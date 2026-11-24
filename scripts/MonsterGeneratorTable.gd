extends RefCounted
class_name MonsterGeneratorTable
## Phase 4B Step 1: data-only CQ generator table.
## Camp population includes its single King/Champion; the King replaces one regular mob.

const ACTIVATION_DISTANCE_M := 75.0
const CAMP_SIZE_M := Vector2(40.0, 40.0)
const CITY_ORDER := ["TwinCity", "PhoenixCastle", "ApeMountain", "DesertCity", "BirdIsland"]

const MONSTERS := [
    {"id":"Chicken","cq_name":"Pheasant","city":"TwinCity","level":1,"hp":33,"damage":8,"exp":15,"rest_secs":5.0,"camp_sizes":[20,20,20,20]},
    {"id":"Pigeon","cq_name":"Turtledove","city":"TwinCity","level":7,"hp":81,"damage":18,"exp":35,"rest_secs":5.0,"camp_sizes":[20,20,20]},
    {"id":"Birb","cq_name":"Robin","city":"TwinCity","level":12,"hp":183,"damage":32,"exp":65,"rest_secs":6.0,"camp_sizes":[25,25]},
    {"id":"Ghost","cq_name":"Apparition","city":"TwinCity","level":17,"hp":303,"damage":50,"exp":110,"rest_secs":6.0,"camp_sizes":[15,15,15]},
    {"id":"Blob","cq_name":"Poltergeist","city":"TwinCity","level":22,"hp":548,"damage":78,"exp":180,"rest_secs":7.0,"camp_sizes":[20,20]},
    {"id":"Bunny","cq_name":"Bandit","city":"PhoenixCastle","level":27,"hp":850,"damage":115,"exp":270,"rest_secs":6.0,"camp_sizes":[20,20,20]},
    {"id":"Dog","cq_name":"Ratling","city":"PhoenixCastle","level":35,"hp":1350,"damage":170,"exp":410,"rest_secs":6.0,"camp_sizes":[20,20,20]},
    {"id":"Frog","cq_name":"Fire Spirit","city":"PhoenixCastle","level":43,"hp":2100,"damage":245,"exp":620,"rest_secs":6.0,"camp_sizes":[20,20]},
    {"id":"Orc","cq_name":"Macaque","city":"ApeMountain","level":50,"hp":3200,"damage":340,"exp":900,"rest_secs":6.0,"camp_sizes":[20,20,20]},
    {"id":"Yeti","cq_name":"Giant Ape","city":"ApeMountain","level":60,"hp":4900,"damage":480,"exp":1350,"rest_secs":6.0,"camp_sizes":[20,20,20]},
    {"id":"Cactoro","cq_name":"Sand Monster","city":"DesertCity","level":70,"hp":7200,"damage":650,"exp":1950,"rest_secs":6.0,"camp_sizes":[20,20,20]},
    {"id":"Dino","cq_name":"Hill Monster","city":"DesertCity","level":80,"hp":10500,"damage":880,"exp":2800,"rest_secs":7.0,"camp_sizes":[20,20]},
    {"id":"Armabee","cq_name":"Birdman","city":"BirdIsland","level":90,"hp":15000,"damage":1180,"exp":3900,"rest_secs":6.0,"camp_sizes":[20,20,20]},
    {"id":"Demon","cq_name":"HawKing","city":"BirdIsland","level":100,"hp":21500,"damage":1550,"exp":5400,"rest_secs":7.0,"camp_sizes":[20,20]},
    {"id":"Alien","cq_name":"Senior Birdman","city":"BirdIsland","level":110,"hp":30000,"damage":2050,"exp":7500,"rest_secs":7.0,"camp_sizes":[20,20]}
]

const WORLD_BOSSES := [
    {"id":"Mushroom King","city":"TwinCity","level":25,"hp":12000,"damage":220,"exp":3500,"max_npc":1,"scale":2.5,"rest_secs":60.0},
    {"id":"Orc Skull","city":"PhoenixCastle","level":48,"hp":45000,"damage":580,"exp":12000,"max_npc":1,"scale":2.2,"rest_secs":60.0},
    {"id":"Alpaking Evolved","city":"ApeMountain","level":68,"hp":110000,"damage":1100,"exp":30000,"max_npc":1,"scale":2.2,"rest_secs":60.0},
    {"id":"Blue Demon","city":"DesertCity","level":88,"hp":250000,"damage":1950,"exp":70000,"max_npc":1,"scale":2.2,"rest_secs":60.0},
    {"id":"Dragon Evolved","cq_name":"Terato Dragon","city":"BirdIsland","level":115,"hp":600000,"damage":3500,"exp":180000,"max_npc":1,"scale":2.2,"rest_secs":60.0}
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
            if amount < 1:
                errors.append("Invalid camp population: " + str(monster.id))
            var offset: Vector3 = offsets[camp_index]
            var camp_local_position: Vector3 = CITY_CENTER_FALLBACKS[monster.city] + offset
            var nearest_gate := INF
            for gate in gates:
                nearest_gate = minf(nearest_gate, camp_local_position.distance_to(gate))
            var minimum_gate_clearance := 25.0 if String(monster.city) == "BirdIsland" else 45.0
            if nearest_gate < minimum_gate_clearance or nearest_gate > 160.0:
                errors.append("Camp outside 45-160m gate clearance: " + str(monster.id) + " camp=" + str(camp_index) + " clearance=" + str(nearest_gate))
    for boss in WORLD_BOSSES:
        if int(boss.max_npc) != 1 or float(boss.scale) != 2.5 or float(boss.rest_secs) != 60.0:
            errors.append("Invalid world boss policy: " + str(boss.id))
    return errors
