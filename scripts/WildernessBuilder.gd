extends RefCounted
const Assets = preload("res://scripts/AssetLoader.gd")

static func _material_from_catalog(key: String, normal: bool = false) -> Texture2D:
    var catalog := Assets._read_catalog()
    if not catalog.has(key):
        push_error("CHECKPOINT2_TEXTURE_CATALOG_MISSING: " + key)
        return null
    var path := String(catalog[key].get("path", ""))
    if path.is_empty() or not FileAccess.file_exists(path):
        push_error("CHECKPOINT2_TEXTURE_FILE_MISSING: " + key)
        return null
    var image := Image.load_from_file(path)
    if image == null or image.is_empty():
        push_error("CHECKPOINT2_TEXTURE_DECODE_FAILED: " + key)
        return null
    return ImageTexture.create_from_image(image)

static func _place_width(root: Node3D, asset_id: String, position: Vector3, target_width: float, rotation_y: float = 0.0, material: Material = null) -> bool:
    var node: Node3D = Assets.load_model(asset_id, "")
    if node == null:
        push_error("CHECKPOINT2_REQUIRED_GLB_MISSING: " + asset_id)
        return false
    var bounds := Assets._measure_bounds(node, Transform3D.IDENTITY)
    var width := maxf(bounds.size.x, bounds.size.z)
    if width <= 0.001:
        push_error("CHECKPOINT2_GLB_BOUNDS_INVALID: " + asset_id)
        node.free()
        return false
    var factor := target_width / width
    node.scale *= Vector3.ONE * factor
    node.position.y -= bounds.position.y * factor
    node.position += position
    node.rotation.y = rotation_y
    if material != null:
        _apply_material(node, material)
    root.add_child(node)
    print("CHECKPOINT2_GLB_PLACED: ", asset_id, " width=", target_width, " position=", position)
    return true

static func _apply_material(node: Node, material: Material) -> void:
    if node is MeshInstance3D:
        (node as MeshInstance3D).material_override = material
    for child in node.get_children():
        _apply_material(child, material)

static func build(root: Node3D) -> bool:
    var catalog := Assets._read_catalog()
    for key in ["leafy_grass_diffuse", "leafy_grass_normal", "leafy_grass_roughness",
                "alpine_and_arctic_biomes", "mountainside", "rock_face_01", "rock_face_02", "boulder_01"]:
        if not catalog.has(key):
            push_error("CHECKPOINT2_CATALOG_ENTRY_MISSING: " + key)
            return false

    var diffuse := _material_from_catalog("leafy_grass_diffuse")
    var normal := _material_from_catalog("leafy_grass_normal")
    var roughness := _material_from_catalog("leafy_grass_roughness")
    if diffuse == null or normal == null or roughness == null:
        return false
    var grass := StandardMaterial3D.new()
    grass.albedo_texture = diffuse
    grass.normal_enabled = true
    grass.normal_texture = normal
    grass.roughness_texture = roughness
    grass.uv1_scale = Vector3(0.12, 0.12, 0.12)
    grass.roughness = 0.92

    # One approved flat carrier only. It sits below the already-built city, moat and bridges.
    var ground := MeshInstance3D.new()
    ground.name = "Wilderness_900m_LeafyGrass_PBR"
    var plane := PlaneMesh.new()
    plane.size = Vector2(900.0, 900.0)
    ground.mesh = plane
    ground.position = Vector3(0.0, -1.35, 0.0)
    ground.material_override = grass
    root.add_child(ground)
    print("CHECKPOINT2_GRASS_GROUND_OK: 900x900m PBR; Twin City 320m, 18m moat and bridges untouched")

    # Northern snowy ridge: asset-only silhouettes, kept north of the 20m safety apron.
    if not _place_width(root, "alpine_and_arctic_biomes", Vector3(-115, 0, -305), 155.0): return false
    if not _place_width(root, "mountainside", Vector3(45, 0, -315), 170.0): return false
    if not _place_width(root, "alpine_and_arctic_biomes", Vector3(205, 0, -300), 150.0): return false
    if not _place_width(root, "mountainside", Vector3(345, 0, -270), 105.0): return false

    # Four raised terrain masses; leave a winding open corridor for the future river.
    var plateau_grass := grass.duplicate() as StandardMaterial3D
    if not _place_width(root, "mountainside", Vector3(-315, 0, -55), 115.0, 0.25, plateau_grass): return false
    if not _place_width(root, "mountainside", Vector3(315, 0, -55), 115.0, -0.2, plateau_grass): return false
    if not _place_width(root, "mountainside", Vector3(-285, 0, 290), 120.0, 0.4, plateau_grass): return false
    if not _place_width(root, "mountainside", Vector3(285, 0, 290), 120.0, -0.35, plateau_grass): return false

    # Exposed rock faces and boulders at the western and south-western escarpments.
    for i in range(4):
        if not _place_width(root, "rock_face_01" if i % 2 == 0 else "rock_face_02",
            Vector3(-365.0 + float(i) * 18.0, 0, 125.0 + float(i) * 24.0), 27.0, float(i) * 0.45): return false
    for p in [Vector3(-350,0,330), Vector3(-315,0,350), Vector3(-280,0,325), Vector3(350,0,180), Vector3(335,0,220)]:
        if not _place_width(root, "boulder_01", p, 13.0): return false

    print("CHECKPOINT2_WILDERNESS_BUILD_COMPLETE: snowy northern ridge, four plateaus, rock formations, river corridor reserved")
    return true

static func captures() -> Array:
    return [
        {"file":"wilderness_overview.png","pos":Vector3(520,430,540),"target":Vector3(0,8,0),"fov":62.0},
        {"file":"wilderness_snowy_mountains.png","pos":Vector3(30,145,-520),"target":Vector3(20,40,-300),"fov":55.0},
        {"file":"wilderness_eastern_plateau.png","pos":Vector3(470,115,-70),"target":Vector3(300,20,-55),"fov":58.0},
        {"file":"wilderness_western_plateau.png","pos":Vector3(-470,115,-60),"target":Vector3(-300,20,-55),"fov":58.0},
        {"file":"wilderness_bridge_exits.png","pos":Vector3(0,105,-270),"target":Vector3(0,0,-165),"fov":58.0},
        {"file":"wilderness_rock_formations.png","pos":Vector3(-470,95,350),"target":Vector3(-330,20,260),"fov":58.0}
    ]
