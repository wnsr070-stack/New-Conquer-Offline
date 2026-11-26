extends Node3D
## Safe Market destination scene. Market services can be registered here independently.
func _ready() -> void:
 add_to_group("safe_zone")
 print("SAFE_MARKET_SCENE_READY: pvp=false city_id=Market")
