#!/usr/bin/env python3
"""Build a visual-only shortlist of up to 15 licensed Objaverse 1.0 GLBs."""
import gzip, json, os, re, sys, time, urllib.request, zlib
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

import trimesh
from PIL import Image, ImageDraw, ImageFont

ROOT = "https://huggingface.co/datasets/allenai/objaverse/resolve/main"
OUT = Path("artifacts/objaverse_preview")
CACHE = Path(".cache/objaverse")
OUT.mkdir(parents=True, exist_ok=True)
CACHE.mkdir(parents=True, exist_ok=True)
ALLOWED = ("CC0", "CC-BY", "CC-BY-SA")
CATEGORIES = {
 "imperial_palace": {
   "title":"القصر الإمبراطوري",
   "terms":["chinese palace","imperial palace","chinese castle","oriental palace","forbidden city","oriental castle","royal palace","palace architecture","east asian palace","traditional chinese palace","imperial residence","palace building"],
   "avoid":["miniature","toy","low poly icon","logo","interior room"]
 },
 "imperial_temple": {
   "title":"المعبد الإمبراطوري",
   "terms":["chinese temple","oriental temple","asian temple","shrine","pagoda","buddhist temple","taoist temple","temple architecture","temple building","traditional chinese temple","east asian shrine"],
   "avoid":["statue","buddha statue","temple bell","interior","toy"]
 },
 "quest_reward": {
   "title":"مبنى المهام والمكافآت",
   "terms":["chinese courtyard","siheyuan","chinese mansion","chinese hall","asian hall","guild hall","traditional chinese house","oriental building","courtyard residence","ancestral hall","clan hall","east asian courtyard","traditional chinese architecture"],
   "avoid":["single chair","interior room","furniture","toy house"]
 },
 "tea_house": {
   "title":"مقهى الشاي",
   "terms":["teahouse","tea house","chinese tavern","asian inn","two story asian","oriental house","wooden pavilion","traditional asian building","chinese inn","tea pavilion","traditional teahouse","asian restaurant"],
   "avoid":["tea cup","tea pot","interior","food"]
 },
 "blacksmith_trade": {
   "title":"ورشة الحدادة والتجارة",
   "terms":["blacksmith","forge","smithy","foundry","anvil workshop","medieval workshop","blacksmith shop","blacksmith building","smith workshop","forge building","traditional forge"],
   "avoid":["sword","anvil only","hammer","weapon","interior only","single tool"]
 }
}
def fetch(url, path, retries=2):
    if path.exists() and path.stat().st_size:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(retries):
        try:
            print(f"FETCH_START {path.name} attempt={attempt+1}/{retries}", flush=True)
            req=urllib.request.Request(url, headers={"User-Agent":"ObjaversePreview/1.0"})
            received=0
            with urllib.request.urlopen(req, timeout=30) as r, open(str(path)+".tmp","wb") as f:
                while True:
                    b=r.read(1024*1024)
                    if not b: break
                    f.write(b)
                    received += len(b)
            os.replace(str(path)+".tmp", path)
            print(f"FETCH_OK {path.name} bytes={received}", flush=True)
            return
        except Exception as exc:
            try:
                Path(str(path)+".tmp").unlink(missing_ok=True)
            except Exception:
                pass
            print(f"FETCH_RETRY {path.name} attempt={attempt+1}/{retries} error={type(exc).__name__}: {exc}", flush=True)
            if attempt == retries-1:
                raise RuntimeError(f"Download failed after {retries} attempts: {url}: {exc}") from exc
            time.sleep(2*(attempt+1))
def flatten(v):
    if isinstance(v, dict):
        return " ".join([str(k)+" "+flatten(x) for k,x in v.items()])
    if isinstance(v, (list,tuple)):
        return " ".join(flatten(x) for x in v)
    return str(v) if v is not None else ""
def first(meta, keys):
    for k in keys:
        v=meta.get(k)
        if isinstance(v,(str,int,float)) and str(v).strip(): return str(v)
    return ""
def normalize_license(meta):
    raw=first(meta,["license","license_id","license_url","license_name","licenseType"])
    if not raw:
        raw=flatten({k:v for k,v in meta.items() if "license" in str(k).lower()})
    s=raw.upper().replace("_","-").replace(" ","")
    if "CC0" in s or "CC-0" in s: return "CC0", raw
    if "CC-BY-SA" in s or "CCBYSA" in s: return "CC-BY-SA", raw
    if ("CC-BY" in s or "CCBY" in s) and "NC" not in s and "ND" not in s: return "CC-BY", raw
    return "", raw
def score(text, spec):
    t=text.lower()
    positive=sum((len(term.split())+2)*3 for term in spec["terms"] if term in t)
    positive += sum(2 for term in spec["terms"] if term.replace(" ","") in t.replace(" ",""))
    negative=sum(5 for term in spec["avoid"] if term in t)
    return positive-negative
def load_metadata_shard(i):
    shard=f"000-{i:03d}"
    print(f"SHARD_START {shard}", flush=True)
    path=CACHE/"metadata"/(shard+".json.gz")
    fetch(f"{ROOT}/metadata/{shard}.json.gz",path)
    try:
        with gzip.open(path,"rt",encoding="utf-8") as f:
            data=json.load(f)
    except (EOFError, zlib.error) as exc:
        print(f"SHARD_CORRUPT_SKIP {shard} error={type(exc).__name__}: {exc}", flush=True)
        return shard, None
    print(f"SHARD_READY {shard} records={len(data):,}", flush=True)
    return shard,data

def main():
    print("Downloading authoritative Objaverse 1.0 UID-to-path map...")
    paths_file=CACHE/"object-paths.json.gz"
    fetch(f"{ROOT}/object-paths.json.gz",paths_file)
    with gzip.open(paths_file,"rt",encoding="utf-8") as f: object_paths=json.load(f)
    print(f"UID paths loaded: {len(object_paths):,}")
    best={k:[] for k in CATEGORIES}
    print("Scanning metadata shards sequentially; corrupt shards are skipped and scanning stops once all five categories have 3 eligible candidates...")
    for shard_index in range(160):
        shard,data=load_metadata_shard(shard_index)
        if data is None:
            continue
        for uid,meta in data.items():
            if uid not in object_paths or not isinstance(meta,dict): continue
            lic,rawlic=normalize_license(meta)
            if lic not in ALLOWED: continue
            name=first(meta,["name","title","displayName","caption"])
            author=first(meta,["author","creator","username","user"])
            textblob=(name+" "+flatten(meta)).lower()
            if not name: name=uid
            for key,spec in CATEGORIES.items():
                sc=score(textblob,spec)
                if sc<=0: continue
                candidate={"uid":uid,"path":object_paths[uid],"name":name[:180],"author":author[:120],
                           "license":lic,"license_raw":rawlic[:120],"score":sc,"shard":shard}
                if all(x["uid"]!=uid for x in best[key]):
                    best[key].append(candidate)
                    best[key].sort(key=lambda x:x["score"],reverse=True)
                    best[key]=best[key][:12]
        print(f"Scanned {shard}: shortlisted " + ", ".join(f"{k}={len(v)}" for k,v in best.items()), flush=True)
        if all(len(items)>=3 for items in best.values()):
            print("EARLY_EXIT: all five categories have 3 open-license candidates; skipping remaining metadata shards.",flush=True)
            break
    chosen={}
    for key,items in best.items():
        chosen[key]=items[:3]
        print(f"CATEGORY_READY {key}: {len(chosen[key])} candidate(s)",flush=True)
    allc=[x for items in chosen.values() for x in items]
    def dl(c):
        p=CACHE/"models"/(c["uid"]+".glb")
        fetch(c.get("download_url") or f"{ROOT}/{c['path']}",p)
        return c,p
    print(f"Downloading {len(allc)} Objaverse GLBs using exact object-paths.json.gz paths; per_category=" + ", ".join(f"{k}={len(v)}" for k,v in chosen.items()), flush=True)
    with ThreadPoolExecutor(max_workers=5) as pool:
        downloads=list(pool.map(dl,allc))
    manifest=[]
    font=ImageFont.load_default()
    for idx,(c,p) in enumerate(downloads,1):
        key=next(k for k,items in chosen.items() if c in items)
        candidate_number=chosen[key].index(c)+1
        scene=trimesh.load(str(p),force="scene",process=False)
        if not isinstance(scene,trimesh.Scene): scene=trimesh.Scene(scene)
        bounds=scene.bounds
        if bounds is None: raise RuntimeError("No mesh bounds: "+c["uid"])
        dims=(bounds[1]-bounds[0]).tolist()
        # Neutral studio framing; preserve source geometry and do not modify the asset.
        scene.set_camera(angles=[0.65,0.0,0.45], distance=None, center=scene.bounding_box.centroid)
        try:
            png=scene.save_image(resolution=(1000,760), visible=True)
        except Exception as e:
            raise RuntimeError(f"Could not render {c['uid']} (GLB downloaded but render failed): {e}")
        from io import BytesIO
        render=Image.open(BytesIO(png)).convert("RGB")
        canvas=Image.new("RGB",(1000,900),(248,247,244))
        canvas.paste(render,(0,0))
        d=ImageDraw.Draw(canvas)
        d.rectangle((0,760,1000,900),fill=(248,247,244))
        d.text((24,778),f"{key}  |  CANDIDATE #{candidate_number}",fill=(20,20,20),font=font)
        d.text((24,800),f"Name: {c['name'][:105]}",fill=(20,20,20),font=font)
        d.text((24,822),f"UID: {c['uid']}   License: {c['license']} ({c['license_raw']})",fill=(20,20,20),font=font)
        d.text((24,844),f"Dimensions (source units): {dims[0]:.3f} x {dims[1]:.3f} x {dims[2]:.3f}",fill=(20,20,20),font=font)
        d.text((24,866),f"Author: {c['author'] or 'Not supplied in metadata'}   Path: {c['path']}",fill=(20,20,20),font=font)
        out=OUT/f"{key}_{candidate_number}.png"
        canvas.save(out,optimize=True)
        c.update({"category":key,"dimensions":dims,"preview":str(out)})
        manifest.append(c)
        print(f"RENDER_OK {key} #{candidate_number} {c['uid']} {c['license']} {dims}",flush=True)
    (OUT/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
    lines=["Objaverse 1.0 visual shortlist — up to 15 candidates","Source: allenai/objaverse (not Objaverse-XL)","UID paths resolved from object-paths.json.gz","Allowed licenses: CC0, CC-BY, CC-BY-SA",""]
    for key,spec in CATEGORIES.items():
        lines.append(spec["title"]+" ["+key+"] — "+str(len(chosen[key]))+" candidate(s)")
        for c in chosen[key]:
            lines.append(f"  #{chosen[key].index(c)+1} {c['name']} | {c['license']} | {c['uid']} | {c['dimensions']} | author={c['author'] or 'not supplied'} | {c['path']}")
    (OUT/"README.txt").write_text("\n".join(lines),encoding="utf-8")
    print(f"OBJAVERSE_PREVIEW_COMPLETE: rendered={len(manifest)}; per_category="+", ".join(f"{k}={len(v)}" for k,v in chosen.items())+"; no city files modified.",flush=True)
if __name__=="__main__": main()
