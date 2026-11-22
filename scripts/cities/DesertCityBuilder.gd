extends Node3D
const K=preload("res://scripts/cities/CityAssetKit.gd")
func _ready(): build()
func build():
    var sand=Color(0.84,0.72,0.48)
    var wall=Color(0.76,0.62,0.40)
    for i in range(16):
        var a=TAU*float(i)/16.0
        K.place_scaled(self,"mountainside",Vector3(cos(a)*330,0,sin(a)*330),Vector3(145,38,110),a,sand,0.92)
        K.place(self,"rock_face_01",Vector3(cos(a)*205,0,sin(a)*205),14,a,wall,0.92)
    for i in range(10):
        var x=float(i%5-2)*34.0
        var z=float(i/5)*55.0-25.0
        K.place(self,"obj_chinese_house",Vector3(x,0,z),12,PI,wall)
    K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",Vector3(0,0,-105),20,PI,wall)
    for i in range(10):
        var a=TAU*float(i)/10.0
        K.place(self,"flora_mangrove",Vector3(155+cos(a)*72,0,-65+sin(a)*48),11,a,Color(0.22,0.48,0.28))
        K.place(self,"boulder_01",Vector3(155+cos(a)*85,0,-65+sin(a)*58),5,a,wall)
    K.portal(self,"ApeMountain",Vector3(-135,0,150))
    K.portal(self,"BirdIsland",Vector3(135,0,150))
    print("DESERT_CITY_BUILD_OK: GLB sand terrain, eastern buildings, oasis vegetation; water mesh asset unavailable")
