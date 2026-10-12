## 이동 미끄러짐 금지 규칙 (SD-16 §3.6.5, SD-11 §2.4). 엔진 무관 상태 모듈: 노드 없이 Vector2·숫자만 쓴다.
##  ① 거리 구동 재생: 프레임은 실제 이동 거리로 넘긴다(직교 frame_px, 대각선 diag_px × diag_px).
##  ② 단계 렌더: 그림 위치는 마지막 프레임 경계. 프레임이 바뀔 때 정확히 프레임 거리만큼만 나간다.
##  ④ 관성 없음: 첫 틱 100%, 놓으면 그 자리 정지. 들린 발 프레임에서 멈추면 디딤 자세 1장(4틱) 뒤 대기.
##  ⑤ 실제 이동 기준: 벽에 막힌 축은 재생에서 뺀다. 이동 0이면 대기(제자리걸음 없음).
##  ⑥ 조준과 이동이 90°를 넘게 벌어지면 하체는 조준 쪽을 보고 역재생(뒷걸음 속도 85%).
class_name Locomotion
extends RefCounted

## 8방향 이름(화면 좌표: +y가 아래 = S). 인덱스 0 = E에서 시계 방향.
const DIRS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const VEC := [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1)]
## 모션 표: 프레임 수, 직교 프레임 거리, 대각선 축 거리, 디딤 프레임(정지 때 보여 줄 수 있는 프레임)
const MOTIONS := {
	"walk": {"frames": 6, "px": 6.0, "diag": 4.0, "contact": [0, 3], "speed_t": 3.0},
	"run": {"frames": 6, "px": 8.0, "diag": 6.0, "contact": [0, 3], "speed_t": 4.5},
}
const TILE := 32.0
const STOP_TICKS := 4
const BACK_SPEED := 0.85

var logical := Vector2.ZERO          ## 판정·충돌 위치(픽셀, 소수 허용)
var render := Vector2.ZERO           ## 그림 위치(마지막 프레임 경계, 정수)
var motion := "idle"
var frame := 0
var facing := 2                      ## DIRS 인덱스 (기본 S)
var reverse := false
var _acc := 0.0
var _move_dir := -1
var _stop_left := 0
var frames_advanced := 0             ## 시험용: 누적 프레임 수
var custom := {}                     ## 크리처 등 종별 모션 표(SD-16 §3.6.4: 종마다 데이터)


func _init(pos: Vector2 = Vector2.ZERO) -> void:
	logical = pos
	render = pos.round()


## 아날로그 입력을 가장 가까운 8방향 인덱스로. 입력이 작으면 -1.
static func snap8(v: Vector2, dead: float = 0.2) -> int:
	if v.length() < dead:
		return -1
	var a := fposmod(atan2(v.y, v.x), TAU)
	return int(round(a / (TAU / 8.0))) % 8


## 실제 이동 벡터의 8방향(축별 부호).
static func dir_of(delta: Vector2) -> int:
	var sx := signf(snappedf(delta.x, 0.0001))
	var sy := signf(snappedf(delta.y, 0.0001))
	if sx == 0 and sy == 0:
		return -1
	for i in 8:
		if VEC[i] == Vector2(sx, sy):
			return i
	return -1


## 한 틱 진행. input: 이동 입력(아날로그 가능), aim_dir: 조준 8방향(-1 = 조준 없음),
## blocked: Callable(from: Vector2, to: Vector2) -> Vector2 (충돌 처리 뒤 실제 도착점). 없으면 자유 이동.
func step(input: Vector2, dt: float, mode: String = "walk", aim_dir: int = -1, blocked: Callable = Callable()) -> void:
	var want := snap8(input)
	if want < 0:
		_stop()
		return
	var m: Dictionary = custom.get(mode, MOTIONS.get(mode, {}))
	var back := aim_dir >= 0 and _angle_between(want, aim_dir) > 2      # > 90°
	var speed: float = m["speed_t"] * TILE * (BACK_SPEED if back else 1.0)
	var dv: Vector2 = VEC[want].normalized() * speed * dt
	var target := logical + dv
	var arrived: Vector2 = target if not blocked.is_valid() else blocked.call(logical, target)
	var actual: Vector2 = arrived - logical
	var before := logical
	logical = arrived
	var d := dir_of(actual)
	if d < 0:                                                        # ⑤ wall: no treadmill
		_stop()
		return
	_stop_left = 0
	if motion != mode or d != _move_dir:
		_acc = 0.0
		render = before.round()                                       # stride starts where the feet were
		if motion != mode:
			frame = 0
		motion = mode
		_move_dir = d
	reverse = back
	facing = (aim_dir if back else d)
	if back:
		facing = (d + 4) % 8                                          # lower body looks toward the aim side
	var diag := d % 2 == 1
	var per: float = m["diag"] if diag else m["px"]
	_acc += maxf(absf(actual.x), absf(actual.y)) if diag else actual.length()
	while _acc >= per - 0.0001:
		_acc = maxf(0.0, _acc - per)
		frame = (frame + (m["frames"] - 1 if reverse else 1)) % m["frames"]
		frames_advanced += 1
		render += VEC[d] * per                                      # ② exactly one frame distance
	render = render.round()


func _stop() -> void:
	if motion == "idle":
		return
	var m: Dictionary = custom.get(motion, MOTIONS.get(motion, {}))
	if _stop_left == 0 and not m.is_empty() and not (frame in m["contact"]):
		# ④ lifted foot: show the nearest contact pose for STOP_TICKS, then idle
		var c: Array = m["contact"]
		frame = c[0] if absi(frame - c[0]) <= absi(frame - c[1]) else c[1]
		_stop_left = STOP_TICKS
		logical = render                                             # 판정을 그림 위치로 되돌린다(차이 < 프레임 거리)
		return
	if _stop_left > 1:
		_stop_left -= 1
		return
	_stop_left = 0
	logical = render
	motion = "idle"
	frame = 0
	_acc = 0.0
	_move_dir = -1


static func _angle_between(a: int, b: int) -> int:
	var d := absi(a - b) % 8
	return mini(d, 8 - d)


## 그리기용: (애니메이션 이름, 좌우 반전) — 시트는 S·SE·E·NE·N 5행, 나머지는 반전.
static func anim_for(motion_name: String, dir_index: int) -> Array:
	var name: String = DIRS[dir_index]
	var mirror := {"W": "E", "SW": "SE", "NW": "NE"}
	if mirror.has(name):
		return ["%s_%s" % [motion_name, mirror[name]], true]
	return ["%s_%s" % [motion_name, name], false]
