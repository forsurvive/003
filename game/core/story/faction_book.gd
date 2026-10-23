## 세력 기록(단계 1-12m, SD-12 §3.10 · SD-16 §9.6 · SD-06 §3.3 · §4): 핍-보이 데이터 > 세력 탭이 읽는 장부.
##   등록: 그 세력의 이름을 처음 듣거나(소식이 닿음 — deeds.heard) · 세력원을 처음 만나거나(인물 수첩 소속) · 그 세력 본거지를 발견한 순간. 그전엔 목록에 없다.
##   관계 단계: 호감도 값 + 히스테리시스(오를 땐 경계값에서 바로, 내릴 땐 그 단계 하한보다 5 낮아질 때, SD-06 §3.3). 숫자는 화면에 없다.
##   최근 일: 그 세력에 닿은 소식(deeds.heard — 주인공이 한 일, 사실 문장) + 관계 단계가 바뀐 날(SD-06 §4.3 핍-보이 한 줄). 세력당 40줄 저장 · 8줄 표시.
##   • = 읽지 않은 새 줄(탭에서 그 세력을 고르면 지운다) · ! = 적대에 가까움(경계 하단 · 적대).
class_name FactionBook
extends RefCounted

const ORDER := ["BJ", "YH", "WP", "JH", "GS", "JG", "SB", "JC", "NJ", "KD"]       ## SD-12 §3.10 목록 차례
const SETTLE := ["JC_BC", "JC_SA"]                                                  ## 1막 정착지(연합 아래 줄)
const LOG_MAX := 40
const SHOW_MAX := 8
const LOWS := [-100, -59, -19, 20, 50, 80]                                          ## 단계 하한(적대 · 경계 · 중립 · 우호 · 신뢰 · 동맹)
## 본거지 장소를 발견하면 등록(그 세력의 이름이 걸린 곳)
const HOME_LID := {"BJ": ["L-R01-19", "L-R02-03"], "SB": ["L-R02-19"], "JH": ["L-R02-11"], "GS": ["L-R01-23"], "JC_BC": ["L-R01-09"], "JC_SA": ["L-R01-18"]}

var reg := {}                                     ## 세력 -> 등록 날
var stage := {}                                   ## 세력 -> 지금 단계(0 적대 ~ 5 동맹)
var log := {}                                     ## 세력 -> [{"date", "text", "at"}] 최근 것이 앞
var unread := {}                                  ## 세력 -> true
var seen_keys := {}                               ## 이미 옮긴 소식 키
var key_order: Array = []


static func aff_key(f: String) -> String:
	return "AFF_" + f


static func aff_of(st, f: String) -> int:
	if f == "JC":
		return jc_avg(st)
	var k := aff_key(f)
	return int(st.vars.get_v(k)) if st.vars.has(k) else 0


## 정착지 연합 합산(SD-06 §3.2.2): 핵심 다섯(노들 3 · 탱크 2 · 봉천 2 · 선유 2 · 뚝섬 1) + 가맹한 사당(1)
static func jc_avg(st) -> int:
	var w := {"ND": 3, "TK": 2, "BC": 2, "SY": 2, "TS": 1}
	if int(st.vars.get_v("SA_JOIN")) == 1:
		w["SA"] = 1
	var s := 0.0
	var n := 0
	for c in w:
		if st.vars.has("AFF_JC_" + c):
			s += int(w[c]) * int(st.vars.get_v("AFF_JC_" + c))
			n += int(w[c])
	return roundi(s / n) if n > 0 else 0


## 값 → 명목 단계(히스테리시스 없이)
static func nominal(v: int) -> int:
	for i in range(LOWS.size() - 1, -1, -1):
		if v >= int(LOWS[i]):
			return i
	return 0


## 히스테리시스(SD-06 §3.3): 오를 땐 바로, 내릴 땐 지금 단계 하한 − 5 아래로
static func hyst(prev: int, v: int) -> int:
	var n := nominal(v)
	if prev < 0 or n >= prev:
		return n
	if v <= int(LOWS[prev]) - 6:
		return n
	return prev


func stage_of(st, f: String) -> int:
	if stage.has(f):
		return int(stage[f])
	return nominal(aff_of(st, f))


func registered(f: String) -> bool:
	return reg.has(f)


func _register(f: String, day: int) -> void:
	if not reg.has(f):
		reg[f] = day
		if f.begins_with("JC_") and not reg.has("JC"):
			reg["JC"] = day


func add_line(f: String, date: String, text: String, at := 0) -> void:
	if not log.has(f):
		log[f] = []
	(log[f] as Array).push_front({"date": date, "text": text, "at": at})
	while (log[f] as Array).size() > LOG_MAX:
		(log[f] as Array).pop_back()
	unread[f] = true
	if f.begins_with("JC_"):
		unread["JC"] = true


## 진행기가 수시로 부른다(가볍다): 등록 · 단계 변화 · 닿은 소식 옮기기
func refresh(st, date_text: String) -> void:
	var day := int(st.vars.get_v("GAME_DAY"))
	if int(st.vars.get_v("V_ACT")) >= 1:
		_register("BJ", day)                                         # 볼트 문을 나서는 날 계엄군을 본다(MQ-P4)
	for f in HOME_LID:
		for lid in HOME_LID[f]:
			if st.places.get_state(lid) >= PlaceLog.FOUND:
				_register(f, day)
	for c in st.book.entries:
		var fac := str(st.npcs.get(c, {}).get("faction", ""))
		if fac in ORDER:
			_register(fac, day)
		var full := str(st.npcs.get(c, {}).get("faction_full", ""))      # 'JC·BC' = 정착지 연합 · 봉천
		if full.begins_with("JC·") and ("JC_" + full.substr(3)) in SETTLE:
			_register("JC_" + full.substr(3), day)
	var heard: Array = st.deeds.heard
	for i in range(heard.size() - 1, -1, -1):                         # 오래된 것부터 옮긴다(앞이 최근)
		var h: Dictionary = heard[i]
		var key := "%d|%s|%s" % [int(h["at"]), str(h["fac"]), str(h["what"])]
		if seen_keys.has(key):
			continue
		seen_keys[key] = true
		key_order.append(key)
		while key_order.size() > 300:
			seen_keys.erase(key_order.pop_front())
		var f := str(h["fac"])
		if not (f in ORDER or f in SETTLE):
			continue
		_register(f, day)
		add_line(f, Clock.md(int(h["at"])), str(h["what"]), int(h["at"]))
	for f in ORDER + SETTLE:
		var v := aff_of(st, f)
		var prev := int(stage.get(f, -1))
		var s := hyst(prev, v)
		if prev >= 0 and s != prev and reg.has(f):
			var lines: Array = Turf.data.get("factions", {}).get(f, Turf.data.get("factions", {}).get(f.split("_")[0], {})).get("stage", [])
			if s < lines.size() and str(lines[s]) != "":
				add_line(f, _md(date_text), str(lines[s]))
		stage[f] = s


static func _md(date_text: String) -> String:
	var t := Clock.parse(date_text)
	return "%02d. %02d." % [int(t[1]), int(t[2])] if not t.is_empty() else ""


## 목록(등록된 것만, 차례대로): [{"f", "sub"(정착지 줄), "dot", "warn"}]
func listed(st) -> Array:
	var out: Array = []
	for f in ORDER:
		if not reg.has(f):
			continue
		out.append({"f": f, "sub": false, "dot": bool(unread.get(f, false)), "warn": _warn(st, f)})
		if f == "JC":
			for s in SETTLE:
				if reg.has(s):
					out.append({"f": s, "sub": true, "dot": bool(unread.get(s, false)), "warn": _warn(st, s)})
	return out


func _warn(st, f: String) -> bool:
	var v := aff_of(st, f)
	return v <= -40


## 관계 한 줄: 경계 ±5면 '기울고 있음' 문장, 아니면 단계 문장
func relation_line(st, f: String) -> String:
	Turf.load_data()
	var fd: Dictionary = Turf.data.get("factions", {}).get(f, {})
	var base: Dictionary = Turf.data.get("factions", {}).get(f.split("_")[0], fd)
	var v := aff_of(st, f)
	var s := int(stage.get(f, nominal(v)))
	for i in range(1, LOWS.size()):
		if absi(v - int(LOWS[i])) <= 5:
			var near: Array = base.get("near", [])
			if i - 1 < near.size() and str(near[i - 1]) != "":
				return str(near[i - 1])
	var lines: Array = base.get("stage", [])
	return str(lines[s]) if s < lines.size() else ""


func treat_line(st, f: String) -> String:
	var base: Dictionary = Turf.data.get("factions", {}).get(f.split("_")[0], {})
	var s := int(stage.get(f, nominal(aff_of(st, f))))
	var t: Array = base.get("treat", [])
	return str(t[s]) if s < t.size() else ""


func hear_line(st, f: String) -> String:
	var base: Dictionary = Turf.data.get("factions", {}).get(f.split("_")[0], {})
	var s := int(stage.get(f, nominal(aff_of(st, f))))
	var t: Array = base.get("hear", [])
	return str(t[s]) if s < t.size() else ""


func desc_of(f: String) -> String:
	return str(Turf.data.get("factions", {}).get(f, {}).get("desc", ""))


func name_of(f: String) -> String:
	return str(Turf.data.get("factions", {}).get(f, {}).get("name", f))


## 최근 일(정착지 연합 줄은 아래 정착지들 것도 함께)
func lines_of(f: String) -> Array:
	var out: Array = (log.get(f, []) as Array).duplicate()
	if f == "JC":
		for s in SETTLE:
			out += log.get(s, [])
		out.sort_custom(func(a, b): return int(a.get("at", 0)) > int(b.get("at", 0)))
	return out.slice(0, SHOW_MAX)


func read(f: String) -> void:
	unread.erase(f)
	if f == "JC":
		for s in SETTLE:
			unread.erase(s)


func any_unread() -> bool:
	return not unread.is_empty()


func to_dict() -> Dictionary:
	return {"reg": reg.duplicate(), "stage": stage.duplicate(), "log": log.duplicate(true), "unread": unread.keys(), "keys": key_order.duplicate()}


func from_dict(d: Dictionary) -> void:
	d = Turf._ints(d)
	reg = (d.get("reg", {}) as Dictionary).duplicate()
	stage = (d.get("stage", {}) as Dictionary).duplicate()
	log = (d.get("log", {}) as Dictionary).duplicate(true)
	unread = {}
	for k in d.get("unread", []):
		unread[k] = true
	key_order = (d.get("keys", []) as Array).duplicate()
	seen_keys = {}
	for k in key_order:
		seen_keys[k] = true
