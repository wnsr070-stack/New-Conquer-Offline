extends Node
const CITY_SCENES={"TwinCity":"res://scenes/TwinCity.tscn","PhoenixCastle":"res://scenes/cities/PhoenixCastle.tscn","ApeMountain":"res://scenes/cities/ApeMountain.tscn","DesertCity":"res://scenes/cities/DesertCity.tscn","BirdIsland":"res://scenes/cities/BirdIsland.tscn"}
var current_city="TwinCity"
var pending_spawn=Vector3.ZERO
var transition_in_progress=false
func travel_to_city(city_id: String, spawn: Vector3=Vector3.ZERO) -> void:
    if transition_in_progress or not CITY_SCENES.has(city_id): return
    var packed=load(CITY_SCENES[city_id]) as PackedScene
    if packed==null:
        push_error("WORLD_MAP_SCENE_LOAD_FAILED: "+city_id)
        return
    transition_in_progress=true
    pending_spawn=spawn
    current_city=city_id
    var err=get_tree().change_scene_to_packed(packed)
    if err!=OK:
        transition_in_progress=false
        push_error("WORLD_MAP_TRANSITION_FAILED: "+city_id+" error="+str(err))
        return
    call_deferred("_finish_transition")
func _finish_transition() -> void:
    await get_tree().process_frame
    var player=get_tree().get_first_node_in_group("player")
    if player is Node3D and pending_spawn!=Vector3.ZERO: player.global_position=pending_spawn
    transition_in_progress=false
    print("WORLD_MAP_TRANSITION_OK: current_city=",current_city," five_city_network=true")
