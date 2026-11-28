extends SceneTree

const MonsterTable = preload("res://scripts/MonsterGeneratorTable.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var database: Variant = root.get_node_or_null("GearDatabase")
	var gear: Variant = root.get_node_or_null("GearSystem")
	var state: Variant = root.get_node_or_null("GameState")
	var quests: Variant = root.get_node_or_null("QuestSystem")
	var loot: Variant = root.get_node_or_null("LootDropManager")
	if database == null or gear == null or state == null or quests == null or loot == null:
		_fail("required_autoload_missing")
		return

	var wing: Dictionary = database.get_item("wing_sky_feather_p0")
	if wing.is_empty() or String(wing.get("slot", "")) != "wing":
		_fail("wing_catalog_item_missing_or_wrong_slot")
		return
	if int(database.get_item_price("wing_sky_feather_p0")) <= 0:
		_fail("wing_shop_price_missing")
		return
	var merchant: Variant = root.get_node_or_null("NPCMerchantSystem")
	if merchant == null:
		_fail("merchant_autoload_missing")
		return
	var shop_items: Array = merchant.get_shop_inventory("AccessoryMerchant")
	var wing_for_sale := false
	for shop_item in shop_items:
		if String(shop_item.get("id", "")) == "wing_sky_feather_p0":
			wing_for_sale = true
	if not wing_for_sale:
		_fail("wing_not_listed_in_accessory_shop")
		return
	if not gear.can_equip("wing_sky_feather_p0", String(state.player_data.get("class", "archer")), 120):
		_fail("wing_equip_validation_rejected_valid_item")
		return

	var original_equipment: Dictionary = gear.equipped.duplicate(true)
	gear.equipped.erase("wing")
	gear._persist_equipment()
	var before: Dictionary = gear.get_combat_bonuses()
	if not gear.equip_item("wing", wing):
		gear.equipped = original_equipment
		gear._persist_equipment()
		_fail("wing_equip_failed")
		return
	var equipped: Dictionary = gear.get_combat_bonuses()
	if int(equipped.get("attack", 0)) <= int(before.get("attack", 0)) or int(equipped.get("defense", 0)) <= int(before.get("defense", 0)) or int(equipped.get("max_hp", 0)) <= int(before.get("max_hp", 0)):
		gear.equipped = original_equipment
		gear._persist_equipment()
		_fail("wing_stats_not_applied")
		return
	if int(state.player_data.get("battle_power", 0)) <= 0:
		gear.equipped = original_equipment
		gear._persist_equipment()
		_fail("battle_power_not_recalculated")
		return
	if not gear.unequip_item("wing"):
		gear.equipped = original_equipment
		gear._persist_equipment()
		_fail("wing_unequip_failed")
		return
	var removed: Dictionary = gear.get_combat_bonuses()
	if int(removed.get("attack", 0)) != int(before.get("attack", 0)) or int(removed.get("defense", 0)) != int(before.get("defense", 0)) or int(removed.get("max_hp", 0)) != int(before.get("max_hp", 0)):
		gear.equipped = original_equipment
		gear._persist_equipment()
		_fail("wing_stats_not_removed")
		return
	gear.equipped = original_equipment
	gear._persist_equipment()

	var errors: PackedStringArray = MonsterTable.validate()
	if not errors.is_empty():
		_fail("monster_table_validation: " + str(errors))
		return
	if MonsterTable.camp_count() != 40:
		_fail("expected_40_monster_camps")
		return
	if float(MonsterTable.ACTIVATION_DISTANCE_M) != 45.0:
		_fail("monster_activation_radius_not_45m")
		return
	var previous := {"level": 0, "hp": 0, "damage": 0, "defense": 0, "exp": 0, "gold_min": 0, "gold_max": 0}
	for monster in MonsterTable.MONSTERS:
		for key in previous:
			if int(monster.get(key, 0)) <= int(previous[key]):
				_fail("monster_progression_not_strict: " + String(monster.id) + "/" + key)
				return
			previous[key] = int(monster.get(key, 0))
		for camp_size in monster.camp_sizes:
			if int(camp_size) < 35 or int(camp_size) > 40:
				_fail("camp_population_out_of_range: " + String(monster.id))
				return
	var major_bosses := 0
	for boss in MonsterTable.WORLD_BOSSES:
		if bool(boss.get("is_major_boss", false)):
			major_bosses += 1
	if major_bosses != 4:
		_fail("expected_four_major_world_bosses")
		return

	var reborn: Dictionary = MonsterTable.QUEST_BOSSES[0]
	if int(reborn.get("level", 0)) < 130 or String(reborn.get("id", "")) != "Reborn Guardian":
		_fail("reborn_quest_zone_boss_invalid")
		return
	var guaranteed: Array = loot.get_guaranteed_quest_drops(reborn)
	if guaranteed.size() != 8:
		_fail("reborn_guaranteed_drop_count_invalid")
		return
	for drop in guaranteed:
		if database.get_item(String(drop.get("item_id", ""))).is_empty():
			_fail("reborn_drop_item_missing_from_database: " + String(drop.get("item_id", "")))
			return
	var endgame: Array = quests.get_quest_catalog("ENDGAME_REBIRTH")
	var reborn_quest_found := false
	for quest in endgame:
		if String(quest.get("id", "")) == "end_celestial" and int(quest.get("level_min", 0)) >= 120:
			reborn_quest_found = true
	if not reborn_quest_found:
		_fail("level_120_reborn_quest_missing")
		return

	print("MONSTERS_AND_WINGS_SYSTEM_PASS=true wings=true stats=true equip_unequip=true camps=40 activation=45m active_cap=80 major_bosses=4 reborn_drops=8")
	quit(0)

func _fail(reason: String) -> void:
	push_error("MONSTERS_AND_WINGS_SYSTEM_FAIL: " + reason)
	quit(1)
