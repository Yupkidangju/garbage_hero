extends RefCounted

# 최신 파일을 쓰는 동안에도 이전 정상 파일을 그대로 읽을 수 있는 두 세대 저장.
const MAGIC = "GH01"
const SCHEMA = 1
var directory: String
var active_bank := -1
var unreadable := false
var recovered := false

func _init(folder: String) -> void:
	directory = ProjectSettings.globalize_path(folder).simplify_path()

func _path(bank: int) -> String:
	return directory.path_join("slot-%d.sav" % bank)

func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish()

func _read(path: String) -> Dictionary:
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
	if not decoded is Dictionary or decoded.get("schema") != SCHEMA or not decoded.get("seq") is int:
		return {}
	for key in ["coins", "next_id", "active_route", "equipped", "bag", "chest", "auto", "first_merge", "forest_kills",
		"bonus_stage", "routes", "claimed", "traveler", "pending_traveler", "rng", "normal_receipts"]:
		if not decoded.has(key):
			return {}
	if not decoded.routes is Array or decoded.routes.size() != 24 or not decoded.claimed is Array or decoded.claimed.size() != 7:
		return {}
	return decoded

func load_slot() -> Dictionary:
	unreadable = false
	recovered = false
	active_bank = -1
	var latest := {}
	var corrupt := false
	for bank in 2:
		var path := _path(bank)
		var candidate := _read(path)
		if candidate.is_empty():
			corrupt = corrupt or FileAccess.file_exists(path)
		elif latest.is_empty() or candidate.seq > latest.seq:
			latest = candidate
			active_bank = bank
	unreadable = corrupt and latest.is_empty()
	recovered = corrupt and not latest.is_empty()
	return latest

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
