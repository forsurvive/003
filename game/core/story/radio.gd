## 라디오(단계 1-10b, SD-12 §10 · SD-17 §4): 음악 없는 텍스트 방송(바이블 K11). 방송국마다 '징글 → 인트로 → 추첨 블록 → 휴지' 편성을
## 게임 안 실시간으로 흘린다 — 라디오를 꺼도, 다른 방송국에 맞춰도 방송은 흐른다(다시 켜면 진행 중인 블록의 다음 줄부터, SD-17 §4.3).
## 대화 · 연출 중에는 맞춘 방송국만 멈췄다가 이어서 나간다. 자료 data/radio.json(원고 script/world/radio.txt).
##   추첨(SD-17 §4.3 정본): 남산 뉴스 40 / 진행 멘트 25 / 생활 정보 20 / 연속극 15 · 공보 연설 45 / 공고 35 / 표어 20(정합).
##   반응 뉴스(§4.8.2 · SD-12 §10.3): 조건이 처음 참이 되면 대기열에 들어가 다음 추첨에 먼저 나간다. 오래된 순서. 사흘 안 세 번 뒤 일반 순환.
##   반복 억제: 같은 진행 멘트는 최근 10블록 안에 다시 고르지 않고, 같은 생활 정보는 게임 시간 24시간 안에 다시 내보내지 않는다.
##   수신(§4.2 · SD-12 §10.1): ST-11 = 볼트 안 + 핍-보이 / ST-01 = 볼트를 나온 뒤(R06 · R02 북쪽 강변 · 노들섬만 깨끗, 그 밖은 잡음 —
##   MQ-205 RADIO_PUBLIC부터 전역 깨끗) / ST-02 = 볼트를 나온 뒤 전역 깨끗. 지하 실내는 한 단계 나빠진다(SD-17 §7.6).
## 소리(징글 RJ- · 스팅어 · 신호 베드)는 SD-17 소리 단계에서 — 지금은 마디마다 ID만 남긴다(sound 필드).
class_name Radio
extends RefCounted

const ORDER := ["ST-11", "ST-01", "ST-02"]
const LINE_BASE := 1.2                            ## 줄 표시 = 1.2초 + 글자 × 0.09초, 줄 사이 0.3초(SD-17 §4.3)
const LINE_PER := 0.09
const LINE_GAP := 0.3
const SPEECH_GAP := 0.3                            ## 공보 연설은 줄 사이를 0.3초 더(SD-17 §4.5)
const PAUSE := [20.0, 60.0]                        ## 휴지: 신호 베드만
const NEWS_MAX := 3                                ## 대기열 뉴스: 세 번 방송하면 내린다
const NEWS_DAYS := 3                               ## 또는 게임 시간 사흘
const TALK_RECENT := 10
const INFO_MIN := 1440
const LOG_MAX := 20
const DRAW_01 := [["news", 40], ["talk", 25], ["info", 20], ["drama", 15]]
const DRAW_02 := [["speech", 45], ["notice", 35], ["slogan", 20]]
const JINGLE := {"ST-01": ["RJ-01-01", 4.0], "ST-02": ["RJ-02-01", 3.0], "ST-11": ["RJ-11-01", 2.0]}
const HEAD := {"news": ["RJ-01-03", 2.0], "info": ["RJ-01-04", 1.5], "drama": ["RJ-01-05", 3.0], "speech": ["RJ-02-02", 6.0],
	"slogan": ["RJ-02-04", 1.0], "outro": ["RJ-01-02", 2.0]}
const KIND_NAME := {"intro": "여는 말", "talk": "진행 멘트", "info": "생활 정보", "drama": "낭독 연속극", "news": "소식", "outro": "맺음말",
	"speech": "담화", "slogan": "오늘의 표어", "notice": "공고", "chime": "구내 안내"}
const Q_NAME := ["깨끗함", "잡음 섞임", "약함"]

static var data := {}
static var blocks := {}                            ## 방송국 -> [블록]

var on := false
var tuned := ""
var heard := {}                                    ## 한 번이라도 잡힌 방송국(목록에 남는다)
var cur := {}                                      ## 방송국 -> {"segs": [마디], "si", "li", "t", "ord"}
var queue := {}                                    ## 대기 뉴스 · 공고 ID -> {"at": 들어온 게임 분, "n": 방송 횟수}
var fired := {}                                    ## 대기열에 한 번 들어간 블록(다시 안 들어간다 — 조건이 계속 참이어도)
var last := {}                                     ## 블록 ID -> 마지막으로 나간 게임 분(생활 정보 24시간 · 연설 순환)
var recent: Array = []                             ## 최근 진행 멘트 10
var drama_i := 0
var air_log: Array = []                                ## 방송 기록 20블록(핍-보이): {"st", "id", "kind", "date", "lines"}
var news_log: Array = []                           ## 지난 소식 20(뉴스 · 공고): 같은 소식은 맨 앞으로
var primed := false                                ## 처음 켤 때(옛 저장 · 시험) 이미 참인 소식은 대기열 없이 순환으로
var seq := 0
var rng_seed := 0
var _chk := 0.0


static func _load() -> void:
	if not data.is_empty() or not FileAccess.file_exists("res://data/radio.json"):
		return
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/radio.json"))
	blocks = {}
	for b in data["blocks"]:
		if not blocks.has(b["st"]):
			blocks[b["st"]] = []
		blocks[b["st"]].append(b)


static func station_name(sid: String) -> String:
	_load()
	return str(data.get("stations", {}).get(sid, {}).get("name", sid))


static func station_short(sid: String) -> String:
	_load()
	return str(data.get("stations", {}).get(sid, {}).get("short", sid))


static func station_host(sid: String) -> String:
	_load()
	return str(data.get("stations", {}).get(sid, {}).get("host", ""))


static func line_secs(text: String) -> float:
	return LINE_BASE + text.length() * LINE_PER


# ---------------------------------------------------------------- 수신
## 신호 품질: -1 안 잡힘 · 0 깨끗 · 1 잡음 · 2 약함. ctx = {"act", "vault", "pip", "under", "clean01", "public"}
static func quality(sid: String, ctx: Dictionary) -> int:
	var act := int(ctx.get("act", 0))
	var vault := bool(ctx.get("vault", false))
	var q := -1
	match sid:
		"ST-11":
			q = 0 if vault and bool(ctx.get("pip", false)) else -1
		"ST-01":
			if act >= 1 and not vault:
				q = 0 if bool(ctx.get("clean01", false)) or bool(ctx.get("public", false)) else 1
		"ST-02":
			if act >= 1 and not vault:
				q = 0
	if q >= 0 and bool(ctx.get("under", false)):
		q = mini(2, q + 1)
	return q


## 잡히는 방송국(차례대로)
static func receivable(ctx: Dictionary) -> Array:
	return ORDER.filter(func(s): return quality(s, ctx) >= 0)


## 목록(핍-보이): 잡히거나 한 번이라도 잡혔던 방송국
func listed(ctx: Dictionary) -> Array:
	return ORDER.filter(func(s): return quality(s, ctx) >= 0 or heard.has(s))


## 켜기 · 끄기(R 길게 · HUD 표시 탭). 맞춘 방송국이 안 잡히면 잡히는 첫 방송국으로
func toggle(ctx: Dictionary) -> bool:
	if on:
		on = false
		return false
	var rc := receivable(ctx)
	if rc.is_empty():
		return false
	if not rc.has(tuned):
		tuned = rc[0]
	on = true
	return true


func tune(sid: String) -> void:
	tuned = sid
	on = true


# ---------------------------------------------------------------- 흐름
## 매 프레임. ctx에 "now"(게임 분) · "hold"(대화 · 연출: 맞춘 방송국만 멈춤) · "date"(기록용 날짜 글) · 수신 조건을 넣는다.
## 새로 잡힌 방송국 ID 목록을 돌려준다(호스트가 처음 한 번 안내를 띄운다)
func tick(dt: float, st: StoryState, ctx: Dictionary) -> Array:
	_load()
	if blocks.is_empty():
		return []
	if rng_seed == 0:
		rng_seed = st.check_seed if st.check_seed != 0 else 7207
	var fresh: Array = []
	for sid in receivable(ctx):
		if not heard.has(sid):
			heard[sid] = true
			fresh.append(sid)
	if on and quality(tuned, ctx) < 0:                                # 맞춘 방송국이 끊겼다(볼트를 나섰다 등): 잡히는 방송국으로 넘긴다
		var rc := receivable(ctx)
		if rc.is_empty():
			on = false
		else:
			tuned = rc[0]
	_chk -= dt
	if _chk <= 0.0:
		_chk = 1.0
		_watch(st, int(ctx.get("now", 0)))
	for sid in blocks:
		if sid == tuned and on and bool(ctx.get("hold", false)):
			continue
		_advance(sid, dt, st, ctx)
	return fresh


## 조건이 처음 참이 된 소식 · 공고를 대기열에 넣고, 오래된(사흘 · 세 번) 것을 내린다
func _watch(st: StoryState, now: int) -> void:
	for sid in blocks:
		for b in blocks[sid]:
			if not (str(b["kind"]) in ["news", "notice"]) or fired.has(b["id"]) or str(b["cond"]) == "":
				continue
			if StoryExpr.test(str(b["cond"]), st):
				fired[b["id"]] = true
				if primed:
					queue[b["id"]] = {"at": now, "n": 0}
	primed = true
	for id in queue.keys():
		var q: Dictionary = queue[id]
		if int(q["n"]) >= NEWS_MAX or (now > 0 and int(q["at"]) > 0 and now - int(q["at"]) > NEWS_DAYS * 1440):
			queue.erase(id)


func _advance(sid: String, dt: float, st: StoryState, ctx: Dictionary) -> void:
	if not cur.has(sid):
		cur[sid] = {"segs": [], "si": 0, "li": 0, "t": 0.0, "ord": 0}
	var c: Dictionary = cur[sid]
	var left := dt
	var guard := 0
	while left > 0.0 and guard < 64:
		guard += 1
		if int(c["si"]) >= (c["segs"] as Array).size():
			c["segs"] = _program(sid, st, ctx)
			c["si"] = 0
			c["li"] = 0
			c["t"] = 0.0
			_begin(sid, c, st, ctx)
			if (c["segs"] as Array).is_empty():
				return
		var need := _seg_len(sid, c)
		var room := need - float(c["t"])
		if left < room:
			c["t"] = float(c["t"]) + left
			return
		left -= room
		_next(sid, c, st, ctx)


## 지금 마디(또는 블록의 지금 줄)의 길이(초)
func _seg_len(sid: String, c: Dictionary) -> float:
	var sg: Dictionary = c["segs"][int(c["si"])]
	if str(sg["k"]) != "block":
		return float(sg["secs"])
	var ln: Dictionary = sg["lines"][int(c["li"])]
	var gap := LINE_GAP + (SPEECH_GAP if str(sg["kind"]) == "speech" else 0.0)
	return line_secs(str(ln["text"])) + gap


func _next(sid: String, c: Dictionary, st: StoryState, ctx: Dictionary) -> void:
	c["t"] = 0.0
	var sg: Dictionary = c["segs"][int(c["si"])]
	if str(sg["k"]) == "block" and int(c["li"]) + 1 < (sg["lines"] as Array).size():
		c["li"] = int(c["li"]) + 1
		return
	c["si"] = int(c["si"]) + 1
	c["li"] = 0
	if int(c["si"]) < (c["segs"] as Array).size():
		_begin(sid, c, st, ctx)


## 블록이 나가기 시작할 때: 방송 기록 · 지난 소식 · 대기열 횟수 · 반복 억제
func _begin(sid: String, c: Dictionary, st: StoryState, ctx: Dictionary) -> void:
	if int(c["si"]) >= (c["segs"] as Array).size():
		return
	var sg: Dictionary = c["segs"][int(c["si"])]
	if str(sg["k"]) != "block":
		return
	var id := str(sg["id"])
	var now := int(ctx.get("now", 0))
	last[id] = now
	var kind := str(sg["kind"])
	if kind == "talk":
		recent.append(id)
		while recent.size() > TALK_RECENT:
			recent.pop_front()
	if queue.has(id):
		queue[id]["n"] = int(queue[id]["n"]) + 1
	if on and tuned == sid and id.begins_with("N-PD-"):
		st.turf.hear_block(st, id)                                     # 판도 소식을 맞춰 들었다(1-12m): 그 구역 아는 판을 고친다(SD-06 §5.7)
	var row := {"st": sid, "id": id, "kind": kind, "date": str(ctx.get("date", "")),
		"lines": (sg["lines"] as Array).map(func(l): return [str(l["who"]), str(l["text"])])}
	air_log.push_front(row)
	while air_log.size() > LOG_MAX:
		air_log.pop_back()
	if kind in ["news", "notice"]:
		for i in range(news_log.size() - 1, -1, -1):
			if str(news_log[i]["id"]) == id:
				news_log.remove_at(i)
		news_log.push_front(row)
		while news_log.size() > LOG_MAX:
			news_log.pop_back()


func _rand() -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(rng_seed) + ":" + str(seq))
	seq += 1
	return r.randf()


func _ok(b: Dictionary, st: StoryState) -> bool:
	return str(b["cond"]) == "" or StoryExpr.test(str(b["cond"]), st)


func _of(sid: String, kind: String, st: StoryState) -> Array:
	return (blocks.get(sid, []) as Array).filter(func(b): return str(b["kind"]) == kind and _ok(b, st))


func _pick(pool: Array) -> Dictionary:
	return {} if pool.is_empty() else pool[mini(pool.size() - 1, int(_rand() * pool.size()))]


## 대기열의 가장 오래된 소식(그 방송국 것, 조건이 아직 참인 것)
func _queued(sid: String, st: StoryState) -> Dictionary:
	var best: Dictionary = {}
	var bt := 1 << 40
	for b in blocks.get(sid, []):
		if queue.has(b["id"]) and _ok(b, st) and int(queue[b["id"]]["at"]) < bt:
			bt = int(queue[b["id"]]["at"])
			best = b
	return best


## 한 편성(마디 목록): 징글 · 인트로 · 본 블록 · (맺음) · 휴지
func _program(sid: String, st: StoryState, ctx: Dictionary) -> Array:
	var segs: Array = []
	var jg: Array = JINGLE.get(sid, ["", 2.0])
	segs.append({"k": "jingle", "sound": jg[0], "secs": jg[1]})
	var now := int(ctx.get("now", 0))
	match sid:
		"ST-11":
			var ch := _of(sid, "chime", st)
			if not ch.is_empty():
				var c: Dictionary = cur.get(sid, {})
				var o := int(c.get("ord", 0))
				_add(segs, ch[o % ch.size()], st)
				if not c.is_empty():
					c["ord"] = o + 1
		"ST-01":
			var intro := _pick(_of(sid, "intro", st))
			if not intro.is_empty():
				_add(segs, intro, st)
			var body := _queued(sid, st)
			if body.is_empty():
				body = _draw(sid, DRAW_01, st, now)
			if not body.is_empty():
				_head(segs, str(body["kind"]))
				_add(segs, body, st)
				if str(body["kind"]) == "drama":
					drama_i += 1
			if _rand() < 0.25:
				var out := _pick(_of(sid, "outro", st))
				if not out.is_empty():
					_head(segs, "outro")
					_add(segs, out, st)
		"ST-02":
			if _rand() < 0.5:
				var intro := _pick(_of(sid, "intro", st))
				if not intro.is_empty():
					_add(segs, intro, st)
			var body := _queued(sid, st)
			if body.is_empty():
				body = _draw(sid, DRAW_02, st, now)
			if not body.is_empty():
				_head(segs, str(body["kind"]))
				_add(segs, body, st)
	segs.append({"k": "pause", "sound": "", "secs": lerpf(PAUSE[0], PAUSE[1], _rand())})
	return segs


func _head(segs: Array, kind: String) -> void:
	if HEAD.has(kind):
		segs.append({"k": "jingle", "sound": HEAD[kind][0], "secs": HEAD[kind][1]})


## 블록을 마디로: 슬롯({P_REGNO} 등)은 나가는 순간의 값으로 채운다
func _add(segs: Array, b: Dictionary, st: StoryState) -> void:
	var lines: Array = []
	for l in b["lines"]:
		var t := str(l["text"])
		if t.contains("{"):
			for k in ["P_REGNO", "P_SURNAME", "P_GIVEN"]:
				if st.vars.has(k):
					var v := str(st.vars.get_v(k))
					t = t.replace("{%s}" % k, v if v != "" else "미상")
		var row := {"who": str(l["who"]), "text": t}
		if l.has("sting"):
			row["sting"] = str(l["sting"])
		lines.append(row)
	segs.append({"k": "block", "id": str(b["id"]), "kind": str(b["kind"]), "lines": lines})


## 비율 추첨. 고른 갈래에 나갈 블록이 없으면 남은 갈래에서 다시
func _draw(sid: String, table: Array, st: StoryState, now: int) -> Dictionary:
	var rows: Array = table.duplicate(true)
	while not rows.is_empty():
		var total := 0.0
		for r in rows:
			total += float(r[1])
		var x := _rand() * total
		var pick: Array = rows[-1]
		for r in rows:
			x -= float(r[1])
			if x <= 0.0:
				pick = r
				break
		var b := _from(sid, str(pick[0]), st, now)
		if not b.is_empty():
			return b
		rows.erase(pick)
	return {}


func _from(sid: String, kind: String, st: StoryState, now: int) -> Dictionary:
	var pool := _of(sid, kind, st)
	match kind:
		"news":                                                        # 일반 순환: 대기열을 거친(또는 지난) 소식 중 가장 오래 안 나간 것
			pool = pool.filter(func(b): return fired.has(b["id"]) and not queue.has(b["id"]))
			return _oldest(pool)
		"talk":
			pool = pool.filter(func(b): return not recent.has(b["id"]))
			return _pick(pool)
		"info":
			pool = pool.filter(func(b): return not last.has(b["id"]) or now <= 0 or now - int(last[b["id"]]) >= INFO_MIN)
			return _pick(pool)
		"drama":
			pool.sort_custom(func(a, b): return int(a.get("ep", 0)) < int(b.get("ep", 0)))
			return {} if pool.is_empty() else pool[drama_i % pool.size()]
		"speech", "notice":                                            # 조건이 맞는 것 가운데 가장 오래 안 나간 것(새로 열린 연설이 먼저 나간다)
			return _oldest(pool)
	return _pick(pool)


func _oldest(pool: Array) -> Dictionary:
	var best: Dictionary = {}
	var bt := 1 << 40
	for b in pool:
		var t := int(last.get(b["id"], -(1 << 40)))
		if t < bt:
			bt = t
			best = b
	return best


# ---------------------------------------------------------------- 보이기
## 맞춘 방송국에서 지금 나가는 것: {"kind": "line" | "jingle" | "pause", "who", "text", "sting", "block", "bkind", "age"} — 꺼져 있으면 빈 사전
func now_playing() -> Dictionary:
	if not on or not cur.has(tuned):
		return {}
	var c: Dictionary = cur[tuned]
	if int(c["si"]) >= (c["segs"] as Array).size():
		return {}
	var sg: Dictionary = c["segs"][int(c["si"])]
	if str(sg["k"]) != "block":
		return {"kind": str(sg["k"]), "sound": str(sg["sound"]), "age": float(c["t"])}
	var ln: Dictionary = sg["lines"][int(c["li"])]
	var shown := float(c["t"]) < line_secs(str(ln["text"]))             # 줄 사이 0.3초는 비운다
	return {"kind": "line" if shown else "gap", "who": str(ln["who"]), "text": str(ln["text"]), "sting": str(ln.get("sting", "")),
		"block": str(sg["id"]), "bkind": str(sg["kind"]), "age": float(c["t"])}


## 지금 코너 이름(핍-보이 상세): '소식' · '낭독 연속극 2화' 등. 휴지 중이면 '신호만'
func corner(sid: String) -> String:
	if not cur.has(sid):
		return "—"
	var c: Dictionary = cur[sid]
	var segs: Array = c["segs"]
	for i in range(int(c["si"]), segs.size()):
		var sg: Dictionary = segs[i]
		if str(sg["k"]) == "block":
			var nm := str(KIND_NAME.get(str(sg["kind"]), ""))
			if str(sg["kind"]) == "drama":
				var b := _block(sid, str(sg["id"]))
				nm += " %d화" % int(b.get("ep", 1))
			return nm if i == int(c["si"]) else "다음: " + nm
		if str(sg["k"]) == "pause" and i == int(c["si"]):
			return "신호만(쉬는 중)"
	return "—"


func _block(sid: String, id: String) -> Dictionary:
	for b in blocks.get(sid, []):
		if str(b["id"]) == id:
			return b
	return {}


## 신호가 약하면 글자 일부를 ▒로(SD-17 §7.6) — 같은 줄은 늘 같은 자리
static func garble(text: String, q: int) -> String:
	if q < 2:
		return text
	var out := ""
	for i in text.length():
		var ch := text[i]
		out += "▒" if ch != " " and absi(hash(text + str(i))) % 4 == 0 else ch
	return out


## 끊김(잡음 30초에 0.3초 · 약함 30%): 이 순간 자막이 비나
static func dropout(q: int, t: float) -> bool:
	if q == 1:
		return fmod(t, 30.0) < 0.3
	if q == 2:
		return fmod(t, 10.0) < 3.0
	return false


# ---------------------------------------------------------------- 저장
func to_dict() -> Dictionary:
	return {"on": on, "tuned": tuned, "heard": heard.keys(), "cur": cur.duplicate(true), "queue": queue.duplicate(true),
		"fired": fired.keys(), "last": last.duplicate(), "recent": recent.duplicate(), "drama": drama_i,
		"log": air_log.duplicate(true), "news": news_log.duplicate(true), "seq": seq, "seed": rng_seed, "primed": primed}


func from_dict(d: Dictionary) -> void:
	on = bool(d.get("on", false))
	tuned = str(d.get("tuned", ""))
	heard = {}
	for k in d.get("heard", []):
		heard[str(k)] = true
	cur = (d.get("cur", {}) as Dictionary).duplicate(true)
	for sid in cur:                                                   # JSON을 지나며 정수가 실수로 — 차례 값은 정수로 되돌린다
		for k in ["si", "li", "ord"]:
			cur[sid][k] = int(cur[sid].get(k, 0))
	queue = {}
	for k in d.get("queue", {}):
		queue[str(k)] = {"at": int(d["queue"][k].get("at", 0)), "n": int(d["queue"][k].get("n", 0))}
	fired = {}
	for k in d.get("fired", []):
		fired[str(k)] = true
	last = {}
	for k in d.get("last", {}):
		last[str(k)] = int(d["last"][k])
	recent = (d.get("recent", []) as Array).duplicate()
	drama_i = int(d.get("drama", 0))
	air_log = (d.get("log", []) as Array).duplicate(true)
	news_log = (d.get("news", []) as Array).duplicate(true)
	seq = int(d.get("seq", 0))
	rng_seed = int(d.get("seed", 0))
	primed = bool(d.get("primed", false))
