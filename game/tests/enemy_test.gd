extends SceneTree

const Enemy = preload("res://scripts/enemy.gd")
const Book = preload("res://data/monsters.gd")
const Mark = preload("res://scripts/monster_attack.gd")
const Landscape = preload("res://scripts/world.gd")

class Hunter extends Node3D:
	var hits := 0
	var push := Vector3.ZERO
	func take_damage(_value:int) -> bool:
		hits += 1
		return true
	func apply_knockback(motion:Vector3) -> void:
		push += motion

var failed := 0
var hunter := Hunter.new()
var deaths := []
var stage := Node3D.new()

func _initialize() -> void:
	run.call_deferred()

func expect(check:bool,label:String) -> void:
	if not check:
		failed+=1
		push_error(label)

func spawn(region:int, difficulty:int, kind:String, index:int) -> CharacterBody3D:
	var actor=Enemy.new()
	actor.setup(region,difficulty,kind,index,"%s-%s-%s"%[region,kind,index])
	actor.set_meta("safe_point",Vector3(10.,0,0))
	actor.defeated.connect(func(k,id,pos):deaths.append([k,id,pos]))
	stage.add_child(actor)
	actor.set_physics_process(false)
	return actor

func zones(actor:Node) -> Array:
	return actor.get_children().filter(func(x):return x is Mark and not x.is_queued_for_deletion())

func population() -> void:
	var names:Dictionary={}
	var patterns:=0
	for r in 6:
		for kind in ["normal","mini","boss"]:
			for i in Book.NORMAL[r].size() if kind=="normal" else 1:
				var actor=spawn(r,3,kind,i)
				names[actor.display_name]=true
				expect(actor.is_in_group("enemies") and not actor.display_name.is_empty(),"Registered "+str(actor.species))
				expect(actor.hp==roundi(Book.species(r,kind,i)[2]*(1.+.05*(r*3+54))),"Scaled health")
				expect(actor.visual.body.get_child_count()>0,"Mesh for "+str(actor.species))
				if r==0:
					expect(actor.visual.animator!=null,"Blender rig "+str(actor.species))
					if actor.visual.animator:
						for clip in ["Idle","Run","Windup","Attack","Recover","Hit","Death"]:
							actor.visual.play(clip,.75)
							expect(str(actor.visual.animator.current_animation).ends_with(clip),"Imported clip "+str(actor.species)+"/"+clip)
				actor.build_sequence()
				expect(kind=="normal" or actor.queued.back()=="follow","Hard pattern")
				while not actor.queued.is_empty():
					var name:String=actor.queued.pop_front()
					actor.begin(name)
					var shots:=zones(actor)
					expect(not shots.is_empty(), "Telegraph for "+name)
					if shots.is_empty():
						continue
					for shot in shots:
						shot.set_physics_process(false)
						expect(shot.windup>=.1 and shot.carpet.mesh!=null,"Readable mark "+name)
						shot._physics_process(shot.windup*.85)
						expect(not shot.fired, "No early attack "+name)
						shot._physics_process(shot.windup*.16)
						expect(shot.fired, "Impact "+name)
						shot._physics_process(shot.active_time+1.)
						expect(shot.is_queued_for_deletion(),"Actual effects expire "+name)
						shot.free()
					patterns+=1
				var prev:=deaths.size()
				actor.take_hit(100000,Vector3.ZERO)
				actor.take_hit(100000,Vector3.ZERO)
				expect(deaths.size()==prev+1 and not actor.is_in_group("enemies"),"One reward "+str(actor.species))
				actor.free()
	expect(names.size()==45,"45 individually named species")
	print("species=",names.size()," attacks=",patterns)

func invariant_checks() -> void:
	var actor=spawn(0,0,"boss",0)
	expect(actor.hp==340 and actor.power==14,"Forest boss base stats")
	expect(actor.visual.animator!=null,"Wheelback Blender animation player")
	actor.turn(Vector3.FORWARD)
	actor.begin("roots")
	var root:Node=zones(actor)[0]
	var dir:Vector3=-root.global_basis.z
	expect(root.contains_point(dir*3.) and not root.contains_point(-dir*3.),"Root ring open side is safe")
	var prior:=hunter.hits
	hunter.position=-dir*3.
	root._physics_process(1.21)
	expect(hunter.hits==prior,"Walking through the root gap avoids impact")
	hunter.position=dir*3.
	root._physics_process(.02)
	expect(hunter.hits==prior+1,"Occupied sector damages")
	actor.free()
	var bee=spawn(0,0,"normal",1)
	expect(bee.hp==20 and bee.power==5,"Forest wasp base stats")
	hunter.position=Vector3(0,0,-3.)
	bee.turn(Vector3.FORWARD)
	bee.begin("needle")
	var shot:Node=zones(bee)[0]
	prior=hunter.hits
	shot._physics_process(.55)
	expect(hunter.hits==prior,"Ranged impact follows visible projectile")
	for i in 30:
		shot._physics_process(.0166667)
	expect(hunter.hits==prior+1,"Passing projectile hits once")
	bee.free()
	var guard=spawn(0,0,"normal",3)
	hunter.position=Vector3(0,0,-1.)
	guard.turn(Vector3.FORWARD)
	expect(guard.take_hit(10,Vector3.ZERO)==4,"Guard blocks frontal damage")
	hunter.position=Vector3(0,0,1.)
	expect(guard.take_hit(10,Vector3.ZERO)==10,"Guard exposes its flank")
	guard.free()
	var actor2=spawn(0,0,"mini",0)
	expect(actor2.hp==100 and actor2.power==9 and actor2.visual.animator!=null,"Stag import and base stats")
	var origin:Vector3=actor2.global_position
	actor2.take_hit(5,Vector3.FORWARD*2.)
	expect(actor2.global_position.is_equal_approx(origin),"Boss resists hook")
	hunter.position=Vector3(10.,0,0)
	actor2.begin("antler")
	actor2._physics_process(1./60.)
	expect(zones(actor2).is_empty(),"Refuge cancels attack")
	actor2.global_position=Vector3(5.2,0,0)
	actor2.velocity=Vector3.RIGHT*12.
	actor2.bound_motion(.2)
	expect(actor2.velocity.x<=.001, "Movement cannot cross refuge boundary")
	actor2.free()
	var mud=spawn(3,0,"normal",5)
	mud.take_hit(ceili(mud.max_hp*.53),Vector3.ZERO)
	expect(mud.split and mud.twin!=null and mud.is_in_group("enemies"),"Mud splits and shares one kill")
	mud.free()

func pursuit_check() -> void:
	for rank in 4:
		var enemy=spawn(0,rank,"normal",0)
		var limit:float=[6.,9.,12.1,12.1][rank]
		enemy.position=Vector3.LEFT*.8
		hunter.position=enemy.position+Vector3.FORWARD*(limit+.02)
		enemy.seek()
		expect(enemy.velocity.x>0 and absf(enemy.velocity.z)<.001,"Outside rank %d detection returns home"%rank)
		enemy.position=enemy.home
		hunter.position=enemy.position+Vector3.FORWARD*(limit+.02)
		enemy.velocity=Vector3.ZERO
		enemy.seek()
		expect(enemy.velocity.is_zero_approx() and enemy.visual.pose=="Idle","Distant rank %d foe waits at home"%rank)
		hunter.position=enemy.position+Vector3.FORWARD*(limit-.02)
		enemy.seek()
		expect(enemy.velocity.z<0,"Inside rank %d detection pursues"%rank)
		enemy.free()
	var bee=spawn(0,0,"normal",1)
	hunter.position=Vector3.FORWARD*6.55
	bee.seek()
	expect(bee.velocity.z<0,"Easy wasp can notice a target 0.8m outside its attack range")
	bee.free()
	var guardian=spawn(0,0,"boss",0)
	hunter.position=Vector3.FORWARD*18.8
	guardian.seek()
	expect(guardian.velocity.z<0,"Guardian keeps full pursuit range")
	guardian.free()

func hill_check() -> void:
	var world:=Landscape.new()
	stage.add_child(world)
	world.build(0)
	await physics_frame
	await physics_frame
	var crossing:PackedVector2Array=world.map_data().routes[2]
	var segment:=crossing.size()-2
	var start:=world._floor_point(Landscape.Layout.road_at(crossing,segment,.60))
	var toward:=world._floor_point(Landscape.Layout.road_at(crossing,segment,.80))-start
	var slope_dir:=Vector3(toward.x,0,toward.z).normalized()
	var bee=spawn(0,0,"normal",1)
	bee.global_position=start
	start.y=world.ground_at(start)
	bee.global_position=start
	bee.line(start,slope_dir,6.25,.58,.5,.6,"needle")
	var shot:Node=zones(bee)[0]
	shot.set_physics_process(false)
	var vertices:PackedVector3Array=shot.carpet.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low:=INF
	var high:=-INF
	var worst_error:=0.
	for local in vertices:
		var point:Vector3=shot.to_global(local)
		worst_error=maxf(worst_error,absf(point.y-world.ground_at(point)-.082))
		low=minf(low,point.y)
		high=maxf(high,point.y)
	expect(worst_error<.025 and high-low>.48 and shot.length>6.20,"Warning crosses the slope to its crest")
	for i in range(0,vertices.size(),3):
		var center:Vector3=shot.to_global((vertices[i]+vertices[i+1]+vertices[i+2])/3.)
		expect(center.y>world.ground_at(center)+.025,"Warning triangle stays above terrain between vertices")
	shot._physics_process(.5+.6*.78)
	var bolt:Vector3=shot.item.global_position
	expect(absf(bolt.y-world.ground_at(bolt)-.552)<.03,"Projectile follows the hill under the lane")
	print("uphill mark elevation=",snappedf(high-low,.001)," max_vertex_error=",snappedf(worst_error,.001))
	var bridge=preload("res://scripts/world/height.gd")
	var bridge_center:=world._floor_point(Landscape.Layout.bridge_at(0))
	var bridge_dir:=Vector3.RIGHT.rotated(Vector3.UP,PI*.25+bridge.BRIDGE_YAW)
	bee.line(bridge_center-bridge_dir*2.9,bridge_dir,5.8,.46,.45,.45,"stone")
	var bridge_shot:Node=zones(bee).back()
	var deck_vertices:PackedVector3Array=bridge_shot.carpet.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var deck_count:=0
	for i in range(0,deck_vertices.size(),3):
		var center:Vector3=bridge_shot.to_global((deck_vertices[i]+deck_vertices[i+1]+deck_vertices[i+2])/3.)
		var floor_y:float=world.ground_at(center)
		if floor_y>.12:
			deck_count+=1
		expect(center.y>floor_y+.01,"Bridge deck and ramps keep telegraphs above their walking surface")
	expect(deck_count>=5 and bridge_shot.length>5.6,"Unobstructed cast crosses bridge deck")
	bee.free()
	world.free()

func run() -> void:
	root.add_child(stage)
	hunter.add_to_group("player")
	stage.add_child(hunter)
	hunter.position=Vector3(0,0,-2.)
	await physics_frame
	population()
	invariant_checks()
	pursuit_check()
	await hill_check()
	print("MONSTER_TEST failures=",failed)
	stage.free()
	quit(1 if failed else 0)
