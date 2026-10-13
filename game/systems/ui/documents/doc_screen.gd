## 서류 UI 공통 틀 (SD-03a §12.1 '같은 종이 질감 틀 + 칸 배치만 다르게', SD-10 §8, 견본 art/samples/18_ui_birth·record·aptitude).
## 논리 640×360. 화면이 넓으면 가운데에 놓고 남는 곳은 책상(또는 단말 외장)으로 채운다.
## 조작: 위·아래 = 칸 이동, 왼쪽·오른쪽 = 값 조정(조정 칸) 또는 옆 단추, 결정 = 누르기, 취소 = 닫기(허용하는 서류만).
## 마우스·터치: 칸 위에 올리면 고르고, 누르면 결정, ◀▶ 자리를 누르면 조정. 터치는 마우스 흉내(기본값)로 들어온다 —
## ScreenTouch를 따로 받으면 한 번 눌러 두 번 결정되므로 받지 않는다.
## 그리기는 view 하나의 _draw에서 하고(draw_rect·draw_string), 그림(초상·페이퍼돌)은 노드로 얹는다
## (호환 렌더러에서 앞에 타일을 그린 장면의 draw_texture가 흰 사각형이 되는 문제, 0-2 기록).
class_name DocScreen
extends CanvasLayer

signal closed(ok: bool)

const C := {
	"P00": Color("0B0A0D"), "P01": Color("1A181D"), "P02": Color("2B2830"), "P03": Color("3E3A40"), "P04": Color("555052"),
	"P05": Color("6E6966"), "P06": Color("8B857D"), "P07": Color("ABA49A"), "P08": Color("CBC5B9"), "P09": Color("E9E4D8"),
	"P17": Color("46331F"), "P18": Color("634A2C"), "P43": Color("142445"), "P44": Color("1F3A6E"), "P45": Color("2E569C"),
	"P46": Color("4C7DC8"), "P52": Color("6E1A1E"), "P53": Color("A82A26"), "P54": Color("E04A35"), "P58": Color("6A3A08"),
	"P60": Color("FFC24A"), "P61": Color("0E4A52"), "P62": Color("1F9AA6"),
}
const AMBER := [Color("0D0702"), Color("2A1604"), Color("4A2A06"), Color("7A4A0C"), Color("B06E12"), Color("E09A1E"),
	Color("FFC24A"), Color("FFE9B0")]
const GREEN := [Color("050A06"), Color("0B1F10"), Color("123A1C"), Color("1C5E2C"), Color("2D8C42"), Color("46C25E"),
	Color("7CF08E"), Color("D2FFD8")]
const PAPER := Color("CBC5B9")
const INK := Color("1F3A6E")
const INK2 := Color("142445")
const RED := Color("A82A26")

var st: StoryState
var view: Control
var f8: Font
var f10: Font
var f12: Font
var f12b: Font
var f15: Font
var items: Array = []        ## [{"id", "rect", "enabled", "lr"(값 조정 칸), "l", "r"(◀▶ 누르는 자리)}] — 그릴 때마다 다시 만든다
var focus := 0
var time := 0.0
var busy := 0.0               ## 확정 연출(도장·출력) 중이면 입력을 받지 않는다
var cancel_ok := false        ## 취소 키로 닫아도 되는 서류(출구 점검표에서 연 하위 서류)
var _want_focus := ""        ## 다음 그리기 뒤에 고를 칸(칸 목록이 아직 없을 때)


func _init() -> void:
	layer = 20
	f8 = load("res://assets/fonts/Galmuri7.ttf")
	f10 = load("res://assets/fonts/Galmuri9.ttf")
	f12 = load("res://assets/fonts/Galmuri11.ttf")
	f12b = load("res://assets/fonts/Galmuri11-Bold.ttf")
	f15 = load("res://assets/fonts/Galmuri14.ttf")
	view = Control.new()
	view.size = Vector2(640, 360)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_on_draw)
	add_child(view)


func _ready() -> void:
	_place()


func _place() -> void:
	var vs := get_viewport().get_visible_rect().size
	view.position = Vector2(floorf((vs.x - 640.0) / 2.0), floorf((vs.y - 360.0) / 2.0))


func _process(dt: float) -> void:
	time += dt
	if busy > 0.0:
		busy = maxf(0.0, busy - dt)
		if busy == 0.0:
			_busy_done()
	_place()
	_tick(dt)
	view.queue_redraw()


func _on_draw() -> void:
	items = []
	_draw_doc()
	focus = clampi(focus, 0, maxi(0, items.size() - 1))


# ---------------------------------------------------------------- 서류마다 채우는 곳
func _draw_doc() -> void:
	pass


func _tick(_dt: float) -> void:
	pass


func _press(_id: String) -> void:
	pass


func _adjust(_id: String, _d: int) -> void:
	pass


func _busy_done() -> void:
	pass


func _cancel() -> void:
	if cancel_ok:
		close(false)


func close(ok: bool) -> void:
	closed.emit(ok)
	queue_free()


# ---------------------------------------------------------------- 칸
## 칸 하나를 등록하고 지금 고른 칸인지 돌려준다(그리기 전에 부른다)
func item(id: String, rect: Rect2, enabled: bool = true, lr: bool = false, l: Rect2 = Rect2(), r: Rect2 = Rect2()) -> bool:
	items.append({"id": id, "rect": rect, "enabled": enabled, "lr": lr, "l": l, "r": r})
	return items.size() - 1 == focus


func focus_on(id: String) -> void:
	for i in items.size():
		if items[i]["id"] == id:
			focus = i
			return
	_want_focus = id


func focused_id() -> String:
	if _want_focus != "":
		for i in items.size():
			if items[i]["id"] == _want_focus:
				focus = i
				_want_focus = ""
				break
	return items[focus]["id"] if focus < items.size() else ""


func _move(d: int) -> void:
	var n := items.size()
	for k in n:
		focus = (focus + d + n) % n
		if items[focus]["enabled"]:
			break
	_focus_changed(false)


## 고른 칸이 바뀌었다(by_mouse: 마우스를 올려서 — 글자 입력 칸은 이때 입력 초점을 빼앗지 않는다)
func _focus_changed(_by_mouse: bool) -> void:
	pass


# ---------------------------------------------------------------- 입력
func _unhandled_input(e: InputEvent) -> void:
	if not visible or items.is_empty():
		return
	if busy > 0.0:
		if e.is_pressed():
			get_viewport().set_input_as_handled()
		return
	focused_id()
	var it: Dictionary = items[focus]
	if e.is_action_pressed("ui_up", true):
		_move(-1)
	elif e.is_action_pressed("ui_down", true):
		_move(1)
	elif e.is_action_pressed("ui_left", true):
		if it["lr"]:
			_adjust(it["id"], -1)
		else:
			_move(-1)
	elif e.is_action_pressed("ui_right", true):
		if it["lr"]:
			_adjust(it["id"], 1)
		else:
			_move(1)
	elif e.is_action_pressed("ui_accept"):
		if it["enabled"]:
			_press(it["id"])
	elif e.is_action_pressed("ui_cancel"):
		_cancel()
	elif e is InputEventMouseMotion:
		var i := _item_at(_local(e.position))
		if i >= 0 and i != focus and items[i]["enabled"]:
			focus = i
			_focus_changed(true)
		return
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p := _local(e.position)
		var i := _item_at(p)
		if i < 0 or not items[i]["enabled"]:
			return
		focus = i
		var hit: Dictionary = items[i]
		if hit["lr"] and hit["l"].has_point(p):
			_adjust(hit["id"], -1)
		elif hit["lr"] and hit["r"].has_point(p):
			_adjust(hit["id"], 1)
		else:
			_press(hit["id"])
	else:
		return
	get_viewport().set_input_as_handled()
	view.queue_redraw()


func _local(p: Vector2) -> Vector2:
	return view.get_global_transform_with_canvas().affine_inverse() * p


func _item_at(p: Vector2) -> int:
	for i in items.size():
		var it: Dictionary = items[i]
		if it["rect"].has_point(p) or (it["lr"] and (it["l"].has_point(p) or it["r"].has_point(p))):
			return i
	return -1


# ---------------------------------------------------------------- 그리기 도구
func text(p: Vector2, s: String, font: Font, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	var x := p.x
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		x -= tw if align == HORIZONTAL_ALIGNMENT_RIGHT else floorf(tw / 2.0)
	view.draw_string(font, Vector2(x, p.y + font.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, col)


func tw(s: String, font: Font, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func box(r: Rect2, col: Color, filled := true) -> void:
	if filled:
		view.draw_rect(r, col)
	else:
		view.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), col, false, 1.0)


func hline(x0: float, x1: float, y: float, col: Color, w := 1.0) -> void:
	view.draw_line(Vector2(x0, y + 0.5), Vector2(x1, y + 0.5), col, w)


## 나무 책상(종이 서류 바탕) — 화면 전체
func desk() -> void:
	var full := Rect2(-view.position, get_viewport().get_visible_rect().size)
	view.draw_rect(full, C["P17"])
	var y0 := int(full.position.y) - posmod(int(full.position.y), 3)
	for y in range(y0, int(full.end.y), 3):
		if posmod(y / 3, 4) == 0:
			view.draw_rect(Rect2(full.position.x, y, full.size.x, 1), C["P18"])


## 종이 한 장(그림자·윗변 밝은 줄·접힘 자국)
func paper(r: Rect2) -> void:
	view.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), C["P03"])
	view.draw_rect(r, PAPER)
	box(r, C["P06"], false)
	hline(r.position.x + 1, r.end.x - 1, r.position.y + 1, C["P09"])
	var y := r.position.y + 6
	while y < r.end.y:
		view.draw_rect(Rect2(r.end.x - 6, y, 1, 1), C["P07"])
		y += 37


## 붉은 도장(두 겹 원 + 글자). t: 0~1 찍히는 연출(크게 → 제자리)
func stamp(c: Vector2, label: String, r := 13.0, t := 1.0) -> void:
	if t <= 0.0:
		return
	var k := 1.0 + (1.0 - clampf(t, 0.0, 1.0)) * 0.8
	var a := clampf(t * 2.0, 0.0, 1.0)
	var col := Color(RED, a)
	view.draw_arc(c, r * k, 0, TAU, 40, col, 2.0)
	view.draw_arc(c, (r - 3.0) * k, 0, TAU, 36, col, 1.0)
	text(c - Vector2(0, 6), label, f10, 10, col, HORIZONTAL_ALIGNMENT_CENTER)


## 종이 서류 단추 [이름]: 강조(파란 바탕) · 고른 칸(밝은 바탕) · 꺼짐(흐림)
func paper_button(r: Rect2, label: String, primary: bool, selected: bool, enabled := true) -> void:
	var fill := INK if primary and enabled else (C["P09"] if selected else PAPER)
	view.draw_rect(r, fill)
	box(r, INK if enabled else C["P06"], false)
	if selected:
		box(r.grow(2), C["P53"] if primary else INK, false)
	var col := PAPER if primary and enabled else (INK if enabled else C["P06"])
	text(Vector2(r.get_center().x, r.position.y + 3), "[%s]" % label, f12, 12, col, HORIZONTAL_ALIGNMENT_CENTER)


## 단말 단추(호박색): 강조는 밝은 바탕 + 줄무늬
func amber_button(r: Rect2, label: String, primary: bool, selected: bool, enabled := true) -> void:
	if primary or selected:
		view.draw_rect(r, AMBER[7] if primary else AMBER[3])
		if primary:
			var y := r.position.y + 1
			while y < r.end.y:
				view.draw_rect(Rect2(r.position.x, y, r.size.x, 1), AMBER[6])
				y += 2
	box(r, AMBER[6] if selected else AMBER[4], false)
	var col := AMBER[0] if primary else (AMBER[7] if selected else (AMBER[5] if enabled else AMBER[3]))
	text(Vector2(r.get_center().x, r.position.y + 3), "[%s]" % label, f12, 12, col, HORIZONTAL_ALIGNMENT_CENTER)


## ◀ ▶ 작은 삼각형(값 조정)
func arrows(x: float, y: float, col_l: Color, col_r: Color) -> void:
	view.draw_colored_polygon(PackedVector2Array([Vector2(x + 6, y), Vector2(x + 6, y + 9), Vector2(x, y + 4.5)]), col_l)
	view.draw_colored_polygon(PackedVector2Array([Vector2(x + 14, y), Vector2(x + 14, y + 9), Vector2(x + 20, y + 4.5)]), col_r)


## 빨간 펜 체크 표시
func check_mark(p: Vector2, col: Color) -> void:
	view.draw_line(p + Vector2(2, 5), p + Vector2(5, 8), col, 2.0)
	view.draw_line(p + Vector2(5, 8), p + Vector2(10, 0), col, 2.0)
