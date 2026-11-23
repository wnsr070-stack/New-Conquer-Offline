extends Node3D
const CharacterController = preload("res://scripts/CharacterVisualController.gd")
var captures := [
 {"file":"phase3b_01_archer_bow.png","class":"archer","level":30,"plus":1,"shadow":false,"extra":[],"pos":Vector3(1.8,1.8,2.35),"target":Vector3(0,1.05,0)},
 {"file":"phase3b_02_oriental_assassin_dual_knives.png","class":"oriental_assassin","level":40,"plus":3,"shadow":true,"extra":[],"pos":Vector3(1.8,1.8,2.35),"target":Vector3(0,1.05,0)},
 {"file":"phase3b_03_dual_blades_axes.png","class":"trojan","level":60,"plus":5,"shadow":false,"extra":[{"asset":"axe","pos":Vector3(-0.95,1.0,0.08)}],"pos":Vector3(2.0,1.9,2.65),"target":Vector3(0,1.05,0)},
 {"file":"phase3b_04_spear_halberd_greatsword_shield.png","class":"warrior","level":90,"plus":7,"shadow":false,"extra":[{"asset":"spear","pos":Vector3(-1.0,0.8,0.1)},{"asset":"halberd","pos":Vector3(1.0,0.8,0.1)},{"asset":"shield","pos":Vector3(0.0,0.65,-0.55)}],"pos":Vector3(2.3,2.0,3.1),"target":Vector3(0,1.0,0)},
 {"file":"phase3b_05_mage_magic_staff.png","class":"taoist","level":100,"plus":9,"shadow":false,"extra":[],"pos":Vector3(1.8,1.8,2.35),"target":Vector3(0,1.05,0)},
 {"file":"phase3b_06_ninja_katana_shuriken_plus12.png","class":"ninja","level":130,"plus":12,"shadow":false,"extra":[{"asset":"shuriken","pos":Vector3(-0.8,1.55,-0.15)}],"pos":Vector3(1.8,1.8,2.35),"target":Vector3(0,1.05,0)}
]
func _ready() -> void:
 if OS.get_environment("CI_CAPTURE") == "1": _capture_all.call_deferred()
func _capture_all() -> void:
 var output := "res://artifacts/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 for spec in captures:
  for child in get_children(): child.queue_free()
  await get_tree().process_frame
  _build_stage()
  if spec.get("kind","") == "showcase":
   if not _build_weapon_showcase():
    push_error("PHASE3B_CAPTURE_FAILED_REQUIRED_WEAPON_SHOWCASE")
    get_tree().quit(2)
    return
  else:
   var hero := CharacterController.new()
   add_child(hero)
   hero.build_character(spec["class"],spec.level)
   if not hero.assets_ready:
    push_error("PHASE3B_CAPTURE_FAILED_REQUIRED_IMPORTED_ASSETS: " + spec.file)
    get_tree().quit(2)
    return
   hero.set_weapon_upgrade(spec.plus,"Super",spec.level)
   if spec.shadow: hero.activate_path_of_shadow(true)
   for extra in spec.get("extra",[]):
    if not _add_weapon_prop(extra.asset,extra.pos):
     push_error("PHASE3B_CAPTURE_FAILED_EXTRA_WEAPON: "+str(extra.asset))
     get_tree().quit(2)
     return
  var camera := Camera3D.new()
  camera.position = spec.pos
  camera.look_at(spec.target,Vector3.UP)
  camera.fov = 38.0 if spec.get("plus",5) <= 5 else 34.0
  add_child(camera)
  camera.current = true
  await get_tree().process_frame
  await get_tree().process_frame
  var image := get_viewport().get_texture().get_image()
  var path := output + spec.file
  var error := image.save_png(path)
  if error != OK: push_error("PHASE3B_CAPTURE_FAILED: "+spec.file)
  else: print("PHASE3B_CAPTURE_OK: ",spec.file)
  await get_tree().process_frame
 print("PHASE3B_ALL_SIX_CAPTURES_COMPLETE")
 get_tree().quit()
func _add_weapon_prop(asset_name: String, prop_position: Vector3) -> bool:
 var filename := "quaternius_shuriken.glb" if asset_name == "shuriken" else "quaternius_" + asset_name + ".glb"
 var path := "res://assets/phase3b/" + filename
 if not ResourceLoader.exists(path):
  push_error("PHASE3B_EXTRA_WEAPON_MISSING: " + path)
  return false
 var packed := load(path) as PackedScene
 if packed == null: return false
 var model := packed.instantiate() as Node3D
 if model == null: return false
 model.position = prop_position
 model.scale = Vector3.ONE * 0.48
 add_child(model)
 return true
func _build_stage() -> void:
 var world := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color(0.34,0.39,0.45)
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color(0.78,0.78,0.80)
 env.ambient_light_energy = 0.85
 world.environment = env
 add_child(world)
 var floor := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(16,16)
 floor.mesh = plane
 var mat := StandardMaterial3D.new()
 mat.albedo_color = Color(0.40,0.36,0.30)
 mat.roughness = 0.95
 floor.material_override = mat
 add_child(floor)
 for side in [-1.0,1.0]:
  var pillar := MeshInstance3D.new()
  var pillar_mesh := BoxMesh.new()
  pillar_mesh.size = Vector3(0.38,3.0,0.38)
  pillar.mesh = pillar_mesh
  pillar.position = Vector3(side*2.35,1.5,-1.2)
  var pillar_mat := StandardMaterial3D.new()
  pillar_mat.albedo_color = Color(0.34,0.16,0.12)
  pillar.material_override = pillar_mat
  add_child(pillar)
  var cap := MeshInstance3D.new()
  var cap_mesh := BoxMesh.new()
  cap_mesh.size = Vector3(0.56,0.16,0.56)
  cap.mesh = cap_mesh
  cap.position = Vector3(side*2.35,3.05,-1.2)
  var cap_mat := StandardMaterial3D.new()
  cap_mat.albedo_color = Color(0.78,0.56,0.20)
  cap.material_override = cap_mat
  add_child(cap)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-45,-30,0)
 sun.light_energy = 1.45
 add_child(sun)
