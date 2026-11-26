extends Node
signal daily_login_claimed(day_index: int, rewards: Dictionary)
signal quest_accepted(quest_id: String)
signal quest_progressed(quest_id: String, progress: int, required: int)
signal quest_completed(quest_id: String)
signal quest_navigation_started(quest_id: String, city_id: String, target_id: String)
const MAIN_PROMOTION := "MAIN_PROMOTION"
const DAILY := "DAILY"
const WEEKLY := "WEEKLY"
const SIDE_QUESTS := "SIDE_QUESTS"
const ENDGAME_REBIRTH := "ENDGAME_REBIRTH"
const DAILY_REWARDS := [{"gold":500,"items":{"HPPotion":5,"MPPotion":5}},{"items":{"Plus1Stone":1}},{"items":{"Meteor":1}},{"items":{"DragonGem":1}},{"items":{"Plus2Stone":1}},{"items":{"AnimaStone":1}},{"items":{"DragonBall":1}}]
var _catalog: Dictionary = {}
func _ready() -> void:
 _build_catalog()
 call_deferred("_connect_runtime_signals")
 var combat := get_node_or_null("/root/CombatSystem")
 if combat != null and not combat.monster_killed.is_connected(_on_monster_killed): combat.monster_killed.connect(_on_monster_killed)
 var npcs := get_node_or_null("/root/NPCMerchantSystem")
 if npcs != null and not npcs.npc_interacted.is_connected(_on_npc_interacted): npcs.npc_interacted.connect(_on_npc_interacted)
 var state := _state()
 if state != null and state.has_signal("inventory_changed") and not state.inventory_changed.is_connected(_on_inventory_changed): state.inventory_changed.connect(_on_inventory_changed)
 var loot := get_node_or_null("/root/LootDropManager")
 if loot != null and loot.has_signal("loot_collected") and not loot.loot_collected.is_connected(_on_loot_collected): loot.loot_collected.connect(_on_loot_collected)
 var forge := get_node_or_null("/root/ForgingSystem")
 if forge != null:
  if forge.has_signal("forging_succeeded") and not forge.forging_succeeded.is_connected(_on_forging_succeeded): forge.forging_succeeded.connect(_on_forging_succeeded)
  if forge.has_signal("socket_updated") and not forge.socket_updated.is_connected(_on_socket_updated): forge.socket_updated.connect(_on_socket_updated)
 print("PHASE4D_CLASSIC_QUEST_ENCYCLOPEDIA_READY: categories=5 quests=",_catalog.size())
func _connect_runtime_signals() -> void:
 var combat := get_node_or_null("/root/CombatSystem")
 if combat != null and combat.has_signal("monster_killed") and not combat.monster_killed.is_connected(_on_monster_killed):
  combat.monster_killed.connect(_on_monster_killed)
 var npcs := get_node_or_null("/root/NPCMerchantSystem")
 if npcs != null and npcs.has_signal("npc_interacted") and not npcs.npc_interacted.is_connected(_on_npc_interacted):
  npcs.npc_interacted.connect(_on_npc_interacted)
 var state := _state()
 if state != null and state.has_signal("inventory_changed") and not state.inventory_changed.is_connected(_on_inventory_changed):
  state.inventory_changed.connect(_on_inventory_changed)
 var loot := get_node_or_null("/root/LootDropManager")
 if loot != null and loot.has_signal("loot_collected") and not loot.loot_collected.is_connected(_on_loot_collected):
  loot.loot_collected.connect(_on_loot_collected)
 var forge := get_node_or_null("/root/ForgingSystem")
 if forge != null:
  if forge.has_signal("forging_succeeded") and not forge.forging_succeeded.is_connected(_on_forging_succeeded):
   forge.forging_succeeded.connect(_on_forging_succeeded)
  if forge.has_signal("socket_updated") and not forge.socket_updated.is_connected(_on_socket_updated):
   forge.socket_updated.connect(_on_socket_updated)
func _add(id: String,cat: String,title: String,lvl: int,npc: String,city: String,pos: Vector3,obj: String,req: int,reward: Dictionary={}) -> void:
 _catalog[id]={"category":cat,"title":title,"level_min":lvl,"npc_id":npc,"target_city":city,"npc_position":pos,"monster_camp_position":pos,"objective":obj,"required":req,"rewards":reward}
func _build_catalog() -> void:
 _catalog.clear()
 _add("novice_1",MAIN_PROMOTION,"Novice Guide 1",1,"QuestMaster","TwinCity",Vector3(-86,0,-92),"visit",1,{"gold":100})
 _add("novice_2",MAIN_PROMOTION,"Novice Guide 2",5,"QuestMaster","TwinCity",Vector3(-86,0,-92),"kill_any",5,{"exp":500})
 _add("novice_3",MAIN_PROMOTION,"Novice Guide 3",10,"QuestMaster","TwinCity",Vector3(-86,0,-92),"collect",3,{"items":{"HPPotion":5}})
 _add("novice_4",MAIN_PROMOTION,"Novice Guide 4",15,"QuestMaster","TwinCity",Vector3(-86,0,-92),"kill_any",10,{"gold":500})
 _add("promotion_15",MAIN_PROMOTION,"Archer Promotion 15",15,"ArcherGod","TwinCity",Vector3(-52,0,-48),"promotion",1,{"items":{"DeerskinCoat":1,"Fly":1}})
 _add("promotion_40",MAIN_PROMOTION,"Archer Promotion 40",40,"ArcherGod","TwinCity",Vector3(-52,0,-48),"euxenite",5,{"items":{"UniqueBow":1}})
 _add("promotion_70",MAIN_PROMOTION,"Archer Promotion 70",70,"ArcherGod","TwinCity",Vector3(-52,0,-48),"emerald",1,{"items":{"ArrowRain":1}})
 _add("promotion_100",MAIN_PROMOTION,"Archer Promotion 100",100,"ArcherGod","TwinCity",Vector3(-52,0,-48),"meteor",1,{"items":{"RainbowGem":1}})
 _add("promotion_110",MAIN_PROMOTION,"Archer Promotion 110",110,"ArcherGod","TwinCity",Vector3(-52,0,-48),"moon_box",1,{"items":{"DragonBall":1}})
 _add("daily_search",DAILY,"Search",1,"Ming","TwinCity",Vector3(24,0,36),"collect",5)
 _add("daily_rebuild",DAILY,"Rebuild",1,"LongDong","TwinCity",Vector3(-36,0,28),"rebuild",5,{"items":{"Meteor":1}})
 _add("daily_kill_competition",DAILY,"Kill Competition",1,"Blacknull","TwinCity",Vector3(44,0,-24),"kill_any",20)
 _add("daily_exterminate",DAILY,"Exterminate",1,"F.Chen","TwinCity",Vector3(-24,0,-38),"kill_any",25)
 _add("daily_assassinate",DAILY,"Assassinate",1,"Synsia","TwinCity",Vector3(38,0,42),"kill_boss",3)
 _add("daily_demons",DAILY,"Demon Exterminators",1,"CloudSaint","Market",Vector3(-18,0,14),"kill_demon",30)
 _add("daily_dis_city",DAILY,"Dis City",1,"SolarSaint","ApeMountain",Vector3(16,0,-18),"kill_boss",3)
 _add("daily_coach",DAILY,"Coach Li's Assignment",1,"CoachLin","PhoenixCastle",Vector3(14,0,16),"collect",5)
 _add("daily_alchemist",DAILY,"The Alchemist's Ingredients",1,"Alchemist","PhoenixCastle",Vector3(-14,0,16),"collect",6)
 _add("daily_tower",DAILY,"Tower of Mystery",1,"TaoistMoon","Market",Vector3(18,0,14),"kill_elite",10)
 _add("daily_rare",DAILY,"Rare Materials",1,"GemCollector","TwinCity",Vector3(-42,0,44),"collect",4)
 _add("weekly_gems",WEEKLY,"Gem Collection",30,"GemCollector","TwinCity",Vector3(-42,0,44),"refined_gems",8)
 _add("weekly_slayer",WEEKLY,"Monster Slayer",40,"MonsterSlayer","TwinCity",Vector3(52,0,18),"kill_types",7)
 _add("weekly_event",WEEKLY,"Event Participation",50,"EventMaster","TwinCity",Vector3(-18,0,52),"event",1)
 _add("weekly_socket",WEEKLY,"Item Socketing",60,"ItemSocketingMaster","TwinCity",Vector3(18,0,-52),"socket",1)
 _add("side_moon_box",SIDE_QUESTS,"Moon Box Quest",1,"Fortuneteller","TwinCity",Vector3(115,0,115),"moon_tokens",6,{"items":{"MoonBox":1}})
 _add("side_blue_mouse",SIDE_QUESTS,"Blue Mouse Royal Treasures",1,"GeneralQing","TwinCity",Vector3(28,0,-32),"kill_mouse",10)
 _add("side_meteor",SIDE_QUESTS,"Meteor Tears",1,"Ming","TwinCity",Vector3(24,0,36),"meteor",3)
 _add("side_snake",SIDE_QUESTS,"Snake Islands & Treasure Labyrinth",1,"GeneralQing","TwinCity",Vector3(28,0,-32),"kill_snake",15)
 _add("side_bandits",SIDE_QUESTS,"Bandits' Plot",1,"ArcherGod","TwinCity",Vector3(-52,0,-48),"kill_bandit",20)
 _add("side_ape",SIDE_QUESTS,"Stone Ape's Trouble",1,"SolarSaint","ApeMountain",Vector3(16,0,-18),"kill_ape",20)
 _add("side_desert",SIDE_QUESTS,"Desert Rescue",1,"GeneralQing","DesertCity",Vector3.ZERO,"kill_desert",20)
 _add("side_bird",SIDE_QUESTS,"Bird Island Guarding Stone",1,"CelestialTaoist","ApeMountain",Vector3(-16,0,-18),"kill_bird",20)
 _add("side_talisman",SIDE_QUESTS,"Talisman Unlock",100,"TaoistMoon","Market",Vector3(18,0,14),"talisman",2,{"items":{"HeavenFan":1,"StarTower":1}})
 _add("end_celestial",ENDGAME_REBIRTH,"Celestial Stone",120,"Celestine","TwinCity",Vector3(-62,0,12),"celestial_recipe",8,{"items":{"CelestialStone":1}})
 _add("end_rebirth",ENDGAME_REBIRTH,"Rebirth Ritual",120,"RebirthMaster","TwinCity",Vector3(62,0,-12),"rebirth",3,{"items":{"SuperGear":1}})
func _state() -> Node: return get_node_or_null("/root/GameState")
func _date() -> String:
 var d:=Time.get_date_dict_from_system()
 return "%04d-%02d-%02d" % [d.year,d.month,d.day]
func _period(weekly: bool) -> String:
 var d:=Time.get_date_dict_from_system()
 var week:=int(Time.get_unix_time_from_datetime_dict(d)/604800.0)
 return str(d.year)+"-"+str(week) if weekly else _date()
func can_claim_daily_login() -> bool:
 var s:=_state()
 return s!=null and String(s.player_data.get("daily_login_last_claim",""))!=_date()
func claim_daily_login() -> Dictionary:
 var s:=_state()
 if s==null or not can_claim_daily_login(): return {"ok":false}
 var day: int=(int(s.player_data.get("daily_login_day_index",-1))+1)%7
 var reward: Dictionary=DAILY_REWARDS[day]
 if int(reward.get("gold",0))>0: s.add_gold(int(reward.gold))
 for id in reward.get("items",{}): s.add_inventory_item(String(id),int(reward.items[id]))
 s.player_data["daily_login_last_claim"]=_date()
 s.player_data["daily_login_day_index"]=day
 s.save_game()
 daily_login_claimed.emit(day+1,reward)
 return {"ok":true,"day":day+1,"rewards":reward}
func get_quest_catalog(category: String="") -> Array[Dictionary]:
 var out: Array[Dictionary]=[]
 for id in _catalog:
  var d: Dictionary=_catalog[id].duplicate(true)
  d["id"]=id
  if category.is_empty() or d.category==category: out.append(d)
 return out
func accept_quest(id: String) -> bool:
 if not _catalog.has(id): return false
 var s:=_state()
 if s==null: return false
 var d: Dictionary=_catalog[id]
 if int(s.player_data.get("level",1))<int(d.level_min): return false
 var active: Dictionary=s.player_data.get("active_quests",{}).duplicate(true)
 var completed: Array=s.player_data.get("completed_quests",[])
 if active.has(id) or id in completed: return false
 active[id]={"progress":0,"period":_period(d.category==WEEKLY)}
 s.player_data["active_quests"]=active
 s.save_game()
 quest_accepted.emit(id)
 return true
func _on_loot_collected(data: Dictionary) -> void:
 var s := _state()
 if s == null: return
 var item_id := String(data.get("item_id",""))
 var amount := maxi(1,int(data.get("amount",1)))
 var active: Dictionary = s.player_data.get("active_quests",{})
 for id in active.keys():
  if String(_catalog[id].objective) == "collect": _advance(id,amount)
 _on_inventory_changed(item_id,s.get_item_count(item_id))
func _on_inventory_changed(item_id: String, total: int) -> void:
 var s := _state()
 if s == null: return
 var active: Dictionary = s.player_data.get("active_quests",{})
 for id in active.keys():
  var obj := String(_catalog[id].objective)
  var count := 0
  match obj:
   "meteor": count = s.get_item_count("Meteor")
   "euxenite": count = s.get_item_count("EuxeniteOre")
   "rebuild": count = s.get_item_count("RebuildOre")
   "refined_gems":
    for gem in ["RefinedDragonGem","RefinedPhoenixGem","RefinedRainbowGem","RefinedVioletGem","RefinedFuryGem","RefinedMoonGem","RefinedKylinGem"]: count += s.get_item_count(gem)
   "moon_tokens":
    for token in ["PeaceCommandToken","ChaosCommandToken","DesertedCommandToken","ProsperousCommandToken","DisturbedCommandToken","CalmedCommandToken"]: count += mini(1,s.get_item_count(token))
   "celestial_recipe":
    for gem in ["DragonGem","PhoenixGem","RainbowGem","VioletGem","FuryGem","MoonGem","KylinGem"]: count += mini(1,s.get_item_count(gem))
    count += mini(1,s.get_item_count("CleanWater"))
  if count > 0:
   var current := int(active[id].get("progress",0))
   if count > current: _advance(id,count-current)
func _on_forging_succeeded(operation: String, _item: Dictionary) -> void:
 var s := _state()
 if s == null: return
 var active: Dictionary = s.player_data.get("active_quests",{})
 for id in active.keys():
  var obj := String(_catalog[id].objective)
  if obj == "rebuild" and operation in ["plus","quality","level"]: _advance(id,1)
  elif obj == "socket" and operation in ["socket","gem"]: _advance(id,1)
  elif obj == "talisman" and operation == "talisman": _advance(id,1)
func _on_socket_updated(_slot: String, _index: int, _gem_id: String) -> void:
 _on_forging_succeeded("socket",{})
func _on_npc_interacted(npc_id: String,_role: String) -> void:
 var s:=_state()
 if s==null: return
 var active: Dictionary=s.player_data.get("active_quests",{})
 for id in active.keys():
  var d: Dictionary=_catalog[id]
  if d.npc_id==npc_id and d.objective in ["visit","promotion","event","socket","talisman"]: _advance(id,1)
func _on_monster_killed(monster: Node3D) -> void:
 if monster==null or not is_instance_valid(monster): return
 var s:=_state()
 if s==null: return
 var name:=monster.name.to_lower()
 var data: Dictionary=monster.get("definition") if _has_property(monster,"definition") else {}
 var tags:=name+" "+String(data.get("name","")).to_lower()
 var boss:=bool(monster.get("is_king")) if _has_property(monster,"is_king") else false
 var elite:=bool(data.get("is_elite",false))
 var active: Dictionary=s.player_data.get("active_quests",{})
 for id in active.keys():
  var obj:=String(_catalog[id].objective)
  if obj in ["kill_any","kill_types"] or (obj=="kill_boss" and boss) or (obj=="kill_elite" and elite) or (obj=="kill_demon" and ("demon" in tags or "devil" in tags)) or (obj=="kill_mouse" and "mouse" in tags) or (obj=="kill_snake" and "snake" in tags) or (obj=="kill_bandit" and "bandit" in tags) or (obj=="kill_ape" and ("ape" in tags or "macaque" in tags)) or (obj=="kill_desert" and ("desert" in tags or "scorpion" in tags)) or (obj=="kill_bird" and "bird" in tags): _advance(id,1)
func _advance(id: String,amount: int) -> void:
 var s:=_state()
 if s==null or not s.player_data.get("active_quests",{}).has(id): return
 var active: Dictionary=s.player_data["active_quests"].duplicate(true)
 var record: Dictionary=active[id]
 var d: Dictionary=_catalog[id]
 record.progress=mini(int(d.required),int(record.get("progress",0))+amount)
 active[id]=record
 s.player_data["active_quests"]=active
 quest_progressed.emit(id,record.progress,int(d.required))
 if int(record.progress)>=int(d.required):
  active.erase(id)
  var done: Array=s.player_data.get("completed_quests",[])
  if id not in done: done.append(id)
  s.player_data["completed_quests"]=done
  s.player_data["active_quests"]=active
  var reward: Dictionary=d.get("rewards",{})
  if int(reward.get("gold",0))>0: s.add_gold(int(reward.gold))
  if int(reward.get("exp",0))>0: s.add_exp(int(reward.exp))
  for item in reward.get("items",{}): s.add_inventory_item(String(item),int(reward.items[item]))
  quest_completed.emit(id)
 s.save_game()
func get_tracked_quests() -> Array[Dictionary]:
 var out: Array[Dictionary]=[]
 var s:=_state()
 if s==null: return out
 for id in s.player_data.get("active_quests",{}):
  var d: Dictionary=_catalog.get(id,{})
  var r: Dictionary=s.player_data["active_quests"][id]
  out.append({"id":id,"title":d.get("title",id),"category":d.get("category",""),"progress":r.get("progress",0),"required":d.get("required",1),"target_city":d.get("target_city",""),"npc_id":d.get("npc_id",""),"npc_position":d.get("npc_position",Vector3.ZERO),"monster_camp_position":d.get("monster_camp_position",Vector3.ZERO)})
 return out
func navigate_to_quest(id: String) -> bool:
 if not _catalog.has(id): return false
 var s:=_state()
 var d: Dictionary=_catalog[id]
 if s==null or int(s.player_data.get("level",1))<int(d.level_min): return false
 var nav:=get_node_or_null("/root/WorldNavigationSystem")
 if nav==null: return false
 var target_position: Vector3 = d.npc_position
 if s.player_data.get("active_quests",{}).has(id):
  var spawner := get_tree().get_first_node_in_group("monster_spawner")
  var monster_id := _quest_monster_id(id)
  if spawner != null and not monster_id.is_empty() and spawner.has_method("get_monster_camp_position"):
   var camp: Vector3 = spawner.get_monster_camp_position(monster_id)
   if camp != Vector3.ZERO: target_position = camp
 var ok: bool=await nav.navigate_to_position(String(d.target_city),target_position)
 if ok: quest_navigation_started.emit(id,String(d.target_city),String(d.npc_id))
 return ok
func _has_property(o: Object,k: String) -> bool:
 for p in o.get_property_list():
  if String(p.name)==k: return true
 return false

func _quest_monster_id(quest_id: String) -> String:
 var mapping := {"novice_2":"Chicken","novice_4":"Pigeon","daily_kill_competition":"Ghost","daily_exterminate":"Blob","daily_assassinate":"Mushroom King","daily_demons":"Demon","daily_dis_city":"Alpaking Evolved","daily_tower":"Alien","weekly_slayer":"Chicken","side_blue_mouse":"Chicken","side_meteor":"Chicken","side_snake":"Cactoro","side_bandits":"Bunny","side_ape":"Orc","side_desert":"Cactoro","side_bird":"Armabee"}
 return String(mapping.get(quest_id,""))
func create_soul_jade() -> Dictionary:
 var s := _state()
 if s == null: return {"ok":false,"reason":"gamestate_missing"}
 var tokens := ["PeaceCommandToken","ChaosCommandToken","DesertedCommandToken","ProsperousCommandToken","DisturbedCommandToken","CalmedCommandToken"]
 for token in tokens:
  if s.get_item_count(token) < 1: return {"ok":false,"reason":"missing_"+token}
 if s.inventory_slots.size() >= GameState.MAX_INVENTORY_SLOTS and s.get_item_count("SoulJade") == 0: return {"ok":false,"reason":"inventory_full"}
 for token in tokens: s.remove_item(token,1)
 if not s.add_item("SoulJade",1): return {"ok":false,"reason":"inventory_full"}
 s.save_game()
 return {"ok":true,"item_id":"SoulJade"}
func create_moon_box() -> Dictionary:
 var s := _state()
 if s == null or not s.remove_item("SoulJade",1): return {"ok":false,"reason":"soul_jade_missing"}
 if not s.add_item("MoonBox",1):
  s.add_item("SoulJade",1)
  return {"ok":false,"reason":"inventory_full"}
 s.save_game()
 return {"ok":true,"item_id":"MoonBox"}
func open_moon_box() -> Dictionary:
 var s := _state()
 if s == null or s.get_item_count("MoonBox") < 1: return {"ok":false,"reason":"moon_box_missing"}
 if not s.remove_item("MoonBox",1): return {"ok":false,"reason":"moon_box_missing"}
 var reward_kind: String = ["Meteor","Elite","Super","Socketed"][randi_range(0,3)]
 var reward_id := "Meteor"
 var instance_data: Dictionary = {}
 if reward_kind != "Meteor":
  var class_id := String(s.player_data.get("class","archer"))
  var family_by_class := {"archer":"bow","oriental_assassin":"dual_daggers","trojan":"dual_blades","warrior":"spear","taoist":"magic_staff","ninja":"katana","monk":"staff"}
  var family := String(family_by_class.get(class_id,"bow"))
  var database := get_node_or_null("/root/GearDatabase")
  if database == null:
   s.add_item("MoonBox",1)
   return {"ok":false,"reason":"gear_database_missing"}
  var quality := "Elite" if reward_kind == "Elite" else "Super"
  var item: Dictionary = database.get_tier_item(family,130,quality,1)
  if item.is_empty():
   s.add_item("MoonBox",1)
   return {"ok":false,"reason":"reward_item_unavailable"}
  reward_id = String(item.get("id",""))
  if reward_kind == "Socketed": instance_data = {"sockets":["DragonGem"],"quality":"Super","plus":1}
 if not s.add_item(reward_id,1,instance_data):
  s.add_item("MoonBox",1)
  return {"ok":false,"reason":"inventory_full"}
 s.save_game()
 return {"ok":true,"reward":reward_id,"reward_kind":reward_kind}
func craft_celestial_stone(npc_id: String = "Celestine") -> Dictionary:
 if npc_id != "Celestine": return {"ok":false,"reason":"wrong_npc"}
 var s := _state()
 if s == null: return {"ok":false,"reason":"gamestate_missing"}
 var gems := ["DragonGem","PhoenixGem","RainbowGem","VioletGem","FuryGem","MoonGem","KylinGem"]
 for gem in gems:
  if s.get_item_count(gem) < 1: return {"ok":false,"reason":"missing_"+gem}
 if s.get_item_count("CleanWater") < 1: return {"ok":false,"reason":"clean_water_missing"}
 if s.inventory_slots.size() >= GameState.MAX_INVENTORY_SLOTS and s.get_item_count("CelestialStone") == 0: return {"ok":false,"reason":"inventory_full"}
 for gem in gems: s.remove_item(gem,1)
 s.remove_item("CleanWater",1)
 s.add_item("CelestialStone",1)
 s.save_game()
 return {"ok":true,"item_id":"CelestialStone"}
func perform_rebirth(npc_id: String = "RebirthMaster") -> Dictionary:
 if npc_id != "RebirthMaster": return {"ok":false,"reason":"wrong_npc"}
 var s := _state()
 var classes := get_node_or_null("/root/ClassSystem")
 var database := get_node_or_null("/root/GearDatabase")
 if s == null: return {"ok":false,"reason":"gamestate_missing"}
 if int(s.player_data.get("level",1)) < 120: return {"ok":false,"reason":"level_120_required"}
 if s.get_item_count("CelestialStone") < 1: return {"ok":false,"reason":"celestial_stone_missing"}
 if database == null: return {"ok":false,"reason":"gear_database_missing"}
 var old_class := String(s.player_data.get("class","archer"))
 var family_by_class := {"archer":"bow","oriental_assassin":"dual_daggers","trojan":"dual_blades","warrior":"spear","taoist":"magic_staff","ninja":"katana","monk":"staff"}
 var family := String(family_by_class.get(old_class,"bow"))
 var weapon: Dictionary = database.get_tier_item(family,130,"Super",1)
 if weapon.is_empty(): return {"ok":false,"reason":"rebirth_weapon_unavailable"}
 var weapon_id := String(weapon.get("id",""))
 var needs_weapon_slot: bool = s.get_item_count(weapon_id) == 0
 var needs_gem_slot: bool = s.get_item_count("SuperDragonGem") >= GameState.MAX_STACK
 var free_slots: int = GameState.MAX_INVENTORY_SLOTS - s.inventory_slots.size()
 if free_slots < int(needs_weapon_slot) + int(needs_gem_slot): return {"ok":false,"reason":"inventory_full"}
 var skills: Dictionary = s.player_data.get("unlocked_skills",{}).duplicate(true)
 if not s.remove_item("CelestialStone",1): return {"ok":false,"reason":"celestial_stone_missing"}
 s.player_data["level"] = 15
 s.player_data["free_attribute_points"] = int(s.player_data.get("free_attribute_points",0)) + 30
 s.player_data["unlocked_skills"] = skills
 s.player_data["rebirth_count"] = int(s.player_data.get("rebirth_count",0)) + 1
 s.player_data["reborn"] = true
 if not s.add_item("SuperDragonGem",1) or not s.add_item(weapon_id,1,{"quality":"Super","plus":1}):
  s.player_data["level"] = 120
  s.player_data["free_attribute_points"] = int(s.player_data.get("free_attribute_points",0)) - 30
  s.player_data["rebirth_count"] = maxi(0,int(s.player_data.get("rebirth_count",1))-1)
  s.player_data["reborn"] = int(s.player_data["rebirth_count"]) > 0
  s.add_item("CelestialStone",1)
  return {"ok":false,"reason":"rebirth_reward_inventory_failed"}
 if classes != null and classes.has_method("apply_rebirth"): classes.apply_rebirth(old_class,15,skills)
 s.save_game()
 return {"ok":true,"level":15,"bonus_points":30,"class":old_class,"weapon_id":weapon_id,"gem":"SuperDragonGem"}
