"""간판 대 글자 세트 (SD-16 §11.2): 16×16 칸, 15×15 자면 + 오른쪽·아래 1px 자간.
진짜 한글만 쓴다(§11.1-4). 자모를 직접 그려 조합한다: 초성 19 × 중성 21 × 종성 27을 꼴(세로 모음 / 가로 모음 /
겹모음) × 받침 유무로 나눈 자리 상자에 그린다. 세로획은 2px, 가로획은 상자 높이가 되면 2px, 빽빽하면 1px
(굵은 고딕을 16px에 담는 규칙). 조합 결과가 어색한 글자는 OVERRIDE 격자로 손으로 고친다.
mask 는 (x, y) 집합이다. 색·외곽·광택은 간판 쪽(signs.py)이 입힌다."""
import os

CHO = "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"
JUNG = "ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ"
JONG = ["", "ㄱ", "ㄲ", "ㄱㅅ", "ㄴ", "ㄴㅈ", "ㄴㅎ", "ㄷ", "ㄹ", "ㄹㄱ", "ㄹㅁ", "ㄹㅂ", "ㄹㅅ", "ㄹㅌ", "ㄹㅍ", "ㄹㅎ",
        "ㅁ", "ㅂ", "ㅂㅅ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
DOUBLE = {"ㄲ": "ㄱ", "ㄸ": "ㄷ", "ㅃ": "ㅂ", "ㅆ": "ㅅ", "ㅉ": "ㅈ"}
VERT = set("ㅏㅐㅑㅒㅓㅔㅕㅖㅣ")
HORI = set("ㅗㅛㅜㅠㅡ")
CELL, EM = 16, 15


def decompose(ch):
    o = ord(ch) - 0xAC00
    if not 0 <= o < 11172:
        raise ValueError(ch)
    return CHO[o // 588], JUNG[(o % 588) // 28], JONG[o % 28]


def _rect(S, x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            S.add((x, y))


def _hw(h, bars):
    """horizontal stroke weight: 2px when the counters stay >= 2px, else 1px."""
    return 2 if h >= bars * 2 + (bars - 1) * 2 else 1


def _vw(w, stems=2):
    return 2 if w >= stems * 2 + 2 else 1


def _ring(w, h):
    """ㅇ as an octagonal ring (pixel fonts read an octagon as a circle at this size)."""
    S = set()
    vw = 2 if w >= 7 else 1
    hw = 2 if h >= 9 else 1
    c = 2 if min(w, h) >= 8 else 1
    def inside(x, y, x0, y0, x1, y1, cut):
        if not (x0 <= x <= x1 and y0 <= y <= y1):
            return False
        dx = min(x - x0, x1 - x)
        dy = min(y - y0, y1 - y)
        return dx + dy >= cut
    for y in range(h):
        for x in range(w):
            if inside(x, y, 0, 0, w - 1, h - 1, c) and not inside(x, y, vw, hw, w - 1 - vw, h - 1 - hw, max(c - 1, 0)):
                S.add((x, y))
    return S


def _legs(w, h, y0=0, split=False):
    """ㅅ body: two 2px legs from an apex at the top centre to the bottom corners. Each row's run joins the run
    above it so a flat leg stays a solid stroke (no dotted diagonals). The spread is capped at ~3px per row
    so a short, wide 받침 ㅅ does not turn into two flat dashes. split=True starts the right leg a third of the way
    down the left one (gothic ㅅ)."""
    S = set()
    hh = h - y0
    we = min(w, 2 + 2 * 3 * max(hh - 1, 1) // 2 * 2)
    ox = (w - we) // 2
    ax = (we - 2) / 2
    t0 = 0.34 if split else 0.0
    prev_l = prev_r = None
    for i in range(hh):
        t = i / max(hh - 1, 1)
        xl = round(ax * (1 - t))
        lo, hi = (xl, xl + 1) if prev_l is None else (min(xl, prev_l + 1), max(xl + 1, prev_l))
        S.update((x + ox, y0 + i) for x in range(lo, hi + 1))
        prev_l = xl
        if t >= t0:
            tr = (t - t0) / (1 - t0) if t0 else t
            start = ax * (1 - t0) + (1 if split else 0)
            xr = round(start + (we - 2 - start) * tr)
            lo, hi = (xr, xr + 1) if prev_r is None else (min(xr, prev_r + 1), max(xr + 1, prev_r))
            S.update((x + ox, y0 + i) for x in range(lo, hi + 1))
            prev_r = xr
    return {(x, y) for x, y in S if 0 <= x < w}


def cons(c, w, h, role="cho"):
    """one consonant in a w×h box. role: cho_v (left of a vertical vowel), cho_h (above a horizontal vowel), jong."""
    if c in DOUBLE:
        base = DOUBLE[c]
        w1 = (w - 1) // 2
        w2 = w - 1 - w1
        a = cons(base, w1, h, role)
        b = cons(base, w2, h, role)
        return a | {(x + w1 + 1, y) for x, y in b}
    S = set()
    if c == "ㅇ":
        return _ring(w, h)
    vw = (2 if w >= 4 else 1) if c in "ㄱㄴㅅㅈㅊㅋ" else _vw(w)
    if c == "ㄱ":
        hw = _hw(h, 1)
        _rect(S, 0, 0, w - 1, hw - 1)
        sweep = role == "cho_v" and h >= 9 and w >= 6
        knee = h - h // 3 if sweep else h
        _rect(S, w - vw, 0, w - 1, knee - 1)
        if sweep:                                       # gothic ㄱ beside ㅏ: the tail leans left
            _rect(S, w - vw - 1, knee, w - 2, h - 1)
    elif c == "ㄴ":
        hw = _hw(h, 1)
        _rect(S, 0, 0, vw - 1, h - 1)
        _rect(S, 0, h - hw, w - 1, h - 1)
    elif c == "ㄷ":
        hw = _hw(h, 2)
        _rect(S, 0, 0, w - 1, hw - 1)
        _rect(S, 0, 0, vw - 1, h - 1)
        _rect(S, 0, h - hw, w - 1, h - 1)
    elif c == "ㄹ":
        hw = _hw(h, 3)
        m = (h - hw) // 2
        _rect(S, 0, 0, w - 1, hw - 1)
        _rect(S, w - vw, 0, w - 1, m + hw - 1)
        _rect(S, 0, m, w - 1, m + hw - 1)
        _rect(S, 0, m, vw - 1, h - 1)
        _rect(S, 0, h - hw, w - 1, h - 1)
    elif c == "ㅁ":
        hw = _hw(h, 2)
        _rect(S, 0, 0, w - 1, hw - 1)
        _rect(S, 0, h - hw, w - 1, h - 1)
        _rect(S, 0, 0, vw - 1, h - 1)
        _rect(S, w - vw, 0, w - 1, h - 1)
    elif c == "ㅂ":
        hw = _hw(h, 2)
        m = (h - hw) * 9 // 20
        if h - hw - (m + hw) < 1:
            m = h - 2 * hw - 1
        _rect(S, 0, 0, vw - 1, h - 1)
        _rect(S, w - vw, 0, w - 1, h - 1)
        _rect(S, 0, m, w - 1, m + hw - 1)
        _rect(S, 0, h - hw, w - 1, h - 1)
    elif c == "ㅅ":
        S = _legs(w, h, 0, split=(role != "jong" and h >= 7))
    elif c == "ㅈ":
        hw = _hw(h, 2)
        _rect(S, 0, 0, w - 1, hw - 1)
        S |= _legs(w, h, hw, split=(role != "jong" and h >= 8))
    elif c == "ㅊ":
        hw = 1 if h < 9 else 2
        cx = (w - 2) // 2
        _rect(S, cx, 0, cx + 1, 0)
        _rect(S, 0, 1, w - 1, hw)
        S |= _legs(w, h, hw + 1, split=(role != "jong" and h >= 9))
    elif c == "ㅋ":
        hw = _hw(h, 2)
        _rect(S, 0, 0, w - 1, hw - 1)
        _rect(S, w - vw, 0, w - 1, h - 1)
        m = hw + max(1, (h - 2 * hw) // 2)
        _rect(S, 0, m, w - 1, m + hw - 1)
    elif c == "ㅌ":
        hw = _hw(h, 3)
        m = (h - hw) // 2
        _rect(S, 0, 0, w - 1, hw - 1)
        _rect(S, 0, m, w - 1, m + hw - 1)
        _rect(S, 0, h - hw, w - 1, h - 1)
        _rect(S, 0, 0, vw - 1, h - 1)
    elif c == "ㅍ":
        hw = _hw(h, 2)
        _rect(S, 0, 0, w - 1, hw - 1)
        _rect(S, 0, h - hw, w - 1, h - 1)
        sv = 2 if w >= 9 else 1
        a = w // 4 if w >= 8 else 1
        b = w - 1 - a - (sv - 1)
        _rect(S, a, 0, a + sv - 1, h - 1)
        _rect(S, b, 0, b + sv - 1, h - 1)
    elif c == "ㅎ":
        hw = 2 if h >= 12 else 1
        cx = (w - 2) // 2
        tick = 2 if h >= 12 else 1
        _rect(S, cx, 0, cx + 1, tick - 1)
        _rect(S, 0, tick, w - 1, tick + hw - 1)
        top = tick + hw + (1 if h >= 9 else 0)
        rw = w - 2 if w >= 9 else w
        ox = (w - rw) // 2
        S |= {(x + ox, y + top) for x, y in _ring(rw, h - top)}
    else:
        raise ValueError(c)
    return S


def _place(S, part, x0, y0):
    S.update((x + x0, y + y0) for x, y in part)


# ---- vowels -------------------------------------------------------------------------------------------------
# Right edge of the em is x=14. Vertical vowels: (stems x0 list, bars (x0, x1, side-y list), cho box width)
VSPEC = {
    "ㅏ": dict(stems=[10], bars=[(12, 14, [0])], cw=9),
    "ㅑ": dict(stems=[10], bars=[(12, 14, [-1, 1])], cw=9),
    "ㅓ": dict(stems=[12], bars=[(9, 11, [0])], cw=8),
    "ㅕ": dict(stems=[12], bars=[(9, 11, [-1, 1])], cw=8),
    "ㅣ": dict(stems=[12], bars=[], cw=10),
    "ㅐ": dict(stems=[8, 12], bars=[(10, 11, [0])], cw=7),
    "ㅒ": dict(stems=[8, 12], bars=[(10, 11, [-1, 1])], cw=7),
    "ㅔ": dict(stems=[10, 13], bars=[(8, 9, [0])], cw=7),
    "ㅖ": dict(stems=[10, 13], bars=[(8, 9, [-1, 1])], cw=7),
}


def _vert_vowel(S, v, y0, y1, mid):
    sp = VSPEC[v]
    for sx in sp["stems"]:
        _rect(S, sx, y0, sx + 1, y1)
    gap = 2 if y1 - y0 >= 12 else 1
    for bx0, bx1, sides in sp["bars"]:
        for s in sides:
            if s == 0:
                yy = mid
            else:
                yy = mid + s * (gap + 1)
            hw = 2 if len(sides) == 1 and y1 - y0 >= 8 else 1
            _rect(S, bx0, yy, bx1, yy + hw - 1)


def _hori_vowel(S, v, x0, x1, y_bar, y_lo, y_hi, hw=2):
    """ㅗㅛㅜㅠㅡ: bar on rows y_bar..y_bar+hw-1, stubs reach y_lo (ㅗㅛ above) or y_hi (ㅜㅠ below)."""
    _rect(S, x0, y_bar, x1, y_bar + hw - 1)
    w = x1 - x0 + 1
    if v in "ㅗㅜ":
        cx = x0 + (w - 2) // 2 + (1 if v == "ㅜ" and w >= 12 else 0)
        xs = [cx]
    elif v in "ㅛㅠ":
        q = max(2, w // 4)
        xs = [x0 + q, x1 - q - 1]
    else:
        xs = []
    for sx in xs:
        if v in "ㅗㅛ":
            _rect(S, sx, y_lo, sx + 1, y_bar - 1)
        else:
            _rect(S, sx, y_bar + hw, sx + 1, y_hi)


COMPOUND = {"ㅘ": ("ㅗ", "ㅏ"), "ㅙ": ("ㅗ", "ㅐ"), "ㅚ": ("ㅗ", "ㅣ"), "ㅝ": ("ㅜ", "ㅓ"), "ㅞ": ("ㅜ", "ㅔ"),
            "ㅟ": ("ㅜ", "ㅣ"), "ㅢ": ("ㅡ", "ㅣ")}


def _jong(S, j, top, x0=1, x1=13):
    h = EM - top
    w = x1 - x0 + 1
    if len(j) == 2:                                     # 겹받침: two halves
        w1 = (w - 1) // 2
        _place(S, cons(j[0], w1, h, "jong"), x0, top)
        _place(S, cons(j[1], w - 1 - w1, h, "jong"), x0 + w1 + 1, top)
    else:
        _place(S, cons(j, w, h, "jong"), x0, top)


def compose(ch):
    if ch in OVERRIDE:
        return set(OVERRIDE[ch])
    c, v, j = decompose(ch)
    S = set()
    if v in VERT:
        sp = VSPEC[v]
        cw = sp["cw"]
        if not j:
            _vert_vowel(S, v, 0, 14, 6)
            ch_h = 12 if c not in "ㄱ" else 13
            _place(S, cons(c, cw, ch_h, "cho_v"), 0, 1)
        else:
            _vert_vowel(S, v, 0, 8, 3)
            _place(S, cons(c, cw, 8, "cho_v"), 0, 0)
            _jong(S, j, 10)
    elif v in HORI:
        if not j:
            if v in "ㅗㅛ":
                _place(S, cons(c, 11, 8, "cho_h"), 2, 1)
                _hori_vowel(S, v, 0, 14, 12, 10, 0)
            elif v in "ㅜㅠ":
                _place(S, cons(c, 11, 7, "cho_h"), 2, 1)
                _hori_vowel(S, v, 0, 14, 9, 0, 14)
            else:
                _place(S, cons(c, 11, 9, "cho_h"), 2, 1)
                _hori_vowel(S, v, 0, 14, 12, 0, 0)
        else:
            if v in "ㅗㅛ":
                _place(S, cons(c, 11, 5, "cho_h"), 2, 0)
                _hori_vowel(S, v, 0, 14, 7, 6, 0)
            elif v in "ㅜㅠ":
                _place(S, cons(c, 11, 5, "cho_h"), 2, 0)
                _hori_vowel(S, v, 0, 14, 6, 0, 8, hw=1)
            else:
                _place(S, cons(c, 11, 6, "cho_h"), 2, 0)
                _hori_vowel(S, v, 0, 14, 7, 0, 0, hw=2)
            _jong(S, j, 10)
    else:
        hv, vv = COMPOUND[v]
        sp = VSPEC[vv]
        bar_x1 = min(sp["stems"]) - 2 if vv != "ㅏ" else sp["stems"][0] - 2
        if vv in ("ㅓ", "ㅔ"):
            bar_x1 = 8
        if not j:
            _vert_vowel(S, vv, 0, 14, 6)
            if hv == "ㅗ":
                _place(S, cons(c, 8, 7, "cho_h"), 0, 0)
                _hori_vowel(S, hv, 0, bar_x1, 10, 8, 0)
            elif hv == "ㅜ":
                _place(S, cons(c, 8, 6, "cho_h"), 0, 0)
                _hori_vowel(S, hv, 0, bar_x1, 7, 0, 13)
            else:
                _place(S, cons(c, 8, 8, "cho_h"), 0, 0)
                _hori_vowel(S, hv, 0, bar_x1, 10, 0, 0)
        else:
            _vert_vowel(S, vv, 0, 8, 3)
            if hv == "ㅗ":
                _place(S, cons(c, 8, 4, "cho_h"), 0, 0)
                _hori_vowel(S, hv, 0, bar_x1, 6, 5, 0, hw=2)
            elif hv == "ㅜ":
                _place(S, cons(c, 8, 4, "cho_h"), 0, 0)
                _hori_vowel(S, hv, 0, bar_x1, 5, 0, 8, hw=1)
            else:
                _place(S, cons(c, 8, 5, "cho_h"), 0, 0)
                _hori_vowel(S, hv, 0, bar_x1, 6, 0, 0, hw=2)
            _jong(S, j, 10)
    return {(x, y) for x, y in S if 0 <= x < EM and 0 <= y < EM}


# ---- digits and a few marks (8 wide, same 15px height) -------------------------------------------------------
DIGITS = {
    "0": ["..####..", ".######.", "##....##", "##...###", "##..####", "##.##.##", "####..##", "###...##", "##....##",
          "##....##", "##....##", "##....##", ".######.", "..####..", "........"],
    "1": ["...##...", "..###...", ".####...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...",
          "...##...", "...##...", "...##...", ".######.", ".######.", "........"],
    "2": ["..####..", ".######.", "##....##", "......##", "......##", ".....##.", "....##..", "...##...", "..##....",
          ".##.....", "##......", "##......", "########", "########", "........"],
    "3": ["..####..", ".######.", "##....##", "......##", "......##", "...####.", "...####.", "......##", "......##",
          "......##", "......##", "##....##", ".######.", "..####..", "........"],
    "4": [".....##.", "....###.", "...####.", "..##.##.", ".##..##.", "##...##.", "##...##.", "########", "########",
          ".....##.", ".....##.", ".....##.", ".....##.", ".....##.", "........"],
    "5": ["########", "########", "##......", "##......", "######..", "#######.", "......##", "......##", "......##",
          "......##", "......##", "##....##", ".######.", "..####..", "........"],
    "6": ["..####..", ".######.", "##....##", "##......", "##......", "######..", "#######.", "##....##", "##....##",
          "##....##", "##....##", "##....##", ".######.", "..####..", "........"],
    "7": ["########", "########", "......##", "......##", ".....##.", ".....##.", "....##..", "....##..", "...##...",
          "...##...", "...##...", "...##...", "...##...", "...##...", "........"],
    "8": ["..####..", ".######.", "##....##", "##....##", "##....##", ".######.", ".######.", "##....##", "##....##",
          "##....##", "##....##", "##....##", ".######.", "..####..", "........"],
    "9": ["..####..", ".######.", "##....##", "##....##", "##....##", "##....##", ".#######", "..######", "......##",
          "......##", "......##", "##....##", ".######.", "..####..", "........"],
    "-": ["", "", "", "", "", "", "######", "######", "", "", "", "", "", "", ""],
    "%": [".##....#", "#..#..##", "#..#.##.", ".##..##.", "....##..", "...##...", "..##....", ".##.....",
          ".##..##.", "##..#..#", "#...#..#", ".....##.", "", "", ""],
    "?": [".####...", "######..", "##..##..", "....##..", "...##...", "..##....", "..##....", "..##....", "........",
          "..##....", "..##....", "", "", "", ""],
    "·": ["", "", "", "", "", "", ".##", ".##", "", "", "", "", "", "", ""],
    ",": ["", "", "", "", "", "", "", "", "", "", "", ".##", ".##", "##.", ""],
    ".": ["", "", "", "", "", "", "", "", "", "", "", "##", "##", "", ""],
    "D": ["######..", "#######.", "##...###", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##",
          "##....##", "##....##", "##...###", "#######.", "######..", "........"],
    "S": ["..####..", ".######.", "##....##", "##......", "##......", ".####...", "..####..", "....###.", ".....##.",
          "......##", "......##", "##....##", ".######.", "..####..", "........"],
    "!": ["##", "##", "##", "##", "##", "##", "##", "##", "", "##", "##", "", "", "", ""],
}
NARROW_W = {k: max((len(r.rstrip(".")) for r in v), default=0) for k, v in DIGITS.items()}


def mark(ch):
    rows = DIGITS[ch]
    return {(x, y) for y, r in enumerate(rows) for x, p in enumerate(r) if p == "#"}


def advance(ch):
    """pen advance in px, before tracking."""
    if ch == " ":
        return 6
    if ch in DIGITS:
        return NARROW_W[ch] + 1
    return CELL


def glyph(ch):
    return mark(ch) if ch in DIGITS else compose(ch)


# ---- hand fixes ---------------------------------------------------------------------------------------------
OVERRIDE = {}
_OV_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "src/sprites/sign16_override.txt")


def _load_override():
    if not os.path.exists(_OV_PATH):
        return
    cur, rows = None, []
    for line in open(_OV_PATH, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line.strip() or (line.startswith("#") and (cur is None or len(rows) >= EM)):
            continue                                    # '#' starts a comment only outside a 15-row glyph block
        if line.startswith("@"):
            if cur:
                OVERRIDE[cur] = {(x, y) for y, r in enumerate(rows) for x, p in enumerate(r) if p == "#"}
            cur, rows = line[1:].strip(), []
        else:
            rows.append(line)
    if cur:
        OVERRIDE[cur] = {(x, y) for y, r in enumerate(rows) for x, p in enumerate(r) if p == "#"}


_load_override()


# 초판 150자 (§12.3 #14): 봉천 상가 간판 5 + S-07 표어 화면 4에 쓰는 글자를 먼저, 그다음 업종·시설·브랜드 음절
SET150 = ("번개봉천점언제나켜져있는이웃약국조상담원자학적성평가대비반합격률아토믹빨래방시코인세탁단말기실곧미다"
          "오버어님께감사니누구의연수생은교무과로주민센터피소위볼트프빌한결건설청솔식품태진든보력관망배급등록충층입출"
          "지하동호용당분슈퍼마철물전리병치안경부산행정육떡집꽃서문빵우체찰도업발공장차역선노화영일늘열휴")
assert len(SET150) == len(set(SET150)) == 150
