extends SceneTree

const Hero = preload("res://scripts/player.gd")
const Loot = preload("res://data/loot_rules.gd")
const CELL := Vector2i(400,420)
const SETS := [
	["수리공 기본",0,-1,-1,-1,-1,-1,-1],
	["솔방울 숲",1,52,58,23,70,76,82],
	["유리모래 장궁",30,53,-1,64,71,24,83],
	["종지기 촛대",36,54,-1,65,25,77,84],
	["늪의 삼지창",46,55,-1,66,72,78,26],
	["설산 진자철퇴",50,27,62,67,73,79,85],
	["화산 도가니칼",6,56,28,68,74,80,86],
	["유물 장착 · 뒤쪽",29,57,63,69,75,81,87],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := SubViewport.new()
	view.size = CELL
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_4X
	root.add_child(view)
	var environment := WorldEnvironment.new()
	var lighting := Environment.new()
	lighting.background_mode = Environment.BG_COLOR
	lighting.background_color = Color("#253b42")
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color("#d2e8e3")
	lighting.ambient_light_energy = 0.65
	environment.environment = lighting
	view.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-25,0)
	sun.light_energy = 1.6
	view.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.1
	view.add_child(camera)
	camera.position = Vector3(3.2,2.4,-5)
	camera.look_at(Vector3(0,0.97,0))
	camera.current = true
	var label := Label.new()
	label.position = Vector2(12,12)
	label.add_theme_font_override("font",preload("res://assets/fonts/NotoSansKR.ttf"))
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_color",Color("#fff2d5"))
	view.add_child(label)
	var note := Label.new()
	note.position = Vector2(12,390)
	note.text = "검수용 장착 상태 · 실제 게임 모델"
	note.add_theme_font_override("font",preload("res://assets/fonts/NotoSansKR.ttf"))
	note.add_theme_font_size_override("font_size",16)
	note.modulate = Color("#a7c8c4")
	view.add_child(note)
	var hero := Hero.new()
	hero.preview_mode = true
	view.add_child(hero)
	var sheet := Image.create_empty(CELL.x*4,CELL.y*2,false,Image.FORMAT_RGB8)
	for index in SETS.size():
		var row: Array = SETS[index]
		var equipment := {}
		for n in 6:
			if int(row[n+2])>=0:
				equipment[["armor","shield","boots","helmet","ring","necklace"][n]] = Loot.design_view(int(row[n+2]),2)
		hero.configure_build(Loot.design_view(int(row[1]),2),{"atk":20,"crit":0,"max_hp":100},{"ranks":{},"loadout":[]},equipment)
		hero._turn_to(Vector3.BACK if index==7 else Vector3.FORWARD)
		hero._play("Locomotion")
		hero.preview_tick(0.2)
		label.text = str(row[0])
		for frame in 3:
			await process_frame
		RenderingServer.force_draw(false)
		var image := view.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image,Rect2i(Vector2i.ZERO,CELL),Vector2i(index%4,index/4)*CELL)
	var path := "res://../tasks/evidence/combat-equipment.png"
	var error := sheet.save_png(ProjectSettings.globalize_path(path))
	print("Equipment capture: ",error_string(error)," ",ProjectSettings.globalize_path(path))
	view.queue_free()
	await process_frame
	quit(0 if error==OK else 1)
