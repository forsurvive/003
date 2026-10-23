## 단계 1-11e SQ-S05 「환승촌 막차」(SD-04a §4.5): 발동(철망 · 방송 설비 · 이미 앎) · 순서 파괴(서울대입구 쪽 → 40) · 휴면 군집(일제 기상 · 여섯 시간 뒤 다시 앉음) ·
## 역무원(정기권 · 경고 뒤 경광봉) · 가면(길만 연다) · 해법 A 방송 → 행렬(소란이면 깨짐 · 24시간 뒤 결과만) · B 소탕 · C 주성호(봉천행 절반) ·
## 정기권 빌리기(물 한 통 · 한 장뿐) · 허순자가 없으면 위원회 · 주성호가 이틀 뒤 돌아감 · 철망 발소리.
extends RefCounted


func _host(date: String, map_id: String, mark: String) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 4)
	st.vars.set_v("P_REGNO", "S07-2259-0412")
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = date
	var c := SideS05.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 원고를 끝까지(또는 picks 차례로 고르며): s05 명령은 진행기로
func _play(st: StoryState, c: SideS05, id: String, picks: Array = [], label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s05" and str(cur["args"][0]) != "go":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				i = -1
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])) and bool(cur["opts"][j]["enabled"]):
						i = j
				k += 1
			if i < 0:
				return dr.errors + ["선택지 없음: %s" % str(picks[k - 1])]
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return dr.errors


func _says(st: StoryState, c: SideS05, id: String, needle: String, picks: Array = [], label := "START") -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if str(cur.get("text", "")).contains(needle):
			return true
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s05" and str(cur["args"][0]) != "go":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])):
						i = j
				k += 1
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return false


## 선택지 글 목록(열린 것만) — 장면 START에서 첫 선택지까지
func _opts(st: StoryState, id: String, label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var guard := 0
	while cur["type"] != "end" and cur["type"] != "choices" and guard < 100:
		guard += 1
		cur = dr.advance()
	var out := []
	if cur["type"] == "choices":
		for o in cur["opts"]:
			if bool(o["enabled"]):
				out.append(str(o["text"]))
	return out


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _alive(h: InteriorHost, id: String) -> Array:
	return h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == id)


## 행렬을 끝까지: 걷기 시작한 손님은 측선 표지에 닿은 것으로 옮긴다(시험엔 연출 실행기의 매 프레임이 없다)
func _walk_line(h: InteriorHost, c: SideS05, shoot_at := -1) -> void:
	var guard := 0
	var n := 0
	while not c.proc.is_empty() and guard < 400:
		guard += 1
		c._proc_tick(0.5)
		if c.proc.is_empty():
			break
		for id in (c.proc["walk"] as Dictionary).keys():
			var a: Actor = h.ev.actors.get(id)
			if a != null:
				a.loco.place(h.map.mark_pos("siding"))
				n += 1
		if shoot_at >= 0 and n >= shoot_at:
			h.combat.stats["shots"] = int(h.combat.stats.get("shots", 0)) + 1
			shoot_at = -1


func test_sq_s05_trigger_gate(t) -> void:
	var r := _host("2277. 10. 26.  22:00", "D-06", "from_U01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	t.ok(_says(st, c, "SQS05_GATE", "웅크리고 지나가", ["나중에"]), "밤 철망 문: 성지후가 '뛰지 마 · 웅크려'")
	t.eq(_play(st, c, "SQS05_GATE", ["나중에"]), [], "철망 문 경고를 끝까지")
	t.eq(_v(st, "SQ_S05_GATE"), 1, "경고를 들음")
	t.eq(st.quests.stage("SQ-S05"), 20, "철망 문 경고 → 10 → 20")
	t.eq(_play(st, c, "SD_BROADCAST"), [], "방송 설비: 테이프 칸이 비었다")
	t.eq(st.quests.stage("SQ-S05"), 30, "방송 설비 조사 → 30")
	h.enter("U-01", "from_E")
	t.eq(st.quests.stage("SQ-S05"), 40, "서쪽 터널 → 40")
	t.eq([_alive(h, "CR-095").size(), _alive(h, "CR-002").size()], [2, 2], "터널: 시궁쥐 둘 · 큰바퀴 둘")
	var sl := _alive(h, "CR-204")
	t.eq(sl.size(), 1, "재미 검수 1: 서서 조는 손님 하나")
	t.ok(sl.size() == 1 and sl[0].asleep and sl[0].doze == "stand", "서서 존다(휴면)")
	h.enter("U-01", "from_E")
	t.eq(_alive(h, "CR-095").size(), 0, "쥐는 첫 방문에만")


func test_sq_s05_fence_lines(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "D-06", "from_U01")
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	var h: InteriorHost = r[0]
	h.date_text = "2277. 10. 26.  04:00"
	t.ok(_says(st, c, "SD_FENCE", "두 걸음"), "철망(새벽): 두 걸음 — 멈춘다")
	h.date_text = "2277. 10. 26.  14:00"
	t.ok(_says(st, c, "SD_FENCE", "막차 왔어요"), "철망(낮): '…막차 왔어요?'")
	h.date_text = "2277. 10. 26.  18:00"
	t.ok(_says(st, c, "SD_FENCE", "숨소리"), "철망(저녁): 숨소리만 — 날 · 시각마다 다르다")
	h.date_text = "2277. 10. 26.  04:00"
	st.vars.set_v("SQ_S05_SLEEPER", 1)
	t.ok(not _says(st, c, "SD_FENCE", "두 걸음"), "서서 졸던 손님을 쓰러뜨렸으면 두 걸음 소리는 없다")
	st.vars.set_v("SQ_S05_WOKE", Clock.abs_min(h.date_text) - 30)
	t.ok(_says(st, c, "SD_FENCE", "서성이는"), "깨어 있으면 서성인다")
	st.vars.set_v("SQ_S05_WOKE", 0)
	h.date_text = "2277. 10. 26.  14:00"
	t.eq(_play(st, c, "SD_FENCE"), [], "철망을 끝까지")
	t.eq(st.quests.stage("SQ-S05"), 20, "철망 발소리 → 20")
	t.eq(_v(st, "SQ_S05_GATE"), 0, "발소리만으론 문 경고를 들은 게 아니다")
	t.ok(_says(st, c, "SQS05_GATE", "웅크리고 지나가", ["나중에"]), "낮 철망 문 첫 번째: 경비 N-SA-G3의 경고")
	t.eq(_play(st, c, "SQS05_GATE", ["나중에"]), [], "끝까지")
	t.ok(_says(st, c, "SQS05_GATE", "자물쇠를 만지작"), "낮 철망 문 두 번째: 경비가 짧게")


func test_sq_s05_order_break(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "U-03", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	t.eq(_alive(h, "CR-095").size(), 2, "서울대입구: 시궁쥐 둘")
	st.vars.set_v("PC_ST", 4)
	t.ok(not _says(st, c, "SQS05_IRONB", "빗장이 들려"), "힘 4: 쇠막대 선택지 없음")
	st.vars.set_v("PC_SKP_REPAIR", 30)
	t.eq(_play(st, c, "SQS05_IRONB", ["철사"]), [], "[수리 25] 철사로 빗장을 조용히 든다")
	t.eq(_v(st, "SQ_S05_DOOR"), 1, "철문 열림")
	t.eq(_v(st, "SQ_S05_WOKE"), 0, "소리 없이")
	h.enter("U-02", "from_W")
	t.eq(st.quests.stage("SQ-S05"), 40, "서울대입구 쪽에서 먼저 → 10 → 40")
	var gs := _alive(h, "CR-204")
	t.eq(gs.size(), 10, "승강장 손님 열(선로 위 둘)")
	t.ok(gs.all(func(e): return e.asleep and e.doze in ["sit", "lie"]), "모두 앉거나 누워 존다")
	t.eq(_alive(h, "CR-205").size(), 1, "역무원 하나")
	t.ok(st.quests.stage("SQ-S05") < 50, "해법 전")


func test_sq_s05_cluster_wake(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "U-02", "from_E")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	var gs := _alive(h, "CR-204")
	gs[3].wake()
	t.ok(gs.all(func(e): return not e.asleep), "하나가 깨면 무리가 한꺼번에(일제 기상)")
	t.ok(_v(st, "SQ_S05_WOKE") > 0, "깬 시각")
	c._calm_tick()
	t.ok(gs.all(func(e): return e.cmb.team == "enemy_s05" and "player" in e.foes), "가면 없음: 적대")
	st.call_fn("give", ["A-106", 1])
	h.wear("A-106")
	t.eq(str(st.vars.get_v("PC_EYES")), "A-106", "구울 가면을 썼다")
	c._calm_tick()
	t.ok(gs.all(func(e): return e.cmb.team == "calm_s05" and e.foes.is_empty()), "가면: 깬 손님도 비적대")
	h.wear("A-106")
	t.eq(str(st.vars.get_v("PC_EYES")), "", "다시 고르면 벗는다")
	h.date_text = "2277. 10. 26.  13:00"
	h.enter("U-02", "from_E")
	t.ok(_alive(h, "CR-204").all(func(e): return not e.asleep), "세 시간 뒤: 아직 서 있다")
	h.date_text = "2277. 10. 26.  17:00"
	h.enter("U-02", "from_E")
	t.ok(_alive(h, "CR-204").all(func(e): return e.asleep), "여섯 시간 뒤: 다시 앉았다(다음 방문)")
	t.eq(_v(st, "SQ_S05_WOKE"), 0, "깬 시각 지움")


func test_sq_s05_doze_rules(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "U-02", "from_E")
	var h: InteriorHost = r[0]
	var gs := _alive(h, "CR-204")
	var e: Enemy = gs[0]
	var pc := h.combat.pc
	var step := func() -> void:
		e._t_per = 1.0
		e.think(0.01, pc, h.map, h.combat.shots)
	h.player.loco.place(e.loco.logical + Vector2(1.6 * 32.0, 0))
	pc.posture = "crouch"
	pc.movement = "sneak"
	step.call()
	t.ok(e.asleep, "웅크려 1.6칸: 그대로 존다")
	h.player.loco.place(e.loco.logical + Vector2(0.8 * 32.0, 0))
	pc.sneak = 60.0
	step.call()
	t.ok(e.asleep, "은신 60 · 웅크려 0.8칸: 그대로 존다(반 칸까지)")
	h.player.loco.place(e.loco.logical + Vector2(1.6 * 32.0, 0))
	pc.posture = "stand"
	pc.movement = "move"
	step.call()
	t.ok(not e.asleep, "서서 걸어 2칸 안: 깬다")
	t.ok(gs.all(func(x): return not x.asleep), "그리고 무리 전체")


func test_sq_s05_staff_ticket(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "U-02", "from_E")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	var s: Enemy = _alive(h, "CR-205")[0]
	t.eq(s.cmb.team, "calm_s05", "역무원: 처음엔 순찰만")
	h.player.loco.place(s.loco.logical + Vector2(64, 0))
	c._staff_tick()
	t.eq(s.say_text, "승차권을 확인합니다.", "3칸 안: '승차권을 확인합니다'")
	t.eq(s.cmb.team, "calm_s05", "바로 치지 않는다")
	for i in 6:
		c._staff_tick()
	t.eq(s.cmb.team, "enemy_s05", "표 없이 버티면 경광봉")
	var r2 := _host("2277. 10. 26.  10:00", "U-02", "from_E")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: SideS05 = r2[2]
	st2.call_fn("give", ["M-071", 1])
	var s2: Enemy = _alive(h2, "CR-205")[0]
	h2.player.loco.place(s2.loco.logical + Vector2(64, 0))
	for i in 8:
		c2._staff_tick()
	t.eq(s2.cmb.team, "calm_s05", "정기권: 비켜선다")
	t.ok(_says(st2, c2, "SQS05_GATES", "초록 불"), "개찰구: 정기권을 대면 초록 불")


func test_sq_s05_sol_a_line(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "U-01", "from_E")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	st.vars.set_v("PC_ST", 6)
	var t0 := Clock.abs_min(h.date_text)
	t.eq(_play(st, c, "SQS05_ROBOT", ["끌고"]), [], "[힘 5] 파수-3을 끌고 간다")
	t.eq(_v(st, "SQ_S05_ROBOT"), 2, "역무실에 세움")
	t.eq(Clock.abs_min(h.date_text) - t0, 30, "삼십 분이 흐른다")
	h.enter("D-03", "from_D-02")
	t.ok(_says(st, c, "SD_BROADCAST", "케이블 한 가닥"), "방송 설비: 파수-3 가슴 칸")
	st.vars.set_v("PC_SKP_REPAIR", 30)
	t.eq(_play(st, c, "SD_BROADCAST", ["케이블"]), [], "[수리 25] 방송")
	t.eq(_v(st, "SQ_S05_BCAST"), 1, "혼자 방송(무단)")
	t.ok(_says(st, c, "SD_HUH", "누가 방송했어"), "허순자: '누가 방송했어'")
	t.ok(_says(st, c, "SQS05_ROBOT", "매시 정각"), "역무실 파수-3 화면: 매시 정각")
	var k0 := _v(st, "V_KARMA")
	h.enter("U-02", "from_E")
	t.ok(not c.proc.is_empty(), "24시간 안에 승강장: 행렬이 시작된다")
	t.eq(_alive(h, "CR-204").size(), 0, "손님은 연출 인물로(아무도 공격하지 않는다)")
	_walk_line(h, c)
	t.eq(_v(st, "SQ_S05_LINE"), 1, "행렬을 봤다")
	t.eq(_v(st, "SQ_S05_SOL"), 1, "해법 A")
	t.eq(st.quests.stage("SQ-S05"), 50, "→ 50")
	t.eq(_v(st, "V_KARMA") - k0, 100, "카르마 +100(모두 들어감)")
	t.eq(_alive(h, "CR-205").size(), 0, "역무원도 맨 마지막에 들어갔다")
	h.enter("U-02", "from_E")
	t.eq(_alive(h, "CR-204").size() + _alive(h, "CR-205").size(), 0, "다시 와도 빈 승강장")
	t.ok(_says(st, c, "SQS05_SIDING", "내린 손님들"), "측선 셔터 안: 내린 손님들")
	h.enter("D-06", "from_U01")
	t.ok(_says(st, c, "SD_FENCE", "손님 없음"), "철망: '손님 없음'")
	t.ok(_says(st, c, "SD_HUH", "잘했어"), "허순자: 행렬 소식 뒤 '…잘했어'")
	var caps := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "SD_HUH", ["서쪽 터널이 비었어요"], "ASK"), [], "보고")
	t.eq(st.quests.stage("SQ-S05"), 100, "→ 100")
	t.eq([st.count_of("M-071"), _v(st, "PC_CAPS") - caps], [1, 100], "보상: 정기권(서랍에서) · 100캡")
	t.eq(_v(st, "SD_MAP_UG"), 2, "노선도 서쪽 칸")
	t.ok(_says(st, c, "SD_RUNBOARD", "막차 끝남"), "칠판 '막차 끝남'")


func test_sq_s05_line_broken(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "D-03", "from_D-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	st.vars.set_v("SQ_S05_ROBOT", 2)
	t.eq(_play(st, c, "SD_HUH", ["방송 설비를 써도"], "ASK"), [], "미리 물으면 허순자가 스위치를")
	t.eq(_v(st, "SQ_S05_BCAST"), 2, "허순자 방송")
	t.ok(not _says(st, c, "SD_HUH", "누가 방송했어"), "허락받은 방송엔 꾸중 없다")
	var k0 := _v(st, "V_KARMA")
	h.enter("U-02", "from_E")
	_walk_line(h, c, 3)
	t.ok(c.proc.is_empty(), "행렬이 깨졌다")
	var left := _alive(h, "CR-204")
	t.ok(left.size() >= 1 and left.size() <= 9, "아직 측선에 들지 못한 손님이 깨어 적대(%d)" % left.size())
	t.ok(left.all(func(e): return not e.asleep and e.cmb.team == "enemy_s05"), "적대")
	var gain := _v(st, "V_KARMA") - k0
	t.eq(gain, 10 * _v(st, "SQ_S05_ENT"), "카르마는 측선에 든 손님마다 +10(%d)" % gain)
	t.eq([_v(st, "SQ_S05_LINE"), _v(st, "SQ_S05_SOL")], [0, 0], "반쯤 — 해법은 아직(세계가 '손님 없음'이라 하지 않는다)")
	t.ok(_v(st, "SQ_S05_REMAIN") > 0, "남은 손님 수")
	t.ok(_says(st, c, "SD_FENCE", "발소리가 줄었다"), "철망: 발소리가 줄었다")
	t.ok(_says(st, c, "SQS05_SIGN", "손님 — "), "표지: 남은 손님 수")
	h.date_text = "2277. 10. 26.  18:00"
	h.enter("U-02", "from_E")
	t.ok(not c.proc.is_empty(), "다시 앉은 손님은 다음 방문에 줄을 선다(방송은 계속)")
	_walk_line(h, c)
	t.eq([_v(st, "SQ_S05_LINE"), _v(st, "SQ_S05_SOL"), _v(st, "SQ_S05_REMAIN")], [1, 1, 0], "두 번째 행렬로 마무리: 해법 A")
	t.eq(_v(st, "V_KARMA") - k0, 100, "모두 들어가면 +100")


func test_sq_s05_line_offscreen(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "D-03", "from_D-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	st.vars.set_v("SQ_S05_ROBOT", 2)
	_play(st, c, "SD_HUH", ["방송 설비를 써도"], "ASK")
	h.date_text = "2277. 10. 27.  11:00"
	c._process(1.0)
	t.eq(_v(st, "SQ_S05_LINE"), 2, "24시간이 지나도록 안 내려감: 결과만")
	t.eq(_v(st, "SQ_S05_SOL"), 1, "해법 A")
	h.enter("U-02", "from_E")
	t.eq(_alive(h, "CR-204").size(), 0, "승강장이 비었다")
	t.ok(c.proc.is_empty(), "행렬은 없다")


func test_sq_s05_sol_b(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "U-02", "from_E")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	var all: Array = _alive(h, "CR-204") + _alive(h, "CR-205")
	for e in all.slice(0, all.size() - 1):
		e.cmb.dead = true
		c._on_down(e)
	t.eq(_v(st, "SQ_S05_SOL"), 0, "하나 남음 — 아직")
	all[all.size() - 1].cmb.dead = true
	c._on_down(all[all.size() - 1])
	t.eq(_v(st, "SQ_S05_SOL"), 2, "모두 쓰러짐: 해법 B")
	t.eq(st.quests.stage("SQ-S05"), 50, "→ 50")
	h.enter("U-02", "from_E")
	t.eq(_alive(h, "CR-204").size(), 0, "다시 서지 않는다")


func test_sq_s05_sol_c_ju(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	st.quests.set_stage("SQ-S05", 20)
	st.vars.set_v("AFF_JH", 25)
	t.eq(_play(st, c, "MQ-102_JU", ["사당 서쪽", "같은 지하시장"]), [], "주성호에게 부탁(JH 우호)")
	t.eq(_v(st, "SQ_S05_JU"), 2, "같이 간다")
	t.ok(not h.combat.mates.get_mate("N-R02-018").is_empty(), "일시 동행")
	t.eq(_v(st, "SQ_S05_AWAY"), 1, "봉천 노점은 비운다(한 사람 한 곳)")
	var k0 := _v(st, "V_KARMA")
	h.enter("U-03", "from_W")
	h.enter("U-02", "from_W")
	t.eq(_alive(h, "CR-204").size(), 5, "봉천행 표의 절반이 떠나고 절반이 남는다")
	t.eq([_v(st, "SQ_S05_SOL"), _v(st, "SQ_S05_REMAIN"), _v(st, "SQ_S05_DOOR")], [0, 5, 1], "반쯤 — 해법은 남은 손님까지 · 주성호가 빗장을 들었다")
	t.ok(_says(st, c, "SQS05_SIDING", "남은 손님들은 아직"), "측선 문: 남은 손님들")
	t.eq(_v(st, "V_KARMA") - k0, 50, "카르마 +50")
	t.eq(_v(st, "SQ_S05_JU"), 3, "주성호는 봉천으로")
	t.ok(h.combat.mates.get_mate("N-R02-018").is_empty(), "동행 끝")
	for e in _alive(h, "CR-204") + _alive(h, "CR-205"):
		e.cmb.dead = true
		c._on_down(e)
	t.eq(_v(st, "SQ_S05_SOL"), 3, "남은 절반을 쓰러뜨리면 C로 마친다")
	t.eq(st.quests.stage("SQ-S05"), 50, "→ 50")
	t.ok(_says(st, c, "SQS05_SIGN", "주성호 인솔"), "표지: 봉천행 하차 — 주성호 인솔")
	t.ok(_says(st, c, "SD_HUH", "구울 행상이 내려갔다고", ["서쪽 터널이 비었어요"], "ASK"), "보고: 구울 행상 판")
	st.vars.set_v("GAME_DAY", 5)
	c._on_day(5)
	t.eq(_v(st, "SQ_S05_AWAY"), 0, "다음 날 노점으로 돌아왔다")
	var other := SideS05.new()
	other.host = h
	other.st = h.st
	t.eq(range(10).filter(func(i): return other._bongcheon(i)).size(), 5, "봉천행 표는 열 중 다섯")
	var picks := range(10).filter(func(i): return other._bongcheon(i))
	st.vars.set_v("P_REGNO", "S07-2260-0007")
	t.ok(range(10).filter(func(i): return other._bongcheon(i)) != picks, "주인공(등록 번호)마다 다른 다섯")


func test_sq_s05_ju_quits(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	st.quests.set_stage("SQ-S05", 20)
	st.call_fn("caps", [60])
	t.eq(_play(st, c, "MQ-102_JU", ["사당 서쪽", "하루 벌이"]), [], "[캡 50] 부탁")
	t.eq(_v(st, "SQ_S05_JU"), 2, "동행")
	st.vars.set_v("GAME_DAY", 6)
	c._on_day(6)
	t.eq([_v(st, "SQ_S05_JU"), _v(st, "SQ_S05_AWAY")], [0, 1], "이틀 기다리다 봉천으로(처음으로 — 반쯤 된 상태 없음)")
	t.ok(h.combat.mates.get_mate("N-R02-018").is_empty(), "동행 풀림")
	st.vars.set_v("GAME_DAY", 7)
	c._on_day(7)
	t.eq(_v(st, "SQ_S05_AWAY"), 0, "다음 날 노점")
	t.ok(_opts(st, "MQ-102_JU").any(func(o): return str(o).contains("손님들한테 말 좀")), "다시 부탁할 수 있다")


func test_sq_s05_lend_pass(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "D-03", "from_D-02")
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	st.quests.set_stage("SQ-S05", 10)
	t.ok(_says(st, c, "SD_HUH", "물 한 통 채워 줘", ["정기권, 지금"], "ASK"), "허순자: 공짜는 아니고 — 물 한 통")
	st.call_fn("give", ["I-054", 1])
	t.eq(_play(st, c, "SD_HUH", ["정기권, 지금", "물 한 통을"], "ASK"), [], "물 한 통을 채운다")
	t.eq([st.count_of("I-054"), st.count_of("M-071"), _v(st, "SQ_S05_PASS")], [0, 1, 1], "물을 주고 정기권을 빌림")
	var b := {"x": 5, "y": 6, "w": 1, "h": 1, "kind": "sd_drawer", "owner": "N-R01-041", "name": "역무실 서랍"}
	t.ok(not (Loot.contents(st, "D-03", b, "r01")["items"] as Dictionary).has("M-071"), "서랍엔 정기권이 없다(한 장뿐)")
	st.vars.set_v("SQ_S05_SOL", 2)
	var caps := _v(st, "PC_CAPS")
	c._report()
	t.eq([st.count_of("M-071"), _v(st, "PC_CAPS") - caps], [1, 130], "보상: 이미 있으면 30캡 더")


func test_sq_s05_huh_dead(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "D-06", "from_U01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	st.quests.set_stage("SQ-S05", 40)
	st.vars.set_v("SQ_S05_SOL", 2)
	st.vars.set_v("SQ_S05_IN", 1)
	st.dead["N-R01-041"] = true
	h.enter("D-03", "from_D-02")
	t.eq(_v(st, "SQ_S05_REPORT"), 1, "허순자가 없으면 위원회 쪽지로 보고")
	t.eq(st.quests.stage("SQ-S05"), 100, "→ 100")
	t.ok(_says(st, c, "SD_RUNBOARD", "위원회"), "칠판: 낯선 글씨 '— 위원회'")


func test_sq_s05_already_know(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "D-06", "from_U01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	t.eq(st.quests.stage("SQ-S05"), 0, "모르면 열리지 않는다")
	st.vars.set_v("SA_MAKCHA_HEARD", 1)
	h.enter("D-03", "from_D-02")
	t.eq(st.quests.stage("SQ-S05"), 10, "이미 앎(성지후 · 허순자에게 들음): 사당에 들어서는 순간 10")


func test_sq_s05_ju_with_broadcast(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	st.quests.set_stage("SQ-S05", 30)
	st.vars.set_v("AFF_JH", 25)
	_play(st, c, "MQ-102_JU", ["사당 서쪽", "같은 지하시장"])
	st.vars.set_v("SQ_S05_ROBOT", 2)
	c._cmd(["broadcast", "2"], func() -> void: pass)
	var k0 := _v(st, "V_KARMA")
	h.enter("U-03", "from_W")
	h.enter("U-02", "from_W")
	t.ok(not c.proc.is_empty(), "해 보고 싶은 짓: 방송을 켠 채 주성호와 — 봉천행은 서쪽으로, 나머지는 측선 행렬")
	_walk_line(h, c)
	t.eq([_v(st, "SQ_S05_SOL"), _v(st, "SQ_S05_ENT"), _v(st, "SQ_S05_EMPTY")], [3, 5, 1], "한 번에 갈라진다 — 해법 C(주성호가 말했다)")
	t.eq(_v(st, "V_KARMA") - k0, 100, "카르마: 주성호 +50 · 측선 다섯 +50")


func test_sq_s05_doors(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "U-03", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	st.vars.set_v("PC_ST", 7)
	t.ok(_says(st, c, "SQS05_IRONB", "여럿이 한꺼번에", ["쇠막대"]), "쇠막대: 쩡 — 저편에서 일어나는 소리")
	h.enter("U-02", "from_W")
	t.ok(_alive(h, "CR-204").all(func(e): return not e.asleep), "그래서 들어서면 이미 서 있다")
	var r2 := _host("2277. 10. 26.  10:00", "U-02", "from_W")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: SideS05 = r2[2]
	st2.vars.set_v("PC_SKP_REPAIR", 30)
	t.eq(_play(st2, c2, "SQS05_IRON", ["기름 먹인 천"]), [], "낙성대 쪽: [수리 25] 조용히 뽑기")
	t.ok(_alive(h2, "CR-204").all(func(e): return e.asleep), "아무도 깨지 않는다")
	var r3 := _host("2277. 10. 26.  10:00", "U-02", "from_W")
	var h3: InteriorHost = r3[0]
	var st3: StoryState = r3[1]
	var c3: SideS05 = r3[2]
	t.eq(_play(st3, c3, "SQS05_IRON", ["소리가 난다"]), [], "그냥 뽑기")
	t.ok(_alive(h3, "CR-204").all(func(e): return not e.asleep), "쇳소리: 승강장 전체가 일어난다")


func test_sq_s05_huh_clock_seen(t) -> void:
	var r := _host("2277. 10. 26.  06:05", "D-03", "from_D-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	c._wind_tick()
	t.eq(_v(st, "SQ_S05_WIND"), 1, "06:05: 태엽 시각")
	h.refresh_npcs()
	var a: Actor = h.ev.actors.get("N-R01-041")
	t.ok(a != null and h.map.tile_of(a.loco.logical) == Vector2i(3, 3), "허순자가 벽시계 앞에서 등을 돌린다")
	h.player.loco.place(Vector2(6 * 32 + 16, 7 * 32 + 16))
	t.eq(h.theft_witness(), "", "서랍 곁 — 보는 사람 없음(반로아가 판 시각)")
	h.date_text = "2277. 10. 26.  06:20"
	c._wind_tick()
	t.eq(_v(st, "SQ_S05_WIND"), 0, "06:20: 책상으로 돌아왔다")
	t.eq(h.theft_witness(), "N-R01-041", "이제는 본다")
	st.vars.set_v("SQ_S05_ROBOT", 2)
	st.vars.set_v("PC_SKP_REPAIR", 30)
	_play(st, c, "SD_BROADCAST", ["케이블"])
	t.eq(_v(st, "SQ_S05_SEEN"), 1, "허순자 눈앞에서 방송")
	t.ok(_says(st, c, "SD_HUH", "지금 내 앞에서"), "허순자: '지금 내 앞에서 그걸 올려?'")


func test_sq_s05_ban_guide(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "D-02", "from_D-03")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS05 = r[2]
	st.vars.set_v("SQ_S05_SOL", 1)
	st.vars.set_v("PC_CAPS", 50)
	var t0 := Clock.abs_min(h.date_text)
	t.ok(_says(st, c, "SD_BAN", "봉천 사다리 앞에 내려 줄게", ["터널은 어때"], "ASK"), "반로아: 해결 뒤 서쪽 안내")
	c._cmd(["guide"], func() -> void: pass)
	t.eq(Clock.abs_min(h.date_text) - t0, 60, "지하 안내: 한 시간")
