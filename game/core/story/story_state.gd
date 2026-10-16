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
const UNNAMED := [["N-TRADER", "떠돌이 고물상", ""], ["N-REFUGEE", "피난민", ""], ["N-DOWNED", "쓰러진 민병", "JC_BC"],
	["N-HS-E1", "수송대 호위", "HS"], ["N-HS-E2", "수송대 호위", "HS"], ["CR-091", "짐소", ""],   # 1-8d 고개길 수송대
	["N-SA-G1", "승강장 경비", "JC_SA"], ["N-SA-G2", "승강장 경비", "JC_SA"], ["N-SA-G3", "승강장 경비", "JC_SA"], ["N-SA-R1", "환승촌 주민", "JC_SA"],   # 1-8f 사당 환승촌
	["N-SA-R2", "환승촌 주민", "JC_SA"], ["N-SA-R3", "환승촌 주민", "JC_SA"], ["N-SA-R4", "버섯 일꾼", "JC_SA"],
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
	for k in ["RE036_MET", "RE036_NEWS", "RE042_N"]:
		vars.declare(k, "int", 0)
	vars.declare("BC_DOUBT_DAY", "int", 0)                    # 정보 전파(1-10c): 걸어 들어감 소문이 봉천에 닿은 날 + 1 — 그날까지 봉천 사람들이 수군거린다(SD-20 N8)
	# 거처(1-8b, SD-15 §7): HOME_BC 봉천 옥탑방(0 없음 · 1 내 방 · 2 압류) · HOME_BC_OK 조건이 찬 날(그다음 날부터 조만석이 열쇠를 준다) ·
	# WELL_RESTED 숙면이 끝나는 절대 분(0 = 없음, SD-11 §11.5 경험치 +10% 12시간) · HOME_BC_NOTE 문 앞 알림(§7.7: 1 '출입 자제' 쪽지 · 2 읽음 · 3 압류 딱지 · 4 읽음 · 5 재개방) ·
	# BAEKGU_NAP 오늘 백구가 옥탑방 문 앞에서 자는 날(하루 판정마다 굴림)
	for k in ["HOME_BC", "HOME_BC_OK", "WELL_RESTED", "HOME_BC_NOTE", "BAEKGU_NAP", "INFO_RUMOR_R01", "INFO_RUMOR_R02", "CARAVAN_V54", "MEDIC_AT", "TR_YEON_MET", "TR_SO_MET", "TR_EOM_MET"]:   # 정보상 장소 소문 산 수(1-8d)
		vars.declare(k, "int", 0)
	# 사당 환승촌(1-8f): 인물 첫 만남 · SA_MAKCHA_HEARD 서쪽 터널 '막차 손님' 들음(SQ-S05 '이미 앎') · SA_MAT_UNTIL 승강장 매트 빌린 끝 절대 분 ·
	# SD_MAP_UG 노선도 봄 · SD_BOARD_SEEN 운행 칠판 봄 · SD_LR05 · SD_LR09 기록물 · U02_OPEN 4호선 남쪽 터널(지하 구간 단계에서 1)
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
			"SQ_S01_BETRAY", "SQ_S01_CLEAR_DAY", "SQ_S01_KILLS", "SQ_S01_KILL_DAY", "SQ_S01_EOM", "SQ_S01_BC", "SQ_S01_NAP", "PK_045"]:
		vars.declare(k, "int", 0)
	vars.declare("SQH_TAG", "int", -1)
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
func get_var(name: String) -> Variant:
	return vars.get_v(name)


func set_var(name: String, v: Variant) -> bool:
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
