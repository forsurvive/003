"""관악산 들개 바위굴 · 연수원 남서 별관 소품(단계 1-11a SQ-S01 외눈의 인식표, SD-09a L-R01-05 · SD-04a §4.1 · SD-16 아이작풍).
  collar_pile  뼈 마당 한가운데 2077년 개 목줄 더미(1×1) — 가죽 · 나일론 · 방울 · 등록 인식표 수십 개가 엉켜 있다
  dog_nest     외눈의 잠자리(1×1) — 체육관 매트 조각 · 낙엽 · 흰 털 뭉치를 둥글게 다진 둥지
  tag_drop     떨어진 인식표(바닥 덧그림) — 끊어진 목줄 끝에 매달린 작은 쇠 인식표가 반짝인다
  gym_rail     별관 2층 관람석 난간(1×1, 막힘) — 녹슨 쇠 난간 + 아래로 무너진 체육관 바닥의 그늘
  gym_hoop     별관 1층 벽 농구 골대(벽 소품) — 기운 백보드 · 찢긴 그물
  gym_crack    무너진 마루 틈(바닥 덧그림) — 갈라진 원목 마루 사이로 보이는 어둠(소음 잔해 칸 표시를 겸한다)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01)."""
import os, sys, random, math
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

C = lambda t: P.rgb(t) + (255,)


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def collar_pile(seed=3):
    """목줄 더미: 납작한 흙 둔덕 위로 색 바랜 목줄 고리가 겹겹이. 쇠 인식표 · 방울 · 버클이 군데군데 반짝인다."""
    rnd = random.Random(seed)
    im = img(34, 24)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 13, 33, 23], fill=C("P02"))                               # 그림자
    d.ellipse([3, 10, 31, 21], fill=C("P18"))                               # 다진 흙 둔덕
    d.ellipse([6, 11, 28, 18], fill=C("P19"))
    cols = ["P26", "P46", "P53", "P31", "P20", "P61", "P25", "P44"]         # 빨강 · 파랑 · 다홍 · 풀색 · 가죽 · 청록 …
    for k in range(11):
        cx = rnd.randint(8, 26)
        cy = rnd.randint(8, 16)
        rx, ry = rnd.randint(4, 7), rnd.randint(2, 3)
        col = C(cols[k % len(cols)])
        d.arc([cx - rx, cy - ry, cx + rx, cy + ry], rnd.randint(0, 60), rnd.randint(250, 360), fill=col, width=2)
        if rnd.random() < 0.5:                                              # 버클
            bx = cx + rnd.choice((-rx, rx))
            d.rectangle([bx - 1, cy - 1, bx + 1, cy + 1], fill=C("P07"))
    for k in range(7):                                                      # 인식표 · 방울
        x, y = rnd.randint(7, 27), rnd.randint(9, 18)
        if k % 3 == 0:
            d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=C("P49"))          # 방울(놋쇠)
            d.point((x, y - 1), fill=C("P50"))
        else:
            d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=C("P07"))        # 쇠 인식표
            d.point((x - 1, y - 1), fill=C("P09"))
    d.line([(4, 12), (1, 6)], fill=C("P20"), width=2)                       # 삐져나온 가죽 끈
    d.point((1, 5), fill=C("P07"))
    return im


def dog_nest(seed=4):
    """외눈의 잠자리: 찢긴 체육 매트 조각(파랑) 위에 낙엽 · 마른 풀을 둥글게 다지고 가운데 흰 털이 뭉쳤다."""
    rnd = random.Random(seed)
    im = img(34, 24)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 12, 33, 23], fill=C("P02"))
    d.polygon([(4, 12), (28, 9), (31, 19), (6, 21)], fill=C("P44"))         # 매트 조각
    d.line([(4, 12), (28, 9)], fill=C("P45"))
    d.line([(10, 11), (12, 20)], fill=C("P43"))                             # 매트 이음매
    d.ellipse([5, 9, 29, 21], fill=C("P20"))                                # 둥지 테(마른 풀)
    d.ellipse([9, 11, 25, 18], fill=C("P18"))                               # 움푹한 가운데
    for k in range(14):                                                     # 낙엽 · 풀 줄기
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(9, 12)
        x, y = 17 + math.cos(a) * r, 15 + math.sin(a) * r * 0.5
        d.point((round(x), round(y)), fill=C(rnd.choice(["P21", "P27", "P19", "P26"])))
    for (x, y) in ((14, 13), (16, 14), (19, 13), (17, 16), (21, 15)):        # 흰 털 뭉치
        d.point((x, y), fill=C("P09")); d.point((x + 1, y), fill=C("P08"))
    return im


def tag_drop(seed=5):
    """떨어진 인식표(바닥 덧그림): 끊어진 가죽 목줄 끝의 작은 쇠 인식표. 빛이 한 점 튄다."""
    im = img(16, 10)
    d = ImageDraw.Draw(im)
    d.line([(1, 7), (6, 4), (9, 5)], fill=C("P20"), width=2)                # 끊긴 목줄
    d.point((0, 8), fill=C("P19"))
    d.ellipse([9, 3, 14, 8], fill=C("P07"))                                 # 인식표(둥근 쇠)
    d.ellipse([10, 4, 13, 7], fill=C("P08"))
    d.point((11, 4), fill=C("P09")); d.point((12, 3), fill=C("P50"))        # 반짝
    d.point((9, 5), fill=C("P49"))                                          # 고리
    return im


def gym_rail(seed=6):
    """관람석 난간(1×1): 녹슨 쇠 기둥 둘 + 가로대 둘. 아래쪽은 무너진 바닥 쪽 그늘이 비친다."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 26, 31, 39], fill=C("P01"))                             # 아래 허공(무너진 1층 바닥 그늘)
    d.rectangle([0, 26, 31, 27], fill=C("P02"))
    for x in (3, 27):                                                       # 기둥
        d.rectangle([x, 6, x + 2, 30], fill=C("P05"))
        d.line([(x, 6), (x, 30)], fill=C("P06"))
        d.point((x + 1, 18), fill=C("P25"))
    for y in (8, 18):                                                       # 가로대
        d.rectangle([0, y, 31, y + 2], fill=C("P05"))
        d.line([(0, y), (31, y)], fill=C("P07"))
    for x in (9, 21):                                                       # 녹물 줄
        d.line([(x, 11), (x, 17)], fill=C("P25"))
    return im


def gym_hoop(seed=7):
    """벽 농구 골대: 기운 흰 백보드(테두리 빨강) · 녹슨 링 · 찢겨 늘어진 그물."""
    im = img(44, 44)
    d = ImageDraw.Draw(im)
    d.polygon([(4, 3), (40, 1), (41, 22), (5, 24)], fill=C("P08"))         # 백보드(기울었다)
    d.polygon([(4, 3), (40, 1), (41, 22), (5, 24)], outline=C("P53"))
    d.rectangle([17, 11, 28, 20], outline=C("P53"))
    d.line([(6, 4), (39, 2)], fill=C("P09"))
    for (x, y) in ((12, 6), (33, 16), (20, 4)):                             # 얼룩
        d.point((x, y), fill=C("P06"))
    d.ellipse([15, 22, 31, 27], outline=C("P26"), width=2)                  # 링
    for k, x in enumerate(range(16, 31, 3)):                                # 찢긴 그물
        L = 10 if k % 2 else 6
        d.line([(x, 26), (x + 1, 26 + L)], fill=C("P08"))
    d.line([(16, 30), (29, 31)], fill=C("P07"))
    return im


def gym_crack(seed=8):
    """무너진 마루 틈(덧그림): 원목 마루가 V자로 갈라지고, 사이로 어둠 · 부서진 판재 끝이 들려 있다. 밟으면 삐걱인다."""
    rnd = random.Random(seed)
    im = img(30, 18)
    d = ImageDraw.Draw(im)
    d.polygon([(3, 9), (12, 5), (20, 7), (27, 4), (24, 11), (14, 13), (6, 14)], fill=C("P00"))
    d.polygon([(6, 10), (13, 7), (20, 9), (23, 8), (21, 11), (13, 12)], fill=C("P01"))
    for (x0, y0, x1, y1) in ((2, 8, 10, 4), (19, 6, 26, 2), (12, 13, 20, 16)):  # 들린 판재 끝
        d.line([(x0, y0), (x1, y1)], fill=C("P20"), width=2)
        d.line([(x0, y0 + 1), (x1, y1 + 1)], fill=C("P18"))
    for _ in range(5):
        d.point((rnd.randint(4, 25), rnd.randint(3, 15)), fill=C("P21"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_BW = {
    "collar_pile": _r(collar_pile, 1, 1, down=-2),
    "dog_nest": _r(dog_nest, 0, 0, "deco"),
    "tag_drop": _r(tag_drop, 0, 0, "deco"),
    "gym_rail": _r(gym_rail, 1, 1, down=-8),
    "gym_hoop": _r(gym_hoop, 1, 0, "wall", dx=-6, dy=2),
    "gym_crack": _r(gym_crack, 0, 0, "deco"),
}
