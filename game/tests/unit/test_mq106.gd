## MQ-106 첫 번째 추적자(단계 1-7, SD-03a §8.6 · §4.1 · §6.5 · §6.7 · SD-09d C05): 버티버드 시트 · 원고 장면 · 대치 선택지(행동 넷) ·
## 청계산 귀빈실 맵(CG-05) · 압수품 보관함 자리 · '출두 확인' 사흘 등급 1 · 진행기 변수.
extends RefCounted


func _map(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func test_vb_sheet(t) -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Vertibird.META))
	for k in ["body", "body_open", "rotor0", "rotor1", "rotor2", "shadow0", "shadow3"]:
		t.ok(m["frames"].has(k), "버티버드 칸 %s" % k)
	t.eq(m["rotor_at"].size(), 2, "날개 끝 회전익 둘")
	var d: Array = m["door"]
	var sz: Array = m["size"]
	t.ok(int(d[0]) + int(d[2]) <= int(sz[0]) and int(d[1]) + int(d[3]) <= int(sz[1]) and int(d[1]) + int(d[3]) < Vertibird.GROUND_Y,
		"화물칸 문이 기체 칸 안, 땅(스키드 줄)보다 위")
	t.ok(ResourceLoader.exists(Vertibird.SHEET), "시트 그림")


func test_vb_scenes(t) -> void:
	var idx: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/_index.json"))["scenes"]
	for s in ["MQ-106_RADIO", "MQ-106_LAND", "MQ-106_YUK", "MQ-106_CARGO", "MQ-106_DOYUN_FREE", "MQ-106_GONE", "MQ-106_RIDE",
			"MQ-106_DROP", "CG-05_ARRIVE", "CG-05_SEOHYEON", "CG-05_NAMGUNG", "CG-05_NAMGUNG2", "CG-05_DESK", "CG-05_TEA", "ACT2_BROADCAST"]:
		t.ok(idx.has(s), "장면 %s" % s)
	var texts := []
	var tags := []
	for op in _scene("MQ-106_LAND")["ops"]:
		if op["op"] == "choice":
			for o in op["opts"]:
				texts.append(str(o["text"]))
				for tg in o.get("tags", []):
					tags.append(str(tg["k"]))
	t.ok(tags.has("speech"), "말한다: [화술 보통]")
	t.ok(texts.any(func(s): return s.contains("인증 단말")), "말한다: 여의도 인증 단말 기록(K_CODE를 MQ-104로)")
	t.ok(texts.any(func(s): return s.contains("걸어간다")), "걸어 들어간다(행동)")
	t.ok(texts.any(func(s): return s.contains("달아난다")), "숨는다(달아나 시야 밖)")
	t.ok(texts.any(func(s): return s.contains("너희 사정")), "싸운다")
	var lines := []
	for op in _scene("MQ-106_LAND")["ops"] + _scene("CG-05_NAMGUNG")["ops"]:
		if op["op"] == "line":
			lines.append(str(op["text"]))
	t.ok(lines.any(func(s): return s.contains("명령서를 읽는 사람")), "육지환 핵심 대사(§8.6)")
	t.ok(lines.any(func(s): return s.contains("강요는 서류에 없습니다")), "남궁혁 핵심 대사(§8.6)")
	t.ok(lines.any(func(s): return s.contains("3년 전까지 1순위는 당신 어머니")), "계보(K_LINEAGE — SD-03b MQ-402 면담과 같은 말)")


func test_vb_cg05(t) -> void:
	t.ok(InteriorMap.exists("CG-05"), "청계산 벙커 행정층 CG-05")
	var d := _map("CG-05")
	for mk in ["arrive", "office_in", "from_elev"]:
		t.ok(d["marks"].has(mk), "표지 %s" % mk)
	var ids := {}
	for n in d["npcs"]:
		ids[str(n["id"])] = true
	for id in ["C-003", "N-R11-005", "N-R11-024"]:
		t.ok(ids.has(id), "인물 %s" % id)
	var props := {}
	for p in d["props"]:
		props[str(p["name"])] = true
	for p in ["minister_desk", "flag_stand", "wall_clock", "display_case", "vip_bed", "tea_table", "w_fake_window", "file_cabinet"]:
		t.ok(props.has(p), "소품 %s" % p)
	t.eq(d["exits"].size(), 0, "출구 없음(사흘 뒤 버티버드가 내려 준다)")
	t.ok(d["doors"].any(func(dr): return bool(dr["locked"])), "승강기 홀 문은 잠겼다")
	t.eq(str(d.get("region", "")), "R11", "루팅 권역 R11")


func test_vb_seized(t) -> void:
	var sp: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/spots_src.json"))["spots"]
	var hit: Array = sp.filter(func(s): return str(s.get("lid", "")) == "L-R11-02")
	t.eq(hit.size(), 1, "청계산 위장 환기탑 발견 자리")
	if hit.size() == 1:
		var boxes: Array = hit[0]["data"].get("boxes", [])
		t.ok(boxes.any(func(b): return str(b["kind"]) == "seized"), "압수품 보관함(seized)")
		t.eq(hit[0]["data"].get("enemies", []).size(), 2, "탑을 지키는 경계병 둘")


## 걸어 들어간다: 사흘 동안 등급 1(값 29 이하), 사흘이 지나면 2막 하한 30
func test_vb_wanted_hold(t) -> void:
	var st := StoryState.new()
	st.load_data()
	Wanted.declare(st)
	st.vars.set_v("V_ACT", 2)
	st.vars.set_v("GAME_DAY", 5)
	st.vars.set_v("WANTED_HOLD", 8)
	Wanted.set_value(st, 45)
	t.eq(Wanted.value(st), 29, "출두 확인 중: 등급 1을 넘지 않는다")
	t.ok(Wanted.notice(st).contains("출두 확인"), "공고 문안 '출두 확인'")
	st.vars.set_v("GAME_DAY", 8)
	Wanted.refresh(st)
	t.ok(Wanted.value(st) >= 30, "사흘 뒤 2막 하한(등급 2)")


func test_vb_vars(t) -> void:
	var st := StoryState.new()
	st.load_data()
	for k in ["MQ106_STAGE", "MQ106_RESULT", "MQ106_CUSTODY", "MQ106_TALKED", "MQ106_SEIZED", "MQ106_AT", "K_SIGNER", "K_LINEAGE",
			"PD_R01_BJ", "V_DOYUN", "V_ACT"]:
		t.ok(st.vars.has(k), "변수 %s" % k)
