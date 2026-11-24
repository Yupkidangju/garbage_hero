extends Resource

const TEXT: Translation = preload("res://data/session_ko.tres")
const HUD_TEXT: Translation = preload("res://data/hud_ko.tres")
const MAP_TEXT: Translation = preload("res://data/map_ko.tres")
const CATALOG: JSON = preload("res://data/item_catalog.json")
const MoveBook = preload("res://data/combat_moves.gd")
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
	["sword",1.24,2],
	["bow",1.18,-1], ["bow",1.08,4], ["bow",0.97,6], ["bow",1.28,-2], ["bow",1.14,3],
	["staff",0.98,4], ["staff",1.22,-1], ["staff",1.08,2], ["staff",1.02,5], ["staff",1.30,-2], ["staff",1.17,3],
	["spear",1.03,3], ["spear",1.23,-1], ["spear",0.96,5], ["spear",1.10,3], ["spear",1.28,-2], ["spear",1.20,2],
	["mace",1.04,3], ["mace",1.30,-2], ["mace",1.08,1], ["mace",1.15,2], ["mace",1.16,1],
	["armor",1.05,0], ["armor",1.08,0], ["armor",1.02,0], ["armor",1.12,0], ["armor",1.15,0], ["armor",1.20,0],
	["shield",1.06,0], ["shield",1.10,0], ["shield",1.14,0], ["shield",1.12,0], ["shield",1.16,0], ["shield",1.20,0],
	["boots",1.10,0], ["boots",1.08,0], ["boots",1.02,0], ["boots",1.18,0], ["boots",1.12,0], ["boots",1.20,0],
	["helmet",1.06,0], ["helmet",1.08,0], ["helmet",1.10,0], ["helmet",1.16,0], ["helmet",1.18,0], ["helmet",1.20,0],
	["ring",1.04,1], ["ring",1.10,2], ["ring",1.10,0], ["ring",1.12,2], ["ring",1.15,-1], ["ring",1.20,1],
	["necklace",1.04,0], ["necklace",1.08,2], ["necklace",1.10,0], ["necklace",1.15,0], ["necklace",1.16,1], ["necklace",1.20,1],
]
const WEAPONS = ["sword", "bow", "staff", "spear", "mace"]
const TWO_HANDED = ["bow", "staff", "spear"]
const STATS = ["atk", "crit", "defense", "max_hp", "speed"]
const TOWN_DESIGNS = [0, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
const REGIONAL_DESIGNS = [
	[1,17,23,35,41,47,52,58,70,76,82],
	[2,18,24,30,42,48,53,59,64,71,83],
	[3,19,25,31,36,43,54,60,65,77,84],
	[4,20,26,32,37,49,55,61,66,72,78],
	[5,21,27,38,44,50,62,67,73,79,85],
	[6,22,28,33,39,45,56,68,74,80,86],
]
const ARTIFACT_DESIGNS = [[29,63], [34,69], [40,75], [46,81], [51,87], [57]]
const EFFECT_CAPS = {"pierce":3, "lifesteal":0.12, "area":0.35}
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

static func catalog(design: int) -> Dictionary:
	if design < 0 or design >= BLUEPRINTS.size():
		return {}
	return CATALOG.data[design]

static func regional_pool(region: int) -> Array:
	if region < 0 or region >= REGIONAL_DESIGNS.size():
		return []
	return REGIONAL_DESIGNS[region] + ARTIFACT_DESIGNS[region]

static func _district_index(region: int, district: String) -> int:
	for index in 5:
		if district == "%d:district_%d" % [region, index]:
			return index
	return -1

static func drop_weights(region: int, district: String = "") -> Dictionary:
	# 지도와 동일한 고정 소지역 ID로 집중 도안을 고른다. 유물도 자연 드롭에 포함한다.
	var result := {0:120}
	for design in TOWN_DESIGNS.slice(1):
		result[design] = 28
	var pool := regional_pool(region)
	if pool.is_empty():
		return result
	var focus := _district_index(region, district)
	var local_total := 0
	for design: int in pool:
		var profile := catalog(design)
		var weight := 1 if profile.artifact else 4
		if focus >= 0 and int(profile.district) == focus:
			weight *= 4
		result[design] = weight
		local_total += weight
	# 정수 가중치 합은 지역 공통 40%, 지역 60%다. 추가 RNG 호출 없이 선택한다.
	for design: int in pool:
		result[design] *= 600
	for design: int in TOWN_DESIGNS:
		result[design] *= local_total
	return result

static func draw_design(region: int, rng: RandomNumberGenerator, district: String = "") -> int:
	var entries := drop_weights(region, district)
	var total := 0
	for value in entries.values():
		total += int(value)
	var roll := rng.randi_range(0, total - 1)
	for design: int in entries:
		roll -= int(entries[design])
		if roll < 0:
			return design
	return 0

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
	var values := {"atk":roundi(power), "crit":crit}
	match row[0]:
		"armor": values = {"defense":maxi(1, roundi(power * 0.22)), "max_hp":roundi(power * 0.7)}
		"shield": values = {"defense":maxi(1, roundi(power * 0.34))}
		"boots": values = {"speed":snappedf(power * 0.026, 0.01)}
		"helmet": values = {"defense":maxi(1, roundi(power * 0.14)), "max_hp":roundi(power * 0.9)}
		"ring": values = {"atk":maxi(1, roundi(power * 0.23)), "crit":crit}
		"necklace": values = {"crit":crit, "max_hp":roundi(power * 1.3)}
	if design >= 29:
		var modifiers: Dictionary = catalog(design).modifiers
		for stat: String in modifiers:
			var value: float = float(values.get(stat, power)) * float(modifiers[stat])
			values[stat] = snappedf(value, 0.01) if stat == "speed" else maxi(0, roundi(value))
	return values

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

static func effects(design: int) -> Dictionary:
	var profile := catalog(design)
	return profile.get("effects", {}).duplicate()

static func effect_text(design: int) -> String:
	var parts := PackedStringArray()
	var passive := effects(design)
	for effect: String in passive:
		var value := float(passive[effect])
		var number := roundi(value if effect == "pierce" else 100.0 * value)
		parts.append(caption("EFFECT_" + effect.to_upper()) % number)
	return " · ".join(parts)

static func source_text(design: int) -> String:
	var profile := catalog(design)
	var region: int = int(profile.get("region", -1))
	if region < 0:
		return caption("SOURCE_COMMON")
	var region_name := HUD_TEXT.get_message("region%d" % region)
	var district_name := MAP_TEXT.get_message("district_%d_%d" % [region,int(profile.district)])
	return caption("SOURCE_ARTIFACT" if profile.artifact else "SOURCE_REGION") % [region_name,district_name]

static func design_view(design: int, grade: int) -> Dictionary:
	var profile := catalog(design)
	if profile.is_empty():
		return {}
	var item_kind := kind(design)
	var item_slot := slot(design)
	var view := {"design":design, "name":caption("DESIGN_%d" % design),
		"description":caption(profile.description_key), "role":caption(profile.role_key),
		"icon":"res://assets/ui/items/item_%03d.png" % design,
		"visual":profile.visual.duplicate(true), "family":item_kind, "archetype":str(profile.visual.shape),
		"region":int(profile.region), "district":int(profile.district), "artifact":bool(profile.artifact),
		"effect_id":str(profile.effect_id), "effect_text":effect_text(design), "effects":effects(design),
		"source_text":source_text(design), "district_id":"%d:district_%d" % [int(profile.region),int(profile.district)] if int(profile.region) >= 0 else "",
		"grade":grade, "grade_name":caption("GRADE_%d" % grade),
		"slot":item_slot, "slot_name":caption("SLOT_" + item_slot.to_upper()),
		"type_name":caption("TYPE_" + item_kind.to_upper()) if item_slot == "weapon" else caption("SLOT_" + item_slot.to_upper()),
		"weapon_type":item_kind if item_slot == "weapon" else "", "two_handed":item_kind in TWO_HANDED}
	view.combat_profile = {}
	view.combat_profile_text = ""
	if item_slot == "weapon":
		var action := "attack1" if item_kind == "sword" else item_kind
		var move: Dictionary = MoveBook.for_gear(action,view)
		view.combat_profile = move
		view.combat_profile_text = caption("COMBAT_PROFILE") % [float(move.windup)/60.0,float(move.recovery)/60.0,float(move.range)]
		if move.has("speed"):
			view.combat_profile_text += caption("COMBAT_PROJECTILE") % float(move.speed)
	return view

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
