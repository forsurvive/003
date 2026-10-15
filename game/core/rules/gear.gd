## 장비 상태(내구도) 5단계(단계 1-8a, SD-13 §8 · SD-11 §11.8 · SD-15 §4 상태 배율 · §6.2 정비).
## 상태는 아이템 열쇠에 붙는다: "W-002" = 새것, "W-002@1" 양호 · "@2" 낡음 · "@3" 위태 · "@4" 파손.
## 그래서 상자·거래·압수·저장처럼 열쇠로 아이템을 옮기는 곳은 상태를 그대로 옮긴다(상자에 넣었다 빼면 고쳐지는 일이 없다 — SD-20 N4).
## 아이템 표(items_db)와 무기 표(weapons)에는 불러올 때 @1~@4 변형 항목을 만들어 둔다 — 이름 '(낡음)', 가치·DR 배율, 전투 condition.
class_name Gear
extends RefCounted

const NAMES := ["새것", "양호", "낡음", "위태", "파손"]
const VALUE := [1.0, 0.5, 0.23, 0.05, 0.0]                ## 가치 배율(파손 = 고철 가치)
const DR := [1.0, 0.86, 0.76, 0.67, 0.67]                ## 방어구 DR 배율(파손은 입은 채면 위태 값, SD-13 §8.1)
const COND_KEY := ["new", "good", "worn", "poor", "poor"]   ## CombatRules의 상태 열쇠
const JAM := [0.0, 0.0, 0.25, 0.80, 1.0]                 ## 재장전마다 탄 걸림(SD-13 §8.1)
const WEAPON_STAGE := {"S": 500, "A": 300, "B": 150, "C": 75, "D": 38, "E": 20}   ## 무기: 단계당 사용 횟수(§8.2)
const SCRAP_VALUE := 5                                   ## 파손 = 고철 M-010 1개분
const KIT := "I-067"                                     ## 수리 키트 +1단계(수리 스킬 상한)
const MIL_KIT := "I-068"                                 ## 군용 정비 키트 +2단계(새것까지)


static func base(key: String) -> String:
	var i := key.find("@")
	return key if i < 0 else key.substr(0, i)


static func cond(key: String) -> int:
	var i := key.find("@")
	return 0 if i < 0 else clampi(int(key.substr(i + 1)), 0, 4)


static func key_of(b: String, c: int) -> String:
	return b if c <= 0 else "%s@%d" % [b, clampi(c, 1, 4)]


## 수리 계열(SD-13 §3.13): 같은 계열의 (고유가 아닌) 무기는 서로의 부품이다. 표에 없는 무기는 같은 무기끼리만.
## 방어구는 §5.3 외형 차분 BD 코드가 수리 계열이다(데이터 'layer').
const FAMILY := {
	"리볼버": ["W-001", "W-006"], "자동권총": ["W-002", "W-003", "W-004"], "중국제 소화기": ["W-005", "W-019"],
	"국산 에너지 소화기": ["W-009", "W-010", "W-022"], "미군 레이저": ["W-008", "W-023"], "미군 플라스마": ["W-011", "W-024"],
	"기관단총": ["W-015", "W-016"], "보병·돌격소총": ["W-017", "W-018"], "저격소총": ["W-020", "W-021"],
	"엽총": ["W-014", "W-026", "W-027"], "경찰·군 산탄총": ["W-028", "W-029"], "수제 화기": ["W-013", "W-025"],
	"공구 화기": ["W-007", "W-012", "W-153"], "날붙이": ["W-037", "W-038", "W-039", "W-044", "W-045", "W-155"],
	"둔기": ["W-040", "W-041", "W-042", "W-043", "W-046", "W-047", "W-048", "W-050", "W-051"], "도끼": ["W-049"],
	"비무장": ["W-053", "W-054", "W-055", "W-056", "W-157"],
}
## 고유 장비(W-101~W-130 · A-101~A-117)가 따르는 기반 계열(§3.13 괄호). 고유는 부품을 받지만 부품이 되지는 않는다
const UNIQUE_FAMILY := {
	"W-119": "리볼버", "W-110": "자동권총", "W-112": "자동권총", "W-123": "중국제 소화기",
	"W-104": "국산 에너지 소화기", "W-108": "국산 에너지 소화기", "W-111": "국산 에너지 소화기", "W-127": "국산 에너지 소화기",
	"W-107": "미군 플라스마", "W-103": "보병·돌격소총", "W-106": "보병·돌격소총", "W-116": "저격소총", "W-125": "저격소총",
	"W-101": "엽총", "W-105": "엽총", "W-120": "경찰·군 산탄총", "W-124": "경찰·군 산탄총", "W-129": "경찰·군 산탄총",
	"W-126": "공구 화기", "W-109": "날붙이", "W-102": "둔기", "W-114": "둔기", "W-118": "둔기", "W-122": "둔기", "W-117": "도끼",
}

## 공구 계열 태그(SD-13 §3.13, 퍽 공구 달인 대상): 공구 정비사가 손보는 근접 공구
const TOOL_TAG := ["W-040", "W-043", "W-050", "W-155"]

static var _db := {}                                     ## 무기·방어구 표(정적 판정용 — 루팅 굴림처럼 아이템 표가 없는 곳)


static func db() -> Dictionary:
	if _db.is_empty():
		for f in ["weapons", "items_apparel", "items_apparel_head"]:
			var p := "res://data/%s.json" % f
			if FileAccess.file_exists(p):
				var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(p))
				for id in d:
					var e: Dictionary = d[id]
					if f == "weapons":
						e = e.duplicate()
						e["cat"] = "weapon"
					_db[id] = e
	return _db


## 상태가 있는 장비인가: 무기(맨주먹 ∞ 제외) · 방어구(DR 1 이상)
static func is_gear(entry: Dictionary) -> bool:
	if str(entry.get("cat", "")) == "weapon":
		return grade(entry) != "∞"
	return str(entry.get("cat", "")) == "apparel" and int(entry.get("dr", 0)) > 0


static func is_gear_id(id: String) -> bool:
	return db().has(base(id)) and is_gear(db()[base(id)])


## 내구 등급 글자(S~E · ∞). 표기 'A (NPC 수리만)'은 앞 글자
static func grade(entry: Dictionary) -> String:
	var g := str(entry.get("durability", "B")).strip_edges()
	return "B" if g == "" else g.substr(0, 1)


## 부품 수리 불가(표기 'NPC 수리만' — T-51b A-051, SD-13 §5.4)
static func npc_only(entry: Dictionary) -> bool:
	return str(entry.get("durability", "")).contains("NPC")


## 고유 장비(세계에 하나, SD-13 §3.12): W-101~W-130 · A-101~A-150
static func is_unique(id: String) -> bool:
	var b := base(id)
	var n := int(b.substr(2)) if b.length() >= 5 else 0
	return (b.begins_with("W-") or b.begins_with("A-")) and n >= 101 and n <= 150


## 수리 계열 이름(없으면 기본 ID 자체 = 같은 무기끼리만)
static func family(id: String) -> String:
	var b := base(id)
	if b.begins_with("A-"):
		return str(db().get(b, {}).get("layer", b))
	if UNIQUE_FAMILY.has(b):
		return UNIQUE_FAMILY[b]
	for f in FAMILY:
		if b in FAMILY[f]:
			return f
	return b


## 정비사가 손보는 계열인가(SD-15 §5.2 정비사 목록). kinds: 수제(출처 D) · 공구(공구 화기·공구 태그·한결) · TS(태성) · SJ(세진) ·
## 에너지(에너지 무기 스킬) · 소형 화기 · 의복(방어구) · 전 계열(파워 아머 제외)
static func fixable_by(id: String, kinds: Array) -> bool:
	var e: Dictionary = db().get(base(id), {})
	if not is_gear(e):
		return false
	var weapon := str(e.get("cat", "")) == "weapon"
	var o := str(e.get("origin", ""))
	for k in kinds:
		match str(k):
			"전 계열":
				if not str(e.get("slot", "")).contains("PA"):
					return true
			"의복":
				if not weapon and not str(e.get("slot", "")).contains("PA"):
					return true
			"수제":
				if weapon and o.begins_with("D"):
					return true
			"공구":
				if weapon and (family(id) == "공구 화기" or base(id) in TOOL_TAG or o.contains("한결")):
					return true
			"TS":
				if weapon and (o.contains("태성") or o.contains("TS-")):
					return true
			"SJ":
				if weapon and (o.contains("세진") or o.contains("SJ-")):
					return true
			"에너지":
				if weapon and str(e.get("skill", "")) == "에너지 무기":
					return true
			"소형 화기":
				if weapon and str(e.get("skill", "")) == "소형 화기":
					return true
	return false


## 방어구 단계당 피격 수(SD-13 §8.2): S 120 · A 60(파워 아머 120) · B 60 · C 40 · D 40 · E 25
static func armor_stage(entry: Dictionary) -> int:
	match grade(entry):
		"S":
			return 120
		"A":
			return 120 if str(entry.get("slot", "")).contains("PA") else 60
		"B":
			return 60
		"C", "D":
			return 40
		"E":
			return 25
	return 0


## 수리 스킬 상한(SD-13 §8.3): 0~17 낡음 · 18~59 양호 · 60 이상 새것
static func repair_cap(skill: int) -> int:
	if skill >= 60:
		return 0
	if skill >= 18:
		return 1
	return 2


## 정비비(SD-15 §5.2): 올림(V × (목표 배율 − 현재 배율) × 0.75 × B × F구매 × 요율), 하한 올림(V × Δ × 0.70), 최소 5캡.
## V = 새것 가치, B = 물물교환 구매 배율(1.55 − 0.45 × 스킬/100, §3.1과 같다)
static func fix_cost(value: int, from_c: int, to_c: int, barter: int, f_buy: float, rate: float) -> int:
	var d: float = VALUE[to_c] - VALUE[from_c]
	if d <= 0.0 or value <= 0:
		return 0
	var b := 1.55 - 0.45 * clampf(float(barter), 0.0, 100.0) / 100.0
	var c := ceili(value * d * 0.75 * b * f_buy * rate - 0.0001)
	return maxi(5, maxi(c, ceili(value * d * 0.70 - 0.0001)))


## 아이템 표에 @1~@4 변형을 더한다(이름 · 가치 · DR · 상태 표지). 이미 있으면 건너뛴다
static func expand_items(db: Dictionary) -> void:
	for id in db.keys():
		var e: Dictionary = db[id]
		if str(id).contains("@") or not is_gear(e):
			continue
		for c in range(1, 5):
			var v: Dictionary = e.duplicate()
			v["base"] = str(id)
			v["cond"] = c
			v["name"] = "%s (%s)" % [str(e.get("name", id)), NAMES[c]]
			var val := int(e.get("value", e.get("price", 0)))
			v["value"] = SCRAP_VALUE if c == 4 else maxi(1, roundi(val * VALUE[c])) if val > 0 else 0
			if e.has("dr"):
				v["dr"] = int(floor(float(e["dr"]) * DR[c]))
			db["%s@%d" % [id, c]] = v


## 무기 표에 @1~@4 변형(같은 수치 + condition)을 더한다 — CombatRules가 condition으로 피해·퍼짐·치명을 깎는다
static func expand_weapons(w: Dictionary) -> void:
	for id in w.keys():
		var e: Dictionary = w[id]
		if str(id).contains("@") or str(e.get("durability", "B")) == "∞":
			continue
		for c in range(1, 5):
			var v: Dictionary = e.duplicate()
			v["base"] = str(id)
			v["condition"] = COND_KEY[c]
			v["cond"] = c
			w["%s@%d" % [id, c]] = v


## 무기 단계당 사용 횟수(∞면 0 = 닳지 않음)
static func weapon_stage(entry: Dictionary) -> int:
	return int(WEAPON_STAGE.get(grade(entry), 150)) if grade(entry) != "∞" else 0


## 단계당 횟수(무기 = 공격, 방어구 = 5 이상 피격). 0 = 닳지 않음
static func stage_of(id: String) -> int:
	var e: Dictionary = db().get(base(id), {})
	if not is_gear(e):
		return 0
	return weapon_stage(e) if str(e.get("cat", "")) == "weapon" else armor_stage(e)


## 사용 카운터(SD-13 §8.2)를 n 올리고, 가득 차면 다음 상태로 바꿔 낀다. 반환: 지금 열쇠(바뀌었으면 새 열쇠).
## 카운터는 열쇠마다 하나(같은 열쇠 여러 개는 들고 쓰는 한 점만 닳는다 — 단계가 바뀌면 남은 묶음 카운터는 0).
static func use(st: StoryState, key: String, n: int = 1) -> String:
	var per := stage_of(key)
	if per <= 0 or n <= 0 or cond(key) >= 4 or int(st.items.get(key, 0)) <= 0:
		return key
	var w := int(st.wear.get(key, 0)) + n
	if w < per:
		st.wear[key] = w
		return key
	st.wear.erase(key)
	var nk := degrade(st, key)
	if w - per > 0 and nk != key:
		st.wear[nk] = mini(w - per, per - 1) if cond(nk) < 4 else 0
	return nk


## 열쇠 하나를 다음 상태로(소지품 안에서 바꿔 끼운다). 반환: 새 열쇠
static func degrade(st: StoryState, key: String) -> String:
	var c := cond(key)
	if c >= 4 or int(st.items.get(key, 0)) <= 0:
		return key
	var nk := key_of(base(key), c + 1)
	_move(st, key, nk)
	return nk


## 수리: key를 +steps 단계(상한 cap = 가장 좋은 상태 번호, 0 = 새것). 반환: 새 열쇠(못 고치면 그대로)
static func improve(st: StoryState, key: String, steps: int, cap: int) -> String:
	var c := cond(key)
	var to := maxi(cap, c - steps)
	if to >= c or int(st.items.get(key, 0)) <= 0:
		return key
	var nk := key_of(base(key), to)
	_move(st, key, nk)
	if int(st.items.get(key, 0)) <= 0:
		st.wear.erase(key)
	return nk


static func _move(st: StoryState, from: String, to: String) -> void:
	st.items[from] = int(st.items[from]) - 1
	if int(st.items[from]) <= 0:
		st.items.erase(from)
	st.items[to] = int(st.items.get(to, 0)) + 1


## 부품 후보(SD-13 §8.3): 같은 기본 ID 또는 같은 수리 계열의 고유가 아닌 장비. 부품의 상태는 결과에 영향이 없으니 가장 나쁜 것부터.
## 고칠 개체 자신(그 열쇠가 1개뿐이면)과 지금 들거나 입은 것(keep)은 빼고, 'NPC 수리만' 장비는 부품을 받지 않는다
static func part_for(st: StoryState, key: String, keep: Array = []) -> String:
	if npc_only(db().get(base(key), {})):
		return ""
	var fam := family(key)
	var best := ""
	for k in st.items.keys():
		var ks := str(k)
		if int(st.items[k]) <= 0 or not is_gear_id(ks):
			continue
		if base(ks) != base(key) and (is_unique(ks) or family(ks) != fam):
			continue
		var spare := int(st.items[k]) - (1 if ks == key else 0) - keep.count(ks)
		if spare <= 0:
			continue
		if best == "" or cond(ks) > cond(best):
			best = ks
	return best


## 스스로 고치기(핍-보이): 부품(아무 개체나) → 수리 키트(장착 중인 것만, 최대 '양호' · 스킬 상한) → 군용 정비 키트(장착 중, +2 · 새것까지).
## SD-13 §8.3 · §6.6. 반환 {"ok", "key", "why", "used"}
static func self_repair(st: StoryState, key: String, keep: Array = [], equipped: bool = false) -> Dictionary:
	var c := cond(key)
	if not is_gear_id(key) or int(st.items.get(key, 0)) <= 0:
		return {"ok": false, "key": key, "why": "고칠 수 있는 물건이 아니다."}
	if c == 0:
		return {"ok": false, "key": key, "why": "이미 새것이다."}
	var cap := repair_cap(st.skill("REPAIR"))
	var part := part_for(st, key, keep)
	if c > cap and part != "":
		_take(st, part)
		return {"ok": true, "key": improve(st, key, 1, cap), "used": part}
	if equipped and c > maxi(cap, 1) and int(st.items.get(KIT, 0)) > 0:
		_take(st, KIT)
		return {"ok": true, "key": improve(st, key, 1, maxi(cap, 1)), "used": KIT}
	if equipped and int(st.items.get(MIL_KIT, 0)) > 0:
		_take(st, MIL_KIT)
		return {"ok": true, "key": improve(st, key, 2, 0), "used": MIL_KIT}
	if npc_only(db().get(base(key), {})):
		return {"ok": false, "key": key, "why": "부품으로는 손댈 수 없다. 정비사에게 맡겨야 한다."}
	if c <= cap:
		return {"ok": false, "key": key, "why": "수리 실력으로는 여기까지다(수리 %d → '%s'까지). 정비사에게 맡기자." % [st.skill("REPAIR"), NAMES[cap]]}
	if not equipped and (int(st.items.get(KIT, 0)) > 0 or int(st.items.get(MIL_KIT, 0)) > 0):
		return {"ok": false, "key": key, "why": "같은 계열 부품이 없다. 키트는 들거나 입은 장비에만 쓴다."}
	return {"ok": false, "key": key, "why": "같은 계열 부품도, 수리 키트도 없다."}


static func _take(st: StoryState, id: String) -> void:
	st.items[id] = int(st.items[id]) - 1
	if int(st.items[id]) <= 0:
		st.items.erase(id)
		st.wear.erase(id)
	st.events.append({"kind": "item", "id": id, "delta": -1})


## 전리품·상점의 상태 굴림. kind: "loot"(상자·시체) · "enemy"(적이 쓰던 것) · "shop"(상인 진열 — 양호 이상, SD-15 §3.8)
static func roll(kind: String, rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	match kind:
		"shop":
			return 0 if r < 0.4 else 1
		"enemy":
			return 1 if r < 0.25 else (2 if r < 0.75 else 3)
		_:
			return 0 if r < 0.1 else (1 if r < 0.45 else (2 if r < 0.8 else 3))


## 장비 ID에 상태 굴림을 붙인 열쇠(장비가 아니거나 고유면 그대로 — 고유는 늘 새것으로 놓인다).
## 씨앗은 따로(seed_key + ID): 기존 굴림 순서를 흔들지 않는다(같은 씨앗 = 같은 상자 내용)
static func rolled_key(id: String, kind: String, seed_key: String) -> String:
	if kind == "" or id.contains("@") or is_unique(id) or not is_gear_id(id):
		return id
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key + "|" + id)
	return key_of(id, roll(kind, rng))
