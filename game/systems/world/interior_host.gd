## 실내 놀이 진행기 (단계 0-5): 실내 맵 하나를 띄우고 주인공을 걷게 한다. 퀘스트 장면(0-6~0-9)이 이것 위에 얹힌다.
##   맵 전환: 출구 칸에 들어서면 디더 페이드 → 갈 맵의 표지(from_<지금 맵>)에 내려 그 방향을 본다 → 맵 이름 띠(쯔꾸르식).
##   조사 키(interact: E·Enter, 터치는 조사 단추): 바라보는 쪽 인물에게 말을 걸고(조건이 맞는 대화 장면, 없으면 한 줄 바크),
##     인물이 없으면 앞 칸의 조사 글(벽 앞이면 벽면 두 칸까지)을 읽는다.
##   인물: 맵 원고의 npc(cond가 참인 사람만), 일과(route)가 있으면 NpcRoutine으로 오간다. 대화 중에는 멈추고 주인공을 본다.
##   대화·연출 중에는 주인공이 움직이지 않는다. 이벤트 실행기(연출)·서류(Documents)도 여기에 붙는다.
class_name InteriorHost
extends Node2D

signal map_entered(map_id: String)
signal talked(npc_id: String, scene: String)

const BANNER_SECS := 2.4

var st: StoryState
var map: InteriorMap
var player: Actor
var cam: Camera2D
var box: DialogueBox
var ev: EventRunner
var npcs: Array = []                             ## [{"id", "actor", "routine", "bark"}]
var scenes_by_npc := {}                          ## 인물 ID -> [대화 장면, …](원고 순서)
var input_vec := Vector2.ZERO                    ## 외부(봇·터치)가 넣는 이동 입력. 없으면 키보드
var use_keyboard := true
var busy := false                                ## 전환·대화·연출 중
var banner: Control
var banner_text := ""
var banner_t := 0.0
var font: Font
var body := "adult"                              ## 주인공 모습: adult 페이퍼돌 · toddler 걸음마(2259 돌잔치, 걷기만·느림) · hidden 안 보임(컷신)
var locked := false                              ## 주인공 조작 막기(연출 장면)
var fired := {}                                  ## once 밟는 칸: "맵:x,y" -> true
var hints: Array = []                           ## 조작 도움말 차례: [[글, 초], …] — 맵 이름 띠가 지나간 뒤, 대화 중에는 멈췄다가 하나씩
var hint_t := 0.0
const TODDLER_WALK := {"walk": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": 1.8}}
var _talking: Dictionary = {}
var _last_tile := Vector2i(-99, -99)
var _from := ""


func _ready() -> void:
	font = load("res://assets/fonts/Galmuri11.ttf")
	if st == null:
		st = StoryState.new()
		st.load_data()
	_index_scenes()
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	box = DialogueBox.new()
	add_child(box)
	box.finished.connect(_on_dialogue_done)
	box.subject = _subject
	ev = EventRunner.new()
	add_child(ev)
	ev.attach(box)
	Documents.attach(ev, st, self)
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	banner = Control.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.draw.connect(_draw_banner)
	layer.add_child(banner)


func _index_scenes() -> void:
	var p := "res://data/dialogue/_index.json"
	if not FileAccess.file_exists(p):
		return
	for sid in JSON.parse_string(FileAccess.get_file_as_string(p))["scenes"]:
		var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % sid))
		var who: String = g.get("npc", "")
		if who != "":
			if not scenes_by_npc.has(who):
				scenes_by_npc[who] = []
			scenes_by_npc[who].append(g)


## 맵을 연다. mark: 주인공이 설 표지(없으면 첫 표지)
func enter(map_id: String, mark: String = "", look: Dictionary = {}) -> void:
	if map != null:
		for n in npcs:
			n["actor"].queue_free()
		npcs.clear()
		if player != null:
			map.remove_actor(player)
			map.objects.remove_child(player)
		map.queue_free()
	for a in ev.actors.values():                                    # 연출로 세운 인물·맵 인물은 옛 맵과 함께 사라진다
		if is_instance_valid(a) and a != player:
			a.queue_free()
	ev.actors.clear()
	map = InteriorMap.new()
	map.load_map(map_id, st)
	add_child(map)
	move_child(map, 0)
	if player != null and player.get_meta("body", "") != body:
		player.queue_free()                                          # 모습이 바뀌었다(걸음마 ↔ 어른): 새로 만든다
		player = null
	if player == null:
		player = Actor.new()
		if body == "toddler":
			var sk: String = CharDocs.look_of(st)["skin"]
			player.setup("st_look_k1_%s_hr00_h1_t01_0_pf11_hd00_ey00" % sk.to_lower(), Vector2.ZERO, map)
			player.loco.custom = TODDLER_WALK
		else:
			var lk := look if not look.is_empty() else CharDocs.paperdoll_look(CharDocs.look_of(st))
			player.setup_doll(lk, Vector2.ZERO, map)
		player.set_meta("body", body)
	player.world = map
	player.visible = body != "hidden"
	map.add_actor(player)
	var m: String = mark if map.marks.has(mark) else (map.marks.keys()[0] if not map.marks.is_empty() else "")
	player.loco.place(map.mark_pos(m))
	player.loco.facing = EventRunner.DIR_IDX.get(map.mark_dir(m), 2)
	player.position = player.loco.render
	player._show()
	_last_tile = map.tile_of(player.loco.logical)
	_spawn_npcs()
	ev.setup(map, map_id, cam)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = map.size.x * 32
	cam.limit_bottom = map.size.y * 32
	cam.position = player.loco.logical.round()
	cam.reset_smoothing()
	banner_text = map.data["name"]
	banner_t = BANNER_SECS
	map_entered.emit(map_id)


func _spawn_npcs() -> void:
	for n in map.data["npcs"]:
		var cond: String = n.get("cond", "")
		if cond != "" and not StoryExpr.test(cond, st):
			continue
		var sheet: String = n.get("sheet", ev.cast_sheets.get(n["id"], ""))
		if sheet == "" or not ResourceLoader.exists("res://assets/sprites/%s.tres" % sheet):
			continue
		if n.has("sheet"):
			st.portrait_alias[n["id"]] = n["sheet"]                    # 다른 시대 모습: 초상화도 그 모습으로
		else:
			st.portrait_alias.erase(n["id"])
		var a := Actor.new()
		a.setup(sheet, Vector2(int(n["x"]) * 32 + 16, int(n["y"]) * 32 + 16), map)
		a.mode = "walk"
		a.loco.facing = EventRunner.DIR_IDX.get(n["dir"], 2)
		a._show()
		map.add_actor(a)
		var r: NpcRoutine = NpcRoutine.new(a, map, n["route"]) if not n["route"].is_empty() else null
		npcs.append({"id": n["id"], "actor": a, "routine": r, "bark": n.get("bark", "")})
		ev.actors[n["id"]] = a                                       # 연출 명령(move·face·balloon·pose)이 맵 인물을 부를 수 있게
		map.blockers.append(a)


func _physics_process(dt: float) -> void:
	if map == null:
		return
	banner_t = maxf(0.0, banner_t - dt)
	if not hints.is_empty() and banner_t <= 0.0 and not box.active:
		hint_t += dt
		if hint_t >= float(hints[0][1]):
			hints.pop_front()
			hint_t = 0.0
	banner.queue_redraw()
	var talking: bool = box.active or ev.busy() or busy or locked or body == "hidden"
	for n in npcs:
		if n["routine"] != null and is_instance_valid(n["actor"]):
			n["routine"].tick(dt, player.loco.logical)
	if talking:
		player.move(Vector2.ZERO, dt)
	else:
		var v := input_vec
		if use_keyboard and v == Vector2.ZERO:
			v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		player.mode = "walk" if body == "toddler" else "run"
		player.move(v, dt)
		if use_keyboard and Input.is_action_just_pressed("interact") and not box.active:
			interact()
		_check_exit()
	cam.position = player.loco.logical.round()


func _check_exit() -> void:
	var t := map.tile_of(player.loco.logical)
	if t == _last_tile:
		return
	_last_tile = t
	for g in map.triggers_at(t):                                      # 밟는 칸: 조건이 맞으면 장면을 연다
		var key := "%s:%d,%d" % [map.id, int(g["x"]), int(g["y"])]
		if (g["once"] and fired.has(key)) or not InteriorMap._cond_ok(g["cond"], st):
			continue
		fired[key] = true
		player.move(Vector2.ZERO, 0.0)
		play_scene(g["scene"])
		return
	var e := map.exit_at(t)
	if e.is_empty():
		return
	go(e["to"], e["mark"])


## 원고의 대화 장면 하나를 연다(연출 명령은 이벤트 실행기가 맵 위에서 실행한다)
func play_scene(scene_id: String, label: String = "START") -> void:
	var p := "res://data/dialogue/%s.json" % scene_id
	if not FileAccess.file_exists(p):
		push_warning("없는 장면: " + scene_id)
		return
	box.open(st, JSON.parse_string(FileAccess.get_file_as_string(p)), label)


## 조작 도움말(쯔꾸르식 튜토리얼 띠): 화면 왼쪽 위에 secs초. 여럿이면 차례로, 맵 이름 띠가 사라진 뒤부터 센다
func hint(text: String, secs: float = 5.0) -> void:
	hints.append([text, secs])


## 다른 맵으로(디더 페이드). 갈 맵이 없으면(아직 만들지 않은 바깥 등) 막혔다는 글만 띄운다.
func go(map_id: String, mark: String) -> void:
	if not InteriorMap.exists(map_id):
		say_text("이 앞은 아직 갈 수 없다.")
		return
	busy = true
	player.move(Vector2.ZERO, 0.0)
	ev.run("fade_out", ["black", "3"], func() -> void:
		enter(map_id, mark)
		ev.run("fade_in", ["black", "3"], func() -> void: busy = false))


## 조사 키: 바라보는 쪽의 인물 → 조사 글(앞 칸, 벽 앞이면 벽면 두 칸)
func interact() -> bool:
	var f: Vector2 = Locomotion.VEC[player.loco.facing].normalized()
	var best: Dictionary = {}
	var best_d := 1e9
	for n in npcs:
		var v: Vector2 = n["actor"].loco.logical - player.loco.logical
		if v.length() < 46.0 and v.normalized().dot(f) > 0.5 and v.length() < best_d:
			best = n
			best_d = v.length()
	if not best.is_empty():
		talk(best)
		return true
	var c := map.tile_of(player.loco.logical + f * 24.0)
	var cells := [c]
	if f.y < -0.5:
		cells += [c + Vector2i(0, -1), c + Vector2i(0, -2)]
	for cc in cells:
		if map.texts.has(cc):
			say_text(map.texts[cc])
			return true
	return false


func talk(n: Dictionary) -> void:
	if n["routine"] != null:
		n["routine"].talk_to(player.loco.logical)
	else:
		n["actor"].loco.facing = Locomotion.snap8(player.loco.logical - n["actor"].loco.logical)
		n["actor"]._show()
	_talking = n
	var g := scene_for(n["id"])
	if g.is_empty():
		var bark: String = n["bark"] if n["bark"] != "" else "……"
		g = {"id": "bark_" + n["id"], "labels": {"START": 0}, "ops": [{"op": "line", "who": n["id"], "emo": "기본", "text": bark}, {"op": "end"}]}
	talked.emit(n["id"], g.get("id", ""))
	box.open(st, g)


## 이 인물의 대화 장면 가운데 조건이 맞는 첫 장면(없으면 빈 사전)
func scene_for(npc_id: String) -> Dictionary:
	for g in scenes_by_npc.get(npc_id, []):
		var cond: String = g.get("cond", "")
		if cond == "" or StoryExpr.test(cond, st):
			return g
	return {}


func say_text(text: String) -> void:
	box.open(st, {"id": "text", "labels": {"START": 0}, "ops": [{"op": "line", "who": "SYS", "emo": "기본", "text": text}, {"op": "end"}]})


## 대화 창 자리 정하기: 말하는 사람(무대·맵 인물)과 주인공의 화면 위 발 위치
func _subject(who: String) -> Array:
	var out := []
	var a = ev.actors.get(who)
	if a != null and is_instance_valid(a) and a.visible:
		out.append((a as Node2D).get_global_transform_with_canvas().origin)
	if player != null and player.visible and a != player:
		out.append(player.get_global_transform_with_canvas().origin)
	return out


func _on_dialogue_done() -> void:
	if not _talking.is_empty() and _talking["routine"] != null:
		_talking["routine"].resume()
	_talking = {}


func _draw_banner() -> void:
	if not hints.is_empty() and banner_t <= 0.0 and not box.active:
		var hint_text: String = hints[0][0]
		var hw := font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 20.0
		var hr := Rect2(10, 10, hw, 20)
		banner.draw_rect(hr.grow(1), Color("0B0A0D"))
		banner.draw_rect(hr, Color("1F3A6E"))
		banner.draw_rect(Rect2(hr.position + Vector2(0.5, 0.5), hr.size - Vector2.ONE), Color("4C7DC8"), false, 1.0)
		banner.draw_string(font, Vector2(hr.position.x + 10, hr.position.y + 3 + font.get_ascent(12)), hint_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 12, Color("E9E4D8"))
	if banner_t <= 0.0 or banner_text == "":
		return
	var vs := banner.get_viewport_rect().size
	var a := clampf(banner_t / 0.4, 0.0, 1.0) if banner_t < 0.4 else clampf((BANNER_SECS - banner_t) / 0.3, 0.0, 1.0)
	if a < 0.5:
		return                                                       # 반투명 없이: 나타날 때·사라질 때는 통째로 켜고 끈다
	var w := font.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 40.0
	var r := Rect2(floorf((vs.x - w) / 2.0), 14, w, 22)
	banner.draw_rect(r.grow(1), Color("0B0A0D"))
	banner.draw_rect(r, Color("1A181D"))
	banner.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), Color("ABA49A"), false, 1.0)
	banner.draw_line(r.position + Vector2(6, 11), r.position + Vector2(14, 11), Color("B08A1C"))
	banner.draw_line(r.end - Vector2(14, 11), r.end - Vector2(6, 11), Color("B08A1C"))
	banner.draw_string(font, Vector2(r.position.x + 20, r.position.y + 4 + font.get_ascent(12)), banner_text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 12, Color("E9E4D8"))
