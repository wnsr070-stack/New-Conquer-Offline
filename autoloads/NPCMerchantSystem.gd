extends Node
## Runtime NPC placement uses imported Phase 3B humanoid GLB assets only.
signal npc_interacted(npc_id: String, role_type: String)
signal quest_npc_interacted(npc_id: String, role_type: String)

const NPC_DEFINITIONS := [
 {"id":"Celestine","city":"TwinCity","role":"quest","position":Vector3(-9,0,-58),"model":"taoist_female","prompt":"[!]"},
 {"id":"GeneralQing","city":"TwinCity","role":"quest","position":Vector3(-4.5,0,-58),"model":"warrior_male","prompt":"[!]"},
 {"id":"ImperialEnvoy","city":"TwinCity","role":"quest","position":Vector3(0,0,-58),"model":"taoist_male","prompt":"[!]"},
 {"id":"RebirthMaster","city":"TwinCity","role":"quest","position":Vector3(4.5,0,-58),"model":"taoist_male","prompt":"[!]"},
 {"id":"ItemSocketingMaster","city":"TwinCity","role":"quest","position":Vector3(9,0,-58),"model":"warrior_female","prompt":"[!]"},
 {"id":"ArcherGod","city":"TwinCity","role":"quest","position":Vector3(-22,0,-18),"model":"archer_male","prompt":"[!]"},
 {"id":"EventMaster","city":"TwinCity","role":"quest","position":Vector3(-22,0,-13.5),"model":"trojan_female","prompt":"[!]"},
 {"id":"MonsterSlayer","city":"TwinCity","role":"quest","position":Vector3(-22,0,-9),"model":"warrior_male","prompt":"[!]"},
 {"id":"GemCollector","city":"TwinCity","role":"quest","position":Vector3(-22,0,-4.5),"model":"taoist_male","prompt":"[!]"},
 {"id":"TCGuide","city":"TwinCity","role":"quest","position":Vector3(-22,0,0),"model":"archer_female","prompt":"[!]"},
 {"id":"ArenaGuard","city":"TwinCity","role":"quest","position":Vector3(-22,0,4.5),"model":"warrior_male","prompt":"[!]"},
 {"id":"Blacksmith","city":"TwinCity","role":"shop","position":Vector3(-22.5,0,20),"model":"warrior_male","prompt":"[Shop]"},
 {"id":"Armorer","city":"TwinCity","role":"shop","position":Vector3(-18,0,20),"model":"trojan_male","prompt":"[Shop]"},
 {"id":"ArtisanMaster","city":"TwinCity","role":"forge","position":Vector3(-13.5,0,20),"model":"archer_male","prompt":"[Forge]"},
 {"id":"AccessoryMerchant","city":"TwinCity","role":"shop","position":Vector3(-9,0,20),"model":"taoist_male","prompt":"[Shop]"},
 {"id":"WeaponMaster","city":"TwinCity","role":"shop","position":Vector3(-4.5,0,20),"model":"warrior_male","prompt":"[Shop]"},
 {"id":"GuildOfficer","city":"TwinCity","role":"quest","position":Vector3(0,0,20),"model":"warrior_male","prompt":"[!]"},
 {"id":"Pharmacist","city":"TwinCity","role":"shop","position":Vector3(4.5,0,20),"model":"taoist_female","prompt":"[Shop]"},
 {"id":"Warehouseman","city":"TwinCity","role":"warehouse","position":Vector3(9,0,20),"model":"trojan_male","prompt":"[Box]"},
 {"id":"Ming","city":"TwinCity","role":"quest","position":Vector3(13.5,0,20),"model":"taoist_female","prompt":"[!]"},
 {"id":"LongDong","city":"TwinCity","role":"quest","position":Vector3(18,0,20),"model":"warrior_male","prompt":"[!]"},
 {"id":"GuildDirector","city":"TwinCity","role":"quest","position":Vector3(22.5,0,20),"model":"warrior_male","prompt":"[!]"},
 {"id":"Conductress","city":"TwinCity","role":"transport","position":Vector3(22,0,0),"model":"taoist_male","prompt":"[Gate]"},
 {"id":"Blacknull","city":"TwinCity","role":"quest","position":Vector3(22,0,-4.5),"model":"taoist_male","prompt":"[!]"},
 {"id":"F.Chen","city":"TwinCity","role":"quest","position":Vector3(22,0,-9),"model":"taoist_male","prompt":"[!]"},
 {"id":"Synsia","city":"TwinCity","role":"quest","position":Vector3(22,0,-13.5),"model":"taoist_male","prompt":"[!]"},
 {"id":"DailyEnvoy","city":"TwinCity","role":"quest","position":Vector3(22,0,-18),"model":"taoist_male","prompt":"[!]"},
 {"id":"LoveStone","city":"TwinCity","role":"quest","position":Vector3(22,0,4.5),"model":"taoist_male","prompt":"[!]"},
 {"id":"Fortuneteller","city":"TwinCity","role":"quest","position":Vector3(22,0,9),"model":"taoist_male","prompt":"[!]"},
 {"id":"CaptainLi","city":"TwinCity","role":"quest","position":Vector3(22,0,13.5),"model":"taoist_male","prompt":"[!]"},
 {"id":"Pharmacist","city":"PhoenixCastle","role":"shop","position":Vector3(-9,0,-98),"model":"taoist_female","prompt":"[Shop]"},
 {"id":"Blacksmith","city":"PhoenixCastle","role":"shop","position":Vector3(-4.5,0,-98),"model":"warrior_male","prompt":"[Shop]"},
 {"id":"Warehouseman","city":"PhoenixCastle","role":"warehouse","position":Vector3(0,0,-98),"model":"trojan_male","prompt":"[Box]"},
 {"id":"Conductress","city":"PhoenixCastle","role":"transport","position":Vector3(4.5,0,-98),"model":"archer_female","prompt":"[Gate]"},
 {"id":"CoachLin","city":"PhoenixCastle","role":"quest","position":Vector3(9,0,-98),"model":"warrior_male","prompt":"[!]"},
 {"id":"Alchemist","city":"PhoenixCastle","role":"quest","position":Vector3(13.5,0,-98),"model":"taoist_male","prompt":"[!]"},
 {"id":"Pharmacist","city":"ApeMountain","role":"shop","position":Vector3(-84,0,-52),"model":"taoist_female","prompt":"[Shop]"},
 {"id":"Blacksmith","city":"ApeMountain","role":"shop","position":Vector3(-79.5,0,-52),"model":"warrior_male","prompt":"[Shop]"},
 {"id":"Warehouseman","city":"ApeMountain","role":"warehouse","position":Vector3(-75,0,-52),"model":"trojan_male","prompt":"[Box]"},
 {"id":"Conductress","city":"ApeMountain","role":"transport","position":Vector3(-70.5,0,-52),"model":"archer_female","prompt":"[Gate]"},
 {"id":"SolarSaint","city":"ApeMountain","role":"quest","position":Vector3(-66,0,-52),"model":"taoist_male","prompt":"[!]"},
 {"id":"CelestialTaoist","city":"ApeMountain","role":"quest","position":Vector3(-61.5,0,-52),"model":"taoist_female","prompt":"[!]"},
 {"id":"Pharmacist","city":"DesertCity","role":"shop","position":Vector3(-6.75,0,-88),"model":"archer_male","prompt":"[!]"},
 {"id":"Blacksmith","city":"DesertCity","role":"shop","position":Vector3(-2.25,0,-88),"model":"archer_male","prompt":"[!]"},
 {"id":"Warehouseman","city":"DesertCity","role":"warehouse","position":Vector3(2.25,0,-88),"model":"archer_male","prompt":"[!]"},
 {"id":"Conductress","city":"DesertCity","role":"transport","position":Vector3(6.75,0,-88),"model":"archer_male","prompt":"[!]"},
 {"id":"Pharmacist","city":"BirdIsland","role":"shop","position":Vector3(25.25,4.6,2),"model":"archer_male","prompt":"[!]"},
 {"id":"Blacksmith","city":"BirdIsland","role":"shop","position":Vector3(29.75,4.6,2),"model":"archer_male","prompt":"[!]"},
 {"id":"Warehouseman","city":"BirdIsland","role":"warehouse","position":Vector3(34.25,4.6,2),"model":"archer_male","prompt":"[!]"},
 {"id":"Conductress","city":"BirdIsland","role":"transport","position":Vector3(38.75,4.6,2),"model":"archer_male","prompt":"[!]"},
 {"id":"CloudSaint","city":"Market","role":"quest","position":Vector3(-9,0,14),"model":"archer_male","prompt":"[!]"},
 {"id":"TaoistMoon","city":"Market","role":"quest","position":Vector3(-4.5,0,14),"model":"archer_male","prompt":"[!]"},
 {"id":"BlessedGreatMaster","city":"Market","role":"quest","position":Vector3(0,0,14),"model":"archer_male","prompt":"[!]"},
 {"id":"Warehouseman","city":"Market","role":"warehouse","position":Vector3(4.5,0,14),"model":"archer_male","prompt":"[!]"},
 {"id":"Conductress","city":"Market","role":"transport","position":Vector3(9,0,14),"model":"archer_male","prompt":"[!]"}
]
const CharacterVisualControllerScript = preload("res://scripts/CharacterVisualController.gd")
const INTERACTION_HEIGHT := 3.2
const INTERACTION_RADIUS := 4.5
const SHOP_STOCK := {
 "Pharmacist":[
  {"id":"HPPotion","name":"HP Potion","type":"Potion","price":80},
  {"id":"MPPotion","name":"MP Potion","type":"Potion","price":80},
  {"id":"Antidote","name":"Antidote","type":"Potion","price":120},
  {"id":"StaminaPotion","name":"Stamina Potion","type":"Potion","price":150}
 ],
 "Blacksmith":[
  {"id":"bow_lv10_normal_p1","name":"Beginner Bow","type":"Weapon","price":1500},
  {"id":"dual_blades_lv10_normal_p1","name":"Beginner Dual Blades","type":"Weapon","price":1650},
  {"id":"spear_lv10_normal_p1","name":"Beginner Spear","type":"Weapon","price":1450},
  {"id":"magic_staff_lv10_normal_p1","name":"Beginner Magic Staff","type":"Weapon","price":1400},
  {"id":"Plus1Stone","name":"Plus +1 Stone","type":"Orb","price":600}
 ],
 "Armorer":[
  {"id":"body_03_beginner_normal_p1","name":"Beginner Leather Armor","type":"Armor","price":1800},
  {"id":"body_01_beginner_normal_p1","name":"Beginner Full Plate","type":"Armor","price":1900},
  {"id":"helmet_01_beginner_normal_p1","name":"Beginner Helmet","type":"Helmet","price":900},
  {"id":"boots_01_beginner_normal_p1","name":"Beginner Boots","type":"Boots","price":650}
 ],
 "AccessoryMerchant":[
  {"id":"DragonGem","name":"Dragon Gem","type":"Gem","price":12000},
  {"id":"GloryGem","name":"Glory Gem","type":"Gem","price":9000},
  {"id":"SoulJade","name":"Soul Jade","type":"Gem","price":6500},
  {"id":"ThunderGem","name":"Thunder Gem","type":"Gem","price":7500},
  {"id":"Meteor","name":"Meteor","type":"Orb","price":1000},
  {"id":"AnimaStone","name":"Anima Stone","type":"Orb","price":8000}
 ]
}
var _city_root: Node3D
var _npc_nodes: Dictionary = {}

func _ready() -> void:
 var forging := get_node_or_null("/root/ForgingSystem")
 if forging != null and not npc_interacted.is_connected(forging.handle_npc_interaction):
  npc_interacted.connect(forging.handle_npc_interaction)
 print("NPC_MERCHANT_SYSTEM_READY: imported_character_models_only=true")

func _exit_tree() -> void:
 # The city may already have freed its children before this autoload exits.
 # Validate every Variant before casting or dereferencing it.
 for npc_value: Variant in _npc_nodes.values():
  if not is_instance_valid(npc_value):
   continue
  var npc := npc_value as Node3D
  if is_instance_valid(npc) and npc.get_parent() == null:
   npc.free()
 _npc_nodes.clear()
 _city_root = null
 print("NPC_MERCHANT_SYSTEM_EXIT_CLEANUP_OK: detached_npc_roots=0 registry=0")

func spawn_city_npcs(city_root: Node3D) -> void:
 if city_root == null or not is_instance_valid(city_root):
  return
 _city_root = city_root
 var city_id := _resolve_city_id(city_root)
 var spawned_count := 0
 for definition in NPC_DEFINITIONS:
  # Twin City is the Phase 4D hub preview: place all 30 authored merchants and quest NPCs there.
  # Other city scenes retain their explicitly assigned NPC subsets.
  if String(definition.get("city","TwinCity")) != city_id: continue
  var npc_id := String(definition.id)
  if _npc_nodes.has(npc_id):
   var existing_npc: Variant = _npc_nodes[npc_id]
   if is_instance_valid(existing_npc):
    spawned_count += 1
    continue
   _npc_nodes.erase(npc_id)
  # Use the same imported-character construction path as CharacterVisualController.
  # The Phase 4D workflow restores this exact approved source as Male_Ranger.glb.
  var npc := Node3D.new()
  npc.name = "NPC_"+npc_id
  npc.set_meta("npc_id",npc_id)
  npc.set_meta("role_type",String(definition.role))
  city_root.add_child(npc)
  _ensure_authored_ground_collider(city_root,definition.position,npc_id)
  npc.position = _resolve_ground_position(city_root,definition.position)
  var facing_target := city_root.to_global(Vector3(0.0,definition.position.y,0.0))
  if npc.global_position.distance_to(facing_target) > 0.01:
   npc.look_at(facing_target,Vector3.UP)
  var character := CharacterVisualControllerScript.new() as Node3D
  if character == null:
   npc.free()
   continue
  character.name = "ImportedCharacterVisualController"
  npc.add_child(character)
  character.call("build_character","archer",1,"male")
  if not bool(character.get("assets_ready")):
   var resolved_source := String(character.call("_resolve_character_asset_path","Male_Ranger","male"))
   push_error("NPC_IMPORTED_CHARACTER_BUILD_FAILED: id="+npc_id+
    " expected=res://assets/phase3b/characters/Male_Ranger.glb"+
    " resolved="+(resolved_source if not resolved_source.is_empty() else "<none>")+
    " controller_assets_ready="+str(character.get("assets_ready")))
   # Free the failed controller (and any partially instantiated model/weapon nodes)
   # before releasing its NPC parent so no detached scene references survive.
   if is_instance_valid(character):
    character.free()
   if is_instance_valid(npc):
    npc.free()
   continue
  _play_npc_idle_animation(character,npc_id)
  _fit_character_height(character,2.8)
  _add_name_label(npc,npc_id)
  _add_interaction_prompt(npc,npc_id,String(definition.role),String(definition.prompt))
  _npc_nodes[npc_id] = npc
  spawned_count += 1
  print("PHASE4D_QUEST_NPC_SPAWNED: id=",npc_id," role=",definition.role," pos=",definition.position," source=res://assets/phase3b/characters/Male_Ranger.glb")
 print("PHASE4D_CITY_NPC_REGISTRY_READY: spawned=",spawned_count," requested=",NPC_DEFINITIONS.size()," city=",city_id)
 if city_id == "TwinCity":
  print("PHASE4D_NPC_OVERHEAD_PROMPTS_READY: spawned=",spawned_count," height=",INTERACTION_HEIGHT,"m")


func _play_npc_idle_animation(character_root: Node, npc_id: String) -> void:
 var animation_players: Array[Node] = character_root.find_children("*","AnimationPlayer",true,false)
 if animation_players.is_empty():
  push_warning("PHASE4D_NPC_IDLE_ANIMATION_MISSING: id="+npc_id+" animation_player=false")
  return
 var animation_player := animation_players[0] as AnimationPlayer
 if animation_player == null:
  push_warning("PHASE4D_NPC_IDLE_ANIMATION_MISSING: id="+npc_id+" animation_player_invalid=true")
  return
 var animation_names := animation_player.get_animation_list()
 if animation_names.is_empty():
  push_warning("PHASE4D_NPC_IDLE_ANIMATION_MISSING: id="+npc_id+" animations=0")
  return
 var selected_animation := ""
 for preferred_name in ["Idle","idle","Stand","stand","Standing","standing"]:
  for animation_name in animation_names:
   if String(animation_name).to_lower() == String(preferred_name).to_lower():
    selected_animation = String(animation_name)
    break
  if not selected_animation.is_empty():
   break
 if selected_animation.is_empty():
  selected_animation = String(animation_names[0])
 var animation := animation_player.get_animation(selected_animation)
 if animation != null:
  animation.loop_mode = Animation.LOOP_LINEAR
 animation_player.play(selected_animation)
 print("PHASE4D_NPC_IDLE_ANIMATION_STARTED: id=",npc_id," animation=",selected_animation," loop=true")

func _ensure_authored_ground_collider(city_root: Node3D, authored_position: Vector3, npc_id: String) -> void:
 var key := "NPCGround_"+npc_id
 if city_root.get_node_or_null(NodePath(key)) != null: return
 var body := StaticBody3D.new()
 body.name = key
 body.position = Vector3(authored_position.x,authored_position.y-0.05,authored_position.z)
 body.collision_layer = 1
 body.collision_mask = 1
 var collision := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = Vector3(4.2,0.1,4.2)
 collision.shape = shape
 body.add_child(collision)
 city_root.add_child(body)
 print("PHASE4D_NPC_AUTHORED_GROUND_COLLIDER_READY: id=",npc_id," surface_y=",authored_position.y)

func _resolve_ground_position(city_root: Node3D, authored_position: Vector3) -> Vector3:
 var world := city_root.get_world_3d()
 if world != null:
  var query := PhysicsRayQueryParameters3D.create(
   Vector3(authored_position.x,30.0,authored_position.z),
   Vector3(authored_position.x,-10.0,authored_position.z))
  query.collision_mask = 1
  query.collide_with_areas = false
  query.collide_with_bodies = true
  var hit: Dictionary = world.direct_space_state.intersect_ray(query)
  if not hit.is_empty():
   var ground_y := float(hit.position.y)
   print("PHASE4D_NPC_GROUND_RAY_OK: x=",authored_position.x," z=",authored_position.z," ground_y=",ground_y," collider=",hit.collider.name)
   return Vector3(authored_position.x,ground_y,authored_position.z)
 push_warning("PHASE4D_NPC_GROUND_RAY_MISS: authored collider surface retained at "+str(authored_position))
 return authored_position

func _resolve_city_id(root: Node3D) -> String:
 var value := root.name.to_lower().replace("_","").replace(" ","")
 if value.contains("market"): return "Market"
 if value.contains("ape"): return "ApeMountain"
 if value.contains("phoenix"): return "PhoenixCastle"
 if value.contains("desert"): return "DesertCity"
 if value.contains("bird"): return "BirdIsland"
 return "TwinCity"

func get_npc_definition(npc_id: String) -> Dictionary:
 for definition in NPC_DEFINITIONS:
  if String(definition.id) == npc_id: return definition.duplicate(true)
 return {}

func _fit_character_height(root: Node3D,target_height: float) -> void:
 var bounds := _mesh_bounds(root,Transform3D.IDENTITY)
 if bounds.size.y <= 0.001:
  push_warning("NPC_IMPORTED_CHARACTER_EMPTY_BOUNDS: "+root.name)
  return
 var factor := target_height / bounds.size.y
 root.scale = Vector3.ONE * factor
 root.position.y -= bounds.position.y * factor

func _mesh_bounds(root: Node, parent_transform: Transform3D) -> AABB:
 var transform := parent_transform
 if root is Node3D:
  transform = parent_transform * (root as Node3D).transform
 var result := AABB()
 var found := false
 if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
  var mesh := root as MeshInstance3D
  var local_box := mesh.get_aabb()
  for corner_index in range(8):
   var corner := local_box.position + Vector3(
    local_box.size.x if (corner_index & 1) != 0 else 0.0,
    local_box.size.y if (corner_index & 2) != 0 else 0.0,
    local_box.size.z if (corner_index & 4) != 0 else 0.0)
   var point := transform * corner
   result = AABB(point,Vector3.ZERO) if not found else result.expand(point)
   found = true
 for child in root.get_children():
  var child_box := _mesh_bounds(child,transform)
  if child_box.size.length_squared() > 0.0:
   result = child_box if not found else result.merge(child_box)
   found = true
 return result if found else AABB()

func _add_name_label(npc: Node3D,npc_id: String) -> void:
 var label := Label3D.new()
 label.name = "NPCName"
 label.text = npc_id
 label.position = Vector3(0,3.78,0)
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size = 32
 label.outline_size = 8
 label.no_depth_test = true
 npc.add_child(label)

func _add_interaction_prompt(npc: Node3D,npc_id: String,role_type: String,prompt_text: String) -> void:
 var prompt := Label3D.new()
 prompt.name = "InteractionPrompt"
 prompt.text = prompt_text
 prompt.position = Vector3(0,INTERACTION_HEIGHT,0)
 prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 prompt.font_size = 42
 prompt.outline_size = 10
 prompt.no_depth_test = true
 prompt.scale = Vector3.ONE * 0.72
 npc.add_child(prompt)
 var solid_body := StaticBody3D.new()
 solid_body.name = "NPCSolidBody"
 solid_body.position = Vector3(0,1.4,0)
 solid_body.collision_layer = 1
 solid_body.collision_mask = 1
 solid_body.input_ray_pickable = true
 var solid_shape_node := CollisionShape3D.new()
 solid_shape_node.name = "NPCBodyCapsule"
 var capsule := CapsuleShape3D.new()
 capsule.height = 2.8
 capsule.radius = 0.55
 solid_shape_node.shape = capsule
 solid_body.add_child(solid_shape_node)
 npc.add_child(solid_body)
 solid_body.input_event.connect(_on_npc_input.bind(npc_id,role_type))

 var hit_area := Area3D.new()
 hit_area.name = "InteractionHitArea"
 hit_area.position = Vector3(0,1.4,0)
 hit_area.collision_layer = 0
 hit_area.collision_mask = 1
 hit_area.monitoring = true
 hit_area.monitorable = true
 var proximity_collision := CollisionShape3D.new()
 proximity_collision.name = "NPCProximitySphere"
 var proximity_sphere := SphereShape3D.new()
 proximity_sphere.radius = INTERACTION_RADIUS
 proximity_collision.shape = proximity_sphere
 hit_area.add_child(proximity_collision)
 npc.add_child(hit_area)
 hit_area.body_entered.connect(_on_npc_proximity_entered.bind(npc_id,role_type))
 hit_area.body_exited.connect(_on_npc_proximity_exited.bind(npc_id))

func _on_npc_proximity_entered(body: Node3D,npc_id: String,role_type: String) -> void:
 if not is_instance_valid(body) or not body.is_in_group("player"):
  return
 var npc_value: Variant = _npc_nodes.get(npc_id)
 if is_instance_valid(npc_value):
  var npc := npc_value as Node3D
  if is_instance_valid(npc):
   var prompt_value: Variant = npc.get_node_or_null("InteractionPrompt")
   if is_instance_valid(prompt_value):
    var prompt := prompt_value as Label3D
    if is_instance_valid(prompt): prompt.visible = true
 npc_interacted.emit(npc_id,role_type)
 quest_npc_interacted.emit(npc_id,role_type)
 print("NPC_PROXIMITY_ENTERED: id=",npc_id," role=",role_type," radius=",INTERACTION_RADIUS,"m auto_interaction=true")

func _on_npc_proximity_exited(body: Node3D,npc_id: String) -> void:
 if not is_instance_valid(body) or not body.is_in_group("player"):
  return
 print("NPC_PROXIMITY_EXITED: id=",npc_id)

func _on_npc_input(_camera: Camera3D,event: InputEvent,_position: Vector3,_normal: Vector3,_shape_idx: int,npc_id: String,role_type: String) -> void:
 var pressed := false
 if event is InputEventMouseButton:
  pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
 elif event is InputEventScreenTouch:
  pressed = event.pressed
 if pressed:
  npc_interacted.emit(npc_id,role_type)
  quest_npc_interacted.emit(npc_id,role_type)
  print("NPC_INTERACTED: id=",npc_id," role=",role_type)

func _process(_delta: float) -> void:
 var player_value: Variant = get_tree().get_first_node_in_group("player")
 if not is_instance_valid(player_value):
  return
 var player := player_value as Node3D
 if not is_instance_valid(player):
  return
 for npc_id in _npc_nodes.keys():
  var npc_value: Variant = _npc_nodes.get(npc_id)
  if not is_instance_valid(npc_value):
   _npc_nodes.erase(npc_id)
   continue
  var npc := npc_value as Node3D
  if not is_instance_valid(npc):
   _npc_nodes.erase(npc_id)
   continue
  var prompt_value: Variant = npc.get_node_or_null("InteractionPrompt")
  if not is_instance_valid(prompt_value):
   continue
  var prompt := prompt_value as Label3D
  if not is_instance_valid(prompt):
   continue
  var nearby := player.global_position.distance_to(npc.global_position) <= INTERACTION_RADIUS
  var target_scale := 1.0 if nearby else 0.72
  prompt.scale = prompt.scale.lerp(Vector3.ONE * target_scale,0.18)

func interact(npc_id: String) -> bool:
 if not _npc_nodes.has(npc_id):
  return false
 var definition: Dictionary = get_npc_definition(npc_id)
 if definition.is_empty():
  return false
 npc_interacted.emit(npc_id,String(definition.role))
 quest_npc_interacted.emit(npc_id,String(definition.role))
 return true

func clear_cache() -> void:
 # Drop all references without casting or touching nodes that may already be freed.
 _npc_nodes.clear()
 _city_root = null
 print("NPC_MERCHANT_SYSTEM_CACHE_CLEARED: registry=0 city_root=null")

func get_transport_destinations() -> Array[String]:
 return ["TwinCity","PhoenixCastle","ApeMountain","DesertCity","BirdIsland","Market"]

func conductress_travel(destination_city_id: String, spawn_pos: Vector3 = Vector3.ZERO) -> bool:
 if destination_city_id not in get_transport_destinations():
  return false
 var navigation := get_node_or_null("/root/WorldNavigationSystem")
 if navigation == null:
  return false
 return await navigation.instant_teleport(destination_city_id,spawn_pos)

func use_market_scroll(spawn_pos: Vector3 = Vector3.ZERO) -> bool:
 var navigation := get_node_or_null("/root/WorldNavigationSystem")
 if navigation == null:
  return false
 return await navigation.instant_teleport("Market",spawn_pos)

func _shop_owner_for_id(merchant_id: String) -> String:
 if merchant_id in ["Pharmacist","Blacksmith","Armorer","AccessoryMerchant"]:
  return merchant_id
 if merchant_id == "WeaponMaster":
  return "Blacksmith"
 return ""

func get_item_base_price(item_id: String) -> int:
 var database := get_node_or_null("/root/GearDatabase")
 if database != null and database.has_method("get_item_price"):
  var catalog_price := int(database.get_item_price(item_id))
  if catalog_price > 0:
   return catalog_price
 var definition: Dictionary = database.get_item(item_id) if database != null and database.has_method("get_item") else {}
 for key in ["shop_price","buy_price","price","value"]:
  if definition.has(key) and int(definition[key]) > 0:
   return int(definition[key])
 for merchant_id in SHOP_STOCK:
  for entry in SHOP_STOCK[merchant_id]:
   if String(entry.id) == item_id:
    return int(entry.price)
 if not definition.is_empty():
  var level := int(definition.get("level",definition.get("level_min",1)))
  var plus := int(definition.get("plus",0))
  return maxi(1,100 + level * 20 + plus * 50)
 return 100

func get_shop_inventory(merchant_id: String) -> Array[Dictionary]:
 var owner := _shop_owner_for_id(merchant_id)
 var result: Array[Dictionary] = []
 if owner.is_empty():
  return result
 var database := get_node_or_null("/root/GearDatabase")
 for entry in SHOP_STOCK[owner]:
  var item_id := String(entry.id)
  var definition: Dictionary = database.get_item(item_id) if database != null and database.has_method("get_item") else {}
  var item: Dictionary = definition.duplicate(true) if not definition.is_empty() else {}
  item["id"] = item_id
  item["name"] = String(definition.get("display_name",definition.get("name",entry.name)))
  item["type"] = String(definition.get("type",entry.type))
  item["buy_price"] = get_item_base_price(item_id)
  item["sell_price"] = maxi(1,int(floor(float(item.buy_price) * 0.5)))
  item["merchant_id"] = owner
  result.append(item)
 return result

func buy_item(merchant_id: String, item_id: String, quantity: int = 1) -> Dictionary:
 var owner := _shop_owner_for_id(merchant_id)
 if owner.is_empty() or quantity < 1 or quantity > 100:
  return {"ok":false,"reason":"invalid_shop_or_quantity"}
 var stock := get_shop_inventory(owner)
 var approved := false
 for item in stock:
  if String(item.id) == item_id:
   approved = true
   break
 if not approved:
  return {"ok":false,"reason":"item_not_sold_here"}
 var state := get_node_or_null("/root/GameState")
 if state == null:
  return {"ok":false,"reason":"game_state_unavailable"}
 var unit_price := get_item_base_price(item_id)
 var total := unit_price * quantity
 if int(state.gold) < total:
  return {"ok":false,"reason":"not_enough_gold","required":total}
 if not state.add_item(item_id,quantity):
  return {"ok":false,"reason":"inventory_full"}
 state.set_gold(int(state.gold) - total)
 state.save_game()
 print("MERCHANT_PURCHASE_OK: merchant=",owner," item=",item_id," quantity=",quantity," gold=",total)
 return {"ok":true,"item_id":item_id,"quantity":quantity,"gold_spent":total,"gold_remaining":int(state.gold)}

func sell_item(inventory_slot_index: int, quantity: int = 1) -> Dictionary:
 var state := get_node_or_null("/root/GameState")
 if state == null or inventory_slot_index < 0 or inventory_slot_index >= state.inventory_slots.size() or quantity < 1:
  return {"ok":false,"reason":"invalid_inventory_slot_or_quantity"}
 var slot: Dictionary = state.inventory_slots[inventory_slot_index]
 var item_id := String(slot.get("item_id",""))
 if item_id.is_empty() or quantity > int(slot.get("count",0)):
  return {"ok":false,"reason":"invalid_stack_quantity"}
 var unit_price := maxi(1,int(floor(float(get_item_base_price(item_id)) * 0.5)))
 var total := unit_price * quantity
 if not state.remove_item_from_slot(inventory_slot_index,quantity):
  return {"ok":false,"reason":"could_not_remove_inventory_item"}
 state.add_gold(total)
 state.save_game()
 print("MERCHANT_SALE_OK: slot=",inventory_slot_index," item=",item_id," quantity=",quantity," gold=",total)
 return {"ok":true,"item_id":item_id,"quantity":quantity,"gold_earned":total,"gold_total":int(state.gold)}
