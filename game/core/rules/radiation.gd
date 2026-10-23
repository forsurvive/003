## 방사능(SD-11 §11.2, 단계 1-9d): 라드 누적 · 자연 감소 없음 · HP를 직접 깎지 않는다.
##   단계 200 경미(지구력 −1) · 400 심화(−2, 민첩성 −1) · 600 위험(−3, −2, 힘 −1) · 800 치명(−3, −2, −2) · 1,000 사망.
##   일시적 지구력 감소는 최대 HP를 깎지 않는다(StoryState.stat_base). 민첩성 감소는 최대 AP에, 힘 감소는 소지 한도에 그대로 반영.
##   저항 = (지구력 − 1) × 2% + 옷('방사능 저항 +N') + 약(라드-X 25 × (1 + 의학/50)% 4분 · 갑상선 방호정 15% 2분, 중복은 시간만 누적), 상한 85%.
##   피폭: 지대 안에서 0.5초마다 `선량 × 0.5 × (1 − 저항)` — 저항이 아무리 높아도 틱당 0.1은 남는다. 소수는 st.rad_acc에 모았다가 정수만 PC_RADS로.
class_name Radiation
extends RefCounted

const DOSE := {1: 1.0, 2: 3.0, 3: 8.0, 4: 25.0, 5: 80.0}            ## 구역 등급 Z1~Z5 초당 라드
const STAGE_AT := [200, 400, 600, 800, 1000]
const NAMES := ["없음", "경미한 방사능 중독", "심화된 방사능 중독", "위험한 방사능 중독", "치명적 방사능 중독", "치사"]
const SHORT := ["없음", "경미", "심화", "위험", "치명", "치사"]
const PEN := [{}, {"EN": 1}, {"EN": 2, "AG": 1}, {"EN": 3, "AG": 2, "ST": 1}, {"EN": 3, "AG": 2, "ST": 2}, {"EN": 3, "AG": 2, "ST": 2}]
const TICK := 0.5
const MIN_TICK := 0.1
const RES_CAP := 85.0
const DRUGS := {"I-003": [25.0, 240.0, true], "I-005": [15.0, 120.0, true], "I-093": [50.0, 240.0, false]}   ## [저항 %, 초, 의학 배율]
static var _res_re: RegEx


static func rads(st: StoryState) -> int:
	return int(st.vars.get_v("PC_RADS")) if st != null else 0


static func stage(r: int) -> int:
	var s := 0
	for t in STAGE_AT:
		if r >= t:
			s += 1
	return s


## 단계가 깎는 능력치(EN · AG · ST)
static func penalty(r: int, code: String) -> int:
	return int((PEN[stage(r)] as Dictionary).get(code, 0))


## 옷의 방사능 저항(%): 자료 bonus 글 '방사능 저항 +N' · '+N 방사능 저항'
static func apparel_res(item: Dictionary) -> float:
	if _res_re == null:
		_res_re = RegEx.create_from_string("방사능 저항\\s*\\+\\s*(\\d+)|\\+\\s*(\\d+)\\s*방사능 저항")
	var m := _res_re.search(str(item.get("bonus", item.get("effect", ""))))
	if m == null:
		return 0.0
	return float(m.get_string(1) if m.get_string(1) != "" else m.get_string(2))


## 지금 저항(0~0.85)
static func resist(st: StoryState, items_db: Dictionary = {}) -> float:
	if st == null:
		return 0.0
	var r := float(st.stat_base("EN") - 1) * 2.0
	if not items_db.is_empty():
		r += apparel_res(items_db.get(Gear.base(str(st.vars.get_v("PC_TORSO"))), {}))
	if float(st.rad_drug.get("t", 0.0)) > 0.0:
		r += float(st.rad_drug.get("pct", 0.0))
	r += Perks.rad_res_bonus(st)                                          # 라드 레지스턴스(PK-033) +25%(1-12p)
	return clampf(r, 0.0, RES_CAP) / 100.0


## 약을 먹는다: 저항은 큰 쪽, 시간은 누적(SD-13 I-003 '중복 시 시간만 누적'). 반환 = 더한 저항 %
static func take_drug(st: StoryState, id: String) -> float:
	var d: Array = DRUGS.get(id, [])
	if d.is_empty():
		return 0.0
	var pct := float(d[0]) * ((1.0 + float(st.skill("MEDICINE")) / 50.0) if bool(d[2]) else 1.0)
	var t := float(st.rad_drug.get("t", 0.0))
	st.rad_drug = {"pct": maxf(pct, float(st.rad_drug.get("pct", 0.0))) if t > 0.0 else pct, "t": maxf(t, 0.0) + float(d[1]), "id": id}
	return pct


## 약 시간이 흐른다(실시간 초 · 대기·수면은 게임 1시간 = 120초)
static func drug_tick(st: StoryState, dt: float) -> void:
	if st == null or float(st.rad_drug.get("t", 0.0)) <= 0.0:
		return
	st.rad_drug["t"] = float(st.rad_drug["t"]) - dt
	if float(st.rad_drug["t"]) <= 0.0:
		st.rad_drug = {}


## 0.5초 한 틱 피폭: rate(초당 라드, 저항 전) → 더한 라드(소수 포함). 정수 몫만 PC_RADS로
static func expose(st: StoryState, rate: float, res: float) -> float:
	if rate <= 0.0:
		return 0.0
	var add := maxf(MIN_TICK, rate * TICK * (1.0 - res))
	st.rad_acc += add
	var whole := floori(st.rad_acc)
	if whole > 0:
		st.rad_acc -= whole
		st.vars.set_v("PC_RADS", rads(st) + whole)
	return add


## 라드를 뺀다(라드어웨이 · 의사): 모아 둔 소수도 버린다
static func remove(st: StoryState, n: int) -> void:
	st.vars.set_v("PC_RADS", maxi(0, rads(st) - n))
	st.rad_acc = 0.0


## 선량계 단계(가이거 소리 SE-ENV-GEI-1~5 · 바늘): 저항 뒤 초당 라드
static func geiger_level(rate: float) -> int:
	if rate <= 0.0:
		return 0
	if rate < 1.5:
		return 1
	if rate < 5.0:
		return 2
	if rate < 12.0:
		return 3
	if rate < 40.0:
		return 4
	return 5
