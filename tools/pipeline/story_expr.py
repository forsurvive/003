"""조건·효과 식 검사기 — game/core/story/expr.gd 와 같은 문법(파이썬 판). 원고 변환기가 빌드 때 구문·변수·함수를 검사하고,
시험(tests)에서 같은 식을 두 쪽에서 계산해 맞는지도 본다.
문법: stmts := stmt (';' stmt)* · stmt := ID ('='|'+='|'-=') expr | expr
      expr := and ('or' and)* · and := not ('and' not)* · not := 'not' not | cmp
      cmp := sum (('=='|'!='|'<'|'<='|'>'|'>=') sum | 'in' '[' expr,* ']')? · sum := term (('+'|'-') term)* · term := unary (('*'|'/') unary)*
      unary := '-' unary | primary · primary := NUM | "STR" | true | false | ID | ID '(' args ')' | '(' expr ')'"""

KEYWORDS = {"and", "or", "not", "in", "true", "false"}


def _id_start(c):
    return c.isascii() and (c.isalpha() or c == "_") or ("가" <= c <= "힣")


def _id_char(c):
    return _id_start(c) or c.isdigit()


def tokenize(src):
    toks, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c in " \t\n":
            i += 1
        elif c.isdigit():
            j = i
            while j < n and src[j].isdigit():
                j += 1
            toks.append(("num", int(src[i:j])))
            i = j
        elif c == '"':
            j = src.find('"', i + 1)
            if j < 0:
                raise SyntaxError("닫히지 않은 문자열")
            toks.append(("str", src[i + 1:j]))
            i = j + 1
        elif _id_start(c):
            j = i
            while j < n and _id_char(src[j]):
                j += 1
            w = src[i:j]
            toks.append(("op", w) if w in KEYWORDS else ("id", w))
            i = j
        elif src[i:i + 2] in ("==", "!=", "<=", ">=", "+=", "-="):
            toks.append(("op", src[i:i + 2]))
            i += 2
        elif c in "<>=+-*/()[],;":
            toks.append(("op", c))
            i += 1
        else:
            raise SyntaxError(f"알 수 없는 글자 '{c}'")
    toks.append(("end", ""))
    return toks


class _P:
    def __init__(self, toks):
        self.t, self.i = toks, 0

    def peek(self):
        return self.t[self.i]

    def take(self, v):
        if self.t[self.i] == ("op", v):
            self.i += 1
            return True
        return False

    def stmts(self):
        out = ["seq"]
        while self.peek()[0] != "end":
            out.append(self.stmt())
            if not self.take(";"):
                break
        if self.peek()[0] != "end":
            raise SyntaxError(f"문장 끝에 남은 것이 있다 (토큰 {self.i})")
        return out

    def stmt(self):
        if self.peek()[0] == "id" and self.t[self.i + 1][0] == "op" and self.t[self.i + 1][1] in ("=", "+=", "-="):
            name, op = self.peek()[1], self.t[self.i + 1][1]
            self.i += 2
            return ["set", name, op, self.expr()]
        return self.expr()

    def expr(self):
        a = self.and_()
        while self.take("or"):
            a = ["or", a, self.and_()]
        return a

    def and_(self):
        a = self.not_()
        while self.take("and"):
            a = ["and", a, self.not_()]
        return a

    def not_(self):
        if self.take("not"):
            return ["not", self.not_()]
        return self.cmp()

    def cmp(self):
        a = self.sum()
        for op in ("==", "!=", "<=", ">=", "<", ">"):
            if self.take(op):
                return ["cmp", op, a, self.sum()]
        if self.take("in"):
            if not self.take("["):
                raise SyntaxError("in 뒤에는 [목록]")
            items = []
            if not self.take("]"):
                while True:
                    items.append(self.expr())
                    if self.take("]"):
                        break
                    if not self.take(","):
                        raise SyntaxError("목록에 , 또는 ]가 와야 한다")
            return ["in", a, items]
        return a

    def sum(self):
        a = self.term()
        while True:
            if self.take("+"):
                a = ["bin", "+", a, self.term()]
            elif self.take("-"):
                a = ["bin", "-", a, self.term()]
            else:
                return a

    def term(self):
        a = self.unary()
        while True:
            if self.take("*"):
                a = ["bin", "*", a, self.unary()]
            elif self.take("/"):
                a = ["bin", "/", a, self.unary()]
            else:
                return a

    def unary(self):
        if self.take("-"):
            return ["neg", self.unary()]
        if self.take("+"):
            return self.unary()
        return self.primary()

    def primary(self):
        k, v = self.peek()
        if k in ("num", "str"):
            self.i += 1
            return ["lit", v]
        if self.peek() in (("op", "true"), ("op", "false")):
            self.i += 1
            return ["lit", 1 if v == "true" else 0]
        if k == "id":
            self.i += 1
            if self.take("("):
                args = []
                if not self.take(")"):
                    while True:
                        args.append(self.expr())
                        if self.take(")"):
                            break
                        if not self.take(","):
                            raise SyntaxError("인자 목록에 , 또는 )가 와야 한다")
                return ["call", v, args]
            return ["var", v]
        if self.take("("):
            e = self.expr()
            if not self.take(")"):
                raise SyntaxError(")가 와야 한다")
            return e
        raise SyntaxError(f"값이 와야 할 자리 (토큰 {self.i})")


def parse(src):
    return _P(tokenize(src)).stmts()


def names(ast, out=None, calls=None):
    """식에 나오는 변수 이름과 함수 이름."""
    out = set() if out is None else out
    calls = set() if calls is None else calls
    if isinstance(ast, list) and ast:
        if isinstance(ast[0], str):
            if ast[0] in ("var", "set"):
                out.add(ast[1])
            if ast[0] == "call":
                calls.add(ast[1])
            for x in ast[1:]:
                names(x, out, calls)
        else:
            for x in ast:
                names(x, out, calls)
    return out, calls


def _truthy(v):
    if v is None:
        return False
    if isinstance(v, str):
        return v != ""
    return int(v) != 0


def _num(v):
    if v is None:
        return 0
    if isinstance(v, str):
        try:
            return int(v)
        except ValueError:
            return 0
    return int(v)


def evaluate(ast, env, fns=None):
    """시험용 계산기(expr.gd와 같은 규칙). env: 변수 사전(값을 바꾼다), fns: 이름 -> 함수."""
    fns = fns or {}
    k = ast[0]
    if k == "seq":
        v = None
        for s in ast[1:]:
            v = evaluate(s, env, fns)
        return v
    if k == "lit":
        return ast[1]
    if k == "var":
        return env.get(ast[1])
    if k == "call":
        return fns[ast[1]](*[evaluate(a, env, fns) for a in ast[2]])
    if k == "not":
        return 0 if _truthy(evaluate(ast[1], env, fns)) else 1
    if k == "and":
        return 1 if _truthy(evaluate(ast[1], env, fns)) and _truthy(evaluate(ast[2], env, fns)) else 0
    if k == "or":
        return 1 if _truthy(evaluate(ast[1], env, fns)) or _truthy(evaluate(ast[2], env, fns)) else 0
    if k == "neg":
        return -_num(evaluate(ast[1], env, fns))
    if k == "bin":
        l, r = _num(evaluate(ast[2], env, fns)), _num(evaluate(ast[3], env, fns))
        return {"+": l + r, "-": l - r, "*": l * r, "/": (0 if r == 0 else int(l / r))}[ast[1]]
    if k == "cmp":
        l, r = evaluate(ast[2], env, fns), evaluate(ast[3], env, fns)
        if isinstance(l, str) or isinstance(r, str):
            return {"==": int(str(l) == str(r)), "!=": int(str(l) != str(r))}.get(ast[1], 0)
        l, r = _num(l), _num(r)
        return int({"==": l == r, "!=": l != r, "<": l < r, "<=": l <= r, ">": l > r, ">=": l >= r}[ast[1]])
    if k == "in":
        v = evaluate(ast[1], env, fns)
        return int(any(str(v) == str(evaluate(x, env, fns)) for x in ast[2]))
    if k == "set":
        cur, rhs = env.get(ast[1]), evaluate(ast[3], env, fns)
        nv = rhs if ast[2] == "=" else (_num(cur) + _num(rhs) if ast[2] == "+=" else _num(cur) - _num(rhs))
        env[ast[1]] = nv
        return nv
    raise ValueError(k)
