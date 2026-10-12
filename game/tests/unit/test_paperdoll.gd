## 페이퍼돌 메타 정합: 모든 몸통 계열 × 모션 × 방향 × 프레임에 머리 앵커가 있고, 머리 층은 방향 5개를 다 갖는다
extends RefCounted


func test_meta_complete(t) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/paperdoll/paperdoll.json"))
	for fam in ["T01", "T02", "T03", "T06"]:
		var f: Dictionary = meta["families"][fam]
		for mo in f["motions"]:
			if mo in ["aim_idle", "aim_walk", "aim_run"]:               # 하체만 있는 층: 머리는 상체(aim_up) 앵커를 쓴다
				continue
			for v in ["S", "SE", "E", "NE", "N"]:
				for i in int(f["motions"][mo]["count"]):
					t.ok(f["head"].has("%s:%s:%d" % [v, mo, i]), "%s %s %s %d 머리 앵커" % [fam, mo, v, i])
		for mode in ["walk", "run"]:
			for v in ["S", "SE", "E", "NE", "N"]:
				t.eq((f["bob"][mode][v] as Array).size(), 6, "%s %s %s 출렁임 표" % [fam, mode, v])
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


## 조준 분리(SD-16 §5.10): 하체는 이동 방향, 상체·머리 층은 조준 방향 + 출렁임. 구르기는 머리 층을 숨긴다.
func test_aim_split(t) -> void:
	var d := Paperdoll.new()
	d.set_look({"gear": "HD05"})
	d.show_aim("run", 4, 1, 0)                                   # 서쪽으로 달리며(하체 반전) 동쪽 조준
	var f: Dictionary = d.fam
	var cols := d._cols
	t.eq(d.base.frame, 2 * cols + int(f["motions"]["aim_run"]["start"]) + 1, "하체 = 달리기 E행 1컷")
	t.ok(d.base.flip_h, "하체는 서쪽(반전)")
	t.ok(d.upper.visible and not d.upper.flip_h, "상체는 동쪽")
	var dy: int = int(f["bob"]["run"]["E"][1])
	t.eq(d.upper.position, Vector2(0, dy), "상체가 출렁임만큼 내려간다")
	var h: Array = f["head"]["E:aim_up:0"]
	var h0: Array = Paperdoll.meta["overlays"]["HD05"]["head"]["E"]
	t.eq(d.layers["gear"].position, Vector2(h[0] - h0[0], h[1] - h0[1] + dy), "머리 장비는 상체 앵커 + 출렁임")
	t.ok(not d.layers["gear"].flip_h, "머리 장비는 상체를 따라 반전하지 않는다")
	d.show_roll(0, 2)
	t.ok(not d.upper.visible and not d.layers["gear"].visible, "구르기: 상체·머리 층 숨김")
	d.show_frame("idle", 2, 0)
	t.ok(d.layers["gear"].visible and not d.upper.visible, "대기로 돌아오면 머리 층이 다시 보인다")
	d.free()
