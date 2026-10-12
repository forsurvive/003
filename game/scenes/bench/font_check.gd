## 글꼴 확인 장면 (SD-19 §6 폰트 행, SD-12 §14): 10px 갈무리9 · 12px 갈무리11 · 16px Neo둥근모 Pro.
## ① 현대 한글 11,172자 전부와 문장 부호의 글리프가 있는가 ② 1배 화면에서 글자 칸에 중간색이 없는가(안티앨리어싱·힌팅·
## 하위 픽셀 끔이 먹었는가) ③ 같은 문장의 폭·높이. 결과를 출력하고 user://font_check.png로 남긴다.
## 실행: godot --path game res://scenes/bench/font_check.tscn (렌더링이 필요하다. 헤드리스 불가)
extends Node2D

const FONTS := [["갈무리9", "res://assets/fonts/Galmuri9.ttf", 10], ["갈무리11", "res://assets/fonts/Galmuri11.ttf", 12],
	["Neo둥근모 Pro", "res://assets/fonts/NeoDunggeunmoPro.ttf", 16]]
const LINES := ["볼트 거주자는 문을 열었다. 「관악산 비탈」로 가자!", "HP 186/200 · AP 75 · 10mm 권총 12/12 · ₩1,250",
	"쀍 똠 꽦 뷁 햏 — 겹받침·드문 글자", "0123456789 ABCDEFGHIJ abcdefghij !?.,:;()[]«»…"]
const FG := Color("e9e4d8")
const BG := Color("0b0a0d")
var _fonts: Array = []
var _rows: Array = []                          ## [y0, y1] 글자 줄 영역(검사용)
var _frame := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG)
	for f in FONTS:
		var ff: FontFile = load(f[1])
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_fonts.append(ff)


func _draw() -> void:
	var y := 4
	_rows.clear()
	for i in FONTS.size():
		var sz: int = FONTS[i][2]
		draw_string(_fonts[i], Vector2(4, y + sz - 2), "%s %dpx" % [FONTS[i][0], sz], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color("e8c23a"))
		y += sz + 2
		var r0 := y
		for line in LINES:
			draw_string(_fonts[i], Vector2(4, y + sz - 2), line, HORIZONTAL_ALIGNMENT_LEFT, 632, sz, FG)
			y += sz + 2
		_rows.append([r0, y])
		y += 4


func _process(_dt: float) -> void:
	_frame += 1
	if _frame == 4:
		_report()
		get_tree().quit()


func _report() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://font_check.png")
	var hangul := 0
	for i in FONTS.size():
		var ff: FontFile = _fonts[i]
		var miss := 0
		for c in range(0xAC00, 0xD7A4):
			if not ff.has_char(c):
				miss += 1
		var punct_miss := []
		for ch in "「」·—…«»₩!?":
			if not ff.has_char(ch.unicode_at(0)):
				punct_miss.append(ch)
		# 글자 줄 영역 색 세기: 배경·글자색 말고 다른 색이 있으면 중간색(번짐)
		var mixed := 0
		var colors := {}
		for yy in range(_rows[i][0], mini(_rows[i][1], img.get_height())):
			for xx in img.get_width():
				var c := img.get_pixel(xx, yy)
				colors[c.to_html(false)] = true
				if not c.is_equal_approx(FG) and not c.is_equal_approx(BG):
					mixed += 1
		var sz: int = FONTS[i][2]
		var w := ff.get_string_size(LINES[0], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		print("%s %dpx: 한글 11,172자 중 없는 글자 %d, 없는 부호 %s, 1배 화면 중간색 픽셀 %d(색 %d가지), 첫 문장 폭 %dpx(%.1f자/640px)" % [
			FONTS[i][0], sz, miss, "".join(punct_miss) if punct_miss.size() > 0 else "0", mixed, colors.size(), int(w),
			640.0 / (w / LINES[0].length())])
		hangul += miss
	print("글꼴 확인 끝: user://font_check.png")
