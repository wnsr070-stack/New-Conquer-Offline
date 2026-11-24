#!/usr/bin/env python3
"""Standalone Quaternius CC0 male/female head extraction and visual QA."""
import bpy, bmesh, hashlib, json, os, pathlib, urllib.request
from mathutils import Vector
ROOT=pathlib.Path(os.environ.get("GITHUB_WORKSPACE",pathlib.Path.cwd()))
CACHE=ROOT/".cache/quaternius_heads"; OUT=ROOT/"artifacts/heads"
CACHE.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
REPO="trebeljahr/quaternius-showcase"; REV="0128ca510d653bb04d6d1e4885bd8890b5050b4f"
SOURCES={"male":("public/glb/modular_men/Adventurer.glb",1272560,"14456cd24345ad437840365396b60e82af653507"),"female":("public/glb/modular_women/Adventurer.glb",894392,"1f7208c84d68a66527c12a1c541fcecb6d0e8953")}
def log(*a): print(*a,flush=True)
def source(g):
 rel,size,sha=SOURCES[g]; p=CACHE/(g+"_Adventurer.glb")
 def valid(d): return len(d)==size and d[:4]==b"glTF" and int.from_bytes(d[8:12],"little")==len(d) and hashlib.sha1(b"blob "+str(len(d)).encode()+b"\0"+d).hexdigest()==sha
 if not p.exists() or not valid(p.read_bytes()):
  req=urllib.request.Request(f"https://raw.githubusercontent.com/{REPO}/{REV}/{rel}",headers={"User-Agent":"New-Conquer-Offline-head-extractor"})
  with urllib.request.urlopen(req,timeout=120) as r: data=r.read()
  if not valid(data): raise RuntimeError("Pinned Quaternius source integrity failed: "+g)
  tmp=p.with_suffix(".part"); tmp.write_bytes(data); tmp.replace(p)
 log("HEAD_SOURCE_VERIFIED",g,p.stat().st_size,sha); return p
def clear():
 bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
def bone(arm,token):
 found=[b for b in arm.data.bones if token in "".join(c.lower() for c in b.name if c.isalnum())]
 if not found: raise RuntimeError("Missing source "+token+" bone: "+arm.name)
 return found[0]
def extract(g,path):
 clear(); bpy.ops.import_scene.gltf(filepath=str(path))
 imported=list(bpy.context.scene.objects); rigs=[o for o in imported if o.type=="ARMATURE"]
 if not rigs: raise RuntimeError(g+" source armature missing")
 rig=rigs[0]; head=bone(rig,"head")
 bpy.ops.object.select_all(action="DESELECT")
 for o in imported: o.select_set(True)
 bpy.context.view_layer.objects.active=imported[0]
 bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 head_world=rig.matrix_world@head.head; src_height=max(rig.dimensions.z,0.001); cut_z=head_world.z-0.08*src_height
 log("HEAD_CUT_PLANE",g,"head_bone",head.name,"head_world",tuple(head_world),"head_local",tuple(head.head),"src_height",src_height,"cut_z",cut_z,"rig_bounds",tuple(rig.dimensions))
 for mesh in [o for o in imported if o.type=="MESH"]:
  if mesh.data.vertices:
   zs=[(mesh.matrix_world@v.co).z for v in mesh.data.vertices]
   log("HEAD_SOURCE_MESH_BOUNDS",g,mesh.name,"zmin",min(zs),"zmax",max(zs),"verts",len(zs),"faces",len(mesh.data.polygons),"matrix",tuple(tuple(row) for row in mesh.matrix_world))
 terms=("head","face","hair","eye","brow","beard","ear"); excluded=("backpack","bag","quiver","cape","shield","weapon")
 candidates=[o for o in imported if o.type=="MESH" and any(t in o.name.casefold() for t in terms) and not any(t in o.name.casefold() for t in excluded)]
 if not candidates: candidates=[o for o in imported if o.type=="MESH" and not any(t in o.name.casefold() for t in excluded)]
 kept=[]
 for o in candidates:
  bm=bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
  removed=[v for v in bm.verts if v.co.z<cut_z]
  if removed: bmesh.ops.delete(bm,geom=removed,context="VERTS")
  loose=[v for v in bm.verts if not v.link_faces]
  if loose: bmesh.ops.delete(bm,geom=loose,context="VERTS")
  bm.to_mesh(o.data); bm.free(); o.data.update()
  if o.data.vertices and o.data.polygons: kept.append(o); log("HEAD_MESH_RETAINED",g,o.name,len(o.data.vertices),len(o.data.polygons))
 if not kept: raise RuntimeError(g+" BMesh cut retained no head geometry")
 coords=[o.matrix_world@v.co for o in kept for v in o.data.vertices]
 zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); height=zmax-zmin
 if height<=1e-5: raise RuntimeError(g+" extracted head has invalid height")
 factor=0.26/height
 for o in kept:
  for v in o.data.vertices:
   w=o.matrix_world@v.co; v.co=Vector((w.x*factor,w.y*factor,(w.z-zmin)*factor))
  o.matrix_world.identity(); o.data.update()
  bm=bmesh.new(); bm.from_mesh(o.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(o.data); bm.free()
 keep=set(kept)
 for o in list(bpy.context.scene.objects):
  if o not in keep: bpy.data.objects.remove(o,do_unlink=True)
 bpy.ops.object.select_all(action="DESELECT")
 for o in kept: o.select_set(True)
 bpy.context.view_layer.objects.active=kept[0]
 dest=OUT/(g+"_head.glb"); bpy.ops.file.pack_all()
 bpy.ops.export_scene.gltf(filepath=str(dest),export_format="GLB",export_apply=True)
 data=dest.read_bytes()
 if len(data)<1000 or data[:4]!=b"glTF" or int.from_bytes(data[8:12],"little")!=len(data): raise RuntimeError("Invalid exported "+g+" GLB")
 log("HEAD_EXPORT_OK",g,dest,len(data),"height_m=0.26","base_origin=(0,0,0)","parts",len(kept)); return dest
def render(male,female):
 clear(); meshes=[]
 for p,x in ((male,-0.24),(female,0.24)):
  before=set(bpy.context.scene.objects); bpy.ops.import_scene.gltf(filepath=str(p))
  added=[o for o in bpy.context.scene.objects if o not in before and o.type=="MESH"]
  for o in added: o.location.x+=x
  meshes+=added
 pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
 lo=Vector((min(p.x for p in pts),min(p.y for p in pts),min(p.z for p in pts))); hi=Vector((max(p.x for p in pts),max(p.y for p in pts),max(p.z for p in pts)))
 center=(lo+hi)*0.5; ext=max((hi-lo).x,(hi-lo).y,(hi-lo).z,0.3); scene=bpy.context.scene
 bpy.ops.object.camera_add(location=center+Vector((ext*2.7,-ext*4,ext*1.8))); cam=bpy.context.object
 cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler(); cam.data.type="ORTHO"; cam.data.ortho_scale=ext*2.25; scene.camera=cam
 for loc,power,size in ((center+Vector((1.5,-2.5,2.4)),500,2.0),(center+Vector((-2,1,1.4)),250,2.5)):
  bpy.ops.object.light_add(type="AREA",location=loc); light=bpy.context.object; light.data.energy=power; light.data.shape="DISK"; light.data.size=size
  light.rotation_euler=(center-light.location).to_track_quat("-Z","Y").to_euler()
 ids=[e.identifier for e in scene.render.bl_rna.properties["engine"].enum_items]; scene.render.engine="BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in ids else "BLENDER_EEVEE"
 scene.render.resolution_x=1200; scene.render.resolution_y=700; scene.render.resolution_percentage=100; scene.render.image_settings.file_format="PNG"
 scene.view_settings.view_transform="Standard"; scene.view_settings.exposure=0; scene.view_settings.gamma=1
 if scene.world is None: scene.world=bpy.data.worlds.new("HeadsQA")
 scene.world.use_nodes=True; scene.world.node_tree.nodes["Background"].inputs["Color"].default_value=(0.12,0.13,0.16,1)
 dest=OUT/"heads_pair_preview.png"; scene.render.filepath=str(dest); bpy.ops.render.render(write_still=True)
 if not dest.is_file() or dest.stat().st_size<3000: raise RuntimeError("QA preview missing")
 log("HEAD_PAIR_QA_RENDER_OK",dest,dest.stat().st_size)
male=extract("male",source("male")); female=extract("female",source("female")); render(male,female)
(OUT/"heads_manifest.json").write_text(json.dumps({"source":REPO,"revision":REV,"license":"CC0-1.0","cut":"v.co.z < src_head_world.z - 0.08 * src_height","normalization":{"neck_base":[0,0,0],"height_m":0.26},"files":[{"name":p.name,"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in (male,female)],"preview":"heads_pair_preview.png"},indent=2)+"\n")
