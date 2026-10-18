"""문래 철공소 골목 소품(단계 1-D7 준비, SD-09a L-R02-14 L993 · L-R02-21 L1037 · SD-16 아이작풍).
  원문: 무기 수리 · 개조 장인 거리 — 성태경 '선반 성씨' · 연시헌 용접공 · 골목 바닥에 200년 동안 떨어진 쇳가루가 굳어 길이 반짝인다.
    lathe_mr        선반(2×1): 주철 받침 · 주축대 · 척에 물린 총열 봉 · 공구대 · 바닥 쇳밥 / 상태 run(척이 돌고 쇳밥이 튄다)
    weld_mr         용접대(2×1): 철판 작업대 · 바이스 · 용접 마스크 · 산소/아세틸렌 통 둘(초록 · 적갈) · 호스
                    / 상태 lit(용접 불꽃 — 파란 흰빛 점)
    dust_mr         쇳가루 길(덮개 1×1 · 칸을 막지 않음): 굳은 쇳가루 무늬 · 반짝이는 점 몇 · 변형 셋(dust_mr2 · dust_mr3)
    w_sign_mr       철공소 간판(벽 2칸): 녹슨 양철판 '선반 · 용접 · 총기 수리' · 페인트로 덧쓴 '성씨'
    die_mold        태성 총열 금형(1×1): 기름 먹은 강철 덩어리 · 위 판 홈 · 원형 다이 구멍 · 각인 '태성 TS-7' · 무겁다(받침 나무)
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
STEEL = ("P03", "P04", "P05", "P06", "P07")
IRON = ("P10", "P11", "P12", "P13", "P14")             # 주철(푸른 회색)
RUST = ("P23", "P24", "P25", "P26", "P27")
WOOD = ("P16", "P17", "P18", "P19", "P20")
OIL = ("P01", "P02", "P10")


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
        if x % 2 == 0:
            d.point((x, y), fill=C("P02"))


def _chips(d, rnd, x0, x1, y0, y1, n, cols=("P07", "P08", "P13")):
    """쇳밥: 꼬불한 1~2픽셀 조각."""
    for _ in range(n):
        x, y = rnd.randint(x0, x1), rnd.randint(y0, y1)
        c = C(rnd.choice(cols))
        d.point((x, y), fill=c)
        if rnd.random() < 0.5:
            d.point((x + 1, y + rnd.choice((-1, 0))), fill=c)


def lathe_mr(state=""):
    """선반(2×1, 64×52): 주철 받침 · 주축대(왼쪽 상자) · 척 · 물린 총열 봉 · 심압대(오른쪽) · 공구대 · 쇳밥."""
    im = img(64, 52)
    d = ImageDraw.Draw(im)
    rnd = random.Random(14)
    _shadow(d, 3, 61, 50)
    _box(d, 4, 38, 59, 48, IRON)                                            # 받침(다리 둘 사이 칩받이)
    d.rectangle([7, 41, 56, 45], fill=C(OIL[1]))
    _chips(d, rnd, 8, 55, 41, 45, 18)
    _box(d, 6, 30, 57, 38, IRON)                                            # 베드
    d.line([7, 33, 56, 33], fill=C(IRON[3]))
    _box(d, 4, 14, 20, 32, IRON)                                            # 주축대
    d.rectangle([7, 17, 17, 21], fill=C(IRON[0]))                           # 기어 덮개 창
    for i, c in enumerate(("P49", "P53", "P09")):
        d.point((8 + i * 3, 25), fill=C(c))                                 # 손잡이 셋
    d.ellipse([19, 17, 27, 29], fill=C(INK))                                # 척
    d.ellipse([20, 18, 26, 28], fill=C(STEEL[3] if state != "run" else STEEL[4]))
    if state == "run":
        d.line([21, 19, 25, 27], fill=C(STEEL[1])); d.line([25, 19, 21, 27], fill=C(STEEL[1]))   # 도는 척 흐림
    else:
        for (x, y) in ((23, 19), (21, 26), (25, 26)):
            d.point((x, y), fill=C(STEEL[0]))                               # 척 죠 셋
    d.rectangle([27, 21, 50, 24], fill=C(INK))                              # 총열 봉
    d.line([27, 22, 50, 22], fill=C(STEEL[4])); d.line([27, 23, 50, 23], fill=C(STEEL[2]))
    _box(d, 49, 18, 57, 31, IRON)                                           # 심압대
    d.ellipse([50, 20, 55, 25], fill=C(IRON[0]))
    _box(d, 33, 25, 42, 30, STEEL)                                          # 공구대
    d.line([37, 25, 37, 23], fill=C(STEEL[0]))                              # 바이트
    if state == "run":
        for (x, y) in ((36, 20), (39, 19), (34, 18), (41, 21), (38, 17)):
            d.point((x, y), fill=C("P50"))                                  # 튀는 쇳밥(밝은 점)
    return im


def weld_mr(state=""):
    """용접대(2×1, 64×56): 철판 작업대 · 바이스 · 걸린 용접 마스크 · 산소(초록)/아세틸렌(적갈) 통 · 호스."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 54)
    for x, ramp in ((48, ("P28", "P29", "P30", "P31", "P32")), (56, RUST)):  # 가스통 둘(뒤)
        d.rectangle([x, 12, x + 6, 52], fill=C(INK))
        d.rectangle([x + 1, 13, x + 5, 51], fill=C(ramp[1]))
        d.line([x + 2, 14, x + 2, 50], fill=C(ramp[3]))
        d.rectangle([x + 2, 8, x + 4, 12], fill=C(STEEL[2]))               # 밸브
    d.line([50, 10, 44, 18], fill=C(INK)); d.line([58, 10, 45, 20], fill=C("P52"))   # 호스
    _box(d, 2, 28, 44, 36, STEEL)                                           # 상판(철판 — 그을음)
    for x in (6, 15, 27, 36):
        d.point((x, 31), fill=C(STEEL[0])); d.point((x + 1, 32), fill=C(OIL[1]))
    d.rectangle([5, 36, 8, 52], fill=C(INK)); d.rectangle([38, 36, 41, 52], fill=C(INK))   # 다리
    d.line([6, 37, 6, 51], fill=C(STEEL[2])); d.line([39, 37, 39, 51], fill=C(STEEL[2]))
    d.line([8, 46, 38, 46], fill=C(STEEL[1]))                               # 가로대
    _box(d, 30, 21, 40, 28, IRON)                                           # 바이스
    d.rectangle([33, 18, 37, 21], fill=C(IRON[3]))
    d.line([40, 24, 44, 24], fill=C(STEEL[3]))                              # 바이스 손잡이
    d.rectangle([8, 22, 24, 27], fill=C(INK))                               # 물린 철판 두 장(용접 중)
    d.line([9, 23, 23, 23], fill=C(STEEL[3])); d.line([9, 26, 23, 26], fill=C(STEEL[1]))
    d.line([16, 23, 16, 26], fill=C(RUST[3]))                               # 용접 비드
    d.rectangle([10, 6, 22, 18], fill=C(INK))                               # 걸린 용접 마스크(벽 고리)
    d.rectangle([11, 7, 21, 17], fill=C("P12"))
    d.rectangle([13, 10, 19, 12], fill=C("P33"))                            # 차광 유리
    if state == "lit":
        for (x, y, c) in ((16, 24, "P09"), (15, 23, "P63"), (17, 25, "P63"), (18, 22, "P50"), (14, 26, "P62"), (19, 21, "P60")):
            d.point((x, y), fill=C(c))
        d.point((16, 22), fill=C("P09")); d.point((16, 20), fill=C("P63"))
    return im


def dust_mr(seed=0):
    """쇳가루 길(덮개 1×1, 32×32): 굳은 쇳가루 — 검푸른 얼룩 결 · 반짝 점(흰 · 연청). 칸을 막지 않는다."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed * 31 + 5)
    for _ in range(26):                                                     # 굳은 결(짧은 빗금)
        x, y = rnd.randint(1, 30), rnd.randint(1, 30)
        c = C(rnd.choice(("P10", "P11", "P02")))
        d.line([x, y, x + rnd.choice((1, 2)), y + rnd.choice((0, 1))], fill=c)
    for _ in range(5 + seed):
        x, y = rnd.randint(2, 29), rnd.randint(2, 29)
        d.point((x, y), fill=C(rnd.choice(("P09", "P15", "P14"))))          # 반짝
    return im


def tracks_mr(kind="cart"):
    """쇳가루 길 위 자국(덮개 1×1): cart = 리어카 바퀴 두 줄(세로) · boots = 인솔조 장화 자국(굵은 밑창 무늬) — 칸을 막지 않는다."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    if kind == "cart":
        for x in (9, 22):
            for y in range(0, 32, 2):
                d.point((x, y), fill=C("P15")); d.point((x + 1, y + 1), fill=C("P14"))
    else:
        for (x, y) in ((8, 4), (19, 12), (9, 20), (20, 27)):
            d.rounded_rectangle([x, y, x + 5, y + 4], radius=2, outline=C("P15"))
            d.line([x + 1, y + 2, x + 4, y + 2], fill=C("P14"))
    return im


def w_sign_mr():
    """철공소 간판(벽 2칸, 64×36): 녹슨 양철판 · 리벳 · '선반·용접·총기수리' · 페인트로 덧쓴 '성씨'."""
    im = img(64, 36)
    d = ImageDraw.Draw(im)
    _box(d, 1, 2, 62, 33, RUST)
    rnd = random.Random(3)
    for _ in range(30):
        d.point((rnd.randint(3, 60), rnd.randint(4, 31)), fill=C(rnd.choice(RUST[:3])))
    for (x, y) in ((4, 5), (59, 5), (4, 30), (59, 30)):
        d.point((x, y), fill=C(STEEL[4]))
    put_text(im, "선반·용접·총기", 5, 4, "P09", 8, "Galmuri7")
    put_text(im, "성씨", 22, 17, "P49", 8, "Galmuri7")
    d.line([20, 29, 44, 28], fill=C("P49"))                                 # 붓 자국 밑줄
    return im


def die_mold():
    """태성 총열 금형(1×1, 32×36): 받침 나무 · 기름 먹은 강철 덩어리 · 윗판 홈 · 다이 구멍 · 각인."""
    im = img(32, 36)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 30, 34)
    _box(d, 2, 28, 29, 33, WOOD)                                            # 받침
    _box(d, 4, 10, 27, 28, STEEL)
    d.rectangle([5, 11, 26, 13], fill=C(STEEL[4]))                          # 윗면 빛
    d.line([5, 23, 26, 23], fill=C(STEEL[0]))                               # 위 · 아래 판 이음
    d.ellipse([12, 21, 19, 27], fill=C(INK)); d.ellipse([13, 22, 18, 26], fill=C(IRON[1]))   # 다이 구멍
    d.point((14, 23), fill=C(IRON[4]))
    for x in (6, 25):
        d.rectangle([x - 1, 18, x, 25], fill=C(STEEL[1]))                   # 가이드 핀
    d.line([6, 26, 25, 26], fill=C(OIL[1]))                                 # 기름 줄
    put_text(im, "TS-7", 8, 13, "P03", 8, "Galmuri7")                    # 각인(윗판 아래 면)
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_MR = {
    "lathe_mr": _r(lambda: lathe_mr(), 2, 1, down=-2),
    "weld_mr": _r(lambda: weld_mr(), 2, 1, down=-2),
    "dust_mr": _r(lambda: dust_mr(0), 1, 1, "deco", down=0),
    "dust_mr2": _r(lambda: dust_mr(1), 1, 1, "deco", down=0),
    "dust_mr3": _r(lambda: dust_mr(2), 1, 1, "deco", down=0),
    "w_sign_mr": _r(w_sign_mr, 2, 0, "wall", dx=0, dy=4),
    "tracks_mr": _r(lambda: tracks_mr("cart"), 1, 1, "deco", down=0),
    "boots_mr": _r(lambda: tracks_mr("boots"), 1, 1, "deco", down=0),
    "die_mold": _r(die_mold, 1, 1, down=-2),
}
STATES_MR = {
    "lathe_mr": {"run": lambda: lathe_mr("run")},
    "weld_mr": {"lit": lambda: weld_mr("lit")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_MR.values()] + [fn() for st in STATES_MR.values() for fn in st.values()]
    cols = 5
    cw, ch = 80, 70
    sheet = Image.new("RGBA", (cols * cw, ((len(ims) + cols - 1) // cols) * ch), (70, 66, 74, 255))
    for i, m in enumerate(ims):
        sheet.alpha_composite(m, ((i % cols) * cw + 4, (i // cols) * ch + 4))
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    sheet.save(out)
