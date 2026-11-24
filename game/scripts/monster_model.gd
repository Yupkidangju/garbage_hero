extends Node3D
## 부위별 메시를 종마다 한 번만 굽고, 전투 인스턴스는 관절과 자세를 독립시킨다.

const Painter = preload("res://scripts/world/scenery_mesh.gd")
const Ink = preload("res://scripts/character_ink.gd")
const FOREST_MODELS := {
	"mouse":"res://assets/models/acorn_mouse.glb", "bee":"res://assets/models/pine_wasp.glb",
	"boar":"res://assets/models/moss_boar.glb", "scarab":"res://assets/models/husk_shield.glb",
	"drummer":"res://assets/models/drum_shroom.glb", "deer":"res://assets/models/trap_antler.glb",
	"treant":"res://assets/models/wheelback.glb"}
const PALETTES := [
	["b77246","6d4537","e6b688","557750","eec76b"],
	["c38759","774d50","f4d599","5c9d9d","8de8de"],
	["737188","414459","d7cdb2","84719b","eef39b"],
	["6d9177","3c5962","d0d383","986575","f0ba70"],
	["8cb3c4","465e7a","f3ead7","7a839e","a3f4f4"],
	["8c5e5e","443e4b","dcc49d","ad6046","ffad60"]]
static var geometry := {}
static var body_paint:ShaderMaterial
static var elite_mesh:Mesh
var animator: AnimationPlayer
var pieces: Array[Node3D] = []
var pose := "Idle"
var clock := 0.0
var age := 0.0
var flying := false
var palette: Array
var skin: String
var shadow_col: String
var ivory: String
var trim: String
var gold: String
var p: Painter
var part_kind := ""
var active_part: Node3D
var species := ""
var body: Node3D
var base_size := 1.0

func build(id:String, region:int, kind:String) -> void:
	species = id
	body = Node3D.new()
	add_child(body)
	if FOREST_MODELS.has(id) and ResourceLoader.exists(FOREST_MODELS[id]):
		var asset: PackedScene = load(FOREST_MODELS[id])
		var model := asset.instantiate() as Node3D
		body.add_child(model)
		Ink.apply(model)
		var players := model.find_children("*","AnimationPlayer",true,false)
		if not players.is_empty():
			animator = players[0]
		play("Idle")
		return
	flying = id in ["bee","crow","moth","icebat","bellowsbat","wraith","candle","spark","frostlamp","nectar_sprite","lantern_owl","dune_vulture","bellwisp","dragonfly","owlfrost"]
	base_size = 1.0 if kind == "normal" else (1.55 if kind == "mini" else 2.12)
	body.scale = Vector3.ONE * base_size
	if geometry.has(id):
		for record:Array in geometry[id]:
			var joint := Node3D.new()
			joint.name = record[0]
			joint.position = record[1]
			var mesh := MeshInstance3D.new()
			mesh.mesh = record[2]
			mesh.position = -joint.position
			joint.add_child(mesh)
			body.add_child(joint)
			pieces.append(joint)
		return
	geometry[id] = []
	palette = PALETTES[region]
	skin = palette[0]
	shadow_col = palette[1]
	ivory = palette[2]
	trim = palette[3]
	gold = palette[4]
	part("Body")
	if expanded():
		finish_part()
		return
	match id:
		"mouse","jerboa","boar","fox","bellgoat","deer","ram","camel":
			quadruped()
		"bee","moth","crow","icebat","bellowsbat":
			winged()
		"scarab","dungbeetle","scorpion","sluicecrab","forgecrab","turtle":
			armored()
		"lizard","leech","salamander","worm","catfish","toad":
			aquatic()
		"candle","spark","wraith","frostlamp":
			spirit()
		_:
			biped()
	finish_part()

func mark_elite() -> void:
	# 테두리 색만 바꾸지 않고, 머리 위 세 갈래 표식과 등 깃발을 실루엣에 더한다.
	if elite_mesh==null:
		var holder:=Node3D.new()
		var paint:=Painter.new(holder,3012)
		for side:float in [-1.,0.,1.]:
			paint.tube(Vector3(side*.19,1.38,0),Vector3(side*.28,1.78-absf(side)*.10,0),.075,.003,"ffd37a",6)
		paint.tube(Vector3(.33,.70,.24),Vector3(.33,1.48,.24),.025,.020,"714e42",6)
		paint.block(Vector3(.53,1.34,.24),Vector3(.39,.24,.045),"b85445")
		paint.finish()
		elite_mesh=holder.get_child(0).mesh
		holder.free()
	var badge:=MeshInstance3D.new()
	badge.name="EliteCrest"
	badge.mesh=elite_mesh
	add_child(badge)
	body.scale*=1.12

func legs(height:float,width:float,color:String) -> void:
	for side:float in [-1.,1.]:
		part("StepA" if side<0 else "StepB",Vector3(side*width,height,0))
		rod(Vector3(side*width,height,0),Vector3(side*width,.12,-.03),.082,.056,color)
		oval(side*width,.09,-.10,.12,.085,.18,ivory)

func sail(span:float,height:float,shape:int) -> void:
	for side:float in [-1.,1.]:
		part("WingL" if side<0 else "WingR",Vector3(side*.12,height,0))
		var a:=Vector3(side*.12,height,.13)
		var tip:=Vector3(side*span,height+.22,-.14)
		var rear:=Vector3(side*span*.68,height-.02,.40)
		p.tri(a,tip,rear,Vector3.UP,p.clr(ivory if shape==0 else trim))
		rod(a,tip,.045,.012,shadow_col)
		if shape==0:
			for n in 4:
				var root:=a.lerp(tip,.42+n*.15)
				rod(root,root+Vector3(side*.12,-.055,.33),.070,.005,skin)
		elif shape==2:
			p.tri(a,Vector3(side*span,height-.08,.56),rear,Vector3.UP,p.clr(gold))

func expanded() -> bool:
	match species:
		"cone_urchin","crystalurchin":
			oval(0,.36,.06,.41,.30,.47,skin)
			oval(0,.30,-.43,.24,.17,.23,ivory)
			eyes(.12,.37,-.60,.047)
			for n in 13:
				var angle:=n*2.4
				var at:=Vector3(cos(angle)*.31,.51+sin(n*1.2)*.09,sin(angle)*.36)
				rod(at,at+Vector3(cos(angle)*.20,.30+fmod(n*.11,.24),sin(angle)*.22),.105,.005,gold if species=="crystalurchin" else "8f6440")
			if species=="crystalurchin":
				rod(Vector3(0,.47,.09),Vector3(.05,1.17,.09),.20,.004,"c4f4f7")
			feet4(.27,.28,.29)
		"branch_mantis":
			rod(Vector3(0,.46,.33),Vector3(0,1.15,0),.24,.12,trim)
			oval(0,1.37,-.12,.30,.19,.17,skin)
			eyes(.21,1.40,-.26,.065)
			for side:float in [-1.,1.]:
				rod(Vector3(side*.16,1.47,-.10),Vector3(side*.35,1.82,-.08),.025,.007,ivory)
				part("ArmL" if side<0 else "ArmR",Vector3(side*.17,1.07,0))
				rod(Vector3(side*.17,1.07,0),Vector3(side*.55,.96,-.20),.075,.060,skin)
				rod(Vector3(side*.55,.96,-.20),Vector3(side*.67,1.41,-.45),.065,.035,trim)
				rod(Vector3(side*.67,1.41,-.45),Vector3(side*.30,1.12,-.63),.13,.003,ivory)
			feet4(.29,.58,.24)
		"nectar_sprite":
			oval(0,.88,0,.16,.25,.15,gold)
			for n in 6:
				var a:=n*TAU/6
				oval(cos(a)*.25,1.10+sin(a)*.22,0,.18,.20,.07,"e9a0a4")
			oval(0,1.10,-.09,.18,.18,.11,ivory)
			eyes(.075,1.12,-.19,.038)
			rod(Vector3(0,.71,0),Vector3(0,.32,.06),.10,.006,trim)
			sail(.62,.85,2)
		"logsnail":
			oval(0,.18,.08,.40,.16,.76,skin)
			oval(0,.58,.26,.43,.43,.48,"936846")
			for n in 4:
				p.ring(Vector3(0,.59,.26),Vector3.RIGHT,.38-n*.075,.035,ivory,16)
			oval(0,.36,-.50,.23,.22,.24,trim)
			for side:float in [-1.,1.]:
				rod(Vector3(side*.13,.44,-.57),Vector3(side*.22,.77,-.66),.043,.027,skin)
				oval(side*.22,.77,-.68,.060,.065,.040,gold)
		"lantern_owl","owlfrost","dune_vulture":
			var vulture:=species=="dune_vulture"
			oval(0,.71,.04,.29,.38,.31,skin)
			if vulture:
				rod(Vector3(0,.83,-.16),Vector3(0,1.26,-.24),.085,.10,ivory)
			oval(0,1.15 if not vulture else 1.32,-.09,.32 if not vulture else .19,.28,.20,shadow_col)
			if not vulture:
				for side:float in [-1.,1.]:
					oval(side*.15,1.16,-.24,.17,.20,.065,ivory)
					rod(Vector3(side*.18,1.32,-.04),Vector3(side*.32,1.64,.01),.11,.004,gold if species=="owlfrost" else skin)
			eyes(.14 if not vulture else .11,1.17 if not vulture else 1.35,-.31,.061)
			rod(Vector3(0,1.13,-.28),Vector3(0,1.04,-.47),.08,.004,gold)
			if species=="lantern_owl":
				p.ring(Vector3(0,.35,-.25),Vector3.FORWARD,.09,.024,ivory)
				oval(0,.20,-.25,.13,.16,.12,gold)
			elif species=="owlfrost":
				for n in 3:
					rod(Vector3((n-1)*.14,.51,.15),Vector3((n-1)*.25,.13,.42),.09,.002,"b6e9ef")
			sail(1.05 if vulture else .79,.86,0)
		"oasis_sage","snowmender","ashpriest":
			var priest:=species=="ashpriest"
			rod(Vector3(0,.25,.03),Vector3(0,1.05,0),.34,.20,trim)
			oval(0,1.20,-.04,.23,.24,.20,ivory)
			eyes(.10,1.21,-.215,.048)
			if species=="oasis_sage":
				for n in 5:
					var a:=n*TAU/5
					rod(Vector3(0,1.40,0),Vector3(cos(a)*.45,1.62,sin(a)*.33),.10,.004,"6c9c75")
				oval(-.38,.66,-.05,.20,.27,.19,gold)
			elif priest:
				rod(Vector3(0,1.30,0),Vector3(0,1.85,.05),.27,.004,shadow_col)
				p.ring(Vector3(0,1.23,-.07),Vector3.FORWARD,.29,.035,gold)
			else:
				oval(0,1.39,.02,.35,.18,.29,skin)
				p.block(Vector3(0,.78,-.24),Vector3(.38,.32,.05),"d7e7d8")
			for side:float in [-1.,1.]:
				part("ArmL" if side<0 else "ArmR",Vector3(side*.20,1.,0))
				rod(Vector3(side*.20,1.,0),Vector3(side*.40,.72,-.17),.10,.07,skin)
				if side>0:
					rod(Vector3(side*.40,.25,-.17),Vector3(side*.40,1.55,-.17),.028,.023,shadow_col)
					if priest:
						p.ring(Vector3(side*.40,1.52,-.17),Vector3.FORWARD,.17,.040,gold)
					else:
						oval(side*.40,1.54,-.17,.14,.17,.13,gold)
			legs(.36,.15,shadow_col)
		"sandshield","pineshield":
			oval(0,.59,.07,.34,.43,.30,trim)
			oval(0,1.02,-.04,.25,.23,.20,skin)
			eyes(.105,1.04,-.21,.05)
			if species=="sandshield":
				p.ring(Vector3(0,1.19,.04),Vector3.UP,.20,.045,ivory)
				oval(-.28,.63,-.28,.46,.49,.11,"c99a66")
				p.ring(Vector3(-.28,.63,-.40),Vector3.FORWARD,.35,.037,gold)
			else:
				for n in 3:
					rod(Vector3(-.26,.35+n*.28,-.32),Vector3(-.26,.74+n*.26,-.32),.43-n*.085,.005,"66846e")
				rod(Vector3(.34,.57,-.10),Vector3(.35,1.45,-.10),.035,.018,shadow_col)
				rod(Vector3(.35,1.19,-.10),Vector3(.35,1.63,-.10),.14,.004,ivory)
			legs(.37,.20,shadow_col)
		"hourglass":
			for side:float in [-1.,1.]:
				rod(Vector3(side*.27,.30,0),Vector3(side*.27,1.29,0),.045,.045,gold)
			p.column(0,0,.30,.10,.36,.36,shadow_col)
			p.column(0,0,1.22,.10,.36,.36,shadow_col)
			rod(Vector3(0,.43,0),Vector3(0,.79,0),.23,.025,ivory)
			rod(Vector3(0,.79,0),Vector3(0,1.17,0),.025,.23,skin)
			eyes(.09,1.09,-.19,.049)
			legs(.30,.18,trim)
		"bonehound","frost_mammoth","badger_captain","basalt_drake":
			var mammoth:=species=="frost_mammoth"
			var drake:=species=="basalt_drake"
			var h:=.75 if mammoth else .54
			oval(0,h,.10,.50 if mammoth else .38,h*.74,.65,skin)
			oval(0,h+.14,-.50,.36 if mammoth else .26,.30,.34,ivory if species=="bonehound" else skin)
			eyes(.18,h+.23,-.73,.061)
			if species=="bonehound":
				for n in 5:
					p.ring(Vector3(0,h,.34-n*.14),Vector3.FORWARD,.28,.041,ivory,12)
				rod(Vector3(0,h-.02,-.63),Vector3(0,h-.03,-.97),.17,.09,ivory)
			elif mammoth:
				rod(Vector3(0,h-.02,-.69),Vector3(0,.23,-.91),.15,.085,skin)
				rod(Vector3(0,.23,-.91),Vector3(.13,.28,-1.06),.085,.025,skin)
				for side:float in [-1.,1.]:
					rod(Vector3(side*.22,h-.05,-.63),Vector3(side*.48,h-.08,-.98),.10,.065,ivory)
					rod(Vector3(side*.48,h-.08,-.98),Vector3(side*.43,h+.23,-1.13),.065,.002,gold)
					oval(side*.39,h+.15,-.35,.24,.30,.10,trim)
			elif drake:
				for n in 5:
					rod(Vector3(0,h+.30,-.25+n*.22),Vector3(0,h+.72,-.22+n*.22),.14,.004,gold)
				rod(Vector3(0,h,.54),Vector3(.22,.37,1.26),.23,.06,shadow_col)
				rod(Vector3(.22,.37,1.26),Vector3(.38,.48,1.62),.06,.001,gold)
				for side:float in [-1.,1.]:
					p.tri(Vector3(side*.28,h,.20),Vector3(side*.95,h+.48,.45),Vector3(side*.44,h-.05,.71),Vector3.UP,p.clr(trim))
			else:
				p.block(Vector3(0,h+.41,.12),Vector3(.70,.20,.75),trim)
				for side:float in [-1.,1.]:
					oval(side*.20,h+.41,-.49,.13,.17,.12,shadow_col)
				rod(Vector3(.47,.28,-.24),Vector3(.47,1.40,-.24),.042,.033,shadow_col)
				p.block(Vector3(.47,1.30,-.24),Vector3(.56,.36,.12),ivory)
			feet4(.33,h*.76,.38)
		"gravearcher","reedarcher","shroudweaver","bone_conductor":
			var reed:=species=="reedarcher"
			var h:=.95 if reed else .72
			rod(Vector3(0,.46,.05),Vector3(0,h+.27,0),.20,.13,trim)
			oval(0,h+.46,-.045,.22,.22,.17,ivory)
			eyes(.09,h+.48,-.20,.045)
			if species=="bone_conductor":
				p.column(0,0,h+.62,.33,.29,.21,shadow_col)
				for n in 4:
					p.ring(Vector3(0,.63+n*.13,0),Vector3.UP,.23,.030,ivory,12)
			elif species=="shroudweaver":
				rod(Vector3(0,h+.50,.05),Vector3(0,h+.82,.12),.30,.005,skin)
				for n in 4:
					rod(Vector3((n-1.5)*.10,.70,.13),Vector3((n-1.5)*.18,.15,.24),.06,.006,ivory)
			elif reed:
				rod(Vector3(0,h+.35,-.15),Vector3(0,h+.34,-.53),.09,.004,gold)
				for n in 3:
					rod(Vector3(.15,h+.55,0),Vector3(.22+n*.10,h+.90,0),.045,.003,trim)
			for side:float in [-1.,1.]:
				part("ArmL" if side<0 else "ArmR",Vector3(side*.15,h+.14,0))
				var hand:=Vector3(side*.40,h,-.22)
				rod(Vector3(side*.15,h+.14,0),hand,.06,.045,ivory)
				if species=="shroudweaver":
					rod(Vector3(side*.15,h-.04,0),hand+Vector3(side*.18,-.26,.08),.05,.020,skin)
				elif side<0 and species!="bone_conductor":
					var bow_col:String=trim if reed else "a39b86"
					rod(hand+Vector3(0,-.43,0),hand+Vector3(0,0,-.18),.032,.040,bow_col)
					rod(hand+Vector3(0,0,-.18),hand+Vector3(0,.43,0),.040,.024,bow_col)
					rod(hand+Vector3(0,-.43,0),hand+Vector3(0,.43,0),.008,.008,ivory)
				elif species=="bone_conductor" and side>0:
					rod(hand,hand+Vector3(.24,.55,-.14),.022,.003,gold)
			legs(.54 if reed else .42,.15,ivory)
		"coffin":
			p.block(Vector3(0,.88,.04),Vector3(.68,1.40,.42),shadow_col)
			p.block(Vector3(0,.88,-.20),Vector3(.55,1.22,.065),"a58a70")
			p.block(Vector3(0,.99,-.25),Vector3(.34,.085,.045),ivory)
			p.block(Vector3(0,.99,-.25),Vector3(.085,.44,.045),ivory)
			eyes(.15,1.30,-.25,.06)
			part("ArmL",Vector3(-.34,.95,-.19))
			p.block(Vector3(.0,.88,-.34),Vector3(.58,1.25,.08),trim,Vector3(0,-.30,0))
			legs(.28,.24,skin)
		"bellwisp":
			rod(Vector3(0,.56,0),Vector3(0,1.15,0),.40,.15,gold)
			p.ring(Vector3(0,.56,0),Vector3.UP,.40,.055,ivory)
			oval(0,.56,0,.11,.19,.11,shadow_col)
			eyes(.14,.89,-.26,.06)
			for side:float in [-1.,1.]:
				rod(Vector3(side*.20,.57,.05),Vector3(side*.37,.15,.18),.095,.005,skin)
			p.ring(Vector3(0,1.24,0),Vector3.FORWARD,.10,.03,ivory)
		"mossheron":
			oval(0,.85,.11,.29,.31,.39,trim)
			rod(Vector3(0,1.02,-.14),Vector3(0,1.56,-.20),.12,.10,skin)
			oval(0,1.57,-.27,.18,.18,.23,skin)
			rod(Vector3(0,1.54,-.39),Vector3(0,1.48,-.82),.10,.003,ivory)
			eyes(.12,1.63,-.42,.043)
			for n in 5:
				rod(Vector3(0,1.67,-.18),Vector3((n-2)*.14,1.93,.08),.055,.003,"8fae6e")
			legs(.67,.16,shadow_col)
			sail(.47,.91,1)
		"bogclam":
			oval(0,.20,.03,.65,.18,.60,skin)
			oval(0,.38,.12,.58,.14,.55,ivory)
			oval(0,.68,.27,.59,.40,.18,trim)
			for n in 7:
				var angle:float=(n-3)*.33
				rod(Vector3(0,.42,.32),Vector3(sin(angle)*.59,.68+cos(angle)*.35,.19),.045,.022,ivory)
			oval(0,.42,-.20,.28,.15,.27,gold)
			eyes(.13,.47,-.42,.06)
		"dragonfly":
			rod(Vector3(0,.79,-.30),Vector3(0,.75,.86),.14,.025,trim)
			oval(0,.84,-.34,.22,.17,.17,gold)
			eyes(.17,.88,-.44,.072)
			for side:float in [-1.,1.]:
				part("WingL" if side<0 else "WingR",Vector3(side*.08,.85,0))
				for row in 2:
					var z:float=-.12+row*.29
					p.quad(Vector3(side*.05,.85,z),Vector3(side*.94,.91,z-.16),Vector3(side*.87,.89,z+.06),Vector3(side*.1,.85,z+.1),Vector3.UP,p.clr("c3dfce"))
					rod(Vector3(side*.08,.855,z),Vector3(side*.91,.92,z-.10),.018,.005,ivory)
		"snowhare":
			oval(0,.36,.11,.28,.34,.42,ivory)
			oval(0,.65,-.24,.22,.24,.22,skin)
			for side:float in [-1.,1.]:
				rod(Vector3(side*.12,.80,-.20),Vector3(side*.21,1.43,-.10),.10,.018,ivory)
				p.block(Vector3(side*.23,.09,-.10),Vector3(.16,.12,.76),trim)
				rod(Vector3(side*.23,.11,-.48),Vector3(side*.23,.22,-.58),.055,.020,gold)
			eyes(.13,.69,-.41,.052)
			oval(0,.43,.48,.15,.17,.15,ivory)
		"slaglobster","cinderscorpion","sand_tortoise":
			var tortoise:=species=="sand_tortoise"
			oval(0,.40,.14,.50 if tortoise else .32,.35,.62,trim)
			oval(0,.37,-.43,.25,.20,.24,skin)
			eyes(.15,.43,-.59,.06)
			if tortoise:
				for n in 3:
					rod(Vector3((n-1)*.26,.60,.13),Vector3((n-1)*.25,1.10-absf(n-1)*.20,.13),.17,.003,gold)
				p.ring(Vector3(0,.66,.16),Vector3.UP,.42,.045,ivory)
			else:
				var tail:=Vector3(0,.43,.54)
				for n in 5:
					var next:=tail+Vector3(.07,.18 if species=="cinderscorpion" else -.035,-.02 if n>2 else .13)
					rod(tail,next,.11-n*.014,.09-n*.012,shadow_col)
					tail=next
				rod(tail,tail+Vector3(-.08,-.19,-.26),.08,.003,gold)
			for side:float in [-1.,1.]:
				if not tortoise:
					part("ArmL" if side<0 else "ArmR",Vector3(side*.27,.37,-.20))
					var claw:=Vector3(side*.61,.43,-.48)
					rod(Vector3(side*.27,.37,-.20),claw,.09,.12,skin)
					rod(claw,claw+Vector3(side*.14,.04,-.38),.14,.005,ivory)
					rod(claw,claw+Vector3(-side*.15,.06,-.29),.11,.005,gold)
			feet4(.40,.35,.34)
		"obsidianspire":
			for n in 5:
				var a:=n*TAU/5
				var at:=Vector3(cos(a)*.28,.08,sin(a)*.28)
				rod(at,at+Vector3(cos(a)*.10,.70+fmod(n*.29,.60),sin(a)*.10),.22,.002,shadow_col)
			rod(Vector3(0,.15,0),Vector3(.05,1.65,0),.29,.003,trim)
			p.block(Vector3(0,.81,-.25),Vector3(.26,.085,.065),gold)
			for side:float in [-1.,1.]:
				oval(side*.085,.84,-.29,.033,.043,.03,"fff3bb")
		"mire_hydra":
			oval(0,.38,.17,.59,.34,.65,trim)
			for n in range(-1,2):
				part("Head%d"%n,Vector3(n*.29,.48,-.14))
				var neck:=Vector3(n*.45,1.05+(.22 if n==0 else 0.),-.34)
				rod(Vector3(n*.29,.48,-.14),neck,.17,.13,skin)
				oval(neck.x,neck.y,neck.z-.13,.22,.17,.30,skin)
				for side:float in [-1.,1.]:
					oval(neck.x+side*.13,neck.y+.07,neck.z-.32,.044,.052,.03,gold)
			feet4(.39,.31,.36)
		_:
			return false
	return true

func part(label:String, pivot := Vector3.ZERO) -> void:
	finish_part()
	active_part = Node3D.new()
	active_part.name = label
	active_part.position = pivot
	body.add_child(active_part)
	pieces.append(active_part)
	p = Painter.new(active_part, absi(hash(species + label)))
	p.at(Vector3.ZERO)
	part_kind = label

func finish_part() -> void:
	if p == null:
		return
	# GLB와 같은 선형 정점색과 셀 명암을 사용한다.
	for batch in p.batches.values():
		for n in batch.colors.size():
			batch.colors[n]=batch.colors[n].srgb_to_linear()
	p.finish()
	var mesh := active_part.get_child(0) as MeshInstance3D
	if not body_paint:
		body_paint=ShaderMaterial.new()
		body_paint.shader=Ink.PAINT
		var outline:=ShaderMaterial.new()
		outline.shader=Ink.OUTLINE
		body_paint.next_pass=outline
	mesh.mesh.surface_set_material(0,body_paint)
	mesh.position = -active_part.position
	geometry[species].append([part_kind,active_part.position,mesh.mesh])
	p = null

func oval(x:float,y:float,z:float,rx:float,ry:float,rz:float,color:String) -> void:
	p.blob(Vector3(x,y,z),Vector3(rx,ry,rz),color,10,.035)

func rod(a:Vector3,b:Vector3,r:float,end:float,color:String) -> void:
	p.tube(a,b,r,end,color,7,.034)

func eyes(width:float, h:float, z:float, size:=.074) -> void:
	for s:float in [-1.,1.]:
		oval(s*width,h,z,size,size*1.20,size*.7,"302b38")
		oval(s*width,h+.021,z-size*.48,size*.58,size*.68,size*.5,"ffdb85")
		oval(s*width-.008,h+.036,z-size*.70,size*.22,size*.28,size*.25,"fff3cb")

func feet4(w:float, h:float, length:float) -> void:
	for group in 2:
		part("StepA" if group==0 else "StepB",Vector3(0,h,0))
		for s:float in [-1.,1.]:
			var z:float = length*s*(1 if group==0 else -1)
			var x:float = w*s
			rod(Vector3(x,h,z),Vector3(x,.10,z+.04),.095,.067,shadow_col)
			oval(x,.10,z-.04,.105,.095,.155,ivory)

func quadruped() -> void:
	var brute := species in ["boar","ram","bellgoat","camel","deer"]
	var h := .52 if brute else .35
	oval(0,h,.045,.37,h*.86,.55,skin)
	var neck := .35 if species in ["deer","camel"] else .10
	var y := h+neck
	oval(0,y,-.40,.27,.28,.32,skin)
	oval(0,y-.06,-.63,.20,.14,.17,ivory)
	oval(0,y-.03,-.759,.105,.083,.053,shadow_col)
	eyes(.179,y+.07,-.604,.058)
	for s:float in [-1.,1.]:
		var neck_ear:float = .40 if species in ["fox","jerboa"] else .19
		rod(Vector3(s*.15,y+.18,-.39),Vector3(s*.29,y+.18+neck_ear,-.30),.105,.018,skin)
		if species in ["bellgoat","deer","ram","camel"]:
			var tip := Vector3(s*.53,y+.50,-.30)
			rod(Vector3(s*.17,y+.20,-.43),tip,.085,.050,ivory)
			rod(tip,Vector3(s*.57,y+.65,-.40),.051,.009,gold)
			if species=="deer":
				rod(tip,Vector3(s*.66,y+.62,-.17),.047,.005,ivory)
		if species=="boar":
			rod(Vector3(s*.18,y-.10,-.59),Vector3(s*.27,y+.08,-.70),.072,.006,ivory)
	if species=="mouse":
		oval(0,h+.24,.20,.23,.26,.25,"9d5e36")
		oval(0,h+.39,.19,.25,.102,.255,"72533b")
		rod(Vector3(0,h+.43,.19),Vector3(.06,h+.59,.24),.05,.024,"5e563c")
		for s:float in [-1.,1.]:
			oval(s*.15,h+.42,.15,.11,.04,.055,"b28956")
	elif species=="boar":
		for n in 6:
			oval(sin(n*2.)*.14,h+.38,-.25+n*.11,.20,.14,.19,trim)
	elif species=="camel":
		for n in 3:
			rod(Vector3((n-1)*.20,h+.18,.16),Vector3((n-1)*.33,h+.80-absf(n-1)*.15,.25),.158,.006,gold)
	elif species in ["ram","bellgoat"]:
		oval(0,y-.18,-.63,.109,.11,.105,gold)
	part("Tail",Vector3(0,h,.38))
	if species in ["fox","jerboa"]:
		rod(Vector3(0,h,.37),Vector3(.19,h+.24,.92),.095,.16,skin)
		rod(Vector3(.19,h+.24,.92),Vector3(.23,h+.32,1.13),.16,.015,ivory)
	else:
		rod(Vector3(0,h,.40),Vector3(.19,h-.09,.79),.075,.038,shadow_col)
		rod(Vector3(.19,h-.09,.79),Vector3(.30,h+.02,.82),.042,.011,ivory)
	feet4(.235,h*.92,.29)

func winged() -> void:
	var h := .88
	var insect := species in ["bee","moth"]
	oval(0,h,0,.21,.21,.36,gold if species=="bee" else skin)
	oval(0,h+.055,-.28,.205,.19,.21,shadow_col)
	eyes(.125,h+.083,-.43,.060)
	if species=="bee":
		for z:float in [.02,.19]:
			oval(0,h,z,.213,.204,.073,shadow_col)
		rod(Vector3(0,h,.29),Vector3(0,h-.05,.62),.09,.005,ivory)
	if species=="crow":
		rod(Vector3(0,h+.04,-.41),Vector3(0,h,-.69),.085,.001,ivory)
	for s:float in [-1.,1.]:
		rod(Vector3(.10*s,h+.14,-.27),Vector3(.23*s,h+.35,-.24),.055,.016,ivory)
		part("WingL" if s<0 else "WingR",Vector3(s*.12,h,0))
		var col := "d8e5c3" if insect else trim
		var a := Vector3(s*.12,h,.12); var b := Vector3(s*.56,h+.31,-.33)
		var c := Vector3(s*.76,h+.25,-.14); var d := Vector3(s*.51,h+.12,.21)
		p.quad(a,b,c,d,Vector3.UP,p.clr(col))
		p.tri(d,Vector3(s*.61,h+.10,.33),a,Vector3.UP,p.clr(ivory))
		rod(a,b,.038,.012,shadow_col)
		rod(a,c,.022,.008,ivory)
		if species=="moth":
			oval(.46*s,h+.21,-.06,.123,.028,.13,"e8a3a8")
		if species=="icebat":
			rod(d,Vector3(s*.56,h-.19,.23),.065,.002,gold)
		if species=="bellowsbat":
			oval(s*.42,h+.12,.08,.16,.095,.19,"d17b52")
func armored() -> void:
	var shell := species in ["turtle","scarab","dungbeetle"]
	oval(0,.39,.035,.46,.31,.54,shadow_col)
	oval(0,.55,.085,.435,.29,.49,trim)
	oval(0,.38,-.41,.245,.20,.24,skin)
	eyes(.14,.44,-.57)
	for s:float in [-1.,1.]:
		rod(Vector3(s*.04,.78,.30),Vector3(s*.29,.67,-.17),.044,.029,ivory)
	if species=="scarab":
		oval(0,.58,-.29,.46,.26,.16,"a78453")
		rod(Vector3(0,.60,-.35),Vector3(0,.94,-.49),.112,.014,ivory)
	elif species=="dungbeetle":
		oval(0,.36,-.92,.35,.35,.35,"af886a")
		p.ring(Vector3(0,.37,-.93),Vector3.RIGHT,.355,.024,gold)
	elif species=="scorpion":
		var tip := Vector3(0,.49,.33)
		for n in 5:
			var next := tip + Vector3(0,.145-n*.018,.15-n*.056)
			rod(tip,next,.13-n*.014,.11-n*.012,trim)
			tip = next
		rod(tip,tip+Vector3(0,-.21,-.19),.091,.006,gold)
	elif species=="turtle":
		for n in 5:
			var x := sin(n*2.2)*.26
			rod(Vector3(x,.68,-.25+n*.13),Vector3(x*1.3,.93,-.24+n*.13),.10,.013,gold)
	for group in 2:
		part("StepA" if group==0 else "StepB", Vector3(0,.34,0))
		for s:float in [-1.,1.]:
			for leg in 2:
				var z:float = -.22+.15*group+.24*leg
				var knee := Vector3(s*(.49+leg*.04),.32,z)
				rod(Vector3(s*.22,.35,z),knee,.058,.054,trim)
				rod(knee,Vector3(s*(.58+leg*.07),.035,z+.08),.057,.013,shadow_col)
			if not shell:
				var claw := Vector3(s*.54,.52,-.34)
				rod(Vector3(s*.29,.34,-.19),claw,.08,.10,skin)
				oval(claw.x,claw.y,claw.z,.15,.155,.23,skin)
				rod(claw,claw+Vector3(s*.14,.03,-.30),.083,.005,ivory)
				rod(claw,claw+Vector3(-s*.055,.10,-.26),.07,.005,gold)

func aquatic() -> void:
	var coil := species in ["leech","worm"]
	var fish := species=="catfish"
	if coil:
		for n in 6:
			var y := .21+n*.092
			oval(sin(n*.9)*.12,y,.44-n*.145,.20+n*.016,.19+n*.012,.225,skin if n%2 else trim)
		var mouth := Vector3(-.11,.71,-.39)
		p.ring(mouth,Vector3.FORWARD,.23,.072,ivory)
		for n in 9:
			var dir := Vector3(cos(TAU*n/9.),sin(TAU*n/9.),0)
			rod(mouth+dir*.2,mouth+dir*.11+Vector3.FORWARD*.04,.025,.002,gold)
		return
	var wide := .44 if species in ["toad","catfish"] else .29
	oval(0,.32,.08,wide,.27,.48,skin)
	oval(0,.38,-.32,wide*.94,.21,.31,skin)
	oval(0,.29,-.38,wide*.80,.13,.26,ivory)
	eyes(wide*.65,.53,-.47)
	for n in 5:
		oval(sin(n*2.8)*.19,.56,-.23+.16*n,.06,.07,.071,gold)
	if fish:
		for s:float in [-1.,1.]:
			rod(Vector3(s*.21,.32,-.54),Vector3(s*.65,.18,-.58),.033,.005,ivory)
			p.tri(Vector3(s*.24,.32,-.16),Vector3(s*.64,.43,.16),Vector3(s*.32,.28,.30),Vector3.UP,p.clr(trim))
	elif species=="lizard":
		for s:float in [-1.,1.]:
			oval(s*.24,.29,-.24,.16,.14,.18,trim)
	elif species=="toad":
		oval(0,.38,-.53,.245,.15,.155,gold)
	elif species=="salamander":
		for s:float in [-1.,1.]:
			rod(Vector3(s*.19,.43,-.26),Vector3(s*.48,.63,-.31),.106,.005,"ff9a50")
	part("Tail",Vector3(0,.32,.37))
	rod(Vector3(0,.32,.32),Vector3(.09,.25,.71),.16,.082,trim)
	rod(Vector3(.09,.25,.71),Vector3(.27,.27,.93),.083,.008,gold)
	if not fish:
		feet4(wide*.73,.26,.23)

func spirit() -> void:
	var lantern := species=="frostlamp"
	if species=="wraith":
		rod(Vector3(0,.33,.04),Vector3(0,1.03,0),.18,.32,trim)
		for n in 6:
			var x := sin(n*2.6)*.24
			rod(Vector3(x,.55,.05),Vector3(x*1.35,.14,.22),.09,.008,ivory)
		oval(0,1.07,0,.26,.30,.23,skin)
		oval(0,1.05,-.18,.175,.175,.09,shadow_col)
		eyes(.09,1.08,-.258,.047)
		return
	oval(0,.73,0,.26,.33,.25,trim if lantern else ivory)
	rod(Vector3(0,1.0,0),Vector3(.06,1.42,.02),.175,.012,gold)
	oval(.01,1.06,-.06,.105,.19,.09,"fff2b9")
	if lantern:
		for s:float in [-1.,1.]:
			for t:float in [-1.,1.]:
				rod(Vector3(s*.16,.45,t*.16),Vector3(s*.16,1.02,t*.16),.032,.032,ivory)
		p.column(0,0,.43,.12,.265,.235,shadow_col,6)
		p.column(0,0,1.0,.15,.29,.095,shadow_col,6)
	elif species=="spark":
		for n in 4:
			var a := TAU*n/4.
			rod(Vector3(cos(a)*.14,.77,sin(a)*.14),Vector3(cos(a)*.43,.98,sin(a)*.43),.10,.004,gold)
	else:
		oval(.11,.68,-.15,.078,.19,.07,ivory)
	eyes(.11,.78,-.214,.052)

func biped() -> void:
	var heavy := species in ["mitten","slaggolem","mudling","treant","furnace","gatekeeper"]
	var h := .57 if heavy else .62
	var w := .37 if heavy else .255
	var head_h := h+.39
	oval(0,h,.03,w,.36,.25,trim)
	oval(0,head_h,-.055,.245,.245,.195,skin)
	eyes(.103,head_h+.018,-.22,.056)
	if species=="drummer":
		oval(0,head_h+.16,0,.49,.23,.46,"bb6147")
		for n in 7:
			var a := n*TAU/7
			oval(cos(a)*.28,head_h+.305,sin(a)*.27,.075,.03,.065,"f8d6a3")
		rod(Vector3(0,.40,-.29),Vector3(0,.76,-.30),.232,.25,"9c623e")
		p.ring(Vector3(0,.759,-.30),Vector3.UP,.25,.035,ivory)
	elif species=="cactus":
		oval(0,.72,0,.33,.52,.30,"658d75")
		for n in 12:
			var a := n*2.4
			var base := Vector3(cos(a)*.27,.45+fmod(n*.19,.58),sin(a)*.25)
			rod(base,base+Vector3(cos(a)*.13,.075,sin(a)*.13),.038,.001,ivory)
		eyes(.13,.85,-.245)
		oval(.09,1.23,.01,.13,.077,.12,"eab094")
	elif species in ["armor","graveguard","spearman","gatekeeper"]:
		p.column(0,-.055,head_h,.23,.28,.16,shadow_col,8)
		p.block(Vector3(0,head_h+.015,-.20),Vector3(.40,.075,.09),ivory)
		p.block(Vector3(0,head_h+.015,-.255),Vector3(.29,.022,.024),gold)
	elif species in ["lamplighter","seamstress","coachman","bellman"]:
		p.column(0,-.02,head_h+.12,.15,.40,.20,shadow_col,10)
		if species in ["coachman","bellman"]:
			p.column(0,-.02,head_h+.20,.27,.20,.19,trim,8)
		rod(Vector3(0,.24,.05),Vector3(0,.78,.01),.37,.23,trim)
	elif species in ["furnace","smith","slaggolem"]:
		p.block(Vector3(0,.70,-.20),Vector3(.40,.30,.15),shadow_col)
		for n in 3:
			p.block(Vector3((n-1)*.10,.72,-.28),Vector3(.042,.19,.035),gold)
		for s:float in [-1.,1.]:
			rod(Vector3(s*.20,.80,.12),Vector3(s*.26,1.29,.15),.11,.09,shadow_col)
	elif species in ["mudling","mitten","treant"]:
		for n in 5:
			var a := n*2.4
			oval(cos(a)*.19,1.02+sin(a)*.14,sin(a)*.16,.15,.125,.145,ivory if species=="mitten" else skin)
	match species:
		"coachman":
			p.block(Vector3(0,.38,.23),Vector3(.71,.30,.52),"53495c")
			for side:float in [-1.,1.]:
				p.ring(Vector3(side*.39,.27,.23),Vector3.RIGHT,.237,.054,ivory,16)
				rod(Vector3(side*.27,.51,.31),Vector3(side*.27,1.06,.34),.034,.030,ivory)
				oval(side*.31,.71,-.27,.088,.112,.083,gold)
			p.block(Vector3(0,1.08,.30),Vector3(.67,.115,.42),trim)
		"gatekeeper":
			for side:float in [-1.,1.]:
				p.block(Vector3(side*.33,.85,.15),Vector3(.13,.94,.19),"557c77")
				p.ring(Vector3(side*.32,1.23,.04),Vector3.FORWARD,.105,.035,gold)
			for bar in 4:
				p.block(Vector3(0,.51+bar*.17,.18),Vector3(.68,.085,.17),ivory)
			p.block(Vector3(0,.63,-.19),Vector3(.40,.35,.08),shadow_col)
			for bar in 4:
				p.block(Vector3((bar-1.5)*.09,.63,-.24),Vector3(.040,.26,.04),gold)
		"seamstress":
			for side:float in [-1.,1.]:
				var a:=Vector3(side*.28,.61,.16)
				var b:=Vector3(side*.38,.90,.16)
				rod(a,b,.13,.13,gold)
				oval(a.x,a.y,a.z,.16,.055,.15,ivory)
				oval(b.x,b.y,b.z,.16,.055,.15,ivory)
			for n in 5:
				var a:=Vector3(-.15+n*.071,.50+n*.034,-.25)
				rod(a,a+Vector3(.066,.045,0),.013,.013,gold)
			rod(Vector3(.19,.62,.12),Vector3(.41,1.45,.24),.025,.003,ivory)
			p.ring(Vector3(-.25,1.13,.19),Vector3.FORWARD,.079,.019,gold)
		"furnace":
			for side:float in [-1.,1.]:
				for n in 4:
					oval(side*.34,.47+n*.085,.08,.19,.052,.23,ivory if n%2 else shadow_col)
				p.block(Vector3(side*.28,.99,.15),Vector3(.21,.11,.24),trim)
			p.ring(Vector3(0,.72,-.27),Vector3.FORWARD,.232,.046,ivory,12)
	for s:float in [-1.,1.]:
		part("StepA" if s<0 else "StepB",Vector3(s*.14,.49,0))
		rod(Vector3(s*.13,.46,.025),Vector3(s*.20,.12,-.015),.112,.083,shadow_col)
		oval(s*.20,.09,-.05,.13,.088,.17,skin)
		var hand := Vector3(s*(w+.13),h-.03,-.12)
		rod(Vector3(s*w*.75,h+.15,0),hand,.090,.069,skin)
		oval(hand.x,hand.y,hand.z,.15 if heavy else .09,.13,.12,ivory)
		if species in ["drummer","smith"]:
			rod(hand,hand+Vector3(s*.06,.25,-.17),.030,.047,ivory)
			oval(hand.x+s*.06,hand.y+.26,hand.z-.17,.13 if species=="smith" else .070,.078,.084,gold)
		elif species in ["armor","spearman","seamstress"] and s>0:
			rod(hand-Vector3.UP*.25,hand+Vector3.UP*.45,.034,.033,shadow_col)
			rod(hand+Vector3.UP*.42,hand+Vector3.UP*.88,.095,.002,ivory)
		elif species in ["lamplighter","bellman"] and s>0:
			rod(hand,hand+Vector3.UP*.49,.035,.035,ivory)
			p.column(hand.x+.02,hand.z,hand.y+.25,.22,.155,.09,gold,8)
		elif species in ["graveguard","gatekeeper"] and s<0:
			p.block(hand+Vector3(0,.07,-.07),Vector3(.36,.62,.13),shadow_col)
			p.block(hand+Vector3(0,.08,-.15),Vector3(.255,.45,.035),ivory)
		elif species in ["treant","furnace","coachman"] and s<0:
			p.ring(Vector3(s*.39,.82,.02),Vector3.RIGHT,.38,.085,ivory,20)
			for n in 4:
				var spoke := Vector3(0,sin(n*PI/4.)*.32,cos(n*PI/4.)*.32)
				var hub := Vector3(s*.39,.82,.02)
				rod(hub-spoke,hub+spoke,.029,.029,skin)

func play(next:String, duration:=0.0) -> void:
	if next==pose and age>0 and next in ["Idle","Run"]:
		return
	pose = next
	age = 0.0
	if not animator:
		return
	for key in animator.get_animation_list():
		if str(key).get_slice("/",str(key).count("/")).to_lower()==next.to_lower():
			var clip := animator.get_animation(key)
			var rate := clip.length/duration if duration>0.0 and clip.length>0.01 else 1.0
			animator.play(key, .08, rate)
			return

func advance(delta:float) -> void:
	age += delta
	clock += delta
	if animator:
		return
	var step := sin(clock*(10 if pose=="Run" else 3))
	var bounce := .04 if pose=="Run" else .012
	body.position.y = absf(step)*bounce + (.045*sin(clock*3.6) if flying else 0.)
	body.rotation.x = -.18*clampf(age*5.,0.,1.) if pose=="Windup" else 0.0
	if pose=="Attack":
		body.rotation.x = .22*maxf(0.,1.-age*2.)
	elif pose=="Hit":
		body.rotation.z = sin(age*24)*.12
	elif pose=="Death":
		body.rotation.z = minf(1.35,age*2.7)
		body.position.y = -minf(.25,age*.5)
	else:
		body.rotation.z = 0
	for piece in pieces:
		var label := str(piece.name)
		match label:
			"StepA","StepB":
				piece.rotation.x = step*(.22 if pose=="Run" else .026)*(1 if label=="StepA" else -1)
			"WingL","WingR":
				piece.rotation.z = sin(clock*(20.0 if species=="bee" else 8.0))*.46*(1 if label=="WingR" else -1)
			"Tail":
				piece.rotation.y = step*.16
			"ArmL","ArmR":
				piece.rotation.x = -.45*clampf(age*3.,0.,1.) if pose=="Windup" else (.58*maxf(0.,1.-age*2.) if pose=="Attack" else step*.045)
			_:
				if label.begins_with("Head"):
					piece.rotation.y=sin(clock*2.+float(label.right(1)))*.13
