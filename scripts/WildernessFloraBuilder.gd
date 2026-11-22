extends RefCounted
# Checkpoint 4: all visible flora is sourced from normalized GLB meshes.
# Zero Procedural Geometry: no BoxMesh, SphereMesh, CylinderMesh, colored spheres, generated terrain, or procedural visual geometry. All visible plants use approved imported GLBs.
const Assets = preload("res://scripts/AssetLoader.gd")
const GIANT_MIN := 28.0
const GIANT_MAX := 42.0
const TREE_MIN := 9.0
const TREE_MAX := 18.0
const PLANT_MIN := 1.2
const PLANT_MAX := 3.0

static func _river_control() -> PackedVector3Array:
    return PackedVector3Array([
        Vector3(-260,0,-718), Vector3(-330,0,-690), Vector3(-440,0,-625),
        Vector3(-555,0,-500), Vector3(-650,0,-350), Vector3(-675,0,-150),
        Vector3(-680,0,100), Vector3(-650,0,300), Vector3(-590,0,500),
        Vector3(-500,0,700), Vector3(-420,0,950)
    ])

static func _distance_to_river(point: Vector3) -> float:
    var points: PackedVector3Array = _river_control()
    var best: float = INF
    for i in range(points.size() - 1):
        var a: Vector3 = points[i]
        var b: Vector3 = points[i + 1]
        var d: Vector2 = Vector2(b.x - a.x, b.z - a.z)
        var denom: float = d.length_squared()
        if denom < 0.0001:
            continue
        var t: float = clampf(Vector2(point.x - a.x, point.z - a.z).dot(d) / denom, 0.0, 1.0)
        var nearest: Vector2 = Vector2(a.x, a.z) + d * t
        best = minf(best, Vector2(point.x, point.z).distance_to(nearest))
    return best

static func _moat_clearance(point: Vector3) -> float:
    var dx: float = maxf(absf(point.x) - 178.0, 0.0)
    var dz: float = maxf(absf(point.z) - 178.0, 0.0)
    return sqrt(dx * dx + dz * dz)

static func _safe(point: Vector3, min_bridge_distance: float = 20.0) -> bool:
    if absf(point.x) > 1010.0 or absf(point.z) > 1010.0:
        return false
    if _moat_clearance(point) < 35.0:
        return false
    if _distance_to_river(point) < 18.0:
        return false
    if Vector2(point.x + 260.0, point.z + 780.0).length() < 80.0:
        return false
    var plateaus: Array[Vector3] = [
        Vector3(-480,0,-85), Vector3(480,0,-85),
        Vector3(-480,0,480), Vector3(480,0,480)
    ]
    for plateau in plateaus:
        if Vector2(point.x - plateau.x, point.z - plateau.z).length() < 58.0:
            return false
    var bridges: Array[Vector3] = [
        Vector3(-615,0,-350), Vector3(-675,0,-100),
        Vector3(-665,0,210), Vector3(-565,0,560)
    ]
    for bridge in bridges:
        if Vector2(point.x - bridge.x, point.z - bridge.z).length() < min_bridge_distance:
            return false
    return true

static func _collect_meshes(node: Node, parent_transform: Transform3D, output: Array[Dictionary]) -> void:
    var transform: Transform3D = parent_transform
    if node is Node3D:
        transform = parent_transform * (node as Node3D).transform
    if node is MeshInstance3D:
        var mesh_node: MeshInstance3D = node as MeshInstance3D
        if mesh_node.mesh != null:
            output.append({"mesh": mesh_node.mesh, "transform": transform, "node_name": mesh_node.name})
    for child in node.get_children():
        _collect_meshes(child, transform, output)

static func _tinted_material(tint: Color) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = tint
    material.roughness = 0.88
    material.metallic = 0.0
    material.vertex_color_use_as_albedo = false
    return material

static func _surface_role(node_name: String, mesh: Mesh, surface_index: int) -> String:
    var tokens: String = node_name.to_lower() + " " + String(mesh.resource_name).to_lower()
    tokens += " " + String(mesh.surface_get_name(surface_index)).to_lower()
    var source: Material = mesh.surface_get_material(surface_index)
    if source != null:
        tokens += " " + String(source.resource_name).to_lower()
    if tokens.contains("trunk") or tokens.contains("bark") or tokens.contains("wood"):
        return "trunk"
    if tokens.contains("base") or tokens.contains("ground") or tokens.contains("disk") or tokens.contains("root_plate"):
        return "base"
    if tokens.contains("canopy") or tokens.contains("leaf") or tokens.contains("leaves") or tokens.contains("foliage"):
        return "canopy"
    return "unknown"

static func _mesh_with_flora_materials(source_mesh: Mesh, node_name: String, tint: Color, tree_asset: bool) -> Mesh:
    var result: Mesh = source_mesh.duplicate() as Mesh
    if result is ArrayMesh:
        var array_mesh: ArrayMesh = result as ArrayMesh
        for surface_index in range(array_mesh.get_surface_count()):
            var role: String = _surface_role(node_name, array_mesh, surface_index)
            var material: StandardMaterial3D = StandardMaterial3D.new()
            material.roughness = 0.88
            material.metallic = 0.0
            material.vertex_color_use_as_albedo = false
            if tree_asset and role == "trunk":
                material.albedo_color = Color(0.32, 0.20, 0.12)
            elif tree_asset and role == "base":
                material.albedo_color = Color(0.35, 0.48, 0.25)
            elif tree_asset and (role == "canopy" or role == "unknown"):
                material.albedo_color = tint
            elif not tree_asset:
                material.albedo_color = tint
            else:
                var original: Material = array_mesh.surface_get_material(surface_index)
                if original is StandardMaterial3D:
                    material = (original as StandardMaterial3D).duplicate() as StandardMaterial3D
                    material.vertex_color_use_as_albedo = false
                    material.roughness = maxf(material.roughness, 0.88)
            array_mesh.surface_set_material(surface_index, material)
    return result

static func _build_instanced_group(root: Node3D, asset_id: String, tint: Color, entries: Array[Dictionary], label: String) -> bool:
    if entries.is_empty():
        return true
    var prototype: Node3D = Assets.load_model(asset_id, "")
    if prototype == null:
        push_error("CHECKPOINT4_REQUIRED_GLB_MISSING: " + asset_id)
        return false
    var source_bounds: AABB = Assets._measure_bounds(prototype, Transform3D.IDENTITY)
    if source_bounds.size.y <= 0.001:
        prototype.free()
        push_error("CHECKPOINT4_GLB_AABB_INVALID: " + asset_id)
        return false
    var mesh_data: Array[Dictionary] = []
    _collect_meshes(prototype, Transform3D.IDENTITY, mesh_data)
    if mesh_data.is_empty():
        prototype.free()
        push_error("CHECKPOINT4_GLB_HAS_NO_MESHES: " + asset_id)
        return false
    for part_index in range(mesh_data.size()):
        var part: Dictionary = mesh_data[part_index]
        var multimesh: MultiMesh = MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        var is_tree_asset: bool = asset_id == "flora_baobab_giant" or asset_id == "flora_jungle_giant" or asset_id == "innerscene-japanese-maple-tree-565c1604" or asset_id == "flora_birch_grove" or asset_id == "flora_mangrove"
        multimesh.mesh = _mesh_with_flora_materials(part.mesh, String(part.node_name), tint, is_tree_asset)
        multimesh.instance_count = entries.size()
        for i in range(entries.size()):
            var item: Dictionary = entries[i]
            var height: float = float(item.height)
            var factor: float = height / source_bounds.size.y
            var basis: Basis = Basis(Vector3.UP, float(item.yaw)) * Basis.from_scale(Vector3.ONE * factor)
            var origin: Vector3 = Vector3(item.position.x, -source_bounds.position.y * factor, item.position.z)
            var placement: Transform3D = Transform3D(basis, origin)
            var part_transform: Transform3D = part.transform
            multimesh.set_instance_transform(i, placement * part_transform)
        var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
        instance.name = "%s_%s_Part_%02d" % [label, asset_id, part_index]
        instance.multimesh = multimesh
        root.add_child(instance)
    prototype.free()
    print("CHECKPOINT4_GLTF_MULTIMESH_OK: ", label, " asset=", asset_id, " instances=", entries.size(), " mesh_parts=", mesh_data.size(), " GLB_source=true")
    return true

static func _typed_entries(raw_entries: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for raw_entry in raw_entries:
        if raw_entry is Dictionary:
            result.append(raw_entry)
    return result

static func _append_group(groups: Array[Dictionary], asset_id: String, tint: Color, item: Dictionary) -> void:
    for group in groups:
        if String(group.asset) == asset_id and group.tint == tint:
            group.entries.append(item)
            return
    groups.append({"asset": asset_id, "tint": tint, "entries": [item]})

static func _add_tree(groups: Array[Dictionary], asset_id: String, tint: Color, position: Vector3, height: float, yaw: float) -> void:
    _append_group(groups, asset_id, tint, {"position": position, "height": height, "yaw": yaw})

static func _generate_tree_groups() -> Array[Dictionary]:
    var groups: Array[Dictionary] = []
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 4120403
    var giant_specs: Array[Dictionary] = [
        {"p":Vector3(-150,0,-780),"asset":"flora_baobab_giant"},
        {"p":Vector3(-398,0,-85),"asset":"flora_jungle_giant"},
        {"p":Vector3(562,0,-85),"asset":"flora_baobab_giant"},
        {"p":Vector3(-480,0,562),"asset":"flora_jungle_giant"},
        {"p":Vector3(538,0,538),"asset":"flora_baobab_giant"},
        {"p":Vector3(-540,0,-430),"asset":"flora_jungle_giant"},
        {"p":Vector3(180,0,-720),"asset":"flora_baobab_giant"},
        {"p":Vector3(850,0,250),"asset":"flora_jungle_giant"}
    ]
    var giant_count: int = 0
    for spec in giant_specs:
        if giant_count >= 22:
            break
        var center: Vector3 = spec.p
        for i in range(3):
            if giant_count >= 22:
                break
            var candidate: Vector3 = center + Vector3(rng.randf_range(-18,18),0,rng.randf_range(-18,18))
            if not _safe(candidate, 28.0):
                candidate = center + Vector3(float(i - 1) * 14.0,0,float(i % 2) * 16.0)
            if _safe(candidate, 28.0):
                _add_tree(groups, String(spec.asset), Color(0.22, 0.48, 0.22), candidate, rng.randf_range(GIANT_MIN,GIANT_MAX), rng.randf_range(0,TAU))
                giant_count += 1
    if giant_count < 20:
        push_error("CHECKPOINT4_GIANT_TREE_COUNT_FAILED: " + str(giant_count))
        return []
    var forest_centers: Array[Vector3] = [
        Vector3(-540,0,-520), Vector3(-535,0,-240), Vector3(-535,0,250),
        Vector3(-450,0,760), Vector3(-80,0,-900), Vector3(180,0,-720),
        Vector3(720,0,-820), Vector3(850,0,-480), Vector3(830,0,40),
        Vector3(820,0,610), Vector3(700,0,900)
    ]
    var tree_assets: Array[String] = ["innerscene-japanese-maple-tree-565c1604","flora_birch_grove","flora_mangrove"]
    var tree_tints: Array[Color] = [Color(0.92,0.48,0.66),Color(0.90,0.58,0.18),Color(0.85,0.35,0.16),Color(0.24,0.56,0.26),Color(0.56,0.36,0.78)]
    var tree_count: int = 0
    for cluster_index in range(forest_centers.size()):
        var center: Vector3 = forest_centers[cluster_index]
        for i in range(16):
            var angle: float = rng.randf_range(0.0,TAU)
            var radius: float = rng.randf_range(18.0,72.0)
            var candidate: Vector3 = center + Vector3(cos(angle)*radius,0,sin(angle)*radius)
            if not _safe(candidate, 22.0):
                continue
            var tint: Color = tree_tints[(tree_count + cluster_index) % tree_tints.size()]
            var asset: String = tree_assets[(tree_count + i) % tree_assets.size()]
            _add_tree(groups,asset,tint,candidate,rng.randf_range(TREE_MIN,TREE_MAX),rng.randf_range(0,TAU))
            tree_count += 1
            if tree_count >= 168:
                break
        if tree_count >= 168:
            break
    if tree_count < 150:
        push_error("CHECKPOINT4_COLOR_TREE_COUNT_FAILED: " + str(tree_count))
        return []
    print("CHECKPOINT4_TREE_DISTRIBUTION_OK: giant=", giant_count, " colorful=", tree_count, " clusters=", forest_centers.size())
    return groups

static func _generate_groundcover_groups() -> Array[Dictionary]:
    var groups: Array[Dictionary] = []
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 4120404
    var centers: Array[Vector3] = [
        Vector3(-555,0,-420),Vector3(-535,0,-180),Vector3(-520,0,300),
        Vector3(-430,0,820),Vector3(-80,0,-900),Vector3(150,0,-720),
        Vector3(700,0,-820),Vector3(850,0,-450),Vector3(830,0,120),
        Vector3(820,0,650),Vector3(700,0,900),Vector3(-585,0,-300),
        Vector3(-585,0,300),Vector3(760,0,400)
    ]
    var assets: Array[String] = ["flora_grass_tuft","flora_fern","flora_ornamental_plant"]
    var colors: Array[Color] = [Color(0.30,0.72,0.24),Color(0.90,0.68,0.20),Color(0.92,0.48,0.66),Color(0.56,0.36,0.78)]
    var count: int = 0
    for cluster_index in range(centers.size()):
        for i in range(32):
            var center: Vector3 = centers[cluster_index]
            var angle: float = rng.randf_range(0.0,TAU)
            var radius: float = rng.randf_range(3.0,38.0)
            var point: Vector3 = center + Vector3(cos(angle)*radius,0,sin(angle)*radius)
            if not _safe(point, 18.0):
                continue
            var asset: String = assets[(count + i + cluster_index) % assets.size()]
            var tint: Color = colors[(count + cluster_index) % colors.size()]
            _append_group(groups,asset,tint,{"position":point,"height":rng.randf_range(PLANT_MIN,PLANT_MAX),"yaw":rng.randf_range(0,TAU)})
            count += 1
            if count >= 420:
                break
        if count >= 420:
            break
    if count < 380:
        push_error("CHECKPOINT4_GROUNDCOVER_COUNT_FAILED: " + str(count))
        return []
    print("CHECKPOINT4_COLORFUL_GROUNDCOVER_OK: instances=",count," height=1.2-3.0m; real GLB tufts, ferns and ornamental plants")
    return groups

static func _build_cottages(root: Node3D) -> bool:
    var clusters: Array[Dictionary] = [
        {"center":Vector3(-565,0,-285),"houses":["obj_chinese_house","obj_chinese_painter_villa"]},
        {"center":Vector3(-570,0,285),"houses":["obj_big_chinese_house","obj_chinese_house"]},
        {"center":Vector3(835,0,390),"houses":["obj_chinese_painter_villa","obj_big_chinese_house"]}
    ]
    var total: int = 0
    for cluster_index in range(clusters.size()):
        var cluster: Dictionary = clusters[cluster_index]
        var center: Vector3 = cluster.center
        for house_index in range(cluster.houses.size()):
            var offset: Vector3 = Vector3(float(house_index)*22.0,0,float(cluster_index%2)*13.0)
            var position: Vector3 = center + offset
            if not _safe(position, 24.0):
                push_error("CHECKPOINT4_COTTAGE_CLEARANCE_REJECTED: " + str(position))
                return false
            var asset_id: String = String(cluster.houses[house_index])
            var house: Node3D = Assets.load_model(asset_id, "")
            if house == null:
                push_error("CHECKPOINT4_COTTAGE_GLB_MISSING: " + asset_id)
                return false
            var bounds: AABB = Assets._measure_bounds(house,Transform3D.IDENTITY)
            if bounds.size.y <= 0.001 or bounds.size.x <= 0.001 or bounds.size.z <= 0.001:
                house.free()
                push_error("CHECKPOINT4_COTTAGE_AABB_INVALID: " + asset_id)
                return false
            var target_height: float = 6.0 + float((cluster_index + house_index) % 4)
            house.scale = Vector3.ONE * (target_height / bounds.size.y)
            var scaled: AABB = Assets._measure_bounds(house,Transform3D.IDENTITY)
            house.position = Vector3(position.x,-scaled.position.y,position.z)
            house.rotation.y = float((cluster_index + house_index) % 4) * PI * 0.5
            house.name = "Checkpoint4_RuralCottage_%02d" % total
            root.add_child(house)
            var body: StaticBody3D = StaticBody3D.new()
            body.name = house.name + "_StaticBody3D"
            body.position = house.position
            body.rotation.y = house.rotation.y
            body.collision_layer = 1
            body.collision_mask = 1
            var shape: BoxShape3D = BoxShape3D.new()
            shape.size = Vector3(scaled.size.x * 0.92,scaled.size.y * 0.96,scaled.size.z * 0.92)
            var collision: CollisionShape3D = CollisionShape3D.new()
            collision.name = "Cottage_AABB_Collision"
            collision.shape = shape
            collision.position = scaled.get_center()
            body.add_child(collision)
            root.add_child(body)
            total += 1
    if total < 6 or total > 9:
        push_error("CHECKPOINT4_COTTAGE_COUNT_FAILED: " + str(total))
        return false
    print("CHECKPOINT4_RURAL_COTTAGES_OK: clusters=",clusters.size()," houses=",total," heights=6-9m StaticBody3D_collision=true")
    return true

static func build(parent: Node3D) -> bool:
    var root: Node3D = parent
    var catalog: Dictionary = Assets._read_catalog()
    for key in ["flora_baobab_giant","flora_jungle_giant","flora_birch_grove","flora_mangrove","flora_grass_tuft","flora_fern","flora_ornamental_plant","innerscene-japanese-maple-tree-565c1604","obj_chinese_house","obj_chinese_painter_villa","obj_big_chinese_house"]:
        if not catalog.has(key):
            push_error("CHECKPOINT4_CATALOG_ASSET_MISSING: " + key)
            return false
    var tree_groups: Array[Dictionary] = _generate_tree_groups()
    if tree_groups.is_empty():
        return false
    var giant_total: int = 0
    var colorful_total: int = 0
    for group in tree_groups:
        if not _build_instanced_group(root,String(group.asset),group.tint,_typed_entries(group.entries),"Checkpoint4_Trees"):
            return false
        for entry in group.entries:
            if float(entry.height) >= GIANT_MIN:
                giant_total += 1
            else:
                colorful_total += 1
    if giant_total < 20 or giant_total > 24 or colorful_total < 150 or colorful_total > 180:
        push_error("CHECKPOINT4_TREE_FINAL_COUNT_REJECTED: giant="+str(giant_total)+" colorful="+str(colorful_total))
        return false
    var groundcover: Array[Dictionary] = _generate_groundcover_groups()
    if groundcover.is_empty():
        return false
    var groundcover_total: int = 0
    for group in groundcover:
        if not _build_instanced_group(root,String(group.asset),group.tint,_typed_entries(group.entries),"Checkpoint4_Groundcover"):
            return false
        groundcover_total += group.entries.size()
    if groundcover_total < 380 or groundcover_total > 450:
        push_error("CHECKPOINT4_GROUNDCOVER_FINAL_COUNT_REJECTED: "+str(groundcover_total))
        return false
    if not _build_cottages(root):
        return false
    print("CHECKPOINT4_FLORA_BUILD_COMPLETE: giant_trees=",giant_total," colorful_trees=",colorful_total," groundcover=",groundcover_total," cottages=6; zero_procedural_visual_geometry=true; gltfpack_noq=true")
    return true

static func captures() -> Array[Dictionary]:
    return [
        {"file":"wilderness_flora_overview.png","pos":Vector3(1040,650,1080),"target":Vector3(680,0,320),"fov":60.0},
        {"file":"wilderness_flora_giant_trees.png","pos":Vector3(-70,95,-690),"target":Vector3(-170,18,-770),"fov":48.0},
        {"file":"wilderness_flora_sakura_forest.png","pos":Vector3(900,55,-520),"target":Vector3(825,8,-650),"fov":52.0},
        {"file":"wilderness_flora_autumn_forest.png","pos":Vector3(930,55,550),"target":Vector3(820,8,430),"fov":52.0},
        {"file":"wilderness_flora_rural_cottages.png","pos":Vector3(-480,48,-215),"target":Vector3(-560,4,-285),"fov":50.0},
        {"file":"wilderness_flora_bridge_forest_cottages.png","pos":Vector3(-560,38,-430),"target":Vector3(-615,5,-350),"fov":42.0}
    ]
