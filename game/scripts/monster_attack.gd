extends Node3D
## 바닥 예고와 실제 판정은 같은 원점, 방향, 폭에서 계산된다.
const Painter = preload("res://scripts/world/scenery_mesh.gd")

var owner_enemy
var shape: String
var style: String
var length: float
var width: float
var angle: float
var windup: float
var active_time: float
var effect: String
var age := 0.0
var next_hit := 0.0
var fired := false
var landed := false
var item: MeshInstance3D
var fixed_tip: Node3D
var carpet := MeshInstance3D.new()
var area_mat := StandardMaterial3D.new()
var stroke_points := PackedVector3Array()
var stroke_colors := PackedColorArray()
var terrain:Node
var flat_surface := false
var floor_offset := 0.0
var sampled_heights := {}
var dry_samples:Dictionary={}
var shoreline:=false
static var projectiles := {}
const FLAT_CACHE_LIMIT:=128
static var flat_geometry:Dictionary={}

func configure(enemy, origin:Vector3, dir:Vector3, form:String, extent:float, breadth:float,
		aperture:float, delay:float, duration:float, theme:String, extra:String="") -> void:
	owner_enemy = enemy
	shape = form
	length = extent
	width = breadth
	angle = aperture
	windup = delay
	active_time = duration
	style = theme
	effect = extra
	top_level = true
	position = origin + Vector3.UP*.074
	rotation.y = atan2(-dir.x,-dir.z)

func _ready() -> void:
	terrain = get_tree().get_first_node_in_group("world")
	if terrain:
		var bounds := Rect2(-length,-length,length*2.0,length*2.0)
		if shape == "lane":
			bounds = Rect2(-width*0.5,-length,width,length)
		flat_surface = terrain.flat_below(global_transform,bounds)
		if terrain.has_method("surface_at"):
			# 바닥이 평평해도 강을 가로지르는 예고는 지형별로 잘라야 한다.
			for row in range(0,ceili(bounds.size.y/1.5)+1):
				for col in range(0,ceili(bounds.size.x/1.5)+1):
					var point:=bounds.position+Vector2(minf(bounds.size.x,col*1.5),minf(bounds.size.y,row*1.5))
					if not dry_at(Vector3(point.x,0,point.y)):
						shoreline=true
						break
				if shoreline: break
		if flat_surface:
			floor_offset = terrain.ground_at(global_position) + .082 - global_position.y
	add_child(carpet)
	carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paint()
	if style in ["wheel","stone","needle","shard","carriage","fork","moth"]:
		item = MeshInstance3D.new()
		item.mesh = projectile_mesh(style)
		item.hide()
		add_child(item)
	elif style in ["pillar","seam","root","wave","splash","hammer","bell"]:
		fixed_tip = Node3D.new()
		add_child(fixed_tip)
		var cluster := MultiMesh.new()
		cluster.transform_format = MultiMesh.TRANSFORM_3D
		cluster.mesh = projectile_mesh(style)
		var points := impact_points()
		if shoreline:
			var dry:=PackedVector3Array()
			for point in points:
				if dry_at(point): dry.append(point)
			points=dry
		cluster.instance_count = points.size()
		for n in points.size():
			var size := .63+.24*fmod(n*.73,1.)
			if style=="pillar" and n==0:
				size=1.35
			cluster.set_instance_transform(n,Transform3D(Basis(Vector3.UP,n*.70).scaled(Vector3.ONE*size),on_ground(points[n])))
		var meshes := MultiMeshInstance3D.new()
		meshes.multimesh = cluster
		fixed_tip.add_child(meshes)
		fixed_tip.hide()

func impact_points() -> PackedVector3Array:
	var points:=PackedVector3Array()
	if shape=="lane":
		var count:=maxi(2,int(length/.78))
		for n in count:
			points.append(Vector3(0,0,-length*(n+.5)/count))
	elif style in ["root","bell","wave"] and length>2.:
		# 뿌리/종의 실제 솟는 지점에도 예고와 똑같은 탈출 틈을 남긴다.
		var count:=ceili(angle*length/1.05)
		for n in count:
			var dir:=Vector3.FORWARD.rotated(Vector3.UP,angle*((n+.5)/count-.5))
			points.append(dir*length*.85)
			if n%2==0:
				points.append(dir*maxf(width+.2,length*.54))
	else:
		points.append(Vector3.ZERO)
		if length>.9:
			for n in 5:
				points.append(Vector3.FORWARD.rotated(Vector3.UP,TAU*n/5.)*length*.65)
	return points

static func projectile_mesh(key:String) -> Mesh:
	if projectiles.has(key):
		return projectiles[key]
	var holder := Node3D.new()
	var g = Painter.new(holder, 220)
	match key:
		"wheel","stone","carriage":
			var r := .58 if key=="wheel" else .36
			if key=="stone":
				g.blob(Vector3.ZERO,Vector3.ONE*r,"a37a55",10)
			else:
				for side:float in [-1.,1.]:
					var hub := Vector3(side*.09,0,0)
					g.ring(hub,Vector3.RIGHT,r,.12,"845136",24)
					g.ring(hub+Vector3.RIGHT*side*.018,Vector3.RIGHT,r,.038,"e4bc79",24)
					for n in 4:
						var spoke := Vector3(0,sin(n*PI/4.)*r*.85,cos(n*PI/4.)*r*.85)
						g.tube(hub-spoke,hub+spoke,.036,.036,"bc8550",6)
				g.tube(Vector3.LEFT*.17,Vector3.RIGHT*.17,.095,.095,"c6b39c",8)
				if key=="carriage":
					g.block(Vector3(0,.55,0),Vector3(.65,.52,.91),"887594")
		"needle","shard","fork","moth":
			var col:String = {"needle":"fcdd85","shard":"93fff3","fork":"ff995c","moth":"ffb9c6"}[key]
			g.tube(Vector3(0,0,.2),Vector3(0,0,-.31),.106,.004,col,5)
			g.tube(Vector3(0,0,.31),Vector3(0,0,.20),.012,.106,"fff2c7",5)
		"pillar","seam","root","wave","splash","hammer","bell":
			var col:String = {"pillar":"9cddcf","seam":"c6f7fa","root":"86603c","wave":"cf9264","splash":"80beab","hammer":"d59668","bell":"dbba7a"}[key]
			for n in 5:
				var a := TAU*n/5.
				var r := .31 if n else .12
				var base := Vector3(cos(a)*r,0,sin(a)*r)
				g.tube(base,base*1.35+Vector3.UP*(.65 if n else .94),.12,.005,col,5)
	g.finish()
	var result:Mesh = holder.get_child(0).mesh
	projectiles[key] = result
	holder.free()
	return result

func on_ground(point:Vector3) -> Vector3:
	if not terrain:
		return point
	if flat_surface:
		point.y = floor_offset
		return point
	var key:=Vector2i(roundi(point.x*32.),roundi(point.z*32.))
	if not sampled_heights.has(key):
		sampled_heights[key]=terrain.ground_at(to_global(point))+.082-global_position.y
	point.y=sampled_heights[key]
	return point

func dry_at(point:Vector3) -> bool:
	if not terrain or not terrain.has_method("surface_at"):
		return true
	var key:=Vector2i(roundi(point.x*64),roundi(point.z*64))
	if not dry_samples.has(key):
		dry_samples[key]=terrain.walkable_at(to_global(point)) if terrain.has_method("walkable_at") else bool(terrain.surface_at(to_global(point)).walkable)
	return dry_samples[key]

func triangle(a:Vector3,b:Vector3,c:Vector3,color:Color) -> void:
	if shoreline and (not dry_at(a) or not dry_at(b) or not dry_at(c) or not dry_at((a+b+c)/3.)):
		return
	stroke_points.append_array(PackedVector3Array([a,b,c]))
	for n in 3: stroke_colors.append(color)

func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color) -> void:
	var cols := 1
	var rows := 1
	if terrain and (not flat_surface or shoreline):
		cols = maxi(1,ceili(maxf(a.distance_to(b),d.distance_to(c))/.48))
		rows = maxi(1,ceili(maxf(a.distance_to(d),b.distance_to(c))/.48))
		# 작은 도형은 기존 격자가 더 싸다. 큰 면만 증명해 지형 조회·분할을 줄인다.
		if not shoreline and cols*rows>=8:
			var lo:=Vector2(minf(minf(a.x,b.x),minf(c.x,d.x)),minf(minf(a.z,b.z),minf(c.z,d.z)))
			var hi:=Vector2(maxf(maxf(a.x,b.x),maxf(c.x,d.x)),maxf(maxf(a.z,b.z),maxf(c.z,d.z)))
			if terrain.flat_below(global_transform,Rect2(lo,hi-lo)):
				cols=1
				rows=1
	var previous := PackedVector3Array()
	previous.resize(cols + 1)
	for y in rows+1:
		var v := float(y)/rows
		var left := a.lerp(d,v)
		var right := b.lerp(c,v)
		var last := Vector3.ZERO
		var prior := Vector3.ZERO
		for x in cols+1:
			var point := on_ground(left.lerp(right,float(x)/cols))
			var above := previous[x]
			if x > 0 and y > 0:
				triangle(prior,above,point,color)
				triangle(prior,point,last,color)
			previous[x] = point
			last = point
			prior = above

func paint() -> void:
	area_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	area_mat.vertex_color_use_as_albedo = true
	area_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	area_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	carpet.material_override=area_mat
	var cache_key:Array=[]
	if flat_surface and not shoreline:
		cache_key=[shape,length,width,angle,effect,floor_offset]
		if flat_geometry.has(cache_key):
			var shared:Mesh=flat_geometry[cache_key]
			flat_geometry.erase(cache_key)
			flat_geometry[cache_key]=shared
			carpet.mesh=shared
			return
	var fill := Color(.95,.29,.11,.22)
	var edge := Color(1.,.58,.26,.87)
	if effect in ["haste","heal"]:
		fill=Color(.23,.78,.60,.19)
		edge=Color(.56,1.,.69,.80)
	if shape=="lane":
		var a := Vector3(-width/2.,0,0); var b := Vector3(width/2.,0,0)
		var c := b+Vector3.FORWARD*length; var d:= a+Vector3.FORWARD*length
		quad(a,b,c,d,fill)
		var side := Vector3.RIGHT*minf(.063,width*.14)
		quad(a,a+side,d+side,d,edge)
		quad(b-side,b,c,c-side,edge)
		for n in maxi(1,int(length/1.15)):
			var mid := Vector3.FORWARD*(.40+n*1.15)
			if -mid.z+.22<=length:
				var dx := minf(width*.33,.24)
				quad(mid-Vector3.RIGHT*dx,mid,mid+Vector3.FORWARD*.20,mid-Vector3.RIGHT*dx+Vector3.FORWARD*.055,edge)
				quad(mid,mid+Vector3.RIGHT*dx,mid+Vector3.RIGHT*dx+Vector3.FORWARD*.055,mid+Vector3.FORWARD*.20,edge)
	else:
		var start := -angle*.5
		var steps := maxi(6,ceili(angle*8.))
		for n in steps:
			var a := Vector3.FORWARD.rotated(Vector3.UP,start+angle*n/steps)
			var b := Vector3.FORWARD.rotated(Vector3.UP,start+angle*(n+1)/steps)
			var inside := width if shape=="arc" else 0.0
			quad(a*inside,a*length,b*length,b*inside,fill)
			quad(a*(length-.065),a*length,b*length,b*(length-.065),edge)
			if inside>0.0:
				quad(a*inside,a*(inside+.055),b*(inside+.055),b*inside,edge)
			if n%3==1:
				quad(a*length*.74,a*length*.91,b*length*.82,b*length*.79,edge)
	var arrays := []
	if stroke_points.is_empty():
		queue_free()
		return
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = stroke_points
	arrays[Mesh.ARRAY_COLOR] = stroke_colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	carpet.mesh = mesh
	if not cache_key.is_empty():
		if flat_geometry.size()>=FLAT_CACHE_LIMIT:
			flat_geometry.erase(flat_geometry.keys()[0])
		flat_geometry[cache_key]=mesh

func contains_point(point:Vector3, fraction_from:=0., fraction_to:=1.) -> bool:
	if terrain and terrain.has_method("surface_at"):
		var walkable:bool=terrain.walkable_at(point) if terrain.has_method("walkable_at") else bool(terrain.surface_at(point).walkable)
		if not walkable: return false
	var offset := to_local(point)
	offset.y = 0.
	if shape=="lane":
		return absf(offset.x)<=width*.5 and -offset.z>=length*fraction_from and -offset.z<=length*fraction_to
	if offset.length()>length or (shape=="arc" and offset.length()<width):
		return false
	return angle>=TAU-.001 or absf(atan2(offset.x,-offset.z))<=angle*.5

func _physics_process(delta:float) -> void:
	if not is_instance_valid(owner_enemy) or owner_enemy.hp<=0:
		queue_free()
		return
	var before := age
	age += delta
	if age < windup:
		var t := age/maxf(.01,windup)
		area_mat.albedo_color = Color(1.,1.,1.,.65+t*.35)
		return
	if not fired:
		fired = true
		if effect in ["haste","heal"]:
			owner_enemy.support(effect)
		if item:
			item.show()
		if fixed_tip:
			fixed_tip.show()
		area_mat.albedo_color = Color(1.,.86,.65,.92)
	var t := clampf((age-windup)/maxf(active_time,.01),0.,1.)
	var last := clampf((before-windup)/maxf(active_time,.01),0.,1.)
	if item:
		item.position = on_ground(Vector3(0,0,-length*t))+Vector3.UP*.47
		if style in ["wheel","stone","carriage"]:
			item.rotation.x = -t*length*2.2
		carpet.visible = t<.16
	if fixed_tip:
		fixed_tip.position.y = -.10+sin(PI*minf(.999,t))*.14
	var hero = owner_enemy.hero
	if not landed and age>=next_hit and is_instance_valid(hero) and not owner_enemy.is_safe(hero.global_position):
		var inside := contains_point(hero.global_position)
		if item:
			inside = contains_point(hero.global_position, maxf(0.,last-.26/maxf(.25,length)),minf(1.,t+.26/maxf(.25,length)))
		if shape=="lane" and effect=="dash":
			inside = inside and owner_enemy.global_position.distance_to(hero.global_position)<=owner_enemy.hit_radius+.84
		if inside and effect not in ["heal","haste"]:
			var hit:bool = hero.take_damage(owner_enemy.power)
			if hit and effect in ["pull","shove"] and hero.has_method("apply_knockback"):
				var dir:Vector3 = hero.global_position-owner_enemy.global_position
				dir.y=0
				hero.apply_knockback(dir.normalized()*(-1.15 if effect=="pull" else 1.1))
			if effect=="pool":
				next_hit=age+.85
			else:
				landed=true
	if t>=1.:
		queue_free()
