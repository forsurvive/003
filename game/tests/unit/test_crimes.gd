## 교차 감사 1-X: 생사 한 곳(st.dead ↔ D_ 변수 · 별칭) · 알려진 죽음 · 범죄 반응(SD-06 §3.4 범죄 · §3.8 · §6.4) · 아이 비전투(SD-11 §580) ·
## 죽은 화자 줄 건너뜀 · 정착지 경보(SD-14 §9.12 자경단) · 적대 정착지 인사 · MQ-101 대체(조만석 → 하숙자 → 게시판, SD-03a §6.3) · 봉천이 문을 닫음(결과 6).
extends RefCounted


func _st(act := 1) -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", act)
	st.vars.set_v("GAME_DAY", 1)
	return st


func test_dead_single_source(t) -> void:
	var st := _st()
	st.kill("C-013")
	t.eq(int(st.get_var("D_HDC")), 1, "황두칠 죽음 → D_HDC는 dead에서 계산된다(P1 한 곳)")
	t.ok(StoryExpr.test("D_HDC == 1", st), "원고 조건도 같은 사실을 본다")
	st.set_var("D_JMS", 1)
	t.ok(st.is_dead("C-010"), "D_JMS = 1을 쓰면 조만석이 죽은 것으로 적힌다")
	t.eq(int(st.get_var("D_DS")), 0, "D_DS는 다니엘 서(SD-03a) — 독사와 상관없다")
	st.kill("C-021")
	t.eq(int(st.get_var("D_DS")), 0, "독사를 죽여도 다니엘 서는 살아 있다(예전엔 D_DS로 적었다)")
	st.kill("N-R01-027")
	t.ok(st.is_dead("C-015") and int(st.get_var("D_BG")) == 1, "별칭(N-R01-027)으로 죽어도 백구 C-015가 죽은 것")
	t.ok(StoryExpr.test('dead("C-015") == 1', st), "원고 함수 dead()")
	t.ok(st.is_child("N-R01-034") and not st.is_child("N-R01-028"), "남솔(10세)은 아이 — 공격 대상이 아니다(SD-11 §580)")


func test_dead_speaker_skipped(t) -> void:
	var st := _st()
	var g := {"id": "T", "labels": {"START": 0}, "ops": [{"op": "line", "who": "C-010", "emo": "기본", "text": "나는 조만석"},
		{"op": "line", "who": "N-R01-028", "emo": "기본", "text": "나는 남태하"}, {"op": "end"}]}
	st.kill("C-010")
	var r := DialogueRunner.new(st)
	var first: Dictionary = r.start(g)
	t.eq(str(first.get("who", "")), "N-R01-028", "죽은 인물의 줄은 건너뛰고 다음 줄(진행기가 연 장면에 섞여 있어도)")


func test_crime_witnessed_and_leader(t) -> void:
	var st := _st()
	var now := 1000
	var a0 := int(st.vars.get_v("AFF_JC_BC"))
	var o := Crimes.on_kill(st, "N-R01-030", true, "R01", now, "BC")
	t.eq(str(o["tgt"]), "JC_BC", "남무진(JC·BC) → 봉천 정착지 호감")
	t.eq(int(st.vars.get_v("AFF_JC_BC")), a0 - 35, "목격된 이름 있는 인물 살해 −35(SD-06 §3.4)")
	t.eq(int(st.deeds.grudge.get("JC_BC", 0)), 1, "원한 플래그")
	t.ok(Crimes.knows_killer(st, "N-R01-030"), "봉천은 범인을 안다")
	Crimes.on_kill(st, "C-010", true, "R01", now + 5, "BC")
	t.eq(int(st.vars.get_v("AFF_JC_BC")), -100, "대표(조만석) 살해: −100 고정")
	t.ok(Crimes.permanent(st, "JC_BC") and Crimes.hostile(st, "JC_BC"), "영구 적대")
	st.call_fn("aff", ["BC", 15])
	t.eq(int(st.vars.get_v("AFF_JC_BC")), -100, "영구 적대는 어떤 원천으로도 오르지 않는다(§3.8)")


func test_crime_unwitnessed_body(t) -> void:
	var st := _st()
	var now := 2000
	Crimes.on_kill(st, "N-R01-030", false, "R01", now, "BC")
	t.eq(int(st.vars.get_v("AFF_JC_BC")), 0, "아무도 못 봤다: 아직 반응 없음(세계가 알아야 반영 — §3.1 원칙 5)")
	st.kill("N-R01-030")
	t.ok(not st.known_dead("N-R01-030"), "시체가 발견되기 전에는 그 죽음을 아무도 모른다")
	var b: Dictionary = st.deeds.bodies[0]
	t.ok(int(b["find"]) >= now + 60 and int(b["find"]) <= now + 1440, "시체는 1~24시간 안에 발견된다(§6.4)")
	b["solve"] = true
	st.deeds.tick(st, int(b["find"]) + 1)
	t.ok(st.known_dead("N-R01-030") and st.deeds.mourn.has("JC_BC"), "발견 뒤: 봉천이 죽음을 안다")
	t.eq(int(st.vars.get_v("AFF_JC_BC")), -35, "범인 지목(30%)이 되면 이름 있는 인물 −35")
	var st2 := _st()
	Crimes.on_kill(st2, "N-R01-031", false, "R01", now, "BC")
	st2.kill("N-R01-031")
	st2.deeds.bodies[0]["solve"] = false
	st2.deeds.tick(st2, now + 1500)
	t.ok(st2.known_dead("N-R01-031") and int(st2.vars.get_v("AFF_JC_BC")) == 0, "지목 못 하면: 죽음은 알지만 범인은 모른다(호감 그대로)")
	t.ok(not Crimes.knows_killer(st2, "N-R01-031"), "범인 모름")


func test_crime_massacre(t) -> void:
	var st := _st()
	for i in 5:
		Crimes.on_kill(st, ["N-R01-030", "N-R01-031", "N-R01-033", "N-R01-035", "N-R01-036"][i], true, "R01", 100 + i, "BC")
	t.ok(Crimes.permanent(st, "JC_BC") and int(st.vars.get_v("AFF_JC_BC")) == -100, "같은 정착지 주민 5명 이상 = 학살, 영구 적대")


func test_crime_save_roundtrip(t) -> void:
	var st := _st()
	Crimes.on_kill(st, "C-010", true, "R01", 50, "BC")
	Crimes.on_kill(st, "N-R01-031", false, "R01", 60, "BC")
	var d := st.deeds.to_dict()
	var dd := Deeds.new()
	dd.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.eq([int(dd.grudge.get("JC_BC", 0)), dd.bodies.size(), dd.known_killer.has("C-010"), int(dd.kills.get("JC_BC", 0))], [2, 1, true, 2], "범죄 기록이 저장 · 불러오기를 지난다")


func test_mq101_substitute_conds(t) -> void:
	var st := _st()
	st.quests.set_stage("MQ-101", 20)
	var s2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/MQ-101_S2_HA.json"))
	t.ok(not StoryExpr.test(str(s2["cond"]), st), "조만석이 살아 있으면 하숙자 대체 장면은 닫혀 있다")
	Crimes.on_kill(st, "C-010", false, "R01", 100, "BC")
	st.kill("C-010")
	t.ok(not StoryExpr.test(str(s2["cond"]), st), "죽었지만 시체가 발견되기 전 — 하숙자는 아직 모른다(N4)")
	st.deeds.bodies[0]["solve"] = false
	st.deeds.tick(st, 100 + 1500)
	t.ok(StoryExpr.test(str(s2["cond"]), st), "시체가 발견되고 범인을 모르면 — 하숙자가 이장 일을 잇는다(SD-03a §6.3)")
	var board: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/X-BC_BOARD.json"))
	t.ok(JSON.stringify(board["ops"]).contains("ACTING"), "이장 · 부이장이 모두 없으면 게시판이 최후 대체(공고)")


func _x_bc() -> Array:
	if not InputMap.has_action("fire"):
		var setup: Node = load("res://systems/input/input_setup.gd").new()
		setup._ready()
		setup.free()
	var st := _st()
	var m := InteriorMap.new()
	m.load_map("X-BC", st)
	var c := InteriorCombat.new()
	m.add_child(c)
	var a := Actor.new()
	a.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), Vector2(20 * 32 + 16, 26 * 32 + 16), m)
	m.add_actor(a)
	c.on_map(m, a, st)
	var host := InteriorHost.new()
	host.st = st
	host.map = m
	host.combat = c
	host.player = a
	host.ev = EventRunner.new()
	host.date_text = "2277. 10. 23.  16:00"
	c.resident_hit.connect(host._on_resident_hit)
	c.resident_down.connect(host._on_resident_down)
	var npcs: Array = []
	var ids := ["N-R01-030", "N-R01-028", "N-R01-035", "N-R01-034"]
	for i in ids.size():
		var na := Actor.new()
		na.setup("st_" + ids[i].to_lower().replace("-", "_"), Vector2((19 + i) * 32 + 16, 24 * 32 + 16), m)
		m.add_actor(na)
		m.blockers.append(na)
		npcs.append({"id": ids[i], "actor": na, "routine": null, "bark": ""})
	host.npcs = npcs
	c.set_residents(npcs.filter(func(x): return not st.is_child(str(x["id"]))))
	return [st, m, c, host]


func test_settlement_alarm(t) -> void:
	var w := _x_bc()
	var st: StoryState = w[0]
	var c: InteriorCombat = w[2]
	var host: InteriorHost = w[3]
	t.ok(c.resident("N-R01-034") == null, "아이(남솔)는 전투 대상 목록에 없다 — 맞지도 죽지도 않는다")
	c.resident("N-R01-030").take({"hp": 500.0}, Vector2.ZERO)
	t.ok(st.is_dead("N-R01-030"), "남무진 사망")
	t.eq(int(st.vars.get_v("AFF_JC_BC")), -35, "곁의 주민이 보았다 — 봉천 −35")
	t.ok(host.alarmed.has("JC_BC"), "정착지 안 살인 목격 → 경보(SD-14 §9.12)")
	var militia := c.enemies.filter(func(e): return is_instance_valid(e) and e.has_meta("militia"))
	t.eq(militia.size(), 2, "자경단원 둘(남태하 · 오재윤)이 그 모습 그대로 총을 든다")
	t.ok(militia.all(func(e): return e.who in ["N-R01-028", "N-R01-035"] and str(e.get_meta("enemy_id", "")) == "CR-466"), "CR-466 계단마을 자경단원")
	t.eq(host._hostile_bark("N-R01-034"), "……(아이가 뒷걸음질 쳐 어른 뒤로 숨는다)", "경보 중 아이는 숨는다")
	host._on_enemy_down(militia[0])
	t.ok(st.is_dead(militia[0].who), "쓰러진 자경단원은 그 사람이 죽은 것 — 다시 서지 않는다")
	host.ev.free()


## 장면을 돌려 나오는 대사(화자 · 글)를 모은다 — 연출 명령은 넘기고, 선택지에선 멈춘다
func _lines(st: StoryState, sid: String) -> Array:
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % sid))
	var r := DialogueRunner.new(st)
	var out: Array = []
	var cur: Dictionary = r.start(g)
	for i in 80:
		match str(cur.get("type", "")):
			"line":
				out.append([str(cur.get("who", "")), str(cur.get("text", ""))])
			"cmd":
				pass
			_:
				break
		cur = r.advance()
	return out


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(l): return str(l[1]).contains(part))


## 교차 표 보강(장면마다 생사)이 찾은 것들: 동물은 아이가 아니다 · 백구 생사 · 거처 열쇠 대체 · 독사 사살 판 · 처음 보는 개
func test_cross_scene_guards(t) -> void:
	var st := _st()
	t.ok(not st.is_child("C-015") and not st.is_child("N-R01-027"), "백구(6살 진돗개)는 아이가 아니다 — 공격할 수 있다(예전엔 나이만 보고 아이로 쳤다)")
	t.ok(st.is_child("N-R01-034"), "남솔은 그대로 아이")
	var bowl := _lines(st, "X-BC_BOWL")
	t.ok(_said(bowl, "비어 있다"), "백구가 살아 개집에 있으면 빈 그릇")
	st.vars.set_v("SQ_S01_DOG", 1)
	t.ok(_said(_lines(st, "X-BC_BOWL"), "다른 데 있다"), "백구가 동행 중이면 개집이 비었다")
	st.vars.set_v("SQ_S01_DOG", 0)
	Crimes.on_kill(st, "C-015", false, "R01", 100, "BC")                # 아무도 못 봤다 — 시체는 아직
	st.kill("C-015")
	t.ok(_said(_lines(st, "X-BC_BOWL"), "다른 데 있다"), "죽었지만 아무도 모른다 — 그릇은 그냥 빈 개집 앞(N12: 누가 물을 채우지 않는다)")
	st.quests.set_stage("MQ-101", 100)
	t.ok(_said(_lines(st, "SQS01_NAMSOL"), "안 들어왔어"), "아무도 모르는 죽음 — 남솔은 '안 들어왔어'(N12)")
	var st2 := _st()
	st2.quests.set_stage("MQ-101", 100)
	Crimes.on_kill(st2, "C-015", false, "R01", 100, "BC")
	st2.kill("C-015")
	st2.deeds.bodies[0]["solve"] = false
	st2.deeds.tick(st2, 1700)
	t.ok(st2.known_dead("C-015") and _said(_lines(st2, "SQS01_NAMSOL"), "습관"), "죽음이 알려진 뒤 — 남솔은 빈 그릇에 물을 채운다")
	t.ok(_said(_lines(st2, "X-BC_BOWL"), "마실 개는"), "알려진 뒤 — 물만 채워진 그릇")
	# 거처 열쇠(SD-15 §7.2): 조만석이 죽어도 거처는 닫히지 않는다(P11) — 하숙자 → 반상회 쪽지
	var st3 := _st()
	Crimes.on_kill(st3, "C-010", false, "R01", 100, "BC")
	st3.kill("C-010")
	st3.deeds.bodies[0]["solve"] = false
	st3.deeds.tick(st3, 1700)
	var key := _lines(st3, "HOME_BC_KEY")
	t.ok(key.size() > 0 and key[0][0] == "C-057", "조만석의 죽음이 알려지면 하숙자가 열쇠를 건넨다")
	t.eq(int(st3.vars.get_v("HOME_BC")), 1, "열쇠 · 거처가 선다")
	st3.vars.set_v("HOME_BC", 0)
	st3.kill("C-057")
	t.ok(_said(_lines(st3, "HOME_BC_KEY"), "봉천 반상회"), "하숙자도 없으면 문고리의 반상회 쪽지")
	# MQ-101 결과 1에서 독사를 쏴 죽였으면 '도망쳤어'가 아니다(N4)
	var st4 := _st()
	st4.vars.set_v("MQ101_RESULT", 1)
	t.ok(_said(_lines(st4, "MQ-101_R1"), "도망쳤어"), "독사가 달아났으면 '피 흘리면서 도망쳤어'")
	st4.kill("C-021")
	var r1 := _lines(st4, "MQ-101_R1")
	t.ok(_said(r1, "누워 있어") and not _said(r1, "도망쳤어"), "독사를 죽였으면 '아랫문 밑에 누워 있어'")
	# 아랫문: 백구를 산에서 본 적 없으면 '산에서 본 그 개'가 아니다(N1) · 남태하가 없으면 빈 초소
	var st5 := _st()
	st5.quests.set_stage("MQ-101", 10)
	t.ok(_said(_lines(st5, "MQ-101_GATE"), "낯선 냄새"), "처음 보는 개")
	st5.kill("N-R01-028")
	t.ok(_said(_lines(st5, "MQ-101_GATE"), "초소가 비어"), "문지기가 죽었으면 빈 초소 분필 글씨 — 그래도 MQ-101은 이어진다")
	t.eq(st5.quests.stage("MQ-101"), 20, "단계 20")


## 페르소나 재검수(1-X)가 짚은 것: 게시판 ACTING2 도달 · 밤 소동 때 시체 발견 · 살인을 아는 세계 · 자백 · 개를 쏜 경보 · 원인별 적대 인사
func test_cross_persona_followups(t) -> void:
	# ① 이장 · 부이장이 밤 뒤에 죽어도 MQ-101이 단계 50에 걸리지 않는다(예전엔 R1~R5 갈래가 먼저라 ACTING2에 닿지 못했다)
	var st := _st()
	st.quests.set_stage("MQ-101", 50)
	st.vars.set_v("MQ101_RESULT", 1)
	st.kill("C-010")
	st.kill("C-057")
	var board := _lines(st, "X-BC_BOARD")
	t.ok(_said(board, "감시조가 정리한다"), "게시판 ACTING2 공고")
	t.eq(st.quests.stage("MQ-101"), 100, "MQ-101 완료 · MQ-102로")
	# ② 밤 소동: 봉천에 아직 발견되지 않은 시체가 있으면 그때 발견된다
	var st2 := _st()
	Crimes.on_kill(st2, "C-010", false, "R01", 1000, "BC")
	st2.kill("C-010")
	t.ok(not st2.known_dead("C-010"), "몰래 죽임 — 아직 모른다")
	t.eq(Crimes.find_now(st2, "JC_BC", 1001), 1, "밤 소동에 시체 하나가 발견된다")
	t.ok(st2.known_dead("C-010"), "이제 마을이 안다 — 밤 장면은 하숙자 · 남솔 판으로")
	# ③ 자백: 직접 죽였고 아무도 몰랐던 살인만
	var st3 := _st()
	st3.quests.set_stage("MQ-101", 20)
	Crimes.on_kill(st3, "C-010", false, "R01", 100, "BC")
	st3.kill("C-010")
	st3.deeds.bodies[0]["solve"] = false
	st3.deeds.tick(st3, 1700)
	t.ok(StoryExpr.test('victim("C-010") == 1 and killer_known("BC") == 0', st3), "직접 죽였지만 마을은 범인을 모른다")
	t.eq(int(st3.call_fn("confess", ["C-010"])), 1, "자백")
	t.ok(Crimes.knows_killer(st3, "C-010") and Crimes.permanent(st3, "JC_BC"), "대표 살해 자백 — 영구 적대(MQ-101은 안전한 순간 결과 6)")
	t.eq(int(st3.call_fn("confess", ["C-010"])), 0, "같은 살인을 두 번 자백할 수 없다")
	t.eq(int(st3.call_fn("confess", ["C-057"])), 0, "죽이지 않은 사람은 자백할 수 없다")
	t.ok(StoryExpr.test('killer_known("BC") == 1', st3), "원고 함수 killer_known")
	var st4 := _st()
	Crimes.on_kill(st4, "N-R01-026", true, "R01", 100, "BC")
	st4.kill("N-R01-026")
	st4.quests.set_stage("MQ-101", 20)
	t.ok(_said(_lines(st4, "MQ-101_S2"), "다 안다"), "목격된 살인 뒤 이장은 '마을이 다 안다'고 말한다")
	# ④ 개를 쏘면 '살인'이 아니라 '쐈어', 살인이 아닌 적대는 '살인자'라 부르지 않는다
	t.eq(Crimes.obj("백구"), "백구를", "목적격 조사(받침 없음)")
	t.eq(Crimes.obj("남솔"), "남솔을", "목적격 조사(받침 있음)")
	var w := _x_bc()
	var hst: StoryState = w[0]
	var host: InteriorHost = w[3]
	t.ok(not Crimes.killer_known_by(hst, "JC_BC"), "아직 아무도 안 죽였다")
	hst.vars.set_v("AFF_JC_BC", -70)
	var bark := host._hostile_bark("N-R01-030")
	t.ok(bark != "" and not bark.contains("살인자"), "살인 없이 적대(≤ −60)면 '살인자'라 부르지 않는다: " + bark)
	host.ev.free()
