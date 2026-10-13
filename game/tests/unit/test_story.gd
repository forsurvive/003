## 단계 0-1 이야기 핵심: 식 언어(파이썬 판과 대조), 변수 저장소, 퀘스트 단계, 화술 확률(SD-10 §3.5.8), 텍스트 제어 코드(SD-12 §14.1),
## 대화 실행기(원고 변환기가 만든 MQ-P1 장면을 끝까지), 저장 왕복.
extends RefCounted


class Env:
	extends RefCounted
	var d := {}

	func get_var(n: String) -> Variant:
		return d.get(n)

	func set_var(n: String, v: Variant) -> bool:
		d[n] = v
		return true

	func call_fn(_n: String, _a: Array) -> Variant:
		return null


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	st.vars.set_v("P_SURNAME", "윤")
	st.vars.set_v("P_GIVEN", "서윤")
	st.vars.set_v("P_REGNO", "S07-2258-0031")
	return st


func test_expr_matches_python(t) -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/expr_cases.json"))["cases"]
	t.ok(cases.size() >= 20, "사례 수")
	for c in cases:
		var e := Env.new()
		for k in c["env"]:
			e.d[k] = c["env"][k] if c["env"][k] is String else int(c["env"][k])
		var p := StoryExpr.parse(c["src"])
		t.ok(p["ok"], "구문 " + c["src"])
		var v = null
		for s in p["ast"].slice(1):
			v = StoryExpr._eval(s, e)
		var want = c["value"] if c["value"] is String else int(c["value"])
		t.eq(v, want, c["src"])
		for k in c["after"]:
			var w = c["after"][k] if c["after"][k] is String else int(c["after"][k])
			t.eq(e.d[k], w, c["src"] + " 뒤 " + k)


func test_expr_errors(t) -> void:
	for bad in ["V_ACT >=", "(1 + 2", "V_ACT in 3", "\"abc", "1 2", "V_ACT @ 3"]:
		t.ok(not StoryExpr.parse(bad)["ok"], "구문 오류여야 함: " + bad)
	t.eq(StoryExpr.names_in("V_A == 1 and has(\"X\") or V_B in [V_C, 2]; V_D += 1"), ["V_A", "V_B", "V_C", "V_D"], "변수 모으기")
	var e := Env.new()
	t.eq(StoryExpr.test("", e), true, "빈 조건은 참")


func test_var_store(t) -> void:
	var v := VarStore.new()
	v.declare("A", "int", 5)
	v.declare("S", "str", "")
	t.eq(v.get_v("A"), 5, "기본값")
	t.ok(v.set_v("A", 7), "쓰기")
	t.eq(v.dump(), {"A": 7}, "기본값과 다른 값만 저장")
	v.set_v("A", 5)
	t.eq(v.dump(), {}, "기본값으로 돌아가면 저장에서 빠짐")
	t.ok(not v.set_v("NOPE", 1), "미선언 쓰기 거부")
	t.eq(v.get_v("NOPE"), null, "미선언 읽기 null")
	t.eq(v.errors.size(), 2, "오류 기록")
	t.ok(not v.set_v("A", "abc"), "정수 변수에 문자열 거부")
	t.eq(v.add("A", 200, 0, 100), 100, "더하기 상한")
	v.set_v("S", "서윤")
	var d := v.dump()
	var w := VarStore.new()
	w.declare("A", "int", 5)
	w.declare("S", "str", "")
	w.restore(d)
	t.eq(w.dump(), d, "왕복")


func test_quest_stages(t) -> void:
	var st := _state()
	t.ok(st.quests.defs.has("MQ-P1") and st.quests.defs.has("MQ-101"), "퀘스트 정의(기획서 추출)")
	t.eq(st.quests.log_text("MQ-P1", 20), "엄마에게 걸어간다", "로그 문장")
	t.ok(st.quests.set_stage("MQ-P2", 10), "발동")
	t.eq(st.quests.events[-1]["kind"], "start", "발동 알림")
	t.ok(not st.quests.set_stage("MQ-P2", 10), "같은 단계 다시 안 됨")
	t.ok(st.quests.set_stage("MQ-P2", 50), "건너뛰기")
	t.eq(int(st.vars.get_v("MQP2_SKIP")), 1, "건너뛰면 SKIP")
	t.ok(not st.quests.set_stage("MQ-P2", 30), "내려가지 않음")
	t.ok(st.quests.set_stage("MQ-P2", 100), "종료")
	t.eq(st.quests.events[-1]["kind"], "done", "종료 알림")
	t.ok(not st.quests.set_stage("MQ-P2", 200), "종료 뒤 변경 없음")
	st.quests.set_stage("MQ-101", 10)
	t.eq(st.quests.active().size(), 1, "진행 중 목록")


func test_speech(t) -> void:
	# SD-10 §3.5.8 권장 화술(카리스마 5, 대상 호감 50, 카르마 0, 세력 중립): (0.7 + 0.5) × 화술 × 배수
	t.near(Speech.chance(5, false, 50, 0, 50, 0, 30, "아주 쉬움"), 1.2 * 30 * 0.018, 1e-6, "아주 쉬움 30")
	t.near(Speech.chance(5, false, 50, 0, 50, 0, 50, "쉬움"), 0.72, 1e-6, "쉬움 50")
	t.near(Speech.chance(5, true, 50, 0, 50, 0, 50, "쉬움"), 1.1 * 50 * 0.012, 1e-6, "무기 꺼냄 -1")
	t.eq(Speech.chance(5, false, 50, 0, 50, 0, 100, "쉬움"), 1.0, "0.9 이상이면 확정")
	t.near(Speech.chance(5, false, 50, 60, 50, 0, 50, "보통"), (0.7 + 0.65) * 50 * 0.009, 1e-6, "세력 호감 ×0.25")
	t.near(Speech.chance(5, false, 50, 0, 80, 500, 50, "보통"), (0.7 + (50 + 30) / 100.0) * 50 * 0.009, 1e-6, "책임감·카르마 항")
	t.eq(Speech.percent(0.648), 65, "표시 반올림")
	t.eq(Speech.roll(7, "A:1:0"), Speech.roll(7, "A:1:0"), "판정 고정")
	t.ok(Speech.roll(7, "A:1:0") != Speech.roll(8, "A:1:0"), "씨앗이 다르면 다름")
	var table := [[1, 1, 5], [1, 10, 9], [5, 5, 15], [5, 6, 15], [10, 10, 27], [7, 3, 18]]
	for r in table:
		t.eq(Speech.base_skill(r[0], r[1]), r[2], "초기 스킬 %d/%d" % [r[0], r[1]])
	var st := _state()
	t.eq(st.skill("화술"), 15, "기본 화술")
	st.vars.set_v("PC_TAG1", "SPEECH")
	t.eq(st.skill("SPEECH"), 30, "태그 +15")


func test_text_codes(t) -> void:
	var st := _state()
	st.vars.set_v("PC_CAPS", 1240)
	var f := TextFmt.format("\\P\\J[은] \\V[PC_CAPS]캡, \\N[C-010]\\J[과] \\V[P_REGNO]\\J[로].\\W[5] 끝\\.줄", st)
	t.eq(f["text"], "서윤은 1,240캡, 조만석과 S07-2258-0031로. 끝" + TextFmt.NBSP + "줄", "제어 코드 풀기")
	t.eq(f["pauses"], [[32, 0.5]], "쉬기 위치(\\W 앞 글자 수)")
	var g := TextFmt.format("평범 \\C[2]강조\\C[0] 끝", st)
	t.eq(g["colors"], [[3, 5, 2]], "색 구간")
	t.eq(TextFmt.group(-1234567), "-1,234,567", "쉼표")
	st.set_meta("speech_target", "C-010")
	t.eq(TextFmt.plain("\\T[화술:쉬움]", st), "[화술 %d%%]" % Speech.percent(1.2 * 15 * 0.012), "판정 태그 계산(카리스마 5·화술 15)")
	t.eq(TextFmt.plain("\\T[과학:25]", st), "[과학 25]", "고정 요구치 태그")


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func test_dialogue_mq_p1(t) -> void:
	var st := _state()
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene("MQ-P1_S01"))
	var lines := 0
	var cmds := []
	var guard := 0
	while cur["type"] != "end" and guard < 100:
		guard += 1
		if cur["type"] == "line":
			lines += 1
		elif cur["type"] == "cmd":
			cmds.append(cur["name"])
		cur = dr.advance()
	t.eq(lines, 9, "의무실 대사 수")
	t.ok("doc" in cmds and "lamp" in cmds and "year_card" in cmds, "연출 명령 전달")
	t.eq(st.quests.stage("MQ-P1"), 20, "의무실 끝 단계 20")
	t.ok(dr.log.has("방금례: …네. 등록 번호 S07-2258-0031. 접수했습니다."), "변수 토큰이 대화 기록에")
	# 돌잡이: 출입 카드
	cur = dr.start(_scene("MQ-P1_S03"))
	while cur["type"] != "choices":
		cur = dr.advance()
	t.eq(cur["opts"].size(), 6, "돌상 물건 6개")
	cur = dr.choose(5)
	t.eq(int(st.vars.get_v("V_DOL")), 6, "V_DOL = 6")
	t.eq(cur["text"], "식당이 잠깐 조용해진다.", "출입 카드 반응")
	while cur["type"] != "end":
		cur = dr.advance()
	t.eq(st.quests.stage("MQ-P1"), 100, "MQ-P1 종료")
	t.eq(dr.errors.size(), 0, "실행 오류 없음: " + str(dr.errors))


func test_dialogue_checks(t) -> void:
	var st := _state()
	var p := st.speech_chance("C-010", "아주 어려움")
	st.check_seed = 0
	while Speech.roll(st.check_seed, "T:1:0") < p:                  # 실패하는 씨앗을 고른다(판정 고정)
		st.check_seed += 1
	var g := {"id": "T", "npc": "C-010", "labels": {"START": 0, "OK": 2, "NO": 4}, "ops": [
		{"op": "choice", "opts": [
			{"id": "T:1:0", "text": "설득한다", "tags": [{"k": "speech", "skill": "화술", "diff": "아주 어려움"}], "to": "OK", "fail": "NO"},
			{"id": "T:1:1", "text": "힘으로", "tags": [{"k": "stat", "name": "힘", "min": 9}], "to": "OK"},
			{"id": "T:1:2", "text": "돈을 낸다", "tags": [{"k": "caps", "n": 200}], "to": "OK", "fx": "karma(-5)"},
			{"id": "T:1:3", "text": "물러난다", "tags": [], "to": "END", "cond": "V_ACT == 0"}]},
		{"op": "end"},
		{"op": "line", "who": "C-010", "emo": "기본", "text": "좋아."}, {"op": "end"},
		{"op": "line", "who": "C-010", "emo": "분노", "text": "안 돼."}, {"op": "end"}]}
	var dr := DialogueRunner.new(st)
	var cur := dr.start(g)
	t.eq(cur["opts"].size(), 3, "힘 9 미달 선택지는 숨김")
	t.ok(cur["opts"][0]["text"].begins_with("[화술 "), "화술 확률 표시")
	t.eq(cur["opts"][1]["enabled"], false, "캡 부족이면 회색")
	cur = dr.choose(1)
	t.eq(cur["type"], "choices", "회색 선택지는 고를 수 없음")
	cur = dr.choose(0)
	t.eq(dr.last_check["ok"], false, "고정 난수 ≥ 확률 → 실패")
	t.eq(cur["text"], "안 돼.", "실패 이동")
	cur = dr.start(g)
	t.eq(cur["opts"].size(), 2, "실패한 판정은 다시 나오지 않음")
	st.vars.set_v("PC_CAPS", 300)
	cur = dr.start(g)
	cur = dr.choose(0)
	t.eq(int(st.vars.get_v("PC_CAPS")), 100, "캡 차감")
	t.eq(int(st.vars.get_v("V_KARMA")), -5, "효과 실행")
	t.ok(dr.log.has("[화술 0% → 실패]") or dr.log.any(func(l): return l.begins_with("[화술 ") and l.ends_with("→ 실패]")), "판정 기록")


func test_state_roundtrip(t) -> void:
	var st := _state()
	st.call_fn("karma", [50])
	st.call_fn("aff", ["BC", 20])
	st.call_fn("give", ["I-BBGUN", 1])
	st.quests.set_stage("MQ-P2", 20)
	st.failed_checks["X:1:0"] = true
	st.check_seed = 42
	var d := st.dump()
	var st2 := _state()
	st2.restore(d)
	t.eq(st2.dump(), d, "이야기 상태 왕복")
	t.eq(int(st2.vars.get_v("AFF_JC_BC")), 20, "정착지 개별 호감도")
	t.eq(int(st2.vars.get_v("AFF_BJ")), -30, "세력 시작값(SD-06)")
	var bytes := var_to_bytes(d)
	t.eq(bytes_to_var(bytes), d, "엔진 이진 변환 왕복")


func test_event_dirs(t) -> void:
	# 바라보기(face ID 인물)·이동 방향 스냅: Locomotion.DIRS 순서(E SE S SW W NW N NE)
	t.eq(EventRunner._dir_to(Vector2.ZERO, Vector2(10, 0)), 0, "동")
	t.eq(EventRunner._dir_to(Vector2.ZERO, Vector2(0, 10)), 2, "남")
	t.eq(EventRunner._dir_to(Vector2.ZERO, Vector2(-10, -10)), 5, "북서")
	t.eq(EventRunner._dir_to(Vector2.ZERO, Vector2.ZERO), 2, "같은 자리면 남")
	t.eq(EventRunner._dir8(Vector2(10, 3)), Vector2(1, 0), "가까운 8방향(동)")
	t.ok(EventRunner._dir8(Vector2(10, 9)).is_equal_approx(Vector2(1, 1).normalized()), "가까운 8방향(남동)")
