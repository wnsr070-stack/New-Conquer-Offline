import bpy, os, sys
from mathutils import Vector
args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
if len(args)!=2: raise SystemExit("usage: blender --background --python script -- asset_root output_dir")
ASSET_ROOT,OUTPUT_DIR=args
os.makedirs(OUTPUT_DIR,exist_ok=True)
models=[("Chicken","monsters/normal/chicken.glb",1.60,"NORMAL"),("Pigeon","monsters/normal/pigeon.glb",1.64,"NORMAL"),("Birb","monsters/normal/birb.glb",1.69,"NORMAL"),("Ghost","monsters/normal/ghost.glb",1.73,"NORMAL"),("Blob","monsters/normal/blob.glb",1.77,"NORMAL"),("Bunny","monsters/normal/bunny.glb",1.81,"NORMAL"),("Dog","monsters/normal/dog.glb",1.86,"NORMAL"),("Frog","monsters/normal/frog.glb",1.90,"NORMAL"),("Orc","monsters/normal/orc.glb",1.94,"NORMAL"),("Yeti","monsters/normal/yeti.glb",1.99,"NORMAL"),("Cactoro","monsters/normal/cactoro.glb",2.03,"NORMAL"),("Dino","monsters/normal/dino.glb",2.07,"NORMAL"),("Armabee","monsters/normal/armabee.glb",2.12,"NORMAL"),("Demon","monsters/normal/demon.glb",2.16,"NORMAL"),("Alien","monsters/normal/alien.glb",2.20,"NORMAL"),("Alpaking_Evolved","monsters/bosses/alpaking_evolved.glb",4.40,"BOSS"),("Mushroom_King","monsters/bosses/mushroom_king.glb",4.40,"BOSS"),("Blue_Demon","monsters/bosses/blue_demon.glb",4.40,"BOSS"),("Orc_Skull","monsters/bosses/orc_skull.glb",4.40,"BOSS"),("Dragon_Evolved","monsters/bosses/dragon_evolved.glb",4.40,"BOSS")]
def bounds(objects):
 pts=[]; dg=bpy.context.evaluated_depsgraph_get()
 for ob in objects:
  if ob.type not in {"MESH","CURVE","FONT","SURFACE","META"}: continue
  ev=ob.evaluated_get(dg); pts.extend(ev.matrix_world @ Vector(c) for c in ev.bound_box)
 if not pts: raise RuntimeError("GLB has no renderable geometry")
 return Vector((min(p.x for p in pts),min(p.y for p in pts),min(p.z for p in pts))),Vector((max(p.x for p in pts),max(p.y for p in pts),max(p.z for p in pts)))
def ground_material():
 m=bpy.data.materials.new("Studio_Ground"); m.diffuse_color=(.105,.125,.16,1); m.use_nodes=True
 m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(.105,.125,.16,1)
 return m
def render_one(label,relpath,height,category):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 path=os.path.join(ASSET_ROOT,relpath)
 if not os.path.isfile(path): raise RuntimeError("Missing GLB: "+path)
 bpy.ops.import_scene.gltf(filepath=path)
 imported=[o for o in bpy.context.scene.objects if o.type in {"MESH","EMPTY","ARMATURE","CURVE"}]
 lo,hi=bounds(imported); original=hi.z-lo.z
 if original<=1e-5: raise RuntimeError("Invalid model height: "+label)
 factor=height/original; roots=[o for o in imported if o.parent not in imported]
 anchor=bpy.data.objects.new("Monster_Normalization_Root",None); bpy.context.scene.collection.objects.link(anchor)
 for ob in roots:
  mw=ob.matrix_world.copy(); ob.parent=anchor; ob.matrix_world=mw
 anchor.scale=(factor,)*3; bpy.context.view_layer.update()
 lo,hi=bounds(imported); anchor.location.z-=lo.z; anchor.location.x-=(lo.x+hi.x)*.5; anchor.location.y-=(lo.y+hi.y)*.5
 bpy.context.view_layer.update()
 bpy.ops.mesh.primitive_plane_add(size=30,location=(0,0,-.015)); bpy.context.object.name="Studio_Ground"; bpy.context.object.data.materials.append(ground_material())
 bpy.ops.object.camera_add(location=(height*1.35,-height*2.5,height*.95)); cam=bpy.context.object; cam.data.type="ORTHO"; cam.data.ortho_scale=max(height*2.05,3.5)
 target=Vector((0,0,height*.48)); cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler(); bpy.context.scene.camera=cam
 def light(name,loc,power,size):
  bpy.ops.object.light_add(type="AREA",location=loc); ob=bpy.context.object; ob.name=name; ob.data.energy=power; ob.data.shape="DISK"; ob.data.size=size
  ob.rotation_euler=(target-ob.location).to_track_quat("-Z","Y").to_euler()
 light("Key",(height*1.1,-height*1.6,height*2.2),1500,height*1.4); light("Fill",(-height*1.8,-height*.7,height*1.1),900,height*1.7); light("Rim",(0,height*1.5,height*1.8),1800,height*1.2)
 scene=bpy.context.scene; scene.render.engine="BLENDER_EEVEE_NEXT" if hasattr(bpy.types,"BLENDER_EEVEE_NEXT") else "BLENDER_EEVEE"
 if hasattr(scene,"eevee"): scene.eevee.taa_render_samples=64
 scene.render.resolution_x=1200; scene.render.resolution_y=1200; scene.render.resolution_percentage=100
 scene.render.image_settings.file_format="PNG"; scene.render.image_settings.color_mode="RGBA"; scene.world.color=(.035,.045,.065)
 scene.view_settings.view_transform="Standard"; scene.render.filepath=os.path.join(OUTPUT_DIR,label+".png")
 bpy.ops.render.render(write_still=True)
 print("PHASE4B_MONSTER_PNG_RENDERED:",label,"category=",category,"height_m=",height)
for model in models: render_one(*model)
print("PHASE4B_MONSTER_RENDER_COMPLETE: png_count=20")

# Render workflow retry: use isolated venv for Hugging Face client.
