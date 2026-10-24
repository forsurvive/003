## 단계 1-13i 정본 정기 순찰 둘(SD-06 §14.1 · 계획 _plans/1-13i_patrol_plan.md · D-404): 봉천 감시조 RE-X08 · 지하시장 계약 경호단 RE-X09.
## 표(세력 · 자리 · 판) · 장면 갈래(판도 몫 RE_TS · 호감 단계 · 장물 몸수색 · 숨은 손님) · 서서 떠들기(말풍선) · 처치 = 호감 −20 한 번.
extends RefCounted


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 4)
	return st


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 장면을 끝까지(picks 차례로). 대사 글과 마지막 @cmd re 명령을 돌려준다
func _play(st: StoryState, id: String, picks: Array = []) -> Dictionary:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var lines: Array = []
	var cmd := ""
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "line":
			lines.append(str(cur.get("text", "")))
			cur = dr.advance()
		elif cur["type"] == "cmd":
			if str(cur["name"]) == "re":
				cmd = str(cur["args"][0])
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := -1
			if k < picks.size():
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])) and bool(cur["opts"][j]["enabled"]):
						i = j
				k += 1
			if i < 0:
				return {"lines": lines, "cmd": cmd, "err": "선택지 없음: %s / %s" % [str(picks.slice(k - 1, k)), str(cur["opts"].map(func(o): return o["text"]))]}
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return {"lines": lines, "cmd": cmd, "err": "" if dr.errors.is_empty() else str(dr.errors)}


func _has(r: Dictionary, frag: String) -> bool:
	return r["lines"].any(func(l): return str(l).contains(frag))


func test_patrol_table(t) -> void:
	for id in ["RE-X08", "RE-X09"]:
		var d := Encounters.re_def(id)
		t.eq(str(d.get("cat", "")), "patrol", "%s = 순찰 범주" % id)
		t.ok(FileAccess.file_exists("res://data/dialogue/%s_TALK.json" % id), "%s 장면" % id)
		t.eq((d.get("variants", []) as Array).size(), 3, "%s 판 셋(같은 순찰도 매번 다른 말)" % id)
		for v in d["variants"]:
			t.ok((v.get("chatter", []) as Array).size() >= 3, "%s 판마다 떠드는 말 셋 이상" % id)
	t.eq(str(Encounters.re_def("RE-X08")["faction"]), "JC", "감시조 = 정착지 연합 몫")
	t.eq(str(Encounters.re_def("RE-X09")["faction"]), "JH", "경호단 = 지하시장 몫")
	t.ok(Encounters.near_ok(Encounters.re_def("RE-X08"), Vector2i(900, 1380)), "감시조는 봉천 둘레")
	t.ok(not Encounters.near_ok(Encounters.re_def("RE-X08"), Vector2i(715, 1112)), "영등포엔 감시조 없음")
	t.ok(Encounters.near_ok(Encounters.re_def("RE-X09"), Vector2i(720, 1120)), "경호단은 지하상가 출입구 둘레")
	t.eq(str(StoryState.ENEMY_FACTION.get("CR-466", "")), "JC", "감시조원을 쓰러뜨리면 정착지 연합 판도 −1")


func test_patrol_watch_scene(t) -> void:
	var st := _st()
	st.vars.set_v("RE_TS", 2)
	var r := _play(st, "RE-X08_TALK", ["수고해"])
	t.eq(r["err"], "", "감시조 장면 오류 없음")
	t.ok(_has(r, "돌계단에 앉아"), "지배 구역 = 하나는 쉰다")
	t.eq(r["cmd"], "leave", "인사하고 떠난다")
	t.eq(int(st.vars.get_v("RE_X08_N")), 1, "만난 수")
	r = _play(st, "RE-X08_TALK", ["수고해"])
	t.ok(_has(r, "또 보네"), "두 번째부터 재회 줄")
	st.vars.set_v("RE_TS", 0)
	st.vars.set_v("RE_SAW", 1)
	var aff0 := int(st.vars.get_v("AFF_JC_BC"))
	r = _play(st, "RE-X08_TALK", ["들개를 봤어", "수고해"])
	t.ok(_has(r, "새 분필 화살표"), "경합 구역 = 새 표식을 긋는다")
	t.ok(int(st.vars.get_v("AFF_JC_BC")) > aff0, "본 것을 알려 주면 봉천 호감")
	t.eq(int(st.vars.get_v("RE_X08_SAW")), 4, "그날 한 번")
	# 외눈 소식: 봉천이 이미 안 뒤에만(P2 · P7)
	st.vars.set_v("RE_V", 3)
	st.kill("CR-500")
	st.vars.set_v("SQ_S01_BC", 3)
	r = _play(st, "RE-X08_TALK", ["수고해"])
	t.ok(not _has(r, "네가 했다며"), "봉천이 아직 모르면 소탕 얘기를 하지 않는다")
	st.vars.set_v("SQ_S01_BC", 0)
	r = _play(st, "RE-X08_TALK", ["수고해"])
	t.ok(_has(r, "네가 했다며"), "봉천이 들은 뒤엔 안다")
	# 봉천 적대: 쫓아낸다
	st.vars.set_v("AFF_JC_BC", -70)
	r = _play(st, "RE-X08_TALK", ["간다"])
	t.ok(_has(r, "이 길에서 꺼져"), "적대 = 쫓아냄")


func test_patrol_guard_scene(t) -> void:
	var st := _st()
	st.vars.set_v("RE_V", 1)
	var r := _play(st, "RE-X09_TALK")
	t.eq(r["err"], "", "경호단 장면 오류 없음")
	t.ok(_has(r, "구경만 하시고"), "중립 = 무관심")
	st.vars.set_v("AFF_JH", 25)
	r = _play(st, "RE-X09_TALK")
	t.ok(_has(r, "단골"), "우호 = 인사 · 지상 소식")
	st.vars.set_v("AFF_JH", 55)
	r = _play(st, "RE-X09_TALK")
	t.ok(_has(r, "출구까지 모셔다"), "신뢰 = 배웅")
	# 장물 몸수색(판 2 · 중립): 내놓으면 장물이 손을 떠난다
	st.vars.set_v("AFF_JH", 0)
	st.vars.set_v("RE_V", 2)
	st.call_fn("give", ["I-001", 2])
	st.stolen["I-001"] = 1
	t.eq(int(st.call_fn("stolen_n", [])), 1, "지닌 장물 하나")
	r = _play(st, "RE-X09_TALK", ["내놓는다"])
	t.ok(_has(r, "누구 건지 아시죠"), "장물을 짚는다")
	t.eq(st.count_of("I-001"), 1, "장물만 내놓는다(내 것은 남는다)")
	t.eq(int(st.call_fn("stolen_n", [])), 0, "장물 기록이 비었다")
	r = _play(st, "RE-X09_TALK")
	t.ok(not _has(r, "주머니부터"), "중립 손님이 장물이 없으면 몸수색 없음")
	st.vars.set_v("AFF_JH", -30)
	r = _play(st, "RE-X09_TALK")
	t.ok(_has(r, "주머니부터") and _has(r, "깨끗하네요"), "경계 단계 = 늘 몸수색 · 장물이 없으면 보낸다")
	st.vars.set_v("AFF_JH", 0)
	# 출입 금지 손님 수색(판 3)
	st.vars.set_v("RE_V", 3)
	var caps0 := int(st.vars.get_v("PC_CAPS"))
	r = _play(st, "RE-X09_TALK", ["못 봤어"])
	t.eq(r["cmd"], "leave", "못 봤다 = 지나간다")
	# 적대 = 추심
	st.vars.set_v("AFF_JH", -70)
	r = _play(st, "RE-X09_TALK", ["덤벼 봐"])
	t.eq(r["cmd"], "fight", "적대에 맞서면 싸움")
	t.eq(int(st.vars.get_v("PC_CAPS")), caps0, "캡은 그대로")


func test_patrol_live_chatter(t) -> void:
	# 실제 인카운터: 봉천 둘레에서 감시조를 세우면 판도 몫(RE_TS)이 서고, 둘은 서서 기다리며(S4) 12칸 안의 주인공에게 들리게 떠든다
	var h := InteriorHost.new()
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 25.  14:00"
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		h.st.quests.set_stage(q, 100)
	h.st.vars.set_v("V_ACT", 1)
	h.enter("W", "@905,1385")
	t.ok(h.enc_live != null, "인카운터 진행기")
	h.st.vars.set_v("RE_TS", -1)
	t.ok(h.enc_live.start({"re": "RE-X08", "force": true}), "감시조를 세운다")
	t.ok(int(h.st.vars.get_v("RE_TS")) in [0, 1, 2], "판도 몫이 섰다(%d)" % int(h.st.vars.get_v("RE_TS")))
	for i in 40:
		h.enc_live.tick(0.25)
		if str(h.enc_live.cur.get("phase", "")) == "live":
			break
	t.eq(str(h.enc_live.cur.get("phase", "")), "live", "본체가 섰다")
	var actors: Array = h.enc_live.cur.get("actors", [])
	t.eq(actors.size(), 2, "감시조 둘")
	t.ok(actors.all(func(a): return bool(a.get_meta("wait", false))), "서서 기다린다(다가오지 않는다)")
	var lead: Actor = actors[0]
	h.player.loco.place(lead.loco.logical + Vector2(7 * 32, 0))
	h.player.position = h.player.loco.render
	var bubbles := 0
	for i in 24:
		h.enc_live.tick(0.25)
		for a in actors:
			if is_instance_valid(a):
				bubbles += a.get_children().filter(func(c): return c is ChatBubble).size()
	t.ok(bubbles > 0, "7칸 밖에서 둘이 떠드는 말풍선이 뜬다")
	t.ok(not bool(h.enc_live.cur.get("talked", true)), "멀리 있으면 말을 걸지 않는다")
	h.free()
