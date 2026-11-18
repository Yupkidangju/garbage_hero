extends MeshInstance3D

signal struck(enemy: Node3D)

static var _meshes := {}
var _direction: Vector3
var _speed: float
var _remaining: float


func launch(style: String, origin: Vector3, direction: Vector3, speed: float, reach: float) -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_direction = direction.normalized()
	_speed = speed
	_remaining = reach
	global_position = origin
	look_at(origin + _direction)
	if not _meshes.has(style):
		_meshes[style] = _make_mesh(style)
	mesh = _meshes[style]


func _physics_process(delta: float) -> void:
	var step := minf(_remaining, _speed * delta)
	var destination := global_position + _direction * step
	# 한 물리 프레임보다 얇은 벽과 빠르게 접근하는 적도 가장 가까운 충돌에서 멈춘다.
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, 1 | 4)
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var enemy := hit.collider as Node3D
		if enemy != null and enemy.is_in_group("enemies"):
			struck.emit(enemy)
		queue_free()
		return
	global_position = destination
	_remaining -= step
	if _remaining <= 0.0:
		queue_free()


static func _make_mesh(style: String) -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	if style == "bow":
		_facets(builder, -0.30, -0.13, 0.0, 0.068, Color("#ffd078"))
		_facets(builder, -0.13, -0.10, 0.068, 0.018, Color("#f8e7bf"))
		_facets(builder, -0.10, 0.30, 0.018, 0.018, Color("#a87542"))
		_facets(builder, 0.22, 0.36, 0.022, 0.065, Color("#f2aa55"))
	else:
		var color := Color("#71e9ff") if style == "staff" else Color("#ffcb78")
		var width := 0.115 if style == "staff" else 0.079
		_facets(builder, -0.26, 0.0, 0.0, width, color.lightened(0.45))
		_facets(builder, 0.0, 0.33, width, 0.0, color.darkened(0.18))
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	builder.set_material(paint)
	return builder.commit()


static func _facets(builder: SurfaceTool, z0: float, z1: float, r0: float, r1: float, tint: Color) -> void:
	for i in 6:
		var a := Vector3(cos(i*TAU/6), sin(i*TAU/6), 0)
		var b := Vector3(cos((i+1)*TAU/6), sin((i+1)*TAU/6), 0)
		var near_a := a*r0 + Vector3.BACK*z0
		var near_b := b*r0 + Vector3.BACK*z0
		var far_a := a*r1 + Vector3.BACK*z1
		var far_b := b*r1 + Vector3.BACK*z1
		builder.set_color(tint.darkened(0.12 * (i%3)))
		for vertex in [near_a, far_a, far_b, near_a, far_b, near_b]:
			builder.add_vertex(vertex)
