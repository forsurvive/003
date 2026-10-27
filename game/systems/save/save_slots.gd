## 저장 칸 종류(SD-12 §13.1·§17.6, SD-19 §6.10, 단계 0-11): 수동 60 · 빠른 1 · 자동 3(순환) · 중단 1(모바일, 불러온 뒤 지움) · 시스템 1(볼트 출구).
## 파일 하나 = SaveGame 형식(머리 + 몸통, 원자적 쓰기·검사합). 칸 정보(slot)는 목록 화면이 몸통을 풀지 않고도 보이게 머리 옆에 둔다:
## 이름 · 레벨 · 막 · 장소 · 게임 날짜 · 플레이 시간 · 축소 그림(160×90 PNG) · 저장 순번(seq) · 종류 · 실제 시각.
class_name SaveSlots
extends RefCounted

const DIR := "user://saves/"
const MANUAL := 60
const KINDS := ["manual", "quick", "auto", "suspend", "system"]
const KIND_NAME := {"manual": "수동", "quick": "빠른 저장", "auto": "자동", "suspend": "중단", "system": "시스템"}
const AUTO_GAP := 90.0                                ## 자동 저장끼리 최소 간격(초, §13.2)

static var dir := DIR                                 ## 시험이 임시 폴더로 바꾼다
static var pending := ""
static var check := ""                                ## 저장 왕복 시험(--savetest): 저장한 한 장의 SHA-256                              ## 장면을 바꾸며 넘기는 불러올 저장 경로(제목 화면 → 진행기)


static func path_of(kind: String, idx := 0) -> String:
	match kind:
		"manual":
			return dir + "manual_%02d.sav" % idx
		"auto":
			return dir + "auto_%d.sav" % idx
		_:
			return dir + kind + ".sav"


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(dir)


## 제목을 '폴아웃 : 서울'로 바꾸며(사용자 지시 2026-10-27) 저장 폴더도 'Fallout Seoul'로 정했다(':'는 윈도우 폴더 이름에 못 쓴다).
## 새 폴더에 저장이 하나도 없고 옛 제목 폴더(Godot · godot/app_userdata/서울 폴아웃/saves)에 있으면 한 번 옮겨 온다(지우지 않고 복사). 옮긴 수를 돌려준다
const OLD_DIRS := ["Godot/app_userdata/서울 폴아웃/saves", "godot/app_userdata/서울 폴아웃/saves"]   # 윈도우 · 맥 / 리눅스


static func migrate_old(old_dir: String = "") -> int:
	if old_dir == "":
		for d in OLD_DIRS:
			if DirAccess.dir_exists_absolute(OS.get_data_dir().path_join(d)):
				old_dir = OS.get_data_dir().path_join(d)
				break
	if old_dir == "" or not DirAccess.dir_exists_absolute(old_dir) or not list().is_empty():
		return 0
	ensure_dir()
	var n := 0
	for f in DirAccess.get_files_at(old_dir):
		if f.ends_with(".sav") and DirAccess.copy_absolute(old_dir.path_join(f), dir + f) == OK:
			n += 1
	return n


## 모든 칸의 정보(빈 칸은 빠진다). 반환: [{"kind", "idx", "path", "slot", "ok", "error"}] — 최근 순
static func list() -> Array:
	var out := []
	var paths := []
	for i in MANUAL:
		paths.append(["manual", i])
	paths.append(["quick", 0])
	for i in 3:
		paths.append(["auto", i])
	paths.append(["suspend", 0])
	paths.append(["system", 0])
	for p in paths:
		var path := path_of(p[0], p[1])
		if not FileAccess.file_exists(path):
			continue
		var r := SaveGame.read(path)
		out.append({"kind": p[0], "idx": p[1], "path": path, "slot": r.get("slot", {}), "ok": r["ok"], "error": r.get("error", "")})
	out.sort_custom(func(a, b): return int(a["slot"].get("seq", 0)) > int(b["slot"].get("seq", 0)))
	return out


## 다음 저장 순번(모든 칸에서 가장 큰 seq + 1)
static func next_seq() -> int:
	var hi := 0
	for e in list():
		hi = maxi(hi, int(e["slot"].get("seq", 0)))
	return hi + 1


## 자동 저장이 쓸 칸: 비었거나 가장 오래된 칸(3칸 순환)
static func auto_index() -> int:
	var best := 0
	var low := 1 << 62
	for i in 3:
		var path := path_of("auto", i)
		var s := -1
		if FileAccess.file_exists(path):
			var r := SaveGame.read(path)
			s = int(r["slot"].get("seq", 0)) if r["ok"] else -1
		if s < low:
			low = s
			best = i
	return best


## 쓰기: slot(칸 정보)과 world(게임 상태)를 원자적으로. 반환 Error
static func write(kind: String, idx: int, slot: Dictionary, world: Dictionary) -> Error:
	ensure_dir()
	var s := slot.duplicate()
	s["kind"] = kind
	s["idx"] = idx
	s["seq"] = next_seq()
	s["real_time"] = Time.get_datetime_string_from_system(false, true)
	return SaveGame.write_atomic(path_of(kind, idx), SaveGame.encode(s, world))


static func read(kind: String, idx := 0) -> Dictionary:
	return SaveGame.read(path_of(kind, idx))


static func erase(kind: String, idx := 0) -> void:
	var p := path_of(kind, idx)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)


## 메인 메뉴 '이어하기'(§17.6): 중단 저장이 있으면 그것, 없으면 가장 최근의 온전한 칸
static func continue_path() -> String:
	if FileAccess.file_exists(path_of("suspend")) and SaveGame.read(path_of("suspend"))["ok"]:
		return path_of("suspend")
	for e in list():
		if e["ok"]:
			return e["path"]
	return ""


## 칸 정보 한 줄(목록 화면): "수동 3 · 윤서진 Lv2 · 1막 · 봉천 계단마을 · 2277. 10. 23. 22:40 · 0:42"
static func describe(e: Dictionary) -> String:
	var s: Dictionary = e.get("slot", {})
	if not e.get("ok", false):
		return "%s — 손상된 저장(%s)" % [label(e), str(e.get("error", ""))]
	var pt := int(s.get("play_time", 0))
	return "%s · %s Lv%d · %s · %s · %s · %d:%02d" % [label(e), str(s.get("name", "")), int(s.get("level", 1)), str(s.get("act", "")),
		str(s.get("place", "")), str(s.get("date", "")).strip_edges(), pt / 3600, (pt / 60) % 60]


## 목록 한 줄(짧게): "수동 3 · 봉천 계단마을 · 10. 23. 22:40" — 나머지는 오른쪽 미리 보기에
static func short(e: Dictionary) -> String:
	if not e.get("ok", false):
		return label(e) + " — 손상"
	var s: Dictionary = e.get("slot", {})
	var place := str(s.get("place", "")).get_slice(" · ", str(s.get("place", "")).count(" · "))
	var date := str(s.get("date", "")).strip_edges().replace("2277. ", "").replace("  ", " ")
	return "%s · %s · %s" % [label(e), place, date]


static func label(e: Dictionary) -> String:
	var k := str(e.get("kind", ""))
	if k == "manual":
		return "수동 %d" % (int(e.get("idx", 0)) + 1)
	if k == "auto":
		return "자동 %d" % (int(e.get("idx", 0)) + 1)
	return str(KIND_NAME.get(k, k))
