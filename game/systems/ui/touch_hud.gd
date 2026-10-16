## 터치 HUD(SD-12 §17.1·§17.2, SD-11 §15.3~15.5, 단계 0-11): 떠다니는 이동 스틱(왼쪽 아래) + 조준·사격 스틱(오른쪽 아래) + 행동 단추.
## 640×360 격자에 그리고, 넓은 화면에서는 왼쪽 묶음은 왼쪽 가장자리, 오른쪽 묶음은 오른쪽 가장자리에 붙는다(§17.3).
## 이동 스틱: 반경 25% 안 = 걷기, 25~85% = 달리기. 조준 스틱: 25% 넘게 끌면 정조준(터치 조준 = 정조준 취급), 85% 링 밖이면 사격,
## 0.2초 안에 톡 치면 보조 표적에게 한 발. 조준 보조(보통): 반각 15° 원뿔, 각도 차의 60%만큼 가장 가까운 적 쪽으로(§15.4).
## 단추: 상황(말하기·열기 — 조사할 것이 있을 때만) · 재장전(탄약 수) · 웅크리기(토글) · 회복(스팀팩) · 무기(넣기·꺼내기) · 핍-보이 · 일시 정지.
## 대화·연출·핍-보이·용기·일시 정지 중에는 모두 숨는다(§17.2). 판정 영역은 그림보다 사방 2px 넓게, 최소 40×40(§17.1).
## 진행기는 host와 pause(Callable)를 넘긴다. 터치를 한 번이라도 받으면 켜지고(모바일은 처음부터), 키보드·마우스를 쓰면 다시 숨는다.
class_name TouchHud
extends CanvasLayer

const DEAD := 0.25
const FIRE := 0.85
const RING := 44.0                                ## 바깥 링 반지름(지름 88)
const KNOB := 18.0                                ## 손잡이 반지름(지름 36)
const TAP_S := 0.2
const ASSIST_DEG := 15.0
const ASSIST_PULL := 0.6
const MOVE_AREA := Rect2(0, 192, 280, 168)        ## 이동 스틱 활성 영역(왼쪽 묶음 기준)
const AIM_AREA := Rect2(440, 192, 200, 168)       ## 조준 스틱 활성 영역(오른쪽 묶음 기준, 단추 밖)
const MOVE_HOME := Vector2(72, 288)
const AIM_HOME := Vector2(564, 284)
const SPRINT_RING := 56.0                         ## 질주 링 지름 112(SD-12 §17.2): 바깥 링 밖까지 0.3초 밀면 질주(SD-11 §15.5)
const SPRINT_S := 0.3
const CALM_S := 3.0                               ## 교전이 끝나고 3초 뒤 집중 · 구르기 단추를 30%로(SD-12 §17.2 비전투 축소)
## 단추: id → [오른쪽 묶음?, 사각형(640×360 기준), 글]
const BUTTONS := {
	"act": [true, Rect2(408, 292, 48, 48), "상황"],
	"focus": [true, Rect2(460, 296, 44, 44), "집중"],
	"dodge": [true, Rect2(466, 244, 40, 40), "구르기"],
	"reload": [true, Rect2(556, 196, 36, 36), "재장전"],
	"crouch": [true, Rect2(596, 196, 36, 36), "웅크림"],
	"heal": [true, Rect2(516, 152, 40, 36), "회복"],
	"weapon": [true, Rect2(560, 152, 72, 36), "무기"],
	"pip": [true, Rect2(556, 8, 36, 36), "핍"],
	"pause": [true, Rect2(596, 8, 36, 36), "||"],
}

var host: InteriorHost
var pause: Callable
var on := false                                   ## 터치 조작이 켜져 있다
var move_id := -1                                 ## 이동 스틱을 쥔 손가락
var move_c := Vector2.ZERO                        ## 이동 스틱 중심(화면 좌표 — view 기준)
var move_v := Vector2.ZERO                        ## -1~1
var aim_id := -1
var aim_c := Vector2.ZERO
var aim_v := Vector2.ZERO
var aim_t := 0.0                                  ## 조준 스틱을 쥔 시간(톡 치기 판정)
var tap_shot := 0.0                               ## 톡 쏘기: 남은 사격 시간
var pressed := {}                                 ## 손가락 → 단추 id
var flash := {}                                   ## 단추 id → 누름 표시 남은 초
var view: Control
var f10: Font
var move_raw := 0.0                               ## 이동 스틱을 끈 거리(px)
var move_out := 0.0                               ## 이동 스틱을 바깥 링 밖에 둔 초(질주 판정)
var calm_t := 0.0                                 ## 교전 아닌 채로 지난 초(비전투 축소)
var off_r := 0.0                                  ## 오른쪽 묶음을 화면 오른쪽 끝에 붙이는 이동량(넓은 화면)


func setup(h: InteriorHost, pause_: Callable) -> TouchHud:
	host = h
	pause = pause_
	return self


func _init() -> void:
	layer = 15
	f10 = load("res://assets/fonts/Galmuri9.ttf")
	view = Control.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_hud)
	add_child(view)


func _ready() -> void:
	on = OS.has_feature("mobile")


func hidden() -> bool:
	return host == null or host.box.active or host.ev.busy() or host.busy or host.pipboy != null or host.container != null \
		or host.body == "hidden" or host.locked or get_tree().paused


func _process(dt: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	view.size = vs
	off_r = vs.x - 640.0
	tap_shot = maxf(0.0, tap_shot - dt)
	for k in flash.keys():
		flash[k] = float(flash[k]) - dt
		if float(flash[k]) <= 0.0:
			flash.erase(k)
	if aim_id >= 0:
		aim_t += dt
	move_out = move_out + dt if move_id >= 0 and move_raw >= RING else 0.0
	if host != null:
		calm_t = 0.0 if host.combat.in_combat() else calm_t + dt
	if host != null:
		host.touch_layout = on
	if on and host != null:
		if hidden():
			_release_all()
		else:
			host.act_held = pressed.values().has("act")             # '상황' 단추를 누르고 있다(동행 일으키기 2초)
			host.input_vec = move_v
			host.touch_sprint = move_out >= SPRINT_S
			_drive_combat()
	view.queue_redraw()


## 조준 스틱 → 전투 입력(봇 입력 칸을 같이 쓴다: aim = 세계 좌표, aimed = 정조준)
func _drive_combat() -> void:
	var c := host.combat
	var b := {"crouch": c.crouch}
	var mag := aim_v.length()
	if aim_id >= 0 and mag >= DEAD:
		var dir := _assist(aim_v.normalized())
		b["aim"] = host.player.loco.logical + Vector2(0, -14) + dir * 96.0
		b["aimed"] = true
		b["fire"] = mag >= FIRE
	elif tap_shot > 0.0:
		b["fire"] = true                                               # 톡: 보조 표적(자동 조준)에게
	c.bot = b


## 조준 보조(§15.4 보통): 반각 15° 안, 유효 사거리 안의 가장 가까운 적 쪽으로 각도 차의 60%
func _assist(dir: Vector2) -> Vector2:
	var c := host.combat
	if not c.armed():
		return dir
	var me := host.player.loco.logical + Vector2(0, -14)
	var reach := float(c.weapon().get("range_eff", 8.0)) * 32.0
	var best := Vector2.ZERO
	var bd := INF
	for e in c.enemies:
		if not is_instance_valid(e) or e.cmb.dead or e.cmb.team != "enemy":
			continue
		var to: Vector2 = e.loco.logical + Vector2(0, -6) - me
		if to.length() > reach or absf(rad_to_deg(dir.angle_to(to))) > ASSIST_DEG:
			continue
		if to.length() < bd:
			bd = to.length()
			best = to
	if best == Vector2.ZERO:
		return dir
	return dir.rotated(dir.angle_to(best) * ASSIST_PULL)


func _release_all() -> void:
	move_id = -1
	aim_id = -1
	move_v = Vector2.ZERO
	move_raw = 0.0
	move_out = 0.0
	aim_v = Vector2.ZERO
	pressed.clear()
	if host != null:
		host.input_vec = Vector2.ZERO
		host.touch_sprint = false
		if on:
			host.combat.bot = {}


# ---------------------------------------------------------------- 입력
## 입력 좌표는 이미 논리 화면(640×360 이상, 늘이기 모드 viewport) 좌표로 온다
func _local(p: Vector2) -> Vector2:
	return p


func _btn_rect(id: String) -> Rect2:
	var b: Array = BUTTONS[id]
	var r: Rect2 = b[1]
	if b[0]:
		r.position.x += off_r
	return r


func _btn_at(p: Vector2) -> String:
	for id in BUTTONS:
		if id == "act" and _act_label() == "":
			continue
		if _btn_rect(id).grow(2.0 + maxf(0.0, (40.0 - _btn_rect(id).size.x) / 2.0)).has_point(p):
			return id
	return ""


func _input(e: InputEvent) -> void:
	if e is InputEventKey:
		if on and e.pressed and not OS.has_feature("mobile"):
			on = false                                                 # 키보드를 쓰면 터치 단추를 숨긴다
			_release_all()
		return
	if not (e is InputEventScreenTouch or e is InputEventScreenDrag):
		return
	if not on:
		on = true
	if hidden():
		return
	var p := _local(e.position)
	if e is InputEventScreenTouch:
		if e.pressed:
			var id := _btn_at(p)
			if id != "":
				pressed[e.index] = id
				flash[id] = 0.15
				_press(id)
			elif MOVE_AREA.has_point(p) and move_id < 0:
				move_id = e.index
				move_c = p
				move_v = Vector2.ZERO
			elif Rect2(AIM_AREA.position + Vector2(off_r, 0), AIM_AREA.size).has_point(p) and aim_id < 0:
				aim_id = e.index
				aim_c = p
				aim_v = Vector2.ZERO
				aim_t = 0.0
			get_viewport().set_input_as_handled()
		else:
			if e.index == move_id:
				move_id = -1
				move_v = Vector2.ZERO
				move_raw = 0.0
			elif e.index == aim_id:
				if aim_t <= TAP_S and aim_v.length() < DEAD:
					tap_shot = 0.08                                    # 톡 쏘기 한 발
				aim_id = -1
				aim_v = Vector2.ZERO
			pressed.erase(e.index)
			get_viewport().set_input_as_handled()
	else:
		if e.index == move_id:
			move_v = _stick(p - move_c)
			move_raw = (p - move_c).length()
			get_viewport().set_input_as_handled()
		elif e.index == aim_id:
			aim_v = _stick(p - aim_c)
			get_viewport().set_input_as_handled()


static func _stick(d: Vector2) -> Vector2:
	var v := d / RING
	return v.limit_length(1.0) if v.length() >= DEAD else Vector2.ZERO


func _act_label() -> String:
	if host == null or host.map == null:
		return ""
	return host.interact_label() if host.has_method("interact_label") else ""


func _press(id: String) -> void:
	var c := host.combat
	match id:
		"act":
			host.interact()
		"focus":
			calm_t = 0.0
			c.focus_req = true                                         # 탭 = 조준 중이면 그 방향, 아니면 보조 표적으로 집중 사격
		"dodge":
			calm_t = 0.0
			host.roll_req = true                                       # 방향 = 이동 스틱, 없으면 몸 반대쪽(뒤로)
		"reload":
			c.start_reload(host.st)
		"crouch":
			c.crouch = not c.crouch
		"heal":
			c.use_stimpak(host.st, true)
		"weapon":
			if c.weapon_id != "":
				c.holstered = not c.holstered
				host.st.weapon_out = c.armed()
				c._doll()
		"pip":
			if host.pipboy_ok:
				host.open_pipboy()
		"pause":
			if pause.is_valid():
				pause.call()


# ---------------------------------------------------------------- 그리기(호환 렌더러: 선·사각형·글자만)
const INK := Color("1A181D")
const FILL := Color(0.06, 0.07, 0.06, 0.45)
const LINE := Color(0.82, 0.95, 0.84, 0.55)
const HOT := Color(1.0, 0.76, 0.29, 0.85)


func _draw_hud() -> void:
	if not on or hidden():
		return
	var v := view
	# 이동 스틱: 쥐지 않았으면 기본 자리에 흐리게
	var mc := move_c if move_id >= 0 else MOVE_HOME
	if move_id >= 0:                                                   # 질주 링(지름 112): 밀어 질주하면 노랗게
		v.draw_arc(mc, SPRINT_RING, 0, TAU, 40, HOT if host.combat.sprinting or move_out >= SPRINT_S else Color(LINE, 0.25), 1.0)
	_ring(mc, RING, 0.9 if move_id >= 0 else 0.45)
	var mk := mc + move_v * RING
	v.draw_circle(mk, KNOB, Color(LINE, 0.35 if move_id >= 0 else 0.2))
	v.draw_arc(mk, KNOB, 0, TAU, 24, LINE, 1.0)
	# 조준 스틱
	var ac := aim_c if aim_id >= 0 else AIM_HOME + Vector2(off_r, 0)
	_ring(ac, RING, 0.9 if aim_id >= 0 else 0.45)
	v.draw_arc(ac, RING * FIRE, 0, TAU, 32, Color(HOT, 0.35), 1.0)          # 사격 링(85%)
	var firing := aim_id >= 0 and aim_v.length() >= FIRE
	var ak := ac + aim_v * RING
	v.draw_circle(ak, KNOB, Color(HOT if firing else LINE, 0.4 if aim_id >= 0 else 0.2))
	v.draw_arc(ak, KNOB, 0, TAU, 24, HOT if firing else LINE, 1.0)
	# 단추
	for id in BUTTONS:
		var label: String = BUTTONS[id][2]
		if id == "act":
			label = _act_label()
			if label == "":
				continue
		var r := _btn_rect(id)
		var down: bool = flash.has(id) or pressed.values().has(id)
		var rr := Rect2(r.position + (Vector2(0, 1) if down else Vector2.ZERO), r.size)
		var lit: bool = (id == "crouch" and host.combat.crouch) or (id == "weapon" and host.combat.armed())
		var fill: Color = Color(HOT, 0.45) if down else (Color(0.18, 0.55, 0.26, 0.5) if lit else FILL)
		if id in ["focus", "dodge"]:                                    # AP 부족 = 회색(§15.5) · 교전 끝 3초 뒤 30%(§17.2)
			var dim := 0.3 if calm_t >= CALM_S and not down else 1.0
			var gray := not host.combat.ap.can(_ap_cost(id))
			fill = Color(0.3, 0.3, 0.3, 0.35) if gray and not down else fill
			v.draw_rect(rr, Color(fill, fill.a * dim))
			v.draw_rect(Rect2(rr.position + Vector2(0.5, 0.5), rr.size - Vector2.ONE), Color(LINE, LINE.a * dim), false, 1.0)
			_label(rr, label, Color(0.62, 0.62, 0.62, dim) if gray else Color(0.914, 0.894, 0.847, dim))
			continue
		v.draw_rect(rr, fill)
		v.draw_rect(Rect2(rr.position + Vector2(0.5, 0.5), rr.size - Vector2.ONE), LINE, false, 1.0)
		if id == "reload" and host.combat.armed() and host.combat.weapon()["kind"] == "ranged":
			var mag := int(host.combat.mags.get(host.combat.weapon_id, 0))      # 두 줄: 재장전 / 탄창·여분 — 빈 탄창은 붉게
			_label(Rect2(rr.position - Vector2(0, 6), rr.size), label)
			_label(Rect2(rr.position + Vector2(0, 7), rr.size), "%d/%d" % [mag, host.combat.ammo_left(host.st)], HOT if mag == 0 else Color("E9E4D8"))
			continue
		elif id == "heal":
			label = "회복 %d" % int(host.st.items.get(InteriorCombat.STIMPAK, 0))
		elif id == "weapon":
			label = str(host.items_db.get(host.combat.weapon_id, {}).get("name", "맨손")) if host.combat.weapon_id != "" else "맨손"
		_label(rr, label)


func _ap_cost(id: String) -> float:
	if id == "dodge":
		return APPool.DODGE
	var c := host.combat
	return InteriorCombat.focus_cost(c.weapon()) if c.armed() and c.weapon()["kind"] == "ranged" else 999.0


func _ring(c: Vector2, r: float, a: float) -> void:
	view.draw_circle(c, r, Color(FILL, FILL.a * a))
	view.draw_arc(c, r, 0, TAU, 40, Color(LINE, LINE.a * a), 1.0)


func _label(r: Rect2, s: String, col := Color("E9E4D8")) -> void:
	var w := f10.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var p := Vector2(floorf(r.position.x + (r.size.x - w) / 2.0), floorf(r.position.y + r.size.y / 2.0 + 4))
	view.draw_string(f10, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	view.draw_string(f10, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
