extends Node
var initialized := false
var items: Dictionary = {}
func _ready() -> void:
	call_deferred("_initialize")
func _initialize() -> void:
	items = {}
	initialized = true
func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})
