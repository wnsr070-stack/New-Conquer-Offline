extends Node3D
class_name MonsterSpawner
## Phase 4B Steps 2-3: runtime instances, five-city ground placement and real scene activation.

const TABLE = preload("res://scripts/MonsterGeneratorTable.gd")
const MonsterActorScript = preload("res://scripts/MonsterActor.gd")
const ACTIVATION_DISTANCE_M := 45.0
const MAX_ACTIVE_MONSTERS := 80
const MIN_ACTIVE_CAMP_POPULATION := 35
const KING_SCALE := 1.3
const KING_HP_MULTIPLIER := 2.0
const KING_EXP_MULTIPLIER := 1.5
const BOSS_OFFSETS := {
	"TwinCity": Vector3(65.0, 0.0, -230.0),
	"PhoenixCastle": Vector3(0.0, 0.0, 330.0),
	"ApeMountain": Vector3(0.0, 0.0, 380.0),
	"DesertCity": Vector3(0.0, 0.0, 380.0),
	"BirdIsland": Vector3(50.0, 0.0, -25.0)
}
const ASSET_ROOT := "res://assets/phase3b/"
const MODEL_FILES := {
	"Bunny": "monsters/normal/bunny.glb",
	"Chicken": "monsters/normal/chicken.glb",
	"Dog": "monsters/normal/dog.glb",
	"Cactoro": "monsters/normal/cactoro.glb",
	"Orc": "monsters/normal/orc.glb",
	"Demon": "monsters/normal/demon.glb",
	"Ghost": "monsters/normal/ghost.glb",
	"Blob": "monsters/normal/blob.glb",
	"Dino": "monsters/normal/dino.glb",
	"Birb": "monsters/normal/birb.glb",
	"Pigeon": "monsters/normal/pigeon.glb",
	"Frog": "monsters/normal/frog.glb",
	"Yeti": "monsters/normal/yeti.glb",
	"Alien": "monsters/normal/alien.glb",
	"Armabee": "monsters/normal/armabee.glb",
	"Alpaking Evolved": "monsters/bosses/alpaking_evolved.glb",
	"Mushroom King": "monsters/bosses/mushroom_king.glb",
	"Blue Demon": "monsters/bosses/blue_demon.glb",
	"Orc Skull": "monsters/bosses/orc_skull.glb",
	"Dragon Evolved": "monsters/bosses/dragon_evolved.glb"
}

var hero: Node3D
var current_city := "TwinCity"
var spawn_points: Array[Node3D] = []
var active_spawn_points: int = 0
var _definitions: Dictionary = {}
var _model_cache: Dictionary = {}

func _ready() -> void:
	add_to_group("monster_spawner")
	var manager := get_node_or_null("/root/WorldMapManager")
	if manager != null:
		current_city = String(manager.get("current_city"))
	for item in TABLE.MONSTERS:
		_definitions[String(item.id)] = item
	for item in TABLE.WORLD_BOSSES:
		_definitions[String(item.id)] = item
	for item in TABLE.QUEST_BOSSES:
		_definitions[String(item.id)] = item
	build_spawn_points()
	var initial_hero := _find_hero()
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
		if String(monster.city) != current_city:
			continue
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
		if String(boss.city) != current_city:
			continue
		var city: String = boss.city
		var center: Vector3 = centers[city]
		var boss_position: Vector3 = center + BOSS_OFFSETS.get(city, Vector3(0.0, 0.0, 330.0))
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
	for boss in TABLE.QUEST_BOSSES:
		if String(boss.city) != current_city:
			continue
		var city: String = boss.city
		var center: Vector3 = centers[city]
		var point := Node3D.new()
		point.name = "QuestZone_" + String(boss.id).replace(" ", "")
		point.position = center + Vector3(130.0, 0.0, -75.0)
		point.add_to_group("monster_spawn_point")
		point.set_meta("spawn_kind", "quest_boss")
		point.set_meta("quest_zone", "RebornQuestZone")
		var zone_marker := Label3D.new()
		zone_marker.name = "RebornQuestZoneMarker"
		zone_marker.text = "REBorn QUEST ZONE  •  Lv.130+"
		zone_marker.font_size = 48
		zone_marker.pixel_size = 0.012
		zone_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		zone_marker.no_depth_test = true
		zone_marker.modulate = Color(0.25, 0.85, 1.0, 1.0)
		zone_marker.position = Vector3(0.0, 8.0, 0.0)
		point.add_child(zone_marker)
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

func _find_hero() -> Node3D:
	var candidate := get_tree().get_first_node_in_group("player")
	if candidate is Node3D:
		return candidate as Node3D
	var named_hero := get_tree().root.find_child("TwinCityPlayableHero", true, false)
	if named_hero is Node3D:
		return named_hero as Node3D
	return null

func _process(_delta: float) -> void:
	if not is_instance_valid(hero):
		var candidate := _find_hero()
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
		var enabled := hero.global_position.distance_to(point.global_position) <= ACTIVATION_DISTANCE_M
		point.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
		point.set_process(enabled)
		point.set_physics_process(enabled)
		point.set_meta("distance_active", enabled)
		if enabled:
			active_spawn_points += 1
			_ensure_point_population(point)
		else:
			_release_point_population(point)

func _ensure_point_population(point: Node3D) -> void:
	if bool(point.get_meta("actors_spawned", false)):
		return
	var monster_id := String(point.get_meta("monster_id", ""))
	if not _definitions.has(monster_id):
		push_error("MonsterSpawner: missing definition " + monster_id)
		return
	var definition: Dictionary = _definitions[monster_id]
	point.set_meta("sleeping", false)
	var center := point.global_position
	var spawn_kind := String(point.get_meta("spawn_kind", ""))
	var is_boss := spawn_kind in ["world_boss", "quest_boss"]
	var requested_population := 1 if is_boss else int(point.get_meta("max_npc", 1))
	var remaining_capacity := maxi(0, MAX_ACTIVE_MONSTERS - _count_active_monsters())
	var population := mini(requested_population, remaining_capacity)
	if not is_boss and population < MIN_ACTIVE_CAMP_POPULATION:
		return
	var regular_count := population if is_boss else maxi(0, population - 1)
	for i in range(regular_count):
		if not _spawn_actor(point, definition, false, is_boss, center):
			return
	if not is_boss and int(point.get_meta("king_count", 0)) > 0:
		var king_data := definition.duplicate(true)
		king_data["hp"] = int(point.get_meta("king_hp", definition.get("hp", 1)))
		king_data["exp"] = int(point.get_meta("king_exp", definition.get("exp", 0)))
		if not _spawn_actor(point, king_data, true, false, center):
			return
	point.set_meta("active_population", population)
	point.set_meta("actors_spawned", true)
	print("MONSTER_CAMP_ACTIVE: id=", monster_id, " population=", population, " radius_m=", ACTIVATION_DISTANCE_M, " cap=", MAX_ACTIVE_MONSTERS)

func _count_active_monsters() -> int:
	var total := 0
	for point in spawn_points:
		if not is_instance_valid(point) or not bool(point.get_meta("distance_active", false)):
			continue
		for child in point.get_children():
			if child is MonsterActor:
				total += 1
	return total

func _release_point_population(point: Node3D) -> void:
	if not bool(point.get_meta("actors_spawned", false)):
		return
	for child in point.get_children():
		if child is MonsterActor:
			point.remove_child(child)
			child.queue_free()
	point.set_meta("actors_spawned", false)
	point.set_meta("active_population", 0)
	point.set_meta("sleeping", true)

func _spawn_actor(point: Node3D, definition: Dictionary, king: bool, boss: bool, center: Vector3) -> bool:
	var monster_id := String(definition.get("id", ""))
	var relative := String(MODEL_FILES.get(monster_id, ""))
	if relative.is_empty():
		push_error("MonsterSpawner: no Phase 3B GLB mapping for " + monster_id)
		return false
	var path := ASSET_ROOT + relative
	if not _model_cache.has(monster_id):
		if not ResourceLoader.exists(path):
			push_error("MonsterSpawner: Phase 3B model missing: " + path)
			return false
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("MonsterSpawner: Phase 3B GLB failed to load: " + path)
			return false
		_model_cache[monster_id] = packed
	var actor := MonsterActorScript.new() as MonsterActor
	actor.name = ("King_" if king else ("Boss_" if boss else "Mob_")) + monster_id.replace(" ", "")
	point.add_child(actor)
	var actor_data := definition.duplicate(true)
	if not actor.configure(actor_data, path, king, boss, center):
		actor.queue_free()
		return false
	actor.camp_half_extent = Vector2.ZERO if boss else TABLE.CAMP_SIZE_M * 0.5
	actor.global_position = center if boss else center + Vector3(_rng_offset(), 0.0, _rng_offset())
	return true

func _rng_offset() -> float:
	return randf_range(-18.0, 18.0)

func get_spawn_summary() -> Dictionary:
	return {
		"camp_count": TABLE.camp_count(),
		"boss_count": TABLE.WORLD_BOSSES.size(),
		"normal_population": TABLE.scheduled_normal_count(),
		"total_scheduled": TABLE.scheduled_world_count(),
		"king_count": TABLE.king_count(),
		"spawn_point_count": spawn_points.size(),
		"loaded_model_count": _model_cache.size(),
		"active_monsters": _count_active_monsters(),
		"activation_distance_m": ACTIVATION_DISTANCE_M,
		"active_monster_cap": MAX_ACTIVE_MONSTERS
	}

func get_monster_camp_position(monster_id: String) -> Vector3:
	var centers := _city_centers()
	for monster in TABLE.MONSTERS:
		if String(monster.id) != monster_id:
			continue
		var city := String(monster.city)
		var offsets: Array = TABLE.CAMP_OFFSETS.get(city, [])
		if offsets.is_empty():
			return centers.get(city, Vector3.ZERO)
		var center: Vector3 = centers.get(city, Vector3.ZERO)
		var offset: Vector3 = offsets[0]
		return center + offset
	for boss in TABLE.WORLD_BOSSES:
		if String(boss.id) == monster_id:
			var city := String(boss.city)
			var center: Vector3 = centers.get(city, Vector3.ZERO)
			var offset: Vector3 = BOSS_OFFSETS.get(city, Vector3(0.0,0.0,330.0))
			return center + offset
	for boss in TABLE.QUEST_BOSSES:
		if String(boss.id) == monster_id:
			return centers.get(String(boss.city), Vector3.ZERO) + Vector3(130.0, 0.0, -75.0)
	return Vector3.ZERO

func get_monster_camp_city(monster_id: String) -> String:
	for monster in TABLE.MONSTERS:
		if String(monster.id) == monster_id:
			return String(monster.city)
	for boss in TABLE.WORLD_BOSSES:
		if String(boss.id) == monster_id:
			return String(boss.city)
	return ""
