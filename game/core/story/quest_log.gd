## 퀘스트 단계 (SD-03a §4.4): 퀘스트마다 `<키>_STAGE`(0 미발동 / 10 발동 / 20~90 진행 / 100 종료 / 200 실패) 변수를
## 갖고, 결과는 `<키>_RESULT`, 먼저 이룬 단계로 건너뛰면 `<키>_SKIP = 1`. 값은 변수 저장소에 둔다(저장 왕복이 공짜).
## 정의(game/data/quests.json)는 파이프라인이 기획서 '단계별 목표' 표에서 뽑는다: 단계 번호 → 퀘스트 로그 문장·완료 조건.
class_name QuestLog
extends RefCounted

var defs := {}                  ## id -> {"key": "MQP1", "title": ..., "stages": {"10": {"log":..., "done":...}, ...}}
var vars: VarStore
var events: Array = []          ## [{"kind": "start"|"update"|"done"|"fail", "id", "stage", "text"}] — 알림 UI가 꺼내 간다
var acts: Array = []            ## 막 구조(SD-03a §3.1): [{"n", "name", "title", "goal", "quests", "paths"}]
var tracked := ""               ## 추적 퀘스트(SD-12 §3.12, "act:n" = 막 단위 추적) — 1개
var pinned: Array = []          ## 고정 퀘스트 — 2개까지


func _init(v: VarStore) -> void:
	vars = v


func load_defs(path: String) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	acts = d.get("acts", [])
	for id in d["quests"]:
		defs[id] = d["quests"][id]
		var key: String = defs[id]["key"]
		for suffix in ["_STAGE", "_RESULT", "_SKIP"]:
			if not vars.has(key + suffix):
				vars.declare(key + suffix, "int", 0)


func key_of(id: String) -> String:
	return defs[id]["key"] if defs.has(id) else id.replace("-", "")


func stage(id: String) -> int:
	var v = vars.get_v(key_of(id) + "_STAGE")
	return int(v) if v != null else 0


## 단계를 올린다(내려가지 않는다). 중간 단계를 건너뛰면 SKIP = 1(건너뛴 단계 XP는 주지 않는다는 규칙의 근거).
## 반환: 실제로 바뀌었는지
func set_stage(id: String, n: int) -> bool:
	var cur := stage(id)
	if n <= cur or cur >= 100:
		return false
	var key := key_of(id)
	var sts := stages_of(id)
	var skipped := false
	for s in sts:
		if s > cur and s < n and s != 200 and cur > 0:
			skipped = true
	vars.set_v(key + "_STAGE", n)
	if skipped:
		vars.set_v(key + "_SKIP", 1)
	var kind := "update"
	if cur == 0:
		kind = "start"
	if n == 100:
		kind = "done"
	elif n == 200:
		kind = "fail"
	events.append({"kind": kind, "id": id, "stage": n, "text": log_text(id, n)})
	return true


func stages_of(id: String) -> Array:
	var out := []
	if defs.has(id):
		for s in defs[id]["stages"]:
			out.append(int(s))
	out.sort()
	return out


func log_text(id: String, n: int) -> String:
	if defs.has(id) and defs[id]["stages"].has(str(n)):
		return defs[id]["stages"][str(n)]["log"]
	return ""


func title(id: String) -> String:
	return defs[id]["title"] if defs.has(id) else id


## 진행 중 퀘스트의 현재 목표 줄(핍-보이 DATA 탭)
func active() -> Array:
	var out := []
	for id in defs:
		var s := stage(id)
		if s > 0 and s < 100:
			out.append({"id": id, "title": title(id), "stage": s, "log": log_text(id, s)})
	return out


# ---------------------------------------------------------------- 막·경로(SD-12 §3.12)
func act_of(id: String) -> int:
	return int(defs.get(id, {}).get("act", -1))


func act_def(n: int) -> Dictionary:
	for a in acts:
		if int(a["n"]) == n:
			return a
	return {}


## 지금 막(V_ACT). 프롤로그 = 0
func cur_act() -> int:
	return int(vars.get_v("V_ACT")) if vars.has("V_ACT") else 0


## 막 목표를 이뤘나(SD-03a §4.1 전환 판정의 목표 부분): 프롤로그 = MQ-P4 종료, 1막 = 코드의 정체(K_CODE)
func act_goal_met(n: int) -> bool:
	match n:
		0:
			return stage("MQ-P4") >= 100
		1:
			return vars.has("K_CODE") and int(vars.get_v("K_CODE")) >= 1
	return false


## 막 머리 줄 상태: [이룸] = 목표를 이뤘다
func act_tag(n: int) -> String:
	return "[이룸]" if act_goal_met(n) else ("[진행 중]" if n == cur_act() else "")


## 경로 상태(SD-12 §3.12): [알려진 것 없음] [진행 중] [이룸] [다른 길로 이룸] [끝남] [놓침] [선택]
func path_tag(id: String) -> String:
	var s := stage(id)
	var a := act_of(id)
	var is_path: bool = bool(defs.get(id, {}).get("path", false))
	if s >= 200:
		return "[놓침]"
	if s >= 100:
		return "[이룸]"
	if is_path and act_goal_met(a):
		return "[다른 길로 이룸]" if s > 0 else "[끝남]"
	if s > 0:
		return "[진행 중]"
	return "[알려진 것 없음]" if is_path else ""


## 퀘스트의 가장 최근 사실 줄(지금 단계 이하에서 기록이 있는 가장 큰 단계)
func latest_line(id: String) -> String:
	var s := stage(id)
	var best := ""
	for n in stages_of(id):
		if n <= s and n < 100 and log_text(id, n) != "":
			best = log_text(id, n)
	return best


func places_of(id: String) -> Array:
	return defs.get(id, {}).get("places", [])


## 추적 켜기·끄기(Enter). 같은 것을 다시 고르면 끈다
func track(id: String) -> void:
	tracked = "" if tracked == id else id
	pinned.erase(id)


## 고정 켜기·끄기(F, 최대 2개 — 넘치면 가장 먼저 고정한 것이 빠진다)
func pin(id: String) -> void:
	if id in pinned:
		pinned.erase(id)
		return
	if id == tracked:
		return
	pinned.append(id)
	while pinned.size() > 2:
		pinned.pop_front()


## 주 퀘스트가 시작될 때 자동 추적(SD-12 §3.12 '추적 1개 = 기본 마커'): 추적이 비었거나 추적하던 퀘스트가 끝났으면 넘겨받는다
func auto_track(id: String) -> void:
	if not id.begins_with("MQ"):
		return
	if tracked == "" or (not tracked.begins_with("act:") and stage(tracked) >= 100) \
			or (tracked.begins_with("act:") and act_goal_met(int(tracked.substr(4)))):
		tracked = id
		pinned.erase(id)


## 추적 대상이 가리키는 퀘스트들(막 머리 = 그 막의 경로 전부, 경로가 없는 막은 진행 중인 퀘스트)
func tracked_ids(what: String) -> Array:
	if not what.begins_with("act:"):
		return [what] if what != "" else []
	var a := act_def(int(what.substr(4)))
	var out: Array = (a.get("paths", []) as Array).duplicate()
	if out.is_empty():
		for id in a.get("quests", []):
			if stage(id) > 0 and stage(id) < 100:
				out.append(id)
	return out


## 퀘스트 마커(SD-12 §3.12): 추적 + 고정 퀘스트의 장소 중 위치가 알려진 곳(표시 이상 = ▼, 소문 = ? 원). 위치를 모르면 마커 없음.
## 퀘스트당 8개까지, 2개 이상이면 번호 ①~⑧. 끝난·놓친 퀘스트는 없음. 반환 [{"lid", "id", "n", "rumor", "main": 추적에서 왔나}]
func marks(places: PlaceLog) -> Array:
	var out: Array = []
	var done := {}
	for src in [tracked] + pinned:
		for id in tracked_ids(src):
			if done.has(id) or stage(id) >= 100:
				continue
			done[id] = true
			var got: Array = []
			for lid in places_of(id):
				var ps := places.get_state(lid)
				if ps < PlaceLog.RUMOR or got.size() >= 8:
					continue
				got.append({"lid": lid, "id": id, "n": 0, "rumor": ps == PlaceLog.RUMOR, "main": src == tracked})
			if got.size() > 1:
				for i in got.size():
					got[i]["n"] = i + 1
			out.append_array(got)
	return out


## HUD 목표 줄(SD-12 §4.2·§3.12): 추적 1 + 고정 2 = 최대 3줄. 각 줄 = 가장 최근 사실 줄(없으면 막 목표·제목).
## 추적이 없거나 끝났으면 지금 막에서 진행 중인 첫 퀘스트가 대신한다. 반환 ["▶ …", "◆ …"]
func objectives() -> Array:
	var out: Array = []
	var head := _goal_line(tracked)
	if head == "":
		for n in [cur_act()] + range(0, 8):
			for id in act_def(n).get("quests", []):
				if head == "" and stage(id) > 0 and stage(id) < 100:
					head = latest_line(id)
	if head != "":
		out.append("▶ " + head)
	for id in pinned:
		var l := _goal_line(id)
		if l != "" and out.size() < 3:
			out.append("◆ " + l)
	return out


func _goal_line(what: String) -> String:
	if what == "":
		return ""
	if what.begins_with("act:"):
		var n := int(what.substr(4))
		return "" if act_goal_met(n) else str(act_def(n).get("goal", ""))
	var s := stage(what)
	if s <= 0 or s >= 100:
		return ""
	var l := latest_line(what)
	return l if l != "" else title(what)
