## 서울의 판도(단계 1-12m, SD-06 §5 · SD-08 §15): 판도 구역(PD-Rxx-n)마다 세력 영향력을 계산하고, 주인공이 '아는 판'을 따로 든다.
##   영향력(SD-06 §5.2) = min(60, Σ그 구역 안 자기 거점 가중치 × 15) + 순찰 기반값(정기 10 · 본거지 20 — 본거지는 자기 거점이 남아 있을 때만) + 사건 보정(−30~+30).
##   상태: 지배(1위 ≥ 50 · 차이 ≥ 25) / 우세(1위 ≥ 20 · 차이 ≥ 10) / 경합(1위 ≥ 20 · 차이 < 10) / 공백(1위 < 20). 정착지는 가맹하면 JC로 합친다(§5.9 끝).
##   사건 보정: 퀘스트가 1-12 전부터 써 온 판도 변수(PD_BC · PD_R01_BJ …)를 원천으로 읽고, 지난번 읽은 값과의 차이만 더한다(같은 사건 두 번 없음, P9).
##     원천 변수는 누적 사실로 남고, 7일마다 0 쪽으로 2씩 줄어드는 것은 이 장부 안에서만(SD-06 §5.2). 한 번만 일어나는 사건은 FX(표지)로.
##   판도 틱(SD-06 §5.4 — 1단계는 틀): 3일마다 경합 구역에서 '전쟁' 두 세력 ±2(주인공이 있는 구역은 건너뛰고 그 구역 교전 RE ×2), 공백 구역은 약탈자 +1(30까지).
##   아는 판(SD-12 §5.8 · T4): 구역 땅을 밟거나, 판도 소식 방송을 맞춰 듣거나(N-PD-…), 판도 소문을 들으면 그 구역만 갱신. 지도는 이것으로 그린다.
##   이야기 변수: PDS_<R01_1>(상태 0 공백 · 1 경합 · 2 우세 · 3 지배) · PDO_<R01_1>(1위 세력 약호) — 방송 · 소문 · 원고 조건이 읽는다(P1).
## 자료 data/turf.json(tools/pipeline/turf_export.py ← SD-08 §15.2 격자 · script/world/turf.txt · factions.txt).
class_name Turf
extends RefCounted

const STATE_NAMES := ["공백", "경합", "우세", "지배"]
const DECAY_DAYS := 7
const DECAY := 2
const TICK_DAYS := 3
const EV_MAX := 30
const RECENT := 3                                 ## '최근 변동' ↻: 사흘(72시간) 안
## 원천 변수 → [구역(PD-…) 또는 권역(R01 · R02), 세력, 배수]
const SRC := [
	["PD_BC", "PD-R01-2", "BC", 1], ["PD_R01", "R01", "BC", 1], ["PD_R01_BJ", "R01", "BJ", 1],
	["PD_R01_6", "PD-R01-6", "SB", 1], ["PD_R01_6", "PD-R01-6", "YT", -1], ["PD_R01_GS", "PD-R01-2", "GS", 1],
	["PD_R02_SB", "PD-R02-4", "SB", 1], ["PD_R02_GD", "PD-R02-5", "SB", 1], ["PD_R02_BJ", "R02", "BJ", 1],
]
const SRC_IDS := ["PD_BC", "PD_R01", "PD_R01_BJ", "PD_R01_6", "PD_R01_GS", "PD_R02_SB", "PD_R02_GD", "PD_R02_BJ"]

static var data := {}

var ev := {}                                      ## 구역 -> {세력: 사건 보정}
var src := {}                                     ## 원천 변수 -> 마지막으로 읽은 값
var fx := {}                                      ## 한 번 사건 표지 -> 일어난 날
var own := {}                                     ## 거점 -> 시뮬레이션이 바꾼 주인(원천 변수가 정한 것보다 뒤)
var known := {}                                   ## 구역 -> {"s", "a", "b", "day", "chg", "flash"} 주인공이 아는 판
var known_n := {}                                 ## 거점 -> {"o", "day", "chg"}
var last_day := -1
var decay_at := 0                                 ## 마지막 감쇠 날
var tick_at := 0                                  ## 마지막 판도 틱 날
var here := ""                                    ## 주인공이 마지막으로 선 구역(실내에선 들어가기 전 바깥)
var kills := {}                                   ## "구역|세력" -> [날, 그날 쓰러뜨린 수](하루 3까지 판도에 남는다)
var cur := {}                                     ## 구역 -> 지금 판(계산 캐시)
var dirty := true


static func load_data() -> void:
	if data.is_empty() and FileAccess.file_exists("res://data/turf.json"):
		data = JSON.parse_string(FileAccess.get_file_as_string("res://data/turf.json"))


static func zones() -> Array:
	load_data()
	var z: Array = (data.get("zones", {}) as Dictionary).keys()
	z.sort()
	return z


static func zone_of_chunk(cx: int, cy: int) -> String:
	load_data()
	return str(data.get("chunk_zone", {}).get("%d,%d" % [cx, cy], ""))


static func zone_at(t: Vector2i) -> String:
	if t.x < 0 or t.y < 0:
		return ""
	return zone_of_chunk(t.x / 40, t.y / 40)


static func zone_name(z: String) -> String:
	load_data()
	return str(data.get("zones", {}).get(z, {}).get("name", z))


## 'PD-R01-6' → 'R01_6'(이야기 변수 꼬리)
static func vkey(z: String) -> String:
	return z.substr(3).replace("-", "_")


static func fac_name(f: String) -> String:
	load_data()
	return str(data.get("show", {}).get(f, [f])[0])


# ---------------------------------------------------------------- 계산
## 세력의 표시 묶음: 봉천 = 정착지 연합 · 사당은 가맹한 뒤에만 연합(SD-06 §5.9 끝)
static func group(st, f: String) -> String:
	if f == "BC":
		return "JC"
	if f == "SA":
		return "JC" if int(st.vars.get_v("SA_JOIN")) == 1 else "SA"
	return f


## 상태 없이 묶음만(인카운터 세력 → 판도 세력): 정착지 개별은 연합으로
static func group_static(f: String) -> String:
	return "JC" if f in ["BC", "JC", "JC_BC"] else f


## 거점의 지금 주인(원천 변수 → 시뮬레이션 → 처음 주인)
func node_owner(st, nid: String) -> String:
	load_data()
	var n: Dictionary = data["nodes"].get(nid, {})
	match nid:
		"N-R02-6":
			if int(st.vars.get_v("PD_R02_KH")) == 1:
				return "BJ"                                           # SQ-S11: 국회 폐허에 휘장 깃발
		"N-R01-6":
			if int(st.vars.get_v("SQ_S02_CAMP")) == 1:
				return ""                                             # SQ-S02 C 처치: 두목이 죽고 은신처가 빈다
	if own.has(nid):
		return str(own[nid])
	return str(n.get("owner", ""))


## 잠긴 거점(시뮬레이션 · 점거가 넘보지 못한다): SQ-S04 E — 송신소 전지를 뽑아 갔다(D-135)
static func locked(st, nid: String) -> bool:
	return nid == "N-R01-7" and int(st.vars.get_v("SQ_S04_PD_LOCK")) == 1


## 구역 z의 세력별 영향력(표시 묶음으로 합친 값)
func influence(st, z: String) -> Dictionary:
	load_data()
	var zd: Dictionary = data["zones"].get(z, {})
	var owned := {}
	for nid in data["nodes"]:
		var n: Dictionary = data["nodes"][nid]
		if str(n["zone"]) != z or bool(n["sealed"]):
			continue
		var o := node_owner(st, nid)
		if o != "":
			owned[o] = int(owned.get(o, 0)) + int(n["w"])
	var raw := {}
	for f in owned:
		raw[f] = mini(60, int(owned[f]) * 15)
	var pat: Dictionary = zd.get("patrol", {})
	for f in pat:
		var b := int(pat[f][0])
		if bool(pat[f][1]) and int(owned.get(f, 0)) <= 0:
			b = 10                                                    # 본거지 순찰은 거점이 남아 있을 때만(재미 검수 ①)
		raw[f] = int(raw.get(f, 0)) + b
	var e: Dictionary = ev.get(z, {})
	for f in e:
		raw[f] = int(raw.get(f, 0)) + int(e[f])
	var out := {}
	for f in raw:
		var g := group(st, str(f))
		out[g] = clampi(int(out.get(g, 0)) + int(raw[f]), 0, 100)
	return out


## 지금 판: {"s": 상태, "a": 1위, "b": 2위, "ia", "ib"}
func state_of(st, z: String) -> Dictionary:
	if not dirty and cur.has(z):
		return cur[z]
	var inf := influence(st, z)
	var a := ""
	var b := ""
	for f in inf:
		if a == "" or int(inf[f]) > int(inf[a]) or (int(inf[f]) == int(inf[a]) and str(f) < a):
			a = str(f)
	for f in inf:
		if f != a and (b == "" or int(inf[f]) > int(inf[b]) or (int(inf[f]) == int(inf[b]) and str(f) < b)):
			b = str(f)
	var ia := int(inf.get(a, 0))
	var ib := int(inf.get(b, 0))
	var s := 0
	if ia >= 20:
		s = 3 if ia >= 50 and ia - ib >= 25 else (2 if ia - ib >= 10 else 1)
	var r := {"s": s, "a": a if s > 0 else "", "b": b if ib > 0 else "", "ia": ia, "ib": ib}
	cur[z] = r
	return r


# ---------------------------------------------------------------- 사건 보정
func _add(st, where: String, f: String, d: int) -> void:
	load_data()
	for z in zones():
		var zd: Dictionary = data["zones"][z]
		if z == where or str(zd["region"]) == where or (where == "SB*" and _has_sb(st, z)):
			if not ev.has(z):
				ev[z] = {}
			ev[z][f] = clampi(int(ev[z].get(f, 0)) + d, -EV_MAX, EV_MAX)
	dirty = true


func _has_sb(st, z: String) -> bool:
	if data["zones"][z]["patrol"].has("SB"):
		return true
	for nid in data["nodes"]:
		if str(data["nodes"][nid]["zone"]) == z and node_owner(st, nid) == "SB":
			return true
	return false


## 원천 변수 차이 · 한 번 사건을 읽어 장부에 넣는다(바뀐 것이 있으면 true)
func ingest(st) -> bool:
	var moved := false
	for k in SRC_IDS:
		if not st.vars.has(k):
			continue
		var nv := int(st.vars.get_v(k))
		var dv := nv - int(src.get(k, 0))
		if dv == 0:
			continue
		src[k] = nv
		for row in SRC:
			if row[0] == k:
				_add(st, str(row[1]), str(row[2]), dv * int(row[3]))
		moved = true
	var day := int(st.vars.get_v("GAME_DAY"))
	for row in _fx_rows(st):
		if fx.has(row[0]) or not bool(row[1]):
			continue
		fx[row[0]] = day
		_add(st, str(row[2]), str(row[3]), int(row[4]))
		moved = true
	if moved:
		dirty = true
	return moved


## 한 번 사건: [표지, 일어났나, 구역/권역, 세력, 값]
func _fx_rows(st) -> Array:
	var ho := int(st.vars.get_v("HO_LEDGER"))
	var s05 := int(st.vars.get_v("SQ_S05_SOL")) if st.vars.has("SQ_S05_SOL") else 0
	return [
		["MQ103", st.quests.stage("MQ-103") >= 100, "PD-R02-2", "JH", 5],             # D-132: 판도 지하상가 +지하시장 5(SD-03a §8.3)
		["LEDGER", ho == 8 or (ho >= 81 and ho <= 92), "R02", "SB", -30],             # D-133: 장부를 정착지에 — R02 −새벽 30(SD-03a §4.6)
		["HDC", st.is_dead("C-013"), "SB*", "SB", -20],                               # 지도자 처리: 황두칠(SD-06 §5.3) — 승계(D-082)가 되돌리지 않는다
		["S05", s05 >= 1 and s05 <= 3, "PD-R01-4", "SA", 3],                          # D-136: 환승촌 교역로 개통(SD-04a §4.5)
	]


## 주인공이 구역 안에서 그 세력원을 쓰러뜨렸다: 그 세력 사건 보정 −1(구역 · 세력마다 하루 3까지 — SD-06 §5.3 '적을 쫓아냄'의 거울, 1-12m 재미 검수 ②)
func note_kill(st, t: Vector2i, f: String) -> void:
	var z := zone_at(t)
	if z == "" or f == "":
		return
	var d := int(st.vars.get_v("GAME_DAY"))
	var key := "%s|%s" % [z, f]
	var c: Array = kills.get(key, [d, 0])
	if int(c[0]) != d:
		c = [d, 0]
	if int(c[1]) >= 3:
		return
	kills[key] = [d, int(c[1]) + 1]
	_bump(z, f, -1)
	dirty = true


# ---------------------------------------------------------------- 날 · 틱
## 하루 판정(06:00 — 진행기 _daily): 감쇠 · 판도 틱 · 가맹 · 변수. 여러 날을 건너뛰면 넘어간 날마다 한 번씩 불린다(P6)
func day(st, d: int) -> Array:
	ingest(st)
	if last_day < 0:
		last_day = d
		decay_at = d
		tick_at = d
	last_day = d
	if d - decay_at >= DECAY_DAYS:
		decay_at = d
		for z in ev:
			for f in ev[z]:
				var v := int(ev[z][f])
				ev[z][f] = v - signi(v) * mini(DECAY, absi(v))
		dirty = true
	if d - tick_at >= TICK_DAYS:
		tick_at = d
		_tick(st)
	var notes: Array = []
	if int(st.vars.get_v("SA_JOIN")) == 0 and fx.has("S05") and _aff(st, "AFF_JC_SA") >= 20:
		st.vars.set_v("SA_JOIN", 1)                                      # D-136 가맹 사건(SD-06 §3.2.2): 문제 하나 + 연합 정착지와 교역로
		dirty = true
		notes.append(["JC_SA", "사당 환승촌 위원회가 봉천과 교역 장부를 트고, 정착지 대표 모임에 사람을 보내기로 했다."])
	sync(st)
	return notes


static func _aff(st, k: String) -> int:
	return int(st.vars.get_v(k)) if st.vars.has(k) else 0


const WAR_AFF := {"BJ": "AFF_BJ", "SB": "AFF_SB", "JH": "AFF_JH", "GS": "AFF_GS", "JC": "AFF_JC_BC", "SA": "AFF_JC_SA", "YH": "AFF_YH"}


static func at_war(a: String, b: String) -> bool:
	load_data()
	for w in data.get("wars", []):
		var x := str(w[0]).replace("BC", "JC")
		var y := str(w[1]).replace("BC", "JC")
		if (x == a and y == b) or (x == b and y == a):
			return true
	return false


## 판도 틱(SD-06 §5.4): 경합 구역의 전쟁 쌍 ±2 · 공백 구역 약탈자 +1. 주인공이 있는 구역은 건너뛴다
func _tick(st) -> void:
	dirty = true
	for z in zones():
		if z == here:
			continue
		var s := state_of(st, z)
		if int(s["s"]) == 1 and at_war(str(s["a"]), str(s["b"])):
			var sa := int(s["ia"]) + (5 if _aff(st, str(WAR_AFF.get(s["a"], ""))) >= 50 else 0)
			var sb := int(s["ib"]) + (5 if _aff(st, str(WAR_AFF.get(s["b"], ""))) >= 50 else 0)
			if sa + sb <= 0:
				continue
			# 우세 판정(SD-06 §5.4)을 '센 쪽이 늘 이긴다' 대신 점수 비율의 굴림으로 — 경합이 매번 같은 결말로 굴러가지 않게(1-12m 재미 검수 ②).
			# 씨앗 = 저장 씨앗 · 날 · 구역(불러와도 같은 결과, P10)
			var r := RandomNumberGenerator.new()
			r.seed = hash("%d:%d:%s" % [int(st.check_seed), tick_at, z])
			var a_wins := r.randf() * float(sa + sb) < float(sa)
			var win := str(s["a"]) if a_wins else str(s["b"])
			var lose := str(s["b"]) if a_wins else str(s["a"])
			_bump(z, _raw(win), 2)
			_bump(z, _raw(lose), -2)
		elif int(s["s"]) == 0 and z != "PD-R01-1" and int(influence(st, z).get("YT", 0)) < 30:
			_bump(z, "YT", 1)                                                 # 관악산 북사면은 크리처 산(SD-04a SQ-S01) — 약탈자가 차오르지 않는다
	dirty = true


static func _raw(g: String) -> String:
	return "BC" if g == "JC" else g


func _bump(z: String, f: String, d: int) -> void:
	if not ev.has(z):
		ev[z] = {}
	ev[z][f] = clampi(int(ev[z].get(f, 0)) + d, -EV_MAX, EV_MAX)


## 이야기 변수에 지금 판을 적는다(PDS_ · PDO_). 바뀐 구역 목록을 돌려준다
func sync(st) -> Array:
	ingest(st)
	dirty = true
	cur.clear()
	var moved: Array = []
	for z in zones():
		var s := state_of(st, z)
		var k := vkey(z)
		if int(st.vars.get_v("PDS_" + k)) != int(s["s"]) or str(st.vars.get_v("PDO_" + k)) != str(s["a"]):
			moved.append(z)
		st.vars.set_v("PDS_" + k, int(s["s"]))
		st.vars.set_v("PDO_" + k, str(s["a"]))
	dirty = false
	return moved


# ---------------------------------------------------------------- 아는 판
## 주인공이 월드 칸 t에 섰다: 그 구역을 지금 판으로 적는다. 알던 판과 달랐으면 알림 글(재미 검수 ③)
func see(st, t: Vector2i) -> String:
	var z := zone_at(t)
	if z == "":
		return ""
	here = z
	return _learn(st, z, "seen")


## 판도 소식 방송(블록 ID 'N-PD-R01-6-…')을 맞춰 들었다 · 판도 소문을 들었다
func hear(st, z: String) -> void:
	if z != "" and (data.get("zones", {}) as Dictionary).has(z):
		_learn(st, z, "heard")


func hear_block(st, block_id: String) -> void:
	if block_id.begins_with("N-PD-"):
		var p := block_id.substr(2).split("-")
		if p.size() >= 3:
			hear(st, "%s-%s-%s" % [p[0], p[1], p[2]])


func _learn(st, z: String, how: String) -> String:
	sync(st)                                                              # 거점 원천(국회 · 은신처 · 가맹)은 장부 밖 변수라 늘 다시 센다(가볍다)
	var s := state_of(st, z)
	var d := int(st.vars.get_v("GAME_DAY"))
	var k: Dictionary = known.get(z, {})
	var msg := ""
	var changed: bool = not k.is_empty() and (int(k["s"]) != int(s["s"]) or str(k["a"]) != str(s["a"]))
	if changed and how == "seen" and int(k["day"]) < d:
		msg = "%s 쪽 깃발이 바뀌어 있다 — 핍-보이 지도를 고쳐 적었다." % zone_name(z)
	known[z] = {"s": int(s["s"]), "a": str(s["a"]), "b": str(s["b"]), "day": d,
		"chg": d if changed else int(k.get("chg", -99)), "flash": changed or bool(k.get("flash", false)), "how": how}
	for nid in data["nodes"]:
		if str(data["nodes"][nid]["zone"]) != z:
			continue
		var o := node_owner(st, nid)
		var kn: Dictionary = known_n.get(nid, {})
		var nchg: bool = not kn.is_empty() and str(kn["o"]) != o
		known_n[nid] = {"o": o, "day": d, "chg": d if nchg else int(kn.get("chg", -99))}
	return msg


## 아는 판(모르면 빈 사전)
func known_of(z: String) -> Dictionary:
	return known.get(z, {})


## 지도 커서 정보: 구역 한 줄 서술(아는 판으로 고른다) + 쓸모 있는 한 마디
func line_of(st, z: String) -> String:
	load_data()
	var k := known_of(z)
	if k.is_empty():
		return "알 수 없음 — 가 보거나 소식을 들어야 안다."
	var sn: String = STATE_NAMES[int(k["s"])]
	var lines: Dictionary = data["zones"][z].get("lines", {})
	var a := _raw(str(k["a"])) if str(k["a"]) in ["JC"] else str(k["a"])
	var t := ""
	var keys: Array = ["%s %s" % [sn, str(k["a"])], "%s %s" % [sn, a], sn]
	if lost_home(st, z, a):
		keys.push_front("%s %s 빈" % [sn, a])                               # 거점을 잃은 세력이 다시 1위: '새 두목' 판(재미 검수 ③)
	for key in keys:
		if lines.has(key):
			t = str(lines[key])
			break
	if t == "":
		t = str(data["template"][sn]).replace("{a}", fac_name(str(k["a"]))).replace("{b}", fac_name(str(k["b"])) if str(k["b"]) != "" else "다른 무리")
	return t


## 처음엔 이 구역에 f의 거점이 있었는데 지금은 하나도 없나
func lost_home(st, z: String, f: String) -> bool:
	var had := false
	for nid in data["nodes"]:
		var n: Dictionary = data["nodes"][nid]
		if str(n["zone"]) != z or str(n["owner"]) != f:
			continue
		had = true
		if node_owner(st, nid) == f:
			return false
	return had


func use_of(st, z: String) -> String:
	var k := known_of(z)
	if k.is_empty():
		return ""
	var sn: String = STATE_NAMES[int(k["s"])]
	var u: Dictionary = data.get("use", {})
	var t := str(u.get(sn + str(k["a"]), u.get(sn, ""))).replace("{a}", fac_name(str(k["a"])))
	if int(k["s"]) == 3:
		var p := price_k(st, z, true)
		if p > 1.0:
			t += " · 장사꾼이 값을 더 부른다"
		elif p < 1.0:
			t += " · 장사꾼이 값을 조금 깎아 준다"
	return t


## 'N일 전 정보'(오늘 본 것은 빈 글)
func age_of(st, z: String) -> String:
	var k := known_of(z)
	if k.is_empty():
		return ""
	var n := int(st.vars.get_v("GAME_DAY")) - int(k["day"])
	return "" if n <= 0 else "%d일 전 정보" % n


# ---------------------------------------------------------------- 세계 반응
## 무소속 상인 값 배수(SD-06 §5.6): 그 구역이 '지배'이고 지배 세력이 나를 우호 이상으로 보면 −5%, 경계 이하면 +10% — 실제 판으로(아는 판 아님)
func price_k(st, z: String, _buying := true) -> float:
	if z == "":
		return 1.0
	var s := state_of(st, z)
	if int(s["s"]) != 3:
		return 1.0
	var key := str(WAR_AFF.get(s["a"], ""))
	if key == "":
		return 1.0
	var a := _aff(st, key)
	if a >= 20:
		return 0.95
	if a <= -20:
		return 1.10
	return 1.0


## RE 범주 가중(SD-05 §6.3): 칸이 든 구역의 상태 이름과 1위 · 2위(구역 밖이면 빈 사전)
func enc_state(st, t: Vector2i) -> Dictionary:
	var z := zone_at(t)
	if z == "":
		return {}
	var s := state_of(st, z)
	return {"state": STATE_NAMES[int(s["s"])], "a": str(s["a"]), "b": str(s["b"]), "zone": z, "here": z == here}


# ---------------------------------------------------------------- 저장
func to_dict() -> Dictionary:
	return {"ev": ev.duplicate(true), "src": src.duplicate(), "fx": fx.duplicate(), "own": own.duplicate(), "known": known.duplicate(true),
		"known_n": known_n.duplicate(true), "last": last_day, "decay": decay_at, "tick": tick_at, "here": here, "kills": kills.duplicate(true)}


## JSON을 거치면 숫자가 실수로 돌아온다 — 저장 → 불러오기 → 저장이 같도록 정수로(SD-19)
static func _ints(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _ints(v[k])
		return o
	if v is Array:
		return (v as Array).map(func(x): return _ints(x))
	return v


func from_dict(d: Dictionary) -> void:
	d = _ints(d)
	ev = (d.get("ev", {}) as Dictionary).duplicate(true)
	src = (d.get("src", {}) as Dictionary).duplicate()
	fx = (d.get("fx", {}) as Dictionary).duplicate()
	own = (d.get("own", {}) as Dictionary).duplicate()
	known = (d.get("known", {}) as Dictionary).duplicate(true)
	known_n = (d.get("known_n", {}) as Dictionary).duplicate(true)
	last_day = int(d.get("last", -1))
	decay_at = int(d.get("decay", 0))
	tick_at = int(d.get("tick", 0))
	here = str(d.get("here", ""))
	kills = (d.get("kills", {}) as Dictionary).duplicate(true)
	dirty = true
	cur.clear()
