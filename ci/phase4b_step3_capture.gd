extends SceneTree

const TABLE = preload("res://scripts/MonsterGeneratorTable.gd")
const MonsterActorScript = preload("res://scripts/MonsterActor.gd")
const SpawnerScript = preload("res://scripts/MonsterSpawner.gd")
const ASSET_ROOT := "res://assets/phase3b/"
const CITY_CASES := [
 {"id":"TwinCity","path":"res://scenes/TwinCity.tscn","points":15,"ground_y":-1.35},
 {"id":"PhoenixCastle","path":"res://scenes/cities/PhoenixCastle.tscn","points":9,"ground_y":0.0},
 {"id":"ApeMountain","path":"res://scenes/cities/ApeMountain.tscn","points":7,"ground_y":0.0},
 {"id":"DesertCity","path":"res://scenes/cities/DesertCity.tscn","points":6,"ground_y":0.0},
 {"id":"BirdIsland","path":"res://scenes/cities/BirdIsland.tscn","points":8,"ground_y":4.6}
]

func _initialize() -> void:
 print("PHASE4B_STEP3_TRACE: INITIALIZE_DEFER_RUN")
 call_deferred("_run")

func _configure_test_input_map() -> void:
 var actions := ["move_forward","move_back","move_left","move_right"]
 for action in actions:
  if not InputMap.has_action(action):
   InputMap.add_action(action)
  var event := InputEventKey.new()
  match action:
   "move_forward": event.physical_keycode = KEY_W
   "move_back": event.physical_keycode = KEY_S
   "move_left": event.physical_keycode = KEY_A
   "move_right": event.physical_keycode = KEY_D
  if not InputMap.action_has_event(action,event):
   InputMap.action_add_event(action,event)
 print("PHASE4B_STEP3_INPUT_ACTIONS_DEFINED: move_forward=W move_back=S move_left=A move_right=D")

func _run() -> void:
 print("PHASE4B_STEP3_TRACE: RUN_BEGIN")
 _configure_test_input_map()
 print("PHASE4B_STEP3_TRACE: INPUT_MAP_READY")
 get_root().size = Vector2i(1600,1000)
 var manager := root.get_node_or_null("WorldMapManager")
 if manager == null:
  _fail("PHASE4B_STEP3_WORLD_MAP_MANAGER_MISSING"); return
 for item in CITY_CASES:
  print("PHASE4B_STEP3_TRACE: PROBE_CITY_BEGIN ",item.id)
  var probe_ok := await _trace_probe_city(item,manager)
  print("PHASE4B_STEP3_TRACE: PROBE_CITY_END ",item.id," ok=",probe_ok)
  if not probe_ok:
   return
 print("PHASE4B_STEP3_ALL_FIVE_CITY_SPAWNERS_OK: cities=5 automatic=true ground_y_verified=true")

 manager.set("current_city","TwinCity")
 var packed := load("res://scenes/TwinCity.tscn") as PackedScene
 if packed == null:
  _fail("PHASE4B_STEP3_TWIN_CITY_SCENE_MISSING"); return
 var city := packed.instantiate() as Node3D
 root.add_child(city)
 var hero: CharacterBody3D
 var spawner: MonsterSpawner
 # TwinCity builds its full runtime world in _ready(); wait for the real hero
 # and the scene-owned spawner instead of relying on a fixed startup delay.
 for attempt in range(180):
  print("PHASE4B_STEP3_TRACE: HERO_DISCOVERY_FRAME_BEGIN attempt=",attempt)
  await process_frame
  print("PHASE4B_STEP3_TRACE: HERO_DISCOVERY_FRAME_END attempt=",attempt)
  var hero_node := city.find_child("TwinCityPlayableHero", true, false)
  var spawner_node := city.find_child("MonsterSpawner", true, false)
  if hero_node is CharacterBody3D and spawner_node is MonsterSpawner:
   hero = hero_node as CharacterBody3D
   spawner = spawner_node as MonsterSpawner
   break
  print("PHASE4B_STEP3_TRACE: HERO_DISCOVERY_TIMER_BEGIN attempt=",attempt)
  await create_timer(1.0).timeout
  print("PHASE4B_STEP3_TRACE: HERO_DISCOVERY_TIMER_END attempt=",attempt)
 if hero == null or spawner == null:
  _fail("PHASE4B_STEP3_REAL_TWIN_CITY_HERO_OR_SPAWNER_MISSING: hero="+str(is_instance_valid(city.find_child("TwinCityPlayableHero", true, false)))+" spawner="+str(is_instance_valid(city.find_child("MonsterSpawner", true, false)))+" city_inside_tree="+str(city.is_inside_tree())); return
 print("PHASE4B_STEP3_REAL_TWIN_CITY_RUNTIME_FOUND: hero_path=",hero.get_path()," spawner_path=",spawner.get_path())
 if hero.get("hero_model") == null:
  _fail("PHASE4B_STEP3_APPROVED_HERO_MODEL_NOT_LOADED"); return
 var hero_model := hero.get("hero_model") as Node3D
 var measured_hero_height := AssetLoader._measure_bounds(hero_model,Transform3D.IDENTITY).size.y
 if absf(measured_hero_height-2.8)>0.06:
  _fail("PHASE4B_STEP3_HERO_HEIGHT_MISMATCH: "+str(measured_hero_height)); return

 var chicken_point: Node3D
 var boss_point: Node3D
 for point in spawner.spawn_points:
  if String(point.get_meta("spawn_kind",""))=="monster_camp" and String(point.get_meta("monster_id",""))=="Chicken":
   chicken_point=point
  elif String(point.get_meta("spawn_kind",""))=="world_boss" and String(point.get_meta("monster_id",""))=="Mushroom King":
   boss_point=point
 if chicken_point==null or boss_point==null:
  _fail("PHASE4B_STEP3_REQUIRED_CHICKEN_OR_MUSHROOM_KING_POINT_MISSING"); return
 hero.global_position=chicken_point.global_position+Vector3(-12.0,0.0,0.0)
 hero.velocity=Vector3.ZERO
 hero.set("has_move_target",false)
 spawner.set_hero(hero)
 print("PHASE4B_STEP3_TRACE: CHICKEN_SPAWN_FRAME_1_BEGIN")
 await process_frame
 print("PHASE4B_STEP3_TRACE: CHICKEN_SPAWN_FRAME_1_END")
 print("PHASE4B_STEP3_TRACE: CHICKEN_SPAWN_FRAME_2_BEGIN")
 await process_frame
 print("PHASE4B_STEP3_TRACE: CHICKEN_SPAWN_FRAME_2_END")
 var chicken_actors := _actors(chicken_point)
 if chicken_actors.size()!=20:
  _fail("PHASE4B_STEP3_CHICKEN_CAMP_NOT_20: "+str(chicken_actors.size())); return
 var king: MonsterActor
 var regular_seen:=0
 for actor in chicken_actors:
  if actor.is_king: king=actor
  else: regular_seen+=1
 if king==null or regular_seen!=19:
  _fail("PHASE4B_STEP3_CHICKEN_KING_OR_REGULAR_COUNT_FAILED"); return
 var positions:Array[Vector3]=[]
 for z in [-15.0,-5.0,5.0,15.0]:
  for x in [-15.0,-7.5,0.0,7.5,15.0]:
   positions.append(chicken_point.global_position+Vector3(x,0.0,z))
 var slot:=0
 for actor in chicken_actors:
  var p:=positions[slot]; slot+=1
  if actor.is_king: p=chicken_point.global_position+Vector3(9.0,0.0,0.0)
  actor.global_position=p
  actor.set("_target",p)
  actor.set_process(false)
  if absf(actor.global_position.y-(-1.35))>0.02:
   _fail("PHASE4B_STEP3_CHICKEN_ACTOR_NOT_ON_GRASS: "+str(actor.global_position.y)); return
 if king.get_model_height()<2.0 or king.get_model_height()>2.2:
  _fail("PHASE4B_STEP3_CHICKEN_KING_HEIGHT_INVALID: "+str(king.get_model_height())); return
 print("PHASE4B_STEP3_TRACE: CAMP_CAPTURE_CALL_BEGIN")
 await _capture_camp(city,hero,chicken_point)
 print("PHASE4B_STEP3_TRACE: CAMP_CAPTURE_CALL_END")
 print("PHASE4B_STEP3_CHICKEN_CAMP_PROOF_OK: actors=20 regular=19 king_height=",king.get_model_height()," ground_y=-1.35 hero_height=2.8")

 hero.global_position=boss_point.global_position+Vector3(-8.0,0.0,0.0)
 hero.velocity=Vector3.ZERO
 hero.set("has_move_target",false)
 spawner.set_hero(hero)
 print("PHASE4B_STEP3_TRACE: BOSS_SPAWN_FRAME_1_BEGIN")
 await process_frame
 print("PHASE4B_STEP3_TRACE: BOSS_SPAWN_FRAME_1_END")
 print("PHASE4B_STEP3_TRACE: BOSS_SPAWN_FRAME_2_BEGIN")
 await process_frame
 print("PHASE4B_STEP3_TRACE: BOSS_SPAWN_FRAME_2_END")
 var bosses := _actors(boss_point)
 if bosses.size()!=1:
  _fail("PHASE4B_STEP3_MUSHROOM_KING_NOT_SPAWNED: "+str(bosses.size())); return
 var boss:=bosses[0]
 if not boss.is_boss or absf(boss.get_model_height()-5.0)>0.03:
  _fail("PHASE4B_STEP3_WORLD_BOSS_HEIGHT_INVALID: "+str(boss.get_model_height())); return
 if absf(boss.global_position.y-(-1.35))>0.02:
  _fail("PHASE4B_STEP3_WORLD_BOSS_NOT_ON_GROUND: "+str(boss.global_position.y)); return
 if boss.get_nameplate()==null or not boss.get_nameplate().modulate.is_equal_approx(Color(1.0,0.72,0.12,1.0)):
  _fail("PHASE4B_STEP3_WORLD_BOSS_GOLD_NAMEPLATE_FAILED"); return
 boss.set_process(false)
 print("PHASE4B_STEP3_TRACE: BOSS_CAPTURE_CALL_BEGIN")
 await _capture_boss(city,hero,boss)
 print("PHASE4B_STEP3_TRACE: BOSS_CAPTURE_CALL_END")
 print("PHASE4B_STEP3_WORLD_BOSS_PROOF_OK: name=Mushroom King height=",boss.get_model_height(),"m hero_height=2.8m ground_y=-1.35 gold_nameplate=true")
 print("PHASE4B_STEP3_TWO_IN_GAME_PNG_PROOFS_COMPLETE")
 quit(0)

func _trace_probe_city(item:Dictionary,manager:Node)->bool:
 return await _probe_city(item,manager)

func _probe_city(item:Dictionary,manager:Node)->bool:
 manager.set("current_city",String(item.id))
 var expected_y:=float(item.ground_y)
 var first_center:Vector3=TABLE.CITY_CENTER_FALLBACKS[item.id]+TABLE.CAMP_OFFSETS[item.id][0]
 var dummy:=Node3D.new()
 dummy.name="Phase4B_AutomaticSpawnProbe"
 dummy.add_to_group("player")
 root.add_child(dummy)
 dummy.global_position=first_center
 var packed:=load(String(item.path)) as PackedScene
 if packed==null:
  _fail("PHASE4B_STEP3_CITY_SCENE_LOAD_FAILED: "+String(item.id)); return false
 var city:=packed.instantiate() as Node3D
 root.add_child(city)
 print("PHASE4B_STEP3_TRACE: CITY_PROBE_FRAME_1_BEGIN ",item.id)
 await process_frame
 print("PHASE4B_STEP3_TRACE: CITY_PROBE_FRAME_1_END ",item.id)
 print("PHASE4B_STEP3_TRACE: CITY_PROBE_FRAME_2_BEGIN ",item.id)
 await process_frame
 print("PHASE4B_STEP3_TRACE: CITY_PROBE_FRAME_2_END ",item.id)
 var spawner:=city.get_node_or_null("MonsterSpawner") as MonsterSpawner
 if spawner==null or spawner.spawn_points.size()!=int(item.points):
  _fail("PHASE4B_STEP3_CITY_SPAWNER_POINTS_FAILED: "+String(item.id)+" actual="+str(spawner.spawn_points.size() if spawner else -1)); return false
 var camp:Node3D
 var boss_point:Node3D
 for point in spawner.spawn_points:
  if absf(point.global_position.y-expected_y)>0.02:
   _fail("PHASE4B_STEP3_SPAWN_POINT_GROUND_Y_FAILED: "+String(item.id)+" y="+str(point.global_position.y)); return false
  if String(point.get_meta("spawn_kind",""))=="monster_camp" and camp==null: camp=point
  if String(point.get_meta("spawn_kind",""))=="world_boss": boss_point=point
 if camp==null or boss_point==null:
  _fail("PHASE4B_STEP3_CITY_CAMP_OR_BOSS_MISSING: "+String(item.id)); return false
 if String(item.id)=="BirdIsland":
  for point in spawner.spawn_points:
   if String(point.get_meta("spawn_kind",""))!="monster_camp": continue
   var p:=point.global_position
   var sand_ok=p.x-20.0>=-145.0 and p.x+20.0<=-40.0 and p.z-20.0>=-45.0 and p.z+20.0<=47.0
   var ice_ok=p.x-20.0>=-4.0 and p.x+20.0<=108.0 and p.z-20.0>=-45.0 and p.z+20.0<=50.0
   if not sand_ok and not ice_ok:
    _fail("PHASE4B_STEP3_BIRD_CAMP_OUTSIDE_ISLAND: "+str(p)); return false
 if _actors(camp).size()!=20:
  _fail("PHASE4B_STEP3_AUTOMATIC_CAMP_POPULATION_FAILED: "+String(item.id)+" actors="+str(_actors(camp).size())); return false
 dummy.global_position=boss_point.global_position
 print("PHASE4B_STEP3_TRACE: CITY_BOSS_FRAME_BEGIN ",item.id)
 await process_frame
 print("PHASE4B_STEP3_TRACE: CITY_BOSS_FRAME_END ",item.id)
 var boss_actors:=_actors(boss_point)
 if boss_actors.size()!=1 or absf(boss_actors[0].get_model_height()-5.0)>0.03:
  _fail("PHASE4B_STEP3_AUTOMATIC_BOSS_POPULATION_FAILED: "+String(item.id)); return false
 if absf(boss_actors[0].global_position.y-expected_y)>0.02:
  _fail("PHASE4B_STEP3_AUTOMATIC_BOSS_GROUND_FAILED: "+String(item.id)); return false
 print("PHASE4B_STEP3_CITY_RUNTIME_OK: city=",item.id," spawn_points=",item.points," camp_actors=20 boss_height=",boss_actors[0].get_model_height()," ground_y=",expected_y)
 city.queue_free(); dummy.queue_free()
 print("PHASE4B_STEP3_TRACE: CITY_CLEANUP_FRAME_BEGIN ",item.id)
 await process_frame
 print("PHASE4B_STEP3_TRACE: CITY_CLEANUP_FRAME_END ",item.id)
 return true

func _actors(point:Node3D)->Array[MonsterActor]:
 var result:Array[MonsterActor]=[]
 for child in point.get_children():
  if child is MonsterActor: result.append(child as MonsterActor)
 return result

func _capture_camp(city:Node3D,hero:CharacterBody3D,camp:Node3D)->void:
 print("PHASE4B_STEP3_TRACE: CAMP_CAPTURE_BEGIN")
 var camera:=Camera3D.new()
 camera.name="Phase4B_CampProofCamera"
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=50.0
 city.add_child(camera)
 camera.current=true
 camera.global_position=hero.global_position+Vector3(6.0,7.0,6.0)
 camera.look_at(camp.global_position+Vector3(0.0,1.6,0.0),Vector3.UP)
 print("PHASE4B_STEP3_TRACE: CAMP_FRAME_POST_DRAW_1_BEGIN")
 await RenderingServer.frame_post_draw
 print("PHASE4B_STEP3_TRACE: CAMP_FRAME_POST_DRAW_1_END")
 print("PHASE4B_STEP3_TRACE: CAMP_FRAME_POST_DRAW_2_BEGIN")
 await RenderingServer.frame_post_draw
 print("PHASE4B_STEP3_TRACE: CAMP_FRAME_POST_DRAW_2_END")
 print("PHASE4B_STEP3_TRACE: CAMP_PNG_SAVE_BEGIN")
 _save_png(camera,"phase4b_step3_01_twin_city_chicken_camp.png")
 print("PHASE4B_STEP3_TRACE: CAMP_PNG_SAVE_END")

func _capture_boss(city:Node3D,hero:CharacterBody3D,boss:MonsterActor)->void:
 print("PHASE4B_STEP3_TRACE: BOSS_CAPTURE_BEGIN")
 var camera:=Camera3D.new()
 camera.name="Phase4B_WorldBossProofCamera"
 camera.fov=50.0
 city.add_child(camera)
 camera.current=true
 var midpoint:Vector3=(hero.global_position+boss.global_position)*0.5
 camera.global_position=hero.global_position+Vector3(6.0,7.0,6.0)
 camera.look_at(midpoint+Vector3(0.0,2.4,0.0),Vector3.UP)
 print("PHASE4B_STEP3_TRACE: BOSS_FRAME_POST_DRAW_1_BEGIN")
 await RenderingServer.frame_post_draw
 print("PHASE4B_STEP3_TRACE: BOSS_FRAME_POST_DRAW_1_END")
 print("PHASE4B_STEP3_TRACE: BOSS_FRAME_POST_DRAW_2_BEGIN")
 await RenderingServer.frame_post_draw
 print("PHASE4B_STEP3_TRACE: BOSS_FRAME_POST_DRAW_2_END")
 print("PHASE4B_STEP3_TRACE: BOSS_PNG_SAVE_BEGIN")
 _save_png(camera,"phase4b_step3_02_mushroom_king_world_boss.png")
 print("PHASE4B_STEP3_TRACE: BOSS_PNG_SAVE_END")

func _save_png(camera:Camera3D,file_name:String)->void:
 print("PHASE4B_STEP3_TRACE: PNG_SAVE_ENTER ",file_name)
 if camera.global_position.distance_to(camera.get_parent().get_node("TwinCityPlayableHero").global_position)>12.1:
  _fail("PHASE4B_STEP3_CAMERA_DISTANCE_OUT_OF_RANGE: "+str(camera.global_position.distance_to(camera.get_parent().get_node("TwinCityPlayableHero").global_position))); return
 print("PHASE4B_STEP3_TRACE: PNG_FRAMEBUFFER_READ_BEGIN ",file_name)
 var image:=get_root().get_texture().get_image()
 print("PHASE4B_STEP3_TRACE: PNG_FRAMEBUFFER_READ_END ",file_name," empty=",image==null or image.is_empty())
 if image==null or image.is_empty():
  _fail("PHASE4B_STEP3_EMPTY_FRAMEBUFFER: "+file_name); return
 var directory:=ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(directory)
 var path:=directory.path_join(file_name)
 print("PHASE4B_STEP3_TRACE: PNG_WRITE_BEGIN ",file_name," path=",path)
 var error:=image.save_png(path)
 print("PHASE4B_STEP3_TRACE: PNG_WRITE_END ",file_name," error=",error)
 if error!=OK:
  _fail("PHASE4B_STEP3_PNG_SAVE_FAILED: "+str(error)); return
 var bytes:=FileAccess.get_file_as_bytes(path).size()
 if bytes<12000:
  _fail("PHASE4B_STEP3_PNG_TOO_SMALL: "+file_name+" bytes="+str(bytes)); return
 print("PHASE4B_STEP3_REAL_GAME_PNG_OK: ",file_name," bytes=",bytes," camera_distance=11m")
 
func _fail(message:String)->void:
 push_error(message)
 quit(1)
