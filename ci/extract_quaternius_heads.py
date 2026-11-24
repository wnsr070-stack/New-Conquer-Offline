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
 # Derive the face-facing direction from the source Head bone roll, not guessed world axes.
 head_bone=bone(rigs[0],"head")
 bone_world=rigs[0].matrix_world.to_3x3() @ head_bone.matrix_local.to_3x3()
 forward=(bone_world @ Vector((0,0,1))).normalized()
 right=(bone_world @ Vector((1,0,0))).normalized()
 log("HEAD_BONE_CAMERA_AXES",g,"bone",head_bone.name,"forward",tuple(round(v,5) for v in forward),"right",tuple(round(v,5) for v in right),"bone_y",tuple(round(v,5) for v in (bone_world @ Vector((0,1,0))).normalized()))
 # Adventurer.glb already contains an independent head mesh. Never cut or derive geometry from the body.
 candidates=[o for o in imported if o.type=="MESH" and "head" in o.name.casefold() and not any(t in o.name.casefold() for t in ("backpack","bag","quiver","cape","shield","weapon"))]
 if not candidates: raise RuntimeError(g+" independent Adventurer head mesh not found")
 for o in candidates:
  for mat in o.data.materials:
   if mat is not None and hasattr(mat,"use_backface_culling"): mat.use_backface_culling=False
 coords=[o.matrix_world@v.co for o in candidates for v in o.data.vertices]
 if not coords: raise RuntimeError(g+" independent head mesh is empty")
 src_min=min(p.z for p in coords); src_max=max(p.z for p in coords); src_height=src_max-src_min
 if src_height<=1e-5: raise RuntimeError(g+" independent head has invalid source height")
 cut_z=None
 if g=="female":
  cut_z=src_min+0.15*src_height
  removed_total=0
  for o in candidates:
   bm=bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
   removed=[v for v in bm.verts if (o.matrix_world@v.co).z<cut_z]
   removed_total+=len(removed)
   if removed: bmesh.ops.delete(bm,geom=removed,context="VERTS")
   loose=[v for v in bm.verts if not v.link_faces]
   if loose: bmesh.ops.delete(bm,geom=loose,context="VERTS")
   bm.to_mesh(o.data); bm.free(); o.data.update()
  log("FEMALE_HEAD_BOTTOM_CUT", "cut_z",cut_z,"source_min_z",src_min,"source_height",src_height,"ratio",0.15,"removed_vertices",removed_total)
 else:
  log("MALE_HEAD_NO_CUT","independent_head_mesh_only")
 kept=[o for o in candidates if o.data.vertices and o.data.polygons]
 if not kept: raise RuntimeError(g+" extraction retained no independent head geometry")
 coords=[o.matrix_world@v.co for o in kept for v in o.data.vertices]
 zmin=min(p.z for p in coords); zmax=max(p.z for p in coords); height=zmax-zmin
 if height<=1e-5: raise RuntimeError(g+" extracted head has invalid post-cut height")
 base_x=(min(p.x for p in coords)+max(p.x for p in coords))*0.5
 base_y=(min(p.y for p in coords)+max(p.y for p in coords))*0.5
 # GLB export converts Blender units by 0.01; 26 Blender units export as 0.26 m.
 factor=26.0/height
 for o in kept:
  bm=bmesh.new(); bm.from_mesh(o.data)
  bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
  bm.to_mesh(o.data); bm.free()
  for v in o.data.vertices:
   w=o.matrix_world@v.co
   v.co=Vector(((w.x-base_x)*factor,(w.y-base_y)*factor,(w.z-zmin)*factor))
  o.matrix_world.identity(); o.data.update()
  bm=bmesh.new(); bm.from_mesh(o.data)
  bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
  bm.to_mesh(o.data); bm.free()
  for mat in o.data.materials:
   if mat is not None and hasattr(mat,"use_backface_culling"): mat.use_backface_culling=False
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
 log("HEAD_EXPORT_OK",g,dest,len(data),"height_m=0.26","neck_base_origin=(0,0,0)","parts",len(kept),"cut",("15_percent_bottom" if g=="female" else "none"))
 return dest,forward,right
def render(male,female,male_axes,female_axes):
 mf,mr=male_axes; ff,fr=female_axes
 if mf.dot(ff)<0.95: raise RuntimeError("Male/female Head bone forward axes disagree; refusing guessed camera orientation")
 camera_forward=(mf+ff).normalized()
 camera_right=(mr+fr).normalized()
 camera_right=(camera_right-camera_forward*camera_right.dot(camera_forward)).normalized()
 def render_view(view_name, direction):
  clear(); meshes=[]
  for p,x in ((male,-0.24),(female,0.24)):
   before=set(bpy.context.scene.objects); bpy.ops.import_scene.gltf(filepath=str(p))
   added=[o for o in bpy.context.scene.objects if o not in before and o.type=="MESH"]
   for o in added:
    # Apply the imported 0.01 unit-conversion scale before bounds/camera calculations.
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.location.x+=x
    for mat in o.data.materials:
     if mat is not None and hasattr(mat,"use_backface_culling"): mat.use_backface_culling=False
   meshes+=added
  pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
  lo=Vector((min(p.x for p in pts),min(p.y for p in pts),min(p.z for p in pts))); hi=Vector((max(p.x for p in pts),max(p.y for p in pts),max(p.z for p in pts)))
  center=(lo+hi)*0.5; ext=max((hi-lo).x,(hi-lo).y,(hi-lo).z,0.3); scene=bpy.context.scene
  # Camera direction is built from the Head bone's local roll axes.
  cam_offset=camera_forward*ext*4.5
  if view_name=="three_quarter": cam_offset=(camera_forward+camera_right*0.65+Vector((0,0,0.18))).normalized()*ext*4.5
  bpy.ops.object.camera_add(location=center+cam_offset); cam=bpy.context.object
  cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler(); cam.data.type="ORTHO"; cam.data.ortho_scale=ext*2.15; scene.camera=cam
  for loc,power,size in ((center+Vector((1.5,-2.5,2.4)),500,2.0),(center+Vector((-2,1,1.4)),250,2.5)):
   bpy.ops.object.light_add(type="AREA",location=loc); light=bpy.context.object; light.data.energy=power; light.data.shape="DISK"; light.data.size=size
   light.rotation_euler=(center-light.location).to_track_quat("-Z","Y").to_euler()
  ids=[e.identifier for e in scene.render.bl_rna.properties["engine"].enum_items]; scene.render.engine="BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in ids else "BLENDER_EEVEE"
  scene.render.resolution_x=1000; scene.render.resolution_y=700; scene.render.resolution_percentage=100; scene.render.image_settings.file_format="PNG"
  scene.view_settings.view_transform="Standard"; scene.view_settings.exposure=0; scene.view_settings.gamma=1
  if scene.world is None: scene.world=bpy.data.worlds.new("HeadsQA")
  scene.world.use_nodes=True; scene.world.node_tree.nodes["Background"].inputs["Color"].default_value=(0.12,0.13,0.16,1)
  dest=OUT/("heads_"+view_name+"_preview.png"); scene.render.filepath=str(dest); bpy.ops.render.render(write_still=True)
  if not dest.is_file() or dest.stat().st_size<3000: raise RuntimeError("QA preview missing: "+view_name)
  # Validate visible rendered content, not merely PNG existence/non-zero size.
  import numpy as np
  preview=bpy.data.images.load(str(dest), check_existing=False)
  rgba=np.asarray(preview.pixels[:],dtype=np.float32).reshape((preview.size[1],preview.size[0],4))
  bg=rgba[0,0,:3]
  mask=np.max(np.abs(rgba[:,:,:3]-bg),axis=2)>0.035
  ys,xs=np.where(mask)
  if len(xs)<5000 or (xs.max()-xs.min())<100 or (ys.max()-ys.min())<100:
   raise RuntimeError("HEAD_QA_VISUAL_CONTENT_FAILED "+view_name+" pixels="+str(len(xs)))
  log("HEAD_QA_VISUAL_CONTENT_OK",view_name,"non_background_pixels",int(len(xs)),"bbox",(int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())))
  bpy.data.images.remove(preview)
  log("HEAD_QA_RENDER_OK",view_name,dest,dest.stat().st_size)
 render_view("front",None)
 render_view("three_quarter",None)

male,male_forward,male_right=extract("male",source("male"))
female,female_forward,female_right=extract("female",source("female"))
render(male,female,(male_forward,male_right),(female_forward,female_right))
(OUT/"heads_manifest.json").write_text(json.dumps({"source":REPO,"revision":REV,"license":"CC0-1.0","cut":{"male":"none; independent head mesh","female":"remove vertices below min_z + 0.15 * source_head_height"},"normalization":{"neck_base":[0,0,0],"height_m":0.26},"files":[{"name":p.name,"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in (male,female)],"previews":["heads_front_preview.png","heads_three_quarter_preview.png"]},indent=2)+"\n")
