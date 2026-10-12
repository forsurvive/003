## 아이작풍 큰바퀴: 옆 3/4 모습 3컷(거리 구동, 컷당 3px), 좌우 반전만.
class_name IsaacRoach
extends Node2D

var room
var loco: Locomotion
var spr: Sprite2D
var radius := 9.0
var hp := 2
var flash := 0.0


func setup(pos: Vector2, r) -> void:
	room = r
	loco = Locomotion.new(pos)
	loco.custom = {"run": {"frames": 3, "px": 3.0, "diag": 2.0, "contact": [0, 0], "speed_t": 2.4}}
	spr = Sprite2D.new()
	spr.texture = load("res://assets/style_isaac/roach.png")
	spr.hframes = 4
	spr.centered = false
	spr.offset = Vector2(-17, -19)
	add_child(spr)
	position = loco.render


func move(input: Vector2, dt: float) -> void:
	var blocked := func(a: Vector2, b: Vector2) -> Vector2: return room.move_circle(a, b, radius)
	loco.step(input, dt, "run", -1, blocked)
	position = loco.render
	flash = maxf(0.0, flash - dt)
	spr.frame = 3 if flash > 0.0 else loco.frame % 3
	spr.flip_h = Locomotion.VEC[loco.facing].x < 0
	spr.offset.x = -25 if spr.flip_h else -17
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
