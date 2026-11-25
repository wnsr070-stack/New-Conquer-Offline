extends Node
signal forge_succeeded(operation: String, item: Dictionary)
signal forge_failed(reason: String)

const PLUS_COMPOSITION := {1:20,2:40,3:80,4:160,5:320,6:640,7:1280,8:2560,9:5120,10:7680,11:10240,12:12800}
const QUALITY_ORDER := ["Normal","Refined","Unique","Elite","Super"]
const GEM_BONUSES := {
 "DragonGem":{"attack":25,"magic_attack":0,"damage_reduction":0,"exp_bonus":0},
 "PhoenixGem":{"attack":0,"magic_attack":25,"damage_reduction":0,"exp_bonus":0},
 "RainbowGem":{"attack":0,"magic_attack":0,"damage_reduction":0,"exp_bonus":0.10},
 "TortoiseGem":{"attack":0,"magic_attack":0,"damage_reduction":0.05,"exp_bonus":0}
}
var last_error := ""

func compose_plus(slot: String = "weapon", material_id: String = "Plus1Stone") -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 var state := get_node_or_null("/root/GameState")
 if gear == null or state == null: return _fail("forge_dependencies_missing")
 var item: Dictionary = gear.get_equipped(slot)
 if item.is_empty(): return _fail("no_equipped_item")
 var plus := int(item.get("plus",0))
 if plus >= 12: return _fail("plus_maximum_reached")
 if material_id not in ["Plus1Stone","plus1_equipment"]: return _fail("invalid_composition_material")
 if not _consume_inventory(state,material_id,1): return _fail("composition_material_missing")
 var next_plus := plus+1
 var points := int(PLUS_COMPOSITION[next_plus])
 var cost := _gold_cost(item,next_plus,"plus")
 if not _spend_gold(state,cost):
  state.add_inventory_item(material_id,1)
  return _fail("insufficient_gold")
 item["composition_points"] = int(item.get("composition_points",0))+points
 item["plus"] = next_plus
 item["attack_bonus"] = int(item.get("base_attack",80))+next_plus*12
 item["defense_bonus"] = int(item.get("base_defense",0))+next_plus*6
 item["display_name"] = _display_name(item)
 gear.update_equipped_item(slot,item)
 _commit(state)
 print("FORGE_PLUS_SUCCESS: slot=",slot," plus=+",next_plus," composition=+",points," gold=",cost)
 forge_succeeded.emit("plus",item)
 return {"ok":true,"item":item,"composition_added":points,"gold_spent":cost}

func upgrade_quality(slot: String = "weapon") -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 var state := get_node_or_null("/root/GameState")
 if gear == null or state == null: return _fail("forge_dependencies_missing")
 var item: Dictionary = gear.get_equipped(slot)
 if item.is_empty(): return _fail("no_equipped_item")
 var index := QUALITY_ORDER.find(String(item.get("quality","Normal")))
 if index < 0 or index >= QUALITY_ORDER.size()-1: return _fail("quality_maximum_reached")
 if not _consume_inventory(state,"Meteor",1): return _fail("meteor_missing")
 var cost := _gold_cost(item,index+1,"quality")
 if not _spend_gold(state,cost):
  state.add_inventory_item("Meteor",1)
  return _fail("insufficient_gold")
 item["quality"] = QUALITY_ORDER[index+1]
 item["quality_attack_multiplier"] = 1.0+float(index+1)*0.12
 item["attack_bonus"] = int(round(float(item.get("attack_bonus",80))*float(item["quality_attack_multiplier"])))
 item["display_name"] = _display_name(item)
 gear.update_equipped_item(slot,item)
 _commit(state)
 print("FORGE_QUALITY_SUCCESS: ",item.quality," gold=",cost)
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
 if not _consume_inventory(state,"Meteor",1): return _fail("meteor_missing")
 var cost := _gold_cost(item,level+10,"level")
 if not _spend_gold(state,cost):
  state.add_inventory_item("Meteor",1)
  return _fail("insufficient_gold")
 item["level"] = level+10
 item["base_attack"] = int(item.get("base_attack",80))+20
 item["attack_bonus"] = int(item.get("attack_bonus",80))+20
 item["display_name"] = _display_name(item)
 gear.update_equipped_item(slot,item)
 _commit(state)
 print("FORGE_LEVEL_SUCCESS: level=",item.level," gold=",cost)
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
 if not _consume_inventory(state,"DragonBall",1): return _fail("dragon_ball_missing")
 var cost := _gold_cost(item,sockets.size()+1,"socket")
 if not _spend_gold(state,cost):
  state.add_inventory_item("DragonBall",1)
  return _fail("insufficient_gold")
 sockets.append("")
 item["sockets"] = sockets
 gear.update_equipped_item(slot,item)
 _commit(state)
 print("FORGE_SOCKET_OPENED: slot=",slot," socket=",sockets.size())
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
 forge_succeeded.emit("gem",item)
 return {"ok":true,"item":item}

func get_plus_aura_level(item: Dictionary) -> int:
 var plus := int(item.get("plus",0))
 return 0 if plus < 3 else 1 if plus < 6 else 2 if plus < 9 else 3 if plus < 12 else 4

func apply_equipped_weapon_aura(hero: Node3D) -> bool:
 if hero == null: return false
 var gear := get_node_or_null("/root/GearSystem")
 if gear == null: return false
 var item: Dictionary = gear.get_equipped("weapon")
 var aura_level := get_plus_aura_level(item)
 var weapon_nodes: Array = hero.get("weapon_nodes") if hero.get("weapon_nodes") is Array else []
 var applied := false
 for socket in weapon_nodes:
  if not is_instance_valid(socket): continue
  var weapon := socket.get_child(0) as Node3D if socket.get_child_count()>0 else null
  if weapon == null: continue
  _clear_aura(weapon)
  if aura_level <= 0: continue
  _apply_aura_to_meshes(weapon,aura_level)
  var aura := OmniLight3D.new()
  aura.name = "ForgingPlusAuraLight"
  aura.light_color = Color(0.25,0.78,1.0) if aura_level < 3 else Color(0.7,0.28,1.0)
  aura.light_energy = 0.45+float(aura_level)*0.55
  aura.omni_range = 1.2+float(aura_level)*0.35
  aura.position = Vector3.ZERO
  weapon.add_child(aura)
  var particles := GPUParticles3D.new()
  particles.name = "ForgingPlusAuraParticles"
  particles.amount = 12+aura_level*8
  particles.lifetime = 0.8
  particles.emitting = true
  var process := ParticleProcessMaterial.new()
  process.direction = Vector3(0,1,0)
  process.spread = 180.0
  process.initial_velocity_min = 0.08
  process.initial_velocity_max = 0.35+float(aura_level)*0.12
  process.gravity = Vector3(0,0,0)
  process.scale_min = 0.025
  process.scale_max = 0.06+float(aura_level)*0.012
  particles.process_material = process
  var sphere := SphereMesh.new()
  sphere.radius = 0.035+float(aura_level)*0.008
  sphere.height = sphere.radius*2.0
  var particle_mat := StandardMaterial3D.new()
  particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  particle_mat.albedo_color = aura.light_color
  particle_mat.emission_enabled = true
  particle_mat.emission = aura.light_color
  particle_mat.emission_energy_multiplier = 1.5+float(aura_level)*0.8
  sphere.material = particle_mat
  particles.draw_pass_1 = sphere
  weapon.add_child(particles)
  applied = true
 print("FORGE_AURA_APPLIED: plus=",item.get("plus",0)," level=",aura_level," applied=",applied)
 return applied

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
    aura_material.emission_energy_multiplier = 0.35+float(level)*0.55
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
 var result := {"attack":0,"magic_attack":0,"damage_reduction":0.0,"exp_bonus":0.0}
 for gem in sockets:
  if GEM_BONUSES.has(String(gem)):
   for key in GEM_BONUSES[gem]: result[key] += GEM_BONUSES[gem][key]
 return result

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
 forge_failed.emit(reason)
 return {"ok":false,"reason":reason}
