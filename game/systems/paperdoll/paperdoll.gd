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
	for slot in layers:
		var code: String = look[slot]
		var s: Sprite2D = layers[slot]
		var hidden: bool = code == "" or not meta["overlays"].has(code)
		if slot == "hair" and look["gear"] != "" and code == "HR07":
			hidden = true                                         # 정수리 묶음은 모자 아래에 들어간다(SD-07b §3.4)
		s.visible = not hidden
		if not hidden:
			s.texture = tex(meta["overlays"][code]["sheet"])
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


## motion: idle/walk/run, dir: Locomotion 8방향 인덱스, frame: 모션 안 프레임
func show_frame(motion: String, dir: int, frame: int) -> void:
	var a: Array = Locomotion.anim_for(motion, dir)
	var row_name: String = (a[0] as String).split("_")[1]
	var flip: bool = a[1]
	var row := ["S", "SE", "E", "NE", "N"].find(row_name)
	var mo: Dictionary = fam["motions"].get(motion, fam["motions"]["idle"])
	var f := mini(frame, int(mo["count"]) - 1)
	base.frame = row * _cols + int(mo["start"]) + f
	base.flip_h = flip
	var key := "%s:%s:%d" % [row_name, motion if fam["motions"].has(motion) else "idle", f]
	var h: Array = fam["head"][key]
	for slot in layers:
		var s: Sprite2D = layers[slot]
		if not s.visible:
			continue
		var ov: Dictionary = meta["overlays"][look[slot]]
		var h0: Array = ov["head"][row_name]
		var d := Vector2(h[0] - h0[0], h[1] - h0[1])
		s.frame = row
		s.flip_h = flip
		s.position = Vector2(-d.x if flip else d.x, d.y)
