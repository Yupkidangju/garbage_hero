extends SceneTree

const Runner = preload("res://scripts/runtime_benchmark.gd")

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var runner
	for frame in 10000:
		await process_frame
		for node in root.get_children():
			if node.get_script() == Runner:
				runner = node
				break
		if is_instance_valid(runner) and runner.frames.size() >= 10:
			var event := InputEventKey.new()
			event.keycode = KEY_ESCAPE
			event.physical_keycode = KEY_ESCAPE
			event.pressed = true
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			print("BENCHMARK_CANCEL paused=",paused," actors=",get_nodes_in_group("enemies").size()," prior_samples=",runner.frames.size())
			var deadline := Time.get_ticks_msec() + 5000
			while Time.get_ticks_msec() < deadline:
				await process_frame
			quit(7)
			return
	quit(7)
