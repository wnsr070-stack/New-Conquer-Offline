#!/usr/bin/env python3
"""Build, validate and render the exact 85-model Phase 3B progression pack."""
import hashlib, json, os, pathlib, shutil, subprocess, urllib.parse, urllib.request, urllib.error, posixpath, random, time, http.client

ROOT = pathlib.Path.cwd()
OUT = ROOT / "assets/phase3b"
CACHE = ROOT / ".cache/phase3b"
MODULAR_REPO = "agentkaerf/FreeModels"
MODULAR_REV = "db3df04d1e4714298a09510b26fb6de6645138a2"
QUATERNIUS_HEAD_REPO = "trebeljahr/quaternius-showcase"
QUATERNIUS_HEAD_REV = "0128ca510d653bb04d6d1e4885bd8890b5050b4f"
OUTFITS_PREFIX = "Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits/"
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

def fetch_complete_outfits():
    """Fetch only the four complete CC0 Outfits; never traverse Modular Parts."""
    target = CACHE / "complete_outfits"
    target.mkdir(parents=True, exist_ok=True)
    api = f"https://api.github.com/repos/{MODULAR_REPO}/git/trees/{MODULAR_REV}?recursive=1"
    tree = json.loads(download(api).decode("utf-8"))
    if tree.get("truncated"): raise RuntimeError("Pinned CC0 complete-outfit tree was truncated")
    entries = {x["path"]: x for x in tree.get("tree", []) if x.get("type") == "blob"}
    names = ["Male_Ranger.gltf", "Female_Ranger.gltf", "Male_Peasant.gltf", "Female_Peasant.gltf"]
    raw_base = f"https://raw.githubusercontent.com/{MODULAR_REPO}/{MODULAR_REV}/"
    downloaded = set()
    def fetch_path(path):
        if not path.startswith(OUTFITS_PREFIX) or "Modular Parts" in path:
            raise RuntimeError("Refusing non-Outfits CC0 dependency: " + path)
        if path not in entries: raise RuntimeError("Missing complete-outfit dependency: " + path)
        dest = target / pathlib.PurePosixPath(path).relative_to(OUTFITS_PREFIX)
        dest.parent.mkdir(parents=True, exist_ok=True)
        if not _valid_cached_file(dest):
            dest.unlink(missing_ok=True)
            dest.write_bytes(download(raw_base + urllib.parse.quote(path, safe="/")))
        if not _valid_cached_file(dest):
            dest.unlink(missing_ok=True)
            raise RuntimeError("Invalid complete-outfit dependency: " + path)
        downloaded.add(path)
        return dest
    result = {}
    for name in names:
        full = OUTFITS_PREFIX + name
        source = fetch_path(full)
        doc = json.loads(source.read_text(encoding="utf-8"))
        if not doc.get("meshes") or not doc.get("skins"): raise RuntimeError("Complete outfit lacks mesh geometry or skin: " + name)
        joints = [doc.get("nodes", [])[i].get("name", "") for i in doc["skins"][0].get("joints", [])]
        right = next((x for x in joints if x.lower() == "hand_r"), "")
        left = next((x for x in joints if x.lower() == "hand_l"), "")
        if len(joints) < 60 or not right or not left:
            raise RuntimeError("Complete outfit must expose 60+ joints and exact hand_r/hand_l bones: " + name)
        deps = []
        for section in ("buffers", "images"):
            for item in doc.get(section, []):
                uri = item.get("uri", "")
                if uri and not uri.startswith("data:"):
                    deps.append(pathlib.PurePosixPath(posixpath.normpath(posixpath.join(posixpath.dirname(full), urllib.parse.unquote(uri)))).as_posix())
        for dep in deps: fetch_path(dep)
        result[name] = source
        print("PHASE3B_COMPLETE_CC0_OUTFIT_VALIDATED:", name, "meshes=", len(doc["meshes"]), "joints=", len(joints), "right_hand=", right, "left_hand=", left, flush=True)
    print("PHASE3B_COMPLETE_CC0_OUTFITS_READY:", len(result), "models;", len(downloaded), "files; source=", MODULAR_REPO, "revision=", MODULAR_REV, flush=True)
    return result

def fetch_quaternius_modular_heads():
    """Fetch only verified Adventurer head/face/hair meshes from the independent CC0 Men/Women packs.

    Source allowlist is limited to the two pinned public/glb/modular_{men,women}/Adventurer.glb files.
    """
    target = CACHE / "quaternius_modular_heads"
    target.mkdir(parents=True, exist_ok=True)
    specs = {
        "male": {"path": "public/glb/modular_men/Adventurer.glb", "size": 1272560, "blob_sha": "14456cd24345ad437840365396b60e82af653507", "license_url": "https://quaternius.com/packs/ultimatemodularcharacters.html"},
        "female": {"path": "public/glb/modular_women/Adventurer.glb", "size": 894392, "blob_sha": "1f7208c84d68a66527c12a1c541fcecb6d0e8953", "license_url": "https://quaternius.com/packs/ultimatemodularwomen.html"},
    }
    result = {}
    for gender, spec in specs.items():
        path = spec["path"]
        if "Modular Parts/" in path:
            raise RuntimeError("Forbidden Modular Parts source path was requested: " + path)
        dest = target / (gender + "_Adventurer.glb")
        def verify(data):
            if len(data) != spec["size"] or data[:4] != b"glTF" or int.from_bytes(data[8:12], "little") != len(data):
                return False
            git_sha = hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()
            return git_sha == spec["blob_sha"]
        if not _valid_cached_file(dest) or not verify(dest.read_bytes()):
            dest.unlink(missing_ok=True)
            url = f"https://raw.githubusercontent.com/{QUATERNIUS_HEAD_REPO}/{QUATERNIUS_HEAD_REV}/{path}"
            data = download(url)
            if not verify(data):
                raise RuntimeError("Pinned Quaternius " + gender + " head/hair GLB failed size, GLB-header or Git blob SHA validation")
            tmp = dest.with_suffix(".part.glb")
            tmp.write_bytes(data)
            tmp.replace(dest)
        result[gender] = dest
        print("PHASE3B_QUATERNIUS_CC0_HEAD_SOURCE_VERIFIED:", gender, "bytes=", dest.stat().st_size, "git_blob=", spec["blob_sha"], flush=True)
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

def apply_class_tint(tint):
    """Multiply clothing albedo only; preserve the skin material."""
    for mat in bpy.data.materials:
        if not any(token.lower() in mat.name.lower() for token in ("MI_Ranger", "MI_Peasant")): continue
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None: continue
        base = bsdf.inputs["Base Color"]
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs["Fac"].default_value = 1.0
        mix.inputs["Color2"].default_value = tint
        if base.is_linked:
            old = base.links[0]; source = old.from_socket
            links.remove(old); links.new(source, mix.inputs["Color1"])
        else: mix.inputs["Color1"].default_value = base.default_value
        links.new(mix.outputs["Color"], base)
        mat.diffuse_color = tint
        print("PHASE3B_CLASS_CLOTHING_ALBEDO_TINT:", mat.name, tint, flush=True)

def apply_creature_fallback(job):
    palette = job.get("fallback_colors") or []
    if not palette:
        return
    mesh_index = 0
    for obj in [item for item in bpy.context.scene.objects if item.type == "MESH"]:
        if not obj.data.materials:
            obj.data.materials.append(bpy.data.materials.new(name="Phase3B_Creature_Fallback"))
        for slot_index, material in enumerate(obj.data.materials):
            if material is None:
                material = bpy.data.materials.new(name="Phase3B_Creature_Fallback")
                obj.data.materials[slot_index] = material
            material.use_nodes = True
            nodes = material.node_tree.nodes
            links = material.node_tree.links
            bsdf = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None:
                bsdf = nodes.new("ShaderNodeBsdfPrincipled")
                output = next((node for node in nodes if node.type == "OUTPUT_MATERIAL"), None)
                if output is None:
                    output = nodes.new("ShaderNodeOutputMaterial")
                links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
            has_image_texture = any(
                node.type == "TEX_IMAGE" and node.image is not None and node.image.has_data
                for node in nodes
            )
            base = bsdf.inputs["Base Color"]
            flat_white = (
                not base.is_linked
                and min(float(base.default_value[i]) for i in range(3)) >= 0.92
            )
            if not has_image_texture or flat_white:
                color = palette[(mesh_index + slot_index) % len(palette)]
                for existing_link in list(base.links):
                    links.remove(existing_link)
                base.default_value = color
                bsdf.inputs["Metallic"].default_value = 0.18 if len(palette) > 1 else 0.05
                bsdf.inputs["Roughness"].default_value = 0.58
                material.diffuse_color = color
        mesh_index += 1

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

def _head_bone(armature):
    def normalized(name):
        return "".join(ch.lower() for ch in name if ch.isalnum())
    matches = [bone for bone in armature.data.bones if normalized(bone.name) in {"head", "headjoint"}]
    if not matches:
        matches = [bone for bone in armature.data.bones if normalized(bone.name).endswith("head")]
    if not matches:
        raise RuntimeError("Quaternius head integration requires a real Head bone on armature " + armature.name)
    return matches[0]

def add_quaternius_head_hair(source_path, gender):
    # The body model was imported before this function; retain its actual rig explicitly.
    target_armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if not target_armatures:
        raise RuntimeError("Target hero GLB has no Armature object for head attachment")
    target_armature = target_armatures[0]
    target_head = _head_bone(target_armature)
    imported_before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=source_path)
    imported_head_objects = set(bpy.context.scene.objects) - imported_before
    source_armatures = [obj for obj in imported_head_objects if obj.type == "ARMATURE"]
    head_meshes = [obj for obj in imported_head_objects if obj.type == "MESH" and "_head_" in obj.name.lower()]
    expected_parts = 4 if gender == "male" else 3
    if not source_armatures or len(head_meshes) != expected_parts:
        raise RuntimeError("Quaternius " + gender + " head source expected " + str(expected_parts) + " head/face/hair meshes; got " + str(len(head_meshes)))
    source_armature = source_armatures[0]
    source_head = _head_bone(source_armature)
    source_head_world = source_armature.matrix_world @ source_head.matrix_local
    target_head_world = target_armature.matrix_world @ target_head.matrix_local
    alignment = target_head_world @ source_head_world.inverted_safe()
    material_names = set()
    for obj in head_meshes:
        for material in obj.data.materials:
            if material is not None:
                material_names.add(material.name.lower())
    if not any("skin" in name for name in material_names):
        raise RuntimeError("Quaternius head source has no visible skin/face material")
    if not any("hair" in name or "brown" in name for name in material_names):
        raise RuntimeError("Quaternius head source has no hair material")
    for obj in head_meshes:
        aligned_world = alignment @ obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = aligned_world
        for modifier in list(obj.modifiers):
            if modifier.type == "ARMATURE":
                obj.modifiers.remove(modifier)
        for group in list(obj.vertex_groups):
            obj.vertex_groups.remove(group)
        head_group = obj.vertex_groups.new(name=target_head.name)
        if len(obj.data.vertices) == 0:
            raise RuntimeError("Quaternius head mesh is empty: " + obj.name)
        head_group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        obj.parent = target_armature
        obj.matrix_world = aligned_world
        armature_modifier = obj.modifiers.new(name="Phase3B_HeadBoneSkin", type="ARMATURE")
        armature_modifier.object = target_armature
        armature_modifier.use_vertex_groups = True
        armature_modifier.use_bone_envelopes = False
    for obj in list(imported_head_objects):
        if obj not in head_meshes and obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and "head_hood" in obj.name.lower():
            bpy.data.objects.remove(obj, do_unlink=True)
    print("PHASE3B_HEAD_HAIR_ATTACHED:", gender, "parts=", len(head_meshes), "bone=", target_head.name,
          "materials=", sorted(material_names), "source=", source_path, flush=True)

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
    bpy.ops.object.camera_add(location=center + Vector((extent * 2.1, extent * 1.4, extent * 2.6)))
    camera = bpy.context.object
    direction = center - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = extent * 2.0
    scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=center + Vector((extent * 1.8, extent * 2.4, extent * 1.5)))
    key = bpy.context.object
    key.data.energy = 360
    key.data.shape = "DISK"
    key.data.size = extent * 2.2
    key.rotation_euler = (center - key.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.light_add(type="AREA", location=center + Vector((-extent * 1.8, extent * 0.5, extent)))
    fill = bpy.context.object
    fill.data.energy = 150
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
    scene.world.color = (0.11, 0.12, 0.14)
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    if background is not None:
        background.inputs["Color"].default_value = (0.11, 0.12, 0.14, 1.0)
    scene.view_settings.view_transform = "Standard"
    available_looks = [item.identifier for item in scene.view_settings.bl_rna.properties["look"].enum_items]
    scene.view_settings.look = "None" if "None" in available_looks else available_looks[0]
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    scene.render.filepath = os.path.join(preview_dir, job["id"] + ".png")
    bpy.ops.render.render(write_still=True)
    output = scene.render.filepath
    if not os.path.isfile(output) or os.path.getsize(output) < 3000:
        raise RuntimeError("Preview image missing or too small: " + output)

for index, job in enumerate(jobs, 1):
    clear_scene()
    import_model(job["source"])
    if job.get("head_source"):
        add_quaternius_head_hair(job["head_source"], job.get("gender", "male"))
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
    if job.get("class_tint"):
        apply_class_tint(job["class_tint"])
    if job.get("tier") != "natural":
        # Tiered models retain the source mesh while receiving a real PBR material treatment.
        for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
            if job.get("tier") == "royal":
                obj.scale *= 1.035
            elif job.get("tier") == "beginner":
                obj.scale *= 0.985
    apply_creature_fallback(job)
    if not job.get("render_only"):
        os.makedirs(os.path.dirname(job["dest"]), exist_ok=True)
        bpy.ops.file.pack_all()
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
    records = []
    hero_jobs = []

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

    outfits = fetch_complete_outfits()
    modular_head_sources = fetch_quaternius_modular_heads()
    outfit_glbs = {}
    for filename, source in outfits.items():
        dest = CACHE / "complete_outfit_glb" / (pathlib.Path(filename).stem + ".glb")
        dest.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["gltfpack", "-noq", "-i", str(source), "-o", str(dest)], check=True)
        valid_glb(dest)
        outfit_glbs[filename] = dest

    armor_sources = [
        ("body_01", "Black Full Plate", "armor_black"),
        ("body_02", "Golden Full Plate", "armor_golden"),
        ("body_03", "Leather Armor", "armor_leather"),
        ("body_04", "Metal Armor", "armor_metal"),
        ("body_05", "Reinforced Metal Armor", "armor_metal2"),
    ]
    helmet_sources = [
        ("helmet_01", "Knight Helmet I", "helmet1_helmet1"),
        ("helmet_02", "Knight Helmet II", "helmet2_helmet2"),
        ("helmet_03", "Knight Helmet III", "helmet3_helmet3"),
        ("helmet_04", "Knight Helmet I Variant", "helmet1_helmet1"),
        ("helmet_05", "Knight Helmet II Variant", "helmet2_helmet2"),
    ]
    class_tints = {
        "trojan": (0.78, 0.035, 0.075, 1.0),
        "warrior": (0.20, 0.36, 0.58, 1.0),
        "archer": (0.12, 0.52, 0.20, 1.0),
        "assassin": (0.075, 0.085, 0.11, 1.0),
        "taoist": (0.12, 0.66, 0.88, 1.0),
    }
    hero_specs = [
        ("Trojan", "trojan", "male", "Male_Ranger.gltf"),
        ("Trojan", "trojan", "female", "Female_Ranger.gltf"),
        ("Warrior", "warrior", "male", "Male_Peasant.gltf"),
        ("Warrior", "warrior", "female", "Female_Peasant.gltf"),
        ("Archer", "archer", "male", "Male_Ranger.gltf"),
        ("Archer", "archer", "female", "Female_Ranger.gltf"),
        ("Assassin", "assassin", "male", "Male_Peasant.gltf"),
        ("Assassin", "assassin", "female", "Female_Peasant.gltf"),
        ("Taoist", "taoist", "male", "Male_Ranger.gltf"),
        ("Taoist", "taoist", "female", "Female_Ranger.gltf"),
    ]
    character_report = {
        "generator": "Quaternius Modular Character Outfits - Fantasy / complete Outfits only",
        "source_repository": MODULAR_REPO,
        "source_revision": MODULAR_REV,
        "source_license": "CC0-1.0",
        "source_license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "source_pack_url": "https://quaternius.itch.io/modular-character-outfits-fantasy",
        "head_hair_source": {"pack": "Ultimate Modular Men / Ultimate Modular Women", "repository": QUATERNIUS_HEAD_REPO, "revision": QUATERNIUS_HEAD_REV, "license": "CC0-1.0", "male_source": "public/glb/modular_men/Adventurer.glb", "female_source": "public/glb/modular_women/Adventurer.glb", "male_license_url": "https://quaternius.com/packs/ultimatemodularcharacters.html", "female_license_url": "https://quaternius.com/packs/ultimatemodularwomen.html"},
        "forbidden_source_paths": ["Modular Parts/"],
        "rig": "Humanoid",
        "profiles": []
    }
    for display, key, gender, source_key in hero_specs:
        source_gltf = outfits[source_key]
        source_doc = json.loads(source_gltf.read_text(encoding="utf-8"))
        skins = source_doc.get("skins", [])
        if not source_doc.get("meshes") or not skins or len(skins[0].get("joints", [])) < 60:
            raise RuntimeError("Complete CC0 hero source lacks full mesh geometry or Humanoid skin: " + source_key)
        joint_names = [source_doc.get("nodes", [])[i].get("name", "") for i in skins[0]["joints"]]
        right_hand = next((name for name in joint_names if name.lower() == "hand_r"), "")
        left_hand = next((name for name in joint_names if name.lower() == "hand_l"), "")
        if not right_hand or not left_hand:
            raise RuntimeError("Complete CC0 hero source missing exact hand_r/hand_l bones: " + source_key)
        relative = f"characters/{key}_{gender}.glb"
        destination = OUT / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        asset_id = f"hero_{key}_{gender}"
        preview = f"previews/{asset_id}.png"
        tint = class_tints[key]
        hero_jobs.append({"id": asset_id, "source": str(outfit_glbs[source_key]), "head_source": str(modular_head_sources[gender]),
                          "gender": gender, "tier": "natural", "dest": str(destination), "class_tint": tint})
        records.append({
            "id": asset_id, "name": f"{display} — {'Male' if gender == 'male' else 'Female'}",
            "category": "character", "class": key, "gender": gender,
            "file": relative, "level_min": 1, "level_max": 110,
            "source": "Quaternius complete CC0 Outfit",
            "source_repository": MODULAR_REPO, "source_revision": MODULAR_REV,
            "source_model": source_key, "class_clothing_albedo_tint": list(tint),
            "license": "CC0-1.0", "source_license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
            "bytes": 0, "preview": preview
        })
        character_report["profiles"].append({
            "file": relative, "class": key, "gender": gender, "source_model": source_key,
            "skin_count": len(skins), "humanoid_joint_count": len(skins[0]["joints"]),
            "right_hand_bone": right_hand, "left_hand_bone": left_hand,
            "clothing_albedo_tint": list(tint), "head_source_pack": "Quaternius Ultimate Modular Men/Women",
            "head_source_model": "Adventurer.glb", "head_attachment_bone": "Head",
            "expected_head_face_hair_mesh_parts": 4 if gender == "male" else 3,
            "bytes": 0, "status": "validated"
        })
    if len(character_report["profiles"]) != 10:
        raise RuntimeError("Expected ten real male/female complete CC0 outfit hero assets")
    (OUT / "characters" / "character_quality_report.json").write_text(
        json.dumps(character_report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("PHASE3B_TEN_COMPLETE_CC0_HUMANOID_HEROES_READY:", len(character_report["profiles"]), flush=True)

    armor_jobs = []
    for slug, display, alias in armor_sources:
        source = choose_model([OUT / "quaternius_library"], [alias], label=display)
        for tier, label, low, high in TIERS:
            asset_id = slug + "_" + tier
            relative = "armor/" + asset_id + ".glb"
            armor_jobs.append({"id": asset_id, "source": str(source), "tier": tier, "dest": str(OUT / relative)})
            records.append({
                "id": asset_id, "name": display + " — " + label, "category": "armor",
                "armor_slot": "body", "tier": tier, "level_min": low, "level_max": high,
                "file": relative, "source": "Quaternius CC0", "license": "CC0-1.0",
                "preview": f"previews/{asset_id}.png"
            })
    helmet_candidates = [OUT / "quaternius_library"]
    for slug, display, alias in helmet_sources:
        source = choose_model(helmet_candidates, [alias], label=display)
        for tier, label, low, high in TIERS:
            asset_id = slug + "_" + tier
            relative = "armor/" + asset_id + ".glb"
            armor_jobs.append({"id": asset_id, "source": str(source), "tier": tier, "dest": str(OUT / relative)})
            records.append({
                "id": asset_id, "name": display + " — " + label, "category": "armor",
                "armor_slot": "helmet", "tier": tier, "level_min": low, "level_max": high,
                "file": relative, "source": "Quaternius CC0", "license": "CC0-1.0",
                "preview": f"previews/{asset_id}.png"
            })
    boots_source = choose_model([OUT / "quaternius_library"], ["stylized_boot"], label="Stylized Boots")
    for tier, label, low, high in TIERS:
        asset_id = "boots_01_" + tier
        relative = "armor/" + asset_id + ".glb"
        armor_jobs.append({"id": asset_id, "source": str(boots_source), "tier": tier, "dest": str(OUT / relative)})
        records.append({
            "id": asset_id, "name": "Stylized Boots — " + label, "category": "armor",
            "armor_slot": "boots", "tier": tier, "level_min": low, "level_max": high,
            "file": relative, "source": "The Base Mesh CC0", "license": "CC0-1.0",
            "preview": f"previews/{asset_id}.png"
        })

    monster_root = [OUT / "monsters"]
    CREATURE_COLORS = {
        "bunny": [(0.72, 0.48, 0.27, 1.0)],
        "chicken": [(0.92, 0.62, 0.12, 1.0)],
        "dog": [(0.34, 0.16, 0.075, 1.0)],
        "cactoro": [(0.16, 0.48, 0.20, 1.0)],
        "orc": [(0.34, 0.17, 0.075, 1.0), (0.48, 0.27, 0.11, 1.0)],
        "demon": [(0.48, 0.035, 0.045, 1.0)],
        "ghost": [(0.35, 0.72, 0.82, 1.0)],
        "blob": [(0.34, 0.18, 0.58, 1.0)],
        "dino": [(0.12, 0.42, 0.16, 1.0), (0.22, 0.58, 0.20, 1.0)],
        "birb": [(0.12, 0.38, 0.72, 1.0)],
        "pigeon": [(0.34, 0.42, 0.52, 1.0)],
        "frog": [(0.10, 0.52, 0.18, 1.0), (0.22, 0.68, 0.24, 1.0)],
        "yeti": [(0.42, 0.72, 0.92, 1.0), (0.72, 0.88, 0.98, 1.0)],
        "alien": [(0.12, 0.58, 0.48, 1.0)],
        "armabee": [(0.82, 0.48, 0.06, 1.0), (0.16, 0.12, 0.06, 1.0)],
        "alpaking_evolved": [(0.76, 0.52, 0.12, 1.0), (0.26, 0.42, 0.12, 1.0)],
        "mushroom_king": [(0.68, 0.12, 0.16, 1.0), (0.88, 0.76, 0.52, 1.0)],
        "blue_demon": [(0.045, 0.20, 0.72, 1.0), (0.12, 0.42, 0.92, 1.0)],
        "orc_skull": [(0.30, 0.14, 0.06, 1.0), (0.72, 0.52, 0.20, 1.0)],
        "dragon_evolved": [(0.62, 0.035, 0.025, 1.0), (0.92, 0.58, 0.10, 1.0)]
    }
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
                                "dest": str(OUT / relative),
                                "fallback_colors": CREATURE_COLORS[key]})
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
                            "dest": str(OUT / relative),
                            "fallback_colors": CREATURE_COLORS[alias]})

    jobs = hero_jobs + weapon_jobs + armor_jobs
    expected = {"character": 10, "weapon": 27, "armor": 33, "normal_mob": 15, "boss": 5}
    counts = {}
    for record in records:
        counts[record["category"]] = counts.get(record["category"], 0) + 1
    if counts != expected or len(records) != 90:
        raise RuntimeError("Exact 90-model count failed: " + json.dumps(counts, sort_keys=True))
    if len({record["file"] for record in records}) != 90:
        raise RuntimeError("90 manifest entries do not map to 90 unique GLB paths")

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
        "progression": "Lv.1-Lv.110", "expected_total": 90, "actual_total": 90,
        "counts": counts, "cities": ["Twin City", "Desert City", "Phoenix Castle", "Bird Island", "Ape Mountain"],
        "weapon_families": 9,
        "tiers": [{"id": t, "name": n, "levels": f"Lv.{lo}-Lv.{hi}"} for t, n, lo, hi in TIERS],
        "armor_slots": {"body": 15, "helmet": 15, "boots": 3},
        "sources": {
            "characters": "Quaternius complete CC0 Outfits (4 source models reused across 10 class/gender profiles)",
            "weapons_monsters": "Quaternius CC0",
            "armor": {"source": "Quaternius CC0 armor models + The Base Mesh CC0 boots"}
        },
        "assets": records
    }
    (OUT / "phase3b_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    report = {
        "status": "validated", "expected_total": 90, "actual_total": 90,
        "counts": counts, "unique_model_paths": 90, "preview_images": 90,
        "all_glb_valid": True, "all_previews_nonempty": True,
        "manifest": "phase3b/phase3b_manifest.json"
    }
    (ROOT / "artifacts" / "phase3b_85_asset_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("PHASE3B_90_PACK_VALIDATED:", json.dumps(report, sort_keys=True), flush=True)

if __name__ == "__main__":
    build()
