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
report={"oga":[],"quaternius_packs":[],"converted":[],"skipped":[],"errors":[],"counts":{"characters":0,"weapons":0,"monsters":0},"oga_counts":{"weapons":0,"monsters":0}}
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
def download_url(url,dest):
 dest.parent.mkdir(parents=True,exist_ok=True)
 req=urllib.request.Request(url,headers={"User-Agent":"Phase3B-AssetFetcher/2.0","Accept":"application/octet-stream,*/*"})
 last=None
 for attempt in range(1,5):
  try:
   with urllib.request.urlopen(req,timeout=90) as response: data=response.read()
   if len(data)<10000: raise RuntimeError(f"download too small ({len(data)} bytes): {url}")
   dest.write_bytes(data)
   print("PHASE3B_OGA_ARCHIVE_DOWNLOADED:",dest.name,"bytes=",len(data),flush=True)
   return dest
  except Exception as error:
   last=error
   if attempt==4: break
   import time
   time.sleep(attempt*2)
 raise RuntimeError(f"download failed after 4 attempts: {url}: {last}")
def extract_archive(archive,target,require_models=True):
 target.mkdir(parents=True,exist_ok=True)
 if zipfile.is_zipfile(archive):
  with zipfile.ZipFile(archive) as zf:
   root=target.resolve()
   for info in zf.infolist():
    dest=(target/info.filename).resolve()
    if dest!=root and root not in dest.parents: raise RuntimeError(f"unsafe ZIP member path: {info.filename}")
   zf.extractall(target)
 elif archive.read_bytes()[:6]==bytes.fromhex("377abcaf271c"):
  run(["7z","x","-y",f"-o{target}",str(archive)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 else: raise RuntimeError(f"unsupported or invalid archive: {archive}")
 count=len(models_under(target))
 if count==0 and require_models: raise RuntimeError(f"archive contains no supported 3D model files: {archive.name}")
 print("PHASE3B_OGA_ARCHIVE_EXTRACTED:",archive.name,"models=",count,"files=",sum(1 for x in target.rglob("*") if x.is_file()),"to=",target.relative_to(ROOT),flush=True)
 return target
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
   if key=="base_mesh":
    # Discover real weapon files by their model filename, not a brittle full-path suffix.
    # The pinned pack currently contains both 3- and 4-point shuriken GLBs.
    base_mesh_names={"halberd","3_point_shuriken","4_point_shuriken","throwing_knife"}
    candidates=[x for x in entries if x.get("type")=="blob"
                and x.get("path","").lower().startswith(pack_root.lower()+"/models/")
                and pathlib.PurePosixPath(x["path"]).suffix.lower()==".glb"
                and pathlib.PurePosixPath(x["path"]).stem.lower() in base_mesh_names]
   if key=="base_mesh":
    discovered=sorted(pathlib.PurePosixPath(x["path"]).stem for x in candidates)
    report.setdefault("base_mesh_source_models",[]).extend(
     {"path":x["path"],"bytes":x.get("size",0)} for x in candidates)
    required_base={"halberd","3_point_shuriken","4_point_shuriken","throwing_knife"}
    missing_base=sorted(required_base-set(discovered))
    if missing_base: raise RuntimeError("pinned Base Mesh is missing required real model files: "+str(missing_base))
   if not candidates: raise RuntimeError("pinned source pack contains no supported model files")
   target=RAW/key
   for item in candidates:
    rel=item["path"][len(pack_root)+1:]; dest=target/rel; dest.parent.mkdir(parents=True,exist_ok=True)
    data=github_get(f"https://raw.githubusercontent.com/{GH_ASSET_REPO}/{GH_ASSET_REF}/{item['path']}")
    if len(data)<1000 or data[:4]!=b"glTF": raise RuntimeError(f"invalid GLB payload: {item['path']}")
    if int.from_bytes(data[8:12],"little")!=len(data): raise RuntimeError(f"GLB length header mismatch: {item['path']}")
    dest.write_bytes(data)
   report["quaternius_packs"].append({"pack":key,"source_repo":GH_ASSET_REPO,"source_ref":GH_ASSET_REF,"source_pack":slug_name,"website":meta.get("website"),"creator":meta.get("creator"),"license":"CC0","files":len(candidates),"bytes":sum((target/x["path"][len(pack_root)+1:]).stat().st_size for x in candidates),"status":"downloaded_and_glb_validated"})
  except Exception as e:
   report["errors"].append({"source":key,"error":str(e)})
   print("PHASE3B_QUATERNIUS_SOURCE_ERROR:",key,str(e),flush=True)
 for item in OGA:
  dest=RAW/item["archive"]
  try:
   if not dest.exists(): download_url(item["url"],dest)
   if dest.stat().st_size<10000: raise RuntimeError("archive smaller than 10 KB")
   if item["archive"].lower().endswith(".zip") and not zipfile.is_zipfile(dest): raise RuntimeError("download is not a valid ZIP archive (possible HTML/error page)")
   if item["archive"].lower().endswith(".7z") and dest.read_bytes()[:6]!=bytes.fromhex("377abcaf271c"): raise RuntimeError("download is not a valid 7z archive (possible HTML/error page)")
   target=EXTRACT/item["id"]
   if not any(target.iterdir()) if target.exists() else True: extract_archive(dest,target,require_models=item["kind"]!="effects")
   report["oga"].append({"id":item["id"],"bytes":dest.stat().st_size,"kind":item["kind"],"status":"downloaded"})
  except Exception as e:
   report["errors"].append({"source":item["id"],"error":str(e)})
   print("PHASE3B_OGA_SOURCE_ERROR:",item["id"],str(e),flush=True)
def optimize_to_glb(source,dest):
 dest.parent.mkdir(parents=True,exist_ok=True)
 tmp=dest.with_name(dest.stem+"_assimp.glb")
 if source.suffix.lower()==".glb":
  run(["gltfpack","-noq","-i",str(source),"-o",str(dest)])
 elif source.suffix.lower()==".gltf":
  run(["gltfpack","-noq","-i",str(source),"-o",str(dest)])
 else:
  # Prefer Assimp; COLLADA files can trigger native Assimp crashes on some OGA assets.
  # For a real .dae source only, retry through Blender's COLLADA importer/exporter.
  try:
   run(["assimp","export",str(source),str(tmp)])
  except Exception as assimp_error:
   if source.suffix.lower() != ".dae":
    raise
   tmp.unlink(missing_ok=True)
   blender_expr=(
    "import bpy; "
    "bpy.ops.wm.read_factory_settings(use_empty=True); "
    "bpy.ops.wm.collada_import(filepath=" + repr(str(source.resolve())) + "); "
    "bpy.ops.export_scene.gltf(filepath=" + repr(str(tmp.resolve())) + ", export_format='GLB')"
   )
   print("PHASE3B_DAE_BLENDER_FALLBACK:",source, "assimp_error=",str(assimp_error),flush=True)
   run(["blender","-b","--factory-startup","--python-expr",blender_expr],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
  if not tmp.is_file() or tmp.stat().st_size<1000: raise RuntimeError("Assimp/Blender did not create a valid GLB")
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
   except Exception as e:
    report["errors"].append({"source":str(src),"error":str(e)})
    print("PHASE3B_OGA_CONVERSION_ERROR:",pack,str(src),str(e),flush=True)
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
def pick_model_anywhere(name_tokens):
 # Search every extracted Quaternius and OpenGameArt source folder, recursively and case-insensitively.
 roots=[RAW,EXTRACT]
 hits=[]
 for root in roots:
  if root.exists():
   for src in models_under(root):
    normalized=re.sub(r"[^a-z0-9]+","_",src.stem.lower()).strip("_")
    if any(token in normalized for token in name_tokens):
     hits.append(src)
 if not hits:
  raise RuntimeError("no real source model matched any of "+str(name_tokens)+" under "+str(roots))
 # Prefer already packaged GLB/GLTF; retain deterministic ordering for reproducible builds.
 hits.sort(key=lambda p:(0 if p.suffix.lower()==".glb" else 1 if p.suffix.lower()==".gltf" else 2 if p.suffix.lower()==".fbx" else 3,len(p.parts),str(p).lower()))
 return hits[0]
def export_ninja_weapon(asset_name,name_tokens):
 src=pick_model_anywhere(name_tokens)
 dst=OUT/("quaternius_"+asset_name+".glb")
 optimize_to_glb(src,dst)
 report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"verified source model","category":"weapon","matched_name_tokens":name_tokens})
 report["counts"]["weapons"]+=1
 print("PHASE3B_NINJA_WEAPON_RESOLVED:",asset_name,"source=",src.relative_to(ROOT),"output=",dst.relative_to(ROOT),flush=True)
 return dst
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
 allowed={"kutejnikov_weapons","cethiel_weapons","infernal_sword","old_fantasy_dagger","shuriken","cethiel_dragon"}
 for pack in sorted(allowed):
  root=EXTRACT/pack
  if not root.exists(): continue
  for src in models_under(root):
   if pack=="cethiel_dragon" and not any(k in src.stem.lower() for k in ("dragon","wyrm")): continue
   if pack=="cethiel_dragon" and src not in sorted([x for x in models_under(root) if any(k in x.stem.lower() for k in ("dragon","wyrm"))])[:2]: continue
   category="monster" if pack in {"frog_guy","cethiel_dragon"} else "weapon"
   dst=OUT/("oga_"+category+"s")/(slug(pack+"_"+src.stem)+".glb")
   try:
    optimize_to_glb(src,dst)
    report["converted"].append({"source":str(src.relative_to(ROOT)),"output":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size,"origin":"OpenGameArt CC0","category":category})
    if category=="monster":
     report["counts"]["monsters"]+=1
     report["oga_counts"]["monsters"]+=1
    else:
     report["counts"]["weapons"]+=1
     report["oga_counts"]["weapons"]+=1
    
   except Exception as e: report["errors"].append({"source":str(src),"error":str(e)})
def main():
 run(["assimp","version"])
 fetch_sources()
 for pack in QUATERNIUS:
  try: convert_quaternius(pack)
  except Exception as e: report["errors"].append({"source":pack+"_conversion","error":str(e)})
 export_named_models()
 # Resolve ninja throwing weapons from actual files anywhere in the unpacked source trees.
 # The pinned Base Mesh inventory contains 3_point_shuriken.glb and 4_point_shuriken.glb;
 # other source archives may use Shuriken_1, ninja_star, or throwing_star names.
 for asset_name,tokens in [("shuriken",["shuriken","ninja_star","throwing_star"]),("throwing_knife",["throwing_knife","throwing_knife_","kunai"])]:
  try: export_ninja_weapon(asset_name,tokens)
  except Exception as e:
   report["errors"].append({"source":"required_"+asset_name,"error":str(e)})
   print("PHASE3B_REQUIRED_NINJA_WEAPON_SOURCE_ERROR:",asset_name,str(e),flush=True)
 convert_oga()
 # Preserve effect textures without pretending they are 3D models.
 for p in (EXTRACT/"special_effects").rglob("*"):
  if p.is_file() and p.suffix.lower() in {".png",".jpg",".jpeg",".tga"}:
   dst=OUT/"effects"/p.name; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,dst)
 # Manifest includes exact asset provenance and counts.
 required=["quaternius_archer.glb","quaternius_assassin.glb","quaternius_knight.glb","quaternius_warrior.glb","quaternius_mage.glb","quaternius_bow.glb","quaternius_dagger.glb","quaternius_spear.glb","quaternius_halberd.glb","quaternius_axe.glb","quaternius_staff.glb","quaternius_sword.glb","quaternius_shield.glb"]
 missing=[x for x in required if not (OUT/x).is_file() or (OUT/x).stat().st_size<1000]
 report["required_missing"]=missing
 required_packs={"rpg_characters","modular_weapons","ultimate_monsters"}
 found_packs={x.get("pack") for x in report["quaternius_packs"] if x.get("status")=="downloaded_and_glb_validated"}
 missing_packs=sorted(required_packs-found_packs)
 report["required_packs_missing"]=missing_packs
 REPORT.write_text(json.dumps(report,indent=2),encoding="utf-8")
 for error in report["errors"]: print("PHASE3B_ASSET_ERROR:",error,flush=True)
 if missing_packs:
  print("PHASE3B_REQUIRED_QUATERNIUS_PACKS_MISSING:",missing_packs); sys.exit(5)
 if report["oga_counts"]["weapons"] != 19 or report["oga_counts"]["monsters"] != 2:
  print("PHASE3B_OGA_REQUIRED_COUNTS_NOT_MET:",report["oga_counts"],"expected exactly 19 weapons and 2 monsters"); sys.exit(6)
 missing_ninja=[name for name in ("quaternius_shuriken.glb","quaternius_throwing_knife.glb") if not (OUT/name).is_file() or (OUT/name).stat().st_size<1000]
 report["required_ninja_weapons_missing"]=missing_ninja
 if missing_ninja:
  print("PHASE3B_REQUIRED_NINJA_WEAPONS_MISSING:",missing_ninja); sys.exit(7)
 REPORT.write_text(json.dumps(report,indent=2),encoding="utf-8")
 print("PHASE3B_ASSET_REPORT:",REPORT)
 print("PHASE3B_OGA_DOWNLOADED:",len(report["oga"]),"QUATERNIUS_PACKS:",len(report["quaternius_packs"]),"CONVERTED:",len(report["converted"]),"COUNTS:",report["counts"],"OGA_COUNTS:",report["oga_counts"])
 if report["errors"]:
  for error in report["errors"]: print("PHASE3B_ASSET_ERROR:",error,flush=True)
 if missing: print("PHASE3B_REQUIRED_MODELS_MISSING:",missing); sys.exit(3)
 if report["counts"]["monsters"]<1: print("PHASE3B_NO_MONSTER_MODELS_CONVERTED"); sys.exit(4)
 # Publish the complete, validated package and an auditable inventory to the private HF dataset.
 token=os.environ.get("HF_TOKEN","").strip()
 if not token:
  print("PHASE3B_HF_TOKEN_MISSING"); sys.exit(8)
 from huggingface_hub import HfApi
 manifest=OUT/"phase3b_asset_manifest.json"
 manifest.write_text(json.dumps(report,indent=2),encoding="utf-8")
 files=sorted(x for x in OUT.rglob("*") if x.is_file())
 print("PHASE3B_HF_UPLOAD_FILE_COUNT:",len(files))
 for item in files:
  print("PHASE3B_HF_UPLOAD_FILE:",item.relative_to(OUT).as_posix(),"bytes=",item.stat().st_size)
 api=HfApi(token=token)
 hf_repo="Zzwahwahz/clash-of-legends-terrain-assets"
 api.create_repo(hf_repo,repo_type="dataset",private=True,exist_ok=True)
 api.upload_folder(repo_id=hf_repo,repo_type="dataset",folder_path=str(OUT),path_in_repo="phase3b",commit_message="cache(phase3b): verified Quaternius CC0 and OpenGameArt models")
 print("PHASE3B_HF_UPLOAD_COMPLETE:",hf_repo,"files=",len(files),"path=phase3b")
if __name__=="__main__": main()
