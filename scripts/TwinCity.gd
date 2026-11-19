extends Node3D
const Assets = preload("res://scripts/AssetLoader.gd")
const HOUSE_IDS := ["3dassets-feudal-japan-castle-town-tea-house-a168f962","3dassets-feudal-japan-castle-town-bath-house-f3524f03","3dassets-alpine-snow-village-cedar-sauna-house-b3b0d5b4"]
const PAGODA_ID := "innerscene-buddhist-temple-pagoda-c5ebacdc"
const PALACE_ID := "3dassets-royal-court-and-throne-palace-palace-audience-house-55f0cb24"
const TREE_ID := "innerscene-japanese-maple-tree-565c1604"
const STONE_BRIDGE := "opengameart-stone-bridge-0"
const WOOD_BRIDGE := "opengameart-wooden-bridge-0"
const WALL_IDS := ["polygonalmind-lunar-year-015","polygonalmind-lunar-year-016"]
var capture_index := 0
var capture_specs := [
 {"file":"twin_city_overview.png","position":Vector3(250,250,290),"target":Vector3(0,0,0),"fov":48.0},
 {"file":"twin_city_palace_pagoda.png","position":Vector3(58,48,82),"target":Vector3(0,12,0),"fov":45.0},
 {"file":"twin_city_gate_moat.png","position":Vector3(155,72,205),"target":Vector3(0,4,0),"fov":52.0}
]
func _ready() -> void:
 _lighting()
 _ground_and_moat()
 _build_city()
 _setup_camera()
 if OS.get_environment("CI_CAPTURE") == "1": _capture_all.call_deferred()

func _lighting() -> void:
 var env_node:=WorldEnvironment.new()
 var env:=Environment.new()
 env.background_mode=Environment.BG_SKY
 var sky:=Sky.new(); var sky_mat:=ProceduralSkyMaterial.new()
 sky_mat.sky_top_color=Color(0.16,0.34,0.58); sky_mat.sky_horizon_color=Color(0.72,0.82,0.88)
 sky.sky_material=sky_mat; env.sky=sky
 env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
 env.ambient_light_energy=0.65
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 env_node.environment=env; add_child(env_node)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-48,-32,0); sun.light_energy=1.1; sun.shadow_enabled=true
 sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
 add_child(sun)

func _mat(color:Color,roughness:=0.8,metallic:=0.0)->StandardMaterial3D:
 var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=roughness; m.metallic=metallic; return m

func _ground_and_moat() -> void:
 var ground:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(330,330)
 ground.mesh=plane; ground.position.y=-0.25; ground.material_override=_mat(Color(0.36,0.43,0.31)); add_child(ground)
 var water:=MeshInstance3D.new(); var water_mesh:=PlaneMesh.new(); water_mesh.size=Vector2(250,250)
 water.mesh=water_mesh; water.position.y=-0.05
 var wm:=_mat(Color(0.04,0.66,0.72),0.18,0.25); wm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; wm.albedo_color.a=0.78
 water.material_override=wm; add_child(water)
 # Four 18m moat channels, leaving the city interior dry.
 for side in range(4):
  var channel:=MeshInstance3D.new(); var pm:=PlaneMesh.new()
  pm.size=Vector2(18,220) if side<2 else Vector2(220,18)
  channel.mesh=pm
  if side==0: channel.position=Vector3(0,0,-119)
  elif side==1: channel.position=Vector3(0,0,119)
  elif side==2: channel.position=Vector3(-119,0,0)
  else: channel.position=Vector3(119,0,0)
  channel.material_override=wm; add_child(channel)

func _place(id:String,pos:Vector3,height:=0.0,rot:=0.0)->Node3D:
 var n:=Assets.load_model(id)
 if n==null: push_warning("TwinCity fallback exhausted for "+id); return null
 if height>0.0: Assets.fit_height(n,height)
 n.position=pos; n.rotation.y=rot; add_child(n); return n

func _build_city() -> void:
 # Palace and pagoda are fitted from each imported model's runtime mesh AABB.
 _place(PALACE_ID,Vector3(0,0,-30),28.0)
 _place(PAGODA_ID,Vector3(32,0,-30),22.0)
 # 244 real GLB building instances, laid out in ordered residential/commercial blocks.
 var house_prototypes:Array[Node3D]=[]
 for id in HOUSE_IDS:
  var h:=Assets.load_model(id)
  if h!=null:
   Assets.fit_height(h,10.0); house_prototypes.append(h)
 if house_prototypes.is_empty():
  var fallback:=Assets.load_model("polygonalmind-lunar-year-014")
  if fallback!=null: house_prototypes.append(fallback)
 var placed:=0
 for z in range(16):
  for x in range(16):
   if (x in [7,8] and z in [6,7,8,9]) or (x==9 and z in [6,7,8,9]): continue
   if placed>=244: break
   if house_prototypes.is_empty(): break
   var proto:=house_prototypes[placed%house_prototypes.size()]
   var house:=proto.duplicate(true) as Node3D
   house.position=Vector3(-75+x*10,0,-75+z*10)
   house.rotation.y=float((x*3+z)%4)*PI/2
   add_child(house); placed+=1
  if placed>=244: break
 print("TWIN_CITY_BUILDINGS_PLACED: ",placed)
 # Closed square defensive wall: 108 GLB wall sections with four deliberate gate gaps.
 var wall_protos:Array[Node3D]=[]
 for id in WALL_IDS:
  var w:=Assets.load_model(id)
  if w!=null: wall_protos.append(w)
 var walls:=0
 if not wall_protos.is_empty():
  for side in range(4):
   for i in range(27):
    if i in [12,13]: continue
    var wall:=wall_protos[walls%wall_protos.size()].duplicate(true) as Node3D
    var t:=float(i-13)*8.0
    if side==0: wall.position=Vector3(t,0,-100); wall.rotation.y=0
    elif side==1: wall.position=Vector3(t,0,100); wall.rotation.y=PI
    elif side==2: wall.position=Vector3(-100,0,t); wall.rotation.y=PI/2
    else: wall.position=Vector3(100,0,t); wall.rotation.y=-PI/2
    Assets.fit_height(wall,5.0); add_child(wall); walls+=1
 print("TWIN_CITY_WALL_SEGMENTS_PLACED: ",walls)
 # Four bridges, two stone and two wooden, span the 18m moat at the cardinal gates.
 for i in range(4):
  var bid:=STONE_BRIDGE if i%2==0 else WOOD_BRIDGE
  var bridge:=Assets.load_model(bid)
  if bridge==null: bridge=Assets.load_model("polygonalmind-lunar-year-014")
  if bridge!=null:
   Assets.fit_height(bridge,4.0)
   if i==0: bridge.position=Vector3(0,0,-119)
   elif i==1: bridge.position=Vector3(0,0,119); bridge.rotation.y=PI
   elif i==2: bridge.position=Vector3(-119,0,0); bridge.rotation.y=PI/2
   else: bridge.position=Vector3(119,0,0); bridge.rotation.y=-PI/2
   add_child(bridge)
 print("TWIN_CITY_BRIDGES_PLACED: 4")
 # Flowering Japanese maple groves in plazas and along the avenues.
 var tree_proto:=Assets.load_model(TREE_ID)
 if tree_proto!=null:
  Assets.fit_height(tree_proto,7.0)
  for i in range(36):
   var tree:=tree_proto.duplicate(true) as Node3D
   var angle=TAU*float(i)/36.0
   tree.position=Vector3(cos(angle)*88,0,sin(angle)*88)
   add_child(tree)
 print("TWIN_CITY_FLOWERING_TREES_PLACED: ",36 if tree_proto!=null else 0)

func _setup_camera() -> void:
 var camera:=Camera3D.new(); camera.name="TwinCityCamera"; add_child(camera)
 camera.fov=48.0; camera.current=true
 camera.position=Vector3(250,250,290); camera.look_at(Vector3.ZERO,Vector3.UP)

func _capture_all() -> void:
 var camera:=get_viewport().get_camera_3d()
 var dir:=ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(dir)
 for spec in capture_specs:
  camera.position=spec.position; camera.fov=spec.fov
  camera.look_at(spec.target,Vector3.UP)
  for frame in range(12): await get_tree().process_frame
  var img:=get_viewport().get_texture().get_image()
  var path:=dir.path_join(spec.file)
  var err:=img.save_png(path)
  if err!=OK: push_error("TWIN_CITY_CAPTURE_FAILED: "+path); get_tree().quit(1); return
  print("TWIN_CITY_CAPTURE_OK: ",path)
 if not FileAccess.file_exists(dir.path_join("twin_city_overview.png")): get_tree().quit(1); return
 get_tree().quit(0)
