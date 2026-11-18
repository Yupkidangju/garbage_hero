extends SceneTree

const Player = preload("res://scripts/player.gd")
class Target extends Node3D:
	var hits: Array[int] = []
	var pull := Vector3.ZERO
	var kind := "normal"
	var hit_radius := 0.3

	func _ready() -> void:
		add_to_group("enemies")

	func take_hit(amount: int, displacement: Vector3) -> int:
		hits.append(amount)
		pull = displacement
		return amount

var player := Player.new()
var failures := 0
var stage := Node3D.new()
var render_frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	render_frames += 1
	return false


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _target(pos: Vector3) -> Target:
	var target := Target.new()
	target.position = pos
	stage.add_child(target)
	return target


func _box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	stage.add_child(body)
	return body


func _run() -> void:
	root.add_child(stage)
	_box(Vector3.DOWN, Vector3(100,2,100))
	player.configure({"atk":20, "crit":0}, false, false)
	stage.add_child(player)
	_check(player._base_bone>=0 and player._tip_bone>=0 and player._clips.size()==11, "Imported skeleton, sword sockets, and all 11 action clips")
	var equipment := player._grade_nodes
	_check(equipment.size()==7, "Base weapon and six tier meshes")
	player.configure({"atk":20, "crit":0, "grade":6}, false, false)
	for mesh in equipment:
		_check(mesh.visible, "Highest tier shows " + str(mesh.name))
	player.configure({"atk":20, "crit":0, "grade":0}, false, false)
	for mesh in equipment:
		_check(mesh.visible == str(mesh.name).begins_with("WeaponBase"), "Base tier visibility " + str(mesh.name))
	await _ticks(3)
	var start := player.position
	Input.action_press("move_up")
	Input.action_press("move_right")
	await _ticks(60)
	Input.action_release("move_up")
	Input.action_release("move_right")
	await _ticks(1)
	var walked := player.position-start
	_check(absf(walked.length()-5.0)<0.025 and walked.z < -4.95, "Diagonal screen-space speed and direction")
	player.position = Vector3.ZERO
	player._turn_to(Vector3.FORWARD)
	var front := _target(Vector3(0,0,-1.5))
	var back := _target(Vector3(0,0,1.0))
	var far := _target(Vector3(0,0,-3.9))
	await _tap("attack")
	await _ticks(7)
	_check(front.hits.is_empty(), "First swing windup")
	await _ticks(1)
	_check(front.hits == [20], "First swing active tick")
	await _ticks(9)
	await _tap("attack")
	await _ticks(28)
	await _tap("attack")
	await _ticks(65)
	_check(front.hits == [20,23,33], "Buffered three-swing combo and per-swing hit deduplication")
	_check(back.hits.is_empty() and far.hits.is_empty(), "Melee sector facing and range")
	await _tap("spin")
	await _ticks(28)
	_check(player.cooldowns().spin == 0 and front.hits.size()==3, "First merge gates spin")
	await _tap("slam")
	_check(player.cooldowns().slam == 0, "Forest clear gates slam")
	await _tap("hook")
	await _ticks(14)
	_check(front.hits.size()==4 and front.hits[-1]==16 and front.pull.z>0.55, "Hook hits first normal and pulls toward player")
	_check(far.hits.is_empty() and player.cooldowns().hook>4.5, "Hook skips second target and starts cooldown")
	await _ticks(22)
	player.configure({"atk":20, "crit":0},true,true)
	await _tap("spin")
	await _ticks(55)
	_check(front.hits.slice(-2)==[15,15] and back.hits==[15,15], "Spin hits on two independent beats")
	await _tap("slam")
	await _ticks(60)
	_check(front.hits[-1]==48 and back.hits==[15,15], "Slam strength and sector")
	var start_dodge := player.position
	await _tap("dodge")
	await _ticks(5)
	player.take_damage(5)
	_check(player.hp==100, "Dodge active frames protect player")
	await _ticks(8)
	player.take_damage(5)
	_check(player.hp==95, "Dodge recovery is vulnerable")
	_check(absf(start_dodge.distance_to(player.position)-2.6)<0.025, "Dodge active travel distance")
	await _ticks(85)
	player.position = Vector3.ZERO
	player._turn_to(Vector3.FORWARD)
	var wall := _box(Vector3(0,1,-1),Vector3(2,2,0.2))
	await _ticks(2)
	var prior := front.hits.size()
	await _tap("attack")
	await _ticks(26)
	_check(front.hits.size()==prior, "Wall blocks melee")
	await _tap("dodge")
	await _ticks(28)
	_check(player.position.z > -0.7 and player.position.z < -0.3, "Wall stops dodge")
	wall.queue_free()
	await _ticks(1)
	paused = true
	var cooldown_before := float(player.cooldowns().dodge)
	await _ticks(15)
	_check(is_equal_approx(cooldown_before, player.cooldowns().dodge), "Pause freezes cooldown clock")
	paused = false
	var death := [0]
	player.died.connect(func(): death[0]+=1)
	player.take_damage(500)
	player.take_damage(1)
	await _ticks(45)
	_check(death[0]==1 and player.hp==0, "Death emits once after the defeat pose")
	print("Player physics checks: %d failure(s), %d rendered frames" % [failures,render_frames])
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
