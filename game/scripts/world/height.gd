extends RefCounted

const Layout = preload("res://scripts/world/field_layout.gd")
const SUMMITS = [2.9,3.6,2.2,1.75,4.9,3.8]
const BRIDGE_YAW:=0.0
const BRIDGE_REGIONS:=[0,3,4]
const BRIDGE_HALF_LENGTH:=1.76
const BRIDGE_HALF_WIDTH:=.75
const BRIDGE_RAMP_END:=2.14
const BRIDGE_DECK:=.125
const HALF_X:=131
const HALF_Z:=115
const WIDTH:=HALF_X*2+1
const DEPTH:=HALF_Z*2+1

class Samples:
	var heights:=PackedFloat32Array()
	# (x,z) 왼쪽 위에 있는 양수 지형 표본의 수. 빈 사각형은 네 번 조회로 판별한다.
	var prefix:=PackedInt32Array()

static var grids:Dictionary[int,Samples]={}

static func samples(region:int) -> Samples:
	if grids.has(region): return grids[region]
	var grid:=Samples.new()
	grid.heights.resize(WIDTH*DEPTH)
	grid.prefix.resize((WIDTH+1)*(DEPTH+1))
	for row in DEPTH:
		var count:=0
		for col in WIDTH:
			var h:=sample_height(Vector2(col-HALF_X,row-HALF_Z),region)
			grid.heights[row*WIDTH+col]=h
			count+=int(h>0)
			grid.prefix[(row+1)*(WIDTH+1)+col+1]=grid.prefix[row*(WIDTH+1)+col+1]+count
	grids[region]=grid
	return grid

static func walking_surface(p:Vector3,region:int) -> float:
	var ground:=altitude(Vector2(p.x,p.z),region)
	if region>=0:
		var long_bridge:=Vector2(Layout.deep_rect(region).get_center().x,-34)
		var delta:=Vector2(p.x,p.z)-long_bridge
		if absf(delta.y)<=1.8 and absf(delta.x)<8.0:
			return maxf(ground,.18*(1.0-smoothstep(6.5,8.0,absf(delta.x))))
	if region not in BRIDGE_REGIONS: return ground
	var bridge := Layout.bridge_at(region)
	var deck:=(p-Vector3(bridge.x,0,bridge.y)).rotated(Vector3.UP,-BRIDGE_YAW)
	if absf(deck.z)>BRIDGE_HALF_WIDTH or absf(deck.x)>=BRIDGE_RAMP_END: return ground
	if absf(deck.x)<=BRIDGE_HALF_LENGTH: return BRIDGE_DECK
	var slope:=inverse_lerp(BRIDGE_HALF_LENGTH-.01,BRIDGE_RAMP_END,absf(deck.x))
	return maxf(ground,lerpf(BRIDGE_DECK,-.03,slope))

static func altitude(p:Vector2,region:int) -> float:
	if region<0: return 0.0
	# Godot과 렌더 메시가 같은 대각선으로 나눈 두 삼각형의 실제 면 높이다.
	var base:=p.floor()
	var fraction:=p-base
	var x:=int(base.x)+HALF_X
	var z:=int(base.y)+HALF_Z
	if x>=0 and x<WIDTH-1 and z>=0 and z<DEPTH-1:
		var grid:=samples(region)
		var i:=z*WIDTH+x
		var right:=grid.heights[i+1]
		var down:=grid.heights[i+WIDTH]
		if fraction.x+fraction.y<=1.0:
			var corner:=grid.heights[i]
			return corner+(right-corner)*fraction.x+(down-corner)*fraction.y
		var far:=grid.heights[i+WIDTH+1]
		return far+(down-far)*(1.0-fraction.x)+(right-far)*(1.0-fraction.y)
	# 필드 경계 밖으로 뻗은 공격의 외부 좌표도 기존 높이 함수로 투영한다.
	var b:=sample_height(base+Vector2.RIGHT,region)
	var c:=sample_height(base+Vector2.DOWN,region)
	if fraction.x+fraction.y<=1.0:
		var a:=sample_height(base,region)
		return a+(b-a)*fraction.x+(c-a)*fraction.y
	var d:=sample_height(base+Vector2.ONE,region)
	return d+(c-d)*(1.0-fraction.x)+(b-d)*(1.0-fraction.y)

static func ridge_center(region:int) -> Vector2:
	return Layout.EAST[region][2]

static func is_flat(bounds:Rect2,region:int) -> bool:
	if region < 0:
		return true
	var bridge_bounds := Rect2(Layout.bridge_at(region)-Vector2(2.4,1.2),Vector2(4.8,2.4))
	if region in BRIDGE_REGIONS and bounds.intersects(bridge_bounds,true): return false
	var river_bridge:=Rect2(Vector2(Layout.deep_rect(region).get_center().x-8,-35.8),Vector2(16,3.6))
	if bounds.intersects(river_bridge,true): return false
	var lo:=Vector2i(bounds.position.floor())+Vector2i(HALF_X,HALF_Z)
	var hi:=Vector2i(bounds.end.ceil())+Vector2i(HALF_X+1,HALF_Z+1)
	if lo.x<0 or lo.y<0 or hi.x>WIDTH or hi.y>DEPTH: return false
	var prefix:=samples(region).prefix
	var top:=lo.y*(WIDTH+1)
	var bottom:=hi.y*(WIDTH+1)
	return prefix[bottom+hi.x]-prefix[top+hi.x]-prefix[bottom+lo.x]+prefix[top+lo.x]==0

static var hill_shapes := {}

static func _hills(region:int) -> Array:
	if not hill_shapes.has(region):
		hill_shapes[region] = [
			Rect2(ridge_center(region),Vector2(23,27)),
			Rect2(Layout.WEST[region][4],Vector2(22,16)),
			Rect2(Layout.CROSSROADS[region]+Vector2(4,4),Vector2(15,19))]
	return hill_shapes[region]

static func sample_height(p:Vector2,region:int) -> float:
	if region<0: return 0.0
	var h := 0.0
	var strength := float(SUMMITS[region])
	for hill:Rect2 in _hills(region):
		var offset := (p-hill.position)/hill.size
		var roll := maxf(0.0,1.0-offset.length_squared())
		h += strength*roll*roll
		strength *= .62
	# 외곽 능선도 같은 표본 함수로 만들어 발·투사체·전리품이 렌더와 갈라지지 않는다.
	for center:Vector2 in [Vector2(-104,-61),Vector2(88,70),Vector2(94,-65),Vector2(-101,57)]:
		var roll:=maxf(0.0,1.0-((p-center)/Vector2(30,32)).length_squared())
		h+=float(SUMMITS[region])*.6*roll*roll
	var river:=Layout.deep_rect(region)
	var nearest:=p.clamp(river.position,river.end)
	var bank:=p.distance_to(nearest)
	h*=smoothstep(2.5,10.5,bank)
	return h
