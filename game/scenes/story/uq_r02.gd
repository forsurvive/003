## 영등포 · 여의도(R02) 비표시 퀘스트 진행기(단계 1-12h, SD-05 §3.4 · 계획 `_plans/1-12h_UQ-07-08-09-10-70_plan.md`).
##   UQ-07 「견습생의 첫 납땜」 — 원고 script/act1/UQ-07.txt(엿듣기 · 광장 아이 · 쪽지) · 공하경 · 마영식 갈래는 MQ-103.txt 장면 안.
##     로봇 자리 한 값 UQ07_TOY(P3) — J-06 소품 · 글 · 공하경 바크 · 광장 아이 줄이 모두 이 값을 읽는다.
## 사실은 변수 한 곳(P1) — 변수 뜻은 원고 머리 주석. 시간 판정(로봇이 아이 손에 감)은 06:00 하루 판정에서만(P6).
## 비표시(SD-05 §2.6): 알림 없음 · 단계 로그(메모) · XP만.
class_name UqR02
extends Node

const KONG := "N-R02-017"                  ## 공하경
const HEAR_R := 3.0                        ## 공하경 혼잣말이 들리는 거리(칸)
const JH_MIN := -19                        ## JH 중립 이상(원문 발동 조건)
const KID := "N-JM-K1"                     ## 광장 아이
const BOT_GAP := 1.2                       ## 아이 뒤 이 칸쯤에서 따라온다(깡통 상자 · 배송 1호)
const NOTE_WALK_S := 6.0                   ## 쪽지: 배송 1호가 주인공 발치까지 굴러오는 시간 한도(막히면 그 자리에서 — 미끄러짐 금지)
const REMAKE_DAYS := 3                     ## ③ 로봇을 잃으면 공하경이 새로 만드는 데 걸리는 날

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _tube_n := 0                           ## 용기 창이 열리기 전 진공관 수(마영식 부품 상자 절도 판정)
var _note_pending := false
var _bot: Actor = null                     ## 아이 뒤를 따르는 배우(UQ07_TOY 2면 배송 1호 · 아니면 끈 달린 깡통 상자) — 맵 인물이 아니라 공격 대상이 아니다
var _bot_kind := ""
var _bot_path := PackedVector2Array()
var _bot_rp := 0.0
var _note_walk := 0.0                      ## > 0: 배송 1호가 주인공에게 굴러가는 중(남은 초)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.day_tick.connect(_on_day)
	host.map_entered.connect(_on_map)
	host.box_closed.connect(_on_box_closed)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v(k, n)


func _log(s: String) -> void:
	if log_on:
		print("[R02 비표시] " + s)


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func _mid() -> String:
	return host.map.id if host.map != null else ""


func _idle() -> bool:
	return not (host.busy or host.box.active or host.ev.busy() or host.container != null or host.combat.in_combat())


func _process(dt: float) -> void:
	_bot_frame(dt)
	_t += dt
	if _t < 1.0:
		return
	_t = 0.0
	if host.container == null:
		_tube_n = st.count_of("M-014")
	_hear_tick()
	_bot_tick()
	_note_tick()


# ---------------------------------------------------------------- UQ-07 견습생의 첫 납땜
## 엿듣기: J-06 둘째 입장부터(해독 · 고백 방문과 겹치지 않게, 재미 검수 R1) · 공하경 3칸 안 · JH 중립 이상
func _hear_tick() -> void:
	if _mid() != "J-06" or v("UQ07_HEARD") != 0 or v("UQ07_VISIT") < 2 or st.is_dead(KONG) or v("AFF_JH") < JH_MIN or not _idle():
		return
	for n in host.npcs:
		if str(n["id"]) != KONG or not is_instance_valid(n["actor"]) or not n["actor"].visible:
			continue
		if n["actor"].loco.logical.distance_to(host.player.loco.logical) <= HEAR_R * 32.0:
			_log("공하경 혼잣말 — 진공관 셋")
			host.play_scene("UQ07_HEAR")
		return


## 쪽지: 로봇이 아이 손에 간 다음 날부터 낮 광장에 들어설 때 한 번 — 아이가 고친 사람을 알 때만(③을 공하경에게 건넨 판은 '하경 언니가 고쳤다')
func _note_tick() -> void:
	if not _note_pending or _mid() != "J-03":
		_note_pending = false
		return
	if not _idle():
		return
	_note_pending = false
	var h := int(st.vars.get_v("GAME_HOUR"))
	if v("UQ07_TOY") != 2 or v("UQ07_NOTE") != 0 or h < 8 or h >= 18:
		return
	if day() < v("UQ07_KDAY") + v("UQ07_ME"):                         # 손수 건넨 날은 그 자리에서 이미 봤다 — 다음 날부터
		return
	if (v("UQ07_RES") == 3 and v("UQ07_ME") == 0) or v("UQ07_RES") == 4:   # 공하경이 혼자 고친 판(③ 맡김 · 다시 만듦 · 직접 말함)
		return
	_log("배송 1호가 쪽지를 끌고 옴")
	if _bot != null and is_instance_valid(_bot) and _bot_kind == "toybot":
		_note_walk = NOTE_WALK_S                                           # 발치까지 굴러온 뒤 장면(_bot_frame)
	else:
		host.play_scene("UQ07_NOTE")


## 아이 뒤 배우: 낮 광장에 아이가 서 있으면 띄우고, 로봇 자리 값에 따라 그림을 바꾼다
func _kid_actor() -> Actor:
	for n in host.npcs:
		if str(n["id"]) == KID and is_instance_valid(n["actor"]) and n["actor"].visible:
			return n["actor"]
	return null


func _bot_tick() -> void:
	var kid := _kid_actor() if _mid() == "J-03" else null
	if kid == null:
		_bot_drop()
		return
	var kind := "toybot" if v("UQ07_TOY") == 2 else "canbox"
	if _bot != null and is_instance_valid(_bot) and _bot_kind == kind:
		return
	_bot_drop()
	_bot = Actor.new()
	_bot.setup("cr_%s_loco" % kind, kid.loco.logical + Vector2(-32.0 * BOT_GAP, 0), host.map)
	_bot.mode = "walk"
	host.map.add_actor(_bot)
	_bot._show()
	_bot_kind = kind
	_bot_path = PackedVector2Array()


func _bot_drop() -> void:
	if _bot != null and is_instance_valid(_bot) and host.map != null:
		host.map.remove_actor(_bot)
		_bot.queue_free()
	_bot = null
	_bot_kind = ""
	_note_walk = 0.0


func _bot_frame(dt: float) -> void:
	if _bot == null or dt <= 0.0:
		return
	if not is_instance_valid(_bot):
		_bot = null
		return
	var to: Vector2
	var gap := BOT_GAP
	if _note_walk > 0.0:
		_note_walk -= dt
		to = host.player.loco.logical
		if _bot.loco.logical.distance_to(to) <= 1.3 * 32.0 or _note_walk <= 0.0:
			_note_walk = 0.0
			_bot.move(Vector2.ZERO, dt)
			host.play_scene("UQ07_NOTE")
			return
		gap = 1.0
	else:
		var kid := _kid_actor()
		if kid == null or host.ev.busy() or host.box.active:
			_bot.move(Vector2.ZERO, dt)
			return
		to = kid.loco.logical
	if _bot.loco.logical.distance_to(to) <= gap * 32.0:
		_bot.move(Vector2.ZERO, dt)
		_bot_path = PackedVector2Array()
		return
	_bot_rp -= dt
	if _bot_path.is_empty() or _bot_rp <= 0.0:
		_bot_rp = 0.8
		_bot_path = NpcRoutine.with_start(host.map, _bot.loco.logical, to)
	if _bot_path.is_empty():
		_bot.move(Vector2.ZERO, dt)                                        # 막히면 선다(미끄러짐 · 벽 비비기 금지)
		return
	_bot_path = NpcRoutine.walk_path(_bot, _bot_path, dt)


func _on_map(id: String) -> void:
	_bot_drop()                                                            # 맵이 바뀌면 옛 배우를 치운다(새 맵에선 다음 틱에 다시 띄움)
	_tube_n = st.count_of("M-014")
	if id == "J-06" and v("UQ07_VISIT") < 2:
		_sv("UQ07_VISIT", v("UQ07_VISIT") + 1)
	if id == "J-03":
		_note_pending = true


## 마영식 부품 상자(owner C-006)에서 진공관을 꺼내 갔다 — ①이 '훔친 판'(꼬리표 달린 관, 재미 검수 R3)
func _on_box_closed(b: Dictionary, _c: Dictionary) -> void:
	if _mid() != "J-06" or str(b.get("owner", "")) != "C-006" or v("UQ07_RES") != 0:
		return
	if st.count_of("M-014") > _tube_n:
		_sv("UQ07_STOLE", 1)
		_log("마영식 부품 상자에서 진공관을 훔침")


func _on_day(d: int) -> void:
	var changed := false
	if v("UQ07_TOY") == 1:
		_sv("UQ07_TOY", 2)                                               # 아침에 아이 머리맡에(공하경 '아침에 걔 일어나기 전에') — 아이는 공격 대상이 아니다(is_child)
		_sv("UQ07_KDAY", d)
		if st.quests.stage("UQ-07") < 100:
			st.quests.set_stage("UQ-07", 100)                             # 다시 만든 판(보상 없음)
		_log("배송 로봇이 아이 손에")
		changed = true
	# ② 실패 뒤 '선생님한테 얘기해 봤는데' → 그 아침 공하경이 직접 말한다(마영식 · 공하경 둘 다 살아 있을 때)
	if v("UQ07_SELF") == 1 and v("UQ07_RES") == 0:
		if st.is_dead("C-006") or st.is_dead(KONG):
			_sv("UQ07_SELF", 2)
		else:
			_sv("UQ07_SELF", 2)
			_sv("UQ07_RES", 4)
			_sv("UQ07_TOY", 1)
			_sv("UQ07_DISC", 1)
			st.call_fn("aff", ["JH", 1])
			st.call_fn("xp", [50])
			st.quests.set_stage("UQ-07", 100)
			_log("공하경이 직접 마영식에게 말함 — 관 셋")
			changed = true
	# ③ 로봇(M-431)을 아이에게 안 주고 잃음 → 사흘 뒤 공하경이 새로 만든다(P10 — 반쯤 된 상태로 굳지 않게)
	if v("UQ07_TOY") == 3 and st.count_of("M-431") == 0:
		if v("UQ07_LOST") == 0:
			_sv("UQ07_LOST", 1)
			_sv("UQ07_LOST_DAY", d)
			_log("배송 로봇을 잃음 — 공하경이 다시 만든다")
		elif d >= v("UQ07_LOST_DAY") + REMAKE_DAYS:
			_sv("UQ07_TOY", 1)
			changed = true
	if changed:
		host.refresh_npcs()
