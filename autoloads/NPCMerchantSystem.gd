extends Node
## Runtime NPC placement uses imported Phase 3B humanoid GLB assets only.
signal npc_interacted(npc_id: String, role_type: String)
signal quest_npc_interacted(npc_id: String, role_type: String)

const NPC_DEFINITIONS := [
 {"id":"Blacksmith","role":"shop","position":Vector3(-92,0,86),"model":"warrior_male","prompt":"[Shop]"},
 {"id":"Armorer","role":"shop","position":Vector3(-86,0,86),"model":"trojan_male","prompt":"[Shop]"},
 {"id":"AccessoryMerchant","role":"shop","position":Vector3(-98,0,86),"model":"taoist_male","prompt":"[Shop]"},
 {"id":"Pharmacist","role":"shop","position":Vector3(86,0,92),"model":"taoist_female","prompt":"[Shop]"},
 {"id":"QuestMaster","role":"quest","position":Vector3(-86,0,-92),"model":"warrior_female","prompt":"[!]"},
 {"id":"ArtisanMaster","role":"forge","position":Vector3(86,0,-92),"model":"archer_male","prompt":"[Forge]"},
 {"id":"Warehouseman","role":"warehouse","position":Vector3(-12,0,-12),"model":"trojan_male","prompt":"[Box]"},
 {"id":"Conductress","role":"transport","position":Vector3(12,0,-12),"model":"archer_female","prompt":"[Gate]"},
 {"id":"ImperialEnvoy","role":"story_quest","position":Vector3(0,0,-56),"model":"taoist_male","prompt":"[?]"},
 {"id":"ArcherGod","city":"TwinCity","role":"quest","position":Vector3(-52,0,-48),"model":"archer_male","prompt":"[!]"},
 {"id":"Ming","city":"TwinCity","role":"quest","position":Vector3(24,0,36),"model":"taoist_female","prompt":"[!]"},
 {"id":"LongDong","city":"TwinCity","role":"quest","position":Vector3(-36,0,28),"model":"warrior_male","prompt":"[!]"},
 {"id":"Blacknull","city":"TwinCity","role":"quest","position":Vector3(44,0,-24),"model":"trojan_male","prompt":"[!]"},
 {"id":"F.Chen","city":"TwinCity","role":"quest","position":Vector3(-24,0,-38),"model":"taoist_male","prompt":"[!]"},
 {"id":"Synsia","city":"TwinCity","role":"quest","position":Vector3(38,0,42),"model":"archer_female","prompt":"[!]"},
 {"id":"GemCollector","city":"TwinCity","role":"quest","position":Vector3(-42,0,44),"model":"taoist_male","prompt":"[!]"},
 {"id":"MonsterSlayer","city":"TwinCity","role":"quest","position":Vector3(52,0,18),"model":"warrior_male","prompt":"[!]"},
 {"id":"EventMaster","city":"TwinCity","role":"quest","position":Vector3(-18,0,52),"model":"trojan_female","prompt":"[!]"},
 {"id":"ItemSocketingMaster","city":"TwinCity","role":"quest","position":Vector3(18,0,-52),"model":"warrior_female","prompt":"[!]"},
 {"id":"Celestine","city":"TwinCity","role":"quest","position":Vector3(-62,0,12),"model":"taoist_female","prompt":"[!]"},
 {"id":"RebirthMaster","city":"TwinCity","role":"quest","position":Vector3(62,0,-12),"model":"taoist_male","prompt":"[!]"},
 {"id":"GeneralQing","city":"TwinCity","role":"quest","position":Vector3(28,0,-32),"model":"warrior_male","prompt":"[!]"},
 {"id":"Fortuneteller","city":"TwinCity","role":"quest","position":Vector3(115,0,115),"model":"taoist_female","prompt":"[!]"},
 {"id":"CloudSaint","city":"Market","role":"quest","position":Vector3(-18,0,14),"model":"taoist_male","prompt":"[!]"},
 {"id":"TaoistMoon","city":"Market","role":"quest","position":Vector3(18,0,14),"model":"taoist_female","prompt":"[!]"},
 {"id":"BlessedGreatMaster","city":"Market","role":"quest","position":Vector3(0,0,22),"model":"warrior_male","prompt":"[!]"},
 {"id":"SolarSaint","city":"ApeMountain","role":"quest","position":Vector3(16,0,-18),"model":"taoist_male","prompt":"[!]"},
 {"id":"CelestialTaoist","city":"ApeMountain","role":"quest","position":Vector3(-16,0,-18),"model":"taoist_female","prompt":"[!]"},
 {"id":"CoachLin","city":"PhoenixCastle","role":"quest","position":Vector3(14,0,16),"model":"warrior_male","prompt":"[!]"},
 {"id":"Alchemist","city":"PhoenixCastle","role":"quest","position":Vector3(-14,0,16),"model":"taoist_male","prompt":"[!]"},
]
const CharacterVisualControllerScript = preload("res://scripts/CharacterVisualController.gd")
const INTERACTION_HEIGHT := 3.2
const INTERACTION_RADIUS := 4.5
var _city_root: Node3D
var _npc_nodes: Dictionary = {}

func _ready() -> void:
 var forging := get_node_or_null("/root/ForgingSystem")
 if forging != null and not npc_interacted.is_connected(forging.handle_npc_interaction):
  npc_interacted.connect(forging.handle_npc_interaction)
 print("NPC_MERCHANT_SYSTEM_READY: imported_character_models_only=true")

func _exit_tree() -> void:
 # NPCs parented to the city are released by that scene; only free detached leftovers here.
 for npc_value in _npc_nodes.values():
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
  if city_id != "TwinCity" and String(definition.get("city","TwinCity")) != city_id: continue
  var npc_id := String(definition.id)
  if _npc_nodes.has(npc_id) and is_instance_valid(_npc_nodes[npc_id]):
   continue
  # Use the same imported-character construction path as CharacterVisualController.
  # The Phase 4D workflow restores this exact approved source as Male_Ranger.glb.
  var npc := Node3D.new()
  npc.name = "NPC_"+npc_id
  npc.set_meta("npc_id",npc_id)
  npc.set_meta("role_type",String(definition.role))
  npc.position = definition.position
  city_root.add_child(npc)
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
  _fit_character_height(character,1.8)
  _add_name_label(npc,npc_id)
  _add_interaction_prompt(npc,npc_id,String(definition.role),String(definition.prompt))
  _npc_nodes[npc_id] = npc
  spawned_count += 1
  print("PHASE4D_QUEST_NPC_SPAWNED: id=",npc_id," role=",definition.role," pos=",definition.position," source=res://assets/phase3b/characters/Male_Ranger.glb")
 print("PHASE4D_CITY_NPC_REGISTRY_READY: spawned=",spawned_count," requested=",NPC_DEFINITIONS.size()," city=",city_id)
 if city_id == "TwinCity":
  print("PHASE4D_NPC_OVERHEAD_PROMPTS_READY: spawned=",spawned_count," height=",INTERACTION_HEIGHT,"m")

func _resolve_city_id(root: Node3D) -> String:
 var value := root.name.to_lower().replace("_","").replace(" ","")
 if value.contains("market"): return "Market"
 if value.contains("ape"): return "ApeMountain"
 if value.contains("phoenix"): return "PhoenixCastle"
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
 label.position = Vector3(0,2.05,0)
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
 var hit_area := Area3D.new()
 hit_area.name = "InteractionHitArea"
 hit_area.position = Vector3(0,1.5,0)
 hit_area.input_ray_pickable = true
 var collision := CollisionShape3D.new()
 var sphere := SphereShape3D.new()
 sphere.radius = 1.15
 collision.shape = sphere
 hit_area.add_child(collision)
 npc.add_child(hit_area)
 hit_area.input_event.connect(_on_npc_input.bind(npc_id,role_type))

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
 var player := get_tree().get_first_node_in_group("player") as Node3D
 if player == null:
  return
 for npc_id in _npc_nodes:
  var npc := _npc_nodes[npc_id] as Node3D
  if not is_instance_valid(npc):
   continue
  var prompt := npc.get_node_or_null("InteractionPrompt") as Label3D
  if prompt == null:
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
 _npc_nodes.clear()
 _city_root = null
 print("NPC_MERCHANT_SYSTEM_CACHE_CLEARED")

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
