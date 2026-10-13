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
var input_fn := Callable()                       ## 봇: 1/60초마다 다시 묻는 이동 입력(긴 프레임에서 칸 가운데를 지나쳐 맴돌지 않게)
var use_keyboard := true
var busy := false                                ## 전환·대화·연출 중
var banner: Control
var banner_text := ""
var banner_t := 0.0
var font: Font
var body := "adult"                              ## 주인공 모습: adult 페이퍼돌 · kid 아이 페이퍼돌(K1, 2268 열 살) · toddler 걸음마(2259 돌잔치,
                                                 ## 걷기만·느림) · hidden 안 보임(컷신)
var locked := false                              ## 주인공 조작 막기(연출 장면)
var fired := {}                                  ## once 밟는 칸: "맵:x,y" -> true
var hints: Array = []                           ## 조작 도움말 차례: [[글, 초], …] — 맵 이름 띠가 지나간 뒤, 대화 중에는 멈췄다가 하나씩
var hint_t := 0.0
const CROUCH_WALK := {"walk": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": 1.5}}   ## 웅크려 걷기 1.5t/초(SD-11 §2.4)
const TODDLER_WALK := {"walk": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": 1.8}}
var combat: InteriorCombat                       ## 실내 전투(무기·표적·적) — 무기를 들지 않으면 아무것도 하지 않는다
var pipboy: PipBoy                               ## 열려 있는 핍-보이(없으면 null)
var pipboy_ok := false                           ## 핍-보이를 받았다(MQ-P2 생일잔치부터)
var items_db := {}                               ## 아이템 ID -> 이름·분류·설명(data/items.json + weapons.json)
var date_text := ""                              ## 핍-보이 위 줄 날짜
var cam_lead := Vector2.ZERO                     ## 카메라 리드(조준 쪽으로 끌린 만큼)
var text_seen := {}                              ## 여러 번 조사하는 글: 키 -> 읽은 횟수
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
	combat = InteriorCombat.new()
	add_child(combat)
	combat.message.connect(func(t: String) -> void: hint(t, 3.0))
	combat.hurt.connect(func(_a: float) -> void: _hurt_t = 0.3)
	_handlers()
	_load_items()
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
			if body == "kid":
				lk["body"] = "K1"
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
	combat.on_map(map, player, st)
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
	_hurt_t = maxf(0.0, _hurt_t - dt)
	_hud_t += dt
	_drain_events()
	for n in notes:
		n[1] -= dt
	notes = notes.filter(func(n): return n[1] > 0.0)
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
	talking = talking or pipboy != null
	if talking:
		player.move(Vector2.ZERO, dt)
	else:
		var v := input_vec
		if use_keyboard and v == Vector2.ZERO:
			v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		player.mode = "walk" if body == "toddler" or combat.crouch or combat.inject_t > 0.0 else "run"
		player.loco.custom = TODDLER_WALK if body == "toddler" else (CROUCH_WALK if combat.crouch else {})
		if input_fn.is_valid():
			var left := dt
			while left > 0.0001:
				var h := minf(left, 1.0 / 60.0)
				left -= h
				player.move(input_fn.call(), h)
		else:
			player.move(v, dt)
		if player.doll != null:
			player.doll.position.y = 2.0 if combat.crouch else 0.0               # 웅크리면 2px 낮게(전용 그림 전까지)
		if use_keyboard and Input.is_action_just_pressed("interact") and not box.active:
			interact()
		if use_keyboard and pipboy_ok and Input.is_action_just_pressed("pipboy"):
			open_pipboy()
		_check_exit()
	combat.tick(dt, not talking, st)
	var want := Vector2.ZERO                                              # 조준 쪽으로 카메라를 끈다(원거리 무기, 최대 3칸 — SD-12 §15 '카메라 리드')
	if combat.armed() and combat.weapon()["kind"] == "ranged" and not talking:
		want = ((combat._aim_point(player) - player.loco.logical) * 0.4).limit_length(96.0)
	cam_lead = cam_lead.lerp(want, 1.0 - exp(-dt * 5.0))
	cam.position = (player.loco.logical + cam_lead).round()


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
			var m: Dictionary = map.text_meta.get(cc, {})
			if not m.is_empty():
				if not InteriorMap._cond_ok(str(m["cond"]), st):
					continue
				var n := int(text_seen.get(m["key"], 0))
				if n < m["seq"].size():                                      # 여러 번 조사: 차례로 다른 글, 다 읽으면 장면
					text_seen[m["key"]] = n + 1
					say_text(m["seq"][n])
					return true
				if m["scene"] != "":
					play_scene(m["scene"])
					return true
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


# ---------------------------------------------------------------- HUD (SD-12 §4.2 PC 배치, U 팔레트 단색 + 1px U0 테두리)
const HU := DocScreen.GREEN
const HUD_RED := Color("E04A35")
var hud_on := false                              ## 핍-보이를 받으면 켠다(HUD = 핍-보이 표시)
var buddy_name := ""                             ## 일시 동행 이름(HUD 동행 칸)
var _hurt_t := 0.0
var _hud_t := 0.0
var font_s: Font


func _draw_hud() -> void:
	if not hud_on or box.active or ev.busy() or busy or pipboy != null or body == "hidden":
		return
	if font_s == null:
		font_s = load("res://assets/fonts/Galmuri9.ttf")
	var vs := banner.get_viewport_rect().size
	var b := vs.y - 360.0                                                    # 아래 붙이기
	var r := vs.x - 640.0                                                    # 오른쪽 붙이기
	var c := combat.pc
	var low := c.hp <= c.max_hp * 0.2
	if _hurt_t > 0.0 or low:                                                 # 맞음: 가장자리 붉은 테 0.3초 / 20% 이하 맥동
		var a := 0.5 if _hurt_t > 0.0 else 0.25 + 0.2 * sin(_hud_t * 7.0)
		for rr in [Rect2(0, 0, vs.x, 3), Rect2(0, vs.y - 3, vs.x, 3), Rect2(0, 0, 3, vs.y), Rect2(vs.x - 3, 0, 3, vs.y)]:
			banner.draw_rect(rr, Color(HUD_RED, a))
	_bar(Vector2(70, 330 + b), 140.0, c.hp / maxf(1.0, c.max_hp), "HP", HUD_RED if low else HU[5])
	var ap := float(status()["ap_max"])
	_bar(Vector2(430 + r, 330 + b), 140.0, 1.0 if ap > 0.0 else 0.0, "AP", HU[5])
	if combat.armed() and combat.weapon()["kind"] == "ranged":
		var t := "장전 중" if combat.reload_t > 0.0 else "%d/%d" % [int(combat.mags.get(combat.weapon_id, 0)), combat.ammo_left(st)]
		_txt(Vector2(632 + r, 322 + b), t, HU[6], HORIZONTAL_ALIGNMENT_RIGHT)
	elif combat.armed():
		_txt(Vector2(632 + r, 322 + b), str(combat.weapon()["name"]), HU[5], HORIZONTAL_ALIGNMENT_RIGHT)
	var det := combat.detect_state()
	if det != "":
		var blink := det == "위험" and fmod(_hud_t, 0.3) < 0.15
		if not blink:
			_txt(Vector2(320 + r / 2.0, 9), "[%s]" % det, HU[5] if det == "숨음" else HUD_RED, HORIZONTAL_ALIGNMENT_CENTER)
	_ring(Vector2(36, 324 + b))
	var ny := 8.0 if hints.is_empty() else 36.0
	for n in notes:
		_txt(Vector2(8, ny), n[0], HU[6] if n[1] > 3.0 else HU[5])
		ny += 14.0
	var goal := _objective()
	if goal != "":
		_txt(Vector2(8, 66), goal, HU[5])
	if buddy_name != "" and combat.buddy != null:
		_txt(Vector2(8, 258 + b), buddy_name, HU[5])
		_bar(Vector2(8, 272 + b), 60.0, 1.0, "", HU[5])


func _bar(p: Vector2, w: float, f: float, label: String, col: Color) -> void:
	if label != "":
		_txt(p - Vector2(0, 11), label, HU[5])
	banner.draw_rect(Rect2(p - Vector2(1, 1), Vector2(w + 2, 8)), HU[0])
	banner.draw_rect(Rect2(p, Vector2(w, 6)), HU[2])
	banner.draw_rect(Rect2(p, Vector2(roundf(w * clampf(f, 0.0, 1.0)), 6)), col)


func _txt(p: Vector2, t: String, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var w := font_s.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var x := p.x - (w if align == HORIZONTAL_ALIGNMENT_RIGHT else (roundf(w / 2.0) if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0))
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		banner.draw_string(font_s, Vector2(x, p.y + font_s.get_ascent(10)) + o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, HU[0])
	banner.draw_string(font_s, Vector2(x, p.y + font_s.get_ascent(10)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


## 방위 링(SD-12 §4.3): 지름 56, 위 '북', 가운데 = 주인공, 적 = 붉은 마름모(반경 10 + 인지력×2 타일), 동행 = 푸른 원
func _ring(c: Vector2) -> void:
	banner.draw_arc(c, 27.0, 0, TAU, 32, HU[0], 3.0)
	banner.draw_arc(c, 27.0, 0, TAU, 32, HU[3], 1.0)
	banner.draw_arc(c, 24.0, 0, TAU, 32, HU[2], 1.0)
	_txt(c + Vector2(0, -33), "북", HU[5], HORIZONTAL_ALIGNMENT_CENTER)
	banner.draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), HU[6])
	var rad := (10.0 + 2.0 * st.stat("PE")) * 32.0
	for e in combat.enemies:
		if not is_instance_valid(e) or e.cmb.dead:
			continue
		var d: Vector2 = e.loco.logical - player.loco.logical
		if d.length() > rad:
			continue
		var q := (c + d / rad * 22.0).round()
		banner.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -2), q + Vector2(2, 0), q + Vector2(0, 2), q + Vector2(-2, 0)]), HUD_RED)
	if combat.buddy != null and is_instance_valid(combat.buddy):
		var d: Vector2 = combat.buddy.loco.logical - player.loco.logical
		if d.length() <= rad:
			banner.draw_circle((c + d / rad * 22.0).round(), 2.0, Color("4C7DC8"))


## 목표 줄(SD-12 §4.2): 진행 중인 메인 퀘스트의 지금 단계 기록 한 줄
func _objective() -> String:
	for id in ["MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		var s := st.quests.stage(id)
		if s > 0 and s < 100:
			var best := ""
			for n in st.quests.stages_of(id):
				if int(n) <= s and st.quests.log_text(id, int(n)) != "":
					best = st.quests.log_text(id, int(n))
			return "▶ " + best if best != "" else ""
	return ""


## 원고의 진행기 명령(0-7). 이벤트 실행기가 모르는 명령을 여기서 처리하고 done을 부른다
func _handlers() -> void:
	ev.handlers["pipboy"] = func(_a: Array, done: Callable) -> void:     # 핍-보이 받기: HUD를 켜고 튜토리얼로 한 번 연다(닫으면 이어진다)
		pipboy_ok = true
		hud_on = true
		var p := open_pipboy()
		p.first = true
		p.closed.connect(func(_ok: bool) -> void: done.call())
	ev.handlers["equip"] = func(a: Array, done: Callable) -> void:
		combat.equip(str(a[0]) if a.size() > 0 and str(a[0]) != "none" else "", st)
		done.call()
	ev.handlers["hurt"] = func(a: Array, done: Callable) -> void:      # 연출 피해(증기 분출 등)
		combat.damage(float(a[0]))
		_hurt_t = 0.3
		done.call()
	ev.handlers["buddy"] = func(a: Array, done: Callable) -> void:     # 일시 동행 시작(인물 ID) · 끝(off)
		var id := str(a[0])
		if id == "off":
			combat.buddy = null
			buddy_name = ""
		elif ev.actors.has(id):
			var b: Actor = ev.actors[id]
			map.blockers.erase(b)                                              # 동행은 길을 막지 않는다
			for n in npcs:
				if n["actor"] == b:
					n["routine"] = null
			combat.buddy = b
			buddy_name = st.npc_name(id).get_slice("(", 0).strip_edges()
		done.call()
	ev.handlers["range"] = func(a: Array, done: Callable) -> void:     # 사격장 단계: stealth = 은신 표적을 세운다
		combat.set_stealth_live(str(a[0]) == "stealth")
		done.call()
	ev.handlers["hint"] = func(a: Array, done: Callable) -> void:
		hint(str(a[0]), float(a[1]) if a.size() > 1 else 6.0)
		done.call()
	ev.handlers["hud"] = func(a: Array, done: Callable) -> void:
		hud_on = str(a[0]) != "off"
		done.call()


# ---------------------------------------------------------------- 핍-보이·소지품
func _load_items() -> void:
	for f in ["items_aid", "items_food", "items_quest", "items_apparel"]:          # 파이프라인이 SD-13 표에서 뽑은 아이템
		var p := "res://data/%s.json" % f
		if FileAccess.file_exists(p):
			items_db.merge(JSON.parse_string(FileAccess.get_file_as_string(p)))
	for id in combat.weapons:
		var w: Dictionary = combat.weapons[id]
		items_db[id] = {"name": w["name"], "cat": "weapon", "dmg": w["dmg"], "mag": w.get("mag"), "ammo": w.get("ammo", ""),
			"ammo_id": w.get("ammo_id", ""), "weight": w.get("weight", 0), "value": w.get("price", 0),
			"desc": "%s · %s · 사거리 %s타일 · 초당 %s회" % [w["skill"], "양손" if w.get("two_handed", false) else "한손",
				PipBoy._num(float(w["range_eff"])), PipBoy._num(float(w["rate"]))]}


## 핍-보이·HUD 위 줄 수치. 레벨(SD-10 §4.2): 다음 레벨까지 50 + 150 × 레벨, 누적 (L−1)(50 + 75L)
func status() -> Dictionary:
	var d := InteriorCombat.derived(st)
	var xp := int(st.vars.get_v("PC_XP"))
	var lv := 1
	while xp >= lv * (50 + 75 * (lv + 1)):
		lv += 1
	var carry := 0.0
	for id in st.items:
		carry += float(items_db.get(id, {}).get("weight", 0)) * int(st.items[id])
	return {"level": lv, "hp": int(ceilf(combat.pc.hp)), "hp_max": int(combat.pc.max_hp), "ap": int(d["ap_max"]), "ap_max": int(d["ap_max"]),
		"xp": xp, "xp_next": lv * (50 + 75 * (lv + 1)), "date": date_text, "equipped": combat.weapon_id if not combat.holstered else "",
		"stimpak_id": InteriorCombat.STIMPAK, "carry": carry, "carry_max": 150 + 10 * st.stat("ST"), "caps": int(st.vars.get_v("PC_CAPS")),
		"place": "볼트 S-07 · " + str(map.data["name"]) if map != null else "", "hotkeys": combat.hotkeys,
		"karma": int(st.vars.get_v("V_KARMA")) if st.vars.has("V_KARMA") else 0,
		"dr": int(items_db.get("A-001", {}).get("dr", 0)) if st.items.has("A-001") else 0}


## 알림(SD-12 §4.6): 이야기 상태의 사건(아이템·카르마·XP·퀘스트)을 꺼내 알림 줄로. 새 무기·스팀팩은 빈 단축키 칸에
var notes: Array = []                           ## [[글, 남은 초]]


func _drain_events() -> void:
	for e in st.events:
		match str(e.get("kind", "")):
			"item":
				var id := str(e["id"])
				var nm := str(items_db.get(id, {}).get("name", id))
				if int(e["delta"]) > 0:
					_note("%s 획득%s" % [nm, " ×%d" % int(e["delta"]) if int(e["delta"]) > 1 else ""])
					if combat.weapons.has(id) or id == InteriorCombat.STIMPAK:
						combat.auto_hotkey(id)
				elif not combat.weapons.has(id) and id != InteriorCombat.STIMPAK and not id.ends_with("탄"):
					_note("%s 건넴" % nm)
			"karma":
				_note("카르마가 %s." % ("올라갔습니다" if int(e["delta"]) > 0 else "내려갔습니다"))
			"xp":
				_note("+%d XP" % int(e["delta"]))
	st.events.clear()
	for q in st.quests.events:
		match str(q.get("kind", "")):
			"start":
				_note("새 퀘스트: " + st.quests.title(str(q["id"])))
			"done":
				_note("퀘스트 완료: " + st.quests.title(str(q["id"])))
	st.quests.events.clear()


func _note(t: String) -> void:
	for n in notes:
		if n[0] == t:
			n[1] = 3.5
			return
	notes.append([t, 3.5])
	if notes.size() > 4:
		notes.pop_front()


func _unhandled_input(e: InputEvent) -> void:
	if not hud_on or not use_keyboard or box.active or ev.busy() or busy or pipboy != null:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_8:
		combat.hotkey(int(e.keycode - KEY_0), st)
		get_viewport().set_input_as_handled()


func open_pipboy() -> PipBoy:
	if pipboy != null:
		return pipboy
	player.move(Vector2.ZERO, 0.0)
	pipboy = PipBoy.new().setup(st, items_db, status())
	pipboy.action.connect(_pip_action)
	pipboy.closed.connect(func(_ok: bool) -> void: pipboy = null)
	add_child(pipboy)
	return pipboy


func _pip_action(kind: String, id: String) -> void:
	match kind:
		"equip":
			combat.equip(id, st)
		"unequip":
			combat.equip("", st)
		"use":
			if id == InteriorCombat.STIMPAK:
				combat.use_stimpak(st)                                          # 핍-보이 안: 시간이 멈춘 채 쓴다(투여 모션 없음)
		_:
			if kind.begins_with("hotkey:"):
				var n := int(kind.substr(7))
				for k in combat.hotkeys.keys():
					if combat.hotkeys[k] == id:
						combat.hotkeys.erase(k)
				combat.hotkeys[n] = id
	if pipboy != null:
		pipboy.info = status()


func _on_dialogue_done() -> void:
	if not _talking.is_empty() and _talking["routine"] != null:
		_talking["routine"].resume()
	_talking = {}


func _draw_banner() -> void:
	_draw_hud()
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
