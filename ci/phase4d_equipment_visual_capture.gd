extends SceneTree
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
  if hero != null and hero.get("hero_model") != null and hero.get("skeleton") != null:
   break
 if hero == null or hero.get("hero_model") == null or hero.get("skeleton") == null:
  _fail("approved_hero_or_skeleton_not_ready")
  return
 hero.call("_switch_class","archer")
 for frame in range(4):
  await process_frame
 var gear: Node = root.get_node_or_null("GearSystem")
 var database: Node = root.get_node_or_null("GearDatabase")
 var equipment_manager: Node = root.get_node_or_null("EquipmentVisualManager")
 if gear == null or database == null or equipment_manager == null:
  _fail("equipment_autoload_missing")
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
 if not gear.equip_item("armor",armor):
  _fail("phase3b_armor_equip_failed")
  return
 if not gear.equip_item("helmet",helmet):
  _fail("phase3b_headgear_equip_failed")
  return
 equipment_manager.bind_hero(hero)
 for frame in range(8):
  await process_frame
 var armor_model: Node3D = equipment_manager.get_visual_model("armor")
 var helmet_model: Node3D = equipment_manager.get_visual_model("helmet")
 var armor_socket: BoneAttachment3D = equipment_manager.get_visual_socket("armor")
 var helmet_socket: BoneAttachment3D = equipment_manager.get_visual_socket("helmet")
 if armor_model == null or helmet_model == null or armor_socket == null or helmet_socket == null:
  _fail("armor_or_headgear_bone_attachment_missing: "+str(equipment_manager.get_visual_status()))
  return
 var armor_meshes: int = int(equipment_manager.call("_count_meshes",armor_model))
 var helmet_meshes: int = int(equipment_manager.call("_count_meshes",helmet_model))
 if int(armor_meshes)<1 or int(helmet_meshes)<1:
  _fail("armor_or_headgear_has_no_renderable_mesh")
  return
 if armor_socket.bone_name.is_empty() or helmet_socket.bone_name.to_lower().find("head")<0:
  _fail("equipment_bone_binding_invalid: armor="+armor_socket.bone_name+" headgear="+helmet_socket.bone_name)
  return
 var armor_aura_target: Node3D = armor_model.find_child("EquipmentAuraTarget",true,false) as Node3D
 var helmet_aura_target: Node3D = helmet_model.find_child("EquipmentAuraTarget",true,false) as Node3D
 if armor_aura_target == null or helmet_aura_target == null:
  _fail("equipment_aura_targets_missing")
  return
 if armor_aura_target.find_child("EquipmentSpriteAura",true,false)==null or helmet_aura_target.find_child("EquipmentSpriteAura",true,false)==null:
  _fail("plus12_armor_or_headgear_aura_missing")
  return
 var bow_socket: Node3D = hero.find_child("HeroWeapon_bow_hand_l",true,false) as Node3D
 if bow_socket == null or bow_socket.get_child_count()==0:
  _fail("approved_bow_visual_missing")
  return
 var bow_model: Node3D = bow_socket.get_child(0) as Node3D
 if bow_model == null or bow_model.find_child("EquipmentSpriteAura",true,false)==null:
  _fail("plus12_bow_aura_missing")
  return
 hero.velocity = Vector3.ZERO
 hero.set_process(false)
 hero.set_physics_process(false)
 var old_camera: Camera3D = hero.get("camera") as Camera3D
 if old_camera != null:
  old_camera.current = false
 var camera: Camera3D = Camera3D.new()
 camera.name = "Phase4D_Equipment_ThreeQuarter_Camera"
 camera.fov = 43.0
 camera.near = 0.05
 camera.far = 500.0
 city.add_child(camera)
 # Three-quarter portrait: 3.2 m horizontal distance, 30-degree offset,
 # and 1.6 m camera height, safely outside the hero mesh.
 camera.global_position = hero.global_position+Vector3(1.6,1.6,2.771281)
 camera.look_at(hero.global_position+Vector3(0,1.4,0),Vector3.UP)
 camera.current = true
 if not camera.is_current():
  _fail("equipment_proof_camera_not_current")
  return
 var overlay: CanvasLayer = CanvasLayer.new()
 overlay.name = "Phase4D_Equipment_Proof_HUD"
 overlay.layer = 20
 root.add_child(overlay)
 var panel: PanelContainer = PanelContainer.new()
 panel.position = Vector2(26,24)
 panel.custom_minimum_size = Vector2(540,142)
 overlay.add_child(panel)
 var stack: VBoxContainer = VBoxContainer.new()
 panel.add_child(stack)
 var labels := ["PHASE 4D — REAL IN-GAME EQUIPMENT","ARMOR: Reinforced Metal Royal +12","HEADGEAR: Knight Helmet II Royal +12","WEAPON: Super Bow +12"]
 for i in range(labels.size()):
  var label: Label = Label.new()
  label.text = labels[i]
  label.add_theme_font_size_override("font_size",22 if i==0 else 18)
  stack.add_child(label)
 var animation_player: AnimationPlayer = hero.get("animation_player") as AnimationPlayer
 if animation_player == null:
  _fail("hero_animation_player_missing_for_idle_capture")
  return
 var idle_animation := ""
 for animation_name in animation_player.get_animation_list():
  if str(animation_name) == "Idle" or str(animation_name).ends_with("/Idle"):
   idle_animation = str(animation_name)
   break
 if idle_animation.is_empty():
  _fail("approved_idle_stance_animation_missing: "+str(animation_player.get_animation_list()))
  return
 animation_player.stop()
 animation_player.play(idle_animation)
 animation_player.seek(0.0,true)
 # Let the idle pose, BoneAttachments, camera switch and renderer settle.
 for frame in range(5):
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
 print("PHASE4D_EQUIPMENT_VISUAL_PLUS12_OK: armor=",armor_socket.bone_name," headgear=",helmet_socket.bone_name," bow=+12 armor_meshes=",armor_meshes," headgear_meshes=",helmet_meshes)
 print("PHASE4D_EQUIPMENT_CAPTURE_PNG_OK: ",output_path," bytes=",png_bytes," dimensions=1600x1000")
 quit(0)

func _fail(message: String) -> void:
 push_error("PHASE4D_EQUIPMENT_VISUAL_FAILED: "+message)
 quit(2)
