extends Node
## Runtime attachment for the approved Phase 3B modular armor and headgear GLBs.
## Real Skeleton3D BoneAttachment3D nodes are used; no placeholder geometry is generated.

var _hero: Node3D
var _skeleton: Skeleton3D
var _active_class := "archer"
var _visuals: Dictionary = {}

func _ready() -> void:
 var gear := get_node_or_null("/root/GearSystem")
 if gear != null and gear.has_signal("equipment_changed"):
  gear.equipment_changed.connect(_on_equipment_changed)
 var class_system := get_node_or_null("/root/ClassSystem")
 if class_system != null and class_system.has_signal("class_changed"):
  class_system.class_changed.connect(set_active_class)
 print("PHASE4D_EQUIPMENT_VISUAL_MANAGER_READY: bone_attachment=true phase3b_catalog=33")

func bind_hero(hero: Node3D) -> void:
 if hero == null or not is_instance_valid(hero):
  return
 if _hero != hero:
  _clear_all_visuals()
 _hero = hero
 _skeleton = hero.get("skeleton") as Skeleton3D
 if _skeleton == null:
  _skeleton = hero.find_child("*", "Skeleton3D", true, false) as Skeleton3D
 if _skeleton == null:
  push_error("PHASE4D_EQUIPMENT_SKELETON_MISSING")
  return
 _sync_all_equipment()
 print("PHASE4D_EQUIPMENT_HERO_BOUND: hero=",hero.name," skeleton=",_skeleton.get_path()," bones=",_skeleton.get_bone_count()," class=",_active_class)

func set_active_class(class_id: String) -> void:
 _active_class = class_id
 if _skeleton != null:
  _sync_all_equipment()

func _on_equipment_changed(slot: String, item: Dictionary) -> void:
 var normalized_slot := "helmet" if slot == "headgear" else slot
 if normalized_slot not in ["armor","helmet"]:
  return
 _apply_slot(normalized_slot,item)

func _sync_all_equipment() -> void:
 var gear := get_node_or_null("/root/GearSystem")
 if gear == null:
  return
 _apply_slot("armor",gear.get_equipped("armor"))
 _apply_slot("helmet",gear.get_equipped("helmet"))

func _apply_slot(slot: String, item: Dictionary) -> void:
 if _skeleton == null or not is_instance_valid(_skeleton):
  return
 if item.is_empty():
  _remove_slot(slot)
  print("PHASE4D_EQUIPMENT_SLOT_CLEARED: ",slot)
  return
 var allowed_classes: Array = item.get("classes",[])
 if not allowed_classes.is_empty() and _active_class not in allowed_classes:
  _remove_slot(slot)
  return
 var asset_path := String(item.get("asset_path",item.get("model_path","")))
 if asset_path.is_empty() or not ResourceLoader.exists(asset_path):
  push_error("PHASE4D_EQUIPMENT_ASSET_MISSING: slot="+slot+" path="+asset_path)
  return
 var existing: Dictionary = _visuals.get(slot,{})
 if not existing.is_empty() and String(existing.get("asset_path","")) == asset_path:
  existing["item"] = item.duplicate(true)
  _visuals[slot] = existing
  _update_equipment_aura(slot)
  return
 _remove_slot(slot)
 var packed := load(asset_path) as PackedScene
 if packed == null:
  push_error("PHASE4D_EQUIPMENT_PACKED_SCENE_LOAD_FAILED: "+asset_path)
  return
 var model := packed.instantiate() as Node3D
 if model == null:
  push_error("PHASE4D_EQUIPMENT_INSTANCE_FAILED: "+asset_path)
  return
 var bone_index := _resolve_bone_index(slot)
 if bone_index < 0:
  model.free()
  push_error("PHASE4D_EQUIPMENT_REQUIRED_BONE_NOT_FOUND: slot="+slot+" available="+str(_bone_names()))
  return
 var bone_name := _skeleton.get_bone_name(bone_index)
 var socket := BoneAttachment3D.new()
 socket.name = "EquipmentSocket_"+slot
 socket.bone_name = bone_name
 socket.bone_idx = bone_index
 socket.override_pose = false
 _skeleton.add_child(socket)
 model.name = "EquipmentModel_"+slot
 socket.add_child(model)
 _skeleton.force_update_all_bone_transforms()
 var bounds := _local_mesh_bounds(model)
 if bounds.size.length() < 0.001 or bounds.size.y < 0.001:
  socket.free()
  push_error("PHASE4D_EQUIPMENT_MESH_BOUNDS_INVALID: slot="+slot+" path="+asset_path)
  return
 if not _fit_model_to_bone(slot,bone_index,model,bounds):
  socket.free()
  push_error("PHASE4D_EQUIPMENT_FIT_FAILED: slot="+slot+" path="+asset_path)
  return
 var aura_target := Node3D.new()
 aura_target.name = "EquipmentAuraTarget"
 aura_target.position = bounds.get_center()*model.scale.x
 model.add_child(aura_target)
 model.set_meta("equipment_slot",slot)
 model.set_meta("equipment_asset_path",asset_path)
 var entry := {"socket":socket,"model":model,"aura_target":aura_target,"asset_path":asset_path,"bone_name":bone_name,"item":item.duplicate(true),"mesh_count":_count_meshes(model)}
 _visuals[slot] = entry
 _update_equipment_aura(slot)
 print("PHASE4D_EQUIPMENT_ATTACHED: slot=",slot," type=",item.get("equipment_type","Armor")," asset=",asset_path," bone=",bone_name," mesh_count=",entry.mesh_count," plus=",item.get("plus",0)," scale=",model.scale," local_bounds=",bounds)

func _fit_model_to_bone(slot: String, bone_index: int, model: Node3D, bounds: AABB) -> bool:
 var bone_rest := _skeleton.get_bone_global_rest(bone_index)
 var target_center_skeleton := bone_rest.origin
 var target_width := 0.34
 var target_height := 0.32
 if slot == "armor":
  var pelvis_index := _find_bone_index(["hips","pelvis"])
  var neck_index := _find_bone_index(["neck"])
  var pelvis_pos := _skeleton.get_bone_global_rest(pelvis_index).origin if pelvis_index >= 0 else bone_rest.origin-Vector3(0,0.65,0)
  var neck_pos := _skeleton.get_bone_global_rest(neck_index).origin if neck_index >= 0 else bone_rest.origin+Vector3(0,0.55,0)
  target_center_skeleton = pelvis_pos.lerp(neck_pos,0.53)
  target_height = clampf(pelvis_pos.distance_to(neck_pos)*1.02,0.72,1.30)
  var left_shoulder := _find_bone_index(["leftshoulder","shoulderl","leftupperarm","upperarml","leftarm"])
  var right_shoulder := _find_bone_index(["rightshoulder","shoulderr","rightupperarm","upperarmr","rightarm"])
  if left_shoulder >= 0 and right_shoulder >= 0:
   target_width = clampf(_skeleton.get_bone_global_rest(left_shoulder).origin.distance_to(_skeleton.get_bone_global_rest(right_shoulder).origin)*1.10,0.48,0.98)
  else:
   target_width = 0.76
 else:
  var neck_index := _find_bone_index(["neck"])
  if neck_index >= 0:
   target_height = clampf(bone_rest.origin.distance_to(_skeleton.get_bone_global_rest(neck_index).origin)*2.0,0.20,0.38)
   target_width = target_height*0.92
  else:
   target_width = 0.26
   target_height = 0.30
  target_center_skeleton = bone_rest.origin+Vector3(0,0.075,0)
 var horizontal_extent := maxf(bounds.size.x,bounds.size.z)
 if horizontal_extent <= 0.001:
  return false
 var scale_value := minf(target_width/horizontal_extent,target_height/maxf(bounds.size.y,0.001))*0.94
 if scale_value <= 0.0001 or not is_finite(scale_value):
  return false
 var target_center_bone := bone_rest.affine_inverse()*target_center_skeleton
 model.scale = Vector3.ONE*scale_value
 model.position = target_center_bone-bounds.get_center()*scale_value
 return true

func _resolve_bone_index(slot: String) -> int:
 if slot == "helmet":
  return _find_bone_index(["head"])
 var best := -1
 var best_height := -INF
 for index in range(_skeleton.get_bone_count()):
  var normalized := _normalize_bone_name(_skeleton.get_bone_name(index))
  if normalized.contains("spine") or normalized.contains("chest"):
   var height := _skeleton.get_bone_global_rest(index).origin.y
   if height > best_height:
    best = index
    best_height = height
 return best

func _find_bone_index(tokens: Array) -> int:
 for index in range(_skeleton.get_bone_count()):
  var normalized := _normalize_bone_name(_skeleton.get_bone_name(index))
  for token in tokens:
   if normalized == String(token) or normalized.contains(String(token)):
    return index
 return -1

func _normalize_bone_name(value: String) -> String:
 return value.to_lower().replace("_","").replace("-","").replace(" ","").replace(":","").replace(".","")

func _bone_names() -> Array[String]:
 var result: Array[String] = []
 if _skeleton == null:
  return result
 for index in range(_skeleton.get_bone_count()):
  result.append(_skeleton.get_bone_name(index))
 return result

func _local_mesh_bounds(root: Node3D) -> AABB:
 var result := AABB()
 var found := false
 for mesh_node in root.find_children("*","MeshInstance3D",true,false):
  var mesh_instance := mesh_node as MeshInstance3D
  if mesh_instance.mesh == null:
   continue
  var relative_transform := root.global_transform.affine_inverse()*mesh_instance.global_transform
  var box := relative_transform*mesh_instance.get_aabb()
  if not found:
   result = box
   found = true
  else:
   result = result.merge(box)
 return result if found else AABB()

func _count_meshes(node: Node) -> int:
 var count := 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
 for child in node.get_children():
  count += _count_meshes(child)
 return count

func _update_equipment_aura(slot: String) -> void:
 var entry: Dictionary = _visuals.get(slot,{})
 if entry.is_empty():
  return
 var aura_target := entry.get("aura_target") as Node3D
 var item: Dictionary = entry.get("item",{})
 var vfx := get_node_or_null("/root/AuraAndVFXManager")
 if aura_target != null and vfx != null:
  vfx.attach_equipment_aura(aura_target,int(item.get("plus",0)))

func _remove_slot(slot: String) -> void:
 var entry: Dictionary = _visuals.get(slot,{})
 if entry.is_empty():
  return
 var socket := entry.get("socket") as Node3D
 if is_instance_valid(socket):
  socket.free()
 _visuals.erase(slot)

func _clear_all_visuals() -> void:
 for slot in _visuals.keys().duplicate():
  _remove_slot(String(slot))

func get_visual_model(slot: String) -> Node3D:
 var entry: Dictionary = _visuals.get(slot,{})
 return entry.get("model") as Node3D if not entry.is_empty() else null

func get_visual_socket(slot: String) -> BoneAttachment3D:
 var entry: Dictionary = _visuals.get(slot,{})
 return entry.get("socket") as BoneAttachment3D if not entry.is_empty() else null

func get_visual_status() -> Dictionary:
 var result := {}
 for slot in _visuals:
  var entry: Dictionary = _visuals[slot]
  result[slot] = {"asset_path":entry.get("asset_path",""),"bone_name":entry.get("bone_name",""),"mesh_count":entry.get("mesh_count",0),"plus":entry.get("item",{}).get("plus",0)}
 return result

func clear_cache() -> void:
 _clear_all_visuals()
 _hero = null
 _skeleton = null
 _active_class = "archer"
 print("PHASE4D_EQUIPMENT_VISUAL_CACHE_CLEARED")
