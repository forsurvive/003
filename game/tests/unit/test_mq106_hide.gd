## 1-13g A27(D-180, SD-20 P10): MQ-106 버티버드를 피해 실내에 숨은 채 저장 → 불러오면 숨은 시간이 0부터가 아니라 이어서 센다.
extends RefCounted


func _host(st: StoryState) -> Array:
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 30.  14:00"
	var m := Mq106.new()
	m.setup(h)
	h.enter("D-01", "")
	return [h, m]


func test_mq106_hide_resume(t) -> void:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 7)
	st.vars.set_v("K_CODE", 1)
	st.quests.set_stage("MQ-106", 10)
	var a := _host(st)
	var m: Mq106 = a[1]
	m.state = "fight"
	m._went_inside()
	t.eq(m.state, "hiding", "실내로 들어가면 숨음")
	t.ok(not m.active(), "숨는 동안은 저장할 수 있다(진행 중 아님)")
	for i in 25:
		m._process(1.0)
	t.ok(absi(int(st.vars.get_v("MQ106_HIDE_T")) - 251) <= 10, "숨은 시간 25초가 저장 변수에(%d)" % int(st.vars.get_v("MQ106_HIDE_T")))
	# 불러오기: 같은 이야기 상태 · 새 진행기
	var b := _host(st)
	var m2: Mq106 = b[1]
	m2._check_resume()
	t.eq(m2.state, "hiding", "불러오면 다시 숨은 상태")
	t.ok(absf(m2._inside_t - 25.0) <= 1.0, "숨은 시간이 이어진다(%.1f초 — 0부터가 아님)" % m2._inside_t)
	for i in 40:
		m2._process(1.0)
	m2._came_out()
	t.eq(int(st.vars.get_v("MQ106_RESULT")), 2, "합쳐 60초를 넘겨 나오면 버티버드는 떠났다(결과 2)")
	t.eq(int(st.vars.get_v("MQ106_HIDE_T")), 0, "나오면 숨음 변수 비움")
	# 너무 일찍 나오면 다시 무전부터
	st.vars.set_v("MQ106_RESULT", 0)
	var c := _host(st)
	var m3: Mq106 = c[1]
	m3.state = "fight"
	m3._went_inside()
	for i in 10:
		m3._process(1.0)
	m3._came_out()
	t.eq(m3.state, "radio", "10초 만에 나오면 다시 내려앉는다")
	t.eq(int(st.vars.get_v("MQ106_HIDE_T")), 0, "숨음 변수 비움")
