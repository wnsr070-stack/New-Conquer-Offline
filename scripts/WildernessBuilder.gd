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
    # Accept broad natural terrain silhouettes while rejecting narrow vertical pillars.
    # Both horizontal AABB axes must remain at least 1.3x the height; cap at 12.0x.
    var min_ratio := 1.3
    var max_ratio := 12.0
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

    # Two continuous, overlapping northern mountain rows; rear row is taller.
    var front_heights := [36.0,40.0,43.0,45.0,42.0,44.0,39.0,45.0,41.0,43.0,45.0,40.0,44.0,42.0,45.0,39.0,43.0,45.0,41.0,44.0,42.0,45.0,40.0,43.0,45.0,41.0,44.0,42.0,45.0,39.0,43.0,45.0,40.0]
    for i in range(front_heights.size()):
        var h: float = front_heights[i]
        var x := -1040.0 + float(i) * 65.0
        var dims := Vector3(h * 3.0, h, h * 3.0)
        var yaw := deg_to_rad(float((i % 7) * 5 - 15))
        if not _place_mass(root, "mountainside", "NorthFront_%02d" % i, Vector3(x, 0.0, -900.0), dims, yaw, rock, true):
            return false

    var rear_heights := [58.0,64.0,72.0,80.0,85.0,76.0,68.0,82.0,74.0,85.0,78.0,66.0,80.0,85.0,73.0,62.0,79.0,85.0,70.0,60.0,75.0,83.0]
    for i in range(rear_heights.size()):
        var h: float = rear_heights[i]
        var x := -1050.0 + float(i) * 100.0
        var dims := Vector3(h * 2.8, h, h * 2.8)
        var yaw := deg_to_rad(float((i % 6) * 6 - 15))
        if not _place_mass(root, "mountainside", "NorthRear_%02d" % i, Vector3(x, 0.0, -1000.0), dims, yaw, rock, true):
            return false
    print("CHECKPOINT2_NORTHERN_RIDGE_CONNECTED: two overlapping rows; front=36-45m rear=58-85m")

    # Four large, visibly stepped grassy plateaus outside the 25m city safety apron.
    var plateaus := [
        {"id":"WestPlateau", "p":Vector3(-455,0,-90), "d":Vector3(105,18,92), "yaw":0.08},
        {"id":"EastPlateau", "p":Vector3(455,0,-70), "d":Vector3(125,22,112), "yaw":-0.08},
        {"id":"SouthWestPlateau", "p":Vector3(-455,0,430), "d":Vector3(92,14,86), "yaw":0.08},
        {"id":"SouthEastPlateau", "p":Vector3(455,0,430), "d":Vector3(118,20,104), "yaw":-0.08}
    ]
    for item in plateaus:
        if not _place_mass(root, "mountainside", item.id, item.p, item.d, item.yaw, grass, false):
            return false

    # Low perimeter terrain closes the east, west and southern horizon.
    var horizon := [
        {"id":"EastHorizonA","p":Vector3(930,0,-430),"d":Vector3(150,34,135),"yaw":0.12},
        {"id":"EastHorizonB","p":Vector3(1010,0,-80),"d":Vector3(160,38,145),"yaw":-0.12},
        {"id":"EastHorizonC","p":Vector3(950,0,300),"d":Vector3(150,32,140),"yaw":0.08},
        {"id":"WestHorizonA","p":Vector3(-930,0,-430),"d":Vector3(150,34,135),"yaw":-0.12},
        {"id":"WestHorizonB","p":Vector3(-1010,0,-80),"d":Vector3(160,38,145),"yaw":0.12},
        {"id":"WestHorizonC","p":Vector3(-950,0,300),"d":Vector3(150,32,140),"yaw":-0.08},
        {"id":"SouthHorizonA","p":Vector3(-650,0,990),"d":Vector3(170,38,150),"yaw":0.12},
        {"id":"SouthHorizonB","p":Vector3(-250,0,1020),"d":Vector3(180,42,155),"yaw":-0.08},
        {"id":"SouthHorizonC","p":Vector3(250,0,1020),"d":Vector3(180,42,155),"yaw":0.08},
        {"id":"SouthHorizonD","p":Vector3(650,0,990),"d":Vector3(170,38,150),"yaw":-0.12}
    ]
    for item in horizon:
        if not _place_mass(root, "mountainside", item.id, item.p, item.d, item.yaw, grass, true):
            return false

    # Flat, 30m-wide winding low corridor reserved for the future blue river.
    var valley_material := StandardMaterial3D.new()
    valley_material.albedo_color = Color(0.34, 0.43, 0.25)
    valley_material.roughness = 0.98
    var valley_points := [
        Vector3(0,-1.33,-255), Vector3(220,-1.33,-255), Vector3(255,-1.33,-110),
        Vector3(255,-1.33,110), Vector3(220,-1.33,255), Vector3(0,-1.33,255),
        Vector3(-220,-1.33,255), Vector3(-255,-1.33,110), Vector3(-255,-1.33,-110),
        Vector3(-220,-1.33,-255), Vector3(0,-1.33,-255)
    ]
    for i in range(valley_points.size() - 1):
        var a: Vector3 = valley_points[i]
        var c: Vector3 = valley_points[i + 1]
        var delta := c - a
        var strip := MeshInstance3D.new()
        strip.name = "FutureRiverLowValley_%02d_30m" % i
        var strip_mesh := PlaneMesh.new()
        strip_mesh.size = Vector2(30.0, delta.length())
        strip.mesh = strip_mesh
        strip.position = (a + c) * 0.5
        strip.rotation.y = atan2(delta.x, delta.z)
        strip.material_override = valley_material
        root.add_child(strip)
    print("CHECKPOINT2_RIVER_VALLEY_RESERVED: winding 30m corridor around city")

    # Light dirt paths lead outward from all four bridges without entering the moat apron.
    var path_material := StandardMaterial3D.new()
    path_material.albedo_color = Color(0.58, 0.46, 0.30)
    path_material.roughness = 1.0
    var bridge_paths := [
        {"a":Vector3(0,-1.30,-190),"b":Vector3(0,-1.30,-320)},
        {"a":Vector3(0,-1.30,190),"b":Vector3(0,-1.30,320)},
        {"a":Vector3(190,-1.30,0),"b":Vector3(340,-1.30,0)},
        {"a":Vector3(-190,-1.30,0),"b":Vector3(-340,-1.30,0)}
    ]
    for i in range(bridge_paths.size()):
        var a: Vector3 = bridge_paths[i].a
        var c: Vector3 = bridge_paths[i].b
        var delta := c - a
        var path := MeshInstance3D.new()
        path.name = "BridgeToPlateauDirtPath_%02d" % i
        var path_mesh := PlaneMesh.new()
        path_mesh.size = Vector2(8.0, delta.length())
        path.mesh = path_mesh
        path.position = (a + c) * 0.5
        path.rotation.y = atan2(delta.x, delta.z)
        path.material_override = path_material
        root.add_child(path)
    print("CHECKPOINT2_FOUR_BRIDGE_PATHS_OK: light dirt paths lead toward outer plateaus")

    var rock_specs := [
        {"asset":"rock_face_01","id":"WestEscarpmentA","p":Vector3(-510,0,-150),"d":Vector3(48,15,38)},
        {"asset":"rock_face_02","id":"WestEscarpmentB","p":Vector3(-515,0,210),"d":Vector3(54,17,42)},
        {"asset":"rock_face_01","id":"EastEscarpmentA","p":Vector3(515,0,185),"d":Vector3(52,16,44)},
        {"asset":"rock_face_02","id":"SouthWestEscarpment","p":Vector3(-505,0,510),"d":Vector3(58,18,46)},
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
        {"file":"wilderness_snowy_mountains.png","pos":Vector3(0,250,-560),"target":Vector3(0,42,-920),"fov":58.0},
        {"file":"wilderness_bridge_grass.png","pos":Vector3(0,18,-310),"target":Vector3(0,5,-255),"fov":58.0},
        {"file":"wilderness_eastern_plateau.png","pos":Vector3(680,150,-120),"target":Vector3(455,12,-70),"fov":58.0},
        {"file":"wilderness_western_plateau.png","pos":Vector3(-680,150,-140),"target":Vector3(-455,12,-90),"fov":58.0},
        {"file":"wilderness_south_plaza.png","pos":Vector3(560,220,850),"target":Vector3(0,10,300),"fov":60.0}
    ]
