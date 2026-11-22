extends Node
var initialized := false
var class_definitions: Dictionary = {}
func _ready() -> void:
	call_deferred("_initialize")
func _initialize() -> void:
	class_definitions = {"warrior": {"display_name": "Warrior"}, "trojan": {"display_name": "Trojan"}, "archer": {"display_name": "Archer"}}
	initialized = true
