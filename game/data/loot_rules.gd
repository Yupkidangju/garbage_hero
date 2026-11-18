extends Resource

const TEXT: Translation = preload("res://data/session_ko.tres")
const ATTACK_MIN = [8, 11, 14, 18, 23, 30, 39]
const ATTACK_MAX = [12, 16, 21, 27, 35, 45, 58]
const REROLL = [0.0, 0.15, 0.25, 0.4, 0.55, 0.7, 0.85]
const DESIGN_FACTOR = [1.0, 1.0, 1.10, 1.15, 0.95, 1.05, 1.20]
const CRIT_BONUS = [0, 2, 0, -1, 3, 1, -2]
const WEIGHT_LOW = [82.0, 16.0, 2.0, 0.0, 0.0, 0.0, 0.0]
const WEIGHT_MID = [43.0, 32.0, 17.0, 6.5, 1.4, 0.1, 0.0]
const WEIGHT_HIGH = [18.0, 31.0, 27.0, 15.0, 7.5, 1.4, 0.1]

static func caption(key: String) -> String:
	return TEXT.get_message(key)

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

static func weapon(id: int, design: int, grade: int, rng: RandomNumberGenerator) -> Dictionary:
	var attack := _draw_stat(ATTACK_MIN[grade], ATTACK_MAX[grade], grade, rng)
	var crit := _draw_stat(1 + grade, 4 + 2 * grade, grade, rng)
	return {"id": id, "order": id, "design": design, "grade": grade,
		"atk": roundi(attack * DESIGN_FACTOR[design]), "crit": maxi(0, crit + CRIT_BONUS[design]), "locked": false}

static func describe(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var view := item.duplicate()
	var design: int = item.design
	var next_grade := mini(item.grade + 1, 6)
	view.name = caption("DESIGN_%d" % design)
	view.grade_name = caption("GRADE_%d" % item.grade)
	view.next_min_atk = roundi(ATTACK_MIN[next_grade] * DESIGN_FACTOR[design])
	view.next_max_atk = roundi(ATTACK_MAX[next_grade] * DESIGN_FACTOR[design])
	view.next_min_crit = maxi(0, 1 + next_grade + CRIT_BONUS[design])
	view.next_max_crit = maxi(0, 4 + 2 * next_grade + CRIT_BONUS[design])
	return view
