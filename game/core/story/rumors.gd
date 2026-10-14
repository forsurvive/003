## 소문(1-4f, STAGE_1 §1.1 '세계가 행적을 기억한다'): 대화 장면이 없는 주민이 주인공의 실제 행적을 혼잣말로 전한다.
## 자료 data/rumors.json(원고 script/world/rumors.txt). 조건이 붙은 소문이 먼저, 같은 사람은 하루 동안 같은 말(날마다 바뀐다).
class_name Rumors
extends RefCounted

static var rows: Array = []


static func _load() -> void:
	if not rows.is_empty() or not FileAccess.file_exists("res://data/rumors.json"):
		return
	rows = JSON.parse_string(FileAccess.get_file_as_string("res://data/rumors.json"))["rumors"]


## who(인물 ID·자리)가 region(R01 등)에서 할 소문 한 줄. own_bark가 있는 인물은 행적 소문만, 그것도 이틀에 하루만 한다. 없으면 ""
static func pick(st: StoryState, region: String, who: String, own_bark := false) -> String:
	_load()
	var hit: Array = []
	var plain: Array = []
	for r in rows:
		var wh := str(r["where"])
		if wh != "*" and wh != region:
			continue
		var c := str(r["cond"])
		if c != "" and not StoryExpr.test(c, st):
			continue
		(hit if c != "" else plain).append(str(r["text"]))
	var day := int(st.vars.get_v("GAME_DAY")) if st.vars.has("GAME_DAY") else 0
	var h := absi(hash(who + ":" + str(day)))
	if own_bark:
		return hit[h % hit.size()] if not hit.is_empty() and h % 2 == 0 else ""
	var pool: Array = hit if not hit.is_empty() and (plain.is_empty() or h % 4 != 0) else plain
	return "" if pool.is_empty() else str(pool[h % pool.size()])
