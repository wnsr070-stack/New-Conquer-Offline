extends Node
var initialized := false
var gold: int = 0
func _ready() -> void:
	call_deferred("_initialize")
func _initialize() -> void:
	gold = 0
	initialized = true
func add_gold(amount: int) -> void:
	if amount > 0:
		gold += amount
