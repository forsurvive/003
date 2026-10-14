## 단계 0-11 저장 종류(SD-12 §13.1·§17.6, SD-19 §6.10): 칸 경로, 자동 3칸 순환, 이어하기 우선순위(중단 → 최근), 손상 칸 건너뛰기,
## 이야기 상태 한 장의 왕복(저장 → 불러오기 → 저장 바이트 동일), 맵·주인공 자리·무기·HP 되살리기.
extends RefCounted

const TMP := "user://test_saves/"


func _clean() -> void:
	SaveSlots.dir = TMP
	DirAccess.make_dir_recursive_absolute(TMP)
	for f in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP + f)


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("P_SURNAME", "윤")
	st.vars.set_v("P_GIVEN", "서진")
	return st


func test_slot_paths_and_rotation(t) -> void:
	_clean()
	t.eq(SaveSlots.path_of("manual", 7), TMP + "manual_07.sav", "수동 칸 경로")
	t.eq(SaveSlots.path_of("quick"), TMP + "quick.sav", "빠른 저장 칸")
	var used := []
	for i in 5:
		var idx := SaveSlots.auto_index()
		used.append(idx)
		t.eq(SaveSlots.write("auto", idx, {"name": "n%d" % i}, {"x": i}), OK, "자동 저장 %d" % i)
	t.eq(used, [0, 1, 2, 0, 1], "자동 저장은 3칸을 돌아가며 덮어쓴다")
	var l := SaveSlots.list()
	t.eq(l.size(), 3, "칸 목록: 자동 3칸")
	t.eq(str(l[0]["slot"]["name"]), "n4", "목록은 최근 저장이 먼저")
	SaveSlots.dir = SaveSlots.DIR


func test_continue_priority(t) -> void:
	_clean()
	t.eq(SaveSlots.continue_path(), "", "저장이 없으면 이어하기 없음")
	SaveSlots.write("manual", 3, {"name": "a"}, {})
	SaveSlots.write("auto", 0, {"name": "b"}, {})
	t.eq(SaveSlots.continue_path(), SaveSlots.path_of("auto", 0), "가장 최근 칸")
	SaveSlots.write("suspend", 0, {"name": "c"}, {})
	SaveSlots.write("manual", 4, {"name": "d"}, {})
	t.eq(SaveSlots.continue_path(), SaveSlots.path_of("suspend"), "중단 저장이 있으면 그것이 먼저(§17.6)")
	var f := FileAccess.open(SaveSlots.path_of("suspend"), FileAccess.READ_WRITE)        # 손상: 몸통 한 바이트를 바꾼다
	f.seek(f.get_length() - 3)
	f.store_8(0x5A)
	f.close()
	t.eq(SaveSlots.continue_path(), SaveSlots.path_of("manual", 4), "손상된 중단 저장은 건너뛴다")
	var bad := SaveSlots.list().filter(func(e): return not e["ok"])
	t.eq(bad.size(), 1, "손상 칸은 목록에 '손상'으로 남는다")
	t.ok(SaveSlots.describe(bad[0]).contains("손상"), "손상 표시")
	SaveSlots.dir = SaveSlots.DIR


func test_story_roundtrip_bytes(t) -> void:
	var st := _state()
	st.vars.set_v("PC_CAPS", 137)
	st.vars.set_v("MQ101_DOG", 2)
	st.items["I-001"] = 3
	st.items["W-002"] = 1
	st.boxes["shop:V01"] = {"items": {"I-001": 2}, "caps": 315, "day": 1, "total": 0}
	st.stolen["M-010"] = 1
	st.dead["N-R01-035"] = true
	var a := GameSnapshot.story(st)
	var bytes_a := var_to_bytes(a)
	var st2 := _state()
	GameSnapshot.apply_story(st2, bytes_to_var(bytes_a))
	var bytes_b := var_to_bytes(GameSnapshot.story(st2))
	t.eq(bytes_a, bytes_b, "저장 → 불러오기 → 저장 바이트 동일(SD-19)")
	t.eq(int(st2.vars.get_v("PC_CAPS")), 137, "변수")
	t.eq(int(st2.items.get("I-001", 0)), 3, "소지품")
	t.eq(int(st2.boxes["shop:V01"]["caps"]), 315, "상인 상태")
	t.ok(st2.dead.has("N-R01-035"), "죽은 인물")


func test_host_restore(t) -> void:
	var st := _state()
	st.items["W-002"] = 1
	st.items["10mm 탄"] = 20
	var h := InteriorHost.new()
	h.st = st
	h._ready()                                                           # 시험 실행기는 장면 나무 밖 — 준비를 직접 부른다
	h.body = "adult"
	h.enter("X-BC", "from_X-S07")
	h.combat.equip("W-002", st)
	h.combat.mags["W-002"] = 7
	h.player.loco.place(Vector2(29 * 32 + 16, 37 * 32 + 16))
	h.combat.pc.hp = 123.0
	h.date_text = "2277. 10. 23.  14:30"
	var d := GameSnapshot.host(h)
	t.eq(str(d["map"]), "X-BC", "맵")
	h.enter("X-S07", "start")
	h.combat.pc.hp = 50.0
	GameSnapshot.apply_host(h, d)
	t.eq(h.map.id, "X-BC", "맵으로 돌아온다")
	t.ok(h.player.loco.logical.distance_to(Vector2(29 * 32 + 16, 37 * 32 + 16)) < 1.0, "저장한 자리")
	t.eq(h.combat.weapon_id, "W-002", "든 무기")
	t.eq(int(h.combat.mags.get("W-002", 0)), 7, "탄창")
	t.near(h.combat.pc.hp, 123.0, 0.01, "HP")
	t.eq(var_to_bytes(GameSnapshot.host(h)), var_to_bytes(d), "다시 찍은 한 장이 같다")
	h.free()
