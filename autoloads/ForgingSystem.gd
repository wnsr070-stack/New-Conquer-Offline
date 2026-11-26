extends Node
signal forge_succeeded(operation: String, item: Dictionary)
signal forge_failed(reason: String)
signal forging_succeeded(operation: String, item: Dictionary)
signal forging_failed(reason: String)
signal socket_updated(slot: String, socket_index: int, gem_id: String)
signal anima_upgraded(old_phase: int, new_phase: int)

const PLUS_COMPOSITION := {1:20,2:40,3:80,4:160,5:320,6:640,7:1280,8:2560,9:5120,10:7680,11:10240,12:12800}
const QUALITY_ORDER := ["Normal","Refined","Unique","Elite","Super"]
const GEM_BONUSES := {
 "DragonGem":{"attack_pct":0.05,"magic_attack_pct":0.0,"damage_reduction":0.0,"exp_bonus":0.0,"dodge_pct":0.0,"hp_pct":0.0,"mana_pct":0.0},
 "PhoenixGem":{"attack_pct":0.0,"magic_attack_pct":0.05,"damage_reduction":0.0,"exp_bonus":0.0,"dodge_pct":0.0,"hp_pct":0.0,"mana_pct":0.0},
 "RainbowGem":{"attack_pct":0.0,"magic_attack_pct":0.0,"damage_reduction":0.0,"exp_bonus":0.10,"dodge_pct":0.0,"hp_pct":0.0,"mana_pct":0.0},
 "VioletGem":{"attack_pct":0.0,"magic_attack_pct":0.0,"damage_reduction":0.0,"exp_bonus":0.0,"dodge_pct":0.05,"hp_pct":0.0,"mana_pct":0.0},
 "FuryGem":{"attack_pct":0.0,"magic_attack_pct":0.0,"damage_reduction":0.0,"exp_bonus":0.0,"dodge_pct":0.0,"hp_pct":0.05,"mana_pct":0.0},
 "MoonGem":{"attack_pct":0.0,"magic_attack_pct":0.0,"damage_reduction":0.0,"exp_bonus":0.0,"dodge_pct":0.0,"hp_pct":0.0,"mana_pct":0.05},
 "KylinGem":{"attack_pct":0.0,"magic_attack_pct":0.0,"damage_reduction":0.05,"exp_bonus":0.0,"dodge_pct":0.0,"hp_pct":0.0,"mana_pct":0.0}
}
signal artisan_opened
var last_error := ""

func handle_npc_interaction(npc_id: String, role_type: String) -> void:
 if npc_id == "ArtisanMaster" and role_type == "forge":
  artisan_opened.emit()

func compose_plus(slot: String = "weapon", material_id: String = "Plus1Stone") -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 var state := get_node_or_null("/root/GameState")
 if gear == null or state == null: return _fail("forge_dependencies_missing")
 var item: Dictionary = gear.get_equipped(slot)
 if item.is_empty(): return _fail("no_equipped_item")
 var current_plus := int(item.get("plus",0))
 if current_plus >= 12: return _fail("plus_maximum_reached")
 var points_by_stone := {"Plus1Stone":20,"Plus2Stone":40,"Plus3Stone":80,"PlusStone1":20,"PlusStone2":40,"PlusStone3":80}
 var points := int(points_by_stone.get(material_id,0))
 var consumed_id := material_id
 if points == 0:
  var material: Dictionary = gear.database.get_item(material_id) if gear.database != null else {}
  if material.is_empty() or String(material.get("family","")) != String(item.get("family","")):
   return _fail("composition_item_must_match_equipment_type")
  points = maxi(1,int(material.get("level",1)))
 if not _consume_inventory(state,consumed_id,1): return _fail("composition_material_missing")
 var target_plus := current_plus + 1
 var required := int(PLUS_COMPOSITION.get(target_plus,0))
 var cost := _gold_cost(item,target_plus,"plus")
 if not _spend_gold(state,cost):
  state.add_inventory_item(consumed_id,1)
  return _fail("insufficient_gold")
 var total_points := int(item.get("composition_points",0)) + points
 if total_points < required:
  item["composition_points"] = total_points
  gear.update_equipped_item(slot,item)
  _commit(state)
  forging_succeeded.emit("composition",item)
  forge_succeeded.emit("composition",item)
  return {"ok":true,"item":item,"composition_added":points,"composition_total":total_points,"composition_required":required,"plus_upgraded":false,"gold_spent":cost}
 item["composition_points"] = total_points - required
 item["plus"] = target_plus
 _recalculate_item_stats(item)
 item["display_name"] = _display_name(item)
 gear.update_equipped_item(slot,item)
 _commit(state)
 forging_succeeded.emit("plus",item)
 forge_succeeded.emit("plus",item)
 return {"ok":true,"item":item,"composition_added":points,"composition_total":int(item["composition_points"]),"plus_upgraded":true,"gold_spent":cost}

func upgrade_quality(slot: String = "weapon") -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 var state := get_node_or_null("/root/GameState")
 if gear == null or state == null: return _fail("forge_dependencies_missing")
 var item: Dictionary = gear.get_equipped(slot)
 if item.is_empty(): return _fail("no_equipped_item")
 var index := QUALITY_ORDER.find(String(item.get("quality","Normal")))
 if index < 0 or index >= QUALITY_ORDER.size()-1: return _fail("quality_maximum_reached")
 if not _consume_inventory(state,"DragonBall",1): return _fail("dragon_ball_missing")
 var cost := _gold_cost(item,index+1,"quality")
 if not _spend_gold(state,cost):
  state.add_inventory_item("DragonBall",1)
  return _fail("insufficient_gold")
 item["quality"] = QUALITY_ORDER[index+1]
 item["quality_attack_multiplier"] = 1.0 + float(index + 1) * 0.05
 _recalculate_item_stats(item)
 item["display_name"] = _display_name(item)
 gear.update_equipped_item(slot,item)
 _commit(state)
 print("FORGE_QUALITY_SUCCESS: ",item.quality," gold=",cost)
 forging_succeeded.emit("quality",item)
 forge_succeeded.emit("quality",item)
 return {"ok":true,"item":item,"gold_spent":cost}

func upgrade_level(slot: String = "weapon") -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 var state := get_node_or_null("/root/GameState")
 if gear == null or state == null: return _fail("forge_dependencies_missing")
 var item: Dictionary = gear.get_equipped(slot)
 if item.is_empty(): return _fail("no_equipped_item")
 var level := int(item.get("level",10))
 if level >= 130: return _fail("level_maximum_reached")
 var target_level := mini(130,level + 10)
 var level_difference := maxi(0,target_level - int(item.get("base_level",level)))
 var success_chance := clampf(1.0 / float(level_difference + 1),0.05,1.0)
 if not _consume_inventory(state,"Meteor",1): return _fail("meteor_missing")
 var cost := _gold_cost(item,level+10,"level")
 if not _spend_gold(state,cost):
  state.add_inventory_item("Meteor",1)
  return _fail("insufficient_gold")
 if randf() > success_chance:
  _commit(state)
  forging_failed.emit("level_upgrade_failed")
  forge_failed.emit("level_upgrade_failed")
  return {"ok":false,"reason":"level_upgrade_failed","success_chance":success_chance,"meteor_consumed":true,"gold_spent":cost}
 item["level"] = target_level
 item["base_level"] = target_level
 _recalculate_item_stats(item)
 item["display_name"] = _display_name(item)
 gear.update_equipped_item(slot,item)
 _commit(state)
 print("FORGE_LEVEL_SUCCESS: level=",item.level," gold=",cost)
 forging_succeeded.emit("level",item)
 forge_succeeded.emit("level",item)
 return {"ok":true,"item":item,"gold_spent":cost}

func open_socket(slot: String = "weapon") -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 var state := get_node_or_null("/root/GameState")
 if gear == null or state == null: return _fail("forge_dependencies_missing")
 var item: Dictionary = gear.get_equipped(slot)
 if item.is_empty(): return _fail("no_equipped_item")
 var sockets: Array = item.get("sockets",[])
 if sockets.size() >= 2: return _fail("sockets_full")
 var drill_cost := 1 if sockets.is_empty() else 5
 if sockets.size() == 1 and int(state.inventory.get("ToughDrill",0)) > 0:
  if not _consume_inventory(state,"ToughDrill",1): return _fail("tough_drill_missing")
 elif not _consume_inventory(state,"DragonBall",drill_cost):
  return _fail("dragon_ball_missing")
 var cost := _gold_cost(item,sockets.size()+1,"socket")
 if not _spend_gold(state,cost):
  state.add_inventory_item("DragonBall",1)
  return _fail("insufficient_gold")
 sockets.append("")
 item["sockets"] = sockets
 gear.update_equipped_item(slot,item)
 _commit(state)
 print("FORGE_SOCKET_OPENED: slot=",slot," socket=",sockets.size())
 socket_updated.emit(slot,sockets.size()-1,"")
 forging_succeeded.emit("socket",item)
 forge_succeeded.emit("socket",item)
 return {"ok":true,"item":item,"socket_count":sockets.size(),"gold_spent":cost}

func socket_gem(gem_id: String, socket_index: int = 0, slot: String = "weapon") -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 var state := get_node_or_null("/root/GameState")
 if gear == null or state == null: return _fail("forge_dependencies_missing")
 if not GEM_BONUSES.has(gem_id): return _fail("unknown_gem")
 var item: Dictionary = gear.get_equipped(slot)
 if item.is_empty(): return _fail("no_equipped_item")
 var sockets: Array = item.get("sockets",[])
 if socket_index < 0 or socket_index >= sockets.size(): return _fail("socket_not_open")
 if not String(sockets[socket_index]).is_empty(): return _fail("socket_occupied")
 if not _consume_inventory(state,gem_id,1): return _fail("gem_missing")
 sockets[socket_index] = gem_id
 item["sockets"] = sockets
 item["gem_bonuses"] = _calculate_gem_bonuses(sockets)
 gear.update_equipped_item(slot,item)
 _commit(state)
 print("FORGE_GEM_SOCKETED: gem=",gem_id," socket=",socket_index+1)
 socket_updated.emit(slot,socket_index,gem_id)
 forging_succeeded.emit("gem",item)
 forge_succeeded.emit("gem",item)
 return {"ok":true,"item":item}

func get_plus_aura_level(item: Dictionary) -> int:
 var plus := int(item.get("plus",0))
 return 0 if plus < 3 else 1 if plus < 6 else 2 if plus < 9 else 3 if plus < 12 else 4

func apply_equipped_weapon_aura(hero: Node3D) -> bool:
 if hero == null or not is_instance_valid(hero): return false
 var gear := get_node_or_null("/root/GearSystem")
 var vfx := get_node_or_null("/root/AuraAndVFXManager")
 if gear == null or vfx == null: return false
 var item: Dictionary = gear.get_equipped("weapon")
 var plus := int(item.get("plus",0))
 var weapon_nodes: Array = hero.get("weapon_nodes") if hero.get("weapon_nodes") is Array else []
 var attached := false
 for socket in weapon_nodes:
  if not is_instance_valid(socket) or not socket is Node3D: continue
  var mesh_root := socket.get_child(0) as Node3D if socket.get_child_count()>0 else socket as Node3D
  if mesh_root != null and vfx.attach_equipment_aura(mesh_root,plus,true): attached = true
 print("PHASE4D_FORGING_SPRITE_AURA_OK: plus=",plus," attached=",attached," particles=false")
 return attached or plus < 3

func _apply_aura_to_meshes(node: Node,level: int) -> void:
 for child in node.get_children():
  if child is MeshInstance3D and child.mesh != null:
   var mesh := child as MeshInstance3D
   for surface in range(mesh.mesh.get_surface_count()):
    var material := mesh.get_active_material(surface)
    var aura_material: StandardMaterial3D = StandardMaterial3D.new()
    if material is StandardMaterial3D: aura_material = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
    aura_material.emission_enabled = true
    aura_material.emission = Color(0.18,0.55,1.0) if level < 3 else Color(0.55,0.18,1.0)
    aura_material.emission_energy_multiplier = 0.18+float(level)*0.16
    aura_material.metallic = maxf(aura_material.metallic,0.55)
    mesh.set_surface_override_material(surface,aura_material)
  _apply_aura_to_meshes(child,level)

func _clear_aura(node: Node) -> void:
 for child in node.get_children():
  if child.name in ["ForgingPlusAuraLight","ForgingPlusAuraParticles"]:
   child.queue_free()
  elif child is MeshInstance3D and child.mesh != null:
   for surface in range(child.mesh.get_surface_count()):
    child.set_surface_override_material(surface,null)
  else: _clear_aura(child)

func _calculate_gem_bonuses(sockets: Array) -> Dictionary:
 var result := {"attack_pct":0.0,"magic_attack_pct":0.0,"damage_reduction":0.0,"exp_bonus":0.0,"dodge_pct":0.0,"hp_pct":0.0,"mana_pct":0.0}
 for gem in sockets:
  var gem_id := String(gem)
  if GEM_BONUSES.has(gem_id):
   for key in GEM_BONUSES[gem_id]:
    result[key] = float(result.get(key,0.0)) + float(GEM_BONUSES[gem_id][key])
 return result

func remove_socket_gem(socket_index: int, slot: String = "weapon") -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 var state := get_node_or_null("/root/GameState")
 if gear == null or state == null: return _fail("forge_dependencies_missing")
 var item: Dictionary = gear.get_equipped(slot)
 if item.is_empty(): return _fail("no_equipped_item")
 var sockets: Array = item.get("sockets",[])
 if socket_index < 0 or socket_index >= sockets.size(): return _fail("socket_not_open")
 var removed_gem := String(sockets[socket_index])
 if removed_gem.is_empty(): return _fail("socket_empty")
 sockets[socket_index] = ""
 item["sockets"] = sockets
 item["gem_bonuses"] = _calculate_gem_bonuses(sockets)
 gear.update_equipped_item(slot,item)
 _commit(state)
 socket_updated.emit(slot,socket_index,"")
 forging_succeeded.emit("gem_removed_destroyed",item)
 return {"ok":true,"item":item,"destroyed_gem":removed_gem}

func upgrade_anima(material_id: String = "AnimaStone", anima_points: int = 0) -> Dictionary:
 var state := get_node_or_null("/root/GameState")
 if state == null: return _fail("gamestate_missing")
 var current_phase := int(state.anima_phase)
 if current_phase >= 18: return _fail("anima_maximum_reached")
 var points := maxi(0,anima_points)
 if points > 0:
  if int(state.player_data.get("anima_points",0)) < points: return _fail("anima_points_missing")
  state.player_data["anima_points"] = int(state.player_data.get("anima_points",0)) - points
 else:
  if not _consume_inventory(state,material_id,1): return _fail("anima_material_missing")
  points = int(ANIMA_POINTS_BY_MATERIAL.get(material_id,1))
 var required := int(ANIMA_REQUIREMENTS[current_phase + 1])
 var total := int(state.player_data.get("anima_progress",0)) + points
 if total < required:
  state.player_data["anima_progress"] = total
  _commit(state)
  return {"ok":true,"upgraded":false,"progress":total,"required":required}
 state.player_data["anima_progress"] = total - required
 state.set_anima_phase(current_phase + 1)
 _commit(state)
 var hero := get_tree().root.find_child("PlayableHero",true,false)
 if not hero is Node3D: hero = get_tree().root.find_child("TwinCityPlayableHero",true,false)
 var vfx := get_node_or_null("/root/AuraAndVFXManager")
 if vfx != null and hero is Node3D:
  vfx.attach_anima_aura(hero,current_phase + 1)
 anima_upgraded.emit(current_phase,current_phase + 1)
 forging_succeeded.emit("anima",{})
 return {"ok":true,"upgraded":true,"phase":current_phase + 1,"progress":int(state.player_data.get("anima_progress",0)),"required":required}

func _recalculate_item_stats(item: Dictionary) -> void:
 var base_attack := int(item.get("base_attack",0))
 var base_defense := int(item.get("base_defense",0))
 var plus := int(item.get("plus",0))
 var quality_multiplier := float(item.get("quality_attack_multiplier",1.0))
 if base_attack > 0:
  item["attack_bonus"] = int(round(float(base_attack + plus * 12) * quality_multiplier))
 if base_defense > 0:
  item["defense_bonus"] = base_defense + plus * 6

const ANIMA_POINTS_BY_MATERIAL := {"AnimaStone":1,"AnimaStoneP2":2,"AnimaStoneP3":3,"AnimaStoneP5":5}
const ANIMA_REQUIREMENTS := {1:1,2:2,3:3,4:4,5:5,6:6,7:7,8:8,9:9,10:10,11:11,12:12,13:13,14:14,15:15,16:16,17:17,18:18}

func _gold_cost(item: Dictionary,step: int,kind: String) -> int:
 var level := maxi(1,int(item.get("level",10)))
 match kind:
  "plus": return level*step*100
  "quality": return level*(step+1)*250
  "level": return level*100
  "socket": return level*step*1000
 return 0

func _consume_inventory(state: Node,item_id: String,amount: int) -> bool:
 var count := int(state.inventory.get(item_id,0))
 if count < amount: return false
 state.inventory[item_id] = count-amount
 if state.inventory[item_id] <= 0: state.inventory.erase(item_id)
 return true

func _spend_gold(state: Node,amount: int) -> bool:
 if int(state.gold) < amount: return false
 state.set_gold(int(state.gold)-amount)
 return true

func _display_name(item: Dictionary) -> String:
 return "%s Lv.%d %s +%d" % [String(item.get("family","weapon")).replace("_"," ").capitalize(),int(item.get("level",10)),String(item.get("quality","Normal")),int(item.get("plus",0))]

func _commit(state: Node) -> void:
 var gear := get_node_or_null("/root/GearSystem")
 if gear != null: state.player_data["equipped"] = gear.get("equipped").duplicate(true)
 state.player_data["inventory"] = state.inventory.duplicate(true)
 state.save_game()

func _fail(reason: String) -> Dictionary:
 last_error = reason
 forging_failed.emit(reason)
 forge_failed.emit(reason)
 return {"ok":false,"reason":reason}
