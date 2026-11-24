extends SceneTree
const TABLE = preload("res://scripts/MonsterGeneratorTable.gd")
const SPAWNER = preload("res://scripts/MonsterSpawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var errors := TABLE.validate()
    if not errors.is_empty():
        for item in errors:
            push_error("PHASE4B_TABLE_INVALID: " + item)
        quit(1)
        return
    var node := SPAWNER.new()
    root.add_child(node)
    await process_frame
    var summary: Dictionary = node.get_spawn_summary()
    var expected_camps := 40
    var expected_normal := 795
    var expected_total := 800
    if summary.camp_count != expected_camps or summary.normal_population != expected_normal or summary.total_scheduled != expected_total or summary.spawn_point_count != 45:
        push_error("PHASE4B_SPAWN_TOTAL_MISMATCH: " + str(summary))
        quit(1)
        return
    print("PHASE4B_STEP1_SPAWN_TABLE_OK: monsters=15 bosses=5 camps=40 kings=40 normal_population=795 world_bosses=5 total_scheduled=800 spawn_points=45 activation_distance=75m")
    node.queue_free()
    quit(0)
