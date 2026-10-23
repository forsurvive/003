## 지하시장 봇(단계 1-4, SD-19 §10.2 봇 플레이): MQ-103 갈래를 실제 맵·대화·전투·해킹 위에서 처음부터 끝까지 돈다.
## 갈래(인자 첫째): job 출입세→상인회 일·박춘삼→둥지→출입패→문→해독→고백(과학)→북쪽 출구 매복 · vent 구청역 통로→둥지→환풍구(은신)→해독
##   · hack 역사 쇼핑몰→출입 단말 해킹→문→해독 · fee 카리스마 농담→면담료 300→문→해독→고백 실패(화술)
## 둘째 인자 = 스크린샷 폴더(없으면 찍지 않음). 끝에 '지하시장 봇 <갈래>: ○ n/m' 한 줄과 확인 줄을 찍는다.
## 실행: xvfb-run godot --path game res://scenes/bench/jm_bot.tscn -- job /tmp/shots
extends Node

var host: InteriorHost
var paths: Act1Paths
var mq106: Mq106
var side: SideR01                                    ## 관악 사이드 퀘스트(1-11a SQ-S01)
var side2: SideS02                                   ## 관악 사이드 퀘스트(1-11b SQ-S02)
var side4: SideS04                                   ## 관악 사이드 퀘스트(1-11c SQ-S04)
var side3: SideS03                                   ## 관악 사이드 퀘스트(1-11d SQ-S03)
var side5: SideS05                                   ## 관악 사이드 퀘스트(1-11e SQ-S05)
var side6: SideS06                                   ## 관악 사이드 퀘스트(1-11f SQ-S06)
var side8: SideS08                                   ## 영등포 사이드 퀘스트(1-11g SQ-S08)
var side9: SideS09                                   ## 영등포 사이드 퀘스트(1-11h SQ-S09)
var side10: SideS10                                 ## 영등포 사이드 퀘스트(1-11i SQ-S10)
var side12: SideS12                                 ## 지하시장 사이드 퀘스트(1-11k SQ-S12)
var side13: SideS13                                 ## 볼트 S-02 사이드 퀘스트(1-11l SQ-S13)
var jc01: FqJc01                                    ## 세력 퀘스트 FQ-JC-01 계단 물길(1-12a)
var fqgs: FqGs                                       ## 세력 퀘스트 FQ-GS-01 정비 당번 · FQ-GS-02 천공기(1-12b)
var fqjh: FqJh                                       ## 세력 퀘스트 FQ-JH-01 B구역 셔터(1-12c)
var fqjh3: FqJh3                                     ## 세력 퀘스트 FQ-JH-03 지상 배달(1-12e)
var fqsb: FqSb                                       ## 세력 퀘스트 FQ-SB-01 · 02(1-12f)
var cara: Caravans                                   ## 순회 일정(소윤희 MEDIC_AT — 1-12e 수산시장 대기)
var side11: SideS11                                 ## 여의도 사이드 퀘스트(1-11j SQ-S11)
var uq71: Uq71                                     ## 비표시 퀘스트 UQ-71(1-D1 대방 지하차도)
var u02: U02Paths                                  ## U02 남태령 지하(1-D2)
var uq04: Uq04                                     ## UQ-04 7호 냉동 창고(1-D3)
var uq_r01: UqR01                                  ## R01 비표시 퀘스트 넷(1-12g)
var rq: RqR01                                          ## 1-12j 반복 의뢰
var uq_r02: UqR02                                  ## R02 비표시 퀘스트(1-12h)
var gr: Gr                                         ## 구로 차량기지(1-D4)
var kt: Kt                                         ## 여의도 금탑(1-D5a)
var ga: Ga
var ks: Ks                                         ## 구로 공단 지식산업센터 · 문래(1-D7)
var hosp: Hp                                       ## 여의도 대학병원(1-D8)
var yt: Yt                                         ## 여의도 유리탑 3동 · 증권가 객장(1-D9)
var u04: U04                                       ## 여의도 지하 U04(1-D10)
var stash: Stash                                   ## 보관 자리 · UQ-125(1-L)
var st: StoryState
var route := "job"
var shots := ""
var plan: Array = []
var i := 0
var t := 0.0
var step_t := 0.0
var path := PackedVector2Array()
var _repath_t := -1.0
var want: Array = []
var checks: Array = []
var hold := 0.0
var shot_n := 0
var last_report := 0.0
var menu_t := 0.0
var shot_on := ""                                    ## 이 글귀가 든 대사 줄에서 한 장 찍는다(연출 확인)
var shot_tag := ""
var shot_wait := 0.0
var seen := {}
var last_line := ""
var note_t := 0.0
var fight_hp := 0.0                                 ## 싸움: 적 체력 합(피해를 주고 있나)
var fight_n := 0
var fight_still := 0.0
var _stuck_p := Vector2.ZERO                         ## 걸음이 막힌 자리(움직이는 사람·짐승이 길을 막으면 옆으로 한 발 비켜 돈다)
var _stuck_t := 0.0
var _side_t := 0.0
var _side_dir := Vector2.ZERO
var step_map := 0                                   ## 걸음 단계를 시작한 맵 노드(출구를 밟아 맵이 바뀌면 그 단계는 끝 — 월드 안 구역 이름 바뀜은 아니다)


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	route = a[0] if a.size() > 0 else "job"
	shots = a[1] if a.size() > 1 else ""
	host = InteriorHost.new()
	add_child(host)
	st = host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.quests.set_stage("MQ-101", 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 3)
	st.vars.set_v("PC_CAPS", 600)
	st.vars.set_v("PC_CH", 6 if route == "fee" else 5)
	st.vars.set_v("PC_SKP_SNEAK", 40 if route == "vent" else 0)
	st.vars.set_v("PC_SKP_SCIENCE", 50 if route == "job" else 40)
	Wanted.add(st, 10)
	for kv in [["W-002", 1], ["10mm 탄", 120], ["I-001", 6]]:
		st.call_fn("give", kv)
	host.body = "adult"
	host.hud_on = true
	host.date_text = "2277. 10. 25.  13:10"
	paths = Act1Paths.new()
	add_child(paths)
	paths.setup(host, true)
	mq106 = Mq106.new()
	add_child(mq106)
	mq106.setup(host, true)
	side = SideR01.new()
	add_child(side)
	side.setup(host, true)
	side2 = SideS02.new()
	add_child(side2)
	side2.setup(host, true)
	side4 = SideS04.new()
	add_child(side4)
	side4.setup(host, true)
	side3 = SideS03.new()
	add_child(side3)
	side3.setup(host, true)
	side5 = SideS05.new()
	add_child(side5)
	side5.setup(host, true)
	side6 = SideS06.new()
	add_child(side6)
	side6.setup(host, true)
	side8 = SideS08.new()
	add_child(side8)
	side8.setup(host, true)
	side9 = SideS09.new()
	add_child(side9)
	side9.setup(host, true)
	side10 = SideS10.new()
	add_child(side10)
	side10.setup(host, true)
	side11 = SideS11.new()
	add_child(side11)
	side11.setup(host, true)
	side12 = SideS12.new()
	add_child(side12)
	side12.setup(host, true)
	side13 = SideS13.new()
	add_child(side13)
	side13.setup(host, true)
	jc01 = FqJc01.new()
	add_child(jc01)
	jc01.setup(host, true)
	fqgs = FqGs.new()
	add_child(fqgs)
	fqgs.setup(host, true)
	fqjh = FqJh.new()
	add_child(fqjh)
	fqjh.setup(host, true)
	fqjh3 = FqJh3.new()
	add_child(fqjh3)
	fqjh3.setup(host, true)
	fqsb = FqSb.new()
	add_child(fqsb)
	fqsb.setup(host, true)
	cara = Caravans.new()
	add_child(cara)
	cara.setup(host)
	uq71 = Uq71.new()
	add_child(uq71)
	uq71.setup(host, true)
	u02 = U02Paths.new()
	add_child(u02)
	u02.setup(host, true)
	uq04 = Uq04.new()
	add_child(uq04)
	uq04.setup(host, true)
	uq_r01 = UqR01.new()
	add_child(uq_r01)
	uq_r01.setup(host, true)
	rq = RqR01.new()
	add_child(rq)
	rq.setup(host, true)
	var bjs := BjStop.new()
	add_child(bjs)
	bjs.setup(host, true)
	uq_r02 = UqR02.new()
	add_child(uq_r02)
	uq_r02.setup(host, true)
	gr = Gr.new()
	add_child(gr)
	gr.setup(host, true)
	kt = Kt.new()
	add_child(kt)
	kt.setup(host, true)
	ga = Ga.new()
	add_child(ga)
	ga.setup(host, true)
	ks = Ks.new()
	add_child(ks)
	ks.setup(host, true)
	hosp = Hp.new()
	add_child(hosp)
	hosp.setup(host, true)
	yt = Yt.new()
	add_child(yt)
	yt.setup(host, true)
	u04 = U04.new()
	add_child(u04)
	u04.setup(host, true)
	stash = Stash.new()
	add_child(stash)
	stash.setup(host, true)
	host.combat.player_down.connect(host.on_pc_down)                  # 쓰러짐 → 생포 판정(진짜 진행 prologue와 같은 연결)
	host.combat.equip("W-002", st)
	match route:
		"job":
			host.enter("J-01", "from_W")
			plan = [["go", 14, 11], ["want", ["출입세를 낸다"]], ["go", 14, 13], ["check", "MQ103_GATE == 1 and MQ103_STAGE == 20", "출입세 → 단계 20"],
				["shot", "toll"],
				["go", 14, 18], ["go", 14, 19], ["go", 20, 6, "J-02"], ["go", 39, 13, "J-02"], ["go", 39, 15, "J-02"],
				["want", ["마영식", "무슨 일이든"]], ["talk", "C-050"], ["check", "MQ103_JOB == 1", "상인회 일 맡음"],
				["go", 19, 4, "J-03"], ["go", 19, 0, "J-03"], ["go", 4, 4, "J-02"], ["go", 4, 0, "J-02"],
				["want", ["같이 가자"]], ["talk", "C-018"], ["check", "MQ103_HIRE == 1", "박춘삼 고용(50캡)"],
				["go", 14, 18, "J-01"], ["go", 14, 19, "J-01"], ["go", 39, 14, "J-02"], ["go", 39, 15, "J-02"],
				["go", 19, 27, "J-03"], ["go", 19, 29, "J-03"], ["go", 60, 5, "J-09"], ["fight"], ["shot", "nest"],
				["check", "MQ103_NEST == 1 and MQ103_JOB == 2", "둥지 비움"],
				["loot", "청소부의 유해"],
				["go", 65, 3, "J-09"], ["go", 65, 0, "J-09"], ["want", ["(인사만"]], ["talk", "C-050"],
				["check", "has(\"M-078\") and JM_REG == 1 and MQ103_STAGE == 30", "출입패·단골·단계 30"],
				["go", 27, 4, "J-03"], ["go", 27, 3, "J-03"], ["check", "MQ103_DOOR == 1", "출입패로 문 열림"], ["go", 27, 0, "J-03"],
				["want", ["핍-보이를 내민다", "어떻게 아느냐", "회선 이야기"]], ["talk", "C-006"], ["shot", "ma"],
				["check", "K_CODE == 1 and K_NET == 1 and has(\"M-207\")", "해독(K_CODE·K_NET·메모)"],
				["check", "K_LINE == 1 and has(\"M-206\") and has(\"M-232\") and MQ103_STAGE == 100", "고백(시공 일지·사양서)"],
				["go", 11, 17, "J-06"], ["go", 19, 0, "J-03"], ["go", 4, 0, "J-02"], ["go", 14, 15, "J-01"], ["fight"], ["shot", "ambush"],
				["check", "MQ103_AMBUSH == 2", "북쪽 출구 매복을 이겼다"], ["check", "MQ102_STAGE == 100", "MQ-102 닫힘"]]
		"vent":
			host.enter("J-09", "from_W")
			plan = [["check", "MQ103_STAGE == 20 and MQ103_GATE == 3", "구청역 통로로 들어옴"], ["go", 10, 5], ["fight"],
				["go", 40, 3], ["want", ["소리 없이"]], ["use", 40, 2], ["check", "MQ103_SNEAK == 1 and MQ103_STAGE == 30", "환풍구(은신 50)"],
				["shot", "vent"], ["want", ["핍-보이를 내민다", "고맙다"]], ["talk", "C-006"],
				["check", "K_CODE == 1 and has(\"M-207\")", "해독"], ["go", 11, 17, "J-06"], ["check", "MQ103_STAGE == 100", "배전실을 나서면 끝"]]
		"hack":
			host.enter("J-02", "from_mall")
			plan = [["check", "MQ103_STAGE == 20 and MQ103_GATE == 4", "역사 쇼핑몰로 들어옴(출입세 없음)"],
				["go", 39, 14], ["go", 39, 15], ["go", 28, 4, "J-03"], ["go", 28, 3, "J-03"], ["use", 28, 2], ["hack"], ["shot", "hack"],
				["check", "MQ103_DOOR == 2", "출입 단말 해킹 → 문 열림"], ["go", 27, 3, "J-03"], ["go", 27, 0, "J-03"],
				["want", ["핍-보이를 내민다", "고맙다"]], ["talk", "C-006"], ["check", "K_CODE == 1", "해독"]]
		"fee":
			host.enter("J-01", "from_W")
			plan = [["go", 14, 11], ["want", ["피부 좋은"]], ["go", 14, 13], ["check", "MQ103_GATE == 2", "카리스마 6 농담으로 통과"],
				["go", 14, 18], ["go", 14, 19], ["go", 20, 6, "J-02"], ["go", 39, 13, "J-02"], ["go", 39, 15, "J-02"],
				["want", ["마영식", "면담료"]], ["talk", "C-050"], ["check", "has(\"M-078\") and PC_CAPS <= 300", "면담료 300 → 출입패"],
				["go", 27, 4, "J-03"], ["go", 27, 3, "J-03"], ["go", 27, 0, "J-03"],
				["want", ["핍-보이를 내민다", "어떻게 아느냐", "직접 깔았죠"]], ["talk", "C-006"],
				["check", "K_CODE == 1 and (MQ103_CONF == 1 or MQ103_CONF == 2)", "해독 + 화술 판정(성공·실패 둘 다 길이 있다)"]]
		"hub":                                                          # MQ-102 허브: 잠든 파수(월드 발견 자리) → 구울 행상 주성호(단서 1) → 하숙자(단서 2)
			st.vars.set_v("MQ101_RAD", 1)
			st.vars.set_v("MQ101_RESULT", 1)                             # 계단 방어로 마친 봉천 — 주민 소문 확인
			host.enter("W", "L-R01-32")
			var sen := _spot_find("L-R01-32", "sentry")
			plan = [["go", sen.x, sen.y + 3], ["shoton", "판독", "sentry_lit"], ["go", sen.x, sen.y + 1],
				["check", "MQ102_ROBOT == 1 and MQ102_STAGE == 10", "잠든 파수가 깨어났다 꺼짐"],
				["use", sen.x, sen.y], ["shot", "sentry_after"],
				["go", 891, 1381], ["go", 891, 1378], ["go", 894, 1374], ["want", ["읽을 사람"]], ["talk", "N-R02-018"],
				["check", "MQ102_C1 == 1 and MQ103_STAGE == 10", "구울 행상 → 단서 1(MQ-103 열림)"],
				["shoton", "*", "rumor"], ["talk", "N-R01-030"], ["wait", 3.0], ["check", "seen_rumor", "이름 없는 봉천 주민이 행적 소문을 한다"],
				["go", 884, 1365], ["go", 884, 1364], ["go", 7, 7, "B-03"], ["want", ["깨진 숫자 줄"]], ["talk", "C-057"], ["shot", "hasukja"],
				["check", "MQ102_C2 == 1 and MQ104_STAGE == 10", "하숙자 옛 여의도 지도 → 단서 2(MQ-104 열림)"]]
		"poi":                                                          # 길 위 발견물(1-4f): 쪽지 읽기 → 떠돌이 유해 열기(용기 창) · 대피소 표지
			host.enter("W", "L-R01-15")
			host.player.loco.place(Vector2(806 * 32 + 16, 1381 * 32 + 16))
			# 발견물 자리는 굽기가 정한다(지형을 다시 구우면 몇 칸씩 옮겨진다) — 좌표를 박지 않고 pois.json에서 가장 가까운 것을 찾는다
			var note := _poi_at("texts", "충전소", Vector2i(806, 1383))
			var body := _poi_at("boxes", "떠돌이의 유해", note)
			var evac := _poi_at("texts", "대피소 표지", Vector2i(806, 1337))
			var sn := _stand(note)
			var sb := _stand(body)
			var se := _stand(evac)
			host.player.loco.place(Vector2(sn.x * 32 + 16, sn.y * 32 + 16))   # 시작 칸도 굽기가 정한 쪽지 옆(다시 구우면 건물이 옮겨진다 — 1-11g)
			plan = [["shoton", "충전소", "note"], ["go", sn.x, sn.y], ["use", note.x, note.y], ["wait", 2.0],
				["go", sb.x, sb.y], ["use", body.x, body.y], ["wait", 1.0], ["shot", "remains_box"],
				["check", "container_open", "떠돌이 유해 → 용기 창이 열린다"], ["close"],
				["go", se.x, se.y], ["shoton", "대피소", "evac"], ["use", evac.x, evac.y], ["wait", 2.0],
				["check", "seen_evac", "대피소 표지 글이 뜬다"]]
		"north":                                                        # 1-7c R01 북쪽 탐험 묶음: 학원가(손재석 문항집 · 10번) → 흑석 병원(간호 7호 붕대) → 수산시장 → 국립묘지 대장 → 상도 빌라 LR-06
			st.vars.set_v("V_Q10", 4)                                    # 볼트 10번에 '문을 열고 밖을 본다'를 고른 주인공
			host.enter("W", "L-R01-24")
			var d24 := _door("K-24")
			plan = [["go", d24.x, d24.y + 1], ["shot", "k24_door"], ["use", d24.x, d24.y], ["wait", 2.0], ["shot", "k24"],
				["go", 9, 7, "K-24"], ["want", ["무슨 수업", "풀어 보자", "가장 가까운 지하", "판독기 앞에 정지", "신고한다", "10번은?", "볼트 시험엔 10번"]],
				["shoton", "점수 없는 답", "son_q10"], ["talk", "N-R01-056"], ["wait", 1.0],
				["check", "PN_Q10 == 1 and PN_SON == 2 and has(\"M-439\") and K_Q10 == 0", "손재석: 문항집(M-439 — 1-12i)에 10번이 없다(보조 단서만, K_Q10은 그대로)"],
				["warp", "K-26"], ["wait", 1.5], ["shot", "k26"], ["fight"],
				["go", 23, 8, "K-26"], ["want", ["!붕대를 갈아", "됐다"]], ["shoton", "관리 후보", "nurse"], ["talk", "N-R01-058"], ["wait", 1.0],
				["check", "PN_NURSE == 1 and PN_HEAL_DAY == GAME_DAY", "간호 7호: 등록 판독 · 오늘 붕대"],
				["warp", "W", "L-R01-25"], ["wait", 1.5], ["go", _spot_o("L-R01-25").x + 6, _spot_o("L-R01-25").y + 6], ["want", ["!저 냉동고는", "됐다"]], ["shoton", "원자력 냉동고", "market"],
				["talk", "N-R01-057"], ["wait", 1.0], ["check", "PN_SIM == 1", "수산시장 경매사 심도겸"],
				["warp", "W", "L-R01-22"], ["wait", 1.5], ["go", _spot_o("L-R01-22").x + 5, _spot_o("L-R01-22").y + 6], ["want", ["!인수 대장을", "됐다"]], ["shoton", "인수 대장", "cemetery"],
				["talk", "N-R01-052"], ["wait", 1.5], ["check", "read:K-22-LEDGER", "길덕수의 귀환 유해 인수 대장"],
				["warp", "W", "L-R01-27"], ["wait", 1.5], ["go", _spot_o("L-R01-27").x + 4, _spot_o("L-R01-27").y + 4], ["shoton", "금색 봉투", "villa"], ["use", _spot_o("L-R01-27").x + 4, _spot_o("L-R01-27").y + 3], ["wait", 2.0],
				["check", "read:LR-06", "무너진 빌라의 국가 유공 통지서(LR-06)"]]
		"bw":                                                           # 1-11a SQ-S01: 엄태경 → 남솔 밥 당번 → 백구 동행 → 해 질 녘 바위굴 대치 → 바닥 인식표 → 살펴보기 → 조담희
			st.call_fn("give", ["I-038", 1])
			host.date_text = "2277. 10. 25.  16:40"
			host.enter("X-BC", "from_X-S07")
			plan = [["want", ["!쇠붙이", "됐다"]], ["talk", "N-R01-033"], ["wait", 1.0], ["check", "SQS01_STAGE == 10", "엄태경: '외눈 목에 쇠붙이' — 단계 10"],
				["want", ["그릇"]], ["talkd", "N-R01-034"], ["wait", 1.0], ["check", "SQ_S01_FEED == 1 and has(\"I-038\") == 0", "남솔의 밥 당번(멧돼지 고기)"],
				["talkd", "C-015"], ["wait", 1.0], ["check", "SQ_S01_DOG == 1", "백구가 따라나선다"],
				["settime", "2277. 10. 25.  17:20"], ["warp", "X-BW", "arrive"], ["wait", 1.0], ["shot", "bw_arrive"],
				["gomark", "X-BW:baek_face"], ["until", "SQS01_STAGE >= 20", 5.0, "바위굴 반경 20칸 — 단계 20"],
				["until", "side:stand", 25.0, "해 질 녘 · 백구 동행 · 외눈 8칸 안 — 대치", "bw_standoff"],
				["chase"], ["until", "SQ_S01_SOL == 2 and SQ_S01_LEFT == 1", 20.0, "들개 둘을 쫓아 무리가 흩어진다(해법 B)", "bw_scatter"],
				["gotag"], ["until", "has(\"M-158\")", 30.0, "바닥의 인식표를 주웠다"], ["examine", "M-158"], ["wait", 1.0],
				["check", "SQS01_STAGE == 40", "살펴보기: 봉천 106동(40)"],
				["warp", "X-BC", "from_X-S07"], ["wait", 1.0], ["check", "SQ_S01_DOG == 3", "봉천에 돌아오자 백구가 개집으로"],
				["check", "SQ_S01_BC == 0", "해법 몫 봉천 +5가 이제 반영"],
				["want", ["드릴게요"]], ["shoton", "백, 설", "bw_jo"], ["talkd", "N-R01-029"], ["wait", 1.5],
				["check", "SQH_TAG == 81 and SQS01_STAGE == 100 and has(\"M-189\")", "조담희에게 건넴 — 백설이 사진 · 종료"]]
		"bs":                                                           # 1-11b SQ-S02: 쪽지 → 조수안 → 밸브실 관로 지도 → 수금원에게 물값(E) → 우회 관로 지도 → 계곡 이음 지점 둘(B) → 사례
			for kv in [["M-010", 4], ["M-025", 2]]:
				st.call_fn("give", kv)
			st.vars.set_v("PC_SKP_REPAIR", 40)
			host.date_text = "2277. 10. 26.  10:00"
			side2.tick()
			st.vars.set_v("GAME_DAY", 5)
			side2._on_day(5)
			host.enter("X-BS", "arrive")
			plan = [["wait", 1.0], ["shot", "bs_yard"], ["want", ["됐어"]], ["talk", "N-R01-032"], ["wait", 1.0],
				["check", "SQS02_STAGE == 10 and SQ_S02_HEARD == 1", "조수안: '상류 밸브가 또 잠겼어' — 단계 10"],
				["warp", "K-32", "from_X"], ["wait", 1.0], ["go", 6, 3, "K-32"], ["use", 6, 2], ["wait", 1.0], ["shot", "bs_k32"],
				["check", "SQS02_STAGE == 20", "밸브실 관로 계통도 — 단계 20"],
				["settime", "2277. 10. 26.  14:00"], ["want", ["낸다"]], ["warp", "X-SS", "arrive"], ["wait", 1.0],
				["until", "SQ_S02_OPEN == 2", 20.0, "수금원: 물값 30캡 — 사흘 흐른다(해법 E)", "bs_toll"],
				["check", "SQS02_STAGE == 30 and SQ_S02_LEVEL == 5", "밸브 반경 30칸(단계 30) · 물값 기간 수위 다섯 칸"],
				["warp", "X-BS", "arrive"], ["wait", 1.0], ["want", ["싸우지 않고", "됐어"]], ["talk", "N-R01-032"], ["wait", 1.0],
				["check", "SQ_S02_PIPEMAP == 1", "조수안의 옛 관로 지도"],
				["warp", "K-08"], ["wait", 1.5], ["go", 30, 4, "K-08"], ["want", ["덧대고"]], ["use", 30, 3], ["wait", 1.0],
				["check", "SQ_S02_J1 == 1", "첫 이음 지점"], ["go", 37, 4, "K-08"], ["want", ["덧대고"]], ["use", 37, 3], ["wait", 1.0], ["shot", "bs_joint"],
				["check", "SQ_S02_B == 1 and SQS02_STAGE == 70 and SQS03_STAGE >= 10", "해법 B 우회 관로 — 단계 70 · SQ-S03 자동 발동(암거 안이면 바로 40)"],
				["warp", "X-BS", "arrive"], ["wait", 1.0], ["talk", "N-R01-032"], ["wait", 1.5],
				["check", "SQ_S02_REWARD == 1 and has(\"I-056\")", "조수안 사례: 관악산 약수 ×5 + 100캡"]]
		"s3":                                                           # 1-11d SQ-S03: 저수조 벽(20) → 암거 쥐 무리 · 왕쥐(40) → 정비공 측정지(50) → 갱도 수문 닫음(60) → 정문 인터컴 측정지 수치(C · 70) → 조수안 보고(100)
			st.vars.set_v("PC_ST", 7)
			host.date_text = "2277. 10. 27.  10:00"
			host.enter("X-BS", "tanks")
			plan = [["wait", 1.0], ["shot", "s3_wall"], ["scene", "SQS03_WALL"], ["wait", 2.0], ["check", "SQS03_STAGE == 20", "저수조 이음 벽 — 볼트 회의 기억(20)"],
				["warp", "K-08", "from_W"], ["wait", 1.5], ["check", "SQS03_STAGE == 40 and SQ_S03_KING == 1", "암거에 들어섬(40) · 왕쥐가 선다"],
				["hp", 9999], ["fight"], ["shot", "s3_k08"], ["check", "SQ_S03_KING == 2", "왕쥐를 쓰러뜨림(다시 서지 않는다)"],
				["go", 44, 5, "K-08"], ["use", 44, 4], ["wait", 2.0], ["check", "has(\"M-302\") and SQS03_STAGE == 50", "정비공 유해의 측정지(50)"],
				["warp", "E-01", "from_W"], ["wait", 1.5], ["fight"], ["go", 23, 5, "E-01"], ["want", ["온몸으로"]], ["use", 24, 5], ["wait", 2.0], ["shot", "s3_gate"],
				["check", "SQ_S03_GATE == 2 and SQS03_STAGE == 60", "갱도 중간 수문을 닫음(60)"],
				["warp", "X-S07", "from_vault"], ["wait", 1.0], ["want", ["누른다"]], ["scene", "SQS03_INTERCOM"], ["wait", 2.0],
				["want", ["누른다", "수치를 읽어", "끊는다"]], ["scene", "SQS03_INTERCOM"], ["wait", 5.0], ["shot", "s3_intercom"],
				["check", "SQ_S03_SOL == 3 and SQR_S03 == 3 and SQS03_STAGE == 70", "방금례에게 측정지 수치 — 원인 차단(C · 70 · 4막 이월)"],
				["warp", "X-BS", "arrive"], ["wait", 1.0], ["talk", "N-R01-032"], ["wait", 2.0],
				["check", "SQS03_STAGE == 100 and SQ_S03_REWARD == 1", "조수안 보고(100) · 사례 · 꼭지 필터"]]
		"s5":                                                           # 1-11e SQ-S05 A: 밤 철망 문(성지후 경고 · 20) → 서쪽 터널(40) → 파수-3 끌기 → 역무실 방송 → 낙성대 행렬(A · 50) → 허순자 보고(100)
			st.vars.set_v("PC_ST", 6)
			st.vars.set_v("PC_SKP_REPAIR", 30)
			host.date_text = "2277. 10. 27.  22:00"
			host.enter("D-06", "from_U01")
			plan = [["wait", 1.0], ["want", ["들어간다"]], ["scene", "SQS05_GATE"], ["until", "map:U-01", 15.0, "철망 문 — 성지후 경고 뒤 서쪽 터널로", "s5_gate"],
				["wait", 1.5], ["check", "SQS05_STAGE == 40 and SQ_S05_GATE == 1", "철망 문 경고(20) · 터널에 들어섬(40)"], ["shot", "s5_tunnel"],
				["hp", 9999], ["crouch", true], ["want", ["끌고"]], ["scene", "SQS05_ROBOT"], ["wait", 2.0], ["crouch", false],
				["check", "SQ_S05_ROBOT == 2", "파수-3을 역무실로 끌어감(삼십 분)"],
				["warp", "D-03", "from_D-02"], ["wait", 1.0], ["shot", "s5_office"], ["want", ["케이블"]], ["scene", "SD_BROADCAST"], ["wait", 2.0],
				["check", "SQ_S05_BCAST == 1 and SQS05_STAGE == 40", "역무실 방송 — 매시 정각"],
				["warp", "U-02", "from_E"], ["wait", 4.0], ["shot", "s5_line"], ["wait", 7.0], ["shot", "s5_line2"],
				["until", "SQ_S05_EMPTY == 1", 90.0, "행렬: 손님들이 한 줄로 측선에 들어간다", "s5_line_end"],
				["check", "SQ_S05_SOL == 1 and SQ_S05_ENT == 10 and SQS05_STAGE == 50", "해법 A — 열 명 모두 측선(50)"],
				["warp", "D-03", "from_D-02"], ["wait", 1.0], ["want", ["서쪽 터널이 비었어요"]], ["talk", "N-R01-041"], ["wait", 2.0],
				["check", "SQS05_STAGE == 100 and SQ_S05_REPORT == 1 and has(\"M-071\")", "허순자 보고(100) · 정기권 · 노선도 서쪽 칸"]]
		"s6":                                                           # 1-11f SQ-S06 B: 탄약고 진해원(20) → 밥 · 평상복 · 등록증 → 시흥 고개 위로(호위) → 다리목 검문(판독기) → 노들섬 남문(반검문 · 100)
			for kv in [["A-005", 1], ["M-062", 1], ["I-031", 1]]:
				st.call_fn("give", kv)
			host.date_text = "2277. 10. 27.  10:00"
			host.enter("Q-30", "from_X")
			plan = [["wait", 1.0], ["shot", "s6_bunker"], ["want", ["어디로", "노들섬까지"]], ["talk", "N-R01-064"], ["wait", 2.0],
				["check", "SQ_S06_JIN == 1 and SQS06_STAGE == 20", "탄약고에서 만남(20) — 호위 시작"],
				["want", ["할 말이 있어", "먹을 거"]], ["mate", "N-R01-064"], ["wait", 1.0],
				["want", ["할 말이 있어", "이 옷으로"]], ["mate", "N-R01-064"], ["wait", 1.0],
				["want", ["할 말이 있어", "등록증"]], ["mate", "N-R01-064"], ["wait", 1.0], ["shot", "s6_civvy"],
				["check", "SQ_S06_FED == 1 and SQ_S06_CLOTH == 1 and SQ_S06_PAPERS == 1 and has(\"A-031\")", "밥 · 평상복 · 등록증 — 전투복은 주인공 손에"],
				["warp", "X-SH", "from_Q-30"], ["wait", 1.5], ["gomark", "X-SH:s1"], ["wait", 1.0], ["shot", "s6_post"],
				["check", "SQ_S06_JIN == 1", "시흥 고개 초소 위로 — 진해원이 따라 나온다"],
				["warp", "X-SH", "@965,1163"], ["wait", 1.5], ["go", 965, 1157], ["until", "SQ_S06_CHECK == 3", 20.0, "다리목 검문 — 판독기 삑(등록증 통과)", "s6_check"],
				["wait", 1.0], ["want", ["견습"]], ["go", 966, 1145], ["until", "SQ_S06_JIN == 3", 40.0, "노들섬 남문 — 하다현이 등록증을 밀어낸다", "s6_gate"],
				["wait", 2.0], ["shot", "s6_after"],
				["check", "SQ_S06_SOL == 2 and SQS06_STAGE == 100 and SQE_DESERTER == 1 and has(\"M-185\")", "해법 B — 노들섬(100) · 군번줄 · MQ-502 증인"]]
		"s8":                                                           # 1-11g SQ-S08 A: 광장 두 번째 방문 다툼(10) → 구청 번호표 · 한 시간 대기 → 위동현이 0413 호출(40 · 50) → 수리공 화술 · 짐꾼 사진 → 이름 돌려주기(100)
			st.vars.set_v("PC_SKP_SPEECH", 90)
			host.date_text = "2277. 10. 27.  10:00"
			host.enter("J-03", "from_J-02")
			plan = [["wait", 1.0], ["warp", "J-02", "from_J-03"], ["wait", 0.5], ["warp", "J-03", "from_J-02"], ["wait", 1.0], ["go", 18, 9],
				["until", "SQ_S08_SAW == 1", 20.0, "광장 두 번째 방문 — 두 김민수의 다툼(10)", "s8_quarrel"], ["wait", 2.0],
				["check", "SQS08_STAGE == 10", "다툼을 보면 10"],
				["warp", "K-15", "from_W"], ["wait", 1.0], ["shot", "s8_office"], ["go", 13, 6], ["use", 13, 5], ["wait", 1.0],
				["check", "SQ_S08_TICKET == 1", "번호표 0413"],
				["want", ["기다린다", "2077년 주민 기록"]], ["go", 15, 6], ["use", 15, 5],
				["until", "SQ_S08_DESK == 1", 30.0, "한 시간 대기 → 위동현이 0413번을 부른다", "s8_called"], ["wait", 2.0], ["shot", "s8_board"],
				["check", "SQ_S08_MATCH == 1 and SQS08_STAGE == 50", "배급 기록 사진 대조(50)"],
				["warp", "J-03", "from_J-02"], ["wait", 1.0], ["want", ["기록을 보여", "줄은 끝났어"]], ["talk", "N-R02-016"], ["wait", 2.0],
				["check", "SQ_S08_TOLD_B == 1", "수리공 — 봉재민(화술)"],
				["warp", "J-02", "from_J-03"], ["wait", 1.0], ["want", ["기록을 보여"]], ["talk", "N-R02-015"], ["wait", 2.0],
				["check", "SQ_S08_SOL == 1 and SQS08_STAGE == 100", "짐꾼 — 하경수 · 해법 A 이름 돌려주기(100)"],
				["warp", "J-03", "from_J-02"], ["wait", 1.5], ["shot", "s8_after"]]
		"s9":                                                           # 1-11h SQ-S09 B: 쪽방 할매 → 벽장 → 벽 사이 통로 판자 틈 속삭임(10 · 40) → 새벽 두 시 창고동 → 127번 칸 문 · 목걸이 → 길금순 칸 → '같이 가자' → 구로 107동 이름으로 재회(100)
			st.vars.set_v("PC_SKP_LOCKPICK", 30)
			st.vars.set_v("PC_SKP_REPAIR", 60)
			st.quests.set_stage("MQ-103", 20)
			host.date_text = "2277. 10. 27.  01:40"
			host.enter("K-23", "from_K-20")
			plan = [["wait", 1.0], ["go", 28, 4], ["use", 29, 4], ["wait", 2.0], ["shot", "s9_crack"],
				["check", "SQ_S09_CRACK == 1 and SQS09_STAGE == 40", "판자 틈 — 127번 말고 채윤재(10 → 40)"],
				["warp", "H-03", "from_tunnel"], ["wait", 1.0], ["settime", "2277. 10. 27.  02:20"], ["go", 10, 9], ["want", ["자물쇠 따기"]], ["use", 10, 8], ["wait", 2.0],
				["check", "SQ_S09_DOOR == 1 and SB_RAID == 0", "새벽 두 시 — 문만 열림(목걸이부터)"], ["shot", "s9_door"],
				["want", ["수리 50"]], ["use", 10, 8], ["wait", 2.0],
				["check", "SB_127 == 2 and SQ_S09_SOL1 == 2 and SQS09_STAGE == 50", "목걸이 → 판자 틈으로(해법 B · 50)"],
				["warp", "K-20", "from_K-23"], ["wait", 1.0], ["shot", "s9_room"], ["want", ["같이 가자", "채윤재", "지하시장"]], ["talk", "N-R02-039"],
				["until", "map:K-22", 20.0, "같이 가자 — 화면 전환 뒤 구로 107동", "s9_home"], ["wait", 5.0], ["shot", "s9_reunion"],
				["check", "SQ_S09_PLACE == 3 and SQS09_STAGE == 100", "이름으로 재회 · 지하시장 정착(100)"]]
		"s10":                                                          # 1-11i SQ-S10 A: 22번 칸 문(발동 · 진술 10) → 경매일 09시 고척 · 견적 패 → 귀빈석 예산 600(30) → 10시 박자 입찰 650 낙찰 · 계약서(100)
			st.vars.set_v("PC_CAPS", 2000)
			st.vars.set_v("PC_SKP_BARTER", 60)
			st.vars.set_v("GAME_DAY", 4)
			host.date_text = "2277. 10. 26.  14:00"
			host.enter("H-03", "from_yard")
			plan = [["wait", 1.0], ["go", 22, 9], ["want", ["기씨 집이라니", "기다려"]], ["use", 22, 8], ["wait", 2.0], ["shot", "s10_cage"],
				["check", "SQ_S10_START == 4 and SQ_S10_TOLD == 1 and SQS10_STAGE == 10", "22번 칸 문 — 88번 기라희 · 할머니 이야기(10)"],
				["setv", "GAME_DAY", 6], ["settime", "2277. 10. 28.  09:10"], ["warp", "GD-01", "from_W"], ["wait", 2.0],
				["check", "SQ_S10_KIRA == 1 and SQ_S10_SEO == 1", "06시 고척 지하로 이송 · 09시 귀빈석 실루엣"], ["shot", "s10_ground"],
				["want", ["구매자 패", "보증금을 낸다", "됐어"]], ["talk", "N-R02-043"], ["wait", 1.0], ["check", "SQ_S10_PADDLE == 1", "견적에게 7번 패(보증금 100)"],
				["warp", "GD-02", "from_GD-01"], ["wait", 1.0], ["shot", "s10_vip"], ["want", ["물물교환 50", "그만둔다"]], ["talk", "N-R02-044"], ["wait", 1.0],
				["check", "SQ_S10_BUDGET == 1 and SQS10_STAGE == 30", "귀빈석 — 예산 600을 털어놓음(30)"],
				["warp", "GD-01", "from_GD-02"], ["wait", 1.0], ["want", ["!지켜본다", "!100 올린다", "!100 올린다", "!50 올린다", "계약서를 기라희에게"]],
				["settime", "2277. 10. 28.  10:00"],
				["until", "SQ_S10_KIRA == 3", 40.0, "10시 경매 — 박자 입찰 · 계약서", "s10_auction"], ["wait", 2.0], ["shot", "s10_free"],
				["check", "SQ_S10_PRICE == 650 and SQR_S10 == 1 and SQS10_STAGE == 100", "650 낙찰(예산 600 + 50) · 계약서를 건넴(100)"]]
		"s11":                                                          # 1-11j SQ-S11: 경찰서(파수가 깨어 막음 → 유치장 배관 우회 · 별첨 출력 30) → 기록관(의사록 · 서고 번호 · 원본 50) →
			st.vars.set_v("PC_SKP_SNEAK", 60)                            #   밤 8시 지하시장 인지영과 국회 앞 계단(낭독 a · 머리띠) → 우도하에게 원본(남산 a · 100)
			st.vars.set_v("PC_SKP_SPEECH", 60)
			st.vars.set_v("GAME_DAY", 4)
			host.date_text = "2277. 10. 26.  14:00"
			host.enter("K-29", "from_W")
			plan = [["wait", 1.0], ["want", ["물러난다"]], ["go", 6, 12], ["until", "SQ_S11_GUARD == 1", 10.0, "서장실 문 경비 파수-3이 깨어 막는다", "s11_guard"],
				["wait", 1.5], ["want", ["소리 없이"]], ["go", 16, 3], ["use", 16, 2], ["until", "SQ_S11_ATOFFICE == 1", 15.0, "유치장 점검구 → 서장실 서류함 뒤(은신 우회)", "s11_pipe"],
				["check", "SQ_S11_GUARD == 3", "배관 우회(파수는 문 앞 그대로)"], ["wait", 1.0], ["setv", "SQ_S11_REPORT", 1],
				["want", ["사본을 뽑는다"]], ["go", 6, 4], ["use", 6, 3], ["wait", 2.0], ["shot", "s11_print"],
				["check", "has(\"M-305\") and SQ_S11_PRINT == 1 and SQS11_STAGE == 30", "별첨 사망자 명단 출력(10 → 30)"],
				["warp", "KH-03", "from_KH-01"], ["wait", 1.0], ["shot", "s11_archive"],
				["want", ["!휴회 결의?", "!원본을 볼 수 있나", "지키는 사람이", "됐어"]], ["talk", "N-R02-027"], ["wait", 1.0],
				["check", "SQ_S11_STACK == 1 and SQS11_STAGE == 40", "의사록 — 제7 서고 번호 1021(40)"],
				["want", ["가져간다"]], ["go", 24, 10], ["go", 24, 6], ["use", 24, 5], ["wait", 1.5], ["shot", "s11_box"],
				["check", "has(\"M-306\") and SQS11_STAGE == 50", "휴회 결의 원본이 손에(50)"],
				["settime", "2277. 10. 26.  21:00"], ["warp", "J-03", "from_J-02"], ["wait", 1.0],
				["want", ["사망자 명단을 보여", "같이 가자"]], ["talk", "N-R02-014"], ["wait", 1.0],
				["check", "SQ_S11_ESCORT == 1", "인지영 — 밤에 국회 앞으로(호위)"],
				["warp", "W", "L-R02-01"], ["wait", 2.0], ["want", []], ["gomark", "kh_read"],
				["until", "SQ_S11_READ == 1", 40.0, "국회 정면 계단 — 열한 이름", "s11_read"], ["wait", 2.0], ["shot", "s11_leaves"],
				["check", "SQH_LIST11 == 4 and has(\"A-084\")", "명단 a 낭독 · 종전 행진 머리띠"],
				["warp", "K-06", "from_W"], ["wait", 1.0], ["want", ["여의도 기록", "휴회 결의 원본", "넘긴다"]], ["talk", "N-R02-026"], ["wait", 2.0],
				["until", "SQH_RECESS == 14", 10.0, "우도하 — '스스로 멈췄다'(원본 a)", "s11_woo"],
				["check", "SQR_S11 == 1 and SQS11_STAGE == 100", "두 기록이 자리를 찾았다(100)"]]
		"s12":                                                          # 1-11k SQ-S12: 벙커 Y-02 세 자리(신분증 거두기 · 반지 · 배급표 묶음 · 손목시계) → 살펴보기(발동) →
			st.vars.set_v("GAME_DAY", 6)                                 #   관리사무소 연락부(호수 따라가기 30) → 진재석 회의 탁자 · 엄수연 건넴(40) ·
			host.date_text = "2277. 10. 28.  10:00"                      #   사공민영 배급표 묶음(순회를 접음) · 강수아 장 맡기기 → 셋 모두(100)
			host.enter("Y-02", "from_Y-01")
			plan = [["wait", 1.0], ["want", ["거둔다", "편다"]], ["go", 16, 18], ["use", 16, 17], ["wait", 1.5], ["shot", "s12_seat"],
				["check", "has(\"M-210\") and has(\"M-412\") and MQ104_IDS == 1", "1조 맨 앞(입구 쪽) — 신분증 거두기 · 쥔 손의 반지"],
				["want", ["든다"]], ["go", 23, 11], ["use", 22, 11], ["wait", 1.0], ["want", ["푼다"]], ["go", 23, 8], ["use", 22, 8], ["wait", 1.0],
				["check", "has(\"M-413\") and has(\"M-414\")", "3조 셋째 배급표 묶음 · 3조 끝 23:29 손목시계"],
				["want", []], ["examine", "M-210"], ["wait", 2.0], ["check", "SQ_S12_START >= 1 and SQ_S12_EVID == 12", "살펴보기 — 뒷면 세 호수 · 발동"],
				["warp", "J-04", "from_J-03"], ["wait", 1.0], ["go", 3, 4], ["use", 2, 4], ["hack", 2], ["wait", 1.0],
				["check", "SQ_S12_LOOK == 1 and SQ_S12_J == 1 and SQ_S12_S == 1 and SQ_S12_E == 1", "연락부 — A-11 · B-04 · A-13 호수 따라가기"],
				["warp", "J-02", "from_J-03"], ["wait", 1.0], ["want", ["신분증", "회의 탁자", "다음에"]], ["talk", "N-R02-005"], ["wait", 1.0],
				["check", "SQ_S12_J == 4 and SQE_FAMILY == 1", "진재석 — '출석 부르듯이'(회의 탁자)"],
				["want", ["신분증", "건넨다", "손목시계", "다음에"]], ["talk", "N-R02-006"], ["wait", 1.0], ["shot", "s12_eom"],
				["check", "SQ_S12_E == 3 and SQ_S12_EW == 1 and SQ_S12_EVID == 11", "엄수연 — 이름을 손에(증거 11) · 23:29"],
				["warp", "J-03", "from_J-02"], ["wait", 1.0], ["want", ["배급표 묶음"]], ["talk", "N-R02-012"], ["wait", 1.5],
				["check", "SQ_S12_SB == 1 and has(\"M-003\")", "사공민영 — 그 달 배급표(순회를 접는다)"],
				["want", ["강수아", "회의 탁자", "다음에"]], ["talk", "N-R02-012"], ["wait", 1.5], ["shot", "s12_bench"],
				["check", "SQ_S12_S == 4 and SQ_S12_DONE == 1 and SQS12_STAGE == 100", "셋의 자리가 정해졌다(100)"]]
		"s13":                                                          # 1-11l SQ-S13: 아트리움(2호 첫 만남 · 등록증 · [과학 25] 방송 유인 30) → 지하시장 노복희 부탁(밤 열 시) →
			st.vars.set_v("PC_SKP_SCIENCE", 60)                          #   나머지 넷은 약속을 바로 세움(경상현 18 · 탁우빈 18 · 어하은 19 · 표강윤 19 — 같은 창) → 시계를 넘겨 다섯 도착(50) →
			st.vars.set_v("PC_SKP_SPEECH", 100)                          #   등록부 '내 이름'(40) → 2호 '투표를 시작하자' → 기표소 기호 1번 → 칸막이 다섯 → 개표실 4호 발표(60) → 명부 그대로(100)
			st.vars.set_v("GAME_DAY", 6)
			host.date_text = "2277. 10. 28.  10:00"
			host.enter("SV-01", "from_W")
			plan = [["hp", 3000], ["wait", 1.0], ["shot", "s13_atrium"], ["want", ["볼트 방송"]], ["talk", "N-R02-028"], ["wait", 1.5],
				["check", "SQ_S13_MET2 == 1 and SQ_S13_LURE == 1 and has(\"M-416\") and SQS13_STAGE == 30", "2호 — 등록증 · 방송 유인(30)"],
				["warp", "J-03", "from_J-02"], ["wait", 1.0], ["want", ["투표하러", "구울도 유권자"]], ["talk", "C-050"], ["wait", 1.5],
				["check", "SQ_S13_V_B == 1 and SQ_S13_T_B == 166", "노복희 — 장부 닫고 밤 열 시"],
				["setv", "SQ_S13_V_K", 1], ["setv", "SQ_S13_T_K", 162], ["setv", "SQ_S13_V_T", 1], ["setv", "SQ_S13_T_T", 162],
				["setv", "SQ_S13_V_E", 1], ["setv", "SQ_S13_T_E", 163], ["setv", "SQ_S13_V_P", 1], ["setv", "SQ_S13_T_P", 163],
				["warp", "SV-01", "from_W"], ["hours", 12], ["wait", 2.0],
				["until", "SQ_S13_HERE == 5", 10.0, "다섯 도착(18 · 18 · 19 · 19 · 22 — 6시간 창 안)", "s13_here"],
				["check", "SQS13_STAGE == 50", "50"],
				["want", ["내 이름"]], ["go", 12, 13], ["use", 12, 12], ["wait", 1.0], ["check", "SQ_S13_C1 == 1", "등록부 기호 1 = 주인공"],
				["want", ["투표를 시작하자"]], ["talk", "N-R02-028"], ["wait", 1.0], ["check", "SQ_S13_VOTING == 1", "투표 시작"],
				["want", ["기호 1번"]], ["go", 19, 19], ["use", 19, 18], ["wait", 1.0],
				["until", "SQ_S13_VOTING == 2", 30.0, "칸막이 다섯 — 마감", "s13_booth"],
				["warp", "SV-02", "from_SV01"], ["wait", 1.0], ["want", []], ["talk", "N-R02-029"], ["wait", 2.0], ["shot", "s13_count"],
				["check", "SQ_S13_VOTING == 3 and SQ_S13_WIN != 0 and SQS13_STAGE == 60", "4호 개표 발표(60)"],
				["warp", "SV-01", "from_SV02"], ["wait", 1.0], ["want", ["그대로", "그대로", "그대로", "그대로", "그대로"]], ["talk", "N-R02-028"], ["wait", 2.0],
				["until", "SQ_S13_DONE == 1", 10.0, "열쇠가 주인을 찾았다", "s13_done"],
				["check", "SQS13_STAGE == 100 and SQ_S13_LOOT == 1", "100 · 창고"]]
		"jc01":                                                         # 1-12a FQ-JC-01: 게시판 쪽지 · 빗물 당번표(10) → 이장실 조만석 → 백구 동행(20) → 홈통 → 아랫문 큰길 첫 갈림(백구가 판 자리) →
			st.vars.set_v("PC_ST", 7)                                    #   비탈 둘째 갈림 → 계곡 암거 둥지 쥐 · 흙막이 [힘 6] 다 메움(30) → 배수지 유입구 새는 소리(40) · [수리 50] →
			st.vars.set_v("PC_SKP_REPAIR", 60)                           #   조만석 보고(100) · 봉천 우호면 이장님의 엽총
			st.vars.set_v("AFF_JC_BC", 15)
			host.date_text = "2277. 10. 30.  09:00"
			jc01.tick()
			st.vars.set_v("GAME_DAY", 8)
			jc01._on_day(8)
			side2.tick()
			host.enter("X-BC", "from_X-S07")
			plan = [["hp", 3000], ["wait", 1.0], ["scene", "X-BC_BOARD"], ["wait", 1.5],
				["check", "FQJC01_STAGE == 10 and FQ_JC01_ROSTER == 1 and FQ_JC01_CAP == 3", "게시판 쪽지 · 빗물 당번표(10) · 빗물 몫 3"],
				["warp", "B-01", "from_X-BC"], ["wait", 1.0], ["want", ["가 볼게"]], ["talk", "C-010"], ["wait", 1.5], ["shot", "jc01_chief"],
				["check", "FQ_JC01_POSTED == 2", "조만석 — 윗관 · 아랫물 두 갈래"],
				["warp", "X-BC", "from_B-01"], ["wait", 1.0], ["want", ["가자"]], ["talkd", "C-015"], ["wait", 1.5],
				["check", "FQ_JC01_DOG == 1 and FQJC01_STAGE == 20", "백구 동행(20)"],
				["go", 888, 1373], ["scene", "FQJC01_SPOUT"], ["wait", 1.0], ["shot", "jc01_spout"],
				["want", ["판 자리"]], ["go", 887, 1408], ["wait", 2.0], ["shot", "jc01_fork1"],
				["check", "FQ_JC01_FORK1 == 1", "첫 갈림: 백구가 판 자리(남쪽 큰길)"],
				["want", ["백구를 따라"]], ["go", 885, 1469], ["wait", 2.0], ["shot", "jc01_fork2"],
				["check", "FQ_JC01_FORK2 == 1", "둘째 갈림: 비탈 아래 암거 입구"],
				["warp", "K-08", "from_W"], ["wait", 1.5], ["fight"], ["wait", 1.0],
				["check", "FQ_JC01_NEST == 1", "웅덩이 둥지 쥐 셋 처치"],
				["want", ["마대를 끌어내"]], ["go", 6, 5, "K-08"], ["use", 6, 4], ["wait", 2.0], ["shot", "jc01_dam"],
				["check", "FQ_JC01_FLOW == 1 and FQJC01_STAGE == 30", "흙막이 다 메움(30)"],
				["warp", "X-BS", "arrive"], ["wait", 1.0],
				["check", "FQ_JC01_LEAK == 1 and FQJC01_STAGE == 40 and SQ_S02_LEVEL == 4", "유입구 새는 소리(40) · 수위 넷"],
				["want", ["수리 50"]], ["go", 926, 1372], ["use", 926, 1371], ["wait", 1.5], ["shot", "jc01_inlet"],
				["check", "FQ_JC01_CRACK == 1", "유입구 균열 고침"],
				["warp", "B-01", "from_X-BC"], ["wait", 1.0], ["want", []], ["talk", "C-010"], ["wait", 2.0],
				["check", "FQJC01_STAGE == 100 and has(\"W-101\") and has(\"M-136\")", "보고(100) · 이장님의 엽총 · 계단마을 증표"]]
		"gs01":                                                         # 1-12b FQ-GS-01: 오상구 당번표(10) → 대기실 정비 카드 → 마당 1 · 2 · 4번 → 살림 ① 천 → 살림 ② 둥지 쥐 · 태그 →
			st.vars.set_v("AFF_GS", 25)                                  #   3번에 전원을 안 내리고 기름부터 → 깨어남 → [관리자 인증] → 오상구 보고(100) · 진공관 둘
			st.vars.set_v("PC_SKP_REPAIR", 60)                           #   (X-GS 원점 883,1183 — 월드 칸 = 원점 + 손 맵 칸)
			st.vars.set_v("V_REGCARD", 4)
			st.vars.set_v("GAME_DAY", 5)
			st.vars.set_v("GAME_HOUR", 7)
			host.date_text = "2277. 10. 28.  07:00"
			host.enter("X-GS", "arrive")
			plan = [["hp", 3000], ["wait", 1.0], ["go", 906, 1191], ["wait", 1.0], ["shot", "gs01_canopy"],
				["want", ["당번을 서겠습니다"]], ["talk", "N-R01-503"], ["wait", 1.5],
				["check", "FQGS01_STAGE == 10 and FQ_GS01_WARN == 1", "오상구 당번표(10) · '3번은 전원부터'"],
				["warp", "GS-01", "from_X"], ["wait", 1.0], ["want", ["정비 카드 여섯 장"]], ["go", 13, 13, "GS-01"], ["use", 13, 12], ["wait", 1.5], ["shot", "gs01_punch"],
				["check", "FQ_GS01_CARDS == 6", "정비 카드 여섯 장"],
				["warp", "X-GS", "from_GS-01"], ["wait", 1.0],
				["want", ["위에서 아래로"]], ["go", 888, 1200], ["use", 888, 1199], ["wait", 1.5],
				["want", ["분필 글씨는 남기고"]], ["go", 892, 1201], ["use", 892, 1200], ["wait", 1.5],
				["want", ["태그 없이"]], ["go", 902, 1201], ["use", 902, 1200], ["wait", 1.5],
				["check", "FQ_GS01_R1 == 1 and FQ_GS01_R2 == 1 and FQ_GS01_R4 == 1 and FQGS01_STAGE == 20", "마당 1 · 2 · 4번(20)"],
				["want", ["천을 풀어", "번호 순서대로"]], ["go", 907, 1189], ["use", 907, 1188], ["wait", 1.5],
				["check", "FQ_GS01_R5 == 2", "살림 ① 천을 풀고 다시 감음"],
				["want", ["뚜껑을 연다"]], ["go", 908, 1189], ["use", 908, 1188], ["wait", 1.5], ["fight"], ["wait", 1.0],
				["want", ["둥지를 쓸어", "집진통을 닦고"]], ["go", 908, 1189], ["use", 908, 1188], ["wait", 1.5],
				["check", "FQ_GS01_R6 == 3 and has(\"M-418\") and FQ_GS01_PAPER == 1", "살림 ② 둥지 쥐 · 4번 태그 · 2077 청소 확인서"],
				["want", ["닦고, 관절에 기름", "관리자 인증"]], ["go", 905, 1189], ["use", 905, 1188], ["wait", 3.0], ["shot", "gs01_wake"],
				["check", "FQ_GS01_R3 == 2 and FQGS01_STAGE == 30", "3번이 깨어남 → [관리자 인증](30)"],
				["want", []], ["talk", "N-R01-503"], ["wait", 2.0], ["shot", "gs01_done"],
				["check", "FQGS01_STAGE == 100 and has(\"M-014\")", "오상구 보고(100) · 진공관"]]
		"gs02":                                                         # 1-12b FQ-GS-02: 학원 K-24 자습석 한 시간 → 원장 대행이 원장실 옆문을 엶 → 채점기 [수리 50] 바늘 →
			st.vars.set_v("AFF_GS", 25)                                  #   중계소 류정 '…벌써요?' → 바늘 건넴(100) → 대기실 등록용 천공기가 다시 돈다
			st.vars.set_v("PC_SKP_REPAIR", 60)
			st.vars.set_v("GS_MET_RJ", 1)
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("GAME_HOUR", 13)
			host.date_text = "2277. 10. 29.  13:00"
			host.enter("K-24", "from_W")
			plan = [["hp", 3000], ["wait", 1.0], ["calm"], ["go", 18, 12, "K-24"], ["wait", 1.0], ["shot", "gs02_door"],
				["want", ["자습석에 앉아"]], ["go", 3, 13, "K-24"], ["use", 3, 12], ["wait", 2.0],
				["check", "FQ_GS02_DOOR == 1 and FQ_GS02_SAT == 1", "자습 한 시간 → 원장실 면담(옆문)"],
				["go", 24, 12, "K-24"], ["wait", 1.0], ["shot", "gs02_office"],
				["want", ["바늘 뭉치만"]], ["go", 29, 4, "K-24"], ["use", 29, 3], ["wait", 1.5], ["shot", "gs02_grader"],
				["check", "GS02_GRADER == 2 and has(\"M-420\")", "채점기 바늘 분리(P1 GS02_GRADER 2)"],
				["warp", "GS-02", "from_X"], ["wait", 1.0], ["want", ["천공 바늘 묶음을 건넨다", "됐습니다"]], ["talk", "C-014"], ["wait", 2.0],
				["check", "FQGS02_STAGE == 100 and FQ_GS02_EARLY == 1", "류정 '…벌써요?' → 건넴(100)"],
				["warp", "GS-01", "from_X"], ["wait", 1.5], ["shot", "gs02_punch"]]
		"jh01":                                                         # 1-12c FQ-JH-01: 게시판(10) → 노복희 사슬 열쇠 → B구역(20) → 굴 A 철판(30) → 굴 B 흙 위 독 미끼 · 한 시간 →
			st.vars.set_v("AFF_JH", 12)                                  #   왕쥐 둥지 비우기 · 영수증(JH-02 훅) → 조용(40) → 노복희 보고(100) → 다음 날 B-06 수리 · B-04 사공 수선 재개장
			st.vars.set_v("PC_SKP_REPAIR", 60)
			st.vars.set_v("PC_SKP_MEDICINE", 60)
			st.vars.set_v("GAME_DAY", 6)
			st.call_fn("give", ["M-010", 2])
			st.call_fn("give", ["M-026", 1])
			host.date_text = "2277. 10. 29.  10:00"
			host.enter("J-03", "from_J-02")
			plan = [["hp", 3000], ["wait", 1.0], ["want", []], ["go", 8, 3, "J-03"], ["use", 8, 2], ["wait", 1.5], ["shot", "jh01_board"],
				["check", "FQJH01_STAGE == 10", "게시판 쪽지(10)"],
				["want", ["B구역 셔터 일"]], ["talk", "C-050"], ["wait", 1.5],
				["check", "FQ_JH01_OPEN == 1", "노복희 사슬 열쇠"],
				["want", ["들어간다"]], ["go", 36, 3, "J-03"], ["use", 36, 2], ["wait", 2.0], ["shot", "jh01_enter"],
				["check", "FQJH01_STAGE == 20", "B구역(20)"],
				["want", ["고철을 펴"]], ["go", 17, 5, "J-08"], ["use", 17, 4], ["wait", 1.0], ["shot", "jh01_plate"],
				["check", "FQ_JH01_HA == 1 and FQJH01_STAGE == 30", "굴 A 철판(30) — 첫 물결 전 틈"],
				["want", ["흙 위에 말벌"]], ["go", 32, 9, "J-08"], ["use", 32, 8], ["wait", 1.0],
				["check", "FQ_JH01_HB == 2", "굴 B 독 미끼"],
				["hours", 1], ["wait", 1.5], ["shot", "jh01_poison"],
				["check", "FQ_JH01_HB == 3", "한 시간 뒤 굴 B 조용"],
				["fight"], ["wait", 2.0], ["fight"], ["wait", 2.0], ["fight"], ["wait", 2.0], ["fight"], ["wait", 2.0], ["fight"],
				["until", "FQ_JH01_HC == 4", 30.0, "왕쥐 둥지 비움", "jh01_king"],
				["want", ["종이 뭉치를 편다"]], ["go", 43, 12, "J-08"], ["use", 43, 11], ["wait", 2.0], ["shot", "jh01_nest"],
				["check", "FQ_JH01_KING == 1 and FQ_JH02_SEEN == 1 and FQ_JH01_CLEAR == 1 and FQJH01_STAGE == 40", "왕쥐 · 영수증 · 조용(40)"],
				["warp", "J-03", "from_J-08"], ["wait", 1.0], ["want", ["B구역 셔터 일"]], ["talk", "C-050"], ["wait", 2.0],
				["check", "FQJH01_STAGE == 100", "노복희 보고(100)"],
				["hours", 21], ["wait", 1.0], ["warp", "J-04", "from_J-03"], ["wait", 1.0],
				["check", "FQ_JH01_SHOP_M == 1 and FQ_JH01_SHOP_S == 1", "다음 날 재개장(광장을 떠났다 오면)"],
				["warp", "J-03", "from_J-08"], ["wait", 1.5], ["go", 30, 4, "J-03"], ["wait", 1.0], ["shot", "jh01_sagong"],
				["warp", "J-08", "from_J-03"], ["wait", 1.5], ["calm"], ["go", 8, 5, "J-08"], ["wait", 1.0], ["shot", "jh01_shops"]]
		"jh02":                                                         # 1-12d FQ-JH-02: 상인회 책상 네 번째 장부(훅) → 노복희 부탁(10) → 고터 지하상가 탁만수(30) →
			st.vars.set_v("AFF_JH", 12)                                  #   [화술 쉬움] 호위 → 승차장 '영등포 23:40' → 반포 쪽 맨홀(혼자 지하로) → 다음 날 J-03 칸막이 앞 → 재회(100) → 광장 노점
			st.vars.set_v("PC_SKP_SPEECH", 100)
			st.vars.set_v("GAME_DAY", 6)
			host.date_text = "2277. 10. 29.  10:00"
			host.enter("J-03", "from_J-02")
			plan = [["hp", 3000], ["wait", 1.0], ["want", []], ["go", 3, 25, "J-03"], ["use", 3, 24], ["wait", 1.5], ["shot", "jh02_ledger"],
				["check", "FQ_JH02_SEEN == 1", "네 번째 장부 마지막 줄(훅)"],
				["want", ["장부 마지막 줄", "자세히 듣는다"]], ["talk", "C-050"], ["wait", 1.5],
				["check", "FQJH02_STAGE == 10", "노복희 부탁(10)"],
				["warp", "GT-01", "from_W"], ["wait", 1.5], ["calm"], ["shot", "jh02_gt"],
				["want", ["직접 가서 갚으세요"]], ["go", 22, 11, "GT-01"], ["talk", "N-UG-501"], ["wait", 2.0],
				["check", "FQ_JH02_TAK == 2 and FQJH02_STAGE == 30", "탁만수 호위 시작(30)"],
				["warp", "W", "gt_yard"], ["wait", 2.0], ["calm"], ["go", _spot_o("L-R07-12").x + 5, _spot_o("L-R07-12").y + 4],
				["go", _spot_o("L-R07-12").x + 8, _spot_o("L-R07-12").y + 3],
				["until", "FQ_JH02_YARD == 1", 15.0, "승차장 — 영등포 막차 앞에서 멈춘다", "jh02_yard"],
				["warp", "W", "gt_tunnel"], ["wait", 2.0], ["calm"], ["want", ["내일 아침 지하시장에서"]], ["go", _spot_o("L-R07-13").x + 1, _spot_o("L-R07-13").y + 3],
				["go", _spot_o("L-R07-13").x + 3, _spot_o("L-R07-13").y + 2],
				["until", "FQ_JH02_TAK == 3", 15.0, "반포 쪽 맨홀 — 혼자 운반조 길로", "jh02_tunnel"],
				["hours", 21], ["wait", 1.0], ["check", "FQ_JH02_TAK == 4", "다음 날 06시 뒤 — J-03 칸막이 앞"],
				["warp", "J-03", "from_J-02"], ["wait", 1.5], ["calm"], ["want", ["손님 오셨어요"]], ["go", 10, 22, "J-03"], ["talk", "N-UG-501"], ["wait", 3.0], ["shot", "jh02_reunion"],
				["check", "FQJH02_STAGE == 100 and FQ_JH02_SOL == 1 and FQ_JH02_SHOP == 2 and has(\"A-019\")", "재회(100) · 장사꾼 코트 · 광장 노점"],
				["warp", "J-02", "from_J-03"], ["wait", 1.0], ["warp", "J-03", "from_J-02"], ["wait", 1.5], ["go", 34, 14, "J-03"], ["wait", 1.0], ["shot", "jh02_stall"]]
		"jh03":                                                         # 1-12e FQ-JH-03: 북쪽 출구 박춘삼 계약(20) → 지상으로 걸어서 노량진로(낮 시계가 돈다) → 다리목 이동 검문
			st.vars.set_v("AFF_JH", 25)                                  #   [화술 보통] 서류(30분) → 수산시장(40) → 모집원 거절 → 소윤희에게 건넴(100) — 최단 길 낮 시계 실측(계획 §4 · §5.4)
			st.vars.set_v("MQ103_JOB", 3)
			st.vars.set_v("MQ103_HIRE", 2)
			st.vars.set_v("PC_SKP_SPEECH", 100)
			st.vars.set_v("GAME_DAY", 8)
			st.quests.set_stage("MQ-101", 100)                           # 세계 시계가 도는 때(clock_running) — 걸은 시간이 낮 시계에 실제로 쌓이게
			st.vars.set_v("MQ101_NIGHT", 3)
			host.date_text = "2277. 10. 26.  09:00"
			host.enter("J-01", "from_J-02")
			var mk := _spot_o("L-R01-25")
			plan = [["hp", 3000], ["wait", 1.0], ["shot", "jh03_box"], ["want", ["계약한다"]], ["go", 24, 16, "J-01"], ["talk", "C-018"], ["wait", 1.5],
				["check", "FQJH03_STAGE == 20 and FQ_JH03_BOX == 1 and FQ_JH03_PARK == 1 and has(\"M-426\")", "계약 — 상자 · 동행(20)"],
				["warp", "W", "L-R02-11"], ["wait", 2.0], ["noenc"], ["calm"],
				["go", 770, 1154], ["go", 820, 1159], ["wait", 1.0],
				["check", "FQ_JH03_BARK == 1", "대방 지하차도 입구 — 박춘삼 길 위 바크(계약서 얘기 없이)"], ["go", 845, 1166],
				["check", "FQ_JH03_OUT == 1 and FQ_JH03_NEAR == 1", "박춘삼이 곁 · 지상"], ["check", "FQ_JH03_CLOCK > 0", "지상 낮 — 시계가 돈다"],
				["want", ["수산시장 들것 의료반 약"]], ["go", 851, 1168], ["shot", "jh03_post"], ["go", 857, 1169],
				["until", "FQ_JH03_CHECK == 4", 25.0, "다리목 이동 검문 — 서류 반 시간", "jh03_check"],
				["want", ["꺼지라고 한다"]], ["go", 878, 1169], ["go", mk.x + 2, mk.y + 4],
				["until", "FQJH03_STAGE >= 40", 10.0, "수산시장 — 소윤희가 기다린다(40)", "jh03_market"],
				["until", "FQ_JH03_NEAR == 1", 10.0, "박춘삼이 곁에 따라와 섰다", "jh03_near"],
				["want", ["상자를 건넨다"]], ["go", mk.x + 2, mk.y + 5], ["talk", "C-067"], ["wait", 3.0], ["shot", "jh03_done"],
				["check", "FQJH03_STAGE == 100 and FQ_JH03_SOL == 1 and FQ_JH03_NIGHT == 0", "박춘삼과 대낮에 건넴(100 · 공개도 2)"],
				["check", "FQ_JH03_CLOCK >= 40 and FQ_JH03_CLOCK <= 90", "최단 길(서류) 낮 시계 40~90분 — 예산 120분의 3분의 1~3분의 2"],
				["check", "FQ_JH03_SKY >= 8 and FQ_JH03_BARK == 5", "첫 신호(쌓인 30분) · 경매장 칠판 바크"],
				["check", "FQ_JH03_RIVER == 0 and FQ_JH03_NIGHT == 0", "서류 30분을 썼으니 강가 상 없음(75분 넘게 남겨야) · 경매장 판"]]
		"uq05":                                                         # 1-12g UQ-05 누렁이: 고개(X-NS)에 처진 소 → 고삐(걷기 3.0) → 남부순환로 동쪽 → 사당 광장 말뚝(위강윤 · 낮)
			st.vars.set_v("TR_YEON_MET", 1)
			st.vars.set_v("GAME_DAY", 8)
			st.quests.set_stage("MQ-101", 100)
			var ns := WorldMap.origin_of("X-NS")
			st.vars.set_v("UQ05_COW", 1)
			st.vars.set_v("UQ05_LOST_DAY", 8)
			st.vars.set_v("UQ05_ABSENT", 1)
			st.vars.set_v("UQ05_CAUSE", 1)
			st.vars.set_v("UQ05_CX", ns.x + 4)
			st.vars.set_v("UQ05_CY", ns.y + 20)
			host.date_text = "2277. 10. 26.  10:00"
			host.enter("W", "", {}, Vector2(ns.x + 2, ns.y + 11) * 32.0 + Vector2(16, 16))
			var sd := WorldMap.origin_of("X-SD")
			plan = [["hp", 3000], ["wait", 2.0], ["noenc"], ["calm"], ["go", ns.x + 4, ns.y + 18], ["shot", "uq05_cow"],
				["want", ["끊긴 고삐를 잡고 끈다"]], ["talk", "N-UQ5-COW"], ["wait", 1.5],
				["check", "UQ05_COW == 2 and UQ05_SAW == 1", "고삐를 잡음(20)"],
				["go", ns.x + 8, ns.y + 11], ["go", ns.x + 40, ns.y + 11], ["go", ns.x + 80, ns.y + 8], ["shot", "uq05_lead"],
				["check", "UQ05_COW == 2", "멀어지지 않고 따라옴(걷기 3.0)"],
				["go", sd.x + 4, sd.y + 12], ["go", sd.x + 17, sd.y + 12],
				["until", "UQ05_COW == 3", 25.0, "사당 광장 말뚝 — 데려다줌", "uq05_home"],
				["check", "UQ05_PEND == 1 and UQ05_RES == 2 and (UQ05_ABSENT == 1 or CARAVAN_V54 == 2)", "위강윤이 맡음 — 다음 사당 정류까지 말뚝 · 사례는 연보경이 다음에"], ["shot", "uq05_post"]]
		"uq07":                                                         # 1-12h UQ-07 견습생의 첫 납땜: 광장 아이 '배송이요'(먼저 봄) → 배전실 둘째 입장 · 공하경 3칸 →
			st.vars.set_v("AFF_JH", 12)                                  #   혼잣말(10) → '그 애?' → 진공관 셋(①, 100) → 다음 06:00 아이 손 → 낮 광장 쪽지
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("UQ07_VISIT", 1)                               # 첫 방문(해독)은 끝났다
			st.quests.set_stage("MQ-103", 40)
			st.vars.set_v("K_CODE", 1)
			st.call_fn("give", ["M-014", 3])
			host.date_text = "2277. 10. 29.  10:00"
			host.enter("J-03", "from_J-02")
			plan = [["hp", 3000], ["wait", 1.0], ["want", []], ["talk", "N-JM-K1"], ["wait", 1.5], ["shot", "uq07_kid"],   # 쪽지(손수 건넨 판)는 단위 시험 test_uq07_kid_seen_and_note
				["check", "UQ07_KID_SEEN == 1", "광장 아이를 먼저 봄 — '배송이요'"],
				["warp", "J-06", "from_J-03"], ["wait", 1.5], ["check", "UQ07_VISIT == 2", "배전실 둘째 입장"],
				["go", 8, 9, "J-06"], ["until", "UQ07_HEARD == 1", 10.0, "공하경 혼잣말 — 진공관 셋(10)", "uq07_hear"],
				["want", ["광장에서 상자 끄는 그 애?", "진공관 셋을 건넨다"]], ["talk", "N-R02-017"], ["wait", 2.0], ["shot", "uq07_give"],
				["check", "UQ07_RES == 1 and UQ07_TOY == 1 and UQ07_DISC == 1 and UQ07_STAGE == 100", "① 진공관 셋 — 오늘 밤 납땜(100) · 정비 ×0.8"],
				["hours", 23], ["wait", 1.0], ["check", "UQ07_TOY == 2", "다음 06:00 — 아이 손(지금 09시 — 아이는 08~18시 광장)"],
				["warp", "J-03", "from_J-06"], ["wait", 4.0], ["check", "UQ07_TOY == 2 and UQ07_NOTE == 0", "아이 손 — ①은 공하경이 고친 판이라 쪽지 없음(아이는 '하경 언니가'라고 믿음, A211)"],
				["want", []], ["talk", "N-JM-K1"], ["wait", 1.5], ["shot", "uq07_kid_after"]]
		"uq08":                                                         # 1-12h UQ-08 철사의 돋보기: 본소 작업실 철사 '눈이 왜 그래요?'(10) → 병원 1층 응급실 북벽 새 계단 →
			st.vars.set_v("AFF_SB", 10)                                  #   2층 안과 수술실 현미경 렌즈 [수리 30](20) → 작업실 — 건네며 공구함 견본(② [과학 60], 100) → 검수 전날 칠판 · 철사
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("PC_SKP_REPAIR", 40)
			st.vars.set_v("PC_SKP_SCIENCE", 100)
			st.quests.set_stage("MQ-101", 100)
			host.date_text = "2277. 10. 29.  10:00"
			host.enter("H-05", "from_H-02")
			plan = [["hp", 3000], ["wait", 1.0], ["calm"], ["want", ["눈이 왜 그래요"]], ["talk", "N-R02-038"], ["wait", 2.0], ["shot", "uq08_ask"],
				["check", "UQ08_MET == 1 and UQ08_STAGE == 10", "철사 사정 — 세진 광학 렌즈(10)"],
				["warp", "HP-01", "from_W"], ["wait", 1.5], ["calm"], ["go", 37, 1, "HP-01"], ["wait", 1.5], ["calm"], ["shot", "uq08_hp04"],
				["want", ["고정 나사 셋"]], ["go", 6, 5, "HP-04"], ["use", 5, 5], ["wait", 2.0], ["shot", "uq08_scope"],
				["check", "UQ08_LENS == 1 and UQ08_STAGE == 20 and has(\"M-432\")", "수술 현미경 렌즈 — 나사 풀기(20)"],
				["warp", "H-05", "from_H-02"], ["wait", 1.5], ["calm"], ["want", ["렌즈를 건넨다", "원격 해제"]], ["talk", "N-R02-038"], ["wait", 2.0], ["shot", "uq08_give"],
				["check", "UQ08_RES == 2 and UQ08_SAFE == 1 and UQ08_LENS == 2 and UQ08_STAGE == 100 and has(\"M-164\")", "② 건네며 공구함 견본(100) · 해제 열쇠 원형"],
				["setv", "GAME_DAY", 35], ["want", []], ["talk", "N-R02-038"], ["wait", 2.0], ["shot", "uq08_inspect"],
				["check", "UQ08_ISAID == 36", "검수 전날 — 철사 '요즘 땜이 곧으니까'"]]
		"uq09":                                                         # 1-12h UQ-09 탁한 물: 정수를 산 뒤 도민지 사정(10) → 노점 옆 점검구 → J-10 외곽 배수구(20) →
			st.vars.set_v("AFF_JH", 10)                                  #   관리원 일지 · 밸브(물이 차오름 — 서쪽 높은 턱) → 천장 관 밑 알집 태움(30) → 당번 4조 · 철창 → 도민지 매듭(100) → 다음 아침 맑음
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("UQ09_BOUGHT", 1)                              # 거래 창 감지는 단위 시험 test_uq09_bought_and_water
			st.quests.set_stage("MQ-103", 40)
			host.date_text = "2277. 10. 29.  10:00"
			host.enter("J-02", "from_J-01")
			plan = [["hp", 3000], ["wait", 1.0], ["want", ["내가 내려가 볼게"]], ["talk", "N-R02-010"], ["wait", 2.0], ["shot", "uq09_minji"],
				["check", "UQ09_MET == 1 and UQ09_HATCH == 1 and UQ09_STAGE == 10 and has(\"M-436\")", "도민지 사정 — 등유 셋 · 점검구(10)"],
				["want", ["내려간다"]], ["go", 45, 4, "J-02"], ["use", 45, 3], ["wait", 2.0], ["shot", "uq09_down"],
				["check", "UQ09_STAGE == 20", "외곽 배수구(20)"],
				["go", 35, 15, "J-10"], ["use", 35, 16], ["wait", 1.5], ["check", "UQ09_CODE == 1", "관리원 일지 — 관리 번호"],
				["want", ["하수 2-117"]], ["go", 17, 7, "J-10"], ["use", 17, 6], ["wait", 0.3], ["go", 4, 5, "J-10"], ["wait", 7.0], ["shot", "uq09_flood"],
				["check", "UQ09_FLOOD == 1 and UQ09_MOM == 2 and UQ09_E1 == 2 and UQ09_E2 == 2 and UQ09_E3 == 0", "밸브 — 어미 · 바닥 알집 익사 · 천장 관 밑 알집은 남음"],
				["want", ["등유를 붓고"]], ["go", 5, 5, "J-10"], ["use", 5, 4], ["wait", 1.5], ["shot", "uq09_burn"],
				["check", "UQ09_E3 == 1 and UQ09_READY == 1 and UQ09_STAGE == 30", "천장 관 밑 알집 태움 — 말할 일(30)"],
				["want", []], ["go", 4, 4, "J-10"], ["use", 4, 3], ["wait", 1.0], ["check", "UQ09_KEY == 1", "당번 4조 — 쪽지 · 열쇠"],
				["want", ["당번 4조의 열쇠", "철창을 밀고"]], ["go", 2, 3, "J-10"], ["use", 2, 2], ["wait", 2.0], ["shot", "uq09_grate"],
				["check", "UQ09_GRATE == 1", "철창 사슬을 풂 — J-09로"],
				["warp", "J-02", "from_J-01"], ["wait", 1.0], ["want", []], ["talk", "N-R02-010"], ["wait", 2.0], ["shot", "uq09_report"],
				["check", "UQ09_RES == 1 and UQ09_STAGE == 100 and RQ22_OPEN == 1", "도민지 매듭(①, 100)"],
				["hours", 21], ["wait", 1.0], ["check", "UQ09_CLEAN == 1", "다음 아침 — 바늘이 눕는다"]]
		"uq10":                                                         # 1-12h UQ-10 저울추: 역전 시장 수군댐(10) → 밤 저울 쇠판 떼기(20) → 국밥 장수 앞 공개(②, 100) →
			st.vars.set_v("GAME_DAY", 6)                                 #   상인 회의(표 반장) → 2층 반장 방 → 전날 어귀 정찰 둘 → 습격 날 아침 실전(RE-012) 막음
			st.vars.set_v("PC_SKP_REPAIR", 30)
			st.quests.set_stage("MQ-101", 100)
			host.date_text = "2277. 10. 29.  10:00"
			var mo := _spot_o("L-R02-12")                               # 시장 스팟 원점(15×9 — 저울 9,5 · 국밥 장수 2,2)
			host.enter("W", "", {}, Vector2(mo.x + 11, mo.y + 8) * 32.0 + Vector2(16, 16))
			plan = [["hp", 3000], ["wait", 2.0], ["noenc"], ["calm"], ["go", mo.x + 10, mo.y + 7],
				["until", "UQ10_HEARD == 1", 10.0, "노점 둘의 수군댐(10)", "uq10_hear"],
				["hours", 12], ["wait", 1.0], ["want", ["거적을 들추고", "쇠판을 떼어 간다"]], ["go", mo.x + 9, mo.y + 6], ["use", mo.x + 9, mo.y + 5], ["wait", 2.5], ["shot", "uq10_night"],
				["check", "UQ10_PLATE == 1 and UQ10_CHECKED >= 1 and UQ10_STAGE == 20 and has(\"M-433\")", "밤 저울 — 쇠판을 떼어 감(20)"],
				["hours", 11], ["wait", 1.0], ["want", ["쇠판이 덧대져", "덧댄 쇠판을 내민다"]], ["talk", "N-YM-1"], ["wait", 3.0], ["shot", "uq10_public"],
				["check", "UQ10_RES == 2 and UQ10_STAGE == 100", "상인들 앞 공개(②, 100)"],
				["warp", "K-38", "from_W"], ["wait", 1.5], ["calm"], ["shot", "uq10_room"],
				["warp", "W", "L-R02-12"], ["wait", 1.5], ["calm"],
				["hours", 22], ["wait", 1.0], ["check", "UQ10_BOSS == 1 and UQ10_RAID_DAY > 0", "다음 아침 상인 회의 — 표 반장 · 습격 날"],
				["setv", "UQ10_RAID_DAY", 9], ["warp", "W", "L-R02-12"], ["wait", 1.5], ["calm"], ["go", mo.x + 7, mo.y + 3], ["wait", 1.5], ["shot", "uq10_scouts"],
				["check", "GAME_DAY == UQ10_RAID_DAY - 1", "습격 전날 — 어귀에 대방 정찰 둘(예고 출처)"],
				["hours", 25], ["wait", 1.0], ["until", "UQ10_RAID == 5", 10.0, "습격 날 아침 — 대방 분대 실전", "uq10_raid"], ["wait", 6.0], ["shot", "uq10_raiders"],
				["fight"], ["wait", 2.0], ["fight"], ["wait", 2.0], ["fight"], ["wait", 2.0], ["fight"],
				["until", "UQ10_RAID == 1", 40.0, "습격을 막음", "uq10_held"]]
		"uq64":                                                         # 1-12i UQ-64 귀환 유해 대장: 묘지 길덕수 꼬리표(10) → 봉천 대문 셋(20 · BC +4) → 사당 역무실 벽시계(마지막 대문 — 100) →
			st.vars.set_v("GAME_DAY", 6)                                 #   다음 06:00 소식 · 근무지 · 길덕수 에필로그
			st.quests.set_stage("MQ-101", 100)
			st.vars.set_v("MQ101_STAGE", 100)
			st.vars.set_v("MQ101_RESULT", 1)
			st.vars.set_v("PN_LEDGER", 1)                                # 인수 대장은 1-7c 판에서 이미 봄(봇 선택지는 앞에서부터 맞춰져 되풀이된다)
			st.vars.set_v("PN_GIL", 1)
			host.date_text = "2277. 10. 29.  10:00"
			var gm := _spot_o("L-R01-22")                               # 묘지 스팟(10×6 — 길덕수 5,5 · 선반 2,4)
			var bx := 892 - 60 / 2                                       # 봉천 X-BC는 월드에 끼운 손 맵(world_chunks 중심 892,1362 · 60×46) — 맵 칸 + 원점
			var by := 1362 - 46 / 2
			host.enter("W", "", {}, Vector2(gm.x + 5, gm.y + 7) * 32.0 + Vector2(16, 16))
			plan = [["hp", 3000], ["wait", 2.0], ["noenc"], ["calm"], ["want", ["꼬리표를 가족에게", "됐다"]], ["talk", "N-R01-052"], ["wait", 3.0], ["shot", "uq64_tags"],
				["check", "UQ64_TAGS == 1 and UQ64_STAGE == 10 and has(\"M-440\")", "길덕수가 꼬리표 다섯을 맡김(10)"],
				["warp", "X-BC", "from_X-S07"], ["wait", 1.5], ["calm"],
				["want", ["412번"]], ["go", bx + 13, by + 20], ["use", bx + 13, by + 19], ["wait", 2.0], ["shot", "uq64_d412"],
				["want", ["414번"]], ["go", bx + 41, by + 27], ["use", bx + 41, by + 26], ["wait", 2.0],
				["want", ["416번"]], ["go", bx + 29, by + 28], ["go", bx + 29, by + 35], ["go", bx + 9, by + 33], ["use", bx + 10, by + 33], ["wait", 2.0], ["shot", "uq64_d416"],
				["check", "UQ64_D412 == 1 and UQ64_D414 == 1 and UQ64_D416 == 1 and UQ64_BC == 1 and UQ64_STAGE == 20", "봉천 대문 셋(20 · BC +4)"],
				["warp", "D-03", "from_D-02"], ["wait", 1.5], ["calm"], ["want", ["413번"]], ["go", 3, 3], ["use", 3, 2], ["wait", 3.0], ["shot", "uq64_sadang"],
				["check", "UQ64_D413 == 1 and UQ64_SA == 1 and UQ64_STAGE == 100", "사당 역무실 벽시계 태엽 열쇠 끈 — 마지막 대문에서 매듭(100)"],
				["hours", 24], ["wait", 1.0], ["check", "UQ64_NEWS == 1 and UQ64_POST == 3", "다음 06:00 소식 · 근무지 둘"],
				["warp", "W", "L-R01-22"], ["wait", 2.0], ["calm"], ["go", gm.x + 5, gm.y + 7], ["shot", "uq64_post"], ["want", ["됐다"]], ["talk", "N-R01-052"], ["wait", 2.0],
				["check", "UQ64_GSAID == 1", "길덕수 — 꽃 색이 바뀌었잖아"]]
		"uq65":                                                         # 1-12i UQ-65 일타 강사의 문항집: 손재석 수업(판정 셋 · 문항집 — 100) → 다음 날 4 · 5번 → 중계소 카드 벽
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("PC_IN", 7)
			st.quests.set_stage("MQ-101", 100)
			host.date_text = "2277. 10. 29.  10:00"
			host.enter("K-24", "from_W")
			plan = [["hp", 3000], ["wait", 1.5], ["calm"], ["want", ["무슨 수업", "풀어 보자", "지상을 버리라는", "등록증을 기다리죠", "출제 의도", "고맙다"]], ["talk", "N-R01-056"], ["wait", 3.0], ["shot", "uq65_lesson"],
				["check", "UQ65_READ == 3 and UQ65_STAGE == 100 and UQ65_BONUS == 1 and has(\"M-439\")", "판정 셋 · 문항집 · 해설 보너스(100)"],
				["hours", 24], ["wait", 1.0], ["want", ["줄을 지킨다", "한 문제 더", "집으로 들여보낸다"]], ["talk", "N-R01-056"], ["wait", 3.0], ["shot", "uq65_lesson2"],
				["check", "UQ65_LESSON == 5 and UQ65_LTODAY == 2 and UQ65_REBEL == 1", "다음 날 — 4번 · 한 문제 더 5번(하루 두 문항 · 오답 끝말)"],
				["warp", "GS-02", "from_X"], ["wait", 1.5], ["calm"], ["want", ["핀에 꽂는다"]], ["go", 15, 4], ["use", 15, 2], ["wait", 2.5], ["shot", "uq65_wall"],
				["check", "UQ65_TO == 1 and UQ65_WALL == 1 and not has(\"M-439\")", "중계소 카드 벽에 꽂음(GS +3)"]]
		"uq63":                                                         # 1-12i UQ-63 연수원의 졸업장: 본관 깔끔이(10) → 서고 명부 · 보존함(맞춤 · ✕ 한 장) → 기숙사 해골 → 정문 인터컴(세 번째) → 투입구(20) → 다음 06:00(100) → 결과 · 깔끔이 청소
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("PC_IN", 5)
			st.quests.set_stage("MQ-101", 100)
			host.date_text = "2277. 10. 29.  10:00"
			host.enter("K-01", "from_W")                                 # 볼트 정문 X-S07은 월드에 끼운 손 맵(world_chunks INSETS — from_vault 19,37 = 959,1503 → 원점 940,1466): 인터컴 959,1505 · 투입구 962,1505
			plan = [["hp", 3000], ["wait", 1.5], ["calm"], ["want", ["!졸업장은 어디", "됐다"]], ["talk", "N-R01-065"], ["wait", 3.0], ["shot", "uq63_clean"],
				["check", "UQ63_MET == 1 and UQ63_STAGE == 10", "깔끔이 — 졸업식 준비 200년째(10)"],
				["warp", "K-03", "from_W"], ["wait", 1.5], ["calm"], ["shot", "uq63_library"],
				["want", ["명부를 읽는다"]], ["go", 20, 8, "K-03"], ["use", 21, 8], ["wait", 2.0],
				["want", ["봉인을 뜯고", "명부 순서대로", "✕ 한 장은", "됐다"]], ["go", 26, 5, "K-03"], ["use", 26, 4], ["wait", 3.0], ["shot", "uq63_box"],
				["check", "UQ63_ROSTER == 1 and UQ63_MATCH == 1 and UQ63_LEFT == 1 and has(\"M-443\")", "명부 · 보존함 — 맞춤 · ✕ 한 장"],
				["warp", "K-02", "from_K-01"], ["wait", 1.5], ["calm"], ["want", ["✕ 졸업장 한 장"]], ["go", 36, 7, "K-02"], ["use", 37, 6], ["wait", 2.5], ["shot", "uq63_skel"],
				["check", "UQ63_LEFT == 2", "해골 손에 한 장"],
				["warp", "W", "L-R01-01"], ["wait", 1.5], ["calm"], ["setv", "SQ_S03_CALLS", 2], ["want", ["누른다", "!졸업장 312장", "끊는다"]], ["go", 959, 1504], ["use", 959, 1505], ["wait", 3.0], ["shot", "uq63_intercom"],
				["want", ["밀어 넣는다"]], ["go", 962, 1504], ["use", 962, 1505], ["wait", 2.5], ["shot", "uq63_slot"],
				["check", "UQ63_IN == 6 and UQ63_STAGE == 20 and not has(\"M-443\")", "투입구(20)"],
				["hours", 24], ["wait", 1.0], ["check", "UQ63_DONE == 1 and UQ63_STAGE == 100", "다음 06:00 — 200년 늦은 졸업식(100)"],
				["want", ["누른다", "끊는다"]], ["go", 959, 1504], ["use", 959, 1505], ["wait", 3.0], ["check", "UQ63_SAID == 1", "방금례 결과 — 서른 가문 · 311장"],
				["warp", "K-01", "from_W"], ["wait", 1.5], ["calm"], ["shot", "uq63_after"], ["want", ["됐다"]], ["talk", "N-R01-065"], ["wait", 2.0],
				["check", "UQ63_RSAID == 1", "깔끔이 — 의자를 치우고 청소"]]
		"uq67":                                                         # 1-12i UQ-67 보라매 마지막 비행: 렌치(10) → 테이프 → 들창 꺼냄(20 · 라드) → 봉천 남무진 ①(100) → 다음 06:00 아랫마당 가로등
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("PC_SKP_REPAIR", 60)
			st.quests.set_stage("MQ-101", 100)
			st.vars.set_v("MQ101_RESULT", 1)
			host.date_text = "2277. 10. 29.  10:00"
			var bo := _spot_o("L-R01-17")                               # 보라매 스팟(14×9 — 렌치 5,4 · 들창 4,3 · 조종석 1,2)
			host.enter("W", "", {}, Vector2(bo.x + 7, bo.y + 7) * 32.0 + Vector2(16, 16))
			plan = [["hp", 3000], ["wait", 2.0], ["noenc"], ["calm"], ["shot", "uq67_runway"], ["want", ["!저 전투기는", "됐다"]], ["talk", "N-R01-063"], ["wait", 3.0], ["shot", "uq67_wrench"],
				["check", "UQ67_MET == 1 and UQ67_STAGE == 10 and UQ67_DUE == 9", "렌치 — 난로(10) · 렌치의 날"],
				["want", ["테이프를 튼다"]], ["go", bo.x + 1, bo.y + 3], ["use", bo.x + 1, bo.y + 2], ["wait", 2.0],
				["want", ["걸쇠를 풀고"]], ["go", bo.x + 4, bo.y + 4], ["use", bo.x + 4, bo.y + 3], ["wait", 2.5], ["shot", "uq67_hatch"],
				["check", "UQ67_CORE == 2 and UQ67_STAGE == 20 and has(\"M-445\") and PC_RADS >= 20", "들창 — 노심을 꺼냄(20 · 20라드)"],
				["warp", "X-BC", "from_X-S07"], ["wait", 1.5], ["calm"], ["want", ["활주로 공원 전투기 노심", "마을에 쓰세요", "돌아선다"]], ["talk", "N-R01-030"], ["wait", 3.0], ["shot", "uq67_nam"],
				["check", "UQ67_CORE == 4 and UQ67_STAGE == 100", "남무진 ① — 봉천 발전기(100)"],
				["hours", 24], ["wait", 1.0], ["warp", "X-BC", "from_X-S07"], ["wait", 1.5], ["calm"], ["go", 29, 36], ["wait", 1.0], ["shot", "uq67_lamps"],
				["check", "GAME_DAY > UQ67_DAY", "다음 날 — 아랫마당 가로등"]]
		"rq":                                                           # 1-12j 반복 의뢰: 고철(캡 · 계단) → 문제집 → 밤 경계(22:10 시작 · 사건 · 보고) → 지하시장 독샘 · 그때 물건
			st.vars.set_v("AFF_JH", 12)
			st.quests.set_stage("MQ-101", 100)
			st.vars.set_v("MQ101_RESULT", 1)
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("RQ08_P1", 83)                                  #   이번 주 '그때 물건'은 미리 정해 둔다(라디오 · 타자기 · 밥솥)
			st.vars.set_v("RQ08_P2", 85)
			st.vars.set_v("RQ08_P3", 88)
			st.vars.set_v("RQ08_PWK", 1)
			st.call_fn("give", ["M-010", 6])
			st.call_fn("give", ["M-058", 1])
			st.call_fn("give", ["M-048", 2])
			st.call_fn("give", ["M-026", 1])
			st.call_fn("give", ["M-083", 1])
			st.call_fn("give", ["M-085", 1])
			st.call_fn("give", ["M-088", 1])
			host.date_text = "2277. 10. 28.  10:00"
			host.enter("X-BC", "from_X-S07")
			plan = [["hp", 3000], ["wait", 1.5], ["noenc"], ["calm"],
				["want", ["고철 다섯, 캡으로", "그만"]], ["talk", "N-R01-026"], ["wait", 1.5], ["shot", "rq_scrap"],
				["check", "RQ19_T == 5 and PC_CAPS >= 50 and RQ19_WK == 5 and RQF_BC_T == 1", "RQ-19 고철 다섯 묶음 → 50캡(5회 · 단골 1)"],
				["want", ["고철 하나, 계단 보수에", "그만"]], ["talk", "N-R01-026"], ["wait", 1.0],
				["check", "RQ19_T == 6 and V_KARMA >= 10 and has(\"M-010\") == 0", "RQ-19 계단 몫 → 카르마 +10(6회 · 곡선 50%)"],
				["want", ["문제집 한 권을 건넨다", "그만"]], ["talk", "N-R01-031"], ["wait", 1.5], ["shot", "rq_books"],
				["check", "RQ15_T == 1 and RQ15_BOOKS == 1 and has(\"M-058\") == 0", "RQ-15 문제집 → 풍경 1"],
				["settime", "2277. 10. 28.  22:10"], ["calm"], ["want", ["선다"]], ["talk", "N-R01-028"], ["wait", 1.5],
				["check", "RQ30_ON == 1 and RQ30_PHASE == 0", "RQ-30 밤 경계 시작(전조)"],
				["hours", 3], ["wait", 2.0], ["until", "RQ30_PHASE >= 1", 20.0, "사건 또는 조용한 밤"], ["shot", "rq_night"],
				["rqnight"], ["wait", 1.0], ["fight"], ["until", "RQ30_PHASE == 2", 90.0, "세운 것이 다 쓰러짐 · 아침까지"],
				["gomark", "X-BC:land1"], ["want", ["아침까지 선다"]], ["talk", "N-R01-028"], ["wait", 2.0],
				["check", "RQ30_T == 1 and RQ30_ON == 0 and GAME_HOUR == 6", "RQ-30 보고 → 캡 · 숙박 · 06:00"],
				["warp", "J-02", "from_J-03"], ["wait", 1.5], ["want", ["독샘 · 독낭 셋을 내놓는다", "다음에"]], ["talk", "N-R02-006"], ["wait", 1.5],
				["check", "RQ06_T == 1 and has(\"I-007\") == 1 and has(\"M-048\") == 0", "RQ-06 독샘 셋 → 앰플(독샘부터 꺼냄)"],
				["warp", "J-03", "from_J-02"], ["wait", 1.5], ["want", ["이번 주 '그때 물건'은 뭐예요", "다음에"]], ["talk", "N-R02-012"], ["wait", 1.5],
				["want", ["이번 주 물건 셋을 내놓는다", "다음에"]], ["talk", "N-R02-012"], ["wait", 1.5], ["shot", "rq_shelf"],
				["check", "RQ08_T == 1 and RQ08_HAVE == 1 and has(\"M-083\") == 0", "RQ-08 셋 → 가치 × 1.5"]]
		"rqb":                                                          # 1-12j-b: 봉천 게시판 공고 → 조담희 식량 → 낙성대 척후조장(현상금) → 남태하 보상 → 지하시장 배수구 청소 → 위동현 배급 증명 의뢰
			st.vars.set_v("AFF_JH", 12)
			st.vars.set_v("AFF_BJ", 25)
			st.vars.set_v("GAME_DAY", 6)
			st.quests.set_stage("MQ-101", 100)
			st.vars.set_v("MQ101_RESULT", 1)
			st.vars.set_v("RQ22_OPEN", 1)
			st.vars.set_v("PC_SKP_SMALL", 80)
			st.vars.set_v("UQ02_HEARD", 1)                               #   조담희 첫 대화의 UQ-02 개집 장면을 건너뛴다
			st.quests.set_stage("SQ-S01", 100)                            #   바위굴 들개 무리는 남쪽 능선으로 옮긴 뒤(현상금 ②가 붙는 조건)
			st.vars.set_v("SQ_S01_LEFT", 1)
			st.quests.set_stage("UQ-09", 100)                             #   외곽 배수구는 UQ-09 ①로 끝난 상태(어미 죽음 · 알집 태움) — 둥지만 남는다
			st.vars.set_v("UQ09_RES", 1)
			st.vars.set_v("UQ09_MOM", 1)
			st.kill("N-JM-B1")
			for k in ["UQ09_E1", "UQ09_E2", "UQ09_E3"]:
				st.vars.set_v(k, 1)
			st.call_fn("give", ["10mm 탄", 200])
			st.call_fn("give", ["I-031", 4])
			st.call_fn("give", ["I-026", 2])
			host.date_text = "2277. 10. 28.  10:00"
			host.enter("X-BC", "from_X-S07")
			plan = [["hp", 3000], ["wait", 1.5], ["noenc"], ["calm"],
				["go", 884, 1375], ["use", 884, 1374], ["wait", 1.5], ["shot", "rqb_board"],
				["check", "RQ03B_ST == 1 and RQ03B_T == 2", "봉천 게시판 — 공고(SQ-S01 뒤 · SQ-S02 전 → 들개 우두머리)"],
				["want", ["먹을 것을 내놓는다", "다음에"]], ["talk", "N-R01-029"], ["wait", 1.5],
				["check", "RQ43_T == 1 and RQ43_HAVE == 1 and V_KARMA >= 10", "RQ-43 봉천 — 식량 80어치"],
				["warp", "X-BW", "arrive"], ["wait", 2.0], ["hp", 3000], ["until", "RQ03B_ST == 1", 3.0, "바위굴 둘레"], ["shot", "rqb_bw"],
				["fight"], ["until", "RQ03B_ST == 2 and has(\"M-326\") == 1", 120.0, "들개 우두머리 쓰러짐 → 귀표"],
				["warp", "X-BC", "from_X-S07"], ["wait", 1.5], ["calm"], ["want", ["귀표를 내민다", "오늘은 아니다", "밤에 다시 온다"]], ["talk", "N-R01-028"], ["wait", 1.5],
				["check", "RQ03B_ST == 3 and RQ03_T == 1 and PC_CAPS >= 100", "남태하 — 현상금 100"],
				["warp", "J-03", "from_J-02"], ["wait", 1.5], ["want", ["배수구 청소 일감 말인데요", "내려가겠습니다", "(인사만 한다)"]], ["talk", "C-050"], ["wait", 1.5],
				["check", "RQ22_ON == 1", "노복희 — 배수구 의뢰"],
				["warp", "J-10", "from_J02"], ["wait", 2.0], ["hp", 3000], ["shot", "rqb_drain"], ["fight"], ["until", "RQ22_ON == 2", 120.0, "둥지 다 쓰러짐"],
				["warp", "J-03", "from_J-02"], ["wait", 1.5], ["want", ["배수구, 치웠습니다", "(인사만 한다)"]], ["talk", "C-050"], ["wait", 1.5],
				["check", "RQ22_T == 1 and has(\"I-059\", 3) == 1", "노복희 보고 — 60캡 · 정수 셋"],
				["warp", "K-15", "from_W"], ["wait", 1.5], ["want", ["바깥 줄 사람들", "데려오겠습니다", "기다리겠습니다"]], ["talk", "N-R02-023"], ["wait", 1.5],
				["check", "RQ46_ON == 1", "위동현 — 배급 증명 의뢰"]]
		"uq62":                                                         # 1-12i UQ-62 고시생의 마지막 시험: 고시촌 동쪽 초소(상담료 50 → 통행) → D동 3층 권성민(10 · 답안 카드) → 노량진 채점기 [과학 45](성적표 · 20) → 권성민(① 100) → 다음 06:00 떠남 · 관리사무소
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("PC_SKP_SCIENCE", 60)
			st.vars.set_v("GS02_GRADER", 1)
			st.vars.set_v("FQ_GS02_DOOR", 1)                               # 원장실 옆문(채점기는 원장실)
			st.quests.set_stage("MQ-101", 100)
			st.vars.set_v("MQ101_RESULT", 1)
			host.date_text = "2277. 10. 29.  10:00"
			var go := Vector2i(793, 1408)                                 # X-GC 원점(center 818·1428 − 25·20) — 동쪽 초소 앞 arrive(47,21)
			host.enter("W", "", {}, Vector2(go.x + 47, go.y + 21) * 32.0 + Vector2(16, 16))
			plan = [["hp", 3000], ["wait", 2.5], ["noenc"], ["calm"], ["shot", "uq62_gate"], ["want", ["!상담료 여기", "돌아간다"]], ["talk", "N-GC-G1"], ["wait", 3.0],
				["check", "GC_PASS == GAME_DAY and GC_SEEN == 1", "문지기 — 상담료 50 · 통행"],
				["go", go.x + 40, go.y + 9], ["wait", 1.0], ["shot", "uq62_block"], ["go", go.x + 40, go.y + 7], ["wait", 2.5], ["calm"],
				["want", ["!시험은 어떻게", "!답안 카드를 줘", "됐다"]], ["talk", "N-R01-059"], ["wait", 3.0], ["shot", "uq62_kwon"],
				["check", "UQ62_MET == 1 and UQ62_STAGE == 10 and UQ62_CARD == 1 and has(\"M-446\")", "권성민 — 발동(10) · 답안 카드"],
				["warp", "K-24", "from_W"], ["wait", 1.5], ["calm"], ["want", ["!권성민의 답안 카드", "!손수 뚫어", "그만둔다"]], ["go", 29, 4], ["use", 29, 3], ["wait", 2.5], ["shot", "uq62_grader"],
				["check", "UQ62_GRADED == 1 and has(\"M-448\") and UQ62_STAGE == 20", "채점기 — [과학 45] 성적표(20)"],
				["warp", "K-43", "from_W"], ["wait", 1.5], ["calm"], ["want", ["!성적표", "됐다"]], ["talk", "N-R01-059"], ["wait", 3.0], ["shot", "uq62_done"],
				["check", "UQ62_WAY == 1 and UQ62_STAGE == 100 and UQ62_DONE == GAME_DAY", "권성민 — ① 성적표(100) · 스탠드 끔"],
				["hours", 24], ["wait", 1.0], ["check", "UQ62_GONE > 0 and UQ62_JOB == 2", "다음 06:00 떠남(소개 없음 — 복도)"],
				["warp", "J-02", "from_J-01"], ["wait", 1.5], ["calm"], ["go", 36, 4], ["wait", 1.0], ["shot", "uq62_hall"],
				["check", "UQ62_JOB == 2", "지하시장 복도의 권성민"]]
		"uq66":                                                         # 1-12i UQ-66 전지 하나, 냉장고 둘: 심도겸 냉동고 이야기(10 · 기한 +4) → 흑석 원무 단말 퇴원 서류 → 7호 퇴원(20 · 철문) →
			st.vars.set_v("GAME_DAY", 6)                                 #   지하 혈액은행 예비 전지 → 냉장고(100 · 로비 글) → 다음 06:00 들것 협력 · 정류지 → 시장 꼬리표 → 기한 날 운반조 [힘 7](① — 둘 다 삶)
			st.vars.set_v("PC_SKP_SCIENCE", 60)
			st.vars.set_v("PC_ST", 7)
			st.vars.set_v("PN_NURSE", 1)
			st.vars.set_v("PN_SIM", 1)
			st.quests.set_stage("MQ-101", 100)
			host.date_text = "2277. 10. 29.  10:00"
			var fm := _spot_o("L-R01-25")                               # 수산시장 스팟(11×7 — 심도겸 6,5 · 냉동고 8,1 · 운반조 8,3)
			host.enter("W", "", {}, Vector2(fm.x + 5, fm.y + 6) * 32.0 + Vector2(16, 16))
			plan = [["hp", 3000], ["wait", 2.0], ["noenc"], ["calm"], ["want", ["!저 냉동고는", "됐다"]], ["talk", "N-R01-057"], ["wait", 3.0], ["shot", "uq66_market"],
				["check", "UQ66_DUE == 10 and UQ66_HEARD == 6", "심도겸 — 운반조 기한(들은 날 + 4)"],
				["warp", "K-26", "from_W"], ["wait", 1.5], ["calm"], ["want", ["병동 다섯의 퇴원 서류"]], ["go", 6, 4, "K-26"], ["use", 6, 3], ["wait", 2.0], ["shot", "uq66_desk"],
				["check", "UQ66_FORMS == 1 and UQ66_STAGE == 10", "원무 단말 — 퇴원 서류(10)"],
				["want", ["퇴원 서류 다섯 장"]], ["talk", "N-R01-058"], ["wait", 3.0], ["shot", "uq66_discharge"],
				["check", "UQ66_WARD == 1 and UQ66_OPEN == 1 and UQ66_STAGE == 20", "7호 퇴원 — 병동이 빔 · 철문 열림(20)"],
				["go", 29, 3, "K-26"], ["go", 29, 0, "K-26"], ["wait", 2.0], ["calm"], ["shot", "uq66_bank"],
				["want", ["예비 전지를 꺼낸다"]], ["go", 5, 4, "K-26B"], ["use", 5, 3], ["wait", 2.0],
				["want", ["B계통 예비 전지"]], ["go", 3, 4, "K-26B"], ["use", 2, 3], ["wait", 4.0], ["shot", "uq66_fridge"],
				["check", "UQ66_FRIDGE == 1 and UQ66_NOTICE == 1 and UQ66_STAGE == 100", "혈액은행 냉장고가 돎 · 로비 글(100)"],
				["hours", 24], ["wait", 1.0], ["check", "UQ66_DG == 1 and DG_STOP == 2 and UQ66_TAG == 1", "다음 06:00 들것 협력 · 흑석 정류지 · 시장 꼬리표"],
				["warp", "W", "L-R01-25"], ["wait", 2.0], ["calm"], ["shot", "uq66_tag"],
				["hours", 72], ["wait", 1.0], ["check", "GAME_DAY == 10 and GAME_HOUR == 10 and UQ66_BATT == 0 and UQ66_PULLED == 0 and UQ66_GSCELL == 0 and UQ66_DUE == 10", "기한 날 10시 — 아직 아무것도 정해지지 않음"],
				["warp", "W", "L-R01-25"], ["wait", 2.0], ["calm"], ["shot", "uq66_carriers"],
				["want", ["손수레 놓고"]], ["talk", "N-GS-C1"], ["wait", 2.5],
				["check", "UQ66_BATT == 1 and UQ66_BOTH == 1", "운반조 [힘 7] — ① 시장 전지를 지킴 · 시장과 혈액은행 둘 다"]]
		"uq70":                                                         # 1-12h UQ-70 대림 시장의 이자: 장터 첫 방문(기한 — 2277. 10. 29.은 월요일 → 다음다음 수요일 15일) →
			st.vars.set_v("GAME_DAY", 6)                                 #   손지담 사정 · 상인회 도장(20) → 장터 사무실 · 도장 뒤칸(K-39) → 화요일 밤 숨은 수호 → 수 10시 끌려감(30) →
			st.vars.set_v("PC_SKP_LOCKPICK", 40)                         #   새벽 3시 교대 본소 H-03 사슬 기둥 풀기 → K-20 베개 맡 수첩(웅크려) → 구만호 → 다음 아침 이자 실종(②, 100) · 장터 자경 초소
			st.vars.set_v("PC_CAPS", 500)
			st.quests.set_stage("MQ-101", 100)
			host.date_text = "2277. 10. 29.  10:00"
			var dm := _spot_o("L-R02-18")                               # 장터 스팟 원점(16×11 — 손지담 10,3 · 창구 6,6)
			host.enter("W", "", {}, Vector2(dm.x + 9, dm.y + 10) * 32.0 + Vector2(16, 16))
			plan = [["hp", 3000], ["wait", 2.0], ["noenc"], ["calm"], ["go", dm.x + 9, dm.y + 5],
				["until", "UQ70_SEEN == 6 and UQ70_DUE == 15", 8.0, "장터 첫 방문 — 기한 다음다음 수요일", "uq70_market"],
				["want", ["두 배요", "경호를 붙이면요", "돌아선다"]], ["talk", "N-R02-046"], ["wait", 3.0], ["shot", "uq70_jidam"],
				["check", "UQ70_MET == 1 and UQ70_SEAL == 1 and UQ70_STAGE == 20", "손지담 사정 · 상인회 도장(20)"],
				["warp", "K-39", "from_W"], ["wait", 1.5], ["calm"], ["shot", "uq70_office"],
				["hours", 204], ["warp", "K-39", "from_W"], ["wait", 1.5], ["calm"], ["shot", "uq70_hide"],
				["want", ["아침까지 여기 있어"]], ["talk", "N-DR-2"], ["wait", 2.0],
				["check", "UQ70_HIDE_MET == 1 and GAME_WDAY == 1", "화요일 밤 — 도장 뒤칸의 수호(V4)"],
				["hours", 12], ["wait", 1.5], ["check", "UQ70_SUHO == 1 and UQ70_STAGE == 30", "수요일 10시 — 본소로(30)"],
				["hours", 17], ["warp", "H-03", "from_W"], ["wait", 1.5], ["calm"], ["shot", "uq70_chain"],
				["want", ["자물쇠 따기"]], ["talk", "N-DR-2"], ["wait", 2.0], ["check", "UQ70_SUHO == 2 and SB_RAID == 0", "새벽 3시 교대 — 사슬 기둥에서 풂(경비 없음)"],
				["warp", "K-20", "from_W"], ["wait", 1.5], ["calm"], ["crouch", true], ["go", 17, 3], ["wait", 1.0], ["shot", "uq70_pillow"],
				["use", 16, 3], ["wait", 2.0], ["crouch", false],
				["check", "UQ70_BOOK == 1 and has(\"M-438\")", "밤 베개 맡 — 이자의 수첩(웅크려)"],
				["warp", "H-04", "from_H-02"], ["wait", 1.5], ["calm"], ["want", ["대림 수금원의 수첩", "이자의 수첩을 내민다"]], ["talk", "C-049"], ["wait", 3.0], ["shot", "uq70_gu"],
				["check", "UQ70_BOOK == 2 and not has(\"M-438\")", "구만호 — 장부 밖 숫자"],
				["hours", 28], ["wait", 1.0], ["check", "UQ70_JA == 3 and UQ70_RES == 2 and UQ70_STAGE == 100 and UQ70_SUHO == 0", "다음 아침 이자 실종(②, 100) · 수호 장터로"],
				["warp", "W", "L-R02-18"], ["wait", 2.0], ["calm"], ["go", dm.x + 9, dm.y + 5], ["wait", 1.5], ["shot", "uq70_after"]]
		"sb02", "sb02f":                                                # 1-12f FQ-SB-02(sb02f: 방범대와 싸우는 갈래): 04시 본소 마당 출발 줄(갈고리) → 서부간선 고가 상판 → 북 램프 끝 오태수 탈주(데려옴) →
			st.vars.set_v("AFF_SB", 25)                                  #   신도림 쉬는 박자 → 노량진로 끝 방범대([화술 보통] 통과) → 철교 남단 노들 경비 60캡 → 인수원 인계(넷 · 10시 전 · M-129)
			st.vars.set_v("PC_CAPS", 500)
			st.vars.set_v("PC_SKP_SPEECH", 100)
			st.vars.set_v("PC_SKP_SNEAK", 60)
			st.vars.set_v("GAME_DAY", 8)
			st.quests.set_stage("MQ-101", 100)
			st.vars.set_v("MQ101_NIGHT", 3)
			st.quests.set_stage("FQ-SB-01", 100)
			st.vars.set_v("FQ_SB01_RES", 1)
			host.date_text = "2277. 10. 26.  04:05"
			host.enter("W", "X-SB:yard_mid")
			plan = [["hp", 3000], ["wait", 1.5], ["noenc"], ["shot", "sb02_yard"], ["sbgo", "lead"], ["want", ["호위 서겠다"]], ["sbtalk"], ["wait", 1.5],
				["check", "FQSB02_STAGE == 10 and FQ_SB02_LEAD == 0 and FQ_SB02_DAY > 0", "출발 줄 — 갈고리(10)"],
				["sbfollow", "FQSB02_STAGE >= 30", 150.0, "고가 상판 → 북 램프 끝 — 오태수 탈주(30)", "sb02_escape"],
				["check", "FQ_SB02_TAESU == 1", "오태수가 상판 밑으로"], ["wait", 2.0],
				["sbgo", "taesu"], ["want", ["줄로 돌아가자"]], ["sbtalk"], ["wait", 1.5], ["check", "FQ_SB02_TAESU == 2 and FQ_SB02_SEEN == 0", "오태수를 데려옴(봤다는 줄 없음)"],
				["sbgo", "lead"], ["wait", 2.0], ["want", ["말없이 기다린다"]],
				["sbfollow", "FQ_SB02_REST == 1", 90.0, "신도림 — 쉬는 박자", "sb02_rest"],
				["want", ["싸운다" if route == "sb02f" else "오늘은 길만"]],
				["sbfollow", "FQSB02_STAGE >= 40", 200.0, "노량진로 끝 — 자율방범대(40)", "sb02_patrol"], ["wait", 3.0],
				["check", "FQ_SB02_PATROL == %d" % (1 if route == "sb02f" else 2), "싸움(인솔조 대 방범대)" if route == "sb02f" else "화술로 통과"],
				["want", ["[캡 60] 낸다"]],
				["sbfollow", "FQSB02_STAGE >= 50", 120.0, "한강철교 남단 인계 지점(50)", "sb02_hand"],
				["until", "FQSB02_STAGE == 100", 30.0, "인계 끝(100)", "sb02_done"],
				["check", "FQ_SB02_RES == 1 and FQ_SB02_N == 4 and FQ_SB02_TOLL == 1 and FQ_SB02_LATE == 0", "끝까지 운송 · 넷 · 통행세 60 · 10시 전"],
				["check", "has(\"M-129\") == 1 and PC_CAPS == 590", "번호표 목걸이(우호) · 일당 150 − 통행세 60"]]
		"db":                                                           # 1-D1 대방 지하차도 · UQ-71: 북쪽 입구로 들어가 분대 등 뒤에서 웅크려 엿듣기(사흘 기한) → 펌프실 운전기사 메모 →
			st.vars.set_v("PC_SKP_SCIENCE", 60)                          #   허리 물 버스에서 정지 레버로 봉인(카르마 · 지대 꺼짐) → 남쪽 입구로 나와 문 앞에 선다
			st.vars.set_v("GAME_DAY", 8)
			host.date_text = "2277. 10. 26.  10:00"
			host.enter("DB-01", "from_N")
			plan = [["hp", 3000], ["crouch", true], ["wait", 1.0], ["shot", "db_north"], ["go", 4, 14],
				["until", "UQ71_HEARD == 1", 20.0, "분대 등 뒤에서 엿듣기", "db_hear"],
				["check", "UQ71_STAGE == 20 and UQ71_DUE == 11 and UQ71_N >= 2", "단계 20 · 기한 사흘 · 그날 인원"],
				["warp", "DB-01", "pump"], ["calm"], ["go", 29, 6], ["use", 30, 6],
				["until", "UQ71_STAGE >= 30", 10.0, "펌프실 운전기사 메모(23:58)", "db_memo"],
				["warp", "DB-01", "bus"], ["calm"], ["go", 25, 11], ["want", ["정지 레버를 당겨"]], ["use", 25, 12],
				["until", "UQ71_CORE == 1", 20.0, "허리 물에서 정지 레버 — 봉인", "db_seal"],
				["check", "UQ71_STAGE == 100 and UQ71_SOL == 1", "해법 ① 봉인 · 끝"], ["crouch", false],
				["go", 50, 13], ["go", 51, 13], ["until", "map:W", 20.0, "남쪽 입구로 나옴", "db_out"]]
		"nt":                                                           # 1-D2 U02 남태령 지하: 사당 D-05 철망 문(자물쇠) → 터널 · 할매 길값 → 05시대에 기다렸다 교대 틈에 밀통로 →
			st.vars.set_v("PC_SKP_LOCKPICK", 60)                         #   맨홀로 검문소 남쪽 → 지하 초소 계단 → 안쪽에서 정확한 벌금으로 차단봉 → 터널 회로 사당 측
			st.vars.set_v("PC_SKP_REPAIR", 60)
			st.vars.set_v("PC_CAPS", 300)
			st.vars.set_v("GAME_DAY", 8)
			host.date_text = "2277. 10. 26.  05:30"
			host.enter("D-05", "from_D-02")
			plan = [["hp", 3000], ["wait", 1.0], ["go", 25, 13, "D-05"], ["want", ["철사로", "터널로 들어간다"]], ["use", 25, 14],
				["until", "map:NT-03", 15.0, "철망 문 자물쇠 — 4호선 남쪽 터널", "nt_tunnel"], ["check", "U02_OPEN == 1", "철망 문 열림"],
				["warp", "NT-03", "from_shaft"], ["calm"], ["wait", 1.0], ["want", ["길이 있다던데요", "길값을 낸다", "됐어요"]], ["talk", "N-UG-007"],
				["until", "U02_PATH == 1", 10.0, "할매 길값 30캡", "nt_hal"],
				["go", 54, 2, "NT-03"], ["want", ["교대까지 기다린다", "올라간다", "제자리에 덮고"]], ["use", 54, 1],
				["until", "map:W", 20.0, "교대 틈 — 밀통로로 과천대로 맨홀", "nt_manhole"],
				["check", "U02_USED == 1 and U02_TRACE == 0", "덮개를 덮고 나왔다(흔적 없음)"],
				["settime", "2277. 10. 26.  10:00"], ["warp", "NT-01", "in"], ["wait", 1.0], ["shot", "nt_post"], ["want", ["낸다"]], ["use", 20, 12],
				["until", "U02_PASSED >= 1", 15.0, "지하 초소 — 정확한 벌금 · 차단봉", "nt_boom"],
				["check", "PC_CAPS == 270 - U02_FEE and U02_FEE == 20 + 30 * U02_FW", "부른 값 그대로(미등록 20 + 수배 할증)"],
				["warp", "NT-03", "ajae"], ["calm"], ["go", 16, 2, "NT-03"], ["want", ["사당 측 차단기만"]], ["use", 16, 1],
				["until", "U02_LIGHT == 1", 10.0, "조명 회로 — 사당 측", "nt_light"], ["go", 22, 6, "NT-03"], ["wait", 1.0], ["shot", "nt_lamps"],
				["check", "AFF_JC_SA >= 5 and U02_PATH == 1 and U02_HAL == 0", "회로 사당 측 · 할매는 측실에"]]
		"ds":                                                           # 1-D3 독산 육가공 단지 · UQ-04: 관리동 일지 → 배수 밸브(알집이 떠내려감) → 7호 번호 1022 →
			st.vars.set_v("PC_SKP_REPAIR", 60)                           #   상자 열 개(④) → 제어반 냉기를 굴로(둥지 얼림 = 던전 정리 · 10일) → 언 흙 6호 굴쥐는 땅 위
			st.vars.set_v("GAME_DAY", 10)
			host.date_text = "2277. 10. 28.  10:00"
			host.enter("DS-01", "from_W")
			plan = [["hp", 3000], ["wait", 1.0], ["shot", "ds_dock"], ["go", 3, 5, "DS-01"], ["use", 3, 4],
				["until", "UQ04_KNOW == 1", 10.0, "관리동 일지 홀로테이프 — 발동", "ds_tape"],
				["warp", "DS-01", "valve"], ["calm"], ["want", ["수리 25"]], ["use", 41, 14],
				["until", "DS_VALVE == 1", 10.0, "배수 밸브 — 알집이 떠내려감", "ds_valve"],
				["warp", "DS-02", "door7"], ["calm"], ["wait", 1.0], ["shot", "ds_corridor"], ["go", 36, 11, "DS-02"], ["want", ["1 · 0 · 2 · 2"]], ["use", 36, 10],
				["until", "UQ04_OPEN == 1", 10.0, "7호 번호 1022", "ds_open"],
				["go", 34, 8, "DS-02"], ["go", 30, 5, "DS-02"], ["want", ["열 개"]], ["use", 30, 4],
				["until", "UQ04_GONE == 10", 10.0, "상자 열 개(④ 직접 나름)", "ds_take"],
				["check", "UQ04_SOL == 4 and UQ04_STAGE == 100", "닫힘 — 런천미트 · 꽁치"],
				["go", 39, 4, "DS-02"], ["want", ["수리 50"]], ["use", 40, 4],
				["until", "UQ04_COLD == 1", 10.0, "냉기를 굴로 — 둥지가 언다", "ds_cold"], ["wait", 2.0], ["shot", "ds_frost"],
				["check", "UQ04_RATK == 2 and DG_DS == 1 and UQ04_DUE == 20", "언 왕쥐 = 던전 정리 · 냉동기 10일"],
				["warp", "DS-02", "door7"], ["calm"], ["go", 28, 14, "DS-02"], ["wait", 1.5], ["shot", "ds_soil"]]
		"gr":                                                           # 1-D4 구로 차량기지: 구내 → 검측차 열쇠 → 신호 초소 호루라기 · 전철기 표 → 수송 열차 '기립' · 기관사 열쇠꾸러미 →
			st.vars.set_v("PC_SKP_SCIENCE", 60)                          #   레버 C → 정비고 7703 깨움 → 앞으로(입환 C) = 출발 진행(던전 정리)
			st.vars.set_v("GAME_DAY", 12)
			host.date_text = "2277. 10. 30.  10:00"
			host.enter("X-GR", "arrive")
			plan = [["hp", 3000], ["noenc"], ["wait", 2.0], ["shot", "gr_yard"],
				["warp", "GR-05", "from_X"], ["wait", 1.0], ["go", 6, 4, "GR-05"], ["want", ["챙긴다"]], ["use", 6, 3],
				["until", "GR_SIGKEY == 1", 10.0, "검측차 — 신호 초소 열쇠", "gr_inspect"],
				["warp", "GR-06", "from_X"], ["wait", 1.0], ["go", 3, 3, "GR-06"], ["use", 3, 2],
				["until", "GR_CHART == 1", 10.0, "전철기 표", "gr_chart"],
				["go", 8, 4, "GR-06"], ["want", ["신호 초소 열쇠"]], ["use", 8, 5],
				["until", "GR_WHISTLE == 1", 10.0, "신호원 함 — 호루라기", "gr_whistle"],
				["warp", "GR-01", "from_a"], ["wait", 1.0], ["want", ["호루라기"]], ["go", 21, 5, "GR-01"],
				["until", "GR_MUSTER == 1", 15.0, "수송 열차 — '기립!' 안 간 사람들이 줄지어 나간다", "gr_muster"], ["wait", 3.0], ["shot", "gr_train"],
				["want", []], ["go", 66, 4, "GR-01"], ["want", ["챙긴다"]], ["use", 67, 4],
				["until", "GR_KEY == 1", 10.0, "기관사 오재석 — 열쇠꾸러미", "gr_driver"],
				["warp", "X-GR", "gr_view"], ["wait", 2.0], ["calm"], ["grgo", 37, 17], ["want", ["넘긴다"]], ["gruse", 37, 18],
				["until", "GR_LV_C == 1", 10.0, "레버 C — 2번(수송)", "gr_lever"],
				["warp", "GR-02", "from_X"], ["wait", 1.0], ["calm"], ["go", 7, 10, "GR-02"], ["want", ["과학 50"]], ["use", 7, 9],
				["until", "GR_CORE == 1", 10.0, "7703 대기 출력", "gr_wake"], ["wait", 1.0], ["shot", "gr_core"],
				["want", ["앞으로"]], ["use", 7, 9],
				["until", "GR_C == 1", 15.0, "입환 C — 수송 열차 연결", "gr_push"], ["wait", 6.0], ["shot", "gr_depart"],
				["check", "GR_STAFF == 2 and DG_GR == 1 and GR_PUSH == 1", "출발 진행 = 던전 정리 · 밀기 하나 남음"],
				["until", "GR_CHEER == 1", 15.0, "구내 — 역무원이 열차 곁에서 '출발 진행!'", "gr_cheer"], ["wait", 2.5], ["shot", "gr_cheer2"],
				["until", "GR_MUSTER == 3", 10.0, "집결한 '안 간 사람들'이 수송 열차에 오른다", "gr_board"], ["wait", 6.0], ["shot", "gr_board2"]]
		"kt":                                                           # 1-D5a 여의도 금탑: 회전문 → 로비 벨 · 인터폰(어하은) → 승강기 4번 승강로 → 수족관 → 펌프실 배수 → 꺼진 칸 → 로비
			st.vars.set_v("GAME_DAY", 12)
			host.date_text = "2277. 10. 30.  10:00"
			host.enter("KT-01", "from_W")
			plan = [["hp", 3000], ["noenc"], ["wait", 2.5], ["shot", "kt_lobby"],
				["want", ["!승강기 4번", "!전망대에서", "끊는다"]], ["go", 22, 3, "KT-01"], ["use", 22, 2],
				["until", "KT_HOOK == 1 and KT_MEM == 1", 15.0, "인터폰 — 어하은(승강기 4번 · 망원경)", "kt_phone"], ["wait", 3.0],
				["want", ["사다리"]], ["go", 14, 3, "KT-01"], ["use", 14, 2],
				["until", "KT_CAR == 0", 2.0, "승강기 4번 승강로", "kt_shaft"], ["wait", 3.0], ["shot", "kt_aqua"],
				["want", []], ["go", 13, 8, "KT-02"], ["go", 10, 8, "KT-02"], ["go", 4, 6, "KT-02"], ["want", ["A — 배수"]], ["use", 3, 5],
				["until", "KT_POWER == 1", 10.0, "펌프실 — 배수(연료 한 통)", "kt_pump"], ["wait", 3.0],
				["go", 13, 8, "KT-02"], ["go", 18, 7, "KT-02"], ["wait", 1.0], ["shot", "kt_drained"],
				["want", ["그만"]], ["wait", 1.0], ["go", 38, 6, "KT-02"], ["use", 38, 5],
				["until", "KT_CAR == 1", 10.0, "물이 빠진 꺼진 칸", "kt_car"],
				["check", "KT_POWER == 1 and KT_CALL >= 1", "배수 · 통화"]]
		"ga":                                                           # 1-D6 가산 아울렛: 방독면을 쓰고 마네킹 줄에 선다 → 진열창 미끼(작업복 여벌) → 망꾼이 고개를 돌린다 → 지하 작업복 상자 넘김
			st.vars.set_v("GAME_DAY", 12)
			st.vars.set_v("V_ACT", 1)
			st.call_fn("give", ["A-074", 1])
			st.call_fn("give", ["A-001", 2])
			st.call_fn("give", ["A-012", 1])
			st.vars.set_v("PC_TORSO", "A-012")                             # 현장 작업복 차림(볼트 작업복이면 미끼가 소용없다 — 규칙대로)
			st.vars.set_v("PC_HEAD", "A-074")
			host.date_text = "2277. 10. 30.  10:00"
			host.enter("GA-01", "from_sign")                              # 간판 사다리로(정문은 망꾼 3칸 안 — 들어서자마자 고개를 돌린다)
			plan = [["hp", 3000], ["noenc"], ["calm"], ["wait", 1.5], ["shot", "ga_front"],
				["go", 13, 21, "GA-01"], ["go", 13, 22, "GA-01"], ["wait", 1.5], ["check", "ga_pose", "방독면 · 줄 칸 · 멈춤 — 패거리 눈엔 마네킹"], ["shot", "ga_pose"],
				["go", 13, 24, "GA-01"], ["go", 13, 29, "GA-01"], ["go", 18, 29, "GA-01"], ["want", ["입힌다"]], ["use", 18, 30],
				["until", "GA_DECOY == 1", 15.0, "진열창 가운데 마네킹에 볼트 작업복", "ga_decoy"], ["check", "ga_lure", "패거리가 진열창으로 몰려간다(30초)"], ["wait", 2.0], ["shot", "ga_lure"],
				["go", 21, 30, "GA-01"], ["until", "GA_SEEN == 1", 6.0, "줄 속 마네킹 하나가 고개를 돌린다 — 망꾼", "ga_lookout"], ["calm"],
				["warp", "GA-02", "from_GA01"], ["wait", 1.0], ["calm"], ["shot", "ga_store"], ["check", "GA_CRATE_DAY == 12", "지하 작업복 상자를 처음 본 날"],
				["go", 29, 16, "GA-02"], ["want", ["넘긴다"]], ["use", 29, 15],
				["until", "GA_BOX == 1", 15.0, "작업복 상자 — 하역장 수거 칸으로 끌어다 둔다", "ga_crate"],
				["check", "GA_BOX == 1 and GA_BOX_DAY == 12 and GA_DECOY == 1 and GA_SEEN == 1", "상자 넘김 · 미끼 · 망꾼(사실 한 곳)"]]
		"ks":                                                           # 1-D7 지식산업센터: 출근 카드 → 공장층(라인이 작업자를 노리지 않는다) → 모준서 → 타자기 '이관' → 금형 → 데크 크레인 → 문래 성태경 → 하역장 분필 → 다음 06:00 리어카
			st.vars.set_v("GAME_DAY", 12)
			st.vars.set_v("V_ACT", 1)
			st.vars.set_v("PC_SKP_" + st.skill_key("과학"), 60)
			host.date_text = "2277. 10. 30.  10:00"
			host.enter("KS-01", "from_W")
			plan = [["hp", 3000], ["noenc"], ["wait", 2.0], ["shot", "ks_lobby"],
				["want", ["카드 하나를"]], ["go", 18, 4, "KS-01"], ["use", 18, 3],
				["until", "KS_CARD == 1", 10.0, "출근 기록기 — 죽은 작업자의 카드를 찍는다", "ks_card"],
				["warp", "KS-02", "from_KS01"], ["wait", 2.0], ["check", "ks_calm", "라인 설비는 작업자를 노리지 않는다(경보 없음)"], ["shot", "ks_floor"],
				["go", 6, 29, "KS-02"], ["go", 6, 12, "KS-02"], ["go", 6, 8, "KS-02"], ["want", ["그만 가"]], ["talk", "N-R02-049"],
				["check", "UQ69_MET == 1", "공장장 모준서 첫 대면"],
				["want", ["본사 서식", "이관"]], ["go", 4, 7, "KS-02"], ["use", 3, 6],
				["until", "UQ69_PAPER == 1 and KS_LINE == -1", 10.0, "타자기 — 11월 목표 '금형 협력사 이관 — 문래'", "ks_paper"], ["wait", 2.0], ["shot", "ks_stopped"],
				["want", ["금형을 뺀다"]], ["go", 6, 12, "KS-02"], ["go", 6, 26, "KS-02"], ["go", 15, 26, "KS-02"], ["use", 15, 25],
				["until", "UQ69_DIE == 1", 10.0, "3라인 프레스에서 금형을 뺀다", "ks_take"], ["check", "ks_carry", "과적 — 걸음이 느려진다"],
				["want", ["금형만 싣고"]], ["go", 40, 26, "KS-02"], ["go", 40, 24, "KS-02"], ["go", 43, 24, "KS-02"], ["use", 43, 24],
				["until", "UQ69_DIE == 6", 10.0, "외벽 데크 크레인 → 1층 하역장", "ks_crane"],
				["warp", "MR-01", "from_X"], ["wait", 1.0], ["shot", "ks_seong"], ["go", 7, 8, "MR-01"], ["go", 15, 8, "MR-01"], ["want", ["그만 간다"]], ["talk", "N-R02-021"],
				["check", "UQ69_HEARD == 1", "성태경 — 금형 얘기(리어카)"],
				["warp", "KS-01", "from_KS02"], ["wait", 1.0], ["clear", ["CR-095"]], ["want", ["그만둔다"]], ["go", 31, 11, "KS-01"], ["use", 30, 10], ["wait", 2.0], ["shot", "ks_dest"],
				["check", "UQ69_DEST == 2 and UQ69_DIE == 6", "하역장 금형에 이관 통보서 — 성씨 리어카가 알아서(분필 없이)"],
				["hours", 22], ["check", "UQ69_DIE == 2 and UQ69_DONE_DAY >= 12", "다음 06:00 — 리어카가 문래로(사실 한 곳)"],
				["warp", "X-MR", "arrive"], ["wait", 2.0], ["shot", "ks_alley"]]
		"yt":                                                             # 1-D9 유리탑: 소파의 서기 목에서 카드(은신) → 3동 게이트 → 비상 계단 → 18층 판독(로봇 — 남기범 심부름) → 테이프 · 화분 전초 → 증권가 셔터 → 객장 경상현 → 전광판 마감 종
			st.vars.set_v("GAME_DAY", 12)
			st.vars.set_v("V_ACT", 1)
			st.vars.set_v("PC_SKP_" + st.skill_key("은신"), 100)
			host.date_text = "2277. 10. 30.  10:00"
			host.enter("YT-01", "from_W")
			plan = [["hp", 3000], ["noenc"], ["wait", 1.5], ["shot", "yt_lobby"],
				["go", 22, 18, "YT-01"], ["want", ["목걸이"]], ["use", 22, 17], ["wait", 0.5],
				["check", "has(\"M-401\") == 1 and YT_DOZE == 1", "졸던 서기의 목에서 진짜 빨강 카드(22:40 발급)"],
				["go", 30, 12, "YT-01"], ["want", ["!남기범"]], ["use", 30, 11], ["wait", 0.5], ["shot", "yt_gate3"],
				["check", "YT_R == 1", "3동 게이트 — '어서 오십시오, 남기범 서기님'"],
				["go", 30, 10, "YT-01"], ["go", 37, 4, "YT-01"], ["want", ["!남기범"]], ["use", 37, 3], ["wait", 0.5],
				["go", 36, 2, "YT-01"], ["go", 36, 0, "YT-01"], ["wait", 1.0],
				["until", "map:YT-03", 10.0, "비상 계단 철문 → 18층"],
				["go", 6, 14, "YT-03"], ["want", ["!남기범"]], ["use", 6, 13], ["wait", 1.0], ["shot", "yt_read18"],
				["check", "YT_ROBOT_OK == 1", "18층 로봇 — 남기범 심부름 확인 · 셔터가 오른다"],
				["clear", ["CR-080"]], ["go", 6, 9, "YT-03"], ["go", 22, 6, "YT-03"], ["go", 31, 5, "YT-03"], ["want", ["꺼낸다"]], ["use", 31, 4], ["wait", 0.5],
				["check", "has(\"M-404\") == 1 and YT_INC == 0", "시세 테이프(10-23 연장장)"],
				["go", 35, 7, "YT-03"], ["want", ["걷어"]], ["use", 35, 8], ["wait", 0.5], ["shot", "yt_deck"],
				["check", "YT_MOUND == 1", "창가 개미 전초를 걷어 냄(정리)"],
				["go", 22, 6, "YT-03"], ["go", 6, 9, "YT-03"], ["go", 3, 19, "YT-03"], ["go", 3, 22, "YT-03"], ["wait", 1.0],
				["go", 30, 12, "YT-01"], ["go", 19, 19, "YT-01"], ["go", 19, 24, "YT-01"], ["go", 34, 27, "YT-01"], ["want", ["!남기범"]], ["use", 34, 28], ["wait", 0.5],
				["check", "YT_SG == 1", "증권가 연결 통로 셔터"],
				["go", 34, 31, "YT-01"], ["wait", 1.0], ["until", "map:SG-01", 10.0, "통로 끝 — 객장 지하"],
				["want", ["됐다"]], ["talk", "N-R02-032"], ["check", "UQ06_MET == 1", "경상현 — '그거… 오늘 치예요?'"],
				["go", 15, 4, "SG-01"], ["want", ["시세 테이프"]], ["use", 15, 3], ["wait", 2.0], ["shot", "yt_board"],
				["check", "UQ06_RESULT == 1 and has(\"M-405\") == 1 and UQ06_STAGE == 100", "전광판 — 마감 종 · 테이프는 지워졌다 · UQ-06 끝"],
				["want", ["구울이 됐어"]], ["talk", "N-R02-032"], ["check", "UQ06_ASKED == 1", "'…그럼 아직 심부름 중이네요.'"]]
		"u04":                                                            # 1-D10 여의도 지하: 소민서 진공관 운송 · 천 감기 · 레일 말 → 수레에 싣고 민다(발 고정 — 수레가 비켜야 간다) → 승강장 끝에서 수레가 따라 넘어감 →
			#   천 감고 신길 앞(줄이 깨지 않는다) → 내리막에 올라타 여의도로 → '길게 하나, 둘' 공병 통제선 → 터널 B 내리막 · 브레이크 → 여의나루 차막이 → 손으로 기건희에게
			st.vars.set_v("GAME_DAY", 12)
			st.vars.set_v("V_ACT", 1)
			host.date_text = "2277. 10. 30.  10:00"
			host.enter("U4-01", "from_top")
			plan = [["hp", 3000], ["noenc"], ["clear", ["CR-095", "CR-002"]], ["wait", 1.5], ["shot", "u04_station"],
				["want", ["짐을 받는다", "진공관"]], ["talk", "N-UG-009"], ["wait", 0.5], ["check", "U04_JOB == 6 and has(\"M-406\") == 1", "소민서 — 진공관 짐"],
				["want", ["바퀴에 천을", "레일 말", "다음에"]], ["talk", "N-UG-009"], ["wait", 0.5], ["check", "U04_CLOTH == 1 and U04_KNOW == 1", "바퀴 천 · 레일 말"],
				["go", 2, 18, "U4-01"], ["want", ["싣는다"]], ["use", 3, 18], ["wait", 0.5], ["check", "U04_CART_LOAD == 6", "진공관을 수레에"], ["shot", "u04_cart"],
				["hold", 1, 0, "U04_CART_X >= 41", 60.0, "걸어 들어가 민다 — 승강장 끝까지"],
				["go", 42, 17, "U4-01"], ["go", 43, 17, "U4-01"], ["until", "map:U4-02", 10.0, "터널 A로"],
				["check", "U04_CART_MAP == 2 and U04_CART_X == 3", "수레가 따라 넘어왔다"], ["clear", ["CR-095"]],
				["hold", 1, 0, "U04_CART_X >= 92", 120.0, "터널 A — 신길 앞을 천 감고"], ["check", "u04_quiet", "신길 줄이 깨지 않았다(천)"], ["shot", "u04_singil"],
				["clear", ["CR-095"]], ["u04go"], ["want", ["올라탄다"]], ["use", 0, 0, "cart"], ["wait", 0.5], ["check", "u04_riding", "내리막 — 올라탔다"],
				["until", "map:U4-03", 30.0, "탄 채로 여의도역"], ["until", "u04_stopped", 30.0, "브레이크 없이 — 공병 모래주머니에 쿵"], ["check", "U04_RAM == 1", "들이받음 하나(초소가 화낸다)"], ["clear", ["CR-200"]], ["shot", "u04_yd"],
				["go", 30, 19, "U4-03"], ["want", ["길게 하나, 둘"]], ["use", 30, 20], ["use", 30, 20], ["wait", 0.5], ["check", "U04_ENG == 1", "운반조 신호 — 공병 통제선이 걷힌다"],
				["u04go"], ["hold", 1, 0, "U04_CART_X >= 44", 60.0, "통제선 틈으로 민다"],
				["go", 43, 19, "U4-03"], ["go", 46, 19, "U4-03"], ["go", 47, 19, "U4-03"], ["until", "map:U4-04", 10.0, "터널 B로"],
				["check", "U04_CART_MAP == 4", "수레가 따라 넘어왔다"], ["clear", ["CR-095", "CR-206"]],
				["hold", 1, 0, "U04_CART_X >= 8", 20.0, "내리막 머리까지"],
				["u04go"], ["want", ["올라탄다"]], ["use", 0, 0, "cart"], ["wait", 0.5], ["check", "u04_riding", "대심도 내리막 — 올라탔다"],
				["until", "U04_CART_X >= 36", 30.0, "질주"], ["use", 0, 0, "brake"], ["until", "u04_stopped", 15.0, "브레이크 — 선다"], ["shot", "u04_brake"],
				["check", "U04_CART_X < 70", "내리막 끝 전에 섰다"], ["clear", ["CR-095", "CR-206"]],
				["u04go"], ["hold", 1, 0, "U04_CART_X >= 96", 90.0, "터널 B 끝까지"],
				["go", 98, 8, "U4-04"], ["go", 99, 8, "U4-04"], ["until", "map:U4-05", 10.0, "여의나루로"],
				["u04go"], ["hold", 1, 0, "U04_CART_X >= 34", 30.0, "차막이까지"], ["shot", "u04_naru"],
				["u04go"], ["want", ["내려"]], ["use", 0, 0, "cart"], ["wait", 0.5], ["check", "has(\"M-406\") == 1 and U04_CART_LOAD == 0", "차막이 — 짐을 손으로"],
				["want", ["다음에"]], ["talk", "N-UG-012"], ["wait", 1.0], ["check", "U04_RUN == 1 and U04_JOB == 9 and has(\"M-409\") == 1", "기건희 — 운임 · 돌아오는 펌프 부품"], ["shot", "u04_kigun"]]
		"hosp":                                                           # 1-D8 대학병원: 1층 → 7층 반수빈(첫 대화 · 사정) → 칠판 → 지하 회진 행진 → 방재실 배식 차임(덮어쓰기 — 7층이 흐림) → 면회 시간 흐린 침상 곁 → 보급 → 약길 ① 편지 → 금하람
			st.vars.set_v("GAME_DAY", 12)
			st.vars.set_v("V_ACT", 1)
			st.vars.set_v("PC_SKP_" + st.skill_key("화술"), 100)
			st.call_fn("give", ["I-002", 3])
			st.call_fn("give", ["I-004", 2])
			host.date_text = "2277. 10. 30.  10:00"
			host.enter("HP-01", "from_W")
			plan = [["hp", 3000], ["noenc"], ["wait", 1.5], ["shot", "hp_lobby"],
				["warp", "HP-02", "from_HP01"], ["wait", 1.5], ["shot", "hp_ward"],
				["go", 16, 19, "HP-02"], ["want", ["!사정", "그만 간다"]], ["talk", "N-R02-031"],
				["until", "HP_MET == 1 and HP_TOLD == 1 and HP_DAY0 == 12", 10.0, "반수빈 — 첫 대화 · 사정(병동 시계는 이날부터)", "hp_ban"],
				["go", 19, 18, "HP-02"], ["use", 19, 17], ["wait", 1.0], ["shot", "hp_board"],
				["warp", "HP-03", "from_HP01"], ["calm"], ["wait", 1.0], ["check", "hp_march", "회진 — 옛 직원 다섯이 깨어 복도를 한 줄로 돈다"], ["shot", "hp_march"],
				["go", 17, 12, "HP-03"], ["go", 17, 5, "HP-03"], ["go", 18, 4, "HP-03"], ["want", ["!배식"]], ["use", 18, 3],
				["until", "HP_OVR == 3", 10.0, "방재실 단말 — 배식 차임(두 시간 덮어쓰기)", "hp_call"], ["wait", 1.0], ["check", "hp_eat", "배식 대형 — 주방 배식차 쪽으로"],
				["check", "HP_BLUR == 1 and HP_PUSH_DAY == 12", "제때 아닌 차임을 7층도 들었다 — 차트 1번 흐림"],
				["hours", 4], ["warp", "HP-02", "from_HP01"], ["wait", 1.0],
				["want", ["!곁에 앉아"]], ["go", 2, 6, "HP-02"], ["use", 2, 5],
				["until", "HP_BLUR == 0", 10.0, "면회 시간 — 흐린 탁정오 곁에 앉아 이름을 부른다", "hp_visit"], ["shot", "hp_visit"],
				["go", 21, 12, "HP-02"], ["want", ["!보급품", "그만 간다"]], ["talk", "N-R02-031"],
				["until", "RQ47_N == 1", 10.0, "RQ-47 — 라드어웨이 셋 · 수혈 팩 둘", "hp_supply"],
				["go", 21, 12, "HP-02"], ["want", ["!약길", "!지하시장", "그만 간다"]], ["talk", "N-R02-031"],
				["until", "HP_LETTER == 1", 10.0, "약길 ① — 반수빈 편지", "hp_letter"],
				["warp", "J-05", "from_J-03"], ["wait", 1.0], ["want", ["200년", "괜찮다"]], ["talk", "C-051"],
				["until", "HP_WAY == 1", 10.0, "금하람 — 주마다 피 둘을 7층 몫으로", "hp_geum"],
				["check", "HP_LETTER == 2 and DG_STOP == 0", "교역 길 — 들것 정류지는 그대로(사실 한 곳)"], ["wait", 1.0], ["shot", "hp_sign"]]
		"ktj":                                                          # 1-D5a 금탑 엉뚱한 짓: 승강로에 뛰어내린다 → 물속 칸 → 사다리로 로비 → 어하은이 알아챈다
			st.vars.set_v("GAME_DAY", 12)
			host.date_text = "2277. 10. 30.  10:00"
			host.enter("KT-01", "from_W")
			plan = [["hp", 3000], ["noenc"], ["wait", 1.5], ["want", ["뛰어내린다"]], ["go", 14, 3, "KT-01"], ["use", 14, 2],
				["until", "KT_HATCH == 1", 10.0, "승강로에 뛰어내림 — 칸 지붕 해치가 꺼짐", "ktj_jump"], ["wait", 3.0], ["shot", "ktj_bottom"], ["clear", ["CR-130"]],
				["want", ["사다리"]], ["go", 39, 6, "KT-02"], ["use", 40, 6],
				["until", "KT_CAR == 1", 10.0, "물속 칸 — 아이 신발 한 짝 → 점검 사다리로 로비", "ktj_car"], ["wait", 3.0],
				["want", ["!끊는다"]], ["go", 22, 3, "KT-01"], ["use", 22, 2],
				["until", "KT_CARTOLD == 1", 15.0, "어하은 — '숨소리가 달라요'", "ktj_phone"]]
		"trd":                                                          # 1-L 파밍 v3 · 다시 문 연 가게: 문 앞 세움 간판 → 고물상 거래(결 매입 · 찾는 것) → 털린 살림집(보이는 빔)
			st.vars.set_v("GAME_DAY", 5)
			st.vars.set_v("V_ACT", 1)
			host.date_text = "2277. 10. 26.  11:00"
			host.ev.handlers["trade"] = func(a: Array, done: Callable) -> void: host.open_trade(str(a[0]), func(_c: int) -> void: done.call())
			host.enter("W", "", {}, Vector2(918 * 32 + 16, 1294 * 32 + 16))
			plan = [["noenc"], ["hp", 3000], ["wait", 2.0], ["shot", "trd_door"], ["go", 918, 1293], ["use", 918, 1292], ["wait", 2.0],
				["check", "map:G-918-1292", "다시 문 연 고물상에 들어섰다"], ["shot", "trd_inside"],
				["want", ["!물건을 본다", "다음에"]], ["talk", "N-VG-S1"], ["until", "win", 15.0, "고물상 거래 창(가게마다 따로 재고 · 찾는 것)", "trd_trade"], ["wait", 2.0], ["warp", "G-880-1244", "from_W"], ["wait", 2.0], ["shot", "trd_home"],
				["warp", "G-855-1243", "from_W"], ["wait", 2.0], ["shot", "trd_home2"]]
		"stash":                                                        # 1-L 보관 자리 · UQ-125: 빈집 장롱을 비우고 삼기 → 물건 넣기 → 털림 → 흔적(10) → 빈집의 아이(30) → 나눠 주기(100)
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("V_ACT", 1)
			host.date_text = "2277. 10. 27.  11:00"
			host.enter("G-880-1244", "from_W")
			plan = [["noenc"], ["hp", 3000], ["wait", 1.5], ["stash_open"], ["wait", 0.5], ["stash_claim"], ["shot", "stash_claim"], ["close"], ["wait", 0.5],
				["check", "UQ125_R == 0", "내 자리로 삼았다"], ["setv", "GAME_DAY", 12], ["warp", "W", "L-R01-20"], ["wait", 1.0], ["stash_rob"],
				["warp", "G-880-1244", "from_W"], ["wait", 1.5], ["stash_open"], ["wait", 1.0], ["shot", "stash_trace"], ["close"],
				["check", "stage(\"UQ-125\") >= 10", "털린 자리를 열어 흔적을 보았다 — UQ-125 10"], ["warp_dest"], ["wait", 2.0], ["shot", "stash_kid"],
				["check", "UQ125_KID == 1", "흔적이 가리킨 빈집에 아이가 있다"],
				["want", ["먹을 건 가져라"]], ["talk", "N-UQ-K1"], ["until", "UQ125_R == 2", 25.0, "먹을 것은 아이 몫 — 나머지 · 방울 줄 둘", "stash_share"],
				["check", "has(\"M-195\") == 1 and has(\"M-012\") == 1 and has(\"W-013\") == 1", "방울 줄 · 구리선 · 권총을 되찾았다"]]
		"stashc":                                                       # 1-L⑦ 털이꾼 갈래: 삼기 → 털이꾼 털림 → 흔적 → 낮 소굴(말이 통함 · 장면) → 수고비 30캡(R 10)
			st.vars.set_v("GAME_DAY", 6)
			st.vars.set_v("V_ACT", 1)
			st.vars.set_v("PC_CAPS", 200)
			host.date_text = "2277. 10. 27.  11:00"
			host.enter("G-880-1244", "from_W")
			plan = [["noenc"], ["hp", 3000], ["wait", 1.5], ["stash_open"], ["wait", 0.5], ["stash_claim"], ["close"], ["wait", 0.5],
				["setv", "GAME_DAY", 12], ["setv", "GAME_HOUR", 13], ["warp", "W", "L-R01-20"], ["wait", 1.0], ["stash_rob", "crew"],
				["warp", "G-880-1244", "from_W"], ["wait", 1.5], ["stash_open"], ["wait", 1.0], ["shot", "stashc_trace"], ["close"],
				["check", "stage(\"UQ-125\") >= 10 and UQ125_WHO == 2", "털이꾼 흔적 — UQ-125 10"], ["warp_dest"], ["wait", 1.0],
				["want", ["수고비"]], ["until", "UQ125_R == 10", 25.0, "낮 소굴 — 말이 통하는 털이꾼 · 수고비로 자루를 돌려받음", "stashc_talk"],
				["check", "has(\"M-195\") == 1 and has(\"W-013\") == 1 and PC_CAPS < 200", "자루 · 방울 줄 둘 · 30캡을 냈다"]]
		"ktu":                                                          # 1-D5b 금탑 위층: 화물 칸 → 사무층 육아방(위장 · 냄새 줄) → 22층 → 옥상 → 60층 어하은 · 망원경 → 연회장 · 기단
			st.vars.set_v("GAME_DAY", 12)
			st.vars.set_v("KT_POWER", 2)
			st.vars.set_v("KT_CALL", 1)
			host.date_text = "2277. 10. 30.  10:00"
			host.enter("KT-01", "from_W")
			plan = [["hp", 3000], ["noenc"], ["wait", 1.5], ["shot", "ktu_lobby"], ["want", ["위층 단추"]], ["go", 19, 3, "KT-01"], ["use", 19, 2],
				["wait", 3.0], ["shot", "ktu_office"], ["clear", ["CR-081"]],
				["want", ["!점액", "!알 하나", "그만"]], ["go", 27, 21, "KT-03"], ["use", 27, 20],
				["until", "PC_SMELL > 0 and has(\"M-394\") == 1", 15.0, "육아방 — 위장 · 알", "ktu_nurse"], ["wait", 2.0], ["shot", "ktu_scent"],
				["go", 40, 4, "KT-03"], ["go", 45, 3, "KT-03"], ["wait", 2.5], ["calm"], ["shot", "ktu_nest"],
				["setv", "KT_QUEEN", 1], ["setv", "KT_TOP", 1], ["warp", "KT-07", "from_ladder"], ["wait", 1.5], ["shot", "ktu_roof"],
				["warp", "KT-06", "from_roof"], ["wait", 1.5], ["shot", "ktu_deck"],
				["want", ["!망원경 이야기", "내려가 보겠다"]], ["talk", "N-R02-030"],
				["until", "KT_MEET == 1", 20.0, "어하은 첫 얼굴 — 4번 문 앞", "ktu_haeun"], ["wait", 3.0],
				["want", ["손잡이"]], ["go", 30, 6, "KT-06"], ["use", 30, 5],
				["until", "KT_TOP == 2 and KT_VIEW == 1", 20.0, "망원경 점등 — 지금의 서울 · 그녀의 2077", "ktu_scope"], ["wait", 3.0], ["shot", "ktu_lit"],
				["check", "KT_TOP == 2 and KT_QUEEN == 1", "UQ-68 끝(사실)"],
				["warp", "KT-05", "from_stair"], ["wait", 1.5], ["calm"], ["shot", "ktu_hall"],
				["warp", "KT-08", "from_base"], ["wait", 1.5], ["shot", "ktu_base"]]
		"grp":                                                          # 1-D4 구로 엉뚱한 짓: 분실물 정기권을 역무원 박에게 돌려준다 → 박 퇴근 · 쥐 둥지 군번줄 → 떠돌이
			st.vars.set_v("GAME_DAY", 12)
			st.call_fn("give", ["M-071", 1])
			st.vars.set_v("GR_LOST", 1)
			host.date_text = "2277. 10. 30.  10:00"
			host.enter("X-GR", "gr_gate_in")
			plan = [["hp", 3000], ["noenc"], ["wait", 1.5], ["want", ["정기권을 내민다"]], ["grgo", 57, 26],
				["until", "GR_PARK >= 1", 40.0, "박에게 정기권 — '제 겁니다. 찾고 있었습니다.'", "grp_park"], ["wait", 3.0], ["shot", "grp_leave"],
				["check", "has(\"M-071\") == 0 and GR_STAFF == 0", "정기권을 잃음 · 김은 아직 근무"],
				["warp", "GR-04", "from_X"], ["wait", 1.0], ["want", ["집는다"]], ["go", 22, 5, "GR-04"], ["use", 22, 4],
				["until", "GR_TAG == 1", 10.0, "쥐 둥지 — 군번줄 '최병규'", "grp_tag"],
				["warp", "GR-03", "from_X"], ["wait", 1.0], ["want", ["부탁"]], ["talk", "N-GR-D1"],
				["until", "GR_DRIFT == 3", 15.0, "떠돌이 — 부탁을 듣는 자리에서 군번줄을 건넨다", "grp_drift"]]
		"s11p":                                                         # 1-11j SQ-S11 낮 호위: 공영방송 앞에서 국회 쪽으로 걸으면 여의도 순찰이 '구울 통행 금지' → 환승센터 터 지하로 숨는다 → 계단 낭독
			st.call_fn("give", ["M-305", 1])
			st.vars.set_v("GAME_DAY", 4)
			host.date_text = "2277. 10. 26.  12:00"
			host.enter("J-03", "from_J-02")
			plan = [["wait", 1.0], ["want", ["사망자 명단을 보여", "같이 가자"]], ["talk", "N-R02-014"], ["wait", 1.0],
				["check", "SQ_S11_ESCORT == 1", "낮 — 인지영과 출발"], ["noenc"], ["warp", "W", "L-R02-06"], ["wait", 2.0], ["want", ["몸을 숨긴다"]], ["gomark", "kh_read"],
				["until", "SQ_S11_PDAY == 4", 40.0, "여의도 낮 순찰 — 구울 통행 금지", "s11p_squad"], ["wait", 4.0], ["shot", "s11p_after"],
				["want", []], ["clear", ["CR-104", "CR-107"]], ["gomark", "kh_read"], ["until", "SQ_S11_READ == 1", 60.0, "숨었다가 계단까지 — 열한 이름", "s11p_read"],
				["check", "SQH_LIST11 == 4 and SQ_S11_PKIND == 1", "순찰을 넘기고 낭독"]]
		"s6s":                                                          # 1-11f 수색조: 첫 접촉 25시간 뒤 시흥 고개 — 평상복 · 등록증 진해원과 길을 걸으면 수색조가 선다 → 분대장 검문 통과
			for kv in [["A-005", 1], ["M-062", 1]]:
				st.call_fn("give", kv)
			host.date_text = "2277. 10. 27.  10:00"
			host.enter("Q-30", "from_X")
			plan = [["wait", 1.0], ["want", ["어디로", "노들섬까지"]], ["talk", "N-R01-064"], ["wait", 1.0],
				["want", ["할 말이 있어", "이 옷으로"]], ["mate", "N-R01-064"], ["wait", 1.0],
				["want", ["할 말이 있어", "등록증"]], ["mate", "N-R01-064"], ["wait", 1.0],
				["settime", "2277. 10. 28.  12:00"], ["warp", "X-SH", "arrive"], ["wait", 1.5], ["want", []], ["gomark", "X-SH:s2"], ["goen", "CR-403"],
				["until", "SQ_S06_LEADER >= 1 or SQ_S06_SQUADS > 0", 30.0, "시흥 고개 — 수색조(상황은 그날 굴린 것)", "s6s_squad"],
				["wait", 3.0], ["shot", "s6s_after"],
				["check", "SQ_S06_SQUADS > 0 and SQS06_STAGE >= 30 and SQ_S06_JIN == 1", "수색조를 넘겼다(권역 한 번) · 진해원은 곁에"]]
		"s5q":                                                          # 1-11e 휴면 군집: 서울대입구 쪽 철사로 조용히 → 웅크려(은신 60) 선로 잔해 길목 지나 개찰구까지 → 서서 걸으면 일제 기상
			st.vars.set_v("PC_SKP_REPAIR", 30)
			st.vars.set_v("PC_SKP_SNEAK", 60)
			st.call_fn("give", ["M-071", 1])
			host.date_text = "2277. 10. 27.  10:00"
			host.enter("U-03", "from_W")
			plan = [["wait", 1.0], ["shot", "s5q_snu"], ["want", ["철사"]], ["scene", "SQS05_IRONB"], ["until", "map:U-02", 15.0, "철사로 빗장을 조용히 — 낙성대 승강장", "s5q_in"],
				["wait", 1.0], ["check", "SQ_S05_WOKE == 0 and SQS05_STAGE == 40", "아무도 깨지 않았다 · 순서 파괴 40"], ["hp", 9999],
				["crouch", true], ["go", 14, 6, "U-02"], ["go", 30, 6, "U-02"], ["go", 38, 8, "U-02"], ["wait", 1.0], ["shot", "s5q_through"],
				["check", "SQ_S05_WOKE == 0", "웅크려 군집 사이를 지나 개찰구까지(정기권 — 역무원이 비켜선다)"],
				["crouch", false], ["go", 27, 7, "U-02"], ["wait", 2.0], ["shot", "s5q_wake"],
				["check", "SQ_S05_WOKE > 0", "서서 걸어 2칸 안 — 승강장이 한꺼번에 일어난다"]]
		"rd":                                                           # 1-11c SQ-S04: 21시 경보(봉천) → 민원실 철망 → 레이더 철조망(힘 6) → 돔 전지 회수(E) → 대장간 인도 → 마을이 철망을 연다
			st.vars.set_v("PC_ST", 7)
			host.combat.pc.hp = 99999.0
			host.combat.pc.max_hp = 99999.0
			host.date_text = "2277. 10. 25.  14:00"
			st.quests.set_stage("MQ-102", 10)
			side4.tick()
			host.enter("X-BC", "from_X-S07")
			var rd: Vector2i = host.map.to_world("X-RD", 0, 0)                 # 레이더 손 맵 왼쪽 위(월드 칸) — 손 맵 좌표 + 이 값
			plan = [["wait", 1.0], ["gomark", "X-BC:land2"], ["settime", "2277. 10. 27.  21:00"],
				["until", "SQS04_STAGE == 10 and SQ_S04_HELD == 1", 20.0, "21시: 종 · 파수가 남솔을 안고 간다 — 단계 10", "rd_alarm"], ["wait", 3.0], ["shot", "rd_carry"],
				["warp", "K-33", "from_W"], ["wait", 1.5], ["shot", "rd_k33"],
				["check", "SQS04_STAGE >= 20", "민원실 — 철망 안 남솔(단계 20 이상)"],
				["settime", "2277. 10. 28.  10:00"], ["warp", "X-RD", "arrive"], ["wait", 1.0], ["shot", "rd_arrive"],
				["go", rd.x + 9, rd.y + 6], ["go", rd.x + 10, rd.y + 5], ["want", ["힘 6"]], ["use", rd.x + 11, rd.y + 5], ["wait", 1.0],
				["check", "SQ_S04_FENCE == 1", "장비동 뒤 철조망을 젖혔다"], ["shot", "rd_fence"],
				["go", rd.x + 13, rd.y + 6], ["go", rd.x + 17, rd.y + 9], ["go", rd.x + 17, rd.y + 8], ["wait", 1.5], ["shot", "rd_k36"],
				["go", 4, 7, "K-36"], ["want", ["뽑는다"]], ["use", 4, 6], ["wait", 1.0],
				["check", "SQ_S04_BATT == 1 and SQ_S04_SLEEP == 1 and has(\"M-162\")", "핵분열 전지 회수(해법 E) — 파수가 잠든다"],
				["warp", "X-BC", "from_X-S07"], ["wait", 1.0], ["want", ["전지를 보여", "마을에 쓰세요", "돌아선다"]], ["talkd", "N-R01-030"], ["wait", 1.5],
				["check", "SQH_BATT == 81", "대장간 남무진에게 — 옥탑 조명"],
				["settime", "2277. 10. 28.  18:30"], ["wait", 1.5],
				["check", "SQ_S04_OUT == 6 and SQS04_STAGE == 100", "잠든 뒤 여섯 시간: 남태하가 철망을 연다 — 종료"]]
		"bjs":                                                          # 1-12l D-081 · D-118: 사당 고개 도주 관리자 정지 → 손을 든다(회차) · 여의도 초소 문서 검문 → 인수증 · MQ-106 걸어 들어감 → 차단봉
			for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
				st.quests.set_stage(q, 100)
			st.vars.set_v("V_ACT", 1)
			st.quests.set_stage("MQ-101", 100)
			st.vars.set_v("MQ101_NIGHT", 3)
			st.quests.set_stage("MQ-104", 100)
			st.vars.set_v("MQ106_RESULT", 1)
			st.vars.set_v("AFF_BJ", -30)
			st.vars.set_v("SQ_S11_PASS", 1)
			st.vars.set_v("GAME_HOUR", 10)
			host.date_text = "2277. 10. 27.  10:00"
			host.enter("X-SG", "arrive")
			plan = [["noenc"], ["want", ["손을 든다"]], ["go", 1113, 1458], ["wait", 2.0], ["shot", "sg_stop"],
				["check", "BJS_SG_DAY == GAME_DAY", "사당 고개 — 도주 관리자 정지 · 손을 든다 · 회차(30분)"],
				["set", "MQ106_RESULT", 2], ["warp", "W", "@804,1094"], ["wait", 1.0], ["want", ["인수증"]], ["go", 804, 1090], ["wait", 2.0], ["shot", "yd_doc"],
				["check", "BJS_YD_DAY == GAME_DAY and BJS_KIND == 4", "여의도 초소 낮 문서 검문 → 선우진의 인수증으로 통과"],
				["set", "MQ106_RESULT", 4], ["set", "AFF_BJ", -15], ["warp", "X-SG", "arrive"], ["wait", 1.0], ["shot", "sg_boom"],
				["check", "BJS_SG_DAY == GAME_DAY", "걸어 들어감 + 중립 — 정지 없이(차단봉 오름은 화면으로)"]]
		"s04w":                                                         # 1-12l D-100: 별채 창고 창 [자물쇠 25] → 창고 → 철망 → 남솔 → 창고 창으로 나감
			for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
				st.quests.set_stage(q, 100)
			st.vars.set_v("V_ACT", 1)
			st.quests.set_stage("MQ-101", 100)
			st.vars.set_v("MQ101_NIGHT", 3)
			st.quests.set_stage("SQ-S04", 20)
			st.vars.set_v("SQ_S04_HELD", 1)
			st.vars.set_v("SQ_S04_SLEEP", 1)
			st.vars.set_v("PC_SKP_LOCKPICK", 50)
			host.enter("W", "@916,1393")
			plan = [["noenc"], ["wait", 1.0], ["go", 915, 1398], ["shot", "window_out"], ["want", ["[자물쇠 따기 25] 걸쇠"]], ["use", 915, 1399], ["wait", 2.0],
				["check", "map:K-33", "별채 창고 창 → 민원실 창고(K-33)"], ["shot", "storeroom"],
				["want", ["[자물쇠 따기 25] 휘장"]], ["go", 20, 12, "K-33"], ["use", 20, 11], ["wait", 2.0],
				["check", "SQ_S04_HELD == 0", "철망을 따고 남솔을 빼냄"],
				["want", ["창턱을 넘어"]], ["go", 27, 4, "K-33"], ["use", 27, 3], ["wait", 2.0],
				["check", "SQ_S04_WIN == 1 and SQ_S04_HELD == 0", "창고 창으로 나감 — 별채 옆 골목"], ["shot", "window_back"]]
		"mapk":                                                         # 1-12k 지도 화면: 망원경 훑기(원경 S 둘 + 금탑) → 봉천 링 화면 → 교역로 쌍(사다리 앞 → 사당 30분) → 벙커 앞 '여기였나'(단서 2)
			st.vars.set_v("V_ACT", 1)
			st.vars.set_v("V_REGCARD", 2)
			st.quests.set_stage("MQ-101", 50)
			st.vars.set_v("MQ101_NIGHT", 3)
			var m101 := Mq101.new()                                      # 망원경 `mq panorama`는 MQ-101 진행기의 명령(start 없이 명령만 잇는다)
			add_child(m101)
			m101.setup(host, true, false)
			host.ev.handlers["mq"] = m101._mq_cmd
			host.enter("W", "L-R01-03")
			var tel := _spot_find("L-R01-03", "telescope")
			plan = [["go", tel.x, tel.y + 1], ["shotin", "scope", 4.0], ["shotin", "scope_labels", 11.0], ["use", tel.x, tel.y], ["wait", 1.0], ["shot", "after_scope"],
				["check", "LM_SEEN == 1049095 and PL_VIEW == 1", "망원경 → 원경 표식 S 둘(비트 0 · 1) + 금탑 · 레이더 돔 · 도곡 3탑(반경 안)"],
				["warp", "W", "L-R01-09"], ["wait", 1.5], ["shot", "ring_bc"],
				["check", "LM_SEEN >= 7", "봉천에서 금탑 · 레이더 돔 등록 비트"],
				["set", "SQ_S05_SOL", 1], ["found", "L-R01-18"], ["warp", "W", "L-UG-02"], ["wait", 1.0], ["shot", "ladder"],
				["travel", "L-R01-18"], ["wait", 4.0], ["check", "map:X-SD", "사다리 앞 → 사당 환승촌 지하 교역로"], ["shot", "sadang"],
				["warp", "W", "L-R02-02"], ["wait", 2.0],
				["check", "MQ102_MAPC == 2 and MQ102_C2 == 1 and MQ104_STAGE >= 10", "카드 숫자만 보고 벙커 앞에 서면 단서 2(여기였나)"]]
		"turf":                                                         # 1-12m 판도: 신림을 본다 → 두목 처치(은신처 공백) · 사흘 뒤 다시 들어서면 '깃발이 바뀌어' + 아는 판 고침 → 장부를 정착지에 · 황두칠 사망 → 가리봉
			st.vars.set_v("V_ACT", 1)
			st.vars.set_v("GAME_DAY", 1)
			host.enter("W", "L-R01-14")
			plan = [["wait", 1.5], ["check", "turf:PD-R01-3:2", "신림 · 도림천을 밟자 아는 판 = 약탈자 우세"],
				["set", "SQ_S02_CAMP", 1], ["set", "GAME_DAY", 3], ["warp", "W", "L-R01-09"], ["wait", 1.0],
				["check", "turf:PD-R01-3:2", "가 보기 전엔 옛 판(아는 만큼만)"],
				["warp", "W", "L-R01-14"], ["wait", 1.0], ["shot", "turf_hint"],
				["check", "turf:PD-R01-3:0", "다시 들어서면 공백으로 고쳐 적음"], ["check", "turfhint:깃발이 바뀌어", "알던 판과 다르면 알림"],
				["check", "PDS_R01_3 == 0", "이야기 변수(방송 · 소문 조건)"],
				["set", "HO_LEDGER", 81], ["warp", "W", "L-R02-19"], ["wait", 1.0],
				["check", "PDS_R02_4 == 2 and PDS_R02_5 == 0", "장부를 봉천에: 구로 지배 → 우세 · 고척 공백(D-133)"],
				["check", "turf:PD-R02-4:2", "가리봉 아는 판"],
				["found", "L-R02-19"], ["check", "fbook:SB", "새벽인력 본소를 발견하면 세력 기록 등록"]]
		"place":                                                        # 1-5e 손 장소: 전망바위 → 연수원 본관(LR-19)·기숙사(LR-11) → 계곡 배수로(정비공) → 경찰서 무기고(자물쇠 50) → 공영방송(LR-01)
			st.vars.set_v("PC_SKP_LOCKPICK", 50)
			st.vars.set_v("PC_SKP_SMALL_GUNS", 40)
			for kv in [["M-070", 4], ["I-001", 10], ["10mm 탄", 200]]:
				st.call_fn("give", kv)
			host.enter("W", "L-R01-03")
			var tel := _spot_find("L-R01-03", "telescope")
			plan = [["go", tel.x, tel.y + 1], ["shoton", "세진전자 타워", "view"], ["use", tel.x, tel.y], ["wait", 0.5],
				["check", "PL_VIEW == 1 and PC_CAPS == 612", "전망바위 망원경 → 지도 표시 · 동전 12캡"],
				["warp", "W", "L-R01-06"], ["wait", 1.0], ["face", 6], ["shot", "k01_door"], ["use", _door("K-01").x, _door("K-01").y], ["wait", 2.0], ["shot", "k01"], ["fight"],
				["go", 3, 5, "K-01"], ["use", 3, 4], ["wait", 0.5], ["check", "has(\"M-230\") and PL_LETTER == 1", "교관 책상 서랍의 LR-19(M-230)"],
				["go", 15, 3], ["go", 15, 0], ["wait", 1.5], ["shot", "k02"], ["fight"], ["go", 37, 7, "K-02"], ["use", 37, 6], ["wait", 0.5],
				["check", "read:LR-11", "기숙사 끝 해골의 「종전」 유인물(LR-11)"]]
			plan += [["warp", "K-08"], ["wait", 1.5], ["shot", "k08"], ["fight"], ["go", 44, 5, "K-08"], ["use", 44, 4], ["wait", 0.5],
				["check", "PL_TECH == 1", "배수로 정비공의 수질 측정지"],
				["warp", "K-29"], ["wait", 1.5], ["shot", "k29"], ["fight"], ["go", 21, 11, "K-29"], ["use", 21, 10], ["lock"], ["wait", 1.0],
				["go", 21, 6, "K-29"], ["check", "STAT_LOCKS == 1", "경찰서 무기고 문(자물쇠 50)을 따고 들어감"], ["shot", "k29_armory"],
				["warp", "K-06"], ["wait", 1.5], ["fight"], ["go", 8, 5, "K-06"], ["use", 8, 4], ["wait", 0.5], ["shot", "k06"],
				["check", "read:LR-01", "앵커석의 심야 뉴스 대본(LR-01)"]]
		"yd_talk", "yd_fight", "yd_vent":                               # MQ-104(1-5): 해치 → 방화문 → 작은 방 → 집결지 조사 → 인증 → 수색조 세 갈래
			_yd_plan()
		"sb_buy", "sb_deal", "sb_capture", "sb_raid", "sb_roof", "sb_jo", "sb_south":   # MQ-105(1-6) 새벽인력 본소 · R02 남쪽 탐험 묶음
			_sb_plan()
		"vb_talk", "vb_walk", "vb_fight", "vb_hide", "vb_cargo", "vb_capture":   # MQ-106(1-7) 첫 번째 추적자 · 막 전환
			_vb_plan()
	plan.append(["end"])


## MQ-106: K_CODE를 안 채로 연수원 본관(K-01)에서 바깥으로 나온다 → 무전 → 30초 뒤 버티버드 → 해법 여섯 갈래 → 막 전환(V_ACT 2)
## 굽힌 발견물(data/world/pois.json의 texts·boxes)에서 글·이름에 sub가 든 것 중 near에 가장 가까운 칸
## 굽기 결과(place_geo.json)에서 자리 찾기 — 도로망이 바뀌어도 봇이 따라간다(SD-21 §8 '봇·시험 좌표 → 장소 ID 기준')
static var _geo := {}


func _geo_d() -> Dictionary:
	if _geo.is_empty():
		_geo = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/place_geo.json"))
	return _geo


## 월드 → 실내 문(to = 실내 맵 ID)의 문 칸
func _door(to: String) -> Vector2i:
	for d in _geo_d().get("_doors", []):
		if str(d.get("to", "")) == to:
			return Vector2i(int(d["at"][0]), int(d["at"][1]))
	push_error("봇: 문을 못 찾았다 " + to)
	return Vector2i.ZERO


## 손 장소 자리(spot) 원점
func _spot_o(lid: String) -> Vector2i:
	for sp in _geo_d().get("_spots", []):
		if str(sp.get("lid", "")) == lid:
			return Vector2i(int(sp["at"][0]), int(sp["at"][1]))
	push_error("봇: 장소 자리를 못 찾았다 " + lid)
	return Vector2i.ZERO


## 손 장소 자리 안의 소품·조사 글·인물(이름·글·ID에 sub가 든 첫 것)의 월드 칸
func _spot_find(lid: String, sub: String) -> Vector2i:
	for sp in _geo_d().get("_spots", []):
		if str(sp.get("lid", "")) != lid:
			continue
		var data: Dictionary = sp["data"]
		if (data.get("marks", {}) as Dictionary).has(sub):                    # 표지 이름(1-11c 주민센터 'sentry' — 파수 그림은 진행기가 세운다)
			var mk: Array = data["marks"][sub]
			return Vector2i(int(sp["at"][0]) + int(mk[0]), int(sp["at"][1]) + int(mk[1]))
		for grp in ["texts", "props", "npcs", "boxes"]:
			for e in data.get(grp, []):
				if (str(e.get("text", "")) + str(e.get("name", "")) + str(e.get("id", ""))).contains(sub):
					return Vector2i(int(sp["at"][0]) + int(e["x"]), int(sp["at"][1]) + int(e["y"]))
	push_error("봇: 자리 안 '%s'를 못 찾았다 %s" % [sub, lid])
	return Vector2i.ZERO


## 발견물 옆에 설 칸: 아래 → 위 → 옆 순으로 걸을 수 있는 칸(다시 구우면 아래 칸이 막힐 수 있다)
func _stand(c: Vector2i) -> Vector2i:
	host.map.load_now(Vector2(c) * 32.0)
	for n in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1)]:
		var t: Vector2i = c + n
		if not host.map.is_solid(t) and host.map.deck_at(t) not in [InteriorMap.DK_WALL, InteriorMap.DK_PILLAR]:
			return t
	return c + Vector2i(0, 1)


func _poi_at(group: String, sub: String, near: Vector2i) -> Vector2i:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/pois.json"))
	var best := near
	var bd := INF
	for p in d.get(group, []):
		if not (str(p.get("text", "")) + str(p.get("name", ""))).contains(sub):
			continue
		var t := Vector2i(int(p["x"]), int(p["y"]))
		var dd := Vector2(t - near).length()
		if dd < bd:
			bd = dd
			best = t
	return best


func _vb_plan() -> void:
	st.quests.set_stage("MQ-102", 100)
	st.quests.set_stage("MQ-104", 100)
	st.vars.set_v("K_CODE", 1)
	st.vars.set_v("K_NET", 1)
	st.vars.set_v("MQ104_AUTH", 1)
	st.vars.set_v("V_DOYUN", 1 if route in ["vb_cargo", "vb_walk"] else 2)
	st.vars.set_v("PC_SKP_SPEECH", 90)
	st.vars.set_v("PC_SKP_LOCKPICK", 50)
	st.vars.set_v("PC_SKP_SMALL_GUNS", 60)
	for kv in [["M-070", 6], ["I-001", 20], ["10mm 탄", 600], ["I-036", 2]]:
		st.call_fn("give", kv)
	host.date_text = "2277. 10. 26.  10:00"
	if route == "vb_fight":                                               # 싸움 갈래 기계 확인: 넉넉한 체력(맵을 옮긴 뒤 'hp' 단계에서) · 총 솜씨
		st.vars.set_v("PC_SKP_SMALL_GUNS", 100)
	host.enter("K-01", "from_W")
	var first := {"vb_talk": ["[화술 보통]"], "vb_walk": ["(무기를 집어넣고"], "vb_fight": ["서류는 너희 사정"], "vb_hide": ["(뒤돌아 달아난다)"],
		"vb_cargo": ["(뒤돌아 달아난다)"], "vb_capture": ["서류는 너희 사정"]}
	plan = [["want", first[route]], ["go", 14, 15], ["wait", 1.0], ["hp", 3000 if route == "vb_fight" else (6 if route == "vb_capture" else 0)],
		["check", "MQ106_STAGE == 10", "실내에서 나오자 무전(단계 10)"],
		["until", "state:fly", 30.0, "18초 뒤 버티버드가 날아온다"], ["wait", 4.0], ["shot", "vb_fly"], ["wait", 4.5], ["shot", "vb_descend"],
		["until", "state:stand", 20.0, "내려앉는다(하강 · 먼지 · 흔들림)", "vb_landed"],
		["check", "vb_blocks", "내려앉은 기체 밑 칸이 막힌다"]]
	match route:
		"vb_talk":
			plan += [["shoton", "서류대로", "vb_yuk"], ["until", "MQ106_STAGE == 100", 40.0, "철수"],
				["wait", 3.0], ["shot", "vb_lift"],
				["check", "MQ106_RESULT == 3 and AFF_BJ == -25 and V_WANTED >= 30", "말: 비상 +5(−30 → −25) · 수배 공고 30"]]
		"vb_walk":
			plan += [["shoton", "맞은편 의자", "vb_ride"], ["until", "map:CG-05", 40.0, "걸어 들어감 → 청계산 귀빈실"],
				["wait", 2.0], ["shot", "cg05"], ["check", "has(\"W-002\") == 0", "무기는 정문 보관함에"],
				["go", 17, 14], ["want", ["알겠다"]], ["talk", "N-R11-005"],
				["go", 31, 15], ["shoton", "서명한 사람이", "namgung"],
				["want", ["왜 하필", "날 쫓은", "관제망이", "죽은 사람", "(일어선다)"]], ["talk", "C-003"], ["wait", 1.0],
				["check", "K_SIGNER == 1 and K_LINEAGE == 1 and MQ106_TALKED == 1", "남궁혁 면담: 서명자 · 계보(K_SIGNER · K_LINEAGE)"],
				["want", ["(사흘을 보낸다)"]], ["talk", "C-003"], ["until", "MQ106_STAGE == 100", 40.0, "사흘째 아침 관악 산자락"], ["wait", 2.0], ["shot", "vb_drop"],
				["check", "MQ106_RESULT == 4 and AFF_BJ == -15 and has(\"W-002\") and WANTED_HOLD > 0 and V_WANTED < 30", "걸어 들어감: 비상 +15 · 무기 돌려받음 · 출두 확인(등급 1)"],
				["check", "V_DOYUN == 1", "기체 안에서 마주 앉기만(구출 아님)"]]
		"vb_fight":
			plan += [["fight"], ["until", "MQ106_STAGE == 100", 60.0, "분대가 무너지면 철수"],
				["wait", 3.0], ["shot", "vb_after"],
				["check", "MQ106_RESULT == 1 and AFF_BJ == -45 and V_WANTED >= 30", "싸움: 비상 −15 · 수배 +10 이상"]]
		"vb_hide":
			plan += [["wait", 2.0], ["warp", "K-01"], ["wait", 62.0], ["warp", "W", "L-R01-06"], ["wait", 1.0],
				["check", "MQ106_RESULT == 2 and MQ106_STAGE == 100 and AFF_BJ == -30", "숨음: 건물 안에서 1분 — 비상 0"]]
		"vb_cargo":
			plan += [["wait", 1.0], ["want", ["[자물쇠 따기 50]"]], ["godoor"], ["talk", "C-002"], ["lock"], ["wait", 3.0], ["shot", "vb_doyun"],
				["check", "V_DOYUN == 2 and V_KARMA >= 100", "화물칸 철창(자물쇠 50) → 하도윤 구출 · 카르마 +100"],
				["warp", "K-01"], ["wait", 62.0], ["warp", "W", "L-R01-06"], ["wait", 1.0], ["check", "MQ106_RESULT == 2", "숨음으로 마침"]]
		"vb_capture":
			plan += [["until", "map:CG-05", 80.0, "쓰러짐 → 생포 → 귀빈실"], ["wait", 2.0], ["shot", "cg05_taken"],
				["check", "MQ106_CUSTODY == 2 and MQ106_SEIZED == 1 and has(\"W-002\") == 0 and has(\"I-001\") == 0", "소지품 압수(무기 · 스팀팩)"],
				["go", 31, 15], ["want", ["(일어선다)"]], ["talk", "C-003"], ["wait", 1.0],
				["want", ["(사흘을 보낸다)"]], ["talk", "C-003"], ["until", "MQ106_STAGE == 100", 40.0, "내려 줌"],
				["check", "MQ106_RESULT == 5 and AFF_BJ == -25", "생포: 비상 +5"], ["check", "place_marked:L-R11-02", "압수품 보관함 자리가 지도에"]]
	plan += [["check", "V_ACT == 2", "막 전환 1 → 2"], ["wait", 4.0], ["shot", "act2_after"]]
	for k in plan.size():                                               # 막 제목 카드는 MQ-106이 끝나는 순간 뜬다: 그 '기다림' 바로 뒤에서 본다
		var st_: Array = plan[k]
		if str(st_[0]) == "until" and str(st_[1]) == "MQ106_STAGE == 100":
			plan.insert(k + 1, ["until", "card", 30.0, "막 제목 카드 「2막 강」", "act2_card"])
			break


## MQ-105 본소(손 맵 X-SB 원점 606,1307): 구매자(열쇠 은신 50 → 금고 → 장부 → 마당 화로) · 거래(물물교환 50 + 1,000캡) ·
## 생포(볼트 작업복으로 정문 → 손을 내민다 → 우리 · 여섯 풀기 · 목걸이) · 정면 습격 · 옥상(사다리·판자 다리 → 뚜껑 → 금고 50 → 노량진 초소) · 조만석 인도
func _sb_plan() -> void:
	var O := Vector2i(606, 1307)
	var W := func(x: int, y: int) -> Array: return ["go", O.x + x, O.y + y]
	st.vars.set_v("PC_CAPS", 1500 if route == "sb_deal" else 800)
	st.vars.set_v("PC_TORSO", "A-001" if route == "sb_capture" else "A-016")
	st.call_fn("give", ["A-016", 1])
	st.vars.set_v("PC_SKP_SNEAK", 50)
	st.vars.set_v("PC_SKP_BARTER", 50)
	st.vars.set_v("PC_SKP_LOCKPICK", 50)
	st.vars.set_v("PC_SKP_REPAIR", 50)
	st.vars.set_v("PC_SKP_SMALL_GUNS", 60 if route == "sb_raid" else 20)
	st.vars.set_v("PC_ST", 7)
	for kv in [["M-070", 6], ["I-001", 20], ["10mm 탄", 400]]:
		st.call_fn("give", kv)
	if route == "sb_raid":                                              # 습격 기계 확인용: 개는 빼고(뒷마당 담 너머), 체력을 넉넉히
		st.vars.set_v("SB_DOGS", 1)
		host.combat.pc.max_hp = 3000.0
		host.combat.pc.hp = 3000.0
	if route == "sb_roof":
		host.date_text = "2277. 10. 25.  04:20"                      # 인력시장 시간: 소장실이 빈다
	if route == "sb_jo":
		st.call_fn("give", ["M-211", 1])
		st.quests.set_stage("MQ-105", 30)
		host.enter("B-01", "from_X-BC")
		plan = [["want", ["장부를 건넨다"]], ["talk", "C-010"], ["wait", 1.0],
			["check", "HO_LEDGER == 81", "조만석에게 장부(HO 81)"], ["check", "has(\"M-211\") == 0 and MQ105_STAGE == 100", "장부를 건넴 · 단계 100"],
			["check", "AFF_JC >= 5", "연합 일괄 +5"]]
		return
	if route == "sb_south":                                            # 쪽방 할매 → 잠 → 벽 사이 통로 → 창고동 우리에서 127번 → 아내 → LR-47 → 신도림 우산
		st.vars.set_v("PC_CH", 8)
		st.vars.set_v("PC_SKP_SPEECH", 80)
		host.date_text = "2277. 10. 25.  18:00"                       # 8시간 자고 02시 — 우리 열기는 02~04시(1-11h SQ-S09 B, 그 밖엔 감시 의자 경비)
		st.vars.set_v("PC_SKP_LOCKPICK", 30)
		st.vars.set_v("PC_SKP_REPAIR", 60)
		host.combat.pc.hp = host.combat.pc.max_hp * 0.5
		host.enter("W", "L-R02-20")
		plan = [["wait", 1.0], ["face", 6], ["shot", "k20_door"], ["use", _door("K-20").x, _door("K-20").y], ["wait", 2.0], ["shot", "k20"],
			["go", 27, 12, "K-20"], ["go", 27, 7], ["want", ["벽장에서", "[화술 쉬움]"]], ["talk", "N-R02-042"], ["wait", 1.0], ["check", "GB_PASS == 1", "길금순이 벽장 통로를 알려 준다(화술 쉬움)"],
			["want", ["눈을 붙이고"]], ["talk", "N-R02-042"], ["wait", 4.0], ["check", "GAME_HOUR == 2 or GAME_HOUR == 3", "은신처에서 잠(8시간)"],
			["check", "hp_full", "자고 나면 체력이 찬다"],
			["go", 27, 3, "K-20"], ["go", 27, 1], ["go", 27, 0], ["wait", 1.5], ["shot", "k23"], ["go", 29, 4, "K-23"], ["go", 31, 4], ["wait", 1.5],
			["check", "map:H-03", "벽 사이 통로 끝 = 창고동 우리 벽 판자 틈"], ["shot", "k23_h03"],
			["go", 10, 9, "H-03"], ["want", ["자물쇠 따기"]], ["use", 10, 8], ["wait", 2.0], ["want", ["수리 50"]], ["use", 10, 8], ["wait", 2.0],
			["check", "SB_127 == 2 and SB_RAID == 0", "127번을 우리에서 빼 옴(02~04시 · 문 → 목걸이, 1-11h 절차)"],
			["warp", "K-20", "from_K-23"], ["wait", 1.0], ["want", ["같이 가자", "채윤재", "여기 남아"]], ["talk", "N-R02-039"],
			["until", "map:K-22", 20.0, "같이 가자 — 구로 107동", "k22"], ["wait", 5.0], ["shot", "k22_reunion"],
			["check", "SQ_S09_PLACE == 1 and SQS09_STAGE == 100", "아내: 빼 온 남편을 이름으로 — 구로 107동에 남음(1-11h 재회)"],
			["go", 33, 8, "K-22"], ["use", 33, 7], ["wait", 2.0], ["check", "read:LR-47", "지하주차장 기둥의 LR-47"],
			["warp", "W", "L-R02-24"], ["wait", 1.5], ["shot", "umbrella"], ["go", 665, 1200], ["face", 6], ["shoton", "순댓국", "commuter"], ["use", 665, 1199], ["wait", 2.0],
			["check", "seen_commuter", "신도림 우산 바리케이드의 출근길 유해"]]
		return
	host.enter("W", "L-R02-19")
	plan = [["shot", "sb_front"], W.call(22, 39)]
	match route:
		"sb_buy":
			plan += [["want", ["사람을 사러", "[캡 500]"]], W.call(22, 37), ["wait", 1.0], ["shot", "sb_gate"],
				["check", "SB_PASS == 1 and SB_DEPO == 1 and PC_CAPS == 300", "정문 보증금 500 → 손님 표찰"],
				W.call(22, 30), ["check", "MQ105_STAGE == 20", "담 안에 들어서면 단계 20"], ["shot", "sb_yard"], W.call(19, 11), W.call(19, 10),
				["go", 10, 17, "H-02"], ["shot", "sb_h02"], ["go", 4, 3], ["go", 4, 0], ["wait", 1.0],
				["go", 28, 7, "H-04"], ["go", 28, 11], ["want", ["[캡 300] 88번", "[은신 50]"]], ["talk", "C-013"], ["shot", "sb_hdc"],
				["check", "SB_BOUGHT == 1 and PC_CAPS == 500 and SB_KEY == 1 and SB_TALK == 2", "88번을 삼(보증금 환급) · 허리춤 열쇠(은신 50)"],
				["go", 36, 12], ["want", ["열쇠를 꽂는다", "장부를 챙긴다"]], ["use", 36, 11], ["wait", 3.0], ["shot", "sb_safe"],
				["check", "SB_READ == 1 and K_CODE == 1 and K_NET == 1 and has(\"M-211\") and has(\"M-212\") and MQ105_STAGE == 30", "장부·의뢰서 → K_CODE · 단계 30"],
				["go", 28, 10], ["go", 28, 7], ["go", 1, 5], ["go", 0, 5], ["wait", 1.0], ["go", 10, 18, "H-02"], ["go", 10, 19], ["wait", 1.5],
				W.call(28, 18), W.call(28, 17), ["want", ["불에 던진다"]], ["shoton", "규정 제1조는", "sb_burn"], ["use", O.x + 29, O.y + 17], ["wait", 1.5],
				["check", "HO_LEDGER == 99 and SB_DEBT == 1 and MQ105_STAGE == 100 and has(\"M-211\") == 0", "마당 화로에 태움(HO 99 · 112명 빚)"],
				["check", "SB_RAID == 1", "불길에 마당이 술렁인다 → 습격"]]
		"sb_deal":
			plan += [["want", ["돈 얘기다"]], W.call(22, 37), ["wait", 1.0],
				["check", "SB_PASS == 2", "정문: 소장한테 돈 얘기(1,000캡 이상)"], W.call(19, 11), W.call(19, 10),
				["go", 4, 3, "H-02"], ["go", 4, 0], ["wait", 1.0], ["go", 28, 7, "H-04"], ["go", 28, 11],
				["want", ["[물물교환 50]"]], ["shoton", "줄은 긋지", "sb_deal"], ["talk", "C-013"], ["wait", 3.0],
				["check", "SB_DEAL == 1 and HO_LEDGER == 96 and MQ105_STAGE == 100 and K_CODE == 1 and PC_CAPS == 500 and AFF_SB == -10", "거래: 이름에 줄 · 수배 −30 · 새벽 +15"],
				["check", "read:SB-ORDER7", "의뢰서와 지령 제7호 사본을 읽음"]]
		"sb_capture":
			plan += [["want", ["손을 내민다"]], W.call(22, 37), ["wait", 4.0], ["shot", "sb_cage"],
				["check", "CAPTURE_BY == 1 and SB_CUFF == 1 and SB_COLLAR == 1", "볼트 작업복으로 정문 → 손을 내밀어 우리로"],
				["go", 16, 6, "H-03"], ["want", ["벽에 기대"]], ["go", 16, 7], ["wait", 3.0], ["check", "GAME_HOUR == 2", "벽에 기대 눈 붙임 — 새벽 두 시(1-11h)"],
				["go", 16, 6], ["want", ["[힘 7]"]], ["go", 16, 7], ["wait", 1.0], ["check", "SB_CUFF == 0", "수갑·우리 문(힘 7)"],
				["go", 16, 9], ["go", 10, 9], ["want", ["[힘 7]"]], ["use", 10, 8], ["wait", 0.8], ["want", ["수리 50"]], ["use", 10, 8], ["wait", 0.8], ["shot", "sb_free127"],
				["go", 4, 9], ["want", ["[힘 7]"]], ["use", 4, 8], ["wait", 0.8], ["go", 22, 9], ["use", 22, 8], ["wait", 0.8],   # 22번 칸은 SQ-S10 문 장면(1-11i) — 메뉴의 [힘 7]
				["go", 28, 9], ["use", 28, 8], ["wait", 0.8], ["go", 34, 9], ["use", 34, 8], ["wait", 0.8], ["shot", "sb_freed"],
				["check", "SB_FREED >= 6 and V_KARMA >= 100", "'인력' 여섯을 풀어 줌(카르마 +100)"],
				["want", ["[수리 50]"]], ["go", 40, 5], ["wait", 1.5], ["check", "SB_COLLAR == 0", "목걸이 해제(수리 50)"]]
		"sb_raid":
			plan += [["hp", 3000], ["want", ["총을 꺼낸다"]], W.call(22, 37), ["wait", 1.0], ["check", "SB_RAID == 1", "정문에서 총 → 정면 습격"],   # 맵에 든 뒤 체력(시작 때 넣은 값은 맵 진입에서 200으로 돌아감)
				["fight"], ["shot", "sb_raid_yard"], W.call(19, 11), W.call(19, 10), ["fight"], ["go", 4, 3, "H-02"], ["go", 4, 0], ["wait", 1.0],
				["fight"], ["go", 28, 11, "H-04"], ["fight"], ["shot", "sb_hdc_down"], ["wait", 2.0],
				["check", "D_HDC == 1 and SB_RAID == 2 and SB_READ == 1", "황두칠 사살 → 외투의 의뢰서(K_CODE)"]]
		"sb_roof":
			plan += [["crouch", true], W.call(5, 10), W.call(5, 9), W.call(5, 6), W.call(9, 5), W.call(12, 5), ["shot", "sb_roof"],
				W.call(27, 7), ["want", ["내려간다"]], ["face", 6], ["use", O.x + 27, O.y + 6], ["wait", 1.5],
				["check", "SB_RAID == 0", "옥상 길로 들키지 않고 2층"], ["go", 28, 7, "H-04"], ["go", 28, 11], ["go", 36, 12],
				["want", ["[자물쇠 따기 50]", "장부를 챙긴다"]], ["use", 36, 11], ["lock"], ["wait", 3.0],
				["check", "SB_READ == 1 and has(\"M-211\")", "인력시장 시간 빈 소장실 금고(자물쇠 50) → 장부"],
				["go", 28, 7], ["go", 27, 3], ["go", 27, 0], ["wait", 1.5], W.call(12, 5), W.call(9, 5), W.call(5, 6), W.call(5, 10), W.call(1, 20),
				["check", "MQ105_STAGE == 100 and HO_LEDGER == 0", "장부를 들고 본소를 나서면 끝(HO 0)"], ["crouch", false],
				["warp", "W", "L-R01-20"], ["wait", 1.0], ["want", ["장부를 넘긴다"]], ["talk", "N-R01-050"], ["wait", 1.0], ["shot", "sb_bj"],
				["check", "HO_LEDGER == 1 and SB_BJ == 1 and AFF_BJ == -20", "노량진 다리목 초소에 넘김(비상 +10)"]]


## MQ-104 공통 앞부분(해치·방화문·서랍·유해·출석부·당직 일지·인증)과 갈래별 뒷부분
func _yd_plan() -> void:
	st.vars.set_v("V_DOYUN", 1)
	st.vars.set_v("PC_ST", 6 if route == "yd_talk" else 5)                # 방화문: 말로 갈래는 힘 6, 나머지는 쇠파이프(W-040)
	st.vars.set_v("PC_SKP_SCIENCE", 50)
	st.vars.set_v("PC_SKP_LOCKPICK", 50 if route == "yd_vent" else 0)
	st.vars.set_v("PC_SKP_SMALL_GUNS", 40 if route == "yd_fight" else 0)
	for kv in [["W-040", 1], ["M-070", 3], ["10mm 탄", 200], ["I-001", 10]]:
		st.call_fn("give", kv)
	host.enter("W", "L-R02-02")
	var tk := _spot_find("L-R02-28", "계엄군 호송차")                       # 호송차 조사 글 칸(도로망이 바뀌어도 따라간다)
	plan = [["shot", "hatch"], ["go", _door("Y-00").x, _door("Y-00").y], ["shot", "stairs"], ["check", "MQ104_STAGE == 20", "해치로 내려가면 단계 20"],
		["go", 6, 12, "Y-00"], ["want", ["[힘 6]", "[물건: W-040"]], ["use", 6, 13], ["shot", "firedoor"],
		["check", "MQ104_FIRE == 1", "방화문을 비틀어 열었다"], ["go", 5, 26], ["go", 5, 27],
		["go", 9, 5, "Y-01"], ["use", 9, 4], ["check", "K_SIGNER == 1 and has(\"M-228\")", "서랍의 반대 의견서(K_SIGNER)"], ["shot", "small_room"],
		["go", 12, 2], ["go", 12, 0], ["shot", "hall"],
		["go", 19, 18, "Y-02"], ["want", ["거둔다"]], ["shoton", "열두 구", "remains"], ["use", 19, 17], ["wait", 0.5],
		["go", 13, 22], ["use", 13, 21], ["wait", 0.5], ["go", 26, 22], ["use", 26, 21], ["wait", 0.5],
		["check", "MQ104_STAGE == 30 and has(\"M-209\") and has(\"M-210\") and K_LINE == 1", "출석부·당직 일지·유해 → 단계 30"],
		["go", 30, 4], ["shoton", "녹색 화면", "auth"], ["use", 30, 3], ["wait", 0.5],
		["check", "MQ104_STAGE == 40 and K_CODE == 1 and K_NET == 1 and MQ104_SEARCH == 1", "인증 단말 → K_CODE·K_NET · 단계 40"]]
	match route:
		"yd_talk":                                                      # 기다렸다 과학 50으로 돌려보낸다 → 방폭문(인증으로 열림) 너머 마지막 쪽지 → 계단으로
			plan += [["want", ["[과학 50]"]], ["go", 20, 20], ["shoton", "선우진 중위", "sunwoo"], ["wait", 14.0],
				["check", "MQ104_SEARCH == 4 and AFF_BJ == -25", "선우진을 말로 돌려보냄(비상 +5)"],
				["go", 38, 13], ["go", 39, 13], ["go", 3, 13, "Y-04"], ["go", 5, 8], ["use", 5, 7], ["wait", 0.5],
				["check", "MQ104_LAST == 1", "방폭문 너머 관리자의 마지막 쪽지"], ["go", 3, 28], ["go", 3, 29],
				["go", 19, 26, "Y-02"], ["go", 19, 27], ["go", 1, 8, "Y-01"], ["go", 0, 8], ["go", 5, 1, "Y-00"], ["go", 5, 0],
				["check", "MQ104_STAGE == 100", "벙커를 나서면 끝"], ["go", tk.x, tk.y + 3, "W"], ["shoton", "관리자 후보님", "guard_bark"], ["talk", "CR-401"], ["wait", 2.0], ["check", "seen_guard", "초소 병사가 '관리자 후보'라 부른다"]]
		"yd_fight":                                                     # 총을 든다 → 수색조 다섯 → 초소가 빈다 → 호송차 열쇠로 하도윤
			plan += [["want", ["총을 든다"]], ["wait", 14.0], ["fight"], ["shot", "squad_down"],
				["check", "MQ104_SEARCH == 2 and MQ104_GUARDS == 1 and AFF_BJ == -40", "수색조 격퇴(비상 -10) · 초소가 빈다"],
				["go", 34, 5], ["want", ["가져간다"]], ["use", 34, 4], ["check", "has(\"W-017\")", "경비 장교의 소총"],
				["go", 19, 26], ["go", 19, 27], ["go", 1, 8, "Y-01"], ["go", 0, 8], ["go", 5, 1, "Y-00"], ["go", 5, 0],
				["check", "MQ104_STAGE == 100", "벙커를 나서면 끝"],
				["go", tk.x, tk.y + 1, "W"], ["shoton", "초소가 비었다", "truck_empty"], ["use", tk.x, tk.y], ["wait", 1.0],
				["check", "V_DOYUN == 2 and MQ104_DOYUN == 1 and MQ104_STAGE == 100", "빈 초소의 열쇠로 하도윤 구출(V_DOYUN 2)"]]
		"yd_vent":                                                      # 인증 뒤 기계실 환기구 → 배수로(은신) → 둑 → 호송차 자물쇠 50
			plan += [["go", 5, 2], ["go", 5, 0], ["go", 15, 3, "Y-03"], ["use", 15, 2], ["wait", 0.3],
				["want", ["기어 들어간다"]], ["use", 15, 2], ["shot", "drain"],
				["check", "MQ104_SEARCH == 3", "수색조가 내려오기 전에 환기구로 빠짐(은신)"], ["wait", 1.5], ["shot", "drain_tunnel"], ["fight"],
				["go", 38, 4, "Y-05"], ["go", 39, 4], ["check", "MQ104_STAGE == 100", "둑 배수구로 나오면 끝"],
				["go", tk.x, tk.y + 1, "W"], ["shot", "post"], ["want", ["[자물쇠 따기 50]"]], ["use", tk.x, tk.y], ["lock"],
				["wait", 1.5], ["check", "V_DOYUN == 2 and STAT_LOCKS == 1", "호송 칸 자물쇠를 땄다(V_DOYUN 2)"]]


var _hint_log: Array = []                            ## 지나간 알림 글(1-12m turfhint 확인)


func _process(dt: float) -> void:
	if host != null:
		for h in host.hints:
			if not _hint_log.has(str(h[0])):
				_hint_log.append(str(h[0]))
	t += dt
	step_t += dt
	if t > 400.0:
		_finish("시간 초과")
		return
	_box(dt)
	if str(host.ev._job.get("kind", "")) == "card":
		seen["card"] = true                                          # 막 제목 카드는 싸움 단계 안에서 떴다 질 수 있다 — 본 적이 있으면 'card' 기다림이 넘어간다
	if i >= plan.size():
		return
	var s: Array = plan[i]
	for c in host.get_children():                                      # 종이 기록물 창: 한 장 찍고 끝 쪽까지 넘겨 닫는다
		if c is NoteScreen:
			note_t += dt
			if note_t > 1.2:
				note_t = 0.0
				if c.page == 0:
					seen["note"] = true
					_shot("note_" + str(c.note.get("title", "")).substr(0, 8).replace(" ", "_"))
				if c.page < c._pages.size() - 1:
					c.page += 1
				else:
					c.close(true)
			return
	if str(s[0]) == "until" and _until(s):
		return
	if host.box.active or host.ev.busy() or host.busy:
		host.input_fn = func() -> Vector2: return Vector2.ZERO
		if s[0] != "fight":
			return
	match str(s[0]):
		"u04go":                                                        # 1-D10 수레 뒤 칸으로(레일 방향 동쪽으로 밀 자리)
			plan[i] = ["go", u04.cart_x() - 1, u04._row(), host.map.id]
			return
		"rqnight":                                                      # 1-12j RQ-30: 그날 밤 사건 방향의 봉천 표지로(아랫문 · 윗문 · 뒷산)
			plan[i] = ["gomark", str(RqR01.NIGHT_MARK.get(int(st.vars.get_v("RQ30_DIR")), "X-BC:sbf2"))]
			return
		"hold":                                                         # 1-D10 한 방향으로 계속 걷는다(수레 밀기 — 막히면 서고, 수레가 비키면 간다)
			host.input_fn = func() -> Vector2: return Vector2(float(s[1]), float(s[2]))
			var okh := StoryExpr.test(str(s[3]), st)
			if okh or step_t > float(s[4]):
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				checks.append([okh, str(s[5])])
				print("  [확인] %s %s (%.1f초 · 수레 %s %d)" % ["○" if okh else "×", s[5], step_t, u04.cart_map(), u04.cart_x()])
				_next()
		"grgo", "gruse":                                               # 구로 구내(월드 손 맵 X-GR) 좌표 → 월드 좌표(1-D4)
			var o := gr.origin()
			plan[i] = ["go" if str(s[0]) == "grgo" else "use", o.x + int(s[1]), o.y + int(s[2])]
			return
		"go":
			if s.size() > 3 and host.map.id != str(s[3]) and step_map == 0:
				return
			if step_map == 0:
				step_map = host.map.get_instance_id()
			elif host.map.get_instance_id() != step_map:
				_next()
				return
			host.input_fn = _walk.bind(Vector2(int(s[1]) * 32 + 16, int(s[2]) * 32 + 16))
			if host.player.loco.render.distance_to(Vector2(int(s[1]) * 32 + 16, int(s[2]) * 32 + 16)) < 6.0 or step_t > 40.0:
				if step_t > 40.0:
					var near: Array = []
					for b in host.map.blockers:
						if is_instance_valid(b) and b.loco.logical.distance_to(host.player.loco.logical) < 48.0:
							near.append([b.sheet, b.loco.logical, b.floor_id])
					print("  [봇] 걸어서 못 감: ", s, " 지금 ", host.map.id, " ", host.map.tile_of(host.player.loco.logical),
						" · 대화 ", host.box.active, " 바쁨 ", host.busy, " 연출 ", host.ev.busy(), " 길 ", NpcRoutine.with_start(host.map, host.player.loco.logical,
						Vector2(int(s[1]) * 32 + 16, int(s[2]) * 32 + 16)).size(), " 고체 ", host.map.is_solid(host.map.tile_of(host.player.loco.logical)),
						" · 잠금 ", host.locked, " 몸 ", host.body, " 창 ", [host.pipboy != null, host.container != null, host.terminal != null, host.lockpick != null],
						" 입력 ", _walk(Vector2(int(s[1]) * 32 + 16, int(s[2]) * 32 + 16)), " 걸음 ", host.player.loco.motion, " 그림 ", host.player.loco.render, " 판정 ", host.player.loco.logical,
						" 층 ", host.player.floor_id, " 곁 ", near)
				_next()
		"want":
			want = s[1]
			_next()
		"shoton":
			shot_on = str(s[1])
			shot_tag = str(s[2])
			_next()
		"talk":
			var n := _npc(str(s[1]))
			if n.is_empty():
				print("  [봇] 인물 없음: ", s[1])
				_next()
				return
			var goal: Vector2 = n["actor"].loco.logical
			var p := host.player.loco.logical
			if p.distance_to(goal) < 80.0 or step_t >= 30.0:              # 가까우면(계산대 너머 포함) 바라보고 말을 건다
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				host.player.loco.facing = Locomotion.snap8(goal - p, 0.0)
				host.player._show()
				var started := false
				if p.distance_to(goal) > 46.0 and step_t >= 3.0:          # 가구에 막혀 46px 안으로 못 들어감(침낭 · 계산대) — 앞 칸 소품이 먼저 잡히니 바로 말을 건다
					host.talk(n)
					started = true
				elif p.distance_to(goal) <= 46.0:
					started = host.interact()
				if started or step_t >= 30.0:
					if step_t >= 30.0:
						print("  [봇] 말 걸기 실패: ", s[1], " 거리 ", p.distance_to(goal), " 맵 ", host.map.id, " ", host.map.tile_of(p), " 상대 ", host.map.tile_of(goal))
						_shot("talkfail")
					_next()
					return
			host.input_fn = _walk.bind(goal + (p - goal).normalized() * 34.0)
		"use":
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			if s.size() > 3 and str(s[3]) == "cart":                       # 1-D10 바로 앞 수레를 본다
				s = ["use", u04.cart_x(), u04._row()]
			elif s.size() > 3 and str(s[3]) == "brake":                    # 1-D10 탄 채 조사 키(브레이크)
				s = ["use", u04.cart_x() + 3, u04._row()]
			host.player.loco.facing = Locomotion.snap8(Vector2(int(s[1]) * 32 + 16, int(s[2]) * 32 + 16) - host.player.loco.logical, 0.0)
			host.player._show()
			host.interact()
			_next()
		"loot":
			for c in host.map.boxes:
				var b: Dictionary = host.map.boxes[c]
				if str(b.get("name", "")) == str(s[1]):
					var items: Dictionary = host.box_contents(b)["items"]
					print("  [봇] %s: %s" % [s[1], str(items)])
					checks.append([not items.is_empty(), "유해 소지품이 나온다(%d종)" % items.size()])
			_next()
		"fight":
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			var alive := host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == "enemy" and not e.hide_bar \
				and e.loco.logical.distance_to(host.player.loco.logical) < 30.0 * 32.0)
			if alive.is_empty():
				if step_t > 1.5:
					host.combat.bot = {}
					_next()
				return
			step_t = 0.0 if step_t > 1.0 and not alive.is_empty() and t < 380.0 else step_t
			if t - last_report > 10.0:
				last_report = t
				print("  [봇] 싸움 %.0f초: 남은 %s · 체력 %d · 무기 %s 탄창 %s 넣음 %s" % [t, str(alive.map(func(e): return "%s hp%d" % [str(host.map.tile_of(e.loco.logical)), int(e.cmb.hp)])), int(host.combat.pc.hp),
					host.combat.weapon_id, str(host.combat.mags.get(host.combat.weapon_id, -1)), str(host.combat.holstered)])
				var a0: Enemy = alive.reduce(func(m, e): return e if m == null or e.loco.logical.distance_to(host.player.loco.logical) < m.loco.logical.distance_to(host.player.loco.logical) else m, null)
				print("    가까운 적 %s 거리 %.0f 시야 %s 보임 %s 나 %s" % [str(a0.get_meta("enemy_id", "")), a0.loco.logical.distance_to(host.player.loco.logical),
					str(host.map.line_of_sight(host.player.loco.logical, a0.loco.logical)), str(a0.visible), str(host.player.loco.logical)])
			alive.sort_custom(func(a, b): return a.loco.logical.distance_to(host.player.loco.logical) < b.loco.logical.distance_to(host.player.loco.logical))
			var far: float = alive[0].loco.logical.distance_to(host.player.loco.logical)
			var hp_sum: float = alive.reduce(func(m, e): return m + e.cmb.hp, 0.0)
			if absf(hp_sum - fight_hp) > 0.1 or alive.size() != fight_n:
				fight_hp = hp_sum
				fight_n = alive.size()
				fight_still = 0.0
			fight_still += get_process_delta_time()
			if fight_still > 6.0:                                          # 6초 동안 피해를 못 줬다(엄폐 뒤): 표적 옆으로 돌아간다
				var side: Vector2 = (alive[0].loco.logical - host.player.loco.logical).orthogonal().normalized() * 96.0
				host.input_fn = _walk.bind(alive[0].loco.logical + side * (1.0 if int(t / 8.0) % 2 == 0 else -1.0))
				if fight_still > 9.0:
					fight_still = 0.0
			elif far > 160.0:                                                # 멀면 다가간다(사거리·시야 안으로)
				host.input_fn = _walk.bind(alive[0].loco.logical)
			host.combat.bot = {"aim": alive[0].loco.logical + Vector2(0, -12), "fire": true, "aimed": true,
				"reload": host.combat.mags.get(host.combat.weapon_id, 1) == 0, "stim": host.combat.pc.hp < host.combat.pc.max_hp * 0.4}
		"hack":
			var tm: TerminalScreen = host.terminal
			if tm == null:
				if step_t > 3.0:
					print("  [봇] 단말이 안 열렸다")
					_next()
				return
			if tm.mode == "hack" and tm.hack.state == "play" and tm.shown > 9999:
				var wrong := -1
				for wi in tm.hack.words.size():
					if tm.hack.words[wi] != tm.hack.answer and not tm.hack.removed.has(wi):
						wrong = wi
				if tm.hack.tries == 4 and wrong >= 0:
					tm.pick(tm.hack.starts[wrong])                         # 한 번 틀려 본다(일치 표시 확인)
				else:
					tm.pick(tm.hack.starts[tm.hack.words.find(tm.hack.answer)])
			elif tm.mode == "hack":
				tm.shown = 1e9
			elif tm.mode == "menu":
				menu_t += get_process_delta_time()
				if menu_t < 1.5:                                        # 글이 다 찍힌 뒤에 찍는다(타자 효과)
					return
				menu_t = 0.0
				_shot("hack_menu")
				tm._open_entry(int(s[1]) if s.size() > 1 else 0)          # ["hack", n] — n번째 항목(기본 0)
			elif tm.mode == "read" and menu_t < 1.5:
				menu_t += get_process_delta_time()
				if menu_t >= 1.5:
					_shot("hack_read")
			elif tm.mode == "read":
				menu_t = 0.0
				tm.close(true)
				_next()
		"lock":                                                         # 자물쇠 창: 머리핀을 정답 쪽으로 쓸어 가다 돌린다(한 번은 일부러 비껴서 걸림을 본다)
			var ls: LockScreen = host.lockpick
			if ls == null:
				if step_t > 2.0:
					if not seen.has("lock"):
						print("  [봇] 자물쇠 창이 안 열렸다")
					_next()
				return
			ls.bot_on = true
			seen["lock"] = true
			var lk: Lockpick = ls.lock
			if step_t < 1.2:                                            # 비껴 돌리기: 막혀 덜 돈다
				lk.set_angle(clampf(lk.target + lk.w + 25.0, 0.0, 180.0))
				ls.bot_turn = true
			elif step_t < 1.6:
				ls.bot_turn = false
			else:
				if not seen.has("lock_shot"):
					seen["lock_shot"] = true
					_shot("lock_miss")
				lk.set_angle(lk.target)
				ls.bot_turn = true
				if lk.turn > 45.0 and not seen.has("lock_shot2"):
					seen["lock_shot2"] = true
					_shot("lock_turn")
		"scene":                                                        # 조사 글 장면을 그 자리에서 연다(월드 손 맵의 조사 칸 — 1-11d)
			host.play_scene(str(s[1]))
			_next()
		"warp":                                                         # 다음 장소로 바로(확인 봇: 걸어가는 길은 다른 봇이 본다)
			host.enter(str(s[1]), str(s[2]) if s.size() > 2 else "from_W")
			_next()
		"shotin":                                                       # n초 뒤 한 장(연출 · 대화 중에도 — 봇 계획은 그동안 멈춰 있으니 타이머로)
			var tag := str(s[1])
			get_tree().create_timer(float(s[2])).timeout.connect(func() -> void: _shot(tag))
			_next()
		"travel":                                                       # 빠른 이동(1-12k): 지도에서 고른 것처럼 — 막히면 이유를 찍고 멈춘다
			var why: Array = host.travel_check(str(s[1]))
			if not why[0]:
				_finish("빠른 이동 불가: " + str(why[1]))
				return
			host.fast_travel(str(s[1]))
			_next()
		"set":
			st.vars.set_v(str(s[1]), s[2])
			_next()
		"found":
			st.places.raise(str(s[1]), PlaceLog.FOUND)
			_next()
		"crouch":
			host.combat.crouch = bool(s[1])
			_next()
		"clear":                                                        # 둘레 30칸의 그 짐승들을 걷어 낸다(월드 소장소에 사는 들개 등 — 다른 것을 보는 봇이 개 떼에 막히지 않게)
			for e in host.combat.enemies.duplicate():
				if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) in s[1] and e.loco.logical.distance_to(host.player.loco.logical) < 30.0 * 32.0:
					host.combat.enemies.erase(e)
					e.queue_free()
			host.combat._rebuild_list()
			_next()
		"noenc":                                                        # 새 인카운터를 굴리지 않는다(인카운터는 시각 난수 — 다른 것을 보는 봇이 운에 기대지 않게)
			host.enc_live.off = true
			_next()
		"calm":                                                         # 맵의 적을 멈춰 세운다(확인 봇: 싸움 없이 장치 · 장면만 본다 — 1-D)
			for e in host.combat.enemies:
				if is_instance_valid(e):
					e.set_process(false)
					e.set_physics_process(false)
			_next()
		"goen":                                                         # 가장 가까운 그 적(비적대 수색조 등)에게 걸어간다(1-11f)
			var best: Enemy = null
			for e in host.combat.enemies:
				if is_instance_valid(e) and not e.cmb.dead and str(e.get_meta("enemy_id", "")) == str(s[1]) \
						and (best == null or e.loco.logical.distance_to(host.player.loco.logical) < best.loco.logical.distance_to(host.player.loco.logical)):
					best = e
			if best == null or host.box.active or best.loco.logical.distance_to(host.player.loco.logical) < 64.0 or step_t > 40.0:
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				_next()
				return
			host.input_fn = _walk.bind(best.loco.logical)
		"mate":                                                         # 곁의 동행에게 말 건다(1-11f 진해원 — 동행 메뉴 '할 말이 있어')
			var mm := host.combat.mates.get_mate(str(s[1]))
			if mm.is_empty():
				print("  [봇] 동행 없음: ", s[1])
			else:
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				host._mate_talk(mm)
			_next()
		"talkd":                                                        # 그 인물에게 바로 말 건다(나란히 선 사람 · 개 — 남솔과 백구, 1-11a)
			var nd := _npc(str(s[1]))
			if nd.is_empty():
				print("  [봇] 인물 없음: ", s[1])
				_next()
				return
			var gd: Vector2 = nd["actor"].loco.logical
			if host.player.loco.logical.distance_to(gd) < 60.0 or step_t >= 30.0:
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				host.talk(nd)
				_next()
				return
			host.input_fn = _walk.bind(gd + (host.player.loco.logical - gd).normalized() * 34.0)
		"settime":
			host.date_text = str(s[1])
			_next()
		"hours":                                                        # 시계를 몇 시간 넘긴다(06:00을 넘으면 하루 판정 — 1-D7 수레)
			host.advance_minutes(int(s[1]) * 60)
			_next()
		"setv":                                                         # 변수 바로 세우기(날짜를 건너뛸 때 GAME_DAY — 1-11i)
			st.vars.set_v(str(s[1]), s[2])
			_next()
		"gomark":                                                       # 월드 손 맵 표지까지 걷는다(1-11a)
			var gm: Vector2 = host.map.mark_pos(str(s[1]))
			host.input_fn = _walk.bind(gm)
			if host.player.loco.logical.distance_to(gm) < 40.0 or step_t > 40.0 or side.stand_t > 0.0:
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				print("  [봇] 표지 %s: 나 %s · 목표 %s · %.1f초 · 외눈 %s" % [s[1], str(host.map.tile_of(host.player.loco.logical)), str(host.map.tile_of(gm)), step_t,
					str(host.map.tile_of(side.one.loco.logical)) if is_instance_valid(side.one) else "-"])
				_shot("gomark")
				_next()
		"sbgo":                                                         # 1-12f 행렬 사람 곁으로(갈고리 · 오태수)
			var who = fqsb.lead() if str(s[1]) == "lead" else fqsb.cv.get("taesu")
			if who == null or not is_instance_valid(who) or step_t > 30.0:
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				_next()
				return
			host.input_fn = _walk.bind((who as Node2D).loco.logical + Vector2(0, 24))
			if host.player.loco.logical.distance_to((who as Node2D).loco.logical) < 34.0:
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				_next()
		"sbtalk":
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			if not host.box.active:
				fqsb._interact2()
			_next()
		"sbfollow":                                                     # 행렬 꼬리를 따라 걷는다(조건이 서거나 시간이 다 되면)
			var okf := StoryExpr.test(str(s[1]), st)
			if okf or step_t > float(s[2]):
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				checks.append([okf, str(s[3])])
				print("  [확인] %s %s (%.1f초 · 경유점 %d · %s)" % ["○" if okf else "×", s[3], step_t, int(st.vars.get_v("FQ_SB02_LEG")), host.date_text])
				if s.size() > 4:
					_shot(str(s[4]))
				_next()
				return
			if int(step_t / 10.0) != int((step_t - get_process_delta_time()) / 10.0):            # 10초마다 행렬 상태(봇 로그)
				var ldd = fqsb.lead()
				print("  [봇] 행렬 %.0f초 · %s · 경유점 %d · 선두 %s 상태 %s · 나 %s · hold=%s lag=%s · 단계 %d" % [step_t, host.date_text, int(st.vars.get_v("FQ_SB02_LEG")),
					str(host.map.tile_of(ldd.loco.logical)) if ldd else "-", str(ldd.brain.state) if ldd else "-", host.cur_map + str(host.map.tile_of(host.player.loco.logical)),
					str(fqsb.cv.get("hold", "")), str(fqsb.cv.get("lag", "")), int(st.quests.stage("FQ-SB-02"))])
			if not fqsb.cv.is_empty() and fqsb.lead() != null:
				var tr: Array = fqsb.cv["trail"]
				var n_f: int = fqsb.cv["men"].size() + fqsb.cv["folk"].size() + 1     # 줄 맨 뒤 사람 한 칸 뒤
				var tail: Vector2 = tr[maxi(0, tr.size() - 1 - n_f * FqSb.GAP)]
				host.input_fn = _walk.bind(tail)
		"chase":                                                        # 대치 중 들개를 쏘아 쫓는다(외눈은 쏘지 않는다)
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			var dogs: Array = side.pack.filter(func(e): return is_instance_valid(e) and e != side.one and not e.cmb.dead and not e.released)
			if int(st.vars.get_v("SQ_S01_SOL")) != 0 or dogs.is_empty() or step_t > 20.0:
				host.combat.bot = {}
				_next()
				return
			dogs.sort_custom(func(a, b): return a.loco.logical.distance_to(host.player.loco.logical) < b.loco.logical.distance_to(host.player.loco.logical))
			host.combat.bot = {"aim": dogs[0].loco.logical + Vector2(0, -8), "fire": true, "aimed": true,
				"reload": host.combat.mags.get(host.combat.weapon_id, 1) == 0}
		"gotag":
			var dc := side._drop_cell()
			var gt := Vector2(dc.x * 32 + 16, dc.y * 32 + 16)
			host.input_fn = _walk.bind(gt)
			if st.count_of("M-158") > 0 or step_t > 30.0:
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				_next()
		"examine":
			host._pip_action("examine", str(s[1]))
			_next()
		"godoor":                                                       # 버티버드 문 앞 칸으로(기체를 돌아서)
			var g := host.map.mark_pos("vb_door") if host.map.marks.has("vb_door") else host.player.loco.logical
			host.input_fn = _walk.bind(g)
			if host.player.loco.render.distance_to(g) < 6.0 or step_t > 20.0:
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				host.player.loco.facing = 6
				host.player._show()
				_next()
		"hp":                                                           # 체력을 정한다(0 = 그대로)
			if int(s[1]) > 0:
				host.combat.pc.max_hp = maxf(host.combat.pc.max_hp, float(s[1]))
				host.combat.pc.hp = float(s[1])
			_next()
		"face":
			host.player.loco.facing = int(s[1])
			host.player._show()
			_next()
		"wait":
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			if step_t >= float(s[1]):
				_next()
		"stash_open":                                                  # 1-L: 이 맵의 첫 '삼을 수 있는' 용기를 비우고 연다(내 자리면 그대로 연다)
			var keys: Array = host.map.boxes.keys()
			keys.sort_custom(func(p, q): return int(str(host.map.boxes[p].get("kind", "")) == "apartment") > int(str(host.map.boxes[q].get("kind", "")) == "apartment"))   # 장롱 먼저
			for c in keys:
				var b: Dictionary = host.map.boxes[c]
				var bc := host.box_contents(b)
				if stash.is_mine(bc) or (str(b.get("kind", "")) in Stash.CLAIM_KINDS and str(b.get("owner", "")) == ""):
					if not stash.is_mine(bc):
						bc["items"] = {}
					host.open_box(b)
					break
			_next()
		"stash_claim":
			if host.container != null:
				host.container.stash_act.emit("claim")
				host.container.state["items"] = {"W-013": 1, "M-096": 1, "I-030": 2, "M-012": 2, "M-001": 40}
				print("  [봇] 내 자리: ", host.container.stash_line)
			_next()
		"stash_rob":                                                   # 날마다 판정 대신 바로 털게 한다(시험용 — 판정식은 단위 시험)
			for k in stash.spots():
				var sp: Dictionary = stash.spots()[k]
				var rng := RandomNumberGenerator.new()
				rng.seed = 5
				stash._theft(k, sp, st.boxes[k], int(st.vars.get_v("GAME_DAY")), rng, str(s[1]) if s.size() > 1 else "")
				var bn := stash.bundle(int(stash.data()["qb"]))
				print("  [봇] 털림 → ", bn.get("who", ""), " ", bn.get("dest", ""))
				break
			_next()
		"warp_dest":
			var bn2 := stash.bundle(int(stash.data()["qb"]))
			if not bn2.is_empty():
				host.enter(str(bn2["dest"]), "from_W")
			_next()
		"close":
			if host.container != null:
				print("  [봇] 용기 안: ", host.container.title, " ", host.container.state["items"])
				host.container.close(true)
			_next()
		"check":
			var ok := false
			if str(s[1]) == "container_open":
				ok = host.container != null
			elif str(s[1]) == "seen_evac":
				ok = seen.has("evac")
			elif str(s[1]).begins_with("read:"):
				ok = st.boxes.has("notes") and st.boxes["notes"]["read"].has(str(s[1]).substr(5))
			elif str(s[1]) == "hp_full":
				ok = host.combat.pc.hp >= host.combat.pc.max_hp - 0.5
			elif str(s[1]).begins_with("map:"):
				ok = host.map.id == str(s[1]).substr(4)
			elif str(s[1]) == "seen_commuter":
				ok = seen.has("commuter")
			elif str(s[1]) == "vb_blocks":
				ok = mq106.land_check
			elif str(s[1]).begins_with("place_marked:"):
				ok = st.places.get_state(str(s[1]).substr(13)) >= PlaceLog.MARKED
			elif str(s[1]) == "ga_pose":
				var gs: Array = host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) in Ga.GANG and e != ga._lookout)
				ok = not gs.is_empty() and gs.all(func(e): return e.det_mul == 0.0 or e.brain.state == AIBrain.S.COMBAT)
			elif str(s[1]) == "ks_calm":
				var us := ks.units()
				ok = us.size() == 4 and us.all(func(e): return not ("player" in e.foes)) and not ks._hot
			elif str(s[1]) == "hp_march":
				var fs: Array = hosp.ferals().filter(func(e): return str(e.who) in Hp.FERALS.slice(0, 5))
				ok = fs.size() >= 3 and fs.all(func(e): return not e.asleep and e.route.size() >= 6)
			elif str(s[1]) == "hp_eat":
				var fs2: Array = hosp.ferals().filter(func(e): return e.brain.state != AIBrain.S.COMBAT)   # 주인공을 본(교전) 개체는 차임을 따르지 않는다
				ok = hosp._phase == 3 and fs2.size() >= 3 and fs2.all(func(e): return (e.has_meta("hp_go") and int(e.get_meta("hp_go")) == 3) or (e.asleep and e.doze == "stand"))
				if not ok:
					print("  [봇] 대형 %d · %s" % [hosp._phase, str(fs2.map(func(e): return [e.who, e.get_meta("hp_go", -1), e.asleep, e.doze, e.brain.state]))])
			elif str(s[1]) == "u04_quiet":
				ok = u04._stayers.size() == 6 and u04._stayers.all(func(e): return is_instance_valid(e) and e.asleep)
			elif str(s[1]) == "u04_riding":
				ok = u04._riding
			elif str(s[1]) == "ks_carry":
				ok = is_equal_approx(host.carry_mul, Ks.CARRY_MUL)
			elif str(s[1]) == "ga_lure":
				ok = ga._lure_t > 0.0
			elif str(s[1]).begins_with("turf:"):                        # turf:구역:상태 — 주인공이 아는 판(1-12m)
				var tp := str(s[1]).split(":")
				var kt: Dictionary = st.turf.known_of(tp[1])
				ok = not kt.is_empty() and int(kt["s"]) == int(tp[2])
				if not ok:
					print("    [판도] 맵 %s · 칸 %s · 선 구역 %s · 아는 판 %s" % [host.map.id, str(host.map.tile_of(host.player.loco.logical)), st.turf.here, str(kt)])
			elif str(s[1]).begins_with("turfhint:"):
				ok = _hint_log.any(func(h): return str(h).contains(str(s[1]).substr(9)))
			elif str(s[1]).begins_with("fbook:"):
				st.fbook.refresh(st, host.date_text)
				ok = st.fbook.registered(str(s[1]).substr(6))
			elif str(s[1]) == "seen_guard":
				ok = seen.has("guard_bark")
			elif str(s[1]) == "seen_rumor":
				ok = seen.has("rumor") and last_line != "……"
				print("  [봇] 소문: ", last_line)
			else:
				ok = StoryExpr.test(str(s[1]), st)
			checks.append([ok, str(s[2])])
			print("  [확인] %s %s" % ["○" if ok else "×", s[2]])
			if not ok and OS.get_environment("BOT_DBG") != "":
				print("    [디버그] 맵 %s · SB_127 %s · SB_RAID %s · 장면 %s · 시각 %s" % [host.map.id, str(st.vars.get_v("SB_127")), str(st.vars.get_v("SB_RAID")), str(host.ev.busy()), host.date_text])
			_next()
		"shot":
			_shot(str(s[1]))
			_next()
		"until":
			host.input_fn = func() -> Vector2: return Vector2.ZERO
		"end":
			_finish("")


## 조건까지 기다림(state:진행기 상태 · map:맵 · card 막 제목 카드 · 식). 대화·연출 중에도 본다. 넘어갔으면 true
func _until(s: Array) -> bool:
	var c := str(s[1])
	var ok2 := false
	if c.begins_with("state:"):
		ok2 = mq106 != null and mq106.state == c.substr(6)
	elif c.begins_with("map:"):
		ok2 = host.map.id == c.substr(4)
	elif c == "card":
		ok2 = seen.has("card") or str(host.ev._job.get("kind", "")) == "card"
	elif c == "u04_stopped":
		ok2 = not u04._riding and not u04._ride_carry
	elif c == "side:stand":
		ok2 = side != null and side.stand_t > 0.0
	elif c == "win":                                                   # 대화 안에서 열린 거래 · 용기 창(1-L): 찍고 닫는다
		ok2 = host.container != null
	else:
		ok2 = StoryExpr.test(c, st)
	if ok2 or step_t > float(s[2]):
		if not ok2:
			print("  [봇] 기다림 끝: 나 %s · 맵 %s · 교전 %s" % [str(host.map.tile_of(host.player.loco.logical)), host.map.id, str(host.combat.in_combat())])
			for e in host.combat.enemies:                              # 무엇이 붙었나(실패 원인 읽기)
				if is_instance_valid(e) and not e.cmb.dead and e.loco.logical.distance_to(host.player.loco.logical) < 20.0 * 32.0:
					print("    적 %s %s · %s" % [str(e.row.get("id", "")), str(host.map.tile_of(e.loco.logical)), str(e.brain.state)])
			_shot("until_fail")
		checks.append([ok2, str(s[3])])
		print("  [확인] %s %s (%.1f초)" % ["○" if ok2 else "×", s[3], step_t])
		if ok2 and c == "win":
			print("  [봇] 창: ", host.container.title, " ", host.container.state.get("items", {}).size(), "줄 · 찾는 것 ", host.container.state.get("want", ""))
			var wn := host.container
			var nm := str(s[4]) if s.size() > 4 else "win"
			get_tree().create_timer(0.5).timeout.connect(func() -> void:     # 창이 그려진 뒤 찍고 닫는다
				_shot(nm)
				if is_instance_valid(wn):
					wn.close(true))
		elif ok2 and s.size() > 4:
			_shot(str(s[4]))
		_next()
		return true
	return false


func _next() -> void:
	i += 1
	step_t = 0.0
	_repath_t = -1.0
	_stuck_t = 0.0
	_side_t = 0.0
	step_map = 0
	path = PackedVector2Array()


func _npc(id: String) -> Dictionary:                                   # 같은 ID(무명 병사 CR-401 등)가 여럿이면 가장 가까운 사람
	var best := {}
	var bd := INF
	for n in host.npcs:
		if str(n["id"]) == id and is_instance_valid(n["actor"]) and n["actor"].visible:
			var d: float = n["actor"].loco.logical.distance_to(host.player.loco.logical)
			if d < bd:
				bd = d
				best = n
	return best


func _walk(goal: Vector2) -> Vector2:
	var p := host.player.loco.render
	if p.distance_to(goal) < 4.0:
		return Vector2.ZERO
	if (path.is_empty() and step_t - _repath_t > 0.5) or step_t < 0.05 or (int(step_t * 2.0) % 6 == 0 and step_t - _repath_t > 0.4):
		path = NpcRoutine.with_start(host.map, p, goal, host.player.floor_id)
		_repath_t = step_t                                                # 닿지 않는 목표에 매 틱 길찾기를 되풀이하지 않는다(0.5초에 한 번)
	if p.distance_to(_stuck_p) > 3.0:
		_stuck_p = p
		_stuck_t = step_t
	elif step_t - _stuck_t > 1.2 and _side_t <= step_t:                # 1.2초 제자리: 길 위에 몸이 선 것 — 옆으로 0.5초 비킨다
		var fw := (goal - p).normalized() if path.is_empty() else NpcRoutine.step_dir(p, path[0])
		_side_dir = Vector2(-fw.y, fw.x) * (1.0 if int(step_t) % 2 == 0 else -1.0)
		_side_t = step_t + 0.5
		_stuck_t = step_t
	if _side_t > step_t:
		return _side_dir
	while path.size() > 0 and (NpcRoutine.arrived(p, path[0]) or (path.size() > 1 and p.distance_to(path[1]) <= path[0].distance_to(path[1]) + 2.0)):
		path.remove_at(0)
	if path.is_empty():
		return (goal - p).normalized()
	return NpcRoutine.step_dir(p, path[0])


## 대화: 줄은 넘기고, 선택지는 원하는 글귀(want 앞쪽 우선)를 고른다. 없으면 첫째
func _box(dt: float) -> void:
	if not host.box.active:
		return
	hold += dt
	if hold < 0.25:
		return
	hold = 0.0
	match str(host.box.state.get("type", "")):
		"line":
			if shot_on != "" and (shot_on == "*" or str(host.box.state.get("text", "")).contains(shot_on)):
				shot_wait += 0.25
				if shot_wait < 1.75:                                    # 글이 다 찍히게 1.5초 더 기다렸다 찍는다
					return
				_shot(shot_tag)
				last_line = str(host.box.state.get("text", ""))
				seen[shot_tag] = true
				shot_wait = 0.0
				shot_on = ""
			host.box.next()
		"choices":
			var opts: Array = host.box.state.get("opts", [])
			var pick := -1
			var used := ""
			for w in want:
				var ws := str(w).trim_prefix("!")                          # '!'로 시작하면 한 번 쓰고 지운다(메뉴로 돌아오는 대화에서 맴돌지 않게)
				for k in opts.size():
					if pick < 0 and str(opts[k]["text"]).contains(ws) and bool(opts[k].get("enabled", true)):
						pick = k
						used = str(w)
			if used.begins_with("!"):
				want.erase(used)
			_shot("choice")
			host.box.pick(maxi(0, pick))


func _shot(tag: String) -> void:
	if shots == "":
		return
	shot_n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%02d_%s.png" % [shots, route, shot_n, tag])


func _finish(why: String) -> void:
	set_process(false)
	if why != "" and i < plan.size():
		print("  [봇] 멈춘 단계 %d: %s · 맵 %s %s" % [i, str(plan[i]), host.map.id if host.map else "-", str(host.map.tile_of(host.player.loco.logical)) if host.map else ""])
	var ok := checks.filter(func(c): return c[0]).size()
	print("지하시장 봇 %s: %s %d/%d%s · MQ-103 %d · 캡 %d · XP %d · 지하 %d · MQ-105 %d" % [route, "○" if ok == checks.size() and why == "" else "×", ok,
		checks.size(), (" (" + why + ")") if why != "" else "", st.quests.stage("MQ-103"), int(st.vars.get_v("PC_CAPS")),
		int(st.vars.get_v("PC_XP")), int(st.vars.get_v("AFF_JH")) if st.vars.has("AFF_JH") else 0, st.quests.stage("MQ-105")])
	get_tree().create_timer(0.3).timeout.connect(get_tree().quit)
