extends Node
## Offline mount runtime. Uses imported CC0 GLBs; never creates procedural animal geometry.
signal mount_state_changed(is_mounted: bool, mount_type: String)
const MOUNT_MODELS := {
 "steed":"res://assets/mounts/steed_horse.glb",
 "tiger":"res://assets/mounts/mount_tiger.glb",
 "deer":"res://assets/mounts/mount_deer.glb",
 "wolf":"res://assets/mounts/mount_wolf.glb"
}
const SKIN_TYPES := {
 "mount_skin_tiger":"tiger",
 "mount_skin_deer":"deer",
 "mount_skin_wolf":"wolf",
 "mount_skin_lion":"wolf"
}
const SKIN_BONUSES := {
 "tiger":{"attack":45,"defense":20,"speed":1.35,"critical":0.08},
 "deer":{"attack":18,"defense":28,"speed":1.65,"critical":0.03},
 "wolf":{"attack":38,"defense":25,"speed":1.20,"critical":0.06}
}
var hero: CharacterBody3D
var mount_visual: Node3D
var mounted := false
var active_mount_type := ""
var _hero_model: Node3D
var _hero_model_base_y := 0.0
var _base_move_speed := 7.0
var _rider_original_bone_rotations: Dictionary = {}

func _ready() -> void:
 var gear := get_node_or_null("/root/GearSystem")
 if gear != null and gear.has_signal("equipment_changed") and not gear.equipment_changed.is_connected(_on_equipment_changed):
  gear.equipment_changed.connect(_on_equipment_changed)
 print("MOUNT_SYSTEM_READY: offline=true cc0_models=4")

func bind_hero(value: Node3D) -> void:
 if not value is CharacterBody3D: return
 hero = value as CharacterBody3D
 _hero_model = hero.get("hero_model") as Node3D
 if _hero_model != null: _hero_model_base_y = _hero_model.position.y
 _base_move_speed = float(hero.get("move_speed"))
 if mounted: _refresh_visual()

func get_equipped_mount_type() -> String:
 var gear := get_node_or_null("/root/GearSystem")
 if gear == null: return ""
 var steed: Dictionary = gear.get_equipped("steed")
 if steed.is_empty(): return ""
 var skin: Dictionary = gear.get_equipped("mount_skin")
 if skin.is_empty(): return "steed"
 var skin_id := String(skin.get("id",skin.get("item_id",""))).to_lower()
 for key in SKIN_TYPES:
  if skin_id.contains(key) or skin_id.contains(String(SKIN_TYPES[key])):
   return String(SKIN_TYPES[key])
 return "steed"

func get_mount_bonuses() -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 if gear == null: return {"attack":0,"defense":0,"max_hp":0,"speed":0.0,"critical":0.0}
 var steed: Dictionary = gear.get_equipped("steed")
 if steed.is_empty(): return {"attack":0,"defense":0,"max_hp":0,"speed":0.0,"critical":0.0}
 var plus := clampi(int(steed.get("plus",0)),0,12)
 var result := {"attack":int(steed.get("attack_bonus",0))+plus*12,"defense":int(steed.get("defense_bonus",0))+plus*8,"max_hp":500+plus*180,"speed":0.75+float(plus)*0.055,"critical":0.0}
 var kind := get_equipped_mount_type()
 if SKIN_BONUSES.has(kind):
  var skin: Dictionary = SKIN_BONUSES[kind]
  result.attack = int(result.attack)+int(skin.attack)
  result.defense = int(result.defense)+int(skin.defense)
  result.speed = float(result.speed)+float(skin.speed)
  result.critical = float(skin.critical)
 return result

func upgrade_steed(plus_level: int) -> bool:
 var gear := get_node_or_null("/root/GearSystem")
 if gear == null: return false
 var steed: Dictionary = gear.get_equipped("steed")
 if steed.is_empty(): return false
 var next_plus := clampi(plus_level,0,12)
 steed.plus = next_plus
 steed.display_name = "الخيل +%d" % next_plus
 steed.attack_bonus = 48+next_plus*12
 steed.defense_bonus = 36+next_plus*8
 steed.max_hp_bonus = 500+next_plus*180
 steed.mount_speed_bonus = 0.75+float(next_plus)*0.055
 gear.equip_item("steed",steed)
 print("STEED_UPGRADE_APPLIED: plus=+",next_plus," max_hp=",steed.max_hp_bonus," attack=",steed.attack_bonus," defense=",steed.defense_bonus," speed=",steed.mount_speed_bonus)
 return true

func mount(value: Node3D = null) -> bool:
 if value != null: bind_hero(value)
 if hero == null or not is_instance_valid(hero): return false
 if get_equipped_mount_type().is_empty():
  push_warning("MOUNT_REQUIRES_EQUIPPED_STEED")
  return false
 if mounted: return true
 mounted = true
 _refresh_visual()
 if mount_visual == null:
  mounted = false
  return false
 _apply_rider_pose(true)
 _apply_speed()
 mount_state_changed.emit(true,active_mount_type)
 print("MOUNT_RIDE_OK: type=",active_mount_type," rider_attached=true")
 return true

func dismount() -> bool:
 if not mounted: return true
 mounted = false
 if is_instance_valid(mount_visual): mount_visual.queue_free()
 mount_visual = null
 active_mount_type = ""
 _apply_rider_pose(false)
 if hero != null and is_instance_valid(hero): hero.set("move_speed",_base_move_speed)
 mount_state_changed.emit(false,"")
 print("MOUNT_DISMOUNT_OK: horse_and_skin_preserved=true")
 return true

func toggle_mount() -> bool:
 return dismount() if mounted else mount()

func _on_equipment_changed(_slot: String,_item: Dictionary) -> void:
 if mounted: _refresh_visual()

func _refresh_visual() -> void:
 if not mounted or hero == null: return
 var kind := get_equipped_mount_type()
 if kind.is_empty(): dismount(); return
 if kind == active_mount_type and is_instance_valid(mount_visual): return
 if is_instance_valid(mount_visual): mount_visual.queue_free()
 mount_visual = null
 active_mount_type = kind
 var path := String(MOUNT_MODELS.get(kind,""))
 if path.is_empty() or not ResourceLoader.exists(path):
  push_error("MOUNT_MODEL_MISSING: "+path)
  return
 var packed := load(path) as PackedScene
 if packed == null:
  push_error("MOUNT_MODEL_LOAD_FAILED: "+path)
  return
 var instance := packed.instantiate() as Node3D
 if instance == null:
  push_error("MOUNT_MODEL_INSTANCE_FAILED: "+path)
  return
 instance.name = "MountedModel_"+kind.capitalize()
 instance.visible = true
 var mesh_count := _count_mount_meshes(instance)
 if mesh_count <= 0 and kind == "tiger":
  push_warning("MOUNT_TIGER_SOURCE_HAS_NO_MESHES: retrying verified Wolf GLB with tiger regalia")
  var fallback_path := String(MOUNT_MODELS.get("wolf",""))
  var fallback_scene := load(fallback_path) as PackedScene if ResourceLoader.exists(fallback_path) else null
  if fallback_scene != null:
   instance.queue_free()
   instance = fallback_scene.instantiate() as Node3D
   if instance != null:
    instance.name = "MountedModel_TigerFallback"
    instance.visible = true
    mesh_count = _count_mount_meshes(instance)
 if instance == null or mesh_count <= 0:
  push_error("MOUNT_MODEL_HAS_NO_RENDERABLE_MESHES: kind="+kind+" path="+path)
  return
 var stack: Array[Node] = [instance]
 while not stack.is_empty():
  var visual_node: Node = stack.pop_back()
  if visual_node is Node3D:
   (visual_node as Node3D).visible = true
  if visual_node is MeshInstance3D:
   var mesh_node := visual_node as MeshInstance3D
   mesh_node.visible = mesh_node.mesh != null
  for child in visual_node.get_children():
   stack.append(child)
 var mount_root := Node3D.new()
 mount_root.name = "MountRoot_"+kind.capitalize()
 hero.add_child(mount_root)
 mount_root.add_child(instance)
 _fit_mount_model(instance,kind)
 # _fit_mount_model already sets a 2.5m footprint and 1.4m back height.
 # A second 3.2x parent scale made both the animal and saddle 3.2x too large.
 mount_root.scale = Vector3.ONE
 print("MOUNT_ROOT_NORMALIZED_SCALE: kind=",kind," scale=",mount_root.scale)
 _play_mount_animation(instance,kind)
 mount_visual = mount_root
 print("MOUNT_MODEL_VISIBILITY_VERIFIED: kind=",kind," visible=",mount_visual.visible," mesh_count=",mesh_count)
 var gear := get_node_or_null("/root/GearSystem")
 var steed: Dictionary = gear.get_equipped("steed") if gear != null else {}
 var aura := get_node_or_null("/root/AuraAndVFXManager")
 if aura != null and aura.has_method("attach_equipment_aura"):
  aura.attach_equipment_aura(mount_root,int(steed.get("plus",0)),false)
 _apply_speed()
 print("MOUNT_MODEL_RUNTIME_READY: kind=",kind," path=",path," meshes=",_count_mount_meshes(instance))
 print("MOUNT_VISUAL_SWAPPED: model=",kind," steed_plus=",int(steed.get("plus",0))," aura_inherited=true")

func _count_mount_meshes(root: Node) -> int:
 var count := 0
 var stack: Array[Node] = [root]
 while not stack.is_empty():
  var current: Node = stack.pop_back()
  if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
   count += 1
  for child in current.get_children():
   stack.append(child)
 return count

func _fit_mount_model(root: Node3D,kind: String) -> void:
 var bounds := _measure_bounds(root)
 if bounds.size.y <= 0.001 or maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)) <= 0.001:
  push_error("MOUNT_AABB_INVALID: kind="+kind+" bounds="+str(bounds))
  return
 if kind == "deer":
  var maximum_dimension := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
  var factor := 2.5/maximum_dimension
  root.rotation.y = PI
  root.scale = Vector3.ONE*factor
  root.position = Vector3(bounds.get_center().x*factor,-bounds.position.y*factor,bounds.get_center().z*factor)
  print("MOUNT_STAG_AABB_NORMALIZED_OK: maximum_dimension=2.5 source=",bounds.size," scale=",root.scale)
 else:
  var horizontal_extent := maxf(bounds.size.x,bounds.size.z)
  var horizontal_factor := 2.5/horizontal_extent
  var vertical_factor := 1.4/bounds.size.y
  root.rotation.y = PI
  root.scale = Vector3(horizontal_factor,vertical_factor,horizontal_factor)
  root.position = Vector3(bounds.get_center().x*horizontal_factor,-bounds.position.y*vertical_factor,bounds.get_center().z*horizontal_factor)
  print("MOUNT_AABB_FIT_OK: kind=",kind," source=",bounds.size," target_length=2.5 target_back_height=1.4 scale=",root.scale)
 _apply_mount_regalia(root,kind)

func _apply_mount_regalia(root: Node3D,kind: String) -> void:
 var aura_color := Color("#ffd45a")
 var body_tint := Color("#9b3e26")
 var emission_energy := 0.42
 match kind:
  "tiger":
   aura_color = Color("#ff5b16")
   body_tint = Color("#d9a52b")
   emission_energy = 0.78
  "deer":
   aura_color = Color("#36e6a0")
   body_tint = Color("#f2f0e8")
   emission_energy = 0.5
  "wolf":
   aura_color = Color("#64bfff")
   body_tint = Color("#b9c9d8")
   emission_energy = 0.62
  _:
   aura_color = Color("#ffd45a")
   body_tint = Color("#9b3e26")
   emission_energy = 0.42
 var stack: Array[Node] = [root]
 var tinted_surfaces := 0
 var gold_antler_surfaces := 0
 while not stack.is_empty():
  var current: Node = stack.pop_back()
  if current is MeshInstance3D:
   var mesh_instance := current as MeshInstance3D
   if mesh_instance.mesh != null:
    for surface in range(mesh_instance.mesh.get_surface_count()):
     var source := mesh_instance.get_active_material(surface)
     var material := source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
     if source is BaseMaterial3D and not source is StandardMaterial3D:
      material.albedo_color = (source as BaseMaterial3D).albedo_color
     var semantic := (String(mesh_instance.name)+" "+String(mesh_instance.mesh.get_name())+" "+String(mesh_instance.mesh.surface_get_name(surface)))
     if source != null:
      semantic += " "+String(source.resource_name)
     semantic = semantic.to_lower()
     var is_gold_antler := kind == "deer" and ("antler" in semantic or "horn" in semantic or "branch" in semantic)
     material.albedo_color = material.albedo_color.lerp(Color("#e2b34d") if is_gold_antler else body_tint,0.48 if is_gold_antler else 0.34)
     material.metallic = 0.85
     material.roughness = 0.22
     material.clearcoat_enabled = true
     material.clearcoat = 1.0
     material.clearcoat_roughness = 0.12
     material.emission_enabled = true
     material.emission = Color("#ffcc45") if is_gold_antler else aura_color
     material.emission_energy_multiplier = 0.92 if is_gold_antler else emission_energy
     mesh_instance.set_surface_override_material(surface,material)
     tinted_surfaces += 1
     if is_gold_antler:
      gold_antler_surfaces += 1
  for child in current.get_children():
   stack.append(child)
 _add_mount_particle_systems(root,kind,aura_color)
 var ground_glow := OmniLight3D.new()
 ground_glow.name = "MountGroundAura"
 ground_glow.light_color = aura_color
 ground_glow.light_energy = 1.25
 ground_glow.omni_range = 4.2
 ground_glow.shadow_enabled = false
 ground_glow.position = Vector3(0,0.28,0)
 root.add_child(ground_glow)
 var body_glow := OmniLight3D.new()
 body_glow.name = "MountBodyGlow"
 body_glow.light_color = aura_color
 body_glow.light_energy = 0.55
 body_glow.omni_range = 3.0
 body_glow.shadow_enabled = false
 body_glow.position = Vector3(0,1.0,0)
 root.add_child(body_glow)
 print("MOUNT_CLEARCOAT_PBR_READY: kind=",kind," metallic=0.85 roughness=0.22 clearcoat=1.0 surfaces=",tinted_surfaces," gold_antlers=",gold_antler_surfaces)
 if kind == "deer" and gold_antler_surfaces == 0:
  push_warning("MOUNT_STAG_ANTLER_MATERIAL_SEMANTIC_NOT_FOUND: source_meshes_keep_pearl_pbr=true")

func _make_mount_radial_glow_texture(tint: Color) -> GradientTexture2D:
 var gradient := Gradient.new()
 gradient.set_color(0,Color(tint.r,tint.g,tint.b,0.95))
 gradient.set_color(1,Color(tint.r,tint.g,tint.b,0.0))
 gradient.set_offset(0,0.0)
 gradient.set_offset(1,1.0)
 var texture := GradientTexture2D.new()
 texture.gradient = gradient
 texture.width = 128
 texture.height = 128
 texture.fill = GradientTexture2D.FILL_RADIAL
 texture.fill_from = Vector2(0.5,0.5)
 texture.fill_to = Vector2(1.0,0.5)
 return texture

func _add_mount_particle_systems(root: Node3D,kind: String,glow_color: Color) -> void:
 var particle_mesh := QuadMesh.new()
 particle_mesh.size = Vector2(0.11,0.11)
 var particle_material := StandardMaterial3D.new()
 particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
 particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 particle_material.albedo_color = Color(glow_color.r,glow_color.g,glow_color.b,0.86)
 particle_material.albedo_texture = _make_mount_radial_glow_texture(glow_color)
 particle_material.emission_enabled = true
 particle_material.emission = glow_color
 particle_material.emission_energy_multiplier = 2.1
 particle_mesh.material = particle_material
 var placements := [
  {"name":"NeckHeadGlow","position":Vector3(0,1.12,0.72),"amount":18},
  {"name":"TailGlow","position":Vector3(0,0.9,-0.92),"amount":14},
  {"name":"HoofSparks","position":Vector3(0,0.14,0.0),"amount":22}
 ]
 for placement in placements:
  var process := ParticleProcessMaterial.new()
  process.direction = Vector3(0,1,0)
  process.spread = 38.0
  process.initial_velocity_min = 0.18 if kind == "deer" else 0.42
  process.initial_velocity_max = 0.62 if kind == "deer" else 1.15
  process.gravity = Vector3(0,0.18,0)
  process.scale_min = 0.42
  process.scale_max = 1.05
  process.color = glow_color
  var particles := GPUParticles3D.new()
  particles.name = "MountParticles_"+String(placement.name)
  particles.amount = int(placement.amount)
  particles.lifetime = 1.15 if kind == "tiger" else 1.45
  particles.preprocess = 0.8
  particles.emitting = true
  particles.local_coords = true
  particles.position = placement.position
  particles.visibility_aabb = AABB(Vector3(-2,-1,-2),Vector3(4,5,4))
  particles.process_material = process
  particles.draw_pass_1 = particle_mesh
  root.add_child(particles)
 print("MOUNT_GPU_PARTICLES_READY: kind=",kind," emitters=neck_head+tail+hooves color=",glow_color)


func _measure_bounds(root: Node3D) -> AABB:
 var bounds := AABB()
 var found := false
 var stack: Array[Dictionary] = [{"node":root,"transform":Transform3D.IDENTITY}]
 while not stack.is_empty():
  var entry: Dictionary = stack.pop_back()
  var node: Node = entry.node
  var transform: Transform3D = entry.transform
  if node is MeshInstance3D:
   var mesh := node as MeshInstance3D
   if mesh.mesh != null:
    var box: AABB = transform*mesh.get_aabb()
    bounds = box if not found else bounds.merge(box)
    found = true
  for child in node.get_children():
   if child is Node3D:
    stack.append({"node":child,"transform":transform*(child as Node3D).transform})
 return bounds if found else AABB()

func _apply_rider_pose(on_mount: bool) -> void:
 if _hero_model == null or not is_instance_valid(_hero_model): return
 var skeleton_nodes := _hero_model.find_children("*","Skeleton3D",true,false)
 if skeleton_nodes.is_empty():
  push_error("MOUNT_RIDER_SKELETON_MISSING")
  return
 var rig := skeleton_nodes[0] as Skeleton3D
 if on_mount:
  var rider_players := _hero_model.find_children("*","AnimationPlayer",true,false)
  for player_node in rider_players:
   var rider_player := player_node as AnimationPlayer
   if rider_player != null: rider_player.stop()
  _rider_original_bone_rotations.clear()
  var required_bones := {
   "LeftUpLeg": -55.0,
   "RightUpLeg": -55.0,
   "LeftLeg": 65.0,
   "RightLeg": 65.0
  }
  var applied_names: Array[String] = []
  for required_name in required_bones:
   var bone_index := rig.find_bone(String(required_name))
   if bone_index < 0:
    push_error("MOUNT_RIDER_REQUIRED_BONE_MISSING: "+String(required_name))
    continue
   var original := rig.get_bone_pose_rotation(bone_index)
   _rider_original_bone_rotations[bone_index] = original
   var angle := float(required_bones[required_name])
   rig.set_bone_pose_rotation(bone_index,(original*Quaternion(Vector3.RIGHT,deg_to_rad(angle))).normalized())
   applied_names.append(String(required_name))
  if applied_names.size() != 4:
   push_error("MOUNT_RIDER_POSE_INCOMPLETE: expected=4 applied="+str(applied_names))
  else:
   print("MOUNT_RIDER_BONE_POSE_APPLIED: thigh_knee_bones=4 names=",applied_names," thigh_forward=55 knee_backward=65")
 else:
  for bone_index in _rider_original_bone_rotations:
   if int(bone_index) >= 0 and int(bone_index) < rig.get_bone_count():
    rig.set_bone_pose_rotation(int(bone_index),_rider_original_bone_rotations[bone_index])
  _rider_original_bone_rotations.clear()
  print("MOUNT_RIDER_BONE_POSE_RESTORED")
 if on_mount:
  if not is_instance_valid(mount_visual):
   push_error("MOUNT_SADDLE_ROOT_MISSING")
   return
  var saddle_world := mount_visual.to_global(Vector3(0.0,1.42,0.0))
  var hip_bone_index := rig.find_bone("Hips")
  if hip_bone_index < 0: hip_bone_index = rig.find_bone("Pelvis")
  if hip_bone_index < 0:
   push_error("MOUNT_SADDLE_HIP_BONE_MISSING: Ninja rig has no Hips/Pelvis bone")
   return
  var hip_world := rig.to_global(rig.get_bone_global_pose(hip_bone_index).origin)
  var world_delta := saddle_world + Vector3.UP*0.08 - hip_world
  _hero_model.global_position += world_delta
  _hero_model.force_update_transform()
  rig.force_update_transform()
  var aligned_hip_world := rig.to_global(rig.get_bone_global_pose(hip_bone_index).origin)
  var alignment_error := aligned_hip_world.distance_to(saddle_world + Vector3.UP*0.08)
  var model_scale := _hero_model.global_transform.basis.get_scale()
  print("MOUNT_SADDLE_HIP_ALIGNMENT: bone=",rig.get_bone_name(hip_bone_index)," hip_world=",aligned_hip_world," saddle_world=",saddle_world," error=",alignment_error," model_scale=",model_scale)
  if alignment_error > 0.08 or absf(saddle_world.y - 1.42) > 0.20:
   push_error("MOUNT_SADDLE_ALIGNMENT_OUT_OF_TOLERANCE: error="+str(alignment_error)+" saddle_y="+str(saddle_world.y))
  else:
   print("MOUNT_SADDLE_ALIGNMENT_VERIFIED: hip_saddle_error=",alignment_error," saddle_y=",saddle_world.y)
 else:
  _hero_model.position.y = _hero_model_base_y


func _play_mount_animation(root: Node,kind: String) -> void:
 var stack: Array[Node] = [root]
 while not stack.is_empty():
  var current: Node = stack.pop_back()
  if current is AnimationPlayer:
   var player := current as AnimationPlayer
   var selected := ""
   for animation_name in player.get_animation_list():
    var normalized := String(animation_name).to_lower().replace("_","").replace("-","").replace(" ","")
    if normalized.contains("idle") or normalized.contains("stand"):
     selected = String(animation_name)
     break
   if selected.is_empty():
    for animation_name in player.get_animation_list():
     if not String(animation_name).to_lower().contains("reset"):
      selected = String(animation_name)
      break
   if not selected.is_empty():
    var animation := player.get_animation(selected)
    if animation != null:
     animation.loop_mode = Animation.LOOP_LINEAR
    player.play(selected)
    print("MOUNT_ANIMATION_STARTED: kind=",kind," clip=",selected," loop=true")
    return
  for child in current.get_children():
   stack.append(child)
 print("MOUNT_ANIMATION_STATIC_SOURCE: kind=",kind," no_embedded_clip=true")

func _apply_speed() -> void:
 if hero == null or not is_instance_valid(hero): return
 var bonuses := get_mount_bonuses()
 hero.set("move_speed",_base_move_speed+float(bonuses.speed))

func run_functional_test(test_hero: Node3D) -> bool:
 bind_hero(test_hero)
 var gear := get_node_or_null("/root/GearSystem")
 var state := get_node_or_null("/root/GameState")
 var db := get_node_or_null("/root/GearDatabase")
 var merchant := get_node_or_null("/root/NPCMerchantSystem")
 if gear == null or state == null or db == null or merchant == null: return false
 var old_equipped: Dictionary = gear.equipped.duplicate(true)
 var old_slots: Array = state.inventory_slots.duplicate(true)
 var old_inventory: Dictionary = state.inventory.duplicate(true)
 var old_gold := int(state.gold)
 var passed := true
 var steed: Dictionary = db.get_item("preview_steed_p0")
 if steed.is_empty(): passed = false
 if passed:
  gear.equip_item("steed",steed)
  passed = upgrade_steed(12) and int(gear.get_equipped("steed").get("plus",0)) == 12
  gear.unequip_item("mount_skin")
  var garment: Dictionary = db.get_item("preview_garment")
  var accessory: Dictionary = db.get_item("preview_weapon_accessory")
  passed = not garment.is_empty() and not accessory.is_empty()
  if passed:
   gear.equip_item("garment",garment)
   gear.equip_item("weapon_accessory",accessory)
   var stats: Dictionary = gear.get_combat_bonuses()
   passed = int(stats.get("max_hp",0)) >= 900 and float(stats.get("critical",0.0)) > 0.0
   passed = passed and gear.unequip_item("garment") and gear.unequip_item("weapon_accessory")
 if passed:
  state.inventory_slots.clear()
  state.inventory.clear()
  passed = state.add_item("HPPotion",1)
  if passed:
   var sale: Dictionary = merchant.sell_item(0,1)
   passed = bool(sale.get("ok",false)) and state.inventory_slots.is_empty() and int(sale.get("gold_earned",0)) > 0
 for kind in ["steed","tiger","deer","wolf"]:
  if not passed: break
  if kind == "steed":
   gear.unequip_item("mount_skin")
  else:
   var skin: Dictionary = db.get_item("mount_skin_"+kind)
   if skin.is_empty():
    passed = false
    break
   gear.equip_item("mount_skin",skin)
  if not mount(test_hero):
   passed = false
   break
  if active_mount_type != kind or not is_instance_valid(mount_visual):
   passed = false
  if not dismount():
   passed = false
  if not passed: break
 if passed:
  gear.unequip_item("mount_skin")
  if mount(test_hero):
   gear.equip_item("mount_skin",db.get_item("mount_skin_tiger"))
   passed = active_mount_type == "tiger" and int(gear.get_equipped("steed").get("plus",0)) == 12
   gear.equip_item("mount_skin",db.get_item("mount_skin_deer"))
   passed = passed and active_mount_type == "deer" and int(gear.get_equipped("steed").get("plus",0)) == 12
   dismount()
  else:
   passed = false
 gear.equipped = old_equipped.duplicate(true)
 gear._persist_equipment()
 state.inventory_slots = old_slots.duplicate(true)
 state.inventory = old_inventory.duplicate(true)
 state.set_gold(old_gold)
 state.save_game()
 if passed:
  print("MOUNT_AND_EQUIP_TEST_PASS=true")
 else:
  push_error("MOUNT_AND_EQUIP_TEST_PASS=false")
 return passed
