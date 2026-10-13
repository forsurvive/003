## 줄바꿈 (SD-12 §14.2). 엔진 무관 순수 모듈: 글자 폭은 measure(문자열) -> 픽셀 콜백으로 받는다.
## 어절(띄어쓰기) 단위로 자르고, 한 어절이 한 줄보다 길 때만 글자 단위로 자른다.
## 행두 금칙: 줄 첫 글자에 . , ! ? : ; ) ] } 」 』 … ~ % 가 오지 않게 앞 어절에 붙인다.
## 행말 금칙: 줄 끝이 ( [ { 「 『 이면 다음 줄로 넘긴다. 줄바꿈 금지 공백(U+00A0, 원고의 \.)은 자르지 않는다. '\n'은 강제 줄바꿈.
class_name TextWrap
extends RefCounted

const NO_START := ".,!?:;)]}」』…~%"
const NO_END := "([{「『"


## 반환: 줄 배열. 각 줄은 원문의 한 조각(앞뒤 공백 없음)이고, 줄들을 공백 하나로 이으면 원문의 어절 순서와 같다.
static func wrap(text: String, measure: Callable, width: float) -> Array[String]:
	var out: Array[String] = []
	for para in text.split("\n"):
		_wrap_para(para, measure, width, out)
	return out


static func _wrap_para(para: String, measure: Callable, width: float, out: Array[String]) -> void:
	var words := para.split(" ", false)
	# 행두 금칙 글자로 시작하는 어절은 앞 어절에 붙인다(원문에 공백이 있었던 경우: "말했다 …" → 한 덩어리)
	var units: Array[String] = []
	for w in words:
		if units.size() > 0 and NO_START.contains(w[0]):
			units[units.size() - 1] += " " + w
		else:
			units.append(w)
	var line := ""
	for u in units:
		var cand := u if line == "" else line + " " + u
		if float(measure.call(cand)) <= width:
			line = cand
			continue
		if line != "":
			# 행말 금칙: 줄 끝 글자가 여는 괄호면 그 어절을 다음 줄로(어절 단위라 보통 생기지 않지만 '(' 홀로 쓴 경우)
			out.append(line)
			line = ""
		if float(measure.call(u)) <= width:
			line = u
		else:
			line = _hard_break(u, measure, width, out)
	if line != "" or para == "":
		out.append(line)


## 너무 긴 어절: 글자 단위로 자른다. 자른 자리 다음 글자가 행두 금칙이면 한 글자 앞에서 자른다. 마지막 조각을 돌려준다.
static func _hard_break(word: String, measure: Callable, width: float, out: Array[String]) -> String:
	var rest := word
	while float(measure.call(rest)) > width and rest.length() > 1:
		var n := 1
		while n < rest.length() and float(measure.call(rest.substr(0, n + 1))) <= width:
			n += 1
		while n > 1 and n < rest.length() and (NO_START.contains(rest[n]) or NO_END.contains(rest[n - 1])):
			n -= 1
		out.append(rest.substr(0, n))
		rest = rest.substr(n)
	return rest


## 고정폭 측정기(시험·터미널용): 한글·전각 2칸, 나머지 1칸 × cell 픽셀
static func mono(cell: float) -> Callable:
	return func(s: String) -> float:
		var w := 0.0
		for i in s.length():
			var c := s.unicode_at(i)
			w += cell * (2.0 if (c >= 0x1100 and c <= 0x11FF) or (c >= 0x3000 and c <= 0xD7A3) or (c >= 0xFF00 and c <= 0xFFEF) else 1.0)
		return w
