extends Node3D

const CharacterController = preload("res://scripts/CharacterVisualController.gd")

var captures := [
	{"file": "phase3b_01_archer_bow.png", "class": "archer", "level": 30, "plus": 1, "shadow": false, "extra": [], "pos": Vector3(1.8, 1.8, 2.35), "target": Vector3(0, 1.05, 0)},
	{"file": "phase3b_02_oriental_assassin_dual_knives.png", "class": "oriental_assassin", "level": 40, "plus": 3, "shadow": true, "extra": [], "pos": Vector3(1.8, 1.8, 2.35), "target": Vector3(0, 1.05, 0)},
	{"file": "phase3b_03_dual_blades_axes.png", "class": "trojan", "level": 60, "plus": 5, "shadow": false, "extra": [{"asset": "axe", "pos": Vector3(-0.95, 1.0, 0.08)}], "pos": Vector3(2.0, 1.9, 2.65), "target": Vector3(0, 1.05, 0)},
	{"file": "phase3b_04_spear_halberd_greatsword_shield.png", "class": "warrior", "level": 90, "plus": 7, "shadow": false, "extra": [{"asset": "spear", "pos": Vector3(-1.0, 0.8, 0.1)}, {"asset": "halberd", "pos": Vector3(1.0, 0.8, 0.1)}, {"asset": "shield", "pos": Vector3(0.0, 0.65, -0.55)}], "pos": Vector3(2.3, 2.0, 3.1), "target": Vector3(0, 1.0, 0)},
	{"file": "phase3b_05_mage_magic_staff.png", "class": "taoist", "level": 100, "plus": 9, "shadow": false, "extra": [], "pos": Vector3(1.8, 1.8, 2.35), "target": Vector3(0, 1.05, 0)},
	{"file": "phase3b_06_ninja_katana_shuriken_plus12.png", "class": "ninja", "level": 130, "plus": 12, "shadow": false, "extra": [{"asset": "shuriken", "pos": Vector3(-0.8, 1.55, -0.15)}], "pos": Vector3(1.8, 1.8, 2.35), "target": Vector3(0, 1.05, 0)}
]


func _ready() -> void:
	if OS.get_environment("CI_CAPTURE") == "1":
		_capture_all.call_deferred()


func _capture_all() -> void:
	var output: String = "res://artifacts/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var completed_captures: int = 0

	for spec in captures:
		for child in get_children():
			child.queue_free()
		await get_tree().process_frame
		_build_stage()

		var hero = CharacterController.new()
		add_child(hero)
		hero.build_character(str(spec.get("class", "archer")), int(spec.get("level", 1)))
		if not hero.assets_ready:
			push_error("PHASE3B_CAPTURE_FAILED_REQUIRED_IMPORTED_ASSETS: " + str(spec.get("file", "")))
			get_tree().quit(2)
			return

		hero.set_weapon_upgrade(int(spec.get("plus", 1)), "Super", int(spec.get("level", 1)))
		if bool(spec.get("shadow", false)):
			hero.activate_path_of_shadow(true)

		for extra in spec.get("extra", []):
			if not _add_weapon_prop(str(extra.get("asset", "")), extra.get("pos", Vector3.ZERO)):
				push_error("PHASE3B_CAPTURE_FAILED_EXTRA_WEAPON: " + str(extra.get("asset", "")))
				get_tree().quit(2)
				return

		var camera := Camera3D.new()
		camera.position = spec.get("pos", Vector3(1.8, 1.8, 2.35))
		camera.look_at(spec.get("target", Vector3(0, 1.05, 0)), Vector3.UP)
		camera.fov = 38.0 if int(spec.get("plus", 5)) <= 5 else 34.0
		camera.near = 0.05
		camera.far = 100.0
		add_child(camera)
		camera.current = true

		await get_tree().process_frame
		await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		if image == null or image.is_empty():
			push_error("PHASE3B_CAPTURE_FAILED_EMPTY_VIEWPORT: " + str(spec.get("file", "")))
			get_tree().quit(2)
			return

		var path: String = str(spec.get("file", ""))
		if path.is_empty():
			push_error("PHASE3B_CAPTURE_FAILED_EMPTY_FILENAME")
			get_tree().quit(2)
			return
		var full_path: String = output.path_join(path)
		var save_error: Error = image.save_png(full_path)
		if save_error != OK:
			push_error("PHASE3B_CAPTURE_FAILED_SAVE: " + path + " error=" + str(save_error))
			get_tree().quit(2)
			return

		var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes(full_path)
		if saved_bytes.size() <= 15000:
			push_error("PHASE3B_CAPTURE_FAILED_IMAGE_TOO_SMALL: " + path + " bytes=" + str(saved_bytes.size()))
			get_tree().quit(2)
			return

		completed_captures += 1
		print("PHASE3B_CAPTURE_OK: ", path, " bytes=", saved_bytes.size(), " size=", image.get_width(), "x", image.get_height())

	if completed_captures != captures.size():
		push_error("PHASE3B_CAPTURE_FAILED_COUNT: " + str(completed_captures) + "/" + str(captures.size()))
		get_tree().quit(2)
		return

	print("PHASE3B_ALL_SIX_CAPTURES_COMPLETE")
	get_tree().quit(0)


func _add_weapon_prop(asset_name: String, prop_position: Vector3) -> bool:
	var filename: String = "quaternius_shuriken.glb" if asset_name == "shuriken" else "quaternius_" + asset_name + ".glb"
	var asset_path: String = "res://assets/phase3b/" + filename
	if not ResourceLoader.exists(asset_path):
		push_error("PHASE3B_EXTRA_WEAPON_MISSING: " + asset_path)
		return false
	var packed: PackedScene = load(asset_path) as PackedScene
	if packed == null:
		push_error("PHASE3B_EXTRA_WEAPON_NOT_PACKED_SCENE: " + asset_path)
		return false
	var model := packed.instantiate() as Node3D
	if model == null:
		push_error("PHASE3B_EXTRA_WEAPON_ROOT_NOT_NODE3D: " + asset_path)
		return false
	model.position = prop_position
	model.scale = Vector3.ONE * 0.48
	add_child(model)
	return true


func _build_stage() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.20, 0.27)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.88, 0.96)
	env.ambient_light_energy = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.12
	world.environment = env
	add_child(world)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	floor.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.24, 0.25, 0.29)
	floor_material.roughness = 0.92
	floor.material_override = floor_material
	add_child(floor)

	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.38, 3.0, 0.38)
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(side * 2.35, 1.5, -1.2)
		var pillar_material := StandardMaterial3D.new()
		pillar_material.albedo_color = Color(0.30, 0.17, 0.15)
		pillar.material_override = pillar_material
		add_child(pillar)

		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.56, 0.16, 0.56)
		cap.mesh = cap_mesh
		cap.position = Vector3(side * 2.35, 3.05, -1.2)
		var cap_material := StandardMaterial3D.new()
		cap_material.albedo_color = Color(0.78, 0.56, 0.20)
		cap_material.metallic = 0.45
		cap.material_override = cap_material
		add_child(cap)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-45, -30, 0)
	key_light.light_color = Color(1.0, 0.91, 0.78)
	key_light.light_energy = 1.65
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-20, 145, 0)
	fill_light.light_color = Color(0.68, 0.78, 1.0)
	fill_light.light_energy = 0.7
	add_child(fill_light)
