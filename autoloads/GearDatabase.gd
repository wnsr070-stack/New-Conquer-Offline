extends Node
const TIER_LEVELS := [10,20,30,40,50,60,70,80,90,100,110,120,130]
const QUALITIES := ["Normal","Refined","Unique","Elite","Super"]
const PLUS_LEVELS := 12
const SHOP_PRICES := {
 "HPPotion":80,"MPPotion":80,"Antidote":120,"StaminaPotion":150,
 "bow_lv10_normal_p1":1500,"dual_blades_lv10_normal_p1":1650,"spear_lv10_normal_p1":1450,"magic_staff_lv10_normal_p1":1400,"Plus1Stone":600,
 "body_03_beginner_normal_p1":1800,"body_01_beginner_normal_p1":1900,"helmet_01_beginner_normal_p1":900,"boots_01_beginner_normal_p1":650,
 "DragonGem":12000,"GloryGem":9000,"SoulJade":6500,"ThunderGem":7500,"Meteor":1000,"AnimaStone":8000,"wing_sky_feather_p0":25000,"wing_azure_dragon_p0":85000,"wing_celestial_phoenix_p0":240000
}
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
 _initialize_mount_items()
 _initialize_wing_items()
 initialized = true
 print("PHASE3B_GEAR_DATABASE_READY: ",items.size()," weapon+armor variants; armor_assets=33 classes=7")
func _tier_color(level: int) -> Color:
 if level <= 30: return Color(0.62,0.34,0.16)
 if level <= 60: return Color(0.25,0.52,0.82)
 if level <= 90: return Color(0.78,0.82,0.91)
 return Color(1.0,0.72,0.22)
func get_item(item_id: String) -> Dictionary:
 return items.get(item_id,{}).duplicate(true)

func get_item_price(item_id: String) -> int:
 return int(SHOP_PRICES.get(item_id,0))
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

func _initialize_mount_items() -> void:
 var fixtures := [
  {"id":"preview_heaven_fan","name":"الفانة السماوية","slot":"fan","family":"fan","type":"Equipment","base_attack":18,"base_defense":4},
  {"id":"preview_star_tower","name":"تاور النجمة","slot":"tower","family":"tower","type":"Equipment","base_attack":8,"base_defense":24},
  {"id":"preview_steed","name":"الخيل +12","slot":"steed","family":"steed","type":"Mount","base_attack":0,"base_defense":0,"mount_speed":180,"max_hp_bonus":500,"mount_speed_bonus":0.75},
  {"id":"preview_fire_tiger_skin","name":"سكن المطية الأسطورية: النمر الناري","slot":"mount_skin","family":"mount_skin","type":"MountSkin","base_attack":0,"base_defense":0},
  {"id":"preview_wing","name":"جناح سماوي","slot":"wing","family":"wing","type":"Wing","base_attack":0,"base_defense":0},
  {"id":"preview_mount_whip","name":"سوط ركوب","slot":"mount_whip","family":"mount_whip","type":"MountWhip","base_attack":0,"base_defense":0},
  {"id":"preview_garment","name":"زي الحارس","slot":"garment","family":"garment","type":"Garment","base_attack":0,"base_defense":0,"max_hp_bonus":900,"defense_bonus":55},
  {"id":"preview_weapon_accessory","name":"زخرفة السلاح","slot":"weapon_accessory","family":"weapon_accessory","type":"WeaponAccessory","base_attack":0,"base_defense":0,"attack_bonus":75,"critical":0.12},
  {"id":"mount_skin_tiger","name":"سكن النمر الأسطوري","slot":"mount_skin","family":"mount_skin","mount_type":"tiger","type":"MountSkin","base_attack":45,"base_defense":20,"attack_bonus":45,"defense_bonus":20,"critical":0.08,"movement_speed_bonus":1.35},
  {"id":"mount_skin_deer","name":"سكن الغزال الأسطوري","slot":"mount_skin","family":"mount_skin","mount_type":"deer","type":"MountSkin","base_attack":18,"base_defense":28,"attack_bonus":18,"defense_bonus":28,"critical":0.03,"movement_speed_bonus":1.65},
  {"id":"mount_skin_wolf","name":"سكن الذئب الأسطوري","slot":"mount_skin","family":"mount_skin","mount_type":"wolf","type":"MountSkin","base_attack":38,"base_defense":25,"attack_bonus":38,"defense_bonus":25,"critical":0.06,"movement_speed_bonus":1.20}
 ]
 for fixture in fixtures:
  var fixture_id := String(fixture.id)
  var plus_max := PLUS_LEVELS if String(fixture.slot) in ["fan","tower","steed"] else 0
  if plus_max == 0:
   items[fixture_id] = fixture.duplicate(true)
  else:
   for plus in range(0,plus_max+1):
    var item_id := fixture_id + "_p" + str(plus)
    var item: Dictionary = fixture.duplicate(true)
    item["id"] = item_id
    item["plus"] = plus
    item["quality"] = "Super" if plus == 12 else "Normal"
    item["level"] = 130 if String(fixture.slot) == "steed" else 120
    item["composition_points"] = 0
    item["sockets"] = []
    item["attack_bonus"] = int(fixture.base_attack) + plus * 4
    item["defense_bonus"] = int(fixture.base_defense) + plus * 3
    if String(fixture.slot) == "steed":
     item["max_hp_bonus"] = 500 + plus * 180
     item["mount_speed_bonus"] = 0.75 + float(plus) * 0.055
    item["gem_bonuses"] = {"attack":0,"magic_attack":0,"damage_reduction":0.0,"exp_bonus":0.0}
    item["display_name"] = String(fixture.name) + " +" + str(plus)
    items[item_id] = item
 print("PHASE5A_MOUNT_EQUIPMENT_FIXTURES_READY: fan=+0..+12 tower=+0..+12 steed=+0..+12 fire_tiger_skin=true wings=true whip=true garment=true")

func _initialize_quest_items() -> void:
 var rows := [["EuxeniteOre","Euxenite Ore"],["RebuildOre","Rebuild Ore"],["PeaceCommandToken","Peace Command Token"],["ChaosCommandToken","Chaos Command Token"],["DesertedCommandToken","Deserted Command Token"],["ProsperousCommandToken","Prosperous Command Token"],["DisturbedCommandToken","Disturbed Command Token"],["CalmedCommandToken","Calmed Command Token"],["SoulJade","Soul Jade"],["MoonBox","Moon Box"],["CleanWater","Clean Water"],["CelestialStone","Celestial Stone"],["HeavenFan","Heaven Fan"],["StarTower","Star Tower"],["ThunderGem","Thunder Gem"],["GloryGem","Glory Gem"],["DragonGem","Dragon Gem"],["PhoenixGem","Phoenix Gem"],["RainbowGem","Rainbow Gem"],["VioletGem","Violet Gem"],["FuryGem","Fury Gem"],["MoonGem","Moon Gem"],["KylinGem","Kylin Gem"],["MountBox","Mount Treasure Box"],["GarmentBox","Garment Treasure Box"]]
 for row in rows:
  items[String(row[0])] = {"id":String(row[0]),"display_name":String(row[1]),"type":"QuestItem","family":"quest_item","level":1,"quality":"Normal","plus":0,"stackable":true,"classes":EQUIPMENT_CLASSES.duplicate(),"sockets":[],"gem_bonuses":{}}
 print("PHASE4D_CLASSIC_QUEST_ITEMS_READY: count=",rows.size())

func _initialize_wing_items() -> void:
 var catalog := [
  {"id":"wing_sky_feather","name":"جناح الريشة السماوية","level":25,"attack":35,"defense":25,"hp":450,"price":25000},
  {"id":"wing_azure_dragon","name":"جناح التنين الأزرق","level":70,"attack":110,"defense":85,"hp":1400,"price":85000},
  {"id":"wing_celestial_phoenix","name":"جناح العنقاء السماوية","level":120,"attack":260,"defense":190,"hp":4200,"price":240000}
 ]
 for entry in catalog:
  for plus in range(0,PLUS_LEVELS+1):
   var item_id := String(entry.id) + "_p" + str(plus)
   var stat_scale := 1.0 + float(plus) * 0.12
   items[item_id] = {"id":item_id,"display_name":String(entry.name) + " +" + str(plus),"type":"Wing","equipment_type":"Wing","family":"wing","slot":"wing","level":int(entry.level),"quality":"Super" if plus >= 9 else "Elite" if plus >= 6 else "Unique" if plus >= 3 else "Normal","plus":plus,"classes":EQUIPMENT_CLASSES.duplicate(),"base_attack":int(entry.attack),"base_defense":int(entry.defense),"attack_bonus":int(round(float(entry.attack)*stat_scale)),"defense_bonus":int(round(float(entry.defense)*stat_scale)),"max_hp_bonus":int(round(float(entry.hp)*stat_scale)),"composition_points":0,"sockets":[],"gem_bonuses":{"attack":0,"magic_attack":0,"damage_reduction":0.0,"exp_bonus":0.0}}
 print("PHASE5A_WING_CATALOG_READY: tiers=3 plus=+0..+12 stats=attack/defense/max_hp visual_attachment=false")
