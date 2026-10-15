## 대기·수면 창(단계 1-8b, SD-12 §7.6 · SD-11 §11.5): 1~24시간 막대에서 시간을 고르고 '기다린다/잔다'.
## 침대면 잔다(HP·부위 전부 회복, 시간 길이와 무관). 소유 침대(거처·돈 낸 숙소)면 숙면(경험치 +10%, 12시간) 안내를 함께 보인다.
## 핍-보이 녹색 화면 틀. 키: ◀▶ 시간 · ▲▼ 칸 · 결정 · 취소(Esc/Tab). 마우스·터치: ◀▶ 자리를 누르면 조정, 단추를 누르면 결정.
class_name WaitScreen
extends DocScreen

var hours := 1
var bed := ""                 ## 침대 이름(비면 그냥 기다리기)
var owned := false            ## 소유 침대(숙면)
var now := ""                 ## 지금 날짜·시각 글(예: "2277. 10. 24.  10:20")


func setup(state: StoryState, now_text: String, bed_name: String = "", is_owned: bool = false) -> WaitScreen:
	st = state
	now = now_text
	bed = bed_name
	owned = is_owned
	hours = 8 if bed != "" else 1
	cancel_ok = true
	return self


func _adjust(id: String, d: int) -> void:
	if id == "hours":
		hours = clampi(hours + d, 1, 24)


func _press(id: String) -> void:
	match id:
		"ok":
			close(true)
		"cancel":
			close(false)
		"hours":
			focus_on("ok")


func _draw_doc() -> void:
	var g := GREEN
	var r := Rect2(170, 92, 300, 176)
	view.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.55))
	view.draw_rect(r, g[0])
	view.draw_rect(r, g[4], false, 2.0)
	view.draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), g[2], false, 1.0)
	var title := ("잠자기 — " + bed) if bed != "" else "기다리기"
	view.draw_string(f12b, r.position + Vector2(14, 24), title, HORIZONTAL_ALIGNMENT_LEFT, 272, 12, g[6])
	view.draw_line(r.position + Vector2(10, 32), r.position + Vector2(290, 32), g[3])
	# 시간 막대(1~24): 칸 24개, 고른 시간까지 밝게
	var bar := Rect2(r.position + Vector2(36, 48), Vector2(228, 14))
	var l := Rect2(r.position + Vector2(12, 46), Vector2(18, 18))
	var rr := Rect2(r.position + Vector2(270, 46), Vector2(18, 18))
	var on := item("hours", Rect2(r.position + Vector2(8, 42), Vector2(284, 26)), true, true, l, rr)
	for i in 24:
		var x := bar.position.x + i * 9.5
		view.draw_rect(Rect2(x, bar.position.y, 8, bar.size.y), g[5] if i < hours else g[1])
	view.draw_string(f12, l.position + Vector2(3, 14), "◀", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, g[6] if on else g[4])
	view.draw_string(f12, rr.position + Vector2(3, 14), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, g[6] if on else g[4])
	if on:
		view.draw_rect(Rect2(r.position + Vector2(8, 42), Vector2(284, 26)), g[4], false, 1.0)
	view.draw_string(f15, r.position + Vector2(14, 92), "%d시간" % hours, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, g[7])
	var wake := Clock.add_hours(now, hours) if now != "" else ""
	view.draw_string(f10, r.position + Vector2(96, 90), ("깨는 때  " if bed != "" else "끝나는 때  ") + wake, HORIZONTAL_ALIGNMENT_LEFT, 196, 10, g[5])
	var note := ""
	if bed != "":
		note = "HP·부위 손상을 모두 회복한다." + ("  숙면: 경험치 +10% (12시간)" if owned else "")
	else:
		note = "시간만 흐른다. 회복은 없다."
	view.draw_string(f8, r.position + Vector2(14, 112), note, HORIZONTAL_ALIGNMENT_LEFT, 272, 8, g[5])
	var b1 := Rect2(r.position + Vector2(40, 132), Vector2(100, 26))
	var b2 := Rect2(r.position + Vector2(160, 132), Vector2(100, 26))
	for pair in [["ok", b1, "잔다" if bed != "" else "기다린다"], ["cancel", b2, "그만둔다"]]:
		var sel := item(str(pair[0]), pair[1])
		view.draw_rect(pair[1], g[4] if sel else g[1])
		view.draw_rect(pair[1], g[5], false, 1.0)
		view.draw_string(f12, (pair[1] as Rect2).position + Vector2(0, 17), str(pair[2]), HORIZONTAL_ALIGNMENT_CENTER, (pair[1] as Rect2).size.x, 12, g[0] if sel else g[6])
