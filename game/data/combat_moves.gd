extends RefCounted

# 시작 프레임을 0으로 센다. 판정과 이동 거리는 렌더 프레임과 독립적이다.
const MOVES := {
	"attack1": {"clip":"Attack1", "windup":7, "active":4, "recovery":13, "range":1.7, "angle":80.0, "power":1.0},
	"attack2": {"clip":"Attack2", "windup":9, "active":5, "recovery":14, "range":1.9, "angle":110.0, "power":1.15},
	"attack3": {"clip":"Attack3", "windup":15, "active":6, "recovery":21, "range":2.1, "angle":65.0, "power":1.65},
	"dodge": {"clip":"Dodge", "windup":4, "active":8, "recovery":12, "cooldown":1.3, "distance":2.6},
	"hook": {"clip":"Hook", "windup":12, "active":5, "recovery":18, "range":6.0, "width":0.8, "power":0.8, "cooldown":5.0},
	"spin": {"clip":"Spin", "windup":10, "active":18, "recovery":18, "range":2.4, "angle":360.0, "power":0.75, "cooldown":7.0},
	"slam": {"clip":"Slam", "windup":22, "active":5, "recovery":26, "range":2.8, "angle":70.0, "power":2.4, "cooldown":10.0},
}
