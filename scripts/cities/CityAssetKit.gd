extends RefCounted
class_name CityAssetKit
const Assets = preload("res://scripts/AssetLoader.gd")
static func add_ground(root: Node3D, color: Color, court_size: Vector2, court_color: Color, roughness: float=0.92, ocean: bool=false) -> void:
    var plane := PlaneMesh.new()
    plane.size = Vector2(2200.0, 2200.0)
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    var floor := MeshInstance3D.new()
    floor.name = "MainGroundPlane_2200m"
    floor.mesh = plane
    floor.material_override = material
    floor.position.y = 0.0
    root.add_child(floor)
    if not ocean:
        var body := StaticBody3D.new()
        body.name = "MainGroundCollision"
        body.position.y = -0.25
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(2200.0, 0.5, 2200.0)
        collision.shape = shape
        collision.position.y = 0.25
        body.add_child(collision)
        root.add_child(body)
    if court_size.x > 0.0 and court_size.y > 0.0:
        var court_mesh := PlaneMesh.new()
        court_mesh.size = court_size
        var court_material := StandardMaterial3D.new()
        court_material.albedo_color = court_color
        court_material.roughness = 0.9
        var court := MeshInstance3D.new()
        court.name = "CentralCityCourt"
        court.mesh = court_mesh
        court.material_override = court_material
        court.position.y = 0.08
        root.add_child(court)
        var court_body := StaticBody3D.new()
        court_body.name = "CentralCourtCollision"
        court_body.position.y = -0.17
        var court_collision := CollisionShape3D.new()
        var court_shape := BoxShape3D.new()
        court_shape.size = Vector3(court_size.x, 0.5, court_size.y)
        court_collision.shape = court_shape
        court_collision.position.y = 0.25
        court_body.add_child(court_collision)
        root.add_child(court_body)
static func add_oasis_lake(root: Node3D, center: Vector3) -> void:
    var water := CylinderMesh.new()
    water.top_radius = 65.0
    water.bottom_radius = 65.0
    water.height = 0.18
    water.radial_segments = 64
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.06, 0.48, 0.60)
    material.roughness = 0.24
    var lake := MeshInstance3D.new()
    lake.name = "OasisLake_130m"
    lake.mesh = water
    lake.material_override = material
    lake.position = center
    root.add_child(lake)
static func tint_model(node: Node, color: Color, roughness: float = 0.88) -> void:
    for child in node.get_children():
        if child is MeshInstance3D and child.mesh != null:
            var mesh := child.mesh.duplicate() as Mesh
            for surface in range(mesh.get_surface_count()):
                var mat := StandardMaterial3D.new()
                mat.albedo_color=color
                mat.roughness=roughness
                mat.vertex_color_use_as_albedo=false
                mesh.surface_set_material(surface,mat)
            child.mesh=mesh
        tint_model(child,color,roughness)
static func place(root: Node3D, asset_id: String, pos: Vector3, height: float, yaw: float=0.0, tint: Color=Color(-1,-1,-1), roughness: float=0.88) -> Node3D:
    var model: Node3D=Assets.load_model(asset_id,"")
    if model==null:
        push_error("PHASE3A3_REQUIRED_ASSET_MISSING: "+asset_id)
        return null
    var bounds: AABB=Assets._measure_bounds(model,Transform3D.IDENTITY)
    if bounds.size.y<=0.001 or bounds.size.x<=0.001 or bounds.size.z<=0.001:
        model.free()
        push_error("PHASE3A3_INVALID_GLB_BOUNDS: "+asset_id)
        return null
    Assets.fit_height(model,height)
    model.position+=pos
    model.rotation.y=yaw
    if tint.r>=0.0: tint_model(model,tint,roughness)
    model.name="GLB_"+asset_id
    root.add_child(model)
    return model
static func place_scaled(root: Node3D, asset_id: String, pos: Vector3, dims: Vector3, yaw: float, tint: Color, roughness: float=0.9) -> Node3D:
    var model: Node3D=Assets.load_model(asset_id,"")
    if model==null:
        push_error("PHASE3A3_REQUIRED_ASSET_MISSING: "+asset_id)
        return null
    var b: AABB=Assets._measure_bounds(model,Transform3D.IDENTITY)
    if b.size.length_squared()<0.0001:
        model.free()
        push_error("PHASE3A3_INVALID_GLB_BOUNDS: "+asset_id)
        return null
    model.scale=Vector3(dims.x/b.size.x,dims.y/b.size.y,dims.z/b.size.z)
    model.position=pos-Vector3(b.position.x*model.scale.x,b.position.y*model.scale.y,b.position.z*model.scale.z)
    model.rotation.y=yaw
    tint_model(model,tint,roughness)
    model.name="GLB_"+asset_id
    root.add_child(model)
    return model
static func portal(root: Node3D, destination: String, pos: Vector3) -> void:
    var area:=Area3D.new()
    area.name="Conductor_To_"+destination
    area.position=pos
    area.collision_layer=0
    area.collision_mask=1
    var collision:=CollisionShape3D.new()
    var shape:=CylinderShape3D.new()
    shape.radius=3.0
    shape.height=4.0
    collision.shape=shape
    collision.position.y=2.0
    area.add_child(collision)
    area.body_entered.connect(func(body: Node3D) -> void:
        var main_loop: MainLoop = Engine.get_main_loop()
        var scene_tree: SceneTree = main_loop as SceneTree
        var manager: Node = scene_tree.root.get_node_or_null("WorldMapManager") if scene_tree != null else null
        if body.is_in_group("player") and manager != null:
            manager.call("travel_to_city", destination)
    )
    root.add_child(area)
    place(root,"innerscene-buddhist-temple-pagoda-c5ebacdc",pos+Vector3(0,0,-5),5.0,0.0,Color(0.72,0.62,0.36))
