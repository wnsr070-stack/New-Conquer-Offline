extends SceneTree
func _initialize()->void:
	call_deferred("_run")
func _run()->void:
	await process_frame
	var manager:=root.get_node_or_null("LootDropManager")
	var state:=root.get_node_or_null("GameState")
	if manager==null or state==null: _fail("required_autoload_missing"); return
	if not manager.is_asset_manifest_valid(): _fail("145_hf_assets_not_verified: "+str(manager.get_asset_manifest_summary())); return
	var summary:Dictionary=manager.get_asset_manifest_summary()
	if int(summary.get("assets",0))!=145 or int(summary.get("models",0))!=12 or int(summary.get("icons",0))!=131: _fail("hf_manifest_count_mismatch: "+str(summary)); return
	if manager.get_gold_visual_variant(999)!="gold_small" or manager.get_gold_visual_variant(1000)!="gold_medium" or manager.get_gold_visual_variant(9999)!="gold_medium" or manager.get_gold_visual_variant(10000)!="gold_large": _fail("gold_stack_thresholds_invalid"); return
	if manager.get_lifetime_for_item("Gold")!=60.0 or manager.get_lifetime_for_item("Meteor")!=120.0 or manager.get_lifetime_for_item("DragonBall")!=120.0 or manager.get_lifetime_for_item("SuperGear","Super")!=120.0: _fail("loot_expiry_rules_invalid"); return
	var hero:=Node3D.new()
	hero.name="LootTestHero"
	hero.global_position=Vector3(100,0,100)
	root.add_child(hero)
	var gold_before:=int(state.gold)
	var gold_drop:Node3D=manager.spawn_drop({"item_id":"Gold","item_type":"Gold","amount":999,"rarity":"Normal"},Vector3.ZERO)
	if gold_drop==null: _fail("gold_drop_spawn_failed"); return
	var scatter:=gold_drop.global_position.distance_to(Vector3.ZERO)
	if scatter<1.49 or scatter>3.51: _fail("gold_drop_scatter_out_of_range: "+str(scatter)); return
	if gold_drop.get_node_or_null("LootSpriteAura")==null: _fail("gold_drop_aura_missing"); return
	var gold_id:=String(gold_drop.get_meta("loot_drop_id",""))
	hero.global_position=gold_drop.global_position+Vector3(2.1,0,0)
	if manager.try_auto_loot(hero)!=1 or int(state.gold)!=gold_before+999: _fail("gold_auto_pickup_failed"); return
	if manager.collect_drop(gold_id) or int(state.gold)!=gold_before+999: _fail("duplicate_gold_pickup_not_blocked"); return
	var meteor_before:=int(state.inventory.get("Meteor",0))
	hero.global_position=Vector3(100,0,100)
	var meteor_drop:Node3D=manager.spawn_drop({"item_id":"Meteor","item_type":"Meteor","amount":1,"rarity":"Super"},Vector3(5,0,5))
	if meteor_drop==null or meteor_drop.get_node_or_null("LootSpriteAura")==null: _fail("meteor_model_or_aura_missing"); return
	var meteor_id:=String(meteor_drop.get_meta("loot_drop_id",""))
	hero.global_position=meteor_drop.global_position
	if manager.try_auto_loot(hero)!=1 or int(state.inventory.get("Meteor",0))!=meteor_before+1: _fail("meteor_inventory_pickup_failed"); return
	if manager.collect_drop(meteor_id) or int(state.inventory.get("Meteor",0))!=meteor_before+1: _fail("duplicate_meteor_pickup_not_blocked"); return
	var dragonball:Node3D=manager.spawn_drop({"item_id":"DragonBall","item_type":"Dragon Ball","amount":1,"rarity":"Super"},Vector3.ZERO)
	var gem:Node3D=manager.spawn_drop({"item_id":"DragonGem","item_type":"Gems","amount":1,"rarity":"Elite"},Vector3.ZERO)
	var potion:Node3D=manager.spawn_drop({"item_id":"HPPotion","item_type":"Potions","amount":2,"rarity":"Refined"},Vector3.ZERO)
	var gear:Node3D=manager.spawn_drop({"item_id":"GearBox","item_type":"Gear","amount":1,"rarity":"Unique"},Vector3.ZERO)
	if dragonball==null or gem==null or potion==null or gear==null: _fail("supported_loot_category_spawn_failed"); return
	if manager.get_active_drop_count()!=4: _fail("category_drop_tracking_count_invalid"); return
	print("PHASE4D_LOOT_DROP_TEST_OK: hf_assets=145 gold_thresholds=true scatter=1.5-3.5 auto_loot=2.2m duplicate_guard=true categories=6 timers=60/120 aura_labels=true")
	manager.clear_cache()
	hero.free()
	quit(0)
func _fail(reason:String)->void:
	push_error("PHASE4D_LOOT_DROP_TEST_FAILED: "+reason)
	var manager:=root.get_node_or_null("LootDropManager")
	if manager!=null and manager.has_method("clear_cache"): manager.clear_cache()
	quit(1)
