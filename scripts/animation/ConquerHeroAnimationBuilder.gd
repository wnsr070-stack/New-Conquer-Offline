@tool
extends SceneTree
## Builds one shared animation library against the verified Ranger humanoid rest pose.

const OUTPUT := "res://assets/phase4/animations/conquer_hero_anims.res"
const MALE_MODEL := "res://assets/phase3b/characters/Male_Ranger.glb"
const CLIPS := ["Idle", "Run", "Jump", "Attack_Bow", "Attack_Assassin", "Attack_Trojan", "Attack_SwordShield", "Attack_Staff", "Hit", "Death"]
const POSES := {
 "Idle": [
  {"t":0.0,"p":{"upperarm_l":Vector3(0,0,-58),"upperarm_r":Vector3(0,0,58),"hand_l":Vector3.ZERO,"lowerarm_l":Vector3(-22,0,-10),"lowerarm_r":Vector3(-22,0,10),"thigh_l":Vector3(-7,0,0),"thigh_r":Vector3(-7,0,0),"calf_l":Vector3(12,0,0),"calf_r":Vector3(12,0,0),"spine_01":Vector3(-2,0,0)}},
  {"t":0.6,"p":{"upperarm_l":Vector3(0,0,-55),"upperarm_r":Vector3(0,0,55),"lowerarm_l":Vector3(-24,0,-10),"lowerarm_r":Vector3(-24,0,10),"thigh_l":Vector3(-9,0,0),"thigh_r":Vector3(-9,0,0),"calf_l":Vector3(14,0,0),"calf_r":Vector3(14,0,0),"spine_01":Vector3(-1,0,0)}}
 ],
 "Run": [
  {"t":0.0,"p":{"upperarm_l":Vector3(-48,0,-12),"upperarm_r":Vector3(48,0,12),"lowerarm_l":Vector3(-55,0,0),"lowerarm_r":Vector3(-55,0,0),"thigh_l":Vector3(42,0,0),"thigh_r":Vector3(-42,0,0),"calf_l":Vector3(-20,0,0),"calf_r":Vector3(35,0,0),"spine_01":Vector3(8,0,0)}},
  {"t":0.25,"p":{"upperarm_l":Vector3(48,0,-12),"upperarm_r":Vector3(-48,0,12),"lowerarm_l":Vector3(-55,0,0),"lowerarm_r":Vector3(-55,0,0),"thigh_l":Vector3(-42,0,0),"thigh_r":Vector3(42,0,0),"calf_l":Vector3(35,0,0),"calf_r":Vector3(-20,0,0),"spine_01":Vector3(8,0,0)}},
  {"t":0.5,"p":{"upperarm_l":Vector3(-48,0,-12),"upperarm_r":Vector3(48,0,12),"lowerarm_l":Vector3(-55,0,0),"lowerarm_r":Vector3(-55,0,0),"thigh_l":Vector3(42,0,0),"thigh_r":Vector3(-42,0,0),"calf_l":Vector3(-20,0,0),"calf_r":Vector3(35,0,0),"spine_01":Vector3(8,0,0)}}
 ],
 "Jump": [
  {"t":0.0,"p":{"upperarm_l":Vector3(0,0,45),"upperarm_r":Vector3(0,0,-45),"lowerarm_l":Vector3(-10,0,8),"lowerarm_r":Vector3(-10,0,-8),"thigh_l":Vector3(-48,0,0),"thigh_r":Vector3(-48,0,0),"calf_l":Vector3(92,0,0),"calf_r":Vector3(92,0,0),"spine_01":Vector3(-8,0,0)}},
  {"t":0.38,"p":{"upperarm_l":Vector3(0,0,50),"upperarm_r":Vector3(0,0,-50),"lowerarm_l":Vector3(-8,0,8),"lowerarm_r":Vector3(-8,0,-8),"thigh_l":Vector3(-55,0,0),"thigh_r":Vector3(-55,0,0),"calf_l":Vector3(105,0,0),"calf_r":Vector3(105,0,0),"spine_01":Vector3(-10,0,0)}},
  {"t":0.8,"p":{"upperarm_l":Vector3(-68,0,-45),"upperarm_r":Vector3(-68,0,45),"lowerarm_l":Vector3(-8,0,0),"lowerarm_r":Vector3(-8,0,0),"thigh_l":Vector3(-48,0,0),"thigh_r":Vector3(-48,0,0),"calf_l":Vector3(92,0,0),"calf_r":Vector3(92,0,0),"spine_01":Vector3(-8,0,0)}}
 ],
 "Attack_Bow": [
  {"t":0.0,"p":{"spine_01":Vector3(-5,0,0),"spine_02":Vector3(-5,0,0),"spine_03":Vector3(-5,0,0),"thigh_l":Vector3(-8,0,0),"thigh_r":Vector3(-8,0,0),"calf_l":Vector3(16,0,0),"calf_r":Vector3(16,0,0),"upperarm_l":Vector3(82,0,12),"hand_l":Vector3.ZERO,"lowerarm_l":Vector3(-8,0,0),"upperarm_r":Vector3(82,0,-12),"lowerarm_r":Vector3.ZERO}},
  {"t":0.32,"p":{"spine_01":Vector3(-5,0,0),"spine_02":Vector3(-5,0,0),"spine_03":Vector3(-5,0,0),"thigh_l":Vector3(-10,0,0),"thigh_r":Vector3(-10,0,0),"calf_l":Vector3(18,0,0),"calf_r":Vector3(18,0,0),"upperarm_l":Vector3(88,0,10),"lowerarm_l":Vector3(-4,0,0),"upperarm_r":Vector3(88,0,-10),"lowerarm_r":Vector3.ZERO}},
  {"t":0.58,"p":{"spine_01":Vector3(-5,0,0),"spine_02":Vector3(-5,0,0),"spine_03":Vector3(-5,0,0),"thigh_l":Vector3(-8,0,0),"thigh_r":Vector3(-8,0,0),"calf_l":Vector3(16,0,0),"calf_r":Vector3(16,0,0),"upperarm_l":Vector3(82,0,12),"hand_l":Vector3.ZERO,"lowerarm_l":Vector3(-8,0,0),"upperarm_r":Vector3(82,0,-12),"lowerarm_r":Vector3.ZERO}}
 ],
 "Attack_Assassin": [
  {"t":0.0,"p":{"spine_01":Vector3(-4,0,0),"spine_02":Vector3(-4,0,0),"spine_03":Vector3(-4,0,0),"thigh_l":Vector3(-8,0,0),"thigh_r":Vector3(-8,0,0),"calf_l":Vector3(18,0,0),"calf_r":Vector3(18,0,0),"upperarm_l":Vector3(72,0,28),"upperarm_r":Vector3(72,0,-28),"lowerarm_l":Vector3(-28,0,0),"lowerarm_r":Vector3(-28,0,0)}},
  {"t":0.16,"p":{"spine_01":Vector3(-4,0,0),"spine_02":Vector3(-4,0,0),"spine_03":Vector3(-4,0,0),"thigh_l":Vector3(-9,0,0),"thigh_r":Vector3(-9,0,0),"calf_l":Vector3(20,0,0),"calf_r":Vector3(20,0,0),"upperarm_l":Vector3(92,0,16),"upperarm_r":Vector3(92,0,-16),"lowerarm_l":Vector3(-12,0,0),"lowerarm_r":Vector3(-12,0,0)}},
  {"t":0.34,"p":{"spine_01":Vector3(-4,0,0),"spine_02":Vector3(-4,0,0),"spine_03":Vector3(-4,0,0),"thigh_l":Vector3(-8,0,0),"thigh_r":Vector3(-8,0,0),"calf_l":Vector3(18,0,0),"calf_r":Vector3(18,0,0),"upperarm_l":Vector3(72,0,28),"upperarm_r":Vector3(72,0,-28),"lowerarm_l":Vector3(-28,0,0),"lowerarm_r":Vector3(-28,0,0)}}
 ],
 "Attack_Trojan": [
  {"t":0.0,"p":{"spine_01":Vector3(6,0,0),"spine_02":Vector3(6,0,0),"spine_03":Vector3(6,0,0),"thigh_l":Vector3(-10,0,0),"thigh_r":Vector3(-10,0,0),"upperarm_l":Vector3(105,0,42),"upperarm_r":Vector3(105,0,-42),"lowerarm_l":Vector3(-25,0,0),"lowerarm_r":Vector3(-25,0,0)}},
  {"t":0.18,"p":{"spine_01":Vector3(6,0,0),"spine_02":Vector3(6,0,0),"spine_03":Vector3(6,0,0),"thigh_l":Vector3(-12,0,0),"thigh_r":Vector3(-12,0,0),"upperarm_l":Vector3(72,0,52),"upperarm_r":Vector3(72,0,-52),"lowerarm_l":Vector3(-18,0,0),"lowerarm_r":Vector3(-18,0,0)}},
  {"t":0.42,"p":{"spine_01":Vector3(6,0,0),"spine_02":Vector3(6,0,0),"spine_03":Vector3(6,0,0),"thigh_l":Vector3(-10,0,0),"thigh_r":Vector3(-10,0,0),"upperarm_l":Vector3(105,0,42),"upperarm_r":Vector3(105,0,-42),"lowerarm_l":Vector3(-25,0,0),"lowerarm_r":Vector3(-25,0,0)}}
 ],
 "Attack_SwordShield": [
  {"t":0.0,"p":{"spine_01":Vector3(4,0,0),"spine_02":Vector3(4,0,0),"spine_03":Vector3(4,0,0),"upperarm_l":Vector3(72,0,42),"lowerarm_l":Vector3(-48,0,0),"upperarm_r":Vector3(92,0,-22),"lowerarm_r":Vector3(-22,0,0)}},
  {"t":0.2,"p":{"spine_01":Vector3(4,0,0),"spine_02":Vector3(4,0,0),"spine_03":Vector3(4,0,0),"upperarm_l":Vector3(62,0,50),"lowerarm_l":Vector3(-42,0,0),"upperarm_r":Vector3(55,0,-22),"lowerarm_r":Vector3(-18,0,0)}},
  {"t":0.45,"p":{"spine_01":Vector3(4,0,0),"spine_02":Vector3(4,0,0),"spine_03":Vector3(4,0,0),"upperarm_l":Vector3(72,0,42),"lowerarm_l":Vector3(-48,0,0),"upperarm_r":Vector3(92,0,-22),"lowerarm_r":Vector3(-22,0,0)}}
 ],
 "Attack_Staff": [
  {"t":0.0,"p":{"spine_01":Vector3(-2,0,0),"upperarm_l":Vector3(60,0,28),"lowerarm_l":Vector3(-25,0,0),"upperarm_r":Vector3(75,0,-28),"lowerarm_r":Vector3(-22,0,0)}},
  {"t":0.32,"p":{"spine_01":Vector3(-5,0,0),"upperarm_l":Vector3(105,0,20),"lowerarm_l":Vector3(-12,0,0),"upperarm_r":Vector3(112,0,-20),"lowerarm_r":Vector3(-12,0,0)}},
  {"t":0.62,"p":{"spine_01":Vector3(-2,0,0),"upperarm_l":Vector3(60,0,28),"lowerarm_l":Vector3(-25,0,0),"upperarm_r":Vector3(75,0,-28),"lowerarm_r":Vector3(-22,0,0)}}
 ],
 "Hit":[{"t":0.0,"p":{"spine_01":Vector3(-18,0,0),"upperarm_l":Vector3(30,0,-25),"upperarm_r":Vector3(30,0,25)}},{"t":0.2,"p":{"spine_01":Vector3(8,0,0),"upperarm_l":Vector3(-12,0,-18),"upperarm_r":Vector3(-12,0,18)}}],
 "Death":[{"t":0.0,"p":{"spine_01":Vector3(-8,0,0),"upperarm_l":Vector3(25,0,-35),"upperarm_r":Vector3(25,0,35)}},{"t":0.5,"p":{"spine_01":Vector3(55,0,0),"thigh_l":Vector3(-70,0,0),"thigh_r":Vector3(-70,0,0),"calf_l":Vector3(85,0,0),"calf_r":Vector3(85,0,0)}}]
}

func _initialize() -> void:
 call_deferred("_build")

func _build() -> void:
 var male := _load_rig(MALE_MODEL)
 if male == null: quit(2); return
 var skeleton := male["skeleton"] as Skeleton3D
 var female_skeleton := skeleton
 var mapping := _resolve_bones(skeleton)
 if mapping.size() < 18:
  push_error("RANGER_RIG_BONE_MAPPING_INCOMPLETE: " + str(mapping))
  quit(4); return
 for key in mapping:
  if female_skeleton.find_bone(str(mapping[key])) < 0:
   push_error("RANGER_GENDER_RIG_MISMATCH: " + str(key) + " -> " + str(mapping[key]))
   quit(5); return
 var library := AnimationLibrary.new()
 for clip in CLIPS:
  var animation := _make_animation(clip, skeleton, male["skeleton_path"], mapping)
  var err := library.add_animation(clip, animation)
  if err != OK: push_error("ANIMATION_ADD_FAILED: " + clip); quit(6); return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/phase4/animations"))
 var save_err := ResourceSaver.save(library, OUTPUT)
 if save_err != OK: push_error("ANIMATION_SAVE_FAILED: " + str(save_err)); quit(7); return
 var loaded := ResourceLoader.load(OUTPUT, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
 if loaded == null or loaded.get_animation_list().size() != CLIPS.size():
  push_error("ANIMATION_RELOAD_VALIDATION_FAILED"); quit(8); return
 print("PHASE4A_ANIMATION_LIBRARY_OK: animations=", CLIPS.size(), " mapped_bones=", mapping.size(), " rig=Male_Ranger_only")
 quit(0)

func _load_rig(path: String) -> Dictionary:
 var packed := ResourceLoader.load(path) as PackedScene
 if packed == null: push_error("RANGER_MODEL_NOT_IMPORTED: " + path); return {}
 var root := packed.instantiate()
 var skeletons := root.find_children("*", "Skeleton3D", true, false)
 if skeletons.is_empty(): push_error("RANGER_SKELETON_MISSING: " + path); root.free(); return {}
 var skeleton := skeletons[0] as Skeleton3D
 var result := {"skeleton":skeleton, "skeleton_path":root.get_path_to(skeleton)}
 # Keep instance alive while building the rest-pose transforms.
 return {"root":root, "skeleton":skeleton, "skeleton_path":root.get_path_to(skeleton)}

func _resolve_bones(skeleton: Skeleton3D) -> Dictionary:
 var aliases := {
  "pelvis":["pelvis","hips"],
  "spine_01":["spine_01","spine1","spine"],
  "spine_02":["spine_02","spine2","chest"],
  "spine_03":["spine_03","spine3","upperchest"],
  "neck_01":["neck_01","neck1","neck"],
  "Head":["head"],
  "clavicle_l":["clavicle_l","claviclel","leftshoulder"],
  "clavicle_r":["clavicle_r","clavicler","rightshoulder"],
  "upperarm_l":["upperarm_l","upperarml","leftarm"],
  "upperarm_r":["upperarm_r","upperarmr","rightarm"],
  "lowerarm_l":["lowerarm_l","lowerarml","leftforearm"],
  "lowerarm_r":["lowerarm_r","lowerarmr","rightforearm"],
  "hand_l":["hand_l","handl","lefthand"],
  "hand_r":["hand_r","handr","righthand"],
  "thigh_l":["thigh_l","thighl","leftupleg"],
  "thigh_r":["thigh_r","thighr","rightupleg"],
  "calf_l":["calf_l","calfl","leftleg"],
  "calf_r":["calf_r","calfr","rightleg"],
  "foot_l":["foot_l","footl","leftfoot"],
  "foot_r":["foot_r","footr","rightfoot"]
 }
 var result := {}
 for canonical in aliases:
  for i in range(skeleton.get_bone_count()):
   var actual := skeleton.get_bone_name(i)
   var normalized := actual.to_lower().replace("_","").replace("-","").replace(" ","")
   for alias in aliases[canonical]:
    if normalized == str(alias).to_lower().replace("_","").replace("-","").replace(" ",""):
     result[canonical] = actual
     break
   if result.has(canonical): break
 return result

func _make_animation(clip: String, skeleton: Skeleton3D, skeleton_path: NodePath, mapping: Dictionary) -> Animation:
 var animation := Animation.new()
 animation.resource_name = clip
 var frames: Array = POSES[clip]
 animation.length = float(frames.back()["t"]) + (0.22 if clip in ["Run","Attack_Assassin"] else 0.28)
 animation.loop_mode = Animation.LOOP_LINEAR if clip in ["Idle","Run"] else Animation.LOOP_NONE
 var used := {}
 for frame in frames:
  for bone in frame["p"]: used[bone] = true
 for canonical in used:
  if not mapping.has(canonical): continue
  var actual := str(mapping[canonical])
  var bone_index := skeleton.find_bone(actual)
  var rest_quat := skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()
  var track := animation.add_track(Animation.TYPE_ROTATION_3D)
  animation.track_set_path(track, NodePath(str(skeleton_path) + ":" + actual))
  animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
  for frame in frames:
   var degrees: Vector3 = frame["p"].get(canonical, Vector3.ZERO)
   var delta_quat := Quaternion.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)))
   if clip == "Attack_Bow" and canonical == "upperarm_r":
    # The imported Ranger faces skeleton-space +Z (verified by the front-facing
    # hood/face and the rig's measured rest transforms). The previous -Z target
    # aimed the arm behind the torso, making it disappear from the front view.
    # Build the aim in the clavicle's parent-rest space, then convert it to the
    # local delta expected by the Animation rotation track.
    var parent_index := skeleton.get_bone_parent(bone_index)
    var parent_global_basis := Basis.IDENTITY
    if parent_index >= 0:
     parent_global_basis = skeleton.get_bone_global_rest(parent_index).basis.orthonormalized()
    var target_in_parent_space := (parent_global_basis.inverse() * Vector3(0, 0, 1)).normalized()
    var target_parent_rotation := Quaternion(Vector3.UP, target_in_parent_space)
    var local_rest_rotation := skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()
    delta_quat = (local_rest_rotation.inverse() * target_parent_rotation).normalized()
   elif clip == "Attack_Bow" and canonical == "lowerarm_r":
    # Keep the elbow completely straight; no forearm bend.
    delta_quat = Quaternion.IDENTITY
   animation.track_insert_key(track, float(frame["t"]), (rest_quat * delta_quat).normalized())
 if clip in ["Idle", "Attack_Bow"] and mapping.has("hand_l") and mapping.has("lowerarm_l"):
  var hand_index := skeleton.find_bone(str(mapping["hand_l"]))
  var forearm_index := skeleton.find_bone(str(mapping["lowerarm_l"]))
  var hand_rest_global := skeleton.get_bone_global_rest(hand_index)
  var forearm_to_wrist := hand_rest_global.basis.inverse() * (skeleton.get_bone_global_rest(forearm_index).origin - hand_rest_global.origin)
  var forearm_axis_local := forearm_to_wrist.normalized()
  var hand_track := animation.add_track(Animation.TYPE_ROTATION_3D)
  animation.track_set_path(hand_track, NodePath(str(skeleton_path) + ":" + str(mapping["hand_l"])))
  animation.track_set_interpolation_type(hand_track, Animation.INTERPOLATION_LINEAR)
  var hand_rest_rotation := skeleton.get_bone_rest(hand_index).basis.get_rotation_quaternion()
  var palm_inward_rotation := Quaternion(forearm_axis_local, deg_to_rad(90.0))
  for frame in frames:
   animation.track_insert_key(hand_track, float(frame["t"]), (hand_rest_rotation * palm_inward_rotation).normalized())
  var finger_track_count := 0
  var finger_names: Array[String] = []
  for finger_index in range(skeleton.get_bone_count()):
   var ancestor := skeleton.get_bone_parent(finger_index)
   while ancestor >= 0 and ancestor != hand_index:
    ancestor = skeleton.get_bone_parent(ancestor)
   if ancestor != hand_index:
    continue
   var finger_name := skeleton.get_bone_name(finger_index)
   var finger_normalized := finger_name.to_lower().replace("_","").replace("-","").replace(" ","").replace(":","")
   var is_finger := "index" in finger_normalized or "middle" in finger_normalized or "ring" in finger_normalized or "pinky" in finger_normalized or "little" in finger_normalized or "thumb" in finger_normalized
   if not is_finger:
    continue
   var curl_degrees := 42.0
   if "thumb" in finger_normalized:
    curl_degrees = 34.0
   elif "3" in finger_normalized or "distal" in finger_normalized:
    curl_degrees = 24.0
   elif "2" in finger_normalized or "middle" in finger_normalized:
    curl_degrees = 38.0
   else:
    curl_degrees = 48.0
   var finger_rest_rotation := skeleton.get_bone_rest(finger_index).basis.get_rotation_quaternion()
   var finger_curl := Quaternion(Vector3.RIGHT, deg_to_rad(curl_degrees))
   var finger_track := animation.add_track(Animation.TYPE_ROTATION_3D)
   animation.track_set_path(finger_track, NodePath(str(skeleton_path) + ":" + finger_name))
   animation.track_set_interpolation_type(finger_track, Animation.INTERPOLATION_LINEAR)
   for frame in frames:
    animation.track_insert_key(finger_track, float(frame["t"]), (finger_rest_rotation * finger_curl).normalized())
   finger_track_count += 1
   finger_names.append(finger_name)
  print("PHASE4C_LEFT_HAND_GRIP_POSE_BUILT: hand_bone=", mapping["hand_l"], " forearm_axis_local=", forearm_axis_local, " palm_rotation_deg=90 finger_tracks=", finger_track_count, " fingers=", finger_names)
  if finger_track_count < 4:
   push_error("PHASE4C_LEFT_HAND_FINGER_CURL_INCOMPLETE: tracks=" + str(finger_track_count) + " fingers=" + str(finger_names))
 if clip == "Jump" and mapping.has("pelvis"):
  var pelvis := str(mapping["pelvis"])
  var idx := skeleton.find_bone(pelvis)
  var rest_position := skeleton.get_bone_rest(idx).origin
  var track := animation.add_track(Animation.TYPE_POSITION_3D)
  animation.track_set_path(track, NodePath(str(skeleton_path) + ":" + pelvis))
  animation.track_insert_key(track, 0.0, rest_position)
  animation.track_insert_key(track, 0.38, rest_position + Vector3(0,0.65,0))
  animation.track_insert_key(track, 0.8, rest_position)
 return animation
