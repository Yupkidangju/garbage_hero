extends CharacterBody3D

signal defeated(kind:String, spawn_id:String, pos:Vector3)
signal cue(kind:String)

const Book = preload("res://data/monsters.gd")
const Model = preload("res://scripts/monster_model.gd")
const Mark = preload("res://scripts/monster_attack.gd")
const SAFE_RADIUS := 4.0
const NORMAL_PURSUIT := [6.0, 9.0, 12.1, 12.1]
const DASH_ACTIONS := ["charge","charge_short","antler","ice_ram","leap","dive","owl_swoop","bone_pounce","water_skim","hare_skate"]
const GUARDS := ["shield","carapace","shove","sidestep","log_guard","sand_guard","pine_guard","clam_snap","coffin_latch"]

var region := 0
var difficulty := 0
var kind := "normal"
var index := 0
var spawn_id := ""
var hp := 1
var max_hp := 1
var display_name := ""
var hit_radius := .4
var power := 1
var hero:Node3D
var terrain:Node
var species := ""
var behavior := ""
var speed := 2.0
var reach := 2.0
var home := Vector3.ZERO
var facing := Vector3.FORWARD
var visual := Model.new()
var collider := CollisionShape3D.new()
var phase := "seek"
var remaining := .0
var active_duration := .0
var cast_delay := .0
var destination := Vector3.ZERO
var move_style := ""
var dash_speed := 0.0
var recovery := 1.0
var cooldown := .24
var haste := 0.0
var cast_index := 0
var salt := 0
var hurt_pose := .0
var queued: Array[String] = []
var split := false
var twin:Node3D
var mirror:Node3D
var ice_pillar:StaticBody3D
var pillar_ttl := 0.
var stride_blocked := 0.0
var turn_sign := 1.0
var is_elite := false
var support_charges := 3

func setup(area:int, rank:int, category:String, variant:int, id:String) -> void:
	region = clampi(area,0,5)
	difficulty = clampi(rank,0,3)
	kind = category
	index = posmod(variant, Book.NORMAL[region].size() if kind=="normal" else (2 if kind=="mini" else 1))
	spawn_id = id
	var row := Book.species(region,kind,index)
	species = row[0]
	behavior = row[1]
	var level := 1+region*3+difficulty*18
	max_hp = roundi(row[2]*(1.+.05*(level-1)))
	hp = max_hp
	power = roundi(row[3]*(1.+.025*(level-1)))
	speed = row[4]
	reach = row[5]
	hit_radius = row[6]
	display_name = Book.NAMES.get_message(Book.display_key(region,kind,index))
	is_elite = kind=="normal" and bool(get_meta("is_elite",false))
	if is_elite:
		max_hp=roundi(max_hp*1.7)
		hp=max_hp
		power=roundi(power*1.25)
		hit_radius*=1.15
		display_name=Book.NAMES.get_message("ELITE_PREFIX")%display_name
	salt = absi(hash(id))%240
	turn_sign = 1.0 if salt%2 else -1.0

func _ready() -> void:
	if species.is_empty():
		setup(0,0,"normal",0,str(get_instance_id()))
	add_to_group("enemies")
	home = global_position
	terrain = get_tree().get_first_node_in_group("world")
	collision_layer = 4
	collision_mask = 1|2|4
	floor_snap_length = .35
	var shape := CylinderShape3D.new()
	shape.radius = hit_radius
	shape.height = hit_radius*2.1
	collider.shape = shape
	collider.position.y = shape.height/2.
	add_child(collider)
	add_child(visual)
	visual.build(species,region,kind)
	if is_elite:
		visual.mark_elite()
	visual.clock = salt*.088
	visual.play("Idle")
	hero = get_tree().get_first_node_in_group("player") as Node3D

func is_safe(point:Vector3) -> bool:
	if not has_meta("safe_point"):
		return false
	var mark:Vector3 = get_meta("safe_point")
	return Vector2(mark.x-point.x,mark.z-point.z).length_squared()<=SAFE_RADIUS*SAFE_RADIUS

func flat(vector:Vector3) -> Vector3:
	return Vector3(vector.x,0,vector.z)

func turn(dir:Vector3) -> void:
	if dir.length_squared()>.001:
		facing = flat(dir).normalized()
		visual.rotation.y = atan2(-facing.x,-facing.z)
		if twin:
			twin.rotation.y = visual.rotation.y

func _physics_process(delta:float) -> void:
	visual.advance(delta)
	if twin:
		twin.advance(delta)
	if mirror:
		mirror.advance(delta)
	if hp<=0:
		remaining -= delta
		if remaining<=0.0:
			queue_free()
		return
	if not is_instance_valid(hero):
		hero = get_tree().get_first_node_in_group("player") as Node3D
	cooldown = maxf(0.,cooldown-delta)
	haste = maxf(0.,haste-delta)
	hurt_pose = maxf(0.,hurt_pose-delta)
	if ice_pillar:
		pillar_ttl -= delta
		if pillar_ttl<=0.:
			ice_pillar.queue_free()
			ice_pillar = null
	velocity.x=0
	velocity.z=0
	if not is_on_floor():
		velocity.y -= 18.*delta
	else:
		velocity.y = -.1
	if not is_instance_valid(hero) or is_safe(hero.global_position):
		if phase!="seek":
			cancel_attacks()
		var back := flat(home-global_position)
		if back.length()>.45:
			walk(back.normalized()*speed)
		else:
			show_pose("Idle")
	elif phase=="seek":
		seek()
	else:
		update_cast(delta)
	if terrain and terrain.has_method("surface_at"):
		var surface:Dictionary=terrain.movement_surface_at(global_position) if terrain.has_method("movement_surface_at") else terrain.surface_at(global_position)
		velocity.x*=float(surface.speed)
		velocity.z*=float(surface.speed)
	bound_motion(delta)
	var had_motion := Vector2(velocity.x,velocity.z).length()>.2
	var before := global_position
	move_and_slide()
	if had_motion and flat(global_position-before).length()<delta*.16:
		stride_blocked = .7
	else:
		stride_blocked = maxf(0.,stride_blocked-delta)
	if move_style=="ice_ram" and phase=="active" and ice_pillar:
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_collider()==ice_pillar:
				remaining=.0
				recovery=2.05
				ice_pillar.queue_free()
				ice_pillar=null
				break

func bound_motion(delta:float) -> void:
	if delta<=0:
		return
	var motion:=flat(velocity)*delta
	if has_meta("safe_point"):
		var center:Vector3=get_meta("safe_point")
		var from:=flat(global_position-center)
		var closest:=Geometry3D.get_closest_point_to_segment(Vector3.ZERO,from,from+motion) if motion.length_squared()>.000001 else from
		if closest.length()<SAFE_RADIUS+hit_radius and motion.dot(from)<0:
			var normal:=from.normalized()
			var inward:=motion.dot(normal)
			motion-=normal*inward
	if terrain and terrain.has_method("constrain_motion"):
		motion=terrain.constrain_motion(global_position,motion,hit_radius)
	velocity.x=motion.x/delta
	velocity.z=motion.z/delta

func walk(dir:Vector3) -> void:
	velocity.x=dir.x
	velocity.z=dir.z
	turn(dir)
	show_pose("Run")

func show_pose(label:String, duration:=0.) -> void:
	if hurt_pose>0 and kind=="normal" and label in ["Idle","Run"]:
		return
	if visual.pose!=label or label not in ["Idle","Run"]:
		visual.play(label,duration)
		if twin:
			twin.play(label,duration)

func seek() -> void:
	var offset := flat(hero.global_position-global_position)
	var dist := offset.length()
	var pursuit := 19.0
	if kind=="normal":
		pursuit = maxf(NORMAL_PURSUIT[difficulty],reach+.8)
	if dist>pursuit:
		var back := flat(home-global_position)
		if back.length()>.55:
			walk(back.normalized()*speed*.75)
		else:
			show_pose("Idle")
		return
	var dir := offset.normalized()
	if dist<=reach and cooldown<=0.0:
		turn(dir)
		if queued.is_empty():
			build_sequence()
		begin(queued.pop_front())
		return
	if cooldown>0.0 and dist<reach and behavior in ["bite","juke","flank","sidestep"]:
		var move_dir:=dir.rotated(Vector3.UP,turn_sign*PI*.5)
		if behavior=="bite":
			move_dir=-dir
		walk(move_dir*speed*1.1)
		turn(dir)
	elif dist>reach*.88:
		if stride_blocked>0:
			dir=dir.rotated(Vector3.UP,turn_sign*.91)
		walk(dir*speed*(1.45 if haste>0 else 1.0))
	else:
		turn(dir)
		show_pose("Idle")

func build_sequence() -> void:
	match behavior:
		"wheel":
			queued.assign(["wheel","roots"])
		"double_bell":
			queued.assign(["bell_1","bell_2"])
		"double_charge":
			queued.assign(["charge","charge_short"])
		"pincers":
			queued.assign(["claw_l","claw_r"])
		_:
			queued.append(behavior)
	if difficulty>=2 and kind!="normal":
		queued.append("follow")
	cast_index+=1

func update_cast(delta:float) -> void:
	remaining -= delta
	if phase=="windup" and move_style in ["burrow","breach","drop"]:
		var approach:=clampf(1.-remaining/cast_delay,0.,1.)
		var gap:=flat(destination-global_position)
		var travel:=gap/maxf(remaining+delta,.12)
		travel=travel.limit_length(9.)
		velocity.x=travel.x
		velocity.z=travel.z
		if move_style=="burrow":
			visual.position.y=-.85*sin(PI*approach)
		else:
			visual.position.y=(1.05 if move_style=="breach" else 1.50)*sin(PI*approach)
	if phase=="active" and move_style in DASH_ACTIONS:
		velocity.x = facing.x*dash_speed
		velocity.z = facing.z*dash_speed
		if move_style in ["leap","dive","owl_swoop","bone_pounce","water_skim","hare_skate"]:
			var progress:=1.-clampf(remaining/active_duration,0.,1.)
			visual.position.y = .66*sin(progress*PI)
	if remaining>0.0:
		return
	match phase:
		"windup":
			visual.position.y=0
			phase="active"
			remaining = active_duration
			show_pose("Attack",active_duration)
			if kind!="normal":
				cue.emit("warning" if move_style in ["roots","bell_1","bell_2"] else "swing3")
		"active":
			phase="recover"
			remaining = recovery
			visual.position.y = 0
			if mirror:
				mirror.queue_free()
				mirror=null
			show_pose("Recover",recovery)
		"recover":
			phase="seek"
			move_style=""
			cooldown=.78 if kind=="normal" else .55
			if not queued.is_empty():
				cooldown=.1
			show_pose("Idle")

func cancel_attacks() -> void:
	for child in get_children():
		if child is Mark:
			child.queue_free()
			child.set_physics_process(false)
	queued.clear()
	phase="seek"
	move_style=""
	cooldown=.40
	visual.position.y=0
	if mirror:
		mirror.queue_free()
		mirror=null

func mark(at:Vector3,dir:Vector3,shape:String,extent:float,breadth:float,angle:float,
		delay:float,active:float,style:String="",extra:String="") -> void:
	var effect:=Mark.new()
	effect.configure(self,at,dir,shape,extent,breadth,angle,delay,active,style,extra)
	add_child(effect)

func line(at:Vector3,dir:Vector3,dist:float,width:float,delay:float,active:float,style:String="",extra:String="") -> void:
	# 능선을 따라 오르는 사격은 지면 위를 진행하고 벽에만 막힌다.
	if terrain and terrain.has_method("surface_at"):
		var steps:=maxi(1,ceili(dist/.30))
		for step in steps+1:
			var point:=at+dir*dist*step/steps
			var walkable:bool=terrain.walkable_at(point) if terrain.has_method("walkable_at") else bool(terrain.surface_at(point).walkable)
			if not walkable:
				dist=maxf(0.,dist*maxi(0,step-1)/steps)
				break
	var segments:=maxi(1,ceili(dist/1.1)) if terrain else 1
	var start:=ground_point(at)+Vector3.UP*.52
	for n in segments:
		var end:=ground_point(at+dir*dist*(n+1)/segments)+Vector3.UP*.52
		var ray:=PhysicsRayQueryParameters3D.create(start,end,1)
		var wall:=get_world_3d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty():
			dist=minf(dist,flat(wall.position-at).length())
			break
		start=end
	if dist>.08:
		mark(at,dir,"lane",dist,width,TAU,delay,active,style,extra)

func ground_point(point:Vector3) -> Vector3:
	if terrain:
		point.y=terrain.ground_at(point)
	return point

func zone(at:Vector3,dir:Vector3,outer:float,inner:float,arc:float,delay:float,active:float,style:String="",extra:String="") -> void:
	mark(at,dir,"arc" if inner>0. else "circle",outer,inner,arc,delay,active,style,extra)

func begin(action:String) -> void:
	move_style = action
	var origin := global_position
	var target := ground_point(hero.global_position)
	destination = target
	var right := facing.cross(Vector3.UP)
	var delay := .53
	var duration := .17
	recovery = .46
	match action:
		"cone_burst":
			delay=.70; duration=.50; recovery=.68
			for n in 5:
				line(origin,facing.rotated(Vector3.UP,(n-2)*.63),4.05,.47,delay,duration,"needle")
		"branch_shear":
			delay=.62; duration=.42; recovery=.72
			for side:float in [-1.,1.]:
				line(origin-right*side*.48,facing.rotated(Vector3.UP,side*.31),3.0,.66,delay+(side+1.)*.10,.22,"seam")
		"nectar_heal","oasis_heal","heron_heal","snow_heal","ash_heal":
			delay=.80; duration=.38; recovery=1.8
			if support_charges>0:
				zone(origin,facing,3.25,0,TAU,delay,.20,"","heal")
			if action=="nectar_heal":
				line(origin,facing,4.4,.42,delay,duration,"needle")
			elif action=="oasis_heal":
				zone(target,facing,.90,0,TAU,delay,.50,"splash","pool")
			elif action=="heron_heal":
				line(origin,facing,3.5,.65,delay,.21,"","pull")
			elif action=="snow_heal":
				zone(origin,facing,2.5,1.3,PI*1.1,delay,.30,"bell")
			else:
				for side:float in [-1.,1.]:
					line(origin,facing.rotated(Vector3.UP,side*.22),4.2,.42,delay,.48,"fork")
		"log_guard","sand_guard","pine_guard":
			delay=.85; duration=.24; recovery=.95
			if action=="log_guard":
				zone(origin,facing,2.30,0,PI*1.18,delay,duration,"wave","shove")
			elif action=="sand_guard":
				line(origin,facing,3.3,1.25,delay,.55,"stone","shove")
			else:
				zone(origin,facing,2.65,.55,PI*.95,delay,duration,"root")
		"owl_swoop","bone_pounce","water_skim","hare_skate":
			var length:=minf(reach+.5,origin.distance_to(target)+.75)
			delay=.68 if action=="owl_swoop" else (.45 if action=="bone_pounce" else .59)
			duration=maxf(.24,length/(8.5 if action=="water_skim" else 7.2))
			dash_speed=length/duration
			recovery=.85
			line(origin,facing,length,hit_radius*1.7+.33,delay,duration,"","dash")
			if action=="hare_skate":
				zone(origin,facing,.85,0,TAU,delay+.16,1.15,"splash","pool")
			elif action=="owl_swoop":
				zone(target,facing,1.0,.30,TAU,delay+duration,.20,"bell")
		"crosswind":
			delay=.72; duration=.55; recovery=.70
			for side:float in [-1.,1.]:
				line(origin+right*side*.80,facing.rotated(Vector3.UP,-side*.14),5.2,.68,delay,duration,"moth","shove")
		"sand_clock":
			delay=.70; duration=1.25; recovery=.78
			for n in 3:
				zone(target-facing*(n-1)*1.20,facing,.85+n*.14,0,TAU,delay+n*.40,.25,"splash","pool")
		"grave_volley","reed_fan","icicle_fan":
			delay=.69; duration=.66; recovery=.82
			for n in 3:
				var spread:float=.12 if action=="grave_volley" else (.31 if action=="reed_fan" else .43)
				var stagger:float=n*.16 if action=="grave_volley" else (n*.08 if action=="icicle_fan" else 0.)
				line(origin,facing.rotated(Vector3.UP,(n-1)*spread),reach+.45,.45,delay+stagger,.52,"shard" if action=="icicle_fan" else "needle")
		"coffin_latch":
			delay=.96; duration=.36; recovery=1.10
			line(origin,facing,3.0,1.55,delay,duration,"hammer","pull")
		"dirge":
			delay=.78; duration=.24; recovery=.92
			zone(origin,-facing,3.95,1.9,TAU-1.45,delay,duration,"bell")
		"shroud_stitch":
			delay=.80; duration=.58; recovery=.95
			for side:float in [-1.,1.]:
				line(target-right*side*2.2-facing*1.2,(right*side+facing*.55).normalized(),4.6,.55,delay+(side+1.)*.13,.25,"seam","pull")
		"clam_snap":
			delay=.90; duration=.22; recovery=1.15
			zone(origin,facing,2.8,.25,PI*.72,delay,duration,"hammer","pull")
		"snow_cross":
			delay=.88; duration=.44; recovery=.92
			for side:float in [-1.,1.]:
				line(target-right*side*2.0,right*side,4.,.58,delay+(side+1.)*.14,.25,"seam")
		"smelt":
			delay=.78; duration=.42; recovery=.87
			zone(origin,facing,3.8,.45,PI*.55,delay,.28,"splash")
			zone(target+right*.75,facing,.75,0,TAU,delay+.2,1.3,"splash","pool")
		"ember_tail":
			delay=.67; duration=.53; recovery=.80
			line(origin,facing,5.2,.50,delay,duration,"fork")
			zone(target,facing,.85,.15,TAU,delay+.53,.28,"wave")
		"eruption":
			delay=.98; duration=.64; recovery=1.10
			for n in 3:
				zone(origin.lerp(target,(n+1)/3.),facing,.75,0,TAU,delay+n*.22,.24,"pillar")
		"timber_sweep":
			delay=1.05; duration=.68; recovery=1.4
			zone(origin,facing,3.5,.50,PI*1.25,delay,.25,"root","shove")
			for side:float in [-1.,1.]:
				line(origin+right*side*1.8,facing,6.8,.90,delay+.40,.60,"stone")
		"mirage_lanes":
			delay=1.05; duration=1.20; recovery=1.20
			for n in range(-2,3):
				if n==turn_sign: continue
				line(target-facing*3.+right*n*1.30,facing,6.5,.98,delay+absf(n)*.17,.50,"shard")
		"requiem":
			delay=.88; duration=.90; recovery=1.12
			zone(origin,facing,4.9,2.7,TAU-1.4,delay,.25,"bell")
			zone(origin,-facing,2.7,.40,TAU-1.7,delay+.64,.25,"bell")
		"hydra_spit":
			delay=.97; duration=.85; recovery=1.20
			for n in range(-1,2):
				var aim:=facing.rotated(Vector3.UP,n*.30)
				line(origin+right*n*.70,aim,6.0,.65,delay+absf(n)*.17,.55,"moth")
				zone(target+right*n*1.70,facing,.78,0,TAU,delay+.70,1.25,"splash","pool")
		"glacier":
			delay=1.1; duration=.90; recovery=1.30
			for n in 3:
				zone(origin+facing*(1.5+n*1.45),facing,1.25,.15,PI*1.25,delay+n*.24,.24,"pillar","shove")
		"kiln_breath":
			delay=1.07; duration=1.15; recovery=1.35
			zone(origin,facing,6.4,1.0,PI*.45,delay,.45,"wave")
			for side:float in [-1.,1.]:
				line(origin,facing.rotated(Vector3.UP,side*.61),6.2,.9,delay+.62,.47,"fork")
		"bite","flank","juke","haunt","shove","shield","sidestep","carapace","cleave","split","claw_l","claw_r":
			var arc := deg_to_rad(108.)
			var length := reach+.22
			if action=="cleave":
				delay=.92; arc=deg_to_rad(158.)
			elif action in ["claw_l","claw_r"]:
				delay=.32; recovery=.16
			var aim:=facing.rotated(Vector3.UP,.21 if action=="claw_l" else (-.21 if action=="claw_r" else 0.))
			if action=="split" and split:
				for side:float in [-1.,1.]:
					zone(origin+right*side*.46,aim,length,0,arc,delay,duration)
			else:
				zone(origin,aim,length,0,arc,delay,duration,"","shove" if action=="shove" else "")
		"needle","boulder","shards","spines","fork","mirror","wheel":
			var count := 1
			var style := "needle"
			var spread := 0.
			var length:=reach+.62
			var width:=.55
			if action=="wheel":
				delay=.9; duration=.71; recovery=.26; width=1.06; style="wheel"; length=8.0
			elif action=="boulder":
				style="stone"; width=.90; duration=.83
			elif action=="shards":
				style="shard"; count=3; spread=.25; duration=.50
			elif action=="spines":
				count=8; spread=TAU/8.; duration=.50
			elif action=="fork":
				style="fork"; duration=.38; length=3.0
				for side:float in [-1.,1.]:
					line(origin+facing*length,facing.rotated(Vector3.UP,side*.33),3.30,.60,delay+duration,.38,style)
				recovery=.78
			elif action=="mirror":
				style="moth"; duration=.55
				mirror=Model.new()
				add_child(mirror)
				mirror.build(species,region,kind)
				mirror.position=right*1.05
				mirror.scale=Vector3.ONE*.73
				mirror.rotation.y=visual.rotation.y
				line(origin+right*1.05,facing,length,.48,delay+.17,duration,style)
			else:
				duration=.48
			for n in count:
				var dir:=facing.rotated(Vector3.UP,(n-(count-1)*.5)*spread)
				line(origin,dir,length,width,delay,duration,style)
		"antler","ice_ram","charge","charge_short","leap","dive":
			var length:=minf(reach+.6,origin.distance_to(target)+1.1)
			delay=.64 if kind=="normal" else .88
			if action=="charge_short":
				delay=.37
			if action=="ice_ram":
				place_pillar(target+facing*1.05)
			duration=maxf(.25,length/(7.8 if kind=="normal" else 9.0))
			dash_speed=length/duration
			recovery=.65 if kind=="normal" else .92
			line(origin,facing,length,hit_radius*2.+.48,delay,duration,"","dash")
		"pull","thrust","gust":
			var width:=1.5 if action=="gust" else .68
			line(origin,facing,reach+.45,width,delay,duration,"","pull" if action=="pull" else ("shove" if action=="gust" else ""))
		"pound","seismic","haste","heal":
			delay=.68
			if action in ["haste","heal"]:
				zone(origin,facing,3.25,0,TAU,delay,duration,"",action)
				zone(origin,facing,1.44,0,PI*.8,delay,duration)
			else:
				zone(origin,facing,reach+.2,.24 if action=="seismic" else 0.,TAU,delay,duration,"wave")
		"poison","sand","ice","drop","burrow","breach","hammer":
			var rad:=1.15
			if action in ["burrow","breach","hammer"]:
				delay=.88; rad=1.52; recovery=.9
			if action in ["poison","sand","ice"]:
				zone(target,facing,rad,0,TAU,delay,2.55,"splash","pool")
			else:
				zone(target,facing,rad,0,TAU,delay,.32,"hammer" if action=="hammer" else "splash")
			if action in ["burrow","breach"]:
				for n in 3:
					var p:=origin.lerp(target,(n+1)/4.)
					zone(p,facing,.56,0,TAU,delay*(n+1)*.19,.16,"splash")
			elif action=="hammer":
				for side:float in [-1.,1.]:
					zone(target+right*side*2.2,facing,.78,0,TAU,delay*.7,.78,"hammer")
		"roots","bell_1","bell_2","bellows":
			delay=1.2 if action=="roots" else (.65 if action=="bell_1" else .98)
			duration=.3
			recovery=1.4 if action in ["roots","bellows"] else .2
			var gap:=1.25 if action in ["roots","bellows"] else 0.
			var axis:Vector3=-facing.rotated(Vector3.UP,turn_sign*.47)
			zone(origin,axis,5.65 if gap else 4.4,.38 if gap else (.28 if action=="bell_1" else 1.40),TAU-gap,delay,duration,"root" if action=="roots" else "bell")
			if action=="bellows":
				zone(origin,axis,6.55,3.10,TAU-gap,delay+.44,.26,"wave")
		"crystals","carriage","sluice","seams":
			delay=.88; duration=1.45; recovery=.87
			var open:=1 if cast_index%2==1 else -1
			if action=="crystals":
				for n in 3:
					var start:=target+right*(n-1)*1.2-facing*3.2
					var dir:=facing.rotated(Vector3.UP,(1-n)*.22)
					line(start,dir,7.2,.85,delay+n*.37,.24,"pillar")
			elif action=="seams":
				for n in 4:
					var side:float=1. if n%2==0 else -1.
					var start:=target-facing*(2.4-n*1.05)-right*side*2.55
					line(start,(right*side+facing*.32).normalized(),5.4,.70,delay+n*.22,.24,"seam")
			else:
				for n in range(-2,3):
					if n==open:
						continue
					var start:=target-facing*3.6+right*n*1.40
					line(start,facing,8.,1.35,delay,.73 if action=="carriage" else .94,"carriage" if action=="carriage" else "splash")
		"follow":
			delay=.76; duration=.25; recovery=1.15
			zone(target,facing,1.10,0,TAU,delay,duration,"wave")
			if difficulty==3:
				zone(target+right*turn_sign*2.25,facing,.78,0,TAU,delay+.12,.76,"splash","pool")
	phase="windup"
	remaining=delay
	cast_delay=delay
	active_duration=duration
	show_pose("Windup",delay)

func place_pillar(at:Vector3) -> void:
	if ice_pillar:
		ice_pillar.queue_free()
	ice_pillar=StaticBody3D.new()
	ice_pillar.top_level=true
	ice_pillar.position=at
	ice_pillar.collision_layer=1
	ice_pillar.collision_mask=0
	var shape:=CollisionShape3D.new()
	var cylinder:=CylinderShape3D.new()
	cylinder.height=1.25
	cylinder.radius=.38
	shape.shape=cylinder
	shape.position.y=.625
	ice_pillar.add_child(shape)
	var mesh:=MeshInstance3D.new()
	mesh.mesh=Mark.projectile_mesh("pillar")
	mesh.scale=Vector3(1.05,1.60,1.05)
	ice_pillar.add_child(mesh)
	add_child(ice_pillar)
	pillar_ttl=3.8

func support(effect:String) -> void:
	if effect=="heal":
		if support_charges<=0:
			return
		support_charges-=1
	for ally in get_tree().get_nodes_in_group("enemies"):
		if ally==self or ally.hp<=0 or global_position.distance_squared_to(ally.global_position)>10.57:
			continue
		if effect=="heal":
			ally.hp=mini(ally.max_hp,ally.hp+maxi(2,roundi(ally.max_hp*.08)))
		else:
			ally.haste=2.8

func take_hit(amount:int, pull:Vector3=Vector3.ZERO, incoming:Vector3=Vector3.ZERO) -> int:
	if hp<=0 or amount<=0:
		return 0
	var damage:=amount
	if behavior in GUARDS and phase!="recover":
		var toward_source := flat(-incoming)
		if incoming.is_zero_approx() and is_instance_valid(hero):
			toward_source = flat(hero.global_position - global_position)
		if toward_source.normalized().dot(facing)>.57:
			damage=maxi(1,roundi(amount*.36))
			cue.emit("impact")
	var dealt:=mini(hp,damage)
	hp-=dealt
	if hp==0:
		remove_from_group("enemies")
		collision_layer=0
		collision_mask=0
		cancel_attacks()
		remaining=.48
		show_pose("Death",remaining)
		defeated.emit(kind,spawn_id,global_position)
		return dealt
	if kind=="normal" and not pull.is_zero_approx():
		var motion:=flat(pull).limit_length(2.0)
		if terrain and terrain.has_method("constrain_motion"):
			motion=terrain.constrain_motion(global_position,motion,hit_radius)
		if not is_safe(global_position+motion):
			move_and_collide(motion)
	if behavior=="split" and hp*2<=max_hp and not split:
		split=true
		twin=Model.new()
		add_child(twin)
		twin.build(species,region,kind)
		visual.scale=Vector3.ONE*.70
		twin.scale=Vector3.ONE*.70
		visual.position.x=-.40
		twin.position.x=.40
		hit_radius+=.14
		(collider.shape as CylinderShape3D).radius=hit_radius
	if kind=="normal" and phase=="seek":
		hurt_pose=.18
		show_pose("Hit",.18)
	return dealt
