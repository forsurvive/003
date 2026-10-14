## 단계 0-12 자동 검사(SD-19 §5.3 '조사 토큰 자동 검사 오류 0, 대화창 넘침 0'): 데이터 파이프라인이 만든 대사 그래프 전부를
## 주인공 이름 세 벌(받침 있음·없음·가장 긴 이름 성 2 + 이름 4)로 풀어 보고 실제 대화창 글꼴(갈무리11 12px)로 잰다.
##   ① 풀고 남은 제어 코드·중괄호·'이(가)' 같은 겸용 표기 0  ② \J 조사 앞에 붙을 글자가 있다(공백·괄호 뒤 조사 0)
##   ③ 대사 한 줄 = 대화창 폭(484px, SYS 584px) 안에 어절이 들어간다(어절을 글자 단위로 끊어야 하는 줄 0)
##   ④ 선택지 = 2줄 안(대화창은 3줄째를 잘라 버린다)  ⑤ 퀘스트 목표 문구 30자 이하(SD-18 §8.3)
extends RefCounted

const NAMES := [["윤", "서진"], ["윤", "서아"], ["남궁", "하늘빛나"]]
const LEFTOVER := ["이(가)", "을(를)", "은(는)", "와(과)", "(으)로", "(이)", "\\", "{", "}"]

var font: Font


func _graphs() -> Array:
	var out := []
	for f in DirAccess.get_files_at("res://data/dialogue"):
		if f.ends_with(".json") and not f.begins_with("_"):
			out.append(JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + f)))
	return out


func _state(n: Array) -> StoryState:
	var st := StoryState.new()
	st.load_data()
	st.vars.set_v("P_SURNAME", n[0])
	st.vars.set_v("P_GIVEN", n[1])
	st.vars.set_v("P_FULL", n[0] + n[1])
	return st


func _w(s: String) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x


## 어절 단위로 들어가는가: 어절 하나가 폭보다 넓으면 글자 단위로 끊어야 한다(넘침으로 친다)
func _word_fits(text: String, width: float) -> String:
	for para in text.split("\n"):
		for word in para.split(" "):
			if _w(word) > width:
				return word
	return ""


func test_dialogue_text(t) -> void:
	font = load("res://assets/fonts/Galmuri11.ttf")
	var graphs := _graphs()
	t.ok(graphs.size() >= 50, "대사 그래프 %d개" % graphs.size())
	var lines := 0
	var bad := []
	for n in NAMES:
		var st := _state(n)
		for g in graphs:
			var id := str(g.get("id", "?"))
			for op in g["ops"]:
				if op["op"] != "line":
					continue
				lines += 1
				var src := str(op["text"])
				var txt: String = TextFmt.format(src, st)["text"]
				for lo in LEFTOVER:
					if txt.contains(lo):
						bad.append("%s 남은 표기 '%s': %s" % [id, lo, txt])
				var k := src.find("\\J[")
				while k >= 0:
					if k == 0 or src[k - 1] in [" ", "(", "[", "「", "\n"]:
						bad.append("%s 조사 앞 글자 없음: %s" % [id, src])
					k = src.find("\\J[", k + 3)
				var width := TextWrap.wrap(txt, func(s: String) -> float: return _w(s), 584.0 if str(op["who"]) == "SYS" else 484.0)
				var wide := _word_fits(txt, 584.0 if str(op["who"]) == "SYS" else 484.0)
				if wide != "":
					bad.append("%s 어절이 대화창보다 넓다(%s): %s" % [id, n[1], wide])
				for ln in width:
					if _w(ln) > (584.0 if str(op["who"]) == "SYS" else 484.0) + 0.5:
						bad.append("%s 줄 넘침: %s" % [id, ln])
	t.ok(lines > 1000, "대사 %d줄(이름 3벌)" % lines)
	t.eq(bad, [], "대사 조사·넘침 오류 0")


func test_choice_rows(t) -> void:
	font = load("res://assets/fonts/Galmuri11.ttf")
	var bad := []
	var rows := 0
	for n in NAMES:
		var st := _state(n)
		st.vars.set_v("V_REGCARD", 8)                              # 관리자 인증 태그도 보이게
		for g in _graphs():
			var r := DialogueRunner.new(st)
			r.g = g
			r.show_locked = true
			for op in g["ops"]:
				if op["op"] != "choice":
					continue
				var opts := []
				for o in op["opts"]:
					var c: Dictionary = o.duplicate(true)
					c["cond"] = ""                                    # 조건과 관계없이 모든 선택지를 잰다
					opts.append(c)
				for s in r._visible(opts):
					rows += 1
					var disp := str(s["display"]).replace("[화술 0%]", "[화술 100%]")   # 가장 넓은 판정 표시로
					var tag := ""
					var body := disp
					if body.begins_with("["):
						var k := body.find("] ")
						while k >= 0 and body.substr(k + 2).begins_with("["):
							k = body.find("] ", k + 2)
						if k >= 0:
							tag = body.substr(0, k + 1)
							body = body.substr(k + 2)
					var tag_w := _w(tag + " ") if tag != "" else 0.0
					var w := 488.0 - 34.0 - tag_w
					var ls := TextWrap.wrap(body, func(x: String) -> float: return _w(x), w)
					if ls.size() > 2:
						bad.append("%s 선택지 3줄 이상(%s): %s" % [str(g.get("id", "?")), n[1], disp])
					for lo in LEFTOVER:
						if disp.contains(lo):
							bad.append("%s 선택지 남은 표기 '%s': %s" % [str(g.get("id", "?")), lo, disp])
	t.ok(rows > 100, "선택지 %d줄" % rows)
	t.eq(bad, [], "선택지 넘침·표기 오류 0")


func test_quest_log_length(t) -> void:
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))["quests"]
	var bad := []
	var n := 0
	for id in q:
		var stages: Dictionary = q[id].get("stages", {})
		for k in stages:
			var log := str(stages[k].get("log", ""))
			n += 1
			if log.length() > 30:
				bad.append("%s %s (%d자): %s" % [id, k, log.length(), log])
	t.ok(n > 10, "퀘스트 목표 %d줄" % n)
	t.eq(bad, [], "퀘스트 목표 30자 이하(SD-18 §8.3)")


## 검사기가 실제로 잡는지: 일부러 틀린 글을 넣어 본다
func test_checker_catches(t) -> void:
	font = load("res://assets/fonts/Galmuri11.ttf")
	t.ok(_word_fits("가" .repeat(50), 484.0) != "", "대화창보다 넓은 어절을 잡는다")
	t.eq(_word_fits("가나다 라마바", 484.0), "", "보통 어절은 통과")
	var st := _state(NAMES[0])
	var txt: String = TextFmt.format("\\P 이(가) 왔다 {P_GIVEN|이}", st)["text"]
	t.ok(LEFTOVER.any(func(lo): return txt.contains(lo)), "겸용 표기·중괄호를 잡는다: " + txt)
	t.eq(TextFmt.format("\\P\\J[이] 왔다", st)["text"], "서진이 왔다", "받침 있는 이름 + 이")
	t.eq(TextFmt.format("\\P\\J[이] 왔다", _state(NAMES[1]))["text"], "서아가 왔다", "받침 없는 이름 + 가")
