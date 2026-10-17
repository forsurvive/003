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
var doll: Paperdoll                           ## 주인공: 실행 중 페이퍼돌(장비 즉시 반영). 없으면 굽은 시트
## 회피 구르기(SD-11 §5.3): 0.35초에 2.5t, 5컷 중 2~4번째 무적, 끝난 뒤 0.5초 간격
const ROLL_TIME := 0.35
const ROLL_DIST := 2.5 * 32.0
const ROLL_GAP := 0.5
## 자세 그림(시트에 '<자세>_E'가 있을 때): [속도 배수(8컷/초 기준), 걸어도 트나]
const POSE_ANIMS := {"mound": [1.0, true], "heave": [1.2, true], "emerge": [0.6, true], "dig": [0.8, true], "eat": [0.5, false],
	"pulse": [0.25, false], "crack": [1.0, false], "spray": [1.0, false], "spit": [1.0, false], "lay": [0.6, false]}   # 1-D5b 왕개미 분사 · 산성 침 · 알 낳기
var roll_t := -1.0                            ## 구르는 중이면 0 이상
var roll_vec := Vector2.ZERO
var roll_dir := 2
var roll_cool := 0.0
var roll_mul := 1.0                           ## 구르기 거리 배수(과적 · 다리 손상 0.6, SD-11 §5.3)
var _steer := Vector2.ZERO
var _steer_at := -1
## 층(1-Rd, SD-16 §6.5 '층 ID'): 0 지면 · 1 고가 상판. 램프·비상계단 칸에서만 바뀐다(InteriorMap.floor_after)
var floor_id := 0


func setup_doll(look: Dictionary, pos: Vector2, w) -> void:
	world = w
	loco = Locomotion.new(pos)
	doll = Paperdoll.new()
	doll.set_look(look)
	add_child(doll)
	meta = {"foot": [32, 60], "rows": ["S", "SE", "E", "NE", "N"]}
	position = loco.render
	_show()


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


## 자세(SD-16 §13.6 인게임 컷신): stand 서기 · lie 눕기(그림을 90도 눕혀 머리를 왼쪽에, 침대 위라 앞에 그린다) · sit 앉기(4px 내림) ·
## sleep 잠(시트에 sleep_E가 있는 짐승만 — 엎드려 숨쉬는 2컷, 1-8b 백구)
var pose := "stand"


func set_pose(p: String) -> void:
	pose = p
	var n: Node2D = doll if doll != null else sprite
	n.visible = p != "in_bed"                                          # 침대 그림이 대신 그린다(말풍선 자리는 남는다)
	n.rotation_degrees = -90.0 if p == "lie" else 0.0
	n.position = Vector2(-4, -10) if p == "lie" else (Vector2(0, 4) if p == "sit" else Vector2.ZERO)
	_floor_z()
	_show()


## 그리는 층: 상판(z 2) 위에 선 인물은 z 3 — 상판 아래(층 0) 인물은 상판 그림에 가려진다. 램프 위도 상판 쪽이다
func _floor_z() -> void:
	var up := floor_id >= 1
	if not up and world is InteriorMap and world.has_deck:
		up = InteriorMap.is_link(world.deck_at(world.tile_of(loco.logical)))
	z_index = (3 if up else 0) + (1 if pose == "lie" else 0)


## 층이 있는 맵에서 충돌을 부르기 전후: 맵에 내 층을 알리고, 움직인 뒤 층을 갱신한다
func _deck_pre() -> Vector2i:
	if world is InteriorMap and world.has_deck:
		world.mover_floor = floor_id
		return world.tile_of(loco.logical)
	return Vector2i(-99999, -99999)


func _deck_post(from_t: Vector2i) -> void:
	if from_t.x == -99999:
		return
	var f: int = world.floor_after(from_t, world.tile_of(loco.logical), floor_id)
	world.mover_floor = 0
	floor_id = f
	_floor_z()                                                          # 램프에 오르내리면 층이 같아도 그리는 층이 바뀐다


## 층을 정해 세운다(불러오기·순간 이동·연출 배치)
func set_floor(f: int) -> void:
	floor_id = f
	_floor_z()


## 발 기준점에서 머리 꼭대기까지(음수 px): 시트 첫 컷의 불투명 영역 위끝(시트마다 한 번 재어 둔다). 말풍선 높이 — 아기는 낮다
static var _tops := {}


func head_y() -> float:
	if sprite == null:
		return -39.0
	if not _tops.has(sheet):
		var top := -39.0
		var anims := sprite.sprite_frames.get_animation_names()
		var tex: Texture2D = sprite.sprite_frames.get_frame_texture(anims[0], 0) if not anims.is_empty() else null
		var img := tex.get_image() if tex != null else null
		if img != null and not img.is_empty() and img.get_used_rect().has_area():
			top = float(img.get_used_rect().position.y - int(meta["foot"][1]))
		_tops[sheet] = top
	return _tops[sheet] + (sprite.position.y if sprite.visible else 0.0)


func move(input: Vector2, dt: float) -> void:
	var blocked := func(a: Vector2, b: Vector2) -> Vector2: return world.move_circle(a, b, radius_px)
	var ft := _deck_pre()
	loco.step(input, dt, mode, aim_dir, blocked)
	_deck_post(ft)
	position = loco.render
	_show()


## AI용: 가려는 방향이 막히면 막히지 않은 가까운 8방향으로 돌아선다(벽 비비기 대신 돌아서 걷기, Sweep.steer)
func steer(input: Vector2) -> Vector2:
	if input.length() < 0.2:
		_steer = Vector2.ZERO
		return input
	if _steer != Vector2.ZERO and loco.motion != "idle" and loco.frames_advanced == _steer_at:
		return _steer                                                  # 걸음 하나를 다 걸을 때까지 방향 유지
	var hits := func(c: Vector2, r: float) -> bool: return world.circle_hits(c, r)
	var ft := _deck_pre()
	_steer = Sweep.steer(loco.logical, input, 6.0, radius_px, hits)
	if ft.x != -99999:
		world.mover_floor = 0
	_steer_at = loco.frames_advanced
	return _steer


func rolling() -> bool:
	return roll_t >= 0.0


func roll_frame() -> int:
	return mini(4, int(roll_t / (ROLL_TIME / 5.0)))


## 구르기 시작. dir_vec이 0이면 몸 방향의 반대(뒤로) — SD-11 §15.5와 같은 규칙을 키보드에도 쓴다.
func start_roll(dir_vec: Vector2) -> void:
	var d := Locomotion.snap8(dir_vec) if dir_vec.length() > 0.2 else (loco.facing + 4) % 8
	roll_dir = d
	roll_vec = Locomotion.VEC[d].normalized()
	roll_t = 0.0
	_show()


## 구르는 동안 매 프레임: 발이 땅에서 떨어진 이동이라 위치가 연속으로 바뀐다. 끝나면 그 자리에 선다.
func roll_step(dt: float) -> void:
	var a := loco.logical
	var ft := _deck_pre()
	var b: Vector2 = world.move_circle(a, a + roll_vec * ROLL_DIST * roll_mul / ROLL_TIME * dt, radius_px)
	loco.logical = b
	_deck_post(ft)
	loco.render = b.round()
	roll_t += dt
	if roll_t >= ROLL_TIME:
		roll_t = -1.0
		roll_cool = ROLL_GAP
		loco.place(b)
		loco.facing = roll_dir
	position = loco.render
	_show()


func _show() -> void:
	var motion := "idle" if loco.motion == "idle" else loco.anim_motion()
	var dir := loco.facing if loco.motion != "idle" or aim_dir < 0 else aim_dir
	if doll != null:
		if rolling():
			doll.show_roll(roll_dir, roll_frame())
		elif aim_dir >= 0:
			doll.show_aim(motion, loco.facing if motion != "idle" else aim_dir, loco.frame, aim_dir)
		else:
			doll.show_frame(motion, dir, loco.frame if motion != "idle" else 0)
		return
	if meta.get("rows", []) == ["E"]:                                 # side-only sheets (creatures): E or mirrored W
		dir = 4 if Locomotion.VEC[dir].x < 0 else 0
	if POSE_ANIMS.has(pose) and sprite.sprite_frames.has_animation(pose + "_E") and (bool(POSE_ANIMS[pose][1]) or loco.motion == "idle"):
		var pa := pose + "_E"                                          # 1-D3 자세 그림: 굴쥐 둔덕 · 들썩임 · 내밀기 · 파기(걸어도 그 그림) · 먹기 · 알집 맥동 · 갈라짐(서 있을 때만)
		if sprite.animation != pa:
			sprite.animation = pa
		sprite.flip_h = dir == 4
		sprite.speed_scale = float(POSE_ANIMS[pose][0])
		if not sprite.is_playing():
			sprite.play(pa)
		return
	if pose == "sleep" and loco.motion == "idle" and sprite.sprite_frames.has_animation("sleep_E"):   # 잠(백구 낮잠, 1-8b): 숨쉬기 2컷을 느리게 돈다
		if sprite.animation != "sleep_E":
			sprite.animation = "sleep_E"
		sprite.flip_h = dir == 4
		sprite.speed_scale = 0.12
		if not sprite.is_playing():
			sprite.play("sleep_E")
		return
	sprite.speed_scale = 1.0
	if pose == "sit" and loco.motion == "idle":                      # 앉은 그림이 있는 시트(대피민 구울, 1-11e): 무릎을 세운 앉음
		var sa: Array = Locomotion.anim_for("sit", dir)
		if sprite.sprite_frames.has_animation(sa[0]):
			sprite.position = Vector2.ZERO
			if sprite.animation != sa[0]:
				sprite.animation = sa[0]
			sprite.flip_h = sa[1]
			sprite.frame = 0
			sprite.pause()
			return
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
