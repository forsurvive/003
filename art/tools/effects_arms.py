"""단계 1-9a 무기 계열 이펙트(SD-16 §10.1·§10.4): 산탄·중화기 총구 화염, 레이저·플라스마 총구, 투사체(펠릿·플라스마 구·
미사일·유탄·못·다트·방전 구·잡동사니), 화염 줄기 입자, 폭발(불덩이 가산 + 연기 일반 혼합).
외곽선 없음(§3.7) · 팔레트 64색만 · 가산 세트는 어두운 색을 쓰지 않는다(가산이면 검은색 = 투명).
방향 세트는 16방향을 미리 그린다(실행 중 회전 없음, §3.5). 무방향 세트(화염 입자·폭발)는 1열.
tools/pipeline/fx_export.py가 combat_fx.png 아래에 칸 크기별로 이어 붙인다."""
import os, sys, math, random
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import palette as P

CLEAR = (0, 0, 0, 0)
C = lambda t: P.rgb(t) + (255,)


def _px(img, x, y, tok):
    x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5))
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), C(tok))


def _cone(angle, frame, size, L, W, core, mid, rim, petals=0, dither_last=True, nframes=3):
    """총열 축 원뿔(역매핑 — 45°에서도 빈틈 없음). 기준점 = (size/2 − 0.5, size/2 − 0.5) 칸 중심."""
    img = Image.new("RGBA", (size, size), CLEAR)
    c = size / 2 - 1
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    Lf, Wf = L[frame], W[frame]
    for y in range(size):
        for x in range(size):
            dx, dy = x - c, y - c
            t = dx * ux + dy * uy
            s = -dx * uy + dy * ux
            if t < -1.2 or t > Lf + 0.5:
                continue
            width = Wf * (1 - max(0.0, t) / (Lf + 0.5)) + (0.7 if t < 1 else 0)
            tok = None
            if abs(s) <= width:
                tok = core[frame] if abs(s) < width * 0.45 and t < Lf * 0.6 else mid[frame]
            elif petals and frame < nframes - 1 and -0.6 < t < 1.8 and width < abs(s) <= width + petals - frame:
                tok = mid[frame] if abs(s) < width + petals * 0.5 else rim[frame]
            if tok and not (dither_last and frame == nframes - 1 and (x + y) % 2):
                img.putpixel((x, y), C(tok))
    return img


# ---------------------------------------------------------------- 총구 화염(가산)
def flash_shotgun(angle, frame):
    """산탄: 짧고 넓은 부채 + 앞으로 튀는 불티 점(펠릿이 지나간 자리). 32칸, 3컷."""
    img = _cone(angle, frame, 32, L=(9.0, 7.0, 4.0), W=(5.5, 4.0, 2.0), core=("P09", "P50", "P50"),
                mid=("P60", "P60", "P27"), rim=("P27", "P27", "P27"), petals=4)
    if frame < 2:
        rnd = random.Random(int(angle * 10) + frame)
        a = math.radians(angle)
        c = 15
        for k in range(7):
            off = math.radians(rnd.uniform(-14, 14))
            r = rnd.uniform(9, 14) + frame * 2
            _px(img, c + r * math.cos(a + off), c + r * math.sin(a + off), "P50" if k % 2 else "P60")
    return img


def flash_heavy(angle, frame):
    """회전 기관포: 길고 가는 별 + 좌우 깜박임(컷마다 꽃잎 쪽이 바뀐다). 32칸, 3컷."""
    img = _cone(angle, frame, 32, L=(12.0, 9.0, 6.0), W=(3.0, 3.6, 1.6), core=("P09", "P09", "P50"),
                mid=("P50", "P60", "P27"), rim=("P60", "P27", "P27"), petals=3)
    a = math.radians(angle)
    c = 15
    for side in (-1, 1):                                       # 옆으로 튀는 가스(컷마다 길이가 다르다)
        n = (3, 4, 1)[frame] if side == (1 if frame % 2 else -1) else (2, 1, 0)[frame]
        for k in range(n):
            px = c + (2 + k * 0.5) * math.cos(a) + side * (3 + k) * -math.sin(a)
            py = c + (2 + k * 0.5) * math.sin(a) + side * (3 + k) * math.cos(a)
            _px(img, px, py, "P60" if k < 2 else "P27")
    return img


def flash_laser(angle, frame):
    """레이저: 붉은 고리 섬광(불꽃 없음). 16칸, 2컷. 심 P09 · 고리 P54 · 바깥 P53."""
    img = Image.new("RGBA", (16, 16), CLEAR)
    c = 7
    a = math.radians(angle)
    cx, cy = c + 1.5 * math.cos(a), c + 1.5 * math.sin(a)
    r0 = (2.6, 3.8)[frame]
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - cx, y - cy)
            if frame == 0 and d <= 1.2:
                img.putpixel((x, y), C("P09"))
            elif abs(d - r0) <= 0.6 and not (frame == 1 and (x + y) % 2):
                img.putpixel((x, y), C("P54" if frame == 0 else "P53"))
    _px(img, cx + 4 * math.cos(a), cy + 4 * math.sin(a), "P54")
    return img


def flash_plasma(angle, frame):
    """플라스마: 녹색 덩어리 분출. 16칸, 2컷. P57 · P56 · P55."""
    return _cone(angle, frame, 16, L=(5.0, 3.5), W=(3.4, 2.4), core=("P57", "P56"), mid=("P56", "P55"),
                 rim=("P55", "P55"), petals=2, nframes=2)


def flash_flame(angle, frame):
    """화염방사기 점화구: 작은 파란 심 + 주황 혀. 16칸, 2컷."""
    img = _cone(angle, frame, 16, L=(4.5, 3.0), W=(2.0, 1.4), core=("P63", "P62"), mid=("P60", "P27"),
                rim=("P27", "P27"), petals=0, nframes=2)
    return img


# ---------------------------------------------------------------- 투사체(머리 = 칸 (8, 8))
def _streak(angle, toks, size=16, dark=True):
    img = Image.new("RGBA", (size, size), CLEAR)
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    c = size // 2
    pts = {}
    for k, tok in toks:
        pts[(int(math.floor(c + k * ux + 0.5)), int(math.floor(c + k * uy + 0.5)))] = tok
    if dark:
        ox, oy = (1, 0) if abs(uy) > 0.92 else (0, 1)
        for k, _ in toks[:3]:
            q = (int(math.floor(c + k * ux + 0.5)) + ox, int(math.floor(c + k * uy + 0.5)) + oy)
            if q not in pts:
                img.putpixel(q, C("P01"))
    for (x, y), tok in pts.items():
        img.putpixel((x, y), C(tok))
    return img


def pellet(angle):
    """산탄 펠릿: 탄환보다 짧다(머리 + 잔상 2px) — 9발이 겹쳐도 덩어리로 안 뭉친다."""
    return _streak(angle, [(0, "P50"), (-1, "P60"), (-2, "P27")])


def nail(angle):
    """못: 회색 쇠 막대 5px + 밝은 머리."""
    return _streak(angle, [(0, "P09"), (-1, "P08"), (-2, "P07"), (-3, "P07"), (-4, "P06")])


def dart(angle):
    """다트: 가는 녹색 깃 + 바늘."""
    return _streak(angle, [(0, "P08"), (-1, "P07"), (-2, "P56"), (-3, "P55")])


def plasma_bolt(angle, frame=0):
    """플라스마 구(SD-16 §10.1 '8×8, 녹'): 둥근 심 + 뒤로 흐르는 꼬리. 가산."""
    return _orb(angle, ("P57", "P56", "P55"))


def tesla_bolt(angle, frame=0):
    """방전 구: 청백 심 + 지그재그 가지. 가산."""
    img = _orb(angle, ("P09", "P63", "P62"))
    rnd = random.Random(int(angle))
    c = 8
    for k in range(3):
        ra = math.radians(angle + 180 + rnd.choice((-60, -30, 30, 60)))
        x, y = c, c
        for s in range(3):
            x += 1.6 * math.cos(ra) + rnd.uniform(-0.8, 0.8)
            y += 1.6 * math.sin(ra) + rnd.uniform(-0.8, 0.8)
            _px(img, x, y, "P63" if s < 2 else "P62")
    return img


def _orb(angle, ramp):
    img = Image.new("RGBA", (16, 16), CLEAR)
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    cx, cy = 8.0, 8.0
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            t = dx * ux + dy * uy
            s = abs(-dx * uy + dy * ux)
            tok = None
            if d <= 1.6:
                tok = ramp[0]
            elif d <= 2.8:
                tok = ramp[1]
            elif d <= 3.9 and (x + y) % 2 == 0:
                tok = ramp[2]
            elif -7.5 < t < -2.5 and s <= 1.6 * (1 + t / 7.5) + 0.3:   # 꼬리
                tok = ramp[1] if s < 0.7 and t > -5 else ramp[2]
                if t < -5 and (x + y) % 2:
                    tok = None
            if tok:
                img.putpixel((x, y), C(tok))
    return img


def missile(angle, frame=0):
    """미사일: 회색 몸통 6px · 붉은 탄두 · 꼬리 날개 · 배기 불꽃(컷마다 길이). 일반 혼합(불꽃 색은 밝은 팔레트)."""
    img = Image.new("RGBA", (16, 16), CLEAR)
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    c = 8
    for k in range(-5, 2):                                   # 몸통(머리 = +1)
        tok = "P53" if k >= 0 else ("P14" if k > -4 else "P12")
        for w in (-0.5, 0.5):
            _px(img, c + k * ux + w * nx, c + k * uy + w * ny, tok if w < 0 else ("P13" if tok.startswith("P1") else "P52"))
    for side in (-1, 1):                                     # 꼬리 날개
        _px(img, c - 5 * ux + side * 1.6 * nx, c - 5 * uy + side * 1.6 * ny, "P11")
    for k, tok in ((-6, "P50"), (-7, "P60"), (-8, "P27")):
        _px(img, c + k * ux, c + k * uy, tok)
    return img


def shell40(angle, frame=0):
    """40mm 유탄 · 미니 누크: 둥근 탄체(올리브) + 빛나는 밴드. 무방향처럼 보이지만 열은 방향을 쓴다."""
    img = Image.new("RGBA", (16, 16), CLEAR)
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - 8, y + 0.5 - 8
            t = dx * ux + dy * uy
            s = -dx * uy + dy * ux
            if (t / 2.6) ** 2 + (s / 1.8) ** 2 <= 1.0:
                tok = "P31" if s < -0.4 else "P30"
                if abs(t + 0.6) < 0.6:
                    tok = "P48"
                if t > 1.6:
                    tok = "P06"
                img.putpixel((x, y), C(tok))
    return img


def junk(angle, frame=0):
    """잡동사니 탄: 모양 다른 고철 덩어리(각마다 다른 조각)."""
    img = Image.new("RGBA", (16, 16), CLEAR)
    rnd = random.Random(int(angle * 3) + 7)
    pts = [(8 + rnd.randint(-2, 1), 8 + rnd.randint(-2, 1)) for _ in range(6)]
    for i, (x, y) in enumerate(pts):
        img.putpixel((x, y), C(("P05", "P06", "P19", "P04")[i % 4]))
        img.putpixel((x + 1, y), C("P04"))
    img.putpixel((8, 8), C("P07"))
    return img


# ---------------------------------------------------------------- 화염 줄기 입자(가산, 무방향 16칸 × 5컷)
def flame_puff(frame):
    """나온 지 0~4컷: 작은 흰·노란 심 → 주황 불덩이 → 붉은 가장자리 → 성기게 꺼진다. 덩어리 모양은 컷마다 다르다."""
    img = Image.new("RGBA", (16, 16), CLEAR)
    rnd = random.Random(31 + frame)
    r = (2.2, 3.4, 4.6, 5.4, 6.0)[frame]
    lobes = [(rnd.uniform(-1.5, 1.5), rnd.uniform(-1.5, 1.5), r * rnd.uniform(0.55, 0.8)) for _ in range(4)]
    ramp = [("P09", "P50", "P60"), ("P50", "P60", "P27"), ("P60", "P27", "P26"), ("P27", "P26", "P25"), ("P26", "P25", "P25")][frame]
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - 8, y + 0.5 - 8 + frame * 0.4       # 불은 조금씩 위로
            d = min(math.hypot(dx - lx, dy - ly) / lr for lx, ly, lr in lobes + [(0, 0, r)])
            if d > 1.0:
                continue
            tok = ramp[0] if d < 0.45 else ramp[1] if d < 0.8 else ramp[2]
            if frame >= 3 and (x + y + frame) % 2:
                continue
            img.putpixel((x, y), C(tok))
    return img


# ---------------------------------------------------------------- 폭발(SD-16 §10.4 중형 64칸, 8컷) — 불덩이(가산) + 연기(일반)
def _blobs(seed, n, spread, rmin, rmax):
    rnd = random.Random(seed)
    return [(rnd.uniform(-spread, spread), rnd.uniform(-spread, spread), rnd.uniform(rmin, rmax)) for _ in range(n)]


def boom_fire(frame, size=64):
    """0: 흰 섬광 원 · 1~2: 커지는 노랑·주황 불덩이(덩어리 7개) · 3~4: 붉게 식으며 갈라진다 · 5~7: 불씨만 성기게."""
    img = Image.new("RGBA", (size, size), CLEAR)
    c = size / 2
    k = size / 64.0
    R = (9, 16, 21, 24, 25, 25, 24, 22)[frame] * k
    lobes = _blobs(5, 7, R * 0.45, R * 0.45, R * 0.75)
    ramp = [("P09", "P50", "P60"), ("P09", "P50", "P60"), ("P50", "P60", "P27"), ("P60", "P27", "P26"),
            ("P27", "P26", "P25"), ("P26", "P25", "P24"), ("P25", "P24", "P24"), ("P24", "P24", "P24")][frame]
    hole = (0, 0, 0, 0, 0.35, 0.55, 0.7, 0.8)[frame]                  # 식으면 가운데부터 빈다(연기가 덮는다)
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            d = min(math.hypot(dx - lx, dy - ly) / lr for lx, ly, lr in lobes + [(0, 0, R * 0.7)])
            if d > 1.0:
                continue
            noise = ((x * 7 + y * 13 + frame * 5) % 11) / 11.0
            if hole and d < hole and noise < 0.8:
                continue
            if frame >= 5 and (x + y) % 2:
                continue
            tok = ramp[0] if d < 0.4 else ramp[1] if d < 0.75 + noise * 0.1 else ramp[2]
            img.putpixel((x, y), C(tok))
    if frame <= 2:                                                  # 튀는 불티
        rnd = random.Random(9 + frame)
        for k in range(10):
            ra = rnd.uniform(0, 2 * math.pi)
            r = R + (2 + frame * 3 + rnd.uniform(0, 4)) * k
            _px(img, c + r * math.cos(ra), c + r * math.sin(ra), "P50" if k % 2 else "P60")
    return img


def boom_smoke(frame, size=64):
    """연기(일반 혼합, 불덩이 뒤에 깐다): 2컷부터 회색 덩어리가 부풀며 위로 오르고 6~7컷에 바둑판으로 흩어진다."""
    img = Image.new("RGBA", (size, size), CLEAR)
    if frame < 2:
        return img
    c = size / 2
    k = size / 64.0
    R = (0, 0, 18, 22, 25, 27, 28, 28)[frame] * k
    lift = (frame - 2) * 1.6 * k
    lobes = _blobs(11, 8, R * 0.5, R * 0.4, R * 0.7)
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - c, y + 0.5 - c + lift
            best = min(((math.hypot(dx - lx, dy - ly) / lr, lx, ly, lr) for lx, ly, lr in lobes))
            d, lx, ly, lr = best
            if d > 1.0:
                continue
            if frame >= 6 and (x + y + frame) % 2:
                continue
            if frame == 7 and (x // 2 + y // 2) % 2:   # 마지막 컷: 2px 바둑판
                continue
            ry, rx = (dy - ly) / lr, (dx - lx) / lr                 # 덩어리마다 왼쪽 위가 밝다
            tok = "P05" if ry + rx * 0.5 < -0.35 else ("P04" if d < 0.82 else "P03")
            img.putpixel((x, y), C(tok))
    return img


def sparks_red(angle, frame, size=16):
    """레이저가 벽에 닿은 자리: 금속 불꽃 모양의 붉은 판(SD-16 §10.1 '색 교체')."""
    img = Image.new("RGBA", (size, size), CLEAR)
    c = size // 2
    for k, off in enumerate((-30, 10, 35, 60, -60)):
        r = 2 + frame * 2 + k % 2
        ra = math.radians(angle + 180 + off)
        _px(img, c + r * math.cos(ra), c + r * math.sin(ra), "P54" if frame < 2 else "P53")
        if frame == 0:
            _px(img, c + (r - 1) * math.cos(ra), c + (r - 1) * math.sin(ra), "P09")
    return img


ANCHOR = {"flash32": (15.5, 15.5), "flash16": (7.5, 7.5), "proj": (8.5, 8.5), "mid16": (8.0, 8.0), "mid64": (32.0, 32.0), "mid96": (48.0, 48.0)}


# ================================================================ 단계 1-9b 투척·설치(SD-11 §3.4 · §9.2 · SD-13 §3.8.4)
# 던진 물체(16칸 무방향 4컷 — 날며 구른다) · 놓인 지뢰(16칸 2컷 — 불빛 깜박임) · 지대(32칸 3컷, 일반 혼합 바둑판) · 플라스마·펄스 폭발(96칸)
THROWN = ("frag", "plasma", "pulse", "molotov", "gas", "smoke", "nuka")


def thrown(kind, frame):
    """수류탄·화염병·통: 컷마다 90°씩 돈다(위에서 본 몸통 + 손잡이·심지 방향)."""
    img = Image.new("RGBA", (16, 16), CLEAR)
    a = math.radians(frame * 90 + 20)
    ux, uy = math.cos(a), math.sin(a)
    body = {"frag": ("P30", "P31", "P29"), "plasma": ("P03", "P04", "P02"), "pulse": ("P12", "P13", "P11"),
            "molotov": ("P36", "P37", "P35"), "gas": ("P05", "P06", "P04"), "smoke": ("P30", "P31", "P29"),
            "nuka": ("P53", "P54", "P52")}[kind]
    ln, wd = {"molotov": (3.8, 1.9), "gas": (3.2, 2.1), "smoke": (3.2, 2.1), "nuka": (3.0, 2.2)}.get(kind, (2.8, 2.4))
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - 8, y + 0.5 - 8
            t = dx * ux + dy * uy
            s = -dx * uy + dy * ux
            if (t / ln) ** 2 + (s / wd) ** 2 <= 1.0:
                tok = body[1] if s < -0.5 else (body[2] if s > 0.8 else body[0])
                if kind == "frag" and int(t + 3) % 2 == 0 and abs(s) < 1.2:
                    tok = body[2]                                        # 파편 홈
                if kind == "plasma" and abs(t) < 0.7:
                    tok = "P56"                                          # 녹색 띠
                if kind == "pulse" and math.hypot(t, s) < 1.0:
                    tok = "P46"
                if kind in ("gas", "smoke") and abs(t - 0.6) < 0.5:
                    tok = "P48" if kind == "gas" else "P56"
                if kind == "nuka" and abs(t) < 0.6:
                    tok = "P09"
                img.putpixel((x, y), C(tok))
    if kind == "molotov":                                                # 병목 + 불붙은 헝겊
        for k, tok in ((ln + 0.6, "P22"), (ln + 1.6, "P60"), (ln + 2.4, "P50")):
            _px(img, 8 + k * ux - 0.5, 8 + k * uy - 0.5, tok)
    elif kind in ("frag", "plasma", "pulse", "nuka"):                    # 안전 손잡이(스푼)
        _px(img, 8 + (ln + 0.4) * ux - 0.5, 8 + (ln + 0.4) * uy - 0.5, "P06")
        _px(img, 8 + (ln + 0.4) * ux + 1.2 * -uy - 0.5, 8 + (ln + 0.4) * uy + 1.2 * ux - 0.5, "P07")
    return img


MINES = ("frag", "pulse", "cap")


def mine(kind, frame):
    """놓인 지뢰: 납작한 원판(파편 국방색 · 펄스 회청) 또는 병뚜껑 도시락통. 1컷째에 경보등이 켜진다(붉은·푸른)."""
    img = Image.new("RGBA", (16, 16), CLEAR)
    if kind == "cap":                                                    # 병뚜껑 지뢰: 붉은 도시락통 + 뚜껑 둘레 병뚜껑
        for y in range(5, 12):
            for x in range(3, 13):
                tok = "P53" if y > 6 else "P54"
                if y == 11 or x in (3, 12):
                    tok = "P52"
                img.putpixel((x, y), C(tok))
        for x in (4, 7, 10):
            img.putpixel((x, 5), C("P07"))
        img.putpixel((8, 8), C("P50" if frame else "P47"))
        return img
    ramp = ("P29", "P30", "P31") if kind == "frag" else ("P11", "P12", "P13")
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - 8, (y + 0.5 - 9) * 1.6                   # 비스듬히 본 원판
            d = math.hypot(dx, dy)
            if d <= 5.2:
                tok = ramp[0] if d > 4.4 or dy > 2.5 else (ramp[2] if dy < -2.0 else ramp[1])
                if abs(d - 2.6) < 0.5:
                    tok = ramp[0]                                        # 뇌관 고리
                img.putpixel((x, y), C(tok))
    lamp = ("P54" if kind == "frag" else "P46") if frame else ("P52" if kind == "frag" else "P44")
    img.putpixel((8, 8), C(lamp))
    if frame:
        for q in ((7, 8), (9, 8), (8, 7)):
            img.putpixel(q, C("P53" if kind == "frag" else "P45"))
    return img


def zone(kind, frame, size=32):
    """지대(일반 혼합 — 반투명 대신 바둑판): fire = 바닥 불꽃 덩이 · gas = 누런 최루 구름 · smoke = 회색 연막. 3컷 순환(덩이가 자리를 바꾼다)."""
    img = Image.new("RGBA", (size, size), CLEAR)
    rnd = random.Random({"fire": 3, "gas": 5, "smoke": 7, "rad": 11}[kind] * 10 + frame)
    lobes = [(rnd.uniform(-9, 9), rnd.uniform(-7, 7), rnd.uniform(4.5, 7.5)) for _ in range(6)]
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - size / 2, y + 0.5 - size / 2
            best = min(((math.hypot(dx - lx, dy - ly) / lr, ly, lr) for lx, ly, lr in lobes))
            d, ly, lr = best
            if d > 1.0:
                continue
            ry = (dy - ly) / lr
            if kind == "fire":
                if d < 0.45:
                    tok = "P50" if ry < 0 else "P60"
                elif d < 0.8:
                    tok = "P60" if ry < 0.2 else "P27"
                else:
                    tok = "P26" if (x + y + frame) % 2 == 0 else None
            elif kind == "gas":
                if (x + y + frame) % 2:
                    continue
                tok = "P32" if ry < -0.3 else ("P31" if d < 0.75 else "P30")
            elif kind == "rad":                                              # 방사능 아지랑이(1-9d): 성긴 녹색 점 · 가운데 밝은 알갱이
                if d < 0.22 and (x * 3 + y + frame) % 5 == 0:
                    tok = "P57"
                elif (x + 2 * y + frame) % 4:
                    continue
                else:
                    tok = "P56" if d < 0.55 else ("P55" if d < 0.85 else "P35")
            else:
                if (x + y + frame) % 2 and d > 0.5:
                    continue
                tok = "P08" if ry < -0.3 else ("P07" if d < 0.75 else "P06")
            if tok:
                img.putpixel((x, y), C(tok))
    return img


def boom_tint(frame, kind, size=96):
    """플라스마(녹) · 펄스(청) 폭발: 불덩이 모양을 색만 바꾼다(SD-16 §10.1 '색 교체가 기본')."""
    base = boom_fire(frame, size)
    swap = {"plasma": {"P09": "P57", "P50": "P57", "P60": "P56", "P27": "P55", "P26": "P36", "P25": "P35", "P24": "P34"},
            "pulse": {"P09": "P63", "P50": "P63", "P60": "P46", "P27": "P45", "P26": "P44", "P25": "P43", "P24": "P43"}}[kind]
    rev = {P.rgb(k): P.rgb(v) for k, v in swap.items()}
    px = base.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in rev:
                px[x, y] = rev[(r, g, b)] + (255,)
    return base


# ================================================================ 단계 1-9c 숨긴 함정(SD-11 §9.2): 발견했을 때만 그린다(바닥층, 일반 혼합)
def trap(kind, frame=0):
    """bear 덫(0 벌림 · 1 닫힘) · plate 압력판 · wire 철선 말뚝 + 수류탄 다발 · claymore 지향성 파편 지뢰(오른쪽을 향함) ·
    shotgun 함정 산탄총(오른쪽을 향한 총 + 받침) · 16칸 또는 32칸(shotgun)."""
    size = 32 if kind == "shotgun" else 16
    im = Image.new("RGBA", (size, size), CLEAR)
    d = __import__("PIL.ImageDraw", fromlist=["Draw"]).Draw(im)
    if kind == "bear":
        if frame == 0:                                                        # 벌린 톱니 턱(위에서 본 원) + 가운데 발판
            for a in range(0, 360, 30):
                r = 6.5
                x, y = 8 + r * math.cos(math.radians(a)), 9 + r * 0.7 * math.sin(math.radians(a))
                _px(im, x, y, "P06" if a % 60 == 0 else "P05")
            d.ellipse([3, 5, 13, 13], outline=C("P04"))
            d.rectangle([6, 8, 10, 10], fill=C("P24")); d.point((8, 9), fill=C("P07"))
        else:                                                                 # 닫힌 턱(한 줄)
            d.rectangle([2, 8, 14, 10], fill=C("P05")); d.line([2, 8, 14, 8], fill=C("P06"))
            for x in range(3, 14, 2):
                d.point((x, 7), fill=C("P07"))
        d.line([13, 11, 15, 14], fill=C("P04"))                               # 말뚝 사슬
    elif kind == "plate":                                                     # 흙에 묻힌 판 + 비죽 나온 선
        d.rectangle([3, 6, 12, 11], fill=C("P17")); d.rectangle([4, 7, 11, 10], fill=C("P18"))
        d.line([4, 7, 11, 7], fill=C("P19")); d.line([12, 9, 15, 7], fill=C("P54"))
    elif kind == "wire":                                                      # 철선 말뚝 + 테이프로 묶은 수류탄 셋
        d.line([3, 3, 3, 13], fill=C("P18")); d.point((3, 2), fill=C("P19"))
        for i, (x, y) in enumerate(((6, 9), (9, 9), (7, 12))):
            d.ellipse([x - 1, y - 2, x + 2, y + 1], fill=C("P30")); d.point((x, y - 2), fill=C("P31"))
        d.line([5, 10, 11, 10], fill=C("P06"))
    elif kind == "claymore":                                                  # 휜 국방색 상자 · 다리 둘 · 앞면 글자 띠 · 철선
        d.polygon([(4, 4), (11, 3), (12, 10), (4, 11)], fill=C("P30")); d.line([11, 3, 12, 10], fill=C("P31"))
        d.line([6, 6, 10, 6], fill=C("P32")); d.line([5, 11, 4, 14], fill=C("P29")); d.line([10, 10, 11, 14], fill=C("P29"))
        d.point((13, 7), fill=C("P07")); d.point((14, 7), fill=C("P06"))
    elif kind == "shotgun":                                                   # 나무 받침 위 산탄총(오른쪽) + 방아쇠 줄
        d.rectangle([10, 20, 12, 28], fill=C("P18")); d.rectangle([20, 20, 22, 28], fill=C("P18"))
        d.rectangle([8, 18, 24, 20], fill=C("P19")); d.line([8, 18, 24, 18], fill=C("P20"))
        d.rectangle([4, 14, 10, 16], fill=C("P18")); d.rectangle([10, 13, 28, 15], fill=C("P04")); d.line([10, 13, 28, 13], fill=C("P06"))
        d.rectangle([14, 16, 18, 17], fill=C("P18"))
        d.line([13, 17, 8, 26], fill=C("P07"))
    return im


def aura_rad(frame, size=48):
    """빛나는 개체 오라(SD-16 §10.5 '덧그림 4프레임', 가산): 몸 윤곽(발 기준 키 40px)을 따라 도는 녹색 테 + 위로 떠오르는 알갱이.
    가산이라 어두운 지하에서 빛나 보이고, 밝은 바닥에서도 테가 성겨 허옇게 바래지 않는다. 기준점 = 발(24, 44)."""
    img = Image.new("RGBA", (size, size), CLEAR)
    cx, cy, rx, ry = 24.0, 26.0, 12.5, 19.0
    for y in range(size):
        for x in range(size):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = math.hypot(dx, dy)
            if 0.82 <= d <= 1.08:                                       # 윤곽 테: 4컷 동안 밝은 마디가 몸을 한 바퀴 돈다
                ang = (math.degrees(math.atan2(dy, dx)) + 360.0) % 360.0
                ph = (ang - frame * 90.0) % 360.0
                if ph < 70.0 and (x + y) % 2 == 0:
                    img.putpixel((x, y), C("P57" if ph < 25.0 else "P56"))
                elif (x * 3 + y * 5 + frame) % 7 == 0:
                    img.putpixel((x, y), C("P55"))
    rnd = random.Random(29)
    for i in range(9):                                                 # 떠오르는 알갱이: 컷마다 4px씩 위로, 꼭대기에서 사그라진다
        bx, by0 = rnd.uniform(14, 34), rnd.uniform(18, 44)
        y = by0 - frame * 4.0
        if y < 4:
            y += 40
        tok = "P57" if y < 16 else ("P56" if y < 32 else "P55")
        img.putpixel((int(bx), int(y)), C(tok))
        if i % 3 == 0 and y > 1:
            img.putpixel((int(bx), int(y) - 1), C("P55"))
    return img
