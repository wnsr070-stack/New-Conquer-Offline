extends Node3D
const K=preload("res://scripts/cities/CityAssetKit.gd")
func _ready():build()
func build():
    K.add_ground(self,Color(0.22,0.20,0.22),Vector2(280,280),Color(0.36,0.35,0.34),0.96,false,"rock_boulder_dry","rock_boulder_dry")
    for i in range(24):
        var a=TAU*float(i)/24.0; var r=285.0 if i%2==0 else 345.0
        K.place_scaled(self,"mountainside",Vector3(cos(a)*r,0,sin(a)*r),Vector3(120,75,105),a,Color(0.22,0.20,0.22))
        K.place(self,"rock_face_02" if i%2==0 else "rock_face_01",Vector3(cos(a)*205,0,sin(a)*205),24,a,Color(0.22,0.20,0.22))
    for p in [Vector3(-75,0,-65),Vector3(75,0,-65),Vector3(-75,0,65),Vector3(75,0,65)]: K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",p,33.3)
    for p in [Vector3(-125,0,-5),Vector3(-115,0,85),Vector3(-35,0,120),Vector3(45,0,120),Vector3(125,0,65),Vector3(130,0,-30)]: K.place(self,"obj_chinese_house",p,20.35,PI,Color(0.34,0.28,0.20))
    K.forest(self,128); K.lava(self)
    K.portal(self,"PhoenixCastle",Vector3(-130,0,145)); K.portal(self,"DesertCity",Vector3(130,0,145))
    print("APE_VOLCANIC_PBR_AND_EMISSIVE_LAVA_OK")
