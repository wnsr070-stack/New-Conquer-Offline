extends Node
signal target_changed(target: Node3D)
signal damage_dealt(target: Node3D, amount: int, critical: bool)
signal monster_killed(monster: Node3D)
signal loot_visual_registered(loot_node: Node3D, item_rarity: String, item_type: String)
const RANGED_RANGE := 18.0
const MELEE_RANGE := 3.5
const CRITICAL_MULTIPLIER := 1.5
const CRITICAL_CHANCE := 0.10
const XP_PER_SECOND := 4.0
const XP_PER_KILL := 5.0
var current_target: Node3D
var combat_active := false
var _xp_fraction := 0.0
var _rng := RandomNumberGenerator.new()
var _hero: Node3D

func _ready() -> void:
 _rng.randomize()
 print("PHASE4C_COMBAT_SYSTEM_READY: ranged=18m melee=3.5m critical=1.5x xp=4_per_second")

func _process(delta: float) -> void:
 var hero := _find_hero()
 if hero == null:
  combat_active = false
  return
 _hero = hero
 _sync_anima_stats(hero)
 if combat_active:
  var target := current_target
  if not _is_alive_monster(target) or hero.global_position.distance_to(target.global_position) > _weapon_range(hero):
   combat_active = false
  else:
   _grant_combat_xp(delta)
 var game_state := get_node_or_null("/root/GameState")
 if game_state != null: game_state.tick_xp(delta)

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
  var hero := _find_hero()
  if hero == null: return
  var target := find_nearest_target(hero)
  if target != null: perform_attack(hero,target)

func _find_hero() -> Node3D:
 var named := get_tree().root.find_child("PlayableHero",true,false)
 if named is Node3D: return named as Node3D
 var legacy := get_tree().root.find_child("TwinCityPlayableHero",true,false)
 return legacy as Node3D if legacy is Node3D else null

func _hero_class(hero: Node3D) -> String:
 for property in hero.get_property_list():
  if String(property.name) == "active_class": return String(hero.get("active_class"))
 return String(hero.get_meta("active_class","archer"))

func _weapon_range(hero: Node3D) -> float:
 return RANGED_RANGE if _hero_class(hero) in ["archer","taoist"] else MELEE_RANGE

func find_nearest_target(hero: Node3D) -> Node3D:
 if hero == null: return null
 var best: Node3D
 var best_distance := _weapon_range(hero)
 for candidate in get_tree().root.find_children("*","MonsterActor",true,false):
  if not candidate is Node3D or not _is_alive_monster(candidate): continue
  var distance := hero.global_position.distance_to((candidate as Node3D).global_position)
  if distance <= best_distance:
   best_distance = distance
   best = candidate as Node3D
 if current_target != best:
  current_target = best
  target_changed.emit(best)
 return best

func perform_attack(hero: Node3D,target: Node3D,force_critical: bool = false) -> Dictionary:
 if hero == null or not _is_alive_monster(target): return {"ok":false,"reason":"invalid_target"}
 var distance := hero.global_position.distance_to(target.global_position)
 if distance > _weapon_range(hero): return {"ok":false,"reason":"out_of_range","distance":distance}
 _play_attack_animation(hero,_hero_class(hero))
 var weapon_family := _equipped_weapon_family()
 var state := get_node_or_null("/root/GameState")
 var player_data: Dictionary = state.player_data if state != null else {}
 var gear_stats: Dictionary = _gear_bonuses()
 var attack: int = int(player_data.get("attack",100))+int(gear_stats.get("attack",0))
 var defense := int(target.definition.get("defense",0))
 var critical_chance := clampf(CRITICAL_CHANCE+float(gear_stats.get("critical",0.0)),0.0,0.75)
 var critical := force_critical or (not bool(get_meta("disable_random_crit",false)) and _rng.randf() < critical_chance)
 var anima: Dictionary = state.get_anima_bonuses() if state != null else {"attack_multiplier":1.0}
 var multiplier := float(hero.get_meta("physical_damage_multiplier",1.0))*float(anima.get("attack_multiplier",1.0))
 var raw_damage := maxi(1,attack-defense)
 var damage := int(round(float(raw_damage)*(CRITICAL_MULTIPLIER if critical else 1.0)*multiplier))
 var result := _apply_damage(target,damage,critical,hero,"basic_attack")
 if bool(result.get("ok",false)) and state != null: state.add_weapon_proficiency(weapon_family,1.0)
 return result

func apply_skill_damage(hero: Node3D,target: Node3D,skill_multiplier: float,skill_id: String) -> Dictionary:
 if hero == null or not _is_alive_monster(target): return {"ok":false,"reason":"invalid_target"}
 var state := get_node_or_null("/root/GameState")
 var player_data: Dictionary = state.player_data if state != null else {}
 var physical := skill_id not in ["thunder","tornado","chain_lightning","arrow_rain"]
 var gear_stats: Dictionary = _gear_bonuses()
 var attack: int = int(player_data.get("attack",100))+int(gear_stats.get("attack" if physical else "magic_attack",0))
 var defense := int(target.definition.get("defense",0))
 var anima: Dictionary = state.get_anima_bonuses() if state != null else {"attack_multiplier":1.0}
 var buff_multiplier := float(hero.get_meta("physical_damage_multiplier",1.0)) if physical else 1.0
 var anima_multiplier := float(anima.get("attack_multiplier",1.0)) if physical else 1.0
 var damage := maxi(1,int(round(float(maxi(1,attack-defense))*skill_multiplier*buff_multiplier*anima_multiplier)))
 return _apply_damage(target,damage,false,hero,skill_id)

func _apply_damage(target: Node3D,damage: int,critical: bool,hero: Node3D,source: String) -> Dictionary:
 var hp_before := int(target.current_hp)
 if target.has_method("play_hit") and hp_before > damage:
  target.call("play_hit")
 target.current_hp = maxi(0,hp_before-damage)
 var actual_damage := hp_before-int(target.current_hp)
 _spawn_floating_damage(target,actual_damage,critical)
 damage_dealt.emit(target,actual_damage,critical)
 combat_active = true
 current_target = target
 print("PHASE4C_DAMAGE_APPLIED: source=",source," target=",target.name," damage=",actual_damage," critical=",critical," hp=",target.current_hp,"/",target.max_hp)
 if target.current_hp <= 0:
  monster_killed.emit(target)
  _on_monster_killed(target,get_node_or_null("/root/GameState"))
 return {"ok":true,"damage":actual_damage,"critical":critical,"hp":int(target.current_hp),"damage_label":target.get_node_or_null("FloatingDamage") != null}

func _play_attack_animation(hero: Node3D,class_id: String) -> void:
 var animation_player := hero.get("animation_player") as AnimationPlayer
 if animation_player == null: return
 var wanted := "Attack_Bow" if class_id == "archer" else "Attack_Assassin" if class_id == "oriental_assassin" else "Attack_Trojan" if class_id == "trojan" else "Attack_SwordShield" if class_id == "warrior" else "Attack_Staff"
 if animation_player.has_animation(wanted): animation_player.play(wanted)
 elif class_id == "oriental_assassin": push_warning("Attack_DualKnives is not in approved Phase 4A library; using approved Attack_Assassin clip")
 else: push_warning("Approved attack clip missing: "+wanted)

func _spawn_floating_damage(target: Node3D,amount: int,critical: bool) -> void:
 var label := Label3D.new()
 label.name = "FloatingDamage" if target.get_node_or_null("FloatingDamage") == null else "FloatingDamage_"+str(target.get_child_count())
 label.set_meta("game_settings_role", "damage")
 var game_settings := get_node_or_null("/root/GameSettings")
 label.visible = bool(game_settings.get_setting("show_damage_numbers", true)) if game_settings != null else true
 label.text = str(amount)+("!" if critical else "")
 label.font_size = 64 if critical else 52
 label.pixel_size = 0.004
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.no_depth_test = true
 label.modulate = Color(1.0,0.18,0.12,1.0) if critical else Color(1.0,0.86,0.12,1.0)
 label.outline_size = 8
 label.position = Vector3(0,float(target.get_model_height())+0.7,0) if target.has_method("get_model_height") else Vector3(0,2.2,0)
 target.add_child(label)
 var tween := create_tween()
 tween.tween_property(label,"position:y",label.position.y+1.8,0.9)
 tween.parallel().tween_property(label,"modulate:a",0.0,0.9)
 tween.tween_callback(label.queue_free)

func _on_monster_killed(target: Node3D,state: Node) -> void:
 var data: Dictionary = target.definition
 var exp_reward := int(data.get("exp",0))
 exp_reward = int(round(float(exp_reward)*(1.0+float(_gear_bonuses().exp_bonus))))
 if target.is_king: exp_reward = int(round(exp_reward*1.5))
 if state != null:
  state.add_exp(exp_reward)
  state.add_xp(XP_PER_KILL)
  var loot_manager := get_node_or_null("/root/LootDropManager")
  var ground_drops := int(loot_manager.on_monster_killed(target)) if loot_manager != null else 0
  if loot_manager == null:
   state.add_gold(_rng.randi_range(1,3))
   _roll_loot(state)
  state.save_game()
  print("PHASE4D_COMBAT_GROUND_LOOT_LINKED: exp=",exp_reward," ground_drops=",ground_drops," gold=",state.gold," xp=+5 inventory=",state.inventory)
 var skills := get_node_or_null("/root/SkillSystem")
 if skills != null: skills.on_monster_killed()
 target.die()
 print("PHASE4C_MONSTER_KILLED_RESPAWN_STARTED: ",target.name," rest_secs=",target.rest_secs)

func _roll_loot(state: Node) -> void:
 if _rng.randf() <= 0.25: state.add_inventory_item("Plus1Stone")
 if _rng.randf() <= 0.08: state.add_inventory_item("Meteor")
 if _rng.randf() <= 0.01: state.add_inventory_item("DragonBall")

func _grant_combat_xp(delta: float) -> void:
 _xp_fraction += delta*XP_PER_SECOND
 if _xp_fraction >= 0.01:
  var value := _xp_fraction
  _xp_fraction = 0.0
  var state := get_node_or_null("/root/GameState")
  if state != null: state.add_xp(value)

func _is_alive_monster(node: Node) -> bool:
 return node != null and is_instance_valid(node) and node.has_method("is_dead") and not node.is_dead() and int(node.get("current_hp")) > 0

func _equipped_weapon_family() -> String:
 var gear := get_node_or_null("/root/GearSystem")
 if gear == null: return "unarmed"
 var item: Dictionary = gear.get_equipped("weapon")
 return String(item.get("family",item.get("id","unarmed")))

func _gear_bonuses() -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 return gear.get_combat_bonuses() if gear != null else {"attack":0,"defense":0,"magic_attack":0,"damage_reduction":0.0,"exp_bonus":0.0}

func apply_incoming_damage(hero: Node3D,raw_damage: int) -> int:
 if hero == null or raw_damage <= 0: return 0
 var bonuses: Dictionary = _gear_bonuses()
 var state := get_node_or_null("/root/GameState")
 var anima: Dictionary = state.get_anima_bonuses() if state != null else {"defense_bonus":0}
 var reduced := maxi(0,raw_damage-int(bonuses.get("defense",0))-int(anima.get("defense_bonus",0)))
 reduced = int(round(float(reduced)*(1.0-float(bonuses.get("damage_reduction",0.0)))))
 print("COMBAT_INCOMING_DAMAGE_REDUCED: raw=",raw_damage," final=",reduced," defense=",bonuses.get("defense",0)," gem_reduction=",bonuses.get("damage_reduction",0.0))
 return reduced

func _sync_anima_stats(hero: Node3D) -> void:
 var state := get_node_or_null("/root/GameState")
 if state == null: return
 var anima: Dictionary = state.get_anima_bonuses()
 var max_hp_property := false
 for property in hero.get_property_list():
  if String(property.name) == "max_hp":
   max_hp_property = true
   break
 if not max_hp_property: return
 if not hero.has_meta("_anima_base_max_hp"):
  hero.set_meta("_anima_base_max_hp",int(hero.get("max_hp")))
 var base_hp := maxi(1,int(hero.get_meta("_anima_base_max_hp")))
 var desired_hp := maxi(1,int(round(float(base_hp)*float(anima.get("hp_multiplier",1.0)))))
 var old_max := maxi(1,int(hero.get("max_hp")))
 if old_max != desired_hp:
  var current_hp := int(hero.get("current_hp")) if hero.get_property_list().any(func(p): return String(p.name)=="current_hp") else old_max
  hero.set("max_hp",desired_hp)
  if hero.get_property_list().any(func(p): return String(p.name)=="current_hp"):
   hero.set("current_hp",clampi(current_hp+(desired_hp-old_max),0,desired_hp))

func attach_loot_drop_aura(loot_node: Node3D,item_rarity: String,item_type: String) -> bool:
 if loot_node == null or not is_instance_valid(loot_node): return false
 var vfx := get_node_or_null("/root/AuraAndVFXManager")
 if vfx == null: return false
 var attached: bool = vfx.attach_loot_aura(loot_node,item_rarity,item_type)
 if attached: loot_visual_registered.emit(loot_node,item_rarity,item_type)
 return attached


func clear_cache() -> void:
 current_target = null
 _hero = null
 print("PHASE4D_COMBAT_NODE_REFERENCES_CLEARED")
