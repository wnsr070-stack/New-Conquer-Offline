extends Node
## Data-driven quests and seven-day login rewards. Only verified world targets are navigable.
signal daily_login_claimed(day_index: int, rewards: Dictionary)
signal quest_accepted(quest_id: String)
signal quest_progressed(quest_id: String, progress: int, required: int)
signal quest_completed(quest_id: String)
signal quest_navigation_started(quest_id: String, city_id: String, target_id: String)

const MAIN_PROMOTION := "MAIN_PROMOTION"
const DAILY := "DAILY"
const SIDE_QUESTS := "SIDE_QUESTS"
const ENDGAME_REBIRTH := "ENDGAME_REBIRTH"

# Target positions are included only where the live WorldNavigationSystem has verified coordinates.
const QUEST_CATALOG := {
 "tc_starting_tour":{"category":MAIN_PROMOTION,"title":"Twin City Starting Tour","level_min":1,"level_max":15,"npc_id":"QuestMaster","target_city":"TwinCity","npc_position":Vector3(-86,0,-92),"monster_camp_position":Vector3.ZERO,"objective":"visit_merchants","required":4,"rewards":{"gold":500,"items":{"HPPotion":5,"MPPotion":5}}},
 "promotion_15":{"category":MAIN_PROMOTION,"title":"Archer Promotion — Level 15","level_min":15,"npc_id":"","target_city":"TwinCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"promotion_15","required":1,"rewards":{"items":{"DeerskinCoat":1,"Fly":1}}},
 "promotion_40":{"category":MAIN_PROMOTION,"title":"Archer Promotion — Level 40","level_min":40,"npc_id":"","target_city":"TwinCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"collect_euxenite_ore","required":5,"rewards":{"items":{"UniqueBow":1}}},
 "promotion_70":{"category":MAIN_PROMOTION,"title":"Archer Promotion — Level 70","level_min":70,"npc_id":"","target_city":"TwinCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"collect_emerald","required":1,"rewards":{"items":{"ArrowRain":1}}},
 "promotion_100":{"category":MAIN_PROMOTION,"title":"Archer Promotion — Level 100","level_min":100,"npc_id":"","target_city":"TwinCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"collect_meteor","required":1,"rewards":{"items":{"RainbowGem":1}}},
 "promotion_110":{"category":MAIN_PROMOTION,"title":"Archer Promotion — Level 110","level_min":110,"npc_id":"","target_city":"TwinCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"collect_moon_box","required":1,"rewards":{"items":{"DragonBall":1}}},
 "demon_exterminators":{"category":DAILY,"title":"Demon Exterminators","level_min":1,"npc_id":"","target_city":"Market","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"kill_any","required":30,"rewards":{"exp":50000,"items":{"Meteor":1}}},
 "dis_city":{"category":DAILY,"title":"Dis City Invasion","level_min":1,"npc_id":"","target_city":"Market","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"kill_boss","required":3,"rewards":{"exp":150000,"items":{"Meteor":2,"Plus1Stone":1}}},
 "daily_patrol":{"category":DAILY,"title":"Daily Patrol","level_min":1,"npc_id":"","target_city":"TwinCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"kill_elite","required":10,"rewards":{"gold":2000,"items":{"Plus1Stone":1}}},
 "moon_box":{"category":SIDE_QUESTS,"title":"Moon Box","level_min":1,"npc_id":"","target_city":"TwinCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"collect_command_tokens","required":6,"rewards":{"items":{"MoonBox":1}}},
 "bandit_threat":{"category":SIDE_QUESTS,"title":"Bandit Threat","level_min":1,"npc_id":"","target_city":"TwinCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"kill_bandit","required":20,"rewards":{"items":{"UniqueGear":1}}},
 "phoenix_flame":{"category":SIDE_QUESTS,"title":"Phoenix Castle Flame","level_min":1,"npc_id":"","target_city":"PhoenixCastle","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"kill_fire_spirit_or_turtledove","required":20,"rewards":{"gold":3000,"items":{"Meteor":1}}},
 "macaque_threat":{"category":SIDE_QUESTS,"title":"Macaque Threat","level_min":1,"npc_id":"","target_city":"ApeMountain","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"kill_macaque","required":20,"rewards":{"exp":25000,"items":{"UniqueGear":1}}},
 "desert_treasure":{"category":SIDE_QUESTS,"title":"Ancient Desert Treasure","level_min":1,"npc_id":"","target_city":"DesertCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"kill_desert_monster","required":20,"rewards":{"items":{"DragonGem":1,"Meteor":1}}},
 "bird_island_feathers":{"category":SIDE_QUESTS,"title":"Bird Island Feathers","level_min":1,"npc_id":"","target_city":"BirdIsland","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"kill_birdman","required":20,"rewards":{"exp":25000,"items":{"Plus1Stone":1}}},
 "talisman_quest":{"category":SIDE_QUESTS,"title":"Talisman Quests","level_min":100,"npc_id":"","target_city":"TwinCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"own_talismans","required":2,"rewards":{"items":{"HeavenFan":1,"StarTower":1}}},
 "rebirth_quest":{"category":ENDGAME_REBIRTH,"title":"Second Rebirth","level_min":120,"npc_id":"","target_city":"TwinCity","npc_position":Vector3.ZERO,"monster_camp_position":Vector3.ZERO,"objective":"rebirth_requirements","required":3,"rewards":{"items":{"SuperGear":1}}}
}
const DAILY_REWARDS := [
 {"gold":500,"items":{"HPPotion":5,"MPPotion":5}},
 {"items":{"Plus1Stone":1}},
 {"items":{"Meteor":1}},
 {"items":{"DragonGem":1}},
 {"items":{"Plus2Stone":1}},
 {"items":{"AnimaStone":1}},
 {"items":{"DragonBall":1}}
]
const TOKEN_IDS := ["Peace","Chaos","Deserted","Prosperous","Disturbed","Calmed"]
var _catalog: Dictionary = QUEST_CATALOG.duplicate(true)

func _ready() -> void:
 var combat := get_node_or_null("/root/CombatSystem")
 if combat != null and combat.has_signal("monster_killed"):
  if not combat.monster_killed.is_connected(_on_monster_killed): combat.monster_killed.connect(_on_monster_killed)
 var npcs := get_node_or_null("/root/NPCMerchantSystem")
 if npcs != null and npcs.has_signal("npc_interacted"):
  if not npcs.npc_interacted.is_connected(_on_npc_interacted): npcs.npc_interacted.connect(_on_npc_interacted)
 print("QUEST_SYSTEM_READY: categories=4 quests=",_catalog.size()," daily_login_cycle=7")

func can_claim_daily_login() -> bool:
 var state := _state()
 if state == null: return false
 var today := _today_key()
 var last_day := String(state.player_data.get("daily_login_last_claim",""))
 return last_day != today

func claim_daily_login() -> Dictionary:
 var state := _state()
 if state == null: return {"ok":false,"reason":"gamestate_missing"}
 if not can_claim_daily_login(): return {"ok":false,"reason":"already_claimed_today"}
 var last_day := String(state.player_data.get("daily_login_last_claim",""))
 var day_index := int(state.player_data.get("daily_login_day_index",0))
 var previous_date := _parse_date_key(last_day)
 var current_date := Time.get_date_dict_from_system()
 if not last_day.is_empty() and _is_next_calendar_day(previous_date,current_date):
  day_index = (day_index + 1) % 7
 else:
  day_index = 0
 var rewards: Dictionary = DAILY_REWARDS[day_index].duplicate(true)
 _grant_rewards(rewards)
 state.player_data["daily_login_last_claim"] = _today_key()
 state.player_data["daily_login_day_index"] = day_index
 state.save_game()
 daily_login_claimed.emit(day_index + 1,rewards)
 return {"ok":true,"day":day_index + 1,"rewards":rewards}

func _today_key() -> String:
 var d := Time.get_date_dict_from_system()
 return "%04d-%02d-%02d" % [int(d.year),int(d.month),int(d.day)]

func _parse_date_key(value: String) -> Dictionary:
 var p := value.split("-")
 if p.size() != 3: return {}
 return {"year":int(p[0]),"month":int(p[1]),"day":int(p[2])}

func _is_next_calendar_day(previous: Dictionary,current: Dictionary) -> bool:
 if previous.is_empty(): return false
 var p := Time.get_unix_time_from_datetime_dict(previous)
 var c := Time.get_unix_time_from_datetime_dict(current)
 return int(c - p) == 86400

func _state() -> Node:
 return get_node_or_null("/root/GameState")

func _grant_rewards(rewards: Dictionary) -> void:
 var state := _state()
 if state == null: return
 if int(rewards.get("gold",0)) > 0: state.add_gold(int(rewards.gold))
 for item_id in rewards.get("items",{}):
  state.add_inventory_item(String(item_id),int(rewards.items[item_id]))
 if int(rewards.get("exp",0)) > 0: state.add_exp(int(rewards.exp))

func get_quest_catalog(category: String = "") -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for quest_id in _catalog:
  var data: Dictionary = _catalog[quest_id].duplicate(true)
  data["id"] = quest_id
  if category.is_empty() or String(data.category) == category: result.append(data)
 return result

func accept_quest(quest_id: String) -> bool:
 if not _catalog.has(quest_id): return false
 var state := _state()
 if state == null: return false
 var level := int(state.player_data.get("level",1))
 var definition: Dictionary = _catalog[quest_id]
 if level < int(definition.get("level_min",1)): return false
 var active: Dictionary = state.player_data.get("active_quests",{})
 if active.has(quest_id) or state.player_data.get("completed_quests",[]).has(quest_id): return false
 active[quest_id] = {"progress":0,"accepted":true}
 state.player_data["active_quests"] = active
 state.save_game()
 quest_accepted.emit(quest_id)
 return true

func _on_monster_killed(monster: Node3D) -> void:
 if monster == null or not is_instance_valid(monster): return
 var monster_id := String(monster.get("monster_id")) if _has_property(monster,"monster_id") else monster.name
 var definition: Dictionary = monster.get("definition") if _has_property(monster,"definition") else {}
 var tags := (monster_id + " " + String(definition.get("name",""))).to_lower()
 var is_boss := bool(monster.get("is_king")) if _has_property(monster,"is_king") else false
 var is_elite := bool(definition.get("is_elite",false))
 var active: Dictionary = _state().player_data.get("active_quests",{}) if _state()!=null else {}
 for quest_id in active.keys():
  var quest: Dictionary = _catalog.get(quest_id,{})
  var objective := String(quest.get("objective",""))
  var matched := objective in ["kill_any"] or (objective=="kill_boss" and is_boss) or (objective=="kill_elite" and is_elite) or (objective=="kill_bandit" and "bandit" in tags) or (objective=="kill_macaque" and "macaque" in tags) or (objective=="kill_birdman" and "birdman" in tags) or (objective=="kill_desert_monster" and ("desert" in tags or "scorpion" in tags)) or (objective=="kill_fire_spirit_or_turtledove" and ("fire spirit" in tags or "turtledove" in tags))
  if matched: _advance_quest(quest_id,1)

func _on_npc_interacted(npc_id: String, role_type: String) -> void:
 var active: Dictionary = _state().player_data.get("active_quests",{}) if _state()!=null else {}
 if active.has("tc_starting_tour") and role_type == "shop":
  _advance_quest("tc_starting_tour",1)
 if npc_id == "QuestMaster" and active.has("tc_starting_tour"):
  _advance_quest("tc_starting_tour",1)

func _advance_quest(quest_id: String,amount: int) -> void:
 var state := _state()
 if state == null: return
 var active: Dictionary = state.player_data.get("active_quests",{})
 if not active.has(quest_id): return
 var record: Dictionary = active[quest_id]
 var required := int(_catalog[quest_id].get("required",1))
 record["progress"] = mini(required,int(record.get("progress",0))+amount)
 active[quest_id] = record
 state.player_data["active_quests"] = active
 quest_progressed.emit(quest_id,int(record.progress),required)
 if int(record.progress) >= required:
  active.erase(quest_id)
  var completed: Array = state.player_data.get("completed_quests",[])
  if quest_id not in completed: completed.append(quest_id)
  state.player_data["completed_quests"] = completed
  _grant_rewards(_catalog[quest_id].get("rewards",{}))
  quest_completed.emit(quest_id)
 state.save_game()

func get_tracked_quests() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 var state := _state()
 if state == null: return result
 var active: Dictionary = state.player_data.get("active_quests",{})
 for quest_id in active:
  var quest: Dictionary = _catalog.get(quest_id,{})
  var record: Dictionary = active[quest_id]
  result.append({"id":quest_id,"title":quest.get("title",quest_id),"category":quest.get("category",""),"progress":record.get("progress",0),"required":quest.get("required",1),"target_city":quest.get("target_city",""),"npc_id":quest.get("npc_id",""),"npc_position":quest.get("npc_position",Vector3.ZERO),"monster_camp_position":quest.get("monster_camp_position",Vector3.ZERO)})
 return result

func navigate_to_quest(quest_id: String) -> bool:
 if not _catalog.has(quest_id): return false
 var state := _state()
 var active: Dictionary = state.player_data.get("active_quests",{}) if state != null else {}
 var quest: Dictionary = _catalog[quest_id]
 var navigation := get_node_or_null("/root/WorldNavigationSystem")
 var world_map := get_node_or_null("/root/WorldMapManager")
 if navigation == null or world_map == null: return false
 var target_city := String(quest.get("target_city",""))
 var target_id := String(quest.get("npc_id",""))
 var destination: Vector3 = quest.get("monster_camp_position",Vector3.ZERO) if active.has(quest_id) else quest.get("npc_position",Vector3.ZERO)
 if active.has(quest_id) and destination == Vector3.ZERO: destination = world_map.get_city_center(target_city)
 if not active.has(quest_id) and target_id.is_empty(): return false
 var ok := await navigation.navigate_to_position(target_city,destination)
 if ok:
  quest_navigation_started.emit(quest_id,target_city,target_id if not active.has(quest_id) else "MonsterCamp")
 return ok

func _has_property(object: Object,property_name: String) -> bool:
 for property in object.get_property_list():
  if String(property.name) == property_name: return true
 return false
