extends SceneTree
## Policy-compliant Phase 4D portrait proof:
## Armor/headgear remain icon+stats only; Ranger Hood is the hero's sole head appearance.
func _initialize() -> void:
 call_deferred("_run_capture")

func _run_capture() -> void:
 root.size = Vector2i(1600,1000)
 await process_frame
 var map_manager := root.get_node_or_null("WorldMapManager")
 if map_manager == null:
  _fail("world_map_manager_missing")
  return
 map_manager.set("current_city","TwinCity")
 var packed := load("res://scenes/TwinCity.tscn") as PackedScene
 if packed == null:
  _fail("twin_city_scene_missing")
  return
 var city := packed.instantiate() as Node3D
 root.add_child(city)
 current_scene = city
 var hero: CharacterBody3D
 for frame in range(240):
  await process_frame
  hero = city.find_child("PlayableHero",true,false) as CharacterBody3D
  if hero != null and hero.get("hero_model") != null:
   break
 if hero == null or hero.get("hero_model") == null:
  _fail("approved_hero_not_ready")
  return
 hero.call("_switch_class","archer")
 for frame in range(5):
  await process_frame
 var gear: Node = root.get_node_or_null("GearSystem")
 var database: Node = root.get_node_or_null("GearDatabase")
 var vfx: Node = root.get_node_or_null("AuraAndVFXManager")
 if gear == null or database == null or vfx == null:
  _fail("gear_or_aura_autoload_missing")
  return
 if not gear.equip_weapon("bow_lv40_normal_p1","archer"):
  _fail("approved_bow_equip_failed")
  return
 var bow_item: Dictionary = gear.get_equipped("weapon")
 bow_item["plus"] = 12
 bow_item["quality"] = "Super"
 gear.update_equipped_item("weapon",bow_item)
 var armor: Dictionary = database.get_armor_item("body_05_royal","Super",12)
 var helmet: Dictionary = database.get_armor_item("helmet_05_royal","Super",12)
 if armor.is_empty() or helmet.is_empty():
  _fail("phase3b_armor_or_headgear_database_record_missing")
  return
 if not gear.equip_item("armor",armor) or not gear.equip_item("helmet",helmet):
  _fail("phase3b_armor_or_headgear_equip_failed")
  return
 if int(gear.get_equipped("weapon").get("plus",0)) != 12 or int(gear.get_equipped("armor").get("plus",0)) != 12 or int(gear.get_equipped("helmet").get("plus",0)) != 12:
  _fail("gear_plus12_state_invalid")
  return
 if not vfx.attach_character_aura(hero,12,false):
  _fail("ranger_hood_set_aura_attach_failed")
  return
 var bow_socket := hero.find_child("HeroWeapon_bow_hand_l",true,false) as Node3D
 if bow_socket == null or bow_socket.get_child_count()==0:
  _fail("approved_bow_visual_missing")
  return
 var bow_model := bow_socket.get_child(0) as Node3D
 if bow_model == null or not vfx.attach_equipment_aura(bow_model,12,true):
  _fail("plus12_bow_aura_missing")
  return
 if hero.get_node_or_null("CharacterSpriteAura") == null or bow_model.find_child("EquipmentSpriteAura",true,false) == null:
  _fail("hero_or_weapon_aura_node_missing")
  return
 if hero.find_child("EquipmentModel_armor",true,false) != null or hero.find_child("EquipmentModel_helmet",true,false) != null:
  _fail("forbidden_armor_or_headgear_3d_model_detected")
  return
 hero.velocity = Vector3.ZERO
 hero.set_process(false)
 hero.set_physics_process(false)
 var old_camera := hero.get("camera") as Camera3D
 if old_camera != null:
  old_camera.current = false
 var camera := Camera3D.new()
 camera.name = "Phase4D_Ranger_Hood_Portrait_Camera"
 camera.fov = 47.0
 camera.near = 0.05
 camera.far = 500.0
 city.add_child(camera)
 camera.global_position = hero.global_position+Vector3(1.8,1.8,3.117691)
 camera.look_at(hero.global_position+Vector3(0,1.35,0),Vector3.UP)
 camera.current = true
 var overlay := CanvasLayer.new()
 overlay.name = "Phase4D_Equipment_Proof_HUD"
 overlay.layer = 20
 root.add_child(overlay)
 var panel := PanelContainer.new()
 panel.position = Vector2(26,24)
 panel.custom_minimum_size = Vector2(570,170)
 overlay.add_child(panel)
 var stack := VBoxContainer.new()
 panel.add_child(stack)
 var labels := ["PHASE 4D — APPROVED RANGER APPEARANCE","RANGER HOOD: ORIGINAL HERO MODEL","ARMOR SLOT: Reinforced Metal Royal +12 (ICON / STATS)","HEADGEAR SLOT: Knight Helmet II Royal +12 (ICON / STATS)","WEAPON: Super Bow +12 — SPRITE AURA"]
 for i in range(labels.size()):
  var label := Label.new()
  label.text = labels[i]
  label.add_theme_font_size_override("font_size",22 if i==0 else 17)
  stack.add_child(label)
 var animation_player := hero.get("animation_player") as AnimationPlayer
 if animation_player == null:
  _fail("hero_animation_player_missing_for_idle_capture")
  return
 var idle_animation := ""
 for animation_name in animation_player.get_animation_list():
  if str(animation_name) == "Idle" or str(animation_name).ends_with("/Idle"):
   idle_animation = str(animation_name)
   break
 if idle_animation.is_empty():
  _fail("approved_idle_stance_animation_missing")
  return
 animation_player.stop()
 animation_player.play(idle_animation)
 animation_player.seek(0.0,true)
 for frame in range(6):
  await process_frame
 await RenderingServer.frame_post_draw
 var image: Image = root.get_texture().get_image()
 if image == null or image.is_empty():
  _fail("equipment_proof_viewport_empty")
  return
 var out_dir := ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(out_dir)
 var output_path := out_dir.path_join("phase4d_equipment_visual_plus12.png")
 var save_error: Error = image.save_png(output_path)
 if save_error != OK:
  _fail("equipment_proof_png_save_failed: "+str(save_error))
  return
 var png_bytes: int = FileAccess.get_file_as_bytes(output_path).size()
 if png_bytes < 20000 or image.get_width()!=1600 or image.get_height()!=1000:
  _fail("equipment_proof_png_invalid: bytes="+str(png_bytes)+" size="+str(image.get_size()))
  return
 print("PHASE4D_EQUIPMENT_VISUAL_PLUS12_OK: weapon=12 armor=12 helmet=12 ranger_hood_only=true 3d_armor_headgear=false")
 print("PHASE4D_EQUIPMENT_CAPTURE_PNG_OK: ",output_path," bytes=",png_bytes," dimensions=1600x1000")
 quit(0)

func _fail(message: String) -> void:
 push_error("PHASE4D_EQUIPMENT_VISUAL_FAILED: "+message)
 quit(2)
