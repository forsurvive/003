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
	# 판정 성공 → 추적대 또는 기본 표(밤만 RE-004)
	var got := {}
	var en2 := Encounters.new(st, 11)
	for i in 400:
		var r := en2._roll("move", Vector2i(1100, row), 1.0, true, "R01")
		got[str(r.get("re", ""))] = int(got.get(str(r.get("re", "")), 0)) + 1
	t.ok(got.has("RE-087") and got.has("RE-004"), "밤 판정 성공 = 추적대 끼워 넣기(5%) 또는 기본 표 RE-004")
	t.ok(int(got.get("RE-087", 0)) <= 1, "추적대는 하루 상한(1막 등급 1 = 1번)")
	var day_en := Encounters.new(st, 3)
	t.eq(day_en._base("R01", false), "", "낮에는 RE-004(밤) 없음")
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
	t.eq(h.map.tile_of(h.player.loco.logical), Vector2i(833, 1343), "월드 출구 표지 = 장소 L-ID의 도착 칸")
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
