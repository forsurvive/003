## 머리 위 혼잣말 말풍선(1-13i — 길 위 순찰원끼리 떠드는 말 · 엿보는 장면): 인물(Actor) 노드의 자식으로 붙어 secs 뒤 사라진다.
## 대화 창을 열지 않는다(주인공이 다가가 말을 걸면 그때 장면). 그림은 적 말풍선(enemy.gd _draw)과 같은 결 — 흰 종이 · 먹 테.
class_name ChatBubble
extends Node2D

static var font: Font
var text := ""
var left := 0.0


static func pop(who: Node2D, line: String, secs: float = 3.2) -> ChatBubble:
	if who == null or not is_instance_valid(who):
		return null
	for c in who.get_children():                                         # 한 사람에 하나 — 새 말이 앞 말을 밀어낸다
		if c is ChatBubble:
			c.queue_free()
	if font == null:
		font = load("res://assets/fonts/Galmuri9.ttf")
	var b := ChatBubble.new()
	b.text = line
	b.left = secs
	b.z_index = 40
	var top := -39.0
	if who.has_method("head_y"):
		top = float(who.call("head_y"))
	b.position = Vector2(0, top - 6.0)
	who.add_child(b)
	return b


func _process(dt: float) -> void:
	left -= dt
	if left <= 0.0:
		queue_free()
		return
	modulate.a = clampf(left / 0.4, 0.0, 1.0)                          # 마지막 0.4초에 옅어진다
	queue_redraw()


func _draw() -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var bp := Vector2(-tw / 2.0 - 3.0, -14.0)
	draw_rect(Rect2(bp, Vector2(tw + 6.0, 12.0)), Color(0.96, 0.94, 0.88, 0.92))
	draw_rect(Rect2(bp, Vector2(tw + 6.0, 12.0)), Color("1a181d"), false, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(0, 2)]), Color(0.96, 0.94, 0.88, 0.92))   # 꼬리
	draw_string(font, bp + Vector2(3, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("1a181d"))
