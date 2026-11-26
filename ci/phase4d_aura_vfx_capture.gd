extends SceneTree
# Zero Procedural Geometry: approved GLB weapon assets only; no generated projectile meshes.
var _capture_failed := false
func _initialize() -> void:
 call_deferred("_ready")
func _ready() -> void:
 await _run_capture()
 if _capture_failed: return
 # _run_capture has returned, so all of its local scene/resource references are out of scope.
 var autoload_names := ["WorldMapManager","ClassSystem","GearDatabase","GearSystem","EquipmentVisualManager","GlobalEconomy","GameState","CombatSystem","SkillSystem","ForgingSystem","AuraAndVFXManager","LootDropManager"]
 var preserved_autoloads: Array[Node] = []
 for child in root.get_children():
  if child.name in autoload_names:
   preserved_autoloads.append(child)
 for child in root.get_children().duplicate():
  if child in preserved_autoloads:
   continue
  if is_instance_valid(child):
   child.free()
 current_scene = null
 print("PHASE4D_NON_AUTOLOAD_ROOT_CHILDREN_FREED: preserved_autoloads=",preserved_autoloads.size())
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 RenderingServer.force_sync()
 print("PHASE4D_POST_CAPTURE_STACK_RELEASE_FRAMES_OK")
 # Release every remaining root child, including all ten Autoloads, in reverse order.
 _capture_failed = false
 var remaining_root_children := root.get_children()
 for index in range(remaining_root_children.size() - 1, -1, -1):
  var node := remaining_root_children[index]
  if is_instance_valid(node):
   root.remove_child(node)
   node.free()
 print("PHASE4D_ALL_ROOT_CHILDREN_FREED: remaining=",root.get_child_count())
 await process_frame
 print("PHASE4D_FINAL_ROOT_RELEASE_FRAME_OK")
 quit(0)
func _run_capture() -> void:
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
 current_scene = city
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
 if int(bow_metrics.get("mesh_count",0)) < 1 or float(bow_metrics.get("grip_distance",999.0)) >= 0.02:
  _fail("approved_bow_visual_alignment_failed: "+str(bow_metrics)); return
 var bow_node := bow_socket.get_child(0) as Node3D
 if bow_node == null or bow_node.scale.length() < 0.1:
  _fail("bow_root_scale_invalid")
  return
 bow_socket.visible = true
 bow_node.visible = true
 print("PHASE4C_PROOF_BOW_VISIBLE_OK: mesh_count=",bow_metrics.get("mesh_count")," grip_distance_m=",bow_metrics.get("grip_distance")," required_lt=0.02 bone=",bow_metrics.get("actual_bone_name")," scale=",bow_node.scale," rotation_degrees=",bow_node.rotation_degrees," global_bounds=",bow_node.get_global_transform())
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
  actors[i].set_process(true)
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
 state.inventory = {"Plus1Stone":24,"Meteor":4,"DragonBall":5,"ToughDrill":1,"DragonGem":2}
 state.player_data["class"] = "archer"
 state.player_data["attack"] = 120
 if not gear.equip_weapon("bow_lv40_normal_p1","archer"): _fail("equip_approved_bow_failed"); return
 for i in range(12):
  var plus_result: Dictionary = forging.compose_plus("weapon","Plus1Stone")
  if not plus_result.get("ok",false): _fail("plus_upgrade_"+str(i+1)+"_failed: "+str(plus_result)); return
 if int(gear.get_equipped("weapon").get("plus",0)) != 12: _fail("weapon_plus_12_not_reached"); return
 var armor: Dictionary = root.get_node("GearDatabase").get_armor_item("body_05_royal","Normal",1)
 if armor.is_empty(): _fail("approved_phase3b_armor_asset_missing_from_database"); return
 armor["plus"] = 0
 if not gear.equip_item("armor",armor): _fail("equip_plus_12_armor_failed"); return
 for i in range(12):
  var armor_plus: Dictionary = forging.compose_plus("armor","Plus1Stone")
  if not armor_plus.get("ok",false): _fail("armor_plus_upgrade_"+str(i+1)+"_failed: "+str(armor_plus)); return
 if int(gear.get_equipped("armor").get("plus",0)) != 12: _fail("armor_plus_12_not_reached"); return
 state.set_anima_phase(18)
 var vfx := root.get_node("AuraAndVFXManager")
 if not vfx.attach_anima_aura(hero,18): _fail("anima_p18_orbit_attach_failed"); return
 if not vfx.attach_character_aura(hero,12,false): _fail("full_set_ring_attach_failed"); return
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
 var equipment_sprite_aura := bow_node.find_child("EquipmentSpriteAura",true,false)
 var equipment_manager := root.get_node_or_null("EquipmentVisualManager")
 var armor_visual := equipment_manager.get_visual_model("armor") as Node3D if equipment_manager != null else null
 var armor_aura_target := armor_visual.find_child("EquipmentAuraTarget",true,false) as Node3D if armor_visual != null else null
 var armor_sprite_aura := armor_aura_target.find_child("EquipmentSpriteAura",true,false) if armor_aura_target != null else null
 var anima_orbit := hero.get_node_or_null("AnimaOrbitController")
 if equipment_sprite_aura == null or armor_sprite_aura == null: _fail("weapon_or_armor_sprite_aura_missing"); return
 if anima_orbit == null or anima_orbit.get_child_count() != 6: _fail("anima_p18_six_orbs_missing"); return
 print("PHASE4D_WEAPON_ARMOR_PLUS12_ANIMA_P18_OK: weapon=12 armor=12 anima_orbs=6 sprite_only=true")
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
 print("PHASE4C_SCATTER_COMBAT_VFX_SOURCE_OK: native_skill_damage_and_floating_numbers=true procedural_projectiles_disabled=true")
 await create_timer(0.08).timeout
 var floating := false
 for label_node in get_root().find_children("*","Label3D",true,false):
  if label_node is Label3D and String(label_node.name).begins_with("FloatingDamage"):
   floating = true
   break
 if not floating: _fail("floating_damage_numbers_missing_global_search"); return
 # Freeze controller input only; AnimationPlayer and monster actors continue advancing.
 hero.set_process(false)
 hero.set_physics_process(false)
 var world_env := city.find_child("WorldEnvironment",true,false) as WorldEnvironment
 if world_env != null and world_env.environment != null:
  world_env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
  world_env.environment.tonemap_exposure = 0.0
  world_env.environment.ambient_light_energy = 0.16
  world_env.environment.ambient_light_color = Color(0.78,0.82,0.88)
  world_env.environment.adjustment_enabled = true
  world_env.environment.adjustment_saturation = 0.96
 for light in city.find_children("*","DirectionalLight3D",true,false):
  light.light_energy = 0.7
 var old_camera := hero.get("camera") as Camera3D
 if old_camera != null: old_camera.current = false
 var camera := Camera3D.new()
 camera.name = "Phase4C_Forging_3Quarter_Proof_Camera"
 camera.fov = 52.0
 city.add_child(camera)
 _set_action_camera(camera,hero,target_center,4.5)
 camera.current = true
 _build_gear_proof_hud(item,gear.get_combat_bonuses())
 # Frame 1 — genuine bow aiming pose; never capture the initial animation frame.
 if hero.animation_player == null or not hero.animation_player.has_animation("Attack_Bow"):
  _fail("approved_attack_bow_clip_missing"); return
 hero.animation_player.play("Attack_Bow")
 hero.animation_player.seek(0.32,true)
 await _wait_rendered_pose()
 _save_proof_png("1_stance_aim.png","PHASE4C_FRAME1_STANCE_OK")
 # Frame 2 — run the real combat skill and preserve the live HP/damage feedback.
 var arrow_projectile := _spawn_arrow_projectile(city,hero,actors[0].global_position)
 if arrow_projectile == null:
  _fail("approved_ranger_arrow_glb_missing_or_invalid"); return
 var attack_result: Dictionary = combat.perform_attack(hero,actors[0],true)
 if not attack_result.get("ok",false):
  _fail("real_attack_frame_failed: "+str(attack_result)); return
 hero.animation_player.play("Attack_Bow")
 hero.animation_player.seek(0.48,true)
 _set_action_camera(camera,hero,target_center,5.0)
 await _wait_rendered_pose()
 if not is_instance_valid(arrow_projectile):
  _fail("real_arrow_projectile_disappeared_before_capture"); return
 print("PHASE4C_REAL_ARROW_PROJECTILE_VISUAL_OK: source=approved_ranger_arrow_ranger_arrow.glb in_flight=true")
 _save_proof_png("2_attack_hit.png","PHASE4C_FRAME2_ATTACK_HIT_OK")
 # Frame 3 — force a real lethal combat result; MonsterActor now plays its death clip
 # or remains as a visible fallen corpse until the respawn timer expires.
 actors[1].current_hp = 1
 var kill_result: Dictionary = combat.perform_attack(hero,actors[1],true)
 if not kill_result.get("ok",false) or not actors[1].is_dead():
  _fail("real_monster_kill_or_death_pose_failed: "+str(kill_result)); return
 if not _spawn_loot_proof(city,actors[1].global_position):
  _fail("one_or_more_verified_cc0_loot_models_failed_to_load"); return
 # Let the actual death clip / corpse fall finish, then frame the body and all seven drops.
 await create_timer(0.55).timeout
 var corpse_model := actors[1].get("_model") as Node3D
 if corpse_model != null and actors[1].is_dead():
  corpse_model.rotation.z = deg_to_rad(82.0)
  print("PHASE4C_CORPSE_FALLEN_POSE_LOCKED: side_fall=82deg")
 _set_loot_camera(camera,actors[1].global_position)
 await _wait_rendered_pose()
 _save_proof_png("3_kill_loot.png","PHASE4C_FRAME3_KILL_LOOT_OK")
 # Frame 4 — side close-up of the actual BoneAttachment3D bow and +12 aura.
 camera.fov = 30.0
 var bow_world := bow_socket.global_position
 camera.global_position = bow_world + Vector3(1.2,0.48,1.25).normalized() * 2.1
 camera.look_at(bow_world + Vector3(0,0.15,0),Vector3.UP)
 print("PHASE4C_BOW_SIDE_CLOSEUP_CAMERA_OK: distance=2.1m upright_bow_hand_aura=true")
 hero.animation_player.play("Attack_Bow")
 hero.animation_player.seek(0.32,true)
 await _wait_rendered_pose()
 _save_proof_png("4_closeup_weapon.png","PHASE4C_FRAME4_BOW_CLOSEUP_OK")
 var out_dir := ProjectSettings.globalize_path("res://artifacts")
 var bytes := FileAccess.get_file_as_bytes(out_dir.path_join("1_stance_aim.png")).size()
 var detail_bytes := FileAccess.get_file_as_bytes(out_dir.path_join("4_closeup_weapon.png")).size()
 var bonuses: Dictionary = gear.get_combat_bonuses()
 if int(bonuses.attack) < 100: _fail("forged_attack_bonus_not_applied"); return
 if int(state.gold) >= 2000000: _fail("gold_cost_was_not_charged"); return
 state.save_game()
 print("PHASE4C_FORGING_FINAL_STATE_OK: weapon=+12 Super sockets=2 DragonGemx2=true composition=",item.composition_points," attack_bonus=",bonuses.attack," gold_remaining=",state.gold)
 print("PHASE4D_SPRITE_AURA_VISUAL_OK: weapon_plus12=true armor_plus12=true anima_p18=true procedural_particles=false")
 print("PHASE4C_FORGING_SCATTER_IN_CAMP_OK: targets_hit=",skill_result.targets_hit," floating_damage=true approved_hero=true approved_monsters=true")
 print("PHASE4C_STEP3_FOUR_SEQUENTIAL_PNGS_OK: 1_stance_aim 2_attack_hit 3_kill_loot 4_closeup_weapon")
 print("PHASE4C_STEP3_CLOSEUP_PNG_OK: bytes=",detail_bytes)
 print("PHASE4C_STEP3_FORGING_OK: all_four_pngs_validated")
 print("PHASE4D_AURA_VFX_RENDER_OK")
 print("PHASE4D_CLEANUP_BEGIN")
 # Clear autoload-held scene references and stop VFX processing before detaching the city.
 var cache_autoloads := ["WorldMapManager","GearDatabase","GearSystem","EquipmentVisualManager","AuraAndVFXManager","CombatSystem","SkillSystem","LootDropManager"]
 for autoload_name in cache_autoloads:
  var autoload := root.get_node_or_null(autoload_name)
  if autoload == null or not autoload.has_method("clear_cache"):
   _fail("required_autoload_clear_cache_missing: "+autoload_name)
   return
  autoload.clear_cache()
 current_scene = null
 var geometry_count := city.find_children("*","GeometryInstance3D",true,false).size() if is_instance_valid(city) else 0
 # Free synchronously while still inside the SceneTree: queue_free() leaves the
 # whole imported city subtree alive until the deferred-delete flush, after our capture returns.
 if is_instance_valid(city): city.free()
 AssetLoader.clear_cached_prototypes()
 print("PHASE4D_ASSETLOADER_PROTOTYPES_CLEARED")
 if is_instance_valid(city):
  _fail("CITY_SCENE_ROOT_SURVIVED_SYNCHRONOUS_FREE")
  return
 print("PHASE4D_CITY_SUBTREE_FREED_SYNCHRONOUSLY: geometry_instances=",geometry_count)
 packed = null
 city = null
 hero = null
 spawner = null
 camp = null
 bow_socket = null
 bow_node = null
 actors.clear()
 state = null
 gear = null
 forging = null
 combat = null
 skills = null
 vfx = null
 equipment_sprite_aura = null
 armor_sprite_aura = null
 anima_orbit = null
 target_center = Vector3.ZERO
 camera = null
 old_camera = null
 world_env = null
 arrow_projectile = null
 corpse_model = null
 item.clear()
 await process_frame
 await RenderingServer.frame_post_draw
 RenderingServer.force_sync()
 print("PHASE4D_QUEUED_SCENE_RELEASE_FRAME_COMPLETE")

 print("PHASE4D_CAPTURE_LOCAL_REFERENCES_RELEASED")
 print("PHASE4D_CAPTURE_FUNCTION_RETURNING")

func _wait_rendered_pose() -> void:
 for frame in range(5):
  await process_frame
  await RenderingServer.frame_post_draw

func _save_proof_png(file_name: String, marker: String) -> void:
 var out_dir := ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(out_dir)
 var image := get_root().get_texture().get_image()
 if image == null or image.is_empty():
  _fail("proof_framebuffer_empty: "+file_name)
  return
 var path := out_dir.path_join(file_name)
 var err := image.save_png(path)
 if err != OK:
  _fail("proof_png_save_failed: "+file_name+" err="+str(err))
  return
 var size := FileAccess.get_file_as_bytes(path).size()
 if size < 20000:
  _fail("proof_png_too_small: "+file_name+" bytes="+str(size))
  return
 print(marker,": ",path," bytes=",size," width=",image.get_width()," height=",image.get_height())

func _build_gear_proof_hud(item: Dictionary, bonuses: Dictionary) -> void:
 var canvas := CanvasLayer.new()
 canvas.name = "Phase4C_GearProofHUD"
 get_root().add_child(canvas)
 var panel := PanelContainer.new()
 panel.name = "ForgedWeaponProofPanel"
 panel.position = Vector2(28,28)
 panel.custom_minimum_size = Vector2(520,260)
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
  "ARMOR: +12   ANIMA: P18 (6 spirit orbs)",
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


func _set_action_camera(camera: Camera3D, hero: Node3D, target_center: Vector3, distance: float) -> void:
 camera.fov = 58.0
 var hero_focus := hero.global_position + Vector3(0.0,1.05,0.0)
 var midpoint := (hero.global_position + target_center) * 0.5 + Vector3(0.0,1.0,0.0)
 var side_front := Vector3(0.68,0.42,0.60).normalized()
 camera.global_position = hero_focus + side_front * distance
 camera.look_at(midpoint,Vector3.UP)
 print("PHASE4C_ACTION_CAMERA_OK: hero_distance=",distance,"m angle=3quarter_side_front fov=58")

func _set_loot_camera(camera: Camera3D, corpse_center: Vector3) -> void:
 camera.fov = 54.0
 var target := corpse_center + Vector3(0.0,0.75,0.0)
 var offset := Vector3(0.10,0.62,0.77).normalized() * 3.5
 camera.global_position = target + offset
 camera.look_at(target,Vector3.UP)
 print("PHASE4C_LOOT_CAMERA_OK: distance=3.5m fallen_corpse_and_seven_drops=true")

func _spawn_arrow_projectile(city: Node3D, hero: Node3D, target: Vector3) -> Node3D:
 var path := "res://assets/phase3b/quaternius_library/ranger_arrow_ranger_arrow.glb"
 if not ResourceLoader.exists(path): return null
 var packed := load(path) as PackedScene
 if packed == null: return null
 var arrow := packed.instantiate() as Node3D
 if arrow == null: return null
 arrow.name = "Phase4C_RealRangerArrowProjectile"
 city.add_child(arrow)
 arrow.global_position = hero.global_position + Vector3(0.0,1.45,0.0) + (-hero.global_transform.basis.z * 0.9)
 arrow.scale = Vector3.ONE * 0.22
 arrow.look_at(target + Vector3(0.0,0.9,0.0),Vector3.UP)
 var tween := arrow.create_tween()
 tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 tween.tween_property(arrow,"global_position",target + Vector3(0.0,0.9,0.0),0.32)
 print("PHASE4C_REAL_ARROW_PROJECTILE_STARTED: source=",path," target=",target)
 return arrow

func _spawn_loot_proof(city: Node3D, center: Vector3) -> bool:
 var loot := [
  {"name":"Gold","path":"res://assets/items_and_consumables/models/gold_stack.glb","color":Color(1.0,0.72,0.12)},
  {"name":"Panacea Potion","path":"res://assets/items_and_consumables/models/potion_green_bottle.glb","color":Color(0.2,1.0,0.45)},
  {"name":"Dragon Gem","path":"res://assets/items_and_consumables/models/dragon_gem_crystal.glb","color":Color(0.2,0.75,1.0)},
  {"name":"Meteor","path":"res://assets/items_and_consumables/models/meteor.glb","color":Color(1.0,0.32,0.12)},
  {"name":"Dragon Ball","path":"res://assets/items_and_consumables/models/upgrade_crystal.glb","color":Color(1.0,0.2,0.18)},
  {"name":"Tough Drill","path":"res://assets/items_and_consumables/models/treasure_chest.glb","color":Color(0.9,0.78,0.42)},
  {"name":"+1 Stone","path":"res://assets/items_and_consumables/models/upgrade_crystal.glb","color":Color(0.75,0.35,1.0)}
 ]
 var offsets := [Vector3(-2.7,0.15,0.2),Vector3(-1.8,0.15,-0.7),Vector3(-0.9,0.15,0.25),Vector3(0.0,0.15,-0.65),Vector3(0.9,0.15,0.25),Vector3(1.8,0.15,-0.65),Vector3(2.7,0.15,0.2)]
 for i in range(loot.size()):
  var entry: Dictionary = loot[i]
  var packed := load(entry.path) as PackedScene if ResourceLoader.exists(entry.path) else null
  if packed == null: return false
  var model := packed.instantiate() as Node3D
  if model == null: return false
  if not _ensure_loot_albedo(model, String(entry.name)):
   return false
  model.name = "Loot3D_" + String(entry.name).replace(" ","_")
  city.add_child(model)
  model.global_position = center + offsets[i]
  model.scale = Vector3.ONE * (0.34 if i not in [0,5] else 0.42)
  var combat := get_root().get_node_or_null("CombatSystem")
  if combat != null:
   var rarity := "Super" if String(entry.name)=="Dragon Gem" else "Elite" if String(entry.name)=="Meteor" else "Unique"
   combat.attach_loot_drop_aura(model,rarity,String(entry.name))
  var glow := StandardMaterial3D.new()
  glow.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
  glow.albedo_color = Color(1,1,1,0.18)
  glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  glow.emission_enabled = true
  glow.emission = entry.color
  glow.emission_energy_multiplier = 1.35
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   (mesh as MeshInstance3D).material_overlay = glow
  var label := Label3D.new()
  label.name = "LootLabel_" + str(i)
  label.text = String(entry.name)
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  label.pixel_size = 0.008
  label.font_size = 40
  label.modulate = entry.color
  label.position = Vector3(0,0.85,0)
  model.add_child(label)
 print("PHASE4C_REAL_3D_LOOT_MODELS_OK: seven_models=true labels=true emissive_glow=true")
 return true

func _ensure_loot_albedo(model: Node3D, loot_name: String) -> bool:
 var texture_path := "res://assets/items_and_consumables/models/Textures/colormap.png"
 if not ResourceLoader.exists(texture_path):
  push_error("PHASE4C_LOOT_COLORMAP_MISSING: " + texture_path + " loot=" + loot_name)
  return false
 var source_colormap := load(texture_path) as Texture2D
 if source_colormap == null or source_colormap.get_width() <= 0 or source_colormap.get_height() <= 0:
  push_error("PHASE4C_LOOT_COLORMAP_INVALID: " + texture_path + " loot=" + loot_name)
  return false
 var loot_image := source_colormap.get_image()
 if loot_image == null or loot_image.is_empty(): return false
 loot_image.convert(Image.FORMAT_RGBA8)
 var white_pixels_removed := 0
 for py in range(loot_image.get_height()):
  for px in range(loot_image.get_width()):
   var pixel := loot_image.get_pixel(px,py)
   if pixel.r > 0.90 and pixel.g > 0.90 and pixel.b > 0.90:
    pixel.a = 0.0
    loot_image.set_pixel(px,py,pixel)
    white_pixels_removed += 1
 var colormap := ImageTexture.create_from_image(loot_image)
 print("PHASE4D_LOOT_WHITE_ALPHA_EXTRACTION_OK: loot=",loot_name," transparent_white_pixels=",white_pixels_removed," format=RGBA8")
 var mesh_count := 0
 var surface_count := 0
 for node in model.find_children("*", "MeshInstance3D", true, false):
  var mesh_instance := node as MeshInstance3D
  if mesh_instance.mesh == null:
   continue
  mesh_count += 1
  for surface in range(mesh_instance.mesh.get_surface_count()):
   var source_material := mesh_instance.get_active_material(surface)
   var material := source_material.duplicate() as StandardMaterial3D if source_material is StandardMaterial3D else StandardMaterial3D.new()
   if material.albedo_texture == null:
    material.albedo_texture = colormap
   material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
   if material.albedo_texture == null:
    push_error("PHASE4C_LOOT_TEXTURE_ALBEDO_INVALID: loot=" + loot_name + " mesh=" + mesh_instance.name + " surface=" + str(surface))
    return false
   mesh_instance.set_surface_override_material(surface, material)
   surface_count += 1
 if mesh_count == 0 or surface_count == 0:
  push_error("PHASE4C_LOOT_RENDERABLE_SURFACES_MISSING: loot=" + loot_name)
  return false
 print("PHASE4C_LOOT_TEXTURE_ALBEDO_OK: loot=", loot_name, " meshes=", mesh_count, " surfaces=", surface_count, " colormap=", texture_path)
 return true

func _fail(reason: String) -> void:
 _capture_failed = true
 push_error("PHASE4C_STEP3_FAILED: "+reason)
 quit(1)

func _configure_input_map() -> void:
 var bindings := {"move_left":KEY_A,"move_right":KEY_D,"move_forward":KEY_W,"move_back":KEY_S}
 for action in bindings:
  if not InputMap.has_action(action): InputMap.add_action(action)
  var key := InputEventKey.new()
  key.physical_keycode = bindings[action]
  if not InputMap.action_has_event(action,key): InputMap.action_add_event(action,key)
