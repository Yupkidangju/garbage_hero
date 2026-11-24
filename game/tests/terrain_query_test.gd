extends SceneTree
## 최적화 전의 공개 지형 질의와 가벼운 통행 판정의 동치성을 경계에서 검증한다.
const Layout = preload("res://scripts/world/field_layout.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	call_deferred("run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=12: push_error(label)

func original_body_clear(layout:Layout,point:Vector2,radius:float) -> bool:
	if not layout.surface_at(point).walkable: return false
	for i in 8:
		if not layout.surface_at(point+Vector2.from_angle(TAU*i/8)*radius).walkable: return false
	return true

func run() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=309241
	for region in 6:
		var layout:=Layout.new(region)
		for radius:float in [0.,.34,.75,1.35,3.,20.]:
			var points:=PackedVector2Array()
			for i in 256: points.append(Vector2(rng.randf_range(-132,132),rng.randf_range(-116,116)))
			var river:=Layout.deep_rect(region)
			for rect:Rect2 in [Layout.BOUNDS,river]:
				for x:float in [rect.position.x-radius,rect.position.x+radius,rect.end.x-radius,rect.end.x+radius]:
					for y:float in [rect.position.y-radius,rect.position.y+radius,rect.end.y-radius,rect.end.y+radius,rect.get_center().y]:
						for epsilon:float in [-.00001,0.,.00001]: points.append(Vector2(x+epsilon,y+epsilon))
			for crossing in layout.crossings:
				for x:float in [-8.,-5.,0.,5.,8.]:
					for side:float in [-1.,1.]:
						for epsilon:float in [-.00001,0.,.00001]:
							points.append(crossing.pos+Vector2(x,(crossing.half_size.y-radius)*side+epsilon))
			for point in points:
				check(layout.walkable_at(point)==bool(layout.surface_at(point).walkable),"통행 boolean 동치 %d %s"%[region,point])
				check(layout.clear_for_body(point,radius)==original_body_clear(layout,point,radius),"반경9표본 동치 %d %s r%s"%[region,point,radius])
	var sample:=Layout.new(5)
	var point:=Layout.ARENAS[5]+Vector2(.33,.22)
	var start:=Time.get_ticks_usec()
	for i in 5000: original_body_clear(sample,point,1.0)
	var original_us:=Time.get_ticks_usec()-start
	start=Time.get_ticks_usec()
	for i in 5000: sample.clear_for_body(point,1.0)
	var optimized_us:=Time.get_ticks_usec()-start
	print("terrain body query 5000: original_us=%d optimized_us=%d"%[original_us,optimized_us])
	print("terrain queries: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
