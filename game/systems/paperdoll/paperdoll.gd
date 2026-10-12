## 주인공 실행 중 페이퍼돌 (SD-16 §5.1·§5.5, SD-19 §6.7): 몸+몸통 인덱스 시트 1장 + 머리 앵커 층(머리카락·눈 장비·머리 장비).
## 장비·피부·머리색·세력을 바꾸면 그 프레임부터 바로 보인다(P9). 색은 팔레트 셰이더가 정한다.
class_name Paperdoll
extends Node2D

const DIR := "res://assets/paperdoll/"
static var meta: Dictionary
static var _shader: Shader
static var _tex := {}
var look := {"torso": "T01", "skin": "S3", "hair_color": "H1", "faction": "", "hair": "HR03", "gear": "", "eyes": ""}
var base: Sprite2D
var upper: Sprite2D                    ## 조준 분리 때만: 권총 상체(조준 방향). base는 그때 하체(이동 방향)만 그린다
var layers := {}                       ## slot -> Sprite2D (hair, eyes, gear: 그리기 순서 = 머리 합성 순서)
var mat: ShaderMaterial
var fam: Dictionary
var _cols := 1


static func _load_meta() -> void:
	if meta.is_empty():
		meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "paperdoll.json"))
		_shader = load("res://systems/paperdoll/palette_index.gdshader")


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name)
	return _tex[name]


func _init() -> void:
	_load_meta()
	mat = ShaderMaterial.new()
	mat.shader = _shader
	base = Sprite2D.new()
	base.centered = false
	base.offset = Vector2(-32, -60)
	base.material = mat
	add_child(base)
	upper = Sprite2D.new()
	upper.centered = false
	upper.offset = Vector2(-32, -60)
	upper.material = mat
	upper.vframes = 5
	upper.visible = false
	add_child(upper)
	for slot in ["hair", "eyes", "gear"]:
		var s := Sprite2D.new()
		s.centered = false
		s.offset = Vector2(-32, -60)
		s.material = mat
		s.hframes = 5
		s.visible = false
		add_child(s)
		layers[slot] = s
	set_look({})


func set_look(changes: Dictionary) -> void:
	for k in changes:
		look[k] = changes[k]
	fam = meta["families"][look["torso"]]
	base.texture = tex(fam["sheet"])
	_cols = 0
	for mo in fam["motions"].values():
		_cols += int(mo["count"])
	base.hframes = _cols
	base.vframes = 5
	upper.texture = base.texture
	upper.hframes = _cols
	for slot in layers:
		var code: String = look[slot]
		var s: Sprite2D = layers[slot]
		var hidden: bool = code == "" or not meta["overlays"].has(code)
		if slot == "hair" and look["gear"] != "" and code == "HR07":
			hidden = true                                         # 정수리 묶음은 모자 아래에 들어간다(SD-07b §3.4)
		s.visible = not hidden
		s.texture = null if hidden else tex(meta["overlays"][code]["sheet"])
	_apply_palette()


func _apply_palette() -> void:
	var pal: Dictionary = meta["palettes"]
	var m := PackedColorArray()
	for h in pal["master"]:
		m.append(Color(h))
	mat.set_shader_parameter("master", m)
	mat.set_shader_parameter("skin", _colors(pal["skin"][look["skin"]]))
	mat.set_shader_parameter("hair", _colors(pal["hair"][look["hair_color"]]))
	var f: Array
	if look["faction"] != "" and pal["faction"].has(look["faction"]):
		f = pal["faction"][look["faction"]]
	elif fam["default_main"] != null:
		f = fam["default_main"] + fam["default_accent"]
	else:
		f = pal["faction"]["PF-01"]
	mat.set_shader_parameter("fac", _colors(f))


static func _colors(a: Array) -> PackedColorArray:
	var out := PackedColorArray()
	for h in a:
		out.append(Color(h))
	return out


func set_flash(v: float) -> void:
	mat.set_shader_parameter("flash", v)


static func _row(dir: int) -> Array:
	var a: Array = Locomotion.anim_for("x", dir)
	return [["S", "SE", "E", "NE", "N"].find((a[0] as String).split("_")[1]), a[1]]


func _cell(motion: String, row: int, frame: int) -> int:
	var mo: Dictionary = fam["motions"].get(motion, fam["motions"]["idle"])
	return row * _cols + int(mo["start"]) + mini(frame, int(mo["count"]) - 1)


## 머리 층을 머리 앵커 key("행:모션:프레임")에 맞춰 옮긴다. key가 없으면(구르기) 머리 층을 숨긴다.
func _heads(key: String, row: int, flip: bool, dy: int = 0) -> void:
	var h: Array = fam["head"].get(key, [])
	var rn: String = ["S", "SE", "E", "NE", "N"][row]
	for slot in layers:
		var s: Sprite2D = layers[slot]
		var on: bool = s.texture != null and look[slot] != "" and meta["overlays"].has(look[slot]) \
			and not (slot == "hair" and look["gear"] != "" and look[slot] == "HR07")
		s.visible = on and not h.is_empty()
		if not s.visible:
			continue
		var h0: Array = meta["overlays"][look[slot]]["head"][rn]
		var d := Vector2(h[0] - h0[0], h[1] - h0[1] + dy)
		s.frame = row
		s.flip_h = flip
		s.position = Vector2(-d.x if flip else d.x, d.y)


## motion: idle/walk/run, dir: Locomotion 8방향 인덱스, frame: 모션 안 프레임
func show_frame(motion: String, dir: int, frame: int) -> void:
	var r: Array = _row(dir)
	upper.visible = false
	base.frame = _cell(motion, r[0], frame)
	base.flip_h = r[1]
	var mo: String = motion if fam["motions"].has(motion) else "idle"
	var f := mini(frame, int(fam["motions"][mo]["count"]) - 1)
	_heads("%s:%s:%d" % [["S", "SE", "E", "NE", "N"][r[0]], mo, f], r[0], r[1])


## 조준 분리(SD-16 §5.10): 하체는 legs_dir(뒷걸음이면 Locomotion이 이미 뒤집어 준다)·motion·frame,
## 상체는 aim_dir. 상체와 머리 층은 하체 보폭의 출렁임(bob)만큼 내려간다.
func show_aim(motion: String, legs_dir: int, frame: int, aim_dir: int) -> void:
	var lr: Array = _row(legs_dir)
	var ur: Array = _row(aim_dir)
	var mode: String = motion if motion in ["walk", "run"] else "idle"
	var f := 0 if mode == "idle" else frame % 6
	base.frame = _cell("aim_" + mode, lr[0], f)
	base.flip_h = lr[1]
	var dy := 0
	if mode != "idle":
		dy = int(fam["bob"][mode][["S", "SE", "E", "NE", "N"][lr[0]]][f])
	upper.visible = true
	upper.frame = _cell("aim_up", ur[0], 0)
	upper.flip_h = ur[1]
	upper.position = Vector2(0, dy)
	_heads("%s:aim_up:0" % ["S", "SE", "E", "NE", "N"][ur[0]], ur[0], ur[1], dy)


## 회피 구르기 5컷(임시 그림). 머리 층은 숨긴다(공 그림에 기본 머리가 들어 있다).
func show_roll(dir: int, frame: int) -> void:
	var r: Array = _row(dir)
	upper.visible = false
	base.frame = _cell("roll", r[0], frame)
	base.flip_h = r[1]
	_heads("", r[0], r[1])
