## 행적 기록과 정보 전파(단계 1-10c, SD-06 §6): 세력은 주인공이 한 일을 '알게 된 뒤에' 반응한다. 행동 하나가 기록 하나 —
## 공개도(0 비밀 · 1 목격 · 2 공개 · 3 방송급) · 구역 · 시각 · 대기 효과(세력별 호감도 변화, 아직 반영 전)를 담고, 경로를 따라 퍼져
## 도착한 세력에게 그때 효과가 반영된다. 시간 도약(사흘 구금 · 긴 잠)에도 넘어간 도착을 시각 순서대로 모두 처리한다(SD-20 P6).
##   경로(§6.3): 직접 목격 = 즉시(호출하는 쪽이 seen_by로) · 정보원 = 비상정부 6시간(봉천 · 노들섬 · 세이프빌 · 양재 온실촌의 공개도 1 이상) ·
##   소문 = 같은 구역 12시간, 인접 구역마다 +12시간, 3구역까지, 공개도 2 이상(R05 발생은 +24시간) ·
##   남산 방송 = 다음 정시 뉴스(6시간 주기), 공개도 3 전부 + 공개도 2 한 건 · 공보방송 = 비상정부가 관련된 공개도 2 이상, 다음 정시.
##   행상 = 수송로 4개 위 정착지에서 난 일이 같은 수송로 정착지 · 행상 조합에 24시간(공개도 1 이상) ·
##   지하시장 정보상 = 정기 구매 세력(비상정부 · 새벽인력 · 연합단)에 공개도 1 사건의 30%를 48시간 · 용산 기지 방송 = 연합단 관련 사건을 다음 낭독(12시간 주기)에
##   연합단 · 이태원 · 남산 방송으로(1-12q). 연동 계수(§3.6)는 오른 세력의 도움 기록(LINK)이 열 세력에 닿을 때 적용(`link`).
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
## 행상 조합 수송로(SD-06 §10.17): 정착지 코드
const TRADE_ROUTES := [["ND", "IT", "TS"], ["ND", "SY", "TK"], ["BC", "SA", "ND"], ["TS", "SV", "YJ"]]
const BROKER_BUYERS := ["BJ", "SB", "YH"]           ## 지하시장 정보상 정기 구매 세력(§6.3)
const YONGSAN := ["YH", "JC_IT", "NS"]             ## 용산 기지 방송이 닿는 곳
const YONGSAN_SLOT := 720                          ## 낭독 주기(12시간)
## 연동 계수(§3.6): 오른 세력 → {영향받는 세력: 계수}. 열 JC는 모든 가맹 정착지(아래 덮어쓰기 먼저)
const LINK := {
	"BJ": {"YH": -0.5, "WP": -0.2, "SB": 0.1, "JG": -0.5, "JH": -0.3, "JC": -0.4},
	"YH": {"BJ": -0.5, "WP": -0.6, "SB": -0.4, "JG": -0.4, "GS": -0.2, "JC": 0.1, "NJ": -0.2},
	"WP": {"BJ": -0.2, "YH": -0.6, "JG": -0.3, "GS": -0.3},
	"SB": {"YH": -0.3, "JH": -0.3, "JC": -0.6, "NJ": 0.1, "KD": -0.2},
	"JG": {"BJ": -0.5, "YH": -0.4, "WP": -0.2, "GS": -0.4, "JC": -0.1},
	"JH": {"BJ": -0.3, "SB": -0.3},
	"GS": {"YH": -0.3, "WP": -0.3, "JG": -0.4},
	"JC": {"BJ": -0.3, "YH": 0.1, "SB": -0.4, "JG": -0.1, "NJ": -0.3},
	"NJ": {"YH": -0.2, "JC": -0.4},
	"KD": {"YH": -0.1, "JC": -0.1},
}
## 정착지 개별 덮어쓰기(§3.6 아래 표): [오른 쪽, 영향받는 정착지 코드(JC_ 없이), 계수]
const LINK_SETTLE := [["JH", "SV", -0.3], ["JC_SV", "BC", -0.2], ["JC_SV", "TK", -0.2], ["JC_SV", "IT", -0.2], ["JC_ND", "SY", -0.1],
	["NJ", "TK", -0.6], ["BJ", "YJ", 0.0], ["YH", "IT", 0.3], ["JG", "CD", -0.3]]
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
var seen := {}                                     ## 권역 → 주인공이 사람 눈에 띈 분들(최근 여섯 — 시체 조사 +20% — §6.4, 1-12q)
var said := {}                                     ## 주민이 이미 꺼낸 들은 소식(기록 ID:세력 → true) — 한 번만
var hushed: Array = []                             ## 입막음한 기록: {"what", "until", "to"(세력 이름들), "told"} — 정보상이 '거기까진 안 갔어'로 알려 준다
var leaks: Array = []                              ## 매수한 기록이 샐 날: {"at", "what", "region", "place", "fx", "tag", "about"}
var link_hold := 0                                 ## 0보다 크면 aff가 연동 기록을 남기지 않는다(전파 도착 · RQ · 거래 · 기부)
var link_src := 0                                  ## 원고 효과(StoryExpr.run)를 도는 중 — 자동 연동은 원고의 호감 상승에만(진행기 코드는 손으로 연동, 1-12q)


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
	var due := leaks.filter(func(l): return int(l["at"]) <= now)          # 매수한 일이 샜다(§6.5 '7일 뒤 20%')
	leaks = leaks.filter(func(l): return int(l["at"]) > now)
	for l in due:
		record(st, "범죄", str(l["region"]), 1, l["fx"], int(l["at"]), {"tag": str(l["tag"]), "place": str(l["place"]),
			"what": "%s — 입막음한 얘기가 샜다" % str(l["what"]), "about": l.get("about", [])})
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
	var pl := str(d["place"])
	if pub >= 1 and pl != "":                                          # 행상(24시간): 같은 수송로 정착지 · 행상 조합
		for r in TRADE_ROUTES:
			if pl in r and (f == "HS" or (f.begins_with("JC_") and f.substr(3) in r and f.substr(3) != pl)):   # 행상은 소식을 다른 정착지로 나른다
				best = _min(best, [at + 24 * 60, "행상"])
	if pub == 1 and f in BROKER_BUYERS and absi(hash(str(d["id"]) + ":broker")) % 10 < 3:   # 지하시장 정보상(48시간 · 30% — 기록 ID로 굴림)
		best = _min(best, [at + 48 * 60, "정보상"])
	if f in YONGSAN and ("YH" in d["about"] or (d["fx"] as Dictionary).has("YH")):        # 용산 기지 방송(다음 낭독)
		best = _min(best, [(at / YONGSAN_SLOT + 1) * YONGSAN_SLOT, "용산 기지 방송"])
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
	link_hold += 1                                                     # 도착한 효과는 다시 연동하지 않는다(연쇄 금지)
	if dv != 0 and str(d["attr"]) == "player":
		st.call_fn("aff", [f, dv])
	elif dv != 0 and str(d["attr"]) == "unknown":                      # 귀속 불명(보도 자제 · 변장): 연동 절반(§6.5)
		st.call_fn("aff", [f, int(dv / 2)])
	link_hold -= 1
	var what := str(d["what"])
	if str(d["attr"]).begins_with("other:"):                           # 정보 세탁: 다른 세력 짓으로 들린다(효과 없음)
		what = "%s — %s 짓이라더라" % [what, str(FAC_NAME.get(str(d["attr"]).substr(6), "누군가"))]
	heard.push_front({"fac": f, "what": what, "at": when, "route": route, "tag": str(d["tag"]), "id": str(d["id"]), "about": d.get("about", []).duplicate()})
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


## 연동 계수(§3.6): 세력 fac이 dv(≥ 3) 올랐다 — 영향받는 세력별 변화(0 쪽으로 버림, 0은 뺀다). 정착지는 JC 행 + 개별 덮어쓰기
static func link_fx(st, fac: String, dv: int) -> Dictionary:
	var out := {}
	if dv < 3:
		return out
	var row := "JC" if fac.begins_with("JC_") else fac
	var cols: Dictionary = (LINK.get(row, {}) as Dictionary).duplicate()
	var per := {}                                                      # 정착지별 계수(JC 열을 펼친 뒤 덮어쓰기)
	if cols.has("JC"):
		for k in HOME:
			if str(k).begins_with("JC_") and str(k) != fac:
				per[str(k)] = float(cols["JC"])
		cols.erase("JC")
	for o in LINK_SETTLE:
		if str(o[0]) == fac or str(o[0]) == row and not str(o[0]).begins_with("JC_"):
			per["JC_" + str(o[1])] = float(o[2])
	for k in per:
		cols[k] = per[k]
	for c in cols:
		if str(c) == fac or not st.vars.has("AFF_" + str(c)):
			continue
		var v := int(float(dv) * float(cols[c]))                       # int()는 0 쪽으로 버린다
		if v != 0:
			out[str(c)] = v
	return out


## 오른 세력의 도움을 행적으로(연동은 소문이 닿을 때) — StoryState aff가 부른다
func link(st, fac: String, dv: int, now: int) -> void:
	if link_hold > 0 or link_src <= 0 or now <= 0:
		return
	var fx := link_fx(st, fac, dv)
	if fx.is_empty():
		return
	record(st, "도움", str(HOME.get(fac, "R01")), 2, fx, now, {"tag": "LINK", "what": "%s 일을 거들었다는 얘기" % str(FAC_NAME.get(fac, fac)), "about": [fac]})


## 아직 다 닿지 않은 기록의 남은 도착: [{"d", "f", "at", "route"}] — 가까운 순(정보상 '누가 나를 아는가')
func pending(now: int) -> Array:
	var out: Array = []
	for d in list:
		if str(d["attr"]) != "player":
			continue
		for f in (d["fx"] as Dictionary).keys():
			if (d["known"] as Dictionary).has(f):
				continue
			var a := arrival(d, str(f))
			if a.size() == 2:
				out.append({"d": d, "f": str(f), "at": int(a[0]), "route": str(a[1])})
	out.sort_custom(func(x, y): return int(x["at"]) < int(y["at"]))
	return out


## 매수 · 세탁 대상: 주인공 귀속 · 아직 닿지 않은 곳이 남은 · 손대지 않은 기록(매수는 공개도 1만, 세탁은 1~2)
func coverable(kind: String) -> Array:
	var out: Array = []
	for d in list:
		if str(d["attr"]) != "player" or bool(d.get("covered", false)) or str(d["tag"]) == "LINK":
			continue
		var pub := int(d["pub"])
		if (kind == "hush" and pub != 1) or (kind == "launder" and (pub < 1 or pub > 2)):
			continue
		var left := false
		for f in d["fx"]:
			left = left or not (d["known"] as Dictionary).has(f)
		if left:
			out.append(d)
	return out


## 목격자 매수(§6.5 · SD-15 §5.3): 남은 도착을 끊는다. 기록 ID로 20% — 7일 뒤 샌다
func hush(d: Dictionary, now: int) -> bool:
	var cut := {}
	for f in (d["fx"] as Dictionary).keys():
		if not (d["known"] as Dictionary).has(f):
			cut[f] = int(d["fx"][f])
			(d["fx"] as Dictionary).erase(f)
	d["covered"] = true
	var until := 0
	var names: Array = []
	for f in cut:
		var a := arrival(d.merged({"fx": cut}), str(f))
		until = maxi(until, int(a[0]) if a.size() == 2 else now)
		names.append(str(FAC_NAME.get(str(f), f)))
	hushed.append({"what": str(d["what"]), "until": until, "to": names, "told": false})
	var leak := absi(hash(str(d["id"]) + ":leak")) % 100 < 20
	if leak and not cut.is_empty():
		leaks.append({"at": now + EXPIRE, "what": str(d["what"]), "region": str(d["region"]), "place": str(d["place"]), "fx": cut,
			"tag": str(d["tag"]), "about": d.get("about", [])})
	return leak


## 정보 세탁(§6.5): 남은 도착의 귀속을 다른 세력으로(효과 없이 '○○ 짓이라더라'). 돌려줌 = 발각(15% — 기록 ID 굴림)
func launder(d: Dictionary, to_fac: String) -> bool:
	d["attr"] = "other:" + to_fac
	d["covered"] = true
	return absi(hash(str(d["id"]) + ":launder")) % 100 < 15


## 사람 눈에 띄었다(대화 · 거래 — 호스트가 부른다)
func saw(region: String, now: int) -> void:
	var a: Array = seen.get(region, [])
	a.append(now)
	if a.size() > 6:
		a.pop_front()
	seen[region] = a


## 시체 조사 보정(§6.4): 그 권역에서 at 앞뒤 1시간 안에 사람 눈에 띄었나
func seen_near(region: String, at: int) -> bool:
	for x in seen.get(region, []):
		if absi(int(x) - at) <= 60:
			return true
	return false


const ROUTE_SAY := {"소문": "소문이 돌더라.", "행상": "행상이 그러더라.", "남산 방송": "방송에서 들었어.", "공보방송": "공보방송에 나오더라.",
	"정보원": "위에서 그러더라.", "정보상": "지하시장 쪽에서 흘러나왔대.", "용산 기지 방송": "용산 방송에서 들었어.", "목격": "본 사람이 있어."}


## 주민 한 마디(재미 검수 ① — P7 출처): 그 정착지 · 세력에 닿은 연동 소식 · 샌 입막음을 다음 대화에서 한 번. 사흘 지난 소식은 꺼내지 않는다
func gossip(fac: String, now: int) -> String:
	for h in heard:
		if str(h["fac"]) != fac or now - int(h["at"]) > 3 * 1440:
			continue
		var k := "%s:%s" % [str(h.get("id", "")), fac]
		if said.has(k):
			continue
		var tag := str(h["tag"])
		if tag == "LINK" and not (h.get("about", []) as Array).is_empty():
			said[k] = true
			return "%s 일 거들었다며? %s" % [str(FAC_NAME.get(str(h["about"][0]), "남의")), str(ROUTE_SAY.get(str(h["route"]), "소문이 돌더라."))]
		if str(h["what"]).ends_with("입막음한 얘기가 샜다"):
			said[k] = true
			return "다 덮은 줄 알았지? 그 얘기, 여기까지 다 돌았어."
	return ""


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
		"grudge": grudge.duplicate(), "bodies": bodies.duplicate(true), "mourn": mourn.duplicate(), "known_killer": known_killer.keys(), "victims": victims.keys(),
		"seen": seen.duplicate(true), "leaks": leaks.duplicate(true),
		"said": said.keys(), "hushed": hushed.duplicate(true)}


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
	seen = {}
	for k in dd.get("seen", {}):
		var v = dd["seen"][k]
		seen[str(k)] = (v as Array).map(func(x): return int(x)) if v is Array else [int(v)]
	said = {}
	for k in dd.get("said", []):
		said[str(k)] = true
	hushed = []
	for hh in dd.get("hushed", []):
		var hd: Dictionary = (hh as Dictionary).duplicate(true)
		hd["until"] = int(hd.get("until", 0))
		hushed.append(hd)
	leaks = []
	for l in dd.get("leaks", []):
		var lk: Dictionary = (l as Dictionary).duplicate(true)
		lk["at"] = int(lk.get("at", 0))
		leaks.append(lk)
