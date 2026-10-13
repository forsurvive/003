## 입력 맵 (SD-11 §2.3 키보드+마우스·패드. 터치는 touch_ui.gd).
## Shift 질주, Space 회피 구르기, Q 집중 사격, CapsLock 걷기 토글, 1·2 단축키(무기). 상호작용(패드 X 길게)은 대화 시스템과 함께.
## 고전 조작(키보드 단독): Z 공격·X 정조준(바라보는 방향 + 자동 조준 원뿔 — InteriorCombat.auto_aim).
## project.godot에 이벤트 직렬화를 두지 않고 시작할 때 코드로 만든다(데이터로 옮기기 쉽게).
extends Node

const KEYS := {
	"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT], "walk_toggle": [KEY_CAPSLOCK], "sprint": [KEY_SHIFT],
	"dodge": [KEY_SPACE], "focus": [KEY_Q], "slot_1": [KEY_1], "slot_2": [KEY_2], "holster": [KEY_F],
	"interact": [KEY_E, KEY_ENTER], "reload": [KEY_R], "crouch": [KEY_CTRL], "debug": [KEY_F3],
	"save": [KEY_F5], "load": [KEY_F9], "pipboy": [KEY_TAB], "stimpak": [KEY_H],
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
	_key("fire", KEY_Z)                               # 고전 조작(키보드 단독, SD-11 §2.3): Z 공격 · X 정조준
	_key("aim", KEY_X)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0); _axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0); _axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0); _axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button("dodge", JOY_BUTTON_A)
	_button("focus", JOY_BUTTON_RIGHT_SHOULDER)
	_button("sprint", JOY_BUTTON_LEFT_STICK)          # 문서는 토글: 시험판은 누르는 동안(토글은 옵션 화면과 함께)
	_button("reload", JOY_BUTTON_X)
	_button("crouch", JOY_BUTTON_B)
	_button("holster", JOY_BUTTON_Y)


func _mouse(a: String, b: MouseButton) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a)
	var e := InputEventMouseButton.new()
	e.button_index = b
	InputMap.action_add_event(a, e)


func _key(a: String, k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
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
