## 입력 맵 (SD-11 §2.3 키보드+마우스·패드. 터치는 단계 T 후반 touch_ui.gd).
## project.godot에 이벤트 직렬화를 두지 않고 시작할 때 코드로 만든다(데이터로 옮기기 쉽게).
extends Node

const KEYS := {
	"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT], "run_toggle": [KEY_CAPSLOCK], "walk_hold": [KEY_SHIFT],
	"interact": [KEY_E, KEY_ENTER], "reload": [KEY_R], "crouch": [KEY_C], "debug": [KEY_F3],
	"save": [KEY_F5], "load": [KEY_F9],
}


func _ready() -> void:
	for a in KEYS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		for k in KEYS[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0); _axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0); _axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0); _axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button("interact", JOY_BUTTON_A)
	_button("reload", JOY_BUTTON_X)


func _mouse(a: String, b: MouseButton) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a)
	var e := InputEventMouseButton.new()
	e.button_index = b
	InputMap.action_add_event(a, e)


func _axis(a: String, ax: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = ax
	e.axis_value = v
	InputMap.action_add_event(a, e)


func _button(a: String, b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	InputMap.action_add_event(a, e)
