## 텍스트 제어 코드 (SD-12 §14.1). 대사·알림 문자열의 코드를 풀어 화면 문자열로 만든다. 엔진 무관 순수 모듈.
##   \P 주인공 이름(P_GIVEN)   \V[변수] 변수 값(숫자는 천 단위 쉼표, 문자열은 그대로)   \N[id] 인물 이름   \I[id] 아이템 이름
##   \L[id] 장소 이름   \K 카르마 칭호   \J[조사] 바로 앞 글자 받침으로 짝 고르기   \T[스킬:난이도] 판정 태그([화술 45%])
##   \C[n] 글자 색(n 0 = 기본)   \W[n] n/10초 쉬기   \. 줄바꿈 금지 공백   \\ 역슬래시
## 결과: {"text": 화면 문자열, "pauses": [[글자 위치, 초]], "colors": [[시작, 끝, n]]}
class_name TextFmt
extends RefCounted

const NBSP := "\u00a0"                ## 줄바꿈 금지 공백(원고 \.)


static func format(src: String, st: Object = null) -> Dictionary:
	var out := ""
	var pauses := []
	var colors := []
	var color_start := -1
	var color_n := 0
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		if c != "\\" or i + 1 >= n:
			out += c
			i += 1
			continue
		var code := src[i + 1]
		var arg := ""
		var j := i + 2
		if j < n and src[j] == "[":
			var k := src.find("]", j)
			if k < 0:
				out += src.substr(i)
				break
			arg = src.substr(j + 1, k - j - 1)
			j = k + 1
		match code:
			"P":
				out += _var_str(st, "P_GIVEN")
			"V":
				out += _var_str(st, arg)
			"N":
				out += st.npc_name(arg) if st != null else arg
			"I", "L":
				out += str(st.names.get(arg, arg)) if st != null else arg
			"K":
				out += str(st.call_fn("karma_title", [])) if st != null and st.fns.has("karma_title") else ""
			"J":
				out += Josa.pick(arg, out)
			"T":
				out += tag_text(arg, st)
			"C":
				if color_start >= 0 and color_n != 0:
					colors.append([color_start, out.length(), color_n])
				color_n = int(arg)
				color_start = out.length()
			"W":
				pauses.append([out.length(), int(arg) / 10.0])
			".":
				out += NBSP
			"\\":
				out += "\\"
			_:
				out += "\\" + code + ("[" + arg + "]" if arg != "" else "")
		i = j
	if color_start >= 0 and color_n != 0:
		colors.append([color_start, out.length(), color_n])
	return {"text": out, "pauses": pauses, "colors": colors}


static func plain(src: String, st: Object = null) -> String:
	return format(src, st)["text"]


static func _var_str(st: Object, name: String) -> String:
	if st == null:
		return name
	var v = st.get_var(name)
	if v == null:
		return "?"
	if v is int:
		return group(v)
	return str(v)


## 천 단위 쉼표(SD-12 §14.3)
static func group(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


## 판정 태그 글자(SD-12 §6.3): "화술:쉬움" → "[화술 45%]" (확률은 대상 인물 기준, st.speech_target),
## "과학:25" → "[과학 25]", "지능:7" → "[지능 7]", "카르마" → "[카르마]"
static func tag_text(arg: String, st: Object) -> String:
	var parts := arg.split(":")
	if parts.size() == 2 and parts[0] == "화술" and st != null:
		var target: String = st.get_meta("speech_target") if st.has_meta("speech_target") else ""
		return "[화술 %d%%]" % Speech.percent(st.speech_chance(target, parts[1]))
	if parts.size() == 2:
		return "[%s %s]" % [parts[0], parts[1]]
	return "[%s]" % arg
