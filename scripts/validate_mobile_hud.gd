extends SceneTree

const MOBILE_HUD_SCRIPT = preload("res://scripts/MobileHUD.gd")
const GAME_SETTINGS_SCRIPT = preload("res://scripts/GameSettings.gd")
const HERO_CONTROLLER_SCRIPT = preload("res://scripts/HeroController.gd")
const MONSTER_ACTOR_SCRIPT = preload("res://scripts/MonsterActor.gd")
const COMBAT_SYSTEM_SCRIPT = preload("res://scripts/CombatSystem.gd")
const LOOT_DROP_MANAGER_SCRIPT = preload("res://autoloads/LootDropManager.gd")

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run_functional_tests")

func _check(condition: bool, label: String) -> void:
    if condition:
        print("SETTINGS_TEST_OK: ", label)
    else:
        failures.append(label)
        push_error("SETTINGS_TEST_FAILED: " + label)

func _run_functional_tests() -> void:
    var scripts := [MOBILE_HUD_SCRIPT, GAME_SETTINGS_SCRIPT, HERO_CONTROLLER_SCRIPT, MONSTER_ACTOR_SCRIPT, COMBAT_SYSTEM_SCRIPT, LOOT_DROP_MANAGER_SCRIPT]
    for script in scripts:
        _check(script != null, "required script preload")
    if not failures.is_empty():
        quit(1)
        return
    print("PHASE5A_MOBILE_HUD_PARSE_OK")

    var scene_error := change_scene_to_file("res://scenes/TwinCity.tscn")
    _check(scene_error == OK, "load TwinCity test scene")
    for frame in range(4):
        await process_frame

    var settings = root.get_node_or_null("GameSettings")
    var state = root.get_node_or_null("GameState")
    var world_map = root.get_node_or_null("WorldMapManager")
    var loot = root.get_node_or_null("LootDropManager")
    _check(settings != null and state != null and world_map != null and loot != null, "required autoloads available")
    if settings == null or state == null or world_map == null or loot == null:
        quit(1)
        return

    # Wait for the actual scene HeroController; the loot test must not use a fake player.
    var gameplay_hero: Node3D = null
    for frame in range(600):
        var candidate: Node = root.find_child("PlayableHero", true, false)
        if candidate == null:
            candidate = root.find_child("HeroController", true, false)
        if candidate is Node3D and candidate.get_script() == HERO_CONTROLLER_SCRIPT:
            gameplay_hero = candidate as Node3D
            if gameplay_hero.get("camera_pivot") is Node3D:
                break
        await process_frame
    _check(gameplay_hero != null and gameplay_hero.get("camera_pivot") is Node3D, "live TwinCity HeroController initialized")
    if gameplay_hero == null:
        quit(1)
        return

    settings.set_process(false)
    var original_settings: Dictionary = settings._values.duplicate(true)
    var original_player_data: Dictionary = state.player_data.duplicate(true)
    var original_inventory_slots: Array = state.inventory_slots.duplicate(true)
    var original_inventory: Dictionary = state.inventory.duplicate(true)
    # Isolate inventory probes so a full player inventory cannot make the test flaky.
    state.inventory_slots.clear()
    state.inventory.clear()
    state.player_data["inventory_slots"] = []
    state.player_data["inventory"] = {}
    # AudioServer: assert both bus dB and mute state after real setting changes.
    settings.set_setting("music_volume", 30.0)
    settings.set_setting("music_muted", true)
    settings.set_setting("sfx_volume", 60.0)
    settings.set_setting("sfx_muted", true)
    var music_bus := AudioServer.get_bus_index("Music")
    var sfx_bus := AudioServer.get_bus_index("SFX")
    _check(music_bus >= 0 and AudioServer.is_bus_mute(music_bus) and absf(AudioServer.get_bus_volume_db(music_bus) - linear_to_db(0.3)) < 0.2, "Music AudioServer volume and mute")
    _check(sfx_bus >= 0 and AudioServer.is_bus_mute(sfx_bus) and absf(AudioServer.get_bus_volume_db(sfx_bus) - linear_to_db(0.6)) < 0.2, "SFX AudioServer volume and mute")

    # Add real Godot nodes so the settings system applies to their live properties.
    var test_root := current_scene
    var world_environment := WorldEnvironment.new()
    world_environment.name = "SettingsFunctionalWorldEnvironment"
    world_environment.environment = Environment.new()
    test_root.add_child(world_environment)
    var light := DirectionalLight3D.new()
    light.name = "SettingsFunctionalDirectionalLight"
    test_root.add_child(light)
    settings.set_setting("graphics_quality", 0)
    _check(not world_environment.environment.glow_enabled and not light.shadow_enabled, "low graphics disables glow and shadows")
    settings.set_setting("graphics_quality", 1)
    _check(not world_environment.environment.glow_enabled and light.shadow_enabled, "medium graphics enables shadows only")
    settings.set_setting("graphics_quality", 2)
    _check(world_environment.environment.glow_enabled and light.shadow_enabled, "ultra graphics enables glow and shadows")

    var name_label := Label3D.new()
    name_label.name = "NPCName"
    test_root.add_child(name_label)
    var damage_label := Label3D.new()
    damage_label.name = "FloatingDamageFunctional"
    test_root.add_child(damage_label)
    var hp_bar := MeshInstance3D.new()
    hp_bar.name = "HPBarFunctional"
    hp_bar.mesh = BoxMesh.new()
    test_root.add_child(hp_bar)
    var simulated := Node3D.new()
    simulated.name = "FunctionalSimulatedPlayer"
    simulated.add_to_group("simulated_players")
    var simulated_mesh := MeshInstance3D.new()
    simulated_mesh.mesh = BoxMesh.new()
    simulated.add_child(simulated_mesh)
    test_root.add_child(simulated)
    settings.set_setting("show_names", false)
    settings.set_setting("show_damage_numbers", false)
    settings.set_setting("show_hp_bars", false)
    settings.set_setting("hide_simulated_players", true)
    _check(not name_label.visible, "name labels hidden")
    _check(not damage_label.visible, "damage numbers hidden")
    _check(not hp_bar.visible, "HP bars hidden")
    _check(simulated.process_mode == Node.PROCESS_MODE_DISABLED and not simulated_mesh.visible, "simulated players hidden and processing disabled")

    # Auto-loot uses the actual spawned HeroController and an actual drop at the exact same world position.
    var drop_node := Node3D.new()
    drop_node.name = "SettingsFunctionalGroundDrop"
    test_root.add_child(drop_node)
    drop_node.global_position = gameplay_hero.global_position
    var before_probe := int(state.get_item_count("HPPotion"))
    loot._drops["settings_functional_probe"] = {
        "node": drop_node,
        "data": {"item_id": "HPPotion", "item_type": "Potions", "amount": 1},
        "remaining": 30.0
    }
    settings.set_setting("auto_loot", false)
    loot._process(0.01)
    _check(int(state.get_item_count("HPPotion")) == before_probe and loot._drops.has("settings_functional_probe"), "auto-loot disabled prevents pickup")
    settings.set_setting("auto_loot", true)
    for frame in range(8):
        await physics_frame
    # Run the same manager process path once after the physics-frame settling window.
    loot._process(0.01)
    var probe_collected := int(state.get_item_count("HPPotion")) == before_probe + 1 and not loot._drops.has("settings_functional_probe")
    _check(probe_collected, "auto-loot enabled collects exact-position ground drop after physics frames")
    if probe_collected:
        state.remove_item("HPPotion", 1)
    # Consume actual inventory items through GameState, verify HP and MP changes, then restore save data.
    state.player_data["max_hp"] = 100
    state.player_data["hp"] = 40
    state.player_data["max_mana"] = 100
    state.player_data["mana"] = 35
    var hp_added: bool = bool(state.add_item("HPPotion", 1))
    var hp_before := int(state.get_item_count("HPPotion"))
    settings._try_auto_potion()
    _check(hp_added and int(state.player_data.get("hp", 0)) == 100 and int(state.get_item_count("HPPotion")) == hp_before - 1, "auto-potion consumes HP potion and restores HP")
    var mp_added: bool = bool(state.add_item("MPPotion", 1))
    var mp_before := int(state.get_item_count("MPPotion"))
    settings._try_auto_potion()
    _check(mp_added and int(state.player_data.get("mana", 0)) == 100 and int(state.get_item_count("MPPotion")) == mp_before - 1, "auto-potion consumes MP potion and restores MP")

    # Save, reload into a fresh script instance, and compare persisted values.
    settings.set_setting("camera_sensitivity", 1.7)
    settings.set_setting("music_volume", 42.0)
    _check(settings.save_settings(), "settings config saved")
    var reloaded = GAME_SETTINGS_SCRIPT.new()
    reloaded._load_settings()
    _check(absf(float(reloaded.get_setting("camera_sensitivity")) - 1.7) < 0.001 and absf(float(reloaded.get_setting("music_volume")) - 42.0) < 0.001, "settings config reload preserves values")
    reloaded.free()

    # Restore the user's save/settings and clean up temporary test nodes before the scene reload.
    state.player_data = original_player_data
    state.inventory_slots = original_inventory_slots
    state.inventory = original_inventory
    state.save_game()
    for key in original_settings:
        settings._values[key] = original_settings[key]
    settings.save_settings()
    settings.apply_audio_settings()
    settings.apply_world_settings()
    loot._drops.erase("settings_functional_probe")
    await process_frame
    if is_instance_valid(test_root):
        if is_instance_valid(drop_node) and drop_node.get_parent() == test_root and not drop_node.is_queued_for_deletion():
            test_root.remove_child(drop_node)
            drop_node.free()
        for node in [world_environment, light, name_label, damage_label, hp_bar, simulated]:
            if is_instance_valid(node):
                test_root.remove_child(node)
                node.free()

    # The method must await the actual scene transition, not just set current_city.
    var unstuck_ok: bool = await settings.unstuck_to_twin_city()
    var final_scene := current_scene
    _check(unstuck_ok and String(world_map.current_city) == "TwinCity" and not bool(world_map.transition_in_progress) and final_scene != null and String(final_scene.scene_file_path).ends_with("TwinCity.tscn"), "unstuck performs completed TwinCity scene transition")

    settings.set_setting("camera_sensitivity", 2.0)
    var hero_controller: Node = null
    var active_camera: Camera3D = null
    for frame in range(600):
        var candidate: Node = root.find_child("PlayableHero", true, false)
        if candidate == null:
            candidate = root.find_child("HeroController", true, false)
        if candidate == null:
            candidate = get_first_node_in_group("player")
        if candidate != null and candidate.get_script() != HERO_CONTROLLER_SCRIPT:
            var nested_hero := candidate.find_child("HeroController", true, false)
            if nested_hero != null:
                candidate = nested_hero
        if candidate != null and candidate.get_script() == HERO_CONTROLLER_SCRIPT:
            hero_controller = candidate
            active_camera = hero_controller.get_viewport().get_camera_3d()
            if active_camera != null and active_camera.current and hero_controller.get("camera_pivot") is Node3D:
                break
        await process_frame
    var camera_ready := hero_controller != null and active_camera != null and active_camera.current and active_camera == hero_controller.get("camera")
    _check(camera_ready, "active Viewport Camera3D belongs to dynamically discovered HeroController")
    if camera_ready and hero_controller.has_method("_rotate_camera"):
        var pivot: Node3D = hero_controller.get("camera_pivot")
        var original_yaw := pivot.rotation_degrees.y
        hero_controller.call("_rotate_camera", Vector2(10.0, 0.0))
        _check(absf((pivot.rotation_degrees.y - original_yaw) + 3.2) < 0.05, "live HeroController camera rotation uses configured sensitivity")
        pivot.rotation_degrees.y = original_yaw
    else:
        _check(false, "HeroController camera sensitivity method and active camera are available")
    settings.set_setting("camera_sensitivity", float(original_settings.get("camera_sensitivity", 1.0)))

    if failures.is_empty():
        print("SETTINGS_FUNCTIONAL_TEST_PASS=true")
        quit(0)
    else:
        print("SETTINGS_FUNCTIONAL_TEST_PASS=false failures=", failures.size(), " details=", failures)
        quit(1)
