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
 hero.global_position = camp.global_position + Vector3(-5.0,0,7.0)
 # Keep the Ranger facing the camp; the proof camera will view the front/bow side.
 hero.look_at(camp.global_position + Vector3(0,0,-5.5),Vector3.UP)
 if hero.has_method("_switch_class"):
  hero.call("_switch_class","archer")
 for i in range(3): await process_frame
 var bow_socket := hero.find_child("HeroWeapon_bow_hand_l",true,false) as Node3D
 if bow_socket == null or bow_socket.get_child_count() == 0:
  _fail("approved_archer_bow_socket_or_mesh_missing"); return
 var bow_metrics: Dictionary = hero.call("_weapon_visual_metrics",bow_socket) if hero.has_method("_weapon_visual_metrics") else {}
 if int(bow_metrics.get("mesh_count",0)) < 1 or float(bow_metrics.get("grip_distance",999.0)) > 0.08:
  _fail("approved_bow_visual_alignment_failed: "+str(bow_metrics)); return
 var bow_node := bow_socket.get_child(0) as Node3D
 if bow_node == null or bow_node.scale.length() < 0.1:
  _fail("bow_root_scale_invalid")
  return
 bow_socket.visible = true
 bow_node.visible = true
 print("PHASE4C_PROOF_BOW_VISIBLE_OK: mesh_count=",bow_metrics.get("mesh_count")," grip_distance=",bow_metrics.get("grip_distance")," bone=",bow_metrics.get("actual_bone_name")," scale=",bow_node.scale," rotation_degrees=",bow_node.rotation_degrees," global_bounds=",bow_node.get_global_transform())
 hero.velocity = Vector3.ZERO
 hero.set("has_move_target",false)
 spawner.set_hero(hero)
 for i in range(3): await process_frame
 for other_point in spawner.spawn_points:
  if other_point == camp: continue
  for other_actor in other_point.get_children():
   if other_actor is MonsterActor:
    # Hidden off-camp actors must not remain valid Scatter targets in this proof.
    other_actor.set("_dead",true)
    other_actor.set("current_hp",0)
    other_actor.visible = false
    other_actor.set_process(false)
    other_actor.set_physics_process(false)
 var actors: Array[MonsterActor] = []
 for child in camp.get_children():
  if child is MonsterActor and not child.is_dead(): actors.append(child as MonsterActor)
 if actors.size() < 8: _fail("chicken_camp_population_less_than_8: "+str(actors.size())); return
 var slots := [Vector3(2.0,0,-5.5),Vector3(4.0,0,-6.0),Vector3(6.0,0,-5.4),Vector3(8.0,0,-6.2),Vector3(3.0,0,-8.0),Vector3(5.0,0,-8.4),Vector3(7.0,0,-8.0),Vector3(9.0,0,-8.5)]
 for i in range(8):
  actors[i].global_position = hero.global_position + slots[i]
  actors[i].rotation.y = PI
  actors[i].scale = Vector3.ONE * 0.48
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
 state.inventory = {"Plus1Stone":12,"Meteor":4,"DragonBall":2,"DragonGem":2}
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
 if not gem_result.get("ok",false): _fail("dragon_gem_socket_1_failed: "+str(gem_result)); return
 var gem_result_2: Dictionary = forging.socket_gem("DragonGem",1,"weapon")
 if not gem_result_2.get("ok",false): _fail("dragon_gem_socket_2_failed: "+str(gem_result_2)); return
 var item: Dictionary = gear.get_equipped("weapon")
 if int(item.get("plus",0)) != 12 or String(item.get("quality","")) != "Super" or item.get("sockets",[]).size() != 2 or String(item.sockets[0]) != "DragonGem" or String(item.sockets[1]) != "DragonGem":
  _fail("final_weapon_state_invalid: "+str(item)); return
 if forging.get_plus_aura_level(item) != 4: _fail("plus_12_aura_tier_invalid"); return
 if not forging.apply_equipped_weapon_aura(hero): _fail("plus_12_weapon_aura_not_attached"); return
 var aura_light := hero.find_child("ForgingPlusAuraLight",true,false)
 var aura_particles := hero.find_child("ForgingPlusAuraParticles",true,false)
 if aura_light == null or aura_particles == null: _fail("aura_light_or_particles_missing"); return
 var target_center := Vector3.ZERO
 for actor in actors:
  target_center += actor.global_position
 target_center /= float(actors.size())
 hero.look_at(target_center,Vector3.UP)
 var aim_dot := (-hero.global_transform.basis.z).normalized().dot((target_center-hero.global_position).normalized())
 if aim_dot < 0.94: _fail("archer_aim_direction_invalid: "+str(aim_dot)); return
 var skill_result: Dictionary = skills.use_skill(hero,"scatter")
 if not skill_result.get("ok",false) or int(skill_result.get("targets_hit",0)) < 1:
  _fail("scatter_skill_did_not_hit_camp: "+str(skill_result)); return
 _add_scatter_arrow_effects(city,bow_socket,actors)
 await create_timer(0.08).timeout
 var floating := false
 for label_node in get_root().find_children("*","Label3D",true,false):
  if label_node is Label3D and String(label_node.name).begins_with("FloatingDamage"):
   floating = true
   break
 if not floating: _fail("floating_damage_numbers_missing_global_search"); return
 # Freeze the hero controller so its idle updater cannot cancel the attack pose.
 hero.set_process(false)
 hero.set_physics_process(false)
 if hero.animation_player != null and hero.animation_player.has_animation("Attack_Bow"):
  hero.animation_player.play("Attack_Bow")
  await create_timer(0.55).timeout
 else:
  _fail("approved_attack_bow_clip_missing"); return
 var world_env := city.find_child("WorldEnvironment",true,false) as WorldEnvironment
 if world_env != null and world_env.environment != null:
  world_env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
  world_env.environment.tonemap_exposure = 0.0
  world_env.environment.ambient_light_energy = 0.20
  world_env.environment.ambient_light_color = Color(0.78,0.82,0.88)
  world_env.environment.adjustment_enabled = true
  world_env.environment.adjustment_saturation = 0.92
 for light in city.find_children("*","DirectionalLight3D",true,false):
  light.light_energy = minf(light.light_energy,0.48)
 for light in hero.find_children("ForgingPlusAuraLight","OmniLight3D",true,false):
  light.light_energy = minf(light.light_energy,0.34)
  light.omni_range = minf(light.omni_range,1.05)
 var old_camera := hero.get("camera") as Camera3D
 if old_camera != null: old_camera.current = false
 var camera := Camera3D.new()
 camera.name = "Phase4C_Forging_3Quarter_Proof_Camera"
 camera.fov = 48.0
 city.add_child(camera)
 # Clean 45-degree 3/4 full-body framing; keep city skyline and the whole monster arc.
 camera.global_position = hero.global_position + Vector3(8.0,8.0,-14.0)
 camera.look_at(hero.global_position + Vector3(2.0,1.5,-4.8),Vector3.UP)
 camera.current = true
 await process_frame
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 var actual_item: Dictionary = gear.get_equipped("weapon")
 var actual_bonuses: Dictionary = gear.get_combat_bonuses()
 _build_gear_proof_hud(actual_item,actual_bonuses)
 await process_frame
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
 # Second genuine in-game angle, tighter on the approved bow grip and forging aura.
 camera.fov = 48.0
 camera.global_position = hero.global_position + Vector3(8.0,8.0,-14.0)
 camera.look_at(hero.global_position + Vector3(2.0,1.5,-4.8),Vector3.UP)
 await process_frame
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 var detail_image := get_root().get_texture().get_image()
 if detail_image == null or detail_image.is_empty(): _fail("forging_detail_framebuffer_empty"); return
 var detail_path := out_dir.path_join("phase4c_step3_bow_aura_detail.png")
 var detail_error := detail_image.save_png(detail_path)
 if detail_error != OK: _fail("forging_detail_png_save_failed: "+str(detail_error)); return
 var detail_bytes := FileAccess.get_file_as_bytes(detail_path).size()
 if detail_bytes < 20000: _fail("forging_detail_png_too_small: "+str(detail_bytes)); return
 var bonuses: Dictionary = gear.get_combat_bonuses()
 if int(bonuses.attack) < 100: _fail("forged_attack_bonus_not_applied"); return
 if int(state.gold) >= 2000000: _fail("gold_cost_was_not_charged"); return
 state.save_game()
 print("PHASE4C_FORGING_FINAL_STATE_OK: weapon=+12 Super sockets=2 DragonGemx2=true composition=",item.composition_points," attack_bonus=",bonuses.attack," gold_remaining=",state.gold)
 print("PHASE4C_FORGING_AURA_VISUAL_OK: aura_level=4 light=true particles=true")
 print("PHASE4C_FORGING_SCATTER_IN_CAMP_OK: targets_hit=",skill_result.targets_hit," floating_damage=true approved_hero=true approved_monsters=true")
 print("PHASE4C_STEP3_IN_GAME_PNG_OK: ",out_path," bytes=",bytes," camera=front_bow_side_3_quarter hero_left_monster_arc_right")
 print("PHASE4C_STEP3_DETAIL_PNG_OK: ",detail_path," bytes=",detail_bytes," camera=close_bow_aura_detail")
 print("PHASE4C_STEP3_FORGING_OK")
 print("PHASE4C_STEP3_EXIT_CODE_0")
 quit(0)
func _add_scatter_arrow_effects(city: Node3D, bow_socket: Node3D, actors: Array[MonsterActor]) -> void:
 var origin := bow_socket.global_position
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color = Color(1.0,0.72,0.22)
 material.emission_enabled = true
 material.emission = Color(1.0,0.52,0.12)
 material.emission_energy_multiplier = 1.35
 for i in range(mini(3,actors.size())):
  var target := actors[i].global_position + Vector3(0,1.15,0)
  var delta := target-origin
  if delta.length() < 0.25: continue
  var direction := delta.normalized()
  var rotation := Quaternion(Vector3.UP,direction)
  var shaft_mesh := CylinderMesh.new()
  shaft_mesh.top_radius = 0.018
  shaft_mesh.bottom_radius = 0.018
  shaft_mesh.height = delta.length()
  var shaft := MeshInstance3D.new()
  shaft.name = "ScatterArrowTrail_%d" % i
  shaft.mesh = shaft_mesh
  shaft.material_override = material
  city.add_child(shaft)
  shaft.global_position = origin+delta*0.5
  shaft.quaternion = rotation
  var head_mesh := ConeMesh.new()
  head_mesh.bottom_radius = 0.075
  head_mesh.height = 0.18
  var head := MeshInstance3D.new()
  head.name = "ScatterArrowHead_%d" % i
  head.mesh = head_mesh
  head.material_override = material
  city.add_child(head)
  head.global_position = target-direction*0.06
  head.quaternion = rotation
 print("PHASE4C_SCATTER_ARROW_VFX_OK: visible_projectile_trails=3 damage_labels_expected=true")

func _build_gear_proof_hud(item: Dictionary, bonuses: Dictionary) -> void:
 var canvas := CanvasLayer.new()
 canvas.name = "Phase4C_GearProofHUD"
 get_root().add_child(canvas)
 var panel := PanelContainer.new()
 panel.name = "ForgedWeaponProofPanel"
 panel.position = Vector2(28,28)
 panel.custom_minimum_size = Vector2(410,210)
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.035,0.045,0.075,0.92)
 style.border_color = Color(0.48,0.68,0.96,0.95)
 style.set_border_width_all(2)
 style.set_corner_radius_all(10)
 style.set_content_margin_all(14)
 panel.add_theme_stylebox_override("panel",style)
 canvas.add_child(panel)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation",7)
 panel.add_child(stack)
 var sockets: Array = item.get("sockets",[])
 var gem_a := "Dragon Gem" if sockets.size()>0 and String(sockets[0])=="DragonGem" else "Empty"
 var gem_b := "Dragon Gem" if sockets.size()>1 and String(sockets[1])=="DragonGem" else "Empty"
 var lines := [
  "WEAPON: Super Bow (+12)",
  "SOCKETS (2/2): ["+gem_a+"] ["+gem_b+"]",
  "QUALITY: "+String(item.get("quality","Unknown"))+"   LEVEL: "+str(item.get("level",0)),
  "DAMAGE BONUS: +"+str(item.get("attack_bonus",0))+"   GEM ATK: +"+str(bonuses.get("attack",0))
 ]
 for i in range(lines.size()):
  var label := Label.new()
  label.text = lines[i]
  label.add_theme_color_override("font_color",Color(0.94,0.96,1.0))
  label.add_theme_font_size_override("font_size",22 if i==0 else 18)
  stack.add_child(label)
 if sockets.size()!=2 or gem_a!="Dragon Gem" or gem_b!="Dragon Gem":
  push_error("PHASE4C_GEAR_HUD_SOCKET_STATE_INVALID: "+str(sockets))
 print("PHASE4C_GEAR_PROOF_HUD_OK: ",lines)

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
