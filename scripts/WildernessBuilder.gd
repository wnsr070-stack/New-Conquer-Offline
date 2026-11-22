extends RefCounted
const Assets = preload("res://scripts/AssetLoader.gd")
const BURIAL_Y := -2.0
const FIELD_SIZE := 2200.0

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

static func _validate_mass(node: Node3D, asset_id: String, label: String, mountain: bool) -> bool:
    var bounds := Assets._measure_bounds(node, Transform3D.IDENTITY)
    if bounds.size.x <= 0.001 or bounds.size.y <= 0.001 or bounds.size.z <= 0.001:
        push_error("CHECKPOINT2_AABB_INVALID: " + label + " asset=" + asset_id)
        return false
    var rx := bounds.size.x / bounds.size.y
    var rz := bounds.size.z / bounds.size.y
    # Accept natural broad terrain silhouettes while rejecting narrow vertical pillars.
    # Both horizontal AABB axes must remain at least 1.3x the height; cap at 4.0x.
    var min_ratio := 1.3
    var max_ratio := 4.0
    if rx < min_ratio or rx > max_ratio or rz < min_ratio or rz > max_ratio:
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

static func _place_mass(root: Node3D, asset_id: String, label: String, center: Vector3, dimensions: Vector3, yaw: float, material: StandardMaterial3D, mountain: bool = false) -> bool:
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
    if not _validate_mass(node, asset_id, label, mountain):
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
    grass.albedo_color = Color(0.52, 0.82, 0.38)
    grass.normal_enabled = true
    grass.normal_texture = normal
    grass.roughness_texture = roughness_map
    grass.uv1_scale = Vector3(110.0, 110.0, 110.0)
    grass.roughness = 0.92
    grass.specular = 0.15

    var ground := MeshInstance3D.new()
    ground.name = "Wilderness_2200m_LeafyGrass_PBR"
    var plane := PlaneMesh.new()
    plane.size = Vector2(FIELD_SIZE, FIELD_SIZE)
    ground.mesh = plane
    ground.position = Vector3(0.0, -1.35, 0.0)
    ground.material_override = grass
    root.add_child(ground)
    print("CHECKPOINT2_GRASS_GROUND_OK: 2200x2200m uv1_scale=110 albedo=0.52,0.82,0.38")

    var rock := StandardMaterial3D.new()
    rock.roughness = 0.90
    rock.specular = 0.15
    rock.metallic = 0.0
    rock.albedo_color = Color(0.34, 0.37, 0.31)

    var plateau_material := StandardMaterial3D.new()
    plateau_material.albedo_texture = diffuse
    plateau_material.albedo_color = Color(0.36, 0.48, 0.29)
    plateau_material.normal_enabled = true
    plateau_material.normal_texture = normal
    plateau_material.roughness_texture = roughness_map
    plateau_material.uv1_scale = Vector3(24.0, 24.0, 24.0)
    plateau_material.roughness = 0.94
    plateau_material.specular = 0.12
    plateau_material.metallic = 0.0

    # Northern ridge: broad low-profile masses, rotated in plan, with no snow assets outside this northern zone.
    var ridge_x := [-900.0, -750.0, -600.0, -450.0, -300.0, -150.0, 0.0, 150.0, 300.0, 450.0, 600.0, 750.0, 900.0]
    var ridge_h := [38.0, 42.0, 48.0, 55.0, 63.0, 70.0, 74.0, 70.0, 63.0, 56.0, 49.0, 43.0, 38.0]
    for i in range(ridge_x.size()):
        var h: float = ridge_h[i]
        var dims := Vector3(h * 1.75, h, h * 1.8)
        var z := -405.0 - (12.0 if i % 2 == 0 else 0.0)
        var yaw := deg_to_rad(float((i % 5) * 9 - 18))
        if not _place_mass(root, "mountainside", "NorthRidge_%02d" % i, Vector3(ridge_x[i], 0.0, z), dims, yaw, rock, true):
            return false

    # Four broad stepped plateaus; each remains outside the 25m moat/bridge safety apron.
    var plateaus := [
        {"id":"WestPlateau", "p":Vector3(-390,0,-80), "d":Vector3(42,14,42), "yaw":0.08},
        {"id":"EastPlateau", "p":Vector3(390,0,-70), "d":Vector3(48,16,48), "yaw":-0.08},
        {"id":"SouthWestPlateau", "p":Vector3(-390,0,360), "d":Vector3(36,12,36), "yaw":0.08},
        {"id":"SouthEastPlateau", "p":Vector3(390,0,360), "d":Vector3(54,18,54), "yaw":-0.08}
    ]
    for item in plateaus:
        if not _place_mass(root, "mountainside", item.id, item.p, item.d, item.yaw, plateau_material):
            return false

    # Low distant horizon hills on the east, west and south perimeter.
    var horizon := [
        {"id":"EastHorizonA","p":Vector3(900,0,-250),"d":Vector3(45,25,45),"yaw":0.25},
        {"id":"EastHorizonB","p":Vector3(980,0,100),"d":Vector3(50,28,50),"yaw":-0.18},
        {"id":"WestHorizonA","p":Vector3(-900,0,-220),"d":Vector3(47,26,47),"yaw":-0.2},
        {"id":"WestHorizonB","p":Vector3(-980,0,130),"d":Vector3(54,30,54),"yaw":0.16},
        {"id":"SouthHorizonA","p":Vector3(-520,0,930),"d":Vector3(49,27,49),"yaw":0.22},
        {"id":"SouthHorizonB","p":Vector3(0,0,980),"d":Vector3(58,32,58),"yaw":-0.12},
        {"id":"SouthHorizonC","p":Vector3(520,0,930),"d":Vector3(60,27,80),"yaw":0.18}
    ]
    for item in horizon:
        if not _place_mass(root, "mountainside", item.id, item.p, item.d, item.yaw, rock, true):
            return false

    var rock_specs := [
        {"asset":"rock_face_01","id":"WestEscarpmentA","p":Vector3(-420,0,-165),"d":Vector3(38,11,32)},
        {"asset":"rock_face_02","id":"WestEscarpmentB","p":Vector3(-430,0,205),"d":Vector3(45,13,37)},
        {"asset":"rock_face_01","id":"EastEscarpmentA","p":Vector3(425,0,185),"d":Vector3(42,12,35)},
        {"asset":"rock_face_02","id":"SouthWestEscarpment","p":Vector3(-420,0,430),"d":Vector3(52,15,43)},
        {"asset":"boulder_01","id":"BoulderWest","p":Vector3(-365,0,245),"d":Vector3(15,4.5,13)},
        {"asset":"boulder_01","id":"BoulderSouthWest","p":Vector3(-345,0,440),"d":Vector3(18,5,15)},
        {"asset":"boulder_01","id":"BoulderEast","p":Vector3(365,0,245),"d":Vector3(15,4.5,13)},
        {"asset":"boulder_01","id":"BoulderSouthEast","p":Vector3(345,0,440),"d":Vector3(18,5,15)}
    ]
    for item in rock_specs:
        if not _place_mass(root, item.asset, item.id, item.p, item.d, 0.0, rock):
            return false

    print("CHECKPOINT2_WILDERNESS_BUILD_COMPLETE: 2200m PBR field, varied northern ridge, four raised plateaus, east-west-south horizon hills, grounded rocks")
    print("CHECKPOINT2_ALL_MASS_AABB_VALIDATED")
    return true

static func captures() -> Array:
    return [
        {"file":"wilderness_overview.png","pos":Vector3(920,650,980),"target":Vector3(0,25,-120),"fov":62.0},
        {"file":"wilderness_snowy_mountains.png","pos":Vector3(0,24,-250),"target":Vector3(0,35,-420),"fov":58.0},
        {"file":"wilderness_bridge_grass.png","pos":Vector3(0,7,-215),"target":Vector3(0,3,-275),"fov":58.0},
        {"file":"wilderness_eastern_plateau.png","pos":Vector3(520,95,-80),"target":Vector3(390,10,-70),"fov":58.0},
        {"file":"wilderness_western_plateau.png","pos":Vector3(-520,95,-80),"target":Vector3(-390,10,-80),"fov":58.0},
        {"file":"wilderness_south_plaza.png","pos":Vector3(420,180,650),"target":Vector3(0,3,80),"fov":60.0}
    ]
