extends Node
signal equipment_changed(slot: String,item: Dictionary)
const MAX_STACK := 100
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
 var normalized_slot := "helmet" if slot == "headgear" else slot
 if normalized_slot.is_empty() or item.is_empty(): return false
 equipped[normalized_slot] = item.duplicate(true)
 _persist_equipment()
 equipment_changed.emit(normalized_slot,equipped[normalized_slot])
 _apply_runtime_aura()
 return true

func unequip_item(slot: String) -> bool:
 var normalized_slot := "helmet" if slot == "headgear" else slot
 if not equipped.has(normalized_slot): return false
 equipped.erase(normalized_slot)
 _persist_equipment()
 equipment_changed.emit(normalized_slot,{})
 _apply_runtime_aura()
 return true
func update_equipped_item(slot: String,item: Dictionary) -> void:
 var normalized_slot := "helmet" if slot == "headgear" else slot
 if not equipped.has(normalized_slot): return
 equipped[normalized_slot] = item.duplicate(true)
 _persist_equipment()
 equipment_changed.emit(normalized_slot,equipped[normalized_slot])
 _apply_runtime_aura()
func get_equipped(slot: String = "weapon") -> Dictionary:
 var normalized_slot := "helmet" if slot == "headgear" else slot
 return equipped.get(normalized_slot,{}).duplicate(true)
func can_equip(item_id: String,class_id: String,level: int) -> bool:
 if database == null: return false
 var item: Dictionary = database.get_item(item_id)
 return not item.is_empty() and class_id in item.classes and level >= int(item.level)
func get_combat_bonuses() -> Dictionary:
 var attack := 0
 var defense := 0
 var max_hp := 0
 var critical := 0.0
 var movement_speed := 0.0
 var magic_attack := 0
 var damage_reduction := 0.0
 var exp_bonus := 0.0
 var attack_pct := 0.0
 var magic_attack_pct := 0.0
 var hit_accuracy_pct := 0.0
 var weapon_exp_bonus := 0.0
 var magic_exp_bonus := 0.0
 var durability_bonus := 0.0
 for item in equipped.values():
  attack += int(item.get("attack_bonus",0))
  defense += int(item.get("defense_bonus",0))
  max_hp += int(item.get("max_hp_bonus",0))
  critical += float(item.get("critical",0.0))
  movement_speed += float(item.get("movement_speed_bonus",0.0))
  var gems: Dictionary = item.get("gem_bonuses",{})
  magic_attack += int(gems.get("magic_attack",0))
  attack += int(gems.get("attack",0))
  attack_pct += float(gems.get("attack_pct",0.0))
  magic_attack_pct += float(gems.get("magic_attack_pct",0.0))
  attack += int(round(float(item.get("attack_bonus",0)) * float(gems.get("attack_pct",0.0))))
  magic_attack += int(round(float(item.get("magic_attack",0)) * float(gems.get("magic_attack_pct",0.0))))
  damage_reduction += float(gems.get("damage_reduction",0.0))
  exp_bonus += float(gems.get("exp_bonus",0.0))
  hit_accuracy_pct += float(gems.get("hit_accuracy_pct",0.0))
  weapon_exp_bonus += float(gems.get("weapon_exp_bonus",0.0))
  magic_exp_bonus += float(gems.get("magic_exp_bonus",0.0))
  durability_bonus += float(gems.get("durability_bonus",0.0))
 return {"attack":attack,"defense":defense,"max_hp":max_hp,"critical":critical,"movement_speed":movement_speed,"magic_attack":magic_attack,"attack_pct":attack_pct,"magic_attack_pct":magic_attack_pct,"damage_reduction":damage_reduction,"exp_bonus":exp_bonus,"hit_accuracy_pct":hit_accuracy_pct,"weapon_exp_bonus":weapon_exp_bonus,"magic_exp_bonus":magic_exp_bonus,"durability_bonus":durability_bonus}
func _persist_equipment() -> void:
 var state := get_node_or_null("/root/GameState")
 if state != null:
  state.player_data["equipped"] = equipped.duplicate(true)
  state.save_game()
func _apply_runtime_aura() -> void:
 var hero := get_tree().root.find_child("PlayableHero",true,false)
 if not hero is Node3D: hero = get_tree().root.find_child("TwinCityPlayableHero",true,false)
 if not hero is Node3D: return
 var vfx := get_node_or_null("/root/AuraAndVFXManager")
 if vfx == null: return
 var weapon_nodes: Array = hero.get("weapon_nodes") if hero.get("weapon_nodes") is Array else []
 var weapon: Dictionary = equipped.get("weapon",{})
 for socket in weapon_nodes:
  if not is_instance_valid(socket) or not socket is Node3D: continue
  var mesh_root := socket.get_child(0) as Node3D if socket.get_child_count()>0 else socket as Node3D
  if mesh_root != null: vfx.attach_equipment_aura(mesh_root,int(weapon.get("plus",0)),true)
 var min_set_plus := 13
 var set_count := 0
 for slot in equipped:
  var item: Dictionary = equipped[slot]
  if String(slot) in ["weapon","armor","helmet","necklace","ring","boots","fan","tower"]:
   min_set_plus = mini(min_set_plus,int(item.get("plus",0)))
   set_count += 1
 if set_count == 0: min_set_plus = 0
 var state := get_node_or_null("/root/GameState")
 var xp_active := state != null and float(state.xp_ready_time_left)>0.0
 vfx.attach_character_aura(hero,min_set_plus,xp_active)
 if state != null: vfx.attach_anima_aura(hero,int(state.anima_phase))

func clear_cache() -> void:
 equipped.clear()
 database = null
 initialized = false
 print("PHASE4D_GEAR_SYSTEM_CACHE_CLEARED")

func add_item(item_id: String, amount: int = 1, instance_data: Dictionary = {}) -> bool:
 var state := get_node_or_null("/root/GameState")
 return state != null and state.add_item(item_id,amount,instance_data)
func remove_item(item_id: String, amount: int = 1) -> bool:
 var state := get_node_or_null("/root/GameState")
 return state != null and state.remove_item(item_id,amount)
func get_item_count(item_id: String) -> int:
 var state := get_node_or_null("/root/GameState")
 return state.get_item_count(item_id) if state != null else 0
