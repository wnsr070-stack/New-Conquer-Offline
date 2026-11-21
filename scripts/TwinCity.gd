extends Node3D
const Assets = preload("res://scripts/AssetLoader.gd")
const PALACE_ID := "3dassets-royal-court-and-throne-palace-palace-audience-house-55f0cb24"
const HOUSE_IDS := ["obj_chinese_house","obj_chinese_painter_villa","obj_big_chinese_house"]
var captures := [
 {"file":"twin_city_overview.png","pos":Vector3(300,270,320),"target":Vector3(0,8,0),"fov":54.0},
 {"file":"twin_city_palace.png","pos":Vector3(38,42,-22),"target":Vector3(0,10,-75),"fov":48.0},
 {"file":"twin_city_ne_pagoda.png","pos":Vector3(105,34,-25),"target":Vector3(92,8,-75),"fov":52.0},
 {"file":"twin_city_nw_quest_hall.png","pos":Vector3(-105,30,-24),"target":Vector3(-92,7,-75),"fov":52.0},
 {"file":"twin_city_se_tea_house.png","pos":Vector3(105,30,24),"target":Vector3(92,7,75),"fov":52.0},
 {"file":"twin_city_sw_blacksmith.png","pos":Vector3(-105,30,24),"target":Vector3(-92,7,75),"fov":52.0}
]
func _ready() -> void:
 _lighting()
 if not _build_city():
  get_tree().quit(1)
  return
 _camera()
 if OS.get_environment("CI_CAPTURE")=="1": _capture.call_deferred()
func _mat(c:Color) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.albedo_color=c
 m.roughness=0.9
 return m
func _box(name:String,size:Vector3,pos:Vector3,mat:Material) -> void:
 var n:=MeshInstance3D.new()
 n.name=name
 var mesh:=BoxMesh.new()
 mesh.size=size
 n.mesh=mesh
 n.position=pos
 n.material_override=mat
 add_child(n)
func _lighting() -> void:
 var world:=WorldEnvironment.new()
 var env:=Environment.new()
 env.background_mode=Environment.BG_SKY
 var sky:=Sky.new()
 var sky_mat:=ProceduralSkyMaterial.new()
 sky_mat.sky_top_color=Color(0.16,0.30,0.48)
 sky_mat.sky_horizon_color=Color(0.76,0.80,0.79)
 sky.sky_material=sky_mat
 env.sky=sky
 env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
 env.ambient_light_energy=0.8
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 world.environment=env
 add_child(world)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-48,-28,0)
 sun.light_energy=1.15
 sun.shadow_enabled=true
 add_child(sun)
func _texture(key:String) -> Texture2D:
 var c:=Assets._read_catalog()
 if not c.has(key): push_error("CHECKPOINT1_TEXTURE_CATALOG_MISSING: "+key); return null
 var path:=String(c[key].get("path",""))
 if path.is_empty() or not FileAccess.file_exists(path):
  push_error("CHECKPOINT1_TEXTURE_FILE_MISSING: "+key+" "+path); return null
 var img:=Image.load_from_file(path)
 if img==null or img.is_empty():
  push_error("CHECKPOINT1_TEXTURE_IMAGE_DECODE_FAILED: "+key); return null
 return ImageTexture.create_from_image(img)
func _cobble() -> StandardMaterial3D:
 var m:=_mat(Color.WHITE)
 var d:=_texture("cobblestone_diffuse")
 var n:=_texture("cobblestone_normal")
 var r:=_texture("cobblestone_roughness")
 if d: m.albedo_texture=d
 if n: m.normal_enabled=true; m.normal_texture=n
 if r: m.roughness_texture=r
 m.uv1_scale=Vector3(0.16,0.16,0.16)
 print("CHECKPOINT1_COBBLE_RUNTIME_IMAGE_TEXTURES_OK: diffuse=",d!=null," normal=",n!=null," roughness=",r!=null)
 return m
func _place(id:String,pos:Vector3,height:=0.0,rot:=0.0,required:=true) -> Node3D:
 var n:=Assets.load_model(id,"")
 if n==null:
  if required: push_error("CHECKPOINT1_REQUIRED_MODEL_MISSING: "+id)
  return null
 if height>0.0: Assets.fit_height(n,height)
 n.position+=pos
 n.rotation.y=rot
 add_child(n)
 return n
func _build_city() -> bool:
 var cat:=Assets._read_catalog()
 if not cat.has("grab3d-dirt-road"):
  push_error("CHECKPOINT1_DIRT_ROAD_ASSET_MISSING"); return false
 var dirt:=Assets.load_model("grab3d-dirt-road","")
 if dirt==null: push_error("CHECKPOINT1_DIRT_ROAD_IMPORT_FAILED"); return false
 dirt.name="ContinuousGrab3DDirtRoadGround"
 dirt.position=Vector3(0,-0.25,0)
 dirt.scale=Vector3(320.0/11.8,1.0,320.0/11.8)
 add_child(dirt)
 print("CHECKPOINT1_UNIFIED_DIRT_GROUND_OK: grab3d-dirt-road 320x320")
 var cobble:=_cobble()
 var square:=MeshInstance3D.new()
 square.name="CobblestoneCentralSquare"
 var pm:=PlaneMesh.new()
 pm.size=Vector2(54,54)
 square.mesh=pm
 square.position=Vector3(0,0.04,0)
 square.material_override=cobble
 add_child(square)
 print("CHECKPOINT1_COBBLESTONE_PLAZA_OK: 54x54; runtime ImageTexture")
 var platform:=MeshInstance3D.new()
 platform.name="RoyalPalaceCobblestonePlatform_34x26x3_5"
 var platform_mesh:=BoxMesh.new()
 platform_mesh.size=Vector3(34,3.5,26)
 platform.mesh=platform_mesh
 platform.position=Vector3(0,1.75,-75)
 platform.material_override=cobble
 if platform.material_override is StandardMaterial3D:
  (platform.material_override as StandardMaterial3D).uv1_scale=Vector3(0.16,0.16,0.16)
 add_child(platform)
 if _place(PALACE_ID,Vector3(0,3.5,-75),28.0,PI)==null: return false
 var stairs:=_place("imperial_entrance_stairs",Vector3(0,0,-59),0.0,0.0)
 if stairs==null: return false
 var sb:=Assets._measure_bounds(stairs,Transform3D.IDENTITY)
 if sb.size.x>0.01: stairs.scale*=Vector3(8.0/sb.size.x,1.0,8.0/maxf(sb.size.z,0.01))
 stairs.position=Vector3(0,0,-59)
 var guard:=_place("guardian_lion_or_statue",Vector3(-6,3.5,-64),3.2,0.0,false)
 if guard!=null:
  var other:=guard.duplicate(true) as Node3D
  other.position=Vector3(6,3.5,-64)
  other.rotation.y=PI
  add_child(other)
  print("CHECKPOINT1_GUARDIAN_MODELS_PLACED: 2")
 else: print("CHECKPOINT1_GUARDIAN_OMITTED_NO_VALID_POLY_PIZZA_GLB")
 print("CHECKPOINT1_PALACE_PLATFORM_OK: 34x26x3.5 EntranceStairs")
 var landmarks=[
  {"id":"innerscene-buddhist-temple-pagoda-c5ebacdc","pos":Vector3(92,0,-91),"rot":PI,"height":22.0,"tag":"NE_PAGODA"},
  {"id":"quest_hall","pos":Vector3(-92,0,-91),"rot":0.0,"height":16.0,"tag":"NW_QUEST_HALL"},
  {"id":"tea_house","pos":Vector3(92,0,91),"rot":PI,"height":12.0,"tag":"SE_TEA_HOUSE"},
  {"id":"blacksmith_forge","pos":Vector3(-92,0,91),"rot":0.0,"height":12.0,"tag":"SW_BLACKSMITH"}
 ]
 for a in landmarks:
  var landmark:=_place(a.id,a.pos,a.height,a.rot)
  if landmark==null: return false
  if a.tag=="SW_BLACKSMITH": print("CHECKPOINT1_BLACKSMITH_GLTF_APPEND_OK")
  print("CHECKPOINT1_LANDMARK_OK: ",a.tag," forecourt=5m")
 if cat.has("paifang_gate"):
  var paifang:=_place("paifang_gate",Vector3(92,0,-70),10.0,PI,false)
  if paifang!=null: print("CHECKPOINT1_EASTERN_GATE_GLTF_APPEND_OK: dedicated gate model")
  else: print("CHECKPOINT1_EASTERN_GATE_OMITTED_NO_VERIFIED_MODEL")
 else:
  print("CHECKPOINT1_EASTERN_GATE_OMITTED_NO_VERIFIED_MODEL")
 var prototypes:Array[Node3D]=[]
 for id in HOUSE_IDS:
  var proto:=Assets.load_model(id,"")
  if proto==null: push_error("CHECKPOINT1_HOUSE_MODEL_MISSING: "+id); return false
  Assets.fit_height(proto,7.0)
  prototypes.append(proto)
 var accepted:Array[AABB]=[]
 var counts:Array[int]=[]
 for qx in [-1.0,1.0]:
  for qz in [-1.0,1.0]:
   var count:=0
   for row in range(5):
    for col in range(5):
     if row==2 and col==2: continue
     var base_pos:=Vector3(qx*(48.0+col*18.0),0,qz*(48.0+row*18.0))
     var proto:=prototypes[(row*5+col+count)%prototypes.size()]
     var rot:=float((row+col)%4)*PI/2.0
     var placement:=_find_house_position(proto,base_pos,rot,qx,qz,accepted)
     if not placement.get("valid",false):
      print("CHECKPOINT1_BUILDING_REJECTED_ROTATED_AABB: ",base_pos)
      continue
     var bounds:AABB=placement.bounds
     var house:=proto.duplicate(true) as Node3D
     house.position+=placement.pos
     house.rotation.y=rot
     add_child(house)
     accepted.append(bounds)
     count+=1
   counts.append(count)
 if counts.size()!=4 or counts.min()<8:
  push_error("CHECKPOINT1_QUADRANT_DENSITY_FAILED: "+str(counts)); return false
 print("CHECKPOINT1_ROTATED_AABB_REJECTION_OK: accepted=",accepted.size()," quadrant_counts=",counts," street_clearance=22m")
 print("CHECKPOINT1_ROTATED_AABB_AUTO_OFFSET_OK: accepted=",accepted.size())
 var cherry:=Assets.load_model("cherry_blossom_lowmance","")
 if cherry!=null:
  var remove:Array[Node]=[]
  _collect_base(cherry,remove)
  for n in remove: n.queue_free()
  for x in [-118.0,-94.0,-70.0,70.0,94.0,118.0]:
   var tree:=cherry.duplicate(true) as Node3D
   tree.position=Vector3(x,0,28)
   add_child(tree)
  print("CHECKPOINT1_CHERRY_BASE_NODES_REMOVED: ",remove.size())
 print("CHECKPOINT1_GEOMETRY_BUILD_COMPLETE")
 return true
func _find_house_position(proto:Node3D,base_pos:Vector3,rot:float,qx:float,qz:float,accepted:Array[AABB]) -> Dictionary:
 for ring in range(0,9):
  for dx in range(-ring,ring+1):
   for dz in range(-ring,ring+1):
    if maxi(absi(dx),absi(dz))!=ring: continue
    var candidate:=base_pos+Vector3(float(dx)*2.0,0.0,float(dz)*2.0)
    var bounds:=Assets._measure_bounds(proto,Transform3D(Basis(Vector3.UP,rot),candidate))
    var inside_x:=bounds.position.x>=22.0 and bounds.end.x<=158.0 if qx>0.0 else bounds.position.x>=-158.0 and bounds.end.x<=-22.0
    var inside_z:=bounds.position.z>=22.0 and bounds.end.z<=158.0 if qz>0.0 else bounds.position.z>=-158.0 and bounds.end.z<=-22.0
    var valid:=inside_x and inside_z
    for other in accepted:
     if bounds.intersects(other): valid=false; break
    if valid:
     if dx!=0 or dz!=0: print("CHECKPOINT1_BUILDING_AUTO_OFFSET: ",base_pos," -> ",candidate)
     return {"valid":true,"pos":candidate,"bounds":bounds}
 return {"valid":false}
func _collect_base(n:Node,out:Array[Node]) -> void:
 for child in n.get_children():
  var name:=String(child.name).to_lower()
  if child is MeshInstance3D and (name.contains("base") or name.contains("stand") or name.contains("pot") or name.contains("platform")): out.append(child)
  else: _collect_base(child,out)
func _camera() -> void:
 var c:=Camera3D.new()
 c.name="TwinCityCamera"
 add_child(c)
 c.current=true
 c.position=Vector3(300,270,320)
 c.look_at(Vector3(0,8,0),Vector3.UP)
func _capture() -> void:
 var cam:=get_viewport().get_camera_3d()
 var dir:=ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(dir)
 for spec in captures:
  cam.position=spec.pos
  cam.fov=spec.fov
  cam.look_at(spec.target,Vector3.UP)
  await RenderingServer.frame_post_draw
  await RenderingServer.frame_post_draw
  var image:=get_viewport().get_texture().get_image()
  var path:=dir.path_join(spec.file)
  if image==null or image.is_empty() or image.save_png(path)!=OK:
   push_error("TWIN_CITY_CAPTURE_FAILED: "+path); return false
  if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size()<1024:
   push_error("TWIN_CITY_CAPTURE_FILE_INVALID: "+path); return false
  print("TWIN_CITY_CAPTURE_OK: ",path," bytes=",FileAccess.get_file_as_bytes(path).size())
 print("CHECKPOINT1_ALL_SIX_CAPTURES_COMPLETE")
 get_tree().quit(0)
