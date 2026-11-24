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

func _ready() -> void:
 name = "PlayableHero"
 floor_snap_length = 0.35
 _load_approved_ranger()
 _setup_camera()
 _switch_class("archer")
 _ensure_input_actions()
 set_process_unhandled_input(true)
 print("HERO_CONTROLLER_READY: classes=Archer,Trojan,Warrior,Taoist stamina=100")

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
 add_child(hero_model)
 var found := hero_model.find_children("*","Skeleton3D",true,false)
 if found.is_empty():
  push_error("HERO_RANGER_SKELETON_MISSING")
  return
 skeleton = found[0] as Skeleton3D
 if has_animation_library:
  animation_player = AnimationPlayer.new()
  animation_player.name = "AnimationPlayer"
  hero_model.add_child(animation_player)
  var library := load(ANIMS) as AnimationLibrary
  if library == null or animation_player.add_animation_library("",library) != OK:
   push_error("HERO_ANIMATION_LIBRARY_ATTACH_FAILED")
   return
  animation_player.play("Idle")
  print("HERO_ANIMATION_LIBRARY_LOADED: clips=",library.get_animation_list())
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
  "archer": _attach_weapon("hand_l","bow")
  "oriental_assassin":
   _attach_weapon("hand_l","dual_knives")
   _attach_weapon("hand_r","dual_knives")
  "trojan":
   _attach_weapon("hand_l","dual_blades")
   _attach_weapon("hand_r","dual_blades")
  "warrior":
   _attach_weapon("hand_l","shield")
   _attach_weapon("hand_r","greatsword")
  "taoist": _attach_weapon("hand_r","magic_staff")

func _attach_weapon(bone_name: String,family: String) -> void:
 if skeleton == null: return
 var bone := skeleton.find_bone(bone_name)
 if bone < 0:
  for i in range(skeleton.get_bone_count()):
   var normalized := skeleton.get_bone_name(i).to_lower().replace("_","")
   if normalized == bone_name.replace("_",""):
    bone = i
    break
 if bone < 0:
  push_error("HERO_WEAPON_SOCKET_MISSING: "+bone_name)
  return
 var filename := str(WEAPON_FILES.get(family,""))
 var path := WEAPON_ROOT+filename
 if not ResourceLoader.exists(path):
  push_error("HERO_WEAPON_ASSET_MISSING: "+path)
  return
 var packed := load(path) as PackedScene
 var weapon := packed.instantiate() as Node3D if packed else null
 if weapon == null: return
 var socket := BoneAttachment3D.new()
 socket.name = "HeroWeapon_"+family+"_"+bone_name
 socket.bone_name = skeleton.get_bone_name(bone)
 socket.bone_idx = bone
 skeleton.add_child(socket)
 socket.add_child(weapon)
 weapon.scale = Vector3.ONE*(0.4 if family=="dual_knives" else 0.7)
 weapon_nodes.append(socket)

func _clear_weapons() -> void:
 for node in weapon_nodes:
  if is_instance_valid(node): node.queue_free()
 weapon_nodes.clear()

func _update_animation() -> void:
 if animation_player == null or is_jumping: return
 if velocity.length_squared() > 0.25:
  if animation_player.current_animation != "Run": animation_player.play("Run")
 elif animation_player.current_animation != "Idle":
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
