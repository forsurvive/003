## 조건·효과 식 언어 (SD-19 §6.9). 엔진 무관 순수 모듈: 노드를 쓰지 않는다(SD-19 §6.1).
## 조건: `V_ACT >= 2 and AFF_YH >= 50`, `V_REACTOR in [2, 3, 4]`, `not K_CODE`, `has("I-001") or V_DOL == 6`
## 효과: `V_DOL = 3; V_KARMA += 50; aff("BC", 20); quest("MQ-P1", 30)` — 문장은 `;`로 나눈다.
## 같은 문법의 파이썬 검사기가 원고 변환기에 있다(tools/pipeline/story_expr.py). 빌드 때 구문·변수 선언을 검사한다.
## 값은 정수·문자열·참거짓. 참거짓은 정수 0/1과 같게 본다(변수는 정수로 저장).
## 컨텍스트(ctx)는 get_var(name) -> Variant(없으면 null), set_var(name, v) -> bool, call_fn(name, args) -> Variant 를 가진다.
class_name StoryExpr
extends RefCounted

static var _cache := {}

const KEYWORDS := ["and", "or", "not", "in", "true", "false"]


## 문자열 → 토큰 배열 [kind, value]. kind: num, str, id, op, end
static func tokenize(src: String) -> Array:
	var toks: Array = []
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == " " or c == "\t" or c == "\n":
			i += 1
			continue
		if c >= "0" and c <= "9":
			var j := i
			while j < n and src[j] >= "0" and src[j] <= "9":
				j += 1
			toks.append(["num", int(src.substr(i, j - i))])
			i = j
			continue
		if c == "\"":
			var j := i + 1
			while j < n and src[j] != "\"":
				j += 1
			if j >= n:
				return [["err", "닫히지 않은 문자열"]]
			toks.append(["str", src.substr(i + 1, j - i - 1)])
			i = j + 1
			continue
		if _is_id_start(c):
			var j := i
			while j < n and _is_id_char(src[j]):
				j += 1
			var w := src.substr(i, j - i)
			toks.append(["op", w] if w in KEYWORDS else ["id", w])
			i = j
			continue
		var two := src.substr(i, 2)
		if two in ["==", "!=", "<=", ">=", "+=", "-="]:
			toks.append(["op", two])
			i += 2
			continue
		if c in ["<", ">", "=", "+", "-", "*", "/", "(", ")", "[", "]", ",", ";"]:
			toks.append(["op", c])
			i += 1
			continue
		return [["err", "알 수 없는 글자 '%s'" % c]]
	toks.append(["end", ""])
	return toks


static func _is_id_start(c: String) -> bool:
	var u := c.unicode_at(0)
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" or (u >= 0xAC00 and u <= 0xD7A3)


static func _is_id_char(c: String) -> bool:
	return _is_id_start(c) or (c >= "0" and c <= "9")


## 파서: 재귀 하강. 결과 {"ok": bool, "ast": Array, "err": String}
class _P:
	var t: Array
	var i := 0
	var err := ""

	func peek() -> Array:
		return t[i]

	func is_op(v: String) -> bool:
		return t[i][0] == "op" and t[i][1] == v

	func take(v: String) -> bool:
		if is_op(v):
			i += 1
			return true
		return false

	func fail(msg: String) -> Array:
		if err == "":
			err = "%s (토큰 %d)" % [msg, i]
		return []

	func stmts() -> Array:
		var out := ["seq"]
		while true:
			if peek()[0] == "end":
				break
			out.append(stmt())
			if err != "":
				return []
			if not take(";"):
				break
		if peek()[0] != "end":
			return fail("문장 끝에 남은 것이 있다")
		return out

	func stmt() -> Array:
		if peek()[0] == "id" and t[i + 1][0] == "op" and t[i + 1][1] in ["=", "+=", "-="]:
			var name: String = peek()[1]
			var op: String = t[i + 1][1]
			i += 2
			return ["set", name, op, expr()]
		return expr()

	func expr() -> Array:
		var a := and_()
		while take("or"):
			a = ["or", a, and_()]
		return a

	func and_() -> Array:
		var a := not_()
		while take("and"):
			a = ["and", a, not_()]
		return a

	func not_() -> Array:
		if take("not"):
			return ["not", not_()]
		return cmp()

	func cmp() -> Array:
		var a := sum()
		for op in ["==", "!=", "<=", ">=", "<", ">"]:
			if take(op):
				return ["cmp", op, a, sum()]
		if take("in"):
			if not take("["):
				return fail("in 뒤에는 [목록]")
			var items := []
			if not take("]"):
				while true:
					items.append(expr())
					if take("]"):
						break
					if not take(","):
						return fail("목록에 , 또는 ]가 와야 한다")
			return ["in", a, items]
		return a

	func sum() -> Array:
		var a := term()
		while true:
			if take("+"):
				a = ["bin", "+", a, term()]
			elif take("-"):
				a = ["bin", "-", a, term()]
			else:
				break
		return a

	func term() -> Array:
		var a := unary()
		while true:
			if take("*"):
				a = ["bin", "*", a, unary()]
			elif take("/"):
				a = ["bin", "/", a, unary()]
			else:
				break
		return a

	func unary() -> Array:
		if take("-"):
			return ["neg", unary()]
		if take("+"):
			return unary()
		return primary()

	func primary() -> Array:
		var tk := peek()
		if tk[0] == "num":
			i += 1
			return ["lit", tk[1]]
		if tk[0] == "str":
			i += 1
			return ["lit", tk[1]]
		if is_op("true") or is_op("false"):
			i += 1
			return ["lit", 1 if tk[1] == "true" else 0]
		if tk[0] == "id":
			i += 1
			if take("("):
				var args := []
				if not take(")"):
					while true:
						args.append(expr())
						if take(")"):
							break
						if not take(","):
							return fail("인자 목록에 , 또는 )가 와야 한다")
				return ["call", tk[1], args]
			return ["var", tk[1]]
		if take("("):
			var e := expr()
			if not take(")"):
				return fail(")가 와야 한다")
			return e
		return fail("값이 와야 할 자리")


static func parse(src: String) -> Dictionary:
	if _cache.has(src):
		return _cache[src]
	var toks := tokenize(src)
	var res: Dictionary
	if toks.size() > 0 and toks[0][0] == "err":
		res = {"ok": false, "ast": [], "err": toks[0][1]}
	else:
		var p := _P.new()
		p.t = toks
		var ast := p.stmts()
		res = {"ok": p.err == "", "ast": ast, "err": p.err}
	_cache[src] = res
	return res


## 조건식 하나를 참/거짓으로. 빈 문자열은 참. 구문 오류·미선언 변수는 거짓(+오류 기록).
static func test(src: String, ctx: Object) -> bool:
	if src.strip_edges() == "":
		return true
	var p := parse(src)
	if not p["ok"]:
		push_error("조건식 오류: %s — %s" % [src, p["err"]])
		return false
	var v = null
	for s in p["ast"].slice(1):
		v = _eval(s, ctx)
	return _truthy(v)


## 효과 문장들을 실행한다. 반환: 오류 문자열(없으면 "")
static func run(src: String, ctx: Object) -> String:
	if src.strip_edges() == "":
		return ""
	var p := parse(src)
	if not p["ok"]:
		return "효과 구문 오류: %s — %s" % [src, p["err"]]
	var story := ctx is StoryState
	if story:
		ctx.deeds.link_src += 1                                          # 원고 효과의 호감 상승만 연동(SD-06 §3.6 — 진행기 코드는 제 손으로 연동한다, 1-12q)
	for s in p["ast"].slice(1):
		_eval(s, ctx)
	if story:
		ctx.deeds.link_src -= 1
	return ""


static func value(src: String, ctx: Object) -> Variant:
	var p := parse(src)
	if not p["ok"] or p["ast"].size() < 2:
		return null
	return _eval(p["ast"][1], ctx)


static func _truthy(v) -> bool:
	if v == null:
		return false
	if v is String:
		return v != ""
	return int(v) != 0


static func _num(v) -> int:
	if v == null:
		return 0
	if v is String:
		return int(v) if v.is_valid_int() else 0
	return int(v)


static func _eval(a: Array, ctx: Object) -> Variant:
	match a[0]:
		"lit":
			return a[1]
		"var":
			return ctx.get_var(a[1])
		"call":
			var args := []
			for x in a[2]:
				args.append(_eval(x, ctx))
			return ctx.call_fn(a[1], args)
		"not":
			return 0 if _truthy(_eval(a[1], ctx)) else 1
		"and":
			return 1 if _truthy(_eval(a[1], ctx)) and _truthy(_eval(a[2], ctx)) else 0
		"or":
			return 1 if _truthy(_eval(a[1], ctx)) or _truthy(_eval(a[2], ctx)) else 0
		"neg":
			return -_num(_eval(a[1], ctx))
		"bin":
			var l := _num(_eval(a[2], ctx))
			var r := _num(_eval(a[3], ctx))
			match a[1]:
				"+": return l + r
				"-": return l - r
				"*": return l * r
				"/": return 0 if r == 0 else l / r
		"cmp":
			var l = _eval(a[2], ctx)
			var r = _eval(a[3], ctx)
			if l is String or r is String:
				var ls := str(l)
				var rs := str(r)
				match a[1]:
					"==": return 1 if ls == rs else 0
					"!=": return 1 if ls != rs else 0
				return 0
			var li := _num(l)
			var ri := _num(r)
			match a[1]:
				"==": return 1 if li == ri else 0
				"!=": return 1 if li != ri else 0
				"<": return 1 if li < ri else 0
				"<=": return 1 if li <= ri else 0
				">": return 1 if li > ri else 0
				">=": return 1 if li >= ri else 0
		"in":
			var v = _eval(a[1], ctx)
			for x in a[2]:
				var w = _eval(x, ctx)
				if str(v) == str(w):
					return 1
			return 0
		"set":
			var cur = ctx.get_var(a[1])
			var rhs = _eval(a[3], ctx)
			var nv = rhs
			if a[2] == "+=":
				nv = _num(cur) + _num(rhs)
			elif a[2] == "-=":
				nv = _num(cur) - _num(rhs)
			ctx.set_var(a[1], nv)
			return nv
	return null


## 식에 나오는 변수 이름 전부(검사용)
static func names_in(src: String) -> Array:
	var p := parse(src)
	var out := []
	if p["ok"]:
		_collect(p["ast"], out)
	return out


static func _collect(a, out: Array) -> void:
	if not (a is Array) or a.is_empty():
		return
	if a[0] is String:
		if (a[0] == "var" or a[0] == "set") and not (a[1] in out):
			out.append(a[1])
		for x in a.slice(1):
			_collect(x, out)
	else:
		for x in a:
			_collect(x, out)
