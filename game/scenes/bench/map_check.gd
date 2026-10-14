## 지도 확인 장면(단계 1-2): 봉천(1막)에서 R01·R02 장소 일부를 발견·표시·소문으로 둔 채 핍-보이 지도를 연다.
## 실행: godot --path game res://scenes/bench/map_check.tscn --write-movie out.png --fixed-fps 2 --quit-after 4 -- 1 [확대 0~3]
## 첫 인자 0 = 지역 지도, 1 = 월드 지도, 2 = 퀘스트(둘째 인자 = 고른 줄), 3 = 기록·인물 수첩(둘째 인자 = 고른 줄), hud = 핍-보이 없이 HUD(목표 3줄·방위 링·화면 표식).
## 퀘스트: 1막 — 산 아래 마을 진행 · 코드를 읽을 사람 · 여의도 집결지(위치 2곳 표시, 고정) · 지하시장 소문, 막 머리 추적.
extends Node
func _ready() -> void:
	var host := InteriorHost.new()
	add_child(host)
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		host.st.quests.set_stage(q, 100)
	host.body = "adult"
	host.date_text = "2277. 10. 23.  16:40"
	host.enter("X-BC", "from_X-S07")
	PlaceLog.load_db()
	var i := 0
	for lid in PlaceLog.db:                                              # R01: 앞 절반 발견, 나머지 표시 · R02: 소문 몇 곳
		if lid.begins_with("L-R01-"):
			host.st.places.raise(lid, PlaceLog.FOUND if i % 2 == 0 else PlaceLog.MARKED)
			i += 1
		elif lid.begins_with("L-R02-") and int(lid.substr(7)) % 4 == 0:
			host.st.places.raise(lid, PlaceLog.RUMOR)
	host.st.places.regions["R01"] = true
	var me: Vector2 = host.player.loco.logical
	for dy in range(-30, 31, 6):                                         # 봉천 둘레를 본 것으로
		for dx in range(-30, 31, 10):
			host.st.places.mark_seen(host.map.tile_of(me) + Vector2i(dx, dy))
	var q := host.st.quests
	host.st.vars.set_v("V_ACT", 1)
	q.set_stage("MQ-101", 50)
	q.set_stage("MQ-102", 10)
	q.set_stage("MQ-104", 20)
	for lid in ["L-R02-01", "L-R02-02"]:
		host.st.places.raise(lid, PlaceLog.MARKED)
	host.st.places.raise("L-R02-11", PlaceLog.RUMOR)
	q.track("act:1")
	q.pin("MQ-101")
	q.pin("MQ-102")
	q.events.clear()
	var bk := host.st.book                                               # 인물 수첩: 볼트 사람 둘 · 봉천 사람 넷(한 명은 고인, 메모 하나)
	bk.meet("C-001", "2258. 03. 02.  06:10")
	bk.meet("N-R01-001", "2268. 05. 14.  09:00")
	for id in ["C-010", "C-057", "N-R01-028", "N-R01-011"]:
		bk.meet(id, "2277. 10. 23.  16:40")
	bk.memo("C-010", "봉천에 머물 자리를 내주었다. 관리자 코드를 읽을 사람을 찾아보라고 했다.")
	bk.died("N-R01-028", "2277. 10. 24.  03:10")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "hud":
		host.pipboy_ok = true
		host.hud_on = true
		return
	var p := host.open_pipboy()
	p.t_open = 1.0
	p.open_at(2, int(args[0]) if args.size() > 0 else 1)
	p.map = PipMap.new(p)
	if args.size() > 1 and int(args[0]) >= 2:
		p.sel = int(args[1])
	elif args.size() > 1:
		p.map.zoom = int(args[1])
	p.map.cursor = Vector2(892, 1362)
	p.map.center = Vector2(892, 1362)
