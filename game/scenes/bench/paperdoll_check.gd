## 페이퍼돌 검증 장면: (1) 셰이더가 굽은 합성본과 픽셀 단위로 같은지 비교용 배치, (2) 장비·색 교체 전시.
## 실행: godot --path game res://scenes/bench/paperdoll_check.tscn --write-movie out.png --fixed-fps 1 --quit-after 2
extends Node2D

const CASES := [["T01", "idle", 2, 0], ["T01", "idle", 0, 0], ["T01", "walk", 0, 2], ["T01", "walk", 1, 4],
	["T01", "run", 7, 3], ["T06", "idle", 2, 0], ["T03", "walk", 6, 1], ["T02", "run", 3, 5]]
const REF := {"T01": "pc_comp_t01_pf00_loco", "T02": "pc_comp_t02_pf00_loco", "T03": "pc_comp_t03_pf00_loco",
	"T06": "pc_comp_t06_pf01_loco"}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("2b2830"))
	# 위 줄: 페이퍼돌(셰이더) / 둘째 줄: 굽은 합성본(참조). 같은 칸 = 같은 그림이어야 한다.
	for i in CASES.size():
		var c: Array = CASES[i]
		var d := Paperdoll.new()
		d.set_look({"torso": c[0]})
		d.position = Vector2(40 + i * 72, 80)
		d.show_frame(c[1], c[2], c[3])
		add_child(d)
		var r := AnimatedSprite2D.new()
		r.sprite_frames = load("res://assets/sprites/%s.tres" % REF[c[0]])
		var a: Array = Locomotion.anim_for(c[1], c[2])
		r.animation = a[0]
		r.flip_h = a[1]
		r.frame = c[3]
		r.centered = false
		r.offset = Vector2(-32, -60)
		r.position = Vector2(40 + i * 72, 160)
		add_child(r)
	# 셋째 줄: 장비·색 교체 전시
	var looks := [{"torso": "T01", "hair": "HR05", "hair_color": "H6"}, {"torso": "T01", "gear": "HD05", "skin": "S5"},
		{"torso": "T02", "gear": "HD03", "eyes": "EY01"}, {"torso": "T06", "gear": "HD04", "faction": "PF-01"},
		{"torso": "T06", "gear": "HD04", "faction": "PF-05"}, {"torso": "T02", "faction": "PF-12", "hair": "HR08", "hair_color": "H4"},
		{"torso": "T03", "hair": "HR09", "hair_color": "H7", "skin": "S1"}, {"torso": "T03", "eyes": "EY05", "gear": "HD02", "skin": "SG1"}]
	for i in looks.size():
		var d := Paperdoll.new()
		d.set_look(looks[i])
		d.position = Vector2(40 + i * 72, 260)
		d.show_frame("walk", [2, 1, 0, 7, 6, 5, 4, 3][i], 2)
		add_child(d)
	var f: Font = load("res://assets/fonts/Galmuri9.ttf")
	for row in [["페이퍼돌(셰이더)", 18], ["굽은 합성본(참조)", 98], ["장비·색 교체", 198]]:
		var l := Label.new()
		l.text = row[0]
		l.position = Vector2(4, row[1])
		l.add_theme_font_override("font", f)
		l.add_theme_font_size_override("font_size", 10)
		add_child(l)
