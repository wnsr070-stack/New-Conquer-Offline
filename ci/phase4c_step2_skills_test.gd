extends SceneTree
class DummyMonster extends Node3D:
 var current_hp: int = 100
 var max_hp: int = 100
 var definition: Dictionary = {"defense":0,"exp":1}
 var is_king: bool = false
 var dead: bool = false
 func is_dead() -> bool: return dead
 func die() -> void: dead = true; current_hp = 0
 func revive() -> void: dead = false; current_hp = max_hp
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 await process_frame
 var state := root.get_node_or_null("GameState")
 var combat := root.get_node_or_null("CombatSystem")
 var skills := root.get_node_or_null("SkillSystem")
 if state == null or combat == null or skills == null: _fail("autoload_missing"); return
 combat.set_meta("disable_random_crit",true)
 state.gold = 0
 state.exp = 0
 state.xp = 0.0
 state.xp_ready_time_left = 0.0
 state.player_data = {"class":"archer","level":40,"attack":30,"mana":100,"stamina":100}
 var hero := Node3D.new()
 hero.name = "Phase4C_TestHero"
 hero.set_meta("active_class","archer")
 hero.set_meta("max_hp",100)
 hero.set_meta("current_hp",50)
 root.add_child(hero)
 var mobs: Array[DummyMonster] = []
 for i in range(8):
  var mob := DummyMonster.new()
  mob.name = "Phase4C_SkillMob_"+str(i)
  mob.position = Vector3(0,0,-2.0-float(i)*0.4)
  root.add_child(mob)
  mobs.append(mob)
 var checks := 0
 var result: Dictionary
 result = skills.use_skill(hero,"scatter")
 if not result.get("ok",false) or int(result.get("targets_hit",0)) < 1: _fail("scatter_failed: "+str(result)); return
 checks += 1
 skills.reset_for_test()
 result = skills.use_skill(hero,"rapid_fire",mobs[0])
 if not result.get("ok",false) or int(result.get("targets_hit",0)) != 3: _fail("rapid_fire_failed: "+str(result)); return
 checks += 1
 hero.set_meta("equipped_weapon","dual_daggers")
 skills.reset_for_test()
 result = skills.use_skill(hero,"blade_tempest")
 if not result.get("ok",false) or int(result.get("targets_hit",0)) < 1: _fail("blade_tempest_failed: "+str(result)); return
 checks += 1
 result = skills.use_skill(hero,"kinetic_spark",mobs[0])
 if not result.get("ok",false): _fail("kinetic_spark_failed: "+str(result)); return
 checks += 1
 hero.set_meta("active_class","trojan")
 hero.set_meta("equipped_weapon","")
 skills.reset_for_test()
 result = skills.use_skill(hero,"fast_blade")
 if not result.get("ok",false): _fail("fast_blade_failed: "+str(result)); return
 checks += 1
 skills.reset_for_test()
 result = skills.use_skill(hero,"scent_sword")
 if not result.get("ok",false): _fail("scent_sword_failed: "+str(result)); return
 checks += 1
 skills.reset_for_test()
 result = skills.use_skill(hero,"hercules")
 if not result.get("ok",false): _fail("hercules_failed: "+str(result)); return
 checks += 1
 state.xp = 100.0; state.xp_ready_time_left = 20.0
 result = skills.use_skill(hero,"cyclone")
 if not result.get("ok",false) or not skills.buffs.has("cyclone"): _fail("cyclone_failed: "+str(result)); return
 var before_cyclone := float(skills.buffs["cyclone"])
 skills.on_monster_killed()
 if float(skills.buffs["cyclone"]) < before_cyclone+1.99: _fail("cyclone_kill_extension_failed"); return
 checks += 1
 hero.set_meta("active_class","warrior")
 skills.reset_for_test()
 result = skills.use_skill(hero,"wide_strike")
 if not result.get("ok",false): _fail("wide_strike_failed: "+str(result)); return
 checks += 1
 skills.reset_for_test()
 result = skills.use_skill(hero,"shield_bash",mobs[1])
 if not result.get("ok",false) or not mobs[1].has_meta("movement_slow_multiplier"): _fail("shield_bash_failed: "+str(result)); return
 checks += 1
 skills.reset_for_test()
 state.xp = 100.0; state.xp_ready_time_left = 20.0
 result = skills.use_skill(hero,"superman")
 if not result.get("ok",false): _fail("superman_failed: "+str(result)); return
 var before_superman := float(skills.buffs["superman"])
 skills.on_monster_killed()
 if float(skills.buffs["superman"]) < before_superman+1.99: _fail("superman_kill_extension_failed"); return
 checks += 1
 hero.set_meta("active_class","taoist")
 skills.reset_for_test()
 result = skills.use_skill(hero,"thunder",mobs[2])
 if not result.get("ok",false): _fail("thunder_failed: "+str(result)); return
 checks += 1
 skills.reset_for_test()
 hero.set_meta("current_hp",40)
 result = skills.use_skill(hero,"cure")
 if not result.get("ok",false) or int(hero.get_meta("current_hp")) <= 40: _fail("cure_failed: "+str(result)); return
 checks += 1
 skills.reset_for_test()
 result = skills.use_skill(hero,"tornado")
 if not result.get("ok",false) or int(result.get("targets_hit",0)) < 1: _fail("tornado_aoe_failed: "+str(result)); return
 checks += 1
 skills.reset_for_test()
 for i in range(mobs.size()):
  mobs[i].revive()
  mobs[i].position = Vector3(float(i)*1.2,0,-2.0)
 state.xp = 100.0; state.xp_ready_time_left = 20.0
 result = skills.use_skill(hero,"chain_lightning")
 if not result.get("ok",false) or int(result.get("targets_hit",0)) < 1 or int(result.get("targets_hit",0)) > 6: _fail("chain_lightning_failed: "+str(result)); return
 checks += 1
 hero.set_meta("active_class","archer")
 hero.set_meta("equipped_weapon","bow")
 skills.reset_for_test()
 state.xp = 100.0; state.xp_ready_time_left = 20.0
 result = skills.use_skill(hero,"fly")
 if not result.get("ok",false) or not bool(hero.get_meta("flight_active",false)) or absf(hero.position.y-3.5)>0.01: _fail("fly_failed: "+str(result)); return
 checks += 1
 skills.reset_for_test()
 state.xp = 100.0; state.xp_ready_time_left = 20.0
 result = skills.use_skill(hero,"arrow_rain")
 if not result.get("ok",false) or not skills.buffs.has("arrow_rain"): _fail("arrow_rain_failed: "+str(result)); return
 checks += 1
 print("PHASE4C_STEP2_CONQUER_SKILLS_OK: skills_checked=",checks," aoe=true cyclone_extend=+2 superman_extend=+2 cure=true chain_max=6 xp_gate=true")
 quit(0)
func _fail(reason: String) -> void:
 push_error("PHASE4C_STEP2_FAILED: "+reason)
 quit(1)
