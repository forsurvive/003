## 반복 퀘스트 1막 진행기(단계 1-12j, SD-05 §4.2 RQ-19 계단 보수 · RQ-15 아이들의 교재 · RQ-06 독샘 납품 · RQ-08 그때 물건 · RQ-30 정착지 야간 경계(봉천)).
## 규칙(곡선 · 주간 캡 상한 · 단골 · 판도)은 공통 엔진 core/story/repeat.gd(StoryState.call_fn "rq")가 맡고, 여기는 각 RQ의 물건 · 사건 · 장면만.
## 원고: script/act1/RQ.txt(오봉수 · 조만석 · 오해인 · 남태하 — 장면 ID는 ZRQ…로 퀘스트 장면 뒤에 선다) · JM_PEOPLE.txt(엄수연 · 사공민영 메뉴).
## 변수(엔진 EXTRA): RQ08_P1~P3 이번 주 찾는 2077 잡화(M-0nn의 nn) · RQ08_PWK 그 주 · RQ08_HAVE 셋 다 있나(cmd가 채움) /
##   RQ30_ON 야간 경계 진행 중 · DAY 그날 · KIND 위협(1 패거리 · 2 들개 · 3 옴 너구리) · DIR 방향(1 아랫문 · 2 윗문 · 3 뒷산) · AT 사건 절대 분 ·
##   PHASE 0 전조 · 1 사건 중 · 2 끝(아침까지) · 3 보고 대기(06:00 지남) · N 세운 수 · KILLS 쓰러뜨린 수 · QUIET 아무 일 없는 밤 /
##   RQ19_IRON · RQ15_BOOKS 풍경 단계(맵 소품 cond — 재미 검수 '납품물이 풍경이 된다').
## 예상 밖 행동: 같은 날 여러 번(엔진 ×0.5/0) · 의뢰처 죽음(원고 @cond dead) · 경계 중 마을을 떠남(06:00 닫힘, 보상 없음 — P6 · P10) ·
##   경계 시작 뒤 저장/불러오기(세운 적은 저장 안 됨 — 불러오면 사건을 다시 세운다) · 적을 안 잡고 숨음(06:00 닫힘) · 22시 전에 옴(기다리기 선택).
class_name RqR01
extends Node

const XP_NIGHT := 30
const NIGHT_KIND := {1: ["CR-420", "CR-421", "CR-423"], 2: ["CR-104", "CR-105"], 3: ["CR-136"]}
const NIGHT_N := {1: [3, 4], 2: [4, 6], 3: [2, 3]}
const NIGHT_CAPS := {1: 70, 2: 55, 3: 40}
const JUNK_POOL := [80, 81, 82, 83, 84, 85, 86, 88, 89, 90, 92, 93, 94, 95, 96, 97, 99]   ## 2077 생활 잡화(빈 병 · 바구니 · 명찰은 뺀다)
const NIGHT_MARK := {1: "X-BC:sbf2", 2: "X-BC:upgate", 3: "X-BC:tanks"}   ## 사건이 솟는 자리(재미 검수: 전조 방향이 동선이 되게 — 아랫문 · 윗문 · 뒷산)
const NIGHT_SEE := 12                                                   ## 그 자리 12칸 안에 서 있으면 '먼저 본다'(힌트 · 적이 아직 나를 못 봄)

var host: InteriorHost
var st: StoryState
var log_on := false
var _mobs: Array = []


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


func _process(_dt: float) -> void:
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


func _on_map(_id: String) -> void:
	_mobs.clear()                                                       # 세운 적은 맵과 함께 사라진다 — 사건 중이었으면 다시 세운다
	if v("RQ30_ON") == 1 and v("RQ30_PHASE") == 1:
		_sv("RQ30_PHASE", 0)
		_sv("RQ30_AT", now() + 5)


# ---------------------------------------------------------------- 풍경(단골 단계마다 한 칸 — 맵 소품 cond가 읽는다)
func _scenery(iron: bool) -> void:
	if iron:
		var t := v("RQ19_T")
		_sv("RQ19_IRON", 3 if t >= 30 else (2 if t >= 15 else (1 if t >= 5 else 0)))
	var b := v("RQ15_T")
	_sv("RQ15_BOOKS", 3 if b >= 15 else (2 if b >= 5 else (1 if b >= 1 else 0)))
