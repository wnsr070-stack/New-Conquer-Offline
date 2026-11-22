#!/usr/bin/env python3
"""Prepare approved CC0 Leafy Grass maps and wilderness GLBs for Checkpoint 2."""
import hashlib, json, os, subprocess
from pathlib import Path
import requests
from huggingface_hub import HfApi, hf_hub_download

REPO = "ZzwahwahzZ/clash-of-legends-terrain-assets"
ROOT = Path(".cache/hf-assets")
EXT = ROOT / "wilderness"
EXT.mkdir(parents=True, exist_ok=True)
TOKEN = os.environ.get("HF_TOKEN")
if not TOKEN:
    raise RuntimeError("HF_TOKEN is required for Checkpoint 2 asset upload")
api = HfApi(token=TOKEN)

def fetch(url, path):
    if path.exists() and path.stat().st_size > 1024:
        return path
    response = requests.get(url, timeout=120, headers={"User-Agent":"ClashOfLegends-Checkpoint2/1.0"})
    response.raise_for_status()
    if len(response.content) < 1024:
        raise RuntimeError(f"Unexpectedly small download: {url}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(response.content)
    return path

def sha(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024), b""): h.update(chunk)
    return h.hexdigest()

maps = {
 "leafy_grass_diffuse.jpg": "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/leafy_grass/leafy_grass_diff_2k.jpg",
 "leafy_grass_normal.png": "https://dl.polyhaven.org/file/ph-assets/Textures/png/2k/leafy_grass/leafy_grass_nor_gl_2k.png",
 "leafy_grass_roughness.jpg": "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/leafy_grass/leafy_grass_rough_2k.jpg",
}
textures=[]
for name,url in maps.items():
    path=fetch(url, EXT/name)
    api.upload_file(path_or_fileobj=str(path), path_in_repo=f"assets/wilderness/leafy_grass/{name}", repo_id=REPO, repo_type="dataset")
    textures.append({"file":name,"path":f"assets/wilderness/leafy_grass/{name}","bytes":path.stat().st_size,"sha256":sha(path),"license":"CC0","source":"https://polyhaven.com/a/leafy_grass"})
    print("LEAFY_GRASS_MAP_UPLOADED:", name, path.stat().st_size)

models = {
 "mountainside":"assets/universal_nature_pack/models/mountainside.glb",
 "rock_face_01":"assets/universal_nature_pack/models/rock_face_01.glb",
 "rock_face_02":"assets/universal_nature_pack/models/rock_face_02.glb",
 "boulder_01":"assets/universal_nature_pack/models/boulder_01.glb",
}
catalog_path=ROOT/"twin_city_runtime_assets.json"
if not catalog_path.is_file():
    raise RuntimeError("Twin City runtime asset catalog missing")
catalog=json.loads(catalog_path.read_text())
report=[]
for asset_id,repo_path in models.items():
    src=Path(hf_hub_download(repo_id=REPO,repo_type="dataset",filename=repo_path,local_dir=str(ROOT)))
    raw=src.read_bytes()
    if len(raw)<20 or raw[:4]!=b"glTF": raise RuntimeError(f"Invalid GLB: {asset_id}")
    out=EXT/(asset_id+".godot43.glb")
    subprocess.run(["gltfpack","-i",str(src),"-o",str(out),"-noq"],check=True,timeout=240)
    data=out.read_bytes()
    if len(data)<20 or data[:4]!=b"glTF": raise RuntimeError(f"gltfpack output invalid: {asset_id}")
    jlen=int.from_bytes(data[12:16],"little")
    if data[16:20]!=b"JSON" or jlen<2 or 20+jlen>len(data): raise RuntimeError(f"GLB JSON chunk invalid: {asset_id}")
    gltf=json.loads(data[20:20+jlen].decode("utf-8").rstrip("\x00 "))
    ext=set(gltf.get("extensionsUsed",[]))|set(gltf.get("extensionsRequired",[]))
    bad=ext & {"KHR_mesh_quantization","EXT_meshopt_compression"}
    if bad: raise RuntimeError(f"Unsupported extensions remain: {asset_id} {sorted(bad)}")
    accessors=gltf.get("accessors",[])
    bounded=sum(1 for a in accessors if "min" in a and "max" in a)
    if not gltf.get("meshes"): raise RuntimeError(f"No meshes in {asset_id}")
    catalog[asset_id]={"path":str(out),"kind":"wilderness_glb"}
    report.append({"asset":asset_id,"source":repo_path,"source_bytes":len(raw),"normalized_bytes":len(data),"mesh_count":len(gltf["meshes"]),"accessors_with_bounds":bounded,"extensions":sorted(ext),"sha256":sha(out)})
    print("WILDERNESS_GLB_OK:",asset_id,"meshes=",len(gltf["meshes"]),"accessors_with_bounds=",bounded,"bytes=",len(data))

for name in maps:
    catalog[name.rsplit(".",1)[0]]={"path":str(EXT/name),"kind":"texture"}
catalog_path.write_text(json.dumps(catalog,indent=2))
manifest={"source":"Poly Haven Leafy Grass CC0","textures":textures,"models":report,"cache_schema":"wilderness-checkpoint2-v2-no-cartoon-biome"}
(ROOT/"wilderness_checkpoint2_manifest.json").write_text(json.dumps(manifest,indent=2))
Path("artifacts").mkdir(exist_ok=True)
Path("artifacts/wilderness_asset_report.json").write_text(json.dumps(manifest,indent=2))
print("CHECKPOINT2_ASSET_PREPARATION_COMPLETE")
