#!/usr/bin/env python3
"""Fetch CC0 Quaternius/OGA assets; convert supported models with Assimp and optimize GLB."""
import json, pathlib, subprocess, zipfile, shutil, sys, os, re, hashlib, urllib.request, urllib.parse, html.parser, tarfile
ROOT=pathlib.Path.cwd()
RAW=ROOT/".cache/phase3b/source"; EXTRACT=ROOT/".cache/phase3b/extracted"
OUT=ROOT/"assets/phase3b"; REPORT=ROOT/"artifacts/phase3b_asset_report.json"
for p in (RAW,EXTRACT,OUT,REPORT.parent): p.mkdir(parents=True,exist_ok=True)
OGA=[
 {"id":"kutejnikov_weapons","url":"https://opengameart.org/sites/default/files/weapons_5.zip","archive":"weapons_5.zip","kind":"weapon"},
 {"id":"cethiel_weapons","url":"https://opengameart.org/sites/default/files/handpainted%20weapons.zip","archive":"cethiel_weapons.zip","kind":"weapon"},
 {"id":"infernal_sword","url":"https://opengameart.org/sites/default/files/3d_-_infernal_sword.zip","archive":"infernal_sword.zip","kind":"weapon"},
 {"id":"old_fantasy_dagger","url":"https://opengameart.org/sites/default/files/dagger.7z","archive":"dagger.7z","kind":"weapon"},
 {"id":"shuriken","url":"https://opengameart.org/sites/default/files/shuriken.zip","archive":"shuriken.zip","kind":"weapon"},
 {"id":"frog_guy","url":"https://opengameart.org/sites/default/files/3d_frog.zip","archive":"frog_guy.zip","kind":"monster"},
 {"id":"cethiel_dragon","url":"https://opengameart.org/sites/default/files/dragon_oga.zip","archive":"dragon_oga.zip","kind":"monster"},
 {"id":"special_effects","url":"https://opengameart.org/sites/default/files/blender-volumetric-particles-effects.zip","archive":"special_effects.zip","kind":"effects"}]
QUATERNIUS={
 "rpg_characters":"https://quaternius.com/packs/rpgcharacters.html",
 "modular_weapons":"https://quaternius.com/packs/medievalweapons.html",
 "ultimate_monsters":"https://quaternius.com/packs/ultimatemonsters.html"}
report={"oga":[],"quaternius_packs":[],"converted":[],"skipped":[],"errors":[],"counts":{"characters":0,"weapons":0,"monsters":0}}
MODEL_EXT={".obj",".fbx",".gltf",".glb",".stl",".ply",".dae"}
def run(cmd,**kw): return subprocess.run(cmd,check=True,**kw)
def slug(s): return re.sub(r"[^a-z0-9]+","_",s.lower()).strip("_")[:90] or "model"
class Links(html.parser.HTMLParser):
 def __init__(self): super().__init__(); self.hrefs=[]
 def handle_starttag(self,tag,attrs):
  if tag=="a":
   a=dict(attrs); h=a.get("href","")
   if h: self.hrefs.append((h,a.get("title","")))
def official_download_url(page):
 req=urllib.request.Request(page,headers={"User-Agent":"Mozilla/5.0 (compatible; Phase3BAssetBot/1.0)"})
 with urllib.request.urlopen(req,timeout=45) as r: body=r.read().decode("utf-8","replace")
 # Quaternius currently stores its public Drive download in a button onclick attribute, not an href.
 embedded=re.findall(r"https?://drive\.google\.com/drive/folders/[A-Za-z0-9_-]+(?:\?[^'\\"\s)]*)?",body)
 if embedded: return embedded[0]
 p=Links(); p.feed(body)
 links=[]
 for href,title in p.hrefs:
  u=urllib.parse.urljoin(page,href)
  if any(x in u.lower() for x in ("drive.google.com","itch.io","quaternius.com/download","dropbox.com")):
   links.append(u)
 # Prefer Google Drive or itch source/download endpoints, avoiding social/member links.
 links=[u for u in links if not any(x in u.lower() for x in ("discord","patreon","twitter","member"))]
 if not links: raise RuntimeError("official Quaternius page had no machine-readable public download link")
 return links[0]
def download_url(url,dest):
 dest.parent.mkdir(parents=True,exist_ok=True)
 req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0"})
 with urllib.request.urlopen(req,timeout=90) as r:
  data=r.read()
 if len(data)<10000: raise RuntimeError("download response smaller than 10 KB")
 dest.write_bytes(data)
 return len(data)
def extract_archive(archive,target):
 target.mkdir(parents=True,exist_ok=True)
 if zipfile.is_zipfile(archive):
  with zipfile.ZipFile(archive) as z:
   for info in z.infolist():
    if info.is_dir(): continue
    name=pathlib.PurePosixPath(info.filename)
    if name.is_absolute() or ".." in name.parts: continue
    out=target.joinpath(*name.parts); out.parent.mkdir(parents=True,exist_ok=True)
    with z.open(info) as src,out.open("wb") as dst: shutil.copyfileobj(src,dst)
 elif archive.suffix.lower()==".7z":
  run(["7z","x","-y",f"-o{target}",str(archive)])
 elif tarfile.is_tarfile(archive):
  with tarfile.open(archive) as t:
   for m in t.getmembers():
    if m.isfile() and not pathlib.PurePosixPath(m.name).is_absolute() and ".." not in pathlib.PurePosixPath(m.name).parts: t.extract(m,target,filter="data")
 else: raise RuntimeError("unsupported archive format")
def fetch_sources():
 # Resolve download buttons from the official Quaternius pages at run time; no guessed Drive IDs.
 for pack,page in QUATERNIUS.items():
  try:
   url=official_download_url(page)
   target=RAW/pack; target.mkdir(parents=True,exist_ok=True)
   parsed=urllib.parse.urlparse(url)
   if "drive.google.com" in parsed.netloc:
    run([sys.executable,"-m","pip","install","--disable-pip-version-check","gdown>=5.2,<6"])
    if "/folders/" in parsed.path:
     run([sys.executable,"-m","gdown","--folder",url,"-O",str(target),"--remaining-ok"])
    else:
     archive=RAW/(pack+".zip")
     run([sys.executable,"-m","gdown",url,"-O",str(archive)])
     extract_archive(archive,target)
    files=[p for p in target.rglob("*") if p.is_file()]
    if not files: raise RuntimeError("official Google Drive download produced no files")
    report["quaternius_packs"].append({"pack":pack,"url":url,"files":len(files),"bytes":sum(p.stat().st_size for p in files),"status":"downloaded"})
   else:
    archive=RAW/(pack+".zip"); size=download_url(url,archive); extract_archive(archive,target)
    files=[p for p in target.rglob("*") if p.is_file()]
    report["quaternius_packs"].append({"pack":pack,"url":url,"archive_bytes":size,"files":len(files),"status":"downloaded"})
  except Exception as e: report["errors"].append({"source":pack,"error":str(e)})
 for item in OGA:
  dest=RAW/item["archive"]
  try:
   if not dest.exists(): download_url(item["url"],dest)
   if dest.stat().st_size<10000: raise RuntimeError("archive smaller than 10 KB")
   target=EXTRACT/item["id"]
   if not any(target.iterdir()) if target.exists() else True: extract_archive(dest,target)
   report["oga"].append({"id":item["id"],"bytes":dest.stat().st_size,"kind":item["kind"],"status":"downloaded"})
  except Exception as e: report["errors"].append({"source":item["id"],"error":str(e)})
def optimize_to_glb(source,dest):
 dest.parent.mkdir(parents=True,exist_ok=True)
 tmp=dest.with_name(dest.stem+"_assimp.glb")
 if source.suffix.lower()==".glb":
  run(["gltfpack","-noq","-i",str(source),"-o",str(dest)])
 elif source.suffix.lower()==".gltf":
  run(["gltfpack","-noq","-i",str(source),"-o",str(dest)])
 else:
  # Assimp selects the GLB exporter from the output extension; OBJ MTL/textures remain beside source.
  run(["assimp","export",str(source),str(tmp)])
  if not tmp.is_file() or tmp.stat().st_size<1000: raise RuntimeError("Assimp did not create a valid GLB")
  run(["gltfpack","-noq","-i",str(tmp),"-o",str(dest)])
  tmp.unlink(missing_ok=True)
 data=dest.read_bytes()[:4]
 if data!=b"glTF" or dest.stat().st_size<1000:
  dest.unlink(missing_ok=True); raise RuntimeError("output failed GLB magic/size validation")
 return dest
def models_under(root):
 return [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in MODEL_EXT]
def convert_quaternius(pack):
 root=RAW/pack
 files=models_under(root)
 if not files: raise RuntimeError("no supported model files found in downloaded pack")
 # Convert the entire monster pack to a separate Phase 4 cache; retain names and avoid collisions.
 if pack=="ultimate_monsters":
  converted=0
  for src in files:
   dst=OUT/"monsters"/(slug(src.parent.name+"_"+src.stem)+".glb")
   try:
    optimize_to_glb(src,dst); converted+=1
    report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"Quaternius CC0","category":"monster"})
   except Exception as e: report["errors"].append({"source":str(src),"error":str(e)})
  report["counts"]["monsters"]+=converted
  if converted==0: raise RuntimeError("Ultimate Monsters produced zero valid GLB models")
  return
 # All models are converted into a named library. Required named models are then selected by aliases.
 for src in files:
  dst=OUT/"quaternius_library"/(slug(src.parent.name+"_"+src.stem)+".glb")
  try:
   optimize_to_glb(src,dst)
   report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"Quaternius CC0","pack":pack})
  except Exception as e: report["errors"].append({"source":str(src),"error":str(e)})
def pick_model(pack,aliases):
 root=RAW/pack
 hits=[p for p in models_under(root) if any(a in slug(p.stem) for a in aliases)]
 if not hits: raise RuntimeError("no model matched aliases "+str(aliases))
 # Prefer GLB/GLTF, then FBX, then OBJ, and shorter unambiguous names.
 hits.sort(key=lambda p:(0 if p.suffix.lower() in {".glb",".gltf"} else 1 if p.suffix.lower()==".fbx" else 2,len(p.name)))
 return hits[0]
def export_named_models():
 characters=[("archer",["ranger","archer"]),("assassin",["rogue","assassin"]),("knight",["knight"]),("warrior",["warrior","barbarian"]),("mage",["mage","wizard"])]
 weapons=[("bow",["bow"]),("dagger",["dagger","knife"]),("spear",["spear"]),("halberd",["halberd"]),("axe",["axe"]),("staff",["staff"]),("sword",["sword","blade"]),("shield",["shield"])]
 for key,aliases in characters:
  try:
   src=pick_model("rpg_characters",aliases); dst=OUT/("quaternius_"+key+".glb"); optimize_to_glb(src,dst)
   report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"Quaternius CC0","category":"character"}); report["counts"]["characters"]+=1
  except Exception as e: report["errors"].append({"source":"quaternius_"+key,"error":str(e)})
 for key,aliases in weapons:
  try:
   src=pick_model("modular_weapons",aliases); dst=OUT/("quaternius_"+key+".glb"); optimize_to_glb(src,dst)
   report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"Quaternius CC0","category":"weapon"}); report["counts"]["weapons"]+=1
  except Exception as e: report["errors"].append({"source":"quaternius_"+key,"error":str(e)})
def convert_oga():
 allowed={"kutejnikov_weapons","cethiel_weapons","infernal_sword","old_fantasy_dagger","shuriken","frog_guy","cethiel_dragon"}
 for pack in allowed:
  root=EXTRACT/pack
  if not root.exists(): continue
  for src in models_under(root):
   if pack=="frog_guy" and not any(k in src.stem.lower() for k in ("frog","toad")): continue
   if pack=="cethiel_dragon" and not any(k in src.stem.lower() for k in ("dragon","wyrm")): continue
   category="monster" if pack in {"frog_guy","cethiel_dragon"} else "weapon"
   dst=OUT/("oga_"+category+"s")/(slug(pack+"_"+src.stem)+".glb")
   try:
    optimize_to_glb(src,dst)
    report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"OpenGameArt CC0","category":category})
    if category=="monster": report["counts"]["monsters"]+=1
    else: report["counts"]["weapons"]+=1
   except Exception as e: report["errors"].append({"source":str(src),"error":str(e)})
def main():
 run(["assimp","version"])
 fetch_sources()
 for pack in QUATERNIUS:
  try: convert_quaternius(pack)
  except Exception as e: report["errors"].append({"source":pack+"_conversion","error":str(e)})
 export_named_models()
 convert_oga()
 # Preserve effect textures without pretending they are 3D models.
 for p in (EXTRACT/"special_effects").rglob("*"):
  if p.is_file() and p.suffix.lower() in {".png",".jpg",".jpeg",".tga"}:
   dst=OUT/"effects"/p.name; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,dst)
 # Manifest includes exact asset provenance and counts.
 required=["quaternius_archer.glb","quaternius_assassin.glb","quaternius_knight.glb","quaternius_warrior.glb","quaternius_mage.glb","quaternius_bow.glb","quaternius_dagger.glb","quaternius_spear.glb","quaternius_halberd.glb","quaternius_axe.glb","quaternius_staff.glb","quaternius_sword.glb","quaternius_shield.glb"]
 missing=[x for x in required if not (OUT/x).is_file() or (OUT/x).stat().st_size<1000]
 report["required_missing"]=missing
 REPORT.write_text(json.dumps(report,indent=2))
 print("PHASE3B_ASSET_REPORT:",REPORT)
 print("PHASE3B_OGA_DOWNLOADED:",len(report["oga"]),"QUATERNIUS_PACKS:",len(report["quaternius_packs"]),"CONVERTED:",len(report["converted"]),"COUNTS:",report["counts"])
 if missing: print("PHASE3B_REQUIRED_MODELS_MISSING:",missing); sys.exit(3)
 if report["counts"]["monsters"]<1: print("PHASE3B_NO_MONSTER_MODELS_CONVERTED"); sys.exit(4)
if __name__=="__main__": main()
