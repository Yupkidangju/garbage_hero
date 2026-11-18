extends SceneTree

# 렌더링 전용 부하 장면. 캐릭터 위치와 체력을 고정해 측정 내내 25체를 유지한다.
const WARMUP := 30.0
const MEASURE := 120.0
var main
var slot := ""
var clock_start := 0
var previous := 0
var frames: Array[float] = []
var positioned := false
var smallest_count := 25
var tick := 0
var finishing := false

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	slot = OS.get_temp_dir().path_join("garbagehero-perf-" + Crypto.new().generate_random_bytes(8).hex_encode())
	OS.set_environment("GARBAGEHERO_SAVE_DIR", slot)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.session._data.routes[22].cleared = true
	main.session._data.routes[23].phase = "boss"
	main.session._data.first_merge = true
	main.session._data.routes[0].cleared = true
	if not main.session.act("depart", {"region":5,"difficulty":3}):
		push_error("Performance scene could not open its test route")
		quit(1)
		return
	main._enter(5, 3)
	main.player.position = main.world.boss_point() + Vector3(0, 0, 2.5)
	main.player._power = 1
	physics_frame.connect(_combat)

func _combat() -> void:
	if not is_instance_valid(main.director) or not is_instance_valid(main.director.boss):
		return
	var actors := get_nodes_in_group("enemies")
	if not positioned and actors.size() >= 25:
		var n := 0
		for actor in actors:
			if actor != main.director.boss:
				var angle := TAU * (n % 12) / 12.0
				var radius := 2.9 + 2.6 * floorf(n / 12.0)
				actor.position = main.player.position + Vector3(cos(angle), 0, sin(angle)) * radius
				n += 1
		positioned = true
		clock_start = Time.get_ticks_usec()
		previous = clock_start
	if not positioned:
		return
	smallest_count = mini(smallest_count, actors.size())
	main.player.hp = 100
	for actor in actors:
		actor.hp = actor.max_hp
	for action in ["attack", "spin", "hook", "slam"]:
		Input.action_release(action)
	tick += 1
	if tick % 19 == 0:
		Input.action_press("attack")
	if tick % 193 == 0:
		Input.action_press("hook")
	if tick % 259 == 0:
		Input.action_press("spin")
	if tick % 313 == 0:
		Input.action_press("slam")

func _process(_delta: float) -> bool:
	if finishing:
		return false
	if not positioned:
		if Time.get_ticks_msec() > 90000:
			push_error("25 combatants did not become active")
			quit(2)
		return false
	var now := Time.get_ticks_usec()
	var seconds := (now - clock_start) / 1000000.0
	if seconds >= WARMUP:
		frames.append((now - previous) / 1000.0)
	previous = now
	if seconds < WARMUP + MEASURE:
		return false
	finishing = true
	frames.sort()
	var p95: float = frames[ceili(frames.size()*0.95)-1]
	print("FIELD_PERFORMANCE ", JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(), "renderer":RenderingServer.get_current_rendering_method(), "size":str(root.size), "warmup_s":WARMUP,"sample_s":MEASURE,"frames":frames.size(),"min_actors":smallest_count,"median_ms":frames[frames.size()/2],"p95_ms":p95}))
	_finish.call_deferred()
	return false

func _finish() -> void:
	physics_frame.disconnect(_combat)
	await main.prepare_shutdown()
	main.queue_free()
	await process_frame
	await process_frame
	for bank in [0,1]:
		DirAccess.remove_absolute(slot.path_join("slot-%d.sav" % bank))
	DirAccess.remove_absolute(slot)
	quit(0 if smallest_count == 25 else 3)
