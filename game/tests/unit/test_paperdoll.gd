## 페이퍼돌 v2 메타 정합과 층 배치: 몸 컷마다 머리 앵커, 머리 시트·장비 층, 조준 분리, 구르기
extends RefCounted


func test_meta_complete(t) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/paperdoll/paperdoll.json"))
	t.eq(int(meta["version"]), 2, "v2")
	for key in meta["families"]:
		var f: Dictionary = meta["families"][key]
		for mo in f["motions"]:
			for v in ["S", "SE", "E", "NE", "N"]:
				for i in int(f["motions"][mo]["count"]):
					t.ok(f["head"].has("%s:%s:%d" % [v, mo, i]), "%s %s %s %d 머리 앵커" % [key, mo, v, i])
		t.ok(ResourceLoader.exists("res://assets/paperdoll/" + f["sheet"]), key + " 몸 시트")
	for hr in ["HR00", "HR03", "HR06", "HR07", "HR07h", "HR11"]:
		t.ok(meta["heads"].has("M1:" + hr) and meta["heads"].has("F1:" + hr), hr + " 머리 시트")
	t.eq(meta["overlays"].size(), 27, "머리 장비 19(1-D6 HD19 방독면) + 눈 장비 8")
	t.eq((meta["faces"] as Array).size(), 5, "표정 5")
	for k in ["S1", "S3", "S6", "SG1"]:
		t.eq(meta["palettes"]["skin"][k].size(), 5, "피부 램프 5")


func test_head_rides_body(t) -> void:
	var d := Paperdoll.new()
	d.show_frame("walk", 0, 2)
	var a: Array = d.fam["head"]["E:walk:2"]
	t.eq(d.head_root.position, Vector2(a[0], a[1]), "머리는 그 컷의 앵커에")
	d.show_frame("walk", 4, 2)
	t.eq(d.head_root.position, Vector2(-a[0], a[1]), "W는 반전")
	t.ok(d.body.flip_h and d.head.flip_h, "몸·머리 반전")
	d.set_look({"gear": "HD05", "hair": "HR07"})
	t.ok(d.gear.visible, "모자 층")
	t.ok(String(d.head.texture.resource_path).ends_with("hr07h.png"), "쪽머리는 모자 아래 판")
	d.set_look({"torso": "T10"})
	t.ok(not d.gear.visible, "방호복 후드는 머리 장비를 가린다")
	d.free()


## 조준 분리(SD-16 §5.10): 몸은 이동 방향, 머리·무기는 조준 방향
func test_aim_split(t) -> void:
	var d := Paperdoll.new()
	d.set_look({"weapon": "pistol", "gear": "HD04"})
	d.show_aim("run", 4, 1, 0)                                   # 서쪽으로 달리며 동쪽 조준
	t.ok(d.body.flip_h, "몸은 서쪽(반전)")
	t.ok(not d.head.flip_h and not d.gear.flip_h, "머리·장비는 동쪽")
	t.eq(d.head.frame % 5, 2, "머리 E 열")
	t.eq(d.gun.frame, 2, "무기 E")
	t.ok(d.gun.position.x + 10.0 > 0.0, "무기(칸 가운데)는 오른손 쪽")
	d.show_aim("idle", 2, 0, 6)
	t.eq(d.gun.z_index, -1, "위를 겨누면 무기는 몸 뒤")
	d.flash_face("fire", 0.2)
	t.eq(int(d.head.frame / 5), 2, "쏠 때 찡그린 얼굴")
	d.tick(0.3)
	t.ok(int(d.head.frame / 5) in [0, 1], "시간이 지나면 평소 얼굴")
	d.free()


func test_roll(t) -> void:
	var d := Paperdoll.new()
	d.show_roll(0, 2)
	t.ok(absf(d.head_root.rotation) > 1.0, "구르는 중 머리가 돈다")
	d.show_frame("idle", 2, 0)
	t.eq(d.head_root.rotation, 0.0, "서면 바로")
	d.free()
