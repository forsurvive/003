"""원고 변환기 v1 (SD-19 §9.3 단계 3·5): 대사 원고(script/**/*.txt) → 자동 검사 → 대화 그래프 JSON(game/data/dialogue/).

원고 형식(한 줄 = 한 명령. 빈 줄·`#`으로 시작하는 줄은 무시)
  @scene MQ-P1_S01  의무실  (L-R01-01)       장면 시작(ID · 제목 · 장소)
  @npc   C-025                                화술 판정 대상(없으면 그 장면 첫 화자). `@npc -` = 진행기·밟는 칸 장면(인물에 묶지 않는다)
  @cond  MQP1_STAGE == 10                     장면이 열리는 조건
  C-025 [미소] 건강해요. 울음소리 좋네.       대사: 화자 ID [표정] 문장   (화자 SYS = 해설, 표정 생략 = 기본)
  * 라벨                                      라벨(장면 첫 줄은 START)
  -> 라벨                                     이동(END = 장면 끝)
  ? 조건식 -> 라벨                            조건이 참이면 이동
  ! 효과식                                    효과(V_DOL = 3; karma(50); quest("MQ-P1", 30))
  @cmd 이름 인자...                            연출 명령(이벤트 실행기)
  > [태그]* 선택 문장 -> 성공 [| 실패] [?? 보이는 조건] [!! 효과]   선택지(연속한 > 줄이 한 묶음)
태그: [화술 아주 쉬움|쉬움|보통|어려움|아주 어려움] · [능력치 n] · [스킬 n] · [캡 n] · [물건: ID n] · [증거: ID] · [카르마] ·
      [관리자 인증] · [볼트 S-07] · [거짓말]·[위협](연출 표지). 한 선택지에 최대 2개(SD-12 §6.3).
문장 토큰(SD-18 N7): {변수|조사} · {변수} · {N:인물ID|조사} · {I:아이템ID|조사} · {L:장소ID|조사} → \\V[..]·\\N[..]·\\I[..]·\\L[..] + \\J[조사]

자동 검사(불합격이면 종료 코드 1): 토큰 문법·변수 선언·조사 짝, 화자 ID(SD-07b), 표정 키, 라벨, 식 구문·변수·함수, 장면 열림 조건(@cond) 필수,
창별 글자 수(SD-12 §14.5: 대사 1쪽 160자·2쪽 넘으면 오류, 선택지 80자), 금칙 명칭(SD-18 §2.3·§11.7, 옛 이름),
진영 결정 질문 문형(바이블 §5.8), 연출 명령 이름."""
import os, re, sys, json, glob, shlex

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import story_expr as SE
from extract import tables, DOCS

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "script")
OUT = os.path.join(ROOT, "game", "data", "dialogue")
DATA = os.path.join(ROOT, "game", "data")

EMOS = ["기본", "미소", "놀람", "분노", "슬픔", "피곤", "말함", "아픔", "목소리"]   # 목소리: 얼굴 없이 들리는 말(인터폰 · 무전 — 초상 자리에 스피커, 1-D5a)
DIFFS = ["아주 쉬움", "쉬움", "보통", "어려움", "아주 어려움"]
STATS = ["힘", "인지력", "지구력", "카리스마", "지능", "민첩성", "행운"]
SKILLS = ["물물교환", "중화기", "에너지 무기", "폭발물", "자물쇠 따기", "의학", "근접 무기", "수리", "과학", "소형 화기", "은신", "화술",
          "비무장"]
FLAVORS = ["거짓말", "위협"]
PARTICLES = ["은", "는", "이", "가", "을", "를", "과", "와", "으로", "로", "이나", "나", "이랑", "랑", "아", "야", "이다", "다", "이에요",
             "예요", "이었", "였", "이라", "라", "이든", "든"]
FNS = {"karma", "aff", "quest", "stage", "result", "give", "take", "has", "caps", "xp", "wanted", "stat", "skill", "year", "worn", "blade", "dead", "known_dead", "met", "killer_known", "confess", "victim"}
CMDS = {"wait", "fade_in", "fade_out", "balloon", "move", "face", "shake", "year_card", "title_card", "sfx", "bgm", "cam", "show",
        "hide", "pose", "doc", "flash", "lamp", "unlit", "note", "reveal",
        "pipboy", "equip", "hurt", "buddy", "range", "hint", "hud",          # 0-7: 핍-보이·무기·연출 피해·일시 동행·사격장 단계·안내 띠
        "refresh",                                                           # 0-8: 맵 인물을 지금 조건대로 다시 세운다
        "gate", "go", "pc", "escape", "unlock", "anim",                     # 0-9: 방폭문 · 기다리지 않는 이동 · 주인공 자리 · 탈출 진행기 · 문 열기
        "mq", "trade", "yd", "fix",                                                   # 0-10: 1막 진행기 사건 · 거래 창(상인 V번호)
        "meet", "memo", "obit",                                              # 1-2: 인물 수첩 등록 · 한 줄 메모 · 소식으로 안 죽음
        "re", "cage", "capture",                                             # 1-3: 인카운터 첫 분대 대화의 결말 · 우리 문 열기 · 생포(사흘 버팀)
        "jm", "yd", "sb", "vb", "home", "info", "doctor", "rent", "stash", "s01", "s02", "s03", "s04", "s05", "s06", "s08", "s09", "s10", "s11", "uq71", "u02", "uq04", "gr", "kt", "ga", "ks", "hp", "yt", "u04", "s12", "s13", "chain", "jc01", "gs01", "gs02", "jh01", "jh02", "jh03", "sb01", "sb02", "uqr", "uqr2"}                                                                # 1-4: 1막 경로 진행기(지하시장·단서) 사건                                             # 1-3: 인카운터 첫 분대 대화의 결말 · 우리 문 열기 · 생포(사흘 버팀)
ENGINE_VARS = {"PC_ST", "PC_PE", "PC_EN", "PC_CH", "PC_IN", "PC_AG", "PC_LK", "PC_TAG1", "PC_TAG2", "PC_TAG3", "PC_CAPS", "PC_XP",
               "PC_SEX", "PC_APT_PROXY",
               "MQP4_DUCT", "MQP4_FOLLOW", "MQP4_KEY", "MQP4_ARMORY", "MQP4_TALK", "MQP4_BJ_KO", "MQP4_SEC_KO", "MQP4_CAUGHT", "MQP4_DECOY",
               "S7_THEFT_SEEN", "S7_ASSAULT", "S7_KILLS",
               "MQ101_DOG", "MQ101_TRADE", "MQ101_WATER", "MQ101_RAD", "MQ101_NIGHT", "MQ101_DEAD", "MQ101_TANK", "MQ101_ROOF", "MQ101_LOAN",
               "MQ101_BOARD", "MQ101_FIGHT", "PC_RADS", "PD_BC", "PD_R01", "GAME_DAY", "PC_TORSO", "PC_EYES", "PC_SMELL",
               "WANTED_DAY", "WANTED_KILL_SUM", "WANTED_AUTH_SUM", "WANTED_LOOK",                            # 1-3 수배도
               "CAPTURE_DAY", "CAPTURE_AT", "SB_COLLAR", "SB_CUFF", "CAPTURE_BY", "STAT_HACKED", "STAT_LOCKS",
               "MQ104_FIRE", "MQ104_DESK", "MQ104_IDS", "MQ104_SEEN", "MQ104_ROLL", "MQ104_LOG", "MQ104_FILES", "MQ104_RIFLE",
               "MQ104_AUTH", "MQ104_VENT", "MQ104_LAST", "MQ104_SEARCH", "MQ104_DOYUN", "MQ104_GUARDS", "MQ104_DAY",
               "PL_LETTER", "PL_VIEW", "PL_TECH", "PN_SON", "PN_Q10", "PN_NURSE", "PN_HEAL_DAY", "PN_SIM", "PN_GIL", "PN_LEDGER", "PN_NAM", "PN_NAM_TIP",
               "MQ102_C1", "MQ102_C2", "MQ102_C3", "MQ102_ROBOT", "MQ103_GATE", "MQ103_JOB", "MQ103_HIRE", "MQ103_SNEAK",
               "MQ103_DOOR", "MQ103_CONF", "MQ103_LOG", "MQ103_AMBUSH", "MQ103_NEST", "MQ103_FOUNT", "JM_REG", "JM_GU_MET",
               "GAME_HOUR", "GAME_WDAY", "SB_RAID", "SB_PASS", "SB_DOGS", "SB_SAFE", "SB_KEY", "SB_FREED", "SB_READ", "SB_DEAL",
               "SB_BURNT", "SB_DEBT", "SB_BJ", "SB_TALK", "SB_BOUGHT", "SB_DEPO", "SB_127", "GB_PASS",
               "MQ106_CUSTODY", "MQ106_TALKED", "MQ106_SEIZED", "MQ106_AT", "MQ106_QLINE", "MQ106_QWHY", "MQ106_QGRID", "MQ106_QDEAD", "MQ106_QSIGN", "NAMGUNG_MET", "WANTED_PRE",
               "PD_R01_BJ", "WANTED_HOLD", "RE036_MET", "RE036_NEWS", "RE042_N", "VG_TALK", "VG_NEWS", "UQ125_WHO", "UQ125_HERE", "UQ125_KID", "UQ125_GUARD", "UQ125_FENCE", "UQ125_R", "HOME_BC", "HOME_BC_OK", "WELL_RESTED", "HOME_BC_NOTE", "BAEKGU_NAP", "INFO_RUMOR_R01", "INFO_RUMOR_R02", "CARAVAN_V54", "MEDIC_AT", "TR_YEON_MET", "TR_SO_MET", "TR_EOM_MET",
               "SD_MET_HUH", "SD_MET_PYO", "SD_MET_WI", "SD_MET_SEONG", "SD_MET_BAN", "SD_MET_TAK", "SA_MAKCHA_HEARD", "SA_MAT_UNTIL", "SD_MAP_UG", "SD_BOARD_SEEN", "SD_LR05", "SD_LR09", "U02_OPEN",
               "SG_MET_HWANG", "SG_MET_KWON", "SG_REFUSED", "SG_ISSUED", "GS_MET_RJ", "GS_MET_HAN", "GS_MET_EUNSOL", "GS_MET_MA", "GS_MET_HA", "GS_CARD_SEEN", "GS_LR50", "BC_DOUBT_DAY",
               "SQ_S01_SOL", "SQ_S01_LEFT", "SQ_S01_LEFT_DAY", "SQ_S01_DROP", "SQ_S01_DROP_AT", "SQ_S01_TAG_DAY", "SQ_S01_DOG", "SQ_S01_FEED", "SQ_S01_COLL", "SQ_S01_BAIT",
               "SQ_S01_BETRAY", "SQ_S01_CLEAR_DAY", "SQ_S01_KILLS", "SQ_S01_KILL_DAY", "SQ_S01_EOM", "SQ_S01_BC", "SQ_S01_NAP", "SQ_S01_BOWL", "PK_045", "SQH_TAG"} | {"SQ_S02_" + k for k in (
               "ARM POSTED DAY0 LEVEL OPEN PAID SOL B BJ BJ_AT CAMP CKILLS TDEAD DDEAD HOT NS_HOT GUARD MAP SIREN NKILLS HAND KNOW IN PIPEMAP J1 J2 AT "
               "TRAP_AT TRAP_DONE FIGHT NH_DEAD NH_KILLED EXILE_DAY STOP_DAY NIGHT_DAY HEARD REWARD DONE_DAY RAID_UNTIL SOL_E DRY_HINT SHADOW").split()} | {"JC_PROB_BC"} \
    | {"SQ_S03_" + k for k in "ARM POSTED WALL P1 P2 P3 SPRAY GATE NAME TAGSEEN TAG CALLS VAULT SOL CLEAN DRY_DAY FILTER FILTER_DAY FILTER_N SMELL RACC_UNTIL RAT RAT2 KING KING_HP ERAT IN VISITS REWARD DRINKS SAID PIPE".split()} | {"SQR_S03"} | {"SQ_S04_" + k for k in "ARM WAKE_AT WAKE HELD DEADLINE OUT SLEEP KILLED TKILLED HOT LOITER D D_AT TEST BATT F LETTER AWAY BELL RED HELP FENCE CHASE FIGHT UP GUARD_BACK VILLAGE_AT B PD_LOCK TICKET".split()} | {"SQ_S05_" + k for k in "ARM GATE IN BSEEN ROBOT PASS TIP BCAST BCAST_AT MAD SOFT SOL LEFT WOKE DOOR JU JU_AT REPORT FENCE LINE PYO RAT SLEEPER MASK HOT REWARD AWAY DAY REMAIN EMPTY ENT WIND SEEN".split()} | {"SQ_S06_" + k for k in "ARM JIN MET FED CLOTH PAPERS ROUTE CHECK CARAVAN BOAT NOTE PERSUADE TAG DECOY SOL TOLD LEADER DISC PHASE SQUADS SOLO_DAY SOLO_P JAIL_DAY REWARD DAY HOT FLYER FOUND_AT HID SEEN_SG GATE_AT CARGO_AT FOOD SALUTE KWON BFIGHT SAID NEAR KIND HOW UNI".split()} | {"SQE_DESERTER"} | {"SQ_S08_" + k for k in "SAW LEDGER DEAD DESK MATCH NOTEBOOK TOLD_A TOLD_B TOOL ADDR GRADE SOL TICKET WAIT SHUT PROXY STRAIN REWARD FIX_DAY FOUND_DAY DAY CARRY GHOULS SEEN_A SEEN_B CARD LATE".split()} | {"SQ_S09_" + k for k in "START DUE_M DUE_D WIFE TOOK DEBT SOL1 SOL2 NOTICE REQ ORDER LIST LISTGIVEN WALL PLACE UNCOL DOOR LEARN CRACK GATE OUT HAGGLE REWARD CLOSED DAY CHECK SPENT88 SAID88 WAITED".split()} | {"SQR_S09", "SQS_S09", "PD_R02_SB", "PD_R02_BJ"} | {"SQ_S10_" + k for k in "START AUCTION OPEN HOST SEO KIRA PADDLE PRICE LEAD WATCH BUDGET TOLD CARVE KIN THREAT SWAP LEDGER CAST CAST_DAY RAID SOL PLACE REFUSED REWARD OLD FORE GAVE TAK CODE STOP DONE SEEN LATE PEN GLANCE SAID JUMP AM AD NM ND KSAY CAPV SEOIN BOOTH CAT".split()} | {"SQR_S10", "SQS_S10", "PD_R02_GD"} | {"SQ_S11_" + k for k in "START LEAF REPORT PRINT GUARD STACK ESCORT READ HELD_DAY SOL_L SOL_D REWARD PLATE VOTE CLAUSE TOOK WARN PASS PDAY PKIND PSAID CASTL CASTL_DAY WOOQ SUNQ SAGONG COIN SAWLEAF MET TOLD SHOWN ATOFFICE WOOL SUNL KNOWS DONE IMET NEARHUB HIDEF PTALK PCOUNT PNEXT GAVEL ISAID".split()} | {"SQ_S12_" + k for k in "START CARDS LOOK J S E JR SB EW JT ST ET SOLD SOLD_DAY KNOWN EVID YASK LAYJ LAYS LAYE DONE REWARD HINT STOLE BOXED LOG LAYIJ LAYIS LAYIE DAYK HINTD".split()} | {"SQH_IDCARD", "SQE_FAMILY"} | {"SQ_S13_" + k for k in "START MET2 SAFE LURE BOARD FAILS PLEDGE BOOTH CAST OFF PILE LOOT RULE C1 C2 C3 VOTING PCV WIN TURN FRAUD KNOWN FRAUD_DAY CUTS PROMISE DONE OPEN LIE ROLL INVALID HERE N1 N2 N3 NB CARD AUTH NOM RO RT RA RC RE".split()} | {"SQ_S13_%s_%s" % (a, b) for a in "V T BL ASK EASY TWO CUT HEARD SAID SUSP".split() for b in "BKETWIP"} | {"SQR_S11", "SQH_LIST11", "SQH_RECESS", "SQE_LIST11", "SQE_RECESS", "SQK_MARCH", "NS_COOP", "PD_R02_KH"} | {"FQ_JC01_" + k for k in "ARM CUT POSTED SPOUT DOG FORK1 FORK2 SHELTER KNOW FLOW NEST ROSTER LEAK CRACK REWARD DONE SAID BETRAY CAP BASE SEEN PERC KING TALK GIFT".split()} | {"FQ_GS01_" + k for k in "FLYER ROSTER R1 R2 R3 R4 R5 R6 CARDS TAG FUSE FUSE_DAY DIM POWER WAKE WAKE_DAY CLUMSY PAPER DONE SEEN WARN HURT".split()} \
    | {"FQ_JH01_" + k for k in "OPEN HA HB HC WA WB WC TA TB TC MOTOR LEAK KING KOUT NEST SHOP_M SHOP_S MINSU DONE CLEAR WARN CRUSH SF SI REOPEN LEAK_N KAWAY BUY TIPS".split()} | {"FQ_JH02_" + k for k in "SEEN SHOP ASK KNOW MET TAK PAY SOL LIE_DAY RUMOR KNOWN COLD_DAY COAT DONE YARD ARRIVE_DAY TUNNEL NEAR MEET".split()} | {"FQ_SB01_" + k for k in "SEED X1 X2 X3 X4 X5 X6 X7 X8 X9 PD1 PD2 PD3 PD4 PD5 PD6 PD7 PD8 PD9 STAMP DRAWER AWAY BLANK RES TOLD WHO BACK TYPED LURE LURE_DAY SUS EXTRA DUE DUE_M DUE_D THX1 THX2 THX3 THX4 THX5 OWE WHERE".split()} | {"FQ_SB02_" + k for k in "DAY LEG TAESU SEEN PATROL TOLL N LATE RES LEAD TOLD REMOTE SCOUT DETOUR REST SNEAK TRIED FREE TWHERE".split()} | {"FQ_JH03_" + k for k in "PARK BOX CLOCK LAST OUT END CHECK ID REC WAIT SOL SHORT BAND HURT NEAR ROOM ALONE KNOWN TOLD SKY BACK OFFER DONE NIGHT SPOT RIVER RESCUED GOSSIP BARK FLED".split()} | {"GT_COT_UNTIL"} \
    | {"FQ_GS02_" + k for k in "OFFER DOOR SAT CALL BANNER CAL CODE SAFE SCORED M135 BUNDLE NAME TRUTH HEAD DONE EARLY TUTOR SEEN".split()} \
    | {"GS_OPEN", "GS_TRUTH", "GS_ROBOT", "GS02_GRADER"} | {"SQH_BATT", "LR15_READ", "PD_R01_GS", "M303_BONUS", "PK_017"}   # 1-11c SQ-S04   # 1-11b SQ-S02   # 1-11a SQ-S01                                                        # 1-6 MQ-105             # 1-3 생포 · 1-4 해킹 통계
# UQ-71 원자력 버스(1-D1, SD-05 UQ-71 · 훅 H-R02-11 · DB-01): 노심의 행방은 UQ71_CORE 하나(0 버스 · 1 제자리 봉인 · 2 주인공 소지 · 3 팔림 · 4 분대가 가져감 · 5 신길에서 터짐)
ENGINE_VARS |= {"UQ71_" + k for k in "CORE SQ HEARD DAY DUE SOL REWARD TALK SEEN SQP N QUICK SQ_DAY".split()}
# U02 남태령 지하(1-D2, SD-09f U02 · L-UG-05 · 훅 UG-H01 · UG-H02 · 1-D 계획 §8): 사실 한 곳 — 원고 script/act1/U02.txt 머리 주석
ENGINE_VARS |= {"U02_" + k for k in ("GUIDE INTRO LIGHT LIGHT_DAY ASK HAL HAL_DAY HFEE PATH TRACE USED FOUND SOL SHIFT SIDE FEE FN FW FS FR FD "
                                     "HAGGLED PASSED RADIO GAP_DAY PATROL_DAY VENT MET_EOM MET_HAL MET_AJAE BACKDOOR PHOTO PHOTO_TRY FORGE_TRY RING1 LASTFEE PATROL RULES").split()}
# UQ-04 7호 냉동 창고(1-D3, SD-05 UQ-04 · 1-D 계획 §9 · §9.6): 사실 한 곳 — 원고 script/act1/UQ-04.txt 머리 주석 · DS_VALVE 가공장 배수 밸브
ENGINE_VARS |= {"UQ04_" + k for k in "KNOW OPEN OPEN_DAY LOCK DUE THAW THAW_DAY GONE LEFT COLD COLD_DAY BC BC_DAY SA SA_DAY JH JH_DAY LEAK FEUD FEUD_DAY RATK SHARD SHELF SOL REWARD LINK2 LINK3 FLED DATE SIGN PRICE BACK REFUND".split()} | {"DS_VALVE"}
# R01 비표시 퀘스트 넷(1-12g, SD-05 §3.23~§3.26 · 진행기 UqR01): 뜻은 script/act1/UQ-01 · 02 · 03 · 05.txt 머리 주석
ENGINE_VARS |= {"UQ01_" + k for k in "TALKS SOL CODE RELAY RELAYED LR13 FAILED HINT THEFT_DAY WITNESS SEEN SEEN_SAID BAN_DAY GUEST SERVED TIN_SAID TIN_BC".split()} | {"V24_" + k for k in "HOSTILE WEEK N1 N2 N3 N4 TICKETS SEEN".split()} \
    | {"UQ02_" + k for k in "HEARD HOW END END_DAY BARK_UNTIL SEE_OFF_UNTIL DOG_OUT LEG SPOT ROUTE PAW_DAY CARRY SAW TOLD_EOM WITNESS FOLLOW GONE_DAY NAMED SOLNA_TOLD PUP_SPOT NAME".split()} | {"UQ03_" + k for k in "RES DAY GOT_DAY PASS EOM EOM_DAY MOM_MET DELIVER_DAY BACK_READ COLD RE104 LATE PHOTO_GIVEN REPORT_DAY TOLD_MOM MOMSAID SOUP CANS KNOWGONE".split()} \
    | {"UQ05_" + k for k in "COW PACK LOST_DAY CAUSE SPOT KILL_SEEN REFUSE_DAY DISC NEWCOW_DAY HEARD LEAD DOGS PEND TOLD SAW REWARD SPILL ABSENT CX CY PACK_DAY AT RES MEAT GONE_SAID".split()} | {"RE104_N"}
# R02 비표시 퀘스트(1-12h, SD-05 §3.4 · 진행기 UqR02): 뜻은 script/act1/UQ-07 · 10.txt 머리 주석
ENGINE_VARS |= {"UQ07_" + k for k in "VISIT HEARD RES DISC TOY KDAY ME KID_SEEN STOLE MA_NO MA_SAID KSAID NOTE SELF LOST LOST_DAY LOST_SAID TOLD".split()} | {"UQ10_" + k for k in "HEARD CHECKED LEDGER PAGE HIDE_UNTIL NOTICED NSAW NSEEN NROLL PLATE PLATE_DAY PSAID RES PUB_DAY XP EXTORT BOSS RAID_DAY RAID PAY_UNTIL MISS MSAID ROB_DAY FREE REFUND DUE BOXT BOXSAID EARLY".split()} | {"UQ08_" + k for k in "MET MET_DAY TICKET LENS LOUD LSAID MA_SAID RES DAY XP SAFE SAFE_AT HEAT INSPECT CHECK_N REVERT ISAID WIRE WIRE_DAY SNAP_DAY BOOM BOOM_DAY BSAID VISE WIRE_AT WIRE_PEND PSAID MA_BOOM GSAID MA_SOLD TAGSAID".split()} | {"UQ09_" + k for k in "BOUGHT MET HATCH CLEAN PEND E1 E2 E3 MOM MOM_DAY FLOOD CODE PIPE READY RES REWARD REDIRTY REDIRTY_DAY RSAID LIE LIE_DAY LSAID SMOKE SMSAID KEY CREW GRATE REGROW EGG_SOLD BSAID EGG_DAY EGG_ENDSAID GOPEN GIFT GSEEN".split()} | {"RQ22_OPEN"} | {"UQ65_" + k for k in "READ BOOK XP BONUS TO RJ_SAID LESSON LESSON_DAY TEN REBEL STOLE WALL WALL_DAY LTODAY".split()} | {"UQ64_" + k for k in "TAGS BC SA T415 DONE_DAY POST XP GSAID D412 D413 D414 D416 MEM NEWS HINT T415_DAY D414_DAY LOST".split()} | {"UQ70_" + k for k in "SEEN DUE MET JA RES XP GUARD GSEEN SEAL BOOK GU_DAY SUHO SUHO_DAY FREE_DAY STALL_GONE PLEDGE PLEDGE_DAY HIDE_MET SNEAK THREAT PAID TOLD BSAID PD JA_DAY KIOSK_SAID GDAY WSAID FAIL FLED PROMISE CAGE_SEEN CHEON_TOLD RES_DAY".split()}
ENGINE_VARS |= {"UQ66_" + k for k in "BATT FRIDGE CELL DUE HEARD PUSH WARD NURSE OPEN DG NOTICE SELF XP PULLED SAID TAG GSCELL FORMS DG_SAID HAN_SAID PULL_DAY NURSE_SAID CSAID BOTH HOW CAUGHT".split()}   # 1-12i UQ-66 전지 하나, 냉장고 둘 — 뜻은 script/act1/UQ-66.txt 머리
ENGINE_VARS |= {"GR_" + k for k in "CORE PUSH BUS CORE_DAY LV_A LV_B LV_C A B C STAFF STAFF_DAY STAFF_K KEY LOST SIGKEY WHISTLE MUSTER MUSTER_K REEFER DRIFT RATS SB SB_DAY ROOF CHART TAG PARK CHEER ESC GUIDE TIP MUSTER_DAY".split()}   # 1-D4 구로 차량기지
ENGINE_VARS |= {"GA_" + k for k in "SEEN BOX BOX_DAY BOX_DONE CRATE_DAY FEUD DECOY DECOY_DAY COUNTED TOLD BOSS PICK PAID".split()} | {"PD_R01_6", "PC_HEAD"}   # 1-D6 가산 아울렛
ENGINE_VARS |= {"UQ69_" + k for k in "PAPER DIE DEST DEST_DAY HEARD MET T1 T2 T3 ASKED HALF DONE_DAY REWARD TOLD".split()} \
    | {"KS_" + k for k in "LINE ALARM WARN ESTOP CARD CARD_N WORK WORK_N WORK_DAY AWARD STAMP CRANE TOLD SEEN".split()} \
    | {"MR_" + k for k in "LOCKER LOCKER_DAY BOARD BOARD_WK FEET".split()}   # 1-D7 지식산업센터 · 문래(원고 script/act1/KS.txt 머리 주석)
ENGINE_VARS |= {"HP_" + k for k in "DAY0 LOST BLUR BLUR_DAY WAY TRUST CUT OVR OVR_END NIGHT GEN MASK VISIT VISIT_DAY PUSH_DAY BED ASK1 ASK2 ASK3 OJ MOVE_DAY SKIP MORGUE PHASE SAT LETTER MET TOLD DONE_DAY VON SEEN VMASK LTOLD".split()} \
    | {"RQ47_" + k for k in "N WK LAST".split()} | {"DG_STOP"}   # 1-D8 여의도 대학병원 · UQ-126 · RQ-47(원고 script/act1/HP.txt 머리 주석)
ENGINE_VARS |= {"YT_" + k for k in "FORGE FORGE_T TEMP LOCK UNK DEAD_DM ESCORT POWER MOUND SEEN GATE1 CLERK_SEEN ROBOT_OK ELEV INC INC_DAY R DOZE DMTAKE HBTAKE OJTAKE TAPE SG KBN UPC UP NOCARD CUP CUPSEEN TRAP NO HK2 HK3 SIDE CTAPE CDONE BUMP_DAY".split()} \
    | {"UQ06_" + k for k in "RESULT DAY ASKED MET GONE BACK TOLD HEARD RADIO".split()} \
    | {"U04_" + k for k in "CART_MAP CART_X CART_LOAD CLOTH JOB JOB_DMG RUN RUN_DAY KNOW ENG WOO RUSH HATCH LIST LIST_DAY GHOUL SK QK SCATTER CLEAR CARR_DAY YIELD TAP SEEN DIG HEARD RIDE CART_NEAR JOB_DAY BACK WEAR RAM GNO TAPJH LOUD CDIR".split()}   # 1-D10 U04 여의도 지하(진행기 U04 · 원고 U04.txt 머리 주석)   # 1-D9 유리탑 3동 · 증권가 객장 · UQ-06(원고 script/act1/YT.txt 머리 주석)
ENGINE_VARS |= {"KT_" + k for k in "POWER POWER_DAY NOTE CALL RING RING2 MEM HOOK REVOLVE TUNNEL CAR QUEEN LOW CARTOLD HATCH KEY GRATE DIG ROPE GOND TOP TOP_DAY MEET VIEW SHOE NURSE EXPL HEAT OBS QUEEN_DAY CREW EXT3 EXT4 EXT5 HOSE3 HOSE4 SWAT GLASS20 GLASS31 WIN6 GEN_DAY BACK".split()}   # 1-D5a·1-D5b 여의도 금탑
# 던전 정리 변수(1-D0, script/world/dungeons.txt): DG_<접미> 0 손 안 댐 · 1 정리 · 2 다시 들어섬 / _DAY 정리 · 재입주 날 / _ROLL 재입주를 굴린 날
ENGINE_VARS |= {f"DG_{m}{s}" for m in re.findall(r"^@\s+([A-Z0-9]+)\s", open(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "script", "world", "dungeons.txt"), encoding="utf-8").read(), re.M)
                for s in ("", "_DAY", "_ROLL")}
UNNAMED = {"N-TRADER": "떠돌이 고물상", "N-VG-S1": "고물상", "N-VG-H1": "약초꾼", "N-VG-P1": "부품 장수", "N-VG-C1": "옷 장수",
           "N-VG-F1": "국밥 장수", "N-VG-D1": "떠돌이 장사꾼", "N-UQ-K1": "아이", "N-UQ-C1": "털이꾼", "N-GA-B1": "패거리 두목", "N-GA-S1": "인솔조", "N-GA-S2": "인솔조", "N-MR-W1": "문래 철공", "N-MR-W2": "문래 철공", "N-HP-F1": "원무과 직원", "N-HP-F2": "조리원", "N-HP-F3": "야간 경비", "N-HP-F4": "방사선사", "N-HP-F5": "간호조무사", "N-HP-F6": "안과 외래 간호사", "N-HP-F7": "안과 레지던트", "N-JM-B1": "배수구 어미", "N-HP-L1": "탁정오", "N-HP-L2": "길순례", "N-HP-L3": "오재민", "N-HP-P1": "변미숙", "N-HP-P2": "남궁호", "N-HP-P3": "기도윤", "N-HP-P4": "차미영", "N-YTB-1": "남기범", "N-YTB-2": "김밥집 주인",                    # 1-L 일반 장사꾼
           "N-REFUGEE": "피난민", "N-DOWNED": "쓰러진 민병", "N-HS-E1": "수송대 호위", "N-HS-E2": "수송대 호위",
           "CR-091": "짐소", "N-UQ5-COW": "누렁이",                                                     # 1-8d 고개길 수송대
           "N-SA-G1": "승강장 경비", "N-SA-G2": "승강장 경비", "N-SA-G3": "승강장 경비", "N-SA-R1": "환승촌 주민", "N-SA-R2": "환승촌 주민",   # 1-8f 사당 환승촌
           "N-SA-R3": "환승촌 주민", "N-SA-R4": "버섯 일꾼", "N-SA-K1": "환승촌 아이",
           "N-YT-1": "패거리 수금원", "N-YT-2": "패거리 척후", "N-BC-1": "봉천 감시조", "N-BC-2": "봉천 감시조", "N-BC-3": "봉천 감시조", "N-JC-W1": "7동 물당번", "N-JC-W2": "7동 물당번",   # 1-11b SQ-S02 · 1-12a FQ-JC-01
           "N-PS-1": "파수-3", "N-PS-2": "경비 파수-3", "N-BJ-S1": "수색조 분대장", "N-BJ-S2": "수색조 계엄병", "N-BJ-P1": "순찰 분대장", "N-BJ-P2": "순찰 계엄병",                                                   # 1-11c SQ-S04
           "N-DB-1": "대방 분대원", "N-DB-2": "대방 분대원",                      # 1-D1 UQ-71 대방 지하차도
           "N-DS-B1": "봉천 감시조", "N-DS-B2": "봉천 감시조", "N-DS-S1": "승강장 경비", "N-DS-S2": "승강장 경비",   # 1-D3 UQ-04 독산 7호 앞
           "N-DS-J1": "상인회 짐꾼", "N-DS-J2": "상인회 짐꾼",
           "N-GR-D1": "객차 떠돌이", "N-GR-S1": "새벽인력 측량조", "N-GR-S2": "새벽인력 측량조",   # 1-D4 구로 차량기지
           "N-GS-1": "각성회 신도", "N-GS-2": "각성회 신도", "N-GS-3": "각성회 신도",
           "N-GS-5": "새 순례자", "N-GS-6": "새 순례자", "N-GS-R3": "3번 파수", "N-K24-P1": "원장 대행",
           "N-GT-M1": "고터 민병", "N-GT-M2": "고터 민병", "N-J03-R1": "운반조 짐꾼",
           "N-BJ-C1": "다리목 검문조장", "N-SB-R1": "새벽인력 모집원",
           "N-SB-L1": "인솔 반장", "N-SB-H1": "출장소 인수원", "N-JY-P1": "방범대 조장", "N-ND-G1": "노들 남문 경비",
           "N-BG-G1": "밤손님", "N-BJ-C2": "다리목 분대장", "N-DS-E1": "탈영병", "N-DS-E2": "탈영병", "N-JM-K1": "광장 아이", "N-YM-1": "국밥 장수", "N-YM-2": "부품 장수", "N-DB-S1": "대방 정찰", "N-DB-S2": "대방 정찰",
           "N-DR-1": "천 씨", "N-DR-2": "천수호", "N-DR-3": "국수 노점", "N-DR-4": "일용직", "N-DR-5": "마늘 장수", "N-DR-6": "건전지 장수", "N-DR-7": "옷 노점",
           "N-BC-H1": "조씨 할매", "N-BC-H2": "남씨네 어머니", "N-BC-H3": "오씨네 딸", "N-GV-1": "봉천 자경", "N-GV-2": "사당 경비", "N-GS-C1": "각성회 운반조", "N-GS-C2": "각성회 운반조", "N-HS-P1": "퇴원 환자", "N-HS-P2": "퇴원 환자", "N-HS-P3": "퇴원 환자"}   # 1-12h UQ-70 대림 장터   # 1-12i UQ-64 귀환 유해 대장   # 1-12f FQ-SB-02 현장 운송   # 1-12e FQ-JH-03 이동 검문 · 모집원   # 1-12d FQ-JH-02 · 고터 지하상가   # 1-12b FQ-GS-01 · GS-02   # 1-8g 노량진 관제 중계소
DECISION = ["어느 편에 서겠", "편에 서겠습니까", "제안을 수락", "받아들이겠습니까", "어느 쪽을 택하", "누구 편이"]
OLD_NAMES = ["강태오", "천웨이", "국민방송"]
PAGE = 160
CHOICE_MAX = 80


def banned_terms():
    """SD-18 §2.3 사용 금지 실명(예 칸)과 §11.7 금칙 범주의 예 → 금칙어. 설명 문구는 뺀다."""
    words = set(OLD_NAMES)
    skip = re.compile(r"실제|전부|같은|이름|인물명|명칭|계열|약칭|조합|호칭|고유명|낮잡|멸칭|뜻|말$|^등$|단체명|교단명|교회명|사찰명|국호|지도자|조직명|제호")
    for section, line, header, rows in tables(os.path.join(DOCS, "18_naming-terms.md")):
        col = None
        if section.startswith("### 2.3") and len(header) >= 3:
            col = 2
        if "예(일부)" in header:
            col = header.index("예(일부)")
        if col is None:
            continue
        for ln, cells in rows:
            if len(cells) <= col:
                continue
            if cells[0].strip() in ("X1", "X2", "X16", "X18", "X19", "X20", "X21") or re.search(r"전부|낮잡|모욕|빗댄|§", cells[col]):
                continue                                             # 범주 설명뿐인 칸(실명 목록이 아님)
            for w in re.split(r"[,·]", re.sub(r"\(.*?\)", "", cells[col])):
                w = w.strip().strip("'\"")
                if len(w) < 2 or skip.search(w) or w.endswith("등"):
                    continue
                words.add(w)
    return sorted(words)


class Report:
    def __init__(self):
        self.errors, self.warns = [], []

    def err(self, where, msg):
        self.errors.append(f"오류 {where} {msg}")

    def warn(self, where, msg):
        self.warns.append(f"경고 {where} {msg}")


TOKEN = re.compile(r"\{([^{}]*)\}")


class Ctx:
    def __init__(self):
        self.vars = set(json.load(open(os.path.join(DATA, "vars.json")))["vars"]) | ENGINE_VARS
        self.npcs = json.load(open(os.path.join(DATA, "npcs.json")))["npcs"]
        for cid, row in json.load(open(os.path.join(DATA, "enemies.json"))).items():   # 무명 적 템플릿도 화자(1-3: 추적대 첫 분대, 이름표는 직함)
            self.npcs.setdefault(cid, {"name": row.get("name", cid), "unnamed": True})
        for cid, nm in UNNAMED.items():                                   # 길 위 무명 사람(1-E 인카운터, game StoryState.UNNAMED와 같게)
            self.npcs.setdefault(cid, {"name": nm, "unnamed": True})
        self.banned = banned_terms()
        self.rep = Report()


def conv_text(text, where, cx):
    """원고 문장 → 엔진 문장(제어 코드). 반환: (문장, 화면 길이 추정)."""
    if "\\" in text.replace("\\.", ""):
        cx.rep.err(where, "원고에 역슬래시 제어 코드를 직접 쓰지 않는다(토큰 {..|..}을 쓴다. 줄바꿈 금지 공백 \\.만 허용)")
    out, est, pos = "", 0, 0
    for m in TOKEN.finditer(text):
        out += text[pos:m.start()]
        est += len(text[pos:m.start()])
        pos = m.end()
        body = m.group(1)
        name, _, part = body.partition("|")
        if part and part not in PARTICLES:
            cx.rep.err(where, f"조사 짝이 아니다: {{{body}}}")
        if ":" in name:
            kind, _, ident = name.partition(":")
            if kind == "N":
                if ident not in cx.npcs:
                    cx.rep.err(where, f"없는 인물 ID: {ident}")
                out += f"\\N[{ident}]"
                est += len(cx.npcs.get(ident, {}).get("name", "XXX"))
            elif kind in ("I", "L"):
                out += f"\\{kind}[{ident}]"
                est += 6
            else:
                cx.rep.err(where, f"알 수 없는 토큰 종류: {{{body}}}")
        else:
            if name not in cx.vars:
                cx.rep.err(where, f"미선언 변수 토큰: {{{body}}}")
            out += f"\\V[{name}]"
            est += 4
        if part:
            out += f"\\J[{part}]"
            est += len(part)
    out += text[pos:]
    est += len(text[pos:])
    if "{" in out or "}" in out:
        cx.rep.err(where, "닫히지 않은 토큰 괄호")
    for w in cx.banned:
        if w.isascii():
            hit = re.search(rf"(?<![A-Za-z0-9]){re.escape(w)}(?![A-Za-z0-9])", text)
        elif len(w) == 2:                                             # 두 글자 한글은 어절 경계에서만(조사 '이든' 같은 오탐 방지)
            hit = re.search(rf"(?<![가-힣]){re.escape(w)}(?![가-힣])", text)
        else:
            hit = w in text
        if hit:
            cx.rep.err(where, f"금칙 명칭: {w}")
    for p in DECISION:
        if p in text:
            cx.rep.err(where, f"진영 결정 질문 문형: '{p}'")
    return out, est


def check_expr(src, where, cx, effect=False):
    try:
        ast = SE.parse(src)
    except SyntaxError as e:
        cx.rep.err(where, f"식 구문: {src} — {e}")
        return
    vs, calls = SE.names(ast)
    for v in vs:
        if v not in cx.vars:
            cx.rep.err(where, f"미선언 변수: {v}")
    for c in calls:
        if c not in FNS:
            cx.rep.err(where, f"알 수 없는 함수: {c}()")
    if not effect and any(isinstance(s, list) and s[0] == "set" for s in ast[1:]):
        cx.rep.err(where, f"조건식에 대입이 있다: {src}")


TAG = re.compile(r"^\[([^\]]+)\]\s*")


def parse_tags(text, where, cx):
    tags = []
    while True:
        m = TAG.match(text)
        if not m:
            break
        t = m.group(1).strip()
        text = text[m.end():]
        if t.startswith("화술 "):
            d = t[3:].strip()
            if d.endswith("%"):
                cx.rep.err(where, f"[{t}]: 화술 확률은 난이도로 쓴다(실행 중 계산)")
            elif d not in DIFFS:
                cx.rep.err(where, f"[{t}]: 난이도는 {DIFFS}")
            tags.append({"k": "speech", "skill": "화술", "diff": d})
        elif t.startswith("캡 "):
            tags.append({"k": "caps", "n": int(t[2:])})
        elif t.startswith("물건:"):
            parts = t[3:].split()
            tags.append({"k": "item", "id": parts[0], "n": int(parts[1]) if len(parts) > 1 else 1})
        elif t.startswith("증거:"):
            tags.append({"k": "evidence", "id": t[3:].strip()})
        elif t == "카르마":
            tags.append({"k": "karma"})
        elif t == "관리자 인증":
            tags.append({"k": "admin"})
        elif t == "볼트 S-07":
            tags.append({"k": "vault"})
        elif t in FLAVORS:
            tags.append({"k": "flavor", "text": t})
        else:
            m2 = re.match(r"^(.+?)\s+(\d+)$", t)
            if m2 and m2.group(1) in STATS:
                tags.append({"k": "stat", "name": m2.group(1), "min": int(m2.group(2))})
            elif m2 and m2.group(1) in SKILLS:
                tags.append({"k": "skill", "name": m2.group(1), "min": int(m2.group(2))})
            else:
                cx.rep.err(where, f"알 수 없는 태그 [{t}]")
    if len(tags) > 2:
        cx.rep.err(where, f"선택지 태그는 최대 2개(지금 {len(tags)})")
    late = re.search(r"\[(캡 \d+|물건:[^\]]+|화술 [^\]]+|증거:[^\]]+)\]", text)
    if late:                                                           # 1-12h A229: 뒤에 붙은 태그는 값을 매기지 않고 글자로만 보인다(돈이 안 빠진다)
        cx.rep.err(where, f"태그 [{late.group(1)}]는 선택지 맨 앞에 쓴다(뒤에 쓰면 글자로만 남는다)")
    return tags, text


def compile_file(path, cx):
    rel = os.path.relpath(path, ROOT)
    scenes, sc = [], None
    pending = None                        # 모으는 중인 선택지 op
    n_choice = 0

    def flush():
        nonlocal pending
        if pending is not None:
            sc["ops"].append(pending)
            pending = None

    for ln, raw in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
        line = raw.rstrip()
        where = f"{rel}:{ln}"
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line.startswith(">"):
            flush()
        if line.startswith("@scene"):
            parts = line.split(None, 2)
            sid = parts[1] if len(parts) > 1 else ""
            rest = parts[2] if len(parts) > 2 else ""
            m = re.search(r"\((L-[^)]+)\)\s*$", rest)
            sc = {"id": sid, "title": rest[:m.start()].strip() if m else rest.strip(), "loc": m.group(1) if m else "",
                  "npc": "", "cond": "", "labels": {"START": 0}, "ops": [], "src": rel, "_refs": [], "_first": ""}
            scenes.append(sc)
            n_choice = 0
            continue
        if sc is None:
            cx.rep.err(where, "@scene 앞에 내용이 있다")
            continue
        if line.startswith("@npc"):
            sc["npc"] = line.split(None, 1)[1].strip()
            if sc["npc"] == "-":                                   # 0-9: 진행기·밟는 칸 장면 — 어느 인물에게도 묶지 않는다
                sc["npc"] = ""
                sc["_nonpc"] = True
            elif sc["npc"] not in cx.npcs:
                cx.rep.err(where, f"없는 인물 ID: {sc['npc']}")
        elif line.startswith("@cond"):
            sc["cond"] = line.split(None, 1)[1].strip()
            check_expr(sc["cond"], where, cx)
        elif line.startswith("@cmd"):
            try:
                parts = shlex.split(line)[1:]                       # "따옴표 안 공백"은 인자 하나
            except ValueError as e:
                cx.rep.err(where, f"연출 명령 인자: {e}")
                continue
            if not parts or parts[0] not in CMDS:
                cx.rep.err(where, f"알 수 없는 연출 명령: {parts[:1]}")
            sc["ops"].append({"op": "cmd", "name": parts[0] if parts else "", "args": parts[1:]})
        elif line.startswith("* "):
            lab = line[2:].strip()
            if lab in sc["labels"] and not (lab == "START" and sc["labels"]["START"] == len(sc["ops"])):
                cx.rep.err(where, f"라벨 중복: {lab}")
            sc["labels"][lab] = len(sc["ops"])
        elif line.startswith("-> "):
            to = line[3:].strip()
            sc["ops"].append({"op": "goto", "to": to})
            sc["_refs"].append((to, where))
        elif line.startswith("? "):
            m = re.match(r"^\?\s+(.+?)\s+->\s+(\S+)\s*$", line)
            if not m:
                cx.rep.err(where, "조건 이동 형식: ? 조건 -> 라벨")
                continue
            check_expr(m.group(1), where, cx)
            sc["ops"].append({"op": "if", "cond": m.group(1), "to": m.group(2)})
            sc["_refs"].append((m.group(2), where))
        elif line.startswith("! "):
            fx = line[2:].strip()
            check_expr(fx, where, cx, effect=True)
            sc["ops"].append({"op": "do", "fx": fx})
        elif line.startswith(">"):
            body = line[1:].strip()
            fx = cond = ""
            if " !! " in body:
                body, fx = body.split(" !! ", 1)
                check_expr(fx.strip(), where, cx, effect=True)
            if " ?? " in body:
                body, cond = body.split(" ?? ", 1)
                check_expr(cond.strip(), where, cx)
            if " -> " not in body:
                cx.rep.err(where, "선택지에 -> 이동이 없다")
                continue
            body, target = body.rsplit(" -> ", 1)
            to, _, fail = target.partition("|")
            tags, text = parse_tags(body.strip(), where, cx)
            etext, est = conv_text(text.strip(), where, cx)
            if est > CHOICE_MAX:
                cx.rep.err(where, f"선택지 {est}자 > {CHOICE_MAX}")
            elif est > 40:
                cx.rep.warn(where, f"선택지 {est}자(권장 40자 이내)")
            if pending is None:
                pending = {"op": "choice", "opts": []}
                n_choice += 1
            opt = {"text": etext, "tags": tags, "cond": cond.strip(), "fx": fx.strip(), "to": to.strip(),
                   "id": f"{sc['id']}:{n_choice}:{len(pending['opts'])}"}
            if fail.strip():
                opt["fail"] = fail.strip()
                sc["_refs"].append((fail.strip(), where))
            elif any(t["k"] == "speech" for t in tags):
                cx.rep.err(where, "화술 판정 선택지에는 실패 이동(| 라벨)이 있어야 한다")
            sc["_refs"].append((to.strip(), where))
            pending["opts"].append(opt)
        else:
            m = re.match(r"^(SYS|CR-\d+|[CN]-[A-Z0-9]+(?:-[A-Z]?[0-9]+)?)\s+(?:\[([^\]]+)\]\s*)?(.+)$", line)
            if not m:
                cx.rep.err(where, f"알 수 없는 줄: {line[:30]}")
                continue
            who, emo, text = m.group(1), m.group(2) or "기본", m.group(3)
            if who != "SYS" and who not in cx.npcs:
                cx.rep.err(where, f"없는 화자 ID: {who}")
            if emo not in EMOS:
                cx.rep.err(where, f"표정 키 [{emo}]는 {EMOS} 중 하나")
            etext, est = conv_text(text, where, cx)
            if est > PAGE * 2:
                cx.rep.err(where, f"대사 {est}자 > 2쪽({PAGE * 2}자)")
            elif est > PAGE:
                cx.rep.warn(where, f"대사 {est}자: 2쪽으로 나뉜다")
            if who != "SYS" and not sc["_first"]:
                sc["_first"] = who
            sc["ops"].append({"op": "line", "who": who, "emo": emo, "text": etext})
    flush()
    for s in scenes:
        for to, where in s.pop("_refs"):
            if to != "END" and to not in s["labels"]:
                cx.rep.err(where, f"없는 라벨: {to}")
        first = s.pop("_first")
        if not s["npc"] and not s.pop("_nonpc", False):
            s["npc"] = first
        if not s["cond"]:                                          # 0-8: 2268 장면이 2274년 차명수에게 다시 열렸다
            cx.rep.err(f"{s['src']} {s['id']}", "@cond가 없다 — 그 인물에게 말을 걸면 어느 시대든 이 장면이 다시 열린다")
        s["ops"].append({"op": "end"})
    return scenes


def main():
    cx = Ctx()
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, "*.json")):
        os.remove(f)
    ids, total = {}, 0
    for path in sorted(glob.glob(os.path.join(SRC, "**", "*.txt"), recursive=True)):
        if os.sep + "terms" + os.sep in path or os.sep + "world" + os.sep in path or os.sep + "notes" + os.sep in path:   # 단말 원고(1-4)는 term_compile, 길 위 쪽지(1-4f)는 world_chunks가 읽는다
            continue
        for s in compile_file(path, cx):
            if s["id"] in ids:
                cx.rep.err(s["src"], f"장면 ID 중복: {s['id']} ({ids[s['id']]})")
            ids[s["id"]] = s["src"]
            total += sum(1 for o in s["ops"] if o["op"] == "line")
            json.dump(s, open(os.path.join(OUT, s["id"] + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump({"scenes": sorted(ids)}, open(os.path.join(OUT, "_index.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    head = f"원고 변환 v1: 장면 {len(ids)}, 대사 {total}줄 | 오류 {len(cx.rep.errors)}, 경고 {len(cx.rep.warns)}"
    open(os.path.join(DATA, "_script_report.txt"), "w", encoding="utf-8").write("\n".join([head] + cx.rep.errors + cx.rep.warns) + "\n")
    print(head)
    for e in cx.rep.errors[:30]:
        print(" ", e)
    return 1 if cx.rep.errors else 0


if __name__ == "__main__":
    sys.exit(main())
