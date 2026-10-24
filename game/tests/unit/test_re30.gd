## 기본 RE 표 30종(단계 1-13e, D-130 · 계획 _plans/1-13_closing_plan.md §5): 장소 반경(near) · 판(variants) · 우두머리 레벨 문턱 ·
## 조건 배수(mult_if) · 같은 RE 쿨다운(SD-05 §6.6) · 위협도 보정(§6.3) · 시작 효과(on_start) · 새 EP · 원고 장면.
extends RefCounted


func _st(act := 1) -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", act)
	st.vars.set_v("GAME_DAY", 3)
	return st


func test_re30_table(t) -> void:
	var tab := Encounters.table()
	var n := 0
	for id in tab:
		var regs = tab[id].get("regions", "*")
		var here: bool = typeof(regs) != TYPE_ARRAY or "R01" in regs or "R02" in regs
		if here and RegEx.create_from_string("^RE-(\\d{3}|X\\d{2})$").search(str(id)) != null:
			n += 1
	t.ok(n >= 29, "R01 · R02 표 RE %d종(+ 원고 RE-045 = 30, 판 RE-104E는 따로 세지 않음)" % n)
	for id in ["RE-006", "RE-008", "RE-033", "RE-039", "RE-041", "RE-053", "RE-055", "RE-069"]:
		t.ok(tab.has(id), "%s 표에 있음" % id)
		var d: Dictionary = tab[id]
		for v in d.get("variants", []):
			var talk := str(v.get("talk", d.get("talk", "")))
			if talk != "":
				t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % talk), "%s 판 장면 %s" % [id, talk])
	var eps: Array = Encounters.data.get("ep", [])
	var ids := eps.map(func(e): return str(e["id"]))
	t.ok("EP-X-R02-01" in ids and "EP-X-UG-06" in ids, "국회 정문 · 영등포시장역 입구 EP(정착지 반경에 걸린 자리 RE)")


func test_re30_near_variant_leader(t) -> void:
	var st := _st()
	var en := Encounters.new(st, 11)
	var d6 := Encounters.re_def("RE-006")
	t.ok(Encounters.near_ok(d6, Vector2i(760, 1060)), "국회 곁 = 왕개미 후보")
	t.ok(not Encounters.near_ok(d6, Vector2i(900, 1400)), "봉천 = 왕개미 아님(3청크 밖)")
	t.ok(Encounters.near_ok(Encounters.re_def("RE-001"), Vector2i(900, 1400)), "near 없는 RE는 어디서나")
	# 판: 조건이 맞는 판만(봉천 개를 돌려보냈으면 사당 개 판만)
	st.vars.set_v("RE053_BC", 2)
	for i in 20:
		var v := en.with_variant("RE-053")
		t.ok(str(v.get("on_start", "")).contains("RE_V = 2"), "봉천 개는 이미 집 — 사당 개 판만")
		if not str(v.get("on_start", "")).contains("RE_V = 2"):
			break
	# 시작 효과: 사냥꾼이 그날 산에 간다(봉천 오두막이 빈다)
	var v39 := en.with_variant("RE-039")
	StoryExpr.run(str(v39["on_start"]), st)
	t.eq(int(st.vars.get_v("HUNT_OUT")), 3, "RE-039 시작 효과 = HUNT_OUT 오늘")
	t.ok(int(st.vars.get_v("RE_V")) in [1, 2, 3], "판 번호")
	# 우두머리 레벨 문턱: 왕쥐는 Lv5부터
	var d8 := Encounters.re_def("RE-008").duplicate(true)
	d8["groups"] = d8["variants"][1]["groups"]
	var low := 0
	var high := 0
	for i in 30:
		if "CR-097" in en.groups("RE-008", 3, "S6", d8)[0]["ids"]:
			low += 1
		if "CR-097" in en.groups("RE-008", 6, "S6", d8)[0]["ids"]:
			high += 1
	t.eq(low, 0, "Lv3 = 왕쥐 없음")
	t.eq(high, 30, "Lv6 = 왕쥐가 이끈다(판 ②)")
	var big := 0
	for i in 30:
		big = maxi(big, (en.groups("RE-006", 10, "S3")[0]["ids"] as Array).count("CR-081"))
	t.ok(big <= 1, "1막 왕개미 병정 최대 1(밸런스 조율)")


func test_re30_mult_cool_threat(t) -> void:
	var st := _st()
	var en := Encounters.new(st, 5)
	en.ctx = {"hour": 12, "level": 3}
	var d8 := Encounters.re_def("RE-008")
	var at := Vector2i(716, 1113)
	var m0 := en.cat_mult(d8, "R02", at, false)
	st.vars.set_v("RQ22_ON", 1)
	t.ok(absf(en.cat_mult(d8, "R02", at, false) - m0 * 0.5) < 0.001, "RQ-22 배수구 청소 중 = 지하상가 쥐 절반")
	# 위협도 보정: 위협 1~2 상인 ×1.5 · 사건 ×1.3
	var calm := Vector2i(24 * 40 + 5, 1503)                         # 위협 1
	t.eq(Encounters.threat_at(calm), 1, "견본 칸 위협 1")
	t.ok(absf(en.pick_mult(Encounters.re_def("RE-036"), calm) - 1.5) < 0.01, "위협 1 상인 ×1.5(고르기에만)")
	t.ok(absf(en.pick_mult(Encounters.re_def("RE-042"), calm) - 1.3) < 0.01, "위협 1 사건 ×1.3(고르기에만)")
	t.ok(absf(en.cat_mult(Encounters.re_def("RE-036"), "R01", calm, false) - 1.0) < 0.01, "굴림 확률 배수에는 위협도 보정이 없다(두 번 곱하지 않음)")
	var d41 := Encounters.re_def("RE-041")
	var p0 := en.pick_mult(d41, calm)
	en.ctx["radio"] = true
	t.ok(absf(en.pick_mult(d41, calm) - p0 * 2.0) < 0.01, "라디오 켜짐 = 조난 신호 고르기 ×2")
	t.ok(absf(en.cat_mult(d41, "R01", calm, false) - en.cat_mult(d41, "R01", calm, false)) < 0.001 and en.cat_mult(d41, "R01", calm, false) < 1.01, "라디오 배수는 굴림에 안 들어간다")
	en.ctx.erase("radio")
	# 쿨다운: 상인 3일 · 그 밖 2일 · 같은 구역
	en.now_min = 10000
	en._remember_pick("RE-036", "S1", calm)
	t.ok(en.cooling("RE-036", calm), "고물상을 만난 직후 같은 구역 쿨다운")
	en.now_min = 10000 + 71 * 60
	t.ok(en.cooling("RE-036", calm), "71시간 뒤에도(상인 72시간)")
	en.now_min = 10000 + 73 * 60
	t.ok(not en.cooling("RE-036", calm), "73시간 뒤 풀림")
	en._remember_pick("RE-001", "S1", calm)
	en.now_min += 49 * 60
	t.ok(not en.cooling("RE-001", calm), "크리처는 48시간")
	# 범주 분모: 고른 RE는 늘 설 수 있는 후보다(다른 권역 전용 · 쿨다운 중은 안 나옴)
	en.ctx = {"hour": 12, "level": 3, "tags": []}
	en.now_min = 50000
	var seen := {}
	for i in 300:
		var id := en._pick("R01", false, calm)
		if id != "":
			seen[id] = true
			t.ok(not en.cooling(id, calm), "쿨다운 중인 RE가 나오지 않음")
			var regs = Encounters.re_def(id).get("regions", "*")
			t.ok(typeof(regs) != TYPE_ARRAY or "R01" in regs, "%s는 R01에 설 수 있다" % id)
	t.ok(not seen.has("RE-006") and not seen.has("RE-008"), "봉천 쪽 판정엔 국회 · 지하상가 RE가 없다")


func test_re30_category_mix(t) -> void:
	# D-394 '범주 비율'(SD-05 §6.3 표 ±25%): 판도 구역마다 실제 고르기(_pick)의 범주 몫이 표 × 위협도 보정과 맞는다.
	# 기대 몫 = 표 가중 × (위협 1~2 상인 1.5 · 사건 1.3 / 위협 4~5 상인 0.5 · 크리처 1.3)을, 그 자리에 설 후보가 있는 범주끼리 나눈 값.
	# 상인회 · 새벽인력 · 정착지 연합이 지배하는 구역은 그 세력 순찰 RE가 아직 없어 순찰이 적다(D-404 — 내용 몫)
	var st := _st()
	var en := Encounters.new(st, 21)
	en.ctx = {"hour": 12, "level": 3, "tags": []}
	en.now_min = 90000
	var seen := {}
	var checked := 0
	for y in range(1060, 1600, 36):
		for x in range(600, 1120, 36):
			var c := Vector2i(x, y)
			var es: Dictionary = st.turf.enc_state(st, c)
			if es.is_empty():
				continue
			var zone := str(es["zone"])
			if seen.has(zone):
				continue
			seen[zone] = true
			var region := zone.get_slice("-", 1)
			var cw := en._cat_table(region, c)
			var th := Encounters.threat_at(c)
			var got := {}
			var n := 0
			for i in 1500:
				var id := en._pick(region, false, c)
				if id == "":
					continue
				var cat := str(Encounters.re_def(id).get("cat", ""))
				got[cat] = int(got.get(cat, 0)) + 1
				n += 1
			if n < 500:
				continue
			var pw := 0.0                                                       # 순찰 몫 = 서 있는 순찰 RE의 세력 몫(지배 · 경쟁 세력의 순찰 RE가 없으면 그만큼 다른 범주로 — 1-13e 범주 분모 규칙)
			var pn := 0.0
			for id in Encounters.table():
				var d: Dictionary = Encounters.table()[id]
				if str(d.get("cat", "")) == "patrol" and en._allowed(d, region, false, th) and Encounters.near_ok(d, c):
					pw += float(d["weight"]) * Encounters._patrol_share(d, cw)
					pn += float(d["weight"])
			var exp := {}
			var tot := 0.0
			for cat in got:
				var m := 1.0
				if th in [1, 2]:
					m = 1.5 if cat == "trader" else (1.3 if cat == "event" else 1.0)
				elif th >= 4:
					m = 0.5 if cat == "trader" else (1.3 if cat == "creature" else 1.0)
				exp[cat] = float(cw.get(cat, 0)) * m * ((pw / pn) if cat == "patrol" and pn > 0.0 else 1.0)
				tot += float(exp[cat])
			var bad: Array = []
			for cat in got:
				var want := float(exp[cat]) / tot
				var share := float(got[cat]) / n
				if want >= 0.05 and absf(share - want) > want * 0.25 + 0.02:       # ±25%(작은 몫은 표본 흔들림 2점을 더 봐 준다)
					bad.append("%s %.0f%%(표 %.0f%%)" % [cat, share * 100.0, want * 100.0])
			t.ok(bad.is_empty(), "%s(%s · 위협 %d) 범주 몫이 표 ±25%% 안: %s" % [zone, str(es["state"]), th, ", ".join(bad) if not bad.is_empty() else "맞음"])
			checked += 1
	t.ok(checked >= 4, "판도 구역 %d곳을 견줬다" % checked)
