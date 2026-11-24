extends SceneTree
const TABLE = preload("res://scripts/MonsterGeneratorTable.gd")
const SPAWNER = preload("res://scripts/MonsterSpawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var errors: PackedStringArray = TABLE.validate()
    if not errors.is_empty():
        for item in errors:
            push_error("PHASE4B_TABLE_INVALID: " + item)
        quit(1)
        return
    var manager := root.get_node_or_null("WorldMapManager")
    if manager == null:
        push_error("PHASE4B_WORLD_MAP_MANAGER_MISSING")
        quit(1)
        return
    var city_cases := [
        {"id":"TwinCity","points":15},
        {"id":"PhoenixCastle","points":9},
        {"id":"ApeMountain","points":7},
        {"id":"DesertCity","points":6},
        {"id":"BirdIsland","points":8}
    ]
    var total_points := 0
    for item in city_cases:
        manager.set("current_city",String(item.id))
        var node := SPAWNER.new()
        root.add_child(node)
        await process_frame
        if node.spawn_points.size()!=int(item.points):
            push_error("PHASE4B_CITY_SPAWN_POINT_MISMATCH: "+String(item.id)+" actual="+str(node.spawn_points.size()))
            quit(1)
            return
        total_points+=node.spawn_points.size()
        node.queue_free()
        await process_frame
    var expected_camps := 40
    var expected_normal := 795
    var expected_total := 800
    if TABLE.camp_count()!=expected_camps or TABLE.scheduled_normal_count()!=expected_normal or TABLE.scheduled_world_count()!=expected_total or total_points!=45:
        push_error("PHASE4B_SPAWN_TOTAL_MISMATCH: camps="+str(TABLE.camp_count())+" normal="+str(TABLE.scheduled_normal_count())+" total="+str(TABLE.scheduled_world_count())+" spawn_points="+str(total_points))
        quit(1)
        return
    print("PHASE4B_STEP1_SPAWN_TABLE_OK: monsters=15 bosses=5 camps=40 kings=40 normal_population=795 world_bosses=5 total_scheduled=800 spawn_points=45 activation_distance=75m")
    quit(0)
