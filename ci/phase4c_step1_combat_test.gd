extends SceneTree

const MonsterActorScript = preload("res://scripts/MonsterActor.gd")
const ChickenModel = "res://assets/phase3b/monsters/normal/chicken.glb"

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 await process_frame
 var state := root.get_node_or_null("GameState")
 var combat := root.get_node_or_null("CombatSystem")
 if state == null or combat == null:
  _fail("autoload_missing")
  return
 combat.set_meta("disable_random_crit",true)
 state.gold = 0
 state.exp = 0
 state.xp = 0.0
 state.xp_ready_time_left = 0.0
 state.inventory.clear()
 state.player_data = {"class":"archer","level":1,"attack":20,"defense":0,"equipped":{}}
 var hero := Node3D.new()
 hero.name = "Phase4C_TestHero"
 # Use a minimal combat-facing test actor; approved Phase 4A hero files remain untouched.
 hero.set_meta("active_class","archer")
 hero.set_meta("animation_player",null)
 hero.set_meta("attack",20)
 root.add_child(hero)
 hero.global_position = Vector3.ZERO
 var chicken := MonsterActorScript.new() as Node3D
 chicken.name = "Phase4C_TestChicken"
 root.add_child(chicken)
 var definition := {"id":"Chicken","level":1,"hp":33,"damage":8,"exp":15,"rest_secs":0.45}
 if not chicken.configure(definition,ChickenModel,false,false,Vector3(2,0,0)):
  _fail("chicken_configure_failed")
  return
 chicken.global_position = Vector3(2,0,0)
 var first: Dictionary = combat.perform_attack(hero,chicken,true)
 if not first.get("ok",false) or int(first.get("hp",-1)) != 3 or int(first.get("damage",0)) != 30:
  _fail("first_hit_or_hp_failed: "+str(first))
  return
 if chicken.get_node_or_null("FloatingDamage") == null:
  _fail("floating_damage_label_missing")
  return
 combat._grant_combat_xp(1.0)
 var second: Dictionary = combat.perform_attack(hero,chicken,false)
 if not second.get("ok",false) or not chicken.is_dead():
  _fail("chicken_kill_or_respawn_not_started: "+str(second))
  return
 if state.exp != 15 or state.gold < 1 or state.gold > 3:
  _fail("exp_or_gold_reward_failed exp="+str(state.exp)+" gold="+str(state.gold))
  return
 if state.xp < 8.9:
  _fail("xp_increment_failed: "+str(state.xp))
  return
 if chicken.get_node_or_null("AutoRespawn") == null or (chicken.get_node("AutoRespawn") as Timer).is_stopped():
  _fail("auto_respawn_timer_not_started")
  return
 await create_timer(0.65).timeout
 if chicken.is_dead() or int(chicken.current_hp) != int(chicken.max_hp):
  _fail("auto_respawn_failed")
  return
 await create_timer(0.5).timeout
 print("PHASE4C_STEP1_COMBAT_LOOP_OK: chicken_hp=33->3->0 damage_label=true exp=15 gold=",state.gold," xp=",state.xp," respawn=true")
 quit(0)

func _fail(reason: String) -> void:
 push_error("PHASE4C_STEP1_FAILED: "+reason)
 quit(1)
