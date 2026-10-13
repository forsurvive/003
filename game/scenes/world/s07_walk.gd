## 볼트 S-07 걸어 보기(단계 0-5): 실내 12장을 걸어 다니며 문·계단·덕트로 오가고, 주민에게 말을 걸고, 조사 글을 읽는다.
## 실행: godot --path game res://scenes/world/s07_walk.tscn [-- --map=V-01 --mark=이름 --auto --shots=디렉터리]
##   --auto: 순회 봇 — TOUR 차례로 출구를 찾아 걸어가 맵을 넘고(길찾기), 처음 맵에서는 가까운 주민에게 말을 건다.
##           맵마다 걸린 시간·막힘을 기록하고, 끝나면 요약을 찍고 종료한다. --shots: 맵에 들어설 때마다 화면 저장.
extends Node

const TOUR := ["V-01", "V-03", "V-07", "V-03", "V-01", "V-02", "V-05", "V-02", "V-11", "V-06", "V-01", "V-00", "V-02", "V-00",
	"V-01", "V-04", "V-10", "V-11", "V-10", "V-04", "V-09", "V-01", "V-08"]
const HOP_LIMIT := 45.0

var host: InteriorHost
var auto := false
var shots := ""
var shot_n := 0
var tour_i := 0
var path := PackedVector2Array()
var hop_t := 0.0
var log_rows: Array = []
var failures: Array = []
var phase := "start"                            ## start → talk → read → tour → done
var phase_t := 0.0
var _shot_pending := 0.0
var _did := false                               ## 이번 단계의 조사·대화를 했다(한 번만)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0B0A0D"))
	var start := "V-08"
	var mark := "door"
	for a in OS.get_cmdline_user_args():
		if a == "--auto":
			auto = true
		elif a.begins_with("--map="):
			start = a.substr(6)
		elif a.begins_with("--mark="):
			mark = a.substr(7)
		elif a.begins_with("--shots="):
			shots = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shots)
	host = InteriorHost.new()
	add_child(host)
	host.st.vars.set_v("P_FULL", "윤서진")
	host.map_entered.connect(_on_enter)
	host.use_keyboard = not auto
	host.enter(start, mark)


func _on_enter(mid: String) -> void:
	if auto and phase == "tour":
		log_rows.append("%s %.1f초" % [mid, hop_t])
		hop_t = 0.0
		path = PackedVector2Array()
	_shot_pending = 0.9


func _shot(tag: String) -> void:
	if shots == "":
		return
	shot_n += 1
	get_viewport().get_texture().get_image().save_png("%s/walk_%02d_%s.png" % [shots, shot_n, tag])


func _process(dt: float) -> void:
	if _shot_pending > 0.0:
		_shot_pending -= dt
		if _shot_pending <= 0.0 and not host.busy:
			_shot(host.map.id)
	if not auto:
		return
	phase_t += dt
	match phase:
		"start":
			if phase_t > 1.2:
				phase = "talk"
				phase_t = 0.0
		"talk":
			_auto_talk(dt)
		"read":
			_auto_read(dt)
		"tour":
			_auto_tour(dt)


## 가장 가까운 일과 인물에게 다가가 말을 건다 → 대화 화면을 찍고 넘긴다
func _auto_talk(dt: float) -> void:
	if host.box.active:
		if phase_t > 1.0:
			_shot("talk")
			host.box.next()
			host.box.next()
			phase_t = 0.0
		return
	if _did or phase_t > 20.0:
		phase = "read"
		phase_t = 0.0
		_did = false
		host.input_vec = Vector2.ZERO
		return
	if host.npcs.is_empty():
		phase = "read"
		return
	var n: Dictionary = host.npcs[0]
	var to: Vector2 = n["actor"].loco.logical
	var d := to - host.player.loco.logical
	if d.length() < 40.0:
		host.input_vec = Vector2.ZERO
		host.player.loco.facing = Locomotion.snap8(d)
		host.player._show()
		_did = host.interact()
		phase_t = 0.0
		return
	host.input_vec = _follow(to, dt)


## 조사 글 하나: 의무실 등록 단말 앞(V-08 terminal 표지)에서 북쪽을 보고 조사
func _auto_read(dt: float) -> void:
	if host.box.active:
		if phase_t > 1.0:
			_shot("read")
			host.box.next()
			host.box.next()
			phase_t = 0.0
		return
	if _did or phase_t > 15.0 or not host.map.marks.has("terminal"):
		_begin_tour()
		return
	var to := host.map.mark_pos("terminal")
	if NpcRoutine.arrived(host.player.loco.render, to):
		host.input_vec = Vector2.ZERO
		host.player.loco.facing = 6
		host.player._show()
		_did = host.interact()
		phase_t = 0.0
		if not _did:
			_begin_tour()
		return
	host.input_vec = _follow(to, dt)


func _begin_tour() -> void:
	phase = "tour"
	phase_t = 0.0
	hop_t = 0.0
	path = PackedVector2Array()


func _auto_tour(dt: float) -> void:
	if host.busy or host.box.active:
		host.input_vec = Vector2.ZERO
		if host.box.active:
			host.box.next()
		return
	hop_t += dt
	if tour_i >= TOUR.size():
		_finish()
		return
	if host.map.id == TOUR[tour_i]:
		tour_i += 1
		return
	if hop_t > HOP_LIMIT:
		failures.append("%s → %s: %.0f초 안에 못 감" % [host.map.id, TOUR[tour_i], HOP_LIMIT])
		_finish()
		return
	var goal := Vector2.INF
	for t in host.map.exits:
		if host.map.exits[t]["to"] == TOUR[tour_i]:
			goal = Vector2(t.x * 32 + 16, t.y * 32 + 16)
			break
	if goal == Vector2.INF:
		failures.append("%s에 %s로 가는 출구가 없다" % [host.map.id, TOUR[tour_i]])
		_finish()
		return
	host.input_vec = _follow(goal, dt)


## 길찾기 경로를 따라가는 입력(칸 가운데를 차례로)
func _follow(goal: Vector2, _dt: float) -> Vector2:
	var p := host.player.loco.render
	var gt := host.map.tile_of(goal)
	if path.is_empty() or host.map.tile_of(path[path.size() - 1]) != gt:
		path = NpcRoutine.with_start(host.map, p, goal)
		if path.is_empty():
			return Vector2.ZERO
	while path.size() > 1 and NpcRoutine.arrived(p, path[0]):
		path.remove_at(0)
	if path.size() == 1 and NpcRoutine.arrived(p, path[0]):
		return Vector2.ZERO
	return NpcRoutine.step_dir(p, path[0])


func _finish() -> void:
	phase = "done"
	host.input_vec = Vector2.ZERO
	print("S-07 순회: %d/%d 맵, %s" % [tour_i, TOUR.size(), " · ".join(log_rows)])
	print("실패: %s" % (str(failures) if not failures.is_empty() else "없음"))
	get_tree().create_timer(0.5).timeout.connect(get_tree().quit)
