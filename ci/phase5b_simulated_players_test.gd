extends SceneTree

const SimulatedPlayers = preload("res://scripts/SimulatedPlayersSystem.gd")

var chat_events: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var system: Node = root.get_node_or_null("SimulatedPlayersSystem")
	if system == null:
		system = SimulatedPlayers.new()
		root.add_child(system)
		await process_frame
	if system == null:
		_fail("simulated_players_autoload_missing")
		return
	var report: Dictionary = system.validate_phase5b_contract()
	if not bool(report.get("ok", false)):
		_fail("contract_validation: " + str(report))
		return
	var summary: Dictionary = system.get_population_summary()
	var selected: Array = system.select_active_entries("TwinCity", Vector3(0.0, 0.0, -49.0))
	if selected.size() > 30:
		_fail("active_player_cap_exceeded")
		return
	var visible_hunters := 0
	for selected_entry in selected:
		if bool(selected_entry.get("hunter", false)):
			visible_hunters += 1
	if visible_hunters != 4:
		_fail("nearby_hunter_visibility_not_guaranteed")
		return
	var counts: Dictionary = summary.get("counts", {})
	if int(summary.get("total", 0)) != 85:
		_fail("expected_85_total_players")
		return
	if int(counts.get("TwinCity", 0)) != 30:
		_fail("twin_city_population_not_30")
		return
	for city in ["PhoenixCastle", "ApeMountain", "DesertCity", "BirdIsland"]:
		if int(counts.get(city, 0)) != 10:
			_fail("subcity_population_not_10: " + city)
			return
	if int(counts.get("Wilderness", 0)) != 15:
		_fail("wilderness_hunters_not_15")
		return
	if int(summary.get("active_cap", 0)) != 30 or float(summary.get("radius_m", 0.0)) != 55.0:
		_fail("proximity_or_active_cap_invalid")
		return
	if not system.simulated_chat_message.is_connected(_on_chat_message):
		system.simulated_chat_message.connect(_on_chat_message)
	var chat_record: Dictionary = system.post_simulated_chat_message("trade")
	if String(chat_record.get("channel", "")) != "trade" or String(chat_record.get("message", "")).is_empty():
		_fail("trade_chat_feed_not_updated")
		return
	if chat_events.size() != 1:
		_fail("chat_signal_not_emitted")
		return
	var target: Vector3 = system.make_wander_target(Vector3.ZERO, 5.0)
	if target.length() <= 0.01:
		_fail("city_movement_target_not_generated")
		return
	var moved: Vector3 = system.step_towards(Vector3.ZERO, Vector3(5.0, 0.0, 0.0), 2.0, 1.0)
	if moved.x <= 0.0 or moved.x > 2.01:
		_fail("movement_step_not_applied")
		return
	var recent: String = system.get_recent_chat_text(4)
	if recent.is_empty() or not recent.contains("trade"):
		_fail("chat_history_not_updated")
		return
	print("PHASE5B_SIMULATED_PLAYERS_PASS=true total=85 twin_city=30 subcities=40 wilderness=15 active_cap=30 activation=55m hunters_visible=4 movement=true chat=true visual_only_combat=true")
	quit(0)

func _on_chat_message(channel: String, speaker: String, message: String) -> void:
	chat_events.append({"channel": channel, "speaker": speaker, "message": message})

func _fail(reason: String) -> void:
	push_error("PHASE5B_SIMULATED_PLAYERS_FAIL: " + reason)
	quit(1)
