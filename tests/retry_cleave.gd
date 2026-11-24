extends SceneTree

const Slot := preload("res://scripts/slot_store.gd")
var sandbox: DirAccess
var game
var failures := 0
var obstruction := ""

func _initialize() -> void:
	sandbox = DirAccess.create_temp("garbagehero-retry-cleave")
	if not sandbox:
		quit(1)
		return
	OS.set_environment("GARBAGEHERO_SAVE_DIR", sandbox.get_current_dir().path_join("save"))
	OS.set_environment("GARBAGEHERO_SETTINGS_PATH", sandbox.get_current_dir().path_join("settings.cfg"))
	_run.call_deferred()

func _check(value: bool, label: String) -> bool:
	if not value:
		failures += 1
		push_error(label)
	return value

func _block_next_write() -> void:
	var slot = game.session._slot
	var next_bank := 1 - int(slot.active_bank)
	obstruction = slot.directory.path_join("slot-v3-%d.sav.tmp" % next_bank)
	_check(DirAccess.make_dir_absolute(obstruction) == OK, "fixture blocked the next temporary save file")

func _allow_write() -> void:
	_check(DirAccess.remove_absolute(obstruction) == OK, "fixture removed its temporary directory")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not _check(game.session.act("depart", {"region": 0, "difficulty": 0}), "departed with isolated save"):
		quit(1)
		return
	game._enter(0, 0)
	var hunter = game.player
	var director = game.director
	var ids: Array[String] = []
	var approach := Vector3.RIGHT.rotated(Vector3.UP, PI / 4.0)
	for i in 2:
		var enemy = director.enemies[i]
		enemy.hp = 1
		enemy.global_position = hunter.global_position + approach * (1.0 + i * 0.7)
		ids.append(enemy.spawn_id)
	var before: int = game.session._data.seq
	_block_next_write()
	hunter._start_move("spin", approach)
	hunter._sector_hits()
	_check(paused and is_instance_valid(game.error_layer), "cleave opened the retry overlay")
	_check(director.pending_kills.size() == 2 and game.session._data.seq == before, "two deaths survived the failed write")
	game._retry_saves()
	_check(paused and game.session.ui_state().coins == 0, "repeated failure kept both rewards pending")
	_allow_write()
	# 한 처치만 저장된 뒤 다시 실패시켜 부분 성공 이후의 재시도까지 확인한다.
	game.session.changed.connect(_block_next_write, CONNECT_ONE_SHOT)
	game._retry_saves()
	_check(paused and director.pending_kills.size() == 1, "a second save fault kept only the remaining death")
	_check(game.session.ui_state().coins == 1 and game.session._data.seq == before + 1, "first recovery committed exactly one reward")
	if director.pending_kills.size() == 1:
		_check(director.pending_kills[0].id == ids[1], "recovery retained original hit order")
	_allow_write()
	game._retry_saves()
	_check(not paused and not is_instance_valid(game.error_layer) and director.pending_kills.is_empty(), "retry finished and resumed play")
	var saved := Slot.new(game.session._slot.directory).load_slot()
	_check(saved.get("coins") == 2 and saved.get("seq") == before + 2, "both rewards were durable exactly once")
	_check(game.session.world_state(0, 0).trace == 2, "both kills contributed to the hunt")
	for id in ids:
		_check(not game.session.record_kill(0, 0, "normal", id, hunter.global_position), "replayed receipt rejected: " + id)
	print("Cleave save-retry integration: %d failures" % failures)
	await game.prepare_shutdown()
	quit(1 if failures else 0)
