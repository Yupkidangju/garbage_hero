extends CanvasLayer

signal command(action: String, args: Dictionary)
signal panel_changed(opened: bool)

const S = preload("res://scripts/hud_style.gd")
const Art = preload("res://scripts/hud_art.gd")
const AreaMap = preload("res://scripts/area_map.gd")
const TravelStamp = preload("res://scripts/hud_travel_stamp.gd")
const Preferences = preload("res://scripts/hud_settings.gd")

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
	info = data
	if art == null: return
	art.info = info
	art.queue_redraw()
	if panel_open():
		if previous_region != int(info.get("region",-1)):
			close_panel()
			return
		var stamp := hash([info.get("coins"),info.get("bag"),info.get("chest"),info.get("equipped"),info.get("auto"),info.get("quests"),info.get("traveler"),info.get("cleared"),info.get("unlocked"),info.get("last_merge")])
		if stamp != wallet_state:
			wallet_state = stamp
			_schedule()

func open_panel(kind: String) -> void:
	if kind not in ["inventory","map","pause","settings","coach","elder","shop","traveler","chest","return"]: return
	var was_open := panel_open()
	return_to = active if kind == "settings" or (kind in ["inventory","map"] and active == "pause") else ""
	active = kind
	section = "take" if kind=="chest" and info.get("bag",[]).is_empty() and not info.get("chest",[]).is_empty() else ""
	selected = -1
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
	var shortcut_closed := active in ["map","inventory"] and InputMap.has_action(active) and event.is_action_pressed(active)
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
		var compact := frame.x / clampf(frame.y/780.0,0.86,1.35) < 980.0 + 860.0*(float(prefs.prefs.text_scale)-1.0)
		quick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		var qs := quick.get_combined_minimum_size()
		quick.offset_right = -20
		quick.offset_left = -20-qs.x
		quick.offset_bottom = -(105+22*(float(prefs.prefs.text_scale)-1)) if compact else -18
		quick.offset_top = quick.offset_bottom-qs.y
	if not is_instance_valid(modal): return
	var available := Vector2(maxf(180,frame.x-30),maxf(150,frame.y-28))
	var target := Vector2(minf(846,available.x),minf(685,available.y))
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
	var stack := _col(modal,10)
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
			_button(body,"%s   ·   %s"%[S.t("map"),S.binding("map")],open_panel.bind("map"),"OpenMap")
			_button(body,S.t("open_settings"),open_panel.bind("settings"),"OpenSettings")
			_button(body,S.t("exit"),_act.bind("quit",{}),"Quit")
		"map":
			var chart := AreaMap.new()
			chart.map_data = info.get("area_map",{})
			chart.text_scale = prefs.prefs.text_scale
			chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(chart)
		"settings": _options()
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
	for id in ["inventory","pause"]:
		var shortcut := "Esc" if id=="pause" else S.binding("inventory")
		var b := _button(quick,"%s   %s"%[shortcut,S.t(id)],open_panel.bind(id),"Quick"+id)
		b.focus_mode = Control.FOCUS_NONE

func _act(action: String, args: Dictionary) -> void:
	command.emit(action,args)

func _section_change(value: String) -> void:
	section = value
	selected = -1
	_render()
	if menu_scroll: menu_scroll.scroll_vertical = 0

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
	return S.t("gear_stats")%[int(item.get("atk",0)),int(item.get("crit",0))]

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
		var scroll := ScrollContainer.new()
		scroll.name = "GearList"
		scroll.follow_focus = true
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size.y = 245 * float(prefs.prefs.text_scale)
		parent.add_child(scroll)
		rows = _col(scroll,5)
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.tooltip_text = _weapon_name(item)
	return choice

func _details(parent: Control, item: Dictionary) -> void:
	var grade := clampi(int(item.get("grade",0)),0,6)
	_label(parent,_weapon_name(item),21,S.GRADE[grade],true,true)
	_label(parent,_stats(item),17,S.PAPER,false,true)
	var worn: Dictionary = info.get("equipped",{})
	var delta := [int(item.get("atk",0))-int(worn.get("atk",0)),int(item.get("crit",0))-int(worn.get("crit",0))]
	_label(parent,S.t("stats_delta")%delta,15,S.MUTED,false,true)

func _inventory() -> void:
	var bag: Array = info.get("bag",[])
	_balance()
	var worn: Dictionary = info.get("equipped",{})
	_label(body,S.t("own_gear"),16,S.GOLD,true)
	if worn.is_empty(): _label(body,S.t("no_gear"),16,S.MUTED)
	else:
		var gear_line := _row(body)
		var gear := _label(gear_line,_weapon_name(worn)+"   ·   "+_stats(worn),17,S.PAPER,false,true)
		gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(gear_line,S.t("unequip"),_act.bind("unequip",{"id":worn.id}),"Unequip")
	var auto := bool(info.get("auto",true))
	_button(body,S.t("auto_on" if auto else "auto_off"),_act.bind("auto",{"enabled":not auto}),"ToggleAuto",auto)
	_line(body)
	var sides := _columns()
	var list: Control = sides[0]
	var detail: Control = sides[1]
	_label(list,S.t("bag_tab"),17,S.GOLD,true)
	var item := _item_rows(list,bag,"BagItem","bag_empty")
	var valid_ids: Array = []
	for candidate in bag:
		if not candidate.get("locked",false): valid_ids.append(int(candidate.id))
	materials = materials.filter(func(id): return valid_ids.has(id))
	if not item.is_empty():
		_details(detail,item)
		_button(detail,S.t("equip"),_act.bind("equip",{"id":item.id}),"Equip",true)
		_button(detail,S.t("unlock" if item.locked else "lock"),_act.bind("lock",{"id":item.id}),"Lock")
	if not auto:
		var reason := _material_reason(item,bag)
		if not item.is_empty():
			_button(detail,S.t("manual_remove" if materials.has(selected) else "manual_pick"),_toggle_material.bind(selected),"Material",false,not reason.is_empty())
			if int(item.grade)<6:
				_label(detail,S.t("fusion_range")%[int(item.get("next_min_atk",0)),int(item.get("next_max_atk",0)),int(item.get("next_min_crit",0)),int(item.get("next_max_crit",0))],15,S.MUTED,false,true)
		_label(detail,S.t(reason) if reason!="" else S.t("fusion_help"),15,S.MUTED,false,true)
		_button(detail,S.t("fusion")%materials.size(),_act.bind("merge",{"ids":materials.duplicate()}),"Merge",true,materials.size()!=3)
	var merged: Dictionary = info.get("last_merge",{})
	if not merged.is_empty() and merged.has("item"):
		_line(body)
		_label(body,"%s   ·   %s   ·   %s"%[S.t("fusion_last"),_weapon_name(merged.item),_stats(merged.item)],16,S.MINT,false,true)
		_label(body,S.t("fusion_compare")%[int(merged.get("atk_delta",0)),int(merged.get("crit_delta",0))],15,S.MUTED)

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
	var quests: Array = info.get("quests",[])
	if quests.is_empty():
		_label(body,S.t("quest_goal"),17,S.PAPER,false,true)
		return
	var sides := _columns()
	var list: Control = sides[0]
	var detail: Control = sides[1]
	_label(list,S.t("quest_list"),16,S.GOLD,true)
	for i in range(quests.size()):
		var entry: Dictionary = quests[i]
		var title := S.t("quest_first") if i==0 else S.t("quest_hunt")%S.t("boss%d"%(i-1))
		var b := _button(list,title,_quest_select.bind(i),"Quest%d"%i,i==quest)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if entry.get("claimed",false): b.text += "   ·   "+S.t("claimed")
	quest = clampi(quest,0,quests.size()-1)
	var entry: Dictionary = quests[quest]
	var claimed := bool(entry.get("claimed",false))
	var eligible := bool(entry.get("eligible",false))
	var target := S.t("quest_goal") if quest==0 else S.t("quest_boss_goal")%[S.t("region%d"%(quest-1)),S.t("boss%d"%(quest-1))]
	_label(detail,target,21,S.PAPER,true,true)
	_label(detail,S.t("reward")%int(entry.get("reward",12 if quest==0 else 20)),18,S.GOLD)
	if quest>0 and not quests[0].get("claimed",false):
		_label(detail,S.t("quest_prereq"),16,S.MUTED,false,true)
	_button(detail,S.t("claimed" if claimed else ("eligible" if eligible else "ongoing")),_act.bind("claim",{"quest":quest}),"Claim",true,not eligible or claimed)

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
	var price := int(vendor.get("price",18)) if visit else 8
	var region := clampi(int(vendor.get("region",0)),0,5)
	var name_text := S.t("buy_traveler")%S.t("region%d"%region) if visit else S.t("buy_shop")
	_label(body,name_text,22,S.GOLD,true)
	var sold := visit and bool(vendor.get("sold",false))
	var reason := ""
	if sold: reason = "sold"
	elif int(info.get("coins",0)) < price: reason = "no_funds"
	elif not _bag_has_room(region+1 if visit else 0,1 if visit else 0): reason = "bag_full"
	_button(body,S.t("sold") if sold else S.t("buy")%price,_act.bind("buy",{"vendor":"traveler" if visit else "shop"}),"Buy",true,reason!="")
	if reason!="" and not sold: _label(body,S.t(reason),16,S.GOLD,false,true)

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
			var desc := _label(grid,S.t(id),16,S.PAPER)
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
