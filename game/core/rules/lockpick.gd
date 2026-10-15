## 자물쇠 따기(SD-12 §8.1·§8.2, 단계 1-5): 정면 원판 — 머리핀 각도(0~180°) + 드라이버 회전.
## 정답 각도 θ* 10~170° · 허용 반폭 30/18/10/6/3°(+스킬이 요구치를 넘는 10점마다 1°, 최대 +5°) ·
## 최대 회전 = 90° × clamp(1 − (|θ − θ*| − w) ÷ 60°, 0, 1), 오차가 w 안이면 90°까지 돌아 열림 ·
## 최대 회전에 닿은 뒤에도 누르고 있으면 핀 손상(초당 25/30/35/45/55, 내구 100) → 0이면 머리핀 1개 소모, θ*는 그대로 ·
## 강제 개방 성공률 = 스킬 − 요구치 + 10(%, 최대 95), 실패하면 자물쇠 영구 파손 · 요구치 미달이면 시도할 수 없다 · XP 20~60.
class_name Lockpick
extends RefCounted

const REQ := [0, 25, 50, 75, 100]
const NAMES := ["매우 쉬움", "쉬움", "보통", "어려움", "매우 어려움"]
const HALF := [30.0, 18.0, 10.0, 6.0, 3.0]
const WEAR := [25.0, 30.0, 35.0, 45.0, 55.0]
const XP := [20, 30, 40, 50, 60]
const TURN_SPEED := 150.0                         ## 누르는 동안 초당 도는 각도(°)
const BACK_SPEED := 300.0                         ## 떼면 되돌아오는 속도

var g := 0                                        ## 등급 0~4
var skill := 0
var target := 90.0                                ## θ*
var w := 30.0
var angle := 90.0                                 ## 머리핀 θ
var turn := 0.0                                   ## 드라이버 회전량(°)
var pins := 0
var pin_hp := 100.0
var state := "play"                               ## play · open · jammed(강제 개방 실패, 영구 파손) · no_pins
var rng := RandomNumberGenerator.new()


## 자물쇠 값(맵의 lock=25 등) → 등급(그 값 이하에서 가장 높은 요구치)
static func grade_of(lock_value: int) -> int:
	var gi := 0
	for i in REQ.size():
		if lock_value >= int(REQ[i]):
			gi = i
	return gi


static func can_try(lock_value: int, skill_v: int) -> bool:
	return skill_v >= int(REQ[grade_of(lock_value)])


static func half_width(gi: int, skill_v: int) -> float:
	return HALF[gi] + float(mini(5, maxi(0, (skill_v - int(REQ[gi])) / 10)))


static func force_chance(gi: int, skill_v: int) -> int:
	return clampi(skill_v - int(REQ[gi]) + 10, 0, 95)


func _init(gi := 0, skill_v := 0, hairpins := 1, seed := 0) -> void:
	g = clampi(gi, 0, 4)
	skill = skill_v
	pins = hairpins
	rng.seed = seed if seed != 0 else int(Time.get_ticks_usec())
	target = rng.randf_range(10.0, 170.0)
	w = half_width(g, skill)
	if pins <= 0:
		state = "no_pins"


## 지금 각도에서 드라이버가 돌 수 있는 최대량(°)
func max_turn(a: float = -1.0) -> float:
	var th := angle if a < 0.0 else a
	return 90.0 * clampf(1.0 - (absf(th - target) - w) / 60.0, 0.0, 1.0)


## 한 틱: 누르고 있으면 돌리고(막히면 핀이 닳는다), 떼면 되돌아온다. 돌려주는 사건: "" · "open" · "pin_broke" · "no_pins"
func step(dt: float, turning: bool) -> String:
	if state != "play":
		return ""
	var mx := max_turn()
	if not turning:
		turn = maxf(0.0, turn - BACK_SPEED * dt)
		return ""
	if turn < mx:
		turn = minf(mx, turn + TURN_SPEED * dt)
		if turn >= 90.0 - 0.001:
			state = "open"
			return "open"
		return ""
	pin_hp -= WEAR[g] * dt                                             # 막힌 채 더 돌리면 핀이 닳는다
	if pin_hp <= 0.0:
		pins -= 1
		pin_hp = 100.0
		turn = 0.0
		if pins <= 0:
			state = "no_pins"
			return "no_pins"
		return "pin_broke"
	return ""


## 머리핀 각도를 바꾼다(돌리는 중에는 핀이 걸려 움직이지 않는다 — 원작처럼 떼고 옮긴다)
func set_angle(a: float) -> void:
	if turn > 0.5:
		return
	angle = clampf(a, 0.0, 180.0)


## 강제 개방(F): 성공이면 열림, 실패면 영구 파손
func force() -> bool:
	if state not in ["play", "no_pins"]:
		return false
	if rng.randi_range(1, 100) <= force_chance(g, skill):
		state = "open"
		return true
	state = "jammed"
	return false


## 근접도 0~1(자물쇠 보조 막대)
func closeness() -> float:
	return clampf(1.0 - maxf(0.0, absf(angle - target) - w) / 60.0, 0.0, 1.0)


func xp() -> int:
	return XP[g]
