"""길 위 발견물 소품(단계 1-4f, SD-08 §13.2 '소형 관심 지점' · §14.1 경고 장치, SD-16 §7·§8 아이작풍).
월드 굽기(world_chunks.place_pois)가 청크마다 규칙으로 흩는다: 땅에 떨어진 쪽지 · 배낭 · 2077 민방위 대피소 표지 · 손글씨 경고판 · 뼈 무더기.
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01).
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def note_ground(seed=0):
    """땅에 떨어진 쪽지(바닥 덧그림): 구겨진 누런 종이 한 장을 돌멩이로 눌러 두었다. 줄글 자국 몇 줄."""
    rnd = random.Random(seed)
    im = img(20, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 4), (15, 2), (17, 12), (4, 14)], fill=C("P22"))          # 종이(살짝 비뚤게)
    d.line([(2, 4), (15, 2)], fill=C("P09"))
    d.line([(4, 14), (17, 12)], fill=C("P20"))
    d.line([(9, 3), (10, 13)], fill=C("P21"))                               # 접힌 자국
    for k in range(3):                                                      # 글줄
        y = 6 + k * 2
        d.line([(5, y + 1), (8 + rnd.randint(0, 2), y)], fill=C("P18"))
        d.line([(11, y), (14 - rnd.randint(0, 2), y - 1)], fill=C("P18"))
    d.ellipse([12, 8, 18, 13], fill=C("P05"))                               # 누름돌
    d.point((14, 9), fill=C("P07"))
    return im


def backpack(seed=0):
    """버려진 배낭(1×1): 바랜 국방색 천 · 앞주머니 · 위에 만 침낭 · 끊어진 어깨끈. 누군가 급히 내려놓고 다시 오지 않았다."""
    im = img(26, 24)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 17, 24, 23], fill=C("P02"))                               # 그림자
    d.rounded_rectangle([5, 7, 21, 21], 4, fill=C("P30"))                   # 몸통
    d.line([(6, 8), (20, 8)], fill=C("P31"))
    d.rounded_rectangle([8, 13, 18, 20], 2, fill=C("P29"))                  # 앞주머니
    d.line([(8, 13), (18, 13)], fill=C("P31"))
    d.rectangle([12, 15, 14, 16], fill=C("P06"))                            # 버클
    d.rounded_rectangle([4, 2, 22, 8], 3, fill=C("P25"))                    # 침낭(주홍)
    d.line([(6, 3), (20, 3)], fill=C("P27"))
    for x in (9, 17):                                                       # 묶음 끈
        d.line([(x, 2), (x, 8)], fill=C("P17"))
    d.line([(21, 12), (25, 18)], fill=C("P18"), width=2)                    # 끊어진 어깨끈
    return im


def evac_sign():
    """2077 민방위 대피소 표지(1×1): 쇠기둥 위 청록 판 — 흰 사람 그림 · '대피소' · 화살표. 녹이 아래로 흘렀다."""
    im = img(38, 52)
    d = ImageDraw.Draw(im)
    d.ellipse([13, 46, 25, 51], fill=C("P02"))
    d.rectangle([17, 18, 20, 49], fill=C("P05"))                            # 기둥
    d.line([(17, 18), (17, 49)], fill=C("P07"))
    d.rectangle([1, 0, 36, 21], fill=C("P61"))                              # 판
    d.rectangle([1, 0, 36, 1], fill=C("P62"))
    d.rectangle([3, 3, 34, 19], outline=C("P09"))
    d.ellipse([6, 5, 9, 8], fill=C("P09"))                                  # 사람 그림(머리·몸·다리)
    d.line([(7, 9), (7, 13)], fill=C("P09"))
    d.line([(7, 13), (5, 17)], fill=C("P09")); d.line([(7, 13), (10, 17)], fill=C("P09"))
    d.line([(5, 10), (10, 11)], fill=C("P09"))
    put_text(im, "대피소", 12, 4, "P09", size=8)
    d.polygon([(13, 14), (27, 14), (27, 12), (31, 15), (27, 18), (27, 16), (13, 16)], fill=C("P49"))   # 노란 화살표
    for x, h in ((5, 6), (22, 9), (32, 4)):                                 # 녹 흘림
        d.line([(x, 20), (x, 20 + h)], fill=C("P25"))
    return im


def warn_board(seed=0):
    """손글씨 경고판(1×1, SD-08 §14.1 경고 장치): 막대 두 개에 박은 널빤지, 붉은 칠 '위험' · 해골 낙서. 막대 아래 돌무더기."""
    rnd = random.Random(seed)
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 38, 28, 43], fill=C("P02"))
    for x in (7, 23):                                                       # 막대
        d.rectangle([x, 14, x + 2, 41], fill=C("P18"))
        d.line([(x, 14), (x, 41)], fill=C("P19"))
    d.polygon([(1, 3), (31, 1), (31, 19), (1, 20)], fill=C("P20"))          # 널빤지(살짝 기울게)
    d.line([(1, 3), (31, 1)], fill=C("P21"))
    d.line([(1, 11), (31, 10)], fill=C("P19"))                              # 판자 이음
    for (x, y) in ((4, 5), (27, 4), (4, 16), (27, 15)):                     # 못
        d.point((x, y), fill=C("P04"))
    put_text(im, "위험", 4, 4, "P53", size=8)
    d.ellipse([22, 4, 29, 11], fill=C("P09"))                               # 해골 낙서
    d.point((24, 7), fill=C("P53")); d.point((27, 7), fill=C("P53"))
    d.line([(24, 13), (29, 17)], fill=C("P53")); d.line([(29, 13), (24, 17)], fill=C("P53"))
    for k in range(4):                                                      # 돌
        x = 5 + k * 6 + rnd.randint(-1, 1)
        d.ellipse([x, 36, x + 5, 41], fill=C("P05" if k % 2 else "P06"))
    return im


def bone_pile(seed=0):
    """뼈 무더기(1×1, 경고 장치): 해골 둘 · 긴 뼈 · 찢긴 천. '시체가 말해 주는 위험'(SD-08 §14.1)."""
    rnd = random.Random(seed)
    im = img(34, 22)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 13, 33, 21], fill=C("P02"))
    d.polygon([(4, 16), (12, 10), (20, 15)], fill=C("P44"))                 # 찢긴 천
    for (x0, y0, x1, y1) in ((3, 15, 18, 11), (14, 17, 30, 13), (8, 12, 24, 18)):   # 긴 뼈
        d.line([(x0, y0), (x1, y1)], fill=C("P08"), width=2)
        d.ellipse([x0 - 2, y0 - 2, x0 + 1, y0 + 1], fill=C("P09"))
        d.ellipse([x1 - 1, y1 - 2, x1 + 2, y1 + 1], fill=C("P09"))
    for (x, y) in ((6, 3), (19, 5)):                                        # 해골
        d.ellipse([x, y, x + 9, y + 8], fill=C("P09"))
        d.rectangle([x + 2, y + 7, x + 7, y + 9], fill=C("P08"))
        d.point((x + 3, y + 4), fill=C("P02")); d.point((x + 6, y + 4), fill=C("P02"))
        d.point((x + 4 + rnd.randint(0, 1), y + 6), fill=C("P04"))
    return im


def civil_box():
    """민방위 비상함(1×1): 노란 칠 철함 · 앞면 '민방위 비상' 띠 · 녹슨 경첩과 걸쇠. 대피소 표지 곁에 둔다(SD-08 §13.2 보급 상자)."""
    im = img(30, 30)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 24, 28, 29], fill=C("P02"))
    d.rectangle([3, 6, 26, 26], fill=C("P48"))                              # 몸통
    d.rectangle([3, 6, 26, 7], fill=C("P49"))
    d.rectangle([2, 2, 27, 8], fill=C("P59"))                               # 뚜껑
    d.line([(2, 2), (27, 2)], fill=C("P60"))
    d.rectangle([3, 12, 26, 18], fill=C("P61"))                             # 띠
    put_text(im, "민방위", 5, 11, "P09", size=8)
    d.rectangle([13, 20, 16, 24], fill=C("P05")); d.point((14, 22), fill=C("P02"))   # 걸쇠
    for (x, y, h) in ((5, 19, 6), (22, 20, 5), (10, 8, 3)):                 # 녹
        d.line([(x, y), (x, y + h)], fill=C("P25"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_ROAD = {
    "note_ground": _r(lambda: note_ground(1), 0, 0, "deco"),
    "backpack": _r(lambda: backpack(1), 1, 1, down=-2),
    "evac_sign": _r(evac_sign, 1, 1),
    "warn_board": _r(lambda: warn_board(1), 1, 1),
    "bone_pile": _r(lambda: bone_pile(1), 1, 1, down=-2),
    "civil_box": _r(civil_box, 1, 1),
}
