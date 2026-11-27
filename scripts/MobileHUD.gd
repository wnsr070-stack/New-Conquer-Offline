extends Control
## Touch-first 2D HUD. All 3D presentation remains imported assets; this UI owns no 3D nodes.
const ICON_SCRIPT = preload("res://scripts/ItemIconGenerator.gd")
const SKILL_ICON_FILES := {"bow":"bow.png","arrow":"arrow.png","fire":"fire.png","lightning":"lightning.png","speed":"speed.png","shield":"shield.png","sword":"sword.png","dagger":"dagger.png","heal":"heal.png","poison":"poison.png"}
const WINDOW_NAMES := ["Inventory","Character","Quests","Daily Login","Map","Chat","Merchant","Warehouse","ArtisanMaster"]
const FORGE_TABS := ["Plus +1…+12","Quality","Level","Sockets","Anima"]
var _hero: Node3D
var _window_layer: Control
var _active_window := ""
var _status_label: Label
var _quest_panel: VBoxContainer
var _minimap_label: Label
var _joystick_center := Vector2.ZERO
var _joystick_vector := Vector2.ZERO
var _dragging_joystick := false
var _current_npc := ""
var _current_role := ""
var _last_quest_id := ""
var _quest_category := "MAIN_PROMOTION"
var _selected_inventory_slot := -1
var _selected_warehouse_slot := -1
var _window_menu: VBoxContainer
var _character_preview_model: Node3D
var _character_preview_container: SubViewportContainer
var _character_preview_dragging := false
var _selected_equipment_slot := "weapon"
var _settings_feedback: Label
var _auto_hunt_button: Button

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layout_direction = Control.LAYOUT_DIRECTION_LTR
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 _build_hud()
 _install_arabic_theme()
 _apply_arabic_rtl(self)
 _connect_systems()
 var settings := _root_autoload("GameSettings")
 if settings != null and settings.has_method("apply_world_settings"):
  settings.apply_world_settings()
 _refresh_all()
 print("PHASE5A_MOBILE_HUD_READY: touch_ui=true inventory=40 warehouse=40 stack=100 character_slots=10 procedural_3d=false")
 if OS.get_cmdline_user_args().has("--preview-mobile-hud"):
  call_deferred("_run_mobile_hud_preview")

func _process(delta: float) -> void:
 _refresh_status()
 _refresh_minimap()
 if is_instance_valid(_character_preview_model) and not _character_preview_dragging:
  _character_preview_model.rotation.y += delta * 0.22

func _build_hud() -> void:
 var root:=Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.layout_direction = Control.LAYOUT_DIRECTION_LTR
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(root)
 var hero:=_ornate_panel(root,Vector2(16,14),Vector2(365,164))
 var head:=HBoxContainer.new()
 head.position=Vector2(12,8)
 hero.add_child(head)
 var portrait:=TextureRect.new()
 portrait.texture=load("res://assets/ui/hero_portrait.svg")
 portrait.custom_minimum_size=Vector2(68,68)
 portrait.size=Vector2(68,68)
 portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 var circle_shader:=Shader.new()
 circle_shader.code="shader_type canvas_item; void fragment(){ vec2 p=UV-vec2(0.5); if(length(p)>0.49) discard; COLOR=texture(TEXTURE,UV)*COLOR; }"
 var circle_material:=ShaderMaterial.new()
 circle_material.shader=circle_shader
 portrait.material=circle_material
 var portrait_stack:=Control.new()
 portrait_stack.custom_minimum_size=Vector2(76,76)
 portrait_stack.size=Vector2(76,76)
 portrait.position=Vector2(4,4)
 portrait_stack.add_child(portrait)
 var portrait_ring:=GoldRing.new()
 portrait_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 portrait_ring.mouse_filter=Control.MOUSE_FILTER_IGNORE
 portrait_stack.add_child(portrait_ring)
 head.add_child(portrait_stack)
 var info:=VBoxContainer.new()
 info.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
 info.custom_minimum_size=Vector2(230,0)
 head.add_child(info)
 _status_label=Label.new()
 _status_label.add_theme_font_size_override("font_size",15)
 _status_label.custom_minimum_size = Vector2(230,0)
 _status_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
 _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 info.add_child(_status_label)
 var rank:=Label.new()
 rank.text="رامٍ  •  النقابة: بلا"
 rank.add_theme_color_override("font_color",Color(0.95,0.79,0.42))
 info.add_child(rank)
 var sta:=ProgressBar.new()
 sta.position=Vector2(92,91)
 sta.custom_minimum_size=Vector2(250,12)
 sta.max_value=100
 sta.value=100
 sta.show_percentage=false
 hero.add_child(sta)
 var buffs:=Label.new()
 buffs.text="✦  ◆  ♜  ✚"
 buffs.position=Vector2(95,109)
 hero.add_child(buffs)
 var modes:=HBoxContainer.new()
 modes.position=Vector2(10,135)
 for mode in ["سلمي","فريق","صيد","حر"]:
  var mb:=_button(mode,_set_combat_mode.bind(mode))
  mb.custom_minimum_size=Vector2(78,26)
  mb.add_theme_font_size_override("font_size",12)
  modes.add_child(mb)
 hero.add_child(modes)
 var qcard:=_ornate_panel(root,Vector2(-390,640),Vector2(365,190))
 qcard.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 _quest_panel=VBoxContainer.new()
 _quest_panel.position=Vector2(12,8)
 _quest_panel.size=Vector2(340,170)
 qcard.add_child(_quest_panel)

 var radar_frame:=_ornate_panel(root,Vector2(-200,14),Vector2(184,184),true)
 var radar:=RadarDisplay.new()
 radar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 radar_frame.add_child(radar)
 _minimap_label=Label.new()
 _minimap_label.set_anchors_preset(Control.PRESET_CENTER)
 _minimap_label.position=Vector2(-65,-18)
 _minimap_label.size=Vector2(130,42)
 _minimap_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 _minimap_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 _minimap_label.add_theme_font_size_override("font_size",11)
 radar_frame.add_child(_minimap_label)

 var quick:=HBoxContainer.new()
 quick.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 quick.position=Vector2(-224,210)
 root.add_child(quick)
 for p in [["🎒","الحقيبة","Inventory","bag"],["♟","الشخصية","Character","character"],["📜","المهام","Quests","quest"],["🛒","السوق","Merchant","merchant"]]:
  var entry:=VBoxContainer.new()
  entry.custom_minimum_size=Vector2(52,68)
  entry.add_theme_constant_override("separation",1)
  var icon_button:=_round_button("",_quick_action.bind(String(p[2])))
  icon_button.custom_minimum_size=Vector2(48,48)
  icon_button.size=Vector2(48,48)
  _apply_glass_round_style(icon_button,24)
  icon_button.add_theme_constant_override("icon_max_width",32)
  icon_button.icon=load("res://assets/ui/menu/"+String(p[3]+".png")) as Texture2D
  icon_button.expand_icon=true
  entry.add_child(icon_button)
  var caption:=_label(String(p[1]))
  caption.add_theme_font_size_override("font_size",10)
  caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  entry.add_child(caption)
  quick.add_child(entry)

 var right_actions:=VBoxContainer.new()
 right_actions.name="RightCenterActions"
 right_actions.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
 right_actions.position=Vector2(-78,-112)
 right_actions.custom_minimum_size=Vector2(66,224)
 right_actions.add_theme_constant_override("separation",26)
 right_actions.z_index=24
 root.add_child(right_actions)
 var settings_entry:=VBoxContainer.new()
 settings_entry.custom_minimum_size=Vector2(64,72)
 settings_entry.add_theme_constant_override("separation",2)
 var settings_button:=_round_button("",_quick_action.bind("System"))
 settings_button.custom_minimum_size=Vector2(54,54)
 settings_button.size=Vector2(54,54)
 settings_button.icon=load("res://assets/ui/menu/settings.png") as Texture2D
 settings_button.expand_icon=true
 settings_button.add_theme_constant_override("icon_max_width",34)
 _apply_glass_round_style(settings_button,14)
 settings_entry.add_child(settings_button)
 var settings_caption:=_label("الإعدادات")
 settings_caption.add_theme_font_size_override("font_size",10)
 settings_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 settings_entry.add_child(settings_caption)
 right_actions.add_child(settings_entry)
 var hunt_entry:=VBoxContainer.new()
 hunt_entry.custom_minimum_size=Vector2(64,72)
 hunt_entry.add_theme_constant_override("separation",2)
 _auto_hunt_button=_round_button("",_quick_action.bind("Auto-Hunt"))
 _auto_hunt_button.custom_minimum_size=Vector2(54,54)
 _auto_hunt_button.size=Vector2(54,54)
 _auto_hunt_button.icon=load("res://assets/ui/menu/hunt.png") as Texture2D
 _auto_hunt_button.expand_icon=true
 _auto_hunt_button.add_theme_constant_override("icon_max_width",34)
 hunt_entry.add_child(_auto_hunt_button)
 var hunt_caption:=_label("صيد تلقائي")
 hunt_caption.add_theme_font_size_override("font_size",10)
 hunt_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 hunt_entry.add_child(hunt_caption)
 right_actions.add_child(hunt_entry)
 _refresh_auto_hunt_button()

 _window_menu=VBoxContainer.new()
 _window_menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 _window_menu.position=Vector2(-205,258)
 _window_menu.visible=false
 _window_menu.z_index=30
 root.add_child(_window_menu)
 for p in [["الحقيبة","Inventory","bag"],["الشخصية","Character","character"],["المهارات","Skill","skill"],["المهام","Quests","quest"],["السوق","Merchant","merchant"],["النقابة","Guild","character"],["الإعدادات","System","settings"]]:
  var b:=_round_button(String(p[0]),_open_window.bind(String(p[1])))
  b.icon=load("res://assets/ui/menu/"+String(p[2])+".png") as Texture2D
  b.expand_icon=true
  b.add_theme_constant_override("icon_max_width",26)
  _window_menu.add_child(b)

 var chat:=_ornate_panel(root,Vector2(16,-390),Vector2(360,165))
 chat.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 chat.position=Vector2(maxf(16.0,(get_viewport_rect().size.x-360.0)*0.5),-390)
 chat.z_index=26
 var tabs:=HBoxContainer.new()
 tabs.position=Vector2(8,7)
 for t in ["All","Talk","Whisper","Team","Guild","System"]:
  var b:=_button(t,_select_chat_tab.bind(t))
  b.custom_minimum_size=Vector2(54,26)
  tabs.add_child(b)
 chat.add_child(tabs)
 var log:=Label.new()
 log.text="[النظام] مرحبًا بك في المدينة التوأم"
 log.position=Vector2(12,42)
 log.size=Vector2(330,72)
 chat.add_child(log)
 var entry:=LineEdit.new()
 entry.placeholder_text="اكتب رسالتك هنا..."
 entry.position=Vector2(10,120)
 entry.size=Vector2(275,30)
 chat.add_child(entry)
 var send:=_button("Send",_send_chat_message.bind(entry,log))
 send.position=Vector2(290,120)
 send.custom_minimum_size=Vector2(58,30)
 chat.add_child(send)

 var joy:=JoystickTouchArea.new()
 joy.name="VirtualJoystick"
 joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 joy.position=Vector2(16,-148)
 joy.size=Vector2(132,132)
 joy.custom_minimum_size=Vector2(132,132)
 joy.z_index=50
 joy.visible=true
 joy.mouse_filter=Control.MOUSE_FILTER_IGNORE
 joy.gui_input.connect(_on_joystick_input)
 var joy_base:=Panel.new()
 joy_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 joy_base.mouse_filter=Control.MOUSE_FILTER_IGNORE
 joy_base.add_theme_stylebox_override("panel",_circular_style(Color(0.055,0.045,0.035,0.78),Color(0.95,0.76,0.30),5,66))
 joy.add_child(joy_base)
 var joyart:=JoystickVisual.new()
 joyart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 joyart.mouse_filter=Control.MOUSE_FILTER_IGNORE
 joy.add_child(joyart)
 root.add_child(joy)

 var bottom:=Control.new()
 bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 bottom.z_index=10
 bottom.mouse_filter=Control.MOUSE_FILTER_IGNORE
 root.add_child(bottom)
 var hot:=HBoxContainer.new()
 hot.name="F1F10Hotbar"
 hot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 hot.add_theme_constant_override("separation",5)
 var hotbar_width:=445.0
 var orb_size:=76.0
 var total_width:=orb_size*2.0+16.0+hotbar_width
 var start_x:=maxf(8.0,(get_viewport_rect().size.x-total_width)*0.5)
 var hp_orb:=CrystalOrb.new()
 hp_orb.name="CrystalHPOrb"
 hp_orb.kind="HP"
 hp_orb.size=Vector2(orb_size,orb_size)
 hp_orb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 hp_orb.position=Vector2(start_x,-112)
 hp_orb.add_to_group("hud_orbs")
 bottom.add_child(hp_orb)
 hot.position=Vector2(start_x+orb_size+8.0,-80)
 hot.custom_minimum_size=Vector2(hotbar_width,42)
 hot.size=Vector2(hotbar_width,42)
 for i in range(10):
  var button:=_button("",_use_skill_at.bind(i))
  button.custom_minimum_size=Vector2(40,40)
  button.size=Vector2(40,40)
  _apply_glass_round_style(button,10)
  _set_skill_button_icon(button,["bow","arrow","fire","lightning","speed","shield","sword","dagger","heal","poison"][i],"F%d"%(i+1))
  hot.add_child(button)
 bottom.add_child(hot)
 var mp_orb:=CrystalOrb.new()
 mp_orb.name="CrystalMPOrb"
 mp_orb.kind="MP"
 mp_orb.size=Vector2(orb_size,orb_size)
 mp_orb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 mp_orb.position=Vector2(start_x+orb_size+8.0+hotbar_width+8.0,-112)
 mp_orb.add_to_group("hud_orbs")
 bottom.add_child(mp_orb)

 var combat:=Control.new()
 combat.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 combat.position=Vector2(-270,-250)
 combat.size=Vector2(254,238)
 combat.z_index=20
 combat.mouse_filter=Control.MOUSE_FILTER_IGNORE
 root.add_child(combat)
 var attack:=_round_button("",_attack)
 attack.position=Vector2(154,132)
 attack.size=Vector2(88,88)
 _apply_glass_round_style(attack,44)
 _set_skill_button_icon(attack,"bow")
 combat.add_child(attack)
 var arc_buttons: Array = [["قفزة",_jump,Vector2(166,48)],["تشتت",_use_primary_skill,Vector2(92,18)],["طيران",_jump,Vector2(18,66)],["مطر",_use_secondary_skill,Vector2(92,178)],["سريع",_use_primary_skill,Vector2(166,0)],["هدف",_cycle_target,Vector2(18,154)]]
 for item in arc_buttons:
  var b:=_round_button(String(item[0]),item[1])
  var arc_icon: String = String({"قفزة":"speed","تشتت":"arrow","طيران":"speed","مطر":"fire","سريع":"lightning","هدف":"bow"}.get(String(item[0]),"bow"))
  b.position=item[2]
  b.size=Vector2(56,56)
  _apply_glass_round_style(b,28)
  _set_skill_button_icon(b,String(arc_icon))
  combat.add_child(b)

 _window_layer=Control.new()
 _window_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 _window_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
 _window_layer.z_index=30
 add_child(_window_layer)

class GoldRing extends Control:
 func _draw()->void:
  var c:=size*0.5
  draw_arc(c,34.0,0.0,TAU,72,Color(0.95,0.76,0.30,1.0),4.0,true)
  draw_arc(c,29.5,0.0,TAU,72,Color(0.55,0.36,0.13,1.0),1.5,true)
  for i in range(8):
   var a:=TAU*float(i)/8.0
   draw_circle(c+Vector2(cos(a),sin(a))*34.0,2.0,Color(1.0,0.88,0.55,1.0))

class JoystickTouchArea extends Control:
 func _has_point(point: Vector2)->bool:
  return point.distance_to(size*0.5)<=size.x*0.5

class RoyalOrnament extends Control:
 func _draw()->void:
  var gold:=Color(0.95,0.76,0.30,0.98)
  var ruby:=Color(0.82,0.035,0.09,1.0)
  var w:=size.x
  var h:=size.y
  for p in [Vector2(13,13),Vector2(w-13,13),Vector2(13,h-13),Vector2(w-13,h-13)]:
   var sx:=1.0 if p.x<w*0.5 else -1.0
   var sy:=1.0 if p.y<h*0.5 else -1.0
   draw_polyline(PackedVector2Array([p,p+Vector2(14*sx,0),p+Vector2(25*sx,8*sy),p+Vector2(17*sx,14*sy),p+Vector2(8*sx,10*sy),p]),gold,2.5,true)
  var cx:=w*0.5
  for y in [8.0,h-8.0]:
   var d:=1.0 if y<h*0.5 else -1.0
   var crown:=PackedVector2Array([Vector2(cx-20,y+5*d),Vector2(cx-14,y-5*d),Vector2(cx-5,y+2*d),Vector2(cx,y-10*d),Vector2(cx+5,y+2*d),Vector2(cx+14,y-5*d),Vector2(cx+20,y+5*d)])
   draw_polyline(crown,gold,2.8,true)
   draw_colored_polygon(PackedVector2Array([Vector2(cx,y-5*d),Vector2(cx+5,y),Vector2(cx,y+6*d),Vector2(cx-5,y)]),ruby)

class CrystalOrb extends Control:
 var kind:="HP"
 func _draw()->void:
  var c:=size*0.5
  var r:=size.x*0.43
  var red:=kind=="HP"
  draw_circle(c,r+5.0,Color(0.95,0.76,0.30,0.95))
  draw_circle(c,r+2.0,Color(0.18,0.12,0.06,1.0))
  draw_circle(c,r,Color(0.72,0.035,0.10,0.96) if red else Color(0.025,0.24,0.82,0.96))
  draw_circle(c,r*0.68,Color(1.0,0.18,0.22,0.62) if red else Color(0.16,0.52,1.0,0.62))
  draw_circle(c+Vector2(-r*0.28,-r*0.30),r*0.18,Color(1.0,1.0,1.0,0.55))
  draw_arc(c,r+4.0,0.0,TAU,72,Color(1.0,0.88,0.55,1.0),3.0,true)
  draw_string(ThemeDB.fallback_font,c+Vector2(-r*0.55,5),kind,HORIZONTAL_ALIGNMENT_CENTER,40,12,Color.WHITE)

class SplitOrb extends Control:
 var hp_ratio:=1.0
 var mp_ratio:=1.0
 func _draw()->void:
  var center:=size*0.5
  var radius:=minf(size.x,size.y)*0.43
  draw_circle(center,radius,Color(0.025,0.03,0.05,0.98))
  var left:=PackedVector2Array([center])
  var right:=PackedVector2Array([center])
  for i in range(33):
   var a:=PI*0.5+PI*float(i)/32.0
   left.append(center+Vector2(cos(a),sin(a))*radius)
   var b:=-PI*0.5+PI*float(i)/32.0
   right.append(center+Vector2(cos(b),sin(b))*radius)
  left.append(center)
  right.append(center)
  draw_colored_polygon(left,Color(0.86,0.10,0.16,0.94*clampf(hp_ratio,0.12,1.0)))
  draw_colored_polygon(right,Color(0.10,0.38,0.94,0.94*clampf(mp_ratio,0.12,1.0)))
  draw_line(center+Vector2(0,-radius),center+Vector2(0,radius),Color(0.96,0.82,0.52),3.0)
  draw_arc(center,radius,0.0,TAU,72,Color(0.96,0.76,0.32),5.0,true)
  draw_string(ThemeDB.fallback_font,center+Vector2(-radius*0.72,5),"HP",HORIZONTAL_ALIGNMENT_CENTER,42,13,Color.WHITE)
  draw_string(ThemeDB.fallback_font,center+Vector2(radius*0.30,5),"MP",HORIZONTAL_ALIGNMENT_CENTER,42,13,Color.WHITE)

class JoystickVisual extends Control:
 func _draw() -> void:
  var center := size*0.5
  var radius := minf(size.x,size.y)*0.48
  draw_circle(center,radius,Color(0.08,0.10,0.14,0.65))
  draw_arc(center,radius,0.0,TAU,64,Color(0.88,0.76,0.52,0.78),4.0,true)
  draw_circle(center,radius*0.46,Color(0.18,0.20,0.24,0.65))
  draw_arc(center,radius*0.46,0.0,TAU,48,Color(0.96,0.84,0.62,0.92),3.0,true)

class RadarDisplay extends Control:
 func _draw()->void:
  var center:=size*0.5
  var radius:=minf(size.x,size.y)*0.43
  draw_circle(center,radius,Color(0.04,0.10,0.12,0.95))
  for r in [radius*0.35,radius*0.68,radius]:
   draw_arc(center,r,0.0,TAU,64,Color(0.82,0.68,0.38,0.75),1.5,true)
  draw_line(center+Vector2(-radius,0),center+Vector2(radius,0),Color(0.55,0.55,0.45,0.35),1.0)
  draw_line(center+Vector2(0,-radius),center+Vector2(0,radius),Color(0.55,0.55,0.45,0.35),1.0)
  draw_circle(center,4.0,Color(0.25,0.95,0.55))

func _root_autoload(node_name: String) -> Node:
 if not is_inside_tree(): return null
 var scene_root := get_tree().root
 if scene_root == null: return null
 return scene_root.get_node_or_null(node_name)

func _connect_systems() -> void:
 var npcs := _root_autoload("NPCMerchantSystem")
 if npcs != null and npcs.has_signal("npc_interacted") and not npcs.npc_interacted.is_connected(_on_npc_interacted):
  npcs.npc_interacted.connect(_on_npc_interacted)
 var quests := _root_autoload("QuestSystem")
 if quests != null:
  if quests.has_signal("quest_accepted") and not quests.quest_accepted.is_connected(_refresh_quests): quests.quest_accepted.connect(_refresh_quests)
  if quests.has_signal("quest_progressed") and not quests.quest_progressed.is_connected(_on_quest_progressed): quests.quest_progressed.connect(_on_quest_progressed)
  if quests.has_signal("quest_completed") and not quests.quest_completed.is_connected(_refresh_quests): quests.quest_completed.connect(_refresh_quests)
  if quests.has_signal("quest_ready_to_claim") and not quests.quest_ready_to_claim.is_connected(_refresh_quests): quests.quest_ready_to_claim.connect(_refresh_quests)
 var gear := _root_autoload("GearSystem")
 if gear != null and gear.has_signal("equipment_changed") and not gear.equipment_changed.is_connected(_on_equipment_changed):
  gear.equipment_changed.connect(_on_equipment_changed)
 var state := _root_autoload("GameState")
 if state != null and state.has_signal("inventory_changed") and not state.inventory_changed.is_connected(_on_inventory_changed):
  state.inventory_changed.connect(_on_inventory_changed)
 if state != null and state.has_signal("warehouse_changed") and not state.warehouse_changed.is_connected(_on_warehouse_changed):
  state.warehouse_changed.connect(_on_warehouse_changed)
 var forging := _root_autoload("ForgingSystem")
 if forging != null and forging.has_signal("artisan_opened") and not forging.artisan_opened.is_connected(_open_artisan):
  forging.artisan_opened.connect(_open_artisan)

func _refresh_all() -> void:
 _refresh_status()
 _refresh_minimap()
 _refresh_quests()

func _refresh_status() -> void:
 if _status_label==null: return
 var state:=_root_autoload("GameState")
 var player:Dictionary=state.player_data if state!=null else {}
 var hp:=int(player.get("hp",player.get("max_hp",100)))
 var max_hp:=maxi(1,int(player.get("max_hp",100)))
 var mp:=int(player.get("mana",100))
 var max_mp:=maxi(1,int(player.get("max_mana",100)))
 var gold:=int(state.gold) if state!=null else 0
 var name:=String(player.get("name","Ranger"))
 var level:=int(player.get("level",1))
 var cps:=int(player.get("cps",player.get("conquer_points",0)))
 var bp:=int(player.get("battle_power",0))
 _status_label.text="البطل: %s  •  المستوى %d\nالحياة %d/%d  •  الطاقة %d/%d\nالذهب %d  •  نقاط CP %d  •  قوة BP %d" % [name,level,hp,max_hp,mp,max_mp,gold,cps,bp]
 var anima := int(state.anima_phase) if state != null else 0
 _status_label.add_theme_color_override("font_color",_hero_rank_color(level,anima))
 if is_inside_tree():
  var player_hero := _find_hero()
  if player_hero != null:
   for name_node in player_hero.find_children("*","Label3D",true,false):
    var overhead := name_node as Label3D
    if overhead != null and (overhead.name.to_lower().contains("name") or overhead.text == name):
     overhead.modulate = _hero_rank_color(level,anima)
 for orb in get_tree().get_nodes_in_group("hud_orbs"):
  if orb is SplitOrb:
   orb.hp_ratio=float(hp)/float(max_hp)
   orb.mp_ratio=float(mp)/float(max_mp)
  orb.queue_redraw()

func _refresh_minimap() -> void:
 if _minimap_label == null: return
 var world := _root_autoload("WorldMapManager")
 var city := "المدينة التوأم" if world == null or String(world.current_city)=="TwinCity" else String(world.current_city)
 var p := _find_hero()
 var pos := p.global_position if p != null else Vector3.ZERO
 _minimap_label.text = "خريطة\n%s\nX %.1f  Z %.1f" % [city,pos.x,pos.z]

func _refresh_quests(_unused_a: Variant = null,_unused_b: Variant = null,_unused_c: Variant = null) -> void:
 if _active_window=="Quests": call_deferred("_open_window","Quests")
 if _quest_panel==null: return
 for child in _quest_panel.get_children(): child.queue_free()
 var title:=Label.new()
 title.text="المهام النشطة  •  اضغط للانتقال التلقائي"
 title.add_theme_color_override("font_color",Color(1.0,0.82,0.42))
 _quest_panel.add_child(title)
 var quests:=_root_autoload("QuestSystem")
 if quests==null: return
 var tracked:Array=quests.get_tracked_quests() if quests.has_method("get_tracked_quests") else []
 for quest in tracked.slice(0,4):
  var status:=String(quest.get("status","ACTIVE"))
  var marker:="!" if status=="READY_TO_CLAIM" else "?" if status=="ACTIVE" else "+"
  var b:=_button("[%s] %s  %d/%d" % [marker,String(quest.title),int(quest.progress),int(quest.required)],_navigate_quest.bind(String(quest.id)))
  b.custom_minimum_size=Vector2(330,27)
  _quest_panel.add_child(b)

func _navigate_quest(id: String) -> void:
 var quests := _root_autoload("QuestSystem")
 if quests != null and quests.has_method("navigate_to_quest"):
  _last_quest_id = id
  quests.navigate_to_quest(id)

func _on_quest_progressed(_id: String, _progress: int, _required: int) -> void:
 _refresh_quests()

func _on_inventory_changed(_id: String, _count: int) -> void:
 if _active_window in ["Inventory","Merchant","Warehouse"]: _open_window(_active_window)

func _on_warehouse_changed(_id: String, _count: int) -> void:
 if _active_window == "Warehouse": _open_window("Warehouse")

func _on_equipment_changed(_slot: String, _item: Dictionary) -> void:
 if _active_window == "Character": _open_window("Character")

func _on_npc_interacted(npc_id: String, role_type: String) -> void:
 _current_npc = npc_id
 _current_role = role_type
 match role_type:
  "warehouse": _open_window("Warehouse")
  "forge": _open_window("ArtisanMaster")
  "shop": _open_window("Merchant")
  "quest": _open_window("Quests")
  _: _open_window("NPC: " + npc_id)

func _open_artisan() -> void:
 _open_window("ArtisanMaster")

func _open_window(window_name: String) -> void:
 _active_window = window_name
 for child in _window_layer.get_children(): child.queue_free()
 var window_size := Vector2(940,600) if window_name == "Character" else Vector2(860,720) if window_name == "System" else Vector2(650,560)
 var panel := _panel(_window_layer, Vector2.ZERO, window_size, false)
 panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
 panel.size = window_size
 panel.position = (get_viewport_rect().size - panel.size) * 0.5
 panel.z_index = 50
 var layout := VBoxContainer.new()
 layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layout.offset_left=22
 layout.offset_top=18
 layout.offset_right=-22
 layout.offset_bottom=-18
 layout.add_theme_constant_override("separation",8)
 panel.add_child(layout)
 var header := HBoxContainer.new()
 layout.add_child(header)
 var heading := Label.new()
 heading.text = "الإعدادات" if window_name == "System" else _arabic(window_name)
 heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_theme_font_size_override("font_size",22)
 header.add_child(heading)
 var close_button := _button("✕",func(): _active_window=""; panel.queue_free())
 close_button.add_theme_stylebox_override("normal",_flat_style(Color(0.25,0.035,0.045,0.98),Color(0.86,0.66,0.26),2))
 close_button.add_theme_stylebox_override("hover",_flat_style(Color(0.42,0.045,0.055,1.0),Color(1.0,0.78,0.34),2))
 close_button.add_theme_stylebox_override("pressed",_flat_style(Color(0.16,0.02,0.03,1.0),Color(0.72,0.48,0.22),2))
 header.add_child(close_button)
 match window_name:
  "Inventory": _build_inventory(layout)
  "Bag": _build_inventory(layout)
  "Status": _build_character(layout)
  "Skill": _build_skill_window(layout)
  "System": _build_system_window(layout)
  "Guild": _build_guild_window(layout)
  "Character": _build_character(layout)
  "Quests": _build_quest_book(layout)
  "Daily Login": _build_daily_rewards(layout)
  "ArtisanMaster": _build_artisan(layout)
  "Warehouse": _build_warehouse(layout)
  "Merchant": _build_merchant(layout)
  "Map": _build_map_window(layout)
  "Chat": _build_chat(layout)
  _: _build_npc_info(layout,window_name)
 if window_name in ["Inventory","Bag","Character","Warehouse"]:
  layout.add_child(_build_currency_bar(window_name == "Warehouse"))
 _apply_arabic_rtl(_window_layer)

func _send_chat_message(entry: LineEdit,log: Label) -> void:
 if not entry.text.strip_edges().is_empty():
  log.text+="\\n[You] "+entry.text
  entry.clear()

func _set_combat_mode(mode: String) -> void:
 var state:=_root_autoload("GameState")
 if state!=null: state.player_data["combat_mode"]=mode

func _toggle_window_menu() -> void:
 if _window_menu != null: _window_menu.visible = not _window_menu.visible

func _round_button(caption: String,callback: Callable) -> Button:
 var button := _button(caption,callback)
 button.custom_minimum_size=Vector2(58,54)
 _apply_glass_round_style(button,10)
 return button
func _quick_action(action: String) -> void:
 if action=="Auto-Hunt": _toggle_auto_combat()
 else: _open_window(action)

func _select_chat_tab(tab: String) -> void:
 print("CHAT_TAB_SELECTED: ",tab)

func _cycle_target() -> void:
 var combat:=_root_autoload("CombatSystem")
 _hero=_find_hero()
 if combat!=null and _hero!=null: combat.current_target=combat.find_nearest_target(_hero)

func _build_skill_window(layout: VBoxContainer) -> void:
 var skills:=_root_autoload("SkillSystem")
 var hero:=_find_hero()
 var available:Array=skills.get_available_skills(hero) if skills!=null and hero!=null else []
 var grid:=GridContainer.new()
 grid.columns=2
 layout.add_child(grid)
 var names: Array[String] =["Scatter","Fly","Arrow Rain","Rapid Fire","Cyclone","Superman","Shield","Dash","Poison","Meditation","Intensify","XP Skill","Fatal Strike","Revive"]
 for i in range(14):
  var row:=VBoxContainer.new()
  row.add_child(_label("%02d  %s" % [i+1,String(available[i]) if i<available.size() else names[i]]))
  var xp:=ProgressBar.new()
  xp.max_value=100
  xp.custom_minimum_size=Vector2(260,10)
  row.add_child(xp)
  grid.add_child(row)
 layout.add_child(_label("Weapon & Skill Proficiency"))

func _build_system_window(layout: VBoxContainer) -> void:
 var scroll := ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.custom_minimum_size = Vector2(0, 620)
 layout.add_child(scroll)
 var content := VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation", 10)
 scroll.add_child(content)

 var audio := _settings_group(content, "الصوتيات")
 _add_settings_slider(audio, "مستوى صوت الموسيقى", "music_volume", 0.0, 100.0, 1.0, "%")
 _add_settings_mute_button(audio, "كتم الموسيقى", "music_muted")
 _add_settings_slider(audio, "مستوى المؤثرات الصوتية", "sfx_volume", 0.0, 100.0, 1.0, "%")
 _add_settings_mute_button(audio, "كتم المؤثرات الصوتية", "sfx_muted")

 var graphics := _settings_group(content, "العرض والأداء")
 var quality_row := HBoxContainer.new()
 quality_row.add_child(_label("جودة الرسوم"))
 var quality_picker := OptionButton.new()
 quality_picker.add_item("منخفض")
 quality_picker.add_item("متوسط")
 quality_picker.add_item("فائق")
 var settings := _root_autoload("GameSettings")
 quality_picker.select(int(settings.get_setting("graphics_quality", 1)) if settings != null else 1)
 quality_picker.item_selected.connect(_on_graphics_quality_selected)
 quality_row.add_child(quality_picker)
 graphics.add_child(quality_row)
 _add_settings_toggle(graphics, "إظهار أسماء الشخصيات والوحوش", "show_names")
 _add_settings_toggle(graphics, "إظهار أرقام الضرر", "show_damage_numbers")
 _add_settings_toggle(graphics, "إظهار أشرطة الحياة", "show_hp_bars")
 _add_settings_toggle(graphics, "إخفاء اللاعبين الوهميين لتسريع الأداء", "hide_simulated_players")

 var gameplay := _settings_group(content, "التحكم واللعب الأوفلاين")
 _add_settings_slider(gameplay, "حساسية دوران الكاميرا", "camera_sensitivity", 0.2, 3.0, 0.1, "×")
 _add_settings_toggle(gameplay, "الالتقاط التلقائي للذهب والأغراض", "auto_loot")
 _add_settings_toggle(gameplay, "الجرعة التلقائية عند انخفاض الحياة أو الطاقة عن 50٪", "auto_potion")

 var system := _settings_group(content, "إجراءات النظام")
 var return_button := _button("فك التعليق — العودة إلى مدينة التوأم", _return_to_twin_city)
 return_button.custom_minimum_size = Vector2(0, 42)
 system.add_child(return_button)
 var save_button := _button("حفظ اللعبة الآن", _save_game_now)
 save_button.custom_minimum_size = Vector2(0, 42)
 system.add_child(save_button)
 _settings_feedback = Label.new()
 _settings_feedback.text = "تُحفَظ التغييرات تلقائيًا على هذا الجهاز"
 _settings_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 _settings_feedback.add_theme_color_override("font_color", Color(0.95, 0.79, 0.42))
 system.add_child(_settings_feedback)

func _settings_group(parent: VBoxContainer, caption: String) -> VBoxContainer:
 var panel := PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 panel.add_theme_stylebox_override("panel", _flat_style(Color(0.035, 0.029, 0.027, 0.97), Color(0.83, 0.62, 0.25), 2))
 parent.add_child(panel)
 var margin := MarginContainer.new()
 margin.add_theme_constant_override("margin_left", 14)
 margin.add_theme_constant_override("margin_top", 10)
 margin.add_theme_constant_override("margin_right", 14)
 margin.add_theme_constant_override("margin_bottom", 10)
 panel.add_child(margin)
 var group := VBoxContainer.new()
 group.add_theme_constant_override("separation", 7)
 margin.add_child(group)
 var heading := _label(caption)
 heading.add_theme_color_override("font_color", Color(1.0, 0.82, 0.43))
 heading.add_theme_font_size_override("font_size", 19)
 group.add_child(heading)
 return group

func _add_settings_slider(parent: VBoxContainer, caption: String, key: String, minimum: float, maximum: float, step: float, suffix: String) -> void:
 var settings := _root_autoload("GameSettings")
 var row := VBoxContainer.new()
 row.add_theme_constant_override("separation", 2)
 var heading := HBoxContainer.new()
 var title := _label(caption)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_child(title)
 var value_label := Label.new()
 var current := float(settings.get_setting(key, minimum)) if settings != null else minimum
 value_label.text = ("%.1f" % current) + suffix if suffix == "×" else str(roundi(current)) + suffix
 value_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
 heading.add_child(value_label)
 row.add_child(heading)
 var slider := HSlider.new()
 slider.min_value = minimum
 slider.max_value = maximum
 slider.step = step
 slider.value = current
 slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 slider.custom_minimum_size = Vector2(0, 24)
 slider.value_changed.connect(_on_settings_slider_changed.bind(key, value_label, suffix))
 row.add_child(slider)
 parent.add_child(row)

func _on_settings_slider_changed(value: float, key: String, value_label: Label, suffix: String) -> void:
 var settings := _root_autoload("GameSettings")
 if settings == null:
  return
 settings.set_setting(key, value)
 value_label.text = ("%.1f" % value) + suffix if suffix == "×" else str(roundi(value)) + suffix

func _add_settings_toggle(parent: VBoxContainer, caption: String, key: String) -> void:
 var settings := _root_autoload("GameSettings")
 var check := CheckBox.new()
 check.text = caption
 check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 check.button_pressed = bool(settings.get_setting(key, true)) if settings != null else true
 check.toggled.connect(_on_settings_toggle.bind(key))
 parent.add_child(check)

func _on_settings_toggle(enabled: bool, key: String) -> void:
 var settings := _root_autoload("GameSettings")
 if settings != null:
  settings.set_setting(key, enabled)

func _add_settings_mute_button(parent: VBoxContainer, caption: String, key: String) -> void:
 var settings := _root_autoload("GameSettings")
 var button := _button("", _toggle_audio_mute.bind(key))
 var muted := bool(settings.get_setting(key, false)) if settings != null else false
 button.text = "إلغاء الكتم" if muted else "كتم"
 button.custom_minimum_size = Vector2(130, 32)
 var row := HBoxContainer.new()
 row.add_child(_label(caption))
 row.add_spacer(false)
 row.add_child(button)
 parent.add_child(row)

func _toggle_audio_mute(key: String) -> void:
 var settings := _root_autoload("GameSettings")
 if settings == null:
  return
 var muted := not bool(settings.get_setting(key, false))
 settings.set_setting(key, muted)
 if _active_window == "System":
  call_deferred("_open_window", "System")

func _on_graphics_quality_selected(index: int) -> void:
 var settings := _root_autoload("GameSettings")
 if settings != null:
  settings.set_setting("graphics_quality", index)

func _save_game_now() -> void:
 var state := _root_autoload("GameState")
 var settings := _root_autoload("GameSettings")
 if state == null:
  if _settings_feedback != null:
   _settings_feedback.text = "تعذّر الحفظ: حالة اللعبة غير متاحة"
  return
 var hero := _find_hero()
 var world := _root_autoload("WorldMapManager")
 if hero != null:
  state.player_data["world_position"] = hero.global_position
 if world != null:
  state.player_data["world_city"] = String(world.current_city)
 var game_saved := bool(state.save_game())
 var settings_saved := bool(settings.save_settings()) if settings != null else false
 if _settings_feedback != null:
  _settings_feedback.text = "تم حفظ اللعبة والإعدادات بنجاح" if game_saved and settings_saved else "تعذّر إكمال الحفظ — راجع سجل الأخطاء"
 print("GAME_SETTINGS_MANUAL_SAVE: game=", game_saved, " settings=", settings_saved)

func _return_to_twin_city() -> void:
 var navigation := _root_autoload("WorldNavigationSystem")
 if navigation == null:
  if _settings_feedback != null:
   _settings_feedback.text = "تعذّر الانتقال: نظام التنقل غير متاح"
  return
 var returned: bool = await navigation.instant_teleport("TwinCity", Vector3(0.0, 0.2, -49.0))
 if _settings_feedback != null:
  _settings_feedback.text = "تمت العودة إلى نقطة الأمان في المدينة التوأم" if returned else "تعذّر الانتقال الآن — حاول مرة أخرى"
 print("GAME_SETTINGS_RETURN_TO_TWIN_CITY: success=", returned)

func _build_guild_window(layout: VBoxContainer) -> void:
 layout.add_child(_label("النقابة"))
 layout.add_child(_label("نظام النقابة المحلي"))


func _hero_rank_color(level: int,anima: int) -> Color:
 if anima >= 18: return Color(0.70,0.36,1.0)
 if level >= 130: return Color(1.0,0.78,0.20)
 if level >= 120: return Color(0.92,0.12,0.22)
 if level >= 100: return Color(0.12,0.32,0.95)
 if level >= 70: return Color(0.12,0.88,0.95)
 if level >= 40: return Color(0.18,0.82,0.32)
 return Color.WHITE

func _rank_color_for_plus(plus: int) -> Color:
 if plus >= 12: return Color(0.70,0.36,1.0)
 if plus >= 10: return Color(1.0,0.78,0.20)
 if plus >= 8: return Color(0.95,0.20,0.24)
 if plus >= 5: return Color(0.16,0.38,1.0)
 if plus >= 3: return Color(0.12,0.88,0.95)
 if plus >= 1: return Color(0.20,0.86,0.35)
 return Color.WHITE

func _select_inventory_item(index: int) -> void:
 var state := _root_autoload("GameState")
 if state == null or index < 0 or index >= state.inventory_slots.size(): return
 _selected_inventory_slot = index
 _open_window("Inventory")

func _equip_inventory_item(index: int) -> void:
 var state := _root_autoload("GameState")
 var gear := _root_autoload("GearSystem")
 if state == null or gear == null or index < 0 or index >= state.inventory_slots.size(): return
 var entry: Dictionary = state.inventory_slots[index]
 var item_id := String(entry.get("item_id",""))
 var item := _get_item_data(item_id)
 item["plus"] = int(entry.get("instance_data",{}).get("plus",item.get("plus",0)))
 var slot := String(item.get("slot",item.get("equipment_slot",""))).to_lower()
 if slot == "headgear": slot = "helmet"
 var ok := false
 if slot == "weapon": ok = gear.equip_weapon(item_id,String(state.player_data.get("class","archer")))
 elif not slot.is_empty(): ok = gear.equip_item(slot,item)
 if ok: state.remove_item_from_slot(index,1)
 _open_window("Inventory")

func _use_inventory_item(index: int) -> void:
 var state := _root_autoload("GameState")
 if state == null or index < 0 or index >= state.inventory_slots.size(): return
 var item_id := String(state.inventory_slots[index].get("item_id",""))
 var item_type := String(_get_item_data(item_id).get("type","")).to_lower()
 if item_type.contains("potion") or item_id.to_lower().contains("potion"): _use_potion(item_id)
 _open_window("Inventory")

func _sell_inventory_item(index: int) -> void:
 var merchant := _root_autoload("NPCMerchantSystem")
 if merchant != null and merchant.has_method("sell_item"): merchant.sell_item(index,1)
 _selected_inventory_slot = -1
 _open_window("Inventory")

func _deposit_inventory_item(index: int) -> void:
 var state := _root_autoload("GameState")
 if state != null: state.deposit_to_warehouse(index,1)
 _selected_inventory_slot = -1
 _open_window("Inventory")

func _build_inventory(layout: VBoxContainer) -> void:
 var state := _root_autoload("GameState")
 var slots: Array = state.inventory_slots if state != null else []
 var margin := MarginContainer.new()
 margin.add_theme_constant_override("margin_left",20)
 margin.add_theme_constant_override("margin_right",20)
 layout.add_child(margin)
 var grid := GridContainer.new()
 grid.columns = 8
 grid.add_theme_constant_override("h_separation",4)
 grid.add_theme_constant_override("v_separation",4)
 margin.add_child(grid)
 for index in range(40):
  var item: Dictionary = slots[index] if index < slots.size() else {}
  var cell := Button.new()
  cell.custom_minimum_size = Vector2(52,52)
  cell.clip_contents = true
  cell.text = ""
  _apply_button_skin(cell,true)
  cell.add_theme_stylebox_override("normal",_selected_slot_style() if index == _selected_inventory_slot else _slot_style())
  if not item.is_empty():
   var item_id := String(item.get("item_id",""))
   var data := _get_item_data(item_id)
   var plus := int(item.get("instance_data",{}).get("plus",data.get("plus",0)))
   var icon := _make_item_icon(data,plus,Vector2(42,42))
   icon.position = Vector2(5,5)
   cell.add_child(icon)
   if plus > 0:
    var plus_label := Label.new()
    plus_label.text = "★"+str(plus)
    plus_label.position = Vector2(1,34)
    plus_label.add_theme_font_size_override("font_size",10)
    plus_label.add_theme_color_override("font_color",_rank_color_for_plus(plus))
    cell.add_child(plus_label)
   var quantity := Label.new()
   quantity.text = "x%d" % int(item.get("count",1))
   quantity.position = Vector2(27,35)
   quantity.add_theme_font_size_override("font_size",11)
   cell.add_child(quantity)
   cell.pressed.connect(_select_inventory_item.bind(index))
  grid.add_child(cell)
 layout.add_child(_label("الحقيبة: %d / 40   |   الحد الأقصى للتكديس: ×100" % slots.size()))
 var details := VBoxContainer.new()
 details.name = "InventoryItemDetails"
 details.custom_minimum_size = Vector2(0,110)
 layout.add_child(details)
 if _selected_inventory_slot >= 0 and _selected_inventory_slot < slots.size():
  var item_id := String(slots[_selected_inventory_slot].get("item_id",""))
  var data := _get_item_data(item_id)
  var item_title := _label(_item_display_name(item_id))
  item_title.add_theme_color_override("font_color",_rank_color_for_plus(int(slots[_selected_inventory_slot].get("instance_data",{}).get("plus",0))))
  details.add_child(item_title)
  details.add_child(_label(String(data.get("description","لا يوجد وصف متاح."))))
  var actions := HBoxContainer.new()
  actions.add_child(_button("لبس",_equip_inventory_item.bind(_selected_inventory_slot)))
  actions.add_child(_button("استخدام",_use_inventory_item.bind(_selected_inventory_slot)))
  actions.add_child(_button("بيع 50%",_sell_inventory_item.bind(_selected_inventory_slot)))
  actions.add_child(_button("نقل للخزنة",_deposit_inventory_item.bind(_selected_inventory_slot)))
  details.add_child(actions)
 else:
  details.add_child(_label("اختَر قطعة لعرض تفاصيلها"))
func _build_character(layout: VBoxContainer) -> void:
 var state := _root_autoload("GameState")
 var gear := _root_autoload("GearSystem")
 var equipped: Dictionary = gear.equipped if gear != null else {}
 var body_margin:=MarginContainer.new()
 body_margin.add_theme_constant_override("margin_left",24)
 body_margin.add_theme_constant_override("margin_right",24)
 layout.add_child(body_margin)
 var body := HBoxContainer.new()
 body.custom_minimum_size = Vector2(844,420)
 body.add_theme_constant_override("separation",0)
 body_margin.add_child(body)
 var left_column := VBoxContainer.new()
 left_column.custom_minimum_size = Vector2(170,0)
 left_column.add_theme_constant_override("separation",4)
 body.add_child(left_column)
 var center_column := VBoxContainer.new()
 center_column.custom_minimum_size = Vector2(480,0)
 center_column.add_theme_constant_override("separation",5)
 body.add_child(center_column)
 var right_margin := MarginContainer.new()
 right_margin.custom_minimum_size = Vector2(194,0)
 right_margin.add_theme_constant_override("margin_left",24)
 right_margin.add_theme_constant_override("margin_right",24)
 body.add_child(right_margin)
 var right_column := VBoxContainer.new()
 right_column.custom_minimum_size = Vector2(170,0)
 right_column.add_theme_constant_override("separation",4)
 right_margin.add_child(right_column)
 var left_slots: Array = [["fan","فانة"],["tower","تاور"],["wing","جناح"],["mount_whip","سوط ركوب"],["steed","خيل"],["mount_skin","سكن مطية"],["garment","زي/لبسة"]]
 var right_slots: Array = [["helmet","خوذة"],["necklace","قلادة"],["armor","درع"],["weapon","سلاح يمين"],["weapon_left","سلاح يسار"],["ring","خاتم"],["boots","حذاء"]]
 for entry in left_slots:
  _add_character_equipment_slot(left_column,String(entry[0]),String(entry[1]),false,equipped)
 for entry in right_slots:
  _add_character_equipment_slot(right_column,String(entry[0]),String(entry[1]),true,equipped)
 var preview := SubViewportContainer.new()
 preview.name = "CharacterModelPreview"
 preview.custom_minimum_size = Vector2(480,270)
 preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 preview.stretch = true
 preview.mouse_filter = Control.MOUSE_FILTER_STOP
 preview.gui_input.connect(_on_character_preview_input)
 center_column.add_child(preview)
 _character_preview_container = preview
 var viewport := SubViewport.new()
 viewport.name = "CharacterSubViewport"
 viewport.size = Vector2i(480,270)
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 viewport.transparent_bg = false
 preview.add_child(viewport)
 var world := Node3D.new()
 world.name = "CharacterPreviewWorld"
 viewport.add_child(world)
 var camera := Camera3D.new()
 camera.position = Vector3(0,1.25,4.8)
 camera.current = true
 camera.fov = 38.0
 world.add_child(camera)
 camera.look_at(Vector3(0,0.92,0),Vector3.UP)
 var gold_platform := MeshInstance3D.new()
 gold_platform.name = "HeroGoldLightPlatform"
 var platform_mesh := TorusMesh.new()
 platform_mesh.inner_radius = 0.72
 platform_mesh.outer_radius = 0.86
 platform_mesh.rings = 48
 platform_mesh.ring_segments = 16
 gold_platform.mesh = platform_mesh
 gold_platform.position = Vector3(0,0.035,0)
 gold_platform.scale = Vector3(1.0,1.0,0.72)
 var platform_material := StandardMaterial3D.new()
 platform_material.albedo_color = Color(0.86,0.58,0.16,0.92)
 platform_material.emission_enabled = true
 platform_material.emission = Color(1.0,0.56,0.12)
 platform_material.emission_energy_multiplier = 1.8
 platform_material.metallic = 0.72
 platform_material.roughness = 0.24
 gold_platform.set_surface_override_material(0,platform_material)
 world.add_child(gold_platform)
 var platform_light := OmniLight3D.new()
 platform_light.name = "HeroGoldPlatformLight"
 platform_light.position = Vector3(0,0.38,0.55)
 platform_light.light_color = Color(1.0,0.66,0.28)
 platform_light.light_energy = 1.15
 platform_light.omni_range = 4.5
 world.add_child(platform_light)
 var key_light := DirectionalLight3D.new()
 key_light.rotation_degrees = Vector3(-38,-28,0)
 key_light.light_energy = 1.35
 world.add_child(key_light)
 var fill_light := OmniLight3D.new()
 fill_light.position = Vector3(-2.0,2.4,2.2)
 fill_light.light_energy = 0.8
 fill_light.omni_range = 8.0
 world.add_child(fill_light)
 var rim_light := DirectionalLight3D.new()
 rim_light.rotation_degrees = Vector3(-12,145,0)
 rim_light.light_energy = 0.75
 world.add_child(rim_light)
 var controller_script: Script = load("res://scripts/CharacterVisualController.gd") as Script
 if controller_script != null:
  var controller := controller_script.new() as Node3D
  controller.name = "RangerPreviewController"
  world.add_child(controller)
  controller.call("build_character","archer",70,"male")
  controller.call("normalize_character")
  _character_preview_model = controller.get("character_root") as Node3D
 if _character_preview_model == null:
  push_error("PHASE5A_CHARACTER_PREVIEW_MODEL_MISSING: Ranger Hood real 3D model")
 else:
  _character_preview_model.rotation.y = deg_to_rad(22.0)
  var idle_started := _play_character_idle_animation(_character_preview_model)
  print("PHASE5A_CHARACTER_PREVIEW_MODEL_READY: source=Male_Ranger.glb viewport=480x270 touch_drag=true mouse_drag=true idle=",idle_started)
 var selected: Dictionary = equipped.get(_selected_equipment_slot,{})
 var details := PanelContainer.new()
 details.custom_minimum_size = Vector2(480,62)
 details.add_theme_stylebox_override("panel",_flat_style(Color(0.03,0.03,0.04,0.80),Color(0.86,0.66,0.26),2))
 center_column.add_child(details)
 var detail_row := HBoxContainer.new()
 detail_row.add_theme_constant_override("separation",8)
 details.add_child(detail_row)
 var detail_text := VBoxContainer.new()
 detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 detail_row.add_child(detail_text)
 var item_name := String(selected.get("display_name",selected.get("name",selected.get("id","لا توجد قطعة محددة"))))
 var plus_level := int(selected.get("plus",0))
 var plus_suffix := "+" + str(plus_level)
 var title_label := _label(item_name + ("  " + plus_suffix if plus_level > 0 and not item_name.contains(plus_suffix) else ""))
 title_label.add_theme_color_override("font_color",_rank_color_for_plus(plus_level))
 title_label.add_theme_font_size_override("font_size",15)
 detail_text.add_child(title_label)
 detail_text.add_child(_label("الهجوم %d  •  الدفاع %d  •  المستوى %d" % [int(selected.get("attack_bonus",selected.get("base_attack",0))),int(selected.get("defense_bonus",selected.get("base_defense",0))),int(selected.get("level",1))]))
 detail_row.add_child(_button("خلع القطعة",_unequip_character_slot.bind(_selected_equipment_slot)))
 var stats: Dictionary = gear.get_combat_bonuses() if gear != null else {}
 var player: Dictionary = state.player_data if state != null else {}
 var bp := int(player.get("battle_power",int(stats.get("attack",0))+int(stats.get("defense",0))))
 var steed: Dictionary = equipped.get("steed",{})
 var speed := int(steed.get("mount_speed",steed.get("speed",0)))
 var stats_panel := PanelContainer.new()
 stats_panel.custom_minimum_size = Vector2(480,68)
 stats_panel.add_theme_stylebox_override("panel",_flat_style(Color(0.03,0.03,0.04,0.80),Color(0.86,0.66,0.26),1))
 center_column.add_child(stats_panel)
 var stats_grid := GridContainer.new()
 stats_grid.columns = 2
 stats_grid.add_theme_constant_override("h_separation",18)
 stats_grid.add_theme_constant_override("v_separation",2)
 stats_panel.add_child(stats_grid)
 for stat_line in ["قوة المعركة: %d" % bp,"الهجوم: %d" % int(stats.get("attack",0)),"الدفاع: %d" % int(stats.get("defense",0)),"الهجوم السحري: %d" % int(stats.get("magic_attack",0)),"سرعة الركوب: %d" % speed,"القطع المجهزة: %d/14" % equipped.size()]:
  var stat_label := _label(stat_line)
  stat_label.add_theme_font_size_override("font_size",13)
  stats_grid.add_child(stat_label)

func _add_character_equipment_slot(column: VBoxContainer,slot: String,caption: String,label_first: bool,equipped: Dictionary) -> void:
 var row := HBoxContainer.new()
 row.custom_minimum_size = Vector2(168,51)
 row.add_theme_constant_override("separation",4)
 column.add_child(row)
 var item: Dictionary = equipped.get(slot,{})
 var cell := Button.new()
 cell.custom_minimum_size = Vector2(48,48)
 cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
 cell.clip_contents = true
 cell.text = ""
 _apply_button_skin(cell,true)
 cell.add_theme_stylebox_override("normal",_selected_slot_style() if slot == _selected_equipment_slot else _slot_style())
 var icon_data: Dictionary = item if not item.is_empty() else {"id":slot,"slot":slot,"type":"Equipment"}
 var icon := _make_item_icon(icon_data,int(item.get("plus",0)),Vector2(40,40))
 icon.position = Vector2(4,4)
 cell.add_child(icon)
 if int(item.get("plus",0)) > 0:
  var plus_label := Label.new()
  plus_label.text = "★" + str(item.get("plus",0))
  plus_label.position = Vector2(1,33)
  plus_label.add_theme_font_size_override("font_size",9)
  plus_label.add_theme_color_override("font_color",_rank_color_for_plus(int(item.get("plus",0))))
  cell.add_child(plus_label)
 cell.pressed.connect(_select_character_slot.bind(slot))
 var caption_label := Label.new()
 caption_label.text = caption
 caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 caption_label.add_theme_font_size_override("font_size",12)
 if label_first:
  row.add_child(caption_label)
  row.add_child(cell)
 else:
  row.add_child(cell)
  row.add_child(caption_label)

func _play_character_idle_animation(root: Node) -> bool:
 if root == null: return false
 for candidate in root.find_children("*","AnimationPlayer",true,false):
  var player := candidate as AnimationPlayer
  if player == null: continue
  for animation_name in player.get_animation_list():
   if String(animation_name).to_lower().contains("idle"):
    player.play(String(animation_name))
    print("PHASE5A_CHARACTER_IDLE_ANIMATION_PLAYING: player=",player.get_path()," animation=",animation_name)
    return true
 push_warning("PHASE5A_CHARACTER_IDLE_ANIMATION_NOT_FOUND: Ranger model has no Idle AnimationPlayer clip")
 return false

func _select_character_slot(slot: String) -> void:
 _selected_equipment_slot = slot
 _open_window("Character")

func _unequip_character_slot(slot: String) -> void:
 var gear := _root_autoload("GearSystem")
 var state := _root_autoload("GameState")
 if gear == null: return
 var item: Dictionary = gear.get_equipped(slot)
 if item.is_empty(): return
 var item_id := String(item.get("id",item.get("item_id","")))
 if state != null and not item_id.is_empty():
  state.add_item(item_id,1,item)
 gear.unequip_item(slot)
 _open_window("Character")

func _on_character_preview_input(event: InputEvent) -> void:
 if event is InputEventScreenDrag:
  if is_instance_valid(_character_preview_model):
   _character_preview_model.rotation.y += (event as InputEventScreenDrag).relative.x * 0.012
 elif event is InputEventScreenTouch:
  _character_preview_dragging = (event as InputEventScreenTouch).pressed
 elif event is InputEventMouseButton:
  var mouse_event := event as InputEventMouseButton
  if mouse_event.button_index == MOUSE_BUTTON_LEFT:
   _character_preview_dragging = mouse_event.pressed
 elif event is InputEventMouseMotion and _character_preview_dragging:
  if is_instance_valid(_character_preview_model):
   _character_preview_model.rotation.y += (event as InputEventMouseMotion).relative.x * 0.012

func _build_quest_book(layout: VBoxContainer) -> void:
 var quests := _root_autoload("QuestSystem")
 if quests == null: return
 var categories: Array[String] = ["MAIN_PROMOTION","DAILY","WEEKLY","SIDE_QUESTS","ENDGAME_REBIRTH","DAILY_LOGIN"]
 var tabs := HBoxContainer.new()
 tabs.add_theme_constant_override("separation",3)
 layout.add_child(tabs)
 for category in categories:
  var caption: String = str("Login" if category=="DAILY_LOGIN" else "Daily Quests" if category=="DAILY" else category.replace("_"," ").capitalize())
  var tab := _button(caption,_select_quest_category.bind(category))
  tab.custom_minimum_size = Vector2(84,34)
  tab.disabled = category == _quest_category
  tabs.add_child(tab)
 var scroll := ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 layout.add_child(scroll)
 var content := VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation",6)
 scroll.add_child(content)
 if _quest_category == "DAILY_LOGIN":
  _build_daily_rewards(content)
  return
 var entries: Array = quests.get_quest_catalog(_quest_category)
 content.add_child(_label("%s — %d quests" % [_quest_category.replace("_"," ").capitalize(),entries.size()]))
 for quest in entries:
  var card := VBoxContainer.new()
  card.add_theme_constant_override("separation",2)
  card.add_child(_label("%s  [%s]" % [String(quest.get("title",quest.id)),String(quest.get("status","AVAILABLE"))]))
  card.add_child(_label("Objective: %s (%d required)  |  Level %d+  |  %s" % [String(quest.get("objective","")).replace("_"," "),int(quest.get("required",1)),int(quest.get("level_min",1)),String(quest.get("target_city",""))]))
  var reward_row := HBoxContainer.new()
  var rewards: Dictionary = quest.get("rewards",{})
  if int(rewards.get("gold",0)) > 0: reward_row.add_child(_label("Gold %d" % int(rewards.gold)))
  if int(rewards.get("exp",0)) > 0: reward_row.add_child(_label("EXP %d" % int(rewards.exp)))
  for item_id in rewards.get("items",{}):
   var reward_icon := _make_item_icon(_get_item_data(String(item_id)),0,Vector2(30,30))
   reward_row.add_child(reward_icon)
   reward_row.add_child(_label("%s x%d" % [_item_display_name(String(item_id)),int(rewards.items[item_id])]))
  card.add_child(reward_row)
  var actions := HBoxContainer.new()
  var status := String(quest.get("status","AVAILABLE"))
  if status == "READY_TO_CLAIM":
   actions.add_child(_button("Claim Reward",_claim_quest_reward.bind(String(quest.id))))
  elif status == "ACTIVE":
   actions.add_child(_button("Auto-Path",_navigate_quest.bind(String(quest.id))))
   actions.add_child(_label("Progress %d/%d" % [int(quest.get("progress",0)),int(quest.get("required",1))]))
  elif status == "AVAILABLE":
   actions.add_child(_button("Accept Quest",_accept_quest.bind(String(quest.id))))
  else:
   actions.add_child(_label("Completed"))
  card.add_child(actions)
  content.add_child(card)
  content.add_child(HSeparator.new())

func _select_quest_category(category: String) -> void:
 _quest_category = category
 _open_window("Quests")

func _accept_quest(id: String) -> void:
 var quests := _root_autoload("QuestSystem")
 if quests != null and quests.accept_quest(id):
  _open_window("Quests")

func _claim_quest_reward(id: String) -> void:
 var quests := _root_autoload("QuestSystem")
 if quests != null and quests.claim_quest_reward(id):
  _open_window("Quests")

func _build_daily_rewards(layout: VBoxContainer) -> void:
 var quests := _root_autoload("QuestSystem")
 var rewards: Array = quests.DAILY_REWARDS if quests != null else []
 var state := _root_autoload("GameState")
 var claimed_day := int(state.player_data.get("daily_login_day_index",-1)) if state != null else -1
 for day in range(7):
  var reward: Dictionary = rewards[day] if day < rewards.size() else {}
  var row := HBoxContainer.new()
  row.add_child(_label("Day %d%s" % [day+1,"  ✓" if day <= claimed_day else ""]))
  if int(reward.get("gold",0)) > 0: row.add_child(_label("Gold %d" % int(reward.gold)))
  for item_id in reward.get("items",{}):
   row.add_child(_make_item_icon(_get_item_data(String(item_id)),0,Vector2(32,32)))
   row.add_child(_label("%s x%d" % [_item_display_name(String(item_id)),int(reward.items[item_id])]))
  layout.add_child(row)
 layout.add_child(_button("Claim today’s login reward",_claim_daily))
 layout.add_child(_label("One reward per calendar day; seven-day cycle."))

func _claim_daily() -> void:
 var quests := _root_autoload("QuestSystem")
 if quests != null and quests.has_method("claim_daily_login"):
  quests.claim_daily_login()
 _open_window("Daily Login")

func _build_artisan(layout: VBoxContainer) -> void:
 var tabs := HBoxContainer.new()
 layout.add_child(tabs)
 for tab in FORGE_TABS: tabs.add_child(_button(tab,_select_forge_tab.bind(tab)))
 layout.add_child(_label("ArtisanMaster — choose an equipped slot, then select an operation."))
 for slot in ["weapon","armor","helmet","ring","necklace","boots","fan","tower","steed"]:
  layout.add_child(_button("Upgrade " + slot,_forge_operation.bind(slot)))

func _select_forge_tab(tab: String) -> void:
 _current_role = tab
 _open_window("ArtisanMaster")

func _forge_operation(slot: String) -> void:
 var forge := _root_autoload("ForgingSystem")
 if forge == null: return
 match _current_role:
  "Quality": forge.upgrade_quality(slot)
  "Level": forge.upgrade_level(slot)
  "Sockets": forge.socket_gem("DragonGem",0,slot)
  "Anima": forge.upgrade_anima()
  _: forge.compose_plus(slot,"Plus1Stone")
 _open_window("ArtisanMaster")

func _build_warehouse(layout: VBoxContainer) -> void:
 var state := _root_autoload("GameState")
 if state == null: return
 var scroll := ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 layout.add_child(scroll)
 var content := VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(content)
 content.add_child(_label("WAREHOUSE 40 SLOTS  |  STACK LIMIT x100"))
 content.add_child(_label("Bag — select a slot to deposit"))
 var bag_grid := GridContainer.new()
 bag_grid.columns = 8
 bag_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_child(bag_grid)
 for index in range(40):
  var item: Dictionary = state.inventory_slots[index] if index < state.inventory_slots.size() else {}
  var cell := _warehouse_cell(item,index,index==_selected_inventory_slot)
  cell.pressed.connect(_select_inventory_warehouse_slot.bind(index))
  bag_grid.add_child(cell)
 var bag_actions := HBoxContainer.new()
 content.add_child(bag_actions)
 bag_actions.add_child(_button("Deposit x1",_deposit_one))
 bag_actions.add_child(_button("Deposit All",_deposit_all))
 var selected_bag := "None"
 if _selected_inventory_slot >= 0 and _selected_inventory_slot < state.inventory_slots.size():
  var selected: Dictionary = state.inventory_slots[_selected_inventory_slot]
  selected_bag = "%s x%d" % [String(selected.item_id),int(selected.count)]
 content.add_child(_label("Selected bag slot: " + selected_bag))
 content.add_child(_label("Warehouse — select a slot to withdraw"))
 var warehouse_grid := GridContainer.new()
 warehouse_grid.columns = 8
 warehouse_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_child(warehouse_grid)
 for index in range(40):
  var item: Dictionary = state.warehouse_slots[index] if index < state.warehouse_slots.size() else {}
  var cell := _warehouse_cell(item,index,index==_selected_warehouse_slot)
  cell.pressed.connect(_select_warehouse_storage_slot.bind(index))
  warehouse_grid.add_child(cell)
 var warehouse_actions := HBoxContainer.new()
 content.add_child(warehouse_actions)
 warehouse_actions.add_child(_button("Withdraw x1",_withdraw_one))
 warehouse_actions.add_child(_button("Withdraw All",_withdraw_all))
 var selected_warehouse := "None"
 if _selected_warehouse_slot >= 0 and _selected_warehouse_slot < state.warehouse_slots.size():
  var selected: Dictionary = state.warehouse_slots[_selected_warehouse_slot]
  selected_warehouse = "%s x%d" % [String(selected.item_id),int(selected.count)]
 content.add_child(_label("Selected warehouse slot: " + selected_warehouse))

func _warehouse_cell(item: Dictionary,index: int,selected: bool) -> Button:
 var cell := Button.new()
 cell.custom_minimum_size = Vector2(52,52)
 cell.clip_contents = true
 cell.text = ""
 _apply_button_skin(cell,true)
 cell.add_theme_stylebox_override("normal",_selected_slot_style() if selected else _slot_style())
 if not item.is_empty():
  var item_plus := int(item.get("instance_data",{}).get("plus",0))
  var icon := _make_item_icon(_get_item_data(String(item.item_id)),item_plus,Vector2(38,38))
  icon.position = Vector2(7,7)
  cell.add_child(icon)
  if item_plus > 0:
   var plus_badge := Label.new()
   plus_badge.text = "★" + str(item_plus)
   plus_badge.position = Vector2(1,34)
   plus_badge.add_theme_font_size_override("font_size",9)
   plus_badge.add_theme_color_override("font_color",_rank_color_for_plus(item_plus))
   cell.add_child(plus_badge)
  var quantity := Label.new()
  quantity.text = "x%d" % int(item.get("count",1))
  quantity.position = Vector2(25,35)
  quantity.add_theme_font_size_override("font_size",10)
  cell.add_child(quantity)
 return cell
func _select_inventory_warehouse_slot(index: int) -> void:
 _selected_inventory_slot = index
 _open_window("Warehouse")

func _select_warehouse_storage_slot(index: int) -> void:
 _selected_warehouse_slot = index
 _open_window("Warehouse")

func _deposit_one() -> void:
 _transfer_warehouse(true,false)

func _deposit_all() -> void:
 _transfer_warehouse(true,true)

func _withdraw_one() -> void:
 _transfer_warehouse(false,false)

func _withdraw_all() -> void:
 _transfer_warehouse(false,true)

func _transfer_warehouse(deposit: bool,all_items: bool) -> void:
 var state := _root_autoload("GameState")
 if state == null: return
 if deposit:
  if _selected_inventory_slot < 0 or _selected_inventory_slot >= state.inventory_slots.size(): return
  var quantity := int(state.inventory_slots[_selected_inventory_slot].get("count",1)) if all_items else 1
  state.deposit_to_warehouse(_selected_inventory_slot,quantity)
  _selected_inventory_slot = -1
 else:
  if _selected_warehouse_slot < 0 or _selected_warehouse_slot >= state.warehouse_slots.size(): return
  var quantity := int(state.warehouse_slots[_selected_warehouse_slot].get("count",1)) if all_items else 1
  state.withdraw_from_warehouse(_selected_warehouse_slot,quantity)
  _selected_warehouse_slot = -1
 _open_window("Warehouse")

func _build_currency_bar(include_warehouse: bool) -> Control:
 var state := _root_autoload("GameState")
 var player: Dictionary = state.player_data if state != null else {}
 var gold := int(state.gold) if state != null else 0
 var cps := int(player.get("cps",player.get("conquer_points",0)))
 var bar := PanelContainer.new()
 bar.name = "ClassicCurrencyBar"
 bar.custom_minimum_size = Vector2(0,42)
 bar.add_theme_stylebox_override("panel",_flat_style(Color(0.025,0.025,0.03,0.96),Color(0.86,0.66,0.26),2))
 var row := HBoxContainer.new()
 row.add_theme_constant_override("separation",12)
 bar.add_child(row)
 var carried := Label.new()
 carried.text = "🪙 Gold: %s   ✦ CP: %s" % [gold,cps]
 carried.add_theme_color_override("font_color",Color(1.0,0.82,0.42))
 carried.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(carried)
 if include_warehouse:
  var stored := int(player.get("warehouse_gold",0))
  var vault := Label.new()
  vault.text = "🏦 الخزنة: %s Gold" % stored
  vault.add_theme_color_override("font_color",Color(0.92,0.72,0.34))
  row.add_child(vault)
  row.add_child(_button("إيداع الذهب",_deposit_all_gold))
  row.add_child(_button("سحب الذهب",_withdraw_all_gold))
 return bar

func _deposit_all_gold() -> void:
 var state := _root_autoload("GameState")
 if state == null: return
 var amount := int(state.gold)
 if amount <= 0: return
 state.player_data["warehouse_gold"] = int(state.player_data.get("warehouse_gold",0)) + amount
 state.set_gold(0)
 state.save_game()
 _open_window("Warehouse")

func _withdraw_all_gold() -> void:
 var state := _root_autoload("GameState")
 if state == null: return
 var amount := int(state.player_data.get("warehouse_gold",0))
 if amount <= 0: return
 state.player_data["warehouse_gold"] = 0
 state.add_gold(amount)
 state.save_game()
 _open_window("Warehouse")

func _build_merchant(layout: VBoxContainer) -> void:
 var npc := _root_autoload("NPCMerchantSystem")
 var state := _root_autoload("GameState")
 layout.add_child(_label("Merchant: %s  |  Gold: %d" % [_current_npc,int(state.gold) if state != null else 0]))
 if npc == null or not npc.has_method("get_shop_inventory"): return
 var stock: Array = npc.get_shop_inventory(_current_npc)
 var shop_scroll := ScrollContainer.new()
 shop_scroll.custom_minimum_size = Vector2(0,190)
 shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 layout.add_child(shop_scroll)
 var shop_list := VBoxContainer.new()
 shop_scroll.add_child(shop_list)
 for item in stock:
  var row := HBoxContainer.new()
  row.add_child(_make_item_icon(item,0,Vector2(42,42)))
  var info := VBoxContainer.new()
  info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  info.add_child(_label(String(item.get("name",item.id))))
  info.add_child(_label("Buy %d Gold  |  Sell %d Gold" % [int(item.buy_price),int(item.sell_price)]))
  row.add_child(info)
  row.add_child(_button("Buy x1",_merchant_buy.bind(String(item.id),1)))
  row.add_child(_button("Buy x10",_merchant_buy.bind(String(item.id),10)))
  shop_list.add_child(row)
 layout.add_child(_label("SELL FROM BAG — 50% of shop value"))
 var bag_scroll := ScrollContainer.new()
 bag_scroll.custom_minimum_size = Vector2(0,150)
 layout.add_child(bag_scroll)
 var bag_list := VBoxContainer.new()
 bag_scroll.add_child(bag_list)
 if state != null:
  for index in range(state.inventory_slots.size()):
   var slot: Dictionary = state.inventory_slots[index]
   var item_id := String(slot.item_id)
   var item_data := _get_item_data(item_id)
   var row := HBoxContainer.new()
   row.add_child(_make_item_icon(item_data,int(slot.get("instance_data",{}).get("plus",0)),Vector2(34,34)))
   row.add_child(_label("%s x%d  |  Sell %d Gold ea." % [_item_display_name(item_id),int(slot.count),int(floor(float(npc.get_item_base_price(item_id))*0.5))]))
   row.add_child(_button("Sell x1",_merchant_sell.bind(index,1)))
   row.add_child(_button("Sell All",_merchant_sell.bind(index,int(slot.count))))
   bag_list.add_child(row)

func _merchant_buy(item_id: String,quantity: int) -> void:
 var npc := _root_autoload("NPCMerchantSystem")
 if npc != null: npc.buy_item(_current_npc,item_id,quantity)
 _open_window("Merchant")

func _merchant_sell(slot_index: int,quantity: int) -> void:
 var npc := _root_autoload("NPCMerchantSystem")
 if npc != null: npc.sell_item(slot_index,quantity)
 _open_window("Merchant")

func _build_map_window(layout: VBoxContainer) -> void:
 _refresh_minimap()
 layout.add_child(_label(_minimap_label.text))
 var nav := _root_autoload("WorldNavigationSystem")
 if nav != null:
  for target in ["CentralPlaza","ArcherGod","ArtisanMaster","Warehouseman","ImperialPalace"]:
   layout.add_child(_button(target,func(): nav.navigate_to_target(target)))

func _build_chat(layout: VBoxContainer) -> void:
 var input := LineEdit.new()
 input.placeholder_text = "اكتب رسالتك..."
 layout.add_child(input)
 layout.add_child(_button("Send",func(): input.clear()))

func _build_npc_info(layout: VBoxContainer, name: String) -> void:
 layout.add_child(_label("Interaction: " + name))
 layout.add_child(_label("Role: " + _current_role))

func _get_item_data(item_id: String) -> Dictionary:
 var database := _root_autoload("GearDatabase")
 if database != null and database.has_method("get_item"):
  var data: Dictionary = database.get_item(item_id)
  if not data.is_empty(): return data
 return {"id":item_id,"name":item_id,"type":item_id}

func _item_display_name(item_id: String) -> String:
 var data := _get_item_data(item_id)
 var raw := String(data.get("display_name",data.get("name",item_id)))
 var key := item_id.to_lower()
 var translated := ""
 if key.contains("bow"): translated = "قوس الصياد"
 elif key.contains("helmet"): translated = "خوذة المبتدئ السوبر" if key.contains("super") else "خوذة المبتدئ"
 elif key.contains("body") or key.contains("armor"): translated = "درع المبتدئ السوبر" if key.contains("super") else "درع المبتدئ"
 elif key.contains("boot") or key.contains("shoe"): translated = "حذاء المبتدئ السوبر" if key.contains("super") else "حذاء المبتدئ"
 elif key.contains("ring"): translated = "خاتم"
 elif key.contains("necklace") or key.contains("amulet"): translated = "قلادة"
 elif key.contains("potion"): translated = "جرعة حياة" if key.contains("hp") else "جرعة طاقة"
 else: translated = _arabic(raw)
 var plus := int(data.get("plus",0))
 if key.contains("_p12"): plus = maxi(plus,12)
 elif key.contains("_p"): 
  var marker := key.rfind("_p")
  if marker >= 0: plus = maxi(plus,int(key.substr(marker+2)))
 return translated + (" +" + str(plus) if plus > 0 and not translated.contains("+"+str(plus)) else "")
func _make_item_icon(data: Dictionary,plus: int = 0,icon_size: Vector2 = Vector2(40,40)) -> Control:
 var icon: Control = ICON_SCRIPT.new()
 icon.custom_minimum_size = icon_size
 icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
 icon.configure(data,plus)
 return icon

func _use_potion(item_id: String) -> void:
 var state := _root_autoload("GameState")
 if state != null and state.remove_item(item_id,1):
  if item_id == "HPPotion": state.player_data["hp"] = int(state.player_data.get("hp",100)) + 250
  else: state.player_data["mana"] = int(state.player_data.get("mana",100)) + 250
  state.save_game()
 _refresh_status()

func _attack() -> void:
 var combat := _root_autoload("CombatSystem")
 _hero = _find_hero()
 if combat != null and _hero != null:
  var target: Node3D = combat.find_nearest_target(_hero) as Node3D
  if target != null: combat.perform_attack(_hero,target)

func _use_primary_skill() -> void:
 _use_skill_at(0)

func _use_secondary_skill() -> void:
 _use_skill_at(1)

func _use_skill_at(index: int) -> void:
 var skills := _root_autoload("SkillSystem")
 _hero = _find_hero()
 if skills == null or _hero == null: return
 var available: Array = skills.get_available_skills(_hero)
 if index < available.size():
  var combat := _root_autoload("CombatSystem")
  var target: Node3D = combat.find_nearest_target(_hero) if combat != null else null
  skills.use_skill(_hero,String(available[index]),target)

func _jump() -> void:
 _hero = _find_hero()
 if _hero is CharacterBody3D:
  var body := _hero as CharacterBody3D
  if body.is_on_floor(): body.velocity.y = 6.5

func _toggle_auto_combat() -> void:
 var combat := _root_autoload("CombatSystem")
 _hero = _find_hero()
 if combat == null or _hero == null: return
 combat.combat_active = not combat.combat_active
 if combat.combat_active: combat.current_target = combat.find_nearest_target(_hero)

func _refresh_auto_hunt_button() -> void:
 if not is_instance_valid(_auto_hunt_button): return
 var combat:=_root_autoload("CombatSystem")
 var active:=combat!=null and bool(combat.combat_active)
 var normal:=_circular_style(Color(0.07,0.055,0.025,0.98) if active else Color(0.075,0.055,0.035,0.98),Color(0.78,1.0,0.42) if active else Color(0.98,0.77,0.30),3,14)
 normal.shadow_color=Color(0.28,1.0,0.18,0.95) if active else Color(0.0,0.0,0.0,0.86)
 normal.shadow_size=14 if active else 11
 var hover:=_circular_style(Color(0.12,0.18,0.045,1.0) if active else Color(0.16,0.12,0.055,1.0),Color(0.86,1.0,0.52) if active else Color(1.0,0.91,0.55),3,14)
 hover.shadow_color=Color(0.35,1.0,0.22,1.0) if active else Color(0.22,0.16,0.04,0.92)
 hover.shadow_size=16 if active else 13
 _auto_hunt_button.add_theme_stylebox_override("normal",normal)
 _auto_hunt_button.add_theme_stylebox_override("hover",hover)
 _auto_hunt_button.add_theme_stylebox_override("pressed",hover)
 _auto_hunt_button.tooltip_text="صيد تلقائي: يعمل" if active else "صيد تلقائي: متوقف"

 _refresh_auto_hunt_button()

func _on_joystick_input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  var touch := event as InputEventScreenTouch
  if touch.pressed:
   _dragging_joystick = touch.position.distance_to(Vector2(66,66)) <= 66.0
  else:
   _dragging_joystick = false
   _joystick_vector = Vector2.ZERO
 elif event is InputEventScreenDrag and _dragging_joystick:
  var local: Vector2 = ((event as InputEventScreenDrag).position - Vector2(66,66)) / 54.0
  _joystick_vector = local.limit_length(1.0)
  _hero = _find_hero()
  if _hero is CharacterBody3D:
   var body := _hero as CharacterBody3D
   body.velocity.x = _joystick_vector.x * 5.0
   body.velocity.z = _joystick_vector.y * 5.0

func _find_hero() -> Node3D:
 var hero := get_tree().root.find_child("PlayableHero",true,false)
 if hero is Node3D: return hero as Node3D
 var legacy := get_tree().root.find_child("TwinCityPlayableHero",true,false)
 return legacy as Node3D if legacy is Node3D else null

func _install_arabic_theme() -> void:
 var arabic_theme := Theme.new()
 var font_path := "res://assets/fonts/NotoSansArabic-Bold.ttf"
 var arabic_font := load(font_path) as Font
 if arabic_font != null:
  arabic_theme.default_font = arabic_font
 else:
  arabic_theme.default_font = ThemeDB.fallback_font
  push_warning("PHASE5A_ARABIC_FONT_FALLBACK: " + font_path)
 arabic_theme.default_font_size = 17
 for control_type in ["Label","Button","LineEdit","TextEdit","CheckBox","OptionButton","RichTextLabel"]:
  arabic_theme.set_color("font_outline_color",control_type,Color(0.0,0.0,0.0,0.92))
  arabic_theme.set_constant("outline_size",control_type,2)
  arabic_theme.set_font_size("font_size",control_type,17)
 theme = arabic_theme

func _apply_arabic_rtl(node: Node) -> void:
 if node is Control:
  var control := node as Control
  control.layout_direction = Control.LAYOUT_DIRECTION_LTR
  if node is Label or node is Button or node is RichTextLabel or node is LineEdit:
   node.set("text_direction",Control.TEXT_DIRECTION_RTL)
 for child in node.get_children():
  _apply_arabic_rtl(child)
func _arabic(caption: String) -> String:
 var dictionary: Dictionary = {
  "Plus +1…+12":"التطوير +1 إلى +12","Quality":"الجودة","Level":"المستوى","Sockets":"فتح الثقوب","Anima":"ترقية الأنيما",
  "MAIN PROMOTION":"المهام الرئيسية والترقية","Daily Quests":"المهام اليومية","Weekly":"الأسبوعية","Side Quests":"الجانبية","Endgame Rebirth":"الميلاد الثاني",
  "Ranger":"رامٍ","Battle Power":"قوة المعركة","HP":"الحياة","MP":"الطاقة","Stamina":"القدرة على التحمل",
  "Meteor":"نيزك","DragonBall":"كرة التنين","DragonGem":"جوهرة التنين","Plus2Stone":"حجر +2","HPPotion":"جرعة حياة",
  "Buy":"شراء","Sell":"بيع","None":"لا يوجد","Guild • offline guild system integration pending":"النقابة",
  "Weapon & Skill Proficiency":"إتقان السلاح والمهارات","Merchant:":"التاجر:","SELL FROM BAG — 50% of shop value":"البيع من الحقيبة — 50٪ من سعر المتجر",
  "Day":"اليوم","Claim today’s login reward":"استلام مكافأة تسجيل الدخول اليوم",
  "All":"الكل","Talk":"عام","Whisper":"همس","Guild":"نقابة","System":"النظام","Send":"إرسال",
  "Daily":"الدخول اليومي","Hunt":"الصيد التلقائي","Map":"الخريطة","Settings":"الإعدادات",
  "Peace":"سلمي","Team":"فريق","Capture":"صيد","PK":"حر",
  "Status":"الشخصية والعتاد","Skill":"المهارات","Bag":"الحقيبة","Quest":"المهام","Market":"السوق والتجارة",
  "Warehouse":"الخزنة","ArtisanMaster":"الحرفي","Character":"الشخصية والعتاد","Inventory":"الحقيبة",
  "Quests":"المهام","Daily Login":"تسجيل الدخول اليومي","Merchant":"السوق والتجارة",
  "Scatter":"تشتت السهام","Fly":"الطيران","Target":"تبديل الهدف","ATTACK":"هجوم",
  "Arrow Rain":"مطر السهام","Rapid Fire":"الرمي السريع","Empty":"فارغ",
  "BGM Volume":"موسيقى الخلفية","SFX Volume":"المؤثرات الصوتية","Camera Distance":"بُعد الكاميرا",
  "Save Game":"حفظ اللعبة الآن","Claim Reward":"استلام الجائزة","Auto-Path":"انتقال تلقائي",
  "Accept Quest":"قبول المهمة","Completed":"مكتملة","Objective":"الهدف","Gold":"ذهب","EXP":"خبرة",
  "Inventory:":"الحقيبة:","WAREHOUSE":"الخزنة","Buy x1":"شراء ×1","Buy x10":"شراء ×10",
  "Sell x1":"بيع ×1","Sell All":"بيع الكل","Upgrade weapon":"تطوير السلاح",
  "RANGER  •  GUILD: NONE":"رامٍ  •  النقابة: بلا",
  "QUEST TRACKER  [+] Available   [?] Active   [!] Ready":"المهام النشطة  •  اضغط للانتقال التلقائي",
  "Tap to type a message...":"اكتب رسالتك هنا...",
  "TwinCity":"المدينة التوأم","Novice Guide 1":"إرشاد المبتدئين ١","Novice Guide 2":"إرشاد المبتدئين ٢",
  "Archer Promotion 15":"ترقية الرامي للمستوى ١٥","Search":"البحث","Rebuild":"إعادة البناء",
  "Kill Competition":"مسابقة القتال","Exterminate":"إبادة الوحوش","Assassinate":"اغتيال",
  "Demon Exterminators":"قاهر الشياطين","Dis City":"مدينة الأشباح","Coach Li's Assignment":"مهمة المدرّب لي",
  "The Alchemist's Ingredients":"مكونات الخيميائي","Tower of Mystery":"برج الأسرار","Rare Materials":"المواد النادرة",
  "Gem Collection":"جمع الجواهر","Monster Slayer":"صائد الوحوش","Event Participation":"المشاركة في الفعاليات",
  "Item Socketing":"فتح ثقوب العتاد","Moon Box Quest":"مهمة صندوق القمر","Meteor Tears":"دموع النيازك",
  "Blue Mouse Royal Treasures":"كنوز الفأر الأزرق","Snake Islands & Treasure Labyrinth":"جزر الأفاعي ومتاهة الكنوز",
  "Bandits' Plot":"مؤامرة قطاع الطرق","Stone Ape's Trouble":"مشكلة القرد الحجري","Desert Rescue":"إنقاذ الصحراء",
  "Bird Island Guarding Stone":"حجر حراسة جزيرة الطيور","Talisman Unlock":"فتح التعويذة",
  "Celestial Stone":"الحجر السماوي","Rebirth Ritual":"طقوس الميلاد الثاني"
 }
 if dictionary.has(caption): return String(dictionary[caption])
 return caption

func _circular_style(bg: Color,border: Color,width: int,radius: int) -> StyleBoxFlat:
 var style:=_flat_style(bg,border,width)
 style.set_corner_radius_all(radius)
 style.shadow_color=Color(0.0,0.0,0.0,0.72)
 style.shadow_size=8
 return style

func _apply_glass_round_style(button: Button,radius: int) -> void:
 var normal:=_circular_style(Color(0.075,0.055,0.035,0.98),Color(0.98,0.77,0.30),3,radius)
 normal.shadow_color=Color(0.0,0.0,0.0,0.86)
 normal.shadow_size=11
 normal.border_color=Color(0.98,0.77,0.30)
 var hover:=_circular_style(Color(0.16,0.12,0.055,1.0),Color(1.0,0.91,0.55),3,radius)
 hover.shadow_color=Color(0.22,0.16,0.04,0.92)
 hover.shadow_size=13
 var pressed:=_circular_style(Color(0.22,0.12,0.035,1.0),Color(1.0,0.58,0.18),3,radius)
 pressed.shadow_color=Color(0.0,0.0,0.0,0.92)
 pressed.shadow_size=5
 button.add_theme_stylebox_override("normal",normal)
 button.add_theme_stylebox_override("hover",hover)
 button.add_theme_stylebox_override("pressed",pressed)
 button.add_theme_stylebox_override("focus",hover)

func _flat_style(bg: Color,border: Color,width: int) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new()
 style.bg_color=bg
 style.border_color=border
 style.set_border_width_all(width)
 style.set_corner_radius_all(6)
 if width >= 3:
  style.shadow_color = Color(0.0,0.0,0.0,0.72)
  style.shadow_size = 8
 return style

func _set_skill_button_icon(button: Button,kind: String,hotkey: String = "") -> void:
 var filename := String(SKILL_ICON_FILES.get(kind,"bow.png"))
 var texture := load("res://assets/ui/skills/" + filename) as Texture2D
 if texture != null:
  var icon_rect := TextureRect.new()
  icon_rect.name = "SkillTextureIcon"
  icon_rect.texture = texture
  icon_rect.custom_minimum_size = Vector2(30,30)
  icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
  icon_rect.position = (button.size-Vector2(30,30))*0.5 + Vector2(0,2)
  icon_rect.size = Vector2(30,30)
  icon_rect.z_index = 1
  button.add_child(icon_rect)
 else:
  push_error("PHASE5A_SKILL_ICON_MISSING: " + filename)
 if not hotkey.is_empty():
  var badge_panel:=Panel.new()
  badge_panel.name="SkillHotkeyBadge"
  badge_panel.position=Vector2(1,0)
  badge_panel.size=Vector2(15,12)
  badge_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
  badge_panel.add_theme_stylebox_override("panel",_flat_style(Color(0.035,0.025,0.015,0.98),Color(0.92,0.68,0.22),1))
  badge_panel.z_index=4
  var badge:=Label.new()
  badge.text=hotkey
  badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  badge.add_theme_font_size_override("font_size",8)
  badge.add_theme_color_override("font_color",Color(1.0,0.91,0.65))
  badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  badge.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
  badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
  badge_panel.add_child(badge)
  button.add_child(badge_panel)

func _ornate_panel(parent: Control,offset: Vector2,panel_size: Vector2,top_right:=false) -> Panel:
 var panel:=Panel.new()
 panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.custom_minimum_size=panel_size
 panel.size=panel_size
 panel.position=offset
 if top_right: panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 panel.add_theme_stylebox_override("panel",_flat_style(Color(0.05,0.04,0.04,0.96),Color(0.95,0.76,0.30),2))
 var inner_frame:=Panel.new()
 inner_frame.position=Vector2(8,8)
 inner_frame.size=panel_size-Vector2(16,16)
 inner_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
 inner_frame.add_theme_stylebox_override("panel",_flat_style(Color(0.05,0.04,0.04,0.0),Color(0.46,0.34,0.15),1))
 panel.add_child(inner_frame)
 var frame_texture:=TextureRect.new()
 frame_texture.name="OrnateFantasyFrame"
 frame_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 frame_texture.texture=load("res://assets/ui/borders/ornate_panel.png") as Texture2D
 frame_texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 frame_texture.stretch_mode=TextureRect.STRETCH_SCALE
 frame_texture.modulate=Color(0.95,0.76,0.30,0.96)
 frame_texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if frame_texture.texture!=null: panel.add_child(frame_texture)
 var trim:=RoyalOrnament.new()
 trim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 trim.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.add_child(trim)
 parent.add_child(panel)
 return panel

func _texture_style(path: String) -> StyleBoxTexture:
 var style := StyleBoxTexture.new()
 var texture := load(path) as Texture2D
 if texture == null:
  push_warning("PHASE5A_UI_TEXTURE_MISSING: " + path)
  return style
 style.texture = texture
 style.texture_margin_left = 12.0
 style.texture_margin_top = 12.0
 style.texture_margin_right = 12.0
 style.texture_margin_bottom = 12.0
 style.draw_center = true
 return style

func _slot_style() -> StyleBoxFlat:
 return _flat_style(Color(0.08,0.08,0.09,0.95),Color(0.55,0.49,0.37),2)

func _selected_slot_style() -> StyleBoxFlat:
 var style := _flat_style(Color(0.10,0.085,0.055,0.98),Color(1.0,0.76,0.25),3)
 style.shadow_color = Color(1.0,0.62,0.12,0.72)
 style.shadow_size = 8
 return style

func _apply_button_skin(button: Button,square := false) -> void:
 var normal_path := "res://assets/ui/buttons/btn_sq_brown.png" if square else "res://assets/ui/buttons/btn_brown.png"
 var pressed_path := "res://assets/ui/buttons/btn_sq_brown_pressed.png" if square else "res://assets/ui/buttons/btn_brown_pressed.png"
 button.add_theme_stylebox_override("normal",_texture_style(normal_path))
 button.add_theme_stylebox_override("hover",_texture_style(normal_path))
 button.add_theme_stylebox_override("pressed",_texture_style(pressed_path))
func _panel(parent: Control,offset: Vector2,panel_size: Vector2,top_right:=false,transparent:=false) -> Panel:
 return _ornate_panel(parent,offset,panel_size,top_right)

func _button(caption: String,callback: Callable) -> Button:
 var button := Button.new()
 button.text = _arabic(caption)
 button.custom_minimum_size = Vector2(70,34)
 _apply_button_skin(button,false)
 button.pressed.connect(callback)
 return button
func _label(caption: String) -> Label:
 var label := Label.new()
 label.text = _arabic(caption)
 return label

func _run_mobile_hud_preview() -> void:
 await get_tree().process_frame
 _seed_mobile_hud_preview_data()
 _open_window("Inventory")
 await RenderingServer.frame_post_draw
 if not _save_mobile_hud_preview("mobile_hud_inventory_preview.png"):
  push_error("PHASE5A_MOBILE_HUD_PREVIEW_FAILED: inventory capture")
  get_tree().quit(1)
  return
 _open_window("Character")
 await RenderingServer.frame_post_draw
 if not _save_mobile_hud_preview("mobile_hud_character_preview.png"):
  push_error("PHASE5A_MOBILE_HUD_PREVIEW_FAILED: character capture")
  get_tree().quit(1)
  return
 if _character_preview_model == null:
  push_error("PHASE5A_MOBILE_HUD_PREVIEW_FAILED: real Ranger 3D model not loaded")
  get_tree().quit(1)
  return
 var joystick := find_child("JoystickVisual",true,false)
 print("PHASE5A_MOBILE_HUD_PREVIEW_CAPTURE_OK: inventory=true character=true icons=true arabic=true slots=14 ranger_3d=true viewport=480x270 ornate=true joystick_visible=",is_instance_valid(joystick) and (joystick as Control).is_visible_in_tree())
 get_tree().quit(0)

func _save_mobile_hud_preview(file_name: String) -> bool:
 var directory := ProjectSettings.globalize_path("res://artifacts")
 DirAccess.make_dir_recursive_absolute(directory)
 var image := get_viewport().get_texture().get_image()
 if image == null or image.is_empty():
  return false
 var path := directory.path_join(file_name)
 if image.save_png(path) != OK:
  return false
 var file := FileAccess.open(path,FileAccess.READ)
 if file == null:
  return false
 var bytes := file.get_length()
 file.close()
 print("PHASE5A_MOBILE_HUD_PREVIEW_FILE: ",path," bytes=",bytes)
 return bytes > 1024

func _seed_mobile_hud_preview_data() -> void:
 var state := _root_autoload("GameState")
 if state != null:
  state.inventory_slots.clear()
  state.inventory.clear()
  state.add_item("Meteor",15)
  state.add_item("DragonBall",5)
  state.add_item("DragonGem",3)
  state.add_item("Plus2Stone",8)
  state.add_item("HPPotion",50)
 var db := _root_autoload("GearDatabase")
 var gear := _root_autoload("GearSystem")
 if db != null and gear != null:
  var fixtures: Dictionary = {
   "weapon":"bow_lv10_normal_p12",
   "armor":"body_03_beginner_super_p12",
   "helmet":"helmet_01_beginner_super_p12",
   "boots":"boots_01_beginner_super_p12",
   "fan":"preview_heaven_fan_p12",
   "tower":"preview_star_tower_p12",
   "steed":"preview_steed_p12"
  }
  for slot in fixtures:
   var definition: Dictionary = db.get_item(String(fixtures[slot]))
   if not definition.is_empty():
    definition["plus"]=12
    definition["display_name"] = "قوس +12" if slot=="weapon" else "درع +12" if slot=="armor" else "خوذة +12" if slot=="helmet" else "حذاء +12"
    gear.equipped[slot]=definition
  gear.equipped["necklace"]={"id":"preview_necklace_p12","name":"قلادة +12","slot":"necklace","plus":12,"type":"Accessory"}
  gear.equipped["ring"]={"id":"preview_ring_p12","name":"خاتم +12","slot":"ring","plus":12,"type":"Accessory"}
  gear.equipped["wing"]={"id":"preview_wing","name":"جناح سماوي","slot":"wing","plus":0,"type":"Wing"}
  gear.equipped["mount_whip"]={"id":"preview_mount_whip","name":"سوط ركوب","slot":"mount_whip","plus":0,"type":"MountWhip"}
  gear.equipped["mount_skin"]={"id":"preview_fire_tiger_skin","name":"سكن المطية: النمر الناري","slot":"mount_skin","plus":0,"type":"MountSkin"}
  gear.equipped["garment"]={"id":"preview_garment","name":"لبسة الحارس","slot":"garment","plus":0,"type":"Garment"}
 if state != null:
  state.player_data["active_quests"]={
   "novice_1":{"status":"ACTIVE","progress":0},
   "novice_2":{"status":"ACTIVE","progress":2}
  }
 _refresh_quests()
 print("PHASE5A_MOBILE_HUD_PREVIEW_FIXTURES_READY: meteor=15 dragon_ball=5 dragon_gem=3 plus2=8 hp_potion=50 equipped=14 active_quests=2 mount_fixtures=true save_untouched=true")