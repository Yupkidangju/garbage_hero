extends SceneTree
## 준비된 검수 위치에서 실제 Forward+ 월드와 인물을 촬영한다.

const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")

func _initialize() -> void:
	call_deferred("run")

func capture(world:World,player:Player,at:Vector2,path:String) -> void:
	player.global_position=world._floor_point(at)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(path)
	assert(error==OK,"terrain capture save")
	print(path)

func run() -> void:
	root.size=Vector2i(1280,720)
	var world:=World.new()
	root.add_child(world)
	var player:=Player.new()
	player.configure({"atk":10,"crit":0},false,false)
	root.add_child(player)
	player.bind_terrain(world)
	player.set_physics_process(false)
	var output:=ProjectSettings.globalize_path("res://../artifacts/world_030")
	DirAccess.make_dir_recursive_absolute(output)
	for region in 6:
		world.build(region)
		var river_x:=World.Layout.deep_rect(region).get_center().x
		await capture(world,player,Vector2(river_x+2,-34),output+"/region_%d_bridge.png"%region)
		if region in [0,3]:
			var cache:Dictionary=world.cache_points()[0]
			var p:=world.axes.to_local(cache.pos)
			await capture(world,player,Vector2(p.x,p.z+2),output+"/region_%d_grotto.png"%region)
		if region==3: await capture(world,player,Vector2(72,20),output+"/region_3_swamp.png")
	print("world graphics: 9 prepared-state captures")
	quit()
