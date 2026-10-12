## 아이작풍 샘플 인물: 몸(이동 방향, 걷기 6컷) + 머리(조준 방향 5방향 + 반전, 표정 3) + 손에 든 총.
## 이동은 본편과 같은 Locomotion(거리 구동·단계 렌더·미끄러짐 금지). 보폭은 짧은 다리에 맞춰 컷당 4px.
class_name IsaacChar
extends Node2D

const VIEW_OF := {2: ["S", false], 1: ["SE", false], 3: ["SE", true], 0: ["E", false], 4: ["E", true],
	7: ["NE", false], 5: ["NE", true], 6: ["N", false]}
var kind := "pc"
var meta: Dictionary
var room
var loco: Locomotion
var aim_dir := -1
var body: Sprite2D
var head: Sprite2D
var gun: Sprite2D
var radius := 9.0
var hp := 6
var flash := 0.0
var face_t := 0.0
var _blink := 2.0


func setup(k: String, pos: Vector2, r, m: Dictionary) -> void:
	kind = k
	room = r
	meta = m
	loco = Locomotion.new(pos)
	var w: Dictionary = meta["walk"]
	loco.custom = {"run": {"frames": 6, "px": float(w["px"]), "diag": float(w["px"]), "contact": w["contact"], "speed_t": 4.5},
		"walk": {"frames": 6, "px": float(w["px"]), "diag": float(w["px"]), "contact": w["contact"], "speed_t": 3.0}}
	body = _sprite(k + "_body.png", 7, 3, Vector2(-16, -30))
	head = _sprite(k + "_head.png", 5, 3, Vector2.ZERO)
	head.z_index = 2
	gun = _sprite(k + "_gun.png", 5, 1, Vector2.ZERO)
	position = loco.render
	show_frame()


func _sprite(file: String, h: int, v: int, off: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/style_isaac/" + file)
	s.hframes = h
	s.vframes = v
	s.centered = false
	s.offset = off
	add_child(s)
	return s


func move(input: Vector2, dt: float, mode: String = "run") -> void:
	var blocked := func(a: Vector2, b: Vector2) -> Vector2: return room.move_circle(a, b, radius)
	loco.step(input, dt, mode, aim_dir, blocked)
	position = loco.render
	face_t = maxf(0.0, face_t - dt)
	flash = maxf(0.0, flash - dt)
	_blink -= dt
	if _blink < -0.12:
		_blink = 2.0 + randf() * 2.5
	show_frame()


func show_frame() -> void:
	var moving := loco.motion != "idle"
	var f := loco.facing
	var row := 0 if f == 2 else (2 if f == 6 else 1)
	var col := 1 + loco.frame if moving else 0
	body.frame = row * 7 + col
	body.flip_h = f in [3, 4, 5]
	var top: int = int(meta[kind]["head_top"][["S", "E", "N"][row]][col])
	var a := aim_dir if aim_dir >= 0 else f
	var vf: Array = VIEW_OF[a]
	var vi: int = ["S", "SE", "E", "NE", "N"].find(vf[0])
	var face := 1 if face_t > 0.0 else (2 if _blink < 0.0 and kind == "pc" else 0)
	head.frame = face * 5 + vi
	head.flip_h = vf[1]
	head.position = Vector2(-12, top - 30)
	gun.frame = vi
	gun.flip_h = vf[1]
	var g: Array = meta["gun_at"][vf[0]]
	gun.position = Vector2((-g[0] if vf[1] else g[0]) - 8, g[1] - 8)
	gun.z_index = -1 if vf[0] in ["N", "NE"] else 3
	modulate = Color(1, 0.45, 0.45) if flash > 0.0 else Color(1, 1, 1)
	queue_redraw()


func _draw() -> void:                                              # 발밑 그림자(아이작풍 납작한 타원)
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.32))
