## 행적 기록과 정보 전파(단계 1-10c, SD-06 §6): 세력은 주인공이 한 일을 '알게 된 뒤에' 반응한다. 행동 하나가 기록 하나 —
## 공개도(0 비밀 · 1 목격 · 2 공개 · 3 방송급) · 구역 · 시각 · 대기 효과(세력별 호감도 변화, 아직 반영 전)를 담고, 경로를 따라 퍼져
## 도착한 세력에게 그때 효과가 반영된다. 시간 도약(사흘 구금 · 긴 잠)에도 넘어간 도착을 시각 순서대로 모두 처리한다(SD-20 P6).
##   경로(§6.3): 직접 목격 = 즉시(호출하는 쪽이 seen_by로) · 정보원 = 비상정부 6시간(봉천 · 노들섬 · 세이프빌 · 양재 온실촌의 공개도 1 이상) ·
##   소문 = 같은 구역 12시간, 인접 구역마다 +12시간, 3구역까지, 공개도 2 이상(R05 발생은 +24시간) ·
##   남산 방송 = 다음 정시 뉴스(6시간 주기), 공개도 3 전부 + 공개도 2 한 건 · 공보방송 = 비상정부가 관련된 공개도 2 이상, 다음 정시.
##   행상 · 지하시장 정보상 · 용산 기지 방송 경로는 해당 세력 · 방송국이 들어올 때(정합).
##   퍼지지 않은 기록은 7일 뒤 사라진다. 도착하면 '들은 소식' 한 줄(핍-보이 세력 기록의 '최근 사건' — 수치 없음)과 기록별 후속(hook)을 남긴다.
class_name Deeds
extends RefCounted

const SLOT := 360                                  ## 정시 뉴스 · 공고 주기(분)
const RUMOR_H := 12
const EXPIRE := 7 * 1440
const INFORMANT := ["BC", "ND", "SV", "YJ"]        ## 비상정부 분류반 정보원이 있는 정착지(SD-07b)
## 권역 인접(SD-08 권역 지도: 한강 HR은 강변 권역을 잇는다 — 소문은 강을 건넌다)
const ADJ := {
	"R01": ["R02", "R07", "R11"], "R02": ["R01", "R04", "R10", "HR"], "R03": ["R04", "R05", "R09", "R10", "HR"],
	"R04": ["R02", "R03", "HR"], "R05": ["R03", "R06", "R08", "R09"], "R06": ["R05", "R08", "HR"],
	"R07": ["R01", "R08", "R11", "HR"], "R08": ["R05", "R06", "R07", "R09", "HR"], "R09": ["R03", "R05", "R08"],
	"R10": ["R02", "R03"], "R11": ["R01", "R07"], "HR": ["R02", "R03", "R04", "R06", "R07", "R08"],
}
## 세력 · 정착지 근거지 권역(SD-06 §2 표 · §3.2.2)
const HOME := {
	"BJ": "R11", "YH": "R06", "WP": "R09", "SB": "R02", "JG": "R09", "JH": "R02", "GS": "R01", "JC": "HR", "KD": "R05",
	"NJ": "R03", "NS": "R06", "HS": "R08",
	"JC_ND": "HR", "JC_TK": "R03", "JC_BC": "R01", "JC_SY": "R04", "JC_TS": "R08", "JC_SV": "R07", "JC_SA": "R01",
	"JC_MW": "R04", "JC_IT": "R06", "JC_YJ": "R11", "JC_AC": "R08", "JC_CD": "R09",
}
const FAC_NAME := {"BJ": "비상정부", "YH": "연합단", "WP": "원칙파", "SB": "새벽인력", "JG": "잔존병", "JH": "지하시장", "GS": "각성회",
	"JC": "정착지 연합", "KD": "큰돌 무리", "NJ": "난지 고철단", "NS": "남산 방송", "HS": "행상 조합",
	"JC_ND": "노들섬", "JC_TK": "탱크마을", "JC_BC": "봉천", "JC_SY": "선유도", "JC_TS": "뚝섬 장터", "JC_SV": "세이프빌",
	"JC_SA": "사당 환승촌", "JC_MW": "망원 유수지", "JC_IT": "이태원 피난촌", "JC_YJ": "양재 온실촌", "JC_AC": "아차산 배수지", "JC_CD": "창동 차량기지촌"}

var list: Array = []                               ## 기록: {"id", "kind", "region", "place", "at", "pub", "attr", "about", "fx": {세력: 변화}, "known": {세력: 도착 분}, "tag", "what", "news"}
var heard: Array = []                              ## 들은 소식(최근 30): {"fac", "what", "at", "route"}
var seq := 0
var kills := {}                                    ## 범죄(1-X, Crimes): 대상별 살해 수(학살 판정)
var grudge := {}                                   ## 대상 → 1 원한(시간 회복 정지) · 2 영구 적대(−100 고정)
var bodies: Array = []                             ## 목격 없는 살해의 시체: {"id", "tgt", "at", "find", "solve", "perm", "named", "region", "place"}
var mourn := {}                                    ## 대상 → 죽음을 안 분(장례 · 수군거림)
var known_killer := {}                             ## 인물 ID → true: 주인공이 죽인 것을 그 대상이 안다
var victims := {}                                  ## 인물 ID → true: 주인공이 죽인 사람(아무도 몰라도 — 자백 판정용, 1-X)
var last := 0                                      ## 마지막으로 처리한 게임 분


static func dist(a: String, b: String) -> int:
	if a == b:
		return 0
	var seen := {a: 0}
	var q: Array = [a]
	while not q.is_empty():
		var c: String = q.pop_front()
		for n in ADJ.get(c, []):
			if not seen.has(n):
				seen[n] = int(seen[c]) + 1
				if n == b:
					return int(seen[n])
				q.append(n)
	return 99


## 기록 하나. fx = {"JC": -3, "JC_BC": 0} — 0은 '알게 되는 것'만(후속 hook용). seen_by = 직접 목격한 세력(즉시 반영)
func record(st: StoryState, kind: String, region: String, pub: int, fx: Dictionary, now: int, opt := {}) -> Dictionary:
	seq += 1
	var d := {"id": "D%d" % seq, "kind": kind, "region": region, "place": str(opt.get("place", "")), "at": now, "pub": pub,
		"attr": str(opt.get("attr", "player")), "about": opt.get("about", []), "fx": fx.duplicate(), "known": {}, "tag": str(opt.get("tag", "")),
		"what": str(opt.get("what", kind)), "news": false}
	list.append(d)
	for f in opt.get("seen_by", []):
		_arrive(st, d, str(f), now, "목격")
	return d


## 지금 시각까지 도착한 소식을 시각 순서대로 반영한다(호스트가 시간이 흐를 때마다 부른다)
func tick(st: StoryState, now: int) -> void:
	if now <= 0:
		return
	if last == 0:
		last = now
	_broadcasts(now)
	var found := bodies.filter(func(b): return int(b["find"]) <= now)   # 시체 발견(SD-06 §6.4)을 먼저 — 그 기록도 이번 tick 안에 닿는다
	found.sort_custom(func(x, y): return int(x["find"]) < int(y["find"]))
	bodies = bodies.filter(func(b): return int(b["find"]) > now)
	for b in found:
		Crimes.find_body(st, b, int(b["find"]))
	var evs: Array = []                                                # [도착 분, 기록, 세력, 경로]
	for d in list:
		for f in (d["fx"] as Dictionary).keys():
			if (d["known"] as Dictionary).has(f):
				continue
			var a := arrival(d, str(f))
			if a.size() == 2 and int(a[0]) <= now:
				evs.append([int(a[0]), d, str(f), str(a[1])])
	evs.sort_custom(func(x, y): return int(x[0]) < int(y[0]))
	for e in evs:
		_arrive(st, e[1], e[2], int(e[0]), e[3])
	list = list.filter(func(d): return not _done(d, now))
	last = now


## 세력 f에 이 기록이 닿는 가장 이른 [분, 경로] — 닿지 않으면 []
func arrival(d: Dictionary, f: String) -> Array:
	var best: Array = []
	var at := int(d["at"])
	var pub := int(d["pub"])
	if pub >= 2:                                                       # 소문
		var k := dist(str(d["region"]), str(HOME.get(f, "")))
		if k <= 2:
			var h := RUMOR_H * (k + 1) + (24 if str(d["region"]) == "R05" else 0)
			best = _min(best, [at + h * 60, "소문"])
	if f == "BJ" and pub >= 1 and str(d["place"]) in INFORMANT:          # 정보원
		best = _min(best, [at + 6 * 60, "정보원"])
	if bool(d["news"]):                                                # 남산 · 공보 정시 방송(이미 방송된 기록)
		best = _min(best, [int(d["news_at"]), str(d["news_by"])])
	return best


static func _min(a: Array, b: Array) -> Array:
	return b if a.is_empty() or int(b[0]) < int(a[0]) else a


static func next_slot(at: int) -> int:
	return (at / SLOT + 1) * SLOT


## 정시 방송: 공개도 3 전부, 공개도 2는 슬롯마다 한 건(오래된 순). 비상정부가 관련된 공개도 2 이상은 공보방송이 다음 정시에
func _broadcasts(now: int) -> void:
	var slot := next_slot(last)
	var by_at := list.duplicate()
	by_at.sort_custom(func(x, y): return int(x["at"]) < int(y["at"]))   # 오래된 순
	var guard := 0
	while slot <= now and guard < 400:
		guard += 1
		var took2 := false
		for d in by_at:
			if bool(d["news"]) or int(d["at"]) >= slot:
				continue
			var pub := int(d["pub"])
			var by := ""
			if pub >= 3:
				by = "남산 방송"
			elif pub == 2 and "BJ" in d["about"]:
				by = "공보방송"
			elif pub == 2 and not took2:
				by = "남산 방송"
				took2 = true
			if by != "":
				d["news"] = true
				d["news_at"] = slot
				d["news_by"] = by
		slot += SLOT


func _arrive(st: StoryState, d: Dictionary, f: String, when: int, route: String) -> void:
	if (d["known"] as Dictionary).has(f):
		return
	d["known"][f] = when
	var dv := int(d["fx"].get(f, 0))
	if dv != 0 and str(d["attr"]) == "player":
		st.call_fn("aff", [f, dv])
	elif dv != 0 and str(d["attr"]) == "unknown":                      # 귀속 불명(보도 자제 · 변장): 연동 절반(§6.5)
		st.call_fn("aff", [f, int(dv / 2)])
	heard.push_front({"fac": f, "what": str(d["what"]), "at": when, "route": route, "tag": str(d["tag"])})
	while heard.size() > 30:
		heard.pop_back()
	_hook(st, d, f)


## 기록별 후속(SD-20 이월): 걸어 들어감(MQ-106 결과 4) 소문이 봉천에 닿으면 봉천 사람들이 하루 동안 수군거린다(N8 세계 반응)
func _hook(st: StoryState, d: Dictionary, f: String) -> void:
	if str(d["tag"]).begins_with("CRIME") and str(d["tag"]) != "CRIME_BODY":
		for a in d.get("about", []):
			known_killer[st.canon(str(a))] = true
	match str(d["tag"]):
		"CRIME_PERM":                                                  # 지도자 · 대표 살해 · 학살: 값 −100 고정, 영구 적대(SD-06 §3.5 강제 사건 · §3.8)
			grudge[f] = 2
			var k := "AFF_" + f
			if st.vars.has(k):
				st.vars.set_v(k, -100)
				st.events.append({"kind": "aff", "key": k, "delta": 0, "value": -100})
		"MQ106_WALK":
			if f == "JC_BC" and st.vars.has("BC_DOUBT_DAY"):
				st.vars.set_v("BC_DOUBT_DAY", int(st.vars.get_v("GAME_DAY")) + 1)


func _done(d: Dictionary, now: int) -> bool:
	var all := true
	for f in d["fx"]:
		all = all and (d["known"] as Dictionary).has(f)
	if all:
		return true
	if (d["known"] as Dictionary).is_empty() and not bool(d["news"]) and now - int(d["at"]) > EXPIRE:
		return true                                                    # 퍼지지 않은 기록은 7일 뒤 사라진다
	return false


## 꼬리표 tag 기록을 세력 f에 지금 닿게 한다(그 자리에서 본 일 — 물이 다시 흐르는 마을에 돌아왔다, 1-11b). 이미 닿았으면 그대로
func tell(st: StoryState, tag: String, f: String, now: int, route := "목격") -> void:
	for d in list:
		if str(d["tag"]) == tag and (d["fx"] as Dictionary).has(f):
			_arrive(st, d, f, now, route)


## 세력 f가 그 꼬리표의 일을 아는가(대사 조건 · 시험)
func knows(f: String, tag: String) -> bool:
	for h in heard:
		if str(h["fac"]) == f and str(h["tag"]) == tag:
			return true
	return false


func to_dict() -> Dictionary:
	return {"list": list.duplicate(true), "heard": heard.duplicate(true), "seq": seq, "last": last, "kills": kills.duplicate(),
		"grudge": grudge.duplicate(), "bodies": bodies.duplicate(true), "mourn": mourn.duplicate(), "known_killer": known_killer.keys(), "victims": victims.keys()}


func from_dict(dd: Dictionary) -> void:
	list = []
	for d in dd.get("list", []):
		var x: Dictionary = (d as Dictionary).duplicate(true)
		for k in ["at", "pub", "news_at"]:
			if x.has(k):
				x[k] = int(x[k])
		var kn := {}
		for f in x.get("known", {}):
			kn[str(f)] = int(x["known"][f])
		x["known"] = kn
		var fx := {}
		for f in x.get("fx", {}):
			fx[str(f)] = int(x["fx"][f])
		x["fx"] = fx
		list.append(x)
	heard = []
	for h in dd.get("heard", []):
		var y: Dictionary = (h as Dictionary).duplicate()
		y["at"] = int(y.get("at", 0))
		heard.append(y)
	seq = int(dd.get("seq", 0))
	last = int(dd.get("last", 0))
	kills = {}
	for k in dd.get("kills", {}):
		kills[str(k)] = int(dd["kills"][k])
	grudge = {}
	for k in dd.get("grudge", {}):
		grudge[str(k)] = int(dd["grudge"][k])
	bodies = []
	for b in dd.get("bodies", []):
		var z: Dictionary = (b as Dictionary).duplicate()
		for k in ["at", "find"]:
			z[k] = int(z.get(k, 0))
		bodies.append(z)
	mourn = {}
	for k in dd.get("mourn", {}):
		mourn[str(k)] = int(dd["mourn"][k])
	known_killer = {}
	for k in dd.get("known_killer", []):
		known_killer[str(k)] = true
	victims = {}
	for k in dd.get("victims", []):
		victims[str(k)] = true
