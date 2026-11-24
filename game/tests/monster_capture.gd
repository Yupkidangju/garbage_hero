extends SceneTree
## 전투 모델 자체를 사용하는 고정 시점 검수용 몽타주. 저장이나 필드 스폰에는 관여하지 않는다.
const Model=preload("res://scripts/monster_model.gd")
const Book=preload("res://data/monsters.gd")
const Enemy=preload("res://scripts/enemy.gd")
const Mark=preload("res://scripts/monster_attack.gd")
class Target extends Node3D:
	func take_damage(_amount:int)->bool:
		return true
var viewport:=SubViewport.new()
var stage:=Node3D.new()
var camera:=Camera3D.new()
var caption:=Label.new()
var folder:=""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	folder=ProjectSettings.globalize_path("res://../tasks/evidence")
	DirAccess.make_dir_recursive_absolute(folder)
	viewport.size=Vector2i(360,320)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	root.add_child(viewport)
	viewport.add_child(stage)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("cedad6")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("f4edda")
	environment.environment.ambient_light_energy=.75
	stage.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-25,0)
	light.light_color=Color("fff0d6")
	light.light_energy=1.2
	stage.add_child(light)
	var floor:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(20,20)
	floor.mesh=plane
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color("b9cdc1")
	floor.material_override=mat
	floor.position.y=-.035
	stage.add_child(floor)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.55
	camera.position=Vector3(2.7,2.8,4.5)
	stage.add_child(camera)
	camera.look_at(Vector3(0,.78,0))
	caption.add_theme_font_override("font",preload("res://assets/fonts/NotoSansKR.ttf"))
	caption.add_theme_font_size_override("font_size",17)
	caption.add_theme_color_override("font_color",Color("283c3a"))
	caption.position=Vector2(12,9)
	viewport.add_child(caption)
	var entries:=[]
	for region in 6:
		var old_count:int=[5,6,5,6,5,6][region]
		for i in range(old_count,10):
			entries.append([region,"normal",i])
		entries.append([region,"mini",1])
	var sheet:=Image.create_empty(360*6,320*6,false,Image.FORMAT_RGB8)
	sheet.fill(Color("cedad6"))
	for n in entries.size():
		var entry:Array=entries[n]
		var row:Array=Book.species(entry[0],entry[1],entry[2])
		var model:=Model.new()
		stage.add_child(model)
		model.build(row[0],entry[0],entry[1])
		model.rotation.y=PI-.28
		model.play("Idle")
		model.advance(.25)
		caption.text=Book.NAMES.get_message(Book.display_key(entry[0],entry[1],entry[2]))+"\n"+row[0]
		await process_frame
		RenderingServer.force_draw(false)
		var frame:=viewport.get_texture().get_image()
		frame.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(frame,Rect2i(0,0,360,320),Vector2i(n%6,n/6)*Vector2i(360,320))
		model.free()
	var error:=sheet.save_png(folder.path_join("ecology-new-species.png"))
	print("MONSTER_MONTAGE new_species=",entries.size()," output=",folder.path_join("ecology-new-species.png")," result=",error_string(error))
	viewport.size=Vector2i(640,360)
	camera.size=10.5
	camera.position=Vector3(8,12,8)
	camera.look_at(Vector3(0,0,-1.5))
	var target:=Target.new()
	target.add_to_group("player")
	target.position=Vector3(0,0,-3.)
	stage.add_child(target)
	var actions:=Image.create_empty(1280,360*6,false,Image.FORMAT_RGB8)
	for region in 6:
		var enemy:=Enemy.new()
		enemy.setup(region,0,"mini",1,"capture-%d"%region)
		stage.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.turn(Vector3.FORWARD)
		enemy.begin(enemy.behavior)
		for column in 2:
			caption.text=enemy.display_name+" · "+("공격 준비" if column==0 else "판정 / 후속 예고")
			for node in enemy.get_children():
				if node is Mark:
					node.set_physics_process(false)
					node._physics_process(.35 if column==0 else .80)
			enemy.visual.play("Windup" if column==0 else "Attack",1.)
			enemy.visual.advance(.22)
			await process_frame
			RenderingServer.force_draw(false)
			var frame:=viewport.get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			actions.blit_rect(frame,Rect2i(0,0,640,360),Vector2i(column*640,region*360))
		enemy.free()
	var action_error:=actions.save_png(folder.path_join("ecology-mini-attacks.png"))
	print("MONSTER_ATTACK_MONTAGE six_actual_mini_variants result=",error_string(action_error))
	viewport.queue_free()
	await process_frame
	quit(0 if error==OK else 1)
