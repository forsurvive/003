## 1-12m: 서울의 판도(R01 · R02) — 시작 판 · 원천 변수 차이 · 감쇠 · 지도자 처리 · 거점 이전 · 아는 판 · 저장 · 가맹 · 세력 기록
extends RefCounted


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 1)
	return st


func _s(st: StoryState, z: String) -> int:
	st.turf.sync(st)
	return int(st.turf.state_of(st, z)["s"])


func _a(st: StoryState, z: String) -> String:
	st.turf.sync(st)
	return str(st.turf.state_of(st, z)["a"])


func test_turf_start(t) -> void:
	var st := _st()
	var want := {"PD-R01-1": [0, ""], "PD-R01-2": [2, "JC"], "PD-R01-3": [2, "YT"], "PD-R01-4": [2, "BJ"], "PD-R01-5": [2, "GS"],
		"PD-R01-6": [1, "YT"], "PD-R02-1": [1, "BJ"], "PD-R02-2": [2, "JH"], "PD-R02-3": [1, "YT"], "PD-R02-4": [3, "SB"], "PD-R02-5": [2, "SB"]}
	t.eq(Turf.zones().size(), 11, "R01 6 + R02 5 구역")
	for z in want:
		t.eq(_s(st, z), int(want[z][0]), "%s 시작 상태(SD-08 §15.2)" % z)
		t.eq(_a(st, z), str(want[z][1]), "%s 시작 1위" % z)
		var k := Turf.vkey(z)
		t.eq(int(st.vars.get_v("PDS_" + k)), int(want[z][0]), "%s 상태 변수 = 기본값과 같음(첫 계산 전에도 방송 조건이 맞게)" % z)
	t.eq(Turf.zone_at(Vector2i(849, 1428)), "PD-R01-3", "신림 고시촌 칸")
	t.eq(Turf.zone_at(Vector2i(632, 1329)), "PD-R02-4", "새벽인력 본소 칸")
	t.eq(Turf.zone_at(Vector2i(1500, 600)), "", "판도 틀 밖(R08)")


func test_turf_sources(t) -> void:
	var st := _st()
	st.vars.set_v("PD_R01_6", 10)                                       # 가산 작업복 상자 넘김(+새벽 −약탈)
	t.eq(_a(st, "PD-R01-6"), "SB", "가산 +10: 새벽인력이 1위")
	t.eq(_s(st, "PD-R01-6"), 2, "가산 +10: 우세(새벽 25 · 약탈 10)")
	t.eq(str(st.vars.get_v("PDO_R01_6")), "SB", "이야기 변수")
	st.turf.sync(st)
	st.turf.sync(st)
	t.eq(int(st.turf.ev["PD-R01-6"]["SB"]), 10, "같은 원천 값은 두 번 더하지 않는다(P9)")
	st.vars.set_v("PD_R01_6", 5)                                        # 원천이 줄면 차이만큼 뺀다
	st.turf.sync(st)
	t.eq(int(st.turf.ev["PD-R01-6"]["SB"]), 5, "원천 감소 = 차이만큼")
	st.vars.set_v("PD_R01_BJ", 10)                                      # MQ-106 관악 검문소 상설화 = R01 전 구역 BJ +10
	t.eq(_a(st, "PD-R01-1"), "BJ", "관악산 북사면: 계엄군 우세")
	t.eq(_s(st, "PD-R01-1"), 2, "BJ 20 · YT 10")
	t.eq(int(st.turf.ev["PD-R02-1"].get("BJ", 0)) if st.turf.ev.has("PD-R02-1") else 0, 0, "R01 사건은 R02에 번지지 않는다")


func test_turf_decay(t) -> void:
	var st := _st()
	st.vars.set_v("PD_R01_6", 10)
	st.turf.day(st, 1)
	for d in range(2, 9):
		st.vars.set_v("GAME_DAY", d)
		st.turf.day(st, d)
	t.eq(int(st.turf.ev["PD-R01-6"]["SB"]), 8, "7일 뒤 0 쪽으로 2(SD-06 §5.2)")
	t.eq(int(st.turf.ev["PD-R01-6"]["YT"]), -8, "음수도 0 쪽으로")
	t.eq(int(st.vars.get_v("PD_R01_6")), 10, "원천 변수는 누적 사실로 남는다")


func test_turf_ledger_leader(t) -> void:
	var st := _st()
	st.quests.set_stage("MQ-105", 100)
	st.vars.set_v("HO_LEDGER", 81)                                      # 장부를 봉천에
	t.eq(_s(st, "PD-R02-4"), 2, "구로 · 가리봉: 지배 → 우세(새벽 50 − 30)")
	t.eq(_s(st, "PD-R02-5"), 0, "고척: 새벽 −30 → 공백")
	t.eq(_a(st, "PD-R02-1"), "BJ", "여의도: 새벽이 빠져 계엄군")
	st.kill("C-013")
	st.turf.sync(st)
	t.eq(int(st.turf.ev["PD-R02-4"]["SB"]), -30, "장부 −30 + 지도자 −20은 ±30에서 자른다")
	t.ok(st.turf.fx.has("HDC"), "지도자 처리는 한 번(표지)")
	st.turf.sync(st)
	t.eq(int(st.turf.ev["PD-R02-4"]["SB"]), -30, "다시 읽어도 그대로")
	t.eq(int(st.turf.ev["PD-R01-6"]["SB"]), -20, "새벽 순찰이 있는 R01 구역에도 지도자 처리")
	var st2 := _st()
	st2.vars.set_v("HO_LEDGER", 1)                                      # 비상정부에 — 판도 변화 없음(5막 몫)
	t.eq(_s(st2, "PD-R02-4"), 3, "장부를 비상정부에: 구로는 그대로 지배")


func test_turf_nodes(t) -> void:
	var st := _st()
	st.vars.set_v("SQ_S02_CAMP", 1)                                     # 삽자루 처치 — 은신처가 빈다
	t.eq(st.turf.node_owner(st, "N-R01-6"), "", "신림 은신처 공백")
	t.eq(_s(st, "PD-R01-3"), 0, "본거지 순찰 20 → 10: 신림이 공백(재미 검수 ①)")
	st.vars.set_v("PD_R02_KH", 1)                                       # 국회 폐허 → BJ
	t.eq(st.turf.node_owner(st, "N-R02-6"), "BJ", "국회 폐허 BJ")
	t.eq(_s(st, "PD-R02-1"), 2, "여의도: BJ 우세(40 · 25)")
	t.eq(Turf.locked(st, "N-R01-7"), false, "송신소 잠금 전")
	st.vars.set_v("SQ_S04_PD_LOCK", 1)
	t.eq(Turf.locked(st, "N-R01-7"), true, "S04 E: 송신소 공백 고정(D-135)")
	var st3 := _st()
	st3.quests.set_stage("MQ-103", 100)
	t.eq(_s(st3, "PD-R02-2"), 3, "MQ-103: 영등포 지하시장 +5 → 지배(D-132)")


func test_turf_known(t) -> void:
	var st := _st()
	t.ok(st.turf.known_of("PD-R01-3").is_empty(), "처음엔 모른다")
	t.eq(st.turf.line_of(st, "PD-R01-3").begins_with("알 수 없음"), true, "모르는 구역 서술")
	var msg := st.turf.see(st, Vector2i(849, 1428))
	t.eq(msg, "", "처음 본 구역은 알림 없음")
	t.eq(int(st.turf.known_of("PD-R01-3")["s"]), 2, "본 판")
	t.ok(st.turf.line_of(st, "PD-R01-3").contains("망꾼"), "우세 YT 손 서술")
	st.vars.set_v("SQ_S02_CAMP", 1)
	st.vars.set_v("GAME_DAY", 3)
	t.eq(int(st.turf.known_of("PD-R01-3")["s"]), 2, "가 보기 전엔 옛 판")
	t.eq(st.turf.age_of(st, "PD-R01-3"), "2일 전 정보", "오래된 정보 꼬리표")
	msg = st.turf.see(st, Vector2i(849, 1428))
	t.ok(msg.contains("깃발이 바뀌어"), "알던 판과 다르면 알림(재미 검수 ③)")
	t.eq(int(st.turf.known_of("PD-R01-3")["s"]), 0, "고쳐 적음")
	t.eq(int(st.turf.known_of("PD-R01-3")["chg"]), 3, "↻ 날짜")
	st.turf.hear_block(st, "N-PD-R02-4-HDC")
	t.ok(not st.turf.known_of("PD-R02-4").is_empty(), "방송 블록 ID로 구역을 안다")
	t.eq(st.turf.use_of(st, "PD-R01-3"), "짐승과 떠돌이 패거리를 만나기 쉽다", "공백 한 마디(서술 '졸개들뿐'과 어긋나지 않게)")


func test_turf_price_enc(t) -> void:
	var st := _st()
	st.quests.set_stage("MQ-103", 100)
	st.turf.sync(st)
	st.vars.set_v("AFF_JH", 25)
	t.near(st.turf.price_k(st, "PD-R02-2"), 0.95, 0.001, "지배 세력 우호 → −5%")
	st.vars.set_v("AFF_JH", -30)
	t.near(st.turf.price_k(st, "PD-R02-2"), 1.10, 0.001, "경계 → +10%")
	t.near(st.turf.price_k(st, "PD-R01-3"), 1.0, 0.001, "지배가 아니면 그대로")
	var e := Encounters.new()
	e.st = st
	Encounters.load_data()
	var tb: Dictionary = e._cat_table("R02", Vector2i(720, 1149))
	t.eq(int(tb.get("dom", 0)), 40, "지배 구역: 지배 세력 순찰 40(SD-05 §6.3)")
	var tb2: Dictionary = e._cat_table("R01", Vector2i(849, 1428))
	t.eq(int(tb2.get("dom", 0)), 0, "약탈자 우세: 순찰 몫을 약탈자로")
	t.ok(float(tb2.get("raider", 0)) >= 37.0, "약탈자 7 + 30")


func test_turf_save(t) -> void:
	var st := _st()
	st.vars.set_v("PD_R01_6", 10)
	st.turf.see(st, Vector2i(849, 1428))
	st.turf.day(st, 1)
	var d := GameSnapshot.story(st)
	var st2 := _st()
	GameSnapshot.apply_story(st2, d)
	t.eq(st2.turf.to_dict(), st.turf.to_dict(), "판도 장부 저장 왕복")
	st2.turf.sync(st2)
	t.eq(int(st2.turf.ev["PD-R01-6"]["SB"]), 10, "불러온 뒤 다시 더하지 않는다")
	var st3 := _st()
	st3.vars.set_v("PD_R01_6", 10)
	GameSnapshot.apply_story(st3, {"vars": st3.vars.dump()})          # 옛 저장(판도 장부 없음): 원천 합을 한 번에
	st3.turf.sync(st3)
	t.eq(int(st3.turf.ev["PD-R01-6"]["SB"]), 10, "옛 저장 이식")


func test_turf_join_book(t) -> void:
	var st := _st()
	st.vars.set_v("SQ_S05_SOL", 1)
	st.vars.set_v("AFF_JC_SA", 12)
	var notes: Array = st.turf.day(st, 1)
	t.eq(int(st.vars.get_v("SA_JOIN")), 0, "사당 호감 20 전엔 가맹 없음")
	t.eq(int(st.turf.ev["PD-R01-4"]["SA"]), 3, "교역로 PD-R01-4 +3(D-136)")
	st.vars.set_v("AFF_JC_SA", 22)
	notes = st.turf.day(st, 2)
	t.eq(int(st.vars.get_v("SA_JOIN")), 1, "가맹 사건")
	t.eq(notes.size(), 1, "세력 기록 한 줄")
	t.eq(Turf.group(st, "SA"), "JC", "가맹 뒤 사당 = 정착지 연합")
	var fb := st.fbook
	fb.refresh(st, "2277. 10. 24.  09:00")
	t.ok(fb.registered("BJ"), "볼트를 나서면 계엄군 등록")
	t.ok(not fb.registered("WP"), "원칙파는 아직 모른다")
	st.deeds.heard.push_front({"fac": "JC_BC", "what": "봉천 물탱크를 고쳤다", "at": 1440 * 300 + 600, "route": "목격", "tag": ""})
	fb.refresh(st, "2277. 10. 28.  09:00")
	t.ok(fb.registered("JC_BC") and fb.registered("JC"), "소식이 닿은 정착지 · 연합 등록")
	t.eq(str(fb.lines_of("JC")[0]["text"]), "봉천 물탱크를 고쳤다", "최근 일(연합 줄에 정착지 것도)")
	t.ok(fb.any_unread(), "• 읽지 않음")
	fb.read("JC")
	t.ok(not fb.unread.has("JC_BC"), "연합을 읽으면 아래 정착지도")
	st.vars.set_v("AFF_JC_BC", 25)
	fb.refresh(st, "2277. 10. 28.  10:00")
	t.eq(int(fb.stage["JC_BC"]), 3, "우호로 오름(바로)")
	st.vars.set_v("AFF_JC_BC", 17)
	fb.refresh(st, "2277. 10. 28.  11:00")
	t.eq(int(fb.stage["JC_BC"]), 3, "하한 −5 안: 그대로(히스테리시스)")
	st.vars.set_v("AFF_JC_BC", 14)
	fb.refresh(st, "2277. 10. 28.  12:00")
	t.eq(int(fb.stage["JC_BC"]), 2, "+14 이하 → 중립")
	t.ok(str(fb.lines_of("JC_BC")[0]["text"]) != "", "단계가 바뀐 날 한 줄")
	st.vars.set_v("AFF_BJ", -22)
	t.ok(fb.relation_line(st, "BJ").contains("전단을 떼어"), "경계 ±5: 기울고 있음 문장")
	t.eq(Clock.md(Clock.abs_min("2277. 10. 25.  14:32")), "10. 25.", "날짜 거꾸로")


func test_turf_tick_kill(t) -> void:
	var st := _st()
	st.check_seed = 4242
	for d in range(1, 64):                                              # 두 달: 공백 관악산 북사면에 약탈자가 차오르지 않는다(크리처 산)
		st.vars.set_v("GAME_DAY", d)
		st.turf.day(st, d)
	t.eq(_s(st, "PD-R01-1"), 0, "관악산 북사면은 두 달 뒤에도 공백(재미 검수 ②)")
	t.eq(int(st.turf.ev.get("PD-R01-1", {}).get("YT", 0)), 0, "약탈자 +1 제외")
	var outs := {}
	for seed in [1, 2, 3, 4, 5, 6, 7, 8]:                               # 가산 경합: 씨앗마다 굴림 — 늘 같은 결말이 아니다
		var s2 := _st()
		s2.check_seed = seed
		for d in range(1, 13):
			s2.vars.set_v("GAME_DAY", d)
			s2.turf.day(s2, d)
		outs[_a(s2, "PD-R01-6") + str(_s(s2, "PD-R01-6"))] = true
	t.ok(outs.size() >= 2, "가산 판도 틱 결말이 씨앗마다 갈린다 %s" % str(outs.keys()))
	var s3 := _st()
	s3.check_seed = 77
	var s4 := _st()
	s4.check_seed = 77
	for d in range(1, 10):
		s3.vars.set_v("GAME_DAY", d)
		s3.turf.day(s3, d)
		s4.vars.set_v("GAME_DAY", d)
		s4.turf.day(s4, d)
	t.eq(s3.turf.ev, s4.turf.ev, "같은 씨앗 = 같은 판(불러와도 같다)")
	var s5 := _st()
	for i in 5:
		s5.turf.note_kill(s5, Vector2i(660, 1460), "YT")                  # 가산에서 패거리 다섯
	t.eq(int(s5.turf.ev["PD-R01-6"]["YT"]), -3, "구역 안 처치는 하루 3까지 −1씩")
	s5.vars.set_v("GAME_DAY", 2)
	s5.turf.note_kill(s5, Vector2i(660, 1460), "YT")
	t.eq(int(s5.turf.ev["PD-R01-6"]["YT"]), -4, "다음 날 다시")
	t.eq(_s(s5, "PD-R01-6"), 0, "패거리를 쫓아내면 가산 경합이 무너진다(약탈 16 · 새벽 15 = 공백)")
	var s6 := _st()
	s6.vars.set_v("SQ_S02_CAMP", 1)
	s6.turf.ev["PD-R01-3"] = {"YT": 12}
	s6.turf.see(s6, Vector2i(849, 1428))
	t.eq(_a(s6, "PD-R01-3"), "YT", "은신처가 빈 뒤 약탈자가 다시 1위")
	t.ok(s6.turf.line_of(s6, "PD-R01-3").contains("새 두목"), "빈 망루 서술(새 두목 판)")


func test_turf_auth_tracked(t) -> void:
	var st := _st()
	st.vars.set_v("V_ACT", 2)
	st.vars.set_v("V_WANTED", 40)                                       # 2막 하한(30) 위에서 센다
	st.turf.sync(st)
	t.eq(Wanted.tracked(st), false, "여의도 경합: 관측소 없음")
	var v0 := Wanted.value(st)
	Wanted.add(st, 3, "auth")
	t.eq(Wanted.value(st) - v0, 3, "인증 +3")
	st.vars.set_v("PD_R02_KH", 1)
	st.turf.sync(st)
	t.eq(Wanted.tracked(st), true, "2막 · 국회 BJ → 여의도 BJ 우세 → 금탑 관측소(D-219)")
	var v1 := Wanted.value(st)
	Wanted.add(st, 3, "auth")
	t.eq(Wanted.value(st) - v1, 6, "관측소가 있으면 한 단 더(+6)")
	Wanted.add(st, 3, "auth")
	t.eq(Wanted.value(st) - v0, 9, "하루 상한 +9는 그대로")
	st.vars.set_v("V_ACT", 1)
	t.eq(Wanted.tracked(st), false, "1막엔 관측소 없음(KT-06 조건과 같게)")
