## 핍-보이 수첩 '숨겨 둔 자리'(단계 1-12o, D-225 · 1-L 계획 §3.1 · 계획 `_plans/1-12o_stash_book_plan.md`).
##   목록 · 상세 · 지도 표시가 같이 읽는다. 사실은 진행기 Stash가 쓰는 st.boxes["stash"] 한 곳(P1):
##   spots[k] = 내 은닉처(털릴 수 있음) — seen{day, items} 마지막으로 닫은 때의 기억 · known{day, text, b} 흔적을 본 때 · room 삼은 실내 이름.
##   safe[k] = 맡긴 자리(털리지 않음 — 옥탑방 · 원룸 사물함 · 공구 사물함, 열어 닫아 본 적 있는 것만).
##   **기억만 보인다(SD-20 P2)**: '그때 든 것'은 지금 내용이 아니다 — 털림은 그 용기를 열어 흔적을 본 뒤에야 뜬다(§3.2 알게 되는 때).
class_name StashBook
extends RefCounted

const MAX := 8
## 맡긴 자리(손 맵): 맵 → 월드 칸(끼움 맵 원점 + 문 표식) · 안내 이름
const SAFE := {"B-01": {"at": [889, 1348], "where": "봉천 계단마을 옥탑 이장실"},
	"K-40": {"at": [800, 1416], "where": "고시촌 분양 원룸 A-203"},
	"X-MR": {"at": [685, 1161], "where": "문래 철공소 골목 협동조합"}}
const DIRS := ["동쪽", "남동쪽", "남쪽", "남서쪽", "서쪽", "북서쪽", "북쪽", "북동쪽"]


static func data(st) -> Dictionary:
	return st.boxes.get("stash", {})


## 목록 행: [{"id", "text"(이름), "where"(짧게), "right"(상태 한 마디), "dim", "safe"}] — 은닉처 먼저(삼은 차례), 그다음 맡긴 자리
static func rows(st, now := "", me := Vector2i(-1, -1), db := {}) -> Array:
	var d := data(st)
	var out: Array = []
	var sp: Dictionary = d.get("spots", {})
	var keys := sp.keys()
	if me.x >= 0:                                                        # 가까운 순(지금 자리에서 — 재미 검수 F11)
		keys.sort_custom(func(a, b): return Vector2(me).distance_to(Vector2(int(sp[a]["wx"]), int(sp[a]["wy"]))) < Vector2(me).distance_to(Vector2(int(sp[b]["wx"]), int(sp[b]["wy"]))))
	else:
		keys.sort_custom(func(a, b): return int(sp[a].get("since", 0)) < int(sp[b].get("since", 0)))
	for k in keys:
		var s: Dictionary = sp[k]
		out.append({"id": "stash:" + str(k), "text": memo(s, db), "where": short_where(st, s), "right": status(st, s, now), "dim": false, "safe": false})
	var sf: Dictionary = d.get("safe", {})
	for k in sf:
		var s: Dictionary = sf[k]
		out.append({"id": "safe:" + str(k), "text": str(s.get("name", "사물함")), "where": str(SAFE.get(str(s["map"]), {}).get("where", "")),
			"right": safe_status(st, s, now), "dim": false, "safe": true})
	return out


static func count(st) -> int:
	return (data(st).get("spots", {}) as Dictionary).size()


## 상태 한 마디: 털림(흔적을 봄) · 되찾음 · 방울 · 마지막으로 본 날
static func status(st, s: Dictionary, now := "") -> String:
	var kn: Dictionary = s.get("known", {})
	if not kn.is_empty():
		return "되찾음" if _bundle_state(st, int(kn.get("b", 0))) == "back" else "털림"
	var seen: Dictionary = s.get("seen", {})
	return "방울" if bool(seen.get("bell", false)) else md(st, int(seen.get("day", s.get("since", 0))), int(seen.get("at", 0)), now)   # 방울도 닫은 순간의 기억 · 날짜는 상세에   # 방울도 닫은 순간의 기억(방울이 막은 날 열기 전에 새지 않게)


static func safe_status(st, s: Dictionary, now := "") -> String:
	if str(s["map"]) == "X-MR":
		match int(st.vars.get_v("MR_LOCKER")):
			1:
				return "~" + md(st, int(st.vars.get_v("MR_LOCKER_DAY")), 0, now)
			2:
				return "기한 지남"
	return "안전"


static func _bundle_state(st, bid: int) -> String:
	for bn in (data(st).get("bundles", []) as Array):
		if int(bn["id"]) == bid:
			return str(bn["state"])
	return ""


## 날 → 'MM.DD'. at = 기록한 절대 분(Clock.abs_min) — 없으면 게임 날 차이로 오늘 날짜에서 거꾸로 센다
static func md(st, day: int, at := 0, now_text := "") -> String:
	if at <= 0 and now_text != "":
		at = Clock.abs_min(now_text) - (int(st.vars.get_v("GAME_DAY")) - day) * 1440
	var t := Clock.md(at)
	return t.replace(". ", ".").trim_suffix(".") if t != "" else "%d일째" % day


## 행 = 내 메모(재미 검수 ①): '삼은 실내 이름 + 용기 — 그때 둔 가장 값진 것'
static func memo(s: Dictionary, db: Dictionary, full := false) -> String:
	var room := str(s.get("room", ""))
	var head := ((room + " ") if full and room != "" else "") + str(s.get("name", "용기"))   # 목록은 '용기 — 값진 것'(구현 뒤 재미 검수 ①), 실내 이름은 상세 머리에
	var lines := memory_lines((s.get("seen", {}) as Dictionary).get("items", {}), db, 1)
	return head + (" — " + str(lines[0]).split(" ×")[0] if not lines.is_empty() else " — 비어 있었다")


## 마음에 걸림(재미 검수 ②): 플레이어가 아는 값만 — 닫을 때 얼린 위험(p · 위험 문장) × 마지막으로 본 뒤 날수. 털림 여부는 읽지 않는다(P2)
static func worry(st, s: Dictionary) -> String:
	var seen: Dictionary = s.get("seen", {})
	if (seen.get("items", {}) as Dictionary).is_empty():
		return "비워 둔 자리라 걸릴 것도 없다."
	var n := int(st.vars.get_v("GAME_DAY")) - int(seen.get("day", s.get("since", 0)))
	var when := "오늘 봤다." if n <= 0 else ("어제 봤다." if n == 1 else ("이틀째 못 봤다." if n == 2 else ("사흘째 못 봤다." if n == 3 else "%d일째 못 봤다." % n)))
	var p := float(seen.get("p", 0.018))
	var why := ""
	if bool(seen.get("bell", false)):
		why = "방울을 매 뒀으니 손대면 소리는 나겠지."
	elif int(s.get("lock", 0)) >= 50:
		why = "단단히 잠기는 자리라 걱정은 덜 된다."
	elif int(s.get("th", 2)) <= 1:
		why = "사람 드나드는 동네라 자꾸 생각난다."
	elif int(s.get("th", 2)) >= 3:
		why = "짐승만 다니는 데라 마음이 놓인다."
	else:
		why = "가끔 생각난다."
	if n >= 7 and p * n > 0.08:
		why = "너무 오래 비워 뒀다. " + why
	return when + " " + why


## 어디(짧게): 가까운 아는 장소 이름 — 없으면 구역 칸
static func short_where(st, s: Dictionary) -> String:
	var near := _near(st, Vector2i(int(s.get("wx", 0)), int(s.get("wy", 0))))
	return str(near[0]) if str(near[0]) != "" else PipMap.grid_name(Vector2(int(s.get("wx", 0)), int(s.get("wy", 0)))) + " 구역"


## 어디(길게): '봉천 고개에서 북동쪽, 골목 몇 개 건너' — 아는 장소(발견 이상)만 기준으로 쓴다
static func long_where(st, s: Dictionary) -> String:
	var w := Vector2i(int(s.get("wx", 0)), int(s.get("wy", 0)))
	var near := _near(st, w)
	var cell := PipMap.grid_name(Vector2(w)) + " 구역"
	if str(near[0]) == "":
		return cell + " — 둘레에 아는 곳이 없다"
	var dd := float(near[1])
	if dd < 8.0:
		return "%s 바로 옆 · %s" % [near[0], cell]
	var to: Vector2i = near[2]
	var ang := rad_to_deg(atan2(float(w.y - to.y), float(w.x - to.x)))
	var dn: String = DIRS[int(fposmod(ang + 22.5, 360.0) / 45.0) % 8]
	var far := "골목 몇 개 건너" if dd < 40 else ("큰길 하나 건너" if dd < 80 else "한참 가서")
	return "%s에서 %s, %s · %s" % [near[0], dn, far, cell]


static func _near(st, w: Vector2i) -> Array:
	var best := ["", 1e9, Vector2i.ZERO]
	if PlaceLog.db.is_empty():
		PlaceLog.load_db()
	for lid in PlaceLog.db:
		var e: Dictionary = PlaceLog.db[lid]
		if str(e.get("region", "")) == "UG" or st.places.get_state(lid) < PlaceLog.FOUND:
			continue
		var p := Vector2i(int(e["tx"]), int(e["ty"]))
		var dd := Vector2(p).distance_to(Vector2(w))
		if dd < float(best[1]) and dd <= 160.0:
			best = [str(e["name"]), dd, p]
	return best


## 그때 든 것(기억): 값 높은 순 '이름 ×n' 줄 · 캡은 맨 끝
static func memory_lines(items: Dictionary, db: Dictionary, n := 7) -> Array:
	var ids := items.keys().filter(func(x): return str(x) != "M-001")
	ids.sort_custom(func(a, b): return int(db.get(Gear.base(str(a)), {}).get("value", 0)) * int(items[a]) > int(db.get(Gear.base(str(b)), {}).get("value", 0)) * int(items[b]))
	var out: Array = []
	for id in ids.slice(0, n):
		var nm := str(db.get(Gear.base(str(id)), {}).get("name", id))
		out.append(nm + (" ×%d" % int(items[id]) if int(items[id]) > 1 else ""))
	if ids.size() > n:
		out.append("그 밖 %d가지" % (ids.size() - n))
	if int(items.get("M-001", 0)) > 0:
		out.append("캡 %d" % int(items["M-001"]))
	return out


## 지금 자리의 월드 칸(가까운 순): 바깥이면 그 칸 · 생성 실내 G-x-y면 그 집 · 맡긴 자리 맵이면 그 자리 · 아니면 (-1, -1)
static func here(tile: Vector2, map_id: String) -> Vector2i:
	if tile.x >= 0:
		return Vector2i(tile)
	if map_id.begins_with("G-"):
		var p := map_id.split("-")
		return Vector2i(int(p[1]), int(p[2]))
	if SAFE.has(map_id):
		var a: Array = SAFE[map_id]["at"]
		return Vector2i(int(a[0]), int(a[1]))
	return Vector2i(-1, -1)


## 지도 점: [{"at": Vector2i, "name", "robbed", "safe"}]
static func points(st) -> Array:
	var out: Array = []
	var d := data(st)
	for k in d.get("spots", {}):
		var s: Dictionary = d["spots"][k]
		out.append({"at": Vector2i(int(s.get("wx", 0)), int(s.get("wy", 0))), "name": memo(s, {}, false).split(" — ")[0], "robbed": status(st, s) == "털림", "safe": false})
	for k in d.get("safe", {}):
		var s: Dictionary = d["safe"][k]
		var a: Array = SAFE.get(str(s["map"]), {}).get("at", [0, 0])
		out.append({"at": Vector2i(int(a[0]), int(a[1])), "name": str(s.get("name", "")), "robbed": false, "safe": true})
	return out


## id('stash:키' · 'safe:키') → 월드 칸(지도에서 보기)
static func at_of(st, id: String) -> Vector2i:
	var d := data(st)
	if id.begins_with("stash:"):
		var s: Dictionary = d.get("spots", {}).get(id.substr(6), {})
		return Vector2i(int(s.get("wx", -1)), int(s.get("wy", -1)))
	if id.begins_with("safe:"):
		var s2: Dictionary = d.get("safe", {}).get(id.substr(5), {})
		var a: Array = SAFE.get(str(s2.get("map", "")), {}).get("at", [-1, -1])
		return Vector2i(int(a[0]), int(a[1]))
	return Vector2i(-1, -1)
