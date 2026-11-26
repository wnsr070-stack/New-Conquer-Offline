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
 var combat := get_node_or_null("/root/CombatSystem")
 if combat != null and not combat.monster_killed.is_connected(_on_monster_killed): combat.monster_killed.connect(_on_monster_killed)
 var npcs := get_node_or_null("/root/NPCMerchantSystem")
 if npcs != null and not npcs.npc_interacted.is_connected(_on_npc_interacted): npcs.npc_interacted.connect(_on_npc_interacted)
 print("PHASE4D_CLASSIC_QUEST_ENCYCLOPEDIA_READY: categories=5 quests=",_catalog.size())
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
 var ok: bool=await nav.navigate_to_position(String(d.target_city),d.monster_camp_position if s.player_data.get("active_quests",{}).has(id) else d.npc_position)
 if ok: quest_navigation_started.emit(id,String(d.target_city),String(d.npc_id))
 return ok
func _has_property(o: Object,k: String) -> bool:
 for p in o.get_property_list():
  if String(p.name)==k: return true
 return false
