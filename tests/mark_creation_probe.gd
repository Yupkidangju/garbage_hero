extends SceneTree
const World=preload("res://scripts/world.gd")
const Enemy=preload("res://scripts/enemy.gd")
const Mark=preload("res://scripts/monster_attack.gd")
var stage:=Node3D.new()
var world:=World.new()
var target:=Node3D.new()
var rows:=[]

func _initialize()->void:
	_run.call_deferred()

func p(values:Array[float],fraction:float)->float:
	values.sort()
	return values[ceili(values.size()*fraction)-1]

func _run()->void:
	Engine.max_fps=0
	root.add_child(stage)
	stage.add_child(world)
	world.build(5)
	target.add_to_group("player")
	stage.add_child(target)
	var actors:=[]
	for kind in ["normal","mini","boss"]:
		for index in (10 if kind=="normal" else (2 if kind=="mini" else 1)):
			var actor:=Enemy.new()
			actor.setup(5,3,kind,index,"profile-%s-%d"%[kind,index])
			actor.set_physics_process(false)
			stage.add_child(actor)
			actor.hero=target
			actors.append(actor)
	await physics_frame
	await physics_frame
	var hill:Vector2=world.Layout.WEST[5][4]
	var sites:={"arena":world.Layout.ARENAS[5],"hill_foot":hill+Vector2(20,0),"hill_center":hill,"riverbank":Vector2(-70,0)}
	for site:String in sites:
		for actor in actors:
			actor.global_position=world._floor_point(sites[site])
			actor.turn(Vector3.FORWARD.rotated(Vector3.UP,.31))
			target.position=actor.position+actor.facing*3.0
			actor.build_sequence()
			var actions:Array=actor.queued.duplicate()
			actor.queued.clear()
			for action:String in actions:
				var times:Array[float]=[]
				var maximum_vertices:=0
				var maximum_marks:=0
				for iteration in 16:
					var start:=Time.get_ticks_usec()
					actor.begin(action)
					var elapsed:float=(Time.get_ticks_usec()-start)/1000.
					var vertices:=0
					var marks:=0
					for child in actor.get_children():
						if child is Mark:
							child.set_physics_process(false)
							if child.carpet.mesh:
								vertices+=child.carpet.mesh.surface_get_array_len(0)
							marks+=1
							child.free()
					if iteration>=2:
						times.append(elapsed)
						maximum_vertices=maxi(maximum_vertices,vertices)
						maximum_marks=maxi(maximum_marks,marks)
				var row:={"site":site,"species":actor.species,"action":action,"samples":times.size(),"median_ms":p(times,.5),"p95_ms":p(times,.95),"max_ms":times.back(),"max_vertices":maximum_vertices,"max_marks":maximum_marks}
				rows.append(row)
	rows.sort_custom(func(a,b):return a.p95_ms>b.p95_ms)
	for row in rows.slice(0,20): print("MARK_CREATION_WORST ",JSON.stringify(row))
	var all:Array[float]=[]
	for row in rows: all.append(row.p95_ms)
	print("MARK_CREATION_SUMMARY ",JSON.stringify({"patterns":rows.size(),"p95_of_cast_p95_ms":p(all,.95),"worst_cast_ms":all.back()}))
	var output_path:=OS.get_environment("GARBAGEHERO_MARK_PROFILE")
	if output_path.is_empty(): output_path=ProjectSettings.globalize_path("res://../tasks/evidence/mark-creation-profile.json")
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	stage.free()
	quit()
