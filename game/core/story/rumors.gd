## 소문(1-4f, STAGE_1 §1.1 '세계가 행적을 기억한다'): 대화 장면이 없는 주민이 주인공의 실제 행적을 혼잣말로 전한다.
## 자료 data/rumors.json(원고 script/world/rumors.txt). 조건이 붙은 소문이 먼저, 같은 사람은 하루 동안 같은 말(날마다 바뀐다).
## 머리 줄 셋째 칸 '판도 PD-Rxx-n'이 붙은 소문을 들으면 그 구역의 아는 판이 고쳐진다(1-12m, SD-06 §5.7).
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
		(hit if c != "" and not bool(r.get("usual", false)) else plain).append(r)      # usual: 조건이 있어도 평소 소문(그 상태가 '보통'인 소문 — 1-13a3)
	var day := int(st.vars.get_v("GAME_DAY")) if st.vars.has("GAME_DAY") else 0
	var h := absi(hash(who + ":" + str(day)))
	var row: Dictionary = {}
	if own_bark:
		row = hit[h % hit.size()] if not hit.is_empty() and h % 2 == 0 else {}
	else:
		var pool: Array = hit if not hit.is_empty() and (plain.is_empty() or h % 4 != 0) else plain
		row = {} if pool.is_empty() else pool[h % pool.size()]
	if row.is_empty():
		return ""
	if str(row.get("turf", "")) != "":
		st.turf.hear(st, str(row["turf"]))                             # 판도 소문(1-12m): 들은 구역의 아는 판을 고친다(출처 = 그 동네 사람)
	return str(row["text"])
