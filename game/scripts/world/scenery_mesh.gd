extends RefCounted
## 정적 소품의 면을 공간 셀로 묶어 그림자와 컬링 단위를 공유한다.

const PAINT = preload("res://scripts/world/painted.gdshader")
const CONTACT = preload("res://scripts/world/contact.gdshader")
const HEIGHT = preload("res://scripts/world/height.gd")

class Batch:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

var node: Node3D
var rng := RandomNumberGenerator.new()
var batches: Dictionary = {}
var pigment: Dictionary = {}
var opaque := ShaderMaterial.new()
var fade := ShaderMaterial.new()
var contact := ShaderMaterial.new()
var frame := Transform3D.IDENTITY
var occludes := false
var cell := Vector2i.ZERO
var area: int

func _init(parent: Node3D, seed_value: int,region:=-1) -> void:
	node = parent
	area=region
	rng.seed = seed_value
	opaque.shader = PAINT
	fade.shader = PAINT
	fade.set_shader_parameter("occluding", true)
	contact.shader=CONTACT
	contact.render_priority=-10

func at(pos: Vector3, yaw := 0.0, size := 1.0, can_occlude := false) -> void:
	pos.y+=HEIGHT.altitude(Vector2(pos.x,pos.z),area)
	frame = Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),pos)
	occludes = can_occlude
	cell = Vector2i(floori(pos.x/9.0),floori(pos.z/9.0))

func clr(value: String) -> Color:
	if not pigment.has(value):
		pigment[value] = Color(value)
	return pigment[value]

func tint(value: String, factor: float) -> Color:
	var c := clr(value)
	return Color(clampf(c.r*factor,0,1),clampf(c.g*factor,0,1),clampf(c.b*factor,0,1))

# Godot은 카메라에서 봤을 때 시계 방향인 삼각형을 앞면으로 쓴다.
func tri(a: Vector3,b: Vector3,c: Vector3, wanted: Vector3, color: Color) -> void:
	var key := Vector3i(cell.x,cell.y,int(occludes))
	if not batches.has(key):
		batches[key] = Batch.new()
	var batch: Batch = batches[key]
	var n := (b-a).cross(c-a).normalized()
	if n.length_squared() < 0.4:
		return
	if n.dot(wanted) < 0.0:
		n = -n
	else:
		var swap := c
		c = b
		b = swap
	n = (frame.basis*n).normalized()
	for v in [a,b,c]:
		batch.vertices.append(frame*v)
		batch.normals.append(n)
		batch.colors.append(color)

func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3,color: Color) -> void:
	tri(a,b,c,normal,color)
	tri(a,c,d,normal,color)

func block(p: Vector3,s: Vector3,col: String, tilt := Vector3.ZERO) -> void:
	var basis := Basis.from_euler(tilt)
	var a := basis.x*s.x*0.5
	var b := basis.y*s.y*0.5
	var c := basis.z*s.z*0.5
	var color := clr(col)
	quad(p-a+b-c,p+a+b-c,p+a+b+c,p-a+b+c,b,color)
	quad(p-a-b+c,p+a-b+c,p+a+b+c,p-a+b+c,c,color)
	quad(p+a-b-c,p-a-b-c,p-a+b-c,p+a+b-c,-c,color)
	quad(p-a-b-c,p-a-b+c,p-a+b+c,p-a+b-c,-a,color)
	quad(p+a-b+c,p+a-b-c,p+a+b-c,p+a+b+c,a,color)
	quad(p-a-b-c,p+a-b-c,p+a-b+c,p-a-b+c,-b,color)

func tube(a: Vector3,b: Vector3,r0: float,r1: float, col: String,sides := 8, variegation := 0.0) -> void:
	var up := (b-a).normalized()
	var ref := Vector3.UP if absf(up.y)<0.85 else Vector3.FORWARD
	var right := up.cross(ref).normalized()
	var front := up.cross(right)
	var base := clr(col)
	for i in sides:
		var th := TAU*i/sides
		var next := TAU*(i+1)/sides
		var d := right*cos(th)+front*sin(th)
		var e := right*cos(next)+front*sin(next)
		var paint := tint(col,1.0+variegation*sin(i*4.17))
		quad(a+d*r0,a+e*r0,b+e*r1,b+d*r1,d+e,paint)
		if r0>0:
			tri(a,a+d*r0,a+e*r0,-up,base)
		if r1>0:
			tri(b,b+e*r1,b+d*r1,up,base)

func column(x: float,z: float,y: float,h: float,r0: float,r1: float,color:String,sides := 8) -> void:
	tube(Vector3(x,y,z),Vector3(x,y+h,z),r0,r1,color,sides)

func blob(p:Vector3,sc:Vector3,col:String,sides := 8, irregular := 0.07) -> void:
	var rows: Array = []
	var rotation := rng.randf()*TAU
	for band in 3:
		var h:float = [-0.65,0.05,0.67][band]
		var ring := PackedVector3Array()
		for i in sides:
			var angle := TAU*(i+float(band%2)*0.32)/sides+rotation
			var r := sqrt(1-h*h)*rng.randf_range(1.0-irregular,1.0+irregular)
			ring.append(p+Vector3(cos(angle)*r,h+rng.randf_range(-irregular,irregular),sin(angle)*r)*sc)
		rows.append(ring)
	for i in sides:
		var j := (i+1)%sides
		var c := tint(col,rng.randf_range(0.95,1.045))
		tri(p-Vector3.UP*sc.y,rows[0][i],rows[0][j],rows[0][i]-p,c)
		for band in 2:
			quad(rows[band][i],rows[band][j],rows[band+1][j],rows[band+1][i],rows[band][i]+rows[band+1][j]-p*2,c)
		tri(rows[2][i],rows[2][j],p+Vector3.UP*sc.y,Vector3.UP,c)

func ring(center:Vector3, normal:Vector3, radius:float, width:float,color:String, sides:=16) -> void:
	var ref := Vector3.UP if absf(normal.y)<0.85 else Vector3.RIGHT
	var rx := normal.cross(ref).normalized()
	var ry := normal.cross(rx).normalized()
	for i in sides:
		var angle := TAU*i/sides
		var next := TAU*(i+1)/sides
		var d := rx*cos(angle)+ry*sin(angle)
		var e := rx*cos(next)+ry*sin(next)
		quad(center+d*(radius-width),center+d*radius,center+e*radius,center+e*(radius-width),normal,clr(color))

func patch(x:float,z:float,rx:float,rz:float,color:String,y:=0.012,sides:=14,uneven:=0.08) -> void:
	var center := Vector3(x,y,z)
	var points := PackedVector3Array()
	for i in sides:
		var a := TAU*i/sides
		var dev := rng.randf_range(1.0-uneven,1.0+uneven)
		points.append(center + Vector3(cos(a)*rx,0,sin(a)*rz)*dev)
	for i in sides:
		tri(center,points[i],points[(i+1)%sides],Vector3.UP,clr(color))

func solid(p:Vector3,s:Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = Transform3D(frame.basis.orthonormalized(),frame*p)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = s*frame.basis.get_scale().abs()
	collider.shape = shape
	body.add_child(collider)
	node.add_child(body)

func shadow(x:float,z:float,rx:float,rz:float,power:=.25) -> void:
	var key:=Vector3i(cell.x,cell.y,2)
	if not batches.has(key):
		batches[key]=Batch.new()
	var batch:Batch=batches[key]
	var center:=Vector3(x,.056/frame.basis.get_scale().y,z)
	for i in 12:
		var a:=TAU*i/12
		var b:=TAU*(i+1)/12
		var da:=Vector3(cos(a)*rx,0,sin(a)*rz)
		var db:=Vector3(cos(b)*rx,0,sin(b)*rz)
		for offset:Vector3 in [Vector3.ZERO,da*.52,db*.52,da*.52,da,db,da*.52,db,db*.52]:
			var norm:=Vector2(offset.x/rx,offset.z/rz).length()
			var alpha:=power*(1.0-smoothstep(.05,1.0,norm))
			batch.vertices.append(frame*(center+offset))
			batch.normals.append(Vector3.UP)
			batch.colors.append(Color(1,1,1,alpha))

func finish() -> void:
	for key:Vector3i in batches:
		var b:Batch = batches[key]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=b.vertices
		arrays[Mesh.ARRAY_NORMAL]=b.normals
		arrays[Mesh.ARRAY_COLOR]=b.colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,[opaque,fade,contact][key.z])
		var part := MeshInstance3D.new()
		part.mesh=mesh
		if key.z==2: part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.name="Paint_%s_%s_%s" % [key.x,key.y,key.z]
		node.add_child(part)
	batches.clear()
