## 적 AI 속성(SD-14 §12.1 AI 유형 · SD-11 §7.1 속성 · §7.5 사기 · §7.8 세력별 패턴, 단계 1-9e).
## SD-14 개체 표에는 AI 유형 열이 없어 계열 절('행동 패턴 (AI-nn …)')과 §7.8 표로 여기서 묶는다(구현 정합 SD-11 §7.5).
##   conf 자신감 0 겁쟁이 ~ 4 무모 · surr 항복 확률(궁지 · 다리 손상 때 굴림, 0 = 항복 안 함) · react 반응 지연 · drug 약물 광란(약탈자)
##   leader 분대장(살아 있으면 분대 자신감 +1, 죽으면 −1) · pack_lead 무리 우두머리(죽으면 무리 50% 도주) · support 지원성(경보 전파)
## 이야기 인물(이름표 who · 못 이기는 적 hp_floor · 이름 있는 CR-513 · CR-534)과 프롤로그 보안요원은 도주 · 항복하지 않는다(SD-20 P3 · P4).
class_name EnemyTraits
extends RefCounted

const AI := {
	"AI-01": {"conf": 1, "support": 0, "react": 0.4},     # 겁쟁이 해충(큰바퀴 — 볼트 판본은 4)
	"AI-03": {"conf": 4, "support": 2, "react": 0.35},    # 무리 포위(들개 · 시궁쥐 · 야생 구울)
	"AI-12": {"conf": 3, "support": 2, "react": 0.35},    # 지원·호출(경비견)
	"AI-13": {"conf": 4, "support": 1, "react": 0.25},    # 규칙형 경비
	"AI-15": {"conf": 2, "support": 2, "react": 0.45},    # 분대 전술(세력별로 자신감을 덮어쓴다)
	"AI-16": {"conf": 3, "support": 2, "react": 0.3},     # 포획조
	"AI-18": {"conf": 3, "support": 2, "react": 0.35},    # 중립 영역(정착지 진돗개)
	"AI-19": {"conf": 4, "support": 2, "react": 0.25},    # 보스 · 유일 개체
}

## 개체 → AI 유형 + 덮어쓰기. 없는 ID는 인간형 AI-15 · 자신감 2
const ROWS := {
	"CR-002": {"ai": "AI-01", "conf": 4},                              # 볼트 바퀴는 4(SD-14 AI-01 '볼트 판본')
	"CR-095": {"ai": "AI-03"},
	"CR-097": {"ai": "AI-03"},                                       # 왕쥐(1-11d SQ-S03): 시궁쥐 무리의 우두머리
	"CR-136": {"ai": "AI-01", "conf": 0},                              # 옴 너구리: 보면 달아나고, 궁지에 몰리면 문다(SD-14 §4.9)
	"CR-104": {"ai": "AI-03"},
	"CR-105": {"ai": "AI-03"},
	"CR-106": {"ai": "AI-03", "pack_lead": true},
	"CR-500": {"ai": "AI-03", "pack_lead": true, "conf": 4},             # 외눈(보스, 1-11a): 쉽게 꺾이지 않는다
	"CR-107": {"ai": "AI-12"},
	"CR-108": {"ai": "AI-18"},
	"CR-200": {"ai": "AI-03"},
	"CR-201": {"ai": "AI-03"},
	"CR-401": {"ai": "AI-15", "conf": 3, "react": 0.3},                # 계엄군: 용감 3, 항복 없음(§7.8)
	"CR-402": {"ai": "AI-16", "conf": 3},
	"CR-403": {"ai": "AI-15", "conf": 3, "react": 0.3, "leader": true},
	"CR-405": {"ai": "AI-15", "conf": 4, "react": 0.3},                # 파워 아머: 못 이기는 적(도주 없음)
	"CR-420": {"ai": "AI-15", "conf": 2, "surr": 0.5, "drug": true},    # 약탈자: 보통 2, '일부' 항복, 약물
	"CR-421": {"ai": "AI-15", "conf": 2, "surr": 0.5, "drug": true},
	"CR-422": {"ai": "AI-15", "conf": 2, "surr": 0.5, "drug": true},
	"CR-423": {"ai": "AI-15", "conf": 2, "surr": 0.5, "drug": true},
	"CR-435": {"ai": "AI-16", "conf": 1, "surr": 1.0, "react": 0.4},   # 새벽인력: 신중 1~2, 항복 예
	"CR-436": {"ai": "AI-16", "conf": 2, "surr": 1.0},
	"CR-437": {"ai": "AI-15", "conf": 1, "surr": 1.0},
	"CR-438": {"ai": "AI-15", "conf": 2, "surr": 1.0, "leader": true},
	"CR-456": {"ai": "AI-15", "conf": 3, "react": 0.35},               # 지하시장 경비: 출입구 고정
	"CR-457": {"ai": "AI-15", "conf": 4, "react": 0.35},               # 계약 경호 구울
	"CR-473": {"ai": "AI-13", "conf": 4},                              # 프롤로그 보안요원(볼트 평시 — 도주 연출 없음)
	"CR-513": {"ai": "AI-19"},
	"CR-534": {"ai": "AI-19"},
}
const FLEE_HP := [1.01, 0.70, 0.35, 0.15, -1.0]          ## 자신감별 도주 HP 비율(0 = 적을 보면 · 4 = 안 함)


static func of(id: String) -> Dictionary:
	var r: Dictionary = ROWS.get(id, {"ai": "AI-15"})
	var out: Dictionary = AI.get(str(r["ai"]), AI["AI-15"]).duplicate()
	out.merge(r, true)
	for k in [["surr", 0.0], ["drug", false], ["leader", false], ["pack_lead", false]]:
		if not out.has(k[0]):
			out[k[0]] = k[1]
	return out


## 자신감(분대장 · 사건 보정 뒤)으로 지금 도망쳐야 하나
static func should_flee(conf: int, hp_ratio: float) -> bool:
	var c := clampi(conf, 0, 4)
	return c < 4 and hp_ratio <= FLEE_HP[c]
