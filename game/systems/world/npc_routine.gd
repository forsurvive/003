## 인물 일과(단계 0-5, SD-19 §5.3 '인물 일과(장소 2곳 왕복)'): 맵 원고 npc의 route 지점을 차례로 걸어 오가며 머문다.
## 길은 실내 맵의 칸 길찾기(8방향, 모서리 끼어 지나가기 없음), 걸음은 Locomotion(걸음 단위, 미끄러짐 없음).
## 주인공이 앞을 막으면 서서 기다리고, 2초 넘게 나아가지 못하면 길을 다시 찾는다. 말을 걸면 멈추고 주인공을 본다.
class_name NpcRoutine
extends RefCounted

const TOL := Vector2(3.0, 2.0)                  ## 도착 허용(가로·세로): 보폭(가로 6·세로 4) 절반 — 칸 가운데를 정확히 밟는다.
                                                ## 판정은 그림 위치(걸음 경계)로 한다: 걸음 중간 위치는 방향을 바꾸면 경계로 돌아가 맴돈다
const BLOCK_R := 22.0
const YIELD_S := 3.0                             ## 주인공에게 이만큼 막히면 길을 비켜 준다(돌아서 왔던 지점으로)

var actor: Actor
var map
var route: Array = []                            ## [[이름, x, y, 머무는 초], …]
var idx := 0
var wait_t := 0.0
var path := PackedVector2Array()
var paused := false
var _stuck_t := 0.0
var _last := Vector2.ZERO
var _yield_t := 0.0


func _init(a: Actor, m, r: Array) -> void:
	actor = a
	map = m
	route = r
	wait_t = 1.0 + float(abs(hash(a.sheet)) % 30) / 10.0           # 처음에는 인물마다 조금씩 어긋나게 출발
	_last = a.loco.logical


func target() -> Vector2:
	var r: Array = route[idx]
	return Vector2(int(r[1]) * 32 + 16, int(r[2]) * 32 + 16)


func tick(dt: float, player_pos: Vector2) -> void:
	if paused or route.is_empty():
		actor.move(Vector2.ZERO, dt)
		return
	if wait_t > 0.0:
		wait_t -= dt
		actor.move(Vector2.ZERO, dt)
		if wait_t <= 0.0:
			idx = (idx + 1) % route.size()
			path = with_start(map, actor.loco.render, target())
		return
	if path.is_empty():
		if arrived(actor.loco.render, target()):
			_arrive()
		else:
			path = with_start(map, actor.loco.render, target())
			if path.is_empty():
				_arrive()                                               # 갈 수 없으면 그 자리에서 머문다
		actor.move(Vector2.ZERO, dt)
		return
	while not path.is_empty() and arrived(actor.loco.render, path[0]):
		path.remove_at(0)
	if path.is_empty():
		actor.move(Vector2.ZERO, dt)
		return
	var dir: Vector2 = step_dir(actor.loco.render, path[0])
	if (actor.loco.logical + dir * BLOCK_R).distance_to(player_pos) < BLOCK_R:
		actor.move(Vector2.ZERO, dt)                                # 주인공이 길을 막았다: 서서 기다린다
		_yield_t += dt
		if _yield_t > YIELD_S and route.size() > 1:                 # 오래 막히면 돌아서 왔던 지점으로 간다 — 좁은 복도에서 서로 기다리는 교착 풀기
			_yield_t = 0.0
			idx = (idx - 1 + route.size()) % route.size()
			path = with_start(map, actor.loco.render, target())
		return
	_yield_t = 0.0
	path = walk_path(actor, path, dt)
	_stuck_t = _stuck_t + dt if actor.loco.logical.distance_to(_last) < 0.5 else 0.0
	_last = actor.loco.logical
	if _stuck_t > 2.0:
		_stuck_t = 0.0
		path = with_start(map, actor.loco.render, target())


func _arrive() -> void:
	path = PackedVector2Array()
	wait_t = float(route[idx][3])


## 말을 걸면 멈추고 주인공을 본다. resume()으로 일과를 잇는다.
func talk_to(player_pos: Vector2) -> void:
	paused = true
	actor.move(Vector2.ZERO, 0.0)
	actor.loco.facing = Locomotion.snap8(player_pos - actor.loco.logical)
	actor._show()


func resume() -> void:
	paused = false


# ---------------------------------------------------------------- 칸 길 따라가기(봇·연출도 쓴다)
## 길찾기 경로 앞에, 첫 걸음 방향에 수직인 축만 칸 가운데로 맞추는 점을 둔다(어긋난 채 문틀·모서리로 들어 걸리지 않게).
## 진행 방향 축의 어긋남은 그대로 둔다 — 지나온 칸 가운데로 되돌아가 좌우로 맴돌지 않게.
static func with_start(m, from: Vector2, to: Vector2) -> PackedVector2Array:
	var p: PackedVector2Array = m.path(from, to)
	if p.is_empty():
		if m.tile_of(from) == m.tile_of(to) and not arrived(from, to):
			p.append(to)                                            # 같은 칸 안: 그 자리로만 맞춘다(빈 길이면 제자리에 멈춰 섰다)
		return p
	var t: Vector2i = m.tile_of(from)
	var c := Vector2(t.x * 32 + 16, t.y * 32 + 16)
	var step := (p[0] - c).sign()
	var fix := from
	if step.x != 0.0 and absf(from.y - c.y) > TOL.y:
		fix.y = c.y
	if step.y != 0.0 and absf(from.x - c.x) > TOL.x:
		fix.x = c.x
	if fix != from:
		p.insert(0, fix)
	return p


## 길을 dt만큼 걷는다. 1/60초씩 잘라 매번 방향을 다시 정한다 — 프레임이 길면(녹화 10fps·느린 기기) 한 번에 보폭 여러 개를
## 가서 칸 가운데를 지나쳤다 되돌아오기를 되풀이했다. 돌려줌: 남은 길
static func walk_path(a: Actor, p: PackedVector2Array, dt: float) -> PackedVector2Array:
	var left := dt
	while left > 0.0001:
		var h := minf(left, 1.0 / 60.0)
		left -= h
		while not p.is_empty() and arrived(a.loco.render, p[0]):
			p.remove_at(0)
		a.move(Vector2.ZERO if p.is_empty() else step_dir(a.loco.render, p[0]), h)
	return p


static func arrived(pos: Vector2, target: Vector2) -> bool:
	return absf(target.x - pos.x) <= TOL.x and absf(target.y - pos.y) <= TOL.y


## 축마다 허용 안이면 0: 가로·세로를 따로 맞춰 칸 가운데로(대각선은 두 축이 다 어긋났을 때만)
static func step_dir(pos: Vector2, target: Vector2) -> Vector2:
	var d := target - pos
	return Vector2(0.0 if absf(d.x) <= TOL.x else signf(d.x), 0.0 if absf(d.y) <= TOL.y else signf(d.y))
