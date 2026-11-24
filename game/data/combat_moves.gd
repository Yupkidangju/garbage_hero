extends RefCounted

# 시작 프레임을 0으로 센다. 판정과 이동 거리는 렌더 프레임과 독립적이다.
const MOVES := {
	"attack1": {"clip":"Attack1", "windup":7, "active":4, "recovery":13, "range":1.7, "angle":80.0, "power":1.0},
	"attack2": {"clip":"Attack2", "windup":9, "active":5, "recovery":14, "range":1.9, "angle":110.0, "power":1.15},
	"attack3": {"clip":"Attack3", "windup":15, "active":6, "recovery":21, "range":2.1, "angle":65.0, "power":1.65},
	"mace": {"clip":"MaceCrush", "windup":17, "active":5, "recovery":20, "range":1.85, "angle":100.0, "power":1.85},
	"spear": {"clip":"SpearThrust", "windup":9, "active":5, "recovery":16, "range":3.5, "angle":24.0, "power":1.18},
	"bow": {"clip":"BowDraw", "windup":11, "active":1, "recovery":14, "range":12.0, "speed":18.0, "power":1.0},
	"staff": {"clip":"StaffCast", "windup":17, "active":1, "recovery":17, "range":9.5, "speed":12.0, "power":1.58},
	"dodge": {"clip":"Dodge", "windup":4, "active":8, "recovery":12, "cooldown":1.3, "distance":2.6},
	"hook": {"clip":"Hook", "windup":12, "active":5, "recovery":18, "range":6.0, "width":0.8, "power":0.8, "cooldown":5.0},
	"spin": {"clip":"Spin", "windup":10, "active":18, "recovery":18, "range":2.4, "angle":360.0, "power":0.75, "cooldown":7.0},
	"slam": {"clip":"Slam", "windup":22, "active":5, "recovery":26, "range":2.8, "angle":70.0, "power":2.4, "cooldown":10.0},
	"volley": {"clip":"Volley", "windup":11, "active":1, "recovery":18, "range":10.0, "speed":16.0, "power":0.85, "cooldown":6.0},
	"nova": {"clip":"Nova", "windup":18, "active":4, "recovery":24, "range":3.6, "angle":360.0, "power":1.8, "cooldown":9.0},
	"rush": {"clip":"Rush", "windup":6, "active":12, "recovery":16, "range":1.05, "angle":90.0, "distance":3.6, "power":1.3, "cooldown":5.0},
}

const SLOT_ACTIONS := ["hook", "spin", "slam"]
const WEAPON_ATTACKS := ["bow", "staff", "spear", "mace"]

# 새 도안만 별도 준비/회복/거리를 쓴다. 기존 저장의 0~28번은 기본 프레임 그대로다.
const GEAR_PROFILES := {
	"starwheel_longsword":{"windup_delta":2,"recovery_delta":1,"range_scale":1.15},
	"hourglass_longbow":{"windup":15,"recovery":16,"range":14.4,"speed":20.7},
	"bell_shortbow":{"windup":8,"recovery":11,"range":10.2,"speed":18.0},
	"lily_foldingbow":{"windup":9,"recovery":14,"range":10.8,"speed":18.0},
	"bellows_pulleybow":{"windup":17,"recovery":17,"range":13.0,"speed":22.0},
	"comet_orbitbow":{"windup":13,"recovery":15,"range":13.0,"speed":21.0},
	"acorn_lantern":{"windup":14,"recovery":15,"range":8.5,"speed":13.0},
	"funeral_candelabrum":{"windup":21,"recovery":19,"range":10.7,"speed":12.0},
	"lily_sluice":{"windup":15,"recovery":16,"range":10.5,"speed":14.0},
	"icicle_baton":{"windup":13,"recovery":14,"range":9.0,"speed":16.0},
	"furnace_blower":{"windup":23,"recovery":20,"range":11.0,"speed":10.0},
	"armillary_compass":{"windup":18,"recovery":16,"range":12.0,"speed":15.0},
	"pine_fork":{"windup":7,"recovery":14,"range":3.15,"angle":32.0},
	"scorpion_tail":{"windup":13,"recovery":18,"range":4.0,"angle":20.0},
	"tomb_banner":{"windup":8,"recovery":17,"range":3.8,"angle":30.0},
	"goat_horn_pike":{"windup":10,"recovery":14,"range":3.9,"angle":20.0},
	"chimney_awl":{"windup":14,"recovery":18,"range":4.25,"angle":18.0},
	"ford_trident":{"windup":11,"recovery":17,"range":4.0,"angle":38.0},
	"acorn_mallet":{"windup":13,"recovery":16,"range":1.7,"angle":110.0},
	"glass_mortar":{"windup":22,"recovery":24,"range":2.05,"angle":85.0},
	"sluice_cog":{"windup":15,"recovery":21,"range":2.15,"angle":120.0},
	"glacier_pendulum":{"windup":20,"recovery":22,"range":2.25,"angle":110.0},
	"oscillator_hammer":{"windup":18,"recovery":18,"range":2.1,"angle":120.0},
}


static func for_gear(action: String, gear: Dictionary) -> Dictionary:
	var result: Dictionary = MOVES.get(action, {}).duplicate(true)
	if int(gear.get("design",-1)) < 29 or action not in ["attack1","attack2","attack3","bow","staff","spear","mace"]:
		return result
	var profile: Dictionary = GEAR_PROFILES.get(str(gear.get("visual",{}).get("shape","")),{})
	for key in ["windup","recovery","range","speed","angle"]:
		if profile.has(key):
			result[key] = profile[key]
	for key in ["windup","recovery"]:
		result[key] = int(result[key])+int(profile.get(key+"_delta",0))
	result.range *= float(profile.get("range_scale",1.0))
	return result
