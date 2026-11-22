extends Node3D
const K=preload("res://scripts/cities/CityAssetKit.gd")
func _ready():build()
func build():
    K.add_ground(self,Color(0.05,0.44,0.58),Vector2.ZERO,Color(0.05,0.44,0.58),0.30,true)
    var islands=[{"p":Vector3(0,0.6,0),"s":Vector3(210,6,185)},{"p":Vector3(-181,0.6,0),"s":Vector3(105,4,92)},{"p":Vector3(181,0.6,0),"s":Vector3(112,4,95)},{"p":Vector3(0,0.6,-164.5),"s":Vector3(98,4,90)},{"p":Vector3(0,0.6,164.5),"s":Vector3(105,4,88)}]
    for i in range(islands.size()):
        var item=islands[i]
        if i==3: K.place_scaled(self,"mountainside",item.p,item.s,0,Color(0.86,0.90,0.96),0.96,"snow_02")
        else: K.place_scaled(self,"mountainside",item.p,item.s,0,Color(0.72,0.66,0.42))
    for p in [Vector3(0,7,-30),Vector3(-48,7,25),Vector3(48,7,25),Vector3(-181,5,0),Vector3(181,5,0),Vector3(0,5,-164.5),Vector3(0,5,164.5)]: K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",p,22.2)
    for p in [Vector3(-60,5,-25),Vector3(60,5,-25),Vector3(-65,5,55),Vector3(65,5,55),Vector3(-181,4,28),Vector3(181,4,28),Vector3(-25,4,-164.5),Vector3(25,4,164.5)]: K.place(self,"obj_chinese_house",p,16.65,PI,Color(0.58,0.38,0.22))
    for i in range(3):
        K.bridge(self,Vector3(-211+float(i)*44,3,0),45,0,"WestBridge_%02d"%i)
        K.bridge(self,Vector3(123+float(i)*44,3,0),45,0,"EastBridge_%02d"%i)
    for i in range(2):
        K.bridge(self,Vector3(0,3,-114+float(i)*17),19,PI/2,"NorthBridge_%02d"%i)
        K.bridge(self,Vector3(0,3,97+float(i)*17),19,PI/2,"SouthBridge_%02d"%i)
    K.portal(self,"DesertCity",Vector3(-55,6,55)); K.portal(self,"TwinCity",Vector3(55,6,55))
    print("BIRD_ISLAND_SNOW_PBR_AND_10_COLLIDABLE_BRIDGE_SEGMENTS_OK")
