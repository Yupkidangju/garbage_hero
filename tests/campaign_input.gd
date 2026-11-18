extends "first_expedition.gd"

# 쉬움 화산 클리어 뒤 일반 숲 진입까지가 기본 범위다. --target=N은 N개
# 노선 클리어와 다음 노선 입장을 검증한다. 재시도할 때는 실제 플레이로
# 작성한 이 테스트의 임시 폴더를 --resume=경로에 전달할 수 있다.
var target_routes := 6
var campaign_dir := ""
var cleared_count := 0
var visited := {}
var species_seen := {}
var defeats := {}
var watch := {}
var route_start := 0
var unlock_times := {}
var hp_seen := 100
var shopped := false
var purchases := 0
var shop_balance := -1
var lowest_boss_hp := {}
var sell_to_slots := 0
var tactical := false

func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option == "--tactical":
			tactical = true
		if option.begins_with("--target="):
			target_routes = clampi(option.trim_prefix("--target=").to_int(), 1, 24)
		if option.begins_with("--resume="):
			campaign_dir = option.trim_prefix("--resume=").simplify_path()
	if campaign_dir.is_empty():
		folder = DirAccess.create_temp("garbagehero-campaign", true)
		if folder:
			campaign_dir = folder.get_current_dir()
			var marker := FileAccess.open(campaign_dir.path_join("campaign-test.marker"), FileAccess.WRITE)
			if marker:
				marker.store_string("garbagehero-input-v1")
				marker.close()
	if not FileAccess.file_exists(campaign_dir.path_join("campaign-test.marker")) or FileAccess.get_file_as_string(campaign_dir.path_join("campaign-test.marker")) != "garbagehero-input-v1":
		push_error("Use a test-created campaign directory.")
		quit(2)
		return
	OS.set_environment("GARBAGEHERO_SAVE_DIR", campaign_dir.path_join("save"))
	OS.set_environment("GARBAGEHERO_SETTINGS_PATH", campaign_dir.path_join("settings.cfg"))
	print("CAMPAIGN_SAVE ", campaign_dir)
	root.size = Vector2i(1280, 720)
	_campaign.call_deferred()

func _campaign() -> void:
	started = Time.get_ticks_msec()
	if change_scene_to_file("res://scenes/main.tscn") != OK:
		_stop(false, "main scene could not start")
		return
	await scene_changed
	game = current_scene
	for i in 8:
		await physics_frame
	if not is_instance_valid(game.get("player")):
		_stop(false, "player could not start")
		return
	cleared_count = game.snapshot.cleared.count(true)
	while ticks < 60 * 60 * 75 and not ending:
		await physics_frame
		ticks += 1
		_release_pulses()
		var route: int = game.difficulty * 6 + game.region if game.region >= 0 else -1
		if route != last_region:
			_stop_walking()
			watch.clear()
			region_selected = -1
			retreat = false
			hp_seen = 100
			shopped = false
			last_region = route
			if route >= 0:
				trips += 1
				visited[route] = true
				print("CAMPAIGN_ENTER ", route, " sim_s=", snappedf(ticks/60.0,0.01), " gear=",game.snapshot.equipped.get("atk",0))
				if route >= target_routes and cleared_count >= target_routes:
					_stop(true, "entered next unlocked route")
					return
			elif FileAccess.file_exists(campaign_dir.path_join("pause.request")):
				_stop(false, "paused in town for independent measurement")
				return
		if is_instance_valid(game.error_layer):
			_stop(false, "save retry appeared")
			return
		if game.transitioning:
			continue
		var saved_clears: int = game.snapshot.cleared.count(true)
		if saved_clears > cleared_count:
			cleared_count = saved_clears
			unlock_times[route] = snappedf(ticks/60.0, 0.01)
			print("CAMPAIGN_CLEAR ", route, " sim_s=", unlock_times[route], " deaths=",deaths," species=",species_seen.size())
			route_start = ticks
			if cleared_count == 24:
				_stop(game.snapshot.ending, "final boss cleared")
				return
		if game.hud.panel_open():
			_panel()
		elif route < 0:
			_town()
		else:
			_field(route)
		if ticks % 2700 == 0:
			print("CAMPAIGN_PROGRESS ", cleared_count, " cleared; s=",ticks/60,
				" boss_low=",lowest_boss_hp.get(route,"-")," atk=",game.snapshot.equipped.get("atk",0)," ",_status())
		if ticks - route_start > 60 * 60 * 12:
			_stop(false, "12 simulated minutes without a route clear")
			return
	if not ending:
		_stop(false, "75 simulated minutes elapsed")

func _stop(success: bool, reason: String) -> void:
	if ending:
		return
	ending = true
	print("CAMPAIGN_RESULT ", JSON.stringify({"passed":success,"reason":reason,"requested_clears":target_routes,"cleared":cleared_count,
		"entered":visited.keys(),"species_seen":species_seen.keys(),"defeats":defeats,"deaths":deaths,"visits":trips,"purchases":purchases,
		"lowest_boss_hp":lowest_boss_hp,
		"clear_seconds":unlock_times,"simulation_seconds":ticks/60.0,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,
		"state":_status(), "temp_directory":campaign_dir}))
	quit(0 if success else 1)

func _panel() -> void:
	_stop_walking()
	if ticks - opened_tick > 480:
		_stop(false, "menu could not be operated")
		return
	if ticks < next_ui or mouse_held:
		return
	if training:
		_train_panel(_buttons())
		return
	if game.hud.active == "shop":
		if game.snapshot.bag.size() >= 28:
			sell_to_slots = 21
		if sell_to_slots > 0 and game.snapshot.bag.size() > sell_to_slots:
			var candidate := _sale_candidate()
			if candidate >= 0:
				if game.hud.section != "sell":
					_press_named("Tabsell")
				elif game.hud.selected != candidate:
					_press_named("SellItem%d" % candidate)
				else:
					_press_named("Sell")
				return
		sell_to_slots = 0
		if game.hud.section == "sell":
			_press_named("Tabbuy")
			return
		var coins := int(game.snapshot.coins)
		if shop_balance >= 0 and coins < shop_balance:
			@warning_ignore("integer_division")
			purchases += (shop_balance - coins) / 8
		shop_balance = coins
		for button: Button in _buttons():
			if button.name == "Buy":
				_click_button(button)
				opened_tick = ticks
				return
		shopped = true
		shop_balance = -1
		_tap(KEY_ESCAPE)
		next_ui = ticks + 7
		return
	var name_wanted: String
	if equipment_goal >= 0:
		if _goal_is_equipped():
			equipment_goal = -1
			_tap(KEY_ESCAPE)
			next_ui = ticks + 6
			return
		name_wanted = "Equip" if game.hud.selected == equipment_goal else "BagItem%d" % equipment_goal
	else:
		@warning_ignore("integer_division")
		var rank := cleared_count / 6
		if game.hud.difficulty != rank:
			name_wanted = "Difficulty%d" % rank
		elif game.hud.route != cleared_count % 6:
			name_wanted = "Route%d" % (cleared_count % 6)
		else:
			name_wanted = "Depart"
	for button: Button in _buttons():
		if str(button.name) == name_wanted and _reveal(button):
			_click_button(button)
			return

func _press_named(name_wanted: String) -> void:
	for button: Button in _buttons():
		if str(button.name) == name_wanted and _reveal(button):
			_click_button(button)
			opened_tick = ticks
			return

func _sale_candidate() -> int:
	var price_score := INF
	var selected := -1
	for item in game.snapshot.bag:
		if item.locked or item.design == 0 or item.atk >= game.snapshot.equipped.get("atk", 0):
			continue
		var score := float(item.grade * 100 + item.atk)
		if score < price_score:
			selected = item.id
			price_score = score
	return selected

func _town() -> void:
	var restock: bool = game.snapshot.coins >= 32 and game.snapshot.equipped.get("atk", 0) < 55
	if not shopped and (restock or game.snapshot.bag.size() >= 28) and cleared_count >= 6:
		if game.world.service_near(game.player.position) == "shop":
			_stop_walking()
			if ticks >= next_ui:
				_tap(KEY_F)
				next_ui = ticks + 5
				opened_tick = ticks
		else:
			_navigate(game.world.service_points().get("shop"))
		return
	super._town()

func _observe() -> void:
	for enemy in get_nodes_in_group("enemies"):
		var key: int = enemy.get_instance_id()
		if watch.has(key):
			continue
		watch[key] = true
		species_seen[enemy.species] = true
		enemy.defeated.connect(_on_defeat.bind(enemy.region, enemy.difficulty))

func _on_defeat(kind: String, _id: String, _position: Vector3, region: int, difficulty: int) -> void:
	var key := "%d/%s" % [difficulty * 6 + region, kind]
	defeats[key] = int(defeats.get(key, 0)) + 1

func _field(route: int) -> void:
	if ticks % 8 == 0:
		_observe()
		var boss = game.director.boss
		if is_instance_valid(boss) and boss.kind == "boss":
			lowest_boss_hp[route] = mini(boss.hp, int(lowest_boss_hp.get(route, boss.max_hp)))
	var player = game.player
	if player.hp <= 0:
		if hp_seen > 0:
			deaths += 1
		hp_seen = player.hp
		_stop_walking()
		return
	hp_seen = player.hp
	if game.snapshot.cleared[route]:
		if game.world.service_near(player.position) == "return" and game.combat_lock <= 0:
			_stop_walking()
			if ticks >= next_ui:
				_tap(KEY_F)
				next_ui = ticks + 5
		else:
			_navigate(game.world.entry_point())
		return
	if _start_training(): return
	if (_tactical_evade() if tactical else _evade_telegraph()):
		return
	if ticks >= next_ui and ticks % 37 == 0:
		equipment_goal = _upgrade()
		if equipment_goal >= 0:
			_stop_walking()
			_tap(KEY_I)
			opened_tick = ticks
			next_ui = ticks + 4
			return
	var target = _nearest()
	if is_instance_valid(game.director.boss) and game.director.boss.hp > 0:
		if not is_instance_valid(target) or player.position.distance_to(target.position) > 1.45 or player.position.distance_to(game.director.boss.position) < 3.0:
			target = game.director.boss
	if not is_instance_valid(target):
		_navigate(game.world.boss_point())
		return
	var goal: Vector3 = target.position
	var distance: float = player.position.distance_to(goal)
	var loot_distance := 3.5
	var closest := Vector3.ZERO
	for drop in game.director.state.drops:
		var gap: float = player.position.distance_to(drop.pos)
		if gap < loot_distance:
			loot_distance = gap
			closest = drop.pos
	if loot_distance < 3.5 and distance > 2.4 and game.snapshot.bag.size() < 30:
		_navigate(closest)
		return
	_aim_enemy(target)
	var reach := _reach(target)
	if distance > reach:
		_navigate(goal)
	else:
		_stop_walking()
	if _skill_in_range(distance, float(target.hit_radius)): return
	if distance <= reach and not mouse_held and ticks % 5 == 0:
		_mouse(true)

# 빛난 예고 영역들을 함께 읽고 주변 적을 피해 움직인다. 동시에 여러 줄이
# 겹치는 보스전에서 한 줄을 피하다 인접한 다른 줄을 밟지 않게 한다.
func _tactical_evade() -> bool:
	var hero = game.player
	var hazards := []
	var earliest := INF
	var bodies := get_nodes_in_group("enemies")
	for enemy in bodies:
		if hero.position.distance_squared_to(enemy.position) > 144:
			continue
		for mark in enemy.get_children():
			if not mark.has_method("contains_point") or mark.landed or mark.effect in ["heal","haste"]:
				continue
			var remaining: float = mark.windup - mark.age
			if remaining > 0.68 or remaining < -0.27:
				continue
			hazards.append(mark)
			if mark.contains_point(hero.position):
				earliest = minf(earliest, remaining)
	if earliest > 0.28:
		return false
	var target = _nearest()
	var best := -INF
	var best_point: Vector3 = hero.position
	for i in 12:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, i*TAU/12.0)
		if hero.test_move(hero.global_transform, dir * 0.62):
			continue
		var point: Vector3 = hero.position + dir * 1.55
		var score := 0.0
		for mark in hazards:
			if mark.contains_point(point):
				score -= 6
		for body in bodies:
			var flat := Vector2(body.position.x - point.x, body.position.z - point.z)
			score -= maxf(0, 1.7-flat.length()) * 1.6
		if is_instance_valid(target):
			score -= absf(point.distance_to(target.position)-1.9) * 0.18
		if score > best:
			best = score
			best_point = point
	if best == -INF:
		return false
	_walk_towards(best_point)
	if hero.cooldowns().dodge <= 0 and earliest <= 0.18:
		_tap(KEY_SPACE)
	return true

