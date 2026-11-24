#!/usr/bin/env python3
"""CI-only preparation of the approved city/wilderness runtime catalog; never uploads to HF."""
import json, pathlib, subprocess, requests
from huggingface_hub import hf_hub_download
ROOT=pathlib.Path(".cache/hf-assets"); W=ROOT/"wilderness"; W.mkdir(parents=True,exist_ok=True)
REPO="ZzwahwahzZ/clash-of-legends-terrain-assets"
catalog_path=ROOT/"twin_city_runtime_assets.json"
if not catalog_path.is_file(): raise SystemExit("Twin City runtime catalog missing; run ci/fetch_assets.py first")
catalog=json.loads(catalog_path.read_text())
maps={
"leafy_grass_diffuse.jpg":"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/leafy_grass/leafy_grass_diff_2k.jpg",
"leafy_grass_normal.png":"https://dl.polyhaven.org/file/ph-assets/Textures/png/2k/leafy_grass/leafy_grass_nor_gl_2k.png",
"leafy_grass_roughness.jpg":"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/leafy_grass/leafy_grass_rough_2k.jpg",
"rock_boulder_dry_diffuse.png":"https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/rock_boulder_dry/rock_boulder_dry_diff_1k.png",
"rock_boulder_dry_normal.png":"https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/rock_boulder_dry/rock_boulder_dry_nor_gl_1k.png",
"rock_boulder_dry_roughness.png":"https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/rock_boulder_dry/rock_boulder_dry_rough_1k.png",
"sand_01_diffuse.jpg":"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/sand_01/sand_01_diff_1k.jpg",
"sand_01_normal.png":"https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/sand_01/sand_01_nor_gl_1k.png",
"sand_01_roughness.jpg":"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/sand_01/sand_01_rough_1k.jpg",
"snow_02_diffuse.jpg":"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/snow_02/snow_02_diff_1k.jpg",
"snow_02_normal.png":"https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/snow_02/snow_02_nor_gl_1k.png",
"snow_02_roughness.jpg":"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/snow_02/snow_02_rough_1k.jpg"}
for name,url in maps.items():
 p=W/name
 if not p.exists():
  r=requests.get(url,timeout=120); r.raise_for_status(); p.write_bytes(r.content)
 if p.stat().st_size<1024: raise SystemExit("Texture download invalid: "+name)
 catalog[name.rsplit(".",1)[0]]={"path":str(p),"kind":"texture"}
 print("PHASE4B_SCENE_TEXTURE_OK:",name,p.stat().st_size)
models={
"mountainside":"assets/universal_nature_pack/models/mountainside.glb",
"rock_face_01":"assets/universal_nature_pack/models/rock_face_01.glb",
"rock_face_02":"assets/universal_nature_pack/models/rock_face_02.glb",
"boulder_01":"assets/universal_nature_pack/models/boulder_01.glb",
"bridge_stone":"assets/wuxia_imperial_pack/candidates/models/opengameart-stone-bridge-0.glb",
"bridge_wood":"assets/wuxia_imperial_pack/candidates/models/opengameart-wooden-bridge-0.glb"}
for key,remote in models.items():
 src=pathlib.Path(hf_hub_download(repo_id=REPO,repo_type="dataset",filename=remote,token=None))
 out=W/(key+".godot43.glb")
 subprocess.run(["gltfpack","-i",str(src),"-o",str(out),"-noq"],check=True,timeout=240)
 if not out.is_file() or out.stat().st_size<20 or out.read_bytes()[:4]!=b"glTF": raise SystemExit("Invalid normalized GLB: "+key)
 catalog[key]={"path":str(out),"kind":"wilderness_glb"}
 print("PHASE4B_SCENE_MODEL_OK:",key,out.stat().st_size)
for key in ["rock_boulder_dry","sand_01","snow_02"]:
 for suffix in ["diffuse","normal","roughness"]:
  k=key+"_"+suffix
  p=W/(k+".png")
  if not p.exists(): p=W/(k+".jpg")
  if not p.exists(): raise SystemExit("Missing prepared map "+k)
  catalog[k]={"path":str(p),"kind":"texture"}
catalog_path.write_text(json.dumps(catalog,indent=2))
print("PHASE4B_SCENE_ASSET_CATALOG_READY:",len(catalog),"uploads_to_hf=0")
