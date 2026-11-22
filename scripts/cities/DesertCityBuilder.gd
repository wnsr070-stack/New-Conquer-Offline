extends Node3D
const K=preload("res://scripts/cities/CityAssetKit.gd")
func _ready():build()
func build():
    K.add_ground(self,Color(0.84,0.72,0.46),Vector2(300,300),Color(0.76,0.62,0.40),0.96,false,"sand_01","cobblestone")
    for i in range(16):
        var a=TAU*float(i)/16.0
        K.place_scaled(self,"mountainside",Vector3(cos(a)*380,0,sin(a)*380),Vector3(145,38,110),a,Color(0.84,0.72,0.48),0.92,"sand_01")
        K.place(self,"rock_face_01",Vector3(cos(a)*245,0,sin(a)*245),14,a,Color(0.76,0.62,0.40))
    for i in range(10):
        var x=float(i%5-2)*34.0; var z=float(i/5)*55.0-25.0
        K.place(self,"obj_chinese_house",Vector3(x,0,z),22.2,PI,Color(0.76,0.62,0.40))
    K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",Vector3(0,0,-105),37.0,PI,Color(0.76,0.62,0.40))
    for i in range(12):
        var a=TAU*float(i)/12.0
        K.place(self,"flora_mangrove",Vector3(410+cos(a)*92,0,-65+sin(a)*88),15,a,Color(0.22,0.48,0.28))
        K.place(self,"boulder_01",Vector3(410+cos(a)*104,0,-65+sin(a)*96),6,a,Color(0.76,0.62,0.40))
    K.oasis(self,Vector3(410,0.14,-65))
    K.portal(self,"ApeMountain",Vector3(-135,0,150)); K.portal(self,"BirdIsland",Vector3(135,0,150))
    print("DESERT_SAND_PBR_CLEAR_120M_OASIS_OK")
