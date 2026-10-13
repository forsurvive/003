## 주인공 실행 중 페이퍼돌 v2 — 아이작풍(SD-16 §5 v2.0, SD-19 §6.7).
## 층: 몸(이동 방향) · 머리(조준 방향, 표정) · 머리 장비 · 눈 장비 · 손 무기. 전부 팔레트 인덱스 시트 + 같은 셰이더.
## 장비·피부·머리색·세력을 바꾸면 그 프레임부터 바로 보인다(P9). 머리는 몸 컷마다 메타의 '머리 구 중심'에 얹는다.
class_name Paperdoll
extends Node2D

const DIR := "res://assets/paperdoll/"
const VIEWS := ["S", "SE", "E", "NE", "N"]
const VIEW_OF := {2: ["S", false], 1: ["SE", false], 3: ["SE", true], 0: ["E", false], 4: ["E", true],
	7: ["NE", false], 5: ["NE", true], 6: ["N", false]}
static var meta: Dictionary
static var _shader: Shader
static var _tex := {}
var look := {"body": "M1", "torso": "T01", "skin": "S3", "hair_color": "H1", "faction": "", "hair": "HR03", "gear": "", "eyes": "",
	"weapon": ""}
var body: Sprite2D
var head_root: Node2D
var head: Sprite2D
var gear: Sprite2D
var eyes: Sprite2D
var gun: Sprite2D
var muzzle_fx: Sprite2D                       ## 총구 화염·분출(가산, CombatFx 시트) — 총과 같은 층(N·NE 조준이면 몸 뒤)
var mat: ShaderMaterial
var fam: Dictionary
var face := "idle"
var _cols := 1
var _face_t := 0.0
var _blink := 2.5
var _head_view := 0
var _head_flip := false
var _fx_set := ""
var _fx_ang := 0.0
var _fx_t := -1.0
var _fx_born := -1


static func _load_meta() -> void:
	if meta.is_empty():
		meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "paperdoll.json"))
		_shader = load("res://systems/paperdoll/palette_index.gdshader")


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name)
	return _tex[name]


func _sprite(parent: Node, off: Vector2, h: int, v: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.offset = off
	s.material = mat
	s.hframes = h
	s.vframes = v
	parent.add_child(s)
	return s


func _init() -> void:
	_load_meta()
	mat = ShaderMaterial.new()
	mat.shader = _shader
	gun = _sprite(self, Vector2.ZERO, 5, 1)                           # 뒤쪽 무기(N·NE 조준)는 z로 몸 뒤에 둔다
	body = _sprite(self, Vector2(-16, -30), 1, 5)
	head_root = Node2D.new()
	add_child(head_root)
	head = _sprite(head_root, Vector2(-20, -22), 5, 5)
	gear = _sprite(head_root, Vector2(-20, -22), 5, 1)
	eyes = _sprite(head_root, Vector2(-20, -22), 5, 1)
	muzzle_fx = Sprite2D.new()
	muzzle_fx.centered = false
	muzzle_fx.region_enabled = true
	muzzle_fx.visible = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	muzzle_fx.material = add
	add_child(muzzle_fx)
	set_look({})


func set_look(changes: Dictionary) -> void:
	for k in changes:
		look[k] = changes[k]
	var key := "%s:%s" % [look["body"], look["torso"]]
	if not meta["families"].has(key):
		key = "M1:" + look["torso"]
	fam = meta["families"][key]
	body.texture = tex(fam["sheet"])
	_cols = 0
	for mo in fam["motions"].values():
		_cols += int(mo["count"])
	body.hframes = _cols
	var hood: bool = fam["hood"]
	var hk: String
	if hood:
		hk = "%s:HOOD_%s" % [look["body"], look["torso"]]
	else:
		var hr: String = look["hair"]
		if hr == "HR07" and look["gear"] != "":
			hr = "HR07h"                                                # 쪽머리는 모자 아래로 숨는다
		hk = "%s:%s" % [look["body"], hr]
	if not meta["heads"].has(hk):
		hk = "M1:HR03"
	head.texture = tex(meta["heads"][hk])
	for pair in [[gear, "gear"], [eyes, "eyes"]]:
		var s: Sprite2D = pair[0]
		var code: String = look[pair[1]]
		var on: bool = not hood and code != "" and meta["overlays"].has(code)
		s.visible = on
		s.texture = tex(meta["overlays"][code]["sheet"]) if on else null
	gun.visible = look["weapon"] != "" and meta["weapons"].has(look["weapon"])
	var wk: String = look["weapon"] + ("_glove" if fam.get("gloved", false) else "")
	gun.texture = tex(meta["weapons"][wk]) if gun.visible else null
	_apply_palette()


func _apply_palette() -> void:
	var pal: Dictionary = meta["palettes"]
	var m := PackedColorArray()
	for h in pal["master"]:
		m.append(Color(h))
	mat.set_shader_parameter("master", m)
	mat.set_shader_parameter("skin", _colors(pal["skin"][look["skin"]]))
	mat.set_shader_parameter("hair", _colors(pal["hair"][look["hair_color"]]))
	var f: Array = pal["faction"][look["faction"] if look["faction"] != "" and pal["faction"].has(look["faction"]) else "PF-01"]
	mat.set_shader_parameter("fac", _colors(f))


static func _colors(a: Array) -> PackedColorArray:
	var out := PackedColorArray()
	for h in a:
		out.append(Color(h))
	return out


func set_flash(v: float) -> void:
	mat.set_shader_parameter("flash", v)


## 잠깐 바뀌는 표정(쏠 때 찡그림·맞을 때·말할 때). secs 뒤 평소 얼굴로.
func flash_face(f: String, secs: float) -> void:
	face = f
	_face_t = secs
	_update_head()


func tick(dt: float) -> void:
	if _face_t > 0.0:
		_face_t -= dt
		if _face_t <= 0.0:
			face = "idle"
	_blink -= dt
	if _blink < -0.12:
		_blink = 2.0 + randf() * 2.5
	_update_head()


func _update_head() -> void:
	var fname := face
	if fname == "idle" and _blink < 0.0:
		fname = "blink"
	var fi: int = (meta["faces"] as Array).find(fname)
	head.frame = maxi(0, fi) * 5 + _head_view
	head.flip_h = _head_flip
	for s in [gear, eyes]:
		s.frame = _head_view
		s.flip_h = _head_flip


func _place(motion: String, body_dir: int, frame: int, head_dir: int) -> void:
	var bv: Array = VIEW_OF[body_dir]
	var row: int = VIEWS.find(bv[0])
	var mo: Dictionary = fam["motions"].get(motion, fam["motions"]["idle"])
	var f := mini(frame, int(mo["count"]) - 1) if motion != "idle" else 0
	body.frame = row * _cols + int(mo["start"]) + f
	body.flip_h = bv[1]
	var a: Array = fam["head"]["%s:%s:%d" % [bv[0], motion if fam["motions"].has(motion) else "idle", f]]
	head_root.rotation = 0.0
	head_root.position = Vector2(-a[0] if bv[1] else a[0], a[1])
	var hv: Array = VIEW_OF[head_dir]
	_head_view = VIEWS.find(hv[0])
	_head_flip = hv[1]
	_update_head()
	if gun.visible:
		var g: Array = meta["gun_at"][hv[0]]
		var go: Array = fam.get("gun_off", [0, 0])                      # 몸마다 손 위치(아이 K1은 낮고 안쪽)
		var gx: float = g[0] + go[0]
		gun.frame = _head_view
		gun.flip_h = hv[1]
		gun.position = Vector2((-gx if hv[1] else gx) - 10, g[1] + go[1] - 8)
		gun.z_index = -1 if hv[0] in ["N", "NE"] else 1


## motion: idle/walk/run, dir: Locomotion 8방향 인덱스, frame: 모션 안 프레임. 머리·무기도 몸 방향.
func show_frame(motion: String, dir: int, frame: int) -> void:
	_place(motion, dir, frame, dir)


## 조준 분리(SD-16 §5.10): 몸은 legs_dir(뒷걸음이면 Locomotion이 이미 뒤집어 준다), 머리·무기는 aim_dir.
func show_aim(motion: String, legs_dir: int, frame: int, aim_dir: int) -> void:
	_place(motion if motion in ["walk", "run"] else "idle", legs_dir, frame, aim_dir)


## 총구 점(인형 좌표): 손 기준점(gun_at + 몸 보정) + 무기 그림 안 총구(paperdoll.json muzzle) — SD-16 §5 'muzzle'.
## dir8 = 총 그림이 보는 쪽(조준 중이면 조준 방향, 아니면 몸 방향). 총구가 없는 무기면 손 자리.
func muzzle_local(dir8: int) -> Vector2:
	var hv: Array = VIEW_OF[dir8]
	var g: Array = meta["gun_at"][hv[0]]
	var go: Array = fam.get("gun_off", [0, 0])
	var gx: float = float(g[0]) + float(go[0])
	var top := Vector2((-gx if hv[1] else gx) - 10.0, float(g[1]) + float(go[1]) - 8.0)
	var m: Array = meta.get("muzzle", {}).get(look["weapon"], {}).get(hv[0], [10.0, 8.0])
	return top + Vector2(20.0 - float(m[0]) if hv[1] else float(m[0]), float(m[1]))


## 쏠 때 총구 효과(SD-16 §10.1): 날아가는 각에 가까운 16방향 열, 컷당 2틱. 총과 같은 층에 그려 N·NE 조준이면 머리 뒤로 숨는다.
func fire_flash(dir8: int, angle_deg: float, set_name: String) -> void:
	if not CombatFx.has_set(set_name) or not gun.visible:
		return
	_fx_set = set_name
	_fx_ang = angle_deg
	_fx_t = 0.0
	_fx_born = Engine.get_process_frames()
	muzzle_fx.texture = CombatFx.sheet()
	muzzle_fx.position = CombatFx.top_left(set_name, muzzle_local(dir8))
	muzzle_fx.z_index = -1 if VIEW_OF[dir8][0] in ["N", "NE"] else 1
	muzzle_fx.region_rect = CombatFx.region(set_name, angle_deg, 0)
	muzzle_fx.visible = true


func _fx_tick(dt: float) -> void:
	if _fx_t < 0.0:
		return
	if Engine.get_process_frames() != _fx_born:                       # 나온 프레임에는 첫 컷을 그대로 둔다
		_fx_t += dt
	var k := CombatFx.frame_at(_fx_set, _fx_t)
	if k < 0 or not gun.visible:
		_fx_t = -1.0
		muzzle_fx.visible = false
		return
	muzzle_fx.region_rect = CombatFx.region(_fx_set, _fx_ang, k)


## 회피 구르기 5컷: 몸은 웅크린 공, 머리는 공 둘레를 90도씩 돈다(앞으로 구르는 쪽). 무기는 숨긴다.
func show_roll(dir: int, frame: int) -> void:
	var bv: Array = VIEW_OF[dir]
	var row: int = VIEWS.find(bv[0])
	var mo: Dictionary = fam["motions"]["roll"]
	var f := clampi(frame, 0, int(mo["count"]) - 1)
	body.frame = row * _cols + int(mo["start"]) + f
	body.flip_h = bv[1]
	var a: Array = fam["head"]["%s:roll:%d" % [bv[0], f]]
	var turn: int = [0, 1, 2, 3, 0][f]
	var sgn := -1.0 if bv[1] else 1.0
	head_root.rotation = deg_to_rad(90.0 * turn * sgn)
	var r := 6.0
	var ang := deg_to_rad(-90.0 + 90.0 * turn * sgn)
	head_root.position = Vector2(a[0] * sgn, a[1]) + (Vector2(cos(ang), sin(ang)) * r if f in [1, 2, 3] else Vector2(0, -r))
	var hv: Array = VIEW_OF[dir]
	_head_view = VIEWS.find(hv[0])
	_head_flip = hv[1]
	_update_head()
	gun.visible = false


func _process(dt: float) -> void:
	tick(dt)
	gun.visible = look["weapon"] != "" and meta["weapons"].has(look["weapon"]) and head_root.rotation == 0.0
	_fx_tick(dt)
