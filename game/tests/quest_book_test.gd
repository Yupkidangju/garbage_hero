extends SceneTree

const Book = preload("res://data/quest_book.gd")
const Layout = preload("res://scripts/world/field_layout.gd")
const Session = preload("res://scripts/session.gd")
var failures := 0
var checks := 0

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	return condition

func _initialize() -> void:
	var data := {"coins":0, "claimed":[false,false,false,true,false,false,false],
		"first_merge":false, "routes":[], "progression":{"level":1,"ranks":{"hook":1}}}
	for i in 24:
		data.routes.append({"cleared":false})
	data.routes[18].cleared = true
	Book.initialize(data)
	var entries := Book.views(data)
	check(entries.size() == Book.COUNT and data.claimed.size() == entries.size(), "append new claim flags")
	check(entries[3].claimed and not entries[4].claimed, "preserve legacy claim identity")
	check(entries[1].progress == 1 and not entries[1].eligible and not entries[1].prerequisite.is_empty(), "prior clear on another difficulty awaits first claim")
	for entry: Dictionary in entries:
		check(not entry.name.is_empty() and not entry.description.is_empty() and entry.target > 0, "localized objective %d" % entry.id)
	check(not Book.claim(data, -1) and not Book.claim(data, entries.size()) and not Book.claim(data, 1), "invalid or locked claim does not pay")
	data.first_merge = true
	check(Book.claim(data, 0) and data.coins == 12, "first merge reward")
	check(Book.claim(data, 1) and data.coins == 32 and not Book.claim(data, 1), "field reward paid once")
	data.progression.level = 3
	data.progression.ranks.hook = 3
	data.progression.ranks.spin = 1
	entries = Book.views(data)
	check(entries[7].progress == 3 and entries[7].eligible, "level milestone")
	check(not entries[8].eligible, "automatic spin award does not count as tree-exclusive training")
	check(entries[9].progress == 3 and not entries[9].eligible and not entries[9].prerequisite.is_empty(), "mastery tracked before prerequisite")
	data.progression.ranks.volley = 1
	check(Book.claim(data, 8) and Book.claim(data, 9), "training claim unlocks earlier mastery")
	Book.record_equip(data, "weapon", "spear")
	Book.record_equip(data, "shield", "")
	check(not Book.views(data)[10].eligible and Book.views(data)[11].progress == 0, "shield and melee do not count toward equipment objectives")
	Book.record_equip(data, "weapon", "bow")
	Book.record_equip(data, "weapon", "sword")
	Book.record_equip(data, "boots", "")
	Book.record_equip(data, "boots", "")
	Book.record_equip(data, "helmet", "")
	check(Book.views(data)[10].eligible and Book.views(data)[11].progress == 2, "swapping weapon preserves history and duplicate fitting counts once")
	Book.record_equip(data, "armor", "")
	check(Book.views(data)[11].eligible, "all three armor slots tried")
	check(not Book.record_landmark(data, -1, "gate") and not Book.record_landmark(data, 6, "gate") and not Book.record_landmark(data, 0, ""), "reject invalid exploration events")
	check(not Book.record_landmark(data, 0, "0:fake") and not Book.record_landmark(data, 1, "0:mill"), "unknown and cross-region identifiers rejected")
	for region in 6:
		var first := "%d:%s" % [region, Layout.TITLES[region][0]]
		check(Book.record_landmark(data, region, first), "first discovery")
		check(not Book.record_landmark(data, region, first), "revisit has no effect")
		check(Book.views(data)[12 + region].progress == 1, "region-specific progress")
		check(Book.record_landmark(data, region, "%d:%s" % [region, Layout.TITLES[region][1]]), "second discovery")
		check(Book.views(data)[12 + region].eligible, "regional survey complete")
	check(Book.claim(data, 12), "first regional reward")
	var loaded: Dictionary = bytes_to_var(var_to_bytes(data))
	Book.initialize(loaded)
	check(loaded == data and not Book.claim(loaded, 12), "history and claimed rewards survive reload")
	check(Book.views(loaded)[10].eligible and Book.views(loaded)[17].progress == 2, "completed optional objectives persist")
	check(Book.valid_history(loaded.quest_history), "valid completed history")
	for invalid in [null, {}, {"ranged":1,"armor_slots":{},"landmarks":{}},
			{"ranged":false,"armor_slots":{"weapon":true},"landmarks":{}},
			{"ranged":false,"armor_slots":{"armor":false},"landmarks":{}},
			{"ranged":false,"armor_slots":{},"landmarks":{"00":{"0:mill":true}}},
			{"ranged":false,"armor_slots":{},"landmarks":{"1":{"0:mill":true}}},
			{"ranged":false,"armor_slots":{},"landmarks":{"0":{"0:mill":false}}}]:
		check(not Book.valid_history(invalid), "reject malformed history: %s" % str(invalid))
	_session_quest_loop()
	print("Quest book: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)

func _session_quest_loop() -> void:
	var folder := DirAccess.create_temp("garbagehero-quest")
	var session := Session.new()
	if not check(session.start_slot(folder.get_current_dir()), "start real slot for optional quests"):
		session.free()
		return
	check(session.act("depart", {"region":0,"difficulty":0}), "depart for quest survey")
	var marks := Layout.new(0).landmarks
	check(session.discover(0, 0, marks[0].id) and session.discover(0, 0, marks[0].id), "discovery and idempotent revisit")
	check(not session.discover(1, 0, marks[0].id) and not session.discover(0, 0, "0:fake"), "reject invalid survey transactions")
	check(session.ui_state().quests[12].progress == 1, "duplicate discovery earns no survey credit")
	check(session.discover(0, 0, marks[1].id), "complete regional survey")
	check(not session.act("claim", {"quest":12}), "elder pays in village only")
	for cycle in 2:
		for count in 12:
			check(session.record_kill(0, 0, "normal", "quest-%d" % (12 * cycle + count), Vector3.ZERO), "earn field experience")
		var mini_id: String = session.world_state(0, 0).spawn_id
		check(session.record_kill(0, 0, "mini", mini_id, Vector3.ZERO), "earn miniboss experience")
	check(session.act("return"), "visit elder after survey")
	check(session.act("learn_skill", {"skill":"hook"}) and session.act("learn_skill", {"skill":"hook"}), "upgrade starter to rank three")
	check(not session.act("claim", {"quest":9}), "mastery waits for training claim")
	check(session.act("learn_skill", {"skill":"volley"}), "learn a tree-exclusive skill")
	var before: int = session.ui_state().coins
	var reward := 0
	for id in [7, 8, 9, 12]:
		reward += int(session.ui_state().quests[id].reward)
		check(session.act("claim", {"quest":id}), "claim earned milestone %d" % id)
	check(session.ui_state().coins == before + reward, "elder pays displayed rewards")
	for offer: Dictionary in session.ui_state().offers.shop:
		if offer.weapon_type != "bow" and offer.slot not in Book.ARMOR_SLOTS:
			continue
		if not check(session.act("buy", {"vendor":"shop","design":offer.design}), "buy quest gear"):
			continue
		var bought: Dictionary = session.ui_state().bag.back()
		check(session.act("equip", {"id":bought.id}) and session.act("unequip", {"id":bought.id}), "record equipment tried, then stowed")
	session.free()
	session = Session.new()
	check(session.start_slot(folder.get_current_dir()), "resume quest slot")
	before = session.ui_state().coins
	check(not session.act("claim", {"quest":12}) and before == session.ui_state().coins, "restart cannot pay survey twice")
	var bank := 1 if session._slot.active_bank == 0 else 0
	var blocked: String = session._slot._path(bank) + ".tmp"
	check(DirAccess.make_dir_absolute(blocked) == OK, "block next staged save")
	check(not session.act("claim", {"quest":10}) and before == session.ui_state().coins and not session.ui_state().quests[10].claimed, "failed reward save rolls back money and claim")
	check(DirAccess.remove_absolute(blocked) == OK, "restore save writes")
	check(session.act("claim", {"quest":10}) and session.act("claim", {"quest":11}), "elder remembers stowed weapon and armor on restart")
	var total_after_all: int = session.ui_state().coins
	var damaged: Dictionary = session._data.duplicate(true)
	damaged.quest_history.armor_slots = {"unknown":true}
	var bytes := var_to_bytes(damaged)
	var file := FileAccess.open(session._slot._path(session._slot.active_bank), FileAccess.WRITE)
	file.store_buffer(session._slot.MAGIC.to_ascii_buffer())
	file.store_buffer(session._slot._digest(bytes))
	file.store_buffer(bytes)
	file.close()
	session.free()
	session = Session.new()
	check(session.start_slot(folder.get_current_dir()) and session._slot.recovered, "fall back after checksum-valid quest history corruption")
	check(session.ui_state().quests[10].claimed and not session.ui_state().quests[11].claimed, "restore exact previous quest claims")
	check(session.act("claim", {"quest":11}) and session.ui_state().coins == total_after_all, "recovered bank can earn the same final total")
	session.free()
