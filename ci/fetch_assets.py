#!/usr/bin/env python3
"""Fetch approved nature and Twin City architecture; emit a runtime asset catalog."""
import hashlib, json
from pathlib import Path
from huggingface_hub import hf_hub_download, HfApi
REPO_ID = "ZzwahwahzZ/clash-of-legends-terrain-assets"
OBJAVERSE_REPO_ID = "codepawl/objaverse-clean-glb"
LANDMARKS = {
 "landmark_tea_house": "engine/teahouse-429e0904/teahouse-429e0904.glb",
 "landmark_quest_hall": "engine/chinese-temple-0ffd9067/chinese-temple-0ffd9067.glb",
 "landmark_forge_hall": "engine/stylized-chinese-blacksmith-adapted-d733793d/stylized-chinese-blacksmith-adapted-d733793d.glb",
}
CACHE_ROOT = Path(".cache/hf-assets")
NATURE = "assets/universal_nature_pack/imperial_approved_assets.json"
CITY = "assets/wuxia_imperial_pack/twin_city_selected_17_assets.json"
IMPERIAL = "assets/wuxia_imperial_pack/manifest.json"
CURATED = "settlement-terrain-source/curated-glb/curated_glb_manifest.json"
SHOWCASE = {"boulder_01", "mountainside", "dead_tree_trunk"}
CC0 = {
 "settlement-terrain-source/curated-glb/nature/alpine_and_arctic_biomes.glb",
 "settlement-terrain-source/curated-glb/nature/date_palm.glb",
 "settlement-terrain-source/curated-glb/nature/willow_tree.glb",
}
CANDIDATE_PREFIXES = (
 "3dassets-feudal-japan-castle-town-", "3dassets-alpine-snow-village-",
 "3dassets-royal-court-and-throne-palace-", "opengameart-kenney-building-kit",
 "opengameart-kenney-modular-buildings", "opengameart-modular-temple-3d-models",
 "opengameart-modular-temple-3d-models-2", "opengameart-3d-walls-props",
 "opengameart-basic-wooden-fence", "opengameart-stone-bridge-",
 "opengameart-wooden-bridge-",
)
def download(name):
 return Path(hf_hub_download(repo_id=REPO_ID, repo_type="dataset", filename=name, local_dir=str(CACHE_ROOT)))
def digest(path):
 h=hashlib.sha256()
 with path.open("rb") as f:
  for chunk in iter(lambda:f.read(1024*1024), b""): h.update(chunk)
 return h.hexdigest()
def verify(path, item, label):
 if item.get("bytes") is not None and path.stat().st_size != int(item["bytes"]):
  raise RuntimeError(f"Size mismatch: {label}")
 if item.get("sha256") and digest(path) != item["sha256"]:
  raise RuntimeError(f"SHA256 mismatch: {label}")
 if path.stat().st_size < 20 or path.read_bytes()[:4] != b"glTF":
  raise RuntimeError(f"Invalid GLB header: {label}")
def main():
 catalog={}
 approved=json.loads(download(NATURE).read_text(encoding="utf-8"))
 nature=approved.get("categories",{}).get("nature",{}).get("assets",[])
 valid=[x for x in nature if x.get("validation",{}).get("validated") is True and x.get("file")]
 valid.sort(key=lambda x:x.get("asset_id",""))
 by_id={x["asset_id"]:x for x in valid}
 if SHOWCASE-set(by_id): raise RuntimeError(f"Boot models missing: {sorted(SHOWCASE-set(by_id))}")
 chosen=[by_id[x] for x in sorted(SHOWCASE)]
 chosen_ids={x["asset_id"] for x in chosen}
 chosen.extend(x for x in valid if x["asset_id"] not in chosen_ids)
 chosen=chosen[:38]
 if len(chosen)!=38: raise RuntimeError(f"Expected 38 validated nature assets; found {len(chosen)}")
 for item in chosen:
  repo_path=f"assets/universal_nature_pack/{item['file']}"
  path=download(repo_path); verify(path,item,repo_path)
  catalog[item["asset_id"]]={"path":str(path),"kind":"nature"}
  print(f"ASSET_OK {item['asset_id']}")
 curated=json.loads(download(CURATED).read_text(encoding="utf-8"))
 records={x.get("hf_path"):x for x in curated.get("assets",[])}
 for repo_path in sorted(CC0):
  item=records.get(repo_path)
  if not item or item.get("license")!="CC0 1.0 Universal": raise RuntimeError(f"CC0 license metadata missing: {repo_path}")
  path=download(repo_path); verify(path,item,repo_path)
  catalog[Path(repo_path).stem]={"path":str(path),"kind":"nature"}
 city=json.loads(download(CITY).read_text(encoding="utf-8"))
 selected=city.get("assets",[])
 for item in selected:
  rel=item.get("file","")
  if not rel.endswith(".glb"): continue
  repo_path=f"assets/wuxia_imperial_pack/{rel}"
  path=download(repo_path); verify(path,item,repo_path)
  catalog[item["asset_id"]]={"path":str(path),"kind":item.get("role",item.get("category","architecture"))}
 imperial=json.loads(download(IMPERIAL).read_text(encoding="utf-8"))
 for category in imperial.get("assets",[]):
  if not category.get("twin_city_approved") and not category.get("twin_city_geometry_verified"): continue
  rel=category.get("file","")
  if not rel.endswith(".glb"): continue
  repo_path=f"assets/wuxia_imperial_pack/{rel}"
  path=download(repo_path); verify(path,category,repo_path)
  catalog[category["asset_id"]]={"path":str(path),"kind":category.get("twin_city_role",category.get("category","architecture"))}
 api=HfApi()
 files=api.list_repo_files(repo_id=REPO_ID,repo_type="dataset")
 candidates=[x for x in files if x.startswith("assets/wuxia_imperial_pack/candidates/models/") and x.endswith(".glb") and Path(x).name.startswith(CANDIDATE_PREFIXES)]
 for repo_path in candidates:
  path=download(repo_path)
  if path.stat().st_size < 20 or path.read_bytes()[:4] != b"glTF": raise RuntimeError(f"Invalid candidate GLB: {repo_path}")
  catalog[Path(repo_path).stem]={"path":str(path),"kind":"candidate"}
  print(f"CANDIDATE_GLB_OK {Path(repo_path).name}")
 objaverse_root = CACHE_ROOT / "objaverse-clean-glb"
 metadata_path = Path(hf_hub_download(repo_id=OBJAVERSE_REPO_ID, repo_type="dataset",
  filename="metadata.jsonl", local_dir=str(objaverse_root)))
 metadata_by_path = {}
 for line in metadata_path.read_text(encoding="utf-8").splitlines():
  if not line.strip(): continue
  row = json.loads(line)
  metadata_by_path[row.get("file_name","")] = row
 credits = ["Objaverse Clean GLB (CodePawl), derived from Objaverse 1.0.",
  "Dataset: https://huggingface.co/datasets/codepawl/objaverse-clean-glb"]
 for asset_id, repo_path in LANDMARKS.items():
  row = metadata_by_path.get(repo_path)
  if not row: raise RuntimeError(f"Objaverse attribution metadata missing: {repo_path}")
  if row.get("license") not in ("CC0-1.0", "CC-BY-4.0", "CC0", "CC-BY"):
   raise RuntimeError(f"Unsupported or missing landmark license for {repo_path}: {row.get('license')}")
  path = Path(hf_hub_download(repo_id=OBJAVERSE_REPO_ID, repo_type="dataset",
   filename=repo_path, local_dir=str(objaverse_root)))
  if path.stat().st_size < 20 or path.read_bytes()[:4] != b"glTF":
   raise RuntimeError(f"Invalid landmark GLB: {repo_path}")
  catalog[asset_id] = {"path": str(path), "kind": "architecture"}
  credits.append(f"{asset_id}: {row.get('title')} | author={row.get('authors')} | license={row.get('license')} | source={row.get('source_url')} | license_url={row.get('license_url')} | engine-tier GLB used for preview.")
  print(f"LANDMARK_ASSET_OK: {asset_id} | {row.get('title')} | {row.get('license')}")
 Path("artifacts").mkdir(parents=True, exist_ok=True)
 Path("artifacts/landmark_sources.txt").write_text("\n".join(credits) + "\n", encoding="utf-8")
 out=Path(".cache/hf-assets/twin_city_runtime_assets.json")
 out.parent.mkdir(parents=True,exist_ok=True)
 out.write_text(json.dumps(catalog,indent=2),encoding="utf-8")
 print(f"TWIN_CITY_ASSET_CATALOG_OK: {len(catalog)} entries; candidates={len(candidates)}")
if __name__=="__main__": main()
