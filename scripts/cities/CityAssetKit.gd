extends RefCounted
class_name CityAssetKit
const Assets = preload("res://scripts/AssetLoader.gd")
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
