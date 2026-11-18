extends RefCounted
## 지역 좌표는 카메라에 맞춘 지형 축의 미터 단위다.

const BOUNDS := Rect2(-64, -56, 128, 112)
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

var routes: Array[PackedVector2Array] = []
var landmarks: Array[Dictionary] = []
var pockets := PackedVector2Array()
var stream := PackedVector2Array()

func _init(region:int) -> void:
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
	for road in routes:
		for i in road.size()-1:
			var point := road[i]
			if point.distance_to(ENTRY)>5 and not pockets.has(point):
				pockets.append(point)
			pockets.append(road_at(road,i,.5))
	stream = PackedVector2Array([Vector2(-57,60),west[1]+Vector2(-10,5),west[2]+Vector2(-8,4),
		west[2]+Vector2(-5,2),bridge+Vector2(-2,4),bridge,bridge+Vector2(0,-9),
		west[3]+Vector2(-5,-4),west[4]+Vector2(-7,-8),arena+Vector2(-12,-16)])

static func bridge_at(region:int) -> Vector2:
	return WEST[region][2]+Vector2(8,0)

static func road_at(road:PackedVector2Array,index:int,t:float) -> Vector2:
	return road[index].cubic_interpolate(road[index+1],road[maxi(0,index-1)],road[mini(road.size()-1,index+2)],t)
