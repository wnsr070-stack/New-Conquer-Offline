#!/usr/bin/env python3
"""Build, validate and render the exact 85-model Phase 3B progression pack."""
import hashlib, json, os, pathlib, shutil, subprocess, urllib.parse, urllib.request, urllib.error, posixpath, random, time, http.client

ROOT = pathlib.Path.cwd()
OUT = ROOT / "assets/phase3b"
CACHE = ROOT / ".cache/phase3b"
MODULAR_REPO = "agentkaerf/FreeModels"
MODULAR_REV = "db3df04d1e4714298a09510b26fb6de6645138a2"
MODULAR_PREFIX = "Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Modular Parts/"
TIERS = [
    ("beginner", "Beginner", 1, 29),
    ("steel", "Steel", 30, 59),
    ("royal", "Royal Legendary", 60, 110),
]

_DOWNLOAD_ATTEMPTS = 6
_RETRY_DELAYS = (2, 4, 8, 16, 32)
_RETRYABLE_HTTP_STATUS = {429, 500, 502, 503, 504}
def _valid_cached_file(path):
    path = pathlib.Path(path)
    if not path.is_file() or path.stat().st_size <= 0: return False
    suffix = path.suffix.lower()
    try:
        if suffix == ".glb":
            data = path.read_bytes()
            return len(data) >= 1000 and data[:4] == b"glTF" and int.from_bytes(data[8:12], "little") == len(data)
        if suffix == ".gltf":
            doc = json.loads(path.read_text(encoding="utf-8"))
            return isinstance(doc, dict) and isinstance(doc.get("asset"), dict)
        if suffix == ".zip":
            import zipfile
            return zipfile.is_zipfile(path)
        if suffix == ".obj":
            with path.open("r", encoding="utf-8", errors="ignore") as stream:
                return any(line.startswith(("v ", "f ")) for line in stream)
        if suffix in {".png", ".jpg", ".jpeg", ".webp", ".tga"}:
            head = path.read_bytes()[:12]
            return (head.startswith(b"\x89PNG\r\n\x1a\n") or head.startswith(b"\xff\xd8\xff") or
                    (head.startswith(b"RIFF") and head[8:12] == b"WEBP") or (suffix == ".tga" and len(head) == 12))
        return True
    except (OSError, ValueError, json.JSONDecodeError): return False

def download(url):
    headers = {"User-Agent": "New-Conquer-Offline-Phase3B/2.1 (+https://github.com/wnsr070-stack/New-Conquer-Offline)",
               "Accept": "application/octet-stream, application/vnd.github+json, */*"}
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    host = urllib.parse.urlparse(url).netloc.lower()
    if token and host in {"api.github.com", "raw.githubusercontent.com", "github.com"}:
        headers["Authorization"] = "Bearer " + token
    last_error = None
    for attempt in range(1, _DOWNLOAD_ATTEMPTS + 1):
        time.sleep(0.25)
        request = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                data = response.read()
            if not data: raise RuntimeError("Empty response: " + url)
            return data
        except urllib.error.HTTPError as error:
            last_error = error
            if error.code not in _RETRYABLE_HTTP_STATUS: raise
            if error.code == 503:
                print("PHASE3B_HTTP_503_RETRY:", f"attempt={attempt}/{_DOWNLOAD_ATTEMPTS}", "url=", url, flush=True)
        except (urllib.error.URLError, TimeoutError, ConnectionError, OSError, http.client.HTTPException) as error:
            last_error = error
        if attempt == _DOWNLOAD_ATTEMPTS: break
        base_delay = _RETRY_DELAYS[attempt - 1]
        delay = base_delay + random.uniform(0.0, max(0.25, base_delay * 0.25))
        print("PHASE3B_DOWNLOAD_RETRY:", f"attempt={attempt}/{_DOWNLOAD_ATTEMPTS}",
              "next_delay_seconds=", round(delay, 2), "url=", url, "error=", str(last_error), flush=True)
        time.sleep(delay)
    raise RuntimeError(f"download failed after {_DOWNLOAD_ATTEMPTS} attempts: {url}: {last_error}")

def valid_glb(path):
    path = pathlib.Path(path)
    data = path.read_bytes()
    if len(data) < 1000 or data[:4] != b"glTF" or int.from_bytes(data[8:12], "little") != len(data):
        raise RuntimeError("Invalid GLB: " + str(path))
    return len(data)

def fetch_modular_parts():
    target = CACHE / "modular_outfits"
    target.mkdir(parents=True, exist_ok=True)
    api = f"https://api.github.com/repos/{MODULAR_REPO}/git/trees/{MODULAR_REV}?recursive=1"
    tree = json.loads(download(api).decode("utf-8"))
    if tree.get("truncated"):
        raise RuntimeError("Pinned CC0 modular outfit tree was truncated")
    entries = {x["path"]: x for x in tree.get("tree", []) if x.get("type") == "blob"}
    wanted = [
        "Male_Ranger_Body.gltf", "Female_Ranger_Body.gltf",
        "Male_Peasant_Body.gltf", "Female_Peasant_Body.gltf",
        "Male_Ranger_Acc_Pauldron.gltf",
        "Male_Ranger_Head_Hood.gltf", "Female_Ranger_Head_Hood.gltf",
        "Male_Ranger_Feet_Boots.gltf",
    ]
    downloaded = set()
    raw_base = f"https://raw.githubusercontent.com/{MODULAR_REPO}/{MODULAR_REV}/"
    def fetch_path(path):
        if path in downloaded:
            return target / pathlib.PurePosixPath(path).relative_to(MODULAR_PREFIX)
        if not path.startswith(MODULAR_PREFIX) or path not in entries:
            raise RuntimeError("Missing pinned modular source dependency: " + path)
        dest = target / pathlib.PurePosixPath(path).relative_to(MODULAR_PREFIX)
        dest.parent.mkdir(parents=True, exist_ok=True)
        if _valid_cached_file(dest):
            print("PHASE3B_MODULAR_CACHE_HIT:", path, "bytes=", dest.stat().st_size, flush=True)
            downloaded.add(path)
            return dest
        if dest.exists(): dest.unlink()
        dest.write_bytes(download(raw_base + urllib.parse.quote(path, safe="/")))
        if not _valid_cached_file(dest):
            dest.unlink(missing_ok=True)
            raise RuntimeError("Downloaded modular dependency failed local validation: " + path)
        downloaded.add(path)
        return dest
    usable = {}
    failed = {}
    for name in wanted:
        full = MODULAR_PREFIX + name
        try:
            source = fetch_path(full)
            doc = json.loads(source.read_text(encoding="utf-8"))
            refs = []
            for section in ("buffers", "images"):
                for item in doc.get(section, []):
                    uri = item.get("uri", "")
                    if uri and not uri.startswith("data:"): refs.append((section, uri))
            for section, uri in refs:
                dependency = pathlib.PurePosixPath(posixpath.normpath(posixpath.join(posixpath.dirname(full), urllib.parse.unquote(uri)))).as_posix()
                try: fetch_path(dependency)
                except Exception as dependency_error:
                    suffix = pathlib.PurePosixPath(uri).suffix.lower()
                    if section == "images" or suffix in {".png", ".jpg", ".jpeg", ".webp", ".tga"}:
                        print("PHASE3B_OPTIONAL_TEXTURE_FALLBACK:", name, "texture=", uri, "warning=", str(dependency_error), flush=True)
                        continue
                    raise
            usable[name] = source
        except Exception as source_error:
            failed[name] = str(source_error)
            print("PHASE3B_MODULAR_PART_DOWNLOAD_WARNING:", name, "error=", str(source_error), flush=True)
    fallback_preferences = {
        "Male_Ranger_Body.gltf": ["Female_Ranger_Body.gltf", "Male_Peasant_Body.gltf", "Female_Peasant_Body.gltf"],
        "Female_Ranger_Body.gltf": ["Male_Ranger_Body.gltf", "Female_Peasant_Body.gltf", "Male_Peasant_Body.gltf"],
        "Male_Peasant_Body.gltf": ["Male_Ranger_Body.gltf", "Female_Peasant_Body.gltf", "Female_Ranger_Body.gltf"],
        "Female_Peasant_Body.gltf": ["Female_Ranger_Body.gltf", "Male_Peasant_Body.gltf", "Male_Ranger_Body.gltf"],
        "Male_Ranger_Acc_Pauldron.gltf": ["Male_Ranger_Body.gltf", "Male_Peasant_Body.gltf"],
        "Male_Ranger_Head_Hood.gltf": ["Female_Ranger_Head_Hood.gltf", "Male_Ranger_Body.gltf"],
        "Female_Ranger_Head_Hood.gltf": ["Male_Ranger_Head_Hood.gltf", "Female_Ranger_Body.gltf"],
        "Male_Ranger_Feet_Boots.gltf": ["Male_Ranger_Body.gltf", "Male_Peasant_Body.gltf"],
    }
    result = dict(usable)
    for name in wanted:
        if name in result: continue
        fallback = next((candidate for candidate in fallback_preferences.get(name, []) if candidate in usable), None)
        if fallback is None and usable: fallback = sorted(usable)[0]
        if fallback is None:
            raise RuntimeError("No valid cached/downloaded modular part can replace " + name + "; " + failed.get(name, "unknown source error"))
        result[name] = usable[fallback]
        print("PHASE3B_MODULAR_PART_FALLBACK:", "requested=", name, "using_real_model=", fallback, flush=True)
    print("PHASE3B_MODULAR_CC0_READY:", len(result), "model slots;", len(downloaded), "files;",
          "downloaded=", len(usable), "fallbacks=", len(failed), "repo=", MODULAR_REPO, "revision=", MODULAR_REV, flush=True)
    return result

def restore_hf_seed():
    token = os.environ.get("HF_TOKEN", "").strip()
    if not token:
        raise RuntimeError("HF_TOKEN is required to reuse the existing approved Phase 3B asset cache")
    from huggingface_hub import snapshot_download
    seed = pathlib.Path(snapshot_download(
        repo_id="ZzwahwahzZ/clash-of-legends-terrain-assets", repo_type="dataset", token=token,
        allow_patterns=["phase3b/quaternius_library/**", "phase3b/monsters/**"],
        local_dir=str(CACHE / "hf_seed")
    )) / "phase3b"
    copied = 0
    for folder in ("quaternius_library", "monsters"):
        source = seed / folder
        if not source.is_dir():
            continue
        for item in source.rglob("*"):
            if not item.is_file():
                continue
            destination = OUT / folder / item.relative_to(source)
            if not destination.exists():
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(item, destination)
                copied += 1
    print("PHASE3B_HF_EXISTING_ASSETS_REUSED:", copied, "files", flush=True)

def all_glbs(roots):
    found = []
    for root in roots:
        if root.exists():
            found.extend(p for p in root.rglob("*.glb") if p.is_file())
    return sorted(set(found), key=lambda p: str(p).lower())

def choose_model(roots, aliases, used=None, label="model"):
    used = used or set()
    candidates = all_glbs(roots)
    for alias in aliases:
        hits = [p for p in candidates if alias in p.stem.lower() and p not in used]
        if hits:
            hits.sort(key=lambda p: (len(p.stem), str(p).lower()))
            return hits[0]
    raise RuntimeError("No distinct real source model for " + label + "; tried " + repr(aliases))

def write_blender_batch(jobs, preview_dir):
    config = CACHE / "phase3b_85_jobs.json"
    script = CACHE / "phase3b_85_export_render.py"
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(json.dumps({"jobs": jobs, "preview_dir": str(preview_dir)}, indent=2), encoding="utf-8")
    script.write_text(r'''
import bpy, json, sys, os, math
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:]
cfg = json.load(open(args[0], encoding="utf-8"))
jobs = cfg["jobs"]
preview_dir = cfg["preview_dir"]
os.makedirs(preview_dir, exist_ok=True)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def set_tier_materials(tier):
    if tier == "beginner":
        tint, metallic, roughness = (0.48, 0.29, 0.14, 1.0), 0.16, 0.78
    elif tier == "steel":
        tint, metallic, roughness = (0.62, 0.72, 0.84, 1.0), 0.82, 0.29
    elif tier == "royal":
        tint, metallic, roughness = (0.94, 0.64, 0.16, 1.0), 0.96, 0.17
    else:
        return
    for mat in bpy.data.materials:
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            bsdf = nodes.new("ShaderNodeBsdfPrincipled")
            output = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None)
            if output is None:
                output = nodes.new("ShaderNodeOutputMaterial")
            links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
        base = bsdf.inputs["Base Color"]
        if base.is_linked:
            old = base.links[0]
            source = old.from_socket
            mix = nodes.new("ShaderNodeMixRGB")
            mix.blend_type = "MULTIPLY"
            mix.inputs["Fac"].default_value = 0.76
            mix.inputs["Color2"].default_value = tint
            links.remove(old)
            links.new(source, mix.inputs["Color1"])
            links.new(mix.outputs["Color"], base)
        else:
            base.default_value = tint
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        mat.diffuse_color = tint

def import_model(path):
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("Source GLB has no mesh: " + path)
    return meshes

def add_secondary(path):
    before = set(bpy.context.scene.objects)
    import_model(path)
    added = [o for o in bpy.context.scene.objects if o not in before]
    for obj in added:
        if obj.parent is None:
            obj.location.x += 0.22

def render_preview(job, index):
    scene = bpy.context.scene
    meshes = [o for o in scene.objects if o.type == "MESH"]
    points = []
    for obj in meshes:
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    if not points:
        raise RuntimeError("No mesh bounds for preview: " + job["id"])
    minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    center = (minimum + maximum) * 0.5
    extent = max((maximum - minimum).x, (maximum - minimum).y, (maximum - minimum).z, 0.25)
    bpy.ops.object.camera_add(location=center + Vector((extent * 2.7, extent * 1.8, extent * 3.4)))
    camera = bpy.context.object
    direction = center - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = extent * 2.5
    scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=center + Vector((extent * 1.8, extent * 2.4, extent * 1.5)))
    key = bpy.context.object
    key.data.energy = 1300
    key.data.shape = "DISK"
    key.data.size = extent * 2.2
    key.rotation_euler = (center - key.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.light_add(type="AREA", location=center + Vector((-extent * 1.8, extent * 0.5, extent)))
    fill = bpy.context.object
    fill.data.energy = 650
    fill.data.size = extent * 2.5
    fill.rotation_euler = (center - fill.location).to_track_quat("-Z", "Y").to_euler()
    engine_ids = [item.identifier for item in scene.render.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engine_ids else "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Phase3BPreviewWorld")
    scene.world.color = (0.055, 0.065, 0.08)
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    if background is not None:
        background.inputs["Color"].default_value = (0.055, 0.065, 0.08, 1.0)
    scene.view_settings.view_transform = "Standard"
    available_looks = [item.identifier for item in scene.view_settings.bl_rna.properties["look"].enum_items]
    scene.view_settings.look = "Medium High Contrast" if "Medium High Contrast" in available_looks else "None"
    scene.render.filepath = os.path.join(preview_dir, job["id"] + ".png")
    bpy.ops.render.render(write_still=True)
    output = scene.render.filepath
    if not os.path.isfile(output) or os.path.getsize(output) < 3000:
        raise RuntimeError("Preview image missing or too small: " + output)

for index, job in enumerate(jobs, 1):
    clear_scene()
    import_model(job["source"])
    if job.get("secondary"):
        add_secondary(job["secondary"])
    if job.get("dual"):
        original = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        for obj in original:
            dup = obj.copy()
            if obj.data:
                dup.data = obj.data.copy()
            bpy.context.collection.objects.link(dup)
            dup.location.x += 0.32
            dup.rotation_euler.z += math.pi
    set_tier_materials(job.get("tier", "natural"))
    if job.get("tier") != "natural":
        # Tiered models retain the source mesh while receiving a real PBR material treatment.
        for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
            if job.get("tier") == "royal":
                obj.scale *= 1.035
            elif job.get("tier") == "beginner":
                obj.scale *= 0.985
    if not job.get("render_only"):
        os.makedirs(os.path.dirname(job["dest"]), exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=job["dest"], export_format="GLB", export_apply=True)
        if not os.path.isfile(job["dest"]) or os.path.getsize(job["dest"]) < 1000:
            raise RuntimeError("GLB export failed: " + job["dest"])
    if job.get("dual") and not job.get("render_only"):
        for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
            dup = obj.copy()
            if obj.data:
                dup.data = obj.data.copy()
            bpy.context.collection.objects.link(dup)
            dup.location.x += 0.32
            dup.rotation_euler.z += math.pi
    render_preview(job, index)
    print("PHASE3B_85_MODEL_AND_PREVIEW_OK:", index, "/", len(jobs), job["id"], flush=True)
print("PHASE3B_85_BLENDER_EXPORT_RENDER_COMPLETE:", len(jobs), flush=True)
''', encoding="utf-8")
    proc = subprocess.run(
        ["blender", "--background", "--factory-startup", "--python-exit-code", "1",
         "--python", str(script), "--", str(config)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    )
    print("PHASE3B_85_BLENDER_LOG_BEGIN\n" + (proc.stdout or "") + "\nPHASE3B_85_BLENDER_LOG_END", flush=True)
    if proc.returncode:
        raise RuntimeError("Blender 85-model export/render failed: " + str(proc.returncode))

def build():
    character_specs = [
        ("Archer", "archer", "ara3d_archer.glb"),
        ("Assassin", "assassin", "ara3d_assassin.glb"),
        ("Trojan", "trojan", "ara3d_trojan.glb"),
        ("Warrior", "warrior", "ara3d_warrior.glb"),
        ("Taoist", "taoist", "ara3d_taoist.glb"),
    ]
    records = []
    hero_jobs = []
    for display, key, filename in character_specs:
        path = OUT / "characters" / filename
        size = valid_glb(path)
        hero_jobs.append({"id": "hero_" + key, "source": str(path), "tier": "natural", "dest": str(path), "render_only": True})
        records.append({
            "id": "hero_" + key, "name": display, "category": "character", "class": key,
            "file": path.relative_to(OUT).as_posix(), "level_min": 1, "level_max": 110,
            "source": "Ara 3D Gen 0.9.0 / MakeHuman CC0", "license": "CC0-1.0",
            "bytes": size, "preview": "previews/hero_" + key + ".png"
        })

    restore_hf_seed()
    weapon_roots = [OUT / "quaternius_library"]
    weapon_specs = [
        ("bow", "Bow", ["bow_wooden", "bow"], None, False),
        ("dual_knives", "Dual Knives", ["rogue_dagger", "dagger"], None, True),
        ("dual_blades", "Dual Blades", ["sword"], None, True),
        ("dual_axes", "Dual Axes", ["axe_double", "double_axe", "axe"], None, True),
        ("greatsword", "Greatsword", ["claymore", "greatsword", "sword_big"], None, False),
        ("spear_halberd", "Spear / Halberd", ["halberd", "spear"], None, False),
        ("shield", "Shield", ["shield_heater", "shield"], None, False),
        ("magic_staff", "Magic Staff", ["wizard_staff", "staff"], None, False),
        ("katana_shuriken", "Katana + Shuriken", ["katana"], ["shuriken"], False),
    ]
    used_weapon_sources = set()
    weapon_jobs = []
    for slug, display, aliases, secondary_aliases, dual in weapon_specs:
        source = choose_model(weapon_roots, aliases, used_weapon_sources, "weapon " + slug)
        used_weapon_sources.add(source)
        secondary = choose_model(weapon_roots, secondary_aliases, used_weapon_sources, "weapon companion " + slug) if secondary_aliases else None
        if secondary:
            used_weapon_sources.add(secondary)
        for tier, label, low, high in TIERS:
            relative = f"weapons/{slug}_{tier}.glb"
            asset_id = f"weapon_{slug}_{tier}"
            weapon_jobs.append({
                "id": asset_id, "source": str(source), "secondary": str(secondary) if secondary else None,
                "dual": dual, "tier": tier, "dest": str(OUT / relative)
            })
            records.append({
                "id": asset_id, "name": display + " — " + label, "category": "weapon",
                "weapon_class": slug, "tier": tier, "level_min": low, "level_max": high,
                "file": relative, "source": "Quaternius CC0",
                "license": "CC0-1.0", "source_license_url": "https://quaternius.com/packs/modularcharacteroutfitsfantasy.html", "preview": f"previews/{asset_id}.png"
            })

    modular = fetch_modular_parts()
    armor_sources = [
        ("body_01", "Ranger Male Chest", "Male_Ranger_Body.gltf"),
        ("body_02", "Ranger Female Chest", "Female_Ranger_Body.gltf"),
        ("body_03", "Peasant Male Chest", "Male_Peasant_Body.gltf"),
        ("body_04", "Peasant Female Chest", "Female_Peasant_Body.gltf"),
        ("body_05", "Ranger Pauldrons", "Male_Ranger_Acc_Pauldron.gltf"),
    ]
    helmet_sources = [
        ("helmet_01", "Ranger Male Hood", "Male_Ranger_Head_Hood.gltf"),
        ("helmet_02", "Ranger Female Hood", "Female_Ranger_Head_Hood.gltf"),
        ("helmet_03", "Quaternius Helmet I", None),
        ("helmet_04", "Quaternius Helmet II", None),
        ("helmet_05", "Quaternius Helmet III", None),
    ]
    modular_glbs = {}
    for filename, source in modular.items():
        dest = CACHE / "modular_glb" / (pathlib.Path(filename).stem + ".glb")
        dest.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["gltfpack", "-noq", "-i", str(source), "-o", str(dest)], check=True)
        valid_glb(dest)
        modular_glbs[filename] = dest

    armor_jobs = []
    for slug, display, filename in armor_sources:
        source = modular_glbs[filename]
        for tier, label, low, high in TIERS:
            asset_id = slug + "_" + tier
            relative = "armor/" + asset_id + ".glb"
            armor_jobs.append({"id": asset_id, "source": str(source), "tier": tier, "dest": str(OUT / relative)})
            records.append({
                "id": asset_id, "name": display + " — " + label, "category": "armor",
                "armor_slot": "body", "tier": tier, "level_min": low, "level_max": high,
                "file": relative, "source": "Quaternius Modular Character Outfits - Fantasy",
                "source_repo": MODULAR_REPO, "source_revision": MODULAR_REV,
                "license": "CC0-1.0", "preview": f"previews/{asset_id}.png"
            })
    helmet_candidates = [OUT / "quaternius_library"]
    for slug, display, filename in helmet_sources:
        if filename:
            source = modular_glbs[filename]
        else:
            qname = {"helmet_03": "helmet1_helmet1", "helmet_04": "helmet2_helmet2", "helmet_05": "helmet3_helmet3"}[slug]
            source = choose_model(helmet_candidates, [qname], label=display)
        for tier, label, low, high in TIERS:
            asset_id = slug + "_" + tier
            relative = "armor/" + asset_id + ".glb"
            armor_jobs.append({"id": asset_id, "source": str(source), "tier": tier, "dest": str(OUT / relative)})
            records.append({
                "id": asset_id, "name": display + " — " + label, "category": "armor",
                "armor_slot": "helmet", "tier": tier, "level_min": low, "level_max": high,
                "file": relative, "source": "Quaternius CC0",
                "license": "CC0-1.0", "preview": f"previews/{asset_id}.png"
            })
    boots_source = modular_glbs["Male_Ranger_Feet_Boots.gltf"]
    for tier, label, low, high in TIERS:
        asset_id = "boots_01_" + tier
        relative = "armor/" + asset_id + ".glb"
        armor_jobs.append({"id": asset_id, "source": str(boots_source), "tier": tier, "dest": str(OUT / relative)})
        records.append({
            "id": asset_id, "name": "Ranger Boots — " + label, "category": "armor",
            "armor_slot": "boots", "tier": tier, "level_min": low, "level_max": high,
            "file": relative, "source": "Quaternius Modular Character Outfits - Fantasy",
            "source_repo": MODULAR_REPO, "source_revision": MODULAR_REV,
            "license": "CC0-1.0", "preview": f"previews/{asset_id}.png"
        })

    monster_root = [OUT / "monsters"]
    normal_groups = [
        ("Twin City", 1, 20, [("bunny", "bunny"), ("chicken", "chicken"), ("dog", "dog")]),
        ("Desert City", 21, 40, [("cactoro", "cactoro"), ("orc", "orc"), ("demon", "demon")]),
        ("Phoenix Castle", 41, 60, [("ghost", "ghost"), ("blob", "spiky_blob"), ("dino", "dino")]),
        ("Bird Island", 61, 80, [("birb", "birb"), ("pigeon", "pigeon"), ("frog", "frog")]),
        ("Ape Mountain", 81, 110, [("yeti", "yeti"), ("alien", "alien"), ("armabee", "armabee")]),
    ]
    used_monsters = set()
    for city, low, high, specs in normal_groups:
        for key, alias in specs:
            source = choose_model(monster_root, [alias], used_monsters, "normal mob " + city + "/" + key)
            used_monsters.add(source)
            relative = "monsters/normal/" + key + ".glb"
            asset_id = "mob_" + key
            records.append({
                "id": asset_id, "name": key.replace("_", " ").title(), "category": "normal_mob",
                "city": city, "level_min": low, "level_max": high, "file": relative,
                "source": "Quaternius CC0", "license": "CC0-1.0",
                "preview": f"previews/{asset_id}.png"
            })
            weapon_jobs.append({"id": asset_id, "source": str(source), "tier": "natural",
                                "dest": str(OUT / relative)})
    boss_specs = [
        ("Twin City", "alpaking_evolved", "Alpaking Overlord", 1, 20),
        ("Desert City", "mushroom_king", "Mushroom King", 21, 40),
        ("Phoenix Castle", "blue_demon", "Blue Demon Lord", 41, 60),
        ("Bird Island", "orc_skull", "Orc Skull Warlord", 61, 80),
        ("Ape Mountain", "dragon_evolved", "Ancient Dragon", 81, 110),
    ]
    for city, alias, display, low, high in boss_specs:
        source = choose_model(monster_root, [alias], used_monsters, "boss " + display)
        used_monsters.add(source)
        relative = "monsters/bosses/" + alias + ".glb"
        asset_id = "boss_" + alias
        records.append({
            "id": asset_id, "name": display, "category": "boss", "city": city,
            "level_min": low, "level_max": high, "file": relative,
            "source": "Quaternius CC0", "license": "CC0-1.0",
            "preview": f"previews/{asset_id}.png"
        })
        weapon_jobs.append({"id": asset_id, "source": str(source), "tier": "natural",
                            "dest": str(OUT / relative)})

    jobs = hero_jobs + weapon_jobs + armor_jobs
    expected = {"character": 5, "weapon": 27, "armor": 33, "normal_mob": 15, "boss": 5}
    counts = {}
    for record in records:
        counts[record["category"]] = counts.get(record["category"], 0) + 1
    if counts != expected or len(records) != 85:
        raise RuntimeError("Exact 85-model count failed: " + json.dumps(counts, sort_keys=True))
    if len({record["file"] for record in records}) != 85:
        raise RuntimeError("85 manifest entries do not map to 85 unique GLB paths")

    preview_dir = OUT / "previews"
    write_blender_batch(jobs, preview_dir)
    for record in records:
        model = OUT / record["file"]
        record["bytes"] = valid_glb(model)
        record["sha256"] = hashlib.sha256(model.read_bytes()).hexdigest()
        preview = OUT / record["preview"]
        if not preview.is_file() or preview.stat().st_size < 3000:
            raise RuntimeError("Missing real preview image: " + str(preview))
        record["preview_bytes"] = preview.stat().st_size
    manifest = {
        "schema_version": 1, "project": "New Conquer Offline", "phase": "3B",
        "progression": "Lv.1-Lv.110", "expected_total": 85, "actual_total": 85,
        "counts": counts, "cities": ["Twin City", "Desert City", "Phoenix Castle", "Bird Island", "Ape Mountain"],
        "weapon_families": 9,
        "tiers": [{"id": t, "name": n, "levels": f"Lv.{lo}-Lv.{hi}"} for t, n, lo, hi in TIERS],
        "armor_slots": {"body": 15, "helmet": 15, "boots": 3},
        "sources": {
            "characters": "Ara 3D Gen 0.9.0 / MakeHuman CC0",
            "weapons_monsters": "Quaternius CC0",
            "armor": {"repo": MODULAR_REPO, "revision": MODULAR_REV, "license": "CC0-1.0",
                     "source_url": "https://quaternius.com/packs/modularcharacteroutfitsfantasy.html"}
        },
        "assets": records
    }
    (OUT / "phase3b_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    report = {
        "status": "validated", "expected_total": 85, "actual_total": 85,
        "counts": counts, "unique_model_paths": 85, "preview_images": 85,
        "all_glb_valid": True, "all_previews_nonempty": True,
        "manifest": "phase3b/phase3b_manifest.json"
    }
    (ROOT / "artifacts" / "phase3b_85_asset_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("PHASE3B_85_PACK_VALIDATED:", json.dumps(report, sort_keys=True), flush=True)

if __name__ == "__main__":
    build()
