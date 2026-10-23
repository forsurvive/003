## 지하시장 확인 장면(단계 1-4): 1막 진행 상태로 실내 맵 하나를 연다. 인자 "맵 표지 [x,y 주인공 자리] [진행]"
## 진행: 0 막 들어옴 · 1 둥지 맡음(박춘삼 고용) · 2 둥지 비움 · 3 마영식 해독 뒤.
## 실행: godot --path game res://scenes/bench/jm_check.tscn --write-movie out.png --fixed-fps 2 --quit-after 4 -- J-02 from_J-01 40,8
## 성능(1-13f, SD-19 §10.4): 다섯째 인자 'perf=N' — 처음 60프레임을 버리고 N프레임 동안 주인공이 좌우로 걸으며 프레임마다 CPU 시간
## (그 프레임 물리 시작 → 맨 끝 처리, 60fps 고정)을 모아 'PERF|맵|인물|평균|1% 최악|최대' 한 줄을 찍고 끝난다. 헤드리스라 렌더는 재지 않는다
extends Node

var host: InteriorHost
var perf_n := 0
var _pf: Array = []
var _pf_skip := 60
var _pf_t := 0.0
var _pf_last := 0


func _ready() -> void:
	host = InteriorHost.new()
	add_child(host)
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		host.st.quests.set_stage(q, 100)
	host.st.quests.set_stage("MQ-101", 100)
	host.st.vars.set_v("V_ACT", 1)
	host.st.vars.set_v("PC_CAPS", 400)
	host.body = "adult"
	host.date_text = "2277. 10. 25.  13:10"
	var a := OS.get_cmdline_user_args()
	var mid := a[0] if a.size() > 0 else "J-02"
	var mark := a[1] if a.size() > 1 else "from_J-01"
	var prog := int(a[3]) if a.size() > 3 else 0
	if prog >= 1:
		host.st.quests.set_stage("MQ-103", 20)
		host.st.vars.set_v("MQ103_JOB", 1)
	if prog >= 2:
		host.st.vars.set_v("MQ103_JOB", 2)
		host.st.vars.set_v("MQ103_NEST", 1)
	if prog >= 3:
		host.st.quests.set_stage("MQ-103", 30)
		host.st.vars.set_v("K_CODE", 1)
	host.st.vars.set_v("MQ103_GATE", 1)
	host.enter(mid, mark)
	if a.size() > 2 and a[2] != "-":
		var p := a[2].split(",")
		host.player.loco.place(Vector2(int(p[0]) * 32 + 16, int(p[1]) * 32 + 16))
		host.player.position = host.player.loco.render
	if a.size() > 4 and a[4].begins_with("perf="):
		perf_n = int(a[4].substr(5))
		Engine.max_fps = 60                                              # 실제 게임처럼 60fps — 한 프레임 안의 일(물리 → 처리 → 그리기 직전)을 잰다
		OS.low_processor_usage_mode = false
		OS.low_processor_usage_mode_sleep_usec = 0                       # 헤드리스 기본 잠(6.9ms)을 끈다
		get_tree().physics_frame.connect(_pf_begin)
		get_tree().process_frame.connect(_pf_begin)
		process_priority = 100000                                        # 이 노드의 처리가 프레임 맨 끝 — 여기서 잰다(헤드리스는 그리기 신호가 없다)


## 한 프레임의 CPU 몫: 그 프레임 첫 물리 단계(없으면 처리 시작)부터 이 노드의 처리(맨 끝)까지(스크립트 · AI · 경로 · 물리 — 렌더 제출은 뺀다)
func _pf_begin() -> void:
	if perf_n > 0 and _pf_last == 0:
		_pf_last = Time.get_ticks_usec()


func _pf_end() -> void:
	if _pf_last > 0:
		if _pf_skip <= 0 and perf_n > 0:
			_pf.append(float(Time.get_ticks_usec() - _pf_last) / 1000.0)
		_pf_last = 0


func _process(dt: float) -> void:
	if perf_n <= 0 or host == null or host.map == null:
		return
	_pf_end()
	_pf_t += dt
	host.input_vec = Vector2(1.0 if fmod(_pf_t, 6.0) < 3.0 else -1.0, 0.0)   # 좌우로 걷는다(막히면 선다 — 미끄러짐 없음)
	if _pf_skip > 0:
		_pf_skip -= 1
		return
	if _pf.size() >= perf_n:
		var srt := _pf.duplicate()
		srt.sort()
		var avg := 0.0
		for x in _pf:
			avg += float(x)
		avg /= _pf.size()
		var p99: float = srt[int(srt.size() * 0.99) - 1] if srt.size() >= 100 else srt[-1]
		var people := host.map.actors.size() + host.combat.enemies.size()
		print("PERF|%s|%d|%.2f|%.2f|%.2f" % [host.map.id, people, avg, p99, srt[-1]])
		perf_n = 0
		get_tree().quit()
