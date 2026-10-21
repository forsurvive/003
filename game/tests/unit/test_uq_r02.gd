## 단계 1-12h 영등포 비표시 퀘스트(SD-05 §3.4, 계획 docs/seoul-fallout/_plans/1-12h_UQ-07-08-09-10-70_plan.md §6 · §8):
## UQ-07 엿듣기 문턱(둘째 입장 · JH · 3칸) · ① 진공관(훔친 판 포함) · ② 마영식 · ③ 직접 고침(공하경에게 / 내가 아이에게) ·
## 로봇 자리 한 값(다음 06:00 아이 손) · 아이를 먼저 본 판 · 마영식 사망 판 · 쪽지 한 번 · V09 정비 ×0.8.
extends RefCounted


func _host(map_id := "J-03", mark := "from_J-02") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.quests.set_stage("MQ-103", 40)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("MQ101_STAGE", 100)
	st.vars.set_v("MQ101_RESULT", 1)
	st.vars.set_v("GAME_DAY", 5)
	st.vars.set_v("GAME_HOUR", 10)
	st.vars.set_v("PC_CAPS", 200)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 28.  10:00"
	var c := UqR02.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
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


func _says(st: StoryState, id: String, needle: String, picks: Array = []) -> bool:
	var r := _play(st, id, picks)
	return r.size() == 1 and str(r[0]).begins_with("말:") and str(r[0]).contains(needle)


func _has_opt(st: StoryState, id: String, needle: String, picks: Array = []) -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 200:
		guard += 1
		if cur["type"] == "choices":
			if k >= picks.size():
				for o in cur["opts"]:
					if str(o["text"]).contains(needle) and bool(o["enabled"]):
						return true
				return false
			var i := -1
			for j in cur["opts"].size():
				if str(cur["opts"][j]["text"]).contains(str(picks[k])):
					i = j
			k += 1
			if i < 0:
				return false
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return false


func _actor(h: InteriorHost, id: String):
	for n in h.npcs:
		if str(n["id"]) == id and is_instance_valid(n["actor"]):
			return n["actor"]
	return null


# ---------------------------------------------------------------- UQ-07
func test_uq07_hear_gate(t) -> void:
	var a := _host("J-06", "from_J-03")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	t.eq(_v(st, "UQ07_VISIT"), 1, "첫 입장 = 1")
	var k = _actor(h, "N-R02-017")
	t.ok(k != null, "공하경이 J-06에 선다")
	h.player.loco.logical = k.loco.logical + Vector2(32, 0)
	c._hear_tick()
	t.ok(not h.box.active, "첫 입장(해독 · 고백 방문)에는 혼잣말이 없다(재미 검수 R1)")
	h.enter("J-03", "from_J-06")
	h.enter("J-06", "from_J-03")
	t.eq(_v(st, "UQ07_VISIT"), 2, "둘째 입장 = 2")
	k = _actor(h, "N-R02-017")
	st.vars.set_v("AFF_JH", -20)
	h.player.loco.logical = k.loco.logical + Vector2(32, 0)
	c._hear_tick()
	t.ok(not h.box.active, "JH 중립 아래면 없다")
	st.vars.set_v("AFF_JH", 0)
	h.player.loco.logical = k.loco.logical + Vector2(32 * 5, 0)
	c._hear_tick()
	t.ok(not h.box.active, "3칸 밖이면 없다")
	h.player.loco.logical = k.loco.logical + Vector2(32, 0)
	c._hear_tick()
	t.ok(h.box.active, "둘째 입장 · 3칸 안 · JH 중립 → 혼잣말")
	t.ok(_says(st, "UQ07_HEAR", "진공관 세 개만"), "혼잣말 원문")
	t.eq(_v(st, "UQ07_HEARD"), 1, "엿들음")
	t.eq(st.quests.stage("UQ-07"), 10, "단계 10")


func test_uq07_give_tubes(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ07_HEARD", 1)
	t.ok(not _has_opt(st, "MQ-103_KONG", "진공관 셋을 건넨다"), "관이 셋 없으면 ① 없음(계획 §4.1-10)")
	st.call_fn("give", ["M-014", 3])
	var jh := _v(st, "AFF_JH")
	t.ok(_says(st, "MQ-103_KONG", "첫 납땜", ["진공관 셋을 건넨다"]), "① 공하경 '제 첫 납땜'")
	t.eq(_v(st, "UQ07_RES"), 1, "RES 1")
	t.eq(_v(st, "UQ07_TOY"), 1, "로봇은 공하경 손(오늘 밤 납땜)")
	t.eq(_v(st, "UQ07_DISC"), 1, "정비 ×0.8")
	t.eq(_v(st, "AFF_JH"), jh + 2, "JH +2")
	t.eq(st.count_of("M-014"), 0, "관 셋을 넘김")
	t.eq(st.quests.stage("UQ-07"), 100, "단계 100")
	t.ok(_says(st, "MQ-103_KONG", "아침에 걔 일어나기 전에"), "그날 공하경 '오늘 밤에 마무리'")
	c._on_day(6)
	t.eq(_v(st, "UQ07_TOY"), 2, "다음 06:00 아이 손")
	t.eq(_v(st, "UQ07_KDAY"), 6, "아이 손에 간 날")
	t.ok(_says(st, "UQ07_KID", "불도 들어와요"), "아이 '하경 언니가 고쳐 줬어요 — 불'")
	t.ok(_says(st, "MQ-103_KONG", "배송 1호"), "공하경 뒷말 한 번")
	t.ok(_says(st, "MQ-103_KONG", "밥을 다 드셨어요"), "뒷말 뒤엔 평소 줄")


func test_uq07_stolen_tubes(t) -> void:
	var a := _host("J-06", "from_J-03")
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ07_HEARD", 1)
	c._tube_n = st.count_of("M-014")
	st.call_fn("give", ["M-014", 3])                                     # 부품 상자에서 꺼냄
	c._on_box_closed({"owner": "C-006"}, {})
	t.eq(_v(st, "UQ07_STOLE"), 1, "마영식 부품 상자 절도 기록")
	var jh := _v(st, "AFF_JH")
	t.ok(_says(st, "MQ-103_KONG", "공범", ["진공관 셋을 건넨다"]), "① 훔친 판 — 공하경 '공범이에요'")
	t.eq(_v(st, "UQ07_DISC"), 0, "훔친 판엔 정비 할인 없음")
	t.eq(_v(st, "AFF_JH"), jh, "JH 그대로")
	t.eq(_v(st, "UQ07_TOY"), 1, "그래도 로봇은 고친다")
	t.ok(not _says(st, "MQ-103_MA", "관이 셋 비더라"), "아이 손에 가기 전엔 마영식이 모른다")
	c._on_day(6)
	t.ok(_says(st, "MQ-103_MA", "손이 빠르긴 하지"), "다음 날 마영식 '관이 셋 비더라 … 손이 빠르긴 하지'")
	t.ok(not _says(st, "MQ-103_MA", "관이 셋 비더라"), "한 번만")


func test_uq07_ma_route(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	st.vars.set_v("UQ07_HEARD", 1)
	t.ok(_has_opt(st, "MQ-103_MA", "공하경 일을 먼저 말한다"), "엿들은 뒤 마영식에게 ② 선택지")
	var jh := _v(st, "AFF_JH")
	_play(st, "MQ-103_MA", ["공하경 일을 먼저 말한다", "하경이가"])
	if _v(st, "UQ07_RES") == 2:
		t.eq(_v(st, "AFF_JH"), jh + 3, "② 성공 JH +3")
		t.eq(_v(st, "UQ07_TOY"), 1, "마영식이 관 셋을 내줌 → 공하경이 고침")
		t.eq(_v(st, "UQ07_DISC"), 1, "정비 ×0.8")
	else:
		t.eq(_v(st, "UQ07_MA_NO"), 1, "② 실패 — '하경이가 직접 말하라 해'")
		t.ok(not _has_opt(st, "MQ-103_MA", "공하경 일을 먼저 말한다"), "실패 뒤엔 ② 다시 없음")
		st.call_fn("give", ["M-014", 3])
		t.ok(_has_opt(st, "MQ-103_KONG", "진공관 셋을 건넨다"), "①은 남는다")
	st.vars.set_v("UQ07_RES", 2)
	st.vars.set_v("UQ07_TOY", 2)
	st.vars.set_v("UQ07_MA_SAID", 0)
	t.ok(_says(st, "MQ-103_MA", "손이 빠른 애야"), "② 뒤 마영식 대사 한 줄(원문)")


func test_uq07_fix_direct(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ07_HEARD", 1)
	st.vars.set_v("PC_SKP_REPAIR", 0)
	if st.skill("REPAIR") < 40:
		t.ok(not _has_opt(st, "MQ-103_KONG", "담요 밑 로봇"), "수리 40 미만이면 ③ 잠김(문턱 판정 — SD-10)")
	st.vars.set_v("PC_SKP_REPAIR", 60)
	var karma := _v(st, "V_KARMA")
	t.ok(_says(st, "MQ-103_KONG", "제가 하고 싶었는데", ["담요 밑 로봇", "내가 갖다준다"]), "③ 공하경 실망(원문)")
	t.eq(st.count_of("M-431"), 1, "고친 로봇을 손에(M-431)")
	t.eq(_v(st, "UQ07_TOY"), 3, "로봇 자리 = 주인공 손")
	t.eq(_v(st, "UQ07_DISC"), 0, "③엔 정비 할인 없음(원문 ①②만)")
	t.eq(_v(st, "V_KARMA"), karma + 5, "카르마 +5")
	t.eq(st.quests.stage("UQ-07"), 20, "단계 20")
	t.ok(_says(st, "MQ-103_KONG", "분수 근처"), "갖고 있으면 공하경 '낮엔 분수 근처'")
	st.call_fn("take", ["M-431", 1])
	t.ok(_says(st, "MQ-103_KONG", "걔한테 줬어요?"), "팔거나 버리면 공하경 '걔한테 줬어요?'(받기만 하고 안 함)")
	st.call_fn("give", ["M-431", 1])
	t.ok(_says(st, "UQ07_KID", "배송 1호 출발", ["태엽 배송 로봇을 건넨다"]), "아이에게 직접 건넴")
	t.eq(_v(st, "UQ07_TOY"), 2, "아이 손")
	t.eq(_v(st, "UQ07_ME"), 1, "내가 건넴")
	t.eq(st.count_of("M-431"), 0, "로봇을 넘김")
	t.eq(st.quests.stage("UQ-07"), 100, "단계 100")
	t.ok(_says(st, "UQ07_KID", "고쳐 준 사람"), "아이는 고친 사람을 안다")
	c._on_map("J-03")
	c._note_tick()
	t.eq(_v(st, "UQ07_NOTE"), 0, "건넨 날엔 쪽지 없음(그 자리에서 봤다)")


func test_uq07_fix_for_kong(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ07_HEARD", 1)
	st.vars.set_v("PC_SKP_REPAIR", 60)
	t.ok(_says(st, "MQ-103_KONG", "제가 고쳤다고 할게요", ["담요 밑 로봇", "공하경에게 건넨다"]), "③ 공하경에게 건넴(원문)")
	t.eq(_v(st, "UQ07_TOY"), 1, "공하경 손 → 다음 아침")
	t.eq(st.count_of("M-431"), 0, "로봇은 주인공 손에 없다")
	c._on_day(6)
	t.ok(_says(st, "UQ07_KID", "종이 울려요"), "관 없이 고친 로봇 — 종(③)")
	t.ok(_says(st, "MQ-103_KONG", "제가 고친 줄 알아요"), "공하경 '고마워요, 그렇게 둬 줘서'")
	c._on_map("J-03")
	c._note_tick()
	t.ok(not h.box.active, "아이는 '하경 언니가 고쳤다'고 믿는다 — 쪽지 없음(A211)")


func test_uq07_kid_seen_and_note(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	t.ok(_says(st, "UQ07_KID", "배송이요"), "퀘스트 전부터 광장 아이 '배송이요'")
	t.eq(_v(st, "UQ07_KID_SEEN"), 1, "아이를 먼저 봄")
	st.vars.set_v("UQ07_HEARD", 1)
	t.ok(_has_opt(st, "MQ-103_KONG", "광장에서 상자 끄는 그 애?"), "공하경 장면에 '그 애?' 선택지(재미 검수 R2)")
	st.vars.set_v("UQ07_RES", 1)
	st.vars.set_v("UQ07_TOY", 2)
	st.vars.set_v("UQ07_KDAY", 5)
	st.vars.set_v("GAME_HOUR", 20)
	c._on_map("J-03")
	c._note_tick()
	t.ok(not h.box.active, "밤엔 쪽지 없음(아이는 숙소)")
	st.vars.set_v("GAME_HOUR", 10)
	c._on_map("J-03")
	c._note_tick()
	t.ok(h.box.active, "낮 광장 — 배송 1호가 쪽지를 끌고 옴")
	t.ok(_says(st, "UQ07_NOTE", "배송 완료"), "크레용 그림 '배송 완료'")
	t.eq(_v(st, "UQ07_NOTE"), 1, "한 번")


func test_uq07_master_dead(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	st.kill("C-006")
	t.ok(_says(st, "MQ-103_KONG", "아무도 안 앉아요"), "마영식 사망 뒤 공하경 평소 줄(옛 '밥을 다 드셨어요' 고침)")
	t.ok(_says(st, "UQ07_HEAR", "시험용"), "혼잣말 — 선생님 계셨으면")
	t.ok(_says(st, "MQ-103_KONG", "횡령이라고 할 사람도 없네요"), "공하경 장면 사망 판")


func test_uq07_fix_discount(t) -> void:
	var a := _host("J-06", "from_J-03")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var keys: Array = []
	for k in h.items_db:
		var it: Dictionary = h.items_db[k]
		if str(k).begins_with("W-") and not str(k).contains("@") and Gear.fixable_by(str(k), h.merchant_def("V09").get("fix", {}).get("kinds", [])):
			keys.append(str(k))
	if keys.is_empty():
		t.ok(true, "V09가 고칠 수 있는 무기가 자료에 없다 — 건너뜀")
		return
	var w := Gear.key_of(str(keys[0]), 3)
	st.call_fn("give", [w, 1])
	var j0 := h.fix_jobs("V09")
	if j0.is_empty():
		t.ok(true, "정비 일감 없음 — 건너뜀")
		return
	st.vars.set_v("UQ07_DISC", 1)
	var j1 := h.fix_jobs("V09")
	t.ok(int(j1[0]["cost"]) < int(j0[0]["cost"]), "UQ-07 ①② 뒤 V09 정비값이 내려간다(%d → %d)" % [int(j0[0]["cost"]), int(j1[0]["cost"])])
	st.kill("N-R02-017")
	var j2 := h.fix_jobs("V09")
	t.eq(int(j2[0]["cost"]), int(j0[0]["cost"]), "공하경이 죽으면 할인도 없다")


func test_uq07_self_after_refusal(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ07_HEARD", 1)
	t.ok(not _has_opt(st, "MQ-103_KONG", "선생님한테 얘기해 봤는데"), "마영식에게 거절당하기 전엔 없음")
	st.vars.set_v("UQ07_MA_NO", 1)
	var jh := _v(st, "AFF_JH")
	t.ok(_says(st, "MQ-103_KONG", "내일 아침에 제가 해 볼게요", ["선생님한테 얘기해 봤는데"]), "② 실패가 이야기로 — 공하경이 직접 말하기로(재미 검수 ②)")
	t.eq(_v(st, "UQ07_SELF"), 1, "SELF 1")
	c._on_day(6)
	t.eq(_v(st, "UQ07_RES"), 4, "그 아침 공하경이 직접 말함(RES 4)")
	t.eq(_v(st, "UQ07_TOY"), 1, "관 셋 → 그날 납땜")
	t.eq(_v(st, "UQ07_DISC"), 1, "정비 ×0.8")
	t.eq(_v(st, "AFF_JH"), jh + 1, "JH +1(약한 판)")
	t.eq(st.quests.stage("UQ-07"), 100, "단계 100")
	c._on_day(7)
	t.eq(_v(st, "UQ07_TOY"), 2, "다음 아침 아이 손")
	t.ok(_says(st, "MQ-103_MA", "직접 와서 말하더라"), "마영식 '그게 맞아'")
	t.ok(_says(st, "MQ-103_KONG", "제가 직접 말했어요"), "공하경 '무서웠는데'")


func test_uq07_lost_robot(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ07_HEARD", 1)
	st.vars.set_v("PC_SKP_REPAIR", 60)
	_play(st, "MQ-103_KONG", ["담요 밑 로봇", "내가 갖다준다"])
	t.eq(_v(st, "UQ07_TOY"), 3, "로봇은 주인공 손")
	st.call_fn("take", ["M-431", 1])                                     # 팔거나 버림
	c._on_day(6)
	t.eq(_v(st, "UQ07_LOST"), 1, "06:00 — 잃음을 앎")
	t.ok(_says(st, "MQ-103_KONG", "제가 다시 만들게요"), "공하경 한 번")
	t.ok(_says(st, "MQ-103_KONG", "걔한테 줬어요?"), "그 뒤엔 평소 물음")
	c._on_day(8)
	t.eq(_v(st, "UQ07_TOY"), 3, "사흘 전엔 그대로")
	c._on_day(9)
	t.eq(_v(st, "UQ07_TOY"), 1, "사흘 뒤 공하경이 새로 만듦(P10)")
	c._on_day(10)
	t.eq(_v(st, "UQ07_TOY"), 2, "아이 손")
	t.eq(st.quests.stage("UQ-07"), 100, "단계 100(보상 없음)")
	t.ok(_says(st, "MQ-103_KONG", "새로 만들어 줬어요"), "공하경 '이번 건 처음부터 끝까지 제 납땜'")
	t.ok(_says(st, "UQ07_KID", "하경 언니가"), "아이는 하경 언니가 만든 줄 안다")


func test_uq07_bot_follows_kid(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	c._bot_tick()
	t.ok(c._bot != null and c._bot_kind == "canbox", "퀘스트 전 — 아이 뒤에 끈 달린 깡통 상자")
	st.vars.set_v("UQ07_TOY", 2)
	h.refresh_npcs()
	c._bot_tick()
	t.ok(c._bot != null and c._bot_kind == "toybot", "로봇을 받은 뒤 — 배송 1호")
	t.ok(not (c._bot in h.npcs.map(func(n): return n["actor"])), "맵 인물이 아니다(공격 대상 아님)")
	st.vars.set_v("GAME_HOUR", 20)
	h.refresh_npcs()
	c._bot_tick()
	t.ok(c._bot == null, "밤 — 아이가 숙소로 가면 배우도 없다")
	st.vars.set_v("GAME_HOUR", 10)
	h.refresh_npcs()
	h.enter("J-06", "from_J-03")
	t.ok(c._bot == null, "다른 맵 — 치움")
