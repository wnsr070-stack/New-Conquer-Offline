extends Node3D
class_name MonsterActor

signal respawned(actor: MonsterActor)

const NORMAL_MIN_HEIGHT := 1.6
const NORMAL_MAX_HEIGHT := 2.2
const KING_SCALE := 1.3
const BOSS_SCALE := 2.2

var definition: Dictionary = {}
var is_king := false
var is_boss := false
var current_hp := 1
var max_hp := 1
var rest_secs := 5.0
var camp_center := Vector3.ZERO
var camp_half_extent := Vector2(20.0, 20.0)
var ground_y := 0.0
var move_speed := 1.6
var animation_mode := "procedural"
var embedded_idle_clip := ""
var embedded_walk_clip := ""

var _target := Vector3.ZERO
var _dead := false
var _model: Node3D
var _animation_player: AnimationPlayer
var _respawn_timer: Timer
var _nameplate: Label3D
var _rng := RandomNumberGenerator.new()
var _procedural_clock := 0.0
var _model_rest_position := Vector3.ZERO
var _model_rest_scale := Vector3.ONE
var _model_height := 1.8

func configure(data: Dictionary, model_path: String, king: bool, boss: bool, center: Vector3) -> bool:
	definition = data.duplicate(true)
	is_king = king
	is_boss = boss
	camp_center = center
	ground_y = center.y
	max_hp = int(definition.get("hp", 1))
	current_hp = max_hp
	rest_secs = maxf(0.1, float(definition.get("rest_secs", 5.0)))
	_rng.randomize()

	if not ResourceLoader.exists(model_path):
		push_error("MonsterActor: Phase 3B GLB missing: " + model_path)
		return false
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_error("MonsterActor: GLB PackedScene failed: " + model_path)
		return false
	_model = packed.instantiate() as Node3D
	if _model == null:
		push_error("MonsterActor: GLB root is not Node3D: " + model_path)
		return false
	add_child(_model)

	_model_height = _target_height(String(definition.get("id", "")))
	if is_king:
		_model_height *= KING_SCALE
	elif is_boss:
		_model_height *= BOSS_SCALE
	var fit_factor := AssetLoader.fit_height(_model, _model_height)
	if fit_factor <= 0.0:
		push_error("MonsterActor: could not normalize model height: " + model_path)
		return false
	_model_rest_position = _model.position
	_model_rest_scale = _model.scale

	_animation_player = _find_animation_player(_model)
	if _animation_player != null:
		embedded_idle_clip = _find_clip(["idle", "animation_idle"])
		embedded_walk_clip = _find_clip(["walk", "walking", "animation_walk"])
	if _animation_player != null and not embedded_idle_clip.is_empty() and not embedded_walk_clip.is_empty():
		animation_mode = "embedded"
		_animation_player.play(embedded_idle_clip)
	else:
		animation_mode = "procedural"
		if _animation_player != null:
			_animation_player.stop()

	_build_nameplate()
	_respawn_timer = Timer.new()
	_respawn_timer.name = "AutoRespawn"
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_on_respawn_timeout)
	add_child(_respawn_timer)
	_target = _random_camp_point()
	global_position = camp_center
	_play_idle()
	return true

func _target_height(monster_id: String) -> float:
	var normal_ids := ["Chicken", "Pigeon", "Birb", "Ghost", "Blob", "Bunny", "Dog", "Frog", "Orc", "Yeti", "Cactoro", "Dino", "Armabee", "Demon", "Alien"]
	var index := normal_ids.find(monster_id)
	if index >= 0:
		return lerpf(NORMAL_MIN_HEIGHT, NORMAL_MAX_HEIGHT, float(index) / float(normal_ids.size() - 1))
	return 2.0

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_clip(aliases: Array[String]) -> String:
	if _animation_player == null:
		return ""
	for clip in _animation_player.get_animation_list():
		var clip_name := String(clip).get_slice("/", String(clip).get_slice_count("/") - 1)
		var normalized := clip_name.to_lower().replace("_", "").replace("-", "").replace(" ", "")
		for alias in aliases:
			var wanted := alias.to_lower().replace("_", "").replace("-", "").replace(" ", "")
			if normalized == wanted:
				return String(clip)
	return ""

func has_idle_walk() -> bool:
	return animation_mode == "embedded" or animation_mode == "procedural"

func _build_nameplate() -> void:
	_nameplate = Label3D.new()
	var level := int(definition.get("level", 1))
	var display_name := String(definition.get("id", "Monster"))
	if is_king:
		display_name = "King " + display_name
	_nameplate.text = "[Lv.%d] %s" % [level, display_name]
	_nameplate.font_size = 48
	_nameplate.pixel_size = 0.004
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = true
	_nameplate.outline_size = 8
	_nameplate.outline_modulate = Color(0.04, 0.035, 0.025, 1.0)
	if is_boss:
		_nameplate.modulate = Color(1.0, 0.72, 0.12, 1.0)
	elif is_king:
		_nameplate.modulate = Color(1.0, 0.9, 0.12, 1.0)
	else:
		_nameplate.modulate = Color.WHITE
	_nameplate.position.y = _model_height + 0.18
	add_child(_nameplate)

func _process(delta: float) -> void:
	if _dead or _model == null:
		return
	_procedural_clock += delta
	var offset := Vector3(_target.x - global_position.x, 0.0, _target.z - global_position.z)
	if offset.length() > 0.18:
		var step := minf(move_speed * delta, offset.length())
		global_position += offset.normalized() * step
		global_position.y = ground_y
		look_at(global_position + Vector3(offset.x, 0.0, offset.z), Vector3.UP)
		_play_walk()
	else:
		_play_idle()
		if _rng.randf() < delta * 0.35:
			_target = _random_camp_point()
	if animation_mode == "procedural":
		_apply_procedural_motion()

func _apply_procedural_motion() -> void:
	if _model == null:
		return
	var bob := 0.0
	var breath := 0.0
	if _animation_player != null:
		# A GLB with incomplete clips still uses the same gentle procedural fallback.
		_animation_player.stop()
	if _target.distance_to(global_position) > 0.18:
		bob = absf(sin(_procedural_clock * 8.0)) * 0.095
	_model.position = _model_rest_position + Vector3(0.0, bob + sin(_procedural_clock * 2.1) * 0.012, 0.0)
	breath = 1.0 + sin(_procedural_clock * 2.1) * 0.012
	_model.scale = Vector3(_model_rest_scale.x, _model_rest_scale.y * breath, _model_rest_scale.z)

func _random_camp_point() -> Vector3:
	return Vector3(
		camp_center.x + _rng.randf_range(-camp_half_extent.x, camp_half_extent.x),
		ground_y,
		camp_center.z + _rng.randf_range(-camp_half_extent.y, camp_half_extent.y)
	)

func _play_idle() -> void:
	if animation_mode == "embedded" and _animation_player != null and _animation_player.current_animation != embedded_idle_clip:
		_animation_player.play(embedded_idle_clip)

func _play_walk() -> void:
	if animation_mode == "embedded" and _animation_player != null and _animation_player.current_animation != embedded_walk_clip:
		_animation_player.play(embedded_walk_clip)

func die() -> void:
	if _dead:
		return
	_dead = true
	current_hp = 0
	if _animation_player != null:
		_animation_player.stop()
	if _nameplate != null:
		_nameplate.visible = false
	if _model != null:
		_model.visible = false
	if _respawn_timer != null:
		_respawn_timer.start(rest_secs)

func _on_respawn_timeout() -> void:
	if not _dead:
		return
	_dead = false
	current_hp = max_hp
	_target = _random_camp_point()
	global_position = camp_center
	if _model != null:
		_model.visible = true
		_model.position = _model_rest_position
		_model.scale = _model_rest_scale
	if _nameplate != null:
		_nameplate.visible = true
	_play_idle()
	respawned.emit(self)

func is_dead() -> bool:
	return _dead

func get_model_height() -> float:
	return _model_height

func get_model_ground_offset() -> float:
	if _model == null:
		return INF
	return AssetLoader._measure_bounds(_model, Transform3D.IDENTITY).position.y

func get_nameplate() -> Label3D:
	return _nameplate
