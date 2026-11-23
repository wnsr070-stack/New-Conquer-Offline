extends RefCounted
class_name CityAssetKit
const Assets=preload("res://scripts/AssetLoader.gd")
static func tex(key:String)->Texture2D:
    var c=Assets._read_catalog()
    if not c.has(key): push_error("CITY_TEXTURE_MISSING: "+key); return null
    var p=String(c[key].get("path",""))
    if not FileAccess.file_exists(p): push_error("CITY_TEXTURE_FILE_MISSING: "+p); return null
    var im=Image.load_from_file(p)
    if im==null or im.is_empty(): push_error("CITY_TEXTURE_DECODE_FAILED: "+key); return null
    if im.get_mipmap_count()==0: im.generate_mipmaps()
    return ImageTexture.create_from_image(im)
static func mat(prefix:String,tint:Color,scale:float=55.0)->StandardMaterial3D:
    var d=tex(prefix+"_diffuse"); var n=tex(prefix+"_normal"); var r=tex(prefix+"_roughness")
    if d==null or n==null or r==null: return null
    var m=StandardMaterial3D.new()
    m.albedo_texture=d; m.albedo_color=tint; m.normal_enabled=true; m.normal_texture=n
    m.roughness_texture=r; m.roughness=0.94; m.uv1_scale=Vector3(scale,scale,scale)
    m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return m
static func apply_mat(n:Node,m:StandardMaterial3D)->void:
    if n is MeshInstance3D: n.material_override=m
    for ch in n.get_children(): apply_mat(ch,m)
static func add_ground(root:Node3D,color:Color,court_size:Vector2,court_color:Color,roughness:float=0.92,ocean:bool=false,ground_texture:String="",court_texture:String="")->void:
    var pm=PlaneMesh.new(); pm.size=Vector2(2200,2200)
    var gm=StandardMaterial3D.new(); gm.albedo_color=color; gm.roughness=roughness
    if ground_texture!="":
        gm=mat(ground_texture,color,55.0)
        if gm==null:return
    var floor=MeshInstance3D.new(); floor.name="MainGround_PBR"; floor.mesh=pm; floor.material_override=gm; root.add_child(floor)
    if not ocean:
        var body=StaticBody3D.new(); body.name="MainGroundCollision"
        var cs=CollisionShape3D.new(); var bs=BoxShape3D.new(); bs.size=Vector3(2200,0.5,2200); cs.shape=bs; cs.position.y=0.25; body.position.y=-0.25; body.add_child(cs); root.add_child(body)
    if court_size.x>0 and court_size.y>0:
        var cm=PlaneMesh.new(); cm.size=court_size
        var mm=StandardMaterial3D.new(); mm.albedo_color=court_color
        if court_texture!="":
            mm=mat(court_texture,court_color,8.0)
            if mm==null:return
        var court=MeshInstance3D.new(); court.name="CentralCourt_PBR"; court.mesh=cm; court.material_override=mm; court.position.y=0.08; root.add_child(court)
        var cb=StaticBody3D.new(); var cc=CollisionShape3D.new(); var sh=BoxShape3D.new(); sh.size=Vector3(court_size.x,0.5,court_size.y); cc.shape=sh; cc.position.y=0.25; cb.position.y=-0.17; cb.add_child(cc); root.add_child(cb)
static func tint_model(n:Node,c:Color,r:float=0.88)->void:
    for ch in n.get_children():
        if ch is MeshInstance3D and ch.mesh!=null:
            var mesh=ch.mesh.duplicate() as Mesh
            for s in range(mesh.get_surface_count()):
                var m=StandardMaterial3D.new(); m.albedo_color=c; m.roughness=r; mesh.surface_set_material(s,m)
            ch.mesh=mesh
        tint_model(ch,c,r)
static func place(root:Node3D,id:String,pos:Vector3,height:float,yaw:float=0.0,tint:Color=Color(-1,-1,-1),roughness:float=0.88,texture_prefix:String="")->Node3D:
    var model=Assets.load_model(id,"")
    if model==null: push_error("PHASE3A3_REQUIRED_ASSET_MISSING: "+id); return null
    var b=Assets._measure_bounds(model,Transform3D.IDENTITY)
    if b.size.y<=0.001:return null
    Assets.fit_height(model,height); model.position+=pos; model.rotation.y=yaw
    if texture_prefix!="":
        var m=mat(texture_prefix,tint if tint.r>=0 else Color.WHITE,8.0)
        if m==null:return null
        apply_mat(model,m)
    elif tint.r>=0:tint_model(model,tint,roughness)
    root.add_child(model); return model
static func place_scaled(root:Node3D,id:String,pos:Vector3,dims:Vector3,yaw:float,tint:Color,roughness:float=0.9,texture_prefix:String="")->Node3D:
    var model=Assets.load_model(id,"")
    if model==null: push_error("PHASE3A3_REQUIRED_ASSET_MISSING: "+id); return null
    var b=Assets._measure_bounds(model,Transform3D.IDENTITY)
    if b.size.length_squared()<0.0001:return null
    model.scale=Vector3(dims.x/b.size.x,dims.y/b.size.y,dims.z/b.size.z)
    model.position=pos-Vector3(b.position.x*model.scale.x,b.position.y*model.scale.y,b.position.z*model.scale.z); model.rotation.y=yaw
    if texture_prefix!="":
        var m=mat(texture_prefix,tint,8.0)
        if m==null:return null
        apply_mat(model,m)
    else:tint_model(model,tint,roughness)
    root.add_child(model); return model
static func lava(root:Node3D)->void:
    var m=StandardMaterial3D.new(); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; m.emission_enabled=true
    m.emission=Color(0.95,0.28,0.05); m.emission_energy_multiplier=1.6
    for i in range(28):
        var a=TAU*float(i)/28.0; var crack=MeshInstance3D.new(); var p=PlaneMesh.new()
        p.size=Vector2(1.1,9.0+float(i%4)*3.0); crack.mesh=p
        crack.position=Vector3(cos(a)*(235.0+float(i%3)*22.0),0.12,sin(a)*(235.0+float(i%3)*22.0)); crack.rotation.y=a+0.35; crack.material_override=m; root.add_child(crack)
static func forest(root:Node3D,count:int=128)->void:
    for i in range(count):
        var a=TAU*float(i)/float(count); var r=245.0+fposmod(float(i)*37.0,185.0)
        place(root,"flora_birch_grove",Vector3(cos(a)*r,0,sin(a)*r),13.0+float(i%7),-a,Color(0.12,0.24,0.14))
    print("APE_MOUNTAIN_DARK_FOREST_OK: ",count," tree instances")
static func oasis(root:Node3D,center:Vector3)->void:
    var mesh=CylinderMesh.new(); mesh.top_radius=60; mesh.bottom_radius=60; mesh.height=0.18; mesh.radial_segments=96
    var m=StandardMaterial3D.new(); m.albedo_color=Color(0.06,0.62,0.72); m.roughness=0.18
    var lake=MeshInstance3D.new(); lake.name="Oasis_120m"; lake.mesh=mesh; lake.material_override=m; lake.position=center; root.add_child(lake)
static func bridge(root:Node3D,pos:Vector3,length:float,yaw:float,label:String)->void:
    place_scaled(root,"bridge_wood",pos,Vector3(length,1.8,9),yaw,Color(0.36,0.23,0.13))
    var body=StaticBody3D.new(); body.name=label+"_StaticBody3D"; body.position=pos+Vector3(0,0.9,0)
    var cs=CollisionShape3D.new(); var sh=BoxShape3D.new(); sh.size=Vector3(length,1.8,9); cs.shape=sh; body.add_child(cs); root.add_child(body)
static func portal(root:Node3D,destination:String,pos:Vector3)->void:
    var area=Area3D.new(); area.name="Conductor_To_"+destination; area.position=pos; area.collision_layer=0; area.collision_mask=1
    var cs=CollisionShape3D.new(); var sh=CylinderShape3D.new(); sh.radius=3; sh.height=4; cs.shape=sh; cs.position.y=2; area.add_child(cs)
    area.body_entered.connect(func(body:Node3D)->void:
        var tree=Engine.get_main_loop() as SceneTree
        var manager=tree.root.get_node_or_null("WorldMapManager") if tree!=null else null
        if body.is_in_group("player") and manager!=null: manager.call("travel_to_city",destination))
    root.add_child(area)
    place(root,"innerscene-buddhist-temple-pagoda-c5ebacdc",pos+Vector3(0,0,-5),9.25)
