extends Node
signal target_changed(target: Node3D)
signal damage_dealt(target: Node3D, amount: int, critical: bool)
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
 var state := get_node_or_null("/root/GameState")
 var player_data: Dictionary = state.player_data if state != null else {}
 var attack := int(player_data.get("attack",100))
 var defense := int(target.definition.get("defense",0))
 var critical := force_critical or (not bool(get_meta("disable_random_crit",false)) and _rng.randf() < CRITICAL_CHANCE)
 var multiplier := float(hero.get_meta("physical_damage_multiplier",1.0))
 var raw_damage := maxi(1,attack-defense)
 var damage := int(round(float(raw_damage)*(CRITICAL_MULTIPLIER if critical else 1.0)*multiplier))
 return _apply_damage(target,damage,critical,hero,"basic_attack")

func apply_skill_damage(hero: Node3D,target: Node3D,skill_multiplier: float,skill_id: String) -> Dictionary:
 if hero == null or not _is_alive_monster(target): return {"ok":false,"reason":"invalid_target"}
 var state := get_node_or_null("/root/GameState")
 var player_data: Dictionary = state.player_data if state != null else {}
 var attack := int(player_data.get("attack",100))
 var defense := int(target.definition.get("defense",0))
 var physical := skill_id not in ["thunder","tornado","chain_lightning","arrow_rain"]
 var buff_multiplier := float(hero.get_meta("physical_damage_multiplier",1.0)) if physical else 1.0
 var damage := maxi(1,int(round(float(maxi(1,attack-defense))*skill_multiplier*buff_multiplier)))
 return _apply_damage(target,damage,false,hero,skill_id)

func _apply_damage(target: Node3D,damage: int,critical: bool,hero: Node3D,source: String) -> Dictionary:
 var hp_before := int(target.current_hp)
 target.current_hp = maxi(0,hp_before-damage)
 var actual_damage := hp_before-int(target.current_hp)
 _spawn_floating_damage(target,actual_damage,critical)
 damage_dealt.emit(target,actual_damage,critical)
 combat_active = true
 current_target = target
 print("PHASE4C_DAMAGE_APPLIED: source=",source," target=",target.name," damage=",actual_damage," critical=",critical," hp=",target.current_hp,"/",target.max_hp)
 if target.current_hp <= 0: _on_monster_killed(target,get_node_or_null("/root/GameState"))
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
 if target.is_king: exp_reward = int(round(exp_reward*1.5))
 if state != null:
  state.add_exp(exp_reward)
  state.add_gold(_rng.randi_range(1,3))
  state.add_xp(XP_PER_KILL)
  _roll_loot(state)
  state.save_game()
  print("PHASE4C_LOOT_REWARD: exp=",exp_reward," gold=",state.gold," xp=+5 inventory=",state.inventory)
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
