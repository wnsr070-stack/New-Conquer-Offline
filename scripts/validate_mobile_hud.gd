extends SceneTree

const MOBILE_HUD_SCRIPT = preload("res://scripts/MobileHUD.gd")

func _initialize() -> void:
	if MOBILE_HUD_SCRIPT == null:
		push_error("PHASE5A_MOBILE_HUD_PARSE_FAILED: preload returned null")
		quit(1)
		return
	print("PHASE5A_MOBILE_HUD_PARSE_OK")
	quit(0)
