extends Node
## Equipment visuals policy:
## Armor and headgear remain represented by inventory icons/stats only.
## Weapon meshes are managed by the hero weapon system; set/weapon auras are
## managed by GearSystem through AuraAndVFXManager.

var _hero: Node3D

func _ready() -> void:
 var gear := get_node_or_null("/root/GearSystem")
 if gear != null and gear.has_signal("equipment_changed"):
  gear.equipment_changed.connect(_on_equipment_changed)
 print("PHASE4D_EQUIPMENT_VISUAL_MANAGER_READY: armor_3d=false headgear_3d=false weapon_3d=hero_weapon_system set_aura=GearSystem")

func bind_hero(hero: Node3D) -> void:
 if hero == null or not is_instance_valid(hero):
  return
 _hero = hero
 _remove_legacy_armor_headgear_nodes(_hero)
 print("PHASE4D_EQUIPMENT_HERO_BOUND: hero=",hero.name," armor_headgear_meshes=disabled")

func set_active_class(_class_id: String) -> void:
 pass

func _on_equipment_changed(slot: String, _item: Dictionary) -> void:
 var normalized_slot := "helmet" if slot == "headgear" else slot
 if normalized_slot in ["armor","helmet"]:
  if is_instance_valid(_hero):
   _remove_legacy_armor_headgear_nodes(_hero)
  print("PHASE4D_EQUIPMENT_ICON_STATS_ONLY: slot=",normalized_slot)

func _remove_legacy_armor_headgear_nodes(root: Node) -> void:
 if root == null:
  return
 for node in root.find_children("*","Node",true,false):
  if node is Node3D and (node.name.begins_with("EquipmentSocket_armor") or node.name.begins_with("EquipmentModel_armor") or node.name.begins_with("EquipmentSocket_helmet") or node.name.begins_with("EquipmentModel_helmet")):
   node.queue_free()

func get_visual_model(_slot: String) -> Node3D:
 return null

func get_visual_socket(_slot: String) -> BoneAttachment3D:
 return null

func get_visual_status() -> Dictionary:
 return {}

func clear_cache() -> void:
 _hero = null
 print("PHASE4D_EQUIPMENT_VISUAL_CACHE_CLEARED")
