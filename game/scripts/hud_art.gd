extends Control

const S = preload("res://scripts/hud_style.gd")
const SKILLS = ["attack", "dodge", "hook", "spin", "slam"]
var info: Dictionary = {}
var text_scale := 1.0
var message := ""
var keys: Dictionary = {}
var body_font: Font
var title_font: FontVariation
var factor := 1.0
var view := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_font = S.font_weight(get_theme_default_font(),460)
	title_font = S.font_weight(get_theme_default_font(),730)
	rebuild_keys()

func rebuild_keys() -> void:
	for action in SKILLS + ["inventory","skills","interact","move_left","move_right","move_up","move_down"]:
		keys[action] = S.binding(action)
	queue_redraw()

func _type(value: String, x: float, y: float, points: int, tint: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, bold := false) -> void:
	var font: Font = title_font if bold else body_font
	var px := maxi(10,roundi(points * text_scale))
	if width > 0 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x > width:
		while value.length() > 1 and font.get_string_size(value+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,px).x > width:
			value = value.left(-1)
		value += "…"
	draw_string(font, Vector2(x,y+font.get_ascent(px)), value, align, width, px, tint)

func _plate(r: Rect2, bg: Color, edge: Color, cut := 7.0) -> void:
	var a := r.position
	var b := r.end
	var p := PackedVector2Array([a+Vector2(cut,0),Vector2(b.x,a.y),b-Vector2(0,cut),b-Vector2(cut,0),Vector2(a.x,b.y),a+Vector2(0,cut)])
	draw_colored_polygon(p,bg)
	p.append(p[0])
	draw_polyline(p,edge,1.3,true)

func _rule(a: Vector2, b: Vector2, color: Color) -> void:
	draw_line(a,b,color,1.2,true)

func _draw() -> void:
	if not body_font or size.x < 1: return
	factor = clampf(size.y / 780.0, 0.86, 1.35)
	view = size / factor
	draw_set_transform(Vector2.ZERO,0,factor*Vector2.ONE)
	var margin := clampf(view.x * 0.023,16,38)
	var narrow := view.x < 1020
	_hero(margin, margin)
	_location(margin,narrow)
	_boss(margin)
	_skills()
	_controls(margin, narrow)
	var service := str(info.get("service",""))
	if not service.is_empty():
		var label := "%s   %s" % [keys.get("interact","F"),S.t("service_"+service)]
		var w := maxf(160.0,body_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(17*text_scale)).x+50)
		var r := Rect2((view.x-w)*0.5,view.y-143*text_scale,w,37*text_scale)
		_plate(r,S.INK,S.GOLD,5)
		_type(label,r.position.x,r.position.y+5,17,S.PAPER,w,HORIZONTAL_ALIGNMENT_CENTER,true)
	if not message.is_empty():
		var lines := message.split("\n",false)
		var w := 220.0
		for line in lines:
			w = maxf(w,body_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(17*text_scale)).x+38)
		w = minf(view.x-40,w)
		var row_height := 26.0*text_scale
		var y := view.y - (199 if not service.is_empty() else 146)*text_scale - row_height*(lines.size()-1)
		_plate(Rect2((view.x-w)*0.5,y,w,37*text_scale+row_height*(lines.size()-1)),S.DEEP,S.BRASS)
		for i in range(lines.size()):
			_type(lines[i],(view.x-w)*0.5+14,y+4+i*row_height,17,S.GOLD,w-28,HORIZONTAL_ALIGNMENT_CENTER)

func hero_height() -> float:
	return 113*text_scale

func _hero(x: float, y: float) -> void:
	var h := hero_height()
	var w := minf(304+(text_scale-1)*78,view.x*0.43)
	_plate(Rect2(x,y,w,h),S.DEEP,S.LINE)
	_rule(Vector2(x+10,y),Vector2(x+w*0.5,y),S.GOLD)
	var center := Vector2(x+37,y+42*text_scale)
	var outer := PackedVector2Array([center+Vector2(0,-26),center+Vector2(24,-12),center+Vector2(21,14),center+Vector2(0,27),center+Vector2(-21,14),center+Vector2(-24,-12)])
	draw_colored_polygon(outer,S.RAISED)
	outer.append(outer[0])
	draw_polyline(outer,S.BRASS,2,true)
	S.icon(self,"attack",center-Vector2(17,17),34,S.GOLD)
	var left := x+72
	var width := w-88
	var growth: Dictionary = info.get("progression",{})
	_type(S.t("hero"),left,y+4,21,S.PAPER,width*0.70,HORIZONTAL_ALIGNMENT_LEFT,true)
	_type(S.t("level")%int(growth.get("level",1)),x+3,center.y+27,12,S.GOLD,68,HORIZONTAL_ALIGNMENT_CENTER,true)
	var gold_text := str(info.get("coins",0))
	var gw := body_font.get_string_size(gold_text,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(16*text_scale)).x
	if gw < width*0.5:
		S.icon(self,"coin",Vector2(x+w-gw-36,y+13),15,S.GOLD)
		_type(gold_text,x+w-gw-16,y+7,16,S.GOLD)
	var hp := int(info.get("hp",100))
	var maximum := maxi(1,int(info.get("max_hp",100)))
	var bar_y := y+55*text_scale
	draw_rect(Rect2(left,bar_y,width,7),S.RAISED)
	draw_rect(Rect2(left,bar_y,width*clampf(float(hp)/maximum,0,1),7),S.MINT if hp > maximum*0.3 else S.HOT)
	for n in range(1,5):
		_rule(Vector2(left+width*n/5.0,bar_y+1),Vector2(left+width*n/5.0,bar_y+7),S.DEEP)
	_type(S.t("hp"),left,y+32*text_scale,14,S.MUTED)
	_type("%d / %d" % [hp,maximum],left,y+32*text_scale,14,S.PAPER,width,HORIZONTAL_ALIGNMENT_RIGHT,true)
	var xp := int(growth.get("xp",0))
	var xp_next := int(growth.get("xp_next",0))
	var xp_y := y+95*text_scale
	_type(S.t("xp"),left,y+69*text_scale,14,S.MUTED)
	_type("%d / %d" % [xp,xp_next],left,y+69*text_scale,14,S.GOLD,width,HORIZONTAL_ALIGNMENT_RIGHT,true)
	draw_rect(Rect2(left,xp_y,width,4),S.RAISED)
	draw_rect(Rect2(left,xp_y,width*clampf(float(xp)/maxi(xp_next,1),0,1),4),S.GOLD)

func _location(margin: float, narrow: bool) -> void:
	var region := int(info.get("region",-1))
	var diff := int(info.get("difficulty",0))
	var w := minf(304+(text_scale-1)*150,view.x*(0.48 if narrow else 0.42))
	var x := view.x-margin-w
	var y := margin
	var world: Dictionary = info.get("world",{})
	var h := (79 if region < 0 else 109)*text_scale
	var accent: Color = S.GOLD if region < 0 else S.GEO[clampi(region,0,5)]
	_plate(Rect2(x,y,w,h),S.DEEP,S.LINE)
	_rule(Vector2(x+w*0.55,y),Vector2(x+w,y),accent)
	S.icon(self,"town" if region < 0 else ("forest" if region == 0 else "pin"),Vector2(x+13,y+13),25,accent)
	var title := S.t("town") if region < 0 else S.t("region%d"%region)
	_type(title,x+47,y+8,21,S.PAPER,w-120,HORIZONTAL_ALIGNMENT_LEFT,true)
	var status := S.t("town_sub") if region < 0 else S.t("diff%d"%diff)
	_type(status,x+8,y+13,14,accent,w-23,HORIZONTAL_ALIGNMENT_RIGHT)
	var hint := S.t("claim_hint") if info.get("first_merge",false) else S.t("first_hint")
	var quests: Array = info.get("quests",[])
	if not quests.is_empty() and quests[0].get("claimed",false):
		hint = S.t("ending") if info.get("ending",false) else S.t("depart_hint")
	if region < 0:
		_rule(Vector2(x+13,y+42*text_scale),Vector2(x+w-14,y+42*text_scale),S.LINE)
		S.icon(self,"track",Vector2(x+14,y+50*text_scale),17,accent)
		_type(hint,x+40,y+44*text_scale,16,S.PAPER,w-53)
		return
	var phase := str(world.get("phase","hunt"))
	if phase == "mini": hint = S.t("mini_hint") % S.t("mini%d"%region)
	elif phase == "boss": hint = S.t("boss_hint") % S.t("boss%d"%region)
	elif phase == "rest": hint = S.t("rest_hint") % int(world.get("rest",0))
	else: hint = S.t("collect_hint") if region==0 and not info.get("first_merge",false) else S.t("hunt_hint")
	_type(hint,x+14,y+43*text_scale,15,S.PAPER,w-28)
	var trace := clampi(int(world.get("trace",0)),0,12)
	var marks := clampi(int(world.get("minis",0)),0,2)
	_type("%s %d/12" % [S.t("track"),trace],x+14,y+68*text_scale,13,S.MUTED,w*0.55)
	_type("%s %d/2" % [S.t("mini_marks"),marks],x+w*0.5,y+68*text_scale,13,accent,w*0.5-14,HORIZONTAL_ALIGNMENT_RIGHT)
	var seg := (w-38)/12
	for i in range(12):
		draw_rect(Rect2(x+14+i*seg,y+h-10,seg-2.2,3.0),accent if i < trace else S.LINE)

func _boss(margin: float) -> void:
	var boss: Dictionary = info.get("boss",{})
	if boss.is_empty(): return
	var width := clampf(view.x*0.29,235,460)
	var x := (view.x-width)*0.5
	var right_edge := view.x-margin-minf(304+(text_scale-1)*150,view.x*0.48)
	var y := margin if x >= margin+318+(text_scale-1)*78 and x+width+10 <= right_edge else margin + hero_height()+8
	var h := 47*text_scale
	_plate(Rect2(x,y,width,h),S.DEEP,S.BRASS)
	_type(str(boss.get("name","")),x+7,y+3,17,S.GOLD,width-14,HORIZONTAL_ALIGNMENT_CENTER,true)
	var ratio := clampf(float(boss.get("hp",0))/maxf(1,float(boss.get("max_hp",1))),0,1)
	draw_rect(Rect2(x+11,y+h-11,width-22,5),S.RAISED)
	draw_rect(Rect2(x+11,y+h-11,(width-22)*ratio,5),S.HOT)

func skill_row_rect(frame: Vector2) -> Rect2:
	var ui_scale := clampf(frame.y / 780.0, 0.86, 1.35)
	var virtual_size := frame/ui_scale
	var width := minf((virtual_size.x-26)/5,(99 if virtual_size.x<1020 else 114)+78*(text_scale-1))
	var w := width*5+20
	var h := 75.0 + 22.0*(text_scale-1)
	return Rect2(Vector2((virtual_size.x-w)*0.5,virtual_size.y-h-18)*ui_scale,Vector2(w,h)*ui_scale)

func _skills() -> void:
	var rect := skill_row_rect(size)
	var width := (rect.size.x/factor-20)/5
	var gap := 5.0
	var h := rect.size.y/factor
	var y := rect.position.y/factor
	var start := rect.position.x/factor
	var cds: Dictionary = info.get("cooldowns",{})
	var loadout: Array = info.get("progression",{}).get("loadout",["hook","",""])
	var locked_hint := ""
	for i in range(SKILLS.size()):
		var action: String = SKILLS[i]
		var id := str(loadout[i-2]) if i>=2 else action
		var x := start+i*(width+gap)
		var locked := id.is_empty()
		var cd := float(cds.get(action,0))
		var tint := S.MUTED if locked else (S.GOLD if i==0 else S.MINT)
		_plate(Rect2(x,y,width,h),S.INK if locked else S.DEEP,S.LINE if locked else S.BRASS,5)
		if not locked:
			_rule(Vector2(x+6,y),Vector2(x+width-5,y),tint)
		S.icon(self,"skills" if locked else id,Vector2(x+width*0.5-12,y+8),30,tint.darkened(0.35) if locked else tint)
		var key: String = keys.get(action,"")
		var cap_w := minf(width*0.51,maxf(18,body_font.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+6))
		draw_rect(Rect2(x+4,y+4,cap_w,17),S.RAISED)
		draw_string(body_font,Vector2(x+4,y+17),key,HORIZONTAL_ALIGNMENT_CENTER,cap_w,13,S.PAPER)
		if locked:
			if Rect2(x,y,width,h).has_point(get_local_mouse_position()/factor): locked_hint = S.t("empty_skill_hint")%keys.get("skills","K")
		if cd > 0.01 and not locked:
			draw_rect(Rect2(x+width*0.5-23,y+9,46,28),S.INK)
			_type("%.1f" % cd,x+width*0.5-23,y+9,16,S.GOLD,46,HORIZONTAL_ALIGNMENT_CENTER,true)
		var skill_name := S.t("empty_slot" if locked else id)
		if i>=2 and not locked and body_font.get_string_size(skill_name,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(17*text_scale)).x > width-6:
			skill_name = S.t("short_"+id)
		_type(skill_name,x+3,y+h-30*text_scale,17,tint if not locked else S.MUTED,width-6,HORIZONTAL_ALIGNMENT_CENTER)

	if locked_hint!="" and message=="" and str(info.get("service","")).is_empty():
		var hint_width := body_font.get_string_size(locked_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(16*text_scale)).x+26
		var hint_y := y-44*text_scale
		_plate(Rect2((view.x-hint_width)*0.5,hint_y,hint_width,34*text_scale),S.DEEP,S.BRASS)
		_type(locked_hint,(view.x-hint_width)*0.5+13,hint_y+3,16,S.GOLD,hint_width-26)

func _controls(margin: float, narrow: bool) -> void:
	if narrow: return
	var move_keys := "%s%s%s%s" % [keys.get("move_up","W"),keys.get("move_left","A"),keys.get("move_down","S"),keys.get("move_right","D")]
	var w := minf((view.x-(114+78*(text_scale-1))*5-20)/2-margin-12,239*text_scale)
	if w < 136: return
	var y := view.y-51*text_scale
	var guide := "%s  %s   ·   %s" % [move_keys,S.t("move"),S.t("aim")]
	if body_font.get_string_size(guide,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(16*text_scale)).x+20>w:
		guide = "%s  %s" % [move_keys,S.t("move")]
	w = minf(w,body_font.get_string_size(guide,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(16*text_scale)).x+22)
	_plate(Rect2(margin,y,w,30*text_scale),S.DEEP,S.LINE,4)
	_type(guide,margin+10,y+2,16,S.MUTED,w-20)
