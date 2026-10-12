"""Pip-Boy 3000 screens (SD-12 §3.4 layout, SD-16 §4.6 U palette, §9.2 CRT rules).
Outputs samples/07_pipboy_stat.png and 07_pipboy_faction.png (+x2)."""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageChops
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import upscale

ROOT = os.path.dirname(os.path.dirname(__file__))
C = P.rgb
U = lambda i: C(f"U{i}")
F12 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri11.ttf"), 12)
F10 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
F12B = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri11-Bold.ttf"), 12)


def bezel():
    """Device frame: worn olive-grey metal, rivets, rad gauge, knobs, name plate, fingerprint smudge."""
    im = Image.new("RGB", (640, 360), C("P04"))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 639, 359], fill=C("P29"))
    d.rectangle([4, 4, 635, 355], fill=C("P30"))
    for y in range(6, 356, 6):  # brushed bands
        d.line([6, y, 633, y], fill=C("P29"))
    d.rectangle([30, 18, 609, 341], fill=C("P02"))      # screen recess
    d.rectangle([32, 20, 607, 339], fill=C("P01"))
    for x, y in [(12, 12), (627, 12), (12, 347), (627, 347), (320, 8), (320, 351)]:  # rivets
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=C("P05")); d.point((x - 1, y - 1), fill=C("P07"))
    # rad gauge (top-left corner plate)
    d.rectangle([2, 2, 50, 34], fill=C("P02")); d.rectangle([4, 4, 48, 32], fill=C("P08"))
    d.arc([8, 10, 44, 46], 200, 340, fill=C("P02"))
    for k in range(5):
        import math
        a = math.radians(200 + k * 35)
        d.line([26 + 15 * math.cos(a), 28 + 15 * math.sin(a), 26 + 18 * math.cos(a), 28 + 18 * math.sin(a)], fill=C("P53") if k == 4 else C("P02"))
    d.line([26, 28, 15, 17], fill=C("P53"))
    # knobs on the right margin
    for y in (60, 120):
        d.ellipse([612, y, 636, y + 24], fill=C("P01")); d.ellipse([613, y + 1, 635, y + 23], fill=C("P05"))
        d.ellipse([616, y + 4, 632, y + 20], fill=C("P06")); d.line([624, y + 4, 624, y + 11], fill=C("P02"))
    d.rectangle([614, 180, 634, 220], fill=C("P01")); d.rectangle([616, 182, 632, 218], fill=C("P53"))  # power button
    d.line([616, 182, 632, 182], fill=C("P54"))
    # name plate (bottom-right, may carry glyphs)
    d.rectangle([470, 342, 606, 357], fill=C("P01")); d.rectangle([471, 343, 605, 356], fill=C("P48"))
    dd = ImageDraw.Draw(im); dd.fontmode = "1"
    dd.text((476, 344), "PIP-BOY 3000 · S-07", font=F10, fill=C("P01"))
    return im


def crt(screen):
    """Scanlines (even rows ×0.85) + rounded vignette + fingerprint smudge (SD-16 §9.2)."""
    w, h = screen.size
    px = screen.load()
    for y in range(0, h, 2):
        for x in range(w):
            r, g, b = px[x, y]
            px[x, y] = (r * 85 // 100, g * 85 // 100, b * 85 // 100)
    vig = Image.new("L", (w, h), 0)
    vd = ImageDraw.Draw(vig)
    vd.rounded_rectangle([0, 0, w - 1, h - 1], radius=26, fill=255)
    black = Image.new("RGB", (w, h), U(0))
    screen = Image.composite(screen, black, vig)
    sm = screen.load()  # smudge: a few dimmed arcs bottom-right
    for k, (cx, cy) in enumerate([(w - 70, h - 50), (w - 64, h - 44)]):
        for x in range(cx - 10, cx + 10, 3):
            y = cy + (x - cx) ** 2 // 30
            if 0 <= x < w and 0 <= y < h:
                r, g, b = sm[x, y]
                sm[x, y] = (r * 7 // 10, g * 7 // 10, b * 7 // 10)
    return screen


class Screen:
    """Draws inside the 560x304 CRT area; coordinates given in 640x360 canvas space."""
    X0, Y0, W, H = 40, 28, 560, 304

    def __init__(self):
        self.im = Image.new("RGB", (self.W, self.H), U(1))
        self.d = ImageDraw.Draw(self.im)
        self.d.fontmode = "1"

    def t(self, x, y, s, f=F12, col=5):
        self.d.text((x - self.X0, y - self.Y0), s, font=f, fill=U(col))

    def line(self, x0, y0, x1, y1, col=3):
        self.d.line([x0 - self.X0, y0 - self.Y0, x1 - self.X0, y1 - self.Y0], fill=U(col))

    def rect(self, x0, y0, x1, y1, col=5, fill=None):
        self.d.rectangle([x0 - self.X0, y0 - self.Y0, x1 - self.X0, y1 - self.Y0], outline=U(col) if col is not None else None, fill=U(fill) if fill is not None else None)

    def tabs(self, active, sub, sub_active):
        x = 56
        for i, name in enumerate(["능력치", "아이템", "데이터"]):
            w = 64
            if i == active:
                self.rect(x - 4, 32, x + w - 8, 47, None, fill=7)
                self.t(x, 33, name, F12B, 0)
            else:
                self.t(x, 33, name, F12, 4)
            x += w + 8
        self.t(470, 33, "2277. 10. 25.  14:32", F10, 4)
        self.t(48, 51, "레벨 7  |  HP 145/160  |  AP 72/80  |  XP 1,240/1,450", F10, 5)
        self.line(48, 66, 591, 66, 3)
        # sub tabs
        w = 544 // len(sub)
        for i, s in enumerate(sub):
            x = 48 + i * w
            if i == sub_active:
                self.rect(x + 2, 296, x + w - 3, 311, 6)
                self.t(x + w // 2 - len(s) * 6 // 1 // 2 * 1, 298, s, F12, 6)
            else:
                self.t(x + w // 2 - len(s) * 6 // 2, 298, s, F12, 3)
        self.line(48, 313, 591, 313, 2)

    def hint(self, s):
        self.t(48, 316, s, F10, 4)

    def list(self, items, sel):
        for i, s in enumerate(items):
            y = 74 + i * 15
            if i == sel:
                self.rect(48, y - 1, 246, y + 12, None, fill=6)
                self.t(52, y, s, F12, 0)
            else:
                self.t(52, y, s, F12, 5)

    def finish(self, bez, amber_lamp=True):
        scr = self.im
        if amber_lamp:  # 관제망 램프: the one amber exception (SD-12 §3.8)
            d = ImageDraw.Draw(scr)
            d.fontmode = "1"
            d.text((520 - self.X0, 51 - self.Y0), "관제망", font=F10, fill=U(4))
            d.ellipse([566 - self.X0, 53 - self.Y0, 573 - self.X0, 60 - self.Y0], fill=C("P59"))
            d.point((568 - self.X0, 55 - self.Y0), fill=C("P60"))
        scr = crt(scr)
        out = bez.copy()
        out.paste(scr, (self.X0, self.Y0))
        return out


def resident_figure(s, x, y, damaged=("leg_l",)):
    """Original S-07 resident pictogram (not Vault Boy): line art, 1px U6, limb segments separately dimmable."""
    d = s.d
    ox, oy = x - s.X0, y - s.Y0
    def L(a, b, c, e, part=None):
        col = U(3) if part in damaged else U(6)
        d.line([ox + a, oy + b, ox + c, oy + e], fill=col)
    def E(a, b, c, e):
        d.ellipse([ox + a, oy + b, ox + c, oy + e], outline=U(6))
    # head + hair parting + face
    E(36, 4, 60, 28)
    d.arc([ox + 36, oy + 4, ox + 60, oy + 22], 190, 350, fill=U(6))
    L(40, 9, 46, 6); L(46, 6, 56, 8)
    d.point([(ox + 43, oy + 16), (ox + 53, oy + 16)], fill=U(6))
    d.arc([ox + 43, oy + 17, ox + 53, oy + 25], 20, 160, fill=U(6))
    # torso (jumpsuit with centre stripe)
    L(40, 30, 56, 30); L(37, 33, 40, 30); L(59, 33, 56, 30)
    L(37, 33, 38, 58); L(59, 33, 58, 58); L(38, 58, 58, 58)
    L(48, 30, 48, 56)
    L(46, 30, 46, 56); L(50, 30, 50, 56)
    # arms (one raised in a wave)
    L(37, 34, 30, 48, "arm_r"); L(30, 48, 31, 58, "arm_r"); E(29, 57, 33, 61)
    L(59, 34, 68, 26, "arm_l"); L(68, 26, 72, 14, "arm_l"); E(70, 9, 75, 14)
    # legs
    L(41, 58, 40, 84, "leg_r"); L(46, 58, 45, 84, "leg_r"); L(38, 84, 46, 88, "leg_r")
    L(50, 58, 52, 84, "leg_l"); L(55, 58, 57, 84, "leg_l"); L(51, 84, 61, 88, "leg_l")
    if "leg_l" in damaged:  # splint marks
        for yy in (66, 72):
            L(49, yy, 58, yy - 2)


def limb_bar(s, x, y, frac, label, low=False):
    s.t(x, y, label, F10, 4 if not low else 6)
    s.rect(x, y + 12, x + 50, y + 16, 3)
    s.rect(x + 1, y + 13, x + 1 + int(48 * frac), y + 15, None, fill=6 if not low else 3)


def stat_screen():
    s = Screen()
    s.tabs(0, ["상태", "S.P.E.C.I.A.L.", "스킬", "퍽", "세력", "일반"], 0)
    s.list(["신체", "방사능", "효과"], 0)
    s.line(250, 70, 250, 290, 2)
    resident_figure(s, 376, 96)
    limb_bar(s, 404, 78, 1.0, "머리")
    limb_bar(s, 300, 112, 0.9, "오른팔")
    limb_bar(s, 486, 112, 1.0, "왼팔")
    limb_bar(s, 300, 160, 0.95, "몸통")
    limb_bar(s, 300, 200, 0.7, "오른다리")
    limb_bar(s, 486, 200, 0.15, "왼다리 손상", low=True)
    s.t(264, 236, "스팀팩 (4)  사용하면 손상 부위부터 회복한다", F12, 5)
    s.t(264, 254, "의사 진료: 봉천 계단마을 보건소 (40캡)", F10, 4)
    s.t(264, 270, "왼다리 손상: 이동 속도 -15%, 질주 불가", F10, 6)
    s.hint("[Tab] 닫기   [Q·E] 하위 탭   [Enter] 스팀팩 사용   [R] 라드어웨이")
    return s.finish(bezel())


def faction_screen():
    s = Screen()
    s.tabs(0, ["상태", "S.P.E.C.I.A.L.", "스킬", "퍽", "세력", "일반"], 4)
    s.list(["정착지 연합", "  봉천 계단마을", "  탱크마을", "지하시장", "연합단", "비상정부", "새벽인력", "(소문으로만 아는 세력 4)"], 1)
    s.line(250, 70, 250, 290, 2)
    # emblem: stepped-roof village mark (original), state drawn as picture, not a number
    d = s.d
    ex, ey = 270 - s.X0, 80 - s.Y0
    d.rectangle([ex, ey, ex + 40, ey + 40], outline=U(6))
    d.line([ex + 6, ey + 30, ex + 14, ey + 30, ex + 14, ey + 22, ex + 22, ey + 22, ex + 22, ey + 14, ex + 30, ey + 14, ex + 30, ey + 8, ex + 34, ey + 8], fill=U(6))
    d.rectangle([ex + 4, ey + 32, ex + 36, ey + 35], fill=U(5))
    s.t(322, 78, "봉천 계단마을", F12B, 6)
    s.t(322, 94, "관악산 아래 계단 골목 정착지. 이장 조만석.", F10, 4)
    s.t(264, 128, "\"볼트에서 내려온 이 사람, 이제 우리 동네 사람이지.\"", F12, 6)
    s.t(264, 148, "아이들이 이름을 부르며 따라온다. 이장이 상점 셔터를", F12, 5)
    s.t(264, 164, "먼저 올려 준다. 정수 배급 줄에 끼워 주기 시작했다.", F12, 5)
    s.line(264, 186, 588, 186, 2)
    s.t(264, 192, "최근 일", F10, 4)
    s.t(264, 206, "· 들개 바위굴을 정리해 텃밭 길이 다시 열렸다", F10, 5)
    s.t(264, 220, "· 새벽인력 추적자를 마을 밖으로 따돌렸다", F10, 5)
    s.t(264, 234, "· 배수지 펌프를 고쳤다 (물값이 내려갔다)", F10, 5)
    s.t(264, 256, "지원 요청: 자경대 확성기를 갖고 있지 않다", F10, 3)
    s.hint("[Tab] 닫기   [Q·E] 하위 탭   [Enter] 지원 요청   숫자 표시: 설정 > 표시")
    return s.finish(bezel())


if __name__ == "__main__":
    out = os.path.join(ROOT, "samples")
    for name, fn in (("07_pipboy_stat", stat_screen), ("07_pipboy_faction", faction_screen)):
        im = fn()
        im.save(os.path.join(out, name + ".png"))
        upscale(im.convert("RGBA"), 2).convert("RGB").save(os.path.join(out, name + "_x2.png"))
    print("ok")
