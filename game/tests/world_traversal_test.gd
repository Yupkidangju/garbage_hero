extends SceneTree

const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const ACTIONS := ["move_left","move_right","move_up","move_down"]
var failures:=0
var checks:=0
var world:World
var player:Player

func _initialize() -> void:
	call_deferred("run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func release_input() -> void:
	for action:String in ACTIONS: Input.action_release(action)

func walk_to(target:Vector2,max_ticks:int) -> bool:
	for i in max_ticks:
		var local:=world.axes.to_local(player.global_position)
		var offset:=target-Vector2(local.x,local.z)
		if offset.length()<.14:
			release_input()
			return true
		release_input()
		var direction:=offset.normalized()
		Input.action_press("move_left" if direction.x<0 else "move_right",absf(direction.x))
		Input.action_press("move_up" if direction.y<0 else "move_down",absf(direction.y))
		await physics_frame
		if not world.surface_at(player.global_position).walkable:
			release_input()
			return false
	release_input()
	return false

func reset_at(point:Vector2) -> void:
	release_input()
	player.global_position=world._floor_point(point)+Vector3.UP*.02
	player.velocity=Vector3.ZERO
	for i in 3: await physics_frame

func run() -> void:
	world=World.new()
	root.add_child(world)
	player=Player.new()
	player.configure({"atk":10,"crit":0},false,false)
	root.add_child(player)
	player.bind_terrain(world)
	for region in 6:
		world.build(region)
		for i in 3: await physics_frame
		var river_x:=World.Layout.deep_rect(region).get_center().x
		for z:float in [-34,51]:
			await reset_at(Vector2(river_x+10,z))
			var crossed:bool=await walk_to(Vector2(river_x-10,z),440)
			check(crossed,"실제 WASD 교량/여울 횡단 %d %s"%[region,z])
			check(absf(player.global_position.y-world.ground_at(player.global_position))<.08,"횡단 뒤 실제 발 접지 %d %s"%[region,z])
		var hill:=World.Height.ridge_center(region)
		await reset_at(hill+Vector2(0,6))
		var reached:bool=await walk_to(hill-Vector2(0,6),220)
		check(reached and player.global_position.y>.75,"실제 WASD 오르내리는 능선 %d"%region)
		for cache in world.cache_points():
			var local:=world.axes.to_local(cache.pos)
			await reset_at(Vector2(local.x,local.z+3.8))
			var entered:bool=await walk_to(Vector2(local.x,local.z),90)
			check(entered and world.cache_near(player.global_position)==cache.id,"실제 WASD 보물함/동굴 접근 %s"%cache.id)
		print("traversal region %d checked"%region)
	release_input()
	print("world traversal: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
