extends Node
const TIER_LEVELS := [10,20,30,40,50,60,70,80,90,100,110,120,130]
const QUALITIES := ["Normal","Refined","Unique","Elite","Super"]
const PLUS_LEVELS := 12
const WEAPON_FAMILIES := {
 "bow":{"classes":["archer"],"models":["quaternius_bow_wooden","quaternius_bow_golden"]},
 "dual_daggers":{"classes":["oriental_assassin"],"models":["kutejnikov_dagger","old_fantasy_dagger"]},
 "dual_blades":{"classes":["trojan"],"models":["cethiel_sword","kutejnikov_sword"]},
 "dual_axes":{"classes":["trojan"],"models":["cethiel_axe","kutejnikov_scythe"]},
 "spear":{"classes":["warrior"],"models":["quaternius_spear"]},
 "halberd":{"classes":["warrior"],"models":["quaternius_halberd"]},
 "infernal_greatsword":{"classes":["warrior"],"models":["infernal_sword"]},
 "shield":{"classes":["warrior"],"models":["cethiel_shield"]},
 "magic_staff":{"classes":["taoist"],"models":["quaternius_staff"]},
 "katana":{"classes":["ninja"],"models":["cethiel_sword"]},
 "shuriken":{"classes":["ninja"],"models":["shuriken"]},
 "staff":{"classes":["monk"],"models":["quaternius_staff"]}
}
var initialized := false
var items: Dictionary = {}
func _ready() -> void:
 _initialize()
func _initialize() -> void:
 items.clear()
 for family in WEAPON_FAMILIES:
  for level in TIER_LEVELS:
   for quality in QUALITIES:
    for plus in range(1,PLUS_LEVELS+1):
     var item_id := "%s_lv%d_%s_p%d" % [family,level,quality.to_lower(),plus]
     items[item_id] = {"id":item_id,"family":family,"level":level,"quality":quality,"plus":plus,"classes":WEAPON_FAMILIES[family].classes,"model_keys":WEAPON_FAMILIES[family].models,"tier_color":_tier_color(level),"display_name":"%s Lv.%d %s +%d" % [family.replace("_"," ").capitalize(),level,quality,plus]}
 initialized = true
 print("PHASE3B_GEAR_DATABASE_READY: ",items.size()," weapon variants; 13 tiers x 5 qualities x 12 plus levels")
func _tier_color(level: int) -> Color:
 if level <= 30: return Color(0.62,0.34,0.16)
 if level <= 60: return Color(0.25,0.52,0.82)
 if level <= 90: return Color(0.78,0.82,0.91)
 return Color(1.0,0.72,0.22)
func get_item(item_id: String) -> Dictionary:
 return items.get(item_id,{}).duplicate(true)
func get_tier_item(family: String, level: int, quality: String = "Normal", plus: int = 1) -> Dictionary:
 var safe_level := clampi(int(round(float(level)/10.0))*10,10,130)
 var safe_plus := clampi(plus,1,12)
 return get_item("%s_lv%d_%s_p%d" % [family,safe_level,quality.to_lower(),safe_plus])
func get_family(family: String) -> Dictionary:
 return WEAPON_FAMILIES.get(family,{}).duplicate(true)
