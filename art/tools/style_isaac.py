"""그림체 비교 샘플: '바인딩 오브 아이작'풍 (2~2.5등신, 큰 머리, 굵은 외곽선, 방 단위 화면).
현행 SD-16 그림체와 같은 장면(볼트 S-07 정문 앞, 주인공·보병 계엄병·큰바퀴)을 다시 그려 나란히 보기 위한 것.
아이작의 캐릭터·몬스터·그림을 베끼지 않는다. 비율·선·면 처리·방 구성 같은 '그림체'만 빌린다.

머리는 구(球)로 보고 픽셀마다 법선을 구해 머리 방향(S·SE·E·NE·N)으로 돌린 뒤, 머리 좌표계에서 머리카락·눈·입을 정한다.
그래서 다섯 방향이 같은 얼굴로 맞물린다. 몸은 다리를 발 위치 표로 그린다(옆: 발 고정 6컷, 앞뒤: 들어 올림 6컷).
색은 전부 마스터 팔레트·피부 S3·머리색 H1·세력 PF-01 안에서 고른다(QA 대상).

출력: samples/17_isaac_*.png·gif, out/isaac/*.png + isaac.json(게임 샘플 장면용)
"""
import os, sys, math, json, random
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLES = os.path.join(ROOT, "samples")
OUT = os.path.join(ROOT, "out", "isaac")
FONT = ImageFont.truetype(os.path.join(ROOT, "fonts", "Galmuri9.ttf"), 10)
CLEAR = (0, 0, 0, 0)
C = lambda t: P.rgb(t) + (255,)
INK = C("P01")
SKIN = [C(c) for c in P.SKIN["S3"]]                       # 0 가장 어두움 … 4 가장 밝음
HAIR = [C(c) for c in P.HAIR["H1"]]
PF1 = [C(c) for c in P.PF["PF-01"]]                       # 주색 4 + 강조 2
SUIT = [C("P43"), C("P44"), C("P45"), C("P46")]
GOLD = [C("P47"), C("P48"), C("P49")]
VIEWS = ("S", "SE", "E", "NE", "N")
YAW = {"S": 0.0, "SE": 38.0, "E": 72.0, "NE": 128.0, "N": 180.0}   # 옆모습은 얼굴을 덜 돌린다(눈이 윤곽에 붙지 않게)
LIGHT = (-0.45, -0.65, 0.62)


def norm(v):
    m = math.sqrt(sum(a * a for a in v))
    return tuple(a / m for a in v)


L = norm(LIGHT)


def ramp4(r, d, lo=0, hi=0.72):
    """빛 세기 d(-1~1) → 램프 색. 아이작풍: 면은 넓게, 단계는 셋."""
    if d > hi:
        return r[min(len(r) - 1, lo + 3)]
    if d > 0.18:
        return r[lo + 2]
    if d > -0.35:
        return r[lo + 1]
    return r[lo]


def outline(img, col=INK, thick_bottom=True):
    """바깥 1px 외곽선. 아래쪽은 한 줄 더(아이작풍 묵직한 밑선)."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            near = any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3]
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if near:
                o[x, y] = col
    if thick_bottom:
        o2 = out.copy().load()
        for y in range(1, h):
            for x in range(w):
                if not o2[x, y][3] and o2[x, y - 1] == col and y - 2 >= 0 and o2[x, y - 2][3] and o2[x, y - 2] != col:
                    o[x, y] = col
    return out


# ---------------------------------------------------------------- head
def head(view, kind="pc", face="idle", W=22, H=20):
    """kind: pc(짧은 검은 머리) / soldier(철모 + 방독면). face: idle / fire(찡그림·입 벌림) / blink"""
    th = math.radians(YAW[view])
    f = (math.sin(th), 0.0, math.cos(th))
    r = (math.cos(th), 0.0, -math.sin(th))
    img = Image.new("RGBA", (W + 2, H + 2), CLEAR)
    px = img.load()
    cx, cy, rx, ry = W / 2 + 1, H / 2 + 1, W / 2, H / 2 - 0.3
    for y in range(H + 2):
        for x in range(W + 2):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            q = nx * nx + ny * ny
            if q > 1.0:
                continue
            nz = math.sqrt(max(0.0, 1.0 - q))
            d = nx * L[0] + ny * L[1] + nz * L[2]
            lx = nx * r[0] + nz * r[2]
            lz = nx * f[0] + nz * f[2]
            ly = ny
            col = None
            if kind == "pc":
                jag = 0.07 if int((lx + 2) * 9) % 2 else -0.04          # 앞머리 끝이 들쭉날쭉
                if lz >= 0.3:
                    hairline = -0.32 + jag
                else:
                    hairline = -0.1 - 0.22 * max(0.0, lz) / 0.3                # 관자놀이
                if lz < -0.12:
                    hairline = 0.62                                       # 뒤통수는 목덜미까지(경계가 세로로 선다)
                if ly < hairline:
                    col = ramp4(HAIR, d)
                elif abs(lz) < 0.2 and -0.02 < ly < 0.32 and abs(lx) > 0.9:
                    col = SKIN[1] if abs(lz) < 0.08 and 0.06 < ly < 0.24 else SKIN[2]   # 귀
            else:                                                       # 철모: 위쪽 반구 + 챙
                if ly < -0.08:
                    col = ramp4(PF1[:4], d)
                elif ly < 0.04:
                    col = PF1[0]                                        # 챙 그림자 띠
                elif lz < 0.18:
                    col = ramp4([C("P01"), C("P02"), C("P02"), C("P03")], d)   # 방독면 밖: 검은 두건
            if col is None:
                col = ramp4(SKIN, d, 0, 0.9) if kind == "pc" else ramp4([C("P03"), C("P04"), C("P05"), C("P06")], d)
            # 얼굴(앞쪽 반구에서만)
            if lz > 0.25:
                for side in (-1, 1):
                    ex, ey = side * 0.36, 0.20
                    if kind == "pc":
                        sx, sy = 0.21, (0.06 if face == "fire" or face == "blink" else 0.27)
                        e = ((lx - ex) / sx) ** 2 + ((ly - ey) / sy) ** 2
                        if e <= 1.0:
                            col = C("P00")
                            if face == "idle" and lx - ex < -0.06 and ly - ey < -0.1 and e > 0.15:
                                col = C("P09")                         # 눈 반짝임(왼쪽 위)
                    else:                                               # 방독면 고글: 테 + 유리
                        e = ((lx - ex) / 0.25) ** 2 + ((ly - ey) / 0.25) ** 2
                        if e <= 1.0:
                            col = C("P02") if e > 0.55 else (C("P62") if ly - ey < 0.02 else C("P61"))
                            if e < 0.18 and lx - ex < 0 and ly - ey < 0:
                                col = C("P63")
                if kind == "pc":
                    if face == "fire":
                        if abs(lx) < 0.16 and 0.50 < ly < 0.72:
                            col = C("P52") if ly > 0.62 else C("P51")  # 입을 벌린다
                    elif abs(lx) < 0.09 and 0.56 < ly < 0.64:
                        col = SKIN[0]
                else:                                                   # 방독면 정화통
                    e = (lx / 0.2) ** 2 + ((ly - 0.62) / 0.2) ** 2
                    if e <= 1.0:
                        col = C("P04") if e > 0.5 else C("P06")
                        if abs(lx) < 0.04 and e < 0.5:
                            col = C("P03")
            px[x, y] = col
    img = outline(img)
    return img


# ---------------------------------------------------------------- body
FOOT_SIDE = [(6, 0), (2, 0), (-2, 0), (-6, 0), (-1, -2), (3, -2)]    # 옆 6컷: 발 x(엉덩이 기준), 들림. 디딤 0~3 = 컷당 -4px
WALK_PX = 4                                                         # 옆·대각 컷당 이동(발 고정과 같은 값)
FB_LIFT = [0, -2, -1, 0, 0, 0]                                      # 앞뒤 6컷: 왼발 들림(오른발은 3컷 어긋남)


def body(view, frame, kind="pc", moving=True):
    """32×32 칸, 발 기준점 (16, 30). 몸통 + 다리 + 팔 끝(손). 머리는 따로 얹는다(머리 위치는 BODY_TOP + 출렁임)."""
    img = Image.new("RGBA", (32, 32), CLEAR)
    d = ImageDraw.Draw(img)
    ramp = SUIT if kind == "pc" else PF1[:4]
    boot = [C("P02"), C("P03")]
    side = view in ("E", "SE", "NE")
    bob = 0 if not moving else (1 if frame % 3 == 0 else 0)          # 디딤 컷에 한 칸 내려앉는다
    hip_y = 25 + bob
    # legs
    legs = []
    if side and moving:
        for k, sh in ((0, 0), (1, 3)):
            fx, lift = FOOT_SIDE[(frame + sh) % 6]
            legs.append((16 + fx, 30 + lift, k))
    elif moving:
        for k, sh in ((0, 0), (1, 3)):
            lift = FB_LIFT[(frame + sh) % 6]
            legs.append((13 + 6 * k, 30 + lift, k))
    else:
        legs = [(14, 30, 0), (18, 30, 1)] if side else [(13, 30, 0), (19, 30, 1)]
    legs.sort(key=lambda t: t[2] if not side else -t[2])               # 옆모습: 먼 다리(1) 먼저
    for fx, fy, k in legs:
        hx = 16 + (k * 2 - 1) * (1 if side else 2)
        far = side and k == 1
        col = ramp[0] if far else ramp[1]
        steps = max(abs(fx - hx), abs(fy - 1 - hip_y))
        for i in range(steps + 1):
            t = i / max(1, steps)
            x = round(hx + (fx - hx) * t)
            y = round(hip_y + (fy - 1 - hip_y) * t)
            d.rectangle([x - 1, y, x, y], fill=col)
        bc = boot[0] if far else boot[1]
        if side:
            d.rectangle([fx - 1, fy - 1, fx + 1, fy - 1], fill=bc)       # 장화는 앞으로 1px 더
        else:
            d.rectangle([fx - 1, fy - 1, fx, fy - 1], fill=bc)
    # torso: 둥근 통(폭 14, 높이 10)
    tw, th = (12, 10) if side else (14, 10)
    x0, y0 = 16 - tw // 2, hip_y - th + 2
    for y in range(th):
        for x in range(tw):
            nx = (x + 0.5 - tw / 2) / (tw / 2)
            ny = (y + 0.5 - th / 2) / (th / 2)
            if nx * nx * 0.9 + max(0, ny) ** 4 + max(0, -ny) ** 2 * 0.6 > 1.0:
                continue
            nz = math.sqrt(max(0.0, 1 - min(1, nx * nx)))
            dd = nx * L[0] + ny * 0.5 * L[1] + nz * L[2]
            img.putpixel((x0 + x, y0 + y), ramp4(ramp, dd))
    # 무늬: 볼트 줄무늬(앞), 등 번호판(뒤), 계엄군은 가슴 띠
    if kind == "pc":
        if view == "S":
            for y in range(y0 + 1, y0 + th - 1):
                img.putpixel((16, y), GOLD[2]); img.putpixel((15, y), GOLD[1])
        elif view == "SE":
            for y in range(y0 + 1, y0 + th - 1):
                img.putpixel((18, y), GOLD[2])
        elif view in ("E", "NE"):
            for y in range(y0 + 1, y0 + th - 1):
                img.putpixel((x0 + tw - 3, y), GOLD[1])
        else:
            d.rectangle([14, y0 + 3, 17, y0 + 5], fill=GOLD[1])            # 등 번호판
            d.point((15, y0 + 4), fill=SUIT[0]); d.point((17, y0 + 4), fill=SUIT[0])
        belt = SUIT[0]
    else:
        if view != "N":
            d.line([x0 + 2, y0 + 2, x0 + tw - 3, y0 + th - 3], fill=PF1[5])  # 탄띠
        belt = C("P17")
    d.line([x0 + 1, hip_y - 1, x0 + tw - 2, hip_y - 1], fill=belt)
    # hands: 몸통 양옆 피부 2×2(걸을 때 앞뒤로 흔든다)
    sw = 0 if not moving else [1, 1, 0, -1, -1, 0][frame % 6]
    hand = SKIN[3] if kind == "pc" else C("P03")
    if side:
        d.rectangle([16 + sw * 2, hip_y - 3, 17 + sw * 2, hip_y - 2], fill=hand)
    else:
        d.rectangle([x0 - 1, hip_y - 4 + sw, x0, hip_y - 3 + sw], fill=hand)
        d.rectangle([x0 + tw - 1, hip_y - 4 - sw, x0 + tw, hip_y - 3 - sw], fill=hand)
    img = outline(img, thick_bottom=False)
    return img, y0 + 4 - 22                                           # 머리 윗변 y(머리 아랫변이 몸통 위 4px를 덮는다)


# ---------------------------------------------------------------- guns (손에 든 무기, 조준 방향 8개 중 5개 그림 + 반전)
def gun(view, kind="pistol"):
    n = 7 if kind == "pistol" else 13
    img = Image.new("RGBA", (16, 16), CLEAR)
    d = ImageDraw.Draw(img)
    metal = [C("P02"), C("P03"), C("P04"), C("P06")]
    wood = [C("P17"), C("P18")]
    if view in ("E", "SE", "NE"):
        tmp = Image.new("RGBA", (16, 16), CLEAR)
        t = ImageDraw.Draw(tmp)
        x0 = 8 - n // 2
        t.rectangle([x0, 7, x0 + n - 1, 8], fill=metal[2])
        t.line([x0, 7, x0 + n - 1, 7], fill=metal[3])
        t.rectangle([x0 + 1, 9, x0 + 2, 10], fill=metal[1] if kind == "pistol" else wood[1])   # 손잡이
        if kind != "pistol":
            t.rectangle([x0 - 2, 8, x0, 9], fill=wood[1])                                  # 개머리
            t.point((x0 + 6, 9), fill=metal[1])                                            # 탄창
            t.point((x0 + 6, 10), fill=metal[1])
        t.rectangle([x0 + 1, 9, x0 + 2, 9], fill=SKIN[3])                                  # 손
        if view != "E":
            tmp = tmp.rotate(-35 if view == "SE" else 35, resample=Image.NEAREST, center=(8, 8))
        img = tmp
    elif view == "S":                                                   # 총구가 화면 쪽: 짧은 사각 + 구멍
        d.rectangle([6, 6, 9, 9 if kind == "pistol" else 10], fill=metal[2])
        d.point((7, 7), fill=C("P00")); d.point((8, 7), fill=C("P00"))
        d.rectangle([6, 10 if kind == "pistol" else 11, 9, 11 if kind == "pistol" else 12], fill=SKIN[3])
    else:                                                               # N: 등 뒤로 보이는 총 윗면
        d.rectangle([7, 3, 8, 3 + n // 2], fill=metal[2])
        d.point((7, 3), fill=metal[3])
        d.rectangle([7, 4 + n // 2, 8, 5 + n // 2], fill=SKIN[3])
    return outline(img, thick_bottom=False)


GUN_AT = {"E": (7, -9), "SE": (7, -6), "S": (6, -4), "NE": (6, -13), "N": (4, -15)}   # 손 위치(발 기준점에서)


def actor(view, frame, kind="pc", face="idle", moving=True, aim=None, gun_kind="pistol"):
    """한 컷 합성(샘플 그림용). 게임에서는 몸·머리·총을 따로 겹친다."""
    mirror = view in ("W", "SW", "NW")
    v = {"W": "E", "SW": "SE", "NW": "NE"}.get(view, view)
    body_view = "E" if v in ("E", "SE", "NE") else v
    b, top = body(body_view, frame, kind, moving)
    a = aim or v
    am = {"W": "E", "SW": "SE", "NW": "NE"}.get(a, a)
    h = head(am, kind, face)
    g = gun(am, gun_kind) if gun_kind else None
    flip_aim = a in ("W", "SW", "NW")
    if flip_aim:
        h = h.transpose(Image.FLIP_LEFT_RIGHT)
        g = g.transpose(Image.FLIP_LEFT_RIGHT) if g else None
    if mirror:
        b = b.transpose(Image.FLIP_LEFT_RIGHT)
    img = Image.new("RGBA", (40, 44), CLEAR)
    ox, oy = 4, 10                                                     # 발 기준점 = (20, 40)
    gx, gy = GUN_AT[am]
    gx = -gx if flip_aim else gx
    gpos = (ox + 16 + gx - 8, oy + 30 + gy - 8)
    if g and am in ("N", "NE"):
        img.alpha_composite(g, gpos)
    img.alpha_composite(b, (ox, oy))
    img.alpha_composite(h, (ox + 16 - h.width // 2, oy + top))
    if g and am not in ("N", "NE"):
        img.alpha_composite(g, gpos)
    return img


# ---------------------------------------------------------------- 큰바퀴(옆 3/4, 3컷 종종걸음)
SHELL = [C("P16"), C("P17"), C("P18"), C("P19"), C("P20")]


def roach(frame, hurt=False):
    img = Image.new("RGBA", (42, 22), CLEAR)
    d = ImageDraw.Draw(img)
    legc = [C("P02"), C("P16")]
    # 다리: 먼 쪽(어둡게) 먼저, 3쌍. 컷마다 앞뒤로 엇갈린다(삼각 보행)
    sw = [(-2, 1, -2), (1, -2, 1), (0, 0, 0)][frame % 3]
    for far in (1, 0):
        y0 = 13 - far * 2
        for i, (bx, ln) in enumerate(((10, -5), (16, 0), (22, 5))):
            o = sw[i] * (1 if (i + far) % 2 else -1)
            fx, fy = bx + ln + o, 19 - far * 3
            kx, ky = bx + ln // 2 + o // 2, y0 + 2
            d.line([bx, y0, kx, ky], fill=legc[far])
            d.line([kx, ky, fx, fy], fill=legc[far])
            d.point((fx + (1 if ln >= 0 else -1), fy), fill=legc[far])
    # 몸통(배) + 날개 덮개: 타원, 위에서 빛
    cx, cy, rx, ry = 15.5, 10.5, 11.5, 5.8
    for y in range(22):
        for x in range(36):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            q = nx * nx + ny * ny
            if q <= 1:
                nz = math.sqrt(1 - q)
                dd = nx * L[0] + ny * L[1] + nz * L[2]
                col = SHELL[0] if dd < -0.3 else SHELL[1] if dd < 0.15 else SHELL[2] if dd < 0.6 else SHELL[3]
                if -0.05 < ny < 0.12 and nx < 0.55:
                    col = SHELL[0]                                      # 날개 갈라진 줄
                if ny < -0.45 and -0.6 < nx < 0.2 and (x + y) % 5:
                    col = SHELL[4]                                      # 윤기
                img.putpixel((x, y), col)
    # 앞가슴 방패 + 머리
    d.ellipse([23, 5, 30, 13], fill=SHELL[1])
    d.arc([23, 5, 30, 13], 200, 330, fill=SHELL[3])
    d.ellipse([28, 8, 32, 12], fill=C("P02"))
    d.point((30, 9), fill=C("P54") if hurt else C("P08"))                 # 눈
    img = outline(img)
    # 더듬이: 외곽선 없이 가늘고 길게, 앞으로 뻗어 휘어진다(컷마다 까딱)
    d = ImageDraw.Draw(img)
    t = frame % 3
    for k, pts in enumerate((((32, 8), (35, 4), (39, 2 + t), (41, 4 + t)), ((32, 10), (36, 8), (40, 9 - t // 2), (41, 12 - t)))):
        d.line(pts, fill=SHELL[0] if k else C("P01"))
    if hurt:
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                if px[x, y][3] and px[x, y] != INK:
                    px[x, y] = C("P09")
    return img


# ---------------------------------------------------------------- 바닥 자국(남는다) · 탄
def splat(kind, seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (28, 18), CLEAR)
    px = img.load()
    cols = {"blood": [C("P51"), C("P52"), C("P53")], "ichor": [C("P29"), C("P30"), C("P31")], "oil": [C("P01"), C("P02"), C("P03")],
            "dried": [C("P38"), C("P51"), C("P51")]}[kind]
    blobs = [(14, 9, 5.5, 3.6)] + [(rnd.uniform(4, 24), rnd.uniform(3, 15), rnd.uniform(1.2, 2.6), rnd.uniform(1.0, 2.0)) for _ in range(6)]
    for y in range(18):
        for x in range(28):
            v = max((1 - ((x + .5 - bx) / rx) ** 2 - ((y + .5 - by) / ry) ** 2) for bx, by, rx, ry in blobs)
            if v > 0:
                px[x, y] = cols[2] if v > 0.6 and kind not in ("oil", "dried") else cols[1] if v > 0.25 else cols[0]
    return img


# ---------------------------------------------------------------- 방 소품(장애물 칸 32×32)
def rock(seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (32, 32), CLEAR)
    px = img.load()
    lumps = [(16, 19, 12.5, 10)] + [(rnd.uniform(9, 23), rnd.uniform(12, 20), rnd.uniform(5, 8), rnd.uniform(5, 7)) for _ in range(3)]
    g = [C("P03"), C("P04"), C("P05"), C("P06"), C("P07")]
    for y in range(32):
        for x in range(32):
            best = None
            for bx, by, rx, ry in lumps:
                nx, ny = (x + .5 - bx) / rx, (y + .5 - by) / ry
                q = nx * nx + ny * ny
                if q <= 1 and (best is None or q < best[0]):
                    best = (q, nx, ny)
            if best:
                q, nx, ny = best
                nz = math.sqrt(1 - q)
                dd = nx * L[0] + ny * L[1] + nz * L[2]
                px[x, y] = g[0] if dd < -0.35 else g[1] if dd < 0.05 else g[2] if dd < 0.5 else g[3] if dd < 0.8 else g[4]
    d = ImageDraw.Draw(img)
    cx = rnd.randint(12, 18)
    d.line([cx, 12, cx + 2, 17, cx + 1, 21], fill=g[0])                  # 금
    return outline(img)


def drum():
    img = Image.new("RGBA", (32, 32), CLEAR)
    d = ImageDraw.Draw(img)
    rust = [C("P24"), C("P25"), C("P26"), C("P27")]
    for x in range(8, 25):
        nx = (x + .5 - 16.5) / 8.5
        col = rust[0] if nx > 0.55 else rust[1] if nx > 0.0 else rust[2] if nx > -0.6 else rust[3]
        d.line([x, 11, x, 28], fill=col)
    for y in (16, 23):
        d.line([8, y, 24, y], fill=rust[0])
    d.ellipse([8, 6, 24, 15], fill=rust[2])
    d.ellipse([10, 8, 22, 13], fill=rust[1])
    d.ellipse([12, 9, 15, 11], fill=C("P02"))                           # 마개
    d.point((19, 18), fill=C("P49")); d.point((20, 18), fill=C("P49")); d.point((19, 19), fill=C("P48"))   # 벗겨진 경고 표시
    return outline(img)


def tire():
    img = Image.new("RGBA", (32, 32), CLEAR)
    px = img.load()
    for y in range(32):
        for x in range(32):
            nx, ny = (x + .5 - 16) / 12.5, (y + .5 - 19) / 9
            q = math.sqrt(nx * nx + ny * ny)
            if 0.42 < q <= 1:
                px[x, y] = C("P03") if ny < -0.3 else C("P02") if q > 0.75 else C("P01")
                if 0.55 < q < 0.65 and ny < 0:
                    px[x, y] = C("P04")
    return outline(img)


# ---------------------------------------------------------------- 방: 볼트 S-07 정문 앞 공터 (640×360, 바닥 17×8칸)
RW, RH = 640, 360
FX0, FY0, FX1, FY1 = 48, 72, 592, 328                                 # 바닥 영역
PROPS = [("rock", 2, 1), ("rock", 3, 1), ("rock", 13, 5), ("rock", 14, 5), ("rock", 14, 6), ("drum", 9, 6),
         ("drum", 1, 6), ("tire", 15, 1), ("rock", 6, 4)]                # (종류, 칸 x, 칸 y) — 바닥 17×8 격자
DOORS = {"left": (0, 4), "right": (16, 4), "bottom": (8, 7)}           # 바닥 가장자리 열린 칸(문 앞)


def gear_door():
    """S-07 톱니 문(아이작풍: 두꺼운 테, 단순한 면)."""
    S = 76
    img = Image.new("RGBA", (S, S), CLEAR)
    px = img.load()
    c = S / 2
    for y in range(S):
        for x in range(S):
            dx, dy = x + .5 - c, y + .5 - c
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            tooth = 33.5 + (3.0 if math.cos(a * 10) > 0.25 else 0)
            if r > tooth:
                continue
            lit = (-dx * 0.6 - dy * 0.8) / max(r, 1)
            if r > 30:
                col = C("P06") if lit > 0.2 else C("P05") if lit > -0.4 else C("P04")
            elif r > 27:
                col = C("P03")
            elif r > 23:
                seg = int((a + math.pi) / (2 * math.pi) * 16) % 2
                col = (C("P49") if lit > 0 else C("P48")) if seg else C("P02")         # 노랑·검정 경고 띠
            elif r > 13:
                col = C("P46") if lit > 0.35 else C("P45") if lit > -0.3 else C("P44")
            else:
                col = C("P07") if lit > 0.2 else C("P06") if lit > -0.4 else C("P05")
            px[x, y] = col
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text((c - 11, c - 6), "S-07", font=FONT, fill=C("P49"))
    return outline(img)


def room(seed=7):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (RW, RH), C("P03"))
    px = img.load()
    # 바닥: 콘크리트 판(64×64, 판마다 한 색) + 홈(어두운 줄 + 아래 밝은 줄) + 드문 잡티
    base = [C("P04"), C("P05"), C("P06")]
    def cell(ix, iy, k):
        return random.Random(ix * 7919 + iy * 104729 + k * 1299709).random()

    def noise(x, y, sc, k):                                            # 값 잡음(쌍선형 + 부드러운 계단): 둥근 얼룩
        fx, fy = x / sc, y / sc
        ix, iy = int(math.floor(fx)), int(math.floor(fy))
        tx, ty = fx - ix, fy - iy
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = cell(ix, iy, k) * (1 - tx) + cell(ix + 1, iy, k) * tx
        b = cell(ix, iy + 1, k) * (1 - tx) + cell(ix + 1, iy + 1, k) * tx
        return a * (1 - ty) + b * ty
    for y in range(FY0, FY1):
        for x in range(FX0, FX1):
            tx, ty = (x - FX0) // 64, (y - FY0) // 64
            col = base[1] if (tx * 5 + ty * 3) % 4 else base[2] if (tx + ty) % 2 else base[0]
            blot = noise(x, y, 22, 1) * 0.65 + noise(x, y, 7, 2) * 0.35     # 큼직하고 둥근 얼룩
            if blot < 0.3:
                col = P.step(col[:3], -1) + (255,)
            elif blot > 0.72:
                col = P.step(col[:3], 1) + (255,)
            if rnd.random() < 0.012:
                col = C("P03")
            u, v = (x - FX0) % 64, (y - FY0) % 64
            if u == 0 or v == 0:
                col = C("P03")
            elif v == 1:
                col = P.step(col[:3], 1) + (255,)
            px[x, y] = col
    d = ImageDraw.Draw(img)
    for _ in range(12):                                                # 균열: 꺾이는 선
        x, y = rnd.randint(FX0 + 10, FX1 - 10), rnd.randint(FY0 + 10, FY1 - 10)
        for _k in range(rnd.randint(4, 8)):
            nx, ny = x + rnd.randint(-7, 7), y + rnd.randint(-4, 4)
            d.line([x, y, nx, ny], fill=C("P03"))
            x, y = nx, ny
    for _ in range(5):                                                 # 흙 덩이: 테두리가 울퉁불퉁한 면
        cx, cy = rnd.randint(FX0, FX1), rnd.randint(FY0, FY1)
        rr = rnd.randint(9, 20)
        k0 = rnd.random() * 9
        for y in range(cy - rr, cy + rr):
            for x in range(cx - rr - 4, cx + rr + 4):
                if FX0 <= x < FX1 and FY0 <= y < FY1:
                    a = math.atan2(y - cy, x - cx)
                    edge = rr * (0.75 + 0.18 * math.sin(a * 3 + k0) + 0.08 * math.sin(a * 7 + k0 * 2))
                    dd = math.hypot(x - cx, (y - cy) * 1.5)
                    if dd < edge:
                        px[x, y] = C("P18") if dd < edge - 3 else C("P17")
                        if noise(x, y, 3, 9) < 0.1:
                            px[x, y] = C("P19")
    for k in range(4):                                                 # 오래된 기름·핏자국(마른 색)
        sp = splat("oil" if k % 2 else "dried", seed + k)
        sp = sp.resize((sp.width * 2, sp.height * 2), Image.NEAREST) if k == 1 else sp
        img.alpha_composite(sp, (rnd.randint(FX0 + 20, FX1 - 60), rnd.randint(FY0 + 30, FY1 - 40)))
    # 가장자리 어둡게(아이작풍 비네트): 경계를 울퉁불퉁하게, 팔레트 램프로 한두 단계
    for y in range(FY0, FY1):
        for x in range(FX0, FX1):
            j = noise(x, y, 14, 3) * 12 + noise(x, y, 4, 4) * 4
            e = min(x - FX0, FX1 - 1 - x, FY1 - 1 - y, (y - FY0) * 0.6) - j
            k = -2 if e < 6 else -1 if e < 26 else 0
            if k:
                px[x, y] = P.step(px[x, y][:3], k) + (255,)
    # 벽: 위는 관악산 바위 절벽(어두운 화강암 덩이 + 금), 옆·아래는 돌 축대
    wall = Image.new("RGBA", (RW, RH), CLEAR)
    wp = wall.load()
    g = [C("P01"), C("P02"), C("P03"), C("P04"), C("P05")]
    blobs = []
    for i in range(70):
        blobs.append((rnd.uniform(-10, RW + 10), rnd.uniform(-8, 64), rnd.uniform(11, 27), rnd.uniform(9, 19)))
    for y in range(0, FY0 + 6):
        for x in range(RW):
            best = None
            for bx, by, rx, ry in blobs:
                q = ((x + .5 - bx) / rx) ** 2 + ((y + .5 - by) / ry) ** 2
                if q <= 1 and (best is None or by > best[3]):
                    best = (q, (x + .5 - bx) / rx, (y + .5 - by) / ry, by)
            if best is None:
                wp[x, y] = (g[1] if noise(x, y, 9, 6) > 0.45 else g[0]) if y < FY0 else (0, 0, 0, 0)
                continue
            q, nx, ny, _ = best
            nz = math.sqrt(max(0, 1 - q))
            dd = nx * L[0] + ny * L[1] + nz * L[2]
            wp[x, y] = g[0] if q > 0.9 else g[1] if dd < -0.25 else g[2] if dd < 0.3 else g[3] if dd < 0.7 else g[4]
            if 0.55 < q < 0.6 and dd > 0.2 and noise(x, y, 3, 5) < 0.4:
                wp[x, y] = g[1]                                       # 바위 금
            if y >= FY0 and q > 0.55:
                wp[x, y] = (0, 0, 0, 0)
    for y in range(FY0, RH):                                           # 옆 축대: 엇갈린 돌 블록, 위쪽이 밝다
        for x in list(range(0, FX0)) + list(range(FX1, RW)):
            off = 12 if (y // 20) % 2 else 0
            bx, by = (x + off) // 24, y // 20
            r = random.Random(bx * 31 + by * 17).random()
            col = g[2] if r < 0.5 else g[3] if r < 0.85 else g[1]
            if (x + off) % 24 == 0 or y % 20 == 0:
                col = g[0]
            elif y % 20 == 1:
                col = P.step(col[:3], 1) + (255,)
            wp[x, y] = col
    for y in range(FY1, RH):
        for x in range(FX0, FX1):
            off = 14 if ((y - FY1) // 16) % 2 else 0
            r = random.Random(((x + off) // 28) * 13 + ((y - FY1) // 16) * 7 + 5).random()
            wp[x, y] = g[0] if (x + off) % 28 == 0 or (y - FY1) % 16 == 0 else (g[2] if r < 0.5 else g[3])
    img.alpha_composite(wall)
    # 바닥과 벽 경계: 두꺼운 먹선 + 위 벽 그림자
    d.rectangle([FX0 - 2, FY0 - 2, FX1 + 1, FY1 + 1], outline=INK, width=2)
    # 출입구: 왼·오·아래(검은 구멍 + 돌 테), 위는 톱니 문
    for side, rect in (("left", (FX0 - 26, 190, FX0 - 1, 246)), ("right", (FX1, 190, FX1 + 25, 246)), ("bottom", (296, FY1, 343, FY1 + 30))):
        x0, y0, x1, y1 = rect
        d.rectangle([x0 - 4, y0 - 4, x1 + 4, y1 + 4], fill=C("P04"), outline=INK, width=1)
        d.rectangle([x0 - 2, y0 - 2, x1 + 2, y1 + 2], fill=C("P05"))
        d.rectangle([x0, y0, x1, y1], fill=C("P00"), outline=INK)
        if side == "bottom":
            d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=C("P02"))        # 문턱 안쪽 그림자
        else:
            d.line([x0 + 1, y0 + 1, x0 + 1, y1 - 1] if side == "right" else [x1 - 1, y0 + 1, x1 - 1, y1 - 1], fill=C("P02"))
    gd = gear_door()
    d.rectangle([320 - 44, 0, 320 + 43, FY0 + 1], fill=C("P04"), outline=INK)   # 콘크리트 문틀
    d.rectangle([320 - 40, 4, 320 + 39, FY0 - 2], fill=C("P02"))
    img.alpha_composite(gd.crop((0, 0, gd.width, gd.height)), (320 - gd.width // 2, FY0 - gd.height + 8))
    # 장애물
    sprites = {"drum": drum(), "tire": tire()}
    for i, (kind, gx, gy) in enumerate(PROPS):
        im = rock(seed * 10 + i) if kind == "rock" else sprites[kind]
        img.alpha_composite(im, (FX0 + gx * 32, FY0 + gy * 32))
    return img


def upscale(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


GAME = os.path.join(os.path.dirname(ROOT), "game", "assets", "style_isaac")
BODY_ROWS = ("S", "E", "N")                                           # 대각선은 옆 몸(E)을 쓴다(아이작 방식)
FACES = ("idle", "fire", "blink")


def solids():
    """바닥 밖 = 벽(출입구 칸 제외), 장애물 칸. 반환: 32px 격자(20×12)에서 막힌 칸 목록."""
    out = []
    for ty in range(12):
        for tx in range(20):
            x, y = tx * 32 + 16, ty * 32 + 16
            inside = FX0 <= x < FX1 and FY0 <= y < FY1
            if not inside:
                out.append([tx, ty])
    for kind, gx, gy in PROPS:
        out.append([FX0 // 32 + gx, FY0 // 32 + gy])
    return out


def export():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(GAME, exist_ok=True)
    meta = {"foot": [16, 30], "body_rows": list(BODY_ROWS), "views": list(VIEWS), "faces": list(FACES),
            "walk": {"frames": 6, "px": WALK_PX, "contact": [0, 3]}, "gun_at": GUN_AT, "floor": [FX0, FY0, FX1, FY1],
            "solids": solids(), "props": PROPS}
    for kind, gk in (("pc", "pistol"), ("soldier", "rifle")):
        sheet = Image.new("RGBA", (32 * 7, 32 * 3), CLEAR)
        tops = {}
        for r, v in enumerate(BODY_ROWS):
            tops[v] = []
            for f in range(7):
                b, top = body(v, max(0, f - 1), kind, moving=f > 0)          # 0열 = 서 있기, 1~6열 = 걷기
                sheet.alpha_composite(b, (f * 32, r * 32))
                tops[v].append(top)
        sheet.save(os.path.join(GAME, f"{kind}_body.png"))
        heads = Image.new("RGBA", (24 * len(VIEWS), 22 * len(FACES)), CLEAR)
        for r, face in enumerate(FACES):
            for c, v in enumerate(VIEWS):
                heads.alpha_composite(head(v, kind, face), (c * 24, r * 22))
        heads.save(os.path.join(GAME, f"{kind}_head.png"))
        guns = Image.new("RGBA", (16 * len(VIEWS), 16), CLEAR)
        for c, v in enumerate(VIEWS):
            guns.alpha_composite(gun(v, gk), (c * 16, 0))
        guns.save(os.path.join(GAME, f"{kind}_gun.png"))
        meta[kind] = {"head_top": tops}
    rs = Image.new("RGBA", (42 * 4, 22), CLEAR)
    for f in range(3):
        rs.alpha_composite(roach(f), (f * 42, 0))
    rs.alpha_composite(roach(0, True), (126, 0))
    rs.save(os.path.join(GAME, "roach.png"))
    meta["roach"] = {"frame": [42, 22], "foot": [17, 19], "frames": 3, "px": 3}
    for kind in ("blood", "ichor"):
        sp = Image.new("RGBA", (28 * 4, 18), CLEAR)
        for k in range(4):
            sp.alpha_composite(splat(kind, 100 + k), (k * 28, 0))
        sp.save(os.path.join(GAME, f"splat_{kind}.png"))
    room().save(os.path.join(GAME, "room.png"))
    json.dump(meta, open(os.path.join(GAME, "isaac.json"), "w"), ensure_ascii=False, indent=1, sort_keys=True)
    print("isaac assets:", sorted(os.listdir(GAME)))


def label(img, xy, text, col="P09"):
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text(xy, text, font=FONT, fill=C(col))


def samples():
    """samples/17_isaac_chars_x4.png(인물·소품 시트), samples/17_isaac_room_x2.png(방 + 인물 정지 장면)."""
    W = 6 * 48 + 90
    sheet = Image.new("RGBA", (W, 296), C("P19"))
    y = 4
    label(sheet, (4, y + 8), "주인공 머리")
    for r, face in enumerate(FACES):
        for c, v in enumerate(VIEWS):
            sheet.alpha_composite(head(v, "pc", face), (90 + c * 30, y + r * 24))
    y += 76
    label(sheet, (4, y + 14), "주인공 걷기 E")
    for f in range(6):
        sheet.alpha_composite(actor("E", f), (90 + f * 44, y - 6))
    y += 46
    label(sheet, (4, y + 14), "S / N / 조준 분리")
    for f, (v, aim) in enumerate((("S", None), ("N", None), ("W", "E"), ("E", "S"), ("S", "NE"), ("SE", "W"))):
        sheet.alpha_composite(actor(v, f, aim=aim, face="fire" if f == 2 else "idle"), (90 + f * 44, y - 6))
    y += 46
    label(sheet, (4, y + 14), "보병 계엄병")
    for f, (v, aim) in enumerate((("S", None), ("SE", None), ("E", None), ("NE", None), ("N", None), ("W", "SW"))):
        sheet.alpha_composite(actor(v, f, "soldier", aim=aim, gun_kind="rifle"), (90 + f * 44, y - 6))
    y += 50
    label(sheet, (4, y + 6), "큰바퀴")
    for f in range(3):
        sheet.alpha_composite(roach(f), (90 + f * 48, y))
    sheet.alpha_composite(roach(0, True), (90 + 3 * 48, y))
    sheet.alpha_composite(splat("ichor", 3), (90 + 4 * 48, y + 4))
    sheet.alpha_composite(splat("blood", 4), (90 + 4 * 48 + 30, y + 4))
    y += 34
    label(sheet, (4, y + 10), "소품(장애물 칸)")
    for i, im in enumerate((rock(1), rock(2), drum(), tire())):
        sheet.alpha_composite(im, (90 + i * 40, y))
    sheet.save(os.path.join(SAMPLES, "17_isaac_chars.png"))
    upscale(sheet, 4).save(os.path.join(SAMPLES, "17_isaac_chars_x4.png"))
    # 정지 장면: 방 + 인물(그림자는 바닥 색을 램프 두 단계 낮춰 팔레트 안에서)
    scene = room()
    px = scene.load()
    cast = [(actor("NE", 2, aim="NE", face="fire"), (300, 236)), (actor("SW", 0, "soldier", aim="SW", gun_kind="rifle", moving=False), (470, 112)),
            (roach(1), (130, 292)), (roach(2).transpose(Image.FLIP_LEFT_RIGHT), (540, 300))]
    for _im, (fx, fy) in cast:
        for y in range(fy - 4, fy + 2):
            for x in range(fx - 11, fx + 12):
                if ((x - fx) / 11) ** 2 + ((y - fy + 1) / 3.5) ** 2 <= 1:
                    px[x, y] = P.step(px[x, y][:3], -2) + (255,)
    scene.alpha_composite(splat("ichor", 7), (180, 296))
    for im, (fx, fy) in cast:
        if im.width == 40:
            scene.alpha_composite(im, (fx - 20, fy - 40))
        else:
            scene.alpha_composite(im, (fx - 17, fy - 19))
    d = ImageDraw.Draw(scene)
    for (x0, y0), (x1, y1), col in (((372, 174), (380, 168), "P49"), ((404, 152), (412, 146), "P49"), ((426, 152), (418, 159), "P53")):
        d.line([x0, y0 + 1, x1, y1 + 1], fill=C("P01"), width=3)          # 탄: 짧은 꼬리 + 먹선
        d.line([x0, y0, x1, y1], fill=C(col))
        d.point((x1, y1), fill=C("P50"))
    scene.save(os.path.join(SAMPLES, "17_isaac_room.png"))
    upscale(scene, 2).save(os.path.join(SAMPLES, "17_isaac_room_x2.png"))
    print("isaac samples written")


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "export":
    export()

if __name__ == "__main__" and len(sys.argv) == 1:
    export()
    samples()

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "room":
    upscale(room(), 2).save("/tmp/claude-0/-home-user-003/c49a198f-1dc9-5a25-b808-ed8df563557e/scratchpad/isaac_room.png")

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "heads":
    sheet = Image.new("RGBA", (6 * 26 + 4, 3 * 24 + 4), C("P19"))
    for i, v in enumerate(VIEWS):
        sheet.alpha_composite(head(v), (2 + i * 26, 2))
        sheet.alpha_composite(head(v, face="fire"), (2 + i * 26, 26))
        sheet.alpha_composite(head(v, "soldier"), (2 + i * 26, 50))
    upscale(sheet, 6).save("/tmp/claude-0/-home-user-003/c49a198f-1dc9-5a25-b808-ed8df563557e/scratchpad/isaac_heads.png")
    row = Image.new("RGBA", (12 * 40, 2 * 44), C("P19"))
    for f in range(6):
        row.alpha_composite(actor("E", f), (f * 40, 0))
        row.alpha_composite(actor("S", f), ((6 + f) * 40, 0))
        row.alpha_composite(actor("E", f, "soldier", gun_kind="rifle"), (f * 40, 44))
        row.alpha_composite(actor("N", f, "soldier", gun_kind="rifle"), ((6 + f) * 40, 44))
    upscale(row, 4).save("/tmp/claude-0/-home-user-003/c49a198f-1dc9-5a25-b808-ed8df563557e/scratchpad/isaac_actors.png")
