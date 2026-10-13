## 벽면 문패(단계 0-5): 남색 판 + 흰 글자. 노드 위치 = 정렬 기준(벽 아랫변), lift만큼 위에 그린다.
## 글자 길이에 맞춰 폭이 정해진다(소품 그림 props_s07.sign_plate와 같은 모양).
class_name SignPlate
extends Node2D

const BG := Color("1F3A6E")
const HI := Color("4C7DC8")
const INK := Color("0B0A0D")
const FG := Color("E9E4D8")

var text := ""
var lift := 62.0
static var font: Font


func _ready() -> void:
	if font == null:
		font = load("res://assets/fonts/Galmuri7.ttf")


func _draw() -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := maxf(24.0, roundf(tw) + 8.0)
	var r := Rect2(-roundf(w / 2.0), -lift, w, 11)
	draw_rect(r.grow(1), INK)
	draw_rect(r, BG)
	draw_line(r.position + Vector2(0, 0.5), r.position + Vector2(r.size.x, 0.5), HI)
	draw_string(font, Vector2(-roundf(tw / 2.0), r.position.y + 1 + font.get_ascent(8)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, FG)
