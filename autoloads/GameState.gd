extends Node
signal state_loaded
const SAVE_VERSION := 6
const SAVE_PATH := "user://conquer_save_v6.cfg"
var initialized := false
var current_zone: String = "boot_test"
var player_data: Dictionary = {}
var gold: int = 0
func _ready() -> void:
 _initialize()
func _initialize() -> void:
 _load_save()
 var economy := get_node_or_null("/root/GlobalEconomy")
 if economy != null:
  economy.set_gold(gold)
 initialized = true
 state_loaded.emit()
 print("PHASE3B_GAMESTATE_SAVE_V6_READY: gold_only_currency=true")
func _load_save() -> void:
 var config := ConfigFile.new()
 if config.load(SAVE_PATH) != OK:
  player_data = {"class":"archer","level":1,"equipped":{}}
  gold = 0
  return
 var version := int(config.get_value("meta","version",0))
 if version > SAVE_VERSION:
  push_warning("Save is newer than supported; starting safe defaults")
  player_data = {"class":"archer","level":1,"equipped":{}}
  gold = 0
  return
 player_data = config.get_value("player","data",{"class":"archer","level":1,"equipped":{}})
 gold = maxi(0,int(config.get_value("economy","gold",0)))
func save_game() -> bool:
 var config := ConfigFile.new()
 config.set_value("meta","version",SAVE_VERSION)
 config.set_value("player","data",player_data)
 config.set_value("economy","gold",gold)
 return config.save(SAVE_PATH) == OK
func set_gold(value: int) -> void:
 gold = maxi(0,value)
 var economy := get_node_or_null("/root/GlobalEconomy")
 if economy != null: economy.set_gold(gold)
