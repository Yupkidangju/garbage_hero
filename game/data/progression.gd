extends RefCounted

const TEXT: Translation = preload("res://data/progression_ko.tres")
const ATTRIBUTES := ["strength", "vitality", "agility"]
const SKILLS := {
	"hook": {"level":1, "prerequisite":""},
	"spin": {"level":2, "prerequisite":"hook"},
	"slam": {"level":4, "prerequisite":"spin"},
	"volley": {"level":2, "prerequisite":"hook"},
	"nova": {"level":4, "prerequisite":"volley"},
	"rush": {"level":5, "prerequisite":"spin"}
}
const LEGACY_SLOTS := {"spin":1, "slam":2}
const MAX_RANK := 5
const XP_MULTIPLIERS := {"normal":1, "mini":5, "boss":12}


static func fresh() -> Dictionary:
	var ranks := {}
	for id in SKILLS:
		ranks[id] = 1 if id == "hook" else 0
	return {"level":1, "xp":0, "stat_points":0, "skill_points":0,
		"attributes":{"strength":0, "vitality":0, "agility":0},
		"ranks":ranks, "loadout":["hook", "", ""], "grants":[]}


static func from_legacy(first_merge: bool, forest_clear: bool) -> Dictionary:
	var p := fresh()
	if first_merge:
		grant_legacy(p, "spin")
	if forest_clear:
		grant_legacy(p, "slam")
	return p


static func _xp_next(level: int) -> int:
	return 30 + 15 * (level - 1)


static func gain(p: Dictionary, field_level: int, kind: String) -> int:
	if not XP_MULTIPLIERS.has(kind) or field_level < 1 or field_level > 70:
		return 0
	var old_level: int = p.level
	p.xp += (6 + 2 * (field_level - 1)) * XP_MULTIPLIERS[kind]
	while p.xp >= _xp_next(p.level):
		p.xp -= _xp_next(p.level)
		p.level += 1
	var gained: int = p.level - old_level
	p.stat_points += 3 * gained
	p.skill_points += gained
	return gained


static func allocate(p: Dictionary, stat: String) -> bool:
	if stat not in ATTRIBUTES or p.stat_points < 1:
		return false
	p.stat_points -= 1
	p.attributes[stat] += 1
	return true


static func _can_learn(p: Dictionary, skill: String) -> bool:
	if not SKILLS.has(skill) or p.skill_points < 1:
		return false
	var rank: int = p.ranks[skill]
	var rule: Dictionary = SKILLS[skill]
	return rank < MAX_RANK and p.level >= rule.level + rank and (
		rule.prerequisite == "" or p.ranks[rule.prerequisite] > 0)


static func learn(p: Dictionary, skill: String) -> bool:
	if not _can_learn(p, skill):
		return false
	p.skill_points -= 1
	p.ranks[skill] += 1
	return true


static func equip(p: Dictionary, slot: int, skill: String) -> bool:
	if slot < 0 or slot >= p.loadout.size():
		return false
	if skill != "" and p.ranks.get(skill, 0) == 0:
		return false
	if skill != "":
		var previous: int = p.loadout.find(skill)
		if previous >= 0:
			p.loadout[previous] = p.loadout[slot]
	p.loadout[slot] = skill
	return true


static func grant_legacy(p: Dictionary, skill: String) -> bool:
	if not LEGACY_SLOTS.has(skill) or p.ranks[skill] > 0:
		return false
	p.ranks[skill] = 1
	# 최초 합성과 숲 클리어로 얻은 한 등급은 소비 포인트에서 제외한다.
	p.grants.append(skill)
	var preferred: int = LEGACY_SLOTS[skill]
	var free_slot: int = preferred if p.loadout[preferred] == "" else p.loadout.find("")
	if free_slot >= 0:
		p.loadout[free_slot] = skill
	return true


static func damage_multiplier(rank: int) -> float:
	return (1.0 + 0.2 * (mini(rank, MAX_RANK) - 1)) if rank > 0 else 0.0


static func caption(key: String) -> String:
	return TEXT.get_message(key)


static func level_notice(p: Dictionary, levels: int) -> String:
	return caption("LEVEL_UP") % [p.level, 3 * levels, levels]


static func describe(p: Dictionary) -> Dictionary:
	var catalog := []
	for id: String in SKILLS:
		var rule: Dictionary = SKILLS[id]
		var rank: int = p.ranks[id]
		catalog.append({"id":id, "name":caption("SKILL_" + id), "description":caption("DESC_" + id),
			"rank":rank, "max_rank":MAX_RANK, "level_required":rule.level + rank if rank < MAX_RANK else 0,
			"prerequisite":rule.prerequisite, "can_learn":_can_learn(p, id), "cost":1,
			"damage_percent":roundi(100 * damage_multiplier(rank)),
			"next_damage_percent":roundi(100 * damage_multiplier(rank + 1)) if rank < MAX_RANK else 0})
	return {"level":p.level, "xp":p.xp, "xp_next":_xp_next(p.level), "stat_points":p.stat_points,
		"skill_points":p.skill_points, "attributes":p.attributes.duplicate(), "ranks":p.ranks.duplicate(),
		"loadout":p.loadout.duplicate(), "catalog":catalog}


static func stats(p: Dictionary, bonuses: Dictionary) -> Dictionary:
	return {"atk":int(bonuses.get("atk", 4)) + 2 * p.attributes.strength,
		"crit":clampi(int(bonuses.get("crit", 0)) + p.attributes.agility, 0, 100),
		"defense":int(bonuses.get("defense", 0)),
		"max_hp":100 + int(bonuses.get("max_hp", 0)) + 10 * p.attributes.vitality,
		"speed":5.0 + float(bonuses.get("speed", 0.0))}


static func valid(p: Variant) -> bool:
	if not p is Dictionary:
		return false
	for key in ["level", "xp", "stat_points", "skill_points"]:
		if not p.get(key) is int or p[key] < 0:
			return false
	if p.level < 1 or p.xp >= _xp_next(p.level):
		return false
	return _valid_attributes(p) and _valid_ranks(p) and _valid_loadout(p)


static func _valid_attributes(p: Dictionary) -> bool:
	if not p.get("attributes") is Dictionary or p.attributes.size() != ATTRIBUTES.size():
		return false
	var remaining: int = 3 * (p.level - 1) - p.stat_points
	for key in ATTRIBUTES:
		if not p.attributes.get(key) is int or p.attributes[key] < 0 or p.attributes[key] > remaining:
			return false
		remaining -= p.attributes[key]
	return remaining == 0


static func _valid_ranks(p: Dictionary) -> bool:
	if not p.get("ranks") is Dictionary or p.ranks.size() != SKILLS.size() or not p.get("grants") is Array:
		return false
	var free_ranks := ["hook"]
	for granted in p.grants:
		if not granted is String or not LEGACY_SLOTS.has(granted) or granted in free_ranks:
			return false
		free_ranks.append(granted)
	var accounted_ranks: int = p.skill_points
	for id in SKILLS:
		if not p.ranks.get(id) is int:
			return false
		var rank: int = p.ranks[id]
		var free: int = int(id in free_ranks)
		if rank < free or rank > MAX_RANK:
			return false
		if rank > free:
			var rule: Dictionary = SKILLS[id]
			if p.level < rule.level + rank - 1:
				return false
			if rule.prerequisite != "" and (not p.ranks.get(rule.prerequisite) is int or p.ranks[rule.prerequisite] < 1):
				return false
		accounted_ranks += rank - free
	return accounted_ranks == p.level - 1


static func _valid_loadout(p: Dictionary) -> bool:
	if not p.get("loadout") is Array or p.loadout.size() != 3:
		return false
	var equipped := []
	for skill in p.loadout:
		if not skill is String:
			return false
		if skill == "":
			continue
		if not SKILLS.has(skill) or p.ranks[skill] < 1 or skill in equipped:
			return false
		equipped.append(skill)
	return true
