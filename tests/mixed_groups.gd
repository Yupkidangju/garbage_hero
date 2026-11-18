extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var slot := DirAccess.create_temp("garbagehero-formations")
	OS.set_environment("GARBAGEHERO_SAVE_DIR", slot.get_current_dir())
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var checked := 0
	var failures := 0
	for region in 6:
		main._enter(region, 1)
		var hunt = main.director
		for index in [0, 7]:
			var front = hunt.enemies[index]
			var rear = hunt.enemies[index+1]
			var types: Vector2i = hunt.PARTNERS[region]
			if front == null or rear == null or front.index != types.x or rear.index != types.y or front.position.distance_to(rear.position) > 5:
				failures += 1
				push_error("region=%d slots=%d/%d front=%s rear=%s"%[region,index,index+1,front.position if front else null,rear.position if rear else null])
			checked += 1
		var before:Dictionary=main.session.ui_state()
		var prior_ids:={}
		for actor in hunt.enemies:
			prior_ids[actor.spawn_id]=true
		var road:PackedVector2Array=main.world.map_data().routes[0]
		for i in road.size()-1:
			for j in range(1,5):
				var point:Vector2=main.world.Layout.road_at(road,i,float(j)/4)
				main.player.position=main.world._floor_point(point)
				hunt._fill_slots()
		for actor in hunt.enemies:
			if actor==null or prior_ids.has(actor.spawn_id) or actor.position.distance_to(main.player.position)>hunt.RETIRE_RADIUS:
				push_error("이동 후 사냥터 재배치 실패 %s"%region)
				failures+=1
				break
		main.player.position=main.world._floor_point(Vector2(63,55))
		hunt._fill_slots()
		var settled:int=hunt.spawn_counter
		for i in 12: hunt._fill_slots()
		if hunt.spawn_counter!=settled:
			push_error("필드 가장자리에서 정지 중인 개체가 반복 교체됨")
			failures+=1
		var after:Dictionary=main.session.ui_state()
		if before.progression!=after.progression or before.coins!=after.coins or hunt.state.trace!=0:
			push_error("지역 이동으로 사냥 보상 발생")
			failures+=1
		await process_frame
	main.queue_free()
	await process_frame
	print("MIXED_GROUPS pairs=%d failures=%d" % [checked, failures])
	quit(1 if failures > 0 else 0)
