## 디버그 콘솔 (SD-19 §6 표 'T' 행: 변수 설정, 장소 ID 순간 이동, 청크·AI·탐지 표시, 시간 건너뛰기).
## ` 키로 열고 닫는다. 실행 인자 --cmd="tp T-NEST; show ai" 는 시작할 때 명령을 차례로 돌린다(녹화·회귀용).
## 명령 해석은 parse()(엔진 무관, 단위 시험), 실행은 host(시험 구역)의 dbg_* 함수가 맡는다.
class_name DebugConsole
extends CanvasLayer

const HELP := [
	"help — 명령 목록",
	"set <hp|ap|mag|skill> <값|max> — 변수 설정",
	"tp <장소 ID> | tp <타일 x> <타일 y> — 순간 이동 (places: 장소 목록)",
	"show <chunk|ai|detect|nav|all|off> — 디버그 표시 켜고 끄기",
	"skip <분> — 게임 시간 건너뛰기",
	"god — 무적 켜고 끄기 / kill — 활성 적 모두 쓰러뜨리기 / heal — HP·AP 가득",
	"close — 콘솔 닫기(` 키와 같다)",
]
const ARITY := {"help": [0, 0], "set": [2, 2], "tp": [1, 2], "places": [0, 0], "show": [1, 1], "skip": [1, 1],
	"god": [0, 0], "kill": [0, 0], "heal": [0, 0], "close": [0, 0]}
var host: Object
var opened := false
var lines: PackedStringArray = []
var _panel: ColorRect
var _log: Label
var _edit: LineEdit
var _history: PackedStringArray = []
var _hist_i := 0


## 한 줄 → {ok, cmd, args} 또는 {ok: false, err}. 따옴표·세미콜론은 run_script가 나눈다.
static func parse(line: String) -> Dictionary:
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty():
		return {"ok": false, "err": ""}
	var cmd := parts[0].to_lower()
	if not ARITY.has(cmd):
		return {"ok": false, "err": "모르는 명령: %s (help)" % cmd}
	var args := parts.slice(1)
	var ar: Array = ARITY[cmd]
	if args.size() < ar[0] or args.size() > ar[1]:
		return {"ok": false, "err": "%s: 인자 %d~%d개" % [cmd, ar[0], ar[1]]}
	if cmd == "set" and not (args[0] in ["hp", "ap", "mag", "skill"]):
		return {"ok": false, "err": "set: hp·ap·mag·skill 중 하나"}
	if cmd == "set" and args[1] != "max" and not args[1].is_valid_float():
		return {"ok": false, "err": "set: 값은 숫자 또는 max"}
	if cmd == "show" and not (args[0] in ["chunk", "ai", "detect", "nav", "all", "off"]):
		return {"ok": false, "err": "show: chunk·ai·detect·nav·all·off"}
	if cmd == "skip" and not args[0].is_valid_float():
		return {"ok": false, "err": "skip: 분(숫자)"}
	if cmd == "tp" and args.size() == 2 and not (args[0].is_valid_int() and args[1].is_valid_int()):
		return {"ok": false, "err": "tp: 장소 ID 또는 타일 x y"}
	return {"ok": true, "cmd": cmd, "args": args}


func _ready() -> void:
	layer = 20
	var font: Font = load("res://assets/fonts/Galmuri9.ttf")
	_panel = ColorRect.new()
	_panel.color = Color(0.043, 0.039, 0.051, 0.88)
	_panel.visible = false
	add_child(_panel)
	_log = Label.new()
	_log.add_theme_font_override("font", font)
	_log.add_theme_font_size_override("font_size", 10)
	_log.add_theme_color_override("font_color", Color("cbc5b9"))
	_log.position = Vector2(4, 2)
	_panel.add_child(_log)
	_edit = LineEdit.new()
	_edit.add_theme_font_override("font", font)
	_edit.add_theme_font_size_override("font_size", 10)
	_edit.flat = true
	_edit.placeholder_text = "명령 (help)"
	_edit.text_submitted.connect(_submit)
	_panel.add_child(_edit)
	var fit := get_node_or_null("/root/ScreenFit")
	_layout(fit.logical if fit != null else Vector2i(640, 360))
	if fit != null:
		fit.changed.connect(_layout)


func _layout(logical: Vector2i) -> void:
	_panel.size = Vector2(logical.x, 132)
	_panel.position = Vector2(0, logical.y - 132)
	_log.size = Vector2(logical.x - 8, 112)
	_edit.position = Vector2(4, 114)
	_edit.size = Vector2(logical.x - 8, 16)


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_QUOTELEFT:
			toggle()
			get_viewport().set_input_as_handled()
		elif opened and e.physical_keycode == KEY_UP and not _history.is_empty():
			_hist_i = maxi(0, _hist_i - 1)
			_edit.text = _history[_hist_i]
			_edit.caret_column = _edit.text.length()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	opened = not opened
	_panel.visible = opened
	if opened:
		_edit.grab_focus()
		_edit.clear()
	else:
		_edit.release_focus()


func _submit(text: String) -> void:
	_edit.clear()
	if text.strip_edges() != "":
		_history.append(text)
		_hist_i = _history.size()
	run(text)


## 세미콜론으로 여러 명령(실행 인자 --cmd). 녹화에서 결과가 보이도록 창을 열어 둔다.
func run_script(script: String) -> void:
	if not opened:
		toggle()
	for part in script.split(";", false):
		run(part)


func run(line: String) -> void:
	var p := parse(line)
	if not p["ok"]:
		if p["err"] != "":
			out("× " + p["err"])
		return
	out("> " + line.strip_edges())
	if p["cmd"] == "close":
		if opened:
			toggle()
		return
	if p["cmd"] == "help":
		for h in HELP:
			out("  " + h)
		return
	out("  " + str(host.call("dbg_" + p["cmd"], p["args"])))


func out(s: String) -> void:
	lines.append(s)
	print("[콘솔] " + s)
	if lines.size() > 10:
		lines = lines.slice(lines.size() - 10)
	_log.text = "\n".join(lines)
