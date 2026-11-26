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
 {"id":"ImperialEnvoy","role":"story_quest","position":Vector3(0,0,-56),"model":"taoist_male","prompt":"[?]"}
]
const CHARACTER_ROOT := "res://assets/phase3b/characters/"
const INTERACTION_HEIGHT := 3.2
const INTERACTION_RADIUS := 4.5
var _city_root: Node3D
var _npc_nodes: Dictionary = {}

func _ready() -> void:
 var forging := get_node_or_null("/root/ForgingSystem")
 if forging != null and not npc_interacted.is_connected(forging.handle_npc_interaction):
  npc_interacted.connect(forging.handle_npc_interaction)
 print("NPC_MERCHANT_SYSTEM_READY: imported_character_models_only=true")

func spawn_city_npcs(city_root: Node3D) -> void:
 if city_root == null or not is_instance_valid(city_root):
  return
 _city_root = city_root
 for definition in NPC_DEFINITIONS:
  var npc_id := String(definition.id)
  if _npc_nodes.has(npc_id) and is_instance_valid(_npc_nodes[npc_id]):
   continue
  var character_path := CHARACTER_ROOT + String(definition.model) + ".glb"
  if not ResourceLoader.exists(character_path):
   push_warning("NPC_IMPORTED_CHARACTER_ASSET_MISSING: "+npc_id+" path="+character_path)
   continue
  var packed := load(character_path) as PackedScene
  if packed == null:
   push_warning("NPC_IMPORTED_CHARACTER_SCENE_INVALID: "+character_path)
   continue
  var npc := Node3D.new()
  npc.name = "NPC_"+npc_id
  npc.set_meta("npc_id",npc_id)
  npc.set_meta("role_type",String(definition.role))
  npc.position = definition.position
  city_root.add_child(npc)
  var character := packed.instantiate() as Node3D
  if character == null:
   npc.queue_free()
   continue
  character.name = "ImportedCharacter"
  npc.add_child(character)
  _fit_character_height(character,1.8)
  _add_name_label(npc,npc_id)
  _add_interaction_prompt(npc,npc_id,String(definition.role),String(definition.prompt))
  _npc_nodes[npc_id] = npc
  print("TWIN_CITY_NPC_SPAWNED: id=",npc_id," role=",definition.role," pos=",definition.position," source=",character_path)
 print("TWIN_CITY_NPC_REGISTRY_READY: spawned=",_npc_nodes.size()," requested=",NPC_DEFINITIONS.size())

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
 var definition: Dictionary = {}
 for entry in NPC_DEFINITIONS:
  if String(entry.id) == npc_id:
   definition = entry
   break
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
