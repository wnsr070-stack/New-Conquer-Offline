#!/usr/bin/env python3
"""Fetch and verify 38 approved nature assets plus three CC0 models."""
import hashlib, json
from pathlib import Path
from huggingface_hub import hf_hub_download
REPO_ID = "ZzwahwahzZ/clash-of-legends-terrain-assets"
CACHE_ROOT = Path(".cache/hf-assets")
APPROVED = "assets/universal_nature_pack/imperial_approved_assets.json"
CURATED = "settlement-terrain-source/curated-glb/curated_glb_manifest.json"
SHOWCASE = {"boulder_01", "mountainside", "dead_tree_trunk"}
CC0 = {
 "settlement-terrain-source/curated-glb/nature/alpine_and_arctic_biomes.glb",
 "settlement-terrain-source/curated-glb/nature/date_palm.glb",
 "settlement-terrain-source/curated-glb/nature/willow_tree.glb",
}
def download(name):
 return Path(hf_hub_download(repo_id=REPO_ID, repo_type="dataset", filename=name, local_dir=str(CACHE_ROOT)))
def digest(path):
 h=hashlib.sha256()
 with path.open("rb") as f:
  for chunk in iter(lambda:f.read(1024*1024), b""): h.update(chunk)
 return h.hexdigest()
def main():
 approved=json.loads(download(APPROVED).read_text(encoding="utf-8"))
 nature=approved.get("categories",{}).get("nature",{}).get("assets",[])
 valid=[x for x in nature if x.get("validation",{}).get("validated") is True and x.get("file")]
 valid.sort(key=lambda x:x.get("asset_id",""))
 by_id={x["asset_id"]:x for x in valid}
 if SHOWCASE-set(by_id): raise RuntimeError(f"Boot models missing from approved manifest: {sorted(SHOWCASE-set(by_id))}")
 chosen=[by_id[x] for x in sorted(SHOWCASE)]
 chosen_ids={x["asset_id"] for x in chosen}
 chosen.extend(x for x in valid if x["asset_id"] not in chosen_ids)
 chosen=chosen[:38]
 if len(chosen)!=38: raise RuntimeError(f"Expected 38 validated nature assets; found {len(chosen)}")
 for item in chosen:
  repo_path=f"assets/universal_nature_pack/{item['file']}"
  path=download(repo_path)
  if path.stat().st_size!=int(item.get("bytes",-1)): raise RuntimeError(f"Size mismatch: {repo_path}")
  if item.get("sha256") and digest(path)!=item["sha256"]: raise RuntimeError(f"SHA256 mismatch: {repo_path}")
  print(f"ASSET_OK {item['asset_id']} {path.stat().st_size}")
 curated=json.loads(download(CURATED).read_text(encoding="utf-8"))
 records={x.get("hf_path"):x for x in curated.get("assets",[])}
 for repo_path in sorted(CC0):
  item=records.get(repo_path)
  if not item or item.get("license")!="CC0 1.0 Universal": raise RuntimeError(f"CC0 license metadata missing: {repo_path}")
  path=download(repo_path)
  if path.stat().st_size!=int(item["bytes"]) or digest(path)!=item["sha256"]: raise RuntimeError(f"Integrity failure: {repo_path}")
  print(f"CC0_ASSET_OK {repo_path}")
 print(f"ASSET_FETCH_COMPLETE: {len(chosen)} approved nature assets + {len(CC0)} CC0 assets")
if __name__=="__main__": main()
