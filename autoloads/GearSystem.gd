extends Node
signal equipment_changed(slot: String, item: Dictionary)
var initialized := false
var database: Node
var equipped: Dictionary = {}
func _ready() -> void:
 _initialize()
func _initialize() -> void:
 database = get_node_or_null("/root/GearDatabase")
 initialized = database != null and database.initialized
 print("PHASE3B_GEAR_SYSTEM_READY: database_dependency=",initialized)
func equip_weapon(item_id: String, class_id: String) -> bool:
 if database == null: return false
 var item: Dictionary = database.get_item(item_id)
 if item.is_empty() or class_id not in item.classes: return false
 equipped["weapon"] = item
 equipment_changed.emit("weapon",item)
 return true
func get_equipped(slot: String = "weapon") -> Dictionary:
 return equipped.get(slot,{}).duplicate(true)
func can_equip(item_id: String, class_id: String, level: int) -> bool:
 if database == null: return false
 var item: Dictionary = database.get_item(item_id)
 return not item.is_empty() and class_id in item.classes and level >= int(item.level)
