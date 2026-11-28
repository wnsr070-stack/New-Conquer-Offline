extends Node
signal loot_dropped(drop_node: Node3D,item_data: Dictionary)
signal loot_collected(item_data: Dictionary)
const AUTO_LOOT_DISTANCE:=2.2
const NORMAL_DESPAWN_SECONDS:=60.0
const RARE_DESPAWN_SECONDS:=120.0
const ASSET_MANIFEST_PATH:="res://assets/items_and_consumables/asset_manifest.json"
const MODEL_ROOT:="res://assets/items_and_consumables/models/"
const MODEL_BY_TYPE:={"gold_small":"gold_coin_single.glb","gold_medium":"gold_stack.glb","gold_large":"gold_chest.glb","meteor":"meteor.glb","dragon_ball":"upgrade_crystal.glb","gem":"dragon_gem_crystal.glb","potion":"potion_green_bottle.glb","gear":"treasure_chest.glb"}
const RARITY_COLORS:={"normal":Color(1,1,1),"refined":Color(0.22,0.62,1),"refinedblue":Color(0.22,0.62,1),"unique":Color(0.18,0.95,0.34),"uniquegreen":Color(0.18,0.95,0.34),"elite":Color(1,0.20,0.16),"elitered":Color(1,0.20,0.16),"super":Color(1,0.78,0.16),"meteor":Color(1,0.78,0.16),"dragonball":Color(1,0.78,0.16)}
var _rng:=RandomNumberGenerator.new()
var _drops:Dictionary={}
var _next_drop_id:=1
var _asset_manifest_summary:Dictionary={"assets":0,"models":0,"icons":0,"missing":0}
var _asset_manifest_valid:=false

func _ready()->void:
	_rng.randomize()
	_load_asset_manifest()
	set_process(true)
	print("PHASE4D_LOOT_DROP_MANAGER_READY: auto_loot=2.2m scatter=1.5-3.5m normal_ttl=60s rare_ttl=120s")

func _process(delta:float)->void:
	_tick_despawn(delta)
	var hero:=_find_hero()
	var settings:=get_node_or_null("/root/GameSettings")
	if hero!=null and (settings==null or bool(settings.get_setting("auto_loot",true))): try_auto_loot(hero)

func _find_hero()->Node3D:
	var hero:=get_tree().root.find_child("PlayableHero",true,false)
	if hero is Node3D: return hero as Node3D
	hero=get_tree().root.find_child("TwinCityPlayableHero",true,false)
	return hero as Node3D if hero is Node3D else null

func _load_asset_manifest()->void:
	_asset_manifest_valid=false
	if not FileAccess.file_exists(ASSET_MANIFEST_PATH):
		push_warning("PHASE4D_LOOT_ASSET_MANIFEST_MISSING: "+ASSET_MANIFEST_PATH)
		return
	var file:=FileAccess.open(ASSET_MANIFEST_PATH,FileAccess.READ)
	if file==null: push_warning("PHASE4D_LOOT_ASSET_MANIFEST_UNREADABLE"); return
	var parsed:Variant=JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary: push_warning("PHASE4D_LOOT_ASSET_MANIFEST_INVALID"); return
	var assets:Array=parsed.get("assets",[])
	var models:=0
	var icons:=0
	var missing:=0
	for entry in assets:
		if not entry is Dictionary: continue
		var path:=String(entry.get("path",""))
		if path.ends_with(".glb"): models+=1
		elif path.ends_with(".png"): icons+=1
		if path.is_empty() or not FileAccess.file_exists("res://"+path.trim_prefix("res://")): missing+=1
	_asset_manifest_summary={"assets":assets.size(),"models":models,"icons":icons,"missing":missing}
	_asset_manifest_valid=assets.size()==145 and models==12 and icons==131 and missing==0
	print("PHASE4D_LOOT_ASSET_MANIFEST_CHECK: assets=",assets.size()," models=",models," icons=",icons," missing=",missing)
	if not _asset_manifest_valid: push_warning("PHASE4D_LOOT_ASSET_MANIFEST_NOT_COMPLETE: "+str(_asset_manifest_summary))

func get_asset_manifest_summary()->Dictionary: return _asset_manifest_summary.duplicate(true)
func is_asset_manifest_valid()->bool: return _asset_manifest_valid
func get_supported_drop_categories()->Array[String]: return ["Gold","Meteor","Dragon Ball","Gems","Potions","Gear"]
func get_gold_visual_variant(amount:int)->String:
	if amount>=10000: return "gold_large"
	if amount>=1000: return "gold_medium"
	return "gold_small"
func get_lifetime_for_item(item_id:String,rarity:String="Normal")->float:
	var normalized:=item_id.to_lower().replace(" ","").replace("_","")
	return RARE_DESPAWN_SECONDS if normalized in ["meteor","dragonball"] or rarity.to_lower()=="super" else NORMAL_DESPAWN_SECONDS

func on_monster_killed(monster:Node3D)->int:
	if monster==null or not is_instance_valid(monster): return 0
	var origin:=monster.global_position
	var is_boss:=bool(monster.get("is_king")) or bool(monster.get("is_boss"))
	var spawned:=0
	var gold_roll:=_rng.randf()
	var definition: Dictionary = monster.get("definition") if monster.get("definition") is Dictionary else {}
	if is_boss or gold_roll<0.88:
		var gold_min := maxi(1,int(definition.get("gold_min",1)))
		var gold_max := maxi(gold_min,int(definition.get("gold_max",999)))
		var amount := _rng.randi_range(gold_min,gold_max)
		if spawn_drop({"item_id":"Gold","item_type":"Gold","amount":amount,"rarity":"Normal"},origin)!=null: spawned+=1
	if _rng.randf()<(0.30 if is_boss else 0.045):
		if spawn_drop({"item_id":"Meteor","item_type":"Meteor","amount":1,"rarity":"Super"},origin)!=null: spawned+=1
	if _rng.randf()<(0.025 if is_boss else 0.0015):
		if spawn_drop({"item_id":"DragonBall","item_type":"Dragon Ball","amount":1,"rarity":"Super"},origin)!=null: spawned+=1
	if _rng.randf()<(0.32 if is_boss else 0.10):
		var gem_id := String(["DragonGem","PhoenixGem","RainbowGem","VioletGem","MoonGem"][_rng.randi_range(0,4)])
		if spawn_drop({"item_id":gem_id,"item_type":"Gems","amount":1,"rarity":"Elite"},origin)!=null: spawned+=1
	if _rng.randf()<(0.40 if is_boss else 0.16):
		var potion_id := String(["HPPotion","MPPotion","Panacea"][_rng.randi_range(0,2)])
		if spawn_drop({"item_id":potion_id,"item_type":"Potions","amount":_rng.randi_range(1,3),"rarity":"Refined"},origin)!=null: spawned+=1
	if _rng.randf()<(0.06 if is_boss else 0.008):
		var material := String(["EuxeniteOre","RebuildOre","CleanWater","PeaceCommandToken","ChaosCommandToken","DesertedCommandToken","ProsperousCommandToken","DisturbedCommandToken","CalmedCommandToken"][_rng.randi_range(0,8)])
		if spawn_drop({"item_id":material,"item_type":"Quest Material","amount":1,"rarity":"Refined"},origin)!=null: spawned+=1
	if is_boss and _rng.randf()<0.12:
		if spawn_drop({"item_id":"MountBox","item_type":"Mount Treasure Box","amount":1,"rarity":"Super"},origin)!=null: spawned+=1
	if is_boss and _rng.randf()<0.12:
		if spawn_drop({"item_id":"GarmentBox","item_type":"Garment Treasure Box","amount":1,"rarity":"Super"},origin)!=null: spawned+=1
	if is_boss and _rng.randf()<0.02:
		var relic := String(["SoulJade","MoonBox","CelestialStone","HeavenFan","StarTower","ThunderGem","GloryGem"][_rng.randi_range(0,6)])
		if spawn_drop({"item_id":relic,"item_type":"Quest Relic","amount":1,"rarity":"Super"},origin)!=null: spawned+=1
	if _rng.randf()<(0.24 if is_boss else 0.035):
		var gear_id := String(["GearBox","RandomWeapon","RandomArmor"][_rng.randi_range(0,2)])
		var quality := String(["Unique","Elite","Super"][_rng.randi_range(0,2)])
		if spawn_drop({"item_id":gear_id,"item_type":"Gear","amount":1,"rarity":quality},origin)!=null: spawned+=1
	var guaranteed: Array = get_guaranteed_quest_drops(definition)
	for quest_drop in guaranteed:
		if spawn_drop(quest_drop,origin)!=null: spawned+=1
	print("PHASE4D_MONSTER_LOOT_ROLLED: monster=",monster.name," boss=",is_boss," drops=",spawned)
	return spawned

func spawn_drop(item_data:Dictionary,world_origin:Vector3)->Node3D:
	var item_id:=String(item_data.get("item_id",""))
	if item_id.is_empty(): return null
	var item_type:=String(item_data.get("item_type",item_id))
	var amount:=maxi(1,int(item_data.get("amount",1)))
	var rarity:=String(item_data.get("rarity","Normal"))
	var model_key:=_model_key(item_id,item_type,amount)
	var model_path:=MODEL_ROOT+String(MODEL_BY_TYPE.get(model_key,"treasure_chest.glb"))
	if not ResourceLoader.exists(model_path): push_warning("PHASE4D_LOOT_MODEL_MISSING: "+model_path); return null
	var packed:=load(model_path) as PackedScene
	if packed==null: push_warning("PHASE4D_LOOT_MODEL_INVALID: "+model_path); return null
	var model:=packed.instantiate() as Node3D
	if model==null: return null
	var parent:Node=get_tree().current_scene
	if parent==null: parent=get_tree().root
	var drop_id:="loot_%08d" % _next_drop_id
	_next_drop_id+=1
	model.name="GroundLoot_"+drop_id
	parent.add_child(model)
	var angle:=_rng.randf_range(0.0,TAU)
	var radius:=_rng.randf_range(1.5,3.5)
	model.global_position=world_origin+Vector3(cos(angle)*radius,0.12,sin(angle)*radius)
	model.scale=Vector3.ONE*(0.28 if model_key.begins_with("gold_") else 0.34)
	model.set_meta("loot_drop_id",drop_id)
	var lifetime:=get_lifetime_for_item(item_id,rarity)
	var data:=item_data.duplicate(true)
	data["item_id"]=item_id
	data["item_type"]=item_type
	data["amount"]=amount
	data["rarity"]=rarity
	data["drop_id"]=drop_id
	data["lifetime"]=lifetime
	var vfx:=get_node_or_null("/root/AuraAndVFXManager")
	if vfx!=null and vfx.has_method("attach_loot_aura"): vfx.attach_loot_aura(model,rarity,item_type)
	_add_floating_name(model,data)
	_drops[drop_id]={"node":model,"data":data,"remaining":lifetime}
	loot_dropped.emit(model,data.duplicate(true))
	print("PHASE4D_LOOT_DROP_CREATED: id=",drop_id," item=",item_id," amount=",amount," rarity=",rarity," scatter_m=",snappedf(radius,0.01)," ttl=",lifetime)
	return model

func _model_key(item_id:String,item_type:String,amount:int)->String:
	if item_id=="Gold": return get_gold_visual_variant(amount)
	var normalized: String=(item_id+" "+item_type).to_lower()
	if "meteor" in normalized: return "meteor"
	if "dragonball" in normalized or "dragon ball" in normalized: return "dragon_ball"
	if "gem" in normalized: return "gem"
	if "potion" in normalized or "panacea" in normalized or "hp" in normalized or "mp" in normalized: return "potion"
	return "gear"

func _add_floating_name(model:Node3D,data:Dictionary)->void:
	var label:=Label3D.new()
	label.name="GroundLootName"
	var item_name:=String(data.get("item_type",data.get("item_id","Item")))
	var amount:=int(data.get("amount",1))
	label.text=item_name+(" x"+str(amount) if amount>1 else "")
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=true
	label.font_size=38
	label.pixel_size=0.007
	label.outline_size=6
	label.modulate=_rarity_color(String(data.get("rarity","Normal")))
	label.position=Vector3(0.0,0.82,0.0)
	model.add_child(label)

func _rarity_color(rarity:String)->Color:
	var key:=rarity.to_lower().replace("/","").replace(" ","")
	return RARITY_COLORS.get(key,RARITY_COLORS.normal)

func try_auto_loot(hero:Node3D)->int:
	if hero==null or not is_instance_valid(hero): return 0
	var collected:=0
	for drop_id in _drops.keys():
		if not _drops.has(drop_id): continue
		var record:Dictionary=_drops[drop_id]
		var node:=record.get("node") as Node3D
		if node==null or not is_instance_valid(node):
			_drops.erase(drop_id)
			continue
		if hero.global_position.distance_to(node.global_position)<=AUTO_LOOT_DISTANCE and collect_drop(String(drop_id)): collected+=1
	return collected

func collect_drop(drop_id:String)->bool:
	if not _drops.has(drop_id): return false
	var record:Dictionary=_drops[drop_id]
	var state:=get_node_or_null("/root/GameState")
	if state==null: return false
	var node:=record.get("node") as Node3D
	var data:Dictionary=record.get("data",{}).duplicate(true)
	var item_id:=String(data.get("item_id",""))
	var amount:=maxi(1,int(data.get("amount",1)))
	if item_id=="Gold":
		state.add_gold(amount)
	elif not state.add_item(item_id,amount):
		return false
	_drops.erase(drop_id)
	if state.has_method("save_game"): state.save_game()
	if node!=null and is_instance_valid(node): node.queue_free()
	loot_collected.emit(data)
	print("PHASE4D_LOOT_AUTO_PICKUP_OK: id=",drop_id," item=",item_id," amount=",amount," gold=",state.gold," inventory_count=",state.inventory.size())
	return true

func _tick_despawn(delta:float)->void:
	for drop_id in _drops.keys():
		if not _drops.has(drop_id): continue
		var record:Dictionary=_drops[drop_id]
		record["remaining"]=float(record.get("remaining",0.0))-delta
		if float(record["remaining"])<=0.0:
			var node:=record.get("node") as Node3D
			_drops.erase(drop_id)
			if node!=null and is_instance_valid(node): node.queue_free()
			print("PHASE4D_LOOT_DESPAWNED: id=",drop_id)

func get_active_drop_count()->int: return _drops.size()
func clear_cache()->void:
	set_process(false)
	for record in _drops.values():
		var node:=record.get("node") as Node3D
		if node!=null and is_instance_valid(node): node.free()
	_drops.clear()
	print("PHASE4D_LOOT_DROP_MANAGER_CLEARED")
func _exit_tree()->void: clear_cache()

func get_guaranteed_quest_drops(definition: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in definition.get("quest_drop_items", []):
		var normalized := String(item_id)
		if normalized.is_empty(): continue
		var item_type := "Gems" if normalized.ends_with("Gem") else "Quest Material"
		result.append({"item_id":normalized,"item_type":item_type,"amount":1,"rarity":"Super","guaranteed":true})
	return result
