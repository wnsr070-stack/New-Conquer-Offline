#!/usr/bin/env python3
"""Fetch official Quaternius CC0 packs and approved OGA archives; convert source models to optimized GLB."""
import json, pathlib, subprocess, zipfile, shutil, sys, os, re
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
 {"id":"special_effects","url":"https://opengameart.org/sites/default/files/blender-volumetric-particles-effects.zip","archive":"special_effects.zip","kind":"effects"}
]
QUATERNIUS_FOLDERS={
 "rpg_characters":("https://drive.google.com/drive/folders/1MIRQXLfTd21HMI5rwOb6Xy0rv0xv1m8b?usp=sharing","rpg_characters"),
 "modular_weapons":("https://drive.google.com/drive/folders/1Z6vYiQxY8W73FXuMWzaTQAg9rzbumnOr?usp=sharing","modular_weapons")
}
report={"oga":[],"quaternius_packs":[],"converted":[],"effects":[],"errors":[]}
def run(cmd): subprocess.run(cmd,check=True)
def download_quaternius():
 for pack,(url,folder) in QUATERNIUS_FOLDERS.items():
  target=RAW/folder
  target.mkdir(parents=True,exist_ok=True)
  try:
   run([sys.executable,"-m","gdown","--folder",url,"-O",str(target),"--remaining-ok"])
   files=[p for p in target.rglob("*") if p.is_file()]
   if not files: raise RuntimeError("official folder returned no files")
   report["quaternius_packs"].append({"pack":pack,"files":len(files),"bytes":sum(p.stat().st_size for p in files),"status":"downloaded"})
  except Exception as exc:
   report["errors"].append({"source":pack,"error":str(exc)})
def extract_oga():
 for item in OGA:
  dest=RAW/item["archive"]
  try:
   if not dest.exists(): run(["curl","-L","--fail","--retry","3","--retry-all-errors",item["url"],"-o",str(dest)])
   if dest.stat().st_size<10000: raise RuntimeError("archive smaller than 10 KB")
   target=EXTRACT/item["id"]; target.mkdir(parents=True,exist_ok=True)
   if zipfile.is_zipfile(dest):
    with zipfile.ZipFile(dest) as z:
     for info in z.infolist():
      name=pathlib.PurePosixPath(info.filename).name
      if not name or info.is_dir(): continue
      if pathlib.Path(name).suffix.lower() in {".blend",".obj",".mtl",".fbx",".gltf",".glb",".bin",".png",".jpg",".jpeg",".tga"}:
       out=target/name
       if not out.exists():
        with z.open(info) as src,out.open("wb") as dst: shutil.copyfileobj(src,dst)
   elif dest.suffix.lower()==".7z": run(["7z","x","-y",f"-o{target}",str(dest)])
   report["oga"].append({"id":item["id"],"bytes":dest.stat().st_size,"kind":item["kind"],"status":"downloaded"})
  except Exception as exc: report["errors"].append({"source":item["id"],"error":str(exc)})
def convert(source,dest):
 script=ROOT/".cache/phase3b/convert_one.py"
 script.write_text(r'''
import bpy,sys,os
src=sys.argv[-2]; dst=sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
ext=os.path.splitext(src)[1].lower()
if ext==".blend": bpy.ops.wm.open_mainfile(filepath=src)
elif ext==".obj":
 if hasattr(bpy.ops.wm,"obj_import"): bpy.ops.wm.obj_import(filepath=src)
 else: bpy.ops.import_scene.obj(filepath=src)
elif ext==".fbx": bpy.ops.import_scene.fbx(filepath=src)
elif ext in (".gltf",".glb"): bpy.ops.import_scene.gltf(filepath=src)
bpy.ops.export_scene.gltf(filepath=dst,export_format="GLB",export_image_format="AUTO",export_animations=True)
''')
 run(["blender","--background","--python",str(script),"--",str(source),str(dest)])
 optimized=dest.with_name(dest.stem+"_optimized.glb")
 run(["gltfpack","-noq","-i",str(dest),"-o",str(optimized)])
 dest.unlink(missing_ok=True); optimized.rename(dest)
 return dest
def normalized(s): return re.sub(r"[^a-z0-9]+","",s.lower())
all_quat=[p for p in (RAW/"rpg_characters").rglob("*") if p.is_file() and p.suffix.lower() in {".blend",".fbx",".obj",".gltf",".glb"}]+[p for p in (RAW/"modular_weapons").rglob("*") if p.is_file() and p.suffix.lower() in {".blend",".fbx",".obj",".gltf",".glb"}]
def choose(tokens,prefer_folder):
 candidates=[p for p in all_quat if prefer_folder in str(p).lower() and any(t in normalized(p.stem) for t in tokens)]
 return sorted(candidates,key=lambda p:(0 if p.suffix.lower() in {".fbx",".blend",".glb",".gltf"} else 1,len(p.name)))[0] if candidates else None
def convert_quat(key,tokens,folder):
 source=choose(tokens,folder)
 if source is None: raise RuntimeError("no source model matched "+key+" tokens "+str(tokens))
 out=OUT/("quaternius_"+key+".glb")
 if source.suffix.lower()==".glb":
  tmp=OUT/(out.stem+"_optimized.glb")
  run(["gltfpack","-noq","-i",str(source),"-o",str(tmp)])
  shutil.move(tmp,out)
 else:
  tmp=OUT/(out.stem+"_raw.glb")
  convert(source,tmp); tmp.rename(out)
 report["converted"].append({"source":str(source.relative_to(ROOT)),"output":str(out.relative_to(ROOT)),"bytes":out.stat().st_size,"origin":"Quaternius CC0"})
def main():
 run([sys.executable,"-m","pip","install","--disable-pip-version-check","gdown>=5.2,<6"])
 download_quaternius()
 extract_oga()
 # Required official player models: Ranger/Archer, Rogue/Assassin, Knight/Warrior, Mage/Taoist.
 required=[
  ("archer",["ranger","archer"],"rpg_characters"),
  ("assassin",["rogue","assassin"],"rpg_characters"),
  ("knight",["knight"],"rpg_characters"),
  ("warrior",["warrior","barbarian"],"rpg_characters"),
  ("mage",["mage","wizard"],"rpg_characters")]
 for key,tokens,folder in required:
  try: convert_quat(key,tokens,folder)
  except Exception as exc: report["errors"].append({"source":"quaternius_"+key,"error":str(exc)})
 weapon_map=[
  ("bow",["bow"],"modular_weapons"),("dagger",["dagger","knife"],"modular_weapons"),
  ("spear",["spear"],"modular_weapons"),("halberd",["halberd"],"modular_weapons"),
  ("axe",["axe"],"modular_weapons"),("staff",["staff"],"modular_weapons"),
  ("sword",["sword","blade"],"modular_weapons"),("shield",["shield"],"modular_weapons")]
 for key,tokens,folder in weapon_map:
  try: convert_quat(key,tokens,folder)
  except Exception as exc: report["errors"].append({"source":"quaternius_"+key,"error":str(exc)})
 # Convert approved OGA weapon models and selected creature sources.
 model_ext={".blend",".obj",".fbx",".gltf",".glb"}
 for source in EXTRACT.rglob("*"):
  if not source.is_file() or source.suffix.lower() not in model_ext: continue
  pack=source.parent.name
  if pack not in {"kutejnikov_weapons","cethiel_weapons","infernal_sword","old_fantasy_dagger","shuriken","frog_guy","cethiel_dragon"}: continue
  if pack in {"frog_guy","cethiel_dragon"} and not any(x in source.name.lower() for x in ("frog","dragon")): continue
  out=OUT/(pack+"_"+source.stem+".glb")
  try:
   if source.suffix.lower()==".glb":
    run(["gltfpack","-noq","-i",str(source),"-o",str(out)])
   else: convert(source,out)
   report["converted"].append({"source":str(source.relative_to(ROOT)),"output":str(out.relative_to(ROOT)),"bytes":out.stat().st_size,"origin":"OpenGameArt CC0"})
  except Exception as exc: report["errors"].append({"source":str(source),"error":str(exc)})
 for p in (EXTRACT/"special_effects").glob("*"):
  if p.suffix.lower() in {".png",".jpg",".jpeg",".tga"}:
   dst=OUT/"effects"/p.name; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,dst)
   report["effects"].append({"file":str(dst.relative_to(ROOT)),"bytes":dst.stat().st_size})
 REPORT.write_text(json.dumps(report,indent=2))
 print("PHASE3B_ASSET_REPORT:",REPORT)
 print("PHASE3B_OGA_DOWNLOADED:",len(report["oga"]),"QUATERNIUS_PACKS:",len(report["quaternius_packs"]),"CONVERTED:",len(report["converted"]))
 required_files=["quaternius_archer.glb","quaternius_assassin.glb","quaternius_knight.glb","quaternius_warrior.glb","quaternius_mage.glb","quaternius_bow.glb","quaternius_dagger.glb","quaternius_spear.glb","quaternius_halberd.glb","quaternius_axe.glb","quaternius_staff.glb","quaternius_sword.glb","quaternius_shield.glb"]
 missing=[name for name in required_files if not (OUT/name).is_file() or (OUT/name).stat().st_size<10000]
 if missing:
  print("PHASE3B_REQUIRED_QUATERNIUS_MODELS_MISSING:",missing)
  sys.exit(3)
if __name__=="__main__": main()
