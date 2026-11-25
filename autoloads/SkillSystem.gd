extends Node
signal skill_used(skill_id: String, targets_hit: int)
signal buff_changed(buff_id: String, time_left: float)

const SKILL_DATA := {
 "scatter":{"class":"archer","weapon":"bow","cost_type":"mana","cost":12,"cooldown":4.0,"range":18.0,"damage":0.85,"kind":"fan","max_targets":8},
 "rapid_fire":{"class":"archer","weapon":"bow","cost_type":"mana","cost":15,"cooldown":3.0,"range":18.0,"damage":0.65,"kind":"rapid","hits":3},
 "fly":{"class":"archer","weapon":"bow","xp":true,"duration":30.0,"kind":"fly"},
 "arrow_rain":{"class":"archer","weapon":"bow","xp":true,"duration":20.0,"range":18.0,"damage":1.35,"kind":"aoe","radius":6.0,"max_targets":8},
 "blade_tempest":{"class":"oriental_assassin","weapon":"dual_daggers","cost_type":"stamina","cost":18,"cooldown":5.0,"range":4.5,"damage":0.9,"kind":"aoe","radius":4.5,"max_targets":8},
 "kinetic_spark":{"class":"oriental_assassin","weapon":"dual_daggers","cost_type":"stamina","cost":14,"cooldown":3.0,"range":4.5,"damage":1.8,"kind":"single"},
 "fast_blade":{"class":"trojan","cost_type":"stamina","cost":14,"cooldown":3.0,"range":12.0,"damage":1.25,"kind":"line","max_targets":8},
 "scent_sword":{"class":"trojan","cost_type":"stamina","cost":16,"cooldown":4.0,"range":12.0,"damage":1.45,"kind":"line","max_targets":8},
 "hercules":{"class":"trojan","cost_type":"stamina","cost":20,"cooldown":5.0,"range":5.0,"damage":1.6,"kind":"aoe","radius":5.0,"max_targets":8},
 "cyclone":{"class":"trojan","xp":true,"duration":20.0,"kind":"buff"},
 "wide_strike":{"class":"warrior","cost_type":"stamina","cost":16,"cooldown":3.5,"range":5.0,"damage":1.2,"kind":"fan","max_targets":8},
 "shield_bash":{"class":"warrior","cost_type":"stamina","cost":12,"cooldown":4.0,"range":3.5,"damage":1.1,"kind":"single","slow":0.5,"slow_duration":3.0},
 "superman":{"class":"warrior","xp":true,"duration":20.0,"kind":"buff"},
 "thunder":{"class":"taoist","cost_type":"mana","cost":14,"cooldown":2.5,"range":18.0,"damage":1.5,"kind":"single"},
 "cure":{"class":"taoist","cost_type":"mana","cost":18,"cooldown":8.0,"kind":"heal","heal":0.35},
 "tornado":{"class":"taoist","cost_type":"mana","cost":22,"cooldown":6.0,"range":18.0,"damage":1.0,"kind":"aoe","radius":6.0,"max_targets":8},
 "chain_lightning":{"class":"taoist","xp":true,"duration":20.0,"range":18.0,"damage":1.2,"kind":"chain","max_targets":6}
}
var cooldowns: Dictionary = {}
var buffs: Dictionary = {}
var _buff_durations: Dictionary = {}
var _flight_original_y: float = 0.0
var slowed_targets: Dictionary = {}

func _process(delta: float) -> void:
 var hero := _find_hero()
 var attack_rate := float(hero.get_meta("attack_speed_multiplier",1.0)) if hero != null else 1.0
 for key in cooldowns.keys():
  cooldowns[key] = maxf(0.0,float(cooldowns[key])-delta*attack_rate)
 for key in slowed_targets.keys():
  var entry: Dictionary = slowed_targets[key]
  entry.remaining = float(entry.remaining)-delta
  if entry.remaining <= 0.0:
   var target: Node3D = entry.target
   if is_instance_valid(target):
    for property in target.get_property_list():
     if String(property.name) == "move_speed":
      target.set("move_speed",float(entry.original))
      break
    target.remove_meta("movement_slow_multiplier")
    target.remove_meta("movement_slow_time")
   slowed_targets.erase(key)
 for key in buffs.keys():
  buffs[key] = maxf(0.0,float(buffs[key])-delta)
  if buffs[key] <= 0.0:
   _end_buff(String(key))
  else:
   buff_changed.emit(String(key),float(buffs[key]))

func get_equipped_mode(hero: Node3D) -> String:
 var class_id := _hero_class(hero)
 if class_id == "oriental_assassin": return "dual_daggers"
 if class_id != "archer": return ""
 var gear := get_node_or_null("/root/GearSystem")
 if gear != null:
  var item: Dictionary = gear.get_equipped("weapon")
  var weapon_id := String(item.get("family",item.get("id",item.get("name","")))).to_lower()
  if weapon_id.contains("dagger") or weapon_id.contains("knife") or weapon_id.contains("dual"):
   return "dual_daggers"
 if hero.has_meta("equipped_weapon"):
  var weapon := String(hero.get_meta("equipped_weapon")).to_lower()
  if weapon.contains("dagger") or weapon.contains("knife") or weapon.contains("dual"):
   return "dual_daggers"
 return "bow"

func get_available_skills(hero: Node3D) -> Array[String]:
 var class_id := _effective_skill_class(hero)
 var mode := get_equipped_mode(hero)
 var result: Array[String] = []
 for skill_id in SKILL_DATA:
  var data: Dictionary = SKILL_DATA[skill_id]
  if String(data.get("class","")) != class_id: continue
  if class_id == "archer" and String(data.get("weapon","bow")) != mode: continue
  result.append(skill_id)
 return result

func use_skill(hero: Node3D, skill_id: String, target: Node3D = null) -> Dictionary:
 if hero == null or not is_instance_valid(hero): return _fail("invalid_hero")
 if not SKILL_DATA.has(skill_id): return _fail("unknown_skill")
 var data: Dictionary = SKILL_DATA[skill_id]
 var class_id := _effective_skill_class(hero)
 if String(data.get("class","")) != class_id: return _fail("wrong_class")
 if class_id == "archer" and String(data.get("weapon","bow")) != get_equipped_mode(hero): return _fail("wrong_weapon")
 var state := get_node_or_null("/root/GameState")
 if bool(data.get("xp",false)):
  if state == null or float(state.xp_ready_time_left) <= 0.0: return _fail("xp_not_ready")
 else:
  if float(cooldowns.get(skill_id,0.0)) > 0.0: return _fail("cooldown")
  if not _spend_resource(state,String(data.get("cost_type","mana")),int(data.get("cost",0)),hero): return _fail("insufficient_resource")
 var combat := get_node_or_null("/root/CombatSystem")
 if combat == null: return _fail("combat_system_missing")
 var kind := String(data.get("kind","single"))
 var hit_count := 0
 if bool(data.get("xp",false)):
  state.consume_xp_ready()
  if skill_id in ["fly","cyclone","superman"]:
   _start_buff(skill_id,float(data.get("duration",20.0)),hero)
  elif skill_id == "arrow_rain":
   hit_count = _start_buff("arrow_rain",float(data.get("duration",20.0)),hero)
  elif skill_id == "chain_lightning":
   hit_count = _chain_lightning(hero,combat,data)
 else:
  cooldowns[skill_id] = float(data.get("cooldown",1.0))
  if kind == "heal":
   var max_hp := _hero_max_hp(hero)
   var old_hp := _hero_hp(hero)
   var amount := maxi(1,int(round(float(max_hp)*float(data.get("heal",0.35)))))
   _set_hero_hp(hero,mini(max_hp,old_hp+amount))
   hit_count = 1 if _hero_hp(hero) > old_hp else 0
  elif kind == "rapid":
   if target == null: target = combat.find_nearest_target(hero)
   if target != null:
    for i in range(int(data.get("hits",3))):
     if not combat._is_alive_monster(target): break
     var result: Dictionary = combat.apply_skill_damage(hero,target,float(data.get("damage",1.0)),skill_id)
     if result.get("ok",false): hit_count += 1
  else:
   var targets := _select_targets(hero,target,data)
   for victim in targets:
    var result: Dictionary = combat.apply_skill_damage(hero,victim,float(data.get("damage",1.0)),skill_id)
    if result.get("ok",false):
     hit_count += 1
     if skill_id == "shield_bash":
      _apply_slow(victim,float(data.get("slow",0.5)),float(data.get("slow_duration",3.0)))
 if kind == "buff" or kind == "fly": hit_count = 1
 skill_used.emit(skill_id,hit_count)
 print("PHASE4C_SKILL_USED: id=",skill_id," class=",class_id," weapon=",get_equipped_mode(hero)," targets=",hit_count)
 return {"ok":true,"skill":skill_id,"targets_hit":hit_count,"cooldown":float(cooldowns.get(skill_id,0.0))}

func _select_targets(hero: Node3D, primary: Node3D, data: Dictionary) -> Array[Node3D]:
 var result: Array[Node3D] = []
 var combat := get_node_or_null("/root/CombatSystem")
 var kind := String(data.get("kind","single"))
 if primary != null and kind == "single":
  if combat._is_alive_monster(primary) and hero.global_position.distance_to(primary.global_position) <= float(data.get("range",18.0)):
   result.append(primary)
  return result
 var radius := float(data.get("radius",data.get("range",18.0)))
 var max_targets := int(data.get("max_targets",8))
 var forward := -hero.global_transform.basis.z
 for candidate in get_tree().root.find_children("*","Node3D",true,false):
  if not candidate is Node3D or not combat._is_alive_monster(candidate): continue
  var victim := candidate as Node3D
  if victim == hero or victim.is_in_group("players"): continue
  var offset := victim.global_position-hero.global_position
  var distance := offset.length()
  if distance > radius: continue
  if kind == "fan":
   var dot := forward.normalized().dot(offset.normalized())
   if dot < 0.35: continue
  elif kind == "line":
   var along := offset.dot(forward.normalized())
   var lateral := (offset-forward.normalized()*along).length()
   if along < 0.0 or along > radius or lateral > 1.8: continue
  result.append(victim)
 result.sort_custom(func(a: Node3D,b: Node3D): return hero.global_position.distance_squared_to(a.global_position) < hero.global_position.distance_squared_to(b.global_position))
 if result.size() > max_targets: result.resize(max_targets)
 if kind == "single" and result.size() > 1: result.resize(1)
 return result

func _chain_lightning(hero: Node3D, combat: Node, data: Dictionary) -> int:
 var first := _select_targets(hero,null,{"kind":"aoe","radius":float(data.get("range",18.0)),"max_targets":1})
 if first.is_empty(): return 0
 var hit := 0
 var current: Node3D = first[0]
 var visited: Array[Node3D] = []
 for i in range(int(data.get("max_targets",6))):
  if current == null or not combat._is_alive_monster(current): break
  visited.append(current)
  var result: Dictionary = combat.apply_skill_damage(hero,current,float(data.get("damage",1.0)), "chain_lightning")
  if result.get("ok",false): hit += 1
  var next_target: Node3D
  var best := 5.0
  for candidate in get_tree().root.find_children("*","",true,false):
   if not candidate is Node3D or candidate in visited or not combat._is_alive_monster(candidate): continue
   var d := current.global_position.distance_to(candidate.global_position)
   if d < best:
    best = d
    next_target = candidate as Node3D
  current = next_target
 return hit

func _spend_resource(state: Node,resource: String,amount: int,hero: Node3D) -> bool:
 if state == null: return false
 if resource == "stamina":
  for property in hero.get_property_list():
   if String(property.name) == "stamina":
    var current_stamina := float(hero.get("stamina"))
    if current_stamina < float(amount): return false
    hero.set("stamina",current_stamina-float(amount))
    return true
 var key := "mana" if resource == "mana" else "stamina"
 var current := int(state.player_data.get(key,100))
 if current < amount: return false
 state.player_data[key] = current-amount
 return true

func _hero_class(hero: Node3D) -> String:
 for property in hero.get_property_list():
  if String(property.name) == "active_class": return String(hero.get("active_class"))
 return String(hero.get_meta("active_class","archer"))

func _hero_max_hp(hero: Node3D) -> int:
 for property in hero.get_property_list():
  if String(property.name) == "max_hp": return maxi(1,int(hero.get("max_hp")))
 return maxi(1,int(hero.get_meta("max_hp",100)))

func _hero_hp(hero: Node3D) -> int:
 for property in hero.get_property_list():
  if String(property.name) == "current_hp": return int(hero.get("current_hp"))
 return int(hero.get_meta("current_hp",_hero_max_hp(hero)))

func _set_hero_hp(hero: Node3D,value: int) -> void:
 for property in hero.get_property_list():
  if String(property.name) == "current_hp":
   hero.set("current_hp",value)
   return
 hero.set_meta("current_hp",value)

func _start_buff(buff_id: String,duration: float,hero: Node3D) -> int:
 buffs[buff_id] = duration
 _buff_durations[buff_id] = duration
 if buff_id == "fly":
  _flight_original_y = hero.global_position.y
  hero.global_position.y += 3.5
  hero.set_meta("flight_active",true)
  hero.set_meta("attack_speed_multiplier",1.5)
 elif buff_id == "cyclone":
  hero.set_meta("movement_speed_multiplier",2.0)
  hero.set_meta("attack_speed_multiplier",2.0)
  for property in hero.get_property_list():
   if String(property.name) == "move_speed":
    var base_speed := float(hero.get("move_speed"))
    hero.set_meta("_skill_base_move_speed",base_speed)
    hero.set("move_speed",base_speed*2.0)
    break
 elif buff_id == "superman":
  hero.set_meta("physical_damage_multiplier",2.0)
 elif buff_id == "arrow_rain":
  var combat := get_node_or_null("/root/CombatSystem")
  var hits := 0
  for victim in _select_targets(hero,null,{"kind":"aoe","radius":6.0,"max_targets":8}):
   var result: Dictionary = combat.apply_skill_damage(hero,victim,1.35,"arrow_rain")
   if result.get("ok",false): hits += 1
  buff_changed.emit(buff_id,duration)
  return hits
 buff_changed.emit(buff_id,duration)
 return 0

func _end_buff(buff_id: String) -> void:
 buffs.erase(buff_id)
 _buff_durations.erase(buff_id)
 var hero := _find_hero()
 if hero != null:
  if buff_id == "fly":
   hero.global_position.y = _flight_original_y
   hero.set_meta("flight_active",false)
   hero.set_meta("attack_speed_multiplier",1.0)
  elif buff_id == "cyclone":
   hero.set_meta("movement_speed_multiplier",1.0)
   hero.set_meta("attack_speed_multiplier",1.0)
   if hero.has_meta("_skill_base_move_speed"):
    for property in hero.get_property_list():
     if String(property.name) == "move_speed":
      hero.set("move_speed",float(hero.get_meta("_skill_base_move_speed")))
      break
    hero.remove_meta("_skill_base_move_speed")
  elif buff_id == "superman":
   hero.set_meta("physical_damage_multiplier",1.0)
 buff_changed.emit(buff_id,0.0)

func on_monster_killed() -> void:
 for buff_id in ["cyclone","superman"]:
  if float(buffs.get(buff_id,0.0)) > 0.0:
   buffs[buff_id] = float(buffs[buff_id])+2.0
   print("PHASE4C_XP_BUFF_EXTENDED: id=",buff_id," seconds=+2 remaining=",buffs[buff_id])

func _find_hero() -> Node3D:
 var hero := get_tree().root.find_child("PlayableHero",true,false)
 if hero is Node3D: return hero as Node3D
 var legacy := get_tree().root.find_child("TwinCityPlayableHero",true,false)
 return legacy as Node3D if legacy is Node3D else null

func _fail(reason: String) -> Dictionary:
 return {"ok":false,"reason":reason}

func reset_for_test() -> void:
 cooldowns.clear()
 buffs.clear()
 _buff_durations.clear()

func _effective_skill_class(hero: Node3D) -> String:
 var class_id := _hero_class(hero)
 if class_id == "archer" and get_equipped_mode(hero) == "dual_daggers":
  return "oriental_assassin"
 return class_id

func _apply_slow(target: Node3D,multiplier: float,duration: float) -> void:
 var key := target.get_instance_id()
 var original_speed := 0.0
 for property in target.get_property_list():
  if String(property.name) == "move_speed":
   original_speed = float(target.get("move_speed"))
   target.set("move_speed",original_speed*multiplier)
   break
 target.set_meta("movement_slow_multiplier",multiplier)
 target.set_meta("movement_slow_time",duration)
 slowed_targets[key] = {"target":target,"remaining":duration,"original":original_speed}
