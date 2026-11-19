extends Node3D
const Assets = preload("res://scripts/AssetLoader.gd")
const PALACE_ID := "3dassets-royal-court-and-throne-palace-palace-audience-house-55f0cb24"
const MODELS := [
 {"id":"landmark_chinese_architecture","height":20.0,"x":-48.0,"label":"CHINESE ARCHITECTURE"},
 {"id":"landmark_big_chinese_house","height":24.0,"x":-16.0,"label":"CHINESE HOUSE"},
 {"id":"landmark_chinese_fireworks_shop","height":18.0,"x":16.0,"label":"CHINESE FIREWORKS SHOP"},
 {"id":PALACE_ID,"height":30.0,"x":48.0,"label":"IMPERIAL PALACE"}
]
func _ready() -> void:
 _build_lighting()
 _build_stage()
 for item in MODELS:
  var model: Node3D = Assets.load_model(item.id, "")
  if model == null:
   push_error("LANDMARKS_PREVIEW_FAILED: required model unavailable: " + item.id)
   get_tree().quit(1)
   return
  Assets.fit_height(model, item.height)
  model.position = Vector3(item.x, 0, 0)
  add_child(model)
  var bounds: AABB = Assets._measure_bounds(model, Transform3D.IDENTITY)
  var dimensions := Vector3(bounds.size.x, bounds.size.y, bounds.size.z)
  print("LANDMARK_MODEL_OK: ", item.id)
  print("LANDMARK_DIMENSIONS_OK: ", item.id, " width=", snappedf(dimensions.x, 0.01), "m height=", snappedf(dimensions.y, 0.01), "m depth=", snappedf(dimensions.z, 0.01), "m")
  var label := Label3D.new()
  label.text = "%s\n%.2f x %.2f x %.2f m" % [item.label, dimensions.x, dimensions.y, dimensions.z]
  label.font_size = 38
  label.outline_size = 10
  label.pixel_size = 0.012
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  label.modulate = Color(1.0, 0.94, 0.78)
  label.position = Vector3(item.x, item.height + 3.0, 0)
  add_child(label)
 var camera := Camera3D.new()
 camera.name = "EasternBuildingsPreviewCamera"
 camera.fov = 48.0
 camera.position = Vector3(0, 36, 118)
 camera.current = true
 add_child(camera)
 camera.look_at(Vector3(0, 14, 0), Vector3.UP)
 _capture.call_deferred()

func _build_lighting() -> void:
 var world := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 var sky_material := ProceduralSkyMaterial.new()
 sky_material.sky_top_color = Color(0.12, 0.19, 0.29)
 sky_material.sky_horizon_color = Color(0.62, 0.69, 0.76)
 sky.sky_material = sky_material
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
 env.ambient_light_energy = 0.72
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 env.tonemap_exposure = 0.9
 world.environment = env
 add_child(world)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-42, -32, 0)
 sun.light_energy = 0.82
 sun.shadow_enabled = true
 add_child(sun)
 var fill := DirectionalLight3D.new()
 fill.rotation_degrees = Vector3(-18, 145, 0)
 fill.light_energy = 0.28
 fill.light_color = Color(0.72, 0.80, 1.0)
 add_child(fill)

func _build_stage() -> void:
 var ground := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(170, 90)
 ground.mesh = plane
 ground.position.y = -0.65
 var ground_mat := StandardMaterial3D.new()
 ground_mat.albedo_color = Color(0.12, 0.15, 0.18)
 ground_mat.roughness = 0.94
 ground.material_override = ground_mat
 add_child(ground)
 for x in [-48.0, -16.0, 16.0, 48.0]:
  var plinth := MeshInstance3D.new()
  var cylinder := CylinderMesh.new()
  cylinder.top_radius = 12.0
  cylinder.bottom_radius = 12.5
  cylinder.height = 0.8
  cylinder.radial_segments = 64
  plinth.mesh = cylinder
  plinth.position = Vector3(x, -0.25, 0)
  var material := StandardMaterial3D.new()
  material.albedo_color = Color(0.30, 0.23, 0.15)
  material.roughness = 0.76
  plinth.material_override = material
  add_child(plinth)

func _capture() -> void:
 for frame in range(30):
  await get_tree().process_frame
 var dir := ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(dir)
 var image := get_viewport().get_texture().get_image()
 var path := dir.path_join("eastern_buildings_palace_preview.png")
 var err := image.save_png(path)
 if err != OK:
  push_error("LANDMARKS_PREVIEW_FAILED: could not save " + path)
  get_tree().quit(1)
  return
 print("LANDMARKS_PREVIEW_CAPTURE_OK: ", path)
 get_tree().quit(0)
