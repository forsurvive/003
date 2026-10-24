## 명중·피해 공식 (SD-11 §4). 엔진 무관 순수 모듈: 입력·출력은 숫자·Dictionary뿐(SD-19 §6.1).
## 난수는 호출하는 쪽이 RandomNumberGenerator를 넘긴다(저장·재현이 같아지도록, 시드 고정 가능).
class_name CombatRules
extends RefCounted

const STANCE := {"stand": 1.0, "crouch": 0.7, "aim": 0.5, "crouch_aim": 0.35, "heavy_aim": 0.75}
const COND_SPREAD := {"new": 1.0, "good": 1.0, "worn": 1.2, "poor": 1.5}
const COND_DMG_RANGED := {"new": 1.0, "good": 0.87, "worn": 0.79, "poor": 0.70}
const COND_DMG_MELEE := {"new": 1.0, "good": 0.82, "worn": 0.69, "poor": 0.57}
const COND_CRIT := {"new": 1.0, "good": 0.65, "worn": 0.4, "poor": 0.15}
const DR_CAP := 85.0
const PART_MULT := {"head": 2.0, "torso": 1.0, "arm": 1.0, "leg": 1.0, "weapon": 0.0}
const PART_HP := {"head": 0.25, "torso": 0.5, "arm": 0.3, "leg": 0.3, "antenna": 0.1}   ## 더듬이(곤충 특수 부위, SD-11 §4.8 표 — 계수는 1-D5b 정합: 가는 부위 0.1)
const HUMANOID_WEIGHTS := {"head": 12, "torso": 48, "arm": 20, "leg": 20}


## §4.1 총 퍼짐(반각, 도) = max(조준 퍼짐, 무기 최소 퍼짐)
static func spread(skill: float, stance: String = "stand", moving: bool = false, condition: String = "new",
		perk_mult: float = 1.0, limb_add: float = 0.0, recoil: float = 0.0, weapon_min: float = 1.0) -> float:
	var aim: float = 24.0 * (0.5 - 0.005 * skill) * STANCE[stance] * (1.25 if moving else 1.0) \
		* COND_SPREAD[condition] * perk_mult + limb_add + recoil
	return maxf(aim, weapon_min)


## 발사 각도 = 조준 각도 + (u1 + u2 − 1) × 총 퍼짐  (삼각 분포)
static func shot_angle(aim_deg: float, total_spread: float, rng: RandomNumberGenerator) -> float:
	return aim_deg + (rng.randf() + rng.randf() - 1.0) * total_spread


## 정지 표적 명중 기대치: 삼각 분포에서 |오차| < atan(r / d) 일 확률 (§4.1 참고표의 계산식)
static func hit_probability(total_spread: float, dist_tiles: float, radius_tiles: float = 0.3) -> float:
	var a := rad_to_deg(atan(radius_tiles / dist_tiles))
	if a >= total_spread:
		return 1.0
	return 1.0 - pow(1.0 - a / total_spread, 2.0)


## §4.5 기본 피해 Dam. w = {dmg, kind: "ranged"|"melee"|"unarmed", condition, range_eff, range_max, falloff_min}
static func base_damage(w: Dictionary, skill: float, attacker: Dictionary = {}, power: bool = false,
		dist: float = 0.0, arm_crippled: bool = false) -> float:
	var kind: String = w.get("kind", "ranged")
	var cond: String = w.get("condition", "new")
	var cond_k: float = (COND_DMG_RANGED if kind == "ranged" else COND_DMG_MELEE)[cond]
	var dmg: float = w["dmg"]
	if arm_crippled and kind != "ranged":
		dmg *= 0.7 if w.get("hands", 1) == 1 else 0.8
	var p := 2.0 if power and kind != "ranged" else 1.0
	var bonus := 0.0
	if kind == "melee":
		bonus = ceilf(attacker.get("str", 5) / 2.0)
	elif kind == "unarmed":
		bonus = ceilf((10.0 + attacker.get("unarmed", 0)) / 20.0)
	var dam := dmg * (100.0 + skill) / 200.0 * cond_k * p + bonus
	return dam * range_falloff(w, dist)


## 거리 감쇠: 유효 사거리 안 1.0, 최대 사거리에서 falloff_min(원거리 0.7 / 산탄 0.4), 선형
static func range_falloff(w: Dictionary, dist: float) -> float:
	var eff: float = w.get("range_eff", 0.0)
	var mx: float = w.get("range_max", 0.0)
	if eff <= 0.0 or dist <= eff or mx <= eff:
		return 1.0
	var lo: float = w.get("falloff_min", 0.7)
	return lerpf(1.0, lo, clampf((dist - eff) / (mx - eff), 0.0, 1.0))


## 치명타 확률(%) = (행운 + 퍽 가산) × 무기 치명타 배수 × 상태 치명 계수 (+15 집중 사격). 은신 기습 = 100
static func crit_chance(luck: float, crit_mult: float, condition: String = "new", perk_add: float = 0.0,
		focused: bool = false, sneak: bool = false) -> float:
	if sneak:
		return 100.0
	return (luck + perk_add) * crit_mult * COND_CRIT[condition] + (15.0 if focused else 0.0)


## 기습 배수: 원거리 2, 근접·비무장 5, 보스 상한 2
static func sneak_mult(kind: String, boss: bool) -> float:
	var m := 2.0 if kind == "ranged" else 5.0
	return minf(m, 2.0) if boss else m


## 부위 가중치 (§4.7): base(종별 표) + 상황 보정
static func part_weights(base: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var w := base.duplicate()
	if ctx.get("focused", false) and w.has("head"):
		w["head"] += 2 * ctx.get("per", 5)
		w["weapon"] = 5
	if ctx.get("sniper", false) and w.has("head"):
		w["head"] = w["head"] * 1.5
	if ctx.get("from_behind", false) and w.has("head"):
		w["head"] += 10
	if ctx.get("target_low", false) and w.has("leg"):
		w["torso"] += w["leg"]
		w["leg"] = 0
	if ctx.get("melee", false) and w.has("head"):
		if ctx.get("attacker_crouch", false):
			w["leg"] = w.get("leg", 0) + 15
			w["head"] = maxf(0, w["head"] - 8)
		else:
			w["head"] += 8
	if ctx.get("knocked_down", false):
		if w.has("leg"):
			w["torso"] += w["leg"]
			w["leg"] = 0
		if w.has("head"):
			w["head"] += 5
	return w


## 맞은 쪽이 대상의 뒤쪽 90°인가(쏜 자리 → 대상 방향이 대상이 보는 방향과 같은 쪽)
static func from_behind(target_pos: Vector2, facing: int, src: Vector2) -> bool:
	var into := (target_pos - src).normalized()
	return into.dot(Vector2(Locomotion.VEC[facing]).normalized()) > 0.7071


## 갑각(PW-D) 같은 뒤쪽 특수 부위: 뒤에서 맞으면 back_part [옮길 부위, 새 부위, 몫]만큼 가중을 옮긴다
static func back_weights(w: Dictionary, back: Array) -> Dictionary:
	if back.size() < 3 or not w.has(back[0]):
		return w
	var o := w.duplicate()
	var n := minf(float(back[2]), float(o[back[0]]))
	o[back[0]] = float(o[back[0]]) - n
	o[back[1]] = float(o.get(back[1], 0.0)) + n
	return o


static func pick_part(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var keys := weights.keys()
	keys.sort()                                              # deterministic order for a given seed
	var total := 0.0
	for k in keys:
		total += weights[k]
	var r := rng.randf() * total
	for k in keys:
		r -= weights[k]
		if r < 0.0:
			return k
	return keys[keys.size() - 1]


## 피해 처리 순서 (§4.4) 전체. 굴림 결과(crit, part)를 미리 정해 넘기면 결정적으로 계산한다.
## hit = {weapon, skill, attacker, power, dist, perk_mult, crit(bool), sneak(bool), boss(bool), part, dr,
##        block(0~1 감쇄), difficulty(배수)}
static func resolve(hit: Dictionary) -> Dictionary:
	var w: Dictionary = hit["weapon"]
	var dam := base_damage(w, hit.get("skill", 0.0), hit.get("attacker", {}), hit.get("power", false),
		hit.get("dist", 0.0), hit.get("arm_crippled", false))
	dam += hit.get("add", 0.0)                                         # 아이언 피스트(PK-014) 비무장 +5/랭크(1-12p)
	dam *= hit.get("perk_mult", 1.0)
	if hit.get("crit", false) or hit.get("sneak", false):
		dam += w.get("crit_dmg", 0.0) * (1.5 if hit.get("better_crits", false) else 1.0)
	if hit.get("sneak", false):
		dam *= sneak_mult(w.get("kind", "ranged"), hit.get("boss", false))
	var part: String = hit.get("part", "torso")
	dam *= hit.get("part_mult", PART_MULT.get(part, 1.0))
	var dr := minf(hit.get("dr", 0.0), DR_CAP)
	if hit.get("explosive", false):
		dr *= 0.5
	dam *= 1.0 - dr / 100.0
	dam *= 1.0 - hit.get("block", 0.0)
	dam *= hit.get("difficulty", 1.0)
	return {"hp": dam, "part": part, "limb": dam * 2.0 * w.get("limb_mult", 1.0)}


## 부위 체력 = 최대 HP × 부위 계수
static func limb_hp(max_hp: float, part: String) -> float:
	return max_hp * PART_HP.get(part, 0.3)
