extends Control
## 2D vector item artwork. Draws only CanvasItem primitives; never creates 3D geometry.
var item_data: Dictionary = {}
var enhancement_level: int = 0
var _aura_color: Color = Color(0.0, 0.0, 0.0, 0.0)
var _aura_intensity: float = 0.0
var _kenney_texture: Texture2D

func _ready() -> void:
 _refresh_aura()
 _kenney_texture = _find_kenney_texture(_item_kind(item_data))
 queue_redraw()

func _refresh_aura() -> void:
 if not is_inside_tree(): return
 var scene_root: Window = get_tree().root
 if scene_root == null: return
 var aura: Node = scene_root.get_node_or_null("AuraAndVFXManager")
 if aura != null and aura.has_method("get_slot_enhancement_aura"):
  var presentation: Dictionary = aura.get_slot_enhancement_aura(enhancement_level)
  _aura_color = presentation.get("color",Color.TRANSPARENT)
  _aura_intensity = float(presentation.get("intensity",0.0))

func _find_kenney_texture(kind: String) -> Texture2D:
 var directory: DirAccess = DirAccess.open("res://assets/icons/rpg")
 if directory == null: return null
 var files: PackedStringArray = directory.get_files()
 files.sort()
 var prefixes: Array[String] = [kind]
 if kind == "blade": prefixes = ["sword"]
 elif kind == "armor": prefixes = ["shield"]
 for prefix_kind: String in prefixes:
  var prefix: String = prefix_kind + "__"
  for file_name in files:
   if file_name.to_lower().begins_with(prefix) and file_name.to_lower().ends_with(".png"):
    var texture: Texture2D = load("res://assets/icons/rpg/" + file_name) as Texture2D
    if texture != null: return texture
 return null

func configure(data: Dictionary,plus_level: int = -1) -> void:
 item_data = data.duplicate(true)
 enhancement_level = int(data.get("plus",0)) if plus_level < 0 else clampi(plus_level,0,12)
 _refresh_aura()
 _kenney_texture = _find_kenney_texture(_item_kind(item_data))
 queue_redraw()
func _draw() -> void:
 var bounds: Rect2 = Rect2(Vector2.ZERO,size)
 var center: Vector2 = size*0.5
 var side: float = minf(size.x,size.y)
 var rank: Color = _rank_color(enhancement_level)
 draw_rect(bounds,Color(0.055,0.075,0.12,0.98),true)
 draw_rect(bounds,rank,false,2.0)
 if enhancement_level > 0:
  var glow: Color = _aura_color if _aura_color.a > 0.0 else rank
  draw_rect(bounds.grow(-3.0),Color(glow.r,glow.g,glow.b,clampf(0.30+_aura_intensity*0.18,0.35,0.9)),false,2.0+_aura_intensity)
 if _kenney_texture == null:
  _draw_fallback_icon(center,side)
 else:
  var icon_side: float = side*0.78
  draw_texture_rect(_kenney_texture,Rect2(center-Vector2.ONE*icon_side*0.5,Vector2.ONE*icon_side),false)
 if enhancement_level > 0:
  draw_string(ThemeDB.fallback_font,Vector2(3.0,size.y-4.0),"+"+str(enhancement_level),HORIZONTAL_ALIGNMENT_LEFT,-1,10,rank)

func _rank_color(plus: int) -> Color:
 if plus >= 12: return Color(0.70,0.36,1.0)
 if plus >= 10: return Color(1.0,0.78,0.20)
 if plus >= 8: return Color(0.95,0.20,0.24)
 if plus >= 5: return Color(0.16,0.38,1.0)
 if plus >= 3: return Color(0.12,0.88,0.95)
 if plus >= 1: return Color(0.20,0.86,0.35)
 return Color.WHITE

func _draw_fallback_icon(center: Vector2,side: float) -> void:
 var kind: String = _item_kind(item_data)
 var metal: Color = Color(0.78,0.86,0.96)
 var gold: Color = Color(1.0,0.72,0.18)
 var accent: Color = Color(0.22,0.78,1.0)
 match kind:
  "bow":
   draw_arc(center+Vector2(-side*0.08,0),side*0.34,-1.35,1.35,24,gold,4.0,true)
   draw_line(center+Vector2(-side*0.08,-side*0.33),center+Vector2(side*0.27,0),metal,2.0)
   draw_line(center+Vector2(side*0.27,0),center+Vector2(-side*0.08,side*0.33),metal,2.0)
  "blade":
   draw_colored_polygon(PackedVector2Array([center+Vector2(-side*.12,side*.30),center+Vector2(side*.25,-side*.34),center+Vector2(side*.12,-side*.39),center+Vector2(-side*.20,side*.18)]),metal)
   draw_line(center+Vector2(-side*.18,side*.20),center+Vector2(-side*.30,side*.34),gold,4.0)
  "armor":
   draw_colored_polygon(PackedVector2Array([center+Vector2(-side*.29,-side*.28),center+Vector2(0,-side*.38),center+Vector2(side*.29,-side*.28),center+Vector2(side*.23,side*.22),center+Vector2(0,side*.36),center+Vector2(-side*.23,side*.22)]),Color(0.34,0.48,0.66))
  "helmet":
   draw_arc(center+Vector2(0,side*.03),side*.29,PI,TAU,24,metal,6.0,true)
  "ring":
   draw_arc(center,side*.23,0,TAU,32,gold,5.0,true)
  "necklace":
   draw_arc(center+Vector2(0,-side*.04),side*.27,0,PI,28,gold,3.0,true)
  "boots":
   draw_colored_polygon(PackedVector2Array([center+Vector2(-side*.22,-side*.28),center+Vector2(side*.03,-side*.28),center+Vector2(side*.03,side*.12),center+Vector2(side*.27,side*.22),center+Vector2(side*.27,side*.33),center+Vector2(-side*.25,side*.33)]),metal)
  "potion":
   draw_rect(Rect2(center+Vector2(-side*.13,-side*.16),Vector2(side*.26,side*.43)),Color(0.12,0.82,0.42),true)
  _:
   draw_circle(center,side*.25,accent)
func _item_kind(data: Dictionary) -> String:
 var text: String = " ".join([String(data.get("type","")), String(data.get("slot","")), String(data.get("family","")), String(data.get("id","")), String(data.get("name",""))]).to_lower()
 if text.contains("bow"): return "bow"
 if text.contains("sword") or text.contains("dagger") or text.contains("blade") or text.contains("knife"): return "blade"
 if text.contains("armor") or text.contains("shield") or text.contains("body"): return "armor"
 if text.contains("helmet") or text.contains("headgear") or text.contains("hood"): return "helmet"
 if text.contains("ring"): return "ring"
 if text.contains("necklace") or text.contains("amulet"): return "necklace"
 if text.contains("boot") or text.contains("shoe"): return "boots"
 if text.contains("potion") or text.contains("vial") or text.contains("flask"): return "potion"
 if text.contains("meteor") or text.contains("dragonball") or text.contains("dragon_ball") or text.contains("anima"): return "orb"
 if text.contains("gem") or text.contains("jewel") or text.contains("stone"): return "gem"
 if text.contains("quest") or text.contains("scroll"): return "scroll"
 return "orb"
