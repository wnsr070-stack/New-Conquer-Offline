extends Control
## 2D vector item artwork. Draws only CanvasItem primitives; never creates 3D geometry.
var item_data: Dictionary = {}
var enhancement_level := 0
var _aura_color := Color(0.0, 0.0, 0.0, 0.0)
var _aura_intensity := 0.0

func configure(data: Dictionary, plus_level: int = -1) -> void:
 item_data = data.duplicate(true)
 enhancement_level = int(data.get("plus", 0)) if plus_level < 0 else clampi(plus_level, 0, 12)
 var aura := get_node_or_null("/root/AuraAndVFXManager")
 if aura != null and aura.has_method("get_slot_enhancement_aura"):
  var presentation: Dictionary = aura.get_slot_enhancement_aura(enhancement_level)
  _aura_color = presentation.get("color", Color.TRANSPARENT)
  _aura_intensity = float(presentation.get("intensity", 0.0))
 queue_redraw()

func _draw() -> void:
 var bounds := Rect2(Vector2.ZERO, size)
 var center := size * 0.5
 var side := minf(size.x, size.y)
 draw_rect(bounds, Color(0.055, 0.075, 0.12, 0.98), true)
 draw_rect(bounds, Color(0.48, 0.58, 0.72, 0.95), false, 2.0)
 if enhancement_level > 0:
  var glow := _aura_color if _aura_color.a > 0.0 else Color(1.0, 0.72, 0.18)
  draw_rect(bounds.grow(-3.0), Color(glow.r, glow.g, glow.b, clampf(0.30 + _aura_intensity * 0.18, 0.35, 0.9)), false, 2.0 + _aura_intensity)
 var kind := _item_kind(item_data)
 var metal := Color(0.78, 0.86, 0.96)
 var gold := Color(1.0, 0.72, 0.18)
 var accent := Color(0.22, 0.78, 1.0)
 match kind:
  "bow":
   draw_arc(center + Vector2(-side * 0.08, 0), side * 0.34, -1.35, 1.35, 24, gold, 4.0, true)
   draw_line(center + Vector2(-side * 0.08, -side * 0.33), center + Vector2(side * 0.27, 0), metal, 2.0)
   draw_line(center + Vector2(side * 0.27, 0), center + Vector2(-side * 0.08, side * 0.33), metal, 2.0)
  "blade":
   draw_colored_polygon(PackedVector2Array([center + Vector2(-side*.12,side*.30),center + Vector2(side*.25,-side*.34),center + Vector2(side*.12,-side*.39),center + Vector2(-side*.20,side*.18)]), metal)
   draw_line(center + Vector2(-side*.18,side*.20), center + Vector2(-side*.30,side*.34), gold, 4.0)
  "armor":
   draw_colored_polygon(PackedVector2Array([center+Vector2(-side*.29,-side*.28),center+Vector2(0,-side*.38),center+Vector2(side*.29,-side*.28),center+Vector2(side*.23,side*.22),center+Vector2(0,side*.36),center+Vector2(-side*.23,side*.22)]), Color(0.34,0.48,0.66))
   draw_line(center+Vector2(-side*.18,0),center+Vector2(side*.18,0),gold,3.0)
  "helmet":
   draw_arc(center+Vector2(0,side*.03),side*.29,PI,TAU,24,metal,6.0,true)
   draw_line(center+Vector2(-side*.29,side*.03),center+Vector2(side*.29,side*.03),gold,4.0)
   draw_circle(center+Vector2(0,-side*.10),side*.07,accent)
  "ring":
   draw_arc(center,side*.23,0,TAU,32,gold,5.0,true)
   draw_circle(center+Vector2(0,-side*.22),side*.10,accent)
  "necklace":
   draw_arc(center+Vector2(0,-side*.04),side*.27,0,PI,28,gold,3.0,true)
   draw_colored_polygon(PackedVector2Array([center+Vector2(0,side*.12),center+Vector2(side*.12,side*.28),center+Vector2(0,side*.42),center+Vector2(-side*.12,side*.28)]),accent)
  "boots":
   draw_colored_polygon(PackedVector2Array([center+Vector2(-side*.22,-side*.28),center+Vector2(side*.03,-side*.28),center+Vector2(side*.03,side*.12),center+Vector2(side*.27,side*.22),center+Vector2(side*.27,side*.33),center+Vector2(-side*.25,side*.33)]),metal)
  "potion":
   draw_rect(Rect2(center+Vector2(-side*.13,-side*.16),Vector2(side*.26,side*.43)),Color(0.12,0.82,0.42),true)
   draw_rect(Rect2(center+Vector2(-side*.09,-side*.30),Vector2(side*.18,side*.14)),gold,true)
   draw_line(center+Vector2(-side*.09,0),center+Vector2(side*.09,0),Color.WHITE,2.0)
  "orb":
   draw_circle(center,side*.27,accent)
   draw_arc(center,side*.27,0,TAU,32,Color(0.85,0.96,1.0),3.0,true)
   draw_circle(center+Vector2(-side*.08,-side*.09),side*.07,Color(1,1,1,0.85))
  "gem":
   draw_colored_polygon(PackedVector2Array([center+Vector2(0,-side*.36),center+Vector2(side*.27,-side*.08),center+Vector2(side*.18,side*.30),center+Vector2(-side*.18,side*.30),center+Vector2(-side*.27,-side*.08)]),Color(0.28,0.92,0.75))
   draw_line(center+Vector2(0,-side*.32),center+Vector2(0,side*.26),Color(0.86,1,1),2.0)
  "scroll":
   draw_rect(Rect2(center+Vector2(-side*.22,-side*.31),Vector2(side*.44,side*.62)),Color(0.88,0.77,0.53),true)
   for line_index in range(3):
    draw_line(center+Vector2(-side*.13,-side*.12+line_index*side*.12),center+Vector2(side*.13,-side*.12+line_index*side*.12),Color(0.34,0.24,0.14),2.0)
  _:
   draw_circle(center,side*.25,gold)
   draw_circle(center,side*.14,accent)
 if enhancement_level > 0:
  var label := "+" + str(enhancement_level)
  draw_string(ThemeDB.fallback_font, Vector2(4.0, size.y - 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func _item_kind(data: Dictionary) -> String:
 var text := " ".join([String(data.get("type","")), String(data.get("slot","")), String(data.get("family","")), String(data.get("id","")), String(data.get("name",""))]).to_lower()
 if text.contains("bow"): return "bow"
 if text.contains("sword") or text.contains("dagger") or text.contains("blade") or text.contains("knife"): return "blade"
 if text.contains("armor") or text.contains("shield"): return "armor"
 if text.contains("helmet") or text.contains("headgear") or text.contains("hood"): return "helmet"
 if text.contains("ring"): return "ring"
 if text.contains("necklace") or text.contains("amulet"): return "necklace"
 if text.contains("boot") or text.contains("shoe"): return "boots"
 if text.contains("potion"): return "potion"
 if text.contains("meteor") or text.contains("dragonball") or text.contains("dragon_ball") or text.contains("anima"): return "orb"
 if text.contains("gem") or text.contains("jewel") or text.contains("stone"): return "gem"
 if text.contains("quest") or text.contains("scroll"): return "scroll"
 return "orb"
