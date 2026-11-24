extends RefCounted
## 미채택 진단 후보: 정확히 같은 높이0 평면만 합치고 굽은 면의 1m 삼각형은 보전한다.
const Height = preload("res://scripts/world/height.gd")

static func flat_cell(values:PackedFloat32Array,index:int) -> bool:
	return values[index]==0.0 and values[index+1]==0.0 and values[index+Height.WIDTH]==0.0 and values[index+Height.WIDTH+1]==0.0

static func build(region:int) -> Dictionary:
	var values:=Height.samples(region).heights
	const W:=Height.WIDTH-1
	const D:=Height.DEPTH-1
	var used:=PackedByteArray()
	used.resize(W*D)
	var faces:=PackedVector3Array()
	var flat_rectangles:=0
	for row in D:
		var col:=0
		while col<W:
			var cell:=row*W+col
			if used[cell]:
				col+=1
				continue
			var index:=row*Height.WIDTH+col
			var x:=col-Height.HALF_X
			var z:=row-Height.HALF_Z
			if not flat_cell(values,index):
				var a:=Vector3(x,values[index],z)
				var b:=Vector3(x+1,values[index+1],z)
				var c:=Vector3(x,values[index+Height.WIDTH],z+1)
				var d:=Vector3(x+1,values[index+Height.WIDTH+1],z+1)
				faces.append_array(PackedVector3Array([a,b,c,b,d,c]))
				used[cell]=1
				col+=1
				continue
			var right:=col+1
			while right<W and not used[row*W+right] and flat_cell(values,row*Height.WIDTH+right): right+=1
			var bottom:=row+1
			while bottom<D:
				var available:=true
				for at in range(col,right):
					if used[bottom*W+at] or not flat_cell(values,bottom*Height.WIDTH+at):
						available=false
						break
				if not available: break
				bottom+=1
			for at_row in range(row,bottom):
				for at_col in range(col,right): used[at_row*W+at_col]=1
			var far_x:=right-Height.HALF_X
			var far_z:=bottom-Height.HALF_Z
			var a:=Vector3(x,0,z)
			var b:=Vector3(far_x,0,z)
			var c:=Vector3(x,0,far_z)
			var d:=Vector3(far_x,0,far_z)
			faces.append_array(PackedVector3Array([a,b,c,b,d,c]))
			flat_rectangles+=1
			col=right
	var shape:=ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return {"shape":shape,"triangles":faces.size()/3,"original_triangles":W*D*2,"flat_rectangles":flat_rectangles}

static func install_zero_plane(world) -> Dictionary:
	var values:PackedFloat32Array=Height.samples(int(world.region)).heights
	for height in values: assert(height>=0.0,"zero-plane candidate requires nonnegative terrain")
	var faces:=PackedVector3Array()
	for row in Height.DEPTH-1:
		for col in Height.WIDTH-1:
			var index:=row*Height.WIDTH+col
			if flat_cell(values,index): continue
			var x:=col-Height.HALF_X
			var z:=row-Height.HALF_Z
			var a:=Vector3(x,values[index],z)
			var b:=Vector3(x+1,values[index+1],z)
			var c:=Vector3(x,values[index+Height.WIDTH],z+1)
			var d:=Vector3(x+1,values[index+Height.WIDTH+1],z+1)
			faces.append_array(PackedVector3Array([a,b,c,b,d,c]))
	var shape:=ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var replaced:=false
	for body in world.axes.get_children():
		if body is StaticBody3D and body.get_child_count()==1:
			var collision:=body.get_child(0) as CollisionShape3D
			if collision and collision.shape is ConcavePolygonShape3D and collision.shape.get_faces().size()>1000:
				collision.shape=shape
				replaced=true
				break
	assert(replaced,"original terrain collider found")
	var plane_body:=StaticBody3D.new()
	plane_body.name="ZeroPlaneCandidate"
	plane_body.collision_layer=1
	plane_body.collision_mask=0
	var plane_collision:=CollisionShape3D.new()
	var plane:=WorldBoundaryShape3D.new()
	plane.plane=Plane(Vector3.UP,0)
	plane_collision.shape=plane
	plane_body.add_child(plane_collision)
	world.axes.add_child(plane_body)
	return {"triangles":faces.size()/3,"original_triangles":(Height.WIDTH-1)*(Height.DEPTH-1)*2,"plane_y":0.0}
