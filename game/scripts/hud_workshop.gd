extends Control

const S = preload("res://scripts/hud_style.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	var panel := S.texture("res://assets/ui/workshop_panel.png")
	if panel:
		draw_texture_rect(panel,Rect2(Vector2.ZERO,size),false,Color(1,1,1,0.24))
	var frame := S.texture("res://assets/ui/workshop_frame.png")
	if frame:
		# 그림은 가장자리 재료감에만 사용하고 본문 대비를 보존한다.
		draw_texture_rect_region(frame,Rect2(0,0,size.x,7),Rect2(0,0,frame.get_width(),32),Color(1,1,1,0.65))
	for at in [Vector2(7,7),Vector2(size.x-7,7),Vector2(7,size.y-7),size-Vector2(7,7)]:
		draw_circle(at,2.1,S.BRASS,true,-1,true)
		draw_line(at-Vector2(1,0),at+Vector2(1,0),S.DEEP,0.8,true)
	draw_line(Vector2(19,2),Vector2(size.x*0.31,2),S.GOLD,1.5,true)
	draw_line(Vector2(size.x*0.69,size.y-2),size-Vector2(19,2),S.BRASS,1.2,true)
