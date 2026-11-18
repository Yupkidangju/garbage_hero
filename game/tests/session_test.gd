extends SceneTree

const Session = preload("res://scripts/session.gd")
const Loot = preload("res://data/loot_rules.gd")
var failures := 0
var assertions := 0
var serial := 0
var temp: DirAccess
var session: Node

func _initialize() -> void:
	temp = DirAccess.create_temp("garbagehero-session")
	if temp == null:
		push_error("Could not create isolated test directory")
		quit(1)
		return
	_distribution()
	_campaign()
	_inventory()
	_recovery()
	if session:
		session.free()
	print("Session tests: %d checks, %d failures." % [assertions, failures])
	quit(1 if failures else 0)

func check(value: bool, label: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error(label)
	return value

func _start(folder: String) -> bool:
	if is_instance_valid(session):
		session.free()
	session = Session.new()
	return check(session.start_slot(temp.get_current_dir().path_join(folder)), "open " + folder)

func _distribution() -> void:
	var previous_mean := 0.0
	for level in range(1, 71):
		var weight_sum := 0.0
		for value in Loot.weights(level):
			weight_sum += value
		check(is_equal_approx(weight_sum, 100), "weights at %d" % level)
	for grade in 7:
		var lo: int = Loot.ATTACK_MIN[grade]
		var hi: int = Loot.ATTACK_MAX[grade]
		var count := hi - lo + 1
		var max_mean := 0.0
		for first in range(lo, hi + 1):
			for second in range(lo, hi + 1):
				max_mean += maxi(first, second) / float(count * count)
		var mean := lerpf((lo + hi) / 2.0, max_mean, Loot.REROLL[grade])
		check(mean > previous_mean and (grade == 0 or lo <= Loot.ATTACK_MAX[grade - 1]), "mean/overlap %d" % grade)
		previous_mean = mean
	check(Loot.field_level(5, 3) == 70, "maximum level")
	var tester := Session.new()
	var history := {"normal_receipts":{}}
	for id in [4,2,7,8,6,1,3,5]:
		check(tester._accept_normal(history, "out-of-order-%d" % id), "accept separate spawn %d" % id)
	check(history.normal_runs["out-of-order"] == [[1,8]] and not tester._accept_normal(history, "out-of-order-3"), "compact ordered receipts retain duplicate detection")
	tester.free()

func _normal(region: int, difficulty: int) -> bool:
	serial += 1
	return check(session.record_kill(region, difficulty, "normal", "rat-%d" % serial, Vector3.ONE), "normal %d" % serial)

func _boss(region: int, difficulty: int, kind: String) -> bool:
	var world: Dictionary = session.world_state(region, difficulty)
	if not check(world.phase == kind and not world.spawn_id.is_empty(), "expected phase " + kind):
		return false
	var count: int = world.drops.size()
	if not check(session.record_kill(region, difficulty, kind, world.spawn_id, Vector3.ZERO), "kill " + kind):
		return false
	check(not session.record_kill(region, difficulty, kind, world.spawn_id, Vector3.ZERO), "duplicate " + kind)
	var after: Dictionary = session.world_state(region, difficulty)
	check(after.drops.size() == count + (2 if kind == "boss" else 1), "guaranteed drops " + kind)
	return true

func _campaign() -> void:
	if not _start("campaign"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 72431
	for channel in ["loot", "merge", "shop"]:
		rng.randi()
		session._data.rng[channel] = rng.state
	var initial: Dictionary = session.ui_state()
	check(initial.coins == 0 and initial.bag.is_empty() and initial.auto and initial.equipped.atk == 10, "starting equipment")
	check(not session.can_travel(1, 0) and not session.act("depart", {"region":1, "difficulty":0}), "locked route")
	for index in 24:
		var region := index % 6
		@warning_ignore("integer_division")
		var difficulty := index / 6
		if not check(session.act("depart", {"region":region, "difficulty":difficulty}), "depart %d" % index):
			return
		for mini in 2:
			for n in 12:
				if not _normal(region, difficulty):
					return
				if index == 0 and mini == 0 and n == 8:
					var seen := {}
					for drop in session.world_state(0, 0).drops:
						check(not seen.has(drop.id), "unique ground item ID")
						seen[drop.id] = true
						check(session.pickup(drop.id), "ground pickup")
					check(session.ui_state().first_merge, "guaranteed first common merge")
				if index == 0 and mini == 0 and n == 10:
					var prior_spawn := "rat-%d" % serial
					check(session.world_state(0, 0).trace == 11, "trace before return")
					if not _start("campaign"):
						return
					check(session.act("depart", {"region":0,"difficulty":0}) and session.world_state(0, 0).trace == 11, "11 traces after restart")
					check(not session.record_kill(0, 0, "normal", prior_spawn, Vector3.ZERO), "late duplicate from previous expedition")
			if index == 0 and mini == 0:
				var token: String = session.world_state(0, 0).spawn_id
				if not _start("campaign"):
					return
				check(session.act("depart", {"region":0,"difficulty":0}) and token == session.world_state(0, 0).spawn_id, "boss survives restart with same identity")
			if not _boss(region, difficulty, "mini"):
				return
		if not _boss(region, difficulty, "boss"):
			return
		check(session.world_state(region, difficulty).rest == 30, "rest entered")
		check(session.tick_rest(region, difficulty, 8) and session.world_state(region, difficulty).rest == 22, "rest consumed")
		check(session.act("return"), "return")
		check(not session.tick_rest(region, difficulty, 22), "rest frozen in town")
		if index == 0:
			var town: Dictionary = session.ui_state()
			check(town.forest_clear and town.traveler.available and town.traveler.region == 0, "first clear and traveler")
			check(session.act("claim", {"quest":0}) and session.act("claim", {"quest":1}), "retroactive claims")
			check(not session.act("claim", {"quest":1}), "one claim only")
			check(session.act("buy", {"vendor":"traveler"}) and not session.act("buy", {"vendor":"traveler"}), "one traveler purchase")
			var bought: Dictionary = session.ui_state().bag.back()
			check(bought.design == 1 and bought.grade == 1, "traveler blueprint")
			check(session.act("store", {"id":bought.id}) and session.ui_state().chest[0] == bought, "chest identity")
			check(session.act("withdraw", {"id":bought.id}), "withdraw")
	check(session.ui_state().ending and session.ui_state().cleared.count(true) == 24, "24 cleared + ending")
	if not _start("campaign"):
		return
	check(session.ui_state().ending, "saved ending")
	check(session.act("depart", {"region":5,"difficulty":3}) and session.tick_rest(5, 3, 22), "revisit after ending")
	for mini in 2:
		for n in 12:
			if not _normal(5, 3):
				return
		if not _boss(5, 3, "mini"):
			return
	if _boss(5, 3, "boss"):
		check(session.world_state(5, 3).cycle == 3, "second complete cycle")

# 경계 사례의 시작 상태만 구성하고 실제 거래 진입점에서 결과를 검증한다.
func _add(design: int, grade: int, locked: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = session._data.next_id
	var item: Dictionary = session._new_weapon(session._data, design, grade, rng)
	item.locked = locked
	session._data.bag.append(item)
	return item

func _inventory() -> void:
	if not _start("inventory"):
		return
	check(session.act("auto", {"enabled":false}), "manual mode")
	var a := _add(0, 0)
	var b := _add(0, 0)
	var c := _add(0, 0, true)
	var other := _add(1, 0)
	check(not session.act("merge", {"ids":[a.id,b.id,c.id]}), "protected material")
	check(not session.act("merge", {"ids":[a.id,a.id,b.id]}), "duplicate material")
	check(not session.act("merge", {"ids":[a.id,b.id,other.id]}), "different blueprints")
	check(not session.act("merge", {"ids":[a.id,b.id,1]}), "equipped item excluded")
	check(session.act("lock", {"id":c.id}) and session.act("merge", {"ids":[a.id,b.id,c.id]}), "manual merge")
	var bag: Array = session.ui_state().bag
	check(bag.size() == 2 and bag[1].grade == 1 and session.ui_state().last_merge.item.id == bag[1].id, "manual result preview")
	var gear: Dictionary = bag[1]
	check(session.act("equip", {"id":gear.id}) and session.ui_state().equipped == gear, "equip")
	check(not session.act("sell", {"id":gear.id}) and session.act("unequip", {"id":gear.id}), "equipped sale and unequip")
	check(session.act("sell", {"id":gear.id}) and session.ui_state().coins == 4, "sale amount")
	session._data.bag.clear()
	for i in 9:
		_add(0, 0)
	check(session.act("auto", {"enabled":true}) and session.ui_state().bag.size() == 1 and session.ui_state().bag[0].grade == 2, "nine-to-one chain")
	session._data.bag.clear()
	for i in 729:
		_add(0, 0)
	check(session.act("auto", {"enabled":true}) and session.ui_state().bag.size() == 1 and session.ui_state().bag[0].grade == 6, "729 common materials to mythic")
	session._data.bag.clear()
	for i in 4:
		var item := _add(0, 0)
		item.atk = 10
		item.crit = 3
	var strongest_id: int = session._data.bag[2].id
	session._data.bag[2].crit = 4
	check(session.act("auto", {"enabled":true}) and session.ui_state().bag[0].id == strongest_id, "keep higher crit when attacks tie")
	session._data.bag.clear()
	for i in 28:
		_add(0, 6)
	_add(0, 0)
	_add(0, 0)
	session._data.coins = 100
	check(session.act("buy", {"vendor":"shop"}) and session.ui_state().bag.size() == 29, "full bag accepts purchase resulting in merge")
	check(session.ui_state().bag[27].grade == 6, "highest grade remains protected from merging")
	check(session.act("buy", {"vendor":"shop"}), "last available slot")
	var before: Dictionary = session._data.duplicate(true)
	check(not session.act("buy", {"vendor":"shop"}) and session._data == before, "rejected purchase retains RNG, IDs, balance and all items")
	check(session.act("depart", {"region":0,"difficulty":0}), "travel with full bag")
	var rng := RandomNumberGenerator.new()
	session._ground_item(session._data, session._data.routes[0], 6, 0, Vector3(3, 0, 7), rng)
	var ground: Dictionary = session.world_state(0, 0).drops[0]
	check(not session.pickup(ground.id), "full bag leaves ground item")
	check(session.act("return") and session.act("depart", {"region":0, "difficulty":0}), "ground revisit")
	check(session.world_state(0, 0).drops[0] == ground, "persistent dropped stats and position")
	check(session.act("return") and session.act("auto", {"enabled":false}), "manual mode in town")
	var chest_item := _add(6, 0)
	session._data.chest.append(session._data.bag.pop_back())
	before = session._data.duplicate(true)
	check(not session.act("withdraw", {"id":chest_item.id}) and session._data == before, "full manual bag preserves chest item and balance")
	for i in 119:
		_add(6, 1)
		session._data.chest.append(session._data.bag.pop_back())
	before = session._data.duplicate(true)
	check(not session.act("store", {"id":session._data.bag[0].id}) and session._data == before, "full chest retains bag item")

func _recovery() -> void:
	if not _start("recovery"):
		return
	var folder := temp.get_current_dir().path_join("recovery")
	# 한쪽 세대를 보존한 채 임시 파일과 같은 이름의 폴더를 만들어 쓰기 실패를 재현한다.
	var target := folder.path_join("slot-1.sav.tmp")
	check(DirAccess.make_dir_absolute(target) == OK, "inject save failure")
	var before: Dictionary = session._data.duplicate(true)
	check(not session.act("depart", {"region":0, "difficulty":0}) and session._data == before, "failed save is rolled back")
	DirAccess.remove_absolute(target)
	check(session.act("depart", {"region":0, "difficulty":0}), "retry after failed save")
	check(session.record_kill(0, 0, "normal", "n", Vector3.ZERO), "record")
	check(not session.record_kill(0, 0, "normal", "n", Vector3.ZERO), "duplicate normal")
	check(session.record_kill(0, 0, "normal", "n2", Vector3.ZERO), "second record")
	var latest := folder.path_join("slot-%d.sav" % session._slot.active_bank)
	var bad := FileAccess.open(latest, FileAccess.WRITE)
	bad.store_string("truncated by test")
	bad.close()
	if _start("recovery"):
		check(session.ui_state().coins == 1, "previous intact bank recovered after corruption")
	var active := folder.path_join("slot-%d.sav" % session._slot.active_bank)
	var inactive := folder.path_join("slot-%d.sav" % (1 - session._slot.active_bank))
	for path in [active, inactive]:
		var damaged := FileAccess.open(path, FileAccess.WRITE)
		damaged.store_string("damaged")
		damaged.close()
	session.free()
	session = Session.new()
	check(not session.start_slot(folder), "two damaged banks block overwriting")
	check(not session.act("depart", {"region":0,"difficulty":0}), "blocked state rejects writes")
	check(FileAccess.get_file_as_string(active) == "damaged" and FileAccess.get_file_as_string(inactive) == "damaged", "preserve originals for recovery")
