"""월드 건물 타일(단계 1-1, SD-16 §3.1·§6.3·§6.5·§6.6): 심리스 월드의 건물 1만여 채를 타일로 조립한다.
봉천(0-10)은 맵마다 구조물 한 장을 구웠지만 월드 전체(2120×1720타일)를 그렇게 구우면 수백 MB라, 월드는 타일로 짓는다.

규칙(SD-16):
  · 3/4 시점: 남쪽 정면만 그린다. 1층 = 정면 1타일, 4층 이상은 '저층부 + 반복 모듈 + 옥상'으로 압축(정면 최대 6타일).
  · 동·서 측면은 2~4px 띠(정면 양 끝 열의 밝은 1px · 어두운 2px), 북쪽 면은 그리지 않는다.
  · 벽 정면 아래 바닥 접선만 1px 먹선. 빛은 왼쪽 위.
  · 아파트 = 저층부 2(필로티·현관) + 중층 모듈(창 + 발코니 난간) + 옥상(냉각 돔·물탱크). 창 4종(꺼짐·깨짐·판자·불).
  · 상가·학원가 = 층마다 가로 간판 띠. 업무 = 금속 패널 + 띠창. 관청 = 석조 열주 + 앰버 경광등(정면마다 1개 이상).
이음매 규칙: 칸 경계를 넘는 무늬는 32px 주기(벽돌 8×4, 슬래브, 갓돌, 간판 띠)만 쓰고, 얼룩·균열·녹물은 칸 안에서 끝낸다.
그래서 같은 행·열 종류의 변형끼리 아무 순서로 붙여도 이음매가 없다.

타일 이름: '<스킨>:<부위>' — 부위는 정면 '<행>_<열><변형>'(행 top·mid·low·bot·solo, 열 l·m·r), 옥상 'rf_<자리><변형>',
덧층(투명) 'rd_<이름>'. 스킨 목록·부위 목록은 skins()가 돌려주고 굽기(tools/pipeline/world_bake.py)가 그 표대로 고른다.
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import struct_r01 as S

T = 32
C = S.C
INK = "P01"
step_px, streak, hsh = S.step_px, S.streak, S.hsh

# 벽 재질: 바탕 · 밝음 · 어두움 · 무늬(brick 벽돌 8×4 / tile 4px 격자 / flat 미장 / panel 콘크리트 판 / stone 석재 블록 /
#          rib 골강판 / glass 유리 커튼월)
WALLS = {
    "brick": ("P25", "P26", "P24", "brick"),
    "brick_dk": ("P24", "P25", "P23", "brick"),
    "plaster": ("P21", "P22", "P20", "flat"),
    "tile": ("P08", "P09", "P07", "tile"),
    "mint": ("P14", "P15", "P13", "flat"),
    "apt": ("P08", "P09", "P07", "panel"),
    "apt_dk": ("P07", "P08", "P06", "panel"),
    "stone": ("P07", "P08", "P06", "stone"),
    "steel": ("P05", "P06", "P04", "rib"),
    "rust": ("P25", "P26", "P24", "rib"),
    "olive": ("P30", "P31", "P29", "panel"),
    "glass": ("P12", "P13", "P11", "glass"),
}


def new(fill=None):
    return Image.new("RGBA", (T, T), C(fill) if fill else (0, 0, 0, 0))


def fill_wall(img, wall, rnd):
    """칸 하나를 벽 재질로 채운다(칸 경계를 넘는 무늬는 32px 주기만)."""
    base, hi, lo, kind = WALLS[wall]
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=C(base))
    if kind == "brick":
        joint = "P05" if wall == "brick" else "P04"
        d.rectangle([0, 0, T - 1, T - 1], fill=C(joint))
        for row, y in enumerate(range(0, T, 4)):
            off = 4 if row % 2 else 0
            for x in range(-8 + off, T, 8):
                r = rnd.random()
                b, h_, l_ = (base, hi, lo) if r < 0.82 else ((lo, base, S.P_dn(lo)) if r < 0.93 else (hi, S.P_up(hi), base))
                a0, a1 = max(0, x), min(T - 1, x + 6)
                if a1 < a0:
                    continue
                d.rectangle([a0, y, a1, y + 2], fill=C(b))
                d.line([a0, y, a1, y], fill=C(h_))
                d.line([a0, y + 2, a1, y + 2], fill=C(l_))
    elif kind == "tile":
        for y in range(0, T, 4):
            d.line([0, y, T - 1, y], fill=C(lo))
        for x in range(0, T, 4):
            d.line([x, 0, x, T - 1], fill=C(lo))
        for _ in range(rnd.randint(0, 3)):                               # 떨어져 나간 타일(시멘트 바탕)
            tx, ty = rnd.randrange(1, 7) * 4, rnd.randrange(1, 7) * 4
            d.rectangle([tx + 1, ty + 1, tx + 3, ty + 3], fill=C("P06"))
    elif kind == "stone":                                                # 석재 블록 16×8 엇갈림 + 블록마다 한 단 차이
        for row, y in enumerate(range(0, T, 8)):
            off = 8 if row % 2 else 0
            for x in range(-16 + off, T, 16):
                a0, a1 = max(0, x), min(T - 1, x + 15)
                if a1 < a0:
                    continue
                if rnd.random() < 0.25:
                    d.rectangle([a0, y, a1, y + 7], fill=C(lo if rnd.random() < 0.6 else hi))
                d.line([a0, y, a1, y], fill=C(hi))
                d.line([a0, y + 7, a1, y + 7], fill=C(S.P_dn(lo)))
                if x + 15 < T:
                    d.line([x + 15, y, x + 15, y + 7], fill=C(S.P_dn(lo)))
    elif kind == "rib":                                                  # 골강판: 4px마다 골(밝은 등 · 어두운 골)
        for x in range(0, T, 4):
            d.line([x, 0, x, T - 1], fill=C(hi))
            d.line([x + 2, 0, x + 2, T - 1], fill=C(lo))
            d.line([x + 3, 0, x + 3, T - 1], fill=C(S.P_dn(lo)))
    elif kind == "panel":                                                # 콘크리트 판: 16px 세로 이음매 + 판마다 얼룩
        for x in (15, 31):
            d.line([x, 0, x, T - 1], fill=C(lo))
        for x in (0, 16):
            d.line([x, 0, x, T - 1], fill=C(hi))
    elif kind == "glass":                                                # 유리 커튼월: 8px 멀리언, 칸마다 하늘 반사
        for x in range(0, T, 8):
            d.line([x, 0, x, T - 1], fill=C("P05"))
            d.line([x + 1, 0, x + 1, T - 1], fill=C("P06"))
        for x0 in range(2, T, 8):
            k = rnd.random()
            if k < 0.3:
                d.rectangle([x0, 0, x0 + 5, T - 1], fill=C("P13"))
            elif k < 0.45:
                d.rectangle([x0, 0, x0 + 5, T - 1], fill=C("P11"))
            d.line([x0 + 1, 6, x0 + 4, 3], fill=C("P14")) if rnd.random() < 0.5 else None
    if kind in ("flat", "panel"):                                        # 큰 얼룩(칸 안에서 끝남)
        for _ in range(rnd.randint(0, 2)):
            cx, cy = rnd.randint(8, 23), rnd.randint(8, 23)
            rx, ry = rnd.randint(3, 6), rnd.randint(2, 4)
            for y in range(cy - ry, cy + ry + 1):
                for x in range(cx - rx, cx + rx + 1):
                    if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                        img.putpixel((x, y), C(lo))


def crack(img, rnd, n=1, base="P07"):
    for _ in range(n):
        cx, cy = rnd.randint(4, 27), rnd.randint(4, 20)
        for i in range(rnd.randint(4, 9)):
            if 2 <= cx <= 29 and 1 <= cy <= 29:
                step_px(img, cx, cy, -2)
            cx += rnd.choice((-1, 0, 1))
            cy += 1


def ends(img, col, top_y=0):
    """정면 양 끝 열: 왼쪽 밝은 1px + 먹선, 오른쪽 어두운 2px + 먹선(동·서 측면 띠, SD-16 §3.1)."""
    d = ImageDraw.Draw(img)
    for y in range(top_y, T):
        if col == "l":
            step_px(img, 1, y, 1)
        elif col == "r":
            step_px(img, T - 2, y, -1)
            step_px(img, T - 3, y, -1)
    if col == "l":
        d.line([0, 0, 0, T - 1], fill=C(INK))
    elif col == "r":
        d.line([T - 1, 0, T - 1, T - 1], fill=C(INK))


def cap(img, rnd, col="P08", hi="P09", lo="P06", h=5):
    """갓돌(옥상 난간 앞면): 위 밝은 선 · 아래 어두운 선 · 먹선, 그 아래 검은 물때."""
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, h], fill=C(col))
    d.line([0, 0, T - 1, 0], fill=C(hi))
    d.line([0, h, T - 1, h], fill=C(lo))
    d.line([0, h + 1, T - 1, h + 1], fill=C(INK))
    for _ in range(rnd.randint(0, 2)):
        streak(img, rnd.randint(3, 28), h + 2, rnd.randint(4, 12), -1, rnd)


def slabs(img, above, below, wall):
    """층 사이 슬래브 띠: 위 칸 아래 2줄 + 아래 칸 위 2줄(32px 주기로 이어진다)."""
    d = ImageDraw.Draw(img)
    lo = WALLS[wall][2]
    if below:
        d.line([0, T - 2, T - 1, T - 2], fill=C("P08"))
        d.line([0, T - 1, T - 1, T - 1], fill=C("P07"))
    if above:
        d.line([0, 0, T - 1, 0], fill=C("P07"))
        d.line([0, 1, T - 1, 1], fill=C(S.P_dn(lo)) if WALLS[wall][3] != "brick" else C("P23"))


def grime(img, rnd, wear=1.0):
    """아래 때 띠·물튐·이끼 + 바닥 접선 먹선(SD-16 §3.8)."""
    for x in range(T):
        for k in range(3):
            if (x * 7 + k * 3) % 5 != 0 or k == 0:
                step_px(img, x, T - 1 - k, -1)
        if rnd.random() < 0.06 * wear:
            for k in range(rnd.randint(1, 3)):
                img.putpixel((x, T - 2 - k), C(rnd.choice(["P29", "P30"])))
    ImageDraw.Draw(img).line([0, T - 1, T - 1, T - 1], fill=C(INK))


WIN_KINDS = {"villa": ["glass", "glass", "glass", "curtain", "laundry", "plant", "dark", "board", "broken"],
             "house": ["glass", "curtain", "dark", "board", "broken"]}


# ================================================================================================ 정면 칸
def face_villa(wall, row, col, var, seed, door=None, pipe=False):
    rnd = random.Random(hsh(seed, var, ord(row[0]), ord(col)))
    img = new()
    fill_wall(img, wall, rnd)
    top, bot = row in ("top", "solo"), row in ("bot", "solo")
    slabs(img, not top, not bot, wall)
    if top:
        cap(img, rnd)
    d = ImageDraw.Draw(img)
    if door:
        S.door(img, 7, 6, 18, 25, door, rnd, num=None)
    else:
        kinds = WIN_KINDS["house" if wall in ("mint",) else "villa"]
        k = kinds[var % len(kinds)] if var < len(kinds) else rnd.choice(kinds)
        if bot and k == "laundry":
            k = "glass"
        if var == 7 and not top:                                           # 창 없는 벽(환기구)
            d.rectangle([12, 12, 19, 17], fill=C(INK))
            d.rectangle([13, 13, 18, 16], fill=C("P05"))
            d.line([13, 14, 18, 14], fill=C("P03"))
        else:
            wy = 9 if top else 6
            S.window(img, 7, wy, 18, 14 if top else 16, k, rnd)
            if rnd.random() < 0.5:
                streak(img, rnd.randint(8, 23), wy + 19, rnd.randint(3, 7), -1, rnd)
    if pipe:                                                              # 노란 가스관(빌라 외벽의 상징), 1층에 계량기
        S.gas_pipe(img, 28, 7 if top else 0, T - 1, meter_y=14 if bot else None)
    crack(img, rnd, rnd.randint(0, 1))
    if bot:
        grime(img, rnd)
    ends(img, col, 7 if top else 0)
    return img


def face_apt(wall, row, col, var, seed, brand="P45", door=None):
    """판상형 아파트: 중층 모듈 = 창 + 발코니 난간, 저층부 = 필로티(기둥·어둠) + 현관(등록 단말기)."""
    rnd = random.Random(hsh(seed, var, ord(row[0]), ord(col), 5))
    img = new()
    fill_wall(img, wall, rnd)
    d = ImageDraw.Draw(img)
    if row == "bot":                                                      # 필로티: 기둥 사이 어둠, 끝 열은 벽
        d.rectangle([0, 0, T - 1, 3], fill=C("P07"))
        d.line([0, 3, T - 1, 3], fill=C("P05"))
        d.line([0, 4, T - 1, 4], fill=C(INK))
        if door == "entry":                                               # 동 현관: 유리문 + 등록 단말기(SD-16 §5.4)
            d.rectangle([4, 5, 27, T - 1], fill=C("P02"))
            d.rectangle([7, 9, 24, T - 1], fill=C(INK))
            d.rectangle([8, 10, 23, T - 1], fill=C("P11"))
            d.rectangle([8, 10, 23, 12], fill=C("P12"))
            d.line([15, 10, 15, T - 1], fill=C("P06"))
            d.rectangle([26, 14, 29, 20], fill=C(INK))
            d.rectangle([27, 15, 28, 17], fill=C("P56"))
            d.rectangle([3, 5, 28, 7], fill=C(brand))                       # 현관 위 브랜드 띠
        elif col == "m":
            d.rectangle([0, 5, T - 1, T - 1], fill=C("P02"))
            d.rectangle([0, 5, T - 1, 9], fill=C("P01"))                    # 필로티 천장 그늘
            for x in (0,):
                d.rectangle([x, 5, x + 6, T - 1], fill=C("P06"))            # 기둥
                d.line([x, 5, x, T - 1], fill=C("P08"))
                d.line([x + 6, 5, x + 6, T - 1], fill=C("P04"))
            if rnd.random() < 0.5:                                          # 필로티 안 잔해
                d.rectangle([14, 26, 19, 29], fill=C("P04"))
                d.line([14, 26, 19, 26], fill=C("P05"))
        grime(img, rnd)
        ends(img, col)
        return img
    top = row == "top"
    slabs(img, not top, True, wall)
    if top:
        cap(img, rnd, h=4)
        d.rectangle([0, 6, T - 1, 8], fill=C(brand))                        # 브랜드 띠(단지마다 색)
        d.line([0, 9, T - 1, 9], fill=C(S.P_dn(brand)))
    if row == "low":
        d.rectangle([0, T - 4, T - 1, T - 3], fill=C(brand))
    wy = 12 if top else 5
    kinds = ["dark", "dark", "dark", "broken", "board", "dark", "broken", "dark"]
    k = kinds[var % len(kinds)]
    d.rectangle([4, wy - 1, 27, wy + 16], fill=C(INK))                       # 거실 큰 창(난간 뒤)
    if k == "dark":
        d.rectangle([5, wy, 26, wy + 15], fill=C("P11"))
        d.rectangle([5, wy, 26, wy + 2], fill=C("P12"))
        d.line([15, wy, 15, wy + 15], fill=C("P06"))
        d.line([8, wy + 9, 12, wy + 5], fill=C("P13"))
    elif k == "broken":
        d.rectangle([5, wy, 26, wy + 15], fill=C("P01"))
        d.polygon([(5, wy), (11, wy), (8, wy + 4), (10, wy + 8), (5, wy + 6)], fill=C("P11"))
        d.polygon([(26, wy + 15), (20, wy + 15), (24, wy + 10)], fill=C("P11"))
    else:
        d.rectangle([5, wy, 26, wy + 15], fill=C("P02"))
        for j, yy in enumerate(range(wy, wy + 15, 4)):
            d.rectangle([4, yy, 27, yy + 2], fill=C(["P19", "P18", "P20"][j % 3]))
            d.line([4, yy + 2, 27, yy + 2], fill=C("P17"))
    by = wy + 9                                                           # 발코니 난간: 위 레일 + 살
    d.rectangle([2, by, 29, by + 7], fill=C(WALLS[wall][0]))
    d.line([2, by, 29, by], fill=C("P09"))
    d.line([2, by + 1, 29, by + 1], fill=C("P05"))
    for x in range(4, 29, 3):
        d.line([x, by + 2, x, by + 6], fill=C("P05"))
    d.line([2, by + 7, 29, by + 7], fill=C(INK))
    if var % 3 == 1:                                                       # 난간에 넌 빨래·화분
        for j, colr in enumerate(rnd.sample(["P26", "P45", "P09", "P49", "P36"], 2)):
            xx = 6 + j * 12 + rnd.randint(0, 4)
            d.rectangle([xx, by - 3, xx + 4, by + 4], fill=C(colr))
            d.line([xx, by + 5, xx + 4, by + 5], fill=C(INK))
    streak(img, rnd.randint(6, 25), by + 8, rnd.randint(2, 5), -1, rnd)
    ends(img, col, 6 if top else 0)
    return img


SIGN_COLS = [("P45", "P46", "P09"), ("P53", "P54", "P09"), ("P48", "P49", "P02"), ("P36", "P37", "P09"), ("P09", "P08", "P53")]


def face_shop(wall, row, col, var, seed, sign=0, front="glass"):
    """상가·학원가: 층마다 가로 간판 띠(바랜 판, 글자 흔적) + 넓은 유리창. 1층 = 진열창·셔터."""
    rnd = random.Random(hsh(seed, var, ord(row[0]), ord(col), sign, 9))
    img = new()
    fill_wall(img, wall, rnd)
    d = ImageDraw.Draw(img)
    top, bot = row in ("top", "solo"), row in ("bot", "solo")
    slabs(img, not top, not bot, wall)
    y0 = 0
    if top:
        cap(img, rnd, h=3)
        y0 = 5
    if not bot or row == "solo":                                           # 간판 띠: 칸 사이로 이어지고 끝 열에서 닫힌다
        bg, hi, fg = SIGN_COLS[sign % len(SIGN_COLS)]
        sy0, sy1 = y0 + 2, y0 + 10
        x0 = 2 if col == "l" else 0
        x1 = T - 3 if col == "r" else T - 1
        d.rectangle([x0, sy0 - 1, x1, sy1 + 1], fill=C(INK))
        d.rectangle([x0 + (1 if col == "l" else 0), sy0, x1 - (1 if col == "r" else 0), sy1], fill=C(bg))
        d.line([x0, sy0, x1, sy0], fill=C(hi))
        if var % 2 == 0:                                                   # 바랜 글자 흔적(읽히지 않는 덩어리 — 실제 글자는 장소 간판 소품)
            for gx in range(x0 + 4, x1 - 5, 8):
                for k in range(rnd.randint(3, 6)):
                    px, py = gx + rnd.randint(0, 5), sy0 + 2 + rnd.randint(0, 5)
                    if rnd.random() < 0.7:
                        img.putpixel((px, py), C(fg))
        for _ in range(3):
            step_px(img, rnd.randint(x0 + 1, x1 - 1), rnd.randint(sy0, sy1), -1)
        y0 = sy1 + 3
    if not bot:                                                            # 위층: 넓은 유리창(학원 교실)
        wy0, wy1 = y0 + 1, T - 5
        d.rectangle([3, wy0 - 1, 28, wy1 + 1], fill=C(INK))
        k = var % 4
        d.rectangle([4, wy0, 27, wy1], fill=C("P11" if k != 2 else "P01"))
        if k != 2:
            d.rectangle([4, wy0, 27, wy0 + 2], fill=C("P12"))
            d.line([6, wy1 - 1, 10, wy1 - 5], fill=C("P13"))
        else:
            d.polygon([(4, wy0), (10, wy0), (6, wy0 + 5)], fill=C("P11"))
        d.line([15, wy0, 15, wy1], fill=C("P06"))
        if k == 3:                                                         # 블라인드
            for yy in range(wy0 + 1, wy1, 2):
                d.line([4, yy, 27, yy], fill=C("P07"))
    else:                                                                  # 1층 진열창·셔터
        fy0 = max(y0, 12)
        d.rectangle([1 if col == "l" else 0, fy0 - 1, (T - 2) if col == "r" else T - 1, T - 1], fill=C(INK))
        x0 = 2 if col == "l" else 0
        x1 = T - 3 if col == "r" else T - 1
        if front == "glass":
            d.rectangle([x0, fy0, x1, T - 2], fill=C("P11"))
            d.rectangle([x0, fy0, x1, fy0 + 2], fill=C("P12"))
            for x in range(x0, x1 + 1, 16):
                d.line([x + 15, fy0, x + 15, T - 2], fill=C("P06")) if x + 15 <= x1 else None
            for x in range(x0 + 2, x1 - 1, 3):                              # 진열대 물건
                d.rectangle([x, T - 9, x + 1, T - 7], fill=C(["P09", "P53", "P49", "P15", "P37"][(x // 3 + var) % 5]))
            d.line([x0, T - 6, x1, T - 6], fill=C("P05"))
        elif front == "broken":
            d.rectangle([x0, fy0, x1, T - 2], fill=C("P01"))
            d.polygon([(x0, fy0), (x0 + 8, fy0), (x0 + 3, fy0 + 7)], fill=C("P11"))
            d.polygon([(x1, T - 2), (x1 - 6, T - 2), (x1 - 1, T - 9)], fill=C("P11"))
            for _ in range(4):                                               # 바닥에 흩어진 유리
                img.putpixel((rnd.randint(x0, x1), T - 2), C("P14"))
        else:                                                                # 셔터(내림 / 반 올림)
            d.rectangle([x0, fy0, x1, T - 2], fill=C("P06"))
            for yy in range(fy0 + 1, T - 1, 2):
                d.line([x0, yy, x1, yy], fill=C("P05"))
            if front == "half":
                d.rectangle([x0, T - 9, x1, T - 2], fill=C("P02"))
                d.line([x0, T - 9, x1, T - 9], fill=C("P08"))
            if rnd.random() < 0.6:                                         # 셔터 낙서(형광 스프레이 — 아주 작게)
                xx = rnd.randint(x0 + 2, max(x0 + 3, x1 - 10))
                for k in range(6):
                    img.putpixel((xx + k, fy0 + 6 + (k % 3)), C(rnd.choice(["P56", "P54", "P46"])))
        grime(img, rnd)
    crack(img, rnd, rnd.randint(0, 1))
    ends(img, col, 4 if top else 0)
    return img


def face_office(row, col, var, seed):
    """업무(유리 커튼월): 층마다 스팬드럴 띠(금속), 꼭대기 왕관 띠, 1층 로비(높은 유리 + 기둥)."""
    rnd = random.Random(hsh(seed, var, ord(row[0]), ord(col), 13))
    img = new()
    fill_wall(img, "glass", rnd)
    d = ImageDraw.Draw(img)
    if row in ("top", "solo"):
        d.rectangle([0, 0, T - 1, 9], fill=C("P05"))                        # 왕관 띠(금속 패널)
        d.line([0, 0, T - 1, 0], fill=C("P07"))
        d.line([0, 4, T - 1, 4], fill=C("P04"))
        d.line([0, 9, T - 1, 9], fill=C(INK))
        if var % 4 == 1:                                                    # 원자력 첨탑 받침·안테나 자국
            d.rectangle([13, 1, 18, 3], fill=C("P06"))
    if row != "bot":
        d.rectangle([0, T - 5, T - 1, T - 1], fill=C("P04"))                # 스팬드럴(층 띠)
        d.line([0, T - 5, T - 1, T - 5], fill=C("P06"))
        d.line([0, T - 1, T - 1, T - 1], fill=C("P02"))
        if var % 5 == 2:                                                    # 깨진 판(어둠 + 걸린 조각)
            x0 = rnd.choice((2, 10, 18))
            d.rectangle([x0, 12, x0 + 5, T - 7], fill=C("P01"))
            d.polygon([(x0, 12), (x0 + 5, 12), (x0 + 2, 17)], fill=C("P12"))
        if var % 5 == 4:                                                    # 그을음 띠
            for x in range(T):
                for y in range(10, 18):
                    if (x + y + rnd.randint(0, 2)) % 3 == 0:
                        step_px(img, x, y, -2)
    else:                                                                   # 로비: 기둥 + 높은 유리 + 회전문
        d.rectangle([0, 0, T - 1, 3], fill=C("P04"))
        d.line([0, 3, T - 1, 3], fill=C(INK))
        d.rectangle([0, 4, 5, T - 1], fill=C("P07"))
        d.line([0, 4, 0, T - 1], fill=C("P09"))
        d.line([5, 4, 5, T - 1], fill=C("P05"))
        if var % 3 == 1:
            d.ellipse([12, 12, 27, T - 2], fill=C(INK))
            d.ellipse([13, 13, 26, T - 3], fill=C("P11"))
            d.line([19, 13, 19, T - 3], fill=C("P06"))
        if var % 3 == 2:
            d.rectangle([8, 14, 29, T - 2], fill=C("P01"))
        grime(img, rnd)
    ends(img, col, 10 if row in ("top", "solo") else 0)
    return img


def face_factory(wall, row, col, var, seed, door=None):
    """공장: 골강판 벽 + 꼭대기 채광창 띠(망입 유리) + 큰 셔터 문(2칸) · 철문, 아래 콘크리트 기단."""
    rnd = random.Random(hsh(seed, var, ord(row[0]), ord(col), 17))
    img = new()
    fill_wall(img, wall, rnd)
    d = ImageDraw.Draw(img)
    top, bot = row in ("top", "solo"), row in ("bot", "solo")
    if top:
        cap(img, rnd, "P06", "P07", "P05", 3)
        d.rectangle([0, 7, T - 1, 15], fill=C(INK))                         # 채광창 띠
        d.rectangle([0, 8, T - 1, 14], fill=C("P13" if var % 3 else "P01"))
        for x in range(0, T, 4):
            d.line([x, 8, x, 14], fill=C("P06"))
        d.line([0, 11, T - 1, 11], fill=C("P06"))
    if not bot and not top and var % 2:                                     # 중간 단: 환기 루버
        d.rectangle([10, 10, 21, 19], fill=C(INK))
        for yy in range(11, 19, 2):
            d.line([11, yy, 20, yy], fill=C("P06"))
    for _ in range(rnd.randint(1, 3)):                                     # 녹물
        x = rnd.randint(2, 29)
        for i in range(rnd.randint(5, 14)):
            if rnd.random() < 0.8:
                img.putpixel((x, min(T - 1, (16 if top else 1) + i)), C(rnd.choice(["P24", "P25", "P18"])))
    if bot:
        if door in ("shutter_l", "shutter_r"):                              # 2칸 셔터 문(왼쪽 칸 · 오른쪽 칸)
            x0, x1 = (4, T - 1) if door == "shutter_l" else (0, T - 5)
            d.rectangle([x0 - 1 if door == "shutter_l" else x0, 4, x1 + 1 if door == "shutter_r" else x1, T - 1], fill=C(INK))
            d.rectangle([x0, 5, x1, T - 1], fill=C("P06"))
            for yy in range(6, T, 2):
                d.line([x0, yy, x1, yy], fill=C("P05"))
            d.rectangle([x0, 4, x1, 5], fill=C("P04"))
            if var % 2:
                d.rectangle([x0, T - 8, x1, T - 1], fill=C("P01"))
                d.line([x0, T - 8, x1, T - 8], fill=C("P08"))
            for yy in (5, 6):                                               # 노란 안전 띠(문틀)
                for x in range(x0, x1 + 1):
                    if (x + yy) // 2 % 2:
                        img.putpixel((x, T - 1 - (yy - 5)), C("P49"))
        elif door == "steel":
            S.door(img, 7, 6, 18, 25, "steel", rnd)
        d.rectangle([0, T - 4, T - 1, T - 1], fill=C("P06")) if not door else None    # 콘크리트 기단
        if not door:
            d.line([0, T - 4, T - 1, T - 4], fill=C("P07"))
        grime(img, rnd)
    ends(img, col, 4 if top else 0)
    return img


def face_gov(row, col, var, seed, door=None, lamp=False):
    """관청(1970년대 석조 + 2070년대 비상 설비): 열주 정면, 무거운 처마, 앰버 경광등, 현관 계단·차단벽."""
    rnd = random.Random(hsh(seed, var, ord(row[0]), ord(col), 19))
    img = new()
    fill_wall(img, "stone", rnd)
    d = ImageDraw.Draw(img)
    top, bot = row in ("top", "solo"), row in ("bot", "solo")
    if top:                                                                 # 처마(엔타블러처)
        d.rectangle([0, 0, T - 1, 8], fill=C("P08"))
        d.line([0, 0, T - 1, 0], fill=C("P09"))
        d.line([0, 4, T - 1, 4], fill=C("P06"))
        for x in range(1, T, 4):
            d.rectangle([x, 5, x + 1, 7], fill=C("P06"))                    # 치형 장식
        d.line([0, 8, T - 1, 8], fill=C("P05"))
        d.line([0, 9, T - 1, 9], fill=C(INK))
    y0 = 10 if top else 0
    if col == "m" or col == "l":                                            # 열주: 칸 왼쪽에 기둥, 나머지는 그늘진 벽 + 긴 창
        d.rectangle([9, y0, T - 1, T - 1], fill=C("P05"))
        d.rectangle([9, y0, T - 1, y0 + 1], fill=C("P03"))
        if not bot:
            d.rectangle([15, y0 + 4, 26, T - 3], fill=C(INK))
            d.rectangle([16, y0 + 5, 25, T - 4], fill=C("P11" if var % 3 else "P02"))
            d.line([20, y0 + 5, 20, T - 4], fill=C("P05"))
            d.line([16, y0 + 12, 25, y0 + 12], fill=C("P05"))
        d.rectangle([2, y0, 8, T - 1], fill=C("P08"))                        # 기둥(밝은 왼쪽 · 어두운 오른쪽)
        d.line([2, y0, 2, T - 1], fill=C("P09"))
        d.line([7, y0, 7, T - 1], fill=C("P06"))
        d.line([8, y0, 8, T - 1], fill=C(INK))
        d.line([1, y0, 1, T - 1], fill=C(INK))
    if lamp and top:                                                        # 앰버 경광등(SD-16 §6.3)
        d.rectangle([20, 1, 26, 7], fill=C(INK))
        d.rectangle([21, 2, 25, 6], fill=C("P59"))
        d.rectangle([22, 2, 24, 3], fill=C("P60"))
        d.line([23, 8, 23, 12], fill=C("P04"))
    if bot:
        if door == "door":                                                  # 청사 현관: 쌍여닫이 철문 + 계단
            d.rectangle([10, 6, 29, T - 5], fill=C(INK))
            d.rectangle([11, 7, 28, T - 5], fill=C("P04"))
            d.line([19, 7, 19, T - 5], fill=C(INK))
            d.rectangle([12, 9, 17, 14], fill=C("P11")); d.rectangle([21, 9, 26, 14], fill=C("P11"))
        elif door == "barrier":                                             # 비상 차단벽(노랑·검정 사선)
            d.rectangle([0, 14, T - 1, T - 5], fill=C(INK))
            for x in range(T):
                for y in range(15, T - 5):
                    img.putpixel((x, y), C("P49" if (x + y) // 4 % 2 else "P02"))
        for k, yy in enumerate((T - 4, T - 2)):                              # 계단 두 단
            d.rectangle([0, yy, T - 1, yy + 1], fill=C("P08" if k == 0 else "P07"))
            d.line([0, yy, T - 1, yy], fill=C("P09"))
        d.line([0, T - 1, T - 1, T - 1], fill=C(INK))
    ends(img, col, 10 if top else 0)
    return img


def face_base(row, col, var, seed, door=None):
    """군 기지: 올리브 콘크리트, 좁은 띠창(사격창), 갓 위 철조망, 방폭문, 아래 모래주머니."""
    rnd = random.Random(hsh(seed, var, ord(row[0]), ord(col), 23))
    img = new()
    fill_wall(img, "olive", rnd)
    d = ImageDraw.Draw(img)
    top, bot = row in ("top", "solo"), row in ("bot", "solo")
    if top:
        cap(img, rnd, "P31", "P32", "P29", 4)
        for x in range(0, T, 4):                                            # 철조망(갓 위 고리)
            d.point((x + 1, 0), fill=C("P05")); d.point((x + 2, 1), fill=C("P06"))
    if not bot:
        wy = 13 if top else 10
        d.rectangle([6, wy, 25, wy + 4], fill=C(INK))
        d.rectangle([7, wy + 1, 24, wy + 3], fill=C("P02"))
        d.line([6, wy + 5, 25, wy + 5], fill=C("P32"))
    if var % 4 == 3 and not bot:                                            # 스텐실 번호(색 띠, 글자 대신)
        d.rectangle([10, 22, 21, 25], fill=C("P09"))
        d.rectangle([12, 23, 13, 24], fill=C("P30")); d.rectangle([16, 23, 17, 24], fill=C("P30"))
    if bot:
        if door == "blast":
            d.rectangle([5, 4, 26, T - 1], fill=C(INK))
            d.rectangle([6, 5, 25, T - 1], fill=C("P05"))
            for y in range(6, T, 6):
                d.line([6, y, 25, y], fill=C("P04"))
            d.rectangle([14, 13, 17, 20], fill=C("P49"))
            for x in range(6, 26):
                img.putpixel((x, 5), C("P49" if x // 3 % 2 else "P02"))
        elif var % 2 == 0:                                                   # 모래주머니
            for k, x in enumerate(range(-4 + (var % 3) * 2, T, 9)):
                d.ellipse([x, T - 9, x + 9, T - 3], fill=C("P20"))
                d.arc([x, T - 9, x + 9, T - 3], 180, 360, fill=C("P21"))
                d.arc([x, T - 9, x + 9, T - 3], 0, 180, fill=C("P18"))
            for x in range(-0 + (var % 3) * 2, T, 9):
                d.ellipse([x, T - 6, x + 9, T - 1], fill=C("P19"))
                d.arc([x, T - 6, x + 9, T - 1], 180, 360, fill=C("P21"))
        grime(img, rnd)
    ends(img, col, 5 if top else 0)
    return img


# ================================================================================================ 옥상(위에서 본 면)
ROOF_PAINT = {"green": ("P35", "P36", "P37", "P34"), "grey": ("P06", "P07", "P08", "P05"), "red": ("P24", "P25", "P26", "P23"),
              "tar": ("P03", "P04", "P05", "P02"), "olive": ("P29", "P30", "P31", "P28"), "metal": ("P05", "P06", "P07", "P04")}


def roof_tile(paint, pos, var, seed):
    """평지붕 칸: pos = nw·n·ne·w·c·e. 북·서·동에 난간 띠, 남쪽은 정면 갓돌이 덮는다(struct_r01.roof와 같은 띠).
    쯔꾸르식으로 차분하게: 변형 0 = 거의 평면(티끌 몇 점), 1 = 바랜 자리(50% 디더), 2 = 금, 3 = 덧댄 방수 판."""
    rnd = random.Random(hsh(seed, var, sum(map(ord, pos)), sum(map(ord, paint))))
    ramp = ROOF_PAINT[paint]
    img = new(ramp[1])
    d = ImageDraw.Draw(img)
    for _ in range(rnd.randint(3, 6)):                                      # 티끌(1px)
        img.putpixel((rnd.randint(2, 29), rnd.randint(2, 29)), C(ramp[0] if rnd.random() < 0.7 else ramp[2]))
    if paint == "tar":                                                       # 타르 지붕 자갈
        for _ in range(14):
            img.putpixel((rnd.randint(1, 30), rnd.randint(1, 30)), C(ramp[2]))
    if var == 1:                                                             # 바랜 자리: 둥근 디더 얼룩(칸 안)
        cx, cy, rx, ry = rnd.randint(11, 20), rnd.randint(11, 20), rnd.randint(6, 9), rnd.randint(4, 7)
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if 1 <= x <= 30 and 1 <= y <= 30 and ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 and (x + y) % 2 == 0:
                    img.putpixel((x, y), C(ramp[2] if paint != "tar" else ramp[0]))
    elif var == 2:                                                           # 금(가는 1px, 칸 안에서 끝남)
        cx, cy = rnd.randint(6, 25), rnd.randint(5, 12)
        for i in range(rnd.randint(9, 15)):
            if 1 <= cx <= 30 and 1 <= cy <= 30:
                img.putpixel((cx, cy), C(ramp[3]))
            cx += rnd.choice((-1, 0, 1, 1)); cy += rnd.choice((0, 1, 1))
    elif var == 3:                                                           # 덧댄 방수 판(회색 사각 + 아래 그늘)
        x0, y0 = rnd.randint(6, 14), rnd.randint(8, 15)
        w_, h_ = rnd.randint(8, 12), rnd.randint(5, 8)
        d.rectangle([x0, y0, x0 + w_, y0 + h_], fill=C("P06" if paint != "grey" else "P05"))
        d.line([x0, y0, x0 + w_, y0], fill=C("P07" if paint != "grey" else "P06"))
        d.line([x0, y0 + h_ + 1, x0 + w_, y0 + h_ + 1], fill=C(ramp[0]))
    if paint == "metal":                                                     # 금속 지붕 이음 띠
        d.line([0, 15, T - 1, 15], fill=C(ramp[0]))
        d.line([0, 31, T - 1, 31], fill=C(ramp[0]))
    bw = 5
    if "n" in pos:
        d.rectangle([0, 0, T - 1, bw], fill=C("P07"))
        d.line([0, 0, T - 1, 0], fill=C(INK)); d.line([0, bw, T - 1, bw], fill=C("P08")); d.line([0, bw + 1, T - 1, bw + 1], fill=C("P05"))
        d.line([0, bw + 2, T - 1, bw + 2], fill=C(ramp[0]))
    if pos.endswith("w"):
        d.rectangle([0, 0, bw - 1, T - 1], fill=C("P07"))
        d.line([0, 0, 0, T - 1], fill=C(INK)); d.line([bw - 1, 0, bw - 1, T - 1], fill=C("P08")); d.line([bw, 0, bw, T - 1], fill=C(ramp[0]))
    if pos.endswith("e"):
        d.rectangle([T - bw, 0, T - 1, T - 1], fill=C("P07"))
        d.line([T - 1, 0, T - 1, T - 1], fill=C(INK)); d.line([T - bw, 0, T - bw, T - 1], fill=C("P06")); d.line([T - bw - 1, 0, T - bw - 1, T - 1], fill=C(ramp[0]))
    if pos == "nw":
        d.rectangle([0, 0, bw - 1, bw], fill=C("P07")); d.line([0, 0, bw - 1, 0], fill=C(INK)); d.line([0, 0, 0, bw], fill=C(INK))
    if pos == "ne":
        d.rectangle([T - bw, 0, T - 1, bw], fill=C("P07")); d.line([T - bw, 0, T - 1, 0], fill=C(INK)); d.line([T - 1, 0, T - 1, bw], fill=C(INK))
    return img


def roof_rib(paint, pos, var, seed):
    """공장 골지붕(남북 방향 골): 4px마다 등·골, 북쪽 끝 용마루 띠, 녹 얼룩."""
    rnd = random.Random(hsh(seed, var, sum(map(ord, pos)), 29))
    ramp = ROOF_PAINT[paint]
    img = new(ramp[1])
    d = ImageDraw.Draw(img)
    for x in range(0, T, 4):
        d.line([x, 0, x, T - 1], fill=C(ramp[2]))
        d.line([x + 2, 0, x + 2, T - 1], fill=C(ramp[0]))
    for _ in range(1 if var == 1 else 0):                                   # 녹 얼룩(칸 안, 변형 1만)
        x, y = rnd.randint(3, 26), rnd.randint(3, 22)
        for i in range(rnd.randint(3, 8)):
            img.putpixel((x + rnd.randint(-1, 1), y + i), C(rnd.choice(["P24", "P25", "P18"])))
    if var == 2:                                                             # 덮개 판 이음(가로)
        d.line([0, 15, T - 1, 15], fill=C(ramp[3])); d.line([0, 16, T - 1, 16], fill=C(ramp[2]))
    if var == 3:                                                             # 뚫린 구멍
        d.rectangle([11, 11, 19, 17], fill=C(INK))
        d.rectangle([12, 12, 18, 16], fill=C("P02"))
    if "n" in pos:
        d.rectangle([0, 0, T - 1, 4], fill=C(ramp[2]))
        d.line([0, 0, T - 1, 0], fill=C(INK)); d.line([0, 4, T - 1, 4], fill=C(ramp[3]))
    if pos.endswith("w"):
        d.line([0, 0, 0, T - 1], fill=C(INK)); d.line([1, 0, 1, T - 1], fill=C(ramp[2]))
    if pos.endswith("e"):
        d.line([T - 1, 0, T - 1, T - 1], fill=C(INK)); d.line([T - 2, 0, T - 2, T - 1], fill=C(ramp[3]))
    return img


def roof_pitch(paint, part, col, var, seed):
    """주택 맞배지붕(동서로 긴 용마루): part = n(북 처마) · ns(북 비탈) · ridge(용마루 · 남 비탈 시작) · ss(남 비탈).
    빛이 북서에서 와서 북 비탈이 밝고 남 비탈이 어둡다. 양 끝 열은 박공 띠."""
    rnd = random.Random(hsh(seed, var, sum(map(ord, part)), ord(col), 31))
    ramp = ROOF_PAINT[paint]
    north = part in ("n", "ns")
    img = new(ramp[2] if north else ramp[1])
    d = ImageDraw.Draw(img)
    for y in range(0, T, 4):                                                # 슬레이트 골(가로 줄, 4px 주기라 칸 사이로 이어진다)
        d.line([0, y + 3, T - 1, y + 3], fill=C(ramp[1] if north else ramp[0]))
        for x in range((y // 4 % 2) * 4, T, 8):
            img.putpixel((x, y + 1), C(ramp[1] if north else ramp[0]))
    for _ in range(rnd.randint(0, 2)):                                       # 깨진 장 · 덧댄 판
        x, y = rnd.randint(4, 22), rnd.randint(6, 22)
        d.rectangle([x, y, x + 5, y + 3], fill=C(ramp[3] if rnd.random() < 0.5 else "P06"))
    if part == "n":
        d.line([0, 0, T - 1, 0], fill=C(INK)); d.line([0, 1, T - 1, 1], fill=C(ramp[2]))
    if part == "ridge":
        d.rectangle([0, 0, T - 1, 3], fill=C(ramp[2]))
        d.line([0, 0, T - 1, 0], fill=C(ramp[2])); d.line([0, 3, T - 1, 3], fill=C(ramp[3]))
        d.line([0, 4, T - 1, 4], fill=C(INK))
    if part in ("ss", "ridge") and var % 3 == 0:
        d.line([0, T - 1, T - 1, T - 1], fill=C(ramp[0]))
    if col == "l":
        d.line([0, 0, 0, T - 1], fill=C(INK)); d.line([1, 0, 1, T - 1], fill=C("P08"))
    if col == "r":
        d.line([T - 1, 0, T - 1, T - 1], fill=C(INK)); d.line([T - 2, 0, T - 2, T - 1], fill=C("P05"))
    return img


# ================================================================================================ 옥상 덧층(투명 바탕)
def roof_deco():
    out = {}
    rnd = random.Random(7)
    # 물탱크 2×2(FRP 패널 탱크, 사다리)
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([10, 50, 58, 62], fill=(0, 0, 0, 0))
    d.rectangle([8, 10, 55, 55], fill=C(INK))
    d.rectangle([9, 11, 54, 30], fill=C("P15"))                              # 윗면
    d.rectangle([9, 31, 54, 54], fill=C("P13"))                              # 정면
    for x in range(9, 55, 9):
        d.line([x, 31, x, 54], fill=C("P12"))
        d.line([x, 11, x, 30], fill=C("P14"))
    d.line([9, 31, 54, 31], fill=C("P09"))
    d.rectangle([26, 16, 37, 24], fill=C("P12")); d.rectangle([27, 17, 36, 23], fill=C("P14"))     # 점검구
    for y in range(33, 54, 3):
        d.line([44, y, 49, y], fill=C("P05"))
    d.line([44, 31, 44, 54], fill=C("P04")); d.line([49, 31, 49, 54], fill=C("P04"))
    for k in range(4):
        streak(im, 12 + k * 11, 34, rnd.randint(5, 14), -1, rnd)
    _split(out, "tank", im)
    # 냉각 돔 2×2(아파트 옥상 원자로 냉각 돔 + 방열 핀, SD-16 §2.4 폴아웃화)
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for k in range(7):                                                       # 방열 핀(둘레)
        x = 6 + k * 8
        d.rectangle([x, 40, x + 3, 58], fill=C(INK)); d.rectangle([x + 1, 41, x + 2, 57], fill=C("P06"))
    d.rectangle([4, 50, 59, 59], fill=C(INK)); d.rectangle([5, 51, 58, 58], fill=C("P05"))
    d.line([5, 51, 58, 51], fill=C("P07"))
    d.pieslice([8, 6, 55, 56], 180, 360, fill=C(INK))
    d.pieslice([9, 7, 54, 55], 180, 360, fill=C("P07"))
    d.pieslice([13, 11, 42, 44], 200, 300, fill=C("P08"))                    # 왼쪽 위 빛
    d.arc([9, 7, 54, 55], 270, 360, fill=C("P05"))
    d.rectangle([9, 30, 54, 50], fill=C("P06"))
    d.line([9, 31, 54, 31], fill=C("P04"))
    for k in range(5):
        d.line([12 + k * 9, 33, 12 + k * 9, 49], fill=C("P05"))
    d.line([8, 30, 8, 50], fill=C(INK)); d.line([55, 30, 55, 50], fill=C(INK))
    d.ellipse([28, 4, 35, 11], fill=C(INK)); d.ellipse([29, 5, 34, 10], fill=C("P49"))    # 표시등
    d.point((30, 6), fill=C("P50"))
    for x in range(16, 48, 6):                                               # 원자 궤도 마크(돔 정면 칠)
        pass
    d.ellipse([24, 36, 39, 45], outline=C("P49"))
    d.point((31, 40), fill=C("P49")); d.point((32, 40), fill=C("P49"))
    _split(out, "dome", im)
    # 1×1: 실외기 · 환기구 · 출입 계단실 뚜껑 · 안테나 · 텃밭 상자 · 잔해 · 위성 접시 · 모래주머니
    im = new(); d = ImageDraw.Draw(im)
    d.rectangle([5, 9, 26, 26], fill=C(INK)); d.rectangle([6, 10, 25, 16], fill=C("P08")); d.rectangle([6, 17, 25, 25], fill=C("P07"))
    d.ellipse([10, 17, 21, 25], fill=C("P05")); d.line([11, 21, 20, 21], fill=C("P03")); d.line([15, 18, 15, 24], fill=C("P03"))
    streak(im, 8, 27, 3, -1)
    out["ac"] = im
    im = new(); d = ImageDraw.Draw(im)
    d.rectangle([9, 9, 22, 24], fill=C(INK)); d.rectangle([10, 10, 21, 15], fill=C("P07")); d.rectangle([10, 16, 21, 23], fill=C("P05"))
    for y in range(17, 23, 2):
        d.line([10, y, 21, y], fill=C("P03"))
    out["vent"] = im
    im = new(); d = ImageDraw.Draw(im)
    d.rectangle([4, 4, 27, 27], fill=C(INK)); d.rectangle([5, 5, 26, 14], fill=C("P06")); d.rectangle([5, 15, 26, 26], fill=C("P07"))
    d.rectangle([9, 16, 22, 26], fill=C("P04")); d.rectangle([10, 17, 21, 26], fill=C("P05")); d.rectangle([19, 21, 20, 22], fill=C("P49"))
    out["hatch"] = im
    im = new(); d = ImageDraw.Draw(im)
    d.line([16, 2, 16, 27], fill=C("P04")); d.line([17, 2, 17, 27], fill=C(INK))
    for y, w in ((5, 6), (10, 9), (15, 12)):
        d.line([16 - w, y, 16 + w, y], fill=C("P05")); d.line([16 - w, y + 1, 16 + w, y + 1], fill=C(INK))
    d.rectangle([13, 26, 20, 29], fill=C("P05")); d.line([13, 29, 20, 29], fill=C(INK))
    out["antenna"] = im
    for k in range(2):                                                       # 옥상 텃밭(정착민) — 흙 상자 + 싹
        im = new(); d = ImageDraw.Draw(im)
        d.rectangle([3, 7, 28, 26], fill=C(INK)); d.rectangle([4, 8, 27, 13], fill=C("P19")); d.rectangle([4, 14, 27, 25], fill=C("P18"))
        d.rectangle([5, 9, 26, 12], fill=C("P17"))
        r2 = random.Random(40 + k)
        for x in range(6, 26, 4):
            col = r2.choice(["P30", "P31", "P55"])
            d.point((x, 9), fill=C(col)); d.point((x + 1, 8), fill=C(col)); d.point((x - 1, 8), fill=C(col))
            if k:
                d.point((x, 7), fill=C("P31"))
        out[f"garden{k}"] = im
    im = new(); d = ImageDraw.Draw(im)                                       # 잔해 더미(깨진 판·철근)
    for (x, y, w, h, c) in ((5, 17, 10, 6, "P06"), (13, 13, 12, 8, "P07"), (8, 21, 14, 5, "P05")):
        d.rectangle([x, y, x + w, y + h], fill=C(INK)); d.rectangle([x + 1, y + 1, x + w - 1, y + h - 1], fill=C(c))
        d.line([x + 1, y + 1, x + w - 1, y + 1], fill=C(S.P_up(c)))
    d.line([20, 9, 25, 16], fill=C("P25")); d.line([21, 9, 26, 16], fill=C(INK))
    out["debris"] = im
    im = new(); d = ImageDraw.Draw(im)                                       # 위성 접시(꺾인)
    d.ellipse([5, 6, 24, 21], fill=C(INK)); d.ellipse([6, 7, 23, 20], fill=C("P08")); d.ellipse([8, 9, 17, 16], fill=C("P09"))
    d.line([15, 13, 25, 23], fill=C("P04")); d.rectangle([22, 22, 27, 27], fill=C("P05")); d.rectangle([22, 22, 27, 27], outline=C(INK))
    out["dish"] = im
    im = new(); d = ImageDraw.Draw(im)                                       # 모래주머니 둔덕(군 옥상)
    for (x, y) in ((2, 16), (11, 16), (20, 16), (6, 10), (15, 10)):
        d.ellipse([x, y, x + 10, y + 7], fill=C(INK)); d.ellipse([x + 1, y + 1, x + 9, y + 6], fill=C("P20"))
        d.arc([x + 1, y + 1, x + 9, y + 6], 180, 360, fill=C("P21"))
    out["sandbag"] = im
    # 계단실 3×2(옥상 출입 계단·승강기 기계실): 윗면 + 남쪽 정면(철문·환기 루버)
    im = Image.new("RGBA", (96, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([4, 6, 91, 61], fill=C(INK))
    d.rectangle([5, 7, 90, 30], fill=C("P06"))                               # 윗면(평지붕 회색)
    d.rectangle([5, 7, 90, 10], fill=C("P07")); d.line([5, 7, 90, 7], fill=C("P08"))
    for x in (30, 60):
        d.line([x, 11, x, 30], fill=C("P05"))
    d.rectangle([5, 31, 90, 60], fill=C("P07"))                              # 정면
    d.line([5, 31, 90, 31], fill=C("P09")); d.line([5, 32, 90, 32], fill=C("P05"))
    d.line([6, 33, 6, 60], fill=C("P08")); d.line([89, 33, 89, 60], fill=C("P05")); d.line([88, 33, 88, 60], fill=C("P06"))
    d.rectangle([16, 36, 33, 60], fill=C(INK)); d.rectangle([17, 37, 32, 60], fill=C("P05"))
    d.rectangle([19, 39, 30, 46], fill=C("P06")); d.rectangle([29, 49, 30, 50], fill=C("P48"))
    d.rectangle([56, 38, 79, 49], fill=C(INK))
    for y in range(39, 49, 2):
        d.line([57, y, 78, y], fill=C("P04"))
    for k in range(3):
        streak(im, 40 + k * 14, 33, rnd.randint(5, 12), -1, rnd)
    _split(out, "pent", im)
    # 천창 2×2(망입 유리 피라미드 — 관청·상가 옥상)
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([6, 8, 57, 55], fill=C(INK))
    d.rectangle([7, 9, 56, 54], fill=C("P05"))
    d.polygon([(9, 11), (54, 11), (31, 31)], fill=C("P14"))                   # 북쪽 면(밝음)
    d.polygon([(9, 11), (31, 31), (9, 52)], fill=C("P13"))                    # 서쪽 면
    d.polygon([(54, 11), (54, 52), (31, 31)], fill=C("P12"))                  # 동쪽 면
    d.polygon([(9, 52), (54, 52), (31, 31)], fill=C("P11"))                   # 남쪽 면(어둠)
    d.line([9, 11, 54, 52], fill=C("P06")); d.line([54, 11, 9, 52], fill=C("P06"))
    for k in range(1, 4):
        d.line([9 + k * 11, 11, 9 + k * 11, 52], fill=C("P06"))
    d.polygon([(38, 40), (46, 44), (40, 47)], fill=C(INK))                    # 깨진 판
    _split(out, "sky", im)
    return out


def _split(out, name, im):
    for j in range(im.height // T):
        for i in range(im.width // T):
            out[f"{name}{j}{i}"] = im.crop((i * T, j * T, i * T + T, j * T + T))


# ================================================================================================ 지형 구조(암벽·벼랑 끝·계단·성곽·다리)
def cliff_face(col, var, seed=0):
    """정면 암벽 1단(SD-16 §6.5 '등고선 1단 = 암벽 1타일'): 높은 땅 남쪽 칸. 위 2px 풀·흙 처마, 화강암 덩어리(왼쪽 위 빛),
    아래 먹선 + 부스러기. col l·r = 암벽 끝(비스듬히 땅으로 사라진다 — 바깥은 투명, 바닥 합성이 비친다)."""
    rnd = random.Random(hsh(seed, var, ord(col), 41))
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=C("P03"))                        # 바위 틈(어둠)
    px = img.load()
    blobs = []
    for k in range(9):                                                      # 화강암 덩어리: 둥근 바위(칸 가장자리는 32px 주기로 이어지게 감싼다)
        blobs.append((rnd.randint(0, T - 1), rnd.randint(6, T - 6), rnd.randint(6, 11), rnd.randint(5, 8)))
    blobs.sort(key=lambda b: b[1])
    for (cx, cy, rx, ry) in blobs:
        tone = rnd.choice([("P07", "P06", "P05"), ("P06", "P05", "P04"), ("P08", "P07", "P05")])
        for yy in range(max(3, cy - ry), min(T - 3, cy + ry + 1)):
            for xx in range(cx - rx - 1, cx + rx + 2):
                q = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
                if q <= 1.0:
                    X = xx % T
                    u, v = (xx - cx) / rx, (yy - cy) / ry
                    c = tone[0] if (u + v) < -0.55 else (tone[2] if (u + v) > 0.55 else tone[1])
                    if q > 0.82:
                        c = "P02" if (u + v) > 0 else tone[1]
                    px[X, yy] = C(c)
    for _ in range(rnd.randint(1, 3)):                                      # 금(세로)
        cx, cy = rnd.randint(3, 28), rnd.randint(5, 14)
        for i in range(rnd.randint(4, 10)):
            if 0 <= cx < T and cy < T - 3:
                img.putpixel((cx, cy), C("P02"))
            cx += rnd.choice((-1, 0, 0, 1)); cy += 1
    d.rectangle([0, 0, T - 1, 1], fill=C("P29"))                            # 위 처마(마른 풀·흙)
    for x in range(0, T, 3):
        d.point((x + rnd.randint(0, 1), 2), fill=C(rnd.choice(["P29", "P30", "P18"])))
    d.line([0, 3, T - 1, 3], fill=C("P02"))
    d.rectangle([0, T - 3, T - 1, T - 2], fill=C("P04"))                     # 발치 부스러기
    for x in range(0, T, 4):
        d.point((x + rnd.randint(0, 2), T - 3), fill=C(rnd.choice(["P06", "P07", "P05"])))
    d.line([0, T - 1, T - 1, T - 1], fill=C(INK))
    if col in ("l", "r"):                                                   # 끝: 비스듬히 깎아 투명하게
        px = img.load()
        for yy in range(T):
            cut = int(12 * yy / T) + 2
            for xx in range(cut):
                X = xx if col == "l" else T - 1 - xx
                px[X, yy] = (0, 0, 0, 0)
            X = cut if col == "l" else T - 1 - cut
            px[X, yy] = C(INK)
    return img


def cliff_stair(var=0):
    """암벽을 깎은 돌계단(남북 방향, SD-16 §6.5): 디딤판 밝음 · 챌판 어둠 · 양옆 돌 기둥."""
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=C("P05"))
    for k, y in enumerate(range(1, T, 6)):
        d.rectangle([4, y, T - 5, y + 2], fill=C("P08"))
        d.line([4, y, T - 5, y], fill=C("P09"))
        d.rectangle([4, y + 3, T - 5, y + 5], fill=C("P05"))
        d.line([4, y + 5, T - 5, y + 5], fill=C("P03"))
    for x0 in (0, T - 4):
        d.rectangle([x0, 0, x0 + 3, T - 1], fill=C("P06"))
        d.line([x0, 0, x0, T - 1], fill=C("P07" if x0 == 0 else "P04"))
        d.line([x0 + 3, 0, x0 + 3, T - 1], fill=C(INK))
    d.line([0, 0, 0, T - 1], fill=C(INK))
    return img


def brink(mask):
    """벼랑 끝(덧층): 높은 땅 칸의 낮은 쪽 테두리. mask 1 = 북, 2 = 동, 4 = 서. 투명 바탕."""
    img = new()
    d = ImageDraw.Draw(img)
    if mask & 1:
        d.line([0, 0, T - 1, 0], fill=C(INK)); d.line([0, 1, T - 1, 1], fill=C("P05"))
    if mask & 4:
        d.line([0, 0, 0, T - 1], fill=C(INK)); d.line([1, 0, 1, T - 1], fill=C("P07"))
    if mask & 2:
        d.line([T - 1, 0, T - 1, T - 1], fill=C(INK)); d.line([T - 2, 0, T - 2, T - 1], fill=C("P04")); d.line([T - 3, 0, T - 3, T - 1], fill=C("P05"))
    return img


def fort(kind, var=0):
    """한양도성 성벽(SD-08 §6.4): face = 정면(다듬은 돌 쌓기 + 여장 총안), top = 성곽 위 길(남북으로 이어진 구간)."""
    rnd = random.Random(hsh(var, 43, ord(kind[0])))
    img = new()
    d = ImageDraw.Draw(img)
    if kind == "face":
        d.rectangle([0, 0, T - 1, T - 1], fill=C("P21"))
        for row, y in enumerate(range(10, T, 6)):
            off = 4 if row % 2 else 0
            for x in range(-8 + off, T, 8):
                a0, a1 = max(0, x), min(T - 1, x + 7)
                if a1 < a0:
                    continue
                col = rnd.choice(["P21", "P21", "P20", "P22"])
                d.rectangle([a0, y, a1, y + 5], fill=C(col))
                d.line([a0, y, a1, y], fill=C("P22"))
                d.line([a0, y + 5, a1, y + 5], fill=C("P19"))
                if x + 7 < T:
                    d.line([x + 7, y, x + 7, y + 5], fill=C("P19"))
        d.rectangle([0, 0, T - 1, 9], fill=C("P20"))                         # 여장(총안 두 개)
        d.line([0, 0, T - 1, 0], fill=C("P22"))
        for x in (6, 22):
            d.rectangle([x, 2, x + 3, 7], fill=C(INK))
        d.line([0, 9, T - 1, 9], fill=C("P18"))
        d.line([0, T - 1, T - 1, T - 1], fill=C(INK))
    else:
        d.rectangle([0, 0, T - 1, T - 1], fill=C("P20"))
        for y in range(0, T, 8):
            d.line([4, y, T - 5, y], fill=C("P19"))
        for x0 in (0, T - 4):                                                 # 양옆 여장 윗면
            d.rectangle([x0, 0, x0 + 3, T - 1], fill=C("P21"))
            d.line([x0, 0, x0, T - 1], fill=C(INK) if x0 == 0 else C("P22"))
            d.line([x0 + 3, 0, x0 + 3, T - 1], fill=C("P19") if x0 == 0 else C(INK))
    return img


def fort_course(part, var=0):
    """한양도성 정면 중단·하단(SD-08 §9.1 '성곽 높이는 정면 3~4타일'): 위로 갈수록 작아지는 다듬은 돌 쌓기.
    mid = 중간 크기 돌(10×7), bot = 큰 지대석(16×9) + 아래 땅 접선 먹선과 이끼."""
    rnd = random.Random(hsh(var, 61, ord(part[0])))
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=C("P19"))
    bw, bh = (16, 8)                                                         # 32의 약수(칸 사이 줄눈이 이어진다)
    for row, y in enumerate(range(0, T, bh)):
        off = (bw // 2) if row % 2 else 0
        for x in range(-bw + off, T, bw):
            a0, a1 = max(0, x), min(T - 1, x + bw - 2)
            b1 = min(T - 1, y + bh - 2)
            if a1 < a0:
                continue
            col = rnd.choice(["P21", "P21", "P20", "P20", "P19"] if part == "mid" else ["P20", "P20", "P19", "P21"])
            d.rectangle([a0, y, a1, b1], fill=C(col))
            d.line([a0, y, a1, y], fill=C(S.P_up(col)))                     # 윗면 빛
            d.line([a0, y, a0, b1], fill=C(S.P_up(col)))
            d.line([a1, y, a1, b1], fill=C("P18"))
            d.line([a0, b1, a1, b1], fill=C("P18"))
    for _ in range(rnd.randint(1, 3)):                                      # 물때(세로)
        x = rnd.randint(2, 29)
        for i in range(rnd.randint(4, 12)):
            step_px(img, x, i + (0 if part == "mid" else 2), -1)
    if part == "bot":
        for x in range(T):
            if rnd.random() < 0.25:
                img.putpixel((x, T - 3), C(rnd.choice(["P29", "P30"])))
        d.line([0, T - 1, T - 1, T - 1], fill=C(INK))
    return img


def deck(mask, broken=False, var=0):
    """다리 상판(SD-16 §6.3): 콘크리트 판 + 신축 이음, 물 쪽 변에 난간(mask 1 북 · 2 동 · 4 남 · 8 서 = 그쪽이 물).
    broken: 끊긴 끝 — 북·남 물 쪽 변이 들쭉날쭉 깨지고 철근이 삐져나온다."""
    rnd = random.Random(hsh(mask, var, 47, int(broken)))
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=C("P05"))
    for _ in range(5):
        img.putpixel((rnd.randint(1, 30), rnd.randint(1, 30)), C(rnd.choice(["P04", "P06"])))
    d.line([0, 15, T - 1, 15], fill=C("P04")); d.line([0, 16, T - 1, 16], fill=C("P06"))     # 신축 이음
    px = img.load()

    def rail(side):
        if side == 1:
            d.rectangle([0, 0, T - 1, 3], fill=C("P07")); d.line([0, 0, T - 1, 0], fill=C(INK)); d.line([0, 1, T - 1, 1], fill=C("P08"))
            d.line([0, 4, T - 1, 4], fill=C("P03"))
        elif side == 4:
            d.rectangle([0, T - 7, T - 1, T - 1], fill=C("P06"))            # 남쪽 난간 정면 + 거더 면
            d.rectangle([0, T - 7, T - 1, T - 5], fill=C("P08")); d.line([0, T - 7, T - 1, T - 7], fill=C("P09"))
            d.line([0, T - 4, T - 1, T - 4], fill=C("P04"))
            d.line([0, T - 1, T - 1, T - 1], fill=C(INK))
        elif side == 8:
            d.rectangle([0, 0, 3, T - 1], fill=C("P07")); d.line([0, 0, 0, T - 1], fill=C(INK)); d.line([1, 0, 1, T - 1], fill=C("P08"))
            d.line([4, 0, 4, T - 1], fill=C("P04"))
        elif side == 2:
            d.rectangle([T - 4, 0, T - 1, T - 1], fill=C("P06")); d.line([T - 1, 0, T - 1, T - 1], fill=C(INK)); d.line([T - 4, 0, T - 4, T - 1], fill=C("P08"))
            d.line([T - 5, 0, T - 5, T - 1], fill=C("P04"))

    def jag(side):
        ys = range(0, 9) if side == 1 else range(T - 9, T)
        cut = [rnd.randint(2, 8) for _ in range(T)]
        for x in range(T):
            c = cut[x] if x % 3 else cut[x - 1]
            for yy in ys:
                k = yy if side == 1 else T - 1 - yy
                if k < c:
                    px[x, yy] = (0, 0, 0, 0)
                elif k == c:
                    px[x, yy] = C(INK)
                elif k == c + 1:
                    px[x, yy] = C("P07")
        for x in range(3, T - 3, 7):                                          # 철근
            y0 = cut[x] if side == 1 else T - 1 - cut[x]
            for k in range(4):
                yy = y0 - k if side == 1 else y0 + k
                if 0 <= yy < T:
                    px[x, yy] = C("P25" if k < 3 else "P24")

    for side in (8, 2, 1, 4):
        if mask & side:
            if broken and side in (1, 4):
                jag(side)
            else:
                rail(side)
    if (mask & 1) and (mask & 8):
        d.point((0, 0), fill=C(INK))
    return img


def scrap_top(var=0):
    """고철 장벽 위에서 본 남북 구간(정착지 담, 0-10 고철 장벽과 같은 재료): 칸 가운데 판 띠 + 말뚝 + 가시철사."""
    rnd = random.Random(hsh(var, 59))
    img = new()
    d = ImageDraw.Draw(img)
    tones = [("P24", "P25"), ("P04", "P05"), ("P12", "P13"), ("P17", "P18")]
    y = 0
    while y < T:
        h = rnd.randint(5, 10)
        a, b = rnd.choice(tones)
        d.rectangle([12, y, 19, min(T - 1, y + h - 1)], fill=C(a))
        d.line([12, y, 12, min(T - 1, y + h - 1)], fill=C(b))
        y += h
    d.line([11, 0, 11, T - 1], fill=C(INK)); d.line([20, 0, 20, T - 1], fill=C(INK))
    for yy in (4, 20):                                                       # 말뚝 머리
        d.rectangle([13, yy, 18, yy + 4], fill=C("P18")); d.rectangle([13, yy, 18, yy + 4], outline=C(INK))
    for yy in range(1, T, 3):                                                # 가시철사
        img.putpixel((15 + (yy % 2), yy), C("P06"))
    for yy in range(0, T):                                                   # 동쪽 그늘
        step_px(img, 21, yy, -1); step_px(img, 22, yy, -1)
    return img


def terrain_tiles():
    out = {}
    sw = S.scrap_wall(6, 1, seed=11)                                         # 고철 장벽 정면(봉천 정착지 담, 0-10과 같은 그림)
    for i in range(6):
        out[f"tr:scrap_face{i}"] = sw.crop((i * T, 0, i * T + T, T))
    for v in range(2):
        out[f"tr:scrap_top{v}"] = scrap_top(v)
    for col in "lmr":
        for v in range(3 if col == "m" else 1):
            out[f"tr:cliff_{col}{v}"] = cliff_face(col, v)
    out["tr:cstair"] = cliff_stair()
    for m in range(1, 8):
        out[f"tr:brink{m}"] = brink(m)
    for v in range(2):
        out[f"tr:fort_face{v}"] = fort("face", v)
    out["tr:fort_top"] = fort("top")
    for v in range(2):
        out[f"tr:fort_mid{v}"] = fort_course("mid", v)
        out[f"tr:fort_bot{v}"] = fort_course("bot", v)
    for m in range(16):
        out[f"tr:deck{m}"] = deck(m)
        out[f"tr:deckb{m}"] = deck(m, broken=True)
    return out


# ================================================================================================ 스킨 표
# 스킨: 양식 · 정면 함수 · 행 종류 · 열 변형 수 · 1층 특수 칸 · 옥상
SKINS = {
    "villa_brick": {"style": "villa", "wall": "brick", "roof": ("flat", "green")},
    "villa_brickdk": {"style": "villa", "wall": "brick_dk", "roof": ("flat", "grey")},
    "villa_plaster": {"style": "villa", "wall": "plaster", "roof": ("flat", "green")},
    "villa_tile": {"style": "villa", "wall": "tile", "roof": ("flat", "grey")},
    "apt_blue": {"style": "apt", "wall": "apt", "brand": "P45", "roof": ("flat", "grey")},
    "apt_green": {"style": "apt", "wall": "apt_dk", "brand": "P36", "roof": ("flat", "grey")},
    "apt_red": {"style": "apt", "wall": "apt", "brand": "P53", "roof": ("flat", "tar")},
    "shop_tile": {"style": "shop", "wall": "tile", "roof": ("flat", "grey")},
    "shop_plaster": {"style": "shop", "wall": "plaster", "roof": ("flat", "tar")},
    "office": {"style": "office", "wall": "glass", "roof": ("flat", "metal")},
    "factory_steel": {"style": "factory", "wall": "steel", "roof": ("rib", "metal")},
    "factory_rust": {"style": "factory", "wall": "rust", "roof": ("rib", "red")},
    "gov": {"style": "gov", "wall": "stone", "roof": ("flat", "grey")},
    "base": {"style": "base", "wall": "olive", "roof": ("flat", "olive")},
    "house_mint": {"style": "house", "wall": "mint", "roof": ("pitch", "metal")},
    "house_plaster": {"style": "house", "wall": "plaster", "roof": ("pitch", "red")},
    "house_brick": {"style": "house", "wall": "brick", "roof": ("pitch", "green")},
}
NV = 4                     # 가운데 열 변형 수(행마다)
NR = 4                     # 옥상 가운데 변형 수
ROWS = {"villa": ["top", "mid", "bot", "solo"], "house": ["top", "mid", "bot", "solo"], "apt": ["top", "mid", "low", "bot"],
        "shop": ["top", "mid", "bot", "solo"], "office": ["top", "mid", "bot", "solo"], "factory": ["top", "mid", "bot", "solo"],
        "gov": ["top", "mid", "bot", "solo"], "base": ["top", "mid", "bot", "solo"]}


def _face(sk, row, col, var, seed, **kw):
    st, wall = sk["style"], sk["wall"]
    if st in ("villa", "house"):
        return face_villa(wall, row, col, var, seed, **kw)
    if st == "apt":
        return face_apt(wall, row, col, var, seed, brand=sk["brand"], **kw)
    if st == "shop":
        return face_shop(wall, row, col, var, seed, **kw)
    if st == "office":
        return face_office(row, col, var, seed)
    if st == "factory":
        return face_factory(wall, row, col, var, seed, **kw)
    if st == "gov":
        return face_gov(row, col, var, seed, **kw)
    return face_base(row, col, var, seed, **kw)


def build():
    """→ (타일 dict 이름 → 32×32, 스킨 표 dict). 스킨 표는 굽기가 칸마다 고를 부위 이름 목록이다."""
    tiles, table = {}, {}
    for si, (name, sk) in enumerate(SKINS.items()):
        seed = hsh(si, 977)
        st = sk["style"]
        ent = {"style": st, "rows": {}, "special": {}, "roof": {}}
        for row in ROWS[st]:
            for col in "lmr":
                nv = NV if col == "m" else 2
                lst = []
                for v in range(nv):
                    kw = {}
                    if st == "shop" and row in ("bot", "solo"):
                        kw["front"] = ["glass", "shutter", "half", "broken"][v % 4]
                    if st == "shop" and row != "bot":
                        for sg in range(len(SIGN_COLS)):                       # 간판 색은 층마다 하나(굽기가 색을 고정)
                            nm = f"{name}:{row}_{col}{v}s{sg}"
                            tiles[nm] = _face(sk, row, col, v, seed, sign=sg, **kw)
                            lst.append(nm)
                        continue
                    nm = f"{name}:{row}_{col}{v}"
                    tiles[nm] = _face(sk, row, col, v, seed, **kw)
                    lst.append(nm)
                ent["rows"][f"{row}_{col}"] = lst
        sp = ent["special"]                                                   # 1층 특수 칸(문·현관·셔터·경광등·가스관 열)
        if st in ("villa", "house"):
            for row in ("bot", "solo"):
                for k in ("steel", "open"):
                    nm = f"{name}:{row}_door_{k}"
                    tiles[nm] = face_villa(sk["wall"], row, "m", 1, seed, door=k)
                    sp.setdefault(f"{row}_door", []).append(nm)
            for row in ROWS[st]:
                nm = f"{name}:{row}_pipe"
                tiles[nm] = face_villa(sk["wall"], row, "m", 0, seed, pipe=True)
                sp[f"{row}_pipe"] = [nm]
        elif st == "apt":
            nm = f"{name}:bot_entry"
            tiles[nm] = face_apt(sk["wall"], "bot", "m", 0, seed, brand=sk["brand"], door="entry")
            sp["bot_door"] = [nm]
        elif st == "factory":
            for row in ("bot", "solo"):
                for k in ("shutter_l", "shutter_r", "steel"):
                    nm = f"{name}:{row}_{k}"
                    tiles[nm] = face_factory(sk["wall"], row, "m", 1, seed, door=k)
                    sp[f"{row}_{k}"] = [nm]
        elif st == "gov":
            for row in ("bot", "solo"):
                for k in ("door", "barrier"):
                    nm = f"{name}:{row}_{k}"
                    tiles[nm] = face_gov(row, "m", 1, seed, door=k)
                    sp[f"{row}_{k}"] = [nm]
            for row in ("top", "solo"):
                nm = f"{name}:{row}_lamp"
                tiles[nm] = face_gov(row, "m", 0, seed, lamp=True)
                sp[f"{row}_lamp"] = [nm]
        elif st == "base":
            for row in ("bot", "solo"):
                nm = f"{name}:{row}_blast"
                tiles[nm] = face_base(row, "m", 0, seed, door="blast")
                sp[f"{row}_door"] = [nm]
        kind, paint = sk["roof"]
        rf = ent["roof"]
        rf["kind"] = kind
        if kind == "pitch":
            for part in ("n", "ns", "ridge", "ss"):
                for col in "lmr":
                    lst = []
                    for v in range(NR if col == "m" else 1):
                        nm = f"{name}:rp_{part}_{col}{v}"
                        tiles[nm] = roof_pitch(paint, part, col, v, seed)
                        lst.append(nm)
                    rf[f"{part}_{col}"] = lst
        else:
            fn = roof_tile if kind == "flat" else roof_rib
            for pos in ("nw", "n", "ne", "w", "c", "e"):
                lst = []
                for v in range(NR if pos in ("n", "c") else 1):
                    nm = f"{name}:rf_{pos}{v}"
                    tiles[nm] = fn(paint, pos, v, seed)
                    lst.append(nm)
                rf[pos] = lst
        table[name] = ent
    deco = roof_deco()
    for k, im in deco.items():
        tiles[f"rd:{k}"] = im
    table["_deco"] = sorted(deco)
    tiles.update(terrain_tiles())
    return tiles, table


def atlas(tiles, cols=32):
    names = list(tiles)
    rows = (len(names) + cols - 1) // cols
    img = Image.new("RGBA", (cols * T, rows * T), (0, 0, 0, 0))
    pos = {}
    for i, n in enumerate(names):
        x, y = i % cols, i // cols
        img.alpha_composite(tiles[n], (x * T, y * T))
        pos[n] = [x, y]
    return img, pos


if __name__ == "__main__":
    t, tb = build()
    im, pos = atlas(t)
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ts_world_bld.png"
    im.save(out)
    print("건물 타일 %d칸 · 스킨 %d · 아틀라스 %dx%d" % (len(t), len(SKINS), im.width, im.height))
