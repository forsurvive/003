## 인카운터 판정(단계 1-3, SD-05 §6 스폰 규칙 · SD-08 §13.3 이동 판정 · §14.3 위협도 격자) — 규칙만(배치·연출은 EncounterLive).
## 판정 기회: 청크 경계를 넘을 때(위협 1~3 = 3청크마다 · 4~5 = 2청크마다, 확률 12·18·24·28·35%), 고정 지점 EP에 들어설 때(EP 전용 확률),
## 실내에서 밖으로 나올 때, 빠른 이동으로 도착했을 때(추적대 첫 출현 후보). 안전 간격: RE 하나가 끝나면 다음 2번의 기회를 건너뛴다.
## 판정 없음: 정착지 반경 2청크 안 · 놀이 밖(위협 0) · 진행기가 막은 동안(메인 스크립트 장면).
## 순서(§6.1): ① 추적대 끼워 넣기(수배 등급 0~4 → 판정마다 0·5·10·15·20%, 하루 상한 1·1·1·2·3 — 1막은 RE-087이 등급과 무관하게
## 활성) ② 막·판도 특수 표(1-3에는 없음) ③ 구역 기본 표(1-3은 엔진 확인용 RE-004만 — 나머지 표는 1-13).
## 상태(StoryState.enc, 저장): 안전 간격 남은 수 · 오늘 추적대 수 · EP 사용(1회 = -1, 반복 = 마지막 분 — 72게임시간 뒤 다시).
class_name Encounters
extends RefCounted

const PATH := "res://data/world/encounters.json"
const CHUNK := 40
const SAFE_SKIP := 2
const EP_R := 6                                   ## EP 진입 반경(타일) — 표는 지점만 준다(정합)
const EP_RESET_MIN := 72 * 60
const TRACKER_P := [0.0, 0.05, 0.10, 0.15, 0.20]
const TRACKER_DAY_CAP := [0, 1, 1, 2, 3]
## RE 정의(1-3은 엔진 확인용 둘. 편성: CR-ID, 최소, 최대 — 레벨 구간마다 +1, 최대에서 멈춤)
const RES := {
	"RE-087": {"name": "생포 추적대(새벽인력)", "kind": "tracker", "units": [["CR-436", 1, 1], ["CR-437", 2, 3]], "talk": "RE-087_TALK",
		"capture": "SB"},
	"RE-004": {"name": "시체 뜯는 바퀴", "kind": "hostile", "units": [["CR-002", 3, 6]], "night": true, "no_region": ["R05"]},
}

static var data := {}
var st: StoryState
var rng := RandomNumberGenerator.new()
var last_chunk := Vector2i(-9999, -9999)
var steps := 0                                    ## 넘은 청크 경계 수(판정 주기)
var inside_ep := {}                               ## 지금 들어서 있는 EP(나갈 때까지 다시 판정하지 않는다)
var trace: Array = []                             ## 판정 기록(시험·봇): [{"src", "t", "threat", "p", "roll", "re"}]


static func load_data() -> void:
	if data.is_empty() and FileAccess.file_exists(PATH):
		data = JSON.parse_string(FileAccess.get_file_as_string(PATH))


func _init(state: StoryState = null, seed_v := 0) -> void:
	st = state
	rng.seed = seed_v if seed_v != 0 else Time.get_ticks_usec()
	load_data()


func enc() -> Dictionary:
	if not st.enc.has("ep"):
		st.enc["ep"] = {}
	return st.enc


# ---------------------------------------------------------------- 자리 정보
## 청크 위협도 1~5(놀이 밖 0, 위협 3 이하 한강 수면 `~` = 2)
static func threat_at(t: Vector2i) -> int:
	load_data()
	var g: Array = data.get("threat", [])
	var cx := t.x / CHUNK
	var cy := t.y / CHUNK
	if t.x < 0 or t.y < 0 or cy >= g.size() or cx >= str(g[cy]).length():
		return 0
	var c := str(g[cy])[cx]
	if c == "~":
		return 2
	return int(c) if c.is_valid_int() else 0


## 정착지 반경 2청크 안(이동 판정 없음, SD-05 §6.2)
static func near_settlement(t: Vector2i) -> bool:
	load_data()
	var k := Vector2i(t.x / CHUNK, t.y / CHUNK)
	for s in data.get("settlements", []):
		var sk := Vector2i(int(s[1]) / CHUNK, int(s[2]) / CHUNK)
		if absi(sk.x - k.x) <= 2 and absi(sk.y - k.y) <= 2:
			return true
	return false


# ---------------------------------------------------------------- 판정 기회
## 걸어서 움직였다: 청크 경계와 EP 진입을 본다. 배치할 RE 요청 {"re", "src", "ep"} 또는 {}
func on_move(t: Vector2i, now_min: int, night: bool, region: String) -> Dictionary:
	var req := _ep_check(t, now_min, night)
	if not req.is_empty():
		return req
	var k := Vector2i(t.x / CHUNK, t.y / CHUNK)
	if k == last_chunk:
		return {}
	var first := last_chunk.x < -999
	last_chunk = k
	if first:                                                       # 처음 자리 잡기는 경계 넘기가 아니다
		return {}
	steps += 1
	var th := threat_at(t)
	if th <= 0 or near_settlement(t):
		return {}
	var ch: Array = data.get("chance", {}).get(str(th), [3, 0.0])
	if steps % int(ch[0]) != 0:
		return {}
	return _roll("move", t, float(ch[1]), night, region)


## 실내에서 밖으로 나왔다(§6.1 판정 기회). 위협도 확률표를 쓴다
func on_exit_interior(t: Vector2i, night: bool, region: String) -> Dictionary:
	last_chunk = Vector2i(t.x / CHUNK, t.y / CHUNK)
	var th := threat_at(t)
	if th <= 0 or near_settlement(t):
		return {}
	return _roll("exit", t, float(data.get("chance", {}).get(str(th), [3, 0.0])[1]), night, region)


## 빠른 이동 도착(§6.2): 매복 판정은 판도(1-10) 뒤에. 추적대가 오늘 남았으면 도착 지점이 첫 출현 후보
func on_arrive(t: Vector2i, night: bool, region: String) -> Dictionary:
	last_chunk = Vector2i(t.x / CHUNK, t.y / CHUNK)
	if near_settlement(t):
		return {}
	var tr := _tracker(1.0 if _tracker_p() > 0.0 else 0.0)
	return {"re": tr, "src": "arrive"} if tr != "" else {}


func _roll(src: String, t: Vector2i, p: float, night: bool, region: String) -> Dictionary:
	var e := enc()
	var roll := rng.randf()
	var rec := {"src": src, "t": t, "threat": threat_at(t), "p": p, "roll": roll, "re": ""}
	trace.append(rec)
	if int(e.get("safe", 0)) > 0:
		e["safe"] = int(e["safe"]) - 1
		rec["re"] = "(안전 간격)"
		return {}
	if roll >= p:
		return {}
	var re := _tracker(_tracker_p())                                 # ① 추적대 끼워 넣기
	if re == "":
		re = _base(region, night)                                    # ③ 구역 기본 표
	rec["re"] = re
	return {"re": re, "src": src} if re != "" else {}


## EP: 반경 안으로 들어설 때 1번. 1회 EP는 쓰면 끝, 반복 EP는 72게임시간 뒤 다시(SD-14 §11.3)
func _ep_check(t: Vector2i, now_min: int, night: bool) -> Dictionary:
	var e := enc()
	for ep in data.get("ep", []):
		var id := str(ep["id"])
		var near: bool = absi(int(ep["pos"][0]) - t.x) <= EP_R and absi(int(ep["pos"][1]) - t.y) <= EP_R
		if not near:
			inside_ep.erase(id)
			continue
		if inside_ep.has(id):
			continue
		inside_ep[id] = true
		var used: int = int(e["ep"].get(id, -99999999))
		if used == -1 or (used > -99999999 and now_min - used < EP_RESET_MIN):
			continue
		var res: Array = (ep["re"] as Array).filter(func(r): return RES.has(r))
		if res.is_empty():
			continue                                                 # 이 단계에 정의가 없는 RE만 걸린 EP(1-13에서)
		if ep.has("wanted_min") and Wanted.grade(st) < int(ep["wanted_min"]):
			continue
		if bool(ep.get("night_only", false)) and not night:
			continue
		var p: float = float(ep.get("p_night", ep["p"])) if night else float(ep["p"])
		var roll := rng.randf()
		trace.append({"src": "ep:" + id, "t": t, "threat": threat_at(t), "p": p, "roll": roll, "re": ""})
		e["ep"][id] = -1 if bool(ep["once"]) else now_min
		if roll >= p:
			continue
		var re := ""
		for r in res:
			if RES[r]["kind"] == "tracker":
				re = _tracker(1.0) if re == "" else re
			elif re == "" and (not bool(RES[r].get("night", false)) or night):
				re = r
		if re != "":
			trace[-1]["re"] = re
			return {"re": re, "src": "ep", "ep": id}
	return {}


# ---------------------------------------------------------------- 표
## 추적대 끼워 넣기 확률(수배 등급 → 0·5·10·15·20%). 오늘 상한을 다 썼거나 추적대가 꺼져 있으면 0
func _tracker_p() -> float:
	if not tracker_on():
		return 0.0
	var g := Wanted.grade(st)
	var e := enc()
	var day := int(st.vars.get_v("GAME_DAY")) if st.vars.has("GAME_DAY") else 0
	if int(e.get("trk_day", -1)) != day:
		e["trk_day"] = day
		e["trk_n"] = 0
	if int(e.get("trk_n", 0)) >= TRACKER_DAY_CAP[maxi(g, 1)]:
		return 0.0
	return TRACKER_P[maxi(g, 1)]


func _tracker(p: float) -> String:
	if p <= 0.0 or rng.randf() >= p:
		return ""
	var e := enc()
	e["trk_n"] = int(e.get("trk_n", 0)) + 1
	return "RE-087"


## 새벽인력 생포 추적대가 도는가(SD-05 §6.4 · RE-087): 1막은 등급과 무관하게 활성, 2막부터는 수배 2+.
## 꺼짐: 새벽인력 우호 이상 · 1막 독사 매수(MQ-101 해법 4) · MQ-105 장부 처리(HO_LEDGER) · 합의금 7일(SB_TRUCE_UNTIL)
func tracker_on() -> bool:
	var act := st.quests.cur_act()
	if act < 1:
		return false
	if st.vars.has("AFF_SB") and int(st.vars.get_v("AFF_SB")) >= 20:
		return false
	if act == 1 and st.vars.has("MQ101_RESULT") and int(st.vars.get_v("MQ101_RESULT")) == 4:
		return false
	if st.vars.has("HO_LEDGER") and int(st.vars.get_v("HO_LEDGER")) != 0:
		return false
	var day := int(st.vars.get_v("GAME_DAY")) if st.vars.has("GAME_DAY") else 0
	if int(enc().get("truce_until", -1)) >= day:
		return false
	return act == 1 or Wanted.grade(st) >= 2


## 구역 기본 표(1-3: 엔진 확인용 RE-004 하나 — 밤, R05 밖)
func _base(region: String, night: bool) -> String:
	var cands: Array = []
	for r in RES:
		var d: Dictionary = RES[r]
		if d["kind"] != "hostile":
			continue
		if bool(d.get("night", false)) and not night:
			continue
		if region in d.get("no_region", []):
			continue
		cands.append(r)
	return cands[rng.randi() % cands.size()] if not cands.is_empty() else ""


## 편성(레벨 구간 1~7 · 8~14 · 15~21 · 22+, SD-14 §9.13 — 구간마다 +1, 최대에서 멈춤) → CR-ID 목록
func units(re: String, level: int) -> Array:
	var band := 0 if level <= 7 else (1 if level <= 14 else (2 if level <= 21 else 3))
	var out: Array = []
	for u in RES[re]["units"]:
		var n: int = int(u[1]) + band
		if RES[re]["kind"] == "hostile":
			n = rng.randi_range(int(u[1]), int(u[2]))
		for i in mini(n, int(u[2])):
			out.append(str(u[0]))
	return out


## RE가 끝났다(적 전멸·놓침·대화 끝): 안전 간격
func finished() -> void:
	enc()["safe"] = SAFE_SKIP
