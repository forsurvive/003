## 대화 실행기 v1 (SD-19 §6.9). 원고 변환기(tools/pipeline/script_compile.py)가 만든 장면 그래프를 한 줄씩 진행한다.
## 화면이 없는 순수 객체: UI(대화 창)와 이벤트 실행기가 step()의 결과를 받아 그리고, advance()/choose()로 다음으로 간다.
## 장면 그래프: {"id", "npc"(화술 대상 기본), "labels": {이름: 위치}, "ops": [...]}
##   line   {"who", "emo", "text"}            대사(화자 SYS = 해설)
##   do     {"fx"}                             효과 식
##   if     {"cond", "to"}                     조건이 참이면 이동
##   goto   {"to"}                             이동(END = 끝)
##   choice {"opts": [{"text", "tags", "cond", "fx", "to", "fail", "id"}]}
##   cmd    {"name", "args"}                   연출 명령(이벤트 실행기가 처리한 뒤 advance)
##   end
class_name DialogueRunner
extends RefCounted

const LOG_MAX := 400                      ## 대화 기록 보존 줄 수(SD-12 §6.6)

var st: StoryState
var g: Dictionary
var pc := 0
var cur: Dictionary = {}
var shown: Array = []                     ## 지금 보이는 선택지(원래 번호 포함)
var log: Array[String] = []               ## 대화 기록: "화자: 대사", "▷ 선택", "[화술 45% → 성공]"
var last_check: Dictionary = {}           ## 마지막 판정 {"pct", "ok"} — UI가 [성공]/[실패]를 0.6초 띄운다
var show_locked := false                  ## 옵션: 요구치 미달 선택지를 회색으로 보이기(기본 숨김, SD-12 §6.3)
var errors: Array[String] = []


func _init(state: StoryState) -> void:
	st = state


func start(graph: Dictionary, label: String = "START") -> Dictionary:
	g = graph
	st.set_meta("speech_target", str(g.get("npc", "")))
	pc = int(g["labels"].get(label, 0))
	return step()


## 다음 보여 줄 것까지 실행한다.
func step() -> Dictionary:
	var guard := 0
	while true:
		guard += 1
		if guard > 10000:
			errors.append("무한 반복 의심: %s @%d" % [g.get("id", "?"), pc])
			cur = {"type": "end"}
			return cur
		if pc >= g["ops"].size():
			cur = {"type": "end"}
			return cur
		var op: Dictionary = g["ops"][pc]
		match op["op"]:
			"line":
				var who := str(op["who"])
				var name := "" if who == "SYS" else st.npc_name(who)
				var f := TextFmt.format(str(op["text"]), st)
				cur = {"type": "line", "who": who, "name": name, "emo": str(op.get("emo", "기본")), "text": f["text"],
					"pauses": f["pauses"], "colors": f["colors"]}
				_log(("%s: %s" % [name, f["text"]]) if name != "" else f["text"])
				return cur
			"do":
				var e := StoryExpr.run(str(op["fx"]), st)
				if e != "":
					errors.append(e)
				pc += 1
			"if":
				if StoryExpr.test(str(op["cond"]), st):
					if _jump(str(op["to"])):
						cur = {"type": "end"}
						return cur
				else:
					pc += 1
			"goto":
				if _jump(str(op["to"])):
					cur = {"type": "end"}
					return cur
			"cmd":
				cur = {"type": "cmd", "name": str(op["name"]), "args": op.get("args", [])}
				return cur
			"choice":
				shown = _visible(op["opts"])
				if shown.is_empty():
					errors.append("보이는 선택지가 없다: %s @%d" % [g.get("id", "?"), pc])
					cur = {"type": "end"}
					return cur
				var list := []
				for s in shown:
					list.append({"text": s["display"], "enabled": s["enabled"], "kind": s["kind"]})
				cur = {"type": "choices", "opts": list}
				return cur
			"end":
				cur = {"type": "end"}
				return cur
			_:
				errors.append("알 수 없는 명령: " + str(op["op"]))
				pc += 1
	return cur


func advance() -> Dictionary:
	if cur.get("type", "") in ["line", "cmd"]:
		pc += 1
	return step()


## i: 보이는 선택지 번호(0부터)
func choose(i: int) -> Dictionary:
	if cur.get("type", "") != "choices" or i < 0 or i >= shown.size() or not shown[i]["enabled"]:
		return cur
	var o: Dictionary = shown[i]["opt"]
	_log("▷ " + shown[i]["display"])
	last_check = {}
	var to := str(o["to"])
	for t in o.get("tags", []):
		match str(t["k"]):
			"caps":
				st.call_fn("caps", [-int(t["n"])])
			"item":
				st.call_fn("take", [str(t["id"]), int(t.get("n", 1))])
			"speech":
				var p := st.speech_chance(str(g.get("npc", "")), str(t["diff"]))
				var ok := Speech.roll(st.check_seed, str(o["id"])) < p
				last_check = {"pct": Speech.percent(p), "ok": ok}
				_log("[화술 %d%% → %s]" % [last_check["pct"], "성공" if ok else "실패"])
				if ok:
					st.call_fn("xp", [int(Speech.XP.get(str(t["diff"]), 0))])
				else:
					st.failed_checks[str(o["id"])] = true
					to = str(o.get("fail", to))
	var e := StoryExpr.run(str(o.get("fx", "")), st)
	if e != "":
		errors.append(e)
	if _jump(to):
		cur = {"type": "end"}
		return cur
	return step()


func _jump(label: String) -> bool:
	if label == "END":
		return true
	if not g["labels"].has(label):
		errors.append("없는 라벨: " + label)
		return true
	pc = int(g["labels"][label])
	return false


func _visible(opts: Array) -> Array:
	var out := []
	for o in opts:
		if not StoryExpr.test(str(o.get("cond", "")), st):
			continue
		if st.failed_checks.has(str(o["id"])):
			continue
		var enabled := true
		var hidden := false
		var kind := "plain"
		var tag_txt := []
		for t in o.get("tags", []):
			match str(t["k"]):
				"speech":
					kind = "speech"
					tag_txt.append("[화술 %d%%]" % Speech.percent(st.speech_chance(str(g.get("npc", "")), str(t["diff"]))))
				"stat":
					kind = "stat"
					tag_txt.append("[%s %d]" % [t["name"], int(t["min"])])
					if st.stat(str(t["name"])) < int(t["min"]):
						hidden = not show_locked
						enabled = false
				"skill":
					kind = "stat"
					tag_txt.append("[%s %d]" % [t["name"], int(t["min"])])
					if st.skill(str(t["name"])) < int(t["min"]):
						hidden = not show_locked
						enabled = false
				"evidence":
					kind = "stat"
					tag_txt.append("[증거: %s]" % st.names.get(str(t["id"]), str(t["id"])))
					if int(st.call_fn("has", [str(t["id"])])) == 0:
						hidden = not show_locked
						enabled = false
				"caps":
					tag_txt.append("[캡 %d]" % int(t["n"]))
					if int(st.get_var("PC_CAPS")) < int(t["n"]):
						enabled = false
				"item":
					tag_txt.append("[물건: %s %d]" % [st.names.get(str(t["id"]), str(t["id"])), int(t.get("n", 1))])
					if int(st.call_fn("has", [str(t["id"]), int(t.get("n", 1))])) == 0:
						enabled = false
				"karma":
					kind = "karma"
					tag_txt.append("[카르마]")
				"admin":
					kind = "admin"
					tag_txt.append("[관리자 인증]")
					if int(st.get_var("V_REGCARD")) < 4:
						hidden = true
				"vault":
					tag_txt.append("[볼트 S-07]")
				"flavor":
					tag_txt.append("[%s]" % t["text"])
		if hidden:
			continue
		var text := TextFmt.plain(str(o["text"]), st)
		var display := (" ".join(tag_txt) + " " + text) if tag_txt.size() > 0 else text
		out.append({"opt": o, "display": display, "enabled": enabled, "kind": kind})
	return out


func _log(line: String) -> void:
	log.append(line)
	if log.size() > LOG_MAX:
		log = log.slice(log.size() - LOG_MAX)
