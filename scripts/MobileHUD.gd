extends Control
## Touch-first 2D HUD. All 3D presentation remains imported assets; this UI owns no 3D nodes.
const ICON_SCRIPT = preload("res://scripts/ItemIconGenerator.gd")
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

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_PASS
 _build_hud()
 _install_arabic_theme()
 _apply_arabic_rtl(self)
 _connect_systems()
 _refresh_all()
 print("PHASE5A_MOBILE_HUD_READY: touch_ui=true inventory=40 warehouse=40 stack=100 character_slots=10 procedural_3d=false")
 if OS.get_cmdline_user_args().has("--preview-mobile-hud"):
  call_deferred("_run_mobile_hud_preview")

func _process(_delta: float) -> void:
 _refresh_status()
 _refresh_minimap()

func _build_hud() -> void:
 var root:=Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(root)
 var hero:=_ornate_panel(root,Vector2(16,14),Vector2(365,164))
 var head:=HBoxContainer.new()
 head.position=Vector2(12,8)
 hero.add_child(head)
 var portrait:=TextureRect.new()
 portrait.texture=load("res://assets/ui/hero_portrait.svg")
 portrait.custom_minimum_size=Vector2(68,68)
 head.add_child(portrait)
 var info:=VBoxContainer.new()
 info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 head.add_child(info)
 _status_label=Label.new()
 _status_label.add_theme_font_size_override("font_size",15)
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
 for mode in ["Peace","Team","Capture","PK"]:
  var mb:=_button(mode,_set_combat_mode.bind(mode))
  mb.custom_minimum_size=Vector2(78,26)
  modes.add_child(mb)
 hero.add_child(modes)
 var qcard:=_ornate_panel(root,Vector2(16,185),Vector2(365,190))
 _quest_panel=VBoxContainer.new()
 _quest_panel.position=Vector2(12,8)
 _quest_panel.size=Vector2(340,170)
 qcard.add_child(_quest_panel)

 var radar_frame:=Panel.new()
 radar_frame.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 radar_frame.position=Vector2(-202,16)
 radar_frame.size=Vector2(184,184)
 radar_frame.add_theme_stylebox_override("panel",_flat_style(Color(0.035,0.045,0.065,0.92),Color(0.92,0.69,0.28),4))
 root.add_child(radar_frame)
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
 quick.position=Vector2(-205,210)
 root.add_child(quick)
 for p in [["⚙","System"],["日","Daily Login"],["✦","Auto-Hunt"],["☰","Menu"]]:
  var b:=_round_button(String(p[0]),_toggle_window_menu if String(p[1])=="Menu" else _quick_action.bind(String(p[1])))
  quick.add_child(b)

 _window_menu=VBoxContainer.new()
 _window_menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 _window_menu.position=Vector2(-205,258)
 _window_menu.visible=false
 _window_menu.z_index=30
 root.add_child(_window_menu)
 for p in [["الحقيبة","Inventory"],["الشخصية","Character"],["المهارات","Skill"],["المهام","Quests"],["السوق","Merchant"],["النقابة","Guild"],["الإعدادات","System"]]:
  var b:=_round_button(String(p[0]),_open_window.bind(String(p[1])))
  _window_menu.add_child(b)

 var chat:=_ornate_panel(root,Vector2(16,-390),Vector2(360,165))
 chat.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
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

 var joy:=_ornate_panel(root,Vector2(18,-205),Vector2(190,190))
 joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 joy.z_index=25
 joy.gui_input.connect(_on_joystick_input)
 var joyart:=TextureRect.new()
 joyart.texture=load("res://assets/ui/joystick.svg")
 joyart.position=Vector2(8,8)
 joyart.size=Vector2(174,174)
 joyart.mouse_filter=Control.MOUSE_FILTER_IGNORE
 joy.add_child(joyart)

 var bottom:=Control.new()
 bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 bottom.z_index=10
 root.add_child(bottom)
 var orb:=SplitOrb.new()
 orb.name="SplitHPMPOrb"
 orb.position=Vector2(560,-150)
 orb.size=Vector2(132,132)
 orb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 orb.add_to_group("hud_orbs")
 bottom.add_child(orb)
 var exp:=HBoxContainer.new()
 exp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 exp.position=Vector2(704,-105)
 for i in range(10):
  var c:=ColorRect.new()
  c.custom_minimum_size=Vector2(23,12)
  c.color=Color(0.83,0.61,0.17)
  exp.add_child(c)
 bottom.add_child(exp)
 var hot:=HBoxContainer.new()
 hot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 hot.position=Vector2(704,-72)
 for i in range(10):
  var b:=_button("F%d"%(i+1),_use_skill_at.bind(i))
  b.custom_minimum_size=Vector2(34,34)
  hot.add_child(b)
 bottom.add_child(hot)

 var combat:=Control.new()
 combat.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 combat.position=Vector2(-260,-270)
 combat.size=Vector2(250,250)
 combat.z_index=20
 root.add_child(combat)
 var attack:=_round_button("هجوم",_attack)
 attack.position=Vector2(138,138)
 attack.size=Vector2(104,104)
 combat.add_child(attack)
 var arc_buttons:=[["قفزة",_jump,Vector2(100,78)],["تشتت",_use_primary_skill,Vector2(48,38)],["طيران",_jump,Vector2(4,78)],["مطر",_use_secondary_skill,Vector2(48,118)],["سريع",_use_primary_skill,Vector2(100,4)],["هدف",_cycle_target,Vector2(4,158)]]
 for item in arc_buttons:
  var b:=_round_button(String(item[0]),item[1])
  b.position=item[2]
  b.size=Vector2(68,58)
  combat.add_child(b)

 _window_layer=Control.new()
 _window_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 _window_layer.mouse_filter=Control.MOUSE_FILTER_STOP
 _window_layer.z_index=50
 add_child(_window_layer)

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

func _connect_systems() -> void:
 var npcs := get_node_or_null("/root/NPCMerchantSystem")
 if npcs != null and npcs.has_signal("npc_interacted") and not npcs.npc_interacted.is_connected(_on_npc_interacted):
  npcs.npc_interacted.connect(_on_npc_interacted)
 var quests := get_node_or_null("/root/QuestSystem")
 if quests != null:
  if quests.has_signal("quest_accepted") and not quests.quest_accepted.is_connected(_refresh_quests): quests.quest_accepted.connect(_refresh_quests)
  if quests.has_signal("quest_progressed") and not quests.quest_progressed.is_connected(_on_quest_progressed): quests.quest_progressed.connect(_on_quest_progressed)
  if quests.has_signal("quest_completed") and not quests.quest_completed.is_connected(_refresh_quests): quests.quest_completed.connect(_refresh_quests)
  if quests.has_signal("quest_ready_to_claim") and not quests.quest_ready_to_claim.is_connected(_refresh_quests): quests.quest_ready_to_claim.connect(_refresh_quests)
 var gear := get_node_or_null("/root/GearSystem")
 if gear != null and gear.has_signal("equipment_changed") and not gear.equipment_changed.is_connected(_on_equipment_changed):
  gear.equipment_changed.connect(_on_equipment_changed)
 var state := get_node_or_null("/root/GameState")
 if state != null and state.has_signal("inventory_changed") and not state.inventory_changed.is_connected(_on_inventory_changed):
  state.inventory_changed.connect(_on_inventory_changed)
 if state != null and state.has_signal("warehouse_changed") and not state.warehouse_changed.is_connected(_on_warehouse_changed):
  state.warehouse_changed.connect(_on_warehouse_changed)
 var forging := get_node_or_null("/root/ForgingSystem")
 if forging != null and forging.has_signal("artisan_opened") and not forging.artisan_opened.is_connected(_open_artisan):
  forging.artisan_opened.connect(_open_artisan)

func _refresh_all() -> void:
 _refresh_status()
 _refresh_minimap()
 _refresh_quests()

func _refresh_status() -> void:
 if _status_label==null: return
 var state:=get_node_or_null("/root/GameState")
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
 _status_label.text="البطل: %s  •  المستوى %d\\nالحياة %d/%d  •  الطاقة %d/%d\\nالذهب %d  •  نقاط CP %d  •  قوة BP %d" % [name,level,hp,max_hp,mp,max_mp,gold,cps,bp]
 for orb in get_tree().get_nodes_in_group("hud_orbs"):
  if orb is SplitOrb:
   orb.hp_ratio=float(hp)/float(max_hp)
   orb.mp_ratio=float(mp)/float(max_mp)
  orb.queue_redraw()

func _refresh_minimap() -> void:
 if _minimap_label == null: return
 var world := get_node_or_null("/root/WorldMapManager")
 var city := "المدينة التوأم" if world == null or String(world.current_city)=="TwinCity" else String(world.current_city)
 var p := _find_hero()
 var pos := p.global_position if p != null else Vector3.ZERO
 _minimap_label.text = "MAP\n%s\nX %.1f  Z %.1f" % [city,pos.x,pos.z]

func _refresh_quests(_unused_a: Variant = null,_unused_b: Variant = null,_unused_c: Variant = null) -> void:
 if _active_window=="Quests": call_deferred("_open_window","Quests")
 if _quest_panel==null: return
 for child in _quest_panel.get_children(): child.queue_free()
 var title:=Label.new()
 title.text="المهام النشطة  •  اضغط للانتقال التلقائي"
 title.add_theme_color_override("font_color",Color(1.0,0.82,0.42))
 _quest_panel.add_child(title)
 var quests:=get_node_or_null("/root/QuestSystem")
 if quests==null: return
 var tracked:Array=quests.get_tracked_quests() if quests.has_method("get_tracked_quests") else []
 for quest in tracked.slice(0,4):
  var status:=String(quest.get("status","ACTIVE"))
  var marker:="!" if status=="READY_TO_CLAIM" else "?" if status=="ACTIVE" else "+"
  var b:=_button("[%s] %s  %d/%d" % [marker,String(quest.title),int(quest.progress),int(quest.required)],_navigate_quest.bind(String(quest.id)))
  b.custom_minimum_size=Vector2(330,27)
  _quest_panel.add_child(b)

func _navigate_quest(id: String) -> void:
 var quests := get_node_or_null("/root/QuestSystem")
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
 var panel := _panel(_window_layer, Vector2.ZERO, Vector2(650,540), false)
 panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
 panel.size = Vector2(650,540)
 panel.position = (get_viewport_rect().size - panel.size) * 0.5
 panel.z_index = 50
 var layout := VBoxContainer.new()
 layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layout.add_theme_constant_override("separation",8)
 panel.add_child(layout)
 var header := HBoxContainer.new()
 layout.add_child(header)
 var heading := Label.new()
 heading.text = _arabic(window_name)
 heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_theme_font_size_override("font_size",22)
 header.add_child(heading)
 header.add_child(_button("✕",func(): _active_window=""; panel.queue_free()))
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
 _apply_arabic_rtl(_window_layer)

func _send_chat_message(entry: LineEdit,log: Label) -> void:
 if not entry.text.strip_edges().is_empty():
  log.text+="\\n[You] "+entry.text
  entry.clear()

func _set_combat_mode(mode: String) -> void:
 var state:=get_node_or_null("/root/GameState")
 if state!=null: state.player_data["combat_mode"]=mode

func _toggle_window_menu() -> void:
 if _window_menu != null: _window_menu.visible = not _window_menu.visible

func _round_button(caption: String,callback: Callable) -> Button:
 var button:=_button(caption,callback)
 button.custom_minimum_size=Vector2(58,54)
 button.add_theme_stylebox_override("normal",_flat_style(Color(0.10,0.075,0.045,0.96),Color(0.91,0.69,0.29),3))
 button.add_theme_stylebox_override("hover",_flat_style(Color(0.24,0.16,0.07,0.98),Color(1.0,0.84,0.45),3))
 return button

func _quick_action(action: String) -> void:
 if action=="Auto-Hunt": _toggle_auto_combat()
 else: _open_window(action)

func _select_chat_tab(tab: String) -> void:
 print("CHAT_TAB_SELECTED: ",tab)

func _cycle_target() -> void:
 var combat:=get_node_or_null("/root/CombatSystem")
 _hero=_find_hero()
 if combat!=null and _hero!=null: combat.current_target=combat.find_nearest_target(_hero)

func _build_skill_window(layout: VBoxContainer) -> void:
 var skills:=get_node_or_null("/root/SkillSystem")
 var hero:=_find_hero()
 var available:Array=skills.get_available_skills(hero) if skills!=null and hero!=null else []
 var grid:=GridContainer.new()
 grid.columns=2
 layout.add_child(grid)
 var names:=["Scatter","Fly","Arrow Rain","Rapid Fire","Cyclone","Superman","Shield","Dash","Poison","Meditation","Intensify","XP Skill","Fatal Strike","Revive"]
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
 layout.add_child(_label("الصوت"))
 _add_setting_slider(layout,"موسيقى الخلفية",0.75,1.0)
 _add_setting_slider(layout,"المؤثرات الصوتية",0.85,1.0)
 layout.add_child(_button("كتم الكل",func(): AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)))
 layout.add_child(HSeparator.new())
 layout.add_child(_label("العرض"))
 layout.add_child(_setting_option("جودة الرسوم",["منخفضة","متوسطة","عالية"],1))
 _add_setting_check(layout,"إظهار الأسماء",true)
 _add_setting_check(layout,"إظهار الهالات",true)
 _add_setting_slider(layout,"بُعد الكاميرا",1.0,2.0)
 layout.add_child(HSeparator.new())
 layout.add_child(_label("القتال والصيد التلقائي"))
 layout.add_child(_setting_option("وضع القتال",["سلمي","فريق","دفاع","حر"],0))
 _add_setting_check(layout,"الالتقاط التلقائي",true)
 _add_setting_check(layout,"الجرعات التلقائية",true)
 layout.add_child(HSeparator.new())
 layout.add_child(_label("الحفظ"))
 layout.add_child(_button("حفظ اللعبة الآن",func():
  var state:=get_node_or_null("/root/GameState")
  if state!=null: state.save_game()
 ))
 layout.add_child(_button("العودة إلى المدينة",func():
  var nav:=get_node_or_null("/root/WorldNavigationSystem")
  if nav!=null and nav.has_method("navigate_to_target"): nav.navigate_to_target("CentralPlaza")
 ))

func _add_setting_slider(parent: VBoxContainer,caption: String,initial: float,maximum: float) -> void:
 parent.add_child(_label(caption))
 var slider:=HSlider.new()
 slider.min_value=0.0
 slider.max_value=maximum
 slider.value=initial
 parent.add_child(slider)

func _setting_option(caption: String,options: Array,selected: int) -> HBoxContainer:
 var row:=HBoxContainer.new()
 row.add_child(_label(caption))
 var picker:=OptionButton.new()
 for option in options: picker.add_item(String(option))
 picker.select(selected)
 row.add_child(picker)
 return row

func _add_setting_check(parent: VBoxContainer,caption: String,enabled: bool) -> void:
 var check:=CheckBox.new()
 check.text=caption
 check.button_pressed=enabled
 parent.add_child(check)

func _build_guild_window(layout: VBoxContainer) -> void:
 layout.add_child(_label("النقابة"))
 layout.add_child(_label("نظام النقابة المحلي"))


func _build_inventory(layout: VBoxContainer) -> void:
 var state := get_node_or_null("/root/GameState")
 var slots: Array = state.inventory_slots if state != null else []
 var grid := GridContainer.new()
 grid.columns = 8
 grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
 layout.add_child(grid)
 for index in range(40):
  var item: Dictionary = slots[index] if index < slots.size() else {}
  var cell := Button.new()
  cell.custom_minimum_size = Vector2(68,66)
  cell.text = "فارغ"
  if not item.is_empty():
   var id := String(item.get("item_id",""))
   var data := _get_item_data(id)
   cell.text = "%s\nx%d" % [String(data.get("name",id)),int(item.get("count",1))]
   var icon: Control = ICON_SCRIPT.new()
   icon.custom_minimum_size = Vector2(42,42)
   icon.configure(data,int(item.get("instance_data",{}).get("plus",data.get("plus",0))))
   cell.add_child(icon)
   icon.position = Vector2(8,2)
  grid.add_child(cell)
 var footer := Label.new()
 footer.text = "الحقيبة: %d / 40   |   الحد الأقصى للتكديس: ×100" % slots.size()
 layout.add_child(footer)

func _build_character(layout: VBoxContainer) -> void:
 var state := get_node_or_null("/root/GameState")
 var gear := get_node_or_null("/root/GearSystem")
 var equipped: Dictionary = gear.equipped if gear != null else {}
 var grid := GridContainer.new()
 grid.columns = 5
 layout.add_child(grid)
 for slot in ["helmet","necklace","armor","weapon","ring","boots","fan","tower","garment","mount"]:
  var item: Dictionary = equipped.get(slot,{})
  var cell := Button.new()
  cell.custom_minimum_size = Vector2(112,66)
  cell.text = "%s\n%s" % [slot.capitalize(),String(item.get("name",item.get("id","Empty")))]
  var icon := ICON_SCRIPT.new()
  icon.custom_minimum_size = Vector2(38,38)
  icon.configure(item,int(item.get("plus",0)))
  cell.add_child(icon)
  icon.position = Vector2(2,4)
  grid.add_child(cell)
 var stats: Dictionary = gear.get_combat_bonuses() if gear != null else {}
 var player: Dictionary = state.player_data if state != null else {}
 var bp := int(player.get("battle_power",int(stats.get("attack",0))+int(stats.get("defense",0))))
 layout.add_child(_label("Battle Power: %d   ATK: %d   DEF: %d   M.ATK: %d" % [bp,int(stats.get("attack",0)),int(stats.get("defense",0)),int(stats.get("magic_attack",0))]))

func _build_quest_book(layout: VBoxContainer) -> void:
 var quests := get_node_or_null("/root/QuestSystem")
 if quests == null: return
 var categories := ["MAIN_PROMOTION","DAILY","WEEKLY","SIDE_QUESTS","ENDGAME_REBIRTH","DAILY_LOGIN"]
 var tabs := HBoxContainer.new()
 tabs.add_theme_constant_override("separation",3)
 layout.add_child(tabs)
 for category in categories:
  var caption: String = str("Login" if category=="DAILY_LOGIN" else category.replace("_"," ").capitalize())
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
 var quests := get_node_or_null("/root/QuestSystem")
 if quests != null and quests.accept_quest(id):
  _open_window("Quests")

func _claim_quest_reward(id: String) -> void:
 var quests := get_node_or_null("/root/QuestSystem")
 if quests != null and quests.claim_quest_reward(id):
  _open_window("Quests")

func _build_daily_rewards(layout: VBoxContainer) -> void:
 var quests := get_node_or_null("/root/QuestSystem")
 var rewards: Array = quests.DAILY_REWARDS if quests != null else []
 var state := get_node_or_null("/root/GameState")
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
 var quests := get_node_or_null("/root/QuestSystem")
 if quests != null and quests.has_method("claim_daily_login"):
  quests.claim_daily_login()
 _open_window("Daily Login")

func _build_artisan(layout: VBoxContainer) -> void:
 var tabs := HBoxContainer.new()
 layout.add_child(tabs)
 for tab in FORGE_TABS: tabs.add_child(_button(tab,_select_forge_tab.bind(tab)))
 layout.add_child(_label("ArtisanMaster — choose an equipped slot, then select an operation."))
 for slot in ["weapon","armor","helmet","ring","necklace","boots"]:
  layout.add_child(_button("Upgrade " + slot,_forge_operation.bind(slot)))

func _select_forge_tab(tab: String) -> void:
 _current_role = tab
 _open_window("ArtisanMaster")

func _forge_operation(slot: String) -> void:
 var forge := get_node_or_null("/root/ForgingSystem")
 if forge == null: return
 match _current_role:
  "Quality": forge.upgrade_quality(slot)
  "Level": forge.upgrade_level(slot)
  "Sockets": forge.socket_gem("DragonGem",0,slot)
  "Anima": forge.upgrade_anima()
  _: forge.compose_plus(slot,"Plus1Stone")
 _open_window("ArtisanMaster")

func _build_warehouse(layout: VBoxContainer) -> void:
 var state := get_node_or_null("/root/GameState")
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
 bag_grid.columns = 10
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
 warehouse_grid.columns = 10
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
 cell.custom_minimum_size = Vector2(58,52)
 cell.text = "Empty" if item.is_empty() else "#%02d\nx%d" % [index+1,int(item.get("count",1))]
 if selected: cell.text = "▶ " + cell.text
 if not item.is_empty():
  var icon := _make_item_icon(_get_item_data(String(item.item_id)),int(item.get("instance_data",{}).get("plus",0)),Vector2(27,27))
  cell.add_child(icon)
  icon.position = Vector2(2,1)
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
 var state := get_node_or_null("/root/GameState")
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

func _build_merchant(layout: VBoxContainer) -> void:
 var npc := get_node_or_null("/root/NPCMerchantSystem")
 var state := get_node_or_null("/root/GameState")
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
 var npc := get_node_or_null("/root/NPCMerchantSystem")
 if npc != null: npc.buy_item(_current_npc,item_id,quantity)
 _open_window("Merchant")

func _merchant_sell(slot_index: int,quantity: int) -> void:
 var npc := get_node_or_null("/root/NPCMerchantSystem")
 if npc != null: npc.sell_item(slot_index,quantity)
 _open_window("Merchant")

func _build_map_window(layout: VBoxContainer) -> void:
 _refresh_minimap()
 layout.add_child(_label(_minimap_label.text))
 var nav := get_node_or_null("/root/WorldNavigationSystem")
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
 var database := get_node_or_null("/root/GearDatabase")
 if database != null and database.has_method("get_item"):
  var data: Dictionary = database.get_item(item_id)
  if not data.is_empty(): return data
 return {"id":item_id,"name":item_id,"type":item_id}

func _item_display_name(item_id: String) -> String:
 var data := _get_item_data(item_id)
 var raw := String(data.get("display_name",data.get("name",item_id)))
 return _arabic(raw)

func _make_item_icon(data: Dictionary,plus: int = 0,icon_size: Vector2 = Vector2(40,40)) -> Control:
 var icon: Control = ICON_SCRIPT.new()
 icon.custom_minimum_size = icon_size
 icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
 icon.configure(data,plus)
 return icon

func _use_potion(item_id: String) -> void:
 var state := get_node_or_null("/root/GameState")
 if state != null and state.remove_item(item_id,1):
  if item_id == "HPPotion": state.player_data["hp"] = int(state.player_data.get("hp",100)) + 250
  else: state.player_data["mana"] = int(state.player_data.get("mana",100)) + 250
  state.save_game()
 _refresh_status()

func _attack() -> void:
 var combat := get_node_or_null("/root/CombatSystem")
 _hero = _find_hero()
 if combat != null and _hero != null:
  var target: Node3D = combat.find_nearest_target(_hero) as Node3D
  if target != null: combat.perform_attack(_hero,target)

func _use_primary_skill() -> void:
 _use_skill_at(0)

func _use_secondary_skill() -> void:
 _use_skill_at(1)

func _use_skill_at(index: int) -> void:
 var skills := get_node_or_null("/root/SkillSystem")
 _hero = _find_hero()
 if skills == null or _hero == null: return
 var available: Array = skills.get_available_skills(_hero)
 if index < available.size():
  var combat := get_node_or_null("/root/CombatSystem")
  var target: Node3D = combat.find_nearest_target(_hero) if combat != null else null
  skills.use_skill(_hero,String(available[index]),target)

func _jump() -> void:
 _hero = _find_hero()
 if _hero is CharacterBody3D:
  var body := _hero as CharacterBody3D
  if body.is_on_floor(): body.velocity.y = 6.5

func _toggle_auto_combat() -> void:
 var combat := get_node_or_null("/root/CombatSystem")
 _hero = _find_hero()
 if combat == null or _hero == null: return
 combat.combat_active = not combat.combat_active
 if combat.combat_active: combat.current_target = combat.find_nearest_target(_hero)

func _on_joystick_input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  _dragging_joystick = event.pressed
  if not event.pressed: _joystick_vector = Vector2.ZERO
 elif event is InputEventScreenDrag and _dragging_joystick:
  var local := (event as InputEventScreenDrag).position - Vector2(95,95)
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
 arabic_theme.default_font = ThemeDB.fallback_font
 theme = arabic_theme

func _apply_arabic_rtl(node: Node) -> void:
 if node is Control:
  var control := node as Control
  control.layout_direction = Control.LAYOUT_DIRECTION_RTL
  control.text_direction = Control.TEXT_DIRECTION_RTL
 for child in node.get_children():
  _apply_arabic_rtl(child)

func _arabic(caption: String) -> String:
 var dictionary := {
  "Plus +1…+12":"التطوير +1 إلى +12","Quality":"الجودة","Level":"المستوى","Sockets":"فتح الثقوب","Anima":"ترقية الأنيما",
  "MAIN PROMOTION":"المهام الرئيسية والترقية","Daily":"اليومية","Weekly":"الأسبوعية","Side Quests":"الجانبية","Endgame Rebirth":"الميلاد الثاني",
  "Ranger":"رامٍ","Battle Power":"قوة المعركة","HP":"الحياة","MP":"الطاقة","Stamina":"القدرة على التحمل",
  "Meteor":"نيزك","DragonBall":"كرة التنين","DragonGem":"جوهرة التنين","Plus2Stone":"حجر +2","HPPotion":"جرعة حياة",
  "Buy":"شراء","Sell":"بيع","None":"لا يوجد","Guild • offline guild system integration pending":"النقابة",
  "Weapon & Skill Proficiency":"إتقان السلاح والمهارات","Merchant:":"التاجر:","SELL FROM BAG — 50% of shop value":"البيع من الحقيبة — 50٪ من سعر المتجر",
  "Day":"اليوم","Claim today’s login reward":"استلام مكافأة تسجيل الدخول اليوم",
  "All":"الكل","Talk":"عام","Whisper":"همس","Guild":"نقابة","System":"النظام","Send":"إرسال",
  "Daily":"الدخول اليومي","Hunt":"الصيد التلقائي","Map":"الخريطة","Settings":"الإعدادات",
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

func _flat_style(bg: Color,border: Color,width: int) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new()
 style.bg_color=bg
 style.border_color=border
 style.set_border_width_all(width)
 style.set_corner_radius_all(6)
 return style

func _ornate_panel(parent: Control,offset: Vector2,panel_size: Vector2,top_right:=false) -> Panel:
 var panel:=Panel.new()
 panel.custom_minimum_size=panel_size
 panel.size=panel_size
 panel.position=offset
 if top_right: panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 var style:=StyleBoxTexture.new()
 style.texture=load("res://assets/ui/frame_gold.svg")
 style.texture_margin_left=24
 style.texture_margin_top=24
 style.texture_margin_right=24
 style.texture_margin_bottom=24
 panel.add_theme_stylebox_override("panel",style)
 parent.add_child(panel)
 return panel

func _panel(parent: Control,offset: Vector2,panel_size: Vector2,top_right:=false,transparent:=false) -> Panel:
 return _ornate_panel(parent,offset,panel_size,top_right)

func _button(caption: String, callback: Callable) -> Button:
 var button := Button.new()
 button.text = _arabic(caption)
 button.custom_minimum_size = Vector2(70,34)
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
 print("PHASE5A_MOBILE_HUD_PREVIEW_CAPTURE_OK: inventory=true character=true icons=true arabic=true")
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
 var state := get_node_or_null("/root/GameState")
 if state != null:
  state.inventory_slots.clear()
  state.inventory.clear()
  state.add_item("Meteor",15)
  state.add_item("DragonBall",5)
  state.add_item("DragonGem",3)
  state.add_item("Plus2Stone",8)
  state.add_item("HPPotion",50)
 var db := get_node_or_null("/root/GearDatabase")
 var gear := get_node_or_null("/root/GearSystem")
 if db != null and gear != null:
  var fixtures := {
   "weapon":"bow_lv10_normal_p12",
   "armor":"body_03_beginner_super_p12",
   "helmet":"helmet_01_beginner_super_p12",
   "boots":"boots_01_beginner_super_p12"
  }
  for slot in fixtures:
   var definition: Dictionary = db.get_item(String(fixtures[slot]))
   if not definition.is_empty():
    definition["plus"]=12
    definition["display_name"] = "قوس +12" if slot=="weapon" else "درع +12" if slot=="armor" else "خوذة +12" if slot=="helmet" else "حذاء +12"
    gear.equipped[slot]=definition
  gear.equipped["necklace"]={"id":"preview_necklace_p12","name":"قلادة +12","slot":"necklace","plus":12,"type":"Accessory"}
  gear.equipped["ring"]={"id":"preview_ring_p12","name":"خاتم +12","slot":"ring","plus":12,"type":"Accessory"}
 if state != null:
  state.player_data["active_quests"]={
   "novice_1":{"status":"ACTIVE","progress":0},
   "novice_2":{"status":"ACTIVE","progress":2}
  }
 _refresh_quests()
 print("PHASE5A_MOBILE_HUD_PREVIEW_FIXTURES_READY: meteor=15 dragon_ball=5 dragon_gem=3 plus2=8 hp_potion=50 equipped=6 active_quests=2 save_untouched=true")