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
