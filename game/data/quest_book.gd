extends RefCounted

const HUD_TEXT: Translation = preload("res://data/hud_ko.tres")
const TEXT: Translation = preload("res://data/quests_ko.tres")
const FieldLayout = preload("res://scripts/world/field_layout.gd")
const ARMOR_SLOTS := ["armor", "helmet", "boots"]
const TRAINED_SKILLS := ["volley", "nova", "rush"]

# 저장된 수령 배열의 인덱스가 의뢰 ID이므로 새 의뢰는 끝에 추가한다.
const QUESTS := [
	{"kind":"merge", "reward":12},
	{"kind":"boss", "reward":20, "region":0, "requires":0},
	{"kind":"boss", "reward":20, "region":1, "requires":0},
	{"kind":"boss", "reward":20, "region":2, "requires":0},
	{"kind":"boss", "reward":20, "region":3, "requires":0},
	{"kind":"boss", "reward":20, "region":4, "requires":0},
	{"kind":"boss", "reward":20, "region":5, "requires":0},
	{"kind":"level", "reward":14, "target":3},
	{"kind":"train", "reward":16},
	{"kind":"mastery", "reward":30, "target":3, "requires":8},
	{"kind":"ranged", "reward":16},
	{"kind":"armor", "reward":24, "target":3},
	{"kind":"survey", "reward":12, "region":0, "target":2},
	{"kind":"survey", "reward":14, "region":1, "target":2},
	{"kind":"survey", "reward":16, "region":2, "target":2},
	{"kind":"survey", "reward":18, "region":3, "target":2},
	{"kind":"survey", "reward":20, "region":4, "target":2},
	{"kind":"survey", "reward":22, "region":5, "target":2},
	{"kind":"treasure", "reward":18, "region":0},
	{"kind":"treasure", "reward":20, "region":1},
	{"kind":"treasure", "reward":22, "region":2},
	{"kind":"treasure", "reward":24, "region":3},
	{"kind":"treasure", "reward":26, "region":4},
	{"kind":"treasure", "reward":28, "region":5},
]
static var COUNT: int:
	get: return QUESTS.size()

static func initialize(data: Dictionary) -> void:
	if not data.has("claimed"):
		data.claimed = []
	while data.claimed.size() < COUNT:
		data.claimed.append(false)
	if not data.has("quest_history"):
		data.quest_history = {"ranged":false, "armor_slots":{}, "landmarks":{}}
	if not data.quest_history.has("caches"):
		data.quest_history.caches = {}

static func record_equip(data: Dictionary, slot: String, family: String) -> void:
	var history: Dictionary = data.quest_history
	if slot == "weapon" and family in ["bow", "staff"]:
		history.ranged = true
	elif slot in ARMOR_SLOTS:
		history.armor_slots[slot] = true

static func record_landmark(data: Dictionary, region: int, key: String) -> bool:
	if not valid_landmark(region, key):
		return false
	var landmarks: Dictionary = data.quest_history.landmarks
	var region_key := str(region)
	if not landmarks.has(region_key):
		landmarks[region_key] = {}
	if landmarks[region_key].has(key):
		return false
	landmarks[region_key][key] = true
	return true

static func valid_landmark(region: int, key: String) -> bool:
	if region < 0 or region >= FieldLayout.TITLES.size():
		return false
	var prefix := "%d:" % region
	return key.begins_with(prefix) and (key.trim_prefix(prefix) in FieldLayout.TITLES[region] or key == prefix + "grotto")

static func valid_history(history: Variant) -> bool:
	if not history is Dictionary or not history.get("ranged") is bool:
		return false
	if not history.get("armor_slots") is Dictionary or not history.get("landmarks") is Dictionary:
		return false
	for slot in history.armor_slots:
		if not slot is String or slot not in ARMOR_SLOTS or not is_same(history.armor_slots[slot], true):
			return false
	for region_key in history.landmarks:
		if not region_key is String:
			return false
		var region := int(region_key)
		var marks: Variant = history.landmarks[region_key]
		if region_key != str(region) or region < 0 or region >= FieldLayout.TITLES.size() or not marks is Dictionary:
			return false
		for key in marks:
			if not key is String or not valid_landmark(region, key) or not is_same(marks[key], true):
				return false
	var caches: Variant = history.get("caches", {})
	if not caches is Dictionary:
		return false
	for key in caches:
		if not key is String or not is_same(caches[key], true):
			return false
		var region: int = key.get_slice(":", 0).to_int()
		if not FieldLayout.valid_cache(region, key):
			return false
	return true

static func _progress(data: Dictionary, quest: Dictionary) -> int:
	match quest.kind:
		"merge":
			return int(data.first_merge)
		"boss":
			for route in range(quest.region, data.routes.size(), 6):
				if data.routes[route].cleared:
					return 1
		"level":
			return data.progression.level
		"train":
			for skill in TRAINED_SKILLS:
				if data.progression.ranks.get(skill, 0) > 0:
					return 1
		"mastery":
			var highest := 0
			for rank: int in data.progression.ranks.values():
				highest = maxi(highest, rank)
			return highest
		"ranged":
			return int(data.quest_history.ranged)
		"armor":
			return data.quest_history.armor_slots.size()
		"survey":
			return data.quest_history.landmarks.get(str(quest.region), {}).size()
		"treasure":
			for key: String in data.quest_history.get("caches", {}):
				if key.begins_with(str(quest.region) + ":"):
					return 1
	return 0

static func _name(quest: Dictionary) -> String:
	match quest.kind:
		"merge":
			return HUD_TEXT.get_message("quest_first")
		"boss":
			return HUD_TEXT.get_message("quest_hunt") % HUD_TEXT.get_message("boss%d" % quest.region)
		"survey", "treasure":
			if quest.kind == "treasure":
				return TEXT.get_message("treasure_name") % HUD_TEXT.get_message("region%d" % quest.region)
			return TEXT.get_message("survey_name") % HUD_TEXT.get_message("region%d" % quest.region)
	return TEXT.get_message(quest.kind + "_name")

static func _description(quest: Dictionary) -> String:
	match quest.kind:
		"merge":
			return HUD_TEXT.get_message("quest_goal")
		"boss":
			return HUD_TEXT.get_message("quest_boss_goal") % [HUD_TEXT.get_message("region%d" % quest.region), HUD_TEXT.get_message("boss%d" % quest.region)]
		"survey":
			return TEXT.get_message("survey_goal") % [HUD_TEXT.get_message("region%d" % quest.region), quest.target]
		"treasure":
			return TEXT.get_message("treasure_goal") % HUD_TEXT.get_message("region%d" % quest.region)
		"level", "mastery":
			return TEXT.get_message(quest.kind + "_goal") % quest.target
	return TEXT.get_message(quest.kind + "_goal")

static func _prerequisite_met(data: Dictionary, quest: Dictionary) -> bool:
	return not quest.has("requires") or data.claimed[quest.requires]

static func views(data: Dictionary) -> Array:
	var result := []
	for id in COUNT:
		var quest: Dictionary = QUESTS[id]
		var target := int(quest.get("target", 1))
		var progress := mini(_progress(data, quest), target)
		var unlocked := _prerequisite_met(data, quest)
		var prerequisite := ""
		if not unlocked:
			prerequisite = TEXT.get_message("requires") % _name(QUESTS[quest.requires])
		result.append({"id":id, "name":_name(quest), "description":_description(quest),
			"progress":progress, "target":target, "eligible":unlocked and progress >= target,
			"claimed":data.claimed[id], "reward":quest.reward, "prerequisite":prerequisite})
	return result

static func claim(data: Dictionary, id: int) -> bool:
	if id < 0 or id >= COUNT or data.claimed[id]:
		return false
	var quest: Dictionary = QUESTS[id]
	if not _prerequisite_met(data, quest) or _progress(data, quest) < quest.get("target", 1):
		return false
	data.coins += quest.reward
	data.claimed[id] = true
	return true
