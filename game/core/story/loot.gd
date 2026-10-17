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
static var flavor := {}                          ## 자리 특색(SD-22 §5.4): 권역·지형 태그 → 묶음 → [[아이템, 등급]]
static var restock := {}                         ## 다시 채움(SD-22 §5.4 V2): 용기 종류 → [최소일, 최대일, 확률]
static var chunk_tags := {}                      ## 청크 지형 태그(world_chunks.chunk_tags): "cx,cy" → {"fab", "tags"}
static var place := {}                           ## 파밍 v3(1-L §2.1): 장소 결 → {용기 종류 · '계산대' → 바꿔 끼울 표}
static var events := {}                          ## 사건 물건(§2.2): 사건 → [용기 종류들, 표, 빈 상자율 배수, 모두]
static var v3 := {}                              ## 빈 상자율 · 줄 상한 · 캡 배수 · 보이는 빔(§9.1)
static var why := {}                             ## 빈 이유 글: 열쇠 → [글]
const FLAVOR_P := 0.3


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
		flavor = d.get("flavor", {})
		restock = d.get("restock", {})
		place = d.get("place", {})
		events = d.get("events", {})
		v3 = d.get("v3", {})
		why = d.get("why", {})
	var tp := "res://data/world/chunk_tags.json"
	if FileAccess.file_exists(tp):
		chunk_tags = JSON.parse_string(FileAccess.get_file_as_string(tp)).get("chunks", {})


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
## ctx(SD-22 §5.4): {"region", "tags", "luck"} — 볼트를 나온 뒤에만 주어진다(볼트판은 0-9와 같은 결과).
## 행운: '@묶음' 줄 확률 ×(0.9 + LK × 0.02). 특색: '@묶음'에서 고른 것의 30%를 그 자리 특색 묶음에서(따로 씨앗 — 기본 굴림 순서를 흔들지 않는다)
static func roll_rows(rows: Array, seed_key: String, t: int = 1, cond_kind: String = "", ctx: Dictionary = {}) -> Dictionary:
	_load()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key)
	var out := {}
	var luck := float(ctx.get("luck", 5)) if not ctx.is_empty() else 5.0
	for r in rows:
		var pr := float(r[1])
		if str(r[0]).begins_with("@") and not ctx.is_empty():
			pr = minf(1.0, pr * (0.9 + luck * 0.02))
		var hit := rng.randf() < pr
		if not hit:
			continue
		var n := rng.randi_range(int(r[2]), int(r[3]))
		if r.size() > 4 and int(r[4]) > t:
			continue
		var id := str(r[0])
		if id.begins_with("@"):
			var pool := id.substr(1)
			id = pick(pool, t, rng)
			if id == "":
				continue
			if not ctx.is_empty():
				var frng := RandomNumberGenerator.new()
				frng.seed = hash("%s|f%d" % [seed_key, out.size()])
				if frng.randf() < FLAVOR_P:
					var f := flavor_pick(pool, t, ctx, frng)
					if f != "":
						id = f
			if id.begins_with("W-") or id.begins_with("A-"):
				n = 1                                                    # 무기·방어구 묶음은 한 점
		id = Gear.rolled_key(id, cond_kind, "%s#%d" % [seed_key, out.size()])
		out[id] = int(out.get(id, 0)) + n
	return out


static func roll(kind: String, seed_key: String, t: int = 1, cond_kind: String = "", ctx: Dictionary = {}) -> Dictionary:
	_load()
	return roll_rows(tables.get(kind, {}).get("rows", []), seed_key, t, cond_kind, ctx)


## 특색 묶음에서 하나: 권역 50% · 지형 태그 50%(없으면 다른 쪽). 지금 등급 이하만
static func flavor_pick(pool: String, t: int, ctx: Dictionary, rng: RandomNumberGenerator) -> String:
	var srcs: Array = []
	var reg := str(ctx.get("region", ""))
	var tag_srcs: Array = (ctx.get("tags", []) as Array).filter(func(x): return flavor.has(x) and (flavor[x] as Dictionary).has(pool))
	var reg_ok: bool = flavor.has(reg) and (flavor[reg] as Dictionary).has(pool)
	if reg_ok and (tag_srcs.is_empty() or rng.randf() < 0.5):
		srcs = flavor[reg][pool]
	elif not tag_srcs.is_empty():
		srcs = flavor[tag_srcs[rng.randi() % tag_srcs.size()]][pool]
	var ok: Array = srcs.filter(func(e): return int(e[1]) <= t)
	return str(ok[rng.randi() % ok.size()][0]) if not ok.is_empty() else ""


## 그 자리의 지형 태그(월드 맵만, 청크 단위)
static func tags_at(x: int, y: int) -> Array:
	_load()
	return chunk_tags.get("%d,%d" % [x / 40, y / 40], {}).get("tags", [])


## 굴림 맥락(SD-22 §5.4): 볼트 시대(2277 이전)는 빈 맥락 — 0-9 결과 그대로
static func ctx_for(st: StoryState, map_id: String, b: Dictionary, region: String) -> Dictionary:
	if st.year() < 2277:
		return {}
	return {"region": region, "tags": tags_at(int(b["x"]), int(b["y"])) if map_id == "W" else [], "luck": st.stat("LK")}


## 굴림 씨앗(SD-22 §5.4 V1): 볼트 밖은 그 판의 씨앗 + 다시 채운 횟수를 섞는다(판마다 다르고, 같은 판 안에서는 불러와도 같다)
static func seed_of(st: StoryState, k: String, gen: int) -> String:
	return k if st.year() < 2277 else "%s#%d#%d" % [k, st.check_seed, gen]


## 이 용기의 지금 내용물(없으면 굴려서 st.boxes에 넣는다). region = 맵의 권역(등급)
static func contents(st: StoryState, map_id: String, b: Dictionary, region: String = "") -> Dictionary:
	var k := key(map_id, b, st.year())
	var t := tier_of(st, region) if region != "" else 1
	var cond := "loot" if st.year() >= 2277 else ""
	if not st.boxes.has(k):
		if is_v3(st, map_id, b):
			var r := roll_v3(map_id, b, seed_of(st, k, 0), t, cond, ctx_for(st, map_id, b, region))
			st.boxes[k] = {"items": r["items"], "opened": 0, "taken": 0, "why": r["why"], "vis": r["vis"]}
		else:
			st.boxes[k] = {"items": roll(str(b["kind"]), seed_of(st, k, 0), t, cond, ctx_for(st, map_id, b, region)), "opened": 0, "taken": 0}
		if map_id.begins_with("G-") and str(b.get("name", "")) == "작업대" and st.year() >= 2277:
			st.boxes[k]["items"]["W-151"] = 1                              # 시설 작업대 서랍의 완성 병뚜껑 지뢰 1개(SD-13 §7.9.1 원작 관습, 처음 한 번)
	else:
		_restock(st, k, map_id, b, t, cond, region)
	return st.boxes[k]


## 다시 채움(SD-22 §5.4 V2·V3·V8): 비어 있는 길가·야외·생성 실내 용기는 정해진 날 수가 지나면 그때 등급으로 새로 굴린다.
## 볼트 시대·손 배치 맵·주인 있는 용기·금고 등 표에 없는 종류는 다시 차지 않는다
static func _restock(st: StoryState, k: String, map_id: String, b: Dictionary, t: int, cond: String, region: String) -> void:
	_load()
	var bx: Dictionary = st.boxes[k]
	if not (bx["items"] as Dictionary).is_empty():
		bx.erase("re_at")
		return
	var rs = restock.get(str(b.get("kind", "")))
	if rs == null or st.year() < 2277 or owned(b) or not (map_id == "W" or map_id.begins_with("G-")):
		return
	var day := int(st.vars.get_v("GAME_DAY")) if st.vars.has("GAME_DAY") else 0
	var gen := int(bx.get("gen", 0))
	if not bx.has("re_at"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|re%d" % [k, gen])
		bx["re_at"] = day + rng.randi_range(int(rs[0]), int(rs[1]))
		bx["re_ok"] = rng.randf() < float(rs[2])
		return
	if day < int(bx["re_at"]):
		return
	bx.erase("re_at")
	bx["gen"] = gen + 1
	if bool(bx.get("re_ok", true)):
		if is_v3(st, map_id, b):                                         # 1-L: 다시 채움도 장소 결 · 빈 상자율 · 줄 상한 그대로(보이는 빔은 처음 한 번만)
			var r := roll_v3(map_id, b, seed_of(st, k, gen + 1), t, cond, ctx_for(st, map_id, b, region))
			bx["items"] = r["items"]
			bx["why"] = r["why"]
			bx["vis"] = false
		else:
			bx["items"] = roll(str(b["kind"]), seed_of(st, k, gen + 1), t, cond, ctx_for(st, map_id, b, region))


## 쓰러진 적의 소지품(§9.3): 적 ID 표 + 씨앗(맵·자리·날)
static func drop(enemy_id: String, seed_key: String, t: int = 1, cond_kind: String = "enemy") -> Dictionary:
	_load()
	return roll_rows(drops.get(enemy_id, []), seed_key, t, cond_kind)


# ---------------------------------------------------------------- 파밍 v3(1-L 계획 §2 · §9.1)
## 대상: 볼트를 나온 뒤 생성 실내(G-) · 월드 길가(W)의 일반 용기. 손 맵 · 퀘스트 용기 · 볼트 시대는 옛 굴림 그대로
static func is_v3(st: StoryState, map_id: String, b: Dictionary) -> bool:
	_load()
	return st.year() >= 2277 and (map_id == "W" or map_id.begins_with("G-")) and str(b.get("kind", "")) in (v3.get("kinds", []) as Array) \
		and str(b.get("owner", "")) == ""


static func place_of(map_id: String, b: Dictionary) -> String:
	return str(b.get("pl", "road" if map_id == "W" else "home"))


## 빈 상자율(§2.1): 결 기본 × 위협 × 잠김 × 함정/방사능 × 최근 사람 × 사건 × 용기 배수
static func empty_p(map_id: String, b: Dictionary) -> float:
	_load()
	var pl := place_of(map_id, b)
	var p := float((v3.get("empty", {}) as Dictionary).get(pl, 0.5))
	p *= float((v3.get("threat", {}) as Dictionary).get(str(int(b.get("th", 2))), 1.0))
	if int(b.get("lock", 0)) > 0:
		p *= float(v3.get("lock", 0.6))
	if int(b.get("hd", 0)) == 1:
		p *= float(v3.get("hard", 0.7))
	if "l3" in (b.get("ly", []) as Array):
		p *= float(v3.get("l3", 1.1))
	var ev := str(b.get("ev", ""))
	if ev != "" and events.has(ev):
		p *= float(events[ev][2])
	p *= float((v3.get("kind_mul", {}) as Dictionary).get(str(b.get("kind", "")), 1.0))
	return clampf(p, 0.0, 0.97)


## 바꿔 끼울 표: 사건 표 → 결 표(이름이 '계산대'로 시작하면 '계산대' 열쇠 먼저) → 모든 결 기본 → 그대로
static func table_of(map_id: String, b: Dictionary) -> String:
	_load()
	var kind := str(b.get("kind", ""))
	var ev := str(b.get("ev", ""))
	if ev != "" and events.has(ev) and str(events[ev][1]) != "" and kind in (events[ev][0] as Array):
		return str(events[ev][1])
	var till := str(b.get("name", "")).begins_with("계산대")
	for pk in [place_of(map_id, b), "*"]:
		var m: Dictionary = place.get(pk, {})
		if till and m.has("계산대"):
			return str(m["계산대"])
		if m.has(kind):
			return str(m[kind])
	return kind


## 굴림: {"items", "why"(빈 이유 글 — 비었을 때만), "vis"(보이는 빔 — 들어선 순간 바닥에 보인다)}. 같은 씨앗이면 같은 결과
static func roll_v3(map_id: String, b: Dictionary, seed_key: String, t: int, cond_kind: String, ctx: Dictionary) -> Dictionary:
	_load()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key + "|v3")
	var u := rng.randf()
	var pe := empty_p(map_id, b)
	var vs: Dictionary = v3.get("vis", {})
	var pv := pe * float(vs.get(place_of(map_id, b), vs.get("*", 0.0)))
	if u < pe:
		return {"items": {}, "why": why_text(map_id, b, rng), "vis": u < pv}
	var rows: Array = []
	var ly: Array = b.get("ly", [])
	for r in (tables.get(table_of(map_id, b), {}).get("rows", []) as Array):
		if "l2" in ly and str(r[0]) in (v3.get("l2_drop", []) as Array):
			continue                                                     # 시간 층 ②: 200년 동안 누가 여기서 먹고 아팠다
		var rr: Array = (r as Array).duplicate()
		if str(rr[0]) == "M-001":
			rr[1] = float(rr[1]) * float(v3.get("caps", 0.35))           # 상자에서 캡은 드물다 — 캡은 거래로 번다(원칙 4)
		rows.append(rr)
	var items := roll_rows(rows, seed_key, t, cond_kind, ctx)
	var nmax := int((v3.get("lines_big", {}) as Dictionary).get(str(b.get("kind", "")), v3.get("lines", 2)))
	if items.size() > nmax:
		var ks := items.keys()
		ks.sort()
		for i in range(ks.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = ks[i]
			ks[i] = ks[j]
			ks[j] = tmp
		var kept := {}
		for kk in ks.slice(0, nmax):
			kept[kk] = items[kk]
		items = kept
	return {"items": items, "why": why_text(map_id, b, rng) if items.is_empty() else "", "vis": false}


## 빈 이유 글(§1 원칙 2): 사건 → 시간 층 → 결:용기 → 결:* → *:용기 → *:*. 12%는 다른 곳을 가리킨다(생성기가 고른 가까운 소굴 · 사람 사는 집)
static func why_text(map_id: String, b: Dictionary, rng: RandomNumberGenerator) -> String:
	_load()
	var ld: Array = b.get("ld", [])
	if ld.size() >= 2 and rng.randf() < float(v3.get("lead", 0.12)) and why.has("lead"):
		var ll: Array = why["lead"]
		return str(ll[rng.randi() % ll.size()]).replace("{dir}", str(ld[0])).replace("{far}", str(ld[1]))
	var pl := place_of(map_id, b)
	var kind := "계산대" if str(b.get("name", "")).begins_with("계산대") else str(b.get("kind", ""))
	var keys: Array = []
	var ev := str(b.get("ev", ""))
	if ev != "":
		keys.append("ev:" + ev)
	for lay in (b.get("ly", []) as Array):
		keys.append_array(["%s+%s:%s" % [pl, lay, kind], "%s+%s:*" % [pl, lay]])
	keys.append_array(["%s:%s" % [pl, kind], pl + ":*", "*:" + kind, "*:*"])
	for kk in keys:
		if why.has(kk) and not (why[kk] as Array).is_empty():
			var l: Array = why[kk]
			return str(l[rng.randi() % l.size()])
	return ""


## 보이는 빔(§9.1): 아직 열지 않았어도 들어선 순간 바닥에 털린 자리가 보이나 — 굴림과 같은 씨앗(열어 보면 그대로 비었다)
static func visibly_empty(st: StoryState, map_id: String, b: Dictionary) -> bool:
	if not is_v3(st, map_id, b):
		return false
	var k := key(map_id, b, st.year())
	if st.boxes.has(k):
		var bx: Dictionary = st.boxes[k]
		return bool(bx.get("vis", false)) and (bx["items"] as Dictionary).is_empty() and int(bx.get("taken", 0)) == 0 \
			and int(bx.get("gen", 0)) == 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_of(st, k, 0) + "|v3")
	var u := rng.randf()
	var vs: Dictionary = v3.get("vis", {})
	return u < empty_p(map_id, b) * float(vs.get(place_of(map_id, b), vs.get("*", 0.0)))


## 빈 상자를 열었을 때 보일 글: 처음 굴려 빈 채였고 주인공이 아직 아무것도 꺼내지 않았을 때만(내가 비운 상자에 '누가 털었다'는 없다)
static func empty_line(bx: Dictionary) -> String:
	if not (bx.get("items", {}) as Dictionary).is_empty() or int(bx.get("taken", 0)) > 0:
		return ""
	return str(bx.get("why", ""))


## 주인이 있는 남의 물건인가(절도 판정 대상)
static func owned(b: Dictionary) -> bool:
	var o := str(b.get("owner", ""))
	return o != "" and o != "PC"
