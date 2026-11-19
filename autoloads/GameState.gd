extends Node
var initialized := false
var current_zone: String = "boot_test"
var player_data: Dictionary = {}
func _ready() -> void:
	call_deferred("_initialize")
func _initialize() -> void:
	player_data = {}
	current_zone = "boot_test"
	initialized = true
