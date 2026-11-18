extends SceneTree

const Hero = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Missile = preload("res://scripts/hero_projectile.gd")
var stage := Node3D.new()
var hero := Hero.new()
var failures := 0

class Target extends StaticBody3D:
	var hits: Array[int] = []
	var kind := "normal"
	var hit_radius := 0.28

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		add_to_group("enemies")
		var shape := CollisionShape3D.new()
		var body := CylinderShape3D.new()
		body.radius = hit_radius
		body.height = hit_radius * 2.1
		shape.shape = body
		shape.position.y = body.height*0.5
		add_child(shape)

	func take_hit(amount: int, _pull: Vector3, _incoming := Vector3.ZERO) -> int:
		hits.append(amount)
		return amount


func _initialize() -> void:
	_run.call_deferred()


func check(result: bool, label: String) -> void:
	if not result:
		failures += 1
		push_error(label)


func ticks(frames: int) -> void:
	for i in frames:
		await physics_frame


func press(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = size
	shape.shape = solid
	body.add_child(shape)
	body.position = at
	stage.add_child(body)
	return body


func target(at: Vector3) -> Target:
	var body := Target.new()
	body.position = at
	stage.add_child(body)
	return body


func build(weapon: String, attack := 20, rank := 1, slots := ["volley","nova","rush"], max_hp := 145) -> void:
	hero.configure_build({"weapon_type":weapon,"grade":3}, {"atk":attack,"crit":0,"defense":6,"speed":6,"max_hp":max_hp},
		{"ranks":{"volley":rank,"nova":rank,"rush":rank,"hook":rank},"loadout":slots},{"shield":{"id":2}})


func projectiles() -> int:
	var count := 0
	for child in hero.get_children():
		if child is Missile and not child.is_queued_for_deletion():
			count += 1
	return count


func shield_shots() -> void:
	var launch_point := Vector3(10,0,0)
	var guard := Enemy.new()
	guard.setup(0,0,"normal",3,"scarab-shield-test")
	guard.position = launch_point + Vector3.FORWARD*6.0
	stage.add_child(guard)
	guard.set_physics_process(false)
	var guard_at := guard.position
	build("staff",10)
	for trial in ["stationary","knockback","rear","turn"]:
		hero.position = launch_point
		hero._turn_to(Vector3.FORWARD)
		guard.hp = guard.max_hp
		guard.turn(Vector3.FORWARD if trial=="rear" else Vector3.BACK)
		await ticks(2)
		await press("attack")
		await ticks(20)
		check(projectiles()==1 and guard.hp==guard.max_hp,"Staff bolt is in flight before "+trial)
		if trial=="knockback":
			hero.apply_knockback(Vector3.RIGHT*12)
			check(hero.position.x > launch_point.x+11.9,"Shooter was displaced outside the frontal cone")
		if trial=="turn":
			guard.turn(Vector3.FORWARD)
		await ticks(60)
		var expected := 6 if trial in ["stationary","knockback"] else 16
		var actual := guard.max_hp - guard.hp
		check(actual==expected,"Staff versus shield after %s: %d expected %d" % [trial,actual,expected])
		check(guard.position.is_equal_approx(guard_at),"Projectile direction adds no displacement to the defender")
	guard.queue_free()
	await ticks(1)


func _run() -> void:
	root.add_child(stage)
	box(Vector3.DOWN,Vector3(60,2,60))
	stage.add_child(hero)
	build("sword")
	check(hero.hp == 145 and hero.max_hp == 145,"A new actor starts at the equipped maximum")
	check(hero.take_damage(20) and hero.hp == 131,"Armor removes six incoming damage")
	build("mace",20,1,["volley","nova","rush"],110)
	build("sword")
	check(hero.hp == 110 and hero.max_hp == 145,"Removing and replacing vitality gear cannot heal")
	await ticks(31)
	Input.action_press("move_right")
	await ticks(60)
	Input.action_release("move_right")
	await ticks(1)
	check(absf(hero.position.length()-6.0)<0.05,"Final movement stat changes world travel")
	hero.position = Vector3.ZERO
	hero._turn_to(Vector3.FORWARD)
	var front := target(Vector3(0,0,-1.45))
	var far := target(Vector3(0,0,-3.1))
	await ticks(2)
	await press("attack")
	await ticks(28)
	check(front.hits == [20] and far.hits.is_empty(),"Sword reach and legacy first hit")
	check(hero._equipment_meshes.shield.visible and hero._grade_nodes[0].visible,"Sword and shield can both be visible")
	build("mace")
	await press("attack")
	await ticks(12)
	check(front.hits == [20] and hero._spec.clip=="MaceCrush","Mace takes longer to land than a sword")
	build("spear",99)
	check(hero._equipment_meshes.mace.visible,"Changed gear retains the committed swing silhouette")
	await ticks(35)
	check(front.hits == [20,37] and hero._equipment_meshes.spear.visible and not hero._equipment_meshes.shield.visible,
		"Committed mace damage survives reconfiguration, then the two-handed spear replaces it")
	build("spear")
	var side := target(Vector3(1.3,0,-1.2))
	await press("attack")
	await ticks(34)
	check(far.hits == [24] and side.hits.is_empty(),"Spear reaches further along a narrow thrust")
	front.queue_free()
	far.queue_free()
	side.queue_free()
	await ticks(2)
	var ranged := target(Vector3(0,0,-6))
	var behind := target(Vector3(0,0,-8))
	for weapon: String in ["bow","staff"]:
		build(weapon)
		check(hero._equipment_meshes[weapon].visible and not hero._grade_nodes[0].visible,"Distinct two-hand mesh "+weapon)
		var old := ranged.hits.size()
		await press("attack")
		await ticks(20)
		check(projectiles()==1 and ranged.hits.size()==old,"Shot has travel time "+weapon)
		build("sword",99)
		await ticks(60)
		check(ranged.hits.size()==old+1 and ranged.hits[-1]==(20 if weapon=="bow" else 32) and behind.hits.is_empty(),
			"First cylinder receives snapshotted projectile damage "+weapon)
		var barrier := box(Vector3(0,0.9,-3.27),Vector3(2,1.8,0.03))
		build(weapon)
		await ticks(2)
		await press("attack")
		await ticks(65)
		check(ranged.hits.size()==old+1 and projectiles()==0,"Thin wall stops "+weapon)
		barrier.queue_free()
		await ticks(1)
	var near_cover := box(Vector3(0,1,-0.48),Vector3(2,2,0.04))
	build("staff")
	await ticks(2)
	await press("attack")
	await ticks(80)
	check(ranged.hits.size()==2 and projectiles()==0,"A staff tip crossing cover cannot launch through it")
	near_cover.queue_free()
	await ticks(1)
	ranged.position.z = -14
	behind.position.z = -16
	await ticks(2)
	for weapon: String in ["bow","staff"]:
		build(weapon)
		await press("attack")
		await ticks(85)
		check(projectiles()==0 and ranged.hits.size()==2,"Maximum projectile range "+weapon)
	ranged.position.z = -5
	var left := target(Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(-17.0))*5.0)
	var right := target(Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(17.0))*5.0)
	build("staff",20,2)
	await ticks(2)
	await press("hook")
	await ticks(15)
	check(projectiles()==3 and hero.cooldowns().hook>5,"Q fires the learned three-way volley")
	build("bow",99,5,["nova","volley","rush"])
	check(hero.cooldowns().spin>5 and hero.cooldowns().hook==0,"Cooldown follows volley from Q to E")
	await ticks(45)
	check(left.hits == [20] and right.hits == [20] and ranged.hits[-1]==20,"All fan shots retain rank two and attack at cast")
	await press("spin")
	await ticks(15)
	check(projectiles()==0 and left.hits.size()==1,"Slot transfer cannot bypass the cooldown")
	build("sword",20,5,["nova","volley","rush"])
	var rear := target(Vector3(0,0,2.3))
	var covered := target(Vector3(2.7,0,0))
	var cover := box(Vector3(1.2,1,0),Vector3(.1,2,1))
	await ticks(2)
	await press("hook")
	await ticks(5)
	check(hero._move=="nova" and hero._frame<int(hero._spec.windup),"Rank-five nova has committed before the build change")
	build("sword",99,1,["nova","volley","rush"])
	await ticks(50)
	check(rear.hits==[65] and covered.hits.is_empty(),"Rank-five nova keeps the prepared damage and respects cover")
	build("sword",20,5,["nova","volley","rush"])
	cover.queue_free()
	var rush_target := target(Vector3(0,0,-2.6))
	var stop := box(Vector3(0,.8,-3.3),Vector3(2,1.6,.15))
	await ticks(2)
	await press("slam")
	await ticks(40)
	check(hero.position.z < -1.4 and hero.position.z > -3.27 and rush_target.hits==[47],
		"R rush travels in world space and hits each defender once")
	rush_target.queue_free()
	hero.position = Vector3.ZERO
	await ticks(312)
	await press("slam")
	await ticks(42)
	check(hero.position.z < -2.7 and hero.position.z > -3.2,"Empty lane rush stops at solid cover")
	stop.queue_free()
	await shield_shots()
	print("Arsenal combat checks: %d failure(s)" % failures)
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
