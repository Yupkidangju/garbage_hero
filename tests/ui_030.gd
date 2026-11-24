extends "progression_input.gd"

# 0.3.0 UI 검수용 준비 상태다. 자연 진행 증거와 구분하고 실제 메뉴 입력/저장은 그대로 사용한다.
const ItemBook = preload("res://data/loot_rules.gd")
var fixture_items := {}
var checks := 0
var failures := 0
var watchdog_deadline := 0

func _initialize() -> void:
	folder = DirAccess.create_temp("garbagehero-ui030")
	var save_dir := folder.get_current_dir().path_join("save")
	OS.set_environment("GARBAGEHERO_SAVE_DIR",save_dir)
	OS.set_environment("GARBAGEHERO_SETTINGS_PATH",folder.get_current_dir().path_join("settings.cfg"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	root.size = Vector2i(1280,720)
	var setup := Session.new()
	var data := setup._new_slot()
	setup.free()
	data.coins = 20000
	data.auto = false
	while data.progression.level<8: Growth.gain(data.progression,1,"normal")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3088
	var designs := [0,0,0,7,11,12,13,14,15,16,30,47,63,80]
	for design in designs:
		var item := ItemBook.weapon(data.next_id,design,0,rng)
		data.next_id += 1
		data.bag.append(item)
		if not fixture_items.has(design): fixture_items[design] = []
		fixture_items[design].append(item.id)
	data.traveler = {"available":true,"sold":false,"region":0,"price":18}
	for route in data.routes: route.cleared = true
	if not Slot.new(save_dir).commit(data):
		_failure("Could not create 0.3.0 isolated fixture")
		return
	_verify.call_deferred()

func check(result: bool, label: String) -> void:
	checks += 1
	print("UI030_CHECK %d %s %s"%[checks,"PASS" if result else "FAIL",label])
	if not result:
		failures += 1
		push_error("UI030 "+label)

func _capture(stem: String) -> void:
	if capture_dir.is_empty(): return
	if stem.begins_with("skills") or stem.begins_with("shop") or stem.begins_with("elder") or stem.begins_with("coach"):
		for step in 35:
			if game.hud.menu_scroll.scroll_vertical<=0: break
			_wheel_event(game.hud.menu_scroll.get_v_scroll_bar().get_global_rect().get_center(),true)
			await _settle(1)
	await _settle(2)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	check(image!=null and not image.is_empty(),"native viewport capture "+stem)
	check(game.hud.body.size.x<=game.hud.menu_scroll.size.x+1,"no horizontal overflow "+stem)
	if image and image.save_png(capture_dir.path_join(stem+".png"))!=OK: _failure("capture "+stem)

func _verify() -> void:
	print("UI030 starting prepared fixture")
	watchdog_deadline = Time.get_ticks_msec() + 180000
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game = current_scene
	await _settle(8)
	var pictures := 0
	for design in 88:
		var texture = game.hud.S.item_art({"design":design})
		if texture!=null and texture.get_width()>=128 and texture.get_height()>=128: pictures += 1
	check(pictures==88,"all88dedicated item paintings load at runtime")
	var original_player: Vector3 = game.player.position
	var group_count := get_nodes_in_group("player").size()
	await _press(KEY_I)
	check(paused and game.hud.active=="inventory","I opens inventory and pauses")
	var preview = game.hud.find_child("CharacterPreview",true,false)
	check(is_instance_valid(preview) and preview.viewport.own_world_3d,"actual hero uses an isolated World3D")
	check(preview.hero.preview_mode and preview.hero.collision_layer==0 and not preview.hero.is_in_group("player"),"preview cannot join combat or collision")
	check(preview.hero._power==game.snapshot.stats.atk,"preview uses actual build")
	var equipment_count := 0
	for slot in ["weapon","armor","shield","boots","helmet","ring","necklace"]:
		if game.hud.find_child("Slot"+slot,true,false): equipment_count += 1
	check(equipment_count==7,"all seven equipment image slots exist")
	await _capture("inventory-030")
	for id in fixture_items[0]:
		await _click("BagItem%d"%id)
		await _click("Material")
	check(not game.hud.find_child("Merge",true,false).disabled,"three identical designs enable fusion")
	await _click("Merge")
	check(game.snapshot.last_merge.item.grade==1 and game.snapshot.bag.size()==12,"clicked fusion commits three to one")
	check(is_instance_valid(game.hud.celebration),"fusion success has an illustrated feedback panel")
	await _capture("fusion-030")
	await _click("BagItem%d"%fixture_items[7][0])
	await _click("Equip")
	check(game.snapshot.equipment.weapon.weapon_type=="bow","icon-grid equip reaches actual weapon")
	preview = game.hud.find_child("CharacterPreview",true,false)
	check(preview.hero._weapon_type=="bow","character preview changes with actual equipment")
	await _click("BagItem%d"%fixture_items[12][0])
	check(game.hud.find_child("Equip",true,false).disabled,"two-hand shield reason disables equip")
	await _click("Slotweapon")
	await _click("Tabbag")
	check(game.hud.inventory_filter=="bow","worn weapon returns to its valid weapon type filter")
	await _click("FilterPrevious")
	await _click("FilterPrevious")
	await _press(KEY_I)
	await _press(KEY_K)
	await _click("Skillvolley")
	var skill_preview = game.hud.find_child("SkillPreview",true,false)
	check(is_instance_valid(skill_preview),"skill selection has live cast viewport")
	await _click("ReplaySkill")
	check(skill_preview.hero._move=="volley" or skill_preview.casting,"replay starts actual volley combat move")
	await _click("LearnSkill")
	await _click("Assign1")
	check(game.snapshot.progression.ranks.volley==1 and game.snapshot.progression.loadout[1]=="volley","illustrated skill learn and assign commits")
	await _capture("skills-030")
	await _click("Tabattributes")
	var attack: int = game.snapshot.stats.atk
	await _click("Allocatestrength")
	check(game.snapshot.stats.atk==attack+2,"attributes still change real combat stats")
	await _press(KEY_K)
	check(get_nodes_in_group("player").size()==group_count and game.player.position.is_equal_approx(original_player),"all preview time leaves main player and group unchanged")
	await _press(KEY_ESCAPE)
	await _click("OpenSettings")
	await _click("Scale150")
	await _press(KEY_ESCAPE)
	await _press(KEY_ESCAPE)
	await _press(KEY_I)
	await _click("FilterPrevious")
	await _press(KEY_ENTER)
	check(game.hud.inventory_filter=="ring","keyboard selects an item type filter")
	await _capture("inventory-030-150")
	await _press(KEY_I)
	await _service("shop")
	check(game.snapshot.offers.shop.size()==88,"all unlocked commission designs can be purchased")
	await _click("Offer0")
	var balance: int = game.snapshot.coins
	var price: int = game.snapshot.offers.shop[0].price
	await _click("Buy")
	check(game.snapshot.coins==balance-price,"illustrated shop Buy commits quoted price")
	await _capture("shop-030-150")
	await _press(KEY_ESCAPE)
	await _service("elder")
	check(is_instance_valid(game.hud.find_child("Portraitelder",true,false)),"elder portrait is present")
	await _capture("elder-030-150")
	await _press(KEY_ESCAPE)
	await _service("coach")
	await _click("Route5")
	check(not game.hud.find_child("Depart",true,false).disabled,"unlocked illustrated destination is actionable")
	await _capture("coach-030-150")
	await _press(KEY_ESCAPE)
	game.session.act("depart",{"region":0,"difficulty":0})
	game._enter(0,0)
	await _settle(5)
	await _press(KEY_M)
	var chart = game.hud.find_child("AreaMap",true,false)
	check(chart.map_data.bounds.size==Vector2(256,224) and chart.map_data.districts.size()==5,"map uses expanded world and five actual districts")
	check(chart.map_data.waters.size()>0 and chart.map_data.crossings.size()>=2 and chart.map_data.caches.size()==3,"map water crossing and treasure marks share world data")
	await _capture("map-030-150")
	await _press(KEY_ESCAPE)
	paused = false
	await game.prepare_shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("UI030: %d checks, %d failures, %d actual mouse clicks; prepared fixture, isolated save %s"%[checks,failures,successful_clicks,folder.get_current_dir()])
	quit(1 if failures else 0)

func _process(_delta: float) -> bool:
	if watchdog_deadline > 0 and Time.get_ticks_msec() > watchdog_deadline:
		watchdog_deadline = 0
		_failure("UI030 watchdog")
	return false
