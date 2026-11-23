extends Node3D
const SHOTS=[
{"scene":"res://scenes/cities/PhoenixCastle.tscn","file":"city_phoenix_castle.png","pos":Vector3(90,100,90),"target":Vector3(0,12,0),"fov":52.0},
{"scene":"res://scenes/cities/ApeMountain.tscn","file":"city_ape_mountain.png","pos":Vector3(90,108,90),"target":Vector3(0,18,0),"fov":52.0},
{"scene":"res://scenes/cities/DesertCity.tscn","file":"city_desert_city.png","pos":Vector3(110,100,90),"target":Vector3(80,10,0),"fov":52.0},
{"scene":"res://scenes/cities/BirdIsland.tscn","file":"city_bird_island.png","pos":Vector3(90,105,90),"target":Vector3(0,5,0),"fov":52.0},
{"scene":"res://scenes/cities/DesertCity.tscn","file":"city_desert_oasis_closeup.png","pos":Vector3(80,100,80),"target":Vector3(410,8,-65),"fov":42.0},
{"scene":"res://scenes/cities/BirdIsland.tscn","file":"city_bird_island_bridges_closeup.png","pos":Vector3(90,105,90),"target":Vector3(0,5,0),"fov":42.0}]
var camera:Camera3D
func _ready()->void:
    var envnode=WorldEnvironment.new(); var env=Environment.new(); env.background_mode=Environment.BG_SKY
    env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color(0.72,0.76,0.82); env.ambient_light_energy=0.8
    envnode.environment=env; add_child(envnode)
    var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-52,-32,0); sun.light_energy=1.25; add_child(sun)
    camera=Camera3D.new(); camera.current=true; add_child(camera)
    if OS.get_environment("CI_CAPTURE")=="1": await capture_all()
    else:
        var packed=load(SHOTS[0].scene) as PackedScene
        if packed!=null:add_child(packed.instantiate())
func capture_all()->void:
    var dir=ProjectSettings.globalize_path("res://artifacts"); DirAccess.make_dir_recursive_absolute(dir)
    for shot in SHOTS:
        var packed=load(shot.scene) as PackedScene
        if packed==null:push_error("PHASE3A3_CAPTURE_FAILED: "+shot.scene); get_tree().quit(1); return
        var city:Node3D=packed.instantiate() as Node3D
        if city==null:push_error("PHASE3A3_CAPTURE_FAILED: invalid root "+shot.scene); get_tree().quit(1); return
        add_child(city); await get_tree().process_frame
        camera.position=shot.pos; camera.fov=shot.fov; camera.look_at(shot.target,Vector3.UP)
        for i in range(3):await get_tree().process_frame; await RenderingServer.frame_post_draw
        var img=get_viewport().get_texture().get_image(); var path=dir.path_join(shot.file)
        if img==null or img.is_empty() or img.save_png(path)!=OK:push_error("PHASE3A3_CAPTURE_FAILED: "+shot.file); get_tree().quit(1); return
        var f=FileAccess.open(path,FileAccess.READ); var bytes=f.get_length() if f!=null else 0
        if f!=null:f.close()
        if bytes<=15000:push_error("PHASE3A3_CAPTURE_FAILED: "+shot.file); get_tree().quit(1); return
        print("PHASE3A3_CAPTURE_DONE: ",shot.file," bytes=",bytes)
        remove_child(city); city.queue_free(); await get_tree().process_frame
    print("PHASE3A3_ALL_SIX_CAPTURES_COMPLETE"); get_tree().quit(0)
