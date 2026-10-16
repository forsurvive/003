## 관악(R01) 사이드 퀘스트 SQ-S03 「곰팡이의 근원」 진행기(단계 1-11d, SD-04a §4.3). 원고: script/act1/SQ-S03.txt · SQ-S02.txt SQS02_SUAN(조수안 몫) ·
##   MQ-101.txt X-BC_BOARD(쪽지) · places/R01_R02.txt K-08_TECH(정비공 유해 — 측정지 M-302). 맵: X-BS 배수지 · K-08 계곡 암거 · E-01 S-07 배수 갱도 · X-S07 정문 인터컴.
## 발동: ① MQ-101 끝나고 사흘 뒤 06시 게시판 쪽지 ② SQ-S02 우회 관로(B)가 계곡 배수로를 지나면 그 물에 곰팡이 냄새 ③ 저수조 이음 벽 얼룩을 먼저 봄.
## 단계는 이 진행기 한 곳에서만, 오르기만 한다(SD-20). 퀘스트가 열리기 전에 한 일(조사 지점 · 측정지 · 수문 · 군락 처리)은 사실로 남아 열리는 순간 따라 올린다(P2).
## 고정 지침 '볼트 출구는 정문 방폭문 하나': E-01은 바깥 원형 철문 → 중간 수문 → 볼트 쪽 용접 창살에서 끝난다. 볼트와는 정문 인터컴(방금례)으로만 말한다.
## 재미 검수(SD-23, 계획 때): 단계 20은 볼트 회의 기억으로 · 왕쥐는 맵에 있는 쥐만 부른다 · D 필터는 칠판에 날짜를 세고 30일 뒤 곰팡내만 돌아온다(방사능 0은 그대로) ·
##   C의 꼭지는 14일에 걸쳐 맑아진다(A · B는 바로) · 수문을 먼저 돌려도 손해 없다.
class_name SideS03
extends Node

const BC_CENTER := Vector2i(892, 1362)    ## 봉천(밤 너구리 +30% 범위의 중심)
const BC_R := 60
const COLONY_K08 := Vector2i(19, 1)      ## K-08 천장 군락 소품
const STREAKS_K08 := [Vector2i(23, 1), Vector2i(27, 1), Vector2i(32, 1), Vector2i(39, 1), Vector2i(44, 1), Vector2i(48, 1), Vector2i(52, 1)]   ## 군락에서 갱도 쪽으로 이어지는 줄기(같은 상태)
const GATE_E01 := Vector2i(24, 4)        ## E-01 중간 수문
const PATCH_BS := Vector2i(10, 7)        ## X-BS 이음 벽 얼룩 · 옛 관 입 거름망
const SCREEN_BS := Vector2i(14, 9)
const DRY_DAYS := 14                     ## C: 먹이를 잃은 군락이 마르는 날
const FILTER_DAYS := 30                  ## D: 필터가 곰팡내를 버티는 날
const RACC_DAYS := 7                     ## A: 따뜻한 암거를 잃은 옴 너구리가 봉천으로(밤 RE +30%)
const ARM_DAYS := 3                      ## 발동 ①: MQ-101 끝나고 사흘 뒤

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _king: Enemy                          ## 지금 맵에 선 왕쥐(물러선 체력을 다음 방문에 잇는다)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s03"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.enemy_killed.connect(_on_kill)
	_migrate()


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v(k, n)


func _log(s: String) -> void:
	if log_on:
		print("[곰팡이] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S03")


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S03", n)
		_log("단계 %d" % n)


## 예전 판(1-11d 전)에 정비공 유해를 이미 본 저장: 쪽지만 있고 측정지 물건이 없다 — 같은 사실을 물건으로 맞춘다(P1)
func _migrate() -> void:
	if v("PL_TECH") == 1 and v("SQ_S03_TAGSEEN") == 0:
		_sv("SQ_S03_TAGSEEN", 1)
		if not bool(st.call_fn("has", ["M-302"])):
			st.call_fn("give", ["M-302", 1])


## 퀘스트가 열린다(단계 10) — 그 전에 한 일만큼 따라 올린다(P2: 이미 앎 · 이미 함)
func _start(why: String) -> void:
	if stage() == 0:
		_up(10)
		_log("발동(%s)" % why)
	_catch_up()


func _catch_up() -> void:
	if stage() < 10:
		return
	if v("SQ_S03_WALL") == 1:
		_up(20)                                                          # 볼트 회의 기억: 농장 2동 · 3동 곰팡이병(MQ-P4 S01 — 누구나 들었다)
	if v("SQ_S03_P1") + v("SQ_S03_P2") + v("SQ_S03_P3") >= 2:
		_up(30)
	if v("SQ_S03_IN") == 1:
		_up(40)
	if bool(st.call_fn("has", ["M-302"])):
		_up(50)
		if v("SQ_S03_GATE") >= 1:
			_up(60)
	if v("SQ_S03_SOL") > 0:
		_up(70)


# ---------------------------------------------------------------- 매 0.5초: 우회 관로(SQ-S02 B)가 남긴 표지 · 발동 ① 쪽지
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	if is_instance_valid(_king) and not _king.cmb.dead and v("SQ_S03_KING") == 1:
		_sv("SQ_S03_KING_HP", maxi(1, int(ceil(_king.cmb.hp))))           # 물러서거나 두고 나가도 깎인 체력은 남는다
	if v("SQ_S03_PIPE") == 1 and stage() == 0:                       # SQ-S02 B: 옛 관로가 계곡 배수로를 지난다
		_start("우회 관로")
		host.hint("관에서 내려온 물에 곰팡이 냄새가 섞였다. 배수지 저수조 벽을 봐야겠다.", 6.0)


func _on_day(d: int) -> void:
	_sv("SQ_S03_DRINKS", 0)
	if v("SQ_S03_ARM") == 0 and st.quests.stage("MQ-101") >= 100:
		_sv("SQ_S03_ARM", d)
	if v("SQ_S03_ARM") > 0 and v("SQ_S03_POSTED") == 0 and d >= v("SQ_S03_ARM") + ARM_DAYS and v("SQ_S03_CLEAN") == 0:
		_sv("SQ_S03_POSTED", 1)                                         # 발동 ①: 반상회 게시판 쪽지(조수안 · 없으면 반상회 서명)
		_log("게시판 쪽지")
	if v("SQ_S03_FILTER") == 1:
		_sv("SQ_S03_FILTER_N", maxi(0, d - v("SQ_S03_FILTER_DAY")))
		if v("SQ_S03_CLEAN") == 0 and v("SQ_S03_SMELL") == 0 and v("SQ_S03_FILTER_DAY") > 0 and d >= v("SQ_S03_FILTER_DAY") + FILTER_DAYS:
			_sv("SQ_S03_SMELL", 1)                                      # D: 필터가 한 달을 버텼다 — 곰팡내만 돌아온다(방사능 0은 그대로). 소식은 소문 · 칠판으로(P7)
			_log("필터 곰팡내 돌아옴")
	if v("SQ_S03_SOL") == 3 and v("SQ_S03_DRY_DAY") > 0 and d >= v("SQ_S03_DRY_DAY") + DRY_DAYS and v("SQ_S03_CLEAN") == 0:
		_sv("SQ_S03_CLEAN", 1)                                          # C: 먹이를 잃은 군락이 다 말랐다
		_log("C 군락 마름")
	if host.map != null:
		_looks()


# ---------------------------------------------------------------- 맵에 들어올 때: 소품 상태 · 쥐 무리
func _on_map(_id: String) -> void:
	if host.map == null:
		return
	_looks()
	match host.map.id:
		"K-08":
			_sv("SQ_S03_VISITS", v("SQ_S03_VISITS") + 1)
			_sv("SQ_S03_IN", 1)
			if stage() >= 10:
				_up(40)
			_rats_k08()
		"E-01":
			_rats_e01()


## 소품 상태 한 곳: 군락(살아 있는 · 태운 · 약품 · 마르는) · 저수조 얼룩 · 거름망 · 수문
func _looks() -> void:
	var m := host.map
	if m == null:
		return
	if m.has_method("to_world"):                                         # 심리스 월드: 배수지(X-BS)는 손 맵 끼우기 — 어느 구역에 서 있든 그 자리 소품을 맞춘다
		var clean := v("SQ_S03_CLEAN") == 1
		m.set_prop_state(m.to_world("X-BS", PATCH_BS.x, PATCH_BS.y), "scrubbed" if clean else "")
		m.set_prop_state(m.to_world("X-BS", SCREEN_BS.x, SCREEN_BS.y), "clean" if clean else "")
		return
	match m.id:
		"K-08":
			var s := ""
			match v("SQ_S03_SOL"):
				1:
					s = "burnt"
				2:
					s = "sprayed"
				3:
					var dd := day() - v("SQ_S03_DRY_DAY")
					s = "dry2" if dd >= DRY_DAYS else ("dry1" if dd >= DRY_DAYS / 2 else "")
			m.set_prop_state(COLONY_K08, s)
			for c in STREAKS_K08:
				m.set_prop_state(c, s)
		"E-01":
			m.set_prop_state(GATE_E01, "shut" if v("SQ_S03_GATE") == 2 else "")


## K-08 쥐 무리(SD-04a §4.3 '배수로 암거: 시궁쥐 ×4~6, 왕쥐 ×1 — 이 퀘스트에서는 첫 방문에'): 첫 방문에 시궁쥐 무리. 왕쥐는 퀘스트가 열려 있으면 첫 방문,
## 아니면 세 번째 방문(SD-09a L-R01-08 '3회 방문 뒤'). D 곰팡내가 돌아온 뒤 다시 오면 시궁쥐 둘(왕쥐 없음 — 재미 검수: 다시 열린 일은 짧게)
func _rats_k08() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("k08:%d" % v("SQ_S03_VISITS"))
	if v("SQ_S03_RAT") == 0:
		_sv("SQ_S03_RAT", 1)
		var n := r.randi_range(4, 6)
		for i in n:
			host.combat.spawn("CR-095", host.map.mark_pos("k%d" % (i + 1)), host.map, st, {"lv": r.randi_range(2, 3), "dir": "W"})
		_log("K-08 시궁쥐 %d" % n)
	if v("SQ_S03_KING") == 1:                                              # 물러섰거나 두고 나갔다 — 둥지로 돌아와 있다(쓰러뜨릴 때까지, 깎인 체력 그대로)
		_king = host.combat.spawn("CR-097", host.map.mark_pos("king"), host.map, st, {"lv": 7, "dir": "W"})
		if v("SQ_S03_KING_HP") > 0 and v("SQ_S03_KING_HP") < int(_king.cmb.max_hp):
			_king.cmb.hp = float(v("SQ_S03_KING_HP"))
			host.hint("암거 안쪽에서 낮은 찍찍 — 그 왕쥐다. 흉터가 하나 늘었다.", 5.0)
	elif v("SQ_S03_KING") == 0 and (stage() >= 10 or v("SQ_S03_VISITS") >= 3):
		_sv("SQ_S03_KING", 1)
		_king = host.combat.spawn("CR-097", host.map.mark_pos("king"), host.map, st, {"lv": 7, "dir": "W"})
		host.hint("암거 안쪽 어둠에서 찌이익 — 크고 낮은 울음. 무리가 대답한다.", 5.0)
		_log("왕쥐")
	if v("SQ_S03_SMELL") == 1 and v("SQ_S03_RAT2") == 0:
		_sv("SQ_S03_RAT2", 1)
		for i in 2:
			host.combat.spawn("CR-095", host.map.mark_pos("k%d" % (i + 3)), host.map, st, {"lv": 3, "dir": "W"})


func _on_kill(id: String, _left: int) -> void:
	if id == "CR-097" and v("SQ_S03_KING") == 1:
		_sv("SQ_S03_KING", 2)                                            # 왕쥐를 쓰러뜨렸다 — 다시 서지 않는다(봉천 소문 한 줄)
		_sv("SQ_S03_KING_HP", 0)
		_log("왕쥐 쓰러짐")


## E-01 갱도: 시궁쥐 셋 · 큰바퀴 둘(SD-04a '잔바퀴 떼 CR-001'은 자료가 없어 큰바퀴 CR-002로 — 구현 정합)
func _rats_e01() -> void:
	if v("SQ_S03_ERAT") == 1:
		return
	_sv("SQ_S03_ERAT", 1)
	for k in ["r1", "r2", "r3"]:
		host.combat.spawn("CR-095", host.map.mark_pos(k), host.map, st, {"lv": 2, "dir": "W"})
	for k in ["x1", "x2"]:
		host.combat.spawn("CR-002", host.map.mark_pos(k), host.map, st, {"lv": 1, "dir": "W"})


# ---------------------------------------------------------------- 원고 명령(@cmd s03 …)
func _cmd(a: Array, done: Callable) -> void:
	var what := str(a[0]) if a.size() > 0 else ""
	match what:
		"note":                                                           # 발동 ①: 반상회 게시판 쪽지를 읽음
			_start("게시판 쪽지")
		"wall":                                                           # 저수조 이음 벽 얼룩 — 볼트 회의 기억(단계 20)
			_sv("SQ_S03_WALL", 1)
			_start("저수조 벽")
		"point":
			var n := int(a[1]) if a.size() > 1 else 1
			_sv("SQ_S03_P%d" % n, 1)
			_catch_up()
		"spray":
			_sv("SQ_S03_SPRAY", 1)
		"sheet":                                                          # 정비공 측정지(M-302)
			_catch_up()
		"name":
			_sv("SQ_S03_NAME", 1)
		"gate":
			_sv("SQ_S03_GATE", maxi(1, v("SQ_S03_GATE")))
			_catch_up()
		"shut":
			_sv("SQ_S03_GATE", 2)
			_looks()
			if v("SQ_S03_VAULT") == 2:
				_solve_c()
		"vault":
			_sv("SQ_S03_VAULT", 2)
			if v("SQ_S03_GATE") == 2:
				_solve_c()
			else:
				host.hint("볼트가 물길을 돌려도 갱도 중간 수문은 아직 열려 있다.", 5.0)
		"call":
			_sv("SQ_S03_CALLS", v("SQ_S03_CALLS") + 1)
		"tag":                                                            # 정영수의 볼트 기록(1 바깥에서 기다림 · 2 보고하다 사망 · 3 그대로)
			var t := int(a[1]) if a.size() > 1 else 3
			_sv("SQ_S03_TAG", t)
			if t in [1, 2]:
				st.call_fn("karma", [25])
		"burn":
			_solve_ab(1)
		"sprayed":
			_solve_ab(2)
		"filter":
			_sv("SQ_S03_FILTER", 1)
			_sv("SQ_S03_FILTER_DAY", day())
			_sv("SQ_S03_FILTER_N", 0)
			st.call_fn("aff", ["BC", 3])
			_log("D 필터")
		"drink":
			_drink()
		"report":
			_report()
	done.call()


## A 소각 · B 약품: 바로 맑아진다. 퀘스트 전이면 사실로 남고 열리는 순간 70으로(P2)
func _solve_ab(sol: int) -> void:
	if v("SQ_S03_SOL") == 0:
		_sv("SQ_S03_SOL", sol)
	_sv("SQ_S03_CLEAN", 1)
	if sol == 1:
		_sv("SQ_S03_RACC_UNTIL", day() + RACC_DAYS)
	else:
		st.call_fn("karma", [25])
	_looks()
	_start("군락 처리")
	_up(70)
	_deed("SQS03_" + ("A" if sol == 1 else "B"), {"JC_BC": 0}, "관악 계곡 배수로 천장의 곰팡이 군락이 %s" % ("불에 탔다" if sol == 1 else "약품에 바랬다"))


## C 원인 차단: 수문이 닫혔고 볼트가 물길을 돌렸다(순서는 아무래도 좋다). A · B 뒤여도 C로 덮어쓴다(카르마는 C 몫만)
func _solve_c() -> void:
	if v("SQ_S03_SOL") == 3:
		return
	_sv("SQ_S03_SOL", 3)
	# 이미 태우거나 약을 친 군락이면 먹이까지 끊긴 셈 — 바로 다 마른 모습(태운 군락이 살아나 보이지 않게)
	_sv("SQ_S03_DRY_DAY", day() - DRY_DAYS if v("SQ_S03_CLEAN") == 1 else day())
	st.call_fn("karma", [100])
	_sv("SQR_S03", 3)                                                   # 4막 볼트 반응(MQ-401 · SQ-S07 — 농장 2 · 3동 회복, 이월)
	_looks()
	_start("원인 차단")
	_up(70)
	host.hint("갱도 아래로 흐르던 물이 멎었다. 군락은 먹이를 잃고 두 주에 걸쳐 마른다.", 6.0)
	_deed("SQS03_C", {"JC_BC": 0}, "볼트 S-07이 농장 배수를 정화조로 돌렸다는 말이 봉천까지 내려왔다")


## 보고(조수안 — 없으면 칠판 · 반상회 궤짝): 100 · XP 300 · 사례 100캡 · 꼭지 필터(방사능 0, 상시) · 봉천 호감(A · B +6, C +8)
func _report() -> void:
	if stage() >= 100:
		return
	_up(100)
	st.call_fn("xp", [300])
	st.call_fn("caps", [100])                                           # 조수안이 없으면 칠판 아래 반상회 궤짝(재미 검수: 보상은 사람이 아니라 마을 몫)
	if v("SQ_S03_FILTER") == 0:
		_sv("SQ_S03_FILTER", 1)
		_sv("SQ_S03_FILTER_DAY", 0)                                       # 보상 필터는 군락이 처리된 뒤라 곰팡내 시계가 없다
	st.call_fn("aff", ["BC", 8 if v("SQ_S03_SOL") == 3 else 6])
	_sv("SQ_S03_REWARD", 1)
	_log("보고(해법 %d)" % v("SQ_S03_SOL"))


## 꼭지에서 한 모금(재미 검수 F1 · F10): 곰팡이가 있으면 '물에 냄새가 난다.'(2214년 쪽지와 같은 글) · 회복이 적다. 필터면 방사능 0.
## C는 14일에 걸쳐 냄새가 빠진다. D 필터는 30일 동안 냄새를 잡고 그 뒤 곰팡내만 돌아온다. 마셔 봐야 안다(MQ-101 '물').
func _drink() -> void:
	_sv("SQ_S03_DRINKS", v("SQ_S03_DRINKS") + 1)
	_sv("MQ101_WATER", 1)
	var smell := 1.0
	if v("SQ_S03_CLEAN") == 1:
		smell = 0.0
	elif v("SQ_S03_SOL") == 3 and v("SQ_S03_DRY_DAY") > 0:
		smell = clampf(1.0 - float(day() - v("SQ_S03_DRY_DAY")) / float(DRY_DAYS), 0.0, 1.0)
	elif v("SQ_S03_FILTER") == 1 and v("SQ_S03_SMELL") == 0:
		smell = 0.0
	var filt := v("SQ_S03_FILTER") == 1
	var heal := lerpf(15.0, 5.0, smell)
	var rad := 0 if filt else 2
	var c := host.combat.pc
	c.hp = minf(c.max_hp, c.hp + heal)
	if rad > 0:
		st.vars.set_v("PC_RADS", v("PC_RADS") + rad)
	var line := "물이 맑다. 산 냄새가 조금 난다." if smell <= 0.0 else ("물에 냄새가 난다." if smell >= 0.7 else "물에 냄새가 조금 남았다.")
	if filt and smell <= 0.0:
		line = "필터를 지난 물. 아무 맛도 안 난다."
	host.hint("%s  HP +%d%s" % [line, int(heal), ("  방사능 +%d" % rad) if rad > 0 else "  방사능 없음"], 4.0)
	if smell >= 0.7 and stage() == 0 and v("SQ_S03_WALL") == 0:
		host.hint("물에 냄새가 난다. …저수조 쪽에서 나는 냄새다.", 4.0)


func _deed(tag: String, fx: Dictionary, what: String) -> void:
	st.deeds.record(st, "side", "R01", 1, fx, Clock.abs_min(host.date_text), {"tag": tag, "place": "BC", "what": what, "seen_by": ["JC_BC"], "about": []})
