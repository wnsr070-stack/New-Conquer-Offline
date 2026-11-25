#!/usr/bin/env python3
"""Fetch pinned CC0 Kenney + KayKit GLB/icon assets, inventory them, and publish to HF."""
import hashlib, json, os, pathlib, shutil, subprocess, tempfile
from huggingface_hub import HfApi

ROOT = pathlib.Path("assets/items_and_consumables")
TMP = pathlib.Path(".cache/cc0-consumables")
KENNEY_SHA = "3694c6879e487c108f55677be7dd2ca75b07cc3b"
KAYKIT_SHA = "b0ca9bd96a8072ab36a3a5464f00ed1e06a16d07"

def checkout(url, sha, name, sparse):
    dest = TMP / name
    if dest.exists():
        shutil.rmtree(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git","clone","--filter=blob:none","--no-checkout",url,str(dest)],check=True)
    subprocess.run(["git","-C",str(dest),"sparse-checkout","init","--cone"],check=True)
    subprocess.run(["git","-C",str(dest),"sparse-checkout","set",*sparse],check=True)
    subprocess.run(["git","-C",str(dest),"checkout",sha],check=True)
    return dest

def copy_tree(source, target, include_ext=None):
    target.mkdir(parents=True,exist_ok=True)
    for p in source.rglob("*"):
        if not p.is_file(): continue
        if include_ext and p.suffix.lower() not in include_ext: continue
        rel=p.relative_to(source)
        out=target/rel
        out.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(p,out)

def main():
    if ROOT.exists(): shutil.rmtree(ROOT)
    (ROOT/"models").mkdir(parents=True)
    (ROOT/"icons").mkdir(parents=True)
    kenney=checkout("https://github.com/shorepine/kenney.git",KENNEY_SHA,"kenney",[
        "3d/mini-dungeon","3d/pirate","3d/survival","3d/food","3d/graveyard",
        "icons/Game Icons Expansion/Black/2x"])
    kaykit=checkout("https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0.git",KAYKIT_SHA,"kaykit",[
        "addons/kaykit_dungeon_remastered/Assets/gltf","addons/kaykit_dungeon_remastered/Assets/LICENSE.txt","LICENSE.txt"])
    copy_tree(kenney/"3d",ROOT/"models/kenney",{".glb"})
    copy_tree(kenney/"icons/Game Icons Expansion/Black/2x",ROOT/"icons/kenney-game-icons",{".png"})
    copy_tree(kaykit/"addons/kaykit_dungeon_remastered/Assets/gltf",ROOT/"models/kaykit",{".glb"})
    shutil.copy2(kenney/"LICENSE.txt",ROOT/"KENNEY-LICENSE.txt")
    shutil.copy2(kaykit/"LICENSE.txt",ROOT/"KAYKIT-LICENSE.txt")
    files=[]
    for p in sorted(ROOT.rglob("*")):
        if p.is_file() and p.name not in {"asset_manifest.json"}:
            data=p.read_bytes()
            files.append({"path":p.relative_to(ROOT).as_posix(),"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()})
    manifest={
        "schema":"clash-items-cc0-v1",
        "destination":"res://assets/items_and_consumables/",
        "sources":[
            {"name":"Kenney CC0 game assets","repository":"https://github.com/shorepine/kenney","commit":KENNEY_SHA,"license":"CC0-1.0","included":["3d/mini-dungeon","3d/pirate","3d/survival","3d/food","3d/graveyard","icons/Game Icons Expansion/Black/2x"]},
            {"name":"KayKit Dungeon Remastered 1.0","repository":"https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0","commit":KAYKIT_SHA,"license":"CC0-1.0","included":["addons/kaykit_dungeon_remastered/Assets/gltf"]}
        ],
        "file_count":len(files),"files":files,
        "note":"Source assets are preserved with their original filenames. No item is assigned an official Conquer Online price/effect unless supported by a separate verified game-data source."
    }
    (ROOT/"asset_manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    print(f"PHASE4C_CC0_ASSET_BUNDLE_READY: files={len(files)} glb={sum(x['path'].endswith('.glb') for x in files)} png={sum(x['path'].endswith('.png') for x in files)}")
    token=os.environ.get("HF_TOKEN")
    if not token: raise SystemExit("HF_TOKEN secret is required to publish the approved CC0 bundle")
    api=HfApi(token=token)
    api.upload_folder(repo_id="ZzwahwahzZ/clash-of-legends-terrain-assets",repo_type="dataset",
        folder_path=str(ROOT),path_in_repo="project-assets/items_and_resources/cc0_bundle",
        commit_message="Add pinned Kenney and KayKit CC0 consumable and loot source assets")
    print("PHASE4C_CC0_ASSET_BUNDLE_HF_UPLOAD_OK: ZzwahwahzZ/clash-of-legends-terrain-assets/project-assets/items_and_resources/cc0_bundle")
if __name__=="__main__": main()
