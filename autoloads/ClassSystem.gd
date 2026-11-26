extends Node
signal class_changed(class_id: String)
const CLASS_DATA := {
 "archer":{"name":"Archer","weapon":"bow","skills":["scatter","rapid_fire"],"level":1},
 "oriental_assassin":{"name":"Oriental Assassin","weapon":"dual_daggers","skills":["path_of_shadow","bladed_flurry"],"level":40,"unlock_from":"archer"},
 "trojan":{"name":"Trojan","weapon":"dual_blades","skills":["kinetic_spark","bladed_flurry"],"level":1},
 "warrior":{"name":"Warrior","weapon":"spear","skills":["kinetic_spark"],"level":1},
 "taoist":{"name":"Taoist","weapon":"magic_staff","skills":["kinetic_spark"],"level":1},
 "ninja":{"name":"Ninja","weapon":"katana_shuriken","skills":["path_of_shadow","bladed_flurry"],"level":1},
 "monk":{"name":"Monk","weapon":"staff","skills":["kinetic_spark","bladed_flurry"],"level":1}
}
const SKILLS := {
 "scatter":{"name":"Scatter","class":"archer","cooldown":4.0,"description":"Fan of arrows"},
 "rapid_fire":{"name":"Rapid Fire","class":"archer","cooldown":2.0,"description":"Rapid ranged volley"},
 "path_of_shadow":{"name":"Path of Shadow","class":"oriental_assassin","cooldown":12.0,"duration":5.0,"description":"Become a spectral shadow"},
 "kinetic_spark":{"name":"Kinetic Spark","class":"warrior","cooldown":6.0,"description":"Charged weapon burst"},
 "bladed_flurry":{"name":"Bladed Flurry","class":"oriental_assassin","cooldown":7.0,"description":"Fast dual blade combo"}
}
var initialized := false
var active_class := "archer"
var player_level := 1
func _ready() -> void:
 _initialize()
func _initialize() -> void:
 initialized = true
 print("PHASE3B_CLASS_SYSTEM_READY: 7 classes; Assassin unlock at Archer Lv40")
func get_available_classes(level: int = player_level) -> Array[String]:
 var result: Array[String] = []
 for class_id in CLASS_DATA:
  if int(CLASS_DATA[class_id].get("level",1)) <= level: result.append(class_id)
 return result
func unlock_class(class_id: String, level: int) -> bool:
 if not CLASS_DATA.has(class_id): return false
 if class_id == "oriental_assassin" and level < 40: return false
 return true
func select_class(class_id: String, level: int) -> bool:
 if not unlock_class(class_id,level): return false
 active_class = class_id
 player_level = level
 class_changed.emit(class_id)
 return true
func get_class_data(class_id: String = active_class) -> Dictionary:
 return CLASS_DATA.get(class_id,{}).duplicate(true)
func get_skill(skill_id: String) -> Dictionary:
 return SKILLS.get(skill_id,{}).duplicate(true)
func has_skill(class_id: String, skill_id: String) -> bool:
 return CLASS_DATA.has(class_id) and skill_id in CLASS_DATA[class_id].skills

func apply_rebirth(class_id: String, new_level: int, preserved_skills: Dictionary) -> void:
 active_class = class_id if CLASS_DATA.has(class_id) else "archer"
 player_level = new_level
 var state := get_node_or_null("/root/GameState")
 if state != null:
  state.player_data["class"] = active_class
  state.player_data["level"] = new_level
  state.player_data["unlocked_skills"] = preserved_skills.duplicate(true)
 class_changed.emit(active_class)
