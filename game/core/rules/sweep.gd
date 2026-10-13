## 원형 충돌체 이동(SD-16 §5.4 ⑤·⑧): 가려는 선분을 따라 막히기 직전까지만 간다. 축을 나눠 벽을 따라 미끄러지는 일은 없다.
## 벽에 닿은 뒤에는 0만 움직인다(Locomotion이 그때 대기로 돌린다 — 제자리걸음·비비기 없음).
## hits: Callable(center: Vector2, r: float) -> bool. 출발점은 비어 있다고 본다.
class_name Sweep
extends RefCounted

const EPS := 0.05


static func move(from: Vector2, to: Vector2, r: float, hits: Callable) -> Vector2:
	if from.is_equal_approx(to) or not hits.call(to, r):
		return to
	var lo := 0.0
	var hi := 1.0
	for i in 8:                                                      # 이분 탐색: 1/256 정밀도(한 틱 이동량 < 4px → 0.02px)
		var mid := (lo + hi) * 0.5
		if hits.call(from.lerp(to, mid), r):
			hi = mid
		else:
			lo = mid
	var p := from.lerp(to, lo)
	return from if p.distance_to(from) < EPS else p


## AI 조향: 가려는 8방향이 이번 틱에 막히면 가까운 방향부터(±45°, ±90°) 막히지 않은 쪽으로 몸을 돌려 걷는다.
## 미끄러짐이 아니라 '돌아서 걷기'다(그림도 그 방향으로 바뀐다). 모두 막히면 0.
static func steer(pos: Vector2, want: Vector2, step: float, r: float, hits: Callable) -> Vector2:
	if want.length() < 0.001:
		return Vector2.ZERO
	var d := Locomotion.snap8(want, 0.0)
	for k in [0, 1, -1, 2, -2]:
		var dd := posmod(d + k, 8)
		var v: Vector2 = Locomotion.VEC[dd].normalized()
		if not hits.call(pos + v * step, r):
			return v
	return Vector2.ZERO
