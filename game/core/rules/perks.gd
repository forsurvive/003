## 퍽(단계 1-12p, SD-10 §5 · 계획 `_plans/1-12p_levelup_perks_plan.md`): 퍽 자료(data/perks.json — SD-10 §5.2 표 그대로) · 랭크 · 고를 수 있나 · 효과 수치.
##   사실은 변수 한 곳(P1): 랭크 = PK_xxx(PK-045 → PK_045). 퀘스트가 주는 특별 퍽(PK-103~)도 같은 칸.
##   **효과가 실제로 들어간 퍽만 고를 수 있다**(IMPL) — 반쪽 효과로 플레이어를 속이지 않는다. 나머지는 효과가 들어갈 때 연다(장부 D-370~).
##   퍽 카드 글(맛 한 줄 · 효과 한 줄)은 원고 script/world/perks.txt → perks.json의 line · card(다듬이 검수). 기획서 effect 열은 자료로만 둔다.
class_name Perks
extends RefCounted

const CAP_LV := 35                                    ## 레벨 상한(SD-10 §4.1 결정)
## 1차로 효과가 들어간 일반 퍽(레벨업으로 고를 수 있다)
const IMPL := ["PK-002", "PK-003", "PK-004", "PK-005", "PK-006", "PK-007", "PK-008", "PK-009", "PK-012", "PK-013", "PK-014", "PK-015",
	"PK-020", "PK-024", "PK-025", "PK-026", "PK-028", "PK-033", "PK-035", "PK-036", "PK-045", "PK-046", "PK-047", "PK-058", "PK-059",
	"PK-076", "PK-077", "PK-092", "PK-093", "PK-094", "PK-095", "PK-098", "PK-100", "PK-102"]
## 랭크당 스킬 +(오버시어의 아이 · 건 넛 · 체육 특기생 · 시프 · 스카운드럴 · 사이즈 매터스)
const SKILL_PLUS := {"PK-002": {"SCIENCE": 5, "MEDICINE": 5}, "PK-003": {"SMALL_GUNS": 5, "REPAIR": 5}, "PK-005": {"MELEE": 5, "EXPLOSIVES": 5},
	"PK-007": {"SNEAK": 5, "LOCKPICK": 5}, "PK-015": {"SPEECH": 5, "BARTER": 5}, "PK-035": {"BIG_GUNS": 15}}
## 애니멀 프렌드(PK-045) 대상: 변이 들개 · 멧돼지 · 반달가슴곰 · 시궁쥐 · 두 머리 한우 계열(SD-14 — 권역 변종 CR-6xx 포함).
##   경비견 CR-107(약탈자가 부리는 개) · 정착지 진돗개 CR-108 · 외눈 CR-500(SQ-S01이 따로 다룬다)은 빠진다
const ANIMALS := ["CR-095", "CR-096", "CR-097", "CR-100", "CR-101", "CR-102", "CR-104", "CR-105", "CR-106", "CR-109", "CR-110", "CR-111",
	"CR-090", "CR-600", "CR-601", "CR-604", "CR-605", "CR-606", "CR-617", "CR-619", "CR-622"]
## 엔토몰로지스트(PK-013) 대상: 변이 곤충 · 절지동물(바퀴 · 러브버그 · 하루살이 · 모기 · 왕지네 · 말벌 · 개미 — SD-14 CR-001~088 · 변종 · 우두머리)
const INSECT_EXTRA := ["CR-501", "CR-502", "CR-503", "CR-602", "CR-603", "CR-607", "CR-614", "CR-620"]
const STAT_NAMES := {"ST": "힘", "PE": "인지력", "EN": "지구력", "CH": "카리스마", "IN": "지능", "AG": "민첩성", "LK": "행운"}

static var db := {}
static var _food := {}
static var _cooked := {}


static func load_db() -> void:
	if not db.is_empty():
		return
	var p := "res://data/perks.json"
	if FileAccess.file_exists(p):
		db = (JSON.parse_string(FileAccess.get_file_as_string(p)) as Dictionary).get("perks", {})
	for f in ["res://data/items_food.json"]:
		if FileAccess.file_exists(f):
			for k in (JSON.parse_string(FileAccess.get_file_as_string(f)) as Dictionary):
				_food[str(k).get_slice("+", 0)] = true
	if FileAccess.file_exists("res://data/recipes.json"):
		var rc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
		for k in rc:
			if bool(rc[k].get("cook", false)) or str(rc[k].get("kind", "")) == "food":
				_cooked[str(rc[k].get("out", k))] = true


static func var_of(id: String) -> String:
	return "PK_" + id.substr(3)


static func rank(st, id: String) -> int:
	var k := var_of(id)
	return int(st.vars.get_v(k)) if st != null and st.vars.has(k) else 0


static func perk_name(id: String) -> String:
	load_db()
	return str(db.get(id, {}).get("name", id))


# ---------------------------------------------------------------- 레벨
## 레벨(SD-10 §4.2 · §4.3): 누적 XP (L−1)(50 + 75L), 상한 35
static func level_of(xp: int) -> int:
	var lv := 1
	while lv < CAP_LV and xp >= lv * (50 + 75 * (lv + 1)):
		lv += 1
	return lv


static func xp_at(lv: int) -> int:
	return (lv - 1) * (50 + 75 * lv)


static func level(st) -> int:
	return level_of(int(st.vars.get_v("PC_XP")))


## 아직 배분하지 않은 레벨 수(PC_LV_DONE = 배분을 마친 레벨 — 옛 저장은 1이라 쌓인 레벨 모두 미배분)
static func pending(st) -> int:
	return maxi(0, level(st) - maxi(1, int(st.vars.get_v("PC_LV_DONE"))))


## 이번 레벨 스킬 포인트(§4.2): 10 + 그 순간 영구 지능(표시 1~10) + 에듀케이티드 3
static func skill_points(st) -> int:
	return 10 + clampi(st.stat_base("IN"), 1, 10) + (3 if rank(st, "PK-012") > 0 else 0)


# ---------------------------------------------------------------- 고를 수 있나(§5.1: 레벨 · 영구 능력치 · 영구 스킬 · 카르마 구간 · 랭크)
## 모자란 것 목록(비면 고를 수 있다). lv = 지금 배분하는 레벨
static func lacks(st, id: String, lv: int) -> Array:
	load_db()
	var p: Dictionary = db.get(id, {})
	var out: Array = []
	if p.is_empty():
		return ["자료 없음"]
	if rank(st, id) >= int(p.get("ranks", 1)):
		return ["랭크를 다 올렸다"]
	if lv < int(p.get("lv", 2)):
		out.append("레벨 %d" % int(p["lv"]))
	var sts: Dictionary = p.get("stats", {})
	for c in sts:
		if clampi(st.stat_base(str(c)), 1, 10) < int(sts[c]):
			out.append("%s %d" % [STAT_NAMES.get(str(c), str(c)), int(sts[c])])
	var sks: Dictionary = p.get("skills", {})
	for k in sks:
		if st.skill_perm(str(k)) < int(sks[k]):
			out.append("%s %d" % [StoryState.SKILLS[str(k)][0], int(sks[k])])
	var karma := int(st.vars.get_v("V_KARMA")) if st.vars.has("V_KARMA") else 0
	if p.has("karma_min") and karma < int(p["karma_min"]):
		out.append("카르마 매우 악함이 아닐 것" if int(p["karma_min"]) == -749 else "카르마 %+d 이상" % int(p["karma_min"]))
	if p.has("karma_max") and karma > int(p["karma_max"]):
		out.append("카르마 매우 선함이 아닐 것" if int(p["karma_max"]) == 749 else "카르마 %+d 이하" % int(p["karma_max"]))
	if bool(p.get("karma_not_neutral", false)) and absi(karma) <= 249:
		out.append("카르마 중립이 아닐 것")
	if id == "PK-047" and lv >= 34:
		out.append("레벨 33 이하")
	if id == "PK-004" and _stats_full(st):
		out.append("더 올릴 능력치가 없다")
	return out


static func _stats_full(st) -> bool:
	for c in STAT_NAMES:
		if st.stat_raw(c) < 10:
			return false
	return true


## 레벨업 퍽 목록: 효과가 들어간 일반 퍽(IMPL) — 레벨 순 · 같은 레벨은 번호 순
static func choices() -> Array:
	load_db()
	var ids := IMPL.duplicate()
	ids.sort_custom(func(a, b): return [int(db.get(a, {}).get("lv", 0)), a] < [int(db.get(b, {}).get("lv", 0)), b])
	return ids


## 가진 퍽(랭크 1 이상): 일반 · 특별 · 비기 모두
static func owned(st) -> Array:
	load_db()
	var out: Array = []
	for i in range(1, 120):
		var id := "PK-%03d" % i
		if rank(st, id) > 0:
			out.append(id)
	return out


# ---------------------------------------------------------------- 효과(1차 — 읽는 곳은 각 체계, 수치는 여기 한 곳)
static func skill_bonus(st, skill_key: String) -> int:
	var n := 0
	for id in SKILL_PLUS:
		var r := rank(st, id)
		if r > 0:
			n += int((SKILL_PLUS[id] as Dictionary).get(skill_key, 0)) * r
	return n


static func hp_bonus(st) -> float:
	return 30.0 if rank(st, "PK-059") > 0 else 0.0


static func ap_bonus(st) -> float:
	return 25.0 if rank(st, "PK-076") > 0 else 0.0


static func carry_bonus(st) -> float:
	return (50.0 if rank(st, "PK-036") > 0 else 0.0) + (25.0 if rank(st, "PK-028") > 0 else 0.0)


## 터프니스(PK-025): DR +10(영구 DR 퍽 합계 상한 +20 — §5.1 · 터프니스 + 사이보그만)
static func dr_bonus(st) -> float:
	return 10.0 if rank(st, "PK-025") > 0 else 0.0


static func rad_res_bonus(st) -> float:
	return 25.0 if rank(st, "PK-033") > 0 else 0.0


static func stim_mult(st) -> float:
	return 1.2 if rank(st, "PK-058") > 0 else 1.0


## 너브스 오브 스틸(PK-098): AP 회복 초당 8 → 10
static func ap_regen_mult(st) -> float:
	return 10.0 / 8.0 if rank(st, "PK-098") > 0 else 1.0


## 배달 기사(PK-028): 질주 AP 소모 ×0.7
static func sprint_mult(st) -> float:
	return 0.7 if rank(st, "PK-028") > 0 else 1.0


## 배달 기사(PK-028): 과적 감속 절반 — 과적 구르기 AP ×2 → ×1.5 · 거리 ×0.6 → ×0.8
static func overload_soft(st) -> bool:
	return rank(st, "PK-028") > 0


## 스위프트 러너(PK-006): 모든 XP +10%/랭크
static func xp_mult(st) -> float:
	return 1.0 + 0.1 * rank(st, "PK-006")


## 주인공이 낸 피해 배수: 블러디 메스 +5% · 엔토몰로지스트(곤충 · 절지동물) +50%
static func dmg_mult(st, target_id: String = "") -> float:
	var m := 1.05 if rank(st, "PK-020") > 0 else 1.0
	if target_id != "" and rank(st, "PK-013") > 0 and insect(target_id):
		m *= 1.5
	return m


## 아이언 피스트(PK-014): 비무장 피해 +5/랭크
static func unarmed_add(st) -> float:
	return 5.0 * rank(st, "PK-014")


## 피네스(PK-046): 치명타 확률 +5(행운 +5 상당 — 무기 배수가 곱해진다)
static func crit_add(st) -> float:
	return 5.0 if rank(st, "PK-046") > 0 else 0.0


static func better_crits(st) -> bool:
	return rank(st, "PK-077") > 0


## 라드 앱소프션(PK-100): 실시간 20초(게임 10분)마다 라드 1
static func rad_absorb(st) -> bool:
	return rank(st, "PK-100") > 0


## 먹고 마실 때(손맛 PK-009 · 레드 벨리 PK-024): [HP 배수, 라드 배수]
static func eat_mult(st, id: String) -> Array:
	load_db()
	var hp := 1.0
	var rad := 1.0
	var base := id.get_slice("+", 0)
	if rank(st, "PK-009") > 0:
		if _food.has(base):
			hp = 1.3
		if _cooked.has(id) or id.contains("+"):
			rad *= 0.5
	if rank(st, "PK-024") > 0 and (base in ["I-054", "I-055", "I-056", "I-057", "I-058", "I-059"] or id.contains("+I-054") or id.contains("+I-055")):
		rad *= 0.5
	return [hp, rad]


## 먹기 알림 꼬리표: 숫자를 바꾼 퍽 이름 — '(손맛)' · '(레드 벨리)'
static func eat_tags(st, id: String, healed: bool, irradiated: bool) -> String:
	load_db()
	var base := id.get_slice("+", 0)
	var out := ""
	var water := base in ["I-054", "I-055", "I-056", "I-057", "I-058", "I-059"] or id.contains("+I-054") or id.contains("+I-055")
	if rank(st, "PK-009") > 0 and ((healed and _food.has(base)) or (irradiated and (_cooked.has(id) or id.contains("+")))):
		out += "(손맛)"
	if rank(st, "PK-024") > 0 and irradiated and water:
		out += "(레드 벨리)"
	return out


## 단골(PK-026): 같은 상인과 누적 거래액 500캡마다 한 단계(최대 3) — [구매 배수, 판매 배수, 단계]
static func regular_k(st, total: int) -> Array:
	if rank(st, "PK-026") <= 0:
		return [1.0, 1.0, 0]
	var s := mini(3, maxi(0, total) / 500)
	return [1.0 - 0.05 * s, 1.0 + 0.05 * s, s]


static func animal(enemy_id: String) -> bool:
	return enemy_id in ANIMALS


## 짐승 계열(무리 편 이름): 들개 · 쥐 · 멧돼지 · 곰 · 소
static func family(enemy_id: String) -> String:
	if enemy_id in ["CR-104", "CR-105", "CR-106", "CR-600", "CR-604"]:
		return "dog"
	if enemy_id in ["CR-095", "CR-096", "CR-097", "CR-601", "CR-605", "CR-606", "CR-622"]:
		return "rat"
	if enemy_id in ["CR-100", "CR-101", "CR-102", "CR-617", "CR-619"]:
		return "boar"
	if enemy_id in ["CR-109", "CR-110", "CR-111"]:
		return "bear"
	return "cow" if enemy_id == "CR-090" else "beast"


static func insect(enemy_id: String) -> bool:
	if enemy_id in INSECT_EXTRA:
		return true
	if not enemy_id.begins_with("CR-") or not enemy_id.substr(3).is_valid_int():
		return false
	var n := int(enemy_id.substr(3))
	return n >= 1 and n <= 88
