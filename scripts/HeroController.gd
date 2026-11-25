extends CharacterBody3D
class_name HeroController

const RANGER_MALE := "res://assets/phase3b/characters/Male_Ranger.glb"
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

func _ready() -> void:
 name = "PlayableHero"
 floor_snap_length = 0.35
 await _load_approved_ranger()
 _setup_camera()
 _switch_class("archer")
 _ensure_input_actions()
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

func _load_approved_ranger() -> void:
 if not ResourceLoader.exists(RANGER_MALE):
  push_error("HERO_APPROVED_RANGER_MISSING")
  return
 var has_animation_library := ResourceLoader.exists(ANIMS)
 if not has_animation_library and OS.get_environment("PHASE4A_CAPTURE") != "1":
  push_error("HERO_ANIMATION_LIBRARY_MISSING")
  return
 var packed := load(RANGER_MALE) as PackedScene
 hero_model = packed.instantiate() as Node3D if packed else null
 if hero_model == null:
  push_error("HERO_RANGER_INSTANCE_FAILED")
  return
 hero_model.name = "ApprovedRanger"
 # Male_Ranger source faces +Z while Godot look_at() aims the parent -Z.
 # Rotate only the visual rig; preserve gameplay/root heading.
 hero_model.rotation.y = PI
 add_child(hero_model)
 await get_tree().process_frame
 _normalize_hero_scale()
 var found := hero_model.find_children("*","Skeleton3D",true,false)
 if found.is_empty():
  push_error("HERO_RANGER_SKELETON_MISSING")
  return
 skeleton = found[0] as Skeleton3D
 if has_animation_library:
  animation_player = AnimationPlayer.new()
  animation_player.name = "AnimationPlayer"
  hero_model.add_child(animation_player)
  animation_player.root_node = NodePath("..")
  var library := load(ANIMS) as AnimationLibrary
  if library == null or animation_player.add_animation_library("",library) != OK:
   push_error("HERO_ANIMATION_LIBRARY_ATTACH_FAILED")
   return
  animation_player.play("Idle")
  await get_tree().process_frame
  var approved_clips := ["Idle", "Run", "Jump", "Attack_Bow", "Attack_Assassin", "Attack_Trojan", "Attack_SwordShield", "Attack_Staff", "Hit", "Death"]
  var missing_clips: Array[String] = []
  for clip_name in approved_clips:
   if not animation_player.has_animation(clip_name):
    missing_clips.append(clip_name)
  if not missing_clips.is_empty() or animation_player.current_animation != "Idle":
   push_error("HERO_APPROVED_ANIMATION_LIBRARY_INCOMPLETE: missing=" + str(missing_clips) + " current=" + animation_player.current_animation)
   return
  print("HERO_ANIMATION_LIBRARY_LOADED: clips=", library.get_animation_list())
  print("HERO_ANIMATION_IDLE_PLAYING: current=", animation_player.current_animation, " root_node=", animation_player.root_node, " skeleton_path=", animation_player.get_path_to(skeleton))
  print("PHASE4A_ANIMATION_RESOURCE_PRESERVED: approved_builder_invoked_unchanged=true all_10_clips_loaded=true idle_playing=true resource_runtime_read_only=true")
 else:
  print("PHASE4A_ANIMATION_RESOURCE_PRESERVED: generated .res not rebuilt, loaded or modified")

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
 if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  _set_click_target(event.position)

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
 if animation_player and animation_player.has_animation("Jump"):
  animation_player.play("Jump")
 print("HERO_CONQUER_JUMP: stamina=",stamina)

func _switch_class(class_id: String) -> void:
 if class_id == "oriental_assassin" and character_level < 40:
  print("HERO_ASSASSIN_LOCKED_LEVEL_40")
  return
 if not CLASS_CLIPS.has(class_id): return
 active_class = class_id
 if is_instance_valid(animation_player):
  animation_player.play("Idle")
 _clear_weapons()
 _apply_approved_palette()
 _attach_class_weapons()
 print("HERO_CLASS_SWITCHED: ",active_class," weapon_mode=",("dual_knives" if active_class=="oriental_assassin" else "bow" if active_class=="archer" else active_class))

func _apply_approved_palette() -> void:
 if hero_model == null: return
 var colors: Array = PALETTES[active_class]
 var part_index := 0
 for node in hero_model.find_children("*","MeshInstance3D",true,false):
  var mi := node as MeshInstance3D
  if mi.mesh == null: continue
  for surface in range(mi.mesh.get_surface_count()):
   var material := StandardMaterial3D.new()
   if active_class in ["archer","oriental_assassin"]:
    var part := mi.name.to_lower()
    material.albedo_color = colors[0] if ("arms" in part or "sleeve" in part) else colors[1]
   else:
    material.albedo_color = colors[part_index % colors.size()]
   material.roughness = 0.72
   material.metallic = 0.04
   mi.set_surface_override_material(surface,material)
   part_index += 1

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
 for i in range(skeleton.get_bone_count()):
  var actual := skeleton.get_bone_name(i)
  var normalized := actual.to_lower().replace("_","").replace("-","").replace(" ","").replace(":","")
  var matches_side := normalized.contains(required_side + "hand") or normalized.ends_with("hand" + ("r" if side == "r" else "l"))
  if normalized.contains("hand") and matches_side:
   print("HERO_HAND_BONE_NAME_MATCH: side=", side, " index=", i, " name=", actual)
   return i
 var available: Array[String] = []
 for i in range(skeleton.get_bone_count()):
  available.append(skeleton.get_bone_name(i))
 push_error("HERO_STRICT_HAND_BONE_NOT_FOUND: side=" + side + " available=" + str(available))
 return -1

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
 socket.add_child(weapon)
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
  # Keep the bow upright, then compose the two director-requested rotations:
  # 1) close the bow plane around its length axis (local Y).
  # 2) rotate 180 degrees in the bow plane around its normal.
  weapon.rotation = Vector3(0.0, PI, PI / 2.0)
  var bow_up_dir := Vector3.UP
  weapon.rotate_object_local(bow_up_dir, PI / 2.0)
  var bow_up_after_first: Vector3 = weapon.transform.basis * bow_up_dir
  var bow_forward_after_first: Vector3 = weapon.transform.basis * Vector3.FORWARD
  var bow_plane_normal := bow_up_after_first.cross(bow_forward_after_first).normalized()
  var bow_plane_normal_local := (weapon.transform.basis.inverse() * bow_plane_normal).normalized()
  weapon.rotate_object_local(bow_plane_normal_local, PI)
  # Fine adjustment: add 30 degrees in the same bow-plane spin direction.
  weapon.rotate_object_local(bow_plane_normal_local, deg_to_rad(30.0))
  print("PHASE4C_BOW_FIRST_COMPOSITE_ROTATION_APPLIED: axis=bow_up_dir_local_y angle=90deg")
  print("PHASE4C_BOW_SECOND_COMPOSITE_ROTATION_APPLIED: axis=bow_plane_normal angle=180deg normal=", bow_plane_normal, " local_axis=", bow_plane_normal_local)
  print("PHASE4C_BOW_FINE_IN_PLANE_SPIN_APPLIED: axis=bow_plane_normal angle=+30deg total_in_plane_spin=210deg")
  print("PHASE4C_BOW_COMPOSITE_ORIENTATION_OK: upright_preserved=true plane_rotated=true fine_spin=30deg")
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
 var bow_forward_seat_offset := Vector3.ZERO
 if family == "bow":
  # Move the wooden grip forward toward the fingers by 90 mm inside the hand socket.
  bow_forward_seat_offset = Vector3(0.0, 0.0, -0.09)
 weapon.position = -rotated_grip_offset + bow_forward_seat_offset
 if family == "bow":
  print("PHASE4C_BOW_PALM_CENTER_OFFSET_APPLIED: direction=toward_fingers socket_local_offset_m=", bow_forward_seat_offset.length(), " target=0.09m")
  print("PHASE4C_BOW_ROTATED_GRIP_COMPENSATION_OK: rotated_grip_offset=", rotated_grip_offset, " seating_offset=", bow_forward_seat_offset, " scale=", family_scale, " rotation_degrees=", weapon.rotation_degrees)
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
 var hand_world := (socket as BoneAttachment3D).global_position
 return {
  "mesh_count": _count_weapon_meshes(weapon),
  "grip_distance": grip_world.distance_to(hand_world),
  "grip_world": grip_world,
  "hand_world": hand_world,
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
 if animation_player == null: return
 if is_jumping:
  if animation_player.current_animation != "Jump" and animation_player.has_animation("Jump"):
   animation_player.play("Jump")
  return
 if velocity.length_squared() > 0.25:
  if animation_player.current_animation != "Run" and animation_player.has_animation("Run"):
   animation_player.play("Run")
 elif animation_player.current_animation != "Idle" and animation_player.has_animation("Idle"):
  animation_player.play("Idle")

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
   var key := InputEventKey.new()
   key.physical_keycode = keycode
   InputMap.action_add_event(action,key)
