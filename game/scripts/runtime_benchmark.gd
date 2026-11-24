extends Node

const ACTORS := 41
const Loot = preload("res://data/loot_rules.gd")
var main
var sandbox: DirAccess
var warmup := 30.0
var measure := 120.0
var output_path := ""
var positioned := false
var finishing := false
var start_usec := 0
var previous := 0
var launch_msec := 0
var frames: Array[float] = []
var minimum_actors := ACTORS
var maximum_actors := ACTORS
var ticks := 0
var cues := {}
var assets_valid := true

static func prepare_environment() -> DirAccess:
	var folder := DirAccess.create_temp("garbagehero-benchmark")
	if folder:
		OS.set_environment("GARBAGEHERO_SAVE_DIR", folder.get_current_dir().path_join("save"))
		OS.set_environment("GARBAGEHERO_SETTINGS_PATH", folder.get_current_dir().path_join("settings.cfg"))
	return folder

func configure(game: Node, folder: DirAccess) -> void:
	main = game
	sandbox = folder
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--benchmark-warmup="):
			warmup = clampf(option.trim_prefix("--benchmark-warmup=").to_float(), 1.0, 60.0)
		if option.begins_with("--benchmark-seconds="):
			measure = clampf(option.trim_prefix("--benchmark-seconds=").to_float(), 1.0, 600.0)
		if option.begins_with("--benchmark-output="):
			output_path = option.trim_prefix("--benchmark-output=")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	launch_msec = Time.get_ticks_msec()
	_start.call_deferred()

func _start() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for id in 88:
		assets_valid = assets_valid and ResourceLoader.exists("res://assets/ui/items/item_%03d.png" % id)
		assets_valid = assets_valid and ResourceLoader.exists("res://assets/models/items/item_%03d.glb" % id)
	assets_valid = assets_valid and Loot.BLUEPRINTS.size() == 88
	main.session._data.routes[22].cleared = true
	main.session._data.routes[23].phase = "boss"
	main.session._data.first_merge = true
	main.session._data.routes[0].cleared = true
	main.session._data.progression = preload("res://data/progression.gd").from_legacy(true, true)
	if not main.session.act("depart", {"region":5,"difficulty":3}):
		_complete({"error":"benchmark route could not open"}, 2)
		return
	main._enter(5, 3)
	main.player.position = main.world.boss_point() + Vector3(0,0,2.5)
	main.player._power = 1
	main.player.cue.connect(func(kind: String): cues[kind] = int(cues.get(kind, 0)) + 1)
	get_tree().physics_frame.connect(_combat)

func _combat() -> void:
	if finishing or not is_instance_valid(main.director) or not is_instance_valid(main.director.boss):
		return
	var actors := get_tree().get_nodes_in_group("enemies")
	if not positioned and actors.size() >= ACTORS:
		var n := 0
		for actor in actors:
			if actor != main.director.boss:
				var angle := TAU * (n % 20) / 20.0
				var radius := 3.4 + 3.0 * floorf(n / 20.0)
				actor.position = main.player.position + Vector3(cos(angle),0,sin(angle)) * radius
				n += 1
		positioned = true
		start_usec = Time.get_ticks_usec()
		previous = start_usec
	if not positioned:
		return
	minimum_actors = mini(minimum_actors, actors.size())
	maximum_actors = maxi(maximum_actors, actors.size())
	main.player.hp = main.player.max_hp
	for actor in actors:
		actor.hp = actor.max_hp
	for action in ["attack","spin","hook","slam"]:
		Input.action_release(action)
	ticks += 1
	if ticks % 19 == 0: Input.action_press("attack")
	if ticks % 193 == 0: Input.action_press("hook")
	if ticks % 259 == 0: Input.action_press("spin")
	if ticks % 313 == 0: Input.action_press("slam")

func _process(_delta: float) -> void:
	if finishing:
		return
	if get_tree().paused or (is_instance_valid(main) and main.hud.panel_open()):
		_complete({"error":"benchmark interrupted by a menu or pause"},6)
		return
	if not positioned:
		if Time.get_ticks_msec() - launch_msec > 90000:
			_complete({"error":"41 combatants did not become active"}, 2)
		return
	var now := Time.get_ticks_usec()
	var seconds := (now-start_usec)/1000000.0
	if seconds >= warmup:
		frames.append((now-previous)/1000.0)
	previous = now
	if seconds < warmup + measure:
		return
	frames.sort()
	var result := {"gpu":RenderingServer.get_video_adapter_name(),
		"renderer":RenderingServer.get_current_rendering_method(), "size":str(get_viewport().size),
		"warmup_s":warmup, "sample_s":measure, "frames":frames.size(),
		"min_actors":minimum_actors,"max_actors":maximum_actors,
		"median_ms":frames[frames.size()/2],"p95_ms":frames[ceili(frames.size()*0.95)-1],
		"debug_build":OS.is_debug_build(),"editor_binary":OS.has_feature("editor"),
		"version":ProjectSettings.get_setting("application/config/version"),
		"assets_valid":assets_valid,"action_signals":cues}
	_complete(result, 0 if assets_valid and minimum_actors == ACTORS and maximum_actors == ACTORS else 3)

func _complete(result: Dictionary, exit_code: int) -> void:
	if finishing:
		return
	finishing = true
	if not output_path.is_empty():
		var file := FileAccess.open(output_path,FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(result, "\t"))
			file.close()
		else:
			exit_code = 4
	print("FIELD_PERFORMANCE ",JSON.stringify(result))
	_finish.call_deferred(exit_code)

func _finish(exit_code: int) -> void:
	if get_tree().physics_frame.is_connected(_combat):
		get_tree().physics_frame.disconnect(_combat)
	for action in ["attack","spin","hook","slam"]:
		Input.action_release(action)
	if is_instance_valid(main):
		await main.prepare_shutdown()
		main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(exit_code)
