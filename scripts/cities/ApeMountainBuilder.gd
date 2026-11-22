extends Node3D
const K=preload("res://scripts/cities/CityAssetKit.gd")
func _ready(): build()
func build():
    var rock=Color(0.30,0.28,0.26)
    for i in range(18):
        var a=TAU*float(i)/18.0
        var r=285.0 if i%2==0 else 345.0
        K.place_scaled(self,"mountainside",Vector3(cos(a)*r,0,sin(a)*r),Vector3(120,75,105),a,rock)
        K.place(self,"rock_face_02" if i%2==0 else "rock_face_01",Vector3(cos(a)*205,0,sin(a)*205),24,a,rock)
    for p in [Vector3(-95,0,-80),Vector3(100,22,-120),Vector3(-110,42,75),Vector3(105,58,100)]:
        K.place(self,"innerscene-buddhist-temple-pagoda-c5ebacdc",p,18)
    for i in range(12):
        var a=TAU*float(i)/12.0
        K.place(self,"flora_birch_grove",Vector3(cos(a)*175,0,sin(a)*175),15,a,Color(0.18,0.38,0.20))
    for p in [Vector3(-40,18,-55),Vector3(35,38,45),Vector3(0,55,115)]:
        K.place(self,"bridge_wood",p,8,0.35,Color(0.36,0.23,0.13))
        K.place(self,"bridge_stone",p+Vector3(70,20,15),7,-0.25,rock)
    K.portal(self,"PhoenixCastle",Vector3(-130,0,145))
    K.portal(self,"DesertCity",Vector3(130,0,145))
    print("APE_MOUNTAIN_BUILD_OK: imported mountain and rock GLBs, four temples, forest and bridges")
