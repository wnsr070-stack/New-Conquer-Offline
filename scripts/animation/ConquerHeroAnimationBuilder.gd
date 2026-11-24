@tool
extends SceneTree
## Builds the shared Conquer animation library from the normalized Phase 3B humanoid skeleton.
## Run: Godot_v4.3 --headless --path . --script res://scripts/animation/ConquerHeroAnimationBuilder.gd

const OUTPUT := "res://assets/phase4/animations/conquer_hero_anims.res"
const BONES := [
	"pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
	"clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r",
	"lowerarm_l", "lowerarm_r", "hand_l", "hand_r",
	"thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r"
]
const CLIPS := ["Idle", "Run", "Jump", "Attack_Trojan", "Attack_Assassin",
	"Attack_SwordShield", "Attack_Bow", "Attack_Staff", "Hit", "Death"]

# Bone rotations are authored in degrees around local X/Y/Z. Each pose is a sparse
# override; unspecified bones remain at the imported bind pose.
const POSES := {
	"Idle": [
		{"t": 0.0, "p": {"upperarm_l": Vector3(-24, 0, -8), "upperarm_r": Vector3(-24, 0, 8), "lowerarm_l": Vector3(-18, 0, -5), "lowerarm_r": Vector3(-18, 0, 5), "pelvis": Vector3(0, 0, 0), "spine_01": Vector3(-3, 0, 0)}},
		{"t": 0.55, "p": {"upperarm_l": Vector3(-20, 0, -7), "upperarm_r": Vector3(-20, 0, 7), "lowerarm_l": Vector3(-22, 0, -4), "lowerarm_r": Vector3(-22, 0, 4), "spine_01": Vector3(-2, 0, 0)}}
	],
	"Run": [
		{"t": 0.0, "p": {"upperarm_l": Vector3(-55, 0, -12), "upperarm_r": Vector3(48, 0, 12), "lowerarm_l": Vector3(-65, 0, 0), "lowerarm_r": Vector3(-58, 0, 0), "thigh_l": Vector3(48, 0, 0), "thigh_r": Vector3(-42, 0, 0), "calf_l": Vector3(-18, 0, 0), "calf_r": Vector3(38, 0, 0), "spine_01": Vector3(10, 0, 0)}},
		{"t": 0.25, "p": {"upperarm_l": Vector3(48, 0, -12), "upperarm_r": Vector3(-55, 0, 12), "lowerarm_l": Vector3(-58, 0, 0), "lowerarm_r": Vector3(-65, 0, 0), "thigh_l": Vector3(-42, 0, 0), "thigh_r": Vector3(48, 0, 0), "calf_l": Vector3(38, 0, 0), "calf_r": Vector3(-18, 0, 0), "spine_01": Vector3(10, 0, 0)}},
		{"t": 0.5, "p": {"upperarm_l": Vector3(-55, 0, -12), "upperarm_r": Vector3(48, 0, 12), "lowerarm_l": Vector3(-65, 0, 0), "lowerarm_r": Vector3(-58, 0, 0), "thigh_l": Vector3(48, 0, 0), "thigh_r": Vector3(-42, 0, 0), "calf_l": Vector3(-18, 0, 0), "calf_r": Vector3(38, 0, 0), "spine_01": Vector3(10, 0, 0)}}
	],
	"Jump": [
		{"t": 0.0, "p": {"upperarm_l": Vector3(-85, 0, -35), "upperarm_r": Vector3(-85, 0, 35), "lowerarm_l": Vector3(-12, 0, 0), "lowerarm_r": Vector3(-12, 0, 0), "thigh_l": Vector3(-48, 0, 0), "thigh_r": Vector3(-48, 0, 0), "calf_l": Vector3(78, 0, 0), "calf_r": Vector3(78, 0, 0), "spine_01": Vector3(-8, 0, 0)}},
		{"t": 0.38, "p": {"upperarm_l": Vector3(-100, 0, -42), "upperarm_r": Vector3(-100, 0, 42), "lowerarm_l": Vector3(-8, 0, 0), "lowerarm_r": Vector3(-8, 0, 0), "thigh_l": Vector3(-55, 0, 0), "thigh_r": Vector3(-55, 0, 0), "calf_l": Vector3(92, 0, 0), "calf_r": Vector3(92, 0, 0), "spine_01": Vector3(-12, 0, 0)}},
		{"t": 0.8, "p": {"upperarm_l": Vector3(-85, 0, -35), "upperarm_r": Vector3(-85, 0, 35), "lowerarm_l": Vector3(-12, 0, 0), "lowerarm_r": Vector3(-12, 0, 0), "thigh_l": Vector3(-48, 0, 0), "thigh_r": Vector3(-48, 0, 0), "calf_l": Vector3(78, 0, 0), "calf_r": Vector3(78, 0, 0), "spine_01": Vector3(-8, 0, 0)}}
	],
	"Attack_Trojan": [
		{"t": 0.0, "p": {"spine_01": Vector3(-12, -8, 0), "upperarm_l": Vector3(-72, 0, -24), "upperarm_r": Vector3(-72, 0, 24), "lowerarm_l": Vector3(-75, 0, 0), "lowerarm_r": Vector3(-75, 0, 0), "thigh_l": Vector3(-12, 0, 0), "thigh_r": Vector3(12, 0, 0)}},
		{"t": 0.18, "p": {"spine_01": Vector3(24, 18, 0), "spine_02": Vector3(12, 0, 0), "upperarm_l": Vector3(42, 0, -42), "upperarm_r": Vector3(42, 0, 42), "lowerarm_l": Vector3(-28, 0, 0), "lowerarm_r": Vector3(-28, 0, 0), "thigh_l": Vector3(15, 0, 0), "thigh_r": Vector3(-15, 0, 0)}},
		{"t": 0.42, "p": {"spine_01": Vector3(-8, -5, 0), "upperarm_l": Vector3(-28, 0, -30), "upperarm_r": Vector3(-28, 0, 30), "lowerarm_l": Vector3(-48, 0, 0), "lowerarm_r": Vector3(-48, 0, 0)}}
	],
	"Attack_Assassin": [
		{"t": 0.0, "p": {"spine_01": Vector3(-8, -15, 0), "upperarm_l": Vector3(-30, 0, -52), "upperarm_r": Vector3(-30, 0, 52), "lowerarm_l": Vector3(-75, 0, 0), "lowerarm_r": Vector3(-75, 0, 0), "thigh_l": Vector3(-12, 0, 0), "thigh_r": Vector3(20, 0, 0)}},
		{"t": 0.12, "p": {"spine_01": Vector3(18, 22, 0), "upperarm_l": Vector3(62, 0, -30), "upperarm_r": Vector3(72, 0, 30), "lowerarm_l": Vector3(-18, 0, 0), "lowerarm_r": Vector3(-12, 0, 0), "thigh_l": Vector3(24, 0, 0), "thigh_r": Vector3(-22, 0, 0)}},
		{"t": 0.28, "p": {"spine_01": Vector3(-5, -18, 0), "upperarm_l": Vector3(-45, 0, -38), "upperarm_r": Vector3(-55, 0, 38), "lowerarm_l": Vector3(-35, 0, 0), "lowerarm_r": Vector3(-28, 0, 0)}}
	],
	"Attack_SwordShield": [
		{"t": 0.0, "p": {"upperarm_l": Vector3(-30, 0, -42), "upperarm_r": Vector3(-65, 0, 18), "lowerarm_l": Vector3(-55, 0, 0), "lowerarm_r": Vector3(-30, 0, 0), "spine_01": Vector3(-5, -8, 0)}},
		{"t": 0.2, "p": {"upperarm_l": Vector3(-18, 0, -58), "upperarm_r": Vector3(48, 0, 20), "lowerarm_l": Vector3(-45, 0, 0), "lowerarm_r": Vector3(-20, 0, 0), "spine_01": Vector3(18, 12, 0)}},
		{"t": 0.45, "p": {"upperarm_l": Vector3(-30, 0, -42), "upperarm_r": Vector3(-40, 0, 18), "lowerarm_l": Vector3(-55, 0, 0), "lowerarm_r": Vector3(-35, 0, 0), "spine_01": Vector3(-5, -8, 0)}}
	],
	"Attack_Bow": [
		{"t": 0.0, "p": {"spine_01": Vector3(-4, -8, 0), "clavicle_l": Vector3(0, 0, -8), "clavicle_r": Vector3(0, 0, 8), "upperarm_l": Vector3(-82, 0, -18), "upperarm_r": Vector3(-82, 0, 18), "lowerarm_l": Vector3(-8, 0, 0), "lowerarm_r": Vector3(-8, 0, 0)}},
		{"t": 0.32, "p": {"spine_01": Vector3(0, 0, 0), "upperarm_l": Vector3(-88, 0, -12), "upperarm_r": Vector3(-105, 0, 12), "lowerarm_l": Vector3(-4, 0, 0), "lowerarm_r": Vector3(-72, 0, 0), "hand_r": Vector3(0, 0, 12)}},
		{"t": 0.55, "p": {"spine_01": Vector3(8, 4, 0), "upperarm_l": Vector3(-82, 0, -18), "upperarm_r": Vector3(-82, 0, 18), "lowerarm_l": Vector3(-8, 0, 0), "lowerarm_r": Vector3(-8, 0, 0)}}
	],
	"Attack_Staff": [
		{"t": 0.0, "p": {"upperarm_l": Vector3(-35, 0, -25), "upperarm_r": Vector3(-45, 0, 25), "lowerarm_l": Vector3(-35, 0, 0), "lowerarm_r": Vector3(-45, 0, 0), "spine_01": Vector3(-5, 0, 0)}},
		{"t": 0.35, "p": {"upperarm_l": Vector3(-112, 0, -20), "upperarm_r": Vector3(-105, 0, 20), "lowerarm_l": Vector3(-18, 0, 0), "lowerarm_r": Vector3(-20, 0, 0), "spine_01": Vector3(-12, 0, 0)}},
		{"t": 0.65, "p": {"upperarm_l": Vector3(-80, 0, -22), "upperarm_r": Vector3(-72, 0, 22), "lowerarm_l": Vector3(-28, 0, 0), "lowerarm_r": Vector3(-35, 0, 0), "spine_01": Vector3(4, 0, 0)}}
	],
	"Hit": [
		{"t": 0.0, "p": {"spine_01": Vector3(-22, 0, 0), "Head": Vector3(18, 0, 0), "upperarm_l": Vector3(38, 0, -35), "upperarm_r": Vector3(38, 0, 35), "thigh_l": Vector3(-12, 0, 0), "thigh_r": Vector3(-12, 0, 0)}},
		{"t": 0.18, "p": {"spine_01": Vector3(8, 0, 0), "Head": Vector3(-8, 0, 0), "upperarm_l": Vector3(-15, 0, -20), "upperarm_r": Vector3(-15, 0, 20)}}
	],
	"Death": [
		{"t": 0.0, "p": {"spine_01": Vector3(-8, 0, 0), "upperarm_l": Vector3(28, 0, -35), "upperarm_r": Vector3(28, 0, 35), "thigh_l": Vector3(-18, 0, 0), "thigh_r": Vector3(-18, 0, 0)}},
		{"t": 0.45, "p": {"spine_01": Vector3(55, 0, 0), "spine_02": Vector3(28, 0, 0), "Head": Vector3(24, 0, 0), "upperarm_l": Vector3(75, 0, -55), "upperarm_r": Vector3(75, 0, 55), "thigh_l": Vector3(-75, 0, 0), "thigh_r": Vector3(-75, 0, 0), "calf_l": Vector3(85, 0, 0), "calf_r": Vector3(85, 0, 0)}}
	]
}

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	var library := AnimationLibrary.new()
	for clip_name in CLIPS:
		var animation := _make_animation(clip_name)
		var error := library.add_animation(clip_name, animation)
		if error != OK:
			push_error("ANIMATION_LIBRARY_ADD_FAILED: %s (%s)" % [clip_name, error])
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/phase4/animations"))
	var error := ResourceSaver.save(library, OUTPUT)
	if error != OK:
		push_error("ANIMATION_LIBRARY_SAVE_FAILED: %s" % error)
		quit(2)
		return
	var check := ResourceLoader.load(OUTPUT, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE)
	if check == null or (check as AnimationLibrary).get_animation_list().size() != CLIPS.size():
		push_error("ANIMATION_LIBRARY_RELOAD_VALIDATION_FAILED")
		quit(2)
		return
	print("PHASE4A_ANIMATION_LIBRARY_OK: ", OUTPUT, " animations=", CLIPS.size(), " bones=", BONES.size())
	quit(0)

func _make_animation(clip_name: String) -> Animation:
	var animation := Animation.new()
	animation.resource_name = clip_name
	var frames: Array = POSES[clip_name]
	animation.length = float(frames.back()["t"]) + (0.15 if clip_name in ["Run", "Attack_Assassin"] else 0.25)
	animation.loop_mode = Animation.LOOP_LINEAR if clip_name in ["Idle", "Run"] else Animation.LOOP_NONE
	var used := {}
	for frame in frames:
		for bone in frame["p"]:
			used[bone] = true
	for bone in used:
		if not BONES.has(bone):
			continue
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("Skeleton3D:" + bone))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for frame in frames:
			var pose: Dictionary = frame["p"]
			var degrees: Vector3 = pose.get(bone, Vector3.ZERO)
			animation.track_insert_key(track, float(frame["t"]), Quaternion.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))))
	return animation
