## 용기 내용물(SD-12 §7.3, 단계 0-9 · 파밍 v2 단계 1-4, SD-13 §9): 처음 열 때 표(data/loot.json)로 굴려 정하고, 그 뒤로는 이야기 상태(st.boxes)에 남는다.
## 씨앗 = 용기 자리 + 연도 → 같은 시대에 다시 열면 같은 내용, 시대가 바뀌면 새로 채워진다(200년 볼트, 사물함 주인이 바뀐다).
## 소유(owner): "" 주인 없음 · "PC" 내 것 · "S7" 볼트 공용(관리동·보안과) · 인물 ID. 내 것이 아니고 주인이 있으면 꺼내는 것이 절도.
## 등급(§9.2): 권역 기본 등급에서 시작해 주인공 레벨 7·13·19·25마다 한 등급씩 올라 권역 상한에서 멈춘다. 줄의 다섯째 값(처음 나오는 등급)이
## 지금 등급보다 높으면 그 줄은 나오지 않고, '@묶음' 줄은 지금 등급 이하 묶음에서 하나를 고른다(높은 등급일수록 자주).
class_name Loot
extends RefCounted

static var tables := {}
static var pools := {}
static var drops := {}
static var regions := {}
static var level_steps: Array = [7, 13, 19, 25]


static func _load() -> void:
	if not tables.is_empty():
		return
	var p := "res://data/loot.json"
	if FileAccess.file_exists(p):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(p))
		tables = d["tables"]
		pools = d.get("pools", {})
		drops = d.get("drops", {})
		regions = d.get("regions", {})
		level_steps = d.get("level_steps", level_steps)


static func kind_name(kind: String) -> String:
	_load()
	return str(tables.get(kind, {}).get("name", kind))


## 레벨(SD-10 §4.2): 누적 XP (L−1)(50 + 75L) — InteriorHost.level()과 같은 식
static func level_of(xp: int) -> int:
	var lv := 1
	while xp >= lv * (50 + 75 * (lv + 1)):
		lv += 1
	return lv


## 지금 루팅 등급(§9.2): 권역 기본 + 레벨 단계, 상한에서 멈춤. 모르는 권역은 T1~T2
static func tier(region: String, lv: int) -> int:
	_load()
	var r: Array = regions.get(region, [1, 2])
	var t := int(r[0])
	for s in level_steps:
		if lv >= int(s):
			t += 1
	return clampi(t, int(r[0]), int(r[1]))


static func tier_of(st: StoryState, region: String) -> int:
	return tier(region, level_of(int(st.vars.get_v("PC_XP"))))


## 용기 하나의 상태 열쇠: "맵:x,y@연도"
static func key(map_id: String, b: Dictionary, year: int) -> String:
	return "%s:%d,%d@%d" % [map_id, int(b["x"]), int(b["y"]), year]


## 묶음에서 하나(지금 등급 이하, 높은 등급 묶음일수록 무겁게)
static func pick(pool: String, t: int, rng: RandomNumberGenerator) -> String:
	_load()
	var cands: Array = []
	var weights: Array = []
	for k in pools.get(pool, {}):
		var pt := int(k)
		if pt > t:
			continue
		for it in pools[pool][k]:
			cands.append(it)
			weights.append(1.0 + float(pt - 1) * 0.6)
	if cands.is_empty():
		return ""
	var sum := 0.0
	for w in weights:
		sum += w
	var x := rng.randf() * sum
	for i in cands.size():
		x -= weights[i]
		if x <= 0.0:
			return cands[i]
	return cands[-1]


## 줄 목록을 굴린다(결정적: 같은 씨앗이면 같은 결과). 볼트판 표(묶음·등급 없음)는 0-9와 같은 결과가 나온다
## cond_kind: 장비 상태 굴림 종류(1-8a, Gear.roll — "loot" 상자 · "enemy" 적 유해 · "" 새것 그대로)
static func roll_rows(rows: Array, seed_key: String, t: int = 1, cond_kind: String = "") -> Dictionary:
	_load()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key)
	var out := {}
	for r in rows:
		var hit := rng.randf() < float(r[1])
		if not hit:
			continue
		var n := rng.randi_range(int(r[2]), int(r[3]))
		if r.size() > 4 and int(r[4]) > t:
			continue
		var id := str(r[0])
		if id.begins_with("@"):
			id = pick(id.substr(1), t, rng)
			if id == "":
				continue
			if id.begins_with("W-") or id.begins_with("A-"):
				n = 1                                                    # 무기·방어구 묶음은 한 점
		id = Gear.rolled_key(id, cond_kind, "%s#%d" % [seed_key, out.size()])
		out[id] = int(out.get(id, 0)) + n
	return out


static func roll(kind: String, seed_key: String, t: int = 1, cond_kind: String = "") -> Dictionary:
	_load()
	return roll_rows(tables.get(kind, {}).get("rows", []), seed_key, t, cond_kind)


## 이 용기의 지금 내용물(없으면 굴려서 st.boxes에 넣는다). region = 맵의 권역(등급)
static func contents(st: StoryState, map_id: String, b: Dictionary, region: String = "") -> Dictionary:
	var k := key(map_id, b, st.year())
	if not st.boxes.has(k):
		var t := tier_of(st, region) if region != "" else 1
		st.boxes[k] = {"items": roll(str(b["kind"]), k, t, "loot" if st.year() >= 2277 else ""), "opened": 0, "taken": 0}
	return st.boxes[k]


## 쓰러진 적의 소지품(§9.3): 적 ID 표 + 씨앗(맵·자리·날)
static func drop(enemy_id: String, seed_key: String, t: int = 1, cond_kind: String = "enemy") -> Dictionary:
	_load()
	return roll_rows(drops.get(enemy_id, []), seed_key, t, cond_kind)


## 주인이 있는 남의 물건인가(절도 판정 대상)
static func owned(b: Dictionary) -> bool:
	var o := str(b.get("owner", ""))
	return o != "" and o != "PC"
