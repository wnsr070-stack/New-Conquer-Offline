extends Node3D
const K=preload("res://scripts/cities/CityAssetKit.gd")
func _ready():build()
func build():
    K.add_ground(self,Color(0.68,0.62,0.34),Vector2(280,280),Color(0.68,0.62,0.34),0.94,false,"leafy_grass","cobblestone")
    for i in range(16):
        var a=TAU*float(i)/16.0
        K.place_scaled(self,"mountainside",Vector3(cos(a)*330,0,sin(a)*330),Vector3(150,55,125),a,Color(0.68,0.62,0.34))
    for i in range(36):
        var a=TAU*float(i)/36.0; var r=185.0+float(i%4)*19.0
        K.place(self,"innerscene-japanese-maple-tree-565c1604",Vector3(cos(a)*r,0,sin(a)*r),24,a,Color(0.90,0.58,0.18))
        K.place(self,"flora_birch_grove",Vector3(cos(a)*(r+25),0,sin(a)*(r+25)),19,-a,Color(0.86,0.34,0.13))
    K.place(self,"imperial_palace",Vector3(0,0,-115),62.9,PI,Color(0.62,0.45,0.32))
    for p in [Vector3(-90,0,-90),Vector3(90,0,-90),Vector3(-90,0,90),Vector3(90,0,90)]: K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",p,27.75)
    for p in [Vector3(-115,0,-35),Vector3(-70,0,65),Vector3(-20,0,105),Vector3(45,0,105),Vector3(115,0,55),Vector3(115,0,-35),Vector3(65,0,-170),Vector3(-65,0,-170)]: K.place(self,"obj_chinese_house",p,22.2,PI,Color(0.62,0.45,0.32))
    K.portal(self,"TwinCity",Vector3(0,0,145)); K.portal(self,"ApeMountain",Vector3(18,0,145))
    print("PHOENIX_PBR_GROUND_AND_1_85X_ARCHITECTURE_OK")
