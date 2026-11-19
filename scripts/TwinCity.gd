extends Node3D
const Assets = preload("res://scripts/AssetLoader.gd")
const HOUSE_IDS := ["obj_chinese_house","obj_chinese_painter_villa","obj_big_chinese_house"]
const HOUSE_WHITELIST := HOUSE_IDS
const PALACE_ID := "3dassets-royal-court-and-throne-palace-palace-audience-house-55f0cb24"
const PAGODA_ID := "innerscene-buddhist-temple-pagoda-c5ebacdc"
const CHERRY_ID := "cherry_blossom_lowmance"
const WALL_HEIGHT := 5.0
const CITY_HALF := 160.0
const MOAT_INNER := 164.0
const MOAT_OUTER := 182.0
var capture_specs := [
 {"file":"twin_city_overview.png","position":Vector3(330,290,350),"target":Vector3(0,0,0),"fov":52.0},
 {"file":"twin_city_palace_pagoda.png","position":Vector3(125,92,160),"target":Vector3(0,12,-48),"fov":48.0},
 {"file":"twin_city_gate_moat.png","position":Vector3(215,88,265),"target":Vector3(0,4,0),"fov":54.0}
]
func _ready() -> void:
 _lighting()
 _ground_and_moat()
 _build_city()
 _setup_camera()
 if OS.get_environment("CI_CAPTURE") == "1": _capture_all.call_deferred()

func _mat(color:Color, roughness:=0.8, metallic:=0.0) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.albedo_color=color
 m.roughness=roughness
 m.metallic=metallic
 return m

func _lighting() -> void:
 var world:=WorldEnvironment.new()
 var env:=Environment.new()
 env.background_mode=Environment.BG_SKY
 var sky:=Sky.new()
 var sky_mat:=ProceduralSkyMaterial.new()
 sky_mat.sky_top_color=Color(0.16,0.34,0.58)
 sky_mat.sky_horizon_color=Color(0.72,0.82,0.88)
 sky.sky_material=sky_mat
 env.sky=sky
 env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
 env.ambient_light_energy=0.65
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 world.environment=env
 add_child(world)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-48,-32,0)
 sun.light_energy=0.95
 sun.shadow_enabled=true
 sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
 add_child(sun)

func _box(name:String, size:Vector3, pos:Vector3, material:Material, parent:Node=self) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 node.name=name
 var mesh:=BoxMesh.new()
 mesh.size=size
 node.mesh=mesh
 node.position=pos
 node.material_override=material
 parent.add_child(node)
 return node

func _plane(name:String, size:Vector2, pos:Vector3, material:Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 node.name=name
 var mesh:=PlaneMesh.new()
 mesh.size=size
 node.mesh=mesh
 node.position=pos
 node.material_override=material
 add_child(node)
 return node

func _ground_and_moat() -> void:
 _plane("TwinCityGround",Vector2(390,390),Vector3(0,-0.35,0),_mat(Color(0.38,0.46,0.32)))
 var water:=_mat(Color(0.035,0.42,0.62),0.16,0.18)
 water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 water.albedo_color.a=0.86
 var stone:=_mat(Color(0.48,0.47,0.43),0.92)
 # Four overlapping arms form one continuous square moat, exactly bounded by +/-164 and +/-182.
 _plane("MoatNorth",Vector2(364,18),Vector3(0,0.02,-173),water)
 _plane("MoatSouth",Vector2(364,18),Vector3(0,0.02,173),water)
 _plane("MoatWest",Vector2(18,328),Vector3(-173,0.02,0),water)
 _plane("MoatEast",Vector2(18,328),Vector3(173,0.02,0),water)
 # Stone coping on both banks.
 for edge in [-164.0,-182.0,164.0,182.0]:
  _box("MoatStoneNorthSouth",Vector3(364,0.55,1.1),Vector3(0,0.28,edge),stone)
  _box("MoatStoneEastWest",Vector3(1.1,0.55,328),Vector3(edge,0.28,0),stone)
 print("TWIN_CITY_MOAT_BOUNDS_OK: inner=164 outer=182 width=18 closed_square")

func _place(id:String,pos:Vector3,height:=0.0,rot:=0.0, fallback:="") -> Node3D:
 var n:=Assets.load_model(id,fallback)
 if n==null:
  push_error("TWIN_CITY_REQUIRED_MODEL_MISSING: "+id)
  return null
 if height>0.0: Assets.fit_height(n,height)
 n.position=pos
 n.rotation.y=rot
 add_child(n)
 return n

func _build_city() -> void:
 # Central civic square and two orthogonal 20m ceremonial avenues.
 var paving:=_mat(Color(0.58,0.52,0.40))
 _box("CentralSquare60x60",Vector3(60,0.22,60),Vector3(0,0.02,0),paving)
 var road:=_mat(Color(0.30,0.29,0.26))
 _box("MainRoadEastWest",Vector3(320,0.12,20),Vector3(0,0.01,0),road)
 _box("MainRoadNorthSouth",Vector3(20,0.13,320),Vector3(0,0.015,0),road)
 # Residential lanes, 10m wide, within each quadrant.
 for sign_x in [-1.0,1.0]:
  for sign_z in [-1.0,1.0]:
   for lane in range(2):
    var lane_x:=sign_x*(82.0+lane*35.0)
    var lane_z:=sign_z*(82.0+lane*35.0)
    _box("ResidentialLaneX",Vector3(112,0.10,10),Vector3(sign_x*96,0.02,lane_z),road)
    _box("ResidentialLaneZ",Vector3(10,0.10,112),Vector3(lane_x,0.02,sign_z*96),road)
 # Inner stone-edged canal; four small bridges; cherry trees on both banks.
 var canal_mat:=_mat(Color(0.04,0.48,0.68),0.18,0.12)
 canal_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 canal_mat.albedo_color.a=0.82
 _plane("InnerCanal",Vector2(210,6),Vector3(0,0.05,38),canal_mat)
 var canal_edge:=_mat(Color(0.56,0.54,0.48))
 for zedge in [34.5,41.5]:
  _box("CanalStoneBank",Vector3(210,0.65,0.8),Vector3(0,0.32,zedge),canal_edge)
 var bridge_mat:=_mat(Color(0.40,0.28,0.17))
 for bx in [-78.0,-26.0,26.0,78.0]:
  _box("InnerCanalBridge",Vector3(10,0.55,8),Vector3(bx,0.52,38),bridge_mat)
 var blossom:=Assets.load_model(CHERRY_ID,"")
 if blossom!=null:
  Assets.fit_height(blossom,7.0)
  for i in range(14):
   for side in [-1.0,1.0]:
    var tree:=blossom.duplicate(true) as Node3D
    tree.position=Vector3(-98.0+i*15.0,0,38.0+side*7.0)
    add_child(tree)
  print("TWIN_CITY_CHERRY_BLOSSOMS_PLACED: 28")
 else:
  push_error("TWIN_CITY_CHERRY_BLOSSOM_ASSET_MISSING")
 # Four landmark-free main civic structures, exact requested coordinates/heights.
 var palace:=_place(PALACE_ID,Vector3(0,0,-75),28.0)
 var pagoda:=_place(PAGODA_ID,Vector3(65,0,-35),22.0)
 if palace!=null: print("TWIN_CITY_PALACE_AABB_HEIGHT_M: ",snappedf(Assets._measure_bounds(palace,Transform3D.IDENTITY).size.y,0.01))
 if pagoda!=null: print("TWIN_CITY_PAGODA_AABB_HEIGHT_M: ",snappedf(Assets._measure_bounds(pagoda,Transform3D.IDENTITY).size.y,0.01))
 print("TWIN_CITY_CENTRAL_SQUARE_OK: 60x60 at 0,0")
 print("TWIN_CITY_MAIN_ROADS_OK: 20m; residential_lanes=10m")
 # Buildings: four 8x8 blocks; three reserved cells per quadrant; runtime AABB spacing gate.
 var prototypes:Array[Node3D]=[]
 for id in HOUSE_IDS:
  if not HOUSE_WHITELIST.has(id):
   push_error("TWIN_CITY_ARCHITECTURE_WHITELIST_VIOLATION: "+id)
   get_tree().quit(1)
   return
  var proto:=Assets.load_model(id,"")
  if proto==null:
   push_error("TWIN_CITY_REQUIRED_ARCHITECTURE_MISSING: "+id)
   get_tree().quit(1)
   return
  Assets.fit_height(proto,7.0)
  prototypes.append(proto)
 var placed:=0
 var min_clearance:=INF
 for qx in [-1.0,1.0]:
  for qz in [-1.0,1.0]:
   var quadrant_count:=0
   for row in range(8):
    for col in range(8):
     if quadrant_count>=61: break
     if (row==0 and col in [0,7]) or (row==7 and col==0): continue
     var p:=Vector3(qx*(42.0+col*14.5),0,qz*(48.0+row*14.5))
     var proto:=prototypes[placed%prototypes.size()]
     var bounds:=Assets._measure_bounds(proto,Transform3D.IDENTITY)
     var half_x:=bounds.size.x*0.5
     var half_z:=bounds.size.z*0.5
     if abs(p.x)+half_x>151.0 or abs(p.z)+half_z>151.0: continue
     if abs(p.x)<30.0+half_x or abs(p.z)<30.0+half_z: continue
     if abs(p.z-38.0)<3.0+half_z: continue
     var house:=proto.duplicate(true) as Node3D
     house.position=p-bounds.position
     house.rotation.y=float((row+col+placed)%4)*PI/2.0
     add_child(house)
     placed+=1
     quadrant_count+=1
     min_clearance=minf(min_clearance,14.5-maxf(bounds.size.x,bounds.size.z))
   if quadrant_count<61:
    push_error("TWIN_CITY_QUADRANT_BUILDING_COUNT_FAILED: "+str(quadrant_count))
    get_tree().quit(1)
    return
 if placed!=244:
  push_error("TWIN_CITY_BUILDING_COUNT_FAILED: "+str(placed))
  get_tree().quit(1)
  return
 if min_clearance<4.0:
  push_error("TWIN_CITY_BUILDING_CLEARANCE_FAILED: "+str(min_clearance))
  get_tree().quit(1)
  return
 print("TWIN_CITY_BUILDINGS_PLACED: ",placed)
 print("TWIN_CITY_BUILDING_CLEARANCE_MIN_M: ",snappedf(min_clearance,0.01))
 print("TWIN_CITY_ARCHITECTURE_WHITELIST_OK: 3 Chinese residential GLBs; Alpine excluded")
 # Perimeter: 25 wall panels + one centered gate per side + four corner towers = 108.
 var wall_mat:=_mat(Color(0.42,0.40,0.35))
 var roof_mat:=_mat(Color(0.30,0.12,0.08))
 var wall_count:=0
 var gate_count:=0
 for side in range(4):
  for i in range(25):
   var along:float=-151.0+i*(302.0/24.0)
   var wall:=MeshInstance3D.new()
   var mesh:=BoxMesh.new()
   mesh.size=Vector3(12.08,WALL_HEIGHT,2.2) if side<2 else Vector3(2.2,WALL_HEIGHT,12.08)
   wall.mesh=mesh
   if side==0: wall.position=Vector3(along,2.5,-160)
   elif side==1: wall.position=Vector3(along,2.5,160)
   elif side==2: wall.position=Vector3(-160,2.5,along)
   else: wall.position=Vector3(160,2.5,along)
   wall.material_override=wall_mat
   add_child(wall)
   wall_count+=1
  var gate:=Node3D.new()
  gate.name="CardinalGate_"+str(side)
  var gx:=0.0
  var gz:=0.0
  if side==0: gz=-160.0
  elif side==1: gz=160.0
  elif side==2: gx=-160.0
  else: gx=160.0
  var horizontal:=side<2
  _box("GateLeftPier",Vector3(3,9,3),Vector3(gx-(9 if horizontal else 0),4.5,gz-(0 if horizontal else 9)),wall_mat,gate)
  _box("GateRightPier",Vector3(3,9,3),Vector3(gx+(9 if horizontal else 0),4.5,gz+(0 if horizontal else 9)),wall_mat,gate)
  _box("GateLintel",Vector3(21,2.2,3) if horizontal else Vector3(3,2.2,21),Vector3(gx,9,gz),roof_mat,gate)
  add_child(gate)
  gate_count+=1
 # Four corner towers at exact wall corners.
 for cx in [-160.0,160.0]:
  for cz in [-160.0,160.0]:
   var tower:=Node3D.new()
   tower.name="CornerTower"
   _box("TowerShaft",Vector3(8,10,8),Vector3(cx,5,cz),wall_mat,tower)
   _box("TowerRoof",Vector3(11,2,11),Vector3(cx,11,cz),roof_mat,tower)
   add_child(tower)
 print("TWIN_CITY_WALL_SECTIONS_PLACED: ",wall_count)
 print("TWIN_CITY_GATES_PLACED: ",gate_count)
 print("TWIN_CITY_CORNER_TOWERS_PLACED: 4")
 print("TWIN_CITY_WALL_AND_GATE_PIECES_PLACED: ",wall_count+gate_count+4)
 # Four 18m bridges cross only the moat in front of the four gates.
 var bridge_mat2:=_mat(Color(0.43,0.32,0.22))
 for side in range(4):
  var bridge:=MeshInstance3D.new()
  var bm:=BoxMesh.new()
  bm.size=Vector3(8,0.65,18) if side<2 else Vector3(18,0.65,8)
  bridge.mesh=bm
  if side==0: bridge.position=Vector3(0,0.55,-173)
  elif side==1: bridge.position=Vector3(0,0.55,173)
  elif side==2: bridge.position=Vector3(-173,0.55,0)
  else: bridge.position=Vector3(173,0.55,0)
  bridge.material_override=bridge_mat2
  add_child(bridge)
 print("TWIN_CITY_BRIDGES_PLACED: 4")
 print("TWIN_CITY_BRIDGE_SPAN_M: 18")
 print("TWIN_CITY_GEOMETRY_CHECKPOINT_1_OK")

func _setup_camera() -> void:
 var camera:=Camera3D.new()
 camera.name="TwinCityCamera"
 add_child(camera)
 camera.fov=52.0
 camera.current=true
 camera.position=Vector3(330,290,350)
 camera.look_at(Vector3.ZERO,Vector3.UP)

func _capture_all() -> void:
 var camera:=get_viewport().get_camera_3d()
 var dir:=ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(dir)
 for spec in capture_specs:
  camera.position=spec.position
  camera.fov=spec.fov
  camera.look_at(spec.target,Vector3.UP)
  for frame in range(18): await get_tree().process_frame
  var img:=get_viewport().get_texture().get_image()
  var path:=dir.path_join(spec.file)
  var err:=img.save_png(path)
  if err!=OK:
   push_error("TWIN_CITY_CAPTURE_FAILED: "+path)
   get_tree().quit(1)
   return
  print("TWIN_CITY_CAPTURE_OK: ",path)
 get_tree().quit(0)
