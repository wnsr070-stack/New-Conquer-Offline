extends Node3D

const Assets = preload("res://scripts/AssetLoader.gd")
const ROOT := "res://assets/hf_imported"
const KEYWORDS := ["building", "house", "palace", "castle", "temple", "pagoda", "gate", "hall", "forge", "blacksmith", "smith", "shop", "architecture", "tower", "shrine", "fortress", "pavilion", "dojo", "courtyard", "monastery", "bridge", "inn"]
const MIN_FOOTPRINT := 4.0
const CELL_SPACING := 14.0
const NORMALIZED_FOOTPRINT := 7.5
const BATCH_SIZE := 9

var candidates: Array[Dictionary] = []
var model_nodes: Array[Node] = []

func _ready() -> void:
 _setup_environment()
 _collect_glbs(ROOT)
 var measured: Array[Dictionary] = []
 for item in candidates:
  var model := Assets._load_gltf(String(item.path))
  if model == null:
   print("LARGE_BUILDING_SKIPPED_LOAD: ", item.path)
   continue
  var bounds: AABB = Assets._measure_bounds(model, Transform3D.IDENTITY)
  var dims: Vector3 = bounds.size
  model.free()
  if dims.x >= MIN_FOOTPRINT and dims.z >= MIN_FOOTPRINT:
   measured.append({"path": String(item.path), "dimensions": dims})
 measured.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.path).to_lower() < String(b.path).to_lower())
 if measured.is_empty():
  push_error("LARGE_BUILDINGS_FAILED: no models passed 4m width/depth filter")
  get_tree().quit(1)
  return
 _write_filtered_manifest(measured)
 var batches := int(ceil(float(measured.size()) / float(BATCH_SIZE)))
 for batch_index in range(batches):
  _clear_batch()
  var start := batch_index * BATCH_SIZE
  var finish := mini(start + BATCH_SIZE, measured.size())
  for index in range(start, finish):
   _add_model_card(measured[index], index - start)
  await _capture_batch(batch_index + 1, batches)
 print("LARGE_BUILDINGS_COMPLETE: models=", measured.size(), " images=", batches)
 get_tree().quit(0)

func _collect_glbs(path: String) -> void:
 var dir := DirAccess.open(path)
 if dir == null:
  return
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
   for word in KEYWORDS:
    if lower.contains(word):
     candidates.append({"path": full})
     break
  name = dir.get_next()
 dir.list_dir_end()

func _setup_environment() -> void:
 var world := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 var sky_material := ProceduralSkyMaterial.new()
 sky_material.sky_top_color = Color(0.12, 0.18, 0.27)
 sky_material.sky_horizon_color = Color(0.48, 0.53, 0.59)
 sky.sky_material = sky_material
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color(0.48, 0.50, 0.54)
 env.ambient_light_energy = 0.3
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 env.tonemap_exposure = 0.9
 env.glow_enabled = false
 env.adjustment_enabled = false
 world.environment = env
 add_child(world)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48, -32, 0)
 sun.light_energy = 0.8
 sun.shadow_enabled = true
 add_child(sun)
 var ground := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(80, 80)
 ground.mesh = plane
 ground.position.y = -0.08
 var material := StandardMaterial3D.new()
 material.albedo_color = Color(0.19, 0.21, 0.23)
 material.roughness = 0.95
 ground.material_override = material
 add_child(ground)
 var camera := Camera3D.new()
 camera.name = "CloseupThreeByThreeCamera"
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 43.0
 camera.position = Vector3(0, 34, 34)
 camera.current = true
 add_child(camera)
 camera.look_at(Vector3(0, 2, 0), Vector3.UP)

func _add_model_card(item: Dictionary, slot: int) -> void:
 var model := Assets._load_gltf(String(item.path))
 if model == null:
  return
 var bounds: AABB = Assets._measure_bounds(model, Transform3D.IDENTITY)
 var dims: Vector3 = item.dimensions
 var footprint := max(dims.x, dims.z)
 var scale_factor := NORMALIZED_FOOTPRINT / max(footprint, 0.001)
 model.scale = Vector3.ONE * scale_factor
 var col := slot % 3
 var row := int(slot / 3)
 var center_x := (float(col) - 1.0) * CELL_SPACING
 var center_z := (float(row) - 1.0) * CELL_SPACING
 model.position = Vector3(center_x, -bounds.position.y * scale_factor, center_z)
 add_child(model)
 model_nodes.append(model)
 var label := Label3D.new()
 label.text = "%s\n%.2f × %.2f × %.2f m" % [String(item.path).get_file(), dims.x, dims.y, dims.z]
 label.font_size = 30
 label.outline_size = 8
 label.pixel_size = 0.008
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.modulate = Color(0.96, 0.94, 0.86)
 label.position = Vector3(center_x, max(2.0, dims.y * scale_factor + 1.0), center_z)
 add_child(label)
 model_nodes.append(label)
 print("LARGE_BUILDING_CARD_OK: ", String(item.path).get_file(), " | ", dims)

func _clear_batch() -> void:
 for node in model_nodes:
  if is_instance_valid(node):
   node.queue_free()
 model_nodes.clear()
 await get_tree().process_frame

func _write_filtered_manifest(items: Array[Dictionary]) -> void:
 var output_dir := ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(output_dir)
 var file := FileAccess.open(output_dir.path_join("filtered_large_buildings.txt"), FileAccess.WRITE)
 file.store_line("Filtered architectural models (original dimensions in metres)")
 file.store_line("Rule: width X >= 4.000 m AND depth Z >= 4.000 m")
 file.store_line("Count: %d" % items.size())
 file.store_line("")
 for index in range(items.size()):
  var item: Dictionary = items[index]
  var d: Vector3 = item.dimensions
  file.store_line("%03d | %s | %.3f x %.3f x %.3f m" % [index + 1, String(item.path).trim_prefix("res://"), d.x, d.y, d.z])
 file.close()
 print("LARGE_BUILDINGS_MANIFEST_OK: ", items.size(), " models")

func _capture_batch(batch_number: int, total_batches: int) -> void:
 for frame in range(12):
  await get_tree().process_frame
 var output_dir := ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(output_dir)
 var image := get_viewport().get_texture().get_image()
 var filename := "large_buildings_grid_%02d.png" % batch_number
 var error := image.save_png(output_dir.path_join(filename))
 if error != OK:
  push_error("LARGE_BUILDINGS_CAPTURE_FAILED: " + filename)
  get_tree().quit(1)
  return
 print("LARGE_BUILDINGS_GRID_CAPTURE_OK: ", filename, " batch=", batch_number, "/", total_batches)
