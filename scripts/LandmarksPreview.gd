extends Node3D
const Assets = preload("res://scripts/AssetLoader.gd")
const MODELS := [
 {"id":"landmark_tea_house","height":18.0,"x":-28.0,"label":"#1  GRAND CHINESE TEA HOUSE / TAVERN CANDIDATE"},
 {"id":"landmark_quest_hall","height":24.0,"x":0.0,"label":"#2  CHINESE TEMPLE / QUEST GUILD HALL CANDIDATE"},
 {"id":"landmark_forge_hall","height":20.0,"x":28.0,"label":"#3  CHINESE BLACKSMITH / IMPERIAL FORGE HALL CANDIDATE"}
]
func _ready() -> void:
 _build_lighting()
 _build_stage()
 for item in MODELS:
  var model := Assets.load_model(item.id,"")
  if model == null:
   push_error("LANDMARKS_PREVIEW_FAILED: required model unavailable: " + item.id)
   get_tree().quit(1)
   return
  Assets.fit_height(model,item.height)
  model.position = Vector3(item.x,0,0)
  add_child(model)
  print("LANDMARK_MODEL_OK: ",item.id)
  var label := Label3D.new()
  label.text = item.label
  label.font_size = 48
  label.outline_size = 10
  label.pixel_size = 0.012
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  label.modulate = Color(1.0,0.91,0.62)
  label.position = Vector3(item.x,item.height + 2.0,0)
  add_child(label)
 var camera := Camera3D.new()
 camera.name = "LandmarksPreviewCamera"
 camera.fov = 42.0
 camera.position = Vector3(0,32,92)
 camera.current = true
 add_child(camera)
 camera.look_at(Vector3(0,11,0),Vector3.UP)
 _capture.call_deferred()

func _build_lighting() -> void:
 var world := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 var sky_material := ProceduralSkyMaterial.new()
 sky_material.sky_top_color = Color(0.075,0.14,0.27)
 sky_material.sky_horizon_color = Color(0.63,0.72,0.82)
 sky.sky_material = sky_material
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
 env.ambient_light_energy = 0.9
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 world.environment = env
 add_child(world)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48,-28,0)
 sun.light_energy = 1.35
 sun.shadow_enabled = true
 add_child(sun)
 var fill := DirectionalLight3D.new()
 fill.rotation_degrees = Vector3(-18,145,0)
 fill.light_energy = 0.45
 fill.light_color = Color(0.68,0.78,1.0)
 add_child(fill)

func _build_stage() -> void:
 var ground := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(110,58)
 ground.mesh = plane
 ground.position.y = -0.65
 var ground_mat := StandardMaterial3D.new()
 ground_mat.albedo_color = Color(0.105,0.14,0.18)
 ground_mat.roughness = 0.92
 ground.material_override = ground_mat
 add_child(ground)
 for x in [-28.0,0.0,28.0]:
  var plinth := MeshInstance3D.new()
  var cylinder := CylinderMesh.new()
  cylinder.top_radius = 9.5
  cylinder.bottom_radius = 10.0
  cylinder.height = 0.8
  cylinder.radial_segments = 64
  plinth.mesh = cylinder
  plinth.position = Vector3(x,-0.25,0)
  var material := StandardMaterial3D.new()
  material.albedo_color = Color(0.30,0.22,0.13)
  material.roughness = 0.72
  plinth.material_override = material
  add_child(plinth)

func _capture() -> void:
 for frame in range(24):
  await get_tree().process_frame
 var dir := ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(dir)
 var image := get_viewport().get_texture().get_image()
 var path := dir.path_join("landmarks_preview.png")
 var err := image.save_png(path)
 if err != OK:
  push_error("LANDMARKS_PREVIEW_FAILED: could not save " + path)
  get_tree().quit(1)
  return
 print("LANDMARKS_PREVIEW_CAPTURE_OK: ",path)
 get_tree().quit(0)
