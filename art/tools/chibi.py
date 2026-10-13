"""아이작풍 인물 그림 체계 v1 (SD-16 §5 v2.0, 리드 결정 2026-10-13: 그림체만 아이작풍, 맵·시스템은 그대로).

인물 = 몸(이동 방향, 5방향 × 대기·걷기·달리기·구르기) + 머리(조준 방향, 5방향 × 표정) + 손 무기.
머리는 단위 구(球)를 기준으로 머리 좌표계(lx 오른쪽, ly 아래, lz 얼굴 앞)에서 머리카락·얼굴·장비를 정하고,
보는 방향(YAW)으로 돌려 점 단위 z-버퍼로 그린다. 그래서 같은 머리가 다섯 방향에서 어긋나지 않고, 구 밖으로 튀어나온
묶음 머리·챙·꽁지도 깊이에 맞게 앞뒤가 정해진다.

외형 코드(SD-07b §3): 몸 M1 M2 F1 F2 E1 E2 K1 · 피부 S1~S6 SG1 SG2 · 머리 HR00~HR11 · 머리색 H1~H8 ·
몸통 T01~T16(+GOWN 환자복) · 낡음 0~2 · 팔레트 PF00~PF12 · 머리 장비 HD01~HD18 · 눈 장비 EY01~EY08.
색은 전부 마스터 64 + 교체 램프(피부·머리색·세력) 안에서 고른다.
"""
import os, sys, math, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

CLEAR = (0, 0, 0, 0)
C = lambda t: P.rgb(t) + (255,)
INK = C("P01")
VIEWS = ("S", "SE", "E", "NE", "N")
YAW = {"S": 0.0, "SE": 38.0, "E": 72.0, "NE": 128.0, "N": 180.0}   # 옆모습은 얼굴을 덜 돌린다(눈이 윤곽에 붙지 않게)
LIGHT = (-0.45, -0.65, 0.62)
_m = math.sqrt(sum(a * a for a in LIGHT))
L = tuple(a / _m for a in LIGHT)
FACES = ("idle", "blink", "fire", "talk", "hurt")
# 맵 크기 머리(1배)의 눈 도장: 구면 위 타원을 픽셀마다 계산하면 22픽셀 머리에서 꼬리·떨어진 하이라이트가 생겨서
# 손으로 찍은 모양을 투영한 눈 중심에 얹는다. '#' 먹, 'w' 하이라이트(빛이 오는 왼쪽 위), 'l' 속눈썹(여), '.' 빈칸.
# 정면(앞으로 향한 정도 f > 0.75) · ¾(f > 0.42) · 옆(그 아래). 초상화(2배 이상)는 매끄러운 타원 그대로.
EYE_STAMP = {
    "open": ([".##.", "#w##", "####", "####", ".##."], [".#.", "#w#", "###", "###", ".#."], ["##", "w#", "##", "##"]),
    "shut": (["####"], ["###"], ["##"]),
    "hurt": (["#..", ".##", "#.."], ["#.", ".#", "#."], ["#.", ".#", "#."]),
}


def ramp(tokens):
    return [C(t) if not str(t).startswith("#") else tuple(int(t[i:i + 2], 16) for i in (1, 3, 5)) + (255,) for t in tokens]


def skin_ramp(code):
    return ramp(P.SKIN[code])


def hair_ramp(code):
    return ramp(P.HAIR[code])


def fac_ramp(code):
    r = ramp(P.PF[code])
    return r[:4], r[4:6]


def shade(r, d, hi=0.72, lo=0):
    """빛 세기 d → 4단 램프(어두움·그늘·바탕·밝음). 아이작풍: 면은 넓게."""
    if d > hi:
        return r[min(len(r) - 1, lo + 3)]
    if d > 0.18:
        return r[lo + 2]
    if d > -0.35:
        return r[lo + 1]
    return r[lo]


def outline(img, col=INK, thick_bottom=True):
    """바깥 1px 먹선 + 아래쪽 한 줄 더(묵직한 밑선)."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                o[x, y] = col
    if thick_bottom:
        o2 = out.copy().load()
        for y in range(2, h):
            for x in range(w):
                if not o2[x, y][3] and o2[x, y - 1] == col and o2[x, y - 2][3] and o2[x, y - 2] != col:
                    o[x, y] = col
    return out


# ================================================================ 머리
class Look:
    """외형 코드 한 벌. body M1…, skin S3, hair HR03, color H1, torso T01, worn 0, faction PF-01|None, gear HD..|None, eyes EY..|None"""

    def __init__(self, body="M1", skin="S3", hair="HR03", color="H1", torso="T01", worn=0, faction=None, gear=None, eyes=None):
        self.body, self.skin, self.hair, self.color = body, skin, hair, color
        self.torso, self.worn, self.faction, self.gear, self.eyes = torso, worn, faction, gear, eyes

    @staticmethod
    def parse(code):
        b, sk, hr, hc, t, worn, pf, hd, ey, *_ = code.split("-")
        return Look(b, sk, hr, hc, t, int(worn), None if pf == "PF00" else "PF-" + pf[2:],
                    None if hd == "HD00" else hd, None if ey == "EY00" else ey)


HEAD_SIZE = {"M1": (22, 20), "M2": (23, 20), "F1": (22, 20), "F2": (22, 20), "E1": (22, 19), "E2": (22, 19), "K1": (20, 18)}
HC = 20                                   # 머리 칸 40×40, 구 중심 (20, 22)


class Canvas:
    """점 단위 z-버퍼. put(x, y, z, col): z가 클수록 앞(보는 사람 쪽)."""

    def __init__(self, w=40, h=40):
        self.w, self.h = w, h
        self.z = [[-9.0] * w for _ in range(h)]
        self.c = [[None] * w for _ in range(h)]

    def put(self, x, y, z, col):
        x, y = int(round(x - 0.5)), int(round(y - 0.5))
        if 0 <= x < self.w and 0 <= y < self.h and z > self.z[y][x]:
            self.z[y][x] = z
            self.c[y][x] = col

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), CLEAR)
        px = img.load()
        for y in range(self.h):
            for x in range(self.w):
                if self.c[y][x] is not None:
                    px[x, y] = self.c[y][x]
        return img


class Head:
    def __init__(self, look, view, face="idle", scale=1.0):
        self.look, self.view, self.face = look, view, face
        self.th = math.radians(YAW[view])
        W, H = HEAD_SIZE.get(look.body, (22, 20))
        self.scale = scale
        self.rx, self.ry = W / 2 * scale, (H / 2 - 0.3) * scale
        self.cx, self.cy = HC * scale, 22 * scale
        self.skin = skin_ramp(look.skin)
        self.hair = hair_ramp(look.color)
        self.cv = Canvas(int(40 * scale), int(40 * scale))

    # 머리 좌표 ↔ 화면
    def to_view(self, lx, ly, lz):
        s, c = math.sin(self.th), math.cos(self.th)
        return lx * c + lz * s, ly, -lx * s + lz * c

    def to_screen(self, lx, ly, lz):
        nx, ny, nz = self.to_view(lx, ly, lz)
        return self.cx + nx * self.rx, self.cy + ny * self.ry, nz

    def light(self, nx, ny, nz):
        return nx * L[0] + ny * L[1] + nz * L[2]

    # 구 밖 덩어리(묶음 머리·챙·꽁지): 머리 좌표의 타원체를 점으로 찍는다
    def blob(self, center, radii, col_ramp, hi=0.72, lumpy=0.0, seed=0, behind_body=False):
        cx, cy, cz = center
        ax, ay, az = radii
        n = int(max(ax * self.rx, ay * self.ry, az * self.rx) * 6) + 8
        rnd = random.Random(seed)
        for i in range(n):
            for j in range(2 * n):
                u = math.pi * (i + 0.5) / n
                v = 2 * math.pi * j / (2 * n)
                ex, ey, ez = math.sin(u) * math.cos(v), math.cos(u), math.sin(u) * math.sin(v)
                k = 1.0 + (lumpy * (rnd.random() - 0.5) if lumpy else 0.0)
                for t in (1.0, 0.75, 0.5, 0.25):
                    lx, ly, lz = cx + ex * ax * t * k, cy + ey * ay * t * k, cz + ez * az * t * k
                    sx, sy, sz = self.to_screen(lx, ly, lz)
                    if behind_body and sz < 0 and sy > self.cy + self.ry * 0.7 and self.view in ("S", "SE"):
                        continue                                              # 몸 뒤로 가려지는 부분(앞모습)
                    nx, ny, nz = self.to_view(ex, ey, ez)
                    self.cv.put(sx, sy, sz, shade(col_ramp, self.light(nx, ny, nz), hi))

    def disk(self, center, rx, rz, y_tilt, col, edge=None, front_only=False):
        """수평 원판(챙): 머리 좌표 (cx, cy, cz)에서 반지름 rx(옆)·rz(앞뒤). y_tilt: 앞쪽이 내려가는 정도."""
        cx, cy, cz = center
        n = int(60 * max(1.0, self.scale))
        for i in range(n + 1):
            for j in range(n + 1):
                u, v = -1 + 2 * i / n, -1 + 2 * j / n
                if u * u + v * v > 1:
                    continue
                if front_only and v < -0.15:
                    continue
                lx, lz = cx + u * rx, cz + v * rz
                ly = cy + y_tilt * v
                sx, sy, sz = self.to_screen(lx, ly, lz)
                rim = u * u + v * v > 0.72
                self.cv.put(sx, sy, sz + 0.02, edge if (rim and edge) else col)

    # -------------------------------------------------------- 그리기
    def render(self):
        lk = self.look
        hidden_head = lk.torso in ("T10", "T15")              # 방호 후드·스텔스 헬멧: 머리 전체를 덮는다
        self.sphere(hidden_head)
        if not hidden_head and self.scale < 2:
            self.eye_stamps()
        if not hidden_head:
            self.hair_extras()
            self.gear_draw()
        else:
            self.full_hood()
        img = self.cv.image()
        img = outline(img)
        if self.scale >= 2:                                                   # 초상화: 먹선 2px(크게 그려도 굵기가 같아 보이게)
            img = outline(img, thick_bottom=False)
        if not hidden_head:
            img = self.eyewear(img)
        return img

    def sphere(self, hidden):
        lk, cv = self.look, self.cv
        for y in range(cv.h):
            for x in range(cv.w):
                nx, ny = (x + 0.5 - self.cx) / self.rx, (y + 0.5 - self.cy) / self.ry
                q = nx * nx + ny * ny
                if q > 1.0:
                    continue
                nz = math.sqrt(max(0.0, 1.0 - q))
                d = self.light(nx, ny, nz)
                s, c = math.sin(self.th), math.cos(self.th)
                lx, lz, ly = nx * c - nz * s, nx * s + nz * c, ny
                if hidden:
                    continue
                col = self.surface(lx, ly, lz, d)
                cv.put(x + 0.5, y + 0.5, nz, col)

    def eye_stamps(self):
        lk, face = self.look, self.face
        kid, fem = lk.body == "K1", lk.body in ("F1", "F2", "E2")
        kind = "shut" if face in ("blink", "fire", "smile") else "hurt" if face == "hurt" else "open"
        ex0, ey = 0.36, 0.2 if not kid else 0.22
        for side in (-1, 1):
            ex = side * ex0
            ez = math.sqrt(max(0.0, 1.0 - ex * ex - ey * ey))
            sx, sy, f = self.to_screen(ex, ey, ez)
            if f < 0.12:
                continue                                                     # 머리 뒤로 돌아간 눈
            stamp = EYE_STAMP[kind][0 if f > 0.75 else 1 if f > 0.42 else 2]
            if kind == "hurt" and side == 1:
                stamp = [r[::-1] for r in stamp]                             # > <
            h, w = len(stamp), len(stamp[0])
            x0 = int(round(sx - w / 2.0))
            y0 = int(round(sy - h / 2.0 + (0.5 if kind == "shut" else 0.0)))
            rows = [list(r) for r in stamp]
            if fem and kind == "open" and w >= 3:                            # 속눈썹: 바깥 위 한 점
                rows[0] = (["l"] + rows[0]) if side == -1 else (rows[0] + ["l"])
                if side == -1:
                    x0 -= 1
                    rows = [rows[0]] + [["."] + r for r in rows[1:]]
                else:
                    rows = [rows[0]] + [r + ["."] for r in rows[1:]]
            for j, row in enumerate(rows):
                for i, ch in enumerate(row):
                    if ch == ".":
                        continue
                    px, py = x0 + i, y0 + j
                    hit = self._head_point(px, py)
                    if hit is None:
                        continue
                    (lx, ly, lz), nz = hit
                    if lz < 0.0 or self.hair_at(lx, ly, lz) is not None:
                        continue                                             # 앞머리에 가린 곳
                    self.cv.put(px + 0.5, py + 0.5, nz + 0.01, C("P09") if ch == "w" else C("P00"))

    def _head_point(self, x, y):
        """화면 픽셀 → 머리 구 위의 점(머리 좌표)과 보는 쪽 깊이. 구 밖이면 None."""
        nx, ny = (x + 0.5 - self.cx) / self.rx, (y + 0.5 - self.cy) / self.ry
        q = nx * nx + ny * ny
        if q > 1.0:
            return None
        nz = math.sqrt(1.0 - q)
        s, c = math.sin(self.th), math.cos(self.th)
        return (nx * c - nz * s, ny, nx * s + nz * c), nz

    # 머리 표면 한 점의 색: 머리카락 → 얼굴 → 피부
    def surface(self, lx, ly, lz, d):
        lk = self.look
        hair = self.hair_at(lx, ly, lz)
        if hair is not None:
            return shade(self.hair, d) if hair == "hair" else hair
        col = shade(self.skin, d, 0.9)
        if lz > 0.25:
            f = self.face_at(lx, ly, lz)
            if f is not None:
                return f
        if abs(lz) < 0.2 and -0.02 < ly < 0.32 and abs(lx) > 0.9:            # 귀
            return self.skin[1] if abs(lz) < 0.08 and 0.06 < ly < 0.24 else self.skin[2]
        if lk.skin in ("SG1", "SG2"):                                       # 구울: 벗겨진 살갗 얼룩
            if math.sin(lx * 9 + 1.3) * math.sin(ly * 7 - lz * 5) > 0.72:
                return self.skin[1]
        return col

    def hair_at(self, lx, ly, lz):
        """머리카락이면 'hair' 또는 특정 색, 아니면 None."""
        hr = self.look.hair
        if hr == "HR00":
            return None
        jag = 0.07 if int((lx + 2) * 9) % 2 else -0.04
        front = -0.32 + jag
        temple = -0.1 - 0.22 * max(0.0, lz) / 0.3
        nape = 0.62
        if hr == "HR01":                                                    # 짧은 스포츠: 높고 짧게, 결이 보이게
            front, temple, nape = -0.5, -0.32, 0.3
        elif hr == "HR02":                                                  # 가르마: 매끈한 앞머리 + 가르마 선
            front = -0.36 + 0.06 * max(0.0, lx + 0.25)
            if lz > 0 and abs(lx + 0.25) < 0.05 and ly < -0.45:
                return self.hair[0]
        elif hr == "HR05":                                                  # 단발: 얼굴 옆을 감싸 턱선까지
            temple, nape = 0.55, 0.72
            if lz > 0.3 and abs(lx) > 0.58 and ly < 0.5:
                return "hair"
        elif hr == "HR06":                                                  # 긴 생머리
            temple, nape = 0.7, 0.95
            if lz > 0.3 and abs(lx) > 0.62 and ly < 0.75:
                return "hair"
        elif hr == "HR08":                                                  # 덥수룩: 앞머리가 눈썹까지 크게 들쭉날쭉
            front = -0.12 + (0.12 if int((lx + 2) * 6) % 2 else -0.06)
            temple = 0.05
        elif hr == "HR10":                                                  # 반삭: 가운데 띠만
            if abs(lx) > 0.38 and ly > -0.75:
                return self.skin[2] if (int(lx * 20) + int(ly * 20)) % 3 == 0 else None
            front = -0.42
        elif hr == "HR11":                                                  # 파마: 앞머리도 곱슬 덩이
            front = -0.25 + (0.1 if (int((lx + 2) * 7) + int((ly + 2) * 5)) % 3 == 0 else 0)
            nape = 0.7
        if lz >= 0.3:
            line = front
        else:
            line = temple
        if lz < -0.12:
            line = nape
        if ly < line:
            if hr == "HR01" and (int((lx + 2) * 13) * 2 + int((ly + 2) * 11) * 3) % 5 == 0:
                return self.hair[1]                                          # 짧게 깎은 결(드문드문)
            if hr == "HR11" and (int((lx + 2) * 9) + int((ly + 2) * 9) + int((lz + 2) * 9)) % 4 == 0:
                return self.hair[3]                                          # 곱슬 반짝임
            return "hair"
        return None

    def face_at(self, lx, ly, lz):
        lk, face = self.look, self.face
        kid = lk.body == "K1"
        old = lk.body in ("E1", "E2")
        fem = lk.body in ("F1", "F2", "E2")
        ex0 = 0.36
        er = (0.21, 0.27) if not kid else (0.24, 0.31)
        squint = face in ("fire", "blink", "hurt", "smile")
        if face in ("smile", "angry", "sad", "tired", "surprise"):
            r = self.portrait_face(lx, ly, lz, ex0, er, fem, old)
            if r is not False:
                return r
        for side in (-1, 1):
            ex, ey = side * ex0, 0.2
            sx, sy = er[0], (0.06 if squint else er[1])
            e = ((lx - ex) / sx) ** 2 + ((ly - ey) / sy) ** 2
            if self.scale < 2:                                               # 맵 머리: 눈은 eye_stamps()가 찍는다
                e = 9.0
                if old and 0.16 < ly - ey - er[1] < 0.24 and abs(lx - ex) < 0.14:
                    return self.skin[1]
                continue
            if e <= 1.0:
                if face == "hurt":
                    return C("P00") if abs((lx - ex) * 1.3) < abs(ly - ey) + 0.05 else None   # ><
                col = C("P00")
                if face in ("idle", "talk") and lx - ex < -0.06 and ly - ey < -0.1 and e > 0.15:
                    col = C("P09")
                return col
            if fem and not squint and -0.18 < (ly - ey) / sy + 1.15 < 0.25 and side * (lx - ex) > 0.1 and side * (lx - ex) < 0.28:
                return C("P00")                                              # 속눈썹(바깥 위)
            if old and 0.16 < ly - ey - er[1] < 0.24 and abs(lx - ex) < 0.14:
                return self.skin[1]                                          # 눈 밑 주름
        # 입
        if face == "fire":
            if abs(lx) < 0.16 and 0.5 < ly < 0.72:
                return C("P52") if ly > 0.62 else C("P51")
        elif face == "talk":
            if abs(lx) < 0.12 and 0.52 < ly < 0.68:
                return C("P51")
        elif face == "hurt":
            if abs(lx) < 0.14 and 0.55 < ly < 0.66:
                return C("P51")
        elif abs(lx) < (0.07 if fem else 0.09) and 0.56 < ly < 0.64:
            return self.skin[0] if not fem else C("P53")
        if old and abs(abs(lx) - 0.32) < 0.05 and 0.48 < ly < 0.62:
            return self.skin[1]                                              # 팔자 주름
        if lk.body == "M2" and abs(lx) < 0.5 and 0.78 < ly and lz > 0.4:
            return self.skin[1]                                              # 두툼한 턱 그늘
        return None

    def portrait_face(self, lx, ly, lz, ex0, er, fem, old):
        """대화 초상화 표정(SD-12 §6.1 표정 칸): 미소·화남·슬픔·피곤·놀람. 해당 없으면 False(평소 얼굴로)."""
        face = self.face
        for side in (-1, 1):
            ex, ey = side * ex0, 0.2
            dx, dy = (lx - ex) / er[0], (ly - ey) / er[1]
            if face == "smile":                                              # 웃는 눈 ^ ^
                if abs(dy + 0.15 - 0.55 * dx * dx) < 0.22 and abs(dx) < 0.95:
                    return C("P00")
            elif face == "surprise":                                         # 동그란 눈 + 흰자
                e = dx * dx + dy * dy
                if e <= 1.15:
                    return C("P00") if e < 0.35 else C("P09") if e < 0.9 else C("P01")
            elif face == "tired":                                            # 반쯤 감긴 눈
                e = dx * dx + dy * dy
                if e <= 1.0 and dy > -0.1:
                    return C("P00") if not (dx < -0.2 and dy < 0.25) else C("P09")
                if e <= 1.0 and -0.25 < dy <= -0.1:
                    return self.skin[1]
            elif face in ("angry", "sad"):
                e = dx * dx + dy * dy
                if e <= 1.0:
                    return C("P09") if dx < -0.25 and dy < -0.3 else C("P00")
                tilt = side * (0.45 if face == "angry" else -0.4)            # 눈썹: 화남 ↘↙ / 슬픔 ↗↖
                bx = (lx - ex) / er[0]
                if abs(bx) < 1.0 and abs((ly - ey + er[1] * 1.45) / er[1] + tilt * bx) < 0.18:
                    return C("P01")
                if face == "sad" and side == -1 and 0.3 < dy < 2.4 and abs(dx + 0.1) < 0.18:
                    return C("P46") if dy > 1.0 else C("P15")                 # 눈물
        if face == "smile" and abs(lx) < 0.22 and abs(ly - 0.64 + 1.4 * lx * lx) < 0.035:
            return C("P51")
        if face == "surprise" and (lx / 0.09) ** 2 + ((ly - 0.62) / 0.08) ** 2 <= 1:
            return C("P51")
        if face == "angry" and abs(lx) < 0.14 and abs(ly - 0.58 - 1.2 * lx * lx) < 0.03:
            return C("P51")
        if face == "sad" and abs(lx) < 0.12 and abs(ly - 0.6 - 1.6 * lx * lx) < 0.03:
            return C("P51")
        if face == "tired" and abs(lx) < 0.08 and 0.57 < ly < 0.62:
            return self.skin[0]
        if face in ("smile", "angry", "sad", "tired", "surprise"):
            if abs(lx) < 0.25 and 0.4 < ly < 0.75:
                return None
        return False

    def hair_extras(self):
        hr, hc = self.look.hair, self.hair
        hat = self.look.gear is not None
        if hr == "HR07" and not hat:                                         # 올림 묶음: 정수리 뒤 쪽머리
            self.blob((0.0, -0.92, -0.35), (0.34, 0.3, 0.34), hc)
        if hr == "HR04":                                                     # 낮게 묶음: 목덜미 작은 꽁지
            self.blob((0.0, 0.62, -0.88), (0.22, 0.22, 0.2), hc, behind_body=True)
        if hr == "HR09":                                                     # 꽁지: 뒤로 늘어진 긴 묶음
            self.blob((0.0, 0.3, -1.02), (0.2, 0.2, 0.18), hc, behind_body=True)
            self.blob((0.0, 0.85, -1.08), (0.2, 0.42, 0.16), hc, behind_body=True)
        if hr in ("HR05", "HR06"):                                           # 옆·뒤로 떨어지는 머리 다발
            n = 0.75 if hr == "HR05" else 1.25
            for side in (-1, 1):
                self.blob((side * 0.88, 0.25 + n * 0.3, -0.15), (0.2, n * 0.45, 0.45), hc)
            self.blob((0.0, 0.3 + n * 0.3, -0.75), (0.75, n * 0.45, 0.3), hc, behind_body=True)
        if hr == "HR08":                                                     # 덥수룩: 정수리 삐침
            for k, (a, b) in enumerate(((-0.4, -0.95), (0.1, -1.02), (0.5, -0.9))):
                self.blob((a, b, -0.1), (0.16, 0.16, 0.16), hc, seed=k)
        if hr == "HR11":                                                     # 곱슬 덩이(윤곽이 울퉁불퉁)
            for k in range(14):
                a = 2 * math.pi * k / 14
                self.blob((math.cos(a) * 0.95, -0.35 + math.sin(a) * 0.55 - 0.3, math.sin(a) * 0.6 - 0.2),
                          (0.2, 0.2, 0.2), hc, seed=k)

    # -------------------------------------------------------- 머리 장비
    def shell(self, cut, col_ramp, scale=1.09, front_cut=None, hi=0.72):
        """머리를 덮는 껍데기(철모·모자 몸통): 구를 scale만큼 키운 표면에서 ly < cut(앞쪽은 front_cut)인 부분."""
        n = int(70 * max(1.0, self.scale))
        for i in range(n):
            for j in range(2 * n):
                u = math.pi * (i + 0.5) / n
                v = 2 * math.pi * j / (2 * n)
                ex, ey, ez = math.sin(u) * math.cos(v), -math.cos(u), math.sin(u) * math.sin(v)
                lim = cut if (front_cut is None or ez < 0.3) else front_cut
                if ey > lim:
                    continue
                sx, sy, sz = self.to_screen(ex * scale, ey * scale, ez * scale)
                nx, ny, nz = self.to_view(ex, ey, ez)
                self.cv.put(sx, sy, sz * scale, shade(col_ramp, self.light(nx, ny, nz), hi))

    def gear_draw(self):
        g = self.look.gear
        if not g:
            return
        grey = ramp(["P04", "P05", "P06", "P07"])
        fac_main, fac_acc = fac_ramp(self.look.faction or "PF-01")
        if g == "HD01":                                                      # 두건: 천을 묶음(뒤 매듭)
            self.shell(-0.25, ramp(["P24", "P25", "P26", "P27"]), 1.05)
            self.blob((0.0, -0.1, -1.0), (0.16, 0.14, 0.12), ramp(["P24", "P25", "P26", "P27"]))
        elif g == "HD02":                                                    # 안전모: 노란 돔 + 앞챙 + 가운데 골
            y = ramp(["P47", "P48", "P49", "P50"])
            self.shell(-0.12, y, 1.1)
            self.disk((0.0, -0.12, 0.25), 1.12, 1.15, 0.0, y[1], edge=y[0])
        elif g == "HD03":                                                    # 둥근 돔 헬멧(세력 색)
            self.shell(-0.05, fac_main, 1.1)
            self.disk((0.0, -0.05, 0.0), 1.13, 1.13, 0.0, fac_main[0])
        elif g == "HD04":                                                    # 계엄군 철모: 흑청, 깊게
            self.shell(0.02, ramp(["#1C2230", "#2A3346", "#3E4A62", "#5A6A86"]), 1.11)
            self.disk((0.0, 0.02, 0.0), 1.15, 1.15, 0.0, C("P01"))
        elif g == "HD05":                                                    # 야구모자: 돔 + 앞 챙
            cap = ramp(["P52", "P53", "P54", "P27"]) if self.look.faction is None else fac_main
            self.shell(-0.3, cap, 1.06)
            self.disk((0.0, -0.3, 0.95), 0.62, 0.55, 0.12, cap[1], edge=cap[0], front_only=True)
        elif g == "HD06":                                                    # 제복 모자: 납작한 윗면 + 챙 + 띠
            self.shell(-0.25, fac_main, 1.08)
            self.disk((0.0, -0.95, 0.0), 0.95, 0.95, 0.0, fac_main[2], edge=fac_main[1])
            self.disk((0.0, -0.28, 0.85), 0.62, 0.42, 0.1, C("P01"), front_only=True)
        elif g == "HD07":                                                    # 머릿수건: 정수리 천 + 뒤 매듭
            cl = ramp(["P19", "P20", "P21", "P22"])
            self.shell(-0.35, cl, 1.05, front_cut=-0.5)
            self.blob((0.0, -0.05, -1.0), (0.15, 0.12, 0.1), cl)
        elif g == "HD08":                                                    # 약탈자: 가시 두건
            leather = ramp(["P16", "P17", "P18", "P19"])
            self.shell(-0.2, leather, 1.06)
            for k in range(5):
                a = -0.9 + 0.45 * k
                self.blob((math.sin(a) * 0.95, -0.85, math.cos(a) * 0.3 - 0.2), (0.06, 0.22, 0.06), grey)
        elif g == "HD09":                                                    # 풀페이스 헬멧: 얼굴창
            self.shell(0.85, ramp(["P02", "P03", "P04", "P05"]), 1.08)
            for y in range(self.cv.h):                                         # 얼굴창은 아래 eyewear 단계에서
                pass
        elif g == "HD10":                                                    # 헤드폰
            for side in (-1, 1):
                self.blob((side * 1.0, 0.1, 0.0), (0.16, 0.26, 0.26), ramp(["P02", "P03", "P04", "P05"]))
            self.shell(-0.82, ramp(["P02", "P03", "P04", "P05"]), 1.06)
        elif g == "HD11":                                                    # 선원 모자: 흰 둥근 모자
            w = ramp(["P07", "P08", "P09", "P09"])
            self.shell(-0.35, w, 1.07)
            self.disk((0.0, -0.36, 0.0), 1.1, 1.1, 0.0, w[1], edge=C("P45"))
        elif g == "HD12":                                                    # 방호 두건: 얼굴만 남기고 감싼다
            hood = ramp(["P28", "P29", "P30", "P31"])
            self.shell(1.0, hood, 1.07, front_cut=-0.42)
        elif g == "HD13":                                                    # 무전 헤드셋: 한쪽 귀 + 마이크
            self.blob((1.0, 0.12, 0.05), (0.14, 0.22, 0.22), ramp(["P02", "P03", "P04", "P05"]))
            self.blob((0.75, 0.55, 0.75), (0.08, 0.06, 0.08), ramp(["P02", "P02", "P03", "P04"]))
            self.shell(-0.85, ramp(["P02", "P03", "P04", "P05"]), 1.05)
        elif g == "HD14":                                                    # 각성회 녹광 머리띠
            band = ramp(["P55", "P55", "P56", "P57"])
            self.shell(-0.3, band, 1.04, front_cut=-0.3)
            self.shell(-0.42, self.hair, 1.045)
        elif g == "HD15":                                                    # 장교 정모: 높은 윗면 + 금띠 + 검은 챙
            self.shell(-0.22, fac_main, 1.09)
            self.disk((0.0, -1.02, -0.05), 1.05, 1.0, 0.0, fac_main[2], edge=fac_main[1])
            self.disk((0.0, -0.24, 0.0), 1.1, 1.1, 0.0, fac_acc[1])
            self.disk((0.0, -0.18, 0.88), 0.66, 0.42, 0.12, C("P01"), front_only=True)
        elif g == "HD16":                                                    # 중절모
            felt = ramp(["P16", "P17", "P18", "P19"])
            self.shell(-0.25, felt, 1.08)
            self.disk((0.0, -0.25, 0.0), 1.45, 1.45, 0.06, felt[1], edge=felt[0])
            self.disk((0.0, -0.3, 0.0), 1.1, 1.1, 0.0, C("P02"))
        elif g == "HD17":                                                    # 헤드램프
            self.shell(-0.42, ramp(["P02", "P02", "P03", "P04"]), 1.04, front_cut=-0.42)
            self.blob((0.0, -0.45, 1.02), (0.16, 0.12, 0.08), ramp(["P49", "P50", "P50", "P09"]))
        elif g == "HD18":                                                    # 밀짚모자: 넓은 챙
            st = ramp(["P19", "P20", "P21", "P22"])
            self.shell(-0.3, st, 1.08)
            self.disk((0.0, -0.3, 0.0), 1.7, 1.7, 0.08, st[2], edge=st[1])
            self.disk((0.0, -0.33, 0.0), 1.1, 1.1, 0.0, C("P53"))

    def full_hood(self):
        """T10 방호복 후드(둥근 노란 후드 + 얼굴창), T15 스텔스 헬멧(고글 일체)."""
        if self.look.torso == "T10":
            hood = ramp(["P47", "P48", "P49", "P50"])
            self.shell(1.0, hood, 1.08)
            self.visor(0.1, 0.45, ramp(["P10", "P11", "P12", "P14"]))
        else:
            dark = ramp(["P10", "P11", "P12", "P13"])
            self.shell(1.0, dark, 1.06)
            for side in (-1, 1):
                self.blob((side * 0.36, 0.15, 0.9), (0.2, 0.17, 0.12), ramp(["P61", "P62", "P63", "P63"]))

    def visor(self, y0, y1, col_ramp):
        n = int(50 * max(1.0, self.scale))
        for i in range(n):
            for j in range(n):
                u, v = -1 + 2 * i / n, y0 + (y1 - y0) * j / n
                lx = u * 0.7
                lz2 = 1.0 - lx * lx - v * v
                if lz2 <= 0.05:
                    continue
                lz = math.sqrt(lz2) * 1.1
                sx, sy, sz = self.to_screen(lx, v, lz)
                nx, ny, nz = self.to_view(lx, v, lz)
                self.cv.put(sx, sy, sz + 0.2, shade(col_ramp, self.light(nx, ny, nz)))

    # -------------------------------------------------------- 눈 장비(먹선 뒤에 얹는다: 테가 얼굴 위로 보이게)
    def eyewear(self, img):
        e = self.look.eyes
        g = self.look.gear
        if not e and g != "HD09":
            return img
        d = ImageDraw.Draw(img)
        pts = []
        for side in (-1, 1):
            sx, sy, sz = self.to_screen(side * 0.36, 0.2, math.sqrt(1 - 0.36 ** 2 - 0.04))
            pts.append((sx, sy, sz))
        vis = [p for p in pts if p[2] > 0.15]
        if g == "HD09":                                                      # 풀페이스 헬멧 얼굴창
            if self.view != "N":
                xs = [p[0] for p in vis] or [self.cx]
                x0, x1 = int(min(xs)) - 3, int(max(xs)) + 3
                d.rectangle([x0, int(pts[0][1]) - 3, x1, int(pts[0][1]) + 3], fill=C("P11"), outline=INK)
                d.line([x0 + 1, int(pts[0][1]) - 2, x1 - 2, int(pts[0][1]) - 2], fill=C("P14"))
            return img
        if self.view == "N" or (self.view == "NE" and e in ("EY01", "EY02", "EY03", "EY05", "EY07")):
            if e == "EY06" or e == "EY04":                                   # 끈은 뒤에서도 보인다
                y = int(self.cy + 0.15 * self.ry)
                d.line([self.cx - self.rx + 1, y, self.cx + self.rx - 2, y], fill=C("P02"))
            return img
        rim = {"EY01": C("P02"), "EY02": C("P02"), "EY03": C("P19"), "EY05": C("P02"), "EY06": C("P03"), "EY07": C("P48"), "EY08": C("P02")}.get(e, C("P02"))
        for (sx, sy, sz) in vis:
            x, y = int(sx), int(sy)
            if e in ("EY01", "EY07") and (e != "EY07" or sx > self.cx - 1):
                d.ellipse([x - 3, y - 3, x + 3, y + 3], outline=rim)
            elif e == "EY02":
                d.rectangle([x - 3, y - 2, x + 3, y + 3], outline=rim)
            elif e == "EY03":
                d.line([x - 3, y + 1, x + 3, y + 1], fill=rim)
                d.arc([x - 3, y - 2, x + 3, y + 4], 0, 180, fill=rim)
            elif e == "EY04":
                if sx < self.cx + 2:
                    d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=C("P01"))
            elif e == "EY05":
                d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=C("P02"), outline=INK)
                d.point((x - 1, y - 1), fill=C("P05"))
            elif e == "EY06":
                d.ellipse([x - 4, y - 3, x + 4, y + 3], fill=C("P03"), outline=INK)
                d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=C("P36"))
                d.point((x - 1, y - 1), fill=C("P37"))
            elif e == "EY08":
                d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=C("P02"), outline=INK)
                d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=C("P54"))
        if len(vis) == 2 and e in ("EY01", "EY02", "EY05"):                  # 코다리
            d.line([int(vis[0][0]) + 3, int(vis[0][1]) - 1, int(vis[1][0]) - 3, int(vis[1][1]) - 1], fill=rim)
        if e == "EY06" and self.view != "S":
            y = int(pts[0][1])
            d.line([self.cx - self.rx + 1, y, int(min(p[0] for p in vis)) - 4 if vis else self.cx, y], fill=C("P02"))
        return img


def head(look, view, face="idle", scale=1.0):
    return Head(look, view, face, scale).render()


# ================================================================ 몸
# 몸 칸 32×32, 발 기준점 (16, 30). 머리는 따로 얹는다(머리 칸 40×40의 구 중심이 몸의 '목'에 오도록).
BODY = {   # 몸통 폭·높이, 다리 길이, 머리가 몸통을 덮는 깊이, 등 굽음(머리 앞으로)
    "M1": (14, 10, 6, 2, 0), "M2": (16, 11, 6, 2, 0), "F1": (12, 10, 6, 2, 0), "F2": (13, 10, 6, 2, 0),
    "E1": (13, 9, 5, 2, 1), "E2": (13, 9, 5, 2, 1), "K1": (10, 8, 4, 2, 0)}
# 보폭(컷당 px): 옆 E, 대각 SE·NE(축 거리), 앞뒤 S·N — 다리 길이에 맞춘 값. Locomotion 표(px·diag·px_v)와 같다.
STRIDE = {"walk": {"E": 4, "D": 3, "V": 3}, "run": {"E": 6, "D": 4, "V": 4}}
AXIS = {"S": (0, 1), "SE": (1, 1), "E": (1, 0), "NE": (1, -1), "N": (0, -1)}
SIDE = {"S": (1, 0), "SE": (1, -1), "E": (0, 1), "NE": (1, 1), "N": (1, 0)}           # 두 발이 벌어지는 축(화면)
BOB = {"walk": [0, 0, -1, 0, 0, -1], "run": [1, 0, -1, 1, 0, -1]}             # 두 발이 뜬 컷(2·5)에 몸이 뜬다


def stride(mode, view):
    return STRIDE[mode]["E" if view == "E" else "V" if view in ("S", "N") else "D"]


def foot(mode, view, f):
    """한 발의 (진행 축 위치 u px, 들림 px). 짧은 다리라 한 발이 2컷만 딛는 종종걸음:
    디딤 0·1(u = +p/2 → -p/2, 컷마다 정확히 -보폭 = 세계에서 고정), 2는 두 발 다 뜬 컷, 3·4는 다른 발, 5는 다시 뜬 컷.
    딛지 않은 동안만 발이 앞으로 돌아온다(SD-16 §3.6 ① 디딤발 고정)."""
    p = stride(mode, view)
    f %= 6
    up = 1 if mode == "walk" else 2
    u0 = (p + 1) // 2                                   # 정수 px: 디딤 두 컷의 차가 정확히 p(반올림 1px 어긋남 없음)
    return {0: (u0, 0), 1: (u0 - p, 0), 2: (u0 - p - 1, up), 3: (u0 - p, up + 1), 4: (0, up + 1), 5: (u0 - 1, up)}[f]


def footlock_report():
    """디딤발 세계 좌표 검사: 그림 위치(컷마다 보폭 p만큼 진행) + 발 화면 위치가 디딤 동안 그대로인가. 반환 (줄들, 최대 어긋남)."""
    lines, worst = [], 0
    for mode in ("walk", "run"):
        for view in VIEWS:
            p = stride(mode, view)
            ax, ay = AXIS[view]
            for ph in (0, 3):
                pts = []
                for f in range(6):
                    u, lift = foot(mode, view, f + ph)
                    if lift == 0:
                        pts.append((f * p * ax + u * ax, f * p * ay + u * ay))
                err = max(max(abs(a[0] - pts[0][0]), abs(a[1] - pts[0][1])) for a in pts) if pts else 0
                worst = max(worst, err)
                lines.append(f"{mode} {view} 발{ph // 3}: 디딤 {len(pts)}컷, 어긋남 {err}px")
    return lines, worst


def outfit(look):
    """몸통 계열 → 색·모양 사양. main(4)·acc(2)는 세력 교체 대상."""
    t, fac = look.torso, look.faction
    fm, fa = fac_ramp(fac) if fac else (None, None)
    def R(*ts):
        return ramp(ts)
    o = {"main": R("P43", "P44", "P45", "P46"), "acc": R("P48", "P49"), "pants": None, "boots": R("P02", "P03"),
         "hand": None, "faction": False, "feat": set(), "hem": 0, "legs_skin": False}
    if t == "T01":
        o["feat"] = {"stripe", "collar"}
    elif t == "T02":
        o.update(main=fm or R("P43", "P44", "P45", "P46"), faction=True, hand=R("P02", "P03"),
                 feat={"pads", "chestplate", "badge"})
    elif t == "T03":
        o.update(main=R("P16", "P17", "P18", "P19"), pants=R("P28", "P29", "P30", "P31"), boots=R("P16", "P17"),
                 feat={"scarf", "loose"}, hem=1)
    elif t == "T04":
        o.update(main=R("P16", "P17", "P18", "P19"), pants=R("P16", "P17", "P18", "P19"), feat={"scrap"}, hand=R("P16", "P17"))
    elif t == "T05":
        o.update(main=R("P16", "P17", "P18", "P19"), pants=R("P10", "P11", "P12", "P13"), feat={"leather"})
    elif t == "T06":
        o.update(main=fm or fac_ramp("PF-01")[0], acc=fa or fac_ramp("PF-01")[1], faction=True, hand=R("P01", "P02"),
                 boots=R("P01", "P02"), feat={"armor", "kneepads"})
    elif t == "T07":
        o.update(main=R("P04", "P05", "P06", "P07"), pants=R("P03", "P04", "P05", "P06"), hand=R("P03", "P04"), feat={"metal"})
    elif t == "T08":
        o.update(main=fm or fac_ramp("PF-01")[0], acc=fa or fac_ramp("PF-01")[1], faction=True, hand=R("P01", "P02"),
                 boots=R("P01", "P02"), feat={"coat", "buttons"}, hem=4)
    elif t == "T09":
        o.update(main=R("P28", "P29", "P30", "P31"), feat={"backpack", "antenna"}, faction=fac is not None)
        if fm:
            o["main"] = fm
    elif t == "T10":
        o.update(main=R("P47", "P48", "P49", "P50"), boots=R("P01", "P02"), hand=R("P01", "P02"), feat={"hazmat"})
    elif t == "T11":
        o.update(main=R("P01", "P02", "P03", "P04"), feat={"suit"})
        if fm and fac in ("PF-11", "PF-12"):
            pass
    elif t == "T12":
        o.update(main=R("P58", "P59", "P60", "P60"), pants=R("P43", "P44", "P45", "P46"), feat={"vest"})
    elif t == "T13":
        o.update(main=R("P06", "P07", "P08", "P09"), pants=R("P03", "P04", "P05", "P06"), feat={"gown"}, hem=4)
    elif t == "T14":
        o.update(main=R("P33", "P34", "P35", "P36"), acc=R("P56", "P57"), feat={"robe"}, hem=9)
    elif t == "T15":
        o.update(main=R("P10", "P11", "P12", "P13"), acc=R("P62", "P63"), hand=R("P10", "P11"), boots=R("P10", "P11"), feat={"stealth"})
    elif t == "T16":
        o.update(main=R("P17", "P18", "P04", "P05"), pants=R("P16", "P17", "P03", "P04"), feat={"rags"})
    elif t == "GOWN":
        o.update(main=R("P13", "P14", "P15", "P09"), feat={"gown", "ties"}, hem=3, legs_skin=True)
    if o["pants"] is None:
        o["pants"] = o["main"]
    return o


def _leg(d, hx, hy, fx, fy, col, w=2):
    steps = max(abs(fx - hx), abs(fy - hy), 1)
    for i in range(steps + 1):
        t = i / steps
        x = round(hx + (fx - hx) * t)
        y = round(hy + (fy - hy) * t)
        d.rectangle([x - (w - 1) // 2 - (1 if w == 2 else 0), y, x + (w // 2) - (1 if w == 2 else 0), y], fill=col)


def body(look, view, mode="idle", frame=0):
    """한 컷. 반환 (그림 32×32, 머리 구 중심 (x, y) — 몸 칸 좌표, 발 기준점은 (16, 30))."""
    tw, th, legl, overlap, stoop = BODY.get(look.body, BODY["M1"])
    o = outfit(look)
    sk = skin_ramp(look.skin)
    img = Image.new("RGBA", (32, 32), CLEAR)
    d = ImageDraw.Draw(img)
    moving = mode in ("walk", "run")
    bob = BOB[mode][frame % 6] if moving else 0
    hip_y = 30 - legl + bob
    ax, ay = AXIS[view]
    sx, sy = SIDE[view]
    side_view = view == "E"
    if side_view:
        tw -= 2
    elif view in ("SE", "NE"):
        tw -= 1
    # ---- 다리(먼 발 먼저)
    feet = []
    for k, ph in ((0, 0), (1, 3)):
        if moving:
            u, lift = foot(mode, view, frame + ph)
        else:
            u, lift = 0.0, 0
        spread = (k * 2 - 1) * (1.0 if side_view else 2.0 if view in ("S", "N") else 1.5)
        fx = 16 + ax * u + sx * spread
        fy = 30 + ay * u + sy * spread * (0.5 if view in ("SE", "NE") else 1.0) - lift
        hx = 16 + sx * spread * (0.5 if side_view else 0.8)
        hy = hip_y + (sy * spread * 0.4 if view in ("SE", "NE") else 0)
        near = (sy * spread) > 0 if view in ("E", "SE", "NE") else True
        feet.append((near, k, fx, fy, hx, hy))
    feet.sort(key=lambda f: (f[0], f[3]))
    leg_ramp = sk if o["legs_skin"] else o["pants"]
    for near, k, fx, fy, hx, hy in feet:
        fx, fy = round(fx), round(fy)
        col = leg_ramp[1] if near else leg_ramp[0]
        if "robe" in o["feat"]:
            pass
        else:
            _leg(d, round(hx), round(hy), fx, fy - 1, col)
            if "kneepads" in o["feat"]:
                kx, ky = round((hx + fx) / 2), round((hy + fy) / 2)
                d.point((kx - 1, ky), fill=C("P06") if near else C("P05"))
        bc = (sk[1] if o["legs_skin"] else o["boots"][1]) if near else (sk[0] if o["legs_skin"] else o["boots"][0])
        toe = ax if ax else (1 if view == "E" else 0)
        if view == "E":
            d.rectangle([fx - 1, fy - 1, fx + 1, fy - 1], fill=bc)
        elif view in ("S", "N"):
            d.rectangle([fx - 1, fy - 1, fx, fy - 1], fill=bc)
        else:
            d.rectangle([fx - 1, fy - 1, fx + 1, fy - 1], fill=bc)
    # ---- 뒤에 메는 것(앞모습에서는 몸통 뒤)
    x0 = 16 - tw // 2
    y0 = hip_y - th + 2
    if "backpack" in o["feat"] and view in ("S", "SE"):
        d.rectangle([x0 + 1, y0 - 2, x0 + tw - 2, y0 + 3], fill=ramp(["P17"])[0])
    # ---- 몸통: 둥근 통
    main = o["main"]
    hem = max(0, min(o["hem"], 29 - (y0 + th)))                              # 자락은 발목 위까지(발은 보인다)
    for y in range(th + hem):
        for x in range(-1 if "loose" in o["feat"] else 0, tw + (1 if "loose" in o["feat"] else 0)):
            nx = (x + 0.5 - tw / 2) / (tw / 2)
            ny = (y + 0.5 - th / 2) / (th / 2)
            if y < th:
                if nx * nx * 0.9 + max(0.0, ny) ** 4 + max(0.0, -ny) ** 2 * 0.6 > 1.0:
                    continue
            else:                                                             # 자락(외투·가운·로브): 아래로 퍼진다
                flare = (y - th + 1) * (0.5 if "robe" in o["feat"] else 0.15)
                if abs(x + 0.5 - tw / 2) > tw / 2 - 1 + flare:
                    continue
            nz = math.sqrt(max(0.0, 1 - min(1.0, nx * nx)))
            dd = nx * L[0] + max(-1, min(1, ny)) * 0.5 * L[1] + nz * L[2]
            img.putpixel((x0 + x, y0 + y), shade(main, dd))
    _features(img, d, look, o, view, x0, y0, tw, th, hip_y, frame if moving else -1)
    # ---- 팔·손: 몸통 옆(걸으면 흔든다)
    sw = 0 if not moving else [1, 1, 0, -1, -1, 0][frame % 6]
    hand = o["hand"][1] if o["hand"] else sk[3]
    sleeve = main[1]
    arm_y = y0 + 3
    if "rags" in o["feat"]:
        sleeve = sk[2]
    if view == "E":
        d.rectangle([16 + sw * 2 - 1, arm_y, 16 + sw * 2, arm_y + 3], fill=sleeve)
        d.rectangle([16 + sw * 2 - 1, arm_y + 4, 16 + sw * 2, arm_y + 5], fill=hand)
    else:
        for side, s_ in ((-1, sw), (1, -sw)):
            xa = x0 - 1 if side < 0 else x0 + tw
            if view in ("SE", "NE") and side < 0 and view == "NE":
                continue
            d.rectangle([xa, arm_y + s_, xa + (0 if side < 0 else 0), arm_y + 3 + s_], fill=sleeve)
            d.rectangle([xa, arm_y + 4 + s_, xa, arm_y + 5 + s_], fill=hand)
    if "backpack" in o["feat"] and view in ("N", "NE", "E"):
        bx = x0 + 1 if view == "N" else (x0 - 2 if view == "E" else x0)
        d.rectangle([bx, y0 - 1, bx + (tw - 3 if view == "N" else 4), y0 + th - 2], fill=C("P18"), outline=C("P17"))
    if "antenna" in o["feat"]:
        axx = x0 + tw - 3 if view != "E" else x0 + 1
        d.line([axx, y0 - 1, axx, y0 - 8], fill=C("P02"))
        d.point((axx, y0 - 9), fill=C("P54"))
    img = outline(img, thick_bottom=False)
    neck_y = y0 + overlap                                                     # 머리 아랫변이 몸통 위 overlap px를 덮는다
    hx = 16 + (stoop if view in ("E", "SE", "NE") else 0)
    ry = HEAD_SIZE.get(look.body, (22, 20))[1] / 2 - 0.3
    return img, (hx, int(round(neck_y + stoop - ry)))                       # 머리 구 중심(칸 좌표)


def _features(img, d, look, o, view, x0, y0, tw, th, hip_y, frame):
    f = o["feat"]
    main, acc = o["main"], o["acc"]
    cx = 16
    front = view in ("S", "SE")
    back = view in ("N", "NE")
    if "stripe" in f:
        if view == "S":
            d.line([cx, y0 + 1, cx, y0 + th - 2], fill=acc[1]); d.line([cx - 1, y0 + 1, cx - 1, y0 + th - 2], fill=acc[0])
        elif view == "SE":
            d.line([cx + 2, y0 + 1, cx + 2, y0 + th - 2], fill=acc[1])
        elif view == "E":
            d.line([x0 + tw - 3, y0 + 1, x0 + tw - 3, y0 + th - 2], fill=acc[0])
        else:
            d.rectangle([cx - 2, y0 + 3, cx + 1, y0 + 5], fill=acc[0])            # 등 번호판
            d.point((cx - 1, y0 + 4), fill=main[0]); d.point((cx + 1, y0 + 4), fill=main[0])
    if "pads" in f:
        for side in (-1, 1):
            if view == "E" and side < 0:
                continue
            px = x0 - 1 if side < 0 else x0 + tw - 3
            d.rectangle([px, y0, px + 3, y0 + 2], fill=C("P07"))
            d.line([px, y0 + 2, px + 3, y0 + 2], fill=C("P05"))
    if "chestplate" in f and front:
        d.rectangle([cx - 3, y0 + 2, cx + 2, y0 + 5], fill=C("P06"))
        d.line([cx - 3, y0 + 2, cx + 2, y0 + 2], fill=C("P08"))
    if "badge" in f and front:
        d.point((cx + 1, y0 + 3), fill=C("P49"))
    if "scarf" in f:
        sc = ramp(["P24", "P25", "P26", "P27"])
        d.rectangle([x0 + 1, y0, x0 + tw - 2, y0 + 1], fill=sc[2])
        d.line([x0 + 1, y0 + 1, x0 + tw - 2, y0 + 1], fill=sc[1])
        tail = x0 + 2 if view in ("S", "SE", "E") else x0 + tw - 4
        d.rectangle([tail, y0 + 2, tail + 1, y0 + 4], fill=sc[1])
    if "scrap" in f:
        rust = ramp(["P24", "P25", "P26", "P27"])
        side = 1 if view != "E" else 1
        px = x0 + tw - 4
        d.rectangle([px, y0 - 2, px + 5, y0 + 2], fill=rust[2])                 # 비대칭 어깨판
        d.line([px, y0 + 2, px + 5, y0 + 2], fill=rust[0])
        d.point((px + 1, y0 - 3), fill=C("P07")); d.point((px + 4, y0 - 3), fill=C("P07"))
        if front:
            d.rectangle([cx - 3, y0 + 3, cx, y0 + 5], fill=C("P02"))              # 타이어 조각
    if "leather" in f:
        if front:
            d.rectangle([cx - 4, y0 + 2, cx + 3, y0 + 6], fill=main[0])
            d.line([cx - 4, y0 + 2, cx + 3, y0 + 2], fill=main[2])
        d.rectangle([x0 + tw - 4, y0, x0 + tw - 1, y0 + 2], fill=main[3])
    if "armor" in f:
        if front:
            d.polygon([(cx - 4, y0 + 2), (cx + 3, y0 + 2), (cx + 2, y0 + 6), (cx - 3, y0 + 6)], fill=main[2])
            d.line([cx - 4, y0 + 2, cx + 3, y0 + 2], fill=main[3])
            d.point((cx - 1, y0 + 4), fill=acc[1])
        d.line([x0 + 1, hip_y - 1, x0 + tw - 2, hip_y - 1], fill=C("P17"))         # 탄띠
        d.point((x0 + 3, hip_y - 2), fill=C("P18")); d.point((x0 + tw - 4, hip_y - 2), fill=C("P18"))
    if "metal" in f:
        for side in (-1, 1):
            px = x0 - 2 if side < 0 else x0 + tw - 3
            if view == "E" and side < 0:
                continue
            d.ellipse([px, y0 - 1, px + 4, y0 + 3], fill=C("P07"), outline=C("P05"))
        if front:
            d.line([cx - 3, y0 + 4, cx + 2, y0 + 4], fill=C("P04"))
    if "coat" in f:
        if front:
            d.polygon([(cx - 1, y0), (cx - 4, y0), (cx - 1, y0 + 4)], fill=main[3])     # 넓은 깃
            d.polygon([(cx, y0), (cx + 3, y0), (cx, y0 + 4)], fill=main[3])
            d.line([cx - 1, y0 + 4, cx - 1, y0 + th + 3], fill=main[0])
        if "buttons" in f and front:
            for yy in (y0 + 5, y0 + 7, y0 + 9):
                d.point((cx, yy), fill=acc[1])
    if "hazmat" in f:
        d.line([x0 + 1, y0 + th // 2, x0 + tw - 2, y0 + th // 2], fill=main[0])
        if back:
            d.rectangle([cx - 3, y0 + 1, cx + 2, y0 + th - 2], fill=C("P06"), outline=C("P04"))   # 산소통
    if "suit" in f and front:
        d.polygon([(cx - 2, y0), (cx + 1, y0), (cx - 1 if view == "S" else cx, y0 + 4)], fill=C("P09"))
        d.line([cx - 1 if view == "S" else cx, y0 + 1, cx - 1 if view == "S" else cx, y0 + 5], fill=C("P53"))
    if "vest" in f:
        if front:
            d.line([cx - 1, y0, cx - 1, y0 + th - 2], fill=C("P05"))
            d.rectangle([x0 + 2, y0 + 4, x0 + 4, y0 + 6], fill=main[0])
            d.rectangle([x0 + tw - 5, y0 + 4, x0 + tw - 3, y0 + 6], fill=main[0])
        d.rectangle([x0, y0, x0, y0 + 3], fill=C("P05")); d.rectangle([x0 + tw - 1, y0, x0 + tw - 1, y0 + 3], fill=C("P05"))
    if "gown" in f and front and "ties" not in f:
        d.line([cx - 1, y0, cx - 1, y0 + th + 2], fill=main[1])
        d.point((cx - 3, y0 + 3), fill=C("P03"))                                # 청진기 끝
    if "ties" in f:
        if back:
            for yy in (y0 + 2, y0 + 6):
                d.point((cx - 1, yy), fill=C("P07")); d.point((cx, yy), fill=C("P07"))
            d.line([cx - 1, y0, cx - 1, y0 + th + 2], fill=main[0])
        elif front:
            d.line([x0 + 2, y0 + 1, x0 + tw - 3, y0 + 1], fill=main[0])
    if "robe" in f:
        d.line([cx - 1, y0 + 1, cx - 1, y0 + th + 7], fill=main[0])
        d.rectangle([x0 + 1, y0 + th - 1, x0 + tw - 2, y0 + th - 1], fill=acc[0])
        if front:
            d.point((cx - 1, y0 + 3), fill=acc[1])
    if "stealth" in f:
        d.line([x0 + 2, y0 + 2, x0 + 2, y0 + th - 2], fill=acc[0])
        d.line([x0 + tw - 3, y0 + 2, x0 + tw - 3, y0 + th - 2], fill=acc[0])
    if "rags" in f:
        for x in range(x0, x0 + tw, 3):
            img.putpixel((x, y0 + th - 1), (0, 0, 0, 0))                       # 찢어진 끝단
        d.point((x0 + 3, y0 + 4), fill=C("P04")); d.point((x0 + tw - 4, y0 + 6), fill=C("P19"))
    if "collar" in f and front:
        d.line([cx - 2, y0, cx + 1, y0], fill=acc[1])
    # 낡음
    w = look.worn
    if w >= 1:
        rnd = random.Random(hash((look.torso, w, view)) & 0xFFFF)
        for _ in range(2 * w):
            x, y = rnd.randint(x0 + 1, x0 + tw - 2), rnd.randint(y0 + 2, y0 + th - 2)
            if img.getpixel((x, y))[3]:
                img.putpixel((x, y), P.step(img.getpixel((x, y))[:3], -1) + (255,))
    if w >= 2:
        img.putpixel((x0 + 2, y0 + th - 2), C("P17"))
        img.putpixel((x0 + tw - 3, y0 + th - 3), C("P01"))


# ================================================================ 대화 초상화 96×96(SD-12 §6.1): 같은 머리를 4배로 + 어깨
PORTRAIT_EXPR = {"기본": "idle", "미소": "smile", "놀람": "surprise", "분노": "angry", "슬픔": "sad", "피곤": "tired",
                 "말함": "talk", "아픔": "hurt"}


def portrait(look, expr="기본", bg=None):
    face = PORTRAIT_EXPR.get(expr, expr)
    img = Image.new("RGBA", (96, 96), bg or CLEAR)
    o = outfit(look)
    sh = Image.new("RGBA", (96, 96), CLEAR)                                    # 어깨(몸통 윗부분)
    d = ImageDraw.Draw(sh)
    main = o["main"]
    for y in range(66, 96):
        for x in range(6, 90):
            nx, ny = (x + 0.5 - 48) / 42, (y + 0.5 - 100) / 32
            if nx * nx + ny * ny <= 1:
                nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
                sh.putpixel((x, y), shade(main, nx * L[0] + ny * L[1] + nz * L[2]))
    if "stripe" in o["feat"]:
        d.rectangle([46, 70, 49, 95], fill=o["acc"][1])
    if "coat" in o["feat"] or "suit" in o["feat"]:
        d.polygon([(40, 72), (48, 88), (56, 72)], fill=C("P09") if "suit" in o["feat"] else main[3])
    if "gown" in o["feat"]:
        d.line([48, 72, 48, 95], fill=main[1])
    sh = outline(sh, thick_bottom=False)
    sh = outline(sh, thick_bottom=False)
    img.alpha_composite(sh)
    k = 3.0
    h = head(look, "S", face, k)
    img.alpha_composite(h, (48 - int(HC * k), 11 - int((22 - 9.7) * k)))
    return img


# 손 무기(머리·조준 방향을 따른다). 손 위치는 발 기준점 기준.
GUN_AT = {"E": (7, -9), "SE": (7, -6), "S": (6, -4), "NE": (6, -13), "N": (4, -15)}
# 몸마다 손 위치 보정(dx, dy): 아이(K1)는 몸통이 4px 낮고 2px 좁다
GUN_BODY = {"K1": (-1, 3)}


def gun(view, kind="pistol", hand=None):
    hand = hand or C("P41")
    img = Image.new("RGBA", (20, 16), CLEAR)
    metal = [C("P02"), C("P03"), C("P04"), C("P06")]
    wood = [C("P17"), C("P18")]
    n = {"pistol": 7, "rifle": 13, "smg": 9, "baton": 10, "bb": 11, "pole": 15}[kind]
    if view in ("E", "SE", "NE"):
        t = Image.new("RGBA", (20, 16), CLEAR)
        g = ImageDraw.Draw(t)
        x0 = 10 - n // 2
        if kind == "pole":                                   # 대걸레 자루: 밝은 나무 막대, 끝에 쇠 물림
            g.line([x0, 8, x0 + n - 1, 8], fill=wood[1])
            g.line([x0 + 2, 7, x0 + n - 2, 7], fill=C("P19"))
            g.rectangle([x0 + n - 2, 7, x0 + n - 1, 8], fill=metal[3])
        elif kind == "bb":                                   # BB총: 짧은 공기총, 나무 개머리·가는 총열·펌프
            g.rectangle([x0 - 2, 8, x0 + 2, 9], fill=wood[1])
            g.line([x0 - 2, 10, x0, 10], fill=wood[0])
            g.rectangle([x0 + 3, 7, x0 + n - 1, 7], fill=metal[2])
            g.line([x0 + 3, 8, x0 + 8, 8], fill=metal[1])
            g.point((x0 + n - 1, 6), fill=metal[3])
            g.rectangle([x0 + 5, 9, x0 + 6, 9], fill=wood[0])
        elif kind == "baton":
            g.rectangle([x0, 7, x0 + n - 1, 8], fill=C("P02"))
            g.line([x0, 7, x0 + n - 1, 7], fill=C("P04"))
        else:
            g.rectangle([x0, 7, x0 + n - 1, 8], fill=metal[2])
            g.line([x0, 7, x0 + n - 1, 7], fill=metal[3])
            g.rectangle([x0 + 1, 9, x0 + 2, 10], fill=metal[1] if kind == "pistol" else wood[1])
            if kind in ("rifle", "smg"):
                g.rectangle([x0 - 2, 8, x0, 9], fill=wood[1] if kind == "rifle" else metal[1])
                g.rectangle([x0 + 6, 9, x0 + 6, 10], fill=metal[1])
        g.rectangle([x0 + 1, 9, x0 + 2, 9], fill=hand)
        if view != "E":
            t = t.rotate(-35 if view == "SE" else 35, resample=Image.NEAREST, center=(10, 8))
        img = t
    elif view == "S":
        g = ImageDraw.Draw(img)
        if kind == "pole":
            g.rectangle([9, 0, 9, 13], fill=wood[1])
            g.point((9, 0), fill=metal[3])
        elif kind == "bb":
            g.rectangle([9, 3, 10, 9], fill=metal[2])
            g.point((9, 3), fill=metal[3])
            g.rectangle([8, 8, 11, 10], fill=wood[1])
        elif kind == "baton":
            g.rectangle([9, 2, 10, 10], fill=C("P02"))
        else:
            g.rectangle([8, 6, 11, 9 if kind == "pistol" else 10], fill=metal[2])
            g.point((9, 7), fill=C("P00")); g.point((10, 7), fill=C("P00"))
        g.rectangle([8, 10 if kind == "pistol" else 11, 11, 11 if kind == "pistol" else 12], fill=hand)
    else:
        g = ImageDraw.Draw(img)
        g.rectangle([9, 3, 10, 3 + n // 2], fill=wood[1] if kind in ("pole",) else metal[2] if kind != "baton" else C("P02"))
        g.rectangle([9, 4 + n // 2, 10, 5 + n // 2], fill=hand)
    return outline(img, thick_bottom=False)


GUN_KINDS = ("pistol", "rifle", "smg", "bb")                 # 총구가 있는 무기(탄·총구 화염이 나간다)


def gun_muzzle(view, kind):
    """총구 점: gun() 칸(20×16) 안 연속 좌표(화소 중심 = +0.5). 총열 끝 화소에서 총열 축으로 1px 바깥(먹선 자리).
    SE·NE는 gun()과 같이 동쪽 그림을 (10, 8) 둘레로 ±35° 돌린 자리(PIL rotate와 0.3px 안으로 맞는다).
    S는 총구가 화면 쪽이라 총구 구멍(권총·소총) 또는 총열 아래 끝(BB총), N은 총열 위 끝 바로 위.
    게임은 탄 출발점과 총구 화염을 여기에 찍는다(SD-16 §5 'muzzle' = 손 기준점 + 무기 그림의 총구 오프셋)."""
    n = {"pistol": 7, "rifle": 13, "smg": 9, "bb": 11}[kind]
    x0 = 10 - n // 2
    if view in ("E", "SE", "NE"):
        mx, my = x0 + n + 0.5, 7.5 if kind == "bb" else 8.0
        if view == "E":
            return (mx, my)
        a = math.radians(35 if view == "SE" else -35)
        vx, vy = mx - 10, my - 8
        return (round(10 + vx * math.cos(a) - vy * math.sin(a), 2), round(8 + vx * math.sin(a) + vy * math.cos(a), 2))
    if view == "S":
        return (10.0, 9.5) if kind == "bb" else (10.0, 7.5)
    return (10.0, 2.5)


def roll_body(look, frame):
    """구르기 5컷용 몸: 웅크린 공(0·4 = 웅크림, 1~3 = 공). 머리는 실행 중에 90도씩 돌려 얹는다."""
    o = outfit(look)
    img = Image.new("RGBA", (32, 32), CLEAR)
    d = ImageDraw.Draw(img)
    r = 8 if frame in (1, 2, 3) else 9
    cy = 30 - r
    for y in range(32):
        for x in range(32):
            nx, ny = (x + 0.5 - 16) / r, (y + 0.5 - cy) / (r - 1)
            if nx * nx + ny * ny <= 1:
                nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
                img.putpixel((x, y), shade(o["main"], nx * L[0] + ny * L[1] + nz * L[2]))
    k = frame % 4
    bx, by = [(8, cy + 5), (16, cy + 7), (23, cy + 3), (16, cy - 6)][k]                  # 무릎·장화가 공 둘레를 돈다
    d.rectangle([bx - 1, by - 1, bx + 1, by], fill=o["boots"][1])
    return outline(img, thick_bottom=False), (16, cy - 1)


def actor(look, view, mode="idle", frame=0, face="idle", aim=None, weapon=None):
    """한 컷 합성(굽기·샘플용). 칸 40×48, 발 기준점 (20, 44). view/aim에 W·SW·NW를 주면 반전."""
    mir = {"W": "E", "SW": "SE", "NW": "NE"}
    bv = mir.get(view, view)
    a = aim or view
    av = mir.get(a, a)
    b, (hx, hy) = body(look, bv, mode, frame)
    h = head(look, av, face)
    flip_b, flip_a = view in mir, a in mir
    if flip_b:
        b = b.transpose(Image.FLIP_LEFT_RIGHT)
        hx = 32 - hx
    if flip_a:
        h = h.transpose(Image.FLIP_LEFT_RIGHT)
    img = Image.new("RGBA", (40, 48), CLEAR)
    ox, oy = 4, 14
    g = None
    if weapon:
        o = outfit(look)
        g = gun(av, weapon, (o["hand"] or skin_ramp(look.skin))[3 if not o["hand"] else 1])
        if flip_a:
            g = g.transpose(Image.FLIP_LEFT_RIGHT)
        gx, gy = GUN_AT[av]
        bdx, bdy = GUN_BODY.get(look.body, (0, 0))
        gx, gy = gx + bdx, gy + bdy
        gpos = (ox + 16 + (-gx if flip_a else gx) - 10, oy + 30 + gy - 8)
        if av in ("N", "NE"):
            img.alpha_composite(g, gpos)
    img.alpha_composite(b, (ox, oy))
    img.alpha_composite(h, (ox + hx - HC, oy + hy - 22))
    if g is not None and av not in ("N", "NE"):
        img.alpha_composite(g, gpos)
    return img


def head_preview(path, looks, faces=("idle",)):
    cell = 40
    sheet = Image.new("RGBA", (cell * 5 * len(faces), cell * len(looks)), C("P19"))
    for r, lk in enumerate(looks):
        for fi, face in enumerate(faces):
            for c, v in enumerate(VIEWS):
                sheet.alpha_composite(head(lk, v, face), ((fi * 5 + c) * cell, r * cell))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(path)


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "portraits":
    out = sys.argv[2]
    looks = [Look.parse(c) for c in ("F1-S2-HR06-H1-GOWN-0-PF11-HD00-EY00", "F1-S2-HR07-H1-T13-1-PF11-HD00-EY00",
                                     "F2-S2-HR08-H2-T11-1-PF11-HD00-EY02", "M1-S4-HR02-H1-T06-1-PF01-HD04-EY00",
                                     "E1-S2-HR00-H5-T11-2-PF11-HD00-EY03", "K1-S3-HR07-H2-T01-1-PF11-HD00-EY00")]
    exprs = ("기본", "미소", "놀람", "분노", "슬픔", "피곤")
    sheet = Image.new("RGBA", (98 * len(exprs), 98 * len(looks)), C("P44"))
    for r, lk in enumerate(looks):
        for c, e in enumerate(exprs):
            sheet.alpha_composite(portrait(lk, e), (c * 98 + 1, r * 98 + 1))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out + "_portraits.png")

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "bodies":
    out = sys.argv[2]
    fams = ["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08", "T09", "T10", "T11", "T12", "T13", "T14", "T15", "T16", "GOWN"]
    sheet = Image.new("RGBA", (40 * 9, 48 * len(fams)), C("P19"))
    for r, t in enumerate(fams):
        lk = Look(torso=t, faction="PF-01" if t in ("T02", "T06", "T08") else None,
                  gear={"T06": "HD04", "T08": "HD15", "T02": "HD03"}.get(t))
        for c, (v, m, f) in enumerate((("S", "idle", 0), ("SE", "idle", 0), ("E", "idle", 0), ("NE", "idle", 0), ("N", "idle", 0),
                                       ("E", "walk", 1), ("E", "run", 2), ("S", "walk", 4), ("SE", "run", 1))):
            sheet.alpha_composite(actor(lk, v, m, f), (c * 40, r * 48))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out + "_bodies.png")
    sheet = Image.new("RGBA", (40 * 7, 48 * 7), C("P19"))
    for r, b in enumerate(("M1", "M2", "F1", "F2", "E1", "E2", "K1")):
        lk = Look(body=b, hair={"F1": "HR06", "F2": "HR05", "E2": "HR07", "K1": "HR09"}.get(b, "HR03"),
                  color={"E1": "H5", "E2": "H5"}.get(b, "H1"), torso="T03")
        for c, (v, m, f) in enumerate((("S", "idle", 0), ("SE", "walk", 0), ("E", "walk", 2), ("NE", "run", 1), ("N", "walk", 3),
                                       ("E", "idle", 0), ("W", "run", 4))):
            sheet.alpha_composite(actor(lk, v, m, f), (c * 40, r * 48))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out + "_types.png")

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "heads":
    out = sys.argv[2]
    looks = [Look(hair=h) for h in ("HR00", "HR01", "HR02", "HR03", "HR04", "HR05", "HR06", "HR07", "HR08", "HR09", "HR10", "HR11")]
    head_preview(out + "_hair.png", looks)
    looks = [Look(gear=g, faction="PF-01") for g in ("HD01", "HD02", "HD03", "HD04", "HD05", "HD06", "HD07", "HD08", "HD09",
                                                     "HD10", "HD11", "HD12", "HD13", "HD14", "HD15", "HD16", "HD17", "HD18")]
    head_preview(out + "_gear.png", looks)
    looks = [Look(eyes=e) for e in ("EY01", "EY02", "EY03", "EY04", "EY05", "EY06", "EY07", "EY08")] + \
            [Look(body=b, skin=s, hair=h, color=c) for b, s, h, c in (("F1", "S1", "HR06", "H2"), ("E1", "S2", "HR00", "H5"),
                                                                     ("E2", "S2", "HR08", "H5"), ("K1", "S3", "HR07", "H2"),
                                                                     ("M2", "S5", "HR01", "H1"), ("M1", "SG1", "HR10", "H6"))]
    head_preview(out + "_eyes.png", looks, FACES)
