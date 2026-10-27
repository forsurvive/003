## 핍-보이 단순 조작(사용자 지시 2026-10-27): 화면 16장을 한 줄로 넘기기 · 부가 동작 하나(F) · 터치 밀기 · 뗄 때 결정.
extends RefCounted


func _pb() -> PipBoy:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.quests.set_stage("MQ-101", 10)
	return PipBoy.new().setup(st, {}, {})


func _key(p: PipBoy, k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	p._unhandled_input(e)


func test_pipboy_page_wraps(t) -> void:
	var p := _pb()
	p.open_at(0, 4)
	p._page(1)
	t.eq([p.tab, p.sub[p.tab]], [1, 0], "능력치 마지막 화면에서 다음 = 아이템 첫 화면")
	p.open_at(0, 0)
	p._page(-1)
	t.eq([p.tab, p.sub[p.tab]], [2, 5], "맨 앞에서 이전 = 데이터 마지막(세력)")
	p.open_at(1, 2)
	_key(p, KEY_E)
	t.eq([p.tab, p.sub[p.tab]], [1, 3], "E = 다음 화면")
	_key(p, KEY_D)
	t.eq([p.tab, p.sub[p.tab]], [1, 4], "D = 다음 화면")
	_key(p, KEY_Q)
	t.eq([p.tab, p.sub[p.tab]], [1, 3], "Q = 이전 화면")
	p.free()


func test_pipboy_alt_and_swipe(t) -> void:
	var p := _pb()
	p.open_at(2, 2)
	p.rows = p._rows()
	var i := -1
	for k in p.rows.size():
		if str(p.rows[k]["id"]) == "MQ-101":
			i = k
	t.ok(i >= 0, "퀘스트 목록에 MQ-101")
	p.sel = i
	t.eq(p._alt_label(), "고정", "퀘스트 화면의 부가 동작 = 고정")
	_key(p, KEY_F)
	t.ok(p.st.quests.pinned.has("MQ-101"), "F = 고정")
	t.eq(p._act_label(), "추적", "결정 단추 = 추적")
	# 터치 밀기: 오른쪽에서 왼쪽으로 60px = 다음 화면 — 누른 줄을 결정(추적)하지 않는다
	var tracked0: String = p.st.quests.tracked
	p._pointer_at(true, Vector2(400, 150))                               # 논리 좌표(640×360)
	p._pointer_at(false, Vector2(340, 152))
	t.eq([p.tab, p.sub[p.tab]], [2, 3], "왼쪽으로 밀면 다음 화면(기록)")
	t.eq(p.st.quests.tracked, tracked0, "밀기는 결정이 아니다")
	p.open_at(1, 0)
	t.eq(p._alt_label(), "", "빈 무기 목록엔 부가 동작 없음")
	p.free()
