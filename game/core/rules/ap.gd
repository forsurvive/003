## AP(행동력) 실시간 자원 (SD-11 §5). 엔진 무관 상태 모듈.
## 최대 AP = 65 + 2 × 민첩성 + 보너스, 회복 초당 8(마지막 소모 1.0초 뒤부터), 질주 중 회복 없음.
class_name APPool
extends RefCounted

const REGEN := 8.0
const DELAY := 1.0
const SPRINT_PER_SEC := 10.0
const DODGE := 20.0
var max_ap := 75.0
var ap := 75.0
var sprint_mult := 1.0                    ## 질주 소모 배수(배달 기사 PK-028 0.7)
var regen_mult := 1.0                     ## 몸통 부위 손상 0.7, 막기 유지 0.5, 너브스 오브 스틸 (8+2)/8
var _since := 99.0


func _init(agi: int = 5, bonus: float = 0.0) -> void:
	max_ap = max_for(agi, bonus)
	ap = max_ap


static func max_for(agi: int, bonus: float = 0.0) -> float:
	return 65.0 + 2.0 * agi + bonus


func can(cost: float) -> bool:
	return ap > 0.0 and ap >= cost


func spend(cost: float) -> bool:
	if not can(cost):
		return false
	ap -= cost
	_since = 0.0
	return true


## 매 틱. sprint=true면 초당 10 소모하고 회복하지 않는다. 반환: 질주를 계속할 수 있는가(AP 0이면 자동 종료).
func tick(dt: float, sprint: bool) -> bool:
	if sprint and ap > 0.0:
		ap = maxf(0.0, ap - SPRINT_PER_SEC * sprint_mult * dt)
		_since = 0.0
		return ap > 0.0
	_since += dt
	if _since >= DELAY:
		ap = minf(max_ap, ap + REGEN * regen_mult * dt)
	return false


## 숨참 표시(AP 0)
func winded() -> bool:
	return ap <= 0.0
