extends Node
## Offline mount runtime. Uses imported CC0 GLBs; never creates procedural animal geometry.
signal mount_state_changed(is_mounted: bool, mount_type: String)
const MOUNT_MODELS := {
 "steed":"res://assets/mounts/steed_horse.glb",
 "tiger":"res://assets/mounts/mount_tiger.glb",
 "deer":"res://assets/mounts/mount_deer.glb",
 "wolf":"res://assets/mounts/mount_wolf.glb"
}
const SKIN_TYPES := {
 "mount_skin_tiger":"tiger",
 "mount_skin_deer":"deer",
 "mount_skin_wolf":"wolf",
 "mount_skin_lion":"wolf"
}
const SKIN_BONUSES := {
 "tiger":{"attack":45,"defense":20,"speed":1.35,"critical":0.08},
 "deer":{"attack":18,"defense":28,"speed":1.65,"critical":0.03},
 "wolf":{"attack":38,"defense":25,"speed":1.20,"critical":0.06}
}
var hero: CharacterBody3D
var mount_visual: Node3D
var mounted := false
var active_mount_type := ""
var _hero_model: Node3D
var _hero_model_base_y := 0.0
var _base_move_speed := 7.0

func _ready() -> void:
 var gear := get_node_or_null("/root/GearSystem")
 if gear != null and gear.has_signal("equipment_changed") and not gear.equipment_changed.is_connected(_on_equipment_changed):
  gear.equipment_changed.connect(_on_equipment_changed)
 print("MOUNT_SYSTEM_READY: offline=true cc0_models=4")

func bind_hero(value: Node3D) -> void:
 if not value is CharacterBody3D: return
 hero = value as CharacterBody3D
 _hero_model = hero.get("hero_model") as Node3D
 if _hero_model != null: _hero_model_base_y = _hero_model.position.y
 _base_move_speed = float(hero.get("move_speed"))
 if mounted: _refresh_visual()

func get_equipped_mount_type() -> String:
 var gear := get_node_or_null("/root/GearSystem")
 if gear == null: return ""
 var steed: Dictionary = gear.get_equipped("steed")
 if steed.is_empty(): return ""
 var skin: Dictionary = gear.get_equipped("mount_skin")
 if skin.is_empty(): return "steed"
 var skin_id := String(skin.get("id",skin.get("item_id",""))).to_lower()
 for key in SKIN_TYPES:
  if skin_id.contains(key) or skin_id.contains(String(SKIN_TYPES[key])):
   return String(SKIN_TYPES[key])
 return "steed"

func get_mount_bonuses() -> Dictionary:
 var gear := get_node_or_null("/root/GearSystem")
 if gear == null: return {"attack":0,"defense":0,"max_hp":0,"speed":0.0,"critical":0.0}
 var steed: Dictionary = gear.get_equipped("steed")
 if steed.is_empty(): return {"attack":0,"defense":0,"max_hp":0,"speed":0.0,"critical":0.0}
 var plus := clampi(int(steed.get("plus",0)),0,12)
 var result := {"attack":int(steed.get("attack_bonus",0))+plus*12,"defense":int(steed.get("defense_bonus",0))+plus*8,"max_hp":500+plus*180,"speed":0.75+float(plus)*0.055,"critical":0.0}
 var kind := get_equipped_mount_type()
 if SKIN_BONUSES.has(kind):
  var skin: Dictionary = SKIN_BONUSES[kind]
  result.attack = int(result.attack)+int(skin.attack)
  result.defense = int(result.defense)+int(skin.defense)
  result.speed = float(result.speed)+float(skin.speed)
  result.critical = float(skin.critical)
 return result

func upgrade_steed(plus_level: int) -> bool:
 var gear := get_node_or_null("/root/GearSystem")
 if gear == null: return false
 var steed: Dictionary = gear.get_equipped("steed")
 if steed.is_empty(): return false
 var next_plus := clampi(plus_level,0,12)
 steed.plus = next_plus
 steed.display_name = "الخيل +%d" % next_plus
 steed.attack_bonus = 48+next_plus*12
 steed.defense_bonus = 36+next_plus*8
 steed.max_hp_bonus = 500+next_plus*180
 steed.mount_speed_bonus = 0.75+float(next_plus)*0.055
 gear.equip_item("steed",steed)
 print("STEED_UPGRADE_APPLIED: plus=+",next_plus," max_hp=",steed.max_hp_bonus," attack=",steed.attack_bonus," defense=",steed.defense_bonus," speed=",steed.mount_speed_bonus)
 return true

func mount(value: Node3D = null) -> bool:
 if value != null: bind_hero(value)
 if hero == null or not is_instance_valid(hero): return false
 if get_equipped_mount_type().is_empty():
  push_warning("MOUNT_REQUIRES_EQUIPPED_STEED")
  return false
 if mounted: return true
 mounted = true
 _refresh_visual()
 if mount_visual == null:
  mounted = false
  return false
 _apply_rider_pose(true)
 _apply_speed()
 mount_state_changed.emit(true,active_mount_type)
 print("MOUNT_RIDE_OK: type=",active_mount_type," rider_attached=true")
 return true

func dismount() -> bool:
 if not mounted: return true
 mounted = false
 if is_instance_valid(mount_visual): mount_visual.queue_free()
 mount_visual = null
 active_mount_type = ""
 _apply_rider_pose(false)
 if hero != null and is_instance_valid(hero): hero.set("move_speed",_base_move_speed)
 mount_state_changed.emit(false,"")
 print("MOUNT_DISMOUNT_OK: horse_and_skin_preserved=true")
 return true

func toggle_mount() -> bool:
 return dismount() if mounted else mount()

func _on_equipment_changed(_slot: String,_item: Dictionary) -> void:
 if mounted: _refresh_visual()

func _refresh_visual() -> void:
 if not mounted or hero == null: return
 var kind := get_equipped_mount_type()
 if kind.is_empty(): dismount(); return
 if kind == active_mount_type and is_instance_valid(mount_visual): return
 if is_instance_valid(mount_visual): mount_visual.queue_free()
 mount_visual = null
 active_mount_type = kind
 var path := String(MOUNT_MODELS.get(kind,""))
 if path.is_empty() or not ResourceLoader.exists(path):
  push_error("MOUNT_MODEL_MISSING: "+path)
  return
 var packed := load(path) as PackedScene
 if packed == null:
  push_error("MOUNT_MODEL_LOAD_FAILED: "+path)
  return
 var instance := packed.instantiate() as Node3D
 if instance == null:
  push_error("MOUNT_MODEL_INSTANCE_FAILED: "+path)
  return
 instance.name = "Mounted_"+kind.capitalize()
 hero.add_child(instance)
 _fit_mount_model(instance,kind)
 mount_visual = instance
 var gear := get_node_or_null("/root/GearSystem")
 var steed: Dictionary = gear.get_equipped("steed") if gear != null else {}
 var aura := get_node_or_null("/root/AuraAndVFXManager")
 if aura != null and aura.has_method("attach_equipment_aura"):
  aura.attach_equipment_aura(instance,int(steed.get("plus",0)),false)
 _apply_speed()
 print("MOUNT_VISUAL_SWAPPED: model=",kind," steed_plus=",int(steed.get("plus",0))," aura_inherited=true")

func _fit_mount_model(root: Node3D,kind: String) -> void:
 var bounds := _measure_bounds(root)
 if bounds.size.y <= 0.001: return
 var target_height := 1.75 if kind == "steed" else 1.55
 var factor := target_height/bounds.size.y
 root.scale = Vector3.ONE*factor
 root.position = Vector3(0,-bounds.position.y*factor,0)
 root.rotation.y = PI

func _measure_bounds(root: Node3D) -> AABB:
 var bounds := AABB()
 var found := false
 var stack: Array[Dictionary] = [{"node":root,"transform":Transform3D.IDENTITY}]
 while not stack.is_empty():
  var entry: Dictionary = stack.pop_back()
  var node: Node = entry.node
  var transform: Transform3D = entry.transform
  if node is MeshInstance3D:
   var mesh := node as MeshInstance3D
   if mesh.mesh != null:
    var box: AABB = transform*mesh.get_aabb()
    bounds = box if not found else bounds.merge(box)
    found = true
  for child in node.get_children():
   if child is Node3D:
    stack.append({"node":child,"transform":transform*(child as Node3D).transform})
 return bounds if found else AABB()

func _apply_rider_pose(on_mount: bool) -> void:
 if _hero_model == null or not is_instance_valid(_hero_model): return
 _hero_model.position.y = _hero_model_base_y+(1.05 if on_mount else 0.0)

func _apply_speed() -> void:
 if hero == null or not is_instance_valid(hero): return
 var bonuses := get_mount_bonuses()
 hero.set("move_speed",_base_move_speed+float(bonuses.speed))

func run_functional_test(test_hero: Node3D) -> bool:
 bind_hero(test_hero)
 var gear := get_node_or_null("/root/GearSystem")
 var state := get_node_or_null("/root/GameState")
 var db := get_node_or_null("/root/GearDatabase")
 var merchant := get_node_or_null("/root/NPCMerchantSystem")
 if gear == null or state == null or db == null or merchant == null: return false
 var old_equipped: Dictionary = gear.equipped.duplicate(true)
 var old_slots: Array = state.inventory_slots.duplicate(true)
 var old_inventory: Dictionary = state.inventory.duplicate(true)
 var old_gold := int(state.gold)
 var passed := true
 var steed: Dictionary = db.get_item("preview_steed_p12")
 if steed.is_empty(): passed = false
 if passed:
  gear.equip_item("steed",steed)
  gear.unequip_item("mount_skin")
  var garment: Dictionary = db.get_item("preview_garment")
  var accessory: Dictionary = db.get_item("preview_weapon_accessory")
  passed = not garment.is_empty() and not accessory.is_empty()
  if passed:
   gear.equip_item("garment",garment)
   gear.equip_item("weapon_accessory",accessory)
   var stats: Dictionary = gear.get_combat_bonuses()
   passed = int(stats.get("max_hp",0)) >= 900 and float(stats.get("critical",0.0)) > 0.0
   passed = passed and gear.unequip_item("garment") and gear.unequip_item("weapon_accessory")
 if passed:
  state.inventory_slots.clear()
  state.inventory.clear()
  passed = state.add_item("HPPotion",1)
  if passed:
   var sale: Dictionary = merchant.sell_item(0,1)
   passed = bool(sale.get("ok",false)) and state.inventory_slots.is_empty() and int(sale.get("gold_earned",0)) > 0
 for kind in ["steed","tiger","deer","wolf"]:
  if kind == "steed":
   gear.unequip_item("mount_skin")
  else:
   var skin: Dictionary = db.get_item("mount_skin_"+kind)
   if skin.is_empty():
    passed = false
    break
   gear.equip_item("mount_skin",skin)
  if not mount(test_hero):
   passed = false
   break
  if active_mount_type != kind or not is_instance_valid(mount_visual):
   passed = false
  if not dismount():
   passed = false
  if not passed: break
 gear.equipped = old_equipped.duplicate(true)
 gear._persist_equipment()
 state.inventory_slots = old_slots.duplicate(true)
 state.inventory = old_inventory.duplicate(true)
 state.set_gold(old_gold)
 state.save_game()
 if passed:
  print("MOUNT_AND_EQUIP_TEST_PASS=true")
 else:
  push_error("MOUNT_AND_EQUIP_TEST_PASS=false")
 return passed
