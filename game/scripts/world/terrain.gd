extends RefCounted

const Painter = preload("res://scripts/world/scenery_mesh.gd")
const GROUND = preload("res://scripts/world/landscape.gdshader")
const WATER = preload("res://scripts/world/water.gdshader")
const CollisionSurface = preload("res://scripts/world/collision_surface.gd")
const HEIGHT = preload("res://scripts/world/height.gd")
const Layout = preload("res://scripts/world/field_layout.gd")
const PALETTES = [
	["84995f","a7b77a","c2c98b","d1b58b","e0c79a","b09c71"],
	["7d995a","9daf6a","c4be81","b8a37b","cfb789","a5996e"],
	["d2aa72","e6c38a","f8dba1","d9a577","e5b789","c7966e"],
	["69766d","879181","a0a892","a59685","b2a393","817c72"],
	["68917b","8da384","b0b89a","a59f79","b7ae85","7d8d72"],
	["c3d8dc","e9ede1","fbf6dd","adbfbe","c7d4cd","a9bbc1"],
	["6e615c","8b7668","b18b70","a07b65","b38c70","796b62"]]
var g:Painter
var colors:Array
var region:int
var tracks:=Image.create_empty(576,576,false,Image.FORMAT_L8)
var road_texture:ImageTexture
var bounds:Rect2
var texture_bounds:=Rect2(-24,-24,48,48)
var layout:Layout

func _init(painter:Painter, area:int) -> void:
	g=painter
	region=area
	colors=PALETTES[region+1]
	if region>=0:
		layout=Layout.new(region)
		texture_bounds=Rect2(-136,-120,272,240)

func ribbon(points:PackedVector2Array,width:float,color:String,y:float,edge_variation:=.06) -> void:
	var left:=PackedVector3Array()
	var right:=PackedVector3Array()
	for i in points.size()-1:
		var a:=points[maxi(0,i-1)]
		var b:=points[i]
		var c:=points[i+1]
		var d:=points[mini(points.size()-1,i+2)]
		var steps:=maxi(2,ceili(b.distance_to(c)/.85))
		for j in steps+int(i==points.size()-2):
			var t:=float(j)/steps
			var s:=b.cubic_interpolate(c,a,d,t)
			var t2:=minf(t+.004,1.0)
			var direction:=b.cubic_interpolate(c,a,d,t2)-b.cubic_interpolate(c,a,d,maxf(t-.004,0.0))
			var normal:=direction.orthogonal().normalized()
			var variance:=1.0+edge_variation*sin(s.x*2.7+s.y)
			var l:=s-normal*width*.5*variance
			var r:=s+normal*width*.5*(2.0-variance)
			left.append(Vector3(l.x,HEIGHT.altitude(l,region)+y,l.y))
			right.append(Vector3(r.x,HEIGHT.altitude(r,region)+y,r.y))
	for i in left.size()-1:
		g.quad(left[i],right[i],right[i+1],left[i+1],Vector3.UP,g.clr(color))

func path(points:PackedVector2Array,width:float) -> void:
	for i in points.size()-1:
		var a:=points[maxi(0,i-1)]
		var b:=points[i]
		var c:=points[i+1]
		var d:=points[mini(points.size()-1,i+2)]
		var steps:=maxi(2,ceili(b.distance_to(c)/.30))
		for j in steps+int(i==points.size()-2):
			var point:=b.cubic_interpolate(c,a,d,float(j)/steps)
			stamp(point,Vector2.ONE*width*.5)

func stamp(at:Vector2,half_size:Vector2) -> void:
	var density:=Vector2(tracks.get_size())/texture_bounds.size
	var center:=(at-texture_bounds.position)*density
	var extent:=half_size*density
	var lo:=Vector2i((center-extent).floor()).clamp(Vector2i.ZERO,Vector2i(575,575))
	var hi:=Vector2i((center+extent).ceil()).clamp(Vector2i.ZERO,Vector2i(575,575))
	for row in range(lo.y,hi.y+1):
		var dy:=(float(row)-center.y)/extent.y
		for col in range(lo.x,hi.x+1):
			var dx:=(float(col)-center.x)/extent.x
			var dist:=dx*dx+dy*dy
			if dist>=1.0: continue
			var amount:=clampf((1.0-sqrt(dist))*.98/.18,0,1)
			if amount>tracks.get_pixel(col,row).r:
				tracks.set_pixel(col,row,Color(amount,amount,amount))

func generate() -> void:
	var plane:=PlaneMesh.new()
	plane.size=Vector2(125,125) if region<0 else Vector2(340,310)
	var material:=ShaderMaterial.new()
	material.shader=GROUND
	material.set_shader_parameter("shade",Color(colors[0]))
	material.set_shader_parameter("light_ink",Color(colors[1]))
	material.set_shader_parameter("grass_tip",Color(colors[2]))
	material.set_shader_parameter("dust",Color(colors[3]))
	material.set_shader_parameter("dust_tip",Color(colors[4]))
	material.set_shader_parameter("biome",region)
	material.set_shader_parameter("track_extent",texture_bounds.size)
	plane.material=material
	var land:=MeshInstance3D.new()
	land.mesh=plane
	land.name="Terrain"
	g.node.add_child(land)
	g.at(Vector3.ZERO)
	if region==-1:
		g.solid(Vector3(0,-.30,0),Vector3(125,.6,125))
	else:
		land.position.y=-.08
		field_surface(material)
	bounds=Rect2(-14,-11,28,22) if region<0 else Layout.BOUNDS
	var xlimit:=bounds.size.x*.5
	var zlimit:=bounds.size.y*.5
	var wall_y:=1.6 if region<0 else 3.0
	var wall_height:=3.3 if region<0 else 6.4
	for side:float in [-1.,1.]:
		g.solid(Vector3(side*(xlimit+.35),wall_y,0),Vector3(.7,wall_height,zlimit*2+1.4))
		g.solid(Vector3(0,wall_y,side*(zlimit+.35)),Vector3(xlimit*2,wall_height,.7))
	distant_ridges()
	g.at(Vector3.ZERO)
	if region==-1:
		village_ground()
	else:
		field_ground()
		waterways()
	tracks.generate_mipmaps()
	road_texture=ImageTexture.create_from_image(tracks)
	material.set_shader_parameter("tracks",road_texture)

func field_surface(material:ShaderMaterial) -> void:
	# 메시와 물리 지형은 같은 1m 격자 표본을 쓴다. 오른쪽 길은 초입과 공터에서 평지로 이어진다.
	const HALF_X:=HEIGHT.HALF_X
	const HALF_Z:=HEIGHT.HALF_Z
	const COUNT:=HEIGHT.WIDTH
	var heights:=HEIGHT.samples(region).heights
	var points:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var indices:=PackedInt32Array()
	for z in range(-HALF_Z,HALF_Z+1):
		for x in range(-HALF_X,HALF_X+1):
			var p:=Vector2(x,z)
			var h:=heights[(z+HALF_Z)*COUNT+x+HALF_X]
			points.append(Vector3(x,h,z))
			var dx:=HEIGHT.sample_height(p+Vector2.RIGHT*.5,region)-HEIGHT.sample_height(p-Vector2.RIGHT*.5,region)
			var dz:=HEIGHT.sample_height(p+Vector2.DOWN*.5,region)-HEIGHT.sample_height(p-Vector2.DOWN*.5,region)
			normals.append(Vector3(-dx,1,-dz).normalized())
			if x<HALF_X and z<HALF_Z:
				var i:=points.size()-1
				indices.append_array(PackedInt32Array([i,i+1,i+COUNT,i+1,i+COUNT+1,i+COUNT]))
	var arrays:Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,material)
	var ground:=MeshInstance3D.new()
	ground.name="WalkableRidge"
	ground.mesh=mesh
	g.node.add_child(ground)
	CollisionSurface.add_to(g.node,mesh,region)

func distant_ridges() -> void:
	var shades:=["849b89","819b8b","bb987a","839691","78998d","8ba8b4","8f7770"]
	var cap_colors:=["d9e3d4","b8c6ad","e2bc89","acb8a8","9fb7a7","eef1e6","bf9279"]
	for i in 24:
		var p:=Vector3(-39+i%12*7.15,0,-24-float(i/12)*5.9+g.rng.randf_range(-1.5,1.5))
		if region>=0:
			p.x*=3.4
			p.z-=103.0
		var h:=g.rng.randf_range(3.4,9.1)+(2.2 if i>=12 else 0.0)
		var r:=g.rng.randf_range(4.5,7.8)
		g.at(p,g.rng.randf()*TAU)
		var top:=Vector3(g.rng.randf_range(-1.2,1.2),h,0)
		var base:=PackedVector3Array()
		var snow:=PackedVector3Array()
		for j in 9:
			var a:=TAU*j/9
			var foot:=Vector3(cos(a)*r*g.rng.randf_range(.88,1.12),-.2,sin(a)*r*.83)
			base.append(foot)
			snow.append(top.lerp(foot,g.rng.randf_range(.17,.43)))
		for j in 9:
			var k:=(j+1)%9
			g.quad(base[j],base[k],snow[k],snow[j],Vector3.UP,g.tint(shades[region+1],1.0+.07*sin(j)))
			g.tri(top,snow[j],snow[k],Vector3.UP,g.tint(cap_colors[region+1],1.0+.045*sin(j)))

func village_ground() -> void:
	stamp(Vector2(0,.60),Vector2(7.7,4.4))
	path(PackedVector2Array([Vector2(-.6,24),Vector2(-.4,7.5),Vector2(.6,3.2),Vector2(0,.3),Vector2(-1.5,-3.8),Vector2(-2,-6.8)]),3.18)
	path(PackedVector2Array([Vector2(-24,4),Vector2(-8,1),Vector2(-5,.3),Vector2(0,0),Vector2(5,-1.2),Vector2(9,-2),Vector2(24,-5.6)]),2.5)
	var center:=Vector3(0,.04,.45)
	# 서로 다른 밝기의 방사형 포석 세 줄과 경계석.
	g.at(Vector3.ZERO)
	g.patch(center.x,center.z,2.61,2.61,"aa987b",.026,32,.004)
	var stones:=["cebb9c","d1bf9c","d8c6a6","c8b89b","d9c4a4","decbac"]
	for row in 3:
		var r0:=.37+row*.70
		var r1:=r0+.676
		var count:=10+row*8
		for i in count:
			var a:=TAU*(i+(.45 if row%2 else .1))/count
			var b:=a+TAU/count-.020/r1
			var v:=Vector3(cos(a),0,sin(a))
			var w:=Vector3(cos(b),0,sin(b))
			g.quad(center+v*r0,center+w*r0,center+w*r1,center+v*r1,Vector3.UP,g.clr(stones[g.rng.randi()%stones.size()]))
	g.ring(center+Vector3.UP*.003,Vector3.UP,2.55,.067,"ecdaa9",40)
	g.ring(center+Vector3.UP*.004,Vector3.UP,1.76,.040,"b29974",32)
	g.patch(center.x,center.z,.40,.40,"9c876c",.048,12,.0)
	for j in 8:
		var a:=TAU*j/8
		var v:=Vector3(cos(a),0,sin(a))
		var w:=Vector3(-v.z,0,v.x)
		var p:=center+Vector3.UP*.014
		g.tri(p-w*.09,p+v*(.94 if j%2==0 else .61),p+v*.17,Vector3.UP,g.clr("a18963"))
		g.tri(p+w*.09,p+v*.17,p+v*(.94 if j%2==0 else .61),Vector3.UP,g.clr("ede0bb"))
	for j in 140:
		var x:=g.rng.randf_range(-10,10)
		var z:=g.rng.randf_range(-4.4,5.3)
		if Vector2(x,z-.45).length()>2.73 and (absf(z+0.13*x)<1.1 or (x*x/51+z*z/13)<.96):
			g.patch(x,z,g.rng.randf_range(.04,.12),.026,"c5ad8c",.039,5,.16)

func field_ground() -> void:
	for i in layout.routes.size():
		path(layout.routes[i],3.6 if i<2 else 2.7)
	stamp(Layout.ENTRY,Vector2(4.0,3.7))
	stamp(Layout.ARENAS[region],Vector2(7,6.4))
	for landmark in layout.landmarks:
		stamp(landmark.pos,Vector2(4.2,3.6))
	for cache in layout.caches:
		stamp(cache.pos,Vector2(4.6,4.2))
	for j in 450:
		var p:=Vector2(g.rng.randf_range(-127,127),g.rng.randf_range(-111,111))
		g.at(Vector3(p.x,0,p.y))
		var s:=g.rng.randf_range(.05,.18)
		g.patch(0,0,s*1.23,s*.55,colors[5],.034,5,.28)

func _water_face(water:Dictionary,color:String,y:float) -> void:
	var rect:Rect2=water.rect
	var holder:=Node3D.new()
	holder.name="Water_"+water.id.replace(":","_")
	holder.set_meta("surface_kind",water.kind)
	g.node.add_child(holder)
	var fluid:=Painter.new(holder,91)
	fluid.opaque.shader=WATER
	fluid.opaque.set_shader_parameter("flow_speed",.25 if water.kind=="swamp" else 1.0)
	fluid.at(Vector3.ZERO)
	for iz in ceili(rect.size.y/2.0):
		for ix in ceili(rect.size.x/2.0):
			var p:=rect.position+Vector2(ix,iz)*2.0
			var q:=p+Vector2(2,2)
			q=q.min(rect.end)
			var a:=Vector3(p.x,HEIGHT.altitude(p,region)+y,p.y)
			var b:=Vector3(q.x,HEIGHT.altitude(Vector2(q.x,p.y),region)+y,p.y)
			var c:=Vector3(q.x,HEIGHT.altitude(q,region)+y,q.y)
			var d:=Vector3(p.x,HEIGHT.altitude(Vector2(p.x,q.y),region)+y,q.y)
			fluid.quad(a,b,c,d,Vector3.UP,fluid.clr(color))
	fluid.finish()
	for part:MeshInstance3D in holder.get_children():
		part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func waterways() -> void:
	for water in layout.waters:
		var color:="607b6a" if water.kind=="swamp" else ("376f79" if water.kind=="deep" else "8bb6a6")
		if region==1: color="507f81" if water.kind=="deep" else "a4ba9d"
		if region==4: color="548caa" if water.kind=="deep" else "b4d9db"
		if region==5: color="466965" if water.kind=="deep" else "b4a27d"
		_water_face(water,color,.052 if water.kind=="deep" else .035)
	var river:=Layout.deep_rect(region)
	g.at(Vector3.ZERO)
	for side:float in [-1.,1.]:
		var x:=river.get_center().x+side*river.size.x*.5
		for j in 68:
			var z:=river.position.y+j*2.0
			g.at(Vector3(x+side*.16,0,z))
			g.patch(0,0,.18,.65,"c1d3be",.065,6,.12)
			if j%3==0:
				g.block(Vector3(side*.6,.10,0),Vector3(.34,.20,.8),colors[5])
	for crossing in layout.crossings:
		var center:Vector2=crossing.pos
		if crossing.kind=="ford":
			for j in 15:
				g.at(Vector3(center.x-7+j,0,center.y+sin(j)*.26))
				g.patch(0,0,.38,.63,"d7ceb0",.061,7,.07)
		else:
			g.at(Vector3(center.x,0,center.y))
			for j in 40:
				var x:=-7.8+j*.4
				var h:=HEIGHT.walking_surface(Vector3(center.x+x,0,center.y),region)
				g.block(Vector3(x,h-.045,0),Vector3(.38,.09,3.6),["ad8d65","c4a678","b89a6c"][j%3])
			for z:float in [-1.72,1.72]:
				for x:float in [-6.,-3.,0.,3.,6.]:
					g.column(x,z,.18,.9,.09,.075,"876b50",6)
				g.tube(Vector3(-6,.96,z),Vector3(6,.96,z),.045,.045,"b7a17b",6)
			# 교량 충돌도 보행면과 동일한 완만한 양쪽 램프를 쓴다.
			var faces:=PackedVector3Array()
			for j in 32:
				var x:=-8+j*.5
				var a:=Vector3(center.x+x,HEIGHT.walking_surface(Vector3(center.x+x,0,center.y),region),center.y-1.8)
				var b:=a+Vector3.BACK*3.6
				var c:=Vector3(center.x+x+.5,HEIGHT.walking_surface(Vector3(center.x+x+.5,0,center.y),region),center.y-1.8)
				faces.append_array(PackedVector3Array([a,c,b,c,c+Vector3.BACK*3.6,b]))
			var bridge_body:=StaticBody3D.new()
			bridge_body.collision_mask=0
			var bridge_shape:=CollisionShape3D.new()
			var triangles:=ConcavePolygonShape3D.new()
			triangles.set_faces(faces)
			bridge_shape.shape=triangles
			bridge_body.add_child(bridge_shape)
			g.node.add_child(bridge_body)
	# 깊은 수역은 통로 스트립을 뺀 실체 충돌체다. 큰 돌진도 물리 벽을 관통하지 않는다.
	var bridge:Dictionary=layout.crossings[0]
	var ford:Dictionary=layout.crossings[1]
	var segments:=[Vector2(river.position.y,bridge.pos.y-bridge.half_size.y),
		Vector2(bridge.pos.y+bridge.half_size.y,ford.pos.y-ford.half_size.y),
		Vector2(ford.pos.y+ford.half_size.y,river.end.y)]
	for span:Vector2 in segments:
		g.at(Vector3.ZERO)
		g.frame=Transform3D.IDENTITY
		g.solid(Vector3(river.get_center().x,.8,(span.x+span.y)*.5),Vector3(river.size.x,2.4,span.y-span.x))
