extends Control

const MapText=preload("res://data/map_ko.tres")
var hero: Node3D
var director
var world

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(director) or not is_instance_valid(hero):
		return
	var camera:=get_viewport().get_camera_3d()
	if not camera: return
	var home:Vector3=world.entry_point()
	if hero.global_position.distance_to(home)>12.0:
		_arrow(camera,home,MapText.get_message("return_marker"),Color("#a9dfc9"),.24)
	if director.boss_key.is_empty():
		return
	var target:Vector3=director.boss.global_position if is_instance_valid(director.boss) else world.boss_point()
	if hero.global_position.distance_to(target)>=5:
		var title:=tr("FIELD_TARGET_MINI") if director.state.phase=="mini" else tr("FIELD_TARGET_BOSS")
		_arrow(camera,target,title,Color("#ffe5a0"),.33)

func _arrow(camera:Camera3D,target:Vector3,title:String,tint:Color,reach:float) -> void:
	var origin:=size*.5
	var direction:=(camera.unproject_position(target)-camera.unproject_position(hero.global_position)).normalized()
	var center:=origin+direction*minf(size.y*reach,640.0*reach)
	var font:=get_theme_default_font()
	var distance:=roundi(hero.global_position.distance_to(target))
	var caption:="%s  %dm"%[title,distance]
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_circle(center, 13.0, Color("#23332fee"), true, -1, true)
	draw_arc(center, 12.0, 0, TAU, 28, tint, 1.3, true)
	var normal := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([center + direction * 7, center - direction * 4 + normal * 4, center - direction * 4 - normal * 4]), tint)
	var base := center + Vector2(-width / 2, 28)
	draw_string_outline(font, base, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color("#25312b"))
	draw_string(font, base, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint)
