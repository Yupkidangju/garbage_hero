extends "first_expedition.gd"

# 별도 슬롯에 구입 자금과 레벨을 준비하고, 본 씬의 이동·대화·메뉴는 키와 마우스로 조작한다.
const Session = preload("res://scripts/session.gd")
const Slot = preload("res://scripts/slot_store.gd")
const Growth = preload("res://data/progression.gd")
var capture_dir := ""
var successful_clicks := 0
var legacy_controls := false

func _initialize() -> void:
	folder = DirAccess.create_temp("garbagehero-progression-ui")
	var save_dir := folder.get_current_dir().path_join("save")
	OS.set_environment("GARBAGEHERO_SAVE_DIR",save_dir)
	OS.set_environment("GARBAGEHERO_SETTINGS_PATH",folder.get_current_dir().path_join("settings.cfg"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg=="--legacy-controls": legacy_controls = true
	if legacy_controls:
		var old_prefs := ConfigFile.new()
		old_prefs.set_value("input","move_left",["key",KEY_K])
		old_prefs.set_value("input","attack",["key",KEY_J])
		if old_prefs.save(OS.get_environment("GARBAGEHERO_SETTINGS_PATH"))!=OK:
			_failure("Could not prepare legacy control settings")
			return
	root.size = Vector2i(1280,720)
	var setup := Session.new()
	var data := setup._new_slot()
	setup.free()
	data.coins = 400
	while data.progression.level<4: Growth.gain(data.progression,1,"normal")
	data.traveler = {"available":true,"sold":false,"region":0,"price":18}
	if not Slot.new(save_dir).commit(data):
		_failure("Could not create isolated fixture")
		return
	_verify.call_deferred()

func _failure(message: String) -> void:
	push_error("PROGRESSION_UI "+message)
	quit(1)

func _settle(count := 3) -> void:
	for frame in count: await process_frame

func _press(code: Key) -> void:
	_key(code,true)
	await _settle(1)
	_key(code,false)
	await _settle()

func _capture(stem: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	var path := capture_dir.path_join(stem+".png")
	if root.get_texture().get_image().save_png(path)!=OK: _failure("capture "+path)

func _wheel_event(point: Vector2, up: bool) -> void:
	_aim(point)
	var event := InputEventMouseButton.new()
	event.position = cursor
	event.global_position = cursor
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.factor = 1
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _click(id: String) -> void:
	for attempt in 55:
		var b := game.hud.find_child(id,true,false) as Button
		if not b or not b.is_visible_in_tree() or b.disabled:
			_failure("Unavailable button "+id)
			return
		var point := b.get_global_rect().get_center()
		var scrolls: Array[ScrollContainer] = []
		var ancestor := b.get_parent()
		while ancestor:
			if ancestor is ScrollContainer: scrolls.append(ancestor)
			ancestor = ancestor.get_parent()
		var scrolled := false
		for scroll in scrolls:
			var r := scroll.get_global_rect().grow(-3)
			if point.y < r.position.y or point.y > r.end.y:
				_wheel_event(r.get_center(),point.y < r.position.y)
				await _settle()
				scrolled = true
				break
		if scrolled: continue
		_aim(point)
		await _settle(1)
		var hover := root.gui_get_hovered_control()
		if hover!=b and (not hover or not b.is_ancestor_of(hover)):
			_failure("Button %s at %s is covered by %s"%[id,point,hover])
			return
		_mouse(true)
		await _settle(1)
		_mouse(false)
		successful_clicks+=1
		if id!="Quit": await _settle(4)
		return
	_failure("Could not scroll to "+id)

func _service(id: String) -> void:
	for i in 420:
		await physics_frame
		if game.world.service_near(game.player.position)==id:
			_stop_walking()
			await _press(KEY_F)
			if game.hud.active!=id: _failure("F did not open "+id)
			return
		_walk_towards(game.world.service_points()[id])
	_failure("Could not walk to "+id)

func _buy_design(vendor: String, design: int) -> int:
	var wallet: int = game.snapshot.coins
	var price := 0
	for offer in game.snapshot.offers[vendor]:
		if offer.design==design: price = offer.price
	await _click("Offer%d"%design)
	await _click("Buy")
	if price<1 or game.snapshot.coins!=wallet-price: _failure("Purchase of %d did not deduct quoted price"%design)
	for item in game.snapshot.bag:
		if item.design==design: return int(item.id)
	_failure("Purchased offer missing from bag")
	return -1

func _verify() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game = current_scene
	await _settle(8)
	if legacy_controls:
		await _verify_legacy_controls()
		return
	await _press(KEY_K)
	if game.hud.active!="skills" or not paused: _failure("K failed to open growth and pause")
	await _click("Skillvolley")
	await _click("LearnSkill")
	await _click("LearnSkill")
	await _click("Assign1")
	if game.snapshot.progression.ranks.volley!=2 or game.snapshot.progression.loadout[1]!="volley": _failure("Learning, upgrade or assignment failed")
	await _capture("skill-tree")
	await _click("Tabattributes")
	var previous_atk: int = game.snapshot.stats.atk
	await _click("Allocatestrength")
	if game.snapshot.stats.atk!=previous_atk+2: _failure("Strength did not change actual combat stats")
	await _press(KEY_K)
	await _click("Quickskills")
	await _click("Skillhook")
	await _click("Assign2")
	if game.snapshot.progression.loadout!=["","volley","hook"]: _failure("Skill reassignment")
	await _press(KEY_K)
	await _press(KEY_ESCAPE)
	await _click("OpenSettings")
	await _click("Scale150")
	await _click("Tabcontrols")
	await _click("Bindskills")
	await _press(KEY_L)
	await _press(KEY_ESCAPE)
	await _press(KEY_ESCAPE)
	await _press(KEY_L)
	if game.hud.active!="skills": _failure("Rebound growth action")
	await _click("Skillvolley")
	await _click("Assign0")
	await _press(KEY_L)
	if game.hud.quick.get_global_rect().intersects(game.hud.art.skill_row_rect(game.hud.screen.size)): _failure("Quick buttons overlap active skill bar")
	for frame in 75:
		await physics_frame
		if game.player._move.is_empty(): break
	await _press(KEY_Q)
	await _settle(10)
	if game.hud.art.info.progression.loadout[0]!="volley" or game.hud.art.info.cooldowns.hook<=0:
		_failure("HUD skill or timer mismatches: slots=%s cooldowns=%s player_move=%s player_timers=%s paused=%s"%[game.hud.art.info.progression.loadout,game.hud.art.info.cooldowns,game.player._move,game.player.cooldowns(),paused])
	await _capture("hud-150")
	await _service("shop")
	var shield: int = await _buy_design("shop",12)
	var bow: int = await _buy_design("shop",7)
	await _capture("shop-150")
	var pieces := {}
	for design in [11,13,14,15,16]:
		pieces[design] = await _buy_design("shop",design)
	await _buy_design("shop",13)
	pieces[13] = await _buy_design("shop",13)
	var fusion: Dictionary = game.snapshot.last_merge
	if fusion.item.design!=13 or fusion.item.grade!=1: _failure("Boots did not fuse")
	await _press(KEY_ESCAPE)
	await _press(KEY_I)
	await _click("BagItem%d"%shield)
	var recorded := game.hud.find_child("LastFusionComparison",true,false) as Label
	if not recorded or not recorded.text.ends_with(fusion.comparison): _failure("Boot fusion comparison was lost when shield selected")
	await _click("Equip")
	if game.snapshot.equipment.shield.get("id")!=shield: _failure("Shield did not equip")
	await _click("BagItem%d"%bow)
	await _click("Equip")
	if game.snapshot.equipment.weapon.get("id")!=bow or not game.snapshot.equipment.shield.is_empty(): _failure("Two-hand swap")
	await _click("BagItem%d"%shield)
	if not game.hud.find_child("Equip",true,false).disabled: _failure("Unavailable shield should be disabled")
	await _click("Tabequipped")
	await _click("Unequip")
	if not game.snapshot.equipment.weapon.is_empty(): _failure("Unequip did not update weapon slot")
	await _click("Tabbag")
	for id in [1,shield]+pieces.values():
		await _click("BagItem%d"%id)
		await _click("Equip")
	await _click("Tabequipped")
	for slot in game.snapshot.equipment:
		if game.snapshot.equipment[slot].is_empty(): _failure("Missing "+slot)
	await _capture("equipment-150")
	if not capture_dir.is_empty():
		await _press(KEY_ESCAPE)
		await _press(KEY_ESCAPE)
		await _click("OpenSettings")
		await _click("Scale100")
		await _press(KEY_ESCAPE)
		await _press(KEY_ESCAPE)
		await _press(KEY_I)
		await _click("Tabequipped")
		await _capture("equipment")
		await _press(KEY_ESCAPE)
		await _press(KEY_ESCAPE)
		await _click("OpenSettings")
		await _click("Scale150")
		await _press(KEY_ESCAPE)
		await _press(KEY_ESCAPE)
		await _press(KEY_I)
		await _click("Tabequipped")
	await _click("Unequipnecklace")
	if not game.snapshot.equipment.necklace.is_empty(): _failure("Could not reach seventh equipped item")
	await _click("OpenSkills")
	await _click("Tabattributes")
	await _capture("attributes-150")
	await _press(KEY_ESCAPE)
	await _press(KEY_ESCAPE)
	await _service("traveler")
	await _buy_design("traveler",17)
	if not game.hud.find_child("Buy",true,false).disabled: _failure("Purchased traveling offer still available")
	await _click("Offer23")
	if game.hud.find_child("Buy",true,false).disabled: _failure("Other traveling offer should still be available")
	await _press(KEY_ESCAPE)
	await _service("elder")
	await _click("Quest8")
	var gold: int = game.snapshot.coins
	await _click("Claim")
	var claim: Dictionary = game.snapshot.quests[8]
	if not claim.claimed or game.snapshot.coins!=gold+claim.reward: _failure("New training quest reward")
	await _capture("quest-150")
	await _press(KEY_ESCAPE)
	await _press(KEY_ESCAPE)
	await _click("Quit")
	if not game.shutting_down: _failure("Game quit button did not start shutdown")
	print("PROGRESSION_UI PASS ",successful_clicks," GUI clicks | K/L/F/I/Esc | pixels=",root.size," window_mode=",root.mode," | 100%/150%")

func _verify_legacy_controls() -> void:
	var bindings := InputMap.action_get_events("skills")
	if bindings.size()!=1 or bindings[0].physical_keycode in [KEY_K,KEY_J]:
		_failure("Growth took an explicitly assigned legacy key")
		return
	var growth_key: Key = bindings[0].physical_keycode
	var position: Vector3 = game.player.position
	_key(KEY_K,true)
	for frame in 24: await physics_frame
	_key(KEY_K,false)
	if paused or (game.player.position-position).dot(RIGHT)>-0.5 or not InputMap.event_is_action(_physical(KEY_J),"attack"):
		_failure("Legacy movement or attack assignment was lost")
		return
	var quick := game.hud.find_child("Quickskills",true,false) as Button
	if not quick.text.contains(OS.get_keycode_string(growth_key)):
		_failure("HUD does not show migrated controls")
		return
	await _press(growth_key)
	if not paused or game.hud.active!="skills":
		_failure("Alternative growth shortcut did not open its panel")
		return
	await _press(growth_key)
	await _press(KEY_ESCAPE)
	await _click("OpenSettings")
	await _click("Scale125")
	var saved := ConfigFile.new()
	saved.load(OS.get_environment("GARBAGEHERO_SETTINGS_PATH"))
	if saved.get_value("input","move_left")!=["key",KEY_K] or saved.get_value("input","attack")!=["key",KEY_J] or saved.get_value("input","skills")!=["key",growth_key]:
		_failure("Saving preferences did not keep migrated assignments")
		return
	await _press(KEY_ESCAPE)
	await _click("Quit")
	print("LEGACY_UI_KEYS PASS K=move_left J=attack ",OS.get_keycode_string(growth_key),"=skills")

func _physical(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event
