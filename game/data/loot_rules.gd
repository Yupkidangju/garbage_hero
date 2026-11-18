extends Resource

const TEXT: Translation = preload("res://data/session_ko.tres")
const ATTACK_MIN = [8, 11, 14, 18, 23, 30, 39]
const ATTACK_MAX = [12, 16, 21, 27, 35, 45, 58]
const REROLL = [0.0, 0.15, 0.25, 0.4, 0.55, 0.7, 0.85]
# 저장된 도안 번호는 고정이다. 열은 종류, 기본 위력 배수, 치명 가산이다.
const BLUEPRINTS = [
	["sword",1.0,0], ["sword",1.0,2], ["sword",1.10,0], ["sword",1.15,-1],
	["sword",0.95,3], ["sword",1.05,1], ["sword",1.20,-2],
	["bow",0.90,2], ["staff",1.05,0], ["spear",1.0,1], ["mace",1.12,-1],
	["armor",1.0,0], ["shield",1.0,0], ["boots",1.0,0],
	["helmet",1.0,0], ["ring",1.0,0], ["necklace",1.0,0],
	["bow",1.05,3], ["staff",1.16,1], ["mace",1.22,0],
	["spear",1.10,2], ["bow",1.09,3], ["mace",1.27,-1],
	["boots",1.20,0], ["ring",1.20,1], ["helmet",1.20,0],
	["necklace",1.20,1], ["armor",1.20,0], ["shield",1.20,0],
]
const WEAPONS = ["sword", "bow", "staff", "spear", "mace"]
const TWO_HANDED = ["bow", "staff", "spear"]
const STATS = ["atk", "crit", "defense", "max_hp", "speed"]
const TOWN_DESIGNS = [0, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
const REGIONAL_DESIGNS = [[1,17,23], [2,18,24], [3,19,25], [4,20,26], [5,21,27], [6,22,28]]
const WEIGHT_LOW = [82.0, 16.0, 2.0, 0.0, 0.0, 0.0, 0.0]
const WEIGHT_MID = [43.0, 32.0, 17.0, 6.5, 1.4, 0.1, 0.0]
const WEIGHT_HIGH = [18.0, 31.0, 27.0, 15.0, 7.5, 1.4, 0.1]

static func caption(key: String) -> String:
	return TEXT.get_message(key)

static func kind(design: int) -> String:
	if design < 0 or design >= BLUEPRINTS.size():
		return ""
	return BLUEPRINTS[design][0]

static func slot(design: int) -> String:
	var item_kind := kind(design)
	return "weapon" if item_kind in WEAPONS else item_kind

static func draw_design(region: int, rng: RandomNumberGenerator) -> int:
	# 공통 60칸은 고철검 20과 나머지 열 도안 각 4, 지역 40칸은 16/14/10이다.
	var roll := rng.randi_range(0, 99)
	if roll < 20:
		return 0
	if roll < 60:
		return TOWN_DESIGNS[1 + floori((roll - 20) / 4.0)]
	var local: Array = REGIONAL_DESIGNS[region]
	if roll < 76:
		return local[0]
	return local[1] if roll < 90 else local[2]

static func field_level(region: int, difficulty: int) -> int:
	return 1 + 3 * region + 18 * difficulty

static func weights(level: int) -> Array[float]:
	var first := WEIGHT_LOW if level <= 34 else WEIGHT_MID
	var last := WEIGHT_MID if level <= 34 else WEIGHT_HIGH
	var blend := clampf((level - 1) / 33.0 if level <= 34 else (level - 34) / 36.0, 0, 1)
	var result: Array[float] = []
	for i in 7:
		result.append(lerpf(first[i], last[i], blend))
	return result

static func draw_grade(level: int, rng: RandomNumberGenerator) -> int:
	var roll := rng.randf() * 100
	var entries := weights(level)
	for i in entries.size():
		roll -= entries[i]
		if roll < 0:
			return i
	# randf는 1.0도 반환하므로 확률 0인 꼬리 등급을 건너뛴다.
	for i in range(entries.size() - 1, -1, -1):
		if entries[i] > 0:
			return i
	return 0

static func _draw_stat(lo: int, hi: int, grade: int, rng: RandomNumberGenerator) -> int:
	var value := rng.randi_range(lo, hi)
	if rng.randf() < REROLL[grade]:
		value = maxi(value, rng.randi_range(lo, hi))
	return value

static func _stat_values(design: int, power_roll: int, crit_roll: int) -> Dictionary:
	var row: Array = BLUEPRINTS[design]
	var power := power_roll * float(row[1])
	var crit := maxi(0, crit_roll + int(row[2]))
	match row[0]:
		"armor": return {"defense":maxi(1, roundi(power * 0.22)), "max_hp":roundi(power * 0.7)}
		"shield": return {"defense":maxi(1, roundi(power * 0.34))}
		"boots": return {"speed":snappedf(power * 0.026, 0.01)}
		"helmet": return {"defense":maxi(1, roundi(power * 0.14)), "max_hp":roundi(power * 0.9)}
		"ring": return {"atk":maxi(1, roundi(power * 0.23)), "crit":crit}
		"necklace": return {"crit":crit, "max_hp":roundi(power * 1.3)}
	return {"atk":roundi(power), "crit":crit}

# 이 진입점과 기존 검의 두 난수 추첨 순서를 유지해 저장된 난수 스트림을 이어간다.
static func weapon(id: int, design: int, grade: int, rng: RandomNumberGenerator) -> Dictionary:
	var power := _draw_stat(ATTACK_MIN[grade], ATTACK_MAX[grade], grade, rng)
	var crit := _draw_stat(1 + grade, 4 + 2 * grade, grade, rng)
	var item := {"id":id, "order":id, "design":design, "grade":grade, "atk":0, "crit":0, "locked":false}
	item.merge(_stat_values(design, power, crit), true)
	return item

static func less_valuable(a: Dictionary, b: Dictionary) -> bool:
	for stat in STATS:
		if a.get(stat, 0) != b.get(stat, 0):
			return a.get(stat, 0) < b.get(stat, 0)
	return a.order < b.order

static func _format_number(stat: String, value: float, signed_value: bool = false) -> String:
	if stat == "speed":
		return ("%+.2f" if signed_value else "%.2f") % value
	return ("%+d" if signed_value else "%d") % roundi(value)

static func _stat_words(stat: String, number: String) -> String:
	return caption("STAT_" + stat.to_upper()) % number

static func stat_delta_text(delta: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat: String in STATS:
		var value := float(delta.get(stat, 0))
		if not is_zero_approx(value):
			parts.append(_stat_words(stat, _format_number(stat, value, true)))
	return " · ".join(parts) if not parts.is_empty() else caption("SAME_STATS")

static func _ranges(design: int, grade: int) -> Array:
	return [_stat_values(design, ATTACK_MIN[grade], 1 + grade),
		_stat_values(design, ATTACK_MAX[grade], 4 + 2 * grade)]

static func _format_stats(minima: Dictionary, maxima: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat: String in STATS:
		if not maxima.has(stat):
			continue
		var value := _format_number(stat, minima[stat])
		if minima[stat] != maxima[stat]:
			value += "–" + _format_number(stat, maxima[stat])
		parts.append(_stat_words(stat, value))
	return " · ".join(parts)

static func design_view(design: int, grade: int) -> Dictionary:
	var item_kind := kind(design)
	var item_slot := slot(design)
	return {"design":design, "name":caption("DESIGN_%d" % design),
		"grade":grade, "grade_name":caption("GRADE_%d" % grade),
		"slot":item_slot, "slot_name":caption("SLOT_" + item_slot.to_upper()),
		"type_name":caption("TYPE_" + item_kind.to_upper()) if item_slot == "weapon" else caption("SLOT_" + item_slot.to_upper()),
		"weapon_type":item_kind if item_slot == "weapon" else "", "two_handed":item_kind in TWO_HANDED}

static func range_text(design: int, grade: int) -> String:
	var bounds := _ranges(design, grade)
	return _format_stats(bounds[0], bounds[1])

static func describe(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var view := item.duplicate()
	var design: int = item.design
	view.merge(design_view(design, item.grade), true)
	var bounds := _ranges(design, mini(item.grade + 1, 6))
	var display := {}
	for stat in STATS:
		view[stat] = item.get(stat, 0)
		if bounds[1].has(stat):
			display[stat] = view[stat]
	view.stat_text = _format_stats(display, display)
	view.next_stat_text = _format_stats(bounds[0], bounds[1])
	view.next_min_atk = bounds[0].get("atk", 0)
	view.next_max_atk = bounds[1].get("atk", 0)
	view.next_min_crit = bounds[0].get("crit", 0)
	view.next_max_crit = bounds[1].get("crit", 0)
	return view
