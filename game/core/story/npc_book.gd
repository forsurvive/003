## 인물 수첩(단계 1-2, SD-12 §3.11): 이름 있는 NPC와 처음 대화하거나 이름을 소개받으면 자동 등록(바크만 들은 인물은 없음).
## 항목: 이름 · 직함 · 소속(세력) · 주로 있는 곳(장소, 지도 연결) · 서비스 · 처음 만난 날 · 한 줄 메모(퀘스트가 정한 사실) · 생사.
## 생사는 주인공이 아는 죽음만(시체를 보거나 소식을 들었을 때). 이동 인물은 '마지막으로 본 곳'. 개인 호감도 수치는 없다.
## 같은 사람의 두 ID(C-022 · N-R01-001)는 첫 ID로 묶는다(SD-07b §1.4).
class_name NpcBook
extends RefCounted

const SERVICES := {"상": "상인", "의": "의사", "수": "수리", "정": "정보", "숙": "숙소", "통": "통행", "지": "지원 병력", "동": "동행", "교": "교습"}
const SERVICE_ORDER := "상의수정숙통지동교"
const FILTERS := ["전체", "이 권역", "서비스", "퀘스트 관련", "생존"]
const CHO := ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]

static var factions: Dictionary = {}
static var settlements: Dictionary = {}

var db: Dictionary = {}                       ## StoryState.npcs(인물 ID -> 자료)
var entries := {}                             ## 묶음 ID -> {"met": 날짜, "n": 등록 순번, "memo": "", "dead": "", "seen": L-ID}
var count := 0


func _init(npcs: Dictionary = {}) -> void:
	db = npcs
	if factions.is_empty() and FileAccess.file_exists("res://data/npcs.json"):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json"))
		factions = d.get("factions", {})
		settlements = d.get("settlements", {})


## 두 ID를 하나로(자료의 ids 첫 값). 자료에 없는 ID(SYS·이름 없는 적)는 ""
func canon(id: String) -> String:
	var e: Dictionary = db.get(id, {})
	if e.is_empty():
		return ""
	var ids: Array = e.get("ids", [id])
	return str(ids[0]) if not ids.is_empty() else id


## 등록(처음이면 true). date = 진행기 날짜 글('2277. 10. 23.  16:40' — 날짜만 남긴다)
func meet(id: String, date: String) -> bool:
	var c := canon(id)
	if c == "" or entries.has(c) or bool(info(c).get("unnamed", false)):   # 무명(적 템플릿)은 수첩에 없다
		return false
	count += 1
	var t := Clock.parse(date)
	entries[c] = {"met": ("%d. %02d. %02d." % [t[0], t[1], t[2]]) if not t.is_empty() else date, "n": count, "memo": "", "dead": "", "seen": ""}
	return true


func knows(id: String) -> bool:
	return entries.has(canon(id))


## 한 줄 메모(퀘스트 단계가 정한 사실 문장). 등록 안 된 인물이면 먼저 등록한다
func memo(id: String, text: String, date := "") -> void:
	var c := canon(id)
	if c == "":
		return
	if not entries.has(c):
		meet(c, date)
	entries[c]["memo"] = text


## 주인공이 안 죽음(등록된 인물만 — 모르는 사람의 죽음은 수첩에 없다)
func died(id: String, date: String) -> void:
	var c := canon(id)
	if entries.has(c) and str(entries[c]["dead"]) == "":
		entries[c]["dead"] = _short_date(date)


## 마지막으로 본 곳(이동 인물)
func saw(id: String, lid: String) -> void:
	var c := canon(id)
	if entries.has(c):
		entries[c]["seen"] = lid


static func _short_date(date: String) -> String:
	var t := Clock.parse(date)
	return "%02d. %02d." % [t[1], t[2]] if not t.is_empty() else date


func info(c: String) -> Dictionary:
	return db.get(c, {})


## 직함(이름표·목록 오른쪽)
func title(c: String) -> String:
	return str(info(c).get("title", ""))


## 소속 문장: 'JC·BC' → '정착지 연합 · 봉천 계단마을'
func faction_text(c: String) -> String:
	var full := str(info(c).get("faction_full", info(c).get("faction", "")))
	var parts: Array = []
	for p in full.split("·"):
		p = p.strip_edges()
		if p in ["", "—"]:
			continue
		parts.append(str(factions.get(p, settlements.get(p, p))))
	return " · ".join(parts) if not parts.is_empty() else "소속 없음"


## 주로 있는 곳(L-ID). 이동 인물은 마지막으로 본 곳이 앞선다
func place_of(c: String) -> String:
	var seen := str(entries.get(c, {}).get("seen", ""))
	if seen != "":
		return seen
	var p := str(info(c).get("place", ""))
	return ("L-" + p) if p != "" and not p.begins_with("L-") else p


func services_text(c: String) -> String:
	var out: Array = []
	for s in info(c).get("services", []):
		out.append(SERVICES.get(s, s))
	return " · ".join(out)


## 목록(SD-12 §3.11): 기본 최근 만난 순. filter = FILTERS 번호, region = 지금 권역(R01 …), q = 이름 검색(초성 가능)
func list(filter := 0, region := "", q := "", quest_ids: Array = []) -> Array:
	var out: Array = entries.keys()
	out = out.filter(func(c):
		var e: Dictionary = info(c)
		match filter:
			1:
				if not place_of(c).begins_with("L-" + region + "-"):
					return false
			2:
				if (e.get("services", []) as Array).is_empty():
					return false
			3:
				var hit := false
				for qid in e.get("quests", []):
					hit = hit or qid in quest_ids
				if not hit:
					return false
			4:
				if str(entries[c]["dead"]) != "":
					return false
		return q == "" or matches(str(e.get("name", "")), q))
	out.sort_custom(func(a, b): return int(entries[a]["n"]) > int(entries[b]["n"]))
	return out


## 이름 검색: 그대로 들어 있거나, 초성 열이 이어서 맞으면(예 'ㅂㅇㅎ' → 백인하, 'ㅈㅁ' → 조만석)
static func matches(name: String, q: String) -> bool:
	q = q.replace(" ", "")
	if q == "" or name.replace(" ", "").contains(q):
		return true
	var ini := ""
	var nm := name.replace(" ", "")
	for i in nm.length():
		var u := nm.unicode_at(i)
		if u >= 0xAC00 and u <= 0xD7A3:
			ini += CHO[(u - 0xAC00) / 588]
		else:
			ini += nm[i]
	for start in nm.length() - q.length() + 1:                        # 검색어의 초성은 초성끼리, 완성 음절은 그대로 — 한 글자씩 맞춘다
		var ok := true
		for i in q.length():
			var qc := q[i]
			if CHO.has(qc):
				ok = ini[start + i] == qc
			else:
				ok = nm[start + i] == qc
			if not ok:
				break
		if ok:
			return true
	return false


func to_dict() -> Dictionary:
	var keys := entries.keys()
	keys.sort()
	var e := {}
	for k in keys:
		e[k] = (entries[k] as Dictionary).duplicate()
	return {"entries": e, "count": count}


func from_dict(d: Dictionary) -> void:
	entries = (d.get("entries", {}) as Dictionary).duplicate(true)
	count = int(d.get("count", entries.size()))
