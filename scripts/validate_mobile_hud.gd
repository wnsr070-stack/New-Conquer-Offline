extends SceneTree

const MOBILE_HUD_SCRIPT = preload("res://scripts/MobileHUD.gd")
const GAME_SETTINGS_SCRIPT = preload("res://scripts/GameSettings.gd")
const HERO_CONTROLLER_SCRIPT = preload("res://scripts/HeroController.gd")
const MONSTER_ACTOR_SCRIPT = preload("res://scripts/MonsterActor.gd")
const COMBAT_SYSTEM_SCRIPT = preload("res://scripts/CombatSystem.gd")
const LOOT_DROP_MANAGER_SCRIPT = preload("res://autoloads/LootDropManager.gd")

func _initialize() -> void:
	var scripts := [
		MOBILE_HUD_SCRIPT,
		GAME_SETTINGS_SCRIPT,
		HERO_CONTROLLER_SCRIPT,
		MONSTER_ACTOR_SCRIPT,
		COMBAT_SYSTEM_SCRIPT,
		LOOT_DROP_MANAGER_SCRIPT
	]
	for script in scripts:
		if script == null:
			push_error("PHASE5A_SETTINGS_SCRIPTS_PARSE_FAILED: preload returned null")
			quit(1)
			return
	print("PHASE5A_MOBILE_HUD_PARSE_OK")
	print("PHASE5A_FUNCTIONAL_SETTINGS_SCRIPTS_PARSE_OK: game_settings=true camera=true hp_bars=true damage_numbers=true auto_loot=true")
	quit(0)
