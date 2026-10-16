"""관악 계곡 배수로 곰팡이 · S-07 배수 갱도 바깥 끝 · 봉천 배수지 소품(단계 1-11d SQ-S03 곰팡이의 근원, SD-04a §4.3 · SD-09a L-R01-02 · 08 · 10 · SD-16 아이작풍).
  w_mold_colony   암거 천장 검은 곰팡이 군락(벽 소품 3칸) — 겹친 둥근 반점 · 올리브빛 솜털 테 · 흰 포자 가루 · 늘어진 물방울 줄
                  상태 burnt(태움 — 그을음 줄 · 숯 딱지 · 재) · sprayed(약품 — 탈색 반점 · 거품) · dry1(마르는 중 — 잿빛 · 갈라짐) · dry2(거의 사라짐)
  w_mold_streak   군락에서 동쪽(볼트 갱도 쪽)으로 이어지는 검은 줄기(벽 소품 3칸) · 굵기 셋 thin/mid/thick — 갱도로 갈수록 짙다(재미 검수: '검은 길'이 물이 오는 쪽을 가리킨다)
                  상태는 군락과 같은 넷
  mold_patch      배수지 저수조 벽 곰팡이 얼룩(덧그림 2칸) · 상태 scrubbed(문질러 닦은 밝은 자국)
  intake_screen   배수지 유입관 거름망(1×1) — 땅에서 올라온 관 입 · 철망 · 검은 포자 덩어리 · 상태 clean
  sluice_gate     갱도 중간 수문(2×1) — 양옆 형강 기둥 · 위 기어 상자 · 손잡이 바퀴 · 들린 판 아래로 흐르는 물 · 상태 shut(판이 내려와 물이 고임)
  w_weld_grate    볼트 쪽 용접 창살(벽 소품 2칸) — 굵은 창살 · 덕지덕지 용접 자국 · 'S-07' 찍힌 판 · 창살 사이로 새는 물
  w_hatch_open    갱도 바깥 끝 원형 철문 안쪽(벽 소품 3칸) — 바위 속 콘크리트 테 · 옆으로 젖혀진 녹슨 문짝 · 바깥 햇빛
  vault_drain_out 계곡 바위 사이 위장된 배수 출구(바깥 2×1) — 이끼 낀 바위 덩이 · 반쯤 열린 녹슨 원형 철문 · 흘러나오는 물줄기
  rathole         벽 밑 쥐구멍(덧그림) — 갉은 자국 · 똥 · 털 뭉치(왕쥐가 시궁쥐를 부르는 자리)
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


def _blobs(seed, w, h, n):
    rnd = random.Random(seed)
    out = []
    for _ in range(n):
        r = rnd.uniform(3.0, 7.5)
        out.append((rnd.uniform(r, w - r), rnd.uniform(r * 0.8, h * 0.62), r, rnd.random()))
    return out


# ================================================================================================ 암거 천장 곰팡이 군락
def _noise(x, y, k):
    return (math.sin(x * 0.71 + k * 3.1) * math.sin(y * 0.93 - k * 1.7) + math.sin((x + y) * 0.37 + k)) * 0.5


def _field(seed, W, H, n, top=0.62):
    """번진 얼룩의 거리장: 칸마다 (가장 가까운 반점 기준 0~1+ 거리, 반점 번호). 둥근 공이 아니라 가장자리가 들쭉날쭉 퍼진 납작한 얼룩."""
    rnd = random.Random(seed)
    bl = [(rnd.uniform(4, W - 4), rnd.uniform(3, H * top), rnd.uniform(3.5, 8.0), rnd.random()) for _ in range(n)]
    out = {}
    for y in range(H):
        for x in range(W):
            best, bi = 9.0, -1
            for i, (bx, by, r, _k) in enumerate(bl):
                dd = math.hypot((x - bx) / r, (y - by) / (r * 0.8)) * (1.0 + 0.28 * _noise(x, y, i))
                if dd < best:
                    best, bi = dd, i
            out[(x, y)] = (best, bi)
    return out, bl


MOLD = {   # 속 · 몸 · 결 무늬 · 솜털 테 · 덮는 비율 · 크기
    "live": dict(core="P01", body="P02", ring="P03", rim=("P29", "P30"), cover=1.0, scale=1.0),
    "dry1": dict(core="P03", body="P04", ring="P05", rim=("P05", "P06"), cover=0.85, scale=0.9),
    "dry2": dict(core="P04", body="P05", ring="P05", rim=None, cover=0.4, scale=0.6),
    "burnt": dict(core="P01", body="P01", ring="P02", rim=("P02", "P03"), cover=1.0, scale=1.05),
    "sprayed": dict(core="P06", body="P07", ring="P08", rim=("P05", "P06"), cover=1.0, scale=0.95),
}


def _paint_mold(im, field, bl, state, seed, drip_h=0):
    m = MOLD[state]
    rnd = random.Random(seed * 3 + 1)
    W, H = im.size
    px = im.load()
    for (x, y), (dd, bi) in field.items():
        if bl[bi][3] > m["cover"]:
            continue
        dd = dd / m["scale"]
        if dd < 0.45:
            col = m["core"]
        elif dd < 1.0:
            col = m["ring"] if abs(((dd * 7.0) % 1.0) - 0.5) < 0.12 else m["body"]     # 나이테처럼 번진 결
        elif dd < 1.25 and m["rim"]:
            if (x + y) % 2 == 0 or rnd.random() < 0.25:                                # 솜털 테(성긴 점)
                col = m["rim"][(x * 7 + y) % 2]
            else:
                continue
        else:
            continue
        px[x, y] = C(col)
    d = ImageDraw.Draw(im)
    if state == "live":
        for bx, by, r, k in bl:
            for _ in range(5):                                                          # 흰 포자 가루
                d.point((bx + rnd.uniform(-r * 1.3, r * 1.3), by + rnd.uniform(-r, r)), fill=C("P07"))
        for bx, by, r, k in bl[::3]:                                                    # 늘어진 물방울 줄
            ln = int(3 + k * drip_h)
            y0 = int(by + r * 0.8)
            if y0 + ln < H - 1:
                d.line([bx, y0, bx, y0 + ln], fill=C("P02"))
                d.point((bx, y0 + ln + 1), fill=C("P36"))
    elif state == "burnt":
        for bx, by, r, k in bl:
            for j in range(3):                                                          # 위로 번진 그을음 줄
                sx = bx - r + j * r
                d.line([sx, by - r * 0.6, sx + rnd.uniform(-2, 2), max(1, by - r - 5 - k * 6)], fill=C("P02"))
        for _ in range(20):                                                             # 떨어진 재
            d.point((rnd.uniform(3, W - 3), rnd.uniform(H * 0.6, H - 2)), fill=C(rnd.choice(["P05", "P06", "P07"])))
        for bx, by, r, _k in bl[1:3]:                                                   # 아직 남은 불씨
            d.point((bx + 1, by), fill=C("P54")); d.point((bx + 2, by), fill=C("P27"))
        for (x, y), (dd, bi) in field.items():                                          # 그을린 가장자리: 숯 테두리 바깥에 주황 잔불 · 갈색 탄 자국
            if bl[bi][3] <= m["cover"] and 1.02 < dd / m["scale"] < 1.22:
                h = (x * 13 + y * 7 + bi) % 9
                if h == 0:
                    px[x, y] = C("P54")
                elif h in (1, 4):
                    px[x, y] = C("P27") if (x + y) % 3 else C("P28")
    elif state == "sprayed":
        for bx, by, r, k in bl:
            d.line([bx - r * 0.3, by + r * 0.7, bx - r * 0.3, min(H - 2, by + r + 3 + k * 6)], fill=C("P06"))   # 흘러내린 약품 줄
            for _ in range(3):
                d.point((bx + rnd.uniform(-r, r), by + rnd.uniform(-r * 0.6, r * 0.6)), fill=C("P09"))    # 거품
    elif state == "dry1":
        for bx, by, r, k in bl:
            if k <= m["cover"]:
                d.line([bx - r * 0.6, by - 1, bx + r * 0.4, by + r * 0.3], fill=C("P02"))  # 갈라짐
    return im


def w_mold_colony(state="live", seed=31):
    """군락(벽 소품 3칸, 96×40): 같은 얼룩 자리를 상태마다 다른 재질로 — 살아 있는(검정 · 나이테 결 · 올리브 솜털 테 · 포자 가루 · 물방울 줄) ·
    태운(숯 · 그을음 줄 · 재 · 불씨) · 약품(탈색 · 거품 · 흘러내린 줄) · 마르는(잿빛 · 갈라짐) · 거의 사라진(옅은 자국)."""
    im = img(96, 40)
    field, bl = _field(seed, 96, 40, 13)
    return _paint_mold(im, field, bl, state, seed, drip_h=10)


STREAK = {"thin": (5, 0.55, 0.62), "mid": (8, 0.75, 0.8), "thick": (12, 1.0, 1.0)}   # 반점 수 · 크기 · 위아래 퍼짐


def w_mold_streak(width="mid", state="live", seed=0):
    """군락에서 갱도 쪽으로 이어지는 줄기(벽 소품 3칸, 96×40): 물때 높이를 따라 가로로 늘어선 납작한 얼룩 띠.
    굵기마다 반점 수 · 크기 · 위아래 퍼짐이 다르고, 같은 상태 재질(_paint_mold)을 쓴다 — 군락과 함께 태우고 약을 치고 마른다."""
    n, sc, spread = STREAK[width]
    W, H = 96, 40
    rnd = random.Random(seed * 17 + n)
    band = H * 0.32
    bl = []
    for i in range(n):                                                                  # 가로로 줄 선 반점(물때 줄을 따라)
        r = rnd.uniform(3.0, 6.5) * sc
        bx = (i + 0.5) * W / n + rnd.uniform(-3, 3)
        by = band + rnd.uniform(-5, 5) * spread
        bl.append((min(W - 3, max(3, bx)), by, r, rnd.random() * 0.9))
    field = {}
    for y in range(H):
        for x in range(W):
            best, bi = 9.0, -1
            for i, (bx, by, r, _k) in enumerate(bl):
                dd = math.hypot((x - bx) / (r * 1.6), (y - by) / (r * 0.7)) * (1.0 + 0.3 * _noise(x, y, i + seed))
                if dd < best:
                    best, bi = dd, i
            field[(x, y)] = (best, bi)
    return _paint_mold(img(W, H), field, bl, state, seed + n, drip_h=int(6 * sc))


def mold_patch(state="live", seed=5):
    """배수지 저수조 벽 곰팡이 얼룩(덧그림 2칸, 64×28). scrubbed: 문질러 닦은 밝은 자국 · 솔 자국 · 남은 점."""
    im = img(64, 28)
    if state == "scrubbed":
        d = ImageDraw.Draw(im)
        rnd = random.Random(seed)
        d.rounded_rectangle([6, 6, 58, 22], 5, fill=C("P07"))
        for x in range(9, 56, 3):
            d.line([x, 8, x + 2, 20], fill=C("P08"))
        for _ in range(6):
            d.point((rnd.randint(8, 56), rnd.randint(8, 20)), fill=C("P05"))
        return im
    field, bl = _field(seed, 64, 28, 8, top=0.75)
    return _paint_mold(im, field, bl, "live", seed, drip_h=4)


def intake_screen(state="live"):
    """유입관 거름망(1×1, 32×44): 땅에서 올라온 굵은 관 · 콘크리트 받침 · 관 입의 둥근 철망 · 검은 포자 덩어리(clean이면 철망이 비었다)."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 34, 27, 42], fill=C(INK)); d.rectangle([5, 34, 26, 41], fill=C("P05")); d.line([5, 34, 26, 34], fill=C("P07"))   # 받침
    d.rectangle([9, 14, 22, 35], fill=C(INK)); d.rectangle([10, 14, 21, 35], fill=C("P12")); d.line([10, 14, 10, 35], fill=C("P14"))   # 관
    d.line([11, 24, 20, 24], fill=C("P11"))
    d.ellipse([5, 4, 26, 20], fill=C(INK)); d.ellipse([6, 5, 25, 19], fill=C("P12"))                        # 관 입 테
    d.ellipse([8, 7, 23, 17], fill=C("P02"))
    for x in range(9, 23, 3):                                                                               # 철망
        d.line([x, 7, x, 17], fill=C("P06"))
    for y in range(8, 17, 3):
        d.line([8, y, 23, y], fill=C("P06"))
    if state != "clean":
        for x, y in ((11, 10), (16, 13), (20, 9), (13, 15)):                                                 # 포자 덩어리
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=C("P01")); d.point((x - 1, y - 1), fill=C("P29"))
        d.line([12, 20, 12, 30], fill=C("P02")); d.line([19, 20, 19, 26], fill=C("P02"))                    # 관 몸에 흘러내린 검은 줄
        d.point((12, 31), fill=C("P29"))
    else:
        d.line([7, 4, 13, 3], fill=C("P08"))                                                                # 닦은 테의 반짝임
    return im


def sluice_gate(state="open"):
    """갱도 중간 수문(2×1, 64×72): 양옆 형강 기둥 · 위 기어 상자와 손잡이 바퀴 · 판. open = 판이 들려 아래로 물이 흐른다, shut = 판이 바닥까지 · 물이 고였다."""
    im = img(64, 72)
    d = ImageDraw.Draw(im)
    for x in (6, 52):                                                                                       # 형강 기둥
        d.rectangle([x, 14, x + 6, 70], fill=C(INK)); d.rectangle([x + 1, 14, x + 5, 69], fill=C("P12")); d.line([x + 1, 14, x + 1, 69], fill=C("P14"))
        for y in range(20, 68, 9):
            d.point((x + 3, y), fill=C("P10"))                                                              # 리벳
    d.rectangle([4, 8, 59, 18], fill=C(INK)); d.rectangle([5, 9, 58, 17], fill=C("P24")); d.line([5, 9, 58, 9], fill=C("P26"))   # 기어 상자(녹)
    d.line([20, 10, 20, 16], fill=C("P23")); d.line([44, 10, 44, 16], fill=C("P23"))
    cx, cy = 32, 6                                                                                          # 손잡이 바퀴
    d.ellipse([cx - 9, cy - 5, cx + 9, cy + 5], outline=C(INK), width=3)
    d.ellipse([cx - 8, cy - 4, cx + 8, cy + 4], outline=C("P53"), width=1)
    d.line([cx - 8, cy, cx + 8, cy], fill=C("P53")); d.line([cx, cy - 4, cx, cy + 4], fill=C("P53"))
    d.ellipse([cx - 2, cy - 1, cx + 2, cy + 2], fill=C("P52"))
    top = 52 if state == "shut" else 22                                                                    # 판 윗단
    bot = 70 if state == "shut" else 44
    d.rectangle([12, top, 52, bot], fill=C(INK)); d.rectangle([13, top + 1, 51, bot - 1], fill=C("P11"))
    for x in range(16, 50, 8):
        d.line([x, top + 2, x, bot - 2], fill=C("P12"))
    d.line([13, top + 1, 51, top + 1], fill=C("P13"))
    d.line([13, bot - 3, 51, bot - 3], fill=C("P02"))                                                       # 물때 줄
    d.line([14, top + 3, 28, top + 3], fill=C("P29"))                                                       # 판에 묻은 곰팡이 줄
    if state == "shut":
        d.rectangle([13, top - 4, 51, top - 1], fill=C("P35")); d.line([13, top - 4, 51, top - 4], fill=C("P37"))   # 판 위로 고인 물
        d.line([30, top - 3, 34, top - 3], fill=C("P09"))
    else:
        for x in range(15, 50, 5):                                                                          # 판 아래로 흘러가는 물줄기
            d.line([x, 46, x + 1, 69], fill=C("P36"))
            d.point((x + 1, 60 + (x % 7)), fill=C("P37"))
    return im


def w_weld_grate():
    """볼트 쪽 용접 창살(벽 소품 2칸, 64×56): 굵은 창살 여섯 · 가로 띠 둘 · 덕지덕지 용접 자국 · 'S-07' 찍힌 판 · 창살 사이로 새는 물(물만 지나간다)."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 61, 54], fill=C(INK)); d.rectangle([4, 4, 59, 54], fill=C("P02"))                     # 너머의 어둠
    for y in (12, 34):
        d.rectangle([3, y, 60, y + 4], fill=C(INK)); d.rectangle([4, y + 1, 59, y + 3], fill=C("P12")); d.line([4, y + 1, 59, y + 1], fill=C("P13"))
    for i, x in enumerate(range(8, 60, 9)):
        d.rectangle([x, 3, x + 4, 54], fill=C(INK)); d.rectangle([x + 1, 3, x + 3, 54], fill=C("P11")); d.line([x + 1, 3, x + 1, 54], fill=C("P13"))
        for y in (12, 34):                                                                                  # 용접 자국(울퉁불퉁한 덩이)
            d.ellipse([x - 1, y - 1, x + 5, y + 5], fill=C("P24")); d.point((x + 1, y), fill=C("P26")); d.point((x + 3, y + 3), fill=C("P23"))
    d.rectangle([18, 19, 45, 30], fill=C(INK)); d.rectangle([19, 20, 44, 29], fill=C("P47"))
    put_text(im, "S-07", 21, 20, "P01", 8, "Galmuri7")
    for x in (14, 31, 49):                                                                                  # 새는 물
        d.line([x, 42, x, 54], fill=C("P36")); d.point((x, 50), fill=C("P37"))
    return im


def w_hatch_open():
    """갱도 바깥 끝 원형 철문 안쪽(벽 소품 3칸, 96×64): 바위 속 콘크리트 테 · 열린 둥근 구멍 너머 햇빛 · 옆으로 젖혀진 녹슨 문짝(바퀴 손잡이)."""
    im = img(96, 64)
    d = ImageDraw.Draw(im)
    cx, cy, r = 44, 34, 24
    d.ellipse([cx - r - 4, cy - r - 4, cx + r + 4, cy + r + 4], fill=C(INK))
    d.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], fill=C("P06"))                             # 콘크리트 테
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C("P09"))                                             # 햇빛
    d.ellipse([cx - r + 4, cy - r + 4, cx + r - 4, cy + r - 4], fill=C("P50"))
    d.ellipse([cx - r + 10, cy - r + 6, cx + r - 2, cy + r - 12], fill=C("P09"))
    d.line([cx - r + 2, cy + 10, cx + r - 2, cy + 6], fill=C("P31"))                                       # 바깥 풀 그림자
    d.line([cx - r + 4, cy + 14, cx + r - 6, cy + 12], fill=C("P30"))
    for a in range(0, 360, 30):                                                                             # 테 볼트
        t = math.radians(a)
        d.point((cx + math.cos(t) * (r + 1.5), cy + math.sin(t) * (r + 1.5)), fill=C("P04"))
    dx = cx + r + 2                                                                                         # 젖혀진 문짝(옆에서 본 두께)
    d.polygon([(dx, cy - r), (dx + 14, cy - r + 6), (dx + 14, cy + r - 6), (dx, cy + r)], fill=C(INK))
    d.polygon([(dx + 1, cy - r + 2), (dx + 13, cy - r + 7), (dx + 13, cy + r - 7), (dx + 1, cy + r - 2)], fill=C("P24"))
    d.line([dx + 2, cy - r + 3, dx + 2, cy + r - 3], fill=C("P26"))
    d.ellipse([dx + 4, cy - 5, dx + 11, cy + 5], outline=C("P23"), width=2)                                 # 손잡이 바퀴
    for y in range(cy - r + 8, cy + r - 6, 7):
        d.point((dx + 7, y), fill=C("P25"))
    d.line([cx - 6, cy + r + 2, cx + 6, cy + r + 2], fill=C("P36"))                                         # 문턱의 물
    return im


def vault_drain_out():
    """계곡 바위 사이 배수 출구(바깥 2×1, 64×52): 이끼 낀 바위 덩이(위장) · 반쯤 열린 녹슨 원형 철문 · 흘러나오는 물줄기 · 표지 '외부 개방 금지'."""
    im = img(64, 52)
    d = ImageDraw.Draw(im)
    rnd = random.Random(19)
    d.polygon([(2, 46), (4, 18), (14, 6), (34, 2), (52, 8), (62, 22), (62, 46)], fill=C(INK))              # 바위 덩이
    d.polygon([(4, 45), (6, 19), (15, 8), (34, 4), (51, 10), (60, 23), (60, 45)], fill=C("P05"))
    d.polygon([(6, 19), (15, 8), (34, 4), (30, 14), (12, 22)], fill=C("P06"))                              # 볕 드는 윗면
    for _ in range(14):                                                                                     # 이끼
        x, y = rnd.randint(8, 54), rnd.randint(8, 22)
        d.ellipse([x, y, x + rnd.randint(2, 5), y + 2], fill=C(rnd.choice(["P29", "P30", "P31"])))
    cx, cy, r = 30, 32, 11                                                                                  # 원형 철문 구멍
    d.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], fill=C(INK))
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=C("P24"))
    d.ellipse([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], fill=C("P01"))
    d.polygon([(cx + r - 1, cy - r + 2), (cx + r + 7, cy - r + 6), (cx + r + 7, cy + r - 4), (cx + r - 1, cy + r - 2)], fill=C("P23"))   # 반쯤 열린 문짝
    d.line([cx + r, cy - r + 3, cx + r, cy + r - 3], fill=C("P26"))
    d.ellipse([cx + r + 1, cy - 3, cx + r + 6, cy + 3], outline=C("P25"))
    for x in range(cx - 6, cx + 7, 3):                                                                      # 흘러나오는 물
        d.line([x, cy + r - 2, x + rnd.randint(-1, 1), 50], fill=C("P36"))
    d.line([cx - 9, 49, cx + 10, 49], fill=C("P37"))
    d.rectangle([6, 34, 18, 40], fill=C(INK)); d.rectangle([7, 35, 17, 39], fill=C("P49"))                  # 녹슨 경고판
    d.line([8, 37, 16, 37], fill=C("P53"))
    return im


def rathole(seed=3):
    """벽 밑 쥐구멍(덧그림, 32×16): 반달 구멍 · 갉은 테 · 똥 · 털 뭉치."""
    im = img(32, 16)
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    d.pieslice([6, 2, 26, 22], 180, 360, fill=C(INK))
    d.pieslice([8, 4, 24, 20], 180, 360, fill=C("P01"))
    for a in range(190, 350, 25):                                                                           # 갉은 자국
        t = math.radians(a)
        d.point((16 + math.cos(t) * 10, 12 + math.sin(t) * 10), fill=C("P06"))
    for _ in range(5):
        x = rnd.randint(4, 28)
        d.point((x, rnd.randint(12, 14)), fill=C("P17"))
    d.ellipse([24, 10, 28, 13], fill=C("P04"))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_S03 = {
    "w_mold_colony": _r(w_mold_colony, 3, 0, "wall", dx=0, dy=6),
    "w_mold_streak": _r(lambda: w_mold_streak("thin", seed=3), 3, 0, "wall", dx=0, dy=6),
    "w_mold_streak2": _r(lambda: w_mold_streak("mid", seed=5), 3, 0, "wall", dx=0, dy=6),
    "w_mold_streak3": _r(lambda: w_mold_streak("thick", seed=7), 3, 0, "wall", dx=0, dy=6),
    "mold_patch": _r(mold_patch, 0, 0, "deco"),
    "intake_screen": _r(intake_screen, 1, 1, down=-2),
    "sluice_gate": _r(sluice_gate, 2, 1, down=-2),
    "w_weld_grate": _r(w_weld_grate, 2, 0, "wall", dx=0, dy=2),
    "w_hatch_open": _r(w_hatch_open, 3, 0, "wall", dx=0, dy=2),
    "vault_drain_out": _r(vault_drain_out, 2, 1, down=-2),
    "rathole": _r(rathole, 0, 0, "deco"),
}

STATES_S03 = {
    "w_mold_colony": {s: (lambda s=s: w_mold_colony(s)) for s in ("burnt", "sprayed", "dry1", "dry2")},
    "w_mold_streak": {s: (lambda s=s: w_mold_streak("thin", s, seed=3)) for s in ("burnt", "sprayed", "dry1", "dry2")},
    "w_mold_streak2": {s: (lambda s=s: w_mold_streak("mid", s, seed=5)) for s in ("burnt", "sprayed", "dry1", "dry2")},
    "w_mold_streak3": {s: (lambda s=s: w_mold_streak("thick", s, seed=7)) for s in ("burnt", "sprayed", "dry1", "dry2")},
    "mold_patch": {"scrubbed": lambda: mold_patch("scrubbed")},
    "intake_screen": {"clean": lambda: intake_screen("clean")},
    "sluice_gate": {"shut": lambda: sluice_gate("shut")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_s03.png"
    ims = [v["fn"]() for v in PROPS_S03.values()] + [f() for st in STATES_S03.values() for f in st.values()]
    W = sum(i.width for i in ims) + 6 * len(ims)
    Hh = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, Hh + 4), C("P04"))
    x = 2
    for i in ims:
        sheet.alpha_composite(i, (x, 2))
        x += i.width + 6
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)
