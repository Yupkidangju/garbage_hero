extends Node3D

const Painter = preload("res://scripts/world/scenery_mesh.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const Village = preload("res://scripts/world/village.gd")
const Fields = preload("res://scripts/world/fields.gd")
const Height = preload("res://scripts/world/height.gd")
const Layout = preload("res://scripts/world/field_layout.gd")
const TOWN_POINTS = {"coach":Vector2(3.6,-1.2),"elder":Vector2(-2.35,-1.6),"shop":Vector2(-6.5,-.1),"chest":Vector2(6.4,2.0),"traveler":Vector2(-5.8,3.6)}
const RADII = {"coach":2.05,"elder":2.35,"shop":2.05,"chest":1.85,"traveler":1.95,"return":2.50}
const SKY = ["bed9cd","b6d5c5","e8d2ad","a9bfbb","b1cabe","c9dde5","cfb3a3"]
const WARM_LIGHT = ["fff5db","fff2d8","ffe7cb","f5eddd","fff1da","ffedda","ffe0ca"]
var region := -1
var axes:Node3D
var traveler:Node3D
var traveler_visible:=false
var materials:Array[ShaderMaterial]=[]
var hero_cache:Node3D
var anchors:Dictionary={}
var sites:Array[Vector3]=[]
var _site_anchors:Array[Vector2]=[]
var _map:Dictionary={}
var _obstacles:Dictionary={}
var _layout:Layout
var _cache_lids:Dictionary={}

func _ready() -> void:
	add_to_group("world")

func ground_at(world_pos:Vector3) -> float:
	var local:=axes.to_local(world_pos)
	local.y=Height.walking_surface(local,region)
	return axes.to_global(local).y

func ground_normal_at(world_pos:Vector3) -> Vector3:
	var dx:=ground_at(world_pos+Vector3.RIGHT*.025)-ground_at(world_pos-Vector3.RIGHT*.025)
	var dz:=ground_at(world_pos+Vector3.BACK*.025)-ground_at(world_pos-Vector3.BACK*.025)
	return Vector3(-dx,.05,-dz).normalized()

func surface_at(world_pos:Vector3) -> Dictionary:
	var result:=movement_surface_at(world_pos)
	result.height=ground_at(world_pos)
	result.normal=ground_normal_at(world_pos)
	return result

func movement_surface_at(world_pos:Vector3) -> Dictionary:
	var local:=axes.to_local(world_pos)
	var result:Dictionary={"kind":"ground","speed":1.0,"walkable":true}
	if region>=0: result=_layout.surface_at(Vector2(local.x,local.z))
	else: result.walkable=_map.bounds.has_point(Vector2(local.x,local.z))
	return result

func walkable_at(world_pos:Vector3) -> bool:
	var local:=axes.to_local(world_pos)
	if region>=0: return _layout.walkable_at(Vector2(local.x,local.z))
	return _map.bounds.has_point(Vector2(local.x,local.z))

func constrain_motion(origin:Vector3,displacement:Vector3,radius:float) -> Vector3:
	var from:=axes.to_local(origin)
	var delta:=axes.global_basis.inverse()*displacement
	var start:=Vector2(from.x,from.z)
	var step:=Vector2(delta.x,delta.z)
	var count:=maxi(1,ceili(step.length()/.20))
	step/=count
	var point:=start
	for i in count:
		if _body_surface_clear(point+step,radius):
			point+=step
		else:
			if _body_surface_clear(point+Vector2(step.x,0),radius): point.x+=step.x
			if _body_surface_clear(point+Vector2(0,step.y),radius): point.y+=step.y
	var adjusted:=axes.global_basis*Vector3(point.x-start.x,delta.y,point.y-start.y)
	return adjusted

func _body_surface_clear(point:Vector2,radius:float) -> bool:
	if region>=0: return _layout.clear_for_body(point,radius)
	return _map.bounds.grow(-radius).has_point(point)

func flat_below(mark: Transform3D, bounds: Rect2) -> bool:
	var transform_to_ground := axes.global_transform.affine_inverse() * mark
	var corners := [bounds.position, Vector2(bounds.end.x,bounds.position.y), bounds.end, Vector2(bounds.position.x,bounds.end.y)]
	var first: Vector3 = transform_to_ground * Vector3(corners[0].x,0,corners[0].y)
	var footprint := Rect2(Vector2(first.x,first.z),Vector2.ZERO)
	for corner: Vector2 in corners:
		var p := transform_to_ground * Vector3(corner.x,0,corner.y)
		footprint = footprint.expand(Vector2(p.x,p.z))
	return Height.is_flat(footprint,region)

func _location(uv:Vector2) -> Vector3:
	return Vector3(uv.x,0,uv.y).rotated(Vector3.UP,PI*.25)

func build(area:int) -> void:
	region=clampi(area,-1,5)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	materials.clear()
	hero_cache=null
	traveler=null
	anchors.clear()
	sites.clear()
	_site_anchors.clear()
	_obstacles.clear()
	_cache_lids.clear()
	_layout=null
	axes=Node3D.new()
	axes.name="Landscape"
	axes.rotation.y=PI*.25
	add_child(axes)
	lighting()
	var painter:=Painter.new(axes,62403+(region+1)*451,region)
	var landscape:=Terrain.new(painter,region)
	landscape.generate()
	_map={"roads":landscape.road_texture,"road_image":landscape.tracks,"bounds":landscape.bounds,
		"texture_bounds":landscape.texture_bounds,"transform":axes.global_transform,"landmarks":[]}
	if region==-1:
		Village.new(painter).build()
		for key:String in TOWN_POINTS:
			anchors[key]=_location(TOWN_POINTS[key])
		traveler=Node3D.new()
		traveler.name="TravelingMerchant"
		axes.add_child(traveler)
		var shopkeeper:=Painter.new(traveler,732)
		Village.new(shopkeeper).build_traveler()
		shopkeeper.finish()
		materials.append(shopkeeper.fade)
		traveler.visible=traveler_visible
	else:
		var fields:=Fields.new(painter,region,landscape)
		fields.generate()
		_cache_lids=fields.cache_lids
		var layout:=landscape.layout
		_layout=layout
		_map.merge({"stream":layout.stream,"routes":layout.routes,"landmarks":layout.landmarks,
			"districts":layout.districts,"caches":layout.caches,"waters":layout.waters,
			"crossings":layout.crossings,"sideareas":layout.sideareas},true)
		anchors["return"]=entry_point()
		_index_obstacles()
		for pocket in layout.pockets:
			for offset:Vector2 in [Vector2.ZERO,Vector2(2.1,.7),Vector2(-2.2,.6),Vector2(.4,-2.4),Vector2(-.5,2.6),Vector2(2.4,2.65),Vector2(-2.1,-2.35)]:
				var p:=pocket+offset
				if p.distance_to(Layout.ENTRY)<7.3 or p.distance_to(Layout.ARENAS[region])<7.0 or not _clear(p): continue
				if region in Height.BRIDGE_REGIONS and p.distance_squared_to(Layout.bridge_at(region))<9: continue
				if not _approach_clear(p,pocket): continue
				sites.append(_floor_point(p))
				_site_anchors.append(pocket)
	painter.finish()
	materials.append(painter.fade)

func lighting() -> void:
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(SKY[region+1])
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d8e5e6" if region!=5 else "e0d6d1")
	env.ambient_light_energy=.70
	env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var sky:=WorldEnvironment.new()
	sky.environment=env
	add_child(sky)
	var sun:=DirectionalLight3D.new()
	sun.name="AfternoonSun"
	sun.light_color=Color(WARM_LIGHT[region+1])
	sun.light_energy=1.16
	sun.shadow_enabled=true
	sun.shadow_opacity=.83
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance=58
	sun.shadow_bias=.045
	sun.shadow_normal_bias=.72
	add_child(sun)
	sun.position=_location(Vector2(-10,-8))+Vector3.UP*17
	sun.look_at_from_position(sun.position,Vector3.ZERO,Vector3.UP)

func entry_point() -> Vector3:
	return Vector3.ZERO if region==-1 else _floor_point(Layout.ENTRY)

func boss_point() -> Vector3:
	return Vector3.ZERO if region<0 else _floor_point(Layout.ARENAS[region])

func spawn_points() -> Array[Vector3]:
	return sites.duplicate()

func service_points() -> Dictionary:
	return anchors.duplicate()

func map_data() -> Dictionary:
	return _map

func district_at(pos:Vector3) -> String:
	if region<0: return ""
	var local:=axes.to_local(pos)
	return _layout.district_at(Vector2(local.x,local.z))

func district_points() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if region<0: return result
	for district in _layout.districts:
		var point:=district.duplicate()
		point.pos=_floor_point(district.pos)
		result.append(point)
	return result

func cache_points() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if region<0: return result
	for cache in _layout.caches:
		var point:=cache.duplicate()
		point.pos=_floor_point(cache.pos)
		point.district=_layout.district_at(cache.pos)
		result.append(point)
	return result

func cache_near(pos:Vector3) -> String:
	if region<0: return ""
	var local:=axes.to_local(pos)
	for cache in _layout.caches:
		if Vector2(local.x,local.z).distance_squared_to(cache.pos)<=4: return cache.id
	return ""

func set_open_caches(ids:Array) -> void:
	for id:String in _cache_lids:
		var lid:Node3D=_cache_lids[id]
		if is_instance_valid(lid): lid.rotation.x=-1.05 if ids.has(id) else 0.0

func landmark_near(pos:Vector3) -> String:
	if region<0: return ""
	var local:=axes.to_local(pos)
	for spot in _map.landmarks:
		if Vector2(local.x,local.z).distance_squared_to(spot.pos)<=4.0*4.0:
			return spot.id
	return ""

func _floor_point(p:Vector2) -> Vector3:
	var local:=Vector3(p.x,0,p.y)
	local.y=Height.walking_surface(local,region)
	return axes.to_global(local)

func _index_obstacles() -> void:
	var inverse:=axes.global_transform.affine_inverse()
	for collider:CollisionShape3D in axes.find_children("*","CollisionShape3D",true,false):
		var box:=collider.shape as BoxShape3D
		if box==null or box.size.y<.45 or maxf(box.size.x,box.size.z)>20: continue
		var pose:=inverse*collider.global_transform
		var half:=box.size*.5
		var a:=pose.basis.x*half.x
		var b:=pose.basis.z*half.z
		var extent:=Vector2(absf(a.x)+absf(b.x),absf(a.z)+absf(b.z))+Vector2.ONE*.72
		var bounds:=Rect2(Vector2(pose.origin.x,pose.origin.z)-extent,extent*2)
		var lo:=Vector2i((bounds.position/8).floor())
		var hi:=Vector2i((bounds.end/8).floor())
		for z in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				var cell:=Vector2i(x,z)
				if not _obstacles.has(cell): _obstacles[cell]=[]
				_obstacles[cell].append(bounds)

func _clear(pos:Vector2) -> bool:
	if region>=0 and not _layout.clear_for_body(pos,.74): return false
	for bounds:Rect2 in _obstacles.get(Vector2i((pos/8).floor()),[]):
		if bounds.has_point(pos): return false
	return true

func _approach_clear(point:Vector2,anchor:Vector2) -> bool:
	var steps:=maxi(1,ceili(point.distance_to(anchor)/.35))
	for i in steps+1:
		var p:=point.lerp(anchor,float(i)/steps)
		if not _clear(p): return false
		if region in Height.BRIDGE_REGIONS and p.distance_squared_to(Layout.bridge_at(region))<9: return false
	return true

func drop_point(old_position:Vector3) -> Vector3:
	var local:=axes.to_local(old_position)
	var inner:Rect2=_map.bounds.grow(-1)
	var point:=Vector2(local.x,local.z).clamp(inner.position,inner.end)
	if _clear(point): return _floor_point(point)
	for step in range(1,32):
		for i in 12:
			var p:=point+Vector2.from_angle(i*TAU/12)*(.75*step)
			if inner.has_point(p) and _clear(p): return _floor_point(p)
	return entry_point()

func service_near(pos:Vector3) -> String:
	var best:=""
	var nearest:=INF
	for service:String in anchors:
		if service=="traveler" and not traveler_visible: continue
		var anchor:Vector3=anchors[service]
		var d:=Vector2(pos.x-anchor.x,pos.z-anchor.z).length()
		if d<=float(RADII[service]) and d<nearest:
			best=service
			nearest=d
	return best

func set_traveler_visible(value:bool) -> void:
	traveler_visible=value
	if is_instance_valid(traveler): traveler.visible=value

func _process(_delta:float) -> void:
	if not is_instance_valid(hero_cache):
		hero_cache=get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(hero_cache):
		for mat in materials:
			mat.set_shader_parameter("hero",hero_cache.global_position)
