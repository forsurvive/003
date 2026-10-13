## 페이퍼돌 v2 검증 장면: 위 줄 = 실행 중 페이퍼돌(인덱스 시트 + 팔레트 셰이더), 둘째 줄 = 같은 외형의 대조 합성본
## (art/tools/chibi.actor가 그린 것). 같은 칸은 픽셀 단위로 같아야 한다. 셋째 줄은 장비·색 교체 전시.
## 실행: godot --path game res://scenes/bench/paperdoll_check.tscn --write-movie out.png --fixed-fps 1 --quit-after 2
extends Node2D

const X0 := 32
const DX := 48


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("2b2830"))
	Paperdoll._load_meta()
	var refs: Array = Paperdoll.meta["refs"]
	for i in refs.size():
		var c: Dictionary = refs[i]
		var d := Paperdoll.new()
		d.set_process(false)                                        # 눈 깜박임 없이 고정
		d.set_look(c["look"])
		d.position = Vector2(X0 + i * DX, 70)
		if int(c["aim"]) >= 0:
			d.show_aim(c["motion"], int(c["dir"]), int(c["frame"]), int(c["aim"]))
		else:
			d.show_frame(c["motion"], int(c["dir"]), int(c["frame"]))
		add_child(d)
		var r := Sprite2D.new()
		r.texture = load("res://assets/paperdoll/" + c["png"])
		r.centered = false
		r.offset = Vector2(-20, -44)
		r.position = Vector2(X0 + i * DX, 140)
		add_child(r)
	var looks := [{"hair": "HR05", "hair_color": "H6"}, {"gear": "HD05", "skin": "S5"}, {"torso": "T02", "gear": "HD03", "eyes": "EY01"},
		{"torso": "T06", "gear": "HD04", "faction": "PF-01", "weapon": "rifle"}, {"torso": "T06", "gear": "HD04", "faction": "PF-05"},
		{"torso": "T04", "hair": "HR08", "hair_color": "H4"}, {"body": "F1", "torso": "T14", "hair": "HR09", "hair_color": "H7", "skin": "S1"},
		{"torso": "T10"}, {"torso": "T03", "eyes": "EY06", "gear": "HD02", "skin": "SG1"}, {"body": "F1", "torso": "GOWN", "hair": "HR06"},
		{"torso": "T11", "eyes": "EY05", "hair": "HR02"}, {"torso": "T09", "gear": "HD13", "faction": "PF-03"}]
	for i in looks.size():
		var d := Paperdoll.new()
		d.set_process(false)
		d.set_look(looks[i])
		d.position = Vector2(X0 + i * DX, 230)
		d.show_frame("walk", [2, 1, 0, 7, 6, 5, 4, 3][i % 8], 2)
		add_child(d)
	var f: Font = load("res://assets/fonts/Galmuri9.ttf")
	for row in [["페이퍼돌(셰이더)", 4], ["대조 합성본", 78], ["장비·색 교체", 166]]:
		var l := Label.new()
		l.text = row[0]
		l.position = Vector2(4, row[1])
		l.add_theme_font_override("font", f)
		l.add_theme_font_size_override("font_size", 10)
		add_child(l)
