## 서류 UI 규칙 (단계 0-4): 이름 입력(SD-18 §9.1.4), S.P.E.C.I.A.L. 배분·담임 의견·파생 수치(SD-10 §2.3·§2.6),
## 적성 채점·동점 규칙·10-④(SD-03a §7.3), 서류 화면의 조작(헤드리스, 그리지 않고 조작 함수만).
extends RefCounted


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	return st


func test_data(t) -> void:
	var d := CharDocs.load_data()
	t.eq(d["record"].size(), 7, "생활기록부 7항목")
	t.eq(d["aptitude"].size(), 10, "적성 10문항")
	t.eq(d["jobs"].size(), 13, "직무 13")
	t.eq(d["ksx1001"].length(), 2350, "KS X 1001 완성형 2,350자")
	t.eq(CharDocs.record_item("LK"), "특기 사항", "행운 = 특기 사항")
	t.eq(CharDocs.job("REPAIR")["job"], "배관 정비원", "수리 → 배관 정비원")


func test_name(t) -> void:
	t.eq(CharDocs.check_name("윤", "서진"), "", "기본 이름")
	t.eq(CharDocs.check_name("남궁", "하윤아"), "", "두 글자 성 + 세 글자 이름")
	t.ok(CharDocs.check_name("", "서진") != "", "성 없음")
	t.ok(CharDocs.check_name("제갈공", "명") != "", "성 3자")
	t.ok(CharDocs.check_name("윤", "가나다라마") != "", "이름 5자")
	t.ok(CharDocs.check_name("윤", "") != "", "이름 없음")
	t.eq(CharDocs.check_name("윤", "Seo"), "한글 완성형 글자만 등록할 수 있습니다.", "로마자 거부")
	t.eq(CharDocs.check_name("윤", "서 진"), "한글 완성형 글자만 등록할 수 있습니다.", "공백 거부")
	t.eq(CharDocs.check_name("윤", "똠이"), "한글 완성형 글자만 등록할 수 있습니다.", "KS X 1001 밖 글자(똠)")
	t.eq(CharDocs.check_name("강", "태오"), "등록할 수 없는 이름입니다.", "금칙 명칭(옛 이름)")
	t.eq(CharDocs.check_name("병", "신"), "등록할 수 없는 이름입니다.", "금칙 표현")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		t.eq(CharDocs.check_name(CharDocs.default_surname(), CharDocs.random_given(CharDocs.SEX_F, rng)), "", "무작위 이름은 늘 통과")
	t.ok(CharDocs.data["names"]["male"].has(CharDocs.random_given(CharDocs.SEX_M, rng)), "남 풀")


func test_special(t) -> void:
	var s := CharDocs.default_stats()
	t.eq(CharDocs.points_left(s), 5, "기본 5씩 + 남은 5")
	for i in 5:
		t.ok(CharDocs.can_raise(s, "IN"), "올릴 수 있다 %d" % i)
		s["IN"] += 1
	t.eq(CharDocs.points_left(s), 0, "다 썼다")
	t.ok(not CharDocs.can_raise(s, "IN") and not CharDocs.can_raise(s, "ST"), "남은 점수 0이면 못 올린다")
	t.ok(not CharDocs.can_raise(s, "IN"), "10 위로 못 올린다")
	for i in 4:
		s["LK"] -= 1
	t.ok(not CharDocs.can_lower(s, "LK"), "1 아래로 못 내린다")
	t.eq(CharDocs.points_left(s), 4, "내리면 남은 점수 +1")
	t.eq(CharDocs.comment("ST", 1), "급식판을 두 손으로 듭니다.", "1~2 구간")
	t.eq(CharDocs.comment("ST", 2), CharDocs.comment("ST", 1), "2도 1~2 구간")
	t.eq(CharDocs.comment("PE", 7), "환기구 소리가 바뀐 것을 먼저 알아챘습니다.", "7~8 구간")
	t.eq(CharDocs.comment("LK", 10), "배급 추첨 3회 연속 1번. 조사 중.", "9~10 구간")
	var d5 := CharDocs.derived(CharDocs.default_stats())
	t.eq(d5, {"hp": 200, "ap": 75, "carry": 200, "detect": 13, "skill_pts": 15}, "능력치 5 기준값(SD-10 §2.4 표)")
	var ten := {}
	for c in CharDocs.ORDER:
		ten[c] = 10
	t.eq(CharDocs.derived(ten), {"hp": 300, "ap": 85, "carry": 250, "detect": 18, "skill_pts": 20}, "능력치 10(§2.4 표)")
	var sk := CharDocs.base_skills(CharDocs.default_stats())
	t.eq(sk.size(), 13, "스킬 13")
	t.eq(sk["SPEECH"], 15, "능력치 5 · 행운 5 → 15(§3.3 조견표)")
	var one := {"ST": 1, "PE": 1, "EN": 1, "CH": 1, "IN": 10, "AG": 1, "LK": 1}
	t.eq(CharDocs.base_skills(one)["SCIENCE"], 23, "지능 10 · 행운 1 → 23")
	t.eq(CharDocs.base_skills(one)["SNEAK"], 5, "최솟값 5")


func test_aptitude(t) -> void:
	var a := [1, 1, 2, 3, 1, 1, 4, 2, 4, 1]
	var sc := CharDocs.score(a)
	t.eq(sc["REPAIR"], {"score": 3, "last": 9}, "수리 3점(2·6·9번)")
	t.eq(CharDocs.recommend(a), ["REPAIR", "SCIENCE", "SMALL_GUNS"], "1점 동점이면 더 나중 문항(10번 소형 화기)")
	a[9] = 4
	t.eq(CharDocs.score(a).has(""), false, "10-④는 점수 없음")
	t.eq(CharDocs.recommend(a), ["REPAIR", "SCIENCE", "SPEECH"], "10-④면 1~9번만: 화술(8번)이 3위")
	var all1 := [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
	t.eq(CharDocs.recommend(all1), ["SMALL_GUNS", "MEDICINE", "BIG_GUNS"], "2점 동점 셋: 9번 의학 > 7번 중화기 > 6번 수리")
	all1[9] = 4
	t.eq(CharDocs.recommend(all1), ["MEDICINE", "SMALL_GUNS", "BIG_GUNS"], "소형 화기가 2점으로 내려가면 의학(9번)이 1위")
	t.eq(CharDocs.ranking([]).slice(0, 3), ["BARTER", "BIG_GUNS", "ENERGY"], "응답 없음: 스킬 목록 순서")
	# 모든 답 조합이 늘 13스킬 순위를 낸다(무작위 200조)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ok := true
	for n in 200:
		var r := []
		for i in 10:
			r.append(rng.randi_range(1, 4))
		var rk := CharDocs.ranking(r)
		var s := CharDocs.score(r)
		ok = ok and rk.size() == 13 and int(s.get(rk[0], {"score": 0})["score"]) >= int(s.get(rk[1], {"score": 0})["score"])
	t.ok(ok, "무작위 응답 200조 순위 일관")


func test_state_roundtrip(t) -> void:
	var st := _st()
	CharDocs.write_name(st, "한", "서진")
	t.eq(st.vars.get_v("P_FULL"), "한서진", "P_FULL")
	t.eq(st.vars.get_v("P_REGNO"), "S07-2258-0031", "등록번호")
	CharDocs.write_look(st, {"sex": CharDocs.SEX_M, "hair": "HR01", "hcol": "H3", "skin": "S5"})
	t.eq(CharDocs.paperdoll_look(CharDocs.look_of(st))["body"], "M1", "남 → M1 몸")
	CharDocs.write_aptitude(st, [1, 2, 3, 4, 1, 2, 3, 4, 1, 3])
	t.eq(st.vars.get_v("V_Q10"), 3, "V_Q10 = 10번 답")
	t.eq(CharDocs.aptitude_of(st), [1, 2, 3, 4, 1, 2, 3, 4, 1, 3], "답 다시 읽기")
	CharDocs.write_tags(st, ["REPAIR", "SCIENCE", "SPEECH"])
	t.eq(st.skill("REPAIR"), 30, "태그 +15")
	var d := st.dump()
	var st2 := _st()
	st2.restore(d)
	t.eq(CharDocs.tags_of(st2), ["REPAIR", "SCIENCE", "SPEECH"], "저장 왕복")


func test_screens(t) -> void:
	var st := _st()
	var rb: RecordBook = RecordBook.new().setup(st)
	rb._press("ok")
	t.eq(rb.signed_at, -1.0, "남은 점수가 있으면 확정 안 됨")
	for i in 3:
		rb._adjust("IN", 1)
	rb._adjust("ST", -1)
	for i in 3:
		rb._adjust("PE", 1)
	t.eq(CharDocs.points_left(rb.stats), 0, "배분 끝")
	rb._adjust("PE", 1)
	t.eq(rb.stats["PE"], 8, "남은 점수 0이면 더 안 오른다")
	rb._press("undo")
	t.eq(rb.stats["PE"], 7, "되돌리기 한 칸")
	rb._adjust("PE", 1)
	rb._press("ok")
	t.eq(st.vars.get_v("PC_IN"), 8, "확정하면 이야기 상태에 적힌다")
	rb.free()

	var ac: AptitudeCard = AptitudeCard.new().setup(st)
	for i in 10:
		ac._press("opt%d" % (i % 4))
		ac._busy_done()
	t.eq(ac.answers, [1, 2, 3, 4, 1, 2, 3, 4, 1, 2], "답 10개, 칠하면 다음 문항")
	ac._press("row3")
	t.eq(ac.q, 3, "카드의 행을 누르면 그 문항")
	ac._press("submit")
	t.eq(st.vars.get_v("V_Q10"), 2, "제출 → V_Q10")
	ac.free()

	var rs: ResultSheet = ResultSheet.new().setup(st)
	t.eq(rs.picks, CharDocs.recommend(ac_answers(st)), "추천 3개가 미리 체크")
	var extra: String = StoryState.SKILL_ORDER.filter(func(k): return not k in rs.picks)[0]
	rs._press(extra)
	t.eq(rs.picks.size(), 3, "4번째는 못 고른다")
	rs._press(rs.picks[0])
	rs._press(extra)
	rs._press("ok")
	t.ok(extra in CharDocs.tags_of(st), "바꾼 태그 확정")
	rs.free()

	var rt: RegisterTerminal = RegisterTerminal.new().setup(st, "birth", 11)
	rt.sur_edit.text = "윤"
	rt.given_edit.text = "abc"
	rt._press("ok")
	t.ok(rt.error != "" and rt.submit_at < 0.0, "잘못된 이름이면 신고 안 됨")
	rt.given_edit.text = "하린"
	rt._adjust("sex", 1)
	rt._adjust("hair", 1)
	rt._press("ok")
	t.ok(rt.submit_at >= 0.0, "신고")
	t.eq(st.vars.get_v("P_FULL"), "윤하린", "성명 기록")
	t.eq(st.vars.get_v("PC_SEX"), CharDocs.SEX_M, "성별 기록(여 → 남)")
	rt.free()

	var skin_before: String = st.vars.get_v("PC_SKIN")
	var ex: RegisterTerminal = RegisterTerminal.new().setup(st, "exit", 5)
	ex.given_edit.text = "바뀜"
	ex._adjust("skin", 1)
	ex._commit_name()
	CharDocs.write_look(st, ex.look)
	ex._press("keep")
	t.eq(st.vars.get_v("P_FULL"), "윤하린", "[변경 없음]은 열 때 상태로 되돌린다")
	t.ok(ex.look["skin"] != skin_before, "점검표에서 피부를 바꿨었다")
	t.eq(st.vars.get_v("PC_SKIN"), skin_before, "외형도 되돌림")
	ex.free()


func ac_answers(st: StoryState) -> Array:
	return CharDocs.aptitude_of(st)
