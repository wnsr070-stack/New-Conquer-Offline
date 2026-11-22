extends RefCounted
class_name AssetLoader

const DEFAULT_FALLBACK_ID := "boulder_01"
static var _catalog: Dictionary = {}
static var _prototypes: Dictionary = {}

static func _cache_root() -> String:
 var configured := OS.get_environment("HF_ASSET_CACHE_DIR")
 return configured.simplify_path() if configured.strip_edges() != "" else ProjectSettings.globalize_path("res://.cache/hf-assets").simplify_path()

static func _read_catalog() -> Dictionary:
 if not _catalog.is_empty(): return _catalog
 var path := _cache_root().path_join("twin_city_runtime_assets.json")
 if not FileAccess.file_exists(path): return {}
 var f := FileAccess.open(path,FileAccess.READ)
 if f == null: return {}
 var parsed: Variant = JSON.parse_string(f.get_as_text())
 if typeof(parsed) == TYPE_DICTIONARY: _catalog = parsed
 return _catalog

static func load_model(asset_id: String, fallback_id: String = DEFAULT_FALLBACK_ID) -> Node3D:
 var catalog := _read_catalog()
 var actual_id := asset_id
 if not catalog.has(actual_id):
  if fallback_id.is_empty():
   push_error("AssetLoader: required asset is missing: " + asset_id)
   return null
  push_warning("AssetLoader: missing '%s'; trying explicit fallback '%s'." % [asset_id,fallback_id])
  actual_id = fallback_id
 if not catalog.has(actual_id): return null
 if _prototypes.has(actual_id): return (_prototypes[actual_id] as Node3D).duplicate(true) as Node3D
 var path := String(catalog[actual_id].get("path",""))
 var instance := _load_gltf(path)
 if instance == null and not fallback_id.is_empty() and actual_id != fallback_id:
  return load_model(fallback_id,"")
 if instance == null: return null
 _prototypes[actual_id] = instance.duplicate(true)
 return instance

static func _load_gltf(path: String) -> Node3D:
 if path.is_empty() or not FileAccess.file_exists(path): return null
 var doc := GLTFDocument.new()
 var state := GLTFState.new()
 var err: Error = doc.append_from_file(path,state)
 if err != OK:
  push_warning("AssetLoader: GLB import failed (%s): %s" % [err,path])
  return null
 var node: Node = doc.generate_scene(state)
 if node == null or not node is Node3D:
  if node != null: node.free()
  return null
 return node as Node3D

static func clear_cached_prototypes() -> void:
 for prototype in _prototypes.values():
  if is_instance_valid(prototype):
   (prototype as Node).free()
 _prototypes.clear()
 _catalog.clear()

static func fit_height(model: Node3D, target_height: float) -> float:
 var bounds := _measure_bounds(model,Transform3D.IDENTITY)
 if bounds.size.y <= 0.0001:
  push_warning("AssetLoader: empty AABB; cannot scale " + model.name)
  return 1.0
 var factor := target_height / bounds.size.y
 model.scale = model.scale * Vector3.ONE * factor
 model.position.y -= bounds.position.y * factor
 return factor

static func _measure_bounds(node: Node, parent_xform: Transform3D) -> AABB:
 var result := AABB()
 var has_bounds := false
 var xform: Transform3D = parent_xform * node.transform if node is Node3D else parent_xform
 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
  var a := (node as MeshInstance3D).get_aabb()
  for i in range(8):
   var corner := a.position + Vector3((a.size.x if (i&1)!=0 else 0.0),(a.size.y if (i&2)!=0 else 0.0),(a.size.z if (i&4)!=0 else 0.0))
   var point: Vector3 = xform * corner
   if not has_bounds: result=AABB(point,Vector3.ZERO); has_bounds=true
   else: result=result.expand(point)
 for child in node.get_children():
  var child_bounds := _measure_bounds(child,xform)
  if child_bounds.size.length_squared() > 0.0 or child is MeshInstance3D:
   if not has_bounds: result=child_bounds; has_bounds=true
   else: result=result.merge(child_bounds)
 return result
