## 맵 위 인물·크리처 공통: 논리 위치는 Locomotion이, 그림은 AnimatedSprite2D가 맡는다.
## 노드 위치 = 발 기준점 = Locomotion.render(단계 렌더). 시트 메타(JSON)의 foot으로 오프셋을 맞춘다.
class_name Actor
extends Node2D

var loco: Locomotion
var sprite: AnimatedSprite2D
var meta: Dictionary
var radius_px := 9.6                          ## 인간형 0.3t (SD-11 §4.3)
var world                                    ## ChunkWorld 또는 InteriorRoom (같은 충돌 API)
var mode := "run"                             ## 기본 이동 = 달리기 4.5t/s (SD-11 §2.4)
var aim_dir := -1
var sheet := ""


func setup(sheet_name: String, pos: Vector2, w) -> void:
	sheet = sheet_name
	world = w
	loco = Locomotion.new(pos)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = load("res://assets/sprites/%s.tres" % sheet_name)
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s.json" % sheet_name))
	var fw: int = int(meta["frame"][0])
	var fh: int = int(meta["frame"][1])
	sprite.centered = false
	sprite.offset = Vector2(-int(meta["foot"][0]), -int(meta["foot"][1]))
	add_child(sprite)
	position = loco.render
	_show()


func move(input: Vector2, dt: float) -> void:
	var blocked := func(a: Vector2, b: Vector2) -> Vector2: return world.move_circle(a, b, radius_px)
	loco.step(input, dt, mode, aim_dir, blocked)
	position = loco.render
	_show()


func _show() -> void:
	var motion := "idle" if loco.motion == "idle" else loco.motion
	var dir := loco.facing if loco.motion != "idle" or aim_dir < 0 else aim_dir
	if meta.get("rows", []) == ["E"]:                                 # side-only sheets (creatures): E or mirrored W
		dir = 4 if Locomotion.VEC[dir].x < 0 else 0
	var a: Array = Locomotion.anim_for(motion, dir)
	var anim: String = a[0]
	if not sprite.sprite_frames.has_animation(anim):
		anim = Locomotion.anim_for("idle", dir)[0]
		if not sprite.sprite_frames.has_animation(anim):
			anim = sprite.sprite_frames.get_animation_names()[0]
	if sprite.animation != anim:
		sprite.animation = anim
	sprite.flip_h = a[1]
	sprite.frame = loco.frame if motion != "idle" else 0
	sprite.pause()
