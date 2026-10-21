## 영등포(R02) 사이드 퀘스트 SQ-S09 「127번」 진행기(단계 1-11h, SD-04a §5.2). 원고: script/act1/SQ-S09.txt · MQ-105.txt(황두칠 매입 · 연습용 목걸이) ·
##   CAPTURE.txt(우리에서 눈 붙이기). 맵: H-02 칠판 · H-03 127번 칸 · 감시 의자 경비 · H-04 결재 양식 · K-20 길금순 칸 · K-22 구로 107동 · K-23 벽 사이 통로 ·
##   J-09 구멍 · X-SB 정문 · 줄 · X-BC · J-02 정착. 설계안 docs/seoul-fallout/_plans/SQ-S09_plan.md(계획 단계 재미 검수 반영).
## 채윤재의 자리는 SB_127 하나(P1): 0 · 1 우리 · 2 길금순 칸 · 3 정문 앞 · 4 구로 집 · 5 7일째 줄 · 6 봉천 · 7 지하시장 · 8 팔림.
## 단계는 이 진행기 한 곳에서만, 오르기만 한다(SD-20). 시계는 둘뿐: 7일째 04시(줄) → 06시(트럭) · 갈고리가 눈치챈 뒤 사흘.
class_name SideS09
extends Node

const YJ := "N-R02-039"                     ## 채윤재(127번)
const HAEIN := "N-R02-050"                  ## 채해인
const GEUM := "N-R02-042"                   ## 길금순
const HOOK := "N-R02-041"                   ## 갈고리(인솔조장)
const DUE_DAYS := 6                         ## 발동 날 + 6 = 7일째
const CLOSE_DAYS := 3                       ## 갈고리가 눈치챈 뒤 벽장을 부수기까지
const RUBBLE := [Vector2i(27, 3), Vector2i(27, 4)]

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s09"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v(k, n)


func _log(s: String) -> void:
	if log_on:
		print("[127번] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S09")


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S09", n)
		_log("단계 %d" % n)


func _zone() -> String:
	return host.map.id if host.map != null else ""


func _hour() -> int:
	return Clock.hour(host.date_text)


# ---------------------------------------------------------------- 발동 · 따라 올림(P2)
func _start(why: String) -> void:
	if v("V_ACT") < 1 or v("SB_127") >= 8 or st.is_dead(YJ):
		return
	_up(10)
	if v("SQ_S09_START") == 0:
		_sv("SQ_S09_START", day())
		var t := Clock.parse(Clock.add_minutes(host.date_text, DUE_DAYS * 1440))
		if not t.is_empty():
			_sv("SQ_S09_DUE_M", int(t[1]))
			_sv("SQ_S09_DUE_D", int(t[2]))
		if v("SB_127") <= 1:
			host.hint("127번 채윤재 — 현장 트럭은 %d월 %d일 새벽 04:00." % [v("SQ_S09_DUE_M"), v("SQ_S09_DUE_D")], 6.0)
		_log("발동(%s) · 트럭 %d/%d" % [why, v("SQ_S09_DUE_M"), v("SQ_S09_DUE_D")])
	_catch_up()


func _catch_up() -> void:
	if stage() < 10:
		return
	if v("SQ_S09_WIFE") == 1:
		_up(20)
	if v("SQ_S09_DEBT") == 1:
		_up(30)
	if v("GB_PASS") >= 1 or v("SQ_S09_CRACK") == 1:
		_up(40)
	if v("SB_127") >= 2 and v("SB_127") != 8:
		_up(50)
	if v("SQ_S09_SOL2") > 0 and v("SQ_S09_SOL2") != 9:
		_up(60)


func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	if host.map == null or host.player == null or v("V_ACT") < 1:
		return
	tick()


func tick() -> void:
	_released()
	_clock()
	_hook_dead()
	_catch_up()
	if stage() > 0 and stage() < 100 and st.is_dead(YJ):
		_close(8, "채윤재가 죽었다")


## 우리를 나왔다(B 우리 열기 · D 습격 · 줄에서 빼 옴): 해법①이 아직 없으면 여기서 정한다
func _released() -> void:
	if v("SB_127") != 2 or v("SQ_S09_SOL1") != 0:
		return
	if st.boxes.has("sbfreed6"):
		_sol1(4)                                                           # D는 우리 칸을 다 열었을 때만(재미 검수 — 한 칸 열다 들킨 소동은 B)
	else:
		_sol1(2)


func _sol1(n: int) -> void:
	if v("SQ_S09_SOL1") != 0:
		return
	_sv("SQ_S09_SOL1", n)
	_sv("SQ_S09_UNCOL", 1)
	_start("석방")
	match n:
		1:                                                                # 몸값 — 카르마는 값을 치른 장면에서(+50)
			st.call_fn("aff", ["SB", 3])
		2:                                                                # 우리 열기
			st.call_fn("karma", [100])
			_sv("PD_R02_SB", v("PD_R02_SB") - 3)
		4:                                                                # 습격(기존 '여섯 풀어 줌' +100에 더해)
			st.call_fn("karma", [50])
			st.call_fn("aff", ["SB", -12])
			_sv("PD_R02_SB", v("PD_R02_SB") - 10)
			_sv("SQS_S09", 1)                                             # MQ-504 선해방(RECON_SPEC N-68)
	_catch_up()
	_log("해법① %d" % n)


## 7일째 04시 줄 → 06시 트럭(P4: 주인공이 그 칸을 보고 있으면 나갈 때까지 미룬다)
func _clock() -> void:
	var s := v("SQ_S09_START")
	if s == 0 or v("SB_127") > 1 and v("SB_127") != 5:
		return
	if _zone() == "H-03":
		return
	var d := day()
	var h := _hour()
	var due := s + DUE_DAYS
	if v("SB_127") <= 1 and d == due and h >= 4 and h < 6:
		_sv("SB_127", 5)
		_refresh_if("X-SB")
		_log("줄에 섰다")
	elif d > due or (d == due and h >= 6):
		if v("SB_127") <= 1 or v("SB_127") == 5:
			if _zone() == "X-SB" and v("SB_127") == 5:
				host.hint("트럭 짐칸 문이 닫힌다. 번호표 127이 마당에 떨어져 있다.", 6.0)
			_sv("SB_127", 8)
			_refresh_if("X-SB")
			_close(9, "현장으로 팔려 감")


func _refresh_if(z: String) -> void:
	if _zone() == z:
		host.refresh_npcs()


## 갈고리를 먼저 쳤다: 벽장을 눈치챌 사람이 없다(재미 검수 8)
func _hook_dead() -> void:
	if v("SQ_S09_SOL2") != 0 or not st.is_dead(HOOK):
		return
	if v("SQ_S09_NOTICE") > 0 or v("SQ_S09_SOL1") == 2 or v("SQ_S09_SOL1") == 4 or v("SQ_S09_REQ") == 1:
		_sol2(4)


func _sol2(n: int) -> void:
	if v("SQ_S09_SOL2") != 0:
		return
	_sv("SQ_S09_SOL2", n)
	match n:
		1:
			_sv("SQ_S09_WALL", 1)
			st.call_fn("karma", [50])
			st.call_fn("aff", ["JH", 5])
			st.call_fn("aff", ["SB", -5])
			_sv("PD_R02_SB", v("PD_R02_SB") - 5)
			host.hint("쪽방 벽장이 지하시장 남쪽 통로로 이어졌다. 이제 이 길은 장부가 못 막는다.", 6.0)
		2:
			st.call_fn("karma", [25])
			host.hint("인솔조가 짐을 싼다 — 가리봉은 비고, 새 조장은 벽장을 모른다.", 6.0)
		3:
			st.call_fn("karma", [25])
			host.hint("통로가 메워졌다. 마흔 명의 이름은 봉투 안에 남았다.", 6.0)
			if host.map != null and _zone() == "K-23":
				_rubble()
		4:
			st.call_fn("aff", ["SB", -10])
			host.hint("벽장을 아는 사람이 없다. 인솔조는 한동안 갈피를 못 잡는다.", 6.0)
	_catch_up()
	_log("해법② %d" % n)


func _close(sqr: int, why: String) -> void:
	if stage() >= 100:
		return
	_sv("SQR_S09", sqr)
	_sv("SQ_S09_DAY", day())
	_up(100)
	_log("닫힘 — " + why)


# ---------------------------------------------------------------- 맵 · 하루 판정
func _on_map(_id: String) -> void:
	if host.map == null:
		return
	match _zone():
		"H-03":
			if v("SQ_S09_DOOR") == 1 and v("SB_127") <= 1 and host.ev.handlers.has("cage"):
				host.ev.handlers["cage"].call(["open", 10, 8], func() -> void: pass)
		"K-22":
			if v("SB_127") == 4 and v("SQ_S09_PLACE") == 0 and stage() < 100 and not st.is_dead(YJ):
				_reunion.call_deferred()
		"K-23":
			if v("SQ_S09_SOL2") == 3 or v("SQ_S09_CLOSED") == 1:
				_rubble()
		"K-20":
			if v("SQ_S09_CLOSED") == 1 or v("SQ_S09_SOL2") == 3:
				_relock(27, 1)
	_barks()


func _rubble() -> void:
	for c in RUBBLE:
		host.map._put_solid(c.x, c.y, 1)


## 부서지거나 막힌 벽장: 다시 잠근다(길금순이 열어 준 판도 끝)
func _relock(x: int, y: int) -> void:
	for d in host.map.doors:
		if int(d["x"]) == x and int(d["y"]) == y:
			d["locked"] = true
			d["lock"] = 100
			for yy in [y, y + 1]:
				host.map._put_solid(x, yy, 1)


## 지나가며 하는 말이 시계를 안다(재미 검수 2)
func _barks() -> void:
	var s := v("SQ_S09_START")
	if s == 0 or v("SB_127") > 1:
		return
	var left := s + DUE_DAYS - day()
	for n in host.npcs:
		if str(n["id"]) == HOOK and left <= 2:
			n["bark"] = "127번? %d일 새벽 트럭이야. 현장 가면 이자 걱정은 끝나지." % v("SQ_S09_DUE_D")


func _on_day(_d: int) -> void:
	# C 장부: 정착지에 넘김(HO_LEDGER 8x — 1막은 조만석 81, SD-03a §8.5 구현 정합) · 태움 99 → 다음 06시 '석방 명단' — 정문 앞(재미 검수 7: 씨앗 없이 고정)
	if v("SB_127") <= 1 and ((v("HO_LEDGER") >= 80 and v("HO_LEDGER") < 90) or v("HO_LEDGER") == 99 or v("SB_DEBT") == 1) and not st.is_dead(YJ):
		_sv("SB_127", 3)
		_sv("SQ_S09_UNCOL", 1)
		if v("SQ_S09_SOL1") == 0:
			_sv("SQ_S09_SOL1", 3)
		_log("석방 명단(C)")
	# 혼자 보낸 채윤재가 구로에 닿는다
	if v("SQ_S09_OUT") > 0 and (v("SB_127") == 2 or v("SB_127") == 3):
		_sv("SB_127", 4)
		_sv("SQ_S09_OUT", 0)
		_sv("SQ_S09_WAITED", 1)                                           # 판자 앞에서 밤새 기다렸다 — 재회는 주인공이 와서 이름을 부른다
	# 정착: 재회 다음 날 그곳에 선다
	if v("SB_127") == 4 and v("SQ_S09_PLACE") in [2, 3]:
		_sv("SB_127", 6 if v("SQ_S09_PLACE") == 2 else 7)
	# 갈고리가 벽장을 눈치챈다(B · D 다음 날) — 먼저 죽었으면 눈치챌 사람이 없다
	if (v("SQ_S09_SOL1") == 2 or v("SQ_S09_SOL1") == 4) and v("SQ_S09_NOTICE") == 0 and v("SQ_S09_SOL2") == 0:
		if st.is_dead(HOOK):
			_sol2(4)
		else:
			_sv("SQ_S09_NOTICE", day())
			_log("갈고리가 눈치챔")
	# 사흘이 지나도 통로 일이 없으면 인솔조가 벽장을 부순다
	if v("SQ_S09_NOTICE") > 0 and v("SQ_S09_SOL2") == 0 and day() >= v("SQ_S09_NOTICE") + CLOSE_DAYS:
		_sv("SQ_S09_CLOSED", 1)
		_sv("SQ_S09_SOL2", 9)
		_log("벽장이 부서짐")
	# b 운송로: 다음 06시 발각 판정(씨앗 고정 15%)
	if v("SQ_S09_SOL2") == 2 and v("SQ_S09_CHECK") == 0:
		_sv("SQ_S09_CHECK", 1)
		if _seed() % 100 < 15:
			st.call_fn("aff", ["SB", -5])
			_log("지시서 발각")


func _seed() -> int:
	return absi(hash(str(st.vars.get_v("P_REGNO")) + ":s09"))


# ---------------------------------------------------------------- 원고 명령(@cmd s09 …)
func _cmd(a: Array, done: Callable) -> void:
	var what := str(a[0]) if a.size() > 0 else ""
	var arg := str(a[1]) if a.size() > 1 else ""
	match what:
		"crack":
			_sv("SQ_S09_CRACK", 1)
			_start("판자 틈")
		"meet":
			_start("우리")
		"debt":
			_sv("SQ_S09_DEBT", 1)
			_catch_up()
		"wife":
			_sv("SQ_S09_WIFE", 1)
			_sv("SQ_S09_DEBT", 1)
			if v("SB_127") == 0:
				_sv("SB_127", 1)                                           # 아내가 부탁함(기존 뜻)
			_start("아내")
		"took":
			_sv("SQ_S09_TOOK", int(arg))
		"learn":
			_sv("SQ_S09_LEARN", 1)
		"uncol":
			_sv("SQ_S09_UNCOL", 1)
			if v("SQ_S09_DOOR") == 1 and v("SB_127") <= 1:
				_leave_cage()
		"open":
			_open_cage()
		"buy_hdc":                                                       # 황두칠 매입(MQ-105) — 값 400 = 해법 A
			st.call_fn("karma", [25])
			_sol1(1)
		"buy":                                                           # 구만호 계약 해지
			_sv("SB_127", 3)
			st.call_fn("karma", [50])
			_sb(["buy", "127"])
			_sol1(1)
		"haggle":
			_sv("SQ_S09_HAGGLE", 1)
		"linebuy":                                                       # 7일째 줄: 십장에게 웃돈
			_sv("SB_127", 3)
			st.call_fn("karma", [50])
			_sb(["buy", "127"])
			_sol1(1)
		"linesneak":                                                     # 7일째 줄: 줄에서 빼 옴(목걸이는 이미 풀림)
			_sv("SB_127", 2)
			_sb(["buy", "127"])
			_refresh_if("X-SB")
			_released()
		"go":
			done.call()
			_go_home()
			return
		"alone":
			_sv("SQ_S09_OUT", day())
		"reunion":
			host.box.finished.connect(func() -> void: _reunion.call_deferred(), CONNECT_ONE_SHOT)
		"spent88":
			if v("SQ_S09_TOOK") == 1:
				_sv("SQ_S09_SPENT88", 1)                                   # 아내의 400으로 88번을 샀다(순서가 맞을 때만, 재미 검수 5)
		"said88":
			_sv("SQ_S09_SAID88", 1)
		"soup":
			host.combat.pc.hp = host.combat.pc.max_hp
			host.hint("시래깃국 한 그릇. 몸이 데워진다.", 4.0)
		"settle":
			_settle(int(arg))
		"gate":
			_sv("SQ_S09_GATE", 1)
		"req":
			_sv("SQ_S09_REQ", 1)
		"order":
			_sv("SQ_S09_ORDER", int(arg))
		"sol2":
			_sol2(int(arg))
		"list":
			_sv("SQ_S09_LIST", 1)
		"listgiven":
			_give_list()
		"down":
			done.call()
			host.enter("J-09", "from_K-23")
			return
		"up":
			done.call()
			host.enter("K-23", "from_J-09")
			return
		"nap":
			done.call()
			_nap()
			return
	done.call()


func _sb(args: Array) -> void:
	if host.ev.handlers.has("sb"):
		host.ev.handlers["sb"].call(args, func() -> void: pass)


## 127번 칸 문: 목걸이가 풀렸거나 습격 중이면 판자 틈으로 나가고, 아니면 문만 열린다(재미 검수 4 — 확률 죽음 없음)
func _open_cage() -> void:
	var watched := v("SB_RAID") == 0 and not (_hour() >= 2 and _hour() < 4)   # 잡혀 온 사람도 남의 칸을 열면 본다(재미 검수 4)
	if watched:
		host.hint("감시 의자의 경비가 고개를 든다 — \"거기!\"", 4.0)
		st.call_fn("aff", ["SB", -8])
		_sb(["raid"])
	if v("SB_RAID") == 1:
		_sv("SQ_S09_UNCOL", 1)                                             # 습격 소동 — 철사의 공구로 서로 목걸이를 딴다
	if v("SQ_S09_UNCOL") == 1:
		_leave_cage()
		return
	_sv("SQ_S09_DOOR", 1)
	if host.ev.handlers.has("cage"):
		host.ev.handlers["cage"].call(["open", 10, 8], func() -> void: pass)
	host.hint("채윤재: \"문은 열렸는데… 이대로 담 넘으면 터져. 목걸이부터야.\"", 5.0)


func _leave_cage() -> void:
	_sb(["free10"])
	_sv("SQ_S09_DOOR", 0)
	if v("SB_127") < 2:
		_sv("SB_127", 2)
	_released()


## 재회 무대: 판자 앞에 채윤재를 세우고(맵 인물은 정착 뒤에만 — 한 사람 한 곳, 재미 검수 1) 장면이 끝나면 들인다
func _reunion() -> void:
	if not is_instance_valid(host) or host.map == null or _zone() != "K-22" or host.box.active:   # 미뤄 부른 사이 호스트가 사라졌으면(시험 해제 · 맵 교체) 그만
		return
	var at := host.player.loco.logical + Vector2(-34, 0)
	host.ev._show_actor("S9YJ", at, "E", str(host.ev.cast_sheets.get(YJ, "")))
	host.box.finished.connect(func() -> void:
		if host.ev.actors.has("S9YJ"):
			host.ev.run("hide", ["S9YJ"], func() -> void: pass)
		host.refresh_npcs(), CONNECT_ONE_SHOT)
	host.play_scene("SQS09_REUNION")


## '같이 가자': 실시간 동행 대신 화면 전환(재미 검수 5) — 한 시간 뒤 구로 107동 문 앞
func _go_home() -> void:
	host.ev.run("fade_out", ["black", "6"], func() -> void:
		host.advance_minutes(60)
		_sv("SB_127", 4)
		_sv("SQ_S09_OUT", 0)
		host.enter("K-22", "from_W")
		host.ev.run("fade_in", ["black", "6"], func() -> void: pass))


## 재회 뒤 어디서 살지(1 구로 · 2 봉천 · 3 지하시장 · 9 아내 없음)
func _settle(n: int) -> void:
	if v("SQ_S09_PLACE") != 0:
		return
	_sv("SQ_S09_PLACE", n)
	_sv("SQR_S09", 7 if n == 9 else n)                                      # SQR: 1~3 정착 · 7 아내 없음 · 8 채윤재 사망 · 9 팔림
	if n != 9:
		st.call_fn("give", ["M-184", 1])                                   # 채해인: 구로 공단 근속 15년 명패
		match n:
			2:
				st.call_fn("aff", ["JC_BC", 3])
				if v("SQ_S09_LIST") == 1 and v("SQ_S09_LISTGIVEN") == 0:
					_give_list()                                           # 명단은 부부가 봉천으로 가져간다(재미 검수 7)
			3:
				st.call_fn("aff", ["JH", 3])
	st.call_fn("xp", [450 if n != 9 else 200])
	_sv("SQ_S09_REWARD", 1)
	st.deeds.record(st, "side", "R02", 1, {"SB": 0}, Clock.abs_min(host.date_text), {"tag": "SQS09_%d" % n, "place": "R02",
		"what": {1: "구로 107동 판자에 '사람 있음'이 쓰였다", 2: "127번이라 불리던 사람이 고향 봉천에 자리를 잡았다",
			3: "새벽인력 우리를 나온 부부가 지하시장에 칸을 얻었다", 9: "127번이 우리를 나왔지만 이름을 불러 줄 사람이 없었다"}[n], "seen_by": [], "about": []})
	_close(7 if n == 9 else n, "재회")


func _give_list() -> void:
	if v("SQ_S09_LISTGIVEN") == 1:
		return
	_sv("SQ_S09_LISTGIVEN", 1)
	st.call_fn("aff", ["JC_BC", 5])


## 우리 안에서 눈 붙이기(해 보고 싶은 짓): 새벽 두 시 경비 교대까지
func _nap() -> void:
	var h := _hour()
	var t := Clock.parse(host.date_text)
	var now := h * 60 + (int(t[4]) if not t.is_empty() else 0)
	var mins := (26 * 60 - now) % (24 * 60)
	host.ev.run("fade_out", ["black", "6"], func() -> void:
		host.advance_minutes(maxi(1, mins))
		if v("SB_127") < 2 and not st.is_dead(YJ):
			host.hint("새벽 두 시. 감시 의자가 비었다. 옆 칸에서 속삭임 — \"세 번째 선이야.\"", 5.0)
		else:
			host.hint("새벽 두 시. 감시 의자가 비었다.", 4.0)
		host.ev.run("fade_in", ["black", "6"], func() -> void: pass))
