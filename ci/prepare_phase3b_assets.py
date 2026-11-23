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
# Immutable public GitHub mirror of Quaternius CC0 packs.
GH_ASSET_REPO="Papyszoo/CC0-Public-Domain-Models"
GH_ASSET_REF="77343cac874f06b73d16ad0063339df7c9ca254c"
QUATERNIUS={
 "rpg_characters":"quaternius-rpg-characters",
 "modular_weapons":"quaternius-medieval-weapons",
 "ultimate_monsters":"quaternius-ultimate-monsters",
 "knight_character":"quaternius-knightcharacter",
 "base_mesh":"the-base-mesh"}
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
def github_get(url,headers=None):
 h={"User-Agent":"Phase3B-CC0-AssetBot/2.0","Accept":"application/vnd.github+json"}
 if headers: h.update(headers)
 token=os.environ.get("GITHUB_TOKEN","").strip()
 if token and "api.github.com" in urllib.parse.urlparse(url).netloc: h["Authorization"]="Bearer "+token
 req=urllib.request.Request(url,headers=h)
 with urllib.request.urlopen(req,timeout=90) as r: return r.read()
def fetch_sources():
 tree_url=f"https://api.github.com/repos/{GH_ASSET_REPO}/git/trees/{GH_ASSET_REF}?recursive=1"
 tree=json.loads(github_get(tree_url).decode("utf-8"))
 if tree.get("truncated"): raise RuntimeError("GitHub asset tree response was truncated; refusing partial inventory")
 entries=tree.get("tree",[])
 for key,slug_name in QUATERNIUS.items():
  try:
   pack_root=f"packs/{slug_name}"
   meta_url=f"https://raw.githubusercontent.com/{GH_ASSET_REPO}/{GH_ASSET_REF}/{pack_root}/pack.json"
   meta=json.loads(github_get(meta_url).decode("utf-8"))
   if str(meta.get("license","")).upper()!="CC0": raise RuntimeError(f"source pack license is not CC0: {meta.get('license')}")
   if key!="base_mesh" and meta.get("creator")!="Quaternius": raise RuntimeError("source pack creator is not verified as Quaternius")
   candidates=[x for x in entries if x.get("type")=="blob" and x.get("path","").startswith(pack_root+"/models/") and x["path"].lower().endswith(".glb")]
   if key=="base_mesh": candidates=[x for x in candidates if x["path"].endswith("/models/halberd/halberd.glb")]
   if not candidates: raise RuntimeError("pinned source pack contains no GLB models")
   target=RAW/key
   for item in candidates:
    rel=item["path"][len(pack_root)+1:]; dest=target/rel; dest.parent.mkdir(parents=True,exist_ok=True)
    data=github_get(f"https://raw.githubusercontent.com/{GH_ASSET_REPO}/{GH_ASSET_REF}/{item['path']}")
    if len(data)<1000 or data[:4]!=b"glTF": raise RuntimeError(f"invalid GLB payload: {item['path']}")
    if int.from_bytes(data[8:12],"little")!=len(data): raise RuntimeError(f"GLB length header mismatch: {item['path']}")
    dest.write_bytes(data)
   report["quaternius_packs"].append({"pack":key,"source_repo":GH_ASSET_REPO,"source_ref":GH_ASSET_REF,"source_pack":slug_name,"website":meta.get("website"),"creator":meta.get("creator"),"license":"CC0","files":len(candidates),"bytes":sum((target/x["path"][len(pack_root)+1:]).stat().st_size for x in candidates),"status":"downloaded_and_glb_validated"})
  except Exception as e: report["errors"].append({"source":key,"error":str(e)})
 for item in OGA:
  dest=RAW/item["archive"]
  try:
   if not dest.exists(): download_url(item["url"],dest)
   if dest.stat().st_size<10000: raise RuntimeError("archive smaller than 10 KB")
   if item["archive"].lower().endswith(".zip") and not zipfile.is_zipfile(dest): raise RuntimeError("download is not a valid ZIP archive (possible HTML/error page)")
   if item["archive"].lower().endswith(".7z") and dest.read_bytes()[:6]!=bytes.fromhex("377abcaf271c"): raise RuntimeError("download is not a valid 7z archive (possible HTML/error page)")
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
 root=RAW/pack; files=models_under(root)
 if not files: raise RuntimeError("no supported model files found in pinned CC0 GitHub pack")
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
 for src in files:
  dst=OUT/"quaternius_library"/(slug(src.parent.name+"_"+src.stem)+".glb")
  try:
   optimize_to_glb(src,dst); creator="The Base Mesh CC0" if pack=="base_mesh" else "Quaternius CC0"
   report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":creator,"pack":pack})
  except Exception as e: report["errors"].append({"source":str(src),"error":str(e)})
def pick_model(pack,aliases):
 files=models_under(RAW/pack); hits=[p for p in files if any(a in slug(p.stem) for a in aliases)]
 if not hits: raise RuntimeError("no model matched aliases "+str(aliases)+" in "+pack)
 hits.sort(key=lambda p:(0 if p.suffix.lower() in {".glb",".gltf"} else 1 if p.suffix.lower()==".fbx" else 2,len(p.name)))
 return hits[0]
def export_named_models():
 characters=[("archer","rpg_characters",["ranger"]),("assassin","rpg_characters",["rogue"]),("knight","knight_character",["knight_character"]),("warrior","rpg_characters",["warrior"]),("mage","rpg_characters",["wizard"])]
 weapons=[("bow","modular_weapons",["bow_wooden"]),("dagger","rpg_characters",["rogue_dagger"]),("spear","modular_weapons",["spear"]),("halberd","base_mesh",["halberd"]),("axe","modular_weapons",["axe_double"]),("staff","rpg_characters",["wizard_staff"]),("sword","modular_weapons",["sword_big"]),("shield","modular_weapons",["shield_heater"])]
 for key,pack,aliases in characters:
  try:
   src=pick_model(pack,aliases); dst=OUT/("quaternius_"+key+".glb"); optimize_to_glb(src,dst)
   report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"Quaternius CC0","category":"character"}); report["counts"]["characters"]+=1
  except Exception as e: report["errors"].append({"source":"quaternius_"+key,"error":str(e)})
 for key,pack,aliases in weapons:
  try:
   src=pick_model(pack,aliases); dst=OUT/("quaternius_"+key+".glb"); optimize_to_glb(src,dst)
   origin="The Base Mesh CC0" if pack=="base_mesh" else "Quaternius CC0"
   report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":origin,"category":"weapon"}); report["counts"]["weapons"]+=1
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
