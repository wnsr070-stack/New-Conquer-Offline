extends Node
var initialized := false
var database: Node
func _ready() -> void:
	call_deferred("_initialize")
func _initialize() -> void:
	database = get_node_or_null("/root/GearDatabase")
	initialized = database != null
func resolve_item(item_id: String) -> Dictionary:
	if database == null:
		return {}
	return database.get_item(item_id)
