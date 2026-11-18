extends RefCounted

const Painter = preload("res://scripts/world/scenery_mesh.gd")
const TIMBER = "6d4537"
const EDGE = "9a6443"
const IRON = "354750"
const BRASS = "edb55e"
const CREAM = "f9e3b4"
var g: Painter

func _init(painter:Painter) -> void:
	g = painter

func wheel(p:Vector3,r:float,axis := Vector3.FORWARD) -> void:
	var face := axis.normalized()
	var right := face.cross(Vector3.UP)
	g.tube(p-face*0.07,p+face*0.07,r,r,TIMBER,16)
	# 어두운 안쪽 면 위에 밝은 바퀴살과 테두리를 겹친다.
	for side:float in [-1.0,1.0]:
		var hub := p+face*0.076*side
		g.ring(hub,face*side,r,0.085,IRON,16)
		g.tube(hub,hub+face*0.009*side,r*0.77,r*0.77,"584336",16)
		for i in 8:
			var a := TAU*i/8
			var tip := right*cos(a)+Vector3.UP*sin(a)
			g.tube(hub+face*0.014*side,hub+tip*(r-0.075)+face*0.014*side,0.035,0.05,"d49b5e",5)
		g.tube(hub,hub+face*0.09*side,r*0.17,r*0.17,BRASS,8)

func crate(p:Vector3,s:=0.64) -> void:
	if p.y<.08: g.shadow(p.x,p.z,s*.82,s*.68,.27)
	g.block(p+Vector3.UP*s*0.48,Vector3(s,s*0.93,s*0.85),"ac774e")
	for side:float in [-1.0,1.0]:
		for y:float in [0.13,0.83]:
			g.block(p+Vector3(0,s*y,side*s*0.43),Vector3(s*1.01,s*0.13,0.035),"d3a16b")
		for x:float in [-0.41,0.41]:
			g.block(p+Vector3(x*s,s*0.49,side*s*0.43),Vector3(s*0.12,s*0.89,0.04),EDGE)
	g.block(p+Vector3(0,s*0.48,s*0.448),Vector3(s*0.105,s,s*0.05),"e1aa70",Vector3(0,0,-0.76))

func barrel(p:Vector3,sc:=1.0) -> void:
	g.shadow(p.x,p.z,sc*.48,sc*.46,.36)
	var low:=p+Vector3.UP*0.08*sc
	var mid:=p+Vector3.UP*.43*sc
	var top:=p+Vector3.UP*.79*sc
	g.tube(low,mid,.27*sc,.34*sc,"a87548",10,.09)
	g.tube(mid,top,.34*sc,.27*sc,"ad7d4c",10,.09)
	for h:float in [.17,.66]:
		g.tube(p+Vector3.UP*h*sc,p+Vector3.UP*(h+.064)*sc,.312*sc,.314*sc,IRON,10)
	g.tube(top,top+Vector3.UP*.025*sc,.265*sc,.265*sc,"d09a62",10)

func lantern(p:Vector3,sc:=1.0) -> void:
	g.tube(p,p+Vector3.UP*.15*sc,.18*sc,.12*sc,IRON,6)
	g.tube(p+Vector3.UP*.13*sc,p+Vector3.UP*.46*sc,.13*sc,.185*sc,"ffdc82",6)
	g.tube(p+Vector3.UP*.46*sc,p+Vector3.UP*.59*sc,.22*sc,.07*sc,IRON,6)
	for i in 4:
		var a:=TAU*i/4+0.3
		g.tube(p+Vector3(cos(a)*.13,.12,sin(a)*.13)*sc,p+Vector3(cos(a)*.18,.47,sin(a)*.18)*sc,.015*sc,.015*sc,EDGE,4)

func pennants(a:Vector3,b:Vector3,count:int,colors:Array) -> void:
	var last := a
	for i in count+1:
		var t:= float(i)/count
		var top:=a.lerp(b,t)-Vector3.UP*sin(PI*t)*.3
		if i>0:
			g.tube(last,top,.024,.024,TIMBER,4)
			var l:=last.lerp(top,.14)
			var r:=last.lerp(top,.77)
			var tip:=(r+l)*.5+Vector3(.06,-.36,.10)
			g.tri(l,r,tip,Vector3.BACK,g.clr(colors[(i-1)%colors.size()]))
		last=top

func roof(p:Vector3,w:float,d:float,rise:float,palette:Array) -> void:
	var stepz:=d*.5/4
	# 기와마다 처마 끝이 다음 줄에 살짝 겹친다.
	for side:float in [-1.,1.]:
		for row in 4:
			var z0:=row*stepz
			var z1:float=(row+1)*stepz+.06
			var y0:=rise*(1.0-z0/(d*.5))
			var y1:=rise*(1.0-z1/(d*.5))-.012
			var x0:float=-w*.5
			var tile_width:=0.53
			while x0<w*.5-.001:
				var w1:=tile_width
				if row%2==1 and is_equal_approx(x0,-w*.5):
					w1*=.51
				var x1:=minf(x0+w1,w*.5)
				var lift:float=(3-row)*.035
				var corner:=p+Vector3(x0,y0+lift,z0*side)
				var end:=p+Vector3(x1-.008,y1+lift,z1*side)
				var paint:String=palette[g.rng.randi_range(0,palette.size()-1)]
				g.quad(corner,Vector3(end.x,corner.y,corner.z),end,Vector3(corner.x,end.y,end.z),Vector3(0,1,side),g.clr(paint))
				g.quad(end,Vector3(corner.x,end.y,end.z),Vector3(corner.x,end.y-.055,end.z),end-Vector3.UP*.055,Vector3(0,0,side),g.clr(palette[0]))
				x0=x1
		g.block(p+Vector3(0,-.08,side*d*.5),Vector3(w+.13,.16,.15),TIMBER)
	g.tube(p+Vector3(-w*.53,rise+.10,0),p+Vector3(w*.53,rise+.10,0),.125,.125,palette[1],8)
	for side:float in [-1.,1.]:
		var peak:=p+Vector3(side*w*.495,rise,0)
		for z:float in [-1.,1.]:
			g.tube(peak,p+Vector3(side*w*.495,.0,z*d*.51),.088,.085,EDGE,6)

func window(p:Vector3,w:=.72,h:=.85) -> void:
	g.block(p,Vector3(w+.18,h+.18,.10),TIMBER)
	g.block(p+Vector3(0,0,.065),Vector3(w,h,.04),"425d63")
	g.block(p+Vector3(-w*.2,h*.18,.095),Vector3(w*.37,h*.42,.035),"9cbfc0")
	g.block(p+Vector3(w*.20,h*.18,.094),Vector3(w*.37,h*.42,.035),"bfd0bc")
	g.block(p+Vector3(0,0,.125),Vector3(.067,h,.06),EDGE)
	g.block(p+Vector3(0,0,.12),Vector3(w,.07,.06),EDGE)
	g.block(p+Vector3(0,-h*.55,.13),Vector3(w+.26,.12,.24),"bf9469")
	for side:float in [-1.,1.]:
		g.block(p+Vector3(side*(w*.5+.14),0,.055),Vector3(.18,h*.94,.06),"638b80")
		for j in 3:
			g.block(p+Vector3(side*(w*.5+.14),h*(-.29+j*.28),.091),Vector3(.15,.038,.018),"91ab94")

func planter(p:Vector3,w:float) -> void:
	g.block(p,Vector3(w,.18,.26),"995f44")
	g.block(p+Vector3.UP*.075,Vector3(w+.045,.065,.28),"bb8054")
	for j in maxi(4,roundi(w/.14)):
		var off:=Vector3(g.rng.randf_range(-w*.44,w*.44),.15,g.rng.randf_range(-.05,.10))
		g.blob(p+off,Vector3(.12,.10,.09),"72864d",6)
		g.blob(p+off+Vector3(.015,.09,.01),Vector3(.06,.048,.049),["f3c477","e69a7c","f6d4a1"][j%3],5)

func house(pos:Vector3,yaw:float,w:float,d:float,h:float,wall:String,tiles:Array,kind:int) -> void:
	g.at(pos,yaw,1.0,true)
	g.shadow(.1,.25,w*.70,d*.77,.39)
	g.block(Vector3(0,.24,0),Vector3(w+.13,.48,d+.16),"9d9783")
	g.block(Vector3(0,h*.53,0),Vector3(w,h-.2,d),wall)
	g.solid(Vector3(0,h*.5,0),Vector3(w,h,d))
	for x:float in [-w*.48,0.0,w*.48]:
		for z:float in [-d*.51,d*.51]:
			g.block(Vector3(x,h*.52,z),Vector3(.13,h,.15),TIMBER)
	for y:float in [.48,h*.62,h-.04]:
		g.block(Vector3(0,y,0),Vector3(w+.13,.13,d+.15),EDGE)
	var ridge:=h+1.32
	for x:float in [-1.,1.]:
		g.tri(Vector3(x*w*.5,h,-d*.5),Vector3(x*w*.5,h,d*.5),Vector3(x*w*.5,ridge,0),Vector3.RIGHT*x,g.clr(wall))
		g.tube(Vector3(x*w*.51,h,-d*.5),Vector3(x*w*.51,ridge,0),.08,.08,TIMBER,4)
		g.tube(Vector3(x*w*.51,h,d*.5),Vector3(x*w*.51,ridge,0),.08,.08,TIMBER,4)
	roof(Vector3(0,h+.03,0),w+.72,d+.82,1.38,tiles)
	var doorx:=w*.14
	g.block(Vector3(doorx,1.05,d*.51+.03),Vector3(.91,1.67,.12),TIMBER)
	g.block(Vector3(doorx,1.02,d*.51+.12),Vector3(.72,1.5,.09),"9c6847")
	g.block(Vector3(doorx,1.49,d*.51+.18),Vector3(.44,.37,.035),"6d989d")
	g.blob(Vector3(doorx+.24,.90,d*.51+.19),Vector3.ONE*.055,BRASS,6)
	for wx:float in [-w*.31,w*.34]:
		window(Vector3(wx,h*.61,d*.51+.04),w*.15,.81)
		planter(Vector3(wx,h*.61-.56,d*.51+.18),w*.19)
	g.block(Vector3(doorx,.14,d*.54+.18),Vector3(1.17,.26,.71),"b6a790")
	g.block(Vector3(doorx,.055,d*.54+.61),Vector3(1.35,.11,.37),"cab89b")
	var chimney:=Vector3(-w*.28,h+.85,-d*.21)
	g.block(chimney,Vector3(.55,1.95,.54),"a78266")
	g.block(chimney+Vector3.UP*.95,Vector3(.72,.20,.71),"70695e")
	for j in 4:
		g.block(chimney+Vector3((j%2)*.16-.07,.48+j*.13,.279),Vector3(.20,.065,.02),"d0a382")
	if kind==1:
		# 돌출 지붕창과 종루가 광장의 중심 건물을 구별한다.
		g.block(Vector3(.40,h+1.48,0),Vector3(1.35,1.22,1.23),"edce9b")
		window(Vector3(.40,h+1.58,.645),.61,.53)
		roof(Vector3(.40,h+2.0,0),1.85,1.7,.64,tiles)
		for s:float in [-.57,.57]:
			g.tube(Vector3(doorx+s*.89,1.82,d*.5),Vector3(doorx+s,2.03,d*.5+.68),.043,.054,EDGE,6)
		g.block(Vector3(doorx,2.12,d*.50+.30),Vector3(1.62,.15,.85),tiles[1],Vector3(.13,0,0))
		for k in 5:
			var x:=doorx-.60+k*.29
			g.tri(Vector3(x,2.02,d*.5+.73),Vector3(x+.27,2.02,d*.5+.73),Vector3(x+.14,1.85,d*.5+.73),Vector3.BACK,g.clr("e2b25e"))
	elif kind==2:
		wheel(Vector3(-w*.28,1.04,d*.55+.12),.7,Vector3.BACK)

func conifer(pos:Vector3,scale:float,snow:=false) -> void:
	g.at(pos,g.rng.randf()*TAU,scale,true)
	g.shadow(.16,.14,1.62,1.47,.31)
	if absf(pos.x)<17.2 and absf(pos.z)<15.5:
		g.solid(Vector3(0,.82,0),Vector3(.38,1.64,.38))
	g.column(0,0,0,2.4,.27,.15,"806047",7)
	for tier in 4:
		var y:=1.0+tier*.65
		var r:=1.44-tier*.26
		var palette:=["3b6856","48765a","57865e","699565"]
		if snow: palette=["588783","679695","77a6a0","8bb6af"]
		var points:=PackedVector3Array()
		var crest:=Vector3(.08*tier,y+1.34-tier*.09,0)
		for i in 12:
			var a:=TAU*(i+float(tier%2)*.42)/12
			var s:=r*(1.0 if i%2==0 else .80)*g.rng.randf_range(.91,1.05)
			points.append(Vector3(cos(a)*s,y-.14*(i%2),sin(a)*s))
		for i in 12:
			var p:=points[i]
			var q:=points[(i+1)%12]
			g.tri(crest,p,q,p+q-Vector3.UP*y*2,g.tint(palette[tier],1.0+.048*sin(i*2.3)))
			g.tri(Vector3(0,y-.13,0),p,q,Vector3.DOWN,g.clr(palette[0]))
			if snow:
				var f1:=.57+.13*(i%2)
				var f2:=.57+.13*((i+1)%2)
				g.tri(crest+Vector3.UP*.016,crest.lerp(p,f1)+Vector3.UP*.025,crest.lerp(q,f2)+Vector3.UP*.025,Vector3.UP,g.clr(["d3e6e2","e7f0e8","f1f2df"][i%3]))

func broadleaf(pos:Vector3,scale:float,colors:Array) -> void:
	g.at(pos,g.rng.randf()*TAU,scale,true)
	g.shadow(.18,.13,1.91,1.57,.33)
	if absf(pos.x)<17.2 and absf(pos.z)<15.5:
		g.solid(Vector3(.02,.90,0),Vector3(.45,1.80,.43))
	g.tube(Vector3(0,0,0),Vector3(.04,2.75,0),.28,.13,"876447",8,.10)
	for i in 5:
		var a:=TAU*i/5+.31
		var limb:=Vector3(cos(a)*1.03,2.42+(i%2)*.42,sin(a)*.95)
		g.tube(Vector3(0,1.38,0),limb,.12,.055,"936e4b",6)
		g.blob(limb+Vector3.UP*.41,Vector3(1.13,.84,1.08),colors[i%2],8,.11)
		g.blob(limb+Vector3(-.16,.85,-.12),Vector3(.77,.50,.71),colors[2+i%2],7,.12)
	g.blob(Vector3(.03,3.64,0),Vector3(1.12,.71,1.06),colors[3],9)
	for i in 5:
		var a:=i*TAU/5
		g.tube(Vector3(0,.25,0),Vector3(cos(a)*.56,.045,sin(a)*.50),.074,.027,"826a48",5)

func flowers(pos:Vector3,scale:float,petal:String) -> void:
	g.at(pos,0,scale)
	for i in 6:
		var t:=g.rng.randf()*TAU
		var root:=Vector3(cos(t)*g.rng.randf_range(.1,.57),0,sin(t)*.42)
		var tip:=root+Vector3(.06,g.rng.randf_range(.15,.37),.03)
		g.tube(root,tip,.013,.010,"64824f",4)
		for k in 4:
			var a:=TAU*k/4
			var v:=Vector3(cos(a),.2,sin(a))
			g.tri(tip,tip+v*.093+Vector3(-v.z,.02,v.x)*.04,tip+v*.084-Vector3(-v.z,0,v.x)*.045,Vector3.UP,g.clr(petal))
		g.column(tip.x,tip.z,tip.y,.026,.030,.031,"f6c65d",5)

func grasses(pos:Vector3,scale:float,color:String) -> void:
	g.at(pos,0,scale)
	for i in 8:
		var a:=TAU*i/8+g.rng.randf_range(-.35,.35)
		var out:=Vector3(cos(a),0,sin(a))
		var side:=Vector3(-out.z,0,out.x)*.046
		var p:=out*g.rng.randf_range(.045,.19)
		g.tri(p-side,p+side,p+out*.20+Vector3.UP*g.rng.randf_range(.18,.51),Vector3.UP+out,g.tint(color,1.0+.075*sin(i)))
