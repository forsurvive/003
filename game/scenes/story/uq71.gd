## 영등포(R02) 비표시 퀘스트 UQ-71 「원자력 버스」 진행기(단계 1-D1, SD-05 §3.17 · 3.16 표 · 훅 H-R02-11). 원고: script/act1/UQ-71.txt ·
##   MQ-103.txt MQ-103_BOK(상인회장에게 판매). 맵: DB-01 대방 지하차도(던전 DG-DB) · 월드 두 입구(L-R02-17 북 · 남).
## 노심의 행방은 UQ71_CORE 하나(P1): 0 버스 · 1 제자리 봉인 · 2 주인공 소지 · 3 팔림 · 4 분대가 끌어감 · 5 신길에서 터짐.
## 시간선(P4 · P6): 분대의 끌어내기 · 폭발은 06:00 하루 판정에서만 — 주인공이 지하차도 안이나 신길 빌라 둘레에 있으면 하루씩 미룬다.
## 분대장 배수관(N-R02-048)이 죽으면 분대가 흩어지고(SQ 9) 기한이 사라진다 — 노심은 그대로 남아 봉인 · 꺼내기가 열려 있다.
## 비표시(SD-05 §2.6): 알림 없음 · 메모 한 줄 · XP만.
class_name Uq71
extends Node

const QID := "UQ-71"
const MAP := "DB-01"
const LEADER := "N-R02-048"
const DUE_DAYS := 3                        ## 엿듣기: '사흘 안에'
const HEAR_R := 6.0                        ## 배수관 6칸 안 · 들키지 않았을 때 엿듣는다
const SINGIL := Vector2i(763, 1194)        ## 신길 언덕 빌라(L-R02-16) — 폭발 자리 · 30칸 안이면 미룬다
const SINGIL_R := 30
const XP := 100

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["uq71"] = _cmd
	host.day_tick.connect(_on_day)
	host.combat.enemy_killed.connect(_on_kill)
	if v("N") == 0:
		_sv("N", _crew(day()))


## 그날 낮 분대 인원(2~4 — 날마다 다르게, 같은 날은 같게: 저장 · 불러오기에 흔들리지 않는다)
static func _crew(d: int) -> int:
	return 2 + (d * 7919 + 13) % 3


func v(k: String) -> int:
	return int(st.vars.get_v("UQ71_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("UQ71_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[원자력 버스] " + s)


func _mid() -> String:
	return host.map.id if host.map != null else ""


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func stage() -> int:
	return st.quests.stage(QID)


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage(QID, n)
		_log("단계 %d" % n)


## 퀘스트가 열린다 — 분대가 일하고 있으면 그날부터 사흘(P2: 먼저 본 쪽이 무엇이든 같은 기한)
func _start(why: String) -> void:
	if stage() == 0:
		_up(10)
		_sv("DAY", day())
		_log("발동(%s)" % why)
	if v("DUE") == 0 and v("SQ") == 0 and v("CORE") == 0 and not st.is_dead(LEADER):
		_sv("DUE", v("DAY") + DUE_DAYS)


func _close(sol: int, why: String) -> void:
	if stage() >= 100:
		return
	if stage() == 0:
		_up(10)
	_sv("SOL", sol)
	_sv("REWARD", day())                                                 # 끝난 날(소문은 하루 늦게 — P7)
	_up(100)
	st.call_fn("xp", [XP])
	_log("닫힘 — " + why)


# ---------------------------------------------------------------- 매 0.5초: 엿듣기(들키지 않고 배수관 곁) · 배수관 사망 → 분대 흩어짐
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5 or host == null or host.map == null:
		return
	_t = 0.0
	if v("SQ") == 0 and st.is_dead(LEADER):
		_sv("SQ", 9)                                                     # 분대장이 쓰러지면 나머지는 흩어진다(UQ-10 비고: 대방 분대 습격도 사라진다)
		_sv("DUE", 0)
		_log("배수관 사망 — 분대 흩어짐")
		if _mid() == MAP and v("CORE") == 0:                            # 배수관 품의 협박문 초안(P2: 엿듣지 못했어도 분대가 노심을 노린 까닭을 안다)
			host.hint("배수관 품에서 구겨진 종이 — '역전 시장 상인회 귀하. 신길 빌라 옥상의 초록 불을 보거든 다음 달부터…' 쓰다 만 협박문이다.", 8.0)
			_start("협박문")
			_up(20)
	if v("QUICK") == 0 and int(st.vars.get_v("DG_DB")) >= 1 and v("CORE") == 0 and v("SQ") == 0 and v("DUE") > day() + 1:
		_sv("QUICK", 1)                                                  # 큰집게가 없어지면 분대가 물에 들어간다 — 기한이 다음 날로(던전 정리 ↔ 노심, F10)
		_sv("DUE", day() + 1)
		_log("큰집게 처치 — 분대 기한 당겨짐")
		if _mid() == MAP:
			host.hint("경사로 쪽이 술렁인다. '큰집게가 뻗었다! 내일 아침에 다 당긴다!'", 6.0)
	if _mid() != MAP or v("HEARD") == 1 or v("SQ") != 0 or v("CORE") != 0 or host.busy or host.box.active or host.ev.busy():
		return
	for e in host.combat.enemies:
		if is_instance_valid(e) and str(e.who) == LEADER and not e.cmb.dead:
			var alarmed: bool = e.brain.state in [AIBrain.S.COMBAT, AIBrain.S.SEARCH, AIBrain.S.SUSPICIOUS]
			if not alarmed and e.loco.logical.distance_to(host.player.loco.logical) <= HEAR_R * 32.0:
				host.play_scene("UQ71_HEAR")
			return


# ---------------------------------------------------------------- 06:00: 분대가 끌어내고, 다음 날 신길에서 터진다(주인공이 그 자리에 있으면 하루 미룸)
func _on_day(d: int) -> void:
	_sv("N", _crew(d))
	if v("CORE") == 0 and v("SQ") == 0 and v("DUE") > 0 and d >= v("DAY") + 1:
		_sv("SQP", 1)                                                   # 하루 지나면 버스가 경사로 쪽으로 기운다(그림 · 윈치 글)
	if v("CORE") == 0 and v("SQ") == 0 and v("DUE") > 0 and d >= v("DUE"):
		if st.is_dead(LEADER):
			return
		if _mid() == MAP:
			if host.combat.in_combat() or host.box.active:
				_sv("DUE", d + 1)                                       # 싸움 · 대화 중엔 미룬다(P5)
				_log("끌어내기 미룸(싸움 · 대화 중)")
				return
			_pull()
			host.play_scene("UQ71_PULL")                                # 숨어 있으면 눈앞에서 끌어낸다
			_clear_squad()
			return
		_pull()
		return
	if v("CORE") == 4 and d >= v("DUE"):
		if host.map is WorldMap and Vector2(host.map.tile_of(host.player.loco.logical)).distance_to(Vector2(SINGIL)) <= SINGIL_R:
			_sv("DUE", d + 1)
			_log("폭발 미룸(주인공이 신길 빌라 곁)")
			return
		_sv("CORE", 5)
		_sv("SQ", 9)
		if not st.is_dead(LEADER):
			st.kill(LEADER)
			st.book.died(LEADER, host.date_text)                          # 소식으로 안 죽음(수첩)
		_close(3, "신길 섬광")
		if host.outdoor():
			host.hint("북쪽 멀리, 신길 언덕 쪽 하늘이 초록으로 번쩍였다. 한참 뒤에 낮은 쿵 소리가 땅을 타고 온다.", 7.0)
		if host.map is WorldMap:
			host.combat.rad.setup(host.map, st)                         # 신길 빌라 Rad-1 지대(조건부 월드 지대)를 바로 켠다


# ---------------------------------------------------------------- 원고 명령(@cmd uq71 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"hear":
			_sv("HEARD", 1)
			_start("엿듣기")
			_up(20)
		"seen":
			_sv("SEEN", 1)
			_start("버스")
			if v("HEARD") == 1:
				_up(20)
		"memo":
			_start("운전기사 메모")
			if v("SQ") == 0 and v("SEEN") == 1:
				_up(20)                                                  # 사슬을 보고 메모를 읽으면 분대의 일을 짐작한다
			_up(30)
		"seal":
			_sv("CORE", 1)
			_sv("DUE", 0)
			_cool()
			st.call_fn("karma", [25])
			_close(1, "봉인")
		"take":
			_sv("CORE", 2)
			_sv("DUE", 0)
			_cool()
			st.call_fn("give", ["M-392", 1])
			_start("꺼냄")
			_up(40)
		"burn":
			Radiation.expose(st, 40.0, 0.0)                              # 덮개 틈의 숨 한 번(저항 없이 20라드)
		"sold":
			_sv("CORE", 3)
			st.call_fn("caps", [250])
			st.call_fn("aff", ["JH", 2])
			_close(2, "상인회에 팖")
	done.call()


func _pull() -> void:
	_sv("CORE", 4)
	_sv("SQ", 1)
	_sv("DUE", day() + 1)                                               # 다음 날 터진다
	_log("분대가 노심을 끌어감")


## 눈앞 끌어내기 뒤: 분대가 경사로로 사라지고 버스는 뜯긴 판 · 지대가 꺼진다
func _clear_squad() -> void:
	for e in host.combat.enemies.duplicate():
		if is_instance_valid(e) and not e.cmb.dead and (str(e.who) == LEADER or str(e.row.get("id", "")) in ["CR-420", "CR-423"]):
			host.combat.enemies.erase(e)
			e.queue_free()
	host.combat._rebuild_list()
	host.map.set_prop_state(Vector2i(23, 13), "torn")
	host.combat.rad.setup(host.map, st)


## 분대원을 쓰러뜨릴 때마다 사슬 당길 손이 줄어 하루 늦어진다
func _on_kill(id: String, _left: int) -> void:
	if _mid() == MAP and id in ["CR-420", "CR-423"] and v("CORE") == 0 and v("SQ") == 0 and v("DUE") > 0:
		_sv("DUE", mini(v("DUE") + 1, v("DAY") + DUE_DAYS + 3))         # 손이 줄어 늦어진다 — 다시 서는 일꾼으로 끝없이 미루지 못하게 상한 +3일
		_log("분대원 처치 — 기한 +1일")


## 노심이 잠들면 버스가 식는다: 버스 둘레 Z2 지대를 끄고 그림을 '빈 받침'으로
func _cool() -> void:
	if _mid() != MAP:
		return
	host.map.set_prop_state(Vector2i(23, 13), "cold")
	host.combat.rad.setup(host.map, st)
