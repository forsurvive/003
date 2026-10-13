## 화술 판정 (SD-10 §3.5.8, SD-12 §6.3·§6.4). 순수 함수 + 판정 고정 난수.
class_name Speech
extends RefCounted

const DIFF := {"아주 쉬움": 0.018, "쉬움": 0.012, "보통": 0.009, "어려움": 0.006, "아주 어려움": 0.004}
const XP := {"아주 쉬움": 5, "쉬움": 10, "보통": 20, "어려움": 30, "아주 어려움": 50}
## 고정 요구치 판정 I~V(SD-10 §3.6): 자물쇠만 I 단계가 0
const SKILL_REQ := [15, 25, 50, 75, 100]
const LOCK_REQ := [0, 25, 50, 75, 100]
const STAT_REQ := [4, 5, 6, 7, 8]


## 성공 확률 0..1. 0.9 이상이면 1(확정).
## cha: 카리스마, weapon_out: 무기를 꺼냈는가, target_aff: NPC 기본 호감(0~100), faction_aff: 소속 세력 호감도(-100~100),
## responsibility: 대상 책임감(0~100), karma: 플레이어 카르마(-1000~1000), speech: 화술 스킬, diff: 난이도 이름
static func chance(cha: int, weapon_out: bool, target_aff: float, faction_aff: float, responsibility: float, karma: float,
		speech: int, diff: String) -> float:
	var cha_term := float(cha - (1 if weapon_out else 0) + 2) / 10.0
	var aff := target_aff + faction_aff * 0.25
	var karma_term := (aff + (responsibility - 50.0) * karma / 500.0) / 100.0
	var p := (cha_term + karma_term) * float(speech) * float(DIFF.get(diff, 0.009))
	if p >= 0.9:
		return 1.0
	return clampf(p, 0.0, 1.0)


## 표시값: 정수 반올림(SD-12 §6.3)
static func percent(p: float) -> int:
	return int(round(p * 100.0))


## 판정 고정(SD-10 §3.5.8): 게임 시작 때 정한 씨앗 + 판정 ID로 0..1 값을 고정한다. 같은 조건이면 다시 해도 같은 결과.
static func roll(seed: int, check_id: String) -> float:
	var h := hash(str(seed) + "|" + check_id)
	return float(h & 0xFFFFFF) / float(0x1000000)


## 초기 스킬값(SD-10 §3.3): 2 + 연관 능력치 × 2 + ⌈행운/2⌉
static func base_skill(stat: int, luck: int) -> int:
	return 2 + stat * 2 + int(ceil(luck / 2.0))
