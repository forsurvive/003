## 전투 참가자 데이터: 체력·DR·편·충돌 반지름. 맞으면 CombatRules.resolve 결과를 받는다.
class_name Combatant
extends RefCounted

signal died
signal hit                                    ## 맞았지만 쓰러지지 않았다(주민 폭행 반응, 0-9)
var actor                                     ## loco.logical을 가진 것(Actor 또는 표적 자리표)
var team := "player"
var hp := 100.0
var max_hp := 100.0
var dr := 0.0
var radius := 9.6
var weights: Dictionary = CombatRules.HUMANOID_WEIGHTS
var dead := false
var last_hit_from := Vector2.ZERO
var flash := 0
var invuln := false                           ## 구르기 무적 프레임: 투사체·근접·폭발 모두 무시(SD-11 §5.3)
var unaware := Callable()                     ## 쏜 쪽을 아직 모른다(은신 기습 가능, SD-11 §4.4) — 없으면 늘 안다
var last_sneak := false                       ## 마지막으로 맞은 것이 은신 기습이었나(표시용)
## 단계 0-9: 은신 탐지 입력(주인공) · 기절 · 체력 하한
var posture := "stand"                        ## stand | crouch — 적의 탐지식(Perception.detect_rate)이 읽는다
var movement := "move"                        ## still | sneak | move | sprint | fired
var sneak := 0.0                              ## 은신 스킬
var can_ko := false                           ## 비살상 피해로 HP 0이면 기절(인간형 적)
var ko := false                               ## 기절 중(dead도 참: 맞지 않고 막지 않는다)
var hp_floor := 0.0                           ## 이 밑으로 내려가지 않는다(죽지 않는 적)
var killed_lethal := false                    ## 마지막 일격이 실총이었나(카르마)


func pos() -> Vector2:
	return actor.loco.logical


func take(result: Dictionary, from: Vector2) -> void:
	if dead or invuln:
		return
	hp -= float(result["hp"])
	last_hit_from = from
	flash = 3
	if hp_floor > 0.0 and hp < hp_floor:
		hp = hp_floor
		hit.emit()
		return
	if hp > 0.0:
		hit.emit()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		ko = can_ko and bool(result.get("nonlethal", false))
		killed_lethal = not ko
		died.emit()
