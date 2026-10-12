## 일시 정지 화면(SD-19 §6.10·§10.2 공통 행): 트리가 멈춰도 이 층은 돈다. 아무 키·터치·클릭이면 다시 시작한다.
class_name PauseOverlay
extends CanvasLayer

var label: Label


func _init(font: Font) -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.039, 0.051, 0.7)
	bg.size = Vector2(854, 480)
	add_child(bg)
	label = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 12)
	label.position = Vector2(220, 160)
	add_child(label)


func open(text: String) -> void:
	label.text = text
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _input(e: InputEvent) -> void:
	if visible and e.is_pressed() and (e is InputEventKey or e is InputEventScreenTouch or e is InputEventMouseButton):
		close()
		get_viewport().set_input_as_handled()
