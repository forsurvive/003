## 1막 MQ-101 「산 아래 마을」 진행기(단계 0-10, SD-03a §8.1). 프롤로그 장면(prologue.gd)이 첫 풍경·공보방송 뒤 넘겨준다.
## 같은 InteriorHost 위에서 돈다: 관악산 비탈(X-S07) → 봉천 계단마을(X-BC) → 옥탑 이장실(B-01)·약국(B-03).
## 봇(--auto): 지점 목록을 따라 걷는다(맵을 넘는 출구 포함) — 바깥 맵 충돌·높이·계단·사다리 확인용.
class_name Mq101
extends Node

var host: InteriorHost
var auto := false
var log_on := false
var t := 0.0
var route: Array = []                              ## 봇 지점 [[맵 ID, 칸 x, 칸 y], …]
var route_i := 0
var path := PackedVector2Array()
var path_goal := Vector2.INF
var _re_t := 0.0
var stuck_t := 0.0
var _last_p := Vector2.ZERO
var done := false


func setup(h: InteriorHost, is_auto: bool, is_log: bool) -> void:
	host = h
	auto = is_auto
	log_on = is_log


## 1막 시작: 비탈 첫 칸(첫 풍경에서 주인공이 멈춘 흙길과 같은 자리)
func start(map_id: String = "X-S07", mark: String = "start") -> void:
	host.body = "adult"
	host.hud_on = true
	host.pipboy_ok = true
	host.date_text = "2277. 10. 23.  14:30"
	host.enter(map_id, mark)


func walk(points: Array) -> void:
	route = points
	route_i = 0
	host.input_fn = _bot_input


func _bot_input() -> Vector2:
	if route_i >= route.size() or host.map == null:
		return Vector2.ZERO
	while route_i + 1 < route.size() and host.map.id != str(route[route_i][0]) and host.map.id == str(route[route_i + 1][0]):
		route_i += 1                                               # 출구를 밟아 맵이 바뀌었다: 그 맵의 다음 지점으로
		path = PackedVector2Array()
	var r: Array = route[route_i]
	if host.map.id != str(r[0]):
		return Vector2.ZERO
	var goal := Vector2(int(r[1]) * 32 + 16, int(r[2]) * 32 + 16)
	var p := host.player.loco.render
	if p.distance_to(goal) < 6.0:
		route_i += 1
		path = PackedVector2Array()
		return Vector2.ZERO
	if path.is_empty() or path_goal != goal or t - _re_t > 3.0:
		_re_t = t
		path = NpcRoutine.with_start(host.map, p, goal)
		path_goal = goal
	while path.size() > 0 and NpcRoutine.arrived(p, path[0]):
		path.remove_at(0)
	if path.is_empty():
		return (goal - p).normalized() if p.distance_to(goal) > 2.0 else Vector2.ZERO
	return NpcRoutine.step_dir(p, path[0])


func _process(dt: float) -> void:
	if not auto or host == null or host.map == null:
		return
	t += dt
	var p := host.player.loco.render
	if p.distance_to(_last_p) < 0.5 and not host.box.active and not host.busy:
		stuck_t += dt
	else:
		stuck_t = 0.0
	_last_p = p
	if log_on and int(t) % 3 == 0 and int(t - dt) % 3 != 0:
		var c := host.map.tile_of(p)
		print("[%3.0f초] %s 칸 %s 높이 %d 지점 %d/%d" % [t, host.map.id, c, host.map.level_at(c), route_i, route.size()])
	if route_i >= route.size() and not done:
		done = true
		print("MQ-101 봇: 지점 %d개 끝 — %s %s" % [route.size(), host.map.id, host.map.tile_of(p)])
		get_tree().create_timer(0.5).timeout.connect(get_tree().quit)
	elif stuck_t > 6.0 and not done:
		done = true
		print("MQ-101 봇: 막힘 — %s %s 지점 %d %s" % [host.map.id, host.map.tile_of(p), route_i, route[route_i] if route_i < route.size() else []])
		get_tree().create_timer(0.5).timeout.connect(get_tree().quit)
