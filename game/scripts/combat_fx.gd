extends Node3D

const MINT := Color("#7ee9d0")
const CREAM := Color("#fff2bb")
const AMBER := Color("#ffd46d")
const IMPACT := Color("#ff8d69")
var reduced_flash := false
var _mesh := ImmediateMesh.new()
var _ink := StandardMaterial3D.new()
var _effects: Array[Dictionary] = []
var _trail: Array[Dictionary] = []
var ribbon_live := false
var _labels: Array[Label3D] = []
var _grade := 0
var _blade_base := Vector3.ZERO
var _blade_tip := Vector3.ZERO
var _clock := 0.0


func _ready() -> void:
	var canvas := MeshInstance3D.new()
	canvas.mesh = _mesh
	canvas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ink.vertex_color_use_as_albedo = true
	_ink.vertex_color_is_srgb = true
	_ink.render_priority = 3
	add_child(canvas)


func begin_ribbon() -> void:
	_trail.clear()
	ribbon_live = true


func enchanted_blade(grade: int, base: Vector3, tip: Vector3) -> void:
	_grade = grade
	_blade_base = base
	_blade_tip = tip


func blade_sample(base: Vector3, tip: Vector3) -> void:
	if ribbon_live:
		_trail.append({"root":base, "tip":tip, "life":0.105})


func end_ribbon() -> void:
	ribbon_live = false


func interrupt() -> void:
	end_ribbon()
	_trail.clear()
	for i in range(_effects.size()-1, -1, -1):
		if _effects[i].kind in ["hook","spin","arc"]:
			_effects.remove_at(i)
	_mesh.clear_surfaces()


func _effect(kind: String, origin: Vector3, direction: Vector3, duration: float,
		radius: float, color: Color, variation := 0) -> void:
	_effects.append({"kind":kind, "origin":origin, "direction":direction, "age":0.0,
		"duration":duration, "radius":radius, "color":color, "variation":variation})


func strike(origin: Vector3, direction: Vector3, step: int, reach: float) -> void:
	_effect("arc", origin, direction, 0.16, reach, MINT, step)


func hook(origin: Vector3, direction: Vector3, length: float) -> void:
	_effect("hook", origin, direction, 0.27, length, MINT)


func spin(origin: Vector3, direction: Vector3, beat: int, reach := 2.4) -> void:
	_effect("spin", origin, direction, 0.23, reach, MINT, beat)


func slam(origin: Vector3, direction: Vector3, reach := 2.8) -> void:
	_effect("ring", origin + direction * reach*0.55 + Vector3.UP * 0.08, direction, 0.36, reach*0.5, AMBER)
	_effect("sparks", origin + direction * reach*0.54 + Vector3.UP * 0.08, direction, 0.32, reach*0.39, CREAM)


func thrust(origin: Vector3, direction: Vector3, reach: float) -> void:
	_effect("thrust", origin + Vector3.UP * 0.66, direction, 0.12, reach, CREAM)


func nova(origin: Vector3, direction: Vector3, reach: float) -> void:
	_effect("ring", origin + Vector3.UP * 0.13, direction, 0.32, reach, Color("#80dcff"))
	_effect("sparks", origin + Vector3.UP * 0.24, direction, 0.32, reach*0.82, MINT)


func dust(origin: Vector3, direction: Vector3) -> void:
	_effect("sparks", origin + Vector3.UP * 0.09, direction, 0.24, 0.56, MINT)


func footfall(origin: Vector3, direction: Vector3, surface: String, wet: bool) -> void:
	if surface == "shallow":
		_effect("ripple",origin+Vector3.UP*0.055,direction,0.62,0.45,Color("#b8dfd8",0.48))
	elif surface == "swamp":
		_effect("footprint",origin+Vector3.UP*0.04,direction,1.15,0.12,Color("#354d35",0.55))
	elif wet:
		_effect("footprint",origin+Vector3.UP*0.04,direction,0.85,0.085,Color("#516c68",0.34))


func impact(origin: Vector3, direction: Vector3, amount: int, critical: bool, hurt := false) -> void:
	var color := IMPACT if hurt else (AMBER if critical else CREAM)
	_effect("sparks", origin, direction, 0.22, 0.72 if critical else 0.48, color)
	var label: Label3D
	for existing in _labels:
		if not existing.visible:
			label = existing
			break
	if label == null:
		if _labels.size() >= 20:
			return
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 54
		label.outline_size = 13
		label.outline_modulate = Color("#302d33")
		label.pixel_size = 0.005
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(label)
		_labels.append(label)
	label.text = ("−" if hurt else "") + str(amount) + ("!" if critical else "")
	label.modulate = color
	label.position = origin + Vector3.UP * 0.45
	label.scale = Vector3.ONE * (1.2 if critical else 1.0)
	label.show()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.65, 0.54).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.2).set_delay(0.34)
	tween.chain().tween_callback(label.hide)


func _process(delta: float) -> void:
	_clock += delta
	for i in range(_effects.size()-1, -1, -1):
		var effect := _effects[i]
		effect.age += delta
		if effect.age >= effect.duration:
			_effects.remove_at(i)
	for i in range(_trail.size()-1, -1, -1):
		_trail[i].life -= delta
		if _trail[i].life <= 0:
			_trail.remove_at(i)
	_mesh.clear_surfaces()
	if _effects.is_empty() and _trail.size() < 2 and _grade < 5:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _ink)
	if _grade >= 5:
		_draw_enchantment()
	for i in range(1, _trail.size()):
		var old := _trail[i-1]
		var cur := _trail[i]
		var alpha := minf(1.0, float(cur.life) / 0.105)
		_quad(old.root, old.tip, cur.tip, cur.root, _tint(MINT, alpha * 0.72))
		var tip_old: Vector3 = old.tip
		var tip_cur: Vector3 = cur.tip
		_quad(tip_old.lerp(old.root, 0.1), tip_old, tip_cur, tip_cur.lerp(cur.root, 0.1), _tint(CREAM, alpha))
	for effect in _effects:
		_draw_effect(effect)
	_mesh.surface_end()


func _draw_enchantment() -> void:
	var axis := (_blade_tip - _blade_base).normalized()
	var tangent := axis.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = axis.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var other := axis.cross(tangent)
	for i in 10:
		var u := i / 10.0
		var v := (i+1) / 10.0
		var a := _blade_base.lerp(_blade_tip, u) + tangent * sin(u*TAU + _clock*3.0)*0.075
		var b := _blade_base.lerp(_blade_tip, v) + tangent * sin(v*TAU + _clock*3.0)*0.075
		_line(a,b,other,0.046,_tint(MINT,0.8))
	if _grade < 6:
		return
	for i in 3:
		var angle := _clock*2.5 + i*TAU/3.0
		var spread := 0.11 + sin(_clock*2.0)*0.06
		var center := _blade_tip + (tangent*cos(angle) + other*sin(angle))*spread
		_quad(center-axis*0.065,center+tangent*0.025,center+axis*0.065,center-tangent*0.025,_tint(AMBER,0.9))


func _tint(color: Color, alpha: float) -> Color:
	return Color(color, clampf(alpha * (0.58 if reduced_flash else 1.0), 0.0, 1.0))


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_add_vertex(b)
	_mesh.surface_add_vertex(c)
	_mesh.surface_add_vertex(a)
	_mesh.surface_add_vertex(c)
	_mesh.surface_add_vertex(d)


func _line(a: Vector3, b: Vector3, axis: Vector3, width: float, color: Color) -> void:
	var edge := axis * width * 0.5
	_quad(a-edge, a+edge, b+edge*0.55, b-edge*0.55, color)


func _draw_effect(e: Dictionary) -> void:
	var t := float(e.age) / float(e.duration)
	var origin: Vector3 = e.origin
	var direction: Vector3 = e.direction
	var right := direction.cross(Vector3.UP).normalized()
	var radius := float(e.radius)
	var color := _tint(e.color, pow(1.0-t, 0.7))
	match e.kind:
		"ripple":
			var r := 0.07+t*radius
			for i in 24:
				var a := direction.rotated(Vector3.UP,float(i)*TAU/24.0)
				var b := direction.rotated(Vector3.UP,float(i+1)*TAU/24.0)
				_quad(origin+a*r,origin+b*r,origin+b*(r+0.016),origin+a*(r+0.016),color)
		"footprint":
			var toe := origin+direction*radius
			var heel := origin-direction*radius*0.7
			_quad(heel-right*radius*0.4,toe-right*radius*0.52,toe+right*radius*0.52,heel+right*radius*0.4,color)
		"thrust":
			var tip := origin + direction * (0.7 + t*0.3) * radius
			var mid := tip - direction * (1.0-t)*radius*0.55
			_quad(mid + right*0.055, tip, mid-right*0.055, origin + direction*0.35, color)
		"arc", "spin":
			var spinning: bool = e.kind == "spin"
			var side := -1.0 if e.variation == 2 else 1.0
			var length := 2.65 if spinning else 1.38
			var phase := t * TAU + float(e.variation) * PI if spinning else t * 0.6
			for i in 21:
				var u := i / 21.0
				var v := (i + 1) / 21.0
				var ra := direction.rotated(Vector3.UP, (u*length-length*0.5+phase)*side)
				var rb := direction.rotated(Vector3.UP, (v*length-length*0.5+phase)*side)
				var height := 0.47 if spinning else 0.82
				var a := origin + ra * radius + Vector3.UP * (height + u * 0.28 * side)
				var b := origin + rb * radius + Vector3.UP * (height + v * 0.28 * side)
				if e.kind == "arc" and e.variation == 3:
					a = origin + direction * (radius * sin(0.35+u*1.3)) + Vector3.UP * (1.78-u*1.62)
					b = origin + direction * (radius * sin(0.35+v*1.3)) + Vector3.UP * (1.78-v*1.62)
				_quad(a, b, b-rb*sin(v*PI)*0.16, a-ra*sin(u*PI)*0.16, color)
		"ring":
			var r := maxf(0.08, sin(t*PI/2.0)*radius)
			for i in 36:
				var ra := direction.rotated(Vector3.UP, i*TAU/36.0)
				var rb := direction.rotated(Vector3.UP, (i+0.9)*TAU/36.0)
				_quad(origin+ra*r, origin+rb*r, origin+rb*r*0.89, origin+ra*r*0.89, color)
		"hook":
			var stretch := minf(t / 0.22, 1.0) * (1.0 - maxf(0.0, (t-0.58) / 0.42))
			var tip := origin + direction * maxf(0.12, radius * stretch)
			_line(origin, tip, Vector3.UP, 0.055, color)
			for i in range(1, maxi(1, int(origin.distance_to(tip) / 0.34))):
				var center := origin + direction * i * 0.34
				_line(center-right*0.052, center+right*0.052, Vector3.UP, 0.075, _tint(CREAM,1.0-t))
			for sign_value in [-1.0,1.0]:
				_line(tip + right * float(sign_value)*0.015, tip - direction*0.23 + right*float(sign_value)*0.17, Vector3.UP, 0.1, color)
		"sparks":
			for i in 7:
				var outward := direction.rotated(Vector3.UP, i*TAU/7.0)
				var ray := (outward + Vector3.UP * (0.3 + (i%3)*0.28)).normalized()
				var tip := origin + ray * radius * (0.15 + t)
				var base := tip - ray * (1.0-t) * radius * 0.46
				_line(base, tip, outward.cross(Vector3.UP), 0.065*(1.0-t), color)
