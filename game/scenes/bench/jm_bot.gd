## 지하시장 봇(단계 1-4, SD-19 §10.2 봇 플레이): MQ-103 갈래를 실제 맵·대화·전투·해킹 위에서 처음부터 끝까지 돈다.
## 갈래(인자 첫째): job 출입세→상인회 일·박춘삼→둥지→출입패→문→해독→고백(과학)→북쪽 출구 매복 · vent 구청역 통로→둥지→환풍구(은신)→해독
##   · hack 역사 쇼핑몰→출입 단말 해킹→문→해독 · fee 카리스마 농담→면담료 300→문→해독→고백 실패(화술)
## 둘째 인자 = 스크린샷 폴더(없으면 찍지 않음). 끝에 '지하시장 봇 <갈래>: ○ n/m' 한 줄과 확인 줄을 찍는다.
## 실행: xvfb-run godot --path game res://scenes/bench/jm_bot.tscn -- job /tmp/shots
extends Node

var host: InteriorHost
var paths: Act1Paths
var st: StoryState
var route := "job"
var shots := ""
var plan: Array = []
var i := 0
var t := 0.0
var step_t := 0.0
var path := PackedVector2Array()
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
			plan = [["go", 911, 1395], ["shoton", "판독", "sentry_lit"], ["go", 912, 1393],
				["check", "MQ102_ROBOT == 1 and MQ102_STAGE == 10", "잠든 파수가 깨어났다 꺼짐"],
				["use", 912, 1392], ["shot", "sentry_after"],
				["go", 891, 1381], ["go", 891, 1378], ["go", 894, 1374], ["want", ["읽을 사람"]], ["talk", "N-R02-018"],
				["check", "MQ102_C1 == 1 and MQ103_STAGE == 10", "구울 행상 → 단서 1(MQ-103 열림)"],
				["shoton", "*", "rumor"], ["talk", "N-R01-030"], ["wait", 3.0], ["check", "seen_rumor", "이름 없는 봉천 주민이 행적 소문을 한다"],
				["go", 884, 1365], ["go", 884, 1364], ["go", 7, 7, "B-03"], ["want", ["깨진 숫자 줄"]], ["talk", "C-057"], ["shot", "hasukja"],
				["check", "MQ102_C2 == 1 and MQ104_STAGE == 10", "하숙자 옛 여의도 지도 → 단서 2(MQ-104 열림)"]]
		"poi":                                                          # 길 위 발견물(1-4f): 쪽지 읽기 → 떠돌이 유해 열기(용기 창) · 대피소 표지
			host.enter("W", "L-R01-15")
			host.player.loco.place(Vector2(806 * 32 + 16, 1381 * 32 + 16))
			plan = [["shoton", "충전소", "note"], ["go", 806, 1382], ["use", 806, 1383], ["wait", 2.0],
				["go", 805, 1384], ["use", 806, 1384], ["wait", 1.0], ["shot", "remains_box"],
				["check", "container_open", "떠돌이 유해 → 용기 창이 열린다"], ["close"],
				["go", 804, 1338], ["shoton", "대피소", "evac"], ["use", 804, 1337], ["wait", 2.0],
				["check", "seen_evac", "대피소 표지 글이 뜬다"]]
		"place":                                                        # 1-5e 손 장소: 전망바위 → 연수원 본관(LR-19)·기숙사(LR-11) → 계곡 배수로(정비공) → 경찰서 무기고(자물쇠 50) → 공영방송(LR-01)
			st.vars.set_v("PC_SKP_LOCKPICK", 50)
			st.vars.set_v("PC_SKP_SMALL_GUNS", 40)
			for kv in [["M-070", 4], ["I-001", 10], ["10mm 탄", 200]]:
				st.call_fn("give", kv)
			host.enter("W", "L-R01-03")
			plan = [["go", 984, 1514], ["shoton", "세진전자 타워", "view"], ["use", 984, 1513], ["wait", 0.5],
				["check", "PL_VIEW == 1 and PC_CAPS == 612", "전망바위 망원경 → 지도 표시 · 동전 12캡"],
				["warp", "W", "L-R01-06"], ["wait", 1.0], ["face", 6], ["shot", "k01_door"], ["use", 929, 1475], ["wait", 2.0], ["shot", "k01"], ["fight"],
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
		"sb_buy", "sb_deal", "sb_capture", "sb_raid", "sb_roof", "sb_jo":   # MQ-105(1-6) 새벽인력 본소
			_sb_plan()
	plan.append(["end"])


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
				["go", 16, 6, "H-03"], ["want", ["[힘 7]"]], ["go", 16, 7], ["wait", 1.0], ["check", "SB_CUFF == 0", "수갑·우리 문(힘 7)"],
				["go", 16, 9], ["go", 10, 9], ["want", ["[힘 7]"]], ["use", 10, 8], ["wait", 0.8], ["shot", "sb_free127"],
				["go", 4, 9], ["use", 4, 8], ["wait", 0.8], ["go", 22, 9], ["use", 22, 8], ["wait", 0.8],
				["go", 28, 9], ["use", 28, 8], ["wait", 0.8], ["go", 34, 9], ["use", 34, 8], ["wait", 0.8], ["shot", "sb_freed"],
				["check", "SB_FREED >= 6 and V_KARMA >= 100", "'인력' 여섯을 풀어 줌(카르마 +100)"],
				["want", ["[수리 50]"]], ["go", 40, 5], ["wait", 1.5], ["check", "SB_COLLAR == 0", "목걸이 해제(수리 50)"]]
		"sb_raid":
			plan += [["want", ["총을 꺼낸다"]], W.call(22, 37), ["wait", 1.0], ["check", "SB_RAID == 1", "정문에서 총 → 정면 습격"],
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
	plan = [["shot", "hatch"], ["go", 812, 1086], ["shot", "stairs"], ["check", "MQ104_STAGE == 20", "해치로 내려가면 단계 20"],
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
				["check", "MQ104_STAGE == 100", "벙커를 나서면 끝"], ["go", 800, 1097, "W"], ["shoton", "관리자 후보님", "guard_bark"], ["talk", "CR-401"], ["wait", 2.0], ["check", "seen_guard", "초소 병사가 '관리자 후보'라 부른다"]]
		"yd_fight":                                                     # 총을 든다 → 수색조 다섯 → 초소가 빈다 → 호송차 열쇠로 하도윤
			plan += [["want", ["총을 든다"]], ["wait", 14.0], ["fight"], ["shot", "squad_down"],
				["check", "MQ104_SEARCH == 2 and MQ104_GUARDS == 1 and AFF_BJ == -40", "수색조 격퇴(비상 -10) · 초소가 빈다"],
				["go", 34, 5], ["want", ["가져간다"]], ["use", 34, 4], ["check", "has(\"W-017\")", "경비 장교의 소총"],
				["go", 19, 26], ["go", 19, 27], ["go", 1, 8, "Y-01"], ["go", 0, 8], ["go", 5, 1, "Y-00"], ["go", 5, 0],
				["check", "MQ104_STAGE == 100", "벙커를 나서면 끝"],
				["go", 800, 1095, "W"], ["shoton", "초소가 비었다", "truck_empty"], ["use", 800, 1094], ["wait", 1.0],
				["check", "V_DOYUN == 2 and MQ104_DOYUN == 1 and MQ104_STAGE == 100", "빈 초소의 열쇠로 하도윤 구출(V_DOYUN 2)"]]
		"yd_vent":                                                      # 인증 뒤 기계실 환기구 → 배수로(은신) → 둑 → 호송차 자물쇠 50
			plan += [["go", 5, 2], ["go", 5, 0], ["go", 15, 3, "Y-03"], ["use", 15, 2], ["wait", 0.3],
				["want", ["기어 들어간다"]], ["use", 15, 2], ["shot", "drain"],
				["check", "MQ104_SEARCH == 3", "수색조가 내려오기 전에 환기구로 빠짐(은신)"], ["wait", 1.5], ["shot", "drain_tunnel"], ["fight"],
				["go", 38, 4, "Y-05"], ["go", 39, 4], ["check", "MQ104_STAGE == 100", "둑 배수구로 나오면 끝"],
				["go", 800, 1095, "W"], ["shot", "post"], ["want", ["[자물쇠 따기 50]"]], ["use", 800, 1094], ["lock"],
				["wait", 1.5], ["check", "V_DOYUN == 2 and STAT_LOCKS == 1", "호송 칸 자물쇠를 땄다(V_DOYUN 2)"]]


func _process(dt: float) -> void:
	t += dt
	step_t += dt
	if t > 400.0:
		_finish("시간 초과")
		return
	_box(dt)
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
	if host.box.active or host.ev.busy() or host.busy:
		host.input_fn = func() -> Vector2: return Vector2.ZERO
		if s[0] != "fight":
			return
	match str(s[0]):
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
					print("  [봇] 걸어서 못 감: ", s, " 지금 ", host.map.id, " ", host.map.tile_of(host.player.loco.logical))
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
				if host.interact() or step_t >= 30.0:
					if step_t >= 30.0:
						print("  [봇] 말 걸기 실패: ", s[1], " 거리 ", p.distance_to(goal), " 맵 ", host.map.id, " ", host.map.tile_of(p), " 상대 ", host.map.tile_of(goal))
						_shot("talkfail")
					_next()
					return
			host.input_fn = _walk.bind(goal + (p - goal).normalized() * 34.0)
		"use":
			host.input_fn = func() -> Vector2: return Vector2.ZERO
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
			var alive := host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == "enemy")
			if alive.is_empty():
				if step_t > 1.5:
					host.combat.bot = {}
					_next()
				return
			step_t = 0.0 if step_t > 1.0 and not alive.is_empty() and t < 380.0 else step_t
			if t - last_report > 10.0:
				last_report = t
				print("  [봇] 싸움 %.0f초: 남은 %s · 체력 %d" % [t, str(alive.map(func(e): return "%s hp%d" % [str(host.map.tile_of(e.loco.logical)), int(e.cmb.hp)])), int(host.combat.pc.hp)])
			alive.sort_custom(func(a, b): return a.loco.logical.distance_to(host.player.loco.logical) < b.loco.logical.distance_to(host.player.loco.logical))
			var far: float = alive[0].loco.logical.distance_to(host.player.loco.logical)
			if far > 160.0:                                                # 멀면 다가간다(사거리·시야 안으로)
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
				tm._open_entry(0)
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
		"warp":                                                         # 다음 장소로 바로(확인 봇: 걸어가는 길은 다른 봇이 본다)
			host.enter(str(s[1]), str(s[2]) if s.size() > 2 else "from_W")
			_next()
		"crouch":
			host.combat.crouch = bool(s[1])
			_next()
		"face":
			host.player.loco.facing = int(s[1])
			host.player._show()
			_next()
		"wait":
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			if step_t >= float(s[1]):
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
			elif str(s[1]) == "seen_guard":
				ok = seen.has("guard_bark")
			elif str(s[1]) == "seen_rumor":
				ok = seen.has("rumor") and last_line != "……"
				print("  [봇] 소문: ", last_line)
			else:
				ok = StoryExpr.test(str(s[1]), st)
			checks.append([ok, str(s[2])])
			print("  [확인] %s %s" % ["○" if ok else "×", s[2]])
			_next()
		"shot":
			_shot(str(s[1]))
			_next()
		"end":
			_finish("")


func _next() -> void:
	i += 1
	step_t = 0.0
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
	if path.is_empty() or step_t < 0.05 or int(step_t * 2.0) % 6 == 0:
		path = NpcRoutine.with_start(host.map, p, goal)
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
			for w in want:
				for k in opts.size():
					if pick < 0 and str(opts[k]["text"]).contains(str(w)) and bool(opts[k].get("enabled", true)):
						pick = k
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
