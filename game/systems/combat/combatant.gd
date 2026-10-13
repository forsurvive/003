## 전투 참가자 데이터: 체력·DR·편·충돌 반지름. 맞으면 CombatRules.resolve 결과를 받는다.
class_name Combatant
extends RefCounted

signal died
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


func pos() -> Vector2:
	return actor.loco.logical


func take(result: Dictionary, from: Vector2) -> void:
	if dead or invuln:
		return
	hp -= float(result["hp"])
	last_hit_from = from
	flash = 3
	if hp <= 0.0:
		hp = 0.0
		dead = true
		died.emit()
