extends Node3D
const K=preload("res://scripts/cities/CityAssetKit.gd")
func _ready(): build()
func build():
    var grass=Color(0.58,0.52,0.28)
    var stone=Color(0.62,0.45,0.32)
    for i in range(12):
        var a=TAU*float(i)/12.0
        K.place_scaled(self,"mountainside",Vector3(cos(a)*330,0,sin(a)*330),Vector3(150,55,125),a,grass)
    for i in range(8):
        var a=TAU*float(i)/8.0
        K.place(self,"innerscene-japanese-maple-tree-565c1604",Vector3(cos(a)*205,0,sin(a)*205),17,a,Color(0.90,0.58,0.18))
        K.place(self,"flora_birch_grove",Vector3(cos(a)*245,0,sin(a)*245),14,-a,Color(0.86,0.34,0.13))
    K.place(self,"imperial_palace",Vector3(0,0,-115),34,PI,stone)
    for p in [Vector3(-90,0,-90),Vector3(90,0,-90),Vector3(-90,0,90),Vector3(90,0,90)]:
        K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",p,15,0,stone)
    for i in range(8):
        var a=TAU*float(i)/8.0
        K.place(self,"rock_face_01",Vector3(cos(a)*145,0,sin(a)*145),18,a,stone)
    K.portal(self,"TwinCity",Vector3(0,0,145))
    K.portal(self,"ApeMountain",Vector3(18,0,145))
    print("PHOENIX_CASTLE_BUILD_OK: imported palace, four landmarks, GLB ramparts and autumn forests")
