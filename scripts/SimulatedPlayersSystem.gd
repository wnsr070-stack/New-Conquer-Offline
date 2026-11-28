extends Node
## Phase 5B: offline simulated players. Actors are data-only while distant and
## instantiate the approved rigged assassin GLB only inside the active radius.
signal simulated_chat_message(channel: String, speaker: String, message: String)

const HERO_MODEL := "res://assets/mounts/hero_assassin.glb"
const ACTIVATION_RADIUS_M := 55.0
const MAX_ACTIVE_PLAYERS := 30
const TOTAL_PLAYERS := 85
const HUNTER_COUNT := 15
const VISIBLE_HUNTERS := 4
const CITY_COUNTS := {
	"TwinCity": 30,
	"PhoenixCastle": 10,
	"ApeMountain": 10,
	"DesertCity": 10,
	"BirdIsland": 10
}
const MOUNT_MODELS := {
	"steed": "res://assets/mounts/steed_horse.glb",
	"deer": "res://assets/mounts/mount_deer.glb",
	"wolf": "res://assets/mounts/mount_wolf.glb"
}
const ARABIC_NAMES := ["فارس الليل", "ظل التنين", "قمر الشرق", "سيف الصحراء", "نسيم الفجر", "عين النمر", "صقر السماء", "روح العنقاء", "نصل القمر", "حارس الوادي", "ليث الجبال", "شهاب"]
const ENGLISH_NAMES := ["SilentBlade", "MoonRider", "AzureFang", "NightLotus", "StormDancer", "JadeShadow", "CrimsonFox", "SkyWarden", "IronPetal", "SwiftRaven", "DawnHunter", "GhostStep"]
const CHAT_TEMPLATES := {
	"world": [
		"أهلًا بكل اللاعبين في Twin City 🌟",
		"مين جاي يصطاد زعيم الصحراء؟",
		"مساء الخير يا أبطال، صيد موفق للجميع",
		"حد يعرف مكان مدخل Ape Mountain؟",
		"مبروك لكل اللي وصلوا للمستوى الجديد!"
	],
	"trade": [
		"للبيع Meteor بسعر مناسب، همس للتفاصيل",
		"أبحث عن Dragon Ball، الدفع Gold",
		"تم تطوير السلاح +12 ✨ مبروك علينا!",
		"مطلوب أحجار تطوير، عروض جادة فقط",
		"تبادل مطايا؟ عندي ذئب وأبحث عن حصان"
	],
	"team": [
		"فريق صيد مفتوح، اللي عايز ينضم ييجي",
		"دعوة لقتل زعيم Phoenix Castle، التجمع عند البوابة",
		"محتاجين لاعب إضافي لصيد الوحوش",
		"استعدوا، هنبدأ جولة الصيد بعد دقيقة",
		"مين معانا في مهمة Reborn؟"
	]
}

var _rng := RandomNumberGenerator.new()
var _roster: Array[Dictionary] = []
var _active_actors: Dictionary = {}
var _scene_root: Node3D
var _last_city := ""
var _sync_clock := 0.0
var _simulation_clock := 0.0
var _chat_clock := 0.0
var _chat_history: Array[Dictionary] = []
var _hero_scene: PackedScene
var _mount_scenes: Dictionary = {}
var _last_chat_channel_index := 0

func _ready() -> void:
	_rng.randomize()
	build_roster()
	set_process(true)
	print("PHASE5B_SIMULATED_PLAYERS_READY: total=85 twin_city=30 subcities=40 wilderness=15 active_cap=30 radius=55m")

func build_roster() -> void:
	_roster.clear()
	var twin_hub := [
		Vector3(-18.0, 0.0, -52.0), Vector3(-13.5, 0.0, -52.0), Vector3(-9.0, 0.0, -52.0),
		Vector3(-4.5, 0.0, -52.0), Vector3(0.0, 0.0, -52.0), Vector3(4.5, 0.0, -52.0),
		Vector3(9.0, 0.0, -52.0), Vector3(13.5, 0.0, -52.0), Vector3(18.0, 0.0, -52.0),
		Vector3(-18.0, 0.0, -43.0), Vector3(-9.0, 0.0, -43.0), Vector3(0.0, 0.0, -43.0),
		Vector3(9.0, 0.0, -43.0), Vector3(18.0, 0.0, -43.0), Vector3(0.0, 0.0, -34.0)
	]
	var twin_roads := [
		Vector3(-42.0, 0.0, -42.0), Vector3(-48.0, 0.0, -18.0), Vector3(-44.0, 0.0, 8.0),
		Vector3(-38.0, 0.0, 35.0), Vector3(-20.0, 0.0, 48.0), Vector3(0.0, 0.0, 54.0),
		Vector3(20.0, 0.0, 48.0), Vector3(40.0, 0.0, 34.0), Vector3(48.0, 0.0, 10.0),
		Vector3(48.0, 0.0, -16.0), Vector3(40.0, 0.0, -42.0), Vector3(22.0, 0.0, -58.0),
		Vector3(-22.0, 0.0, -62.0), Vector3(58.0, 0.0, 0.0), Vector3(-58.0, 0.0, 0.0)
	]
	for i in range(15):
		_add_player("TwinCity", "hub", twin_hub[i], i, i % 4 == 0)
	for i in range(15):
		_add_player("TwinCity", "gate_road", twin_roads[i], i + 15, false)

	var city_positions := {
		"PhoenixCastle": [Vector3(-18,0,-98), Vector3(-13.5,0,-98), Vector3(-9,0,-98), Vector3(-4.5,0,-98), Vector3(0,0,-98), Vector3(4.5,0,-98), Vector3(9,0,-98), Vector3(13.5,0,-98), Vector3(18,0,-98), Vector3(22.5,0,-98)],
		"ApeMountain": [Vector3(-84,0,-52), Vector3(-79.5,0,-52), Vector3(-75,0,-52), Vector3(-70.5,0,-52), Vector3(-66,0,-52), Vector3(-61.5,0,-52), Vector3(-57,0,-52), Vector3(-52.5,0,-52), Vector3(-48,0,-52), Vector3(-43.5,0,-52)],
		"DesertCity": [Vector3(-20,0,-88), Vector3(-15,0,-88), Vector3(-10,0,-88), Vector3(-5,0,-88), Vector3(0,0,-88), Vector3(5,0,-88), Vector3(10,0,-88), Vector3(15,0,-88), Vector3(20,0,-88), Vector3(25,0,-88)],
		"BirdIsland": [Vector3(25.25,4.6,2), Vector3(29.75,4.6,2), Vector3(34.25,4.6,2), Vector3(38.75,4.6,2), Vector3(43.25,4.6,2), Vector3(47.75,4.6,2), Vector3(52.25,4.6,2), Vector3(56.75,4.6,2), Vector3(61.25,4.6,2), Vector3(65.75,4.6,2)]
	}
	for city in ["PhoenixCastle", "ApeMountain", "DesertCity", "BirdIsland"]:
		var positions: Array = city_positions[city]
		for i in range(10):
			_add_player(city, "city", positions[i], i, i == 2 or i == 7)

	for i in range(HUNTER_COUNT):
		_add_player("Wilderness", "hunter", Vector3.ZERO, i, false, true)
	print("PHASE5B_ROSTER_BUILT: twin=30 phoenix=10 ape=10 desert=10 bird=10 hunters=15 total=", _roster.size())

func _add_player(city: String, role: String, spawn: Vector3, index: int, mounted: bool, hunter: bool = false) -> void:
	var name_index := _roster.size()
	var display_name := String(ARABIC_NAMES[name_index % ARABIC_NAMES.size()]) if name_index % 2 == 0 else String(ENGLISH_NAMES[name_index % ENGLISH_NAMES.size()])
	var mount_type := ["steed", "deer", "wolf"][index % 3] if mounted else ""
	_roster.append({
		"id": "sim_%03d" % name_index,
		"city": city,
		"role": role,
		"base_position": spawn,
		"current_position": spawn,
		"display_name": display_name,
		"level": _rng.randi_range(40, 130),
		"plus_level": _rng.randi_range(1, 12),
		"mounted": mounted,
		"mount_type": mount_type,
		"hunter": hunter,
		"active": false,
		"actor": null,
		"wander_target": spawn,
		"move_clock": _rng.randf_range(0.8, 3.0),
		"pause_clock": _rng.randf_range(0.0, 2.0),
		"hop_phase": _rng.randf_range(0.0, TAU),
		"attack_clock": _rng.randf_range(0.5, 2.0)
	})

func _process(delta: float) -> void:
	_simulation_clock += delta
	_sync_clock += delta
	_chat_clock += delta
	if _chat_clock >= _rng.randf_range(5.0, 9.0):
		_chat_clock = 0.0
		post_simulated_chat_message(["world", "trade", "team"][_rng.randi_range(0, 2)])
	if _sync_clock < 0.35:
		return
	_sync_clock = 0.0
	var hero := _find_hero()
	if hero == null:
		return
	var current_scene := get_tree().current_scene as Node3D
	var manager := get_node_or_null("/root/WorldMapManager")
	var city := String(manager.get("current_city")) if manager != null else "TwinCity"
	if current_scene == null:
		return
	if current_scene != _scene_root or city != _last_city:
		_clear_runtime_actors()
		_scene_root = current_scene
		_last_city = city
	_sync_active_actors(hero, city)
	_update_active_actors(delta, hero)

func _find_hero() -> Node3D:
	var grouped := get_tree().get_first_node_in_group("player")
	if grouped is Node3D:
		return grouped as Node3D
	var named := get_tree().root.find_child("PlayableHero", true, false)
	if named is Node3D:
		return named as Node3D
	var legacy := get_tree().root.find_child("TwinCityPlayableHero", true, false)
	return legacy as Node3D if legacy is Node3D else null

func _sync_active_actors(hero: Node3D, city: String) -> void:
	var city_candidates: Array[Dictionary] = []
	var hunter_candidates: Array[Dictionary] = []
	var hero_position := hero.global_position
	for entry in _roster:
		if String(entry.city) == city and not bool(entry.hunter):
			entry.current_position = _scene_root.to_global(entry.base_position)
			var distance := hero_position.distance_to(entry.current_position)
			if distance <= ACTIVATION_RADIUS_M:
				city_candidates.append(entry)
	for i in range(HUNTER_COUNT):
		var hunter: Dictionary = _roster[_roster.size() - HUNTER_COUNT + i]
		var angle := float(i) * TAU / float(HUNTER_COUNT) + _simulation_clock * 0.045
		var radius := 10.0 + float(i % 4) * 2.3 if i < VISIBLE_HUNTERS else 70.0 + float(i - VISIBLE_HUNTERS) * 3.0
		hunter.current_position = hero_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if i < VISIBLE_HUNTERS:
			hunter_candidates.append(hunter)
	city_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return hero_position.distance_squared_to(a.current_position) < hero_position.distance_squared_to(b.current_position)
	)
	var city_limit := MAX_ACTIVE_PLAYERS - VISIBLE_HUNTERS
	if city_candidates.size() > city_limit:
		city_candidates.resize(city_limit)
	var candidates: Array[Dictionary] = city_candidates
	for hunter in hunter_candidates:
		candidates.append(hunter)
	var wanted: Dictionary = {}
	for entry in candidates:
		wanted[String(entry.id)] = true
	for actor_id in _active_actors.keys():
		if not wanted.has(String(actor_id)):
			_release_actor(String(actor_id))
	for entry in candidates:
		var actor_id := String(entry.id)
		if not _active_actors.has(actor_id):
			_spawn_actor(entry)
		entry.active = true
		var actor: Node3D = _active_actors.get(actor_id) as Node3D
		if is_instance_valid(actor):
			entry.actor = actor
			if bool(entry.hunter):
				actor.global_position = entry.current_position
			elif String(entry.role) == "gate_road":
				actor.global_position = entry.current_position
	_active_actors = _active_actors.duplicate()
	print("PHASE5B_PROXIMITY_SYNC: city=", city, " active=", _active_actors.size(), " max=", MAX_ACTIVE_PLAYERS, " radius=55m")

func _spawn_actor(entry: Dictionary) -> void:
	if _scene_root == null or not is_instance_valid(_scene_root):
		return
	if _hero_scene == null:
		if not ResourceLoader.exists(HERO_MODEL):
			push_error("PHASE5B_ASSASSIN_MODEL_MISSING: " + HERO_MODEL)
			return
		_hero_scene = load(HERO_MODEL) as PackedScene
	if _hero_scene == null:
		push_error("PHASE5B_ASSASSIN_MODEL_LOAD_FAILED")
		return
	var actor := Node3D.new()
	actor.name = "SimulatedPlayer_" + String(entry.id)
	actor.set_meta("simulated_player", true)
	actor.set_meta("plus_level", int(entry.plus_level))
	_scene_root.add_child(actor)
	actor.global_position = entry.current_position
	var model := _hero_scene.instantiate() as Node3D
	if model == null:
		actor.queue_free()
		return
	model.name = "OrientalAssassinRig"
	actor.add_child(model)
	AssetLoader.fit_height(model, 1.75)
	var animation_nodes := model.find_children("*", "AnimationPlayer", true, false)
	if not animation_nodes.is_empty():
		var animation_player := animation_nodes[0] as AnimationPlayer
		for clip in animation_player.get_animation_list():
			var clip_name := String(clip).to_lower()
			if clip_name.contains("walk") or clip_name.contains("run"):
				animation_player.play(String(clip))
				break
	if bool(entry.mounted):
		_attach_mount(actor, String(entry.mount_type))
		model.position.y = 0.72
	_add_nameplate(actor, entry)
	var aura_manager := get_node_or_null("/root/AuraAndVFXManager")
	if aura_manager != null:
		aura_manager.attach_equipment_aura(actor, int(entry.plus_level), false)
	_active_actors[String(entry.id)] = actor
	entry.actor = actor
	entry.active = true
	entry.wander_target = actor.global_position
	print("PHASE5B_SIMULATED_PLAYER_SPAWNED: id=", entry.id, " name=", entry.display_name, " plus=+", entry.plus_level, " mounted=", entry.mounted)

func _attach_mount(actor: Node3D, mount_type: String) -> void:
	var path := String(MOUNT_MODELS.get(mount_type, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var packed := _mount_scenes.get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
		_mount_scenes[path] = packed
	if packed == null:
		return
	var mount := packed.instantiate() as Node3D
	if mount == null:
		return
	mount.name = "SimulatedMount_" + mount_type
	actor.add_child(mount)
	AssetLoader.fit_height(mount, 1.45)
	mount.position = Vector3(0.0, 0.0, 0.35)

func _add_nameplate(actor: Node3D, entry: Dictionary) -> void:
	var label := Label3D.new()
	label.name = "SimulatedPlayerNameplate"
	label.text = "%s  [Lv.%d]  +%d" % [String(entry.display_name), int(entry.level), int(entry.plus_level)]
	label.font = ThemeDB.fallback_font
	label.font_size = 40
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 7
	label.outline_modulate = Color(0.025, 0.018, 0.012, 1.0)
	label.modulate = Color(1.0, 0.82, 0.28) if int(entry.plus_level) >= 9 else Color(0.55, 0.86, 1.0) if int(entry.plus_level) >= 5 else Color(0.94, 0.94, 0.90)
	label.position = Vector3(0.0, 3.15 if not bool(entry.mounted) else 4.25, 0.0)
	actor.add_child(label)
	var halo := Label3D.new()
	halo.name = "SimulatedPlayerEnhancementHalo"
	halo.text = "✦"
	halo.font_size = 48
	halo.pixel_size = 0.009
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.no_depth_test = true
	halo.modulate = Color(1.0, 0.74, 0.18) if int(entry.plus_level) >= 9 else Color(0.30, 0.72, 1.0)
	halo.position = Vector3(0.0, 2.65 if not bool(entry.mounted) else 3.75, 0.0)
	actor.add_child(halo)

func _release_actor(actor_id: String) -> void:
	var entry_index := -1
	for i in range(_roster.size()):
		if String(_roster[i].id) == actor_id:
			entry_index = i
			break
	if entry_index >= 0:
		_roster[entry_index].active = false
		_roster[entry_index].actor = null
	var actor_value: Variant = _active_actors.get(actor_id)
	if is_instance_valid(actor_value):
		var actor := actor_value as Node3D
		if actor.get_parent() != null:
			actor.queue_free()
	_active_actors.erase(actor_id)

func _clear_runtime_actors() -> void:
	for actor_id in _active_actors.keys().duplicate():
		_release_actor(String(actor_id))
	_active_actors.clear()

func _update_active_actors(delta: float, hero: Node3D) -> void:
	for actor_id in _active_actors.keys():
		var actor := _active_actors[actor_id] as Node3D
		if not is_instance_valid(actor):
			_active_actors.erase(actor_id)
			continue
		var entry: Dictionary = _find_entry(String(actor_id))
		if entry.is_empty():
			continue
		if bool(entry.hunter):
			_update_hunter(entry, actor, delta, hero)
		else:
			_update_city_player(entry, actor, delta)

func _find_entry(actor_id: String) -> Dictionary:
	for entry in _roster:
		if String(entry.id) == actor_id:
			return entry
	return {}

func _update_city_player(entry: Dictionary, actor: Node3D, delta: float) -> void:
	entry.move_clock = float(entry.move_clock) - delta
	entry.pause_clock = maxf(0.0, float(entry.pause_clock) - delta)
	if float(entry.pause_clock) <= 0.0 and float(entry.move_clock) <= 0.0:
		var base: Vector3 = _scene_root.to_global(entry.base_position)
		entry.wander_target = base + Vector3(_rng.randf_range(-5.0, 5.0), 0.0, _rng.randf_range(-5.0, 5.0))
		entry.move_clock = _rng.randf_range(2.0, 5.0)
		if _rng.randf() < 0.28:
			entry.pause_clock = _rng.randf_range(1.5, 3.5)
	var target: Vector3 = entry.wander_target
	if float(entry.pause_clock) <= 0.0:
		actor.global_position = step_towards(actor.global_position, target, 1.25, delta)
	var hop := 0.12 * absf(sin(_simulation_clock * 3.6 + float(entry.hop_phase)))
	actor.global_position.y = _scene_root.to_global(entry.base_position).y + hop
	var movement := target - actor.global_position
	if movement.length_squared() > 0.04:
		actor.look_at(actor.global_position + Vector3(movement.x, 0.0, movement.z), Vector3.UP)

func _update_hunter(entry: Dictionary, actor: Node3D, delta: float, hero: Node3D) -> void:
	var hunter_index := int(String(entry.id).trim_prefix("sim_"))
	var angle := float(hunter_index % HUNTER_COUNT) * TAU / float(HUNTER_COUNT) + _simulation_clock * 0.045
	var target := hero.global_position + Vector3(cos(angle) * (10.0 + float(hunter_index % 4) * 2.3), 0.0, sin(angle) * (10.0 + float(hunter_index % 4) * 2.3))
	actor.global_position = step_towards(actor.global_position, target, 2.0, delta)
	entry.attack_clock = float(entry.attack_clock) - delta
	if float(entry.attack_clock) <= 0.0:
		entry.attack_clock = _rng.randf_range(2.5, 4.0)
		_play_visual_hunter_attack(actor)

func _play_visual_hunter_attack(actor: Node3D) -> void:
	var nearest: Node3D
	var nearest_distance := 14.0
	for candidate in get_tree().root.find_children("*", "MonsterActor", true, false):
		if not candidate is Node3D:
			continue
		var monster := candidate as Node3D
		var distance := actor.global_position.distance_to(monster.global_position)
		if distance < nearest_distance and int(monster.get("current_hp")) > 0:
			nearest = monster
			nearest_distance = distance
	if nearest == null:
		return
	var vfx := get_node_or_null("/root/AuraAndVFXManager")
	if vfx != null:
		vfx.play_skill_vfx("shockwave", "blue", nearest.global_position + Vector3(0.0, 0.8, 0.0), actor.global_position.direction_to(nearest.global_position))
	# Intentionally visual-only: never call CombatSystem, SkillSystem, loot or GameState.

func post_simulated_chat_message(channel: String) -> Dictionary:
	var normalized := channel.to_lower()
	if not CHAT_TEMPLATES.has(normalized):
		normalized = "world"
	var templates: Array = CHAT_TEMPLATES[normalized]
	var speaker_entry: Dictionary = _roster[_rng.randi_range(0, _roster.size() - 1)]
	var message := String(templates[_rng.randi_range(0, templates.size() - 1)])
	return _emit_chat_message(normalized, String(speaker_entry.display_name), message)

func _emit_chat_message(channel: String, speaker: String, message: String) -> Dictionary:
	var record := {"channel": channel, "speaker": speaker, "message": message, "time": _simulation_clock}
	_chat_history.append(record)
	while _chat_history.size() > 12:
		_chat_history.pop_front()
	simulated_chat_message.emit(channel, speaker, message)
	print("PHASE5B_SIMULATED_CHAT: channel=", channel, " speaker=", speaker, " message=", message)
	return record

func send_player_chat(message: String, channel: String = "world") -> void:
	var cleaned := message.strip_edges()
	if cleaned.is_empty():
		return
	var state := get_node_or_null("/root/GameState")
	var player_name := String(state.player_data.get("name", "Ranger")) if state != null else "Ranger"
	_emit_chat_message(channel, player_name, cleaned)

func get_recent_chat_text(max_lines: int = 4) -> String:
	var lines: Array[String] = []
	var start := maxi(0, _chat_history.size() - maxi(1, max_lines))
	for i in range(start, _chat_history.size()):
		var item: Dictionary = _chat_history[i]
		lines.append("[%s] %s: %s" % [String(item.channel), String(item.speaker), String(item.message)])
	return "\n".join(lines)

func get_population_summary() -> Dictionary:
	var counts := {"TwinCity": 0, "PhoenixCastle": 0, "ApeMountain": 0, "DesertCity": 0, "BirdIsland": 0, "Wilderness": 0}
	for entry in _roster:
		var city := String(entry.city)
		counts[city] = int(counts.get(city, 0)) + 1
	return {"total": _roster.size(), "counts": counts, "active": _active_actors.size(), "active_cap": MAX_ACTIVE_PLAYERS, "radius_m": ACTIVATION_RADIUS_M}

func make_wander_target(origin: Vector3, radius: float = 5.0) -> Vector3:
	return origin + Vector3(_rng.randf_range(-radius, radius), 0.0, _rng.randf_range(-radius, radius))

func step_towards(origin: Vector3, target: Vector3, speed: float, delta: float) -> Vector3:
	return origin.move_toward(target, maxf(0.0, speed) * maxf(0.0, delta))

func validate_phase5b_contract() -> Dictionary:
	if _roster.size() != TOTAL_PLAYERS:
		return {"ok": false, "reason": "roster_total", "total": _roster.size()}
	var summary := get_population_summary()
	var counts: Dictionary = summary.counts
	for city in CITY_COUNTS:
		if int(counts.get(city, 0)) != int(CITY_COUNTS[city]):
			return {"ok": false, "reason": "city_count_" + city, "counts": counts}
	if int(counts.get("Wilderness", 0)) != HUNTER_COUNT:
		return {"ok": false, "reason": "hunter_count"}
	if MAX_ACTIVE_PLAYERS != 30 or ACTIVATION_RADIUS_M != 55.0 or VISIBLE_HUNTERS < 3 or VISIBLE_HUNTERS > 5:
		return {"ok": false, "reason": "runtime_limits"}
	var probe := make_wander_target(Vector3.ZERO, 6.0)
	if probe.length() <= 0.01:
		return {"ok": false, "reason": "movement_target"}
	if CHAT_TEMPLATES.size() != 3 or CHAT_TEMPLATES["world"].is_empty() or CHAT_TEMPLATES["trade"].is_empty() or CHAT_TEMPLATES["team"].is_empty():
		return {"ok": false, "reason": "chat_templates"}
	return {"ok": true, "total": _roster.size(), "counts": counts, "active_cap": MAX_ACTIVE_PLAYERS, "radius_m": ACTIVATION_RADIUS_M, "visible_hunters": VISIBLE_HUNTERS, "movement_probe": probe, "chat_channels": CHAT_TEMPLATES.size()}
