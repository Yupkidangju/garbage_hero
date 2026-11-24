extends SceneTree

const Session = preload("res://scripts/session.gd")
const Loot = preload("res://data/loot_rules.gd")
const ARCHIVE_SHA256 := "b17a615fda6112f0ccfec96c375ef7b98f36f0e09e3f90bc2b02a345d4f59b9e"

var checks := 0
var failures := 0
var temp: DirAccess
var session: Node


func _initialize() -> void:
	temp = DirAccess.create_temp("garbagehero-expansion-slot")
	if check(temp != null, "isolated test directory"):
		_migration_and_play()
		_archived_campaign()
	if is_instance_valid(session):
		session.free()
	print("Expansion session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	return condition


func new_session() -> void:
	if is_instance_valid(session):
		session.free()
	session = Session.new()


func sha256(bytes: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish()


# 0.1.0의 고정 헤더·SHA-256·Variant 바이트를 현재 슬롯 구현과 독립적으로 읽고 쓴다.
func legacy_bytes(data: Dictionary) -> PackedByteArray:
	var payload := var_to_bytes(data)
	return "GH01".to_ascii_buffer() + sha256(payload) + payload


func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() <= 36 or bytes.slice(0, 4) != "GH01".to_ascii_buffer():
		return {}
	var payload := bytes.slice(36)
	if bytes.slice(4, 36) != sha256(payload):
		return {}
	var decoded: Variant = bytes_to_var(payload)
	return decoded if decoded is Dictionary else {}


func write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "open fixture " + path.get_file()):
		return false
	file.store_buffer(bytes)
	file.close()
	return check(FileAccess.get_file_as_bytes(path) == bytes, "fixture bytes " + path.get_file())


func banks(folder: String, schema: int) -> Array:
	var stem := "slot-%d.sav" if schema == 1 else "slot-v3-%d.sav"
	var result := []
	for i in 2:
		var path := folder.path_join(stem % i)
		result.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
	return result


func old_sword(id: int, design: int, grade: int, atk: int, crit: int, locked: bool) -> Dictionary:
	return {"id":id, "order":id, "design":design, "grade":grade, "atk":atk, "crit":crit, "locked":locked}


func old_town() -> Dictionary:
	var routes := []
	for i in 24:
		routes.append({"phase":"hunt", "trace":0, "minis":0, "cycle":1, "rest":0, "cleared":false, "drops":[]})
	var drop := old_sword(31, 1, 1, 14, 5, false)
	drop.pos = Vector3(-18.5, 0.75, 11.25)
	routes[0].drops = [drop]
	routes[0].cleared = true
	routes[0].cycle = 2
	routes[1].trace = 7
	return {"schema":1, "seq":42, "coins":77, "next_id":35, "active_route":-1, "first_merge":true,
		"equipped":old_sword(8, 2, 2, 19, 7, true), "bag":[old_sword(14, 0, 0, 10, 2, false)],
		"chest":[old_sword(23, 1, 1, 14, 7, true)], "auto":false, "forest_kills":36, "bonus_stage":3,
		"routes":routes, "claimed":[true, true, false, false, false, false, false],
		"traveler":{"available":true,"sold":true,"region":0,"price":18}, "pending_traveler":-1,
		"rng":{"loot":101, "merge":222, "shop":439}, "normal_receipts":{"archived-spawn":true},
		"normal_runs":{"old-forest":[[1, 24]]}}


func verify_migrated(old: Dictionary) -> void:
	var live: Dictionary = session._data
	check(live.schema == 3 and live.seq == old.seq + 1, "exactly one migration commit")
	for key in ["coins", "next_id", "equipped", "bag", "chest", "auto", "first_merge", "forest_kills",
			"bonus_stage", "routes", "rng", "normal_receipts"]:
		check(live[key] == old[key], "preserve legacy " + key)
	check(live.get("normal_runs", {}) == old.get("normal_runs", {}), "preserve compressed historical kill receipts")
	check(live.claimed.slice(0, old.claimed.size()) == old.claimed, "previous quest payouts retained")
	var view: Dictionary = session.ui_state()
	check(view.progression.level == 1 and view.progression.xp == 0 and view.progression.skill_points == 0, "old slot starts new XP ledger")
	check(view.progression.loadout == ["hook", "spin" if old.first_merge else "", "slam" if old.routes[0].cleared else ""], "legacy milestones bind to earned slots")
	check(live.active_route == -1, "migration resumes in town")
	var expected_traveler: Dictionary = old.traveler
	var pending: int = old.pending_traveler
	if old.active_route >= 0 and pending >= 0:
		expected_traveler = {"available":true, "sold":false, "region":pending, "price":18, "visit":old.routes[int(old.active_route / 6) * 6 + pending].cycle}
		pending = -1
	check(live.traveler == expected_traveler and live.pending_traveler == pending, "preserve traveler contract on return")


func _migration_and_play() -> void:
	var folder := temp.get_current_dir().path_join("crafted")
	if not check(DirAccess.make_dir_absolute(folder) == OK, "created crafted slot"):
		return
	var newest := old_town()
	var older := newest.duplicate(true)
	older.seq -= 1
	older.coins -= 3
	older.bag.clear()
	if not write_bytes(folder.path_join("slot-0.sav"), legacy_bytes(newest)):
		return
	if not write_bytes(folder.path_join("slot-1.sav"), legacy_bytes(older)):
		return
	var originals := banks(folder, 1)
	var obstacle := folder.path_join("slot-v3-0.sav.tmp")
	if not check(DirAccess.make_dir_absolute(obstacle) == OK, "block first v2 migration write"):
		return
	new_session()
	check(not session.start_slot(folder) and session.last_error == Loot.caption("SAVE_FAILED"), "migration surfaces actual write failure")
	check(banks(folder, 1) == originals and banks(folder, 3) == [PackedByteArray(), PackedByteArray()], "failed migration leaves both old files intact and no new bank")
	if not check(DirAccess.remove_absolute(obstacle) == OK and session.start_slot(folder), "same session retries migration from disk"):
		return
	verify_migrated(newest)
	check(decode(banks(folder, 3)[0]) == session._data, "new canonical v2 bank matches committed state")
	var state: Dictionary = session.ui_state()
	check(state.equipped.id == 8 and state.equipment.weapon.id == 8 and state.equipped.locked and state.stats.atk == 19, "old equipped sword activates actual slot and attack")
	check(state.bag[0].id == 14 and state.chest[0].id == 23 and state.chest[0].locked, "bag and chest retain distinct identities and locks")
	var field: Dictionary = session.world_state(0, 0)
	check(field.drops[0].id == 31 and field.drops[0].pos == newest.routes[0].drops[0].pos and field.cycle == 2, "old floor item identity and position reach field API")
	check(session.can_travel(1, 0) and not session.can_travel(2, 0), "old route clear is playable after migration")
	_kills_and_spending(folder)
	_recovery_after_migration(folder)
	check(banks(folder, 1) == originals, "both old bank byte streams survive subsequent new play")


func _kills_and_spending(folder: String) -> void:
	if not check(session.act("depart", {"region":0, "difficulty":0}), "depart migrated town"):
		return
	var start: Dictionary = session._data.duplicate(true)
	for id in ["old-forest-8", "archived-spawn"]:
		check(not session.record_kill(0, 0, "normal", id, Vector3.ZERO) and session._data == start, "old receipt rejects " + id)
	for i in 4:
		if not check(session.record_kill(0, 0, "normal", "after-migration-%d" % i, Vector3.ZERO), "new kill %d" % i):
			return
	var before: Dictionary = session._data.duplicate(true)
	var committed := banks(folder, 3)
	var messages: Array[String] = []
	session.notice.connect(func(msg: String): messages.append(msg))
	var obstacle := folder.path_join("slot-v3-%d.sav.tmp" % (1 - session._slot.active_bank))
	if not check(DirAccess.make_dir_absolute(obstacle) == OK, "block level-up kill's next save bank"):
		return
	const FIFTH := "after-migration-4"
	check(not session.record_kill(0, 0, "normal", FIFTH, Vector3.ZERO), "write failure rejects level-up kill")
	check(before.progression.xp == 24 and before.progression.level == 1 and session._data == before and banks(folder, 3) == committed, "failed kill preserves XP, points, coin, RNG, drops, receipt and both disk banks")
	check(messages == [Loot.caption("SAVE_FAILED")], "failed kill emits only the save error")
	messages.clear()
	if not check(DirAccess.remove_absolute(obstacle) == OK and session.record_kill(0, 0, "normal", FIFTH, Vector3.ZERO), "retry commits formerly failed kill"):
		return
	var p: Dictionary = session.ui_state().progression
	check(p.level == 2 and p.xp == 0 and p.stat_points == 3 and p.skill_points == 1, "one XP threshold awards one set of points")
	check(messages.size() == 1 and messages[0].contains("레벨 2") and session._data.coins == before.coins + 1, "one committed level notification and coin")
	var once: Dictionary = session._data.duplicate(true)
	check(not session.record_kill(0, 0, "normal", FIFTH, Vector3.ONE) and session._data == once and messages.size() == 1, "duplicate committed kill grants nothing")
	new_session()
	if not check(session.start_slot(folder) and session._data.active_route == -1 and session.ui_state().progression == p, "XP and points survive actual reopen from field"):
		return
	if not check(session.act("depart", {"region":0, "difficulty":0}), "reenter after restarting"):
		return
	var reopened: Dictionary = session._data.duplicate(true)
	check(not session.record_kill(0, 0, "normal", FIFTH, Vector3.ZERO) and session._data == reopened, "duplicate still rejected after process state reconstruction")
	if not check(session.act("return"), "return to purchase expansion gear"):
		return
	if not check(session.act("buy", {"vendor":"shop", "design":11}), "purchase armor with migrated wallet"):
		return
	var armor: Dictionary = session.ui_state().bag.back()
	check(armor.slot == "armor" and armor.id >= 35, "new armor has fresh unique ID")
	var unspent: Dictionary = session._data.duplicate(true)
	obstacle = folder.path_join("slot-v3-%d.sav.tmp" % (1 - session._slot.active_bank))
	if not check(DirAccess.make_dir_absolute(obstacle) == OK, "block management transaction bank"):
		return
	for request in [["allocate_stat", {"stat":"strength"}], ["learn_skill", {"skill":"volley"}], ["equip", {"id":armor.id}]]:
		check(not session.act(request[0], request[1]) and session._data == unspent and session.last_error == Loot.caption("SAVE_FAILED"), "write failure preserves " + request[0])
	if not check(DirAccess.remove_absolute(obstacle) == OK, "restore management save path"):
		return
	for stat in ["strength", "vitality", "agility"]:
		check(session.act("allocate_stat", {"stat":stat}), "spend " + stat)
	check(session.act("learn_skill", {"skill":"volley"}) and session.act("equip_skill", {"slot":0, "skill":"volley"}), "learn and bind new skill")
	check(session.act("equip", {"id":armor.id}), "equip armor after write recovery")
	var played: Dictionary = session.ui_state()
	check(played.progression.loadout == ["volley","spin","slam"] and played.progression.ranks.volley == 1 and played.progression.stat_points == 0 and played.progression.skill_points == 0, "custom bar and spent point pools")
	check(played.equipment.armor.id == armor.id and played.stats.max_hp == 110 + armor.max_hp and played.stats.atk == 21 and played.stats.crit == 8, "combined legacy sword, armor and allocated stats reach play state")
	new_session()
	if check(session.start_slot(folder), "reopen newest town bank"):
		var restored: Dictionary = session.ui_state()
		for key in ["coins", "bag", "chest", "progression", "equipment", "stats"]:
			check(restored[key] == played[key], "persisted management state: " + key)


func _recovery_after_migration(folder: String) -> void:
	var saved: Dictionary = session._data.duplicate(true)
	if not check(session.act("auto", {"enabled":not saved.auto}), "create distinguishable newest v2 bank"):
		return
	var active: int = session._slot.active_bank
	var files := banks(folder, 3)
	var path := folder.path_join("slot-v3-%d.sav" % active)
	var damaged: PackedByteArray = files[active].duplicate()
	damaged[-1] = damaged[-1] ^ 0xff
	if not write_bytes(path, damaged):
		return
	new_session()
	if not check(session.start_slot(folder) and session._data == saved, "recover previous paid v2 state in presence of intact original v1 banks"):
		return
	path = folder.path_join("slot-v3-%d.sav" % (1 - active))
	if not write_bytes(path, "interrupted".to_ascii_buffer()):
		return
	var damaged_banks := banks(folder, 3)
	new_session()
	check(not session.start_slot(folder) and session.last_error == Loot.caption("LOAD_FAILED"), "two damaged v2 banks do not resurrect obsolete v1 progression")
	check(not session.act("auto", {"enabled":true}) and banks(folder, 3) == damaged_banks, "unreadable v2 banks remain available for recovery")


func _archived_campaign() -> void:
	var archive := ProjectSettings.globalize_path("res://").path_join("../tasks/evidence/campaign-20261118.zip").simplify_path()
	if not FileAccess.file_exists(archive):
		print("Historical campaign ZIP absent; generated schema-1 fixture ran independently.")
		return
	if not check(FileAccess.get_sha256(archive) == ARCHIVE_SHA256, "historical archive matches published SHA-256"):
		return
	var zip := ZIPReader.new()
	if not check(zip.open(archive) == OK, "open historical archive read-only"):
		return
	var folder := temp.get_current_dir().path_join("archived")
	if not check(DirAccess.make_dir_absolute(folder) == OK, "created archived replay slot"):
		return
	var latest := {}
	var originals := []
	for i in 2:
		var name := "slot-%d.sav" % i
		var raw := zip.read_file("save/" + name)
		var data := decode(raw)
		if not check(data.get("schema") == 1 and write_bytes(folder.path_join(name), raw), "historical schema-1 bank %d" % i):
			return
		originals.append(raw)
		if latest.is_empty() or data.seq > latest.seq:
			latest = data
	zip.close()
	new_session()
	if not check(session.start_slot(folder), "migrate archived in-game save"):
		return
	verify_migrated(latest)
	var cleared := 0
	for route in latest.routes:
		cleared += int(route.cleared)
	check(cleared == 9 and latest.equipped.atk == 45, "historical campaign checkpoint imported")
	check(session.can_travel(3, 1) and not session.can_travel(4, 1), "archived 10th destination remains available")
	check(banks(folder, 1) == originals and FileAccess.get_sha256(archive) == ARCHIVE_SHA256, "historical archive and copied legacy banks preserved")
	print("Historical campaign migrated from seq %s, %d cleared routes, weapon attack %s." % [latest.seq, cleared, latest.equipped.atk])
