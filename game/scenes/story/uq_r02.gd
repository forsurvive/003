## 영등포 · 여의도(R02) 비표시 퀘스트 진행기(단계 1-12h, SD-05 §3.4 · 계획 `_plans/1-12h_UQ-07-08-09-10-70_plan.md`).
##   UQ-07 「견습생의 첫 납땜」 — 원고 script/act1/UQ-07.txt(엿듣기 · 광장 아이 · 쪽지) · 공하경 · 마영식 갈래는 MQ-103.txt 장면 안.
##     로봇 자리 한 값 UQ07_TOY(P3) — J-06 소품 · 글 · 공하경 바크 · 광장 아이 줄이 모두 이 값을 읽는다.
##   UQ-10 「저울추」 — 원고 script/act1/UQ-10.txt · 월드 스팟 L-R02-12(r02.spots) · 2층 반장 방 K-38 · SQ-S13 A13_ 장면에서 @cmd chain.
##     쇠판 한 값 UQ10_PLATE · 반장 한 값 UQ10_BOSS · 습격 한 값 UQ10_RAID(P1 · P3). 대방 분대 소멸은 UQ71_SQ 9(UQ-71 진행기).
##   UQ-08 「철사의 돋보기」 — 원고 script/act1/UQ-08.txt(병원 2층 현미경 · 작업대 전표 · 조립대) · 철사 갈래는 SQ-S09.txt SQS09_WIRE 안.
##     렌즈 자리 한 값 UQ08_LENS · 철사 자리 한 값 UQ08_WIRE(P3). ② 효과(UQ08_SAFE)는 읽는 자리 셋: act1_paths 담 밖 목걸이 · FQ-SB-02 원격기 · 생포 장면.
##   UQ-09 「탁한 물」 — 원고 script/act1/UQ-09.txt(점검구 · 철창 · J-10 외곽 배수구) · 도민지 갈래는 JM_PEOPLE.txt JM_DO 안.
##     물 한 값 UQ09_CLEAN(마시기 interior_host · 값 mq101 trade_mult · 바크가 읽음) · 어미 한 값 UQ09_MOM · 알집 E1~E3. 천장 어미 세 페이즈(알 낙하 · 돌진 물기 · 배 터짐)는 이 진행기.
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
# UQ-10: 역전 시장 스팟(월드 칸) · 습격 거리 · 판정 날 수
const TAK := "N-R02-019"                   ## 탁우빈
const PYO := "N-R02-020"                   ## 표강윤
const YM1 := "N-YM-1"                      ## 국밥 장수
const MARKET := "L-R02-12"                 ## 시장 스팟(r02.spots 15×9) — 원점은 굽기가 정한 자리(place_geo _spots)를 읽는다
const MARKET_SZ := Vector2i(15, 9)
const MARKET_MID := Vector2i(7, 3)         ## 시장 한가운데(스팟 안 칸 — 실전 거리 판정의 중심)
const RAID_FROM := Vector2i(7, -6)         ## 습격 무리가 나타나는 자리(아치 바깥 북쪽 길 — 걸어 들어온다)
const THU := 3                             ## 목요일(Clock.weekday 0 월) — 대방 덤 수거 날
const RAID_R := 40.0                       ## 습격 날 이 칸 안이면 실전
const RAID_H := [8, 12]                    ## 습격 시각(그날 아침)
const HIDE_DAYS := 3                       ## 들킨 뒤 쇠판을 떼어 두는 날
const NSEEN_P := 30                        ## 밤 저울 — 위층 창으로 볼 확률(날 씨앗)
const PLATE_BACK := 3                      ## 떼어 간 쇠판 → 새 쇠판까지
const SWAP_BACK := 2                       ## 옮겨 붙인 쇠판 → 원상까지
# UQ-08: 검수 · 오작동 · 렌즈
const WIRE := "N-R02-038"                  ## 철사
const CHIEF := "C-049"                     ## 실장 구만호(검수하는 사람)
const MA_SHOP := "V09"                     ## 마영식 상점(세진 부품 랙)
const SCOPE_AT := Vector2i(5, 5)           ## HP-04 안과 수술 현미경(대물렌즈 M-432)
const INSPECT_GAP := 30                    ## 실장 검수 간격(날) — 원문 '30일마다'
const INSPECT_H := 9                       ## 검수 시각(칠판 '09:00')
const CATCH_P := 10                        ## 발각 확률(원문 10%) — 남이 본 열린 목걸이(HEAT)마다 +HEAT_P
const HEAT_P := 10
const BOOM_DAYS := 30                      ## ③(또는 받고 둠) 뒤 오작동까지
# UQ-09: 외곽 배수구
const MINJI := "N-R02-010"                 ## 도민지
const MOM_WHO := "N-JM-B1"                 ## 배수구 어미(who)
const REDIRTY_DAYS := 14                   ## ② 뒤 재오염(원문)
const REGROW_DAYS := 3                     ## 어미 없이 남은 알집에서 큰바퀴가 다시 붐
const DROP_EVERY := 5.0                    ## 천장 알 낙하 간격(초)
const DROP_WARN := 1.4                     ## 붉은 원 → 떨어짐
const DROP_N := 3                          ## 알 셋을 떨어뜨린 뒤 어미가 내려온다
const DROP_R := 9.0                        ## 이 칸 안에 서 있는 사람에게 알을 떨군다
const FLOOD_S := 6.0                       ## 밸브 → 허리 물까지(초) — 높은 턱으로(단말은 저수 바닥 한가운데 — 동서 턱 어느 쪽도 가깝지 않다)
const EGG_AT := [Vector2i(14, 5), Vector2i(21, 14), Vector2i(5, 4)]
const HIGH := [Rect2i(1, 2, 7, 5), Rect2i(31, 2, 8, 8), Rect2i(31, 13, 8, 4)]   ## J-10 높은 턱(물이 안 닿는 자리)

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
var _raid_on := false                      ## 이 진행기가 세운 습격 인카운터가 진행 중
var _market_o := Vector2i(-1, -1)
var _plate_n := 0                          ## 용기 창이 열리기 전 새 쇠판(M-435) 수 — 2층 쇠판 상자 절도 판정
var _water_n := -1                         ## VJ10 거래 창이 열리기 전 정수(I-059) 수(-1: 거래 창 밖)
var _mom: Enemy = null                     ## 이 맵의 배수구 어미
var _drop_t := 0.0
var _drops := 0
var _drop_pend: Array = []                 ## [[자리, 남은 초]]
var _burst := false
var _flood_t := -1.0                       ## > 0: 밸브를 연 뒤 물이 차오르는 중(남은 초)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.day_tick.connect(_on_day)
	host.map_entered.connect(_on_map)
	host.box_closed.connect(_on_box_closed)
	host.ev.handlers["uqr2"] = _cmd
	if host.enc_live != null:
		host.enc_live.ended.connect(_on_enc_ended)


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
	_mom_frame(dt)
	_t += dt
	if _t < 1.0:
		return
	_t = 0.0
	if host.container == null:
		_tube_n = st.count_of("M-014")
		_plate_n = st.count_of("M-435")
	_hear_tick()
	_bot_tick()
	_note_tick()
	_market_tick()
	_raid_clock()
	_inspect_tick()
	_trade_watch()
	_u9_ready()


# ---------------------------------------------------------------- UQ-07 견습생의 첫 납땜
## 엿듣기: J-06 둘째 입장부터(해독 · 고백 방문과 겹치지 않게, 재미 검수 R1) · 공하경 3칸 안 · JH 중립 이상
func _hear_tick() -> void:
	if _mid() != "J-06" or v("UQ07_HEARD") != 0 or v("UQ07_VISIT") < 2 or st.is_dead(KONG) or v("AFF_JH") < JH_MIN or not _idle():
		return
	if _hour() < 6 or _hour() >= 20:                                   # 공하경은 낮만 배전실(밤엔 상가 숙소 — N14)
		return
	if st.quests.stage("MQ-103") < 40 and v("K_CODE") == 0 and not st.is_dead("C-006"):
		return                                                          # 해독 · 고백 뒤에만(첫 대면 메뉴와 겹치지 않게 — 서사 대조 중6)
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
	if v("UQ07_ME") != 1:                                              # 그림 속 손목 기계 — 아이가 고친 사람을 직접 본 판(손수 건넴)만(A211)
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
	if id == "J-10":
		_u9_stage(20)
		_drops = 0
		_drop_t = 0.0
		_drop_pend.clear()


## 마영식 부품 상자(owner C-006)에서 진공관을 꺼내 갔다 — ①이 '훔친 판'(꼬리표 달린 관, 재미 검수 R3)
## 탁우빈 2층 쇠판 상자(owner N-R02-019)에서 새 쇠판을 꺼내 갔다 — 다음에 그가 말한다(UQ-10 재미 검수 ③c)
func _on_box_closed(b: Dictionary, _c: Dictionary) -> void:
	if _mid() == "K-38" and str(b.get("owner", "")) == TAK and st.count_of("M-435") > _plate_n:
		_sv("UQ10_BOXT", 1)
		_log("2층 쇠판 상자를 털음")
	if _mid() != "J-06" or str(b.get("owner", "")) != "C-006" or v("UQ07_RES") != 0:
		return
	if st.count_of("M-014") > _tube_n:
		_sv("UQ07_STOLE", 1)
		_log("마영식 부품 상자에서 진공관을 훔침")


## 손 · 용기 · 은닉처 어디든 가진 수(맡겨 둔 로봇은 잃은 게 아니다 — 물건 하나가 둘이 되지 않게, 서사 대조 중7) · 상점 진열(shop:)은 판 것이라 뺀다
func _owned_anywhere(id: String) -> int:
	var n := st.count_of(id)
	for k in st.boxes:
		if not str(k).begins_with("shop:"):
			n += int(st.boxes[k].get("items", {}).get(id, 0))
	return n


func _on_day(d: int) -> void:
	var changed := false
	if v("UQ07_TOY") == 1 and st.is_dead(KONG):
		_sv("UQ07_TOY", 5)                                               # 고치던 사람이 죽었다 — 로봇은 담요 위에 남는다(P3)
		changed = true
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
	if v("UQ07_TOY") == 3 and _owned_anywhere("M-431") == 0:
		if v("UQ07_LOST") == 0:
			_sv("UQ07_LOST", 1)
			_sv("UQ07_LOST_DAY", d)
			_log("배송 로봇을 잃음 — 공하경이 다시 만든다")
		elif d >= v("UQ07_LOST_DAY") + REMAKE_DAYS:
			_sv("UQ07_TOY", 1)
			changed = true
	if changed:
		host.refresh_npcs()
	_uq10_day(d)
	_uq08_day(d)
	_uq09_day(d)


func _roll(tag: String, pct: int) -> bool:
	return absi(hash("uqr2:%s:%s" % [tag, str(st.vars.get_v("P_REGNO"))])) % 100 < pct


func _hour() -> int:
	return int(st.vars.get_v("GAME_HOUR"))


func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"look_day":                                                      # 낮 저울: 탁우빈 눈앞 — 웅크리지 않으면 들킨다(문턱 판정엔 실패가 없다 — A226)
			_checked()
			var seen := _tak_here() and not host.combat.crouch
			_sv("UQ10_NOTICED", 1 if seen else 0)
			if seen:
				_sv("UQ10_HIDE_UNTIL", day() + HIDE_DAYS)
				_log("낮 저울 — 탁우빈이 눈치챔(사흘 쇠판 뗌)")
		"look_night":                                                    # 밤 저울: 판정 없음 · 그날 밤 한 번 위층 창 판정(날 씨앗)
			_checked()
			_sv("UQ10_NSAW", 1)
			if v("UQ10_NROLL") != day():
				_sv("UQ10_NROLL", day())
				if not st.is_dead(TAK) and _tak_upstairs() and _roll("nseen:%d" % day(), NSEEN_P):
					_sv("UQ10_NSEEN", 1)
					_sv("UQ10_HIDE_UNTIL", day() + HIDE_DAYS)
					_log("밤 저울 — 위층 창으로 봄")
		"ledger", "checked":
			_sv("UQ10_LEDGER", 1 if str(a[0]) == "ledger" else v("UQ10_LEDGER"))
			_checked()
		"lens":                                                          # UQ-08 렌즈를 뺐다(1 비틀어 뽑음 — 유리 소리에 2층 구울이 다가온다)
			if v("UQ08_MET") == 1 and st.quests.stage("UQ-08") < 20:
				st.quests.set_stage("UQ-08", 20)
			if _mid() == "HP-04":
				host.map.set_prop_state(SCOPE_AT, "taken")                     # 빈 대물렌즈 고리(다시 들어오면 맵 cond가 같은 그림)
			if a.size() > 1 and int(a[1]) == 1 and host.player != null:
				for e in host.combat.enemies:
					if is_instance_valid(e) and not e.cmb.dead:
						e.hear("glass", host.player.loco.logical)
				_log("렌즈를 비틀어 뽑음 — 유리 소리")
		"safe":                                                          # UQ-08 ②: 이 시각 하루 뒤 감긴 목걸이부터 · 첫 검수는 30일 뒤
			_sv("UQ08_SAFE_AT", Clock.abs_min(host.date_text))
			_sv("UQ08_INSPECT", day() + INSPECT_GAP)
			_sv("UQ08_CHECK_N", 0)
			_log("공구함 견본을 바꿈 — 첫 검수 %d일" % v("UQ08_INSPECT"))
		"go":                                                            # UQ-09 점검구 · 철창 · 사다리(장면에서 맵을 넘는다)
			host.enter(str(a[1]), str(a[2]))
		"hatch_pick":                                                    # 점검구 몰래 따기: 웅크렸으면 · 도민지가 없으면 열림, 서서 따면 도민지가 본다
			if host.combat.crouch or st.is_dead(MINJI):
				_sv("UQ09_HATCH", 2)
				host.hint("맹꽁이자물쇠가 딸깍 열린다. 뚜껑 밑으로 젖은 사다리.", 4.0)
				_log("점검구를 몰래 땀")
			else:
				st.call_fn("aff", ["JH", -1])
				host.hint("도민지: \"남의 물관에 손대지 마.\" (자물쇠를 손바닥으로 덮는다)", 4.0)
		"burn":                                                          # 알집을 태움 — 불 소리에 천장 어미가 깬다
			var k := int(a[1]) - 1
			if _mid() == "J-10":
				host.map.set_prop_state(EGG_AT[k], "burnt")
				_noise(Vector2(EGG_AT[k]) * 32.0 + Vector2(16, 16), "pistol")
			_log("알집 %d 태움" % (k + 1))
		"oilfire":                                                       # 엉뚱한 짓(재미 검수 T9): 물길 위 불 띠 · 하루 굴뚝 맛
			_sv("UQ09_SMOKE", day())
			for x in range(4, 30, 3):
				host.combat.ord.zones.append({"p": Vector2(x * 32 + 16, 10 * 32 + 16), "r": 1.6 * 32.0, "t": 6.0, "t0": 6.0, "kind": "fire", "team": "player", "w": {"dot": 6.0}})
			_noise(Vector2(19 * 32 + 16, 10 * 32 + 16), "heavy")
			if v("UQ09_E2") == 0:                                        # 물길까지 늘어진 막을 타고 건너편 알집까지 탄다(재미 검수 T9)
				_sv("UQ09_E2", 1)
				if _mid() == "J-10":
					host.map.set_prop_state(EGG_AT[1], "burnt")
			if _mom != null and is_instance_valid(_mom) and _mom.asleep:
				_mom_drop("열기에 천장의 어미가 떨어진다 — 쿵!")
			_log("물길에 등유 불")
		"pipe":                                                          # ② 흡입관을 상인회 관으로(두 번째면 더 깊은 관 — 어미는 아래로)
			_sv("UQ09_PIPE", 1)
			if v("UQ09_READY") == 0:
				_sv("UQ09_READY", 2)
			_sv("UQ09_PEND", 1)
			if v("UQ09_REDIRTY") == 1:
				_sv("UQ09_MOM", 3)
				for k in ["UQ09_E1", "UQ09_E2", "UQ09_E3"]:
					if v(k) == 0:
						_sv(k, 3)                                             # 어미가 더 깊이 내려가며 알집을 데려감(빈 막 — P10)
			_u9_stage(30)
			_log("흡입관을 상인회 관으로")
		"flood":
			_flood_t = FLOOD_S
			host.hint("물이 쏟아진다 — 높은 턱으로! (동쪽 사다리 밑 · 서쪽 턱 · 대피 칸)", 3.0)
		"u9reward":
			if v("UQ09_REWARD") == 0:
				_sv("UQ09_REWARD", 1)
				st.call_fn("xp", [90])
				if v("UQ09_CLEAN") == 1:
					st.call_fn("give", ["I-059", 5])
				else:
					_sv("UQ09_GIFT", 1)                                      # 맑아진 다음 아침 거 다섯 병(도민지가 맡아 둠 — 서사 대조 중4)
			if v("UQ09_MET") == 0:
				_sv("UQ09_MET", 1)
			if v("UQ09_RES") == 2 and v("UQ09_REDIRTY") == 0:
				_sv("UQ09_REDIRTY_DAY", day() + REDIRTY_DAYS)
		"xp8":
			if v("UQ08_XP") == 0:
				_sv("UQ08_XP", 1)
				st.call_fn("xp", [80])
		"xp":
			if v("UQ10_XP") == 0:
				_sv("UQ10_XP", 1)
				st.call_fn("xp", [70])
		"deal":                                                          # 대납: 수거는 목요일(UQ10_DUE) · 낸 데까지(PAY_UNTIL — 그 목요일까지 냈다)
			var due := next_thu(day() - 1)
			_sv("UQ10_DUE", due)
			_sv("UQ10_PAY_UNTIL", due - 7)
			_sv("UQ10_MISS", 0)
			_sv("UQ10_MSAID", 0)
		"pay":
			var weeks := int(a[1]) if a.size() > 1 else 1
			_sv("UQ10_PAY_UNTIL", maxi(v("UQ10_PAY_UNTIL"), v("UQ10_DUE") - 7) + 7 * weeks)
			_log("대납 %d주(%d일 목요일까지)" % [weeks, v("UQ10_PAY_UNTIL")])
		"msaid":
			_sv("UQ10_MSAID", v("UQ10_MISS"))
		"refund":                                                        # 분대가 흩어지면 대납 끝 — 아직 안 온 목요일 몫(선불)을 돌려준다
			_sv("UQ10_FREE", 1)
			var left := 0
			if v("UQ10_PAY_UNTIL") >= next_thu(day() - 1):
				left = (v("UQ10_PAY_UNTIL") - next_thu(day() - 1)) / 7 + 1
			if left > 0:
				_sv("UQ10_REFUND", left * 50)
				st.call_fn("caps", [left * 50])
			_log("대납 끝 — 돌려준 선불 %d캡" % v("UQ10_REFUND"))
	done.call()


func _checked() -> void:
	if v("UQ10_CHECKED") == 0:
		_sv("UQ10_CHECKED", 1)
	if st.quests.stage("UQ-10") < 20:
		st.quests.set_stage("UQ-10", 20)


## 요일(0 월 ~ 6 일) — 오늘(GAME_DAY)의 시계 글 요일에서 날 수만큼
func wd(d: int) -> int:
	return posmod(Clock.weekday(host.date_text) + d - day(), 7)


## after 다음 날부터 첫 목요일(GAME_DAY)
func next_thu(after: int) -> int:
	for k in range(1, 8):
		if wd(after + k) == THU:
			return after + k
	return after + 7


## 탁우빈이 반장 자리에 있다(낮 · 투표하러 가지 않음 · 쫓겨나지 않음)
func _tak_here() -> bool:
	var vt := v("SQ_S13_V_T")
	return not st.is_dead(TAK) and _hour() >= 6 and _hour() < 20 and vt != 2 and vt != 3 and v("UQ10_BOSS") == 0


## 탁우빈이 2층 방에 있다(밤 · 투표하러 가지 않음)
func _tak_upstairs() -> bool:
	var vt := v("SQ_S13_V_T")
	return (_hour() >= 20 or _hour() < 6) and vt != 2 and vt != 3


## 시장 스팟 원점(월드 칸) — 굽기가 정한 자리
func market_o() -> Vector2i:
	if _market_o.x < 0:
		var g = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/place_geo.json"))
		for sp in (g.get("_spots", []) if g is Dictionary else []):
			if str(sp.get("lid", "")) == MARKET:
				_market_o = Vector2i(int(sp["at"][0]), int(sp["at"][1]))
	return _market_o


func _in_market(margin := 2) -> bool:
	if not (host.map is WorldMap) or host.player == null:
		return false
	var o := market_o()
	var t: Vector2i = host.map.tile_of(host.player.loco.logical)
	return t.x >= o.x - margin and t.y >= o.y - margin and t.x < o.x + MARKET_SZ.x + margin and t.y < o.y + MARKET_SZ.y + margin


## 시장 칸 안: 수군댐(한 번) · 옮겨 붙인 다음 날 탁우빈이 먼저 따짐 · 습격 날 아침 실전
func _market_tick() -> void:
	if not (host.map is WorldMap) or host.player == null:
		return
	var h := _hour()
	var day_open := h >= 6 and h < 20
	if _in_market() and _idle() and day_open:
		if v("UQ10_HEARD") == 0 and _tak_here() and v("UQ10_RES") in [0, 6] and not (st.is_dead(YM1) and st.is_dead("N-YM-2")):
			_log("역전 시장 수군댐")
			host.play_scene("UQ10_HEAR")
			return
		if v("UQ10_PLATE") == 2 and v("UQ10_PSAID") == 0 and day() > v("UQ10_PLATE_DAY") and _tak_here() and v("UQ10_RES") in [0, 6]:
			_log("탁우빈이 먼저 따진다(옮겨 붙인 쇠판)")
			host.play_scene("UQ10_T")
			return
	var window := (h >= RAID_H[0] and h < RAID_H[1]) or (v("UQ10_EARLY") == 1 and h < 20)
	if v("UQ10_RES") == 2 and v("UQ10_RAID") == 0 and v("UQ10_RAID_DAY") > 0 and day() == v("UQ10_RAID_DAY") and window and not _mq106_on():
		if int(st.vars.get_v("UQ71_SQ")) == 9:
			_sv("UQ10_RAID", 9)
			return
		var t: Vector2i = host.map.tile_of(host.player.loco.logical)
		var mc := market_o() + MARKET_MID
		if Vector2(t).distance_to(Vector2(mc)) <= RAID_R and _idle() and host.enc_live != null:
			if host.enc_live.start({"re": "RE-012", "state": "S1", "src": "uq10", "at": market_o() + RAID_FROM, "force": true}):
				_raid_on = true
				_sv("UQ10_RAID", 5)
				host.hint("아치 너머가 소란하다 — 대방 분대다! " + ("표강윤이 상인들을 노점 뒤로 몰아넣는다. '엎드려!'" if not st.is_dead(PYO) and v("UQ10_BOSS") == 1 else "상인들이 노점 뒤로 숨는다."), 6.0)
				_log("대방 분대 습격 — 실전")


## 습격 시계(어느 맵이든): 전날 정찰을 쏘면 그날로 당겨지고 · 실전 없이 정오(당겨진 날은 20시)가 지나면 결과만
func _raid_clock() -> void:
	if v("UQ10_RES") != 2 or v("UQ10_RAID") != 0 or v("UQ10_RAID_DAY") <= 0:
		return
	if v("UQ10_EARLY") == 0 and day() == v("UQ10_RAID_DAY") - 1 and (st.is_dead("N-DB-S1") or st.is_dead("N-DB-S2")):
		_sv("UQ10_EARLY", 1)
		_sv("UQ10_RAID_DAY", day())                                     # 정찰이 안 돌아가면 본대가 더 빨리 온다(재미 검수 엉뚱한 짓)
		_log("정찰을 쏨 — 습격이 오늘로")
		if host.map is WorldMap:
			host.refresh_npcs()
		return
	var deadline := 20 if v("UQ10_EARLY") == 1 else RAID_H[1]
	if day() == v("UQ10_RAID_DAY") and _hour() >= deadline and not _raid_on and not _mq106_on():
		_raid_offscreen()


## 실전 없이 지나간 습격의 결과(표강윤이 반장이면 날 씨앗 반반 — 막음 / 털림 · 분대가 흩어졌으면 없음)
func _raid_offscreen() -> void:
	if int(st.vars.get_v("UQ71_SQ")) == 9:
		_sv("UQ10_RAID", 9)
	elif v("UQ10_BOSS") == 1 and not st.is_dead(PYO) and _roll("raid_off:%d" % v("UQ10_RAID_DAY"), 50):
		_sv("UQ10_RAID", 3)
	else:
		_sv("UQ10_RAID", 4)
		_sv("UQ10_ROB_DAY", v("UQ10_RAID_DAY"))
	_log("습격 결과(흔적) %d" % v("UQ10_RAID"))
	if host.map is WorldMap:
		host.refresh_npcs()


func _mq106_on() -> bool:
	var m6: int = st.quests.stage("MQ-106")
	return m6 > 0 and m6 < 100


func _on_enc_ended(re: String, how: String) -> void:
	if not _raid_on or re != "RE-012":
		return
	_raid_on = false
	if how == "cleared":
		_sv("UQ10_RAID", 1)
		_log("습격 막음")
	else:
		_sv("UQ10_RAID", 2)                                              # 놓침 · 달아남 — 노점 하나가 털린다
		_sv("UQ10_ROB_DAY", day())
		_log("습격 — 놓침(털림)")
	if host.map is WorldMap:
		host.refresh_npcs()


func _uq10_day(d: int) -> void:
	var sq_gone := int(st.vars.get_v("UQ71_SQ")) == 9
	# 공개(②) 다음 아침 상인 회의: 반장 교체 · 습격 날(씨앗)
	if v("UQ10_RES") == 2 and v("UQ10_BOSS") == 0 and d > v("UQ10_PUB_DAY"):
		_sv("UQ10_BOSS", 1 if not st.is_dead(PYO) else 2)
		if sq_gone:
			_sv("UQ10_RAID", 9)
		else:
			_sv("UQ10_RAID_DAY", next_thu(d))                            # 덤이 끊긴 뒤 첫 목요일(수거 날 — 달력 · 장부 · 분필이 가리킨다)
		_log("상인 회의 — 반장 %s · 습격 날 %d" % ["표강윤" if v("UQ10_BOSS") == 1 else "돌아가며", v("UQ10_RAID_DAY")])
	# MQ-106(버티버드 — 주인공 곁 공터, 역전 시장 앞 로터리일 수 있다) 동안엔 습격을 그날로 미룬다(P4 — 큰 사건은 하나씩)
	if v("UQ10_RES") == 2 and v("UQ10_RAID") == 0 and v("UQ10_RAID_DAY") > 0 and d > v("UQ10_RAID_DAY") and _mq106_on():
		_sv("UQ10_RAID_DAY", d)
	# 습격 날이 지났는데 실전이 없었으면 결과만(표강윤 반장이면 씨앗 반반 — 막음 / 털림)
	if v("UQ10_RES") == 2 and v("UQ10_RAID") in [0, 5] and v("UQ10_RAID_DAY") > 0 and d > v("UQ10_RAID_DAY"):
		if v("UQ10_RAID") == 5:
			_sv("UQ10_RAID", 2)                                          # 실전 중 끊김(불러오기 · 생포) — 털림
			_sv("UQ10_ROB_DAY", v("UQ10_RAID_DAY"))
		else:
			_raid_offscreen()
		_raid_on = false
	# ③ 대납: 수거 목요일이 지났는데(금요일 아침) 그 목요일까지 못 냈으면 노점 하나 털림 · 세 번이면 깨짐(다시 쇠판)
	if v("UQ10_RES") == 3 and not sq_gone and v("UQ10_FREE") == 0 and not st.is_dead(TAK) and v("UQ10_DUE") > 0 and d > v("UQ10_DUE"):
		if v("UQ10_PAY_UNTIL") < v("UQ10_DUE"):
			_sv("UQ10_MISS", v("UQ10_MISS") + 1)
			_sv("UQ10_ROB_DAY", d)
			_log("대납 못 냄 %d번째 — 노점 털림" % v("UQ10_MISS"))
		_sv("UQ10_DUE", v("UQ10_DUE") + 7)
		if v("UQ10_MISS") >= 3:
			_sv("UQ10_RES", 6)
			_sv("UQ10_PLATE", 0)
			_sv("UQ10_HIDE_UNTIL", 0)
			_log("담판 깨짐 — 탁우빈이 다시 쇠판")
	# 쇠판 자리 되돌림
	if v("UQ10_PLATE") == 1 and d >= v("UQ10_PLATE_DAY") + PLATE_BACK and v("UQ10_RES") in [0, 4, 6]:
		_sv("UQ10_PLATE", 0)
		_sv("UQ10_NSAW", 0)
	if v("UQ10_PLATE") == 2 and d >= v("UQ10_PLATE_DAY") + SWAP_BACK and v("UQ10_RES") in [0, 4, 6]:
		_sv("UQ10_PLATE", 0)
		_sv("UQ10_NSAW", 0)
	# 탁우빈이 결판 전에 죽으면 소멸(90)
	var s10: int = st.quests.stage("UQ-10")
	if st.is_dead(TAK) and s10 > 0 and s10 < 100:
		st.quests.set_stage("UQ-10", 90)
	if host.map is WorldMap:
		host.refresh_npcs()


# ---------------------------------------------------------------- UQ-08 철사의 돋보기
func _uq08_day(d: int) -> void:
	var gone := st.is_dead(WIRE) or v("SB_RAID") != 0 or v("UQ08_WIRE") != 0
	# 렌즈를 잃음(팔기 · 버리기 · 털림 — 어디든 가진 수 0) → 마영식 랙으로 흘러간다(P10 — 다시 살 수 있다)
	if v("UQ08_LENS") == 1 and _owned_anywhere("M-432") == 0:
		_sv("UQ08_LENS", 3)
		for k in st.boxes:                                               # 상점에 팔았으면 그 진열에서 빠져 마영식 랙으로(물건은 한 곳 — P3)
			if str(k).begins_with("shop:") and st.boxes[k].get("items", {}).has("M-432"):
				st.boxes[k]["items"].erase("M-432")
				if str(k) == "shop:" + MA_SHOP:
					_sv("UQ08_MA_SOLD", 1)                               # 마영식에게 직접 판 판 — '네가 팔고 간 렌즈'(서사 대조 중7)
		_log("세진 렌즈를 잃음 — 마영식 랙으로")
	# ③ 또는 받고 둠: 30일 뒤 마당에서 오작동(389번) — 철사가 아직 그 눈으로 감을 때만
	if v("UQ08_BOOM") == 0 and v("UQ08_MET") == 1 and v("UQ08_RES") in [0, 3] and not gone:
		var base := v("UQ08_DAY") if v("UQ08_RES") == 3 else v("UQ08_MET_DAY")
		if d >= base + BOOM_DAYS:
			_sv("UQ08_BOOM", 1)
			_sv("UQ08_BOOM_DAY", d)
			_log("본소 마당 목걸이 오작동(389번)")
			if _mid() == "X-SB" or _mid().begins_with("H-0"):
				host.hint("담 너머 마당에서 퍽 — 짧은 소리. 누가 소리를 지르고, 곧 조용해진다.", 5.0)
	# 철사 · 실장이 죽거나 습격 — 검수 예고(칠판 · 철사 · 견본)도 닫는다(서사 대조 중2 — 값 한 곳)
	if v("UQ08_INSPECT") > 0 and (st.is_dead(WIRE) or st.is_dead(CHIEF) or v("SB_RAID") != 0):
		_sv("UQ08_INSPECT", 0)
	# 철사가 죽거나 본소 습격 — 결말 전이면 소멸(4.2b 38)
	var s8: int = st.quests.stage("UQ-08")
	if (st.is_dead(WIRE) or v("SB_RAID") != 0) and s8 > 0 and s8 < 100:
		st.quests.set_stage("UQ-08", 90)


## 실장 검수(②만): 그 날 09:00 — 작업실에 있으면 눈앞에서 견본을 연다(재미 검수 '엉뚱한 짓'). 발각이면 철사가 사라지는 건 주인공이 나간 뒤(P4)
func _inspect_tick() -> void:
	if v("UQ08_WIRE_PEND") == 1 and _mid() != "H-05":
		_sv("UQ08_WIRE_PEND", 0)
		_sv("UQ08_WIRE", 1)                                              # 문을 나선 뒤 — 빈 의자
		return
	var due := v("UQ08_INSPECT")
	if v("UQ08_SAFE") != 1 or v("UQ08_WIRE") != 0 or v("UQ08_WIRE_PEND") != 0 or due <= 0:
		return
	if day() < due or (day() == due and _hour() < INSPECT_H):
		return
	if st.is_dead(WIRE) or v("SB_RAID") != 0 or st.is_dead(CHIEF):
		_sv("UQ08_INSPECT", 0)                                           # 철사 · 실장이 없으면 판정 멈춤(만든 목걸이는 남는다)
		return
	var n := v("UQ08_CHECK_N") + 1
	var here := _mid() == "H-05"
	_sv("UQ08_CHECK_N", n)
	_sv("UQ08_INSPECT", due + INSPECT_GAP)
	var p := mini(100, CATCH_P + HEAT_P * v("UQ08_HEAT"))
	if v("UQ08_REVERT") == due or not _roll("u8chk:%d" % n, p):
		_log("검수 %d회 — 통과(%s)" % [n, "견본 되돌림" if v("UQ08_REVERT") == due else "%d%%" % p])
		if here:
			host.hint("문 밖에서 구만호 목소리 — '철사, 견본.' 철사가 꼬리표 달린 목걸이를 들고 나갔다 온다. 문 너머로 '…곧네.'", 6.0)
		return
	_sv("UQ08_WIRE_AT", Clock.abs_min(host.date_text))
	_sv("UQ08_WIRE_DAY", day())
	st.call_fn("aff", ["SB", -8])
	_log("검수 %d회 — 발각(%d%%) · 철사 실종" % [n, p])
	if here:
		_sv("UQ08_WIRE_PEND", 1)
		host.hint("문 밖에서 구만호 목소리 — '철사, 견본.' 철사가 나갔다가 한참 만에 돌아온다. 얼굴이 하얗다. 문 너머에서 '…이따 나 좀 보지.' 철사가 인두를 내려놓는다.", 7.0)
	else:
		_sv("UQ08_WIRE", 1)
		if _mid() == "X-SB" or _mid().begins_with("H-0"):
			host.refresh_npcs()


# ---------------------------------------------------------------- UQ-09 탁한 물
## 정수를 샀다: VJ10 거래 창이 열린 동안 I-059가 늘었으면(노점 상자 루팅은 거래 창이 아니다)
func _trade_watch() -> void:
	var c = host.container
	if c is TradeScreen and str(c.vid) == "VJ10":
		if _water_n < 0:
			_water_n = st.count_of("I-059")
		elif st.count_of("I-059") > _water_n and v("UQ09_BOUGHT") == 0:
			_sv("UQ09_BOUGHT", 1)
			_log("도민지 정수를 삼")
	elif c == null:
		_water_n = -1


func _u9_stage(n: int) -> void:
	var s9: int = st.quests.stage("UQ-09")
	if s9 < n and s9 < 100 and v("UQ09_MET") == 1:
		st.quests.set_stage("UQ-09", n)


## 일을 끝냈나(어미 처치/익사 + 알집 셋) — 도민지에게 말할 일 1 · 물은 다음 06:00
func _u9_ready() -> void:
	if v("UQ09_READY") == 1 or v("UQ09_RES") == 1:
		return
	if v("UQ09_MOM") in [1, 2] and v("UQ09_E1") != 0 and v("UQ09_E2") != 0 and v("UQ09_E3") != 0:   # ② 말할 일(관)이 남아 있어도 ①로 올라간다(재미 검수 ②)
		_sv("UQ09_READY", 1)
		_sv("UQ09_PEND", 1)
		_u9_stage(30)
		_log("배수구 정리 — 도민지에게 말할 일")


func _noise(at: Vector2, kind: String) -> void:
	for e in host.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead:
			e.hear(kind, at)


func _in_high(t: Vector2i) -> bool:
	for r in HIGH:
		if r.has_point(t):
			return true
	return false


## J-10 천장 어미: ① 천장에서 알 낙하(붉은 원) ② 내려와 돌진 물기 · 15초 부화 ③ HP 30% 배가 터져 잔바퀴 떼 셋 · 밸브 물
func _mom_frame(dt: float) -> void:
	if _mid() != "J-10" or host.player == null:
		_mom = null
		_flood_t = -1.0
		return
	if _flood_t > 0.0:
		var was := _flood_t
		_flood_t -= dt
		if int(was) != int(_flood_t) and int(_flood_t) in [4, 1]:
			host.hint("물이 %s까지 찬다!" % ("무릎" if int(_flood_t) == 4 else "허리"), 1.5)
		if _flood_t <= 0.0:
			_flood_t = -1.0
			_flood_done()
		return
	if _mom == null or not is_instance_valid(_mom):
		_mom = null
		for e in host.combat.enemies:
			if is_instance_valid(e) and str(e.who) == MOM_WHO:
				_mom = e
				_drops = 0
				_burst = false
		if _mom == null:
			return
	if _mom.cmb.dead:
		if v("UQ09_MOM") == 0:
			_sv("UQ09_MOM", 1)
			_sv("UQ09_MOM_DAY", day())
			st.call_fn("give", ["M-437", 1])
			host.hint("어미 배 밑에서 손바닥 둘만 한 알집 하나를 떼어 냈다.", 4.0)
			_log("배수구 어미 처치")
		_mom = null
		return
	for pd in _drop_pend.duplicate():                                    # 떨어진 알: 서 있으면 맞고, 아니면 큰바퀴가 깬다
		pd[1] = float(pd[1]) - dt
		if float(pd[1]) <= 0.0:
			_drop_pend.erase(pd)
			var at: Vector2 = pd[0]
			if host.player.loco.logical.distance_to(at) <= 0.9 * 32.0:
				host.combat.damage(6.0)
				host.hint("알이 머리 위에서 터진다!", 1.5)
			else:
				var r = host.combat.spawn("CR-002", at, host.map, null, {"morale": false})
				r.set_meta("mother", _mom.get_instance_id())
				r.hear("pistol", host.player.loco.logical)
	if _mom.asleep:                                                     # ① 천장: 서 있는 사람에게 알을 떨군다(웅크리면 조용 — 밑을 지나간다)
		var near: bool = host.player.loco.logical.distance_to(_mom.loco.logical) <= DROP_R * 32.0 and not host.combat.crouch
		if not near:
			return
		_drop_t -= dt
		if _drop_t > 0.0:
			return
		_drop_t = DROP_EVERY
		if _drops >= DROP_N:
			_mom_drop("천장에서 어미가 떨어진다 — 쿵!")
			return
		_drops += 1
		var at2: Vector2 = host.player.loco.logical + Vector2(randf_range(-20, 20), randf_range(-12, 12))
		host.combat.ord.warn(at2, 0.9 * 32.0, DROP_WARN)
		_drop_pend.append([at2, DROP_WARN])
		if _drops == 1:
			host.hint("천장에서 뭔가 딸깍거린다 — 붉은 자리를 피해!", 2.5)
		return
	if not _burst and _mom.cmb.hp <= _mom.cmb.max_hp * 0.3:              # ③ 배 알집이 터진다
		_burst = true
		for k in 3:
			var p := _mom.loco.logical + Vector2(cos(k * 2.1) * 28.0, sin(k * 2.1) * 18.0)
			if host.map.is_solid(host.map.tile_of(p)):
				p = _mom.loco.logical
			host.combat.spawn("CR-001", p, host.map, null, {"morale": false})
		host.hint("어미의 배 알집이 터진다 — 잔바퀴 떼!", 2.5)


func _mom_drop(msg: String) -> void:
	if _mom == null or not is_instance_valid(_mom):
		return
	_mom.wake()
	_mom.hear("pistol", host.player.loco.logical)
	host.hint(msg, 2.5)


## 밸브 물이 다 찼다: 높은 턱 밖이면 휩쓸림 · 어미 · 바닥 알집 둘은 익사(천장 관 밑 알집은 남음) · 맵을 다시 들인다(허리 물)
func _flood_done() -> void:
	var t: Vector2i = host.map.tile_of(host.player.loco.logical)
	if not _in_high(t):
		host.combat.damage(host.combat.pc.max_hp * 0.4)
		st.vars.set_v("PC_RADS", int(st.vars.get_v("PC_RADS")) + 15)
		host.hint("물살에 휩쓸렸다. 비린 물을 들이켰다.", 4.0)
	_sv("UQ09_FLOOD", 1)
	if v("UQ09_MOM") == 0:
		_sv("UQ09_MOM", 2)
		_sv("UQ09_MOM_DAY", day())
		st.kill(MOM_WHO)
	for k in ["UQ09_E1", "UQ09_E2"]:
		if v(k) == 0:
			_sv(k, 2)
	_log("배수 밸브 — 저수 바닥이 찼다")
	host.enter("J-10", "", {}, host.player.loco.logical)


func _uq09_day(d: int) -> void:
	if v("UQ09_PEND") == 1:
		_sv("UQ09_PEND", 0)
		_sv("UQ09_CLEAN", 1)                                              # 물이 저수조를 한 바퀴 — 다음 아침 바늘이 눕는다(P6)
		_log("정수가 맑아짐")
	if v("UQ09_FLOOD") == 1:
		_sv("UQ09_FLOOD", 2)                                              # 하룻밤에 물이 빠진다(밸브는 열린 채)
	if v("UQ09_LIE") == 1 and d > v("UQ09_LIE_DAY"):                  # '처리했어' — 아침 바늘이 그대로면 들킨다
		if v("UQ09_READY") == 0 and v("UQ09_CLEAN") == 0:
			_sv("UQ09_LIE", 2)
			st.call_fn("aff", ["JH", -1])
		else:
			_sv("UQ09_LIE", 0)
	# ② 뒤 14일: 어미가 새 관까지 따라와 다시 탁해짐(재발동 1회)
	if v("UQ09_RES") == 2 and v("UQ09_REDIRTY") == 0 and v("UQ09_REDIRTY_DAY") > 0 and d >= v("UQ09_REDIRTY_DAY") and v("UQ09_MOM") == 0:
		_sv("UQ09_REDIRTY", 1)
		_sv("UQ09_CLEAN", 0)
		_log("정수 재오염(② 14일)")
	# 어미 없이 남은 알집 — 사흘 뒤 큰바퀴가 다시 붐(반쯤 된 상태가 아니라 '아직 덜 끝남')
	if v("UQ09_MOM") in [1, 2] and v("UQ09_REGROW") == 0 and d >= v("UQ09_MOM_DAY") + REGROW_DAYS \
			and (v("UQ09_E1") == 0 or v("UQ09_E2") == 0 or v("UQ09_E3") == 0):
		_sv("UQ09_REGROW", 1)
	if st.is_dead(MINJI):
		var s9: int = st.quests.stage("UQ-09")
		if s9 > 0 and s9 < 100:
			st.quests.set_stage("UQ-09", 90)
