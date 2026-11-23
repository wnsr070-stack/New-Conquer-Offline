extends Node3D
const ASSET_ROOT := "res://assets/phase3b/"
const SHADOW_COLOR := Color(0.18, 0.08, 0.32, 0.42)
const CHARACTER_ASSETS := {
 "archer": "quaternius_archer.glb",
 "oriental_assassin": "quaternius_assassin.glb",
 "trojan": "quaternius_warrior.glb",
 "warrior": "quaternius_knight.glb",
 "taoist": "quaternius_mage.glb",
 "ninja": "quaternius_assassin.glb",
 "monk": "quaternius_warrior.glb"
}
const WEAPON_ASSETS := {
 "bow": "quaternius_bow.glb",
 "dual_daggers": "quaternius_throwing_knife.glb",
 "dual_blades": "quaternius_sword.glb",
 "dual_axes": "quaternius_axe.glb",
 "spear": "quaternius_spear.glb",
 "halberd": "quaternius_halberd.glb",
 "infernal_greatsword": "quaternius_sword.glb",
 "shield": "quaternius_shield.glb",
 "magic_staff": "quaternius_staff.glb",
 "katana": "quaternius_sword.glb",
 "shuriken": "quaternius_shuriken.glb",
 "staff": "quaternius_staff.glb"
}
var active_class := "archer"
var active_level := 1
var active_weapon_family := "bow"
var active_plus := 5
var shadow_active := false
var assets_ready := false
var character_root: Node3D
var weapon_root: Node3D
var aura_root: Node3D

func _ready() -> void:
 build_character("archer", 1)

func build_character(class_id: String, level: int) -> void:
 assets_ready = false
 active_class = class_id
 active_level = level
 active_weapon_family = _weapon_for_class(class_id)
 if is_instance_valid(character_root):
  character_root.queue_free()
 character_root = Node3D.new()
 character_root.name = "ImportedHeroCharacter"
 add_child(character_root)
 var character_path := ASSET_ROOT + str(CHARACTER_ASSETS.get(class_id, ""))
 if not ResourceLoader.exists(character_path):
  push_error("PHASE3B_REQUIRED_CHARACTER_MISSING: " + character_path)
  return
 var character_scene := load(character_path) as PackedScene
 if character_scene == null:
  push_error("PHASE3B_CHARACTER_NOT_PACKED_SCENE: " + character_path)
  return
 var imported_character := character_scene.instantiate() as Node3D
 if imported_character == null:
  push_error("PHASE3B_CHARACTER_ROOT_NOT_NODE3D: " + character_path)
  return
 imported_character.name = "QuaterniusCharacter"
 character_root.add_child(imported_character)
 _tint_imported_model(imported_character, Color(0.78, 0.91, 0.66) if class_id == "archer" else Color(0.78, 0.52, 0.58) if class_id == "oriental_assassin" else Color(0.82, 0.82, 0.88))
 _build_weapon()
 if is_instance_valid(weapon_root) and weapon_root.get_child_count() > 0:
  assets_ready = true
 _apply_shadow_state()
 print("PHASE3B_REAL_CHARACTER_LOADED: ", class_id, " level=", level, " source=", character_path)

func _weapon_for_class(class_id: String) -> String:
 var mapping := {"archer":"bow","oriental_assassin":"dual_daggers","trojan":"dual_blades","warrior":"infernal_greatsword","taoist":"magic_staff","ninja":"katana","monk":"staff"}
 return mapping.get(class_id, "bow")

func _build_weapon() -> void:
 if is_instance_valid(weapon_root):
  weapon_root.queue_free()
 weapon_root = Node3D.new()
 weapon_root.name = "ImportedSpecializedWeapon"
 weapon_root.position = Vector3(0.48, 1.0, 0.18)
 character_root.add_child(weapon_root)
 var asset_name: String = WEAPON_ASSETS.get(active_weapon_family, "")
 var weapon_path := ASSET_ROOT + asset_name
 if not ResourceLoader.exists(weapon_path):
  push_error("PHASE3B_REQUIRED_WEAPON_MISSING: " + weapon_path)
  return
 var weapon_scene := load(weapon_path) as PackedScene
 if weapon_scene == null:
  push_error("PHASE3B_WEAPON_NOT_PACKED_SCENE: " + weapon_path)
  return
 var imported_weapon := weapon_scene.instantiate() as Node3D
 if imported_weapon == null:
  push_error("PHASE3B_WEAPON_ROOT_NOT_NODE3D: " + weapon_path)
  return
 imported_weapon.name = "Quaternius_" + active_weapon_family
 imported_weapon.scale = Vector3.ONE * (0.72 if active_weapon_family == "bow" else 0.55)
 weapon_root.add_child(imported_weapon)
 if active_weapon_family == "dual_daggers" or active_weapon_family == "dual_blades":
  var offhand := imported_weapon.duplicate() as Node3D
  offhand.name = "Offhand_" + active_weapon_family
  offhand.position = Vector3(-0.78, -0.08, 0.02)
  offhand.rotation_degrees = Vector3(0, 180, 0)
  weapon_root.add_child(offhand)
 _tint_imported_model(imported_weapon, _tier_color(active_level))

func set_weapon_upgrade(plus_level: int, quality: String = "Super", tier_level: int = 130) -> void:
 active_plus = clampi(plus_level, 1, 12)
 if is_instance_valid(aura_root):
  aura_root.queue_free()
 aura_root = Node3D.new()
 aura_root.name = "ImportedWeaponUpgradeAura"
 add_child(aura_root)
 var energy := 0.25
 if active_plus >= 6: energy = 0.9
 if active_plus >= 9: energy = 1.8
 if active_plus == 12 and quality == "Super": energy = 3.2
 if is_instance_valid(weapon_root):
  _apply_weapon_emission(weapon_root, Color(1.0, 0.72, 0.22), energy)
 if active_plus >= 6:
  _add_aura_light(aura_root, Color(0.25, 0.58, 1.0) if active_plus <= 8 else Color(1.0, 0.58, 0.16), 1.4, 3.5)
 if active_plus >= 9:
  _add_aura_light(aura_root, Color(1.0, 0.68, 0.18), 2.0, 4.0)
 if active_plus == 12 and quality == "Super":
  _add_aura_light(aura_root, Color(0.56, 0.18, 0.92), 2.8, 5.0)
 print("PHASE3B_IMPORTED_WEAPON_AURA: plus=", active_plus, " quality=", quality, " emission=", energy, " tier=", tier_level)

func activate_path_of_shadow(enabled: bool = true) -> void:
 shadow_active = enabled
 _apply_shadow_state()
 if enabled:
  _add_aura_light(character_root, Color(0.32, 0.08, 0.72), 1.7, 4.0)
 print("PHASE3B_PATH_OF_SHADOW: active=", enabled)

func _apply_shadow_state() -> void:
 if not is_instance_valid(character_root):
  return
 _set_model_transparency(character_root, shadow_active)

func _set_model_transparency(root: Node, enabled: bool) -> void:
 for child in root.get_children():
  if child is MeshInstance3D:
   var mesh_instance := child as MeshInstance3D
   for surface in range(mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0):
    var source_material := mesh_instance.get_active_material(surface)
    if source_material is StandardMaterial3D:
     var material := (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
     if enabled:
      material.albedo_color = SHADOW_COLOR
      material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
      material.emission_enabled = true
      material.emission = Color(0.28, 0.08, 0.52)
      material.emission_energy_multiplier = 0.7
     else:
      material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
     mesh_instance.set_surface_override_material(surface, material)
  _set_model_transparency(child, enabled)

func _tint_imported_model(root: Node, tint: Color) -> void:
 for child in root.get_children():
  if child is MeshInstance3D:
   var mesh_instance := child as MeshInstance3D
   var surfaces := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
   for surface in range(surfaces):
    var source_material := mesh_instance.get_active_material(surface)
    if source_material is StandardMaterial3D:
     var material := (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
     material.albedo_color = material.albedo_color * tint
     mesh_instance.set_surface_override_material(surface, material)
  _tint_imported_model(child, tint)

func _apply_weapon_emission(root: Node, color: Color, energy: float) -> void:
 for child in root.get_children():
  if child is MeshInstance3D:
   var mesh_instance := child as MeshInstance3D
   var surfaces := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
   for surface in range(surfaces):
    var source_material := mesh_instance.get_active_material(surface)
    var material := StandardMaterial3D.new()
    if source_material is StandardMaterial3D:
     material = (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    mesh_instance.set_surface_override_material(surface, material)
  _apply_weapon_emission(child, color, energy)

func _add_aura_light(parent: Node3D, color: Color, energy: float, radius: float) -> void:
 var light := OmniLight3D.new()
 light.light_color = color
 light.light_energy = energy
 light.omni_range = radius
 light.position = Vector3(0, 1.0, 0)
 parent.add_child(light)

func _tier_color(level: int) -> Color:
 if level <= 30: return Color(0.68, 0.40, 0.20)
 if level <= 60: return Color(0.26, 0.52, 0.82)
 if level <= 90: return Color(0.82, 0.84, 0.92)
 if level <= 120: return Color(0.92, 0.30, 0.34)
 return Color(1.0, 0.72, 0.22)
