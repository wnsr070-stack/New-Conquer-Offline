extends SceneTree
## Renders six real hero poses with the imported approved Phase 3B GLBs and the built AnimationLibrary.
## Run under X11/Xvfb (not --headless): xvfb-run -a Godot --path . --script res://scripts/animation/ConquerHeroPoseRenderer.gd

const LIBRARY_PATH := "res://assets/phase4/animations/conquer_hero_anims.res"
const OUTPUT_PATH := "res://artifacts/hero_pose_review.png"
const POSE_NAMES := ["Idle", "Jump", "Attack_Bow", "Attack_Assassin", "Attack_Trojan", "Attack_SwordShield"]
const LABELS := ["IDLE", "JUMP", "ARCHER • BOW", "EASTERN ASSASSIN", "TROJAN", "WARRIOR • SWORD + SHIELD"]

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var window := get_root()
	window.size = Vector2i(1920, 1080)
	window.title = "New Conquer Offline — Phase 4A Hero Pose Review"
	var scene := Node3D.new()
	scene.name = "HeroPoseReview"
	window.add_child(scene)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.075, 0.105, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.79, 0.92)
	environment.ambient_light_energy = 0.8
	world.environment = environment
	scene.add_child(world)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 3.5, 17.5)
	camera.fov = 43.0
	camera.current = true
	scene.add_child(camera)
	camera.look_at(Vector3(0, 1.05, 0), Vector3.UP)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38, -25, 0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	scene.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-5, 5, 5)
	fill_light.light_energy = 1.0
	fill_light.omni_range = 24.0
	scene.add_child(fill_light)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(19, 8)
	floor.mesh = floor_mesh
	floor.position = Vector3(0, -0.04, 0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.13, 0.17, 0.23)
	floor_material.roughness = 0.88
	floor.material_override = floor_material
	scene.add_child(floor)

	var library := ResourceLoader.load(LIBRARY_PATH, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
	if library == null or library.get_animation_list().size() != 10:
		push_error("POSE_RENDER_LIBRARY_MISSING_OR_INVALID")
		quit(2)
		return

	var model_paths: Array[String] = []
	_collect_glbs("res://assets/phase3b/characters", model_paths)
	model_paths.sort()
	if model_paths.size() < 2:
		push_error("POSE_RENDER_NEEDS_APPROVED_HERO_GLBS; found=%d" % model_paths.size())
		quit(3)
		return

	var archetype_hints := [
		["", "male", "female"],
		["female", "male"],
		["archer", "ranger"],
		["assassin", "ninja", "archer"],
		["trojan", "warrior", "male"],
		["warrior", "sword", "female"]
	]
	var x_positions := [-7.0, -4.2, -1.4, 1.4, 4.2, 7.0]
	for i in range(POSE_NAMES.size()):
		var chosen_path := _choose_model(model_paths, archetype_hints[i], i)
		var packed := ResourceLoader.load(chosen_path) as PackedScene
		if packed == null:
			push_error("POSE_RENDER_MODEL_LOAD_FAILED: " + chosen_path)
			quit(4)
			return
		var hero := packed.instantiate() as Node3D
		if hero == null:
			push_error("POSE_RENDER_MODEL_ROOT_NOT_3D: " + chosen_path)
			quit(5)
			return
		hero.name = "HeroPose_%02d_%s" % [i, POSE_NAMES[i]]
		hero.position = Vector3(x_positions[i], 0, 0)
		hero.scale = Vector3.ONE * 0.82
		scene.add_child(hero)

		var player := AnimationPlayer.new()
		player.name = "AnimationPlayer"
		hero.add_child(player)
		var add_error := player.add_animation_library("", library)
		if add_error != OK:
			push_error("POSE_RENDER_LIBRARY_ATTACH_FAILED: %s" % add_error)
			quit(6)
			return
		player.play(POSE_NAMES[i])
		var animation := library.get_animation(POSE_NAMES[i])
		player.seek(animation.length * (0.62 if POSE_NAMES[i].begins_with("Attack_") else 0.45), true)
		player.pause()

		var caption := Label3D.new()
		caption.text = LABELS[i]
		caption.font_size = 42
		caption.pixel_size = 0.0035
		caption.modulate = Color(0.95, 0.82, 0.48)
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.position = Vector3(x_positions[i], 0.14, 0.45)
		scene.add_child(caption)
		print("PHASE4A_POSE_SLOT: ", LABELS[i], " <- ", chosen_path, " / ", POSE_NAMES[i])

	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := window.get_texture().get_image()
	if image.is_empty() or image.get_width() < 1200 or image.get_height() < 700:
		push_error("POSE_RENDER_CAPTURE_INVALID")
		quit(7)
		return
	var output_file := ProjectSettings.globalize_path(OUTPUT_PATH)
	var save_error := image.save_png(output_file)
	if save_error != OK:
		push_error("POSE_RENDER_PNG_SAVE_FAILED: %s" % save_error)
		quit(8)
		return
	print("PHASE4A_POSE_RENDER_OK: ", OUTPUT_PATH, " size=", image.get_width(), "x", image.get_height(), " bytes=", FileAccess.get_file_as_bytes(output_file).size())
	quit(0)

func _collect_glbs(directory: String, output: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := directory.path_join(entry)
		if dir.current_is_dir():
			_collect_glbs(path, output)
		elif entry.to_lower().ends_with(".glb"):
			output.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

func _choose_model(paths: Array[String], hints: Array, slot: int) -> String:
	for hint in hints:
		for path in paths:
			if hint == "" or path.to_lower().contains(str(hint)):
				return path
	return paths[slot % paths.size()]
