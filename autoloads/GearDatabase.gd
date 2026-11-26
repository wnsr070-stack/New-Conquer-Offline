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
const EQUIPMENT_CLASSES := ["archer","oriental_assassin","trojan","warrior","taoist","ninja","monk"]
const ARMOR_ASSETS := [
 {"id":"body_01_beginner","name":"Black Full Plate — Beginner","type":"Armor","slot":"armor","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/body_01_beginner.glb","base_defense":80},
 {"id":"body_01_steel","name":"Black Full Plate — Steel","type":"Armor","slot":"armor","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/body_01_steel.glb","base_defense":80},
 {"id":"body_01_royal","name":"Black Full Plate — Royal Legendary","type":"Armor","slot":"armor","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/body_01_royal.glb","base_defense":80},
 {"id":"body_02_beginner","name":"Golden Full Plate — Beginner","type":"Armor","slot":"armor","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/body_02_beginner.glb","base_defense":80},
 {"id":"body_02_steel","name":"Golden Full Plate — Steel","type":"Armor","slot":"armor","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/body_02_steel.glb","base_defense":80},
 {"id":"body_02_royal","name":"Golden Full Plate — Royal Legendary","type":"Armor","slot":"armor","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/body_02_royal.glb","base_defense":80},
 {"id":"body_03_beginner","name":"Leather Armor — Beginner","type":"Armor","slot":"armor","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/body_03_beginner.glb","base_defense":80},
 {"id":"body_03_steel","name":"Leather Armor — Steel","type":"Armor","slot":"armor","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/body_03_steel.glb","base_defense":80},
 {"id":"body_03_royal","name":"Leather Armor — Royal Legendary","type":"Armor","slot":"armor","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/body_03_royal.glb","base_defense":80},
 {"id":"body_04_beginner","name":"Metal Armor — Beginner","type":"Armor","slot":"armor","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/body_04_beginner.glb","base_defense":80},
 {"id":"body_04_steel","name":"Metal Armor — Steel","type":"Armor","slot":"armor","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/body_04_steel.glb","base_defense":80},
 {"id":"body_04_royal","name":"Metal Armor — Royal Legendary","type":"Armor","slot":"armor","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/body_04_royal.glb","base_defense":80},
 {"id":"body_05_beginner","name":"Reinforced Metal Armor — Beginner","type":"Armor","slot":"armor","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/body_05_beginner.glb","base_defense":80},
 {"id":"body_05_steel","name":"Reinforced Metal Armor — Steel","type":"Armor","slot":"armor","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/body_05_steel.glb","base_defense":80},
 {"id":"body_05_royal","name":"Reinforced Metal Armor — Royal Legendary","type":"Armor","slot":"armor","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/body_05_royal.glb","base_defense":80},
 {"id":"helmet_01_beginner","name":"Knight Helmet I — Beginner","type":"Headgear","slot":"helmet","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/helmet_01_beginner.glb","base_defense":35},
 {"id":"helmet_01_steel","name":"Knight Helmet I — Steel","type":"Headgear","slot":"helmet","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/helmet_01_steel.glb","base_defense":35},
 {"id":"helmet_01_royal","name":"Knight Helmet I — Royal Legendary","type":"Headgear","slot":"helmet","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/helmet_01_royal.glb","base_defense":35},
 {"id":"helmet_02_beginner","name":"Knight Helmet II — Beginner","type":"Headgear","slot":"helmet","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/helmet_02_beginner.glb","base_defense":35},
 {"id":"helmet_02_steel","name":"Knight Helmet II — Steel","type":"Headgear","slot":"helmet","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/helmet_02_steel.glb","base_defense":35},
 {"id":"helmet_02_royal","name":"Knight Helmet II — Royal Legendary","type":"Headgear","slot":"helmet","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/helmet_02_royal.glb","base_defense":35},
 {"id":"helmet_03_beginner","name":"Knight Helmet III — Beginner","type":"Headgear","slot":"helmet","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/helmet_03_beginner.glb","base_defense":35},
 {"id":"helmet_03_steel","name":"Knight Helmet III — Steel","type":"Headgear","slot":"helmet","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/helmet_03_steel.glb","base_defense":35},
 {"id":"helmet_03_royal","name":"Knight Helmet III — Royal Legendary","type":"Headgear","slot":"helmet","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/helmet_03_royal.glb","base_defense":35},
 {"id":"helmet_04_beginner","name":"Knight Helmet I Variant — Beginner","type":"Headgear","slot":"helmet","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/helmet_04_beginner.glb","base_defense":35},
 {"id":"helmet_04_steel","name":"Knight Helmet I Variant — Steel","type":"Headgear","slot":"helmet","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/helmet_04_steel.glb","base_defense":35},
 {"id":"helmet_04_royal","name":"Knight Helmet I Variant — Royal Legendary","type":"Headgear","slot":"helmet","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/helmet_04_royal.glb","base_defense":35},
 {"id":"helmet_05_beginner","name":"Knight Helmet II Variant — Beginner","type":"Headgear","slot":"helmet","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/helmet_05_beginner.glb","base_defense":35},
 {"id":"helmet_05_steel","name":"Knight Helmet II Variant — Steel","type":"Headgear","slot":"helmet","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/helmet_05_steel.glb","base_defense":35},
 {"id":"helmet_05_royal","name":"Knight Helmet II Variant — Royal Legendary","type":"Headgear","slot":"helmet","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/helmet_05_royal.glb","base_defense":35},
 {"id":"boots_01_beginner","name":"Stylized Boots — Beginner","type":"Armor","slot":"boots","tier":"beginner","level_min":1,"level_max":29,"model_path":"res://assets/phase3b/armor/boots_01_beginner.glb","base_defense":20},
 {"id":"boots_01_steel","name":"Stylized Boots — Steel","type":"Armor","slot":"boots","tier":"steel","level_min":30,"level_max":59,"model_path":"res://assets/phase3b/armor/boots_01_steel.glb","base_defense":20},
 {"id":"boots_01_royal","name":"Stylized Boots — Royal Legendary","type":"Armor","slot":"boots","tier":"royal","level_min":60,"level_max":110,"model_path":"res://assets/phase3b/armor/boots_01_royal.glb","base_defense":20}
]
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
     items[item_id] = {"id":item_id,"family":family,"level":level,"quality":quality,"plus":plus,"classes":WEAPON_FAMILIES[family].classes,"model_keys":WEAPON_FAMILIES[family].models,"tier_color":_tier_color(level),"display_name":"%s Lv.%d %s +%d" % [family.replace("_"," ").capitalize(),level,quality,plus],"base_attack":_family_attack(family),"base_defense":_family_defense(family),"composition_points":0,"sockets":[],"gem_bonuses":{"attack":0,"magic_attack":0,"damage_reduction":0.0,"exp_bonus":0.0}}
 _initialize_armor_items()
 _initialize_quest_items()
 initialized = true
 print("PHASE3B_GEAR_DATABASE_READY: ",items.size()," weapon+armor variants; armor_assets=33 classes=7")
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

func _family_attack(family: String) -> int:
 if family in ["bow","dual_daggers","dual_blades","dual_axes","spear","halberd","infernal_greatsword"]: return 80
 if family in ["magic_staff","staff"]: return 45
 return 10
func _family_defense(family: String) -> int:
 return 15 if family == "shield" else 0

func _initialize_armor_items() -> void:
 for asset in ARMOR_ASSETS:
  for quality in QUALITIES:
   for plus in range(1,PLUS_LEVELS+1):
    var item_id := "%s_%s_p%d" % [asset.id,quality.to_lower(),plus]
    items[item_id] = {"id":item_id,"asset_id":asset.id,"family":String(asset.type).to_lower(),"equipment_type":asset.type,"slot":asset.slot,"tier":asset.tier,"level":asset.level_min,"level_min":asset.level_min,"level_max":asset.level_max,"quality":quality,"plus":plus,"classes":EQUIPMENT_CLASSES.duplicate(),"model_path":asset.model_path,"asset_path":asset.model_path,"base_attack":0,"base_defense":asset.base_defense,"attack_bonus":0,"defense_bonus":asset.base_defense,"composition_points":0,"sockets":[],"gem_bonuses":{"attack":0,"magic_attack":0,"damage_reduction":0.0,"exp_bonus":0.0}}
 print("PHASE3B_ARMOR_CATALOG_READY: assets=",ARMOR_ASSETS.size()," variants=",ARMOR_ASSETS.size()*QUALITIES.size()*PLUS_LEVELS," body=15 headgear=15 boots=3 classes=",EQUIPMENT_CLASSES)

func get_armor_item(asset_id: String, quality: String = "Normal", plus: int = 1) -> Dictionary:
 var safe_plus := clampi(plus,1,PLUS_LEVELS)
 return get_item("%s_%s_p%d" % [asset_id,quality.to_lower(),safe_plus])

func get_armor_assets() -> Array:
 return ARMOR_ASSETS.duplicate(true)

func clear_cache() -> void:
 items.clear()
 initialized = false
 print("PHASE4D_GEAR_DATABASE_CACHE_CLEARED")

func _initialize_quest_items() -> void:
 var rows := [["EuxeniteOre","Euxenite Ore"],["RebuildOre","Rebuild Ore"],["PeaceCommandToken","Peace Command Token"],["ChaosCommandToken","Chaos Command Token"],["DesertedCommandToken","Deserted Command Token"],["ProsperousCommandToken","Prosperous Command Token"],["DisturbedCommandToken","Disturbed Command Token"],["CalmedCommandToken","Calmed Command Token"],["SoulJade","Soul Jade"],["MoonBox","Moon Box"],["CleanWater","Clean Water"],["CelestialStone","Celestial Stone"],["HeavenFan","Heaven Fan"],["StarTower","Star Tower"],["ThunderGem","Thunder Gem"],["GloryGem","Glory Gem"]]
 for row in rows:
  items[String(row[0])] = {"id":String(row[0]),"display_name":String(row[1]),"type":"QuestItem","family":"quest_item","level":1,"quality":"Normal","plus":0,"stackable":true,"classes":EQUIPMENT_CLASSES.duplicate(),"sockets":[],"gem_bonuses":{}}
 print("PHASE4D_CLASSIC_QUEST_ITEMS_READY: count=",rows.size())
