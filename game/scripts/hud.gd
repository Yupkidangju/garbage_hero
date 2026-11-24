extends CanvasLayer

signal command(action: String, args: Dictionary)
signal panel_changed(opened: bool)
signal celebrated(kind: String)

const S = preload("res://scripts/hud_style.gd")
const Art = preload("res://scripts/hud_art.gd")
const AreaMap = preload("res://scripts/area_map.gd")
const TravelStamp = preload("res://scripts/hud_travel_stamp.gd")
const Preferences = preload("res://scripts/hud_settings.gd")
const GrowthMenu = preload("res://scripts/hud_growth.gd")
const Equipment = preload("res://scripts/equipment.gd")
const Loot = preload("res://data/loot_rules.gd")
const InventoryMenu = preload("res://scripts/hud_inventory.gd")
const Preview = preload("res://scripts/hud_hero_preview.gd")
const Workshop = preload("res://scripts/hud_workshop.gd")
const ITEM_FILTERS = ["all","sword","bow","mace","staff","spear","armor","shield","boots","helmet","ring","necklace"]

var info: Dictionary = {}
var prefs := Preferences.new()
var art: Control
var screen: Control
var shade: ColorRect
var modal: PanelContainer
var quick: HBoxContainer
var active := ""
var section := ""
var selected := -1
var selected_skill := "hook"
var materials: Array = []
var route := 0
var difficulty := 0
var quest := 0
var binding_target := ""
var return_to := ""
var notice_clock := 0.0
var notice_frame := -1
var wallet_state := -1
var feedback: Label
var body: VBoxContainer
var foot: VBoxContainer
var menu_scroll: ScrollContainer
var title_font: FontVariation
var body_font: FontVariation
var focus_after := ""
var last_size := Vector2.ZERO
var render_scheduled := false
var inventory_filter := "all"
var last_level := -1
var merge_signature := 0
var celebration: PanelContainer
var celebration_clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	screen = Control.new()
	screen.name = "Interface"
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_font = S.font_weight(screen.get_theme_default_font(),700)
	body_font = S.font_weight(screen.get_theme_default_font(),460)
	art = Art.new()
	screen.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quick = _row(screen,5)
	quick.name = "Shortcuts"
	shade = ColorRect.new()
	shade.name = "MenuBackdrop"
	shade.color = Color("#091117b8")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.hide()
	get_viewport().size_changed.connect(_layout)
	prefs.start()
	_apply_settings()
	command.emit.call_deferred("settings", prefs.prefs.duplicate())
	_layout.call_deferred()

func panel_open() -> bool:
	return not active.is_empty()

func refresh(data: Dictionary) -> void:
	var previous_region := int(info.get("region",-1))
	var level := int(data.get("progression",{}).get("level",1))
	var merged: Dictionary = data.get("last_merge",{})
	var signature := hash(merged)
	if last_level>=0 and level>last_level: _celebrate("level_up",{"levels":level-last_level,"level":level})
	if last_level>=0 and signature!=merge_signature and merged.has("item"): _celebrate("fusion",merged.item)
	last_level = level
	merge_signature = signature
	info = data
	if art == null: return
	art.info = info
	art.queue_redraw()
	if panel_open():
		if previous_region != int(info.get("region",-1)):
			close_panel()
			return
		var stamp := hash([info.get("coins"),info.get("bag"),info.get("chest"),info.get("equipment"),info.get("progression"),info.get("auto"),info.get("quests"),info.get("offers"),info.get("traveler"),info.get("cleared"),info.get("unlocked"),info.get("last_merge")])
		if stamp != wallet_state:
			wallet_state = stamp
			_schedule()

func open_panel(kind: String) -> void:
	if kind not in ["inventory","skills","map","pause","settings","coach","elder","shop","traveler","chest","return"]: return
	var was_open := panel_open()
	return_to = active if kind == "settings" or (kind in ["inventory","map","skills"] and active == "pause") or (kind == "skills" and active == "inventory") else ""
	active = kind
	section = "take" if kind=="chest" and info.get("bag",[]).is_empty() and not info.get("chest",[]).is_empty() else ""
	selected = -1
	inventory_filter = "all"
	materials.clear()
	binding_target = ""
	focus_after = ""
	difficulty = int(info.get("difficulty",0))
	route = maxi(0,int(info.get("region",0)))
	quest = 0
	if kind=="elder":
		var quests: Array = info.get("quests",[])
		for entry in quests:
			if not entry.get("claimed",false):
				quest = int(entry.get("id",0))
				break
	art.message = ""
	notice_clock = 0
	art.hide()
	quick.hide()
	shade.show()
	if not was_open: panel_changed.emit(true)
	else: _drop_modal()
	_render()

func close_panel() -> void:
	if not panel_open(): return
	active = ""
	binding_target = ""
	return_to = ""
	_drop_modal()
	quick.show()
	art.show()
	art.queue_redraw()
	shade.hide()
	panel_changed.emit(false)

func toast(message: String) -> void:
	if art == null: return
	var frame := Engine.get_process_frames()
	var lines := PackedStringArray()
	if notice_frame == frame and not message.is_empty() and not str(art.message).is_empty():
		lines = str(art.message).split("\n",false)
	if message != "" and not lines.has(message): lines.append(message)
	while lines.size()>3: lines.remove_at(0)
	art.message = "\n".join(lines)
	notice_frame = frame
	notice_clock = 4.3 if lines.size()<=1 else 6.0
	art.queue_redraw()
	if is_instance_valid(feedback):
		feedback.text = art.message
		feedback.visible = not lines.is_empty()

func _process(dt: float) -> void:
	if is_instance_valid(celebration):
		celebration_clock -= dt
		celebration.modulate.a = clampf(celebration_clock/0.35,0,1)
		if celebration_clock<=0:
			celebration.queue_free()
			celebration = null
	if notice_clock <= 0: return
	notice_clock -= dt
	if notice_clock <= 0:
		art.message = ""
		art.queue_redraw()
		if is_instance_valid(feedback): feedback.hide()

func _input(event: InputEvent) -> void:
	if not panel_open(): return
	if binding_target != "":
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			binding_target = ""
			toast("")
			_render()
		else:
			var result := prefs.remap(binding_target,event)
			if result=="ok":
				focus_after = "Bind"+binding_target
				binding_target = ""
				toast("")
				_save_settings()
				_render()
			elif not result.is_empty():
				toast(S.t(result))
		get_viewport().set_input_as_handled()
		return
	var shortcut_closed := active in ["map","inventory","skills"] and InputMap.has_action(active) and event.is_action_pressed(active)
	var close_key := event.is_action_pressed("ui_cancel") or shortcut_closed
	if close_key:
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	if binding_target != "":
		binding_target = ""
		_render()
	elif not return_to.is_empty():
		open_panel(return_to)
	else:
		close_panel()

func _apply_settings() -> void:
	art.text_scale = prefs.prefs.text_scale
	art.rebuild_keys()
	_rebuild_quick()
	_layout()

func _save_settings() -> void:
	var result := prefs.save()
	_apply_settings()
	command.emit("settings",prefs.prefs.duplicate())
	if result != OK: toast(S.t("key_settings_failed"))

func _layout() -> void:
	if not is_instance_valid(screen): return
	var frame := screen.size
	if frame.x < 1: frame = get_viewport().get_visible_rect().size
	if is_instance_valid(quick):
		var qs := quick.get_combined_minimum_size()
		var slots: Rect2 = art.skill_row_rect(frame)
		if frame.x - 20 - qs.x >= slots.end.x + 12:
			quick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			quick.offset_left = -20-qs.x
			quick.offset_right = -20
			quick.offset_bottom = -18
			quick.offset_top = quick.offset_bottom-qs.y
		else:
			var hud_factor := clampf(frame.y/780.0,0.86,1.35)
			var margin := clampf(frame.x*0.023,16* hud_factor,38* hud_factor)
			quick.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			quick.position = Vector2(margin, margin+(art.hero_height()+8)*hud_factor)
			quick.size = qs
	if not is_instance_valid(modal): return
	var available := Vector2(maxf(180,frame.x-30),maxf(150,frame.y-28))
	var target := Vector2(minf(1140 if active in ["inventory","skills","coach","elder","shop","traveler","map"] else 846,available.x),minf(685,available.y))
	if active in ["coach","elder","settings","shop","traveler","chest"]: target.y = minf(570*float(prefs.prefs.text_scale),available.y)
	if active=="map": target.y = minf(630*float(prefs.prefs.text_scale),available.y)
	if active in ["pause","return"]: target = Vector2(minf(470,available.x),minf(390*float(prefs.prefs.text_scale),available.y))
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -target.x/2
	modal.offset_right = target.x/2
	modal.offset_top = -target.y/2
	modal.offset_bottom = target.y/2
	if last_size != frame:
		last_size = frame
		if panel_open(): _schedule()

func _schedule() -> void:
	if not render_scheduled:
		render_scheduled = true
		_deferred_render.call_deferred()

func _deferred_render() -> void:
	render_scheduled = false
	if panel_open(): _render()

func _drop_modal() -> void:
	feedback = null
	if is_instance_valid(modal):
		shade.remove_child(modal)
		modal.queue_free()
	modal = null
	menu_scroll = null

func _render() -> void:
	var focus_name := focus_after
	focus_after = ""
	var scroll_pos := 0
	var item_scroll := 0
	if is_instance_valid(modal):
		var old_focus := get_viewport().gui_get_focus_owner()
		if focus_name.is_empty() and is_instance_valid(old_focus) and modal.is_ancestor_of(old_focus):
			focus_name = str(old_focus.name)
		if is_instance_valid(menu_scroll): scroll_pos = menu_scroll.scroll_vertical
		var old_list := modal.find_child("GearList",true,false) as ScrollContainer
		if old_list: item_scroll = old_list.scroll_vertical
	_drop_modal()
	modal = PanelContainer.new()
	modal.name = "Menu"
	modal.add_theme_stylebox_override("panel",S.box(S.INK,S.BRASS,2,6))
	shade.add_child(modal)
	var trim := Workshop.new()
	modal.add_child(trim)
	var stack := _col(modal,10)
	stack.z_index = 1
	var top := _row(stack,12)
	var crest := Control.new()
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.custom_minimum_size = Vector2(38,42)
	top.add_child(crest)
	var crest_id := active
	crest.draw.connect(func(): S.icon(crest,crest_id,Vector2(3,7),31,S.GOLD))
	var heading := _label(top,S.t(active),28,S.PAPER,true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var x := _button(top,S.t("back") if return_to!="" else S.t("close"),_back,"Close")
	x.tooltip_text = "Esc"
	_line(stack)
	menu_scroll = ScrollContainer.new()
	menu_scroll.name = "PanelScroll"
	menu_scroll.follow_focus = true
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(menu_scroll)
	body = _col(menu_scroll,11)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match active:
		"pause":
			_button(body,S.t("resume"),close_panel,"Resume",true)
			_button(body,S.t("open_bag"),open_panel.bind("inventory"),"OpenInventory")
			_button(body,S.t("skills"),open_panel.bind("skills"),"OpenSkills")
			_button(body,"%s   ·   %s"%[S.t("map"),S.binding("map")],open_panel.bind("map"),"OpenMap")
			_button(body,S.t("open_settings"),open_panel.bind("settings"),"OpenSettings")
			_button(body,S.t("exit"),_act.bind("quit",{}),"Quit")
		"map":
			var chart := AreaMap.new()
			chart.map_data = info.get("area_map",{})
			chart.text_scale = prefs.prefs.text_scale
			chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(chart)
			if int(info.get("region",-1))>=0: _label(body,S.t("map_surface_hint"),14,S.MUTED,false,true)
		"settings": _options()
		"skills": GrowthMenu.render(self)
		"inventory": _inventory()
		"coach": _coach()
		"elder": _elder()
		"shop", "traveler": _shop()
		"chest": _chest()
		"return":
			_label(body,S.t("return_body"),18,S.PAPER,false,true)
			_button(body,S.t("town_return"),_act.bind("return",{}),"Return",true)
	foot = _col(stack,2)
	feedback = _label(foot,art.message,16,S.GOLD,false,true)
	feedback.visible = not art.message.is_empty()
	_layout()
	menu_scroll.set_deferred("scroll_vertical",scroll_pos)
	var gear_list := modal.find_child("GearList",true,false) as ScrollContainer
	if gear_list: gear_list.set_deferred("scroll_vertical",item_scroll)
	var first: Control = modal.find_child(focus_name,true,false) if not focus_name.is_empty() else null
	if first == null or not first is Button or first.disabled:
		if active=="pause": first = modal.find_child("Resume",true,false)
		elif active=="coach": first = modal.find_child("Route%d"%route,true,false)
		else: first = x
	if is_instance_valid(first): _focus_if_current.call_deferred(first)

func _focus_if_current(node: Control) -> void:
	if is_instance_valid(node) and node.is_inside_tree() and node.is_visible_in_tree(): node.grab_focus()

func _row(parent: Control, gap: int = 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation",gap)
	parent.add_child(node)
	return node

func _col(parent: Control, gap: int = 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation",gap)
	parent.add_child(node)
	return node

func _line(parent: Control) -> void:
	var line := ColorRect.new()
	line.color = S.LINE
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _image(parent: Control, path: String, minimum: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = S.texture(path)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = minimum
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture

func _portrait(parent: Control, id: String, title: String, caption: String) -> void:
	var row := _row(parent,16)
	_image(row,"res://assets/ui/portraits/%s.png"%id,Vector2(90,96)).name = "Portrait"+id
	var copy := _col(row,2)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(copy,title,23,S.GOLD,true,true)
	_label(copy,caption,16,S.MUTED,false,true)

func _preview_build() -> Dictionary:
	var result := info.duplicate(true)
	result.reduced_flash = bool(prefs.prefs.reduced_flash)
	return result

func _celebrate(kind: String, item: Dictionary) -> void:
	if not is_instance_valid(screen): return
	if is_instance_valid(celebration): celebration.queue_free()
	celebration = PanelContainer.new()
	celebration.name = "SuccessIllustration"
	celebration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celebration.z_index = 40
	celebration.add_theme_stylebox_override("panel",S.box(S.DEEP,S.GOLD if kind=="level_up" else S.MINT,2,5))
	screen.add_child(celebration)
	var row := _row(celebration,12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := _image(row,"res://assets/ui/portraits/hero.png" if kind=="level_up" else "",Vector2(70,70))
	if kind=="fusion": picture.texture = S.item_art(item)
	var copy := _col(row,2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(copy,(S.t("level")%int(item.get("level",1))+" · "+S.t("level_success")) if kind=="level_up" else S.t("fusion_success"),22,S.GOLD if kind=="level_up" else S.MINT,true)
	var levels := int(item.get("levels",1))
	_label(copy,S.t("level_success_detail")%[3*levels,levels] if kind=="level_up" else _weapon_name(item),16,S.PAPER)
	celebration.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	celebration.offset_left = -195
	celebration.offset_right = 195
	celebration.offset_top = 18
	celebration.offset_bottom = 104
	celebration_clock = 2.6 if not bool(prefs.prefs.reduced_flash) else 1.8
	celebrated.emit(kind)

func _item_filter(parent: Control, items: Array) -> void:
	var row := _row(parent,8)
	_label(row,S.t("filter"),15,S.GOLD,true)
	var previous := _button(row,"‹",_cycle_filter.bind(-1),"FilterPrevious")
	previous.tooltip_text = S.t("filter_previous")
	previous.custom_minimum_size.x = 40
	var filter := OptionButton.new()
	filter.name = "ItemFilter"
	filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter.add_theme_font_size_override("font_size",roundi(16*float(prefs.prefs.text_scale)))
	filter.add_theme_stylebox_override("normal",S.box(S.PANEL,S.LINE))
	filter.add_theme_stylebox_override("focus",S.box(S.PANEL,S.MINT,2))
	filter.custom_minimum_size.y = 42
	var popup := filter.get_popup()
	popup.add_theme_font_override("font",body_font)
	popup.add_theme_font_size_override("font_size",roundi(16*float(prefs.prefs.text_scale)))
	popup.add_theme_color_override("font_color",S.PAPER)
	popup.add_theme_color_override("font_hover_color",S.GOLD)
	popup.add_theme_stylebox_override("panel",S.box(S.DEEP,S.BRASS,1,4))
	var ids := ITEM_FILTERS
	for id in ids:
		var count := items.size() if id=="all" else items.filter(func(item): return _item_category(item)==id).size()
		var caption := S.t("filter_all") if id=="all" else Loot.caption(("TYPE_" if id in ["sword","bow","mace","staff","spear"] else "SLOT_")+str(id).to_upper())
		filter.add_item("%s  ·  %d"%[caption,count])
		filter.set_item_metadata(filter.item_count-1,id)
	filter.select(maxi(0,ids.find(inventory_filter)))
	filter.item_selected.connect(func(index):
		inventory_filter = str(filter.get_item_metadata(index))
		selected = -1
		_render()
	)
	row.add_child(filter)
	var next := _button(row,"›",_cycle_filter.bind(1),"FilterNext")
	next.tooltip_text = S.t("filter_next")
	next.custom_minimum_size.x = 40

func _cycle_filter(step: int) -> void:
	var index := maxi(0,ITEM_FILTERS.find(inventory_filter))
	inventory_filter = ITEM_FILTERS[posmod(index+step,ITEM_FILTERS.size())]
	selected = -1
	_render()

func _item_category(item: Dictionary) -> String:
	return str(item.get("weapon_type",Loot.kind(int(item.get("design",0))))) if item.get("slot","weapon")=="weapon" else str(item.get("slot","armor"))

func _filtered_items(items: Array) -> Array:
	return items if inventory_filter=="all" else items.filter(func(item): return _item_category(item)==inventory_filter)

func _meter(parent: Control, current: float, maximum: float, tone: Color) -> void:
	var bar := ProgressBar.new()
	bar.max_value = maxf(1,maximum)
	bar.value = current
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	var track := StyleBoxFlat.new()
	track.bg_color = S.RAISED
	var fill := StyleBoxFlat.new()
	fill.bg_color = tone
	bar.add_theme_stylebox_override("background",track)
	bar.add_theme_stylebox_override("fill",fill)
	parent.add_child(bar)

func _scroll_list(parent: Control, height: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "GearList"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = height
	parent.add_child(scroll)
	var rows := _col(scroll,5)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rows

func _label(parent: Control, value: String, points: int = 17, tint: Color = S.PAPER, strong := false, wrap := false) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_color_override("font_color",tint)
	node.add_theme_font_size_override("font_size",roundi(points*float(prefs.prefs.text_scale)))
	node.add_theme_font_override("font",title_font if strong else body_font)
	if wrap: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func _button(parent: Control, value: String, callback: Callable, node_name: String, highlight := false, disabled := false) -> Button:
	var node := Button.new()
	node.name = node_name
	node.text = value
	node.disabled = disabled
	node.add_theme_font_override("font",body_font)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size",roundi(16*float(prefs.prefs.text_scale)))
	node.add_theme_stylebox_override("normal",S.box(S.RAISED if highlight else S.PANEL,S.GOLD if highlight else S.LINE))
	node.add_theme_stylebox_override("hover",S.box(Color("#34504d"),S.MINT))
	node.add_theme_stylebox_override("pressed",S.box(S.INK,S.GOLD))
	node.add_theme_stylebox_override("disabled",S.box(S.INK,S.LINE))
	var ring := S.box(Color.TRANSPARENT,S.MINT,2)
	ring.draw_center = false
	node.add_theme_stylebox_override("focus",ring)
	node.add_theme_color_override("font_color",S.GOLD if highlight else S.PAPER)
	node.add_theme_color_override("font_disabled_color",S.MUTED.darkened(0.16))
	node.add_theme_color_override("font_hover_color",S.PAPER)
	node.custom_minimum_size.y = maxf(40,31*float(prefs.prefs.text_scale))
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func _rebuild_quick() -> void:
	for old in quick.get_children():
		quick.remove_child(old)
		old.queue_free()
	for id in ["inventory","skills","pause"]:
		var shortcut := "Esc" if id=="pause" else S.binding(id)
		var b := _button(quick,"%s   %s"%[shortcut,S.t(id)],open_panel.bind(id),"Quick"+id)
		b.focus_mode = Control.FOCUS_NONE

func _act(action: String, args: Dictionary) -> void:
	command.emit(action,args)

func _section_change(value: String) -> void:
	section = value
	selected = -1
	if menu_scroll: menu_scroll.scroll_vertical = 0
	_render()

func _tabs(labels: Array, ids: Array, current: String) -> void:
	var tabs := _row(body)
	for i in range(ids.size()):
		var tab := _button(tabs,labels[i],_section_change.bind(ids[i]),"Tab"+str(ids[i]),current==ids[i])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _balance() -> void:
	var wallet := _row(body)
	var space := _label(wallet,S.t("capacity") % [info.get("bag",[]).size(),info.get("chest",[]).size()],16,S.MUTED)
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(wallet,S.t("gold_fmt") % int(info.get("coins",0)),19,S.GOLD,true)

func _columns() -> Array:
	if screen.size.x<675 or (float(prefs.prefs.text_scale)>=1.5 and screen.size.x<800):
		return [body,body]
	var sides := _row(body,20)
	var first := _col(sides)
	var second := _col(sides)
	first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return [first,second]

func _weapon_name(item: Dictionary) -> String:
	return "%s  %s" % [S.t("grade%d"%int(item.get("grade",0))),str(item.get("name",""))]

func _stats(item: Dictionary) -> String:
	return str(item.get("stat_text",S.t("gear_stats")%[int(item.get("atk",0)),int(item.get("crit",0))]))

func _selected_in(items: Array) -> Dictionary:
	for item in items:
		if int(item.id)==selected: return item
	return {}

func _choose(id: int) -> void:
	selected = id
	_render()

func _item_rows(parent: Control, items: Array, prefix: String, empty: String) -> Dictionary:
	if items.is_empty():
		_label(parent,S.t(empty),16,S.MUTED,false,true)
		selected = -1
		return {}
	var choice := _selected_in(items)
	if choice.is_empty():
		choice = items[0]
		selected = int(choice.id)
	var rows := parent
	if items.size()>6:
		rows = _scroll_list(parent,roundi(235*float(prefs.prefs.text_scale)))
	var groups := {}
	for item in items:
		var pattern := int(item.get("design",0))
		if not groups.has(pattern): groups[pattern] = []
		groups[pattern].append(item)
	for pattern in groups:
		var group: Array = groups[pattern]
		_label(rows,"%s    ×%d"%[group[0].name,group.size()],16,S.MUTED,true,true)
		for item in group:
			var id := int(item.id)
			var caption := "%s   ·   %s"%[S.t("grade%d"%item.grade),_stats(item)]
			if item.get("locked",false): caption += "   ·   "+S.t("locked")
			if materials.has(id): caption += "   ·   "+S.t("merge_mark")
			var button := _button(rows,caption,_choose.bind(id),prefix+str(id),id==selected)
			button.icon = S.item_art(item)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width",42)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.tooltip_text = _weapon_name(item)
	return choice

func _details(parent: Control, item: Dictionary) -> void:
	var grade := clampi(int(item.get("grade",0)),0,6)
	var display := _row(parent,12)
	var picture := _image(display,"",Vector2(126,140))
	picture.texture = S.item_art(item)
	picture.name = "SelectedItemArtwork"
	var copy := _col(display,4)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(copy,_weapon_name(item),21,S.GRADE[grade],true,true)
	_label(copy,_type_name(item),15,S.GOLD,false,true)
	_label(copy,_stats(item),17,S.PAPER,false,true)
	var role := str(item.get("role",""))
	if not role.is_empty(): _label(copy,role,14,S.MUTED,false,true)
	var description := str(item.get("description",item.get("role","")))
	if not description.is_empty(): _label(parent,description,15,S.MUTED,false,true)
	var effect := str(item.get("effect_text",""))
	if not effect.is_empty(): _label(parent,effect,15,S.MINT,false,true).name = "ItemUniqueEffect"
	var profile := str(item.get("combat_profile_text",""))
	if not profile.is_empty(): _label(parent,profile,14,S.MUTED,false,true).name = "ItemCombatProfile"
	var source := str(item.get("source_text",""))
	if not source.is_empty(): _label(parent,source,14,S.GOLD,false,true).name = "ItemSource"
	var worn: Dictionary = info.get("equipment",{})
	var comparison := Equipment.compare_text(item,worn)
	var blocked: bool = item.get("slot","weapon")=="shield" and worn.get("weapon",{}).get("two_handed",false)
	_label(parent,comparison if blocked else S.t("worn_delta")%comparison,15,S.GOLD if blocked else S.MUTED,false,true)

func _type_name(item: Dictionary) -> String:
	var category := str(item.get("type_name",item.get("slot_name","")))
	return category+"   ·   "+S.t("two_handed") if item.get("two_handed",false) else category

func _inventory() -> void:
	InventoryMenu.render(self)

func _worn_slots(worn: Dictionary) -> void:
	_label(body,GrowthMenu.stats_text(info.get("stats",{})),16,S.MINT,false,true)
	_line(body)
	var list := _col(body,4)
	for id in Equipment.SLOTS:
		var item: Dictionary = worn.get(id,{})
		var row := _row(list,12)
		var caption := _label(row,Loot.caption("SLOT_"+id.to_upper()),15,S.GOLD,true)
		caption.custom_minimum_size.x = 55*float(prefs.prefs.text_scale)
		var col := _col(row,0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if item.is_empty():
			var blocked: bool = id=="shield" and worn.get("weapon",{}).get("two_handed",false)
			_label(col,S.t("shield_blocked" if blocked else "empty_slot"),16,S.MUTED,false,true)
		else:
			_label(col,_weapon_name(item),18,S.GRADE[clampi(int(item.grade),0,6)],true,true)
			var bonuses := _stats(item)
			if id=="weapon": bonuses = _type_name(item)+"   ·   "+bonuses
			_label(col,bonuses,15,S.MUTED,false,true)
			_button(row,S.t("unequip"),_act.bind("unequip",{"id":item.id}),"Unequip" if id=="weapon" else "Unequip"+id)
		_line(list)

func _material_reason(item: Dictionary, items: Array) -> String:
	if item.is_empty() or materials.has(selected): return ""
	if item.locked: return "fusion_protect"
	if int(item.grade)>=6: return "fusion_max"
	if materials.size()>=3: return "fusion_help"
	if not materials.is_empty():
		for candidate in items:
			if int(candidate.id)==int(materials[0]) and (candidate.grade!=item.grade or candidate.design!=item.design):
				return "fusion_mismatch"
	return ""

func _toggle_material(id: int) -> void:
	if materials.has(id): materials.erase(id)
	elif materials.size()<3: materials.append(id)
	_render()

func _route_select(index: int) -> void:
	route = index
	_render()

func _diff_select(index: int) -> void:
	difficulty = index
	_render()

func _route_flag(key: String, region: int, level: int) -> bool:
	var flags: Array = info.get(key,[])
	var index := level*6+region
	return bool(flags[index]) if index >= 0 and index < flags.size() else key=="unlocked" and index==0

func _coach() -> void:
	var bar := _row(body,5)
	for tier in range(4):
		var b := _button(bar,S.t("diff%d"%tier),_diff_select.bind(tier),"Difficulty%d"%tier,difficulty==tier)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line(body)
	var sides := _columns()
	var list: Control = sides[0]
	var detail: Control = sides[1]
	_label(list,S.t("coach_routes"),16,S.GOLD,true)
	for i in range(6):
		var status := "cleared" if _route_flag("cleared",i,difficulty) else ("open" if _route_flag("unlocked",i,difficulty) else "closed")
		var caption := "%s     ·   %s"%[S.t("region%d"%i),S.t(status)]
		var b := _button(list,caption,_route_select.bind(i),"Route%d"%i,i==route)
		b.icon = S.region_art(i)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width",64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stamp := TravelStamp.new()
	stamp.region = route
	detail.add_child(stamp)
	var unlocked := _route_flag("unlocked",route,difficulty)
	_label(detail,S.t("region%d"%route),24,S.GEO[route],true,true)
	_label(detail,"%s   ·   %s"%[S.t("diff%d"%difficulty),S.t("route_level")%(1+3*route+18*difficulty)],17,S.MUTED)
	_label(detail,"%s   ·   %s"%[S.t("mini_marks"),S.t("mini%d"%route)],17,S.PAPER,false,true)
	_label(detail,S.t("quest_boss_goal")%[S.t("region%d"%route),S.t("boss%d"%route)],17,S.PAPER,false,true)
	if not unlocked:
		var before := maxi(0,difficulty*6+route-1)
		_label(detail,S.t("unlock_route")%[S.t("diff%d"%floori(before/6.0)),S.t("region%d"%(before%6)),S.t("boss%d"%(before%6))],16,S.GOLD,false,true)
	_button(detail,S.t("depart"),_act.bind("travel",{"region":route,"difficulty":difficulty}),"Depart",true,not unlocked)

func _quest_select(index: int) -> void:
	quest = index
	_render()

func _elder() -> void:
	_portrait(body,"elder",S.t("elder_greeting"),S.t("elder_caption"))
	var quests: Array = info.get("quests",[])
	if quests.is_empty():
		_label(body,S.t("quest_goal"),17,S.PAPER,false,true)
		return
	var sides := _columns()
	var list: Control = sides[0]
	var detail: Control = sides[1]
	_label(list,S.t("quest_list"),16,S.GOLD,true)
	if quests.size()>6: list = _scroll_list(list,roundi(255*float(prefs.prefs.text_scale)))
	for entry in quests:
		var id := int(entry.id)
		var title := str(entry.name)
		var b := _button(list,title,_quest_select.bind(id),"Quest%d"%id,id==quest)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if entry.get("claimed",false): b.text += "   ·   "+S.t("claimed")
		elif entry.get("eligible",false): b.text += "   ·   "+S.t("eligible")
	var entry: Dictionary = quests[0]
	for candidate in quests:
		if candidate.id==quest: entry = candidate
	var claimed := bool(entry.get("claimed",false))
	var eligible := bool(entry.get("eligible",false))
	_label(detail,str(entry.name),21,S.PAPER,true,true)
	_label(detail,str(entry.description),17,S.PAPER,false,true)
	_label(detail,S.t("quest_progress")%[entry.progress,entry.target],16,S.MINT)
	_meter(detail,entry.progress,entry.target,S.MINT)
	_label(detail,S.t("reward")%int(entry.get("reward",12 if quest==0 else 20)),18,S.GOLD)
	if not str(entry.prerequisite).is_empty():
		_label(detail,entry.prerequisite,16,S.MUTED,false,true)
	_button(detail,S.t("claimed" if claimed else ("eligible" if eligible else "ongoing")),_act.bind("claim",{"quest":entry.id}),"Claim",true,not eligible or claimed)

func _bag_has_room(design: int, grade: int, protected := false) -> bool:
	var bag: Array = info.get("bag",[])
	if bag.size()<30: return true
	if protected or not info.get("auto",true) or grade==6: return false
	var count := 0
	for item in bag:
		if not item.get("locked",false) and int(item.get("design",-1))==design and int(item.get("grade",-1))==grade:
			count += 1
	return count >= 2

func _shop() -> void:
	var visit := active=="traveler"
	var vendor: Dictionary = info.get("traveler",{})
	_portrait(body,"traveler" if visit else "shop",S.t("traveler_greeting" if visit else "shop_greeting"),S.t("traveler_caption" if visit else "shop_caption"))
	_balance()
	if visit and not vendor.get("available",false):
		_label(body,S.t("absent"),19,S.MUTED,false,true)
		return
	if not visit: _tabs([S.t("tab_buy"),S.t("tab_sell")],["buy","sell"],"sell" if section=="sell" else "buy")
	_line(body)
	if section=="sell" and not visit:
		var sides := _columns()
		var list: Control = sides[0]
		var detail: Control = sides[1]
		_label(list,S.t("col_title"),16,S.GOLD,true)
		var item := _item_rows(list,info.get("bag",[]),"SellItem","sell_empty")
		if item.is_empty(): return
		_details(detail,item)
		var price := (int(item.grade)+1)*2
		_button(detail,S.t("sell")%price,_act.bind("sell",{"id":item.id}),"Sell",true,bool(item.get("locked",false)))
		if item.get("locked",false): _label(detail,S.t("locked_sell"),15,S.GOLD,false,true)
		return
	var vendor_id := "traveler" if visit else "shop"
	var offers: Array = info.get("offers",{}).get(vendor_id,[])
	if offers.is_empty(): return
	_item_filter(body,offers)
	offers = _filtered_items(offers)
	if offers.is_empty():
		_label(body,S.t("filter_empty"),17,S.MUTED,false,true)
		return
	var sides := _columns()
	var list: Control = sides[0]
	var detail: Control = sides[1]
	if visit:
		_label(list,S.t("region_stock")%S.t("region%d"%int(vendor.get("region",0))),16,S.GOLD,true,true)
	else:
		_label(list,S.t("shop_stock")%offers.size(),16,S.GOLD,true)
	if offers.size()>6: list = _scroll_list(list,roundi(250*float(prefs.prefs.text_scale)))
	var offer: Dictionary = offers[0]
	for entry in offers:
		if entry.design==selected: offer = entry
	selected = int(offer.design)
	for entry in offers:
		var caption := "%s   ·   %s" % [entry.name,S.t("sold") if entry.sold else S.t("gold_fmt")%int(entry.price)]
		var b := _button(list,caption,_choose.bind(int(entry.design)),"Offer%d"%int(entry.design),entry.design==selected)
		b.icon = S.item_art(entry)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width",52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var price := int(offer.price)
	var sold := bool(offer.sold)
	_details(detail,offer)
	var owned := 0
	for item in info.get("bag",[]):
		if item.design==offer.design: owned += 1
	_label(detail,S.t("shop_owned")%owned,15,S.MINT)
	if visit: _label(detail,S.t("visit_stock")%int(offer.stock),15,S.MUTED,false,true)
	var reason := ""
	if sold: reason = "sold"
	elif int(info.get("coins",0)) < price: reason = "no_funds"
	elif not _bag_has_room(selected,int(offer.grade)): reason = "bag_full"
	_button(detail,S.t("sold") if sold else S.t("buy")%price,_act.bind("buy",{"vendor":vendor_id,"design":selected}),"Buy",true,reason!="")
	if reason!="" and not sold: _label(detail,S.t(reason),16,S.GOLD,false,true)

func _chest() -> void:
	_balance()
	var take := section=="take"
	_tabs([S.t("tab_send"),S.t("tab_take")],["send","take"],"take" if take else "send")
	var sides := _columns()
	var list: Control = sides[0]
	var detail: Control = sides[1]
	_label(list,S.t("stash_tab" if take else "bag_tab"),16,S.GOLD,true)
	var items: Array = info.get("chest" if take else "bag",[])
	var item := _item_rows(list,items,"ChestItem","stash_empty" if take else "bag_empty")
	if item.is_empty(): return
	_details(detail,item)
	var full: bool = not _bag_has_room(int(item.design),int(item.grade),item.locked) if take else info.get("chest",[]).size()>=120
	_button(detail,S.t("withdraw" if take else "store"),_act.bind("withdraw" if take else "store",{"id":item.id}),"Transfer",true,full)
	if full: _label(detail,S.t("bag_full" if take else "stash_full"),15,S.GOLD,false,true)

func _set_pref(id: String, value: Variant) -> void:
	prefs.prefs[id] = value
	_save_settings()
	_render()

func _capture_key(id: String) -> void:
	binding_target = id
	focus_after = "Bind"+id
	toast(S.t("set_key"))
	_render()

func _reset_keys() -> void:
	prefs.reset()
	_save_settings()
	_render()

func _options() -> void:
	_tabs([S.t("screen"),S.t("controls")],["display","controls"],"controls" if section=="controls" else "display")
	_line(body)
	if section=="controls":
		if not binding_target.is_empty(): _label(body,S.t("set_key"),16,S.GOLD,false,true)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation",16)
		grid.add_theme_constant_override("v_separation",4)
		body.add_child(grid)
		for id in Preferences.ACTIONS:
			var slot_index := GrowthMenu.SLOT_ACTIONS.find(id)
			var desc := _label(grid,S.t("slot_%d"%slot_index if slot_index>=0 else id),16,S.PAPER)
			desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_button(grid,S.binding(id),_capture_key.bind(id),"Bind"+id,binding_target==id)
		_button(body,S.t("reset_keys"),_reset_keys,"ResetKeys")
		return
	_label(body,S.t("type_scale"),18,S.PAPER,true)
	var sizes := _row(body)
	for val in [1.0,1.25,1.5]:
		var b := _button(sizes,"%d%%"%roundi(val*100),_set_pref.bind("text_scale",val),"Scale%d"%roundi(val*100),is_equal_approx(float(prefs.prefs.text_scale),val))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in [["screen_shake","shake"],["reduced_flash","flash"]]:
		var row := _row(body)
		var label := _label(row,S.t(item[1]),18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var enabled := bool(prefs.prefs[item[0]])
		_button(row,S.t("on" if enabled else "off"),_set_pref.bind(item[0],not enabled),str(item[0]),enabled)
