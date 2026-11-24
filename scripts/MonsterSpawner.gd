extends Node3D
class_name MonsterSpawner
## Phase 4B Step 1: creates lightweight spawn-point records only.
## Actual monster scene instantiation is deliberately left for the next phase step.

const TABLE = preload("res://scripts/MonsterGeneratorTable.gd")
const ACTIVATION_DISTANCE_M := 75.0
const KING_SCALE := 1.3
const KING_HP_MULTIPLIER := 2.0
const KING_EXP_MULTIPLIER := 1.5

var hero: Node3D
var spawn_points: Array[Node3D] = []
var active_spawn_points: int = 0

func _ready() -> void:
    build_spawn_points()
    var initial_hero := get_tree().get_first_node_in_group("player")
    if initial_hero is Node3D:
        hero = initial_hero
    _update_distance_activation()

func build_spawn_points() -> void:
    for child in get_children():
        if child.is_in_group("monster_spawn_point"):
            remove_child(child)
            child.queue_free()
    spawn_points.clear()
    var centers := _city_centers()
    for monster in TABLE.MONSTERS:
        var city: String = monster.city
        var offsets: Array = TABLE.CAMP_OFFSETS[city]
        var center: Vector3 = centers[city]
        for camp_index in range(monster.camp_sizes.size()):
            var camp_size: int = int(monster.camp_sizes[camp_index])
            var camp_position: Vector3 = center + offsets[camp_index]
            var camp := _make_spawn_point(monster, camp_index, camp_size, camp_position)
            add_child(camp)
            spawn_points.append(camp)
    for boss in TABLE.WORLD_BOSSES:
        var city: String = boss.city
        var center: Vector3 = centers[city]
        var boss_position := center + Vector3(200.0, 0.0, 0.0)
        var point := Node3D.new()
        point.name = "WorldBoss_" + String(boss.id).replace(" ", "")
        point.position = boss_position
        point.add_to_group("monster_spawn_point")
        point.set_meta("spawn_kind", "world_boss")
        point.set_meta("monster_id", boss.id)
        point.set_meta("level", boss.level)
        point.set_meta("hp", boss.hp)
        point.set_meta("damage", boss.damage)
        point.set_meta("exp", boss.exp)
        point.set_meta("max_npc", boss.max_npc)
        point.set_meta("scale", boss.scale)
        point.set_meta("rest_secs", boss.rest_secs)
        add_child(point)
        spawn_points.append(point)
    print("PHASE4B_SPAWN_POINTS_BUILT: camps=", TABLE.camp_count(),
        " bosses=", TABLE.WORLD_BOSSES.size(),
        " normal_population=", TABLE.scheduled_normal_count(),
        " total_scheduled=", TABLE.scheduled_world_count())

func _make_spawn_point(monster: Dictionary, camp_index: int, camp_size: int, camp_position: Vector3) -> Node3D:
    var point := Node3D.new()
    point.name = "Spawn_" + String(monster.id) + "_%02d" % camp_index
    point.position = camp_position
    point.add_to_group("monster_spawn_point")
    point.set_meta("spawn_kind", "monster_camp")
    point.set_meta("monster_id", monster.id)
    point.set_meta("cq_monstertype", monster.cq_name)
    point.set_meta("city_id", monster.city)
    point.set_meta("camp_index", camp_index)
    point.set_meta("rect_size", TABLE.CAMP_SIZE_M)
    point.set_meta("max_npc", camp_size)
    point.set_meta("level", monster.level)
    point.set_meta("hp", monster.hp)
    point.set_meta("damage", monster.damage)
    point.set_meta("exp", monster.exp)
    point.set_meta("rest_secs", monster.rest_secs)
    point.set_meta("king_count", 1)
    point.set_meta("king_scale", KING_SCALE)
    point.set_meta("king_hp", int(monster.hp) * int(KING_HP_MULTIPLIER))
    point.set_meta("king_exp", int(round(int(monster.exp) * KING_EXP_MULTIPLIER)))
    return point

func _city_centers() -> Dictionary:
    var centers: Dictionary = {}
    var manager := get_node_or_null("/root/WorldMapManager")
    for city in TABLE.CITY_ORDER:
        var center: Vector3 = TABLE.CITY_CENTER_FALLBACKS[city]
        if manager != null and manager.has_method("get_city_center"):
            center = manager.get_city_center(city)
        centers[city] = center
    return centers

func set_hero(target: Node3D) -> void:
    hero = target
    _update_distance_activation()

func _process(_delta: float) -> void:
    if not is_instance_valid(hero):
        var candidate := get_tree().get_first_node_in_group("player")
        if candidate is Node3D:
            hero = candidate
    if is_instance_valid(hero):
        _update_distance_activation()

func _update_distance_activation() -> void:
    active_spawn_points = 0
    if not is_instance_valid(hero):
        return
    for point in spawn_points:
        if not is_instance_valid(point):
            continue
        var world_position := point.global_position
        var distance := hero.global_position.distance_to(world_position)
        var enabled := distance <= ACTIVATION_DISTANCE_M
        point.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
        point.set_process(enabled)
        point.set_physics_process(enabled)
        point.set_meta("distance_active", enabled)
        if enabled:
            active_spawn_points += 1

func get_spawn_summary() -> Dictionary:
    return {
        "camp_count": TABLE.camp_count(),
        "boss_count": TABLE.WORLD_BOSSES.size(),
        "normal_population": TABLE.scheduled_normal_count(),
        "total_scheduled": TABLE.scheduled_world_count(),
        "king_count": TABLE.king_count(),
        "spawn_point_count": spawn_points.size()
    }
