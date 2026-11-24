extends SceneTree

# 편집기와 배포판은 같은 준비 장면과 프레임 수집 로직을 사용한다.
const Scenario = preload("res://scripts/runtime_benchmark.gd")
var sandbox: DirAccess

func _initialize() -> void:
	sandbox = Scenario.prepare_environment()
	if not sandbox:
		quit(2)
		return
	_start.call_deferred()

func _start() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var benchmark := Scenario.new()
	benchmark.configure(main,sandbox)
	root.add_child(benchmark)
