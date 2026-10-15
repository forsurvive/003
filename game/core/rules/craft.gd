## 제작·조리 규칙(단계 1-8c, SD-13 §7.9 · SD-12 §11.3). 자료: data/recipes.json(craft_export.py).
## · 알려진 레시피: 설계도가 없는 것(수리 키트 · 대못 · 마취 다트 · 조리)은 늘 알고, 설계도 레시피는 설계도를 1장 이상 가졌을 때.
## · 퍽 레시피(PK-111 휴대 정수 키트 · PK-009 손맛 조리): 퍽 변수(PK_111 등)가 서야 만든다 — 퍽 체계가 생기기 전엔 잠김.
## · 품질(§7.9.4): 설계도 사본 1장 = 수리 상한보다 1단계 낮게(최저 위태) · 2장 = 상한 · 3장 이상 = 1단계 높게(최대 새것).
##   폭발물은 사본 수(최대 3)만큼 재료 1세트당 개수. 4장째부터는 효과가 없다(판매용).
## · 조리(§7.9.5): 화덕·작업대 앞이거나 휴대용 버너(M-047, 소모 안 됨)를 가졌을 때. 물은 가장 맑은 것부터 쓴다(라드가 적은 순).
##   물에 라드가 있으면 결과물은 '기본ID+물ID' 변형(라드가 재료 합만큼 붙는다).
class_name Craft
extends RefCounted

const BURNER := "M-047"
const WATER := ["I-054", "I-055", "I-056", "I-057", "I-058", "I-059"]
const ORDER := ["I-067", "건설용 대못", "마취 다트", "W-151", "W-152", "W-153", "W-154", "W-155", "W-156", "W-157", "M-074",
	"I-077", "I-078", "I-079", "I-080", "I-081", "I-082", "I-083", "I-084"]
const PERK_NAMES := {"PK-009": "손맛", "PK-111": "휴대 정수"}

static var recipes := {}
static var _rads := {}                                    ## 물 ID → 라드(가장 맑은 물부터 쓰려고)


static func load_data() -> void:
	if not recipes.is_empty():
		return
	if FileAccess.file_exists("res://data/recipes.json"):
		recipes = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
	if FileAccess.file_exists("res://data/items_drink.json"):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items_drink.json"))
		for w in WATER:
			_rads[w] = int(d.get(w, {}).get("rads", 0))


## 보이는 레시피 목록(cook: 조리만 / 아니면 제작만). 설계도 레시피는 설계도를 가졌을 때만 보인다(SD-12 §11.3 '보유한 것만')
static func listing(st: StoryState, cook: bool) -> Array:
	load_data()
	var out: Array = []
	for rid in ORDER:
		if not recipes.has(rid):
			continue
		var r: Dictionary = recipes[rid]
		if bool(r.get("cook", false)) != cook:
			continue
		if str(r.get("blueprint", "")) != "" and copies(st, r) <= 0:
			continue
		out.append(rid)
	return out


static func copies(st: StoryState, r: Dictionary) -> int:
	var bp := str(r.get("blueprint", ""))
	return int(st.items.get(bp, 0)) if bp != "" else 0


static func perk_ok(st: StoryState, r: Dictionary) -> bool:
	var pk := str(r.get("perk", ""))
	if pk == "":
		return true
	var v := pk.replace("-", "_")
	return st.vars.has(v) and int(st.vars.get_v(v)) > 0


## 불(조리): 작업대·화덕 앞(station)이거나 휴대용 버너를 가졌다
static func heat_ok(st: StoryState, station: bool) -> bool:
	return station or int(st.items.get(BURNER, 0)) > 0


## 재료 칸 하나에 쓸 수 있는 수(같은 칸의 '또는' 재료를 모두 센다)
static func have(st: StoryState, slot: Dictionary) -> int:
	var n := 0
	for id in slot["any"]:
		n += int(st.items.get(str(id), 0))
	return n


## 지금 몇 세트 만들 수 있나(재료·캡·설계도·퍽·불)
static func max_sets(st: StoryState, rid: String, station: bool = true) -> int:
	load_data()
	var r: Dictionary = recipes.get(rid, {})
	if r.is_empty() or not perk_ok(st, r):
		return 0
	if str(r.get("blueprint", "")) != "" and copies(st, r) <= 0:
		return 0
	if bool(r.get("cook", false)) and not heat_ok(st, station):
		return 0
	var m := 99
	for slot in r["needs"]:
		m = mini(m, have(st, slot) / int(slot["n"]))
	if int(r.get("caps", 0)) > 0:
		m = mini(m, int(st.vars.get_v("PC_CAPS")) / int(r["caps"]))
	return maxi(m, 0)


## 한 세트로 나오는 개수: 폭발물은 사본 수(최대 3), 탄약은 표의 수(대못 20 · 다트 10), 나머지 1
static func per_set(st: StoryState, rid: String) -> int:
	var r: Dictionary = recipes.get(rid, {})
	if str(r.get("kind", "")) == "explosive":
		return clampi(copies(st, r), 1, 3)
	return int(r.get("count", 1))


## 제작 무기의 만든 직후 상태(0 새것 ~ 3 위태): 수리 상한 ± 사본 수(§7.9.4)
static func quality(st: StoryState, rid: String) -> int:
	var r: Dictionary = recipes.get(rid, {})
	if str(r.get("kind", "")) != "weapon":
		return 0
	var cap := Gear.repair_cap(st.skill("REPAIR"))
	var c := copies(st, r)
	if c <= 1:
		return mini(cap + 1, 3)
	if c == 2:
		return cap
	return maxi(cap - 1, 0)


## 재료 칸에서 실제로 쓸 순서: 물은 맑은 것부터, 그 밖은 표 순서
static func _order(slot: Dictionary) -> Array:
	var ids: Array = (slot["any"] as Array).duplicate()
	if ids == WATER:
		ids.sort_custom(func(a, b): return int(_rads.get(a, 0)) < int(_rads.get(b, 0)))
	return ids


## 만들 결과물의 열쇠(조리의 물 변형 · 무기 상태)
static func out_key(st: StoryState, rid: String) -> String:
	var r: Dictionary = recipes.get(rid, {})
	if str(r.get("kind", "")) == "weapon":
		return Gear.key_of(rid, quality(st, rid))
	var vars: Dictionary = r.get("variants", {})
	if not vars.is_empty():
		for slot in r["needs"]:
			if slot["any"] == WATER:
				for w in _order(slot):
					if int(st.items.get(w, 0)) > 0:
						return str(vars.get(w, rid))
	return rid


## n세트 만든다: {"ok", "key", "count", "why"} — 재료·캡을 꺼내고 결과물을 넣는다(한 번에, 반쯤 된 상태 없음)
static func make(st: StoryState, rid: String, n: int = 1, station: bool = true) -> Dictionary:
	load_data()
	var r: Dictionary = recipes.get(rid, {})
	if r.is_empty():
		return {"ok": false, "why": "모르는 레시피"}
	if not perk_ok(st, r):
		return {"ok": false, "why": "퍽 필요: " + str(PERK_NAMES.get(str(r["perk"]), r["perk"]))}
	if bool(r.get("cook", false)) and not heat_ok(st, station):
		return {"ok": false, "why": "불이 없다(작업대·화덕 또는 휴대용 버너)"}
	if n <= 0 or max_sets(st, rid, station) < n:
		return {"ok": false, "why": "재료가 모자란다"}
	var made := {}
	for k in n:
		var key := out_key(st, rid)                                       # 세트마다(물이 바뀔 수 있다)
		for slot in r["needs"]:
			var left := int(slot["n"])
			for id in _order(slot):
				var take := mini(left, int(st.items.get(id, 0)))
				if take > 0:
					st.call_fn("take", [id, take])
					left -= take
				if left <= 0:
					break
		if int(r.get("caps", 0)) > 0:
			st.vars.set_v("PC_CAPS", int(st.vars.get_v("PC_CAPS")) - int(r["caps"]))
		var cnt := per_set(st, rid)
		st.call_fn("give", [key, cnt])
		made[key] = int(made.get(key, 0)) + cnt
	var first: String = made.keys()[0]
	return {"ok": true, "key": first, "count": int(made[first]), "made": made}
