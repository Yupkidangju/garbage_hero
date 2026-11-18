extends SceneTree

# 실제 게임 씬을 실행한 뒤 창에 키·마우스 이벤트를 전달한다.
# 게임 상태는 검증과 조준·이동 목표 선택에만 읽는다.
const RIGHT := Vector3(0.70710678, 0, -0.70710678)
const DOWN := Vector3(0.70710678, 0, 0.70710678)
const MAX_TICKS := 60 * 60 * 20
var folder: DirAccess
var game
var ticks := 0
var started := 0
var pressed := {}
var releases := {}
var mouse_held := false
var mouse_release := 0
var cursor := Vector2.ZERO
var milestones := {}
var minis := {}
var last_phase := "hunt"
var last_mini_id := ""
var deaths := 0
var trips := 0
var last_region := -2
var next_ui := 0
var equipment_goal := -1
var selecting := false
var region_selected := -1
var ending := false
var retreat := false
var used_return_stone := false
var ui_idle_ticks := 0
var opened_tick := 0

func _initialize() -> void:
	folder = DirAccess.create_temp("garbagehero-input-expedition")
	if not folder:
		push_error("unable to create isolated save directory")
		quit(2)
		return
	OS.set_environment("GARBAGEHERO_SAVE_DIR", folder.get_current_dir().path_join("save"))
	OS.set_environment("GARBAGEHERO_SETTINGS_PATH", folder.get_current_dir().path_join("settings.cfg"))
	root.size = Vector2i(1280, 720)
	_run.call_deferred()

func _run() -> void:
	started = Time.get_ticks_msec()
	if change_scene_to_file("res://scenes/main.tscn") != OK:
		_stop(false, "main scene could not start")
		return
	await scene_changed
	game = current_scene
	for i in 10:
		await physics_frame
	if not is_instance_valid(game.get("player")) or not is_instance_valid(game.get("hud")):
		_stop(false, "main scene did not create HUD/player")
		return
	while ticks < MAX_TICKS and not ending:
		await physics_frame
		ticks += 1
		_release_pulses()
		if game.region != last_region:
			_stop_walking()
			region_selected = -1
			selecting = false
			if game.region == 0:
				trips += 1
				retreat = false
				_mark("forest_entered")
			elif game.region == 1:
				_mark("desert_entered")
				_stop(milestones.has("first_merge") and milestones.has("forest_clear") and milestones.has("return_stone") and minis.size() == 2, "arrived in desert")
				return
			else:
				_mark("town_started")
				if used_return_stone and last_region == 0:
					_mark("return_stone")
				used_return_stone = false
			last_region = game.region
		if is_instance_valid(game.error_layer):
			_stop(false, "save retry appeared")
			return
		if game.transitioning:
			continue
		if game.hud.panel_open():
			_panel()
		elif game.region == -1:
			_town()
		elif game.region == 0:
			_forest()
		if ticks % 1800 == 0:
			print("EXPEDITION_PROGRESS ", _status())
	if not ending:
		_stop(false, "20 simulated minutes elapsed")

func _mark(event: String) -> void:
	if not milestones.has(event):
		milestones[event] = snappedf(ticks / 60.0, 0.01)
		print("EXPEDITION_MILESTONE ", event, " sim_seconds=", milestones[event])

func _stop(success: bool, reason: String) -> void:
	if ending:
		return
	ending = true
	print("EXPEDITION_RESULT ", JSON.stringify({"passed":success,"reason":reason,"milestones":milestones,
		"minibosses":minis.size(),"forest_visits":trips,"deaths":deaths,"simulation_seconds":ticks/60.0,
		"wall_seconds":(Time.get_ticks_msec() - started) / 1000.0,"last_state":_status()}))
	quit(0 if success else 1)

func _status() -> String:
	if not is_instance_valid(game) or not is_instance_valid(game.get("player")):
		return "not initialized"
	var base := "region=%d hp=%d pos=%s service=%s" % [game.region, game.player.hp, game.player.position, game.service]
	if game.hud.panel_open():
		var visible_buttons := []
		for button in _buttons():
			visible_buttons.append([str(button.name),button.text])
		return base + " panel buttons " + str(visible_buttons)
	if is_instance_valid(game.director):
		var w: Dictionary = game.director.state
		var enemy = _nearest()
		var target := ""
		if is_instance_valid(enemy):
			target = "%s %s hp=%d gap=%.2f" % [enemy.name,enemy.position,enemy.hp,game.player.position.distance_to(enemy.position)]
		return base + " %s trace=%d mini=%d dropped=%d held=%s %s" % [w.phase,w.trace,w.minis,w.drops.size(),pressed.keys(),target]
	return base

func _key(code: Key, down: bool) -> void:
	if pressed.has(code) == down:
		return
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	if down:
		pressed[code] = true
	else:
		pressed.erase(code)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _tap(code: Key) -> void:
	if not pressed.has(code):
		_key(code, true)
		releases[code] = ticks + 1

func _aim(pos: Vector2) -> void:
	# 카메라와 Control은 논리 뷰포트 좌표를 사용한다. 입력 서버는 창 픽셀을 받는다.
	root.warp_mouse(pos)
	pos = (root.get_final_transform() * pos).clamp(Vector2.ONE, Vector2(root.size) - Vector2.ONE)
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	move.relative = pos - cursor
	cursor = pos
	Input.parse_input_event(move)
	Input.flush_buffered_events()

func _mouse(down: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = cursor
	click.global_position = cursor
	click.pressed = down
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	mouse_held = down
	if down:
		mouse_release = ticks + 1

func _release_pulses() -> void:
	for code in releases.keys():
		if ticks >= releases[code]:
			_key(code, false)
			releases.erase(code)
	if mouse_held and ticks >= mouse_release:
		_mouse(false)

func _stop_walking() -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_key(code, false)

func _walk_towards(goal: Vector3, stop_at := 0.18) -> void:
	var offset: Vector3 = goal - game.player.position
	offset.y = 0.0
	if offset.length() <= stop_at:
		_stop_walking()
		return
	var dir := offset.normalized()
	var x := dir.dot(RIGHT)
	var z := dir.dot(DOWN)
	_key(KEY_A, x < -0.38)
	_key(KEY_D, x > 0.38)
	_key(KEY_W, z < -0.38)
	_key(KEY_S, z > 0.38)

func _town() -> void:
	if game.world.service_near(game.player.position) == "coach":
		_stop_walking()
		if ticks >= next_ui:
			_tap(KEY_F)
			next_ui = ticks + 4
			equipment_goal = -1
			ui_idle_ticks = 0
			opened_tick = ticks
	else:
		_walk_towards(game.world.service_points().get("coach"))

func _buttons() -> Array:
	var result := []
	for button: Button in game.hud.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and not button.disabled:
			result.append(button)
	return result

func _click_button(button: Button) -> void:
	var rect := button.get_global_rect()
	_aim(rect.get_center())
	if ticks - opened_tick < 15:
		var hover := root.gui_get_hovered_control()
		print("EXPEDITION_INPUT ", button.name, " ui=",rect.get_center()," cursor=",cursor," viewport=",root.get_visible_rect()," hover=", hover.name if hover else &"")
	_mouse(true)
	next_ui = ticks + 4
	ui_idle_ticks = 0

func _panel() -> void:
	_stop_walking()
	if ticks - opened_tick > 240:
		_stop(false, "menu did not respond to physical input")
		return
	if next_ui > ticks or mouse_held:
		return
	ui_idle_ticks += 1
	var buttons := _buttons()
	if equipment_goal >= 0:
		if game.snapshot.equipped.get("id", -2) == equipment_goal:
			_mark("upgrade_equipped")
			equipment_goal = -1
			_tap(KEY_ESCAPE)
			next_ui = ticks + 6
			return
		for button: Button in buttons:
			if not selecting and button.name == "BagItem%d" % equipment_goal:
				_click_button(button)
				selecting = true
				return
			if selecting and button.name == "Equip":
				_click_button(button)
				return
	else:
		var destination := 1 if game.snapshot.forest_clear and milestones.has("return_stone") else 0
		for button: Button in buttons:
			if region_selected != destination and button.name == "Route%d" % destination:
				_click_button(button)
				region_selected = destination
				return
			if region_selected == destination and button.name == "Depart":
				_click_button(button)
				return
	if ui_idle_ticks > 60:
		_stop(false, "no actionable visible UI control")

func _nearest():
	var best
	var shortest := INF
	for enemy in get_nodes_in_group("enemies"):
		if enemy.is_queued_for_deletion() or enemy.hp <= 0:
			continue
		var distance: float = enemy.position.distance_squared_to(game.player.position)
		if distance < shortest:
			best = enemy
			shortest = distance
	return best

func _forest() -> void:
	if game.snapshot.first_merge:
		_mark("first_merge")
	var director = game.director
	var state: Dictionary = director.state
	if last_phase == "mini" and state.phase in ["hunt", "boss"] and not last_mini_id.is_empty():
		minis[last_mini_id] = true
		_mark("miniboss_%d_defeated" % minis.size())
	if state.phase == "mini":
		last_mini_id = state.spawn_id
	last_phase = state.phase
	if state.phase == "boss":
		_mark("field_boss_summoned")
	if game.snapshot.forest_clear:
		_mark("forest_clear")
	if game.player.hp <= 0:
		if not retreat:
			deaths += 1
			retreat = true
		_stop_walking()
		return
	if game.snapshot.forest_clear or retreat:
		if game.world.service_near(game.player.position) == "return" and game.combat_lock <= 0.0:
			_stop_walking()
			if ticks >= next_ui:
				used_return_stone = true
				_tap(KEY_F)
				next_ui = ticks + 5
		else:
			_walk_towards(game.world.entry_point())
		return
	if _evade_telegraph():
		return
	if ticks >= next_ui and ticks % 23 == 0:
		var best := int(game.snapshot.equipped.get("atk", 0))
		var selected := -1
		for item in game.snapshot.bag:
			if item.atk > best:
				best = item.atk
				selected = item.id
		if selected >= 0:
			_stop_walking()
			equipment_goal = selected
			selecting = false
			ui_idle_ticks = 0
			opened_tick = ticks
			_tap(KEY_I)
			next_ui = ticks + 4
			return
	var target = _nearest()
	if is_instance_valid(director.boss) and director.boss.hp > 0:
		if not is_instance_valid(target) or game.player.position.distance_to(target.position) > 1.4:
			target = director.boss
	var goal: Vector3 = game.world.boss_point()
	var distance := INF
	if is_instance_valid(target):
		goal = target.position
		distance = game.player.position.distance_to(goal)
	var loot_distance := INF
	var loot_position := Vector3.ZERO
	for drop in state.drops:
		var gap: float = game.player.position.distance_to(drop.pos)
		if gap < loot_distance:
			loot_distance = gap
			loot_position = drop.pos
	if loot_distance < 3.0 and distance > 2.2:
		_walk_towards(loot_position)
		return
	if not is_instance_valid(target):
		_walk_towards(goal)
		return
	var camera: Camera3D = root.get_camera_3d()
	var aim_point: Vector3 = game.player.position.move_toward(goal, 4.0) + Vector3.UP * 0.24
	_aim(camera.unproject_position(aim_point))
	var reach := 1.48 + float(target.hit_radius)
	if distance > reach:
		_walk_towards(goal, reach * 0.8)
		if distance < 5.0 and ticks % 13 == 0 and game.player.cooldowns().hook <= 0.0:
			_tap(KEY_Q)
	else:
		_stop_walking()
		if game.snapshot.first_merge and game.player.cooldowns().spin <= 0 and ticks % 5 == 0:
			_tap(KEY_E)
		elif not mouse_held and ticks % 5 == 0:
			_mouse(true)

func _evade_telegraph() -> bool:
	var player = game.player
	for enemy in get_nodes_in_group("enemies"):
		if enemy.kind == "normal" and player.hp > 40:
			continue
		if enemy.phase != "windup" or enemy.remaining > 0.30:
			continue
		for mark in enemy.get_children():
			if not mark.has_method("contains_point") or not mark.contains_point(player.position) or mark.effect in ["heal","haste"]:
				continue
			var away: Vector3 = player.position - enemy.position
			away.y = 0.0
			away = away.normalized()
			for distance: float in [1.0, 2.3, 3.0]:
				for angle: float in [PI/2, -PI/2, PI/4, -PI/4, 0.0, PI]:
					var escape: Vector3 = player.position + away.rotated(Vector3.UP, angle) * distance
					if not mark.contains_point(escape):
						_walk_towards(escape)
						if player.cooldowns().dodge <= 0 and enemy.remaining < 0.22:
							_tap(KEY_SPACE)
						return true
	return false
