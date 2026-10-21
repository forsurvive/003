## 세력 퀘스트 FQ-JH-03 「지상 배달」 진행기(단계 1-12e, SD-04d §8.5). 원고: script/act1/FQ-JH-03.txt(검문 · 모집원 · 상자 살펴보기 · 계약 끝) ·
## MQ-103.txt(박춘삼 계약 · 노복희) · TRAVEL.txt(소윤희 건넴) · HP.txt(반수빈) · R01_NORTH.txt(심도겸 팔기). 계획 docs/seoul-fallout/_plans/1-12c_FQ-JH-01-03_plan.md §5.
## 박춘삼이 있는 곳은 FQ_JH03_PARK 한 곳(P1): 0 북쪽 출구 일과 · 1 계약 동행 · 2 돌아가는 중(BACK 날 06시에 0) · 3 모집원에게 넘겨짐.
## 낮 지상 시계(CLOCK): 박춘삼이 바깥에 있는 동안(곁이든 '기다려'든 — OUT) 06~18시와 겹친 분만 쌓인다. 지하 · 건물 안에선 멈춘다. 120분이면 계약 끝.
## 쉬기(대기 · 잠)는 그가 곁이면 지하에서만 — 바깥은 '계약서엔 그런 줄 없어', 지상 건물 안은 '판독기는 유리 너머도 봐'(재미 검수: 실내 대기로 밤까지 버티는 구멍).
## 남은 시간 신호는 게임 분에 건다(90 · 60 · 30 · 10분 남음 — 한 번씩 서서 몸짓 + 한 줄). 수산시장에서 낮에 75분 넘게 남기고 건네면 남은 시간은 그의 몫(경매장 뒤 강가, RIVER — 빨리 온 사람의 상, 재미 검수).
## 길 위 바크 셋(BARK 비트): 대방 지하차도 입구 · 둑길 들것 · 경매장 칠판 — 그가 곁일 때 한 번씩, 계약서 얘기 없이.
## 소윤희는 상자를 기다리는 동안(WAIT — 출발한 날 다음 날 18시까지) 수산시장(MEDIC_AT 4, caravans.gd) — 낮엔 경매장, 밤엔 시장 뒤 터. 그 뒤엔 순회 정류지 어디서든 받는다.
## 결과(SOL)는 한 번(P9): 1 박춘삼과 배달 +10 · 2 혼자 +8 · 3 상자 팖 −8(200) · 4 반수빈(소윤희 사망) +8 · 5 덮음(노복희 사망 · 지하시장 적대, 200).
class_name FqJh3
extends Node

signal want_save(why: String)

const Q := "FQ-JH-03"
const PARK := "C-018"                                                    ## 박춘삼(계약 경호 구울)
const BOX_ID := "M-426"                                                  ## 의약품 상자(무게 10)
const FAKE_ID := "M-062"                                                 ## 위조 주민등록증
const BUDGET := 120                                                      ## 계약 조항 '해 떠 있는 동안 두 시간'
const SIGNS := [[30, 8, "(박춘삼이 계약서를 꺼내 맨 아랫줄을 본다) 해가 넉넉해. …아직은."], [60, 1, "(박춘삼이 계약서를 꺼내 접었다 편다) …한 시간."],
	[90, 2, "(박춘삼이 걸음을 멈추고 하늘을 본다) 해가 아직 높아. 반 시간."], [110, 4, "(박춘삼이 길어진 제 그림자를 내려다본다) 해 그림자가 길다. 서둘러."]]   ## [쌓인 분, SKY 비트, 몸짓 + 한 줄]
const RIVER_LEFT := 75                                                   ## 수산시장에서 낮에 이만큼 넘게 남기고 건네면 남은 시간은 그의 몫(서류 · 줄에 쓴 시간은 이 상을 잃는다)
const BARKS := [[Vector2i(819, 1162), 1, 7.0, "박춘삼: \"2077년엔 여기서 다들 경적을 눌렀어. 그날 밤엔 아무도 안 눌렀고.\""],
	[Vector2i(869, 1135), 2, 5.0, "박춘삼: \"'고마워요'. 누가 누구한테 썼는지 몰라도 계약서보다 짧고 좋네.\""],
	[Vector2i(893, 1163), 4, 4.0, "박춘삼: \"광어 38,000원. 10월 월급 받으면 사려고 했지. …아직 못 받았어.\""]]   ## [자리, BARK 비트, 반경(칸), 한 줄] — 지하차도 입구 · 둑길 들것 · 경매장 칠판
const UNDER_SETS := ["jm", "sd", "cv"]                                   ## 지하 맵 묶음(지하시장 · 지하철 · 굴/지하차도) — Y-(벙커) · V-/SV-(볼트)도 지하
const NEAR := 6.0                                                        ## '곁에 있다'(칸)
const POST := Vector2i(862, 1169)                                        ## 다리목 분대 이동 검문(노량진로 — 대방에서 수산시장으로 가는 큰길)
const SPAWN_R := 60.0                                                    ## 이만큼 다가오면 분대를 세운다
const SEE_R := 25.0                                                      ## 박춘삼이 검문을 알아본다(로그 30)
const MEET_R := 6.0                                                      ## 검문조장이 말을 건다(큰길로 걸어 들어왔을 때)
const SIGHT := 12.0                                                      ## 낮 분대 눈(웅크리면 절반) — 우회를 골랐거나 웅크려 지나가다 이 안에 들면 '거기 짐꾼!'
const RECPOINT := Vector2i(926, 1163)                                    ## 모집원 집결 지점(수산시장 동쪽) — 넘긴 박춘삼을 여기까지 끌고 간다
const MARKET := Vector2i(897, 1165)                                      ## 수산시장 경매장(L-R01-25)
const BACKLOT := Vector2i(895, 1153)                                     ## 시장 뒤 터(밤 대기 · 고정 매복 지점, SD-06 §12.3)
const MARKET_R := 30.0                                                   ## 로그 40(소윤희가 기다린다)
const REC_R := 25.0                                                      ## 모집원이 나타나는 거리(시장에서 — 검문 자리 둘레 15칸은 뺀다)
const REC_PAY := 120
const QUEUE_SHEETS := ["en_refugee_loco", "en_refugee_b_loco", "en_trader_loco", "en_trader_b_loco"]   ## 검문 줄 행인(날마다 수 · 얼굴 다르게)
const NIGHT_PACKS := [["CR-420", "CR-423", "CR-421"], ["CR-200", "CR-200", "CR-201"], ["CR-104", "CR-104", "CR-106"]]   ## 약 냄새를 맡은 밤 무리(날마다 다르게)

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _esc_t := 0.0                                                        ## 끌려가는 걸음 시간(넘긴 뒤)
var _rescue := false                                                     ## 끌고 가던 무리가 다 쓰러졌다 — 되찾음 장면 차례
var _rescue_shown := false
var squad := {}                                                          ## 이동 검문 분대 {men, lead, state}
var rec := {}                                                            ## 모집원 {men, lead, state}
var _part_wait := false                                                  ## 계약 끝 장면을 띄울 차례
var _ambush := false                                                     ## 밤 뒤 터에서 건넸다 — 대화가 닫히면 무리
var stage_set := {"props": [], "people": []}                             ## 검문 자리 차림(차단대 · 판독기 삼각대 · 줄 선 행인) — 분대와 함께 서고, 멀어지면 거둔다


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["jh03"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.wait_vetoes.append(_wait_veto)
	host.travel_blocks.append(_travel_veto)


func v(k: String) -> int:
	return int(st.vars.get_v("FQ_JH03_" + k))


func _s(k: String, n: int) -> void:
	st.vars.set_v("FQ_JH03_" + k, n)


func gv(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[지상 배달] " + s)


func day() -> int:
	return maxi(1, gv("GAME_DAY"))


func now() -> int:
	return Clock.abs_min(host.date_text)


func stage() -> int:
	return st.quests.stage(Q)


func _up(n: int) -> void:
	var s := stage()
	if s < n and s < 100:
		st.quests.set_stage(Q, n)
		_log("단계 %d" % n)


func daylight() -> bool:
	var h := gv("GAME_HOUR")
	return h >= 6 and h < 18


func _paused() -> bool:
	return host.busy or host.ev.busy() or (host.box != null and host.box.active)


func _world() -> bool:
	return host.map != null and host.map is WorldMap


## 지하인가(쉴 수 있는 곳): 지하시장 · 지하철 · 굴/지하차도 · 벙커 · 볼트
func underground() -> bool:
	if host.map == null or host.outdoor():
		return false
	var id := str(host.map.id)
	return str(host.map.data.get("set", "")) in UNDER_SETS or id.begins_with("Y-") or id.begins_with("V-") or id.begins_with("SV-")


func _mate() -> Dictionary:
	return host.combat.mates.get_mate(PARK)


func park_dist() -> float:
	var m := _mate()
	if m.is_empty() or not is_instance_valid(m["actor"]) or host.player == null:
		return 1e9
	return (m["actor"] as Actor).loco.logical.distance_to(host.player.loco.logical) / 32.0


func _tile() -> Vector2i:
	return host.map.tile_of(host.player.loco.logical) if host.player != null and host.map != null else Vector2i(-9999, -9999)


func _dist_to(t: Vector2i) -> float:
	return Vector2(_tile() - t).length()


## [a, b) 절대 분 가운데 낮(06~18)과 겹친 분
static func daylight_min(a: int, b: int) -> int:
	if b <= a:
		return 0
	var out := 0
	var d0 := a / 1440
	var d1 := (b - 1) / 1440
	for d in range(d0, d1 + 1):
		var lo := maxi(a, d * 1440 + 360)
		var hi := mini(b, d * 1440 + 1080)
		if hi > lo:
			out += hi - lo
	return out


# ---------------------------------------------------------------- 시간
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	tick(_t)
	_t = 0.0


func tick(dt := 0.5) -> void:
	var s := stage()
	if s > 0 and s < 100 and (st.known_dead("C-050") or gv("AFF_JH") <= -60):
		_close()
	_s("ROOM", 1 if host.combat.mates.list.size() < Companions.MAX or not _mate().is_empty() else 0)
	if v("BOX") == 1 and s >= 10 and s < 100 and _world() and _dist_to(MARKET) <= MARKET_R:
		_up(40)
	if v("PARK") == 1:
		_tick_park(dt)
	else:
		_s("NEAR", 0)
	if v("PARK") == 4:
		_escort_tick(dt)
	if _world():
		_check_tick()
		_rec_tick()
		_bark_tick()
		_queue_talk()
		if squad.is_empty() and not _stage_empty() and _dist_to(POST) > SPAWN_R:
			_stage_clear()
	elif not squad.is_empty() or not rec.is_empty():
		squad = {}
		rec = {}
	if _ambush and not _paused():
		_ambush = false
		_night_pack()
	if _part_wait and not _paused():
		_part_wait = false
		host.play_scene("JH03_PART")


func _tick_park(dt: float) -> void:
	if host.player == null:
		return
	var m := _mate()
	if m.is_empty() and not host.combat.mates.away.has(PARK) and not _paused():
		host._bring_buddy(PARK)                                           # 불러오기 뒤 · 맵을 건넌 뒤 다시 곁에
		host.combat.mates.set_mode(PARK, "follow")
		m = _mate()
	if not m.is_empty():
		_s("OUT", 1 if host.outdoor() else 0)                             # 그가 선 곳(기다리게 두면 그 자리 값이 남는다)
		var cmb: Combatant = m["cmb"]
		_s("HURT", 1 if cmb.hp < cmb.max_hp * 0.6 else 0)
	_s("NEAR", 1 if park_dist() <= NEAR else 0)
	var n := now()
	var last := v("LAST") if v("LAST") > 0 else n
	if v("OUT") == 1:
		_s("CLOCK", mini(BUDGET, v("CLOCK") + daylight_min(last, n)))
	_s("LAST", n)
	if v("CLOCK") < BUDGET and not m.is_empty() and host.outdoor() and daylight() and not _paused():
		for sg in SIGNS:
			if v("CLOCK") >= int(sg[0]) and v("SKY") & int(sg[1]) == 0:
				_s("SKY", v("SKY") | int(sg[1]))
				_sign(str(sg[2]))
				break
	if v("CLOCK") >= BUDGET and v("END") == 0:
		_end_contract(1)
	elif v("BOX") == 1 and v("WAIT") > 0 and n >= v("WAIT") and v("END") == 0:
		_end_contract(2)                                                  # 의료반이 수산시장을 떠났다 — 계약서엔 '수산시장까지'


## 남은 시간 신호: 선다 → 몸짓 → 다시 따라온다(발 고정 — 미끄러지지 않게 모드로 세운다, HUD 숫자 없음 — 원문 L1034)
func _sign(line: String) -> void:
	var m := _mate()
	if m.is_empty() or not is_instance_valid(m["actor"]):
		return
	host.combat.mates.set_mode(PARK, "wait")
	(m["actor"] as Actor).loco.facing = 6                        # 북쪽(하늘 쪽)
	host.hint(line, 4.0)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if v("PARK") == 1 and not _mate().is_empty() and str(_mate()["mode"]) == "wait":
			host.combat.mates.set_mode(PARK, "follow"))


## 계약이 끝났다: 곁이면 장면으로(그가 말하고 떠난다), 멀리 있으면 안내 한 줄
func _end_contract(why: int) -> void:
	_s("END", why)
	if not _mate().is_empty():
		_part_wait = true
	else:
		_part()
		host.hint("어딘가에서 박춘삼이 계약서를 접고 지하로 돌아갔을 것이다 — '해 떠 있는 동안 두 시간'." if why == 1 else "박춘삼은 계약대로 지하로 돌아갔을 것이다.", 6.0)
	_log("계약 끝(%d)" % why)


## 박춘삼이 떠난다(계약 끝 · 배달 · 생포 틈 · 돌려보냄): 동행에서 빼고 다음 날 06시에 북쪽 출구 일과로(P3)
func _part() -> void:
	_drop()
	if v("PARK") == 1:
		_s("PARK", 2)
		_s("BACK", day() + 1)
	_s("NEAR", 0)
	want_save.emit("jh03")


func _drop() -> void:
	if not _mate().is_empty():
		var a = _mate()["actor"]
		host.combat.mates.remove(PARK)
		host._sync_mates()
		if is_instance_valid(a) and host.ev.actors.has(PARK):
			host.ev.run("hide", [PARK], func() -> void: pass)
	host.combat.mates.away.erase(PARK)


func _join() -> void:
	for n in host.npcs.duplicate():                                        # 북쪽 출구의 박춘삼을 동행으로 떼어 낸다(맵 인물 다시 세우기가 지우지 않게, A35)
		if str(n["id"]) == PARK:
			host.npcs.erase(n)
			if is_instance_valid(n["actor"]):
				host.map.blockers.erase(n["actor"])
			host.sync_residents()
	if _mate().is_empty():
		if host.ev.actors.has(PARK):
			host.ev.handlers["buddy"].call([PARK], func() -> void: pass)
		else:
			host._bring_buddy(PARK)
	host.combat.mates.set_mode(PARK, "follow")


func _wait_veto() -> String:
	if v("PARK") != 1 or _mate().is_empty() or underground():
		return ""
	if not host.outdoor():
		return "박춘삼: \"유리창 있는 데선 못 자. 판독기는 유리 너머도 봐. 쉬려면 지하로 가.\""
	return "박춘삼: \"지상에서 자자고? 계약서엔 그런 줄 없어.\"" if daylight() else "박춘삼: \"밤엔 걷는 거야. 쉬는 건 지하에서.\""


func _travel_veto(_lid: String) -> String:
	if v("PARK") == 1 and not _mate().is_empty() and daylight():
		return "박춘삼: \"낮엔 지도 보고 큰길로 못 가. 그늘 따라 걸어야 해.\""
	return ""


## 06시 하루 판정(P6): 돌아간 박춘삼이 일과로 · 넘긴 일이 상가에 알려짐(국태윤이 빈자리에서 새벽인력 도장 계약서를 찾는다, P7)
func _on_day(_d: int) -> void:
	if v("PARK") == 2 and day() >= v("BACK"):
		_s("PARK", 0)
		_log("박춘삼 일과로")
	if v("REC") == 3 and v("KNOWN") == 0:
		_s("KNOWN", 1)
		st.call_fn("aff", ["JH", -30])
		_log("넘긴 일이 알려짐(JH −30)")


## 맵에 들어설 때: 생포 무대엔 따라가지 않는다(A63 — 붙잡히는 틈에 지하로 빠진다)
func _on_map(id: String) -> void:
	squad = {}
	stage_set = {"props": [], "people": []}                              # 옛 맵과 함께 사라졌다(저장하지 않는다 — 분대가 다시 설 때 같이 선다, P10)
	if v("PARK") == 4:
		if _rescue:
			_rescued()                                                    # 무리는 쓰러졌다 — 그는 혼자 지하로(말은 다음에 J-01에서)
		else:
			_sold()
	rec = {}
	if v("PARK") == 1 and id in ["H-03", "CG-05"]:
		_s("END", 3)
		_part()
		_log("생포 — 박춘삼 지하로")


# ---------------------------------------------------------------- 결과
func _close() -> void:
	_s("SOL", 5)                                                          # 상인회가 등을 돌렸다 · 상자를 받을 회장이 없다 — 덮는다(상자는 손에 남는다)
	st.quests.set_stage(Q, 200)
	if v("PARK") == 1:
		_s("END", 7)
		_part()
	_log("덮음")


func _deliver(to_ban: bool) -> void:
	if v("BOX") != 1:
		return
	_s("BOX", 2)
	if stage() >= 100:
		_log("건넴(보상 없음 — 이미 닫힘)")
		return
	var with := v("PARK") == 1 and park_dist() <= NEAR
	var sol := 4 if to_ban else (1 if with else 2)
	_s("SOL", sol)
	_s("DONE", day())
	var aff := (10 if sol == 1 else 8) - (3 if v("SHORT") == 1 else 0)
	st.call_fn("aff", ["JH", aff])
	st.call_fn("xp", [350])
	st.call_fn("caps", [150])                                             # 상인회 봉투(받는 쪽이 건넨다)
	var link := -3 if sol == 1 else -2                                    # 연동(+10 기준) BJ · SB · SV −3 — 소식이 퍼질 때
	var market := not to_ban and _world() and _dist_to(MARKET) <= MARKET_R   # 수산시장(경매장 · 뒤 터)에서 건넸나 — 소문의 출처(P7)
	var day_run := market and daylight()
	var night := 0 if day_run else (1 if market else 2)
	_s("NIGHT", night)                                                    # 0 낮 경매장 = 경매장 사람들이 봤다(공개도 2, 원문) · 1 밤 뒤 터(무리가 온다) · 2 그 밖 — 지하 · 건물 안 · 다른 정류지 · 7병동(조용히, 소문 없음)
	var what := "지하시장 약이 순회 정류지에서 조용히 들것 의료반에 닿았다"
	if to_ban:
		what = "지하시장 약 상자가 여의도 병원 7병동에 닿았다"
	elif night == 0:
		what = "지하시장 구울이 대낮에 경매장 한복판으로 들것 의료반에 약을 날랐다" if with else "대낮에 누가 지하시장 약 상자를 들고 경매장 들것 의료반을 찾아왔다"
	elif night == 1:
		what = "지하시장 약이 밤에 수산시장 뒤 터에서 들것 의료반에 닿았다"
	st.deeds.record(st, "faction", "R01", 2 if day_run else 1, {"BJ": link, "SB": link, "SV": link}, now(),
		{"tag": "FQJH03_DONE", "place": "NJ", "what": what, "seen_by": ["JH"], "about": []})
	st.quests.set_stage(Q, 100)
	if with:
		_s("END", 5)
		if day_run and BUDGET - v("CLOCK") > RIVER_LEFT and v("FLED") != day():
			_s("RIVER", 1)                                                # 남은 시간은 그의 몫 — 경매장 뒤 강가에 앉았다가 해 질 녘 지하로(원고 JH03_PART)
	if night == 1 and int(st.vars.get_v("MEDIC_AT")) == 4 and _dist_to(BACKLOT) <= 12.0:
		_ambush = true                                                    # 밤의 대가 — 약 냄새를 맡은 무리
	_log("배달(%d) · 낮 시계 %d분" % [sol, v("CLOCK")])
	want_save.emit("jh03")


func _sell_box() -> void:
	if v("BOX") != 1:
		return
	_s("BOX", 3)
	st.call_fn("caps", [300])
	st.call_fn("aff", ["JH", -8])
	if stage() < 100:
		_s("SOL", 3)
		st.quests.set_stage(Q, 200)
	if v("PARK") == 1 and park_dist() <= NEAR * 2:
		_s("END", 4)                                                      # 곁에서 봤다 — 그 자리에서 계약 파기(원고가 말하고 part)
	_log("상자 팖")
	want_save.emit("jh03")


## 넘긴다: 모집원 둘이 박춘삼을 앞세워 수산시장 동쪽 집결 지점까지 실제로 걸어간다(PARK 4 — 그 사이 무리를 치면 되찾는다, 닿거나 맵을 떠나면 3으로 굳는다)
func _sell_park() -> void:
	_s("REC", 3)
	_s("END", 6)
	st.call_fn("caps", [REC_PAY])
	st.call_fn("karma", [-100])
	if not _mate().is_empty():
		host.combat.mates.remove(PARK)                                    # 동행에서만 뺀다 — 몸은 무대에 남아 걷는다
		host._sync_mates()
	host.combat.mates.away.erase(PARK)
	_s("PARK", 4)
	_s("NEAR", 0)
	_esc_t = 0.0
	var to := "%d,%d" % [RECPOINT.x, RECPOINT.y]
	if host.ev.actors.has(PARK):
		host.ev.run("go", [PARK, to], func() -> void: pass)
	for e in _alive(rec.get("men", [])):
		e.route = [[Vector2(RECPOINT.x * 32 + 16, RECPOINT.y * 32 + 16), 999.0]]
		e._route_i = 0
		e._route_wait = 0.0
		e.brain.state = AIBrain.S.IDLE
	if not rec.is_empty():
		rec["state"] = "escort"
	_log("박춘삼을 넘김 — 끌려가는 중")
	want_save.emit("jh03")


## 끌려가는 중: 모집원 둘이 다 쓰러지면 되찾는다 · 집결 지점에 닿거나(25초) 무리가 없으면 굳는다(P10)
func _escort_tick(dt: float) -> void:
	if _rescue:
		if not _paused() and not _rescue_shown:
			_rescue_shown = true
			host.play_scene("JH03_RESCUE")                                  # 장면 끝 @cmd jh03 rescued
		return
	if rec.is_empty() or not _world():
		_sold()
		return
	_esc_t += dt
	var men := _alive(rec["men"])
	if men.is_empty():
		rec = {}
		_rescue = true
		return
	var a = host.ev.actors.get(PARK)
	var there: bool = a != null and is_instance_valid(a) and (a as Actor).loco.logical.distance_to(Vector2(RECPOINT.x * 32 + 16, RECPOINT.y * 32 + 16)) < 48.0
	if there or _esc_t > 25.0:
		_leave(men)
		rec = {}
		_sold()


## 넘긴 일이 굳었다: 박춘삼은 새벽인력 쪽으로 사라진다(다음 06시 상가에 알려짐 — 국태윤 출처, 2막 S10 명단 흔적)
func _sold() -> void:
	if v("PARK") != 4:
		return
	rec = {}
	if v("ID") == 1:
		_s("ID", 3)                                                       # 빌려준 주민증도 그를 따라갔다
	if host.ev.actors.has(PARK):
		host.ev.run("hide", [PARK], func() -> void: pass)
	_s("PARK", 3)
	st.deeds.record(st, "side", "R01", 1, {"SB": 0}, now(),
		{"tag": "FQJH03_SOLD", "place": "NJ", "what": "누가 계약 경호 구울을 새벽인력 모집원에게 넘겼다", "seen_by": ["SB"], "about": [PARK]})
	_log("넘김 굳음")
	want_save.emit("jh03")


## 되찾았다(넘긴 뒤 무리를 쳤다): 계약은 그 자리에서 끝 · 그가 상가에 직접 말한다(P7 — −30 대신 −10) · W-129는 닫히지 않는다
func _rescued() -> void:
	_rescue = false
	_rescue_shown = false
	_s("REC", 6)
	_s("END", 8)
	_s("RESCUED", 1)
	st.call_fn("aff", ["JH", -10])
	if v("ID") == 1:
		_s("ID", 2)
		st.call_fn("give", [FAKE_ID, 1])
	if host.ev.actors.has(PARK):
		host.ev.run("hide", [PARK], func() -> void: pass)
	_s("PARK", 2)
	_s("BACK", day() + 1)
	_log("되찾음")
	want_save.emit("jh03")


# ---------------------------------------------------------------- 이동 검문(엄도현 하사의 다리목 분대에서 나온 검문조 — 하사는 고정 초소에)
func _check_on() -> bool:
	return v("BOX") == 1 and stage() < 100 and daylight() and v("CHECK") in [0, 1, 5, 7, 10]


## 분대 눈(낮): 웅크리면 절반
func _sight() -> float:
	return SIGHT * (0.5 if host.combat.crouch else 1.0)


func _check_tick() -> void:
	if squad.is_empty():
		if not _check_on() or _paused() or _dist_to(POST) > SPAWN_R:
			return
		if host.enc_live != null and host.enc_live.chasing():
			return
		_squad_spawn()
		return
	var men := _alive(squad["men"])
	if men.is_empty():
		_squad_done(6 if str(squad["state"]) == "hostile" else v("CHECK"))
		return
	var d := _dist_to(POST)
	var lead: Enemy = squad["lead"] if is_instance_valid(squad["lead"]) and not (squad["lead"] as Enemy).cmb.dead else men[0]
	match str(squad["state"]):
		"post":
			if not _check_on():
				_squad_done(v("CHECK"))
				return
			if v("CHECK") == 0 and d <= SEE_R:
				_s("CHECK", 1)
				_up(30)
				if park_dist() <= NEAR:
					host.hint("박춘삼: \"저기 판독기 들고 섰다. 다리목 분대야. …샛강 쪽으로 돌면 한 청크 더고.\"", 6.0)
				else:
					host.hint("노량진로 한가운데 계엄군 셋 — 판독기를 든 조장이 길을 막고 섰다.", 5.0)
			var sneak: bool = v("CHECK") == 5 or host.combat.crouch
			if not sneak and d <= MEET_R and not _paused():
				_s("SPOT", 0)
				_talk()
			elif d <= _sight() and not _paused():
				squad["state"] = "call"                                   # 눈에 들었다 — 조장이 다가온다(재미 검수: 그냥 걷는 쪽이 몰래 가는 쪽보다 안전하지 않게)
				_s("SPOT", 1 if sneak else 0)                             # 비켜 가다 들켰으면 도망친 판 · 큰길로 걸어왔으면 보통 검문
				host.hint("검문조장: \"거기, 짐꾼! 상자 든 놈! 이리 와!\"" if sneak else "검문조장: \"거기, 상자 든 사람. 판독기 앞으로.\"", 4.0)
				lead.route = [[host.player.loco.logical, 30.0]]
				lead._route_i = 0
				lead._route_wait = 0.0
			elif _tile().x >= POST.x + 8 and absi(_tile().y - POST.y) <= 30 and v("CHECK") in [0, 1, 5, 10]:
				_s("CHECK", 8)                                            # 눈에 안 띄고 분대 동쪽으로 빠져나왔다 — 몰래 해낸 값
				host.hint("검문 분대의 등 뒤로 빠져나왔다. 판독기 바늘 소리가 멀어진다.", 5.0)
				_squad_done(8)
		"call":
			var dl := lead.loco.logical.distance_to(host.player.loco.logical) / 32.0
			if fmod(float(squad.get("t", 0.0)), 2.0) < 0.26:
				lead.route = [[host.player.loco.logical, 30.0]]
				lead._route_i = 0
				lead._route_wait = 0.0
			squad["t"] = float(squad.get("t", 0.0)) + 0.5
			if dl <= 4.0 and not _paused():
				_talk()
			elif dl > 30.0:
				host.hint("조장이 고개를 젓고 돌아선다. 다음엔 얼굴을 기억할 것이다.", 4.0)
				Wanted.add(st, 5, "다리목 검문 회피")
				_s("FLED", day())                                         # 그날은 박춘삼이 강가에 앉지 않고(분대가 얼굴을 봤다) · 엄도현도 안다(재검수: 무시가 최적해가 되지 않게)
				_squad_done(8)
		"talk":
			if not _paused():
				squad["state"] = "post" if v("CHECK") == 7 else "done"
		"turned":
			if d > MEET_R + 2.0:
				squad["state"] = "post"
		"done":
			if d > SPAWN_R or not daylight():
				_squad_done(v("CHECK"))
		"hostile":
			if d >= 35.0:
				Wanted.add(st, 10, "다리목 검문")                       # 살아서 본 자가 있다
				host.hint("분대를 따돌렸다. …얼굴은 봤을 것이다.", 5.0)
				_squad_done(6)


func _talk() -> void:
	squad["state"] = "talk"
	for e in _alive(squad["men"]):
		e.brain.state = AIBrain.S.IDLE
		e.route = []
	_up(30)
	host.play_scene("JH03_CHECK")


func _squad_spawn() -> void:
	var men: Array = []
	var lead: Enemy = null
	var me := host.player.loco.logical
	for k in 3:
		var c := _free_tile(POST + Vector2i(0, [0, -2, 2][k]))
		if c.x < 0:
			continue
		var pos := Vector2(c.x * 32 + 16, c.y * 32 + 16)
		var id := "CR-403" if k == 0 else "CR-401"
		var e := host.combat.spawn(id, pos, host.map, st, {"lv": 7, "team": "calm_jh03", "foes": [], "dir": "W" if me.x < pos.x else "E",
			"sheet": "en_cr403_loco" if k == 0 else "en_cr401_loco"})
		e.set_meta("jh03", 1)
		men.append(e)
		if k == 0:
			lead = e
	if men.is_empty():
		return
	squad = {"men": men, "lead": lead, "state": "post" if v("CHECK") != 7 else "turned"}
	_stage_up()
	_log("이동 검문 섬")


func _squad_hostile() -> void:
	if squad.is_empty():
		return
	_scatter()
	squad["state"] = "hostile"
	for e in _alive(squad["men"]):
		_side(e, "enemy_jh03")
	_s("CHECK", 6)


func _squad_done(why: int) -> void:
	if squad.is_empty():
		return
	if why > 0 and v("CHECK") in [0, 1, 7] and why != 7:
		_s("CHECK", why)
	_leave(_alive(squad["men"]))
	squad = {}
	_log("검문 끝(%d)" % why)


func _pass(n: int, mins: int) -> void:
	if n == 11:
		st.deeds.record(st, "side", "R01", 1, {}, now(), {"tag": "FQJH03_RADIO", "place": "NJ", "what": "다리목 하사가 판독 불능 구울 하나를 무전으로 봐줬다",
			"seen_by": ["BJ"], "about": []})                              # 분대가 보내 준 순간에 남는다(무전만 하고 안 지나가면 없음)
	_s("CHECK", n)
	if mins > 0:
		host.advance_minutes(mins)                                        # 줄 · 서류 시간(낮 지상 — 계약 시계에 그대로 쌓인다)
	if not squad.is_empty():
		squad["state"] = "done"
		for e in _alive(squad["men"]):
			e.brain.state = AIBrain.S.IDLE


## 샛강 둑길로 돈다: 길만 정한다 — 북쪽 큰길(병원 앞)을 따라 실제로 걸어 시장 북쪽으로(재미 검수: 페이드 대신 걷는 길 · 둑 비탈의 옛 의료반 우회로 표식)
func _detour() -> void:
	_s("CHECK", 5)
	if not squad.is_empty():
		squad["state"] = "post"
	host.hint("박춘삼: \"북쪽 큰길로 올라가서 둑을 따라 돌아. 분대 눈에 안 띄게 — 열두 칸 밖으로.\"", 6.0)
	_log("샛강 우회 고름")


## 검문 자리 차림: 접이 차단대 둘 · 판독기 삼각대 · 줄 선 행인 2~3(날마다 수 · 얼굴) — 길은 막지 않는다(차단대는 양 가장자리, 가운데 차로는 열림)
func _stage_up() -> void:
	_stage_clear()
	for pc in [["bj_sawhorse", POST + Vector2i(1, -3)], ["bj_sawhorse", POST + Vector2i(1, 3)], ["bj_reader_tripod", POST + Vector2i(-1, -1)],
			["bj_sawhorse", POST + Vector2i(-19, -3)], ["bj_sawhorse", POST + Vector2i(19, 3)]]:   # 차단대는 길 양 가장자리(깔때기) · 판독기는 조장 앞 줄 쪽 · 19칸 앞 예고 차단대(눈 12칸보다 먼저 화면에 — 재검수)
		var c: Vector2i = pc[1]
		if host.map.is_solid(c) or host.map.is_solid(c + Vector2i(1, 0)):
			continue
		var p: Dictionary = host.map.add_runtime_prop(str(pc[0]), c)
		if not p.is_empty():
			stage_set["props"].append(p)
	var r := RandomNumberGenerator.new()
	r.seed = hash("jh03queue:%d" % day())
	for k in r.randi_range(2, 3):
		var c := _free_tile(POST + Vector2i(-2 - k, -1))                    # 판독기에서 서쪽으로 한 줄(같은 줄 · 한 칸 간격 — 줄로 읽히게)
		if c.x < 0:
			continue
		var a := Actor.new()
		a.setup(str(QUEUE_SHEETS[r.randi() % QUEUE_SHEETS.size()]), Vector2(c.x * 32 + 16, c.y * 32 + 16), host.map)
		a.mode = "walk"
		a.set_meta("wait", true)
		host.map.add_actor(a)
		a.loco.facing = 0                                                 # 판독기(동쪽)를 본다
		a._show()
		stage_set["people"].append(a)
	stage_set["said"] = false


## 줄 꼬리 한 줄(다가오는 사람에게 — 고르기 전에 '판독 불능이면 줄 서도 소용없다'가 들리게)
func _queue_talk() -> void:
	if bool(stage_set.get("said", true)) or (stage_set["people"] as Array).is_empty() or _paused() or _dist_to(POST) > SIGHT + 3.0:
		return
	stage_set["said"] = true
	if v("PARK") == 1 and v("NEAR") == 1:
		host.hint("줄 선 사람: \"구울 양반 데리고 줄 서 봐야 소용없어요. 판독기가 안 읽어.\"", 4.0)
	else:
		host.hint("줄 선 사람: \"줄 길어요. 한 사람씩 판독기에 얼굴 대요.\"", 4.0)


func _stage_empty() -> bool:
	return (stage_set["props"] as Array).is_empty() and (stage_set["people"] as Array).is_empty()


func _stage_clear() -> void:
	if host.map != null:
		for p in stage_set["props"]:
			host.map.remove_runtime_prop(p)
	for a in stage_set["people"]:
		if is_instance_valid(a):
			if host.map != null:
				host.map.remove_actor(a)
			a.queue_free()
	stage_set = {"props": [], "people": []}


## 싸움이 나면 줄 선 사람들은 흩어진다(뒤돌아 흐려진다 — 차단대는 엄폐로 남는다)
func _scatter() -> void:
	var people: Array = stage_set["people"]
	stage_set["people"] = []
	if not people.is_empty():
		host.hint("줄 서 있던 사람들이 흩어진다.", 3.0)
	for a in people:
		if not is_instance_valid(a):
			continue
		a.loco.facing = 4
		var tw: Tween = a.create_tween()
		tw.tween_property(a, "modulate:a", 0.0, 1.5)
		var gone_a: Actor = a
		tw.tween_callback(func() -> void:
			if is_instance_valid(gone_a):
				if host.map != null:
					host.map.remove_actor(gone_a)
				gone_a.queue_free())


## 길 위 바크(계약서 얘기 없이): 그가 곁이고 그 자리 반경 안이면 한 번씩
func _bark_tick() -> void:
	if v("PARK") != 1 or v("NEAR") == 0 or _paused() or st.is_dead(PARK):
		return
	for b in BARKS:
		if v("BARK") & int(b[1]) == 0 and _dist_to(b[0]) <= float(b[2]):
			_s("BARK", v("BARK") | int(b[1]))
			host.hint(str(b[3]), 5.0)
			return


# ---------------------------------------------------------------- 새벽인력 모집원(판독 불능 인력 — 박춘삼만 노린다)
func _rec_tick() -> void:
	if rec.is_empty():
		if v("REC") != 0 or v("PARK") != 1 or v("BOX") != 1 or not daylight() or _paused() or park_dist() > NEAR:
			return
		var dm := _dist_to(MARKET)
		if dm > REC_R or dm < 8.0 or _dist_to(POST) < 15.0 or not squad.is_empty() and str(squad["state"]) in ["talk", "call", "hostile"]:
			return                                                        # 시장 가까이에서 한 번(검문 자리 둘레 · 검문 중엔 아님)
		if host.enc_live != null and host.enc_live.chasing():
			return
		_rec_spawn()
		return
	var men := _alive(rec["men"])
	if men.is_empty():
		if v("REC") in [1, 4, 5]:
			_s("REC", 4)
		rec = {}
		return
	var lead: Enemy = rec["lead"]
	if not is_instance_valid(lead) or lead.cmb.dead:
		return
	if str(rec["state"]) == "escort":
		return                                                            # 끌고 가는 중 — _escort_tick이 본다
	var d := lead.loco.logical.distance_to(host.player.loco.logical) / 32.0
	if str(rec["state"]) == "near":
		for e in men:
			e.route = [[host.player.loco.logical, 30.0]]
			e._route_i = 0
			e._route_wait = 0.0
		if d <= 5.0 and not _paused():
			rec["state"] = "talk"
			for e in men:
				e.brain.state = AIBrain.S.IDLE
				e.route = []
			host.play_scene("JH03_REC")


func _rec_spawn() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("jh03rec:%d" % day())
	var me := host.player.loco.logical
	var f: Vector2 = Locomotion.VEC[host.player.loco.facing].normalized()
	var side := f.rotated(PI / 2.0 if r.randf() < 0.5 else -PI / 2.0)
	var at := me + (f * r.randf_range(10.0, 13.0) + side * r.randf_range(-3.0, 3.0)) * 32.0
	var c := _free_tile(host.map.tile_of(at))
	if c.x < 0:
		return
	var hostile := gv("AFF_SB") <= -60                                    # 본소를 친 뒤: 말없이 쏜다
	var men: Array = []
	for k in 2:
		var cc := _free_tile(c + Vector2i(k, 0))
		var pos := Vector2(cc.x * 32 + 16, cc.y * 32 + 16)
		var id := "CR-435" if k == 0 else "CR-437"
		var o := {"lv": 6, "dir": "W"}
		if not hostile:
			o["team"] = "calm_jh03r"
			o["foes"] = []
			o["sheet"] = "en_cr435_loco" if k == 0 else "en_cr437_loco"
		var e := host.combat.spawn(id, pos, host.map, st, o)
		e.set_meta("jh03", 1)
		if hostile:
			e.brain.gauge = 100.0
			e.brain.state = AIBrain.S.COMBAT
		men.append(e)
	rec = {"men": men, "lead": men[0], "state": "hostile" if hostile else "near"}
	_s("REC", 5 if hostile else 1)
	if hostile:
		host.hint("모집원 조끼를 입은 사내가 말없이 철근총을 든다 — 새벽인력이다!", 5.0)
	else:
		host.hint("새벽인력 조끼를 입은 사내 둘이 이쪽으로 걸어온다. 손에 판독기 대장.", 5.0)
	_log("모집원 %s" % ("적대" if hostile else "다가옴"))


func _rec_end(fight: bool) -> void:
	if rec.is_empty():
		return
	var men := _alive(rec["men"])
	if fight:
		for e in men:
			_side(e, "enemy_jh03r")
		rec["state"] = "hostile"
		_s("REC", 4)
	else:
		_s("REC", 2)
		_leave(men)
		rec = {}


# ---------------------------------------------------------------- 밤 뒤 터
func _night_pack() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("jh03night:%d" % day())
	var pack: Array = NIGHT_PACKS[r.randi() % NIGHT_PACKS.size()]
	var n := r.randi_range(2, 3)
	var dirs := [Vector2(-1, 0), Vector2(0, 1), Vector2(1, 0)]
	var dv: Vector2 = dirs[r.randi() % dirs.size()]
	var me := host.player.loco.logical
	for k in n:
		var c := _free_tile(host.map.tile_of(me + (dv * 11.0 + dv.orthogonal() * (k - 1) * 2.0) * 32.0))
		if c.x < 0:
			continue
		var e := host.combat.spawn(str(pack[k]), Vector2(c.x * 32 + 16, c.y * 32 + 16), host.map, st, {"lv": 5})
		e.brain.gauge = 100.0
	host.hint("뒤 터 어둠 속에서 발소리. 약 냄새를 맡은 것들이 온다.", 5.0)
	_log("밤 뒤 터 무리")


# ---------------------------------------------------------------- 도움
func _side(e: Enemy, team: String) -> void:
	e.cmb.team = team
	e.foes = ["player", "ally"]
	e.brain.state = AIBrain.S.COMBAT
	e.brain.gauge = 100.0
	host.combat._rebuild_list()


func _alive(list: Array) -> Array:
	return list.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)


func _free_tile(c: Vector2i) -> Vector2i:
	for r in range(0, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := c + Vector2i(dx, dy)
				if not host.map.is_solid(t):
					return t
	return Vector2i(-1, -1)


## 떠나는 사람들: 노리지 않고 돌아서서 흐려진다
func _leave(men: Array) -> void:
	for e in men:
		e.cmb.team = "gone"
		e.foes.clear()
		e.brain.state = AIBrain.S.RETURN
		var tw: Tween = e.create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(e, "modulate:a", 0.0, 2.0)
		var gone_e: Enemy = e
		tw.tween_callback(func() -> void:
			if is_instance_valid(gone_e):
				gone_e.visible = false
				host.combat.drop_enemy(gone_e))


# ---------------------------------------------------------------- 원고 명령(@cmd jh03 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"offer":                                                          # 계약서를 봤다(나중에) — 로그 10
			_s("OFFER", 1)
			_up(10)
		"take":                                                           # 계약 성립: 상자 · 동행 · 소윤희 대기(다음 날 18시까지)
			if v("BOX") == 0 and not st.is_dead(PARK):
				_s("BOX", 1)
				st.call_fn("give", [BOX_ID, 1])
				_s("PARK", 1)
				_s("CLOCK", 0)
				_s("LAST", now())
				_s("WAIT", now() - now() % 1440 + 1440 + 1080)
				_join()
				_up(10)
				_up(20)
				want_save.emit("jh03")
				_log("계약 — 출발")
		"alone":                                                          # 박춘삼이 없다 — 노복희가 '혼자 갈 사람'에게
			if v("BOX") == 0:
				_s("BOX", 1)
				_s("ALONE", 1)
				st.call_fn("give", [BOX_ID, 1])
				_s("WAIT", now() - now() % 1440 + 1440 + 1080)
				_up(10)
				_log("혼자 맡음")
		"pass":                                                           # 검문 통과: pass 판(2 주민증 · 3 등록증 · 4 서류 · 9 혼자) 분
			var n := int(a[1]) if a.size() > 1 else 4
			if n == 2:
				_s("ID", 1)
			_pass(n, int(a[2]) if a.size() > 2 else 20)
		"queue":                                                          # 줄만 서고 판독기에서 돌려보내짐(분 — 낮 지상 시계에 쌓인다)
			host.advance_minutes(int(a[1]) if a.size() > 1 else 10)
		"radio":                                                          # 엄도현이 분대에 무전(분대를 만나면 무전 판)
			if v("CHECK") in [0, 1, 5, 7]:
				_s("CHECK", 10)
		"back":
			_s("CHECK", 7)
			if not squad.is_empty():
				squad["state"] = "turned"
		"detour":
			_detour()
		"rescued":
			_rescued()
		"fight":
			_squad_hostile()
			Wanted.add(st, 10, "다리목 검문")
		"rec_no":
			_rec_end(false)
		"rec_fight":
			_rec_end(true)
		"sellpark":
			_sell_park()
		"deliver":
			_deliver(false)
		"deliver_ban":
			_deliver(true)
		"sellbox":
			_sell_box()
		"take_stim":                                                      # 상자에서 스팀팩 하나 — 받는 쪽이 센다
			if v("SHORT") == 0:
				_s("SHORT", 1)
				st.call_fn("give", [InteriorCombat.STIMPAK, 1])
		"band":                                                           # 다친 팔에 붕대(감점 없음)
			var m := _mate()
			if not m.is_empty():
				var cmb: Combatant = m["cmb"]
				cmb.hp = cmb.max_hp
			_s("BAND", 1)
			_s("HURT", 0)
		"idback":                                                         # 빌린 주민증을 돌려준다
			if v("ID") == 1:
				_s("ID", 2)
				st.call_fn("give", [FAKE_ID, 1])
		"part":                                                           # 장면 끝에 그가 떠난다
			if a.size() > 1 and v("END") == 0:
				_s("END", int(a[1]))
			_part()
			host.hint("박춘삼이 계약서를 품에 넣고 돌아선다. 그의 걸음은 지하로 가는 길을 안다.", 5.0)
		"told":
			_s("TOLD", 1)
	done.call()
