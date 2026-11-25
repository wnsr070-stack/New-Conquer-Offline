extends Node
signal state_loaded
signal xp_changed(value: float, ready: bool)
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
func save_game() -> bool:
 player_data["exp"] = exp
 player_data["anima_phase"] = anima_phase
 player_data["inventory"] = inventory.duplicate(true)
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
 if item_id.is_empty() or amount <= 0: return
 inventory[item_id] = int(inventory.get(item_id,0))+amount
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
