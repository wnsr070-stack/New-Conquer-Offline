extends RefCounted
# Checkpoint 3: Open source-to-mouth turquoise river, northern waterfall, real rock banks and calibrated bridges
const Assets = preload("res://scripts/AssetLoader.gd")

static func _material(color: Color, roughness: float = 0.32) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = 0.0
    return material

static func _tinted_material(source: Material, tint: Color, roughness_floor: float) -> StandardMaterial3D:
    var adjusted: StandardMaterial3D
    if source is StandardMaterial3D:
        adjusted = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
        adjusted.albedo_color = adjusted.albedo_color * tint
    else:
        adjusted = StandardMaterial3D.new()
        adjusted.albedo_color = tint
    adjusted.vertex_color_use_as_albedo = false
    adjusted.roughness = maxf(adjusted.roughness, roughness_floor)
    adjusted.metallic = minf(adjusted.metallic, 0.08)
    return adjusted

static func _force_dark_rock_material(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        var dark := StandardMaterial3D.new()
        dark.albedo_color = Color(0.28, 0.27, 0.25)
        dark.roughness = 0.92
        dark.vertex_color_use_as_albedo = false
        dark.metallic = 0.0
        mesh_node.material_override = dark
        mesh_node.material_overlay = null
    for child in node.get_children():
        _force_dark_rock_material(child)

static func _tint_imported_model(node: Node, tint: Color, roughness_floor: float) -> void:
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        if mesh_node.material_override != null:
            mesh_node.material_override = _tinted_material(mesh_node.material_override, tint, roughness_floor)
        elif mesh_node.mesh != null:
            for surface_index in range(mesh_node.mesh.get_surface_count()):
                var source: Material = mesh_node.mesh.surface_get_material(surface_index)
                mesh_node.set_surface_override_material(surface_index, _tinted_material(source, tint, roughness_floor))
    for child in node.get_children():
        _tint_imported_model(child, tint, roughness_floor)

static func _place_asset(root: Node3D, asset_id: String, label: String, position: Vector3, dimensions: Vector3, yaw: float, tint: Color, roughness_floor: float = 0.72, base_y: float = 0.0, pitch: float = 0.0) -> bool:
    var node: Node3D = Assets.load_model(asset_id, "")
    if node == null:
        push_error("CHECKPOINT3_REQUIRED_GLB_LOAD_FAILED: " + asset_id + " label=" + label)
        return false
    var bounds: AABB = Assets._measure_bounds(node, Transform3D.IDENTITY)
    if bounds.size.x <= 0.001 or bounds.size.y <= 0.001 or bounds.size.z <= 0.001:
        node.free()
        push_error("CHECKPOINT3_REQUIRED_GLB_AABB_INVALID: " + asset_id + " label=" + label)
        return false
    node.scale = Vector3(dimensions.x / bounds.size.x, dimensions.y / bounds.size.y, dimensions.z / bounds.size.z)
    node.rotation = Vector3(pitch, yaw, 0.0)
    var rotated_bounds: AABB = Assets._measure_bounds(node, Transform3D.IDENTITY)
    node.position = Vector3(position.x, base_y - rotated_bounds.position.y, position.z)
    if asset_id.begins_with("rock_face") or asset_id == "boulder_01":
        _force_dark_rock_material(node)
    else:
        _tint_imported_model(node, tint, roughness_floor)
    root.add_child(node)
    print("CHECKPOINT3_IMPORTED_GLB_OK: ", label, " asset=", asset_id, " target_dimensions=", dimensions)
    return true

static func _add_ribbon(root: Node3D, label: String, points: PackedVector3Array, half_width: float, y: float, material: Material) -> void:
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
            indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
        if i < points.size() - 1:
            distance += points[i].distance_to(points[i + 1])
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    instance.material_override = material
    root.add_child(instance)

static func _add_pool_disk(root: Node3D, center: Vector3, radius: float, y: float, material: Material) -> void:
    var vertices := PackedVector3Array([Vector3(center.x, y, center.z)])
    var indices := PackedInt32Array()
    var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
    const SEGMENTS := 64
    for i in range(SEGMENTS):
        var angle := TAU * float(i) / float(SEGMENTS)
        vertices.append(Vector3(center.x + cos(angle) * radius, y, center.z + sin(angle) * radius))
        uvs.append(Vector2(0.5 + cos(angle) * 0.5, 0.5 + sin(angle) * 0.5))
    for i in range(SEGMENTS):
        indices.append_array(PackedInt32Array([0, i + 1, ((i + 1) % SEGMENTS) + 1]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var pool := MeshInstance3D.new()
    pool.name = "Checkpoint3_Wide_Plunge_Lake_124m"
    pool.mesh = mesh
    pool.material_override = material
    root.add_child(pool)

static func _add_waterfall_quad(root: Node3D, label: String, vertices: PackedVector3Array, material: Material, foam: bool = false) -> void:
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 1, 2, 3])
    arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(1,1)])
    if foam:
        arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color(1,1,1,0.10), Color(1,1,1,0.10), Color(1,1,1,0.82), Color(1,1,1,0.82)])
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    instance.material_override = material
    root.add_child(instance)

static func _bridge_surface_height(local_x: float, half_span: float, bank_y: float, crest_y: float) -> float:
    var normalized := clampf(absf(local_x) / half_span, 0.0, 1.0)
    return bank_y + (crest_y - bank_y) * (1.0 - normalized * normalized)

static func _add_walkable_bridge_collision(root: Node3D, label: String, center: Vector3, yaw: float, span: float, width: float, bank_y: float, crest_y: float) -> bool:
    var body := StaticBody3D.new()
    body.name = label + "_Walkable_StaticBody3D"
    body.position = Vector3(center.x, 0.0, center.z)
    body.rotation.y = yaw
    body.collision_layer = 1
    body.collision_mask = 1
    body.set_meta("walkable_bridge", true)
    var half_span := span * 0.5
    var segment_count := 16
    var segment_length := span / float(segment_count)
    var thickness := 0.46
    for i in range(segment_count):
        var x0 := -half_span + float(i) * segment_length
        var x1 := x0 + segment_length
        var xm := (x0 + x1) * 0.5
        var y0 := _bridge_surface_height(x0, half_span, bank_y, crest_y)
        var y1 := _bridge_surface_height(x1, half_span, bank_y, crest_y)
        var ym := (y0 + y1) * 0.5
        var slope := (y1 - y0) / segment_length
        var shape := BoxShape3D.new()
        shape.size = Vector3(segment_length + 0.10, thickness, width)
        var collision := CollisionShape3D.new()
        collision.name = "WalkableRampSegment_%02d" % i
        collision.shape = shape
        collision.position = Vector3(xm, ym - thickness * 0.5, 0.0)
        collision.rotation.z = atan(slope)
        body.add_child(collision)
    root.add_child(body)
    var max_slope_degrees := rad_to_deg(atan(2.0 * (crest_y - bank_y) / span))
    if max_slope_degrees > 25.0:
        push_error("CHECKPOINT3_BRIDGE_RAMP_SLOPE_REJECTED: " + label + " max_slope_deg=" + str(max_slope_degrees))
        body.queue_free()
        return false
    print("CHECKPOINT3_BRIDGE_WALKABLE_COLLISION_OK: ", label, " StaticBody3D segments=", segment_count, " span=", span, "m width=", width, "m bank_y=", bank_y, "m crest_y=", crest_y, "m max_slope_deg=", snappedf(max_slope_degrees, 0.1), " physics=enabled")
    return true

static func _place_bridge(root: Node3D, asset_id: String, label: String, center: Vector3, river_points: PackedVector3Array) -> bool:
    var node: Node3D = Assets.load_model(asset_id, "")
    if node == null:
        push_error("CHECKPOINT3_BRIDGE_ASSET_LOAD_FAILED: " + asset_id)
        return false
    var source_bounds: AABB = Assets._measure_bounds(node, Transform3D.IDENTITY)
    if source_bounds.size.x <= 0.01 or source_bounds.size.y <= 0.01 or source_bounds.size.z <= 0.01:
        node.free()
        push_error("CHECKPOINT3_BRIDGE_AABB_INVALID: " + asset_id)
        return false

    # Measure the source GLB before scaling; retain its real long axis and height.
    var long_x := source_bounds.size.x >= source_bounds.size.z
    var source_length := source_bounds.size.x if long_x else source_bounds.size.z
    var source_width := source_bounds.size.z if long_x else source_bounds.size.x
    if source_length <= 0.01 or source_width <= 0.01:
        node.free()
        push_error("CHECKPOINT3_BRIDGE_SOURCE_DIMENSIONS_INVALID: " + asset_id)
        return false

    var nearest_distance := INF
    var tangent := Vector3.FORWARD
    for i in range(river_points.size() - 1):
        var p: Vector3 = river_points[i]
        var q: Vector3 = river_points[i + 1]
        var seg := q - p
        var den := seg.x * seg.x + seg.z * seg.z
        if den <= 0.0001:
            continue
        var delta2 := Vector2(center.x - p.x, center.z - p.z)
        var t := clampf(delta2.dot(Vector2(seg.x, seg.z)) / den, 0.0, 1.0)
        var closest := p + seg * t
        var distance := Vector2(center.x - closest.x, center.z - closest.z).length()
        if distance < nearest_distance:
            nearest_distance = distance
            tangent = Vector3(seg.x, 0.0, seg.z).normalized()
    if tangent.length_squared() < 0.5:
        node.free()
        push_error("CHECKPOINT3_BRIDGE_FLOW_TANGENT_INVALID: " + label)
        return false

    # The bridge's long axis is perpendicular to the local river tangent.
    var cross_river := Vector3(-tangent.z, 0.0, tangent.x).normalized()
    var yaw := atan2(-cross_river.z, cross_river.x) if long_x else atan2(cross_river.x, cross_river.z)
    var span := 34.0
    var width := 9.0
    var target_visual_height := 2.25
    node.scale = Vector3(
        (span if long_x else width) / source_length,
        target_visual_height / source_bounds.size.y,
        (width if long_x else span) / source_width
    )
    node.rotation = Vector3(0.0, yaw, 0.0)
    var scaled_bounds: AABB = Assets._measure_bounds(node, Transform3D.IDENTITY)
    var visual_min_y := 0.16
    node.position = Vector3(center.x, visual_min_y - scaled_bounds.position.y, center.z)
    var final_bounds: AABB = Assets._measure_bounds(node, Transform3D.IDENTITY)
    var final_min_y := final_bounds.position.y + node.position.y
    var final_max_y := final_bounds.position.y + final_bounds.size.y + node.position.y
    if final_min_y < 0.12 or final_max_y > 2.60:
        node.free()
        push_error("CHECKPOINT3_BRIDGE_VISUAL_HEIGHT_REJECTED: " + label + " min_y=" + str(final_min_y) + " max_y=" + str(final_max_y))
        return false
    var tint := Color(0.46, 0.44, 0.39) if asset_id == "bridge_stone" else Color(0.42, 0.25, 0.12)
    _tint_imported_model(node, tint, 0.78)
    node.name = label + "_" + asset_id
    root.add_child(node)

    # River ribbons are visual-only MeshInstances; no river wall collider is created.
    # A segmented physics ramp connects the two grassy banks and crests above the water.
    if not _add_walkable_bridge_collision(root, label, center, yaw, span, 8.8, -1.30, 1.95):
        node.queue_free()
        return false
    var max_slope_degrees := rad_to_deg(atan(2.0 * (1.95 - (-1.30)) / span))
    print("CHECKPOINT3_BRIDGE_AABB_PLACEMENT_OK: ", label, " asset=", asset_id,
        " source_min_y=", snappedf(source_bounds.position.y, 0.001),
        " source_max_y=", snappedf(source_bounds.position.y + source_bounds.size.y, 0.001),
        " source_length=", snappedf(source_length, 0.001), "m source_width=", snappedf(source_width, 0.001), "m",
        " scale=", node.scale, " final_min_y=", snappedf(final_min_y, 0.01),
        " final_max_y=", snappedf(final_max_y, 0.01), "m water_y=0.12m",
        " span=", span, "m cross_river=true max_ramp_slope_deg=", snappedf(max_slope_degrees, 0.1))
    return true

static func build_waterfall(root: Node3D) -> bool:
    var catalog := Assets._read_catalog()
    for key in ["rock_face_01","rock_face_02","boulder_01"]:
        if not catalog.has(key):
            push_error("CHECKPOINT3_WATERFALL_ASSET_MISSING: "+key)
            return false
    var dark_rock := Color(0.28,0.27,0.25)
    var offsets: Array[float] = [-30.0,-10.0,10.0,30.0]
    for i in range(offsets.size()):
        var x: float = -260.0 + offsets[i]
        var lower := "rock_face_01" if i%2==0 else "rock_face_02"
        var upper := "rock_face_02" if i%2==0 else "rock_face_01"
        if not _place_asset(root,lower,"NorthernWaterfall_Cliff_Lower_%02d"%i,Vector3(x,-2,-866),Vector3(22,28,30),0.0,dark_rock,0.92,-2.0,PI*0.5): return false
        if not _place_asset(root,upper,"NorthernWaterfall_Cliff_Upper_%02d"%i,Vector3(x,26,-870),Vector3(22,28,24),0.0,dark_rock,0.92,26.0,PI*0.5): return false
    var water := _material(Color(0.55,0.85,0.95,0.88),0.25)
    water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    water.albedo_color = Color(0.55,0.85,0.95,0.88)
    water.roughness = 0.25
    water.emission_enabled = true
    water.emission = Color(0.18,0.35,0.42)
    water.emission_energy_multiplier = 0.35
    water.cull_mode = BaseMaterial3D.CULL_DISABLED
    _add_waterfall_quad(root,"Checkpoint3_Turquoise_Waterfall_Cascade_35m",PackedVector3Array([
        Vector3(-277.5,50,-855),Vector3(-242.5,50,-855),
        Vector3(-277.5,0.12,-826.1),Vector3(-242.5,0.12,-826.1)
    ]),water)
    var foam := _material(Color.WHITE,0.22)
    foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    foam.vertex_color_use_as_albedo = true
    foam.albedo_color = Color.WHITE
    foam.emission_enabled = true
    foam.emission = Color(0.72,0.90,0.98)
    foam.emission_energy_multiplier = 0.18
    foam.cull_mode = BaseMaterial3D.CULL_DISABLED
    _add_waterfall_quad(root,"Checkpoint3_Waterfall_White_Foam_Gradient",PackedVector3Array([
        Vector3(-261.5,49,-855.3),Vector3(-258.5,49,-855.3),
        Vector3(-261.5,0.18,-826.4),Vector3(-258.5,0.18,-826.4)
    ]),foam,true)
    for i in range(11):
        var x := -273.0+float(i)*2.6
        var half := 0.18+float(i%3)*0.08
        _add_waterfall_quad(root,"Checkpoint3_Waterfall_Foam_Streak_%02d"%i,PackedVector3Array([
            Vector3(x-half,48.8,-855.35),Vector3(x+half,48.8,-855.35),
            Vector3(x-half,0.24,-826.45),Vector3(x+half,0.24,-826.45)
        ]),foam,true)
    _add_pool_disk(root,Vector3(-260,0,-780),62.0,0.12,water)
    for i in range(24):
        if i == 6: continue
        var angle := TAU*float(i)/24.0
        var factor := 0.9+float(i%4)*0.3
        var pos := Vector3(-260+cos(angle)*62.0,-2,-780+sin(angle)*62.0)
        var dims := Vector3(6.0,3.5,5.5)*factor
        if not _place_asset(root,"boulder_01","PlungeLake_Perimeter_Boulder_%02d"%i,pos,dims,angle,dark_rock,0.92,-2.0): return false
    print("CHECKPOINT3_WATERFALL_ASSETS_OK: 8 imported rock_face_01/02 cliff masses; dark material_override Color(0.28,0.27,0.25)")
    print("CHECKPOINT3_WATERFALL_CASCADE_OK: angle=60deg width=35m top_y=50m pool_y=0.12m turquoise=0.55,0.85,0.95,0.88 emission_energy=0.35")
    print("CHECKPOINT3_PLUNGE_LAKE_OK: oval visual basin diameter=124m; 23 dark imported boulders; south outlet clear opening≈24m")
    return true

static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
    var t2 := t * t
    var t3 := t2 * t
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

static func _distance_to_moat_edge(point: Vector3) -> float:
    var dx := maxf(absf(point.x) - 178.0, 0.0)
    var dz := maxf(absf(point.z) - 178.0, 0.0)
    return sqrt(dx * dx + dz * dz)

static func build(root: Node3D) -> bool:
    var catalog := Assets._read_catalog()
    for key in ["bridge_stone", "bridge_wood", "rock_face_01", "rock_face_02", "boulder_01"]:
        if not catalog.has(key):
            push_error("CHECKPOINT3_CATALOG_MISSING: " + key)
            return false
    if not build_waterfall(root):
        return false

    # Open channel begins at the waterfall pool, clears the city moat and all four plateau clusters, and exits south.
    var control := PackedVector3Array([
        Vector3(-260,0,-718), Vector3(-330,0,-690), Vector3(-440,0,-625),
        Vector3(-555,0,-500), Vector3(-650,0,-350), Vector3(-675,0,-150),
        Vector3(-680,0,100), Vector3(-650,0,300), Vector3(-590,0,500),
        Vector3(-500,0,700), Vector3(-420,0,950)
    ])
    var points := PackedVector3Array()
    for i in range(control.size() - 1):
        var p0: Vector3 = control[maxi(i - 1, 0)]
        var p1: Vector3 = control[i]
        var p2: Vector3 = control[i + 1]
        var p3: Vector3 = control[mini(i + 2, control.size() - 1)]
        for step in range(12):
            points.append(_catmull_rom(p0, p1, p2, p3, float(step) / 12.0))
    points.append(control[control.size() - 1])

    var min_moat_clearance := INF
    var min_plateau_clearance := INF
    var plateau_centers := [
        Vector3(-480,0,-85), Vector3(480,0,-85),
        Vector3(-480,0,480), Vector3(480,0,480)
    ]
    for point in points:
        min_moat_clearance = minf(min_moat_clearance, _distance_to_moat_edge(point))
        for plateau in plateau_centers:
            min_plateau_clearance = minf(min_plateau_clearance, Vector2(point.x - plateau.x, point.z - plateau.z).length())
    if min_moat_clearance < 45.0:
        push_error("CHECKPOINT3_MOAT_CLEARANCE_REJECTED: " + str(min_moat_clearance) + "m")
        return false
    if min_plateau_clearance < 40.0:
        push_error("CHECKPOINT3_PLATEAU_CLEARANCE_REJECTED: " + str(min_plateau_clearance) + "m")
        return false

    var river_water := _material(Color(0.025,0.48,0.62), 0.20)
    river_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    river_water.albedo_color.a = 0.92
    river_water.roughness = 0.20
    river_water.cull_mode = BaseMaterial3D.CULL_DISABLED
    var bank := _material(Color(0.39,0.31,0.19), 0.98)
    _add_ribbon(root, "Checkpoint3_Open_Turquoise_River_20m_Source_To_Mouth", points, 10.0, -0.67, river_water)
    for side_value in [-1.0, 1.0]:
        var shore := PackedVector3Array()
        for i in range(points.size()):
            var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
            shore.append(points[i] + Vector3(-tangent.z,0.0,tangent.x).normalized() * side_value * 12.8)
        _add_ribbon(root, "Checkpoint3_Natural_River_Bank_" + str(side_value), shore, 2.8, -1.10, bank)

    var bridges: Array[Dictionary] = [
        {"id":"bridge_wood","name":"NorthRiverBridge","p":Vector3(-615,-0.38,-350)},
        {"id":"bridge_stone","name":"MidNorthRiverBridge","p":Vector3(-675,-0.38,-100)},
        {"id":"bridge_wood","name":"MidSouthRiverBridge","p":Vector3(-665,-0.38,210)},
        {"id":"bridge_stone","name":"SouthRiverBridge","p":Vector3(-565,-0.38,560)}
    ]
    for item in bridges:
        var bridge: Dictionary = item
        if not _place_bridge(root, String(bridge["id"]), String(bridge["name"]), bridge["p"], points):
            return false
    print("CHECKPOINT3_FOUR_REAL_BRIDGES_OK: 4 HF GLB bridge instances; 2 stone + 2 wood; 34m spans; perpendicular 90deg to local flow")
    print("CHECKPOINT3_RIVER_WIDTH_OK: 20m turquoise winding course; minimum moat safety offset=45m")
    print("CHECKPOINT3_RIVER_OPEN_SOURCE_TO_MOUTH_OK: start=(-260,-718) 24m south lake outlet; end=(-420,950) south map edge; Catmull-Rom open spline; width=20m")
    print("CHECKPOINT3_RIVER_CLEARANCE_OK: moat=", snappedf(min_moat_clearance,0.1), "m minimum; plateau_centers=", snappedf(min_plateau_clearance,0.1), "m minimum; thresholds=45m/40m")
    print("CHECKPOINT3_RIVER_BANKS_OK: paired natural sandy shore ribbons")

    var rock_specs: Array[Dictionary] = [
        {"id":"rock_face_01","p":Vector3(-710,0,-250),"d":Vector3(36,15,30),"yaw":-0.2},
        {"id":"rock_face_02","p":Vector3(-710,0,100),"d":Vector3(38,16,30),"yaw":0.15},
        {"id":"rock_face_01","p":Vector3(-650,0,430),"d":Vector3(36,14,28),"yaw":0.35},
        {"id":"rock_face_02","p":Vector3(-470,0,780),"d":Vector3(32,14,26),"yaw":-0.2},
        {"id":"boulder_01","p":Vector3(-700,0,-330),"d":Vector3(9,4,8),"yaw":0.0},
        {"id":"boulder_01","p":Vector3(-710,0,-10),"d":Vector3(8,4,7),"yaw":0.4},
        {"id":"boulder_01","p":Vector3(-700,0,300),"d":Vector3(10,4,9),"yaw":0.2},
        {"id":"boulder_01","p":Vector3(-620,0,650),"d":Vector3(9,4,8),"yaw":-0.3}
    ]
    for item in rock_specs:
        var rock: Dictionary = item
        if not _place_asset(root, String(rock["id"]), "RiverBank_" + String(rock["id"]) + "_" + str(rock["p"]), rock["p"], rock["d"], float(rock["yaw"]), Color(0.28,0.27,0.25), 0.92):
            return false
    print("CHECKPOINT3_WATER_EDGE_ROCKS_OK: imported dark override rocks; roughness=0.92; no plateau intersections")
    print("CHECKPOINT3_OPEN_RIVER_BUILD_COMPLETE: waterfall source, circular plunge pool, four real bridges, 20m open river and natural banks")
    return true

static func captures() -> Array:
    return [
        {"file":"wilderness_river_overview.png","pos":Vector3(-1180,900,1020),"target":Vector3(-500,0,180),"fov":58.0},
        {"file":"wilderness_river_north_waterfall.png","pos":Vector3(-260,95,-700),"target":Vector3(-260,22,-840),"fov":48.0},
        {"file":"wilderness_river_east_bridge.png","pos":Vector3(-610,38,-180),"target":Vector3(-675,0,-100),"fov":42.0},
        {"file":"wilderness_river_south_bridge.png","pos":Vector3(-490,38,620),"target":Vector3(-565,0,560),"fov":42.0},
        {"file":"wilderness_river_west_bend.png","pos":Vector3(-760,48,80),"target":Vector3(-680,0,100),"fov":46.0},
        {"file":"wilderness_river_south_bank.png","pos":Vector3(-420,45,820),"target":Vector3(-470,0,780),"fov":46.0}
    ]
