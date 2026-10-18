## 보관 자리 · 털림 · 비표시 퀘스트 UQ-125 「털린 은닉처」 진행기(단계 1-L, 계획 `_plans/1-L_loot_stash_plan.md` §3 · §5 · §9.3 · §9.4 ·
## SD-05 §3.20). 원고: script/act1/UQ-125.txt(아이 · 잠복) · script/encounters/TRADERS.txt(장물아비 '내 물건이다').
## 사실은 한 곳(P1): st.boxes["stash"] = {spots: 내 자리 · bundles: 털린 묶음(행방 · 상태) · seen: 맵마다 마지막으로 들른 날 · qb: 퀘스트가 붙은 묶음}.
##   장면이 읽는 변수(UQ125_WHO · HERE · KID · GUARD · R)는 여기서만 쓴다. 털림은 06:00 하루 판정에서만(P6) — 생포 중 · 볼트 시대는 쉰다(P5).
## 내 자리: 생성 실내(G-) · 길가(W)의 주인 없는 용기를 비운 뒤 '삼는다'(최대 8곳) · 다시 차지 않는다 · 퀘스트 물건은 가져가지 않는다(P10).
## 범인 셋(§3.3): 아이(정착지 둘레 위협 1 — 가까운 조용한 빈집) · 털이꾼(가까운 털이 소굴 — 밤엔 잔다) · 장물아비(값진 물건 — 가까운 다시 문 연 가게 진열).
class_name Stash
extends Node

const QID := "UQ-125"
const MAX_SPOTS := 8
const GRACE := 3                           ## 첫 삼기 뒤 판정 없는 날(§9.3 '잊을 무렵')
const MIN_VALUE := 10                      ## 이보다 싼 것만 든 자리는 아무도 노리지 않는다(§6 #2)
const CLAIM_KINDS := ["safe", "cabinet", "apartment", "crate", "desk", "locker", "toolbox", "stash", "pantry", "stall", "conv", "pharmacy"]
const P_TH := {1: 0.03, 2: 0.018, 3: 0.009}
const BELL := "M-195"
const KID := "N-UQ-K1"
const KID_LOOK := "K1-S1-HR09-H2-T01-0-PF11-HD00-EY00"
const CREW := "N-UQ-C1"
const CREW_LOOK := "M2-S4-HR01-H1-T03-2-PF00-HD05-EY00"
const XP := {1: 70, 2: 90, 3: 110}
const HELD_DAYS := 7                       ## 아이는 먹을 것을 다 먹고 · 털이꾼은 장물로 넘긴다
const SOLD_DAYS := 14                      ## 장물이 팔린다
const GONE_DAYS := 30                      ## 행방이 끝난다(소멸)
const GUARDS := [["C-057", "AFF_JC_BC", "하숙자"], ["N-R01-046", "AFF_JC_SA", "탁순복"]]   ## 아이를 맡길 수 있는 사람(살아 있고 적대가 아님)
const GONE_LINE := {"kid": "빈집 쪽 골목이 조용하다. 사탕 껍질도, 맨발 자국도 이제 없다 — 그 아이는 다른 데로 갔다.",
	"crew": "소굴 쪽에서 들은 말: '그 자루? 진작 넘겼지.' 내 물건은 이제 누구 손에 있는지 모른다.",
	"fence": "그 가게 진열이 바뀌었다. 긁힌 자국 난 물건은 하나도 없다 — 팔렸다.",
	"gone": "털린 자리는 그대로다. 찾을 길은 끝났다."}
const CREW_T := "calm_uq125"                ## 낮의 털이꾼 소굴 · 잠복 털이꾼: 먼저 치거나 자루에 손대기 전엔 말이 통한다
const TRADE_V := {"scrap": "VG_SCRAP", "herb": "VG_HERB", "parts": "VG_PARTS", "cloth": "VG_CLOTH", "food": "VG_FOOD", "drift": "VG_DRIFT"}

var host: InteriorHost
var st: StoryState
var _talk_due := false                     ## 낮 소굴에 들어섰다 — 안전한 순간에 털이꾼 장면(UQ125_CREW)
var _t := 0.0
var log_on := false
var _hide := {}
var _traders := {}


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.stash = self
	host.ev.handlers["stash"] = _cmd
	host.day_tick.connect(_on_day)
	host.map_entered.connect(_on_map)
	if not st.npcs.has(KID):                                           # 아이는 공격 대상이 아니다(SD-11 · StoryState.is_child: 외형 K)
		st.npcs[KID] = {"name": "아이"}
	st.npcs[KID]["look"] = KID_LOOK
	if not st.npcs.has(CREW):                                          # 털이꾼 말 상대(UQ125_CREW 초상)
		st.npcs[CREW] = {"name": "털이꾼"}
	st.npcs[CREW]["look"] = CREW_LOOK
	for f in [["res://data/world/hideouts.json", "_hide"], ["res://data/world/traders.json", "_traders"]]:
		if FileAccess.file_exists(f[0]):
			set(f[1], JSON.parse_string(FileAccess.get_file_as_string(f[0])))


func _process(dt: float) -> void:
	_t += dt
	if _t < 0.4 or not _talk_due:
		return
	_t = 0.0
	if host.map == null or not _safe():
		return
	_talk_due = false
	if _crew_calm().is_empty():
		return
	st.portrait_alias[CREW] = "st_look_" + CREW_LOOK.to_lower().replace("-", "_")   # 말 상대 초상(맵 인물이 아니라 무리의 목소리)
	host.play_scene("UQ125_CREW")


func _safe() -> bool:
	if host.box.active or host.ev.busy() or host.busy or host.story_hold or host.locked:
		return false
	return host.pipboy == null and host.container == null and host.wait_ui == null and host.terminal == null and host.lockpick == null


func _crew_calm() -> Array:
	return host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == CREW_T)


## 말이 끝났다(자루에 손댐 · 장면에서 싸움을 고름): 같은 무리 모두 적으로
func _crew_turn() -> void:
	for e in _crew_calm():
		e.cmb.team = "enemy_uq125"
		e.foes = ["player", "ally"]
		e.wake()


func _log(s: String) -> void:
	if log_on:
		print("[은닉처] " + s)


func v(k: String) -> int:
	return int(st.vars.get_v("UQ125_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("UQ125_" + k, n)


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func data() -> Dictionary:
	if not st.boxes.has("stash"):
		st.boxes["stash"] = {"spots": {}, "bundles": [], "seen": {}, "qb": 0, "n": 0}
	return st.boxes["stash"]


func _up(n: int) -> void:
	if st.quests.stage(QID) < n:
		st.quests.set_stage(QID, n)
		_log("단계 %d" % n)


# ---------------------------------------------------------------- 내 자리(§3.1)
## 삼을 수 있나: "" = 된다 · 아니면 까닭(창에 단추를 안 띄운다)
func can_claim(map_id: String, b: Dictionary, c: Dictionary) -> String:
	if st.year() < 2277 or not (map_id == "W" or map_id.begins_with("G-") or b.has("claim")):
		return "여기는 내 자리로 삼을 수 없다"                          # 손 맵 · 볼트 시대(§6 #17 · #18)
	if not (str(b.get("kind", "")) in CLAIM_KINDS) or str(b.get("owner", "")) != "":
		return "남의 자리다"                                             # 주인 있는 용기 · 바꿈 상자(§9.4 #28 · #35)
	if not (c.get("items", {}) as Dictionary).is_empty():
		return "먼저 비워야 한다"
	if (data()["spots"] as Dictionary).size() >= MAX_SPOTS:
		return "이미 자리가 많다 — 하나를 놓아라"                        # §6 #6
	return ""


func is_mine(c: Dictionary) -> bool:
	return str(c.get("mine", "")) != ""


func _wpos(map_id: String, b: Dictionary) -> Vector2i:
	if b.has("claim"):                                                   # 손 맵 보관 자리(claim=월드 좌표): 털림 판정은 그 월드 자리로
		return Vector2i(int(b["claim"][0]), int(b["claim"][1]))
	if map_id.begins_with("G-"):
		var p := map_id.split("-")
		return Vector2i(int(p[1]), int(p[2]))
	return Vector2i(int(b.get("x", 0)), int(b.get("y", 0)))


func risk(b: Dictionary, c: Dictionary) -> float:
	var th := int(b.get("th", 2))
	var p := float(P_TH.get(clampi(th, 1, 3), 0.018))
	var lv := int(b.get("lock", 0))
	p *= 1.0 if lv <= 0 else (0.6 if lv <= 25 else (0.35 if lv <= 50 else 0.15))
	if str(b.get("kind", "")) == "stash":
		p *= 0.5                                                       # 쪽지로만 찾는 숨겨 둔 상자
	if bool(c.get("bell", false)):
		p *= 0.3
	for id in (c.get("items", {}) as Dictionary):
		if str(id).begins_with("W-") or str(id).begins_with("A-") or (str(id) == "M-001" and int(c["items"][id]) >= 100):
			p *= 1.4                                                   # 값진 것을 들락거린 자리는 눈에 띈다
			break
	return p


## 위험을 세계 말로(§9.3): '잠기지 않는 서랍. 큰길가 동네라 사람이 자주 드나든다.'
func risk_text(map_id: String, b: Dictionary, c: Dictionary) -> String:
	var nm := str(b.get("name", "용기"))
	var lv := int(b.get("lock", 0))
	var a := ("잠기지 않는 " if lv <= 0 else ("허술한 자물쇠의 " if lv <= 25 else ("단단히 잠기는 " if lv <= 50 else "잠긴 "))) + nm + "."
	var th := int(b.get("th", 2))
	var w: String = "길가라 누구나 지나간다." if map_id == "W" else str(({1: "사람이 자주 드나드는 동네다.", 2: "가끔 사람이 지나간다.", 3: "여긴 짐승만 다닌다."} as Dictionary).get(th, ""))
	return "%s %s%s" % [a, w, " 방울 줄을 매 두었다." if bool(c.get("bell", false)) else ""]


func on_open(b: Dictionary, c: Dictionary, scr: ContainerScreen) -> void:
	var mid := host.map.id
	if is_mine(c):
		scr.stash_mode = "release"
		scr.stash_line = risk_text(mid, b, c)
		scr.bell_ok = st.items.has(BELL) and not bool(c.get("bell", false))
	elif can_claim(mid, b, c) == "":
		scr.stash_mode = "claim"
		scr.stash_line = risk_text(mid, b, c)
	scr.stash_act.connect(func(what: String) -> void: _act(what, b, c, scr))
	if int(c.get("sack", 0)) > 0:
		_crew_turn()                                                    # 깨어 있는 털이꾼 앞에서 자루를 연다 — 말은 끝났다
	if c.has("trace") and not bool(c.get("trace_seen", false)):        # 털린 흔적(§3.2): 열어서 처음 본다 — 퀘스트가 붙은 묶음이면 UQ-125 10
		c["trace_seen"] = true
		host.hint(str(c["trace"]), 8.0)
		var bn := bundle(int(c.get("trace_b", 0)))
		if not bn.is_empty() and bool(bn.get("quest", false)):
			_open_quest(bn)


func on_close(b: Dictionary, c: Dictionary) -> void:
	var bid := int(c.get("sack", 0))                                   # 털이꾼 소굴의 내 물건 자루: 비우면 끝(§5 털이꾼)
	if bid <= 0 or not (c["items"] as Dictionary).is_empty():
		return
	var bn := bundle(bid)
	if bn.is_empty() or str(bn["state"]) == "back":
		return
	var awake := 0
	for e in host.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and e.has_meta("uq125") and not bool(e.get_meta("asleep", false)):
			awake += 1
	bn["state"] = "back"
	host.st.call_fn("give", [BELL, 2])
	host.hint("자루를 되찾았다. 소굴 입구 못에 방울 줄 둘이 걸려 있다 — 챙겼다.", 5.0)
	_done(bn, 7 if _asleep_all() else 1)


func _asleep_all() -> bool:
	for e in host.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and e.has_meta("uq125") and not bool(e.get_meta("asleep", false)):
			return false
	return true


func _act(what: String, b: Dictionary, c: Dictionary, scr: ContainerScreen) -> void:
	var d := data()
	var k := Loot.key(host.map.id, b, st.year())
	match what:
		"claim":
			if can_claim(host.map.id, b, c) != "":
				return
			c["mine"] = str(b.get("name", "용기"))
			var wp := _wpos(host.map.id, b)
			d["spots"][k] = {"map": host.map.id, "x": int(b["x"]), "y": int(b["y"]), "name": str(b.get("name", "")), "since": day(),
				"lock": int(b.get("lock", 0)), "th": int(b.get("th", 2)), "kind": str(b.get("kind", "")), "wx": wp.x, "wy": wp.y,
				"region": host.map_region(Vector2i(int(b["x"]), int(b["y"]))), "rest": 0}
			scr.stash_mode = "release"
			scr.bell_ok = st.items.has(BELL)
			host.hint("내 자리로 삼았다. 핍-보이 수첩에 적어 둔다 — " + risk_text(host.map.id, b, c), 5.0)
			_log("삼기 %s (%d곳)" % [k, (d["spots"] as Dictionary).size()])
		"release":
			c.erase("mine")
			c.erase("bell")
			d["spots"].erase(k)
			scr.stash_mode = "claim" if can_claim(host.map.id, b, c) == "" else ""
			scr.bell_ok = false
			host.hint("자리를 놓았다. 남은 물건은 그대로다 — 이제 누구의 것도 아니다.", 4.0)
		"bell":
			if st.items.has(BELL) and not bool(c.get("bell", false)):
				st.call_fn("take", [BELL, 1])
				c["bell"] = true
				scr.bell_ok = false
				scr.stash_line = risk_text(host.map.id, b, c)
				host.hint("용기 앞에 방울 줄을 맸다. 손을 대면 울린다.", 4.0)
	if scr.view != null:
		scr.view.queue_redraw()


func spots() -> Dictionary:
	return data()["spots"]


func bundle(id: int) -> Dictionary:
	for bn in (data()["bundles"] as Array):
		if int(bn["id"]) == id:
			return bn
	return {}


# ---------------------------------------------------------------- 하루 판정(§3.2 · §9.3)
func _captive() -> bool:
	return int(st.vars.get_v("SB_COLLAR")) == 1 or int(st.vars.get_v("SB_CUFF")) == 1


func _on_day(_d: int) -> void:
	if st.year() < 2277 or _captive():
		return                                                         # 생포 · 강제 사건 중에는 쉰다(§9.4 #33)
	var d := data()
	var today := day()
	_age(today)
	for k in (d["spots"] as Dictionary).keys():
		var s: Dictionary = d["spots"][k]
		var c: Dictionary = st.boxes.get(k, {})
		if c.is_empty() or not is_mine(c):
			d["spots"].erase(k)                                         # 용기가 사라졌거나 놓았다(§6 #24 — 물건은 그 상태 그대로)
			continue
		if today < int(s["since"]) + GRACE or today < int(s.get("rest", 0)):
			continue
		if _value(c["items"]) < MIN_VALUE:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|%d|%d" % [k, today, st.check_seed])        # 같은 판 같은 날 같은 결과 — 불러와도 바뀌지 않는다(§6 #5)
		var b := {"th": s["th"], "lock": s["lock"], "kind": s["kind"]}
		if rng.randf() >= risk(b, c) + _ramp(s, today):
			continue
		var here := host.map != null and host.map.id == str(s["map"])
		if int(d["seen"].get(str(s["map"]), -99)) >= today - 1 and not here:
			continue                                                    # 그날 · 전날 들른 자리는 넘어간다(§3.2 들른 날)
		if bool(c.get("bell", false)) and rng.randf() < 0.5:
			c["bell"] = false
			c["trace"] = "방울 줄이 끊겨 바닥에 늘어져 있다. 누가 손을 대다 방울 소리에 달아났다 — 물건은 그대로다."
			c["trace_seen"] = false
			s["rest"] = today + 7
			_log("방울이 막음 %s" % k)
			continue
		if here:
			_ambush(k, s, c, rng)                                       # 잠복(§9.3): 그 실내에서 밤을 보냈다 — 털이 대신 현장 장면
			continue
		_theft(k, s, c, today, rng)


## 첫 털림 오름(재미 검수 ③): 퀘스트가 아직이면 유예가 끝난 날부터 하루 +1%p(상한 12%) — 언제 올지는 씨앗이 정하되 한 번은 온다
func _ramp(s: Dictionary, today: int) -> float:
	if st.quests.stage(QID) > 0 or int(data()["qb"]) > 0:
		return 0.0
	return clampf(0.01 * float(today - int(s["since"]) - GRACE), 0.0, 0.12)


func _value(items: Dictionary) -> int:
	var t := 0
	for id in items:
		if _quest_item(str(id)):
			continue
		t += int(host.items_db.get(Gear.base(str(id)), {}).get("value", 1 if str(id) == "M-001" else 0)) * int(items[id])
	return t


func _quest_item(id: String) -> bool:
	var it: Dictionary = host.items_db.get(Gear.base(id), {})
	return str(it.get("tag", "")) == "퀘스트" or str(it.get("cat", "")) == "quest" or id.begins_with("M-2") or id.begins_with("M-3")


## 털림(§3.2 · §3.3): 가치 높은 순으로 50~80% · 캡은 절반 · 퀘스트 물건은 남긴다. 범인 · 행방은 그때 정한다(P1)
func _theft(k: String, s: Dictionary, c: Dictionary, today: int, rng: RandomNumberGenerator, only := "", watched := false) -> void:
	var d := data()
	var items: Dictionary = c["items"]
	var ids: Array = items.keys().filter(func(x): return not _quest_item(str(x)) and str(x) != "M-001")
	ids.sort_custom(func(a, b2): return _value({a: 1}) > _value({b2: 1}))
	var goal := _value(items) * rng.randf_range(0.5, 0.8)
	var got := {}
	var sum := 0
	for id in ids:
		if sum >= goal and not got.is_empty():
			break
		got[id] = int(items[id])
		sum += _value({id: int(items[id])})
	if items.has("M-001") and int(items["M-001"]) > 1:
		got["M-001"] = int(items["M-001"]) / 2
	for id in got:
		items[id] = int(items[id]) - int(got[id])
		if int(items[id]) <= 0:
			items.erase(id)
	var gear := got.keys().any(func(x): return str(x).begins_with("W-") or str(x).begins_with("A-"))
	var dest := _dest(s, gear or sum >= 80, rng, only)
	d["n"] = int(d["n"]) + 1
	var quest := st.quests.stage(QID) == 0 and int(d["qb"]) == 0
	var bn := {"id": int(d["n"]), "key": k, "map": s["map"], "spot": s["name"], "day": today, "items": got, "who": dest[0], "dest": dest[1],
		"state": "held" if dest[0] != "gone" else "gone", "quest": quest and dest[0] != "gone", "th": int(s["th"])}
	if bool(bn["quest"]):
		d["qb"] = bn["id"]
		_sv("WHO", int({"kid": 1, "crew": 2, "fence": 3}.get(str(dest[0]), 0)))
	(d["bundles"] as Array).append(bn)
	if str(dest[0]) == "fence":
		_to_fence(bn)
	c["trace"] = _trace(bn, s, dest)
	c["trace_seen"] = false
	c["trace_b"] = bn["id"]
	if watched and str(dest[0]) == "crew":                              # 지켜봤다(재미 검수 덤): 흔적 대신 내가 본 것 — 단계 10이 바로 열린다
		c["trace"] = "내가 본 것 — 쇠지레를 든 둘이 내 자리를 털어 자루를 메고 %s으로, %s." % [dest[3], dest[2]]
		c["trace_seen"] = true
		if bool(bn["quest"]):
			_open_quest(bn)
	s["rest"] = today + 7
	_log("털림 %s → %s %s (%d)" % [k, dest[0], dest[1], sum])


## 행방: [범인, 맵, 거리 말, 방위 말]. 아이는 위협 1 · 덫이 없을 때만 · 장물아비는 값진 묶음 50% · 그 밖 털이꾼 · 아무 데도 없으면 'gone'
func _dest(s: Dictionary, rich: bool, rng: RandomNumberGenerator, only := "") -> Array:
	var wp := Vector2i(int(s["wx"]), int(s["wy"]))
	var order: Array = []
	if int(s["th"]) <= 1:
		order.append("kid")
	if rich and rng.randf() < 0.5:
		order.push_front("fence")
	order.append_array(["crew", "fence"])
	if only != "":
		order.push_front(only)
	for who in order:
		var best := ["", 1e9]
		if who == "fence":
			for mid in _traders:
				var tv: Dictionary = _traders[mid]
				var vid := "N-VG-" + str({"scrap": "S1", "herb": "H1", "parts": "P1", "cloth": "C1", "food": "F1", "drift": "D1"}[str(tv["kind"])])
				if st.is_dead(vid + "@" + str(mid)):
					continue                                            # 죽은 장사꾼은 장물아비가 될 수 없다(§6 #8)
				var dd := Vector2(wp).distance_to(Vector2(int(tv["at"][0]), int(tv["at"][1])))
				if dd <= 220 and dd < float(best[1]):
					best = [str(mid), dd]
		else:
			for row in (_hide.get("den" if who == "crew" else "quiet", []) as Array):
				if str(row[0]) == str(s["map"]):
					continue
				var dd := Vector2(wp).distance_to(Vector2(int(row[1]), int(row[2])))
				if dd >= (25.0 if who == "kid" else 20.0) and dd <= (140.0 if who == "kid" else 160.0) and dd < float(best[1]):
					best = [str(row[0]), dd]
		if str(best[0]) != "":
			var p := str(best[0]).split("-")
			var to := Vector2i(int(p[1]), int(p[2]))
			var ang := rad_to_deg(atan2(float(to.y - wp.y), float(to.x - wp.x)))
			var dirs := ["동쪽", "남동쪽", "남쪽", "남서쪽", "서쪽", "북서쪽", "북쪽", "북동쪽"]
			var dname: String = dirs[int(fposmod(ang + 22.5, 360.0) / 45.0) % 8]
			var far := "골목 몇 개 건너" if float(best[1]) < 40 else ("큰길 하나 건너" if float(best[1]) < 80 else "한참 가서")
			return [who, best[0], far, dname]
	return ["gone", "", "", ""]


func _trace(bn: Dictionary, _s: Dictionary, dest: Array) -> String:
	match str(dest[0]):
		"kid":
			return "안이 반쯤 비었다. 먼지에 작은 손가락 자국 — 바닥엔 사탕 껍질 하나. 맨발 자국이 %s으로, %s." % [dest[3], dest[2]]
		"crew":
			return "안이 털렸다. 자물쇠 둘레에 쇠지레 자국, 문설주에 분필 'X 털었음'. 군화 자국 셋이 %s으로 %s." % [dest[3], dest[2]]
		"fence":
			return "안이 털렸다. 빈 자리에 쪽지 한 장이 끼워져 있다. '목요일 — 물건 받음 — %s.' 그 가게는 %s으로 %s." % [_map_name(str(dest[1])), dest[3], dest[2]]
	return "안이 털렸다. 흔적은 비에 씻겼다. 어디로 갔는지 알 길이 없다."


var _idx := {}


func _map_name(mid: String) -> String:
	if _idx.is_empty() and FileAccess.file_exists("res://data/maps/_index.json"):
		_idx = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/_index.json")).get("maps", {})
	return str(_idx.get(mid, {}).get("name", "그 가게"))


func _to_fence(bn: Dictionary) -> void:
	var vid := _fence_vid(str(bn["dest"]))
	var sh := host.shop_state(vid)
	var mine: Dictionary = sh.get("mine", {})
	for id in bn["items"]:
		if str(id) == "M-001":
			continue                                                    # 캡은 장사꾼 주머니로
		sh["items"][id] = int(sh["items"].get(id, 0)) + int(bn["items"][id])
		mine[id] = int(mine.get(id, 0)) + int(bn["items"][id])
	sh["mine"] = mine
	sh["mine_b"] = bn["id"]
	bn["state"] = "fenced"


func _fence_vid(mid: String) -> String:
	return "%s@%s" % [TRADE_V.get(str(_traders.get(mid, {}).get("kind", "drift")), "VG_DRIFT"), mid]


## 행방 시계(§5 놓침): 7일 — 아이는 먹을 것을 다 먹었다 · 털이꾼은 장물로 넘긴다 / 14일 — 장물이 팔린다 / 30일 — 끝(소멸)
func _age(today: int) -> void:
	for bn in (data()["bundles"] as Array):
		var age := today - int(bn["day"])
		var stt := str(bn["state"])
		if stt in ["back", "gone", "done"]:
			continue
		if age >= GONE_DAYS:
			_clear_fence(bn)
			bn["state"] = "gone"
			if bool(bn.get("quest", false)) and st.quests.stage(QID) < 100:
				_done(bn, 9)                                            # 놓침 — 바크 한 줄(§2.3 놓침 보상 없음)
			continue
		if age >= SOLD_DAYS and stt == "fenced":
			_clear_fence(bn)
			bn["state"] = "sold"
		elif age >= HELD_DAYS and stt == "held":
			if str(bn["who"]) == "kid":
				for id in _food_ids(bn):
					bn["items"].erase(id)                               # 먹을 것 · 마실 것은 다 먹었다
			elif str(bn["who"]) == "crew":
				var near := _dest({"wx": int(str(bn["dest"]).split("-")[1]), "wy": int(str(bn["dest"]).split("-")[2]), "th": 2, "map": bn["dest"]},
					false, RandomNumberGenerator.new())
				if str(near[0]) == "fence" or str(near[0]) == "crew":
					var f := _dest({"wx": int(str(bn["dest"]).split("-")[1]), "wy": int(str(bn["dest"]).split("-")[2]), "th": 3, "map": bn["dest"]},
						true, RandomNumberGenerator.new())
					if str(f[0]) == "fence":
						bn["dest"] = f[1]
						bn["who"] = "fence"
						_to_fence(bn)                                   # 털이꾼이 자루를 장물로 넘겼다(§5 놓침)


func _clear_fence(bn: Dictionary) -> void:
	if str(bn["who"]) != "fence":
		return
	var sh := host.shop_state(_fence_vid(str(bn["dest"])))
	var mine: Dictionary = sh.get("mine", {})
	for id in mine:
		sh["items"][id] = maxi(0, int(sh["items"].get(id, 0)) - int(mine[id]))
		if int(sh["items"][id]) == 0:
			sh["items"].erase(id)
	sh.erase("mine")
	sh.erase("mine_b")


# ---------------------------------------------------------------- 범인 자리(§5)
func _on_map(mid: String) -> void:
	var d := data()
	d["seen"][mid] = day()
	_sv("HERE", 0)
	for bn in (d["bundles"] as Array):
		if str(bn["map"]) == mid and str(bn["state"]) in ["gone", "sold"] and bool(bn.get("quest", false)) and not bool(bn.get("told", false)):
			bn["told"] = true
			host.hint(str(GONE_LINE.get(str(bn["who"]), GONE_LINE["gone"])), 6.0)
	for bn in (d["bundles"] as Array):
		if str(bn["dest"]) != mid or not (str(bn["state"]) in ["held", "fenced"]):
			continue
		_sv("HERE", 1)
		if bool(bn.get("quest", false)):
			_open_quest(bn)
			_up(30)
		match str(bn["who"]):
			"kid":
				_stage_kid(bn)
			"crew":
				_stage_crew(bn)
			"fence":
				_sv("FENCE", 1)


func _open_quest(bn: Dictionary) -> void:
	if st.quests.stage(QID) == 0:
		_up(10)                                                         # 비표시 — 기타 묶음 메모 줄은 단계 로그(SD-05 §2.6)


func _free_cell(min_from_door: int, front := false) -> Vector2i:
	var m := host.map
	var door := m.tile_of(m.mark_pos("from_W")) if m.marks.has("from_W") else Vector2i(1, 1)
	var best := Vector2i(-1, -1)
	for y in range(3, int(m.data["size"][1]) - 2):
		for x in range(1, int(m.data["size"][0]) - 1):
			var c := Vector2i(x, y)
			if m.is_solid(c) or m.boxes.has(c) or absi(c.x - door.x) + absi(c.y - door.y) < min_from_door:
				continue
			if front and (m.is_solid(c + Vector2i(0, 1)) or m.boxes.has(c + Vector2i(0, 1)) or m.is_solid(c + Vector2i(1, 0))):
				continue
			if best.x < 0 or c.y < best.y:
				best = c
	return best


func _stage_kid(bn: Dictionary) -> void:
	if int(st.vars.get_v("UQ125_KID")) >= 2:
		return
	var c := _free_cell(4, true)
	if c.x < 0:
		c = _free_cell(4)
	if c.x < 0:
		return
	if not host.map.is_solid(c + Vector2i(0, 1)):
		host.map.add_runtime_prop("bedroll", c + Vector2i(0, 1))       # 이불 더미 — 아이는 그 뒤에
	(host.map.data["npcs"] as Array).append({"id": KID, "x": c.x, "y": c.y, "dir": "S", "route": [], "cond": "UQ125_KID <= 1",
		"bark": "…", "look": KID_LOOK, "sheet": "st_look_" + KID_LOOK.to_lower().replace("-", "_")})
	_sv("KID", 1)
	_sv("GUARD", _guard())
	host.refresh_npcs()
	if host.map.add_runtime_prop("backpack", c + Vector2i(1, 0)).is_empty():
		host.map.add_runtime_prop("crate_o", c + Vector2i(1, 0))


func _guard() -> int:
	for i in GUARDS.size():
		var g: Array = GUARDS[i]
		if not st.is_dead(str(g[0])) and int(st.vars.get_v(str(g[1])) if st.vars.has(str(g[1])) else 0) > -20:
			return i + 1                                                # 살아 있고 적대가 아닌 첫 사람(§6 #10)
	return 0


func _stage_crew(bn: Dictionary) -> void:
	if str(bn["state"]) != "held":
		return
	var c := _free_cell(5)
	if c.x < 0:
		return
	var sack := {"x": c.x, "y": c.y, "w": 1, "h": 1, "kind": "sack", "owner": "PC", "lock": 0, "name": "내 물건 자루", "cond": ""}
	host.map.boxes[c] = sack
	var k := Loot.key(host.map.id, sack, st.year())
	if not st.boxes.has(k):
		st.boxes[k] = {"items": (bn["items"] as Dictionary).duplicate(), "opened": 0, "taken": 0, "sack": bn["id"]}
	host.map.add_runtime_prop("backpack", c)
	var hr := int(st.vars.get_v("GAME_HOUR")) if st.vars.has("GAME_HOUR") else 12
	var night := hr >= 22 or hr < 6                                     # 밤엔 잔다 — 몰래 자루만 들고 나올 수 있다
	var n := 2 if _value(bn["items"]) < 120 else 3
	var placed := 0
	for y in range(3, int(host.map.data["size"][1]) - 2):
		for x in range(1, int(host.map.data["size"][0]) - 1):
			var p := Vector2i(x, y)
			if placed >= n or host.map.is_solid(p) or host.map.boxes.has(p) or p.distance_to(c) < 2.0 or p.distance_to(c) > 6.0:
				continue
			var o: Dictionary = {"sleep": night} if night else {"team": CREW_T, "foes": []}
			var e := host.combat.spawn("CR-423", Vector2(x * 32 + 16, y * 32 + 16), host.map, st, o)
			if e != null:
				e.set_meta("uq125", bn["id"])
				e.set_meta("asleep", night)
				placed += 1
	bn["staged"] = day()
	bn["sack_k"] = k
	if not night:
		for e in host.combat.enemies:                                   # 소굴 식구 모두 한 무리 — 먼저 치면 다 같이 돌아선다
			if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) in ["CR-423", "CR-420"]:
				e.cmb.team = CREW_T
				e.foes = []
		_talk_due = true


# ---------------------------------------------------------------- 잠복(§9.3)
func _ambush(k: String, s: Dictionary, c: Dictionary, rng: RandomNumberGenerator) -> void:
	s["rest"] = day() + 7
	if int(s["th"]) <= 1 and int(st.vars.get_v("UQ125_KID")) == 0:
		var cc := _free_cell(2)
		if cc.x >= 0:
			(host.map.data["npcs"] as Array).append({"id": KID, "x": cc.x, "y": cc.y, "dir": "N", "route": [], "cond": "UQ125_KID == 5",
				"bark": "…", "look": KID_LOOK, "sheet": "st_look_" + KID_LOOK.to_lower().replace("-", "_")})
			_sv("KID", 5)
			host.refresh_npcs()
			host.hint("새벽, 문이 삐걱인다. 작은 그림자 하나가 내 자리 앞에 쪼그려 앉았다.", 6.0)
			return
	var door := host.map.tile_of(host.map.mark_pos("from_W")) if host.map.marks.has("from_W") else Vector2i(2, 2)
	var crew: Array = []
	var front := [int(s["x"]), int(s["y"]) + 1, 6.0]
	for i in 2:
		var e := host.combat.spawn("CR-423", Vector2((door.x + i - 1) * 32 + 16, (door.y - 1) * 32 + 16), host.map, st,
			{"team": CREW_T, "foes": [], "route": [[door.x + i - 1, door.y - 1, 1.0], [front[0] + i, front[1], 6.0]]})
		if e != null:
			e.set_meta("uq125", -1)
			crew.append(e)
	host.hint("새벽, 문이 삐걱인다 — 쇠지레를 든 둘이 들어온다. 이쪽은 못 봤다. 지켜볼까, 나설까.", 7.0)
	_log("잠복: 털이꾼 %s" % k)
	var today := day()
	var mid := str(s["map"])
	host.get_tree().create_timer(14.0).timeout.connect(func() -> void: _ambush_end(k, mid, crew, today))


## 잠복 끝: 털이꾼이 아직 말이 통하는 채(아무도 안 쳤다)면 털고 나간다 — 묶음 · 행방이 생긴다(P1). 맵을 떠났어도 같다(흔적만 보통 글)
func _ambush_end(k: String, mid: String, crew: Array, today: int) -> void:
	var calm := crew.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == CREW_T)
	var gone := host.map == null or host.map.id != mid
	if calm.is_empty() and not gone:
		return                                                          # 싸웠다 · 쫓아냈다 — 털림 없음
	var s: Dictionary = spots().get(k, {})
	var c: Dictionary = st.boxes.get(k, {})
	if s.is_empty() or c.is_empty() or _value(c.get("items", {})) < MIN_VALUE:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|w" % [k, today])
	_theft(k, s, c, today, rng, "crew", not gone)
	for e in calm:
		host.combat.drop_enemy(e)
	if not gone:
		host.hint(str(c.get("trace", "")), 7.0)


# ---------------------------------------------------------------- 원고 명령(@cmd stash …)
func _cmd(a: Array, done: Callable) -> void:
	var what := str(a[0]) if a.size() > 0 else ""
	var bn := bundle(int(data()["qb"]))
	match what:
		"kid_take":                                                     # 다 되찾는다 — 아이가 운다(카르마 −5)
			_give_back(bn, [])
			st.call_fn("karma", [-5])
			_kid_leave(2)
			_done(bn, 1)
		"kid_share":                                                    # 먹을 것은 두고 나머지 — 방울 줄 매는 법(+10)
			_give_back(bn, _food_ids(bn))
			st.call_fn("karma", [10])
			st.call_fn("give", [BELL, 2])
			_kid_leave(2)
			_done(bn, 2)
		"kid_guard":                                                    # 맡긴다 — 아이가 좋아한 것 하나는 고집해 가져간다(+25)
			var fav := _favorite(bn)
			_give_back(bn, [fav] if fav != "" else [])
			st.call_fn("karma", [25])
			st.call_fn("give", [BELL, 2])
			if fav != "":
				data()["kid_fav"] = fav
				host.hint("%s — 아이 주머니로 들어갔다. 돌려 달라고 하지 않았다." % str(host.items_db.get(Gear.base(fav), {}).get("name", fav)), 5.0)
			_kid_leave(3)
			_done(bn, 3)
		"kid_scare":                                                    # 겁준다 — 물건만 두고 달아난다(−2)
			_give_back(bn, [])
			st.call_fn("karma", [-2])
			_kid_leave(2)
			_done(bn, 6)
		"night_kid":                                                    # 잠복으로 붙잡은 아이: 사과하며 방울 줄을 준다
			st.call_fn("give", [BELL, 1])
			_sv("KID", 0)
			host.refresh_npcs()
		"crew_talk", "crew_pay":                                       # 낮 소굴에서 말로 · 수고비로(R 8 · 10) — 자루를 돌려받고 입구 방울 줄 둘
			var cb := _crew_bundle()
			if not cb.is_empty():
				var sk := str(cb.get("sack_k", ""))
				if st.boxes.has(sk):
					var sc: Dictionary = st.boxes[sk]
					for id in (sc["items"] as Dictionary):
						if str(id) == "M-001":
							st.call_fn("caps", [int(sc["items"][id])])
						else:
							st.call_fn("give", [id, int(sc["items"][id])])
					sc["items"] = {}
				cb["state"] = "back"
				st.call_fn("give", [BELL, 2])
				_done(cb, 8 if what == "crew_talk" else 10)
		"crew_fight":
			_crew_turn()
		"fence_free":                                                   # [화술 30] 긁힌 자국을 보여 줌 — 그냥 돌려받는다
			var fb := _fence_bundle()
			if not fb.is_empty():
				var sh := host.shop_state(_fence_vid(str(fb["dest"])))
				for id in (sh.get("mine", {}) as Dictionary):
					var n := mini(int(sh["mine"][id]), int(sh["items"].get(id, 0)))
					if n > 0:
						st.call_fn("give", [id, n])
				_clear_fence(fb)
				st.call_fn("give", [BELL, 2])
				fb["state"] = "back"
				_done(fb, 5)
	done.call()


func _crew_bundle() -> Dictionary:
	for bn in (data()["bundles"] as Array):
		if str(bn["who"]) == "crew" and str(bn["state"]) == "held" and str(bn["dest"]) == host.map.id:
			return bn
	return {}


func _fence_bundle() -> Dictionary:
	for bn in (data()["bundles"] as Array):
		if str(bn["who"]) == "fence" and str(bn["state"]) == "fenced" and str(bn["dest"]) == host.map.id:
			return bn
	return {}


## 장물아비 진열에서 되샀다(거래 창을 닫을 때 InteriorHost가 부른다): 내 물건이 진열에 하나도 안 남았으면 끝(되삼)
func after_trade(vid: String) -> void:
	var sh := host.shop_state(vid)
	if not sh.has("mine"):
		return
	var left := 0
	for id in (sh["mine"] as Dictionary).keys():
		sh["mine"][id] = mini(int(sh["mine"][id]), int(sh["items"].get(id, 0)))
		left += int(sh["mine"][id])
	if left == 0:
		var bn := bundle(int(sh.get("mine_b", 0)))
		sh.erase("mine")
		sh.erase("mine_b")
		if not bn.is_empty():
			bn["state"] = "back"
			st.call_fn("give", [BELL, 1])
			host.hint("장사꾼이 방울 줄 하나를 얹어 준다. '다음엔 이거 달아. 나도 덜 귀찮고.'", 5.0)
			_done(bn, 4)


func _give_back(bn: Dictionary, keep: Array) -> void:
	if bn.is_empty():
		return
	for id in (bn["items"] as Dictionary):
		if str(id) in keep:
			continue
		if str(id) == "M-001":
			st.call_fn("caps", [int(bn["items"][id])])
		else:
			st.call_fn("give", [id, int(bn["items"][id])])
	bn["state"] = "back"


func _food_ids(bn: Dictionary) -> Array:
	var out: Array = []
	for id in (bn.get("items", {}) as Dictionary):
		var s := str(id)
		if s.begins_with("I-0") and int(s.substr(2)) >= 22 and int(s.substr(2)) <= 63:
			out.append(s)                                               # 음식 · 마실 것(I-022~I-063)
	return out


## 아이가 좋아한 것(§9.3): 값진 것이 아니라 장난감 · 폭죽 · 잡동사니 — 없으면 먹을 것 하나 · 그것도 없으면 아무것도 고집하지 않는다
func _favorite(bn: Dictionary) -> String:
	var it: Dictionary = bn.get("items", {})
	for pref in ["M-096", "M-041", "M-045", "M-097", "M-092", "M-093", "M-094"]:
		if it.has(pref):
			return pref
	for id in it:
		if str(id).begins_with("M-08") or str(id).begins_with("M-09"):
			return str(id)
	for id in it:
		if str(id) != "M-001":
			return str(id)                                              # 털 때 가장 먼저 집은 것 — 무기일 수도 있다
	return ""


func _kid_leave(state: int) -> void:
	_sv("KID", state)
	host.refresh_npcs()


func _done(bn: Dictionary, r: int) -> void:
	if bn.is_empty() or not bool(bn.get("quest", false)) or st.quests.stage(QID) >= 100:
		return
	_sv("R", r)
	_up(100)
	if r != 9:
		st.call_fn("xp", [int(XP.get(clampi(int(bn.get("th", 2)), 1, 3), 90))])
	_log("끝 R=%d" % r)
