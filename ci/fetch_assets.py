#!/usr/bin/env python3
"""Fetch only the verified runtime assets used by the Twin City checkpoint preview."""
import hashlib
import json
import re
import requests
import subprocess
from pathlib import Path
from huggingface_hub import hf_hub_download

REPO_ID = "ZzwahwahzZ/clash-of-legends-terrain-assets"
OBJAVERSE_REPO_ID = "codepawl/objaverse-clean-glb"
NATURE = "assets/universal_nature_pack/imperial_approved_assets.json"
RESIDENTIAL = {
 "obj_chinese_house": "engine/chinese-house-2bb6ef8d/chinese-house-2bb6ef8d.glb",
 "obj_chinese_painter_villa": "engine/chinese-painter-s-little-house-dae-villa-8766d274/chinese-painter-s-little-house-dae-villa-8766d274.glb",
 "obj_big_chinese_house": "engine/big-house-in-china-style-51cf3958/big-house-in-china-style-51cf3958.glb",
}
LANDMARKS = {
 "landmark_chinese_architecture": "engine/chinese-architecture-2287628c/chinese-architecture-2287628c.glb",
 "landmark_big_chinese_house": "engine/big-house-in-china-style-51cf3958/big-house-in-china-style-51cf3958.glb",
 "landmark_chinese_fireworks_shop": "engine/chinese-fireworks-shop-8acedb4a/chinese-fireworks-shop-8acedb4a.glb",
}
CACHE_ROOT = Path(".cache/hf-assets")
EXTERNAL = CACHE_ROOT / "external"

CITY_MODELS = {
 "grab3d-dirt-road": "assets/wuxia_imperial_pack/models/grab3d-dirt-road.glb",
 "innerscene-buddhist-temple-pagoda-c5ebacdc": "assets/wuxia_imperial_pack/models/innerscene-buddhist-temple-pagoda-c5ebacdc.glb",
 "innerscene-japanese-maple-tree-565c1604": "assets/wuxia_imperial_pack/models/innerscene-japanese-maple-tree-565c1604.glb",
 "polygonalmind-lunar-year-001": "assets/wuxia_imperial_pack/models/polygonalmind-lunar-year-001.glb",
 "polygonalmind-lunar-year-008": "assets/wuxia_imperial_pack/models/polygonalmind-lunar-year-008.glb",
 "polygonalmind-lunar-year-011": "assets/wuxia_imperial_pack/models/polygonalmind-lunar-year-011.glb",
}
CANDIDATE_MODELS = {
 "3dassets-feudal-japan-castle-town-tea-house-a168f962": "assets/wuxia_imperial_pack/candidates/models/3dassets-feudal-japan-castle-town-tea-house-a168f962.glb",
}
DIRECT_ASSETS = {
 "blacksmith_forge": "https://tevy.dev/models/blacksmith-forge/v1/lod0.glb",
 "cobblestone_diffuse": "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/cobblestone_floor_04/cobblestone_floor_04_diff_1k.jpg",
 "cobblestone_normal": "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/cobblestone_floor_04/cobblestone_floor_04_nor_gl_1k.png",
 "cobblestone_roughness": "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/cobblestone_floor_04/cobblestone_floor_04_rough_1k.jpg",
}
POLY_PIZZA_FORGE_PAGE = "https://poly.pizza/m/a1g7o8qQ1U"

def download(repo_path):
 return Path(hf_hub_download(repo_id=REPO_ID, repo_type="dataset", filename=repo_path, local_dir=str(CACHE_ROOT)))

def digest(path):
 h = hashlib.sha256()
 with path.open("rb") as stream:
  for chunk in iter(lambda: stream.read(1024 * 1024), b""):
   h.update(chunk)
 return h.hexdigest()

def verify(path, item, label):
 if item.get("bytes") is not None and path.stat().st_size != int(item["bytes"]):
  raise RuntimeError(f"Size mismatch: {label}")
 if item.get("sha256") and digest(path) != item["sha256"]:
  raise RuntimeError(f"SHA256 mismatch: {label}")
 if path.stat().st_size < 20 or path.read_bytes()[:4] != b"glTF":
  raise RuntimeError(f"Invalid GLB header: {label}")

def fetch_url(url, dest, glb=False):
 dest.parent.mkdir(parents=True, exist_ok=True)
 response = requests.get(url, timeout=90, headers={"User-Agent": "Mozilla/5.0 TwinCityAssetFetcher"})
 response.raise_for_status()
 if len(response.content) < 20 or (glb and response.content[:4] != b"glTF"):
  raise RuntimeError("invalid asset: " + url)
 dest.write_bytes(response.content)
 print("EXTERNAL_ASSET_OK:", dest.name, "bytes=", len(response.content))
 return dest

def poly_page_download(url):
 try:
  response = requests.get(url, timeout=60, headers={"User-Agent": "Mozilla/5.0"})
  response.raise_for_status()
  html = response.text.replace("\\u0026", "&").replace("\\u002F", "/")
  if not re.search(r"CC0\s*(?:1\.0)?", html, re.I):
   raise RuntimeError("Poly Pizza page does not expose verifiable CC0 licence text")
  urls = re.findall(r'https?[^" <>]+?\.glb(?:\?[^" <>]*)?', html, re.I)
  for direct in urls:
   try:
    return fetch_url(direct, EXTERNAL / "blacksmith_forge_poly.glb", True)
   except Exception:
    pass
  raise RuntimeError("no valid direct GLB URL")
 except Exception as error:
  print("POLY_PIZZA_OPTIONAL_MISS: blacksmith_forge_poly", str(error))
  return None

def fetch_checkpoint_assets(catalog):
 for key, url in DIRECT_ASSETS.items():
  suffix = Path(url.split("?")[0]).suffix.lower()
  path = fetch_url(url, EXTERNAL / (key + suffix), suffix == ".glb")
  if key == "blacksmith_forge":
   converted = EXTERNAL / "blacksmith_forge_godot43.glb"
   subprocess.run(["gltfpack", "-i", str(path), "-o", str(converted), "-noq"], check=True, timeout=180)
   if not converted.is_file() or converted.stat().st_size < 20 or converted.read_bytes()[:4] != b"glTF":
    raise RuntimeError("gltfpack produced an invalid standard GLB for blacksmith_forge")
   path = converted
   print("BLACKSMITH_GLTFPACK_DECOMPRESSED_OK:", path.stat().st_size)
  catalog[key] = {"path": str(path), "kind": "texture" if suffix in (".jpg", ".png") else "architecture"}

 poly_path = poly_page_download(POLY_PIZZA_FORGE_PAGE)
 if poly_path:
  converted = EXTERNAL / "blacksmith_forge_poly_godot43.glb"
  subprocess.run(["gltfpack", "-i", str(poly_path), "-o", str(converted), "-noq"], check=True, timeout=180)
  if not converted.is_file() or converted.stat().st_size < 20 or converted.read_bytes()[:4] != b"glTF":
   raise RuntimeError("gltfpack produced an invalid standard GLB for Poly Pizza blacksmith_forge")
  catalog["blacksmith_forge"] = {"path": str(converted), "kind": "architecture"}
  print("BLACKSMITH_POLYPIZZA_CC0_GLTFPACK_OK:", converted.stat().st_size)

 stair = download("assets/wuxia_imperial_pack/models/polygonalmind-lunar-year-014.glb")
 if stair.stat().st_size != 729036 or stair.read_bytes()[:4] != b"glTF":
  raise RuntimeError("HF EntranceStairs source size/header verification failed")
 catalog["imperial_entrance_stairs"] = {"path": str(stair), "kind": "building_entrance_stairs"}
 print("CHECKPOINT1_EXTERNAL_ASSETS_OK")

def main():
 catalog = {}
 credits = [
  "Hugging Face dataset: ZzwahwahzZ/clash-of-legends-terrain-assets",
  "Approved royal palace source: 1,055,596 bytes; HF Wuxia Imperial candidate.",
  "Imperial palace source: 2,876,988 bytes; HF curated Chinese architecture GLB.",
  "EntranceStairs source: 729,036 bytes; HF Wuxia Imperial model.",
 ]

 nature_manifest = json.loads(download(NATURE).read_text(encoding="utf-8"))
 nature_assets = nature_manifest.get("categories", {}).get("nature", {}).get("assets", [])
 boulder = next((item for item in nature_assets if item.get("asset_id") == "boulder_01" and item.get("validation", {}).get("validated") is True), None)
 if boulder is None or not boulder.get("file"):
  raise RuntimeError("Verified boulder_01 nature asset missing from approved manifest")
 boulder_path = download("assets/universal_nature_pack/" + boulder["file"])
 verify(boulder_path, boulder, "boulder_01")
 catalog["boulder_01"] = {"path": str(boulder_path), "kind": "nature"}
 print("ASSET_OK boulder_01")

 for asset_id, repo_path in CITY_MODELS.items():
  path = download(repo_path)
  if path.stat().st_size < 20 or path.read_bytes()[:4] != b"glTF":
   raise RuntimeError(f"Invalid required HF city model: {repo_path}")
  catalog[asset_id] = {"path": str(path), "kind": "twin_city_runtime"}
  print("TWIN_CITY_MODEL_OK:", asset_id, "bytes=", path.stat().st_size)

 for asset_id, repo_path in CANDIDATE_MODELS.items():
  path = download(repo_path)
  if path.stat().st_size < 20 or path.read_bytes()[:4] != b"glTF":
   raise RuntimeError(f"Invalid required HF candidate: {repo_path}")
  catalog[asset_id] = {"path": str(path), "kind": "eastern_architecture"}
  print("CANDIDATE_GLB_OK:", asset_id, "bytes=", path.stat().st_size)

 palace_path = download("settlement-terrain-source/curated-glb/architecture/imperial_china_palace_and_garden.glb")
 if palace_path.stat().st_size != 2876988 or palace_path.read_bytes()[:4] != b"glTF":
  raise RuntimeError("Imperial China palace source failed exact 2,876,988-byte/header verification")
 catalog["imperial_palace"] = {"path": str(palace_path), "kind": "imperial_palace"}
 catalog["tea_house"] = catalog["3dassets-feudal-japan-castle-town-tea-house-a168f962"]
 print("CHECKPOINT1_IMPERIAL_PALACE_SOURCE_OK: 2876988 bytes")

 objaverse_root = CACHE_ROOT / "objaverse-clean-glb"
 metadata_path = Path(hf_hub_download(repo_id=OBJAVERSE_REPO_ID, repo_type="dataset", filename="metadata.jsonl", local_dir=str(objaverse_root)))
 metadata_by_path = {}
 for line in metadata_path.read_text(encoding="utf-8").splitlines():
  if line.strip():
   row = json.loads(line)
   metadata_by_path[row.get("file_name", "")] = row
 credits.append("Objaverse Clean GLB (CodePawl), derived from Objaverse 1.0.")
 credits.append("Dataset: https://huggingface.co/datasets/codepawl/objaverse-clean-glb")
 for asset_id, repo_path in {**RESIDENTIAL, **LANDMARKS}.items():
  row = metadata_by_path.get(repo_path)
  if not row:
   raise RuntimeError(f"Objaverse attribution metadata missing: {repo_path}")
  if row.get("license") not in ("CC0-1.0", "CC-BY-4.0", "CC0", "CC-BY"):
   raise RuntimeError(f"Unsupported or missing model license for {repo_path}: {row.get('license')}")
  path = Path(hf_hub_download(repo_id=OBJAVERSE_REPO_ID, repo_type="dataset", filename=repo_path, local_dir=str(objaverse_root)))
  if path.stat().st_size < 20 or path.read_bytes()[:4] != b"glTF":
   raise RuntimeError(f"Invalid Objaverse GLB: {repo_path}")
  kind = "landmark_preview" if asset_id.startswith("landmark_") else "residential_building"
  catalog[asset_id] = {"path": str(path), "kind": kind}
  credits.append(f"{asset_id}: {row.get('title')} | author={row.get('authors')} | license={row.get('license')} | source={row.get('source_url')} | license_url={row.get('license_url')}.")
  print(f"OBJAVERSE_ASSET_OK: {asset_id} | {row.get('license')}")

 catalog["quest_hall"] = catalog["landmark_chinese_architecture"]
 print("CHECKPOINT1_EASTERN_QUEST_HALL_SOURCE_OK: verified Chinese architecture GLB")
 fetch_checkpoint_assets(catalog)
 Path("artifacts").mkdir(parents=True, exist_ok=True)
 Path("artifacts/landmark_sources.txt").write_text("\n".join(credits) + "\n", encoding="utf-8")
 output = CACHE_ROOT / "twin_city_runtime_assets.json"
 output.parent.mkdir(parents=True, exist_ok=True)
 output.write_text(json.dumps(catalog, indent=2), encoding="utf-8")
 print(f"TWIN_CITY_ASSET_CATALOG_OK: {len(catalog)} required runtime assets")
if __name__ == "__main__":
 main()
