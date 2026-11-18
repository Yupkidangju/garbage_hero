extends Control

var hero: Node3D
var director
var world

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(director) or director.boss_key.is_empty() or not is_instance_valid(hero):
		return
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var target: Vector3 = world.boss_point()
	if is_instance_valid(director.boss):
		target = director.boss.global_position
	var distance := roundi(hero.global_position.distance_to(target))
	if distance < 5:
		return
	var origin := size * Vector2(0.5, 0.5)
	var direction := (camera.unproject_position(target) - origin).normalized()
	var center := origin + direction * minf(size.y * 0.30, 190.0)
	var font := get_theme_default_font()
	var caption := "%s  %dm" % [tr("FIELD_TARGET_MINI") if director.state.phase == "mini" else tr("FIELD_TARGET_BOSS"), distance]
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var gold := Color("#ffe5a0")
	draw_circle(center, 13.0, Color("#23332fee"), true, -1, true)
	draw_arc(center, 12.0, 0, TAU, 28, gold, 1.3, true)
	var normal := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([center + direction * 7, center - direction * 4 + normal * 4, center - direction * 4 - normal * 4]), gold)
	var base := center + Vector2(-width / 2, 28)
	draw_string_outline(font, base, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color("#25312b"))
	draw_string(font, base, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gold)
