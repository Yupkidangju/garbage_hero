extends SceneTree

const Enemy=preload("res://scripts/enemy.gd")
const Mark=preload("res://scripts/monster_attack.gd")
class SampleEnemy extends Enemy:
	var skip_motion:=false
	var skip_marks:=false
	var bounds_us:=0
	var creation_us:=0
	var casts_us:=0
	var pose_us:=0
	func bound_motion(delta:float)->void:
		var start:=Time.get_ticks_usec()
		if not skip_motion: super(delta)
		bounds_us+=Time.get_ticks_usec()-start
	func mark(at:Vector3,dir:Vector3,shape:String,extent:float,breadth:float,angle:float,delay:float,active:float,style:String="",extra:String="")->void:
		var start:=Time.get_ticks_usec()
		if not skip_marks: super(at,dir,shape,extent,breadth,angle,delay,active,style,extra)
		creation_us+=Time.get_ticks_usec()-start
	func begin(action:String)->void:
		var start:=Time.get_ticks_usec()
		super(action)
		casts_us+=Time.get_ticks_usec()-start
	func show_pose(label:String,duration:=0.)->void:
		var start:=Time.get_ticks_usec()
		super(label,duration)
		pose_us+=Time.get_ticks_usec()-start

var main
var actors:Array=[]
var slot:DirAccess
var output:=[]

func _initialize()->void:
	_run.call_deferred()

func percentile(values:Array[float],share:float)->float:
	values.sort()
	return values[ceili(values.size()*share)-1]

func _run()->void:
	slot=DirAccess.create_temp("garbagehero-cpu-probe")
	OS.set_environment("GARBAGEHERO_SAVE_DIR",slot.get_current_dir())
	Engine.max_fps=0
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.session._data.routes[22].cleared=true
	main.session._data.routes[23].phase="boss"
	main.session._data.first_merge=true
	main.session._data.routes[0].cleared=true
	main.session._data.progression=preload("res://data/progression.gd").from_legacy(true,true)
	main.session.act("depart",{"region":5,"difficulty":3})
	main._enter(5,3)
	main.player.position=main.world.boss_point()+Vector3(0,0,2.5)
	main.player.set_physics_process(false)
	main.director.set_physics_process(false)
	main.director.enemy_script=SampleEnemy
	for i in 40:
		var previous=main.director.enemies[i]
		var actor=main.director._spawn("normal",previous.index,previous.spawn_id,previous.position,i)
		previous.free()
		main.director.enemies[i]=actor
		actor.set_physics_process(false)
		actors.append(actor)
	var boss=main.director._spawn("boss",0,"probe-boss",main.world.boss_point(),-1)
	boss.set_physics_process(false)
	actors.append(boss)
	await physics_frame
	await physics_frame
	for mode in ["baseline","no_motion","no_marks","no_motion_or_marks"]:
		main.player.position=main.world.boss_point()+Vector3(0,0,2.5)
		for i in actors.size():
			var actor=actors[i]
			actor.cancel_attacks()
			actor.phase="seek"
			actor.cooldown=.24
			actor.hp=actor.max_hp
			actor.velocity=Vector3.ZERO
			actor.skip_motion="motion" in mode
			actor.skip_marks="marks" in mode
			if i<40:
				var angle:=TAU*(i%20)/20.
				actor.position=main.player.position+Vector3(cos(angle),0,sin(angle))*(3.4+3.*floorf(i/20.))
			else:
				actor.position=main.world.boss_point()
		var frames:Array[float]=[]
		var enemy_us:=0
		var marks_us:=0
		var peak_marks:=0
		var bounds_us:=0
		var casts_us:=0
		var creation_us:=0
		var pose_us:=0
		for tick in 420:
			var start:=Time.get_ticks_usec()
			main.player.hp=main.player.max_hp
			for actor in actors:
				actor.bounds_us=0
				actor.casts_us=0
				actor.creation_us=0
				actor.pose_us=0
				actor.hp=actor.max_hp
				actor._physics_process(1./60.)
			var middle:=Time.get_ticks_usec()
			var count:=0
			for actor in actors:
				for child in actor.get_children():
					if child is Mark:
						child.set_physics_process(false)
						child._physics_process(1./60.)
						count+=1
			var end:=Time.get_ticks_usec()
			if tick>=60:
				frames.append(float(end-start)/1000.)
				enemy_us+=middle-start
				marks_us+=end-middle
				peak_marks=maxi(peak_marks,count)
				for actor in actors:
					bounds_us+=actor.bounds_us
					casts_us+=actor.casts_us
					creation_us+=actor.creation_us
					pose_us+=actor.pose_us
			await process_frame
		var result:={"mode":mode,"ticks":frames.size(),"enemy_avg_ms":enemy_us/360000.,"mark_avg_ms":marks_us/360000.,"bounds_avg_ms":bounds_us/360000.,"casts_avg_ms":casts_us/360000.,"creation_avg_ms":creation_us/360000.,"pose_avg_ms":pose_us/360000.,"median_ms":percentile(frames,.5),"p95_ms":percentile(frames,.95),"peak_marks":peak_marks}
		output.append(result)
		print("ECOLOGY_CPU ",JSON.stringify(result))
	print("ECOLOGY_CPU_PROBE actors=",actors.size()," results=",JSON.stringify(output))
	await main.prepare_shutdown()
	main.free()
	quit()
