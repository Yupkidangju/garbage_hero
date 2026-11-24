extends "res://scripts/world/props.gd"

const Terrain = preload("res://scripts/world/terrain.gd")
const HeightMap = preload("res://scripts/world/height.gd")
const Layout = preload("res://scripts/world/field_layout.gd")
const FOREST := ["508358","719555","91ac67","a8b572"]
const SWAMP := ["4b7766","5f8973","84a77a","9caf82"]
const AUTUMN := ["946f51","ad875c","c3a16e","d1ac72"]
const ROCKS := ["89917a","c2916c","8a8c8d","71897e","8dabad","695956"]
var area:int
var terrain:Terrain
var cache_lids:Dictionary={}

func _init(painter:Painter,id:int,ground:Terrain) -> void:
	super(painter)
	area=id
	terrain=ground

func rocks(pos:Vector3,sc:float,color:String,count:=4) -> void:
	g.at(pos,g.rng.randf()*TAU,sc,true)
	g.shadow(0,.06,1.13,.91,.24)
	for i in count:
		var r:=g.rng.randf_range(.23,.75)
		var x:=g.rng.randf_range(-.78,.78)
		var z:=g.rng.randf_range(-.55,.55)
		g.blob(Vector3(x,r*.36,z),Vector3(r*1.26,r*.72,r),color,6,.15)

func crystal(pos:Vector3,sc:float,colors:Array) -> void:
	g.at(pos,g.rng.randf()*TAU,sc,true)
	g.shadow(0,0,.80,.70,.28)
	for j in 5:
		var a:=TAU*j/5
		var bottom:=Vector3(cos(a)*.35,0,sin(a)*.32)
		var r:=g.rng.randf_range(.12,.32)
		var mid:=bottom+Vector3(cos(a)*.19,g.rng.randf_range(.58,1.52),sin(a)*.21)
		g.tube(bottom,mid,r*.85,r,colors[j%colors.size()],5,.12)
		g.tube(mid,mid+Vector3(cos(a)*.11,r*1.83,sin(a)*.11),r,0,colors[(j+1)%colors.size()],5)

func fungus(pos:Vector3,sc:float) -> void:
	g.at(pos,g.rng.randf()*TAU,sc,true)
	g.shadow(0,0,.86,.81,.25)
	for j in 4:
		var x:=cos(TAU*j/4)*.50
		var z:=sin(TAU*j/4)*.57
		var s:=g.rng.randf_range(.49,1.22)
		g.column(x,z,0,s*.57,s*.14,s*.11,"e4c59b",7)
		g.column(x,z,s*.48,s*.10,s*.36,s*.38,"ebcba1",9)
		g.blob(Vector3(x,s*.63,z),Vector3(s*.4,s*.22,s*.4),["c06e55","c98b65"][j%2],9)
		for k in 3:
			var a:=k*TAU/3
			g.blob(Vector3(x+cos(a)*s*.19,s*.80,z+sin(a)*s*.18),Vector3(s*.054,s*.023,s*.05),"eed5ad",6)

func cactus(pos:Vector3,sc:float) -> void:
	g.at(pos,g.rng.randf()*TAU,sc,true)
	g.shadow(.03,0,.63,.55,.28)
	g.column(0,0,0,1.56,.26,.235,"669779",8)
	g.blob(Vector3(0,1.55,0),Vector3(.236,.15,.235),"7da77d",8)
	for j in 2:
		var side:float=-1.0 if j==0 else 1.0
		var y:=.55+j*.32
		g.tube(Vector3(0,y,0),Vector3(side*.41,y+.15,0),.13,.123,"669779",7)
		g.tube(Vector3(side*.41,y+.15,0),Vector3(side*.42,y+.62,0),.13,.10,"78a080",7)
		g.blob(Vector3(side*.42,y+.62,0),Vector3(.105,.083,.105),"89aa7e",6)
	g.blob(Vector3(.02,1.75,0),Vector3(.15,.115,.12),"d78a77",7)

func headstone(pos:Vector3,sc:float) -> void:
	g.at(pos,g.rng.randf_range(-.37,.37),sc,true)
	g.shadow(.06,.01,.57,.44,.32)
	var tone:String=["8d9490","92978e","89938f","a0a399"][g.rng.randi()%4]
	g.block(Vector3(0,.10,0),Vector3(.85,.20,.52),"727d78")
	g.block(Vector3(0,.51,0),Vector3(.65,.73,.26),tone)
	g.blob(Vector3(0,.87,0),Vector3(.324,.23,.13),tone,8,0.015)
	g.ring(Vector3(0,.76,.139),Vector3.BACK,.13,.031,"c0bba5",8)
	for j in 2:
		g.block(Vector3(0,.43+.11*j,.14),Vector3(.32-.07*j,.029,.012),"666f6b")

func reeds(pos:Vector3,sc:float) -> void:
	g.at(pos,0,sc)
	for j in 9:
		var root:=Vector3(g.rng.randf_range(-.42,.42),0,g.rng.randf_range(-.34,.34))
		var tip:=root+Vector3(.10,g.rng.randf_range(.46,1.13),.05)
		g.tube(root,tip,.019,.013,"86935f",4)
		if j%2==0:
			g.tube(tip,tip+Vector3(.022,.18,.014),.044,.043,"8d7251",5)
		var offset:=Vector3(g.rng.randf_range(-.28,.28),.48,.06)
		g.tri(root-Vector3.RIGHT*.032,root+Vector3.RIGHT*.032,root+offset,Vector3.BACK,g.clr("a0aa73"))

func basalt(pos:Vector3,sc:float) -> void:
	g.at(pos,g.rng.randf()*TAU,sc,true)
	g.shadow(.10,.09,1.01,.95,.33)
	for j in 7:
		var a:=TAU*j/7
		var x:=cos(a)*.55
		var z:=sin(a)*.52
		var h:=g.rng.randf_range(.5,1.97)
		var color:String=["665657","76615e","84706a"][j%3]
		g.column(x,z,0,h,.33,.29,color,6)
		g.column(x,z,h,.045,.29,.28,"a08171",6)

func return_shrine() -> void:
	g.at(Vector3(-1.25,0,10.05),.17,1.0,true)
	g.block(Vector3(0,.09,0),Vector3(1.12,.18,.88),"9b9b87")
	g.block(Vector3(0,.23,0),Vector3(.89,.15,.64),"bdbaa2")
	g.column(0,0,.28,1.17,.33,.29,"799894",6)
	g.column(0,0,1.45,.15,.34,.30,CREAM,6)
	g.column(0,0,1.60,.28,.16,0,"7ed9c1",5)
	g.ring(Vector3(0,1.02,.306),Vector3.BACK,.20,.048,"d9e8c3",12)
	g.tube(Vector3(.02,.82,.314),Vector3(.02,1.03,.316),.032,.032,"d9e8c3",5)
	g.solid(Vector3(0,.75,0),Vector3(.66,1.5,.62))
	g.at(Vector3(1.73,0,9.9),-.08)
	g.column(0,0,0,1.24,.083,.07,EDGE,6)
	g.block(Vector3(-.08,1.02,.015),Vector3(.94,.22,.088),TIMBER,Vector3(0,0,.09))
	g.block(Vector3(.12,.76,.02),Vector3(.87,.18,.093),"ae8658",Vector3(0,0,-.08))
	g.at(Vector3.ZERO)
	g.ring(Vector3(0,.039,9.2),Vector3.UP,1.57,.06,"c8d6a7",32)

func mill() -> void:
	house(Vector3(-12.3,0,-2.85),.19,3.4,2.87,2.48,"d3bb94",["876d55","ac8a68","a18768","a98865"],2)
	g.at(Vector3(-11.85,0,-.96),.14,1.0,true)
	wheel(Vector3(0,1.20,0),1.15,Vector3.BACK)
	for k in 10:
		var a:=TAU*k/10
		g.block(Vector3(cos(a)*1.04,1.20+sin(a)*1.04,.07),Vector3(.13,.36,.63),"9f7e53",Vector3(0,0,a))

func crossing(pos:Vector3) -> void:
	g.at(pos,HeightMap.BRIDGE_YAW)
	for j in 11:
		var x:=-1.78+j*.35
		var h:=.075+.06*sin(PI*j/10)
		g.block(Vector3(x,h,0),Vector3(.34,.11,1.60),["bb9d70","c6a579","b49a76"][j%3])
	for z:float in [-.78,.78]:
		for x:float in [-1.55,1.55]:
			g.column(x,z,0,.75,.087,.077,EDGE,6)
		g.tube(Vector3(-1.55,.67,z),Vector3(1.55,.67,z),.042,.042,EDGE,6)
	# 경사와 상판의 충돌 높이가 판재에 맞아 발이 물에 잠기지 않는다.
	g.solid(Vector3(0,HeightMap.BRIDGE_DECK*.5,0),Vector3(HeightMap.BRIDGE_HALF_LENGTH*2,HeightMap.BRIDGE_DECK,HeightMap.BRIDGE_HALF_WIDTH*2))
	for side:float in [-1.,1.]:
		var ramp:=StaticBody3D.new()
		ramp.collision_layer=1
		ramp.collision_mask=0
		ramp.transform=g.frame
		var collision:=CollisionShape3D.new()
		var wedge:=ConvexPolygonShape3D.new()
		var corners:=PackedVector3Array()
		for z:float in [-HeightMap.BRIDGE_HALF_WIDTH,HeightMap.BRIDGE_HALF_WIDTH]:
			corners.append(Vector3((HeightMap.BRIDGE_HALF_LENGTH-.01)*side,HeightMap.BRIDGE_DECK,z))
			corners.append(Vector3((HeightMap.BRIDGE_HALF_LENGTH-.01)*side,-.03,z))
			corners.append(Vector3(HeightMap.BRIDGE_RAMP_END*side,-.03,z))
		g.quad(Vector3(1.75*side,.126,-.75),Vector3(1.75*side,.126,.75),Vector3(2.14*side,.01,.75),Vector3(2.14*side,.01,-.75),Vector3.UP,g.clr("b79a71"))
		wedge.points=corners
		collision.shape=wedge
		ramp.add_child(collision)
		g.node.add_child(ramp)

func belfry(pos:Vector3) -> void:
	g.at(pos,.11,1.24,true)
	for side:float in [-.85,.85]:
		g.block(Vector3(side,1.35,0),Vector3(.24,2.70,.29),TIMBER)
	g.block(Vector3(0,2.70,0),Vector3(2.24,.26,.53),EDGE)
	roof(Vector3(0,2.87,0),2.62,1.72,.66,["586b73","6c7c7e","758482"])
	g.column(0,0,1.73,.64,.48,.22,"958c68",10)
	g.column(0,0,1.68,.09,.55,.49,"b0a375",10)
	g.column(0,0,2.37,.28,.09,.07,IRON,6)
	g.blob(Vector3(0,1.60,0),Vector3(.105,.13,.105),TIMBER,6)

func ruin(pos:Vector3,sc:float,snow:=false) -> void:
	g.at(pos,-.19,sc,true)
	var stone:="97a9a8" if snow else "bf8e69"
	var highlight:="e2e5d8" if snow else "e1ac75"
	for side:float in [-1.,1.]:
		var x:=side*1.10
		g.block(Vector3(x,.13,0),Vector3(1.0,.26,.91),stone)
		for j in 5:
			g.block(Vector3(x+sin(j+side)*.028,.45+j*.39,0),Vector3(.64-.022*j,.38,.61),stone,Vector3(0,.025*j,0))
		g.block(Vector3(x,2.24,0),Vector3(.88,.19,.82),highlight)
	g.block(Vector3(-.35,2.47,0),Vector3(2.35,.33,.74),stone,Vector3(0,0,.03))
	g.block(Vector3(-.34,2.65,0),Vector3(2.42,.11,.79),highlight)

func water_gate(pos:Vector3) -> void:
	g.at(pos,.18,1.14,true)
	for x:float in [-1.0,1.0]:
		g.block(Vector3(x,1.26,0),Vector3(.39,2.53,.49),"8c8271")
		g.block(Vector3(x,2.5,0),Vector3(.56,.16,.65),"aba48f")
	g.block(Vector3(0,2.25,0),Vector3(2.32,.26,.40),TIMBER)
	for j in 7:
		g.block(Vector3(-.73+j*.24,.73,0),Vector3(.22,1.44,.15),"718577")
	g.block(Vector3(0,.99,.11),Vector3(1.67,.14,.13),IRON)
	wheel(Vector3(.96,1.7,.35),.50,Vector3.BACK)

func furnace(pos:Vector3) -> void:
	g.at(pos,-.20,1.16,true)
	g.column(0,0,0,1.88,1.19,.90,"806961",9)
	g.column(0,0,1.88,1.21,.9,.39,"77615b",9)
	g.column(0,0,3.08,.77,.39,.35,"65595a",9)
	g.column(0,0,3.78,.18,.46,.46,"a1876e",9)
	g.block(Vector3(0,.67,1.02),Vector3(1.13,1.16,.22),IRON)
	g.block(Vector3(0,.55,1.15),Vector3(.85,.82,.045),"e79350")
	for x:float in [-.30,-.10,.10,.30]:
		g.block(Vector3(x,.57,1.19),Vector3(.054,.84,.05),IRON)

func aqueduct() -> void:
	var stream:=terrain.layout.stream
	var bank:String=["a1ad80","bc9c75","8a9791","8fa785","a8c2c5","936e62"][area]
	var water:String=["77aba2","c0a77d","849599","729f95","aac9cf","c87e53"][area]
	g.at(Vector3.ZERO)
	g.frame=Transform3D.IDENTITY
	terrain.ribbon(stream,2.14,bank,.043,.17)
	terrain.ribbon(stream,1.87,water,.046,.14)
	for j in 22:
		var t:=g.rng.randf_range(.1,.9)
		var idx:=g.rng.randi_range(0,stream.size()-2)
		var v:=stream[idx].lerp(stream[idx+1],t)
		g.at(Vector3(v.x,0,v.y))
		g.patch(0,0,g.rng.randf_range(.12,.35),.034,["b3cdc0","dac097","a4b6b0","b1c5ae","d2dfdc","f5ad62"][area],.051,6,.24)
	if area in HeightMap.BRIDGE_REGIONS:
		var bridge:=Layout.bridge_at(area)
		crossing(Vector3(bridge.x,0,bridge.y))

func fallen_log(pos:Vector3,angle:float) -> void:
	g.at(pos,angle,1.0,true)
	g.shadow(.1,.1,1.9,.59,.32)
	g.tube(Vector3(-1.54,.36,0),Vector3(1.46,.28,0),.41,.28,"8c6b49",9,.12)
	for side:float in [-1.,1.]:
		var x:float=-1.54 if side<0 else 1.46
		var y:float=.36 if side<0 else .28
		var r:float=.36 if side<0 else .25
		g.tube(Vector3(x,y,0),Vector3(x+side*.009,y,0),r,r,"c39f69",9)
		g.ring(Vector3(x+side*.013,y,0),Vector3.RIGHT*side,r*.73,.017,"9d8158",9)
	g.tube(Vector3(.36,.49,0),Vector3(.03,.82,-.26),.16,.10,"866944",7)
	for j in 7:
		g.blob(Vector3(-1.25+j*.35,.62+sin(j)*.038,-.03),Vector3(.32,.095,.18),["82965e","929f60"][j%2],6)

func rusted_rails(start:Vector2,angle:float,length:float) -> void:
	g.at(Vector3(start.x,0,start.y),angle)
	for j in ceili(length/.6):
		var z:=j*.60
		g.block(Vector3(0,.038,z),Vector3(1.23,.074,.13),"755a48",Vector3(0,sin(j)*.06,0))
	for x:float in [-.42,.42]:
		g.block(Vector3(x,.102,length*.48),Vector3(.072,.077,length),IRON)

func pond(pos:Vector3,rx:float,rz:float) -> void:
	g.at(pos)
	g.patch(0,0,rx,rz,"879c80",.057,21,.09)
	g.patch(.03,.01,rx*.94,rz*.87,"759b90",.063,21,.08)
	for j in 12:
		var a:=g.rng.randf()*TAU
		var r:=g.rng.randf_range(.12,.73)
		var v:=Vector2(cos(a)*rx*r,sin(a)*rz*r)
		g.patch(v.x,v.y,.17,.12,"a0b58a",.073,8,.10)
		if j%3==0:
			g.blob(Vector3(v.x,.096,v.y),Vector3(.083,.065,.068),"e1b1b6",6)

func beacon_flag(pos:Vector3,color:String,shape:=0) -> void:
	g.at(pos,-.25,1.0,true)
	g.column(0,0,0,2.49,.085,.055,EDGE,7)
	g.tube(Vector3(-.12,2.35,0),Vector3(.78,2.35,0),.042,.042,TIMBER,5)
	g.quad(Vector3(.08,2.34,0),Vector3(.69,2.34,0),Vector3(.74,1.69,.07),Vector3(.10,1.72,.115),Vector3.BACK,g.clr(color))
	g.tri(Vector3(.10,1.72,.115),Vector3(.74,1.69,.07),Vector3(.42,1.4,.11),Vector3.BACK,g.clr(color))
	g.ring(Vector3(.40,2.03,.075),Vector3.BACK,.125,.035,CREAM,8 if shape==0 else 4)
	g.column(0,0,2.48,.14,.069,0,BRASS,6)

func trailhead() -> void:
	match area:
		0:
			fallen_log(Vector3(-5.05,0,8.84),-.45)
			fungus(Vector3(-5.89,0,9.57),.82)
			for p:Vector3 in [Vector3(-4.3,0,8.58),Vector3(-5.7,0,9.08),Vector3(3.4,0,10.1)]:
				flowers(p,1.03,"ecc085")
			beacon_flag(Vector3(3.55,0,10.47),"639684")
		1:
			g.at(Vector3(-4.96,0,9.74),.18,1.0,true)
			g.shadow(0,0,1.46,.95,.3)
			g.column(0,0,0,.18,1.13,1.05,"c49b72",10)
			g.column(0,0,.18,.25,.87,.72,"dfb183",9)
			g.column(0,0,.43,.73,.35,.25,"d9ac7b",7)
			g.column(0,0,1.14,.13,.69,.70,"ab8969",12)
			g.column(0,0,1.27,.045,.62,.62,"e5c77e",12)
			g.tri(Vector3(-.31,1.32,0),Vector3(.36,1.32,0),Vector3(-.29,1.88,0),Vector3.BACK,g.clr("927357"))
			crystal(Vector3(4.7,0,9.1),.95,["80b8b0","9dd0c0","75b0b1"])
			cactus(Vector3(5.65,0,10.48),1.12)
			beacon_flag(Vector3(-6.2,0,9.98),"ba6d55",1)
		2:
			for j in 5:
				headstone(Vector3(-4.0-j*.79,0,8.51+sin(j)*.46),.64+j*.09)
			g.at(Vector3(4.3,0,9.70),.15,1.0,true)
			for j in 4:
				var x:=j*.67
				g.block(Vector3(x,.28,0),Vector3(.67,.50,.46),"828a83")
				g.block(Vector3(x,.55,0),Vector3(.69,.10,.53),"a1a497")
				for k in 2:
					g.column(x-.20+k*.28,0,.57,.57,.028,.027,IRON,5)
					g.column(x-.20+k*.28,0,1.14,.13,.063,0,IRON,4)
			g.block(Vector3(1.0,.88,0),Vector3(2.64,.055,.045),IRON)
			lantern(Vector3(-.40,.54,0),.86)
		3:
			pond(Vector3(5.10,0,10.3),2.04,1.04)
			for p:Vector3 in [Vector3(3.6,0,10.2),Vector3(5.6,0,9.50),Vector3(4.7,0,11.4),Vector3(-4.9,0,9.1)]:
				reeds(p,.94)
			g.at(Vector3(-4.7,0,9.8),-.61,1.0,true)
			g.shadow(0,0,1.8,.63,.25)
			for z:float in [-.36,.36]:
				g.quad(Vector3(-1.62,.29,0),Vector3(-.93,.39,z),Vector3(.99,.39,z),Vector3(1.62,.28,0),Vector3.UP,g.clr("8a6f50"))
				g.quad(Vector3(-.93,.39,z),Vector3(.99,.39,z),Vector3(.83,.12,z*.43),Vector3(-.80,.12,z*.43),Vector3(0,1,signf(z)),g.clr("a98c64"))
			g.block(Vector3(0,.35,0),Vector3(.30,.073,.75),TIMBER)
			g.tube(Vector3(-.19,.4,-.47),Vector3(1.34,.47,.28),.037,.037,EDGE,7)
		4:
			g.at(Vector3(-4.83,0,9.75),.10,1.0,true)
			for j in 4:
				var s:=.67-j*.13
				g.blob(Vector3(sin(j)*.06,.11+j*.27,0),Vector3(s,.22,s*.78),"8aa1a2",7,.06)
			g.blob(Vector3(.02,1.01,-.03),Vector3(.29,.12,.24),"e5ebdd",7)
			beacon_flag(Vector3(-5.60,0,10.16),"b86d65",1)
			crystal(Vector3(4.58,0,9.72),1.02,["92bdcc","a5cbd3","bedbe1"])
			g.at(Vector3(5.95,0,10.63),-.21)
			for j in 3:
				g.block(Vector3(j*.27,.08,0),Vector3(.16,.12,1.53),"b79b78")
				g.block(Vector3(j*.27,.18,0),Vector3(.07,.10,.3),TIMBER)
		5:
			rusted_rails(Vector2(-5.0,8.1),-.49,5.65)
			g.at(Vector3(-5.45,0,9.03),-.49,1.0,true)
			for side:float in [-.43,.43]:
				for z:float in [-.48,.48]:
					wheel(Vector3(side,.29,z),.22,Vector3.RIGHT)
			g.block(Vector3(0,.56,0),Vector3(.90,.48,1.3),"626061")
			g.block(Vector3(0,.80,0),Vector3(1.03,.10,1.46),"8e8076")
			for j in 7:
				g.blob(Vector3(sin(j)*.30,.85,cos(j)*.43),Vector3(.24,.18,.21),"645957",6)
			basalt(Vector3(4.91,0,10.6),.78)

func arena_marks() -> void:
	var tints:=["a6a27a","c9a27a","989d8d","92a688","c3d1cd","9c8170"]
	var arena:Vector2=Layout.ARENAS[area]
	for j in 22:
		var a:=TAU*j/22
		var p:=arena+Vector2(cos(a)*6.5,sin(a)*5.8)
		g.at(Vector3(p.x,0,p.y),-a)
		g.block(Vector3(0,.065,0),Vector3(.46,.13,.26),tints[area])
	for side:float in [-1.,1.]:
		beacon_flag(Vector3(arena.x+side*4.1,0,arena.y-4.8),"bc7059",1)
	var altar:=Vector3(arena.x,0,arena.y-8.4)
	match area:
		0:
			fallen_log(altar,.12)
			g.at(altar)
			wheel(Vector3(0,1.1,-.24),1.04,Vector3.BACK)
		1: ruin(altar,1.42)
		2: belfry(altar)
		3: water_gate(altar)
		4: crystal(altar,1.88,["98bece","bad7da","92bbcd"])
		5: furnace(altar)

func landmarks() -> void:
	var spots:=terrain.layout.landmarks
	# 표식 중심은 길 위에 두고 목표물은 옆에 세워 접근 공간을 확보한다.
	for i in spots.size():
		var center:Vector2=spots[i].pos
		if i==4:
			grotto(center)
			continue
		var side:Vector2=[Vector2(-5.7,0),Vector2(5.5,0),Vector2(-5,-4.2),Vector2(-2,-5.5)][i]
		g.origin=Vector3(center.x+side.x,0,center.y+side.y)
		match i:
			0:
				match area:
					0:
						g.origin+=Vector3(12.3,0,2.85)
						mill()
					1: ruin(Vector3.ZERO,1.48)
					2: belfry(Vector3.ZERO)
					3: water_gate(Vector3.ZERO)
					4: ruin(Vector3.ZERO,1.4,true)
					5: furnace(Vector3.ZERO)
			1:
				for k in 5:
					var p:=Vector3(1.55*cos(k*1.6),0,k*1.18-2.5)
					match area:
						0: fungus(p,1.65+.35*(k%2))
						1: crystal(p,1.45+.29*k,["7bafb1","94c4bb","86bcb9"])
						2: headstone(p,1.2+.18*(k%3))
						3:
							if k==2: broadleaf(p,1.65,SWAMP)
							else: reeds(p,1.3)
						4: crystal(p,1.1+.32*k,["98bece","afcfdb","92bbcd"])
						5: basalt(p,1.1+.24*k)
			2:
				match area:
					0:
						fallen_log(Vector3.ZERO,-.28)
						fallen_log(Vector3(1.3,0,-1.1),-.21)
						g.at(Vector3(2,0,1))
						crate(Vector3.ZERO)
					1:
						g.at(Vector3.ZERO)
						crate(Vector3(0,0,-.4),.85)
						barrel(Vector3(1.2,0,.3),1.15)
						beacon_flag(Vector3(-.6,0,.8),"b56c52")
					2:
						for k in 4:
							g.at(Vector3(k*.76,0,sin(k)*.3))
							lantern(Vector3.ZERO,1.45)
						headstone(Vector3(1.1,0,-1.1),1.44)
					3:
						g.at(Vector3.ZERO)
						for k in 9:
							g.block(Vector3(k*.32,.14,0),Vector3(.31,.22,2.4),"ab8c66")
						barrel(Vector3(-.5,0,.5))
						reeds(Vector3(2.7,0,1.5),1.38)
					4:
						fallen_log(Vector3.ZERO,-.42)
						beacon_flag(Vector3(.8,0,-1),"bb6c62")
						g.at(Vector3(-1.4,0,-1.6))
						crate(Vector3.ZERO)
						lantern(Vector3(0,.68,0))
					5:
						rusted_rails(Vector2(-1.1,-2.5),-.36,5.5)
						g.at(Vector3.ZERO,-.36)
						g.block(Vector3(0,.62,0),Vector3(1.1,.70,1.42),IRON)
						for x:float in [-.55,.55]:
							for z:float in [-.48,.48]:
								wheel(Vector3(x,.28,z),.26,Vector3.RIGHT)
			3:
				match area:
					0: broadleaf(Vector3.ZERO,1.8,FOREST)
					1:
						g.at(Vector3.ZERO,-.22)
						g.column(0,0,0,.42,1.46,1.15,"c1936c",12)
						g.column(0,0,.42,.58,.61,.42,"cba279",8)
						g.column(0,0,1.0,.14,1.12,1.10,"e3c78b",20)
						for hour in 12:
							var a:=hour*TAU/12
							g.block(Vector3(cos(a)*.89,1.15,sin(a)*.89),Vector3(.15,.026,.045),IRON,Vector3(0,-a,0))
						g.tri(Vector3(-.5,1.16,0),Vector3(.52,1.16,0),Vector3(-.45,1.96,0),Vector3.BACK,g.clr("826c54"))
					2: ruin(Vector3.ZERO,1.17,true)
					3: pond(Vector3.ZERO,3.45,2.4)
					4:
						for k in 3:
							g.at(Vector3(k*1.45,0,sin(k)*.4))
							for tier in 4:
								var s:=.73-tier*.14
								g.blob(Vector3(0,.15+tier*.34,0),Vector3(s,.26,s*.9),"9aadae" if tier<3 else "e1ece1",8)
					5:
						furnace(Vector3.ZERO)
						rusted_rails(Vector2(2.1,-2.4),.1,4.3)
		g.origin=Vector3.ZERO
		beacon_flag(Vector3(center.x+2.1,0,center.y+2.2),"c99554")

func grotto(center:Vector2) -> void:
	var tone:String=ROCKS[area]
	g.at(Vector3(center.x,0,center.y),0,1.0,true)
	for side:float in [-1.,1.]:
		g.blob(Vector3(side*3.2,1.7,-1.5),Vector3(1.3,2.1,3.0),tone,9,.12)
		g.solid(Vector3(side*3.2,1.5,-1.5),Vector3(1.8,3,4.4))
	g.blob(Vector3(0,3.65,-2.1),Vector3(3.7,1.0,2.1),tone,10,.10)
	g.block(Vector3(0,1.65,-4.5),Vector3(5.6,3.3,.8),tone)
	g.solid(Vector3(0,1.65,-4.5),Vector3(5.6,3.3,.8))
	g.solid(Vector3(0,3.65,-2.6),Vector3(5.6,.8,3.0))
	lantern(Vector3(-2,1.0,1.0),1.2)
	g.at(Vector3(center.x,0,center.y+3.0))
	g.patch(0,0,2.4,1.1,"b7b393",.045,12,.12)

func treasure_caches() -> void:
	for cache in terrain.layout.caches:
		var p:Vector2=cache.pos
		var holder:=Node3D.new()
		holder.name="Cache_"+cache.id.replace(":","_")
		holder.position=Vector3(p.x,HeightMap.altitude(p+Vector2(0,-1.4),area),p.y-1.4)
		g.node.add_child(holder)
		var chest:=Painter.new(holder,924+area)
		chest.at(Vector3.ZERO)
		chest.shadow(0,0,.73,.52,.34)
		chest.block(Vector3(0,.28,0),Vector3(1.12,.56,.68),"779281")
		for x:float in [-.47,.47]:
			chest.block(Vector3(x,.29,0),Vector3(.10,.58,.72),BRASS)
		chest.block(Vector3(0,.31,.36),Vector3(.18,.22,.065),IRON)
		chest.finish()
		var lid:=Node3D.new()
		lid.position=Vector3(0,.57,-.34)
		holder.add_child(lid)
		var top:=Painter.new(lid,824+area)
		top.at(Vector3.ZERO)
		top.block(Vector3(0,.055,.34),Vector3(1.16,.11,.74),"a0b096")
		for x:float in [-.47,.47]:
			top.block(Vector3(x,.12,.34),Vector3(.10,.05,.74),BRASS)
		top.ring(Vector3(0,.13,.34),Vector3.UP,.17,.043,BRASS,8)
		top.finish()
		cache_lids[cache.id]=lid
		g.at(Vector3(holder.position.x,0,holder.position.z))
		g.solid(Vector3(0,.3,0),Vector3(1.12,.6,.68))

func outer_ruins() -> void:
	var spot:Vector2=terrain.layout.sideareas[1].pos
	for side:float in [-1.,1.]:
		var p:=Vector3(spot.x+side*5.5,0,spot.y-4)
		ruin(p,1.25,area in [2,4])
		rocks(Vector3(spot.x+side*6,0,spot.y+2),1.3,ROCKS[area])
	var lookout:Vector2=terrain.layout.sideareas[2].pos
	beacon_flag(Vector3(lookout.x-4,0,lookout.y-2),"bc8061",1)
	beacon_flag(Vector3(lookout.x+4,0,lookout.y-2),"6c9e96")
	for district in terrain.layout.districts:
		var p:Vector2=district.pos
		for j in 4:
			var offset:=Vector2.from_angle(j*TAU/4+.3)*8.0
			flora(Vector3(p.x+offset.x,0,p.y+offset.y),1.45,j)

func flora(pos:Vector3,sc:float,index:int) -> void:
	match area:
		0:
			if index%4==1: broadleaf(pos,sc,FOREST)
			else: conifer(pos,sc)
		1:
			if index%3==0: crystal(pos,sc,["76aaa9","a6c5b5","9cbab0"])
			else: cactus(pos,sc)
		2:
			if index%4==0: broadleaf(pos,sc*.89,AUTUMN)
			elif index%4==1: conifer(pos,sc*.85)
			else: headstone(pos,sc)
		3:
			if index%4==0: broadleaf(pos,sc,SWAMP)
			else: reeds(pos,sc*1.35)
		4:
			if index%4==0: crystal(pos,sc,["a1c7d2","b5d4db","9cbdc9"])
			else: conifer(pos,sc,true)
		5:
			if index%4==0: crystal(pos,sc,["cc875e","d39767","ac795d"])
			else: basalt(pos,sc)

func _prototypes() -> Array:
	var ground_painter:=g
	var results:=[]
	for i in 8:
		var holder:=Node3D.new()
		g=Painter.new(holder,701+area*100+i)
		g.fade=ground_painter.fade
		g.opaque=ground_painter.opaque
		g.contact=ground_painter.contact
		if i<4: flora(Vector3.ZERO,1.0,i)
		elif i==4: rocks(Vector3.ZERO,1.0,ROCKS[area],3)
		elif i==5 and area in [0,3]: flowers(Vector3.ZERO,1.0,"e6cc88" if area==0 else "d4a9bf")
		else: grasses(Vector3.ZERO,1.0,["89a260","b8a771","81917b","8da279","a0b1ab","9a826c"][area])
		g.finish()
		var parts:=[]
		var solids:=[]
		for child in holder.get_children():
			if child is MeshInstance3D:
				parts.append([child.mesh,child.cast_shadow])
			elif child is StaticBody3D:
				solids.append([child.transform,child.get_child(0).shape])
		results.append({"parts":parts,"solids":solids})
		holder.free()
	g=ground_painter
	return results

func _groves() -> void:
	# 풀·바위·나무는 셀 단위로 묶어 같은 메시를 공유하고 화면 밖 무리는 컬링한다.
	var shapes:=_prototypes()
	var cells:={}
	var body:=StaticBody3D.new()
	body.collision_mask=0
	g.node.add_child(body)
	var banks:=PackedVector2Array()
	var water:=terrain.layout.stream
	for i in water.size()-1:
		var steps:=ceili(water[i].distance_to(water[i+1])/1.7)
		for k in steps: banks.append(Layout.road_at(water,i,float(k)/steps))
	for z in range(-118,119,5):
		for x in range(-134,135,5):
			var center:=Vector2(x+g.rng.randf_range(-2.2,2.2),z+g.rng.randf_range(-2.2,2.2))
			var grove:=g.rng.randi_range(0,3)
			for j in 4:
				var p:=center+Vector2(g.rng.randf_range(-2,2),g.rng.randf_range(-2,2))
				var surface:Dictionary=terrain.layout.surface_at(p)
				if not surface.walkable or surface.kind=="bridge": continue
				var uv:=(p-terrain.texture_bounds.position)/terrain.texture_bounds.size
				var cell_xy:=Vector2i(uv*Vector2(terrain.tracks.get_size())).clamp(Vector2i.ZERO,terrain.tracks.get_size()-Vector2i.ONE)
				if terrain.tracks.get_pixelv(cell_xy).r>.015: continue
				var tall:=j==0 or (j==1 and sin(center.x*.16)+cos(center.y*.23)>.53)
				if tall and (p.distance_to(Layout.ENTRY)<7.0 or p.distance_to(Layout.ARENAS[area])<8.0): continue
				var variation:=grove if tall else g.rng.randi_range(4,7)
				var sc:=g.rng.randf_range(.82,1.36) if tall else g.rng.randf_range(.6,1.25)
				if tall and (absf(p.x)<2.5 or _beside_landmark(p) or p.distance_squared_to(Layout.bridge_at(area))<16): continue
				var on_bank:=false
				for bank in banks:
					if p.distance_squared_to(bank)<4.4:
						on_bank=true
						break
				if on_bank: continue
				var pose:=Transform3D(Basis(Vector3.UP,g.rng.randf()*TAU).scaled(Vector3.ONE*sc),
					Vector3(p.x,HeightMap.altitude(p,area),p.y))
				var key:=Vector3i(floori(p.x/24),floori(p.y/24),variation)
				if not cells.has(key): cells[key]=[]
				cells[key].append(pose)
				if Layout.BOUNDS.has_point(p):
					for solid in shapes[variation].solids:
						var collision:=CollisionShape3D.new()
						collision.shape=solid[1]
						collision.transform=pose*solid[0]
						body.add_child(collision)
	for key:Vector3i in cells:
		var poses:Array=cells[key]
		for part in shapes[key.z].parts:
			var instances:=MultiMesh.new()
			instances.transform_format=MultiMesh.TRANSFORM_3D
			instances.mesh=part[0]
			instances.instance_count=poses.size()
			for i in poses.size(): instances.set_instance_transform(i,poses[i])
			var grove:=MultiMeshInstance3D.new()
			grove.multimesh=instances
			grove.cast_shadow=part[1]
			g.node.add_child(grove)

func _beside_landmark(point:Vector2) -> bool:
	for spot in terrain.layout.landmarks:
		if point.distance_squared_to(spot.pos)<52: return true
	for spot in terrain.layout.caches:
		if point.distance_squared_to(spot.pos)<52: return true
	return false

func _boundary_posts() -> void:
	var color:String=["896b4d","bd946c","747d78","8d8568","95a4a2","846b61"][area]
	var cord:String=["a2885a","bc9863","475652","968964","a88f76","665758"][area]
	var bounds:=Layout.BOUNDS
	var corners:=[bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]
	for side in 4:
		var a:Vector2=corners[side]
		var b:Vector2=corners[(side+1)%4]
		var count:=ceili(a.distance_to(b)/4.0)
		for k in count:
			var p:=a.lerp(b,float(k)/count)
			var q:=a.lerp(b,float(k+1)/count)
			g.at(Vector3(p.x,0,p.y))
			var h:=.7+.12*(k%3)
			g.column(0,0,0,h,.14,.105,color,5)
			var far:=Vector3(q.x-p.x,HeightMap.altitude(q,area)-g.frame.origin.y+.63,q.y-p.y)
			var middle:=(Vector3.UP*.63+far)*.5-Vector3.UP*.15
			g.tube(Vector3.UP*.63,middle,.027,.027,cord,4)
			g.tube(middle,far,.027,.027,cord,4)

func generate() -> void:
	aqueduct()
	landmarks()
	g.origin=Vector3(Layout.ENTRY.x,0,Layout.ENTRY.y-9.2)
	return_shrine()
	trailhead()
	g.origin=Vector3.ZERO
	arena_marks()
	outer_ruins()
	treasure_caches()
	_boundary_posts()
	_groves()
