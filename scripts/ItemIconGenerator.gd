extends Control
## Displays real, full-colour RPG artwork loaded by the CI asset step. No primitive placeholder icons.
var item_data: Dictionary = {}
var enhancement_level: int = 0
var _aura_color: Color = Color.TRANSPARENT
var _aura_intensity: float = 0.0
var _rpg_texture: Texture2D

func _ready() -> void:
 _refresh_aura()
 _rpg_texture = _find_rpg_texture(_item_kind(item_data))
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

func _find_rpg_texture(kind: String) -> Texture2D:
 var directory: DirAccess = DirAccess.open("res://assets/icons/rpg")
 if directory == null: return null
 var files: PackedStringArray = directory.get_files()
 files.sort()
 var prefixes: Array[String] = []
 match kind:
  "blade": prefixes = ["dagger__","sword__"]
  "armor": prefixes = ["armor__"]
  "orb", "gem": prefixes = ["gem__"]
  "scroll": prefixes = ["skill__","potion__"]
  _: prefixes = [kind+"__"]
 for prefix in prefixes:
  for file_name in files:
   if file_name.to_lower().begins_with(prefix) and file_name.to_lower().ends_with(".png"):
    var texture := load("res://assets/icons/rpg/"+file_name) as Texture2D
    if texture != null: return texture
 return null

func configure(data: Dictionary,plus_level: int = -1) -> void:
 item_data = data.duplicate(true)
 enhancement_level = int(data.get("plus",0)) if plus_level < 0 else clampi(plus_level,0,12)
 _refresh_aura()
 _rpg_texture = _find_rpg_texture(_item_kind(item_data))
 queue_redraw()

func _draw() -> void:
 var bounds := Rect2(Vector2.ZERO,size)
 var center := size*0.5
 var side := minf(size.x,size.y)
 var rank := _rank_color(enhancement_level)
 draw_rect(bounds,Color(0.055,0.075,0.12,0.98),true)
 draw_rect(bounds,rank,false,2.0)
 if enhancement_level > 0:
  var glow := _aura_color if _aura_color.a > 0.0 else rank
  draw_rect(bounds.grow(-3.0),Color(glow.r,glow.g,glow.b,clampf(0.30+_aura_intensity*0.18,0.35,0.9)),false,2.0+_aura_intensity)
 if _rpg_texture != null:
  var icon_side := side*0.86
  draw_texture_rect(_rpg_texture,Rect2(center-Vector2.ONE*icon_side*0.5,Vector2.ONE*icon_side),false)
 else:
  push_warning("PHASE5A_RPG_ICON_MISSING: "+_item_kind(item_data))
 if enhancement_level > 0:
  draw_string(ThemeDB.fallback_font,Vector2(3.0,size.y-4.0),"★"+str(enhancement_level),HORIZONTAL_ALIGNMENT_LEFT,-1,10,rank)

func _rank_color(plus: int) -> Color:
 if plus >= 12: return Color(1.0,0.78,0.20)
 if plus >= 10: return Color(1.0,0.78,0.20)
 if plus >= 8: return Color(0.95,0.20,0.24)
 if plus >= 5: return Color(0.16,0.38,1.0)
 if plus >= 3: return Color(0.12,0.88,0.95)
 if plus >= 1: return Color(0.20,0.86,0.35)
 return Color.WHITE

func _item_kind(data: Dictionary) -> String:
 var text: String = " ".join([String(data.get("type","")),String(data.get("slot","")),String(data.get("equipment_slot","")),String(data.get("family","")),String(data.get("id","")),String(data.get("name",""))]).to_lower()
 var slot := String(data.get("slot",data.get("equipment_slot",""))).to_lower()
 match slot:
  "helmet", "headgear": return "helmet"
  "necklace": return "necklace"
  "armor": return "armor"
  "ring": return "ring"
  "boots": return "boots"
  "fan": return "fan"
  "tower": return "tower"
  "wing": return "wing"
  "mount_whip": return "mount_whip"
  "steed": return "steed"
  "mount_skin": return "mount_skin"
  "garment": return "garment"
  "weapon_accessory": return "weapon_accessory"
 if text.contains("bow"): return "bow"
 if text.contains("steed") or text.contains("horse") or text.contains("mount"): return "steed"
 if text.contains("fan"): return "fan"
 if text.contains("tower"): return "tower"
 if text.contains("wing"): return "wing"
 if text.contains("whip"): return "mount_whip"
 if text.contains("garment") or text.contains("robe") or text.contains("clothing"): return "garment"
 if text.contains("accessory") and text.contains("weapon"): return "weapon_accessory"
 if text.contains("dagger") or text.contains("knife"): return "dagger"
 if text.contains("sword") or text.contains("blade"): return "sword"
 if text.contains("armor") or text.contains("shield") or text.contains("body"): return "armor"
 if text.contains("helmet") or text.contains("headgear") or text.contains("hood"): return "helmet"
 if text.contains("ring"): return "ring"
 if text.contains("necklace") or text.contains("amulet"): return "necklace"
 if text.contains("boot") or text.contains("shoe"): return "boots"
 if text.contains("potion") or text.contains("vial") or text.contains("flask"): return "potion"
 if text.contains("meteor") or text.contains("dragonball") or text.contains("dragon_ball") or text.contains("anima"): return "gem"
 if text.contains("gem") or text.contains("jewel") or text.contains("stone"): return "gem"
 if text.contains("quest") or text.contains("scroll"): return "skill"
 return "gem"
