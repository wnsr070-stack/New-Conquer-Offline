extends Node
# Phase 4D: 40-slot inventory with legacy dictionary mirroring and 100-item stacks.
signal state_loaded
signal xp_changed(value: float, ready: bool)
signal inventory_changed(item_id: String, total_count: int)
const MAX_STACK := 100
const MAX_INVENTORY_SLOTS := 40
var inventory_slots: Array[Dictionary] = []
const SAVE_VERSION := 7
const SAVE_PATH := "user://conquer_save_v6.cfg"
var initialized := false
var current_zone: String = "boot_test"
var player_data: Dictionary = {}
var gold: int = 0
var exp: int = 0
var xp: float = 0.0
var xp_ready_time_left: float = 0.0
var inventory: Dictionary = {}
var anima_phase: int = 0
var weapon_proficiency: Dictionary = {}
var skill_proficiency: Dictionary = {}
func _ready() -> void: _initialize()
func _initialize() -> void:
 _load_save()
 var economy := get_node_or_null("/root/GlobalEconomy")
 if economy != null: economy.set_gold(gold)
 initialized = true
 state_loaded.emit()
 print("PHASE3B_GAMESTATE_SAVE_V6_READY: gold_only_currency=true")
func _load_save() -> void:
 var config := ConfigFile.new()
 if config.load(SAVE_PATH) != OK:
  player_data = {"class":"archer","level":1,"equipped":{},"exp":0,"inventory":{},"mana":100,"stamina":100}
  gold = 0
  exp = 0
  inventory = {}
  anima_phase = 0
  return
 var version := int(config.get_value("meta","version",0))
 if version > SAVE_VERSION:
  push_warning("Save is newer than supported; starting safe defaults")
  player_data = {"class":"archer","level":1,"equipped":{},"exp":0,"inventory":{},"mana":100,"stamina":100}
  gold = 0
  exp = 0
  inventory = {}
  anima_phase = 0
  return
 player_data = config.get_value("player","data",{"class":"archer","level":1,"equipped":{}})
 anima_phase = clampi(int(player_data.get("anima_phase",0)),0,18)
 player_data["mana"] = int(player_data.get("mana",100))
 player_data["stamina"] = int(player_data.get("stamina",100))
 gold = maxi(0,int(config.get_value("economy","gold",0)))
 exp = maxi(0,int(player_data.get("exp",0)))
 inventory = player_data.get("inventory",{}).duplicate(true)
 inventory_slots = []
 var saved_slots: Variant = player_data.get("inventory_slots", [])
 if saved_slots is Array and not saved_slots.is_empty():
  for slot in saved_slots:
   if inventory_slots.size() >= MAX_INVENTORY_SLOTS: break
   if slot is Dictionary and not String(slot.get("item_id","")).is_empty() and int(slot.get("count",0)) > 0:
    inventory_slots.append({"item_id":String(slot.item_id),"count":mini(MAX_STACK,int(slot.count)),"instance_data":slot.get("instance_data",{}).duplicate(true)})
 else:
  _migrate_legacy_inventory(inventory)
 _sync_legacy_inventory()
 weapon_proficiency = player_data.get("weapon_proficiency",{}).duplicate(true)
 skill_proficiency = player_data.get("skill_proficiency",{}).duplicate(true)
func save_game() -> bool:
 player_data["exp"] = exp
 player_data["anima_phase"] = anima_phase
 _sync_legacy_inventory()
 player_data["inventory_slots"] = inventory_slots.duplicate(true)
 player_data["inventory"] = inventory.duplicate(true)
 player_data["weapon_proficiency"] = weapon_proficiency.duplicate(true)
 player_data["skill_proficiency"] = skill_proficiency.duplicate(true)
 var config := ConfigFile.new()
 config.set_value("meta","version",SAVE_VERSION)
 config.set_value("player","data",player_data)
 config.set_value("economy","gold",gold)
 return config.save(SAVE_PATH) == OK
func set_gold(value: int) -> void:
 gold = maxi(0,value)
 var economy := get_node_or_null("/root/GlobalEconomy")
 if economy != null: economy.set_gold(gold)
func add_gold(amount: int) -> void:
 if amount > 0: set_gold(gold+amount)
func add_exp(amount: int) -> void:
 if amount <= 0: return
 exp += amount
 player_data["exp"] = exp
func add_inventory_item(item_id: String,amount: int = 1) -> void:
 add_item(item_id, amount)
func add_item(item_id: String, amount: int = 1, instance_data: Dictionary = {}) -> bool:
 if item_id.is_empty() or amount <= 0: return false
 var remaining := amount
 var stackable := _is_stackable_item(item_id)
 if stackable:
  for slot in inventory_slots:
   if String(slot.item_id) == item_id and int(slot.count) < MAX_STACK:
    remaining -= mini(remaining, MAX_STACK - int(slot.count))
    if remaining <= 0: break
 var slots_needed := int(ceil(float(remaining) / float(MAX_STACK))) if stackable else remaining
 if inventory_slots.size() + slots_needed > MAX_INVENTORY_SLOTS: return false
 remaining = amount
 if stackable:
  for slot in inventory_slots:
   if String(slot.item_id) == item_id and int(slot.count) < MAX_STACK:
    var moved := mini(remaining, MAX_STACK - int(slot.count))
    slot.count = int(slot.count) + moved
    remaining -= moved
    if remaining <= 0: break
 while remaining > 0:
  var moved := mini(remaining, MAX_STACK) if stackable else 1
  inventory_slots.append({"item_id":item_id,"count":moved,"instance_data":instance_data.duplicate(true)})
  remaining -= moved
 _sync_legacy_inventory()
 inventory_changed.emit(item_id, get_item_count(item_id))
 player_data["inventory_slots"] = inventory_slots.duplicate(true)
 player_data["inventory"] = inventory.duplicate(true)
 return remaining == 0
func remove_item(item_id: String, amount: int = 1) -> bool:
 if item_id.is_empty() or amount <= 0 or get_item_count(item_id) < amount: return false
 var remaining := amount
 for i in range(inventory_slots.size() - 1, -1, -1):
  if String(inventory_slots[i].item_id) != item_id: continue
  var taken := mini(remaining, int(inventory_slots[i].count))
  inventory_slots[i].count = int(inventory_slots[i].count) - taken
  remaining -= taken
  if int(inventory_slots[i].count) <= 0: inventory_slots.remove_at(i)
  if remaining <= 0: break
 _sync_legacy_inventory()
 inventory_changed.emit(item_id, get_item_count(item_id))
 player_data["inventory_slots"] = inventory_slots.duplicate(true)
 player_data["inventory"] = inventory.duplicate(true)
 return remaining == 0
func get_item_count(item_id: String) -> int:
 var total := 0
 for slot in inventory_slots:
  if String(slot.get("item_id","")) == item_id: total += int(slot.get("count",0))
 return total
func _is_stackable_item(item_id: String) -> bool:
 var normalized := item_id.to_lower().replace("_","").replace(" ","")
 var equipment_tokens := ["weapon","sword","bow","dagger","armor","coat","helmet","hat","ring","necklace","boots","accessory","talisman","fan","tower","shield"]
 for token in equipment_tokens:
  if normalized.contains(token): return false
 var db := get_node_or_null("/root/GearDatabase")
 if db != null and db.has_method("get_item"):
  var definition: Dictionary = db.get_item(item_id)
  var family := String(definition.get("family","")).to_lower()
  if family != "quest_item" and (definition.has("model_keys") or definition.has("model_path") or definition.has("asset_path") or definition.has("equipment_type")): return false
 return true
func _migrate_legacy_inventory(legacy: Dictionary) -> void:
 inventory_slots.clear()
 for id in legacy:
  var remaining := maxi(0,int(legacy[id]))
  while remaining > 0 and inventory_slots.size() < MAX_INVENTORY_SLOTS:
   var amount := mini(remaining,MAX_STACK) if _is_stackable_item(String(id)) else 1
   inventory_slots.append({"item_id":String(id),"count":amount,"instance_data":{}})
   remaining -= amount
func _sync_legacy_inventory() -> void:
 inventory.clear()
 for slot in inventory_slots:
  var id := String(slot.get("item_id",""))
  if not id.is_empty(): inventory[id] = int(inventory.get(id,0)) + int(slot.get("count",0))
 player_data["inventory"] = inventory.duplicate(true)
func add_xp(amount: float) -> void:
 if amount <= 0.0 or xp_ready_time_left > 0.0: return
 xp = minf(100.0,xp+amount)
 if xp >= 100.0:
  xp = 100.0
  xp_ready_time_left = 20.0
  print("XP_READY: duration=20s")
  _refresh_character_aura()
 xp_changed.emit(xp,xp_ready_time_left>0.0)
func consume_xp_ready() -> bool:
 if xp_ready_time_left <= 0.0 or xp < 100.0: return false
 xp = 0.0
 xp_ready_time_left = 0.0
 xp_changed.emit(xp,false)
 _refresh_character_aura()
 return true
func tick_xp(delta: float) -> void:
 if xp_ready_time_left > 0.0:
  xp_ready_time_left = maxf(0.0,xp_ready_time_left-delta)
  if xp_ready_time_left <= 0.0:
   xp = 0.0
   xp_changed.emit(xp,false)
   _refresh_character_aura()
 else: xp_changed.emit(xp,false)

func set_anima_phase(value: int) -> void:
 anima_phase = clampi(value,0,18)
 player_data["anima_phase"] = anima_phase
 save_game()
 var hero := get_tree().root.find_child("PlayableHero",true,false)
 if not hero is Node3D: hero = get_tree().root.find_child("TwinCityPlayableHero",true,false)
 var vfx := get_node_or_null("/root/AuraAndVFXManager")
 if vfx != null and hero is Node3D: vfx.attach_anima_aura(hero,anima_phase)

func get_anima_bonuses() -> Dictionary:
 var phase := clampi(anima_phase,0,18)
 return {
  "attack_multiplier":1.0+float(phase)*0.015,
  "defense_bonus":phase*3,
  "hp_multiplier":1.0+float(phase)*0.025
 }

func _refresh_character_aura() -> void:
 var gear := get_node_or_null("/root/GearSystem")
 if gear != null and gear.has_method("_apply_runtime_aura"):
  gear.call("_apply_runtime_aura")

func add_weapon_proficiency(id: String, amount: float = 1.0) -> float:
 if id.is_empty() or amount <= 0.0: return 0.0
 var gained := amount * get_proficiency_gem_multiplier("weapon")
 weapon_proficiency[id] = float(weapon_proficiency.get(id,0.0))+gained
 save_game()
 return gained
func add_skill_proficiency(id: String, amount: float = 1.0) -> float:
 if id.is_empty() or amount <= 0.0: return 0.0
 var gained := amount * get_proficiency_gem_multiplier("skill")
 skill_proficiency[id] = float(skill_proficiency.get(id,0.0))+gained
 save_game()
 return gained
func get_proficiency_gem_multiplier(kind: String) -> float:
 var result := 1.0
 var gear := get_node_or_null("/root/GearSystem")
 if gear == null: return result
 for item in gear.equipped.values():
  for socket in item.get("sockets",[]):
   var gem := String(socket.get("gem_id",socket.get("id",""))) if socket is Dictionary else String(socket)
   var quality := String(socket.get("quality",item.get("quality","Normal"))) if socket is Dictionary else String(item.get("quality","Normal"))
   if kind=="weapon" and gem.to_lower().contains("violet"):
    result += 0.30 if quality=="Normal" else 0.50 if quality=="Refined" else 1.0 if quality=="Super" else 0.0
   elif kind=="skill" and gem.to_lower().contains("moon"):
    result += 0.15 if quality=="Normal" else 0.30 if quality=="Refined" else 0.50 if quality=="Super" else 0.0
 return result

# Final Phase 4D quest signal parser-compatibility gate.
