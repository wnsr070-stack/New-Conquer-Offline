extends Node
## Animated sprite-only VFX and aura service. All visuals are authored PNG atlas frames;
## no procedural meshes or generated geometry are created here.
const EFFECT_ROOT := "res://assets/phase3b/effects/"
const FRAME_COLUMNS := 8
const FRAME_ROWS := 7
const EFFECT_FILES := {
 "explosion": ["explosion_blueish_flame.png","explosion_blueish_smoke.png","explosion_fire.png","explosion_fire_smoke.png","explosion_magic.png"],
 "flame": ["flame_blueish_flame.png","flame_blueish_smoke.png","flame_fire.png","flame_fire_smoke.png","flame_magic.png"],
 "flattened": ["flat_effect_blueish_flame.png","flat_effect_blueish_smoke.png","flat_effect_fire.png","flat_effect_fire_smoke.png","flat_effect_magic.png"],
 "ring": ["ring_blueish_flame.png","ring_blueish_smoke.png","ring_fire.png","ring_fire_smoke.png","ring_magic.png"],
 "shockwave": ["shockwave_blueish_flame.png","shockwave_blueish_smoke.png","shockwave_fire.png","shockwave_fire_smoke.png","shockwave_magic.png"]
}
const ANIMA_COLORS := {
 "green_blue": [Color(0.24,1.0,0.42),Color(0.18,0.62,1.0)],
 "gold": [Color(1.0,0.78,0.18)],
 "fire": [Color(1.0,0.32,0.08)],
 "purple": [Color(0.72,0.28,1.0)],
 "dual": [Color(1.0,0.72,0.16),Color(0.68,0.22,1.0)]
}
var _frames_cache: Dictionary = {}
var _atlas_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _material_cache: Dictionary = {}
var _active_orbits: Dictionary = {}
var _active_effect_roots: Array[Node] = []
var _orbit_clock := 0.0

func _track_effect_root(node: Node) -> void:
 if node != null and is_instance_valid(node) and not _active_effect_roots.has(node):
  _active_effect_roots.append(node)

func cleanup_all() -> void:
 set_process(false)
 _active_orbits.clear()
 var freed_roots := 0
 for node in _active_effect_roots:
  if not is_instance_valid(node):
   continue
  if node.is_inside_tree():
   node.queue_free()
  else:
   node.free()
  freed_roots += 1
 _active_effect_roots.clear()
 # Drop every strong cache reference. SpriteFrames owns its AtlasTexture frames,
 # which in turn own the loaded textures; clearing in this order releases them
 # when no scene node or other resource owner still references them.
 _frames_cache.clear()
 _atlas_cache.clear()
 _texture_cache.clear()
 _material_cache.clear()
 print("PHASE4D_AURA_VFX_CLEANUP_OK: roots=",freed_roots," frames=0 atlases=0 textures=0 materials=0 orbits=0")

func _exit_tree() -> void:
 cleanup_all()

func _process(delta: float) -> void:
 _orbit_clock += delta
 for orbit_id in _active_orbits.keys():
  var entry: Dictionary = _active_orbits[orbit_id]
  var controller := entry.get("node") as Node3D
  if not is_instance_valid(controller):
   _active_orbits.erase(orbit_id)
   continue
  for orb in controller.get_children():
   if not orb is AnimatedSprite3D: continue
   var angle := _orbit_clock*float(orb.get_meta("orbit_speed",1.0))+float(orb.get_meta("orbit_phase",0.0))
   var radius := float(orb.get_meta("orbit_radius",0.8))
   var wobble := float(orb.get_meta("orbit_wobble",0.15))
   var height := float(orb.get_meta("orbit_height",1.2))+sin(angle*1.7)*wobble
   orb.position = Vector3(cos(angle)*radius,height,sin(angle)*radius*0.72)

func _ready() -> void:
 print("PHASE4D_AURA_VFX_MANAGER_READY: sprite_frames=true billboard=true blend_add=true procedural_geometry=false")

func _make_material(tint: Color = Color.WHITE) -> StandardMaterial3D:
 var key := "%0.4f:%0.4f:%0.4f:%0.4f" % [tint.r,tint.g,tint.b,tint.a]
 if _material_cache.has(key):
  return _material_cache[key] as StandardMaterial3D
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
 material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
 material.albedo_color = tint
 material.emission_enabled = true
 material.emission = Color(tint.r,tint.g,tint.b,1.0)
 material.emission_energy_multiplier = 1.35
 material.no_depth_test = false
 _material_cache[key] = material
 return material

func _build_frames(effect_type: String, variant: int) -> SpriteFrames:
 var key := "%s:%d" % [effect_type,clampi(variant,0,4)]
 if _frames_cache.has(key): return _frames_cache[key] as SpriteFrames
 if not EFFECT_FILES.has(effect_type): return null
 var file_name: String = EFFECT_FILES[effect_type][clampi(variant,0,4)]
 var path := EFFECT_ROOT + file_name
 if not ResourceLoader.exists(path):
  push_warning("PHASE4D_VFX_ASSET_MISSING: "+path)
  return null
 var texture: Texture2D = _texture_cache.get(path) as Texture2D
 if texture == null:
  texture = load(path) as Texture2D
  if texture == null: return null
  _texture_cache[path] = texture
 var frames := SpriteFrames.new()
 frames.add_animation("play")
 frames.set_animation_loop("play",true)
 frames.set_animation_speed("play",18.0)
 var frame_w := maxi(1,texture.get_width()/FRAME_COLUMNS)
 var frame_h := maxi(1,texture.get_height()/FRAME_ROWS)
 for y in range(FRAME_ROWS):
  for x in range(FRAME_COLUMNS):
   var atlas := AtlasTexture.new()
   atlas.atlas = texture
   atlas.region = Rect2(x*frame_w,y*frame_h,frame_w,frame_h)
   frames.add_frame("play",atlas)
 _frames_cache[key] = frames
 return frames

func _make_sprite(effect_type: String, variant: int, tint: Color, scale_value: float, fps: float = 18.0) -> AnimatedSprite3D:
 var frames := _build_frames(effect_type,variant)
 if frames == null: return null
 var sprite := AnimatedSprite3D.new()
 sprite.sprite_frames = frames
 sprite.animation = "play"
 sprite.speed_scale = fps/18.0
 sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 sprite.material_override = _make_material(tint)
 sprite.modulate = tint
 sprite.pixel_size = 0.004
 sprite.scale = Vector3.ONE*scale_value
 sprite.play("play")
 return sprite

func _get_or_create_anchor(target: Node3D, anchor_name: String) -> Node3D:
 var found := target.get_node_or_null(anchor_name)
 if found is Node3D:
  _track_effect_root(found)
  return found as Node3D
 var anchor := Node3D.new()
 anchor.name = anchor_name
 target.add_child(anchor)
 _track_effect_root(anchor)
 return anchor

func _clear_anchor(target: Node3D, anchor_name: String) -> void:
 var old := target.get_node_or_null(anchor_name)
 if old != null:
  _active_effect_roots.erase(old)
  old.free()

func attach_equipment_aura(target_node: Node3D, plus_level: int) -> bool:
 if target_node == null or not is_instance_valid(target_node): return false
 _clear_anchor(target_node,"EquipmentSpriteAura")
 if plus_level < 3: return true
 var tier := clampi(int(ceil(float(plus_level-2)/2.5)),1,4)
 var tint := Color(0.25,0.82,1.0).lerp(Color(0.78,0.28,1.0),float(tier-1)/3.0)
 var anchor := _get_or_create_anchor(target_node,"EquipmentSpriteAura")
 var flame := _make_sprite("flame",2,tint,0.52+float(tier)*0.10,16.0+float(tier)*2.0)
 var ring := _make_sprite("ring",2,tint,0.42+float(tier)*0.12,12.0+float(tier)*1.5)
 if flame == null or ring == null: return false
 flame.position = Vector3(0,0.12,0)
 ring.position = Vector3(0,-0.05,0)
 ring.rotation_degrees.x = -90.0
 anchor.add_child(ring)
 anchor.add_child(flame)
 return true

func attach_character_aura(player_node: Node3D, min_set_plus: int, is_xp_active: bool) -> bool:
 if player_node == null or not is_instance_valid(player_node): return false
 _clear_anchor(player_node,"CharacterSpriteAura")
 var anchor := _get_or_create_anchor(player_node,"CharacterSpriteAura")
 var attached := false
 if min_set_plus >= 3:
  var tier := clampi(int(ceil(float(min_set_plus-2)/2.5)),1,4)
  var tint := Color(1.0,0.72,0.18).lerp(Color(0.65,0.24,1.0),float(tier-1)/3.0)
  var ring := _make_sprite("ring",2,tint,0.95+float(tier)*0.18,10.0+float(tier))
  if ring != null:
   ring.position.y = 0.035
   ring.rotation_degrees.x = -90.0
   anchor.add_child(ring)
   attached = true
 if is_xp_active:
  var xp_flame := _make_sprite("flame",4,Color(0.25,0.72,1.0),0.9,22.0)
  if xp_flame != null:
   xp_flame.position.y = 1.0
   anchor.add_child(xp_flame)
   attached = true
 return attached or (min_set_plus < 3 and not is_xp_active)

func _anima_style(phase: int) -> Dictionary:
 if phase <= 3: return {"colors":ANIMA_COLORS.green_blue,"count":1+int(floor(float(phase-1)/3.0)),"speed":0.8+phase*0.12}
 if phase <= 6: return {"colors":ANIMA_COLORS.gold,"count":2+int(floor(float(phase-4)/3.0)),"speed":1.2+phase*0.10}
 if phase <= 9: return {"colors":ANIMA_COLORS.fire,"count":3+int(floor(float(phase-7)/3.0)),"speed":1.7+phase*0.08}
 if phase <= 12: return {"colors":ANIMA_COLORS.purple,"count":4,"speed":2.0+phase*0.07}
 return {"colors":ANIMA_COLORS.dual,"count":5+int(floor(float(phase-13)/3.0)),"speed":2.4+phase*0.06}

func attach_anima_aura(player_node: Node3D, anima_phase: int) -> bool:
 if player_node == null or not is_instance_valid(player_node): return false
 _clear_anchor(player_node,"AnimaOrbitController")
 _active_orbits.erase(player_node.get_instance_id())
 var phase := clampi(anima_phase,0,18)
 if phase == 0: return true
 var style: Dictionary = _anima_style(phase)
 var controller := Node3D.new()
 controller.name = "AnimaOrbitController"
 player_node.add_child(controller)
 _track_effect_root(controller)
 var count := clampi(int(style.count),1,6)
 var colors: Array = style.colors
 for i in range(count):
  var tint: Color = colors[i%colors.size()]
  var orb := _make_sprite("flame",0,tint,0.24+float(phase)*0.009,float(style.speed)*18.0)
  if orb == null: continue
  orb.name = "AnimaOrb_%02d" % i
  controller.add_child(orb)
  orb.set_meta("orbit_index",i)
  orb.set_meta("orbit_count",count)
  orb.set_meta("orbit_phase",float(i)*TAU/float(count))
  orb.set_meta("orbit_radius",0.72+float(i%3)*0.10)
  orb.set_meta("orbit_height",1.05+float(i%3)*0.34)
  orb.set_meta("orbit_speed",float(style.speed)*(1.0 if i%2==0 else -0.82))
  orb.set_meta("orbit_wobble",0.13+float(phase)*0.006)
 _active_orbits[player_node.get_instance_id()] = {"node":controller,"clock":0.0}
 controller.set_meta("anima_phase",phase)
 print("PHASE4D_ANIMA_ORBIT_ATTACHED: phase=P",phase," orbs=",count," speed=",style.speed)
 return controller.get_child_count()>0

func attach_loot_aura(loot_node: Node3D, item_rarity: String, item_type: String) -> bool:
 if loot_node == null or not is_instance_valid(loot_node): return false
 _clear_anchor(loot_node,"LootSpriteAura")
 var anchor := _get_or_create_anchor(loot_node,"LootSpriteAura")
 var rarity := item_rarity.to_lower()
 var effect := "ring"
 var variant := 2
 var tint := Color(0.4,0.9,1.0)
 if rarity in ["refined","unique"]: tint = Color(0.25,0.82,1.0)
 elif rarity == "elite": tint = Color(1.0,0.68,0.18)
 elif rarity in ["super","gem","gems"]: tint = Color(0.35,0.82,1.0); variant = 4
 elif item_type.to_lower() == "meteor": effect = "shockwave"; tint = Color(1.0,0.3,0.08)
 elif item_type.to_lower() in ["dragon ball","dragonball"]: effect = "explosion"; tint = Color(1.0,0.18,0.12); variant = 4
 var sprite := _make_sprite(effect,variant,tint,0.52,12.0)
 if sprite == null: return false
 sprite.rotation_degrees.x = -90.0
 sprite.position.y = 0.035
 anchor.add_child(sprite)
 return true

func attach_skill_buff_aura(target_node: Node3D, buff_id: String, duration: float) -> bool:
 if target_node == null or not is_instance_valid(target_node): return false
 var key := "SkillBuffAura_"+buff_id
 _clear_anchor(target_node,key)
 var anchor := _get_or_create_anchor(target_node,key)
 var color := Color(0.28,0.72,1.0) if buff_id in ["fly","arrow_rain","chain_lightning"] else Color(1.0,0.62,0.18)
 var sprite := _make_sprite("flame",4,color,0.7,20.0)
 if sprite == null: return false
 sprite.position.y = 0.95
 anchor.add_child(sprite)
 var timer := get_tree().create_timer(maxf(0.1,duration))
 timer.timeout.connect(func(): if is_instance_valid(anchor): anchor.queue_free())
 return true

func play_skill_vfx(vfx_type: String, color_style: String, world_pos: Vector3, direction: Vector3) -> Node3D:
 var effect := vfx_type.to_lower()
 if not EFFECT_FILES.has(effect): effect = "explosion"
 var variant := 2
 var tint := Color.WHITE
 match color_style.to_lower():
  "blue", "green_blue": variant=0; tint=Color(0.25,0.75,1.0)
  "gold": variant=2; tint=Color(1.0,0.72,0.16)
  "purple": variant=4; tint=Color(0.72,0.28,1.0)
  "fire", "orange": variant=2; tint=Color(1.0,0.32,0.08)
  "smoke": variant=3; tint=Color(0.72,0.72,0.78)
 var sprite := _make_sprite(effect,variant,tint,1.0,22.0)
 if sprite == null: return null
 var effect_parent: Node = get_tree().current_scene
 if effect_parent == null:
  effect_parent = get_tree().root
 effect_parent.add_child(sprite)
 _track_effect_root(sprite)
 sprite.global_position = world_pos
 if direction.length_squared()>0.001: sprite.look_at(world_pos+direction,Vector3.UP)
 sprite.scale = Vector3.ONE*1.0
 var timer := get_tree().create_timer(1.2)
 timer.timeout.connect(func(): if is_instance_valid(sprite): sprite.queue_free())
 return sprite

func get_loaded_effect_names() -> Array[String]:
 var names: Array[String] = []
 for effect in EFFECT_FILES:
  for file_name in EFFECT_FILES[effect]: names.append(file_name)
 return names
