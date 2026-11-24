extends RefCounted

const S = preload("res://scripts/hud_style.gd")
const SLOT_ACTIONS = ["hook","spin","slam"]
const ATTRIBUTES = ["strength","vitality","agility"]

static func stats_text(stats: Dictionary) -> String:
	return S.t("hero_stats") % [int(stats.get("atk",0)),int(stats.get("defense",0)),int(stats.get("max_hp",100)),int(stats.get("crit",0)),float(stats.get("speed",0))]

static func render(hud) -> void:
	var growth: Dictionary = hud.info.get("progression",{})
	var summary: HBoxContainer = hud._row(hud.body,14)
	var level: Label = hud._label(summary,S.t("level") % int(growth.get("level",1)),23,S.GOLD,true)
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current := int(growth.get("xp",0))
	var next := int(growth.get("xp_next",0))
	hud._label(summary,S.t("xp_progress")%[current,next],16,S.PAPER)
	hud._meter(hud.body,current,next,S.GOLD)
	var points := int(growth.get("skill_points",0))
	var stat_points := int(growth.get("stat_points",0))
	var stats_tab: bool = hud.section=="attributes"
	hud._tabs([S.t("skill_tree_tab")%points,S.t("attributes_tab")%stat_points],["tree","attributes"],"attributes" if stats_tab else "tree")
	if stats_tab: _attributes(hud,growth,stat_points)
	else: _tree(hud,growth)

static func _attributes(hud, growth: Dictionary, points: int) -> void:
	var totals: Dictionary = hud.info.get("stats",{})
	for id in ATTRIBUTES:
		var row: HBoxContainer = hud._row(hud.body,14)
		var col: VBoxContainer = hud._col(row,1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := int(growth.get("attributes",{}).get(id,0))
		hud._label(col,"%s   %d" % [S.t(id),value],21,S.PAPER,true)
		hud._label(col,S.t(id+"_gain"),16,S.MUTED,false,true)
		hud._button(row,S.t("allocate"),hud._act.bind("allocate_stat",{"stat":id}),"Allocate"+id,false,points<1)
		hud._line(hud.body)
	hud._label(hud.body,S.t("combat_stats"),17,S.GOLD,true)
	hud._label(hud.body,stats_text(totals),17,S.PAPER,false,true)

static func _select(hud, id: String) -> void:
	hud.selected_skill = id
	hud._render()

static func _tree(hud, growth: Dictionary) -> void:
	var catalog: Array = growth.get("catalog",[])
	if catalog.is_empty(): return
	var by_id := {}
	for entry in catalog: by_id[entry.id] = entry
	var selected: Dictionary = by_id.get(hud.selected_skill,catalog[0])
	var sides: Array = hud._columns()
	var list: Control = sides[0]
	var detail: Control = sides[1]
	for entry in catalog:
		if str(entry.prerequisite).is_empty(): _branch(hud,list,catalog,entry,selected.id,0)
	var header: HBoxContainer = hud._row(detail,10)
	var id := str(selected.id)
	var name_label: Label = hud._label(header,selected.name,23,S.PAPER,true,true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var demonstration: HBoxContainer = hud._row(detail,8)
	var crest: TextureRect = hud._image(demonstration,"res://assets/ui/skills/%s.png"%id,Vector2(146,196))
	crest.name = "SkillIllustration"
	var preview = hud.Preview.new()
	preview.skill = id
	preview.build = hud._preview_build()
	var ranks: Dictionary = preview.build.get("progression",{}).get("ranks",{}).duplicate()
	ranks[id] = maxi(1,int(selected.rank))
	preview.build.progression.ranks = ranks
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demonstration.add_child(preview)
	hud._label(detail,S.t("preview_unlearned" if int(selected.rank)==0 else "preview_caption"),14,S.MUTED,false,true)
	hud._button(detail,S.t("preview_cast"),preview.replay,"ReplaySkill")
	hud._label(detail,str(selected.description),16,S.PAPER,false,true)
	var rank := int(selected.rank)
	var maximum := int(selected.max_rank)
	hud._label(detail,S.t("skill_rank") % [rank,maximum],16,S.MINT,true)
	if rank < maximum:
		var damage := S.t("rank_first") % int(selected.next_damage_percent) if rank==0 else S.t("rank_gain") % [int(selected.damage_percent),int(selected.next_damage_percent)]
		hud._label(detail,damage,15,S.MUTED,false,true)
		var requirement := S.t("learn_level") % int(selected.level_required)
		var parent_id := str(selected.prerequisite)
		if not parent_id.is_empty() and by_id.has(parent_id):
			requirement += "   ·   "+S.t("learn_parent")%str(by_id[parent_id].name)
		hud._label(detail,requirement,15,S.MUTED,false,true)
		var caption := S.t("learn" if rank==0 else "upgrade") % int(selected.cost)
		hud._button(detail,caption,hud._act.bind("learn_skill",{"skill":id}),"LearnSkill",true,not bool(selected.can_learn))
	else:
		hud._label(detail,S.t("rank_max")%int(selected.damage_percent),16,S.MINT,false,true)
	hud._line(detail)
	hud._label(detail,S.t("assign_slot"),16,S.GOLD,true)
	var loadout: Array = growth.get("loadout",["","",""])
	var slots: HBoxContainer = hud._row(detail,5)
	for index in 3:
		var key := S.binding(SLOT_ACTIONS[index])
		var assigned := str(loadout[index])
		var label := key+"\n"+(S.t("short_"+assigned) if not assigned.is_empty() else S.t("empty_slot"))
		var b: Button = hud._button(slots,label,hud._act.bind("equip_skill",{"slot":index,"skill":id}),"Assign%d"%index,assigned==id,rank==0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = S.t("assign_hint")%[key,selected.name]
	var worn_index := loadout.find(id)
	if worn_index>=0:
		hud._button(detail,S.t("clear_slot")%S.binding(SLOT_ACTIONS[worn_index]),hud._act.bind("equip_skill",{"slot":worn_index,"skill":""}),"ClearSkill")

static func _branch(hud, parent: Control, catalog: Array, entry: Dictionary, selected: String, depth: int) -> void:
	var row: HBoxContainer = hud._row(parent,0)
	if depth>0:
		var indent := Control.new()
		indent.custom_minimum_size.x = depth*13
		indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(indent)
		indent.draw.connect(func():
			var p := Vector2(indent.size.x-8,indent.size.y*0.50)
			indent.draw_line(Vector2(p.x,0),p,S.LINE,1.5)
			indent.draw_line(p,Vector2(indent.size.x-2,p.y),S.LINE,1.5)
		)
	var caption := "%s    ·    %s" % [entry.name,S.t("rank_short")%int(entry.rank) if int(entry.rank)>0 else S.t("unlearned")]
	var b: Button = hud._button(row,caption,_select.bind(hud,str(entry.id)),"Skill"+str(entry.id),entry.id==selected)
	b.icon = S.skill_art(str(entry.id))
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width",68)
	b.custom_minimum_size.y = 78
	b.tooltip_text = str(entry.description)
	if int(entry.rank)==0: b.add_theme_color_override("icon_normal_color",Color(0.67,0.75,0.73))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bool(entry.can_learn): b.add_theme_color_override("font_color",S.MINT)
	for child in catalog:
		if child.prerequisite==entry.id: _branch(hud,parent,catalog,child,selected,depth+1)
