## 영등포(R02) 사이드 퀘스트 SQ-S08 「같은 명찰의 두 사람」 진행기(단계 1-11g, SD-04a §5.1). 원고: script/act1/SQ-S08.txt · MQ-103.txt(노복희 해법 B) ·
##   JM_PEOPLE.txt(금하람 D 판) · terms/r02_market.txt(명부 단말 TM-J04 — 열람이 사실을 세운다). 맵: J-02 · J-03 광장(다툼 · 김민수 셔터 · 간판) · J-04 · J-09 초소 · K-15 구청 배급소 · K-33 출입 카드.
## 단계는 이 진행기 한 곳에서만, 오르기만 한다(SD-20). 어느 쪽에서 먼저 와도(구청 · 초소 · 명부) 이미 아는 만큼 따라 올린다(P2).
## 2077 사실 한 벌(P1): 김민수 = 상가 야간 경비원(2등급) · 00:10 남쪽 통로 순찰 · 무전 00:31 끊김 · 경비실 예비 명찰 2개 분실 — 명부 · 분실물 쪽지 · 초소 수첩이 같은 사실.
## 재미 검수(SD-23 계획 때 8건 + 해골 번호표): plan _plans/SQ-S08_plan.md.
class_name SideS08
extends Node

const A_ID := "N-R02-015"                   ## 김민수 A — 하경수(짐꾼)
const B_ID := "N-R02-016"                   ## 김민수 B — 봉재민(수리공)
const WI := "N-R02-023"                     ## 위동현(구청 창구)
const HAM := "N-R02-009"
const TICKET_FROM := 411                    ## 전광판 번호 — 200년째 0411(5등급 줄 맨 앞 해골 오순례)에 멎어 있다. 주인공 번호표는 0413
const TICKET_MINE := 413
const DRAWER := Vector2i(7, 3)              ## K-15 창구 뒤 서류함
const CARD_DESK := Vector2i(1, 3)           ## K-33 직원 서랍(M-073)
const STRAIN_DAYS := [3, 5, 7]              ## 기록을 찾은 뒤 긴장 바크 · 간판 줄 · 끝(D 또는 하나 남은 김민수)

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _ghouls: Array = []


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s08"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.enemy_down.connect(_on_down)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v(k, n)


func _log(s: String) -> void:
	if log_on:
		print("[명찰] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S08")


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S08", n)
		_log("단계 %d" % n)


func _zone() -> String:
	return host.map.id if host.map != null else ""


func _dead(id: String) -> bool:
	return st.is_dead(id)


## 퀘스트가 열린다(10) — 이미 안 사실만큼 따라 올린다(P2)
func _start(why: String) -> void:
	if v("V_ACT") < 1:
		return
	if stage() == 0:
		_up(10)
		_log("발동(%s)" % why)
	_catch_up()


func _catch_up() -> void:
	if stage() < 10:
		return
	if v("SQ_S08_LEDGER") >= 2:
		_up(20)
	if v("SQ_S08_DEAD") == 1 or v("SQ_S08_NOTEBOOK") == 1:
		_up(20)
		_up(30)
	if v("SQ_S08_DESK") >= 1:
		_up(40)
	if v("SQ_S08_MATCH") == 1:
		_up(40)
		_up(50)
	if (v("SQ_S08_MATCH") == 1 or v("SQ_S08_NOTEBOOK") == 1) and v("SQ_S08_SAW") == 1:
		if v("SQ_S08_FOUND_DAY") == 0:
			_sv("SQ_S08_FOUND_DAY", day())                                    # D 시계: 다툼을 보고 기록을 찾은 날부터(재미 검수 — 다툼 전 수첩은 시계를 켜지 않는다)


func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	if host.map == null or host.player == null or v("V_ACT") < 1:
		return
	tick()


func tick() -> void:
	if v("SQ_S08_LEDGER") >= 2 or v("SQ_S08_DEAD") == 1:
		_start("명부")
	_catch_up()
	match _zone():
		"K-15":
			_drawer_tick()
		"J-03":
			_quarrel_tick()
	_resolve()


# ---------------------------------------------------------------- 광장 다툼(지하시장 첫 방문 뒤 — 광장에 두 번째로 들어섰을 때부터)
func _quarrel_tick() -> void:
	if v("SQ_S08_SAW") == 1 or v("SQ_S08_SOL") != 0 or v("SQ_S08_SEEN_B") < 2 or host.box.active or host.ev.busy() or host.busy:
		return
	if _dead(A_ID) or _dead(B_ID):
		return
	var q := host.map.mark_pos("quarrel")
	if host.player.loco.logical.distance_to(q) > 9.0 * 32.0:
		return
	_sv("SQ_S08_SAW", 1)                                                   # 다시 열리지 않게(장면 끝에서 saw가 단계를 세운다)
	host.ev._show_actor("S8A", q + Vector2(-24, 0), "E", str(host.ev.cast_sheets.get(A_ID, "")))   # 짐꾼이 J-02에서 내려와 분수대 앞에(연출 배우)
	if host.ev.actors.has(B_ID):
		host.ev.run("go", [B_ID, "%d,%d" % [int(q.x / 32) + 1, int(q.y / 32)]], func() -> void: pass)
	host.box.finished.connect(func() -> void:
		if host.ev.actors.has("S8A"):
			host.ev.run("go", ["S8A", "19,3"], func() -> void: pass)
			_hide_later("S8A"), CONNECT_ONE_SHOT)
	host.play_scene("SQS08_QUARREL")


func _hide_later(id: String) -> void:
	if is_inside_tree():
		await get_tree().create_timer(6.0).timeout
	if host.ev.actors.has(id):
		host.ev.run("hide", [id], func() -> void: pass)


# ---------------------------------------------------------------- 구청: 서류함(자물쇠 25 — 원본 · 목격이면 창구 하루 닫힘)
func _drawer_tick() -> void:
	if v("SQ_S08_DESK") != 0:
		return
	var b: Variant = host.map.boxes.get(DRAWER)
	if b == null:
		return
	var c: Dictionary = host.box_contents(b)
	if int(c.get("opened", 0)) <= 0:
		return
	_sv("SQ_S08_DESK", 4)
	_sv("SQ_S08_GRADE", 1)                                                 # 원본엔 등급이 붙어 있다
	if not _dead(WI):
		st.call_fn("karma", [-5])                                          # 산 공무원의 서류함(죽은 뒤엔 빈 창구 — 훔칠 주인이 없다)
	host.hint("서류함 원본 — 증명사진 두 장과 이름 둘, 하경수 · 봉재민. 등급 칸: 3 · 5. 어느 얼굴이 어느 김민수인지는 직접 맞춰 봐야 한다.", 7.0)
	if not _dead(WI) and host.theft_witness() == WI:
		_sv("SQ_S08_SHUT", day() + 1)                                      # 다음 날 06시까지 창구 폐쇄
		host.hint("위동현: \"규정 위반입니다.\" — 둘째 창구에 '업무 마감' 팻말이 내려온다.", 5.0)
	_start("서류함")
	_catch_up()


# ---------------------------------------------------------------- 남쪽 통로 초소: 먹이 냄새를 따라 모인 구울 넷(30 뒤 · 수첩 전)
func _spawn_ghouls() -> void:
	_ghouls.clear()
	if v("SQ_S08_GHOULS") == 2 or v("SQ_S08_NOTEBOOK") == 1 or stage() < 30:
		return
	for k in ["g1", "g2", "g3", "g4"]:
		var e := host.combat.spawn("CR-200", host.map.mark_pos(k), host.map, st, {"lv": 4, "dir": host.map.mark_dir(k)})
		e.set_meta("s08g", 1)
		_ghouls.append(e)
	_sv("SQ_S08_GHOULS", 1)


func _on_down(e: Enemy) -> void:
	if not e.cmb.dead or not e.has_meta("s08g"):
		return
	_ghouls.erase(e)
	if _ghouls.all(func(o): return not is_instance_valid(o) or o.cmb.dead):
		_sv("SQ_S08_GHOULS", 2)


# ---------------------------------------------------------------- 해법
## 둘 다 본명을 받아들였다(죽은 쪽은 빼고) → A. 한쪽만 받아들이고 시간이 지나면 '하나 남은 김민수'(재미 검수 7, _on_day)
func _resolve() -> void:
	if v("SQ_S08_SOL") != 0:
		return
	var a_ok := v("SQ_S08_TOLD_A") == 1 or _dead(A_ID)
	var b_ok := v("SQ_S08_TOLD_B") == 1 or _dead(B_ID)
	if a_ok and b_ok and (v("SQ_S08_TOLD_A") == 1 or v("SQ_S08_TOLD_B") == 1):
		_solve(1)
	elif _dead(A_ID) and _dead(B_ID) and stage() >= 10:
		_solve(6)                                                          # 둘 다 죽었다 — 이름을 돌려줄 사람이 없다(끊겨도 반쯤 된 상태 없음, P10)


func _solve(sol: int) -> void:
	if v("SQ_S08_SOL") != 0:
		return
	_sv("SQ_S08_SOL", sol)
	_sv("SQ_S08_DAY", day())
	_start("해법")
	_up(100)
	var karma := {1: 50, 2: 25, 3: 75, 4: 0, 5: 25, 6: 0}
	var jh := {1: 5, 2: 5, 3: 8, 4: 0, 5: 3, 6: 0}
	st.call_fn("karma", [int(karma[sol])])
	if int(jh[sol]) > 0:
		st.call_fn("aff", ["JH", int(jh[sol])])
	if sol not in [4, 6]:
		st.call_fn("xp", [250 if sol != 5 else 150])
		_sv("SQ_S08_FIX_DAY", day() - 7)
	st.deeds.record(st, "side", "R02", 2, {"JH": 0}, Clock.abs_min(host.date_text), {"tag": "SQS08_%d" % sol, "place": "JH",
		"what": {1: "지하시장 김민수 둘이 본명을 찾았다", 2: "지하시장에 김민수가 둘이 됐다", 3: "남쪽 통로의 진짜 김민수가 광장에 셔터 한 칸을 얻었다",
			4: "지하시장 김민수 둘이 주먹다짐 끝에 진료소에 누웠다", 5: "지하시장 김민수 하나가 본명을 찾고, 하나는 김민수로 남았다",
			6: "지하시장의 두 김민수가 모두 죽었다 — 본명은 서류함에 남았다"}[sol], "seen_by": ["JH"], "about": []})
	_paint()
	_log("해법 %d" % sol)


## 결과 판: 광장 셔터 · 간판 · 초소 유해 · 전광판(맵에 들어설 때마다)
func _paint() -> void:
	if host.map == null:
		return
	match _zone():
		"J-03":
			if v("SQ_S08_SOL") in [3, 6] or v("SQ_S08_LATE") == 1:
				host.map.set_prop_state(Vector2i(24, 1), "named")
			if v("SQ_S08_SOL") in [1, 3] or (v("SQ_S08_SOL") == 5 and v("SQ_S08_TOLD_B") == 1):
				host.map.set_prop_state(Vector2i(36, 4), "bong")
		"J-09":
			if v("SQ_S08_NOTEBOOK") == 1 or v("SQ_S08_SOL") == 3:
				host.map.set_prop_state(Vector2i(6, 4), "taken")
		"K-15":
			if v("SQ_S08_DESK") == 1:
				host.map.set_prop_state(Vector2i(17, 1), "next")
			elif v("SQ_S08_PROXY") >= 2:
				host.map.set_prop_state(Vector2i(17, 1), "skip")              # 0411 오순례가 불렸다 — 200년 만에 한 칸


func _on_map(_id: String) -> void:
	if host.map == null:
		return
	_barks()
	match _zone():
		"J-03":
			_sv("SQ_S08_SEEN_B", mini(9, v("SQ_S08_SEEN_B") + 1))           # 광장 방문 횟수(다툼은 두 번째부터 — '첫 방문 이후')
		"J-09":
			_spawn_ghouls()
		"K-15":
			if v("SQ_S08_SAW") == 1 or v("SQ_S08_LEDGER") >= 1:
				_start("구청")
		"K-33":
			var cb: Variant = host.map.boxes.get(CARD_DESK)
			if cb != null and v("SQ_S08_CARD") == 0:
				_sv("SQ_S08_CARD", 1)                                          # 관공서 출입 카드 M-073 한 장(원문 '봉천 동 주민센터에서 얻는다') — 한 번만
				var items: Dictionary = host.box_contents(cb).get("items", {})
				items["M-073"] = int(items.get("M-073", 0)) + 1
				host.box_contents(cb)["items"] = items
	_paint()


## 지나가며 하는 말이 결과를 안다(재미 검수 ⑤): 두 김민수 · 광장 인지영
func _barks() -> void:
	var sol := v("SQ_S08_SOL")
	var a_named := v("SQ_S08_TOLD_A") == 1 or sol in [1, 3]
	var b_named := v("SQ_S08_TOLD_B") == 1 or sol in [1, 3]
	var lines := {}
	if sol == 2:
		lines = {A_ID: "큰 민수야. 짐 있으면 말해. …걸레질? 이제 안 해. 내 가게 아니잖아.", B_ID: "작은 민수네 수리. 주 1회는 공짜야."}
	elif sol == 4:
		lines = {A_ID: "(붕대 감은 팔로 셔터를 닦는다)", B_ID: "(반쪽 난 명찰을 만지작거린다) 수리 안 해. 오늘은."}
	else:
		if a_named:
			lines[A_ID] = "하경수야. 짐 들 때 이름 불러 줘. 힘이 나." if sol != 3 else "하경수야. 저 셔터, 이제 김민수 거야. 진짜 김민수."
		if b_named:
			lines[B_ID] = "봉 수리. 고칠 거 있어? 주 1회는 공짜."
		if sol == 5:
			if not a_named:
				lines[A_ID] = "이제 김민수는 나 하나야. …셔터는 계속 닦을래. 습관이야."
			if not b_named:
				lines[B_ID] = "김민수는 나 하나 남았어. 명찰 봐. …좋을 줄 알았는데."
	if sol == 0 and v("SQ_S08_STRAIN") >= 1:
		lines["N-R02-014"] = "어제 또 소리 질렀대, 김민수 둘이. 저러다 주먹 나가." if v("SQ_S08_STRAIN") == 1 else "수리 간판 이름 위에 누가 칼로 줄을 그었어. 큰일 나겠다."
	elif sol == 2:
		lines["N-R02-014"] = "큰 민수, 작은 민수. 이름 하나로 둘이 사는 법도 있더라."
	for n in host.npcs:
		if lines.has(str(n["id"])):
			n["bark"] = lines[str(n["id"])]


# ---------------------------------------------------------------- 하루 판정: D 시계 · 창구 폐쇄 풀림
func _on_day(_d: int) -> void:
	if v("SQ_S08_SOL") != 0 or v("SQ_S08_FOUND_DAY") == 0:
		return
	var n := day() - v("SQ_S08_FOUND_DAY")
	if n >= STRAIN_DAYS[2]:
		if (v("SQ_S08_TOLD_A") == 1) != (v("SQ_S08_TOLD_B") == 1):
			_solve(5)                                                      # 한쪽만: 남은 쪽이 '하나 남은 김민수'(재미 검수 7)
		elif not _dead(A_ID) and not _dead(B_ID):
			_solve(4)                                                      # 그대로 두기: 주먹다짐 → 진료소
	elif n >= STRAIN_DAYS[1]:
		_sv("SQ_S08_STRAIN", 2)                                            # 간판 이름 위에 칼줄
	elif n >= STRAIN_DAYS[0]:
		_sv("SQ_S08_STRAIN", 1)                                            # '어제 또 소리 질렀대'


# ---------------------------------------------------------------- 원고 명령(@cmd s08 …)
func _cmd(a: Array, done: Callable) -> void:
	var what := str(a[0]) if a.size() > 0 else ""
	var arg := str(a[1]) if a.size() > 1 else ""
	match what:
		"saw":
			_sv("SQ_S08_SAW", 1)
			_start("다툼")
		"ledger_ok":
			_sv("SQ_S08_LEDGER", maxi(1, v("SQ_S08_LEDGER")))
			host.term_state("TM-J04")["unlocked"] = true                   # 함준호가 '안 보는 사이' — 해킹 없이(소유 카르마 없음)
			_start("함준호")
		"ticket":
			_sv("SQ_S08_TICKET", 1)
			_sv("SQ_S08_WAIT", TICKET_FROM)
			_start("번호표")
		"wait":
			done.call()
			_wait()
			return
		"desk":
			_sv("SQ_S08_DESK", {"line": 1, "talk": 2, "card": 3, "names": 5}.get(arg, 2))
			_start("창구")
			_catch_up()
			_paint()
		"match":
			_sv("SQ_S08_MATCH", 1)
			_catch_up()
		"grade":
			_sv("SQ_S08_GRADE", 1)
		"take411":
			_sv("SQ_S08_PROXY", 1)
		"proxy":
			_sv("SQ_S08_PROXY", 2)
			st.call_fn("karma", [5])
		"notebook":
			_sv("SQ_S08_NOTEBOOK", 1)
			_sv("SQ_S08_DEAD", 1)                                          # 수첩 마지막 장 = 사망자 칸과 같은 사실(이미 앎, P2)
			_start("초소")
			_catch_up()
			_paint()
		"note":                                                            # 김민수 둘에게 수첩을 보여 준다 → 대화가 닫히면 수첩 장면(C 수습 제안)
			host.box.finished.connect(func() -> void: host.play_scene.call_deferred("SQS08_NOTEBOOK"), CONNECT_ONE_SHOT)
		"addr":
			_sv("SQ_S08_ADDR", 1)
		"tool":
			_sv("SQ_S08_TOOL", 1)
		"told":
			_sv("SQ_S08_TOLD_A" if arg == "a" else "SQ_S08_TOLD_B", 1)
			_resolve()
		"both":
			_solve(2)
		"one":
			_solve(5)                                                      # 노복희 — 한쪽이 이미 본명을 받아들였다(재미 검수 ④)
		"late":
			_late()
		"lay":
			_sv("SQ_S08_PROXY", 3)                                         # 빈 창구 도장 옆에 0411(위동현 사망 — 해 보고 싶은 짓)
			if host.map != null and _zone() == "K-15":
				host.map.set_prop_state(Vector2i(17, 1), "skip")
		"carry":
			done.call()
			_carry()
			return
		"reward":
			if v("SQ_S08_REWARD") == 0:
				_sv("SQ_S08_REWARD", 1)
				st.call_fn("caps", [100])
				host.term_state("TM-J04")["unlocked"] = true
		"fix":
			_free_fix()
	done.call()


## 진료소 뒤 늦은 이름(재미 검수 ②): 그대로 두기(D)로 끝난 뒤 기록을 내밀면 둘이 본명을 받아들인다 — 반쪽 명찰을 셔터에(보상은 줄여서)
func _late() -> void:
	if v("SQ_S08_SOL") != 4 or v("SQ_S08_LATE") == 1:
		return
	_sv("SQ_S08_LATE", 1)
	_sv("SQ_S08_SOL", 1)
	_sv("SQ_S08_TOLD_A", 1)
	_sv("SQ_S08_TOLD_B", 1)
	st.call_fn("karma", [25])
	st.call_fn("aff", ["JH", 2])
	st.call_fn("xp", [100])
	_sv("SQ_S08_FIX_DAY", day() - 7)
	st.deeds.record(st, "side", "R02", 2, {"JH": 0}, Clock.abs_min(host.date_text), {"tag": "SQS08_LATE", "place": "JH",
		"what": "지하시장 김민수 둘이 진료소에서 나와 본명을 찾았다 — 반쪽 명찰은 셔터에", "seen_by": ["JH"], "about": []})
	_paint()
	_log("늦은 이름(D → A)")


## 대기 의자: 화면이 어두워졌다 밝아지며 전광판이 한 칸씩 — 위동현이 해골 줄을 보고 번호를 부른다(재미 검수 1)
func _wait() -> void:
	host.ev.run("fade_out", ["black", "5"], func() -> void:
		host.advance_minutes(60)
		_sv("SQ_S08_WAIT", TICKET_MINE)
		if v("SQ_S08_PROXY") >= 2:
			host.hint("위동현: \"0412번 손님…\" (빈 의자를 한 번 본다) 진공관 숫자가 한 칸씩 넘어간다.", 5.0)
		else:
			host.hint("위동현: \"0411번 손님…\" (5등급 줄 맨 앞 해골을 한 번 본다) \"…0412번.\" 200년 만에 진공관 숫자가 넘어간다.", 5.0)
		host.ev.run("fade_in", ["black", "5"], func() -> void:
			if host.map != null and _zone() == "K-15":
				host.map.set_prop_state(Vector2i(17, 1), "next")
			host.play_scene("SQS08_DESK", "CALLED_IN")))


## C 진짜 김민수: 두 사람이 들것으로 유해를 광장에 옮긴다(한 시간) → 김민수 셔터
func _carry() -> void:
	_sv("SQ_S08_CARRY", 1)
	host.ev.run("fade_out", ["black", "8"], func() -> void:
		host.advance_minutes(60)
		var who := "두 사람이" if not _dead(A_ID) and not _dead(B_ID) else "남은 한 사람이"
		host.hint("%s 남쪽 통로에서 들것을 든다. 둥지 옆을 지나 광장까지 — 아무도 말하지 않는다." % who, 6.0)
		_sv("SQ_S08_NOTEBOOK", 1)
		_solve(3)
		host.ev.run("fade_in", ["black", "8"], func() -> void: pass))


## 봉 수리: 주 1회 무료 — 가진 무기 중 가장 상한 것 한 단계(SD-04a 보상)
func _free_fix() -> void:
	var worst := ""
	var wc := 0
	for k in st.items.keys():
		var key := str(k)
		if not key.begins_with("W-") or int(st.items[k]) <= 0:
			continue
		if Gear.cond(key) > wc:
			wc = Gear.cond(key)
			worst = key
	if worst == "":
		host.hint("봉재민: \"고칠 게 없네. 다음 주에 와.\"", 4.0)
		return
	var nk := Gear.improve(st, worst, 1, 0)
	if nk != worst:
		host.combat.rekey(worst, nk, st)
		_sv("SQ_S08_FIX_DAY", day())
		host.hint("봉재민이 %s을 손본다 — '%s'." % [str(host.items_db.get(Gear.base(nk), {}).get("name", nk)), Gear.NAMES[Gear.cond(nk)]], 4.0)
