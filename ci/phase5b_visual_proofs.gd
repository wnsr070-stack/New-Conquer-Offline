extends SceneTree

var _output_dir := ""
var _system: Node
var _hero: Node3D
var _camera: Camera3D
var _world_map: Node
var _capture_count := 0
var _current_capture := "startup"
var _proofs_completed := false
var _watchdog_started_msec := 0
var _last_run_trace := "not_started"

func _initialize() -> void:
	_watchdog_started_msec = Time.get_ticks_msec()
	call_deferred("_run")

func _process(_delta: float) -> bool:
	if _proofs_completed or _watchdog_started_msec <= 0:
		return false

	if Time.get_ticks_msec() - _watchdog_started_msec >= 45000:
		push_error("PHASE5B_VISUAL_PROOFS_WATCHDOG: timeout=45000ms captured=%d/4 last_RUN_TRACE=%s" % [_capture_count, _last_run_trace])
		quit(1)
		return true

	return false

func _trace(step: String) -> void:
	_last_run_trace = step
	print("RUN_TRACE: ", step)

func _run() -> void:
	_trace("run_start")
	OS.unset_environment("CI_CAPTURE")
	print("PHASE5B_VISUAL_PROOFS_START=true captures=4 legacy_capture=disabled")
	_trace("before_window_setup")
	DisplayServer.window_set_size(Vector2i(960, 540))
	_trace("before_output_directory")
	_output_dir = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_trace("before_scene_change")
	var error := change_scene_to_file("res://scenes/TwinCity.tscn")
	if error != OK:
		_fail("twin_city_scene_load", error)
		return
	_trace("before_initial_three_frames")
	for i in range(3):
		await get_tree().process_frame
	_trace("before_hero_lookup")
	_hero = _find_hero()
	if _hero == null:
		_fail("live_hero_not_found_after_three_frames")
		return
	_trace("before_autoload_lookup")
	_system = root.get_node_or_null("SimulatedPlayersSystem")
	_world_map = root.get_node_or_null("WorldMapManager")
	if _system == null or _world_map == null:
		_fail("phase5b_autoload_missing")
		return
	_trace("before_camera_lookup")
	_camera = _hero.get("camera") as Camera3D
	if _camera == null:
		_fail("hero_camera_missing")
		return
	_trace("before_hero_freeze")
	_hero.set_process(false)
	_hero.set_physics_process(false)
	_camera.top_level = true
	_camera.current = true
	_camera.fov = 52.0

	_trace("before_set_location_twin_city")
	_set_location("TwinCity", Vector3(0.0, 0.0, -45.0))
	_trace("before_twin_city_three_frames")
	for i in range(3):
		await get_tree().process_frame
	_trace("before_population_assert_1")
	if not _assert_population(18, 12):
		return
	_trace("before_camera_1")
	_set_camera(Vector3(0.0, 1.5, -45.0), 42.0, 24.0)
	_trace("before_capture_1")
	if not await _capture("phase5b_twin_city_crowd.png"):
		return
	print("PHASE5B_VISUAL_CAPTURE_OK: phase5b_twin_city_crowd.png")

	_trace("before_clear_runtime_actors")
	_system.call("_clear_runtime_actors")
	_trace("before_roster_setup")
	var roster: Array = _system.get("_roster")
	var mount_positions := [Vector3(-7.0, 0.0, -45.0), Vector3(0.0, 0.0, -45.0), Vector3(7.0, 0.0, -45.0)]
	var mount_kinds := ["steed", "deer", "wolf"]
	var mount_levels := [0, 6, 12]
	for entry in roster:
		if String(entry.get("city", "")) != "TwinCity" or String(entry.get("role", "")) != "hub":
			continue
		var rider_index := int(String(entry.get("id", "sim_000")).trim_prefix("sim_")) % 15
		entry["plus_level"] = rider_index % 13
		if rider_index in [0, 4, 8]:
			var slot := [0, 4, 8].find(rider_index)
			entry["base_position"] = mount_positions[slot]
			entry["mount_type"] = mount_kinds[slot]
			entry["plus_level"] = mount_levels[slot]
	_system.set("_last_city", "")
	_trace("before_mounts_three_frames")
	for i in range(3):
		await get_tree().process_frame
	_trace("before_mount_validation")
	var mount_count := 0
	var aura_levels: Dictionary = {}
	var active: Dictionary = _system.get("_active_actors")
	for actor_id in active.keys():
		var actor := active[actor_id] as Node3D
		if not is_instance_valid(actor):
			continue
		if actor.find_children("SimulatedMount_*", "Node3D", true, false).size() > 0:
			mount_count += 1
			aura_levels[int(actor.get_meta("plus_level", -1))] = true
	if mount_count < 3 or not aura_levels.has(0) or not aura_levels.has(6) or not aura_levels.has(12):
		_fail("three_mounts_or_plus_levels_missing")
		return
	_trace("before_camera_2")
	_set_camera(Vector3(0.0, 1.5, -45.0), 25.0, 13.0)
	_trace("before_capture_2")
	if not await _capture("phase5b_auras_and_mounts.png"):
		return
	print("PHASE5B_VISUAL_CAPTURE_OK: phase5b_auras_and_mounts.png mounts=3 plus_levels=0,6,12")

	_trace("before_set_location_subcity")
	_set_location("PhoenixCastle", Vector3(0.0, 0.0, -98.0))
	_trace("before_subcity_three_frames")
	for i in range(3):
		await get_tree().process_frame
	_trace("before_population_assert_2")
	if not _assert_population(8, 6):
		return
	_trace("before_camera_3")
	_set_camera(Vector3(0.0, 1.5, -98.0), 34.0, 20.0)
	_trace("before_capture_3")
	if not await _capture("phase5b_sub_cities.png"):
		return
	print("PHASE5B_VISUAL_CAPTURE_OK: phase5b_sub_cities.png city=PhoenixCastle")

	_trace("before_set_location_wilderness")
	_set_location("Wilderness", Vector3(0.0, 0.0, 0.0))
	_trace("before_wilderness_three_frames")
	for i in range(3):
		await get_tree().process_frame
	_trace("before_hunter_validation")
	var hunter_count := 0
	for actor_id in _system.get("_active_actors").keys():
		var entry: Dictionary = _system.call("_find_entry", String(actor_id))
		if bool(entry.get("hunter", false)):
			hunter_count += 1
	if hunter_count < 3:
		_fail("wilderness_hunters_not_visible")
		return
	_trace("before_camera_4")
	_set_camera(Vector3(0.0, 1.5, 0.0), 21.0, 13.0)
	_trace("before_capture_4")
	if not await _capture("phase5b_wild_hunters.png"):
		return
	print("PHASE5B_VISUAL_CAPTURE_OK: phase5b_wild_hunters.png hunters=", hunter_count)

	_trace("before_final_image_validation")
	for filename in ["phase5b_twin_city_crowd.png", "phase5b_auras_and_mounts.png", "phase5b_sub_cities.png", "phase5b_wild_hunters.png"]:
		var image := Image.load_from_file(_output_dir.path_join(filename))
		if image == null or image.is_empty() or image.get_width() < 960 or image.get_height() < 540:
			_fail("invalid_capture_" + filename)
			return
	_proofs_completed = true
	_trace("all_four_captures_validated")
	print("PHASE5B_VISUAL_PROOFS_PASS=true captures=4 crowd=true nameplates=true mounts=3 plus_levels=0,6,12 subcity=PhoenixCastle hunters=true")
	get_tree().quit(0)

func _find_hero() -> Node3D:
	var grouped := root.get_tree().get_first_node_in_group("player")
	if grouped is Node3D:
		return grouped as Node3D
	var named := root.find_child("PlayableHero", true, false)
	if named is Node3D:
		return named as Node3D
	var legacy := root.find_child("TwinCityPlayableHero", true, false)
	return legacy as Node3D if legacy is Node3D else null

func _set_location(city: String, position: Vector3) -> void:
	_world_map.set("current_city", city)
	_hero.global_position = position
	_system.set("_last_city", "")
	_system.set_process(true)
	_camera.current = true

func _set_camera(target: Vector3, distance: float, height: float) -> void:
	print("CAPTURE_STEP: camera_move_begin target=", target, " distance=", distance, " height=", height)
	_camera.global_position = target + Vector3(0.0, height, distance)
	_camera.look_at(target + Vector3(0.0, 1.6, 0.0), Vector3.UP)
	_camera.current = true
	print("CAPTURE_STEP: camera_move_done position=", _camera.global_position)

func _settle(_seconds: float) -> void:
	for i in range(3):
		await get_tree().process_frame

func _assert_population(minimum_actors: int, minimum_nameplates: int) -> bool:
	var active: Dictionary = _system.get("_active_actors")
	var nameplates := 0
	for actor_id in active.keys():
		var actor := active[actor_id] as Node3D
		if is_instance_valid(actor) and actor.get_node_or_null("SimulatedPlayerNameplate") is Label3D:
			nameplates += 1
	if active.size() < minimum_actors or nameplates < minimum_nameplates:
		_fail("population_or_nameplates_below_capture_threshold active=%d nameplates=%d" % [active.size(), nameplates])
		return false
	return true

func _capture(filename: String) -> bool:
	_current_capture = filename
	print("CAPTURE_STEP: begin ", filename)
	await get_tree().process_frame
	await get_tree().process_frame
	print("CAPTURE_STEP: viewport_read ", filename)
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty() or img.get_width() < 960 or img.get_height() < 540:
		_fail("viewport_image_empty_" + filename)
		return false
	var file_path := _output_dir.path_join(filename)
	print("CAPTURE_STEP: save_png ", file_path)
	var err := img.save_png(file_path)
	print("CAPTURED_OK: ", file_path, " err=", err)
	if err != OK:
		_fail("png_save_failed_" + filename + " error=" + str(err))
		return false
	var bytes := FileAccess.get_file_as_bytes(file_path).size()
	if bytes < 15000:
		_fail("png_below_minimum_size_" + filename + " bytes=" + str(bytes))
		return false
	_capture_count += 1
	print("CAPTURE_STEP: complete ", filename, " count=", _capture_count)
	return true

func get_tree() -> SceneTree:
	return self

func get_viewport() -> Viewport:
	return get_root()

func _fail(reason: String, code: int = 1) -> void:
	push_error("PHASE5B_VISUAL_PROOFS_FAIL: " + reason)
	quit(code)
