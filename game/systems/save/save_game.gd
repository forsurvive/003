## 저장 v0 (SD-19 §6.10, SD-12 §13): 머리(형식 버전·게임 버전·슬롯 정보) + 몸통(세계 상태).
## 직렬화는 엔진 이진 변환(var_to_bytes: 타입 보존 → 왕복 바이트 동일), 디버그 빌드는 JSON 사본을 함께 쓴다.
## 원자적 저장: 임시 파일에 쓰고 검사합을 확인한 뒤 바꿔 넣는다. 형식 버전마다 이전 판 → 다음 판 변환 함수.
class_name SaveGame
extends RefCounted

const FORMAT := 1
const MAGIC := "SFSV"
const GAME_VERSION := "T-0.1"


static func encode(slot: Dictionary, world_state: Dictionary) -> PackedByteArray:
	var body := var_to_bytes({"slot": slot, "world": world_state})
	var head := var_to_bytes({"format": FORMAT, "game": GAME_VERSION, "len": body.size(),
		"sha256": _sha(body)})
	var out := PackedByteArray()
	out.append_array(MAGIC.to_ascii_buffer())
	out.append_array(_u32(head.size()))
	out.append_array(head)
	out.append_array(body)
	return out


## 반환: {ok, error, slot, world}
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 8 or bytes.slice(0, 4).get_string_from_ascii() != MAGIC:
		return {"ok": false, "error": "형식 표시 없음"}
	var hl := bytes.decode_u32(4)
	var head: Dictionary = bytes_to_var(bytes.slice(8, 8 + hl))
	var body := bytes.slice(8 + hl)
	if body.size() != int(head["len"]) or _sha(body) != head["sha256"]:
		return {"ok": false, "error": "검사합 불일치(파일 손상)"}
	var data: Dictionary = bytes_to_var(body)
	data = migrate(int(head["format"]), data)
	return {"ok": true, "error": "", "slot": data["slot"], "world": data["world"]}


## 형식 변환 사슬: 판 n → n+1 함수를 차례로 부른다(공개 1 → 1.0 저장 변환을 단계 7까지 유지).
static func migrate(from_format: int, data: Dictionary) -> Dictionary:
	var f := from_format
	while f < FORMAT:
		f += 1                                              # 판 2가 생기면 여기에 _to_2(data) 를 둔다
	return data


static func write_atomic(path: String, bytes: PackedByteArray) -> Error:
	var tmp := path + ".tmp"
	var fa := FileAccess.open(tmp, FileAccess.WRITE)
	if fa == null:
		return FileAccess.get_open_error()
	fa.store_buffer(bytes)
	fa.close()
	var check := FileAccess.get_file_as_bytes(tmp)
	if check != bytes or not decode(check)["ok"]:
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(tmp, path)


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "파일 없음"}
	return decode(FileAccess.get_file_as_bytes(path))


static func _sha(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(b)
	return h.finish().hex_encode()


static func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b


## 자동 저장 3칸 순환(SD-12 §13.1, SD-19 §6.10). 머리의 seq가 가장 큰 칸이 최신, 가장 작은(또는 빈) 칸에 덮어쓴다.
const AUTO := "user://auto_%d.sav"


static func auto_paths() -> Array:
	return [AUTO % 0, AUTO % 1, AUTO % 2]


## 반환: [쓸 경로, 다음 seq]
static func next_auto() -> Array:
	var best := ""
	var low := 1 << 62
	var high := 0
	for p in auto_paths():
		var r := read(p)
		var s: int = int(r["slot"].get("seq", 0)) if r["ok"] else -1
		high = maxi(high, s)
		if s < low:
			low = s
			best = p
	return [best, high + 1]


## 가장 최근의 온전한 자동 저장(없으면 빈 문자열). 손상된 칸은 건너뛴다.
static func latest_auto() -> String:
	var best := ""
	var high := -1
	for p in auto_paths():
		var r := read(p)
		if r["ok"] and int(r["slot"].get("seq", 0)) > high:
			high = int(r["slot"]["seq"])
			best = p
	return best
