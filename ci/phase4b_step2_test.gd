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
		if actor.get_model_height() <= 0.0:
			_fail("PHASE4B_STEP2_MODEL_HEIGHT_FAILED: " + monster_id)
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

	print("PHASE4B_STEP2_ANIMATION_SOURCE_COUNTS: embedded=", embedded_count, " procedural=", procedural_count)
	print("PHASE4B_STEP2_MONSTER_INSTANCES_OK: models=20 embedded=", embedded_count, " procedural=", procedural_count, " idle_walk=20 respawn_cycle=1")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
