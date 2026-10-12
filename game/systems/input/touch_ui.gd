## 터치 조작 시안 (SD-19 §6.13, SD-11 §15): 왼쪽 아래 떠 있는 이동 스틱, 오른쪽 조준·사격 스틱, 상황 버튼.
## 이동 스틱: 반경 25% 안쪽 걷기, 바깥 달리기, 링 끝까지 0.3초 = 질주. 회피·집중 버튼(SD-11 §15.5).
## 오른쪽 스틱: 기울이면 조준, 놓으면 사격, 끝까지 0.3초 유지하면 정조준. 조준 보정(반각 12°)은 시험 구역 쪽에서 쓴다.
## 버튼 높이는 최소 48 내부 픽셀(×3 화면에서 약 7mm). 실행 인자 --touch 이면 마우스로 터치를 흉내 낸다.
class_name TouchUI
extends CanvasLayer

signal fire_released
var move := Vector2.ZERO
var aim := Vector2.ZERO
var aim_full := 0.0                       ## 끝까지 기울인 시간(초) → 0.3 이상이면 정조준
var move_full := 0.0                      ## 이동 스틱을 질주 링(바깥 끝)까지 민 시간 → 0.3 이상이면 질주
var buttons := {"재장전": Rect2(560, 196, 48, 48), "교체": Rect2(500, 236, 48, 48), "문": Rect2(560, 136, 48, 48)}
var dim := {}                             ## 회색으로 그릴 버튼(AP 부족 등)
var pressed := {}
var _taps := {}                           ## 누른 순간 한 번만: take()로 꺼낸다
const R := 34.0
var _left := {"id": -1, "c": Vector2.ZERO, "p": Vector2.ZERO}
var _right := {"id": -1, "c": Vector2.ZERO, "p": Vector2.ZERO}
var _pad: Control
var font: Font


func _ready() -> void:
	layer = 5
	_pad = Control.new()
	_pad.size = Vector2(640, 360)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	font = load("res://assets/fonts/Galmuri9.ttf")


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var p: Vector2 = _pad.get_global_transform_with_canvas().affine_inverse() * e.position
		if e.pressed:
			for k in buttons:
				if buttons[k].has_point(p):
					pressed[k] = true
					_taps[k] = true
					return
			var side := _left if p.x < 320 else _right
			if side["id"] < 0:
				side["id"] = e.index
				side["c"] = p
				side["p"] = p
		else:
			for k in buttons:
				pressed.erase(k)
			if _left["id"] == e.index:
				_left["id"] = -1
				move = Vector2.ZERO
			if _right["id"] == e.index:
				_right["id"] = -1
				if aim.length() > 0.25:
					fire_released.emit()
				aim = Vector2.ZERO
				aim_full = 0.0
	elif e is InputEventScreenDrag:
		var p2: Vector2 = _pad.get_global_transform_with_canvas().affine_inverse() * e.position
		for side in [_left, _right]:
			if side["id"] == e.index:
				var d: Vector2 = (p2 - side["c"]).limit_length(R)
				side["p"] = side["c"] + d
				if side == _left:
					move = d / R
				else:
					aim = d / R
	_pad.queue_redraw()


func take(k: String) -> bool:
	return _taps.erase(k)


func _process(dt: float) -> void:
	aim_full = aim_full + dt if aim.length() > 0.95 else 0.0
	move_full = move_full + dt if move.length() > 0.98 else 0.0


func _draw_pad() -> void:
	for side in [_left, _right]:
		if side["id"] >= 0:
			_pad.draw_circle(side["c"], R, Color(0.05, 0.05, 0.06, 0.45))
			var ring := Color("e8c23a") if side == _left and move_full >= 0.3 else Color("cbc5b9")   # 질주 링이 노랗게
			_pad.draw_arc(side["c"], R, 0, TAU, 32, ring, 1.0)
			_pad.draw_circle(side["p"], 12, Color("e9e4d8") if side == _left else (Color("e8c23a") if aim_full >= 0.3 else Color("e04a35")))
	for k in buttons:
		var r: Rect2 = buttons[k]
		_pad.draw_rect(r, Color(0.05, 0.05, 0.06, 0.55 if not pressed.has(k) else 0.85))
		if dim.get(k, false):
			_pad.draw_rect(r, Color(0.4, 0.4, 0.4, 0.35))
		_pad.draw_rect(r, Color("8b857d"), false, 1.0)
		_pad.draw_string(font, r.position + Vector2(6, 28), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e9e4d8"))
