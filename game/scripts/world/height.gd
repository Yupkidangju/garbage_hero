extends RefCounted

const SUMMITS = [.68,.92,.42,.46,.95,.73]
const BRIDGE_ORIGIN:=Vector3(-9.8,0,4.2)
const BRIDGE_YAW:=.17
const BRIDGE_REGIONS:=[0,3,4]
const BRIDGE_HALF_LENGTH:=1.76
const BRIDGE_HALF_WIDTH:=.75
const BRIDGE_RAMP_END:=2.14
const BRIDGE_DECK:=.125

static func walking_surface(p:Vector3,region:int) -> float:
	var ground:=altitude(Vector2(p.x,p.z),region)
	if region not in BRIDGE_REGIONS: return ground
	var deck:=(p-BRIDGE_ORIGIN).rotated(Vector3.UP,-BRIDGE_YAW)
	if absf(deck.z)>BRIDGE_HALF_WIDTH or absf(deck.x)>=BRIDGE_RAMP_END: return ground
	if absf(deck.x)<=BRIDGE_HALF_LENGTH: return BRIDGE_DECK
	var slope:=inverse_lerp(BRIDGE_HALF_LENGTH-.01,BRIDGE_RAMP_END,absf(deck.x))
	return maxf(ground,lerpf(BRIDGE_DECK,-.03,slope))

static func altitude(p:Vector2,region:int) -> float:
	if region<0: return 0.0
	# Godot과 렌더 메시가 같은 대각선으로 나눈 두 삼각형의 실제 면 높이다.
	var base:=p.floor()
	var fraction:=p-base
	var b:=sample_height(base+Vector2.RIGHT,region)
	var c:=sample_height(base+Vector2.DOWN,region)
	if fraction.x+fraction.y<=1.0:
		var a:=sample_height(base,region)
		return a+(b-a)*fraction.x+(c-a)*fraction.y
	var d:=sample_height(base+Vector2.ONE,region)
	return d+(c-d)*(1.0-fraction.x)+(b-d)*(1.0-fraction.y)

static func ridge_center(region:int) -> Vector2:
	return Vector2(6.15+.65*sin(region),-.68+.49*cos(region))

static func is_flat(bounds:Rect2,region:int) -> bool:
	if region < 0:
		return true
	# 높이가 있는 격자점에서 바깥쪽으로 한 셀까지 삼각형 보간의 영향을 받는다.
	var extent := Vector2(5.31,7.36)
	if bounds.intersects(Rect2(ridge_center(region)-extent,extent*2.0),true):
		return false
	var bridge_bounds := Rect2(Vector2(BRIDGE_ORIGIN.x,BRIDGE_ORIGIN.z)-Vector2(2.4,1.2),Vector2(4.8,2.4))
	return region not in BRIDGE_REGIONS or not bounds.intersects(bridge_bounds,true)

static func sample_height(p:Vector2,region:int) -> float:
	var center:=ridge_center(region)
	var offset:=(p-center)/Vector2(4.30,6.35)
	var roll:=maxf(0.0,1.0-offset.length_squared())
	return SUMMITS[region]*roll*roll
