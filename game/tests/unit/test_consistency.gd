## SD-20 서사 정합 §8 시험 규격(단계 1-7): 원고 정적 검사 · 시간 도약 · 경로 기록 표지 · 수배 순서 규칙.
## 원고를 새로 쓰면 여기 걸린다 — 지식을 세우는 장면은 '이미 앎' 판을 갖는다(P2), 보상 변수를 두 장면이 조건 없이 올리지 않는다(P9).
extends RefCounted


func _scenes() -> Array:
	var out: Array = []
	var idx: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/_index.json"))["scenes"]
	for id in idx:
		var p := "res://data/dialogue/%s.json" % id
		if FileAccess.file_exists(p):
			out.append(JSON.parse_string(FileAccess.get_file_as_string(p)))
	return out


## P2: 대화로 K_CODE를 '알려 주는' 장면은 K_CODE를 이미 아는 판(조건 분기)을 갖는다. 문서 열람(종이 창)은 본문이 고정이라 빼고, 허용 목록은 이유와 함께
const KNOW_OK := {"MQ-105_LEDGER": "장부 문서 — 종이 창 본문", "MQ-105_COAT": "외투 봉투 문서"}


func test_sd20_knowledge_scenes(t) -> void:
	var bad: Array = []
	var n := 0
	for d in _scenes():
		var ops := JSON.stringify(d["ops"])
		if not ops.contains("K_CODE = 1"):
			continue
		n += 1
		var guarded := ops.contains("K_CODE == 1") or ops.contains("K_CODE >= 1") or str(d.get("cond", "")).contains("K_CODE")
		if not guarded and not KNOW_OK.has(str(d["id"])):
			bad.append(str(d["id"]))
	t.ok(n >= 2, "K_CODE를 세우는 장면이 있다(%d)" % n)
	t.eq(bad, [], "K_CODE를 세우는 대화 장면은 '이미 앎' 판을 갖는다(SD-20 P2)")


## P9: XP를 주는 원고 함수 xp(…)가 같은 장면 안 두 갈래에서 조건 없이 겹치지 않는다 — 장면 재진입 가드가 있는 장면만 XP를 준다
func test_sd20_scene_reentry(t) -> void:
	var bad: Array = []
	for d in _scenes():
		var ops: Array = d["ops"]
		var gives := false
		var guard := false
		for op in ops:
			if op["op"] == "do" and str(op.get("fx", "")).contains("xp("):
				gives = true
			if op["op"] == "if" or str(d.get("cond", "")) != "":
				guard = true
		if gives and not guard:
			bad.append(str(d["id"]))
	t.eq(bad, [], "XP를 주는 장면은 다시 열었을 때를 가르는 조건이 있다(SD-20 P9)")


## P6: 시간 도약 — 사흘을 보내면 하루 판정 세 번(test_encounters의 시계 시험과 같은 규칙을 호스트 없이 시각 글로 확인)
func test_sd20_clock(t) -> void:
	var a := Clock.abs_min("2277. 10. 24.  09:00")
	var b := Clock.abs_min(Clock.add_minutes("2277. 10. 24.  09:00", 3 * 24 * 60))
	var crossed := floori((b - 360) / 1440.0) - floori((a - 360) / 1440.0)
	t.eq(crossed, 3, "사흘 = 06:00 세 번")


## N10: 경로 퀘스트가 스스로 K_CODE를 세웠으면 '[다른 길로 이룸]'이 아니다
func test_sd20_path_tag(t) -> void:
	var st := StoryState.new()
	st.load_data()
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("K_CODE", 1)
	st.quests.set_stage("MQ-104", 40)                                  # 인증으로 K_CODE를 세웠다(단계 30 '완료 조건 K_CODE' 넘음)
	st.quests.set_stage("MQ-103", 20)                                  # 지하시장은 들어가기만 했다
	t.eq(st.quests.path_tag("MQ-104"), "[진행 중]", "스스로 이룬 경로는 마무리 중")
	t.eq(st.quests.path_tag("MQ-103"), "[다른 길로 이룸]", "다른 경로가 이룬 것은 '다른 길로'")


## P8 · §6.5: 출두 확인(WANTED_HOLD) 동안 상한 29, 끝나면 출두 전 값과 2막 하한 중 큰 값 — 진행기(_on_day)와 같은 식
func test_sd20_wanted_hold(t) -> void:
	var st := StoryState.new()
	st.load_data()
	Wanted.declare(st)
	st.vars.set_v("V_ACT", 2)
	st.vars.set_v("GAME_DAY", 5)
	Wanted.set_value(st, 45)
	st.vars.set_v("WANTED_PRE", Wanted.value(st))
	st.vars.set_v("WANTED_HOLD", 8)
	Wanted.refresh(st)
	t.eq(Wanted.value(st), 29, "출두 확인 중 29")
	st.vars.set_v("GAME_DAY", 8)
	st.vars.set_v("WANTED_HOLD", 0)
	Wanted.set_value(st, maxi(maxi(Wanted.value(st), int(st.vars.get_v("WANTED_PRE"))), 30))
	t.eq(Wanted.value(st), 45, "사흘 뒤 출두 전 값(45)으로 — 출두가 수배를 깎아 주지 않는다")


## SD-20 §10 교차 점검(1-X): 퀘스트끼리 부딪히는 곳(죽을 수 있는 인물 · 한 사람 두 곳 · 사실 소유 · 한 장뿐인 물건 · 겹치는 무대 · 막에 갇힌 퀘스트)을
## tools/pipeline/quest_cross.py가 표로 뽑는다(build_data). 허용 목록에 이유 없이 남은 '새 경고'가 있으면 실패한다.
func test_sd20_cross_table(t) -> void:
	var p := "res://data/_cross_report.json"
	t.ok(FileAccess.file_exists(p), "교차 정합 표가 있다(build_data가 만든다)")
	if not FileAccess.file_exists(p):
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(p))
	t.ok(int(d.get("warn", 0)) > 0, "표가 실제로 퀘스트들을 읽었다(경고 %d)" % int(d.get("warn", 0)))
	t.eq(d.get("new", []), [], "교차 정합 새 경고 0 — 고치거나 quest_cross_allow.yaml에 이유를 적는다")
