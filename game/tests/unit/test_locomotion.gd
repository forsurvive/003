## SD-16 §3.6.5 이동 미끄러짐 금지 — 엔진 무관 규칙 시험
extends RefCounted


func test_snap8(t) -> void:
	t.eq(Locomotion.snap8(Vector2(1, 0)), 0, "E")
	t.eq(Locomotion.snap8(Vector2(0.9, 0.5)), 1, "SE 쪽 아날로그")
	t.eq(Locomotion.snap8(Vector2(0.3, 1)), 2, "S")
	t.eq(Locomotion.snap8(Vector2(-1, -0.2)), 4, "W")
	t.eq(Locomotion.snap8(Vector2(0.05, 0.05)), -1, "데드존")


func test_distance_driven_cardinal(t) -> void:
	var l := Locomotion.new(Vector2(100, 100))
	var dt := 1.0 / 60.0
	for i in 120:
		l.step(Vector2(1, 0), dt, "walk")
	var dist := l.logical.x - 100.0
	t.near(dist, 3.0 * 32.0 * 2.0, 0.01, "걷기 3.0t/초 × 2초")
	t.eq(l.frames_advanced, int(dist / 6.0), "프레임 = 이동 거리 / 6px")
	t.ok(absf(l.render.x - l.logical.x) < 6.0, "그림과 판정 차이 < 프레임 거리")
	t.eq(fmod(l.render.x - 100.0, 6.0), 0.0, "그림은 6px 경계에서만 움직인다")


func test_distance_driven_diagonal(t) -> void:
	var l := Locomotion.new(Vector2(0, 0))
	for i in 60:
		l.step(Vector2(1, 1), 1.0 / 60.0, "run")
	t.eq(l.facing, 1, "SE")
	var axis := l.logical.x
	t.eq(l.frames_advanced, int(axis / 6.0), "대각선 달리기: 축 6px마다 1프레임")
	t.eq(l.render.x, l.render.y, "대각선 단계 (6,6)")
	t.eq(fmod(l.render.x, 6.0), 0.0, "6px 경계")


func test_speed_only_changes_rate(t) -> void:
	# 같은 거리를 가면 같은 프레임 수: 보폭은 그대로, 빈도만 바뀐다
	var a := Locomotion.new()
	var b := Locomotion.new()
	for i in 60:
		a.step(Vector2(1, 0), 1.0 / 60.0, "walk")
	for i in 120:
		b.step(Vector2(0.4, 0), 1.0 / 120.0, "walk")
	t.eq(a.frames_advanced, b.frames_advanced, "dt가 달라도 거리당 프레임 같음")


func test_no_inertia_and_stop(t) -> void:
	var l := Locomotion.new()
	l.step(Vector2(1, 0), 1.0 / 60.0, "walk")
	t.near(l.logical.x, 3.0 * 32.0 / 60.0, 0.001, "첫 틱 100% 속도")
	for i in 7:
		l.step(Vector2(1, 0), 1.0 / 60.0, "walk")
	var before := l.render
	for i in 10:
		l.step(Vector2.ZERO, 1.0 / 60.0, "walk")
	t.eq(l.motion, "idle", "놓으면 대기")
	t.eq(l.render, before, "정지 중 그림 이동 0")
	t.eq(l.logical, l.render, "정지하면 판정 = 그림")


func test_wall_no_treadmill(t) -> void:
	var l := Locomotion.new(Vector2(10, 10))
	var wall := func(from: Vector2, to: Vector2) -> Vector2: return from
	for i in 30:
		l.step(Vector2(1, 0), 1.0 / 60.0, "walk", -1, wall)
	t.eq(l.frames_advanced, 0, "막히면 제자리걸음 없음")
	t.eq(l.motion, "idle", "대기")


func test_wall_slide_plays_actual_axis(t) -> void:
	var l := Locomotion.new(Vector2(0, 0))
	var slide := func(from: Vector2, to: Vector2) -> Vector2: return Vector2(from.x, to.y)   # x blocked
	for i in 60:
		l.step(Vector2(1, 1), 1.0 / 60.0, "walk", -1, slide)
	t.eq(l.facing, 2, "실제 이동 방향(S)으로 재생")
	t.eq(l.logical.x, 0.0, "x는 막힘")
	t.eq(l.frames_advanced, int(l.logical.y / 6.0), "실제 이동 거리만큼만 재생")


func test_backpedal(t) -> void:
	var l := Locomotion.new()
	for i in 60:
		l.step(Vector2(-1, 0), 1.0 / 60.0, "walk", 0)                # move W, aim E
	t.ok(l.reverse, "역재생")
	t.eq(l.facing, 0, "하체는 조준 쪽(E)")
	t.near(-l.logical.x, 3.0 * 32.0 * 0.85, 0.01, "뒷걸음 85%")
	var a := Locomotion.anim_for("walk", 4)
	t.eq(a, ["walk_E", true], "W = E 반전")
