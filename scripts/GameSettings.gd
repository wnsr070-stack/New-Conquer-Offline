extends Node
## Persistent, offline-first settings shared by the HUD and gameplay systems.
const SETTINGS_PATH := "user://game_settings.cfg"
const DEFAULTS := {
    "music_volume": 75.0,
    "music_muted": false,
    "sfx_volume": 85.0,
    "sfx_muted": false,
    "graphics_quality": 1,
    "show_names": true,
    "show_damage_numbers": true,
    "show_hp_bars": true,
    "hide_simulated_players": false,
    "camera_sensitivity": 1.0,
    "auto_loot": true,
    "auto_potion": true
}

var _values: Dictionary = {}
var _auto_potion_clock := 0.0

func _ready() -> void:
    _load_settings()
    _ensure_audio_bus("Music")
    _ensure_audio_bus("SFX")
    apply_audio_settings()
    if not get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.connect(_on_node_added)
    apply_world_settings()
    set_process(true)
    print("GAME_SETTINGS_READY: path=", SETTINGS_PATH, " keys=", _values.size(), " offline=true")

func _process(delta: float) -> void:
    if not bool(get_setting("auto_potion", true)):
        return
    _auto_potion_clock += delta
    if _auto_potion_clock < 0.45:
        return
    _auto_potion_clock = 0.0
    _try_auto_potion()

func get_setting(key: String, fallback: Variant = null) -> Variant:
    return _values.get(key, fallback)

func set_setting(key: String, value: Variant) -> void:
    if not _values.has(key):
        push_warning("GAME_SETTINGS_UNKNOWN_KEY: " + key)
        return
    match key:
        "music_volume", "sfx_volume":
            value = clampf(float(value), 0.0, 100.0)
        "camera_sensitivity":
            value = clampf(float(value), 0.2, 3.0)
        "graphics_quality":
            value = clampi(int(value), 0, 2)
        _:
            value = bool(value)
    _values[key] = value
    save_settings()
    if key in ["music_volume", "music_muted", "sfx_volume", "sfx_muted"]:
        apply_audio_settings()
    elif key == "graphics_quality" or key in ["show_names", "show_damage_numbers", "show_hp_bars", "hide_simulated_players"]:
        apply_world_settings()
    print("GAME_SETTING_CHANGED: ", key, "=", value)

func save_settings() -> bool:
    var config := ConfigFile.new()
    for key in _values:
        config.set_value("settings", String(key), _values[key])
    var error := config.save(SETTINGS_PATH)
    if error != OK:
        push_error("GAME_SETTINGS_SAVE_FAILED: error=" + str(error))
        return false
    return true

func _load_settings() -> void:
    var config := ConfigFile.new()
    var load_error := config.load(SETTINGS_PATH)
    _values.clear()
    for key in DEFAULTS:
        var default_value: Variant = DEFAULTS[key]
        _values[key] = config.get_value("settings", String(key), default_value) if load_error == OK else default_value
    _values["music_volume"] = clampf(float(_values["music_volume"]), 0.0, 100.0)
    _values["sfx_volume"] = clampf(float(_values["sfx_volume"]), 0.0, 100.0)
    _values["camera_sensitivity"] = clampf(float(_values["camera_sensitivity"]), 0.2, 3.0)
    _values["graphics_quality"] = clampi(int(_values["graphics_quality"]), 0, 2)

func _ensure_audio_bus(bus_name: String) -> int:
    var index := AudioServer.get_bus_index(bus_name)
    if index >= 0:
        return index
    AudioServer.add_bus()
    index = AudioServer.bus_count - 1
    AudioServer.set_bus_name(index, bus_name)
    AudioServer.set_bus_send(index, "Master")
    return index

func apply_audio_settings() -> void:
    _ensure_audio_bus("Music")
    _ensure_audio_bus("SFX")
    _apply_audio_bus("Music", float(get_setting("music_volume", 75.0)), bool(get_setting("music_muted", false)))
    _apply_audio_bus("SFX", float(get_setting("sfx_volume", 85.0)), bool(get_setting("sfx_muted", false)))
    _route_existing_audio_nodes(get_tree().root)

func _apply_audio_bus(bus_name: String, volume_percent: float, muted: bool) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    if index < 0:
        return
    var linear := clampf(volume_percent / 100.0, 0.0, 1.0)
    AudioServer.set_bus_volume_db(index, -80.0 if linear <= 0.0001 else linear_to_db(linear))
    AudioServer.set_bus_mute(index, muted)

func _route_existing_audio_nodes(parent: Node) -> void:
    for child in parent.get_children():
        _route_audio_node(child)
        _route_existing_audio_nodes(child)

func _route_audio_node(node: Node) -> void:
    if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
        return
    var player := node as Node
    if String(player.get("bus")) != "Master":
        return
    var lower := String(node.name).to_lower()
    if lower.contains("music") or lower.contains("bgm") or lower.contains("background"):
        player.set("bus", "Music")
    elif lower.contains("sfx") or lower.contains("effect") or lower.contains("sound"):
        player.set("bus", "SFX")

func _on_node_added(node: Node) -> void:
    if node == null or not is_instance_valid(node):
        return
    var instance_id: int = node.get_instance_id()
    call_deferred("_apply_node_settings_by_id", instance_id)
    call_deferred("_route_audio_node_by_id", instance_id)

func _apply_node_settings_by_id(instance_id: int) -> void:
    var node := instance_from_id(instance_id) as Node
    if node == null:
        return
    _apply_node_settings(node)

func _route_audio_node_by_id(instance_id: int) -> void:
    var node := instance_from_id(instance_id) as Node
    if node == null:
        return
    _route_audio_node(node)

func apply_world_settings() -> void:
    if not is_inside_tree():
        return
    _apply_recursive(get_tree().root)

func _apply_recursive(node: Node) -> void:
    _apply_node_settings(node)
    for child in node.get_children():
        _apply_recursive(child)

func _apply_node_settings(node: Node) -> void:
    if not is_instance_valid(node):
        return
    var quality := int(get_setting("graphics_quality", 1))
    var is_ci_capture := OS.get_environment("CI_CAPTURE") == "1" and OS.get_environment("SETTINGS_FUNCTIONAL_TEST") != "1"
    if node is WorldEnvironment:
        var world_environment := node as WorldEnvironment
        if world_environment.environment != null:
            world_environment.environment.glow_enabled = quality >= 2 and not is_ci_capture
    elif node is DirectionalLight3D:
        (node as DirectionalLight3D).shadow_enabled = quality >= 1 and not is_ci_capture

    if node is Label3D:
        var label := node as Label3D
        var label_name := String(label.name).to_lower()
        var is_name := label_name in ["npcname", "monsternameplate", "playernameplate"] or String(label.get_meta("game_settings_role", "")) == "name"
        var is_damage := label_name.begins_with("floatingdamage") or String(label.get_meta("game_settings_role", "")) == "damage"
        if is_name:
            _set_visual_visibility(label, bool(get_setting("show_names", true)))
        elif is_damage:
            _set_visual_visibility(label, bool(get_setting("show_damage_numbers", true)))

    var lower_name := String(node.name).to_lower()
    var is_hp_bar := lower_name.contains("hpbar") or lower_name.contains("healthbar") or lower_name.contains("health_bar") or String(node.get_meta("game_settings_role", "")) == "hp_bar"
    if is_hp_bar and (node is VisualInstance3D or node is CanvasItem):
        _set_visual_visibility(node, bool(get_setting("show_hp_bars", true)))

    if node is Node3D:
        var is_simulated := (node as Node3D).is_in_group("simulated_players") or lower_name.contains("simulatedplayer") or bool(node.get_meta("simulated_player", false))
        if is_simulated:
            var simulated := node as Node3D
            if not simulated.has_meta("game_settings_original_process_mode"):
                simulated.set_meta("game_settings_original_process_mode", int(simulated.process_mode))
            simulated.process_mode = Node.PROCESS_MODE_DISABLED if bool(get_setting("hide_simulated_players", false)) else int(simulated.get_meta("game_settings_original_process_mode"))
            for visual in simulated.find_children("*", "VisualInstance3D", true, false):
                _set_visual_visibility(visual, not bool(get_setting("hide_simulated_players", false)))

func _set_visual_visibility(node: Node, enabled: bool) -> void:
    if not (node is VisualInstance3D or node is CanvasItem):
        return
    if not node.has_meta("game_settings_original_visible"):
        node.set_meta("game_settings_original_visible", bool(node.get("visible")))
    node.set("visible", bool(node.get_meta("game_settings_original_visible")) and enabled)

func _try_auto_potion() -> void:
    var state := get_node_or_null("/root/GameState")
    if state == null:
        return
    var data: Dictionary = state.player_data
    var hp := int(data.get("hp", data.get("max_hp", 100)))
    var max_hp := maxi(1, int(data.get("max_hp", 100)))
    if float(hp) / float(max_hp) < 0.5 and _consume_first_potion(state, ["HPPotion", "HealthPotion", "Panacea"]):
        data["hp"] = mini(max_hp, hp + 250)
        state.save_game()
        print("GAME_SETTINGS_AUTO_HP_POTION_USED: hp=", data["hp"], "/", max_hp)
        return
    var mp := int(data.get("mana", data.get("max_mana", 100)))
    var max_mp := maxi(1, int(data.get("max_mana", 100)))
    if float(mp) / float(max_mp) < 0.5 and _consume_first_potion(state, ["MPPotion", "ManaPotion", "MPPOTION", "Panacea"]):
        data["mana"] = mini(max_mp, mp + 250)
        state.save_game()
        print("GAME_SETTINGS_AUTO_MP_POTION_USED: mana=", data["mana"], "/", max_mp)

func _consume_first_potion(state: Node, item_ids: Array[String]) -> bool:
    for item_id in item_ids:
        if state.has_method("get_item_count") and int(state.get_item_count(item_id)) > 0 and state.has_method("remove_item"):
            if bool(state.remove_item(item_id, 1)):
                return true
    return false


## Return only after the WorldMapManager has completed a real Twin City scene transition.
func unstuck_to_twin_city() -> bool:
    var world_map := get_node_or_null("/root/WorldMapManager")
    if world_map == null or not world_map.has_method("travel_to_city"):
        push_error("GAME_SETTINGS_UNSTUCK_FAILED: WorldMapManager unavailable")
        return false
    world_map.travel_to_city("TwinCity", Vector3(0.0, -1.35, 0.0))
    for frame in range(180):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if String(world_map.current_city) == "TwinCity" and not bool(world_map.transition_in_progress) and scene != null and String(scene.scene_file_path).ends_with("TwinCity.tscn"):
            print("GAME_SETTINGS_UNSTUCK_TWIN_CITY_OK: scene=", scene.scene_file_path)
            return true
    push_error("GAME_SETTINGS_UNSTUCK_TIMEOUT: city=" + String(world_map.current_city))
    return false
