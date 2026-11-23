#!/usr/bin/env python3
"""Generate five rigged, high-detail CC0 MakeHuman characters with Ara 3D Gen."""
import json, pathlib, struct, subprocess, tempfile

ROOT = pathlib.Path.cwd()
OUT = ROOT / "assets/phase3b/characters"
REPORT = OUT / "character_quality_report.json"
ARA_VERSION = "0.9.0"
PROFILES = [
    ("ara3d_archer.glb", "The Adventurer", "Archer / Eastern ranger"),
    ("ara3d_assassin.glb", "The Yoruba Warrior", "Oriental assassin / dual blades"),
    ("ara3d_trojan.glb", "The Dahomey Warrior", "Trojan / heavy dual weapons"),
    ("ara3d_warrior.glb", "The Soldier", "Warrior / spear and shield"),
    ("ara3d_taoist.glb", "The Explorer", "Taoist / staff bearer"),
]

def read_glb(path):
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise RuntimeError(f"Not a GLB: {path}")
    offset = 12
    while offset + 8 <= len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset:offset+length]
        offset += length
        if kind == 0x4E4F534A:
            return json.loads(chunk.decode("utf-8").rstrip(" \0"))
    raise RuntimeError(f"GLB JSON chunk missing: {path}")

def inspect(path):
    doc = read_glb(path)
    accessors = doc.get("accessors", [])
    triangles = 0
    for mesh in doc.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if primitive.get("mode", 4) != 4:
                continue
            if "indices" in primitive:
                count = accessors[primitive["indices"]].get("count", 0)
            else:
                count = accessors[primitive["attributes"]["POSITION"]].get("count", 0)
            triangles += count // 3
    names = {n.get("name", "") for n in doc.get("nodes", [])}
    joints = set()
    for skin in doc.get("skins", []):
        for index in skin.get("joints", []):
            if index < len(doc.get("nodes", [])):
                joints.add(doc["nodes"][index].get("name", ""))
    all_names = names | joints
    return {
        "triangles": triangles,
        "node_count": len(doc.get("nodes", [])),
        "skin_count": len(doc.get("skins", [])),
        "weapon_socket": "WeaponR" in all_names,
        "weapon_socket_names": sorted(n for n in all_names if "weapon" in n.lower()),
        "bytes": path.stat().st_size,
    }

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    report = {
        "generator": "Ara 3D Gen CLI",
        "generator_version": ARA_VERSION,
        "generator_license": "MIT",
        "base_asset_license": "CC0 1.0 Universal (MakeHuman dataset)",
        "base_asset_license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "commercial_use": "Permitted; Ara exports may be used commercially without attribution.",
        "animation_license": "No animations exported; CMU motion-capture terms do not apply.",
        "detail": "high",
        "rig": "game",
        "profiles": [],
        "errors": [],
    }
    for filename, preset, role in PROFILES:
        with tempfile.TemporaryDirectory(prefix="ara3d-phase3b-") as temp:
            tempdir = pathlib.Path(temp)
            command = [
                "npx", "--yes", f"ara3d@{ARA_VERSION}", "export",
                "--preset", preset, "--formats", "glb", "--detail", "high",
                "--no-animations", "--out", str(tempdir),
            ]
            print("PHASE3B_AR3D_GENERATE:", role, "preset=", preset, flush=True)
            subprocess.run(command, check=True, cwd=ROOT)
            generated = sorted(tempdir.glob("*.glb"))
            if len(generated) != 1:
                raise RuntimeError(f"Expected one GLB for {preset}, got {[p.name for p in generated]}")
            destination = OUT / filename
            subprocess.run(["gltfpack", "-noq", "-i", str(generated[0]), "-o", str(destination)], check=True)
        metrics = inspect(destination)
        record = {"file": filename, "preset": preset, "role": role, **metrics}
        report["profiles"].append(record)
        print("PHASE3B_AR3D_QUALITY:", json.dumps(record, sort_keys=True), flush=True)
        if metrics["triangles"] <= 5000:
            raise RuntimeError(f"{filename} has only {metrics['triangles']} triangles")
        if metrics["skin_count"] < 1 or not metrics["weapon_socket"]:
            raise RuntimeError(f"{filename} missing rig/WeaponR socket: {metrics}")
    if len(report["profiles"]) != 5:
        raise RuntimeError("Five character profiles were not generated")
    REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("PHASE3B_FIVE_HIGH_DETAIL_CHARACTERS_COMPLETE", flush=True)

if __name__ == "__main__":
    main()
