## 길 위 발견물·소문(단계 1-4f, SD-08 §13.2·§14.1, STAGE_1 §1.1): 굽기 결과 밀도 · 용기 종류가 루팅 표에 있다 · 쪽지 한 번씩 ·
## 대피소 표지는 역·주민센터·구청만 가리킨다 · 소문은 행적 조건이 먼저, 같은 사람·같은 날은 같은 말.
extends RefCounted


func test_pois(t) -> void:
	var pz: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/pois.json"))
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/world.json"))
	var n_chunks := 0
	for k in meta["regions"]:
		if str(meta["regions"][k]) != "HR":
			n_chunks += 1
	var per := float(pz["boxes"].size()) / n_chunks
	t.ok(per >= 2.0 and per <= 6.0, "청크당 용기 %.2f개(SD-08 §13.2 시가지 3~5 · 산지 1~2 — 표지·쪽지 별도)" % per)
	var kinds := {}
	for b in pz["boxes"]:
		kinds[str(b["kind"])] = true
	Loot._load()
	for k in kinds:
		t.ok(Loot.tables.has(k), "길 위 용기 종류 '%s'가 루팅 표에 있다" % k)
	var notes := {}
	var dup := 0
	var bad_sign := 0
	for x in pz["texts"]:
		var s := str(x["text"])
		if s.begins_with("땅에 떨어진 쪽지"):
			dup += int(notes.has(s))
			notes[s] = true
		if s.contains("대피소 표지") and not (s.contains("역'") or s.contains("주민센터") or s.contains("구청") or s.contains("대피소'") or s.contains("지하상가")):
			bad_sign += 1
	t.eq(dup, 0, "쪽지는 한 번씩만 놓인다")
	t.ok(notes.size() >= 20, "길 위 쪽지 %d장" % notes.size())
	t.eq(bad_sign, 0, "2077 대피소 표지는 지하철역·주민센터·구청·지하상가·대피소만 가리킨다")


func test_rumors(t) -> void:
	var st := StoryState.new()
	st.load_data()
	var plain := Rumors.pick(st, "R01", "N-R01-030", false)
	t.ok(plain != "", "행적이 없어도 권역 소문은 있다")
	st.vars.set_v("MQ101_RESULT", 5)
	var said: Array = []
	for d in 8:
		st.vars.set_v("GAME_DAY", d)
		said.append(Rumors.pick(st, "R01", "N-R01-030", false))
	t.ok(said.any(func(s): return s.contains("저수조") or s.contains("물값이 두 배")), "저수조를 팔면 봉천 주민이 그 이야기를 한다")
	st.vars.set_v("GAME_DAY", 3)
	t.eq(Rumors.pick(st, "R01", "N-R01-030", false), Rumors.pick(st, "R01", "N-R01-030", false), "같은 사람·같은 날은 같은 말")
	var r02 := Rumors.pick(st, "R02", "CR-456", false)
	t.ok(not r02.contains("저수조"), "봉천 소문은 영등포에서 안 돈다(권역)")
	st.vars.set_v("JM_REG", 1)
	var jm: Array = []
	for d in 8:
		st.vars.set_v("GAME_DAY", d)
		jm.append(Rumors.pick(st, "R02", "CR-456", false))
	t.ok(jm.any(func(s): return s.contains("단골")), "상인회 일을 하면 지하시장 사람들이 '단골'로 부른다(SD-03a §8.3 기울기)")
	t.ok(not jm.any(func(s): return s.contains("볼트 양반")), "단골이 된 뒤엔 '볼트 양반'이라 부르지 않는다")
