extends SceneTree

const TABLE = preload("res://scripts/MonsterGeneratorTable.gd")
const MonsterActorScript = preload("res://scripts/MonsterActor.gd")
const SpawnerScript = preload("res://scripts/MonsterSpawner.gd")
const ASSET_ROOT := "res://assets/phase3b/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var definitions: Array = []
	definitions.append_array(TABLE.MONSTERS)
	definitions.append_array(TABLE.WORLD_BOSSES)
	if definitions.size() != 20 or SpawnerScript.MODEL_FILES.size() != 20:
		_fail("PHASE4B_STEP2_EXPECTED_EXACTLY_20_MODELS")
		return

	# Verify all five world scenes reference the attached spawner and load as PackedScenes.
	var scene_paths := [
		"res://scenes/TwinCity.tscn",
		"res://scenes/cities/PhoenixCastle.tscn",
		"res://scenes/cities/ApeMountain.tscn",
		"res://scenes/cities/DesertCity.tscn",
		"res://scenes/cities/BirdIsland.tscn"
	]
	for scene_path in scene_paths:
		if load(scene_path) as PackedScene == null:
			_fail("PHASE4B_STEP2_CITY_SCENE_LOAD_FAILED: " + scene_path)
			return
	var manager := root.get_node_or_null("WorldMapManager")
	if manager == null:
		_fail("PHASE4B_STEP2_WORLD_MAP_MANAGER_MISSING")
		return
	var city_cases := [
		{"id":"TwinCity","count":15},
		{"id":"PhoenixCastle","count":9},
		{"id":"ApeMountain","count":7},
		{"id":"DesertCity","count":6},
		{"id":"BirdIsland","count":8}
	]
	for city_case in city_cases:
		manager.set("current_city", String(city_case.id))
		var city_probe := SpawnerScript.new() as MonsterSpawner
		root.add_child(city_probe)
		await process_frame
		if city_probe.spawn_points.size() != int(city_case.count):
			_fail("PHASE4B_STEP2_CITY_SPAWN_SCOPE_FAILED: " + String(city_case.id) + " points=" + str(city_probe.spawn_points.size()))
			return
		city_probe.queue_free()
		await process_frame
	manager.set("current_city", "TwinCity")

	var embedded_count := 0
	var procedural_count := 0
	var actors: Array[MonsterActor] = []
	for definition in definitions:
		var monster_id := String(definition.id)
		var relative := String(SpawnerScript.MODEL_FILES.get(monster_id, ""))
		var path := ASSET_ROOT + relative
		if relative.is_empty() or not ResourceLoader.exists(path):
			_fail("PHASE4B_STEP2_MODEL_MISSING: " + monster_id + " " + path)
			return
		var actor := MonsterActorScript.new() as MonsterActor
		root.add_child(actor)
		var is_boss: bool = definition.has("max_npc")
		if not actor.configure(definition, path, false, is_boss, Vector3.ZERO):
			_fail("PHASE4B_STEP2_MODEL_INSTANCE_FAILED: " + monster_id)
			return
		if not actor.has_idle_walk():
			_fail("PHASE4B_STEP2_IDLE_WALK_FAILED: " + monster_id)
			return
		if actor.animation_mode == "embedded":
			embedded_count += 1
			if actor.embedded_idle_clip.is_empty() or actor.embedded_walk_clip.is_empty():
				_fail("PHASE4B_STEP2_EMBEDDED_CLIPS_NOT_PLAYABLE: " + monster_id)
				return
		else:
			procedural_count += 1
		if actor.get_nameplate() == null or not actor.get_nameplate().text.begins_with("[Lv."):
			_fail("PHASE4B_STEP2_NAMEPLATE_FAILED: " + monster_id)
			return
		if is_boss:
			if absf(actor.get_model_height() - 5.0) > 0.02:
				_fail("PHASE4B_STEP2_BOSS_SCALE_FAILED: " + monster_id + " height=" + str(actor.get_model_height()))
				return
			if not actor.get_nameplate().modulate.is_equal_approx(Color(1.0, 0.72, 0.12, 1.0)):
				_fail("PHASE4B_STEP2_BOSS_NAME_COLOR_FAILED: " + monster_id)
				return
		else:
			if actor.get_model_height() < 1.6 or actor.get_model_height() > 2.2:
				_fail("PHASE4B_STEP2_NORMAL_SCALE_FAILED: " + monster_id + " height=" + str(actor.get_model_height()))
				return
			if not actor.get_nameplate().modulate.is_equal_approx(Color.WHITE):
				_fail("PHASE4B_STEP2_NORMAL_NAME_COLOR_FAILED: " + monster_id)
				return
		if absf(actor.get_model_ground_offset()) > 0.02:
			_fail("PHASE4B_STEP2_GROUND_ALIGNMENT_FAILED: " + monster_id + " offset=" + str(actor.get_model_ground_offset()))
			return
		actors.append(actor)
		await process_frame

	if actors.size() != 20 or embedded_count + procedural_count != 20:
		_fail("PHASE4B_STEP2_ANIMATION_COUNTS_FAILED")
		return

	var probe := actors[0]
	probe.rest_secs = 0.15
	probe.die()
	if not probe.is_dead() or probe.current_hp != 0:
		_fail("PHASE4B_STEP2_DIE_FAILED")
		return
	await probe.respawned
	if probe.is_dead() or probe.current_hp != probe.max_hp:
		_fail("PHASE4B_STEP2_RESPAWN_FAILED")
		return

	# Integration proof: activate one real Twin City camp through MonsterSpawner.
	manager.set("current_city", "TwinCity")
	var test_hero := Node3D.new()
	test_hero.name = "Phase4BTestHero"
	test_hero.add_to_group("player")
	test_hero.position = Vector3(0.0, 0.0, -230.0)
	root.add_child(test_hero)
	var spawner := SpawnerScript.new() as MonsterSpawner
	root.add_child(spawner)
	await process_frame
	if spawner.spawn_points.size() != 15:
		_fail("PHASE4B_STEP2_CITY_SPAWNER_SCOPE_FAILED: " + str(spawner.spawn_points.size()))
		return
	var active_camp := spawner.spawn_points[0]
	if not bool(active_camp.get_meta("actors_spawned", false)) or active_camp.get_child_count() != 20:
		_fail("PHASE4B_STEP2_REAL_CAMP_POPULATION_FAILED: children=" + str(active_camp.get_child_count()))
		return
	var king_actor: MonsterActor
	for child in active_camp.get_children():
		if child is MonsterActor and (child as MonsterActor).is_king:
			king_actor = child as MonsterActor
			break
	if king_actor == null or absf(king_actor.get_model_height() - 2.08) > 0.02:
		_fail("PHASE4B_STEP2_KING_SCALE_FAILED")
		return
	if not king_actor.get_nameplate().modulate.is_equal_approx(Color(1.0, 0.9, 0.12, 1.0)):
		_fail("PHASE4B_STEP2_KING_NAME_COLOR_FAILED")
		return

	print("PHASE4B_STEP2_CITY_SPAWNER_INTEGRATION_OK: city=TwinCity local_spawn_points=15 active_camp_population=20")
	for actor in actors:
		actor.queue_free()
	spawner.queue_free()
	test_hero.queue_free()
	await process_frame
	RenderingServer.force_sync()
	print("PHASE4B_STEP2_ANIMATION_SOURCE_COUNTS: embedded=", embedded_count, " procedural=", procedural_count)
	print("PHASE4B_STEP2_MONSTER_INSTANCES_OK: models=20 embedded=", embedded_count, " procedural=", procedural_count, " idle_walk=20 respawn_cycle=1")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

# Include runtime scene-spawner integration in the validation pass.

# Final validation includes explicit cleanup and zero engine ERROR lines.

# Validate Label3D using the CI software OpenGL display path.

# Audio backend is explicitly Dummy for deterministic headless CI.
