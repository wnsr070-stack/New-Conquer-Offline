#!/usr/bin/env python3
"""Read-only inventory and download of architectural GLBs from the HF dataset."""
import json, re, sys, hashlib
from pathlib import Path
from huggingface_hub import HfApi, hf_hub_download

REPO = "ZzwahwahzZ/clash-of-legends-terrain-assets"
ROOT = Path(".cache/hf-assets")
OUT = Path("artifacts")
ROOT.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
api = HfApi()
repo_files = api.list_repo_files(repo_id=REPO, repo_type="dataset")
repo_files_set = set(repo_files)
manifest_paths = [
    "project-assets/wuxia_imperial_pack/manifest.json",
    "assets/wuxia_imperial_pack/manifest.json",
    "assets/universal_nature_pack/manifest.json",
]
records = []
manifest_counts = {}
for mp in manifest_paths:
    try:
        local = hf_hub_download(repo_id=REPO, repo_type="dataset", filename=mp, local_dir=str(ROOT))
        data = json.loads(Path(local).read_text(encoding="utf-8"))
        items = data.get("assets", [])
        manifest_counts[mp] = len(items)
        if "nature_pack" in mp:
            print("NATURE_MANIFEST_COUNT:", len(items))
            continue
        prefix = mp.rsplit("/", 1)[0] + "/"
        for item in items:
            rel = item.get("file", "")
            if rel.lower().endswith(".glb"):
                repo_path = prefix + rel
                if repo_path not in repo_files_set:
                    alternate = "assets/wuxia_imperial_pack/" + rel
                    if alternate in repo_files_set:
                        repo_path = alternate
                item2 = dict(item)
                item2["_repo_path"] = repo_path
                item2["_manifest"] = mp
                records.append(item2)
    except Exception as exc:
        print("MANIFEST_READ_WARNING:", mp, type(exc).__name__, str(exc)[:240])
print("MANIFEST_COUNTS:", json.dumps(manifest_counts, ensure_ascii=False, sort_keys=True))
print("PROJECT_MANIFEST_ASSET_COUNT:", manifest_counts.get("project-assets/wuxia_imperial_pack/manifest.json", -1))

# Include individual GLBs in the curated candidates directory, but only from this HF dataset.
for path in repo_files:
    if path.startswith("assets/wuxia_imperial_pack/candidates/models/") and path.lower().endswith(".glb"):
        records.append({"asset_id": Path(path).stem, "name": Path(path).stem, "category": "candidate_model",
                        "file": path.split("candidates/", 1)[-1], "_repo_path": path,
                        "_manifest": "candidate-directory"})

INCLUDE = ("palace","temple","shrine","pagoda","house","tea","hall","shop","castle","gate","paifang",
           "arch","forge","blacksmith","workshop","pavilion","building","market","inn","courtyard",
           "residence","tower","bridge","siheyuan","compound","kenney-building-kit","kenney-modular-buildings")
EXCLUDE = ("tree","bush","plant","flower","grass","rock","boulder","cliff","terrain","ground","floor",
           "road","path","dirt","water","river","mountain","vegetation","nature","fence","wall",
           "lantern","banner","bell","statue","sword","weapon","pistol","dragon","goblin","orc",
           "hydra","kraken","wyvern","phoenix","monster","prop","column","pillar","roof-tile")
def text_of(x):
    return " ".join(str(x.get(k, "")) for k in ("asset_id","name","category","twin_city_role","file","source")).lower()
def is_arch(x):
    s = text_of(x)
    if any(w in s for w in EXCLUDE):
        if not any(w in s for w in ("gate","paifang","moon-gate","bridge")):
            return False
    return any(w in s for w in INCLUDE)

# Deduplicate by exact Hub path. Keep manifest metadata over filename-only candidates.
by_path = {}
for item in records:
    path = item.get("_repo_path", "")
    if path and is_arch(item):
        if path not in by_path or item.get("_manifest") != "candidate-directory":
            by_path[path] = item
selected = sorted(by_path.values(), key=lambda x: (x.get("category",""), x.get("name",""), x["_repo_path"]))
print("ARCHITECTURAL_GLB_CANDIDATES:", len(selected))

catalog = {}
inventory = []
for i, item in enumerate(selected, 1):
    repo_path = item["_repo_path"]
    asset_id = re.sub(r"[^A-Za-z0-9_-]+", "_", item.get("asset_id") or Path(repo_path).stem)
    if asset_id in catalog:
        asset_id = asset_id + "_" + str(i)
    try:
        local = Path(hf_hub_download(repo_id=REPO, repo_type="dataset", filename=repo_path, local_dir=str(ROOT)))
        if local.stat().st_size < 20 or local.open("rb").read(4) != b"glTF":
            raise RuntimeError("invalid GLB header")
        catalog[asset_id] = {"path": str(local), "kind": item.get("category", "architecture")}
        inventory.append({
            "asset_id": asset_id, "name": item.get("name", Path(repo_path).stem),
            "category": item.get("category", "candidate_model"), "repo_path": repo_path,
            "file_name": Path(repo_path).name, "source": item.get("source", ""),
            "source_url": item.get("source_url", ""), "license": item.get("license", ""),
            "license_url": item.get("license_url", ""), "authors": item.get("authors", {}),
            "dimensions_m": item.get("dimensions_m", []), "bytes": local.stat().st_size,
            "manifest": item.get("_manifest", "")
        })
        print("ARCH_GLB_OK:", Path(repo_path).name)
    except Exception as exc:
        print("ARCH_GLB_SKIP:", repo_path, type(exc).__name__, str(exc)[:180])

(ROOT / "twin_city_runtime_assets.json").write_text(json.dumps(catalog, indent=2), encoding="utf-8")
(OUT / "building_inventory.json").write_text(json.dumps(inventory, indent=2, ensure_ascii=False), encoding="utf-8")

roles = {
 "imperial_palace": ["imperial china palace", "palace", "castle", "royal court", "throne"],
 "imperial_temple": ["temple", "shrine", "pagoda", "monastery", "sanctuary"],
 "quest_hall": ["siheyuan", "courtyard", "compound", "administrative hall", "ceremonial hall", "hall", "residence"],
 "tea_house": ["tea house", "tea-house", "teahouse", "tea", "pavilion", "inn"],
 "blacksmith_forge": ["blacksmith", "black-smith", "forge", "smithy", "workshop", "anvil", "furnace"],
 "honor_gate": ["paifang", "honor gate", "ceremonial gate", "moon gate", "gate", "arch"]
}
def score(item, terms):
    s = (item["name"] + " " + item["file_name"] + " " + item["category"] + " " + item["repo_path"]).lower().replace("_"," ").replace("-"," ")
    total = 0
    for term in terms:
        t = term.replace("_"," ").replace("-"," ")
        if t in s: total += 10 if " " in t else 4
    return total
shortlist = {}
lines = ["TWIN CITY — HF ARCHITECTURE INVENTORY", "Dataset: https://huggingface.co/datasets/" + REPO,
         "Read-only inspection; no assets inserted into TwinCity.gd.", "",
         "Manifest counts: " + json.dumps(manifest_counts, ensure_ascii=False, sort_keys=True),
         "Architectural GLBs successfully downloaded: " + str(len(inventory)), ""]
for role, terms in roles.items():
    ranked = sorted([(score(x, terms), x) for x in inventory], key=lambda z: (-z[0], z[1]["name"]))
    ranked = [x for x in ranked if x[0] > 0][:5]
    shortlist[role] = [{"score": sc, **it} for sc, it in ranked]
    lines.append("## " + role + (" — no lexical match" if not ranked else ""))
    if not ranked:
        lines.append("No candidate found by manifest/file-name metadata; visual search still needs manual review.")
    for rank, (sc, it) in enumerate(ranked, 1):
        dims = it.get("dimensions_m") or []
        dim_text = " | manifest dimensions=" + " × ".join(str(round(float(v),2)) for v in dims) + " m" if len(dims)==3 else ""
        lines.append(str(rank)+". "+it["file_name"]+" | "+it["category"]+" | "+it["repo_path"]+" | "+(it["license"] or "license metadata absent")+dim_text)
    lines.append("")
(OUT / "building_shortlist.json").write_text(json.dumps(shortlist, indent=2, ensure_ascii=False), encoding="utf-8")
(OUT / "building_inventory.txt").write_text("\n".join(lines + ["## Complete architectural file list"] + [
    str(i)+". "+x["file_name"]+" | "+x["category"]+" | "+x["repo_path"]+" | license="+(x["license"] or "not specified")
    for i,x in enumerate(inventory,1)]) + "\n", encoding="utf-8")
print("BUILDING_INVENTORY_COMPLETE:", len(inventory))
print("BUILDING_SHORTLIST_COMPLETE:", json.dumps({k:[x["file_name"] for x in v] for k,v in shortlist.items()}, ensure_ascii=False))
