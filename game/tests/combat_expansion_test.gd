extends SceneTree

const Hero = preload("res://scripts/player.gd")
const Missile = preload("res://scripts/hero_projectile.gd")
const Moves = preload("res://data/combat_moves.gd")
const World = preload("res://scripts/world.gd")
const Loot = preload("res://data/loot_rules.gd")
var failures := 0
var checks := 0
var stage := Node3D.new()
var hero := Hero.new()

class TerrainFixture extends Node3D:
	var kind := "ground"
	var edge := 12.0

	func surface_at(at: Vector3) -> Dictionary:
		return {"kind":"deep" if at.x >= edge else kind, "speed":0.6 if kind == "swamp" else (0.7 if kind == "shallow" else 1.0), "walkable":at.x < edge, "height":0.0}

	func constrain_motion(origin: Vector3, displacement: Vector3, radius: float) -> Vector3:
		var result := displacement
		result.x = minf(result.x, maxf(0.0, edge-radius-origin.x))
		return result

class Target extends StaticBody3D:
	var hits: Array[int] = []
	var hp := 100
	var kind := "normal"
	var hit_radius := 0.3
	var reduction := 0

	func _ready() -> void:
		add_to_group("enemies")
		collision_layer = 4
		collision_mask = 0
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = hit_radius
		cylinder.height = maxf(1.3,hit_radius*2.1)
		shape.shape = cylinder
		shape.position.y = cylinder.height*0.5
		add_child(shape)

	func take_hit(amount: int, _pull: Vector3, _incoming := Vector3.ZERO) -> int:
		var actual := mini(hp, maxi(0, amount-reduction))
		hp -= actual
		hits.append(actual)
		return actual

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	stage.add_child(body)
	return body

func target(at: Vector3, hp := 100, reduction := 0, radius := 0.3) -> Target:
	var body := Target.new()
	body.position = at
	body.hp = hp
	body.reduction = reduction
	body.hit_radius = radius
	stage.add_child(body)
	return body

func build(kind := "sword", effects := {}, design := 0) -> void:
	hero.configure_build({"weapon_type":kind,"grade":0,"design":design},
		{"atk":20,"crit":0,"defense":0,"max_hp":100,"speed":5.0,"effects":effects},
		{"ranks":{"rush":1,"spin":1},"loadout":["rush","spin",""]},{})

func move_right(count: int) -> void:
	Input.action_press("move_right")
	Input.action_press("move_down")
	await ticks(count)
	Input.action_release("move_right")
	Input.action_release("move_down")
	await ticks(1)

func world_point(world: Node3D, local: Vector2) -> Vector3:
	var at: Vector3 = world.axes.to_global(Vector3(local.x,0.0,local.y))
	at.y = world.ground_at(at)
	return at

func actual_terrain_checks() -> void:
	var world := World.new()
	stage.add_child(world)
	hero.bind_terrain(world)
	for region in 6:
		world.build(region)
		await ticks(2)
		var center := -74.0-float(region)*0.8
		var direction: Vector3 = -world.axes.global_basis.x
		for action in ["dodge","rush"]:
			hero.position = world_point(world,Vector2(center+5.55,0))
			hero.velocity = Vector3.ZERO
			await ticks(2)
			hero._start_move(action,direction)
			await ticks(40)
			var local: Vector3 = world.axes.to_local(hero.global_position)
			check(local.x>=center+5.32 and local.x<center+5.50 and absf(hero.position.y-world.ground_at(hero.position))<0.06,"Actual river blocks grounded %s in region %d" % [action,region])
			check(hero.terrain_state().blocked_kind=="deep","Shoreline contact explains the blocked "+action)
		hero.position = world_point(world,Vector2(center+8,0))
		hero.velocity = Vector3.ZERO
		await ticks(2)
		hero.apply_knockback(direction*20.0)
		check(world.axes.to_local(hero.position).x>=center+5.32,"Actual deep river stops long knockback in region %d" % region)
		hero.position = world_point(world,Vector2(center+7.7,-34))
		hero.velocity = Vector3.ZERO
		await ticks(2)
		hero.apply_knockback(direction*16.0)
		check(world.axes.to_local(hero.position).x<center-5.4 and absf(hero.position.y-world.ground_at(hero.position))<0.06,"Actual bridge passes grounded knockback in region %d: local=%s surface=%s" % [region,str(world.axes.to_local(hero.position)),str(world.surface_at(hero.position))])
		if region == 3:
			for sample in [{"at":Vector2(0,48),"distance":5.0,"kind":"ground"},{"at":Vector2(center+6,0),"distance":3.5,"kind":"shallow"},{"at":Vector2(70,20),"distance":3.0,"kind":"swamp"}]:
				hero.position = world_point(world,sample.at)
				hero.velocity = Vector3.ZERO
				await ticks(2)
				var before := hero.position
				Input.action_press("move_down")
				await ticks(60)
				Input.action_release("move_down")
				await ticks(1)
				var distance: float = (hero.position-before).dot(world.axes.global_basis.z)
				check(absf(distance-float(sample.distance))<0.07,"Actual timed input speed %s: %.3fm" % [sample.kind,distance])
				check(hero.terrain_state().kind==sample.kind,"Actual HUD surface state "+str(sample.kind))
		hero._move = ""
		hero._frame = 0
	hero.bind_terrain(null)
	world.queue_free()
	await ticks(1)

func gear_checks() -> void:
	for sample in [{"id":30,"windup":15,"range":14.4},{"id":31,"windup":8,"range":10.2},{"id":34,"windup":13,"range":13.0}]:
		var view := Loot.design_view(int(sample.id),0)
		hero.configure_build(view,{"atk":20,"max_hp":100},{"ranks":{},"loadout":[]},{})
		hero._start_move("attack1",Vector3.FORWARD)
		check(int(hero._spec.windup)==int(sample.windup) and is_equal_approx(float(hero._spec.range),float(sample.range)),"Descriptor changes actual bow timing and reach %d" % sample.id)
		hero._move = ""
	var old := Loot.design_view(21,0)
	hero.configure_build(old,{"atk":20,"max_hp":100},{"ranks":{},"loadout":[]},{})
	hero._start_move("attack1",Vector3.FORWARD)
	check(hero._spec.windup==11 and hero._spec.range==12.0,"Existing saved bow retains its timing and reach")
	hero._move = ""
	var items := {"armor":Loot.design_view(52,2),"shield":Loot.design_view(58,2),"boots":Loot.design_view(64,2),"helmet":Loot.design_view(70,2),"ring":Loot.design_view(76,2),"necklace":Loot.design_view(82,2)}
	hero.configure_build(Loot.design_view(1,2),{"atk":20,"max_hp":100},{"ranks":{},"loadout":[]},items)
	for name in ["weapon","armor","shield","boots_left","boots_right","helmet","ring","necklace"]:
		var socket := hero.find_child("ItemSlot_"+str(name),true,false)
		check(socket != null and socket.get_child_count()>0,"Actual modeled equipment is attached at "+str(name))
	if hero.find_child("ItemSlot_weapon",true,false) != null:
		hero._start_move("attack1",Vector3.FORWARD)
		hero.configure_build(Loot.design_view(29,2),{"atk":20,"max_hp":100},{"ranks":{},"loadout":[]},items)
		check(hero.find_child("ItemSlot_weapon",true,false).get_meta("design")==1,"A committed swing keeps its original modeled weapon")
		await ticks(26)
		check(hero.find_child("ItemSlot_weapon",true,false).get_meta("design")==29,"The next pose uses the newly equipped modeled weapon")

func _run() -> void:
	root.add_child(stage)
	var floor := box(Vector3.DOWN,Vector3(100,2,100))
	stage.add_child(hero)
	build()
	await ticks(3)
	var terrain := TerrainFixture.new()
	stage.add_child(terrain)
	check(hero.has_method("bind_terrain"),"Player exposes the functional terrain boundary")
	if hero.has_method("bind_terrain"):
		hero.call("bind_terrain",terrain)
		for sample in [{"kind":"ground","distance":5.0},{"kind":"swamp","distance":3.0},{"kind":"shallow","distance":3.5}]:
			terrain.kind = sample.kind
			hero.position = Vector3.ZERO
			await move_right(60)
			check(absf(hero.position.x-float(sample.distance))<0.04,"Grounded walking applies "+str(sample.kind)+" speed")
		terrain.kind = "shallow"
		for action in ["dodge","rush"]:
			hero.position = Vector3(10,0,0)
			hero._start_move(action,Vector3.RIGHT)
			await ticks(40)
			check(hero.position.x<=11.67 and hero.position.y<0.02,"Deep water stops grounded "+action)
		hero.position = Vector3(10,0,0)
		hero.apply_knockback(Vector3(20,0,0))
		check(hero.position.x<=11.67 and hero.position.y<0.02,"Long knockback cannot cross deep water")
		hero.call("bind_terrain",null)
	hero.position = Vector3.ZERO
	hero._turn_to(Vector3.FORWARD)
	build("sword",{"lifesteal":0.12})
	hero.hp = 50
	var reduced := target(Vector3(0,0,-1.2),100,15)
	await ticks(2)
	hero._start_move("attack1",Vector3.FORWARD)
	await ticks(26)
	check(reduced.hits==[5] and hero.hp==50,"Lifesteal retains fractional healing from actual reduced damage")
	hero._start_move("attack1",Vector3.FORWARD)
	await ticks(26)
	check(reduced.hits==[5,5] and hero.hp==51,"Fractional lifesteal accumulates without rounding each hit up")
	reduced.hp = 0
	hero._start_move("attack1",Vector3.FORWARD)
	await ticks(26)
	check(hero.hp==51,"A defeated target grants no lifesteal")
	reduced.queue_free()
	await ticks(1)
	build("sword",{"area":0.35})
	var edge := target(Vector3(0,0,-3.25))
	await ticks(2)
	hero._start_move("spin",Vector3.FORWARD)
	build("sword",{})
	await ticks(48)
	check(edge.hits==[15,15],"A committed area bonus survives an equipment change and reaches both spin beats")
	hero._start_move("spin",Vector3.FORWARD)
	await ticks(48)
	check(edge.hits==[15,15],"Removing area gear restores the next cast radius")
	edge.queue_free()
	await ticks(1)
	build("bow",{"pierce":2})
	var targets := [target(Vector3(0,0,-6)),target(Vector3(0,0,-7)),target(Vector3(0,0,-8)),target(Vector3(0,0,-9))]
	await ticks(2)
	hero._start_move("attack1",Vector3.FORWARD)
	build("sword",{})
	await ticks(70)
	check(targets[0].hits==[20] and targets[1].hits==[20] and targets[2].hits==[20] and targets[3].hits.is_empty(),"A committed piercing shot hits exactly three distinct targets: %s" % str(targets.map(func(body): return body.hits)))
	for body in targets:
		body.hits.clear()
	build("staff",{"pierce":3})
	var wall := box(Vector3(0,1,-6.6),Vector3(2,2,0.04))
	await ticks(2)
	hero._start_move("attack1",Vector3.FORWARD)
	await ticks(80)
	check(targets[0].hits==[32] and targets[1].hits.is_empty(),"Piercing projectiles still stop at the first solid wall")
	wall.queue_free()
	for body in targets:
		body.queue_free()
	await ticks(1)
	hero.configure_build(Loot.design_view(34,0),{"atk":20,"crit":0,"max_hp":100,"effects":{"pierce":2}},{"ranks":{},"loadout":[]},{})
	var close_targets := [target(Vector3(0,0,-1.4),100,0,1.04),target(Vector3(0,0,-5),100,0,0.6),target(Vector3(0,0,-7),100,0,0.6)]
	await ticks(2)
	hero._start_move("attack1",Vector3.FORWARD)
	await ticks(90)
	check(close_targets[0].hits==[20] and close_targets[1].hits==[20] and close_targets[2].hits==[20],"Pierce continues after a legal large enemy blocks the chest-to-muzzle segment")
	for body in close_targets:
		body.queue_free()
	await ticks(1)
	check(hero.has_method("preview_cast") and hero.has_method("preview_tick"),"Player exposes isolated real-action preview hooks")
	if hero.has_method("preview_cast"):
		var preview := Hero.new()
		preview.set("preview_mode",true)
		stage.add_child(preview)
		var victim := target(Vector3(0,0,-1))
		check(not preview.is_in_group("player") and preview.collision_layer==0 and preview.collision_mask==0,"Preview is absent from live player collision and groups")
		var cues := [0]
		preview.cue.connect(func(_kind: String): cues[0]+=1)
		check(preview.call("preview_cast","spin"),"Preview starts the real spin action")
		for i in 47:
			preview.call("preview_tick",1.0/60.0)
		check(preview._move.is_empty() and preview.position==Vector3.ZERO and victim.hits.is_empty() and cues[0]==0,"Preview clock completes the actual action without world movement, damage, or audio")
		preview.queue_free()
		victim.queue_free()
	await gear_checks()
	floor.queue_free()
	await ticks(1)
	await actual_terrain_checks()
	print("Combat expansion: %d checks, %d failure(s)" % [checks,failures])
	stage.queue_free()
	await process_frame
	quit(1 if failures else 0)
