## 이야기 상태 (SD-19 §6.9): 변수 저장소 + 퀘스트 + 주인공 서류(S.P.E.C.I.A.L.·태그·스킬) + 소지품 + 판정 기록.
## 조건·효과 식(StoryExpr)의 컨텍스트이고, 대화 실행기·이벤트 실행기·UI가 모두 이것 하나를 본다. 노드를 쓰지 않는 순수 객체.
class_name StoryState
extends RefCounted

## S.P.E.C.I.A.L.(SD-10 §2): 코드 → 화면 이름
const STATS := {"ST": "힘", "PE": "인지력", "EN": "지구력", "CH": "카리스마", "IN": "지능", "AG": "민첩성", "LK": "행운"}
## 스킬 13종(SD-10 §3.2): 키 → [화면 이름, 연관 능력치]
const SKILLS := {
	"BARTER": ["물물교환", "CH"], "BIG_GUNS": ["중화기", "EN"], "ENERGY": ["에너지 무기", "PE"], "EXPLOSIVES": ["폭발물", "PE"],
	"LOCKPICK": ["자물쇠 따기", "PE"], "MEDICINE": ["의학", "IN"], "MELEE": ["근접 무기", "ST"], "REPAIR": ["수리", "IN"],
	"SCIENCE": ["과학", "IN"], "SMALL_GUNS": ["소형 화기", "AG"], "SNEAK": ["은신", "AG"], "SPEECH": ["화술", "CH"],
	"UNARMED": ["비무장", "EN"],
}
const SKILL_ORDER := ["BARTER", "BIG_GUNS", "ENERGY", "EXPLOSIVES", "LOCKPICK", "MEDICINE", "MELEE", "REPAIR", "SCIENCE",
	"SMALL_GUNS", "SNEAK", "SPEECH", "UNARMED"]
const KARMA_RANGE := 1000
const AFF_RANGE := 100

var vars := VarStore.new()
var quests: QuestLog
var items := {}                         ## 아이템 ID -> 개수
var failed_checks := {}                 ## 실패한 화술 판정 ID(같은 NPC에게 다시 나오지 않는다)
var check_seed := 0                     ## 판정 고정 씨앗(새 게임 때 정한다)
var npcs := {}                          ## 인물 ID -> 자료(이름·세력·외형 등, game/data/npcs.json)
var names := {}                         ## 아이템·장소 ID -> 이름(\I·\L)
var weapon_out := false
var wielded := ""                       ## 손에 든 무기 열쇠(전투 모듈이 equip 때 넣는다 — 원고 blade() 판정, 1-11a)
var events: Array = []                  ## 알림: [{"kind": "karma"|"item"|"xp"|"aff"|"caps", ...}]
var fns := {}                           ## 추가 함수(이벤트 실행기 등이 등록): 이름 -> Callable(args: Array) -> Variant
var wear := {}                          ## 장비 사용 카운터(1-8a, SD-13 §8.2): 아이템 열쇠("W-002@1") -> 이번 단계에서 쓴 횟수
var boxes := {}                         ## 용기 상태(0-9): "맵:x,y@연도" -> {"items": {ID: 수}, "opened": 연 횟수, "taken": 꺼낸 횟수}
var stolen := {}                        ## 장물(SD-12 §9.2): 아이템 ID -> 훔친 수(그 수만큼 [장물] 표시)
var dead := {}                          ## 죽은 인물 ID -> true(0-9): 뒤 시대 맵에서 서지 않는다
var hazards := {}                       ## 함정 · 환경 폭발(1-9c): "맵:x,y" -> "done"(터짐·발동) | "off"(해체) | "seen"(발견) | "open"(열린 차폐 용기, 1-9d)
var rad_acc := 0.0                      ## 방사능(1-9d): PC_RADS에 아직 못 넣은 소수(틱당 최소 0.1)
var stat_tmp := {}                      ## 잠깐 능력치 보정(1-9e4 최루 기침 PE −2 등): 코드 -> 값. 저장하지 않는다(벗어나면 곧 풀린다)
var rad_drug := {}                      ## 라드-X 류(1-9d): {"pct": 저항 %, "t": 남은 초, "id"}
var places := PlaceLog.new()             ## 장소 발견 상태(1-2, SD-12 §5.5)
var deeds := Deeds.new()                ## 행적 기록 · 정보 전파(1-10c, SD-06 §6): 세력은 알게 된 뒤에 반응한다
var radio := Radio.new()                ## 라디오(1-10b, SD-12 §10): 켜기 · 맞춘 방송국 · 편성 위치 · 소식 대기열 · 방송 기록
var book := NpcBook.new()               ## 인물 수첩(1-2, SD-12 §3.11)
const ENEMY_FACTION := {"CR-401": "BJ", "CR-405": "BJ", "CR-435": "SB", "CR-436": "SB", "CR-437": "SB", "CR-438": "SB", "CR-534": "SB",
	"CR-456": "JH", "CR-457": "JH", "CR-403": "BJ", "CR-420": "YT", "CR-421": "YT", "CR-423": "YT"}
const UNNAMED := [["N-TRADER", "떠돌이 고물상", ""], ["N-VG-S1", "고물상", ""], ["N-VG-H1", "약초꾼", ""], ["N-VG-P1", "부품 장수", ""],
	["N-VG-C1", "옷 장수", ""], ["N-VG-F1", "국밥 장수", ""], ["N-VG-D1", "떠돌이 장사꾼", ""], ["N-UQ-K1", "아이", ""], ["N-UQ-C1", "털이꾼", ""], ["N-GA-B1", "패거리 두목", ""], ["N-GA-S1", "인솔조", "SB"], ["N-GA-S2", "인솔조", "SB"], ["N-REFUGEE", "피난민", ""], ["N-DOWNED", "쓰러진 민병", "JC_BC"],
	["N-HS-E1", "수송대 호위", "HS"], ["N-HS-E2", "수송대 호위", "HS"], ["CR-091", "짐소", ""],   # 1-8d 고개길 수송대
	["N-SA-G1", "승강장 경비", "JC_SA"], ["N-SA-G2", "승강장 경비", "JC_SA"], ["N-SA-G3", "승강장 경비", "JC_SA"], ["N-SA-R1", "환승촌 주민", "JC_SA"],   # 1-8f 사당 환승촌
	["N-SA-R2", "환승촌 주민", "JC_SA"], ["N-SA-R3", "환승촌 주민", "JC_SA"], ["N-SA-R4", "버섯 일꾼", "JC_SA"],
	["N-DB-1", "대방 분대원", ""], ["N-DB-2", "대방 분대원", ""],          # 1-D1 UQ-71 대방 지하차도
	["N-DS-B1", "봉천 감시조", "JC_BC"], ["N-DS-B2", "봉천 감시조", "JC_BC"], ["N-DS-S1", "승강장 경비", "JC_SA"], ["N-DS-S2", "승강장 경비", "JC_SA"],   # 1-D3 UQ-04 독산 7호 앞
	["N-DS-J1", "상인회 짐꾼", ""], ["N-DS-J2", "상인회 짐꾼", ""],
	["N-GR-D1", "객차 떠돌이", ""], ["N-GR-S1", "새벽인력 측량조", "SB"], ["N-GR-S2", "새벽인력 측량조", "SB"],   # 1-D4 구로 차량기지
	["N-YT-1", "패거리 수금원", ""], ["N-YT-2", "패거리 척후", ""], ["N-BC-1", "봉천 감시조", "JC_BC"], ["N-BC-2", "봉천 감시조", "JC_BC"], ["N-BC-3", "봉천 감시조", "JC_BC"],   # 1-11b SQ-S02
	["N-PS-1", "파수-3", ""],   # 1-11c SQ-S04 관제망 경비 로봇
	["N-PS-2", "경비 파수-3", ""],   # 1-11j SQ-S11 영등포 경찰서 서장실 경비판
	["N-BJ-S1", "수색조 분대장", "BJ"], ["N-BJ-S2", "수색조 계엄병", "BJ"],   # 1-11c · 1-11f 계엄군 수색조(1-11j: 게임 쪽 목록에 빠져 있던 것 — 이름표에 ID가 나오던 것)
	["N-BJ-P1", "순찰 분대장", "BJ"], ["N-BJ-P2", "순찰 계엄병", "BJ"],   # 1-11j SQ-S11 여의도 낮 순찰
	["N-GS-1", "각성회 신도", "GS"], ["N-GS-2", "각성회 신도", "GS"], ["N-GS-3", "각성회 신도", "GS"]]   # 1-8g 노량진 관제 중계소
var enc := {}                           ## 인카운터 상태(1-3, Encounters): 안전 간격 · 오늘 추적대 수 · EP 사용 · 휴전
var portrait_alias := {}                ## 인물 ID -> 초상화 키(맵에서 다른 시대 모습으로 선 인물: 2259년 아이 하도윤 등)


func _init() -> void:
	quests = QuestLog.new(vars)
	for c in STATS:
		vars.declare("PC_" + c, "int", 5)
	for i in 3:
		vars.declare("PC_TAG%d" % (i + 1), "str", "")
	for k in SKILLS:
		vars.declare("PC_SKP_" + k, "int", 0)         # 레벨업·책 등으로 더한 영구 증가분
	for k in ["PC_CAPS", "PC_XP", "PC_SEX", "PC_APT_PROXY"]:   # PC_APT_PROXY: 적성 평가 대리 작성 유형 1~4(0 = 아님, 단계 0-8)
		vars.declare(k, "int", 0)
	# MQ-P4 진행 표시(단계 0-9, 정합): DUCT 덕트 엿듣기 1 · FOLLOW 하도윤 동행 1 · KEY 무기고 열쇠 1 · ARMORY 무기고 열림 1 ·
	# TALK 설득 1 성공 2 실패 · BJ_KO 계엄병 사망 수 · SEC_KO 보안요원 사살 수 · CAUGHT 붙잡힌 횟수 · DECOY 데크 분대가 빠짐(1 하도윤 미끼 · 2 엄마의 거짓 무전)
	# S7_THEFT_SEEN: 볼트 안에서 훔치다 들킨 횟수(SD-12 §9.2) · S7_ASSAULT: 주민을 때린 횟수 · S7_KILLS: 죽인 주민 수(SD-10 §6.3)
	for k in ["MQP4_DUCT", "MQP4_FOLLOW", "MQP4_KEY", "MQP4_ARMORY", "MQP4_TALK", "MQP4_BJ_KO", "MQP4_SEC_KO", "MQP4_CAUGHT", "MQP4_DECOY",
			"S7_THEFT_SEEN", "S7_ASSAULT", "S7_KILLS"]:
		vars.declare(k, "int", 0)
	# MQ-101 진행 표시(단계 0-10, 정합): DOG 백구 장면(1 들개가 몰아붙임 · 2 쫓아 줌 · 3 지나침) · TRADE·WATER·RAD 생활 세 가지 ·
	# NIGHT 밤(1 쪽지 · 2 추적조가 아랫문에) · DEAD 방어전에서 죽은 감시조 · TANK 비밀 저수조를 앎 · ROOF 옥상길을 들음 · BOARD 수배 쪽지를 읽음 ·
	# FIGHT 방어전 시작 · PC_RADS 방사능(SD-11 §11.2) · PD_BC·PD_R01 판도 사건 보정(정착지 쪽, SD-06 §5) · GAME_DAY 게임 날짜(1 = 10. 23.)
	for k in ["MQ101_DOG", "MQ101_TRADE", "MQ101_WATER", "MQ101_RAD", "MQ101_NIGHT", "MQ101_DEAD", "MQ101_TANK", "MQ101_ROOF", "MQ101_LOAN",
			"MQ101_BOARD", "MQ101_FIGHT", "PC_RADS", "PD_BC", "PD_R01", "GAME_DAY"]:
		vars.declare(k, "int", 0)
	vars.declare("PC_EYES", "str", "")                       # 쓴 눈 장비(아이템 ID — A-106 구울 가면, 1-11e)
	vars.declare("PC_SMELL", "int", 0)                        # 몸에 바른 여왕 페로몬 남은 게임 분(1-D5b 왕개미 위장 — AntColony)
	vars.declare("PC_TORSO", "str", "A-001")                # 입은 몸통 옷(아이템 ID) — 처음은 볼트 점프슈트(MQ-P2 지급)
	Wanted.declare(self)                                   # 수배도 하루 누계·공고 인상착의(1-3)
	# 생포(1-3, SD-03a §6.7): CAPTURE_DAY 마지막으로 잡힌 날(하루 1번) · CAPTURE_AT 잡힌 시각(분, 3일 계산) · SB_COLLAR 근태 목걸이(1 채워짐)
	# SB_CUFF 수갑(1 채워짐) · CAPTURE_BY 잡은 쪽(1 새벽인력)
	vars.declare("STAT_HACKED", "int", 0)                     # 통계: 해킹한 단말(SD-12 §3.5, 1-4)
	vars.declare("STAT_LOCKS", "int", 0)                      # 통계: 딴 자물쇠(SD-12 §3.5, 1-5)
	for k in ["MQ104_FIRE", "MQ104_DESK", "MQ104_IDS", "MQ104_SEEN", "MQ104_ROLL", "MQ104_LOG", "MQ104_FILES", "MQ104_RIFLE",
			"MQ104_AUTH", "MQ104_VENT", "MQ104_LAST", "MQ104_SEARCH", "MQ104_DOYUN", "MQ104_GUARDS", "MQ104_DAY",
			"PL_LETTER", "PL_VIEW", "PL_TECH", "PN_SON", "PN_Q10", "PN_NURSE", "PN_HEAL_DAY", "PN_SIM", "PN_GIL", "PN_LEDGER", "PN_NAM", "PN_NAM_TIP"]:
		vars.declare(k, "int", 0)                                     # MQ-104 여의도 집결지 진행(1-5, Act1Paths)
	# MQ-102·103 진행 표시(단계 1-4, 정합): C1~C3 단서 셋(1 들음) · ROBOT 잠든 파수 로봇을 봄 ·
	# GATE 지하시장에 들어온 길(1 출입세 · 2 카리스마 · 3 남쪽 통로 · 4 역사 쇼핑몰) · JOB 상인회 일(1 맡음 · 2 둥지 비움 · 3 보상) ·
	# HIRE 박춘삼 고용 · SNEAK 배전실 몰래(1 환풍구 들킴 없이 · 2 들킴 · 3 출입 단말 해킹) · DOOR 배전실 문(1 출입패 · 2 해킹) ·
	# CONF 고백(1 털어놓음 · 2 화술 실패) · LOG 작업 단말 일지를 읽음 · AMBUSH 북쪽 출구 매복(1 대기 · 2 끝) · NEST 둥지(1 비움) ·
	# FOUNT 분수에 던진 캡 · JM_REG 지하시장 단골(가격 −10%)
	for k in ["MQ102_C1", "MQ102_C2", "MQ102_C3", "MQ102_ROBOT", "MQ103_GATE", "MQ103_JOB", "MQ103_HIRE", "MQ103_SNEAK", "MQ103_DOOR",
			"MQ103_CONF", "MQ103_LOG", "MQ103_AMBUSH", "MQ103_NEST", "MQ103_FOUNT", "JM_REG", "JM_GU_MET"]:
		vars.declare(k, "int", 0)
	# MQ-105 새벽인력 본소 진행 표시(단계 1-6, Act1Paths): GAME_HOUR 지금 시(0~23, 진행기 시각 글에서) · RAID 정면 습격(1 교전 · 2 끝) ·
	# PASS 정문(1 구매자 · 2 거래 손님 · 3 쫓겨남) · DOGS 경비견(1 고기에 정신 팔림 · 2 모두 쓰러짐) · SAFE 금고 열림 ·
	# KEY 허리춤 열쇠 · FREED 풀어 준 '인력' 수 · READ 장부를 읽음 · DEAL 이름을 산 거래 · BURNT 황두칠이 장부를 태움 · DEBT 112명 빚 탕감 ·
	# BJ 계엄군 초소에 넘김 · TALK 소장 면담(1 만남 · 2 열쇠를 빼앗긴 뒤 마당으로 내려감) · BOUGHT 88번을 삼 · DEPO 보증금을 냄
	# SB_127 훅 「127번」(1 아내가 부탁함 · 2 우리에서 빼 옴 · 3 값을 치르고 삼 · 4 집에 돌아감) · GB_PASS 길금순이 벽장 통로를 알려 줌
	for k in ["GAME_HOUR", "SB_RAID", "SB_PASS", "SB_DOGS", "SB_SAFE", "SB_KEY", "SB_FREED", "SB_READ", "SB_DEAL", "SB_BURNT",
			"SB_DEBT", "SB_BJ", "SB_TALK", "SB_BOUGHT", "SB_DEPO", "SB_127", "GB_PASS"]:
		vars.declare(k, "int", 0)
	# MQ-106 첫 번째 추적자(단계 1-7, Mq106): CUSTODY 귀빈실(1 걸어 들어감 · 2 생포 · 3 새벽인력 인계) · TALKED 남궁혁 면담 ·
	# SEIZED 압수품 보관함에 물건이 있다 · AT 귀빈실에 든 시각(분) · Q* 면담에서 물은 것 · PD_R01_BJ 판도 사건 보정(R01 비상정부 쪽, SD-06 §5)
	for k in ["MQ106_CUSTODY", "MQ106_TALKED", "MQ106_SEIZED", "MQ106_AT", "MQ106_QLINE", "MQ106_QWHY", "MQ106_QGRID", "MQ106_QDEAD", "MQ106_QSIGN", "NAMGUNG_MET", "PD_R01_BJ"]:
		vars.declare(k, "int", 0)
	# 길 위 인카운터(1-E, SD-22): RE036_MET 떠돌이 고물상을 만난 적 · RE036_NEWS 길 소식 차례 · RE042_N 유해 쪽지 차례(같은 글이 연달아 나오지 않게)
	for k in ["RE036_MET", "RE036_NEWS", "RE042_N", "VG_TALK", "VG_NEWS"]:   # 1-L 일반 장사꾼 인사 · 동네 이야기 차례
		vars.declare(k, "int", 0)
	# UQ-125 털린 은닉처(1-L, SD-05 §3.20): 진행기 Stash만 쓴다 — WHO 범인 · HERE 범인 자리 · KID 아이 · GUARD 맡길 사람 · FENCE 장물 진열 · R 결과
	for k in ["UQ125_WHO", "UQ125_HERE", "UQ125_KID", "UQ125_GUARD", "UQ125_FENCE", "UQ125_R"]:
		vars.declare(k, "int", 0)
	# 가산 아울렛(1-D6, 1-D 계획 §12.6): 진행기 Ga만 쓴다 — SEEN 망꾼 · BOX 작업복 상자(1 넘김 · 2 태움 · 3 바꿔치기 · 4 인솔조가 가져감 · 5 빈 상자) ·
	# BOX_DAY 고른 날 · BOX_DONE 판도에 반영됨 · CRATE_DAY 상자를 처음 본 날 · FEUD 인솔조와 패거리가 틀어짐 · DECOY 진열창 미끼 · COUNTED 재고 세기에 걸림 ·
	# TOLD 놓친 소문 표지 · BOSS 두목 처리(던전 정리 식) · PICK 인솔조 수거 날 · PAID 넘김 봉투 받음 · PD_R01_6 판도 PD-R01-6 사건 보정(+ 새벽인력 · − 약탈자, SD-08 §13) · PC_HEAD 쓴 머리 장비(아이템 ID — A-074 방독면)
	for k in ["GA_SEEN", "GA_BOX", "GA_BOX_DAY", "GA_BOX_DONE", "GA_CRATE_DAY", "GA_FEUD", "GA_DECOY", "GA_DECOY_DAY", "GA_COUNTED", "GA_TOLD", "GA_BOSS", "GA_PICK", "GA_PAID", "PD_R01_6"]:
		vars.declare(k, "int", 0)
	vars.declare("PC_HEAD", "str", "")
	# 구로 공단 지식산업센터 · 문래(1-D7, 1-D 계획 §13.5 · SD-05 §3.21 UQ-69): 진행기 Ks만 쓴다 — 뜻은 script/act1/KS.txt 머리 주석
	for k in ["UQ69_PAPER", "UQ69_DIE", "UQ69_DEST", "UQ69_DEST_DAY", "UQ69_HEARD", "UQ69_MET", "UQ69_T1", "UQ69_T2", "UQ69_T3", "UQ69_ASKED", "UQ69_HALF",
			"UQ69_DONE_DAY", "UQ69_REWARD", "UQ69_TOLD", "KS_LINE", "KS_ALARM", "KS_WARN", "KS_ESTOP", "KS_CARD", "KS_CARD_N", "KS_WORK", "KS_WORK_N",
			"KS_WORK_DAY", "KS_AWARD", "KS_STAMP", "KS_CRANE", "KS_TOLD", "KS_SEEN", "MR_LOCKER", "MR_LOCKER_DAY", "MR_BOARD", "MR_BOARD_WK", "MR_FEET"]:
		vars.declare(k, "int", 0)
	# 여의도 대학병원(1-D8, 1-D 계획 §14.7 · SD-05 §3.22 UQ-126 · RQ-47): 진행기 Hp만 쓴다 — 뜻은 script/act1/HP.txt 머리 주석
	for k in ["HP_DAY0", "HP_LOST", "HP_BLUR", "HP_BLUR_DAY", "HP_WAY", "HP_TRUST", "HP_CUT", "HP_OVR", "HP_OVR_END", "HP_NIGHT", "HP_GEN", "HP_MASK", "HP_VISIT", "HP_VISIT_DAY", "HP_PUSH_DAY", "HP_BED", "HP_ASK1", "HP_ASK2", "HP_ASK3", "HP_OJ", "HP_MOVE_DAY", "HP_SKIP", "HP_MORGUE", "HP_PHASE", "HP_SAT", "HP_LETTER", "HP_MET", "HP_TOLD", "HP_DONE_DAY", "HP_VON", "HP_SEEN", "HP_VMASK", "HP_LTOLD",
			"RQ47_N", "RQ47_WK", "RQ47_LAST", "DG_STOP"]:
		vars.declare(k, "int", 0)
	# 여의도 유리탑 3동 · 증권가 객장(1-D9, 1-D 계획 §15.7 · SD-05 UQ-06): 진행기 Yt만 쓴다 — 뜻은 script/act1/YT.txt 머리 주석
	for k in ["YT_FORGE", "YT_FORGE_T", "YT_TEMP", "YT_LOCK", "YT_UNK", "YT_DEAD_DM", "YT_ESCORT", "YT_POWER", "YT_MOUND", "YT_SEEN", "YT_GATE1", "YT_CLERK_SEEN",
			"YT_ROBOT_OK", "YT_ELEV", "YT_INC", "YT_INC_DAY", "YT_R", "YT_DOZE", "YT_DMTAKE", "YT_HBTAKE", "YT_OJTAKE", "YT_TAPE", "YT_SG", "YT_KBN", "YT_UPC", "YT_UP", "YT_NOCARD", "YT_CUP", "YT_CUPSEEN", "YT_TRAP", "YT_NO", "YT_HK2", "YT_HK3", "YT_SIDE", "YT_CTAPE", "YT_CDONE", "YT_BUMP_DAY", "UQ06_RADIO", "UQ06_RESULT", "UQ06_DAY", "UQ06_ASKED", "UQ06_MET", "UQ06_GONE", "UQ06_BACK", "UQ06_TOLD", "UQ06_HEARD"]:
		vars.declare(k, "int", 0)
	for k in "CART_MAP CART_X CART_LOAD CLOTH JOB JOB_DMG RUN RUN_DAY KNOW ENG WOO RUSH HATCH LIST LIST_DAY GHOUL SK QK SCATTER CLEAR CARR_DAY YIELD TAP SEEN DIG HEARD RIDE CART_NEAR JOB_DAY BACK WEAR RAM GNO TAPJH LOUD CDIR".split(" "):
		vars.declare("U04_" + k, "int", 0)                                   # 1-D10 U04 여의도 지하(진행기 U04)
	vars.declare("BC_DOUBT_DAY", "int", 0)                    # 정보 전파(1-10c): 걸어 들어감 소문이 봉천에 닿은 날 + 1 — 그날까지 봉천 사람들이 수군거린다(SD-20 N8)
	# 거처(1-8b, SD-15 §7): HOME_BC 봉천 옥탑방(0 없음 · 1 내 방 · 2 압류) · HOME_BC_OK 조건이 찬 날(그다음 날부터 조만석이 열쇠를 준다) ·
	# WELL_RESTED 숙면이 끝나는 절대 분(0 = 없음, SD-11 §11.5 경험치 +10% 12시간) · HOME_BC_NOTE 문 앞 알림(§7.7: 1 '출입 자제' 쪽지 · 2 읽음 · 3 압류 딱지 · 4 읽음 · 5 재개방) ·
	# BAEKGU_NAP 오늘 백구가 옥탑방 문 앞에서 자는 날(하루 판정마다 굴림)
	for k in ["HOME_BC", "HOME_BC_OK", "WELL_RESTED", "HOME_BC_NOTE", "BAEKGU_NAP", "INFO_RUMOR_R01", "INFO_RUMOR_R02", "CARAVAN_V54", "MEDIC_AT", "TR_YEON_MET", "TR_SO_MET", "TR_EOM_MET"]:   # 정보상 장소 소문 산 수(1-8d)
		vars.declare(k, "int", 0)
	# 사당 환승촌(1-8f): 인물 첫 만남 · SA_MAKCHA_HEARD 서쪽 터널 '막차 손님' 들음(SQ-S05 '이미 앎') · SA_MAT_UNTIL 승강장 매트 빌린 끝 절대 분 ·
	# SD_MAP_UG 노선도 봄 · SD_BOARD_SEEN 운행 칠판 봄 · SD_LR05 · SD_LR09 기록물 · U02_OPEN 4호선 남쪽 터널 철망 문(1-D2: 1 열림)
	for k in ["SD_MET_HUH", "SD_MET_PYO", "SD_MET_WI", "SD_MET_SEONG", "SD_MET_BAN", "SD_MET_TAK", "SA_MAKCHA_HEARD", "SA_MAT_UNTIL", "SD_MAP_UG", "SD_BOARD_SEEN", "SD_LR05", "SD_LR09", "U02_OPEN"]:
		vars.declare(k, "int", 0)
	# 사당 고개 검문소 · 노량진 관제 중계소(1-8g): 첫 만남 · SG_REFUSED 중립 '동행 요청' 거절(한 번 −10) · SG_ISSUED 임시 등록증 첫 발급 ·
	# GS_MET_RJ 류정을 만남(MQ-207 '이미 앎') · GS_CARD_SEEN 천공 카드 벽의 내 번호 · GS_LR50 「도성 문답」
	for k in ["SG_MET_HWANG", "SG_MET_KWON", "SG_REFUSED", "SG_ISSUED", "GS_MET_RJ", "GS_MET_HAN", "GS_MET_EUNSOL", "GS_MET_MA", "GS_MET_HA", "GS_CARD_SEEN", "GS_LR50"]:
		vars.declare(k, "int", 0)
	# SQ-S01 외눈의 인식표(1-11a, SD-04a §4.1 · SideR01): SOL 해법(1 소탕 · 2 백구 대치 · 3 애니멀 프렌드 · 4 낮잠 · 5 미끼) · LEFT 무리가 남쪽 능선으로 떠남 ·
	# LEFT_DAY 떠난 날 · DROP 인식표가 뼈 마당 바닥에 떨어져 있음 · TAG_DAY 인식표를 처음 쥔 날(7일 소지 자동 종료) · DOG 백구 동행(1 함께 · 2 다쳐 돌아감 · 3 일을 마치고 개집으로) ·
	# FEED 남솔의 밥 당번 · COLL 목줄 더미 조사 횟수 · BAIT 미끼를 놓은 절대 분 · BETRAY 백구를 공격함 · CLEAR_DAY 소탕한 날(3일 뒤 시궁쥐 · 크리처 인카운터 −30%) ·
	# KILLS 쓰러뜨린 무리 수 · KILL_DAY 그날(72시간 뒤 다시 채움) · EOM 엄태경에게 소탕을 알림 · BC 봉천이 아직 모르는 해법 호감(돌아오면 반영 — 공개도 1, SD-06 §6) · NAP 지금 외눈이 둥지에서 잔다(진행기)
	# PK_045 애니멀 프렌드 랭크(퍽 창은 1-12 — 지금은 변수만)
	for k in ["SQ_S01_SOL", "SQ_S01_LEFT", "SQ_S01_LEFT_DAY", "SQ_S01_DROP", "SQ_S01_DROP_AT", "SQ_S01_TAG_DAY", "SQ_S01_DOG", "SQ_S01_FEED", "SQ_S01_COLL", "SQ_S01_BAIT",
			"SQ_S01_BETRAY", "SQ_S01_CLEAR_DAY", "SQ_S01_KILLS", "SQ_S01_KILL_DAY", "SQ_S01_EOM", "SQ_S01_BC", "SQ_S01_NAP", "SQ_S01_BOWL", "PK_045"]:
		vars.declare(k, "int", 0)
	vars.declare("SQH_TAG", "int", -1)
	# SQ-S02 물 반 컵의 값(1-11b, SD-04a §4.2 · SideS02): ARM MQ-101 끝난 날 · POSTED 급수 제한 쪽지(DAY0 밸브가 잠긴 첫날) · LEVEL 수위계 칸 · OPEN 밸브(1 열림 · 2 물값 사흘, PAID 끝 날) ·
	# SOL 밸브 해법(1 탈환 · 2 우회 관로 · 4 계엄군) · B 우회 관로 · BJ 계엄사령부 관리(BJ_AT 분대 시각) · CAMP 밸브 캠프가 빔(CKILLS · TDEAD 수금원 · DDEAD 경비견 · HOT 적대) ·
	# GUARD 봉천 감시조 상주 · MAP 척후 지도 · SIREN 사이렌(2 쓰러짐 · 3 지도를 팜, NKILLS 척후 · NS_HOT) · HAND 글씨 대조 · KNOW 남건희를 앎 · IN 내부자(1 고발 · 2 타이름 · 3 함정 · 4 묵인) ·
	# PIPEMAP 관로 지도 · J1 · J2 이음 지점(AT 주인공 곁 지점) · TRAP_AT 03시 함정(TRAP_DONE · FIGHT 싸우는 중) · NH_DEAD 남건희 죽음(NH_KILLED 주인공이) · EXILE_DAY 추방 날 ·
	# STOP_DAY 대장간 간 날 · NIGHT_DAY 윗문 거래를 들킨 밤 · HEARD 조수안에게 들음 · REWARD 사례 · DONE_DAY 단계 70 날 · RAID_UNTIL 밤 습격 +30% 끝 날 · SOL_E 물값 봉천 +2 · DRY_HINT
	# JC_PROB_BC 봉천 '문제 해결'(SD-04a §2.5 — 거처 조건 표지)
	for k in ["ARM", "POSTED", "DAY0", "LEVEL", "OPEN", "PAID", "SOL", "B", "BJ", "BJ_AT", "CAMP", "CKILLS", "TDEAD", "DDEAD", "HOT", "NS_HOT", "GUARD", "MAP", "SIREN", "NKILLS", "HAND", "KNOW", "IN", "PIPEMAP", "J1", "J2", "AT", "TRAP_AT", "TRAP_DONE", "FIGHT", "NH_DEAD", "NH_KILLED", "EXILE_DAY", "STOP_DAY", "NIGHT_DAY", "HEARD", "REWARD", "DONE_DAY", "RAID_UNTIL", "SOL_E", "DRY_HINT", "SHADOW"]:
		vars.declare("SQ_S02_" + k, "int", 0)
	vars.declare("JC_PROB_BC", "int", 0)
	# SQ-S03 곰팡이의 근원(1-11d, SD-04a §4.3 · SideS03): ARM MQ-101 끝난 날 · POSTED 게시판 쪽지 · WALL 이음 벽 얼룩 · P1 P2 P3 조사 지점 · SPRAY 분무기 · GATE 수문(1 살핌 · 2 닫음) ·
	# NAME · TAGSEEN 정영수 · TAG 볼트 기록(1 · 2 · 3) · CALLS 인터컴 · VAULT 방금례(1 받음 · 2 수치) · SOL 처리(1 소각 · 2 약품 · 3 원인 차단) · CLEAN 맑아짐 · DRY_DAY C 마르기 시작 ·
	# FILTER D 필터(FILTER_DAY · FILTER_N 며칠째 · SMELL 30일 뒤 곰팡내) · RACC_UNTIL 소각 뒤 너구리 · RAT RAT2 KING(1 섬 · 2 쓰러짐) KING_HP(물러선 왕쥐의 남은 체력) ERAT 쥐 무리 · IN · VISITS K-08 · REWARD · DRINKS 오늘 꼭지 · SAID · PIPE S02 B 표지
	for k in "ARM POSTED WALL P1 P2 P3 SPRAY GATE NAME TAGSEEN TAG CALLS VAULT SOL CLEAN DRY_DAY FILTER FILTER_DAY FILTER_N SMELL RACC_UNTIL RAT RAT2 KING KING_HP ERAT IN VISITS REWARD DRINKS SAID PIPE".split(" "):
		vars.declare("SQ_S03_" + k, "int", 0)
	vars.declare("SQR_S03", "int", 0)                                     # 4막 볼트 반응(SD-04a §4.3 정보 전파 — MQ-401 이월)
	# SQ-S04 도성이 뒤척인다(1-11c, SD-04a §4.4 · SideS04): ARM MQ-102가 열린 분 · WAKE_AT 깨어날 21시 · WAKE 깨어난 분 · HELD 남솔이 철망 안 · DEADLINE 보호 기간 끝 ·
	# OUT 나온 길(1 인증 · 2 파괴 · 3 은신 · 4 정비 · 5 만료 · 6 마을) · SLEEP 잠든 까닭(1 전지 회수 · 2 대기 · 3 정비 모드) · KILLED · TKILLED 부순 파수 · 감시포(비트) ·
	# HOT 제압 중 · LOITER 아랫문 서성임 끝 · D 정비(1 오는 중 · 2 끝, D_AT) · TEST 시험 가동 · BATT 전지 회수 · F 단말 대기 · LETTER 편지 · AWAY 노량진(돌아오는 날) ·
	# BELL 종(1 봄 · 2 들음 · 3 쪽지) · RED 남태하 · HELP 감시조 지원 · FENCE 철조망 · CHASE 이탈 경보 대기 · FIGHT 감시조가 싸우는 중 · UP 주민센터 파수가 서 있다 ·
	# GUARD_BACK 노량진에서 돌아오는 분 · VILLAGE_AT 마을이 철망을 여는 분 · B 셋 다 부숨 · PD_LOCK 거점 '관악산 송신소' 공백 고정 · TICKET 주인공 번호표 0414(재미 검수)
	for k in ["ARM", "WAKE_AT", "WAKE", "HELD", "DEADLINE", "OUT", "SLEEP", "KILLED", "TKILLED", "HOT", "LOITER", "D", "D_AT", "TEST", "BATT", "F", "LETTER", "AWAY", "BELL", "RED", "HELP", "FENCE", "CHASE", "FIGHT", "UP", "GUARD_BACK", "VILLAGE_AT", "B", "PD_LOCK", "TICKET"]:
		vars.declare("SQ_S04_" + k, "int", 0)
	# SQ-S05 환승촌 막차(1-11e, SD-04a §4.5 · SideS05): ARM MQ-102가 열린 분 · GATE 철망 문 경고 · IN U-01 들어섬 · BSEEN 테이프 칸 봄 · ROBOT 역무 파수-3(1 깨어 걷는 중 · 2 역무실) ·
	# PASS 허순자 정기권(1 빌림 · 2 돌려줌) · TIP 반로아의 시각 · BCAST 방송(1 혼자 · 2 허순자가, BCAST_AT 분) · MAD 무단 방송 꾸중 · SOFT 허순자가 누그러짐 · SOL 해법(1 방송 · 2 소탕 · 3 구울의 말 · 4 정기권 통과) ·
	# LEFT 떠난 손님 · WOKE 군집이 깨어남 · DOOR 철문 · JU 주성호(1 부탁 · 2 동행 · 3 갈라섬, JU_AT) · REPORT 보고 · FENCE 철망 횟수 · LINE 행렬을 봄 · PYO 표하경 할인 · RAT 터널 쥐 ·
	# SLEEPER 선 채 잠든 손님 · MASK 가면 손님 · HOT 깨운 업보 · REWARD 사례 · AWAY 주성호 노점 비움 · DAY 해법 날(소문 하루 늦게) ·
	# REMAIN 남은 손님 · EMPTY 역무원까지 다 떠남 · ENT 측선에 든 손님 수 · WIND 허순자 태엽 시각 · SEEN 허순자 눈앞 방송
	for k in "ARM GATE IN BSEEN ROBOT PASS TIP BCAST BCAST_AT MAD SOFT SOL LEFT WOKE DOOR JU JU_AT REPORT FENCE LINE PYO RAT SLEEPER MASK HOT REWARD AWAY DAY REMAIN EMPTY ENT WIND SEEN".split(" "):
		vars.declare("SQ_S05_" + k, "int", 0)
	# SQ-S06 근무자: 공란(1-11f, SD-04a §4.6 · SideS06): JIN 진해원의 자리(0 탄약고 · 1 호위 · 2 짐칸 · 3 노들섬 남문 · 4 영창 · 5 계엄군 손 · 6 죽음 · 7 혼자 길 위) ·
	# MET 만남 · FED 밥 · CLOTH 평상복 · PAPERS 등록증 · ROUTE 길 셋을 들음(2 해법 인물에게 물음) · CHECK 다리목(1 통과) · CARAVAN 짐칸 거래 · BOAT 배 · NOTE 황보서현 쪽지 ·
	# PERSUADE 자수 설득 · TAG 군번줄 챙김 · DECOY 미끼 · SOL 해법(1 짐칸 · 2 등록증 · 3 배 · 4 자수 · 5 인도 · 6 처치 · 7 혼자 닿음 · 8 혼자 잡힘 · 9 남문) · TOLD 위치만 알림 ·
	# LEADER 분대장과 마주친 횟수 · DISC 첫 접촉 분 · PHASE 수색 권역(0 없음 · 1 시흥 · 2 사당 · 3 봉천 · 4 노량진) · SQUADS 권역별 마주침(비트) · SOLO_DAY · SOLO_P 혼자 확률 ·
	# JAIL_DAY 영창 날 · REWARD · DAY 해법 날 · HOT 수색조와 싸움 · FLYER 전단 · FOUND_AT · HID 숨은 곳 · SEEN_SG 사당 고개를 봄 · GATE_AT · CARGO_AT 짐칸 출발 분 · ARM
	for k in "ARM JIN MET FED CLOTH PAPERS ROUTE CHECK CARAVAN BOAT NOTE PERSUADE TAG DECOY SOL TOLD LEADER DISC PHASE SQUADS SOLO_DAY SOLO_P JAIL_DAY REWARD DAY HOT FLYER FOUND_AT HID SEEN_SG GATE_AT CARGO_AT FOOD SALUTE KWON BFIGHT SAID NEAR KIND HOW UNI".split(" "):
		vars.declare("SQ_S06_" + k, "int", 0)
	vars.declare("SQE_DESERTER", "int", 0)                                # MQ-502 증인(노들섬에 닿은 진해원)
	# SQ-S08 같은 명찰의 두 사람(1-11g, SD-04a §5.1 · SideS08): SAW 다툼 · LEDGER 명부(1 허락 · 2 열람) · DEAD 사망자 칸 · DESK 창구(1 줄 · 2 화술 · 3 카드 · 4 서류함 · 5 이름으로) ·
	# MATCH 사진 대조 · NOTEBOOK 근무 수첩 · TOLD_A · TOLD_B 각자에게 · TOOL B 공구함 · ADDR A 주소 · GRADE 등급 · SOL 해법(1 이름 · 2 둘 다 · 3 진짜 · 4 그대로 · 5 하나 남음 · 6 둘 다 죽음) ·
	# TICKET 번호표 · WAIT 전광판 칸 · SHUT 창구 폐쇄 날 · PROXY 해골 번호표 · STRAIN 긴장 바크 단계 · REWARD · FIX_DAY 무료 수리 · FOUND_DAY 기록 찾은 날 · DAY 해법 날 · CARRY 수습 · GHOULS 초소 구울 · SEEN_A 금하람 판 · SEEN_B 광장 방문 수 · CARD K-33 출입 카드 한 장 넣음 · LATE 진료소 뒤 늦은 이름(D → A)
	for k in "SAW LEDGER DEAD DESK MATCH NOTEBOOK TOLD_A TOLD_B TOOL ADDR GRADE SOL TICKET WAIT SHUT PROXY STRAIN REWARD FIX_DAY FOUND_DAY DAY CARRY GHOULS SEEN_A SEEN_B CARD LATE".split(" "):
		vars.declare("SQ_S08_" + k, "int", 0)
	# SQ-S09 127번(1-11h, SD-04a §5.2 · SideS09): 채윤재의 자리는 SB_127 하나(0 · 1 우리 · 2 길금순 칸 · 3 정문 앞 · 4 구로 집 · 5 7일째 줄 · 6 봉천 · 7 지하시장 · 8 팔림).
	# START 발동 날 · DUE_M/DUE_D 트럭 날짜 · WIFE · TOOK(1 받음 · 2 사양) · DEBT · SOL1(1 몸값 · 2 우리 열기 · 3 장부 · 4 습격) · SOL2(1 지하로 · 2 운송로 · 3 막음 · 4 갈고리 · 9 부서짐) ·
	# NOTICE 갈고리가 눈치챈 날 · REQ 길금순 부탁 · ORDER 지시서 · LIST · LISTGIVEN · WALL · PLACE(1 구로 · 2 봉천 · 3 지하시장 · 9 혼자) · UNCOL · DOOR · LEARN · CRACK · GATE · OUT · HAGGLE · REWARD · CLOSED · DAY · CHECK · SPENT88 아내 돈으로 88번 · SAID88 · WAITED 혼자 와서 판자 앞에서 기다림
	for k in "START DUE_M DUE_D WIFE TOOK DEBT SOL1 SOL2 NOTICE REQ ORDER LIST LISTGIVEN WALL PLACE UNCOL DOOR LEARN CRACK GATE OUT HAGGLE REWARD CLOSED DAY CHECK SPENT88 SAID88 WAITED".split(" "):
		vars.declare("SQ_S09_" + k, "int", 0)
	vars.declare("SQR_S09", "int", 0)
	vars.declare("SQS_S09", "int", 0)
	vars.declare("PD_R02_SB", "int", 0)
	vars.declare("PD_R02_BJ", "int", 0)                                  # 판도 R02 BJ 사건 보정(1-D5b UQ-68 — 관측조가 금탑 꼭대기 불을 쓴다, SD-05)
	# SQ-S10 오늘의 4번 인력(1-11i, SD-04a §5.3 · SideS10): 기라희의 자리는 SQ_S10_KIRA 하나(0 우리 H-03 22 · 1 고척 지하 대기실 · 2 경매 무대 · 3 풀려나 고척 정문 앞 ·
	# 4 정착(PLACE 1 봉천 · 2 노들 남문 앞 · 3 지하시장) · 5 세이프빌 식당(친척) · 6 세이프빌 112동 노역(팔림) · 7 주인공 소유(본소 22번 칸) · 8 다른 구매자(탱크마을)).
	# AUCTION 그녀의 경매일(GAME_DAY) · OPEN 오늘이 경매일 06~11시 · HOST 견적이 고척에 있음 · SEO 기서윤이 VIP 박스에(경매일 09시~경매 끝) · PADDLE 내 패 · PRICE 현재가 ·
	# LEAD 지금 앞선 패(0 나 · 1 기서윤 · 2 십장 · 3 감독관 · 9 아무도) · WATCH 망치 하나둘 · BUDGET 예산을 털어놓음(상한 600) · TOLD 진술 · CARVE 각인 · KIN 친척 · THREAT 장부로 위협 ·
	# SWAP 장부와 계약서를 바꿈 · LEDGER 구매 장부(1 손에 · 2 우도하에게) · CAST 방송(1 넘김 · 2 송출됨) · CAST_DAY · RAID · SOL(1 낙찰 · 2 친척 · 3 습격 · 4 방송만 · 5 소유 · 6 본소 매입 · 7 되팜 · 8 교환 · 9 팔림) ·
	# PLACE · REFUSED 보상 사양 · REWARD · OLD 3번 노인 · FORE 십장이 끼었다 빠짐 · GAVE 패를 기라희에게 · TAK 탁현수 부탁(1 받음 · 2 물 줌) · CODE 장부함 번호 앎 · STOP 세이프빌 구매 중단 ·
	# DONE 경매 끝 · SEEN 칠판 봄 · LATE 늦게 낌 · PEN 대기실 문 열림 · GLANCE 유리창 봄 · SAID 기라희가 정착지를 말함 · JUMP 한 번에 600 시도 ·
	# AM/AD 그녀의 경매 월·일 · NM/ND 다음 경기 월·일 · KSAY 단상의 한 줄(1 450 · 2 600 · 3 750) · CAPV 지금 경쟁자 상한 · SEOIN 기서윤이 4번에 패를 듦 · BOOTH 중계석 쪽지 봄 · CAT 캣워크로 내려옴(장부함 — 견적 눈 밖)
	for k in "START AUCTION OPEN HOST SEO KIRA PADDLE PRICE LEAD WATCH BUDGET TOLD CARVE KIN THREAT SWAP LEDGER CAST CAST_DAY RAID SOL PLACE REFUSED REWARD OLD FORE GAVE TAK CODE STOP DONE SEEN LATE PEN GLANCE SAID JUMP AM AD NM ND KSAY CAPV SEOIN BOOTH CAT".split(" "):
		vars.declare("SQ_S10_" + k, "int", 0)
	vars.declare("SQR_S10", "int", 0)
	vars.declare("SQS_S10", "int", 0)
	# SQ-S11 토요일의 여의도(1-11j, SD-04a §5.4 · SideS11): 명단의 행방은 SQH_LIST11 하나(−1 아직 · 4 인지영 낭독 · 14 남산 · 1 계엄군 · 0 주인공 보관),
	# 원본의 행방은 SQH_RECESS 하나(−1 아직 · 14 남산 · 1 비상정부 · 0 주인공 보관 · 97 기록관에 되돌림). SQE_LIST11 · SQE_RECESS = MQ-502 증거 · SQK_MARCH = 파수-3 240기를 앎(MQ-302 · S18).
	# START 발동 · LEAF LR-11 읽음 · REPORT LR-12/별첨 읽음 · PRINT 출력 매수 · GUARD 경비 파수(0 대기 · 1 깨어 막음 · 2 비킴 · 3 배관 우회 · 9 파괴) · STACK 제7 서고 번호 앎(문 열림) ·
	# ESCORT 인지영 동행(0 · 1 함께 · 2 기다림 · 3 끝) · READ 낭독 끝 · HELD_DAY 원본을 든 날 · SOL_L/SOL_D 결과 · REWARD 머리띠 · PLATE 제118석 쪽지 · VOTE 전광판 · CLAUSE 재개 조항 제3항 앎 ·
	# TOOK 원본을 상자에서 꺼냄 · WARN 반출 소문(5일째) · PASS 선우진 인수증(낮 통행) · PDAY 순찰을 만난 날 · PKIND 순찰 종류(1 구울 · 2 문서) · PSAID 순찰 화술 실패 ·
	# CASTL 명단 방송(1 넘김 · 2 송출) · CASTL_DAY · WOOQ/SUNQ 우도하 · 선우진에게 꺼낼 국회 기록이 있음(진행기) · SAGONG 골동품상 거절 들음 · COIN 분수 동전 대사 ·
	# SAWLEAF 인지영이 유인물을 봄 · MET 의사록을 만남 · TOLD 보고서는 경찰서에 · SHOWN 파수에게 명단 · ATOFFICE 서장실 안(배관 방향) · WOOL/SUNL 사본을 건넴 · KNOWS 원본 자리 앎 · DONE 닫힘 ·
	# IMET 인지영 첫 인사 · NEARHUB 환승센터 터 근처 · HIDEF 숨기 실패 · PTALK 순찰병 설득 · PCOUNT/PNEXT 하루 순찰 수 · 다음 · GAVEL 의사봉 · ISAID 광장 한 줄
	for k in "START LEAF REPORT PRINT GUARD STACK ESCORT READ HELD_DAY SOL_L SOL_D REWARD PLATE VOTE CLAUSE TOOK WARN PASS PDAY PKIND PSAID CASTL CASTL_DAY WOOQ SUNQ SAGONG COIN SAWLEAF MET TOLD SHOWN ATOFFICE WOOL SUNL KNOWS DONE IMET NEARHUB HIDEF PTALK PCOUNT PNEXT GAVEL ISAID".split(" "):
		vars.declare("SQ_S11_" + k, "int", 0)
	vars.declare("SQR_S11", "int", 0)
	for k in "START CARDS LOOK J S E JR SB EW JT ST ET SOLD SOLD_DAY KNOWN EVID YASK LAYJ LAYS LAYE DONE REWARD HINT STOLE BOXED LOG".split(" "):   # 1-11k SQ-S12 관리 요원의 유족(원고 SQ-S12.txt 머리 주석)
		vars.declare("SQ_S12_" + k, "int", 0)
	vars.declare("SQH_IDCARD", "int", 0)
	vars.declare("SQE_FAMILY", "int", 0)
	for kv in [["SQH_LIST11", -1], ["SQH_RECESS", -1], ["SQE_LIST11", 0], ["SQE_RECESS", 0], ["SQK_MARCH", 0], ["NS_COOP", 0], ["PD_R02_KH", 0]]:   # 남산 협력 표시(SD-06 NS 협력 플래그) · 거점 '국회 폐허'(1 = BJ)
		vars.declare(kv[0], "int", kv[1])
	# UQ-71 원자력 버스(1-D1, SD-05 UQ-71 · 훅 H-R02-11 · DB-01): 노심의 행방은 UQ71_CORE 하나(0 버스 · 1 제자리 봉인 · 2 주인공 소지 · 3 팔림 · 4 분대가 가져감 · 5 신길에서 터짐) ·
	# SQ 대방 분대(0 경사로에서 일함 · 1 돌아감 · 9 전멸) · HEARD 엿들음 · DAY 처음 본 날 · DUE 분대가 끌어낼 날 · SOL 해법 · REWARD · TALK 배수관과 말함 · SEEN 버스를 봄
	# SQP 끌어내기 진척(0 사슬만 · 1 버스가 기움 — 버스 그림 · 윈치 글) · N 그날 낮 분대 인원(2~4) · QUICK 큰집게를 잡아 기한이 당겨짐
	for k in "CORE SQ HEARD DAY DUE SOL REWARD TALK SEEN SQP N QUICK".split(" "):
		vars.declare("UQ71_" + k, "int", 0)
	# U02 남태령 지하(1-D2, SD-09f U02 · 훅 UG-H01 · UG-H02): 뜻은 script/act1/U02.txt 머리 주석 — LIGHT 회로 · PATH 밀통로 · HAL 할매 · SOL 매듭 ·
	# SHIFT 교대 틈 · FEE 벌금(FN 야간 · FW 수배 · FR 거부 · FS 회로 조사 · FD 우호 감면) · SIDE 선 쪽 · RADIO 막사 무전 · VENT 환기구 · RING1 막차 일지 · PHOTO 돌 사진
	for k in ("GUIDE INTRO LIGHT LIGHT_DAY ASK HAL HAL_DAY HFEE PATH TRACE USED FOUND SOL SHIFT SIDE FEE FN FW FS FR FD HAGGLED PASSED RADIO GAP_DAY "
			+ "PATROL_DAY VENT MET_EOM MET_HAL MET_AJAE BACKDOOR PHOTO PHOTO_TRY FORGE_TRY RING1 LASTFEE PATROL RULES").split(" "):
		vars.declare("U02_" + k, "int", 0)
	# UQ-04 7호 냉동 창고(1-D3, SD-05 UQ-04): 뜻은 script/act1/UQ-04.txt 머리 주석 — OPEN 7호 문 · GONE 나간 상자 · LEFT 남은 상자(보여 주기) · COLD 냉기를 굴로 ·
	# DUE 냉동기 멈출 날 · BC · SA 알린 날 · JH 함준호 · FEUD RE-045 · RATK 왕쥐 · SHELF 선반 그림(보여 주기) · DS_VALVE 배수 밸브
	for k in "KNOW OPEN OPEN_DAY LOCK DUE THAW THAW_DAY GONE LEFT COLD COLD_DAY BC BC_DAY SA SA_DAY JH JH_DAY LEAK FEUD FEUD_DAY RATK SHARD SHELF SOL REWARD LINK2 LINK3 FLED DATE SIGN PRICE BACK REFUND".split(" "):
		vars.declare("UQ04_" + k, "int", 0)
	vars.declare("DS_VALVE", "int", 0)
	# 1-D4 구로 차량기지(DG-GR): 뜻은 script/act1/GR.txt 머리 주석 — CORE 기관차 · PUSH 남은 밀기 · LV_* 레버 · A · B · C 입환 결과 · STAFF 역무원 · MUSTER 안 간 사람들
	for k in "CORE PUSH BUS CORE_DAY LV_A LV_B LV_C A B C STAFF STAFF_DAY STAFF_K KEY LOST SIGKEY WHISTLE MUSTER MUSTER_K REEFER DRIFT RATS SB SB_DAY ROOF CHART TAG PARK CHEER ESC GUIDE TIP MUSTER_DAY".split(" "):
		vars.declare("GR_" + k, "int", 0)
	# 1-D5a 여의도 금탑(DG-KT): 뜻은 script/act1/KT.txt 머리 주석 — POWER 발전기 연료 한 통 · CALL 어하은 통화 · REVOLVE 회전문 · TUNNEL 유리 터널 · QUEEN 22층 여왕(1-D5b)
	#   1-D5b 위층: DIG 4층 흙벽 · ROPE 곤돌라 줄 · GOND 곤돌라 자리 · TOP 꼭대기 불 · MEET 어하은 첫 얼굴 · SHOE 신발 · NURSE 육아방 · HEAT 불 먼저(개미가 올라옴) 등
	for k in "POWER POWER_DAY NOTE CALL RING RING2 MEM HOOK REVOLVE TUNNEL CAR QUEEN LOW CARTOLD HATCH KEY GRATE DIG ROPE GOND TOP TOP_DAY MEET VIEW SHOE NURSE EXPL HEAT OBS QUEEN_DAY CREW EXT3 EXT4 EXT5 HOSE3 HOSE4 SWAT GLASS20 GLASS31 WIN6 GEN_DAY BACK".split(" "):
		vars.declare("KT_" + k, "int", 0)
	Dungeon.load_db()                                                    # 던전 정리 변수(1-D0): DG_<접미> · _DAY · _ROLL
	for did in Dungeon.db:
		for sfx in ["", "_DAY", "_ROLL"]:
			vars.declare(str(Dungeon.db[did]["var"]) + sfx, "int", 0)
	vars.declare("PD_R02_GD", "int", 0)                                  # 판도 PD-R02-5 새벽(고척 · 개봉 — 습격 −15 · 방송 −5, SD-04a §5.3)                                  # 판도 PD-R02-4 새벽(영등포 남부 — 우리 열기 −3 · 습격 −10 · 지하로 −5, SD-04a §5.2)
	for kv in [["SQH_BATT", -1], ["LR15_READ", 0], ["PD_R01_GS", 0], ["M303_BONUS", 0], ["PK_017", 0]]:   # 전지 인도처(HO) · LR-15 · 판도 PD-R01-2 각성회 · 편지 화술 +10(첫 1회) · 퍽 눈치(퍽 창은 1-12)
		vars.declare(kv[0], "int", kv[1])
	for kv in [["CAPTURE_DAY", -1], ["CAPTURE_AT", 0], ["SB_COLLAR", 0], ["SB_CUFF", 0], ["CAPTURE_BY", 0]]:
		vars.declare(kv[0], "int", kv[1])
	for k in ["P_SURNAME", "P_GIVEN", "P_FULL", "P_REGNO", "PC_APT"]:   # PC_APT: 적성 평가 답 10개(결과지 다시 보기)
		vars.declare(k, "str", "")
	for kv in [["PC_HAIR", "HR05"], ["PC_HCOL", "H1"], ["PC_SKIN", "S3"]]:   # 외형(SD-10 §8.3). PC_SEX 1 남 · 2 여
		vars.declare(kv[0], "str", kv[1])


## 기본 자료(변수 선언·퀘스트·인물)를 읽는다. 시험은 이 함수를 건너뛰고 직접 선언할 수 있다.
func load_data(dir: String = "res://data/") -> void:
	if FileAccess.file_exists(dir + "vars.json"):
		vars.load_decls(dir + "vars.json")
	if FileAccess.file_exists(dir + "quests.json"):
		quests.load_defs(dir + "quests.json")
	if FileAccess.file_exists(dir + "npcs.json"):
		npcs = JSON.parse_string(FileAccess.get_file_as_string(dir + "npcs.json"))["npcs"]
	if FileAccess.file_exists(dir + "enemies.json"):                   # 무명 적 템플릿도 화자(1-3 추적대 첫 분대) — 이름표는 직함, 수첩에 없음
		var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "enemies.json"))
		for cid in en:
			if not npcs.has(cid):
				npcs[cid] = {"name": str(en[cid].get("name", cid)), "title": str(en[cid].get("name", cid)), "faction": ENEMY_FACTION.get(cid, ""),
					"ids": [cid], "unnamed": true}
	for kv in UNNAMED:                                                # 길 위 무명 사람(1-E 인카운터 화자, SD-22) — 이름표는 직함, 수첩에 없음
		if not npcs.has(kv[0]):
			npcs[kv[0]] = {"name": kv[1], "title": kv[1], "faction": kv[2], "ids": [kv[0]], "unnamed": true}
	book = NpcBook.new(npcs)


# ---------------------------------------------------------------- 식 언어 컨텍스트
## 생사 변수(SD-03a §4 '인물 생사' — 정본 ID). 사실은 `dead` 한 곳(SD-20 P1): 변수는 dead에서 계산하고, 변수에 1을 쓰면 dead에 적는다.
## (예전엔 진행기가 D_HDC를 따로 세우고 맵에서 쏴 죽이면 dead만 서서 두 사실이 갈렸다 · 독사를 D_DS(다니엘 서)에 적던 것 — 1-X에서 고침)
const DEAD_VARS := {"D_JMS": "C-010", "D_BIH": "C-011", "D_MKJ": "C-012", "D_HDC": "C-013", "D_MYS": "C-006", "D_SMR": "C-008",
	"D_DS": "C-005", "D_MXM": "C-007", "D_RJ": "C-014", "D_JL": "C-017", "D_BG": "C-015"}


## 대표 ID(별칭 N-…은 첫 ID로 — 백구 C-015 = N-R01-027)
func canon(id: String) -> String:
	var ids: Array = npcs.get(id, {}).get("ids", [])
	return str(ids[0]) if not ids.is_empty() else id


## 죽었나(별칭 어느 쪽으로 적혔어도)
func is_dead(id: String) -> bool:
	if dead.has(id):
		return true
	for a in npcs.get(id, {}).get("ids", []):
		if dead.has(str(a)):
			return true
	return false


## 죽었고 알려졌나: 목격 없이 죽인 시체가 아직 발견 전이면 아무도 모른다(Crimes · Deeds.bodies)
func known_dead(id: String) -> bool:
	if not is_dead(id):
		return false
	var c := canon(id)
	for b in deeds.bodies:
		if canon(str(b["id"])) == c:
			return false
	return true


## 죽음을 적는 한 곳(대표 ID · 그 해)
func kill(id: String) -> void:
	dead[canon(id)] = year()


func get_var(name: String) -> Variant:
	if DEAD_VARS.has(name):
		return 1 if is_dead(DEAD_VARS[name]) else 0
	return vars.get_v(name)


func set_var(name: String, v: Variant) -> bool:
	if DEAD_VARS.has(name):
		if int(v) != 0:
			kill(DEAD_VARS[name])
		return true
	return vars.set_v(name, v)


func call_fn(name: String, args: Array) -> Variant:
	match name:
		"karma":
			var nv := vars.add("V_KARMA", int(args[0]), -KARMA_RANGE, KARMA_RANGE)
			events.append({"kind": "karma", "delta": int(args[0]), "value": nv})
			return nv
		"aff":
			var key := _aff_key(str(args[0]))
			if key == "":
				vars._err("알 수 없는 호감도 대상: " + str(args[0]))
				return null
			var was := int(vars.get_v(key)) if vars.has(key) else 0
			if int(deeds.grudge.get(key.substr(4), 0)) >= 2:             # 영구 적대(1-X, SD-06 §3.8): −100 고정, 어떤 원천으로도 오르지 않는다
				vars.set_v(key, -AFF_RANGE)
				return -AFF_RANGE
			var nv := vars.add(key, int(args[1]), -AFF_RANGE, AFF_RANGE)
			events.append({"kind": "aff", "key": key, "delta": int(args[1]), "value": nv})
			if key == "AFF_BJ" and vars.has("V_WANTED"):
				Wanted.refresh(self)                                           # 비상정부 호감이 움직이면 수배 하한을 다시 건다(철회 · 4막 이후 하한)
				Wanted.bj_crossed(self, was, nv)                               # §6.5 등급 3·4 진입 '순간'
			return nv
		"quest":
			quests.set_stage(str(args[0]), int(args[1]))
			return quests.stage(str(args[0]))
		"stage":
			return quests.stage(str(args[0]))
		"result":
			vars.set_v(quests.key_of(str(args[0])) + "_RESULT", int(args[1]))
			return int(args[1])
		"give":
			var n := int(args[1]) if args.size() > 1 else 1
			items[str(args[0])] = int(items.get(str(args[0]), 0)) + n
			events.append({"kind": "item", "id": str(args[0]), "delta": n})
			return items[str(args[0])]
		"take":                                                         # 기본 ID("W-002")로 부르면 상태 변형(@1~@4)도 같은 물건으로 센다(1-8a) — 정확한 열쇠 → 나쁜 상태 순
			var n := int(args[1]) if args.size() > 1 else 1
			var want := n
			for k in kinds_of(str(args[0])):
				var m := mini(want, int(items.get(k, 0)))
				if m <= 0:
					continue
				want -= m
				if int(items[k]) - m <= 0:
					items.erase(k)
					wear.erase(k)
				else:
					items[k] = int(items[k]) - m
				if want <= 0:
					break
			events.append({"kind": "item", "id": str(args[0]), "delta": -n})
			return count_of(str(args[0]))
		"has":
			var n := int(args[1]) if args.size() > 1 else 1
			return 1 if count_of(str(args[0])) >= n else 0
		"caps":
			var nv := vars.add("PC_CAPS", int(args[0]), 0)
			events.append({"kind": "caps", "delta": int(args[0]), "value": nv})
			return nv
		"xp":
			var dx := int(args[0])
			if dx > 0 and int(vars.get_v("WELL_RESTED")) > 0:
				dx = roundi(dx * 1.1)                                     # 숙면(SD-11 §11.5): 경험치 +10% — 끝나는 시각은 호스트가 지운다
			var nv := vars.add("PC_XP", dx, 0)
			events.append({"kind": "xp", "delta": dx, "value": nv})
			return nv
		"wanted":                                                       # 수배도(1-3): 하한·하루 상한·등급 알림은 Wanted가
			return Wanted.add(self, int(args[0]), str(args[1]) if args.size() > 1 else "")
		"blade":                                                        # 날붙이 근접 무기(W-037~W-045)를 들었나(SD-04a §4.1 해법 D, 1-11a)
			var b := Gear.base(wielded)
			return 1 if b >= "W-037" and b <= "W-045" else 0
		"dead":                                                         # 그 인물(C-·N-·CR- ID)이 죽었나(SD-20 P3 · §10 — 다른 인물 이야기를 하는 줄은 이 조건 뒤에서만)
			return 1 if is_dead(str(args[0])) else 0
		"known_dead":                                                   # 죽었고, 그 죽음이 알려졌나(목격 · 시체 발견 — 아직 아무도 못 본 시체면 0, SD-06 §6.4 · SD-20 P7)
			return 1 if known_dead(str(args[0])) else 0
		"killer_known":                                                 # 그 정착지 · 세력("BC" · "JC_BC")이 주인공을 '우리 사람을 죽인 자'로 아나(목격 · 지목 · 자백, 1-X)
			var tk := str(args[0])
			if not tk.begins_with("JC") and vars.has("AFF_JC_" + tk):
				tk = "JC_" + tk
			return 1 if Crimes.killer_known_by(self, tk) else 0
		"confess":                                                      # 자백(1-X): 직접 죽였고 아무도 몰랐던 살인을 털어놓는다 — 지목된 살해와 같은 기록
			return 1 if Crimes.confess(self, str(args[0]), str(args[1]) if args.size() > 1 else "R01", deeds.last, str(args[2]) if args.size() > 2 else "") else 0
		"victim":                                                       # 주인공이 직접 죽인 사람인가(아무도 몰라도)
			return 1 if deeds.victims.has(canon(str(args[0]))) else 0
		"worn":                                                         # 입은 몸통 옷의 기본 ID(상태 떼고 — 낡은 볼트 점프슈트도 볼트 옷, 1-8a)
			return Gear.base(str(vars.get_v("PC_TORSO")))
		"stat":
			return stat(str(args[0]))
		"skill":
			return skill(str(args[0]))
		"year":
			return year()
	if fns.has(name):
		return (fns[name] as Callable).call(args)
	vars._err("알 수 없는 함수: %s(%s)" % [name, str(args)])
	return null


## 같은 물건의 소지 열쇠들: 기본 ID면 그 ID + 상태 변형(정확한 열쇠 먼저, 나머지는 나쁜 상태부터). 열쇠에 '@'가 있으면 그것만
func kinds_of(id: String) -> Array:
	if id.contains("@"):
		return [id]
	var out := [id]
	for c in [4, 3, 2, 1]:
		out.append("%s@%d" % [id, c])
	return out


func count_of(id: String) -> int:
	var n := 0
	for k in kinds_of(id):
		n += int(items.get(k, 0))
	return n


## 소지품에서 이 물건의 가장 좋은 상태 열쇠(없으면 "")
func best_of(id: String) -> String:
	var ks := kinds_of(id)
	ks.reverse()
	ks.push_front(ks.pop_back())                                       # 정확한 열쇠(새것) → @1 → @2 …
	for k in ks:
		if int(items.get(k, 0)) > 0 and not str(k).ends_with("@4"):
			return k
	return ""


## 지금 이야기 연도(프롤로그 시대 구분: 맵의 사람·소품을 고른다). 퀘스트 진행으로 정한다:
## MQ-P1 출생 2258 → 돌잔치(단계 20~) 2259 → MQ-P2 2268 → MQ-P3 2274 → MQ-P4 이후 2277
func year() -> int:
	if quests.stage("MQ-P4") > 0 or quests.stage("MQ-101") > 0:
		return 2277
	if quests.stage("MQ-P3") > 0:
		return 2274
	if quests.stage("MQ-P2") > 0:
		return 2268
	if quests.stage("MQ-P1") >= 20:
		return 2259
	return 2258


func _aff_key(code: String) -> String:
	for k in ["AFF_" + code, "AFF_JC_" + code]:
		if vars.has(k):
			return k
	return ""


# ---------------------------------------------------------------- 주인공 서류
func stat_code(name: String) -> String:
	if STATS.has(name):
		return name
	for c in STATS:
		if STATS[c] == name:
			return c
	return ""


## 지금 능력치: 방사능 단계가 지구력 · 민첩성 · 힘을 깎는다(SD-11 §11.2, 1-9d). 최소 1
func stat(name: String) -> int:
	var c := stat_code(name)
	if c == "":
		return 0
	var v := int(vars.get_v("PC_" + c))
	if c in ["EN", "AG", "ST"] and vars.has("PC_RADS"):
		v = maxi(1, v - Radiation.penalty(int(vars.get_v("PC_RADS")), c))
	if stat_tmp.has(c):                                               # 잠깐 보정(최루 기침 인지력 −2 등) — 저장하지 않는다
		v = maxi(1, v + int(stat_tmp[c]))
	return v


## 바탕 능력치(방사능 감소 전): 최대 HP · 방사능 저항 · 능력치 창 '기본'
func stat_base(name: String) -> int:
	var c := stat_code(name)
	return int(vars.get_v("PC_" + c)) if c != "" else 0


func skill_key(name: String) -> String:
	if SKILLS.has(name):
		return name
	for k in SKILLS:
		if SKILLS[k][0] == name:
			return k
	return ""


func tagged(key: String) -> bool:
	for i in 3:
		if vars.get_v("PC_TAG%d" % (i + 1)) == key:
			return true
	return false


## 스킬값(SD-10 §3.3): 초기값 + 태그 15 + 영구 증가분, 표시 상한 100
func skill(name: String) -> int:
	var k := skill_key(name)
	if k == "":
		return 0
	var v := Speech.base_skill(stat(SKILLS[k][1]), stat("LK")) + (15 if tagged(k) else 0) + int(vars.get_v("PC_SKP_" + k))
	return mini(v, 100)


## NPC 대상 화술 성공 확률(SD-10 §3.5.8). 인물 자료에 기본 호감·책임감이 없으면 50·50.
func speech_chance(npc_id: String, diff: String) -> float:
	var n: Dictionary = npcs.get(npc_id, {})
	var fac := 0.0
	var fk := _aff_key(str(n.get("faction", "")))
	if fk != "":
		fac = float(vars.get_v(fk))
	return Speech.chance(stat("CH"), weapon_out, float(n.get("aff", 50)), fac, float(n.get("resp", 50)),
		float(vars.get_v("V_KARMA") if vars.has("V_KARMA") else 0), skill("SPEECH"), diff)


## 아이인가(SD-11 §580 · SD-18 '아동': 원작처럼 공격 대상이 아니다 — 맞지도 죽지도 않는다). 나이 1~15 또는 아이 몸(K)
func is_child(id: String) -> bool:
	var n: Dictionary = npcs.get(id, {})
	var look := str(n.get("look", ""))
	if look.begins_with("AN"):                                        # 동물(백구 AN-CR536 · 6살)은 나이가 어려도 아이가 아니다
		return false
	var age := int(n.get("age", 0))
	return (age > 0 and age < 16) or look.begins_with("K")


func npc_name(id: String) -> String:
	return str(npcs[id]["name"]) if npcs.has(id) else id


func player_full() -> String:
	return str(vars.get_v("P_SURNAME")) + str(vars.get_v("P_GIVEN"))


# ---------------------------------------------------------------- 저장
func dump() -> Dictionary:
	var it := {}
	var ks := items.keys()
	ks.sort()
	for k in ks:
		it[k] = items[k]
	var fc := failed_checks.keys()
	fc.sort()
	return {"vars": vars.dump(), "items": it, "failed": fc, "seed": check_seed}


func restore(d: Dictionary) -> void:
	vars.restore(d.get("vars", {}))
	items = {}
	for k in d.get("items", {}):
		items[k] = int(d["items"][k])
	failed_checks = {}
	for k in d.get("failed", []):
		failed_checks[k] = true
	check_seed = int(d.get("seed", 0))
