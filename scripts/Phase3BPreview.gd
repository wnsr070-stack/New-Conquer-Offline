extends Node3D

const CharacterController = preload("res://scripts/CharacterVisualController.gd")
const ASSET_ROOT := "res://assets/phase3b/"

var captures := [
    {"file":"phase3b_01_archer_bow.png","kind":"hero","class":"archer","label":"ARCHER","level":30,"plus":1},
    {"file":"phase3b_02_oriental_assassin_dual_knives.png","kind":"hero","class":"oriental_assassin","label":"ORIENTAL ASSASSIN","level":40,"plus":3,"shadow":true},
    {"file":"phase3b_03_dual_blades_axes.png","kind":"hero","class":"trojan","label":"TROJAN","level":60,"plus":5},
    {"file":"phase3b_04_spear_halberd_greatsword_shield.png","kind":"hero","class":"warrior","label":"WARRIOR","level":90,"plus":7},
    {"file":"phase3b_05_mage_magic_staff.png","kind":"hero","class":"taoist","label":"TAOIST","level":100,"plus":9},
    {"file":"phase3b_06_ninja_katana_shuriken_plus12.png","kind":"hero","class":"ninja","label":"NINJA — KATANA + SHURIKEN","level":130,"plus":12},
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
    var capture_specs: Array = captures.duplicate(true)
    var manifest_path := ASSET_ROOT + "phase3b_manifest.json"
    if not FileAccess.file_exists(manifest_path):
        _fail("PHASE3B_CATALOG_MANIFEST_MISSING: " + manifest_path)
        return
    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    if typeof(manifest) != TYPE_DICTIONARY or not manifest.has("assets"):
        _fail("PHASE3B_CATALOG_MANIFEST_INVALID")
        return
    var creature_index := 0
    for record in manifest["assets"]:
        var category := str(record.get("category", ""))
        if category == "normal_mob" or category == "boss":
            creature_index += 1
            var creature_id := str(record.get("id", "creature_" + str(creature_index)))
            capture_specs.append({
                "file": "phase3b_catalog_%02d_%s.png" % [creature_index, creature_id],
                "kind": "model",
                "asset": str(record.get("file", "")),
                "target_extent": 2.25,
                "label": str(record.get("name", creature_id))
            })
    if creature_index != 20:
        _fail("PHASE3B_CREATURE_CATALOG_COUNT_MISMATCH: " + str(creature_index) + "/20")
        return
    for spec in capture_specs:
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
            if str(spec.get("asset", "")).begins_with("oga_monsters/"):
                camera.position = Vector3(0.0, 2.1, 4.8)
                camera.look_at(Vector3(0.0, 1.3, 0.0), Vector3.UP)
            else:
                camera.position = Vector3(0.0, maxf(1.2, bounds.size.y * 0.65), 4.5)
                camera.look_at(Vector3(0.0, bounds.position.y + bounds.size.y * 0.5, 0.0), Vector3.UP)
        elif kind == "weapons":
            # Nine real Phase 3B assets, arranged on a consistent 0.6 m grid.
            var weapon_paths := [
                "quaternius_sword.glb",
                "quaternius_axe.glb",
                "quaternius_spear.glb",
                "quaternius_library/katana_katana.glb",
                "quaternius_bow.glb",
                "quaternius_staff.glb",
                "quaternius_dagger.glb",
                "quaternius_shuriken.glb",
                "quaternius_shield.glb"
            ]
            for i in range(weapon_paths.size()):
                var path: String = ASSET_ROOT + str(weapon_paths[i])
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
                if not _normalize_model(model, 1.1):
                    _fail("PHASE3B_WEAPON_NORMALIZATION_FAILED: " + path)
                    return
                model.rotation_degrees.y = 35.0
                model.position.x = -2.4 + float(i) * 0.6
                model.position.y = 0.9
            camera.fov = 42.0
            camera.position = Vector3(0.0, 1.2, 4.8)
            camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
        else:
            _fail("PHASE3B_UNKNOWN_CAPTURE_KIND: " + kind)
            return

        var overlay := CanvasLayer.new()
        overlay.layer = 10
        add_child(overlay)
        var title := Label.new()
        title.text = str(spec.get("label", str(spec.get("asset", spec.get("class", "PHASE 3B"))).to_upper()))
        title.position = Vector2(24.0, 18.0)
        title.add_theme_font_size_override("font_size", 28)
        title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 1.0))
        title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
        title.add_theme_constant_override("shadow_offset_x", 2)
        title.add_theme_constant_override("shadow_offset_y", 2)
        overlay.add_child(title)
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
    if completed != capture_specs.size():
        _fail("PHASE3B_CAPTURE_COUNT_MISMATCH: " + str(completed) + "/" + str(capture_specs.size()))
        return
    print("PHASE3B_ALL_CATALOG_CAPTURES_COMPLETE: ", completed)
    get_tree().quit(0)

func _normalize_model(root: Node3D, target_extent: float) -> bool:
    # Combined world-space AABB across every mesh, independent of source units.
    var bounds := _global_mesh_bounds(root)
    var extent: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
    if extent <= 0.001:
        return false
    root.scale = Vector3.ONE * (target_extent / extent)
    bounds = _global_mesh_bounds(root)
    root.global_position.x -= bounds.position.x + bounds.size.x * 0.5
    root.global_position.y -= bounds.position.y
    root.global_position.z -= bounds.position.z + bounds.size.z * 0.5
    # Repair missing or fully transparent source materials so the model remains visible.
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            var mesh_instance := node as MeshInstance3D
            for surface in range(mesh_instance.mesh.get_surface_count()):
                var source = mesh_instance.get_active_material(surface)
                var pbr := StandardMaterial3D.new()
                if source is StandardMaterial3D:
                    pbr = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
                pbr.vertex_color_use_as_albedo = true
                pbr.metallic = maxf(pbr.metallic, 0.22)
                pbr.roughness = clampf(pbr.roughness, 0.16, 0.82)
                mesh_instance.set_surface_override_material(surface, pbr)
        for child in node.get_children():
            stack.append(child)
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
    env.background_color = Color("#1E242B")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(1.0, 0.97, 0.90)
    env.ambient_light_energy = 0.35
    env.glow_enabled = true
    env.glow_intensity = 0.25
    env.glow_bloom = 0.08
    world.environment = env
    add_child(world)

    var floor := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(16.0, 16.0)
    floor.mesh = plane
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("#39332C")
    floor_material.roughness = 0.9
    floor.material_override = floor_material
    add_child(floor)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
    sun.light_color = Color(1.0, 0.96, 0.86)
    sun.light_energy = 1.4
    sun.shadow_enabled = true
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-22.0, 145.0, 0.0)
    fill.light_color = Color(0.78, 0.86, 1.0)
    fill.light_energy = 0.45
    add_child(fill)
