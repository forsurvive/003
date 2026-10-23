## 실내 실시간 전투 (단계 0-7, MQ-P2 사격장·해충 구제): 실내 진행기(InteriorHost)에 붙어 주인공의 무기·조준·사격·재장전·웅크리기(은신)·
## 근접·스팀팩·단축키, 맵의 표적(사격장)과 적(큰바퀴), 일시 동행(하도윤)을 돌린다. 판정은 단계 T의 모듈을 그대로 쓴다:
##   CombatRules(퍼짐·피해·기습 배수) · Projectiles(투사체 40t/초, 엄폐) · Enemy/AIBrain/Perception(적 인지·행동).
## 수치 출처: 무기 SD-13(data/weapons.json), 주인공 HP·AP SD-10 §2.3(data/special.json), 재장전·스팀팩·은신 SD-11 §3.5·§2.7·§9.1.
## 표적(정합 — 문서에 없음, STAGE_0.md 0-7): 소품 target = 한 발에 넘어가는 일반 표적, target_low = 은신 표적(관찰자).
##   은신 표적은 사대(서쪽)를 보고 탐지 게이지(SD-11 §7.3 식, 인지력 5)를 채운다. 낮은 엄폐 뒤에 웅크린 사람은 보지 못한다(§4.2).
##   들키지 않은 채 맞히면 은신 기습(치명 확정 + 원거리 ×2)으로 넘어가고, 들키면 받침 뒤로 숨었다가 3초 뒤 다시 선다.
## 적: 맵 원고의 enemy 줄(cond가 참일 때). 쓰러뜨리면 enemy_killed, 큰바퀴는 바퀴 고기(I-036)를 떨어뜨린다(SD-14 §3.1, 100%).
## 주인공 HP 0 → player_down(프롤로그 특례는 진행 장면이 정한다).
class_name InteriorCombat
extends Node2D

signal target_down(kind: String, sneak: bool, left: int)
signal enemy_killed(id: String, left: int)
signal player_down
signal message(text: String)
signal hurt(amount: float)

const STIMPAK := "I-001"
const SHOT_SPEED := 40.0 * 32.0                   ## 실탄 40t/초(SD-11 §3.3)
const STIM_QUEUE_S := 2.0                         ## 회복 대기열: 한 개를 2.0초에 고르게(SD-11 §2.7)
const STIM_INJECT_S := 0.4                        ## 단축키 사용 투여 모션: 이동 50%·사격 불가
const STEALTH_PER := 5.0                          ## 은신 표적의 인지력(정합)
const STEALTH_RESET_S := 3.0
const DOLL := {"W-065": "bb", "W-067": "pole"}    ## 무기 → 페이퍼돌 손 무기(SD-13 §3.11 형상 차분). 그 밖은 계열로(Arms.doll, 1-9a)

var shots: Projectiles
var pc := Combatant.new()
var weapons := {}                                 ## data/weapons.json
var enemy_rows := {}                              ## data/enemies.json
var weapon_id := ""                               ## 고른 무기("" = 맨손)
var holstered := false                            ## F: 무기 넣기(SD-11 §2.3)
var mags := {}                                    ## 무기 ID -> 탄창에 든 탄 수
var hotkeys := {}                                 ## 1~8 -> 아이템 ID(무기·구호품, SD-12 §3.2)
var reload_t := 0.0
var cool := 0.0
var crouch := false
var since_shot := 999.0                            ## 주인공이 마지막으로 쏜 뒤 지난 초(1-E 인카운터 확률 '30초 안 총성 ×1.4')
var inject_t := 0.0
var heal_q: Array = []                            ## 회복 대기열: 남은 회복량(앞에서부터 2.0초씩)
var heal_rate := 0.0
var enemies: Array = []
var _token_t := 0.0                                ## 공격 토큰 다시 나누기까지 남은 초
var targets: Array = []                           ## [{"prop", "kind": "target"|"stealth", "cmb", "gauge", "seen_t", "down", "facing", "live"}]
var stealth_live := false                         ## 은신 표적을 쓰는 중(사격장 2부) — 아니면 받침 뒤에 숨어 있다
var mates: Companions                             ## 일시 동행(1-10a, SD-11 §8.2): 최대 2명 · 모드 · 기절 · 일으키기
var pc_target: Enemy                              ## 주인공이 마지막으로 공격한 적(동행 엄호의 첫 표적)
## 옛 이름(0-7 MQ-P2 · 1-4 박춘삼): 첫 동행의 몸. null을 넣으면 동행을 모두 뗀다. 몸을 넣으면 그 인물(meta npc_id)을 동행으로
var buddy: Actor:
	get:
		return mates.first_actor() if mates != null else null
	set(v):
		if mates == null:
			return
		if v == null:
			mates.clear()
		else:
			mates.add(str(v.get_meta("npc_id", "")), v, str(v.get_meta("npc_name", "")))
## 옛 이름: 첫 동행의 무기를 바꾼다(퀘스트 자료가 정한 장비)
var buddy_weapon := "W-067":
	set(v):
		buddy_weapon = v
		if mates != null and not mates.list.is_empty() and weapons.has(v):
			mates.list[0]["w"] = weapons[v].duplicate()
var armor_dr := Callable()                         ## 주인공 DR(입은 옷 × 상태, 1-8a) — 호스트가 준다
var nav: InteriorNav
var r_long := false                               ## 재장전 키를 0.6초 넘게 눌렀다(라디오 켜기 · 끄기 — 놓아도 재장전하지 않는다)
var bot := {}                                     ## 봇 입력: {"aim", "fire", "crouch", "reload", "stim"}
var popups: Array = []                            ## [글, 위치, 남은 초, 색]
var lv_fx := -1.0                                 ## 레벨업 빛(1-12p): 지난 초(1.2초 — 발밑 고리 · 오르는 불티, 걸음은 그대로 덧그림만)
var stats := {"shots": 0, "hits": 0, "sneak": 0, "spotted": 0, "stims": 0, "downs": 0, "hurt": 0.0}
var font: Font
var sneak_skill := 0.0
var aim_hold := 0.0                               ## 쏜 뒤 조준 자세를 유지하는 남은 초
var aim_mode := "key"                             ## 조준 장치: mouse(커서 360°) · key(고전 조작: 바라보는 방향 + 자동 조준 원뿔)
const AIM_HOLD_S := 1.0
var _aim_real := false                            ## 조준점이 실제 점(봇·마우스·자동 조준이 잡은 표적)인가 — 아니면 바라보는 방향 그대로 쏜다
var _auto_hit := false
const AUTO_AIM_HALF := 15.0                       ## 고전 조작 자동 조준 반각(SD-11 §2.3 '원뿔 30°', 조준 보정 반각 15°)
var _rng := RandomNumberGenerator.new()
## 1-9a 무기 계열
var ap := APPool.new(5)                            ## 행동력(SD-11 §5): 파워 공격·(구르기·질주는 호스트)
var _spin := 0.0                                  ## 회전 기관포 예열(누르고 있는 초)
var _recoil := 0.0                                ## 돌격소총 반동 누적(°, 최대 +4)
var _recoil_t := 0.0
var _charge := -1.0                               ## 근접 누르는 중(초) — 0.5초면 파워 공격. -1 = 누르지 않음
var power_hits := 0                               ## 시험용: 파워 공격 횟수
var ord: Ordnance                                 ## 투척·설치(1-9b): 수류탄 · 지뢰 · 지대
var hazards: Hazards                              ## 함정 · 환경 폭발(1-9c)
var disarm_prog := -1.0                           ## 그리기: 해체 진행(0~1, -1 = 아님)
var _disarm: Dictionary = {}                      ## 해체 중인 지뢰
## 1-9d 방사능
var rad: RadField                                 ## 지대 근원(맵 rad 줄 · 월드 고리 · 웅덩이 · 드럼 · 임시 지대 · 열린 차폐 용기)
var rad_items := {}                               ## 아이템 표(옷의 방사능 저항) — 호스트가 준다
var rad_dose := 0.0                               ## 선 자리의 초당 라드(저항 전)
var rad_rate := 0.0                               ## 저항 뒤 초당 라드(선량계 · 0이면 계기를 숨긴다)
var rad_shake := 0.0                              ## 단계가 오른 순간 선량계 바늘 흔들림(초)
var rad_stage := 0
var _rad_t := 0.0
const NUKE_RAD := {"r": 4.0, "t": 20.0, "rad": 8.0}  ## 핵 투사기 폭심 지대(SD-11 §9.2 표)
var colony: AntColony
## 1-9e3 AP 행동(SD-11 §5.3): 질주 · 회피 구르기 · 집중 사격 + 저격 스코프 안정(§3.4)
var sprint_want := false                          ## 호스트: 질주 키(또는 터치 링 밖 0.3초)를 누르고 움직이는 중
var sprinting := false
var _sprint_latch := false                        ## 숨이 차 끝난 질주: 키를 뗄 때까지 다시 못 뛴다
var _sprint_snd := 0.0
var focus_t := -1.0                               ## 집중 사격 조준 중(0.3초) — -1 = 아님
var focus_req := false                            ## 터치 '집중' 단추
var aim_held := false                             ## 정조준을 누르고 있다(카메라 리드 3 → 4칸)
var scope_t := 0.0                                ## 저격 계열 정조준 · 멈춘 채 누른 초(0.6초면 안정)
const FOCUS_AIM := 0.3
const SCOPE_S := 0.6


func _init() -> void:
	z_index = 6
	_rng.seed = 2268
	font = load("res://assets/fonts/Galmuri9.ttf")
	weapons = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	if FileAccess.file_exists("res://data/weapons_craft.json"):                # 제작 무기 W-153~157(1-8c, SD-13 §3.10)
		weapons.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons_craft.json")))
	_load_throwables()                                                 # 투척·설치 W-057~W-064 + 제작 폭발물 W-151 · W-152(1-9b)
	Gear.expand_weapons(weapons)                                       # 상태 변형 "W-002@2"(1-8a): 같은 수치 + condition
	enemy_rows = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	shots = Projectiles.new()
	add_child(shots)
	mates = Companions.new(self)
	ord = Ordnance.new()
	ord.shots = shots
	add_child(ord)
	hazards = Hazards.new()
	add_child(hazards)
	hazards.bind(shots, ord, weapons)
	rad = RadField.new()
	add_child(rad)
	colony = AntColony.new()                                           # 1-D5b 왕개미 군체(냄새 길 · 위장 · 분사 · 여왕) — 냄새 길이나 왕개미가 있는 맵에서만 일한다
	add_child(colony)
	rad.bind(ord, hazards)
	shots.nuked.connect(func(at: Vector2) -> void:
		ord.zones.append({"p": at, "r": NUKE_RAD["r"] * 32.0, "t": NUKE_RAD["t"], "t0": NUKE_RAD["t"], "kind": "rad", "team": "env",
			"w": {"rad": NUKE_RAD["rad"]}}))
	pc.team = "player"
	pc.died.connect(func() -> void:                                    # Combatant.take가 HP 0에서 dead를 세우고 died를 낸다
		heal_q.clear()
		player_down.emit())


## 투척·설치 자료를 무기 표에 넣는다(투척 0.65회/초 · 설치 0.5회/초, SD-11 §3.2). 사거리는 던질 때 6 + ⌊힘/2⌋
func _load_throwables() -> void:
	var rows := {}
	if FileAccess.file_exists("res://data/throwables.json"):
		rows.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/throwables.json")))
	if FileAccess.file_exists("res://data/items_craft.json"):
		var cr: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items_craft.json"))
		for id in cr:
			if cr[id].get("explosive", false) and cr[id].has("kind"):
				rows[id] = cr[id]
	for id in rows:
		var r: Dictionary = rows[id].duplicate()
		var mine := str(r.get("kind", "")) == "mine"
		r["family"] = "mine" if mine else "thrown"
		r["layer"] = "X02" if mine else "X01"
		r["skill"] = "폭발물"
		r["rate"] = 0.5 if mine else 0.65
		r["range_eff"] = 0.0 if mine else 6.0
		r["range_max"] = r["range_eff"]
		r["two_handed"] = false
		r["sound"] = "melee"
		r["ammo_id"] = ""
		r["price"] = r.get("price", r.get("value", 0))
		r["durability"] = "∞"
		weapons[id] = r


## 주인공 최대 HP·AP(SD-10 §2.3): 레벨 1 = special.json의 hp_lv1(지구력), ap_max(민첩성)
static var _special := {}


static func derived(st: StoryState) -> Dictionary:
	if _special.is_empty():
		_special = JSON.parse_string(FileAccess.get_file_as_string("res://data/special.json"))
	var sp: Dictionary = _special
	var en := str(clampi(st.stat_base("EN"), 1, 10))                   # 일시적 지구력 감소(방사능)는 최대 HP를 깎지 않는다(SD-11 §11.2)
	var ag := str(clampi(st.stat("AG"), 1, 10))
	var lv := Perks.level(st)                                           # 레벨업 최대 HP +10(SD-10 §4.2) · 라이프 기버 +30 · 액션 보이 AP +25(1-12p)
	return {"hp_max": float(sp[en]["hp_lv1"]) + (lv - 1) * 10.0 + Perks.hp_bonus(st), "ap_max": float(sp[ag]["ap_max"]) + Perks.ap_bonus(st)}


## 레벨업 · 퍽으로 최대 HP · AP가 바뀌었다: 늘어난 만큼 지금 HP도 늘린다(§4.2 '현재 HP도 +10'), 줄면 넘친 만큼만 깎는다
func refresh_pc(st: StoryState) -> void:
	if st == null:
		return
	var mx: float = derived(st)["hp_max"]
	if mx != pc.max_hp and pc.max_hp > 0.0:
		pc.hp = minf(mx, pc.hp + maxf(0.0, mx - pc.max_hp))
		pc.max_hp = mx
	ap.max_ap = APPool.max_for(st.stat("AG"), Perks.ap_bonus(st))
	ap.ap = minf(ap.ap, ap.max_ap)


const RESPAWN_DAYS := 3                           ## 셀 단위 리스폰 72게임시간(SD-14 §11.3) — 게임 날짜(06:00 하루 판정)로 센다


## 이 자리 적이 다시 설 때가 됐나: 쓰러진 기록이 없거나, 우두머리가 아니고 3일이 지났다
static func respawn_due(st: StoryState, key: String) -> bool:
	if not st.boxes.has(key):
		return true
	var r: Dictionary = st.boxes[key]
	if bool(r.get("boss", false)):
		return false
	return int(st.vars.get_v("GAME_DAY")) - int(r.get("day", 0)) >= RESPAWN_DAYS


## 맵이 바뀌었다: 표적·적을 새 맵에서 다시 만든다(주인공 HP는 그대로)
func on_map(map: InteriorMap, player: Actor, st: StoryState) -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	_calm_alias.clear()
	_beast_n = 0
	_hand_auto.clear()
	residents.clear()
	allies.clear()
	targets.clear()
	shots.shots.clear()
	shots.world = map
	shots.ento_said = false
	shots.perk_note = func(t: String, at: Vector2) -> void: _pop(t, at, Color("E8C23A"))
	ord.nades.clear()
	ord.mines.clear()
	ord.zones.clear()
	_disarm = {}
	hazards.setup(map, st)
	rad.setup(map, st)
	rad_stage = Radiation.stage(Radiation.rads(st))
	_rad_t = 0.0
	for row in map.data.get("mines", []):                              # 맵에 깔린 지뢰(적 편, 1-9c 배치)
		if InteriorMap._cond_ok(str(row.get("cond", "")), st) and weapons.has(str(row.get("id", "W-063"))):
			ord.lay(Vector2(int(row["x"]) * 32 + 16, int(row["y"]) * 32 + 16), weapons[str(row.get("id", "W-063"))])
	nav = InteriorNav.new(map)
	pc.actor = player
	pc.radius = player.radius_px
	pc.dead = false
	buddy = null
	if st != null:
		var mx: float = derived(st)["hp_max"]
		if pc.max_hp != mx:
			pc.hp = mx if pc.max_hp <= 0.0 or pc.hp >= pc.max_hp else minf(pc.hp, mx)
			pc.max_hp = mx
	for p in map.props:
		if p["name"] in ["target", "target_low"]:
			var c := Combatant.new()
			c.team = "target"
			c.hp = 1.0
			c.max_hp = 1.0
			c.radius = 9.0
			c.weights = {"torso": 1}
			c.actor = _Pos.new(Vector2(int(p["x"]) * 32 + 16, int(p["y"]) * 32 + 16))
			var t := {"prop": p, "kind": "stealth" if p["name"] == "target_low" else "target", "cmb": c, "gauge": 0.0,
				"seen_t": 0.0, "down": false, "facing": Vector2.LEFT, "live": true}
			targets.append(t)
	set_stealth_live(stealth_live)
	for row in map.data.get("enemies", []):
		if InteriorMap._cond_ok(str(row.get("cond", "")), st):
			var key := "kill:%s:%d,%d" % [str(map.data.get("id", "")), int(row["x"]), int(row["y"])]
			if str(row.get("who", "")) == "" and st != null and (not respawn_due(st, key) or (st.boxes.has(key) and Dungeon.keeps_dead(st, str(map.data.get("id", ""))))):
				continue                                                      # 1-D0: 쓰러뜨린 자리는 72게임시간(3일) 동안 비어 있다 · 우두머리는 다시 서지 않는다(SD-14 §11.3) · 정리한 던전은 다시 서지 않는다(재입주는 따로)
			var e0 := spawn(str(row["id"]), Vector2(int(row["x"]) * 32 + 16, int(row["y"]) * 32 + 16), map, st, row)
			if str(row.get("who", "")) == "":
				e0.set_meta("spawn_key", key)
				if bool(row.get("boss", false)):
					e0.set_meta("boss", true)
	if st != null:                                                     # 1-D0 재입주: 정리한 던전에 30일 뒤 다른 무리가 든다(사람 먼저)
		for row in Dungeon.refill_rows(st, str(map.data.get("id", "")), _rng):
			var e1 := spawn(str(row["id"]), Vector2(int(row["x"]) * 32 + 16, int(row["y"]) * 32 + 16), map, st, row)
			e1.set_meta("spawn_key", str(row["refill_key"]))
	_rebuild_list()
	colony.setup(map, self, st)
	if st != null:
		ap.max_ap = APPool.max_for(st.stat("AG"), Perks.ap_bonus(st))
		ap.ap = minf(ap.ap, ap.max_ap)
	_doll()


## 은신 표적 켜기·끄기(사격장 1부에는 받침 뒤에 숨겨 둔다)
func set_stealth_live(on: bool) -> void:
	stealth_live = on
	for t in targets:
		if t["kind"] == "stealth" and not t["down"]:
			t["live"] = on
			t["gauge"] = 0.0
			t["seen_t"] = 0.0
			_prop_state(t, "" if on else "duck")


## 적 무기(정합, 0-9): 보안요원 진압봉 W-041 · 권총 W-002, 계엄군은 생포 사격(W-002 판정을 빌린다), 파워 아머는 그 세 배 연사
func _enemy_weapon(enemy_id: String, arm: String) -> Dictionary:
	if enemy_id in ["CR-002", "CR-001"] or enemy_id in Enemy.DOGS:
		return {}
	var w: Dictionary = weapons.get("W-041" if arm in ["baton", "claw"] else "W-002", {}).duplicate()
	if arm == "claw" or (arm == "baton" and enemy_id == "CR-205"):      # 야생 구울(1-4) · 역무원 구울 경광봉: 맨손 내려치기 — 피해는 SD-14 표 '근접 n'
		var row: Dictionary = enemy_rows.get(enemy_id, {})
		w["dmg"] = float(str(row.get("attack", "근접 5")).get_slice(" ", 1))
		w["crit_dmg"] = w["dmg"]
		w["name"] = "경광봉" if enemy_id == "CR-205" else "맨손"           # 역무원 구울은 경광봉 12 · 침수 구울은 근접 18(SD-14 표 — 전엔 권총을 쐈다)
		w["rate"] = 0.8                                             # 한 번 내려치고 숨 고르기(떼로 붙으면 초당 30 안팎 — 1.4면 3초 만에 쓰러졌다)
	if enemy_id == "CR-405":
		w["rate"] = float(w.get("rate", 2.0)) * 3.0
	if enemy_id == "CR-305":                                          # 파수-3(1-11c): 손 레이저 — 레이저 권총 판정(SD-14 §8.2 '3정 레이저'는 연사로)
		w = weapons.get("W-008", w).duplicate()
		w["rate"] = float(w.get("rate", 2.0)) * 1.3
	if enemy_id == "CR-320":                                          # 감시포 1형: 기관총 5 연사(회전이 느려 바로 아래가 사각 — 제자리)
		w["dmg"] = 5.0
		w["crit_dmg"] = 5.0
		w["rate"] = float(w.get("rate", 2.0)) * 3.0
		w["name"] = "감시포 기관총"
	if enemy_id == "CR-466":                                          # 계단마을 자경단원(1-X, SD-14 §9.12): 사냥총 · 산탄총 — 자리마다 고정(같은 사람은 같은 총)
		w = weapons.get("W-014" if hash(arm + str(enemy_id)) % 2 == 0 else "W-027", w).duplicate()
	if enemy_id == "CR-472":                                          # 정착지 민병: 권총
		w = weapons.get("W-002", w).duplicate()
	if enemy_id in ["CR-436", "CR-534"]:                               # 기관단총(0-10 정합: 무기 표에 아직 없어 W-002 판정 + 연사 1.5배)
		w["rate"] = float(w.get("rate", 2.0)) * 1.5
	return w


signal enemy_down(e: Enemy)

## 빛나는 구울 방사능 폭발(SD-14 CR-202): 반경 4t — 사람 · 짐승 · 아군 피해 5 + 방사능 5/초 2초(임시 방사능 지대),
## 같은 반경의 야생 구울 HP +30%('먼저 잡아야 하는 적'). probe = 다친(70% 이하) 야생 구울이 곁에 있나만 묻는다
func _glow_burst(e: Enemy, probe: bool) -> bool:
	var at := e.loco.logical
	if probe:
		for o in enemies:
			if is_instance_valid(o) and o != e and not o.cmb.dead and str(o.get_meta("enemy_id", "")) in Enemy.FERALS \
					and o.cmb.hp < o.cmb.max_hp * 0.7 and o.loco.logical.distance_to(at) <= Enemy.BURST_R:
				return true
		return false
	for o in enemies:
		if not is_instance_valid(o) or o == e or o.cmb.dead or o.loco.logical.distance_to(at) > Enemy.BURST_R:
			continue
		var oid := str(o.get_meta("enemy_id", ""))
		if oid in Enemy.FERALS:
			o.cmb.hp = minf(o.cmb.max_hp, o.cmb.hp + o.cmb.max_hp * 0.3)
		elif not oid in Enemy.GHOULS and o.cmb.team != e.cmb.team and not o.cmb.robot:
			o.cmb.last_by = e.cmb.team
			o.cmb.take({"hp": 5.0}, at)
	if not pc.dead and pc.pos().distance_to(at) <= Enemy.BURST_R:
		pc.last_by = e.cmb.team
		pc.take({"hp": 5.0}, at)
	ord.zones.append({"p": at, "r": Enemy.BURST_R, "t": 2.0, "kind": "rad", "team": e.cmb.team, "w": {"rad": 5.0}, "skill": 0.0})
	stats["bursts"] = int(stats.get("bursts", 0)) + 1
	return true


## 들개 우두머리 울부짖기(SD-14 CR-106): 12t 안 같은 편 들개 — 20초 속도 +15% · 물기 +20%(쿨 30초). 듣고 깬다
func _howl(e: Enemy) -> void:
	for o in enemies:
		if is_instance_valid(o) and not o.cmb.dead and o.style == "dog" and o.cmb.team == e.cmb.team \
				and o.loco.logical.distance_to(e.loco.logical) <= 12.0 * 32.0:
			o.buff_t = Enemy.HOWL_BUFF
			o.wake()
			if o.brain.state != AIBrain.S.COMBAT and o != e:
				o.hear("pistol", e.loco.logical)
	stats["howls"] = int(stats.get("howls", 0)) + 1

## 왕쥐 찍찍 울음(SD-14 CR-097, 1-11d): 12t 안 같은 편 시궁쥐 가운데 아직 싸우지 않는 둘을 깨워 부른다. 새 쥐를 만들지 않는다(재미 검수 —
## 수가 정해져 있어 밖에서 먼저 잡아 두는 꼼수가 산다). 부를 쥐가 없으면 '대답이 없다' — 왕쥐는 물러난다(SD-14 §4.1 무리 절반 이상 잃으면 후퇴)
func _rat_call(e: Enemy) -> void:
	var woke := 0
	for o in enemies:
		if woke >= 2:
			break
		if is_instance_valid(o) and o != e and not o.cmb.dead and str(o.row.get("id", "")) == "CR-095" and o.cmb.team == e.cmb.team \
				and o.brain.state != AIBrain.S.COMBAT and o.loco.logical.distance_to(e.loco.logical) <= 12.0 * 32.0:
			o.wake()
			o.hear("pistol", e.loco.logical)
			woke += 1
	var left := enemies.filter(func(o): return is_instance_valid(o) and o != e and not o.cmb.dead and str(o.row.get("id", "")) == "CR-095" and o.cmb.team == e.cmb.team)
	if woke == 0 and left.is_empty():
		message.emit("찍찍… 대답이 없다. 왕쥐가 물러선다.")
		e.brain.state = AIBrain.S.FLEE
	stats["rat_calls"] = int(stats.get("rat_calls", 0)) + 1


## 알집바퀴 부화(SD-14 CR-004): 배 끝 뒤쪽에 큰바퀴 1~2 — 이 어미가 깐 산 큰바퀴가 6이면 멈춘다. 갓 깬 큰바퀴는 들썩인 소리 쪽으로 간다.
## 경험치 · 바퀴 고기는 없다(끝없이 깨는 것을 잡아 키우지 못하게 — 처치 기록도 남기지 않는다)
func _hatch(e: Enemy) -> void:
	var map: InteriorMap = shots.world if shots.world is InteriorMap else null
	if map == null:
		return
	var mine := enemies.filter(func(o): return is_instance_valid(o) and not o.cmb.dead and int(o.get_meta("mother", 0)) == e.get_instance_id())
	var born := 3 if str(e.row.get("id", "")) == "CR-501" else 1 + (1 if _rng.randf() < 0.5 else 0)   # 배수구 어미는 셋(SD-14 CR-501)
	var n := mini(born, Enemy.HATCH_MAX - mine.size())
	var back := Vector2(1.0 if e.sprite.flip_h else -1.0, 0.0)
	for i in n:
		var p := e.loco.logical + back * 22.0 + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-8, 8))
		if map.is_solid(map.tile_of(p)):
			p = e.loco.logical
		var r := spawn("CR-002", p, map, null, {"morale": false})
		r.set_meta("mother", e.get_instance_id())
		r.hear("pistol", pc.pos() if not pc.dead else e.loco.logical)
	stats["hatched"] = int(stats.get("hatched", 0)) + maxi(0, n)


## 1-9e2 적 무기(SD-14 주무기 글 → SD-13 무기 ID, SD-11 §7.4): 길 위 조우 · 생성 건물 적만 — 진행기가 세운 적은 다듬어 둔 장비 그대로(1막 이야기 전투 밸런스)
const ENEMY_ARMS := {
	"CR-420": [["W-005", 0.6], ["W-001", 0.4]],                        # 낡은 권총 / 개조 권총
	"CR-421": [["W-014", 0.4], ["W-025", 0.3], ["W-017", 0.3]],         # 사냥총 / 산탄총 / 자동소총
	"CR-422": [["W-018", 0.4], ["W-029", 0.3], ["W-015", 0.3]],         # 자동소총 / 전투 산탄총 / 기관단총
	"CR-423": [["W-047", 0.35], ["W-040", 0.35], ["W-046", 0.3]],       # 야구방망이 / 쇠파이프 / 각목(+ 파편 수류탄)
	"CR-401": [["W-018", 0.75], ["W-023", 0.25]],                       # 돌격소총 / 레이저 소총
	"CR-456": [["W-017", 0.6], ["W-028", 0.4]],                         # 자동소총 / 산탄총
	"CR-457": [["W-029", 1.0]],                                         # 전투 산탄총(+ 소방 도끼)
}
## 손 맵 · 진행기 · 길 위 조우가 세운 사람 적(밸런스 첫 전수 — 조율사 5번, SD-14 주무기): Lv6 이상만 · 한 편 연사 무기는 셋에 한 정까지 —
## [연사 무기, 반자동 대신](반장은 둘 다 연사 — 조율사). Lv5 이하(MQ-101 독사 · 추적조)와 계엄군 CR-401 · 402('생포 사격' 설계)는 그대로 10mm 권총
const HAND_ARMS := {"CR-436": ["W-015", "W-028"], "CR-437": ["W-017", "W-004"], "CR-438": ["W-017", "W-017"], "CR-452": ["W-017", "W-008"], "CR-534": ["W-015", "W-004"]}
var _hand_auto := {}                                                   ## "맵:편" -> 지금까지 세운 손 맵 사람 수(셋째마다 연사 하나)
const ENEMY_ALT := {"CR-457": "W-049"}                                  ## 붙으면 바꿔 드는 근접 무기
const ENEMY_NADES := {"CR-423": ["W-060", 1], "CR-401": ["W-058", 1]}   ## 수류탄(계엄 '기절탄'은 자료가 없어 최루탄으로 — 정합)
var _team_nade := {}                                                  ## 편 -> 마지막 수류탄 시각(분대 재사용 4초)
var _clock := 0.0


## 손 맵 사람 적 무기: 그 맵 · 편에서 세운 순서로 첫째 · 넷째 · 일곱째…만 연사(셋에 하나), 나머지는 반자동(같은 순서면 같은 무기)
func _hand_arm(enemy_id: String, _pos: Vector2, team: String, map: InteriorMap) -> Dictionary:
	var k := "%s:%s" % [str(map.data.get("id", "")), team]
	var n := int(_hand_auto.get(k, 0))
	_hand_auto[k] = n + 1
	var wid: String = HAND_ARMS[enemy_id][0] if n % 3 == absi(k.hash()) % 3 else HAND_ARMS[enemy_id][1]   # 맵 · 편마다 누가 연사를 쥘지 다르게(재미 검수 — 늘 첫 사람이 아니게)
	return weapons.get(wid, weapons.get("W-002", {})).duplicate()


## 무기 고르기: 개체 자리로 시드한 굴림(같은 자리 같은 무기 — 다시 열어도 같다)
func _pick_arm(enemy_id: String, pos: Vector2) -> Dictionary:
	var opts: Array = ENEMY_ARMS[enemy_id]
	var r := RandomNumberGenerator.new()
	r.seed = int(pos.x * 131 + pos.y * 977) ^ enemy_id.hash()
	var x := r.randf()
	var acc := 0.0
	for o in opts:
		acc += float(o[1])
		if x <= acc:
			return weapons.get(str(o[0]), {}).duplicate()
	return weapons.get(str(opts[-1][0]), {}).duplicate()


func spawn(enemy_id: String, pos: Vector2, map: InteriorMap, st: StoryState = null, opts: Dictionary = {}) -> Enemy:
	var e := Enemy.new()
	var arm := str(opts.get("arm", "baton" if enemy_id == "CR-473" else ("claw" if enemy_id in ["CR-200", "CR-201", "CR-202", "CR-204", "CR-205", "CR-206"] else "")))
	var generic := bool(opts.get("morale", str(map.data.get("id", "")).begins_with("G-")))   # 길 위 조우 · 생성 건물(1-9e)
	var w := _enemy_weapon(enemy_id, arm)
	var o2 := opts
	if generic and ENEMY_ARMS.has(enemy_id) and not opts.has("arm"):
		w = _pick_arm(enemy_id, pos)
	elif HAND_ARMS.has(enemy_id) and not opts.has("arm") and int(opts.get("lv", enemy_rows[enemy_id].get("level", 1))) >= 6:
		w = _hand_arm(enemy_id, pos, str(opts.get("team", "enemy")), map)
	if str(w.get("kind", "")) == "melee" and arm == "":
		o2 = opts.duplicate()
		o2["arm"] = "melee"
	e.setup_enemy(enemy_rows[enemy_id], w, pos, map, o2)
	if generic and ENEMY_ALT.has(enemy_id):
		e.alt_weapon = weapons.get(ENEMY_ALT[enemy_id], {}).duplicate()
	if generic and ENEMY_NADES.has(enemy_id) and weapons.has(str(ENEMY_NADES[enemy_id][0])):
		e.nade_w = weapons[str(ENEMY_NADES[enemy_id][0])]
		e.nades = int(ENEMY_NADES[enemy_id][1])
		e.throw_cb = func(from: Vector2, to: Vector2) -> void:
			_team_nade[e.cmb.team] = _clock
			ord.throw(from, to, e.nade_w, e.cmb.team, e.skill, 8.0)
		e.squad_ok = func() -> bool: return _clock - float(_team_nade.get(e.cmb.team, -99.0)) >= 4.0
	e.smoke_at = ord.in_zone
	e.cmb.hit.connect(func() -> void:
		if e.cmb.last_by == "player":
			pc_target = e)                                          # 동행 엄호의 첫 표적(§8.2)
	e.rad_at = rad.dose_at                                              # 1-9e4: 구울 방사능 회복 · 빛나는 구울 폭발 · 울부짖기 · 들개 지뢰 회피
	e.burst_cb = _glow_burst
	e.howl_cb = _howl
	e.call_cb = _rat_call
	e.bait_at = ord.bait_near                                          # 1-D3 미끼(W-068) · 알집바퀴 부화
	e.hatch_cb = _hatch
	e.mine_list = func() -> Array: return ord.mines
	e.cmb.robot = enemy_id.begins_with("CR-3")                          # SD-14 CR-3xx = 로봇(관제망 · 드론 · 포탑)
	e.cmb.big = enemy_id == "CR-405"                                    # 파워 아머: 넘어짐 · 그물 · 넉백 면역(SD-11 §9.4)
	e.set_meta("enemy_id", enemy_id)
	e.set_meta("row", opts)
	for f in e.foes.duplicate():                                       # 애니멀 프렌드로 이름이 바뀐 무리(calm…)도 그대로 노린다
		if _calm_alias.has(f) and not _calm_alias[f] in e.foes:
			e.foes.append(_calm_alias[f])
	if st != null and Perks.animal(enemy_id) and Perks.rank(st, "PK-045") >= 1 and "player" in e.foes and str(e.cmb.team).begins_with("enemy"):
		_befriend(e)                                                   # 애니멀 프렌드(PK-045, D-142): 먼저 덤비지 않는다 — 맞으면 그 무리만 싸운다(_provoked)
	e.set_meta("home", pos)
	e.cmb.unaware = func() -> bool: return not e.brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY, AIBrain.S.FLEE] and e.brain.gauge < 100.0
	e.morale = bool(opts.get("morale", str(map.data.get("id", "")).begins_with("G-")))   # 1-9e: 길 위 조우 · 생성 건물만(진행기 적은 끝까지)
	e.leader_near = func() -> bool:                                   # 살아 있는 우리 분대장 12t 안(자신감 +1, SD-11 §7.6)
		for o in enemies:
			if is_instance_valid(o) and o != e and not o.cmb.dead and o.cmb.team == e.cmb.team and bool(o.traits.get("leader", false)) \
					and o.loco.logical.distance_to(e.loco.logical) <= 12.0 * 32.0:
				return true
		return false
	if enemy_id == "CR-405":                                            # '못 이기는 적'(SD-03a §7.4 연출 메모): HP 하한 1, 체력 표시 없음
		e.cmb.hp_floor = 1.0
		e.hide_bar = true
	map.objects.add_child(e)
	enemies.append(e)
	e.cmb.died.connect(func() -> void:
		if e.cmb.robot and not e.cmb.ko and _rng.randf() < 0.3:          # 처치된 로봇의 30%: 원자 전지 소형 폭발(SD-11 §9.3)
			shots.explode.call_deferred(e.loco.logical + Vector2(0, -10), {"blast": 40.0, "proj": "robot", "condition": "new"}, 100.0, "env")
		var by_pc: bool = e.cmb.last_by in ["player", "ally", "", "frenzy"]   # 교전(1-E): 다른 무리가 쓰러뜨린 적은 경험치·카르마가 없다 · 더듬이 광란 개미가 문 적은 주인공 몫(SD-11 §4.8)
		if e.cmb.last_by == "mate":                                     # 동행이 쓰러뜨림(1-10a): 주인공이 HP 30% 이상 깎았을 때만 XP(SD-11 §8.2)
			by_pc = e.cmb.dmg_player >= e.cmb.max_hp * 0.3
		_morale_death(e, by_pc, st)
		if enemy_id in ["CR-004", "CR-501"]:                              # 알집바퀴 · 배수구 어미 처치: 주변(12t) 큰바퀴 50% 도주(SD-14 CR-004)
			for o in enemies:
				if is_instance_valid(o) and o != e and not o.cmb.dead and str(o.row.get("id", "")) == "CR-002" \
						and o.loco.logical.distance_to(e.loco.logical) <= 12.0 * 32.0 and _rng.randf() < 0.5:
					o.scatter_from(e.loco.logical, _rng.randf_range(8.0, 15.0))
		if by_pc:
			stats["downs"] += 1
		if st != null and by_pc:
			if not e.has_meta("xp_given"):
				e.set_meta("xp_given", true)
				st.call_fn("xp", [int(enemy_rows[enemy_id]["xp"])])
			if enemy_id == "CR-002":
				st.call_fn("give", ["I-036", 1])                         # 바퀴 고기 100%(SD-14 §3.1)
			if enemy_id == "CR-082":
				st.call_fn("give", ["M-155", 1])                         # 여왕 페로몬 100%(SD-14 §3.5 드롭)
				message.emit("여왕의 더듬이 밑 분비샘 — 여왕 페로몬을 긁어 담았다.")
			if e.cmb.killed_lethal and enemy_id == "CR-473":             # 보안요원 사살: 카르마 -25(기절은 0, SD-03a §7.4)
				st.call_fn("karma", [-25])
				st.vars.set_v("MQP4_SEC_KO", int(st.vars.get_v("MQP4_SEC_KO")) + 1)
			elif e.cmb.killed_lethal and enemy_id == "CR-401":
				st.vars.set_v("MQP4_BJ_KO", int(st.vars.get_v("MQP4_BJ_KO")) + 1)
		if e.cmb.ko:
			e.ko_t = Enemy.KO_SECS
			_pop("기절", e.loco.logical + Vector2(0, -26), Color("8E9BA8"))
		if e.who == "N-R01-018" and st != null and int(st.vars.get_v("MQP4_KEY")) == 0:   # 무기고 담당 권서준: 무기고 열쇠(0-9 정합)
			st.vars.set_v("MQP4_KEY", 1)
			message.emit("권서준의 허리춤에서 무기고 열쇠를 빼앗았다.")
		if not e.cmb.ko and st != null and e.has_meta("spawn_key"):       # 1-D0 처치 기록(맵 자리 단위 · 저장에 남는다)
			st.boxes[str(e.get_meta("spawn_key"))] = {"day": int(st.vars.get_v("GAME_DAY")), "boss": bool(e.get_meta("boss", false))}
			var mid := str(shots.world.data.get("id", "")) if shots.world != null else ""
			var dmsg := Dungeon.check_clear(st, mid) if bool(e.get_meta("boss", false)) else Dungeon.refill_check(st, mid)
			if dmsg != "":
				message.emit(dmsg)
		if not e.cmb.ko:
			enemy_down.emit(e)                                          # 유해(1-4 파밍): 호스트가 그 자리에 소지품 용기를 둔다
		enemy_killed.emit(enemy_id, alive_enemies()))
	_rebuild_list()
	return e


## 1-9e 사기 사건(SD-11 §7.5 · §7.6): 같은 편 12t 안 목격(분대장이면 자신감 −1) · 무리 우두머리면 50% 무리 도주 ·
## 항복한 적을 쏘아 죽이면 카르마 −10(SD-10 미정 → 1-9e 임시값, 구현 정합 SD-11 §7.5)
func _morale_death(e: Enemy, by_pc: bool, st: StoryState) -> void:
	if e.cmb.ko:
		return
	var at: Vector2 = e.loco.logical
	if by_pc and e.has_meta("surrendered") and e.brain.state == AIBrain.S.SURRENDER and not e.released:
		if st != null:
			st.call_fn("karma", [-10])
		_pop("항복한 자를 쐈다", at + Vector2(0, -28), Color("E04A35"))
	var lead := bool(e.traits.get("leader", false))
	var rout := bool(e.traits.get("pack_lead", false)) and _rng.randf() < 0.5
	for o in enemies:
		if not is_instance_valid(o) or o == e or o.cmb.dead or o.cmb.team != e.cmb.team:
			continue
		var d: float = o.loco.logical.distance_to(at)
		if rout and d <= 20.0 * 32.0 and o.style == "dog":                  # 우두머리를 잃은 무리: 20~30초 흩어진다
			o.flee_now(pc.pos(), _rng.randf_range(20.0, 30.0))
		elif d <= 12.0 * 32.0:
			o.witness_death(at, lead)


## 항복한 적(1.5t 안): 상호작용 = 놓아준다(그 개체는 적대하지 않고 떠난다 — 경험치 없음)
func surrendered_near(p: Vector2) -> Enemy:
	for e in enemies:
		if is_instance_valid(e) and not e.cmb.dead and not e.released and e.brain.state == AIBrain.S.SURRENDER \
				and e.loco.logical.distance_to(p) <= 1.5 * 32.0 + 8.0:
			return e
	return null


func release(e: Enemy) -> void:
	e.released = true
	e.set_meta("leave_from", pc.pos())
	e.foes.clear()
	e.cmb.team = "gone"
	e.brain.state = AIBrain.S.RETURN
	e.say_text = "고, 고맙다…"
	e.say_t = 2.0
	message.emit("놓아줬다. 다시는 덤비지 않을 것이다.")
	_rebuild_list()


## 주민(SD-10 §6.3, 0-9): 맵 인물도 맞는다. 공기총·근접은 기절(비살상), 실총으로 죽이면 진행기가 카르마 −100.
## 프롤로그 불사 4인(윤정인·하도윤·육지환·도경철)은 HP 1에서 멈춘다(무릎). 적의 탄은 주민을 맞히지 않는다.
signal resident_hit(id: String)
signal resident_down(id: String, killed: bool)
const IMMORTAL := ["C-001", "C-002", "C-004", "C-022", "C-003"]   # C-003 남궁혁(1-7 귀빈실 — 4막 MQ-402 전에는 쓰러지지 않는다)
const RESIDENT_HP := 40.0
var residents: Array = []                         ## [{"id", "cmb", "actor"}]


func set_residents(list: Array) -> void:
	residents.clear()
	for n in list:
		var a = n["actor"]
		if not is_instance_valid(a) or n.get("dead", false):
			continue
		var c := Combatant.new()
		c.team = "resident"
		c.actor = a
		c.hp = RESIDENT_HP
		c.max_hp = RESIDENT_HP
		c.can_ko = true
		var id := str(n["id"])
		if id in IMMORTAL:
			c.hp_floor = 1.0
		c.hit.connect(func() -> void: resident_hit.emit(id))
		c.died.connect(func() -> void: resident_down.emit(id, c.killed_lethal))
		residents.append({"id": id, "cmb": c, "actor": a})
	_rebuild_list()


## 아군(0-10 MQ-101 계단 방어): 계단참을 지키는 감시조. 제자리에서 보이는 가장 가까운 적을 쏜다. 주인공 탄은 지나가고, 적 탄은 맞는다.
signal ally_down(id: String)
var allies: Array = []                            ## [{"id", "actor", "cmb", "cool", "weapon"}]


func add_ally(id: String, actor: Actor, hp: float, weapon_id: String = "W-002") -> Combatant:
	var c := Combatant.new()
	c.team = "ally"
	c.actor = actor
	c.hp = hp
	c.max_hp = hp
	c.radius = actor.radius_px
	c.died.connect(func() -> void:
		actor.sprite.rotation_degrees = -90.0
		actor.sprite.position = Vector2(-4, -8)
		actor.sprite.modulate = Color(0.7, 0.7, 0.75)
		_pop("쓰러짐", actor.loco.logical + Vector2(0, -26), Color("E04A35"))
		ally_down.emit(id))
	allies.append({"id": id, "actor": actor, "cmb": c, "cool": 0.5 + _rng.randf(), "weapon": weapons.get(weapon_id, {})})
	_rebuild_list()
	return c


func clear_allies() -> void:
	allies.clear()
	_rebuild_list()


func _allies(dt: float) -> void:
	for a in allies:
		var c: Combatant = a["cmb"]
		if c.dead or not is_instance_valid(a["actor"]):
			continue
		var me: Actor = a["actor"]
		a["cool"] = float(a["cool"]) - dt
		var best: Enemy = null
		var bd := 11.0 * 32.0
		for e in enemies:
			if not is_instance_valid(e) or e.cmb.dead or not e.cmb.team.begins_with("enemy"):
				continue
			var d: float = e.loco.logical.distance_to(me.loco.logical)
			if d < bd and shots.world.line_of_sight(me.loco.logical, e.loco.logical) and e.meets(a["cmb"]):
				bd = d
				best = e
		if best == null:
			continue
		me.loco.facing = Locomotion.snap8(best.loco.logical - me.loco.logical, 0.0)
		me._show()
		if float(a["cool"]) <= 0.0 and not (a["weapon"] as Dictionary).is_empty():
			var w: Dictionary = a["weapon"]
			a["cool"] = 1.0 / (float(w.get("rate", 2.0)) * 0.25) * shots.rng.randf_range(0.8, 1.4)   # 감시조는 아껴 쏜다(초당 1발 안팎)
			var aim := rad_to_deg((best.loco.logical - me.loco.logical).angle())
			var ang := CombatRules.shot_angle(aim, CombatRules.spread(20.0, "stand", false), shots.rng)
			shots.fire(me.loco.logical + Vector2(0, -14) + Vector2.RIGHT.rotated(deg_to_rad(aim)) * 10.0, ang, SHOT_SPEED, "ally", w, 20.0, false, 5, "auto", me.floor_id)


## 적이 노릴 대상: 그 적이 노리는 편(foes — 주인공·아군 · 교전 중이면 다른 무리) 가운데 보이는 가장 가까운 쪽
## (지금 대상은 1.5배 가까운 쪽이 나타날 때까지 유지). 노릴 편이 아무도 없으면 '아무도 아님'(죽은 허수아비)을 준다
func _target_for(e: Enemy) -> Combatant:
	var plain: bool = e.foes.size() == 2 and "player" in e.foes and "ally" in e.foes
	var mb: Array = mates.bodies()
	if plain and allies.is_empty() and mb.is_empty() and _beast_n == 0:
		return pc
	var cand: Array = []
	if "player" in e.foes:
		cand.append(pc)
	if "ally" in e.foes:
		for a in allies:
			if not (a["cmb"] as Combatant).dead:
				cand.append(a["cmb"])
		cand.append_array(mb)                                           # 쓰러진 동행은 표적에서 빠진다(§8.2 기절)
	if not plain or _beast_n > 0:                                       # 내 편 짐승(팀 ally)도 '아군'으로 노린다
		for o in enemies:
			if is_instance_valid(o) and o != e and not o.cmb.dead and o.cmb.team in e.foes:
				cand.append(o.cmb)
	if cand.is_empty():
		return _nobody()
	var cur: Combatant = e.focus if e.focus != null and not e.focus.dead and e.focus in cand else null
	var best: Combatant = cur
	var bd := e.loco.logical.distance_to(cur.pos()) / 1.5 if cur != null else INF
	for c in cand:
		var d := e.loco.logical.distance_to((c as Combatant).pos())
		if d < bd and (c == pc or e.sight_of(c) > 0.0):
			bd = d
			best = c
	e.focus = best if best != null else cand[0]
	return e.focus


var _calm_alias := {}                              ## 애니멀 프렌드: 원래 편 이름 → calm 편 이름(다른 무리가 계속 노리게)
var _beast_n := 0                                  ## 지금 내 편으로 싸우는 짐승 수(애니멀 프렌드 2랭크)
var _beast_t := 0.0


func _befriend(e: Enemy) -> void:
	var old: String = e.cmb.team
	var nt := "calm" + old.trim_prefix("enemy")
	if old == "enemy":                                                 # 맵 기본 편: 무리(같은 계열 · 12칸 안 자리)마다 따로 — 하나를 때리면 그 무리만 덤빈다
		var p: Vector2 = e.loco.logical
		nt = "calm_%s_%d_%d" % [Perks.family(str(e.get_meta("enemy_id", ""))), int(p.x / 384.0), int(p.y / 384.0)]
	e.cmb.team = nt
	e.foes.erase("player")
	e.foes.erase("ally")
	e.set_meta("beast", true)
	if old == "enemy":
		return
	_calm_alias[old] = nt
	for o in enemies:
		if is_instance_valid(o) and o != e and old in o.foes and not nt in o.foes:
			o.foes.append(nt)


## 애니멀 프렌드 2랭크(PK-045): 둘레 10칸 안에서 주인공과 싸우는 사람 · 기계가 있으면 짐승이 내 편으로(동물끼리는 싸우지 않는다).
##   제 자리(나타난 곳)에서 16칸을 넘어가면 멈춰 서서 짖기만 한다 — 끌고 다닐 수 없다(동료 시스템 없음).
##   정착지 경비 · 주민은 적 목록(enemies)이 아니라서 짐승이 덤비지 않는다
func _beast_tick(dt: float, st: StoryState) -> void:
	if st == null or Perks.rank(st, "PK-045") < 2:
		_beast_n = 0
		return
	_beast_t -= dt
	if _beast_t > 0.0:
		return
	_beast_t = 0.5
	var hostile: Array = []
	for o in enemies:
		if is_instance_valid(o) and not o.cmb.dead and "player" in o.foes and not o.has_meta("beast") and str(o.cmb.team).begins_with("enemy") \
				and o.brain.state == AIBrain.S.COMBAT:
			hostile.append(o)
	_beast_n = 0
	for b in enemies:
		if not is_instance_valid(b) or b.cmb.dead or not b.has_meta("beast") or "player" in b.foes:
			continue
		var home: Vector2 = b.get_meta("home", b.loco.logical)
		var teams: Array = []
		var leash: bool = b.loco.logical.distance_to(home) > 16.0 * 32.0
		for o in hostile:
			if o.loco.logical.distance_to(b.loco.logical) <= 10.0 * 32.0 and not o.cmb.team in teams:
				teams.append(o.cmb.team)
		if teams.is_empty() or leash:
			if b.cmb.team == "ally" and not b.foes.is_empty():
				b.foes = []
				if leash and Perks.animal(str(b.get_meta("enemy_id", ""))) and str(b.get_meta("enemy_id", "")) >= "CR-104" and str(b.get_meta("enemy_id", "")) <= "CR-106":
					_pop("컹! 컹!", b.loco.logical + Vector2(0, -30), Color("E9E4D8"))
			continue
		b.cmb.team = "ally"
		b.foes = teams
		b.wake()
		_beast_n += 1


## 노릴 편이 없는 적에게 주는 허수아비(죽어 있어 보지도 쏘지도 않는다)
class _NoLoco:
	var logical := Vector2(-1.0e6, -1.0e6)


class _NoActor:
	var loco := _NoLoco.new()


var _none: Combatant


func _nobody() -> Combatant:
	if _none == null:
		_none = Combatant.new()
		_none.actor = _NoActor.new()
		_none.dead = true
		_none.team = "none"
	return _none


signal provoked(team: String)


## 비적대 무리를 주인공이 때렸다(1-E): 그 무리(같은 편) 모두 주인공을 노린다. 탄도 이제 주인공을 맞힌다
func _provoked() -> void:
	for e in enemies:
		if not is_instance_valid(e) or e.cmb.dead or "player" in e.foes or e.cmb.last_by != "player":
			continue
		var team: String = e.cmb.team
		var nt := "enemy" + team.trim_prefix("calm")
		for o in enemies:
			if is_instance_valid(o) and o.cmb.team == team:
				o.foes.append_array(["player", "ally"])
				o.cmb.team = nt
				o.wake()
		for o in enemies:                                                # 그 무리를 노리던 쪽은 바뀐 편 이름도 노린다
			if is_instance_valid(o) and team in o.foes and not nt in o.foes:
				o.foes.append(nt)
		provoked.emit(team)


func resident(id: String) -> Combatant:
	for r in residents:
		if r["id"] == id:
			return r["cmb"]
	return null


## 맵의 적을 지금 조건대로 다시 본다(연출 명령 refresh, 0-9): 조건이 거짓이 된 적은 치운다(하도윤의 미끼·엄마의 거짓 무전으로 분대가 빠진다)
func refresh_enemies(st: StoryState) -> void:
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var row: Dictionary = e.get_meta("row", {})
		if not InteriorMap._cond_ok(str(row.get("cond", "")), st):
			enemies.erase(e)
			e.queue_free()
	_rebuild_list()


## 적 하나를 전장에서 뺀다(물러남 · 기체에 오름 · 고기에 정신 팔림): 목록과 탄 판정 목록을 함께 고친다
func drop_enemy(e: Enemy) -> void:
	enemies.erase(e)
	if is_instance_valid(e):
		e.queue_free()
	_rebuild_list()


func alive_enemies() -> int:
	return enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead).size()


func targets_left(kind: String) -> int:
	return targets.filter(func(t): return t["kind"] == kind and not t["down"]).size()


func _rebuild_list() -> void:
	var l: Array = [pc]
	for e in enemies:
		if is_instance_valid(e):
			l.append(e.cmb)
	for r in residents:
		if is_instance_valid(r["actor"]):
			l.append(r["cmb"])
	for a in allies:
		if is_instance_valid(a["actor"]):
			l.append(a["cmb"])
	if mates != null:
		l.append_array(mates.bodies())
	for t in targets:
		l.append(t["cmb"])
	shots.combatants = l


func armed() -> bool:
	return weapon_id != "" and weapons.has(weapon_id) and not holstered


func weapon() -> Dictionary:
	return weapons.get(weapon_id, {})


## 무기 고르기. 처음 드는 원거리 무기는 소지 탄약으로 탄창을 채운다
func equip(id: String, st: StoryState) -> void:
	if id != "" and Gear.cond(id) >= 4:                                 # 파손(SD-13 §8.1): 사용 불가 — 고치거나 부품으로 쓴다
		message.emit("부서져서 쓸 수 없다. 고쳐야 한다.")
		return
	weapon_id = id
	holstered = false
	reload_t = 0.0
	if id != "" and weapons.has(id) and weapons[id]["kind"] == "ranged" and not mags.has(id):
		mags[id] = _ammo_take(id, int(weapons[id]["mag"]), st)
	if st != null:
		st.weapon_out = armed()
		st.wielded = id
	_doll()


func _doll() -> void:
	var a: Actor = pc.actor
	if a == null or a.doll == null:
		return
	var w := ""
	if armed():
		w = DOLL.get(Gear.base(weapon_id), Arms.doll(weapon()))
	a.doll.set_look({"weapon": w})


## 탄약(이름이 곧 ID, SD-13 §4.1)에서 n발을 꺼낸다
func _ammo_take(id: String, n: int, st: StoryState) -> int:
	var ammo_id := str(weapons[id].get("ammo_id", ""))
	if ammo_id == "" or st == null:
		return n
	var k := mini(int(st.items.get(ammo_id, 0)), n)
	if k > 0:
		st.call_fn("take", [ammo_id, k])
	return k


func ammo_left(st: StoryState) -> int:
	var ammo_id := str(weapon().get("ammo_id", ""))
	return int(st.items.get(ammo_id, 0)) if ammo_id != "" and st != null else 0


## 단축키 1~8(SD-12 §3.2): 무기면 들고, 구호품이면 쓴다
func hotkey(n: int, st: StoryState) -> void:
	var id: String = hotkeys.get(n, "")
	if id == "" or st == null or int(st.items.get(id, 0)) <= 0:
		return
	if weapons.has(id):
		equip("" if id == weapon_id and not holstered else id, st)
	elif id == STIMPAK:
		use_stimpak(st, true)


## 아이템을 처음 받으면 빈 단축키 칸에 넣는다(무기 1·2…, 스팀팩 3)
func auto_hotkey(id: String) -> void:
	if hotkeys.values().has(id):
		return
	var want := 3 if id == STIMPAK else 1
	for n in range(want, 9):
		if not hotkeys.has(n):
			hotkeys[n] = id
			return


# ---------------------------------------------------------------- 매 프레임(진행기가 부른다)
func tick(dt: float, free: bool, st: StoryState) -> void:
	_st_ref = st
	shots.pc_st = st
	_beast_tick(dt, st)
	var player: Actor = pc.actor
	if player == null:
		return
	nav.new_frame()
	if st != null:
		sneak_skill = float(st.skill("SNEAK"))
	pc.posture = "crouch" if crouch else "stand"                          # 적의 탐지식 입력(SD-11 §7.3, 0-9)
	pc.movement = "still" if player.loco.motion == "idle" else ("sneak" if crouch else "move")
	pc.sneak = sneak_skill
	if armor_dr.is_valid():
		pc.dr = float(armor_dr.call())
	cool = maxf(0.0, cool - dt)
	_clock += dt
	if pc.flash > 0:
		pc.flash -= 1
	if player.doll != null:
		player.doll.set_flash(1.0 if pc.flash > 0 else 0.0)
		if pc.flash == 2:
			player.doll.flash_face("hurt", 0.3)
	var hp0 := pc.hp
	var step := dt if free else 0.0
	_token_t -= step
	since_shot += step
	if _token_t <= 0.0:                                                 # 공격 토큰(SD-11 §7.4, 난이도 보통 원거리 3): 대상에 가까운 사수 셋만 쏜다(편마다 — 1-E 교전)
		_token_t = 1.5
		_provoked()
		var cands := enemies.filter(func(e): return is_instance_valid(e) and e.style == "shooter" and not e.cmb.dead)
		cands.sort_custom(func(a, b): return a.loco.logical.distance_to(_target_for(a).pos()) < b.loco.logical.distance_to(_target_for(b).pos()))
		var per_team := {}
		for i in cands.size():
			var tm: String = cands[i].cmb.team
			per_team[tm] = int(per_team.get(tm, 0)) + 1
			cands[i].has_token = int(per_team[tm]) <= 3
		var mel := enemies.filter(func(e): return is_instance_valid(e) and e.style != "shooter" and not e.cmb.dead and not e.eating)   # 미끼를 먹는 짐승은 토큰을 받지 않는다   # 근접 토큰(SD-11 L907~915): 무리는 둘 · 떼 성향은 넷만 문다(밸런스 첫 전수 — 조율사 1번)
		mel.sort_custom(func(a, b): return a.loco.logical.distance_to(_target_for(a).pos()) < b.loco.logical.distance_to(_target_for(b).pos()))
		var per_m := {}
		for e in mel:
			var swarmy: bool = e.style == "swarm" or str(e.row.get("id", "")) in Enemy.SWARMY
			var mk := "%s:%s" % [e.cmb.team, "s" if swarmy else "p"]
			per_m[mk] = int(per_m.get(mk, 0)) + 1
			e.has_mtoken = int(per_m[mk]) <= (4 if swarmy else 2)
	for e in enemies:
		if is_instance_valid(e):
			var was: bool = e.cmb.flash > 0
			e.think(step, _target_for(e), nav, shots)
			if e.cmb.flash == 2 and not was and e.cmb.last_sneak:
				e.cmb.last_sneak = false
				_pop("기습 치명타 ×%d" % int(CombatRules.sneak_mult("ranged", false)), e.loco.logical + Vector2(0, -22), Color("E8C23A"))
	if free:
		_ap_move(dt, player)
		_status(dt)
		_heal(dt)
		_targets(dt, player)
		mates.tick(dt)
		_allies(dt)
		_radiation(dt, st)
	colony.tick(step)
	for z in ord.zones:                                                 # 불(화염병 · 화염방사기 지대)은 냄새 길을 태운다
		if str(z["kind"]) == "fire" and colony.active:
			colony.erase_at(z["p"], float(z["r"]) / 32.0)
	shots.step(step)
	ord.step(step, shots.combatants)
	hazards.step(step, shots.combatants)
	rad.step(dt, pc.pos())
	if pc.hp < hp0:
		stats["hurt"] += hp0 - pc.hp
		hurt.emit(hp0 - pc.hp)
	for e in enemies.duplicate():                                       # 놓아준 적이 멀어지면 전장에서 뺀다(1-9e)
		if is_instance_valid(e) and e.has_meta("gone"):
			drop_enemy(e)
	for p in popups:
		p[2] -= dt
		p[1] += Vector2(0, -12) * dt
	popups = popups.filter(func(p): return p[2] > 0.0)
	queue_redraw()
	if pc.dead:
		return
	if free:
		_player(dt, player, st)


## 1-9d 피폭(SD-11 §11.2): 0.5초마다 선량 × 0.5 × (1 − 저항), 최소 0.1. 단계가 바뀌면 알림 · 바늘 흔들림 · 최대 AP. 1,000이면 죽는다
func _radiation(dt: float, st: StoryState) -> void:
	if st == null or pc.dead:
		return
	rad_shake = maxf(0.0, rad_shake - dt)
	rad_dose = rad.dose_at(pc.pos())
	var res := Radiation.resist(st, rad_items)
	rad_rate = rad_dose * (1.0 - res) if rad_dose > 0.0 else 0.0
	if rad_dose > 0.0:
		_rad_t += dt
		while _rad_t >= Radiation.TICK:
			_rad_t -= Radiation.TICK
			Radiation.expose(st, rad_dose, res)
	else:
		_rad_t = 0.0
	var r := Radiation.rads(st)
	var s := Radiation.stage(r)
	if s != rad_stage:
		if s > rad_stage and s < 5:
			var pen: Dictionary = Radiation.PEN[s]
			var parts: Array = []
			for k in ["EN", "AG", "ST"]:
				if pen.has(k):
					parts.append("%s −%d" % [StoryState.STATS[k], int(pen[k])])
			message.emit("%s — %s" % [Radiation.NAMES[s], " · ".join(parts)])
			rad_shake = 1.0
		rad_stage = s
		ap.max_ap = APPool.max_for(st.stat("AG"), Perks.ap_bonus(st))
		ap.ap = minf(ap.ap, ap.max_ap)
	if r >= 1000:                                                       # 치사(SD-11 §11.2)
		message.emit("방사능 1,000 라드 — 몸이 버티지 못한다.")
		pc.hp = 0.0
		pc.dead = true
		heal_q.clear()
		pc.died.emit()


## 1-9a 상태 이상 흐름: 지속 피해 틱 · 행동 제한 시간 · 넉백(발이 뜬 이동 — 막히면 거기서 선다, SD-16 §5.4 ⑦)
func _status(dt: float) -> void:
	var all: Array = [pc]
	for e in enemies:
		if is_instance_valid(e):
			all.append(e.cmb)
	for r in residents:
		all.append(r["cmb"])
	for c in all:
		c.tick_status(dt)
		if c.push == Vector2.ZERO or c.dead:
			c.push = Vector2.ZERO
			continue
		var a = c.actor
		var step: Vector2 = c.push.limit_length(240.0 * dt)
		c.push -= step
		if c.push.length() < 0.5:
			c.push = Vector2.ZERO
		if not (a is Actor) or a.world == null:
			continue
		var from: Vector2 = a.loco.logical
		var to: Vector2 = a.world.move_circle(from, from + step, a.radius_px)
		if to.distance_to(from + step) > 0.5:                      # 벽·엄폐에 닿으면 넉백은 거기서 끝(비비지 않는다)
			c.push = Vector2.ZERO
		a.loco.place(to.round() if to.distance_to(from) > 0.0 else from)
	_recoil_t += dt
	while _recoil_t >= 0.3 and _recoil > 0.0:                      # 쏘지 않으면 0.3초마다 1°씩 돌아온다
		_recoil_t -= 0.3
		_recoil = maxf(0.0, _recoil - 1.0)


## 사격 중 중화기는 정조준 이동 속도(3.0t/초)로 걷는다(SD-11 §3.4)
func heavy_slow() -> bool:
	return armed() and Arms.fam(weapon()) == "heavy" and aim_hold > 0.0


func _heal(dt: float) -> void:
	if heal_q.is_empty():
		return
	var amt := minf(heal_rate * dt, float(heal_q[0]))
	pc.hp = minf(pc.max_hp, pc.hp + amt)
	heal_q[0] = float(heal_q[0]) - amt
	if float(heal_q[0]) <= 0.001:
		heal_q.pop_front()
		if not heal_q.is_empty():
			heal_rate = float(heal_q[0]) / STIM_QUEUE_S


func _player(dt: float, player: Actor, st: StoryState) -> void:
	if inject_t > 0.0:
		inject_t -= dt
		return
	if player.rolling() or sprinting:                                 # 구르기 · 질주 중엔 쏘지도 재장전하지도 않는다(§5.3)
		_charge = -1.0
		throw_hold = -1.0
		scope_t = 0.0
		aim_held = false
		if sprinting:
			player.aim_dir = -1                                          # 질주는 전신이 달리는 쪽을 본다
		return
	if pc.held():                                                     # 1-9a: 넘어짐·기절·마비·그물 동안 공격 못 한다
		_charge = -1.0
		return
	if bot.is_empty():
		if Input.is_action_just_pressed("crouch"):
			crouch = not crouch
		if Input.is_action_just_pressed("holster"):
			if weapon_id == "" or weapon_id == Arms.FIST:                 # 빈손이면 주먹을 쥐고 편다(SD-11 §3.4 비무장, 1-9a)
				equip("" if weapon_id == Arms.FIST else Arms.FIST, st)
			else:
				holstered = not holstered
				reload_t = 0.0
				if st != null:
					st.weapon_out = armed()
				_doll()
	else:
		crouch = bot.get("crouch", false)
		if bot.has("weapon") and str(bot["weapon"]) != weapon_id:
			equip(str(bot["weapon"]), st)
		if bot.get("disarm", false):
			disarm_tick(dt, st)
		if bot.get("stim", false):
			bot["stim"] = false
			use_stimpak(st, true)
			return
	if not armed():
		player.aim_dir = -1
		return
	var w := weapon()
	var aim := _aim_point(player)
	var to := aim - (player.loco.logical + Vector2(0, -14))
	var fire: bool = bot.get("fire", false) if not bot.is_empty() else Input.is_action_pressed("fire")
	if fire:
		aim_hold = AIM_HOLD_S
	aim_hold = maxf(0.0, aim_hold - dt)
	# 조준 자세(상·하체 분리, SD-16 §5.10): 정조준을 누르고 있거나 · 쏜 뒤 1초 · 교전 중일 때만. 그 밖에는 전신이 걷는 쪽을 본다
	# (조준하면서 90° 넘게 반대로 걸을 때만 뒷걸음 — SD-11 §2.4). 커서가 주인공 위에 겹쳐 있으면 조준하지 않는다.
	var hold_aim: bool = Input.is_action_pressed("aim") if bot.is_empty() else bot.has("aim")
	aim_held = hold_aim
	var aiming_pose: bool = (hold_aim or aim_hold > 0.0 or in_combat()) and to.length() > 12.0
	player.aim_dir = Locomotion.snap8(to, 0.0) if aiming_pose else -1
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			mags[weapon_id] = int(mags.get(weapon_id, 0)) + _ammo_take(weapon_id, int(w["mag"]) - int(mags.get(weapon_id, 0)), st)
		return
	var ranged: bool = w["kind"] == "ranged"
	if ranged and (bot.get("reload", false) if not bot.is_empty() else (Input.is_action_just_released("reload") and not r_long)):
		start_reload(st)
		return
	if Arms.fam(w) in ["thrown", "mine"]:
		_throw_input(dt, player, w, aim, st, fire)
		return
	if not ranged:
		_melee_input(dt, player, w, to, st, fire)
		return
	var hold_scope: bool = Input.is_action_pressed("aim") if bot.is_empty() else bool(bot.get("aimed", false)) and bot.has("aim")
	scope_t = scope_t + dt if Arms.is_sniper(w) and hold_scope and player.loco.motion == "idle" and focus_t < 0.0 else 0.0
	if _focus_step(dt, player, w, aim, to, st):
		return
	var spin := float(w.get("spinup", 0.0))
	if spin > 0.0:                                                     # 회전 기관포(SD-11 §3.4): 누르면 예열 뒤 연사, 예열 중에도 회전음
		if not fire:
			_spin = 0.0
		elif _spin < spin:
			_spin += dt
			for e in enemies:
				if is_instance_valid(e):
					e.hear("pistol", player.loco.logical)
			return
	if not fire or cool > 0.0:
		return
	cool = 1.0 / float(w["rate"])
	var need := Arms.per_shot(w)
	if int(mags.get(weapon_id, 0)) < need:
		start_reload(st)                                              # 탄창이 비면 자동 재장전(옵션 기본 켬)
		return
	var sk := float(st.skill(Arms.skill_name(w))) if st != null else 15.0
	var aiming: bool = Input.is_action_pressed("aim") if bot.is_empty() else bool(bot.get("aimed", true))
	var stance := Arms.aim_stance(w, aiming, crouch)
	var assault := str(w.get("layer", "")) in ["R04", "R05", "R06"]
	var sp := CombatRules.spread(sk, stance, player.loco.motion != "idle", str(w.get("condition", "new")), 1.0, 0.0, _recoil if assault else 0.0, float(w.get("min_spread", 1.0)))
	if scope_steady():
		sp = maxf(float(w.get("min_spread", 1.0)), sp * 0.5)            # 스코프 안정: 퍼짐 ×0.5 한 번 더(§3.4)
	# 탄은 그려진 총의 총구에서 나가 조준점으로 간다(SD-16 §5 'muzzle'). 총 그림 방향 = 조준 중이면 조준 방향, 아니면 몸 방향.
	# 총구 화염은 인형이 총과 같은 층에 그린다(N·NE 조준이면 머리 뒤).
	var gdir: int = player.aim_dir if player.aim_dir >= 0 else player.loco.facing
	var muzzle := player.loco.logical + Vector2(0, -14) + to.normalized() * 10.0
	if player.doll != null:
		muzzle = player.position + player.doll.position + player.doll.muzzle_local(gdir)
	var line := aim - muzzle
	var ang := CombatRules.shot_angle(rad_to_deg((line if _aim_real and line.length() > 24.0 else to).angle()), sp, shots.rng)
	var n := shots.fire_weapon(muzzle, ang, "player", w, sk, {"flash": "" if player.doll != null else "auto", "fl": player.floor_id,
		"sneak_ok": true, "target": aim, "per": 5})
	if n <= 0:
		if Arms.proj(w) == "nuke":
			message.emit("너무 가깝다. 6걸음 밖을 겨눠야 한다.")
		return
	mags[weapon_id] = int(mags[weapon_id]) - need
	stats["shots"] += 1
	since_shot = 0.0
	if assault:
		_recoil = minf(4.0, _recoil + 0.5)
		_recoil_t = 0.0
	_wear_weapon(st, 1)
	if player.doll != null:
		player.doll.flash_face("fire", 0.14)
		var fs := CombatFx.flash_for(w)
		if fs != "":
			player.doll.fire_flash(gdir, ang, fs)
	for e in enemies:
		if is_instance_valid(e):
			e.hear(str(w.get("sound", "pistol")), player.loco.logical)


## 1-9e3 질주(초당 AP 10, 회복 없음, AP 0이면 끝 · 숨참) · 구르기 무적(5컷 중 2~4번째) · 질주 발소리(5t)
func _ap_move(dt: float, player: Actor) -> void:
	_cough(dt, player)
	var moving := player.loco.motion != "idle"
	var want := sprint_want and moving and not _sprint_latch and focus_t < 0.0 and not player.rolling() and not crouch and cough_t <= 0.0
	var was := sprinting
	sprinting = ap.tick(dt, want)
	if not sprint_want:
		_sprint_latch = false
	elif want and was and not sprinting and ap.winded():
		_sprint_latch = true
		message.emit("숨참 — 질주 끝")
	pc.invuln = player.rolling() and player.roll_frame() in [1, 2, 3]
	player.roll_cool = maxf(0.0, player.roll_cool - dt)
	if sprinting:
		pc.movement = "sprint"
		_sprint_snd -= dt
		if _sprint_snd <= 0.0:
			_sprint_snd = 0.5
			for e in enemies:
				if is_instance_valid(e):
					e.hear("sprint", player.loco.logical)


## 최루 기침(SD-14 §3 상태 '기침' · SD-13 W-058): 최루 지대 안이면 — 나온 뒤 4초까지 — 질주 불가 · AP 회복 −50% · 인지력 −2
var cough_t := 0.0
var _st_ref: StoryState


func _cough(dt: float, player: Actor) -> void:
	if ord.in_zone(player.loco.logical, "gas"):
		if cough_t <= 0.0:
			message.emit("콜록 — 최루 가스")
		cough_t = 4.0
	cough_t = maxf(0.0, cough_t - dt)
	ap.regen_mult = (0.5 if cough_t > 0.0 else 1.0) * (Perks.ap_regen_mult(_st_ref) if _st_ref != null else 1.0)   # 너브스 오브 스틸(PK-098) 8 → 10
	ap.sprint_mult = Perks.sprint_mult(_st_ref) if _st_ref != null else 1.0   # 배달 기사(PK-028): 질주 AP ×0.7
	if _st_ref != null:
		if cough_t > 0.0:
			_st_ref.stat_tmp["PE"] = -2
		else:
			_st_ref.stat_tmp.erase("PE")


## 회피 구르기(SD-11 §5.3): AP 20 · 0.35초 2.5t · 간격 0.5초. 과적 · 다리 손상이면 AP ×2 · 거리 ×0.6. 재장전 · 집중 조준이 끊긴다
func try_roll(player: Actor, dir: Vector2, heavy := false) -> bool:
	if player.rolling() or player.roll_cool > 0.0 or pc.held() or pc.big:
		return false
	var hurt := heavy or pc.has_meta("leg_hurt")
	var soft := heavy and not pc.has_meta("leg_hurt") and _st_ref != null and Perks.overload_soft(_st_ref)   # 배달 기사(PK-028): 과적 감속 절반
	if not ap.spend(APPool.DODGE * ((1.5 if soft else 2.0) if hurt else 1.0)):
		message.emit("숨참 — AP 부족")
		return false
	player.roll_mul = (0.8 if soft else 0.6) if hurt else 1.0
	reload_t = 0.0
	focus_t = -1.0
	player.loco.speed_mul = 1.0
	sprinting = false
	player.aim_dir = -1
	player.start_roll(dir)
	stats["rolls"] = int(stats.get("rolls", 0)) + 1
	return true


## 집중 사격 AP(SD-13에 AP 열이 없어 원작 표 기준값 — 구현 정합 SD-11 §5.3): 권총 17 · 기관단총 15 · 돌격소총 20 · 소총 25 · 저격 38 ·
## 산탄총 25 · 중화기 35 · 미사일 45 · 핵 65
static func focus_cost(w: Dictionary) -> float:
	if w.has("ap"):
		return float(w["ap"])
	var pk := Arms.proj(w)
	if pk == "nuke":
		return 65.0
	if pk == "missile":
		return 45.0
	match Arms.fam(w):
		"pistol":
			return 17.0
		"shotgun":
			return 25.0
		"heavy", "minigun", "flamer", "launcher":
			return 35.0
	if Arms.is_sniper(w):
		return 38.0
	var rate := float(w.get("rate", 1.0))
	return 15.0 if rate >= 9.0 else (20.0 if rate >= 5.0 else 25.0)


func scope_steady() -> bool:
	return scope_t >= SCOPE_S


## 집중 사격: 누르면 AP를 내고 0.3초 조준(이동 50%) 뒤 무기 최소 퍼짐으로 쏜다 · 치명타 +15%p · 머리 가중 + 2 × 인지력.
## 연사 무기는 원작 V.A.T.S. 점사 발수 max(1, ⌊연사력 ÷ 2.33⌋). 반환 true = 이번 틱은 집중 사격이 맡았다
func _focus_step(dt: float, player: Actor, w: Dictionary, aim: Vector2, to: Vector2, st: StoryState) -> bool:
	if focus_t >= 0.0:
		focus_t += dt
		player.aim_dir = Locomotion.snap8(to, 0.0)
		if focus_t < FOCUS_AIM:
			return true
		focus_t = -1.0
		player.loco.speed_mul = 1.0
		var need := Arms.per_shot(w)
		var n := maxi(1, floori(float(w.get("rate", 1.0)) / 2.33)) if float(w.get("rate", 1.0)) >= 5.0 else 1
		var sk := float(st.skill(Arms.skill_name(w))) if st != null else 15.0
		var per := st.stat("PE") if st != null else 5
		var muzzle := player.loco.logical + Vector2(0, -14) + to.normalized() * 10.0
		var fired := 0
		for i in n:
			if int(mags.get(weapon_id, 0)) < need:
				break
			var ang := CombatRules.shot_angle(rad_to_deg(to.angle()), float(w.get("min_spread", 1.0)), shots.rng)
			if shots.fire_weapon(muzzle, ang, "player", w, sk, {"focused": true, "per": per, "fl": player.floor_id, "sneak_ok": true, "target": aim}) <= 0:
				break
			mags[weapon_id] = int(mags[weapon_id]) - need
			fired += 1
		if fired > 0:
			cool = 1.0 / float(w["rate"])
			stats["shots"] += fired
			stats["focus"] = int(stats.get("focus", 0)) + 1
			since_shot = 0.0
			_wear_weapon(st, fired * 2)                                     # 집중 사격 열화 ×2(§5.3)
			if player.doll != null:
				player.doll.flash_face("fire", 0.2)
			for e in enemies:
				if is_instance_valid(e):
					e.hear(str(w.get("sound", "pistol")), player.loco.logical)
		return true
	var want: bool = (Input.is_action_just_pressed("focus") if bot.is_empty() else bool(bot.get("focus", false))) or focus_req
	focus_req = false
	if not bot.is_empty():
		bot.erase("focus")
	if not want or cool > 0.0:
		return false
	if int(mags.get(weapon_id, 0)) < Arms.per_shot(w):
		start_reload(st)
		return true
	if not ap.spend(focus_cost(w)):
		message.emit("숨참 — AP 부족")
		return true
	focus_t = 0.0
	player.loco.speed_mul = 0.5                                         # 조준 0.3초 동안 이동 50%(거리 구동 — 보폭 그대로)
	return true


## 투척(SD-11 §3.4): 누르고 있으면 조준선이 착지점까지 늘어나고(1.2초에 최대 거리 6 + ⌊힘/2⌋t), 놓으면 던진다. 쿠킹 없음.
## 설치: 누르면 발밑 0.8t 앞에 놓는다. 하나 쓰면 소지품에서 하나 줄고, 다 쓰면 빈손. 봇은 throw = 누른 초, fire = 설치.
var throw_hold := -1.0                            ## 그리기: 누르는 중인 초(-1 = 아님)
var throw_aim := Vector2.ZERO
var throw_max_t := 8.0


func _throw_input(dt: float, player: Actor, w: Dictionary, aim: Vector2, st: StoryState, fire: bool) -> void:
	var sk := float(st.skill("폭발물")) if st != null else 15.0
	var max_t := 6.0 + floorf(float(st.stat("ST") if st != null else 5) / 2.0)
	throw_aim = aim
	throw_max_t = max_t
	if Arms.fam(w) == "mine":
		if fire and cool <= 0.0:
			cool = 1.0 / float(w["rate"])
			var fwd: Vector2 = (aim - player.loco.logical).normalized() if aim.distance_to(player.loco.logical) > 4.0 else (Locomotion.VEC[player.loco.facing] as Vector2).normalized()
			ord.place(player.loco.logical, fwd, w, "player", sk)
			_use_one(st)
		return
	var hold := -1.0
	if not bot.is_empty():
		if bot.has("throw") and cool <= 0.0:
			hold = float(bot["throw"])
			bot.erase("throw")
	else:
		if fire and cool <= 0.0:
			throw_hold = maxf(0.0, throw_hold) + dt
			return
		if throw_hold >= 0.0:
			hold = throw_hold
	throw_hold = -1.0
	if hold < 0.0:
		return
	cool = 1.0 / float(w["rate"])
	ord.throw(player.loco.logical + Vector2(0, -10), aim, w, "player", sk, max_t, hold)
	if player.doll != null:
		player.doll.flash_face("fire", 0.14)
	_use_one(st)


func _use_one(st: StoryState) -> void:
	if st == null:
		return
	var id := weapon_id
	st.call_fn("take", [id, 1])
	if int(st.items.get(id, 0)) <= 0:
		equip("", st)


## 지뢰 해체(SD-11 §9.2): 웅크려 1t 안에서 상호작용 1초 · 폭발물 I(15). 끝나면 소지품으로. 호스트(상호작용 키)·봇(disarm)이 부른다
func disarm_tick(dt: float, st: StoryState) -> String:
	if not crouch:
		_disarm = {}
		disarm_prog = -1.0
		return "stand"
	var hz := hazards.near(pc.pos())                                   # 함정이 먼저(1-9c): 기술 확인 → 1초 → 회수
	if not hz.is_empty():
		if not hazards.can_disarm(hz):
			disarm_prog = -1.0
			message.emit("해체하려면 %s이 필요하다." % hazards.need_text(hz))
			return "skill"
		disarm_prog = clampf(maxf(0.0, disarm_prog) + dt / Ordnance.DISARM_S, 0.0, 1.0)
		if disarm_prog >= 1.0:
			hazards.finish_disarm(hz)
			disarm_prog = -1.0
			message.emit("함정을 해체했다.")
			return "done"
		return "busy"
	if _disarm.is_empty() or not ord.mines.has(_disarm):
		_disarm = ord.near_mine(pc.pos())
		if _disarm.is_empty():
			return "none"
	var r := ord.disarm_step(_disarm, dt, float(st.skill("폭발물")) if st != null else 0.0)
	if r == "done" and st != null:
		var id := str(_disarm["w"].get("id", "W-063"))
		st.call_fn("give", [id, 1])
		message.emit("%s을(를) 해체했다." % str(_disarm["w"].get("name", id)))
		_disarm = {}
	elif r == "skill":
		message.emit("폭발물 기술이 모자라 해체할 수 없다(15 필요).")
	return r


## 근접 입력(SD-11 §3.4·§5.3): 눌렀다 떼면 일반 공격, 0.5초 누르고 있으면 파워 공격(피해 ×2 · 0.6t 전진 · 넉백 · AP = 무기 AP ÷ 2, 최소 10).
## 회전날(리퍼)은 누르는 동안 0.1초마다 틱(틱당 피해 ÷ 10). 봇은 fire = 일반 공격(쿨마다), power = 파워 공격.
func _melee_input(dt: float, player: Actor, w: Dictionary, to: Vector2, st: StoryState, fire: bool) -> void:
	if w.get("saw", false):
		if fire and cool <= 0.0:
			cool = 0.1
			_melee(player, w, to, st, false, 0.1)
		return
	var cost := maxf(10.0, float(w.get("ap_cost", 0.0) if w.get("ap_cost") != null else 0.0) * 0.5)
	if not bot.is_empty():
		if cool > 0.0:
			return
		if bot.get("power", false) and ap.spend(cost):
			cool = 1.0 / float(w["rate"])
			_melee(player, w, to, st, true)
		elif fire:
			cool = 1.0 / float(w["rate"])
			_melee(player, w, to, st, false)
		return
	if _charge < 0.0:
		if fire and cool <= 0.0 and Input.is_action_just_pressed("fire"):
			_charge = 0.0
		return
	if fire:
		_charge += dt
		if _charge >= Arms.POWER_HOLD_S:
			_charge = -1.0
			cool = 1.0 / float(w["rate"])
			_melee(player, w, to, st, ap.spend(cost))                  # AP가 모자라면 일반 공격
		return
	_charge = -1.0
	cool = 1.0 / float(w["rate"])
	_melee(player, w, to, st, false)


## 근접(SD-11 §3.4): 한손 호 90°·최대 3명, 양손 호 140°·4명, 비무장 호 70°·2명(사거리는 무기 자료), 호 안 충돌체 중심이면 명중(굴림 없음).
## 파워 공격 = 피해 ×2 · 0.6t 전진 · 넉백(양손 1.0t + 경직, 한손·비무장 0.3t). 슈퍼 슬레지급 파워 공격은 인간형 25% 넘어뜨림(§4.9).
## 비무장은 머리에 맞으면 15%(맨주먹 30%) 1.5초 기절. 프롤로그(볼트 평시)의 근접은 비살상(사람은 기절, 0-9) — 1막부터는 실제 피해(1-9a 정합).
func _melee(player: Actor, w: Dictionary, to: Vector2, st: StoryState, power: bool = false, tick_mult: float = 1.0) -> void:
	var fam := Arms.fam(w)
	var reach := float(w["range_eff"]) * 32.0
	var arc := Arms.melee_arc(w)
	var cap := Arms.melee_max(w)
	var sk := float(st.skill(Arms.skill_name(w))) if st != null else 15.0
	var calm := st == null or st.quests.cur_act() < 1                   # 프롤로그: 근접 = 기절
	var dirv: Vector2 = to.normalized() if to.length() > 0.1 else (Locomotion.VEC[player.loco.facing] as Vector2).normalized()
	if power:                                                          # 0.6t 전진 — 앞의 상대 몸 앞에서 멈춘다(겹치지 않는다)
		power_hits += 1
		var go := Arms.POWER_LUNGE_T * 32.0
		for e in enemies:
			if is_instance_valid(e) and not e.cmb.dead:
				var dd: Vector2 = e.loco.logical - player.loco.logical
				if absf(dirv.angle_to(dd)) <= arc:
					go = minf(go, maxf(0.0, dd.length() - pc.radius - e.cmb.radius - 2.0))
		if go > 0.5 and player.world != null:
			var lunge: Vector2 = player.world.move_circle(player.loco.logical, player.loco.logical + dirv * go, player.radius_px)
			player.loco.place(lunge.round())
	var kb := Arms.knockback(w, power) * 32.0
	var n := 0
	var hits: Array = []
	for e in enemies:
		if not is_instance_valid(e) or e.cmb.dead or not e.meets(pc) or e.cmb.team == "ally":
			continue                                                     # 다른 층(고가 위·아래)은 닿지 않는다 · 내 편 짐승(애니멀 프렌드 2랭크)은 휘둘러도 비켜 간다
		hits.append([e.cmb, e.loco.logical, e])
	for rr in residents:                                               # 주민도 맞는다
		if not rr["cmb"].dead and is_instance_valid(rr["actor"]):
			hits.append([rr["cmb"], rr["actor"].loco.logical, null])
	for h in hits:
		if n >= cap:
			break
		var c: Combatant = h[0]
		var d: Vector2 = (h[1] as Vector2) - player.loco.logical
		if d.length() > reach + c.radius or (d.length() >= pc.radius + c.radius and absf(dirv.angle_to(d)) > arc):
			continue
		n += 1
		var e = h[2]
		var sneak: bool = e != null and c.unaware.is_valid() and c.unaware.call()
		var part := CombatRules.pick_part(CombatRules.part_weights(c.weights, {"melee": true, "attacker_crouch": crouch}), shots.rng)
		var r := CombatRules.resolve({"weapon": w, "skill": sk, "power": power, "part": part, "dr": c.dr, "sneak": sneak, "crit": sneak,
			"attacker": {"str": st.stat("ST") if st != null else 5, "unarmed": sk},
			"add": Perks.unarmed_add(st) if st != null and fam == "unarmed" else 0.0,
			"perk_mult": Perks.dmg_mult(st, Projectiles.target_id(c)) if st != null else 1.0, "better_crits": st != null and Perks.better_crits(st)})
		r["hp"] = float(r["hp"]) * tick_mult * (float(w.get("robot_mult", 1.0)) if c.robot else 1.0)
		r["nonlethal"] = calm or str(w.get("id", "")) == "W-066"
		c.last_by = "player"
		c.take(r, player.loco.logical)
		Projectiles.after_hit(c, w, "", d.length() / 32.0, shots.rng, dirv)
		if not c.dead:
			if kb > 0.0 and not c.big:
				c.push += d.normalized() * kb
			if power and fam == "melee2":
				c.hold("stun", 0.6)                                      # 파워 공격 경직
				if str(w.get("layer", "")) == "T05" and c.weights.has("arm") and shots.rng.randf() < 0.25:
					c.hold("down", 1.5)
			if fam == "unarmed" and part == "head" and shots.rng.randf() < (0.3 if Gear.base(str(w.get("id", ""))) == Arms.FIST else 0.15):
				c.hold("stun", 1.5)
		if e != null:
			e.hear("melee", player.loco.logical)
		stats["hits"] += 1
		if sneak:
			stats["sneak"] += 1
			_pop("기습 치명타 ×%d" % int(CombatRules.sneak_mult("melee", false)), (h[1] as Vector2) + Vector2(0, -22), Color("E8C23A"))
	if tick_mult >= 1.0:
		_wear_weapon(st, n)                                            # 근접은 타격마다 카운터 1(SD-13 §8.2) · 리퍼 틱은 열 번에 한 번
	elif n > 0 and shots.rng.randf() < tick_mult:
		_wear_weapon(st, 1)
	if tick_mult >= 1.0 or shots.rng.randf() < 0.3:
		_swing_fx(player.loco.logical + Vector2(0, -12) + dirv * reach * 0.6)


func start_reload(st: StoryState) -> void:
	if not armed() or reload_t > 0.0:
		return
	var w := weapon()
	if w["kind"] != "ranged" or int(mags.get(weapon_id, 0)) >= int(w["mag"]):
		return
	if str(w.get("ammo_id", "")) != "" and ammo_left(st) <= 0:
		message.emit("탄이 없다.")
		return
	var sk := float(st.skill(Arms.skill_name(w))) if st != null else 15.0
	reload_t = float(w.get("reload_s", 2.0)) * (1.2 - 0.004 * sk)            # SD-11 §3.5
	var jam: float = Gear.JAM[Gear.cond(weapon_id)]
	if jam > 0.0 and _rng.randf() < jam:                                 # 탄 걸림(SD-11 §11.8): 낡음 25% · 위태 80%, 재장전 +1.5초
		reload_t += 1.5
		stats["jams"] = int(stats.get("jams", 0)) + 1
		message.emit("탄 걸림! 노리쇠를 당긴다.")


## 든 무기의 열쇠가 바뀌었다(열화·수리): 탄창·단축키를 새 열쇠로 옮긴다
func rekey(old: String, nk: String, st: StoryState) -> void:
	if weapon_id == old:
		weapon_id = nk
		if mags.has(old):
			mags[nk] = mags[old]
			mags.erase(old)
	for k in hotkeys.keys():
		if hotkeys[k] == old and int(st.items.get(old, 0)) <= 0:
			hotkeys[k] = nk


## 무기 열화(SD-13 §8.2): 공격 1회(연사는 발마다, 근접은 타격마다)에 카운터 1. 볼트 안(프롤로그)은 정비반이 손봐 닳지 않는다(정합 1-8a).
## 단계가 바뀌면 든 무기의 열쇠를 바꿔 낀다(탄창·단축키를 옮긴다). 파손이면 내려놓는다
func _wear_weapon(st: StoryState, n: int) -> void:
	if st == null or n <= 0 or weapon_id == "" or weapon_id == Arms.FIST or st.quests.cur_act() < 1:
		return
	var old := weapon_id
	var nk := Gear.use(st, old, n)
	if nk == old:
		return
	rekey(old, nk, st)
	var nm := str(weapons.get(Gear.base(nk), {}).get("name", nk))
	if Gear.cond(nk) >= 4:
		message.emit("%s — 부서졌다. 더는 쏠 수 없다." % nm)
		mags.erase(nk)
		weapon_id = ""
		holstered = false
		reload_t = 0.0
		st.weapon_out = false
		_doll()
	else:
		message.emit("%s — 상태가 '%s'(으)로 떨어졌다." % [nm, Gear.NAMES[Gear.cond(nk)]])


## 스팀팩(SD-11 §2.7, SD-13 §6.2): 30 × (1 + 의학/50)을 회복 대기열에 2.0초로. 단축키면 0.4초 투여 모션
func use_stimpak(st: StoryState, quick: bool = false) -> bool:
	if st == null or int(st.items.get(STIMPAK, 0)) <= 0:
		message.emit("스팀팩이 없다.")
		return false
	if pc.hp >= pc.max_hp and heal_q.is_empty():
		message.emit("다친 데가 없다.")
		return false
	st.call_fn("take", [STIMPAK, 1])
	var amount := 30.0 * (1.0 + float(st.skill("MEDICINE")) / 50.0) * Perks.stim_mult(st)   # 패스트 메타볼리즘(PK-058) +20%
	heal_q.append(amount)
	if heal_q.size() == 1:
		heal_rate = amount / STIM_QUEUE_S
	if quick:
		inject_t = STIM_INJECT_S
	stats["stims"] += 1
	_pop("스팀팩 +%d" % roundi(amount), pc.pos() + Vector2(0, -34), Color("7CD62B"))
	return true


func healing() -> bool:
	return not heal_q.is_empty()


## 연출 피해(증기 분출 등): 방어 무시
func damage(amount: float) -> void:
	var before := pc.hp
	pc.take({"hp": amount}, pc.pos())
	stats["hurt"] += before - pc.hp
	hurt.emit(before - pc.hp)


## 조준점: 봇이 준 점 · 마우스 커서(360°) · 고전 조작(바라보는 방향, 원뿔 안의 가장 가까운 표적·적에게 끌어당김)
func _aim_point(player: Actor) -> Vector2:
	_aim_real = true
	if not bot.is_empty() and bot.has("aim"):
		return bot["aim"]
	if bot.is_empty() and aim_mode == "mouse":
		return get_global_mouse_position()
	var p := auto_aim(player)
	_aim_real = _auto_hit
	return p


## 고전 조작 조준(SD-11 §2.3): 8방향 바라보는 쪽 기준 반각 15° 안, 사거리 안의 가장 가까운 적·표적 중심. 없으면 그 방향 3칸
func auto_aim(player: Actor) -> Vector2:
	var eye := player.loco.logical + Vector2(0, -14)
	var f: Vector2 = Locomotion.VEC[player.loco.facing].normalized()
	var reach := float(weapon().get("range_max", 8.0)) * 32.0 if armed() else 256.0
	var best := Vector2.INF
	var bd := 1e9
	var cands: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.cmb.dead and e.visible and not e.cmb.invuln:   # 숨은 적(물속 매복 · 땅속 굴쥐)은 겨누지 않는다
			cands.append(e.loco.logical + Vector2(0, -6))
	for t in targets:
		if not t["down"] and t["live"]:
			cands.append(t["cmb"].pos() + Vector2(0, -12))
	for p in cands:
		var d: Vector2 = p - eye
		if d.length() <= reach and d.length() < bd and absf(f.angle_to(d)) <= deg_to_rad(AUTO_AIM_HALF):
			bd = d.length()
			best = p
	_auto_hit = best != Vector2.INF
	return best if _auto_hit else eye + f * 96.0


## 교전 중: 주인공을 표적으로 잡은 적이 있다(SD-11 §2.5) — 이동 중에도 상체가 조준을 따른다
func in_combat() -> bool:
	for e in enemies:
		if is_instance_valid(e) and not e.cmb.dead and e.brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY]:
			return true
	return false


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion or (e is InputEventMouseButton and e.pressed):
		aim_mode = "mouse"
	elif e is InputEventKey and e.pressed and e.physical_keycode in [KEY_Z, KEY_X]:
		aim_mode = "key"                                                # 고전 조작으로 쏘기 시작하면 키보드 조준


## HUD 탐지 표시(SD-12 §4.5): 숨음 · 주의 · 발각 · 위험 중 가장 나쁜 것. 웅크리지 않았으면 위험만 보인다
func detect_state() -> String:
	var worst := 0
	for e in enemies:
		if not is_instance_valid(e) or e.cmb.dead:
			continue
		if e.brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY]:
			worst = maxi(worst, 3)
		elif e.brain.gauge >= 40.0:
			worst = maxi(worst, 1)
	for t in targets:
		if t["kind"] != "stealth" or t["down"] or not t["live"]:
			continue
		if t["seen_t"] > 0.0:
			worst = maxi(worst, 2)
		elif t["gauge"] >= 40.0:
			worst = maxi(worst, 1)
	if not crouch:
		return "위험" if worst == 3 else ""
	return ["숨음", "주의", "발각", "위험"][worst]


# ---------------------------------------------------------------- 표적
func _targets(dt: float, player: Actor) -> void:
	var pp := player.loco.logical
	for t in targets:
		var c: Combatant = t["cmb"]
		if t["down"]:
			continue
		if t["kind"] == "stealth":
			if not t["live"]:
				c.hp = c.max_hp
				c.dead = false
				continue
			var to: Vector2 = pp - c.pos()
			var dist_t := to.length() / 32.0
			var sees: bool = dist_t <= Perception.sight_range(STEALTH_PER) and shots.world.line_of_sight(c.pos(), pp, crouch)
			if t["seen_t"] > 0.0:
				t["seen_t"] -= dt
				if t["seen_t"] <= 0.0:
					t["gauge"] = 0.0
					_prop_state(t, "")
			elif sees:
				var moving := player.loco.motion != "idle"
				var rate := Perception.detect_rate(dist_t, STEALTH_PER, {"posture": "crouch" if crouch else "stand",
					"movement": ("sneak" if crouch else "move") if moving else "still",
					"in_fov": Perception.in_fov(t["facing"], to, "human"), "sneak_skill": sneak_skill})
				if dist_t <= 1.2:
					rate = 1000.0                                              # 접촉 1.2t: 바로 들킨다(SD-11 §7.3)
				t["gauge"] = minf(100.0, t["gauge"] + rate * dt)
				if t["gauge"] >= 100.0:
					t["seen_t"] = STEALTH_RESET_S
					stats["spotted"] += 1
					_prop_state(t, "duck")
					_pop("들켰다!", c.pos() + Vector2(0, -30), Color("E04A35"))
					message.emit("들켰다 — 표적이 숨었다. 웅크리고(Ctrl) 상자 뒤로 다가가자.")
			else:
				t["gauge"] = maxf(0.0, t["gauge"] - 10.0 * dt)
		if c.dead or c.hp < c.max_hp:
			_hit_target(t)


func _hit_target(t: Dictionary) -> void:
	var c: Combatant = t["cmb"]
	var sneak: bool = t["kind"] == "stealth" and t["seen_t"] <= 0.0 and t["gauge"] < 100.0
	if t["kind"] == "stealth" and not sneak:
		c.hp = c.max_hp                                                   # 숨은 표적: 맞지 않는다
		c.dead = false
		return
	t["down"] = true
	c.dead = true
	stats["hits"] += 1
	_prop_state(t, "down")
	if sneak:
		stats["sneak"] += 1
		_pop("기습 치명타 ×%d" % int(CombatRules.sneak_mult("ranged", false)), c.pos() + Vector2(0, -30), Color("E8C23A"))
	target_down.emit(t["kind"], sneak, targets_left("target") + targets_left("stealth"))


func _prop_state(t: Dictionary, state: String) -> void:
	var p: Dictionary = t["prop"]
	if shots.world != null:
		shots.world.set_prop_state(Vector2i(int(p["x"]), int(p["y"])), state)


# ---------------------------------------------------------------- 그리기
func _pop(text: String, at: Vector2, col: Color) -> void:
	popups.append([text, at, 1.0, col])


## 레벨업 순간(SD-10 §4.2 — 게임은 멈추지 않는다): 머리 위 '레벨 업!' · 빛
func level_fx() -> void:
	lv_fx = 0.0
	if pc.actor != null:
		popups.append(["레벨 업!", pc.pos() + Vector2(0, -48), 1.6, Color("E8C23A")])


var _swings: Array = []


func _swing_fx(at: Vector2) -> void:
	_swings.append([at, 0.12])


## 조준 커서(SD-11 §12.4): 퍼짐 원(반지름 = 그 거리에서 지금 퍼짐 반각), 사거리 밖이면 점선, 장전 중이면 회색 원호
func _draw_cursor() -> void:
	var a: Actor = pc.actor
	if a == null or not armed() or not visible_cursor:
		return
	if not (aim_mode == "mouse" and bot.is_empty()) and a.aim_dir < 0:
		return                                                          # 키보드·봇: 조준 자세일 때만(마우스면 늘 커서 자리에)
	var w := weapon()
	var aim := _aim_point(a)
	var from := a.loco.logical + Vector2(0, -14)
	var d := aim - from
	var col := Color("7CF08E")
	if w["kind"] != "ranged":
		draw_arc(aim.round(), 3.0, 0, TAU, 8, col, 1.0)
		return
	var sk := 15.0
	var sp := CombatRules.spread(sk, "crouch" if crouch else "stand", a.loco.motion != "idle", "new", 1.0, 0.0, 0.0, float(w.get("min_spread", 1.0)))
	if scope_steady() or focus_t >= 0.0:
		sp = float(w.get("min_spread", 1.0)) * (1.0 if focus_t >= 0.0 else 2.0)   # 집중 조준 · 스코프 안정: 원이 조여든다
		col = Color("E8C23A")
	var r := clampf(d.length() * tan(deg_to_rad(sp)), 3.0, 40.0)
	var far := d.length() > float(w["range_max"]) * 32.0
	if reload_t > 0.0:
		var k := 1.0 - reload_t / maxf(0.01, float(w.get("reload_s", 2.0)))
		draw_arc(aim.round(), r, -PI / 2.0, -PI / 2.0 + TAU * k, 24, Color("8B857D"), 2.0)
		return
	var segs := 16
	for i in segs:
		if far and i % 2 == 1:
			continue                                                    # 사거리 밖: 점선
		var a0 := TAU * i / segs
		draw_arc(aim.round(), r, a0, a0 + TAU / segs, 3, col if not far else Color("E04A35"), 1.0)
	draw_rect(Rect2(aim.round() - Vector2(0.5, 0.5), Vector2(1, 1)), col)


var visible_cursor := true


## 웅크린 채 1t 안에 해체할 것이 있나(호스트: 상호작용 키를 누르고 있으면 해체)
func can_disarm_here() -> bool:
	return crouch and pc.actor != null and (not hazards.near(pc.pos()).is_empty() or not ord.near_mine(pc.pos()).is_empty())


func _draw() -> void:
	_draw_cursor()
	if disarm_prog >= 0.0 and pc.actor != null:                        # 해체 진행 고리(어두운 바탕 원 위 — 녹색 빛 위에서도 보이게)
		var rc := pc.pos() + Vector2(0, -50)
		draw_circle(rc, 11.0, Color(0.04, 0.06, 0.04, 0.8))
		draw_arc(rc, 8.0, 0.0, TAU, 24, Color(0.3, 0.36, 0.3, 0.9), 1.0)
		draw_arc(rc, 8.0, -PI / 2.0, -PI / 2.0 + TAU * disarm_prog, 24, Color("D4FF6A"), 3.0)
	if mates.rev_prog >= 0.0 and pc.actor != null:                     # 동행 일으키기 진행 고리(2초, 1-10a)
		var rc2 := pc.pos() + Vector2(0, -50)
		draw_circle(rc2, 11.0, Color(0.04, 0.06, 0.04, 0.8))
		draw_arc(rc2, 8.0, 0.0, TAU, 24, Color(0.3, 0.36, 0.3, 0.9), 1.0)
		draw_arc(rc2, 8.0, -PI / 2.0, -PI / 2.0 + TAU * mates.rev_prog / Companions.REVIVE_S, 24, Color("7CF08E"), 3.0)
	if mates.glare != null and is_instance_valid(mates.glare):         # 백구가 노려보는 숨은 적: 머리 위 흰 테두리 역삼각(SD-11 §8.2 '위치 표시')
		var gp: Vector2 = (mates.glare.loco.logical + Vector2(0, -44)).round()
		var tri := PackedVector2Array([gp + Vector2(-4, -4), gp + Vector2(4, -4), gp + Vector2(0, 1)])
		draw_colored_polygon(tri, Color("0B0A0D"))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("E9E4D8"), 1.0)
	if throw_hold >= 0.0 and pc.actor != null:                         # 투척 조준선(SD-11 §3.4): 누른 시간만큼 착지점까지 늘어나는 점선 포물선
		var from: Vector2 = pc.pos() + Vector2(0, -10)
		var d := minf(from.distance_to(throw_aim), throw_max_t * 32.0 * clampf(throw_hold / Ordnance.THROW_HOLD_S, 0.15, 1.0))
		var to := from + (throw_aim - from).normalized() * d
		for i in 12:
			var k := float(i) / 11.0
			var p := from.lerp(to, k) - Vector2(0, 4.0 * 22.0 * k * (1.0 - k))
			draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(2, 2)), Color("E8C23A") if i % 2 == 0 else Color("0B0A0D"))
		draw_arc(to, float(Arms.blast_r("grenade")[1]) * 32.0, 0, TAU, 28, Color("E8C23A"), 1.0)
	if lv_fx >= 0.0 and pc.actor != null:                               # 레벨업 빛: 땅에 번지는 납작한 고리 + 몸을 타고 오르는 불티 여섯
		lv_fx += get_process_delta_time()
		var k := lv_fx / 1.2
		var base := pc.pos().round()
		var fade := clampf(1.0 - k, 0.0, 1.0)
		var r := 6.0 + 16.0 * k
		for i in 28:
			var t := TAU * i / 28.0
			draw_rect(Rect2((base + Vector2(cos(t) * r, sin(t) * r * 0.4)).round(), Vector2(2, 1)), Color(0.91, 0.76, 0.23, fade))
		for i in 6:
			var ph := fmod(k * 1.6 + i / 6.0, 1.0)
			var sp := base + Vector2((i - 2.5) * 4.0 + sin(i * 1.7 + k * 6.0) * 1.5, -4.0 - 44.0 * ph)
			draw_rect(Rect2(sp.round(), Vector2(2, 3 if i % 2 == 0 else 2)), Color(1.0, 0.86, 0.42, fade * (1.0 - ph * 0.5)))
		if lv_fx > 1.2:
			lv_fx = -1.0
	for s in _swings:
		var a: Vector2 = (s[0] as Vector2).round()
		draw_arc(a, 7.0, -0.8, 0.8, 6, Color("E9E4D8"), 1.0)
		s[1] -= get_process_delta_time()
	_swings = _swings.filter(func(s): return s[1] > 0.0)
	for p in popups:
		var w := font.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var at: Vector2 = (p[1] as Vector2).round() - Vector2(roundf(w / 2.0), 0)
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(font, at + o, p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("0B0A0D"))
		draw_string(font, at, p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, p[3])
	for t in targets:                                                    # 은신 표적의 탐지 게이지
		if t["kind"] != "stealth" or t["down"] or not t["live"] or (t["gauge"] <= 0.0 and t["seen_t"] <= 0.0):
			continue
		var c: Vector2 = t["cmb"].pos() + Vector2(-8, -28)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(18, 5)), Color("0B0A0D"))
		draw_rect(Rect2(c, Vector2(16.0 * t["gauge"] / 100.0, 3)), Color("E04A35") if t["seen_t"] > 0.0 else Color("E8C23A"))


## 표적 자리표(Combatant.pos()가 actor.loco.logical을 읽는다)
class _Pos:
	extends RefCounted
	var loco: Locomotion

	func _init(p: Vector2) -> void:
		loco = Locomotion.new(p)
