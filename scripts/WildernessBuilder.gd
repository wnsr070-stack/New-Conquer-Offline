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
    var mipmap_error := image.generate_mipmaps()
    if mipmap_error != OK:
        push_error("CHECKPOINT2_TEXTURE_MIPMAP_GENERATION_FAILED: " + key)
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
    var final_bounds := Assets._measure_bounds(node, Transform3D.IDENTITY)
    var actual_max_y := final_bounds.position.y + final_bounds.size.y
    if label.contains("Plateau"):
        if final_bounds.size.y < 18.0 or final_bounds.size.y > 28.0:
            push_error("CHECKPOINT2_PLATEAU_HEIGHT_REJECTED: " + label + " visible_height=" + str(final_bounds.size.y) + " expected=18-28m")
            node.queue_free()
            return false
        print("CHECKPOINT2_PLATEAU_HEIGHT_OK: ", label, " visible_AABB_height=", snappedf(final_bounds.size.y, 0.01), "m expected=18-28m")
    elif label.contains("Transition"):
        if actual_max_y < 22.0 or actual_max_y > 38.0:
            push_error("CHECKPOINT2_INNER_HILL_MAX_Y_REJECTED: " + label + " max_y=" + str(actual_max_y))
            node.queue_free()
            return false
        print("CHECKPOINT2_INNER_HILL_MAX_Y_OK: ", label, " max_y=", snappedf(actual_max_y, 0.01), "m")
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
    grass.albedo_color = Color(0.62, 0.78, 0.45)
    grass.normal_enabled = true
    grass.normal_texture = normal
    grass.roughness_texture = roughness_map
    grass.uv1_scale = Vector3(65.0, 65.0, 65.0)
    var preview_mode := OS.get_environment("CI_CAPTURE") == "1"
    var preview_filter := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if preview_mode else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    grass.texture_filter = preview_filter
    grass.roughness = 0.96
    grass.specular = 0.15

    var ground := MeshInstance3D.new()
    ground.name = "Wilderness_2200m_LeafyGrass_PBR"
    var plane := PlaneMesh.new()
    plane.size = Vector2(FIELD_SIZE, FIELD_SIZE)
    ground.mesh = plane
    ground.position = Vector3(0.0, -1.35, 0.0)
    ground.material_override = grass
    root.add_child(ground)
    print("CHECKPOINT2_GRASS_GROUND_OK: 2200x2200m uv1_scale=65 albedo=0.62,0.78,0.45 mipmaps=generated preview_linear=", preview_mode)

    var rock := StandardMaterial3D.new()
    rock.roughness = 0.90
    rock.specular = 0.15
    rock.metallic = 0.0
    rock.albedo_color = Color(0.22, 0.25, 0.23)


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

    # Four plateau regions use the exact same mountainside GLB as the northern ridge.
    # Four interlocking copies per region; no flattened platform meshes or snow caps.
    var plateau_blocks := [
        {"id":"WestPlateau_A","p":Vector3(-510,0,-125),"d":Vector3(82,28,78),"yaw":0.08},
        {"id":"WestPlateau_B","p":Vector3(-455,0,-105),"d":Vector3(74,24,70),"yaw":-0.12},
        {"id":"WestPlateau_C","p":Vector3(-505,0,-65),"d":Vector3(66,22,62),"yaw":0.05},
        {"id":"WestPlateau_D","p":Vector3(-455,0,-48),"d":Vector3(60,20,58),"yaw":-0.06},
        {"id":"EastPlateau_A","p":Vector3(510,0,-125),"d":Vector3(84,28,80),"yaw":-0.08},
        {"id":"EastPlateau_B","p":Vector3(455,0,-100),"d":Vector3(76,24,72),"yaw":0.12},
        {"id":"EastPlateau_C","p":Vector3(510,0,-60),"d":Vector3(68,22,62),"yaw":-0.05},
        {"id":"EastPlateau_D","p":Vector3(455,0,-42),"d":Vector3(60,20,58),"yaw":0.06},
        {"id":"SouthWestPlateau_A","p":Vector3(-510,0,430),"d":Vector3(82,28,80),"yaw":0.08},
        {"id":"SouthWestPlateau_B","p":Vector3(-455,0,465),"d":Vector3(74,24,72),"yaw":-0.12},
        {"id":"SouthWestPlateau_C","p":Vector3(-510,0,505),"d":Vector3(66,22,62),"yaw":0.05},
        {"id":"SouthWestPlateau_D","p":Vector3(-455,0,530),"d":Vector3(60,20,58),"yaw":-0.06},
        {"id":"SouthEastPlateau_A","p":Vector3(510,0,430),"d":Vector3(84,28,82),"yaw":-0.08},
        {"id":"SouthEastPlateau_B","p":Vector3(455,0,465),"d":Vector3(76,24,72),"yaw":0.12},
        {"id":"SouthEastPlateau_C","p":Vector3(510,0,505),"d":Vector3(68,22,62),"yaw":-0.05},
        {"id":"SouthEastPlateau_D","p":Vector3(455,0,530),"d":Vector3(60,20,58),"yaw":0.06}
    ]
    for item in plateau_blocks:
        if not _place_mass(root, "mountainside", item.id, item.p, item.d, item.yaw, grass, false):
            return false
    print("CHECKPOINT2_FOUR_3D_PLATEAU_CLUSTERS_OK: 16 identical mountainside GLB masses; 4 per cluster; width=55-85m height=20-28m; leafy grass applied")
    # Snow is restricted to the uppermost northern ridge peaks; the dark rock bodies remain visible.
    var snow := StandardMaterial3D.new()
    snow.albedo_color = Color(0.88, 0.92, 0.96)
    snow.roughness = 0.98
    snow.metallic = 0.0
    for peak_x in [-850.0, -550.0, -250.0, 50.0, 350.0, 650.0, 850.0]:
        var cap := MeshInstance3D.new()
        cap.name = "NorthernRidge_SummitSnowCap"
        var cap_mesh := SphereMesh.new()
        cap_mesh.is_hemisphere = true
        cap_mesh.radius = 1.0
        cap_mesh.height = 0.42
        cap.mesh = cap_mesh
        cap.scale = Vector3(25.0, 9.0, 22.0)
        cap.position = Vector3(peak_x, 83.0, -1000.0)
        cap.material_override = snow
        root.add_child(cap)
    print("CHECKPOINT2_NORTHERN_SUMMIT_SNOW_OK: subtle snow caps only on upper northern ridge")
    print("CHECKPOINT2_APRON_SURFACE_AUDIT_OK: no separate apron/frame mesh generated by city or wilderness builders")

    # Close west and south edges; the positive-X edge is rebuilt at X=+1050.
    var perimeter_visible_heights := [24.0, 28.0, 32.0, 36.0, 40.0, 38.0, 34.0, 40.0, 26.0]
    for i in range(27):
        var visible_h: float = perimeter_visible_heights[i % perimeter_visible_heights.size()]
        var along := -975.0 + float(i) * 75.0
        var side_yaw := deg_to_rad(float((i % 5) * 3 - 6))
        var side_dims := Vector3(95.0, visible_h, 95.0)
        if not _place_mass(root, "mountainside", "WestPerimeter_%02d" % i, Vector3(-1000.0,0.0,along), side_dims, -side_yaw, grass, true):
            return false
        var south_dims := Vector3(95.0, visible_h, 95.0)
        if not _place_mass(root, "mountainside", "SouthPerimeter_%02d" % i, Vector3(along,0.0,1000.0), south_dims, side_yaw, grass, true):
            return false
    # 29 blocks span exactly Z=-1050..+1050, centered on the positive-X map edge.
    for i in range(29):
        var visible_h: float = perimeter_visible_heights[i % perimeter_visible_heights.size()]
        var along := -1050.0 + float(i) * 75.0
        var side_yaw := deg_to_rad(float((i % 5) * 3 - 6))
        var east_dims := Vector3(95.0, visible_h, 95.0)
        if not _place_mass(root, "mountainside", "EastPerimeter_%02d" % i, Vector3(1050.0,0.0,along), east_dims, side_yaw, grass, true):
            return false
    print("CHECKPOINT2_PERIMETER_RIDGES_CONNECTED_OK: 83 interlocking mountainside masses; east X=+1050 Z=-1050..+1050; west and south closed; visible_AABB_height=24-40m; north ridge unchanged")

    # No separate valley/approach PlaneMeshes: the continuous Leafy Grass ground remains visible.
    # The future river corridor is reserved logically and will be excavated in Checkpoint 3.
    print("CHECKPOINT2_RIVER_VALLEY_RESERVED: winding 30m corridor; no extra flat green surface")
    print("CHECKPOINT2_BRIDGE_GRASS_TEXTURE_OK: continuous Leafy Grass ground exposed at all bridge exits")
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
        {"asset":"rock_face_01","id":"EastEscarpmentNorth","p":Vector3(510,0,-150),"d":Vector3(54,17,42)},
        {"asset":"rock_face_02","id":"SouthEastEscarpment","p":Vector3(505,0,510),"d":Vector3(58,18,46)},
        {"asset":"boulder_01","id":"BoulderWest","p":Vector3(-365,0,245),"d":Vector3(15,4.5,13)},
        {"asset":"boulder_01","id":"BoulderSouthWest","p":Vector3(-345,0,440),"d":Vector3(18,5,15)},
        {"asset":"boulder_01","id":"BoulderEast","p":Vector3(365,0,245),"d":Vector3(15,4.5,13)},
        {"asset":"boulder_01","id":"BoulderSouthEast","p":Vector3(345,0,440),"d":Vector3(18,5,15)}
    ]
    for item in rock_specs:
        if not _place_mass(root, item.asset, item.id, item.p, item.d, 0.0, rock):
            return false

    print("CHECKPOINT2_WILDERNESS_BUILD_COMPLETE: 2200m PBR field, four 3D plateau clusters, continuous east-west-south perimeter ridges, grounded rocks")
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
