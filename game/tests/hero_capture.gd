extends SceneTree

const Player = preload("res://scripts/player.gd")
const World = preload("res://scripts/world.gd")
const CAPTURE_SIZE := Vector2i(1280,720)
const OUTPUT := "res://../art/review"
var viewport := SubViewport.new()
var player := Player.new()
var caption := Label.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	viewport.size = CAPTURE_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	var world := World.new()
	viewport.add_child(world)
	world.build(0)
	viewport.add_child(player)
	player.position = world.boss_point()
	player.configure({"grade":0,"atk":10,"crit":0},true,true)
	player.set_physics_process(false)
	player.set_process_input(false)
	player._fx.set_process(false)
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_constant_override("outline_size", 5)
	caption.add_theme_color_override("font_outline_color", Color("#282f30"))
	viewport.add_child(caption)
	for i in 5:
		await process_frame
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var cell := Vector2i(164,141)
	var sheet := Image.create_empty(cell.x*4,cell.y*2,false,Image.FORMAT_RGB8)
	for i in 8:
		player._turn_to(Player.SCREEN_DOWN.rotated(Vector3.UP, i*TAU/8.0))
		player._play("Locomotion")
		player._animate(0.2)
		await _capture(sheet, cell, Vector2i(i%4,i/4), "%d°" % (i*45))
	var err := sheet.save_png(folder.path_join("hero_directions.png"))
	if err != OK:
		push_error(error_string(err))
		quit(1)
		return
	cell = Vector2i(326,145)
	var moves := ["attack1","attack2","attack3","dodge","hook","spin","slam"]
	var names_ko := ["1타","2타","3타","회피","갈퀴","회오리","강타"]
	sheet = Image.create_empty(cell.x*3,cell.y*moves.size(),false,Image.FORMAT_RGB8)
	for row in moves.size():
		player.position = world.boss_point()
		player._fx.interrupt()
		player._fx._process(1)
		player._start_move(moves[row], Player.SCREEN_RIGHT.rotated(Vector3.UP,-0.48))
		var windup := int(player._spec.windup)
		var active := int(player._spec.active)
		var samples := [windup-2,windup+mini(active-1,3),windup+active+6]
		for tick in range(int(samples[2])+1):
			player._physics_process(1.0/60.0)
			player._fx._process(1.0/60.0)
			var col := samples.find(tick)
			if col >= 0:
				var phase: String = ["준비","판정","회복"][col]
				var offset := Vector2i(95,16) if moves[row] == "hook" else Vector2i.ZERO
				await _capture(sheet, cell, Vector2i(col,row), "%s · %s  %df" % [names_ko[row],phase,tick], offset)
	err = sheet.save_png(folder.path_join("hero_combat.png"))
	print("Hero sheets: ", folder, " ", error_string(err))
	viewport.queue_free()
	await process_frame
	quit(0 if err == OK else 1)


func _capture(sheet: Image, cell: Vector2i, index: Vector2i, label: String, offset := Vector2i.ZERO) -> void:
	var center := Vector2i(player._camera.unproject_position(player.position+Vector3.UP*0.76))
	var corner := center-cell/2+offset
	caption.text = label
	caption.position = Vector2(corner+Vector2i(8,6))
	await process_frame
	RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	sheet.blit_rect(image,Rect2i(corner,cell),index*cell)
