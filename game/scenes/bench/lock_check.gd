## 자물쇠 따기 화면 확인(단계 1-5): 인자 "스킨 등급값 각도오차 [보조]" — 각도를 정답에서 오차만큼 떼고 1초 뒤부터 돌린다.
## 실행: xvfb-run godot --path game res://scenes/bench/lock_check.tscn --write-movie out.png --fixed-fps 10 --quit-after 40 -- door 50 25 assist
extends Node2D

var ls: LockScreen
var t := 0.0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var st := StoryState.new()
	st.load_data()
	st.vars.set_v("PC_SKP_LOCKPICK", 50)
	var bg := ColorRect.new()
	bg.color = Color("5a5248")
	bg.size = Vector2(1280, 720)
	add_child(bg)
	ls = LockScreen.new().setup(st, int(a[1]) if a.size() > 1 else 50, 3, a[0] if a.size() > 0 else "door", 5)
	ls.bot_on = true
	ls.assist = a.size() > 3 and a[3] == "assist"
	var off := float(a[2]) if a.size() > 2 else 0.0
	ls.lock.set_angle(ls.lock.target + off if ls.lock.target + off <= 180.0 else ls.lock.target - off)
	add_child(ls)


func _process(dt: float) -> void:
	t += dt
	if ls != null and is_instance_valid(ls):
		ls.bot_turn = t > 1.0
