## 단계 1-10b 라디오(SD-12 §10 · SD-17 §4): 수신(볼트 ST-11 · 밖 ST-01 잡음 · ST-02 깨끗 · 지하 한 단계) · 편성(징글 → 인트로 → 블록 → 휴지) ·
## 줄 시간 1.2 + 0.09×글자 · 반응 뉴스 대기열(처음 참 → 다음 추첨에 먼저 · 세 번 뒤 내림) · 진행 멘트 반복 억제 · 대화 중 멈춤 · 꺼도 흐름 · 저장 왕복.
extends RefCounted

const DT := 0.25


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	return st


func _ctx(extra := {}) -> Dictionary:
	var c := {"act": 1, "vault": false, "pip": true, "under": false, "clean01": false, "public": false, "now": 1000, "date": "2277. 10. 24.  09:00"}
	c.merge(extra, true)
	return c


func _run(r: Radio, st: StoryState, secs: float, ctx: Dictionary) -> Array:
	var seen: Array = []
	for i in int(secs / DT):
		r.tick(DT, st, ctx)
		var np := r.now_playing()
		if str(np.get("kind", "")) == "line":
			var key := str(np["block"])
			if seen.is_empty() or seen[-1] != key:
				seen.append(key)
	return seen


func test_radio_reception(t) -> void:
	t.eq(Radio.quality("ST-11", _ctx({"act": 0, "vault": true})), 0, "볼트 안 + 핍-보이: 구내방송")
	t.eq(Radio.quality("ST-11", _ctx({"act": 0, "vault": true, "pip": false})), -1, "핍-보이 없으면 안 잡힌다")
	t.eq(Radio.quality("ST-01", _ctx({"act": 0, "vault": true})), -1, "볼트 안: 남산 방송 안 잡힘")
	t.eq(Radio.quality("ST-01", _ctx()), 1, "밖: 남산 방송은 잡음 섞임(송신탑 출력 약함)")
	t.eq(Radio.quality("ST-01", _ctx({"clean01": true})), 0, "용산 · 노들섬 · R02 북쪽 강변: 깨끗")
	t.eq(Radio.quality("ST-01", _ctx({"public": true})), 0, "MQ-205 뒤(RADIO_PUBLIC): 전역 깨끗")
	t.eq(Radio.quality("ST-02", _ctx()), 0, "공보방송: 전역 깨끗")
	t.eq(Radio.quality("ST-02", _ctx({"under": true})), 1, "지하 실내: 한 단계 나빠짐")
	t.eq(Radio.quality("ST-01", _ctx({"under": true})), 2, "남산 + 지하: 약함")
	t.ok(Radio.garble("남산 방송입니다 오늘도", 2).contains("▒") and Radio.garble("남산", 0) == "남산", "약함: 글자 일부 ▒")
	var st := _state()
	var r := Radio.new()
	t.ok(r.toggle(_ctx()) and r.on and r.tuned == "ST-01", "켜면 잡히는 첫 방송국(남산)")
	r.tick(DT, st, _ctx({"act": 1, "vault": true, "pip": false}))
	t.ok(not r.on, "잡히는 방송국이 없으면 꺼진다")


func test_radio_program(t) -> void:
	var st := _state()
	var r := Radio.new()
	r.tune("ST-01")
	var c := _ctx()
	r.tick(DT, st, c)
	var cur: Dictionary = r.cur["ST-01"]
	var segs: Array = cur["segs"]
	t.eq(str(segs[0]["k"]), "jingle", "편성 첫 마디 = 시그널 징글")
	t.eq(str(segs[0]["sound"]), "RJ-01-01", "남산 시그널 RJ-01-01")
	t.eq(str(segs[1]["kind"]), "intro", "다음 = 인트로 멘트")
	t.eq(str(segs[-1]["k"]), "pause", "끝 = 휴지(신호 베드만)")
	t.ok(float(segs[-1]["secs"]) >= 20.0 and float(segs[-1]["secs"]) <= 60.0, "휴지 20~60초")
	t.near(Radio.line_secs("가나다라마바사아자차"), 1.2 + 0.9, 0.001, "줄 = 1.2 + 0.09 × 글자")
	var seen := _run(r, st, 4.0, c)
	t.ok(not seen.is_empty() and seen[0].begins_with("I"), "징글 4초 뒤 인트로 자막(%s)" % str(seen))
	var kinds := {}
	for i in 40:                                                       # 편성 40번: 추첨 갈래가 고루 나온다
		var p := r._program("ST-01", st, c)
		for sg in p:
			if str(sg["k"]) == "block" and str(sg["kind"]) != "intro" and str(sg["kind"]) != "outro":
				kinds[str(sg["kind"])] = int(kinds.get(str(sg["kind"]), 0)) + 1
	t.ok(kinds.has("talk") and kinds.has("info") and kinds.has("drama"), "진행 멘트 · 생활 정보 · 연속극이 나온다(%s)" % str(kinds))
	t.ok(not kinds.has("news"), "대기열을 거친 소식이 없으면 뉴스 칸은 다른 갈래로")
	var talks: Array = r.recent.duplicate()
	var dup := false
	for i in talks.size():
		for j in range(i + 1, talks.size()):
			dup = dup or talks[i] == talks[j]
	t.ok(not dup, "같은 진행 멘트는 최근 10블록 안에 다시 안 나온다")
	var d1 := r._from("ST-01", "drama", st, 0)
	t.eq(int(d1.get("ep", 0)), (r.drama_i % 4) + 1, "연속극은 회차 순서대로")


func test_radio_news_queue(t) -> void:
	var st := _state()
	var r := Radio.new()
	var c := _ctx()
	r.tick(DT, st, c)                                                  # 첫 틱: 이미 참인 것 없음 → primed
	t.ok(r.primed and r.queue.is_empty(), "처음엔 대기열 비어 있음")
	st.vars.set_v("V_ESCAPE", 2)
	r._chk = 0.0
	r.tick(DT, st, c)
	t.ok(r.queue.has("N-P4") and r.queue.has("N-P4-2") and not r.queue.has("N-P4-1"), "탈출 소식 + 탈출 방식 꼬리(은신)만 대기열에")
	var p := r._program("ST-01", st, c)
	var body := ""
	for sg in p:
		if str(sg["k"]) == "block" and str(sg["kind"]) == "news":
			body = str(sg["id"])
	t.eq(body, "N-P4", "대기열이 있으면 다음 추첨은 무조건 뉴스(오래된 순)")
	var heads := p.filter(func(sg): return str(sg.get("sound", "")) == "RJ-01-03")
	t.eq(heads.size(), 1, "뉴스 머리 징글 RJ-01-03")
	r.tune("ST-01")
	r.cur.erase("ST-01")
	for i in 3:
		r.queue["N-P4"]["n"] = i
	r.queue["N-P4"]["n"] = 3
	r._chk = 0.0
	r.tick(DT, st, c)
	t.ok(not r.queue.has("N-P4"), "세 번 방송하면 대기열에서 내린다")
	r.queue["N-P4-2"]["at"] = 1000
	r._chk = 0.0
	r.tick(DT, st, _ctx({"now": 1000 + 3 * 1440 + 1}))
	t.ok(not r.queue.has("N-P4-2"), "사흘이 지나면 내린다")
	var rot := r._from("ST-01", "news", st, 9000)
	t.ok(str(rot.get("id", "")) in ["N-P4", "N-P4-2"], "내린 소식은 일반 순환(뉴스 40%%)으로")
	st.vars.set_v("V_WANTED", 40)
	st.vars.set_v("P_REGNO", "S07-58-0193")
	r._chk = 0.0
	r.tick(DT, st, c)
	t.ok(r.queue.has("NT-W2"), "공보 수배 공고도 처음 참이 되면 먼저")
	var p2 := r._program("ST-02", st, c)
	var line := ""
	for sg in p2:
		if str(sg["k"]) == "block" and str(sg["id"]) == "NT-W2":
			line = " ".join((sg["lines"] as Array).map(func(l): return str(l["text"])))
	t.ok(line != "" and not line.contains("{") and line.contains(str(st.vars.get_v("P_REGNO"))), "수배 공고: 등록번호 슬롯을 채운다(%s)" % line)
	var r2 := Radio.new()                                              # 옛 저장: 이미 참인 소식은 대기열 없이(한꺼번에 몰려 나오지 않게)
	r2.tick(DT, st, c)
	t.ok(r2.queue.is_empty() and r2.fired.has("N-P4"), "옛 저장 불러오기: 지난 소식은 순환으로만")


func test_radio_hold_save(t) -> void:
	var st := _state()
	var r := Radio.new()
	r.tune("ST-02")
	var c := _ctx()
	_run(r, st, 6.0, c)
	var before: Dictionary = (r.cur["ST-02"] as Dictionary).duplicate(true)
	var c2 := c.duplicate()
	c2["hold"] = true
	var b01: Dictionary = (r.cur.get("ST-01", {}) as Dictionary).duplicate(true)
	for i in 20:
		r.tick(DT, st, c2)
	t.ok(int(r.cur["ST-02"]["si"]) == int(before["si"]) and int(r.cur["ST-02"]["li"]) == int(before["li"]) and is_equal_approx(float(r.cur["ST-02"]["t"]), float(before["t"])), "대화 중: 맞춘 방송국은 멈춘다")
	t.ok(b01.is_empty() or float(r.cur["ST-01"]["t"]) != float(b01.get("t", -1.0)) or int(r.cur["ST-01"]["si"]) != int(b01.get("si", -1)), "다른 방송국은 흐른다")
	r.on = false
	var si := int(r.cur["ST-02"]["si"])
	var li := int(r.cur["ST-02"]["li"])
	_run(r, st, 30.0, c)
	t.ok(int(r.cur["ST-02"]["si"]) != si or int(r.cur["ST-02"]["li"]) != li, "꺼도 방송은 흐른다")
	t.ok(not r.air_log.is_empty(), "방송 기록이 쌓인다(%d)" % r.air_log.size())
	r.on = true
	var d := r.to_dict()
	var js := JSON.stringify(d)
	var r3 := Radio.new()
	r3.from_dict(JSON.parse_string(js))
	t.eq(JSON.stringify(r3.to_dict()), js, "저장 → 불러오기 → 저장이 같다")
	var a := r.now_playing()
	var b := r3.now_playing()
	t.eq(str(a.get("text", a.get("kind", ""))), str(b.get("text", b.get("kind", ""))), "불러온 뒤 같은 줄부터")
