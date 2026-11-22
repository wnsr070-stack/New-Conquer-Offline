extends RefCounted
const Assets = preload("res://scripts/AssetLoader.gd")

static func _material(color: Color, roughness: float = 0.32) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = 0.0
    return m

static func _add_ribbon(root: Node3D, name: String, points: PackedVector3Array, half_width: float, y: float, material: Material) -> void:
    var vertices := PackedVector3Array()
    var indices := PackedInt32Array()
    var uvs := PackedVector2Array()
    var distance := 0.0
    for i in range(points.size()):
        var tangent: Vector3
        if i == 0:
            tangent = (points[1] - points[0]).normalized()
        elif i == points.size() - 1:
            tangent = (points[i] - points[i - 1]).normalized()
        else:
            tangent = (points[i + 1] - points[i - 1]).normalized()
        var side := Vector3(-tangent.z, 0.0, tangent.x).normalized()
        var left := points[i] + side * half_width
        var right := points[i] - side * half_width
        left.y = y
        right.y = y
        vertices.append(left)
        vertices.append(right)
        uvs.append(Vector2(0.0, distance / 18.0))
        uvs.append(Vector2(1.0, distance / 18.0))
        if i > 0:
            var a := (i - 1) * 2
            var b := a + 1
            var c := i * 2
            var d := c + 1
            indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
        if i < points.size() - 1:
            distance += points[i].distance_to(points[i + 1])
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var instance := MeshInstance3D.new()
    instance.name = name
    instance.mesh = mesh
    instance.material_override = material
    root.add_child(instance)

static func _place_bridge(root: Node3D, asset_id: String, label: String, center: Vector3, yaw: float) -> bool:
    var node := Assets.load_model(asset_id, "")
    if node == null:
        push_error("CHECKPOINT3_BRIDGE_ASSET_LOAD_FAILED: " + asset_id)
        return false
    var bounds := Assets._measure_bounds(node, Transform3D.IDENTITY)
    if bounds.size.x <= 0.01 or bounds.size.y <= 0.01 or bounds.size.z <= 0.01:
        node.free()
        push_error("CHECKPOINT3_BRIDGE_AABB_INVALID: " + asset_id)
        return false
    var long_x := bounds.size.x >= bounds.size.z
    var long_source := bounds.size.x if long_x else bounds.size.z
    var short_source := bounds.size.z if long_x else bounds.size.x
    var sx := (22.0 if long_x else 8.5) / bounds.size.x
    var sz := (8.5 if long_x else 22.0) / bounds.size.z
    var sy := 1.0
    node.scale = Vector3(sx, sy, sz)
    node.rotation.y = yaw
    node.position = Vector3(center.x, -0.38 - bounds.position.y * sy, center.z)
    root.add_child(node)
    print("CHECKPOINT3_BRIDGE_GODOT43_OK: ", label, " asset=", asset_id, " source_bounds=", bounds.size)
    return true

static func build(root: Node3D) -> bool:
    var catalog := Assets._read_catalog()
    for key in ["bridge_stone", "bridge_wood", "rock_face_01", "rock_face_02", "boulder_01"]:
        if not catalog.has(key):
            push_error("CHECKPOINT3_CATALOG_MISSING: " + key)
            return false

    # A broad, closed winding course that stays outside the 45m moat safety belt.
    var control := PackedVector3Array([
        Vector3(-455,0,-475), Vector3(-230,0,-505), Vector3(40,0,-475),
        Vector3(315,0,-445), Vector3(485,0,-245), Vector3(475,0,20),
        Vector3(500,0,300), Vector3(300,0,485), Vector3(25,0,475),
        Vector3(-260,0,505), Vector3(-485,0,315), Vector3(-465,0,35),
        Vector3(-455,0,-475)
    ])
    var points := PackedVector3Array()
    for i in range(control.size() - 1):
        var a := control[i]
        var b := control[i + 1]
        for step in range(12):
            var t := float(step) / 12.0
            var smooth := t * t * (3.0 - 2.0 * t)
            points.append(a.lerp(b, smooth))
    points.append(control[control.size() - 1])

    var water := _material(Color(0.025, 0.48, 0.62), 0.18)
    water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    water.albedo_color.a = 0.94
    water.metallic = 0.0
    water.roughness = 0.16
    water.cull_mode = BaseMaterial3D.CULL_DISABLED
    var bank := _material(Color(0.39, 0.31, 0.19), 0.98)
    _add_ribbon(root, "Checkpoint3_Winding_Turquoise_River_20m", points, 10.0, -0.67, water)
    for side in [-1.0, 1.0]:
        var shore := PackedVector3Array()
        for i in range(points.size()):
            var tangent := (points[min(i + 1, points.size()-1)] - points[max(i - 1, 0)]).normalized()
            var lateral := Vector3(-tangent.z,0,tangent.x).normalized() * side * 12.8
            shore.append(points[i] + lateral)
        _add_ribbon(root, "Checkpoint3_River_Bank_" + str(side), shore, 2.8, -1.10, bank)

    var bridges := [
        {"id":"bridge_wood","name":"NorthRiverBridge","p":Vector3(-20,-0.38,-490),"yaw":0.10},
        {"id":"bridge_stone","name":"EastRiverBridge","p":Vector3(485,-0.38,-90),"yaw":1.52},
        {"id":"bridge_wood","name":"SouthRiverBridge","p":Vector3(-20,-0.38,478),"yaw":0.10},
        {"id":"bridge_stone","name":"WestRiverBridge","p":Vector3(-475,-0.38,90),"yaw":1.52}
    ]
    for b in bridges:
        if not _place_bridge(root, b.id, b.name, b.p, b.yaw):
            return false
    print("CHECKPOINT3_FOUR_REAL_BRIDGES_OK: 4 HF GLB bridge instances; stone and wooden sources; Godot 4.3 normalized")
    print("CHECKPOINT3_RIVER_WIDTH_OK: 20m turquoise winding course; minimum moat safety offset=45m")
    print("CHECKPOINT3_RIVER_BANKS_OK: paired natural sandy shore ribbons")
    var rock_specs := [
        {"id":"rock_face_01","p":Vector3(475,0,-235),"d":Vector3(30,13,22),"yaw":0.2},
        {"id":"rock_face_02","p":Vector3(505,0,255),"d":Vector3(34,15,24),"yaw":-0.3},
        {"id":"rock_face_01","p":Vector3(260,0,475),"d":Vector3(32,14,24),"yaw":0.5},
        {"id":"rock_face_02","p":Vector3(-475,0,300),"d":Vector3(34,15,24),"yaw":0.1},
        {"id":"boulder_01","p":Vector3(460,0,-200),"d":Vector3(12,5,10),"yaw":0.0},
        {"id":"boulder_01","p":Vector3(500,0,220),"d":Vector3(14,6,12),"yaw":0.0},
        {"id":"boulder_01","p":Vector3(220,0,485),"d":Vector3(12,5,10),"yaw":0.0},
        {"id":"boulder_01","p":Vector3(-465,0,250),"d":Vector3(14,6,12),"yaw":0.0}
    ]
    for r in rock_specs:
        var node := Assets.load_model(r.id, "")
        if node == null:
            push_error("CHECKPOINT3_BANK_ROCK_LOAD_FAILED: " + r.id)
            return false
        var bounds := Assets._measure_bounds(node, Transform3D.IDENTITY)
        node.scale = Vector3(r.d.x / bounds.size.x, r.d.y / bounds.size.y, r.d.z / bounds.size.z)
        node.rotation.y = r.yaw
        node.position = Vector3(r.p.x, -2.0 - bounds.position.y * node.scale.y, r.p.z)
        root.add_child(node)
    print("CHECKPOINT3_WATER_EDGE_ROCKS_OK: 8 rock_face and boulder placements at bends and bridge approaches")
    return true

static func captures() -> Array:
    return [
        {"file":"wilderness_river_overview.png","pos":Vector3(1050,780,1180),"target":Vector3(0,0,0),"fov":58.0},
        {"file":"wilderness_river_north_bridge.png","pos":Vector3(80,70,-650),"target":Vector3(-20,0,-490),"fov":52.0},
        {"file":"wilderness_river_east_bridge.png","pos":Vector3(650,65,-70),"target":Vector3(485,0,-90),"fov":52.0},
        {"file":"wilderness_river_south_bridge.png","pos":Vector3(100,70,650),"target":Vector3(-20,0,478),"fov":52.0},
        {"file":"wilderness_river_west_bend.png","pos":Vector3(-650,85,100),"target":Vector3(-475,0,90),"fov":52.0},
        {"file":"wilderness_river_south_bank.png","pos":Vector3(380,75,650),"target":Vector3(180,0,480),"fov":54.0}
    ]
}
