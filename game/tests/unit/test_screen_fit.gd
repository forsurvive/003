## 화면 맞춤 규칙(SD-12 §17.3 표 전 행): 정수 배율과 논리 해상도
extends RefCounted

const ROWS := [[Vector2i(1920, 1080), 3, Vector2i(640, 360)], [Vector2i(1920, 1200), 3, Vector2i(640, 400)],
	[Vector2i(1366, 768), 2, Vector2i(683, 384)], [Vector2i(2400, 1080), 3, Vector2i(800, 360)],
	[Vector2i(2532, 1170), 3, Vector2i(844, 390)], [Vector2i(1600, 720), 2, Vector2i(800, 360)],
	[Vector2i(2048, 1536), 3, Vector2i(682, 480)], [Vector2i(2360, 1640), 3, Vector2i(786, 480)],
	[Vector2i(2176, 1812), 3, Vector2i(725, 480)], [Vector2i(5120, 1440), 4, Vector2i(854, 360)]]


func test_expand_table(t) -> void:
	var fit = load("res://systems/display/screen_fit.gd")
	for r in ROWS:
		var got: Array = fit.fit(r[0], "expand")
		t.eq(got[0], r[1], "%s 배율" % r[0])
		t.eq(got[1], r[2], "%s 논리 해상도" % r[0])


func test_letterbox(t) -> void:
	var fit = load("res://systems/display/screen_fit.gd")
	for r in ROWS:
		var got: Array = fit.fit(r[0], "letterbox")
		t.eq(got, [r[1], Vector2i(640, 360)], "%s 띠" % r[0])
