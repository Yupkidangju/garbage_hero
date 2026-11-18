extends SceneTree

const Hero = preload("res://scripts/player.gd")
const Shot = preload("res://scripts/hero_projectile.gd")
const CELL := Vector2i(320, 234)
const DATA := [
	["sword", "attack1", "고철검 · 베기", 10],
	["mace", "attack1", "너트 철퇴 · 내려찍기", 21],
	["spear", "attack1", "쇠갈퀴창 · 찌르기", 13],
	["bow", "attack1", "빨랫줄 활 · 사격", 15],
	["staff", "attack1", "전구 지팡이 · 발사", 23],
	["sword", "volley", "파편 사격", 16],
	["staff", "nova", "파동", 27],
	["spear", "rush", "돌진", 15],
]
var view := SubViewport.new()
var hero := Hero.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	view.size = CELL
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_2X
	root.add_child(view)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#364949")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = .70
	var lighting := WorldEnvironment.new()
	lighting.environment = env
	view.add_child(lighting)
	var light := DirectionalLight3D.new()
	view.add_child(light)
	light.rotation_degrees = Vector3(-58,-35,0)
	light.shadow_enabled = true
	light.light_energy = 1.15
	var ground := MeshInstance3D.new()
	var surface := PlaneMesh.new()
	surface.size = Vector2(48,48)
	ground.mesh = surface
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("#526760")
	ground.material_override = paint
	view.add_child(ground)
	view.add_child(hero)
	hero.set_physics_process(false)
	hero._fx.set_process(false)
	var label := Label.new()
	label.position = Vector2(12,9)
	label.add_theme_font_override("font",preload("res://assets/fonts/NotoSansKR.ttf"))
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_constant_override("outline_size",4)
	label.add_theme_color_override("font_outline_color",Color("#263a37"))
	view.add_child(label)
	var sheet := Image.create_empty(CELL.x*4,CELL.y*2,false,Image.FORMAT_RGB8)
	for i in DATA.size():
		var weapon: String = DATA[i][0]
		var move: String = DATA[i][1]
		label.text = DATA[i][2]
		hero.position = Vector3.ZERO
		hero._move = ""
		hero.configure_build({"weapon_type":weapon,"grade":1},{"atk":20},{"ranks":{move:1}},{"shield":{"id":1}})
		hero._fx.interrupt()
		hero._fx._process(1.0)
		hero._camera.size = 5.8 if move=="nova" else (4.2 if move in ["rush","volley"] else 3.25)
		hero._camera.h_offset = 0.0
		hero._start_move(move,Hero.SCREEN_RIGHT.rotated(Vector3.UP,-0.34))
		for frame in int(DATA[i][3])+1:
			hero._frame = frame
			hero.position += hero._tick_move(1.0/60.0)/60.0
			hero._animate(1.0/60.0)
			if hero._fx.ribbon_live:
				hero._fx.blade_sample(hero._bone_world(hero._base_bone),hero._bone_world(hero._tip_bone))
			for child in hero.get_children():
				if child is Shot:
					child.set_physics_process(false)
					child._physics_process(1.0/60.0)
			hero._fx._process(1.0/60.0)
		hero._camera.h_offset = 0.52 if move!="nova" else 0.0
		await process_frame
		RenderingServer.force_draw(false)
		var tile := view.get_texture().get_image()
		tile.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(tile,Rect2i(Vector2i.ZERO,CELL),Vector2i(i%4,i/4)*CELL)
		for child in hero.get_children():
			if child is Shot:
				child.queue_free()
		await process_frame
	var output := ProjectSettings.globalize_path("res://../art/review/arsenal_actions.webp")
	var error := sheet.save_webp(output,false,.94)
	print("Arsenal action sheet ",output," ",error_string(error))
	view.queue_free()
	await process_frame
	quit(int(error != OK))
