## 자물쇠 따기(단계 1-5, SD-12 §8.1·§8.2): 요구치·등급 · 허용 반폭(+스킬 보정 최대 5°) · 최대 회전식 · 열림 · 핀 손상과 소모 ·
## θ* 유지 · 핀 0개 · 강제 개방 확률과 영구 파손 · XP.
extends RefCounted


func test_lockpick_rules(t) -> void:
	t.eq([Lockpick.grade_of(0), Lockpick.grade_of(25), Lockpick.grade_of(50), Lockpick.grade_of(75), Lockpick.grade_of(100)], [0, 1, 2, 3, 4], "자물쇠 값 → 등급")
	t.ok(not Lockpick.can_try(50, 49) and Lockpick.can_try(50, 50), "요구치 미달이면 시도할 수 없다(§8.1)")
	t.eq(Lockpick.half_width(2, 50), 10.0, "보통 반폭 10°")
	t.eq(Lockpick.half_width(2, 75), 12.0, "요구치를 넘는 10점마다 +1°")
	t.eq(Lockpick.half_width(0, 100), 35.0, "보정은 최대 +5°")
	t.eq(Lockpick.force_chance(2, 60), 20, "강제 개방 = 스킬 − 요구치 + 10")
	t.eq(Lockpick.force_chance(0, 100), 95, "최대 95%")
	var l := Lockpick.new(2, 50, 3, 7)
	t.ok(l.target >= 10.0 and l.target <= 170.0, "θ*는 10~170°")
	l.set_angle(l.target)
	t.eq(l.max_turn(), 90.0, "정답 각도면 90°까지 돈다")
	t.eq(l.max_turn(l.target + 10.0 + 30.0), 45.0, "오차 w+30°면 45°")
	t.eq(l.max_turn(clampf(l.target + 80.0, 0.0, 180.0) if l.target < 100.0 else l.target - 80.0), 0.0, "오차가 w+60° 넘으면 못 돈다")
	var ev := ""
	for i in 120:
		ev = l.step(1.0 / 60.0, true)
		if ev != "":
			break
	t.eq(ev, "open", "정답 각도로 누르고 있으면 열린다")
	t.eq(l.xp(), 40, "보통 XP 40")
	var m := Lockpick.new(3, 75, 2, 11)
	var th := m.target
	m.set_angle(th + 40.0 if th < 120.0 else th - 40.0)
	var broke := 0
	for i in 60 * 10:
		var e := m.step(1.0 / 60.0, true)
		if e == "pin_broke":
			broke += 1
			t.eq(m.target, th, "핀이 부러져도 θ*는 그대로")
		if e == "no_pins":
			break
	t.eq(broke, 1, "머리핀 둘: 하나 부러지고")
	t.eq(m.state, "no_pins", "둘째도 부러지면 핀 0개 — 강제 개방만")
	m.set_angle(0.0)
	t.ok(m.turn <= 0.5, "돌리는 힘을 빼면 드라이버가 돌아온다")
	var jam := 0
	var opened := 0
	for s in 200:
		var f := Lockpick.new(3, 75, 0, s + 1)
		if f.force():
			opened += 1
		else:
			jam += 1
			t.eq(f.state, "jammed", "실패하면 영구 파손")
	t.ok(opened > 5 and opened < 45, "스킬 75 · 요구 75 → 강제 개방 약 10%%(%d/200)" % opened)
	var none := Lockpick.new(1, 30, 0, 3)
	t.eq(none.state, "no_pins", "머리핀 0개면 미니게임 불가")
