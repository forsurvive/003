"""봉천 계단 물길 소품(단계 1-12a FQ-JC-01 계단 물길, SD-04d §10.3 · SD-09a L-R01-08 · 09 · 10 · SD-16 아이작풍).
  mud_dam       암거 서쪽 입구 갈림 보의 흙막이(2×1) — 다진 흙 둔덕 · 모래주머니 셋 · 박은 널빤지 · 서쪽 옛 배수 홈으로 꺾인 물
                상태 filled(흙막이를 걷어 봉천 수로로 다 — 물이 북쪽으로 곧게) · split(분배 — 두 줄기) · breach(한쪽을 터 물이 둥지 웅덩이로)
  bucket_row    고시원 물당번의 물통 줄(3×1) — 플라스틱 말통 여섯 · 호실 번호 분필(7-201 · 7-305 …) · 끈으로 맨 쪽지
                상태 dry(쓰러진 빈 통 — 물길을 되찾은 뒤) · half(반만 찬 통 — 나눈 뒤)
  dist_box      2077 분배함(1×1) — 콘크리트 함 · 녹슨 손잡이 바퀴 · '봉천 ← → 신림' 화살표 판 · 상태 open(바퀴 돌림 · 녹 긁힘)
  pool_nest     웅덩이 둥지(2×1) — 고인 물 가장자리의 넝마 · 지푸라기 · 갉은 뼈 · 새끼 쥐 눈빛 · 상태 drowned(물에 잠겨 휩쓸림) · empty(비었다)
  downspout     312계단 옆 홈통 끝(1×1) — 계단참 벽을 타고 내려오는 함석 홈통 · 받침 돌 · 상태 dry(말라 끊김 — 젖은 흙 자국이 서쪽으로) · wet(물이 쏟아짐) · half(가는 줄기)
  inlet_leak    배수지 유입구 관 균열(1×1) — 땅 위로 올라온 굵은 관 · 갈라진 이음매에서 새는 물 · 젖은 바닥 · 상태 patched(고철 덧판 · 테이프 감음)
  rain_grate    빗물받이 덮개(1×1) — 길가 철 격자 · 흙 냄새 자국 · 개 발자국(백구가 멈춘 자리)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _water(d, box, rnd, light=True):
    """흐르는 물(청록) — 띠 하나 · 물결 반짝임."""
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=C("P61"))
    d.rectangle([x0, y0, x1, y0 + 1], fill=C("P62"))
    if light:
        for _ in range(max(2, (x1 - x0) * (y1 - y0) // 60)):
            x = rnd.randint(x0 + 1, max(x0 + 1, x1 - 3))
            y = rnd.randint(y0 + 1, max(y0 + 1, y1 - 1))
            d.line([x, y, x + 2, y], fill=C("P63"))


def _sandbag(d, x, y, w=12, h=7):
    d.rounded_rectangle([x, y, x + w, y + h], radius=3, fill=C(INK))
    d.rounded_rectangle([x + 1, y + 1, x + w - 1, y + h - 1], radius=2, fill=C("P20"))
    d.line([x + 2, y + 1, x + w - 3, y + 1], fill=C("P22"))
    d.line([x + w // 2, y + 2, x + w // 2, y + h - 2], fill=C("P18"))                       # 묶은 주둥이 주름


# ================================================================================================ 흙막이
def mud_dam(state="dam"):
    """흙막이(2×1, 64×44): 아래가 물길. dam = 물이 둔덕에 막혀 서쪽(왼쪽)으로 꺾인다 · filled = 둔덕을 걷어 물이 위(북쪽 수로)로 ·
    split = 둔덕 가운데를 터 두 줄기 · breach = 왼쪽 끝을 터 물이 아래 웅덩이 쪽으로 쏟아진다."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    rnd = random.Random(12)
    d.rectangle([0, 30, 63, 43], fill=C("P17"))                                                 # 젖은 바닥 흙
    for _ in range(18):
        x, y = rnd.randint(1, 62), rnd.randint(31, 42)
        d.point((x, y), fill=C(rnd.choice(["P16", "P18"])))
    if state == "filled":
        _water(d, [26, 6, 37, 43], rnd)                                                         # 북쪽 수로로 곧게
        d.line([25, 6, 25, 43], fill=C(INK)); d.line([38, 6, 38, 43], fill=C(INK))
        for x0 in (4, 44):                                                                      # 걷어 낸 흙을 양옆에 쌓음
            d.polygon([(x0, 40), (x0 + 8, 30), (x0 + 16, 40)], fill=C("P18"), outline=C(INK))
        _sandbag(d, 46, 34)
        return im
    if state == "split":
        _water(d, [26, 6, 37, 43], rnd)
        _water(d, [0, 33, 26, 39], rnd)                                                         # 서쪽 반 줄기
        d.line([25, 6, 25, 32], fill=C(INK)); d.line([38, 6, 38, 43], fill=C(INK))
        d.polygon([(30, 30), (34, 24), (38, 30)], fill=C("P18"), outline=C(INK))                 # 둔덕 가운데를 튼 자리
        _sandbag(d, 40, 22); _sandbag(d, 44, 30)
        return im
    # dam · breach: 둔덕이 북쪽 수로 입을 막는다
    d.polygon([(10, 30), (22, 8), (42, 8), (56, 30)], fill=C(INK))
    d.polygon([(12, 29), (23, 10), (41, 10), (54, 29)], fill=C("P18"))
    d.line([23, 10, 41, 10], fill=C("P20"))
    for x in (16, 28, 40):
        _sandbag(d, x, 16 if x != 28 else 12)
    d.rectangle([33, 2, 35, 22], fill=C(INK)); d.rectangle([34, 3, 34, 21], fill=C("P19"))      # 박아 넣은 널빤지 말뚝
    d.line([29, 4, 39, 4], fill=C(INK)); d.line([29, 5, 39, 5], fill=C("P20"))
    if state == "breach":
        _water(d, [0, 31, 20, 43], rnd)                                                         # 왼쪽 끝을 터 아래(둥지 웅덩이)로
        d.polygon([(8, 30), (14, 22), (20, 30)], fill=C("P17"), outline=C(INK))
        _water(d, [26, 36, 63, 41], rnd, light=False)
    else:
        _water(d, [0, 33, 63, 39], rnd)                                                         # 서쪽(왼쪽) 옛 배수 홈으로 꺾인 물
        d.polygon([(0, 31), (6, 31), (2, 41), (0, 41)], fill=C("P61"))
    return im


# ================================================================================================ 물통 줄
def bucket_row(state="full"):
    """물당번 물통 줄(3×1, 96×44): 말통 여섯 · 뚜껑 · 분필 호실 번호 · 끈에 맨 쪽지."""
    im = img(96, 44)
    d = ImageDraw.Draw(im)
    cols = ["P49", "P09", "P45", "P49", "P54", "P09"]
    d.line([4, 14, 92, 18], fill=C("P19"), width=1)                                           # 묶은 끈
    for i, c in enumerate(cols):
        x = 4 + i * 15
        if state == "dry" and i in (1, 3, 4):                                                   # 쓰러진 빈 통
            d.rounded_rectangle([x, 32, x + 14, 41], radius=2, fill=C(INK))
            d.rounded_rectangle([x + 1, 33, x + 13, 40], radius=2, fill=C(c))
            d.rectangle([x + 12, 35, x + 14, 38], fill=C("P05"))
            continue
        d.rounded_rectangle([x, 18, x + 12, 41], radius=2, fill=C(INK))
        d.rounded_rectangle([x + 1, 19, x + 11, 40], radius=2, fill=C(c))
        d.line([x + 2, 20, x + 2, 39], fill=C("P09") if c != "P09" else C("P07"))
        d.rectangle([x + 4, 15, x + 8, 18], fill=C(INK)); d.rectangle([x + 5, 15, x + 7, 17], fill=C("P53"))   # 뚜껑
        lvl = 40 if state == "dry" else (30 if state == "half" else 23)                        # 물 높이 띠(반투명 말통)
        if lvl < 40:
            d.line([x + 3, lvl, x + 9, lvl], fill=C("P62"))
        d.line([x + 4, 28, x + 8, 28], fill=C("P08")); d.line([x + 4, 31, x + 7, 31], fill=C("P08"))   # 분필 번호(7-2…)
    d.rectangle([84, 6, 93, 14], fill=C(INK)); d.rectangle([85, 7, 92, 13], fill=C("P09"))     # 끈에 맨 쪽지
    for y in (9, 11):
        d.line([86, y, 91, y], fill=C("P05"))
    return im


# ================================================================================================ 분배함
def dist_box(state="rust"):
    """2077 분배함(1×1, 32×44): 콘크리트 함 · 손잡이 바퀴 · 좌우 화살표 판."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 20, 28, 42], fill=C(INK)); d.rectangle([4, 21, 27, 41], fill=C("P06")); d.line([4, 21, 27, 21], fill=C("P08"))
    d.line([6, 30, 25, 30], fill=C("P05"))
    d.rectangle([5, 10, 26, 18], fill=C(INK)); d.rectangle([6, 11, 25, 17], fill=C("P09"))      # 화살표 판 '봉천 ← → 신림'
    d.polygon([(7, 14), (11, 11), (11, 17)], fill=C("P44")); d.polygon([(24, 14), (20, 11), (20, 17)], fill=C("P53"))
    d.line([12, 14, 19, 14], fill=C("P03"))
    cx, cy = 16, 26
    wheel = "P24" if state == "rust" else "P13"
    d.ellipse([cx - 7, cy - 4, cx + 7, cy + 4], outline=C(INK), width=3)
    d.ellipse([cx - 6, cy - 3, cx + 6, cy + 3], outline=C(wheel), width=1)
    d.line([cx - 6, cy, cx + 6, cy], fill=C(wheel)); d.line([cx, cy - 3, cx, cy + 3], fill=C(wheel))
    if state == "rust":
        for x, y in ((8, 35), (22, 24), (12, 38)):
            d.point((x, y), fill=C("P25"))
    else:
        d.line([cx - 5, cy - 4, cx - 1, cy - 4], fill=C("P15"))                                # 녹 긁힌 반짝임
    return im


# ================================================================================================ 웅덩이 둥지
def pool_nest(state="nest"):
    """웅덩이 둥지(2×1, 64×40): 고인 물 · 넝마 · 지푸라기 · 갉은 뼈 · 새끼 눈빛."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    rnd = random.Random(7)
    d.ellipse([2, 16, 61, 39], fill=C(INK)); d.ellipse([3, 17, 60, 38], fill=C("P34"))
    d.ellipse([8, 20, 40, 34], fill=C("P61"))
    if state == "drowned":
        d.ellipse([3, 12, 61, 39], fill=C("P61")); d.ellipse([3, 12, 61, 39], outline=C(INK))
        for _ in range(6):                                                                     # 떠내려가는 넝마 조각
            x, y = rnd.randint(8, 54), rnd.randint(16, 34)
            d.line([x, y, x + 4, y + 1], fill=C("P19"))
        return im
    if state == "empty":
        for _ in range(8):
            x, y = rnd.randint(30, 56), rnd.randint(18, 34)
            d.line([x, y, x + 3, y - 1], fill=C("P21"))
        d.line([44, 26, 50, 24], fill=C("P08"))                                                # 남은 뼈 하나
        return im
    d.polygon([(30, 30), (36, 14), (52, 12), (60, 26), (54, 36), (34, 36)], fill=C(INK))
    d.polygon([(32, 30), (37, 16), (51, 14), (58, 26), (53, 34), (35, 34)], fill=C("P18"))
    for _ in range(14):                                                                        # 지푸라기 · 넝마
        x, y = rnd.randint(36, 56), rnd.randint(16, 33)
        d.line([x, y, x + rnd.randint(2, 4), y + rnd.randint(-1, 1)], fill=C(rnd.choice(["P21", "P22", "P39"])))
    d.line([40, 28, 46, 26], fill=C("P08")); d.point((47, 26), fill=C("P09"))                   # 갉은 뼈
    for x, y in ((44, 20), (49, 22), (52, 19)):                                                # 새끼 쥐 눈빛
        d.point((x, y), fill=C("P54")); d.point((x + 2, y), fill=C("P54"))
    return im


# ================================================================================================ 홈통
def downspout(state="dry"):
    """312계단 옆 홈통 끝(1×1, 32×56): 함석 홈통 · 꺾인 입 · 받침 돌 · 물 또는 젖은 흙 자국."""
    im = img(32, 56)
    d = ImageDraw.Draw(im)
    rnd = random.Random(3)
    d.rectangle([11, 0, 19, 40], fill=C(INK)); d.rectangle([12, 0, 18, 39], fill=C("P13")); d.line([12, 0, 12, 39], fill=C("P15"))
    for y in (10, 24):
        d.rectangle([10, y, 20, y + 2], fill=C(INK)); d.line([11, y + 1, 19, y + 1], fill=C("P11"))   # 고정 띠
    d.polygon([(10, 38), (20, 38), (24, 44), (6, 44)], fill=C(INK)); d.polygon([(11, 39), (19, 39), (22, 43), (8, 43)], fill=C("P12"))
    d.rectangle([4, 48, 27, 55], fill=C(INK)); d.rectangle([5, 49, 26, 54], fill=C("P06")); d.line([5, 49, 26, 49], fill=C("P08"))
    if state == "wet":
        d.rectangle([12, 44, 18, 50], fill=C("P62")); d.line([13, 44, 13, 50], fill=C("P63"))
        d.ellipse([4, 48, 27, 55], fill=C("P61"))
    elif state == "half":
        d.line([15, 44, 15, 50], fill=C("P62")); d.line([16, 45, 16, 49], fill=C("P63"))
        d.ellipse([10, 50, 22, 54], fill=C("P61"))
    else:
        for i in range(7):                                                                     # 말라 끊김 — 젖은 흙 자국이 서쪽(왼쪽)으로
            x = 8 - i * 2 + rnd.randint(-1, 1)
            d.point((max(0, x), 51 + rnd.randint(-1, 2)), fill=C("P17"))
        d.line([0, 53, 6, 52], fill=C("P17"))
    return im


# ================================================================================================ 유입구 균열
def inlet_leak(state="leak"):
    """배수지 유입구 관 균열(1×1, 32×44): 굵은 관 · 갈라진 이음매 · 새는 물 · 젖은 바닥. patched = 고철 덧판 · 테이프."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 34, 29, 43], fill=C("P34") if state == "leak" else C("P04"))                 # 젖은 바닥
    d.rectangle([0, 14, 31, 30], fill=C(INK)); d.rectangle([0, 15, 31, 29], fill=C("P12")); d.line([0, 15, 31, 15], fill=C("P14"))
    d.rectangle([14, 13, 18, 31], fill=C(INK)); d.rectangle([15, 14, 17, 30], fill=C("P11"))     # 이음매 띠
    if state == "leak":
        d.line([16, 16, 17, 22], fill=C(INK)); d.line([17, 22, 15, 28], fill=C(INK))            # 금
        d.line([18, 20, 24, 18], fill=C("P63")); d.line([18, 21, 26, 21], fill=C("P62"))        # 뿜어 나오는 물
        d.line([17, 28, 16, 36], fill=C("P62")); d.point((22, 34), fill=C("P63")); d.point((10, 37), fill=C("P63"))
    else:
        d.rectangle([10, 16, 22, 28], fill=C(INK)); d.rectangle([11, 17, 21, 27], fill=C("P24"))   # 고철 덧판
        for x, y in ((12, 18), (20, 18), (12, 26), (20, 26)):
            d.point((x, y), fill=C("P14"))
        d.rectangle([9, 21, 23, 23], fill=C("P05")); d.line([9, 21, 23, 21], fill=C("P07"))      # 감은 테이프
    return im


# ================================================================================================ 빗물받이
def rain_grate():
    """빗물받이 덮개(1×1, 32×32): 길가 철 격자 · 흙 냄새 자국 · 개 발자국."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([5, 9, 26, 24], fill=C(INK)); d.rectangle([6, 10, 25, 23], fill=C("P11"))
    for x in range(8, 25, 3):
        d.line([x, 11, x, 22], fill=C("P02"))
    d.line([6, 10, 25, 10], fill=C("P13"))
    d.ellipse([18, 20, 29, 27], fill=C("P17"))                                                   # 젖은 흙 자국
    for x, y in ((3, 26), (8, 29), (2, 20)):                                                   # 개 발자국
        d.ellipse([x, y, x + 2, y + 2], fill=C("P18"))
        d.point((x - 1, y - 1), fill=C("P18")); d.point((x + 3, y - 1), fill=C("P18"))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_JC = {
    "mud_dam": _r(mud_dam, 2, 1, down=-2),
    "bucket_row": _r(bucket_row, 3, 1, down=-2),
    "dist_box": _r(dist_box, 1, 1, down=-2),
    "pool_nest": _r(pool_nest, 0, 0, "deco"),
    "downspout": _r(downspout, 1, 1, down=-2),
    "inlet_leak": _r(inlet_leak, 1, 1, down=-2),
    "rain_grate": _r(rain_grate, 0, 0, "deco"),
}

STATES_JC = {
    "mud_dam": {s: (lambda s=s: mud_dam(s)) for s in ("filled", "split", "breach")},
    "bucket_row": {s: (lambda s=s: bucket_row(s)) for s in ("dry", "half")},
    "dist_box": {"open": lambda: dist_box("open")},
    "pool_nest": {s: (lambda s=s: pool_nest(s)) for s in ("drowned", "empty")},
    "downspout": {s: (lambda s=s: downspout(s)) for s in ("wet", "half")},
    "inlet_leak": {"patched": lambda: inlet_leak("patched")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_jc.png"
    ims = [v["fn"]() for v in PROPS_JC.values()] + [f() for st in STATES_JC.values() for f in st.values()]
    W = sum(i.width for i in ims) + 6 * len(ims)
    H = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, H), (120, 110, 100, 255))
    x = 0
    for i in ims:
        sheet.alpha_composite(i, (x, H - i.height))
        x += i.width + 6
    sheet = sheet.resize((W * 3, H * 3), Image.NEAREST)
    sheet.save(out)
    print(out)
