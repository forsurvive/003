## 적 v0: 인지(0.1초)·상태(0.1초)·전술(0.5초)·행동(매 프레임) 4층 (SD-11 §7.1).
## 성향: 'swarm'(큰바퀴: 둘러싸고 3t 안 2초 머물면 도약 물기) / 'shooter'(보병 계엄병: 유효 사거리 60~90% 유지, 공격 토큰)
##       / 'melee'(S-07 보안요원 진압봉: 다가가서 휘두른다, 단계 0-9).
## 단계 0-9(MQ-P4): 순찰 경로(route: 지점마다 서서 좌우를 둘러본다) · 제자리 경계(stance hold) · 기절(비살상 무기로 HP 0 → 누웠다가
##   25초 뒤 깨어나 수색) · 체력 하한(CR-405 파워 아머는 1 밑으로 안 내려가고 체력 막대도 없다) · 생포 사격(주인공을 죽이지 않는다:
##   피해는 HP에만, 0이 되면 진행기가 '붙잡힘'으로 처리).
class_name Enemy
extends Actor

const DOGS := ["CR-104", "CR-095", "CR-107", "CR-106", "CR-108", "CR-105", "CR-500", "CR-136", "CR-097", "CR-121", "CR-096", "CR-004", "CR-080", "CR-081", "CR-082", "CR-130", "CR-501"]
const MOM_HATCH_S := 15.0                       ## 배수구 어미 부화 간격(SD-14 CR-501 '15초마다 큰바퀴 3')
const GHOULS := ["CR-200", "CR-201", "CR-202", "CR-204", "CR-205", "CR-206", "CR-457", "CR-459", "CR-518"]   ## 방사능에 낫는 구울(SD-14 §7.2 '라드 100당 HP +1')
const BOSS_HP := {"CR-513": [60, 10], "CR-514": [80, 8], "CR-515": [100, 10], "CR-516": [70, 8], "CR-523": [60, 8], "CR-525": [90, 10]}   ## 레벨 비례 스토리 보스 HP = 기본 + Lv × 계수(SD-14 §10.2)
const SWARMY := ["CR-095", "CR-200", "CR-201", "CR-204", "CR-205", "CR-206", "CR-001", "CR-002"]   ## 떼 성향(근접 토큰 넷 — SD-11 · 시궁쥐 · 바퀴 · 야생 구울)
const FERALS := ["CR-200", "CR-201", "CR-204", "CR-205", "CR-206"]            ## 빛나는 구울 폭발에 HP +30%를 받는 야생 구울
const BURST_R := 4.0 * 32.0                       ## 빛나는 구울 방사능 폭발 반경(SD-14 CR-202 '반경 4타일')
const BURST_CD := 8.0                             ## 폭발 간격(SD-11 §7 구울 원형 표 '8초마다')
const HOWL_BUFF := 20.0                           ## 들개 우두머리 울부짖기: 무리 속도 +15% · 피해 +20%(20초, 쿨 30초)
const HOWL_CD := 30.0
const RAT_CALL_CD := 20.0                       ## 왕쥐 찍찍 울음(SD-14 CR-097): 12t 안 시궁쥐 둘 호출 · 쿨 20초
# 1-D3 독산(SD-14 CR-096 · CR-004 · SD-13 W-068 미끼)
const BAIT_R := 10.0 * 32.0                     ## 미끼 냄새를 맡는 거리(교전 전 · 수색 · 놓침)
const BAIT_FIGHT_R := 6.0 * 32.0                ## 교전 중이어도 표적이 이보다 멀면 미끼로 간다
const MOLE_UP_S := 4.0                          ## 굴쥐가 땅 위에서 싸우는 초(그 뒤 흙이면 다시 판다)
const MOLE_HEAVE_S := 1.0                       ## 흙 들썩임(예비 동작) — SD-14 CR-096 '1.0초'
const MOLE_UNDER_SPD := 4.0 / 3.0               ## 땅속 4.0t/초 ÷ 땅 위 3.0t/초
const HATCH_S := 10.0                           ## 알집바퀴 부화 간격(SD-14 CR-004 '10초마다')
const HATCH_MAX := 6                            ## 동시 최대
const STIR_S := 15.0                            ## 소리 · 맞음 · 서서 다가오는 사람에 들썩인 뒤 부화를 이어 가는 초

var brain: AIBrain
var cmb := Combatant.new()
var row: Dictionary
var style := "shooter"
var weapon: Dictionary
var skill := 45.0
var per := 5.0
var react := 0.3                              ## 반응 지연(계엄군 0.3초, §7.4)
var has_token := false
var dash_to := Vector2.INF                       ## 진행기가 시킨 달려가기(황두칠이 금고로 — 밸런스 재미 검수): 쏘지 않고 길을 따라 뛴다 · 경직 없음 · DR +25
var _dash_cd := 0.0
var _dash_dr := 0.0
var _wind := 0.0                                 ## 물기 예비 동작 남은 초(0이면 아직 시작 안 함)
var _circ := 1.0                                 ## 둘레 도는 방향(±1)과 빠르기 — 1.5~3초마다 다시 굴림
var _circ_v := 0.8
var _circ_t := 0.0
var has_mtoken := true                           ## 근접 토큰(전투 고리가 1.5초마다 나눔 — 없으면 2~3칸 밖에서 맴돈다)
var _burst := 0                                   ## 이번 연사에서 쏜 발 수
var _t_per := 0.0
var _t_tac := 0.0
var _cool := 0.0
var _close_t := 0.0
var _leap := 0.0
var _path := PackedVector2Array()
var _path_i := 0
var _hist: Array = []                         ## [time, pos] of the target for the reaction delay
var _clock := 0.0
var _intent := {"goal": "hold"}
var _move := Vector2.ZERO
var _dead_t := 0.0
var _heard := 0.0
var _heard_at := Vector2.ZERO
var ui_font: Font
var shots_fired := 0
var _wander_t := 0.0
var route: Array = []                         ## 순찰: [[위치, 머무는 초], …] — 비면 배회(반경 4t)
var _route_i := 0
var _route_wait := 0.0
var _look_base := 2
var stance := ""                              ## "hold": 제자리 경계(정문 계엄군)
var led := false                              ## 진행기가 걸음을 준다(1-12f 운송 행렬): 평시(IDLE)엔 제 걸음이 없고, 경계 · 교전이 붙으면 AI가 넘겨받는다
var fixed := false                            ## 제자리 고정(감시포 — 몸은 돌고 걷지 않는다, 1-11c)
var level := 1                                ## 실제 레벨(장소 상한을 건 뒤)
var bite := 8.0                               ## 들개 물기 피해(SD-14 표 '물기 n')
var focus: Combatant                          ## 지금 노리는 대상(주인공·아군 감시조 — 진행기가 정한다, 0-10)
var hold_dir := 2                             ## 제자리 경계 방향
var det_mul := 1.0                            ## 감지 배수(1-E 상황: S3 먹이 중 0.5 · S4 잠 0.15 · S2 매복 1.2)
var lurk := false                             ## 1-D 물속 매복(침수 구울 CR-206): 물 타일에서 보이지 않다가 2.5칸 안에 오면 일어나 덮친다(SD-14)
var asleep := false                           ## 야영 중 잠(S4): 누워 있고, 맞거나 가까운 소리·탐지 게이지 50이면 깬다
var doze := ""                                ## 휴면 군집(SD-14 §12 · SQ-S05): "sit" · "lie" · "stand" — 소리 · 맞음 · 가까이 선 걸음으로만 깬다
var wake_cb := Callable()                     ## (e): 하나가 깨면 같은 무리가 한꺼번에(SD-14 '일제 기상') — 진행기가 준다
var foes: Array = ["player", "ally"]          ## 노리는 편(1-E 교전 S5: 다른 무리 편을 더한다 · 비적대 무리는 player를 뺀다)
var arm := ""                                 ## 보안요원 무기: baton | pistol
var who := ""                                 ## 이름 있는 경비(N-R01-018 권서준 등) — 이름표·대사
var hp_floor := 0.0                           ## 이 밑으로 HP가 내려가지 않는다(CR-405, '못 이기는 적')
var hide_bar := false
var ko_t := 0.0                               ## 기절해 누운 남은 초
const KO_SECS := 25.0
## 1-9e 사기(SD-11 §7.5 · SD-14 §12.1): 속성 · 도주 · 항복 · 약물 광란 · 부위 손상 효과 · 말풍선
var traits := {}
var morale := false                           ## 사기가 꺾일 수 있나(길 위 조우 · 생성 건물 — 진행기가 세운 적은 끝까지 싸운다, SD-20 P10)
var conf_mod := 0                             ## 분대장 사망 −1 · 궁지에서 버팀 +4
var leader_near := Callable()                 ## () -> bool: 살아 있는 우리 분대장이 12t 안에 있나(전투 모듈이 준다)
var frenzied := false                         ## 광란: 도주하지 않고 피해 +25%
var released := false                         ## 항복한 적을 놓아줌: 주인공에게서 멀어져 사라진다
var _drug_t := -1.0                           ## 약물 투여 중 남은 초(1.5초 멈춤 → 광란)
var _drug_done := false
var _stuck_t := 0.0
var _rally := 2.0                             ## 사기를 되찾았을 때 HP 비율 — 그보다 15%p 더 깎여야 다시 도망친다
var _spread_add := 0.0                        ## 팔 손상 +8° · 머리 손상 +3°
var _melee_mul := 1.0                         ## 팔 손상 근접 −30%
var say_text := ""
var say_t := 0.0
## 1-9e2 무기 · 점사 · 전환 · 수류탄(SD-11 §7.4)
var alt_weapon := {}                          ## 붙으면 바꿔 드는 근접 무기(계약 경호 구울 소방 도끼)
var _main_weapon := {}
var on_alt := false
var _switch_t := 0.0                          ## 무기 바꾸는 중(0.6초 — 경계에서 들락날락하면 공격이 끊긴다, 원작 공략)
var nades := 0
var nade_w := {}
var throw_cb := Callable()                    ## (from, to) — 전투 모듈이 Ordnance.throw로
var squad_ok := Callable()                    ## () -> bool: 분대 수류탄 재사용(4초)
var _nade_cd := 0.0                           ## 개체 재사용(8초)
var _hide_t := 0.0                            ## 표적이 엄폐 뒤에서 버틴 초(3초 넘으면 수류탄)
var _burst_on := 0.0                          ## 연사 무기 점사 남은 초(0.6~1.2)
var _burst_rest := 0.0                        ## 점사 뒤 쉬는 초(0.5~1.0)
const SAY := {"howl": ["아우우우—!", "우워어어—!"], "rat_call": ["찌이익—!", "끼익! 끼익!"], "flee": ["살려 줘!", "튀어!", "이건 못 해먹겠다!"], "surrender": ["쏘지 마! 항복이야!", "그만, 그만! 손 들었어!"],
	"drug": ["크흐… 이거면 돼…", "으아아!"], "nade": ["수류탄!", "받아라!"], "back": ["다시 간다!", "덤벼 봐!"], "alarm": ["저기다!", "여기야!"],
	"click": ["딸깍.", "딸깍—", "따각."], "growl": ["으르렁…", "그르르…", "크르릉…"]}
var _rng := RandomNumberGenerator.new()
# 1-D3 미끼 · 굴쥐 · 알집바퀴
var bait_at := Callable()                     ## (p, r) -> Dictionary: 가장 가까운 미끼 냄새 지대(Ordnance.bait_near — 전투 모듈이 준다)
var _bait := {}                               ## 먹으러 가는 · 먹는 미끼 지대(지대 사전을 그대로 잡는다 — 먹을수록 빨리 사라진다)
var eating := false
var mole := false                             ## 굴쥐 CR-096: 흙 칸에서만 땅속으로(SD-14 L423)
var aqua := false                             ## 변이 메기 CR-130(1-D5a): 물 칸(침수 1 · 2)에서만 움직인다 · 물에 선 사람은 수염으로 안다(은신 무효, SD-14 L580)
var burrow := ""                              ## "" 땅 위 · under 땅속 · heave 들썩임 · emerge 솟음 · dig 파고듦
var _bur_t := 0.0
var _up_t := 0.0
var _soil_route: Array = []                   ## 땅속 길(흙 칸 가운데 점들)
var _route_t := 0.0
var _bur_goal := Vector2.INF
var nest := false                             ## 알집바퀴 CR-004: 둥지(처음 자리)에서 거의 움직이지 않는다
var bare := false                             ## 알집이 떠내려갔다(배수 밸브) — 부화 끝
var hatch_cb := Callable()                    ## (e): 큰바퀴 1~2 부화(전투 모듈 — 동시 최대 6)
var _stir := 0.0
var _hatch_t := 0.0
var _click := false
# 1-9e4 생물 특수(SD-14 §4.2 · §7.2 · SD-11 §9.2)
var glow := false                             ## 빛나는 구울(CR-202): 오라 덧그림 · 방사능 폭발
var rad_at := Callable()                      ## (p) -> 라드/초(RadField.dose_at) — 구울은 방사능에 낫는다
var burst_cb := Callable()                    ## (e, probe) -> bool: 폭발(probe면 '다친 야생 구울이 곁에 있나'만 묻는다)
var _burst_cd := 3.0
var _ring_t := -1.0                           ## 폭발 고리 그리기(0~0.5초)
var howl_cb := Callable()                     ## (e): 무리에 울부짖기
var _howl_cd := 0.0
var call_cb: Callable                            ## 왕쥐 호출(InteriorCombat._rat_call)
var buff_t := 0.0                             ## 울부짖기를 받은 남은 초(속도 +15% · 물기 +20%)
var mine_list := Callable()                   ## () -> Array: 깔린 지뢰(들개 함정 회피)
var _mine_skip := {}                          ## 지뢰 자리 -> 돌아가나(개체마다 지뢰 하나에 한 번 굴림, 50%)
var _rad_heal := 0.0
var _aura: Sprite2D
## 측정용(--ai-profile): 이번 프레임 층별 시간(마이크로초)과 횟수. 측정을 켜지 않으면 시계를 읽지 않는다.
static var profiling := false
static var prof := {"per": 0, "tac": 0, "act": 0, "n_per": 0, "n_tac": 0, "n_path": 0, "path": 0}


func setup_enemy(enemy_row: Dictionary, weapon_row: Dictionary, pos: Vector2, w, opts: Dictionary = {}) -> void:
	row = enemy_row
	weapon = weapon_row
	arm = str(opts.get("arm", "baton" if row["id"] == "CR-473" else ("claw" if row["id"] in ["CR-200", "CR-201", "CR-202", "CR-204", "CR-205", "CR-206"] else "")))
	who = str(opts.get("who", ""))
	stance = str(opts.get("stance", ""))
	var is_roach: bool = row["id"] in ["CR-002", "CR-001"]
	var is_dog: bool = row["id"] in DOGS                                         # 네발 물기(들개 · 1-5 변이 시궁쥐 — 2타일에서 덤벼 문다, SD-14 §4)
	_rng.seed = int(pos.x * 31 + pos.y * 17)
	var sheet := "en_cr401_loco"
	match str(row["id"]):
		"CR-002":
			sheet = "cr_cr002_base_loco"
		"CR-104":
			sheet = "cr_cr104_loco"
		"CR-105":
			sheet = "cr_cr105_loco"                                  # 사나운 들개(1-11a, SD-14 — 검은 털 · 붉은 눈)
		"CR-500":
			sheet = "cr_cr500_loco"                                  # 외눈(1-11a, SD-04a §4.1 — 흰 털 · 왼눈 흉터 · 목줄과 인식표)
		"CR-095":
			sheet = "cr_cr095_loco"
		"CR-097":
			sheet = "cr_cr097_loco"                                  # 왕쥐(1-11d, SD-14 §4.1 — 한 치수 반 큰 몸 · 흉터 · 엉킨 꼬리 매듭)
		"CR-096":
			sheet = "cr_cr096_loco"                                  # 굴쥐(1-D3, SD-14 §4.1 — 흙빛 · 흰 발톱 · 땅속 전용 컷)
		"CR-004":
			sheet = "cr_cr004_loco"                                  # 알집바퀴(1-D3, SD-14 §3.1 — 배 끝 알집이 맥동)
		"CR-501":
			sheet = "cr_cr501_loco"                                  # 배수구 어미(1-12h UQ-09, SD-14 §10.2 — 등에 알집 무더기 · 긴 더듬이)
		"CR-001":
			sheet = "cr_cr001_loco"                                  # 잔바퀴 떼(1-12h UQ-09, SD-14 §3.1 — 64칸 안 작은 바퀴 무리 한 몸)
		"CR-136":
			sheet = "cr_cr136_loco"
		"CR-080", "CR-081", "CR-082":
			sheet = "cr_%s_loco" % str(row["id"]).to_lower().replace("-", "")   # 왕개미 일개미 · 병정 · 여왕(1-D5 금탑, SD-14 §3.5 — 검은 광택 · 삼각 보행)
		"CR-130":
			sheet = "cr_cr130_loco"                                  # 변이 메기(새끼 — 1-D5a 금탑 수족관, SD-14 L580 — 넓적한 머리 · 수염 넷 · 흰 얼룩)
		"CR-121":
			sheet = "cr_cr121_loco"                                  # 변이 미국가재(1-D 대방 지하차도, SD-14 — 붉은 마디 몸 · 큰 집게 둘)
		"CR-206":
			sheet = "en_cr206_loco"                                  # 침수 구울(1-D, SD-14 — 젖은 검정 누더기, 물속 매복)                                  # 옴 너구리(1-T2 밤 몹, SD-14 §4.9 — 눈가 검은 띠 · 털 빠진 꼬리)
		"CR-107":
			sheet = "cr_cr107_loco"                                  # 경비견(1-6, 새벽인력 조끼)
		"CR-405":
			sheet = "en_cr405_loco"
		"CR-436", "CR-437", "CR-200", "CR-201", "CR-456", "CR-457", "CR-402", "CR-403", "CR-435", "CR-438", "CR-460", "CR-472":   # 1-13e 각성회 신도 · 정착지 민병   # 1-4: 야생·떠돌이 구울(맨손), 지하시장 경비·계약 경호 구울
			sheet = "en_%s_loco" % str(row["id"]).to_lower().replace("-", "")
		"CR-513":
			sheet = "en_c013_loco"                                  # 황두칠(SD-14 CR-513, 외형 SD-07b C-013)
		"CR-534":
			sheet = "en_c021_loco"                                  # 독사(SD-14 §10.4, 외형 SD-07b C-021)
		"CR-473":
			sheet = "en_cr473_%s_loco" % arm
		"CR-420", "CR-421", "CR-423":                               # 1-E 남부순환 패거리(SD-14 F-04-C): 두 외형 중 하나
			sheet = "en_%s%s_loco" % [str(row["id"]).to_lower().replace("-", ""), "b" if _rng.randf() < 0.5 else ""]
		"CR-204", "CR-205":
			sheet = "en_%s_loco" % str(row["id"]).to_lower().replace("-", "")   # 대피민 · 역무원 구울(1-11e SQ-S05 — 2077 차림 · 제복)
		"CR-306":
			sheet = "rb_cr306_loco"                                  # 역무 파수-3(파수-3의 지하철 판)
		"CR-305":
			sheet = "rb_cr305_loco"                                  # 파수-3(1-11c SQ-S04, SD-16 §7.4 — 이족 · 방패 팔 · CRT 얼굴판 · 관제망 휘장)
		"CR-320":
			sheet = "rb_cr320_loco"                                  # 감시포 1형(기둥 위 원통 포탑 — 제자리)
		"CR-326":
			sheet = "rb_cr326_loco"                                  # 성형-4(1-D7 지식산업센터 — 궤도 받침 · 관절 팔 · 렌즈, 작업 2컷)
		"CR-106":
			sheet = "cr_cr104_loco"                                  # 들개 우두머리(그림은 들개, 1-E2에서 따로)
		"CR-108":
			sheet = "cr_baekgu_loco"                                 # 진돗개(백구 그림을 빌린다)
		"CR-202":
			sheet = "en_cr200_loco"                                  # 빛나는 구울: 야생 구울(SG2) 위에 방사능 빛 덧그림(SD-16 §4.3 · §10.5)
			glow = true
	_rng.seed = int(pos.x * 7 + pos.y * 13)
	if opts.has("sheet"):
		sheet = str(opts["sheet"])
	setup(sheet, pos, w)
	if glow and CombatFx.has_set("aura_rad"):                       # 오라: 가산 덧그림 4컷(SD-16 §10.5) — 인물 그림 위
		_aura = Sprite2D.new()
		_aura.texture = CombatFx.sheet()
		_aura.region_enabled = true
		_aura.centered = false
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_aura.material = mat
		var a: Array = CombatFx.meta()["sets"]["aura_rad"]["anchor"]
		_aura.position = -Vector2(a[0], a[1])
		add_child(_aura)
	style = "swarm" if is_roach else ("dog" if is_dog else ("melee" if arm in ["baton", "claw", "melee"] else "shooter"))
	if is_dog:                                                       # 변이 들개(SD-14 §4.2): 4.5t/초, 지그재그로 달려와 문다
		var qpx := float((meta.get("motions", {}) as Dictionary).get("walk", {}).get("px_per_frame", 4))   # 시트의 컷당 보폭(시궁쥐 · 너구리 2px) — 디딘 발이 미끄러지지 않게
		loco.custom = {"run": {"frames": 4, "px": qpx, "diag": qpx, "contact": [0, 2], "speed_t": float(row["speed"])},
			"walk": {"frames": 4, "px": qpx, "diag": qpx, "contact": [0, 2], "speed_t": float(row["speed"]) * 0.45}}
		bite = float(str(row.get("attack", "물기 8")).get_slice(" ", 1))
	if row["id"] == "CR-305":                                       # 파수-3: 사람과 같은 보폭 표(발 고정 6컷) · 무거워 뛰지 않는다(2.5t/초)
		loco.custom = {"run": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": float(row["speed"]), "anim": "walk"},
			"walk": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": float(row["speed"]) * 0.7}}
	if row["id"] == "CR-326":                                       # 성형-4: 궤도 돌기를 사람 보폭 표로 그렸다(옆 4 · 앞뒤 · 대각 3px — 바닥에 닿은 돌기가 세계에 고정)
		loco.custom = {"run": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": float(row["speed"]), "anim": "walk"},
			"walk": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": float(row["speed"]) * 0.7}}
	fixed = float(row.get("speed", 1.0)) <= 0.0                       # 포탑(감시포): 제자리에서 돌기만 한다
	if row["id"] == "CR-405":                                       # 파워 아머: 느리고 무겁다(보폭 6·4px, 2.4t/초). 넉다운 면역
		loco.custom = {"run": {"frames": 6, "px": 6.0, "px_v": 4.0, "diag": 4.0, "contact": [0, 3], "speed_t": 2.4},
			"walk": {"frames": 6, "px": 6.0, "px_v": 4.0, "diag": 4.0, "contact": [0, 3], "speed_t": 2.4}}
	hold_dir = EventRunner.DIR_IDX.get(str(opts.get("dir", "S")), 2)
	if stance == "hold":                                            # 제자리 경계병(정문 데크): 한 곳만 보고 있어 더 멀리, 더 빨리 본다
		per = 7.0
	loco.facing = hold_dir
	for r in opts.get("route", []):
		route.append([Vector2(int(r[0]) * 32 + 16, int(r[1]) * 32 + 16), float(r[2])])
	cmb.actor = self
	cmb.team = str(opts.get("team", "enemy"))
	if opts.has("foes"):
		foes = (opts["foes"] as Array).duplicate()
	det_mul = float(opts.get("det", 1.0))
	cmb.can_ko = not is_roach and not is_dog
	traits = EnemyTraits.of(str(row["id"]))
	react = float(traits.get("react", react))
	cmb.track_limbs = true
	cmb.crippled_part.connect(_on_cripple)
	cmb.hit.connect(func() -> void:
		if cmb.crippled.has("torso") and not cmb.dead and dash_to == Vector2.INF and _rng.randf() < 0.5:
			cmb.hold("flinch", 0.25))                                  # 몸통 손상: 맞을 때마다 50% 0.25초 경직
	cmb.hp = float(row["hp"])
	cmb.dr = float(row["dr"])
	level = int(row.get("level", 1))
	if opts.has("lv") and BOSS_HP.has(str(row["id"])):               # 스토리 보스(SD-14 §10.1 · §10.2): 플레이어 레벨 비례 — HP = 기본 + Lv × 계수(밸런스 첫 전수 — 전엔 표의 기본 HP 그대로)
		var bl := int(opts["lv"])
		cmb.hp = float(BOSS_HP[str(row["id"])][0]) + bl * float(BOSS_HP[str(row["id"])][1])
		level = bl
	elif opts.has("lv") and int(opts["lv"]) < level:                 # 장소 위협도 상한(SD-08 §9: 봉천 위협 1 = Lv1~4, SD-14 §12 스케일링)
		var lv := int(opts["lv"])
		cmb.hp = (20.0 + lv * 8.0) if not (is_roach or is_dog) else roundf(cmb.hp * lv / level)   # 인간 HP ≈ 20 + Lv×8(SD-14 §3.4)
		if str(row["id"]).begins_with("CR-5") and not (is_roach or is_dog):
			cmb.hp = minf(float(row["hp"]), roundf((20.0 + lv * 8.0) * 1.6))   # 이름 있는 사람은 단역보다 단단하게(밸런스 첫 전수 — MQ-101 독사 52 → 85)
		cmb.dr = roundf(cmb.dr * lv / level)
		if is_dog:
			bite = roundf(bite * lv / level)                            # 낮춘 짐승은 물기도 같은 비율로(밸런스 첫 전수 — 금탑 메기 새끼 36 → 18)
		level = lv
	cmb.max_hp = cmb.hp
	if float(opts.get("hurt", 0.0)) > 0.0:                          # 다친 개체(S5~S7, SD-22 §3.2): HP 30~60%로 시작
		cmb.hp = maxf(1.0, roundf(cmb.max_hp * float(opts["hurt"])))
	cmb.radius = float(row["radius"]) * 32.0
	radius_px = cmb.radius
	cmb.weights = {"head": 15, "torso": 55, "leg": 30} if is_roach else ({"head": 20, "torso": 50, "leg": 30} if is_dog else CombatRules.HUMANOID_WEIGHTS)
	if str(row.get("part_weights", "")) == "PW-B":                    # 왕개미(PW-B, SD-11 §4.8 표 곤충): 머리 15 · 몸통 60 · 다리 15 · 더듬이 10(부위 손상 → 광란)
		cmb.weights = {"head": 15, "torso": 60, "leg": 15, "antenna": 10}
	elif str(row.get("part_weights", "")) == "PW-D":                  # 갑각(PW-D, SD-14 §2.4 — 가재 · 참게 · 거북): 얼굴 10 ×2 · 껍질 70 ×0.5 · 집게 10 · 다리 10,
		cmb.weights = {"head": 10, "torso": 70, "arm": 10, "leg": 10}  # 뒤쪽 명중은 껍질 70 가운데 40이 배(×1.0) — 돌아 들어가 쏘는 보람(1-13 D-380)
		cmb.part_mult = {"head": 2.0, "torso": 0.5, "belly": 1.0}
		cmb.back_part = ["torso", "belly", 40]
	per = 3.0 if is_roach else (4.0 if is_dog else 5.0)
	brain = AIBrain.new(pos, per, "insect" if is_roach else "human")
	if stance == "hold":
		brain.per = 7.0
	if is_roach:
		var rpx := 2.0 if row["id"] == "CR-001" else 3.0                  # 잔바퀴 떼 시트는 컷당 2px(무리가 꿈틀 — 미끄러지지 않게)
		loco.custom = {"run": {"frames": 4, "px": rpx, "diag": rpx, "contact": [0, 2], "speed_t": float(row["speed"])},
			"walk": {"frames": 4, "px": rpx, "diag": rpx, "contact": [0, 2], "speed_t": float(row["speed"]) * 0.5}}
	ui_font = load("res://assets/fonts/Galmuri9.ttf")
	if str(opts.get("doze", "")) != "":
		doze = str(opts["doze"])
		asleep = true
		det_mul = 0.3
		set_pose(doze if doze != "stand" else "stand")
	elif bool(opts.get("lurk", false)):
		lurk = true
		asleep = true
		det_mul = 0.0
		visible = false                                             # 물속에 엎드림(탐지 불가) — 일어서면 보인다
	elif bool(opts.get("sleep", false)):
		asleep = true
		var curl: bool = sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("sleep_E")
		set_pose("sleep" if curl else "lie")                        # 웅크려 자는 그림이 있는 개(외눈 · 백구 핏줄)는 그 그림으로
	mole = row["id"] == "CR-096"
	aqua = row["id"] == "CR-130"
	nest = row["id"] in ["CR-004", "CR-501"]
	if row["id"] == "CR-001":
		cmb.fire_mul = 2.0                                          # 잔바퀴 떼: 화염 ×2(SD-14 §3.1)
	if nest:
		set_pose("pulse")
	if mole and world is InteriorMap and world.soil_at(world.tile_of(pos)) and not asleep:
		_set_burrow("under")                                        # 흙 칸에서 시작하면 땅속에 숨어 있다
	_t_tac = _rng.randf() * 0.5                                    # 전술 갱신을 개체마다 엇갈리게(한 프레임 몰림 방지)
	_t_per = _rng.randf() * 0.1


## 소리 사건(총성 등): 다음 인지 틱에 반영
func hear(kind: String, at: Vector2) -> void:
	var g := Perception.sound_gain(kind, loco.logical.distance_to(at) / 32.0)
	if g > _heard:
		_heard = g
		_heard_at = at


## 잠에서 깬다(일어선다)
func wake() -> void:
	if not asleep:
		return
	asleep = false
	if lurk:
		lurk = false
		visible = true                                              # 물보라와 함께 일어선다
	set_pose("stand")
	det_mul = maxf(det_mul, 1.0)
	if doze != "":
		doze = ""
		if wake_cb.is_valid():
			wake_cb.call(self)


func think(dt: float, target: Combatant, nav, shots: Projectiles) -> void:   ## nav: NavGrid(청크 월드) 또는 InteriorNav(실내) — 같은 path()
	_clock += dt
	if cmb.ko:
		_ko_step(dt)
		return
	if cmb.dead:
		_die_step(dt)
		return
	if cmb.flash > 0:
		cmb.flash -= 1
	if cmb.held():                                                 # 1-9a 행동 제한(넘어짐·기절·마비·그물): 아무것도 못 한다
		_held_step(dt)
		return
	if _held_pose:
		_held_pose = false
		set_pose("stand")
	_hist.append([_clock, target.pos()])
	while _hist.size() > 2 and _clock - float(_hist[0][0]) > react + 0.1:
		_hist.pop_front()
	_t_per += dt
	var t0 := Time.get_ticks_usec() if profiling else 0
	if _t_per >= 0.1:                                              # 인지 + 상태 층
		if profiling:
			prof["n_per"] += 1
		var step := _t_per
		_t_per = 0.0
		var to := target.pos() - loco.logical
		var dist_t := to.length() / 32.0
		var fwd: Vector2 = Locomotion.VEC[loco.facing].normalized()
		var fov := brain.state == AIBrain.S.COMBAT or Perception.in_fov(fwd, to, brain.kind)   # 교전 중에는 표적을 계속 본다
		var sm := sight_of(target)                                   # 고가(1-Rd): 다른 층이면 시야 거리 ×0.5, 상판 위·그늘 사이는 못 본다
		var pe := per - (2.0 if gassed() else 0.0)                  # 최루(SD-13 W-058): 지대 안 인간형 인지력 −2
		var sees: bool = not target.dead and sm > 0.0 and dist_t <= Perception.sight_range(pe) * sm
		var whisk: bool = aqua and world is InteriorMap and (world as InteriorMap).wet_at((world as InteriorMap).tile_of(target.pos())) > 0
		if whisk:                                                   # 메기 수염: 같은 물에 선 사람은 웅크려도 · 등 뒤여도 안다
			fov = true
		var rate: float = Perception.detect_rate(dist_t, pe, {"movement": "move" if whisk else target.movement, "posture": "stand" if whisk else target.posture,
			"sneak_skill": 0.0 if whisk else target.sneak, "alert": brain.alert(), "in_fov": fov}) * det_mul * (0.4 if eating else 1.0) * (1.0 if whisk else _hush_mul(target)) if sees else 0.0
		var hit: bool = cmb.last_hit_from != Vector2.ZERO
		if asleep:                                                  # 잠(S4): 맞거나, 가까운 소리(0.5+)거나, 바로 옆까지 오면 깬다
			var near := 2.5 if lurk else 1.5
			if lurk and row["id"] == "CR-501" and target.posture == "crouch":
				near = 0.0                                          # 천장 배수구 어미: 웅크려 불빛 없이 지나가면 밑으로 지나간다(소리 · 불 · 맞음엔 깬다 — 1-12h 재미 검수 T6)
			if doze != "":                                          # 휴면: 서서 걸으면 2칸 · 웅크리면 1칸까지(서 있기만 하면 1.5칸)
				near = (0.5 if target.sneak >= 50.0 else 1.0) if target.posture == "crouch" else (2.0 if target.movement != "still" else 1.5)
			if hit or _heard >= 0.5 or (sees and dist_t <= near) or brain.gauge >= 50.0:
				wake()
			else:
				sees = false
				rate = 0.0
		cmb.last_hit_from = Vector2.ZERO
		if nest and not bare and (hit or _heard >= 0.3 or (sees and dist_t <= 8.0 and target.posture != "crouch")):
			_stir = STIR_S                                            # 알집바퀴: 소리 · 맞음 · 서서 다가오는 사람에만 들썩인다(웅크려 숨으면 조용)
		var was := brain.state
		_intent = brain.tick(step, {"sees": sees and (fov or dist_t <= 3.0), "rate": rate * (0.6 if cmb.crippled.has("head") else 1.0), "target": target.pos(),
			"hit": hit, "sound": _heard, "sound_at": _heard_at, "at_home": loco.logical.distance_to(brain.home) < 24.0})
		_heard = 0.0
		if was == AIBrain.S.FLEE and brain.state == AIBrain.S.COMBAT:      # 용기를 되찾았다
			loco.speed_mul = 0.5 if cmb.crippled.has("leg") else 1.0
			_rally = cmb.hp / maxf(1.0, cmb.max_hp)
			_say("back")
		_morale(target)
	var t1 := Time.get_ticks_usec() if profiling else 0
	say_t = maxf(0.0, say_t - dt)
	_specials(dt, target)
	if _drug_t > 0.0:                                                  # 약물 투여(1.5초 정지) → 광란(§7.8 약탈자)
		_drug_t -= dt
		loco.step(Vector2.ZERO, dt)
		if _drug_t <= 0.0:
			frenzied = true
			brain.frenzy()
			_intent = {"goal": "engage", "at": target.pos()}
		queue_redraw()
		return
	if released:
		_leave(dt, target, nav)
		return
	if dash_to != Vector2.INF:
		_dash(dt, nav)
		queue_redraw()
		return
	if mole and _mole_step(dt, target, nav):
		queue_redraw()
		return
	if _bait_step(dt, target, nav):
		queue_redraw()
		return
	if led and brain.state == AIBrain.S.RETURN:
		brain.state = AIBrain.S.IDLE                                    # 진행기가 이끄는 사람은 출발 자리로 돌아가지 않는다(싸움 뒤 줄로 — 1-12f)
		brain.gauge = 0.0
	if led and brain.state == AIBrain.S.IDLE:
		queue_redraw()
		return
	_t_tac += dt
	if _t_tac >= 0.5:                                              # 전술 층
		_t_tac = 0.0
		_tactics(target, nav)
		if profiling:
			prof["n_tac"] += 1
	var t2 := Time.get_ticks_usec() if profiling else 0
	_act(dt, target, shots)
	queue_redraw()
	if profiling:
		var t3 := Time.get_ticks_usec()
		prof["per"] += t1 - t0
		prof["tac"] += t2 - t1
		prof["act"] += t3 - t2


var _held_pose := false
var smoke_at := Callable()                    ## 지대 묻기(Ordnance.in_zone) — 연막 · 최루(1-9b)


func _held_step(dt: float) -> void:
	if _wind > 0.0:
		_wind = 0.0
		modulate = Color(1, 1, 1)
	loco.step(Vector2.ZERO, dt)
	if cmb.held_by("down") and not _held_pose:
		_held_pose = true
		set_pose("lie")
	queue_redraw()


func _tactics(target: Combatant, nav) -> void:
	var goal: String = _intent.get("goal", "hold")
	if asleep and not (doze == "stand" and not route.is_empty()):                   # 자는 동안은 제자리(서서 조는 손님만 순찰 길 — 두 걸음 걷고 멈춘다)
		_path = PackedVector2Array()
		_move = Vector2.ZERO
		return
	if target.dead and goal == "engage":                              # 노릴 대상이 없다(교전 상대가 다 쓰러짐 · 비적대 무리): 제자리
		goal = "hold"
	var at: Vector2 = _intent.get("at", loco.logical)
	_move = Vector2.ZERO
	if goal == "flee":
		_flee_path(target, nav)
		return
	if goal == "surrender":
		_path = PackedVector2Array()
		return
	if nest:                                                       # 알집바퀴: 둥지 2.5칸 안으로 들어온 표적만 문다 · 아니면 제자리로
		_path = PackedVector2Array()
		if goal == "engage" and target.pos().distance_to(brain.home) <= 2.5 * 32.0:
			_repath(nav, target.pos())
		elif loco.logical.distance_to(brain.home) > 16.0:
			_repath(nav, brain.home)
		return
	if goal == "engage":
		var d := loco.logical.distance_to(target.pos()) / 32.0
		var los: bool = sight_of(target) > 0.0 and meets(target)
		_arms_tactics(target, d, los)
		if style == "swarm" or style == "melee" or style == "dog":
			_repath(nav, target.pos(), target.fl())
		else:
			var lo: float = float(weapon["range_eff"]) * (0.0 if frenzied else 0.6)
			var hi: float = float(weapon["range_eff"]) * 0.9 if not frenzied else 2.0   # 광란: 붙어서 쏜다
			if d > hi or not los:
				_repath(nav, target.pos())
			elif d < lo:
				_path = PackedVector2Array()
				_move = (loco.logical - target.pos()).normalized()       # back off to the preferred band
			else:
				_path = PackedVector2Array()
	elif goal == "home" and not route.is_empty():                  # 귀환: 가장 가까운 순찰 지점으로
		var best := 0
		for i in route.size():
			if loco.logical.distance_to(route[i][0]) < loco.logical.distance_to(route[best][0]):
				best = i
		_route_i = best
		_repath(nav, route[best][0])
	elif goal == "walk_to" or goal == "home":
		_repath(nav, at)
	elif stance == "hold":                                         # 제자리 경계: 자리로 돌아가 정해진 쪽을 본다
		if loco.logical.distance_to(brain.home) > 8.0:
			_repath(nav, brain.home)
		else:
			_path = PackedVector2Array()
	elif not route.is_empty():                                     # 순찰: 지점에 닿으면 머물며 둘러보고 다음 지점으로
		var wp: Vector2 = route[_route_i][0]
		if loco.logical.distance_to(wp) < 10.0:
			_path = PackedVector2Array()
			if _route_wait == 0.0:
				_look_base = loco.facing
			_route_wait += 0.5
			if _route_wait >= float(route[_route_i][1]):
				_route_wait = 0.0
				_route_i = (_route_i + 1) % route.size()
				_repath(nav, route[_route_i][0])
		elif _path.is_empty() or _path_i >= _path.size():
			_repath(nav, wp)
	else:                                                          # 대기: 배회 반경 4t (§7.2)
		_wander_t -= 0.5
		if _wander_t <= 0.0:
			_wander_t = 3.0 + _rng.randf() * 3.0
			var p := brain.home + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4)) * 32.0
			_repath(nav, p)


func _repath(nav, to: Vector2, goal_fl: int = -1) -> void:
	var p: PackedVector2Array = nav.path(loco.logical, to, floor_id, goal_fl)
	if p.size() > 0:
		_path = p
		_path_i = 1


func _act(dt: float, target: Combatant, shots: Projectiles) -> void:
	var goal: String = _intent.get("goal", "hold")
	mode = "walk" if goal == "walk_to" or goal == "home" or goal == "hold" else "run"
	if goal == "surrender":                                         # 항복: 서서 손을 든다(그리기) · 쏘지 않는다
		loco.step(Vector2.ZERO, dt)
		aim_dir = -1
		var tt := target.pos() - loco.logical
		if tt.length() > 4.0:
			loco.facing = Locomotion.snap8(tt, 0.0)
		_show()
		return
	var input := _move
	if _path.size() > 0 and _path_i < _path.size():
		var wp: Vector2 = _path[_path_i]
		if loco.logical.distance_to(wp) < 6.0:
			_path_i += 1
		input = (wp - loco.logical)
	var to_t := target.pos() - loco.logical
	if goal == "engage" or goal == "face":
		aim_dir = Locomotion.snap8(to_t, 0.0) if style == "shooter" else -1
	else:
		aim_dir = -1
	if style == "swarm" and goal == "engage":
		_swarm(dt, target, to_t)
		if _leap > 0.0:
			return
		if to_t.length() < cmb.radius + target.radius + 2.0:
			input = Vector2.ZERO
	if style == "melee" and goal == "engage" and to_t.length() < float(weapon.get("range_eff", 1.0)) * 32.0 + target.radius:
		input = Vector2.ZERO                                       # 닿는 거리면 서서 휘두른다
	if (style == "dog" or style == "melee") and goal == "engage" and not has_mtoken and to_t.length() < 2.5 * 32.0 and not fixed:
		_circ_t -= dt
		if _circ_t <= 0.0:                                             # 방향 · 빠르기를 다시 굴린다(재미 검수 F6 — 같은 무리도 매번 다르게) · 가끔 반쯤 달려들다 물러난다
			_circ_t = _rng.randf_range(1.5, 3.0)
			_circ = -_circ if _rng.randf() < 0.5 else _circ
			_circ_v = _rng.randf_range(0.55, 0.95)
			if _rng.randf() < 0.25:
				_circ_v = -0.9
		var inward := 0.4 if to_t.length() < 1.8 * 32.0 else 0.0
		var near := cmb.radius + target.radius + 14.0                  # 토큰 없는 개는 이보다 안으로 들지 않는다(몸에 겹치면 방향이 0이 되어 그 자리에 굳는다 — 1-13 rq 봇)
		if to_t.length() < near:
			var away := -to_t if to_t.length() > 0.5 else Vector2.RIGHT.rotated(float(get_instance_id() % 8) * PI / 4.0)
			input = away.normalized()
		elif _circ_v < 0.0 and _circ_t > 1.0:
			input = to_t.normalized() * 0.9                            # 반쯤 달려든다(물지는 않는다 — 토큰이 없다)
		else:
			input = to_t.normalized().orthogonal() * _circ * absf(_circ_v) - to_t.normalized() * inward   # 토큰이 없으면 둘레를 돈다(발 고정 걸음 그대로)
	elif style == "dog" and goal == "engage":
		if to_t.length() < cmb.radius + target.radius + 6.0:
			input = Vector2.ZERO
			_bite(dt, target, to_t)
		elif _wind > 0.0:                                              # 노리던 표적이 빠져나갔다 — 예비 동작을 푼다
			_wind = 0.0
			modulate = Color(1, 1, 1)
		elif to_t.length() > 3.0 * 32.0 and input != Vector2.ZERO:     # 지그재그로 달려든다(포위)
			input = input.normalized() + input.normalized().orthogonal() * sin(_clock * 5.0 + float(get_instance_id() % 7)) * 0.7
		_cool = maxf(0.0, _cool - dt)
	if goal == "flee":
		aim_dir = -1
	if style == "dog" and input.length() > 0.2 and mine_list.is_valid():
		input = _mine_dodge(input)
	if fixed:
		input = Vector2.ZERO                                        # 감시포: 걷지 않는다(돌아서 쏜다)
	if aqua and input.length() > 0.1 and world is InteriorMap:     # 메기: 다음 걸음이 마른 칸이면 물가에서 선다(물 밖으로 안 나온다)
		var nxt := (world as InteriorMap).tile_of(loco.logical + input.normalized() * (radius_px + 6.0))
		if (world as InteriorMap).wet_at(nxt) <= 0:
			input = Vector2.ZERO
	var f0 := loco.frames_advanced
	move(steer(input), dt)
	if goal == "flee":                                               # 궁지: 1초 넘게 한 걸음도 못 떼면 항복하거나 버틴다
		if input.length() > 0.2 and loco.frames_advanced == f0 and loco.motion == "idle":
			_stuck_t += dt
			if _stuck_t >= 1.0:
				_stuck_t = 0.0
				_cornered()
		else:
			_stuck_t = 0.0
		return
	if aim_dir >= 0 and loco.motion == "idle":
		loco.facing = aim_dir                                       # 서서 조준하면 그쪽을 본다(시야각 기준)
	if goal == "engage" and style == "shooter":
		_shoot(dt, target, shots)
	elif goal == "engage" and style == "melee":
		_swing(dt, target)
	elif goal == "hold" and loco.motion == "idle":
		if stance == "hold":
			loco.facing = hold_dir
			_show()
		elif not route.is_empty() and _route_wait > 0.0:            # 순찰 지점에서 둘러보기: 1초마다 좌우로 45도
			var base: int = _look_base
			loco.facing = posmod(base + [0, 1, 0, -1][int(_route_wait) % 4], 8)
			_show()


func _swarm(dt: float, target: Combatant, to_t: Vector2) -> void:
	_cool = maxf(0.0, _cool - dt)
	if row["id"] == "CR-001":                                       # 잔바퀴 떼: 발밑을 덮으며 0.5초마다 1(SD-14 §3.1 '접촉 1/0.5초')
		if _cool <= 0.0 and not target.dead and to_t.length() <= cmb.radius + target.radius + 6.0 and meets(target):
			_cool = 0.5
			target.last_by = cmb.team
			target.take({"hp": 1.0}, loco.logical)
		return
	if _leap > 0.0:                                               # leap: airborne frames only, then bite
		_leap -= dt
		var blocked := func(a: Vector2, b: Vector2) -> Vector2: return world.move_circle(a, b, radius_px)
		var room := maxf(0.0, to_t.length() - (cmb.radius + target.radius))     # 닿는 자리에서 멈춘다(겹쳐 올라타지 않는다)
		var ft := _deck_pre()
		loco.logical = blocked.call(loco.logical, loco.logical + to_t.normalized() * minf(160.0 * dt, room))
		_deck_post(ft)
		loco.render = loco.logical.round()
		position = loco.render
		if _leap <= 0.0 and loco.logical.distance_to(target.pos()) <= 32.0 + target.radius and meets(target):
			target.last_by = cmb.team
			target.take({"hp": 3.0}, loco.logical)
		return
	if to_t.length() <= 3.0 * 32.0:
		_close_t += dt
		if _close_t >= 2.0 and _cool <= 0.0:
			_leap = 0.25
			_close_t = 0.0
			_cool = 1.2
	else:
		_close_t = 0.0


## 들개 물기: 닿으면 반응 지연 뒤 물고 1.1초 쉰다(SD-14 §4.2 '물기 n')
func _bite(dt: float, target: Combatant, to_t: Vector2) -> void:
	if _cool > 0.0 or target.dead or not meets(target) or not has_mtoken:
		if _wind > 0.0:
			_wind = 0.0
			modulate = Color(1, 1, 1)
		return
	loco.facing = Locomotion.snap8(to_t, 0.0)
	var wind_full := 0.3 + maxf(0.0, bite - 15.0) * 0.02             # 물기 앞 예비 동작(재미 검수: 첫 물기도 보이게 — 센 물기일수록 길다, 메기 36 0.72초)
	if _wind <= 0.0:
		_wind = wind_full
		if bite >= 15.0:
			_say("growl", wind_full + 0.3)
		modulate = Color(1.0, 0.82, 0.78)                              # 웅크려 노린다 — 몸빛이 붉어진다
		return
	_wind -= dt
	if _wind > 0.0:
		return
	_wind = 0.0
	modulate = Color(1, 1, 1)
	_show()
	_cool = maxf(0.3, 1.1 + maxf(0.0, bite - 15.0) * 0.05 - wind_full)   # 한 주기는 그대로(1.1 + (물기 − 15) × 0.05초 — SD-11 §10.3 '강 근접 · 예비 동작 길이')
	target.last_by = cmb.team
	var dr_k := 1.0 - minf(target.dr, CombatRules.DR_CAP) / 100.0           # 물기도 몸 전체 DR을 거친다(SD-11 §4.6 — 밸런스 검사 B4, 2026-10-23)
	target.take({"hp": bite * (1.25 if frenzied else 1.0) * (1.2 if buff_t > 0.0 else 1.0) * dr_k}, loco.logical)   # 울부짖기 +20%


func _shoot(dt: float, target: Combatant, shots: Projectiles) -> void:
	_cool = maxf(0.0, _cool - dt)
	_switch_t = maxf(0.0, _switch_t - dt)
	var auto := float(weapon.get("rate", 1.0)) >= 5.0 and str(weapon.get("id", "")) != "W-002"   # 연사 무기(1-9e2) — W-002 호환 장비는 예전 리듬
	if auto:
		if _burst_rest > 0.0:
			_burst_rest -= dt
			return
		if _burst_on > 0.0:
			_burst_on -= dt
			if _burst_on <= 0.0:
				_burst_rest = shots.rng.randf_range(0.5, 1.0)
				return
	if not has_token or _cool > 0.0 or target.dead or _switch_t > 0.0:
		return
	if sight_of(target) <= 0.0 or not meets(target):
		return
	var seen: Vector2 = _hist[0][1] if not _hist.is_empty() else target.pos()     # aim lags by the reaction delay
	var aim := rad_to_deg((seen - loco.logical).angle())
	if row["id"] == "CR-473":                                       # 보안요원 권총: 위협 사격만(어깨 너머로 빗나가게, SD-14 §9.12.1)
		aim += (10.0 + shots.rng.randf() * 6.0) * (1.0 if shots.rng.randf() < 0.5 else -1.0)
	var sp := CombatRules.spread(skill, "stand", loco.motion != "idle") + _spread_add
	if smoke_at.is_valid() and smoke_at.call(loco.logical, "gas") and not cmb.robot and not cmb.big:
		sp *= 1.3                                                    # 최루(SD-13 W-058): 인간형 명중 −30%
	var ang := CombatRules.shot_angle(aim, sp, shots.rng)
	var wf := weapon if not frenzied else weapon.merged({"dmg": float(weapon.get("dmg", 5.0)) * 1.25}, true)   # 광란 피해 +25%
	if shots.fire_weapon(loco.logical + Vector2(0, -14) + Vector2.RIGHT.rotated(deg_to_rad(aim)) * 10.0, ang, cmb.team, wf, skill,
			{"speed": 640.0, "fl": floor_id, "target": seen}) > 0:      # 1-9a: 무기 계열대로(산탄·화염·곡사…), 실탄은 20t/초로 읽히게
		shots_fired += 1
		if auto:                                                     # 연사: 최대 연사로 0.6~1.2초 점사 → 0.5~1.0초 쉼(§7.4)
			_cool = 1.0 / float(weapon["rate"])
			if _burst_on <= 0.0:
				_burst_on = shots.rng.randf_range(0.6, 1.2)
			return
		_cool = 1.0 / (float(weapon["rate"]) * 0.6)                  # semi-auto: 60% of max rate
		_burst += 1
		if _burst >= 3:                                               # 세 발 쏘면 다시 겨눈다(조준 지연 + 1~1.6초) — 쉬지 않고 쏘면 Lv1 주인공이 6초에 쓰러진다
			_burst = 0
			_cool += 1.0 + shots.rng.randf() * 0.6


## 진압봉(보안요원): 닿는 거리에서 반응 지연 뒤 휘두른다. 주인공에게는 HP 피해만(붙잡힘 판정은 진행기)
var swing_t := 0.0                            ## 휘두르는 그림 남은 초(그리기)


func _swing(dt: float, target: Combatant) -> void:
	_cool = maxf(0.0, _cool - dt)
	_switch_t = maxf(0.0, _switch_t - dt)
	swing_t = maxf(0.0, swing_t - dt)
	if _switch_t > 0.0:
		return
	var to_t := target.pos() - loco.logical
	if _cool > 0.0 or target.dead or not meets(target) or not has_mtoken or to_t.length() > float(weapon.get("range_eff", 1.0)) * 32.0 + target.radius + cmb.radius:
		return
	loco.facing = Locomotion.snap8(to_t, 0.0)
	_show()
	_cool = 1.0 / maxf(0.1, float(weapon.get("rate", 1.0)))
	swing_t = 0.2
	var r := CombatRules.resolve({"weapon": weapon, "skill": skill, "attacker": {"str": 5}, "part": "torso", "dr": target.dr})
	r["hp"] = float(r["hp"]) * _melee_mul * (1.25 if frenzied else 1.0)   # 팔 손상 −30% · 광란 +25%
	target.last_by = cmb.team
	target.take(r, loco.logical)


## 기절: 누운 채 KO_SECS초 → 일어나 마지막으로 본 자리를 수색한다(경보)
func _ko_step(dt: float) -> void:
	if sprite.rotation_degrees != -90.0:
		sprite.rotation_degrees = -90.0
		sprite.position = Vector2(-4, -8)
		sprite.modulate = Color(0.75, 0.75, 0.8)
		z_index = -1
		queue_redraw()
	ko_t -= dt
	if ko_t <= 0.0:
		cmb.ko = false
		cmb.dead = false
		cmb.hp = cmb.max_hp * 0.5
		sprite.rotation_degrees = 0.0
		sprite.position = Vector2.ZERO
		sprite.modulate = Color(1, 1, 1)
		z_index = 0
		brain.state = AIBrain.S.SEARCH
		brain.gauge = AIBrain.SUSPECT_AT
		woke.emit()


signal woke


func _die_step(dt: float) -> void:
	if _wind > 0.0:
		_wind = 0.0
		modulate = Color(1, 1, 1)
	_dead_t += dt
	if style == "swarm" or style == "dog":
		var f := mini(int(_dead_t * 10.0), sprite.sprite_frames.get_frame_count("death_E") - 1)
		sprite.animation = "death_E"
		sprite.frame = f
	elif sprite.sprite_frames.has_animation("death_S"):                # 로봇(1-11c): 불꽃 → 꺾임 → 넘어짐 → 화면 꺼진 채 누움
		var fr := mini(int(_dead_t * 8.0), sprite.sprite_frames.get_frame_count("death_S") - 1)
		sprite.animation = "death_S"
		sprite.flip_h = false
		sprite.frame = fr
		z_index = -1 if fr >= 2 else 0
	elif _dead_t > 0.3:                                              # 사람형(1-4 파밍): 깜박인 뒤 바닥에 눕는다 — 그 자리가 유해(조사하면 소지품)
		sprite.rotation_degrees = -90.0
		sprite.position = Vector2(-4, -8)
		sprite.modulate = Color(0.68, 0.66, 0.7)
		z_index = -1
	else:
		sprite.modulate = Color(3, 3, 3) if int(_dead_t * 20) % 2 == 0 else Color(1, 1, 1)


func _show() -> void:
	super._show()
	if cmb != null and cmb.flash > 0:
		sprite.modulate = Color(4, 4, 4)
	elif cmb != null and not cmb.dead and (frenzied or has_meta("ant_mad")):   # 광란(약물 · 더듬이 손상): 붉게 맥동(§7.2 '붉은 눈 이펙트'를 몸 색조로 키움)
		var k := 0.5 + 0.5 * sin(_clock * 9.0)
		sprite.modulate = Color(1.0 + 0.35 * k, 0.75 - 0.15 * k, 0.72 - 0.15 * k)
	elif cmb != null and not cmb.dead and glow:                         # 빛나는 구울: 몸이 녹빛으로 맥동(오라와 같은 박자)
		var k := 0.5 + 0.5 * sin(_clock * 5.0)
		sprite.modulate = Color(0.95 + 0.08 * k, 1.08 + 0.17 * k, 0.82 + 0.06 * k)
	elif cmb != null and not cmb.dead:
		sprite.modulate = Color(1, 1, 1)
	if _aura != null:
		_aura.visible = cmb != null and not cmb.dead
		_aura.region_rect = CombatFx.region("aura_rad", 0.0, int(_clock / 0.1) % 4)


func _draw() -> void:
	if cmb.dead and not cmb.ko:
		return
	if cmb.ko:
		draw_string(ui_font, Vector2(-8, -24), "zZ", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("8e9ba8"))
		return
	if _ring_t >= 0.0:                                              # 방사능 폭발 고리: 0.5초에 반경 4t까지 퍼진다(바깥 P56 · 안쪽 P57 점선)
		var rr := lerpf(10.0, BURST_R, minf(1.0, _ring_t / 0.5))
		var fade := 1.0 - _ring_t / 0.5
		draw_arc(Vector2(0, -8), rr, 0.0, TAU, 48, Color(0.486, 0.839, 0.169, 0.85 * fade), 2.0)
		for i in 24:
			if i % 2 == 0:
				var a0 := i * TAU / 24.0 + _ring_t * 2.0
				draw_arc(Vector2(0, -8), rr - 3.0, a0, a0 + TAU / 48.0, 3, Color(0.83, 1.0, 0.416, fade), 1.0)
	if swing_t > 0.0:                                              # 진압봉 휘두름: 앞쪽 호 한 획
		var f: Vector2 = Locomotion.VEC[loco.facing].normalized()
		draw_arc(Vector2(0, -12) + f * 8.0, 10.0, f.angle() - 0.9, f.angle() + 0.9, 6, Color("E9E4D8"), 2.0)
	var top := -float(meta["foot"][1]) + (14.0 if style != "swarm" and style != "dog" else 6.0)
	if say_t > 0.0 and say_text != "":                             # 말풍선(§7.2 도주 '살려 줘!' · 항복 · 약물)
		var tw := ui_font.get_string_size(say_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var bp := Vector2(-tw / 2.0 - 3.0, top - 22.0)
		draw_rect(Rect2(bp, Vector2(tw + 6.0, 12.0)), Color(0.96, 0.94, 0.88, 0.92))
		draw_rect(Rect2(bp, Vector2(tw + 6.0, 12.0)), Color("1a181d"), false, 1.0)
		draw_string(ui_font, bp + Vector2(3, 9), say_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("1a181d"))
	if brain.state == AIBrain.S.SURRENDER and not released:         # 항복: 머리 위 흰 천(손 든 자세 그림 전까지)
		draw_line(Vector2(6, top + 6), Vector2(6, top - 10), Color("6b5a44"), 1.0)
		draw_rect(Rect2(Vector2(7, top - 10), Vector2(7, 5)), Color("ECE8DE"))
		draw_line(Vector2(7, top - 5), Vector2(13, top - 5), Color("B8B2A4"), 1.0)
		return
	if frenzied:                                                    # 광란: 붉은 눈(§7.2)
		draw_rect(Rect2(Vector2(-3, top + 9), Vector2(2, 1)), Color("FF3B2A"))
		draw_rect(Rect2(Vector2(1, top + 9), Vector2(2, 1)), Color("FF3B2A"))
	if cmb.held_by("stun") or cmb.held_by("root"):                # 기절·마비: 머리 위 별 · 그물: 엇갈린 줄
		var col := Color("E8C23A") if cmb.held_by("stun") else Color("CBC5B9")
		var k := fmod(_clock * 6.0, TAU)
		for i in 3:
			var a := k + i * TAU / 3.0
			draw_rect(Rect2(Vector2(cos(a) * 6.0 - 1.0, top - 4.0 + sin(a) * 2.0), Vector2(2, 2)), col)
	match brain.state:
		AIBrain.S.SUSPICIOUS, AIBrain.S.SEARCH:
			draw_string(ui_font, Vector2(-3, top - 2), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e8c23a"))
		AIBrain.S.LOST:
			draw_string(ui_font, Vector2(-3, top - 2), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e04a35"))
		AIBrain.S.COMBAT, AIBrain.S.FRENZY, AIBrain.S.FLEE:
			if brain._t_state < 0.8 and brain.state == AIBrain.S.COMBAT:
				draw_string(ui_font, Vector2(-2, top - 2), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e04a35"))
			elif cmb.hp < cmb.max_hp and not hide_bar:
				var w := 16.0
				draw_rect(Rect2(-w / 2, top + 2, w, 2), Color("1a181d"))
				draw_rect(Rect2(-w / 2, top + 2, w * cmb.hp / cmb.max_hp, 2), Color("e04a35"))


## 고가(1-Rd): 표적과의 시야 배수(1 같은 층 · 0.5 다른 층 · 0 못 봄). 상판이 없는 맵은 시선만 본다
func sight_of(target: Combatant) -> float:
	if smoke_at.is_valid() and (smoke_at.call(target.pos(), "smoke") or smoke_at.call(loco.logical, "smoke")):
		return 0.0                                                    # 연막(1-9b, SD-13 W-059): 안팎으로 보이지 않는다(쏘지도 못한다)
	if world is InteriorMap and world.has_deck:
		return world.sight_mul(loco.logical, floor_id, target.pos(), target.fl())
	return 1.0 if world.line_of_sight(loco.logical, target.pos()) else 0.0


## 표적과 같은 층에서 닿나(탄·물기·근접)
func meets(target: Combatant) -> bool:
	return not (world is InteriorMap and world.has_deck) or world.floors_meet(loco.logical, floor_id, target.pos(), target.fl())


# ---------------------------------------------------------------- 1-9e 사기 · 도주 · 항복 · 부위 손상(SD-11 §7.5 · §4.8)
## 지금 자신감: 속성 + 사건 보정 + 분대장(+1) − 몸에 붙은 불(인간형 −1)
func confidence() -> int:
	var c := int(traits.get("conf", 2)) + conf_mod
	if leader_near.is_valid() and bool(leader_near.call()):
		c += 1
	if cmb.dots.has("burn") and style != "dog" and style != "swarm":
		c -= 1
	return c


func can_break() -> bool:
	return morale and who == "" and cmb.hp_floor <= 0.0 and not frenzied and not released


## 사기 판정(인지 틱마다, 교전 · 놓침 중): 약탈자 약물(HP 50% 이하 한 번, 30%) · 자신감별 HP 문턱 → 도주
func _morale(target: Combatant) -> void:
	if not can_break() or not brain.state in [AIBrain.S.COMBAT, AIBrain.S.LOST] or cmb.held():
		return
	var ratio := cmb.hp / maxf(1.0, cmb.max_hp)
	if bool(traits.get("drug", false)) and not _drug_done and ratio <= 0.5:
		_drug_done = true
		if _rng.randf() < 0.3:
			_drug_t = 1.5
			_say("drug")
			return
	if EnemyTraits.should_flee(confidence(), ratio) and ratio <= _rally - 0.15:
		flee_now(target.pos())


func flee_now(from: Vector2, secs: float = -1.0) -> void:
	if not can_break() or brain.fleeing():
		return
	brain.last_seen = from
	brain.flee(secs if secs > 0.0 else _rng.randf_range(10.0, 20.0))
	loco.speed_mul = 0.3 if cmb.crippled.has("leg") else 1.0         # 다리 손상이면 절뚝 도주
	_path = PackedVector2Array()
	_say("flee")
	if cmb.crippled.has("leg"):
		_cornered()


## 같은 편이 쓰러진 걸 봤다(전투 모듈이 12t 안 같은 편에게): 분대장이면 자신감 −1 뒤 다시 판정 · 신중(1) 이하는 바로 도주
func witness_death(at: Vector2, leader: bool) -> void:
	if not can_break() or cmb.dead:
		return
	if leader:
		conf_mod -= 1
	if confidence() <= 1 and brain.state in [AIBrain.S.COMBAT, AIBrain.S.LOST, AIBrain.S.SUSPICIOUS, AIBrain.S.SEARCH]:
		flee_now(brain.last_seen if brain.last_seen != Vector2.ZERO else at)
	elif brain.state == AIBrain.S.COMBAT and EnemyTraits.should_flee(confidence(), cmb.hp / maxf(1.0, cmb.max_hp)):
		flee_now(brain.last_seen)


## 궁지(막힘 1초 · 도주 중 다리 손상): 항복 가능하면 굴려서 항복, 아니면 돌아서서 버틴다(다시 도망치지 않는다)
func _cornered() -> void:
	if float(traits.get("surr", 0.0)) > 0.0 and _rng.randf() < float(traits["surr"]):
		brain.surrender()
		_path = PackedVector2Array()
		_say("surrender", 3.0)
		set_meta("surrendered", true)
	else:
		conf_mod += 4
		brain.gauge = AIBrain.DETECT_AT
		brain.state = AIBrain.S.COMBAT
		loco.speed_mul = 0.5 if cmb.crippled.has("leg") else 1.0


## 도주 경로: 표적 반대쪽 ±60° 안 8t 지점 중 길이 닿는 첫 곳. 없으면 궁지
func _flee_path(target: Combatant, nav) -> void:
	if _path.size() > 0 and _path_i < _path.size():
		return
	var away := (loco.logical - target.pos())
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(_rng.randf() * TAU)
	away = away.normalized()
	for a in [0.0, 0.5, -0.5, 1.0, -1.0]:
		var to := loco.logical + away.rotated(a) * 8.0 * 32.0
		var p: PackedVector2Array = nav.path(loco.logical, to, floor_id, -1)
		if p.size() > 2 and p[p.size() - 1].distance_to(target.pos()) > loco.logical.distance_to(target.pos()):
			_path = p
			_path_i = 1
			return
	_cornered()


## 놓아준 적: 주인공에게서 멀어진다(14t 넘거나 15초면 전투 모듈이 치운다)
var _leave_t := 0.0


var _leave_cd := 0.0                          ## 떠나는 길 다시 찾기까지(0.5초 — 막힌 쪽을 매 프레임 찾지 않게)


## 진행기용 달려가기: 닿으면 'dash_done' 표지. 몸으로 길을 막으면 선다(미끄러지지 않는다) · 다리를 다치면 느려진다(_on_cripple 그대로)
func start_dash(to: Vector2) -> void:
	if dash_to == Vector2.INF:
		_dash_dr = 25.0
		cmb.dr += _dash_dr
	dash_to = to
	_path = PackedVector2Array()
	_dash_cd = 0.0
	if has_meta("dash_done"):
		remove_meta("dash_done")


func end_dash() -> void:
	if dash_to != Vector2.INF:
		cmb.dr -= _dash_dr
		_dash_dr = 0.0
	dash_to = Vector2.INF
	_path = PackedVector2Array()


func _dash(dt: float, nav) -> void:
	mode = "run"
	_dash_cd -= dt
	if loco.logical.distance_to(dash_to) < 20.0:
		set_meta("dash_done", true)
		loco.step(Vector2.ZERO, dt)
		_show()
		return
	if (_path.is_empty() or _path_i >= _path.size()) and _dash_cd <= 0.0:
		_dash_cd = 0.5
		_repath(nav, dash_to)
	var input := dash_to - loco.logical
	if _path_i < _path.size():
		var wp: Vector2 = _path[_path_i]
		if loco.logical.distance_to(wp) < 6.0:
			_path_i += 1
		input = wp - loco.logical
	move(steer(input), dt)


func _leave(dt: float, _target: Combatant, nav) -> void:
	_leave_t += dt
	_leave_cd -= dt
	mode = "walk"
	var from: Vector2 = get_meta("leave_from", loco.logical)            # 놓아준 순간 주인공 자리(대상이 없어진 뒤라 표적은 믿을 수 없다)
	var to: Vector2 = get_meta("leave_to", Vector2.INF)                 # 정해진 출구(진행기 — 바위굴 남쪽 숲길 등)가 있으면 그리로
	if (_path.is_empty() or _path_i >= _path.size()) and _leave_cd <= 0.0:
		_leave_cd = 0.5
		var away := (loco.logical - from).normalized()
		_repath(nav, to if to != Vector2.INF else loco.logical + away * 10.0 * 32.0)
	if to != Vector2.INF and loco.logical.distance_to(to) < 24.0:
		set_meta("gone", true)
	var input := Vector2.ZERO
	if _path_i < _path.size():
		var wp: Vector2 = _path[_path_i]
		if loco.logical.distance_to(wp) < 6.0:
			_path_i += 1
		input = wp - loco.logical
	move(steer(input), dt)
	if _leave_t > 15.0 or loco.logical.distance_to(from) > 14.0 * 32.0:
		set_meta("gone", true)
	queue_redraw()


## 부위 손상(SD-11 §4.8 적 효과): 다리 이동 −50%(도주 중이면 궁지) · 팔 퍼짐 +8° · 근접 −30% · 머리 시야·탐지 −40% · 퍼짐 +3°
func _on_cripple(part: String) -> void:
	match part:
		"leg":
			loco.speed_mul = 0.3 if brain.state == AIBrain.S.FLEE else 0.5
			if brain.state == AIBrain.S.FLEE:
				_cornered()
		"arm":
			_spread_add += 8.0
			_melee_mul = 0.7
		"head":
			_spread_add += 3.0
			per *= 0.6


## 최루 지대 안의 인간형(짐승 · 벌레 · 로봇 · 대형은 무시)
func gassed() -> bool:
	return smoke_at.is_valid() and style != "dog" and style != "swarm" and not cmb.robot and not cmb.big and bool(smoke_at.call(loco.logical, "gas"))


## 1-9e4 생물 특수(매 프레임): 구울 방사능 회복 · 빛나는 구울 폭발 · 들개 우두머리 울부짖기 · 울부짖기 효과 시간
func _specials(dt: float, target: Combatant) -> void:
	buff_t = maxf(0.0, buff_t - dt)
	if _ring_t >= 0.0:
		_ring_t += dt
		if _ring_t > 0.5:
			_ring_t = -1.0
	var id := str(row.get("id", ""))
	if id in GHOULS and rad_at.is_valid() and cmb.hp < cmb.max_hp:  # 라드 100당 HP +1(저항 전 선량 — Z4 웅덩이 25라드/초면 초당 0.25)
		_rad_heal += float(rad_at.call(loco.logical)) * dt / 100.0
		if _rad_heal >= 0.05:
			cmb.hp = minf(cmb.max_hp, cmb.hp + _rad_heal)
			_rad_heal = 0.0
	var fighting := brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY]
	if glow and fighting and burst_cb.is_valid():                   # 빛나는 구울(8초마다): 표적이 4t 안이거나 다친 야생 구울이 곁에 있으면 터뜨린다
		_burst_cd -= dt
		if _burst_cd <= 0.0 and (loco.logical.distance_to(target.pos()) <= BURST_R or bool(burst_cb.call(self, true))):
			_burst_cd = BURST_CD
			_ring_t = 0.0
			burst_cb.call(self, false)
	if id in ["CR-106", "CR-500"] and fighting and howl_cb.is_valid():   # 들개 우두머리(외눈 포함): 교전에 들면 바로, 그 뒤 30초마다
		_howl_cd -= dt
		if _howl_cd <= 0.0:
			_howl_cd = HOWL_CD
			_say("howl", 1.4)
			howl_cb.call(self)
	if nest and not bare and hatch_cb.is_valid():                     # 알집바퀴: 들썩인 동안 10초마다 부화 — 1초 전에 '딸깍'(자리를 알린다)
		if _stir > 0.0:
			_stir -= dt
			_hatch_t += dt
			var hs := MOM_HATCH_S if row["id"] == "CR-501" else HATCH_S
			if _hatch_t >= hs - 1.0 and not _click:
				_click = true
				_say("click", 1.0)
				set_pose("crack")
			if _hatch_t >= hs:
				_hatch_t = 0.0
				_click = false
				set_pose("pulse")
				hatch_cb.call(self)
		elif pose == "crack":
			_click = false
			_hatch_t = 0.0
			set_pose("pulse")
	if id == "CR-097" and fighting and call_cb.is_valid():               # 왕쥐: 교전에 들면 바로, 그 뒤 20초마다 찍찍 — 둘을 부른다
		_howl_cd -= dt
		if _howl_cd <= 0.0:
			_howl_cd = RAT_CALL_CD
			_say("rat_call", 1.2)
			call_cb.call(self)
	_apply_speed()


## 이동 배수 한 곳: 다리 손상(−50%, 도주 중 −70%) × 울부짖기(+15%)
func _apply_speed() -> void:
	var base := (0.3 if brain.state == AIBrain.S.FLEE else 0.5) if cmb.crippled.has("leg") else 1.0
	loco.speed_mul = base * (1.15 if buff_t > 0.0 else 1.0) * (MOLE_UNDER_SPD if burrow == "under" else 1.0)


## 들개 함정 회피(SD-14 §4.2 '지뢰·덫 타일을 50% 확률로 돌아간다'): 앞 2.5t 안, 가는 줄에서 1.75t 안의 남의 지뢰를 옆으로 비켜 간다.
## 굴림은 개체마다 지뢰 하나에 한 번(망설이다 밟는 일 없이 — 돌아가는 개는 끝까지 돌아간다)
func _mine_dodge(input: Vector2) -> Vector2:
	var v := input.normalized()
	for m in mine_list.call():
		if str(m.get("team", "")) == cmb.team:
			continue
		var d: Vector2 = (m["p"] as Vector2) - loco.logical
		if d.length() > 80.0 or v.dot(d) <= 0.0 or absf(v.cross(d)) > 56.0:
			continue
		var key := str(m["p"])
		if not _mine_skip.has(key):
			_mine_skip[key] = _rng.randf() < 0.5
		if not bool(_mine_skip[key]):
			continue
		var side := v.orthogonal()
		if side.dot(d) > 0.0:
			side = -side
		return (v * 0.35 + side).normalized()
	return input


func _say(kind: String, secs: float = 1.6) -> void:
	var opts: Array = SAY.get(kind, [])
	if opts.is_empty():
		return
	say_text = str(opts[_rng.randi() % opts.size()])
	say_t = secs


# ---------------------------------------------------------------- 1-9e2 무기 전환 · 수류탄(SD-11 §7.4)
## 전술 틱(0.5초)마다: 붙으면 근접 무기로(1.6t) · 떨어지면 다시 총으로(2.6t) — 바꾸는 0.6초 동안은 공격하지 않는다.
## 수류탄: 표적이 엄폐 뒤에서 3초 넘게 버티거나(시선 없음 · 웅크려 엄폐 곁) · 근접형이 3~9t에서 처음 붙기 전 — 개체 8초 · 분대 4초.
func _arms_tactics(target: Combatant, d: float, los: bool) -> void:
	if not alt_weapon.is_empty():
		if _main_weapon.is_empty():
			_main_weapon = weapon
		if d <= 1.6 and not on_alt:
			weapon = alt_weapon
			style = "melee"
			on_alt = true
			_switch_t = 0.6
		elif d >= 2.6 and on_alt:
			weapon = _main_weapon
			style = "shooter"
			on_alt = false
			_switch_t = 0.6
	_nade_cd = maxf(0.0, _nade_cd - 0.5)
	var covered := not los or (target.posture == "crouch" and _cover_by(target.pos()))
	_hide_t = _hide_t + 0.5 if covered else 0.0
	if nades <= 0 or _nade_cd > 0.0 or not throw_cb.is_valid() or (squad_ok.is_valid() and not bool(squad_ok.call())):
		return
	if d < 3.0 or d > 9.0 or not meets(target):
		return
	if _hide_t >= 3.0 or (style == "melee" and d >= 3.0):
		nades -= 1
		_nade_cd = 8.0
		_hide_t = 0.0
		_say("nade", 1.2)
		throw_cb.call(loco.logical + Vector2(0, -12), target.pos())


## 표적 둘레 1칸에 엄폐가 있나(웅크려 숨은 자리)
func _cover_by(p: Vector2) -> bool:
	var c := Vector2i(floori(p.x / 32.0), floori(p.y / 32.0))
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if world.cover_at(c + Vector2i(dx, dy)) > 0:
				return true
	return false



# ---------------------------------------------------------------- 1-D3 미끼(SD-13 W-068 썩은 고기)
## 짐승(개 · 쥐 · 바퀴)이 냄새 지대로 가서 먹는다: 교전 전 · 수색 · 놓침이면 10칸 안, 교전 중이면 표적이 6칸 넘게 떨어졌을 때.
## 먹는 동안 멈추고 감지 ×0.4(인지 층) · 지대가 빨리 줄어든다. 처리했으면 true(전술 · 행동 층을 건너뛴다)
func _bait_step(dt: float, target: Combatant, nav) -> bool:
	if not bait_at.is_valid() or not (style == "dog" or style == "swarm") or nest or asleep or brain.fleeing() or cmb.held():
		_end_eat()
		return false
	var fighting := brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY]
	if fighting and not target.dead and loco.logical.distance_to(target.pos()) <= BAIT_FIGHT_R and (has_mtoken or not eating and _bait.is_empty() and bait_at.call(loco.logical, BAIT_R).is_empty()):
		_end_eat()
		return false                                                   # 근접 토큰이 없는 짐승은 10칸 안 미끼에 끌린다(재미 검수 F12 — 미끼로 무리를 떼어 낸다)
	if _bait.is_empty() or float(_bait.get("t", 0.0)) <= 0.0:
		_bait = bait_at.call(loco.logical, BAIT_R)
		if _bait.is_empty():
			_end_eat()
			return false                                               # 미끼가 없으면 길을 그대로 둔다(1-13 D-380 — 전엔 여기서 길을 비워 6칸 밖 교전 짐승이 제자리에 굳었다)
		_path = PackedVector2Array()
	var bp: Vector2 = _bait["p"]
	var to := bp - loco.logical
	if to.length() > 14.0:
		if eating:
			eating = false
			set_pose("stand")
		mode = "run" if fighting else "walk"
		if _path.is_empty() or _path_i >= _path.size():
			_repath(nav, bp)
		var input := to
		if _path_i < _path.size():
			var wp: Vector2 = _path[_path_i]
			if loco.logical.distance_to(wp) < 6.0:
				_path_i += 1
			input = wp - loco.logical
		move(steer(input), dt)
		return true
	if not eating:
		eating = true
		set_pose("eat")
	loco.step(Vector2.ZERO, dt)
	loco.facing = Locomotion.snap8(to if to.length() > 1.0 else Vector2.RIGHT, 0.0)
	_bait["t"] = float(_bait["t"]) - dt * 0.3                          # 여럿이 먹으면 더 빨리 없어진다
	_show()
	return true


## 소리 덮개(1-D3 파리 떼 칸): 표적이 그 안에 서 있으면 감지 ×0.6
func _hush_mul(target: Combatant) -> float:
	return 0.6 if world is InteriorMap and not world.hush.is_empty() and world.hush_at(world.tile_of(target.pos())) else 1.0


func _end_eat() -> void:
	if eating or pose == "eat":
		eating = false
		set_pose("stand")
	_bait = {}


# ---------------------------------------------------------------- 1-D3 굴쥐(SD-14 CR-096 · L423)
## 흙 칸에서만 땅속으로: 땅속은 보이지 않고 무적(움직일 때 흙 둔덕만 보인다) · 표적이 흙 칸(또는 1칸 곁)에 서면 그 발밑으로 와
## 1.0초 들썩임 → 솟으며 물기 18 → 땅 위에서 4초 싸우고 흙이면 다시 판다. 표적이 흙에서 멀면 흙 가장자리에서 나와 땅 위로 쫓는다.
## 흙 칸에 떨어진 미끼는 땅속에서도 맡고 나와 먹는다(땅 위 = 맞는다). 처리했으면 true
func _mole_step(dt: float, target: Combatant, nav) -> bool:
	match burrow:
		"":
			_up_t += dt
			if _up_t >= MOLE_UP_S and not eating and not cmb.held() and _soil_here(loco.logical) and not brain.fleeing() and _dig_pays(target):
				_set_burrow("dig")
				return true
			return false
		"dig":
			_bur_t += dt
			loco.step(Vector2.ZERO, dt)
			if _bur_t >= 0.5:
				_set_burrow("under")
			return true
		"heave":
			_bur_t += dt
			loco.step(Vector2.ZERO, dt)
			if _bur_t >= MOLE_HEAVE_S:
				var bite_now := _bur_goal != Vector2.INF
				_set_burrow("emerge")
				var to := target.pos() - loco.logical
				if bite_now and not target.dead and meets(target) and to.length() <= cmb.radius + target.radius + 1.1 * 32.0:
					loco.facing = Locomotion.snap8(to, 0.0)
					_cool = 1.1
					target.last_by = cmb.team
					target.take({"hp": bite * (1.25 if frenzied else 1.0) * (1.0 - minf(target.dr, CombatRules.DR_CAP) / 100.0)}, loco.logical)   # 발밑에서 솟으며 문다(DR을 거친다)
			return true
		"emerge":
			_bur_t += dt
			loco.step(Vector2.ZERO, dt)
			if _bur_t >= 0.4:
				_set_burrow("")
			return true
		"under":
			return _under_step(dt, target, nav)
	return false


func _set_burrow(b: String) -> void:
	burrow = b
	_bur_t = 0.0
	match b:
		"under":
			cmb.invuln = true
			visible = false
			_soil_route = []
			set_pose("mound")
		"heave":
			cmb.invuln = true
			visible = true
			set_pose("heave")
		"emerge":
			cmb.invuln = false
			visible = true
			set_pose("emerge")
		"dig":
			cmb.invuln = false
			set_pose("dig")
		_:
			cmb.invuln = false
			visible = true
			_up_t = 0.0
			set_pose("stand")


## 다시 파고들 만한가: 싸우는 중이면 표적 곁 흙까지 땅속 길이 이어질 때만(아니면 땅 위로 쫓는다 — 들락날락하지 않게)
func _dig_pays(target: Combatant) -> bool:
	if not brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY] or target.dead:
		return true
	var c := _soil_near(world.tile_of(target.pos()), 1)
	if c.x < 0:
		return false
	var me: Vector2i = world.tile_of(loco.logical)
	return c == me or not _soil_bfs(me, c).is_empty()


func _soil_here(p: Vector2) -> bool:
	return world is InteriorMap and world.soil_at(world.tile_of(p))


## 땅속: 미끼(흙 위) > 교전 중 표적 쪽 흙 > 가만히(보이지 않음)
func _under_step(dt: float, target: Combatant, _nav) -> bool:
	if not (world is InteriorMap) or world.soil_off:
		_set_burrow("")                                               # 흙이 얼었다 — 땅 위로 밀려 나온다
		return false
	var goal := Vector2.INF
	var why := ""
	var z: Dictionary = bait_at.call(loco.logical, BAIT_R) if bait_at.is_valid() else {}
	if not z.is_empty() and _soil_here(z["p"]):
		goal = z["p"]
		why = "bait"
	elif brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY] and not target.dead:
		var c := _soil_near(world.tile_of(target.pos()), 1)
		if c.x >= 0:
			goal = Vector2(c) * 32.0 + Vector2(16, 16)
			why = "bite"
		else:
			c = _soil_near(world.tile_of(target.pos()), 12)
			if c.x >= 0:
				goal = Vector2(c) * 32.0 + Vector2(16, 16)
				why = "edge"
	_bur_goal = goal if why == "bite" else Vector2.INF
	if goal == Vector2.INF:
		visible = false
		loco.step(Vector2.ZERO, dt)
		return true
	if loco.logical.distance_to(goal) < 10.0 or world.tile_of(loco.logical) == world.tile_of(goal):
		visible = false
		loco.step(Vector2.ZERO, dt)
		if why != "bite" or target.pos().distance_to(goal) <= 1.6 * 32.0:
			_set_burrow("heave")                                      # 미끼 · 흙 가장자리 · 발밑: 들썩이고 솟는다
		return true
	_route_t -= dt
	if _soil_route.is_empty() or _route_t <= 0.0:
		_route_t = 0.5
		_soil_route = _soil_bfs(world.tile_of(loco.logical), world.tile_of(goal))
	if _soil_route.is_empty():
		visible = false
		loco.step(Vector2.ZERO, dt)
		if why == "edge" or why == "bite":
			_bur_goal = Vector2.INF
			_set_burrow("heave")                                      # 표적 쪽 흙과 이어지지 않았다(다른 흙 덩이) — 제자리에서 솟아 땅 위로 쫓는다
		return true
	var wp: Vector2 = _soil_route[0]
	if loco.logical.distance_to(wp) < 5.0:
		_soil_route.pop_front()
		if _soil_route.is_empty():
			return true
		wp = _soil_route[0]
	visible = true                                                  # 움직이는 흙 둔덕만 보인다
	mode = "run"
	_apply_speed()
	move(wp - loco.logical, dt)
	return true


## c에서 r칸 안의 가장 가까운 흙 칸(없으면 (-1,-1))
func _soil_near(c: Vector2i, r: int) -> Vector2i:
	if world.soil_at(c):
		return c
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := c + Vector2i(dx, dy)
			if world.soil_at(q):
				var d := Vector2(dx, dy).length_squared()
				if d < bd:
					bd = d
					best = q
	return best


## 흙 칸만 지나는 4방향 너비 우선 길(칸 가운데 점들, 시작 칸 제외). 못 가면 빈 배열
func _soil_bfs(a: Vector2i, b: Vector2i) -> Array:
	if not world.soil_at(a) or not world.soil_at(b):
		return []
	var prev := {a: a}
	var q: Array = [a]
	var n := 0
	while not q.is_empty() and n < 600:
		var c: Vector2i = q.pop_front()
		n += 1
		if c == b:
			var out: Array = []
			while c != a:
				out.push_front(Vector2(c) * 32.0 + Vector2(16, 16))
				c = prev[c]
			return out
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = c + d
			if not prev.has(nx) and world.soil_at(nx) and not world.is_solid(nx):
				prev[nx] = c
				q.append(nx)
	return []


# ---------------------------------------------------------------- 1-D3 알집바퀴(SD-14 CR-004)
## 배수 밸브로 알집이 떠내려갔다: 부화 끝 · 맨몸 그림 · 도망친다
func wash() -> void:
	if bare or cmb.dead:
		return
	bare = true
	_stir = 0.0
	_click = false
	if ResourceLoader.exists("res://assets/sprites/cr_cr004b_loco.tres"):
		sprite.sprite_frames = load("res://assets/sprites/cr_cr004b_loco.tres")
	set_pose("stand")
	nest = false
	brain.flee(12.0)
	_path = PackedVector2Array()


## 어미가 죽어 흩어진다(SD-14 CR-004 '처치 시 주변 큰바퀴 50% 도주') — 사기 규칙과 따로
func scatter_from(at: Vector2, secs: float) -> void:
	if cmb.dead:
		return
	brain.last_seen = at
	brain.flee(secs)
	_path = PackedVector2Array()
