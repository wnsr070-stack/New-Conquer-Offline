extends RefCounted
class_name AssetLoader
const DEFAULT_FALLBACK_ID := "boulder_01"
const APPROVED_MANIFEST := "assets/universal_nature_pack/imperial_approved_assets.json"
static func load_model(asset_id: String, fallback_id: String = DEFAULT_FALLBACK_ID) -> Node3D:
	var manifest := _read_manifest()
	if manifest.is_empty():
		push_warning("AssetLoader: approved manifest unavailable; cannot load " + asset_id)
		return null
	var instance := _load_gltf(_resolve_asset_path(manifest, asset_id))
	if instance != null:
		return instance
	push_warning("AssetLoader: failed to load '%s'; trying approved fallback '%s'." % [asset_id, fallback_id])
	instance = _load_gltf(_resolve_asset_path(manifest, fallback_id))
	if instance != null:
		instance.name = "Fallback_" + fallback_id
		return instance
	var fallback_path := _first_available_approved_asset(manifest)
	if fallback_path != "":
		push_warning("AssetLoader: trying first available approved model.")
		return _load_gltf(fallback_path)
	push_warning("AssetLoader: no approved GLB could be loaded for '%s'." % asset_id)
	return null
static func _cache_root() -> String:
	var configured := OS.get_environment("HF_ASSET_CACHE_DIR")
	if configured.strip_edges() != "":
		return configured.simplify_path()
	return ProjectSettings.globalize_path("res://.cache/hf-assets").simplify_path()
static func _read_manifest() -> Dictionary:
	var path := _cache_root().path_join(APPROVED_MANIFEST)
	if not FileAccess.file_exists(path):
		push_warning("AssetLoader: missing approved manifest: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("AssetLoader: cannot open approved manifest: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("AssetLoader: approved manifest JSON is invalid.")
		return {}
	return parsed
static func _resolve_asset_path(manifest: Dictionary, asset_id: String) -> String:
	var categories: Dictionary = manifest.get("categories", {})
	for category_value in categories.values():
		if typeof(category_value) != TYPE_DICTIONARY:
			continue
		for asset_value in category_value.get("assets", []):
			if typeof(asset_value) != TYPE_DICTIONARY:
				continue
			if String(asset_value.get("asset_id", "")) == asset_id:
				var relative_file := String(asset_value.get("file", ""))
				if relative_file.is_empty():
					return ""
				return _cache_root().path_join("assets/universal_nature_pack").path_join(relative_file)
	return ""
static func _first_available_approved_asset(manifest: Dictionary) -> String:
	var nature: Dictionary = manifest.get("categories", {}).get("nature", {})
	for asset_value in nature.get("assets", []):
		if typeof(asset_value) != TYPE_DICTIONARY:
			continue
		if not bool(asset_value.get("validation", {}).get("validated", false)):
			continue
		var candidate := _cache_root().path_join("assets/universal_nature_pack").path_join(String(asset_value.get("file", "")))
		if FileAccess.file_exists(candidate):
			return candidate
	return ""
static func _load_gltf(path: String) -> Node3D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err: Error = document.append_from_file(path, state)
	if err != OK:
		push_warning("AssetLoader: GLTFDocument append failed (%s): %s" % [err, path])
		return null
	var generated: Node = document.generate_scene(state)
	if generated == null or not generated is Node3D:
		push_warning("AssetLoader: GLTF scene generation returned no Node3D: " + path)
		if generated != null:
			generated.free()
		return null
	return generated as Node3D
