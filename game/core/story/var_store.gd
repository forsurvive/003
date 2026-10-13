## 변수 저장소 (SD-19 §6.9): 문자열 키 사전. 타입·기본값은 데이터(game/data/vars.json, 파이프라인이 기획서 변수표에서 뽑는다)에
## 선언되고, 선언되지 않은 키 쓰기는 오류다(빌드 때는 원고 변환기가 먼저 막는다). 저장은 기본값과 다른 값만.
class_name VarStore
extends RefCounted

var decls := {}                 ## 이름 -> {"type": "int"|"str", "default": Variant}
var values := {}                ## 기본값과 다른 값만
var errors: Array[String] = []  ## 실행 중 오류(미선언 키 등) — 디버그 콘솔·시험이 읽는다


func declare(name: String, type: String = "int", default: Variant = null) -> void:
	if default == null:
		default = "" if type == "str" else 0
	decls[name] = {"type": type, "default": default}


func load_decls(path: String) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for k in d["vars"]:
		var v: Dictionary = d["vars"][k]
		declare(k, v["type"], int(v["default"]) if v["type"] == "int" else str(v["default"]))


func has(name: String) -> bool:
	return decls.has(name)


func get_v(name: String) -> Variant:
	if values.has(name):
		return values[name]
	if decls.has(name):
		return decls[name]["default"]
	_err("미선언 변수 읽기: " + name)
	return null


func set_v(name: String, v: Variant) -> bool:
	if not decls.has(name):
		_err("미선언 변수 쓰기: " + name)
		return false
	var d: Dictionary = decls[name]
	if d["type"] == "int":
		if v is String and not v.is_valid_int():
			_err("정수 변수에 문자열: %s = %s" % [name, v])
			return false
		v = int(v)
	else:
		v = str(v)
	if v == d["default"]:
		values.erase(name)
	else:
		values[name] = v
	return true


func add(name: String, delta: int, lo: int = -2147483648, hi: int = 2147483647) -> int:
	var nv := clampi(int(get_v(name) if get_v(name) != null else 0) + delta, lo, hi)
	set_v(name, nv)
	return nv


## 저장: 기본값과 다른 값만(정렬된 사전 — 왕복 바이트가 같게)
func dump() -> Dictionary:
	var out := {}
	var keys := values.keys()
	keys.sort()
	for k in keys:
		out[k] = values[k]
	return out


func restore(d: Dictionary) -> void:
	values.clear()
	for k in d:
		if decls.has(k):
			set_v(k, d[k])
		else:
			_err("저장 파일의 미선언 변수 무시: " + str(k))


func _err(msg: String) -> void:
	errors.append(msg)
	if errors.size() <= 20:
		push_warning(msg)
