## 이벤트 실행기 v1 (SD-16 §13.6 '인게임 컷신', SD-03a 연출 메모): 대화 창의 연출 명령(cmd)을 맵 위 진짜 인물로 무대에 올린다.
## 쯔꾸르식: 인물은 걸음 단위로 걷고(Locomotion, 미끄러짐 없음), 말풍선(! ? ♥ …)이 뜨고, 화면은 디더로 페이드한다.
## 명령은 차례로 하나씩, 끝날 때까지 기다린다(쯔꾸르 기본 '완료까지 대기').
##   show ID 표지 [방향 [시트]](시트: 이름 없는 단역 — 계엄병 en_cr401_loco 등)   hide ID   move ID 표지 [walk|run]   face ID 방향|인물ID   balloon ID ! | ? | heart | ... | note | sweat | anger
##   go ID 표지 [walk|run](기다리지 않는 이동, 0-9)   wait n(1/10초) | wait go(go로 걷는 사람이 다 설 때까지)   fade_in 색 n   fade_out 색 n   flash 색   shake n   cam 표지   year_card 연도 "문장"   title_card "제목" "문장"
##   sfx·bgm 이름(소리는 납품 뒤 — 지금은 기록만)   lamp 표지 색(장치 램프 깜박임)   doc 이름(서류 UI, 0-4)
##   gate open|close [n](톱니 방폭문 굴리기, 0-9)
##   pose ID stand|lie|sit|in_bed(0-5: lie 몸을 90도 눕힘 · in_bed 그 칸 침대가 '누운 사람' 그림으로 바뀌고 몸은 숨는다)
## 표지(mark)는 맵 자료(game/data/maps/<맵>.json의 marks: 이름 → [타일 x, 타일 y, 방향])다. "x,y" 숫자도 받는다.
class_name EventRunner
extends Node2D

signal doc_requested(name: String, done: Callable)

const COLORS := {"white": Color("E9E4D8"), "black": Color("0B0A0D"), "green": Color("7CD62B"), "red": Color("E04A35"),
	"amber": Color("FFC24A")}
const DIR_IDX := {"E": 0, "SE": 1, "S": 2, "SW": 3, "W": 4, "NW": 5, "N": 6, "NE": 7}

var world                                     ## InteriorRoom 또는 ChunkWorld(충돌 API)
var marks := {}
var actors := {}                              ## 인물 ID -> Actor
var cast_sheets := {}                         ## 인물 ID -> 시트 이름(story_cast.json)
var cam: Camera2D
var overlay: CanvasLayer
var fade_rect: ColorRect
var fade_mat: ShaderMaterial
var card: Control
var card_lines: Array = []
var font_big: Font
var handlers := {}                            ## 진행기가 붙이는 명령(0-7: pipboy·equip·hurt·buddy·range·hint·hud): 이름 -> Callable(args, done)
var font: Font
var balloons: Array = []                      ## [{"actor", "kind", "t"}]
var lamps: Array = []                         ## [{"pos", "color", "t"}]
var _job: Dictionary = {}                     ## 진행 중 명령(move·wait·fade·card·shake·cam)
var cam_locked := false                      ## cam 명령이 카메라를 쥐고 있다(진행기가 주인공을 따라가지 않는다). 대화가 끝나면 놓는다
var _bg: Array = []                           ## 기다리지 않는 이동(go): [{"actor", "to", "path", "t", "still", "last"}] — 군중·분대가 함께 걷는다
var log: Array[String] = []


func _init() -> void:
	font = load("res://assets/fonts/Galmuri11.ttf")
	font_big = load("res://assets/fonts/NeoDunggeunmoPro.ttf")
	if FileAccess.file_exists("res://assets/sprites/story_cast.json"):
		cast_sheets = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/story_cast.json"))["sheets"]
	overlay = CanvasLayer.new()
	overlay.layer = 12
	add_child(overlay)
	fade_rect = ColorRect.new()
	fade_rect.size = Vector2(854, 480)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_mat = ShaderMaterial.new()
	fade_mat.shader = load("res://systems/story/dither_fade.gdshader")
	fade_mat.set_shader_parameter("amount", 0.0)
	fade_rect.material = fade_mat
	overlay.add_child(fade_rect)
	card = Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = Vector2(854, 480)
	card.draw.connect(_draw_card)
	overlay.add_child(card)
	z_index = 50


## w: 무대 맵(충돌), map_id: game/data/maps/<map_id>.json(표지)
func setup(w, map_id: String, camera: Camera2D = null) -> void:
	world = w
	var p := "res://data/maps/%s.json" % map_id
	if FileAccess.file_exists(p):
		marks = JSON.parse_string(FileAccess.get_file_as_string(p))["marks"]
	cam = camera
	if cam == null:
		cam = Camera2D.new()
		add_child(cam)
		cam.make_current()


## 대화 창에 연결: box.command → 실행 → 끝나면 box.resume()
func attach(box: DialogueBox) -> void:
	box.command.connect(func(n: String, a: Array) -> void: run(n, a, box.resume))


func busy() -> bool:
	return not _job.is_empty()


## 기다리지 않는 이동이 남았나(장면 끝에서 다 걸을 때까지 기다리는 `wait_go`)
func walking() -> bool:
	return not _bg.is_empty()


func run(name: String, args: Array, done: Callable) -> void:
	log.append("%s %s" % [name, " ".join(args)])
	match name:
		"show":
			_show_actor(str(args[0]), _mark(str(args[1])), str(args[2]) if args.size() > 2 else _mark_dir(str(args[1])),
				str(args[3]) if args.size() > 3 else "")
			done.call()
		"hide":
			if actors.has(str(args[0])):
				var ha = actors[str(args[0])]
				_bg = _bg.filter(func(b): return is_instance_valid(b["actor"]) and b["actor"] != ha)
				actors[str(args[0])].queue_free()
				actors.erase(str(args[0]))
			done.call()
		"move":
			var a: Actor = actors.get(str(args[0]))
			if a == null:
				push_warning("move: 무대에 없는 인물 " + str(args[0]))
				done.call()
				return
			a.mode = str(args[2]) if args.size() > 2 else "walk"
			var to := _mark(str(args[1]))
			_job = {"kind": "move", "actor": a, "to": to, "done": done, "t": 0.0, "path": _route(a, to), "still": 0.0,
				"last": a.loco.render}
		"go":                                                             # 기다리지 않는 이동: 걷기 시작만 시키고 다음 명령으로
			var a: Actor = actors.get(str(args[0]))
			if a != null:
				a.mode = str(args[2]) if args.size() > 2 else "walk"
				var to := _mark(str(args[1]))
				_bg = _bg.filter(func(b): return is_instance_valid(b["actor"]) and b["actor"] != a)
				_bg.append({"actor": a, "to": to, "path": _route(a, to), "t": 0.0, "still": 0.0, "last": a.loco.render})
			done.call()
		"face":
			var a: Actor = actors.get(str(args[0]))
			if a != null:
				var tgt := str(args[1])
				var d := -1
				if DIR_IDX.has(tgt):
					d = DIR_IDX[tgt]
				elif actors.has(tgt):
					d = _dir_to(a.loco.logical, actors[tgt].loco.logical)
				elif marks.has(tgt):
					d = _dir_to(a.loco.logical, _mark(tgt))
				if d >= 0:
					a.loco.facing = d
					a._show()
			done.call()
		"balloon":
			var a: Actor = actors.get(str(args[0]))
			if a != null:
				balloons.append({"actor": a, "kind": str(args[1]), "t": 0.0})
				queue_redraw()
				_job = {"kind": "wait", "left": 0.7, "done": done}
			else:
				done.call()
		"wait":
			if args.size() > 0 and str(args[0]) == "go":                        # wait go: 걷는 사람이 다 설 때까지
				_job = {"kind": "wait_go", "done": done, "t": 0.0}
			else:
				_job = {"kind": "wait", "left": float(args[0]) / 10.0, "done": done}
		"fade_in", "fade_out":
			var col: Color = COLORS.get(str(args[0]) if args.size() > 0 else "black", Color.BLACK)
			var secs := float(args[1]) / 10.0 if args.size() > 1 else 0.6
			fade_mat.set_shader_parameter("fill", col)
			var from := 1.0 if name == "fade_in" else 0.0
			fade_mat.set_shader_parameter("amount", from)
			_job = {"kind": "fade", "from": from, "to": 1.0 - from, "len": secs, "t": 0.0, "done": done}
		"flash":
			fade_mat.set_shader_parameter("fill", COLORS.get(str(args[0]) if args.size() > 0 else "white", Color.WHITE))
			_job = {"kind": "fade", "from": 0.75, "to": 0.0, "len": 0.25, "t": 0.0, "done": done}
		"shake":
			_job = {"kind": "shake", "left": float(args[0]) / 10.0 if args.size() > 0 else 0.4, "done": done}
		"cam":                                                            # cam 표지 [n]: 카메라를 붙잡아 옮긴다 · cam player: 놓아준다
			if str(args[0]) == "player":
				cam_locked = false
				done.call()
				return
			cam_locked = true
			_job = {"kind": "cam", "len": float(args[1]) / 10.0 if args.size() > 1 else 0.6, "from": cam.position, "to": _mark(str(args[0])) + Vector2(0, -20), "t": 0.0, "done": done}
		"year_card", "title_card":
			card_lines = args.map(func(x): return str(x))
			fade_mat.set_shader_parameter("fill", COLORS["white"] if name == "year_card" else COLORS["black"])
			_job = {"kind": "card", "t": 0.0, "dark": name == "title_card", "done": done}
		"lamp":
			if world != null and world.has_method("set_prop_state"):                  # 장치 그림도 켜진 상태로(등록 단말 6번 칸)
				world.set_prop_state(world.tile_of(_mark(str(args[0]))), "lit")
			lamps.append({"pos": _mark(str(args[0])) + Vector2(0, -22), "color": COLORS.get(str(args[1]) if args.size() > 1 else "green",
				Color.GREEN), "t": 0.0})
			_job = {"kind": "wait", "left": 0.5, "done": done}
		"gate":                                                           # 톱니 방폭문(V-00): gate open|close [n 1/10초]
			var to := 1.0 if str(args[0]) == "open" else 0.0
			if world == null or not world.has_method("set_gate"):
				done.call()
				return
			_job = {"kind": "gate", "from": float(world.gate_k), "to": to, "len": float(args[1]) / 10.0 if args.size() > 1 else 4.0,
				"t": 0.0, "done": done}
		"doc":
			if doc_requested.get_connections().is_empty():
				done.call()
			else:
				doc_requested.emit(str(args[0]), done)
		"pose":
			if actors.has(str(args[0])):
				var a: Actor = actors[str(args[0])]
				var pz := str(args[1]) if args.size() > 1 else "stand"
				if world != null and world.has_method("set_prop_state"):              # 침대에 눕기: 침대가 '누운 사람' 그림으로
					var cell: Vector2i = world.tile_of(a.loco.logical)
					world.set_prop_state(cell, "occupied" if pz == "in_bed" else "")
				a.set_pose(pz)
			done.call()
		_:
			if handlers.has(name):
				(handlers[name] as Callable).call(args, done)
			else:
				done.call()                                       # sfx·bgm: 아직 자원 없음(기록만)


func _show_actor(id: String, pos: Vector2, dir: String, sheet_name := "") -> void:
	if actors.has(id):
		actors[id].queue_free()
	var a := Actor.new()
	var sheet: String = sheet_name if sheet_name != "" else cast_sheets.get(id, "")
	if sheet == "":
		push_warning("show: 시트 없는 인물 " + id)
		return
	a.setup(sheet, pos, world)
	a.mode = "walk"
	a.loco.facing = DIR_IDX.get(dir, 2)
	a._show()
	if world != null and world.has_method("add_actor"):
		world.add_actor(a)                                         # 실내 맵: 소품과 같은 y 정렬 층(앞뒤 가림)
	else:
		get_parent().add_child(a)
	actors[id] = a


## 실내 맵이면 칸 길찾기(소품·벽을 돌아간다, 인물 일과와 같은 칸 가운데 따라가기). 길이 없으면 빈 배열
func _route(a: Actor, to: Vector2) -> PackedVector2Array:
	if world == null or not world.has_method("path"):
		return PackedVector2Array()
	return NpcRoutine.with_start(world, a.loco.render, to)


func _mark(m: String) -> Vector2:
	var tx := 0
	var ty := 0
	if marks.has(m):
		tx = int(marks[m][0])
		ty = int(marks[m][1])
	elif "," in m:
		tx = int(m.get_slice(",", 0))
		ty = int(m.get_slice(",", 1))
	else:
		push_warning("없는 표지: " + m)
	return Vector2(tx * 32 + 16, ty * 32 + 20)


func _mark_dir(m: String) -> String:
	return str(marks[m][2]) if marks.has(m) and marks[m].size() > 2 else "S"


static func _dir_to(a: Vector2, b: Vector2) -> int:
	var v := b - a
	if v.length() < 0.5:
		return 2
	return posmod(int(round(v.angle() / (PI / 4.0))), 8)


func _process(dt: float) -> void:
	var had := not balloons.is_empty() or not lamps.is_empty()
	for b in balloons:
		b["t"] += dt
	balloons = balloons.filter(func(b): return b["t"] < 1.2)
	for l in lamps:
		l["t"] += dt
	lamps = lamps.filter(func(l): return l["t"] < 1.0)
	if had:
		queue_redraw()                                                  # 마지막 말풍선이 사라진 프레임에도 한 번 더 그려 지운다
	var moving := {}
	for b in _bg.duplicate():
		if not is_instance_valid(b["actor"]):                           # 걷는 중에 hide(치움)된 인물
			_bg.erase(b)
			continue
		var a: Actor = b["actor"]
		moving[a] = true
		b["t"] += dt
		var p: PackedVector2Array = b["path"]
		while not p.is_empty() and NpcRoutine.arrived(a.loco.render, p[0]):
			p.remove_at(0)
		if p.is_empty() or b["t"] > 20.0:
			a.move(Vector2.ZERO, dt)
			if a.loco.motion == "idle":
				_bg.erase(b)
			continue
		b["path"] = NpcRoutine.walk_path(a, p, dt)
		b["still"] = b["still"] + dt if a.loco.render == b["last"] else 0.0
		b["last"] = a.loco.render
		if b["still"] > 1.0:
			b["still"] = 0.0
			b["path"] = _route(a, b["to"])
	if _job.is_empty():
		for a in actors.values():
			if is_instance_valid(a) and not moving.has(a) and a.loco.motion != "idle":
				a.move(Vector2.ZERO, dt)
		return
	var j := _job
	match j["kind"]:
		"move":
			var a: Actor = j["actor"]
			var to: Vector2 = j["to"]
			j["t"] += dt
			var p: PackedVector2Array = j["path"]
			if p.is_empty() and not world.has_method("path"):                 # 길찾기가 없는 맵(청크 월드): 곧장 걷는다
				var d := to - a.loco.logical
				if d.length() <= 2.4 or j["t"] > 20.0:
					a.move(Vector2.ZERO, dt)
					if a.loco.motion == "idle" or j["t"] > 20.0:
						_finish()
					return
				a.move(_dir8(d), dt)
				return
			while not p.is_empty() and NpcRoutine.arrived(a.loco.render, p[0]):
				p.remove_at(0)
			j["path"] = p
			if p.is_empty() or j["t"] > 20.0:
				a.move(Vector2.ZERO, dt)
				if a.loco.motion == "idle":
					_finish()
				return
			j["path"] = NpcRoutine.walk_path(a, p, dt)
			j["still"] = j["still"] + dt if a.loco.render == j["last"] else 0.0  # 막혀 서 있으면(다른 인물 등) 길을 다시 찾는다
			j["last"] = a.loco.render
			if j["still"] > 1.0:
				j["still"] = 0.0
				j["path"] = _route(a, to)
				if (j["path"] as PackedVector2Array).is_empty():
					push_warning("move: 길이 없다 %s → %s" % [str(a.loco.render), str(to)])
					j["t"] = 99.0
		"wait":
			j["left"] -= dt
			if j["left"] <= 0.0:
				_finish()
		"wait_go":
			j["t"] += dt
			if _bg.is_empty() or j["t"] > 20.0:
				_finish()
		"fade":
			j["t"] += dt
			var k := clampf(j["t"] / maxf(j["len"], 0.001), 0.0, 1.0)
			fade_mat.set_shader_parameter("amount", lerpf(j["from"], j["to"], k))
			if k >= 1.0:
				_finish()
		"shake":
			j["left"] -= dt
			cam.offset = Vector2(randi_range(-2, 2), randi_range(-1, 1)) if j["left"] > 0.0 else Vector2.ZERO
			if j["left"] <= 0.0:
				_finish()
		"cam":
			j["t"] += dt
			var k := clampf(j["t"] / j["len"], 0.0, 1.0)
			cam.position = (j["from"] as Vector2).lerp(j["to"], k * k * (3.0 - 2.0 * k)).round()
			if k >= 1.0:
				_finish()
		"gate":
			j["t"] += dt
			var k := clampf(j["t"] / maxf(j["len"], 0.001), 0.0, 1.0)
			world.set_gate(lerpf(j["from"], j["to"], k * k * (3.0 - 2.0 * k)))
			cam.offset = Vector2(randi_range(-1, 1), 0) if k < 1.0 and int(j["t"] * 20.0) % 3 == 0 else Vector2.ZERO
			if k >= 1.0:
				cam.offset = Vector2.ZERO
				_finish()
		"card":
			j["t"] += dt
			var t: float = j["t"]
			var amt := clampf(t / 0.5, 0.0, 1.0) if t < 3.0 else clampf(1.0 - (t - 3.0) / 0.6, 0.0, 1.0)
			fade_mat.set_shader_parameter("amount", amt)
			card.queue_redraw()
			if t >= 3.6:
				card_lines = []
				card.queue_redraw()
				_finish()


func _finish() -> void:
	var done: Callable = _job["done"]
	_job = {}
	done.call()


## 8방향으로 맞춘 입력(이동 방향 스냅, SD-16 §3.6.5 ①)
static func _dir8(v: Vector2) -> Vector2:
	var i := posmod(int(round(v.angle() / (PI / 4.0))), 8)
	return Locomotion.VEC[i].normalized()


# ---------------------------------------------------------------- 그리기: 말풍선·램프(맵 좌표), 연도 카드(화면)
func _draw() -> void:
	for b in balloons:
		var a: Actor = b["actor"]
		if not is_instance_valid(a):
			continue
		var t: float = b["t"]
		var pop := 2 if t < 0.08 else 0                               # 처음 두 프레임은 2px 커졌다가
		var c := a.position + Vector2(6, a.head_y() - 15.0)              # 꼬리 끝이 머리 위 4px(어른 -50, 아기는 그만큼 낮게)
		var r := Rect2(c - Vector2(8 + pop, 8 + pop), Vector2(16 + pop * 2, 15 + pop * 2))
		draw_rect(r, Color("1A181D"))
		draw_rect(r.grow(-1), Color("E9E4D8"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 7 + pop), c + Vector2(0, 7 + pop), c + Vector2(-5, 11 + pop)]), Color("1A181D"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 6 + pop), c + Vector2(-1, 6 + pop), c + Vector2(-4, 9 + pop)]), Color("E9E4D8"))
		_draw_glyph(str(b["kind"]), c)
	for l in lamps:
		if fmod(l["t"], 0.25) < 0.15:
			draw_rect(Rect2(l["pos"] - Vector2(2, 2), Vector2(4, 4)), l["color"])
			draw_rect(Rect2(l["pos"] - Vector2(1, 3), Vector2(2, 6)), l["color"])


func _draw_glyph(kind: String, c: Vector2) -> void:
	var ink := Color("1A181D")
	match kind:
		"!":
			draw_rect(Rect2(c + Vector2(-1, -5), Vector2(2, 6)), Color("E04A35"))
			draw_rect(Rect2(c + Vector2(-1, 3), Vector2(2, 2)), Color("E04A35"))
		"?":
			draw_string(font, c + Vector2(-3, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		"heart":
			for p in [Vector2(-4, -3), Vector2(-3, -4), Vector2(-2, -4), Vector2(1, -4), Vector2(2, -4), Vector2(3, -3)]:
				draw_rect(Rect2(c + p, Vector2(1, 1)), Color("E04A35"))
			draw_rect(Rect2(c + Vector2(-4, -2), Vector2(8, 3)), Color("E04A35"))
			draw_rect(Rect2(c + Vector2(-3, 1), Vector2(6, 1)), Color("E04A35"))
			draw_rect(Rect2(c + Vector2(-2, 2), Vector2(4, 1)), Color("E04A35"))
			draw_rect(Rect2(c + Vector2(-1, 3), Vector2(2, 1)), Color("E04A35"))
		"...":
			for k in 3:
				draw_rect(Rect2(c + Vector2(-5 + k * 4, 1), Vector2(2, 2)), ink)
		"note":
			draw_rect(Rect2(c + Vector2(1, -5), Vector2(1, 7)), ink)
			draw_rect(Rect2(c + Vector2(-2, 1), Vector2(3, 3)), ink)
			draw_rect(Rect2(c + Vector2(2, -5), Vector2(2, 1)), ink)
		"sweat":
			draw_rect(Rect2(c + Vector2(-1, -4), Vector2(2, 3)), Color("4C7DC8"))
			draw_rect(Rect2(c + Vector2(-2, -1), Vector2(4, 4)), Color("4C7DC8"))
		"anger":
			for p in [Vector2(-4, -4), Vector2(1, -4), Vector2(-4, 1), Vector2(1, 1)]:
				draw_rect(Rect2(c + p, Vector2(3, 1)), Color("E04A35"))
				draw_rect(Rect2(c + p + (Vector2(2, 0) if p.x > 0 else Vector2.ZERO), Vector2(1, 3)), Color("E04A35"))


func _draw_card() -> void:
	if card_lines.is_empty() or _job.get("kind", "") != "card":
		return
	var t: float = _job["t"]
	if t < 0.5 or t > 3.0:
		return
	var vs := card.get_viewport_rect().size
	var ink := Color("E9E4D8") if _job["dark"] else Color("1A181D")
	var big: String = card_lines[0]
	var w := font_big.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	card.draw_string(font_big, Vector2(floorf((vs.x - w) / 2.0), floorf(vs.y / 2.0) - 4), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, ink)
	if card_lines.size() > 1:
		var s: String = card_lines[1]
		var w2 := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		card.draw_string(font, Vector2(floorf((vs.x - w2) / 2.0), floorf(vs.y / 2.0) + 24), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			ink.darkened(0.15))
