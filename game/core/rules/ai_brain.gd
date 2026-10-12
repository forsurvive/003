## 적 AI 상태 층 (SD-11 §7.2). 엔진 무관: 인지 결과(percept)를 받아 상태를 바꾸고 의도를 낸다.
## 인지·상태는 0.1초마다(활성 반경 밖 0.5초), 전술은 0.5초마다 부른다 — 주기는 부르는 쪽(§7.1).
## 이번 판: 대기·의심·수색·교전·놓침·귀환·사망. 도주·항복·광란·무력화는 단계 0에서 붙인다.
class_name AIBrain
extends RefCounted

enum S { IDLE, SUSPICIOUS, SEARCH, COMBAT, LOST, RETURN, DEAD }
const NAMES := ["대기", "의심", "수색", "교전", "놓침", "귀환", "사망"]
const SUSPECT_AT := 40.0
const DETECT_AT := 100.0
const SEARCH_TIME := 12.0
const LOST_AFTER := 4.0
const LOST_TIME := 8.0

var state := S.IDLE
var gauge := 0.0
var home := Vector2.ZERO
var last_seen := Vector2.ZERO
var _t_state := 0.0
var _t_unseen := 0.0
var per := 5.0
var kind := "human"


func _init(home_pos: Vector2 = Vector2.ZERO, perception: float = 5.0, body_kind: String = "human") -> void:
	home = home_pos
	per = perception
	kind = body_kind


func alert() -> bool:
	return state == S.SUSPICIOUS or state == S.SEARCH


## percept = {sees: bool, rate: float (Perception.detect_rate 결과), target: Vector2, hit: bool,
##            sound: float (게이지 가산), sound_at: Vector2, at_home: bool, dead: bool}
## 반환 = 이번 틱의 의도 {goal: "hold"|"face"|"walk_to"|"engage"|"home", at: Vector2}
func tick(dt: float, p: Dictionary) -> Dictionary:
	if p.get("dead", false):
		state = S.DEAD
	if state == S.DEAD:
		return {"goal": "dead"}
	_t_state += dt
	var sees: bool = p.get("sees", false)
	if sees:
		gauge = minf(DETECT_AT, gauge + p.get("rate", 0.0) * dt)
		last_seen = p.get("target", last_seen)
		_t_unseen = 0.0
	else:
		_t_unseen += dt
		if state != S.COMBAT:
			gauge = maxf(0.0, gauge - (5.0 if alert() else 10.0) * dt)
	if p.get("sound", 0.0) > 0.0:
		gauge = minf(DETECT_AT, gauge + p["sound"])
		last_seen = p.get("sound_at", last_seen)
		if state == S.IDLE or state == S.RETURN:
			_go(S.SUSPICIOUS)
	if p.get("hit", false) and state != S.COMBAT:
		gauge = DETECT_AT
		_go(S.COMBAT)
	match state:
		S.IDLE, S.RETURN:
			if gauge >= DETECT_AT:
				_go(S.COMBAT)
			elif gauge >= SUSPECT_AT:
				_go(S.SUSPICIOUS)
			elif state == S.RETURN and p.get("at_home", false):
				_go(S.IDLE)
		S.SUSPICIOUS:
			if gauge >= DETECT_AT:
				_go(S.COMBAT)
			elif _t_state >= 1.0:
				_go(S.SEARCH)
		S.SEARCH:
			if gauge >= DETECT_AT:
				_go(S.COMBAT)
			elif _t_state >= SEARCH_TIME:
				gauge = 0.0
				_go(S.RETURN)
		S.COMBAT:
			if not sees and _t_unseen >= LOST_AFTER:
				_go(S.LOST)
		S.LOST:
			if sees:
				_go(S.COMBAT)
			elif _t_state >= LOST_TIME:
				gauge = 0.0
				_go(S.RETURN)
	match state:
		S.SUSPICIOUS:
			return {"goal": "face", "at": last_seen}
		S.SEARCH, S.LOST:
			return {"goal": "walk_to", "at": last_seen}
		S.COMBAT:
			return {"goal": "engage", "at": last_seen}
		S.RETURN:
			return {"goal": "home", "at": home}
	return {"goal": "hold", "at": home}


func _go(s: int) -> void:
	state = s
	_t_state = 0.0
