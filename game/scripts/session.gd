extends Node

signal changed
signal notice(message: String)

const Loot = preload("res://data/loot_rules.gd")
const Slot = preload("res://scripts/slot_store.gd")
const Growth = preload("res://data/progression.gd")
const Equipment = preload("res://scripts/equipment.gd")
const Quests = preload("res://data/quest_book.gd")
const MAP_TEXT: Translation = preload("res://data/map_ko.tres")
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
	var data := {"schema":Slot.SCHEMA, "seq":0, "coins":0, "next_id":2, "bag":[], "chest":[],
		"progression":Growth.fresh(), "gear_slots":{}, "cache_cycles":{},
		"equipped":{"id":1, "order":1, "design":0, "grade":0, "atk":10, "crit":3, "locked":false},
		"auto":true, "first_merge":false, "forest_kills":0, "bonus_stage":0, "routes":routes,
		"claimed":[false,false,false,false,false,false,false], "active_route":-1, "pending_traveler":-1,
		"traveler":{"available":false,"sold":false,"region":-1,"price":18}, "rng":seeds, "normal_receipts":{}}
	Quests.initialize(data)
	return data

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
	var migrated: bool = _data.schema < Slot.SCHEMA
	if _data.schema == 1:
		_data.progression = Growth.from_legacy(_data.first_merge, _data.routes[0].cleared)
		_data.gear_slots = {}
	if migrated:
		Quests.initialize(_data)
		_data.cache_cycles = {}
		_data.schema = Slot.SCHEMA
	if _data.active_route >= 0:
		if not act("return", {}):
			return false
	elif migrated:
		if not _commit(_begin()):
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
	return _refuse(Loot.caption(key))

func _refuse(reason: String) -> bool:
	last_error = reason
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
	view.opened_caches = []
	for id in _data.cache_cycles.get(str(index), {}):
		if _data.cache_cycles[str(index)][id] == view.cycle:
			view.opened_caches.append(id)
	return view

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
	var equipment: Dictionary = Equipment.slots(_data)
	return {"coins":_data.coins, "bag":bag, "chest":chest, "equipped":Loot.describe(_data.equipped),
		"equipment":equipment, "progression":Growth.describe(_data.progression),
		"stats":Growth.stats(_data.progression, Equipment.bonuses(_data)),
		"offers":{"shop":Equipment.offers("shop", _data.traveler, _data), "traveler":Equipment.offers("traveler", _data.traveler, _data)},
		"auto":_data.auto, "first_merge":_data.first_merge, "forest_clear":cleared[0], "ending":cleared[23],
		"traveler":_data.traveler.duplicate(true), "quests":Quests.views(_data), "cleared":cleared, "last_merge":_last_merge.duplicate(true)}

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

func record_kill(region: int, difficulty: int, kind: String, spawn_id: String, pos: Vector3, context: Dictionary = {}) -> bool:
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
	var elite := kind == "normal" and is_same(context.get("elite", false), true)
	match kind:
		"normal":
			if not _accept_normal(next, spawn_id):
				return false
			next.coins += 3 if elite else 1
			draws = 1 if elite or rng.randf() < 0.22 + 0.0025 * (level - 1) else 0
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
				if index == 0:
					Growth.grant_legacy(next.progression, "slam")
			route.cleared = true
			route.phase = "rest"
			route.cycle += 1
			route.trace = 0
			route.minis = 0
			route.rest = 30
	var levels: int = Growth.gain(next.progression, Loot.field_level(region, difficulty), kind)
	if elite:
		levels += Growth.gain(next.progression, Loot.field_level(region, difficulty), kind)
	if levels > 0:
		_messages.append(Growth.level_notice(next.progression, levels))
	for i in draws:
		var design: int = Loot.draw_design(region, rng, str(context.get("district", "")))
		var grade := Loot.draw_grade(level, rng)
		var offset := Vector3(0.35, 0, 0) if i == 1 else Vector3.ZERO
		_ground_item(next, route, design, grade, pos + offset, rng)
	next.rng.loot = rng.state
	return _commit(next)

func open_cache(region: int, difficulty: int, key: String, pos: Vector3) -> bool:
	var index := _route(region, difficulty)
	if index < 0 or _data.get("active_route", -1) != index or not Quests.FieldLayout.valid_cache(region, key) or not pos.is_finite() or _slot.unreadable:
		return false
	var route: Dictionary = _data.routes[index]
	if _data.cache_cycles.get(str(index), {}).get(key, 0) == route.cycle:
		return _fail("CACHE_EMPTY")
	var next := _begin()
	if not next.cache_cycles.has(str(index)):
		next.cache_cycles[str(index)] = {}
	next.cache_cycles[str(index)][key] = route.cycle
	next.quest_history.caches[key] = true
	next.coins += 8 + difficulty * 4
	var rng := _stream(next, "loot")
	var layout := Quests.FieldLayout.new(region)
	var district := ""
	for cache: Dictionary in layout.caches:
		if cache.id == key:
			district = layout.district_at(cache.pos)
			break
	var design: int = Loot.draw_design(region, rng, district)
	var grade := Loot.draw_grade(mini(70, Loot.field_level(region, difficulty) + 6), rng)
	_ground_item(next, next.routes[index], design, grade, pos, rng)
	next.rng.loot = rng.state
	_messages.append(Loot.caption("CACHE_OPEN"))
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

func _fuse(data: Dictionary, materials: Array) -> void:
	var base: Dictionary = materials[0]
	for item in materials:
		data.bag.erase(item)
	var rng := _stream(data, "merge")
	var result := _new_weapon(data, base.design, base.grade + 1, rng)
	data.rng.merge = rng.state
	data.bag.append(result)
	var view := Loot.describe(result)
	var equipment: Dictionary = Equipment.slots(data)
	var worn: Dictionary = equipment[view.slot]
	_new_merge = {"item":view, "atk_delta":result.atk - worn.get("atk", 0), "crit_delta":result.crit - worn.get("crit", 0),
		"comparison":Equipment.compare_text(view, equipment)}
	_messages.append(Loot.caption("MERGED_ITEM") % [Loot.caption("GRADE_%d" % base.grade), view.grade_name, view.name, view.stat_text])
	if base.design == 0 and not data.first_merge:
		data.first_merge = true
		if data.progression.ranks.get("spin", 0) == 0:
			Growth.grant_legacy(data.progression, "spin")
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
			group.sort_custom(Loot.less_valuable)
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
				var visit_route: int = _route(next.pending_traveler, int(_data.active_route / 6))
				next.traveler = {"available":true,"sold":false,"region":next.pending_traveler,"price":18, "visit":next.routes[visit_route].cycle}
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
			var item: Dictionary = next.bag[idx]
			var error: String = Equipment.equip(next, item)
			if not error.is_empty():
				return _fail(error)
			var view := Loot.describe(item)
			Quests.record_equip(next, view.slot, view.weapon_type)
			_auto_merge(next)
		"unequip":
			var error: String = Equipment.unequip(next, id)
			if not error.is_empty():
				return _fail(error)
			_auto_merge(next)
		"lock":
			var item: Dictionary
			if idx >= 0:
				item = next.bag[idx]
			else:
				item = Equipment.equipped_item(next, id)
				if item.is_empty():
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
			if args.has("design") and not args.design is int:
				return _fail("UNAVAILABLE")
			var error: String = Equipment.buy(next, str(args.get("vendor", "")), int(args.get("design", -1)))
			if not error.is_empty():
				return _fail(error)
			_auto_merge(next)
		"claim":
			if not args.get("quest") is int or not Quests.claim(next, args.quest):
				return _fail("UNAVAILABLE")
		"allocate_stat":
			if not Growth.allocate(next.progression, str(args.get("stat", ""))):
				return _refuse(Growth.caption("INVALID_STAT"))
		"learn_skill":
			if not Growth.learn(next.progression, str(args.get("skill", ""))):
				return _refuse(Growth.caption("INVALID_SKILL"))
		"equip_skill":
			if not args.get("slot") is int or not args.get("skill") is String or not Growth.equip(next.progression, args.slot, args.skill):
				return _refuse(Growth.caption("INVALID_LOADOUT"))
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

func discover(region: int, difficulty: int, landmark: String) -> bool:
	var route := _route(region, difficulty)
	if route < 0 or _data.get("active_route", -1) != route or not Quests.valid_landmark(region, landmark) or _slot.unreadable:
		return false
	var next := _begin()
	if not Quests.record_landmark(next, region, landmark):
		return true
	var title := MAP_TEXT.get_message("landmark_" + landmark.get_slice(":", 1))
	_messages.append(MAP_TEXT.get_message("discovered") % title)
	return _commit(next)
