## 2단 경로(NavGrid, T8): 가까우면 타일 격자 그대로, 멀면 거친 격자 길의 앞부분만. 다시 물으며 따라가면 벽의 틈을 돌아 도착한다.
extends RefCounted

const CS := 40


## 3×3청크(120×120타일) 가짜 월드: 가운데 세로 벽(x = 60), 틈은 맨 아래쪽(y 110~113)에만
class FakeWorld:
	var loaded := {}
	var solid_atlas := {7: true}

	func _init() -> void:
		for cy in 3:
			for cx in 3:
				var deco := []
				deco.resize(CS * CS)
				deco.fill(-1)
				loaded[Vector2i(cx, cy)] = {"data": {"deco": deco}}
		for y in 120:
			if y < 110 or y > 113:
				var k := Vector2i(1, y / CS)
				loaded[k]["data"]["deco"][(y % CS) * CS + 20] = 7


func _px(t: Vector2i) -> Vector2:
	return Vector2(t) * 32.0 + Vector2(16, 16)


func test_near_is_exact(t) -> void:
	var n := NavGrid.new()
	n.rebuild(FakeWorld.new(), Vector2i(1, 1), CS)
	n.new_frame()
	var p := n.path(_px(Vector2i(10, 10)), _px(Vector2i(30, 20)))
	t.eq(Vector2i(p[p.size() - 1] / 32.0), Vector2i(30, 20), "32타일 안: 목표까지 한 번에")
	t.eq(n.coarse_queries, 0, "거친 격자를 쓰지 않는다")


func test_far_follows_around_wall(t) -> void:
	var n := NavGrid.new()
	n.rebuild(FakeWorld.new(), Vector2i(1, 1), CS)
	var at := Vector2i(10, 10)
	var goal := Vector2i(110, 10)
	var asked := 0
	var passed_gap := false
	while at != goal and asked < 40:
		n.new_frame()
		var p := n.path(_px(at), _px(goal))
		asked += 1
		if p.size() < 2:
			break
		for i in range(1, p.size()):                                 # 점프 탐색 경로는 꺾이는 점만 준다: 선분이 x = 60을 지나는 자리
			var a: Vector2 = p[i - 1] / 32.0
			var b: Vector2 = p[i] / 32.0
			if (a.x - 60.5) * (b.x - 60.5) <= 0.0 and a.x != b.x:
				var y := a.y + (b.y - a.y) * (60.5 - a.x) / (b.x - a.x)
				passed_gap = passed_gap or (y >= 110.0 and y <= 114.0)
		at = Vector2i(floori(p[p.size() - 1].x / 32), floori(p[p.size() - 1].y / 32))
	t.eq(at, goal, "벽 너머 100타일 목표에 도착")
	t.ok(passed_gap, "벽의 틈으로 지나간다")
	t.ok(n.coarse_queries > 0, "먼 질의는 거친 격자를 쓴다")
	t.ok(asked < 40, "질의 %d회" % asked)
