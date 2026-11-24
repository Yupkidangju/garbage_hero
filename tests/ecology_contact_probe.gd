extends SceneTree
## 같은 배치로 복원한 41개체의 실제 move_and_slide 비용만 재는 진단이다.
const ACTORS:=41
const SAMPLES:=180
var main
var actors:Array=[]
var originals:Array[Vector3]=[]
var radii:Array[float]=[]
var heights:Array[float]=[]
var cylinders:Array[Shape3D]=[]
var capsules:Array[Shape3D]=[]
var height_spheres:Array[Shape3D]=[]
var radius_spheres:Array[Shape3D]=[]
var slot:DirAccess
var results:=[]
var _plane_installed:=false

func _initialize()->void:
	_run.call_deferred()

func stat(values:Array[float],part:float)->float:
	values.sort()
	return values[ceili(values.size()*part)-1]

func freeze()->void:
	main.player.set_physics_process(false)
	main.director.set_physics_process(false)
	for actor in actors: actor.set_physics_process(false)

func install(mode:String,mask:int)->void:
	if mode=="plane_cylinder" and not _plane_installed:
		print("CONTACT_ZERO_PLANE ",preload("res://../tests/terrain_collision_candidate.gd").install_zero_plane(main.world))
		_plane_installed=true
	for i in actors.size():
		var actor=actors[i]
		if mode=="height_sphere" or (mode=="mixed_sphere" and actor.kind!="boss"):
			actor.collider.shape=height_spheres[i]
			actor.collider.position.y=heights[i]*.5
		elif mode=="radius_sphere":
			actor.collider.shape=radius_spheres[i]
			actor.collider.position.y=radii[i]
		else:
			actor.collider.shape=capsules[i] if mode=="capsule" or (mode=="regular_capsule" and i<40) else cylinders[i]
			actor.collider.position.y=heights[i]*.5
		actor.collision_mask=mask
		actor.global_position=originals[i]
		actor.velocity=Vector3.ZERO

func _run()->void:
	print("CONTACT_ENGINE ",ProjectSettings.get_setting("physics/3d/physics_engine"))
	slot=DirAccess.create_temp("garbagehero-contact-probe")
	OS.set_environment("GARBAGEHERO_SAVE_DIR",slot.get_current_dir())
	Engine.max_fps=0
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.session._data.routes[22].cleared=true
	main.session._data.routes[23].phase="boss"
	main.session._data.first_merge=true
	main.session._data.routes[0].cleared=true
	main.session._data.progression=preload("res://data/progression.gd").from_legacy(true,true)
	main.session.act("depart",{"region":5,"difficulty":3})
	main._enter(5,3)
	if OS.get_cmdline_user_args().has("--merged-floor"):
		var candidate:=preload("res://../tests/terrain_collision_candidate.gd").build(5)
		for body in main.world.axes.get_children():
			if body is StaticBody3D and body.get_child_count()==1:
				var shape_node:=body.get_child(0) as CollisionShape3D
				if shape_node and shape_node.shape is ConcavePolygonShape3D and shape_node.shape.get_faces().size()>1000:
					shape_node.shape=candidate.shape
					print("CONTACT_MERGED_FLOOR ",candidate.triangles,"/",candidate.original_triangles)
	main.player.position=main.world.boss_point()+Vector3(0,0,2.5)
	main.director._physics_process(2.01)
	for actor in main.director.enemies: actors.append(actor)
	actors.append(main.director.boss)
	if actors.size()!=ACTORS or not is_instance_valid(actors.back()):
		push_error("Exactly41 actors are required")
		quit(1)
		return
	freeze()
	var largest:=0
	var total_shapes:=0
	var static_count:=0
	for body in main.world.find_children("*","StaticBody3D",true,false):
		static_count+=1
		var count:int=body.find_children("*","CollisionShape3D",true,false).size()
		total_shapes+=count
		largest=maxi(largest,count)
	print("CONTACT_WORLD ",JSON.stringify({"static_bodies":static_count,"total_shapes":total_shapes,"max_shapes_per_body":largest}))
	for i in actors.size():
		var actor=actors[i]
		if i<40:
			var angle:=TAU*(i%20)/20.
			actor.position=main.player.position+Vector3(cos(angle),0,sin(angle))*(3.4+3.*floorf(i/20.))
		else:
			actor.position=main.world.boss_point()
		actor.position.y=main.world.ground_at(actor.position)
		originals.append(actor.global_position)
		radii.append(actor.collider.shape.radius)
		heights.append(actor.collider.shape.height)
		cylinders.append(actor.collider.shape)
		var shape:=CapsuleShape3D.new()
		shape.radius=radii[i]
		shape.height=heights[i]
		capsules.append(shape)
		var height_sphere:=SphereShape3D.new()
		height_sphere.radius=heights[i]*.5
		height_spheres.append(height_sphere)
		var radius_sphere:=SphereShape3D.new()
		radius_sphere.radius=radii[i]
		radius_spheres.append(radius_sphere)
	await physics_frame
	await physics_frame
	var modes:=["cylinder","height_sphere","radius_sphere"] if OS.get_cmdline_user_args().has("--spheres") else ["cylinder","regular_capsule","capsule"]
	if OS.get_cmdline_user_args().has("--mixed-sphere"): modes=["cylinder","height_sphere","mixed_sphere"]
	if OS.get_cmdline_user_args().has("--plane-pair"): modes=["cylinder","plane_cylinder"]
	for mode in modes:
		for mask in [7,3]:
			install(mode,mask)
			await physics_frame
			await physics_frame
			for travel:float in [0.,.1]:
				var timings:Array[float]=[]
				var contacts:=0
				for sample in SAMPLES+20:
					for i in actors.size():
						actors[i].global_position=originals[i]
						var dir:Vector3=(main.player.position-originals[i])
						dir.y=0
						actors[i].velocity=dir.normalized()*(travel*60.)+Vector3.DOWN*.1
					var start:=Time.get_ticks_usec()
					for actor in actors:
						actor.move_and_slide()
					var elapsed:=Time.get_ticks_usec()-start
					if sample>=20:
						timings.append(elapsed/1000.)
						for actor in actors: contacts+=actor.get_slide_collision_count()
				var total:=0.
				for value in timings: total+=value
				var row:={"shape":mode,"mask":mask,"travel_m":travel,"actors":actors.size(),"samples":timings.size(),"average_ms":total/timings.size(),"median_ms":stat(timings,.5),"p95_ms":stat(timings,.95),"slide_collisions":contacts}
				results.append(row)
				print("CONTACT_FIXED ",JSON.stringify(row))
	print("CONTACT_COMPLETE ",JSON.stringify(results))
	await main.prepare_shutdown()
	main.free()
	quit()
