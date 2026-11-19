extends Node3D
const SHOWCASE_ASSETS := [
	{"id": "boulder_01", "position": Vector3(-5.0, 0.0, 0.0)},
	{"id": "mountainside", "position": Vector3(0.0, 0.0, 0.0)},
	{"id": "dead_tree_trunk", "position": Vector3(5.0, 0.0, 0.0)}
]
func _ready() -> void:
	_setup_lighting()
	_load_showcase_models()
	if OS.get_environment("CI_CAPTURE") == "1":
		_capture_boot_image.call_deferred()
func _setup_lighting() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.20, 0.43, 0.72)
	sky_material.sky_horizon_color = Color(0.72, 0.83, 0.91)
	sky_material.ground_bottom_color = Color(0.18, 0.20, 0.17)
	sky_material.ground_horizon_color = Color(0.48, 0.53, 0.46)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Daylight"
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	camera.name = "BootCamera"
	camera.position = Vector3(0.0, 9.0, 22.0)
	camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	camera.current = true
	camera.fov = 55.0
	add_child(camera)
func _load_showcase_models() -> void:
	for item in SHOWCASE_ASSETS:
		var asset_id := String(item["id"])
		var model := AssetLoader.load_model(asset_id)
		if model == null:
			push_error("BootTest: no approved model could be loaded for " + asset_id)
			continue
		model.name = asset_id
		model.position = item["position"]
		add_child(model)
		print("BOOT_ASSET_OK:", asset_id)
func _capture_boot_image() -> void:
	for frame_index in range(120):
		await get_tree().process_frame
	var output_dir := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := get_viewport().get_texture().get_image()
	var output_path := output_dir.path_join("boot_check.png")
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("BootTest: failed to save boot_check.png, error=%s" % save_error)
		get_tree().quit(1)
		return
	print("BOOT_CAPTURE_OK:", output_path)
	get_tree().quit(0)
