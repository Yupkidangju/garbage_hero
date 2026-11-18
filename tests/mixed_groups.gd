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
			checked += 1
		await process_frame
	main.queue_free()
	await process_frame
	print("MIXED_GROUPS pairs=%d failures=%d" % [checked, failures])
	quit(1 if failures > 0 else 0)
