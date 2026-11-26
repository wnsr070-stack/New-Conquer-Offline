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

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_PASS
 _build_hud()
 _connect_systems()
 _refresh_all()
 print("PHASE5A_MOBILE_HUD_READY: touch_ui=true inventory=40 stack=100 character_slots=10 procedural_3d=false")

func _process(_delta: float) -> void:
 _refresh_status()
 _refresh_minimap()

func _build_hud() -> void:
 var root := Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(root)
 var status := _panel(root, Vector2(16,16), Vector2(330,174))
 var status_box := VBoxContainer.new()
 status_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 status_box.add_theme_constant_override("separation",4)
 status.add_child(status_box)
 _status_label = Label.new()
 _status_label.add_theme_font_size_override("font_size",15)
 status_box.add_child(_status_label)
 _quest_panel = VBoxContainer.new()
 _quest_panel.add_theme_constant_override("separation",3)
 status_box.add_child(_quest_panel)
 var map_panel := _panel(root, Vector2(-246,16), Vector2(230,142), true)
 _minimap_label = Label.new()
 _minimap_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 _minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 _minimap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 map_panel.add_child(_minimap_label)
 var quick := HBoxContainer.new()
 quick.position = Vector2(-600,170)
 quick.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 quick.add_theme_constant_override("separation",5)
 root.add_child(quick)
 for pair in [["Bag","Inventory"],["Hero","Character"],["Quest","Quests"],["Daily","Daily Login"],["Map","Map"],["Chat","Chat"]]:
  quick.add_child(_button(String(pair[0]),_open_window.bind(String(pair[1]))))
 var joystick := _panel(root, Vector2(24,-220), Vector2(190,190), false, true)
 joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 joystick.gui_input.connect(_on_joystick_input)
 _joystick_center = Vector2(95,95)
 var base := ColorRect.new()
 base.color = Color(0.25,0.34,0.48,0.38)
 base.position = Vector2(22,22)
 base.size = Vector2(146,146)
 base.mouse_filter = Control.MOUSE_FILTER_IGNORE
 joystick.add_child(base)
 var stick := Label.new()
 stick.text = "◎"
 stick.add_theme_font_size_override("font_size",66)
 stick.position = Vector2(53,45)
 stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
 joystick.add_child(stick)
 var combat := VBoxContainer.new()
 combat.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 combat.position = Vector2(-250,-260)
 combat.add_theme_constant_override("separation",8)
 root.add_child(combat)
 var row1 := HBoxContainer.new()
 combat.add_child(row1)
 row1.add_child(_button("Potion HP",_use_potion.bind("HPPotion")))
 row1.add_child(_button("Potion MP",_use_potion.bind("MPPotion")))
 var row2 := HBoxContainer.new()
 combat.add_child(row2)
 row2.add_child(_button("Attack",_attack))
 row2.add_child(_button("Jump",_jump))
 row2.add_child(_button("Skill 1",_use_primary_skill))
 var row3 := HBoxContainer.new()
 combat.add_child(row3)
 row3.add_child(_button("Skill 2",_use_secondary_skill))
 row3.add_child(_button("Auto",_toggle_auto_combat))
 _window_layer = Control.new()
 _window_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 _window_layer.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(_window_layer)

func _connect_systems() -> void:
 var npcs := get_node_or_null("/root/NPCMerchantSystem")
 if npcs != null and npcs.has_signal("npc_interacted") and not npcs.npc_interacted.is_connected(_on_npc_interacted):
  npcs.npc_interacted.connect(_on_npc_interacted)
 var quests := get_node_or_null("/root/QuestSystem")
 if quests != null:
  if quests.has_signal("quest_accepted") and not quests.quest_accepted.is_connected(_refresh_quests): quests.quest_accepted.connect(_refresh_quests)
  if quests.has_signal("quest_progressed") and not quests.quest_progressed.is_connected(_on_quest_progressed): quests.quest_progressed.connect(_on_quest_progressed)
  if quests.has_signal("quest_completed") and not quests.quest_completed.is_connected(_refresh_quests): quests.quest_completed.connect(_refresh_quests)
 var gear := get_node_or_null("/root/GearSystem")
 if gear != null and gear.has_signal("equipment_changed") and not gear.equipment_changed.is_connected(_on_equipment_changed):
  gear.equipment_changed.connect(_on_equipment_changed)
 var state := get_node_or_null("/root/GameState")
 if state != null and state.has_signal("inventory_changed") and not state.inventory_changed.is_connected(_on_inventory_changed):
  state.inventory_changed.connect(_on_inventory_changed)
 var forging := get_node_or_null("/root/ForgingSystem")
 if forging != null and forging.has_signal("artisan_opened") and not forging.artisan_opened.is_connected(_open_artisan):
  forging.artisan_opened.connect(_open_artisan)

func _refresh_all() -> void:
 _refresh_status()
 _refresh_minimap()
 _refresh_quests()

func _refresh_status() -> void:
 if _status_label == null: return
 var state := get_node_or_null("/root/GameState")
 var player: Dictionary = state.player_data if state != null else {}
 var hp := int(player.get("hp",player.get("max_hp",100)))
 var max_hp := int(player.get("max_hp",100))
 var mp := int(player.get("mana",100))
 var stamina := int(player.get("stamina",100))
 var gold := int(state.gold) if state != null else 0
 var name := String(player.get("name","Ranger"))
 var level := int(player.get("level",1))
 var rank := String(player.get("rank","Novice"))
 var battle_power := int(player.get("battle_power",0))
 _status_label.text = "%s  |  %s  Lv.%d\nHP %d/%d   MP %d   STA %d\nGold %d   CPs %d" % [name,rank,level,hp,max_hp,mp,stamina,gold,battle_power]

func _refresh_minimap() -> void:
 if _minimap_label == null: return
 var world := get_node_or_null("/root/WorldMapManager")
 var city := String(world.current_city) if world != null else "TwinCity"
 var p := _find_hero()
 var pos := p.global_position if p != null else Vector3.ZERO
 _minimap_label.text = "MAP\n%s\nX %.1f  Z %.1f" % [city,pos.x,pos.z]

func _refresh_quests(_unused_a: Variant = null, _unused_b: Variant = null, _unused_c: Variant = null) -> void:
 if _quest_panel == null: return
 for child in _quest_panel.get_children(): child.queue_free()
 var title := Label.new()
 title.text = "ACTIVE QUESTS"
 title.add_theme_font_size_override("font_size",13)
 _quest_panel.add_child(title)
 var quests := get_node_or_null("/root/QuestSystem")
 if quests == null: return
 var tracked: Array = quests.get_tracked_quests() if quests.has_method("get_tracked_quests") else []
 for quest in tracked.slice(0,3):
  var b := _button("%s  %d/%d" % [String(quest.title),int(quest.progress),int(quest.required)],_navigate_quest.bind(String(quest.id)))
  b.custom_minimum_size = Vector2(290,28)
  _quest_panel.add_child(b)

func _navigate_quest(id: String) -> void:
 var quests := get_node_or_null("/root/QuestSystem")
 if quests != null and quests.has_method("navigate_to_quest"):
  _last_quest_id = id
  quests.navigate_to_quest(id)

func _on_quest_progressed(_id: String, _progress: int, _required: int) -> void:
 _refresh_quests()

func _on_inventory_changed(_id: String, _count: int) -> void:
 if _active_window == "Inventory": _open_window("Inventory")

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
 panel.set_anchors_preset(Control.PRESET_CENTER)
 panel.position = Vector2(-325,-270)
 var layout := VBoxContainer.new()
 layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layout.add_theme_constant_override("separation",8)
 panel.add_child(layout)
 var header := HBoxContainer.new()
 layout.add_child(header)
 var heading := Label.new()
 heading.text = window_name
 heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_theme_font_size_override("font_size",22)
 header.add_child(heading)
 header.add_child(_button("X",func(): _active_window=""; panel.queue_free()))
 match window_name:
  "Inventory": _build_inventory(layout)
  "Character": _build_character(layout)
  "Quests": _build_quest_book(layout)
  "Daily Login": _build_daily_rewards(layout)
  "ArtisanMaster": _build_artisan(layout)
  "Warehouse": _build_warehouse(layout)
  "Merchant": _build_merchant(layout)
  "Map": _build_map_window(layout)
  "Chat": _build_chat(layout)
  _: _build_npc_info(layout,window_name)

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
  cell.text = "Empty"
  if not item.is_empty():
   var id := String(item.get("item_id",""))
   var data := _get_item_data(id)
   cell.text = "%s\nx%d" % [String(data.get("name",id)),int(item.get("count",1))]
   var icon := ICON_SCRIPT.new()
   icon.custom_minimum_size = Vector2(42,42)
   icon.configure(data,int(item.get("instance_data",{}).get("plus",data.get("plus",0))))
   cell.add_child(icon)
   icon.position = Vector2(8,2)
  grid.add_child(cell)
 var footer := Label.new()
 footer.text = "Inventory: %d / 40   |   Stack limit: x100" % slots.size()
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
 var stats := gear.get_combat_bonuses() if gear != null else {}
 var player: Dictionary = state.player_data if state != null else {}
 var bp := int(player.get("battle_power",int(stats.get("attack",0))+int(stats.get("defense",0))))
 layout.add_child(_label("Battle Power: %d   ATK: %d   DEF: %d   M.ATK: %d" % [bp,int(stats.get("attack",0)),int(stats.get("defense",0)),int(stats.get("magic_attack",0))]))

func _build_quest_book(layout: VBoxContainer) -> void:
 var quests := get_node_or_null("/root/QuestSystem")
 if quests == null: return
 for quest in quests.get_tracked_quests():
  layout.add_child(_button("%s  %d/%d — Navigate" % [quest.title,int(quest.progress),int(quest.required)],_navigate_quest.bind(String(quest.id))))
 var categories := ["MAIN_PROMOTION","DAILY","WEEKLY","SIDE_QUESTS","ENDGAME_REBIRTH"]
 for category in categories:
  layout.add_child(_label(category))

func _build_daily_rewards(layout: VBoxContainer) -> void:
 var quests := get_node_or_null("/root/QuestSystem")
 var rewards: Array = quests.DAILY_REWARDS if quests != null else []
 for day in range(7):
  var reward: Dictionary = rewards[day] if day < rewards.size() else {}
  layout.add_child(_button("Day %d — %s" % [day+1,str(reward)],_claim_daily.bind(day)))

func _claim_daily(day: int) -> void:
 var quests := get_node_or_null("/root/QuestSystem")
 if quests != null and quests.has_method("claim_daily_reward"):
  quests.claim_daily_reward(day)
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
  "Sockets": forge.socket_gem(slot,"DragonGem",0)
  "Anima": forge.upgrade_anima()
  _: forge.compose_plus(slot,"Plus1Stone")
 _open_window("ArtisanMaster")

func _build_warehouse(layout: VBoxContainer) -> void:
 layout.add_child(_label("Warehouse storage interface"))
 layout.add_child(_label("Warehouseman interaction opened this touch window."))

func _build_merchant(layout: VBoxContainer) -> void:
 layout.add_child(_label("Merchant: " + _current_npc))
 var npc := get_node_or_null("/root/NPCMerchantSystem")
 if npc != null and npc.has_method("get_shop_inventory"):
  var stock: Array = npc.get_shop_inventory(_current_npc)
  for item in stock: layout.add_child(_button(String(item.get("name",item.get("id","Item"))),func(): pass))

func _build_map_window(layout: VBoxContainer) -> void:
 _refresh_minimap()
 layout.add_child(_label(_minimap_label.text))
 var nav := get_node_or_null("/root/WorldNavigationSystem")
 if nav != null:
  for target in ["CentralPlaza","ArcherGod","ArtisanMaster","Warehouseman","ImperialPalace"]:
   layout.add_child(_button(target,func(): nav.navigate_to_target(target)))

func _build_chat(layout: VBoxContainer) -> void:
 var input := LineEdit.new()
 input.placeholder_text = "Message…"
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
  var target := combat.find_nearest_target(_hero)
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

func _panel(parent: Control, offset: Vector2, panel_size: Vector2, top_right := false, transparent := false) -> Panel:
 var panel := Panel.new()
 panel.custom_minimum_size = panel_size
 panel.size = panel_size
 panel.position = offset
 if top_right: panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.025,0.045,0.085,0.86 if transparent else 0.94)
 style.border_color = Color(0.42,0.60,0.82,0.95)
 style.set_border_width_all(2)
 style.set_corner_radius_all(10)
 panel.add_theme_stylebox_override("panel",style)
 parent.add_child(panel)
 return panel

func _button(caption: String, callback: Callable) -> Button:
 var button := Button.new()
 button.text = caption
 button.custom_minimum_size = Vector2(70,34)
 button.pressed.connect(callback)
 return button

func _label(caption: String) -> Label:
 var label := Label.new()
 label.text = caption
 return label
