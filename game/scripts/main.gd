extends Node3D

const FIELD_DIRECTOR := preload("res://scripts/field_director.gd")
const GUARDIAN_POI := preload("res://scripts/guardian_poi.gd")
const AREA_MAP := preload("res://scripts/area_map.gd")

var session
var world
var player
var hud
var director
var stage: Node3D
var region := -1
var difficulty := 0
var service := ""
var nearby_cache := ""
var last_landmark := ""
var combat_lock := 0.0
var ui_clock := 0.0
var snapshot := {}
var unlocked: Array[bool] = []
var gear_state := {}
var retry_tasks: Array[Callable] = []
var error_layer: CanvasLayer
var error_text: Label
var feedback := {"shake_enabled": true, "reduced_flash": false}
var sounds := {}
var voices: Array[AudioStreamPlayer] = []
var voice_index := 0
var last_sound := {}
var transitioning := false
var shutting_down := false
var poi
var save_guard := preload("res://scripts/save_guard.gd").new()
var benchmark_sandbox: DirAccess

func _ready() -> void:
	var benchmark_mode := "--benchmark" in OS.get_cmdline_user_args()
	if benchmark_mode:
		benchmark_sandbox = preload("res://scripts/runtime_benchmark.gd").prepare_environment()
		if not benchmark_sandbox:
			get_tree().quit(2)
			return
	get_tree().auto_accept_quit = false
	ThemeDB.get_default_theme().default_font = preload("res://assets/fonts/NotoSansKR.ttf")
	TranslationServer.add_translation(preload("res://data/expedition_ko.tres"))
	hud = load("res://scripts/hud.gd").new()
	hud.name = "HUD"
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	hud.command.connect(_command)
	hud.panel_changed.connect(_panel_changed)
	hud.celebrated.connect(_sound)
	poi = GUARDIAN_POI.new()
	hud.add_child(poi)
	session = load("res://scripts/session.gd").new()
	session.name = "Session"
	add_child(session)
	session.notice.connect(hud.toast)
	session.changed.connect(_session_changed)
	_setup_sound()
	if not _load_slot():
		if benchmark_mode:
			get_tree().quit(2)
		else:
			_show_retry(_load_slot)
	elif benchmark_mode:
		var scenario := preload("res://scripts/runtime_benchmark.gd").new()
		scenario.configure(self,benchmark_sandbox)
		get_tree().root.add_child.call_deferred(scenario)

func _load_slot() -> bool:
	var path := OS.get_environment("GARBAGEHERO_SAVE_DIR")
	if path.is_empty():
		path = ProjectSettings.get_setting("garbage_hero/save_directory", "user://save")
	var access := save_guard.acquire(path)
	if access != OK:
		session.last_error = tr("SAVE_SLOT_BUSY") if access == ERR_ALREADY_IN_USE else tr("SAVE_RETRY_TITLE")
		session.notice.emit(session.last_error)
		return false
	if not session.start_slot(save_guard.directory):
		return false
	_session_changed()
	_enter(-1, 0)
	return true

func _session_changed() -> void:
	snapshot = session.ui_state()
	unlocked.clear()
	for rank in 4:
		for theme in 6:
			unlocked.append(session.can_travel(theme, rank))
	_update_player_gear()
	if region < 0 and is_instance_valid(world):
		world.set_traveler_visible(snapshot.get("traveler", {}).get("available", false))
	elif region >= 0 and is_instance_valid(world):
		world.set_open_caches(session.world_state(region, difficulty).opened_caches)
	_refresh()

func _update_player_gear() -> void:
	if not is_instance_valid(player) or snapshot.is_empty():
		return
	var gear: Dictionary = snapshot.get("equipped", {})
	var progress: Dictionary = snapshot.progression
	var current := {"gear":gear, "equipment":snapshot.equipment, "stats":snapshot.stats, "ranks":progress.ranks, "loadout":progress.loadout}
	if current != gear_state:
		gear_state = current
		player.configure_build(gear, snapshot.stats, progress, snapshot.equipment)

func _enter(theme: int, rank: int) -> void:
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	world = null
	player = null
	director = null
	region = theme
	difficulty = rank
	service = ""
	nearby_cache = ""
	last_landmark = ""
	combat_lock = 0
	gear_state = {}
	stage = Node3D.new()
	stage.name = "Expedition"
	add_child(stage)
	world = load("res://scripts/world.gd").new()
	world.name = "Landscape"
	stage.add_child(world)
	world.build(region)
	if region < 0:
		world.set_traveler_visible(snapshot.get("traveler", {}).get("available", false))
	player = load("res://scripts/player.gd").new()
	player.name = "Hero"
	player.position = world.entry_point()
	stage.add_child(player)
	player.bind_terrain(world)
	_update_player_gear()
	player.set_feedback(feedback.shake_enabled, feedback.reduced_flash)
	player.cue.connect(_player_cue)
	player.died.connect(_on_death)
	player.health_changed.connect(func(_hp: int, _maximum: int): _refresh())
	if region >= 0:
		director = FIELD_DIRECTOR.new()
		director.name = "Hunt"
		stage.add_child(director)
		director.cue.connect(_sound)
		director.announcement.connect(hud.toast)
		director.save_failed.connect(_show_retry)
		director.initialize(session, world, player, region, difficulty)
		world.set_open_caches(director.state.opened_caches)
	poi.hero = player
	poi.director = director
	poi.world = world
	transitioning = false
	_update_service()
	_refresh()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or transitioning:
		return
	combat_lock = maxf(0, combat_lock - delta)
	ui_clock -= delta
	if ui_clock <= 0:
		ui_clock = 0.1
		_update_service()
		if region >= 0:
			var landmark: String = world.landmark_near(player.global_position)
			if landmark != last_landmark:
				last_landmark = landmark
				if not landmark.is_empty() and not session.discover(region, difficulty, landmark):
					_show_retry(session.discover.bind(region, difficulty, landmark))
		_refresh()

func _update_service() -> void:
	service = world.service_near(player.position)
	nearby_cache = ""
	if region >= 0 and service.is_empty():
		nearby_cache = world.cache_near(player.position)
		if not nearby_cache.is_empty() and nearby_cache not in session.world_state(region, difficulty).opened_caches:
			service = "cache"
	if service == "traveler" and not snapshot.get("traveler", {}).get("available", false):
		service = ""

func _refresh() -> void:
	if not is_instance_valid(player) or snapshot.is_empty():
		return
	var data := snapshot.duplicate()
	var district_name := ""
	if region >= 0:
		var district: String = world.district_at(player.position)
		for area: Dictionary in world.map_data().get("districts", []):
			if area.id == district:
				district_name = area.name
				break
	data.merge({"region": region, "difficulty": difficulty, "hp": player.hp, "max_hp": player.max_hp,
		"world": director.state if is_instance_valid(director) else {},
		"area_map": AREA_MAP.snapshot(world, player, director),
		"service": service, "unlocked": unlocked, "cooldowns": player.cooldowns(), "terrain": player.terrain_state(), "district": district_name,
		"boss": director.guardian_info() if is_instance_valid(director) else {}}, true)
	hud.refresh(data)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player) or transitioning or hud.panel_open():
		return
	if event.is_action_pressed("interact"):
		_update_service()
		if service == "cache":
			_open_nearby_cache()
		elif service == "return":
			if combat_lock <= 0:
				_return_to_town()
			else:
				hud.toast(tr("FIELD_COMBAT_RETURN"))
		elif not service.is_empty():
			_refresh()
			hud.open_panel(service)
		else:
			hud.toast(tr("FIELD_NEARBY"))
	elif event.is_action_pressed("inventory"):
		hud.open_panel("inventory")
	elif event.is_action_pressed("skills"):
		hud.open_panel("skills")
	elif event.is_action_pressed("map"):
		_refresh()
		hud.open_panel("map")
	elif event.is_action_pressed("ui_cancel"):
		hud.open_panel("pause")
	else:
		return
	get_viewport().set_input_as_handled()

func _panel_changed(opened: bool) -> void:
	get_tree().paused = opened or is_instance_valid(error_layer)
	poi.visible = not opened

func _open_nearby_cache() -> void:
	for cache: Dictionary in world.cache_points():
		if cache.id == nearby_cache and player.position.distance_to(cache.pos) <= 2.5:
			if not session.open_cache(region, difficulty, nearby_cache, cache.pos):
				if session.last_error == preload("res://data/loot_rules.gd").caption("SAVE_FAILED"):
					_show_retry(session.open_cache.bind(region, difficulty, nearby_cache, cache.pos))
			else:
				_sound("pickup")
			_update_service()
			_refresh()
			return

func _command(action: String, args: Dictionary) -> void:
	if shutting_down or transitioning:
		return
	match action:
		"travel":
			var target := int(args.get("region", -1))
			var rank := int(args.get("difficulty", -1))
			if region == -1 and service == "coach" and session.act("depart", {"region": target, "difficulty": rank}):
				hud.close_panel()
				transitioning = true
				_enter.call_deferred(target, rank)
		"return":
			if service == "return" and combat_lock <= 0:
				_return_to_town()
		"settings":
			feedback.merge(args, true)
			feedback.shake_enabled = args.get("screen_shake", feedback.shake_enabled)
			if is_instance_valid(player):
				player.set_feedback(feedback.shake_enabled, feedback.reduced_flash)
		"quit":
			_request_exit()
		_:
			if session.act(action, args):
				_sound("pickup" if action in ["claim", "merge", "buy"] else "menu")
	_refresh()

func _player_cue(kind: String) -> void:
	if kind in ["hit", "hurt"]:
		combat_lock = 3.0
	_sound(kind)

func _on_death() -> void:
	if transitioning:
		return
	transitioning = true
	_finish_death.call_deferred()

func _finish_death() -> void:
	if not _return_to_town():
		_show_retry(_return_to_town)

func _return_to_town() -> bool:
	if not session.act("return", {}):
		return false
	transitioning = true
	hud.close_panel()
	_enter.call_deferred(-1, difficulty)
	return true

func _show_retry(task: Callable) -> void:
	if not retry_tasks.has(task):
		retry_tasks.append(task)
	if is_instance_valid(error_layer):
		return
	get_tree().paused = true
	error_layer = CanvasLayer.new()
	error_layer.layer = 100
	error_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(error_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.09, 0.12, 0.88)
	error_layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	center.add_child(box)
	error_text = Label.new()
	error_text.text = session.last_error if not session.last_error.is_empty() else tr("SAVE_RETRY_TITLE")
	error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_text.custom_minimum_size.x = 330
	box.add_child(error_text)
	var retry := Button.new()
	retry.text = tr("SAVE_RETRY_ACTION")
	box.add_child(retry)
	retry.grab_focus()
	retry.pressed.connect(_retry_saves)

func _retry_saves() -> void:
	while not retry_tasks.is_empty():
		var task := retry_tasks.front() as Callable
		if task.is_valid() and not task.call():
			if not session.last_error.is_empty():
				error_text.text = session.last_error
			return
		retry_tasks.pop_front()
	error_layer.queue_free()
	error_layer = null
	get_tree().paused = hud.panel_open()

func _setup_sound() -> void:
	for clip in ["scrap_impact", "guardian_bell", "blade_sweep", "salvage_chime"]:
		var path := "res://assets/audio/%s.wav" % clip
		if ResourceLoader.exists(path):
			sounds[clip] = load(path)
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func _stop_audio() -> void:
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null

func _exit_tree() -> void:
	_stop_audio()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		_request_exit()

func _request_exit() -> void:
	if shutting_down:
		return
	await prepare_shutdown()
	get_tree().quit()

func prepare_shutdown() -> void:
	shutting_down = true
	get_tree().paused = true
	_stop_audio()
	# 재생 중인 WAV를 믹서 스레드가 반환한 다음 씬 트리를 닫는다.
	var wait_ms := ceili(1000.0 * maxf(0.15, AudioServer.get_output_latency()))
	var until := Time.get_ticks_msec() + wait_ms
	while Time.get_ticks_msec() < until:
		await get_tree().create_timer(0.03, true, false, true).timeout

func _sound(kind: String) -> void:
	if shutting_down:
		return
	var clip: String
	var pitch := 1.0
	var volume := -11.0
	match kind:
		"hit", "hurt", "slam", "impact", "mace", "nova":
			clip = "scrap_impact"
			pitch = 0.78 if kind == "slam" else 1.0
		"warning", "boss", "death", "level_up":
			clip = "guardian_bell"
			pitch = 1.25 if kind == "level_up" else 1.0
			volume = -15.0 if kind == "level_up" else volume
		"pickup", "merge", "menu", "fusion":
			clip = "salvage_chime"
			volume = -17.0
			pitch = 0.90 if kind == "fusion" else 1.0
		"swing1", "swing2", "swing3", "spin", "dodge", "hook", "bow", "staff", "spear", "volley", "rush":
			clip = "blade_sweep"
			pitch = 1.16 if kind == "swing1" else 0.94
		_:
			return
	var now := Time.get_ticks_msec()
	if not sounds.has(clip) or now - int(last_sound.get(clip, -1000)) < 85:
		return
	last_sound[clip] = now
	var voice := voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = sounds[clip]
	voice.volume_db = volume
	voice.pitch_scale = pitch
	voice.play()
