## 반복 퀘스트 1막 진행기(단계 1-12j, SD-05 §4.2 RQ-19 계단 보수 · RQ-15 아이들의 교재 · RQ-06 독샘 납품 · RQ-08 그때 물건 · RQ-30 정착지 야간 경계(봉천)).
## 규칙(곡선 · 주간 캡 상한 · 단골 · 판도)은 공통 엔진 core/story/repeat.gd(StoryState.call_fn "rq")가 맡고, 여기는 각 RQ의 물건 · 사건 · 장면만.
## 원고: script/act1/RQ.txt(오봉수 · 조만석 · 오해인 · 남태하 — 장면 ID는 ZRQ…로 퀘스트 장면 뒤에 선다) · JM_PEOPLE.txt(엄수연 · 사공민영 메뉴).
## 변수(엔진 EXTRA): RQ08_P1~P3 이번 주 찾는 2077 잡화(M-0nn의 nn) · RQ08_PWK 그 주 · RQ08_HAVE 셋 다 있나(cmd가 채움) /
##   RQ30_ON 야간 경계 진행 중 · DAY 그날 · KIND 위협(1 패거리 · 2 들개 · 3 옴 너구리) · DIR 방향(1 아랫문 · 2 윗문 · 3 뒷산) · AT 사건 절대 분 ·
##   PHASE 0 전조 · 1 사건 중 · 2 끝(아침까지) · 3 보고 대기(06:00 지남) · N 세운 수 · KILLS 쓰러뜨린 수 · QUIET 아무 일 없는 밤 /
##   RQ19_IRON · RQ15_BOOKS 풍경 단계(맵 소품 cond — 재미 검수 '납품물이 풍경이 된다').
## 예상 밖 행동: 같은 날 여러 번(엔진 ×0.5/0) · 의뢰처 죽음(원고 @cond dead) · 경계 중 마을을 떠남(06:00 닫힘, 보상 없음 — P6 · P10) ·
##   경계 시작 뒤 저장/불러오기(세운 적은 저장 안 됨 — 불러오면 사건을 다시 세운다) · 적을 안 잡고 숨음(06:00 닫힘) · 22시 전에 옴(기다리기 선택).
## j-b(계획 §9): RQ-22 배수구 청소(RQ22_ON 0 없음 · 1 받음 · 2 치움 / SET 알집 자리 조합 / K 둥지 수) · RQ-03 현상금(RQ03B_/RQ03S_ ST 0 없음 · 1 공고 · 2 증거 손에 · 3 이번 주 끝 / T 대상 / DAY 공고 날) ·
##   RQ-43 배급 줄(RQ43_HAVE 식량 충분 / ESC 호위 0 · 1 걷는 중 · 2 닿음 / ESC_DAY / AMB 매복 세움) · RQ-46 배급 증명(RQ46_ON · IN 데려온 수 · NEAR 지금 곁에 있는 수 · LEDGER 장부 0 미정 · 1 둠 · 2 태움 · 3 넘김).
##   세운 적 · 인물은 저장하지 않는다 — 맵이 바뀌면 지우고 돌아오면 다시 세운다(P10 반쯤 된 상태 없음은 변수가 맡는다).
class_name RqR01
extends Node

const XP_NIGHT := 30
const NIGHT_KIND := {1: ["CR-420", "CR-421", "CR-423"], 2: ["CR-104", "CR-105"], 3: ["CR-136"]}
const NIGHT_N := {1: [3, 4], 2: [4, 6], 3: [2, 3]}
const NIGHT_CAPS := {1: 70, 2: 55, 3: 40}
const JUNK_POOL := [80, 81, 82, 83, 84, 85, 86, 88, 89, 90, 92, 93, 94, 95, 96, 97, 99]   ## 2077 생활 잡화(빈 병 · 바구니 · 명찰은 뺀다)
const NIGHT_MARK := {1: "X-BC:sbf2", 2: "X-BC:upgate", 3: "X-BC:tanks"}   ## 사건이 솟는 자리(재미 검수: 전조 방향이 동선이 되게 — 아랫문 · 윗문 · 뒷산)
const NIGHT_SEE := 12                                                   ## 그 자리 12칸 안에 서 있으면 '먼저 본다'(힌트 · 적이 아직 나를 못 봄)
const NEST_SPOTS := [Vector2i(14, 5), Vector2i(21, 14), Vector2i(5, 4)] ## J-10 알집 자리 셋(UQ-09와 같은 자리)
const NEST_SETS := {1: [0, 1], 2: [1, 2], 3: [2, 0]}
const BOUNTY := {                                                        ## 게시판 현상금(SD-05 §4.4 — 봉천 B · 사당 S): 대상 · 자리 · 증거 · 캡
	"B": [{"kind": "CR-421", "lv": 10, "at": Vector2i(966, 1428), "item": "M-325", "caps": 150, "name": "낙성대 척후조장", "hp": 2.0},
		{"kind": "CR-106", "lv": 7, "at": Vector2i(884, 1533), "item": "M-326", "caps": 100, "name": "관악산 들개 우두머리", "hp": 1.5},
		{"kind": "CR-423", "lv": 10, "at": Vector2i(872, 1572), "item": "M-325", "caps": 200, "name": "삼성산 능선 캠프 조장", "hp": 2.0}],
	"S": [{"kind": "CR-097", "lv": 8, "map": "U-01", "mark": "x1", "item": "M-152", "caps": 150, "name": "서쪽 터널 왕쥐", "hp": 1.5},
		{"kind": "CR-096", "lv": 10, "at": Vector2i(1098, 1486), "item": "M-327", "caps": 100, "name": "남태령 굴쥐 우두머리", "hp": 2.5}]}
const BOUNTY_FAC := {"B": "BC", "S": "SA"}
const BOUNTY_R := 45
const LOOKS := ["st_look_e1_s3_hr04_h3_t03_2_pf12_hd00_ey00_pr011", "st_look_f1_s4_hr06_h2_t05_1_pf12_hd00_ey00", "st_look_m1_s2_hr02_h1_t03_2_pf01_hd00_ey00_pr033"]
const ESC_FROM := Vector2i(1113, 1409)                                  ## 사당 광장(L-R01-18 도착점) — 주민 셋이 기다리는 곳
const ESC_TO := Vector2i(1102, 1460)                                    ## 사당 고개 검문소(L-R01-19) 문 앞
const REF_AT := Vector2i(671, 1097)                                     ## 영등포 구청 배급소(L-R02-15) 앞 — 피난민 셋
const FOLLOW_R := 8.0
const FOOD_WORTH := 80

var host: InteriorHost
var st: StoryState
var log_on := false
var _mobs: Array = []
var _nests: Array = []                                                  ## RQ-22 세운 바퀴
var _boss := {}                                                         ## RQ-03 세운 대상 {"B": Enemy, "S": Enemy}
var _esc: Array = []                                                    ## RQ-43 주민 셋(Actor)
var _esc_path: Array = []
var _ref: Array = []                                                    ## RQ-46 피난민 셋(Actor)
var _ref_path: Array = []


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["rq"] = _cmd
	host.day_tick.connect(_on_day)
	host.map_entered.connect(_on_map)
	_week_pick()


func _log(s: String) -> void:
	if log_on:
		print("[반복 의뢰] " + s)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v(k, n)


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func now() -> int:
	return Clock.abs_min(host.date_text) if host.date_text != "" else 0


func _hour() -> int:
	return (now() % 1440) / 60


func _opt(extra := {}) -> Dictionary:
	var o := {"now": now(), "region": "R01"}
	o.merge(extra)
	return o


# ---------------------------------------------------------------- 명령(원고 @cmd rq …)
func _cmd(a: Array, done: Callable) -> void:
	var what := str(a[0]) if a.size() > 0 else ""
	var sub := str(a[1]) if a.size() > 1 else ""
	match what:
		"19":                                                           # 고철(원고 [물건:M-010 n]이 이미 가져갔다): caps → 10캡 + 5 XP / karma → 카르마 +10. BC +1은 5개마다. 셋째 인자 = 개수(다섯 묶음)
			var cnt := int(a[2]) if a.size() > 2 else 1
			for _i in cnt:
				var r: Dictionary
				if sub == "karma":
					r = st.call_fn("rq", ["RQ-19", "BC", 0, 5, "supply", _opt({"aff": 0, "regular_every": 5, "what": "봉천 계단 보수에 고철을 댄다"})])
					st.call_fn("karma", [10])
				else:
					r = st.call_fn("rq", ["RQ-19", "BC", 10, 5, "supply", _opt({"aff": 0, "regular_every": 5, "what": "봉천 계단 보수에 고철을 댄다"})])
				if int(r.get("n", 0)) % 5 == 0:
					st.call_fn("aff", ["BC", 1])
				_log("RQ-19 %d회(%s) 캡 %d" % [int(r.get("n", 0)), sub, int(r.get("caps", 0))])
			_scenery(false)                                                 # 철판은 다음 날 06:00에(오봉수 "내일 가 봐")
		"15":                                                           # 문제집 한 권(원고가 가져갔다): 카르마 +10 · BC +1 · JC +1
			var r: Dictionary = st.call_fn("rq", ["RQ-15", "BC", 0, 0, "supply", _opt({"aff": 1, "what": "봉천 계단 학교에 문제집을 댄다"})])
			st.call_fn("karma", [10])
			st.call_fn("aff", ["JC", 1])
			_scenery(false)
			_log("RQ-15 %d회" % int(r.get("n", 0)))
		"06":                                                           # 독샘 · 독낭 합 셋(독샘부터 꺼낸다) → 50캡 + 해독 앰플 1 + 10 XP · JH +2
			var need := 3
			var sac := mini(need, st.count_of("M-048"))
			if sac > 0:
				st.call_fn("take", ["M-048", sac])
			need -= sac
			if need > 0:
				st.call_fn("take", ["M-026", need])
			var r: Dictionary = st.call_fn("rq", ["RQ-06", "JH", 50, 10, "supply", _opt({"what": "지하시장 약방에 독샘을 댄다"})])
			st.call_fn("give", ["I-007", 1])
			_log("RQ-06 %d회 캡 %d" % [int(r.get("n", 0)), int(r.get("caps", 0))])
		"08":
			_week_pick()
			if sub == "say":                                             # 이번 주 찾는 셋을 말한다
				host.say_text("사공민영이 손가락을 꼽는다. \"이번 주엔 %s, %s, %s. 셋 다 들고 오면 값의 한 배 반.\"" % [_jname(1), _jname(2), _jname(3)])
			elif sub == "give":                                          # 셋 다 있으면 받고 가치 × 1.5 · JH +1 (RQ08_HAVE 0이면 원고가 모자람을 말한다)
				var ok := true
				for i in [1, 2, 3]:
					if st.count_of(_jid(i)) <= 0:
						ok = false
				_sv("RQ08_HAVE", 1 if ok else 0)
				if ok:
					var worth := 0
					for i in [1, 2, 3]:
						st.call_fn("take", [_jid(i), 1])
						worth += int(host.items_db.get(_jid(i), {}).get("value", 0))
					var r: Dictionary = st.call_fn("rq", ["RQ-08", "JH", roundi(worth * 1.5), 0, "fixed", _opt({"aff": 1, "what": "세월상회에 그때 물건을 댄다"})])
					_log("RQ-08 %d회 가치 %d → 캡 %d" % [int(r.get("n", 0)), worth, int(r.get("caps", 0))])
		"30":
			match sub:
				"wait":                                                  # 22:00까지 기다린다(이른 저녁에 온 사람)
					var to := (22 * 60 - now() % 1440 + 1440) % 1440
					if to > 0 and to < 12 * 60:
						host.advance_minutes(to)
					_night_start()
				"start":
					_night_start()
				"morning":                                               # 사건 뒤 "아침까지 선다" — 04:00까지 보낸다(그사이 둘째 전조 없음 · 조용)
					var to := (4 * 60 - now() % 1440 + 1440) % 1440
					if to > 0 and to <= 6 * 60:
						host.advance_minutes(to)
				"done":
					_night_done()
		"22":
			match sub:
				"start":                                                 # 노복희 의뢰: 이번 주 알집 자리 조합 · 둥지 수
					var wk := Repeat.week_of(st)
					_sv("RQ22_ON", 1)
					_sv("RQ22_SET", 1 + (wk * 7 + 2) % 3)                     # 첫 주는 저수조 · 물길 건너(사다리 없는 자리부터)
					_sv("RQ22_K", 1 + wk % 2)
					_log("RQ-22 받음 — 자리 %d · 둥지 %d" % [v("RQ22_SET"), v("RQ22_K")])
				"done":
					var r: Dictionary = st.call_fn("rq", ["RQ-22", "JH", 60, 25, "act", _opt({"region": "R02", "what": "지하상가 배수구를 치운다"})])
					st.call_fn("give", ["I-059", 3])
					_sv("RQ22_ON", 0)
					_nests.clear()
					_log("RQ-22 %d회 캡 %d" % [int(r.get("n", 0)), int(r.get("caps", 0))])
		"03":
			var b := str(a[2]) if a.size() > 2 else "B"
			match sub:
				"post":                                                  # 게시판을 읽으면(7일마다 1건) 공고가 붙는다
					_bounty_post(b)
				"claim":                                                 # 증거를 낸다(원고 [물건:…]이 가져갔다)
					var tg: Dictionary = BOUNTY[b][v("RQ03%s_T" % b) - 1]
					var r: Dictionary = st.call_fn("rq", ["RQ-03", BOUNTY_FAC[b], int(tg["caps"]), 40, "act",
						_opt({"aff": 3, "what": "%s 현상금 공고를 해결한다" % ("봉천" if b == "B" else "사당")})])
					_sv("RQ03%s_ST" % b, 3)
					_log("RQ-03 %s %s 캡 %d" % [b, str(tg["name"]), int(r.get("caps", 0))])
		"43":
			match sub:
				"food":                                                  # 식량 · 물 가치 80어치(비싼 것부터) — 모자라면 RQ43_HAVE 0
					_sv("RQ43_HAVE", 1 if _take_food(FOOD_WORTH) else 0)
					if v("RQ43_HAVE") == 1:
						var r: Dictionary = st.call_fn("rq", ["RQ-43", "BC", 30, 0, "act", _opt({"aff": 2, "zone": "PD_R01", "what": "봉천 배급소에 식량을 댄다"})])
						st.call_fn("karma", [10])
						_log("RQ-43 봉천 %d회 캡 %d" % [int(r.get("n", 0)), int(r.get("caps", 0))])
				"escort":                                                # 권은서: 광장의 셋을 고개 위로
					_sv("RQ43_ESC", 1)
					_sv("RQ43_ESC_DAY", day())
					_sv("RQ43_AMB", 0)
					_esc_clear()
				"escdone":
					var r: Dictionary = st.call_fn("rq", ["RQ-43", "BJ", 30, 0, "act", _opt({"aff": 2, "zone": "PD_R01_BJ", "what": "검문소 배급 줄을 호위한다"})])
					st.call_fn("give", ["I-031", 1])
					_sv("RQ43_ESC", 0)
					_esc_clear()
					_log("RQ-43 검문소 %d회 캡 %d" % [int(r.get("n", 0)), int(r.get("caps", 0))])
		"46":
			match sub:
				"start":
					_sv("RQ46_ON", 1)
					_sv("RQ46_IN", 0)
					_sv("RQ46_NEAR", 0)
					_ref_clear()
				"cert":                                                  # 셋을 창구까지: 20 XP · JC +2 · 피난민 정착지(세이프빌) +1 · 장부를 넘겼으면 BJ +1
					var r: Dictionary = st.call_fn("rq", ["RQ-46", "JC", 0, 20, "act", _opt({"aff": 2, "region": "R02", "what": "피난민에게 배급 증명을 받게 한다"})])
					if st.vars.has("AFF_JC_SV"):
						st.call_fn("aff", ["SV", 1])
					if v("RQ46_LEDGER") == 3:
						st.call_fn("aff", ["BJ", 1])
					_sv("RQ46_ON", 0)
					_sv("RQ46_IN", 0)
					_ref_clear()
					_log("RQ-46 %d회" % int(r.get("n", 0)))
				"handed":                                                # 권은서가 넘긴 장부를 받았다고 말함(한 번)
					_sv("RQ46_LSAID", 1)
				"ledger":                                                # 1회 분기: 1 둔다 · 2 태운다(BJ −3 · 카르마 +25) · 3 넘긴다(BJ +5)
					var n := int(a[2]) if a.size() > 2 else 1
					_sv("RQ46_LEDGER", n)
					if n == 2:
						st.call_fn("aff", ["BJ", -3])
						st.call_fn("karma", [25])
					elif n == 3:
						st.call_fn("aff", ["BJ", 5])
		"check":
			_week_pick()
	done.call()


# ---------------------------------------------------------------- RQ-08 이번 주 물건
func _week_pick() -> void:
	var wk := Repeat.week_of(st)
	if v("RQ08_PWK") == wk and v("RQ08_P1") > 0:
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash("rq08:%d" % wk)
	var pool := JUNK_POOL.duplicate()
	for i in [1, 2, 3]:
		var k := r.randi() % pool.size()
		_sv("RQ08_P%d" % i, int(pool[k]))
		pool.remove_at(k)
	_sv("RQ08_PWK", wk)
	_sv("RQ08_HAVE", 0)


func _jid(i: int) -> String:
	return "M-0%02d" % v("RQ08_P%d" % i)


func _jname(i: int) -> String:
	return str(host.items_db.get(_jid(i), {}).get("name", _jid(i)))


# ---------------------------------------------------------------- RQ-30 봉천 야간 경계
func _night_start() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("rq30:%d" % day())                                  # 같은 밤은 같은 사건(저장 · 불러오기에 흔들리지 않는다)
	var roll := r.randi_range(1, 100)
	var kind := 1 if roll <= 50 else (2 if roll <= 80 else 3)
	_sv("RQ30_ON", 1)
	_sv("RQ30_DAY", day() if _hour() >= 12 else day() - 1)
	_sv("RQ30_KIND", kind)
	_sv("RQ30_DIR", r.randi_range(1, 3))
	_sv("RQ30_QUIET", 1 if r.randi_range(1, 100) <= 20 else 0)
	_sv("RQ30_AT", now() + r.randi_range(40, 150))
	_sv("RQ30_PHASE", 0)
	_sv("RQ30_N", r.randi_range(NIGHT_N[kind][0], NIGHT_N[kind][1]))
	_sv("RQ30_KILLS", 0)
	_mobs.clear()
	_log("야간 경계 시작: 위협 %d 방향 %d 조용 %d 사건 %d분 뒤" % [kind, v("RQ30_DIR"), v("RQ30_QUIET"), v("RQ30_AT") - now()])


func _in_bc() -> bool:
	if host.map == null or host.player == null:
		return false
	if host.map is WorldMap:
		return (host.map as WorldMap).zone_of(host.map.tile_of(host.player.loco.logical)) == "X-BC"
	return host.map.id == "X-BC"


func _dir_vec() -> Vector2i:
	match v("RQ30_DIR"):
		1:
			return Vector2i(0, 1)                                       # 아랫문(남)
		2:
			return Vector2i(0, -1)                                      # 윗문(북)
	return Vector2i(-1, 0)                                              # 뒷산(서)


func _spawn_night() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("rq30s:%d" % day())
	var kind := v("RQ30_KIND")
	var c0: Vector2i = _night_cell()
	var kinds: Array = NIGHT_KIND[kind]
	_mobs.clear()
	for i in v("RQ30_N"):
		var pos := Vector2.ZERO
		for _t in 30:
			var c := c0 + Vector2i(r.randi_range(-3, 3), r.randi_range(-2, 2))
			if not host.map.is_solid(c):
				pos = Vector2(c.x * 32 + 16, c.y * 32 + 16)
				break
		if pos == Vector2.ZERO:
			pos = Vector2(c0.x * 32 + 16, c0.y * 32 + 16)
		var e = host.combat.spawn(str(kinds[r.randi() % kinds.size()]), pos, host.map, st, {"lv": r.randi_range(3, 7), "morale": false})
		if e != null:
			_mobs.append(e)
	_sv("RQ30_PHASE", 1)
	var pc: Vector2i = host.map.tile_of(host.player.loco.logical)
	var there := (pc - c0).length() <= NIGHT_SEE
	var where: String = ["아랫문", "윗문", "뒷산"][v("RQ30_DIR") - 1]
	if there:
		host.hint("%s 쪽. 먼저 봤다 — 저쪽은 아직 나를 못 봤다." % where, 4.0)
	else:
		host.hint(["%s에서 개 짖는 소리. 뛰어야 한다." % where, "%s 쪽에서 불빛 — 마을 안으로 들어온다." % where, "%s 쪽에서 소리가 난다." % where][kind - 1], 4.5)
	_log("야간 위협 %d마리 세움(%s · 먼저 봄 %s)" % [_mobs.size(), where, str(there)])


## 사건이 솟는 자리: 방향별 봉천 표지(월드 좌표) — 없으면 주인공 둘레
func _night_cell() -> Vector2i:
	var m: String = NIGHT_MARK[v("RQ30_DIR")]
	if host.map.has_method("mark_pos"):
		var p: Vector2 = host.map.mark_pos(m)
		if p != Vector2.ZERO:
			return host.map.tile_of(p)
	return host.map.tile_of(host.player.loco.logical) + _dir_vec() * 9


func _process(dt: float) -> void:
	_night_tick()
	_nest_tick()
	_bounty_tick()
	_escort_tick(dt)
	_refugee_tick(dt)


func _night_tick() -> void:
	if v("RQ30_ON") != 1 or v("RQ30_PHASE") >= 2:
		return
	if v("RQ30_PHASE") == 0:
		if now() >= v("RQ30_AT") and _in_bc():
			if v("RQ30_QUIET") == 1:
				_sv("RQ30_PHASE", 2)
				host.hint("…아무것도 안 온다. 바람뿐이다. 아침까지 선다.", 5.0)
			else:
				_spawn_night()
		return
	if v("RQ30_PHASE") == 1:                                            # 사건 중: 세운 것이 다 쓰러지면 끝
		var left := 0
		for e in _mobs:
			if is_instance_valid(e) and not e.cmb.dead:
				left += 1
		_sv("RQ30_KILLS", v("RQ30_N") - left)
		if left == 0 and not _mobs.is_empty():
			_sv("RQ30_PHASE", 2)
			host.hint("조용해졌다. 아침까지 지켜 선다 — 남태하에게.", 5.0)


func _night_done() -> void:
	var caps: int = int(NIGHT_CAPS[v("RQ30_KIND")]) if v("RQ30_QUIET") == 0 else 40
	var r: Dictionary = st.call_fn("rq", ["RQ-30", "BC", caps, XP_NIGHT, "act", _opt({"zone": "PD_BC", "what": "봉천 밤 경계를 선다"})])
	_sv("RQ30_ON", 0)
	_sv("RQ30_PHASE", 0)
	_mobs.clear()
	st.vars.set_v("WELL_RESTED", now() + 12 * 60)                     # 그날 숙박 무료(자경대 숙소) — 06:00까지 보낸다
	var to := (6 * 60 - now() % 1440 + 1440) % 1440
	if to > 0 and to <= 8 * 60:
		host.advance_minutes(to)
	host.hint("자경대 숙소에서 눈을 붙였다. 아침이다.", 4.0)
	_log("야간 경계 끝 캡 %d XP %d" % [int(r.get("caps", 0)), int(r.get("xp", 0))])


func _on_day(_d: int) -> void:
	_scenery(true)                                                      # 계단 철판은 밤새 갈린다
	if v("RQ43_ESC") == 1 and v("RQ43_ESC_DAY") < day():                 # 호위를 두고 하루가 지남 — 흐지부지(주민은 제 발로 돌아간다)
		_sv("RQ43_ESC", 0)
		_esc_clear()
	if v("RQ30_ON") != 1:
		return
	if v("RQ30_PHASE") >= 2:
		_sv("RQ30_PHASE", 3)                                            # 밤을 지켰는데 보고 전 06:00 — 그날 안에 보고하면 된다
		return
	_sv("RQ30_ON", 0)                                                   # 자리를 비웠거나 사건을 못 끝냈다 — 조용히 닫힘(실패 보고 없음, 다음 기회)
	_sv("RQ30_PHASE", 0)
	_mobs.clear()
	if _in_bc():
		host.hint("날이 밝았다. 밤 경계는 흐지부지 끝났다.", 4.0)


func _on_map(id: String) -> void:
	_mobs.clear()                                                       # 세운 적은 맵과 함께 사라진다 — 사건 중이었으면 다시 세운다
	if v("RQ30_ON") == 1 and v("RQ30_PHASE") == 1:
		_sv("RQ30_PHASE", 0)
		_sv("RQ30_AT", now() + 5)
	_nests.clear()
	_boss.clear()
	if id == "K-15" and v("RQ46_ON") == 1 and v("RQ46_NEAR") >= 3:      # 피난민 셋이 곁에 있는 채로 배급소에 들어왔다 — 함께 들어온 셈
		_sv("RQ46_IN", 3)
		host.hint("셋이 뒤따라 들어와 번호표를 뽑는다.", 4.0)
	_esc_clear()
	_ref_clear()
	if id == "J-10" and v("RQ22_ON") == 1:
		_spawn_nests()


# ---------------------------------------------------------------- 풍경(단골 단계마다 한 칸 — 맵 소품 cond가 읽는다)
func _scenery(iron: bool) -> void:
	if iron:
		var t := v("RQ19_T")
		_sv("RQ19_IRON", 3 if t >= 30 else (2 if t >= 15 else (1 if t >= 5 else 0)))
	var b := v("RQ15_T")
	_sv("RQ15_BOOKS", 3 if b >= 15 else (2 if b >= 5 else (1 if b >= 1 else 0)))


# ---------------------------------------------------------------- RQ-22 배수구 둥지(J-10)
func _spawn_nests() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("rq22:%d" % Repeat.week_of(st))
	_nests.clear()
	var idx: Array = NEST_SETS.get(v("RQ22_SET"), [0, 1])
	for i in mini(v("RQ22_K"), idx.size()):
		var c0: Vector2i = NEST_SPOTS[int(idx[i])]
		var e = host.combat.spawn("CR-004", _free_near(c0, r, 2, 1), host.map, st, {"lv": r.randi_range(3, 6), "morale": false})
		if e != null:
			_nests.append(e)
		for _k in 2:
			var s2 = host.combat.spawn("CR-001", _free_near(c0, r, 3, 2), host.map, st, {"morale": false})
			if s2 != null:
				_nests.append(s2)
	_log("RQ-22 둥지 %d · 바퀴 %d" % [v("RQ22_K"), _nests.size()])


func _nest_tick() -> void:
	if v("RQ22_ON") != 1 or _nests.is_empty() or host.map == null or host.map.id != "J-10":
		return
	for e in _nests:
		if is_instance_valid(e) and not e.cmb.dead:
			return
	_sv("RQ22_ON", 2)
	_nests.clear()
	host.hint("배수구가 조용하다. 노복희에게 보고.", 4.0)


func _free_near(c0: Vector2i, r: RandomNumberGenerator, rx: int, ry: int) -> Vector2:
	for _t in 30:
		var c := c0 + Vector2i(r.randi_range(-rx, rx), r.randi_range(-ry, ry))
		if not host.map.is_solid(c):
			return Vector2(c.x * 32 + 16, c.y * 32 + 16)
	return Vector2(c0.x * 32 + 16, c0.y * 32 + 16)


# ---------------------------------------------------------------- RQ-03 게시판 현상금
func _bounty_post(b: String) -> void:
	var st_ := v("RQ03%s_ST" % b)
	var d0 := v("RQ03%s_DAY" % b)
	if st_ == 1:
		return
	if d0 > 0 and day() < d0 + 7:
		return                                                          # 증거를 손에 쥔 채(2)여도 이레가 지나면 새 공고가 붙는다(증거를 팔았어도 잠기지 않는다)
	var cands := []                                                      # 살아 있는 후보 — 봉천 ① 낙성대 척후조장 · ③ 삼성산 캠프 조장은 SQ-S02의 캠프와 같은 자리라 그 퀘스트가 끝난 뒤에만(겹침 · P4)
	for i in BOUNTY[b].size():
		if b == "B" and i in [0, 2] and st.quests.stage("SQ-S02") < 100:
			continue
		if b == "B" and i == 1 and st.quests.stage("SQ-S01") < 100:      # ② 바위굴은 SQ-S01의 들개 무리 자리 — 그 퀘스트가 끝난 뒤의 '새 우두머리'
			continue
		cands.append(i + 1)
	if cands.is_empty():
		return
	_sv("RQ03%s_T" % b, int(cands[(day() * 31 + (0 if b == "B" else 5)) % cands.size()]))
	_sv("RQ03%s_ST" % b, 1)
	_sv("RQ03%s_DAY" % b, day())
	_log("RQ-03 %s 공고 — %s" % [b, str(BOUNTY[b][v("RQ03%s_T" % b) - 1]["name"])])


func _bounty_tick() -> void:
	if host.map == null or host.player == null:
		return
	for b in ["B", "S"]:
		if v("RQ03%s_ST" % b) != 1:
			continue
		var tg: Dictionary = BOUNTY[b][v("RQ03%s_T" % b) - 1]
		if _boss.has(b):
			var e = _boss[b]
			if not is_instance_valid(e):
				_boss.erase(b)
			elif e.cmb.dead:                                            # 쓰러짐 — 증거를 뗀다
				_boss.erase(b)
				_sv("RQ03%s_ST" % b, 2)
				st.call_fn("give", [str(tg["item"]), 1])
				host.hint("%s. 증거를 뗐다 — 게시판 주인에게." % str(tg["name"]), 5.0)
			continue
		var pos := Vector2.ZERO
		if tg.has("map"):
			if host.map.id != str(tg["map"]):
				continue
			pos = host.map.mark_pos(str(tg["mark"]))
		else:
			if not (host.map is WorldMap):
				continue
			var pc: Vector2i = host.map.tile_of(host.player.loco.logical)
			if (pc - (tg["at"] as Vector2i)).length() > BOUNTY_R:
				continue
			var r := RandomNumberGenerator.new()
			r.seed = hash("rq03:%s:%d" % [b, day()])
			pos = _free_near(tg["at"], r, 3, 3)
		if pos == Vector2.ZERO:
			continue
		var e2 = host.combat.spawn(str(tg["kind"]), pos, host.map, st, {"lv": int(tg["lv"]), "morale": false})
		if e2 != null:
			_boss[b] = e2
			e2.cmb.max_hp = e2.cmb.max_hp * float(tg["hp"])               # 두목 · 우두머리: 체력 곱
			e2.cmb.hp = e2.cmb.max_hp
			var r2 := RandomNumberGenerator.new()                        # 부하 1~2(재미 검수: 빈 들판에 혼자 서지 않게) — 척후조 CR-420 · 들개 CR-104 · 굴쥐 CR-096 · 바퀴
			r2.seed = hash("rq03m:%s:%d" % [b, day()])
			var minion: String = {"CR-421": "CR-420", "CR-423": "CR-420", "CR-106": "CR-104", "CR-096": "CR-096", "CR-097": "CR-001"}.get(str(tg["kind"]), "")
			if minion != "":
				var c0: Vector2i = host.map.tile_of(pos)
				for _i in r2.randi_range(1, 2):
					host.combat.spawn(minion, _free_near(c0, r2, 4, 3), host.map, st, {"lv": r2.randi_range(2, 5), "morale": false})
			_log("RQ-03 %s 대상 세움 — %s" % [b, str(tg["name"])])


# ---------------------------------------------------------------- RQ-43 검문소 쪽: 주민 셋 호위(사당 광장 → 고개 검문소)
var _food_ids := {}                                                     ## 식량 · 음료 ID(items_food · items_drink — 자료에 분류 표시가 없어 파일로 가른다)


func _food_set() -> Dictionary:
	if _food_ids.is_empty():
		for f in ["items_food", "items_drink"]:
			var p := "res://data/%s.json" % f
			if FileAccess.file_exists(p):
				for k in JSON.parse_string(FileAccess.get_file_as_string(p)).keys():
					_food_ids[str(k)] = true
	return _food_ids


func _take_food(worth: int) -> bool:
	var cands := []
	var fs := _food_set()
	for k in st.items.keys():
		var base := Gear.base(str(k))
		var it: Dictionary = host.items_db.get(base, {})
		if fs.has(base):
			cands.append([int(it.get("value", 0)), str(k), int(st.items[k])])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var total := 0
	var take := []
	for c in cands:
		for _i in int(c[2]):
			if total >= worth:
				break
			total += int(c[0])
			take.append(str(c[1]))
	if total < worth:
		return false
	for k in take:
		st.call_fn("take", [k, 1])
	return true


func _actor(look: String, pos: Vector2) -> Actor:
	var a := Actor.new()
	a.setup(look, pos, host.map)
	a.mode = "walk"
	host.map.add_actor(a)
	a._show()
	return a


func _clear_actors(arr: Array) -> void:
	for a in arr:
		if a != null and is_instance_valid(a):
			if host.map != null and host.map.has_method("remove_actor"):
				host.map.remove_actor(a)
			a.queue_free()
	arr.clear()


func _esc_clear() -> void:
	_clear_actors(_esc)
	_esc_path = []


func _ref_clear() -> void:
	_clear_actors(_ref)
	_ref_path = []


func _escort_tick(dt: float) -> void:
	if v("RQ43_ESC") != 1 or not (host.map is WorldMap) or host.player == null:
		return
	var pc: Vector2i = host.map.tile_of(host.player.loco.logical)
	if _esc.is_empty():
		if (pc - ESC_FROM).length() > 40:
			return
		var r := RandomNumberGenerator.new()
		r.seed = hash("rq43:%d" % day())
		for i in 3:
			_esc.append(_actor(LOOKS[i], _free_near(ESC_FROM + Vector2i(i - 1, 1), r, 1, 1)))
			_esc_path.append(PackedVector2Array())
		host.hint("광장의 셋이 짐을 챙긴다. 고개 위 검문소까지 — 앞서 걸어야 따라온다.", 5.0)
		return
	var lead: Actor = _esc[0]
	if not is_instance_valid(lead):
		_esc_clear()
		return
	var lt: Vector2i = host.map.tile_of(lead.loco.logical)
	if (lt - ESC_TO).length() <= 6:                                      # 닿음
		_sv("RQ43_ESC", 2)
		_esc_clear()
		host.hint("셋이 검문소 줄 끝에 선다. 권은서에게.", 4.0)
		return
	if v("RQ43_AMB") == 0 and lt.y < ESC_FROM.y + (ESC_TO.y - ESC_FROM.y) / 2 + 4 and lt.y > ESC_FROM.y + 6:   # 고개 중턱 매복
		_sv("RQ43_AMB", 1)
		var r := RandomNumberGenerator.new()
		r.seed = hash("rq43a:%d" % day())
		var pack := ["CR-104", "CR-105", "CR-104"] if r.randi_range(1, 100) <= 60 else ["CR-421", "CR-423"]
		for k in pack:
			host.combat.spawn(k, _free_near(lt + Vector2i(r.randi_range(-4, 4), 5), r, 2, 2), host.map, st, {"lv": r.randi_range(3, 6), "morale": false})
		host.hint("고개 중턱 — " + ("들개다." if pack.size() == 3 else "패거리다."), 4.0)
	var pp: Vector2 = host.player.loco.logical
	for i in _esc.size():
		var a: Actor = _esc[i]
		if not is_instance_valid(a):
			continue
		if a.loco.logical.distance_to(pp) > FOLLOW_R * 32.0:              # 주인공이 멀면 선다
			continue
		if (_esc_path[i] as PackedVector2Array).is_empty():
			var goal := Vector2(ESC_TO.x * 32 + 16 + (i - 1) * 32, ESC_TO.y * 32 + 16)
			_esc_path[i] = NpcRoutine.with_start(host.map, a.loco.logical, goal)
		if not (_esc_path[i] as PackedVector2Array).is_empty():
			_esc_path[i] = NpcRoutine.walk_path(a, _esc_path[i], dt)


# ---------------------------------------------------------------- RQ-46 피난민 셋(영등포 구청 앞 → 배급소)
func _refugee_tick(dt: float) -> void:
	if v("RQ46_ON") != 1 or v("RQ46_IN") >= 3 or not (host.map is WorldMap) or host.player == null:
		return
	var pc: Vector2i = host.map.tile_of(host.player.loco.logical)
	if _ref.is_empty():
		if (pc - REF_AT).length() > 40:
			return
		var r := RandomNumberGenerator.new()
		r.seed = hash("rq46:%d" % day())
		for i in 3:
			_ref.append(_actor(LOOKS[(i + 1) % 3], _free_near(REF_AT + Vector2i(i * 2 - 2, 2), r, 1, 1)))
			_ref_path.append(PackedVector2Array())
		host.hint("구청 앞 셋. 증빙이 없어 줄에도 못 선다 — 가까이 가면 따라온다.", 5.0)
		return
	var pp: Vector2 = host.player.loco.logical
	var near := 0
	for i in _ref.size():
		var a: Actor = _ref[i]
		if not is_instance_valid(a):
			continue
		var d := a.loco.logical.distance_to(pp)
		if d <= 6 * 32.0:
			near += 1
		if d > FOLLOW_R * 32.0 or d <= 2 * 32.0:
			continue
		if (_ref_path[i] as PackedVector2Array).is_empty() or Engine.get_process_frames() % 30 == i:
			_ref_path[i] = NpcRoutine.with_start(host.map, a.loco.logical, pp + Vector2((i - 1) * 24, 28))
		if not (_ref_path[i] as PackedVector2Array).is_empty():
			_ref_path[i] = NpcRoutine.walk_path(a, _ref_path[i], dt)
	_sv("RQ46_NEAR", near)
