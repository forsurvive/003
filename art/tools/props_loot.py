"""파밍 v3 · 보관 자리 · 거래처 소품(단계 1-L, 계획 `_plans/1-L_loot_stash_plan.md` §9 · SD-16 아이작풍).
  털린 자리 무늬(덧그림 32×32 — 용기 앞 바닥 칸, 막지 않음. §9.1 '보이는 빔'):
    spill_drawer    빠져 엎어진 서랍 하나 · 쏟아진 단추 · 실패
    spill_paper     흩어진 종이 · 반쯤 젖은 사진 한 장 · 찢긴 봉투
    spill_door      떼어 내 바닥에 눕힌 찬장 문짝 · 경첩 나사
    spill_chalk     분필 X 표시 · 동그라미 화살표(털이꾼 표시)
    spill_glass     깨진 병 · 유리 조각 · 마른 얼룩
  swap_box_lt     바꿈 상자(1×1): 판자 함 · 분필 '하나 두고 하나' · 위에 깡통 하나
  bell_line_lt    방울 줄(덧그림): 용기 앞에 맨 실 · 작은 방울 셋(M-395)
  trade_mat_lt    장사꾼 자리(2×1): 헌 담요 위 물건 · 등불 · 저울
  w_trade_lt      장사 간판(벽 2칸): 판자에 손글씨 — 결마다 글이 다르다 / 상태 scrap · herb · parts · cloth · food · drift
  tboard_*        문 앞 세움 간판(덧그림): A자 판자 · 결 두 글자(고철 · 약초 · 부품 · 헌옷 · 국밥 · 잡화)
  locker_rent_lt  빌린 물품 보관함(2×1): 철제 칸 여섯 · 번호표 · 자물쇠 / 상태 mine(내 칸에 분필 표시)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다. 위에서 빛(위 밝게 · 아래 어둡게), 반투명 없음."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
WOOD = ("P16", "P17", "P18", "P19", "P20")
PAPER = ("P06", "P07", "P08", "P09")


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _box(d, x0, y0, x1, y1, ramp, top=True):
    d.rectangle([x0, y0, x1, y1], fill=C(INK))
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=C(ramp[1]))
    if top:
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=C(ramp[-1]))
    d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=C(ramp[0]))


def _grain(d, x0, y0, x1, y1, col, seed):
    rnd = random.Random(seed)
    for _ in range((x1 - x0) * (y1 - y0) // 14):
        x, y = rnd.randint(x0, x1), rnd.randint(y0, y1)
        d.line([x, y, min(x1, x + rnd.randint(1, 3)), y], fill=C(col))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        if x % 2 == 0:
            d.point((x, y), fill=C("P02"))


# ================================================================================================ 털린 자리 무늬
def spill_drawer():
    """빠져 엎어진 서랍(32×32): 비스듬히 뒤집힌 나무 서랍(바닥판이 위로) · 손잡이 · 둘레에 쏟아진 단추 · 실패 하나 · 바늘."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    _shadow(d, 5, 26, 25)
    d.polygon([(4, 14), (22, 9), (27, 20), (9, 25)], fill=C(INK))            # 뒤집힌 서랍(바닥판)
    d.polygon([(5, 14), (21, 10), (26, 20), (9, 24)], fill=C(WOOD[2]))
    d.line([(6, 14), (21, 10)], fill=C(WOOD[4]))
    d.line([(9, 23), (25, 19)], fill=C(WOOD[0]))
    d.line([(10, 17), (22, 14)], fill=C(WOOD[1]))                            # 판자 이음
    d.line([(4, 14), (9, 25)], fill=C(INK)); d.line([(5, 15), (9, 23)], fill=C(WOOD[3]))   # 앞판 옆면
    d.point((6, 19), fill=C("P48")); d.point((7, 19), fill=C("P47"))          # 놋쇠 손잡이
    for (x, y, c) in ((27, 26, "P53"), (3, 27, "P45"), (24, 28, "P09"), (14, 28, "P49"), (29, 13, "P07")):
        d.point((x, y), fill=C(INK)); d.point((x + 1, y), fill=C(c))          # 단추
    d.rectangle([17, 25, 20, 28], fill=C(INK)); d.rectangle([18, 26, 19, 27], fill=C("P52"))   # 실패
    d.line([(21, 26), (25, 24)], fill=C("P52"))                               # 풀린 실
    d.line([(11, 28), (14, 27)], fill=C("P08"))                               # 바늘
    return im


def spill_paper():
    """흩어진 종이(32×32): 누렇게 바랜 종이 다섯 장이 겹쳐 흩어짐 · 젖었다 마른 얼룩 · 사진 한 장(사람 둘 실루엣) · 찢긴 봉투."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    rnd = random.Random(7)
    for (x, y, w, h) in ((2, 16, 10, 7), (9, 20, 11, 8), (17, 13, 10, 7), (21, 22, 9, 7), (5, 7, 9, 6)):
        d.rectangle([x, y, x + w, y + h], fill=C(INK))
        d.rectangle([x + 1, y + 1, x + w - 1, y + h - 1], fill=C(PAPER[2] if rnd.random() < 0.5 else PAPER[1]))
        for yy in range(y + 2, y + h - 1, 2):
            d.line([x + 2, yy, x + w - 2 - rnd.randint(0, 3), yy], fill=C(PAPER[0]))   # 글줄
        if rnd.random() < 0.5:
            d.point((x + w - 2, y + h - 2), fill=C(WOOD[3]))                 # 얼룩
    d.rectangle([12, 4, 21, 11], fill=C(INK)); d.rectangle([13, 5, 20, 10], fill=C("P09"))      # 사진
    d.rectangle([14, 6, 19, 9], fill=C("P12"))
    d.point((15, 7), fill=C("P41")); d.point((17, 7), fill=C("P41")); d.line([15, 8, 15, 9], fill=C("P03")); d.line([17, 8, 17, 9], fill=C("P03"))
    d.polygon([(24, 4), (30, 6), (28, 11), (23, 9)], fill=C(INK)); d.polygon([(25, 5), (29, 7), (27, 10), (24, 8)], fill=C(PAPER[3]))   # 봉투
    d.line([(25, 5), (27, 8)], fill=C(PAPER[0]))
    return im


def spill_door():
    """떼어 낸 문짝(32×32): 찬장 문짝 하나가 바닥에 비스듬히 누움 · 경첩 자리 구멍 · 빠진 나사 둘 · 문짝 아래 그늘."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 28, 28)
    d.polygon([(3, 11), (25, 6), (29, 23), (7, 28)], fill=C(INK))
    d.polygon([(4, 12), (24, 7), (28, 22), (7, 27)], fill=C(WOOD[3]))
    d.polygon([(7, 14), (22, 10), (25, 20), (9, 24)], fill=C(INK))           # 안쪽 판
    d.polygon([(8, 14), (21, 11), (24, 20), (10, 23)], fill=C(WOOD[2]))
    d.line([(8, 14), (21, 11)], fill=C(WOOD[4]))
    _grain(d, 10, 15, 22, 21, WOOD[1], 3)
    for (x, y) in ((5, 15), (6, 22)):
        d.rectangle([x, y, x + 1, y + 1], fill=C(INK))                       # 경첩 떼어 낸 구멍
    d.point((27, 26), fill=C("P07")); d.point((28, 26), fill=C("P05"))         # 빠진 나사
    d.point((2, 25), fill=C("P07")); d.point((2, 26), fill=C("P05"))
    d.point((23, 16), fill=C("P48"))                                         # 문고리 자리
    return im


def spill_chalk():
    """분필 표시(32×32): 바닥에 굵은 X · 옆에 동그라미 안 화살표(털이꾼끼리의 표시) · 분필 가루."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    W = "P08"
    for o in (0, 1):
        d.line([(5 + o, 6), (17 + o, 20)], fill=C(W)); d.line([(17 + o, 6), (5 + o, 20)], fill=C(W))
    d.point((4, 5), fill=C("P07")); d.point((18, 21), fill=C("P07"))
    d.ellipse([18, 17, 29, 28], outline=C(W))
    d.line([(20, 22), (27, 22)], fill=C(W)); d.line([(25, 20), (27, 22)], fill=C(W)); d.line([(25, 24), (27, 22)], fill=C(W))
    rnd = random.Random(5)
    for _ in range(9):
        d.point((rnd.randint(3, 29), rnd.randint(3, 29)), fill=C("P06"))
    return im


def spill_glass():
    """깨진 병(32×32): 목이 부러진 갈색 병 하나 · 초록 유리 조각 · 마른 얼룩 테두리 · 반짝이는 날."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 15, 27, 27], fill=C("P17"))                                # 마른 얼룩
    d.ellipse([6, 16, 25, 26], fill=C("P16"))
    d.polygon([(8, 17), (19, 13), (21, 17), (10, 21)], fill=C(INK))         # 누운 병 몸통
    d.polygon([(9, 17), (18, 14), (20, 17), (10, 20)], fill=C("P24"))
    d.line([(9, 17), (18, 14)], fill=C("P26"))
    d.polygon([(19, 13), (23, 12), (24, 14), (21, 17)], fill=C(INK)); d.point((22, 13), fill=C("P25"))   # 부러진 목
    for (x, y, c) in ((25, 21, "P31"), (5, 23, "P30"), (14, 24, "P31"), (27, 16, "P24"), (12, 26, "P30")):
        d.polygon([(x, y), (x + 2, y - 1), (x + 3, y + 1)], fill=C(INK)); d.point((x + 1, y), fill=C(c)); d.point((x + 2, y), fill=C("P09"))
    return im


# ================================================================================================ 거래 · 보관
def swap_box_lt():
    """바꿈 상자(1×1, 32×40): 못 박은 판자 함(뚜껑 반쯤 열림) · 앞면 분필 '하나 두고 하나' · 뚜껑 위 깡통 하나 · 옆에 끈 묶은 꾸러미."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 3, 30, 38)
    _box(d, 3, 16, 28, 37, WOOD)
    for y in (22, 29):
        d.line([4, y, 27, y], fill=C(WOOD[0]))
    for (x, y) in ((5, 18), (26, 18), (5, 35), (26, 35)):
        d.point((x, y), fill=C("P07"))                                       # 못
    d.polygon([(2, 16), (29, 16), (27, 9), (4, 11)], fill=C(INK))           # 들린 뚜껑
    d.polygon([(4, 15), (28, 15), (26, 10), (5, 12)], fill=C(WOOD[3]))
    d.line([(5, 12), (26, 10)], fill=C(WOOD[4]))
    d.rectangle([17, 4, 22, 10], fill=C(INK)); d.rectangle([18, 5, 21, 9], fill=C("P12")); d.line([18, 5, 21, 5], fill=C("P14"))   # 깡통
    put_text(im, "바꿈", 8, 22, "P08", 8, "Galmuri7")
    for (x0, x1, y, tip) in ((7, 24, 31, 24), (24, 7, 34, 7)):            # 분필 화살표 둘(하나 두고 하나 가져가쇼)
        d.line([(x0, y), (x1, y)], fill=C("P08"))
        dx = 2 if tip > x0 else -2
        d.line([(tip, y), (tip - dx, y - 2)], fill=C("P08")); d.line([(tip, y), (tip - dx, y + 2)], fill=C("P08"))
    return im


def bell_line_lt():
    """방울 줄(덧그림 32×16): 용기 앞을 가로지른 실 · 작은 놋쇠 방울 셋(위 밝은 점) · 양 끝 매듭."""
    im = img(32, 16)
    d = ImageDraw.Draw(im)
    d.line([(1, 5), (10, 7), (21, 7), (30, 5)], fill=C("P06"))
    for x in (1, 30):
        d.rectangle([x - 1, 4, x, 5], fill=C(INK))
    for x in (8, 16, 24):
        d.ellipse([x - 2, 7, x + 2, 11], fill=C(INK)); d.ellipse([x - 1, 8, x + 1, 10], fill=C("P48")); d.point((x - 1, 8), fill=C("P50"))
        d.point((x, 11), fill=C(INK))
    return im


def trade_mat_lt():
    """장사꾼 자리(2×1, 64×40): 헌 군용 담요 위 늘어놓은 물건(깡통 · 병 · 고철 · 약봉지) · 등유 등불(불 켬) · 놋쇠 저울."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 38)
    d.rectangle([2, 22, 61, 37], fill=C(INK)); d.rectangle([3, 23, 60, 36], fill=C("P29"))
    d.line([3, 23, 60, 23], fill=C("P31")); d.line([3, 36, 60, 36], fill=C("P28"))
    for x in range(5, 60, 6):
        d.point((x, 29), fill=C("P30"))                                      # 담요 결
    items = [(6, 17, "P12", "P14"), (14, 15, "P24", "P26"), (24, 18, "P04", "P06"), (33, 16, "P09", "P07")]
    for (x, y, a, b) in items:
        d.rectangle([x, y, x + 5, y + 8], fill=C(INK)); d.rectangle([x + 1, y + 1, x + 4, y + 7], fill=C(a)); d.line([x + 1, y + 1, x + 4, y + 1], fill=C(b))
    d.polygon([(42, 28), (47, 20), (52, 28)], fill=C(INK)); d.polygon([(43, 27), (47, 21), (51, 27)], fill=C("P48"))   # 저울 받침
    d.line([(40, 20), (54, 20)], fill=C(INK)); d.line([(40, 20), (40, 24)], fill=C("P47")); d.line([(54, 20), (54, 24)], fill=C("P47"))
    d.line([(38, 24), (42, 24)], fill=C("P47")); d.line([(52, 24), (56, 24)], fill=C("P47"))
    d.rectangle([55, 8, 61, 22], fill=C(INK)); d.rectangle([56, 9, 60, 21], fill=C("P23"))        # 등불
    d.rectangle([57, 12, 59, 18], fill=C("P50")); d.point((58, 14), fill=C("P09")); d.line([56, 8, 60, 8], fill=C("P05"))
    d.line([(58, 4), (58, 8)], fill=C("P05"))
    return im


TRADE_SIGN = {"scrap": ("고철 삽니다", "P08"), "herb": ("약초 받음", "P56"), "parts": ("진공관·전지", "P49"),
              "cloth": ("헌옷 삽니다", "P42"), "food": ("국 · 물 있음", "P27"), "drift": ("뭐든 받음", "P07")}


def w_trade_lt(state="drift"):
    """장사 간판(벽 2칸, 64×40): 못 박은 판자에 손글씨 — 결마다 글 · 색이 다르다 · 아래 매단 깡통 둘(드나들면 딸랑)."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    txt, col = TRADE_SIGN.get(state, TRADE_SIGN["drift"])
    d.polygon([(3, 8), (61, 6), (61, 25), (3, 27)], fill=C(INK))
    d.polygon([(4, 9), (60, 7), (60, 24), (4, 26)], fill=C(WOOD[3]))
    d.line([(4, 9), (60, 7)], fill=C(WOOD[4])); d.line([(4, 18), (60, 16)], fill=C(WOOD[1]))
    for (x, y) in ((6, 10), (58, 8), (6, 24), (58, 22)):
        d.point((x, y), fill=C("P07"))
    put_text(im, txt, 9, 11, col, 8, "Galmuri7")
    for x in (18, 44):
        d.line([(x, 26), (x, 31)], fill=C("P05"))
        d.rectangle([x - 2, 31, x + 2, 37], fill=C(INK)); d.rectangle([x - 1, 32, x + 1, 36], fill=C("P12")); d.point((x - 1, 32), fill=C("P14"))
    return im


def locker_rent_lt(state=""):
    """빌린 물품 보관함(2×1, 64×56): 잿빛 철제 칸 여섯(3×2) · 칸마다 번호표 · 자물쇠 · 위에 '보관 하루 5' 판. 상태 mine = 3번 칸에 분필 동그라미."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 54)
    _box(d, 2, 10, 61, 53, ("P11", "P12", "P13", "P14"))
    for i in range(3):
        for j in range(2):
            x0, y0 = 4 + i * 19, 12 + j * 20
            d.rectangle([x0, y0, x0 + 17, y0 + 18], fill=C(INK)); d.rectangle([x0 + 1, y0 + 1, x0 + 16, y0 + 17], fill=C("P13"))
            d.line([x0 + 1, y0 + 1, x0 + 16, y0 + 1], fill=C("P15"))
            for yy in range(y0 + 4, y0 + 15, 3):
                d.line([x0 + 4, yy, x0 + 12, yy], fill=C("P12"))                # 환기 구멍 줄
            d.rectangle([x0 + 12, y0 + 8, x0 + 15, y0 + 12], fill=C(INK)); d.point((x0 + 13, y0 + 9), fill=C("P48"))
            put_text(im, str(1 + i + 3 * j), x0 + 2, y0 + 2, "P09", 8, "Galmuri7")
    if state == "mine":
        d.ellipse([41, 13, 58, 30], outline=C("P08"))
    d.rectangle([8, 0, 55, 10], fill=C(INK)); d.rectangle([9, 1, 54, 9], fill=C("P09"))
    put_text(im, "보관 하루5", 11, 1, "P02", 8, "Galmuri7")
    return im


BOARD = {"scrap": ("고철", "P08"), "herb": ("약초", "P56"), "parts": ("부품", "P49"), "cloth": ("헌옷", "P42"), "food": ("국밥", "P27"),
         "drift": ("잡화", "P07")}


def tboard(kind="drift"):
    """문 앞 세움 간판(덧그림 32×32 — 월드 문 옆 칸): 판자 두 장을 A자로 세움 · 앞판에 결 두 글자 · 다리 아래 그늘 · 꼭대기 끈에 깡통 하나."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    txt, col = BOARD.get(kind, BOARD["drift"])
    _shadow(d, 6, 27, 30)
    for (a, b2, c2, e2) in (((8, 29), (15, 3), (18, 3), (12, 29)), ((24, 29), (17, 3), (14, 3), (20, 29))):   # A자 다리 둘(먹선 + 나무)
        d.polygon([a, b2, c2, e2], fill=C(INK))
    d.line([(10, 28), (16, 5)], fill=C(WOOD[2])); d.line([(22, 28), (16, 5)], fill=C(WOOD[1]))
    d.line([(11, 28), (16, 6)], fill=C(WOOD[3]))
    d.polygon([(5, 8), (27, 8), (28, 23), (4, 23)], fill=C(INK))           # 앞판
    d.polygon([(6, 9), (26, 9), (27, 22), (5, 22)], fill=C(WOOD[3]))
    d.line([(6, 9), (26, 9)], fill=C(WOOD[4])); d.line([(5, 16), (27, 16)], fill=C(WOOD[1]))
    put_text(im, txt, 8, 11, col, 8, "Galmuri7")
    d.line([(16, 4), (16, 2)], fill=C("P05")); d.rectangle([14, 0, 18, 3], fill=C(INK)); d.point((15, 1), fill=C("P14"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_LOOT = {
    "spill_drawer": _r(spill_drawer, 0, 0, "deco"),
    "spill_paper": _r(spill_paper, 0, 0, "deco"),
    "spill_door": _r(spill_door, 0, 0, "deco"),
    "spill_chalk": _r(spill_chalk, 0, 0, "deco"),
    "spill_glass": _r(spill_glass, 0, 0, "deco"),
    "swap_box_lt": _r(swap_box_lt, 1, 1, down=-2),
    "bell_line_lt": _r(bell_line_lt, 0, 0, "deco"),
    "trade_mat_lt": _r(trade_mat_lt, 2, 1, down=-2),
    "w_trade_lt": _r(w_trade_lt, 2, 0, "wall", dx=0, dy=6),
    "locker_rent_lt": _r(locker_rent_lt, 2, 1, down=-2),
    **{"tboard_" + k: _r(lambda k=k: tboard(k), 0, 0, "deco", dx=0, dy=0) for k in BOARD},   # 문 앞 세움 간판(§9.2)
}
STATES_LOOT = {
    "w_trade_lt": {s: (lambda s=s: w_trade_lt(s)) for s in TRADE_SIGN},
    "locker_rent_lt": {"mine": lambda: locker_rent_lt("mine")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_LOOT.values()] + [fn() for st in STATES_LOOT.values() for fn in st.values()]
    cols = 5
    rows = [ims[i:i + cols] for i in range(0, len(ims), cols)]
    W = max(sum(i.width + 4 for i in r) for r in rows) + 4
    H = sum(max(i.height for i in r) + 4 for r in rows) + 4
    sheet = Image.new("RGBA", (W, H), C("P05"))
    y = 2
    for r in rows:
        x = 2
        for i in r:
            sheet.alpha_composite(i, (x, y))
            x += i.width + 4
        y += max(i.height for i in r) + 4
    sheet = sheet.resize((W * 4, H * 4), Image.NEAREST)
    sheet.save(out)
