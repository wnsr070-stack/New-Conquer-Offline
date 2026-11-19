#!/usr/bin/env python3
"""Download the five approved landmark GLBs on a GitLab shared runner."""
import base64
import hashlib
import os
import subprocess
from pathlib import Path
from huggingface_hub import hf_hub_download

OUT = Path("artifacts/five_buildings")
OUT.mkdir(parents=True, exist_ok=True)

SOURCES = {
    "imperial_palace.glb": None,
    "tea_house.glb": "https://grab3d.com/dl/tea-house/tea-house.glb",
    "ceremonial_temple_hall.glb": "https://cdn.3dassets.dev/assets/36163/v1/model.glb",
    "quest_governor_hall.glb": "https://polyfork.dev/cdn/governor-s-audience-hall-a4d777.glb",
    "blacksmith_forge.glb": "https://tevy.dev/models/blacksmith-forge/v1/lod0.glb",
}
PALACE_REPO = "ZzwahwahzZ/clash-of-legends-terrain-assets"
PALACE_FILE = "assets/wuxia_imperial_pack/candidates/models/3dassets-royal-court-and-throne-palace-palace-audience-house-55f0cb24.glb"

def valid_glb(path):
    if path.stat().st_size < 20 or path.read_bytes()[:4] != b"glTF":
        raise RuntimeError(f"Invalid GLB file: {path.name}")

def main():
    palace = hf_hub_download(
        repo_id=PALACE_REPO, repo_type="dataset", filename=PALACE_FILE,
        token=os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACEHUB_API_TOKEN"),
    )
    target = OUT / "imperial_palace.glb"
    target.write_bytes(Path(palace).read_bytes())

    manifest = []
    for name, url in SOURCES.items():
        path = OUT / name
        if url:
            subprocess.run(
                ["curl", "--fail", "--location", "--retry", "3", "--retry-all-errors",
                 "--connect-timeout", "30", "--max-time", "600", url, "-o", str(path)],
                check=True,
            )
        valid_glb(path)
        data = path.read_bytes()
        sha = hashlib.sha256(data).hexdigest()
        manifest.append(f"{name}\t{len(data)}\t{sha}")
        print(f"BUILDING_OK {name} bytes={len(data)} sha256={sha}", flush=True)
        encoded = base64.b64encode(data).decode("ascii")
        print(f"FILE_BEGIN:{name}:{len(data)}:{sha}", flush=True)
        for start in range(0, len(encoded), 65536):
            print("B64:" + encoded[start:start+65536], flush=True)
        print(f"FILE_END:{name}", flush=True)

    (OUT / "SHA256SUMS.txt").write_text("\n".join(manifest) + "\n", encoding="utf-8")
    print("FIVE_BUILDINGS_DOWNLOAD_AND_GLTF_HEADER_CHECK_OK", flush=True)

if __name__ == "__main__":
    main()
