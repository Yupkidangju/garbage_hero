extends RefCounted

## 종별 반경은 공격 사정거리 계산과 물리 충돌이 함께 쓴다.
const NAMES := preload("res://data/monsters_ko.tres")
# 외형, 행동, 체력, 위력, 이동 속도, 공격을 준비하는 거리, 몸 반경.
const NORMAL := [
	[["mouse","bite",24,4,2.65,1.35,.38],["bee","needle",20,5,2.10,5.8,.34],
	 ["boar","charge",38,6,1.7,4.2,.54],["scarab","shield",33,4,1.38,1.55,.49],
	 ["drummer","haste",26,4,1.55,3.1,.43]],
	[["jerboa","leap",22,5,2.45,3.6,.38],["scorpion","shards",29,5,1.62,5.2,.55],
	 ["lizard","sand",28,5,1.62,4.0,.48],["dungbeetle","boulder",35,6,1.45,4.9,.54],
	 ["wraith","flank",24,5,2.25,1.65,.38],["cactus","spines",33,4,1.1,4.2,.48]],
	[["candle","haunt",24,5,2.22,1.6,.36],["crow","dive",20,6,2.7,4.3,.38],
	 ["graveguard","shove",36,6,1.46,2.2,.49],["lamplighter","heal",27,4,1.55,3.4,.43],
	 ["armor","cleave",38,8,1.50,2.0,.54]],
	[["spearman","thrust",26,6,1.92,3.3,.42],["toad","poison",30,5,1.35,4.8,.52],
	 ["leech","pull",23,5,2.22,3.1,.36],["moth","mirror",22,5,2.2,4.9,.42],
	 ["sluicecrab","sidestep",36,5,1.7,1.75,.54],["mudling","split",30,4,1.68,1.7,.47]],
	[["fox","juke",24,5,2.55,1.75,.4],["icebat","drop",22,6,2.25,4.2,.36],
	 ["mitten","pound",43,8,1.3,2.05,.64],["bellgoat","double_charge",32,6,1.9,4.3,.51],
	 ["frostlamp","ice",25,5,1.55,4.6,.38]],
	[["salamander","leap",27,6,2.05,3.8,.46],["bellowsbat","gust",23,5,2.23,3.5,.39],
	 ["turtle","carapace",44,6,1.26,1.8,.63],["spark","fork",24,5,1.9,4.7,.38],
	 ["forgecrab","pincers",34,6,1.78,1.9,.56],["slaggolem","seismic",46,8,1.25,3.1,.67]]
]
const MINI := [
	["deer","antler",100,9,2.6,6.6,.72],["worm","burrow",115,10,2.0,6.0,.74],
	["bellman","double_bell",112,9,1.75,5.0,.7],["catfish","breach",118,10,1.9,6.1,.75],
	["ram","ice_ram",123,11,2.22,6.5,.73],["smith","hammer",126,12,1.87,4.6,.77]]
const BOSS := [
	["treant","wheel",340,14,1.25,7.8,1.04],["camel","crystals",340,14,1.45,7.5,1.02],
	["coachman","carriage",335,15,1.44,7.6,.94],["gatekeeper","sluice",360,14,1.42,7.1,1.02],
	["seamstress","seams",350,15,1.53,7.3,.92],["furnace","bellows",380,16,1.3,7.3,1.08]]

static func species(region:int, kind:String, index:int) -> Array:
	if kind == "normal":
		return NORMAL[region][index % NORMAL[region].size()]
	if kind == "mini":
		return MINI[region]
	return BOSS[region]
