extends Node3D
const K=preload("res://scripts/cities/CityAssetKit.gd")

func _ready():
    build()

func _bridge_segment(start:Vector3,length:float,index:int)->void:
    K.place_scaled(self,"bridge_wood",start,Vector3(length,1.8,9),0,Color(0.36,0.23,0.13))
    var body=StaticBody3D.new()
    body.name="SandToIceBridge_%02d_StaticBody3D"%index
    body.position=start+Vector3(length*0.5,0.9,0)
    var collision=CollisionShape3D.new()
    collision.name="CollisionShape3D"
    var shape=BoxShape3D.new()
    shape.size=Vector3(length,1.8,9)
    collision.shape=shape
    body.add_child(collision)
    add_child(body)

func build():
    K.add_ground(self,Color(0.05,0.44,0.58),Vector2.ZERO,Color(0.05,0.44,0.58),0.30,true)

    # Coordinates are the lower bounds used by place_scaled; island tops are y=4.6m.
    # The shoreline gap is 36m: sand island ends at x=-40, ice island begins at x=-4.
    var islands=[
        {"name":"SandIsland","p":Vector3(-145,0.6,-45),"s":Vector3(105,4,92),"tint":Color(0.72,0.66,0.42),"texture":""},
        {"name":"IceIsland","p":Vector3(-4,0.6,-45),"s":Vector3(112,4,95),"tint":Color(0.86,0.90,0.96),"texture":"snow_02"}
    ]
    for island in islands:
        K.place_scaled(self,"mountainside",island.p,island.s,0,island.tint,0.96,island.texture)

    # Sand-island structures: every footprint is well inside x=-145..-40, z=-45..47.
    K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",Vector3(-120,4.6,-20),22.2)
    K.place(self,"obj_chinese_house",Vector3(-78,4.6,-20),16.65,PI,Color(0.58,0.38,0.22))
    K.place(self,"obj_chinese_house",Vector3(-120,4.6,22),16.65,PI,Color(0.58,0.38,0.22))
    for p in [Vector3(-133,4.6,-32),Vector3(-62,4.6,-32),Vector3(-133,4.6,32),Vector3(-62,4.6,32)]:
        K.place(self,"flora_mangrove",p,10,0.4,Color(0.22,0.58,0.30))

    # Ice-island structures: every footprint is well inside x=-4..108, z=-45..50.
    K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",Vector3(22,4.6,-20),22.2)
    K.place(self,"obj_chinese_house",Vector3(65,4.6,-20),16.65,PI,Color(0.58,0.38,0.22))
    K.place(self,"obj_chinese_house",Vector3(22,4.6,22),16.65,PI,Color(0.58,0.38,0.22))
    for p in [Vector3(10,4.6,-32),Vector3(82,4.6,-32),Vector3(10,4.6,32),Vector3(82,4.6,32)]:
        K.place(self,"flora_birch_grove",p,10,-0.3,Color(0.78,0.86,0.92))

    # Three exactly abutting 15.34m wooden bridge sections, overlapping each shore by 5m.
    var bridge_start=-45.0
    var bridge_length=46.0/3.0
    for i in range(3):
        _bridge_segment(Vector3(bridge_start+float(i)*bridge_length,4.6,1),bridge_length,i)

    # Portals (and their attached pagodas) remain on safe interior land positions.
    K.portal(self,"DesertCity",Vector3(-95,4.6,30))
    K.portal(self,"TwinCity",Vector3(48,4.6,30))
    print("BIRD_ISLAND_LAND_PLACEMENT_OK: 2 islands, 36m water gap, 3 connected collidable bridge sections")
