## 인카운터 진행(단계 1-3 → 1-E, SD-05 §6.9 실시간 등장 · SD-22 §3 변주): Encounters(판정 규칙)가 고른 RE를 월드에 세우고 끝까지 돌본다.
## 상황(SD-22 §3.1)마다 세우는 모습이 다르다:
##   S1 배회 — 옆 골목(시가지)·뒤·앞에서, 무리가 지점 셋을 천천히 돈다 · S2 매복 — 가는 길 앞 엄폐 칸에 서서 기다린다(감지 ×1.2)
##   S3 먹이·약탈 중 — 앞쪽 유해 둘레에 모여 있다(감지 ×0.5, 다 끝나면 그 유해를 뒤진다) · S4 야영 — 불 드럼·자루, 절반은 잔다
##   S5 싸움 중 — 두 무리가 서로 싸운다(편 enemy·enemy_b, 비적대 편 calm은 주인공을 노리지 않는다 — 때리면 적대로)
##   S6 쫓기는 중 — 피난민·행상이 이쪽으로 달려오고, 뒤에 쫓는 무리 · S7 끝난 뒤 — 유해들과 살아남은 하나(다침)
## 흔적 예고(§3.4): RE에 흔적(sign)이 있거나 야영(S4)이면 본체보다 3~8초 먼저 방향과 함께 알린다(인지력 판정이면 방위 링 점멸).
##   그 사이 주인공이 그쪽에서 멀어지면 '피함'으로 끝난다(안전 간격 절반).
## 비적대 사람(추적대 RE-087 · 순찰 RE-061·064 · 상인 RE-036 · 신참 RE-057 · 피난민 RE-044 · 쓰러진 민병 RE-046)은 걸어오거나 기다리다
##   4타일 안에서 말을 건다(원고 talk) → re fight·run = 전투 개체로 바꿔 세움 · re leave = 돌아서 떠난다.
## 스폰 자리: 같은 높이 단의 걷는 칸, 길이 닿는 칸. 다가오는 무리(S1·S2·S6·사람)는 화면 밖(가로 11 · 세로 7타일 넘게), 시야가 끊긴 칸 먼저.
## 활성 상한(SD-14 §11.7): 위협 1~3 적 12 · 4~5 16, 추적대 5 — 넘으면 다음 판정으로 미룬다.
## 끝: 적대 전멸 · 놓침(살아 있는 적대가 모두 25타일 넘게 떨어지고 시야가 끊김 — 그 무리는 기억된다) · 떠남 · 생포 → Encounters.finished().
## 추적대가 다가오거나 싸우는 동안은 '추격 중'(빠른 이동 F8 · 대기 불가).
class_name EncounterLive
extends Node

signal started(re: String)
signal ended(re: String, how: String)

const SPAWN_MIN := 12
const SPAWN_MAX := 20
const LOST_T := 25.0
const TALK_T := 4.0
const LEAVE_T := 22.0
const CAP := {1: 12, 2: 12, 3: 12, 4: 16, 5: 16}
const CAP_TRACKER := 5
const SIGN_TEXT := {"howl": "%s에서 개 짖는 소리가 들린다", "skitter": "%s에서 무언가 사각거리며 기어 다니는 소리가 난다",
	"groan": "%s에서 낮은 신음 소리가 들린다", "whistle": "%s에서 짧은 호루라기 소리가 울린다", "voices": "%s에서 사람 말소리가 들린다",
	"gunfire": "%s 멀리서 총성이 울린다", "smoke": "%s 하늘로 연기 기둥이 올라간다",
	"squeak": "%s에서 찍찍거리는 소리가 몰려다닌다", "rustle": "%s 쓰레기 더미에서 부스럭거리는 소리가 난다"}
const DIR8 := ["동쪽", "남동쪽", "남쪽", "남서쪽", "서쪽", "북서쪽", "북쪽", "북동쪽"]
## 비적대로 걸어오는 사람 외형(전투 개체가 되면 Enemy가 고른다)
const SHEETS := {"CR-436": "en_cr436_loco", "CR-437": "en_cr437_loco", "CR-401": "en_cr401_loco", "CR-403": "en_cr403_loco",
	"CR-438": "en_cr438_loco", "CR-107": "cr_cr107_loco", "CR-108": "cr_baekgu_loco", "CR-002": "cr_cr002_base_loco",
	"CR-104": "cr_cr104_loco", "CR-105": "cr_cr105_loco"}

var host                                          ## InteriorHost
var rules: Encounters
## 지금 RE: {"re", "def", "cat", "state"(S1~S7), "phase": sign|live|leave, "t", "src", "center", "actors": [Actor](비적대 사람),
##   "foes": [Enemy], "props": [소품], "talked", "talk_by", "note": 칸(RE-042), "sign_t", "half"}
var cur := {}
var flash_t := 0.0                                ## 방위 링 붉은 점멸 남은 초
var walkers: Array = []                           ## 끝난 뒤 떠나가는 비적대 개체 [[Enemy, 남은 초, 목적지]]
## 쫓기다 생성 건물로 들어갔다(1-B4, 설계안 §7.3): {"re", "ids", "beast", "map"(실내 ID), "door"(월드 문 앞 칸), "t", "next"(긁는 소리)}
## 저장하지 않는다 — 불러오면 무리는 잊힌다(길 위 RE와 같다, SD-22 §7 ④)
var pursuit := {}
const PURSUE_R := 12.0                            ## 문 들어설 때 이 안(타일)의 적대만 쫓아온다
const BEAST_WAIT := 60.0                          ## 짐승이 문 앞에서 기다리는 실제 초
const BEASTS := ["CR-002", "CR-095", "CR-097", "CR-104", "CR-105", "CR-106", "CR-108", "CR-136", "CR-107"]
var _path_t := 0.0
var _rng := RandomNumberGenerator.new()
var off := false                                  ## 새 인카운터를 굴리지 않는다(확인 봇이 다른 것을 볼 때 — 시각 난수로 개 떼가 끼어드는 것을 막는다)


func setup(h, seed_v := 0) -> EncounterLive:
	host = h
	rules = Encounters.new(h.st, seed_v)
	_rng.seed = seed_v if seed_v != 0 else Time.get_ticks_usec() + 77
	return self


## 추격 중(SD-12 §5.6 F8 · §7.6 대기 불가): 추적대가 다가오거나 싸우는 동안
func chasing() -> bool:
	return not cur.is_empty() and str(cur.get("cat", "")) == "tracker" and str(cur.get("phase", "")) in ["live"]


func _now() -> int:
	return Clock.abs_min(host.date_text)


func _here() -> Vector2i:
	return host.map.tile_of(host.player.loco.logical)


func _ok() -> bool:
	return not off and host.map is WorldMap and host.clock_running() and cur.is_empty() and not host.story_hold


## 판정 맥락(SD-22 §3.6 · §4.2): 청크 태그 · 길 위계 · 움직임 · 총성 · 시각 · 레벨
func _ctx(t: Vector2i) -> void:
	var c := {"tags": Loot.tags_at(t.x, t.y), "hour": _hour(), "level": host.level(),
		"move": "sneak" if host.combat.crouch else "walk", "shot": host.combat.since_shot}
	if host.map.has_method("road_rank"):
		c["road"] = host.map.road_rank(t)
	rules.ctx = c


func _hour() -> int:
	var s: String = str(host.date_text)
	var hm := s.get_slice("  ", 1) if "  " in s else ""
	return int(hm.get_slice(":", 0)) if hm != "" else 12


# ---------------------------------------------------------------- 판정 기회(진행기·호스트가 부른다)
func tick(dt: float) -> void:
	flash_t = maxf(0.0, flash_t - dt)
	_tick_walkers(dt)
	if not pursuit.is_empty():
		_pursuit_tick(dt)
	if not cur.is_empty():
		_tick_cur(dt)
		return
	if not _ok():
		return
	var t := _here()
	_ctx(t)
	var req := rules.on_move(t, _now(), Clock.is_night(host.date_text), host.map.region_at(t))
	if not req.is_empty():
		start(req)


func on_exit_interior() -> void:
	if not _ok():
		return
	var t := _here()
	_ctx(t)
	var req := rules.on_exit_interior(t, Clock.is_night(host.date_text), host.map.region_at(t))
	if not req.is_empty():
		start(req)


func on_arrive() -> void:
	if not _ok():
		return
	var t := _here()
	_ctx(t)
	var req := rules.on_arrive(t, Clock.is_night(host.date_text), host.map.region_at(t))
	if not req.is_empty():
		start(req)


## 맵이 바뀌었다(문 전환): 다가오던 무리·세운 소품은 사라진다. 다만 싸우던 적대가 문 가까이 있었고 들어간 곳이 생성 건물이면
## 쫓아온다(1-B4) — 사람형은 몇 초 뒤 일부가 문을 열고 들어오고, 짐승은 문 앞에 남는다. 추적대(이야기 사건, P4)는 퀘스트 규칙이 먼저라 넘긴다
func on_map_changed(to_id := "") -> void:
	walkers.clear()
	if not pursuit.is_empty() and str(to_id) != "W" and str(to_id) != str(pursuit["map"]):
		pursuit = {}                                                      # 다른 곳으로 갔다(실내 → 실내)
	if cur.is_empty():
		return
	if str(to_id).begins_with("G-") and str(cur.get("phase", "")) == "live" and str(cur.get("cat", "")) != "tracker" and not host.story_hold:
		var me: Vector2 = host.player.loco.logical
		var ids: Array = []
		var beast := true
		for e in cur.get("foes", []):
			if is_instance_valid(e) and not e.cmb.dead and "player" in e.foes and e.loco.logical.distance_to(me) <= PURSUE_R * 32.0:
				ids.append(str(e.get_meta("enemy_id", "")))
				beast = beast and str(e.get_meta("enemy_id", "")) in BEASTS
		if not ids.is_empty():
			pursuit = {"re": str(cur["re"]), "cat": str(cur["cat"]), "ids": ids, "beast": beast, "map": str(to_id),
				"door": host.map.tile_of(me), "t": 0.0, "next": 2.0, "in": _rng.randf_range(3.0, 6.0)}
	_despawn_actors()
	cur["props"] = []                                                   # 맵이 통째로 바뀌었다(소품 노드도 함께 사라졌다)
	_end("lost")


# ---------------------------------------------------------------- 세우기
## 고가(1-Rd, SD-21 §7.3): 이번 인카운터가 서는 층 — 주인공이 상판 위(층 1)면 무리도 상판 위에(고가 길목), 소장소 자리는 땅
var _efl := 0
var _pick_state := ""
var _pick_cat := ""


## 무리를 세워도 되는 칸: 층 1이면 상판 노면, 층 0이면 같은 높이 단의 걷는 땅
func _ok_tile(t: Vector2i, lv: int) -> bool:
	if _efl >= 1:
		var d: int = host.map.deck_at(t)
		return d == InteriorMap.DK_DECK or d == InteriorMap.DK_PILLAR or d == InteriorMap.DK_BROKEN
	return not host.map.is_solid(t) and host.map.level_at(t) == lv


func start(req: Dictionary) -> bool:
	var re := str(req["re"])
	var d := Encounters.re_def(re)
	if d.is_empty():
		return false
	var night := Clock.is_night(host.date_text)
	var state := str(req.get("state", ""))
	if state == "":
		state = rules.pick_state(re, night)
	var gs := rules.groups(re, host.level(), state)
	var cat := str(d.get("cat", ""))
	var n := 0
	for g in gs:
		n += (g["ids"] as Array).size()
	if cat == "tracker" and n > CAP_TRACKER:
		gs[0]["ids"] = (gs[0]["ids"] as Array).slice(0, CAP_TRACKER)
		n = CAP_TRACKER
	if host.combat.alive_enemies() + n > int(CAP.get(Encounters.threat_at(_here()), 12)):
		return false                                                     # 활성 상한: 다음 판정으로 미룬다
	_efl = host.player.floor_id if host.map.has_deck and not req.has("at") else 0
	_pick_state = state
	_pick_cat = cat
	var mode := _mode(cat, state)
	var center: Vector2i = req["at"] if req.has("at") else _center(mode)       # 소장소 자리(1-W)면 그 자리에
	if center.x < 0:
		return false
	cur = {"re": re, "def": d, "cat": cat, "state": state, "phase": "sign", "t": 0.0, "src": str(req.get("src", "")), "center": center,
		"groups": gs, "actors": [], "foes": [], "props": [], "talked": false, "sign_t": 0.0, "half": false, "site": req.has("at")}
	var sign := str(d.get("sign", ""))
	if state == "S4":
		sign = "smoke"
	if sign != "" and SIGN_TEXT.has(sign) and cat not in ["tracker", "patrol"]:
		cur["sign_t"] = _rng.randf_range(3.0, 8.0)                      # 흔적이 본체보다 3~8초 먼저(SD-22 §3.4)
		var dir := _dir_name(center)
		host.hint(SIGN_TEXT[sign] % dir, 4.0)
		if _rng.randf() < host.st.stat("PE") / 10.0:                   # 인지력 판정 = 방위 링 점멸
			flash_t = 2.4
	else:
		_spawn()
	started.emit(re)
	return true


## 등장 방식(SD-22 §3.3): ahead 앞길 18~26 · alley 옆 골목 10~14 · behind 뒤 14~20 · near 앞 12~18(매복) · any 사람 걸어옴
func _mode(cat: String, state: String) -> String:
	if cat in ["tracker", "patrol"]:
		return "any"
	match state:
		"S2":
			return "near"
		"S3", "S4", "S5", "S7":
			return "ahead"
		"S6":
			return "ahead"
	var tags: Array = rules.ctx.get("tags", [])
	if ("구도심" in tags or "시장" in tags) and _rng.randf() < 0.6:
		return "alley"
	return "behind" if _rng.randf() < 0.4 else "ahead"


## 중심 칸 찾기: 방식의 방향·거리에서 같은 높이 단의 걷는 칸, 길이 닿는 칸. 다가오는 방식은 화면 밖·시야 끊긴 칸 먼저
func _center(mode: String) -> Vector2i:
	var me := _here()
	var lv: int = host.map.level_at(me)
	var me_px: Vector2 = host.player.loco.logical
	var fwd: Vector2 = Locomotion.VEC[host.player.loco.facing].normalized()
	var base := fwd.angle()
	var rr := [SPAWN_MIN, SPAWN_MAX]
	var spread := PI
	var offscreen := true
	var want_hidden := true
	match mode:
		"ahead":
			rr = [18, 26]
			spread = 0.7
			offscreen = false
			want_hidden = false
		"near":
			rr = [12, 18]
			spread = 0.5
		"behind":
			rr = [14, 20]
			base += PI
			spread = 0.8
		"alley":
			rr = [10, 14]
			base += PI / 2.0 * (1.0 if _rng.randf() < 0.5 else -1.0)
			spread = 0.6
	var best := Vector2i(-1, -1)
	var best_score := -1
	for i in 18:
		var ang := base + _rng.randf_range(-spread, spread)
		var r := _rng.randi_range(int(rr[0]), int(rr[1]))
		var t := me + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r))
		if offscreen and absi(t.x - me.x) <= 11 and absi(t.y - me.y) <= 7:
			continue
		if not _ok_tile(t, lv):
			continue
		var hidden: bool = not host.map.line_of_sight(me_px, Vector2(t) * 32.0 + Vector2(16, 16))
		var score := 2 if (hidden == want_hidden) else 1
		var top := 2
		if _efl == 0 and host.map.has_deck and _pick_state == "S2":           # 매복은 고가 아래 그늘을 좋아한다(SD-21 §7.3)
			top = 3
			score += 1 if InteriorMap.is_top(host.map.deck_at(t)) else 0
		elif _pick_cat in ["tracker", "patrol"] and host.map.has_method("road_rank"):   # 추적대·순찰은 큰길(H2·H3) 위
			top = 3
			score += 1 if host.map.road_rank(t) >= 2 else 0
		if score > best_score and _reachable(me_px, t):
			best_score = score
			best = t
			if score >= top:
				break
	if best.x < 0 and mode != "any":                                   # 방향이 막혔으면(벼랑·강) 아무 쪽에서나
		return _center("any")
	return best


## 길이 닿나(칸 A* — 26타일 안팎이면 충분하다)
func _reachable(from_px: Vector2, t: Vector2i) -> bool:
	return not host.map.path(Vector2(t) * 32.0 + Vector2(16, 16), from_px, 1200, _efl, host.player.floor_id).is_empty()


## 중심 둘레 걷는 칸 n개(서로 한 칸 띄움, 같은 높이 단)
func _cluster(c: Vector2i, n: int, gap := 1) -> Array:
	var lv: int = host.map.level_at(c)
	var out: Array = []
	var seen := {c: true}
	var q: Array = [c]
	while not q.is_empty() and out.size() < n:
		var t: Vector2i = q.pop_front()
		var ok: bool = _ok_tile(t, lv)
		if ok:
			var far := true
			for o in out:
				if absi((o as Vector2i).x - t.x) <= gap - 1 and absi((o as Vector2i).y - t.y) <= gap - 1:
					far = false
			if far:
				out.append(t)
		if t.distance_to(c) > 6.0 or (not ok and t != c):
			continue
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nt: Vector2i = t + dd * 1
			if not seen.has(nt):
				seen[nt] = true
				q.append(nt)
	return out


## 걷는 칸 하나(중심에서 r 안팎, 걷는 지점 — S1 배회 경로)
func _walk_tile(c: Vector2i, r: int) -> Vector2i:
	var lv: int = host.map.level_at(c)
	for i in 10:
		var ang := _rng.randf() * TAU
		var t := c + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r))
		if _ok_tile(t, lv) and not host.map.path(Vector2(c) * 32.0 + Vector2(16, 16), Vector2(t) * 32.0 + Vector2(16, 16), 400, _efl, _efl).is_empty():
			return t
	return c


func _dir_name(t: Vector2i) -> String:
	var v := Vector2(t - _here())
	var i := posmod(roundi(v.angle() / (PI / 4.0)), 8)
	return DIR8[i]


static func _facing_to(from: Vector2i, to: Vector2i) -> int:
	return Locomotion.snap8(Vector2(to - from), 0.0)


## 편 이름(교전): 적대 a=enemy · b=enemy_b, 비적대 a=calm · b=calm_b
static func _team(side: String, hostile: bool) -> String:
	return ("enemy" if hostile else "calm") + ("" if side == "a" else "_b")


## 흔적 뒤(또는 곧바로) 본체를 세운다
func _spawn() -> void:
	cur["phase"] = "live"
	cur["t"] = 0.0
	var d: Dictionary = cur["def"]
	var state := str(cur["state"])
	var c: Vector2i = cur["center"]
	var cat := str(cur["cat"])
	var gs: Array = cur["groups"]
	var me := _here()
	var talk := str(d.get("talk", ""))
	if gs.is_empty():                                                    # 사람 없는 장면(RE-042 시체와 쪽지): 유해 하나 + 쪽지
		var b := _corpse_box(c, "", "떠돌이의 유해")
		cur["note"] = c if not b.is_empty() else Vector2i(-1, -1)
		return
	var clash := gs.size() > 1 and cat == "clash"
	var teams: Array = []
	for g in gs:
		teams.append(_team(str(g["side"]), bool(g["hostile"])))
	# 무리별 자리: 교전·쫓김은 두 무리를 떼어 놓는다
	var perp := Vector2(c - me).orthogonal().normalized()
	var along := Vector2(c - me).normalized()
	for gi in gs.size():
		var g: Dictionary = gs[gi]
		var ids: Array = g["ids"]
		if ids.is_empty():
			continue
		var gc := c
		if clash:
			gc = c + Vector2i((perp * (3.5 if gi == 0 else -3.5)).round())
		elif state == "S6" and gi > 0:
			gc = c + Vector2i((along * 8.0).round())                    # 쫓는 무리는 쫓기는 쪽 뒤(주인공에게서 더 멀리)
		elif gi > 0:
			gc = c + Vector2i((perp * 3.0).round())
		gc = _snap_walk(gc, c)
		var spots := _cluster(gc, ids.size(), 2 if state in ["S4", "S3"] else 1)
		if spots.size() < ids.size():
			spots = _cluster(gc, ids.size(), 1)
		var people: bool = not bool(g["hostile"]) and talk != "" and not clash
		for i in mini(ids.size(), spots.size()):
			var id := str(ids[i])
			var at: Vector2 = Vector2(spots[i]) * 32.0 + Vector2(16, 16)
			if people:
				_add_person(id, at, state)
				continue
			var foes: Array = []
			if bool(g["hostile"]):
				foes = ["player", "ally"]
			for oi in teams.size():
				if oi != gi and clash:
					foes.append(teams[oi])
					foes.append(_team(str(gs[oi]["side"]), true))       # 상대가 도발로 적대가 되어도 계속 노린다
			var opts := {"lv": host.level(), "team": teams[gi], "foes": foes, "hurt": float(g["hurt"][i]) if i < (g["hurt"] as Array).size() else 0.0,
				"morale": not d.has("capture")}                               # 1-9e 사기(도주·항복): 길 위 무리는 꺾인다 · 생포조는 이야기 사건이라 끝까지

			match state:
				"S2":
					opts["det"] = 1.2
				"S3":
					opts["det"] = 0.5
				"S4":
					opts["det"] = 0.6
					opts["sleep"] = i % 2 == 1 or _rng.randf() < 0.3
			var e: Enemy = host.combat.spawn(id, at, host.map, host.st, opts)
			e.set_floor(_efl)
			if state == "S7" and i > 0:                                  # 끝난 뒤: 하나만 살아 있고 나머지는 쓰러진 채(유해 용기는 호스트가 둔다, 경험치 없음)
				e.cmb.last_by = "world"
				e.cmb.take({"hp": 99999.0}, at)
				continue
			e.set_meta("re", cur["re"])
			if d.has("capture"):
				e.set_meta("capture", str(d["capture"]))
			_place_state(e, state, spots[i], c, gc, me)
			if e.asleep and e.style != "dog" and e.style != "swarm":
				cur["props"].append(host.map.add_runtime_prop("straw_mat" if _rng.randf() < 0.5 else "straw_mat2", spots[i]))   # 잠든 자리 거적
			if clash:
				e.brain.state = AIBrain.S.COMBAT                          # 이미 싸우는 중(S5)
				e.brain.gauge = 100.0
			cur["foes"].append(e)
	match state:
		"S3":                                                            # 먹이·약탈 중: 가운데 유해(다 끝나면 뒤진다)
			_corpse_box(_snap_walk(c, c), "", "누군가의 유해")
		"S4" when not bool(cur.get("site", false)) and _efl == 0:             # 상판 위(층 1)에는 불 드럼·자루를 두지 않는다                      # 야영: 불 드럼 + 자루(소장소 자리면 이미 놓여 있다)
			var fire := _free_near(c)
			if fire.x >= 0:
				cur["props"].append(host.map.add_runtime_prop("drum_fire", fire))
			var sack := _free_near(c + Vector2i(2, 0))
			if sack.x >= 0:
				var key := "re:%s:%d,%d@%d:%d" % [cur["re"], sack.x, sack.y, int(host.st.vars.get_v("GAME_DAY")), Time.get_ticks_msec()]
				var owner := ""
				for g in gs:
					if not bool(g["hostile"]) and not (g["ids"] as Array).is_empty() and str(g["ids"][0]).begins_with("N-"):
						owner = str(g["ids"][0])                             # 상인의 야영 자루는 그 사람 것(훔치면 장물)
				host.map.boxes[sack] = {"x": sack.x, "y": sack.y, "w": 1, "h": 1, "kind": "camp", "name": "야영지 보급 자루", "owner": owner,
					"lock": 0, "cond": "", "key": key}
				cur["props"].append(host.map.add_runtime_prop("pallet_sacks", sack))
		"S5", "S7":
			for k in _rng.randi_range(1, 2):                              # 싸운 자리의 유해(지나가던 사람)
				_corpse_box(_free_near(c + Vector2i(_rng.randi_range(-3, 3), _rng.randi_range(-3, 3))), "", "누군가의 유해")


## 상황별 자세(S1 배회 경로 · S2 매복 엄폐 · S3 둘러섬 · S4 불가 · S7 다쳐 앉음)
func _place_state(e: Enemy, state: String, t: Vector2i, c: Vector2i, gc: Vector2i, me: Vector2i) -> void:
	match state:
		"S1":
			var a := _walk_tile(gc, 6)
			var b := _walk_tile(gc, 6)
			e.route = [[Vector2(gc) * 32.0 + Vector2(16, 16), 2.0], [Vector2(a) * 32.0 + Vector2(16, 16), 2.5], [Vector2(b) * 32.0 + Vector2(16, 16), 2.0]]
		"S2":
			e.stance = "hold"
			e.hold_dir = _facing_to(t, me)
			e.brain.home = e.loco.logical
		"S3", "S4":
			if not e.asleep:
				e.stance = "hold"
				e.hold_dir = _facing_to(t, c) if t != c else _rng.randi_range(0, 7)
		"S6":                                                            # 쫓는 무리: 쫓기는 사람이 달아난 쪽(주인공 쪽)으로 걸어온다
			e.route = [[Vector2(c) * 32.0 + Vector2(16, 16), 1.0], [Vector2(me) * 32.0 + Vector2(16, 16), 4.0]]
		"S7":
			e.set_pose("sit")
			e.stance = "hold"
			e.hold_dir = _facing_to(t, me)
	e.loco.facing = e.hold_dir if e.stance == "hold" else e.loco.facing
	e._show()


## 비적대 사람(Actor): 사람은 걸어오고(S1·S6), 쓰러진 민병은 누워 있고, 야영 상인은 불 곁에서 기다린다
func _add_person(id: String, at: Vector2, state: String) -> void:
	var a := Actor.new()
	var fs: Dictionary = Encounters.data.get("friendly_sheet", {})
	var sheet := str(fs.get(id, SHEETS.get(id, "en_%s_loco" % id.to_lower().replace("-", ""))))
	if id.begins_with("N-") and _rng.randf() < 0.5 and ResourceLoader.exists("res://assets/sprites/%s.tres" % sheet.replace("_loco", "_b_loco")):
		sheet = sheet.replace("_loco", "_b_loco")                       # 무명 인물 두 외형(같은 사람이 매번 같은 얼굴이 아니게)
	if not ResourceLoader.exists("res://assets/sprites/%s.tres" % sheet) and SHEETS.has(id):
		sheet = SHEETS[id]
	a.setup(sheet, at, host.map)
	a.set_floor(_efl)
	a.mode = "walk"
	a.set_meta("cr", id)
	host.map.add_actor(a)
	if id == "N-DOWNED":
		a.set_pose("lie")
		a.set_meta("wait", true)
	elif state in ["S4", "S7"]:
		a.set_meta("wait", true)
	a.loco.facing = _facing_to(host.map.tile_of(at), _here())
	a._show()
	cur["actors"].append(a)
	if str(cur["cat"]) == "tracker" and cur["actors"].size() == 1 and _rng.randf() < host.st.stat("PE") / 10.0:   # 인지력 판정(정합: 인지력 × 10%)
		flash_t = 2.4
		host.hint("추격자가 다가옵니다", 3.0)


## 유해 용기(S3·S5·S7·RE-042): 적 ID가 있으면 그 적의 소지품, 없으면 떠돌이 유해(청소부 용기 표)
func _corpse_box(t: Vector2i, eid: String, name: String) -> Dictionary:
	if t.x < 0 or host.map.boxes.has(t) or (_efl == 0 and host.map.is_solid(t)):
		return {}
	var key := "re:%s:%d,%d@%d:%d" % [str(cur.get("re", "")), t.x, t.y, int(host.st.vars.get_v("GAME_DAY")), Time.get_ticks_msec()]
	var b := {"x": t.x, "y": t.y, "w": 1, "h": 1, "owner": "", "lock": 0, "cond": "", "key": key}
	if eid != "" and Loot.drops.has(eid) and eid not in ["CR-002", "CR-104"]:
		b.merge({"kind": "_corpse", "eid": eid, "name": str(host.combat.enemy_rows.get(eid, {}).get("name", "적")) + "의 유해"})
	elif eid != "":
		return {}                                                        # 드롭이 없는 크리처(바퀴·들개)는 유해를 두지 않는다
	else:
		b.merge({"kind": "corpse_scav", "name": name})
		var rp: Dictionary = host.map.add_runtime_prop("remains" if _rng.randf() < 0.5 else "remains2", t)   # 쓰러진 사람 그림(유해 용기)
		if _efl >= 1 and not rp.is_empty():
			rp["node"].z_index = 3                                           # 상판 위 유해는 상판 위에 그린다
			for cc in rp.get("cells", []):
				host.map._put_solid(cc.x, cc.y, 0)                           # 땅을 막지 않는다(상판 위 그림일 뿐)
			rp["cells"] = []
		cur["props"].append(rp)
	host.map.boxes[t] = b
	return b


func _free_near(c: Vector2i) -> Vector2i:
	for t in _cluster(c, 6, 1):
		if not host.map.boxes.has(t) and t != _here():
			return t
	return Vector2i(-1, -1)


func _snap_walk(t: Vector2i, fallback: Vector2i) -> Vector2i:
	var lv: int = host.map.level_at(fallback)
	if _ok_tile(t, lv):
		return t
	var near := _cluster(t, 1, 1)
	return near[0] if not near.is_empty() and _ok_tile(near[0], lv) else fallback


# ---------------------------------------------------------------- 돌보기
func _tick_cur(dt: float) -> void:
	cur["t"] = float(cur["t"]) + dt
	match str(cur["phase"]):
		"sign":
			_sign(dt)
		"live":
			_live(dt)
		"leave":
			_leave(dt)


## 흔적 뒤: 주인공이 그쪽에서 멀리 벗어났으면 피함(안전 간격 절반), 아니면 본체를 세운다
func _sign(dt: float) -> void:
	if host.box.active or host.busy or host.ev.busy():
		return
	cur["sign_t"] = float(cur["sign_t"]) - dt
	var c: Vector2i = cur["center"]
	if Vector2(c - _here()).length() > SPAWN_MAX + 14:
		cur["half"] = true
		_end("avoided")
		return
	if float(cur["sign_t"]) <= 0.0:
		_spawn()


func _live(dt: float) -> void:
	var me: Vector2 = host.player.loco.logical
	# 쪽지 유해(RE-042): 곁에 서면 한 번 읽는다
	var note: Vector2i = cur.get("note", Vector2i(-1, -1))
	if note.x >= 0 and not bool(cur["talked"]) and Vector2(note - _here()).length() <= 1.5 and not host.box.active and not host.busy:
		cur["talked"] = true
		host.play_scene(str(cur["def"]["talk"]))
	if note.x >= 0:
		if bool(cur["talked"]) or Vector2(note - _here()).length() > SPAWN_MAX + 14:
			_end("left" if bool(cur["talked"]) else "lost")
		return
	# 사람: 다가와 말을 건다
	if not cur["actors"].is_empty() and not bool(cur["talked"]):
		_approach(dt)
	if cur.is_empty():
		return
	_fight_check()


## 다가온다(칸 길찾기, 0.5초마다 한 명씩 다시). 4타일 안이면 멈춰 서서 말을 건다. 기다리는 사람(누운 민병·야영 상인)은 주인공이 와야 한다
func _approach(dt: float) -> void:
	var me: Vector2 = host.player.loco.logical
	var lead: Actor = cur["actors"][0]
	if not is_instance_valid(lead):
		_end("lost")
		return
	if host.box.active or host.busy or host.ev.busy() or host.pipboy != null:
		for a in cur["actors"]:
			if is_instance_valid(a):
				a.move(Vector2.ZERO, dt)
		return
	var waiting := bool(lead.get_meta("wait", false))
	var reach := TALK_T * (1.6 if waiting else 1.0) * 32.0
	var dl: float = lead.loco.logical.distance_to(me)
	if dl < float(lead.get_meta("best", 1.0e9)) - 4.0:                # 더 다가가지 못하고 1.5초 = 담·난간 너머(시야 안 7타일이면 거기서 말을 건다)
		lead.set_meta("best", dl)
		lead.set_meta("still", 0.0)
	else:
		lead.set_meta("still", float(lead.get_meta("still", 0.0)) + dt)
	var stuck: bool = not waiting and float(lead.get_meta("still", 0.0)) >= 1.5 and dl <= 7.0 * 32.0 and host.map.line_of_sight(lead.loco.logical, me)
	if (dl <= reach or stuck) and not _foes_near(me, 9.0):
		for a in cur["actors"]:
			if is_instance_valid(a):
				a.move(Vector2.ZERO, dt)
				if not bool(a.get_meta("wait", false)):
					a.loco.facing = Locomotion.snap8(me - a.loco.logical)
				a._show()
		cur["talked"] = true
		host.play_scene(str(cur["def"]["talk"]))
		return
	if lead.loco.logical.distance_to(me) > (SPAWN_MAX + 14) * 32.0:     # 주인공이 멀리 갔다(다가오는 중의 놓침)
		_despawn_actors()
		if cur["foes"].is_empty():
			_end("lost")
		return
	if waiting:
		return
	_path_t -= dt
	for i in cur["actors"].size():
		var a: Actor = cur["actors"][i]
		if not is_instance_valid(a):
			continue
		var goal := me + Vector2(((i % 3) - 1) * 28.0, (i / 3) * 28.0)
		if (_path_t <= 0.0 and i == int(float(cur["t"]) * 2.0) % cur["actors"].size()) or not a.has_meta("path"):
			var np: PackedVector2Array = host.map.path(a.loco.logical, goal, 900)
			np.insert(0, a.loco.logical)
			a.set_meta("path", np)
			a.set_meta("pi", 0)
		_follow(a, dt)
	if _path_t <= 0.0:
		_path_t = 0.5


func _foes_near(me: Vector2, tiles: float) -> bool:
	for e in cur["foes"]:
		if is_instance_valid(e) and not e.cmb.dead and "player" in e.foes and e.brain.state == AIBrain.S.COMBAT and e.loco.logical.distance_to(me) <= tiles * 32.0:
			return true
	return false


func _follow(a: Actor, dt: float) -> void:
	var p: PackedVector2Array = a.get_meta("path", PackedVector2Array())
	var i := int(a.get_meta("pi", 0))
	while i < p.size() and a.loco.logical.distance_to(p[i]) < 10.0:
		i += 1
	a.set_meta("pi", i)
	if i >= p.size():
		a.move(Vector2.ZERO, dt)
		return
	a.move(a.steer((p[i] - a.loco.logical).normalized()), dt)         # 막히면 돌아서 걷는다(벽 비비기 없음, Sweep.steer)


## 원고 명령 re fight · run · leave · surrender
func cmd(what: String) -> void:
	if cur.is_empty():
		return
	match what:
		"fight", "run":
			var cap := str(cur["def"].get("capture", ""))
			var keep: Array = []
			for a in cur["actors"]:
				if not is_instance_valid(a):
					continue
				var id := str(a.get_meta("cr"))
				if not id.begins_with("CR-"):                             # 무명 사람(피난민·상인)은 싸움이 나면 달아난다
					keep.append(a)
					continue
				var e: Enemy = host.combat.spawn(id, a.loco.logical, host.map, host.st, {"lv": host.level()})
				e.brain.state = AIBrain.S.COMBAT
				e.brain.gauge = 100.0
				if cap != "":
					e.set_meta("capture", cap)                         # 생포 분대: 주인공을 쓰러뜨리면 생포(SD-03a §6.7)
				e.set_meta("re", cur["re"])
				cur["foes"].append(e)
				a.queue_free()
			cur["actors"] = keep
			cur["talked"] = true
			for a in keep:
				a.set_meta("flee", true)
			if str(cur["cat"]) == "tracker":
				Wanted.seen_wearing(host.st, host.worn())                # 추적대가 본 옷으로 공고 인상착의를 고친다(SD-12 §9.7)
		"leave":
			cur["talked"] = true
			for a in cur["actors"]:
				if is_instance_valid(a):
					a.set_meta("flee", true)
					if a.pose == "lie":
						a.set_pose("stand")                              # 일어나 떠난다(쓰러진 민병은 스팀팩을 받았다)
			cur["leave_t"] = 0.0
		"surrender":                                                     # 손을 내민다(MQ-105 '일부러 잡힌다', SD-03a §8.5): 싸움 없이 생포
			_despawn_actors()
			cur["phase"] = "leave"
			cur["t"] = 99.0
			host.capture.call_deferred("SB")


## 떠나는 사람: 주인공에게서 멀어지며 22타일 넘거나 20초가 지나면 사라진다
func _flee(dt: float) -> void:
	var me: Vector2 = host.player.loco.logical
	cur["leave_t"] = float(cur.get("leave_t", 0.0)) + dt
	for a in cur["actors"].duplicate():
		if not is_instance_valid(a) or not bool(a.get_meta("flee", false)):
			continue
		var away: Vector2 = (a.loco.logical - me)
		if away.length() < LEAVE_T * 32.0 and float(cur["leave_t"]) < 20.0:
			a.move(a.steer(away.normalized()), dt)
		else:
			a.queue_free()
			cur["actors"].erase(a)


func _leave(dt: float) -> void:
	_flee(dt)
	if cur.is_empty():
		return
	if cur["actors"].is_empty() or float(cur["t"]) > 20.0:
		_despawn_actors()
		_end("left")


## 싸움 살피기: 주인공을 노리는 적대가 다 쓰러지면 끝(교전 비적대 생존자는 걸어 떠난다), 모두 멀어지고 시야가 끊기면 놓침(기억)
## 쫓김 이어짐(1-B4): 실내에선 사람형이 들어오고(문 앞 칸) 짐승은 긁는다 · 밖으로 나오면 기다리던 짐승이 문 앞에 · 시간이 지나면 흩어짐
func _pursuit_tick(dt: float) -> void:
	var p := pursuit
	p["t"] = float(p["t"]) + dt
	var in_map: bool = host.map != null and not (host.map is WorldMap) and str(host.map.id) == str(p["map"])
	if in_map and not bool(p["beast"]):
		if float(p["t"]) >= float(p["in"]):
			var n := maxi(1, int(ceil((p["ids"] as Array).size() * 0.6)))
			var m: Array = host.map.marks.get("from_W", [])
			if m.is_empty():
				pursuit = {}
				return
			var at := Vector2(int(m[0]) * 32 + 16, int(m[1]) * 32 + 16)
			for i in n:
				var e: Enemy = host.combat.spawn(str(p["ids"][i]), at + Vector2((i % 2) * 32, 0), host.map, host.st,
					{"lv": host.level(), "team": "enemy", "foes": ["player", "ally"], "morale": true})
				e.brain.state = AIBrain.S.COMBAT
				e.brain.gauge = 100.0
			host.hint("문이 벌컥 열린다 — 쫓아 들어왔다.", 3.0)
			rules.remember_pack(str(p["re"]), [])
			pursuit = {}
		return
	if in_map:                                                            # 짐승: 문 밖에서 긁는다
		if float(p["t"]) >= float(p["next"]) and float(p["t"]) < BEAST_WAIT:
			p["next"] = float(p["t"]) + 9.0
			host.hint("문 밖에서 긁는 소리가 난다. 아직 기다린다.", 2.5)
		elif float(p["t"]) >= BEAST_WAIT:
			host.hint("긁는 소리가 멎었다. 발소리가 멀어진다.", 3.0)
			if str(p["cat"]) in ["creature", "raider", "clash"]:
				rules.remember_pack(str(p["re"]), p["ids"])               # 놓친 무리로 기억(SD-22 §3.5)
			pursuit = {}
		return
	if host.map is WorldMap and bool(p["beast"]) and float(p["t"]) < BEAST_WAIT:   # 같은 문으로 나왔다: 기다리던 짐승
		var door: Vector2i = p["door"]
		var me := _here()
		if me.distance_to(door) <= 3.0:
			var spots := _cluster(_snap_walk(door + Vector2i(0, 3), door), (p["ids"] as Array).size(), 1)
			for i in mini(spots.size(), (p["ids"] as Array).size()):
				var e: Enemy = host.combat.spawn(str(p["ids"][i]), Vector2(spots[i]) * 32.0 + Vector2(16, 16), host.map, host.st,
					{"lv": host.level(), "team": "enemy", "foes": ["player", "ally"], "morale": true})
				e.brain.state = AIBrain.S.COMBAT
				e.brain.gauge = 100.0
			host.hint("문 앞에서 기다리고 있었다!", 3.0)
		pursuit = {}
	elif host.map is WorldMap:
		pursuit = {}


func _fight_check() -> void:
	_flee(get_process_delta_time())
	if cur.is_empty():
		return
	var foes: Array = cur["foes"].filter(func(e): return is_instance_valid(e) and not e.cmb.dead)
	var hostile: Array = foes.filter(func(e): return "player" in e.foes)
	var talking: bool = not cur["actors"].is_empty() and not bool(cur["talked"])
	if hostile.is_empty() and not talking and cur["actors"].is_empty():
		var any_fought: bool = cur["foes"].size() > foes.size()
		if foes.is_empty() or any_fought or (float(cur["t"]) > 4.0 and _all_far(foes, 18.0)):
			for e in foes:                                               # 비적대 생존자(교전의 계엄 분대 등)는 걸어 떠난다
				_walk_off(e)
			rules.remember_pack(str(cur["re"]), [])
			_end("cleared" if any_fought else "left")
		return
	if hostile.is_empty():
		return
	var me: Vector2 = host.player.loco.logical
	for e in hostile:
		if e.loco.logical.distance_to(me) <= LOST_T * 32.0 or host.map.line_of_sight(e.loco.logical, me):
			return
	var ids: Array = []
	for e in hostile:                                                # 놓침: 모두 25타일 밖 + 시야 끊김(SD-11 §2.5) — 남은 무리를 기억한다(SD-22 §3.5)
		ids.append(str(e.get_meta("enemy_id", "")))
	for e in foes:
		host.combat.drop_enemy(e)
	_despawn_actors()
	if str(cur["cat"]) in ["creature", "raider", "clash"]:
		rules.remember_pack(str(cur["re"]), ids)
	_end("lost")


func _all_far(foes: Array, tiles: float) -> bool:
	var me: Vector2 = host.player.loco.logical
	for e in foes:
		if e.loco.logical.distance_to(me) <= tiles * 32.0:
			return false
	return true


## 끝난 RE의 비적대 개체를 걸어 떠나게 한다(20초 뒤 또는 22타일 밖에서 치운다)
func _walk_off(e: Enemy) -> void:
	var me: Vector2 = host.player.loco.logical
	var away: Vector2 = (e.loco.logical - me).normalized()
	var goal: Vector2 = e.loco.logical + away * 16.0 * 32.0
	e.route = [[goal, 30.0]]
	e.stance = ""
	walkers.append([e, 20.0])


func _tick_walkers(dt: float) -> void:
	if walkers.is_empty():
		return
	var me: Vector2 = host.player.loco.logical
	for w in walkers.duplicate():
		var e: Enemy = w[0]
		w[1] = float(w[1]) - dt
		if not is_instance_valid(e) or e.cmb.dead:
			walkers.erase(w)
			continue
		if "player" in e.foes:                                           # 떠나다 맞아서 적대가 됐다: 그냥 싸움으로 둔다
			walkers.erase(w)
			continue
		if float(w[1]) <= 0.0 or e.loco.logical.distance_to(me) > LEAVE_T * 32.0:
			host.combat.drop_enemy(e)
			walkers.erase(w)


## 생포로 끝났다(호스트가 부른다)
func captured() -> void:
	if cur.is_empty():
		return
	for e in cur["foes"]:
		if is_instance_valid(e):
			e.queue_free()
	_end("captured")


func _despawn_actors() -> void:
	for a in cur.get("actors", []):
		if is_instance_valid(a):
			host.map.remove_actor(a)
			a.queue_free()
	cur["actors"] = []


func _end(how: String) -> void:
	var re := str(cur.get("re", ""))
	var half := bool(cur.get("half", false))
	cur = {}
	rules.finished(half)
	ended.emit(re, how)
