## 조사 자동 처리 (SD-12 §14.1). 엔진 무관 순수 모듈: 노드를 쓰지 않고 문자열만 다룬다(SD-19 §6.1).
## 앞 글자의 받침으로 짝 중 하나를 고른다. 판정할 수 없으면 병기형 '은(는)'을 내서 오류가 눈에 띄게 한다.
class_name Josa
extends RefCounted

enum { NONE, HAS, RIEUL, UNKNOWN }

## 조사 짝: 어느 쪽 표기로 써도 같은 짝으로 찾는다. [받침 있음, 받침 없음, ㄹ 받침]
const PAIRS := [
	["은", "는", "은"], ["이", "가", "이"], ["을", "를", "을"], ["과", "와", "과"], ["으로", "로", "로"],
	["이나", "나", "이나"], ["이랑", "랑", "이랑"], ["아", "야", "아"], ["이다", "다", "이다"],
	["이에요", "예요", "이에요"], ["이었", "였", "이었"], ["이라", "라", "이라"], ["이든", "든", "이든"],
]
## 숫자 끝자리의 읽는 소리 받침: 1 일(ㄹ) 2 이 3 삼 4 사 5 오 6 육 7 칠(ㄹ) 8 팔(ㄹ) 9 구
const DIGIT := [HAS, RIEUL, NONE, HAS, NONE, NONE, HAS, RIEUL, RIEUL, NONE]   # index 0 = 영(ㅇ 받침)
## 끝이 0이면 가장 낮은 0이 아닌 자리의 단위: 십(ㅂ) 백(ㄱ) 천(ㄴ) 만(ㄴ)
const UNIT := [HAS, HAS, HAS, HAS]
## 단어 뒤에 덧붙은 괄호는 안을 건너뛴다: 볼트(S-07)은 -> 볼트는
const OPEN_FOR := {")": "(", "]": "["}
## 단어를 감싼 따옴표·책 괄호는 닫는 표시만 떼고 안의 끝 글자로 본다: '번개사이다'가, 『교본』을
const WRAP_CLOSE := ["」", "』", "'", "\"", "’", "”", "》", "〉"]


static func pair_of(particle: String) -> Array:
	for p in PAIRS:
		if particle == p[0] or particle == p[1]:
			return p
	return []


## 문자열 끝의 받침 상태. 괄호·따옴표로 끝나면 그 안을 건너뛰고 앞 글자로 본다.
static func batchim(text: String) -> int:
	var s := text.strip_edges(false, true)
	while s.length() > 0:
		var last := s[s.length() - 1]
		if OPEN_FOR.has(last):
			var open: String = OPEN_FOR[last]
			var i := s.length() - 2
			while i >= 0 and s[i] != open:
				i -= 1
			if i < 0:
				return UNKNOWN
			s = s.substr(0, i).strip_edges(false, true)
			continue
		if last in WRAP_CLOSE:
			s = s.substr(0, s.length() - 1)
			continue
		break
	if s.is_empty():
		return UNKNOWN
	var c := s.unicode_at(s.length() - 1)
	if c >= 0xAC00 and c <= 0xD7A3:
		var jong := (c - 0xAC00) % 28
		return NONE if jong == 0 else (RIEUL if jong == 8 else HAS)
	if c >= 0x30 and c <= 0x39:
		return _number(s)
	var ch := s[s.length() - 1].to_upper()
	if ch >= "A" and ch <= "Z":
		if ch == "L" or ch == "R":
			return RIEUL
		if ch == "M" or ch == "N":
			return HAS
		return NONE
	return UNKNOWN


static func _number(s: String) -> int:
	var i := s.length() - 1
	var digits := ""
	while i >= 0 and ((s.unicode_at(i) >= 0x30 and s.unicode_at(i) <= 0x39) or s[i] == ","):
		if s[i] != ",":
			digits = s[i] + digits
		i -= 1
	var last := int(digits[digits.length() - 1])
	if last != 0:
		return DIGIT[last]
	var zeros := 0
	var k := digits.length() - 1
	while k >= 0 and digits[k] == "0":
		zeros += 1
		k -= 1
	if k < 0:
		return DIGIT[0]                     # 0 = 영
	# 10 십, 100 백, 1000 천, 10000 만(그 위는 만 단위로 끝난다: 십만·백만…도 마지막 소리는 만)
	return UNIT[mini(zeros, 4) - 1]


## particle 하나를 앞 문자열에 맞춰 고른다.
static func pick(particle: String, before: String) -> String:
	var p := pair_of(particle)
	if p.is_empty():
		return particle
	match batchim(before):
		NONE:
			return p[1]
		HAS:
			return p[0]
		RIEUL:
			return p[2]
	return "%s(%s)" % [p[0], p[1]]


## 이미 변수를 펼친 문장 안의 \J[조사] 코드를 모두 처리한다.
static func apply(text: String) -> String:
	var out := ""
	var i := 0
	while i < text.length():
		if text.substr(i, 3) == "\\J[":
			var end := text.find("]", i + 3)
			if end > 0:
				out += pick(text.substr(i + 3, end - i - 3), out)
				i = end + 1
				continue
		out += text[i]
		i += 1
	return out
