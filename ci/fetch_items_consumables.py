#!/usr/bin/env python3
"""Fetch a pinned, sparse subset of CC0 Kenney and KayKit assets for loot/UI."""
from __future__ import annotations
import hashlib, json, os, pathlib, shutil, subprocess

ROOT = pathlib.Path("assets/items_and_consumables")
TMP = pathlib.Path(".cache/source-items")
SOURCES = {
    "kenney": ("https://github.com/shorepine/kenney.git", "3694c6879e487c108f55677be7dd2ca75b07cc3b",
               ["3d/food", "3d/fantasy-town", "3d/mini-dungeon", "3d/platformer", "3d/space",
                "3d/tower-defense", "3d/pirate", "3d/survival", "icons/Game Icons",
                "icons/Game Icons Expansion", "icons/Board Game Info/Fantasy (256px)", "LICENSE.txt", "README.md"]),
    "kaykit": ("https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0.git",
               "b0ca9bd96a8072ab36a3a5464f00ed1e06a16d07",
               ["addons/kaykit_dungeon_remastered/Assets/gltf",
                "addons/kaykit_dungeon_remastered/Assets/texture",
                "addons/kaykit_dungeon_remastered/Assets/LICENSE.txt", "LICENSE.txt", "README.md"]),
}
def run(args):
    subprocess.run(args, check=True)
def checkout(name, spec):
    url, revision, paths = spec
    dest = TMP / name
    if dest.exists(): shutil.rmtree(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    run(["git","clone","--filter=blob:none","--no-checkout","--depth","1",url,str(dest)])
    run(["git","-C",str(dest),"sparse-checkout","init","--cone"])
    run(["git","-C",str(dest),"sparse-checkout","set",*paths])
    run(["git","-C",str(dest),"checkout",revision])
    return dest
def copy_file(src, rel):
    dst = ROOT / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    data = dst.read_bytes()
    if not data: raise RuntimeError(f"empty asset: {src}")
    return {"path":str(dst).replace("\\","/"),"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()}
def main():
    if not os.environ.get("HF_TOKEN"): raise SystemExit("HF_TOKEN is required for approved asset upload")
    ROOT.mkdir(parents=True, exist_ok=True)
    sources = {name: checkout(name,spec) for name,spec in SOURCES.items()}
    copied=[]
    k=sources["kenney"]; y=sources["kaykit"]
    kenney_files = [
      ("3d/platformer/coin-gold.glb","models/gold_coin.glb"),
      ("3d/mini-dungeon/coin.glb","models/gold_coin_single.glb"),
      ("3d/mini-dungeon/chest.glb","models/treasure_chest.glb"),
      ("3d/pirate/bottle.glb","models/panacea_bottle.glb"),
      ("3d/space/meteor_detailed.glb","models/meteor.glb"),
      ("3d/tower-defense/detail-crystal-large.glb","models/dragon_gem_crystal.glb"),
      ("3d/tower-defense/detail-crystal.glb","models/upgrade_crystal.glb"),
      ("3d/platformer/arrow.glb","models/kenney_arrow_reference.glb"),
    ]
    for src,dst in kenney_files: copied.append(copy_file(k/src,dst))
    kaykit_files = [
      ("addons/kaykit_dungeon_remastered/Assets/gltf/coin_stack_medium.gltf.glb","models/gold_stack.glb"),
      ("addons/kaykit_dungeon_remastered/Assets/gltf/chest_gold.glb","models/gold_chest.glb"),
      ("addons/kaykit_dungeon_remastered/Assets/gltf/bottle_C_green.gltf.glb","models/potion_green_bottle.glb"),
      ("addons/kaykit_dungeon_remastered/Assets/gltf/bottle_C_brown.gltf.glb","models/potion_brown_bottle.glb"),
    ]
    for src,dst in kaykit_files: copied.append(copy_file(y/src,dst))
    # Keep source license notices with the imported assets.
    copied.append(copy_file(k/"LICENSE.txt","licenses/kenney/LICENSE.txt"))
    copied.append(copy_file(y/"addons/kaykit_dungeon_remastered/Assets/LICENSE.txt","licenses/kaykit-dungeon-remastered/LICENSE.txt"))
    # Kenney's 2x colored fantasy icon sheet is retained as the inventory-icon source set.
    icon_root=k/"icons/Game Icons Expansion/Colored"
    if icon_root.exists():
      for p in sorted(icon_root.rglob("*.png")):
        rel=p.relative_to(k)
        copied.append(copy_file(p,"icons/kenney_expansion/"+str(rel.relative_to("icons/Game Icons Expansion/Colored"))))
    fantasy=k/"icons/Board Game Info/Fantasy (256px)"
    if fantasy.exists():
      for p in sorted(fantasy.rglob("*.png")):
        copied.append(copy_file(p,"icons/kenney_fantasy/"+p.name))
    manifest={
      "schema":"clash-items-assets-v1",
      "sources":{
        "kenney":{"repo":"shorepine/kenney","commit":SOURCES["kenney"][1],"license":"CC0-1.0","license_file":"licenses/kenney/LICENSE.txt"},
        "kaykit_dungeon_remastered":{"repo":"KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0","commit":SOURCES["kaykit"][1],"license":"CC0-1.0","license_file":"licenses/kaykit-dungeon-remastered/LICENSE.txt"}
      },
      "assets":copied,
      "semantic_mapping":{
        "Gold":"models/gold_stack.glb",
        "Panacea":"models/potion_green_bottle.glb",
        "DragonGem":"models/dragon_gem_crystal.glb",
        "Meteor":"models/meteor.glb",
        "DragonBall":"models/upgrade_crystal.glb",
        "ToughDrill":"models/treasure_chest.glb",
        "Plus1Stone":"models/upgrade_crystal.glb"
      },
      "notes":["Visual mappings are representative CC0 models, not official Conquer-authored meshes.",
               "Conquer item prices/effects must be sourced from verified game data separately."]
    }
    out=ROOT/"asset_manifest.json"; out.write_text(json.dumps(manifest,indent=2)+"\n")
    print("PHASE4C_CC0_ITEMS_ASSETS_FETCHED:",len(copied),"files")
    print("PHASE4C_CC0_ITEMS_ASSET_MANIFEST_SHA256:",hashlib.sha256(out.read_bytes()).hexdigest())
    from huggingface_hub import HfApi
    api=HfApi(token=os.environ["HF_TOKEN"])
    repo_id="ZzwahwahzZ/clash-of-legends-terrain-assets"
    api.upload_folder(repo_id=repo_id,repo_type="dataset",folder_path=str(ROOT),
                      path_in_repo="project-assets/items_and_resources",
                      commit_message="Add pinned CC0 Kenney and KayKit item/loot assets")
    print("PHASE4C_CC0_ITEMS_HF_UPLOAD_OK:",repo_id+"/project-assets/items_and_resources")
if __name__=="__main__": main()
