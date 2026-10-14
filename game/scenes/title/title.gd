## 제목 화면 · 메인 메뉴(SD-12 §13.5·§17.6, 단계 0-11): 이어하기 / 새 게임 / 불러오기 / 만든 사람 / 종료.
## 배경은 첫 풍경 무대(볼트 S-07 문 앞 콘크리트 턱 → 관악산 비탈 → 2277년 서울)를 문 앞에서 1px씩 올려 서울에서 멈추고,
## 로고('서울 폴아웃')와 볼트 문 명판을 얹는다(SD-16 §9.4 메인 메뉴 = 잉크·중성 램프 + 볼트 황 강조).
## 이어하기 = 중단 저장(모바일) → 가장 최근 저장(§17.6). 불러오기는 일시 정지 메뉴의 칸 목록을 그대로 쓴다.
## 조작: 위·아래 + E·Enter, 마우스·터치는 줄을 눌러 고르고 다시 눌러 결정.
extends Node

const STAGE_H := 540.0
const PAN_S := 9.0
const INK := Color("1A181D")
const YEL := Color("E8C23A")
const PAPER := Color("E9E4D8")
const DIM := Color("8B857D")

var layer: CanvasLayer
var stage: Node2D
var ui: Control
var t := 0.0
var sel := 0
var rows: Array = []
var f10: Font
var f12: Font
var f12b: Font
var logo: Texture2D
var plate: Texture2D
var note := ""
var note_t := 0.0
var _items: Array = []
var menu: PauseMenu


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0B0A0D"))
	f10 = load("res://assets/fonts/Galmuri9.ttf")
	f12 = load("res://assets/fonts/Galmuri11.ttf")
	f12b = load("res://assets/fonts/Galmuri11-Bold.ttf")
	logo = load("res://assets/ui/title_logo.png")
	plate = load("res://assets/ui/title_plate.png")
	layer = CanvasLayer.new()
	add_child(layer)
	stage = Node2D.new()
	layer.add_child(stage)
	for pr in [["far", 0], ["near", 290]]:
		var sp := Sprite2D.new()
		sp.texture = load("res://assets/ui/first_view_%s.png" % pr[0])
		sp.centered = false
		sp.position = Vector2(0, pr[1])
		stage.add_child(sp)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	layer.add_child(ui)
	rows = []
	if SaveSlots.continue_path() != "":
		rows.append(["continue", "이어하기"])
	rows += [["new", "새 게임"], ["load", "불러오기"], ["credits", "만든 사람"]]
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		rows.append(["quit", "종료"])


func _process(dt: float) -> void:
	t += dt
	note_t = maxf(0.0, note_t - dt)
	var vs := get_viewport().get_visible_rect().size
	ui.size = vs
	# 문 앞(무대 아래쪽)에서 시작해 PAN_S초 동안 서울(무대 위쪽)까지 올라간다. 부드럽게 시작·멈춤, 1px 단위
	var k := clampf(t / PAN_S, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var bottom := vs.y - STAGE_H                                  # 무대 아래 끝을 화면 아래에 맞춘 위치(문 앞)
	var top := minf(0.0, floorf((vs.y - 360.0) / 2.0))            # 하늘이 화면 위에 오는 위치
	stage.position = Vector2(floorf((vs.x - 640.0) / 2.0), floorf(lerpf(bottom, top, k)))
	ui.queue_redraw()


func _draw_ui() -> void:
	_items = []
	var vs := ui.size
	var ox := floorf((vs.x - 640.0) / 2.0)
	var oy := floorf((vs.y - 360.0) / 2.0)
	var a := clampf((t - PAN_S * 0.55) / 1.2, 0.0, 1.0)            # 서울이 보일 즈음 로고·메뉴가 나타난다
	if a <= 0.0:
		_hint_skip(ox, oy)
		return
	ui.draw_texture(logo, Vector2(ox + floorf((640.0 - logo.get_width()) / 2.0), oy + 22), Color(1, 1, 1, a))
	_shadowed(Vector2(ox + 320 - f10.get_string_size("2277년, 서울.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x / 2.0, oy + 98),
		"2277년, 서울.", Color(PAPER, a))
	ui.draw_texture(plate, Vector2(ox + 640 - plate.get_width() - 16, oy + 360 - plate.get_height() - 16), Color(1, 1, 1, a))
	# 메뉴: 왼쪽 아래 잉크 판
	var p := Rect2(ox + 24, oy + 196, 168, 24 + rows.size() * 22)
	ui.draw_rect(p, Color(INK, 0.82 * a))
	ui.draw_rect(Rect2(p.position + Vector2(0.5, 0.5), p.size - Vector2.ONE), Color(DIM, a), false, 1.0)
	ui.draw_line(p.position + Vector2(8, 1), Vector2(p.end.x - 8, p.position.y + 1), Color(YEL, 0.7 * a))
	for i in rows.size():
		var r := Rect2(p.position.x + 6, p.position.y + 12 + i * 22, p.size.x - 12, 20)
		_items.append(r)
		var on := i == sel
		if on:
			ui.draw_rect(r, Color(YEL, 0.9 * a))
		ui.draw_string(f12, Vector2(r.position.x + 10, r.position.y + 15), str(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(INK, a) if on else Color(PAPER, a))
	var foot := note if note_t > 0.0 else "비상업 팬 게임 · 폴아웃 3 원작 규칙 계승"
	_shadowed(Vector2(ox + 24, oy + 350), foot, Color(YEL if note_t > 0.0 else PAPER, a * (1.0 if note_t > 0.0 else 0.8)))


## 잉크 그림자(오른쪽 아래 1px)를 깐 글 — 그림 위에서도 읽히게
func _shadowed(p: Vector2, s: String, col: Color) -> void:
	for d in [Vector2(1, 1), Vector2(1, 0), Vector2(0, 1)]:
		ui.draw_string(f10, p + d, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(INK, col.a))
	ui.draw_string(f10, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


func _hint_skip(ox: float, oy: float) -> void:
	if t > 1.0:
		ui.draw_string(f10, Vector2(ox + 520, oy + 350), "누르면 건너뛴다", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(DIM, 0.6))


func _choose() -> void:
	match str(rows[sel][0]):
		"continue":
			_start(SaveSlots.continue_path())
		"new":
			_start("")
		"load":
			menu = PauseMenu.new().setup(null, Callable(), Callable(), func(path: String) -> void: _start(path), Callable())
			menu.title_mode = true
			add_child(menu)
			menu._open("load")
			menu.closed.connect(func(_ok: bool) -> void: menu = null)
		"credits":
			note = "기획·그림·코드: Claude · 원작: 폴아웃 3(베데스다) · 글꼴: 갈무리·Neo둥근모 Pro(OFL)"
			note_t = 6.0
		"quit":
			get_tree().quit()


## 게임으로: path가 있으면 그 저장을 불러온다(빈 글 = 새 게임)
func _start(path: String) -> void:
	SaveSlots.pending = path
	get_tree().change_scene_to_file("res://scenes/story/prologue.tscn")


func _unhandled_input(e: InputEvent) -> void:
	if menu != null:
		return
	var pressed: bool = (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed)
	if pressed and t < PAN_S * 0.55 + 1.2:
		t = PAN_S * 0.55 + 1.2                                          # 아무 키나 누르면 바로 메뉴
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("ui_up", true):
		sel = (sel - 1 + rows.size()) % rows.size()
	elif e.is_action_pressed("ui_down", true):
		sel = (sel + 1) % rows.size()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_choose()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in _items.size():
			if (_items[i] as Rect2).has_point(e.position):
				if i == sel:
					_choose()
				else:
					sel = i
	else:
		return
	get_viewport().set_input_as_handled()
