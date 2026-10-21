"""여의도 대학병원 2층 안과 외래 · 수술실 소품(단계 1-12h h2 — UQ-08 철사의 돋보기, SD-05 §3.4 · SD-16 아이작풍).
  op_table     안과 수술대(2×1) — 크롬 기둥 · 민트 패드 · 머리 받침 고리 · 찢어진 시트
  op_scope     안과 수술 현미경(1×1, 키 큼) — 바퀴 받침 · 기둥 · 팔 · 쌍안 머리 · 맨 아래 대물렌즈(정밀 렌즈 — M-432)
               상태 taken(대물렌즈 고리가 비었다 — 렌즈를 빼 갔다)
  slit_lamp    세극등 현미경 진료대(2×1) — 턱받침 틀 · 쌍안 몸통 · 세극 조명 탑
  w_eye_chart  벽 시력표(1×0) — 한글 · 숫자 줄이 아래로 작아진다 · 맨 아래 빨강 / 초록 띠
  lens_case    렌즈 보관장(1×1) — 유리문 안 렌즈 쟁반 셋. 상태 taken(가운데 쟁반이 빔)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
CHROME = ("P12", "P13", "P14", "P15")
MINT = ("P34", "P35", "P36", "P37")
STEEL = ("P04", "P05", "P06", "P07")
CREAM = ("P07", "P08", "P09")


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _box(d, x0, y0, x1, y1, ramp, top=True):
    d.rectangle([x0, y0, x1, y1], fill=C(INK))
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=C(ramp[1]))
    if top:
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=C(ramp[-1]))
    d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=C(ramp[0]))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def op_table():
    """안과 수술대(64×36): 가운데 크롬 기둥 받침 · 민트 패드 상판 · 왼쪽 끝 머리 받침 고리(눈 수술은 머리를 고정한다) · 오른쪽으로 흘러내린 찢어진 시트."""
    im = img(64, 36)
    d = ImageDraw.Draw(im)
    _shadow(d, 6, 60, 33)
    _box(d, 26, 20, 38, 31, CHROME)                                     # 기둥
    d.rectangle([20, 30, 44, 33], fill=C(INK)); d.line([21, 31, 43, 31], fill=C(CHROME[2]))   # 받침
    d.rounded_rectangle([4, 11, 60, 21], 3, fill=C(INK))               # 상판
    d.rounded_rectangle([5, 12, 59, 20], 3, fill=C(MINT[1]))
    d.line([7, 13, 57, 13], fill=C(MINT[3]))
    for x in (18, 32, 46):                                               # 패드 이음
        d.line([x, 13, x, 19], fill=C(MINT[0]))
    d.ellipse([0, 8, 10, 18], fill=C(INK)); d.ellipse([2, 10, 8, 16], fill=C(CHROME[1]))   # 머리 받침 고리
    d.ellipse([4, 12, 6, 14], fill=C(INK))
    d.polygon([(40, 11), (62, 12), (63, 26), (55, 24), (50, 28), (44, 20)], fill=C(INK))   # 찢어진 시트
    d.polygon([(41, 12), (61, 13), (62, 24), (55, 22), (50, 26), (45, 19)], fill=C(CREAM[1]))
    d.line([46, 14, 60, 15], fill=C(CREAM[2]))
    d.point((53, 18), fill=C("P26")); d.point((57, 20), fill=C("P26"))     # 녹물 얼룩
    return im


def op_scope(state=""):
    """안과 수술 현미경(40×64): 바퀴 넷 받침 · 기둥 · 앞으로 뻗은 팔 · 쌍안 머리 · 맨 아래 대물렌즈.
    기본 = 대물렌즈가 먼지 아래 푸르게 반짝 · taken = 렌즈 고리가 비고 나사 셋이 풀려 있다."""
    im = img(40, 64)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 30, 61)
    d.polygon([(2, 58), (28, 58), (24, 54), (6, 54)], fill=C(INK))        # 받침
    d.polygon([(4, 57), (26, 57), (23, 55), (7, 55)], fill=C(STEEL[2]))
    for x in (3, 27):
        d.ellipse([x - 2, 57, x + 2, 61], fill=C(INK))
    _box(d, 12, 14, 17, 55, CHROME)                                      # 기둥
    d.rectangle([12, 10, 36, 15], fill=C(INK)); d.line([13, 11, 35, 11], fill=C(CHROME[3]))   # 팔
    d.rectangle([13, 12, 35, 14], fill=C(CHROME[1]))
    _box(d, 26, 14, 37, 30, STEEL)                                       # 쌍안 머리
    d.rectangle([24, 16, 27, 19], fill=C(INK)); d.rectangle([24, 22, 27, 25], fill=C(INK))   # 접안경 둘(왼쪽으로)
    d.point((25, 17), fill=C("P07")); d.point((25, 23), fill=C("P07"))
    d.rectangle([29, 30, 34, 35], fill=C(INK))                           # 대물 경통
    d.rectangle([30, 31, 33, 34], fill=C(STEEL[1]))
    d.ellipse([27, 34, 36, 40], fill=C(INK))                             # 대물렌즈 고리
    if state == "taken":
        d.ellipse([29, 35, 34, 39], fill=C("P02"))                       # 빈 고리
        for (x, y) in ((22, 52), (25, 53), (19, 53)):                    # 풀린 나사
            d.point((x, y), fill=C("P07"))
    else:
        d.ellipse([29, 35, 34, 39], fill=C("P46"))                       # 렌즈(푸른 반사)
        d.point((30, 36), fill=C("P09")); d.point((31, 36), fill=C("P09"))
    d.line([18, 40, 26, 40], fill=C(INK))                                # 발 조작 줄
    return im


def slit_lamp():
    """세극등 현미경 진료대(60×44): 크림 진료 책상 위 — 왼쪽 턱받침 틀(세로대 둘 · 턱 컵 · 이마 띠) · 가운데 쌍안 몸통 · 오른쪽 세극 조명 탑."""
    im = img(60, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 58, 41)
    _box(d, 2, 26, 57, 40, CREAM)                                        # 책상
    d.line([4, 33, 55, 33], fill=C(CREAM[0]))
    for x in (8, 20):                                                    # 턱받침 틀
        d.rectangle([x, 4, x + 1, 27], fill=C(INK))
    d.line([8, 6, 21, 6], fill=C(INK)); d.line([9, 7, 20, 7], fill=C("P26"))   # 이마 띠
    d.rectangle([11, 19, 18, 22], fill=C(INK)); d.rectangle([12, 20, 17, 21], fill=C(CREAM[2]))   # 턱 컵
    _box(d, 26, 12, 38, 26, STEEL)                                       # 쌍안 몸통
    d.rectangle([28, 8, 30, 12], fill=C(INK)); d.rectangle([34, 8, 36, 12], fill=C(INK))   # 접안경
    d.ellipse([22, 15, 27, 20], fill=C(INK)); d.ellipse([23, 16, 26, 19], fill=C("P46"))   # 대물(환자 쪽)
    _box(d, 44, 2, 49, 26, CHROME)                                       # 세극 조명 탑
    d.rectangle([43, 2, 50, 6], fill=C(INK)); d.rectangle([44, 3, 49, 5], fill=C("P09"))   # 조명 머리
    d.line([46, 6, 46, 24], fill=C("P22"))                              # 세극(가는 빛줄)
    d.rectangle([31, 26, 33, 29], fill=C(INK))                           # 조이스틱
    return im


def w_eye_chart():
    """벽 시력표(26×34): 흰 판 · 위에서 아래로 작아지는 한글 · 숫자 줄 · 맨 아래 빨강 / 초록 띠 · 귀퉁이 곰팡이."""
    im = img(26, 34)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 25, 33], fill=C(INK))
    d.rectangle([1, 1, 24, 32], fill=C("P09"))
    rows = [(4, 5, 1), (11, 4, 2), (17, 3, 3), (22, 2, 4), (26, 1, 6)]   # (y, 글자 크기, 글자 수)
    for (y, sz, n) in rows:
        span = n * (sz + 2) - 2
        x0 = 13 - span // 2
        for i in range(n):
            x = x0 + i * (sz + 2)
            if sz >= 3:
                d.rectangle([x, y, x + sz - 1, y + sz - 1], outline=C(INK))
                d.point((x + sz // 2, y + sz // 2), fill=C(INK))
            else:
                d.rectangle([x, y, x + sz - 1, y + sz - 1], fill=C(INK))
    d.rectangle([3, 29, 11, 31], fill=C("P26")); d.rectangle([14, 29, 22, 31], fill=C("P36"))   # 빨강 / 초록 띠
    for (x, y) in ((22, 2), (23, 3), (21, 3), (2, 27)):                  # 곰팡이 점
        d.point((x, y), fill=C("P35"))
    return im


def lens_case(state=""):
    """렌즈 보관장(30×40): 강철 몸통 · 유리문 · 쟁반 셋에 둥근 렌즈들(반짝). taken = 가운데 쟁반이 비고 유리문이 반쯤 열렸다."""
    im = img(30, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 28, 37)
    _box(d, 2, 4, 27, 36, STEEL)
    d.rectangle([4, 6, 25, 32], fill=C(INK))
    d.rectangle([5, 7, 24, 31], fill=C("P13"))                           # 유리(푸른 기)
    for i, y in enumerate((11, 19, 27)):
        d.line([5, y, 24, y], fill=C(STEEL[3]))                          # 쟁반
        if state == "taken" and i == 1:
            continue
        for x in (8, 13, 18, 22):
            d.ellipse([x - 1, y - 4, x + 1, y - 2], fill=C("P46"))
            d.point((x, y - 4), fill=C("P09"))
    if state == "taken":
        d.line([24, 7, 28, 10], fill=C(INK)); d.line([28, 10, 28, 30], fill=C(INK))   # 반쯤 열린 문
    d.line([6, 8, 10, 8], fill=C("P15"))                                 # 유리 반사
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_HP4 = {
    "op_table": _r(op_table, 2, 1),
    "op_scope": _r(lambda: op_scope(), 1, 1),
    "slit_lamp": _r(slit_lamp, 2, 1),
    "w_eye_chart": _r(w_eye_chart, 1, 0, "wall", dx=3, dy=2),
    "lens_case": _r(lambda: lens_case(), 1, 1),
}
STATES_HP4 = {
    "op_scope": {"taken": lambda: op_scope("taken")},
    "lens_case": {"taken": lambda: lens_case("taken")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_hp4.png"
    ims = [p["fn"]() for p in PROPS_HP4.values()] + [fn() for st in STATES_HP4.values() for fn in st.values()]
    W = sum(i.width + 8 for i in ims) + 8
    sheet = Image.new("RGBA", (W, 76), (60, 56, 52, 255))
    x = 8
    for i in ims:
        sheet.alpha_composite(i, (x, 70 - i.height))
        x += i.width + 8
    sheet.resize((W * 4, 76 * 4), Image.NEAREST).save(out)
    print(out)
