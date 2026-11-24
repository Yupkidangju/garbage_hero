extends SceneTree
const World=preload("res://scripts/world.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	print("TERRAIN_PROBE_ENGINE ",ProjectSettings.get_setting("physics/3d/physics_engine"))
	var world:=World.new()
	root.add_child(world)
	world.build(0)
	await physics_frame
	await physics_frame
	var state:=world.get_world_3d().direct_space_state
	for center:Vector2 in [Vector2(40,4),Vector2(-34,17),Vector2(64,26),Vector2(10.25,9.75)]:
		for epsilon:float in [0.,-.001,.001]:
			var p:=world._floor_point(center+Vector2.ONE*epsilon)
			var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2.1,p-Vector3.UP,1)
			print("JOLT_RAY ",center," ",epsilon," ",state.intersect_ray(query))
	var terrain_body:StaticBody3D
	for body in world.axes.get_children():
		if body is StaticBody3D and body.get_child_count()==1:
			var collision:=body.get_child(0) as CollisionShape3D
			if collision and collision.shape is ConcavePolygonShape3D and collision.shape.get_faces().size()>1000:
				terrain_body=body
	var collider:=terrain_body.get_child(0) as CollisionShape3D
	var excluded:Array[RID]=[]
	for body:StaticBody3D in world.find_children("*","StaticBody3D",true,false):
		if body!=terrain_body: excluded.append(body.get_rid())
	for variant in [0,1,2]:
		var rotated:bool=variant==1
		var shape:=HeightMapShape3D.new()
		var values:=World.Height.samples(0).heights
		if rotated:
			var reversed:=PackedFloat32Array()
			reversed.resize(values.size())
			for row in World.Height.WIDTH:
				for col in World.Height.DEPTH:
					reversed[row*World.Height.DEPTH+col]=values[(World.Height.DEPTH-1-col)*World.Height.WIDTH+row]
			shape.map_width=World.Height.DEPTH
			shape.map_depth=World.Height.WIDTH
			shape.map_data=reversed
			collider.rotation.y=PI*.5
		else:
			shape.map_width=World.Height.WIDTH
			shape.map_depth=World.Height.DEPTH
			shape.map_data=values
			collider.rotation.y=0
		collider.shape=preload("res://../tests/terrain_collision_candidate.gd").build(0).shape if variant==2 else shape
		if variant==2: collider.rotation.y=0
		await physics_frame
		await physics_frame
		var missing:=0
		var worst:=0.0
		var count:=0
		for z in range(-100,101,10):
			for x in range(-120,121,10):
				for fraction:Vector2 in [Vector2.ZERO,Vector2(.13,.74),Vector2(.68,.65)]:
					var point:=world._floor_point(Vector2(x,z)+fraction)
					var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*2.1,point-Vector3.UP,1,excluded)
					var hit:=state.intersect_ray(query)
					count+=1
					if hit.is_empty(): missing+=1
					else: worst=maxf(worst,absf(hit.position.y-point.y))
		print("TERRAIN_SHAPE_PROBE variant=",variant," samples=",count," missing=",missing," max_height_error=",worst)
	world.free()
	quit()
