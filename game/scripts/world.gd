extends Node3D

const Painter = preload("res://scripts/world/scenery_mesh.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const Village = preload("res://scripts/world/village.gd")
const Fields = preload("res://scripts/world/fields.gd")
const Height = preload("res://scripts/world/height.gd")
const TOWN_POINTS = {"coach":Vector2(3.6,-1.2),"elder":Vector2(-2.35,-1.6),"shop":Vector2(-6.5,-.1),"chest":Vector2(6.4,2.0),"traveler":Vector2(-5.8,3.6)}
const FIELD_ENTRY = Vector2(0,9.2)
const ARENA = Vector2(0,-8.4)
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
var _map:Dictionary={}

func _ready() -> void:
	add_to_group("world")

func ground_at(world_pos:Vector3) -> float:
	var local:=axes.to_local(world_pos)
	local.y=Height.walking_surface(local,region)
	return axes.to_global(local).y

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
	axes=Node3D.new()
	axes.name="Landscape"
	axes.rotation.y=PI*.25
	add_child(axes)
	lighting()
	var painter:=Painter.new(axes,62403+(region+1)*451,region)
	var landscape:=Terrain.new(painter,region)
	landscape.generate()
	_map={"roads":landscape.road_texture,"road_image":landscape.tracks,"bounds":landscape.bounds,
		"texture_bounds":Terrain.TEXTURE_BOUNDS,"transform":axes.global_transform}
	if region>=0: _map["stream"]=PackedVector2Array(Fields.STREAM)
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
		Fields.new(painter,region,landscape).generate()
		anchors["return"]=_location(FIELD_ENTRY)
		# 일반 등장 지점은 시설과 공터, 귀환 표석 주위의 안전 공간을 비운다.
		for z:float in [7.1,4.4,1.8,-.6,-3.2,-5.8,-8.5,-10.9]:
			for x:float in [-7.4,-4.4,-1.5,1.5,4.4,7.4]:
				var p:=Vector2(x+.28*sin(z+x),z+.19*cos(x*1.7))
				if p.distance_to(FIELD_ENTRY)<6.0 or p.distance_to(ARENA)<2.8:
					continue
				sites.append(_location(p)+Vector3.UP*Height.altitude(p,region))
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
	return Vector3.ZERO if region==-1 else _location(FIELD_ENTRY)

func boss_point() -> Vector3:
	return _location(ARENA)

func spawn_points() -> Array[Vector3]:
	return sites.duplicate()

func service_points() -> Dictionary:
	return anchors.duplicate()

func map_data() -> Dictionary:
	return _map

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
