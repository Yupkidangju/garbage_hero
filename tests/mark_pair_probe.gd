extends SceneTree
const World=preload("res://scripts/world.gd")
const Enemy=preload("res://scripts/enemy.gd")
const Mark=preload("res://scripts/monster_attack.gd")

class OriginalMark extends Mark:
	var original_flat:=false
	func paint()->void:
		original_flat=flat_surface
		flat_surface=false
		super.paint()
		flat_surface=original_flat
	func on_ground(point:Vector3)->Vector3:
		if not terrain:
			return point
		if original_flat:
			point.y=floor_offset
			return point
		var key:=Vector2i(roundi(point.x*32.),roundi(point.z*32.))
		if not sampled_heights.has(key):
			sampled_heights[key]=terrain.ground_at(to_global(point))+.082-global_position.y
		point.y=sampled_heights[key]
		return point
	func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color)->void:
		var cols:=1
		var rows:=1
		if terrain and (not original_flat or shoreline):
			cols=maxi(1,ceili(maxf(a.distance_to(b),d.distance_to(c))/.48))
			rows=maxi(1,ceili(maxf(a.distance_to(d),b.distance_to(c))/.48))
		var previous:=PackedVector3Array()
		previous.resize(cols+1)
		for y in rows+1:
			var v:=float(y)/rows
			var left:=a.lerp(d,v)
			var right:=b.lerp(c,v)
			var last:=Vector3.ZERO
			var prior:=Vector3.ZERO
			for x in cols+1:
				var point:=on_ground(left.lerp(right,float(x)/cols))
				var above:=previous[x]
				if x>0 and y>0:
					triangle(prior,above,point,color)
					triangle(prior,point,last,color)
				previous[x]=point
				last=point
				prior=above

class SampleEnemy extends Enemy:
	var original:=false
	func mark(at:Vector3,dir:Vector3,form:String,extent:float,breadth:float,aperture:float,delay:float,active:float,theme:String="",extra:String="")->void:
		var effect=OriginalMark.new() if original else Mark.new()
		effect.configure(self,at,dir,form,extent,breadth,aperture,delay,active,theme,extra)
		add_child(effect)

var stage:=Node3D.new()
var world:=World.new()
var target:=Node3D.new()
var rows:=[]

func _initialize()->void:
	_run.call_deferred()

func percentile(values:Array[float],fraction:float)->float:
	values.sort()
	return values[ceili(values.size()*fraction)-1]

func measure(actor,site:String,action:String)->void:
	var before:Array[float]=[]
	var after:Array[float]=[]
	var counts:={true:0,false:0}
	for iteration in 48:
		for original in ([true,false] if iteration%2==0 else [false,true]):
			actor.original=original
			var start:=Time.get_ticks_usec()
			actor.begin(action)
			var elapsed:float=(Time.get_ticks_usec()-start)/1000.
			var vertices:=0
			for child in actor.get_children():
				if child is Mark:
					child.set_physics_process(false)
					if child.carpet.mesh: vertices+=child.carpet.mesh.surface_get_array_len(0)
					child.free()
			if iteration>=6:
				if original: before.append(elapsed)
				else: after.append(elapsed)
				counts[original]=maxi(counts[original],vertices)
	rows.append({"site":site,"species":actor.species,"action":action,"samples":before.size(),"before_median_ms":percentile(before,.5),"before_p95_ms":percentile(before,.95),"after_median_ms":percentile(after,.5),"after_p95_ms":percentile(after,.95),"before_vertices":counts[true],"after_vertices":counts[false]})

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
			var actor:=SampleEnemy.new()
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
			for action:String in actions: measure(actor,site,action)
	rows.sort_custom(func(a,b):return a.after_p95_ms>b.after_p95_ms)
	for row in rows.slice(0,18): print("MARK_PAIR_WORST ",JSON.stringify(row))
	var path:=ProjectSettings.globalize_path("res://../tasks/evidence/mark-creation-paired.json")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	print("MARK_PAIR_COMPLETE patterns=",rows.size())
	stage.free()
	quit()
