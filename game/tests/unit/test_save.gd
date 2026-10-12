## SD-19 §6.10 저장 왕복: 저장 → 불러오기 → 저장 두 결과가 바이트 단위로 같다
extends RefCounted


func _sample() -> Dictionary:
	return {
		"time": {"date": "2277-10-23", "minutes": 1393, "play_sec": 3725.25},
		"player": {"pos": Vector2(5731.5, 5612.0), "hp": 180.0, "mag": 7, "weapon": "W-002", "facing": 6,
			"special": PackedInt32Array([5, 6, 4, 5, 7, 5, 5]), "rng_state": 1234567890123},
		"enemies": [{"id": "CR-002", "pos": Vector2(6401.0, 6016.5), "hp": 0.0, "dead": true, "state": 6, "gauge": 100.0},
			{"id": "CR-401", "pos": Vector2(5000.25, 6250.0), "hp": 61.8, "dead": false, "state": 3, "gauge": 100.0}],
		"chunk_changes": {"C-04-04": {817: 6, 818: -1}},
		"vars": {"V_ACT": 0, "MQP1_RESULT": 1, "AFF_YH": -5, "K_LINE": true},
	}


func test_roundtrip_bytes(t) -> void:
	var slot := {"name": "한서진", "level": 1, "act": "프롤로그", "where": "관악산 비탈", "thumb": PackedByteArray([1, 2, 3])}
	var a := SaveGame.encode(slot, _sample())
	var d := SaveGame.decode(a)
	t.ok(d["ok"], "불러오기 성공")
	var b := SaveGame.encode(d["slot"], d["world"])
	t.eq(a, b, "저장 → 불러오기 → 저장 바이트 동일")
	t.eq(d["world"], _sample(), "세계 상태 깊은 비교 동일")
	t.eq(typeof(d["world"]["player"]["mag"]), TYPE_INT, "정수는 정수로 돌아온다(JSON 왕복의 함정)")


func test_corruption_and_atomic(t) -> void:
	var a := SaveGame.encode({"name": "x"}, _sample())
	var bad := a.duplicate()
	bad[bad.size() - 3] = bad[bad.size() - 3] ^ 0xFF
	t.eq(SaveGame.decode(bad)["ok"], false, "몸통 1바이트 손상 -> 거부")
	t.eq(SaveGame.decode(PackedByteArray([1, 2, 3]))["ok"], false, "형식 표시 없음 -> 거부")
	var path := "user://test_slot.sav"
	t.eq(SaveGame.write_atomic(path, a), OK, "원자적 저장")
	t.ok(not FileAccess.file_exists(path + ".tmp"), "임시 파일 남지 않음")
	t.eq(SaveGame.read(path)["world"], _sample(), "파일 왕복")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 자동 저장 3칸 순환: 빈 칸부터 채우고, 가득 차면 가장 오래된 칸에 쓴다. 손상된 칸은 최신 판정에서 빠진다.
func test_autosave_rotation(t) -> void:
	for p in SaveGame.auto_paths():
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var order := []
	for i in 5:
		var nx := SaveGame.next_auto()
		SaveGame.write_atomic(nx[0], SaveGame.encode({"seq": nx[1]}, {"i": i}))
		order.append((nx[0] as String).get_file())
	t.eq(order, ["auto_0.sav", "auto_1.sav", "auto_2.sav", "auto_0.sav", "auto_1.sav"], "순환 순서")
	t.eq(SaveGame.latest_auto().get_file(), "auto_1.sav", "최신 = seq 5")
	var f := FileAccess.open(SaveGame.AUTO % 1, FileAccess.READ_WRITE)
	f.seek(f.get_length() - 3)
	f.store_8(0x5A)
	f.close()
	t.eq(SaveGame.latest_auto().get_file(), "auto_0.sav", "손상된 최신 칸은 건너뛰고 그다음(seq 4)")
	for p in SaveGame.auto_paths():
		DirAccess.remove_absolute(p)
