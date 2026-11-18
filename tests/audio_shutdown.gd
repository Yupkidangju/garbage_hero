extends SceneTree

# --verbose 출력의 AudioStreamWAV/AudioStreamPlaybackWAV 참조 잔류를 확인한다.
var folder: DirAccess

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	folder = DirAccess.create_temp("garbagehero-audio-exit")
	OS.set_environment("GARBAGEHERO_SAVE_DIR", folder.get_current_dir())
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for cue in ["hit","spin","warning","pickup"]:
		game._sound(cue)
	await create_timer(0.08).timeout
	if "--window" in OS.get_cmdline_user_args():
		game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	else:
		game._command("quit", {})
