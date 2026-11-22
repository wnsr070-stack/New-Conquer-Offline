extends RefCounted
const Assets = preload("res://scripts/AssetLoader.gd")
const BURIAL_Y := -2.0

static func _texture(key: String) -> Texture2D:
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

static func _apply_material(node: Node, material: StandardMaterial3D) -> void:
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        mesh_node.material_override = material
        mesh_node.material_overlay = null
    for child in node.get_children():
        _apply_material(child, material)

static func _validate_mass(node: Node3D, asset_id: String, label: String) -> bool:
    var bounds := Assets._measure_bounds(node, Transform3D.IDENTITY)
    if bounds.size.x <= 0.001 or bounds.size.y <= 0.001 or bounds.size.z <= 0.001:
        push_error("CHECKPOINT2_AABB_INVALID: " + label + " asset=" + asset_id)
        return false
    var rx := bounds.size.x / bounds.size.y
    var rz := bounds.size.z / bounds.size.y
    if rx < 2.5 or rx > 4.0 or rz < 2.5 or rz > 4.0:
        push_error("CHECKPOINT2_PROPORTION_REJECTED: " + label + " x/y=" + str(rx) + " z/y=" + str(rz))
        return false
    if bounds.position.y > 0.1:
        push_error("CHECKPOINT2_BASE_ABOVE_GROUND: " + label + " min_y=" + str(bounds.position.y))
        return false
    if bounds.position.y < -3.01 or bounds.position.y > -1.49:
        push_error("CHECKPOINT2_BASE_BURIAL_OUT_OF_RANGE: " + label + " min_y=" + str(bounds.position.y))
        return false
    print("CHECKPOINT2_AABB_VALID: ", label, " asset=", asset_id, " size=", bounds.size, " min_y=", bounds.position.y, " ratios=", rx, ",", rz)
    return true

static func _place_mass(root: Node3D, asset_id: String, label: String, center: Vector3, dimensions: Vector3, yaw: float, material: StandardMaterial3D) -> bool:
    var node: Node3D = Assets.load_model(asset_id, "")
    if node == null:
        push_error("CHECKPOINT2_REQUIRED_GLB_MISSING: " + asset_id)
        return false
    var source := Assets._measure_bounds(node, Transform3D.IDENTITY)
    if source.size.x <= 0.001 or source.size.y <= 0.001 or source.size.z <= 0.001:
        push_error("CHECKPOINT2_SOURCE_AABB_INVALID: " + asset_id)
        node.free()
        return false
    node.scale = Vector3(dimensions.x / source.size.x, dimensions.y / source.size.y, dimensions.z / source.size.z)
    node.rotation = Vector3(0.0, yaw, 0.0)
    node.position = Vector3(center.x, BURIAL_Y - source.position.y * node.scale.y, center.z)
    _apply_material(node, material)
    root.add_child(node)
    if not _validate_mass(node, asset_id, label):
        node.queue_free()
        return false
    return true

static func build(root: Node3D) -> bool:
    var catalog := Assets._read_catalog()
    for key in ["leafy_grass_diffuse", "leafy_grass_normal", "leafy_grass_roughness", "mountainside", "rock_face_01", "rock_face_02", "boulder_01"]:
        if not catalog.has(key):
            push_error("CHECKPOINT2_CATALOG_ENTRY_MISSING: " + key)
            return false
    if catalog.has("alpine_and_arctic_biomes"):
        catalog.erase("alpine_and_arctic_biomes")
        print("CHECKPOINT2_CARTOON_BIOME_EXCLUDED: removed from runtime catalog")

    var diffuse := _texture("leafy_grass_diffuse")
    var normal := _texture("leafy_grass_normal")
    var roughness_map := _texture("leafy_grass_roughness")
    if diffuse == null or normal == null or roughness_map == null:
        return false
    var grass := StandardMaterial3D.new()
    grass.albedo_texture = diffuse
    grass.normal_enabled = true
    grass.normal_texture = normal
    grass.roughness_texture = roughness_map
    grass.uv1_scale = Vector3(150.0, 150.0, 150.0)
    grass.roughness = 0.92
    grass.specular = 0.15

    var ground := MeshInstance3D.new()
    ground.name = "Wilderness_900m_LeafyGrass_PBR"
    var plane := PlaneMesh.new()
    plane.size = Vector2(900.0, 900.0)
    ground.mesh = plane
    ground.position = Vector3(0.0, -1.35, 0.0)
    ground.material_override = grass
    root.add_child(ground)
    print("CHECKPOINT2_GRASS_GROUND_OK: 900x900m uv1_scale=150 roughness=0.92 specular=0.15")

    var rock := StandardMaterial3D.new()
    rock.roughness = 0.90
    rock.specular = 0.15
    rock.metallic = 0.0
    rock.albedo_color = Color(0.58, 0.55, 0.49)

    var ridge_x := [-360.0, -270.0, -180.0, -90.0, 0.0, 90.0, 180.0, 270.0, 360.0]
    var ridge_h := [38.0, 44.0, 52.0, 62.0, 75.0, 68.0, 58.0, 48.0, 40.0]
    for i in range(ridge_x.size()):
        var h: float = ridge_h[i]
        var dims := Vector3(h * 3.2, h, h * 2.8)
        var z := -300.0 - (8.0 if i % 2 == 0 else 0.0)
        if not _place_mass(root, "mountainside", "NorthRidge_%02d" % i, Vector3(ridge_x[i], 0.0, z), dims, 0.0, rock):
            return false

    var plateaus := [
        {"id":"WestPlateau", "p":Vector3(-300,0,-255), "d":Vector3(42,12,36)},
        {"id":"EastPlateau", "p":Vector3(300,0,-255), "d":Vector3(49,14,42)},
        {"id":"SouthWestPlateau", "p":Vector3(-300,0,285), "d":Vector3(35,10,30)},
        {"id":"SouthEastPlateau", "p":Vector3(300,0,285), "d":Vector3(56,16,48)}
    ]
    for item in plateaus:
        if not _place_mass(root, "mountainside", item.id, item.p, item.d, 0.0, grass):
            return false

    var rock_specs := [
        {"asset":"rock_face_01","id":"WestEscarpmentA","p":Vector3(-360,0,-205),"d":Vector3(35,10,28)},
        {"asset":"rock_face_02","id":"WestEscarpmentB","p":Vector3(-365,0,155),"d":Vector3(42,12,34)},
        {"asset":"rock_face_01","id":"EastEscarpmentA","p":Vector3(365,0,150),"d":Vector3(38,11,31)},
        {"asset":"rock_face_02","id":"SouthWestEscarpment","p":Vector3(-355,0,350),"d":Vector3(49,14,40)},
        {"asset":"boulder_01","id":"BoulderWest","p":Vector3(-350,0,205),"d":Vector3(14,4,12)},
        {"asset":"boulder_01","id":"BoulderSouthWest","p":Vector3(-315,0,365),"d":Vector3(16,4.5,13)},
        {"asset":"boulder_01","id":"BoulderEast","p":Vector3(350,0,205),"d":Vector3(14,4,12)},
        {"asset":"boulder_01","id":"BoulderSouthEast","p":Vector3(315,0,365),"d":Vector3(16,4.5,13)}
    ]
    for item in rock_specs:
        if not _place_mass(root, item.asset, item.id, item.p, item.d, 0.0, rock):
            return false

    print("CHECKPOINT2_WILDERNESS_BUILD_COMPLETE: 900m PBR field, broad northern ridge, four plateaus, grounded rocks")
    print("CHECKPOINT2_ALL_MASS_AABB_VALIDATED")
    return true

static func captures() -> Array:
    return [
        {"file":"wilderness_overview.png","pos":Vector3(510,410,520),"target":Vector3(0,20,-120),"fov":62.0},
        {"file":"wilderness_snowy_mountains.png","pos":Vector3(0,18,-225),"target":Vector3(0,42,-315),"fov":58.0},
        {"file":"wilderness_bridge_grass.png","pos":Vector3(0,5,-205),"target":Vector3(0,3,-255),"fov":58.0},
        {"file":"wilderness_eastern_plateau.png","pos":Vector3(420,70,-240),"target":Vector3(300,8,-255),"fov":58.0},
        {"file":"wilderness_western_plateau.png","pos":Vector3(-420,70,-240),"target":Vector3(-300,8,-255),"fov":58.0},
        {"file":"wilderness_south_plaza.png","pos":Vector3(260,125,430),"target":Vector3(0,2,80),"fov":60.0}
    ]
