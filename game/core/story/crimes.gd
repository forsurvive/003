## 범죄 반응(단계 1-X, SD-06 §3.4 '범죄' 행 · §3.8 영구 적대 · §6.4 시체 발견 · SD-14 §9.12 정착지 경비대).
## 사용자 지시(2026-10-16): 플레이어는 주요 NPC를 죽이는 돌발 행동을 한다 — 세계가 그럴듯하게, 그러나 '알게 된 뒤에' 반응한다.
##   목격된 살해: 이름 있는 인물 −35(원한) · 무명 세력원 −20(원한) — 목격 즉시(직접 목격 경로).
##   지도자 · 정착지 대표 살해, 같은 거점 주민 5명 이상(학살): 값 −100 고정 · 영구 적대(회복 불가).
##   목격 없는 살해: 시체는 1~24시간 안에 발견된다(그 정착지가 죽음을 안다). 범인 지목은 30% — 되면 '비목격 살해 발각'(무명 −12, 이름 있는 인물 −35).
## 정착지 안에서 목격된 살인 · 정착지 적대(≤ −60)는 호스트가 자경단을 깨운다(SettlementAlarm). 아이는 공격 대상이 아니라 죽일 수 없다(SD-11 §580).
class_name Crimes
extends RefCounted

## 지도자 · 대표(SD-06 10장 각 세력 '영구 적대' 항목 · 정착지 개별 대표) — 인물 ID → 호감 대상
const LEADERS := {"C-010": "JC_BC", "N-R01-041": "JC_SA", "C-011": "JC_ND", "C-012": "JC_TK", "C-013": "SB", "C-006": "JH", "C-050": "JH",
	"C-014": "GS", "C-005": "YH", "C-007": "JG", "C-003": "BJ"}
const MASSACRE := 5
## 총을 드는 자경단원(SD-14 §9.12 CR-466 · 정착지 맵 인물): 정착지 → 인물 ID
const GUARDS := {"JC_BC": ["N-R01-028", "N-R01-033", "N-R01-035", "N-R01-036"], "JC_SA": ["N-R01-043"]}
const ALARM := {"살인": "살인이다! 자경단, 총 들어!", "동물": "%s 쐈어! 저놈 잡아!", "적대": "저놈이다! 쏴!", "": "저놈이다!"}
const FIND_MIN := 60                                   ## 시체 발견 1~24시간(SD-06 §6.4)
const FIND_MAX := 1440
const SOLVE := 0.3                                     ## 범인 지목 30%


## 이 사람이 죽으면 반응하는 대상(정착지 개별값이 있으면 그쪽, 무소속 · 적 · 미상이면 "")
static func target(st: StoryState, id: String) -> String:
	var n: Dictionary = st.npcs.get(id, {})
	var ff := str(n.get("faction_full", ""))
	if ff.begins_with("JC·"):
		var code := "JC_" + ff.substr(3)
		return code if st.vars.has("AFF_" + code) else "JC"
	var f := str(n.get("faction", ""))
	if f in ["", "—", "MS", "YT", "BY", "S7"] or not st.vars.has("AFF_" + f):
		return ""
	return f


## 동물(외형 AN* — 백구 같은 마을 개): 죽이면 '살해'가 아니라 '쏨'으로 말한다(값은 정본 SD-06 §3.4 그대로 — 1-X 재미 검수 메모)
static func animal(st: StoryState, id: String) -> bool:
	return str(st.npcs.get(id, {}).get("look", "")).begins_with("AN")


## 이름 + 목적격 조사(을/를) — 조사 고르기는 Josa 한 곳
static func obj(name: String) -> String:
	return name + Josa.pick("를", name) if name != "" else name


static func named(st: StoryState, id: String) -> bool:
	return str(st.npcs.get(id, {}).get("name", "")) != "" and not id.begins_with("N-PS")


## 주민을 죽였다(호스트가 부른다). witnessed = 다른 주민이 보았다. 돌려주는 값: {"tgt", "leader", "perm", "witnessed"}
static func on_kill(st: StoryState, id: String, witnessed: bool, region: String, now: int, place := "") -> Dictionary:
	var tgt := target(st, id)
	var out := {"tgt": tgt, "leader": false, "perm": false, "witnessed": witnessed}
	if tgt == "":
		return out
	var dd := st.deeds
	var beast := animal(st, id)
	if not beast:                                                     # 동물은 학살 셈에 넣지 않는다(리드 결정 2026-10-16 — SD-06 §3.4 정합)
		dd.kills[tgt] = int(dd.kills.get(tgt, 0)) + 1
	var leader := str(LEADERS.get(st.canon(id), "")) == tgt
	var perm := leader or int(dd.kills.get(tgt, 0)) >= MASSACRE
	out["leader"] = leader
	out["perm"] = perm
	var who := st.npc_name(id)
	dd.victims[st.canon(id)] = true
	if witnessed:
		var dv := -20 if beast else (-35 if named(st, id) else -20)   # 마을 개(이름 있어도) −20
		var tag := "CRIME_PERM" if perm else "CRIME"
		dd.record(st, "범죄", region, 3 if leader else 2, {tgt: 0 if perm else dv}, now,
			{"tag": tag, "place": place, "what": "%s %s" % [who, "사살" if animal(st, id) else "살해"], "seen_by": [tgt], "about": [id]})
		if not perm:
			dd.grudge[tgt] = maxi(1, int(dd.grudge.get(tgt, 0)))
	else:
		var seed := hash("%s:%d" % [id, now])
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		dd.bodies.append({"id": id, "tgt": tgt, "at": now, "find": now + rng.randi_range(FIND_MIN, FIND_MAX),
			"solve": rng.randf() < SOLVE, "perm": perm, "named": named(st, id) and not beast, "region": region, "place": place})
	return out


## 시체 발견(Deeds.tick이 시각 순서대로 부른다): 정착지가 죽음을 알고, 지목되면 '비목격 살해 발각'
static func find_body(st: StoryState, b: Dictionary, when: int) -> void:
	var dd := st.deeds
	var tgt := str(b["tgt"])
	var who := st.npc_name(str(b["id"]))
	dd.mourn[tgt] = when                                               # 죽음은 알려진다(범인과 상관없이 — 장례 · 수군거림)
	if not bool(b["solve"]):
		dd.heard.push_front({"fac": tgt, "what": "%s의 시체가 발견됐다(범인 모름)" % who, "at": when, "route": "시체", "tag": "CRIME_BODY"})
		return
	var perm := bool(b["perm"])
	var dv := -35 if bool(b["named"]) else -12
	dd.record(st, "범죄", str(b["region"]), 1, {tgt: 0 if perm else dv}, when,
		{"tag": "CRIME_PERM" if perm else "CRIME", "place": str(b["place"]), "what": "%s 살해 발각" % who, "seen_by": [tgt], "about": [str(b["id"])]})
	if not perm:
		dd.grudge[tgt] = maxi(1, int(dd.grudge.get(tgt, 0)))


## 영구 적대인가(값 −100 고정, 회복 불가)
static func permanent(st: StoryState, tgt: String) -> bool:
	return int(st.deeds.grudge.get(tgt, 0)) >= 2


## 정착지 · 세력이 적대인가(≤ −60, SD-06 §3.3)
static func hostile(st: StoryState, tgt: String) -> bool:
	if tgt == "":
		return false
	var k := "AFF_" + tgt
	return st.vars.has(k) and int(st.vars.get_v(k)) <= -60


## 이 살해의 범인이 주인공이라는 것을 그 정착지 · 세력이 아는가(목격 · 지목 기록이 닿았나) — 대사 조건 · 대체 장면용
static func knows_killer(st: StoryState, id: String) -> bool:
	return st.deeds.known_killer.has(st.canon(id))


## 이 정착지 · 세력이 주인공을 '우리 사람을 죽인 자'로 아는가(목격 · 지목 · 자백 중 하나라도) — 원고 함수 killer_known
static func killer_known_by(st: StoryState, tgt: String) -> bool:
	for k in st.deeds.known_killer.keys():
		if target(st, str(k)) == tgt and not animal(st, str(k)):
			return true
	return false


## 아직 발견되지 않은 그 정착지의 시체를 지금 찾는다(밤 소동에 사람들이 집집마다 뛰어다닌다 — 1-X 재미 검수 ①). 지목 주사위는 이미 굴린 값 그대로
static func find_now(st: StoryState, tgt: String, now: int) -> int:
	var n := 0
	for b in st.deeds.bodies:
		if str(b["tgt"]) == tgt and int(b["find"]) > now:
			b["find"] = now
			n += 1
	if n > 0:
		st.deeds.tick(st, now)
	return n


## 자백(1-X 페르소나 '해 보고 싶은 짓'): 아무도 몰랐던 살인을 주인공이 털어놓는다 — 새 상태 없이 '지목된 살해'와 같은 기록을 쓴다.
## 대표면 영구 적대(MQ-101은 안전한 순간에 결과 6으로 닫힌다). 직접 죽인 사람(victims)만 자백할 수 있다.
static func confess(st: StoryState, id: String, region: String, now: int, place := "") -> bool:
	var c := st.canon(id)
	if not st.deeds.victims.has(c) or knows_killer(st, c):
		return false
	var tgt := target(st, c)
	if tgt == "":
		return false
	st.deeds.bodies = st.deeds.bodies.filter(func(b): return st.canon(str(b["id"])) != c)
	var leader := str(LEADERS.get(c, "")) == tgt
	var perm := leader or int(st.deeds.kills.get(tgt, 0)) >= MASSACRE
	st.deeds.record(st, "범죄", region, 3, {tgt: 0 if perm else (-35 if named(st, c) else -12)}, now,
		{"tag": "CRIME_PERM" if perm else "CRIME", "place": place, "what": "%s 살해 — 자백" % st.npc_name(c), "seen_by": [tgt], "about": [c]})
	if not perm:
		st.deeds.grudge[tgt] = maxi(1, int(st.deeds.grudge.get(tgt, 0)))
	return true
