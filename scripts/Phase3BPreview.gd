extends Node3D

const CharacterController = preload("res://scripts/CharacterVisualController.gd")
const ASSET_ROOT := "res://assets/phase3b/"

var captures := [
    {"file":"phase3b_01_archer_bow.png","kind":"hero","class":"archer","level":30,"plus":1},
    {"file":"phase3b_02_oriental_assassin_dual_knives.png","kind":"hero","class":"oriental_assassin","level":40,"plus":3,"shadow":true},
    {"file":"phase3b_03_dual_blades_axes.png","kind":"hero","class":"trojan","level":60,"plus":5},
    {"file":"phase3b_04_spear_halberd_greatsword_shield.png","kind":"hero","class":"warrior","level":90,"plus":7},
    {"file":"phase3b_05_mage_magic_staff.png","kind":"hero","class":"taoist","level":100,"plus":9},
    {"file":"phase3b_06_ninja_katana_shuriken_plus12.png","kind":"hero","class":"ninja","level":130,"plus":12},
    {"file":"phase3b_07_oga_dragon_daylight.png","kind":"model","asset":"oga_monsters/cethiel_dragon_dragon.glb","target_extent":2.4},
    {"file":"phase3b_08_quaternius_dragon_daylight.png","kind":"model","asset":"monsters/dragon_dragon.glb","target_extent":2.4},
    {"file":"phase3b_09_quaternius_demon_daylight.png","kind":"model","asset":"monsters/demon_demon.glb","target_extent":2.2},
    {"file":"phase3b_10_weapon_collection.png","kind":"weapons"}
]

func _ready() -> void:
    if OS.get_environment("CI_CAPTURE") == "1":
        _capture_all.call_deferred()

func _capture_all() -> void:
    var output: String = "res://artifacts/"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    var completed := 0
    for spec in captures:
        for child in get_children():
            child.queue_free()
        await get_tree().process_frame
        _build_stage()
        var camera := Camera3D.new()
        camera.fov = 40.0
        camera.near = 0.05
        camera.far = 100.0
        add_child(camera)
        camera.current = true

        var kind: String = str(spec.get("kind", "hero"))
        if kind == "hero":
            var hero = CharacterController.new()
            add_child(hero)
            hero.build_character(str(spec["class"]), int(spec["level"]))
            if not hero.assets_ready:
                _fail("PHASE3B_HERO_ASSET_OR_WEAPON_SOCKET_FAILED: " + str(spec["file"]))
                return
            await get_tree().process_frame
            if not hero.normalize_character():
                _fail("PHASE3B_HERO_NORMALIZATION_FAILED: " + str(spec["file"]))
                return
            hero.set_weapon_upgrade(int(spec.get("plus", 1)), "Super", int(spec["level"]))
            if bool(spec.get("shadow", false)):
                hero.activate_path_of_shadow(true)
            camera.position = Vector3(0.0, 1.10, 3.5)
            camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
        elif kind == "model":
            var path: String = ASSET_ROOT + str(spec["asset"])
            if not ResourceLoader.exists(path):
                _fail("PHASE3B_PREVIEW_MODEL_MISSING: " + path)
                return
            var packed := load(path) as PackedScene
            if packed == null:
                _fail("PHASE3B_PREVIEW_MODEL_NOT_PACKED_SCENE: " + path)
                return
            var model := packed.instantiate() as Node3D
            if model == null:
                _fail("PHASE3B_PREVIEW_MODEL_ROOT_INVALID: " + path)
                return
            add_child(model)
            await get_tree().process_frame
            if not _normalize_model(model, float(spec["target_extent"])):
                _fail("PHASE3B_PREVIEW_MODEL_NORMALIZATION_FAILED: " + path)
                return
            var bounds := _global_mesh_bounds(model)
            camera.position = Vector3(0.0, maxf(1.2, bounds.size.y * 0.65), 4.5)
            camera.look_at(Vector3(0.0, bounds.position.y + bounds.size.y * 0.5, 0.0), Vector3.UP)
        elif kind == "weapons":
            var names := ["bow", "dagger", "spear", "halberd", "sword"]
            var x_positions := [-1.55, -0.78, 0.0, 0.78, 1.55]
            for i in range(names.size()):
                var path: String = ASSET_ROOT + "quaternius_" + str(names[i]) + ".glb"
                if not ResourceLoader.exists(path):
                    _fail("PHASE3B_WEAPON_COLLECTION_ASSET_MISSING: " + path)
                    return
                var packed := load(path) as PackedScene
                if packed == null:
                    _fail("PHASE3B_WEAPON_COLLECTION_NOT_PACKED_SCENE: " + path)
                    return
                var model := packed.instantiate() as Node3D
                if model == null:
                    _fail("PHASE3B_WEAPON_COLLECTION_ROOT_INVALID: " + path)
                    return
                add_child(model)
                await get_tree().process_frame
                if not _normalize_model(model, 0.95):
                    _fail("PHASE3B_WEAPON_NORMALIZATION_FAILED: " + path)
                    return
                model.position.x += float(x_positions[i])
                model.position.y += 0.8
            camera.position = Vector3(0.0, 1.15, 4.8)
            camera.look_at(Vector3(0.0, 0.8, 0.0), Vector3.UP)
        else:
            _fail("PHASE3B_UNKNOWN_CAPTURE_KIND: " + kind)
            return

        await get_tree().process_frame
        await get_tree().process_frame
        var image: Image = get_viewport().get_texture().get_image()
        var filename: String = str(spec["file"])
        if image == null or image.is_empty():
            _fail("PHASE3B_CAPTURE_EMPTY_VIEWPORT: " + filename)
            return
        var full_path: String = output.path_join(filename)
        var save_error: Error = image.save_png(full_path)
        if save_error != OK:
            _fail("PHASE3B_CAPTURE_SAVE_FAILED: " + filename + " error=" + str(save_error))
            return
        var saved := FileAccess.get_file_as_bytes(full_path)
        if saved.size() < 15000:
            _fail("PHASE3B_CAPTURE_TOO_SMALL: " + filename + " bytes=" + str(saved.size()))
            return
        completed += 1
        print("PHASE3B_CAPTURE_OK: ", filename, " bytes=", saved.size(), " size=", image.get_width(), "x", image.get_height())
    if completed != captures.size():
        _fail("PHASE3B_CAPTURE_COUNT_MISMATCH: " + str(completed) + "/" + str(captures.size()))
        return
    print("PHASE3B_ALL_TEN_CAPTURES_COMPLETE")
    get_tree().quit(0)

func _normalize_model(root: Node3D, target_extent: float) -> bool:
    var bounds := _global_mesh_bounds(root)
    var extent: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
    if extent <= 0.001:
        return false
    root.scale = Vector3.ONE * (target_extent / extent)
    bounds = _global_mesh_bounds(root)
    root.global_position.x -= bounds.position.x + bounds.size.x * 0.5
    root.global_position.y -= bounds.position.y
    root.global_position.z -= bounds.position.z + bounds.size.z * 0.5
    return true

func _global_mesh_bounds(root: Node) -> AABB:
    var result := AABB()
    var found := false
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            var mesh_instance := node as MeshInstance3D
            if mesh_instance.mesh != null:
                var box: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
                if not found:
                    result = box
                    found = true
                else:
                    result = result.merge(box)
        for child in node.get_children():
            stack.append(child)
    return result if found else AABB()

func _fail(message: String) -> void:
    push_error(message)
    get_tree().quit(2)

func _build_stage() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.60, 0.72, 0.84)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(1.0, 0.97, 0.90)
    env.ambient_light_energy = 1.15
    env.glow_enabled = true
    env.glow_intensity = 0.35
    env.glow_bloom = 0.08
    world.environment = env
    add_child(world)

    var floor := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(16.0, 16.0)
    floor.mesh = plane
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.72, 0.70, 0.64)
    floor_material.roughness = 0.9
    floor.material_override = floor_material
    add_child(floor)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
    sun.light_color = Color(1.0, 0.96, 0.86)
    sun.light_energy = 2.0
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-22.0, 145.0, 0.0)
    fill.light_color = Color(0.78, 0.86, 1.0)
    fill.light_energy = 0.75
    add_child(fill)
