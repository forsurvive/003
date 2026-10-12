## 전투 참가자 데이터: 체력·DR·편·충돌 반지름. 맞으면 CombatRules.resolve 결과를 받는다.
class_name Combatant
extends RefCounted

signal died
var actor: Node2D
var team := "player"
var hp := 100.0
var max_hp := 100.0
var dr := 0.0
var radius := 9.6
var weights: Dictionary = CombatRules.HUMANOID_WEIGHTS
var dead := false
var last_hit_from := Vector2.ZERO
var flash := 0


func pos() -> Vector2:
	return actor.loco.logical


func take(result: Dictionary, from: Vector2) -> void:
	if dead:
		return
	hp -= float(result["hp"])
	last_hit_from = from
	flash = 3
	if hp <= 0.0:
		hp = 0.0
		dead = true
		died.emit()
