extends Node

signal changed
signal notice(message: String)

const Loot = preload("res://data/loot_rules.gd")
const Slot = preload("res://scripts/slot_store.gd")
const BAG_SIZE = 30
const CHEST_SIZE = 120
var _data: Dictionary = {}
var _slot: RefCounted
var _last_merge := {}
var _new_merge := {}
var _messages: Array[String] = []
var last_error := ""

func _new_slot() -> Dictionary:
	var routes := []
	for index in 24:
		routes.append({"phase":"hunt", "trace":0, "minis":0, "cycle":1, "rest":0, "cleared":false, "drops":[]})
	var seeds := {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for name_key in ["loot", "merge", "shop"]:
		rng.randi()
		seeds[name_key] = rng.state
	return {"schema":Slot.SCHEMA, "seq":0, "coins":0, "next_id":2, "bag":[], "chest":[],
		"equipped":{"id":1, "order":1, "design":0, "grade":0, "atk":10, "crit":3, "locked":false},
		"auto":true, "first_merge":false, "forest_kills":0, "bonus_stage":0, "routes":routes,
		"claimed":[false,false,false,false,false,false,false], "active_route":-1, "pending_traveler":-1,
		"traveler":{"available":false,"sold":false,"region":-1,"price":18}, "rng":seeds, "normal_receipts":{}}

func start_slot(folder: String = "user://save") -> bool:
	_slot = Slot.new(folder)
	_data = _slot.load_slot()
	_last_merge = {}
	last_error = ""
	if _data.is_empty():
		_data = _new_slot()
		if _slot.unreadable:
			return _fail("LOAD_FAILED")
		return _commit(_begin())
	var restored: bool = _slot.recovered
	if _data.active_route >= 0:
		if not act("return", {}):
			return false
	else:
		changed.emit()
	if restored:
		notice.emit(Loot.caption("RECOVERED"))
	return true

func _begin() -> Dictionary:
	last_error = ""
	_messages = []
	_new_merge = {}
	return _data.duplicate(true)

func _fail(key: String) -> bool:
	last_error = Loot.caption(key)
	notice.emit(last_error)
	return false

func _commit(candidate: Dictionary) -> bool:
	candidate.seq += 1
	if not _slot.commit(candidate):
		return _fail("SAVE_FAILED")
	_data = candidate
	if not _new_merge.is_empty():
		_last_merge = _new_merge
	var committed_messages := _messages.duplicate()
	changed.emit()
	for message in committed_messages:
		notice.emit(message)
	return true

func _route(region: int, difficulty: int) -> int:
	if region < 0 or region >= 6 or difficulty < 0 or difficulty >= 4:
		return -1
	return difficulty * 6 + region

func can_travel(region: int, difficulty: int) -> bool:
	var index := _route(region, difficulty)
	return not _data.is_empty() and index >= 0 and (index == 0 or _data.routes[index - 1].cleared)

func _boss_id(index: int, state: Dictionary) -> String:
	if state.phase != "mini" and state.phase != "boss":
		return ""
	var serial: int = state.minis + 1 if state.phase == "mini" else 1
	return "%d/%d/%s/%d" % [index, state.cycle, state.phase, serial]

func world_state(region: int, difficulty: int) -> Dictionary:
	var index := _route(region, difficulty)
	if index < 0 or _data.is_empty():
		return {"phase":"hunt", "trace":0, "minis":0, "cycle":1, "rest":0, "cleared":false, "drops":[], "spawn_id":""}
	var view: Dictionary = _data.routes[index].duplicate()
	view.spawn_id = _boss_id(index, view)
	var drops := []
	for item in view.drops:
		drops.append(Loot.describe(item))
	view.drops = drops
	return view

func _is_eligible(data: Dictionary, quest: int) -> bool:
	if quest == 0:
		return data.first_merge
	if quest > 0 and quest <= 6 and data.claimed[0]:
		for difficulty in 4:
			if data.routes[difficulty * 6 + quest - 1].cleared:
				return true
	return false

func ui_state() -> Dictionary:
	if _data.is_empty():
		return {}
	var bag := []
	for item in _data.bag:
		bag.append(Loot.describe(item))
	var chest := []
	for item in _data.chest:
		chest.append(Loot.describe(item))
	var cleared := []
	for route in _data.routes:
		cleared.append(route.cleared)
	var quests := []
	for i in 7:
		quests.append({"id":i, "eligible":_is_eligible(_data, i), "claimed":_data.claimed[i], "reward":12 if i == 0 else 20})
	return {"coins":_data.coins, "bag":bag, "chest":chest, "equipped":Loot.describe(_data.equipped),
		"auto":_data.auto, "first_merge":_data.first_merge, "forest_clear":cleared[0], "ending":cleared[23],
		"traveler":_data.traveler.duplicate(), "quests":quests, "cleared":cleared, "last_merge":_last_merge.duplicate(true)}

func _stream(data: Dictionary, channel: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.state = data.rng[channel]
	return rng

func _new_weapon(data: Dictionary, design: int, grade: int, rng: RandomNumberGenerator) -> Dictionary:
	var item := Loot.weapon(data.next_id, design, grade, rng)
	data.next_id += 1
	return item

func _ground_item(data: Dictionary, route: Dictionary, design: int, grade: int, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var item := _new_weapon(data, design, grade, rng)
	item.pos = pos
	route.drops.append(item)

# 일반 몬스터는 원정 식별자와 출현 순번으로 구분한다. 연속된 순번은 범위로
# 보존해 수천 번의 처치 뒤에도 늦게 도착한 이전 원정의 처치 알림을 걸러낸다.
func _accept_normal(data: Dictionary, spawn_id: String) -> bool:
	if data.normal_receipts.has(spawn_id):
		return false
	var split := spawn_id.rfind("-")
	var suffix := spawn_id.substr(split + 1)
	if split < 1 or not suffix.is_valid_int() or str(suffix.to_int()) != suffix or suffix.to_int() < 0:
		data.normal_receipts[spawn_id] = true
		return true
	var number := suffix.to_int()
	var prefix := spawn_id.left(split)
	if not data.has("normal_runs"):
		data.normal_runs = {}
	if not data.normal_runs.has(prefix):
		data.normal_runs[prefix] = []
	var ranges: Array = data.normal_runs[prefix]
	var i := 0
	while i < ranges.size() and int(ranges[i][1]) < number - 1:
		i += 1
	if i == ranges.size():
		ranges.append([number, number])
		return true
	var interval: Array = ranges[i]
	if number >= interval[0] and number <= interval[1]:
		return false
	if number < interval[0] - 1:
		ranges.insert(i, [number, number])
		return true
	interval[0] = mini(interval[0], number)
	interval[1] = maxi(interval[1], number)
	if i + 1 < ranges.size() and ranges[i+1][0] - 1 == interval[1]:
		interval[1] = ranges[i+1][1]
		ranges.remove_at(i+1)
	return true

func record_kill(region: int, difficulty: int, kind: String, spawn_id: String, pos: Vector3) -> bool:
	var index := _route(region, difficulty)
	if _data.is_empty() or index < 0 or index != _data.active_route or spawn_id.is_empty() or not pos.is_finite():
		return false
	var before: Dictionary = _data.routes[index]
	if kind != "normal" and (kind not in ["mini", "boss"] or before.phase != kind or spawn_id != _boss_id(index, before)):
		return false
	var next := _begin()
	var route: Dictionary = next.routes[index]
	var rng := _stream(next, "loot")
	var level := Loot.field_level(region, difficulty)
	var draws := 0
	match kind:
		"normal":
			if not _accept_normal(next, spawn_id):
				return false
			next.coins += 1
			draws = 1 if rng.randf() < 0.22 + 0.0025 * (level - 1) else 0
			if index == 0:
				next.forest_kills += 1
				if next.bonus_stage < 3 and next.forest_kills >= (next.bonus_stage + 1) * 3:
					next.bonus_stage += 1
					_ground_item(next, route, 0, 0, pos, rng)
			if route.phase == "hunt":
				route.trace += 1
				if route.trace == 12:
					route.trace = 0
					route.phase = "mini"
		"mini":
			next.coins += 5
			next.pending_traveler = region
			draws = 1
			level = mini(70, level + 3)
			route.minis += 1
			route.phase = "boss" if route.minis == 2 else "hunt"
		"boss":
			next.coins += 20
			draws = 2
			level = mini(70, level + 6)
			if not route.cleared:
				_messages.append(Loot.caption("ENDING" if index == 23 else "FIRST_CLEAR"))
			route.cleared = true
			route.phase = "rest"
			route.cycle += 1
			route.trace = 0
			route.minis = 0
			route.rest = 30
	for i in draws:
		var design := 0 if rng.randf() < 0.6 else region + 1
		var grade := Loot.draw_grade(level, rng)
		var offset := Vector3(0.35, 0, 0) if i == 1 else Vector3.ZERO
		_ground_item(next, route, design, grade, pos + offset, rng)
	next.rng.loot = rng.state
	return _commit(next)

func tick_rest(region: int, difficulty: int, seconds: int) -> bool:
	var index := _route(region, difficulty)
	if _data.is_empty() or index < 0 or index != _data.active_route or seconds <= 0 or _data.routes[index].phase != "rest":
		return false
	var next := _begin()
	var route: Dictionary = next.routes[index]
	route.rest = maxi(0, route.rest - seconds)
	if route.rest == 0:
		route.phase = "hunt"
	return _commit(next)

func _find(items: Array, id: int) -> int:
	for i in items.size():
		if items[i].id == id:
			return i
	return -1

func _less_valuable(a: Dictionary, b: Dictionary) -> bool:
	if a.atk != b.atk:
		return a.atk < b.atk
	if a.crit != b.crit:
		return a.crit < b.crit
	return a.order < b.order

func _fuse(data: Dictionary, materials: Array) -> void:
	var base: Dictionary = materials[0]
	for item in materials:
		data.bag.erase(item)
	var rng := _stream(data, "merge")
	var result := _new_weapon(data, base.design, base.grade + 1, rng)
	data.rng.merge = rng.state
	data.bag.append(result)
	var view := Loot.describe(result)
	_new_merge = {"item":view, "atk_delta":result.atk - data.equipped.get("atk", 0), "crit_delta":result.crit - data.equipped.get("crit", 0)}
	_messages.append(Loot.caption("MERGED") % [Loot.caption("GRADE_%d" % base.grade), view.grade_name, view.name, view.atk, view.crit])
	if base.design == 0 and not data.first_merge:
		data.first_merge = true
		_messages.append(Loot.caption("UNLOCK_SPIN"))

func _auto_merge(data: Dictionary) -> void:
	if not data.auto:
		return
	# 낮은 등급부터 처리하면 이번 합성 결과가 다음 등급의 후보에 포함된다.
	for grade in 6:
		var groups := {}
		for item in data.bag:
			if not item.locked and item.grade == grade:
				if not groups.has(item.design):
					groups[item.design] = []
				groups[item.design].append(item)
		for group: Array in groups.values():
			group.sort_custom(_less_valuable)
			for start in range(0, group.size() - 2, 3):
				_fuse(data, group.slice(start, start + 3))

func pickup(item_id: int) -> bool:
	return act("pickup", {"id":item_id})

func act(action: String, args: Dictionary = {}) -> bool:
	if _data.is_empty() or not _slot or _slot.unreadable:
		return _fail("LOAD_FAILED")
	var town: bool = _data.active_route < 0
	if not town and action in ["store","withdraw","sell","buy","claim","depart"]:
		return _fail("UNAVAILABLE")
	var next := _begin()
	var id := int(args.get("id", -1))
	var idx := _find(next.bag, id)
	match action:
		"depart":
			var region := int(args.get("region", -1))
			var difficulty := int(args.get("difficulty", -1))
			if not can_travel(region, difficulty):
				return _fail("UNAVAILABLE")
			next.active_route = _route(region, difficulty)
			next.traveler = {"available":false,"sold":false,"region":-1,"price":18}
		"return":
			if town:
				return true
			next.active_route = -1
			if next.pending_traveler >= 0:
				next.traveler = {"available":true,"sold":false,"region":next.pending_traveler,"price":18}
				next.pending_traveler = -1
		"pickup":
			if town:
				return false
			var drops: Array = next.routes[next.active_route].drops
			var drop_index := _find(drops, id)
			if drop_index < 0:
				return false
			var item: Dictionary = drops.pop_at(drop_index)
			item.erase("pos")
			next.bag.append(item)
			var view := Loot.describe(item)
			_messages.append(Loot.caption("PICKED") % [view.grade_name, view.name])
			_auto_merge(next)
		"auto":
			if not args.get("enabled") is bool:
				return false
			next.auto = args.enabled
			_auto_merge(next)
		"merge":
			if next.auto or not _manual_merge(next, args.get("ids", [])):
				return _fail("INVALID_MERGE")
		"equip":
			if idx < 0:
				return false
			var replacement: Dictionary = next.bag.pop_at(idx)
			if not next.equipped.is_empty():
				next.bag.append(next.equipped)
			next.equipped = replacement
			_auto_merge(next)
		"unequip":
			if next.equipped.is_empty() or (args.has("id") and id != next.equipped.id):
				return false
			next.bag.append(next.equipped)
			next.equipped = {}
			_auto_merge(next)
		"lock":
			var item: Dictionary
			if idx >= 0:
				item = next.bag[idx]
			elif id == next.equipped.get("id", -2):
				item = next.equipped
			else:
				var chest_index := _find(next.chest, id)
				if chest_index < 0:
					return false
				item = next.chest[chest_index]
			item.locked = not item.locked
			if idx >= 0 and not item.locked:
				_auto_merge(next)
		"store":
			if idx < 0:
				return false
			if next.chest.size() >= CHEST_SIZE:
				return _fail("CHEST_FULL")
			next.chest.append(next.bag.pop_at(idx))
		"withdraw":
			var chest_index := _find(next.chest, id)
			if chest_index < 0:
				return false
			next.bag.append(next.chest.pop_at(chest_index))
			_auto_merge(next)
		"sell":
			if idx < 0 or next.bag[idx].locked:
				return _fail("PROTECTED")
			var item: Dictionary = next.bag.pop_at(idx)
			next.coins += 2 * (item.grade + 1)
		"buy":
			if not _buy(next, str(args.get("vendor", ""))):
				return false
		"claim":
			var quest := int(args.get("quest", -1))
			if quest < 0 or quest > 6 or next.claimed[quest] or not _is_eligible(next, quest):
				return _fail("UNAVAILABLE")
			next.claimed[quest] = true
			next.coins += 12 if quest == 0 else 20
		_:
			return false
	if next.bag.size() > BAG_SIZE:
		return _fail("BAG_FULL")
	return _commit(next)

func _manual_merge(data: Dictionary, ids: Array) -> bool:
	if ids.size() != 3:
		return false
	var materials := []
	for id in ids:
		var idx := _find(data.bag, id)
		if idx < 0:
			return false
		var item: Dictionary = data.bag[idx]
		if item.locked or item.grade == 6 or item in materials:
			return false
		if not materials.is_empty() and (item.design != materials[0].design or item.grade != materials[0].grade):
			return false
		materials.append(item)
	_fuse(data, materials)
	return true

func _buy(data: Dictionary, vendor: String) -> bool:
	if vendor not in ["shop","traveler"]:
		return _fail("UNAVAILABLE")
	var traveling := vendor == "traveler"
	if traveling and not data.traveler.available:
		return _fail("UNAVAILABLE")
	if traveling and data.traveler.sold:
		return _fail("SOLD_OUT")
	var price := 18 if traveling else 8
	if data.coins < price:
		return _fail("LOW_COINS")
	var rng := _stream(data, "shop")
	var design: int = data.traveler.region + 1 if traveling else 0
	data.bag.append(_new_weapon(data, design, 1 if traveling else 0, rng))
	data.rng.shop = rng.state
	data.coins -= price
	if traveling:
		data.traveler.sold = true
	_auto_merge(data)
	return true
