extends RefCounted
## 지역 좌표는 카메라에 맞춘 지형 축의 미터 단위다.

const BOUNDS := Rect2(-128, -112, 256, 224)
const ENTRY := Vector2(0, 48)
const FORK := Vector2(0, 37)
const ARENAS := [Vector2(-2,-45),Vector2(11,-46),Vector2(-11,-45),Vector2(5,-46),Vector2(12,-44),Vector2(-7,-44)]
const WEST := [
	[Vector2(-17,29),Vector2(-34,17),Vector2(-43,4),Vector2(-48,-15),Vector2(-31,-32)],
	[Vector2(-21,32),Vector2(-38,25),Vector2(-49,10),Vector2(-39,-10),Vector2(-26,-37)],
	[Vector2(-10,27),Vector2(-31,22),Vector2(-39,3),Vector2(-51,-14),Vector2(-35,-31)],
	[Vector2(-21,25),Vector2(-43,27),Vector2(-47,7),Vector2(-31,-10),Vector2(-43,-31)],
	[Vector2(-16,25),Vector2(-42,30),Vector2(-48,10),Vector2(-35,-11),Vector2(-31,-33)],
	[Vector2(-20,31),Vector2(-33,15),Vector2(-53,0),Vector2(-44,-20),Vector2(-24,-27)],
]
const EAST := [
	[Vector2(14,29),Vector2(29,18),Vector2(40,4),Vector2(36,-16),Vector2(21,-32)],
	[Vector2(15,23),Vector2(35,14),Vector2(45,0),Vector2(53,-18),Vector2(37,-33)],
	[Vector2(20,29),Vector2(27,13),Vector2(44,1),Vector2(33,-21),Vector2(13,-29)],
	[Vector2(20,33),Vector2(40,21),Vector2(38,2),Vector2(50,-14),Vector2(25,-33)],
	[Vector2(20,35),Vector2(31,18),Vector2(45,7),Vector2(33,-8),Vector2(47,-27)],
	[Vector2(15,26),Vector2(31,22),Vector2(39,0),Vector2(30,-16),Vector2(20,-36)],
]
const CROSSROADS := [Vector2(-3,-4),Vector2(5,17),Vector2(-2,-6),Vector2(-8,14),Vector2(10,-4),Vector2(-4,12)]
const TITLES := [
	["mill","mushrooms","woodcutters","old_oak"],
	["aqueduct","glass_vein","caravan","sundial"],
	["belfry","epitaphs","vigil","mausoleum"],
	["sluice","willow","ferry","lotus_pool"],
	["arch","icefall","trail_camp","summit_cairn"],
	["furnace","basalt","ore_cart","bellows"],
]
const CACHE_SLUGS := ["grotto", "ruin", "lookout"]
const MapText = preload("res://data/map_ko.tres")

var routes: Array[PackedVector2Array] = []
var landmarks: Array[Dictionary] = []
var pockets := PackedVector2Array()
var stream := PackedVector2Array()
var districts: Array[Dictionary] = []
var caches: Array[Dictionary] = []
var waters: Array[Dictionary] = []
var crossings: Array[Dictionary] = []
var sideareas: Array[Dictionary] = []
var area:int

func _init(region:int) -> void:
	area=region
	var west := PackedVector2Array(WEST[region])
	var east := PackedVector2Array(EAST[region])
	var center:Vector2 = CROSSROADS[region]
	var arena:Vector2 = ARENAS[region]
	for branch in [west,east]:
		var road := PackedVector2Array([ENTRY,FORK])
		road.append_array(branch)
		road.append(arena)
		routes.append(road)
	var bridge := bridge_at(region)
	routes.append(PackedVector2Array([west[2],bridge,bridge+Vector2(7,0),center,east[2]]))
	routes.append(PackedVector2Array([west[0],center+Vector2(-8,11),center,center+Vector2(9,-15),east[4]]))
	var anchors := [west[2],east[2],center,west[4]]
	for i in anchors.size():
		var key:String = TITLES[region][i]
		landmarks.append({"id":"%d:%s"%[region,key], "label":"landmark_"+key, "pos":anchors[i]})
	# 기존 중심부의 ID/위치는 남겨 구형 저장의 탐험·바닥 전리품을 보전한다.
	var river := deep_rect(region)
	var ford := Vector2(river.get_center().x, 51.0)
	var long_bridge := Vector2(river.get_center().x, -34.0)
	crossings = [
		{"id":"%d:river_bridge"%region,"kind":"bridge","pos":long_bridge,"half_size":Vector2(8,1.8)},
		{"id":"%d:river_ford"%region,"kind":"ford","pos":ford,"half_size":Vector2(8,2.5)},
	]
	waters = [
		{"id":"%d:river_bank"%region,"kind":"shallow","rect":river.grow(2.2)},
		{"id":"%d:river"%region,"kind":"deep","rect":river},
	]
	if region == 3:
		waters.append({"id":"3:reed_marsh","kind":"swamp","rect":Rect2(60,13,31,19)})
		waters.append({"id":"3:temple_marsh","kind":"swamp","rect":Rect2(85,-83,24,16)})
	var shift := Vector2(float(region-2)*.9, float(region%3-1)*1.6)
	var centers := [Vector2(-101,57),Vector2(88,70),Vector2(-104,-61),Vector2(94,-65),center]
	for i in 5:
		var position:Vector2=centers[i]+(shift if i<4 else Vector2.ZERO)
		districts.append({"id":"%d:district_%d"%[region,i],"pos":position,
			"label":"district_%d_%d"%[region,i],"name":MapText.get_message("district_%d_%d"%[region,i]),
			"bounds":Rect2(position-Vector2(25,21),Vector2(50,42)).intersection(BOUNDS)})
	var grotto:Vector2=districts[2].pos+Vector2(-5,-2)
	var ruin:Vector2=districts[3].pos
	var lookout:Vector2=districts[1].pos
	routes.append(PackedVector2Array([ENTRY,Vector2(-14,76),Vector2(-47,79),ford+Vector2(19,0),ford,
		ford+Vector2(-20,0),districts[0].pos,Vector2(-117,11),Vector2(-121,-77),Vector2(-104,-88),Vector2(-43,-92),arena]))
	routes.append(PackedVector2Array([ENTRY,Vector2(38,82),lookout,Vector2(112,28),ruin,Vector2(68,-91),arena]))
	routes.append(PackedVector2Array([west[3],long_bridge+Vector2(19,0),long_bridge,
		long_bridge+Vector2(-19,0),grotto]))
	routes.append(PackedVector2Array([east[1],Vector2(64,26),lookout]))
	routes.append(PackedVector2Array([east[3],Vector2(68,-36),ruin]))
	landmarks.append({"id":"%d:grotto"%region,"label":"landmark_grotto","pos":grotto})
	for i in 3:
		var p:Vector2=[grotto,ruin,lookout][i]
		var kind:String=CACHE_SLUGS[i]
		var title:=MapText.get_message("cache_%d_%s"%[region,kind])
		sideareas.append({"id":"%d:%s"%[region,kind],"kind":kind,"pos":p,"name":title})
		if i>0:
			var cache_pos:=p+Vector2(4,2)
			routes.append(PackedVector2Array([p,cache_pos]))
			p=cache_pos
		caches.append({"id":"%d:cache_%s"%[region,kind],"pos":p,
			"name":title,"label":"cache_%d_%s"%[region,kind]})
	for road in routes:
		for i in road.size()-1:
			var point := road[i]
			if point.distance_to(ENTRY)>5 and not pockets.has(point):
				pockets.append(point)
			pockets.append(road_at(road,i,.5))
	stream = PackedVector2Array([Vector2(-57,60),west[1]+Vector2(-10,5),west[2]+Vector2(-8,4),
		west[2]+Vector2(-5,2),bridge+Vector2(-2,4),bridge,bridge+Vector2(0,-9),
		west[3]+Vector2(-5,-4),west[4]+Vector2(-7,-8),arena+Vector2(-12,-16)])

static func deep_rect(region:int) -> Rect2:
	return Rect2(-79.0-float(region)*.8,-72,10,136)

static func valid_cache(region:int, id:String) -> bool:
	if region<0 or region>5: return false
	for slug:String in CACHE_SLUGS:
		if id=="%d:cache_%s"%[region,slug]: return true
	return false

func district_at(point:Vector2) -> String:
	var nearest:=INF
	var found:=""
	for district in districts:
		var distance:=point.distance_squared_to(district.pos)
		if distance<nearest:
			nearest=distance
			found=district.id
	return found

func surface_at(point:Vector2) -> Dictionary:
	if not BOUNDS.has_point(point): return {"kind":"boundary","speed":0.0,"walkable":false}
	if area in [0,3,4]:
		var small_bridge:=point-bridge_at(area)
		if absf(small_bridge.x)<2.14 and absf(small_bridge.y)<=.75:
			return {"kind":"bridge","speed":1.0,"walkable":true}
	for crossing in crossings:
		if Rect2(crossing.pos-crossing.half_size,crossing.half_size*2).has_point(point):
			return {"kind":"bridge" if crossing.kind=="bridge" else "shallow",
				"speed":1.0 if crossing.kind=="bridge" else .7,"walkable":true}
	var kind:="ground"
	for water in waters:
		if water.rect.has_point(point): kind=water.kind
	if kind=="ground":
		for i in stream.size()-1:
			if Geometry2D.get_closest_point_to_segment(point,stream[i],stream[i+1]).distance_squared_to(point)<.82*.82:
				kind="shallow"
				break
	return {"kind":kind,"speed":.6 if kind=="swamp" else (.7 if kind=="shallow" else (0.0 if kind=="deep" else 1.0)),"walkable":kind!="deep"}

func clear_for_body(point:Vector2,radius:float) -> bool:
	# 경계/깊은물과 원의 AABB가 떨어져 있으면 기존 아홉 표본은 모두 통행 가능하다.
	# 1cm 여유는 경계의 부동소수점 판정을 조기 경로에서 바꾸지 않기 위해 둔다.
	var needs_samples:=not BOUNDS.grow(-radius-.01).has_point(point)
	if not needs_samples:
		for water in waters:
			if water.kind=="deep" and water.rect.grow(radius+.01).has_point(point):
				needs_samples=true
				break
	if not needs_samples: return true
	if not walkable_at(point): return false
	for i in 8:
		if not walkable_at(point+Vector2.from_angle(TAU*i/8)*radius): return false
	return true

func walkable_at(point:Vector2) -> bool:
	if not BOUNDS.has_point(point): return false
	for crossing in crossings:
		if Rect2(crossing.pos-crossing.half_size,crossing.half_size*2).has_point(point): return true
	for water in waters:
		if water.kind=="deep" and water.rect.has_point(point): return false
	return true

static func bridge_at(region:int) -> Vector2:
	return WEST[region][2]+Vector2(8,0)

static func road_at(road:PackedVector2Array,index:int,t:float) -> Vector2:
	return road[index].cubic_interpolate(road[index+1],road[maxi(0,index-1)],road[mini(road.size()-1,index+2)],t)
