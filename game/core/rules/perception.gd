## 인지: 시야·탐지 게이지·소리 (SD-11 §7.3). 엔진 무관 순수 함수.
class_name Perception
extends RefCounted

const BASE_RATE := 120.0
const FOV := {"human": 120.0, "dog": 160.0, "insect": 240.0, "robot": 90.0, "turret": 360.0}
const POSTURE := {"stand": 1.0, "crouch": 0.5}
const LIGHT := {"bright": 1.0, "dark": 0.6, "pitch": 0.35}
const MOVE := {"still": 0.5, "sneak": 0.8, "move": 1.0, "sprint": 1.5, "fired": 2.0}
## 소리: [반경 t, 게이지 가산]
const SOUND := {"sneak": [0.5, 10.0], "move": [2.0, 20.0], "sprint": [5.0, 35.0], "melee": [3.0, 40.0],
	"suppressed": [2.0, 30.0], "pistol": [12.0, 60.0], "rifle": [16.0, 60.0], "heavy": [20.0, 80.0],
	"impact": [3.0, 35.0], "explosion": [18.0, 100.0], "door": [3.0, 30.0]}


static func sight_range(per: float) -> float:
	return 8.0 + 0.6 * per


## 표적이 관찰자 시야각 안인가(전방 벡터와 표적 방향). 3t 안 주변 감지는 별도 계수 0.3.
static func in_fov(forward: Vector2, to_target: Vector2, kind: String) -> bool:
	var half := deg_to_rad(FOV.get(kind, 120.0) / 2.0)
	if to_target.length_squared() < 0.0001:
		return true
	return absf(forward.angle_to(to_target)) <= half


## 초당 증가 = 120 × 거리 × 자세 × 조명 × 움직임 × 은신 × 인지 × 상태
static func detect_rate(dist_t: float, per: float, ctx: Dictionary = {}) -> float:
	var sr := sight_range(per)
	if dist_t > sr:
		return 0.0
	var k_dist := maxf(0.1, 1.0 - pow(dist_t / sr, 1.5))
	var posture: String = ctx.get("posture", "stand")
	var k_stealth := 1.0
	if posture == "crouch":
		k_stealth = 1.0 - ctx.get("sneak_skill", 0.0) / 150.0
	var k_per := 0.6 + 0.08 * per
	var k_state := 1.5 if ctx.get("alert", false) else 1.0
	if ctx.get("head_crippled", false):
		k_state *= 0.6
	var k_fov := 1.0 if ctx.get("in_fov", true) else (0.3 if dist_t <= 3.0 else 0.0)
	return BASE_RATE * k_dist * POSTURE[posture] * LIGHT[ctx.get("light", "bright")] \
		* MOVE[ctx.get("movement", "move")] * k_stealth * k_per * k_state * k_fov


## 소리 사건의 게이지 가산(벽 1장 ×0.5 반경, 2장 ×0.25). 범위 밖이면 0.
static func sound_gain(kind: String, dist_t: float, walls: int = 0) -> float:
	var s: Array = SOUND[kind]
	var r: float = s[0] * pow(0.5, walls)
	return s[1] if dist_t <= r else 0.0
