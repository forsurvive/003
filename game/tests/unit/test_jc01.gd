## 단계 1-12a FQ-JC-01 「계단 물길」(SD-04d §10.3, 계획 docs/seoul-fallout/_plans/1-12a_FQ-JC-01_plan.md §2 · §4):
## 발동(MQ-101 + 4일 06시 · S02와 따로) · 수위 한 곳(min(윗물, 빗물)) · 게시판 · 조만석 · 조담희 · 홈통 · 백구(동행 · 물러남 · 때림 · 앞장) ·
## 갈림(백구 · 인지력 · 당번표) · 흙막이(메움 · 나눔 · 웅덩이로) · 둥지 · 유입구 균열(먼저 고침 · 뒤에 드러남) · 끝(사례 · 적대 · 하숙자 · 아무도 없음) · 고유 무기 W-101.
extends RefCounted


func _host(map_id := "X-BC", mark := "from_X-S07", day := 4) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", day)
	st.vars.set_v("GAME_HOUR", 10)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 27.  10:00"
	var s2 := SideS02.new()
	s2.setup(h)
	var c := FqJc01.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c, s2]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 원고를 끝까지(또는 picks 차례로 고르며): jc01 명령은 진행기로. 마지막 칸은 '말:' + 지나간 줄
func _play(st: StoryState, c: FqJc01, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "jc01":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				i = -1
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])) and bool(cur["opts"][j]["enabled"]):
						i = j
						break
				k += 1
			else:
				i = cur["opts"].size() - 1
			if i < 0:
				return dr.errors + ["선택지 없음: %s" % str(picks[k - 1])]
			cur = dr.choose(i)
		else:
			if cur.has("text"):
				said.append(str(cur["text"]))
			cur = dr.advance()
	return dr.errors + ["말:" + " / ".join(said)]


func _ok(r: Array) -> bool:
	return r.size() == 1 and str(r[0]).begins_with("말:")


func _says(st: StoryState, c: FqJc01, id: String, needle: String, picks: Array = []) -> bool:
	var r := _play(st, c, id, picks)
	return _ok(r) and str(r[0]).contains(needle)


## 흙막이가 생긴 날까지(MQ-101 4일 끝 → 8일 06시)
func _cut(st: StoryState, c: FqJc01, s2: SideS02) -> void:
	c.tick()
	for d in [5, 6, 7, 8]:
		st.vars.set_v("GAME_DAY", d)
		c._on_day(d)
		s2._on_day(d)
	s2.tick()


func test_jc01_trigger_level(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	var s2: SideS02 = r[3]
	c.tick()
	t.eq(_v(st, "FQ_JC01_ARM"), 4, "MQ-101이 끝난 날을 적는다")
	st.vars.set_v("GAME_DAY", 7)
	c._on_day(7)
	t.eq(_v(st, "FQ_JC01_CUT"), 0, "사흘째까지는 아직")
	t.ok(_says(st, c, "FQJC01_SPOUT", "졸졸"), "흙막이 전 홈통: 물이 흐른다")
	t.eq(s2.level(), 5, "흙막이 전 수위 다섯")
	st.vars.set_v("GAME_DAY", 8)
	c._on_day(8)
	t.eq(_v(st, "FQ_JC01_CUT"), 8, "넷째 날 06시: 7동 물당번의 흙막이")
	t.eq(st.quests.stage("FQ-JC-01"), 0, "흙막이만 생겼다 — 알아야 10")
	t.eq([s2.level(), _v(st, "FQ_JC01_BASE"), _v(st, "FQ_JC01_CAP")], [3, 5, 3], "윗물은 그대로, 빗물 몫 3 — 수위 셋(S02와 따로)")
	t.ok(_says(st, c, "SQS02_GAUGE", "셋째 칸"), "수위계: 아랫물 끊김(누구 탓인지 가른다)")
	t.ok(_says(st, c, "SQS02_SUAN", "셋에서 안 올라"), "S02 전 조수안: 수로가 끊겼다")
	t.eq(str(h.scene_for("C-010").get("id", "")), "FQJC01_JO", "조만석에게 말을 걸면 부탁")
	# S02가 같이 닫히면 둘이 겹친다(P1 한 곳)
	st.vars.set_v("SQ_S02_POSTED", 1)
	st.vars.set_v("SQ_S02_DAY0", 8)
	st.vars.set_v("SQ_S02_HEARD", 1)
	s2.tick()
	t.eq([_v(st, "SQ_S02_LEVEL"), _v(st, "FQ_JC01_BASE")], [3, 4], "윗물 4 · 빗물 3 → 셋")
	t.ok(_says(st, c, "SQS02_SUAN", "양쪽에서", ["됐어"]), "조수안: 윗물은 패거리, 아랫물은 끊김")
	t.ok(_says(st, c, "FQJC01_JO", "위아래로 다 막혔지", ["가 볼게"]), "조만석: 두 원인을 같이 말한다(조수안과 다른 말씨)")
	t.eq(_v(st, "FQ_JC01_POSTED"), 2, "들었다")
	t.eq(st.quests.stage("FQ-JC-01"), 10, "단계 10")
	t.eq(str(h.scene_for("C-010").get("id", "")), "ZJC01_JO", "그 뒤엔 진행 중 대화")
	h.free()


func test_jc01_board_spout_damhee(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	var s2: SideS02 = r[3]
	_cut(st, c, s2)
	t.ok(_says(st, c, "X-BC_BOARD", "빗물 당번표"), "게시판: 이장 쪽지 + 빗물 당번표")
	t.eq([_v(st, "FQ_JC01_POSTED"), _v(st, "FQ_JC01_ROSTER"), _v(st, "FQ_JC01_PERC"), st.quests.stage("FQ-JC-01")], [1, 1, 0, 10], "게시판 → 단계 10 · 당번표(ROSTER — 인지력으로 읽은 것과 따로)")
	t.ok(_says(st, c, "FQJC01_SPOUT", "바짝 말랐다"), "홈통: 말랐다 · 흙 자국")
	t.eq(_v(st, "FQ_JC01_SPOUT"), 1, "홈통을 봤다")
	# 조담희: S02를 끝냈고 아직 모를 때만
	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: FqJc01 = r2[2]
	_cut(st2, c2, r2[3])
	st2.quests.set_stage("SQ-S02", 100)
	st2.vars.set_v("SQ_S02_REWARD", 1)
	t.eq(str((r2[0] as InteriorHost).scene_for("N-R01-029").get("id", "")), "FQJC01_DAMHEE", "조담희: 밸브는 됐고, 이제 빗물")
	t.ok(_says(st2, c2, "FQJC01_DAMHEE", "이제 빗물"), "조담희 장면")
	t.eq(st2.quests.stage("FQ-JC-01"), 10, "조담희에게 들어도 10")
	h.free()
	(r2[0] as InteriorHost).free()


func test_jc01_dog(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	_cut(st, c, r[3])
	c.start()
	t.eq(str(h.scene_for("C-015").get("id", "")), "FQJC01_BAEK", "퀘스트 중 백구: 흙 냄새")
	t.ok(_ok(_play(st, c, "FQJC01_BAEK", ["가자"])), "백구가 따라나선다")
	t.eq(_v(st, "FQ_JC01_DOG"), 1, "동행")
	t.ok(not c._dog_mate().is_empty(), "동행 목록에 백구")
	t.eq(st.quests.stage("FQ-JC-01"), 20, "백구가 앞장 — 단계 20")
	t.ok(_says(st, c, "FQJC01_FORK1", "앞발로 흙을 판다", ["판 자리"]), "첫 갈림: 백구가 갈래마다 다르게 군다")
	t.eq(_v(st, "FQ_JC01_FORK1"), 1, "판 자리를 골랐다")
	var m := c._dog_mate()
	(m["cmb"] as Combatant).hp = (m["cmb"] as Combatant).max_hp * 0.15
	c.tick()
	t.eq(_v(st, "FQ_JC01_DOG"), 2, "20% 아래: 물러나 마을로(죽지 않는다)")
	t.ok(h.npcs.any(func(n): return str(n["id"]) == "C-015"), "봉천 개집에 다시 선다")
	t.ok(_ok(_play(st, c, "FQJC01_BAEK", ["가자"])), "다시 데려갈 수 있다")
	var bc0 := _v(st, "AFF_JC_BC")
	var k0 := _v(st, "V_KARMA")
	m = c._dog_mate()
	c.tick()
	(m["cmb"] as Combatant).last_by = "player"
	(m["cmb"] as Combatant).hit.emit()
	t.eq([_v(st, "FQ_JC01_DOG"), _v(st, "FQ_JC01_BETRAY")], [4, 1], "때렸다 — 달아남")
	t.eq([_v(st, "AFF_JC_BC") - bc0, _v(st, "V_KARMA") - k0], [-10, -25], "봉천 −10 · 카르마 −25")
	t.ok(str(h.scene_for("C-015").get("id", "")) != "FQJC01_BAEK", "다시는 따라오지 않는다")
	h.free()


func test_jc01_dog_guide_when_full(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	_cut(st, c, r[3])
	c.start()
	for id in ["N-R01-029", "N-R01-030"]:                                  # 동행 둘(상한)
		var a: Actor = h.ev.actors.get(id)
		if a != null:
			h.combat.mates.add(id, a, id)
	t.eq(h.combat.mates.list.size(), 2, "동행 둘")
	_play(st, c, "FQJC01_BAEK", ["가자"])
	t.eq(_v(st, "FQ_JC01_DOG"), 5, "동행 칸이 없으면 먼저 달려 나가 암거 앞에서 기다린다(앞장)")
	t.ok(not h.npcs.any(func(n): return str(n["id"]) == "C-015"), "봉천 개집은 비었다")
	t.ok(_says(st, c, "FQJC01_FORK1", "먼저 달려간 자국"), "앞장 백구는 갈림에 없다 — 먼저 찍힌 발자국(한 몸 두 곳 없음)")
	t.eq(_v(st, "FQ_JC01_FORK1"), 1, "발자국을 따라 맞는 길")
	h.free()


func test_jc01_no_dog_paths(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	_cut(st, c, r[3])
	st.kill("C-015")
	c.start()
	t.ok(_says(st, c, "FQJC01_JO", "백구가 있었으면", ["가 볼게"]), "백구가 죽었으면: 담희의 빗물 당번표")
	st.vars.set_v("PC_PE", 4)
	var r1 := _play(st, c, "FQJC01_FORK1", ["서쪽"])
	t.ok(_ok(r1) and str(r1[0]).contains("담배") and str(r1[0]).contains("남쪽 비탈 쪽으로"), "헛길: 서쪽 골목 담배 냄새 — 꽁초가 쉼터 쪽으로")
	t.eq(_v(st, "FQ_JC01_FORK1"), 3, "헛길을 골랐다")
	t.ok(_says(st, c, "FQJC01_SHELTER", "비탈 아래 계곡 암거 입구"), "쉼터 터: 근무표 — 누가 · 어디서 하는지 안다(헛길도 정답에 닿음)")
	t.eq(_v(st, "FQ_JC01_KNOW"), 1, "7동을 안다")
	st.vars.set_v("PC_PE", 7)
	t.ok(_says(st, c, "FQJC01_FORK1", "덜 마른 흙", ["인지력", "남쪽"]), "[인지력 6] 자국의 결을 읽는다")
	t.eq(_v(st, "FQ_JC01_FORK1"), 1, "맞는 길")
	t.ok(_says(st, c, "FQJC01_FORK2", "같은 마대 끈"), "둘째 갈림: 읽은 결로 곧장")
	t.eq([_v(st, "FQ_JC01_FORK2"), st.quests.stage("FQ-JC-01")], [1, 20], "단계 20")
	h.free()


func test_jc01_fill_leak_fix_done(t) -> void:
	var r := _host("K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	var s2: SideS02 = r[3]
	_cut(st, c, s2)
	h.enter("K-08", "from_W")
	c.tick()
	c.tick()
	t.eq(c._nest.size(), 3, "둥지 쥐 셋(흙막이가 생긴 뒤에만)")
	t.ok(_says(st, c, "FQJC01_BUCKET", "7동 물당번 일동"), "물통 줄: 호실 번호 · 쪽지")
	t.eq([_v(st, "FQ_JC01_KNOW"), st.quests.stage("FQ-JC-01")], [1, 0], "쪽지만 읽음 — 아직 퀘스트는 모른다(물통은 단서일 뿐)")
	st.vars.set_v("PC_ST", 7)
	var k0 := _v(st, "V_KARMA")
	t.ok(_says(st, c, "FQJC01_DAM", "물이 돌아 들어간다", ["힘 6] 마대를 끌어내"]), "흙막이를 다 메운다")
	t.eq([_v(st, "FQ_JC01_FLOW"), _v(st, "V_KARMA") - k0], [1, -10], "물길 1 · 카르마 −10(7동 물통이 마른다)")
	t.eq(st.quests.stage("FQ-JC-01"), 30, "먼저 가서 메워도 따라 올린다(P2)")
	s2.tick()
	t.eq([_v(st, "FQ_JC01_CAP"), s2.level()], [4, 4], "균열이 남아 한 칸 모자라다")
	t.ok(_says(st, c, "FQJC01_BUCKET", "말라 간다"), "물통 줄이 마른다")
	h.enter("X-BS", "arrive")
	t.eq([_v(st, "FQ_JC01_LEAK"), st.quests.stage("FQ-JC-01")], [1, 40], "배수지에 들어서면 새는 소리 — 단계 40")
	t.ok(_says(st, c, "SQS02_GAUGE", "샌다"), "수위계: 한 칸 모자라게 떤다")
	st.vars.set_v("PC_SKP_REPAIR", 100)
	t.ok(_says(st, c, "FQJC01_INLET", "조용해졌다", ["수리 50"]), "[수리 50] 이음매를 다시 물린다")
	s2.tick()
	t.eq([_v(st, "FQ_JC01_CRACK"), s2.level()], [1, 5], "균열 고침 — 다섯 칸")
	t.eq(str(h.scene_for("C-010").get("id", "")), "FQJC01_DONE", "조만석에게 보고")
	st.vars.set_v("AFF_JC_BC", 10)
	var caps0 := _v(st, "PC_CAPS")
	var xp0 := _v(st, "PC_XP")
	t.ok(_says(st, c, "FQJC01_DONE", "아래서 위로 사는 동네"), "조만석: 물은 위에서 아래로")
	t.eq([st.quests.stage("FQ-JC-01"), _v(st, "AFF_JC_BC"), _v(st, "PC_CAPS") - caps0, _v(st, "PC_XP") - xp0], [100, 22, 50, 250], "끝 · 봉천 +12 · 50캡 · 250 XP")
	t.eq(st.count_of("I-056"), 2, "메움: 반상회가 챙겨 둔 약수 두 병")
	t.ok(st.count_of("W-101") == 1 and st.count_of("M-136") == 1, "봉천 우호(22): 이장님의 엽총 · 계단마을 증표")
	t.ok(_says(st, c, "FQJC01_SPOUT", "물소리가 돌아왔다"), "홈통에 물소리")
	h.free()


func test_jc01_split_breach_nest(t) -> void:
	var r := _host("K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	var s2: SideS02 = r[3]
	_cut(st, c, s2)
	h.enter("K-08", "from_W")
	c.tick()
	c.tick()
	st.vars.set_v("PC_ST", 7)
	t.ok(_says(st, c, "FQJC01_NEST", "어미가 있다"), "왕쥐가 살아 있으면 어미 울음")
	t.ok(_says(st, c, "FQJC01_DAM", "물소리에 묻힌다", ["한쪽만 터서"]), "한쪽만 터서 둥지를 쓸어 버린다")
	t.eq([_v(st, "FQ_JC01_NEST"), _v(st, "FQ_JC01_FLOW")], [2, 0], "둥지는 떠내려감 · 물길은 아직")
	t.eq(h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == "CR-095" and h.map.tile_of(e.loco.logical).x < FqJc01.NEST_X).size(), 0, "둥지 쥐가 빠졌다(싸움 없이)")
	st.vars.set_v("PC_SKP_REPAIR", 100)
	var k0 := _v(st, "V_KARMA")
	t.ok(_says(st, c, "FQJC01_VALVE", "두 줄기", ["수리 50"]), "분배함 밸브로 반씩")
	t.eq([_v(st, "FQ_JC01_FLOW"), _v(st, "V_KARMA") - k0], [2, 25], "나눔 · 카르마 +25")
	t.ok(_says(st, c, "FQJC01_BUCKET", "반쯤 찼다"), "7동 물통에 반씩")
	t.ok(_says(st, c, "FQJC01_DAM", "두 줄기로 갈라져"), "흙막이: 이미 나눴다(다시 고르지 않는다)")
	st.vars.set_v("FQ_JC01_CRACK", 1)
	s2.tick()
	t.eq(s2.level(), 4, "나눔: 넷에서 선다")
	t.ok(_says(st, c, "SQS02_GAUGE", "고시원과 나눔"), "수위계 분필")
	t.ok(_says(st, c, "FQJC01_SPOUT", "반 줄기"), "홈통 물 반 줄기")
	h.free()


func test_jc01_nest_kill_and_early_fix(t) -> void:
	var r := _host("K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	var s2: SideS02 = r[3]
	_cut(st, c, s2)
	h.enter("K-08", "from_W")
	c.tick()
	c.tick()
	for e in c._nest:
		e.cmb.dead = true
	c.tick()
	t.eq(_v(st, "FQ_JC01_NEST"), 1, "둥지 쥐 셋을 쓰러뜨림 — 처치")
	t.ok(_says(st, c, "FQJC01_NEST", "빈 둥지"), "빈 둥지")
	# 유입구를 물이 돌기 전에 먼저 고침(계획 §2-10)
	h.enter("X-BS", "arrive")
	st.vars.set_v("PC_SKP_REPAIR", 0)
	st.items["M-010"] = 5
	st.items["M-025"] = 2
	t.ok(_says(st, c, "FQJC01_INLET", "새지 않을 것", ["고철 다섯"]), "말랐을 때 실금을 먼저 막는다(고철 다섯 + 테이프 둘) — 마른 판 글")
	t.eq([_v(st, "FQ_JC01_CRACK"), st.count_of("M-010"), st.count_of("M-025")], [1, 0, 0], "균열 고침 · 재료 씀")
	t.eq(_v(st, "FQ_JC01_LEAK"), 0, "새는 걸 보기 전")
	c._fill()
	s2.tick()
	h.enter("X-BS", "arrive")
	t.eq([s2.level(), _v(st, "FQ_JC01_LEAK")], [5, 0], "먼저 고쳐 뒀으면 물이 돌아도 새지 않는다 — 다섯 칸")
	h.free()


func test_jc01_cold_and_substitutes(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	_cut(st, c, r[3])
	c.start()
	st.vars.set_v("FQ_JC01_FLOW", 1)
	st.vars.set_v("FQ_JC01_CRACK", 1)
	st.vars.set_v("AFF_JC_BC", -30)
	var caps0 := _v(st, "PC_CAPS")
	t.ok(_says(st, c, "FQJC01_DONE", "줄 건 없어"), "봉천 적대: 사례만 없다")
	t.eq([st.quests.stage("FQ-JC-01"), _v(st, "PC_CAPS") - caps0, st.count_of("W-101")], [100, 0, 0], "끝 · 캡 · 엽총 없음")
	# 하숙자(조만석 사망 · 알려짐)
	var r2 := _host()
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: FqJc01 = r2[2]
	_cut(st2, c2, r2[3])
	st2.kill("C-010")
	t.ok(_says(st2, c2, "FQJC01_HA", "이장님 계셨으면"), "하숙자가 부탁을 대신")
	t.eq(_v(st2, "FQ_JC01_POSTED"), 2, "들었다")
	st2.vars.set_v("FQ_JC01_FLOW", 2)
	st2.vars.set_v("FQ_JC01_CRACK", 1)
	st2.vars.set_v("AFF_JC_BC", 15)
	t.ok(_says(st2, c2, "FQJC01_HA_DONE", "이장님 엽총"), "하숙자가 유품 엽총을 건넴")
	t.ok(st2.count_of("W-101") == 1 and st2.quests.stage("FQ-JC-01") == 100, "엽총 · 끝")
	# 아무도 없음: 고치면 그대로 끝(반쯤 된 상태 없음, P10)
	var r3 := _host()
	var h3: InteriorHost = r3[0]
	var st3: StoryState = r3[1]
	var c3: FqJc01 = r3[2]
	_cut(st3, c3, r3[3])
	c3.start()
	st3.kill("C-010")
	st3.kill("C-057")
	st3.vars.set_v("FQ_JC01_FLOW", 1)
	c3._cmd(["fix"], func() -> void: pass)
	t.eq(st3.quests.stage("FQ-JC-01"), 100, "보고할 사람이 없으면 고친 순간 끝")
	h.free()
	h2.free()
	h3.free()


func test_jc01_unique_weapon(t) -> void:
	var w: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	t.ok(w.has("W-101") and bool(w["W-101"].get("unique", false)), "W-101 고유 무기 추출")
	t.eq(str(w["W-101"].get("base", "")), str(w["W-101"]["base"]), "기반 무기를 적었다")
	t.ok(w.has(str(w["W-101"]["base"])), "기반 무기가 있다")
	var n := 0
	for k in w:
		if bool(w[k].get("unique", false)):
			n += 1
	t.eq(n, 30, "고유 무기 30종(W-115 단독 고유는 건너뜀)")


func test_jc01_dawn_workers(t) -> void:
	var r := _host("K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	_cut(st, c, r[3])
	st.vars.set_v("GAME_HOUR", 10)
	h.enter("K-08", "from_W")
	t.ok(not h.npcs.any(func(n): return str(n["id"]) == "N-JC-W1"), "낮엔 물당번이 없다")
	st.vars.set_v("GAME_HOUR", 4)
	h.enter("K-08", "from_W")
	t.ok(h.npcs.any(func(n): return str(n["id"]) == "N-JC-W1") and h.npcs.any(func(n): return str(n["id"]) == "N-JC-W2"), "새벽 04시: 근무표대로 물당번 둘")
	t.eq(str(h.scene_for("N-JC-W1").get("id", "")), "FQJC01_WATCH", "말을 걸 수 있다")
	t.ok(_says(st, c, "FQJC01_WATCH", "3주째", ["왜 봉천", "그냥 간다"]), "물당번: 3주째 옥상 물탱크")
	t.eq([_v(st, "FQ_JC01_TALK"), _v(st, "FQ_JC01_KNOW"), st.quests.stage("FQ-JC-01")], [1, 1, 30], "만남 = 흙막이를 앎(30)")
	var k0 := _v(st, "V_KARMA")
	t.ok(_says(st, c, "FQJC01_WATCH", "들켜서 다행", ["같이 분배함"]), "말로 나눔 — 셋째 손을 보탠다(기술 없이)")
	t.eq([_v(st, "FQ_JC01_FLOW"), _v(st, "V_KARMA") - k0, _v(st, "FQ_JC01_GIFT")], [2, 25, 8], "나눔 · 카르마 +25 · 보답은 다음 날부터")
	t.ok(_says(st, c, "FQJC01_WATCH", "반은 찼어요"), "그 뒤 새벽: 고맙다는 물당번")
	t.ok(_says(st, c, "FQJC01_BUCKET", "고맙습니다"), "같은 날엔 아직 꾸러미 없음")
	st.vars.set_v("GAME_DAY", 9)
	var m0 := st.count_of("M-010")
	t.ok(_says(st, c, "FQJC01_BUCKET", "반 줄기 값"), "다음 날: 7동 보답 꾸러미")
	t.eq([st.count_of("M-010") - m0, st.count_of("M-025"), _v(st, "FQ_JC01_GIFT")], [2, 1, -1], "고철 둘 · 테이프 하나 · 한 번만")
	t.ok(not _says(st, c, "FQJC01_BUCKET", "반 줄기 값"), "두 번은 없다")
	# 나눔 보고: 봉천이 덜 기뻐한다
	st.vars.set_v("FQ_JC01_CRACK", 1)
	st.vars.set_v("AFF_JC_BC", 15)
	t.ok(_says(st, c, "FQJC01_DONE", "못 막았어"), "조만석: 반상회 몫 사례가 줄었다")
	t.eq([_v(st, "AFF_JC_BC"), st.count_of("I-056")], [23, 0], "나눔: 봉천 +8 · 약수 없음")
	h.free()


func test_jc01_dawn_persuade_flee(t) -> void:
	var r := _host("K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	_cut(st, c, r[3])
	st.vars.set_v("GAME_HOUR", 4)
	h.enter("K-08", "from_W")
	st.vars.set_v("PC_SKP_SPEECH", 0)
	st.vars.set_v("PC_CH", 1)
	var said := false
	for i in 12:                                                          # 화술 굴림 — 실패하면 철수(그날 밤엔 다시 안 옴)
		st.vars.set_v("FQ_JC01_SAID", 0)
		st.failed_checks.clear()
		st.check_seed = i
		var rr := _play(st, c, "FQJC01_WATCH", ["흙막이를 거둬"])
		if _ok(rr) and str(rr[0]).contains("근무표대로"):
			said = true
			break
	t.ok(said, "설득 실패: 근무표대로 철수")
	t.eq(_v(st, "FQ_JC01_SAID"), 8, "철수한 날")
	h.refresh_npcs()
	t.ok(not h.npcs.any(func(n): return str(n["id"]) == "N-JC-W1"), "그날 밤엔 다시 오지 않는다")
	st.vars.set_v("FQ_JC01_SAID", 0)
	st.vars.set_v("PC_SKP_SPEECH", 100)
	st.vars.set_v("PC_CH", 10)
	var k0 := _v(st, "V_KARMA")
	var ok := false
	for i in 12:
		st.failed_checks.clear()
		st.check_seed = 100 + i
		var rr := _play(st, c, "FQJC01_WATCH", ["흙막이를 거둬"])
		if _ok(rr) and str(rr[0]).contains("남겨 줘요"):
			ok = true
			break
		st.vars.set_v("FQ_JC01_SAID", 0)
	t.ok(ok, "설득 성공: 스스로 마대를 거둔다")
	t.eq([_v(st, "FQ_JC01_FLOW"), _v(st, "V_KARMA") - k0], [1, -5], "물길 1 · 카르마 −5(메움보다 덜)")
	t.ok(_says(st, c, "FQJC01_WATCH", "마른 통 세러"), "그 뒤 새벽: 마른 통 앞의 물당번")
	h.free()


func test_jc01_orphan_tick(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqJc01 = r[2]
	_cut(st, c, r[3])
	c.start()
	st.vars.set_v("FQ_JC01_CRACK", 1)                                     # 마른 실금을 먼저 고침
	st.kill("C-010")
	st.kill("C-057")
	c._fill()                                                             # 그 뒤 메움 — fix 명령 없이도
	c.tick()
	t.eq(st.quests.stage("FQ-JC-01"), 100, "보고할 사람이 없으면 다 된 순간 틱에서 끝(P10)")
	h.free()

