## 여의도 금탑 던전 DG-KT 1-D5a 진행기(SD-09a L-R02-05 · SD-05 UQ-68 · SD-07b N-R02-030 · 1-D 계획 §11.3~11.7).
##   원고: script/act1/KT.txt. 맵: KT-01 로비 · KT-02 지하 수족관(월드 문 둘 — 회전문 · 둔치 비상구).
## 동사: 승강로(꺼진 승강기 4번 — 로비와 수족관을 잇는 수직 길) · 관람객 길(유리 터널)과 직원 길(수조 위 철망 발판) · 발전기 연료 한 통의 쓰임(셋 중 하나).
## 어하은(60층)은 1-D5a에서 목소리만(P3): 로비에 들어서면 아직 통화한 적 없을 때 벨이 세 번 울리고 그친다(받으면 첫 통화).
## 회전문 꾀기(재미 검수 엉뚱한 짓): 돌리면 삐걱(소리) → 개미 정찰이 온다 → 회전문 칸 곁에서 한 번 더 돌리면 갇힌다 → 10초 뒤 유리를 깨고 나옴(깨짐 판) · 그동안 남은 정찰은 냄새 길을 잃고 헤맨다.
## 시간선(P4 · P6): 연료는 고른 날을 적는다(소문은 하루 늦게). 사실은 KT_* 한 곳(P1) — 맵 그림 · 물 높이 · 적은 들어설 때 그 사실로 다시 선다.
class_name Kt
extends Node

const LOBBY := "KT-01"
const AQUA := "KT-02"
const HAEUN := "N-R02-030"
const RINGS := 3                                ## 벨 횟수(받지 않으면 그친다 — 다음에 들어서면 다시)
const RING_GAP := 2.5
const RING_NEAR := 14.0                         ## 벨은 인터폰에서 이만큼(칸) 안에 들어서야 울리기 시작한다(정문에서 20칸 — 뛰어도 못 받던 것, 재미 검수)
const INTERCOM := Vector2i(22, 1)
const DOOR_AT := Vector2i(15, 20)               ## 회전문 칸 앞(갇히는 자리)
const REVOLVE_AT := Vector2i(14, 19)            ## 회전문 소품
const TRAP_S := 10.0                            ## 갇힌 일개미가 유리를 깨고 나오기까지
const LURE_R := 40.0                            ## 삐걱 소리가 닿는 거리(칸) — 높은 로비 천장에 울려 로비 전체(재미 검수: 14칸은 정찰 길에 거의 안 닿았다)
const SPIN_S := 4.0                             ## 한 번 밀면 날개가 이만큼 더 돈다 — 그사이 문 칸에 들어선 일개미가 갇힌다(나는 물러나 있어도 된다)
const FUEL := ["화염방사기 연료", 30]           ## 발전기 연료 통을 들고 나가면(휘발유 — 화염방사기 연료로 쓴다)

var host: InteriorHost
var st: StoryState
var log_on := false
var _ring_n := 0
var _ring_t := 0.0
var _ring_armed := false
var _spin_t := 0.0
var _trap_t := 0.0
var _trapped: Dictionary = {}                    ## 갇힌 개미의 자리 · 행(깨고 나올 때 다시 세운다)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["kt"] = _cmd
	host.map_entered.connect(_on_map)


func v(k: String) -> int:
	return int(st.vars.get_v("KT_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("KT_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[여의도 금탑] " + s)


func _mid() -> String:
	return host.map.id if host.map != null else ""


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func _tc(c: Vector2i) -> Vector2:
	return Vector2(c) * 32.0 + Vector2(16, 16)


# ---------------------------------------------------------------- 맵에 들어섰다: 로비 벨
func _on_map(id: String) -> void:
	_ring_n = 0
	_ring_armed = false
	_spin_t = 0.0
	_trapped = {}
	_trap_t = 0.0
	if v("REVOLVE") == 1:                                                 # 갇힌 개미를 두고 떠났다: 그사이 유리를 깨고 나갔다(반쯤 된 상태 없음, P10)
		_sv("REVOLVE", 2)
	if id == LOBBY and v("CALL") == 0 and not st.is_dead(HAEUN) and int(st.vars.get_v("V_ACT")) >= 1:
		_ring_armed = true                                                # 회전문 삐걱을 들은 어하은이 먼저 건다 — 인터폰 가까이 오면 울린다


func _process(dt: float) -> void:
	if host == null or host.map == null:
		return
	if _ring_armed and _mid() == LOBBY and host.player != null:
		if host.player.loco.logical.distance_to(_tc(INTERCOM)) / 32.0 <= RING_NEAR:
			_ring_armed = false
			_ring_n = RINGS
			_ring_t = 0.2
	if _spin_t > 0.0 and _mid() == LOBBY:                                  # 날개가 도는 동안 문 칸에 들어선 일개미는 갇힌다
		_spin_t -= dt
		var door := _tc(DOOR_AT)
		for e in host.combat.enemies:
			if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == "CR-080" and e.loco.logical.distance_to(door) <= 1.6 * 32.0:
				_spin_t = 0.0
				_trap(e)
				break
	if _ring_n > 0 and _mid() == LOBBY:
		_ring_t -= dt
		if _ring_t <= 0.0:
			if v("CALL") >= 1:
				_ring_n = 0
			else:
				_ring_n -= 1
				_ring_t = RING_GAP
				host.map.set_prop_state(INTERCOM, "lit" if _ring_n % 2 == 0 else "")
				host.hint("따르릉 — 북쪽 승강기 홀의 놋쇠 인터폰이 운다." if _ring_n > 0 else "벨이 그쳤다.", 1.8)
				if _ring_n == 0:
					host.map.set_prop_state(INTERCOM, "")
	if not _trapped.is_empty() and _mid() == LOBBY:
		_trap_t -= dt
		if _trap_t <= 0.0:
			_break_out()


# ---------------------------------------------------------------- 원고 명령(@cmd kt …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"go":
			if host.is_inside_tree():
				host.go.call_deferred(str(a[1]), str(a[2]))
		"power":
			_power(int(a[1]))
		"spin":
			_spin()
		"tunnel":
			_tunnel()
		"jump":
			_jump(str(a[1]) == "dry")
	done.call()


## 발전기 연료 한 통: 1 배수(수족관이 마름 · 메기 새끼가 쓸려 나감) · 2 화물 승강기(딩 · 승강로로 개미) · 3 들고 나감
func _power(n: int) -> void:
	if v("POWER") != 0:
		return
	_sv("POWER", n)
	_sv("POWER_DAY", day())
	match n:
		1:
			for e in host.combat.enemies:                                    # 메기 새끼는 배수구로 쓸려 나간다(죽음이 아니라 떠남 — 처치 XP 없음)
				if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == "CR-130":
					e.visible = false
					e.set_meta("kt_gone", 1)
			host.combat.enemies = host.combat.enemies.filter(func(e): return not (is_instance_valid(e) and e.has_meta("kt_gone")))
			host.combat._rebuild_list()
			_log("배수 — 수족관이 마름")
			if host.is_inside_tree() and _mid() == AQUA:
				host.go.call_deferred(AQUA, "pump")                           # 물 높이 · 바닥 · 꺼진 칸을 새 사실로 다시 세운다
		2:
			host.hint("딩 — 머리 위 어딘가에서 화물 승강기 소리.", 3.0)
			_log("화물 승강기에 전기")
		3:
			st.call_fn("give", FUEL)
			_log("연료 통을 들고 나감")


## 회전문을 민다: 삐걱(소리) — 회전문 칸 곁의 일개미는 갇히고, 멀리 있는 일개미는 소리 쪽으로 온다
func _spin() -> void:
	if _mid() != LOBBY or v("REVOLVE") == 2:
		return
	host.hint("끼이이익 — 회전문이 돈다. 로비 천장까지 울린다. 날개가 한참 더 돈다.", 2.5)
	var door := _tc(DOOR_AT)
	if v("REVOLVE") == 0:
		_spin_t = SPIN_S
		host.map.set_prop_state(REVOLVE_AT, "turn")
	for e in host.combat.enemies:
		if not is_instance_valid(e) or e.cmb.dead or str(e.row.get("id", "")) != "CR-080":
			continue
		var d: float = e.loco.logical.distance_to(door) / 32.0
		if d <= 1.6 and v("REVOLVE") == 0:
			_spin_t = 0.0
			_trap(e)
			return
		if d <= LURE_R:
			e.hear("door", door)
			host.combat.colony.lure(e, door, 14.0)                           # 냄새 길을 벗어나 소리 쪽으로(14초 — 그 뒤 줄로 돌아간다)
	_log("회전문 삐걱")


func _trap(e: Enemy) -> void:
	_sv("REVOLVE", 1)
	_trapped = {"pos": e.loco.logical}
	_trap_t = TRAP_S
	host.combat.enemies.erase(e)
	e.queue_free()
	host.combat._rebuild_list()
	host.map.set_prop_state(REVOLVE_AT, "trapped")
	host.hint("회전문 칸에 일개미가 갇혔다. 유리를 긁는 소리 — 딱딱딱.", 3.0)
	for o in host.combat.enemies:                                         # 냄새 길이 끊겼다: 남은 정찰은 길을 잃고 헤맨다(갇힌 동안 · 20초)
		if is_instance_valid(o) and not o.cmb.dead and str(o.row.get("id", "")) == "CR-080":
			host.combat.colony.lose(o, 20.0)
	_log("일개미가 회전문에 갇힘")


func _break_out() -> void:
	var at: Vector2 = _trapped.get("pos", _tc(DOOR_AT))
	_trapped = {}
	_sv("REVOLVE", 2)
	host.map.set_prop_state(REVOLVE_AT, "broken")
	var e := host.combat.spawn("CR-080", at, host.map, st, {"dir": "N"})
	e.hear("impact", at)
	host.hint("쨍그랑 — 회전문 유리가 깨지고 일개미가 튀어나온다.", 3.0)
	_log("일개미가 회전문을 깨고 나옴")


## 승강로에 뛰어내렸다: 그 자리에서 넘어진다(피해 · 소리) — 물이면 칸 지붕 해치가 무게에 꺼져 물속 칸이 열린다 · 말랐으면 더 아프고 칸 안으로
func _jump(dry: bool) -> void:
	_sv("HATCH", 1)
	if host.combat.pc != null:
		host.combat.pc.last_by = "env"
		host.combat.pc.take({"hp": 15.0 if dry else 6.0}, host.player.loco.logical)
		host.combat.pc.hold("down", 1.2)
	_log("승강로에 뛰어내림(%s)" % ("마른 바닥" if dry else "물"))
	if host.is_inside_tree():
		host.go.call_deferred(AQUA, "shaft_bottom")
		_splash.call_deferred(not dry)


func _splash(wet: bool) -> void:
	if not wet or host.map == null or _mid() != AQUA:
		return
	var at := host.player.loco.logical
	for e in host.combat.enemies:                                         # 첨벙 — 물에 있는 것이 깬다
		if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == "CR-130":
			e.hear("impact", at)
			if e.loco.logical.distance_to(at) < 12.0 * 32.0:
				e.wake()


## 유리 터널을 깼다: 물살에 그 자리에서 넘어지고(미끄러지지 않는다 — 넘어짐 · 피해) 터널이 허리 물로 남는다(다시 세움)
func _tunnel() -> void:
	if v("TUNNEL") == 1:
		return
	_sv("TUNNEL", 1)
	if host.combat.pc != null:
		host.combat.pc.last_by = "env"
		host.combat.pc.take({"hp": 8.0}, host.player.loco.logical)
		host.combat.pc.hold("down", 1.2)
	_log("유리 터널 깨짐")
	if host.is_inside_tree() and _mid() == AQUA:
		host.go.call_deferred(AQUA, "tunnel_w")
