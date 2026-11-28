extends RefCounted
class_name MonsterGeneratorTable
## Phase 4B Step 1: data-only CQ generator table.
## Camp population includes its single King/Champion; the King replaces one regular mob.

const ACTIVATION_DISTANCE_M := 45.0
const CAMP_SIZE_M := Vector2(40.0, 40.0)
const CITY_ORDER := ["TwinCity", "PhoenixCastle", "ApeMountain", "DesertCity", "BirdIsland"]

const MONSTERS := [
    {"id":"Chicken","cq_name":"Pheasant","city":"TwinCity","level":1,"hp":33,"damage":8,"defense":2,"exp":15,"gold_min":5,"gold_max":15,"rest_secs":4.0,"camp_sizes":[40,40,40,40]},
    {"id":"Pigeon","cq_name":"Turtledove","city":"TwinCity","level":7,"hp":81,"damage":18,"defense":5,"exp":35,"gold_min":10,"gold_max":25,"rest_secs":4.0,"camp_sizes":[40,40,40]},
    {"id":"Birb","cq_name":"Robin","city":"TwinCity","level":12,"hp":183,"damage":32,"defense":9,"exp":65,"gold_min":20,"gold_max":40,"rest_secs":4.0,"camp_sizes":[40,40]},
    {"id":"Ghost","cq_name":"Apparition","city":"TwinCity","level":17,"hp":303,"damage":50,"defense":14,"exp":110,"gold_min":30,"gold_max":60,"rest_secs":4.5,"camp_sizes":[40,40,40]},
    {"id":"Blob","cq_name":"Poltergeist","city":"TwinCity","level":22,"hp":548,"damage":78,"defense":20,"exp":180,"gold_min":40,"gold_max":80,"rest_secs":4.5,"camp_sizes":[40,40]},
    {"id":"Bunny","cq_name":"Bandit","city":"PhoenixCastle","level":27,"hp":850,"damage":115,"defense":30,"exp":270,"gold_min":60,"gold_max":120,"rest_secs":4.5,"camp_sizes":[40,40,40]},
    {"id":"Dog","cq_name":"Ratling","city":"PhoenixCastle","level":35,"hp":1350,"damage":170,"defense":42,"exp":410,"gold_min":80,"gold_max":160,"rest_secs":4.5,"camp_sizes":[40,40,40]},
    {"id":"Frog","cq_name":"Fire Spirit","city":"PhoenixCastle","level":50,"hp":2100,"damage":245,"defense":60,"exp":620,"gold_min":100,"gold_max":220,"rest_secs":4.5,"camp_sizes":[40,40]},
    {"id":"Orc","cq_name":"Macaque","city":"ApeMountain","level":55,"hp":3200,"damage":340,"defense":80,"exp":900,"gold_min":150,"gold_max":300,"rest_secs":5.0,"camp_sizes":[40,40,40]},
    {"id":"Yeti","cq_name":"Giant Ape","city":"ApeMountain","level":70,"hp":4900,"damage":480,"defense":110,"exp":1350,"gold_min":200,"gold_max":400,"rest_secs":5.0,"camp_sizes":[40,40,40]},
    {"id":"Cactoro","cq_name":"Sand Monster","city":"DesertCity","level":85,"hp":7200,"damage":650,"defense":145,"exp":1950,"gold_min":300,"gold_max":600,"rest_secs":5.0,"camp_sizes":[40,40,40]},
    {"id":"Dino","cq_name":"Hill Monster","city":"DesertCity","level":100,"hp":10500,"damage":880,"defense":185,"exp":2800,"gold_min":400,"gold_max":800,"rest_secs":5.0,"camp_sizes":[40,40]},
    {"id":"Armabee","cq_name":"Birdman","city":"BirdIsland","level":110,"hp":15000,"damage":1180,"defense":230,"exp":3900,"gold_min":500,"gold_max":1000,"rest_secs":5.5,"camp_sizes":[40,40,40]},
    {"id":"Demon","cq_name":"HawKing","city":"BirdIsland","level":120,"hp":21500,"damage":1550,"defense":290,"exp":5400,"gold_min":700,"gold_max":1300,"rest_secs":5.5,"camp_sizes":[40,40]},
    {"id":"Alien","cq_name":"Senior Birdman","city":"BirdIsland","level":130,"hp":30000,"damage":2050,"defense":360,"exp":7500,"gold_min":900,"gold_max":1800,"rest_secs":5.5,"camp_sizes":[40,40]}
]

const WORLD_BOSSES := [
    {"id":"Mushroom King","city":"TwinCity","level":25,"hp":12000,"damage":220,"defense":160,"exp":3500,"gold_min":3000,"gold_max":6000,"boss_tier":"quest","is_major_boss":false,"max_npc":1,"scale":2.5,"rest_secs":45.0},
    {"id":"Orc Skull","city":"PhoenixCastle","level":55,"hp":45000,"damage":580,"defense":280,"exp":12000,"gold_min":7000,"gold_max":12000,"boss_tier":"world","is_major_boss":true,"max_npc":1,"scale":2.5,"rest_secs":60.0},
    {"id":"Alpaking Evolved","city":"ApeMountain","level":85,"hp":110000,"damage":1100,"defense":480,"exp":30000,"gold_min":12000,"gold_max":20000,"boss_tier":"world","is_major_boss":true,"max_npc":1,"scale":2.5,"rest_secs":60.0},
    {"id":"Blue Demon","city":"DesertCity","level":110,"hp":250000,"damage":1950,"defense":760,"exp":70000,"gold_min":20000,"gold_max":35000,"boss_tier":"world","is_major_boss":true,"max_npc":1,"scale":2.5,"rest_secs":60.0},
    {"id":"Dragon Evolved","cq_name":"Terato Dragon","city":"BirdIsland","level":135,"hp":600000,"damage":3500,"defense":1200,"exp":180000,"gold_min":35000,"gold_max":60000,"boss_tier":"world","is_major_boss":true,"max_npc":1,"scale":2.5,"rest_secs":60.0}
]

const QUEST_BOSSES := [
    {"id":"Reborn Guardian","cq_name":"Terato Dragon","city":"BirdIsland","level":130,"hp":900000,"damage":4200,"defense":1600,"exp":250000,"gold_min":50000,"gold_max":75000,"boss_tier":"reborn","is_major_boss":false,"max_npc":1,"scale":2.7,"rest_secs":45.0,"quest_drop_items":["CleanWater","DragonGem","PhoenixGem","RainbowGem","VioletGem","FuryGem","MoonGem","KylinGem"]}
]

# Each city has its own scene-local coordinate frame; these are the authored scene origins.
# Bird Island's authored island surface is elevated; its center is the midpoint between its two landmasses.
const CITY_CENTER_FALLBACKS := {
    "TwinCity": Vector3(0.0, -1.35, 0.0),
    "PhoenixCastle": Vector3(0.0, 0.0, 0.0),
    "ApeMountain": Vector3(0.0, 0.0, 0.0),
    "DesertCity": Vector3(0.0, 0.0, 0.0),
    "BirdIsland": Vector3(0.0, 4.6, 0.0)
}

# Stable local offsets, 45-160m from each city center. Every camp is 40m x 40m.
const CITY_GATE_POSITIONS := {
    "TwinCity": [Vector3(0,0,-168),Vector3(0,0,168),Vector3(168,0,0),Vector3(-168,0,0)],
    "PhoenixCastle": [Vector3(0,0,145),Vector3(18,0,145)],
    "ApeMountain": [Vector3(-130,0,145),Vector3(130,0,145)],
    "DesertCity": [Vector3(-135,0,150),Vector3(135,0,150)],
    "BirdIsland": [Vector3(-95,4.6,30),Vector3(48,4.6,30)]
}
const CAMP_OFFSETS := {
    "TwinCity": [
        Vector3(0,0,-230),Vector3(0,0,-275),Vector3(-55,0,-245),Vector3(0,0,230),
        Vector3(0,0,275),Vector3(55,0,245),Vector3(230,0,0),Vector3(275,0,0),
        Vector3(245,0,-55),Vector3(-230,0,0),Vector3(-275,0,0),Vector3(-245,0,55),
        Vector3(-230,0,230),Vector3(230,0,-230)
    ],
    "PhoenixCastle": [
        Vector3(0,0,220),Vector3(-55,0,240),Vector3(65,0,250),
        Vector3(0,0,290),Vector3(-130,0,230),Vector3(130,0,230),
        Vector3(-100,0,260),Vector3(100,0,260)
    ],
    "ApeMountain": [
        Vector3(-180,0,210),Vector3(-220,0,240),Vector3(-100,0,260),
        Vector3(180,0,210),Vector3(220,0,240),Vector3(100,0,260)
    ],
    "DesertCity": [
        Vector3(-185,0,215),Vector3(-225,0,245),Vector3(-100,0,270),
        Vector3(185,0,215),Vector3(225,0,245)
    ],
    "BirdIsland": [
        Vector3(-125,0,-25),Vector3(-65,0,-25),Vector3(-125,0,25),
        Vector3(16,0,-25),Vector3(85,0,-25),Vector3(16,0,25),Vector3(85,0,25)
    ]
}

static func camp_count() -> int:
    var total := 0
    for monster in MONSTERS:
        total += monster.camp_sizes.size()
    return total

static func scheduled_normal_count() -> int:
    var total := 0
    for monster in MONSTERS:
        for amount in monster.camp_sizes:
            total += int(amount)
    return total

static func king_count() -> int:
    return camp_count()

static func scheduled_world_count() -> int:
    return scheduled_normal_count() + WORLD_BOSSES.size()

static func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    if MONSTERS.size() != 15:
        errors.append("Expected exactly 15 normal monster definitions")
    if WORLD_BOSSES.size() != 5:
        errors.append("Expected exactly 5 world bosses")
    for monster in MONSTERS:
        if not CITY_CENTER_FALLBACKS.has(monster.city):
            errors.append("Missing city center: " + str(monster.city))
        if monster.camp_sizes.size() > CAMP_OFFSETS.get(monster.city, []).size():
            errors.append("Insufficient camp offsets for " + str(monster.id))
        var gates: Array = CITY_GATE_POSITIONS.get(monster.city, [])
        var offsets: Array = CAMP_OFFSETS.get(monster.city, [])
        for camp_index in range(monster.camp_sizes.size()):
            var amount: int = int(monster.camp_sizes[camp_index])
            if amount < 35 or amount > 40:
                errors.append("Camp population outside 35-40 active budget: " + str(monster.id))
            var offset: Vector3 = offsets[camp_index]
            var camp_local_position: Vector3 = CITY_CENTER_FALLBACKS[monster.city] + offset
            var nearest_gate := INF
            for gate in gates:
                nearest_gate = minf(nearest_gate, camp_local_position.distance_to(gate))
            var minimum_gate_clearance := 25.0 if String(monster.city) == "BirdIsland" else 45.0
            if nearest_gate < minimum_gate_clearance or nearest_gate > 160.0:
                errors.append("Camp outside 45-160m gate clearance: " + str(monster.id) + " camp=" + str(camp_index) + " clearance=" + str(nearest_gate))
    var previous := {"level":0,"hp":0,"damage":0,"defense":0,"exp":0,"gold_min":0,"gold_max":0}
    for monster in MONSTERS:
        for key in previous:
            if int(monster.get(key,0)) <= int(previous[key]):
                errors.append("Non-monotonic monster progression: " + str(monster.id) + " " + key)
            previous[key] = int(monster.get(key,0))
    var major_count := 0
    for boss in WORLD_BOSSES:
        if int(boss.max_npc) != 1 or float(boss.scale) != 2.5:
            errors.append("Invalid world boss policy: " + str(boss.id))
        if bool(boss.get("is_major_boss",false)): major_count += 1
    if major_count != 4: errors.append("Expected exactly four major world bosses")
    if QUEST_BOSSES.size() != 1 or int(QUEST_BOSSES[0].level) < 130:
        errors.append("Reborn quest boss must be level 130+")
    return errors
