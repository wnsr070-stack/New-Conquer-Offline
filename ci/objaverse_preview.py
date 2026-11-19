#!/usr/bin/env python3
"""Build a visual-only shortlist of 15 licensed Objaverse 1.0 GLBs."""
import gzip, json, os, re, sys, time, urllib.request
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

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
   "terms":["imperial palace","chinese palace","asian palace","chinese castle","oriental palace","forbidden city","royal palace","palace","pagoda palace"],
   "avoid":["miniature","toy","low poly icon","logo","interior room"]
 },
 "imperial_temple": {
   "title":"المعبد الإمبراطوري",
   "terms":["chinese temple","asian temple","buddhist temple","temple building","oriental temple","temple architecture","chinese shrine"],
   "avoid":["statue","buddha statue","temple bell","interior","toy"]
 },
 "quest_reward": {
   "title":"مبنى المهام والمكافآت",
   "terms":["siheyuan","chinese courtyard","courtyard house","traditional chinese house","chinese residence","quadrangle courtyard","courtyard building"],
   "avoid":["single chair","interior room","furniture","toy house"]
 },
 "tea_house": {
   "title":"مقهى الشاي",
   "terms":["chinese tea house","tea house","teahouse","asian cafe","chinese restaurant","traditional chinese building","two story chinese house"],
   "avoid":["tea cup","tea pot","interior","food"]
 },
 "blacksmith_trade": {
   "title":"ورشة الحدادة والتجارة",
   "terms":["chinese blacksmith","blacksmith shop","blacksmith workshop","smithy","forge building","blacksmith","smith workshop","medieval blacksmith shop"],
   "avoid":["sword","anvil only","hammer","weapon","interior only","single tool"]
 }
}
def fetch(url, path, retries=4):
    if path.exists() and path.stat().st_size:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(retries):
        try:
            req=urllib.request.Request(url, headers={"User-Agent":"ObjaversePreview/1.0"})
            with urllib.request.urlopen(req, timeout=90) as r, open(str(path)+".tmp","wb") as f:
                while True:
                    b=r.read(1024*1024)
                    if not b: break
                    f.write(b)
            os.replace(str(path)+".tmp", path)
            return
        except Exception:
            if attempt == retries-1: raise
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
    path=CACHE/"metadata"/(shard+".json.gz")
    fetch(f"{ROOT}/metadata/{shard}.json.gz",path)
    with gzip.open(path,"rt",encoding="utf-8") as f:
        return shard,json.load(f)
def main():
    print("Downloading authoritative Objaverse 1.0 UID-to-path map...")
    paths_file=CACHE/"object-paths.json.gz"
    fetch(f"{ROOT}/object-paths.json.gz",paths_file)
    with gzip.open(paths_file,"rt",encoding="utf-8") as f: object_paths=json.load(f)
    print(f"UID paths loaded: {len(object_paths):,}")
    best={k:[] for k in CATEGORIES}
    print("Scanning the 160 official metadata shards (licenses and descriptions)...")
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures=[pool.submit(load_metadata_shard,i) for i in range(160)]
        for fut in as_completed(futures):
            shard,data=fut.result()
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
    chosen={}
    for key,items in best.items():
        if len(items)<3:
            raise RuntimeError(f"Only {len(items)} eligible candidates found for {key}; refusing to fabricate a 15-model shortlist.")
        chosen[key]=items[:3]
    allc=[x for items in chosen.values() for x in items]
    def dl(c):
        p=CACHE/"models"/(c["uid"]+".glb")
        fetch(f"{ROOT}/{c['path']}",p)
        return c,p
    print("Downloading 15 GLBs using exact object-paths.json.gz paths...")
    with ThreadPoolExecutor(max_workers=5) as pool:
        downloads=list(pool.map(dl,allc))
    manifest=[]
    font=ImageFont.load_default()
    for idx,(c,p) in enumerate(downloads,1):
        key=next(k for k,items in chosen.items() if c in items)
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
        d.text((24,778),f"{key}  |  CANDIDATE #{(idx-1)%3+1}",fill=(20,20,20),font=font)
        d.text((24,800),f"Name: {c['name'][:105]}",fill=(20,20,20),font=font)
        d.text((24,822),f"UID: {c['uid']}   License: {c['license']} ({c['license_raw']})",fill=(20,20,20),font=font)
        d.text((24,844),f"Dimensions (source units): {dims[0]:.3f} x {dims[1]:.3f} x {dims[2]:.3f}",fill=(20,20,20),font=font)
        d.text((24,866),f"Author: {c['author'] or 'Not supplied in metadata'}   Path: {c['path']}",fill=(20,20,20),font=font)
        out=OUT/f"{key}_{(idx-1)%3+1}.png"
        canvas.save(out,optimize=True)
        c.update({"category":key,"dimensions":dims,"preview":str(out)})
        manifest.append(c)
        print(f"RENDER_OK {key} #{(idx-1)%3+1} {c['uid']} {c['license']} {dims}",flush=True)
    (OUT/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
    lines=["Objaverse 1.0 visual shortlist — 15 candidates","Source: allenai/objaverse (not Objaverse-XL)","UID paths resolved from object-paths.json.gz","Allowed licenses: CC0, CC-BY, CC-BY-SA",""]
    for key,spec in CATEGORIES.items():
        lines.append(spec["title"]+" ["+key+"]")
        for c in chosen[key]:
            lines.append(f"  #{chosen[key].index(c)+1} {c['name']} | {c['license']} | {c['uid']} | {c['dimensions']} | author={c['author'] or 'not supplied'} | {c['path']}")
    (OUT/"README.txt").write_text("\n".join(lines),encoding="utf-8")
    print("OBJAVERSE_PREVIEW_COMPLETE: 15 candidates rendered; no city files modified.")
if __name__=="__main__": main()
