extends SceneTree
## Real Godot render using only the two approved complete Ranger Hood rigs and Phase 3B weapons.
const LIBRARY_PATH := "res://assets/phase4/animations/conquer_hero_anims.res"
const OUTPUT_PATH := "res://artifacts/hero_pose_review.png"
const MALE := "res://assets/phase3b/characters/Male_Ranger.glb"
const FEMALE := "res://assets/phase3b/characters/Female_Ranger.glb"
const POSES := ["Idle","Jump","Attack_Bow","Attack_Assassin","Attack_Trojan","Attack_SwordShield","Attack_Staff"]
const LABELS := ["IDLE","JUMP","ARCHER • BOW","SAME ARCHER • DUAL KNIVES","TROJAN","WARRIOR • SWORD + SHIELD","TAOIST • STAFF"]
const X_POS := [-4.8,-3.2,-1.6,0.0,1.6,3.2,4.8]

func _initialize() -> void:
 call_deferred("_render")

func _render() -> void:
 var window := get_root()
 window.size = Vector2i(1920,1080)
 window.title = "Phase 4A — Ranger Hood Hero Animation Review"
 var scene := Node3D.new()
 scene.name = "RangerHoodReview"
 window.add_child(scene)
 var world := WorldEnvironment.new()
 var environment := Environment.new()
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color(0.055,0.075,0.12)
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color(0.78,0.82,0.92)
 environment.ambient_light_energy = 0.95
 world.environment = environment
 scene.add_child(world)

 var camera := Camera3D.new()
 camera.position = Vector3(2.0,2.55,5.8)
 camera.fov = 68.0
 camera.current = true
 scene.add_child(camera)
 camera.look_at(Vector3(0,1.0,0),Vector3.UP)
 var key := DirectionalLight3D.new()
 key.rotation_degrees = Vector3(-38,-25,0)
 key.light_energy = 1.45
 key.shadow_enabled = true
 scene.add_child(key)
 var fill := OmniLight3D.new()
 fill.position = Vector3(-4,4,4)
 fill.light_energy = 1.2
 fill.omni_range = 20
 scene.add_child(fill)
 var floor := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(13,5)
 floor.mesh = plane
 floor.position.y = -0.035
 var floor_mat := StandardMaterial3D.new()
 floor_mat.albedo_color = Color(0.12,0.15,0.21)
 floor_mat.roughness = 0.9
 floor.material_override = floor_mat
 scene.add_child(floor)

 var library := ResourceLoader.load(LIBRARY_PATH,"AnimationLibrary",ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
 if library == null or library.get_animation_list().size() != 10:
  push_error("POSE_LIBRARY_MISSING_OR_INVALID"); quit(2); return
 var male_scene := ResourceLoader.load(MALE) as PackedScene
 var female_scene := ResourceLoader.load(FEMALE) as PackedScene
 if male_scene == null or female_scene == null:
  push_error("APPROVED_RANGER_MODELS_MISSING"); quit(3); return
 var male_hash := _file_sha256(MALE)
 var female_hash := _file_sha256(FEMALE)
 if male_hash == "" or female_hash == "":
  push_error("RANGER_SOURCE_HASH_MISSING"); quit(4); return
 var model_indices := [0,1,0,0,0,1,1]
 for i in range(POSES.size()):
  var chosen_scene: PackedScene = female_scene if model_indices[i] == 1 else male_scene
  var model := chosen_scene.instantiate() as Node3D
  if model == null: push_error("RANGER_INSTANCE_FAILED: "+POSES[i]); quit(5); return
  model.name = "RangerHood_%02d_%s" % [i,POSES[i]]
  model.position = Vector3(X_POS[i],0,0)
  model.scale = Vector3.ONE * 0.72
  scene.add_child(model)
  var skeletons := model.find_children("*","Skeleton3D",true,false)
  if skeletons.is_empty(): push_error("RANGER_SKELETON_NOT_FOUND: "+POSES[i]); quit(6); return
  var skeleton := skeletons[0] as Skeleton3D
  var player := AnimationPlayer.new()
  player.name = "AnimationPlayer"
  model.add_child(player)
  var add_err := player.add_animation_library("",library)
  if add_err != OK: push_error("ANIMATION_LIBRARY_ATTACH_FAILED"); quit(7); return
  player.play(POSES[i])
  var anim := library.get_animation(POSES[i])
  player.seek(anim.length * (0.58 if POSES[i].begins_with("Attack_") else 0.45),true)
  player.pause()
  _attach_weapons(skeleton,POSES[i])
  var label := Label3D.new()
  label.text = LABELS[i]
  label.font_size = 34
  label.pixel_size = 0.0032
  label.modulate = Color(0.98,0.84,0.52)
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  label.position = Vector3(X_POS[i],0.12,0.5)
  scene.add_child(label)
  print("PHASE4A_SLOT_OK: ",LABELS[i]," model=",MALE if model_indices[i]==0 else FEMALE," sha256=",male_hash if model_indices[i]==0 else female_hash," clip=",POSES[i])
 for frame in range(12): await process_frame
 await RenderingServer.frame_post_draw
 var image := window.get_texture().get_image()
 if image.is_empty() or image.get_width()!=1920 or image.get_height()!=1080:
  push_error("POSE_CAPTURE_INVALID"); quit(8); return
 var output := ProjectSettings.globalize_path(OUTPUT_PATH)
 var err := image.save_png(output)
 if err != OK: push_error("PNG_SAVE_FAILED: "+str(err)); quit(9); return
 print("PHASE4A_POSE_RENDER_OK: ",OUTPUT_PATH," 1920x1080 bytes=",FileAccess.get_file_as_bytes(output).size())
 quit(0)

func _attach_weapons(skeleton: Skeleton3D, pose: String) -> void:
 match pose:
  "Attack_Bow":
   _attach_weapon(skeleton,"hand_l","res://assets/phase3b/weapons/bow_beginner.glb",Vector3(0,0,90),0.85)
  "Attack_Assassin":
   _attach_weapon(skeleton,"hand_l","res://assets/phase3b/weapons/dual_knives_beginner.glb",Vector3(0,0,90),0.40)
   _attach_weapon(skeleton,"hand_r","res://assets/phase3b/weapons/dual_knives_beginner.glb",Vector3(0,0,-90),0.40)
  "Attack_Trojan":
   _attach_weapon(skeleton,"hand_l","res://assets/phase3b/weapons/dual_blades_beginner.glb",Vector3(0,0,90),0.30)
   _attach_weapon(skeleton,"hand_r","res://assets/phase3b/weapons/dual_blades_beginner.glb",Vector3(0,0,-90),0.30)
  "Attack_SwordShield":
   _attach_weapon(skeleton,"hand_l","res://assets/phase3b/weapons/shield_beginner.glb",Vector3(0,0,0),0.34)
   _attach_weapon(skeleton,"hand_r","res://assets/phase3b/weapons/greatsword_beginner.glb",Vector3(0,0,90),0.34)
  "Attack_Staff":
   _attach_weapon(skeleton,"hand_r","res://assets/phase3b/weapons/magic_staff_beginner.glb",Vector3(0,0,90),0.42)

func _attach_weapon(skeleton: Skeleton3D, bone: String, path: String, rotation: Vector3, size: float) -> void:
 var index := skeleton.find_bone(bone)
 if index < 0:
  push_error("WEAPON_SOCKET_MISSING: "+bone); return
 var packed := ResourceLoader.load(path) as PackedScene
 if packed == null:
  push_error("WEAPON_ASSET_MISSING: "+path); return
 var socket := BoneAttachment3D.new()
 socket.bone_name = bone
 socket.name = "WeaponSocket_"+bone+"_"+str(skeleton.get_child_count())
 skeleton.add_child(socket)
 var weapon := packed.instantiate() as Node3D
 if weapon == null:
  push_error("WEAPON_INSTANCE_FAILED: "+path); return
 socket.add_child(weapon)
 weapon.scale = Vector3.ONE * size
 weapon.rotation_degrees = rotation
 weapon.position = Vector3(0,0,0)

func _file_sha256(path: String) -> String:
 var file := FileAccess.open(path,FileAccess.READ)
 if file == null: return ""
 var ctx := HashingContext.new()
 if ctx.start(HashingContext.HASH_SHA256)!=OK: return ""
 while not file.eof_reached():
  var chunk := file.get_buffer(1024*1024)
  if chunk.is_empty(): break
  ctx.update(chunk)
 return ctx.finish().hex_encode()
