## 해킹(단계 1-4, SD-12 §8.1 공통 · §8.3 한국어 음절 단어 맞히기) — 노드를 쓰지 않는 판정 덩어리. 화면은 systems/ui/hack_screen.gd.
## 난이도 5단계: 요구 과학 15/25/50/75/100 · 단어 3~7음절 · 기본 단어 수 8/10/12/14/16(과학이 요구치를 7 넘을 때마다 −1, 최소 5) · XP 20~60.
## 덤프: 2단 × 16행, 행마다 주소(4자리 16진) + 12칸(한글 음절 2칸 · 기호 1칸). 단어는 짝수 칸에서 시작해 행을 넘어가도 음절이 쪼개지지 않는다.
## 고르기: 단어 → 정답이면 접속, 아니면 `x/y 일치`(같은 자리 같은 음절 수)와 시도 −1 · 같은 행의 괄호 짝(사이에 완전한 단어가 없을 때) →
## 오답 1개 제거 또는 시도 4회 회복(짝마다 한 번) · 짝 없는 기호 → 시도 −1('해킹 보조'면 잃지 않음). 시도 0 = 영구 잠김.
class_name Hack
extends RefCounted

const GRADES := ["매우 쉬움", "쉬움", "보통", "어려움", "매우 어려움"]
const REQ := [15, 25, 50, 75, 100]
const LEN := [3, 4, 5, 6, 7]
const BASE_N := [8, 10, 12, 14, 16]
const XP := [20, 30, 40, 50, 60]
const TRIES := 4
const ROWS := 16
const COLS := 2
const CELLS := 12
const TOTAL := ROWS * COLS * CELLS
const JUNK := "!@#$%^&*-_=+;:'\"|\\/?.,~"
const OPEN := "([{<"
const CLOSE := ")]}>"
const LOCK_TEXT := "단말기 잠김. 관리 담당자에게 문의 바람."

static var _pool := {}

var grade := 0
var words: Array = []          ## 덤프에 놓인 단어(0번이 정답은 아니다 — answer로 본다)
var answer := ""
var tries := TRIES
var cells: Array = []          ## TOTAL칸: {"ch": 글자, "w": 단어 번호(-1 = 기호), "head": 음절의 첫 칸인가}
var starts: Array = []         ## 단어 번호 -> 첫 칸
var removed := {}              ## 지운 오답(단어 번호 -> true): 칸은 '.'으로 바뀐다
var used := {}                 ## 쓴 괄호 짝(여는 칸 -> true)
var log: Array = []            ## 기록창 줄
var state := "play"            ## play · ok · locked
var assist := false            ## '해킹 보조'(짝 없는 기호로 시도를 잃지 않음 · 결과와 안 맞는 후보 흐림)
var guesses: Array = []        ## [단어, 일치 수] — 보조 흐림에 쓴다
var address := 0
var rng := RandomNumberGenerator.new()


## 단말 등급(0~4) · 과학 · 주제군(T1~T4) · 씨앗(0 = 무작위)
func _init(g := 0, science := 0, theme := "T1", seed := 0) -> void:
	grade = clampi(g, 0, 4)
	rng.seed = seed if seed != 0 else int(Time.get_ticks_usec())
	var n := word_count(grade, science)
	words = choose(pool_for(theme, LEN[grade]), n, rng)
	if words.size() < n:                                             # 그 주제군만으로 모자라면 모든 주제군에서
		words = choose(pool_for("", LEN[grade]), n, rng)
	answer = words[0]
	_shuffle(words)
	_lay_out()


static func can_try(g: int, science: int) -> bool:
	return science >= REQ[clampi(g, 0, 4)]


## 실제 단어 수 = 기본 − ⌊(과학 − 요구치) ÷ 7⌋, 최소 5
static func word_count(g: int, science: int) -> int:
	return maxi(5, BASE_N[g] - floori(maxf(0.0, science - REQ[g]) / 7.0))


static func likeness(a: String, b: String) -> int:
	var k := 0
	for i in mini(a.length(), b.length()):
		if a[i] == b[i]:
			k += 1
	return k


static func _mask(a: String, b: String) -> int:
	var m := 0
	for i in mini(a.length(), b.length()):
		if a[i] == b[i]:
			m |= 1 << i
	return m


## 주제군 단어 풀(game/data/hack_words.json). 그 주제군에 그 길이가 적으면 모든 주제군을 합친다
static func pool_for(theme: String, length: int) -> Array:
	if _pool.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/hack_words.json"))
		_pool = d["words"] if d is Dictionary else {}
	var k := str(length)
	var out: Array = _pool.get(theme, {}).get(k, []).duplicate()
	if out.size() < 40 or theme == "":
		for t in _pool:
			if t != theme:
				out += _pool[t].get(k, [])
	return out


## 생성 규칙(SD-12 §8.3 '단어 풀 규격'): 정답 1개 → 후보의 절반 이상은 정답과 1자리 이상 일치 · 0일치는 최대 2개 ·
## 정답과 같은 일치 패턴(같은 자리)을 가진 후보끼리의 짝은 줄인다 — 패턴 묶음을 돌아가며 하나씩 뽑아 겹치는 짝을 가장 적게 만든다
## (합성어 풀은 같은 머리를 가진 단어가 같은 패턴을 갖기 때문에 '한 쌍 이하'를 늘 지킬 수는 없다 — 구현 정합).
## 정답은 풀에서 몇 개를 뽑아 보고 서로 다른 일치 패턴이 가장 많은 단어로 정한다. 반환 [정답, 후보…](모자라면 n보다 적다)
static func choose(pool: Array, n: int, r: RandomNumberGenerator) -> Array:
	var order := pool.duplicate()
	_shuffle_r(order, r)
	var answer := ""
	var best := -1
	var groups := {}
	for a in order.slice(0, 40):
		var g := {}
		for b in pool:
			if b != a:
				var m := _mask(a, b)
				if not g.has(m):
					g[m] = []
				g[m].append(b)
		var score := g.size() - (1 if g.has(0) else 0)
		if score > best:
			best = score
			answer = a
			groups = g
	var out: Array = [answer]
	var keys: Array = groups.keys().filter(func(m): return m != 0)
	_shuffle_r(keys, r)
	for m in keys:
		_shuffle_r(groups[m], r)
	var zero: Array = groups.get(0, [])
	_shuffle_r(zero, r)
	var need := ceili((n - 1) / 2.0)
	var rnd := 0
	var zero_used := 0
	while out.size() < n:
		var added := false
		for m in keys:
			if out.size() >= n:
				break
			if rnd < groups[m].size():
				out.append(groups[m][rnd])
				added = true
			# 일치 후보가 절반을 넘긴 뒤에는 0일치 후보(최대 2개)를 섞을 수 있다
			if out.size() - 1 >= need and zero_used < mini(2, zero.size()) and out.size() < n and r.randf() < 0.3:
				out.append(zero[zero_used])
				zero_used += 1
		rnd += 1
		if not added:
			while zero_used < mini(2, zero.size()) and out.size() < n:
				out.append(zero[zero_used])
				zero_used += 1
			break
	return out


static func _shuffle_r(a: Array, r: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _shuffle(a: Array) -> void:
	_shuffle_r(a, rng)


# ---------------------------------------------------------------- 덤프 배치
func _lay_out() -> void:
	address = 0xF000 + rng.randi_range(0, 0x9F) * 0x10
	cells = []
	starts = []
	var wl: int = LEN[grade] * 2
	var free: int = TOTAL - wl * words.size()
	# 단어 사이 틈: 남는 칸을 단어 수 + 1 자리에 나눈다(짝수 시작을 맞추느라 한 칸씩 더 쓸 수 있다)
	var gaps: Array = []
	for i in words.size() + 1:
		gaps.append(0)
	for i in free - words.size() - 2:
		gaps[rng.randi_range(0, gaps.size() - 1)] += 1
	for wi in words.size():
		_junk(gaps[wi])
		if cells.size() % 2 == 1:
			_junk(1)
		starts.append(cells.size())
		var w: String = words[wi]
		for s in w.length():
			cells.append({"ch": w[s], "w": wi, "head": true})
			cells.append({"ch": "", "w": wi, "head": false})
	_junk(TOTAL - cells.size())
	cells.resize(TOTAL)
	_brackets()


func _junk(k: int) -> void:
	for i in maxi(0, k):
		if cells.size() >= TOTAL:
			return
		cells.append({"ch": JUNK[rng.randi_range(0, JUNK.length() - 1)], "w": -1, "head": true})


## 기호 자리 몇 곳에 괄호를 심는다: 행마다 여는 괄호 하나 + 같은 행 뒤쪽 기호 자리에 닫는 괄호(일부는 짝 없이)
func _brackets() -> void:
	for row in ROWS * COLS:
		if rng.randf() > 0.55:
			continue
		var base := row * CELLS
		var free: Array = []
		for c in CELLS:
			if cells[base + c]["w"] == -1:
				free.append(c)
		if free.size() < 2:
			continue
		var k := rng.randi_range(0, 3)
		var a: int = free[rng.randi_range(0, free.size() - 2)]
		cells[base + a]["ch"] = OPEN[k]
		var after := free.filter(func(c): return c > a)
		if not after.is_empty() and rng.randf() < 0.8:
			cells[base + int(after[rng.randi_range(0, after.size() - 1)])]["ch"] = CLOSE[k]


## 칸 번호 → (단, 행, 열)
static func cell_pos(i: int) -> Vector3i:
	var row := i / CELLS
	return Vector3i(row / ROWS, row % ROWS, i % CELLS)


## 칸을 골랐을 때 잡히는 범위 [첫 칸, 끝 칸(포함), 종류 "word"|"pair"|"junk"|"none"]
func target_at(i: int) -> Array:
	if i < 0 or i >= TOTAL:
		return [i, i, "none"]
	var c: Dictionary = cells[i]
	if c["w"] >= 0:
		var wi: int = c["w"]
		if removed.has(wi):
			return [i, i, "none"]
		return [starts[wi], starts[wi] + LEN[grade] * 2 - 1, "word"]
	var p := pair_end(i)
	if p >= 0:
		return [i, p, "pair"]
	return [i, i, "junk"]


## 여는 괄호 칸이면 같은 행 안의 짝 칸(사이에 완전한 단어가 끼면 무효, 쓴 짝 무효), 아니면 −1
func pair_end(i: int) -> int:
	var ch: String = cells[i]["ch"]
	var k := OPEN.find(ch)
	if k < 0 or used.has(i) or cells[i]["w"] != -1:
		return -1
	var row_end := (i / CELLS + 1) * CELLS
	for j in range(i + 1, row_end):
		if cells[j]["w"] != -1 and not removed.has(cells[j]["w"]) and starts[cells[j]["w"]] >= i \
				and starts[cells[j]["w"]] + LEN[grade] * 2 - 1 < row_end:
			return -1                                                    # 사이에 완전한 단어
		if cells[j]["ch"] == CLOSE[k]:
			return j
	return -1


## 칸 i를 고른다. 반환: 기록창에 더한 줄들
func pick(i: int) -> Array:
	if state != "play":
		return []
	var t := target_at(i)
	var out: Array = []
	match t[2]:
		"word":
			var w: String = words[cells[i]["w"]]
			out.append("> " + w)
			if w == answer:
				out.append("> 접속 허가")
				out.append("> 잠시 기다리십시오…")
				state = "ok"
			else:
				var k := likeness(w, answer)
				guesses.append([w, k])
				tries -= 1
				out.append("> 접속 거부")
				out.append("> %d/%d 일치" % [k, answer.length()])
				if tries <= 0:
					out.append("> " + LOCK_TEXT)
					state = "locked"
		"pair":
			var s := ""
			for j in range(t[0], t[1] + 1):
				s += str(cells[j]["ch"])
			used[t[0]] = true
			out.append("> " + s)
			var duds: Array = []
			for wi in words.size():
				if words[wi] != answer and not removed.has(wi):
					duds.append(wi)
			if duds.is_empty() or (tries < TRIES and rng.randf() < 0.25):
				tries = TRIES
				out.append("> 시도 횟수 초기화")
			else:
				var d: int = duds[rng.randi_range(0, duds.size() - 1)]
				removed[d] = true
				for j in range(starts[d], starts[d] + LEN[grade] * 2):
					cells[j]["ch"] = "."
					cells[j]["head"] = true
					cells[j]["w"] = -1
				out.append("> 오답 제거")
		"junk":
			out.append("> " + str(cells[i]["ch"]))
			out.append("> 오류")
			if not assist:
				tries -= 1
				if tries <= 0:
					out.append("> " + LOCK_TEXT)
					state = "locked"
	log += out
	return out


## '해킹 보조': 지금까지의 결과와 맞지 않는 후보(정답일 수 없는 단어)
func ruled_out(wi: int) -> bool:
	var w: String = words[wi]
	for g in guesses:
		if w == g[0] or likeness(w, g[0]) != int(g[1]):
			return true
	return false


func alive_words() -> Array:
	var out: Array = []
	for wi in words.size():
		if not removed.has(wi):
			out.append(wi)
	return out


func xp() -> int:
	return XP[grade]
