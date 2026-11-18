extends SceneTree

# 숲 보스와 세 기술을 재현하기 위한 촬영 피처. 입력 후의 이동·판정·효과는 게임 코드로 진행한다.
const RIGHT := Vector3(.70710678, 0, -.70710678)
const DOWN := Vector3(.70710678, 0, .70710678)
const PRESSES := {9:"hook",57:"dodge",93:"attack",113:"attack",140:"attack",189:"spin",
	256:"slam",333:"attack",353:"attack",380:"attack",435:"hook",475:"attack",495:"attack"}
const DURATION := 525
var scratch: DirAccess
var main
var boss
var tick := 0
var last_pose := ""
var last_boss := ""
var last_hp := 340
var delayed_release := ""
var skills := {}
var reduced := false
var sample_dir := ""

func _initialize() -> void:
	scratch = DirAccess.create_temp("garbagehero-motion-review")
	OS.set_environment("GARBAGEHERO_SAVE_DIR",scratch.get_current_dir().path_join("save"))
	OS.set_environment("GARBAGEHERO_SETTINGS_PATH",scratch.get_current_dir().path_join("settings.cfg"))
	reduced = "--reduced" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--samples="):
			sample_dir=arg.trim_prefix("--samples=")
	var config := ConfigFile.new()
	config.set_value("display","reduced_flash",reduced)
	config.set_value("display","screen_shake",true)
	if config.save(OS.get_environment("GARBAGEHERO_SETTINGS_PATH"))!=OK:
		quit(2)
		return
	call_deferred("_begin")

func _begin() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.session._data.routes[0].cleared = true
	main.session._data.routes[0].phase = "boss"
	main.session._data.routes[0].trace = 12
	main.session._data.routes[0].minis = 2
	main.session._data.first_merge = true
	if not main.session.act("depart",{"region":0,"difficulty":0}):
		quit(2)
		return
	main._enter(0,0)
	# 주변 스폰을 쉬게 하고 동일 공터에서 두 번의 설정을 비교한다.
	var hunt = main.director
	hunt.halted = true
	for extra in hunt.enemies:
		if is_instance_valid(extra):
			extra.queue_free()
	hunt.enemies.clear()
	if is_instance_valid(hunt.marker):
		hunt.marker.queue_free()
		hunt.marker = null
	var site: Vector3 = main.world.boss_point()
	main.player.position = site-RIGHT*3.20+DOWN*.80
	main.player._turn_to((site-main.player.position).normalized())
	main.player._rng.seed = 121
	boss = hunt._spawn("boss",0,"forest-motion-review",site,-1)
	hunt.boss = boss
	boss.cooldown = .35
	main._refresh()
	main.player.cue.connect(func(event: String): print("MOTION_CUE ",tick," ",event))
	physics_frame.connect(_frame)

func _input_action(key: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action=key
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _frame() -> void:
	tick += 1
	if tick==8 and (main.player._fx.reduced_flash!=reduced or not main.player._shake_enabled):
		push_error("Saved feedback settings did not reach active hero")
		quit(4)
		return
	if not sample_dir.is_empty() and tick in [25,104,207,218,285]:
		_sample(tick)
	if not delayed_release.is_empty():
		_input_action(delayed_release,false)
		delayed_release=""
	if PRESSES.has(tick):
		delayed_release=PRESSES[tick]
		_input_action(delayed_release,true)
	if is_instance_valid(boss):
		var status: String=boss.move_style+"/"+boss.phase
		if status!=last_boss:
			last_boss=status
			print("MOTION_BOSS ",tick," ",status)
		if boss.hp!=last_hp:
			print("MOTION_CONTACT ",tick," boss_hp=",boss.hp)
			last_hp=boss.hp
	var pose: String=main.player._move
	if pose!=last_pose:
		last_pose=pose
		if not pose.is_empty():
			skills[pose]=true
			print("MOTION_HERO ",tick," ",pose)
	if tick>=DURATION or (not sample_dir.is_empty() and tick>=292):
		var okay: bool=skills.has("hook") and skills.has("slam") and skills.has("spin") and skills.has("attack1") and last_hp<340
		print("MOTION_END reduced=",reduced," skills=",skills," boss_hp=",last_hp," hero_hp=",main.player.hp," ticks=",tick," passed=",okay)
		physics_frame.disconnect(_frame)
		call_deferred("_finish",okay)

func _sample(number: int) -> void:
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var label: String="reduced" if reduced else "normal"
	var result:=image.save_png(sample_dir.path_join("%s_%03d.png"%[label,number]))
	if result!=OK:
		push_error("Unable to save comparison frame")
		quit(5)

func _finish(okay: bool) -> void:
	for voice in main.voices:
		voice.stop()
		voice.stream=null
	main.queue_free()
	main=null
	boss=null
	await process_frame
	await process_frame
	if DisplayServer.get_name()=="headless":
		OS.delay_msec(150)
	quit(0 if okay else 3)
