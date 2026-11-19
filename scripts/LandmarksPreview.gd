extends Node3D
const Assets = preload("res://scripts/AssetLoader.gd")
const ROOT := "res://assets/hf_imported"
const KEYWORDS := ["building", "house", "palace", "castle", "temple", "pagoda", "gate", "hall", "forge", "blacksmith", "shop", "architecture", "tower", "shrine", "fortress", "pavilion", "dojo", "courtyard", "monastery", "bridge"]
const COLUMNS := 5
const CELL := 24.0
var entries: Array[Dictionary] = []

func _ready() -> void:
 _build_lighting()
 _build_grid_stage()
 _collect_glbs(ROOT)
 entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.path).to_lower() < String(b.path).to_lower())
 if entries.is_empty():
  push_error("BUILDING_GRID_FAILED: no architectural GLB files matched")
  get_tree().quit(1)
  return
 var rows := int(ceil(float(entries.size()) / float(COLUMNS)))
 for i in range(entries.size()):
  var item: Dictionary = entries[i]
  var model := Assets._load_gltf(String(item.path))
  if model == null:
   print("BUILDING_MODEL_SKIPPED: ", item.path)
   continue
  var raw_bounds: AABB = Assets._measure_bounds(model, Transform3D.IDENTITY)
  var raw_size: Vector3 = raw_bounds.size
  Assets.fit_height(model, 8.0)
  var col := i % COLUMNS
  var row := int(i / COLUMNS)
  model.position.x = (float(col) - float(COLUMNS - 1) / 2.0) * CELL
  model.position.z = (float(row) - float(rows - 1) / 2.0) * CELL
  add_child(model)
  var label := Label3D.new()
  label.text = "%s\n%.2f × %.2f × %.2f m" % [String(item.path).get_file(), raw_size.x, raw_size.y, raw_size.z]
  label.font_size = 28
  label.outline_size = 8
  label.pixel_size = 0.009
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  label.modulate = Color(1.0, 0.95, 0.82)
  label.position = model.position + Vector3(0, 10.0, 0)
  add_child(label)
  var line := "%03d | %s | %.3f x %.3f x %.3f m" % [i + 1, String(item.path).trim_prefix("res://"), raw_size.x, raw_size.y, raw_size.z]
  print("BUILDING_GRID_MODEL_OK: ", line)
  entries[i]["dimensions"] = raw_size
 _write_manifest()
 var camera := Camera3D.new()
 camera.name = "ArchitecturalRenderGridCamera"
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = max(58.0, float(rows) * CELL + 18.0)
 camera.position = Vector3(0, max(55.0, float(rows) * 15.0), max(90.0, float(rows) * 18.0))
 camera.current = true
 add_child(camera)
 camera.look_at(Vector3(0, 3, 0), Vector3.UP)
 _capture.call_deferred()

func _collect_glbs(path: String) -> void:
 var dir := DirAccess.open(path)
 if dir == null: return
 dir.list_dir_begin()
 var name := dir.get_next()
 while name != "":
  if name.begins_with("."):
   name = dir.get_next()
   continue
  var full := path.path_join(name)
  if dir.current_is_dir():
   _collect_glbs(full)
  elif name.to_lower().ends_with(".glb"):
   var lower := name.to_lower()
   var matched := false
   for word in KEYWORDS:
    if lower.contains(word):
     matched = true
     break
   if matched:
    entries.append({"path": full})
  name = dir.get_next()
 dir.list_dir_end()

func _write_manifest() -> void:
 var dir := ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(dir)
 var file := FileAccess.open(dir.path_join("eastern_architecture_manifest.txt"), FileAccess.WRITE)
 for item in entries:
  if item.has("dimensions"):
   var d: Vector3 = item.dimensions
   file.store_line("%s | %.3f x %.3f x %.3f m" % [String(item.path).trim_prefix("res://"), d.x, d.y, d.z])
 file.close()
 print("BUILDING_GRID_MANIFEST_OK: ", entries.size(), " matching files")

func _build_lighting() -> void:
 var world := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 var sky_material := ProceduralSkyMaterial.new()
 sky_material.sky_top_color = Color(0.12, 0.19, 0.29)
 sky_material.sky_horizon_color = Color(0.68, 0.73, 0.79)
 sky.sky_material = sky_material
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
 env.ambient_light_energy = 0.9
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 env.tonemap_exposure = 1.0
 world.environment = env
 add_child(world)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48, -32, 0)
 sun.light_energy = 1.15
 sun.shadow_enabled = true
 add_child(sun)
 var fill := DirectionalLight3D.new()
 fill.rotation_degrees = Vector3(-18, 145, 0)
 fill.light_energy = 0.42
 fill.light_color = Color(0.78, 0.84, 1.0)
 add_child(fill)

func _build_grid_stage() -> void:
 var ground := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(1800, 1800)
 ground.mesh = plane
 ground.position.y = -0.7
 var mat := StandardMaterial3D.new()
 mat.albedo_color = Color(0.16, 0.18, 0.20)
 mat.roughness = 0.95
 ground.material_override = mat
 add_child(ground)

func _capture() -> void:
 for frame in range(45):
  await get_tree().process_frame
 var dir := ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(dir)
 var image := get_viewport().get_texture().get_image()
 var path := dir.path_join("eastern_architecture_render_grid.png")
 var err := image.save_png(path)
 if err != OK:
  push_error("BUILDING_GRID_FAILED: cannot save render grid")
  get_tree().quit(1)
  return
 print("BUILDING_GRID_CAPTURE_OK: ", path, " count=", entries.size())
 get_tree().quit(0)
