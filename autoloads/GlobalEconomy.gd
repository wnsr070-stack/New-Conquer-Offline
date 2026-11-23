extends Node
signal gold_changed(total: int)
var initialized := false
var gold: int = 0
func _ready() -> void:
 _initialize()
func _initialize() -> void:
 gold = 0
 initialized = true
 print("PHASE3B_GOLD_ONLY_ECONOMY_READY")
func add_gold(amount: int) -> void:
 if amount > 0:
  gold += amount
  gold_changed.emit(gold)
func spend_gold(amount: int) -> bool:
 if amount <= 0 or gold < amount: return false
 gold -= amount
 gold_changed.emit(gold)
 return true
func set_gold(value: int) -> void:
 gold = maxi(0,value)
 gold_changed.emit(gold)
