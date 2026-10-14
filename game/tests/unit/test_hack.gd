## 해킹(단계 1-4, SD-12 §8.1·§8.3): 단어 수 공식 · 생성 규칙(절반 이상 일치 · 0일치 2개 이하 · 같은 패턴 한 쌍 이하) · 덤프 배치
## (2단 × 16행 × 12칸, 한글 2칸, 단어 짝수 칸 시작) · x/y 일치 · 시도 4회 · 영구 잠김 · 괄호 짝 · 해킹 보조.
extends RefCounted


func test_hack_rules(t) -> void:
	t.eq([Hack.word_count(0, 15), Hack.word_count(2, 50), Hack.word_count(2, 100), Hack.word_count(4, 100)], [8, 12, 5, 16],
		"단어 수 = 기본 − ⌊(과학 − 요구치) ÷ 7⌋, 최소 5(과학 100으로 보통 = 5개)")
	t.eq(Hack.likeness("대피명령", "대기명령"), 3, "대피명령 / 대기명령 = 3/4 일치(SD-12 §8.3 예)")
	t.ok(not Hack.can_try(3, 74) and Hack.can_try(3, 75), "요구치 미달이면 시도할 수 없다(§8.1)")
	for g in 5:
		for s in [3, 17, 91, 1234]:
			var h := Hack.new(g, Hack.REQ[g], ["T1", "T2", "T3", "T4"][s % 4], s)
			var n := Hack.word_count(g, Hack.REQ[g])
			t.eq(h.words.size(), n, "등급 %d 씨앗 %d: 단어 %d개" % [g, s, n])
			var matched := 0
			var zero := 0
			var masks := {}
			var dup_pairs := 0
			for w in h.words:
				t.eq(w.length(), Hack.LEN[g], "단어 길이 %d음절" % Hack.LEN[g])
				if w == h.answer:
					continue
				var m := Hack._mask(h.answer, w)
				if m == 0:
					zero += 1
				else:
					matched += 1
				dup_pairs += int(masks.get(m, 0))
				masks[m] = int(masks.get(m, 0)) + 1
			t.ok(matched >= ceili((n - 1) / 2.0), "등급 %d 씨앗 %d: 후보 절반 이상이 정답과 1자리 이상 일치(%d/%d)" % [g, s, matched, n - 1])
			t.ok(zero <= 2, "0일치 후보 2개 이하")
			# 같은 일치 패턴 짝을 가장 적게: 풀에 남은 패턴이 있는데 한 패턴만 2개 넘게 더 뽑지 않는다(묶음을 돌아가며)
			var pool := Hack.pool_for(["T1", "T2", "T3", "T4"][s % 4], Hack.LEN[g])
			if not h.words.all(func(w): return w in pool):
				pool = Hack.pool_for("", Hack.LEN[g])
			var avail := {}
			for w in pool:
				if w != h.answer:
					var m2 := Hack._mask(h.answer, w)
					avail[m2] = int(avail.get(m2, 0)) + 1
			var even := true
			for m1 in masks:
				for m2 in avail:
					if m1 != 0 and m2 != 0 and int(masks.get(m2, 0)) < int(avail[m2]) and int(masks[m1]) > int(masks.get(m2, 0)) + 1:
						even = false
			t.ok(even, "같은 일치 패턴 짝을 가장 적게(묶음을 돌아가며 뽑음, 겹친 짝 %d)" % dup_pairs)
			# 덤프: 칸 수 · 단어마다 짝수 칸 시작 · 음절이 행을 넘어 쪼개지지 않음
			t.eq(h.cells.size(), Hack.TOTAL, "덤프 2 × 16 × 12 = 384칸")
			for wi in h.words.size():
				var st0: int = h.starts[wi]
				t.ok(st0 % 2 == 0, "단어는 짝수 칸에서 시작한다")
				t.eq(str(h.cells[st0]["ch"]) + str(h.cells[st0 + 2]["ch"]), h.words[wi].substr(0, 2), "덤프에 단어가 그대로 놓인다")


func test_hack_play(t) -> void:
	var h := Hack.new(1, 25, "T2", 4242)
	var wrong := -1
	for wi in h.words.size():
		if h.words[wi] != h.answer:
			wrong = wi
			break
	var lines := h.pick(h.starts[wrong])
	t.eq(lines[0], "> " + h.words[wrong], "고른 단어가 기록창에 찍힌다")
	t.eq(lines[2], "> %d/%d 일치" % [Hack.likeness(h.words[wrong], h.answer), 4], "x/y 일치")
	t.eq(h.tries, 3, "오답이면 시도 −1")
	t.ok(h.ruled_out(wrong), "해킹 보조: 고른 오답은 흐린다")
	# 짝 없는 기호: 시도 −1, 보조면 잃지 않는다
	var junk := -1
	for i in Hack.TOTAL:
		if h.target_at(i)[2] == "junk":
			junk = i
			break
	h.assist = true
	h.pick(junk)
	t.eq(h.tries, 3, "해킹 보조: 짝 없는 기호로 시도를 잃지 않는다")
	h.assist = false
	h.pick(junk)
	t.eq(h.tries, 2, "짝 없는 기호 = 시도 −1")
	# 괄호 짝: 한 번만 쓰인다 → 오답 제거 또는 시도 회복
	var pair := -1
	for i in Hack.TOTAL:
		if h.target_at(i)[2] == "pair":
			pair = i
			break
	if pair >= 0:
		var alive := h.alive_words().size()
		var before := h.tries
		h.pick(pair)
		t.ok(h.alive_words().size() == alive - 1 or (h.tries == Hack.TRIES and before < Hack.TRIES), "괄호 짝 = 오답 제거 또는 시도 4회 회복")
		t.ok(h.target_at(pair)[2] != "pair", "쓴 괄호 짝은 다시 쓸 수 없다")
		t.ok(h.words[h.alive_words()[0]] != "" and h.answer in h.alive_words().map(func(wi): return h.words[wi]), "정답은 지워지지 않는다")
	# 정답
	h.pick(h.starts[h.words.find(h.answer)])
	t.eq(h.state, "ok", "정답이면 접속")
	t.eq(h.xp(), 30, "쉬움 성공 XP 30(§8.1)")
	# 4번 틀리면 영구 잠김
	var l := Hack.new(0, 15, "T1", 99)
	var bad: Array = []
	for wi in l.words.size():
		if l.words[wi] != l.answer:
			bad.append(wi)
	for k in 4:
		l.pick(l.starts[bad[k]])
	t.eq(l.state, "locked", "시도 4회를 모두 쓰면 영구 잠김")
	t.eq(l.log[-1], "> " + Hack.LOCK_TEXT, "잠김 문구")
	t.eq(l.pick(l.starts[l.words.find(l.answer)]), [], "잠긴 뒤에는 고를 수 없다")


## 괄호 짝 사이에 완전한 단어가 끼면 무효(§8.3)
func test_hack_brackets(t) -> void:
	var h := Hack.new(0, 15, "T1", 7)
	for c in Hack.CELLS:
		h.cells[c] = {"ch": "#", "w": -1, "head": true}
	h.cells[0]["ch"] = "("
	h.cells[11]["ch"] = ")"
	t.eq(h.pair_end(0), 11, "같은 행 () 짝")
	# 사이에 3음절 단어(6칸)를 넣는다
	h.starts[0] = 2
	for k in 3:
		h.cells[2 + k * 2] = {"ch": "가", "w": 0, "head": true}
		h.cells[3 + k * 2] = {"ch": "", "w": 0, "head": false}
	t.eq(h.pair_end(0), -1, "사이에 완전한 단어가 끼면 짝이 아니다")
