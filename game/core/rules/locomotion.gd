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
	# 아이작풍 짧은 다리 보폭(SD-16 §3.6 v2.0, art/tools/chibi.py STRIDE와 같은 값): 옆 px, 앞뒤 px_v, 대각선 diag(축 거리)
	"walk": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": 3.0},
	"run": {"frames": 6, "px": 6.0, "px_v": 4.0, "diag": 4.0, "contact": [0, 3], "speed_t": 4.5},
	# 질주 6.5t/s(SD-11 §2.4): 전용 그림 전까지 달리기 컷을 같은 보폭으로 더 빨리 넘긴다(거리 구동이라 미끄러지지 않는다)
	"sprint": {"frames": 6, "px": 6.0, "px_v": 4.0, "diag": 4.0, "contact": [0, 3], "speed_t": 6.5, "anim": "run"},
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
## ⑧ 벽(SD-16 §5.4): 보폭 하나를 끝까지 걸을 수 없으면 그 걸음을 떼지 않는다. 벽 앞에서 제자리걸음·비비기·
##   앞뒤로 들썩임이 없고, 몸만 가려던 쪽으로 돌린다(조준 중이 아니면). 걸음이 바뀌면 그림 위치에서 새 보폭을 시작한다.
func step(input: Vector2, dt: float, mode: String = "walk", aim_dir: int = -1, blocked: Callable = Callable()) -> void:
	var want := snap8(input)
	if want < 0:
		_stop()
		return
	var m: Dictionary = custom.get(mode, MOTIONS.get(mode, {}))
	var back := aim_dir >= 0 and _angle_between(want, aim_dir) > 2      # > 90°
	var per: float = m["diag"] if want % 2 == 1 else (float(m.get("px_v", m["px"])) if want in [2, 6] else float(m["px"]))
	var new_stride := motion != mode or want != _move_dir
	if new_stride:
		if motion == "idle":
			render = logical.round()
		logical = render                                              # 발이 있던 자리(그림)에서 새 보폭 — 그림이 튀지 않는다
		_acc = 0.0
	if blocked.is_valid():                                            # 보폭 앞보기
		var end: Vector2 = render + VEC[want] * per
		if not (blocked.call(logical, end) as Vector2).is_equal_approx(end):
			_blocked(want, aim_dir)
			return
	var speed: float = m["speed_t"] * TILE * (BACK_SPEED if back else 1.0)
	var dv: Vector2 = VEC[want].normalized() * speed * dt
	var target := logical + dv
	var arrived: Vector2 = target if not blocked.is_valid() else blocked.call(logical, target)
	var actual: Vector2 = arrived - logical
	if actual.length() < 0.001:
		_blocked(want, aim_dir)
		return
	logical = arrived
	var d := want
	_stop_left = 0
	if new_stride:
		if motion != mode:
			frame = 0
		motion = mode
		_move_dir = d
	reverse = back
	facing = (d + 4) % 8 if back else d                               # 뒷걸음이면 하체는 조준 쪽
	var diag := d % 2 == 1
	_acc += maxf(absf(actual.x), absf(actual.y)) if diag else actual.length()
	while _acc >= per - 0.0001:
		_acc = maxf(0.0, _acc - per)
		frame = (frame + (m["frames"] - 1 if reverse else 1)) % m["frames"]
		frames_advanced += 1
		render += VEC[d] * per                                      # ② exactly one frame distance
	render = render.round()


## 막혀서 걸음을 못 뗌: 걷던 중이면 디딤 컷으로 서고(⑤), 서 있었으면 몸만 그쪽으로 돌린다.
func _blocked(want: int, aim_dir: int) -> void:
	if motion != "idle":
		_stop()
	elif aim_dir < 0:
		facing = want


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


## 그림 모션 이름(질주는 달리기 컷을 쓴다)
func anim_motion() -> String:
	var m: Dictionary = custom.get(motion, MOTIONS.get(motion, {}))
	return m.get("anim", motion)


## 발이 땅에서 떨어진 동안의 이동(구르기·넉백, SD-16 §5.4 ⑦)이 끝난 자리에 선다: 판정·그림 위치를 맞추고 대기로
func place(p: Vector2) -> void:
	logical = p
	render = p.round()
	motion = "idle"
	frame = 0
	_acc = 0.0
	_move_dir = -1
	_stop_left = 0


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
