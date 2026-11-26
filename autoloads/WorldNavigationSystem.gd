extends Node
## Unified city directory, target navigation and instant travel.

const CITY_DIRECTORIES := {
 "TwinCity": {
  "Blacksmith":{"position":Vector3(-92,0,86),"type":"npc"},
  "Armorer":{"position":Vector3(-86,0,86),"type":"npc"},
  "AccessoryMerchant":{"position":Vector3(-98,0,86),"type":"npc"},
  "Pharmacist":{"position":Vector3(86,0,92),"type":"npc"},
  "QuestMaster":{"position":Vector3(-86,0,-92),"type":"npc"},
  "ArtisanMaster":{"position":Vector3(86,0,-92),"type":"npc"},
  "Warehouseman":{"position":Vector3(-12,0,-12),"type":"npc"},
  "Conductress":{"position":Vector3(12,0,-12),"type":"npc"},
  "ImperialEnvoy":{"position":Vector3(0,0,-56),"type":"npc"},
  "CentralPlaza":{"position":Vector3(0,0,0),"type":"landmark"},
  "ImperialPalace":{"position":Vector3(0,3.5,-75),"type":"landmark"},
  "QuestHall":{"position":Vector3(-92,0,-92),"type":"landmark"},
  "Pagoda":{"position":Vector3(92,0,-92),"type":"landmark"},
  "TeaHouse":{"position":Vector3(92,0,92),"type":"landmark"},
  "BlacksmithForge":{"position":Vector3(-92,0,92),"type":"landmark"}
 },
 "PhoenixCastle":{"CityCenter":{"position":Vector3.ZERO,"type":"landmark"}},
 "ApeMountain":{"CityCenter":{"position":Vector3.ZERO,"type":"landmark"}},
 "DesertCity":{"CityCenter":{"position":Vector3.ZERO,"type":"landmark"}},
 "BirdIsland":{"CityCenter":{"position":Vector3(0,4.6,0),"type":"landmark"}},
 "Market":{"MarketSquare":{"position":Vector3.ZERO,"type":"landmark"}}
}
var last_target_id := ""
var navigation_in_progress := false

func get_city_directory(city_id: String) -> Dictionary:
 var directory: Dictionary = CITY_DIRECTORIES.get(city_id,{})
 return directory.duplicate(true)

func navigate_to_target(target_id: String) -> bool:
 if navigation_in_progress:
  return false
 var world_map := get_node_or_null("/root/WorldMapManager")
 if world_map == null:
  push_error("WORLD_NAVIGATION_WORLD_MAP_MANAGER_MISSING")
  return false
 var city_id := String(world_map.current_city)
 var directory := get_city_directory(city_id)
 if not directory.has(target_id):
  for candidate_city in CITY_DIRECTORIES:
   if CITY_DIRECTORIES[candidate_city].has(target_id):
    city_id = candidate_city
    directory = get_city_directory(city_id)
    break
 if not directory.has(target_id):
  push_warning("WORLD_NAVIGATION_TARGET_UNKNOWN: "+target_id)
  return false
 var destination: Vector3 = directory[target_id].get("position",Vector3.ZERO)
 last_target_id = target_id
 if city_id == String(world_map.current_city):
  _place_player(destination)
  return true
 navigation_in_progress = true
 world_map.travel_to_city(city_id,destination)
 await get_tree().process_frame
 await get_tree().process_frame
 _place_player(destination)
 navigation_in_progress = false
 return true

func instant_teleport(destination_city_id: String, spawn_pos: Vector3) -> bool:
 var world_map := get_node_or_null("/root/WorldMapManager")
 if world_map == null or not world_map.CITY_SCENES.has(destination_city_id):
  push_warning("WORLD_NAVIGATION_DESTINATION_UNKNOWN: "+destination_city_id)
  return false
 if navigation_in_progress:
  return false
 navigation_in_progress = true
 world_map.travel_to_city(destination_city_id,spawn_pos)
 await get_tree().process_frame
 await get_tree().process_frame
 _place_player(spawn_pos)
 navigation_in_progress = false
 print("WORLD_INSTANT_TELEPORT_OK: city=",destination_city_id," spawn=",spawn_pos)
 return true

func _place_player(position: Vector3) -> void:
 var player := get_tree().get_first_node_in_group("player")
 if player is Node3D:
  (player as Node3D).global_position = position
  if player is CharacterBody3D:
   (player as CharacterBody3D).velocity = Vector3.ZERO

func clear_cache() -> void:
 last_target_id = ""
 navigation_in_progress = false

func navigate_to_position(city_id: String, destination: Vector3) -> bool:
 var world_map := get_node_or_null("/root/WorldMapManager")
 if world_map == null or not world_map.CITY_SCENES.has(city_id): return false
 if navigation_in_progress: return false
 if city_id == String(world_map.current_city):
  _place_player(destination)
  return true
 navigation_in_progress = true
 world_map.travel_to_city(city_id,destination)
 await get_tree().process_frame
 await get_tree().process_frame
 _place_player(destination)
 navigation_in_progress = false
 return true
