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


func _play(st: StoryState, id: String, picks: Array = [], c: UqR02 = null) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if c != null and str(cur["name"]) == "uqr2":
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


func _says(st: StoryState, id: String, needle: String, picks: Array = [], c: UqR02 = null) -> bool:
	var r := _play(st, id, picks, c)
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
	t.ok(not _has_opt(st, "MQ-103_MA", "공하경 일을 먼저 말한다"), "엿듣기만으론 아이 사정을 모른다 — ② 없음(서사 대조 중5)")
	_play(st, "MQ-103_KONG", ["다음에"])
	t.eq(_v(st, "UQ07_TOLD"), 1, "공하경에게 사정을 들음")
	t.ok(_has_opt(st, "MQ-103_MA", "공하경 일을 먼저 말한다"), "들은 뒤 마영식에게 ② 선택지")
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
	st.vars.set_v("UQ07_KDAY", 4)
	st.vars.set_v("GAME_HOUR", 10)
	c._on_map("J-03")
	c._note_tick()
	t.ok(not h.box.active and c._note_walk <= 0.0, "공하경이 고친 판 — 아이는 '하경 언니가 고쳤다'고 믿는다(쪽지 없음, A211)")
	st.vars.set_v("UQ07_RES", 3)
	st.vars.set_v("UQ07_ME", 1)
	st.vars.set_v("GAME_HOUR", 20)
	c._on_map("J-03")
	c._note_tick()
	t.ok(not h.box.active and c._note_walk <= 0.0, "밤엔 쪽지 없음(아이는 숙소)")
	st.vars.set_v("GAME_HOUR", 10)
	h.refresh_npcs()
	c._on_map("J-03")
	c._bot_tick()
	c._note_tick()
	t.ok(h.box.active or c._note_walk > 0.0, "손수 건넨 다음 날 낮 광장 — 배송 1호가 쪽지를 끌고 옴")
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
	t.ok(_says(st, "MQ-103_KONG", "새로 만드는 중이에요"), "그 뒤엔 되묻지 않는다(서사 대조 중7)")
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


# ---------------------------------------------------------------- UQ-10
func test_uq10_hear_and_day_scale(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	t.ok(_says(st, "UQ10_HEAR", "반장 저울이 가벼워"), "수군댐(원문)")
	t.eq(_v(st, "UQ10_HEARD"), 1, "들음")
	t.eq(st.quests.stage("UQ-10"), 10, "단계 10")
	st.vars.set_v("PC_SKP_REPAIR", 0)
	if st.skill("REPAIR") < 25 and st.stat("PE") < 6:
		t.ok(not _has_opt(st, "UQ10_SCALE", "추 접시 받침"), "수리 25 · 인지력 6 둘 다 모자라면 낮 판정 잠김(문턱)")
	st.vars.set_v("PC_SKP_REPAIR", 30)
	h.combat.crouch = false
	t.ok(_says(st, "UQ10_SCALE", "코 박지 마", ["추 접시 받침"], c), "낮 — 웅크리지 않으면 탁우빈이 눈치챈다")
	t.eq(_v(st, "UQ10_CHECKED"), 1, "증거는 얻음")
	t.eq(st.quests.stage("UQ-10"), 20, "단계 20")
	t.eq(_v(st, "UQ10_HIDE_UNTIL"), 5 + 3, "사흘 쇠판 뗌")
	t.ok(_says(st, "UQ10_SCALE", "급히 뗐다"), "그동안 저울은 '정직'")
	t.ok(_says(st, "UQ10_M2", "10캡"), "부품 장수 — 한 관에 9캡(정직한 저울, 제 각도)")
	t.ok(not _has_opt(st, "UQ10_M1", "저울 받침을 들춰", ["쇠판이 덧대져"]), "숨긴 동안엔 저울을 들춰 보일 수 없다")
	st.vars.set_v("UQ10_HIDE_UNTIL", 0)
	h.combat.crouch = true
	t.ok(_says(st, "UQ10_SCALE", "눈을 떼지 않았다", ["추 접시 받침"], c), "웅크리면 들키지 않는다")
	t.eq(_v(st, "UQ10_HIDE_UNTIL"), 0, "쇠판 그대로")
	h.combat.crouch = false


func test_uq10_night_take_and_swap(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ10_HEARD", 1)
	st.vars.set_v("GAME_HOUR", 22)
	t.ok(_says(st, "UQ10_SCALE", "거적", ["거적을 들추고", "쇠판을 떼어 간다"], c), "밤 — 판정 없이 들추고 떼어 감")
	t.eq(st.count_of("M-433"), 1, "덧댄 쇠판(M-433)")
	t.eq(_v(st, "UQ10_PLATE"), 1, "쇠판 자리 = 떼어 감")
	t.eq(_v(st, "UQ10_NROLL"), 5, "그날 밤 창 판정 한 번")
	st.vars.set_v("GAME_HOUR", 10)
	t.ok(_says(st, "UQ10_T", "네 손이지" if _v(st, "UQ10_NSEEN") >= 1 else "낯선 얼굴은 너뿐"), "다음 날 탁우빈 — 창에서 봤으면 지목 · 아니면 떠보기(서사 대조 중14)")
	t.eq(_v(st, "UQ10_PSAID"), 1, "한 번")
	c._uq10_day(7)
	t.eq(_v(st, "UQ10_PLATE"), 1, "사흘 전엔 그대로")
	c._uq10_day(8)
	t.eq(_v(st, "UQ10_PLATE"), 0, "사흘 뒤 새 쇠판")
	st.vars.set_v("GAME_HOUR", 22)
	st.vars.set_v("UQ10_PSAID", 0)
	st.vars.set_v("GAME_DAY", 9)
	_play(st, "UQ10_SCALE", ["거적을 들추고", "옮겨 붙인다"], c)
	t.eq(_v(st, "UQ10_PLATE"), 2, "쇠판을 고철 쪽으로(엉뚱한 짓)")
	st.vars.set_v("GAME_DAY", 10)
	st.vars.set_v("GAME_HOUR", 10)
	t.ok(_says(st, "UQ10_M1", "후하네"), "다음 날 국밥 장수 '오늘 저울 후하네?'")
	t.ok(_says(st, "UQ10_T", "고철 쪽으로 넘어가더라"), "탁우빈이 먼저 따진다 → 담판 입구")
	c._uq10_day(11)
	t.eq(_v(st, "UQ10_PLATE"), 0, "이틀 뒤 원상")


func test_uq10_public(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ10_HEARD", 1)
	st.vars.set_v("UQ10_CHECKED", 1)
	t.ok(_says(st, "UQ10_M1", "봤다는 사람만", ["쇠판이 덧대져", "그냥 봤어요"]), "증거 없이 말로는 거절")
	st.vars.set_v("SQ_S13_V_T", 1)
	t.ok(_says(st, "UQ10_M1", "투표 끝나고", ["쇠판이 덧대져"]), "SQ-S13 — 탁우빈이 투표 약속 중이면 '투표 끝나고'(P4)")
	st.vars.set_v("SQ_S13_V_T", 4)
	var karma := _v(st, "V_KARMA")
	t.ok(_says(st, "UQ10_M1", "그 덤이 너희 노점 지켰어", ["쇠판이 덧대져", "저울 받침을 들춰"], c), "② 공개 — 탁우빈 반론(R11)")
	t.eq(_v(st, "UQ10_RES"), 2, "RES 2")
	t.eq(_v(st, "V_KARMA"), karma + 25, "카르마 +25")
	t.eq(_v(st, "UQ10_XP"), 1, "XP 70 한 번")
	t.eq(st.quests.stage("UQ-10"), 100, "단계 100")
	t.ok(_says(st, "UQ10_T", "반장도 끝이야"), "그날 탁우빈")
	c._uq10_day(6)
	t.eq(_v(st, "UQ10_BOSS"), 1, "상인 회의 — 반장 표강윤")
	t.ok(_says(st, "A13_SUSP_T", "내가 알지"), "SQ-S13 의심 장면 — 쫓겨난 뒤 '내가 알지'(H11)")
	var rd := _v(st, "UQ10_RAID_DAY")
	t.ok(rd >= 7 and rd <= 12, "습격 날 7일 안(%d)" % rd)
	t.ok(_says(st, "UQ10_T", "반장은 이제 내가 아니야"), "탁우빈 구석 노점(P3)")
	t.ok(_says(st, "UQ10_P", "반장 노릇은 처음이야"), "표강윤 반장")
	st.vars.set_v("GAME_DAY", rd - 1)
	t.ok(_says(st, "UQ10_M1", "대방 정찰 둘"), "전날 예고 — 출처는 어귀의 정찰 둘(P7)")
	t.ok(_says(st, "UQ10_T", "첫 목요일이 내일"), "탁우빈 — 목요일 셈")
	c._uq10_day(rd + 1)
	var r := _v(st, "UQ10_RAID")
	t.ok(r == 3 or r == 4, "그 자리에 없었으면 결과만(막음/털림 — %d)" % r)
	if r == 4:
		t.ok(_says(st, "UQ10_M1", "그날 너 어디 있었어"), "털림 — '그날 너 어디'")
		t.ok(_says(st, "UQ10_T", "내가 뭐랬어"), "탁우빈 '내가 뭐랬어'")
	else:
		t.ok(_says(st, "UQ10_M1", "표 반장이 탄을"), "막음 — 표강윤")
		t.ok(_says(st, "UQ10_T", "운이 좋았네"), "탁우빈 '운이 좋았네'")


func test_uq10_public_variants(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ10_RES", 2)
	st.vars.set_v("UQ10_PUB_DAY", 5)
	st.kill("N-R02-020")
	st.vars.set_v("UQ71_SQ", 9)
	c._uq10_day(6)
	t.eq(_v(st, "UQ10_BOSS"), 2, "표강윤이 죽었으면 반장은 돌아가며")
	t.eq(_v(st, "UQ10_RAID"), 9, "대방 분대가 흩어졌으면 습격 없음(원문 비고)")


func test_uq10_deal_and_free(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ10_RES", 3)
	c._cmd(["deal"], func() -> void: pass)
	t.eq(c.wd(_v(st, "UQ10_DUE")), 3, "수거는 목요일(%d일)" % _v(st, "UQ10_DUE"))
	var due := _v(st, "UQ10_DUE")
	c._uq10_day(due)
	t.eq(_v(st, "UQ10_MISS"), 0, "목요일 당일엔 아직")
	c._uq10_day(due + 1)
	t.eq(_v(st, "UQ10_MISS"), 1, "금요일 아침 — 못 낸 주 1")
	t.eq(_v(st, "UQ10_ROB_DAY"), due + 1, "노점 하나 털림(흔적)")
	t.eq(_v(st, "UQ10_DUE"), due + 7, "다음 목요일")
	st.vars.set_v("GAME_DAY", due + 1)
	t.ok(_says(st, "UQ10_T", "남쪽 노점 하나 털렸다", [], c), "탁우빈 '이번 주 몫이 비었어'")
	t.ok(_says(st, "UQ10_M2", "판자를 다시 대야"), "부품 장수 — 털린 노점(제 각도)")
	st.vars.set_v("PC_CAPS", 500)
	_play(st, "UQ10_T", ["넉 주 치를"], c)
	t.eq(_v(st, "UQ10_PAY_UNTIL"), due + 28, "넉 주 선불 — 다음 목요일부터 넷(%d)" % _v(st, "UQ10_PAY_UNTIL"))
	t.eq(_v(st, "PC_CAPS"), 300, "200캡")
	st.vars.set_v("UQ71_SQ", 9)
	st.vars.set_v("GAME_DAY", due + 9)
	var caps := _v(st, "PC_CAPS")
	t.ok(_says(st, "UQ10_T", "이제 보호비 안 내도 돼", [], c), "분대가 흩어지면 대납 끝")
	t.eq(_v(st, "UQ10_REFUND"), 150, "아직 안 온 목요일 셋 몫 돌려줌")
	t.eq(_v(st, "PC_CAPS"), caps + 150, "캡 +150")
	c._uq10_day(60)
	t.eq(_v(st, "UQ10_MISS"), 1, "끝난 뒤엔 못 낸 주가 늘지 않는다")


func test_uq10_deal_breaks(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ10_RES", 3)
	c._cmd(["deal"], func() -> void: pass)
	var due := _v(st, "UQ10_DUE")
	c._cmd(["pay", 1], func() -> void: pass)
	c._uq10_day(due + 1)
	t.eq(_v(st, "UQ10_MISS"), 0, "낸 주는 털리지 않는다")
	c._uq10_day(due + 8)
	c._uq10_day(due + 15)
	t.eq(_v(st, "UQ10_RES"), 3, "두 번까지는 버틴다")
	c._uq10_day(due + 22)
	t.eq(_v(st, "UQ10_RES"), 6, "세 번 못 내면 깨짐 — 다시 쇠판")
	t.ok(_says(st, "UQ10_T", "대납 끊긴 지 세 주야"), "깨진 뒤 탁우빈 — 처음 보는 척하지 않는다(재미 검수 ③b)")
	st.vars.set_v("UQ10_CHECKED", 1)
	t.ok(_has_opt(st, "UQ10_T", "입막음값", []) or _has_opt(st, "UQ10_T", "상인들 앞에서"), "깨진 뒤 다시 담판 · 협박 · 공개")


func test_uq10_extort(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ10_CHECKED", 1)
	var caps := _v(st, "PC_CAPS")
	var karma := _v(st, "V_KARMA")
	t.ok(_says(st, "UQ10_T", "150", ["저울 얘기를 하자", "입막음값"], c), "④ 협박 — 150캡")
	t.eq(_v(st, "PC_CAPS"), caps + 150, "캡 +150")
	t.eq(_v(st, "V_KARMA"), karma - 25, "카르마 −25")
	t.eq(_v(st, "UQ10_RES"), 4, "RES 4")
	t.ok(_says(st, "UQ10_T", "한 번 줬으면 끝이야"), "두 번은 없다")
	t.ok(_says(st, "UQ10_M1", "더 가벼워"), "상인 '요즘 저울이 더 가볍다'(R13)")
	st.call_fn("give", ["M-433", 1])
	t.ok(_says(st, "UQ10_M1", "돈 받고 또 팔아", ["쇠판이 덧대져", "덧댄 쇠판을 내민다"], c), "④ 뒤 ② — '돈 받고 또 팔아?'")
	t.eq(_v(st, "UQ10_RES"), 2, "공개로 바뀜")


func test_uq10_pyo_and_ledger(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ10_HEARD", 1)
	t.ok(not _has_opt(st, "UQ10_P", "달아 봐 주세요"), "고철이 없으면 대조 못 함")
	st.call_fn("give", ["M-010", 1])
	t.ok(_says(st, "UQ10_P", "내가 단다", ["달아 봐 주세요"], c), "표강윤 화약 저울 대조(판정 없음)")
	t.eq(_v(st, "UQ10_CHECKED"), 2, "표강윤도 앎")
	t.eq(st.count_of("M-010"), 0, "고철은 값으로 쳐 둔다")
	t.ok(_has_opt(st, "UQ10_M1", "표강윤 씨 화약 저울로", ["쇠판이 덧대져"]), "공개 증거 — 표강윤")
	st.vars.set_v("GAME_HOUR", 22)
	t.ok(_says(st, "UQ10_LEDGER", "내려놔"), "밤엔 탁우빈이 깨어 본다")
	st.vars.set_v("GAME_HOUR", 10)
	t.ok(_says(st, "UQ10_LEDGER", "대방 — 목", ["뒷장을 뜯어"], c), "낮 — 빈 방의 장부 뒷장")
	t.eq(st.count_of("M-434"), 1, "장부 뒷장(M-434)")
	t.eq(_v(st, "UQ10_LEDGER"), 1, "장부를 읽음")


func test_uq10_tak_dead_and_sq13(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.quests.set_stage("UQ-10", 10)
	st.kill("N-R02-019")
	t.ok(_says(st, "UQ10_SCALE", "주인 없는"), "탁우빈이 죽으면 주인 없는 저울")
	c._uq10_day(6)
	t.eq(st.quests.stage("UQ-10"), 90, "결판 전 사망 — 소멸(90)")
	var r2 := FileAccess.get_file_as_string("res://data/dialogue/SQS13_R2.json")
	t.ok(r2.contains("쫓겨난 반장이 오버시어라"), "SQ-S13 KEY_T — 반장에서 밀려난 판(P3)")
	var ask := FileAccess.get_file_as_string("res://data/dialogue/A13_ASK_T.json")
	t.ok(ask.contains("\"chain\"") or ask.contains("chain"), "SQ-S13 탁우빈 '(다른 얘기)' → 평소 장면(UQ10_T)으로 chain")


func test_uq10_thursday_and_noon(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ10_RES", 2)
	st.vars.set_v("UQ10_PUB_DAY", 5)
	c._uq10_day(6)
	var rd := _v(st, "UQ10_RAID_DAY")
	t.eq(c.wd(rd), 3, "습격 날 = 덤이 끊긴 뒤 첫 목요일(%d일)" % rd)
	t.ok(rd > 6 and rd <= 13, "회의 다음 날부터 이레 안")
	st.vars.set_v("GAME_DAY", rd)
	st.vars.set_v("GAME_HOUR", 11)
	c._raid_clock()
	t.eq(_v(st, "UQ10_RAID"), 0, "정오 전엔 아직(실전 창 08~12)")
	st.vars.set_v("GAME_HOUR", 12)
	c._raid_clock()
	var r := _v(st, "UQ10_RAID")
	t.ok(r == 3 or r == 4, "그 자리에 없으면 정오에 결과(그날 오후 흔적이 보인다 — %d)" % r)
	if r == 4:
		t.eq(_v(st, "UQ10_ROB_DAY"), rd, "털린 날 = 습격 날")


func test_uq10_scouts_shot(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	t.ok(bool(st.npcs.get("N-DB-S1", {}).get("evil", false)), "시장 정찰은 약탈자(쏴도 주민 살해 카르마 아님)")
	t.ok(str(st.npcs.get("N-DB-S1", {}).get("name", "")) == "대방 정찰", "이름표 '대방 정찰'")
	t.ok(str(st.npcs.get("N-YM-1", {}).get("name", "")) == "국밥 장수" and str(st.npcs.get("N-JM-K1", {}).get("name", "")) == "광장 아이", "무명 화자 이름표(ID가 찍히던 것)")
	st.vars.set_v("UQ10_RES", 2)
	st.vars.set_v("UQ10_RAID_DAY", 9)
	st.vars.set_v("GAME_DAY", 8)
	st.kill("N-DB-S1")
	c._raid_clock()
	t.eq(_v(st, "UQ10_EARLY"), 1, "전날 정찰을 쏨")
	t.eq(_v(st, "UQ10_RAID_DAY"), 8, "습격이 오늘로 당겨짐")
	t.ok(_says(st, "UQ10_M1", "본대가 더 빨리 와"), "국밥 장수 '정찰이 안 돌아가면'")
	t.ok(not st.is_dead("N-DB-1"), "UQ-71 지하차도 분대원(N-DB-1)과 다른 사람(P3)")
	st.vars.set_v("GAME_HOUR", 15)
	c._raid_clock()
	t.eq(_v(st, "UQ10_RAID"), 0, "당겨진 날은 20시까지 실전 창")
	st.vars.set_v("GAME_HOUR", 20)
	c._raid_clock()
	t.ok(_v(st, "UQ10_RAID") in [3, 4], "20시가 지나면 결과")


func test_uq10_reactions(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ10_CHECKED", 1)
	st.vars.set_v("UQ10_NOTICED", 1)
	t.ok(_says(st, "UQ10_T", "코 박던 놈이네"), "낮에 들킨 뒤 탁우빈이 기억한다(재미 검수 ③a)")
	t.eq(_v(st, "UQ10_NOTICED"), 2, "한 번")
	st.call_fn("give", ["M-435", 2])
	t.ok(_says(st, "UQ10_M1", "못 구멍이 없잖아", ["쇠판이 덧대져", "새 쇠판을 내민다"]), "상자의 새 쇠판은 증거가 아니다(재미 검수 ③c)")
	st.vars.set_v("UQ10_BOXT", 1)
	t.ok(_says(st, "UQ10_T", "상자가 비었더라"), "탁우빈이 방에 누가 든 걸 안다(쇠판은 말하지 않음)")
	st.kill("N-R02-019")
	st.vars.set_v("UQ10_HEARD", 1)
	t.ok(_says(st, "UQ10_M1", "죽은 사람 저울 탓해 뭐 해"), "탁우빈이 죽은 뒤 국밥 장수(계획 §4.2-12)")


# ---------------------------------------------------------------- UQ-08 철사의 돋보기(1-12h h2 — 계획 §3.3 · §4.2b · §8b)
func test_uq08_ask_ticket_gate(t) -> void:
	var a := _host("H-05", "from_H-02")
	var st: StoryState = a[1]
	t.ok(_says(st, "SQS09_WIRE", "고글 너머로 눈을 찡그린다"), "철사 장면 머리 — 늘 찡그림(H6)")
	st.vars.set_v("AFF_SB", -60)
	t.ok(not _has_opt(st, "SQS09_WIRE", "눈이 왜 그래요"), "SB 경계 밖이면 발동 없음")
	st.vars.set_v("SB_PASS", 1)
	t.ok(_has_opt(st, "SQS09_WIRE", "눈이 왜 그래요"), "변장(SB_PASS)이면 발동")
	st.vars.set_v("SB_PASS", 0)
	st.vars.set_v("AFF_SB", 0)
	t.ok(_says(st, "UQ08_DESK", "세진 광학 납품 전표"), "작업대 끝 전표")
	t.eq(_v(st, "UQ08_TICKET"), 1, "전표 읽음")
	t.ok(_says(st, "SQS09_WIRE", "그 전표 봤구나", ["눈이 왜 그래요"]), "전표를 읽었으면 '그 전표 봤구나'(S7)")
	t.eq(_v(st, "UQ08_MET"), 1, "사정을 들음")
	t.eq(st.quests.stage("UQ-08"), 10, "단계 10")
	t.ok(_says(st, "SQS09_WIRE", "나사 셋", ["렌즈 — 어디"]), "다시 물으면 길 · '비틀지 말고 풀어'")
	t.ok(_says(st, "UQ08_BENCH", "두 번 지졌다"), "조립대 — 두 번 지진 땜(S15)")


func test_uq08_scope_quiet_and_loud(t) -> void:
	for loud in [false, true]:
		var a := _host("HP-04", "from_HP01")
		var h: InteriorHost = a[0]
		var st: StoryState = a[1]
		var c: UqR02 = a[2]
		st.vars.set_v("UQ08_MET", 1)
		st.quests.set_stage("UQ-08", 10)
		st.vars.set_v("PC_SKP_REPAIR", 0 if loud else 40)
		if loud:
			t.ok(st.skill("REPAIR") >= 30 or not _has_opt(st, "UQ08_SCOPE", "고정 나사 셋"), "수리 30 미만이면 나사 풀기 잠김")
		var foes := 0
		for e in h.combat.enemies:
			if is_instance_valid(e) and str(e.who) in ["N-HP-F6", "N-HP-F7"]:
				foes += 1
		t.eq(foes, 2, "2층 구울 둘")
		t.ok(_says(st, "UQ08_SCOPE", "유리 하나가 깨진다" if loud else "조용하다", ["비틀어 뽑는다" if loud else "고정 나사 셋"], c), "렌즈 빼기(%s)" % ("비틀기" if loud else "나사"))
		t.eq(_v(st, "UQ08_LENS"), 1, "렌즈 자리 = 주인공 손")
		t.eq(st.count_of("M-432"), 1, "M-432")
		t.eq(st.quests.stage("UQ-08"), 20, "단계 20")
		var heard := 0
		for e in h.combat.enemies:
			if is_instance_valid(e) and e._heard > 0.0:
				heard += 1
		t.ok((heard > 0) == loud, "비틀어 뽑으면 구울이 소리를 듣는다(%d)" % heard)
		t.ok(_says(st, "UQ08_SCOPE", "고리가 비었다"), "빈 고리")


func test_uq08_lens_first(t) -> void:
	var a := _host("H-05", "from_H-02")
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.call_fn("give", ["M-432", 1])
	st.vars.set_v("UQ08_LENS", 1)
	t.ok(_says(st, "SQS09_WIRE", "그거 어디서 났어", ["나중에"]), "렌즈를 먼저 가져온 판(4.2b 36) — 사정 단계를 건너뜀")
	t.eq(st.quests.stage("UQ-08"), 20, "바로 단계 20")
	var sb := _v(st, "AFF_SB")
	var xp := _v(st, "PC_XP")
	t.ok(_says(st, "SQS09_WIRE", "해제 열쇠 원형", ["렌즈를 건넨다", "기다린다"], c), "① 그대로 줌")
	t.eq(_v(st, "UQ08_RES"), 1, "결과 ①")
	t.eq(_v(st, "UQ08_LENS"), 2, "렌즈는 철사 고글")
	t.eq(st.count_of("M-432"), 0, "렌즈를 건넴")
	t.eq(st.count_of("M-164"), 1, "해제 열쇠 원형")
	t.eq(_v(st, "AFF_SB") - sb, 4, "SB +4")
	t.eq(_v(st, "PC_XP") - xp, 80, "80 XP")
	t.eq(_v(st, "UQ08_SAFE"), 0, "① — 회로 그대로")
	t.ok(_says(st, "SQS09_WIRE", "세진 광학 렌즈가 끼워져"), "고글에 렌즈")
	t.ok(_says(st, "UQ08_BENCH", "땜 자국이 곧고"), "조립대 땜이 곧다")
	st.vars.set_v("SQ_S09_START", 1)
	t.ok(_has_opt(st, "SQS09_WIRE", "[캡 100] 127번"), "해제 요금 반값")
	t.ok(not _has_opt(st, "SQS09_WIRE", "[캡 200] 127번"), "200은 없음")
	st.vars.set_v("SB_COLLAR", 1)
	st.vars.set_v("AFF_SB", 20)
	t.ok(_says(st, "SQS09_WIRE", "세 번째 선", ["내 목걸이"]), "내 목걸이 해제 서비스(우호 이상)")
	t.eq(_v(st, "SB_COLLAR"), 0, "풀림")


func test_uq08_tamper_and_inspection(t) -> void:
	var a := _host("H-05", "from_H-02")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ08_MET", 1)
	st.vars.set_v("UQ08_LENS", 1)
	st.call_fn("give", ["M-432", 1])
	st.vars.set_v("PC_SKP_SCIENCE", 100)
	var k0 := _v(st, "V_KARMA")
	t.ok(_says(st, "SQS09_WIRE", "뚜껑 닫는 소리", ["렌즈를 건넨다", "원격 해제"], c), "② 등을 돌린 틈(S12)")
	t.eq(_v(st, "UQ08_RES"), 2, "결과 ②")
	t.eq(_v(st, "UQ08_SAFE"), 1, "원격 해제 = 무조건 열림")
	t.ok(_v(st, "UQ08_SAFE_AT") > 0, "그 시각")
	t.eq(_v(st, "V_KARMA") - k0, 50, "카르마 +50")
	t.eq(_v(st, "UQ08_INSPECT"), 5 + 30, "첫 검수 30일 뒤")
	st.vars.set_v("SQ_S09_START", 1)
	t.ok(_has_opt(st, "SQS09_WIRE", "[캡 100] 127번"), "철사 눈엔 같은 건넴 — ②도 반값(P2)")
	# 전날: 칠판 · 철사 · 조립대 견본
	st.vars.set_v("GAME_DAY", 34)
	t.ok(_says(st, "SQS09_BOARD", "내일 09:00"), "전날 칠판 '목걸이 검수 — 내일 09:00 · 실장'(S4)")
	t.ok(_says(st, "SQS09_WIRE", "괜찮겠지"), "철사 '요즘 땜이 곧으니까 괜찮겠지'")
	t.ok(_says(st, "UQ08_BENCH", "장부대로 터지는", ["되돌려 둔다"]), "견본 되돌리기")
	t.eq(_v(st, "UQ08_REVERT"), 35, "그 회차 값")
	st.vars.set_v("GAME_DAY", 35)
	st.vars.set_v("GAME_HOUR", 9)
	st.vars.set_v("UQ08_HEAT", 9)
	c._inspect_tick()
	t.eq(_v(st, "UQ08_CHECK_N"), 0, "작업실 안에 있으면 미룸(눈앞에서 사라지지 않게)")
	h.enter("H-02", "from_H-05")
	c._inspect_tick()
	t.eq(_v(st, "UQ08_CHECK_N"), 1, "검수 1회")
	t.eq(_v(st, "UQ08_WIRE"), 0, "되돌려 둔 회차는 통과(HEAT가 커도)")
	t.eq(_v(st, "UQ08_INSPECT"), 65, "다음 검수 30일 뒤")
	var sb := _v(st, "AFF_SB")
	st.vars.set_v("GAME_DAY", 65)
	c._inspect_tick()
	t.eq(_v(st, "UQ08_WIRE"), 1, "HEAT 9 — 발각(10% + 90%)")
	t.eq(_v(st, "AFF_SB") - sb, -8, "SB −8")
	t.ok(_says(st, "SQS09_BOARD", "철사 — 결근"), "칠판 '결근'(S14)")
	t.ok(_says(st, "UQ08_BENCH", "인두는 식었고"), "식은 조립대")
	st.vars.set_v("SB_127", 0)
	st.vars.set_v("PC_CAPS", 1000)
	t.ok(_says(st, "SQS09_GU", "마스터 코드", ["127번", "[캡 4"]), "구만호 '마스터 코드로'(4.2b 39)")
	t.ok(_says(st, "X-SB_FIRE", "검수에 걸렸대"), "화로 인부 소문(출처)")
	c._inspect_tick()
	t.eq(_v(st, "UQ08_CHECK_N"), 2, "실종 뒤 판정 멈춤")


func test_uq08_safe_collars(t) -> void:
	var a := _host("H-05", "from_H-02")
	var st: StoryState = a[1]
	st.vars.set_v("UQ08_SAFE", 1)
	st.vars.set_v("UQ08_SAFE_AT", 100000)
	st.vars.set_v("CAPTURE_BY", 1)
	st.vars.set_v("CAPTURE_AT", 100000 + 1440)
	t.ok(_says(st, "CAPTURE_SB", "낯익은 자리"), "생포 — 새 목걸이 '낯익은 땜 자국'(S5)")
	st.vars.set_v("CAPTURE_AT", 100000 + 600)
	t.ok(not _says(st, "CAPTURE_SB", "낯익은 자리"), "그 전에 감긴 목걸이는 아니다")
	st.vars.set_v("FQ_SB02_REMOTE", 1)
	st.vars.set_v("FQ_SB02_DAY", 100000 + 2000)
	t.ok(_says(st, "FQSB02_TAESU", "두 쪽으로 벌어져", ["원격기로 목걸이를 끈다"]), "원격기 — 목걸이가 벌어짐(S2)")
	var heat := _v(st, "UQ08_HEAT")
	t.ok(_says(st, "FQSB02_PATROL", "…철사", ["원격기로 목걸이를 모두"]), "갈고리가 땜 자국을 본다")
	t.eq(_v(st, "UQ08_HEAT") - heat, 1, "HEAT +1")
	st.vars.set_v("FQ_SB02_DAY", 100000 + 100)
	t.ok(_says(st, "FQSB02_TAESU", "불빛이 꺼진다", ["원격기로 목걸이를 끈다"]), "그 전 출발 줄은 꺼질 뿐")
	# 해제 열쇠 원형 — 남의 목걸이 · 생포 공구 상자 [수리 25]
	st.vars.set_v("FQ_SB02_REMOTE", 0)
	st.call_fn("give", ["M-164", 1])
	st.vars.set_v("PC_SKP_REPAIR", 0)
	if st.skill("REPAIR") >= 25:
		t.ok(_says(st, "FQSB02_TAESU", "세 번째 선이 들리고", ["해제 열쇠 원형"]), "오태수 목걸이 — 해제 열쇠 원형(S10)")
	st.vars.set_v("PC_SKP_REPAIR", 30)
	t.ok(_says(st, "FQSB02_TAESU", "세 번째 선이 들리고", ["해제 열쇠 원형"]), "오태수 목걸이 — 해제 열쇠 원형(S10)")
	st.vars.set_v("SB_COLLAR", 1)
	t.ok(_has_opt(st, "CAPTURE_COLLAR", "해제 열쇠 원형"), "생포 공구 상자 [수리 25](원문 '1단계 쉬움')")
	t.ok(_says(st, "H-05_PRACTICE", "내 바이스 쓰고 공짜야", ["내 목걸이 뒤판"]), "바이스로 내 목걸이 — 철사 한마디(S13)")
	t.eq(_v(st, "UQ08_VISE"), 1, "한 번")


func test_uq08_wall_snap(t) -> void:
	var a := _host("H-05", "from_H-02")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var p := Act1Paths.new()
	p.setup(h)
	h.enter("X-SB", "gate_in")
	st.vars.set_v("UQ08_SAFE", 1)
	st.vars.set_v("UQ08_SAFE_AT", 100000)
	st.vars.set_v("CAPTURE_AT", 100000 + 1440)
	st.vars.set_v("SB_COLLAR", 1)
	var hp0: float = h.combat.pc.hp
	for k in 14:
		p._sb_collar(false)
	t.eq(_v(st, "SB_COLLAR"), 0, "담 밖 기폭 신호 — 목걸이가 열림")
	t.eq(h.combat.pc.hp, hp0, "피해 없음")
	t.eq(_v(st, "UQ08_HEAT"), 1, "HEAT +1")
	t.eq(_v(st, "UQ08_SNAP_DAY"), 5, "그날(인부 소문 출처)")
	t.ok(_says(st, "X-SB_FIRE", "그냥 열렸대"), "화로 인부 '담 밖에서 목걸이가 그냥 열렸대'")
	st.vars.set_v("UQ08_SAFE", 0)
	st.vars.set_v("SB_COLLAR", 1)
	for k in 14:
		p._sb_collar(false)
	t.ok(h.combat.pc.hp < hp0, "② 아니면 그대로 터진다")


func test_uq08_refuse_boom_and_lost(t) -> void:
	var a := _host("H-05", "from_H-02")
	var st: StoryState = a[1]
	var c: UqR02 = a[2]
	st.vars.set_v("UQ08_MET", 1)
	st.vars.set_v("UQ08_MET_DAY", 5)
	st.vars.set_v("UQ08_LENS", 1)
	st.call_fn("give", ["M-432", 1])
	t.ok(_says(st, "SQS09_WIRE", "두 번 지지면 돼", ["안 준다"], c), "③ 안 줌")
	t.eq(_v(st, "UQ08_RES"), 3, "결과 ③")
	t.eq(st.quests.stage("UQ-08"), 100, "단계 100")
	c._uq08_day(5 + 29)
	t.eq(_v(st, "UQ08_BOOM"), 0, "29일째엔 아직")
	c._uq08_day(5 + 30)
	t.eq(_v(st, "UQ08_BOOM"), 1, "30일 뒤 오작동")
	st.vars.set_v("GAME_DAY", 36)
	t.ok(_says(st, "SQS09_BOARD", "412번 — 결번"), "칠판 결번(S6)")
	t.ok(_says(st, "X-SB_FIRE", "목걸이가 또 터졌대"), "원문 바크 — 출처: 화로 인부")
	t.ok(_says(st, "SQS09_WIRE", "내 땜이야", ["나중에"]), "철사 '내 땜이야'")
	var xp := _v(st, "PC_XP")
	t.ok(_says(st, "SQS09_WIRE", "해제 열쇠 원형", ["렌즈를 건넨다", "기다린다"], c), "③은 되돌릴 수 있다 — 렌즈를 들고 다시 오면 ①")
	t.eq(_v(st, "UQ08_RES"), 1, "결과 ①로")
	t.eq(_v(st, "PC_XP"), xp, "XP는 한 번")
	# 렌즈를 잃음 → 마영식 랙
	var b := _host("H-05", "from_H-02")
	var st2: StoryState = b[1]
	var c2: UqR02 = b[2]
	st2.vars.set_v("UQ08_MET", 1)
	st2.vars.set_v("UQ08_LENS", 1)
	c2._uq08_day(6)
	t.eq(_v(st2, "UQ08_LENS"), 3, "어디든 가진 수 0 → 잃음")
	t.ok(_says(st2, "SQS09_WIRE", "마영식 랙으로", ["잃어버렸어요"]), "철사가 마영식 랙으로 보냄")
	st2.vars.set_v("MQ103_STAGE", 40)
	t.ok(_says(st2, "MQ-103_MA", "세진 광학 대물렌즈가 하나 흘러들어왔어"), "마영식 '흘러들어왔어'")
	t.ok(_says(st2, "MQ-103_MA", "묻지 마", ["세진 광학 렌즈를 산다"]), "[캡 120] 되사기(S9)")
	t.eq(_v(st2, "UQ08_LENS"), 1, "다시 주인공 손")
	t.eq(st2.count_of("M-432"), 1, "M-432")
	st2.quests.set_stage("UQ-08", 20)
	st2.kill("N-R02-038")
	c2._uq08_day(7)
	t.eq(st2.quests.stage("UQ-08"), 90, "결말 전 철사 사망 — 소멸")
