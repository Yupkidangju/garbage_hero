extends RefCounted
## 비음수 높이의 최상단 면을 보전하면서 평지 내부 삼각형 접촉을 없앤다.
const Height = preload("res://scripts/world/height.gd")

static func add_to(parent:Node3D,mesh:ArrayMesh,region:int) -> void:
	var values:=Height.samples(region).heights
	for height in values:
		if height<0.0:
			# 이후 음수 지형이 도입되면 기존 메시의 전체 충돌면을 그대로 쓴다.
			add_body(parent,mesh.create_trimesh_shape(),"TerrainCollision")
			return
	var faces:=PackedVector3Array()
	for row in Height.DEPTH-1:
		for col in Height.WIDTH-1:
			var index:=row*Height.WIDTH+col
			if values[index]==0.0 and values[index+1]==0.0 and values[index+Height.WIDTH]==0.0 and values[index+Height.WIDTH+1]==0.0: continue
			var x:=col-Height.HALF_X
			var z:=row-Height.HALF_Z
			var a:=Vector3(x,values[index],z)
			var b:=Vector3(x+1,values[index+1],z)
			var c:=Vector3(x,values[index+Height.WIDTH],z+1)
			var d:=Vector3(x+1,values[index+Height.WIDTH+1],z+1)
			faces.append_array(PackedVector3Array([a,b,c,b,d,c]))
	if not faces.is_empty():
		var slope:=ConcavePolygonShape3D.new()
		slope.set_faces(faces)
		add_body(parent,slope,"SlopingTerrainCollision")
	var level:=WorldBoundaryShape3D.new()
	level.plane=Plane(Vector3.UP,0.0)
	add_body(parent,level,"LevelTerrainCollision")

static func add_body(parent:Node3D,shape:Shape3D,label:String) -> void:
	var body:=StaticBody3D.new()
	body.name=label
	body.collision_layer=1
	body.collision_mask=0
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	body.add_child(collision)
	parent.add_child(body)
