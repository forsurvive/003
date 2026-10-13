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


## 벽 비비기 금지(SD-16 §5.4 ⑧): 대각선으로 벽에 닿으면 그 자리에 선다. 막히지 않은 축으로 미끄러지지 않는다.
func test_wall_no_rub(t) -> void:
	var wall := func(c: Vector2, r: float) -> bool: return c.x + r > 100.0            # x = 100에 세로 벽
	var blocked := func(a: Vector2, b: Vector2) -> Vector2: return Sweep.move(a, b, 9.6, wall)
	var l := Locomotion.new(Vector2(80, 40))
	var stopped := Vector2(-1, -1)
	var renders := {}
	for i in 180:
		l.step(Vector2(1, 1), 1.0 / 60.0, "walk", -1, blocked)
		renders[l.render] = true
		if l.motion == "idle" and stopped.x < 0:
			stopped = l.logical
	t.ok(stopped.x > 0.0, "벽 앞에서 선다")
	t.eq(l.logical, stopped, "계속 밀어도 미끄러지거나 들썩이지 않는다")
	t.ok(l.logical.x + 9.6 <= 100.0, "벽을 파고들지 않는다")
	t.eq(l.logical, l.render, "판정 = 그림")
	t.eq(l.facing, 1, "몸은 가려던 방향(SE) 그대로")
	var prev := Vector2(80, 40)
	var ok := true
	var keys := renders.keys()
	keys.sort()
	for r in keys:                                                  # 그림 위치는 보폭 단위로만, 앞으로만
		if r != prev and (r - prev).x != (r - prev).y:
			ok = false
		prev = r
	t.ok(ok, "그림은 대각선 보폭으로만 움직였다(축 미끄러짐 없음)")


func test_wall_turn_in_place(t) -> void:
	var wall := func(c: Vector2, r: float) -> bool: return c.x + r > 100.0
	var blocked := func(a: Vector2, b: Vector2) -> Vector2: return Sweep.move(a, b, 9.6, wall)
	var l := Locomotion.new(Vector2(88, 40))
	l.step(Vector2(1, 0), 1.0 / 60.0, "walk", -1, blocked)
	t.eq(l.motion, "idle", "한 걸음도 못 가면 걷지 않는다")
	t.eq(l.facing, 0, "몸만 벽 쪽으로 돌린다")
	t.eq(l.logical, Vector2(88, 40), "제자리")


## 막히기 직전까지만: 한 틱 이동이 벽을 넘으면 접점에서 멈춘다(축 분리 없음)
func test_sweep_contact(t) -> void:
	var wall := func(c: Vector2, r: float) -> bool: return c.y + r > 50.0
	var p := Sweep.move(Vector2(0, 30), Vector2(6, 42), 10.0, wall)
	t.ok(p.y + 10.0 <= 50.0 and p.y > 39.0, "접점 근처에서 멈춘다")
	t.near(p.x, (p.y - 30.0) * 0.5, 0.05, "가던 선분 위(x로 미끄러지지 않음)")
	t.eq(Sweep.move(Vector2(0, 40), Vector2(5, 40.5), 10.0, wall), Vector2(0, 40), "이미 닿아 있으면 0")


## AI 조향: 막히면 가까운 열린 8방향으로 돌아선다
func test_steer(t) -> void:
	var wall := func(c: Vector2, r: float) -> bool: return c.x + r > 100.0
	t.eq(Sweep.steer(Vector2(50, 50), Vector2(1, 1), 6.0, 9.6, wall), Locomotion.VEC[1].normalized(), "열려 있으면 그대로")
	t.eq(Sweep.steer(Vector2(88, 50), Vector2(1, 1), 6.0, 9.6, wall), Vector2(0, 1), "SE가 막히면 S로 돌아선다")
	t.eq(Sweep.steer(Vector2(88, 50), Vector2(1, 0), 6.0, 9.6, wall), Vector2(0, 1), "E·SE·NE가 다 막히면 90° 돌아선다")


func test_backpedal(t) -> void:
	var l := Locomotion.new()
	for i in 60:
		l.step(Vector2(-1, 0), 1.0 / 60.0, "walk", 0)                # move W, aim E
	t.ok(l.reverse, "역재생")
	t.eq(l.facing, 0, "하체는 조준 쪽(E)")
	t.near(-l.logical.x, 3.0 * 32.0 * 0.85, 0.01, "뒷걸음 85%")
	var a := Locomotion.anim_for("walk", 4)
	t.eq(a, ["walk_E", true], "W = E 반전")


## 질주(SD-11 §2.4 6.5t/s): 달리기 컷·보폭 그대로 빈도만 오른다. 그림 위치는 언제나 프레임 거리 단위.
func test_sprint_same_stride(t) -> void:
	var a := Locomotion.new()
	for i in 60:
		a.step(Vector2(1, 0), 1.0 / 60.0, "sprint")
	t.near(a.logical.x, 6.5 * 32.0, 0.01, "1초에 6.5t")
	t.eq(a.anim_motion(), "run", "그림은 달리기 컷")
	t.near(float(a.frames_advanced), 6.5 * 32.0 / 8.0, 1.0, "8px마다 1컷(달리기 보폭, 마지막 컷은 경계 오차)")
	t.eq(fmod(a.render.x, 8.0), 0.0, "그림 위치는 보폭 단위")


## 구르기·넉백 뒤 그 자리에 선다: 판정 = 그림, 대기 상태, 다음 걸음은 새 보폭에서 시작
func test_place_after_airborne(t) -> void:
	var a := Locomotion.new()
	for i in 10:
		a.step(Vector2(1, 0), 1.0 / 60.0, "run")
	a.place(Vector2(100.4, 50.6))
	t.eq(a.render, Vector2(100, 51), "그림 위치는 정수")
	t.eq(a.motion, "idle", "대기")
	a.step(Vector2(0, 1), 1.0 / 60.0, "run")
	t.eq(a.render.x, 100.0, "새 걸음은 선 자리에서")
