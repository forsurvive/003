## 인카운터 판정(단계 1-3 → 1-E, SD-05 §6 스폰 규칙 · SD-08 §13.3 이동 판정 · §14.3 위협도 격자 · SD-22 §3 변주) — 규칙만(배치·연출은 EncounterLive).
## 판정 기회: 청크 경계를 넘을 때(위협 1~3 = 3청크마다 · 4~5 = 2청크마다, 확률 12·18·24·28·35%), 고정 지점 EP에 들어설 때(EP 전용 확률),
## 실내에서 밖으로 나올 때, 빠른 이동으로 도착했을 때(추적대 첫 출현 후보). 안전 간격: RE 하나가 끝나면 다음 2번의 기회를 건너뛴다(흔적을 보고 피했으면 1번).
## 판정 없음: 정착지 반경 2청크 안 · 놀이 밖(위협 0) · 진행기가 막은 동안(메인 스크립트 장면).
## 순서(§6.1): ① 추적대 끼워 넣기(수배 등급 0~4 → 판정마다 0·5·10·15·20%, 하루 상한 1·1·1·2·3 — 1막은 RE-087이 등급과 무관하게
## 활성) ② 막·판도 특수 표(판도 구현 전 없음) ③ 구역 기본 표(data/world/encounters.json "re" — tools/pipeline/encounter_table.py).
## 1-E(SD-22): 후보를 먼저 고르고(범주 가중 × RE 가중 × 지역 어울림 × 시간 × 반복 피하기 × 조건 배수) 그 후보의 확률 배수로 굴린다
## (§3.6 '표에서 하나를 고를 때도 같은 조건이 RE별 가중에 곱해진다'). 상황(S1~S7)도 가중으로 고른다(§3.1). 놓친 무리는 기억된다(§3.5).
## 상태(StoryState.enc, 저장): 안전 간격 · 오늘 추적대 수 · EP 사용 · 고요 누적(calm) · 최근 판정(recent) · 청크별 마지막 범주(chunk) · 남은 무리(packs).
class_name Encounters
extends RefCounted

const PATH := "res://data/world/encounters.json"
const CHUNK := 40
const SAFE_SKIP := 2
const EP_R := 6                                   ## EP 진입 반경(타일) — 표는 지점만 준다(정합)
const EP_RESET_MIN := 72 * 60
const TRACKER_P := [0.0, 0.05, 0.10, 0.15, 0.20]
const TRACKER_DAY_CAP := [0, 1, 1, 2, 3]
const P_MIN := 0.03                               ## SD-22 §3.6 하한·상한
const P_MAX := 0.6
const CALM_STEP := 0.03                           ## 고요 누적: 판정 실패마다 +0.03(최대 +0.15)
const CALM_MAX := 0.15
const RECENT_N := 6                               ## 반복 피하기: 최근 6건
const RECAT_MIN := 12 * 60                        ## 같은 청크 12게임시간 안에는 다른 범주
const STATES := ["S1", "S2", "S3", "S4", "S5", "S6", "S7"]
## 표가 없을 때(시험 자료·옛 자료)의 기본 RE — 표("re")가 있으면 표가 이긴다
const RES := {
	"RE-087": {"name": "생포 추적대(새벽인력)", "cat": "tracker", "regions": "*", "no_regions": ["R05"], "time": "any", "weight": 0,
		"groups": [{"side": "a", "units": [["CR-436", 1, 1], ["CR-437", 2, 3]], "hostile": false}], "talk": "RE-087_TALK",
		"capture": "SB", "states": {"S1": 1}},
	"RE-004": {"name": "시체 뜯는 바퀴", "cat": "creature", "regions": "*", "no_regions": ["R05"], "time": "night", "weight": 5,
		"groups": [{"side": "a", "units": [["CR-002", 3, 6]], "hostile": true}], "states": {"S3": 5, "S1": 1}, "sign": "skitter"},
}
const CAT_W_DEFAULT := {"경합": {"patrol": 30, "clash": 30, "creature": 10, "raider": 8, "trader": 7, "event": 10},
	"공백": {"creature": 45, "raider": 25, "trader": 5, "event": 15}}

static var data := {}
var st: StoryState
var rng := RandomNumberGenerator.new()
var last_chunk := Vector2i(-9999, -9999)
var steps := 0                                    ## 넘은 청크 경계 수(판정 주기)
var inside_ep := {}                               ## 지금 들어서 있는 EP(나갈 때까지 다시 판정하지 않는다)
var trace: Array = []                             ## 판정 기록(시험·봇): [{"src", "t", "threat", "p", "roll", "re", "state", "cand"}]
var now_min := 0                                  ## 판정 시각(분) — 청크 12시간 규칙
var ctx := {}                                     ## 판정 맥락(EncounterLive가 채운다): tags · road · move · shot · hour · level


static func load_data() -> void:
	if data.is_empty() and FileAccess.file_exists(PATH):
		data = JSON.parse_string(FileAccess.get_file_as_string(PATH))


## RE 정의(표 우선, 없으면 기본)
static func re_def(id: String) -> Dictionary:
	load_data()
	var t: Dictionary = data.get("re", {})
	return t.get(id, RES.get(id, {}))


static func table() -> Dictionary:
	load_data()
	return data.get("re", RES)


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
## 걸어서 움직였다: 청크 경계와 EP 진입을 본다. 배치할 RE 요청 {"re", "src", "state", "ep"} 또는 {}
func on_move(t: Vector2i, now: int, night: bool, region: String) -> Dictionary:
	now_min = now
	var req := _ep_check(t, now, night)
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
	return {"re": tr, "src": "arrive", "state": "S1"} if tr != "" else {}


## 판정 한 번: 후보 고르기 → 그 후보의 확률(기본 × 조건 배수 + 고요 누적, 0.03~0.6) → 굴림
func _roll(src: String, t: Vector2i, p: float, night: bool, region: String) -> Dictionary:
	var e := enc()
	var cand := _pick(region, night, t)
	var pe := 0.0
	if p > 0.0:
		pe = clampf(p * global_mult() * (cat_mult(re_def(cand), region, t, night) if cand != "" else 1.0) + float(e.get("calm", 0.0)), P_MIN, P_MAX)
	var roll := rng.randf()
	var rec := {"src": src, "t": t, "threat": threat_at(t), "p": pe, "base": p, "roll": roll, "re": "", "cand": cand}
	trace.append(rec)
	if int(e.get("safe", 0)) > 0:
		e["safe"] = int(e["safe"]) - 1
		rec["re"] = "(안전 간격)"
		return {}
	if roll >= pe:
		e["calm"] = minf(CALM_MAX, float(e.get("calm", 0.0)) + CALM_STEP)
		return {}
	var re := _tracker(_tracker_p())                                 # ① 추적대 끼워 넣기
	if re == "":
		re = cand                                                    # ③ 구역 기본 표
	if re == "":
		return {}
	e["calm"] = 0.0
	var state := pick_state(re, night)
	rec["re"] = re
	rec["state"] = state
	_remember_pick(re, state, t)
	return {"re": re, "src": src, "state": state}


## EP: 반경 안으로 들어설 때 1번. 1회 EP는 쓰면 끝, 반복 EP는 72게임시간 뒤 다시(SD-14 §11.3)
func _ep_check(t: Vector2i, now: int, night: bool) -> Dictionary:
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
		if used == -1 or (used > -99999999 and now - used < EP_RESET_MIN):
			continue
		var res: Array = (ep["re"] as Array).filter(func(r): return not re_def(str(r)).is_empty() and not re_def(str(r)).get("groups", []).is_empty())
		if res.is_empty():
			continue                                                 # 이 단계에 정의가 없는 RE만 걸린 EP(뒤 단계에서)
		if ep.has("wanted_min") and Wanted.grade(st) < int(ep["wanted_min"]):
			continue
		if bool(ep.get("night_only", false)) and not night:
			continue
		var p: float = float(ep.get("p_night", ep["p"])) if night else float(ep["p"])
		var roll := rng.randf()
		trace.append({"src": "ep:" + id, "t": t, "threat": threat_at(t), "p": p, "roll": roll, "re": ""})
		e["ep"][id] = -1 if bool(ep["once"]) else now
		if roll >= p:
			continue
		var re := ""
		for r in res:
			var d := re_def(str(r))
			if d["cat"] == "tracker":
				re = _tracker(1.0) if re == "" else re
			elif re == "" and _time_ok(d, night, int(ctx.get("hour", 12))):
				re = str(r)
		if re != "":
			trace[-1]["re"] = re
			var state := pick_state(re, night)
			_remember_pick(re, state, t)
			return {"re": re, "src": "ep", "ep": id, "state": state}
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


## 구역 기본 표에서 하나(시험용 얇은 입구 — 낮·밤만 주고 나머지 맥락은 지금 ctx)
func _base(region: String, night: bool) -> String:
	return _pick(region, night, Vector2i(-1, -1))


## 판정 위치의 범주 가중 표(판도 — SD-05 §6.3 · SD-06 §5.9 시작 판도: 표에 없는 권역은 공백)
func _cat_table(region: String) -> Dictionary:
	var cw: Dictionary = data.get("cat_w", CAT_W_DEFAULT)
	var state := str(data.get("region_state", {}).get(region, "공백"))
	return cw.get(state, cw.get("공백", {}))


## RE가 이 자리·시각에 나올 수 있나(권역 · 시간 · 위협 · 조건)
func _allowed(d: Dictionary, region: String, night: bool, th: int) -> bool:
	var regs = d.get("regions", "*")
	if typeof(regs) == TYPE_ARRAY and not (region in regs):
		return false
	if region in d.get("no_regions", []):
		return false
	if not _time_ok(d, night, int(ctx.get("hour", 22 if night else 12))):
		return false
	if th > 0 and (th < int(d.get("threat_min", 0)) or th > int(d.get("threat_max", 9))):
		return false
	var c := str(d.get("cond", ""))
	if c != "" and not StoryExpr.test(c, st):
		return false
	return true


static func _time_ok(d: Dictionary, night: bool, hour: int) -> bool:
	var tm = d.get("time", "any")
	if typeof(tm) == TYPE_ARRAY:
		var a := int(tm[0])
		var b := int(tm[1])
		return (hour >= a and hour < b) if a <= b else (hour >= a or hour < b)
	match str(tm):
		"day":
			return not night
		"night":
			return night
	return true


## 후보 하나를 가중으로 고른다(§3.6 · §3.7 · §4.2 · §3.5). 없으면 ""
func _pick(region: String, night: bool, t: Vector2i) -> String:
	var tab := table()
	var cw := _cat_table(region)
	var cat_sum := {}
	for id in tab:
		var c := str(tab[id].get("cat", ""))
		cat_sum[c] = float(cat_sum.get(c, 0.0)) + float(tab[id].get("weight", 0))
	var th := threat_at(t) if t.x >= 0 else 0
	var ids: Array = []
	var ws: Array = []
	var total := 0.0
	for id in tab:
		var d: Dictionary = tab[id]
		var c := str(d.get("cat", ""))
		if c == "tracker" or float(d.get("weight", 0)) <= 0.0 or float(cat_sum.get(c, 0.0)) <= 0.0:
			continue
		if not _allowed(d, region, night, th):
			continue
		var w: float = float(cw.get(c, 0)) * float(d["weight"]) / float(cat_sum[c])
		w *= fit_mult(d) * cat_mult(d, region, t, night) * _repeat_mult(str(id), c, t)
		if night:
			w *= float(d.get("night_w", 1.0))
		if w > 0.0:
			ids.append(id)
			ws.append(w)
			total += w
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for i in ids.size():
		r -= float(ws[i])
		if r <= 0.0:
			return str(ids[i])
	return str(ids[-1])


## 지역 어울림(§4.2): 판정 청크 태그가 어울리면 ×2, 금지 태그면 ×0
func fit_mult(d: Dictionary) -> float:
	var tags: Array = ctx.get("tags", [])
	for b in d.get("ban", []):
		if b in tags:
			return 0.0
	for p in d.get("prefer", []):
		if p in tags:
			return 2.0
	return 1.0


## 판정 자리·움직임에 걸리는 배수(§3.6 — 모든 후보에 같다): 길 위계 · 웅크림 · 30초 안 총성
func global_mult() -> float:
	var m := 1.0
	match int(ctx.get("road", 0)):
		3:
			m *= 1.3                                                    # 고가·큰길(H1) 위
		1:
			m *= 0.6                                                    # 동네 길·골목
	match str(ctx.get("move", "walk")):
		"sneak":
			m *= 0.7
		"sprint":
			m *= 1.25
	if float(ctx.get("shot", 999.0)) <= 30.0:
		m *= 1.4
	return m


## 후보 범주·세력에 걸리는 배수(§3.6): 밤 크리처·약탈자 · 새벽 인력 · 수배 순찰 · 레벨 차 · 행운 · 카르마
func cat_mult(d: Dictionary, region: String, _t: Vector2i, night: bool) -> float:
	var c := str(d.get("cat", ""))
	var m := 1.0
	if night and c in ["creature", "raider"]:
		m *= 1.3
	var hour := int(ctx.get("hour", 12))
	if region == "R02" and str(d.get("faction", "")) == "SB" and hour >= 4 and hour < 6:
		m *= 2.0                                                        # 새벽 04~06 인력시장
	if c == "patrol":
		m *= 1.0 + 0.1 * Wanted.grade(st)
	var th := threat_at(_t) if _t.x >= 0 else 0
	if th > 0 and int(ctx.get("level", 1)) - (th * 4 - 3) >= 6:     # 권역 기본 레벨(위협 1 = Lv1 … 5 = Lv17)보다 6 넘게 높다
		if c in ["creature", "raider"] and int(d.get("threat_max", 9)) <= th:
			m *= 0.6
		elif c in ["trader", "event"]:
			m *= 1.2
	if bool(d.get("luck", false)):
		m *= 0.5 + st.stat("LK") * 0.1
	var karma := int(st.vars.get_v("V_KARMA")) if st.vars.has("V_KARMA") else 0
	if karma >= 750 and bool(d.get("rescue", false)):
		m *= 1.2
	elif karma <= -750 and c == "trader":
		m *= 0.7
	return m


## 반복 피하기(§3.5): 최근 6건 안 같은 RE ×0.25 · 같은 청크 12게임시간 안이면 다른 범주만
func _repeat_mult(id: String, c: String, t: Vector2i) -> float:
	var e := enc()
	var m := 1.0
	for r in e.get("recent", []):
		if str(r[0]) == id:
			m = 0.25
	if t.x >= 0:
		var k := "%d,%d" % [t.x / CHUNK, t.y / CHUNK]
		var last: Array = e.get("chunk", {}).get(k, [])
		if not last.is_empty() and now_min - int(last[0]) < RECAT_MIN and str(last[1]) == c:
			return 0.0
	return m


## 상황 고르기(§3.1): RE의 states 가중 × 밤 S4·S2 ×1.5 / 낮 S1·S5 ×1.3 × 최근 같은 상황 ×0.5. 세 번 놓친 무리는 야영(S4)
func pick_state(re: String, night: bool) -> String:
	var d := re_def(re)
	var sts: Dictionary = d.get("states", {"S1": 1})
	var pack: Dictionary = enc().get("packs", {}).get(re, {})
	if int(pack.get("lost", 0)) >= 3 and sts.has("S4"):
		return "S4"
	var recent: Array = enc().get("recent", [])
	var keys: Array = []
	var ws: Array = []
	var total := 0.0
	for s in sts:
		var w := float(sts[s])
		if night and s in ["S4", "S2"]:
			w *= 1.5
		elif not night and s in ["S1", "S5"]:
			w *= 1.3
		for r in recent:
			if r.size() > 1 and str(r[1]) == s:
				w *= 0.5
				break
		keys.append(s)
		ws.append(w)
		total += w
	var r := rng.randf() * total
	for i in keys.size():
		r -= float(ws[i])
		if r <= 0.0:
			return str(keys[i])
	return str(keys[-1]) if not keys.is_empty() else "S1"


func _remember_pick(re: String, state: String, t: Vector2i) -> void:
	var e := enc()
	var recent: Array = e.get("recent", [])
	recent.append([re, state])
	while recent.size() > RECENT_N:
		recent.pop_front()
	e["recent"] = recent
	if t.x >= 0:
		var ch: Dictionary = e.get("chunk", {})
		ch["%d,%d" % [t.x / CHUNK, t.y / CHUNK]] = [now_min, str(re_def(re).get("cat", ""))]
		if ch.size() > 64:                                               # 오래된 청크 기록은 버린다(저장 크기)
			var oldest := ""
			for k in ch:
				if oldest == "" or int(ch[k][0]) < int(ch[oldest][0]):
					oldest = k
			ch.erase(oldest)
		e["chunk"] = ch


# ---------------------------------------------------------------- 편성
## 편성(§3.2, 레벨 구간 1~7 · 8~14 · 15~21 · 22+, SD-14 §9.13 — 구간마다 +1, 최대에서 멈춤).
## [{"side", "hostile", "ids": [CR…], "hurt": [0이면 성함, 아니면 HP 비율]}]. 놓친 무리가 남아 있으면 그 무리가 다시 나온다(§3.5)
func groups(re: String, level: int, state: String = "S1") -> Array:
	var d := re_def(re)
	var band := 0 if level <= 7 else (1 if level <= 14 else (2 if level <= 21 else 3))
	var pack: Dictionary = enc().get("packs", {}).get(re, {})
	var out: Array = []
	for g in d.get("groups", []):
		var ids: Array = []
		for u in g["units"]:
			var n: int
			if str(d.get("cat", "")) == "tracker":
				n = mini(int(u[1]) + band, int(u[2]))
			else:
				n = mini(rng.randi_range(int(u[1]), int(u[2])) + band, int(u[2]))
			for i in n:
				ids.append(str(u[0]))
		if g.has("leader") and rng.randf() < float(g["leader"][1]):
			ids.push_front(str(g["leader"][0]))
		if str(g.get("side", "a")) == "a":
			for m in d.get("mix", []):
				if rng.randf() < float(m[3]):
					for i in rng.randi_range(int(m[1]), int(m[2])):
						ids.append(str(m[0]))
		out.append({"side": str(g.get("side", "a")), "hostile": bool(g.get("hostile", true)), "ids": ids, "hurt": []})
	if not pack.is_empty() and not out.is_empty() and not (pack.get("ids", []) as Array).is_empty():
		out[0]["ids"] = (pack["ids"] as Array).duplicate()               # 놓친 무리: 줄어든 인원 그대로
		out[0]["pack"] = true
	var wp := float(d.get("wounded", 0.35))
	for g in out:
		for i in g["ids"].size():
			g["hurt"].append(rng.randf_range(0.3, 0.6) if state in ["S5", "S6", "S7"] and rng.randf() < wp else 0.0)
	return out


## 편성을 한 줄로(옛 입구 · 시험)
func units(re: String, level: int) -> Array:
	var out: Array = []
	for g in groups(re, level):
		out.append_array(g["ids"])
	return out


# ---------------------------------------------------------------- 끝
## 놓친 적대 무리를 기억한다(§3.5): 다음 같은 RE 판정 때 남은 인원으로 다시 나온다. 정리하면 잊는다
func remember_pack(re: String, ids: Array) -> void:
	var e := enc()
	var packs: Dictionary = e.get("packs", {})
	if ids.is_empty():
		packs.erase(re)
	else:
		var p: Dictionary = packs.get(re, {})
		p["lost"] = int(p.get("lost", 0)) + 1
		p["ids"] = ids.duplicate()
		packs[re] = p
	e["packs"] = packs


## RE가 끝났다(적 전멸·놓침·대화 끝): 안전 간격. 흔적을 보고 피했으면 절반(§3.4)
func finished(half := false) -> void:
	enc()["safe"] = 1 if half else SAFE_SKIP
