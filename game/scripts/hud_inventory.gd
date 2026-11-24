extends RefCounted

const S = preload("res://scripts/hud_style.gd")
const Equipment = preload("res://scripts/equipment.gd")
const Loot = preload("res://data/loot_rules.gd")

static func render(hud) -> void:
	var bag: Array = hud.info.get("bag",[])
	var worn: Dictionary = hud.info.get("equipment",{})
	hud._balance()
	var count := 0
	for piece in worn.values():
		if not piece.is_empty(): count += 1
	var tabs: HBoxContainer = hud._row(hud.body)
	for entry in [["bag",S.t("bag_tab")],["equipped",S.t("worn_count")%count]]:
		var button: Button = hud._button(tabs,entry[1],hud._section_change.bind(entry[0]),"Tab"+str(entry[0]),hud.section==entry[0] or (hud.section=="" and entry[0]=="bag"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._button(tabs,S.t("skills"),hud.open_panel.bind("skills"),"OpenSkills")
	var avatar: Control
	var inventory: Control
	var detail: Control
	if hud.screen.size.x>=1050:
		var columns: HBoxContainer = hud._row(hud.body,14)
		inventory = hud._col(columns,8)
		avatar = hud._col(columns,8)
		detail = hud._col(columns,8)
		for column in [inventory,avatar,detail]: column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inventory.custom_minimum_size.x = 282
		avatar.custom_minimum_size.x = 330
		detail.size_flags_stretch_ratio = 1.15
	else:
		var sides: Array = hud._columns()
		avatar = sides[0]
		inventory = sides[1]
		detail = inventory
	_avatar(hud,avatar,worn)
	hud._label(avatar,hud.GrowthMenu.stats_text(hud.info.get("stats",{})),15,S.MINT,false,true)
	hud._label(avatar,S.t("equipment_hint"),14,S.MUTED,false,true)
	if hud.section=="equipped":
		_worn(hud,inventory,worn)
		if detail!=inventory:
			var shown: Dictionary = worn.get("weapon",{})
			for piece in worn.values():
				if not piece.is_empty() and hud._item_category(piece)==hud.inventory_filter: shown = piece
			if not shown.is_empty(): hud._details(detail,shown)
		return
	var auto := bool(hud.info.get("auto",true))
	hud._button(inventory,S.t("auto_on" if auto else "auto_off"),hud._act.bind("auto",{"enabled":not auto}),"ToggleAuto",auto)
	hud._item_filter(inventory,bag)
	var shown: Array = hud._filtered_items(bag)
	var item := _grid(hud,inventory,shown,"BagItem")
	var valid_ids: Array = []
	for candidate in bag:
		if not candidate.get("locked",false): valid_ids.append(int(candidate.id))
	hud.materials = hud.materials.filter(func(id): return valid_ids.has(id))
	if not item.is_empty():
		hud._details(detail,item)
		var actions: HBoxContainer = hud._row(detail)
		var conflict: bool = item.get("slot","weapon")=="shield" and worn.get("weapon",{}).get("two_handed",false)
		hud._button(actions,S.t("equip"),hud._act.bind("equip",{"id":item.id}),"Equip",true,conflict).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud._button(actions,S.t("unlock" if item.locked else "lock"),hud._act.bind("lock",{"id":item.id}),"Lock").size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if item.get("two_handed",false) and not worn.get("shield",{}).is_empty():
			hud._label(detail,S.t("shield_stowed"),15,S.GOLD,false,true)
		var design_count := 0
		var fusion_count := 0
		for candidate in bag:
			if candidate.design==item.design:
				design_count += 1
				if candidate.grade==item.grade and not candidate.locked: fusion_count += 1
		hud._label(detail,S.t("design_quantity")%[design_count,fusion_count],15,S.MINT,false,true).name = "DesignQuantity"
	if not auto:
		var reason: String = hud._material_reason(item,bag)
		if not item.is_empty():
			hud._button(detail,S.t("manual_remove" if hud.materials.has(hud.selected) else "manual_pick"),hud._toggle_material.bind(hud.selected),"Material",false,not reason.is_empty())
			if int(item.grade)<6:
				hud._label(detail,S.t("next_fusion")%str(item.get("next_stat_text","")),15,S.MUTED,false,true)
		var materials: HBoxContainer = hud._row(detail,7)
		for index in 3:
			var art: TextureRect = hud._image(materials,"",Vector2(44,44))
			art.name = "FusionMaterial%d"%index
			if index<hud.materials.size():
				for candidate in bag:
					if int(candidate.id)==int(hud.materials[index]): art.texture = S.item_art(candidate)
		hud._label(detail,S.t(reason) if not reason.is_empty() else S.t("fusion_help"),15,S.MUTED,false,true)
		hud._button(detail,S.t("fusion")%hud.materials.size(),hud._act.bind("merge",{"ids":hud.materials.duplicate()}),"Merge",true,hud.materials.size()!=3)
	var merged: Dictionary = hud.info.get("last_merge",{})
	if not merged.is_empty() and merged.has("item"):
		hud._line(detail)
		var latest: HBoxContainer = hud._row(detail,8)
		var picture: TextureRect = hud._image(latest,"",Vector2(52,52))
		picture.texture = S.item_art(merged.item)
		hud._label(latest,"%s\n%s"%[S.t("fusion_last"),hud._weapon_name(merged.item)],16,S.MINT,false,true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud._label(detail,S.t("fusion_delta")%str(merged.comparison),15,S.MUTED,false,true).name = "LastFusionComparison"

static func _avatar(hud, parent: Control, worn: Dictionary) -> void:
	var title: HBoxContainer = hud._row(parent)
	hud._label(title,S.t("hero"),22,S.PAPER,true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._label(title,S.t("level")%int(hud.info.get("progression",{}).get("level",1)),17,S.GOLD,true)
	var frame := PanelContainer.new()
	frame.name = "EquipmentStage"
	frame.add_theme_stylebox_override("panel",S.box(S.DEEP,S.BRASS,1,4))
	parent.add_child(frame)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(330,386)
	frame.add_child(stage)
	var preview = hud.Preview.new()
	preview.build = hud._preview_build()
	stage.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 77
	preview.offset_right = -77
	preview.offset_top = 50
	preview.offset_bottom = -12
	var places := {"helmet":Vector2(0.5,0.02),"weapon":Vector2(0.0,0.20),"armor":Vector2(1.0,0.20),"shield":Vector2(0.0,0.47),"boots":Vector2(1.0,0.47),"ring":Vector2(0.0,0.74),"necklace":Vector2(1.0,0.74)}
	for slot: String in Equipment.SLOTS:
		var item: Dictionary = worn.get(slot,{})
		var at: Vector2 = places[slot]
		var column: VBoxContainer = hud._col(stage,2)
		column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		column.anchor_left = at.x
		column.anchor_right = at.x
		column.anchor_top = at.y
		column.anchor_bottom = at.y
		column.offset_left = 0 if at.x==0 else (-74 if at.x==1 else -37)
		column.offset_right = column.offset_left+74
		var button: Button = hud._button(column,"",_slot_select.bind(hud,slot),"Slot"+slot,false,item.is_empty())
		button.custom_minimum_size = Vector2(74,62)
		button.expand_icon = true
		button.icon = S.item_art(item) if not item.is_empty() else null
		button.add_theme_constant_override("icon_max_width",54)
		button.tooltip_text = Loot.caption("SLOT_"+slot.to_upper())+"\n"+(hud._weapon_name(item) if not item.is_empty() else S.t("empty_slot"))
		if item.is_empty():
			button.text = "◇"
		else:
			button.add_theme_stylebox_override("normal",S.box(S.PANEL,S.GRADE[clampi(int(item.grade),0,6)]))
		var label: Label = hud._label(column,Loot.caption("SLOT_"+slot.to_upper()),12,S.MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

static func _slot_select(hud, slot: String) -> void:
	hud.section = "equipped"
	var item: Dictionary = hud.info.get("equipment",{}).get(slot,{})
	hud.inventory_filter = hud._item_category(item) if slot=="weapon" and not item.is_empty() else slot
	if hud.inventory_filter not in hud.ITEM_FILTERS: hud.inventory_filter = "all"
	hud._render()

static func _worn(hud, parent: Control, worn: Dictionary) -> void:
	for slot: String in Equipment.SLOTS:
		var item: Dictionary = worn.get(slot,{})
		var row: HBoxContainer = hud._row(parent,8)
		var picture: TextureRect = hud._image(row,"",Vector2(46,46))
		picture.texture = S.item_art(item) if not item.is_empty() else null
		var labels: VBoxContainer = hud._col(row,1)
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud._label(labels,Loot.caption("SLOT_"+slot.to_upper()),14,S.GOLD,true)
		hud._label(labels,S.t("empty_slot") if item.is_empty() else hud._weapon_name(item),16,S.MUTED if item.is_empty() else S.GRADE[clampi(int(item.grade),0,6)],false,true)
		if not item.is_empty():
			hud._button(row,S.t("unequip"),hud._act.bind("unequip",{"id":item.id}),"Unequip" if slot=="weapon" else "Unequip"+slot)
		hud._line(parent)

static func _grid(hud, parent: Control, items: Array, prefix: String) -> Dictionary:
	if items.is_empty():
		hud._label(parent,S.t("bag_empty" if hud.inventory_filter=="all" else "filter_empty"),17,S.MUTED,false,true)
		return {}
	var selected: Dictionary = hud._selected_in(items)
	if selected.is_empty():
		selected = items[0]
		hud.selected = int(selected.id)
	var list: VBoxContainer = hud._scroll_list(parent,194)
	var grid := GridContainer.new()
	grid.name = "BagGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	list.add_child(grid)
	for item in items:
		var id := int(item.id)
		var mark := "◆" if hud.materials.has(id) else ("▣" if item.get("locked",false) else "")
		var button: Button = hud._button(grid,mark,hud._choose.bind(id),prefix+str(id),id==hud.selected)
		button.icon = S.item_art(item)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",52)
		button.custom_minimum_size = Vector2(66,66)
		button.tooltip_text = "%s\n%s\n%s"%[hud._weapon_name(item),hud._type_name(item),hud._stats(item)]
		button.add_theme_stylebox_override("normal",S.box(S.RAISED if id==hud.selected else S.DEEP,S.GOLD if id==hud.selected else S.GRADE[clampi(int(item.grade),0,6)].darkened(0.35)))
	return selected
