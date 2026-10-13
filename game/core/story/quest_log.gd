## 퀘스트 단계 (SD-03a §4.4): 퀘스트마다 `<키>_STAGE`(0 미발동 / 10 발동 / 20~90 진행 / 100 종료 / 200 실패) 변수를
## 갖고, 결과는 `<키>_RESULT`, 먼저 이룬 단계로 건너뛰면 `<키>_SKIP = 1`. 값은 변수 저장소에 둔다(저장 왕복이 공짜).
## 정의(game/data/quests.json)는 파이프라인이 기획서 '단계별 목표' 표에서 뽑는다: 단계 번호 → 퀘스트 로그 문장·완료 조건.
class_name QuestLog
extends RefCounted

var defs := {}                  ## id -> {"key": "MQP1", "title": ..., "stages": {"10": {"log":..., "done":...}, ...}}
var vars: VarStore
var events: Array = []          ## [{"kind": "start"|"update"|"done"|"fail", "id", "stage", "text"}] — 알림 UI가 꺼내 간다


func _init(v: VarStore) -> void:
	vars = v


func load_defs(path: String) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
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
