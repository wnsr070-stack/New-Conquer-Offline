extends Node3D
const K=preload("res://scripts/cities/CityAssetKit.gd")
func _ready(): build()
func build():
    var islands=[{"p":Vector3(0,0,0),"s":Vector3(210,24,185)},{"p":Vector3(-225,0,-115),"s":Vector3(105,17,92)},{"p":Vector3(220,0,-135),"s":Vector3(112,19,95)},{"p":Vector3(-185,0,205),"s":Vector3(98,16,90)},{"p":Vector3(215,0,205),"s":Vector3(105,18,88)}]
    for island in islands: K.place_scaled(self,"mountainside",island.p,island.s,0,Color(0.72,0.66,0.42))
    for p in [Vector3(0,12,-35),Vector3(-55,9,30),Vector3(55,9,35),Vector3(-225,8,-115),Vector3(220,9,-135)]:
        K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",p,14)
    for p in [Vector3(-225,0,-115),Vector3(220,0,-135),Vector3(-185,0,205),Vector3(215,0,205),Vector3(0,0,0)]:
        K.place(self,"flora_mangrove",p+Vector3(35,0,28),13,0.4,Color(0.22,0.58,0.30))
        K.place(self,"flora_birch_grove",p+Vector3(-35,0,-25),12,-0.3,Color(0.22,0.58,0.30))
    for p in [Vector3(-110,8,-60),Vector3(110,8,-65),Vector3(-90,8,110),Vector3(100,8,115)]:
        K.place(self,"bridge_wood",p,8,0.2,Color(0.36,0.23,0.13))
    K.portal(self,"DesertCity",Vector3(-150,0,170))
    K.portal(self,"TwinCity",Vector3(150,0,170))
    print("BIRD_ISLAND_BUILD_OK: five GLB island landforms, temples, tropical vegetation and wooden bridges; ocean mesh asset unavailable")
