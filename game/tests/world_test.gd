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
	for z in range(-114,115,7):
		for x in range(-130,131,7):
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
			for i in world.sites.size():
				var anchor:Vector2=world._site_anchors[i]
				var local:=world.axes.to_local(world.sites[i])
				var start:=Vector2(local.x,local.z)
				for j in 9:
					var approach:=world._floor_point(start.lerp(anchor,float(j)/8))
					query.transform=Transform3D(Basis.IDENTITY,approach+Vector3.UP*.82)
					check(state.intersect_shape(query,1).is_empty(),"모든 출현점의 길 연결 %s %s %s"%[region,i,approach])
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
			check(data.bounds.size==Vector2(256,224) and data.landmarks.size()==5,"필드 크기와 랜드마크 %s"%region)
			check(data.districts.size()==5 and data.caches.size()==3,"다섯 소지역과 보물함 %s"%region)
			for district in world.district_points():
				check(world.district_at(district.pos)==district.id,"소지역 중심 일치 %s"%district.id)
				check(world.surface_at(district.pos).walkable,"소지역 중심 통행 %s"%district.id)
			for cache in world.cache_points():
				check(World.Layout.valid_cache(region,cache.id) and world.cache_near(cache.pos)==cache.id,"보물 ID와 접근 %s"%cache.id)
				check(world.surface_at(cache.pos).walkable,"보물함의 보행면 %s"%cache.id)
				query.transform=Transform3D(Basis.IDENTITY,cache.pos+Vector3.UP*.8)
				check(state.intersect_shape(query,1).is_empty(),"보물함 접근 충돌 %s"%cache.id)
				var chest:Vector3=cache.pos+world.axes.global_basis*Vector3(0,0,-1.4)
				chest.y=world.ground_at(chest)
				query.transform=Transform3D(Basis.IDENTITY,chest+Vector3.UP*.8)
				check(not state.intersect_shape(query,1).is_empty(),"보물함 실물과 충돌 높이 %s"%cache.id)
			check_water(world,state,region)
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
						check(not floor_hit.is_empty() and floor_hit.normal.y>.91,"갈림길 경사 %s %s hit=%s"%[region,uv,floor_hit])
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

func check_water(world:World,state:PhysicsDirectSpaceState3D,region:int) -> void:
	# 렌더된 수면 정점까지 검사해 지형 원점 높이를 두 번 더하는 오류를 잡는다.
	var water_color:=Color(["376f79","507f81","376f79","376f79","548caa","466965"][region])
	var rendered:=world.axes.get_node("Water_%d_river/Paint_0_0_0"%region) as MeshInstance3D
	var arrays:=rendered.mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var error:=0.0
	var count:=0
	for i in vertices.size():
		if not colors[i].is_equal_approx(water_color): continue
		count+=1
		var v:=vertices[i]
		error=maxf(error,absf(v.y-World.Height.altitude(Vector2(v.x,v.z),region)-.052))
	check(count>100 and error<.00001,"렌더 수면과 지형 원점 일치 %s %s"%[region,error])
	var center:=World.Layout.deep_rect(region).get_center()
	var deep:=world._floor_point(Vector2(center.x,0))
	var shallow:=world._floor_point(Vector2(center.x+6,0))
	check(world.surface_at(deep).kind=="deep" and not world.surface_at(deep).walkable,"깊은물 통행 금지 %s"%region)
	check(world.surface_at(shallow).kind=="shallow" and is_equal_approx(world.surface_at(shallow).speed,.7),"얕은물 70퍼센트 %s"%region)
	for z:float in [-34,51]:
		var start:=world._floor_point(Vector2(center.x+9,z))
		var delta:=world.axes.global_basis*Vector3(-18,0,0)
		var actual:Vector3=world.constrain_motion(start,delta,.34)
		check(actual.distance_to(delta)<.005,"다리와 여울 통행 %s %s"%[region,z])
		var hit:=ray(state,world._floor_point(Vector2(center.x,z)))
		check(not hit.is_empty() and absf(hit.position.y-world.ground_at(world._floor_point(Vector2(center.x,z))))<.014,"새 다리와 여울 높이 %s %s"%[region,z])
	var origin:=world._floor_point(Vector2(center.x+9,0))
	var movement:=world.axes.global_basis*Vector3(-22,0,0)
	var clipped:Vector3=world.constrain_motion(origin,movement,.34)
	check(clipped.length()<4.0 and world.surface_at(origin+clipped).walkable,"큰 돌진과 넉백의 수변 차단 %s"%region)
	var across:=PhysicsRayQueryParameters3D.create(origin+Vector3.UP*.8,origin+movement+Vector3.UP*.8,1)
	check(not state.intersect_ray(across).is_empty(),"깊은물 실제 정적 충돌 %s"%region)
	var recovery:=world.drop_point(deep)
	check(world.surface_at(recovery).walkable and recovery.distance_to(deep)<9,"물속 구형 전리품 복원 %s"%region)
	if region==3:
		var swamp:=world._floor_point(Vector2(70,20))
		check(world.surface_at(swamp).kind=="swamp" and is_equal_approx(world.surface_at(swamp).speed,.6),"늪 60퍼센트")
