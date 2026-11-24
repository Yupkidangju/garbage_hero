extends "res://../tests/field_performance.gd"
## 원본 40+1 장면·입력·물리를 유지하는 3+12초 비용 분해.

var diag:Dictionary={"gpu":[],"render_cpu":[],"process":[],"physics":[],"draws":[],"triangles":[]}
var _shape_probed:=false
var _frame_only:=false

func _start() -> void:
	_frame_only=OS.get_cmdline_user_args().has("--frame-only")
	print("PERF030_ENGINE ",ProjectSettings.get_setting("physics/3d/physics_engine")," server=",PhysicsServer3D.get_class())
	super._start()
	if DisplayServer.get_name()=="headless": Engine.max_fps=144
	if OS.get_cmdline_user_args().has("--flora-split"):
		split_flora_compound()
	if OS.get_cmdline_user_args().has("--merged-floor"):
		merge_floor()
	if not _frame_only: RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)

func merge_floor() -> void:
	var candidate:=preload("res://../tests/terrain_collision_candidate.gd").build(main.world.region)
	for body in main.world.axes.get_children():
		if body is StaticBody3D and body.get_child_count()==1:
			var collision:=body.get_child(0) as CollisionShape3D
			if collision and collision.shape is ConcavePolygonShape3D and collision.shape.get_faces().size()>1000:
				collision.shape=candidate.shape
				print("PERF030_FLOOR ",candidate.triangles,"/",candidate.original_triangles," triangles flat_rectangles=",candidate.flat_rectangles)
				return
	assert(false,"terrain collider found")

func _combat() -> void:
	super._combat()
	if not positioned or _shape_probed: return
	_shape_probed=true
	var args:=OS.get_cmdline_user_args()
	if not args.has("--capsules") and not args.has("--normal-capsules"): return
	var count:=0
	for actor in get_nodes_in_group("enemies"):
		if args.has("--normal-capsules") and actor.kind!="normal": continue
		var previous:Variant=actor.collider.shape
		var capsule:=CapsuleShape3D.new()
		capsule.radius=previous.radius
		capsule.height=previous.height
		actor.collider.shape=capsule
		count+=1
	print("PERF030_COLLIDERS capsules=",count)

func split_flora_compound() -> void:
	var biggest:StaticBody3D
	var most:=0
	for node in main.world.axes.get_children():
		if node is StaticBody3D and node.get_child_count()>most:
			most=node.get_child_count()
			biggest=node
	assert(most>100,"flora compound found")
	assert(biggest.transform.is_equal_approx(Transform3D.IDENTITY),"unchanged compound frame")
	var bodies:Dictionary={}
	var count:=0
	for child:CollisionShape3D in biggest.get_children():
		var before:=child.global_transform
		var cell:=Vector2i(floori(child.position.x/24),floori(child.position.z/24))
		if not bodies.has(cell):
			var body:=StaticBody3D.new()
			body.collision_mask=biggest.collision_mask
			body.collision_layer=biggest.collision_layer
			main.world.axes.add_child(body)
			bodies[cell]=body
		biggest.remove_child(child)
		bodies[cell].add_child(child)
		assert(child.global_transform.is_equal_approx(before),"every static collider retains its world pose")
		count+=1
	biggest.queue_free()
	print("PERF030_FLORA_SPLIT shapes=",count," bodies=",bodies.size())

func _process(_delta:float) -> bool:
	if finishing: return false
	if not positioned:
		if Time.get_ticks_msec()>90000:
			push_error("41 combatants did not become active")
			quit(2)
		return false
	var now:=Time.get_ticks_usec()
	var seconds:=(now-clock_start)/1000000.0
	if seconds>=3.0:
		frames.append((now-previous)/1000.0)
		if not _frame_only:
			diag.gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			diag.render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			diag.process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			diag.physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			diag.draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			diag.triangles.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	previous=now
	if seconds<15.0: return false
	finishing=true
	for key:String in diag:
		var values:Array=diag[key]
		if values.is_empty(): continue
		values.sort()
		print("PERF030_COMPONENT ",key," median ",values[values.size()/2]," p95 ",values[ceili(values.size()*.95)-1])
	frames.sort()
	print("PERF030_PROBE ",JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),
		"renderer":RenderingServer.get_current_rendering_method(),"size":str(root.size),
		"warmup_s":3,"sample_s":12,"frames":frames.size(),"min_actors":smallest_count,
		"median_ms":frames[frames.size()/2],"p95_ms":frames[ceili(frames.size()*.95)-1]}))
	_finish.call_deferred()
	return false
