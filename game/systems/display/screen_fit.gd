## 화면 맞춤 (SD-12 §17.3, SD-16 §3.3 v1.2, SD-19 H-11).
## 'expand'(H-11 ①, 권고): 정수 배율 n = min(⌊높이÷360⌋, ⌊폭÷640⌋), 논리 해상도 = (폭÷n, 높이÷n), 상한 854×480, 넘는 부분만 띠.
## 'letterbox'(H-11 ②, SD-16 v1.1 현행): 논리 해상도 640×360 고정 + 정수 배율 + 띠.
## 실행 인자: --fit=letterbox | --fit=expand, --device=2400x1080 (그 기기의 논리 해상도로 창을 1배로 열어 비교 화면을 찍는다)
extends Node

signal changed(logical: Vector2i)
const BASE := Vector2i(640, 360)
const CAP := Vector2i(854, 480)
var mode := "expand"
var logical := BASE
var scale := 1
var too_small := false                       ## 세로 360 미만(분할 화면 등): 일시 정지 + 안내(SD-12 §17.3)
var _device := Vector2i.ZERO


## 화면 크기 → [n, 논리 해상도]. 엔진 무관(단위 시험 대상).
static func fit(screen: Vector2i, fit_mode: String = "expand") -> Array:
	var n := maxi(1, mini(screen.y / BASE.y, screen.x / BASE.x))
	if fit_mode == "letterbox":
		return [n, BASE]
	return [n, Vector2i(mini(screen.x / n, CAP.x), mini(screen.y / n, CAP.y))]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fit="):
			mode = a.substr(6)
		elif a.begins_with("--device="):
			var p := a.substr(9).split("x")
			_device = Vector2i(int(p[0]), int(p[1]))
	get_window().size_changed.connect(apply)
	apply()


func apply() -> void:
	var w := get_window()
	var screen: Vector2i = _device if _device != Vector2i.ZERO else w.size
	var r := fit(screen, mode)
	scale = r[0]
	logical = r[1]
	too_small = screen.y < BASE.y
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	w.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	w.content_scale_size = logical
	if _device != Vector2i.ZERO and w.size != logical:
		w.size = logical                                          # 비교 화면용: 논리 해상도를 1배로
	changed.emit(logical)
