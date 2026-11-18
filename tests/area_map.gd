extends SceneTree

var files: DirAccess
var failures := 0
var game


func _initialize() -> void:
	files = DirAccess.create_temp("garbagehero-area-map")
	OS.set_environment("GARBAGEHERO_SAVE_DIR", files.get_current_dir().path_join("save"))
	OS.set_environment("GARBAGEHERO_SETTINGS_PATH", files.get_current_dir().path_join("settings.cfg"))
	root.size = Vector2i(1280,720)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game = current_scene
	await _wait(4)
	_key(KEY_M,true)
	_key(KEY_M,false)
	await _wait(4)
	_check(paused and game.hud.active=="map", "M opens the town map and pauses the session")
	var map: Control = game.hud.modal.find_child("AreaMap",true,false)
	if not is_instance_valid(map):
		_check(false,"HUD contains map")
		quit(1)
		return
	_check(map._map_texture != null and map.map_data.points.has("coach"),"Terrain and active coach point")
	_check(map.map_data.points.has("traveler")==game.world.traveler_visible,"Visiting merchant availability")
	var start: Vector3 = game.player.global_position
	_key(KEY_W,true)
	_key(KEY_Q,true)
	await _wait(7)
	_key(KEY_W,false)
	_key(KEY_Q,false)
	_check(game.player.global_position.is_equal_approx(start) and game.player.cooldowns().hook==0,
		"Movement and skill input stay paused")
	await _capture("map_town")
	_key(KEY_M,true)
	_key(KEY_M,false)
	await _wait(2)
	_check(not paused and not game.hud.panel_open() and game.player.cooldowns().hook==0,"M resumes without a buffered skill")
	game.session.act("depart",{"region":0,"difficulty":0})
	game._enter(0,0)
	for i in 12:
		game.session.record_kill(0,0,"normal","map_%d"%i,game.world.boss_point())
	_key(KEY_M,true)
	_key(KEY_M,false)
	await _wait(3)
	map = game.hud.modal.find_child("AreaMap",true,false)
	_check(map.map_data.points.has("return") and map.map_data.guardian.pending, "Return stone and pending guardian marker")
	_check(map.map_data.guardian.pos.is_equal_approx(Vector2(0,-8.4)), "Pending guardian at arena")
	_key(KEY_ESCAPE,true)
	_key(KEY_ESCAPE,false)
	for i in 125:
		await physics_frame
	_check(is_instance_valid(game.director.boss),"Guardian spawned")
	game.director.boss.position += Vector3(1.3,0,-0.4)
	game.hud.prefs.prefs.text_scale=1.5
	game.hud._apply_settings()
	_key(KEY_M,true)
	_key(KEY_M,false)
	await _wait(4)
	map = game.hud.modal.find_child("AreaMap",true,false)
	var pos: Vector3 = game.world.axes.to_local(game.director.boss.global_position)
	_check(map.map_data.guardian.pos.is_equal_approx(Vector2(pos.x,pos.z)) and not map.map_data.guardian.pending,
		"Live guardian follows actual world position")
	var viewport_size := root.get_visible_rect().size
	var bounds := map.get_global_rect()
	print("Map viewport ",viewport_size," page ",bounds)
	_check(bounds.end.x<=viewport_size.x and bounds.end.y<=viewport_size.y,"150% map fits viewport")
	await _capture("map_forest")
	print("Area map: %d failure(s), real M/Esc input, town and field markers" % failures)
	for voice in game.voices:
		voice.stop()
	paused = false
	game.queue_free()
	await _wait(8)
	if DisplayServer.get_name()=="headless":
		OS.delay_msec(160)
	quit(1 if failures else 0)


func _key(code: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.keycode=code
	key.physical_keycode=code
	key.pressed=pressed
	Input.parse_input_event(key)
	Input.flush_buffered_events()


func _wait(count: int) -> void:
	for i in count:
		await process_frame


func _check(value: bool, label: String) -> void:
	if not value:
		failures+=1
		push_error(label)


func _capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var file := ProjectSettings.globalize_path("res://../art/review/"+label+".png")
		_check(root.get_texture().get_image().save_png(file)==OK,"Saved visual evidence "+label)
