extends Node3D
const ROOT := "res://assets/phase3b/"
const CHARS := {"archer":"characters/ara3d_archer.glb","oriental_assassin":"characters/ara3d_assassin.glb","trojan":"characters/ara3d_trojan.glb","warrior":"characters/ara3d_warrior.glb","taoist":"characters/ara3d_taoist.glb","ninja":"characters/ara3d_assassin.glb","monk":"characters/ara3d_warrior.glb"}
const WEAPONS := {"bow":"quaternius_bow.glb","dual_daggers":"quaternius_dagger.glb","dual_blades":"quaternius_sword.glb","spear":"quaternius_spear.glb","magic_staff":"quaternius_staff.glb","katana":"quaternius_sword.glb","staff":"quaternius_staff.glb"}
var assets_ready := false
var character_root: Node3D
var weapon_root: Node3D

func build_character(class_id: String, _level: int) -> void:
    assets_ready = false
    character_root = Node3D.new()
    character_root.name = "HighDetailAra3DCharacter"
    add_child(character_root)
    var path: String = ROOT + str(CHARS.get(class_id, ""))
    if not ResourceLoader.exists(path):
        push_error("PHASE3B_HIGH_DETAIL_CHARACTER_MISSING: " + path)
        return
    var packed := load(path) as PackedScene
    if packed == null:
        return
    var model := packed.instantiate() as Node3D
    if model == null:
        return
    character_root.add_child(model)
    var skeleton := _find_skeleton(model)
    if skeleton == null or skeleton.find_bone("WeaponR") < 0:
        push_error("PHASE3B_WEAPONR_SOCKET_NOT_FOUND: " + path)
        return
    var attachment := BoneAttachment3D.new()
    attachment.name = "WeaponR_Attachment"
    attachment.bone_name = "WeaponR"
    skeleton.add_child(attachment)
    var family := _weapon_for_class(class_id)
    var weapon_path: String = ROOT + str(WEAPONS.get(family, ""))
    if not ResourceLoader.exists(weapon_path):
        push_error("PHASE3B_REQUIRED_WEAPON_MISSING: " + weapon_path)
        return
    var weapon_scene := load(weapon_path) as PackedScene
    if weapon_scene == null:
        return
    weapon_root = weapon_scene.instantiate() as Node3D
    if weapon_root == null:
        return
    weapon_root.name = "Attached_" + family
    attachment.add_child(weapon_root)
    _normalize_weapon(weapon_root, 0.82)
    weapon_root.position = Vector3.ZERO
    character_root.rotation_degrees.y = 25.0
    assets_ready = true
    print("PHASE3B_HIGH_DETAIL_CHARACTER_LOADED: ", class_id, " ", path)

func _weapon_for_class(class_id: String) -> String:
    var map := {"archer":"bow","oriental_assassin":"dual_daggers","trojan":"dual_blades","warrior":"spear","taoist":"magic_staff","ninja":"katana","monk":"staff"}
    return str(map.get(class_id, "bow"))

func normalize_character() -> bool:
    var bounds := _mesh_bounds(character_root)
    if bounds.size.y <= 0.001:
        return false
    character_root.scale = Vector3.ONE * (1.8 / bounds.size.y)
    bounds = _mesh_bounds(character_root)
    character_root.global_position.x -= bounds.position.x + bounds.size.x * 0.5
    character_root.global_position.y -= bounds.position.y
    character_root.global_position.z -= bounds.position.z + bounds.size.z * 0.5
    return true

func set_weapon_upgrade(plus_level: int, quality: String = "Super", _tier: int = 130) -> void:
    if plus_level == 12 and quality == "Super" and is_instance_valid(weapon_root):
        _emission(weapon_root, Color(1.0,0.72,0.22), 1.6)
    elif plus_level >= 9 and is_instance_valid(weapon_root):
        _emission(weapon_root, Color(1.0,0.58,0.16), 0.9)

func activate_path_of_shadow(_enabled: bool = true) -> void:
    pass

func _emission(root: Node, color: Color, energy: float) -> void:
    if root is MeshInstance3D:
        var mi := root as MeshInstance3D
        if mi.mesh != null:
            for i in range(mi.mesh.get_surface_count()):
                var src = mi.get_active_material(i)
                var mat := StandardMaterial3D.new()
                if src is StandardMaterial3D:
                    mat = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
                mat.emission_enabled = true
                mat.emission = color
                mat.emission_energy_multiplier = energy
                mi.set_surface_override_material(i, mat)
    for child in root.get_children():
        _emission(child, color, energy)

func _normalize_weapon(root: Node3D, target: float) -> void:
    var b := _mesh_bounds(root)
    var extent := maxf(b.size.x, maxf(b.size.y, b.size.z))
    if extent <= 0.001:
        return
    root.scale = Vector3.ONE * target / extent
    b = _mesh_bounds(root)
    root.global_position -= b.position + b.size * 0.5

func _find_skeleton(root: Node) -> Skeleton3D:
    if root is Skeleton3D:
        return root as Skeleton3D
    for child in root.get_children():
        var result := _find_skeleton(child)
        if result != null:
            return result
    return null

func _mesh_bounds(root: Node) -> AABB:
    var bounds := AABB()
    var found := false
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            var mi := node as MeshInstance3D
            if mi.mesh != null:
                var box: AABB = mi.global_transform * mi.get_aabb()
                bounds = box if not found else bounds.merge(box)
                found = true
        for child in node.get_children():
            stack.append(child)
    return bounds if found else AABB()
