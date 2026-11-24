extends SubViewportContainer

const Hero = preload("res://scripts/player.gd")
var build: Dictionary = {}
var skill := ""
var hero
var viewport: SubViewport
var camera: Camera3D
var clock := 0.0
var accumulator := 0.0
var casting := false

func _ready() -> void:
	name = "SkillPreview" if not skill.is_empty() else "CharacterPreview"
	process_mode = Node.PROCESS_MODE_ALWAYS
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	custom_minimum_size = Vector2(180,220) if skill.is_empty() else Vector2(220,210)
	viewport = SubViewport.new()
	viewport.name = "IsolatedPreviewWorld"
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#172d31")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b7d9ce")
	env.ambient_light_energy = 0.74
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42,-36,0)
	light.light_color = Color("#ffe4b9")
	light.light_energy = 1.6
	viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,155,0)
	fill.light_color = Color("#82dec6")
	fill.light_energy = 0.65
	viewport.add_child(fill)
	var dais := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.12
	mesh.bottom_radius = 1.18
	mesh.height = 0.10
	dais.mesh = mesh
	dais.position.y = -0.075
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3e665e")
	mat.metallic = 0.35
	mat.roughness = 0.75
	dais.material_override = mat
	viewport.add_child(dais)
	hero = Hero.new()
	hero.preview_mode = true
	hero.name = "PreviewHero"
	viewport.add_child(hero)
	hero.configure_build(build.get("equipped",{}),build.get("stats",{}),build.get("progression",{}),build.get("equipment",{}))
	hero.set_feedback(false,bool(build.get("reduced_flash",false)))
	hero._turn_to(Vector3(0.2,0,0.98).normalized())
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.5 if skill.is_empty() else 5.2
	camera.position = Vector3(2.5,2.05,5.5) if skill.is_empty() else Vector3(3.0,3.8,6.2)
	viewport.add_child(camera)
	camera.look_at(Vector3(0,0.9,0) if skill.is_empty() else Vector3(0,0.8,-0.8))
	camera.current = true
	clock = 0.45

func replay() -> void:
	if is_instance_valid(hero) and not skill.is_empty():
		casting = bool(hero.preview_cast(skill))
		clock = 3.5

func _process(delta: float) -> void:
	if not is_instance_valid(hero) or not is_visible_in_tree(): return
	clock -= delta
	if not skill.is_empty() and clock<=0: replay()
	accumulator = minf(accumulator+delta,0.12)
	while accumulator>=1.0/60.0:
		hero.preview_tick(1.0/60.0)
		accumulator -= 1.0/60.0
