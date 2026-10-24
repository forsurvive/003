## 전투 참가자 데이터: 체력·DR·편·충돌 반지름. 맞으면 CombatRules.resolve 결과를 받는다.
class_name Combatant
extends RefCounted

signal died
signal hit                                    ## 맞았지만 쓰러지지 않았다(주민 폭행 반응, 0-9)
var actor                                     ## loco.logical을 가진 것(Actor 또는 표적 자리표)
var team := "player"
var hp := 100.0
var max_hp := 100.0
var dr := 0.0
var radius := 9.6
var weights: Dictionary = CombatRules.HUMANOID_WEIGHTS
var part_mult: Dictionary = {}                  ## 부위 피해 배수 덮어쓰기(갑각 PW-D: 얼굴 ×2 · 껍질 ×0.5 · 배 ×1.0 — SD-14 §2.4 표, 1-13 D-380)
var back_part := []                             ## 뒤쪽 90° 명중이면 [옮길 부위, 새 부위, 몫](PW-D: 껍질 70 가운데 40 → 배)
var dead := false
var last_hit_from := Vector2.ZERO
var flash := 0
var invuln := false                           ## 구르기 무적 프레임: 투사체·근접·폭발 모두 무시(SD-11 §5.3)
var unaware := Callable()                     ## 쏜 쪽을 아직 모른다(은신 기습 가능, SD-11 §4.4) — 없으면 늘 안다
var last_sneak := false                       ## 마지막으로 맞은 것이 은신 기습이었나(표시용)
## 단계 0-9: 은신 탐지 입력(주인공) · 기절 · 체력 하한
var posture := "stand"                        ## stand | crouch — 적의 탐지식(Perception.detect_rate)이 읽는다
var movement := "move"                        ## still | sneak | move | sprint | fired
var sneak := 0.0                              ## 은신 스킬
var can_ko := false                           ## 비살상 피해로 HP 0이면 기절(인간형 적)
var ko := false                               ## 기절 중(dead도 참: 맞지 않고 막지 않는다)
var hp_floor := 0.0                           ## 이 밑으로 내려가지 않는다(죽지 않는 적)
var killed_lethal := false                    ## 마지막 일격이 실총이었나(카르마)
var dmg_player := 0.0                         ## 주인공이 깎은 HP 합(1-10a: 동행이 쓰러뜨린 적의 XP는 주인공이 30% 이상 깎았을 때만, SD-11 §8.2)
var last_by := ""                             ## 마지막으로 때린 편(1-E: 교전 중 다른 무리가 쓰러뜨리면 경험치 없음 · 비적대 무리를 때리면 적대로)
## 1-9a 상태 이상(SD-11 §9.6): 지속 피해는 0.5초 틱 · 같은 종류는 시간만 갱신(세기는 큰 쪽) · 행동 제한은 끝난 뒤 1초 같은 종류 면역
var dots := {}                                ## 종류(burn·shock·poison) -> [초당 피해, 남은 초]
var holds := {}                               ## 종류(stun·root·down) -> 남은 초
var _immune := {}                             ## 종류 -> 면역 남은 초
var _dot_acc := 0.0
var robot := false                            ## 로봇(관제망 로봇 피해 +50% 무기)
var fire_mul := 1.0                           ## 화상 배율(잔바퀴 떼 CR-001 '화염 ×2' — SD-14 §3.1)
var big := false                              ## 대형(넉백·넉다운·그물 무효)
var push := Vector2.ZERO                      ## 넉백 남은 거리(px) — 몸 주인이 걸음 규칙으로 옮긴다
var limbs := {}                               ## 부위 체력(SD-11 §4.8, 1-9e): 부위 -> 남은 값(처음 맞을 때 최대 HP × 계수로 채운다)
var crippled := {}                            ## 부위 손상: 부위 -> true(다리 · 팔 · 머리 · 몸통 · 더듬이)
var track_limbs := false                      ## 부위 체력을 셀지(적만 — 주인공 부위 손상은 SD-11 §11.4 단계에서)
signal crippled_part(part: String)


func pos() -> Vector2:
	return actor.loco.logical


## 층(1-Rd): 0 지면 · 1 고가 상판(인물이 아니면 0)
func fl() -> int:
	var v = actor.get("floor_id") if actor is Object else null
	return int(v) if v != null else 0


func take(result: Dictionary, from: Vector2) -> void:
	if dead or invuln:
		return
	if last_by == "player":
		dmg_player += minf(maxf(0.0, hp), float(result["hp"]))
	hp -= float(result["hp"])
	last_hit_from = from
	flash = 3
	if track_limbs and result.has("part") and hp > 0.0:
		_limb_hit(str(result["part"]), float(result.get("limb", float(result["hp"]) * 2.0)))
	if hp_floor > 0.0 and hp < hp_floor:
		hp = hp_floor
		hit.emit()
		return
	hit.emit()                                # 쓰러뜨린 한 방도 '맞음'이다(폭행 반응이 먼저, 쓰러짐은 그 뒤)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		ko = can_ko and bool(result.get("nonlethal", false))
		killed_lethal = not ko
		died.emit()


## 부위 체력(SD-11 §4.8): 부위 피해 = HP 피해 × 2 × 무기 배수. 바닥나면 부위 손상 + 0.6초 멈춤(상처를 붙잡는다)
func _limb_hit(part: String, amt: float) -> void:
	var key := "leg" if part.begins_with("leg") else ("arm" if part.begins_with("arm") else part)
	if not key in ["head", "torso", "arm", "leg", "antenna"] or crippled.has(key):
		return
	if not limbs.has(key):
		limbs[key] = CombatRules.limb_hp(max_hp, key)
	limbs[key] = float(limbs[key]) - amt
	if float(limbs[key]) <= 0.0:
		crippled[key] = true
		hold("flinch", 0.6)
		crippled_part.emit(key)


## 지속 피해 걸기: 같은 종류는 남은 시간만 갱신, 세기는 큰 쪽(SD-11 §9.6)
func add_dot(kind: String, dps: float, secs: float) -> void:
	if dead or dps <= 0.0 or secs <= 0.0:
		return
	if kind == "burn":
		dps *= fire_mul
	var cur: Array = dots.get(kind, [0.0, 0.0])
	dots[kind] = [maxf(float(cur[0]), dps), maxf(float(cur[1]), secs)]


## 행동 제한 걸기(stun 기절·마비 · root 그물·덫 · down 넘어짐). 면역 중이면 무시. 대형은 넘어짐·그물 무효
func hold(kind: String, secs: float) -> bool:
	if dead or secs <= 0.0 or float(_immune.get(kind, 0.0)) > 0.0:
		return false
	if big and kind in ["down", "root"]:
		return false
	holds[kind] = maxf(float(holds.get(kind, 0.0)), secs)
	return true


func held() -> bool:
	return not holds.is_empty()


func held_by(kind: String) -> bool:
	return float(holds.get(kind, 0.0)) > 0.0


## 상태 흐름(전투 모듈이 매 프레임 부른다): 지속 피해는 0.5초마다 한 틱. 돌려주는 값 = 이번에 깎인 HP
func tick_status(dt: float) -> float:
	for k in _immune.keys():
		_immune[k] = float(_immune[k]) - dt
		if float(_immune[k]) <= 0.0:
			_immune.erase(k)
	for k in holds.keys():
		holds[k] = float(holds[k]) - dt
		if float(holds[k]) <= 0.0:
			holds.erase(k)
			_immune[k] = 1.0
	if dots.is_empty() or dead:
		dots.clear()
		_dot_acc = 0.0
		return 0.0
	_dot_acc += dt
	var lost := 0.0
	while _dot_acc >= 0.5 - 0.0001:
		_dot_acc -= 0.5
		for k in dots.keys():
			var dps := float(dots[k][0])
			var amt := dps * 0.5 * (1.0 - minf(dr * (0.5 if k == "shock" else 0.0), CombatRules.DR_CAP) / 100.0)   # 전기는 DR 절반 적용
			if amt > 0.0 and not dead:
				lost += amt
				take({"hp": amt, "part": "torso", "dot": k}, last_hit_from)
			dots[k][1] = float(dots[k][1]) - 0.5
			if float(dots[k][1]) <= 0.0:
				dots.erase(k)
	return lost
