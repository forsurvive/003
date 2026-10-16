"""무너진 국회 · 기록관(단계 1-11j SQ-S11 토요일의 여의도, SD-04a §5.4 · SD-09a L-R02-01 · SD-16 아이작풍).
  kh_column      열주(1×1, 높음): 흰 대리석 기둥 · 세로 홈 · 위 주두 · 아래 받침 · 금 · 상태 broken(꺾여 넘어진 밑동)
  kh_dome_chunk  내려앉은 돔 조각(3×2): 녹청 동판 곡면 · 철골 늑재 · 깨진 유리 천창 테두리
  kh_seats       본회의장 의석 줄(3×1): 나무 책상 줄 · 뒤집힌 명패(흰 뒷면) · 마이크 목 · 먼지
  kh_speaker     의장석(3×2): 높은 단 · 나무 연단 · 의사봉 · 위에 놓인 비상 계엄 포고문(붉은 도장)
  kh_shelf       기록관 서가(2×1, 높음): 회색 철 서가 · 묶음 의사록(색 띠) · 번호표 · 상태 gap(한 칸 빔)
  kh_box         원본 보존 상자(1×1): 회색 보존 상자 · 끈 · 붉은 '보존' 표 · 상태 open(빈 상자)
  kh_stairs_step 무너진 정면 계단 한 칸(덧그림): 금 간 화강암 계단 모서리 · 상태 leaf(유인물 한 장이 놓임)
  kh_flag        쓰러진 깃대(2×1): 앞마당의 녹슨 깃대 · 상태 bj(세워진 깃대 · 정통 대한민국 휘장 깃발)
  w_kh_plaque    '국회의사당' 현판(벽 3칸): 검은 돌판 · 금색 글씨 반쯤 떨어짐
  w_kh_notice    포고문 게시(벽 1칸): 누런 종이 · '비상 계엄 포고 제1호'
  kh_bobble_base 흔들인형 받침(1×1): 유리 진열 받침 · 빈 자리(수집은 이월)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y, h=2):
    for x in range(x0, x1):
        for yy in range(y, y + h):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def kh_column(state=""):
    """열주(32×88): 흰 대리석 원기둥 — 세로 홈 넷(그늘 · 빛) · 위 주두(넓은 판) · 아래 2단 받침 · 사선 금 하나.
    broken: 위가 꺾여 사라지고 밑동만 — 부러진 단면(거친 톱니) · 발치에 굴러떨어진 토막."""
    im = img(32, 88)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 30, 85)
    top = 6 if state != "broken" else 46
    d.rectangle([2, 78, 29, 85], fill=C(INK)); d.rectangle([3, 79, 28, 84], fill=C("P07")); d.line([3, 79, 28, 79], fill=C("P09"))
    d.rectangle([5, 72, 26, 78], fill=C(INK)); d.rectangle([6, 73, 25, 77], fill=C("P08")); d.line([6, 73, 25, 73], fill=C("P09"))
    d.rectangle([7, top, 24, 72], fill=C(INK)); d.rectangle([8, top, 23, 71], fill=C("P08"))
    for x, col in ((10, "P06"), (13, "P09"), (16, "P06"), (19, "P09"), (22, "P07")):
        d.line([x, top + 1, x, 71], fill=C(col))
    d.line([8, top, 8, 71], fill=C("P09")); d.line([23, top, 23, 71], fill=C("P06"))
    if state == "broken":
        for i, x in enumerate(range(8, 24, 3)):                           # 부러진 단면
            d.polygon([(x, top), (x + 3, top), (x + 1, top - 3 - (i % 2) * 2)], fill=C("P07"))
        d.line([8, top, 23, top], fill=C("P05"))
        d.ellipse([20, 74, 31, 86], fill=C(INK)); d.ellipse([21, 75, 30, 85], fill=C("P08")); d.arc([22, 77, 29, 84], 0, 360, fill=C("P06"))
    else:
        d.rectangle([3, 0, 28, 6], fill=C(INK)); d.rectangle([4, 1, 27, 5], fill=C("P08")); d.line([4, 1, 27, 1], fill=C("P09"))
        d.line([12, 30, 17, 44], fill=C("P05")); d.line([17, 44, 15, 52], fill=C("P05"))
    return im


def kh_dome_chunk():
    """내려앉은 돔 조각(96×72): 비스듬히 주저앉은 녹청 동판 껍질 — 오른쪽이 톱니처럼 찢겨 나가 철골 늑재가 드러나고,
    아래는 의석 쪽으로 무너져 깔림. 동판 이음 줄 · 녹 반점 · 깨진 천창 테두리 · 발치 콘크리트 파편."""
    im = img(96, 72)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 92, 68, 3)
    shell = [(2, 66), (6, 40), (16, 22), (32, 10), (50, 6), (62, 8), (66, 16), (60, 22), (70, 28), (64, 36), (76, 44), (70, 52), (84, 58), (80, 66)]
    d.polygon(shell, fill=C(INK))
    inner = [(x + (1 if x < 48 else -1), y + 1) for (x, y) in shell]
    d.polygon(inner, fill=C("P36"))
    rnd = random.Random(11)
    for y in range(14, 64, 6):                                            # 동판 이음 줄(곡면을 따라 기울게)
        d.line([6 + (64 - y) // 4, y + 2, 58 - (64 - y) // 6, y - 4], fill=C("P35"))
    for _ in range(70):
        x, y = rnd.randint(8, 70), rnd.randint(12, 62)
        if im.getpixel((x, y))[:3] == P.rgb("P36"):
            d.point((x, y), fill=C("P37" if rnd.random() < 0.6 else "P34"))
    for (x0, y0, x1, y1) in ((60, 18, 88, 30), (66, 30, 92, 44), (72, 46, 94, 56)):   # 찢긴 자리에서 삐져나온 늑재
        d.line([x0, y0, x1, y1], fill=C(INK), width=3); d.line([x0, y0, x1, y1], fill=C("P12"))
    for x0 in (20, 40):
        d.line([x0, 14, x0 - 4, 64], fill=C(INK), width=3); d.line([x0, 14, x0 - 4, 64], fill=C("P12"))
    d.arc([30, 2, 64, 26], 190, 330, fill=C(INK), width=3)              # 천창 테두리
    for (a, b) in (((38, 8), (44, 3)), ((50, 4), (56, 9))):
        d.line([a, b], fill=C("P15"))
    for (x, y, r) in ((84, 64, 5), (12, 66, 4), (90, 52, 3), (70, 66, 4)):   # 파편
        d.polygon([(x - r, y), (x, y - r), (x + r, y + 1), (x, y + r)], fill=C("P05")); d.point((x, y - r + 1), fill=C("P07"))
    return im


def kh_seats(seed=0):
    """의석 줄(96×40): 나무 책상 셋이 이어진 줄 · 책상마다 뒤집힌 명패(흰 뒷면) · 마이크 목 · 의자 등받이 · 먼지."""
    im = img(96, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 94, 37)
    for i in range(3):
        x = 2 + i * 31
        d.rectangle([x, 4, x + 28, 12], fill=C(INK)); d.rectangle([x + 1, 5, x + 27, 11], fill=C("P38"))   # 의자 등받이
        d.line([x + 1, 5, x + 27, 5], fill=C("P39"))
        d.rectangle([x, 14, x + 29, 26], fill=C(INK)); d.rectangle([x + 1, 15, x + 28, 25], fill=C("P18"))  # 책상
        d.line([x + 1, 15, x + 28, 15], fill=C("P20")); d.line([x + 1, 20, x + 28, 20], fill=C("P17"))
        d.rectangle([x + 2, 26, x + 27, 34], fill=C("P17")); d.line([x + 2, 34, x + 27, 34], fill=C(INK))
        if (i + seed) % 3 != 1:                                           # 뒤집힌 명패(뒷면이 흰 삼각 받침)
            d.polygon([(x + 8, 16), (x + 20, 16), (x + 19, 13), (x + 9, 13)], fill=C(INK))
            d.polygon([(x + 9, 15), (x + 19, 15), (x + 18, 14), (x + 10, 14)], fill=C("P08"))
        d.line([x + 24, 16, x + 26, 8], fill=C("P04")); d.ellipse([x + 25, 6, x + 28, 9], fill=C("P02"))  # 마이크 목
    rnd = random.Random(seed + 3)
    for _ in range(14):
        d.point((rnd.randint(4, 92), rnd.randint(16, 24)), fill=C("P19"))
    return im


def kh_speaker():
    """의장석(96×80): 3단 단상(나무 · 앞면 휘장 자리 빈 사각) · 연단 · 의사봉 · 연단 위 포고문(누런 종이, 붉은 도장)."""
    im = img(96, 80)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 92, 77, 3)
    for k, (y0, inset) in enumerate(((54, 0), (42, 8), (30, 16))):
        d.rectangle([2 + inset, y0, 93 - inset, y0 + 22 - k * 4], fill=C(INK))
        d.rectangle([3 + inset, y0 + 1, 92 - inset, y0 + 21 - k * 4], fill=C("P18" if k != 1 else "P17"))
        d.line([3 + inset, y0 + 1, 92 - inset, y0 + 1], fill=C("P20"))
    d.rectangle([36, 58, 60, 72], fill=C("P16")); d.rectangle([36, 58, 60, 72], outline=C("P47"))     # 떼어 낸 휘장 자리
    d.rectangle([30, 6, 66, 32], fill=C(INK)); d.rectangle([31, 7, 65, 31], fill=C("P19")); d.line([31, 7, 65, 7], fill=C("P21"))
    d.polygon([(29, 6), (67, 6), (64, 2), (32, 2)], fill=C("P20"))
    d.rectangle([38, 0, 54, 6], fill=C("P22")); d.rectangle([38, 0, 54, 6], outline=C("P20"))         # 포고문
    d.line([40, 2, 50, 2], fill=C("P05")); d.line([40, 4, 48, 4], fill=C("P05")); d.ellipse([50, 3, 53, 6], fill=C("P53"))
    d.line([58, 4, 64, 2], fill=C("P17"), width=2); d.rectangle([62, 0, 66, 3], fill=C("P18"))         # 의사봉
    return im


def kh_shelf(state=""):
    """기록관 서가(64×72): 회색 철 서가 4단 · 묶음 의사록(색 띠 · 번호표) · 맨 위 '의사록 2077' 판. gap: 셋째 단 한 칸이 빈다(원본 자리)."""
    im = img(64, 72)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 69)
    d.rectangle([1, 2, 62, 68], fill=C(INK)); d.rectangle([2, 3, 61, 67], fill=C("P12"))
    rnd = random.Random(21)
    for r, y in enumerate(range(10, 66, 14)):
        d.rectangle([3, y + 10, 60, y + 12], fill=C("P13")); d.line([3, y + 10, 60, y + 10], fill=C("P14"))
        x = 4
        while x < 58:
            w = rnd.randint(4, 7)
            if not (state == "gap" and r == 2 and 24 <= x <= 36):
                col = rnd.choice(["P22", "P21", "P08", "P41"])
                d.rectangle([x, y + 1, x + w - 1, y + 9], fill=C(col))
                d.line([x, y + 1, x, y + 9], fill=C("P05"))
                d.line([x + 1, y + 5, x + w - 2, y + 5], fill=C(rnd.choice(["P53", "P45", "P56"])))   # 색 띠
            x += w
    d.rectangle([14, 3, 50, 9], fill=C("P08")); put_text(im, "2077", 23, 2, "P02", 7)
    return im


def kh_box(state=""):
    """원본 보존 상자(32×30): 회색 보존 상자 · 노끈 열십자 · 붉은 '보존' 표. open: 뚜껑이 옆에 기대고 속이 빔."""
    im = img(32, 30)
    d = ImageDraw.Draw(im)
    _shadow(d, 3, 29, 27)
    d.rectangle([3, 10, 28, 26], fill=C(INK)); d.rectangle([4, 11, 27, 25], fill=C("P06")); d.line([4, 11, 27, 11], fill=C("P07"))
    if state == "open":
        d.rectangle([5, 12, 26, 16], fill=C("P02"))
        d.polygon([(26, 4), (31, 6), (31, 24), (27, 22)], fill=C(INK)); d.polygon([(27, 6), (30, 7), (30, 22), (28, 21)], fill=C("P07"))
    else:
        d.rectangle([2, 6, 29, 11], fill=C(INK)); d.rectangle([3, 7, 28, 10], fill=C("P07"))
        d.line([15, 6, 15, 26], fill=C("P20")); d.line([3, 18, 28, 18], fill=C("P20"))
        d.rectangle([6, 13, 13, 17], fill=C("P53")); d.point((9, 15), fill=C("P08"))
    return im


def kh_stairs_step(state=""):
    """무너진 정면 계단 한 칸(32×20, 덧그림): 금 간 화강암 모서리 · 깨진 조각. leaf: 그 위에 유인물 한 장(흰 종이 · '종전')."""
    im = img(32, 20)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 8, 31, 15], fill=C("P06")); d.line([0, 8, 31, 8], fill=C("P08")); d.line([0, 15, 31, 15], fill=C("P04"))
    d.line([9, 8, 12, 15], fill=C("P04")); d.line([22, 9, 20, 15], fill=C("P05"))
    d.polygon([(26, 16), (30, 16), (28, 19)], fill=C("P05"))
    if state == "leaf":
        d.polygon([(8, 4), (20, 3), (21, 11), (9, 12)], fill=C(INK)); d.polygon([(9, 5), (19, 4), (20, 10), (10, 11)], fill=C("P09"))
        d.line([11, 7, 17, 6], fill=C("P53")); d.line([11, 9, 16, 8], fill=C("P05"))
    return im


def kh_flag(state=""):
    """깃대(64×80): 녹슨 쇠 깃대가 잔디에 쓰러져 있다. bj: 세워진 깃대 끝에 정통 대한민국 휘장 깃발(흰 바탕 · 가운데 붉고 푸른 원 · 검은 획 넷)."""
    im = img(64, 80)
    d = ImageDraw.Draw(im)
    if state == "bj":
        _shadow(d, 24, 40, 77)
        d.rectangle([28, 70, 36, 77], fill=C(INK)); d.rectangle([29, 71, 35, 76], fill=C("P05"))
        d.rectangle([31, 4, 33, 71], fill=C("P05")); d.line([31, 4, 31, 71], fill=C("P07"))
        d.rectangle([34, 6, 62, 26], fill=C(INK)); d.rectangle([35, 7, 61, 25], fill=C("P09"))
        d.pieslice([42, 10, 54, 22], 180, 360, fill=C("P53")); d.pieslice([42, 10, 54, 22], 0, 180, fill=C("P45"))
        for (x0, y0) in ((37, 9), (58, 9), (37, 21), (58, 21)):
            d.line([x0, y0, x0 + 2, y0 + 2], fill=C(INK))
        d.ellipse([30, 1, 34, 5], fill=C("P48"))
    else:
        _shadow(d, 2, 62, 74)
        d.line([4, 70, 60, 62], fill=C(INK), width=4); d.line([4, 70, 60, 62], fill=C("P25"), width=2)
        d.rectangle([0, 66, 9, 74], fill=C(INK)); d.rectangle([1, 67, 8, 73], fill=C("P05"))
        d.polygon([(48, 64), (60, 62), (58, 70), (50, 72)], fill=C("P07"))       # 바랜 천 조각
    return im


def w_kh_plaque():
    """현판(96×30, 벽): 검은 돌판 · 금색 '국회의사당' — 마지막 글자가 떨어져 자국만."""
    im = img(96, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 93, 26], fill=C(INK)); d.rectangle([3, 5, 92, 25], fill=C("P02")); d.line([3, 5, 92, 5], fill=C("P04"))
    put_text(im, "국회의사", 18, 9, "P49")
    d.rectangle([70, 10, 77, 18], outline=C("P03"))                      # 떨어진 '당' 자국
    return im


def w_kh_notice():
    """포고문 게시(32×38, 벽): 누런 종이 · 붉은 제목줄 · 글줄 · 붉은 직인."""
    im = img(32, 38)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 2, 28, 34], fill=C(INK)); d.rectangle([4, 3, 27, 33], fill=C("P22"))
    d.rectangle([4, 3, 27, 9], fill=C("P53"))
    put_text(im, "포고", 9, 2, "P09", 7)
    for y in range(12, 28, 3):
        d.line([7, y, 24 - (y % 4), y], fill=C("P18"))
    d.ellipse([18, 26, 25, 33], fill=C("P53")); d.point((21, 29), fill=C("P22"))
    return im


def kh_bobble_base():
    """흔들인형 받침(32×36): 유리 진열 상자 · 비어 있는 받침(먼지 자국 동그라미) — 수집은 이월."""
    im = img(32, 36)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 28, 33)
    d.rectangle([5, 22, 26, 32], fill=C(INK)); d.rectangle([6, 23, 25, 31], fill=C("P18")); d.line([6, 23, 25, 23], fill=C("P20"))
    d.rectangle([7, 4, 24, 22], outline=C("P14"))
    d.line([8, 5, 12, 21], fill=C("P15")); d.ellipse([12, 18, 19, 22], outline=C("P06"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_S11 = {
    "kh_column": _r(kh_column, 1, 1, down=-2),
    "kh_dome_chunk": _r(kh_dome_chunk, 3, 2, down=-2),
    "kh_seats": _r(lambda: kh_seats(0), 3, 1, down=-2),
    "kh_seats2": _r(lambda: kh_seats(1), 3, 1, down=-2),
    "kh_speaker": _r(kh_speaker, 3, 2, down=-2),
    "kh_shelf": _r(kh_shelf, 2, 1, down=-2),
    "kh_box": _r(kh_box, 1, 1, down=-2),
    "kh_stairs_step": _r(kh_stairs_step, 0, 0, "deco"),
    "kh_flag": _r(kh_flag, 2, 1, down=-2),
    "w_kh_plaque": _r(w_kh_plaque, 3, 0, "wall", dx=0, dy=8),
    "w_kh_notice": _r(w_kh_notice, 1, 0, "wall", dx=0, dy=6),
    "kh_bobble_base": _r(kh_bobble_base, 1, 1, down=-2),
}

STATES_S11 = {
    "kh_column": {"broken": lambda: kh_column("broken")},
    "kh_shelf": {"gap": lambda: kh_shelf("gap")},
    "kh_box": {"open": lambda: kh_box("open")},
    "kh_stairs_step": {"leaf": lambda: kh_stairs_step("leaf")},
    "kh_flag": {"bj": lambda: kh_flag("bj")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_s11.png"
    ims = [v["fn"]() for v in PROPS_S11.values()] + [f() for st in STATES_S11.values() for f in st.values()]
    rows, row, w = [], [], 0
    for i in ims:
        if w + i.width + 6 > 420 and row:
            rows.append(row); row, w = [], 0
        row.append(i); w += i.width + 6
    rows.append(row)
    W = max(sum(i.width + 6 for i in r) for r in rows) + 4
    Hs = [max(i.height for i in r) + 6 for r in rows]
    sheet = Image.new("RGBA", (W, sum(Hs) + 4), C("P30"))
    y = 2
    for r, hh in zip(rows, Hs):
        x = 2
        for i in r:
            sheet.alpha_composite(i, (x, y)); x += i.width + 6
        y += hh
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    sheet.save(out)
    print(out)
