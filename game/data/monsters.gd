extends RefCounted

## 종별 반경은 공격 사정거리 계산과 물리 충돌이 함께 쓴다.
const NAMES := preload("res://data/monsters_ko.tres")
# 외형, 행동, 체력, 위력, 이동 속도, 공격을 준비하는 거리, 몸 반경.
const NORMAL := [
	[["mouse","bite",24,4,2.65,1.35,.38],["bee","needle",20,5,2.10,5.8,.34],
	 ["boar","charge",38,6,1.7,4.2,.54],["scarab","shield",33,4,1.38,1.55,.49],
	 ["drummer","haste",26,4,1.55,3.1,.43],["cone_urchin","cone_burst",31,5,1.45,3.8,.48],
	 ["branch_mantis","branch_shear",29,6,2.14,2.6,.42],["nectar_sprite","nectar_heal",23,3,1.7,4.2,.36],
	 ["logsnail","log_guard",42,5,1.18,2.0,.60],["lantern_owl","owl_swoop",25,5,2.38,5.2,.43]],
	[["jerboa","leap",22,5,2.45,3.6,.38],["scorpion","shards",29,5,1.62,5.2,.55],
	 ["lizard","sand",28,5,1.62,4.0,.48],["dungbeetle","boulder",35,6,1.45,4.9,.54],
	 ["wraith","flank",24,5,2.25,1.65,.38],["cactus","spines",33,4,1.1,4.2,.48],
	 ["dune_vulture","crosswind",27,6,2.35,4.7,.45],["oasis_sage","oasis_heal",29,3,1.45,4.4,.41],
	 ["sandshield","sand_guard",43,5,1.25,2.1,.59],["hourglass","sand_clock",28,6,1.5,5.2,.40]],
	[["candle","haunt",24,5,2.22,1.6,.36],["crow","dive",20,6,2.7,4.3,.38],
	 ["graveguard","shove",36,6,1.46,2.2,.49],["lamplighter","heal",27,4,1.55,3.4,.43],
	 ["armor","cleave",38,8,1.50,2.0,.54],["bonehound","bone_pounce",26,6,2.75,3.7,.44],
	 ["gravearcher","grave_volley",24,6,1.75,6.0,.40],["coffin","coffin_latch",45,7,1.13,2.6,.60],
	 ["bellwisp","dirge",23,5,1.7,4.6,.36],["shroudweaver","shroud_stitch",30,6,1.8,5.1,.46]],
	[["spearman","thrust",26,6,1.92,3.3,.42],["toad","poison",30,5,1.35,4.8,.52],
	 ["leech","pull",23,5,2.22,3.1,.36],["moth","mirror",22,5,2.2,4.9,.42],
	 ["sluicecrab","sidestep",36,5,1.7,1.75,.54],["mudling","split",30,4,1.68,1.7,.47],
	 ["reedarcher","reed_fan",25,6,1.88,5.8,.39],["mossheron","heron_heal",28,3,1.55,4.6,.44],
	 ["bogclam","clam_snap",46,7,1.12,2.5,.64],["dragonfly","water_skim",24,5,2.8,4.7,.34]],
	[["fox","juke",24,5,2.55,1.75,.4],["icebat","drop",22,6,2.25,4.2,.36],
	 ["mitten","pound",43,8,1.3,2.05,.64],["bellgoat","double_charge",32,6,1.9,4.3,.51],
	 ["frostlamp","ice",25,5,1.55,4.6,.38],["snowhare","hare_skate",25,5,2.9,4.3,.38],
	 ["crystalurchin","icicle_fan",33,6,1.3,5.2,.49],["snowmender","snow_heal",30,3,1.45,4.3,.43],
	 ["pineshield","pine_guard",45,6,1.2,2.3,.60],["owlfrost","snow_cross",26,6,2.25,5.1,.44]],
	[["salamander","leap",27,6,2.05,3.8,.46],["bellowsbat","gust",23,5,2.23,3.5,.39],
	 ["turtle","carapace",44,6,1.26,1.8,.63],["spark","fork",24,5,1.9,4.7,.38],
	 ["forgecrab","pincers",34,6,1.78,1.9,.56],["slaggolem","seismic",46,8,1.25,3.1,.67],
	 ["slaglobster","smelt",40,7,1.38,3.5,.60],["ashpriest","ash_heal",29,4,1.6,4.5,.42],
	 ["cinderscorpion","ember_tail",32,6,1.95,4.7,.50],["obsidianspire","eruption",44,8,1.0,5.0,.57]]
]
const MINI := [
	["deer","antler",100,9,2.6,6.6,.72],["worm","burrow",115,10,2.0,6.0,.74],
	["bellman","double_bell",112,9,1.75,5.0,.7],["catfish","breach",118,10,1.9,6.1,.75],
	["ram","ice_ram",123,11,2.22,6.5,.73],["smith","hammer",126,12,1.87,4.6,.77]]
const MINI_SECOND := [
	["badger_captain","timber_sweep",110,10,2.05,5.8,.79],
	["sand_tortoise","mirage_lanes",125,10,1.55,6.1,.86],
	["bone_conductor","requiem",118,11,1.8,5.8,.73],
	["mire_hydra","hydra_spit",128,11,1.7,6.0,.88],
	["frost_mammoth","glacier",138,12,1.72,6.3,.92],
	["basalt_drake","kiln_breath",142,12,1.9,6.4,.87]]
const BOSS := [
	["treant","wheel",340,14,1.25,7.8,1.04],["camel","crystals",340,14,1.45,7.5,1.02],
	["coachman","carriage",335,15,1.44,7.6,.94],["gatekeeper","sluice",360,14,1.42,7.1,1.02],
	["seamstress","seams",350,15,1.53,7.3,.92],["furnace","bellows",380,16,1.3,7.3,1.08]]

const NORMAL_CAP := [16,24,32,40]
# 앞줄 방어, 원거리, 회복. 소지역 특산 두 종에 이 역할 셋을 함께 배치한다.
const GROUPS := [Vector3i(3,1,7),Vector3i(8,1,7),Vector3i(2,6,3),Vector3i(4,6,7),Vector3i(8,6,7),Vector3i(2,3,7)]

static func species(region:int, kind:String, index:=0) -> Array:
	if kind == "normal":
		return NORMAL[region][posmod(index,NORMAL[region].size())]
	if kind == "mini":
		return MINI[region] if posmod(index,2)==0 else MINI_SECOND[region]
	return BOSS[region]

static func display_key(region:int, kind:String, index:int) -> String:
	if kind=="normal":
		return "NORMAL_%d_%d"%[region,posmod(index,10)]
	if kind=="mini" and posmod(index,2)==1:
		return "MINI_%d_1"%region
	return "%s_%d"%[kind.to_upper(),region]

static func population(region:int, district:int) -> Array[int]:
	var roles:Vector3i=GROUPS[region]
	var niche:=posmod(district,5)*2
	return [niche,niche,(niche+1)%10,(niche+1)%10,(niche+2)%10,(niche+3)%10,roles.x,roles.y,roles.z]

static func normal_cap(rank:int) -> int:
	return NORMAL_CAP[clampi(rank,0,3)]
