extends SceneTree

var _output_dir := ""
var _system: Node
var _hero: Node3D
var _camera: Camera3D
var _world_map: Node
var _capture_count := 0
var _frame_tick := 0
var _proofs_completed := false
var _watchdog_started_msec := 0
var _last_run_trace := "not_started"

func _initialize() -> void:
	_watchdog_started_msec = Time.get_ticks_msec()
	OS.unset_environment("CI_CAPTURE")
	print("PHASE5B_VISUAL_PROOFS_START=true captures=4 frame_driven=true legacy_capture=disabled")
	DisplayServer.window_set_size(Vector2i(960, 540))
	_output_dir = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var error := change_scene_to_file("res://scenes/TwinCity.tscn")
	if error != OK:
		_fail("twin_city_scene_load", error)

func _process(_delta: float) -> bool:
	if _proofs_completed:
		return true
	_frame_tick += 1
	if _watchdog_started_msec > 0 and Time.get_ticks_msec() - _watchdog_started_msec >= 90000:
		_fail("watchdog_timeout captured=%d/4 frame=%d last_RUN_TRACE=%s" % [_capture_count, _frame_tick, _last_run_trace])
		return true

	match _frame_tick:
		3:
			if not _capture_twin_city():
				return true
		6:
			if not _capture_mounts_and_auras():
				return true
		9:
			if not _capture_sub_cities():
				return true
		12:
			if not _capture_wilderness_hunters():
				return true
	return _proofs_completed

func _trace(step: String) -> void:
	_last_run_trace = step
	print("RUN_TRACE: ", step)

func _capture_twin_city() -> bool:
	_trace("frame_3_twin_city_setup")
	_hero = _find_hero()
	if _hero == null:
		_fail("live_hero_not_found_at_frame_3")
		return false
	_system = root.get_node_or_null("SimulatedPlayersSystem")
	_world_map = root.get_node_or_null("WorldMapManager")
	if _system == null or _world_map == null:
		_fail("phase5b_autoload_missing")
		return false
	_camera = _hero.get("camera") as Camera3D
	if _camera == null:
		_fail("hero_camera_missing")
		return false
	_hero.set_process(false)
	_hero.set_physics_process(false)
	_camera.top_level = true
	_camera.current = true
	_camera.fov = 52.0
	_set_location("TwinCity", Vector3(0.0, 0.0, -45.0))
	if not _assert_population(18, 12):
		return false
	_set_camera(Vector3(0.0, 1.5, -45.0), 42.0, 24.0)
	if not _capture_now("phase5b_twin_city_crowd.png"):
		return false
	print("PHASE5B_VISUAL_CAPTURE_OK: phase5b_twin_city_crowd.png")

	_free_runtime_actors()
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
	_system.set_process(true)
	_trace("frame_3_complete_waiting_for_frame_6")
	return true

func _capture_mounts_and_auras() -> bool:
	_trace("frame_6_mount_validation")
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
		_fail("three_mounts_or_plus_levels_missing count=%d levels=%s" % [mount_count, str(aura_levels.keys())])
		return false
	_set_camera(Vector3(0.0, 1.5, -45.0), 25.0, 13.0)
	if not _capture_now("phase5b_auras_and_mounts.png"):
		return false
	print("PHASE5B_VISUAL_CAPTURE_OK: phase5b_auras_and_mounts.png mounts=3 plus_levels=0,6,12")
	_set_location("PhoenixCastle", Vector3(0.0, 0.0, -98.0))
	_trace("frame_6_complete_waiting_for_frame_9")
	return true

func _capture_sub_cities() -> bool:
	_trace("frame_9_subcity_validation")
	if not _assert_population(8, 6):
		return false
	_set_camera(Vector3(0.0, 1.5, -98.0), 34.0, 20.0)
	if not _capture_now("phase5b_sub_cities.png"):
		return false
	print("PHASE5B_VISUAL_CAPTURE_OK: phase5b_sub_cities.png city=PhoenixCastle")
	_set_location("Wilderness", Vector3(0.0, 0.0, 0.0))
	_trace("frame_9_complete_waiting_for_frame_12")
	return true

func _capture_wilderness_hunters() -> bool:
	_trace("frame_12_hunter_validation")
	var hunter_count := 0
	for actor_id in _system.get("_active_actors").keys():
		var entry: Dictionary = _system.call("_find_entry", String(actor_id))
		if bool(entry.get("hunter", false)):
			hunter_count += 1
	if hunter_count < 3:
		_fail("wilderness_hunters_not_visible count=%d" % hunter_count)
		return false
	_set_camera(Vector3(0.0, 1.5, 0.0), 21.0, 13.0)
	if not _capture_now("phase5b_wild_hunters.png"):
		return false
	print("PHASE5B_VISUAL_CAPTURE_OK: phase5b_wild_hunters.png hunters=", hunter_count)

	_trace("final_image_validation")
	for filename in ["phase5b_twin_city_crowd.png", "phase5b_auras_and_mounts.png", "phase5b_sub_cities.png", "phase5b_wild_hunters.png"]:
		var image := Image.load_from_file(_output_dir.path_join(filename))
		if image == null or image.is_empty() or image.get_width() < 960 or image.get_height() < 540:
			_fail("invalid_capture_" + filename)
			return false
	_free_runtime_actors()
	_proofs_completed = true
	_trace("all_four_captures_validated_and_runtime_actors_freed")
	print("PHASE5B_VISUAL_PROOFS_PASS=true captures=4 crowd=true nameplates=true mounts=3 plus_levels=0,6,12 subcity=PhoenixCastle hunters=true cleanup=free")
	quit(0)
	return true

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
	_camera.global_position = target + Vector3(0.0, height, distance)
	_camera.look_at(target + Vector3(0.0, 1.6, 0.0), Vector3.UP)
	_camera.current = true
	print("CAPTURE_STEP: camera_ready target=", target)

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

func _capture_now(filename: String) -> bool:
	print("CAPTURE_STEP: begin frame=", _frame_tick, " file=", filename)
	var file_path := _output_dir.path_join(filename)
	var tex: ViewportTexture = root.get_texture()
	if tex == null:
		push_error("CAPTURE_ERROR: root.get_texture() is null for " + file_path)
		quit(1)
		return false
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		push_error("CAPTURE_ERROR: captured image is null or empty for " + file_path)
		quit(1)
		return false
	if img.get_width() < 960 or img.get_height() < 540:
		_fail("viewport_image_below_minimum_size_" + filename)
		return false
	var err: Error = img.save_png(file_path)
	print("CAPTURED_OK: ", file_path, " err=", err)
	if err != OK:
		_fail("png_save_failed_" + filename + " error=" + str(err))
		return false
	var bytes := FileAccess.get_file_as_bytes(file_path).size()
	if bytes < 15000:
		_fail("png_below_minimum_size_" + filename + " bytes=" + str(bytes))
		return false
	_capture_count += 1
	print("CAPTURED_OK: ", file_path, " bytes=", bytes, " count=", _capture_count)
	return true

func _free_runtime_actors() -> void:
	if _system == null or not is_instance_valid(_system):
		return
	var active: Dictionary = _system.get("_active_actors")
	for actor_id in active.keys().duplicate():
		var actor := active.get(actor_id) as Node3D
		if is_instance_valid(actor):
			actor.free()
	active.clear()
	_system.set("_active_actors", active)
	var roster: Array = _system.get("_roster")
	for entry in roster:
		entry["active"] = false
		entry["actor"] = null
	_system.set("_roster", roster)
	_system.set("_last_city", "")

func _fail(reason: String, code: int = 1) -> void:
	push_error("PHASE5B_VISUAL_PROOFS_FAIL: " + reason)
	_proofs_completed = true
	quit(code)
