## 바닥 합성 층(SD-16 §6.10): 타일 격자 한 구역의 바닥을 셰이더 하나로 그린다(ground.gdshader).
## id_map = 구역 + 한 칸 테두리. 테두리는 이웃 구역이 붙으면 채우고(put), 그 전에는 가장자리를 늘려 둔다.
## 같은 식의 파이썬 판(art/tools/ground.py)과 픽셀 단위로 같아야 한다(scenes/bench/ground_check).
class_name GroundLayer
extends Node2D

const DIR := "res://assets/ground/"
const PARAMS := ["mat_of", "force", "spread", "pri", "rim", "shade", "vthr", "dens", "hard", "boff", "dlist", "dcount", "flag_of"]
static var _sets := {}
var set_name: String
var origin: Vector2i
var size: Vector2i
var img: Image
var bytes: PackedByteArray                    ## RG8 원자료(칸당 2바이트): set_pixel보다 빠르다
var tex: ImageTexture
var mat: ShaderMaterial
var flag_of: PackedInt32Array
var _filled: PackedByteArray                  ## 테두리 칸이 실제 이웃 자료로 채워졌는지


static func get_set(name: String) -> Dictionary:
	if not _sets.has(name):
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "ground_%s.json" % name))
		var st := {"meta": meta, "atlas": load(DIR + "ground_%s.png" % name), "decals": load(DIR + "ground_decals_%s.png" % name),
			"noise": load(DIR + "ground_noise.png"), "shader": load("res://systems/world/ground.gdshader"), "ints": {}}
		for k in PARAMS:                                                # 표는 한 번만 변환(붙이기 예산)
			st["ints"][k] = _ints(meta[k])
		_sets[name] = st
	return _sets[name]


static func _ints(a: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for v in a:
		out.append(int(v))
	return out


## o: 구역 첫 칸의 월드 타일, s: 구역 크기(타일).
func setup(name: String, o: Vector2i, s: Vector2i) -> void:
	set_name = name
	origin = o
	size = s
	position = Vector2(o * 32)
	var st := get_set(name)
	var m: Dictionary = st["meta"]
	flag_of = st["ints"]["flag_of"]
	bytes = PackedByteArray()
	bytes.resize((s.x + 2) * (s.y + 2) * 2)
	_filled = PackedByteArray()
	_filled.resize((s.x + 2) * (s.y + 2))
	mat = ShaderMaterial.new()
	mat.shader = st["shader"]
	mat.set_shader_parameter("atlas", st["atlas"])
	mat.set_shader_parameter("decals", st["decals"])
	mat.set_shader_parameter("noise", st["noise"])
	mat.set_shader_parameter("origin", o)
	mat.set_shader_parameter("map_size", s + Vector2i(2, 2))
	mat.set_shader_parameter("cell", int(m["cell"]))
	for k in PARAMS:
		if k != "flag_of":
			mat.set_shader_parameter(k, st["ints"][k])
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## 월드 타일 (tx, ty)의 바닥 번호와 덮개(deco 아틀라스 번호, 없으면 -1). 구역·테두리 밖이면 무시.
func put(tx: int, ty: int, ground: int, deco: int) -> void:
	var x := tx - origin.x + 1
	var y := ty - origin.y + 1
	if x < 0 or y < 0 or x > size.x + 1 or y > size.y + 1:
		return
	var i := y * (size.x + 2) + x
	bytes[i * 2] = ground
	bytes[i * 2 + 1] = flag_of[deco] if deco >= 0 and deco < flag_of.size() else 0
	_filled[i] = 1


## 덮개 값을 바로 넣는다(바깥 맵 0-10: 0 없음 · 1 벽 · 2 소품 · 3 평평한 구조물).
func put_flag(tx: int, ty: int, ground: int, flag: int) -> void:
	var x := tx - origin.x + 1
	var y := ty - origin.y + 1
	if x < 0 or y < 0 or x > size.x + 1 or y > size.y + 1:
		return
	var i := y * (size.x + 2) + x
	bytes[i * 2] = ground
	bytes[i * 2 + 1] = flag
	_filled[i] = 1


## 구역 안쪽 전부를 한 번에(청크 자료 배열, 행 우선 size.x × size.y).
func fill(ground: Array, deco: Array) -> void:
	var w := size.x + 2
	var nf := flag_of.size()
	for y in size.y:
		var row := y * size.x
		var base := (y + 1) * w + 1
		for x in size.x:
			var dv: int = deco[row + x]
			var i := base + x
			bytes[i * 2] = ground[row + x]
			bytes[i * 2 + 1] = flag_of[dv] if dv >= 0 and dv < nf else 0
			_filled[i] = 1


## 구역 안쪽 전부를 RG8 행 복사로(월드 청크 1-1: 바닥·덮개 값이 교대로 든 src[off …], 행 우선 size.x × size.y).
## 덮개 값은 바로 넣는다(put_flag와 같다). 칸마다 부르는 put보다 수십 배 빠르다(붙이기 예산 4ms).
func fill_rg(src: PackedByteArray, off: int) -> void:
	var w := size.x + 2
	var edge := PackedByteArray()
	edge.resize(2)
	var out := PackedByteArray()
	out.resize(w * 2)
	var fil := PackedByteArray()
	fil.resize(w)
	var frow := PackedByteArray()
	frow.resize(w)
	frow.fill(1)
	frow[0] = 0
	frow[w - 1] = 0
	for y in size.y:
		out.append_array(edge)
		out.append_array(src.slice(off + y * size.x * 2, off + (y + 1) * size.x * 2))
		out.append_array(edge)
		fil.append_array(frow)
	var tail := PackedByteArray()
	tail.resize(w * 2)
	out.append_array(tail)
	var ft := PackedByteArray()
	ft.resize(w)
	fil.append_array(ft)
	bytes = out
	_filled = fil


## 아직 이웃 자료가 없는 테두리 칸은 가장자리 칸을 늘려 채운다.
func pad() -> void:
	var w := size.x + 2
	var h := size.y + 2
	var ring: Array[Vector2i] = []
	for x in w:
		ring.append(Vector2i(x, 0))
		ring.append(Vector2i(x, h - 1))
	for y in range(1, h - 1):
		ring.append(Vector2i(0, y))
		ring.append(Vector2i(w - 1, y))
	for p in ring:
		var i := p.y * w + p.x
		if _filled[i] == 0:
			var j := clampi(p.y, 1, size.y) * w + clampi(p.x, 1, size.x)
			bytes[i * 2] = bytes[j * 2]
			bytes[i * 2 + 1] = bytes[j * 2 + 1]


func commit() -> void:
	img = Image.create_from_data(size.x + 2, size.y + 2, false, Image.FORMAT_RG8, bytes)
	if tex == null:
		tex = ImageTexture.create_from_image(img)
		mat.set_shader_parameter("id_map", tex)
	else:
		tex.update(img)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(size * 32)), Color.WHITE)
