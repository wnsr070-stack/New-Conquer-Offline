extends Node3D
const Assets = preload("res://scripts/AssetLoader.gd")
const PAGE_SIZE := 12
const COLS := 4
const TILE_X := 20.0
const TILE_Z := 19.0

func _ready() -> void:
    _build_lighting()
    var file := FileAccess.open("res://artifacts/building_inventory.json", FileAccess.READ)
    if file == null:
        push_error("HF_BUILDINGS_PREVIEW_FAILED: inventory JSON missing")
        get_tree().quit(2)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_ARRAY or parsed.is_empty():
        push_error("HF_BUILDINGS_PREVIEW_FAILED: no architectural candidates")
        get_tree().quit(2)
        return
    var items: Array = parsed
    var measured: Array = []
    var page_count := int(ceil(float(items.size()) / float(PAGE_SIZE)))
    for page in range(page_count):
        await _render_page(items, page, measured)
    var output := FileAccess.open("res://artifacts/building_inventory_measured.json", FileAccess.WRITE)
    if output != null:
        output.store_string(JSON.stringify(measured, "\t"))
    print("HF_BUILDINGS_PREVIEW_COMPLETE: assets=", items.size(), " pages=", page_count)
    get_tree().quit(0)

func _build_lighting() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.72, 0.78, 0.84)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.78, 0.82, 0.9)
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    add_child(sun)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-20, 145, 0)
    fill.light_energy = 0.5
    fill.light_color = Color(0.72, 0.82, 1.0)
    add_child(fill)

func _render_page(items: Array, page: int, measured: Array) -> void:
    var start := page * PAGE_SIZE
    var finish := mini(start + PAGE_SIZE, items.size())
    var page_items := items.slice(start, finish)
    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(88, 65)
    ground.mesh = plane
    ground.position.y = -0.15
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color(0.78, 0.8, 0.82)
    ground_mat.roughness = 0.95
    ground.material_override = ground_mat
    add_child(ground)
    for i in range(page_items.size()):
        var item: Dictionary = page_items[i]
        var model := Assets.load_model(String(item.get("asset_id", "")), "")
        if model == null:
            push_warning("HF_BUILDING_MODEL_LOAD_SKIP: " + String(item.get("repo_path", "")))
            continue
        var bounds: AABB = Assets._measure_bounds(model, Transform3D.IDENTITY)
        var dims := bounds.size
        if dims.length_squared() <= 0.000001:
            model.free()
            continue
        var max_dim := maxf(dims.x, maxf(dims.y, dims.z))
        var factor := 7.0 / max_dim
        model.scale = model.scale * Vector3.ONE * factor
        model.position.y -= bounds.position.y * factor
        var col := i % COLS
        var row := int(i / COLS)
        var x := (float(col) - 1.5) * TILE_X
        var z := (float(row) - 1.0) * TILE_Z
        model.position += Vector3(x, 0, z)
        add_child(model)
        var label := Label3D.new()
        var filename := String(item.get("file_name", item.get("name", "unknown")))
        label.text = filename + "\nW " + _m(dims.x) + " × D " + _m(dims.z) + " × H " + _m(dims.y) + " m"
        label.font_size = 26
        label.outline_size = 8
        label.pixel_size = 0.012
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.modulate = Color(0.08, 0.1, 0.13)
        label.position = Vector3(x, 0.18, z + 6.0)
        add_child(label)
        var measured_item := item.duplicate(true)
        measured_item["measured_dimensions_m"] = [dims.x, dims.z, dims.y]
        measured_item["preview_page"] = page + 1
        measured.append(measured_item)
        print("HF_BUILDING_MEASURED: ", filename, " W=", dims.x, " D=", dims.z, " H=", dims.y)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 76.0
    camera.position = Vector3(0, 92, 102)
    camera.current = true
    add_child(camera)
    camera.look_at(Vector3(0, 0, 0), Vector3.UP)
    for frame in range(8):
        await get_tree().process_frame
    var image := get_viewport().get_texture().get_image()
    var path := "res://artifacts/preview_buildings_grid_" + str(page + 1) + ".png"
    var err := image.save_png(ProjectSettings.globalize_path(path))
    if err != OK:
        push_error("HF_BUILDINGS_PREVIEW_FAILED: cannot save " + path)
        get_tree().quit(3)
        return
    print("HF_BUILDINGS_PREVIEW_CAPTURE_OK: ", path)
    for child in get_children():
        if child != get_node_or_null("WorldEnvironment"):
            child.queue_free()
    await get_tree().process_frame

func _m(value: float) -> String:
    return "%.2f" % value
