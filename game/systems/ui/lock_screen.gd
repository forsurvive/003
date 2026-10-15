## 자물쇠 따기 화면(SD-12 §8.2, 단계 1-5): 필드를 어둡게 덮고 가운데 160×160 자물쇠 정면 원판, 위쪽 반원에 머리핀(72px, 0~180°),
## 아래에 드라이버(56px, 누르는 동안 시계 방향). 정보 줄 `등급 · 머리핀 n개 · (A/D) 각도 · (Space 누름) 돌리기 · (F) 강제 개방 · (Esc) 나가기`.
## 마우스: 가로 이동 = 각도, 왼쪽 버튼 누름 = 돌리기. 스킨 3종: door(문 실린더) · dial(금고 다이얼) · pad(사물함·택배함 소형).
## 핀 손상이 쌓일수록 떨림이 커지고, 부러지기 직전 0.2초 튕긴다. 옵션 '자물쇠 보조'면 원판 둘레에 근접도 막대.
class_name LockScreen
extends DocScreen

signal opened(xp: int)
signal jammed
signal pin_used                                   ## 머리핀 하나가 부러졌다(호출한 쪽이 소지품에서 뺀다)

const DISC_C := Vector2(320, 168)
const DISC_R := 80.0
const PIN_LEN := 72.0
const DRIVER_LEN := 56.0
const ANGLE_SPEED := 70.0                         ## A/D를 누르고 있을 때 초당 각도

var lock: Lockpick
var skin := "door"
var assist := false
var bot_turn := false                             ## 봇·시험용: 돌리기 누름
var bot_on := false
var _mouse_turn := false
var _snap := 0.0                                  ## 핀이 부러진 순간 튕김(초)
var _msg := ""
var _msg_t := 0.0
var _done_t := -1.0


func setup(state: StoryState, lock_value: int, hairpins: int, skin_name := "door", seed := 0) -> LockScreen:
	st = state
	skin = skin_name
	cancel_ok = true
	lock = Lockpick.new(Lockpick.grade_of(lock_value), st.skill("LOCKPICK"), hairpins, seed)
	if lock.state == "no_pins":
		_say("머리핀이 없다. 강제 개방(F)만 할 수 있다.")
	return self


func _say(s: String, secs := 2.5) -> void:
	_msg = s
	_msg_t = secs


# ---------------------------------------------------------------- 진행
func _tick(dt: float) -> void:
	_msg_t = maxf(0.0, _msg_t - dt)
	_snap = maxf(0.0, _snap - dt)
	if _done_t >= 0.0:
		_done_t -= dt
		if _done_t < 0.0:
			close(lock.state == "open")
		return
	if lock.state != "play":
		return
	if not bot_on:
		var d := 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
			d -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
			d += 1.0
		if d != 0.0:
			lock.set_angle(lock.angle + d * ANGLE_SPEED * dt)
	var turning := bot_turn or _mouse_turn or (not bot_on and Input.is_key_pressed(KEY_SPACE))
	var hp_before := lock.pin_hp
	var ev := lock.step(dt, turning)
	if hp_before > 0.0 and lock.pin_hp < 20.0 and hp_before >= 20.0:
		_snap = 0.2                                                    # 부러지기 직전 튕김
	match ev:
		"open":
			_say("찰칵. 열렸다.", 1.0)
			opened.emit(lock.xp())
			_done_t = 0.7
		"pin_broke":
			pin_used.emit()
			_say("머리핀이 부러졌다. 남은 머리핀 %d개." % lock.pins)
		"no_pins":
			pin_used.emit()
			_say("마지막 머리핀이 부러졌다. 강제 개방(F)만 남았다.")


func force_open() -> void:
	if lock.state not in ["play", "no_pins"]:
		return
	if lock.force():
		_say("억지로 비틀어 열었다.", 1.0)
		opened.emit(lock.xp())
	else:
		_say("자물쇠 안에서 무언가 부러졌다. 이제 열쇠가 있어야 한다.", 1.5)
		jammed.emit()
	_done_t = 1.0


# ---------------------------------------------------------------- 입력(서류 칸 대신 직접)
func _unhandled_input(e: InputEvent) -> void:
	if _done_t >= 0.0:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_F:
				force_open()
			KEY_ESCAPE:
				close(false)
			_:
				if e.is_action_pressed("ui_cancel"):
					close(false)
				else:
					return
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and lock.state == "play":
		var p := _local(e.position)
		lock.set_angle(clampf((p.x - (DISC_C.x - PIN_LEN)) / (PIN_LEN * 2.0) * 180.0, 0.0, 180.0))
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_mouse_turn = e.pressed
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- 그리기
func _draw_doc() -> void:
	var full := Rect2(-view.position, get_viewport().get_visible_rect().size)
	view.draw_rect(full, Color(0.02, 0.02, 0.03, 0.82))                 # 필드를 어둡게 덮는다
	var c := DISC_C
	var rot := deg_to_rad(lock.turn)
	var shake := 0.0
	if lock.state == "play" and lock.turn > 0.5 and lock.turn >= lock.max_turn() - 0.5:
		shake = (1.0 - lock.pin_hp / 100.0) * 2.5 + 0.6                   # 막혀서 버티는 떨림 — 손상이 쌓일수록 크게
	var jit := Vector2(sin(time * 61.0), cos(time * 47.0)) * shake
	_draw_body(c, rot)
	if assist and lock.state == "play":
		var k := lock.closeness()
		view.draw_arc(c, DISC_R + 6.0, PI, PI + PI * k, 32, DocScreen.GREEN[5], 3.0)
	# 드라이버(열쇠 구멍 아래쪽에 끼운 납작 날, 손잡이는 원판 밖 — 회전량만큼 시계 방향)
	var dv := Vector2(0, 1).rotated(rot)
	var dn := dv.orthogonal()
	var d0 := c + dv * 10.0
	var d1 := c + dv * (DISC_R + 6.0)
	view.draw_colored_polygon(PackedVector2Array([d0 - dn * 2.0, d0 + dn * 2.0, d1 + dn * 2.0, d1 - dn * 2.0]), C["P06"])
	view.draw_line(d0 - dn * 1.0, d1 - dn * 1.0, C["P08"], 1.0)
	var h0 := c + dv * (DISC_R + 4.0)
	var h1 := c + dv * (DISC_R + 4.0 + DRIVER_LEN * 0.55)
	view.draw_colored_polygon(PackedVector2Array([h0 - dn * 5.0, h0 + dn * 5.0, h1 + dn * 6.0, h1 - dn * 6.0]), C["P52"])   # 손잡이
	view.draw_colored_polygon(PackedVector2Array([h0 - dn * 5.0, h0 - dn * 2.0, h1 - dn * 3.0, h1 - dn * 6.0]), C["P54"])
	view.draw_line(h1 - dn * 6.0, h1 + dn * 6.0, C["P01"], 1.0)
	# 머리핀(열쇠 구멍 위쪽 끝에서, 위쪽 반원 0° = 왼쪽 끝 · 180° = 오른쪽 끝)
	var pa := deg_to_rad(180.0 - lock.angle)
	var pv := Vector2(cos(pa), -sin(pa))
	var pn := pv.orthogonal()
	var pivot := c - Vector2(0, 1).rotated(rot) * 12.0
	var tip := pivot + pv * 2.0 + jit
	var tail := pivot + pv * PIN_LEN + jit
	if _snap > 0.0:
		tail += pn * 4.0 * sin(time * 90.0)
	var wire := C["P07"] if lock.state == "play" else C["P04"]
	view.draw_line(tip + Vector2(1, 1), tail + Vector2(1, 1), Color(0, 0, 0, 0.5), 3.0)
	view.draw_line(tip, tail, C["P03"], 3.0)
	view.draw_line(tip, tail, wire, 1.0)
	var bend := tail + pn * 6.0 + pv * 2.0                               # 구부린 끝(손잡이 고리)
	view.draw_line(tail, bend, C["P03"], 3.0)
	view.draw_line(tail, bend, wire, 1.0)
	view.draw_line(bend, bend - pv * 14.0, C["P03"], 3.0)
	view.draw_line(bend, bend - pv * 14.0, wire, 1.0)
	_draw_info()


func _draw_body(c: Vector2, rot: float) -> void:
	var rim: Color
	var face: Color
	var dark: Color
	var hi: Color
	match skin:
		"dial":
			rim = C["P03"]; face = C["P05"]; dark = C["P02"]; hi = C["P07"]
		"pad":
			rim = C["P58"]; face = Color("B08A1C"); dark = C["P17"]; hi = Color("E8C25A")
		_:
			rim = C["P04"]; face = Color("B08A1C"); dark = C["P58"]; hi = Color("E8C25A")
	if skin == "pad":                                                    # 소형 자물쇠: 고리(쇠막대 두 겹)
		var sc := c + Vector2(0, -DISC_R + 10.0)
		view.draw_arc(sc, 48.0, PI, TAU, 32, C["P03"], 13.0)
		view.draw_arc(sc, 48.0, PI, TAU, 32, C["P06"], 9.0)
		view.draw_arc(sc, 46.0, PI * 1.15, PI * 1.6, 16, C["P08"], 2.0)
	view.draw_circle(c + Vector2(4, 5), DISC_R + 6.0, Color(0, 0, 0, 0.5))           # 그림자
	view.draw_circle(c, DISC_R + 6.0, C["P01"])                                        # 바깥 테
	view.draw_circle(c, DISC_R + 5.0, rim)
	view.draw_arc(c, DISC_R + 3.0, PI * 1.05, PI * 1.7, 24, rim.lightened(0.35), 2.0)   # 테 빛(왼쪽 위)
	view.draw_arc(c, DISC_R + 3.0, PI * 0.05, PI * 0.7, 24, rim.darkened(0.4), 2.0)     # 테 그늘(오른쪽 아래)
	view.draw_circle(c, DISC_R, dark)
	view.draw_circle(c, DISC_R - 2.0, face)
	view.draw_arc(c, DISC_R - 5.0, PI * 1.1, PI * 1.6, 20, hi, 2.0)                    # 면 빛
	if skin == "dial":                                                   # 금고 다이얼 눈금(같이 돈다)
		for i in 40:
			var a := rot + TAU * i / 40.0
			var l := 10.0 if i % 5 == 0 else 5.0
			var u := Vector2(cos(a), sin(a))
			view.draw_line(c + u * (DISC_R - 4.0), c + u * (DISC_R - 4.0 - l), C["P08"] if i % 5 == 0 else C["P06"], 1.0)
	if skin == "door":                                                   # 문 실린더 나사 넷
		for i in 4:
			var a := PI * 0.25 + PI * 0.5 * i
			var sp := c + Vector2(cos(a), sin(a)) * (DISC_R - 13.0)
			view.draw_circle(sp, 5.0, C["P01"])
			view.draw_circle(sp, 4.0, C["P06"])
			view.draw_line(sp - Vector2(3, 0).rotated(a), sp + Vector2(3, 0).rotated(a), C["P03"], 1.0)
	var inner := DISC_R * 0.5                                            # 실린더(돌아가는 안쪽 원) — 하우징과의 틈
	view.draw_circle(c, inner + 4.0, C["P01"])
	view.draw_circle(c, inner + 2.0, dark)
	view.draw_circle(c, inner, face.lightened(0.1))
	view.draw_arc(c, inner - 3.0, PI * 1.1, PI * 1.6, 16, hi, 1.0)
	for i in 6:                                                          # 실린더 무늬(같이 돈다)
		var a := rot + TAU * i / 6.0 + PI / 6.0
		view.draw_circle(c + Vector2(cos(a), sin(a)) * (inner - 8.0), 2.0, dark)
	var kv := Vector2(0, 1).rotated(rot)                                 # 열쇠 구멍(핀 텀블러 단면 — 위 넓고 아래 좁다)
	var kp := kv.orthogonal()
	var key := PackedVector2Array([c - kv * 22.0 - kp * 5.0, c - kv * 22.0 + kp * 5.0, c - kv * 6.0 + kp * 5.0, c - kv * 2.0 + kp * 2.5,
		c + kv * 20.0 + kp * 2.5, c + kv * 20.0 - kp * 2.5, c - kv * 2.0 - kp * 2.5, c - kv * 6.0 - kp * 5.0])
	view.draw_colored_polygon(key, C["P00"])
	view.draw_polyline(key + PackedVector2Array([key[0]]), C["P02"], 1.0)


func _draw_info() -> void:
	var y := 300.0
	view.draw_rect(Rect2(40, y - 6, 560, 46), Color(0.05, 0.05, 0.06, 0.85))
	view.draw_rect(Rect2(40, y - 6, 560, 1), C["P05"])
	var s := "등급: %s   머리핀: %d개   (A/D) 각도   (Space 누름) 돌리기   (F) 강제 개방 %d%%   (Esc) 나가기" % [
		Lockpick.NAMES[lock.g], maxi(0, lock.pins), Lockpick.force_chance(lock.g, lock.skill)]
	text(Vector2(320, y), s, f10, 10, C["P08"], HORIZONTAL_ALIGNMENT_CENTER)
	var hp := clampf(lock.pin_hp / 100.0, 0.0, 1.0)                     # 핀 내구 막대
	view.draw_rect(Rect2(250, y + 16, 140, 5), C["P02"])
	view.draw_rect(Rect2(250, y + 16, 140 * hp, 5), C["P54"] if hp < 0.35 else C["P08"])
	text(Vector2(244, y + 13), "핀", f8, 8, C["P06"], HORIZONTAL_ALIGNMENT_RIGHT)
	if _msg_t > 0.0 and _msg != "":
		text(Vector2(320, 34), _msg, f12, 12, C["P09"], HORIZONTAL_ALIGNMENT_CENTER)
