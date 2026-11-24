#!/usr/bin/env python3
"""Build a visual catalogue from the exact Ara 3D Gen CLI preset list."""
import json, pathlib, re, subprocess, sys, tempfile, shutil, os

ROOT = pathlib.Path.cwd()
OUT = ROOT / "artifacts"
MODELS = ROOT / ".cache/ara3d-catalog/models"
THUMBS = ROOT / "artifacts/ara3d-catalog-thumbs"
OUT.mkdir(exist_ok=True)
MODELS.mkdir(parents=True, exist_ok=True)
THUMBS.mkdir(parents=True, exist_ok=True)

raw = subprocess.check_output(["ara3d", "presets"], text=True, stderr=subprocess.STDOUT)
(OUT / "ara3d_presets.log").write_text(raw, encoding="utf-8")
print("PHASE3B_AR3D_PRESETS_BEGIN")
print(raw, end="" if raw.endswith("\n") else "\n")
print("PHASE3B_AR3D_PRESETS_END")

names = []
for src in raw.splitlines():
    line = re.sub(r"\x1b\[[0-9;]*m", "", src).strip()
    line = re.sub(r"^(?:[-*•]\s*|\d+[.)]\s*)", "", line)
    if not line or line.lower().startswith(("available presets", "presets:", "usage:", "name")):
        continue
    # Ara3D 0.9.0 emits both "The ..." presets and unprefixed names
    # (e.g. "Athletic man", "Detective"). Keep every actual listed preset.
    name = re.split(r"\s{2,}|\s+[|—–]\s+", line, maxsplit=1)[0].strip()
    if name and name.lower() not in {"available presets", "presets:", "usage:", "name"}:
        if name not in names: names.append(name)
if not names:
    raise SystemExit("Could not parse actual Ara preset names; refusing to invent a catalogue")

(OUT / "ara3d_presets_full.txt").write_text("\n".join(names) + "\n", encoding="utf-8")
# The director asked to inspect every preset, not a keyword-filtered subset.
candidates = list(names)
print("PHASE3B_CATALOG_ALL_PRESETS_SELECTED:", len(candidates), flush=True)
records = []
for i, name in enumerate(candidates, 1):
    outdir = MODELS / f"{i:02d}"
    outdir.mkdir(parents=True, exist_ok=True)
    print("PHASE3B_CATALOG_EXPORT:", name, flush=True)
    subprocess.run(["ara3d", "export", "--preset", name, "--formats", "glb", "--detail", "medium", "--no-animations", "--out", str(outdir)], check=True)
    glbs = sorted(outdir.rglob("*.glb"))
    if len(glbs) != 1 or glbs[0].stat().st_size < 10000:
        raise RuntimeError(f"Expected exactly one valid GLB for {name}; found {[str(p) for p in glbs]}")
    records.append({"name": name, "model": str(glbs[0]), "thumbnail": str(THUMBS / f"{i:02d}.png")})
manifest = OUT / "ara3d_catalog_manifest.json"
manifest.write_text(json.dumps(records, indent=2), encoding="utf-8")

blender_py = ROOT / ".cache/ara3d-catalog/render.py"
blender_py.parent.mkdir(parents=True, exist_ok=True)
blender_py.write_text(r'''
import bpy, sys, json, math
from mathutils import Vector
args = sys.argv[sys.argv.index("--")+1:]
manifest_path = args[0]
records = json.load(open(manifest_path, encoding="utf-8"))
for rec in records:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "EEVEE_NEXT") else "BLENDER_EEVEE"
    scene.render.resolution_x = 480
    scene.render.resolution_y = 600
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("CatalogueWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.018, 0.025, 0.04, 1)
    bg.inputs[1].default_value = 0.65
    bpy.ops.import_scene.gltf(filepath=rec["model"])
    meshes = [o for o in scene.objects if o.type == "MESH"]
    if not meshes: raise RuntimeError("No mesh imported for " + rec["name"])
    mins=[min((o.matrix_world @ Vector(c))[k] for o in meshes for c in o.bound_box) for k in range(3)]
    maxs=[max((o.matrix_world @ Vector(c))[k] for o in meshes for c in o.bound_box) for k in range(3)]
    center=Vector(((mins[0]+maxs[0])/2,(mins[1]+maxs[1])/2,(mins[2]+maxs[2])/2))
    height=max(maxs[2]-mins[2],0.1)
    for o in meshes: o.location -= center
    # Ground at model feet; preserve imported materials and textures.
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-height/2))
    floor=bpy.context.object
    mat=bpy.data.materials.new("DarkStone"); mat.diffuse_color=(0.055,0.065,0.08,1); floor.data.materials.append(mat)
    bpy.ops.object.camera_add(location=(height*1.35,-height*2.8,height*0.65))
    cam=bpy.context.object
    direction=Vector((0,0,0))-cam.location
    cam.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()
    cam.data.type="ORTHO"; cam.data.ortho_scale=max(height*1.35,1.7); scene.camera=cam
    def area(loc, power, size, color):
        bpy.ops.object.light_add(type="AREA", location=loc)
        l=bpy.context.object; l.data.energy=power; l.data.shape="DISK"; l.data.size=size; l.data.color=color
        l.rotation_euler=(Vector((0,0,0))-l.location).to_track_quat("-Z","Y").to_euler()
    area((height*1.4,-height*1.8,height*2.2),1500, height*1.4,(1.0,0.82,0.62))
    area((-height*1.8,-height*0.7,height*1.0),900,height*1.8,(0.45,0.65,1.0))
    area((0,height*1.5,height*1.6),1100,height*1.2,(1.0,1.0,1.0))
    scene.view_settings.view_transform="Standard"
    # Blender 3.0 (Ubuntu 22.04 package) exposes no contrast-look presets.
    # Keep its supported default rather than assigning an unavailable enum.
    available_looks = {item.identifier for item in scene.view_settings.bl_rna.properties["look"].enum_items}
    if "Medium High Contrast" in available_looks:
        scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure=0
    scene.view_settings.gamma=1
    scene.render.filepath=rec["thumbnail"]
    bpy.ops.render.render(write_still=True)
''', encoding="utf-8")
# EEVEE needs a working OpenGL context even in background mode on Ubuntu.
# Run it under Xvfb with Mesa software rendering to avoid SIGABRT / display errors.
env = os.environ.copy()
env["LIBGL_ALWAYS_SOFTWARE"] = "1"
subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x1024x24",
                "env", "LIBGL_ALWAYS_SOFTWARE=1", "blender", "--background",
                "--python", str(blender_py), "--", str(manifest)],
               check=True, env=env)

from PIL import Image, ImageDraw, ImageFont
cols=4
cell_w, cell_h=480, 660
rows=(len(records)+cols-1)//cols
sheet=Image.new("RGB",(cols*cell_w,rows*cell_h),(18,24,32))
draw=ImageDraw.Draw(sheet)
font_path="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
font_bold="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
font=ImageFont.truetype(font_path,22)
bold=ImageFont.truetype(font_bold,23)
for i,rec in enumerate(records):
    im=Image.open(rec["thumbnail"]).convert("RGB").resize((cell_w,cell_h-60))
    x=(i%cols)*cell_w; y=(i//cols)*cell_h
    sheet.paste(im,(x,y))
    label=rec["name"]
    draw.rectangle((x,y+cell_h-60,x+cell_w,y+cell_h),fill=(28,36,48))
    draw.text((x+14,y+cell_h-48),f"{i+1:02d}. {label}",font=bold,fill=(245,240,226))
sheet.save(OUT/"phase3b_hero_catalog.png", optimize=True)
print("PHASE3B_HERO_CATALOG_COMPLETE:", len(records), "all_available_presets")
