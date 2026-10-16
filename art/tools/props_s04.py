"""봉천 동 주민센터 민원실 · 관악 레이더 중계소 소품(단계 1-11c SQ-S04 도성이 뒤척인다, SD-09a L-R01-32 · L-R01-04 · SD-04a §4.4 · SD-16 아이작풍).
  radar_dome      레이더 돔 R-03(5×4) — 육각 콘크리트 받침 위 흰 지오데식 돔(삼각 판 이음 · 빗물 얼룩 · 꼭대기 피뢰침) · 옆 철제 사다리
  radar_beacon    돔 꼭대기 앰버 경광(덧그림, 진행기가 세운다 — 전지를 뽑으면 거둔다) · 상태 dim(대기)
  radar_mast      작은 안테나 탑(1×1) — 격자 철탑 · 접시 하나
  fission_socket  핵분열 전지 받침(1×1, 돔 안) — 크림 관제망 콘솔 위 유리 칸 속 앰버 전지 · 상태 empty(뽑힌 빈 칸)
  brain4          두뇌-4(CR-313) 대기 개체(1×1) — 유리 통 진공관 뇌 · 상태 off(전지가 뽑힌 뒤 꺼짐)
  chain_fence     철조망 울타리 한 칸(1×1, 가로) — 콘크리트 기둥 · 철망 · 윗줄 가시철사 · 상태 cut(잘려 벌어진 틈)
  w_civil_sign    민원실 벽 간판(벽 소품 2칸) — 2077년 '민원실' + 붙인 종이 '대기 구역 B · 미등록 아동 보호 조치'
  care_cloth      각성회 정비 의식 흔적(덧그림) — 흰 천 · 기름 깡통 · 대기등 심지(D 해법 뒤 주민센터 앞)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import math
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


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def radar_dome(seed=11):
    """레이더 돔 R-03(5×4 발): 육각 받침 · 지오데식 흰 돔 · 판 이음선 · 빗물 얼룩 · 철제 사다리 · 정비 문."""
    W, H = 164, 168
    im = img(W, H)
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    cx, base = W // 2, H - 10
    d.polygon([(10, base - 26), (40, base - 40), (124, base - 40), (154, base - 26), (154, base), (10, base)], fill=C(INK))
    d.polygon([(12, base - 26), (41, base - 38), (123, base - 38), (152, base - 26), (152, base - 2), (12, base - 2)], fill=C("P06"))
    d.polygon([(12, base - 26), (41, base - 38), (123, base - 38), (152, base - 26)], fill=C("P07"))
    for x in range(16, 150, 12):
        d.line([x, base - 24, x, base - 3], fill=C("P05"))                   # 거푸집 줄
    _shadow(d, 8, 156, base)
    r = 62
    dy = base - 46
    d.pieslice([cx - r - 2, dy - r - 2, cx + r + 2, dy + r + 2], 180, 360, fill=C(INK))
    d.rectangle([cx - r - 2, dy - 2, cx + r + 2, dy + 6], fill=C(INK))
    d.pieslice([cx - r, dy - r, cx + r, dy + r], 180, 360, fill=C("P08"))
    d.rectangle([cx - r, dy - 1, cx + r, dy + 4], fill=C("P07"))
    d.pieslice([cx - r, dy - r, cx + r - 18, dy + r - 18], 190, 300, fill=C("P09"))   # 빛은 왼쪽 위
    for k in range(1, 6):                                                     # 위도 이음
        rr = r * math.cos(k * math.pi / 12)
        yy = dy - r * math.sin(k * math.pi / 12)
        d.line([cx - rr, yy, cx + rr, yy], fill=C("P07"))
    for k in range(-5, 6):                                                    # 경도 이음(삼각 판)
        a = k * math.pi / 12
        pts = [(cx + r * math.sin(a) * math.cos(t * math.pi / 24), dy - r * math.sin(t * math.pi / 24)) for t in range(13)]
        d.line(pts, fill=C("P07"))
    for _ in range(9):                                                        # 빗물 얼룩
        x = rnd.randint(cx - r + 12, cx + r - 12)
        top = dy - int(math.sqrt(max(0, r * r - (x - cx) ** 2))) + 6
        d.line([x, top, x + rnd.choice([-1, 0, 1]), top + rnd.randint(8, 22)], fill=C("P06"))
    d.rectangle([cx + 26, dy - 30, cx + 40, dy - 20], fill=C("P05"))           # 떨어진 판 하나(검은 틈)
    d.rectangle([cx + 28, dy - 28, cx + 38, dy - 22], fill=C("P02"))
    d.line([cx, dy - r - 2, cx, dy - r - 14], fill=C(INK), width=2)            # 피뢰침
    d.rounded_rectangle([cx - 10, dy - 2, cx + 10, dy + 6], 2, fill=C("P12"))   # 정비 문
    d.rectangle([cx - 8, dy - 26, cx + 8, dy - 2], fill=C(INK))
    d.rectangle([cx - 7, dy - 25, cx + 7, dy - 3], fill=C("P12")); d.line([cx - 7, dy - 25, cx + 7, dy - 25], fill=C("P13"))
    d.point((cx + 5, dy - 14), fill=C("P49"))
    lx = cx - 46                                                              # 사다리(돔 옆구리 → 꼭대기)
    for k in range(10):
        y = dy - 4 - k * 6
        x = lx + k * 3
        d.line([x, y, x + 6, y - 1], fill=C("P12"))
    d.line([lx, dy - 4, lx + 27, dy - 58], fill=C("P11")); d.line([lx + 6, dy - 5, lx + 33, dy - 59], fill=C("P11"))
    put_text(im, "R-03", cx + 16, dy - 12, "P05", 8, "Galmuri7")
    return im


def radar_beacon(state=""):
    """돔 꼭대기 앰버 경광(덧그림 1칸): 쇠 받침 + 둥근 유리 등 + 빛 번짐 디더. dim = 대기(느린 점멸의 어두운 박자)."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    lit = state != "dim"
    d.rectangle([13, 22, 18, 27], fill=C(INK)); d.rectangle([14, 23, 17, 26], fill=C("P12"))
    d.ellipse([10, 12, 21, 23], fill=C(INK))
    d.ellipse([11, 13, 20, 22], fill=C("P60" if lit else "P59"))
    d.ellipse([13, 14, 16, 17], fill=C("P50" if lit else "P60"))
    if lit:
        for y in range(4, 30):
            for x in range(2, 30):
                e = ((x - 15.5) / 14) ** 2 + ((y - 17.5) / 13) ** 2
                if 0.35 < e < 1.0 and (x * 3 + y) % 5 == 0:
                    d.point((x, y), fill=C("P60"))
    return im


def radar_mast(seed=12):
    """작은 안테나 탑(1×1 발): 격자 철탑 + 접시 하나(녹) + 꼭대기 붉은 등(꺼짐)."""
    im = img(36, 84)
    d = ImageDraw.Draw(im)
    _shadow(d, 6, 30, 80)
    for t in range(0, 70, 7):
        w = 4 + t // 10
        d.line([18 - w, 78 - t, 18 + w, 78 - t - 7], fill=C("P12"))
        d.line([18 + w, 78 - t, 18 - w, 78 - t - 7], fill=C("P12"))
    d.line([10, 78, 16, 8], fill=C("P11"), width=2); d.line([26, 78, 20, 8], fill=C("P11"), width=2)
    d.ellipse([20, 22, 34, 38], fill=C(INK)); d.ellipse([21, 23, 33, 37], fill=C("P07")); d.arc([21, 23, 33, 37], 100, 220, fill=C("P25"))
    d.line([27, 30, 18, 30], fill=C("P11"))
    d.ellipse([15, 3, 21, 9], fill=C("P52"))
    return im


def fission_socket(state=""):
    """핵분열 전지 받침(1×1, 돔 R-03 안): 크림 관제망 콘솔 · 유리 칸 속 앰버 전지(M-162) · 굵은 케이블 둘. empty = 빈 칸 · 끊긴 단자."""
    im = img(36, 52)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 32, 48)
    d.rounded_rectangle([3, 18, 32, 48], 4, fill=C(INK)); d.rounded_rectangle([4, 19, 31, 47], 3, fill=C("P08"))
    d.rectangle([4, 38, 31, 41], fill=C("P61")); d.line([4, 38, 31, 38], fill=C("P62"))
    for r in (3, 2):
        d.ellipse([24 - r, 28 - r, 24 + r, 28 + r], outline=C("P61"))
    d.rounded_rectangle([7, 2, 22, 30], 3, fill=C(INK)); d.rounded_rectangle([8, 3, 21, 29], 2, fill=C("P15"))
    if state != "empty":
        d.rounded_rectangle([10, 6, 19, 27], 2, fill=C("P59"))
        d.rectangle([11, 8, 13, 25], fill=C("P60")); d.point((12, 9), fill=C("P50"))
        d.rectangle([12, 4, 17, 6], fill=C("P12"))
        put_text(im, "핵", 10, 13, "P58", 8, "Galmuri7")
    else:
        d.rectangle([10, 6, 19, 27], fill=C("P02"))
        d.line([12, 27, 14, 23], fill=C("P49")); d.line([17, 27, 16, 24], fill=C("P54"))   # 끊긴 단자 불꽃 자국
    d.line([31, 44, 35, 50], fill=C(INK), width=3); d.line([4, 44, 1, 50], fill=C(INK), width=3)
    return im


def brain4(state=""):
    import robot_sentry as RS
    return RS.brain4(state)


def chain_fence(state=""):
    """철조망 울타리 한 칸(1×1, 가로): 콘크리트 기둥 · 마름모 철망 · 윗줄 가시철사. cut = 아래쪽이 잘려 벌어진 틈(지나갈 수 있음은 맵이 정한다)."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 0, 32, 41)
    d.rectangle([0, 6, 3, 41], fill=C(INK)); d.rectangle([1, 7, 2, 40], fill=C("P06"))
    for x in range(4, 32, 4):
        for y in range(10, 40, 4):
            if state == "cut" and 14 <= x <= 26 and y >= 24:
                continue
            d.line([x, y, x + 2, y + 2], fill=C("P13")); d.line([x + 2, y, x, y + 2], fill=C("P12"))
    d.line([0, 9, 32, 9], fill=C("P12"))
    for x in range(2, 32, 6):                                                 # 가시철사
        d.line([x, 5, x + 3, 7], fill=C("P11")); d.line([x + 3, 5, x, 7], fill=C("P11"))
    d.line([0, 6, 32, 6], fill=C("P05"))
    if state == "cut":
        d.line([14, 24, 11, 31], fill=C("P13")); d.line([26, 24, 29, 32], fill=C("P13"))   # 벌어진 철망 끝
        d.line([14, 40, 12, 36], fill=C("P12")); d.line([26, 40, 28, 35], fill=C("P12"))
    return im


def w_civil_sign():
    """민원실 벽 간판(2칸 벽 소품): 2077년 청록 바탕 흰 글씨 '민원실' + 아래 붙인 종이(관제망 출력) '대기 구역 B · 미등록 아동 보호 조치'."""
    im = img(64, 34)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 61, 15], fill=C(INK)); d.rectangle([3, 3, 60, 14], fill=C("P61"))
    put_text(im, "민원실", 18, 3, "P09", 8, "Galmuri7")
    d.rectangle([12, 17, 52, 32], fill=C("P09")); d.rectangle([12, 17, 52, 18], fill=C("P59"))
    put_text(im, "대기구역B", 15, 19, "P02", 8, "Galmuri7")
    d.line([14, 30, 48, 30], fill=C("P05"))
    d.point((13, 18), fill=C("P05")); d.point((51, 18), fill=C("P05"))         # 압정
    return im


def civil_post():
    """주민센터 앞 세움 간판(바깥 소품 3칸): 쇠기둥 둘 · 청록 판 흰 글씨 '봉천동 주민센터' · 아래 크림 띠 '민원실 1층'. 녹물 자국과 총탄 구멍 하나."""
    im = img(96, 44)
    d = ImageDraw.Draw(im)
    for x in (14, 82):
        d.rectangle([x - 2, 24, x + 2, 43], fill=C(INK)); d.rectangle([x - 1, 24, x + 1, 42], fill=C("P12")); d.line([x - 1, 24, x - 1, 42], fill=C("P13"))
    d.rectangle([3, 2, 92, 27], fill=C(INK))
    d.rectangle([4, 3, 91, 26], fill=C("P61"))
    d.line([4, 3, 91, 3], fill=C("P62"))
    put_text(im, "봉천동 주민센터", 15, 4, "P09", 8, "Galmuri7")
    d.rectangle([4, 17, 91, 26], fill=C("P09")); d.line([4, 17, 91, 17], fill=C("P08"))
    put_text(im, "민원실 1층", 28, 17, "P61", 8, "Galmuri7")
    d.line([70, 18, 70, 26], fill=C("P47")); d.line([71, 20, 71, 26], fill=C("P47"))   # 녹물 줄기
    d.ellipse([84, 7, 87, 10], fill=C(INK)); d.point((85, 8), fill=C("P05"))   # 총탄 구멍
    return im


def care_cloth(seed=13):
    """각성회 정비 의식 흔적(덧그림): 접어 둔 흰 천 · 기름 깡통 · 꺼진 대기등 심지 둘."""
    im = img(32, 22)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 10), (16, 6), (22, 14), (6, 18)], fill=C("P09")); d.line([2, 10, 16, 6], fill=C("P08"))
    d.rectangle([22, 6, 28, 15], fill=C(INK)); d.rectangle([23, 7, 27, 14], fill=C("P48")); d.line([23, 9, 27, 9], fill=C("P47"))
    for x in (9, 14):
        d.rectangle([x, 17, x + 2, 20], fill=C("P59")); d.point((x + 1, 16), fill=C("P60"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_S04 = {
    "radar_dome": _r(radar_dome, 5, 3, down=-4),
    "radar_beacon": _r(radar_beacon, 0, 0, "deco"),
    "radar_mast": _r(radar_mast, 1, 1, down=-2),
    "fission_socket": _r(fission_socket, 1, 1, down=-2),
    "brain4": _r(brain4, 1, 1, down=-2),
    "chain_fence": _r(chain_fence, 1, 1, down=-2),
    "chain_fence_cut": _r(lambda: chain_fence("cut"), 0, 0, "deco"),       # 잘린 철조망(지나간다 — 진행기가 세운다)
    "w_civil_sign": _r(w_civil_sign, 2, 0, "wall", dx=0, dy=4),
    "care_cloth": _r(care_cloth, 0, 0, "deco"),
    "civil_post": _r(civil_post, 3, 1, down=-2),
}

STATES_S04 = {
    "radar_beacon": {"dim": lambda: radar_beacon("dim")},
    "fission_socket": {"empty": lambda: fission_socket("empty")},
    "brain4": {"off": lambda: brain4("off")},
    "chain_fence": {"cut": lambda: chain_fence("cut")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_s04.png"
    ims = [v["fn"]() for v in PROPS_S04.values()] + [f() for st in STATES_S04.values() for f in st.values()]
    W = sum(i.width for i in ims) + 6 * len(ims)
    Hh = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, Hh), (70, 80, 60, 255))
    x = 0
    for i in ims:
        sheet.alpha_composite(i, (x, Hh - i.height))
        x += i.width + 6
    sheet.resize((W * 2, Hh * 2), Image.NEAREST).save(out)
    print(out)
