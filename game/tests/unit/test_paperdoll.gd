## 페이퍼돌 메타 정합: 모든 몸통 계열 × 모션 × 방향 × 프레임에 머리 앵커가 있고, 머리 층은 방향 5개를 다 갖는다
extends RefCounted


func test_meta_complete(t) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/paperdoll/paperdoll.json"))
	for fam in ["T01", "T02", "T03", "T06"]:
		var f: Dictionary = meta["families"][fam]
		for mo in f["motions"]:
			for v in ["S", "SE", "E", "NE", "N"]:
				for i in int(f["motions"][mo]["count"]):
					t.ok(f["head"].has("%s:%s:%d" % [v, mo, i]), "%s %s %s %d 머리 앵커" % [fam, mo, v, i])
	for code in meta["overlays"]:
		for v in ["S", "SE", "E", "NE", "N"]:
			t.ok(meta["overlays"][code]["head"].has(v), "%s %s" % [code, v])
	for k in ["S1", "S3", "S6", "SG1"]:
		t.eq(meta["palettes"]["skin"][k].size(), 5, "피부 램프 5")
	t.eq(meta["palettes"]["master"].size(), 64, "마스터 64")


func test_head_follows_anchor(t) -> void:
	var d := Paperdoll.new()
	d.set_look({"gear": "HD05"})
	d.show_frame("idle", 2, 0)
	t.eq(d.layers["gear"].position, Vector2.ZERO, "대기 컷은 그 자리")
	d.show_frame("walk", 0, 2)
	var h: Array = d.fam["head"]["E:walk:2"]
	var h0: Array = Paperdoll.meta["overlays"]["HD05"]["head"]["E"]
	t.eq(d.layers["gear"].position, Vector2(h[0] - h0[0], h[1] - h0[1]), "걷기 프레임은 머리 앵커 차이만큼")
	d.show_frame("walk", 4, 2)
	t.eq(d.layers["gear"].position.x, -float(h[0] - h0[0]), "W는 반전")
	d.set_look({"hair": "HR07"})
	t.ok(not d.layers["hair"].visible, "정수리 묶음은 모자 아래 숨김")
	d.free()
