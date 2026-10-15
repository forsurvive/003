"""고가 도로 타일(단계 1-Re, SD-21 §6.1 · SD-16 §6.5 '층 1 상판'·§3.1 '남쪽 정면만'): 월드 구조 타일셋(ts_world)에 들어간다.

두 층으로 그린다.
  · 위층(상판 층, 인물 위 z 2 — 층 0 인물을 가린다. 주인공이 그 아래에 서면 둘레가 디더 50%로 비친다):
      ev:deck{v}        아스팔트 노면(균열·땜질·포트홀·기름 얼룩·신축 이음)
      ev:rail{s}        방호벽 칸: s = 노면이 닿은 변(북1 동2 남4 서8). 방호벽은 노면 쪽 변에 붙고, 바깥은 비어 땅이 보인다.
                        노면이 북쪽에 있는 칸(상판 남쪽 끝)은 방호벽 바깥 면 + 상판 옆면(거더)을 정면으로 그린다(남쪽 정면만, §3.1).
      ev:railc{c}       모서리 칸: 노면이 대각(북동1 남동2 남서4 북서8)에만 닿는다
      ev:brk{g}{v}      끊긴 경간 끝 노면: g = 무너진 쪽 변 — 깨진 단면 + 삐져나온 철근
      ev:car_{a}{v}     상판 위 버려진 차(층 1 막힘·엄폐): 동서 2칸(l·r) · 남북 2칸(t·b)
  · 아래층(인물 아래 z -8):
      ev:shade          상판 아래 그늘(디더 구멍으로 보인다)
      ev:under{v}       상판 남쪽 끝 바로 앞 칸: 상판 아래 빈 공간(위가 짙은 그늘) — 안쪽 기둥 그림자가 비친다(under_p)
      ev:pbase          기둥 밑동(층 0 막힘 칸, 디더 구멍으로 보인다)
      ev:ramp{h}{v}     램프 노면: h 0~3 높이 단(높을수록 밝고 오르막 화살 표시)
      ev:rwall{s}_{h}   램프 옹벽: s = 램프가 닿은 변. 남쪽 정면 높이가 h에 따라 자란다
      ev:stair_{o}{p}   비상계단(강철 격자): o ns(남북으로 내려감) · ew(동서) / p top 층계참 · mid 디딤판 · bot 끝
      ev:rubble{v}      무너진 경간 밑 잔해(콘크리트 판·철근)
타일 경계를 넘는 무늬는 32px 주기(신축 이음·차선 없음)만 쓴다 — 고가가 휘어도 어느 칸끼리 붙여도 이음매가 없다.
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import struct_r01 as S

T = 32
C = S.C
INK = "P01"
hsh, step_px = S.hsh, S.step_px


def new(fill=None):
    return Image.new("RGBA", (T, T), C(fill) if fill else (0, 0, 0, 0))


def _asphalt(img, rnd, box=(0, 0, T - 1, T - 1), base="P03"):
    """노면: 바탕 + 골재 점(밝음·어두움) — 칸마다 다른 점, 줄무늬 없음"""
    d = ImageDraw.Draw(img)
    d.rectangle(box, fill=C(base))
    x0, y0, x1, y1 = box
    n = max(1, (x1 - x0 + 1) * (y1 - y0 + 1) // 22)
    for _ in range(n):
        x, y = rnd.randint(x0, x1), rnd.randint(y0, y1)
        img.putpixel((x, y), C(rnd.choice(["P02", "P04", "P04", "P02", "P05"])))


def deck_surface(v=0):
    """상판 노면 6종: 0 맨 노면 · 1 균열 · 2 땜질 판 · 3 포트홀 · 4 기름 얼룩 · 5 신축 이음(강판)"""
    rnd = random.Random(hsh(v, 811))
    img = new()
    _asphalt(img, rnd)
    d = ImageDraw.Draw(img)
    px = img.load()
    if v == 1:                                                               # 그물 균열
        x, y = rnd.randint(4, 10), rnd.randint(3, 8)
        for _ in range(26):
            px[x, y] = C("P01")
            if rnd.random() < 0.3:
                px[min(T - 1, x + 1), y] = C("P02")
            x = max(1, min(T - 2, x + rnd.choice([0, 1, 1])))
            y = max(1, min(T - 2, y + rnd.choice([0, 1, 1, 1])))
    elif v == 2:                                                             # 땜질한 판(조금 밝은 아스팔트)
        d.rectangle([6, 9, 23, 21], fill=C("P04"))
        d.line([6, 9, 23, 9], fill=C("P05")); d.line([6, 21, 23, 21], fill=C("P02")); d.line([23, 9, 23, 21], fill=C("P02"))
        for _ in range(10):
            px[rnd.randint(7, 22), rnd.randint(10, 20)] = C(rnd.choice(["P03", "P05"]))
    elif v == 3:                                                             # 포트홀: 패인 구멍 + 물
        d.ellipse([10, 11, 22, 19], fill=C("P02"))
        d.ellipse([11, 12, 21, 18], fill=C("P01"))
        d.ellipse([13, 14, 19, 17], fill=C("P34"))
        d.line([11, 19, 21, 19], fill=C("P05"))                              # 아래 턱(빛)
        px[15, 15] = C("P36")
    elif v == 4:                                                             # 기름 얼룩
        for y in range(10, 22):
            for x in range(8, 24):
                if ((x - 16) / 8.0) ** 2 + ((y - 16) / 5.5) ** 2 < 1.0 and (x + y) % 3:
                    px[x, y] = C("P02")
        px[13, 14] = C("P13"); px[18, 17] = C("P12")                         # 기름 무지개 한두 점
    elif v == 5:                                                             # 신축 이음: 가로 강판 띠(32px 주기 — 가로로 이어진다)
        d.rectangle([0, 13, T - 1, 18], fill=C("P05"))
        for x in range(0, T, 4):
            d.line([x, 14, x + 1, 14], fill=C("P06"))
        d.line([0, 13, T - 1, 13], fill=C("P06")); d.line([0, 18, T - 1, 18], fill=C("P02"))
        for x in (3, 19):
            px[x, 16] = C("P24"); px[x + 1, 16] = C("P25")                 # 녹
    return img


def _barrier_h(img, y0, face=True, outer_face=False):
    """가로 방호벽(뉴저지형): 위 갓(밝음) + 앞면(남쪽에서 보이는 면). y0 = 갓 윗줄"""
    d = ImageDraw.Draw(img)
    d.rectangle([0, y0, T - 1, y0 + 3], fill=C("P08"))
    d.line([0, y0, T - 1, y0], fill=C("P09"))
    d.line([0, y0 - 1, T - 1, y0 - 1], fill=C(INK))
    if face:
        d.rectangle([0, y0 + 4, T - 1, y0 + 9], fill=C("P07"))
        d.line([0, y0 + 4, T - 1, y0 + 4], fill=C("P06"))
        d.line([0, y0 + 9, T - 1, y0 + 9], fill=C("P05" if not outer_face else "P04"))
        for x in range(2, T, 16):                                             # 이음 줄(32px 주기 둘)
            d.line([x, y0 + 4, x, y0 + 9], fill=C("P06"))
        for x in range(5, T, 11):
            step_px(img, x, y0 + 7, -1); step_px(img, x, y0 + 8, -1)          # 물 얼룩


def _barrier_v(img, x0, east_lit=True):
    """세로 방호벽: 위에서 본 갓(밝음) + 동쪽 그늘 띠"""
    d = ImageDraw.Draw(img)
    d.rectangle([x0, 0, x0 + 7, T - 1], fill=C("P08"))
    d.line([x0, 0, x0, T - 1], fill=C("P09"))
    d.line([x0 + 6, 0, x0 + 6, T - 1], fill=C("P07"))
    d.line([x0 + 7, 0, x0 + 7, T - 1], fill=C("P06"))
    d.line([x0 - 1, 0, x0 - 1, T - 1], fill=C(INK))
    d.line([x0 + 8, 0, x0 + 8, T - 1], fill=C(INK))
    for y in range(4, T, 16):
        d.line([x0, y, x0 + 7, y], fill=C("P07"))


def _girder(img, y0, rnd):
    """상판 옆면(남쪽 정면): 콘크리트 거더 — 아래로 녹물·물때가 흐른다. y0..31"""
    d = ImageDraw.Draw(img)
    d.rectangle([0, y0, T - 1, T - 1], fill=C("P05"))
    d.line([0, y0, T - 1, y0], fill=C("P06"))
    d.line([0, T - 2, T - 1, T - 2], fill=C("P04"))
    d.line([0, T - 1, T - 1, T - 1], fill=C(INK))
    for x in range(0, T, 16):                                                 # 거더 이음(32px 주기 둘)
        d.line([x + 9, y0 + 1, x + 9, T - 3], fill=C("P04"))
    for _ in range(3):
        x = rnd.randint(1, T - 2)
        S.streak(img, x, y0 + 2, rnd.randint(4, T - y0 - 3), -1, rnd)
    if rnd.random() < 0.5:
        x = rnd.randint(4, T - 6)
        S.streak(img, x, y0 + 1, rnd.randint(5, 10), 0, rnd)
        for k in range(rnd.randint(4, 8)):
            if 0 <= y0 + 1 + k < T:
                img.putpixel((x, y0 + 1 + k), C("P24" if k > 2 else "P25"))


def rail(s, v=0):
    """방호벽 칸. s = 노면이 닿은 변(북1 동2 남4 서8). 바깥 쪽은 비워 둔다(상판 밖 = 아래 땅이 보인다)."""
    rnd = random.Random(hsh(s, v, 823))
    img = new()
    px = img.load()
    # 1) 노면이 닿은 쪽부터 방호벽 안쪽까지 상판(아스팔트) — 방호벽이 노면 끝에 붙는다
    fill = [[False] * T for _ in range(T)]
    if s & 4:                                                                 # 노면이 남쪽 = 상판 북쪽 끝: 방호벽은 아래쪽(노면 쪽)
        for y in range(18, T):
            for x in range(T):
                fill[y][x] = True
    if s & 1:                                                                 # 노면이 북쪽 = 상판 남쪽 끝: 방호벽은 위, 그 아래 거더 정면
        for y in range(0, T):
            for x in range(T):
                fill[y][x] = True
    if s & 8:                                                                 # 노면이 서쪽 = 상판 동쪽 끝
        for y in range(T):
            for x in range(0, 14):
                fill[y][x] = True
    if s & 2:                                                                 # 노면이 동쪽 = 상판 서쪽 끝
        for y in range(T):
            for x in range(18, T):
                fill[y][x] = True
    tmp = new()
    _asphalt(tmp, rnd)
    tp = tmp.load()
    for y in range(T):
        for x in range(T):
            if fill[y][x]:
                px[x, y] = tp[x, y]
    # 2) 방호벽
    if s & 8:
        _barrier_v(img, 2)
        for y in range(T):                                                    # 동쪽 상판 옆 띠(SD-16 §3.1 측면 2~4px)
            px[11, y] = C("P05"); px[12, y] = C("P04"); px[13, y] = C(INK)
    if s & 2:
        _barrier_v(img, 22)
        for y in range(T):
            px[18, y] = C(INK); px[19, y] = C("P06"); px[20, y] = C("P05")
    if s & 4:
        _barrier_h(img, 19, face=True)                                       # 안쪽 면(노면 쪽 = 남쪽) — 보인다
        d = ImageDraw.Draw(img)
        d.line([0, 18, T - 1, 18], fill=C(INK))
    if s & 1:
        _barrier_h(img, 1, face=True, outer_face=True)                       # 바깥 면(남쪽, 화면 쪽)
        _girder(img, 11, rnd)
    if (s & 1) and (s & 8):                                                   # 남동 모서리: 거더 끝 그늘
        for y in range(11, T):
            step_px(img, 11, y, -1)
    return img


def rail_corner(c, v=0):
    """모서리 칸: 노면이 대각(북동1 남동2 남서4 북서8)에만 닿는다 — 그 모서리에 방호벽 끝 기둥, 남쪽 끝이면 거더 정면"""
    rnd = random.Random(hsh(c, v, 829))
    img = new()
    d = ImageDraw.Draw(img)
    for bit, (x0, y0) in ((1, (18, 0)), (2, (18, 18)), (4, (0, 18)), (8, (0, 0))):
        if not c & bit:
            continue
        tmp = new()
        _asphalt(tmp, rnd)
        img.paste(tmp.crop((x0, y0, x0 + 14, y0 + 14)), (x0, y0))
        d.rectangle([x0 + 2, y0 + 2, x0 + 11, y0 + 11], fill=C("P08"))       # 방호벽 끝 기둥
        d.rectangle([x0 + 2, y0 + 2, x0 + 11, y0 + 11], outline=C(INK))
        d.line([x0 + 3, y0 + 3, x0 + 10, y0 + 3], fill=C("P09"))
        d.line([x0 + 3, y0 + 9, x0 + 10, y0 + 9], fill=C("P06"))
        if bit in (1, 8):                                                     # 노면이 북쪽 대각 = 상판 남쪽 모서리: 거더 정면
            gx0, gx1 = (x0, x0 + 13)
            g = new()
            _girder(g, 14, rnd)
            img.paste(g.crop((gx0, 14, gx1 + 1, T)), (gx0, 14))
    return img


def broken(g, v=0):
    """끊긴 경간 끝 노면. g = 무너진 쪽 변(북1 동2 남4 서8): 그 변이 들쭉날쭉 깨지고 철근이 삐져나온다(그 너머는 비었다)"""
    rnd = random.Random(hsh(g, v, 839))
    img = deck_surface(v % 3)
    px = img.load()
    for side in (1, 2, 4, 8):
        if not g & side:
            continue
        cut = [rnd.randint(3, 10) for _ in range(T)]
        for i in range(T):
            c = cut[i] if i % 3 else cut[max(0, i - 1)]
            for k in range(0, 12):
                x, y = {1: (i, k), 4: (i, T - 1 - k), 8: (k, i), 2: (T - 1 - k, i)}[side]
                if k < c:
                    px[x, y] = (0, 0, 0, 0)
                elif k == c:
                    px[x, y] = C(INK)
                elif k == c + 1:
                    px[x, y] = C("P07")                                     # 깨진 단면(밝은 콘크리트)
                elif k == c + 2 and side == 4:
                    px[x, y] = C("P06")
        for i in range(3, T - 3, 6):                                         # 철근
            c = cut[i]
            for k in range(max(0, c - 4), c):
                x, y = {1: (i, k), 4: (i, T - 1 - k), 8: (k, i), 2: (T - 1 - k, i)}[side]
                px[x, y] = C("P25" if k > c - 3 else "P24")
    return img


CAR_PAINT = [("P44", "P45", "P43"), ("P25", "P26", "P24"), ("P30", "P31", "P29"), ("P07", "P08", "P06")]


def car(a, v=0):
    """상판 위 버려진 차(2칸). a: l·r = 동서로 선 차의 왼·오른 칸, t·b = 남북으로 선 차의 위·아래 칸.
    녹슨 차체 + 깨진 유리 + 바람 빠진 타이어, 남쪽 면만 정면(3/4 시점)."""
    rnd = random.Random(hsh(v, 853))
    big = Image.new("RGBA", (64, 32) if a in "lr" else (32, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    hi, lt, lo = CAR_PAINT[v % len(CAR_PAINT)]
    if a in "lr":
        d.rectangle([4, 9, 59, 27], fill=C(lo))                              # 차체 옆면(남쪽)
        d.rectangle([4, 5, 59, 17], fill=C(hi))                              # 지붕·보닛 윗면
        d.rectangle([16, 6, 45, 14], fill=C("P12"))                          # 앞뒤 유리 + 지붕
        d.rectangle([22, 7, 39, 13], fill=C(lt))
        d.line([16, 6, 45, 6], fill=C("P13"))
        d.rectangle([4, 18, 59, 22], fill=C(lt))                             # 옆 창 띠
        for x0 in (18, 32):
            d.rectangle([x0, 18, x0 + 11, 22], fill=C("P11"))
        d.line([24, 19, 27, 21], fill=C("P14"))                              # 깨진 유리 금
        for cx in (13, 50):                                                  # 바퀴(바람 빠짐 — 아래가 납작)
            d.rectangle([cx - 5, 23, cx + 5, 29], fill=C("P02"))
            d.rectangle([cx - 2, 24, cx + 2, 27], fill=C("P05"))
        d.rectangle([4, 5, 59, 28], outline=C(INK))
        d.line([5, 27, 58, 27], fill=C("P02"))
        for _ in range(26):                                                  # 녹
            x, y = rnd.randint(5, 58), rnd.randint(6, 26)
            if big.getpixel((x, y))[3]:
                big.putpixel((x, y), C(rnd.choice(["P24", "P25", "P26"])))
        part = big.crop((0, 0, 32, 32) if a == "l" else (32, 0, 64, 32))
    else:
        d.rectangle([5, 6, 26, 55], fill=C(hi))                              # 위에서 본 차체(남북)
        d.rectangle([5, 50, 26, 59], fill=C(lo))                             # 남쪽 끝 면(정면)
        d.rectangle([8, 16, 23, 24], fill=C("P12"))                          # 앞유리
        d.rectangle([8, 36, 23, 42], fill=C("P11"))                          # 뒷유리
        d.rectangle([8, 25, 23, 35], fill=C(lt))                             # 지붕
        d.line([9, 17, 14, 22], fill=C("P14"))
        for cy in (12, 44):
            d.rectangle([2, cy, 5, cy + 7], fill=C("P02")); d.rectangle([26, cy, 29, cy + 7], fill=C("P02"))
        d.rectangle([5, 6, 26, 59], outline=C(INK))
        d.rectangle([7, 52, 11, 54], fill=C("P53")); d.rectangle([20, 52, 24, 54], fill=C("P53"))   # 미등
        for _ in range(26):
            x, y = rnd.randint(6, 25), rnd.randint(7, 58)
            if big.getpixel((x, y))[3]:
                big.putpixel((x, y), C(rnd.choice(["P24", "P25", "P26"])))
        part = big.crop((0, 0, 32, 32) if a == "t" else (0, 32, 32, 64))
    base = deck_surface((v + 1) % 3)
    base.alpha_composite(part)
    return base


def lane(o, kind="dash"):
    """차선 칸: o 0 동서 · 1 남북 · 2 북동-남서 · 3 북서-남동. kind dash 흰 점선(낡음) · center 노란 겹선(중앙선).
    노면 위에 덧그린다(바탕 = 맨 노면). 점선의 끊김은 굽기가 칸을 건너뛰어 만든다."""
    rnd = random.Random(hsh(o, len(kind), 887))
    img = deck_surface(0)
    px = img.load()
    cols = ["P08", "P07"] if kind == "dash" else ["P49", "P48"]
    offs = [0] if kind == "dash" else [-2, 2]
    for off in offs:
        for t in range(T):
            if kind == "dash" and rnd.random() < 0.18:                         # 닳아 끊긴 페인트
                continue
            if o == 0:
                pts = [(t, 15 + off), (t, 16 + off)]
            elif o == 1:
                pts = [(15 + off, t), (16 + off, t)]
            elif o == 2:
                pts = [(t, T - 1 - t + off), (t, min(T - 1, T - t + off))]
            else:
                pts = [(t, t + off), (t, min(T - 1, t + 1 + off))]
            for k, (x, y) in enumerate(pts):
                if 0 <= x < T and 0 <= y < T:
                    px[x, y] = C(cols[k])
    return img


def shade2():
    """상판 그림자 끝(남쪽 둘째 줄): 옅은 디더"""
    img = new()
    px = img.load()
    for y in range(T):
        for x in range(T):
            if (x + y) % 2 == 0 and y < 20:
                px[x, y] = P.rgb("P01") + (70,)
    return img


# ------------------------------------------------------------------------------------------------ 아래층
def shade():
    img = Image.new("RGBA", (T, T), P.rgb("P01") + (118,))
    return img


def under(v=0, pillar=False):
    """상판 남쪽 끝 앞 칸 = 상판 아래 빈 공간: 위(상판 밑면 바로 아래)일수록 짙은 그늘, 아래는 옅다.
    pillar: 안쪽 기둥이 그늘 속에 어둡게 비친다(충돌 없는 먼 그림 — 실제 기둥은 상판 가운데 줄)."""
    rnd = random.Random(hsh(v, int(pillar), 857))
    img = new()
    px = img.load()
    ink = P.rgb("P01")
    for y in range(T):
        a = int(150 - 110 * (y / (T - 1)))
        for x in range(T):
            if y > 20 and (x + y) % 2:                                       # 아래쪽은 디더로 끝을 흐린다
                continue
            px[x, y] = ink + (a,)
    if pillar:
        x0 = 10 + rnd.randint(-2, 2)
        for y in range(0, T - 3):
            for x in range(x0, x0 + 12):
                px[x, y] = P.rgb("P03" if x < x0 + 9 else "P02") + (255,)
            px[x0, y] = P.rgb("P04") + (255,)
        for x in range(x0 - 2, x0 + 14):                                     # 밑동 그늘
            px[x, T - 3] = ink + (160,)
            px[x, T - 2] = ink + (100,)
    if v % 2 == 1:                                                           # 매달린 전선·물방울
        for y in range(0, 9):
            px[22 + (y // 3) % 2, y] = P.rgb("P02") + (255,)
    return img


def pillar_base():
    """기둥 밑동(층 0에서 막히는 칸) — 위에서 본 콘크리트 기둥 + 남쪽 정면 한 뼘"""
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([3, 2, 28, 24], fill=C("P06"))
    d.line([3, 2, 28, 2], fill=C("P08"))
    d.line([3, 2, 3, 24], fill=C("P07"))
    d.rectangle([3, 25, 28, 30], fill=C("P05"))                              # 남쪽 면
    d.line([3, 30, 28, 30], fill=C("P03"))
    d.rectangle([3, 2, 28, 30], outline=C(INK))
    for y in range(6, 24, 6):
        d.line([4, y, 27, y], fill=C("P05"))                                 # 거푸집 자국
    img.putpixel((9, 27), C("P24")); img.putpixel((9, 28), C("P24"))
    return img


def ramp(h, v=0):
    """램프 노면: 높이 단 h(0 바닥 ~ 3 상판 직전)에 따라 밝아진다. v 1이면 낡은 오르막 화살표(흰 페인트)"""
    rnd = random.Random(hsh(h, v, 859))
    img = new()
    base = ["P03", "P03", "P04", "P04"][h]
    _asphalt(img, rnd, base=base)
    px = img.load()
    if h >= 2:                                                               # 높은 쪽: 밝은 점을 더(빛을 더 받는다)
        for _ in range(14):
            px[rnd.randint(0, T - 1), rnd.randint(0, T - 1)] = C("P05")
    if v == 1:
        for (x, y) in [(15, 9), (16, 9), (14, 10), (17, 10), (13, 11), (18, 11), (15, 10), (16, 10)]:
            if rnd.random() < 0.8:
                px[x, y] = C("P07")
        for y in range(11, 20):
            if rnd.random() < 0.75:
                px[15, y] = C("P07"); px[16, y] = C("P07")
    return img


def rwall(s, h):
    """램프 옹벽 칸: s = 램프 노면이 닿은 변. 낮은 콘크리트 벽 갓 + 남쪽 정면(높이 단 h만큼 자란다)"""
    rnd = random.Random(hsh(s, h, 863))
    img = new()
    d = ImageDraw.Draw(img)
    face = 2 + 5 * h                                                         # 남쪽 정면 높이(px)
    if s & 4:                                                                # 램프가 남쪽: 벽은 위쪽, 안쪽(남) 면이 보인다
        d.rectangle([0, 14, T - 1, 19], fill=C("P07")); d.line([0, 14, T - 1, 14], fill=C("P08"))
        d.rectangle([0, 20, T - 1, T - 1], fill=C("P06")); d.line([0, 13, T - 1, 13], fill=C(INK))
    if s & 1:                                                                # 램프가 북쪽: 벽은 아래, 바깥(남) 정면이 땅까지
        d.rectangle([0, 0, T - 1, 5], fill=C("P07")); d.line([0, 0, T - 1, 0], fill=C("P08"))
        y1 = min(T - 1, 6 + face)
        d.rectangle([0, 6, T - 1, y1], fill=C("P05"))
        d.line([0, 6, T - 1, 6], fill=C("P06"))
        d.line([0, y1, T - 1, y1], fill=C(INK))
        for x in range(4, T, 8):
            d.line([x, 7, x, y1 - 1], fill=C("P04"))                         # 옹벽 블록 줄
        for _ in range(2):
            S.streak(img, rnd.randint(1, T - 2), 7, max(1, face - 1), -1, rnd)
    if s & 8:                                                                # 램프가 서쪽: 벽은 동쪽 띠
        d.rectangle([4, 0, 11, T - 1], fill=C("P07")); d.line([4, 0, 4, T - 1], fill=C("P08"))
        d.line([12, 0, 12, T - 1], fill=C(INK)); d.line([3, 0, 3, T - 1], fill=C(INK))
        for x in range(13, 13 + min(4, 1 + h)):
            d.line([x, 0, x, T - 1], fill=C("P05"))                          # 동쪽 옆면 띠(높을수록 두껍다)
    if s & 2:                                                                # 램프가 동쪽: 벽은 서쪽 띠
        d.rectangle([20, 0, 27, T - 1], fill=C("P07")); d.line([20, 0, 20, T - 1], fill=C("P08"))
        d.line([28, 0, 28, T - 1], fill=C(INK)); d.line([19, 0, 19, T - 1], fill=C(INK))
    if s == 0:                                                               # 모서리
        d.rectangle([10, 10, 21, 21], fill=C("P07")); d.rectangle([10, 10, 21, 21], outline=C(INK))
    return img


def stair(o, p):
    """비상계단(강철 격자). o: ns 남북으로 오르내림 · ew 동서. p: top 상판 쪽 층계참 · mid 디딤판 · bot 땅 쪽 끝"""
    img = new()
    d = ImageDraw.Draw(img)
    rust = ["P24", "P25"]
    if o == "ns":
        d.rectangle([5, 0, 26, T - 1], fill=C("P04"))
        if p == "top":
            for y in range(0, T, 3):                                         # 격자 층계참
                d.line([6, y, 25, y], fill=C("P05"))
            for x in range(6, 26, 3):
                d.line([x, 0, x, T - 1], fill=C("P03"))
        else:
            for y in range(1, T, 5):                                         # 디딤판(위가 밝다)
                d.rectangle([6, y, 25, y + 2], fill=C("P06"))
                d.line([6, y, 25, y], fill=C("P07"))
                d.line([6, y + 3, 25, y + 3], fill=C("P02"))
        d.rectangle([2, 0, 4, T - 1], fill=C("P05")); d.line([2, 0, 2, T - 1], fill=C("P07"))   # 난간
        d.rectangle([27, 0, 29, T - 1], fill=C("P05")); d.line([29, 0, 29, T - 1], fill=C(INK))
        d.line([1, 0, 1, T - 1], fill=C(INK)); d.line([30, 0, 30, T - 1], fill=C(INK))
        if p == "bot":
            d.rectangle([4, T - 4, 27, T - 1], fill=C("P05")); d.line([4, T - 1, 27, T - 1], fill=C(INK))
    else:
        d.rectangle([0, 5, T - 1, 26], fill=C("P04"))
        if p == "top":
            for x in range(0, T, 3):
                d.line([x, 6, x, 25], fill=C("P05"))
            for y in range(6, 26, 3):
                d.line([0, y, T - 1, y], fill=C("P03"))
        else:
            for x in range(1, T, 5):
                d.rectangle([x, 6, x + 2, 25], fill=C("P06"))
                d.line([x, 6, x, 25], fill=C("P07"))
                d.line([x + 3, 6, x + 3, 25], fill=C("P02"))
        d.rectangle([0, 2, T - 1, 4], fill=C("P05")); d.line([0, 2, T - 1, 2], fill=C("P07"))
        d.rectangle([0, 27, T - 1, 29], fill=C("P05")); d.line([0, 29, T - 1, 29], fill=C(INK))
        d.line([0, 1, T - 1, 1], fill=C(INK)); d.line([0, 30, T - 1, 30], fill=C(INK))
    rnd = random.Random(hsh(len(o), len(p), 877))
    for _ in range(9):
        x, y = rnd.randint(2, 29), rnd.randint(1, 30)
        if img.getpixel((x, y))[3]:
            img.putpixel((x, y), C(rnd.choice(rust)))
    return img


def rubble(v=0):
    """무너진 경간 밑 잔해: 깨진 상판 조각(남쪽 면이 보인다) + 철근 + 아스팔트 부스러기"""
    rnd = random.Random(hsh(v, 881))
    img = new()
    d = ImageDraw.Draw(img)
    for _ in range(3 + v % 2):
        x0, y0 = rnd.randint(0, 18), rnd.randint(2, 18)
        w, h = rnd.randint(8, 14), rnd.randint(5, 9)
        d.polygon([(x0, y0 + 2), (x0 + w, y0), (x0 + w + 1, y0 + h - 2), (x0 + 1, y0 + h)], fill=C("P06"))
        d.line([x0 + 1, y0 + h, x0 + w + 1, y0 + h - 2], fill=C("P04"))
        d.line([x0, y0 + 2, x0 + w, y0], fill=C("P07"))
        d.polygon([(x0, y0 + 2), (x0 + w, y0), (x0 + w + 1, y0 + h - 2), (x0 + 1, y0 + h)], outline=C(INK))
        if rnd.random() < 0.6:                                               # 위 아스팔트 겉
            d.line([x0 + 2, y0 + 2, x0 + w - 1, y0 + 1], fill=C("P03"))
    for _ in range(4):
        x, y = rnd.randint(2, 29), rnd.randint(2, 26)
        for k in range(rnd.randint(3, 6)):
            if 0 <= x + k < T and 0 <= y - k // 2 < T:
                img.putpixel((x + k, y - k // 2), C("P25" if k % 2 else "P24"))
    for _ in range(14):
        img.putpixel((rnd.randint(0, 31), rnd.randint(0, 31)), C(rnd.choice(["P03", "P05", "P06"])))
    return img


def tiles():
    out = {}
    for v in range(6):
        out[f"ev:deck{v}"] = deck_surface(v)
    for s in range(1, 16):
        out[f"ev:rail{s}"] = rail(s)
    for c in range(1, 16):
        out[f"ev:railc{c}"] = rail_corner(c)
    for g in range(1, 16):
        for v in range(2):
            out[f"ev:brk{g}_{v}"] = broken(g, v)
    for a in "lrtb":
        for v in range(4):
            out[f"ev:car_{a}{v}"] = car(a, v)
    for o in range(4):
        out[f"ev:lane{o}"] = lane(o)
        out[f"ev:cline{o}"] = lane(o, "center")
    out["ev:shade"] = shade()
    out["ev:shade2"] = shade2()
    for v in range(2):
        out[f"ev:under{v}"] = under(v)
        out[f"ev:under_p{v}"] = under(v, pillar=True)
    out["ev:pbase"] = pillar_base()
    for h in range(4):
        for v in range(2):
            out[f"ev:ramp{h}{v}"] = ramp(h, v)
        for s in range(16):
            out[f"ev:rwall{s}_{h}"] = rwall(s, h)
    for o in ("ns", "ew"):
        for p in ("top", "mid", "bot"):
            out[f"ev:stair_{o}{p}"] = stair(o, p)
    for v in range(4):
        out[f"ev:rubble{v}"] = rubble(v)
    return out


if __name__ == "__main__":
    t = tiles()
    cols = 16
    rows = (len(t) + cols - 1) // cols
    sc = 3
    img = Image.new("RGBA", (cols * (T + 2) * sc, rows * (T + 2) * sc), (60, 90, 60, 255))
    for i, (n, im) in enumerate(t.items()):
        x, y = i % cols, i // cols
        img.alpha_composite(im.resize((T * sc, T * sc), Image.NEAREST), (x * (T + 2) * sc, y * (T + 2) * sc))
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ev_tiles.png"
    img.save(out)
    print("고가 타일 %d칸 → %s" % (len(t), out))
