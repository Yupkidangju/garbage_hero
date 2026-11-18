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

func check_height_grid(region:int) -> void:
	var hill:=World.Height.ridge_center(region)
	check(World.Height.is_flat(Rect2(hill-Vector2(23,27),Vector2(1.4,1.4)),region),"능선 경계 상자 모서리의 평지")
	check(not World.Height.is_flat(Rect2(hill,Vector2.ONE),region),"능선의 실제 높이 표본 보존")
	if region in World.Height.BRIDGE_REGIONS:
		check(not World.Height.is_flat(Rect2(World.Layout.bridge_at(region),Vector2.ONE),region),"평지 위 다리 상판 보존")
	var error:=0.
	var unsafe:=0
	for z in range(-60,60,5):
		for x in range(-69,69,5):
			for uv:Vector2 in [Vector2(.13,.74),Vector2(.68,.65)]:
				var base:=Vector2(x,z)
				var weights:=Vector3(1-uv.x-uv.y, uv.x, uv.y)
				var a:=World.Height.sample_height(base,region)
				var b:=World.Height.sample_height(base+Vector2.RIGHT,region)
				var c:=World.Height.sample_height(base+Vector2.DOWN,region)
				if weights.x<0:
					a=World.Height.sample_height(base+Vector2.ONE,region)
					weights=Vector3(-weights.x,1.-uv.y,1.-uv.x)
				var expected:=weights.dot(Vector3(a,b,c))
				error=maxf(error,absf(World.Height.altitude(base+uv,region)-expected))
			var bounds:=Rect2(x+.22,z+.57,5.5,4.62)
			if World.Height.is_flat(bounds,region):
				for iz in range(floori(bounds.position.y),ceili(bounds.end.y)+1):
					for ix in range(floori(bounds.position.x),ceili(bounds.end.x)+1):
						if World.Height.sample_height(Vector2(ix,iz),region)>0.0: unsafe+=1
	check(error<.00001 and unsafe==0,"격자 표본 비교와 평면 판정 %d: %f, %d"%[region,error,unsafe])

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
			check_height_grid(region)
			check(data.bounds.size==Vector2(128,112) and data.landmarks.size()==4,"필드 크기와 랜드마크 %s"%region)
			check(world.entry_point().distance_to(world.boss_point())>85.0,"보스까지 실제 거리")
			for spot in data.landmarks:
				var anchor:=world.axes.to_global(Vector3(spot.pos.x,0,spot.pos.y))
				check(world.landmark_near(anchor)==spot.id,"랜드마크 발견 %s"%spot.id)
			check(world.landmark_near(world.entry_point()).is_empty(),"입구는 탐험 실적에서 제외한다")
			var summit:=World.Height.ridge_center(region)
			var crest:=world._floor_point(summit)
			check(crest.y>1.45 and not ray(state,crest).is_empty(),"능선 높이 %s"%region)
			for x:float in [0.0,1.90,-1.90,2.50]:
				var center:=World.Layout.bridge_at(region)
				var position:=world.axes.to_global(Vector3(center.x+x,0,center.y))
				var bridge_hit:=ray(state,position)
				check(not bridge_hit.is_empty() and absf(bridge_hit.position.y-world.ground_at(position))<.014,"다리 보행면 %s"%region)
			for branch:PackedVector2Array in data.routes:
				for index in branch.size()-1:
					var steps:=ceili(branch[index].distance_to(branch[index+1]))
					for j in steps:
						var uv:=World.Layout.road_at(branch,index,float(j)/steps)
						var point:=world._floor_point(uv)
						var floor_hit:=ray(state,point)
						check(not floor_hit.is_empty() and floor_hit.normal.y>.91,"갈림길 경사 %s %s"%[region,uv])
						if floor_hit.is_empty(): continue
						query.transform=Transform3D(Basis.IDENTITY,floor_hit.position+Vector3.UP*.82)
						check(state.intersect_shape(query,1).is_empty(),"갈림길 충돌 %s %s"%[region,uv])
			for direction:Vector2 in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				var edge:Vector2=direction*data.bounds.size*.5
				var inside:=world._floor_point(edge-direction*1.5)+Vector3.UP
				var outside:=world._floor_point(edge+direction*1.5)+Vector3.UP
				var wall:=PhysicsRayQueryParameters3D.create(inside,outside,1)
				check(not state.intersect_ray(wall).is_empty(),"필드 물리 경계 %s"%direction)
			var previous:=world.axes.to_global(Vector3(6,0,3))
			var recovered:=world.drop_point(previous)
			check(previous.distance_to(recovered)<6 and absf(recovered.y-world.ground_at(recovered))<.015,"기존 아이템 지면 복원")
			# 표석의 실제 기둥 가운데로 드롭을 주어 보정 전과 후의 물리 상태를 비교한다.
			var blocked:=world._floor_point(World.Layout.ENTRY+Vector2(-1.25,.85))
			query.transform=Transform3D(Basis.IDENTITY,blocked+Vector3.UP*.8)
			check(not state.intersect_shape(query,1).is_empty(),"보정 전 표석 충돌")
			var rescued:=world.drop_point(blocked)
			query.transform=Transform3D(Basis.IDENTITY,rescued+Vector3.UP*.8)
			check(state.intersect_shape(query,1).is_empty() and blocked.distance_to(rescued)<4,"장애물 옆으로 전리품 복원")
	world.queue_free()
	await process_frame
	print("world: %s checks, %s failures"%[checks,failures])
	quit(1 if failures else 0)
