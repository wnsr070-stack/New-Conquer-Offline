extends Node3D
const K=preload("res://scripts/cities/CityAssetKit.gd")
func _ready(): build()
func build():
    K.add_ground(self,Color(0.05,0.44,0.58),Vector2.ZERO,Color(0.05,0.44,0.58),0.30,true)
    var islands=[{"p":Vector3(0,0.6,0),"s":Vector3(210,6,185)},{"p":Vector3(-181,0.6,0),"s":Vector3(105,4,92)},{"p":Vector3(181,0.6,0),"s":Vector3(112,4,95)},{"p":Vector3(0,0.6,-164.5),"s":Vector3(98,4,90)},{"p":Vector3(0,0.6,164.5),"s":Vector3(105,4,88)}]
    for island in islands: K.place_scaled(self,"mountainside",island.p,island.s,0,Color(0.72,0.66,0.42))
    for p in [Vector3(0,7,-30),Vector3(-48,7,25),Vector3(48,7,25),Vector3(-181,5,0),Vector3(181,5,0),Vector3(0,5,-164.5),Vector3(0,5,164.5)]:
        K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",p,12)
    for p in [Vector3(-60,5,-25),Vector3(60,5,-25),Vector3(-65,5,55),Vector3(65,5,55),Vector3(-181,4,28),Vector3(181,4,28),Vector3(-25,4,-164.5),Vector3(25,4,164.5)]:
        K.place(self,"obj_chinese_house",p,9,PI,Color(0.58,0.38,0.22))
    for p in [Vector3(-181,0.6,0),Vector3(181,0.6,0),Vector3(0,0.6,-164.5),Vector3(0,0.6,164.5),Vector3(0,0.6,0)]:
        K.place(self,"flora_mangrove",p+Vector3(35,0,28),10,0.4,Color(0.22,0.58,0.30))
        K.place(self,"flora_birch_grove",p+Vector3(-35,0,-25),9,-0.3,Color(0.22,0.58,0.30))
    K.place_scaled(self,"bridge_wood",Vector3(-116.75,1.6,0),Vector3(36,1.6,8),0,Color(0.36,0.23,0.13))
    K.place_scaled(self,"bridge_wood",Vector3(116.75,1.6,0),Vector3(36,1.6,8),0,Color(0.36,0.23,0.13))
    K.place_scaled(self,"bridge_wood",Vector3(0,1.6,-105.5),Vector3(36,1.6,8),PI/2.0,Color(0.36,0.23,0.13))
    K.place_scaled(self,"bridge_wood",Vector3(0,1.6,105.5),Vector3(36,1.6,8),PI/2.0,Color(0.36,0.23,0.13))
    K.portal(self,"DesertCity",Vector3(-55,6,55))
    K.portal(self,"TwinCity",Vector3(55,6,55))
    print("BIRD_ISLAND_BUILD_OK: full 2200m turquoise ocean, five raised islands, 24-28m gaps and four 36m connecting bridges")
