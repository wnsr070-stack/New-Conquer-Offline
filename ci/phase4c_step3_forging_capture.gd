extends SceneTree
const SpawnerScript = preload("res://scripts/MonsterSpawner.gd")
const MonsterActorScript = preload("res://scripts/MonsterActor.gd")
func _initialize() -> void:
 call_deferred("_run")
func _run() -> void:
 _configure_input_map()
 get_root().size = Vector2i(1600,1000)
 await process_frame
 var manager := root.get_node_or_null("WorldMapManager")
 if manager == null: _fail("world_map_manager_missing"); return
 manager.set("current_city","TwinCity")
 var packed := load("res://scenes/TwinCity.tscn") as PackedScene
 if packed == null: _fail("twin_city_scene_missing"); return
 var city := packed.instantiate() as Node3D
 root.add_child(city)
 var hero: CharacterBody3D
 var spawner: MonsterSpawner
 for i in range(240):
  await process_frame
  hero = city.find_child("PlayableHero",true,false) as CharacterBody3D
  spawner = city.find_child("MonsterSpawner",true,false) as MonsterSpawner
  if hero != null and spawner != null and hero.get("hero_model") != null: break
 if hero == null or spawner == null or hero.get("hero_model") == null:
  _fail("approved_hero_or_monster_spawner_not_ready"); return
 var camp: Node3D
 for point in spawner.spawn_points:
  if String(point.get_meta("spawn_kind","")) == "monster_camp" and String(point.get_meta("monster_id","")) == "Chicken":
   camp = point
   break
 if camp == null: _fail("chicken_camp_missing"); return
 hero.global_position = camp.global_position + Vector3(-1.5,0,4.5)
 hero.look_at(hero.global_position+Vector3(0,0,-1),Vector3.UP)
 hero.velocity = Vector3.ZERO
 hero.set("has_move_target",false)
 spawner.set_hero(hero)
 for i in range(3): await process_frame
 for other_point in spawner.spawn_points:
  if other_point == camp: continue
  for other_actor in other_point.get_children():
   if other_actor is MonsterActor:
    other_actor.visible = false
    other_actor.set_process(false)
    other_actor.set_physics_process(false)
 var actors: Array[MonsterActor] = []
 for child in camp.get_children():
  if child is MonsterActor and not child.is_dead(): actors.append(child as MonsterActor)
 if actors.size() < 8: _fail("chicken_camp_population_less_than_8: "+str(actors.size())); return
 var slots := [Vector3(-2.4,0,-4.2),Vector3(-1.7,0,-5.1),Vector3(-0.9,0,-4.6),Vector3(-0.2,0,-5.5),Vector3(0.5,0,-4.5),Vector3(1.2,0,-5.4),Vector3(1.9,0,-4.6),Vector3(2.5,0,-5.2)]
 for i in range(8):
  actors[i].global_position = hero.global_position + slots[i]
  actors[i].max_hp = 5000
  actors[i].current_hp = 5000
  actors[i].set("_target",actors[i].global_position)
  actors[i].set_process(false)
  actors[i].set_physics_process(false)
  var plate := actors[i].get_nameplate()
  if plate != null: plate.visible = i < 2
 for i in range(8,actors.size()):
  actors[i].visible = false
  actors[i].set_process(false)
  actors[i].set_physics_process(false)
 var state := root.get_node("GameState")
 var gear := root.get_node("GearSystem")
 var forging := root.get_node("ForgingSystem")
 var combat := root.get_node("CombatSystem")
 var skills := root.get_node("SkillSystem")
 state.gold = 2000000
 state.inventory = {"Plus1Stone":12,"Meteor":4,"DragonBall":2,"DragonGem":1}
 state.player_data["class"] = "archer"
 state.player_data["attack"] = 120
 if not gear.equip_weapon("bow_lv40_normal_p1","archer"): _fail("equip_approved_bow_failed"); return
 for i in range(12):
  var plus_result: Dictionary = forging.compose_plus("weapon","Plus1Stone")
  if not plus_result.get("ok",false): _fail("plus_upgrade_"+str(i+1)+"_failed: "+str(plus_result)); return
 if int(gear.get_equipped("weapon").get("plus",0)) != 12: _fail("plus_12_not_reached"); return
 for i in range(4):
  var quality_result: Dictionary = forging.upgrade_quality("weapon")
  if not quality_result.get("ok",false): _fail("quality_upgrade_"+str(i+1)+"_failed: "+str(quality_result)); return
 if String(gear.get_equipped("weapon").get("quality","")) != "Super": _fail("super_quality_not_reached"); return
 for i in range(2):
  var socket_result: Dictionary = forging.open_socket("weapon")
  if not socket_result.get("ok",false): _fail("socket_"+str(i+1)+"_failed: "+str(socket_result)); return
 var gem_result: Dictionary = forging.socket_gem("DragonGem",0,"weapon")
 if not gem_result.get("ok",false): _fail("dragon_gem_socket_failed: "+str(gem_result)); return
 var item: Dictionary = gear.get_equipped("weapon")
 if int(item.get("plus",0)) != 12 or String(item.get("quality","")) != "Super" or item.get("sockets",[]).size() != 2 or String(item.sockets[0]) != "DragonGem":
  _fail("final_weapon_state_invalid: "+str(item)); return
 if forging.get_plus_aura_level(item) != 4: _fail("plus_12_aura_tier_invalid"); return
 if not forging.apply_equipped_weapon_aura(hero): _fail("plus_12_weapon_aura_not_attached"); return
 var aura_light := hero.find_child("ForgingPlusAuraLight",true,false)
 var aura_particles := hero.find_child("ForgingPlusAuraParticles",true,false)
 if aura_light == null or aura_particles == null: _fail("aura_light_or_particles_missing"); return
 if hero.animation_player != null and hero.animation_player.has_animation("Attack_Bow"):
  hero.animation_player.play("Attack_Bow")
 var skill_result: Dictionary = skills.use_skill(hero,"scatter")
 if not skill_result.get("ok",false) or int(skill_result.get("targets_hit",0)) < 1:
  _fail("scatter_skill_did_not_hit_camp: "+str(skill_result)); return
 var floating := false
 for actor in actors:
  if actor.get_child_count() > 0 and actor.find_child("FloatingDamage",true,false) != null: floating = true
 if not floating:
  for actor in actors:
   if actor.get_child_count() > 0:
    for child in actor.get_children():
     if child is Label3D and String(child.name).begins_with("FloatingDamage"): floating = true
 if not floating: _fail("floating_damage_numbers_missing"); return
 var old_camera := hero.get("camera") as Camera3D
 if old_camera != null: old_camera.current = false
 var camera := Camera3D.new()
 camera.name = "Phase4C_Forging_3Quarter_Proof_Camera"
 camera.fov = 45.0
 city.add_child(camera)
 camera.global_position = hero.global_position + Vector3(-5.0,3.5,6.0)
 camera.look_at(hero.global_position + Vector3(0.0,1.15,-1.8),Vector3.UP)
 camera.current = true
 await process_frame
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 var image := get_root().get_texture().get_image()
 if image == null or image.is_empty(): _fail("forging_proof_framebuffer_empty"); return
 var out_dir := ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(out_dir)
 var out_path := out_dir.path_join("phase4c_step3_plus12_super_2socket_dragon_gem_scatter.png")
 var save_error := image.save_png(out_path)
 if save_error != OK: _fail("forging_png_save_failed: "+str(save_error)); return
 var bytes := FileAccess.get_file_as_bytes(out_path).size()
 if bytes < 20000: _fail("forging_png_too_small: "+str(bytes)); return
 var bonuses: Dictionary = gear.get_combat_bonuses()
 if int(bonuses.attack) < 100: _fail("forged_attack_bonus_not_applied"); return
 if int(state.gold) >= 2000000: _fail("gold_cost_was_not_charged"); return
 state.save_game()
 print("PHASE4C_FORGING_FINAL_STATE_OK: weapon=+12 Super sockets=2 DragonGem=true composition=",item.composition_points," attack_bonus=",bonuses.attack," gold_remaining=",state.gold)
 print("PHASE4C_FORGING_AURA_VISUAL_OK: aura_level=4 light=true particles=true")
 print("PHASE4C_FORGING_SCATTER_IN_CAMP_OK: targets_hit=",skill_result.targets_hit," floating_damage=true approved_hero=true approved_monsters=true")
 print("PHASE4C_STEP3_IN_GAME_PNG_OK: ",out_path," bytes=",bytes," camera=close_3_quarter")
 print("PHASE4C_STEP3_FORGING_OK")
 print("PHASE4C_STEP3_EXIT_CODE_0")
 quit(0)
func _fail(reason: String) -> void:
 push_error("PHASE4C_STEP3_FAILED: "+reason)
 quit(1)

func _configure_input_map() -> void:
 var bindings := {"move_left":KEY_A,"move_right":KEY_D,"move_forward":KEY_W,"move_back":KEY_S}
 for action in bindings:
  if not InputMap.has_action(action): InputMap.add_action(action)
  var key := InputEventKey.new()
  key.physical_keycode = bindings[action]
  if not InputMap.action_has_event(action,key): InputMap.action_add_event(action,key)
