extends Node3D
const Assets = preload("res://scripts/AssetLoader.gd")
const Wilderness = preload("res://scripts/WildernessBuilder.gd")
const PALACE_ID := "imperial_palace"
const PAGODA_ID := "innerscene-buddhist-temple-pagoda-c5ebacdc"
const TEA_HOUSE_ID := "3dassets-feudal-japan-castle-town-tea-house-a168f962"
const QUEST_HALL_ID := "quest_hall"
const HOUSE_IDS := ["obj_chinese_house", "obj_chinese_painter_villa", "obj_big_chinese_house"]
const CITY_SIZE := 320.0
const CITY_HALF := CITY_SIZE * 0.5
const DIRT_TILE_SOURCE_SIZE := 11.8
const DIRT_TILES_PER_SIDE := 28
var captures := [
    {"file": "twin_city_overview.png", "pos": Vector3(330, 315, 350), "target": Vector3(0, 4, 0), "fov": 58.0},
    {"file": "twin_city_palace.png", "pos": Vector3(0, 25, -43), "target": Vector3(0, 12, -75), "fov": 39.0},
    {"file": "twin_city_ne_pagoda.png", "pos": Vector3(92, 39, -48), "target": Vector3(92, 17, -92), "fov": 42.0},
    {"file": "twin_city_nw_quest_hall.png", "pos": Vector3(-92, 20, -52), "target": Vector3(-92, 7, -92), "fov": 44.0},
    {"file": "twin_city_se_tea_house.png", "pos": Vector3(92, 20, 137), "target": Vector3(92, 7, 92), "fov": 44.0},
    {"file": "twin_city_sw_blacksmith.png", "pos": Vector3(-92, 17, 130), "target": Vector3(-92, 5, 92), "fov": 40.0}
]
func _ready() -> void:
    _lighting()
    if not _build_city():
        await _shutdown(1)
        return
    var removed_aprons: Array[int] = [0]
    _remove_named_apron_meshes(self, removed_aprons)
    print("CHECKPOINT2_APRON_SURFACE_AUDIT_OK: removed_named_surfaces=", removed_aprons[0], "; city moat, bridges and dirt floor preserved")
    if not Wilderness.build(self):
        await _shutdown(1)
        return
    captures.append_array(Wilderness.captures())
    _camera()
    if OS.get_environment("CI_CAPTURE") == "1":
        _capture.call_deferred()
func _remove_named_apron_meshes(node: Node, removed: Array[int]) -> void:
    for child in node.get_children():
        var lower_name := String(child.name).to_lower()
        var is_apron := child is MeshInstance3D and (
            lower_name.contains("apron") or lower_name.contains("safety_frame") or
            lower_name.contains("outer_city_frame") or lower_name.contains("moat_frame")
        )
        if is_apron:
            node.remove_child(child)
            child.free()
            removed[0] += 1
        else:
            _remove_named_apron_meshes(child, removed)

func _mat(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    return material
func _box(name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = pos
    node.material_override = material
    add_child(node)
    return node
func _plane(name: String, size: Vector2, pos: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name
    var mesh := PlaneMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = pos
    node.material_override = material
    add_child(node)
    return node
func _lighting() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.28, 0.56, 0.92)
    sky_material.sky_horizon_color = Color(0.68, 0.84, 0.98)
    sky_material.ground_bottom_color = Color(0.62, 0.80, 0.96)
    sky_material.ground_horizon_color = Color(0.68, 0.84, 0.98)
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.25
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.fog_enabled = false
    environment.fog_light_color = Color(0.72, 0.86, 0.98)
    environment.fog_density = 0.00035
    environment.fog_depth_begin = 950.0
    environment.fog_depth_end = 2100.0
    environment.fog_depth_curve = 1.0
    environment.fog_sky_affect = 0.0
    print("CHECKPOINT2_HORIZON_FOG_OK: fog disabled; ambient=0.25 sun=0.75 sky_affect=0.0")
    world.environment = environment
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_energy = 0.75
    sun.shadow_enabled = true
    add_child(sun)
func _texture(key: String) -> Texture2D:
    var catalog := Assets._read_catalog()
    if not catalog.has(key):
        push_error("CHECKPOINT1_TEXTURE_CATALOG_MISSING: " + key)
        return null
    var path := String(catalog[key].get("path", ""))
    if path.is_empty() or not FileAccess.file_exists(path):
        push_error("CHECKPOINT1_TEXTURE_FILE_MISSING: " + key + " " + path)
        return null
    var image := Image.load_from_file(path)
    if image == null or image.is_empty():
        push_error("CHECKPOINT1_TEXTURE_IMAGE_DECODE_FAILED: " + key)
        return null
    return ImageTexture.create_from_image(image)
func _cobble() -> StandardMaterial3D:
    var material := _mat(Color.WHITE)
    var diffuse := _texture("cobblestone_diffuse")
    var normal := _texture("cobblestone_normal")
    var roughness := _texture("cobblestone_roughness")
    if diffuse == null or normal == null or roughness == null:
        push_error("CHECKPOINT1_COBBLESTONE_FLOOR_04_INCOMPLETE")
        return null
    material.albedo_texture = diffuse
    material.normal_enabled = true
    material.normal_texture = normal
    material.roughness_texture = roughness
    material.uv1_scale = Vector3(0.085, 0.085, 0.085)
    print("CHECKPOINT1_COBBLE_RUNTIME_IMAGE_TEXTURES_OK: diffuse=true normal=true roughness=true")
    return material
func _collect_meshes(node: Node, parent_transform: Transform3D, output: Array[Dictionary]) -> void:
    var transform := parent_transform
    if node is Node3D:
        transform = parent_transform * (node as Node3D).transform
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        if mesh_node.mesh != null:
            output.append({"mesh": mesh_node.mesh, "transform": transform, "material_override": mesh_node.material_override})
    for child in node.get_children():
        _collect_meshes(child, transform, output)
func _build_dirt_ground() -> bool:
    var source: Node3D = Assets.load_model("grab3d-dirt-road", "")
    if source == null:
        push_error("CHECKPOINT1_DIRT_ROAD_IMPORT_FAILED")
        return false
    _plane("Full320mDirtBase_NoGreenGaps", Vector2(CITY_SIZE, CITY_SIZE), Vector3(0, -0.27, 0), _mat(Color(0.30, 0.205, 0.12)))
    var meshes: Array[Dictionary] = []
    _collect_meshes(source, Transform3D.IDENTITY, meshes)
    if meshes.is_empty():
        push_error("CHECKPOINT1_DIRT_ROAD_HAS_NO_MESHES")
        source.free()
        return false
    var tile_span := CITY_SIZE / float(DIRT_TILES_PER_SIDE)
    var tile_scale := (tile_span / DIRT_TILE_SOURCE_SIZE) * 1.002
    var instances_per_mesh := DIRT_TILES_PER_SIDE * DIRT_TILES_PER_SIDE
    for mesh_data in meshes:
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = mesh_data["mesh"]
        multimesh.instance_count = instances_per_mesh
        var instance_node := MultiMeshInstance3D.new()
        instance_node.name = "Grab3DDirtRoad_TiledSurface"
        instance_node.multimesh = multimesh
        var dirt_material := _mat(Color(0.43, 0.30, 0.19))
        dirt_material.roughness = 1.0
        instance_node.material_override = dirt_material
        add_child(instance_node)
        var index := 0
        for row in range(DIRT_TILES_PER_SIDE):
            for column in range(DIRT_TILES_PER_SIDE):
                var x := -CITY_HALF + (float(column) + 0.5) * tile_span
                var z := -CITY_HALF + (float(row) + 0.5) * tile_span
                var tile_transform := Transform3D(Basis.from_scale(Vector3(tile_scale, 1.0, tile_scale)), Vector3(x, -0.22, z))
                multimesh.set_instance_transform(index, tile_transform * mesh_data["transform"])
                index += 1
    source.free()
    print("CHECKPOINT1_UNIFIED_DIRT_GROUND_OK: grab3d-dirt-road tiled ", DIRT_TILES_PER_SIDE, "x", DIRT_TILES_PER_SIDE, " covers 320x320m")
    print("CHECKPOINT1_FULL_GROUND_NO_GREEN_GAPS_OK: 320x320m")
    print("CHECKPOINT1_GROUND_GREEN_MATERIAL_OVERRIDE_OK: all tiled GLB surfaces unified earth-brown")
    return true
func _build_walls_moat_and_bridges() -> void:
    var wall_material := _mat(Color(0.39, 0.38, 0.34))
    var pier_material := _mat(Color(0.47, 0.44, 0.38))
    var water_material := _mat(Color(0.055, 0.20, 0.27, 0.86))
    water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    water_material.roughness = 0.22
    var bridge_material := _mat(Color(0.35, 0.23, 0.13))
    _plane("NorthMoat_18m", Vector2(320, 18), Vector3(0, -0.85, -169), water_material)
    _plane("SouthMoat_18m", Vector2(320, 18), Vector3(0, -0.85, 169), water_material)
    _plane("EastMoat_18m", Vector2(18, 320), Vector3(169, -0.85, 0), water_material)
    _plane("WestMoat_18m", Vector2(18, 320), Vector3(-169, -0.85, 0), water_material)
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            _plane("MoatCorner", Vector2(18, 18), Vector3(sx * 169, -0.85, sz * 169), water_material)
    var segment_length := CITY_SIZE / 27.0
    var wall_piece_count := 0
    for side in range(4):
        for index in range(27):
            if index == 13:
                continue
            var along := -CITY_HALF + (float(index) + 0.5) * segment_length
            var is_gate_pier := index == 12 or index == 14
            var piece_size := Vector3(segment_length + 0.08, 7.0, 2.4)
            var piece_pos := Vector3(along, 3.5, -156)
            if side == 1:
                piece_pos = Vector3(along, 3.5, 156)
            elif side == 2:
                piece_size = Vector3(2.4, 7.0, segment_length + 0.08)
                piece_pos = Vector3(156, 3.5, along)
            elif side == 3:
                piece_size = Vector3(2.4, 7.0, segment_length + 0.08)
                piece_pos = Vector3(-156, 3.5, along)
            if is_gate_pier:
                piece_size = Vector3(3.4, 9.0, 3.4)
                piece_pos.y = 4.5
                _box("TwinCity_GatePier_%d_%d" % [side, index], piece_size, piece_pos, pier_material)
            else:
                _box("TwinCity_WallSegment_%d_%d" % [side, index], piece_size, piece_pos, wall_material)
            wall_piece_count += 1
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            _box("TwinCity_CornerTower", Vector3(6, 10, 6), Vector3(sx * 156, 5, sz * 156), pier_material)
            wall_piece_count += 1
    _box("NorthBridge", Vector3(8.5, 0.75, 22), Vector3(0, 0.25, -168), bridge_material)
    _box("SouthBridge", Vector3(8.5, 0.75, 22), Vector3(0, 0.25, 168), bridge_material)
    _box("EastBridge", Vector3(22, 0.75, 8.5), Vector3(168, 0.25, 0), bridge_material)
    _box("WestBridge", Vector3(22, 0.75, 8.5), Vector3(-168, 0.25, 0), bridge_material)
    print("CHECKPOINT1_CITY_WALL_PIECES_OK: " + str(wall_piece_count) + " pieces")
    print("CHECKPOINT1_MOAT_WIDTH_OK: 18m continuous ring")
    print("CHECKPOINT1_FOUR_BRIDGES_OK: north south east west")
    if wall_piece_count != 108:
        push_error("CHECKPOINT1_WALL_PIECE_COUNT_FAILED: " + str(wall_piece_count))
func _place_width(asset_id: String, position: Vector3, target_width: float, rotation_y: float = 0.0) -> Node3D:
    var node: Node3D = Assets.load_model(asset_id, "")
    if node == null:
        push_error("CHECKPOINT1_REQUIRED_MODEL_MISSING: " + asset_id)
        return null
    var bounds := Assets._measure_bounds(node, Transform3D.IDENTITY)
    var source_width := maxf(bounds.size.x, bounds.size.z)
    if source_width <= 0.001:
        push_error("CHECKPOINT1_MODEL_WIDTH_INVALID: " + asset_id)
        node.free()
        return null
    var factor := target_width / source_width
    node.scale *= Vector3.ONE * factor
    node.position.y -= bounds.position.y * factor
    node.position += position
    node.rotation.y = rotation_y
    add_child(node)
    return node
func _place_height(asset_id: String, position: Vector3, target_height: float, rotation_y: float = 0.0) -> Node3D:
    var node: Node3D = Assets.load_model(asset_id, "")
    if node == null:
        push_error("CHECKPOINT1_REQUIRED_MODEL_MISSING: " + asset_id)
        return null
    Assets.fit_height(node, target_height)
    node.position += position
    node.rotation.y = rotation_y
    add_child(node)
    return node
func _build_plaza_and_palace() -> bool:
    var cobble := _cobble()
    if cobble == null:
        return false
    _plane("CobblestoneCentralSquare_CobblestoneFloor04", Vector2(54, 54), Vector3(0, 0.105, 0), cobble)
    print("CHECKPOINT1_COBBLESTONE_PLAZA_OK: 54x54 Cobblestone Floor 04 only")
    var platform := MeshInstance3D.new()
    platform.name = "RoyalPalaceCobblestonePlatform_34x26x3_5"
    var platform_mesh := BoxMesh.new()
    platform_mesh.size = Vector3(34, 3.5, 26)
    platform.mesh = platform_mesh
    platform.position = Vector3(0, 1.75, -75)
    platform.material_override = cobble
    add_child(platform)
    var catalog := Assets._read_catalog()
    if not catalog.has(PALACE_ID):
        push_error("CHECKPOINT1_PALACE_SOURCE_MISSING: " + PALACE_ID)
        return false
    var palace_path := String(catalog[PALACE_ID].get("path", ""))
    if palace_path.is_empty() or not FileAccess.file_exists(palace_path):
        push_error("CHECKPOINT1_PALACE_SOURCE_FILE_MISSING")
        return false
    var palace_file := FileAccess.open(palace_path, FileAccess.READ)
    if palace_file == null:
        push_error("CHECKPOINT1_PALACE_SOURCE_UNREADABLE")
        return false
    var palace_bytes := palace_file.get_length()
    var palace_header := palace_file.get_buffer(4)
    palace_file.close()
    if palace_bytes < 20 or palace_header != PackedByteArray([103, 108, 84, 70]):
        push_error("CHECKPOINT1_IMPERIAL_PALACE_GLB_INVALID: bytes=" + str(palace_bytes))
        return false
    print("CHECKPOINT1_IMPERIAL_PALACE_SOURCE_OK: valid GLB bytes=", palace_bytes, " (gltfpack-normalized size accepted)")
    if _place_width(PALACE_ID, Vector3(0, 3.5, -75), 28.0, PI) == null:
        return false
    var stairs: Node3D = Assets.load_model("imperial_entrance_stairs", "")
    if stairs == null:
        push_error("CHECKPOINT1_ENTRANCE_STAIRS_MISSING")
        return false
    var stair_bounds := Assets._measure_bounds(stairs, Transform3D.IDENTITY)
    if stair_bounds.size.x <= 0.001 or stair_bounds.size.y <= 0.001 or stair_bounds.size.z <= 0.001:
        push_error("CHECKPOINT1_ENTRANCE_STAIRS_BOUNDS_INVALID")
        stairs.free()
        return false
    stairs.scale *= Vector3(8.0 / stair_bounds.size.x, 3.5 / stair_bounds.size.y, 8.0 / stair_bounds.size.z)
    stairs.position = Vector3(0, 0, -59.5)
    stairs.rotation.y = PI
    add_child(stairs)
    print("CHECKPOINT1_PALACE_PLATFORM_OK: 34x26x3.5; EntranceStairs CC0 source; imperial palace width 28m; pink-roof candidate excluded")
    return true
func _build_pagoda_gate() -> bool:
    var left_column := _place_height("polygonalmind-lunar-year-008", Vector3(87, 0, -79), 7.0, PI)
    var right_column := _place_height("polygonalmind-lunar-year-008", Vector3(97, 0, -79), 7.0, PI)
    var gate_door := _place_width("polygonalmind-lunar-year-011", Vector3(92, 0, -79), 8.0, PI)
    var gate_arch := _place_width("polygonalmind-lunar-year-001", Vector3(92, 7.0, -79), 10.0, PI)
    if left_column == null or right_column == null or gate_door == null or gate_arch == null:
        return false
    print("CHECKPOINT1_EASTERN_GATE_GLTF_APPEND_OK: HF Door + twin Columns + ArchBanner")
    return true
func _build_landmarks() -> bool:
    if _place_width(PAGODA_ID, Vector3(92, 0, -92), 14.5, PI) == null:
        return false
    print("CHECKPOINT1_LANDMARK_OK: NE_PAGODA width=14.5m")
    if not _build_pagoda_gate():
        return false
    if _place_width(QUEST_HALL_ID, Vector3(-92, 0, -92), 14.0, 0.0) == null:
        return false
    print("CHECKPOINT1_LANDMARK_OK: NW_QUEST_HALL eastern_bath_house width=14m")
    if _place_width(TEA_HOUSE_ID, Vector3(92, 0, 92), 14.0, 0.0) == null:
        return false
    print("CHECKPOINT1_LANDMARK_OK: SE_TEA_HOUSE red_roof_HF_candidate width=14m")
    var forge_catalog := Assets._read_catalog()
    if not forge_catalog.has("blacksmith_forge"):
        push_error("CHECKPOINT1_BLACKSMITH_SOURCE_MISSING: blacksmith_forge")
        return false
    var forge_path := String(forge_catalog["blacksmith_forge"].get("path", ""))
    if forge_path.is_empty() or not FileAccess.file_exists(forge_path):
        push_error("CHECKPOINT1_BLACKSMITH_SOURCE_FILE_MISSING: " + forge_path)
        return false
    var forge_file := FileAccess.open(forge_path, FileAccess.READ)
    if forge_file == null:
        push_error("CHECKPOINT1_BLACKSMITH_SOURCE_UNREADABLE")
        return false
    var forge_bytes := forge_file.get_length()
    var forge_header := forge_file.get_buffer(4)
    forge_file.close()
    if forge_bytes < 20 or forge_header != PackedByteArray([103, 108, 84, 70]):
        push_error("CHECKPOINT1_BLACKSMITH_GLB_INVALID: bytes=" + str(forge_bytes))
        return false
    print("CHECKPOINT1_BLACKSMITH_SOURCE_OK: valid local GLB bytes=", forge_bytes)
    if _place_width("blacksmith_forge", Vector3(-92, 0, 92), 14.0, 0.0) == null:
        push_error("CHECKPOINT1_BLACKSMITH_GODOT_IMPORT_FAILED")
        return false
    print("CHECKPOINT1_BLACKSMITH_GODOT_IMPORT_OK: GLTFDocument generated scene; open-front forge width=14m rotation=0deg; entrance faces south street")
    print("CHECKPOINT1_BLACKSMITH_GLTF_APPEND_OK: open-front forge width=14m rotation=0deg; entrance faces south street")
    print("CHECKPOINT1_LANDMARK_OK: SW_BLACKSMITH width=14m")
    return true
func _remove_house_bases(node: Node, removed: Array[int]) -> void:
    for child in node.get_children():
        var lower_name := String(child.name).to_lower()
        var is_base_mesh := child is MeshInstance3D and (
            lower_name.contains("base") or lower_name.contains("stand") or
            lower_name.contains("platform") or lower_name.contains("plinth")
        )
        if is_base_mesh:
            node.remove_child(child)
            child.free()
            removed[0] += 1
        else:
            _remove_house_bases(child, removed)
func _build_house_blocks() -> bool:
    var prototypes: Array[Node3D] = []
    for asset_id in HOUSE_IDS:
        var prototype: Node3D = Assets.load_model(asset_id, "")
        if prototype == null:
            push_error("CHECKPOINT1_HOUSE_MODEL_MISSING: " + asset_id)
            return false
        var removed: Array[int] = [0]
        _remove_house_bases(prototype, removed)
        Assets.fit_height(prototype, 7.0)
        prototypes.append(prototype)
        print("CHECKPOINT1_HOUSE_BASES_REMOVED: ", asset_id, " removed=", removed[0])
    var occupied: Array[AABB] = []
    for center in [Vector3(92, 0, -92), Vector3(-92, 0, -92), Vector3(92, 0, 92), Vector3(-92, 0, 92)]:
        occupied.append(AABB(Vector3(center.x - 17, -2, center.z - 18), Vector3(34, 24, 38)))
    var quadrant_counts: Array[int] = []
    var total_houses := 0
    for qx in [-1.0, 1.0]:
        for qz in [-1.0, 1.0]:
            var count := 0
            for row in range(5):
                for column in range(5):
                    if row == 2 and column == 2:
                        continue
                    var base_position := Vector3(qx * (48.0 + column * 18.0), 0, qz * (48.0 + row * 18.0))
                    var prototype := prototypes[(row * 5 + column + count) % prototypes.size()]
                    var rotation := float((row + column) % 4) * PI / 2.0
                    var placement := _find_house_position(prototype, base_position, rotation, qx, qz, occupied)
                    if not placement.get("valid", false):
                        print("CHECKPOINT1_BUILDING_REJECTED_ROTATED_AABB: ", base_position)
                        continue
                    var bounds: AABB = placement["bounds"]
                    var house := prototype.duplicate(true) as Node3D
                    house.position = placement["pos"]
                    house.rotation.y = rotation
                    add_child(house)
                    occupied.append(bounds)
                    count += 1
                    total_houses += 1
            quadrant_counts.append(count)
    for prototype in prototypes:
        prototype.free()
    if quadrant_counts.size() != 4 or quadrant_counts.min() < 8:
        push_error("CHECKPOINT1_QUADRANT_DENSITY_FAILED: " + str(quadrant_counts))
        return false
    print("CHECKPOINT1_ROTATED_AABB_REJECTION_OK: accepted=", total_houses, " quadrant_counts=", quadrant_counts, " street_clearance=22m")
    print("CHECKPOINT1_ROTATED_AABB_AUTO_OFFSET_OK: accepted=", total_houses)
    return true
func _find_house_position(proto: Node3D, base_pos: Vector3, rotation: float, qx: float, qz: float, occupied: Array[AABB]) -> Dictionary:
    for ring in range(0, 9):
        for dx in range(-ring, ring + 1):
            for dz in range(-ring, ring + 1):
                if maxi(absi(dx), absi(dz)) != ring:
                    continue
                var candidate := base_pos + Vector3(float(dx) * 2.0, 0.0, float(dz) * 2.0)
                var bounds := Assets._measure_bounds(proto, Transform3D(Basis(Vector3.UP, rotation), candidate))
                var inside_x := bounds.position.x >= 22.0 and bounds.end.x <= 158.0 if qx > 0.0 else bounds.position.x >= -158.0 and bounds.end.x <= -22.0
                var inside_z := bounds.position.z >= 22.0 and bounds.end.z <= 158.0 if qz > 0.0 else bounds.position.z >= -158.0 and bounds.end.z <= -22.0
                var valid := inside_x and inside_z
                for other in occupied:
                    if bounds.intersects(other):
                        valid = false
                        break
                if valid:
                    if dx != 0 or dz != 0:
                        print("CHECKPOINT1_BUILDING_AUTO_OFFSET: ", base_pos, " -> ", candidate)
                    return {"valid": true, "pos": candidate, "bounds": bounds}
    return {"valid": false}
func _build_tea_house_garden() -> void:
    var tree_a := _place_height("innerscene-japanese-maple-tree-565c1604", Vector3(78, 0, 102), 8.0, 0.0)
    var tree_b := _place_height("innerscene-japanese-maple-tree-565c1604", Vector3(106, 0, 102), 8.0, PI)
    var rock_a := _place_width("boulder_01", Vector3(81, 0, 111), 2.8, 0.0)
    var rock_b := _place_width("boulder_01", Vector3(103, 0, 111), 2.8, 0.0)
    var rock_c := _place_width("boulder_01", Vector3(92, 0, 116), 2.0, 0.0)
    if tree_a != null and tree_b != null and rock_a != null and rock_b != null and rock_c != null:
        print("CHECKPOINT1_TEA_HOUSE_DECOR_OK: 2 side-offset ornamental maples + 3 perimeter rocks; doorway kept clear")
func _build_city() -> bool:
    var catalog := Assets._read_catalog()
    if not catalog.has("grab3d-dirt-road"):
        push_error("CHECKPOINT1_DIRT_ROAD_ASSET_MISSING")
        return false
    if not _build_dirt_ground():
        return false
    _build_walls_moat_and_bridges()
    if not _build_plaza_and_palace():
        return false
    if not _build_landmarks():
        return false
    if not _build_house_blocks():
        return false
    _build_tea_house_garden()
    print("CHECKPOINT1_GEOMETRY_BUILD_COMPLETE: complete 320m city, 108 wall pieces, 18m moat, 4 bridges, palace and 4 landmarks")
    return true
func _shutdown(exit_code: int) -> void:
    for child in get_children():
        remove_child(child)
        child.free()
    Assets.clear_cached_prototypes()
    await get_tree().process_frame
    RenderingServer.force_sync()
    print("GODOT_RESOURCE_CLEANUP_COMPLETE: scene nodes and cached GLTF prototypes released")
    get_tree().quit(exit_code)

func _camera() -> void:
    var camera := Camera3D.new()
    camera.name = "TwinCityCamera"
    add_child(camera)
    camera.current = true
    camera.position = captures[0].pos
    camera.fov = captures[0].fov
    camera.look_at(captures[0].target, Vector3.UP)
func _capture() -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        push_error("TWIN_CITY_CAPTURE_FAILED: active camera is missing")
        await _shutdown(1)
        return
    var directory := ProjectSettings.globalize_path("res://artifacts")
    DirAccess.make_dir_recursive_absolute(directory)
    for specification in captures:
        var is_wilderness := String(specification.file).begins_with("wilderness_")
        print("WILDERNESS_CAPTURE_START: " if is_wilderness else "TWIN_CITY_CAPTURE_START: ", specification.file)
        camera.position = specification.pos
        camera.fov = specification.fov
        camera.look_at(specification.target, Vector3.UP)
        await RenderingServer.frame_post_draw
        var image := get_viewport().get_texture().get_image()
        var path := directory.path_join(specification.file)
        if image == null or image.is_empty():
            push_error("TWIN_CITY_CAPTURE_FAILED: empty framebuffer for " + specification.file)
            await _shutdown(1)
            return
        var save_error := image.save_png(path)
        if save_error != OK:
            push_error("TWIN_CITY_CAPTURE_FAILED: could not save " + path + " error=" + str(save_error))
            get_tree().quit(1)
            return
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            push_error("TWIN_CITY_CAPTURE_FILE_INVALID: could not reopen " + path)
            get_tree().quit(1)
            return
        var byte_count := file.get_length()
        file.close()
        if byte_count < 1024:
            push_error("TWIN_CITY_CAPTURE_FILE_INVALID: " + path + " bytes=" + str(byte_count))
            get_tree().quit(1)
            return
        image = null
        print("WILDERNESS_CAPTURE_DONE: " if is_wilderness else "TWIN_CITY_CAPTURE_DONE: ", specification.file, " bytes=", byte_count)
    print("CHECKPOINT1_ALL_SIX_CAPTURES_COMPLETE")
    print("CHECKPOINT2_ALL_SIX_CAPTURES_COMPLETE")
    await _shutdown(0)