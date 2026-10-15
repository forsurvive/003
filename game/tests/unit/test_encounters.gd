## 추적·현상금(단계 1-3): 수배도 등급·하한·하루 상한·공고, 시각(분 더하기·06:00), 인카운터 판정(위협도 격자·정착지·주기·안전 간격·EP·추적대).
extends RefCounted


func _st(act := 1) -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", act)
	st.vars.set_v("GAME_DAY", 2)
	return st


func test_wanted_grades(t) -> void:
	var st := _st()
	t.eq([Wanted.grade_of(0), Wanted.grade_of(1), Wanted.grade_of(29), Wanted.grade_of(30), Wanted.grade_of(60), Wanted.grade_of(80)],
		[0, 1, 1, 2, 3, 4], "등급 경계 0 · 1~29 · 30~59 · 60~79 · 80~100(SD-12 §9.7)")
	t.eq(Wanted.add(st, 10), 10, "1막: +10")
	t.eq(st.events.filter(func(e): return e["kind"] == "wanted").size(), 1, "등급이 바뀌면 알림 1번(미등재 → 소문)")
	t.eq(Wanted.add(st, -30), 1, "1막 하한 = 등급 1(값 1) — 캡으로도 그 밑으로는 못 내린다(SD-15 §5.7.2)")
	st.vars.set_v("V_ACT", 2)
	Wanted.refresh(st)
	t.eq(Wanted.value(st), 30, "2막 하한 = 수배 공고(30)")
	t.eq(Wanted.bounty(st), 500, "공고 금액 500(SD-15 §5.7.1)")
	st.vars.set_v("AFF_BJ", 55)
	Wanted.refresh(st)
	t.eq(Wanted.value(st), 0, "비상정부 신뢰 이상 = 공고 철회, 0 고정")
	t.eq(Wanted.add(st, 3, "auth"), 0, "신뢰 이상이면 관리자 인증 +3도 0")
	st.vars.set_v("AFF_BJ", 0)
	Wanted.refresh(st)
	for i in 6:
		Wanted.add(st, 2, "kill")
	t.eq(Wanted.value(st), 40, "계엄군 사살 +2 — 하루 상한 +10(30 → 40)")
	st.vars.set_v("GAME_DAY", 3)
	Wanted.add(st, 2, "kill")
	t.eq(Wanted.value(st), 42, "다음 날 다시 센다")
	for i in 4:
		Wanted.add(st, 3, "auth")
	t.eq(Wanted.value(st), 51, "관리자 인증 +3 — 하루 상한 +9")
	st.vars.set_v("AFF_BJ", -30)
	t.ok(Wanted.notice(st).begins_with("도주 관리자"), "경계 이하 공고 문안 '도주 관리자'(SD-03a §6.5)")
	st.vars.set_v("AFF_BJ", 25)
	t.ok(Wanted.notice(st).begins_with("관리자 후보 보호 중"), "우호 공고 문안")
	t.ok(Wanted.notice(st).contains("볼트 S-07 작업복 차림, 19세가량"), "인상착의(SD-12 §9.7 예)")
	t.ok(not Wanted.disguised(st, "A-001"), "점프슈트 그대로면 변장 아님")
	t.ok(Wanted.disguised(st, "A-016"), "다른 옷이면 변장(무명 알아보기 절반)")
	Wanted.seen_wearing(st, "A-016")
	t.ok(not Wanted.disguised(st, "A-016"), "다시 목격되면 공고가 지금 옷으로 바뀐다")
	t.eq(int(st.call_fn("wanted", [5])), 56, "원고 함수 wanted(n)도 같은 길")
	st.vars.set_v("AFF_BJ", -10)                                     # SD-20 · §6.5: 등급 3은 하한이 아니라 −20을 넘어가는 순간
	Wanted.set_value(st, 35)
	st.call_fn("aff", ["BJ", -5])
	t.eq(Wanted.value(st), 35, "−15: 아직 −20 위 — 그대로")
	st.call_fn("aff", ["BJ", -10])
	t.eq(Wanted.value(st), 60, "2막 비상 −25로 넘어가는 순간 지명 수배(60)")
	st.call_fn("aff", ["BJ", -5])
	t.eq(Wanted.value(st), 60, "이미 −20 아래에서 더 내려가도 다시 올리지 않는다")


func test_clock_minutes(t) -> void:
	var st := _st()
	t.eq(Clock.add_minutes("2277. 10. 24.  07:10", 50, st), "2277. 10. 24.  08:00", "분 더하기")
	t.eq(Clock.add_minutes("2277. 10. 24.  23:50", 20, st), "2277. 10. 25.  00:10", "날 넘김")
	t.eq(int(st.vars.get_v("GAME_DAY")), 3, "날이 넘으면 GAME_DAY +1")
	t.eq(Clock.abs_min("2277. 10. 25.  00:10") - Clock.abs_min("2277. 10. 24.  23:50"), 20, "절대 분 차")
	t.ok(Clock.is_night("2277. 10. 24.  05:59") and not Clock.is_night("2277. 10. 24.  06:00") and Clock.is_night("2277. 10. 24.  20:00"),
		"밤 20~05시(SD-05 §5.1)")
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.date_text = "2277. 10. 24.  05:50"
	var ticks := [0]
	h.day_tick.connect(func(_d): ticks[0] += 1)
	h.advance_minutes(20)
	t.eq(ticks[0], 1, "06:00을 넘으면 하루 판정 1번")
	h.advance_minutes(60)
	t.eq(ticks[0], 1, "같은 날 다시는 없다")
	h.advance_minutes(24 * 60)
	t.eq(ticks[0], 2, "다음 날 06:00")
	var days := []                                                   # SD-20 P6: 사흘을 한 번에 보내도 하루 판정은 날마다, 그 날짜로
	h.day_tick.connect(func(d): days.append(d))
	var d0 := int(h.st.vars.get_v("GAME_DAY"))
	h.advance_minutes(3 * 24 * 60)
	t.eq(ticks[0], 5, "사흘 도약 = 하루 판정 세 번")
	t.eq(days, [d0 + 1, d0 + 2, d0 + 3], "날짜가 하나씩 오른 채로 차례대로")
	h.free()


func test_encounter_rules(t) -> void:
	var st := _st()
	var en := Encounters.new(st, 7)
	t.eq(Encounters.threat_at(Vector2i(959, 1503)), 2, "볼트 S-07 청크(C-23-37) 위협 2(SD-08 §14.3 격자)")
	t.eq(Encounters.threat_at(Vector2i(24 * 40 + 5, 1503)), 1, "옆 C-24-37 = 1(시작점 둘레 '1' 섬)")
	t.eq(Encounters.threat_at(Vector2i(80, 900)), 5, "서부(C-02-22) 위협 5")
	t.eq(Encounters.threat_at(Vector2i(5, 5)), 0, "놀이 밖 = 판정 없음")
	t.ok(Encounters.near_settlement(Vector2i(892, 1362)), "봉천 계단마을 = 정착지 반경(판정 없음)")
	t.ok(not Encounters.near_settlement(Vector2i(1100, 1500)), "멀리 떨어진 곳")
	t.ok(en.tracker_on(), "1막 = 새벽인력 생포 추적대(RE-087) 활성(수배 무관)")
	st.vars.set_v("MQ101_RESULT", 4)
	t.ok(not en.tracker_on(), "1막 독사 매수(MQ-101 해법 4) = 추적조 철수")
	st.vars.set_v("MQ101_RESULT", 1)
	st.vars.set_v("AFF_SB", 25)
	t.ok(not en.tracker_on(), "새벽인력 우호 이상이면 멈춘다")
	st.vars.set_v("AFF_SB", 0)
	# 주기: 위협 1~3은 3청크마다
	var row := 31 * 40 + 20                                          # C-14-31 ~ C-21-31: 위협 1~3, 정착지 밖
	var x0 := 14 * 40 + 20
	var hits := 0
	Encounters._site_grid = {Vector2i(-99, -99): []}                     # 주기 시험: 소장소(1-W)는 빼고 본다(다시 구우면 자리가 옮겨진다)
	en.on_move(Vector2i(x0, row), 0, false, "R01")                    # 첫 자리 잡기
	for i in range(1, 7):
		en.on_move(Vector2i(x0 + i * 40, row), 0, false, "R01")
	hits = en.trace.filter(func(r): return r["src"] == "move").size()
	t.eq(hits, 2, "청크 6개를 넘는 동안 판정 2번(3청크마다)")
	en.on_move(Vector2i(x0 + 6 * 40 + 5, row), 0, false, "R01")
	t.eq(en.trace.filter(func(r): return r["src"] == "move").size(), 2, "같은 청크 안에서는 판정 없음")
	# 안전 간격
	en.finished()
	var n0 := en.trace.size()
	for i in range(5, -1, -1):                                       # 되돌아 걷는다(경계 6번 = 판정 2번)
		en.on_move(Vector2i(x0 + i * 40, row), 0, false, "R01")
	t.eq(en.trace.slice(n0).filter(func(r): return r["re"] == "(안전 간격)").size(), 2, "RE가 끝나면 다음 2번은 건너뛴다")
	Encounters._site_grid = {}
	# 판정 성공 → 추적대 또는 기본 표(밤만 RE-004)
	var got := {}
	var en2 := Encounters.new(st, 11)
	for i in 400:
		var r := en2._roll("move", Vector2i(1100, row), 1.0, true, "R01")
		got[str(r.get("re", ""))] = int(got.get(str(r.get("re", "")), 0)) + 1
	t.ok(got.has("RE-087"), "밤 판정 성공 = 추적대 끼워 넣기(5%)")
	t.ok(got.size() >= 6, "밤 판정 성공 = 표에서 여러 RE가 나온다(정해진 것처럼 보이지 않게, SD-22): %s" % str(got.keys()))
	t.ok(int(got.get("RE-087", 0)) <= 1, "추적대는 하루 상한(1막 등급 1 = 1번)")
	t.ok(not got.has("RE-036") and not got.has("RE-057"), "낮에만 나오는 RE(떠돌이 고물상·혼자 온 신참)는 밤에 없다")
	var day_en := Encounters.new(st, 3)
	var day := {}
	for i in 300:
		day[day_en._base("R01", false)] = true
	t.ok(not day.has("RE-004") and not day.has("RE-125"), "낮에는 밤 RE(시체 뜯는 바퀴·밤의 구울) 없음")
	t.ok(not day.has("RE-064"), "R01에는 R02 전용 RE(인력 검문)가 없다")
	t.eq(Encounters.new(st, 5).units("RE-087", 3), ["CR-436", "CR-437", "CR-437"], "편성: 추심원 1 + 인솔조원 2(레벨 1~7)")
	t.eq(Encounters.new(st, 5).units("RE-087", 9).size(), 4, "레벨 구간이 오르면 인솔조원 +1(최대 3)")


func test_encounter_ep(t) -> void:
	var st := _st()
	Wanted.set_value(st, 35)                                          # 수배 2(EP-R01-06 조건)
	var en := Encounters.new(st, 1)
	var ep: Dictionary = {}
	for e in Encounters.data["ep"]:
		if e["id"] == "EP-R01-06":
			ep = e
	t.ok(not ep.is_empty() and ep["repeat"] and int(ep.get("wanted_min", 0)) == 2, "EP-R01-06 상도 언덕 = 추적대 스폰(반복, 수배 2+ 50%)")
	var at := Vector2i(int(ep["pos"][0]), int(ep["pos"][1]))
	en._ep_check(at + Vector2i(30, 0), 1000, false)
	en._ep_check(at, 1000, false)
	t.eq(int(st.enc["ep"].get("EP-R01-06", 0)), 1000, "들어서면 판정하고 시각을 적는다")
	var n := en.trace.size()
	en._ep_check(at + Vector2i(1, 0), 1100, false)
	t.eq(en.trace.size(), n, "안에 머무는 동안은 다시 판정하지 않는다")
	en._ep_check(at + Vector2i(30, 0), 1200, false)
	en._ep_check(at, 1200, false)
	t.eq(en.trace.size(), n, "72게임시간 안에는 다시 나와도 판정 없음")
	en._ep_check(at + Vector2i(30, 0), 1000 + 72 * 60, false)
	en._ep_check(at, 1000 + 72 * 60, false)
	t.eq(en.trace.size(), n + 1, "72시간 뒤 다시(SD-14 §11.3)")
	var d := GameSnapshot.story(st)
	var st2 := _st()
	GameSnapshot.apply_story(st2, JSON.parse_string(JSON.stringify(d)))
	t.eq(int(st2.enc["ep"]["EP-R01-06"]), 1000 + 72 * 60, "인카운터 상태 저장 왕복")


func test_capture_flow(t) -> void:
	var st := _st()
	st.quests.set_stage("MQ-101", 50)
	st.vars.set_v("MQ101_NIGHT", 3)
	st.vars.set_v("PC_CAPS", 101)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 24.  09:20"
	h.enter("W", "L-R01-15")
	var arr: Array = PlaceLog.db["L-R01-15"]["arrive"]                   # 도로·고가를 다시 구우면 도착 칸이 옮겨진다(SD-21 §8) — 장소 자료를 읽는다
	t.eq(h.map.tile_of(h.player.loco.logical), Vector2i(int(arr[0]), int(arr[1])), "월드 출구 표지 = 장소 L-ID의 도착 칸")
	t.ok(h.clock_running(), "MQ-101 아침 뒤 = 시간이 흐른다")
	var e: Enemy = h.combat.spawn("CR-436", h.player.loco.logical + Vector2(64, 0), h.map, st, {})
	e.set_meta("capture", "SB")
	var died := [0]
	h.pc_died.connect(func(): died[0] += 1)
	h.on_pc_down()
	t.eq(int(st.vars.get_v("PC_CAPS")), 71, "생포: 소지 캡 30% 압수(101 → 71, SD-03a §6.7)")
	t.eq(int(st.vars.get_v("CAPTURE_DAY")), 2, "오늘 잡혔다")
	await_frames(h)
	t.eq(h.map.id, "H-03", "새벽인력 본소 창고동 '인력' 우리에서 깬다")
	t.eq(int(st.vars.get_v("SB_CUFF")), 1, "수갑")
	t.eq(int(st.vars.get_v("SB_COLLAR")), 1, "근태 목걸이")
	t.eq(h.date_text, "2277. 10. 24.  12:20", "끌려가는 길 3시간")
	t.ok(h.map.is_solid(Vector2i(16, 8)), "우리 문은 닫혀 있다")
	h.ev.handlers["cage"].call(["open", "16", "8"], func() -> void: pass)
	t.ok(not h.map.is_solid(Vector2i(16, 8)), "우리 문을 열면 지나간다")
	var e2: Enemy = h.combat.spawn("CR-436", h.player.loco.logical + Vector2(64, 0), h.map, st, {})
	e2.set_meta("capture", "SB")
	h.on_pc_down()
	t.eq(died[0], 1, "같은 날 다시 쓰러지면 생포가 아니라 쓰러짐(하루 1번)")
	h.free()


## 연출 실행기의 페이드 콜백을 바로 끝낸다(시험용)
func await_frames(h: InteriorHost) -> void:
	for i in 40:
		h.ev._process(0.5)


## SD-22 §3.6 · §4.2 · §3.5 · §3.1: 조건 배수 · 지역 어울림 · 반복 피하기 · 상황 · 놓친 무리 기억
func test_encounter_variety(t) -> void:
	var st := _st()
	var en := Encounters.new(st, 21)
	en.ctx = {"road": 3, "move": "walk", "shot": 999.0, "hour": 12, "level": 1, "tags": ["큰길", "고가"]}
	t.eq(snappedf(en.global_mult(), 0.01), 1.3, "큰길·고가 위 ×1.3")
	en.ctx["road"] = 1
	en.ctx["move"] = "sneak"
	t.eq(snappedf(en.global_mult(), 0.01), 0.42, "골목 ×0.6 · 웅크림 ×0.7")
	en.ctx["shot"] = 10.0
	t.eq(snappedf(en.global_mult(), 0.01), 0.59, "30초 안 총성 ×1.4")
	var re002 := Encounters.re_def("RE-002")
	en.ctx["tags"] = ["고가"]
	t.eq(en.fit_mult(re002), 2.0, "고가 아래 패거리: 고가 태그 ×2(SD-22 §4.2)")
	en.ctx["tags"] = ["산지"]
	t.eq(en.fit_mult(re002), 0.0, "산지 금지 ×0")
	# 지역 어울림: 산지에서는 캠퍼스 들개, 고가 둘레에서는 패거리가 더 잦다
	var count := func(tags: Array, id: String) -> int:
		var e2 := Encounters.new(st, 5)
		e2.ctx = {"road": 2, "move": "walk", "shot": 999.0, "hour": 12, "level": 1, "tags": tags}
		var n := 0
		for i in 600:
			st.enc.erase("recent")
			if e2._pick("R01", false, Vector2i(-1, -1)) == id:
				n += 1
		return n
	t.ok(count.call(["산지"], "RE-001") > count.call(["업무"], "RE-001"), "캠퍼스 들개: 산지에서 더 잦고 업무지구엔 없다")
	t.eq(count.call(["산지"], "RE-002"), 0, "고가 아래 패거리는 산지에 없다")
	# 반복 피하기: 최근 6건 안 같은 RE ×0.25
	st.enc["recent"] = [["RE-X02", "S5"]]
	var e3 := Encounters.new(st, 9)
	e3.ctx = {"road": 2, "move": "walk", "shot": 999.0, "hour": 12, "level": 1, "tags": ["큰길"]}
	var a := 0
	var b := 0
	for i in 800:
		var r := e3._pick("R01", false, Vector2i(-1, -1))
		if r == "RE-X02":
			a += 1
		elif r == "RE-061":
			b += 1
	t.ok(a * 2 < b, "최근에 나온 교전(RE-X02)은 덜 나온다(×0.25): %d 대 계엄 분대 %d" % [a, b])
	# 같은 청크 12시간 안 = 다른 범주
	st.enc["recent"] = []
	st.enc["chunk"] = {"27,37": [100, "patrol"]}
	e3.now_min = 200
	var pats := 0
	for i in 200:
		if str(Encounters.re_def(e3._pick("R01", false, Vector2i(27 * 40 + 5, 37 * 40 + 5))).get("cat", "")) == "patrol":
			pats += 1
	t.eq(pats, 0, "같은 청크에서 12게임시간 안에는 같은 범주(순찰)가 다시 나오지 않는다")
	# 상황: 밤에는 야영·매복이 더 잦다
	var night_s4 := 0
	var day_s4 := 0
	st.enc["recent"] = []
	for i in 600:
		if e3.pick_state("RE-002", true) == "S4":
			night_s4 += 1
		if e3.pick_state("RE-002", false) == "S4":
			day_s4 += 1
	t.ok(night_s4 > day_s4, "밤에는 야영(S4) ×1.5: 밤 %d · 낮 %d" % [night_s4, day_s4])
	# 편성: 다친 개체(S5~S7) · 대장 확률
	var gs := e3.groups("RE-X02", 1, "S5")
	t.eq(gs.size(), 2, "교전 = 두 무리")
	t.ok(not bool(gs[0]["hostile"]) and bool(gs[1]["hostile"]), "계엄 분대(비적대) 대 패거리(적대)")
	# 놓친 무리 기억
	e3.remember_pack("RE-002", ["CR-420", "CR-423"])
	t.eq(e3.groups("RE-002", 1, "S1")[0]["ids"], ["CR-420", "CR-423"], "놓친 무리가 줄어든 인원 그대로 다시 나온다(SD-22 §3.5)")
	e3.remember_pack("RE-002", ["CR-420"])
	e3.remember_pack("RE-002", ["CR-420"])
	t.eq(e3.pick_state("RE-002", false), "S4", "세 번 놓치면 그 무리는 야영을 차린다")
	e3.remember_pack("RE-002", [])
	t.ok(not st.enc["packs"].has("RE-002"), "정리하면 잊는다")
	# 확률: 하한·상한 · 고요 누적
	st.enc["calm"] = 0.0
	st.enc["safe"] = 0
	var e4 := Encounters.new(st, 4)
	e4.ctx = {"road": 1, "move": "sneak", "shot": 999.0, "hour": 12, "level": 1, "tags": []}
	e4._roll("move", Vector2i(1100, 1250), 0.0001, false, "R01")
	t.eq(snappedf(float(e4.trace[-1]["p"]), 0.001), 0.03, "확률 하한 0.03")
	st.enc["calm"] = 0.0
	var fails := 0
	for i in 10:
		var r := e4._roll("move", Vector2i(1100, 1250), 0.0001, false, "R01")
		if r.is_empty():
			fails += 1
	t.ok(float(st.enc.get("calm", 0.0)) <= Encounters.CALM_MAX + 0.0001, "고요 누적 최대 +0.15")


## 표의 RE가 쓰는 대화 장면·사람 외형·적 자료가 실제로 있다(원고가 컴파일되지 않는 폴더에 있으면 대화가 영영 안 열린다 — 1-E에서 겪음)
func test_encounter_assets(t) -> void:
	var tab := Encounters.table()
	var enemies: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var missing: Array = []
	for id in tab:
		var d: Dictionary = tab[id]
		if str(d.get("talk", "")) != "" and not FileAccess.file_exists("res://data/dialogue/%s.json" % d["talk"]):
			missing.append("%s 대화 %s" % [id, d["talk"]])
		for g in d.get("groups", []):
			for u in g["units"]:
				if str(u[0]).begins_with("CR-") and not enemies.has(str(u[0])):
					missing.append("%s 적 %s" % [id, u[0]])
	for nid in Encounters.data.get("friendly_sheet", {}):
		var sh := str(Encounters.data["friendly_sheet"][nid])
		if not ResourceLoader.exists("res://assets/sprites/%s.tres" % sh):
			missing.append("외형 %s" % sh)
	for cr in ["cr420", "cr420b", "cr421", "cr421b", "cr423", "cr423b"]:
		if not ResourceLoader.exists("res://assets/sprites/en_%s_loco.tres" % cr):
			missing.append("외형 en_%s_loco" % cr)
	t.eq(missing, [], "RE 대화 장면·적 자료·외형 시트가 모두 있다")
	var st := _st()
	t.eq(st.npc_name("N-TRADER"), "떠돌이 고물상", "무명 화자 이름표")


## 원고 태그 [물건: ID n]이 이름으로 보인다(호스트가 아이템 이름을 이름 표에 채운다)
func test_item_tag_names(t) -> void:
	var st := _st()
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	t.ok(str(st.names.get("I-055", "I-055")) != "I-055", "I-055 → %s" % str(st.names.get("I-055", "")))
	t.ok(str(st.names.get("I-001", "I-001")) != "I-001", "I-001 → %s" % str(st.names.get("I-001", "")))
	h.free()


## 소장소 자리(1-W, SD-22 §5.2 ④): 반경 안에 처음 들어서면 그 자리의 RE · 72시간 안에는 다시 안 함 · 권역 밖 무리는 서지 않는다
func test_minisite_sites(t) -> void:
	var st := _st()
	Encounters.load_data()
	var sites: Array = Encounters.data.get("sites", [])
	t.ok(sites.size() > 100, "소장소 사람·크리처 자리 %d곳" % sites.size())
	var s0: Dictionary = {}
	for s_ in sites:
		if str(s_["re"]) == "RE-002":
			s0 = s_
			break
	t.ok(not s0.is_empty(), "패거리 야영 자리가 있다")
	var en := Encounters.new(st, 3)
	en.rng.seed = 3
	var at := Vector2i(int(s0["x"]), int(s0["y"]))
	var got := {}
	for i in 12:                                                       # 처음 들어설 때만 판정(80%) — 여러 번 들락날락
		Encounters._site_grid.clear()
		var e2 := Encounters.new(_st(), 100 + i)
		var r := e2._site_check(at + Vector2i(10, 0), 1000, true, "R01")
		got[str(r.get("re", ""))] = true
		if not r.is_empty():
			t.eq(r.get("at"), at, "그 자리에 세운다")
	t.ok(got.has("RE-002"), "패거리 야영이 선다")
	var r1 := en._site_check(at + Vector2i(10, 0), 1000, true, "R01")
	en._site_check(at + Vector2i(40, 0), 1100, true, "R01")
	var r2 := en._site_check(at + Vector2i(10, 0), 1200, true, "R01")
	t.ok(r2.is_empty(), "72게임시간 안에는 다시 서지 않는다")
	var e3 := Encounters.new(_st(), 5)
	t.ok(e3._site_check(at + Vector2i(10, 0), 1000, true, "R09").is_empty(), "권역 밖(R09)이면 빈 야영지로 둔다")
