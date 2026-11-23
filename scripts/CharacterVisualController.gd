extends Node3D
const ROOT := "res://assets/phase3b/"
const CHARS := {
    "archer":"characters/ara3d_archer.glb",
    "oriental_assassin":"characters/ara3d_assassin.glb",
    "trojan":"characters/ara3d_trojan.glb",
    "warrior":"characters/ara3d_warrior.glb",
    "taoist":"characters/ara3d_taoist.glb",
    "ninja":"characters/ara3d_assassin.glb",
    "monk":"characters/ara3d_warrior.glb"
}
const WEAPONS := {
    "archer":"bow",
    "oriental_assassin":"dual_knives",
    "trojan":"dual_blades",
    "warrior":"spear_halberd",
    "taoist":"magic_staff",
    "ninja":"katana",
    "monk":"magic_staff"
}
const DUAL_CLASSES := ["oriental_assassin", "trojan", "ninja", "warrior"]
var assets_ready := false
var character_root: Node3D
var weapon_root: Node3D
var left_weapon_root: Node3D
var active_weapon_tier := "beginner"

func build_character(class_id: String, level: int) -> void:
    assets_ready = false
    character_root = Node3D.new()
    character_root.name = "HighDetailAra3DCharacter"
    add_child(character_root)
    var character_path: String = ROOT + str(CHARS.get(class_id, ""))
    if not ResourceLoader.exists(character_path):
        push_error("PHASE3B_HIGH_DETAIL_CHARACTER_MISSING: " + character_path)
        return
    var packed := load(character_path) as PackedScene
    if packed == null:
        push_error("PHASE3B_CHARACTER_SCENE_INVALID: " + character_path)
        return
    var model := packed.instantiate() as Node3D
    if model == null:
        push_error("PHASE3B_CHARACTER_ROOT_INVALID: " + character_path)
        return
    character_root.add_child(model)
    var skeleton := _find_skeleton(model)
    if skeleton == null:
        push_error("PHASE3B_CHARACTER_SKELETON_MISSING: " + character_path)
        return
    var right_bone := skeleton.find_bone("WeaponR")
    if right_bone < 0:
        push_error("PHASE3B_WEAPONR_SOCKET_NOT_FOUND: " + character_path)
        return
    var family := str(WEAPONS.get(class_id, "bow"))
    active_weapon_tier = _tier_for_level(level)
    var right_path := _weapon_path(family, active_weapon_tier)
    if not _attach_weapon(skeleton, "WeaponR", right_path, family, false):
        return
    if class_id in DUAL_CLASSES:
        var left_bone_name := _find_left_hand_bone(skeleton)
        if left_bone_name.is_empty():
            push_error("PHASE3B_WEAPONL_HAND_BONE_NOT_FOUND: " + character_path)
            return
        var left_family := "shuriken" if class_id == "ninja" else "shield" if class_id == "warrior" else family
        var left_path := _weapon_path(left_family, active_weapon_tier)
        if not _attach_weapon(skeleton, left_bone_name, left_path, left_family, true):
            return
    _apply_vertex_color_pbr(model)
    character_root.rotation_degrees.y = 25.0
    assets_ready = true
    print("PHASE3B_CHARACTER_WEAPONS_ATTACHED: ", class_id, " tier=", active_weapon_tier,
        " right=", right_path, " left=", is_instance_valid(left_weapon_root))

func _tier_for_level(level: int) -> String:
    if level <= 29:
        return "beginner"
    if level <= 59:
        return "steel"
    return "royal"

func _weapon_path(family: String, tier: String) -> String:
    if family == "shuriken":
        return ROOT + "quaternius_shuriken.glb"
    if family == "katana":
        return ROOT + "quaternius_library/katana_katana.glb"
    return ROOT + "weapons/" + family + "_" + tier + ".glb"

func _attach_weapon(skeleton: Skeleton3D, bone_name: String, path: String, family: String, left_hand: bool) -> bool:
    if not ResourceLoader.exists(path):
        push_error("PHASE3B_TIERED_WEAPON_MISSING: " + path)
        return false
    var packed := load(path) as PackedScene
    if packed == null:
        push_error("PHASE3B_TIERED_WEAPON_SCENE_INVALID: " + path)
        return false
    var attachment := BoneAttachment3D.new()
    attachment.name = ("WeaponL_Attachment" if left_hand else "WeaponR_Attachment")
    attachment.bone_name = bone_name
    skeleton.add_child(attachment)
    var weapon := packed.instantiate() as Node3D
    if weapon == null:
        push_error("PHASE3B_TIERED_WEAPON_ROOT_INVALID: " + path)
        attachment.queue_free()
        return false
    weapon.name = ("Left_" if left_hand else "Right_") + family
    attachment.add_child(weapon)
    _fit_weapon_grip(weapon, family, left_hand)
    _apply_vertex_color_pbr(weapon)
    if left_hand:
        left_weapon_root = weapon
    else:
        weapon_root = weapon
    return true

func _fit_weapon_grip(root: Node3D, family: String, left_hand: bool) -> void:
    var bounds := _local_mesh_bounds(root)
    var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
    if extent <= 0.001:
        push_error("PHASE3B_WEAPON_EMPTY_BOUNDS: " + family)
        return
    root.scale = Vector3.ONE * (0.82 / extent)
    # Rotate the longest source axis into the hand-to-tip direction.
    var axis := 0
    if bounds.size.y >= bounds.size.x and bounds.size.y >= bounds.size.z:
        axis = 1
    elif bounds.size.z >= bounds.size.x and bounds.size.z >= bounds.size.y:
        axis = 2
    if axis == 0:
        root.rotation.z = -PI * 0.5
    elif axis == 2:
        root.rotation.x = PI * 0.5
    var fitted := _parent_mesh_bounds(root)
    var grip := fitted.get_center()
    if family not in ["bow", "shield", "shuriken"]:
        # Put the lower end of the blade/staff/spear at the palm, not its centre.
        if fitted.size.y >= fitted.size.x and fitted.size.y >= fitted.size.z:
            grip.y = fitted.position.y + fitted.size.y * 0.12
        elif fitted.size.x >= fitted.size.z:
            grip.x = fitted.position.x + fitted.size.x * 0.12
        else:
            grip.z = fitted.position.z + fitted.size.z * 0.12
    root.position = -grip
    if left_hand:
        root.rotation.y += PI
        root.position.x += 0.025
    else:
        root.position.x -= 0.015
    print("PHASE3B_WEAPON_GRIP_FITTED: ", family, " hand=", "L" if left_hand else "R",
        " bounds=", fitted, " local_grip=", grip)

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
    if plus_level == 12 and quality == "Super":
        if is_instance_valid(weapon_root):
            _emission(weapon_root, Color(1.0, 0.72, 0.22), 1.6)
        if is_instance_valid(left_weapon_root):
            _emission(left_weapon_root, Color(1.0, 0.72, 0.22), 1.6)
    elif plus_level >= 9:
        if is_instance_valid(weapon_root):
            _emission(weapon_root, Color(1.0, 0.58, 0.16), 0.9)
        if is_instance_valid(left_weapon_root):
            _emission(left_weapon_root, Color(1.0, 0.58, 0.16), 0.9)

func activate_path_of_shadow(_enabled: bool = true) -> void:
    pass

func _apply_vertex_color_pbr(root: Node) -> void:
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            var mi := node as MeshInstance3D
            if mi.mesh != null:
                for surface in range(mi.mesh.get_surface_count()):
                    var source = mi.get_active_material(surface)
                    var material := StandardMaterial3D.new()
                    if source is StandardMaterial3D:
                        material = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
                    material.vertex_color_use_as_albedo = true
                    material.metallic = maxf(material.metallic, 0.22)
                    material.roughness = clampf(material.roughness, 0.16, 0.82)
                    mi.set_surface_override_material(surface, material)
        for child in node.get_children():
            stack.append(child)

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

func _find_left_hand_bone(skeleton: Skeleton3D) -> String:
    var preferred := ["WeaponL", "hand.l", "hand_l", "lefthand", "left_hand", "handleft", "hand_l_end"]
    for wanted in preferred:
        for index in range(skeleton.get_bone_count()):
            var name := skeleton.get_bone_name(index)
            if name.to_lower().replace(" ", "") == wanted.to_lower().replace(" ", ""):
                return name
    for index in range(skeleton.get_bone_count()):
        var name := skeleton.get_bone_name(index)
        var normalized := name.to_lower().replace("_", "").replace(".", "").replace(":", "")
        if normalized.contains("lefthand") or normalized.contains("handleft") or normalized.ends_with("handl"):
            return name
    return ""

func _find_skeleton(root: Node) -> Skeleton3D:
    if root is Skeleton3D:
        return root as Skeleton3D
    for child in root.get_children():
        var result := _find_skeleton(child)
        if result != null:
            return result
    return null

func _local_mesh_bounds(root: Node3D) -> AABB:
    var result := AABB()
    var found := false
    var inverse := root.global_transform.affine_inverse()
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            var mi := node as MeshInstance3D
            if mi.mesh != null:
                var box: AABB = inverse * mi.global_transform * mi.get_aabb()
                result = box if not found else result.merge(box)
                found = true
        for child in node.get_children():
            stack.append(child)
    return result if found else AABB()

func _parent_mesh_bounds(root: Node3D) -> AABB:
    var parent := root.get_parent() as Node3D
    if parent == null:
        return _local_mesh_bounds(root)
    var inverse := parent.global_transform.affine_inverse()
    var result := AABB()
    var found := false
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            var mi := node as MeshInstance3D
            if mi.mesh != null:
                var box: AABB = inverse * mi.global_transform * mi.get_aabb()
                result = box if not found else result.merge(box)
                found = true
        for child in node.get_children():
            stack.append(child)
    return result if found else AABB()

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
