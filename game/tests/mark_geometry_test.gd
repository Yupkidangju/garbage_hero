extends SceneTree
const World=preload("res://scripts/world.gd")
const Enemy=preload("res://scripts/enemy.gd")
const Mark=preload("res://scripts/monster_attack.gd")
var stage:=Node3D.new()
var world:=World.new()
var actor:=Enemy.new()
var failed:=0
var checks:=0

func _initialize()->void:
	_run.call_deferred()

func check(condition:bool,label:String)->void:
	checks+=1
	if not condition:
		failed+=1
		push_error(label)

func make(at:Vector3,length:=1.35,angle:=TAU,effect:=""):
	var mark:=Mark.new()
	mark.configure(actor,at,Vector3.FORWARD,"arc",length,.25,angle,.5,.5,"",effect)
	stage.add_child(mark)
	mark.set_physics_process(false)
	return mark

func geometry(mark)->Dictionary:
	var arrays:Array=mark.carpet.mesh.surface_get_arrays(0)
	var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var projected_area:=0.
	var height_error:=0.
	for i in range(0,points.size(),3):
		var a:Vector3=mark.to_global(points[i])
		var b:Vector3=mark.to_global(points[i+1])
		var c:Vector3=mark.to_global(points[i+2])
		projected_area+=absf((b-a).cross(c-a).y)*.5
		for point in [a,b,c]:
			height_error=maxf(height_error,absf(point.y-world.ground_at(point)-.082))
	return {"vertices":points.size(),"area":projected_area,"height_error":height_error}

func _run()->void:
	root.add_child(stage)
	stage.add_child(world)
	world.build(5)
	actor.setup(5,3,"boss",0,"mark-geometry")
	actor.set_physics_process(false)
	stage.add_child(actor)
	await physics_frame
	var flat:=world._floor_point(Vector2(0,-80))
	var first=make(flat)
	var second=make(flat)
	check(first.flat_surface and not first.shoreline,"Flat cache fixture is a proven dry plane")
	check(first.carpet.mesh==second.carpet.mesh,"Repeated flat cast reuses immutable warning geometry")
	check(first.area_mat!=second.area_mat,"Each warning retains its own opacity material")
	first._physics_process(.10)
	second._physics_process(.40)
	check(absf(first.area_mat.albedo_color.a-.72)<.001 and absf(second.area_mat.albedo_color.a-.93)<.001,"One warning clock cannot change another warning's opacity")
	var shifted=make(flat+Vector3.UP*1.25)
	check(shifted.carpet.mesh!=first.carpet.mesh and geometry(shifted).height_error<.001,"Exact floor offset prevents incorrect sharing across cast heights")
	var wider=make(flat,1.55)
	check(wider.carpet.mesh!=first.carpet.mesh and geometry(wider).area>geometry(first).area,"Exact dimensions retain distinct warning coverage")
	var gap=make(flat,1.35,TAU-1.25)
	check(gap.contains_point(flat+Vector3.FORWARD) and not gap.contains_point(flat+Vector3.BACK),"Shared geometry retains the safe ring opening")
	var green=make(flat,1.35,TAU,"heal")
	var colors:PackedColorArray=green.carpet.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(colors[0].g>colors[0].r,"Support warning retains its green fill")
	actor.global_position=world.boss_point()
	actor.hero=Node3D.new()
	stage.add_child(actor.hero)
	actor.hero.position=actor.position+Vector3.FORWARD*3.
	actor.turn(Vector3.FORWARD.rotated(Vector3.UP,.31))
	actor.begin("bellows")
	var total:=0
	var metrics:=[]
	for child in actor.get_children():
		if child is Mark:
			child.set_physics_process(false)
			var view:=geometry(child)
			total+=int(view.vertices)
			metrics.append(view)
			check(view.height_error<.025,"Per-quad proof preserves actual ground projection")
	check(total<=5916,"Furnace ring removes at least half of the baseline 11832 warning vertices")
	check(metrics.size()==2 and absf(metrics[0].area-86.139394182)<.001 and absf(metrics[1].area-92.506673370)<.001,"Coarser flat sectors preserve the original projected warning areas")
	for i in 145:
		var unique=make(flat,1.1+i*.001)
		unique.free()
	check(Mark.flat_geometry.size()<=128,"Continuously varying cast dimensions cannot grow the flat mesh cache without bound")
	print("MARK_GEOMETRY_METRICS ",JSON.stringify(metrics)," total_vertices=",total)
	print("MARK_GEOMETRY_TEST checks=",checks," failures=",failed)
	stage.free()
	quit(1 if failed else 0)
