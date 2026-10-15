## 단계 1-9d 방사능(SD-11 §11.2 · §9.2 방사능 함정 · §9.3 차량 잔류): 단계·능력치 감소(최대 HP는 그대로) · 저항(지구력 · 옷 · 약, 상한 85%) ·
## 0.5초 피폭 식(최소 0.1) · 지대 근원(맵 rad 줄 · 웅덩이 · 폐기물 드럼 · 차 폭발 · 열린 차폐 용기 · 월드 고리) · 1,000 사망 · 차폐 용기 함정(압력판 → 열림 → 봉인).
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("PC_EN", 5)
	st.vars.set_v("PC_AG", 6)
	st.vars.set_v("PC_ST", 5)
	return st


func _open(m: InteriorMap, w: int, h: int) -> Vector2i:
	for y in range(1, 60):
		for x in range(1, 80):
			var ok := true
			for dy in h:
				for dx in w:
					var t := Vector2i(x + dx, y + dy)
					if m.is_solid(t) or m.cover_at(t) != 0:
						ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _setup(st: StoryState, data := {}, props: Array = []) -> Array:
	if not InputMap.has_action("fire"):
		var setup: Node = load("res://systems/input/input_setup.gd").new()
		setup._ready()
		setup.free()
	var m := InteriorMap.new()
	m.load_map("D-02", st)
	var o := _open(m, 14, 7)
	for k in data:
		var rows: Array = data[k]
		for r in rows:
			r["x"] = int(r["x"]) + o.x
			r["y"] = int(r["y"]) + o.y
		m.data[k] = rows
	for p in props:
		m.add_runtime_prop(str(p[0]), o + Vector2i(int(p[1]), int(p[2])))
	var c := InteriorCombat.new()
	m.add_child(c)
	var a := Actor.new()
	a.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), Vector2(o.x * 32 + 16, (o.y + 6) * 32 + 16), m)
	m.add_actor(a)
	c.on_map(m, a, st)
	for e in c.enemies.duplicate():
		c.drop_enemy(e)
	return [m, c, a, o]


func _at(o: Vector2i, dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func _run(c: InteriorCombat, st: StoryState, secs: float) -> void:
	for i in int(secs * 60.0):
		c.tick(1.0 / 60.0, true, st)


func test_rad_stage(t) -> void:
	var st := _state()
	t.eq(Radiation.stage(199), 0, "199 = 없음")
	t.eq(Radiation.stage(200), 1, "200 = 경미")
	t.eq(Radiation.stage(650), 3, "650 = 위험")
	t.eq(Radiation.stage(1000), 5, "1,000 = 치사")
	var hp0: float = InteriorCombat.derived(st)["hp_max"]
	var ap0: float = InteriorCombat.derived(st)["ap_max"]
	st.vars.set_v("PC_RADS", 650)
	t.eq(st.stat("EN"), 2, "위험: 지구력 −3")
	t.eq(st.stat("AG"), 4, "위험: 민첩성 −2")
	t.eq(st.stat("ST"), 4, "위험: 힘 −1(소지 한도 −10)")
	t.eq(st.stat_base("EN"), 5, "바탕 능력치는 그대로")
	t.eq(float(InteriorCombat.derived(st)["hp_max"]), hp0, "일시적 지구력 감소는 최대 HP를 깎지 않는다")
	t.ok(float(InteriorCombat.derived(st)["ap_max"]) < ap0, "민첩성 감소는 최대 AP에 반영(%.0f → %.0f)" % [ap0, float(InteriorCombat.derived(st)["ap_max"])])
	st.vars.set_v("PC_RADS", 0)
	t.eq(st.stat("EN"), 5, "라드를 빼면 돌아온다")


func test_rad_expose(t) -> void:
	var st := _state()
	t.near(Radiation.resist(st), 0.08, 0.001, "지구력 5 = 저항 8%")
	for i in 20:
		Radiation.expose(st, 3.0, Radiation.resist(st))
	t.eq(Radiation.rads(st), 27, "Z2 10초 = 3 × 0.5 × 0.92 × 20 = 27.6(정수만 PC_RADS)")
	t.near(st.rad_acc, 0.6, 0.01, "소수는 모아 둔다")
	st.rad_drug = {}
	st.vars.set_v("PC_RADS", 0)
	st.rad_acc = 0.0
	var add := Radiation.expose(st, 1.0, 0.85)
	t.near(add, 0.1, 0.0001, "저항 85%여도 틱당 0.1은 남는다")
	var pct := Radiation.take_drug(st, "I-003")
	t.near(pct, 25.0 * (1.0 + float(st.skill("MEDICINE")) / 50.0), 0.01, "라드-X 25 × (1 + 의학/50)%")
	t.near(Radiation.resist(st), minf(0.85, 0.08 + pct / 100.0), 0.001, "저항에 더한다")
	Radiation.take_drug(st, "I-003")
	t.near(float(st.rad_drug["t"]), 480.0, 0.01, "중복은 시간만 누적(4분 + 4분)")
	Radiation.drug_tick(st, 481.0)
	t.ok(st.rad_drug.is_empty(), "시간이 다 되면 끝")
	var items := {"A-047": {"bonus": "방사능 저항 +30%, 최루·독가스 면역"}, "A-012": {"bonus": "+5 수리, +5 방사능 저항"}}
	st.vars.set_v("PC_TORSO", "A-047")
	t.near(Radiation.resist(st, items), 0.38, 0.001, "민방위 방독복 +30%")
	st.vars.set_v("PC_TORSO", "A-012@3")
	t.near(Radiation.resist(st, items), 0.13, 0.001, "현장 작업복 +5(표기 순서 달라도)")
	st.vars.set_v("PC_RADS", 120)
	st.rad_acc = 0.7
	Radiation.remove(st, 50)
	t.eq(Radiation.rads(st), 70, "라드어웨이")
	t.eq(st.rad_acc, 0.0, "모아 둔 소수도 버린다")
	Radiation.take_drug(st, "I-005")
	var sn := GameSnapshot.story(st)
	t.ok(sn.has("rad_drug") and sn.has("rad_acc"), "저장에 약 · 소수")
	var st2 := _state()
	GameSnapshot.apply_story(st2, sn)
	t.eq(str(st2.rad_drug.get("id", "")), "I-005", "불러오면 약 효과가 이어진다")


func test_rad_field(t) -> void:
	var st := _state()
	var r := _setup(st, {"rad": [{"z": 2, "x": 8, "y": 0, "w": 3, "h": 3, "cond": ""}]}, [["rad_puddle", 1, 1], ["waste_drum", 4, 4]])
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	t.eq(c.rad.dose_at(_at(o, 9, 1)), 3.0, "맵 rad 줄 Z2 = 3라드/초")
	t.eq(c.rad.dose_at(_at(o, 1, 1)), 1.0, "웅덩이 Z1")
	t.eq(c.rad.dose_at(_at(o, 5, 5)), 3.0, "폐기물 드럼 둘레 Z2(2.2t)")
	t.eq(c.rad.dose_at(_at(o, 12, 6)), 0.0, "밖은 0")
	c.ord.zones.append({"p": _at(o, 12, 6), "r": 96.0, "t": 15.0, "t0": 15.0, "kind": "rad", "team": "env", "w": {"rad": 5.0}})
	t.eq(c.rad.dose_at(_at(o, 12, 6)), 5.0, "차 폭발 잔류 5라드/초")
	c.ord.zones.clear()
	a.loco.place(_at(o, 9, 1))
	var r0 := Radiation.rads(st)
	_run(c, st, 4.1)
	t.ok(Radiation.rads(st) - r0 >= 10 and Radiation.rads(st) - r0 <= 12, "지대 안 4초 = 3 × 0.92 × 4 ≈ 11(%d)" % (Radiation.rads(st) - r0))
	t.ok(c.rad_rate > 2.5, "선량계 값(저항 뒤 %.2f)" % c.rad_rate)
	a.loco.place(_at(o, 12, 6))
	var r1 := Radiation.rads(st)
	_run(c, st, 2.0)
	t.eq(Radiation.rads(st), r1, "나오면 멈춘다(자연 감소도 없다)")
	t.eq(c.rad_rate, 0.0, "선량계가 꺼진다")
	var msgs: Array = []
	c.message.connect(func(s): msgs.append(s))
	st.vars.set_v("PC_RADS", 199)
	a.loco.place(_at(o, 9, 1))
	_run(c, st, 1.0)
	t.ok(msgs.any(func(s): return "경미한 방사능 중독" in s), "단계가 오르면 알림")
	st.vars.set_v("PC_RADS", 999)
	st.rad_acc = 0.9
	_run(c, st, 1.0)
	t.ok(c.pc.dead, "1,000 라드 = 사망")
	m.free()


func test_rad_cask(t) -> void:
	var st := _state()
	var traps := [{"type": "radcask", "x": 6, "y": 1, "dir": "E", "len": 1, "id": "rc", "link": "", "cond": ""},
		{"type": "plate", "x": 6, "y": 3, "dir": "E", "len": 1, "id": "", "link": "rc", "cond": ""}]
	var r := _setup(st, {"traps": traps}, [["rad_cask", 6, 1]])
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var cask: Dictionary = c.hazards.items.filter(func(it): return it["type"] == "radcask")[0]
	t.eq(c.hazards.items.filter(func(it): return it["cell"] == o + Vector2i(6, 1)).size(), 1, "용기 소품과 함정 줄은 한 물건")
	t.eq(c.rad.dose_at(_at(o, 6, 2)), 0.0, "닫힌 용기는 새지 않는다")
	a.loco.place(_at(o, 6, 3))
	_run(c, st, 0.2)
	t.eq(cask["state"], "open", "압력판을 밟으면 뚜껑이 열린다")
	t.eq(c.rad.dose_at(_at(o, 6, 3)), 20.0, "열린 용기 20라드/초(2.5t)")
	t.eq(str(st.hazards.get(cask["key"], "")), "open", "열림을 기억한다")
	c.crouch = true
	a.loco.place(_at(o, 6, 2))
	st.vars.set_v("PC_SKP_REPAIR", 0)
	t.eq(c.disarm_tick(0.1, st), "skill", "봉인은 수리 75")
	st.vars.set_v("PC_SKP_REPAIR", 80)
	for i in 12:
		c.disarm_tick(0.1, st)
	t.eq(cask["state"], "done", "봉인")
	t.eq(str(st.hazards.get(cask["key"], "")), "off", "봉인을 기억한다")
	t.eq(c.rad.dose_at(_at(o, 6, 2)), 0.0, "봉인하면 새지 않는다")
	t.eq(int(st.items.get("M-018", 0)), 1, "선원 회수(핵분열 배터리)")
	m.free()
	st.hazards[cask["key"]] = "open"
	var r2 := _setup(st, {"traps": [traps[0].duplicate()]}, [["rad_cask", 6, 1]])
	var c2: InteriorCombat = r2[1]
	t.eq(c2.rad.dose_at(_at(r2[3], 6, 2)), 20.0, "다시 열어도 열린 채")
	(r2[0] as InteriorMap).free()


func test_rad_world(t) -> void:
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/rad.json"))
	var zs: Array = db["zones"]
	t.eq(RadField.world_grade(zs, Vector2(1260, 1460)), 4, "우면 크레이터 중심 Z4")
	t.eq(RadField.world_grade(zs, Vector2(1200, 1460)), 2, "우면 반경 안 Z2")
	t.eq(RadField.world_grade(zs, Vector2(1145, 1460)), 1, "가장자리 12칸은 Z1로 옅어진다")
	t.eq(RadField.world_grade(zs, Vector2(1114, 1408)), 0, "사당 환승촌은 밖")
	t.eq(RadField.world_grade(zs, Vector2(959, 1503)), 0, "볼트 정문은 밖")
	t.eq(RadField.world_grade(zs, Vector2(180, 900)), 5, "김포 크레이터 중심 8칸 Z5")
	t.eq(RadField.world_grade(zs, Vector2(1020, 1140)), 3, "이촌 폭심 수면 Z3")
