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
