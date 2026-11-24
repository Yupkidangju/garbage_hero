extends "first_expedition.gd"

# 새 슬롯에서 입력만 보낸다. 공개 상태와 월드 데이터는 검증·조준·길찾기를 위해 읽는다.
var districts_seen := {}
var defeated_species := {}
var active_mini_species := ""
var exploring := false
var exploration_done := false
var path_points := PackedVector2Array()
var path_index := 0
var crossing_id := ""
var crossing_surface_seen := false
var crossing_center_index := -1
var cache_id := ""
var cache_position := Vector3.ZERO
var cache_before := {}
var last_input_goal := Vector3.INF
var last_input_position := Vector3.INF
var movement_stalled := 0
var evidence_directory := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			evidence_directory = arg.trim_prefix("--evidence-dir=")
	if evidence_directory.is_empty():
		var timestamp := Time.get_datetime_string_from_system().replace(":","-")
		evidence_directory = ProjectSettings.globalize_path("res://../tasks/evidence/expedition030-input-"+timestamp)
	super._initialize()
	print("EXPEDITION030_FRESH ",JSON.stringify({"save":OS.get_environment("GARBAGEHERO_SAVE_DIR"),
		"prepared_stats":false,"prepared_items":false,"simulation_limit_seconds":1200,"rendering":"CPU headless"}))

func _forest() -> void:
	var state: Dictionary = game.director.state
	var district: String = game.world.district_at(game.player.position)
	if not districts_seen.has(district):
		districts_seen[district] = ticks / 60.0
		_mark("district_"+district)
	if is_instance_valid(game.director.boss) and game.director.boss.kind == "mini":
		active_mini_species = str(game.director.boss.species)
	if last_phase == "mini" and state.phase in ["hunt","boss"] and not active_mini_species.is_empty():
		defeated_species[active_mini_species] = last_mini_id
		_mark("defeated_species_"+active_mini_species)
	if exploring:
		if game.player.hp <= 0:
			exploring = false
			super._forest()
			return
		if _start_training():
			return
		_explore()
		return
	if not exploration_done and milestones.has("first_merge") and milestones.has("volley_cast"):
		_prepare_exploration()
		exploring = true
		_mark("exploration_started")
		_explore()
		return
	super._forest()

func _prepare_exploration() -> void:
	var map: Dictionary = game.world.map_data()
	var ford := Vector2.INF
	for crossing: Dictionary in map.crossings:
		if str(crossing.id).ends_with("river_ford"):
			ford = crossing.pos
			crossing_id = crossing.id
			break
	# 실제 외곽 길의 처음 구간을 따라 여울 양쪽을 건너 첫 소지역까지 간다.
	for road: PackedVector2Array in map.routes:
		var ford_index := -1
		for index in road.size():
			if road[index].distance_to(ford)<0.01:
				ford_index = index
				break
		if ford_index >= 0:
			path_points = road.slice(0,mini(ford_index+3,road.size()))
			crossing_center_index = ford_index
			break
	for cache: Dictionary in game.world.cache_points():
		if str(cache.id).ends_with("cache_grotto"):
			cache_id = cache.id
			cache_position = cache.pos
			break
	var cache_local: Vector3 = game.world.axes.to_local(cache_position)
	path_points.append(Vector2(cache_local.x,cache_local.z))
	path_index = 0
	print("EXPEDITION030_ROUTE ",JSON.stringify({"crossing":crossing_id,"cache":cache_id,"waypoints":str(path_points)}))

func _explore() -> void:
	if cache_id.is_empty() or path_points.is_empty() or crossing_id.is_empty():
		_stop(false,"source map has no usable ford/cache route")
		return
	var state: Dictionary = game.director.state
	# 길을 막는 실제 적은 전투 입력으로 물리친다. 전투 중 정지는 경로 실패로 세지 않는다.
	var target = _nearest()
	if is_instance_valid(target) and game.player.position.distance_to(target.position)<_reach(target)+0.15:
		movement_stalled = 0
		_aim_enemy(target)
		if not _evade_telegraph():
			_stop_walking()
			if not _skill_in_range(game.player.position.distance_to(target.position),float(target.hit_radius)) and not mouse_held and ticks%5==0:
				_mouse(true)
		return
	var surface: Dictionary = game.world.surface_at(game.player.position)
	var local: Vector3 = game.world.axes.to_local(game.player.position)
	var here := Vector2(local.x,local.z)
	if path_index >= crossing_center_index-1 and path_index <= crossing_center_index+1:
		if surface.kind in ["shallow","bridge"]:
			crossing_surface_seen = true
	while path_index < path_points.size() and here.distance_to(path_points[path_index])<1.1:
		if path_index == crossing_center_index+1 and crossing_surface_seen:
			_mark("ford_crossed_by_input")
		path_index += 1
	if cache_id in state.opened_caches:
		if not cache_before.is_empty():
			var rewarded := int(game.snapshot.coins) >= int(cache_before.coins)+8
			var receipt: bool = game.session._data.quest_history.caches.has(cache_id)
			if not rewarded or not receipt:
				_stop(false,"F-key cache opened without its expected saved reward")
				return
			_mark("cache_F_reward")
		exploration_done = true
		exploring = false
		nav_steps.clear()
		_mark("exploration_completed")
		return
	if game.world.cache_near(game.player.position) == cache_id and game.player.position.distance_to(cache_position)<=2.0:
		_stop_walking()
		if ticks >= next_ui:
			if cache_before.is_empty():
				cache_before = {"coins":game.snapshot.coins,"drop_ids":state.drops.map(func(item):return item.id)}
			_tap(KEY_F)
			next_ui = ticks+6
		return
	var point := path_points[mini(path_index,path_points.size()-1)]
	var goal: Vector3 = game.world.axes.to_global(Vector3(point.x,0,point.y))
	goal.y = game.world.ground_at(goal)
	_navigate(goal)
	_watch_path_stall(goal)

func _start_training() -> bool:
	var growth: Dictionary = game.snapshot.progression
	if milestones.has("volley_assigned") and growth.stat_points>0 and ticks>=next_ui:
		training = true
		_stop_walking()
		opened_tick = ticks
		next_ui = ticks+4
		_tap(KEY_K)
		return true
	return super._start_training()

func _train_panel(buttons:Array) -> void:
	var growth: Dictionary = game.snapshot.progression
	if milestones.has("volley_assigned") and growth.stat_points>0:
		var wanted := "Tabattributes"
		if game.hud.section=="attributes":
			wanted = "Allocatevitality" if growth.attributes.vitality<6 else "Allocatestrength"
		for button: Button in buttons:
			if str(button.name)==wanted:
				_click_button(button)
				return
		return
	super._train_panel(buttons)

func _watch_path_stall(goal:Vector3) -> void:
	if last_input_goal.distance_to(goal)>1.0:
		last_input_goal = goal
		last_input_position = game.player.position
		movement_stalled = 0
	if ticks % 30 != 0:
		return
	if game.player.position.distance_to(last_input_position)<0.12 and game.player.position.distance_to(goal)>2.0:
		movement_stalled += 30
	else:
		movement_stalled = 0
	last_input_position = game.player.position
	if movement_stalled>=300:
		_stop(false,"ten simulated seconds without progress toward map route point %d goal=%s" % [path_index,goal])

func _stop(success:bool,reason:String) -> void:
	if ending:
		return
	var added_gates := exploration_done and districts_seen.size()>=2 and defeated_species.size()==2
	added_gates = added_gates and milestones.has("cache_F_reward") and milestones.has("ford_crossed_by_input")
	var passed := success and added_gates
	if success and not added_gates:
		reason = "original expedition reached desert but 0.3 exploration/species gates remain"
	var detail := {"passed":passed,"reason":reason,"districts":districts_seen,"defeated_species":defeated_species,
		"crossing":crossing_id,"crossing_surface_seen":crossing_surface_seen,"cache":cache_id,
		"path_index":path_index,"milestones":milestones,"simulation_seconds":ticks/60.0,
		"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"save_origin":"fresh game, input only",
		"deaths":deaths,"forest_visits":trips,"checkpoints":{}}
	if is_instance_valid(game) and not game.snapshot.is_empty():
		detail.progression = game.snapshot.progression
		detail.equipment = game.snapshot.equipment
		if is_instance_valid(game.director):
			detail.world = game.director.state
		detail.forest_save = game.session.world_state(0,0)
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	var save_folder := OS.get_environment("GARBAGEHERO_SAVE_DIR")
	for bank in 2:
		var name := "slot-v3-%d.sav" % bank
		var source := save_folder.path_join(name)
		if FileAccess.file_exists(source):
			var target := evidence_directory.path_join(name)
			var original_hash := FileAccess.get_sha256(source)
			if DirAccess.copy_absolute(source,target)==OK:
				var copied_hash := FileAccess.get_sha256(target)
				var verified := copied_hash==original_hash
				detail.checkpoints[name] = {"sha256":copied_hash,"copy_matches_source":verified}
				print("EXPEDITION030_CHECKPOINT ",name," sha256=",copied_hash," copy_matches_source=",verified)
	var report := FileAccess.open(evidence_directory.path_join("result.json"),FileAccess.WRITE)
	if report:
		report.store_string(JSON.stringify(detail,"\t"))
		report.close()
	print("EXPEDITION030_RESULT ",JSON.stringify(detail))
	super._stop(passed,reason)
