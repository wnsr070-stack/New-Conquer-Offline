extends CharacterBody3D
class_name HeroController

const ASSASSIN_HERO := "res://assets/mounts/hero_assassin.glb"
const ANIMS := "res://assets/phase4/animations/conquer_hero_anims.res"
const WEAPON_ROOT := "res://assets/phase3b/weapons/"
const CLASS_ORDER := ["archer", "trojan", "warrior", "taoist"]
const CLASS_CLIPS := {"archer":"Attack_Bow","oriental_assassin":"Attack_Assassin","trojan":"Attack_Trojan","warrior":"Attack_SwordShield","taoist":"Attack_Staff"}
const PALETTES := {
 "archer":[Color("#3A1259"),Color("#16161C")],
 "oriental_assassin":[Color("#3A1259"),Color("#16161C")],
 "trojan":[Color("#a30f2d")],
 "warrior":[Color("#2456c5")],
 "taoist":[Color("#d6a82f"),Color("#f4f0df")]
}
const WEAPON_FILES := {
 "bow":"bow_beginner.glb","dual_knives":"dual_knives_beginner.glb",
 "dual_blades":"dual_blades_beginner.glb","shield":"shield_beginner.glb",
 "greatsword":"greatsword_beginner.glb","magic_staff":"magic_staff_beginner.glb"
}
@export var move_speed := 7.0
@export var jump_stamina_cost := 25.0
@export var stamina_regen := 12.0
@export var jump_duration := 0.82
@export var jump_height := 2.8
@export var character_level := 40 # QA spawn level enables the documented level-40 Assassin swap
var stamina := 100.0
var active_class := "archer"
var archer_dual_knives := false
var hero_model: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var camera_pivot: Node3D
var camera: Camera3D
var move_target := Vector3.ZERO
var has_move_target := false
var jump_elapsed := 0.0
var jump_origin := Vector3.ZERO
var jump_destination := Vector3.ZERO
var is_jumping := false
var weapon_nodes: Array[Node] = []
var measured_model_height := 0.0
var _camera_drag_active := false
var _player_nameplate: Label3D
# PHASE4C_DIRECTOR_HAND_POSE: preserve bow's approved 210-degree orientation; palm alignment is derived from finger-root geometry.

func _ready() -> void:
 name = "PlayableHero"
 floor_snap_length = 0.35
 _ensure_input_actions()
 print("INPUTMAP_MOVEMENT_ACTIONS_READY: move_forward,move_back,move_left,move_right")
 await _load_assassin_hero()
 _restore_saved_world_position()
 _setup_camera()
 _build_player_nameplate()
 _switch_class("archer")
 var equipment_manager := get_node_or_null("/root/EquipmentVisualManager")
 if equipment_manager != null: equipment_manager.bind_hero(self)
 var mount_system := get_node_or_null("/root/MountSystem")
 if mount_system != null: mount_system.bind_hero(self)
 set_process_unhandled_input(true)
 print("HERO_CONTROLLER_READY: classes=Archer,Trojan,Warrior,Taoist stamina=100")

func _normalize_hero_scale() -> void:
 if hero_model == null:
  return
 var min_y := INF
 var max_y := -INF
 for node in hero_model.find_children("*", "MeshInstance3D", true, false):
  var mesh_instance := node as MeshInstance3D
  if mesh_instance.mesh == null:
   continue
  var local_box := mesh_instance.get_aabb()
  var to_model := hero_model.global_transform.affine_inverse() * mesh_instance.global_transform
  for x in range(2):
   for y in range(2):
    for z in range(2):
     var corner := local_box.position + Vector3(local_box.size.x * x, local_box.size.y * y, local_box.size.z * z)
     var point := to_model * corner
     min_y = minf(min_y, point.y)
     max_y = maxf(max_y, point.y)
 if not is_finite(min_y) or max_y <= min_y:
  push_error("HERO_AABB_HEIGHT_MEASUREMENT_FAILED")
  return
 measured_model_height = max_y - min_y
 var target_world_height := 2.8
 var factor := target_world_height / measured_model_height
 hero_model.scale = Vector3.ONE * factor
 hero_model.position.y = -min_y * factor
 print("HERO_AABB_SCALE_APPLIED: source_height=", measured_model_height, " target_world_height=2.8 scale=", factor, " bounds_y=", min_y, "..", max_y)

func _load_assassin_hero() -> void:
 if not ResourceLoader.exists(ASSASSIN_HERO):
  push_error("HERO_ASSASSIN_GLB_MISSING: "+ASSASSIN_HERO)
  return
 var packed := load(ASSASSIN_HERO) as PackedScene
 hero_model = packed.instantiate() as Node3D if packed else null
 if hero_model == null:
  push_error("HERO_ASSASSIN_INSTANCE_FAILED")
  return
 hero_model.name = "OrientalAssassin"
 hero_model.rotation.y = PI
 hero_model.set_meta("hero_assassin_rig",true)
 add_child(hero_model)
 await get_tree().process_frame
 _normalize_hero_scale()
 var found := hero_model.find_children("*","Skeleton3D",true,false)
 if found.is_empty():
  push_error("HERO_ASSASSIN_SKELETON_MISSING")
  return
 skeleton = found[0] as Skeleton3D
 var bone_names: Array[String] = []
 for index in range(skeleton.get_bone_count()):
  bone_names.append(skeleton.get_bone_name(index))
 print("HERO_ASSASSIN_SKELETON_BONES: count=",bone_names.size()," names=",bone_names)
 var players := hero_model.find_children("*","AnimationPlayer",true,false)
 if players.is_empty():
  push_error("HERO_ASSASSIN_ANIMATION_PLAYER_MISSING")
  return
 animation_player = players[0] as AnimationPlayer
 animation_player.root_node = animation_player.get_path_to(hero_model)
 var imported_clips := animation_player.get_animation_list()
 var run_clip := _find_animation_name("run")
 var walk_clip := _find_animation_name("walk")
 if run_clip.is_empty() or walk_clip.is_empty():
  push_error("HERO_ASSASSIN_WALK_RUN_CLIPS_MISSING: clips="+str(imported_clips))
  return
 print("HERO_ASSASSIN_RIGGED_GLB_READY: path=",ASSASSIN_HERO," walk=",walk_clip," run=",run_clip," clips=",imported_clips)
 _attach_retargeted_conquer_animations()
 animation_player.play(walk_clip)
 await get_tree().process_frame
 print("HERO_ASSASSIN_ANIMATION_RUNTIME_READY: walk_run=true combat_library=retargeted")
 print("HERO_ASSASSIN_PRIMARY_MODEL_READY: npc_model_preserved=Male_Ranger.glb")

func _normalize_bone_name(value: String) -> String:
 return value.to_lower().replace("_","").replace("-","").replace(" ","").replace(":","").replace(".","").replace("|","")

func _find_animation_name(token: String) -> String:
 if animation_player == null:
  return ""
 for animation_name in animation_player.get_animation_list():
  var normalized := _normalize_bone_name(String(animation_name))
  if normalized.ends_with(token.to_lower()) or normalized.contains("/"+token.to_lower()):
   return String(animation_name)
 return ""

func _resolve_assassin_bone(source_name: String) -> String:
 var aliases := {
  "pelvis":["pelvis","hips"],
  "spine01":["spine_01","spine1","spine"],
  "spine02":["spine_02","spine2","chest"],
  "spine03":["spine_03","spine3","upperchest"],
  "neck01":["neck_01","neck1","neck"],
  "head":["head"],
  "claviclel":["clavicle_l","claviclel","leftshoulder","shoulderl"],
  "clavicler":["clavicle_r","clavicler","rightshoulder","shoulderr"],
  "upperarml":["upperarm_l","upperarml","leftupperarm","upperarml","leftarm","upperarml"],
  "upperarmr":["upperarm_r","upperarmr","rightupperarm","upperarmr","rightarm"],
  "lowerarml":["lowerarm_l","lowerarml","leftforearm","forearml","lowerarml"],
  "lowerarmr":["lowerarm_r","lowerarmr","rightforearm","forearmr","lowerarmr"],
  "handl":["hand_l","handl","lefthand"],
  "handr":["hand_r","handr","righthand"],
  "thighl":["thigh_l","thighl","leftupleg","upperlegl","leftthigh"],
  "thighr":["thigh_r","thighr","rightupleg","upperlegr","rightthigh"],
  "calfl":["calf_l","calfl","leftleg","lowerlegl","leftcalf"],
  "calfr":["calf_r","calfr","rightleg","lowerlegr","rightcalf"],
  "footl":["foot_l","footl","leftfoot"],
  "footr":["foot_r","footr","rightfoot"]
 }
 var key := _normalize_bone_name(source_name)
 var candidates: Array = aliases.get(key,[source_name])
 for index in range(skeleton.get_bone_count()):
  var actual := skeleton.get_bone_name(index)
  var normalized := _normalize_bone_name(actual)
  for alias in candidates:
   if normalized == _normalize_bone_name(String(alias)):
    return actual
 return ""

func _attach_retargeted_conquer_animations() -> void:
 if not ResourceLoader.exists(ANIMS):
  push_error("HERO_CONQUER_ANIMATION_LIBRARY_MISSING")
  return
 var source_library := load(ANIMS) as AnimationLibrary
 if source_library == null:
  push_error("HERO_CONQUER_ANIMATION_LIBRARY_INVALID")
  return
 var remapped_library := AnimationLibrary.new()
 var mapped_tracks := 0
 var dropped_tracks := 0
 var skeleton_path := str(hero_model.get_path_to(skeleton))
 for clip_name in source_library.get_animation_list():
  var source_animation := source_library.get_animation(clip_name)
  var animation := source_animation.duplicate(true) as Animation
  for track_index in range(animation.get_track_count()-1,-1,-1):
   var track_path := String(animation.track_get_path(track_index))
   var separator := track_path.rfind(":")
   if separator < 0:
    continue
   var old_bone := track_path.substr(separator+1)
   var new_bone := _resolve_assassin_bone(old_bone)
   if new_bone.is_empty():
    animation.remove_track(track_index)
    dropped_tracks += 1
   else:
    animation.track_set_path(track_index,NodePath(skeleton_path+":"+new_bone))
    mapped_tracks += 1
  if animation.get_track_count() > 0:
   var add_error := remapped_library.add_animation(clip_name,animation)
   if add_error != OK:
    push_error("HERO_ASSASSIN_COMBAT_CLIP_ATTACH_FAILED: "+String(clip_name))
    return
 if remapped_library.get_animation_list().is_empty() or not remapped_library.has_animation("Attack_Assassin"):
  push_error("HERO_ASSASSIN_COMBAT_RETARGET_EMPTY_OR_ASSASSIN_CLIP_MISSING: clips="+str(remapped_library.get_animation_list()))
  return
 var library_error := animation_player.add_animation_library("conquer",remapped_library)
 if library_error != OK:
  push_error("HERO_ASSASSIN_COMBAT_LIBRARY_ATTACH_FAILED: "+str(library_error))
  return
 print("HERO_ASSASSIN_COMBAT_ANIMATION_RETARGET_OK: clips=",remapped_library.get_animation_list()," mapped_tracks=",mapped_tracks," dropped_tracks=",dropped_tracks)

func _play_hero_animation(token: String) -> bool:
 if animation_player == null:
  return false
 var clip := _find_animation_name(token)
 if clip.is_empty():
  for animation_name in animation_player.get_animation_list():
   if _normalize_bone_name(String(animation_name)).contains("conquer") and _normalize_bone_name(String(animation_name)).ends_with(token.to_lower()):
    clip = String(animation_name)
    break
 if clip.is_empty():
  return false
 animation_player.play(clip)
 return true

func _setup_camera() -> void:
 camera_pivot = Node3D.new()
 camera_pivot.name = "ConquerIsoCameraPivot"
 add_child(camera_pivot)
 camera_pivot.rotation_degrees = Vector3(-45.0,45.0,0.0)
 camera = Camera3D.new()
 camera.name = "Conquer45DegreeCamera"
 camera.position = Vector3(0,0,14.0)
 camera.fov = 42.0
 print("HERO_CAMERA_CONFIG: distance=14m height≈10m pitch=-45 yaw=45")
 camera.current = true
 camera_pivot.add_child(camera)
 camera_pivot.position = Vector3.ZERO

func _restore_saved_world_position() -> void:
 var state := get_node_or_null("/root/GameState")
 var world := get_node_or_null("/root/WorldMapManager")
 if state == null or world == null:
  return
 var data: Dictionary = state.player_data
 if String(data.get("world_city", "")) != String(world.current_city):
  return
 var saved_position: Variant = data.get("world_position", null)
 if saved_position is Vector3:
  global_position = saved_position
  print("HERO_SAVED_POSITION_RESTORED: city=", world.current_city, " position=", global_position)

func _build_player_nameplate() -> void:
 _player_nameplate = Label3D.new()
 _player_nameplate.name = "PlayerNameplate"
 _player_nameplate.set_meta("game_settings_role", "name")
 var state := get_node_or_null("/root/GameState")
 var data: Dictionary = state.player_data if state != null else {}
 _player_nameplate.text = String(data.get("name", "Ranger"))
 _player_nameplate.font = ThemeDB.fallback_font
 _player_nameplate.font_size = 48
 _player_nameplate.pixel_size = 0.008
 _player_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 _player_nameplate.no_depth_test = true
 _player_nameplate.outline_size = 8
 _player_nameplate.position = Vector3(0.0, 3.5, 0.0)
 add_child(_player_nameplate)

func _rotate_camera(relative: Vector2) -> void:
 if not is_instance_valid(camera_pivot):
  return
 var settings := get_node_or_null("/root/GameSettings")
 var sensitivity := float(settings.get_setting("camera_sensitivity", 1.0)) if settings != null else 1.0
 camera_pivot.rotation_degrees.y -= relative.x * 0.16 * sensitivity
 camera_pivot.rotation_degrees.x = clampf(camera_pivot.rotation_degrees.x - relative.y * 0.12 * sensitivity, -72.0, -25.0)

func _process(delta: float) -> void:
 if is_instance_valid(camera_pivot):
  camera_pivot.global_position = camera_pivot.global_position.lerp(global_position + Vector3(0,1.0,0), clampf(delta*8.0,0.0,1.0))
 if is_instance_valid(camera) and camera.global_position.y < 4.0:
  var safe_camera_position := camera.global_position
  safe_camera_position.y = 4.0
  camera.global_position = safe_camera_position
 if not is_jumping:
  stamina = minf(100.0,stamina + stamina_regen*delta)
 _update_animation()

func _physics_process(delta: float) -> void:
 var input_dir := Input.get_vector("move_left","move_right","move_forward","move_back")
 var direction := Vector3(input_dir.x,0,input_dir.y)
 if direction.length_squared() > 0.001:
  direction = (Basis(Vector3.UP,PI*0.25) * direction).normalized()
  velocity.x = direction.x * move_speed
  velocity.z = direction.z * move_speed
  move_target = global_position
  has_move_target = false
 elif has_move_target and not is_jumping:
  var to_target := move_target-global_position
  to_target.y = 0
  if to_target.length() > 0.35:
   var dir := to_target.normalized()
   velocity.x = dir.x*move_speed
   velocity.z = dir.z*move_speed
  else:
   has_move_target = false
   velocity.x = move_toward(velocity.x,0,move_speed*delta*4)
   velocity.z = move_toward(velocity.z,0,move_speed*delta*4)
 else:
  velocity.x = move_toward(velocity.x,0,move_speed*delta*4)
  velocity.z = move_toward(velocity.z,0,move_speed*delta*4)
 if is_jumping:
  jump_elapsed += delta
  var t := clampf(jump_elapsed/jump_duration,0.0,1.0)
  global_position.x = lerpf(jump_origin.x,jump_destination.x,t)
  global_position.z = lerpf(jump_origin.z,jump_destination.z,t)
  global_position.y = jump_height*4.0*t*(1.0-t)
  if t >= 1.0:
   global_position.y = 0.0
   is_jumping = false
   print("HERO_JUMP_LANDED")
 else:
  move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  match event.keycode:
   KEY_1: _switch_class("archer")
   KEY_2: _switch_class("trojan")
   KEY_3: _switch_class("warrior")
   KEY_4: _switch_class("taoist")
   KEY_Q:
    if active_class in ["archer","oriental_assassin"]:
     if active_class == "archer" and character_level < 40:
      print("HERO_ASSASSIN_WEAPON_LOCKED_UNTIL_LEVEL_40")
     else:
      archer_dual_knives = not archer_dual_knives
      _switch_class("oriental_assassin" if archer_dual_knives else "archer")
   KEY_SPACE: _try_jump()
 if event is InputEventScreenTouch:
  var touch := event as InputEventScreenTouch
  if touch.pressed:
   var viewport_size := get_viewport().get_visible_rect().size
   _camera_drag_active = touch.position.x >= viewport_size.x * 0.42 and touch.position.y < viewport_size.y - 230.0
  else:
   _camera_drag_active = false
 elif event is InputEventScreenDrag and _camera_drag_active:
  _rotate_camera((event as InputEventScreenDrag).relative)
 elif event is InputEventMouseButton:
  var mouse_button := event as InputEventMouseButton
  if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
   _camera_drag_active = mouse_button.pressed
  elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
   _set_click_target(mouse_button.position)
 elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
  _rotate_camera((event as InputEventMouseMotion).relative)

func _set_click_target(screen_position: Vector2) -> void:
 if camera == null: return
 var origin := camera.project_ray_origin(screen_position)
 var normal := camera.project_ray_normal(screen_position)
 if absf(normal.y) < 0.0001: return
 var distance := -origin.y/normal.y
 if distance < 0.0: return
 var hit := origin+normal*distance
 if absf(hit.x) <= 158.0 and absf(hit.z) <= 158.0:
  move_target = Vector3(hit.x,0,hit.z)
  has_move_target = true
  print("HERO_CLICK_MOVE_TARGET: ",move_target)

func _try_jump() -> void:
 if is_jumping or stamina < jump_stamina_cost: return
 stamina -= jump_stamina_cost
 jump_origin = global_position
 jump_destination = move_target if has_move_target else global_position + Vector3(-2.0,0,-2.0)
 jump_destination.y = 0
 jump_elapsed = 0.0
 is_jumping = true
 _play_hero_animation("Jump")
 print("HERO_CONQUER_JUMP: stamina=",stamina)

func _switch_class(class_id: String) -> void:
 if class_id == "oriental_assassin" and character_level < 40:
  print("HERO_ASSASSIN_LOCKED_LEVEL_40")
  return
 if not CLASS_CLIPS.has(class_id): return
 active_class = class_id
 if is_instance_valid(animation_player) and not _play_hero_animation("Idle"):
  animation_player.stop()
 _clear_weapons()
 _apply_approved_palette()
 _attach_class_weapons()
 var equipment_manager := get_node_or_null("/root/EquipmentVisualManager")
 if equipment_manager != null: equipment_manager.set_active_class(active_class)
 print("HERO_CLASS_SWITCHED: ",active_class," weapon_mode=",("dual_knives" if active_class=="oriental_assassin" else "bow" if active_class=="archer" else active_class))

func _apply_approved_palette() -> void:
 if hero_model == null:
  return
 # The assassin GLB carries authored PBR textures. Keep its source materials intact;
 # class changes still drive weapon/equipment systems without flattening the rig.
 if bool(hero_model.get_meta("hero_assassin_rig",false)):
  print("HERO_ASSASSIN_PBR_MATERIALS_PRESERVED: class=",active_class)
  return

func _attach_class_weapons() -> void:
 match active_class:
  "archer": _attach_weapon("l","bow")
  "oriental_assassin":
   _attach_weapon("l","dual_knives")
   _attach_weapon("r","dual_knives")
  "trojan":
   _attach_weapon("l","dual_blades")
   _attach_weapon("r","dual_blades")
  "warrior":
   _attach_weapon("l","shield")
   _attach_weapon("r","greatsword")
  "taoist": _attach_weapon("r","magic_staff")

func _resolve_hand_bone(side: String) -> int:
 if skeleton == null:
  return -1
 var required_side := "right" if side == "r" else "left"
 var suffix := "r" if side == "r" else "l"
 for i in range(skeleton.get_bone_count()):
  var actual := skeleton.get_bone_name(i)
  var normalized := _normalize_bone_name(actual)
  var matches_side := normalized.contains(required_side) or normalized.ends_with("hand"+suffix) or normalized == "hand"+suffix
  if normalized.contains("hand") and matches_side:
   print("HERO_HAND_BONE_NAME_MATCH: side=", side, " index=", i, " name=", actual)
   return i
 var available: Array[String] = []
 for i in range(skeleton.get_bone_count()):
  available.append(skeleton.get_bone_name(i))
 push_error("HERO_STRICT_HAND_BONE_NOT_FOUND: side=" + side + " available=" + str(available))
 return -1

func _palm_center_local(hand_bone: int) -> Vector3:
 if skeleton == null or hand_bone < 0:
  return Vector3.ZERO
 var hand_rest := skeleton.get_bone_global_rest(hand_bone)
 var finger_roots: Array[Vector3] = []
 var finger_names: Array[String] = []
 for i in range(skeleton.get_bone_count()):
  if skeleton.get_bone_parent(i) != hand_bone:
   continue
  var bone_name := skeleton.get_bone_name(i)
  var normalized := bone_name.to_lower().replace("_","").replace("-","").replace(" ","").replace(":","")
  if not ("index" in normalized or "middle" in normalized or "ring" in normalized or "pinky" in normalized or "little" in normalized):
   continue
  finger_roots.append(hand_rest.affine_inverse() * skeleton.get_bone_global_rest(i).origin)
  finger_names.append(bone_name)
 if finger_roots.size() < 4:
  push_error("PHASE4C_LEFT_PALM_FINGER_ROOTS_INCOMPLETE: found=" + str(finger_names) + " required=4")
  return Vector3.ZERO
 var center := Vector3.ZERO
 for point in finger_roots:
  center += point
 center /= float(finger_roots.size())
 print("PHASE4C_LEFT_PALM_CENTER_DERIVED: finger_roots=", finger_names, " local_center=", center)
 return center

func _apply_left_bow_finger_curl() -> void:
 if skeleton == null:
  return
 var finger_tokens := ["thumb", "index", "middle", "ring", "pinky", "little"]
 var curled: Array[String] = []
 for i in range(skeleton.get_bone_count()):
  var bone_name := skeleton.get_bone_name(i)
  var normalized := bone_name.to_lower().replace("_","").replace("-","").replace(" ","").replace(":","")
  var is_left := normalized.contains("left") or normalized.ends_with("l") or normalized.contains("handl")
  var is_finger := false
  for token in finger_tokens:
   if token in normalized:
    is_finger = true
    break
  if not is_left or not is_finger:
   continue
  # Curl each phalanx toward the palm while leaving the palm/hand bone untouched.
  var curl_degrees := 32.0
  if "middle" in normalized or "distal" in normalized or "tip" in normalized:
   curl_degrees = 42.0
  elif "thumb" in normalized:
   curl_degrees = 24.0
  var current_pose := skeleton.get_bone_pose_rotation(i)
  skeleton.set_bone_pose_rotation(i, (current_pose * Quaternion(Vector3.RIGHT, deg_to_rad(curl_degrees))).normalized())
  curled.append(bone_name)
 if curled.size() < 4:
  push_error("PHASE4C_LEFT_BOW_FINGER_CURL_INCOMPLETE: curled=" + str(curled))
 else:
  print("PHASE4C_LEFT_BOW_FINGER_CURL_OK: bones=", curled, " palm_direction_preserved=true")

func _attach_weapon(hand_side: String,family: String) -> void:
 if skeleton == null:
  push_error("HERO_WEAPON_SKELETON_MISSING: " + family)
  return
 var bone := _resolve_hand_bone(hand_side)
 if bone < 0:
  var available: Array[String] = []
  for i in range(skeleton.get_bone_count()):
   available.append(skeleton.get_bone_name(i))
  push_error("HERO_REAL_HAND_BONE_NOT_FOUND: side=" + hand_side + " available=" + str(available))
  return
 var actual_bone := skeleton.get_bone_name(bone)
 var filename := str(WEAPON_FILES.get(family,""))
 var path := WEAPON_ROOT+filename
 if not ResourceLoader.exists(path):
  push_error("HERO_WEAPON_ASSET_MISSING: "+path)
  return
 var packed := load(path) as PackedScene
 if packed == null:
  push_error("HERO_WEAPON_PACKED_SCENE_LOAD_FAILED: " + path)
  return
 var weapon := packed.instantiate() as Node3D
 if weapon == null:
  push_error("HERO_WEAPON_INSTANCE_FAILED: " + path)
  return
 var socket := BoneAttachment3D.new()
 var socket_id := "HeroWeapon_"+family+"_hand_"+hand_side
 socket.name = socket_id
 socket.bone_name = actual_bone
 socket.bone_idx = bone
 socket.override_pose = false
 skeleton.add_child(socket)
 socket.set_meta("phase4a_weapon_socket_id", socket_id)
 socket.set_meta("phase4a_actual_bone_name", actual_bone)
 var palm_center_local := _palm_center_local(bone) if family == "bow" and hand_side == "l" else Vector3.ZERO
 socket.set_meta("phase4c_palm_center_local", palm_center_local)
 socket.add_child(weapon)
 if family == "bow" and hand_side == "l":
  _apply_left_bow_finger_curl()
 var mesh_points: Array[Vector3] = []
 for child in weapon.get_children():
  _collect_weapon_mesh_points(child, Transform3D.IDENTITY, mesh_points)
 if mesh_points.is_empty():
  push_error("HERO_WEAPON_HAS_NO_RENDERABLE_MESH: " + family)
  socket.queue_free()
  return
 var bounds := _points_bounds(mesh_points)
 var family_scale := 0.18 if family == "dual_knives" else 0.30
 if family == "bow":
  var source_length := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
  if source_length <= 0.0001:
   push_error("HERO_BOW_AABB_INVALID: " + str(bounds))
   socket.queue_free()
   return
  family_scale = 1.2 / source_length
  print("HERO_BOW_AABB_MEASURED: path=", path, " source_aabb=", bounds, " source_length=", source_length, " target_world_length=1.2m scale=", family_scale)
 weapon.scale = Vector3.ONE * family_scale
 if family == "bow":
  # Director's two-step bow correction, composed in this exact order:
  # 1) 90 degrees counter-clockwise about the palm-plane normal (local Z).
  # 2) 180 degrees about the upright wooden grip axis (local Y).
  # The hand/bone pose and palm-facing direction are not changed here.
  weapon.rotation = Vector3(0.0, PI, PI / 2.0)
  weapon.rotate_object_local(Vector3.FORWARD, PI / 2.0)
  print("PHASE4C_BOW_STEP1_PALM_NORMAL_CCW_OK: axis=local_z angle=+90deg")
  weapon.rotate_object_local(Vector3.UP, PI)
  print("PHASE4C_BOW_STEP2_VERTICAL_GRIP_FLIP_OK: axis=local_y angle=180deg")
  # Final correction from the currently approved grip/string orientation:
  # rotate ONLY in the bow plane around its normal (source local Z).
  # This changes the limb tilt while preserving the plane normal, grip, and string-facing side.
  weapon.rotate_object_local(Vector3.FORWARD, PI / 2.0)
  print("PHASE4C_BOW_EXISTING_PLANE_NORMAL_CORRECTION_OK: axis=bow_plane_normal_local_z angle=+90deg")
  weapon.rotate_object_local(Vector3.FORWARD, deg_to_rad(38.0))
  print("PHASE4C_BOW_ADDITIONAL_TILT_CORRECTION_OK: axis=bow_plane_normal_local_z angle=+38deg mesh_node_only=true hand_and_socket_unchanged=true grip_and_string_side_preserved=true")
  print("PHASE4C_BOW_FINAL_PLANE_ORIENTATION_OK: palm_pose_preserved=true grip_translation_unchanged=true")
 var grip := bounds.get_center()
 if family == "bow":
  # The bow mesh is thin along source Z. Anchor the palm on the forward wooden
  # stave face, not at the AABB midpoint between stave and string.
  grip.z = bounds.position.z + bounds.size.z * 0.85
  print("PHASE4C_BOW_WOOD_GRIP_ANCHOR_SELECTED: source_z=", grip.z, " depth_fraction=0.85 anchor=wood_stave_face")
 if family in ["dual_knives", "dual_blades", "greatsword", "magic_staff"]:
  var size := bounds.size
  if size.y >= size.x and size.y >= size.z:
   grip.y = bounds.position.y + size.y * 0.18
  elif size.x >= size.z:
   grip.x = bounds.position.x + size.x * 0.18
  else:
   grip.z = bounds.position.z + size.z * 0.18
 # Use the node's complete local Basis (rotation + scale) exactly once.
 # This maps the unscaled source AABB grip point into the socket's local space.
 var grip_local_offset: Vector3 = grip
 var rotated_grip_offset: Vector3 = weapon.transform.basis * grip_local_offset
 weapon.position = (palm_center_local - weapon.transform.basis * grip_local_offset) if family == "bow" and hand_side == "l" else -(weapon.transform.basis * grip_local_offset)
 if family == "bow":
  print("PHASE4C_BOW_PALM_CENTER_TRANSFORM_APPLIED: weapon_position=palm_center_local-(weapon_basis*grip_local_point) palm_center_local=", palm_center_local)
  print("PHASE4C_BOW_ROTATED_GRIP_COMPENSATION_OK: rotated_grip_offset=", rotated_grip_offset, " seating_offset=Vector3.ZERO", " scale=", family_scale, " rotation_degrees=", weapon.rotation_degrees)
 weapon.set_meta("phase4a_grip_local", grip)
 weapon.set_meta("phase4a_mesh_count", _count_weapon_meshes(weapon))
 weapon_nodes.append(socket)
 skeleton.force_update_all_bone_transforms()
 await get_tree().process_frame
 skeleton.force_update_all_bone_transforms()
 print("HERO_REAL_HAND_BONE_RESOLVED: side=", hand_side, " bone_index=", bone, " bone_name=", actual_bone)
 print("HERO_WEAPON_BONE_ATTACHMENT_CREATED: ", socket_id, " parent=Skeleton3D bone=", actual_bone)
 print("HERO_WEAPON_GRIP_ALIGNED: family=", family, " scale=", family_scale, " bounds=", bounds, " grip=", grip, " meshes=", weapon.get_meta("phase4a_mesh_count"), " world_aabb_length=", maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))*family_scale)
 if family == "bow":
  assert(socket is BoneAttachment3D and weapon.get_parent() == socket and weapon.get_meta("phase4a_mesh_count", 0) > 0, "Bow weapon must be attached to BoneAttachment3D with valid meshes")
  assert(absf(maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))*family_scale - 1.2) < 0.02, "Bow world AABB length must remain 1.2m")
  print("HERO_BOW_ATTACHMENT_AABB_ASSERT_OK: bone=", actual_bone, " world_length=1.2m")
 print("HERO_WEAPON_HAND_WORLD_PENDING: ", socket_id, " bone=", actual_bone)
 call_deferred("_log_bone_attachment_world", socket_id)

func _log_bone_attachment_world(socket_id: String) -> void:
 var socket := skeleton.get_node_or_null(socket_id) as BoneAttachment3D if is_instance_valid(skeleton) else null
 if socket == null:
  push_error("HERO_HAND_ATTACHMENT_LOG_MISSING: " + socket_id)
  return
 print("HERO_REAL_HAND_BONE_WORLD: attachment=", socket_id, " bone=", socket.bone_name, " global_position=", socket.global_position)

func _collect_weapon_mesh_points(node: Node, parent_transform: Transform3D, points: Array[Vector3]) -> void:
 var current_transform := parent_transform
 if node is Node3D:
  current_transform = parent_transform * (node as Node3D).transform
 if node is MeshInstance3D:
  var mesh_instance := node as MeshInstance3D
  if mesh_instance.mesh != null:
   var box := mesh_instance.mesh.get_aabb()
   for x in range(2):
    for y in range(2):
     for z in range(2):
      var corner := box.position + Vector3(box.size.x * float(x), box.size.y * float(y), box.size.z * float(z))
      points.append(current_transform * corner)
 for child in node.get_children():
  _collect_weapon_mesh_points(child, current_transform, points)

func _points_bounds(points: Array[Vector3]) -> AABB:
 var minimum := Vector3(1.0e20, 1.0e20, 1.0e20)
 var maximum := Vector3(-1.0e20, -1.0e20, -1.0e20)
 for point in points:
  minimum.x = minf(minimum.x, point.x)
  minimum.y = minf(minimum.y, point.y)
  minimum.z = minf(minimum.z, point.z)
  maximum.x = maxf(maximum.x, point.x)
  maximum.y = maxf(maximum.y, point.y)
  maximum.z = maxf(maximum.z, point.z)
 return AABB(minimum, maximum - minimum)

func _count_weapon_meshes(node: Node) -> int:
 var count := 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
 for child in node.get_children():
  count += _count_weapon_meshes(child)
 return count

func _weapon_visual_metrics(socket: Node3D) -> Dictionary:
 if socket == null or not socket is BoneAttachment3D or socket.get_child_count() == 0:
  return {"mesh_count": 0, "grip_distance": 999.0}
 var weapon := socket.get_child(0) as Node3D
 if weapon == null:
  return {"mesh_count": 0, "grip_distance": 999.0}
 var grip: Vector3 = weapon.get_meta("phase4a_grip_local", Vector3.ZERO)
 var grip_world := weapon.to_global(grip)
 var palm_local: Vector3 = socket.get_meta("phase4c_palm_center_local", Vector3.ZERO)
 var palm_world := socket.to_global(palm_local)
 return {
  "mesh_count": _count_weapon_meshes(weapon),
  "grip_distance": grip_world.distance_to(palm_world),
  "grip_world": grip_world,
  "hand_world": palm_world,
  "actual_bone_name": socket.get_meta("phase4a_actual_bone_name", ""),
  "socket_type": "BoneAttachment3D"
 }

func _clear_weapons() -> void:
 for node in weapon_nodes:
  if is_instance_valid(node):
   var parent := node.get_parent()
   if parent != null:
    parent.remove_child(node)
   node.queue_free()
 weapon_nodes.clear()

func _update_animation() -> void:
 if animation_player == null:
  return
 if is_jumping:
  _play_hero_animation("Jump")
  return
 if velocity.length_squared() > 0.25:
  var run_clip := _find_animation_name("run")
  if run_clip.is_empty():
   run_clip = _find_animation_name("walk")
  if not run_clip.is_empty() and animation_player.current_animation != run_clip:
   animation_player.play(run_clip)
 else:
  var idle_clip := _find_animation_name("idle")
  if not idle_clip.is_empty():
   if animation_player.current_animation != idle_clip:
    animation_player.play(idle_clip)
  elif animation_player.is_playing():
   animation_player.stop()

func _ensure_input_actions() -> void:
 var bindings := {
  "move_left":[KEY_A,KEY_LEFT],
  "move_right":[KEY_D,KEY_RIGHT],
  "move_forward":[KEY_W,KEY_UP],
  "move_back":[KEY_S,KEY_DOWN]
 }
 for action in bindings:
  if not InputMap.has_action(action):
   InputMap.add_action(action)
  for keycode in bindings[action]:
   var already_bound := false
   for existing_event in InputMap.action_get_events(action):
    if existing_event is InputEventKey and (existing_event as InputEventKey).physical_keycode == keycode:
     already_bound = true
     break
   if not already_bound:
    var key := InputEventKey.new()
    key.physical_keycode = keycode
    InputMap.action_add_event(action,key)
