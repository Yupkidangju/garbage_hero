extends SceneTree

const Session = preload("res://scripts/session.gd")
const Layout = preload("res://scripts/world/field_layout.gd")
const Slot = preload("res://scripts/slot_store.gd")
const Loot = preload("res://data/loot_rules.gd")
var checks := 0
var failures := 0
var temporary: DirAccess
var session

func _initialize() -> void:
	temporary = DirAccess.create_temp("garbagehero-030-session")
	_cache_and_elite()
	_v2_preservation()
	if is_instance_valid(session):
		session.free()
	print("Expansion 0.3 session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	return ok

func open_slot(name: String) -> bool:
	if is_instance_valid(session):
		session.free()
	session = Session.new()
	return check(session.start_slot(temporary.get_current_dir().path_join(name)), "open " + name)

func _cache_and_elite() -> void:
	if not open_slot("cache"):
		return
	check(session._data.schema == 3 and session.ui_state().quests.size() == 24, "current save and treasure quests")
	check(not session.open_cache(0, 0, "0:cache_grotto", Vector3.ZERO), "town has no field cache")
	check(session.act("depart", {"region":0, "difficulty":0}), "travel to forest")
	check(session.discover(0, 0, "0:grotto") and session._data.quest_history.landmarks["0"].has("0:grotto"), "new grotto discovery is a valid persisted landmark")
	var before: Dictionary = session._data.duplicate(true)
	check(not session.open_cache(0, 0, "1:cache_grotto", Vector3.ZERO) and session._data == before, "reject cross-region reward")
	var layout := Layout.new(0)
	var cache_district := ""
	for cache: Dictionary in layout.caches:
		if cache.id == "0:cache_grotto":
			cache_district = layout.district_at(cache.pos)
	var rng := RandomNumberGenerator.new()
	rng.state = before.rng.loot
	var expected_design := Loot.draw_design(0, rng, cache_district)
	check(session.open_cache(0, 0, "0:cache_grotto", Vector3.ZERO), "open valid cache")
	check(session.world_state(0, 0).drops[0].design == expected_design, "cache focus comes from its actual district")
	check(session.ui_state().coins == 8 and session.world_state(0, 0).drops.size() == 1, "coin and floor item together")
	check(session.ui_state().quests[18].eligible and session.world_state(0, 0).opened_caches == ["0:cache_grotto"], "one treasure objective")
	before = session._data.duplicate(true)
	check(not session.open_cache(0, 0, "0:cache_grotto", Vector3.ZERO) and session._data == before, "repeat cache has no payout")
	var target: String = session._slot._path(1-session._slot.active_bank) + ".tmp"
	check(DirAccess.make_dir_absolute(target) == OK, "inject cache write failure")
	check(not session.open_cache(0, 0, "0:cache_ruin", Vector3.ONE) and session._data == before, "failed opening rolls back receipt loot and rng")
	check(DirAccess.remove_absolute(target) == OK and session.open_cache(0, 0, "0:cache_ruin", Vector3.ONE), "retry opening once")
	check(session.record_kill(0, 0, "normal", "elite-run-1", Vector3.ZERO, {"elite":true, "district":"0:district_2"}), "real elite receipt")
	var after: Dictionary = session._data.duplicate(true)
	check(after.coins == 19 and after.progression.xp == 12 and after.routes[0].trace == 1 and after.routes[0].drops.size() == 3, "elite doubles XP with one trace and guaranteed item")
	check(not session.record_kill(0, 0, "normal", "elite-run-1", Vector3.ZERO, {"elite":true}) and session._data == after, "duplicate elite cannot duplicate loot")
	check(open_slot("cache"), "reopen received cache")
	check(not session.open_cache(0, 0, "0:cache_grotto", Vector3.ZERO), "cannot open field reward from town")
	check(session.act("claim", {"quest":18}) and not session.act("claim", {"quest":18}), "side reward paid once")
	check(session.act("depart", {"region":0, "difficulty":0}), "revisit same cycle")
	check(session.world_state(0, 0).opened_caches.size() == 2, "opened cache state persists")
	check(not session.open_cache(0, 0, "0:cache_grotto", Vector3.ZERO), "same cycle after reload still spent")
	# 주기 번호만 진행시킨 경계 사례다. 실제 보스 승리 순환은 캠페인 검사에서 확인한다.
	session._data.routes[0].cycle += 1
	check(session.open_cache(0, 0, "0:cache_grotto", Vector3.ZERO) and session.world_state(0, 0).opened_caches.size() == 1, "next boss cycle restocks caches")

func _v2_preservation() -> void:
	if not open_slot("seed"):
		return
	check(session.act("depart", {"region":0, "difficulty":0}), "build predecessor state")
	for i in 6:
		check(session.record_kill(0, 0, "normal", "old-generation-%d" % i, Vector3.ONE), "earn previous XP")
	check(session.act("return", {}), "return predecessor to town")
	var previous: Dictionary = session._data.duplicate(true)
	previous.schema = 2
	previous.erase("cache_cycles")
	previous.claimed.resize(18)
	previous.quest_history.erase("caches")
	var folder: String = temporary.get_current_dir().path_join("legacy2")
	check(DirAccess.make_dir_absolute(folder) == OK, "prepare older two generations")
	var payload := var_to_bytes(previous)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	var raw := "GH01".to_ascii_buffer() + hash.finish() + payload
	for bank in 2:
		var f := FileAccess.open(folder.path_join("slot-v2-%d.sav" % bank), FileAccess.WRITE)
		f.store_buffer(raw)
		f.close()
	check(open_slot("legacy2"), "load schema2")
	check(session._data.schema == 3 and session._data.progression == previous.progression, "schema2 XP points loadout retained")
	check(session._data.routes == previous.routes and session._data.rng == previous.rng and session._data.equipped == previous.equipped, "schema2 items receipts routes RNG unchanged")
	for bank in 2:
		check(FileAccess.get_file_as_bytes(folder.path_join("slot-v2-%d.sav" % bank)) == raw, "prior generation bytes preserved")
	check(session._data.claimed.slice(0,18) == previous.claimed and session._data.claimed.size() == 24, "old claims preserved and new quests appended")
