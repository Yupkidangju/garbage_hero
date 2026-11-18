extends Control

# 마차 목적지마다 바뀌는 목판화. 능선과 길의 형태는 메뉴용 삽화다.
const S = preload("res://scripts/hud_style.gd")
const SKY = [Color("#aac3a9"),Color("#deb37b"),Color("#aaa3bc"),Color("#81b5aa"),Color("#a6c6d6"),Color("#d38b72")]
const LAND = [Color("#36574b"),Color("#916348"),Color("#514b61"),Color("#365951"),Color("#506473"),Color("#5e4444")]
var region := 0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size.y = 116

func _shape(coords: Array, paint: Color) -> void:
	var points := PackedVector2Array()
	for i in range(0,coords.size(),2):
		points.append(Vector2(coords[i],coords[i+1]))
	draw_colored_polygon(points,paint)

func _draw() -> void:
	if size.x<1: return
	var sky: Color = SKY[region]
	var land: Color = LAND[region]
	draw_set_transform(Vector2.ZERO,0,size/Vector2(400,116))
	draw_rect(Rect2(0,0,400,116),sky)
	for i in range(8):
		draw_circle(Vector2(318,33),19-i*1.8,sky.lerp(S.PAPER,0.55+i*0.012),true,-1,true)
	if region in [1,4,5]:
		_shape([0,77,50,56,88,62,143,24,185,63,239,38,278,54,337,14,400,57,400,116,0,116],sky.lerp(land,0.45))
		_shape([96,63,143,24,171,52,149,43,142,48,133,41],sky.lightened(0.28))
		_shape([294,50,337,14,361,31,342,28,336,32,329,26],sky.lightened(0.25))
	else:
		_shape([0,66,29,52,71,54,99,40,142,38,183,56,220,48,253,50,280,37,317,38,345,30,400,41,400,116,0,116],sky.lerp(land,0.38))
	_shape([0,78,43,62,79,66,131,58,169,72,207,69,251,59,279,70,315,62,356,63,400,53,400,116,0,116],land.lightened(0.17))
	_shape([0,86,58,77,96,81,145,75,208,89,255,73,312,81,360,76,400,80,400,116,0,116],land)
	_shape([185,116,232,94,224,88,230,81,255,73,236,82,232,88,248,95,221,116],sky.lerp(S.GOLD,0.36))
	if region in [0,4]:
		for p in [[20,92,43],[45,83,27],[69,88,34],[347,83,29],[372,87,42],[392,91,34]]:
			var x: float = p[0]
			var y: float = p[1]
			var h: float = p[2]
			_shape([x,y-h,x-h*0.2,y-h*0.54,x-h*0.09,y-h*0.56,x-h*0.32,y-h*0.13,x-h*0.08,y-h*0.16,x-h*0.07,y,x+h*0.07,y,x+h*0.07,y-h*0.16,x+h*0.31,y-h*0.14,x+h*0.09,y-h*0.57,x+h*0.19,y-h*0.54],land.darkened(0.19))
	elif region==1:
		for p in [[43,32],[69,16],[367,24]]:
			var x: float = p[0]
			var h: float = p[1]
			_shape([x,90,x,90-h,x+4,88-h,x+4,76,x+10,75,x+10,68,x+14,67,x+14,77,x+5,80,x+5,90],land.darkened(0.24))
	elif region==2:
		for p in [[42,37],[68,24],[349,19],[373,32]]:
			var x: float = p[0]
			var h: float = p[1]
			_shape([x,88,x,94-h,x+5,88-h,x+11,94-h,x+11,88],land.darkened(0.26))
	elif region==3:
		for base in [22,40,68,343,362,381]:
			for n in range(4):
				var x: float = base+n*1.8
				var h := 15+posmod(base*n,19)
				draw_line(Vector2(x,92),Vector2(x+(n-2)*3,92-h),land.darkened(0.25),2,true)
	else:
		for p in [[24,88,31],[54,87,19],[355,83,16],[384,90,37]]:
			var x: float = p[0]
			var y: float = p[1]
			var h: float = p[2]
			_shape([x-h*0.3,y,x-h*0.2,y-h*0.5,x+h*0.06,y-h,x+h*0.22,y-h*0.4,x+h*0.4,y],land.darkened(0.25))
	for i in range(17):
		var x := fmod(i*57.0+7.0,400.0)
		var y := 97.0 + fmod(i*21.0,18.0)
		draw_line(Vector2(x,y),Vector2(x+3+i%6,y-1),sky.lerp(land,0.6),1)
