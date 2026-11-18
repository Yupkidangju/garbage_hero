extends SceneTree

func _initialize() -> void:
	call_deferred("_walk")

func _walk() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	world.build(0)
	var hero = load("res://scripts/player.gd").new()
	hero.position = world.entry_point()
	root.add_child(hero)
	var reached := 0
	for route in world.map_data().routes.slice(0,2):
		var targets:=PackedVector2Array()
		for index in route.size()-1:
			var steps:=ceili(route[index].distance_to(route[index+1])/2.8)
			for j in range(1,steps+1):
				targets.append(world.Layout.road_at(route,index,float(j)/steps))
		var back:=targets.duplicate()
		back.reverse()
		targets.append_array(back)
		targets.append(route[0])
		for target in targets:
			var arrived := false
			for frame in 160:
				var local: Vector3 = world.axes.to_local(hero.position)
				var gap := target - Vector2(local.x,local.z)
				_axis("move_right", "move_left", gap.x)
				_axis("move_down", "move_up", gap.y)
				await physics_frame
				if gap.length() < 0.22:
					arrived = true
					break
			if not arrived:
				push_error("경로를 걸어 통과하지 못했습니다 %s / %s" % [hero.position, target])
				quit(1)
				return
			reached += 1
	for action in ["move_right","move_left","move_up","move_down"]:
		Input.action_release(action)
	hero.queue_free()
	world.queue_free()
	await process_frame
	print("FOREST_WALK branches=2 round_trip_waypoints=", reached)
	quit(0)

func _axis(positive:String, negative:String, value:float) -> void:
	if value > 0.12:
		Input.action_press(positive)
		Input.action_release(negative)
	elif value < -0.12:
		Input.action_press(negative)
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)
