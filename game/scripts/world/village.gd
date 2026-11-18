extends "res://scripts/world/props.gd"

const TEAL_ROOF = ["376767","4c827a","528b81","447c77","5d9084","60958b"]
const RED_ROOF = ["9e5446","be7057","cc805e","ba6955","c57659","d18a67"]
const BLUE_ROOF = ["536782","637a91","778ca0","6f829c","5e788f"]
const LEAVES = ["658351","739448","8fa653","a5b85b"]

func carriage(pos:Vector3) -> void:
	g.at(pos,-.14,1.0,true)
	g.shadow(.19,.15,2.10,1.36,.40)
	g.block(Vector3(0,.97,0),Vector3(3.05,.35,1.52),"815436")
	g.block(Vector3(0,1.24,0),Vector3(2.98,.57,1.47),"ae7845")
	g.solid(Vector3(0,1.0,0),Vector3(3.0,2.0,1.49))
	for z:float in [-.80,.80]:
		for h:float in [1.03,1.26,1.5]:
			g.block(Vector3(0,h,z),Vector3(3.08,.075,.10),"d59e5b")
		for x:float in [-1.31,-.68,.62,1.31]:
			g.block(Vector3(x,1.27,z),Vector3(.10,.55,.115),IRON)
		for x:float in [-1.03,.98]:
			wheel(Vector3(x,.61,z*1.19),.59,Vector3.BACK)
	# 마차의 원통형 캔버스, 양 끝의 함몰된 입구, 겹친 가죽끈.
	for x:float in [-1.40,1.40]:
		g.column(x,0,1.4,.92,.10,.075,EDGE,6)
	for k in 12:
		var a:=PI*k/12
		var b:=PI*(k+1)/12
		var low:=Vector3(0,1.68+sin(a)*1.04,cos(a)*.94)
		var high:=Vector3(0,1.68+sin(b)*1.04,cos(b)*.94)
		for j in 7:
			var lx:=-1.59+j*3.18/7
			var rx:=-1.59+(j+1)*3.18/7
			var fabric:String=["43938b","54a398","4c9d92","468e89","4f9e93","56a699","3d8985"][j]
			g.quad(low+Vector3.RIGHT*lx,low+Vector3.RIGHT*rx,high+Vector3.RIGHT*rx,high+Vector3.RIGHT*lx,Vector3(0,sin(a),cos(a)),g.clr(fabric))
		for x:float in [-1.57,-.96,.88,1.57]:
			g.tube(low+Vector3(x,.016,cos(a)*.025),high+Vector3(x,.016,cos(b)*.025),.035,.035,CREAM,5)
		for x:float in [-1.55,1.55]:
			g.tri(Vector3(x,1.69,0),low+Vector3.RIGHT*x,high+Vector3.RIGHT*x,Vector3.RIGHT*signf(x),g.clr("36736c"))
			g.tri(Vector3(x*1.001,1.69,0),Vector3(x*1.001,1.69+sin(a)*.72,cos(a)*.65),Vector3(x*1.001,1.69+sin(b)*.72,cos(b)*.65),Vector3.RIGHT*signf(x),g.clr("475652"))
	for z:float in [-.95,.95]:
		g.block(Vector3(0,1.66,z),Vector3(3.21,.10,.075),CREAM)
		for j in 10:
			var x:=-1.58+j*.316
			g.tri(Vector3(x,1.61,z),Vector3(x+.30,1.61,z),Vector3(x+.14,1.45,z),Vector3.BACK*signf(z),g.clr(CREAM if j%2==0 else "bf873e"))
	for z:float in [-.51,.51]:
		g.tube(Vector3(1.38,.84,z),Vector3(3.60,.66,z),.09,.065,EDGE,6)
	g.block(Vector3(1.72,1.0,0),Vector3(.46,.17,1.22),TIMBER)
	lantern(Vector3(1.38,1.26,.89),.72)
	# 타원형 명패와 여덟 갈래 바퀴 문장.
	var badge:=Vector3(-.1,1.80,.956)
	g.tube(badge,badge+Vector3.BACK*.06,.30,.30,"245e61",12)
	g.ring(badge+Vector3.BACK*.069,Vector3.BACK,.25,.028,BRASS,16)
	for j in 8:
		var a:=TAU*j/8
		g.tube(badge+Vector3.BACK*.075,badge+Vector3(cos(a)*.21,sin(a)*.21,.075),.014,.026,CREAM,4)

func pack_animal(pos:Vector3) -> void:
	g.at(pos,-.1,.86,true)
	g.shadow(.12,.02,.95,.46,.38)
	var hide:="ac8c6b"
	for x:float in [-.47,.47]:
		for z:float in [-.22,.22]:
			g.tube(Vector3(x,.88,z),Vector3(x+.07,.1,z),.10,.064,hide,6)
			g.blob(Vector3(x+.08,.065,z),Vector3(.12,.08,.098),IRON,6)
	g.blob(Vector3(0,1.0,0),Vector3(.68,.37,.32),hide,9)
	g.tube(Vector3(.38,1.10,0),Vector3(.72,1.54,0),.25,.17,hide,7)
	g.blob(Vector3(.77,1.60,.02),Vector3(.30,.25,.19),hide,8)
	g.blob(Vector3(1.03,1.48,.02),Vector3(.22,.15,.16),"dcc4a6",7)
	for z:float in [-.105,.105]:
		g.tube(Vector3(.73,1.71,z),Vector3(.62,2.06,z*1.8),.085,.035,hide,6)
		g.blob(Vector3(.84,1.64,z*1.8),Vector3(.045,.059,.022),IRON,6)
	g.block(Vector3(0,1.29,.025),Vector3(.63,.13,.58),"486d73")
	for x:float in [-.26,.25]:
		g.block(Vector3(x,1.08,.31),Vector3(.085,.5,.06),TIMBER,Vector3(0,0,.21))
	g.tube(Vector3(-.51,1.09,0),Vector3(-.76,.52,.045),.065,.049,EDGE,6)
	g.blob(Vector3(-.79,.47,.045),Vector3(.10,.14,.08),TIMBER,6)

func npc(pos:Vector3,kind:int,angle:=0.0) -> void:
	g.at(pos,angle,1.15,true)
	g.shadow(0,.02,.41,.30,.36)
	var coat:String=["3e7f79","ce8759","775779","637d98"][kind]
	var trim:String=["e0b25c","eee0b3","ccb27d","c7a980"][kind]
	var hair:String=["e0d4b1","634633","583c47","695344"][kind]
	var skin:String=["ddb58b","e6ba8f","b48568","deb18b"][kind]
	for side:float in [-1.,1.]:
		g.block(Vector3(.118*side,.18,0),Vector3(.17,.32,.19),"48525c")
		g.blob(Vector3(.124*side,.078,.052),Vector3(.135,.084,.172),TIMBER,7)
	g.column(0,0,.28,.54,.31,.22,coat,8)
	g.column(0,0,.77,.16,.22,.16,trim,8)
	g.block(Vector3(0,.48,.244),Vector3(.40,.085,.06),TIMBER)
	g.block(Vector3(.025,.47,.282),Vector3(.085,.064,.018),BRASS)
	for side:float in [-1.,1.]:
		g.tube(Vector3(.17*side,.75,0),Vector3(.30*side,.52,.035),.117,.099,coat,7)
		g.blob(Vector3(.30*side,.46,.06),Vector3(.09,.11,.09),skin,7)
	g.blob(Vector3(0,1.04,0),Vector3(.255,.27,.23),skin,9)
	g.blob(Vector3(0,1.17,-.035),Vector3(.27,.19,.23),hair,9)
	for side:float in [-1.,1.]:
		g.blob(Vector3(.10*side,1.055,.203),Vector3(.026,.037,.023),IRON,6)
	if kind==0:
		g.blob(Vector3(0,.883,.15),Vector3(.19,.18,.13),hair,8)
		g.column(0,0,1.26,.12,.30,.245,"49635f",8)
		g.tube(Vector3(.36,0,.13),Vector3(.37,.92,.12),.04,.043,EDGE,7)
		g.blob(Vector3(.37,.97,.12),Vector3(.082,.09,.078),BRASS,7)
	elif kind==1:
		g.column(0,0,1.25,.045,.37,.35,"cb9c58",12)
		g.column(0,0,1.29,.18,.24,.105,"e0b673",10)
	else:
		g.column(0,0,1.24,.11,.31,.22,coat,9)
		g.blob(Vector3(-.19,1.31,.034),Vector3(.13,.08,.12),trim,7)

func shop_stall(pos:Vector3,yaw:float,travel:bool) -> void:
	g.at(pos,yaw,1.0,true)
	g.shadow(.08,.12,1.77,1.04,.40)
	var fabric:="7b678a" if travel else "df8c4e"
	var cream:="d5b880" if travel else "f4dba1"
	for x:float in [-1.27,1.27]:
		for z:float in [-.62,.63]:
			g.column(x,z,0,2.44 if z<0 else 1.98,.066,.055,EDGE,6)
	g.block(Vector3(0,.60,.12),Vector3(2.37,.83,.79),"aa774d")
	g.block(Vector3(0,.99,.12),Vector3(2.59,.12,.96),"d4ab77")
	g.solid(Vector3(0,.51,.1),Vector3(2.31,1.02,.78))
	for j in 8:
		var x:=-1.46+j*.365
		var col:String = cream if j%2==0 else fabric
		g.quad(Vector3(x,2.49,-.72),Vector3(x+.365,2.49,-.72),Vector3(x+.365,2.32,.07),Vector3(x,2.32,.07),Vector3.UP,g.clr(col))
		g.quad(Vector3(x,2.32,.07),Vector3(x+.365,2.32,.07),Vector3(x+.365,2.03,.88),Vector3(x,2.03,.88),Vector3.UP,g.clr(col))
		g.quad(Vector3(x,2.03,.88),Vector3(x+.365,2.03,.88),Vector3(x+.365,1.88,.91),Vector3(x,1.88,.91),Vector3.BACK,g.clr(col))
		g.tri(Vector3(x,1.88,.91),Vector3(x+.365,1.88,.91),Vector3(x+.18,1.79,.92),Vector3.BACK,g.clr(col))
	g.block(Vector3(0,.7,.535),Vector3(2.30,.31,.042),fabric)
	for i in 6:
		var x:=-.90+i*.35
		g.tri(Vector3(x,.8,.561),Vector3(x+.18,.8,.561),Vector3(x+.09,.65,.565),Vector3.BACK,g.clr(cream))
	if not travel:
		for j in 3:
			var x:=-.88+j*.52
			g.block(Vector3(x,1.10,.19),Vector3(.47,.11,.42),EDGE)
			for k in 5:
				g.blob(Vector3(x+(k%3-1)*.115,1.23+(k/3)*.07,.14+(k/3)*.09),Vector3(.081,.085,.078),["d27642","91a65d","e2b955"][j],6)
		barrel(Vector3(-1.56,0,-.05),.83)
		lantern(Vector3(1.23,1.23,.68),.75)

func treasure(pos:Vector3) -> void:
	g.at(pos,-.36,1.1,true)
	g.shadow(.06,.06,.90,.60,.42)
	g.block(Vector3(0,.36,0),Vector3(1.22,.64,.77),"9f714a")
	for j in 5:
		var a:=PI*j/5
		var b:=PI*(j+1)/5
		var v:=Vector3(0,.64+sin(a)*.28,cos(a)*.40)
		var q:=Vector3(0,.64+sin(b)*.28,cos(b)*.40)
		g.quad(v-Vector3.RIGHT*.61,v+Vector3.RIGHT*.61,q+Vector3.RIGHT*.61,q-Vector3.RIGHT*.61,Vector3.UP,g.clr("bd915b"))
		for s:float in [-.42,.42]:
			g.quad(v+Vector3(s-.061,.015,cos(a)*.014),v+Vector3(s+.061,.015,cos(a)*.014),q+Vector3(s+.061,.015,cos(b)*.014),q+Vector3(s-.061,.015,cos(b)*.014),Vector3.UP,g.clr(IRON))
	for z:float in [-.39,.39]:
		for x:float in [-.42,.42]:
			g.block(Vector3(x,.36,z),Vector3(.13,.66,.055),IRON)
		g.block(Vector3(0,.65,z),Vector3(1.24,.08,.066),IRON)
	g.block(Vector3(0,.52,.43),Vector3(.18,.23,.067),BRASS)
	g.solid(Vector3(0,.43,0),Vector3(1.24,.86,.79))

func fence(a:Vector3,b:Vector3,n:int) -> void:
	g.at(Vector3.ZERO)
	for i in n+1:
		var p:=a.lerp(b,float(i)/n)
		g.column(p.x,p.z,0,.92,.103,.085,EDGE,6)
		g.column(p.x,p.z,.91,.10,.102,.05,"c49a6b",6)
		if i<n:
			var q:=a.lerp(b,float(i+1)/n)
			for h:float in [.35,.68]:
				g.tube(p+Vector3.UP*h,q+Vector3.UP*h,.056,.063,"ae875c",5)

func bench(pos:Vector3,angle:float) -> void:
	g.at(pos,angle)
	g.shadow(0,.1,.96,.51,.33)
	for side:float in [-.56,.56]:
		g.block(Vector3(side,.23,0),Vector3(.12,.43,.38),TIMBER)
		g.block(Vector3(side,.64,-.21),Vector3(.093,.52,.10),TIMBER)
	for z:float in [-.12,.10]:
		g.block(Vector3(0,.46,z),Vector3(1.48,.11,.18),"bd8e58")
	g.block(Vector3(0,.77,-.21),Vector3(1.48,.19,.10),"cf9e66")
	g.solid(Vector3(0,.27,0),Vector3(1.37,.54,.45))

func front_garden(pos:Vector3,angle:float) -> void:
	g.at(pos,angle)
	g.patch(0,0,2.25,.90,"8b9368",.030,16,.13)
	for j in 15:
		var a:=TAU*j/15
		var v:=Vector3(cos(a)*2.15,.06,sin(a)*.85)
		g.blob(v,Vector3(.23,.12,.15),["b6b49a","c3baa0","a5a88c"][j%3],7,.11)
	for j in 19:
		var a:=g.rng.randf()*TAU
		var f:=sqrt(g.rng.randf())
		var origin:=Vector3(cos(a)*1.82*f,.04,sin(a)*.68*f)
		var s:=g.rng.randf_range(.13,.30)
		g.blob(origin+Vector3.UP*s*.5,Vector3(s*1.4,s,s*1.33),["7d9557","839953","98a55d"][j%3],7)
		for k in 3:
			var bud:=origin+Vector3(s*cos(k*2),s*1.44,s*sin(k*2))
			g.blob(bud,Vector3(.066,.061,.065),["e9b975","edcd97","d99d88","eedaaa"][j%4],6)

func town_crest() -> void:
	# 작은 식물과 정비 흔적으로 마차 마을의 앞마당을 채운다.
	front_garden(Vector3(5.0,0,5.45),-.27)
	front_garden(Vector3(-3.99,0,6.15),.35)
	bench(Vector3(2.70,0,5.0),-2.9)
	g.at(Vector3(-4.60,0,-3.61),.24)
	for j in 5:
		var x:=float(j%3)*.30
		var y:=.14+int(j/3)*.25
		g.tube(Vector3(x,y,-.33),Vector3(x,y,.40),.151,.138,"996c48",8,.06)
		g.tube(Vector3(x,y,.401),Vector3(x,y,.41),.122,.116,"d7ac71",8)
	g.at(Vector3(8.59,0,1.25),-.35)
	wheel(Vector3(0,.49,.34),.48,Vector3.BACK)
	g.at(Vector3(-7.88,0,.95),.33)
	crate(Vector3.ZERO,.65)
	crate(Vector3(.57,0,-.33),.50)
	g.at(Vector3(7.61,0,-4.02),-.13)
	barrel(Vector3.ZERO,.92)
	crate(Vector3(.52,0,-.15),.56)
	for p:Vector3 in [Vector3(-9.7,0,5.7),Vector3(-9.0,0,5.3),Vector3(-4.9,0,7.1),Vector3(-2.1,0,6.3),Vector3(4.9,0,6.7),Vector3(7.7,0,5.2),Vector3(8.2,0,5.1),Vector3(10.1,0,1.2),Vector3(-5.4,0,-4.7)]:
		grasses(p,g.rng.randf_range(.72,1.08),"849b58")

func build() -> void:
	house(Vector3(-8,0,-6.2),.21,4.1,3.65,2.93,"e6c691",RED_ROOF,2)
	house(Vector3(-2.35,0,-7.75),-.08,4.7,3.6,3.32,"efddb4",TEAL_ROOF,1)
	house(Vector3(3.35,0,-9.65),-.22,3.62,3.5,2.83,"e4c79c",RED_ROOF,0)
	house(Vector3(9,0,-7),-.43,3.57,3.1,2.78,"e7d0a3",BLUE_ROOF,0)
	house(Vector3(-13,0,-1.3),.71,3.5,3.0,2.63,"dbba91",TEAL_ROOF,0)
	house(Vector3(13,0,2.3),-.7,3.5,3.2,2.62,"edc69b",RED_ROOF,0)
	carriage(Vector3(4.06,0,-3.20))
	pack_animal(Vector3(7.02,0,-2.87))
	shop_stall(Vector3(-6.9,0,-2.13),.16,false)
	npc(Vector3(-7.10,0,-1.43),1,.26)
	npc(Vector3(-2.67,0,-2.45),0,.25)
	npc(Vector3(2.62,0,-1.95),3,-.13)
	shop_stall(Vector3(-7.25,0,3.77),1.02,true)
	treasure(Vector3(7.41,0,1.45))
	g.at(Vector3(8.31,0,1.70),-.38,1.0,true)
	crate(Vector3.ZERO,.77)
	crate(Vector3(-.03,.77,0),.57)
	barrel(Vector3(.30,0,-.72),.87)
	fence(Vector3(-12,0,-4.1),Vector3(-10.3,0,4.5),5)
	fence(Vector3(8.6,0,4.3),Vector3(12,0,3.9),3)
	fence(Vector3(-3.9,0,-4.65),Vector3(-.75,0,-4.85),3)
	for j in 2:
		var x:float=-4.45+8.72*j
		g.at(Vector3(x,0,-4.29))
		g.column(0,0,0,3.18,.095,.073,EDGE,8)
		g.column(0,0,2.98,.29,.095,.033,BRASS,6)
	g.at(Vector3.ZERO)
	pennants(Vector3(-4.45,3.04,-4.29),Vector3(4.27,3.04,-4.29),14,["e8ba6a","d87b5b","6f9f92","f2dda8"])
	for j in 2:
		var x:float=-4.25+j*12.7
		g.at(Vector3(x,0,.2+j*2))
		g.column(0,0,0,1.98,.086,.064,EDGE,8)
		g.tube(Vector3(0,1.82,0),Vector3(-.41,2.1,0),.046,.046,TIMBER,5)
		g.tube(Vector3(-.41,2.1,0),Vector3(-.41,1.9,0),.023,.023,IRON,4)
		lantern(Vector3(-.41,1.36,0),.91)
	for pos:Vector3 in [Vector3(-5.0,0,-5.8),Vector3(.76,0,-6.5),Vector3(7.1,0,-8.8),Vector3(-10.7,0,1.6),Vector3(10.15,0,-.50),Vector3(-9.6,0,6.8),Vector3(11.7,0,7.9)]:
		broadleaf(pos,g.rng.randf_range(.85,1.16),LEAVES)
	for j in 23:
		var pos:=Vector3(g.rng.randf_range(-19,19),0,g.rng.randf_range(-15,-12.1))
		conifer(pos,g.rng.randf_range(.85,1.46))
	for pos:Vector3 in [Vector3(-4.1,0,-2.8),Vector3(-3.6,0,-3.4),Vector3(1.70,0,-3.2),Vector3(2.0,0,-4.1),Vector3(8.7,0,.80),Vector3(-5.1,0,4.6),Vector3(4.6,0,4.7),Vector3(5.2,0,5.0),Vector3(-3.7,0,5.1),Vector3(.90,0,-5)]:
		flowers(pos,1.05,["f4da7e","fbecbb","df9b8e"][g.rng.randi_range(0,2)])
	town_crest()

func build_traveler() -> void:
	npc(Vector3(-6.54,0,3.77),2,1.02)
	g.at(Vector3(-7.25,0,3.77),1.02)
	for j in 4:
		g.column(-.83+j*.44,.27,1.04,.32,.083,.10,["639995","d7ab6a","9080a0","ae7867"][j],6)
		g.column(-.83+j*.44,.27,1.36,.065,.11,.06,BRASS,6)
