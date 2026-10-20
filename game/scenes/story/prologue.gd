## 프롤로그 진행(단계 0-6~): MQ-P1 출생신고 → MQ-P2 열 살, 첫 배정을 처음부터 끝까지 이어 논다.
##   MQ-P1: S1 의무실 컷신(주인공 = 침대의 갓난아기) + 출생신고서 → '2259' → S2 돌잔치 걸음마 → S3 돌잡이 → '2268'
##   MQ-P2: S1 교실 생활기록부 → S2 식당 생일잔치(핍-보이·HUD) → S3 행정실 첫 배정 → S4 배급소 지우(선택, 카르마 5갈래)
##          → S5 사격장(BB총: 표적 10 → 은신 표적 2) → S6 배관실(하도윤 동행, 증기 분출·스팀팩, 큰바퀴 6) → '2274'
##   MQ-P3: S1 사물함 복도 소동(카르마 6갈래, V_DY_P3) → S2 적성 평가 교실(시험·건너뛰기·대리 작성, 10번 문항) → S3 평가관실
##          결과 통지서·태그 확정(등록 카드 단계 1) → S4 같은 날 오버시어실(주인공 없음, V-02) → '2277'
##   MQ-P4: S1 식당 주민 회의 → S2 정문 개방식(방폭문이 굴러 열리고 계엄군·파워 아머가 들어온다) → S3 A-07 거래(하도윤의 전언 또는
##          [은신] 덕트 엿듣기 V-02 컷) → 관리동 호출 = 탈출 시작(0-9c)
##   사격장 단계 넘김·바퀴 전멸 장면은 여기서 연다(전투 신호). 주인공이 쓰러지면(프롤로그 특례, 정합): 하도윤이 끌어내
##   배관실 입구에서 HP 가득으로 깨어난다(바퀴는 그대로).
## 실행: godot --path game res://scenes/story/prologue.tscn [-- --auto --pick=N --jiwoo=N --dy=N --exam=test|skip|proxy --q10=N
##        --from=p2|range|pipe|p3|p4|p4e --duct=1 --esc=1~4 --shots=디렉터리 --log]
##   --auto: 대사를 넘기고 서류를 내고 길을 찾아 걸어가며(맵을 넘어) 사격·은신·근접·스팀팩까지 하는 봇.
##   --pick: 돌잡이 1~6(기본 2 청진기) · --jiwoo: 지우 장면 선택 1~6(기본 3 [인지력 5] 카드 찾기) · --from=p2: MQ-P2부터
##   --dy: 복도 소동 1 잉크 · 2 출입 기록 · 3 설득 · 4 막아섬 · 5 고발 · 6 지나침(기본 1) · --exam: 응시 방법(기본 test) · --q10: 10번 답
extends Node

var host: InteriorHost
var phase := "P1S1"
var auto := false
var pick := 2
var jiwoo := 3
var dy := 1
var exam := "test"
var q10 := 1
var shots := ""
var shot_n := 0
var hold := 0.0
var path := PackedVector2Array()
var path_goal := Vector2.INF
var t := 0.0
var talked := false
var stealth_started := false
var _re_t := 0.0
var _pip_t := 0.0
var duct := 0                                   ## --duct=1: 거래 장면에서 [은신 25] 덕트로 직접 엿듣는다(봇)
var esc := 4                                    ## --esc: 탈출 1 전투 · 2 은신 · 3 설득 · 4 하도윤(봇, 기본 4)
var log_on := false                             ## --log: 5초마다 진행 상태 한 줄(봇·녹화 점검)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0B0A0D"))
	var from := ""
	for a in OS.get_cmdline_user_args():
		if a == "--auto":
			auto = true
		elif a.begins_with("--pick="):
			pick = clampi(int(a.substr(7)), 1, 6)
		elif a.begins_with("--jiwoo="):
			jiwoo = clampi(int(a.substr(8)), 1, 6)
		elif a.begins_with("--from="):
			from = a.substr(7)
		elif a.begins_with("--dy="):
			dy = clampi(int(a.substr(5)), 1, 6)
		elif a.begins_with("--exam="):
			exam = a.substr(7)
		elif a.begins_with("--q10="):
			q10 = clampi(int(a.substr(6)), 1, 4)
		elif a.begins_with("--duct="):
			duct = int(a.substr(7))
		elif a.begins_with("--sol="):
			sol = clampi(int(a.substr(6)), 1, 5)
		elif a.begins_with("--esc="):
			esc = clampi(int(a.substr(6)), 1, 4)
		elif a == "--chain":                                    # 개발용(0-12): 탈출 봇이 끝나면 그대로 1막 봇(--sol)으로 이어 간다
			chain = true
		elif a == "--touch":
			touch_on = true
		elif a == "--menushot":
			menushot = 0.0
		elif a.begins_with("--load="):                          # 개발용: 저장 파일 하나를 바로 불러온다(system · quick · auto_0 · manual_03 …)
			SaveSlots.pending = SaveSlots.dir + a.substr(7) + ".sav"
		elif a == "--savetest":
			savetest = true
		elif a == "--log":
			log_on = true
		elif a.begins_with("--shots="):
			shots = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shots)
	host = InteriorHost.new()
	add_child(host)
	host.use_keyboard = not auto
	if OS.has_feature("mobile"):
		auto_every = 300.0
	touch = TouchHud.new().setup(host, open_pause)
	add_child(touch)
	host.map_entered.connect(func(_id: String) -> void:
		if not host.zone_walk:
			request_auto("door"))
	host.slept.connect(func(_h: int) -> void: request_auto("sleep"))             # 침대에서 잔 뒤(SD-12 §13.2 '수면 뒤')
	host.traveled.connect(func(_lid: String) -> void: request_auto("travel"))   # 빠른 이동 도착(SD-12 §5.6 '도착 시 자동 저장')
	host.box.finished.connect(_on_dialogue_done)
	host.combat.target_down.connect(_on_target_down)
	host.combat.enemy_killed.connect(_on_enemy_killed)
	host.combat.player_down.connect(_on_player_down)
	host.pc_died.connect(_on_pc_died)
	host.child_entered_tree.connect(_on_child)
	if SaveSlots.pending != "":                                # 제목 화면·불러오기에서 왔다
		var path := SaveSlots.pending
		SaveSlots.pending = ""
		_load_game.call_deferred(path)
		return
	if from == "p2":
		_quick_p1()
		_start_p2.call_deferred()
		return
	if from == "p3":                                           # 개발용: 적성 평가부터(MQ-P2를 끝낸 상태)
		_quick_p1()
		host.st.quests.set_stage("MQ-P2", 100)
		for c in ["PE", "EN", "IN", "AG", "LK"]:                # 생활기록부 봇과 같은 배분(인지력 6 → 잉크 갈래가 열린다)
			host.st.vars.set_v("PC_" + c, 6)
		host.st.call_fn("give", ["W-065"])
		host.st.call_fn("give", ["W-067"])
		host.pipboy_ok = true
		_start_p3.call_deferred()
		return
	if from in ["p4", "p4e", "view", "box", "gate"]:                                  # 개발용: 개방의 날부터(MQ-P3까지 끝낸 상태) · p4e: 호출 직후(탈출)부터
		_quick_p1()
		host.st.quests.set_stage("MQ-P2", 100)
		host.st.quests.set_stage("MQ-P3", 100)
		for c in ["PE", "EN", "IN", "AG", "LK"]:
			host.st.vars.set_v("PC_" + c, 6)
		host.st.vars.set_v("V_DY_P3", 1)
		host.st.vars.set_v("V_REGCARD", 1)
		for i in 3:
			host.st.vars.set_v("PC_TAG%d" % (i + 1), ["SNEAK", "LOCKPICK", "SMALL_GUNS"][i])
		host.st.call_fn("give", ["W-065"])
		host.st.call_fn("give", ["W-067"])
		host.pipboy_ok = true
		if from == "view":
			host.st.vars.set_v("V_DOYUN", 1)                          # 탈출을 건너뛰어도 하도윤은 붙잡힌 상태(SD-03a §7.4)
			_start_view.call_deferred()
		elif from == "box":
			_start_box.call_deferred()
		elif from == "gate":
			_start_gate.call_deferred()
		elif from == "p4e":
			_start_p4e.call_deferred()
		else:
			_start_p4.call_deferred()
		return
	if from.begins_with("x"):                                   # 개발용(0-10): 1막 바깥 맵부터 — x 비탈 · xbc 봉천 · xwalk/xroof 걷기 봇
		_quick_p1()
		for q in ["MQ-P2", "MQ-P3", "MQ-P4"]:
			host.st.quests.set_stage(q, 100)
		for c in ["PE", "EN", "IN", "AG", "LK"]:
			host.st.vars.set_v("PC_" + c, 6)
		host.st.vars.set_v("V_ACT", 1)
		host.st.vars.set_v("V_ESCAPE", 2)
		host.st.call_fn("give", ["W-002"])
		host.st.call_fn("give", ["10mm 탄", 36])                   # MQ-P4 보안부 권총 보상과 같은 몫
		host.st.call_fn("give", ["W-067"])
		_act1.call_deferred(from)
		return
	if from in ["range", "pipe"]:                              # 개발용: 사격장·배관실부터
		_quick_p1()
		phase = "P2"
		host.body = "kid"
		host.pipboy_ok = true
		host.hud_on = true
		host.date_text = "2268. 03. 02.  15:20"
		host.st.quests.set_stage("MQ-P2", 40 if from == "range" else 60)
		if from == "pipe":
			host.st.call_fn("give", ["W-065"])
			host.st.call_fn("give", ["BB탄", 150])
			stealth_started = true
		host.enter("V-09" if from == "range" else "V-10", "from_V-01" if from == "range" else "from_V-04")
		return
	host.body = "hidden"                                       # 주인공은 윤정인 품의 갓난아기(침대 그림 안)
	host.enter("V-08", "door")
	host.banner_t = 0.0
	host.play_scene.call_deferred("MQ-P1_S01")


## 1막 MQ-101 진행기로 넘긴다(0-10)
var act1: Mq101
var paths: Act1Paths                               ## 1막 경로 진행기(MQ-102 허브 · MQ-103 지하시장, 1-4)
var mq106: Mq106                                   ## MQ-106 첫 번째 추적자 · 1 → 2막 전환(1-7)
var home: HomeBc                                   ## 봉천 옥탑방 거처(1-8b)
var side_r01: SideR01                              ## 관악 사이드 퀘스트(1-11 — SQ-S01 외눈의 인식표)
var side_s02: SideS02                              ## 관악 사이드 퀘스트(1-11b — SQ-S02 물 반 컵의 값)
var side_s03: SideS03                              ## 관악 사이드 퀘스트(1-11d — SQ-S03 곰팡이의 근원)
var side_s04: SideS04                              ## 관악 사이드 퀘스트(1-11c — SQ-S04 도성이 뒤척인다)
var side_s05: SideS05                              ## 관악 사이드 퀘스트(1-11e — SQ-S05 환승촌 막차)
var side_s06: SideS06                              ## 관악 사이드 퀘스트(1-11f — SQ-S06 근무자: 공란)
var side_s08: SideS08                              ## 영등포 사이드 퀘스트(1-11g — SQ-S08 같은 명찰의 두 사람)
var side_s09: SideS09                                   ## 영등포 사이드 퀘스트(1-11h — SQ-S09 127번)
var side_s10: SideS10                                   ## 영등포 사이드 퀘스트(1-11i — SQ-S10 오늘의 4번 인력)
var side_s12: SideS12                                   ## 지하시장 사이드 퀘스트(1-11k — SQ-S12 관리 요원의 유족)
var side_s13: SideS13                                   ## 볼트 S-02 사이드 퀘스트(1-11l — SQ-S13 제752차 개표)
var fq_jc01: FqJc01                                     ## 세력 퀘스트 FQ-JC-01 계단 물길(1-12a — 봉천 빗물 수로 · 7동 물당번 흙막이)
var side_s11: SideS11                                   ## 여의도 사이드 퀘스트(1-11j — SQ-S11 토요일의 여의도)
var uq71: Uq71                                          ## 비표시 퀘스트 UQ-71 원자력 버스(1-D1 — 대방 지하차도)
var u02: U02Paths                                       ## U02 남태령 지하(1-D2 — 터널 회로 UG-H01 · 밀통로 UG-H02 · 지하 초소)
var uq04: Uq04                                          ## UQ-04 7호 냉동 창고(1-D3 — 독산 육가공 단지 DG-DS)
var gr: Gr                                              ## 구로 차량기지 던전 DG-GR(1-D4 — 입환 · 출발 진행)
var kt: Kt                                              ## 여의도 금탑 던전 DG-KT(1-D5a — 로비 · 지하 수족관)
var ks: Ks                                              ## 구로 공단 지식산업센터 · 문래 DG-KS(1-D7 — 라인 박자 · 출근 카드 · 11월 서류 · 금형)
var ga: Ga                                              ## 가산 아울렛 거리 DG-GA(1-D6 — 눈 속이기 · 작업복 상자 · 진열창)
var hp: Hp                                              ## 여의도 대학병원 DG-HP(1-D8 — 병원 시계 · 차임 대형 · 면회 · 약길)
var yt: Yt                                              ## 여의도 유리탑 3동 DG-YT · 증권가 객장 UQ-06(1-D9 — 사원증 판독 · 로봇 대조 · 테이프)
var u04: U04                                            ## 여의도 지하 U04(1-D10 — 레일 수레 · 귀 대기 · 두드림 · 운송 · UG-H03)
var stash: Stash                                        ## 보관 자리 · 털림 · UQ-125 털린 은닉처(1-L)
var caravans: Caravans                             ## 순회 상인 일정(1-8d)
var sol := 1                                       ## 1막 봇 해법(--sol=1~5, 0-10)

# ---------------------------------------------------------------- 저장·일시 정지·터치(0-11, SD-12 §13·§17)
var play_time := 0.0                                ## 플레이 시간(일시 정지·메뉴 중에는 멈춘다)
var pause_menu: PauseMenu
var touch: TouchHud
var thumb := PackedByteArray()                      ## 일시 정지를 연 순간의 화면(160×90) — 저장 칸 축소 그림
var last_auto := -1e9                               ## 마지막 자동 저장(플레이 시간 기준)
var auto_due := ""                                  ## 미뤄 둔 자동 저장 까닭(문·수면·간격 …)
var auto_every := 600.0                             ## 자동 저장 간격(PC 10분 · 모바일 5분, §13.2·§17.6)
var stable := {}                                    ## 마지막으로 저장할 수 있던 순간의 한 장(중단 저장용)
var stable_slot := {}
var _stable_t := 0.0
var _night_seen := 0
var chain := false                                 ## --chain: 탈출 → 첫 풍경 → 1막까지 한 번에(분기 봇 4 × 5)
var touch_on := false                              ## --touch: 터치 단추를 켜고 1막 봇이 합성 터치로만 논다(0-11)
var menushot := -1.0                               ## --menushot: 일시 정지 메뉴 쪽마다 화면을 찍는다(--shots 폴더)
var savetest := false                               ## --savetest: 1막 15초 뒤 수동 저장 → 장면을 다시 열어 불러오기 → 한 장이 같은지
var _saved_test := false
const NO_SAVE_PHASES := ["P1S1", "P3S4", "P4S2", "P4S3", "P4S3B", "P4S5", "P4OUT", "P4S6", "P4S7", "end"]


func _paths() -> void:
	if paths == null:
		paths = Act1Paths.new()
		add_child(paths)
		paths.setup(host, log_on)
	if mq106 == null:                                              # MQ-106 첫 번째 추적자 · 막 전환(1-7)
		mq106 = Mq106.new()
		add_child(mq106)
		mq106.setup(host, log_on)
		mq106.act_up.connect(func(_n: int) -> void: request_auto("act"))
	if caravans == null:                                           # 순회 상인(1-8d, SD-15 §4.3)
		caravans = Caravans.new()
		add_child(caravans)
		caravans.setup(host)
	if home == null:                                               # 거처(1-8b, SD-15 §7)
		home = HomeBc.new()
		add_child(home)
		home.setup(host, log_on)
	if side_r01 == null:                                           # 관악 사이드 퀘스트(1-11, SD-04a §4)
		side_r01 = SideR01.new()
		add_child(side_r01)
		side_r01.setup(host, log_on)
	if side_s02 == null:
		side_s02 = SideS02.new()
		add_child(side_s02)
		side_s02.setup(host, log_on)
	if side_s03 == null:
		side_s03 = SideS03.new()
		add_child(side_s03)
		side_s03.setup(host, log_on)
	if side_s04 == null:
		side_s04 = SideS04.new()
		add_child(side_s04)
		side_s04.setup(host, log_on)
	if side_s05 == null:
		side_s05 = SideS05.new()
		add_child(side_s05)
		side_s05.setup(host, log_on)
	if side_s06 == null:
		side_s06 = SideS06.new()
		add_child(side_s06)
		side_s06.setup(host, log_on)
	if side_s08 == null:
		side_s08 = SideS08.new()
		add_child(side_s08)
		side_s08.setup(host, log_on)
	if side_s09 == null:
		side_s09 = SideS09.new()
		add_child(side_s09)
		side_s09.setup(host, log_on)
	if side_s10 == null:
		side_s10 = SideS10.new()
		add_child(side_s10)
		side_s10.setup(host, log_on)
	if side_s11 == null:
		side_s11 = SideS11.new()
		add_child(side_s11)
		side_s11.setup(host, log_on)
	if side_s12 == null:
		side_s12 = SideS12.new()
		add_child(side_s12)
		side_s12.setup(host, log_on)
		side_s12.want_save.connect(func(_w: String) -> void: request_auto("event"))   # 신분증의 자리가 정해짐(1-11k)
	if side_s13 == null:
		side_s13 = SideS13.new()
		add_child(side_s13)
		side_s13.setup(host, log_on)
		side_s13.want_save.connect(func(_w: String) -> void: request_auto("event"))   # 무산 · 개표 · 끝(1-11l)
	if fq_jc01 == null:
		fq_jc01 = FqJc01.new()
		add_child(fq_jc01)
		fq_jc01.setup(host, log_on)
		fq_jc01.want_save.connect(func(_w: String) -> void: request_auto("event"))   # 물길을 정함 · 끝(1-12a)
	if uq71 == null:
		uq71 = Uq71.new()
		add_child(uq71)
		uq71.setup(host, log_on)
	if u02 == null:
		u02 = U02Paths.new()
		add_child(u02)
		u02.setup(host, log_on)
	if uq04 == null:
		uq04 = Uq04.new()
		add_child(uq04)
		uq04.setup(host, log_on)
	if gr == null:
		gr = Gr.new()
		add_child(gr)
		gr.setup(host, log_on)
	if kt == null:
		kt = Kt.new()
		add_child(kt)
		kt.setup(host, log_on)
	if ga == null:
		ga = Ga.new()
		add_child(ga)
		ga.setup(host, log_on)
	if hp == null:
		hp = Hp.new()
		add_child(hp)
		hp.setup(host, log_on)
	if ks == null:
		ks = Ks.new()
		add_child(ks)
		ks.setup(host, log_on)
		ks.want_save.connect(func(_w: String) -> void: request_auto("shelter"))   # 품질 관리실 쉼터(1-D7 확정안 F11)
	if yt == null:
		yt = Yt.new()
		add_child(yt)
		yt.setup(host, log_on)
		yt.want_save.connect(func(_w: String) -> void: request_auto("event"))   # 마감 종(1-D9 UQ-06)
	if u04 == null:
		u04 = U04.new()
		add_child(u04)
		u04.setup(host, log_on)
		u04.want_save.connect(func(_w: String) -> void: request_auto("event"))   # 운송 한 번 · 대기 줄 빈자리(1-D10)
	if stash == null:
		stash = Stash.new()
		add_child(stash)
		stash.setup(host, log_on)


func _act1(from: String) -> void:
	phase = "ACT1"
	act1 = Mq101.new()
	add_child(act1)
	act1.setup(host, auto, log_on, sol, shots)
	_paths()
	if touch_on:
		touch.on = true
		act1.touch = touch
		act1.touch_bot = auto
	if from == "xbc":
		act1.start("X-BC", "from_X-S07")
	elif from == "xnight":
		act1.start_night()
	else:
		act1.start("X-S07", "start")
	if from == "xwalk":
		act1.walk([["X-S07", 30, 25], ["X-S07", 30, 21], ["X-S07", 33, 14], ["X-S07", 30, 24], ["X-S07", 13, 19], ["X-S07", 12, 15],
			["X-S07", 14, 0], ["X-BC", 50, 43], ["X-BC", 29, 37], ["X-BC", 29, 27], ["X-BC", 33, 22], ["X-BC", 30, 20],
			["X-BC", 30, 14], ["X-BC", 34, 12], ["X-BC", 32, 9], ["X-BC", 27, 8], ["B-01", 8, 11]])
	elif from == "xroof":
		host.enter("X-BC", "from_B-01")
		act1.walk([["X-BC", 6, 14], ["X-BC", 5, 16], ["X-BC", 5, 20], ["X-BC", 5, 23], ["X-BC", 5, 27], ["X-BC", 5, 30],
			["X-BC", 5, 35]])


## --from=p2: MQ-P1을 건너뛴 상태(이름·외형·돌잡이)를 만든다
func _quick_p1() -> void:
	var st := host.st
	CharDocs.write_name(st, "윤", "서진")
	st.vars.set_v("P_REGNO", CharDocs.REGNO)
	st.vars.set_v("V_DOL", pick)
	st.quests.set_stage("MQ-P1", 100)


func _on_child(n: Node) -> void:
	if not auto:
		return
	if n is RegisterTerminal:
		get_tree().create_timer(1.5).timeout.connect(func() -> void: n._press("ok"))
	elif n is RecordBook:                                      # 봇: 인지력·지구력·지능·민첩성·행운 +1 → 확정
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			for c in ["PE", "EN", "IN", "AG", "LK"]:
				n._adjust(c, 1)
			get_tree().create_timer(1.5).timeout.connect(func() -> void: n._press("ok")))
	elif n is PipBoy:                                          # 봇: 탭을 한 바퀴 둘러보고 닫는다
		_pip_t = 0.0
	elif n is AptitudeCard:                                    # 봇: 정해 둔 답을 차례로 칠하고 제출
		for i in APT.size():
			get_tree().create_timer(1.2 + i * 0.7).timeout.connect(func() -> void: n._press("opt%d" % (APT[i] - 1)))
		get_tree().create_timer(1.2 + APT.size() * 0.7 + 0.8).timeout.connect(func() -> void: n._press("submit"))
	elif n is ResultSheet:                                     # 봇: 추천 그대로(건너뛰었으면 화술·수리·소형 화기) 확정
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			for k in ["SPEECH", "REPAIR", "SMALL_GUNS"]:
				if n.picks.size() < 3 and not k in n.picks:
					n._press(k)
			get_tree().create_timer(1.5).timeout.connect(func() -> void: n._press("ok")))


func _on_dialogue_done() -> void:
	var st := host.st
	var p1 := st.quests.stage("MQ-P1")
	var p2 := st.quests.stage("MQ-P2")
	if phase == "P1S1" and p1 >= 20:
		phase = "P1S2"
		_shot("s1_end")
		host.busy = true
		host.body = "toddler"
		host.enter("V-01", "dol_start")
		host.ev.run("fade_in", ["white", "8"], func() -> void:
			host.busy = false
			host.hint("방향키·WASD: 아장아장 걷기 (아직 뛸 수 없다)", 6.0)
			host.hint("E·Enter: 조사하기 · 말 걸기", 6.0))
	elif phase == "P1S2" and p1 >= 100:
		print("MQ-P1 완료: %s · V_DOL=%d · 단계 %d" % [st.vars.get_v("P_FULL"), st.vars.get_v("V_DOL"), p1])
		_shot("p1_end")
		_start_p2()
	elif phase == "P2" and p2 >= 100:
		print("MQ-P2 완료: 카르마 %d · 지우 %d · XP %d · 표적 %d(기습 %d) · 바퀴 %d · 스팀팩 %d · 받은 피해 %d" % [
			int(st.vars.get_v("V_KARMA")), int(st.vars.get_v("MQP2_RESULT")), int(st.vars.get_v("PC_XP")),
			host.combat.stats["hits"], host.combat.stats["sneak"], host.combat.stats["downs"], host.combat.stats["stims"],
			int(host.combat.stats["hurt"])])
		_shot("p2_end")
		_start_p3()
	elif phase == "P3" and st.quests.stage("MQ-P3") >= 100:
		phase = "P3S4"                                         # 같은 날 오버시어실: 주인공은 보지 못한다(V-02, 주인공 숨김)
		_shot("p3_result")
		host.busy = true
		host.ev.run("fade_out", ["black", "6"], func() -> void:
			host.body = "hidden"
			host.hud_on = false
			host.date_text = "2274. 09. 02.  15:10"
			host.enter("V-02", "p3_ovs")
			host.banner_t = 0.0
			host.busy = false
			host.play_scene("MQ-P3_S04"))
	elif phase == "P3S4":
		phase = "end"
		print("MQ-P3 완료: 카르마 %d · 소동 %d(V_DY_P3 %d) · 응시 %s · 10번 %d · 태그 %s · 등록 카드 %d · XP %d" % [
			int(st.vars.get_v("V_KARMA")), int(st.vars.get_v("MQP3_RESULT")), int(st.vars.get_v("V_DY_P3")),
			"대리 %d" % CharDocs.proxy_type(st) if CharDocs.proxy_type(st) > 0 else ("응시" if CharDocs.aptitude_of(st).size() > 0 else "미응시"),
			int(st.vars.get_v("V_Q10")), ",".join(CharDocs.tags_of(st)), int(st.vars.get_v("V_REGCARD")), int(st.vars.get_v("PC_XP"))])
		_shot("p3_end")
		_start_p4()
	elif phase.begins_with("P4"):
		_p4_done()


func _start_p2() -> void:
	phase = "P2"
	host.busy = true
	host.body = "kid"
	host.date_text = "2268. 03. 02.  09:10"
	host.st.quests.set_stage("MQ-P2", 10)                     # 2268년(year())으로 맵을 연다 — 교실의 차명수·하도윤
	host.enter("V-03", "p2_seat")
	host.ev.run("fade_in", ["white", "8"], func() -> void:
		host.busy = false
		host.play_scene("MQ-P2_S01"))


## MQ-P4 시작(2277-10-23, 열아홉): A-07 방에서. 식당에 들어서면 주민 회의(트리거)
func _start_p4() -> void:
	phase = "P4"
	host.busy = true
	host.body = "adult"
	host.hud_on = true
	host.pipboy_ok = true
	host.date_text = "2277. 10. 23.  09:00"
	host.combat.buddy = null
	host.combat.equip("", host.st)
	host.st.quests.set_stage("MQ-P4", 10)                     # 2277년(year())으로 맵을 연다
	host.enter("V-04", "p4_room")
	host.ev.handlers["escape"] = _escape_cmd
	host.ev.run("fade_in", ["white", "8"], func() -> void:
		host.busy = false
		if phase in ["P4", "BOX"]:                                      # 개발용 시작점(탈출·정문)에서는 회의 안내를 띄우지 않는다
			host.hint("주민 회의: 아트리움 남서쪽 공동 식당 — 회의 전까지는 볼트를 둘러봐도 된다", 7.0))


## 개발용(--from=p4e): 호출 직후 A-07에서 탈출만. --esc=4면 하도윤이 동행으로 붙는다
func _start_p4e() -> void:
	_start_p4()
	host.hints.clear()
	host.hint("관리동 호출 — 무기고 · 화장실 덕트 · 오버시어실 · 하층 갱도 철문, 어디로든", 8.0)
	var st := host.st
	st.quests.set_stage("MQ-P4", 30)
	host.date_text = "2277. 10. 23.  13:30"
	host.enter("V-04", "p4_room")
	if esc == 4:
		st.vars.set_v("MQP4_FOLLOW", 1)
		host.ev._show_actor("C-002", host.map.mark_pos("p4_dy"), "W")
		host.ev.handlers["buddy"].call(["C-002"], func() -> void: pass)
	phase = "P4E"
	_bot_skills()


## 개발용 --from=view: 방폭문을 나선 직후(점검표 뒤) 첫 풍경부터
func _start_view() -> void:
	_start_p4()
	host.hints.clear()
	host.st.vars.set_v("V_ESCAPE", 4)
	host.st.quests.set_stage("MQ-P4", 60)
	host.date_text = "2277. 10. 23.  14:10"
	host.enter("V-00", "from_V-01")
	phase = "P4S7"
	_first_view()


## 개발용 --from=gate: 하도윤의 미끼 뒤(④) 정문 구역 제어실 레버 앞부터 — 개방 연출 → 문턱 → 점검표 → 첫 풍경 녹화용
func _start_gate() -> void:
	esc = 0                                                       # 동행 없이(하도윤은 미끼로 떠났다)
	_start_p4e()
	esc = 4
	var st := host.st
	st.quests.set_stage("MQ-P4", 40)
	st.vars.set_v("MQP4_FOLLOW", 1)
	st.vars.set_v("MQP4_DECOY", 1)
	st.call_fn("give", ["M-205"])
	host.hints.clear()
	host.enter("V-00", "")
	host.player.loco.place(Vector2(33 * 32 + 16, 7 * 32 + 16))
	host.player.loco.facing = 6
	host.player._show()


## 개발용 --from=box: 개방의 날 아침(회의 전 자유 시간) A-07에서 용기 열기 — 내 사물함 → 옆방 사물함(절도) → D동 공용 사물함
func _start_box() -> void:
	_start_p4()
	phase = "BOX"


const BOX_ROUTE := [[Vector2i(20, 4), 6], [Vector2i(27, 4), 6], [Vector2i(44, 19), 2]]
var box_i := 0
var box_t := 0.0


func _box_bot() -> void:
	if box_i >= BOX_ROUTE.size():
		if box_t >= 0.0:
			box_t = -1.0
			print("용기 봇 끝: 카르마 %d · 장물 %s · 들킴 %d" % [int(host.st.vars.get_v("V_KARMA")), str(host.st.stolen),
				int(host.st.vars.get_v("S7_THEFT_SEEN"))])
			_shot("box_end")
			if auto:
				get_tree().create_timer(1.0).timeout.connect(get_tree().quit)
		return
	var r: Array = BOX_ROUTE[box_i]
	_use(r[0], r[1])
	if host.container != null:
		box_i += 1
		box_t = 0.0


## 용기 창: 잠깐 보고 → 모두 가져가기 → 잠깐 → 닫기
func _box_screen_bot(dt: float) -> void:
	box_t += dt
	var c := host.container
	if box_t > 1.2 and not c.state.get("_bot_took", false):
		c.state["_bot_took"] = true
		c.take_all()
		c.view.queue_redraw()
		_shot("box_%d" % box_i)
	elif box_t > 2.6:
		c.state.erase("_bot_took")
		c.close(true)


## 봇 준비: 갈래마다 필요한 스킬을 넉넉히(판정 운에 흔들리지 않게)
func _bot_skills() -> void:
	if not auto:
		return
	var st := host.st
	match esc:
		1:
			st.vars.set_v("PC_SKP_LOCKPICK", 20)
		2:
			st.vars.set_v("PC_SKP_SNEAK", 40)
		3:
			st.vars.set_v("PC_SKP_SPEECH", 50)


## MQ-P4 장면이 끝날 때마다: 회의 → 개방식(V-00) → A-07 거래 → (덕트 엿듣기 V-02 컷 → A-07) → 탈출
func _p4_done() -> void:
	var st := host.st
	var s := st.quests.stage("MQ-P4")
	if phase in ["P4E", "P4S5", "P4OUT", "P4S6", "P4S7"]:
		_p4_escape_done()
		return
	if phase == "P4" and s == 20:
		phase = "P4S2"
		_shot("p4_meeting")
		_cut("white", "V-00", "p4_gate", "2277. 10. 23.  12:00", "MQ-P4_S02")
	elif phase == "P4S2" and s == 30:
		phase = "P4S3"
		_shot("p4_gate")
		_cut("black", "V-04", "p4_room", "2277. 10. 23.  13:10", "MQ-P4_S03")
	elif phase == "P4S3" and int(st.vars.get_v("MQP4_DUCT")) == 1:
		phase = "P4S3B"
		host.body = "hidden"
		_cut("", "V-02", "p4_ovs", "", "MQ-P4_S03B")
	elif phase == "P4S3B":
		phase = "P4S3"
		host.body = "adult"
		st.vars.set_v("MQP4_DUCT", 2)                             # 엿들었다(다시 열지 않는다)
		_cut("", "V-04", "p4_room", "", "MQ-P4_S03", "DUCT_BACK")


## 장면 사이 전환: (색이 있으면) 페이드 아웃 → 맵 → 장면(장면이 스스로 페이드 인한다)
func _cut(color: String, map_id: String, mark: String, date: String, scene: String, label := "START") -> void:
	host.busy = true
	var go := func() -> void:
		if date != "":
			host.date_text = date
		host.enter(map_id, mark)
		host.banner_t = 0.0
		host.busy = false
		host.play_scene(scene, label)
	if color == "":
		go.call()
	else:
		host.ev.run("fade_out", [color, "6"], go)


## 원고의 탈출 진행기 명령(0-9c): escape start(호출 = 탈출 시작) · office(도경철을 따라 오버시어실) · alarm(경보: 이 맵의 경비가
## 주인공 쪽을 수색) · done N(출구 도달: 1 전투 · 2 은신 · 3 설득 · 4 하도윤). 장면이 끝나면 _p4_done이 다음으로 넘긴다
var p4_next := ""


func _escape_cmd(a: Array, done: Callable) -> void:
	var st := host.st
	match str(a[0]):
		"start":
			phase = "P4E"
			_bot_skills()
			print("MQ-P4 호출: 덕트 %d · 동행 %d · 단계 %d" % [int(st.vars.get_v("MQP4_DUCT")), int(st.vars.get_v("MQP4_FOLLOW")),
				st.quests.stage("MQ-P4")])
		"office":                                                        # 도경철을 따라 오버시어실 → 엄마
			p4_next = "office"
		"yun":                                                           # 설득 성공: 엄마와 비상 계단으로 정문 구역 서쪽 통로까지
			p4_next = "yun"
		"doyun":                                                         # 원형 철문 → 배수 갱도 → 검역실 바닥 배수구, 하도윤의 미끼
			p4_next = "doyun"
		"alarm":
			p4_fought = true
			for e in host.combat.enemies:
				if is_instance_valid(e) and not e.cmb.dead:
					e.brain.gauge = maxf(e.brain.gauge, AIBrain.SUSPECT_AT + 20.0)
					e.brain.last_seen = host.player.loco.logical
					e.brain._go(AIBrain.S.SEARCH)
		"gate":                                                          # 레버(또는 엄마의 열쇠): 방법을 정하고 방폭문을 연다
			_escape_result(_method())
			p4_next = "gateopen"
		"out":                                                           # 문턱을 넘었다
			p4_next = "out"
	done.call()


## 탈출 방법(0-9 정합, 출구는 방폭문 하나): 엄마의 거짓 무전 3 · 하도윤의 미끼 4 · 들키거나 싸웠으면(무기고를 열었어도) 1 · 아니면 2
var p4_fought := false


func _method() -> int:
	var st := host.st
	if int(st.vars.get_v("MQP4_DECOY")) == 2:
		return 3
	if int(st.vars.get_v("MQP4_DECOY")) == 1:
		return 4
	if p4_fought or int(st.vars.get_v("MQP4_ARMORY")) == 1 or int(st.vars.get_v("MQP4_SEC_KO")) > 0 \
			or int(st.vars.get_v("MQP4_BJ_KO")) > 0 or int(st.vars.get_v("MQP4_CAUGHT")) > 0:
		return 1
	return 2


## 탈출 결과(SD-03a §7.4 표): V_ESCAPE · 하도윤 억류 · 비상정부 호감도 보정(SD-06 §3.2.1) · XP
func _escape_result(n: int) -> void:
	var st := host.st
	st.vars.set_v("V_ESCAPE", n)
	st.vars.set_v("V_DOYUN", 1)                                    # 어느 방법이든 하도윤은 붙잡힌다
	if st.quests.stage("MQ-P4") < 40:
		st.quests.set_stage("MQ-P4", 40)
	st.call_fn("xp", [100])
	var aff := 0
	if n == 3:
		aff = 10
	elif n == 1:
		aff = -10 - mini(15, 5 * int(st.vars.get_v("MQP4_BJ_KO")))
	if aff != 0:
		st.call_fn("aff", ["BJ", aff])


func _p4_escape_done() -> void:
	var st := host.st
	match p4_next:
		"office":
			p4_next = ""
			_cut("black", "V-02", "p4_ovs", "", "MQ-P4_S04_TALK")
			return
		"yun":
			p4_next = ""
			_cut("black", "V-00", "from_V-02", "", "MQ-P4_YUN")
			return
		"doyun":
			p4_next = ""
			host.combat.buddy = null                                   # 동행은 여기서 끝난다(미끼 장면이 따로 세운다)
			host.buddy_name = ""
			host.buddy_id = ""
			_cut("black", "V-00", "from_V-06", "", "MQ-P4_DECOY")
			return
		"gateopen":
			p4_next = ""
			host.play_scene("MQ-P4_GATEOPEN")
			return
		"out":
			p4_next = ""
			for e in host.combat.enemies:                              # 문턱을 넘으면 더 쏘지 않는다
				if is_instance_valid(e):
					e.queue_free()
			host.combat.enemies.clear()
			host.combat._rebuild_list()
			if int(st.vars.get_v("V_ESCAPE")) == 3 and int(st.vars.get_v("K_RALLY")) == 0:   # 설득 경로: 엄마가 열어 준 단말 기록(S5 자동)
				phase = "P4S5"
				host.play_scene("MQ-P4_S05")
				return
			phase = "P4OUT"
			_shot("p4_escape_%d" % int(st.vars.get_v("V_ESCAPE")))
			host.play_scene("MQ-P4_OUT")
			return
	if phase == "P4S5":
		phase = "P4OUT"
		host.play_scene("MQ-P4_OUT")
	elif phase == "P4OUT":
		phase = "P4S6"
		save_to("system", 0)                                      # 시스템 저장(SD-12 §13.1·§13.3): 볼트를 나서기 직전, 점검표 앞
		host.play_scene("MQ-P4_S06")
	elif phase == "P4S6" and st.quests.stage("MQ-P4") >= 60:
		phase = "P4S7"
		_first_view()
	elif phase == "P4S7" and st.quests.stage("MQ-P4") >= 100:
		phase = "end"
		print("MQ-P4 완료: 탈출 %d · 카르마 %d · 비상정부 %d · 하도윤 %d · 붙잡힘 %d · 보안요원 사살 %d · 계엄병 사망 %d · K_RALLY %d · 막 %d · XP %d" % [
			int(st.vars.get_v("V_ESCAPE")), int(st.vars.get_v("V_KARMA")), int(st.vars.get_v("AFF_BJ")), int(st.vars.get_v("V_DOYUN")),
			int(st.vars.get_v("MQP4_CAUGHT")), int(st.vars.get_v("MQP4_SEC_KO")), int(st.vars.get_v("MQP4_BJ_KO")),
			int(st.vars.get_v("K_RALLY")), int(st.vars.get_v("V_ACT")), int(st.vars.get_v("PC_XP"))])
		_shot("end")
		if auto and not chain:
			get_tree().create_timer(0.5).timeout.connect(get_tree().quit)
		else:
			_end_view(func() -> void:                             # 첫 풍경이 멈춘 흙길에서 1막(MQ-101)이 이어진다
				_act1("")
				request_auto("act"))                              # 막이 오르면 먼저 자동 저장(SD-03a §4.1 ①)


## S7 첫 풍경(SD-03a §7.4): 흰 빛이 걷히면 방폭문 앞 콘크리트 턱(위에서 본 RPG 타일 그림) — 주인공(실제 페이퍼돌, 발 고정 걸음)이
## 계단을 올라 흙길에 서고, 잠시 멈춘 뒤 화면이 1px씩 북쪽으로 올라가 관악산 비탈 너머 서울이 나온다(먼 풍경 = 키아트 원경 층).
## 무대 640×540 = 먼 그림(0~330) + 가까운 그림(290~540, 투명 위끝). 자막 "2277년, 서울." 뒤 공보방송(S07). 대화 창(10층)은 무대(9층) 위.
var view_layer: CanvasLayer
var view_stage: Node2D
var view_pc: Actor
var view_cap: Control
var view_t := -1.0
var view_title := 0.0
var view_step := ""                                ## stand → walk → look → pan → title
var view_pan_t := 0.0
const VIEW_Y0 := -180.0                            ## 시작: 무대 아래 360줄(콘크리트 턱·계단)
const VIEW_Y1 := -30.0                             ## 끝: 서울 + 비탈 끝에 선 주인공(화면 아래 가운데)
const VIEW_PAN_SECS := 7.0
const VIEW_START := Vector2(320, 528)              ## 방폭문 문턱(무대 아래 끝)
const VIEW_STOP_Y := 372.0                         ## 계단 위 흙길


class _OpenGround extends RefCounted:              ## 첫 풍경 무대에는 벽이 없다(인형 걸음만 쓴다)
	func move_circle(_a: Vector2, b: Vector2, _r: float) -> Vector2:
		return b

	func circle_hits(_c: Vector2, _r: float) -> bool:
		return false


func _first_view() -> void:
	host.busy = true
	host.ev.run("fade_out", ["white", "10"], func() -> void:
		host.hud_on = false
		host.body = "hidden"
		var lk: Dictionary = host.player.doll.look.duplicate(true) if host.player.doll != null else CharDocs.paperdoll_look(CharDocs.look_of(host.st))
		host.player.visible = false
		view_layer = CanvasLayer.new()
		view_layer.layer = 9
		add_child(view_layer)
		var back := ColorRect.new()                                         # 화면이 무대보다 넓으면(모바일 높이 맞춤) 양옆은 어둡게
		back.color = Color("0B0A0D")
		back.size = Vector2(4000, 2000)
		view_layer.add_child(back)
		view_stage = Node2D.new()
		view_layer.add_child(view_stage)
		for pr in [["far", 0], ["near", 290]]:
			var sp := Sprite2D.new()
			sp.texture = load("res://assets/ui/first_view_%s.png" % pr[0])
			sp.centered = false
			sp.position = Vector2(0, pr[1])
			view_stage.add_child(sp)
		view_pc = Actor.new()
		view_pc.setup_doll(lk, VIEW_START, _OpenGround.new())
		view_pc.mode = "walk"
		view_pc.loco.facing = 6                                              # 북쪽(바깥)을 본다 — 등이 보인다
		view_pc.move(Vector2.ZERO, 0.0)
		view_stage.add_child(view_pc)
		view_cap = Control.new()
		view_cap.size = Vector2(640, 360)
		view_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view_cap.draw.connect(_draw_view_title)
		view_layer.add_child(view_cap)
		view_t = 0.0
		view_step = "stand"
		_view_place(0.0)
		host.ev.run("fade_in", ["white", "14"], func() -> void: pass))


## 첫 풍경을 걷는다: 검게 닫고 → 무대를 치우고 주인공을 다시 보이게 → then(1막 시작, 비탈 맵) → 검게 연다
func _end_view(then: Callable) -> void:
	host.ev.run("fade_out", ["black", "8"], func() -> void:
		if view_layer != null:
			view_layer.queue_free()
			view_layer = null
		view_t = -1.0
		view_title = -1.0
		host.player.visible = true
		then.call()
		host.ev.run("fade_in", ["black", "8"], func() -> void: pass))


## 무대 자리: 가운데 맞춤 + 세로 이동(1px 단위, 반 픽셀 없이)
func _view_place(k: float) -> void:
	var vs := view_cap.get_viewport_rect().size
	var e := k * k * (3.0 - 2.0 * k)
	view_stage.position = Vector2(floorf((vs.x - 640.0) / 2.0), roundf(lerpf(VIEW_Y0, VIEW_Y1, e)) + floorf((vs.y - 360.0) / 2.0))


func _view_tick(dt: float) -> void:
	if view_t < 0.0:
		return
	view_t += dt
	match view_step:
		"stand":                                                            # 흰 빛이 걷히는 동안 문턱에 서 있다
			view_pc.move(Vector2.ZERO, dt)
			if view_t >= 1.6:
				view_step = "walk"
		"walk":                                                             # 계단을 올라 흙길까지(발 고정 걸음)
			view_pc.move(Vector2.UP, dt)
			if view_pc.loco.logical.y <= VIEW_STOP_Y:
				view_step = "look"
				view_t = 0.0
		"look":                                                             # 멈춰 선다(걸음을 마저 디디고 선다) — 잠시 숨을 고른다
			view_pc.move(Vector2.ZERO, dt)
			if view_t >= 1.2 and view_pc.loco.motion == "idle":
				view_step = "pan"
				view_pan_t = 0.0
		"pan":
			view_pc.move(Vector2.ZERO, dt)
			view_pan_t += dt
			_view_place(clampf(view_pan_t / VIEW_PAN_SECS, 0.0, 1.0))
			if view_pan_t >= VIEW_PAN_SECS:
				view_step = "title"
				view_title = 0.01
	if view_step != "pan":
		_view_place(1.0 if view_step == "title" else 0.0)
	if view_title > 0.0:
		view_title += dt
		view_cap.queue_redraw()
		if view_title >= 3.5 and phase == "P4S7" and not host.box.active and host.st.quests.stage("MQ-P4") < 100:
			view_title = -1.0
			_shot("first_view")
			host.busy = false
			host.play_scene("MQ-P4_S07")


func _draw_view_title() -> void:
	if view_title <= 0.0:
		return
	if view_title < 0.3 and int(view_title * 20.0) % 2 == 0:                     # 반투명 없이: 두 번 깜박이며 켜진다
		return
	var f: Font = host.ev.font_title                                                # 숫자가 또렷한 굵은 글꼴(2277이 2077로 읽히지 않게)
	var px := EventRunner.TITLE_PX
	var t := "2277년, 서울."
	var vs := view_cap.get_viewport_rect().size
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := Vector2(floorf((vs.x - w) / 2.0), floorf(vs.y * 0.15))                 # 하늘(주인공은 아래 가운데에 서 있다)
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
		view_cap.draw_string(f, p + o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("1A181D"))
	view_cap.draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("E9E4D8"))


## MQ-P3 시작(2274, 열여섯): 무기는 넣어 두고 교무 구역 동쪽 입구에서. 복도에 들어서면 소동이 열린다(트리거)
func _start_p3() -> void:
	phase = "P3"
	host.busy = true
	host.body = "adult"
	host.hud_on = true
	host.date_text = "2274. 09. 02.  08:40"
	host.combat.buddy = null
	host.combat.equip("", host.st)
	host.st.quests.set_stage("MQ-P3", 10)                     # 2274년(year())으로 맵을 연다 — 사물함 앞의 나채윤·하도윤
	if auto and dy == 2:
		host.st.vars.set_v("PC_SKP_LOCKPICK", 15)              # 봇 준비: 출입 기록 갈래([자물쇠 따기 25])를 시험하려고 올린다
	host.enter("V-03", "from_V-01")
	host.ev.run("fade_in", ["white", "8"], func() -> void:
		host.busy = false
		host.hint("적성 평가 날이다 — 적성 평가 교실로 (시험 전까지는 자유 시간)", 7.0))


# ---------------------------------------------------------------- 전투 신호 → 장면
func _on_target_down(kind: String, _sneak: bool, _left: int) -> void:
	var c := host.combat
	if host.st.quests.stage("MQ-P2") != 50:
		return
	if kind == "target" and c.targets_left("target") == 0 and not stealth_started:
		stealth_started = true
		_scene_soon("MQ-P2_S05B")
	elif kind == "stealth" and c.targets_left("stealth") == 0:
		_scene_soon("MQ-P2_S05C")


func _on_enemy_killed(_id: String, left: int) -> void:
	if left == 0 and host.st.quests.stage("MQ-P2") == 60:
		_scene_soon("MQ-P2_S06_END")


func _scene_soon(id: String) -> void:
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if not host.box.active:
			host.play_scene(id))


## 프롤로그 특례(정합 — 문서에 없음): 쓰러지면 하도윤이 끌어내고, 배관실 입구에서 HP 가득으로 깨어난다
func _on_player_down() -> void:
	if phase == "P4E":
		_caught()
		return
	if phase == "ACT1":                                                # 1막: MQ-101 방어전은 그 진행기가, 그 밖은 생포 또는 쓰러짐(1-3)
		if act1 == null or not act1.fight:
			host.on_pc_down()
		return
	host.busy = true
	host.ev.run("fade_out", ["black", "6"], func() -> void:
		var c := host.combat
		c.pc.hp = c.pc.max_hp
		c.pc.dead = false
		host.player.loco.place(host.map.mark_pos("p2_pipe") if host.map.marks.has("p2_pipe") else host.player.loco.logical)
		host.ev.run("fade_in", ["black", "6"], func() -> void:
			host.busy = false
			host.say_text("정신이 들었다. 하도윤이 통로까지 끌고 나왔다. 스팀팩을 쓰고 다시 가자.")))


## 1막 이후 쓰러짐(생포가 아님): 화면이 어두워지고 마지막 저장(이어하기)을 연다. 저장이 없으면 제목 화면
func _on_pc_died() -> void:
	host.busy = true
	host.hint("쓰러졌다.", 3.0)
	host.ev.run("fade_out", ["black", "12"], func() -> void:
		var p := SaveSlots.continue_path()
		if p != "" and not auto:
			load_from(p)
		elif auto:
			print("봇: 주인공 쓰러짐(1막 이후)")
			get_tree().quit(3)
		else:
			to_title())


## 붙잡힘(MQ-P4 탈출 중 HP 0, SD-14 §9.12.1 정합): A-07로 끌려와 HP 가득으로 다시 시작. 맵의 경비·계엄군은 제자리로
func _caught() -> void:
	var st := host.st
	st.vars.set_v("MQP4_CAUGHT", int(st.vars.get_v("MQP4_CAUGHT")) + 1)
	host.busy = true
	host.ev.run("fade_out", ["black", "6"], func() -> void:
		var c := host.combat
		c.pc.hp = c.pc.max_hp
		c.pc.dead = false
		c.crouch = false
		host.enter("V-04", "p4_room")
		host.ev.run("fade_in", ["black", "6"], func() -> void:
			host.busy = false
			host.say_text("보안부에 붙잡혀 A-07로 끌려왔다. 문 앞 경비가 교대하는 틈이다. 다시 나가자.")))


func _shot(tag: String) -> void:
	if shots == "":
		return
	shot_n += 1
	get_viewport().get_texture().get_image().save_png("%s/p_%02d_%s.png" % [shots, shot_n, tag])


# ---------------------------------------------------------------- 자동 진행
func _process(dt: float) -> void:
	_view_tick(dt)
	_save_tick(dt)
	if phase == "P4E" and host.combat.in_combat():
		p4_fought = true                                          # 들켜서 교전이 붙었다 → 은신이 아니라 전투로 나간 것
	if phase == "P4E" and host.map != null and host.map.id != "V-04" and host.st.quests.stage("MQ-P4") == 30:
		host.st.quests.set_stage("MQ-P4", 40)                    # 방을 나서면 '볼트를 빠져나간다'
	if not auto or phase == "ACT1":                                # 1막은 Mq101 진행기가 대화·봇을 맡는다
		return
	t += dt
	if log_on and int(t) % 5 == 0 and int(t - dt) % 5 != 0:
		var c := host.combat
		print("[%3.0f초] %s %s 단계 %d HP %.0f 무기 %s 대화 %s 바쁨 %s 표적 %d/%d 바퀴 %d" % [t, host.map.id, host.player.loco.render,
			host.st.quests.stage("MQ-P4" if phase.begins_with("P4") else ("MQ-P3" if phase.begins_with("P3") else "MQ-P2")), c.pc.hp, c.weapon_id, host.box.active, host.busy or host.ev.busy(),
			c.targets_left("target"), c.targets_left("stealth"), c.alive_enemies()])
		if host.box.active:
			print("        대화: %s %s" % [host.box.state.get("who", ""), str(host.box.state.get("text", host.box.state.get("type", ""))).left(40)])
	var box := host.box
	if host.pipboy != null:
		_pip_bot(dt)
		return
	if box.active and not box.waiting_cmd:
		_stop()
		host.combat.bot = {"walk": true}                                   # 봇이지만 조준은 하지 않는다(걷는 쪽을 본다)
		match box.state.get("type", ""):
			"line":
				if box.reveal >= box.page_len:
					hold += dt
					if hold > 0.8:
						hold = 0.0
						if box.state.get("who", "") in ["N-R01-010", "C-002", "C-023", "C-027"] or box.state.get("text", "").contains("하나 잡아"):
							_shot(str(box.state.get("who", "")))
						box.next()
			"choices":
				hold += dt
				if hold > 1.4:
					hold = 0.0
					_shot("choices")
					var opts: Array = box.state.get("opts", [])
					if phase == "P3":
						box.pick(_p3_choice(opts))
					elif phase.begins_with("P4"):
						box.pick(_p4_choice(opts))
					elif host.st.quests.stage("MQ-P2") == 40:
						box.pick(_by_text(opts, JIWOO_KEYS[jiwoo - 1]))
					else:
						box.pick(pick - 1)
		return
	if host.container != null:
		_box_screen_bot(dt)
		return
	if box.active or host.busy or host.ev.busy():                  # 서류가 열린 동안(대화창은 명령 대기)도 기다린다
		return
	if phase == "BOX":
		_box_bot()
		return
	if phase == "P1S2":
		_p1_bot()
	elif phase == "P2":
		_p2_bot()
	elif phase == "P3":
		_p3_bot()
	elif phase == "P4":
		_p4_bot()
	elif phase == "P4E":
		_p4e_bot()


## MQ-P3 봇 선택: 복도 소동(--dy), 응시 방법(--exam), 대리 작성 유형(돌잡이에 맞춘 칸), 10번(--q10)
const DY_KEYS := ["살핀다", "출입 기록", "설득한다", "앞을 막는다", "봤다고", "지나친다"]
const EXAM_KEYS := {"test": "시험을 본다", "skip": "꼭 봐야", "proxy": "대신 써"}
const APT := [1, 1, 1, 3, 2, 1, 3, 1, 4, 1]                      ## 봇 답(소형 화기 3 · 수리 3 동점 → 10번이 나중 → 보안부 탄피 수거원)


func _p3_choice(opts: Array) -> int:
	var texts := opts.map(func(o): return str(o["text"]))
	if texts.any(func(x): return x.contains("지나친다")):          # 복도 소동. 화술이 실패해 사라졌으면 막아서기로
		var i := _by_text(opts, DY_KEYS[dy - 1])
		return i if str(opts[i]["text"]).contains(DY_KEYS[dy - 1]) else _by_text(opts, "앞을 막는다")
	if texts.any(func(x): return x.contains("시험을 본다")):
		return _by_text(opts, EXAM_KEYS.get(exam, "시험을 본다"))
	if texts.any(func(x): return x.contains("기계를 만지는 일")):    # 돌잡이에 맞춘 칸(없으면 몸)
		return int(CharDocs.DOL_PROXY.get(int(host.st.vars.get_v("V_DOL")), 3)) - 1
	return clampi(q10 - 1, 0, opts.size() - 1)                    # 10번 문항


## MQ-P3 봇: 복도를 지나(소동 트리거) 교실의 차명수 → 평가관실의 차명수
func _p3_bot() -> void:
	var s := host.st.quests.stage("MQ-P3")
	host.combat.bot = {"walk": true}
	match s:
		10:
			_go("V-03", "p3_locker")
		30:
			_talk_to("C-023", Vector2(0, 32), 6)
		40:
			_talk_to("C-023", Vector2(0, 32), 6)


## MQ-P4 봇 선택: 회의(찬성), 거래(--duct), 동행(--esc 4면 따라간다)
func _p4_choice(opts: Array) -> int:
	var texts := opts.map(func(o): return str(o["text"]))
	if texts.any(func(x): return x.contains("하도윤에게 듣는다")):
		return _by_text(opts, "덕트로" if duct == 1 else "하도윤에게 듣는다")
	if texts.any(func(x): return x.contains("하도윤을 따라간다")):
		return _by_text(opts, "하도윤을 따라간다" if esc == 4 else "혼자")
	if texts.any(func(x): return x.contains("머리핀")):
		return _by_text(opts, "머리핀")
	if texts.any(func(x): return x.contains("정비 카드")):               # 제어실 레버
		var i := _by_text(opts, "정비 카드")
		return i if opts[i]["enabled"] and str(opts[i]["text"]).contains("정비 카드") else _by_text(opts, "열쇠 구멍")
	if texts.any(func(x): return x.contains("서명만 하면")):
		return _by_text(opts, "서명만 하면")
	return 0


## MQ-P4 봇: 방에서 식당까지(회의 트리거)
func _p4_bot() -> void:
	host.combat.bot = {"walk": true}
	if host.st.quests.stage("MQ-P4") == 10:
		_go("V-01", "p4_meet")


## 탈출 봇(--esc): 1 무기고(자물쇠) → 권총 → 정문 데크를 달려 지나간다 · 2 웅크려 관리동 화장실 덕트 → 하층 → 농장 배수로 서쪽 끝
##   · 3 오버시어실의 엄마를 설득 · 4 하도윤을 따라(또는 혼자) 하층 갱도 철문
func _p4e_bot() -> void:
	var st := host.st
	var c := host.combat
	var m := host.map.id
	c.bot = {"walk": true}
	if int(st.vars.get_v("V_ESCAPE")) >= 1:                              # 방폭문이 열렸다: 문턱으로(파워 아머 옆을 지나)
		if m != "V-00":
			_go("V-00", "")
		else:
			_move_to(Vector2(19 * 32 + 16, 9 * 32 + 16))
		return
	match esc:
		1:
			var need_gun := int(st.items.get("W-002", 0)) == 0
			var near := _threat(4.0)
			if need_gun and near != null:                                      # 총이 없으면 대걸레 자루로 기절시킨다(비살상)
				if c.weapon_id != "W-067":
					c.equip("W-067", st)
				if near.loco.logical.distance_to(host.player.loco.logical) > 40.0:
					_move_to(near.loco.logical)
					c.bot = {"aim": near.loco.logical + Vector2(0, -6)}
				else:
					_stop()
					c.bot = {"aim": near.loco.logical + Vector2(0, -6), "fire": true}
			elif need_gun and m != "V-09":
				_go("V-09", "")
			elif int(st.vars.get_v("MQP4_ARMORY")) == 0:
				_use(Vector2i(22, 15), 6)
			elif need_gun:
				_use(Vector2i(22, 4), 6)
			else:
				if c.weapon_id != "W-002":
					c.equip("W-002", st)
				var foe := _threat(7.0)
				if foe != null:                                              # 막아서는 보안요원: 서서 쏜다(계엄군·파워 아머는 지나친다)
					_stop()
					c.bot = {"aim": foe.loco.logical + Vector2(0, -10), "fire": true, "aimed": true}
				elif m != "V-00":
					_go("V-00", "")
				else:
					_use(Vector2i(34, 4), 6)                                # 제어실 레버
		2:                                                                    # 설비 → 하층 → 농장 3·2·1동 → 배수 갱도 → 검역실 → 정비 통로 → 레버
			c.bot = {"walk": true, "crouch": true}
			if m in ["V-04", "V-10"]:
				_go("V-11", "")
			elif m == "V-11":
				_go("V-06", "")
			elif m == "V-06":
				var pts := [Vector2i(45, 31), Vector2i(40, 16), Vector2i(19, 16), Vector2i(5, 31), Vector2i(1, 36)]
				var me := host.map.tile_of(host.player.loco.logical)
				var wp: Vector2i = pts[mini(stealth_wp, pts.size() - 1)]
				if me == wp and stealth_wp < pts.size() - 1:
					stealth_wp += 1
				_move_to(Vector2(wp.x * 32 + 16, wp.y * 32 + 16))
			elif m == "V-00":
				var pts := [Vector2i(37, 26), Vector2i(37, 20), Vector2i(36, 14), Vector2i(34, 4)]
				var me := host.map.tile_of(host.player.loco.logical)
				var wp: Vector2i = pts[mini(stealth_wp0, pts.size() - 1)]
				if me == wp and stealth_wp0 < pts.size() - 1:
					stealth_wp0 += 1
				if stealth_wp0 == pts.size() - 1:
					_use(pts[-1], 6)
				else:
					_move_to(Vector2(wp.x * 32 + 16, wp.y * 32 + 16))
			else:
				_go("V-04", "")
		3:
			if m != "V-02":
				_go("V-02", "")
			else:
				_talk_to("C-001", Vector2(-32, 0), 0)
		4:
			if m == "V-00":
				_use(Vector2i(34, 4), 6)                                    # 미끼 뒤: 정비 카드로 레버
			elif m != "V-11":
				_go("V-11", "p4_gate11")
			elif int(st.vars.get_v("MQP4_FOLLOW")) == 1:
				_move_to(host.map.mark_pos("p4_gate11"))
			else:
				_talk_to("C-002", Vector2(0, 32), 6)


var stealth_wp0 := 0
var stealth_wp := 0


## 가까이서 주인공과 교전 중인 보안요원(전투 봇이 쏠 상대)
func _threat(r_t: float) -> Enemy:
	for e in host.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and e.get_meta("enemy_id") == "CR-473" and e.brain.state == AIBrain.S.COMBAT \
				and e.loco.logical.distance_to(host.player.loco.logical) < r_t * 32.0 and host.map.line_of_sight(host.player.loco.logical, e.loco.logical):
			return e
	return null


## 칸 at에 서서 facing 쪽을 조사한다(무기고 문·총기 거치대)
func _use(at: Vector2i, facing: int) -> void:
	var to := Vector2(at.x * 32 + 16, at.y * 32 + 16)
	if NpcRoutine.arrived(host.player.loco.render, to):
		_stop()
		host.player.loco.facing = facing
		host.player._show()
		host.interact()
	else:
		_move_to(to)


## 인물 앞(off만큼 떨어진 자리)으로 가서 그쪽을 보고 말을 건다
func _talk_to(id: String, off: Vector2, facing: int) -> void:
	var n := _npc(id)
	if n.is_empty():
		return
	var to: Vector2 = n["actor"].loco.logical + off
	if NpcRoutine.arrived(host.player.loco.render, to):
		_stop()
		host.player.loco.facing = facing
		host.player._show()
		host.interact()
	else:
		_move_to(to)


## 지우 장면 선택지(원고 차례 1~6)를 문장으로 찾는다 — 조건이 안 맞는 줄은 숨어서 번호가 밀린다
const JIWOO_KEYS := ["간식 쿠폰을 준다", "재발급", "바닥 틈", "주변을 찾아본다", "지나친다", "남은 쿠폰"]


func _by_text(opts: Array, key: String) -> int:
	for i in opts.size():
		if str(opts[i]["text"]).contains(key) and opts[i]["enabled"]:
			return i
	return opts.size() - 2 if opts.size() >= 2 else 0


func _pip_bot(dt: float) -> void:
	_pip_t += dt
	var p := host.pipboy
	var k := int(_pip_t / 1.1)
	if _pip_t > 0.6 and k != int((_pip_t - dt) / 1.1):
		_shot("pip%d" % k)
		match k:
			1: p._sub(1)
			2: p._sub(1)
			3: p._tab(1)
			4: p._tab(2)
			5: p.close(true)


func _p1_bot() -> void:
	if not talked:
		var n := _npc("N-R01-010")
		if n.is_empty():
			talked = true
			return
		var to: Vector2 = n["actor"].loco.logical + Vector2(-32, 0)
		if NpcRoutine.arrived(host.player.loco.render, to):
			_stop()
			host.player.loco.facing = 0
			host.player._show()
			talked = host.interact()
		else:
			_move_to(to)
		return
	_move_to(host.map.mark_pos("dol_front"))


## MQ-P2 봇: 단계마다 갈 곳(맵·표지)과 할 일
func _p2_bot() -> void:
	var st := host.st
	var c := host.combat
	var s := st.quests.stage("MQ-P2")
	c.bot = {"walk": true}
	match s:
		20:
			_go("V-01", "bday_front")
		30:
			_go("V-02", "p2_window")
		40:
			var met := host.fired.has("V-01:37,30")
			if int(st.vars.get_v("MQP2_RESULT")) == 0 and not (met and jiwoo != 4):
				if jiwoo == 4 and met:
					_crack()                                                 # 조사 3회 길
				else:
					_go("V-01", "p2_ration")
			else:
				_go("V-09", "p2_range")                                      # (화술 실패로 결과 없이 떠나도 된다)
		50:
			_range()
		60:
			if host.map.id != "V-11" or not host.fired.has("V-11:10,15"):
				_go("V-11", "p2_pipe")
			else:
				_pipe()


## 조사 3회 길(--jiwoo=4 → '주변을 찾아본다' 뒤): 바닥 틈 앞에서 아래를 보고 조사
func _crack() -> void:
	var to := Vector2(37 * 32 + 16, 38 * 32 + 16)
	if NpcRoutine.arrived(host.player.loco.render, to):
		_stop()
		host.player.loco.facing = 2
		host.player._show()
		host.interact()
	else:
		_move_to(to)


## 다른 맵의 표지까지: 지금 맵이 아니면 다음 출구로, 맞으면 표지로
func _go(map_id: String, mark: String) -> void:
	var goal: Vector2
	if host.map.id != map_id:
		var e := MapGraph.next_exit(host.map.id, map_id)
		if e.x < 0:
			return
		goal = Vector2(e.x * 32 + 16, e.y * 32 + 16)
	else:
		goal = host.map.mark_pos(mark)
	_move_to(goal)


## 사격장: 1부 사대에서 표적마다 쏜다 → 2부 웅크려 모래주머니 뒤로 가서 은신 표적
func _range() -> void:
	var c := host.combat
	if host.map.id != "V-09":
		_go("V-09", "p2_range")
		return
	var live: Array = c.targets.filter(func(x): return not x["down"] and (x["kind"] == "target" or (stealth_started and x["live"])))
	if live.is_empty():
		_stop()
		return
	var normal: Array = live.filter(func(x): return x["kind"] == "target")
	var tgt: Dictionary = normal.front() if not normal.is_empty() else live.front()
	var stand: Vector2
	var crouch := false
	var aim: Vector2 = tgt["cmb"].pos() + Vector2(0, -4)
	if tgt["kind"] == "stealth":
		crouch = true
		stand = host.map.mark_pos("sneak_1" if int(tgt["prop"]["y"]) < 16 else "sneak_2")
		if tgt["seen_t"] > 0.0:                                          # 들켰다: 모래주머니 뒤에서 기다린다
			_move_to(stand)
			c.bot = {"walk": true, "crouch": true}
			return
	else:                                                                 # 사대(x 30)의 세 자리 가운데 표적과 가까운 곳에서 비스듬히 쏜다
		var ty := int(tgt["prop"]["y"])                                   # (BB총 최대 사거리 12.25칸 — 맨 끝 표적은 앞 자리에서)
		var lane := 9 if ty <= 11 else (22 if ty >= 21 else 16)
		stand = Vector2(30 * 32 + 16, lane * 32 + 16)
	if host.player.loco.logical.distance_to(stand) > 6.0:
		_move_to(stand)
		c.bot = {"walk": true, "crouch": crouch}                          # 자리로 가는 동안은 조준하지 않는다(뒷걸음 없이 걷는다)
		return
	_stop()
	c.bot = {"aim": aim, "fire": true, "crouch": crouch, "aimed": true}


## 배관실: HP가 60% 밑이면 스팀팩(단축키 3), 가장 가까운 바퀴에게 다가가 휘두른다
func _pipe() -> void:
	var c := host.combat
	var me := host.player.loco.logical
	if c.pc.hp < c.pc.max_hp * 0.6 and not c.healing() and int(host.st.items.get(InteriorCombat.STIMPAK, 0)) > 0 and c.inject_t <= 0.0:
		c.hotkey(3, host.st)
		_stop()
		return
	if c.weapon_id != "W-067":
		c.equip("W-067", host.st)
	var best: Enemy = null
	var bd := 1e9
	for e in c.enemies:
		if is_instance_valid(e) and not e.cmb.dead and me.distance_to(e.loco.logical) < bd:
			bd = me.distance_to(e.loco.logical)
			best = e
	if best == null:
		_stop()
		return
	var reach := float(c.weapon()["range_eff"]) * 32.0
	if bd > reach + best.cmb.radius - 4.0:
		_move_to(best.loco.logical)
		c.bot = {"aim": best.loco.logical + Vector2(0, -6)}
	else:
		_stop()
		c.bot = {"aim": best.loco.logical + Vector2(0, -6), "fire": true}


func _npc(id: String) -> Dictionary:
	for n in host.npcs:
		if n["id"] == id:
			return n
	return {}


## 봇 이동: 목표만 정해 두면 진행기가 1/60초마다 _bot_input을 불러 길을 따라간다(긴 프레임에서도 칸 가운데를 지나치지 않는다)
var bot_goal := Vector2.INF


func _move_to(goal: Vector2) -> void:
	bot_goal = goal
	host.input_fn = _bot_input


func _stop() -> void:
	bot_goal = Vector2.INF


func _bot_input() -> Vector2:
	if bot_goal == Vector2.INF or host.map == null:
		return Vector2.ZERO
	return _follow(bot_goal)


## 길찾기 경로를 따라가는 입력. 목표가 바뀌었거나 3초마다(움직이는 인물이 길을 막으면) 다시 찾는다
func _follow(goal: Vector2) -> Vector2:
	var p := host.player.loco.render
	if path.is_empty() or host.map.tile_of(path_goal) != host.map.tile_of(goal) or t - _re_t > 3.0:
		_re_t = t
		path = NpcRoutine.with_start(host.map, p, goal)
		path_goal = goal
	while path.size() > 0 and NpcRoutine.arrived(p, path[0]):
		path.remove_at(0)
	if path.is_empty():
		return Vector2.ZERO
	return NpcRoutine.step_dir(p, path[0])


# ================================================================================================ 저장·불러오기(0-11)
## 지금 저장할 수 없는 까닭(빈 글 = 가능). 수동 저장 불가: 핍-보이·대화·서류·연출 중(§13.1)
func why_no_save() -> String:
	if host == null or host.map == null or host.player == null:
		return "아직 저장할 수 없다"
	if host.box.active or host.ev.busy() or host.busy or view_t >= 0.0 or phase in NO_SAVE_PHASES:
		return "연출 중에는 저장할 수 없다"
	if host.pipboy != null or host.container != null:
		return "창을 닫고 저장한다"
	if mq106 != null and mq106.active():
		return "추격 중에는 저장할 수 없다"
	for c in host.get_children():
		if c is DocScreen and not (c is PauseMenu):
			return "서류를 마치고 저장한다"
	return ""


## 자동 저장을 더 미뤄야 하나(§13.2 미루기: 교전·적 감지·대화·연출)
func _auto_blocked() -> bool:
	if why_no_save() != "":
		return true
	if host.combat.in_combat():
		return true
	for e in host.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and e.cmb.team == "enemy" and e.brain.gauge >= 40.0:
			return true
	return false


func snapshot() -> Dictionary:
	return {"story": GameSnapshot.story(host.st), "host": GameSnapshot.host(host),
		"flow": {"phase": phase, "p4_fought": p4_fought, "buddy": host.buddy_id, "mates": host.combat.mates.snapshot(), "act1": act1.snapshot() if act1 != null else {}}}


func save_to(kind: String, idx: int) -> Error:
	if kind != "suspend" and kind != "system" and why_no_save() != "":
		return ERR_BUSY
	var tb := thumb if not thumb.is_empty() else GameSnapshot.thumbnail(get_viewport())
	var err := SaveSlots.write(kind, idx, GameSnapshot.slot_info(host, play_time, tb), snapshot())
	if err == OK and kind in ["auto", "system"]:
		host._note("자동 저장" if kind == "auto" else "볼트를 나서기 전 저장")
	return err


func request_auto(reason: String) -> void:
	if auto_due == "" or reason in ["sleep", "act"]:
		auto_due = reason


func _menu_shots(dt: float) -> void:
	if menushot >= 1000.0:
		return
	menushot += dt
	if menushot < 10.0 or why_no_save() != "":                     # 대화가 끝나 저장할 수 있을 때 한 번
		return
	menushot = 1000.0
	save_to("manual", 2)
	open_pause()
	var steps := [["menu_main", "save"], ["menu_save", "load"], ["menu_load", "keys"], ["menu_keys", ""]]
	var i := 0
	for stp in steps:
		i += 1
		get_tree().create_timer(1.5 * i, true).timeout.connect(func() -> void:
			_shot(stp[0])
			if stp[1] != "":
				pause_menu._open(stp[1])
			else:
				pause_menu.close(true)
				get_tree().create_timer(0.5, true).timeout.connect(get_tree().quit))


func _save_tick(dt: float) -> void:
	if menushot >= 0.0:
		_menu_shots(dt)
	if get_tree().paused or host == null:
		return
	play_time += dt
	if play_time - last_auto >= auto_every and auto_due == "":
		request_auto("interval")
	if act1 != null and int(host.st.vars.get_v("MQ101_NIGHT")) == 3 and _night_seen != 3:
		request_auto("sleep")                                       # 빌린 침대에서 잔 뒤(§13.2 '수면 뒤')
	_night_seen = int(host.st.vars.get_v("MQ101_NIGHT"))
	if auto_due != "" and not _auto_blocked() and (play_time - last_auto >= SaveSlots.AUTO_GAP or auto_due in ["sleep", "act", "travel"]):
		if save_to("auto", SaveSlots.auto_index()) == OK:
			last_auto = play_time
		auto_due = ""
	if savetest and not _saved_test and play_time > 15.0 and why_no_save() == "":
		_saved_test = true
		var err := save_to("manual", 59)
		SaveSlots.check = _sha(var_to_bytes(snapshot()))
		print("저장 시험: 수동 60칸 %s · %s %s" % [error_string(err), host.map.id, str(host.player.loco.logical)])
		load_from(SaveSlots.path_of("manual", 59))
		return
	_stable_t -= dt
	if _stable_t <= 0.0 and why_no_save() == "":
		_stable_t = 2.0
		stable = snapshot()
		stable_slot = GameSnapshot.slot_info(host, play_time)


## 모바일: 앱이 뒤로 가면 상황과 관계없이 중단 저장(§17.6). 대화·연출 중이면 그 직전의 안정 상태를 쓴다
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and host != null and not stable.is_empty():
		SaveSlots.ensure_dir()
		if why_no_save() != "":
			SaveSlots.write("suspend", 0, stable_slot, stable)
		else:
			SaveSlots.write("suspend", 0, GameSnapshot.slot_info(host, play_time, GameSnapshot.thumbnail(get_viewport())), snapshot())
	elif what == NOTIFICATION_APPLICATION_RESUMED and host != null and pause_menu == null and (touch_on or OS.has_feature("mobile")):
		open_pause()                                               # 돌아오면 일시 정지 메뉴가 열린 상태(§17.6 복귀 시 처리)


func open_pause() -> void:
	if pause_menu != null or why_no_save().begins_with("아직") or host.pipboy != null or host.container != null:
		return
	thumb = GameSnapshot.thumbnail(get_viewport())
	get_tree().paused = true
	pause_menu = PauseMenu.new().setup(host.st, why_no_save, save_to, load_from, to_title)
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.subtitle = host.date_text
	pause_menu.now = GameSnapshot.slot_info(host, play_time, thumb)
	pause_menu.now["goal"] = host._objective()
	add_child(pause_menu)
	pause_menu.closed.connect(func(_ok: bool) -> void:
		pause_menu = null
		thumb = PackedByteArray()
		get_tree().paused = false)


func load_from(path: String) -> void:
	get_tree().paused = false
	SaveSlots.pending = path
	get_tree().change_scene_to_file("res://scenes/story/prologue.tscn")


func to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo) or auto:
		return
	match e.keycode:
		KEY_ESCAPE:
			if host.box.active or host.pipboy != null or host.container != null:
				return
			open_pause()
		KEY_F5:
			var err := save_to("quick", 0)
			host._note("빠른 저장" if err == OK else why_no_save())
		KEY_F9:
			if FileAccess.file_exists(SaveSlots.path_of("quick")):
				load_from(SaveSlots.path_of("quick"))
		_:
			return
	get_viewport().set_input_as_handled()


## 불러오기: 이야기 상태 → 진행 단계 → 맵·주인공(맵 진입 신호가 1막 진행기의 밤·개·추적조를 다시 세운다)
func _load_game(path: String) -> void:
	var r := SaveGame.read(path)
	if not r["ok"]:
		push_warning("저장을 읽지 못했다: %s (%s)" % [path, r["error"]])
		to_title()
		return
	var w: Dictionary = r["world"]
	GameSnapshot.apply_story(host.st, w["story"])
	play_time = float(r["slot"].get("play_time", 0))
	last_auto = play_time
	var flow: Dictionary = w.get("flow", {})
	phase = str(flow.get("phase", "P2"))
	p4_fought = bool(flow.get("p4_fought", false))
	if phase.begins_with("P4"):
		host.ev.handlers["escape"] = _escape_cmd
	if phase == "ACT1":
		act1 = Mq101.new()
		add_child(act1)
		act1.setup(host, auto, log_on, sol, shots)
		act1.resume(flow.get("act1", {}))
		_paths()
	GameSnapshot.apply_host(host, w["host"])
	if phase == "P4S6":                                            # 시스템 저장: 점검표부터 다시(→ 첫 풍경 → 1막)
		host.play_scene.call_deferred("MQ-P4_S06")
	var ms: Dictionary = flow.get("mates", {})                          # 일시 동행(1-10a): 곁의 동행 · 다른 맵에 기다리게 둔 동행
	var here: Array = ms.get("here", [])
	if here.is_empty() and str(flow.get("buddy", "")) != "":
		here = [{"id": str(flow["buddy"])}]                              # 옛 저장: 동행 하나
	for k in here:
		var b := str(k["id"])
		if b != "" and host.ev.handlers.has("buddy"):
			host.ev._show_actor(b, host.player.loco.logical + Vector2(-32, 0), "S")
			host.ev.handlers["buddy"].call([b], func() -> void: pass)
			var mm := host.combat.mates.get_mate(b)
			if not mm.is_empty():
				mm["mode"] = str(k.get("mode", "follow"))
				if k.has("hp"):
					(mm["cmb"] as Combatant).hp = clampf(float(k["hp"]), 1.0, (mm["cmb"] as Combatant).max_hp)
				if k.has("home"):
					mm["home"] = Vector2(float(k["home"][0]), float(k["home"][1]))
	host.combat.mates.away = (ms.get("away", {}) as Dictionary).duplicate(true)
	if str(r["slot"].get("kind", "")) == "suspend":
		SaveSlots.erase("suspend")                                     # 되감기 막기: 불러온 중단 저장은 지운다(§17.6)
		if not auto:
			open_pause.call_deferred()                                 # 중단 지점으로 돌아오면 일시 정지 메뉴부터(§17.6)
	host._note("불러왔다 — " + str(r["slot"].get("place", "")))
	if SaveSlots.check != "":
		_saved_test = true
		var same := _sha(var_to_bytes(snapshot())) == SaveSlots.check
		print("불러오기 시험: %s · %s %s · 단계 %s · HP %.0f · 캡 %d" % ["한 장 같음" if same else "한 장 다름", host.map.id,
			str(host.player.loco.logical), phase, host.combat.pc.hp, int(host.st.vars.get_v("PC_CAPS"))])
		SaveSlots.check = ""
		get_tree().create_timer(0.3).timeout.connect(get_tree().quit)


static func _sha(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(b)
	return h.finish().hex_encode()

