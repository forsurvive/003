## 반복 퀘스트(RQ) 공통 엔진(단계 1-12j, SD-05 §4.1 · SD-06 §3.4 · D-238). 사실은 변수 한 곳(P1):
##   전역 RQ_WK(주 번호) · RQ_WKCAPS(이번 주 RQ 캡 합) · RQ_LEAN(연성 상한 넘김 — 의뢰처 대사)
##   RQ별 <RQnn_>T 누적 · WK 이번 주 회차 · WKNO 그 주 번호 · XP 누적 XP · DAY 마지막 날 · DAYN 그날 횟수 · LAST 마지막 완료 날
##   세력별 RQF_<fac>_T 누적(단골 보너스 · 단계) · RQF_<fac>_ADAY/ASUM(그날 RQ로 오른 호감 합 — 일일 상승 상한 +6은 RQ 몫만, D-340)
## 규칙: 회차 곡선 1~3 100% · 4~5 75% · 6~ 50%(캡 · XP만, fixed 제외) / 주간 캡 연성 상한 1,200 넘으면 ×0.5 + lean /
##   XP 누적 RQ별 500 / 회당 호감 +2(같은 날 두 번째 ×0.5 · 세 번째 0) / 같은 세력 누적 5회마다 +3 + 공개도 2 행적(연동은 전파가 맡는다) /
##   단골 단계 5 · 15 · 30(돌려줌 regular — 호칭 · 선물 · 고유 보상은 진행기 · 원고) / 행동형 누적 10회마다 opt.zone 판도 +2.
class_name Repeat
extends RefCounted

const WEEK_CAP := 1200
const XP_CAP := 500
const DAY_AFF_CAP := 6
const FACS := ["BC", "SA", "JH", "JC", "BJ", "GS", "YH"]          ## 1막에 쓰는 세력 열쇠(RQF_ 변수를 선언한 것)
const IDS := ["RQ-19", "RQ-15", "RQ-06", "RQ-08", "RQ-30", "RQ-47"]  ## 변수를 선언한 RQ(새 RQ는 여기와 script_compile ENGINE_VARS에)
## RQ별 전용 변수(진행기 몫 — 뜻은 scenes/story/rq_r01.gd 머리 주석)
const EXTRA := ["RQ08_P1", "RQ08_P2", "RQ08_P3", "RQ08_PWK", "RQ08_HAVE", "RQ30_ON", "RQ30_DAY", "RQ30_KIND", "RQ30_DIR", "RQ30_AT", "RQ30_PHASE",
	"RQ30_N", "RQ30_KILLS", "RQ30_QUIET", "RQ19_IRON", "RQ15_BOOKS"]
## 단골 보너스(+3)의 연동(SD-06 §3.6 — 1회 상승 3 × 계수를 0 쪽으로 버림 → |계수| ≥ 0.34만 ±1). 행 = 오른 세력(정착지 개별은 JC 행), 열 = 영향받는 세력
const LINK := {
	"JC": {"SB": -1}, "JH": {}, "BJ": {"YH": -1, "JG": -1, "JC": -1}, "GS": {"JG": -1},
	"YH": {"BJ": -1, "WP": -1, "SB": -1, "JG": -1}, "SB": {"JC": -1}, "NJ": {"JC": -1}, "WP": {"YH": -1}, "JG": {"BJ": -1, "YH": -1, "GS": -1}}


static func key(id: String) -> String:
	return id.replace("-", "") + "_"


static func day_of(st) -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


static func week_of(st) -> int:
	return (day_of(st) - 1) / 7 + 1


## 변수 이름 목록(선언용)
static func var_names() -> Array:
	var out := ["RQ_WK", "RQ_WKCAPS", "RQ_LEAN"]
	for id in IDS:
		for k in ["T", "WK", "WKNO", "XP", "DAY", "DAYN", "LAST"]:
			out.append(key(id) + k)
	for f in FACS:
		for k in ["T", "ADAY", "ASUM"]:
			out.append("RQF_%s_%s" % [f, k])
	out.append_array(EXTRA)
	return out


## 완료 한 번. opt: aff(회당 호감, 기본 2) · zone(행동형 판도 변수) · region(행적 권역) · now(절대 분 — 행적 시각) · what(행적 문장)
static func done(st, id: String, fac: String, caps: int, xp: int, kind := "supply", opt := {}) -> Dictionary:
	var p := key(id)
	var d := day_of(st)
	var wk := week_of(st)
	var out := {"n": 0, "wk": 0, "caps": 0, "xp": 0, "aff": 0, "regular": 0, "bonus": 0, "lean": 0, "curve": 100}
	if not st.vars.has(p + "T"):
		st.vars._err("선언 없는 RQ: " + id)
		return out
	if int(st.vars.get_v("RQ_WK")) != wk:                                 # 주가 바뀜(06:00 판정 뒤 첫 호출) — 전역 주간 값만 0
		st.vars.set_v("RQ_WK", wk)
		st.vars.set_v("RQ_WKCAPS", 0)
		st.vars.set_v("RQ_LEAN", 0)
	if int(st.vars.get_v(p + "WKNO")) != wk:
		st.vars.set_v(p + "WKNO", wk)
		st.vars.set_v(p + "WK", 0)
	var n := int(st.vars.get_v(p + "T")) + 1
	var nwk := int(st.vars.get_v(p + "WK")) + 1
	st.vars.set_v(p + "T", n)
	st.vars.set_v(p + "WK", nwk)
	out["n"] = n
	out["wk"] = nwk
	var curve := 1.0
	if kind != "fixed":
		curve = 1.0 if nwk <= 3 else (0.75 if nwk <= 5 else 0.5)
	out["curve"] = int(curve * 100)
	var c := roundi(caps * curve)
	if c > 0 and int(st.vars.get_v("RQ_WKCAPS")) > WEEK_CAP:               # 연성 상한: 넘긴 뒤의 보상은 반값 — 의뢰처가 말로 알린다
		c = maxi(1, c / 2)
		out["lean"] = 1
		st.vars.set_v("RQ_LEAN", 1)
	if c > 0:
		st.call_fn("caps", [c])
		st.vars.set_v("RQ_WKCAPS", int(st.vars.get_v("RQ_WKCAPS")) + c)
	out["caps"] = c
	var x := roundi(xp * curve)
	if x > 0 and int(st.vars.get_v(p + "XP")) + x <= XP_CAP:
		st.call_fn("xp", [x])
		st.vars.set_v(p + "XP", int(st.vars.get_v(p + "XP")) + x)
		out["xp"] = x
	if fac != "":
		var dayn := int(st.vars.get_v(p + "DAYN")) if int(st.vars.get_v(p + "DAY")) == d else 0
		st.vars.set_v(p + "DAY", d)
		st.vars.set_v(p + "DAYN", dayn + 1)
		var base := int(opt.get("aff", 2))
		var aff := base if dayn == 0 else (base / 2 if dayn == 1 else 0)   # 같은 날 두 번째 ×0.5 · 세 번째부터 0(SD-06 §3.4)
		var fk := "RQF_%s_T" % fac
		var every := int(opt.get("regular_every", 1))                     # 고철 한 개짜리 의뢰는 n개마다 한 번만 단골 횟수로 센다
		if st.vars.has(fk) and n % every == 0:
			var ft := int(st.vars.get_v(fk)) + 1
			st.vars.set_v(fk, ft)
			if ft % 5 == 0:                                               # 단골 의뢰 보너스 +3 · 공개도 2 행적 — 연동(SD-06 §3.6)은 전파가 닿은 세력에 그때 적용
				aff += 3
				out["bonus"] = 1
				var fx := {}
				fx[_deed_key(st, fac)] = 0
				var row: String = "JC" if st.vars.has("AFF_JC_" + fac) else fac
				for col in LINK.get(row, {}):
					if st.vars.has("AFF_" + str(col)):
						fx[str(col)] = int(LINK[row][col])
				st.deeds.record(st, "rq_regular", str(opt.get("region", "R01")), 2, fx, int(opt.get("now", 0)),
					{"tag": "RQ_REGULAR", "what": str(opt.get("what", "단골 일꾼 — " + id)), "about": [fac]})
			for s in [5, 15, 30]:
				if ft == s:
					out["regular"] = s
		aff = _daily(st, fac, d, aff)
		if aff > 0:
			st.call_fn("aff", [fac, aff])
		out["aff"] = aff
	if kind == "act" and n % 10 == 0 and opt.has("zone") and st.vars.has(str(opt["zone"])):   # 행동형 10회째 그 구역 사건 보정 +2(SD-06 §5.3 — 7일 감쇠는 판도 틱)
		st.vars.add(str(opt["zone"]), 2)
	st.vars.set_v(p + "LAST", d)
	return out


## 그날 RQ로 오른 호감 합을 +6까지만(SD-06 §3.5 일일 상승 상한 — 다른 원천은 D-340)
static func _daily(st, fac: String, d: int, aff: int) -> int:
	var kd := "RQF_%s_ADAY" % fac
	var ks := "RQF_%s_ASUM" % fac
	if not st.vars.has(kd):
		return aff
	if int(st.vars.get_v(kd)) != d:
		st.vars.set_v(kd, d)
		st.vars.set_v(ks, 0)
	var room := DAY_AFF_CAP - int(st.vars.get_v(ks))
	var give := clampi(aff, 0, maxi(0, room))
	st.vars.set_v(ks, int(st.vars.get_v(ks)) + give)
	return give


## 행적 fx 열쇠: 정착지 개별("BC")은 "JC_BC"
static func _deed_key(st, fac: String) -> String:
	if st.vars.has("AFF_JC_" + fac):
		return "JC_" + fac
	return fac


## 다음 의뢰가 열리기까지 남은 날(주기 period일) — 0이면 지금 된다
static func wait_days(st, id: String, period: int) -> int:
	var p := key(id)
	var last := int(st.vars.get_v(p + "LAST"))
	if last <= 0:
		return 0
	return maxi(0, last + period - day_of(st))


## 이번 주 남은 횟수(주간 한도 limit) — 주가 바뀌었으면 limit
static func left_this_week(st, id: String, limit: int) -> int:
	var p := key(id)
	if int(st.vars.get_v(p + "WKNO")) != week_of(st):
		return limit
	return maxi(0, limit - int(st.vars.get_v(p + "WK")))


## 단골 단계(0 · 5 · 15 · 30)
static func stage_of(st, fac: String) -> int:
	var t := int(st.vars.get_v("RQF_%s_T" % fac)) if st.vars.has("RQF_%s_T" % fac) else 0
	return 30 if t >= 30 else (15 if t >= 15 else (5 if t >= 5 else 0))
