extends RefCounted

# 최신 파일을 쓰는 동안에도 이전 정상 파일을 그대로 읽을 수 있는 두 세대 저장.
const MAGIC = "GH01"
const SCHEMA = 3
const Growth = preload("res://data/progression.gd")
const Equipment = preload("res://scripts/equipment.gd")
const Quests = preload("res://data/quest_book.gd")
var directory: String
var active_bank := -1
var unreadable := false
var recovered := false

func _init(folder: String) -> void:
	directory = ProjectSettings.globalize_path(folder).simplify_path()

func _path(bank: int) -> String:
	return directory.path_join("slot-v3-%d.sav" % bank)

func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish()

func _read(path: String, schema: int = SCHEMA) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file or file.get_length() < 37 or file.get_buffer(4).get_string_from_ascii() != MAGIC:
		return {}
	var checksum := file.get_buffer(32)
	var bytes := file.get_buffer(file.get_length() - file.get_position())
	if _digest(bytes) != checksum:
		return {}
	var decoded: Variant = bytes_to_var(bytes)
	if not decoded is Dictionary or decoded.get("schema") != schema or not decoded.get("seq") is int:
		return {}
	for key in ["coins", "next_id", "active_route", "equipped", "bag", "chest", "auto", "first_merge", "forest_kills",
		"bonus_stage", "routes", "claimed", "traveler", "pending_traveler", "rng", "normal_receipts"]:
		if not decoded.has(key):
			return {}
	var quest_count: int = 7 if schema == 1 else (18 if schema == 2 else Quests.COUNT)
	if not decoded.routes is Array or decoded.routes.size() != 24 or not decoded.claimed is Array or decoded.claimed.size() != quest_count:
		return {}
	for claimed in decoded.claimed:
		if not claimed is bool:
			return {}
	if schema >= 2:
		if not decoded.get("gear_slots") is Dictionary or not Equipment.valid_slots(decoded):
			return {}
		if not Growth.valid(decoded.get("progression")) or not Quests.valid_history(decoded.get("quest_history")):
			return {}
	if schema == SCHEMA and not _cache_records_valid(decoded):
		return {}
	return decoded

func load_slot() -> Dictionary:
	unreadable = false
	recovered = false
	active_bank = -1
	var latest := {}
	var corrupt := false
	# 가장 최근 형식이 존재하면 그 두 세대만 복구한다. 이전 형식의 바이트는 보전한다.
	var schema := SCHEMA
	while schema > 1 and not FileAccess.file_exists(_schema_path(schema, 0)) and not FileAccess.file_exists(_schema_path(schema, 1)):
		schema -= 1
	for bank in 2:
		var path := _schema_path(schema, bank)
		var candidate := _read(path, schema)
		if candidate.is_empty():
			corrupt = corrupt or FileAccess.file_exists(path)
		elif latest.is_empty() or candidate.seq > latest.seq:
			latest = candidate
			active_bank = bank if schema == SCHEMA else -1
	unreadable = corrupt and latest.is_empty()
	recovered = corrupt and not latest.is_empty()
	return latest

func _schema_path(schema: int, bank: int) -> String:
	return directory.path_join("slot-%d.sav" % bank if schema == 1 else "slot-v%d-%d.sav" % [schema, bank])

func _cache_records_valid(data: Dictionary) -> bool:
	if not data.get("cache_cycles") is Dictionary or not data.quest_history.get("caches") is Dictionary:
		return false
	for route in data.cache_cycles:
		if not route is String or not route.is_valid_int() or str(route.to_int()) != route:
			return false
		var index: int = route.to_int()
		var receipts: Variant = data.cache_cycles[route]
		if index < 0 or index >= 24 or not receipts is Dictionary:
			return false
		for key in receipts:
			if not key is String or not Quests.FieldLayout.valid_cache(index % 6, key):
				return false
			if not receipts[key] is int or receipts[key] < 1 or receipts[key] > data.routes[index].cycle:
				return false
	return true

func commit(data: Dictionary) -> bool:
	if unreadable or DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var bank := 1 if active_bank == 0 else 0
	var path := _path(bank)
	var temp_path := path + ".tmp"
	var bytes := var_to_bytes(data)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_buffer(_digest(bytes))
	file.store_buffer(bytes)
	file.flush()
	var success := file.get_error() == OK
	file.close()
	if not success or _read(temp_path) != data:
		return false
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
		return false
	if DirAccess.rename_absolute(temp_path, path) != OK:
		return false
	active_bank = bank
	return true
