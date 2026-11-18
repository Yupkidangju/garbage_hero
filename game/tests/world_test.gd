extends SceneTree

const World=preload("res://scripts/world.gd")
var failures:=0
var checks:=0

func _initialize() -> void:
	call_deferred("run")

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func ray(state:PhysicsDirectSpaceState3D,p:Vector3) -> Dictionary:
	var probe:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2.1,p-Vector3.UP)
	probe.collision_mask=1
	return state.intersect_ray(probe)

func run() -> void:
	var world:=World.new()
	root.add_child(world)
	var capsule:=CapsuleShape3D.new()
	capsule.height=1.52
	capsule.radius=.34
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule
	query.collision_mask=1
	for region in range(-1,6):
		world.build(region)
		await physics_frame
		await physics_frame
		var state:=world.get_world_3d().direct_space_state
		var locations:=world.spawn_points()
		var services:=world.service_points()
		var data:=world.map_data()
		check(data.roads is ImageTexture and data.roads.get_size()==Vector2(576,576),"지형 지도 텍스처 %s"%region)
		check(data.texture_bounds.encloses(data.bounds) and data.transform==world.axes.global_transform,"지도 경계와 좌표계 %s"%region)
		locations.append(world.entry_point())
		if region==-1:
			check(world.service_near(services.traveler)=="","방문하지 않은 이동상인")
			world.set_traveler_visible(true)
		else:
			check(locations.size()>=25,"고난도 등장 후보")
			locations.append(world.boss_point())
		for service:String in services:
			check(world.service_near(services[service])==service,"시설 상호작용 %s"%service)
			locations.append(services[service])
		for p:Vector3 in locations:
			var hit:=ray(state,p)
			check(not hit.is_empty() and absf(hit.position.y-p.y)<.023,"지면 높이 %s %s"%[region,p])
			query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.80)
			check(state.intersect_shape(query,1).is_empty(),"진입 지점 충돌 %s %s"%[region,p])
		if region>=0:
			var summit:=Vector3(6.15+.65*sin(region),0,-.68+.49*cos(region)).rotated(Vector3.UP,PI*.25)
			var crest:=ray(state,summit)
			check(not crest.is_empty() and crest.position.y>.36,"능선 높이 %s"%region)
			for x:float in [0.0,1.90,-1.90,2.50]:
				var bridge_sample:=World.Height.BRIDGE_ORIGIN+Vector3(x,0,0).rotated(Vector3.UP,World.Height.BRIDGE_YAW)
				var position:=world.axes.to_global(bridge_sample)
				var bridge_hit:=ray(state,position)
				check(not bridge_hit.is_empty() and absf(bridge_hit.position.y-world.ground_at(position))<.012,"다리 보행면 %s"%region)
			for branch:float in [-1.,1.]:
				for j in 51:
					var t:=float(j)/50.0
					var point:=Vector3(branch*sin(t*PI)*6.4,0,9.2-17.6*t).rotated(Vector3.UP,PI*.25)
					var floor_hit:=ray(state,point)
					check(not floor_hit.is_empty() and floor_hit.normal.y>.95,"갈림길 경사 %s %s"%[region,point])
					if floor_hit.is_empty(): continue
					query.transform=Transform3D(Basis.IDENTITY,floor_hit.position+Vector3.UP*.80)
					check(state.intersect_shape(query,1).is_empty(),"갈림길 충돌 %s %s"%[region,point])
	world.queue_free()
	await process_frame
	print("world: %s checks, %s failures"%[checks,failures])
	quit(1 if failures else 0)
