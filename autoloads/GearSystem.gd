extends Node
signal equipment_changed(slot: String,item: Dictionary)
var initialized := false
var database: Node
var equipped: Dictionary = {}
func _ready() -> void:
 _initialize()
func _initialize() -> void:
 database = get_node_or_null("/root/GearDatabase")
 var state := get_node_or_null("/root/GameState")
 if state != null: equipped = state.player_data.get("equipped",{}).duplicate(true)
 initialized = database != null and database.initialized
 print("PHASE3B_GEAR_SYSTEM_READY: database_dependency=",initialized)
func equip_weapon(item_id: String,class_id: String) -> bool:
 if database == null: return false
 var item: Dictionary = database.get_item(item_id)
 if item.is_empty() or class_id not in item.classes: return false
 item["plus"] = 0
 item["composition_points"] = 0
 item["quality"] = "Normal"
 item["base_attack"] = int(item.get("base_attack",80))
 item["attack_bonus"] = item["base_attack"]
 item["defense_bonus"] = 0
 item["sockets"] = []
 item["gem_bonuses"] = {"attack":0,"magic_attack":0,"damage_reduction":0.0,"exp_bonus":0.0}
 equipped["weapon"] = item
 _persist_equipment()
 equipment_changed.emit("weapon",item)
 _apply_runtime_aura()
 return true
func equip_item(slot: String,item: Dictionary) -> bool:
 if slot.is_empty() or item.is_empty(): return false
 equipped[slot] = item.duplicate(true)
 _persist_equipment()
 equipment_changed.emit(slot,equipped[slot])
 _apply_runtime_aura()
 return true
func update_equipped_item(slot: String,item: Dictionary) -> void:
 if not equipped.has(slot): return
 equipped[slot] = item.duplicate(true)
 _persist_equipment()
 equipment_changed.emit(slot,equipped[slot])
 _apply_runtime_aura()
func get_equipped(slot: String = "weapon") -> Dictionary:
 return equipped.get(slot,{}).duplicate(true)
func can_equip(item_id: String,class_id: String,level: int) -> bool:
 if database == null: return false
 var item: Dictionary = database.get_item(item_id)
 return not item.is_empty() and class_id in item.classes and level >= int(item.level)
func get_combat_bonuses() -> Dictionary:
 var attack := 0
 var defense := 0
 var magic_attack := 0
 var damage_reduction := 0.0
 var exp_bonus := 0.0
 for item in equipped.values():
  attack += int(item.get("attack_bonus",0))
  defense += int(item.get("defense_bonus",0))
  var gems: Dictionary = item.get("gem_bonuses",{})
  magic_attack += int(gems.get("magic_attack",0))
  attack += int(gems.get("attack",0))
  damage_reduction += float(gems.get("damage_reduction",0.0))
  exp_bonus += float(gems.get("exp_bonus",0.0))
 return {"attack":attack,"defense":defense,"magic_attack":magic_attack,"damage_reduction":damage_reduction,"exp_bonus":exp_bonus}
func _persist_equipment() -> void:
 var state := get_node_or_null("/root/GameState")
 if state != null:
  state.player_data["equipped"] = equipped.duplicate(true)
  state.save_game()
func _apply_runtime_aura() -> void:
 var hero := get_tree().root.find_child("PlayableHero",true,false)
 if not hero is Node3D: hero = get_tree().root.find_child("TwinCityPlayableHero",true,false)
 var forging := get_node_or_null("/root/ForgingSystem")
 if forging != null and hero is Node3D: forging.apply_equipped_weapon_aura(hero)
