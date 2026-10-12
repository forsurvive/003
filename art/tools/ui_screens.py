"""Reference sample #11 (rest): Pip-Boy world map + 'Seoul balance' layer (SD-12 §5.1, §5.8), dialogue window
(SD-12 §6.1), birth registration terminal (SD-10 §8.2, amber), school record book S.P.E.C.I.A.L. (SD-10 §2.6)
and aptitude result notice + tag selection (SD-10 §8.5). 640x360 each.
Writes samples/18_ui_map.png, 18_ui_map_balance.png, 18_ui_dialogue.png, 18_ui_birth.png, 18_ui_record.png,
18_ui_aptitude.png (+ _x2)."""
import os, sys, math
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import pipboy as PB
from grid import upscale, parse

ROOT = os.path.dirname(os.path.dirname(__file__))
Cr = P.rgb
U = lambda i: Cr(f"U{i}")
A = lambda i: Cr(f"A{i}")
F = lambda n, s: ImageFont.truetype(os.path.join(ROOT, "fonts", n), s)
F10, F12, F12B, F15 = F("Galmuri9.ttf", 10), F("Galmuri11.ttf", 12), F("Galmuri11-Bold.ttf", 12), F("Galmuri14.ttf", 15)
F8 = F("Galmuri7.ttf", 8)
OUT = os.path.join(ROOT, "samples")


def save(im, name):
    im.save(os.path.join(OUT, name + ".png"))
    upscale(im.convert("RGBA"), 2).convert("RGB").save(os.path.join(OUT, name + "_x2.png"))


# ---------------------------------------------------------------- world map
# map space: columns 다~아 (6 of 14) x rows 6~11 of the 가~하 x 1~12 grid; one cell = 80 x 36 px on screen
MX0, MY0, MW, MH = 64, 90, 480, 174
COLS = "다라마바사아"
ROWS = range(6, 12)


def map_base(s, balance=False):
    d = s.d
    ox, oy = MX0 - s.X0, MY0 - s.Y0
    # grid letters / numbers on the margins
    for i, ch in enumerate(COLS):
        s.t(MX0 + i * 80 + 36, MY0 + MH + 1, ch, F10, 3)
        for y in range(MY0, MY0 + MH, 4):
            d.point((ox + i * 80, y - s.Y0), fill=U(2))
    for j, r in enumerate(ROWS):
        s.t(MX0 - 14, MY0 + j * 29 + 9, str(r), F10, 3)
        for x in range(MX0, MX0 + MW, 4):
            d.point((x - s.X0, oy + j * 29), fill=U(2))
    # Han river: dark band across the top with 여의도 and 노들섬 islands
    river = [(MX0, MY0 + 8), (MX0 + 120, MY0 + 18), (MX0 + 240, MY0 + 26), (MX0 + 360, MY0 + 22), (MX0 + MW, MY0 + 12),
             (MX0 + MW, MY0 + 34), (MX0 + 360, MY0 + 44), (MX0 + 240, MY0 + 48), (MX0 + 120, MY0 + 40), (MX0, MY0 + 30)]
    d.polygon([(x - s.X0, y - s.Y0) for x, y in river], fill=U(3), outline=U(5))
    d.ellipse([MX0 + 40 - s.X0, MY0 + 14 - s.Y0, MX0 + 110 - s.X0, MY0 + 30 - s.Y0], fill=U(1), outline=U(5))   # 여의도
    d.ellipse([MX0 + 228 - s.X0, MY0 + 30 - s.Y0, MX0 + 250 - s.X0, MY0 + 38 - s.Y0], fill=U(1), outline=U(5))  # 노들섬
    for bx in (150, 238, 320):                                  # bridges (crossing state icons)
        s.line(MX0 + bx, MY0 + 16, MX0 + bx + 4, MY0 + 50, 6)
    s.t(MX0 + 400, MY0 + 26, "한강", F10, 6)
    # roads (남부순환로, 관악로), 관악산 contours, region boundary
    s.line(MX0, MY0 + 120, MX0 + MW, MY0 + 112, 3)
    s.line(MX0 + 250, MY0 + 50, MX0 + 262, MY0 + MH, 3)
    for k, r in enumerate((60, 46, 32, 18)):
        cx, cy = MX0 + 260, MY0 + MH + 18
        for a in range(190, 351, 4 if k < 2 else 6):
            x = cx + r * 2.2 * math.cos(math.radians(a)); y = cy + r * math.sin(math.radians(a))
            if MY0 < y < MY0 + MH:
                d.point((x - s.X0, y - s.Y0), fill=U(2 + (k > 1)))
    s.t(MX0 + 180, MY0 + 168, "관악산", F10, 3)
    bound = [(MX0 + 20, MY0 + 64), (MX0 + 200, MY0 + 58), (MX0 + 380, MY0 + 62), (MX0 + 470, MY0 + 90),
             (MX0 + 470, MY0 + MH - 4), (MX0 + 10, MY0 + MH - 4)]
    for (x0, y0), (x1, y1) in zip(bound, bound[1:] + bound[:1]):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) / 3)
        for i in range(0, n, 2):
            t = i / n
            d.point((x0 + (x1 - x0) * t - s.X0, y0 + (y1 - y0) * t - s.Y0), fill=U(4))
    s.t(MX0 + 26, MY0 + 70, "R01 관악·봉천", F12B, 6)
    s.t(MX0 + 2, MY0 + 36, "R02 영등포·여의도", F10, 4)


def marker(s, x, y, kind, label=None, found=True, col=6):
    d = s.d
    X, Y = x - s.X0, y - s.Y0
    if kind == "vault":                                         # 볼트-텍 톱니
        for a in range(0, 360, 45):
            r = math.radians(a)
            d.rectangle([X + 5 * math.cos(r) - 1, Y + 5 * math.sin(r) - 1, X + 5 * math.cos(r) + 1, Y + 5 * math.sin(r) + 1], fill=U(col))
        d.ellipse([X - 4, Y - 4, X + 4, Y + 4], fill=U(col) if found else U(1), outline=U(col))
        d.ellipse([X - 1, Y - 1, X + 1, Y + 1], fill=U(1))
    elif kind == "town":                                        # 소형 정착지: 지붕 둘
        d.polygon([(X - 6, Y + 3), (X - 3, Y - 3), (X, Y + 3)], fill=U(col) if found else None, outline=U(col))
        d.polygon([(X, Y + 3), (X + 3, Y - 4), (X + 6, Y + 3)], fill=U(col) if found else None, outline=U(col))
    elif kind == "metro":                                       # 역명판
        d.rectangle([X - 5, Y - 3, X + 5, Y + 3], fill=U(col) if found else None, outline=U(col))
        d.line([X - 3, Y, X + 3, Y], fill=U(1) if found else U(col))
    elif kind == "rumor":
        d.ellipse([X - 5, Y - 5, X + 5, Y + 5], outline=U(col))
        s.t(x - 3, y - 6, "?", F10, col)
    elif kind == "site":
        d.rectangle([X - 4, Y - 4, X + 4, Y + 4], fill=U(col) if found else None, outline=U(col))
    elif kind == "player":
        d.polygon([(X, Y - 6), (X + 4, Y + 4), (X, Y + 2), (X - 4, Y + 4)], fill=U(7))
    elif kind == "quest":
        d.polygon([(X, Y - 6), (X + 5, Y), (X, Y + 6), (X - 5, Y)], outline=U(7))
        d.point((X, Y), fill=U(7))
    if label:
        s.t(x + 8, y - 6, label, F10, col if found else 3)


PLACES = [("vault", 330, 244, "S-07", True), ("town", 300, 202, "봉천 계단마을", True), ("metro", 368, 178, "서울대입구역", True),
          ("site", 214, 226, "신림 고시촌", True), ("metro", 470, 170, "사당역", False), ("town", 268, 142, "노량진 수산시장", True),
          ("rumor", 160, 196, None, False), ("site", 420, 222, "낙성대 망루", False), ("town", 155, 108, "여의도 금탑", False),
          ("quest", 268, 142, None, True), ("player", 312, 212, None, True)]


def world_map(balance=False):
    bez = PB.bezel()
    s = PB.Screen()
    s.tabs(2, ["지역 지도", "월드 지도", "퀘스트", "노트", "라디오"], 1)
    # layer switcher
    for i, name in enumerate(["지상", "지하 UG", "한강 HR", "판도"]):
        x = 52 + i * 70
        act = (i == 3) if balance else (i == 0)
        if act:
            s.rect(x - 3, 71, x + 60, 84, None, fill=6); s.t(x, 72, name, F10, 0)
        else:
            s.t(x, 72, name, F10, 3)
    s.t(360, 72, "Q·E 레이어   Tab 필터   L 이동 목록", F10, 3)
    map_base(s, balance)
    if balance:
        balance_layer(s)
    for kind, x, y, label, found in PLACES:
        marker(s, x, y, kind, label if not balance or kind in ("town", "vault") else None, found)
    # cursor info (2 lines) + coordinates
    s.rect(380, 226, 590, 266, 4, fill=1)
    if balance:
        s.t(386, 229, "봉천 계단마을 · 정착지 연합", F10, 6)
        s.t(386, 241, "10. 21. 계엄군 검문소가 철수했다.", F10, 5)
        s.t(386, 253, "↻ 3일 전", F10, 4)
    else:
        s.t(386, 229, "봉천 계단마을 / R01 관악", F10, 6)
        s.t(386, 241, "발견 · 빠른 이동 1시간", F10, 5)
        s.t(386, 253, "R01 · 청크 (12, 31) · 타일 (7, 4)", F10, 4)
    if balance:
        legend(s)
    else:
        s.hint("A 확대  ·  커서: 장소 정보  ·  ★ 즐겨찾기")
    return s.finish(bez)


def hatch(s, mask_poly, pattern, col=3):
    """Faction pattern fill (35% look on a green CRT): rows / columns / dots / grid / diagonal / waves."""
    m = Image.new("L", (s.W, s.H), 0)
    ImageDraw.Draw(m).polygon([(x - s.X0, y - s.Y0) for x, y in mask_poly], fill=255)
    px = s.im.load()
    for y in range(s.H):
        for x in range(s.W):
            if not m.getpixel((x, y)):
                continue
            on = {"rows": y % 4 == 0, "cols": x % 4 == 0, "dots": x % 4 == 0 and y % 4 == 0,
                  "grid": x % 6 == 0 or y % 6 == 0, "diag": (x + y) % 6 == 0, "diag2": (x - y) % 6 == 0,
                  "wave": (y + int(2 * math.sin(x / 3))) % 5 == 0, "unknown": (x + y) % 3 == 0 and (x // 3) % 2}.get(pattern, False)
            if on:
                px[x, y] = U(col)


def flag(s, x, y, contested=False):
    d = s.d
    X, Y = x - s.X0, y - s.Y0
    d.line([X, Y - 8, X, Y + 2], fill=U(7))
    d.polygon([(X, Y - 8), (X + 6, Y - 6), (X, Y - 4)], fill=U(7))
    if contested:
        d.line([X + 3, Y - 9, X + 3, Y + 2], fill=U(5)); d.polygon([(X + 3, Y - 9), (X - 3, Y - 7), (X + 3, Y - 5)], fill=U(5))


def balance_layer(s):
    # 정착지 연합 (봉천·신림) = 세로줄, 계엄군 (여의도 일대) = 격자, 새벽인력 (노량진) = 빗금, 미접촉 = 알 수 없음
    hatch(s, [(MX0 + 150, MY0 + 64), (MX0 + 330, MY0 + 60), (MX0 + 340, MY0 + 180), (MX0 + 140, MY0 + 182)], "cols", 3)
    hatch(s, [(MX0, MY0), (MX0 + 140, MY0 + 4), (MX0 + 130, MY0 + 60), (MX0, MY0 + 62)], "grid", 3)
    hatch(s, [(MX0 + 160, MY0 + 30), (MX0 + 300, MY0 + 30), (MX0 + 300, MY0 + 60), (MX0 + 160, MY0 + 60)], "diag", 3)
    hatch(s, [(MX0 + 350, MY0 + 60), (MX0 + MW, MY0 + 50), (MX0 + MW, MY0 + MH), (MX0 + 350, MY0 + MH)], "unknown", 2)
    flag(s, 300, 200); flag(s, 268, 140, contested=True); flag(s, 120, 104); flag(s, 330, 242)
    s.t(310, 190, "↻", F10, 7)


def legend(s):
    x = 48
    for pat, name in (("cols", "정착지 연합"), ("grid", "비상정부·계엄군"), ("diag", "새벽인력"), ("unknown", "알 수 없음")):
        hatch(s, [(x, 281), (x + 12, 281), (x + 12, 290), (x, 290)], pat, 5)
        s.rect(x, 281, x + 12, 290, 3)
        s.t(x + 16, 280, name, F10, 5)
        x += 30 + len(name) * 10


# ---------------------------------------------------------------- dialogue window
def dialogue():
    import scene_bongcheon as SB
    import portraits as PT
    import npcs as NP
    import rig_pc as R
    base = SB.build(hud=False).convert("RGBA")
    # the two speakers, facing each other above the box (camera sits at their midpoint)
    zm = NP.build("E1-S4-HR01-H5-T03-2-PF12-HD00-EY00-PR006")["idle"]["W"]
    pc = R.build_all("T01", None, {"hair": "HR05", "color": "H2"})[0]["idle"]["E"]
    for spr, fx in ((pc, 296), (zm, 340)):
        for ddx in range(-7, 8):
            for ddy in (-1, 0, 1):
                if (ddx / 7.5) ** 2 + (ddy / 1.6) ** 2 <= 1:
                    r_, g_, b_, a_ = base.getpixel((fx + ddx, 226 + ddy))
                    base.putpixel((fx + ddx, 226 + ddy), (r_ * 2 // 3, g_ * 2 // 3, b_ * 2 // 3, 255))
        base.alpha_composite(spr, (fx - 32, 226 - 60))
    d = ImageDraw.Draw(base); d.fontmode = "1"
    # choices window (above the dialogue box)
    ch = Image.new("RGBA", (488, 6 + 4 * 18 + 6), (0, 0, 0, 0))
    cd = ImageDraw.Draw(ch); cd.fontmode = "1"
    cd.rectangle([0, 0, 487, ch.height - 1], fill=Cr("P01") + (217,), outline=Cr("P07") + (255,))
    choices = [("[화술 45%]", "그 쇠파이프, 지팡이치고는 무거워 보이네요."), ("[인지력 6]", "아랫문 경비가 반으로 줄었던데요."),
               (None, "볼트에서 나왔어요. 길을 물어봐도 될까요?"), (None, "됐어요. 갈게요.")]
    for i, (tag, txt) in enumerate(choices):
        y = 6 + i * 18
        if i == 0:
            cd.rectangle([3, y - 2, 484, y + 14], fill=Cr("P48") + (255,))
        col = Cr("P01") if i == 0 else Cr("P09")
        cd.text((10, y), f"{i + 1}.", font=F12, fill=col)
        x = 28
        if tag:
            cd.text((x, y), tag, font=F12, fill=Cr("P02") if i == 0 else Cr("P49"))
            x += int(cd.textlength(tag, font=F12)) + 6
        cd.text((x, y), txt, font=F12, fill=col)
    base.alpha_composite(ch, (128, 112))
    # dialogue box 16,248 608x104 (85% black), portrait 24,252, name tag 128,232
    box = Image.new("RGBA", (608, 104), Cr("P01") + (217,))
    ImageDraw.Draw(box).rectangle([0, 0, 607, 103], outline=Cr("P07") + (255,))
    base.alpha_composite(box, (16, 248))
    p = PT.UNIQUE[3][2]
    face = PT.portrait(p, "결의")
    plate = Image.new("RGBA", (96, 96), Cr("P17") + (255,))
    plate.alpha_composite(face)
    base.alpha_composite(plate, (24, 252))
    d = ImageDraw.Draw(base); d.fontmode = "1"
    d.rectangle([24, 252, 119, 347], outline=Cr("P05"))
    tag = Image.new("RGBA", (262, 16), Cr("P01") + (217,))
    base.alpha_composite(tag, (124, 230))
    hint = Image.new("RGBA", (52, 13), Cr("P01") + (217,))
    base.alpha_composite(hint, (14, 234))
    d = ImageDraw.Draw(base); d.fontmode = "1"
    # emblem 8x8 (정착지 연합: house + ring) + name tag
    d.rectangle([128, 233, 135, 240], fill=Cr("P27")); d.polygon([(129, 237), (131, 234), (134, 237)], fill=Cr("P09"))
    d.rectangle([130, 237, 133, 240], fill=Cr("P09"))
    d.text((140, 231), "조만석 (봉천 계단마을 이장)", font=F12B, fill=Cr("P09"))
    d.text((16, 235), "(L) 기록", font=F10, fill=Cr("P07"))
    lines = ["볼트에서 내려온 놈이 셋째야. 앞의 둘은 계단도 다 못 내려갔지.",
             "여기선 물 한 바가지도 공짜가 없어. 일을 하든지, 캡을 내든지.",
             "아랫문 지키는 애들한테는 내가 말해 두마. 대신 밤에는 나다니지 마라."]
    for i, s in enumerate(lines):
        d.text((128, 258 + i * 18), s, font=F12, fill=Cr("P09"))
    d.polygon([(604, 338), (612, 338), (608, 344)], fill=Cr("P48"))
    # the line the player picked stays faintly for 0.8s above the text
    d.text((128, 240 + 4), "", font=F10, fill=Cr("P06"))
    return base.convert("RGB")


# ---------------------------------------------------------------- birth registration terminal (amber)
def amber(img):
    """Map a sprite/portrait to the amber CRT ramp by luminance (monochrome preview)."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    px, po = img.load(), out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a:
                L = (r * 299 + g * 587 + b * 114) // 1000
                po[x, y] = A(min(7, 1 + L * 7 // 230)) + (255,)
    return out


def birth_terminal():
    import rig_pc as R
    import portraits as PT
    W, H = 640, 360
    im = Image.new("RGB", (W, H), Cr("P08"))
    d = ImageDraw.Draw(im); d.fontmode = "1"
    # 세진 cream housing with teal trim, CRT recess
    d.rectangle([0, 0, W - 1, H - 1], fill=Cr("P08"))
    d.rectangle([0, 0, W - 1, 14], fill=Cr("P62")); d.line([0, 14, W, 14], fill=Cr("P61"))
    d.text((8, 1), "세진전자  SJ-RT7 진공관 등록 단말  ·  볼트 S-07 행정실", font=F10, fill=Cr("P09"))
    for x in (580, 596, 612):
        d.ellipse([x, 3, x + 9, 12], fill=Cr("P61"), outline=Cr("P01"))
    d.rounded_rectangle([18, 22, W - 19, H - 26], radius=10, fill=Cr("P02"))
    d.rounded_rectangle([22, 26, W - 23, H - 30], radius=8, fill=A(0))
    for x in range(40, 600, 40):                                 # valve windows on the chin panel
        d.ellipse([x, H - 22, x + 10, H - 12], fill=Cr("P58"), outline=Cr("P01")); d.point((x + 4, H - 18), fill=Cr("P60"))
    scr = Image.new("RGB", (W - 48, H - 60), A(0))
    s = ImageDraw.Draw(scr); s.fontmode = "1"
    t = lambda x, y, txt, f=F12, c=6: s.text((x, y), txt, font=f, fill=A(c))
    t(10, 6, "볼트 S-07 출생신고서", F15, 7)
    t(380, 9, "서식 제1호 · 2258", F10, 4)
    s.line([10, 26, 580, 26], fill=A(3))
    rows = [("신고인", "윤정인 (오버시어)", False), ("성명", "한서진_", True), ("성별", "( ) 남   (●) 여", False),
            ("등록번호", "S07-2258-0031  (자동 발급)", False), ("출생 일시", "2258. 03. 14.  04:12", False),
            ("출생 장소", "의무과 분만실 (V-08)", False)]
    for i, (k, v, active) in enumerate(rows):
        y = 36 + i * 22
        t(14, y, k, F12, 4)
        if active:
            s.rectangle([96, y - 2, 330, y + 14], outline=A(6))
        t(102, y, v, F12, 7 if active else 6)
        s.line([96, y + 16, 330, y + 16], fill=A(2))
    t(14, 172, "외형", F12, 4)
    s.rectangle([96, 168, 196, 186], fill=A(6)); t(104, 171, "[성장 예측]", F12, 0)
    t(206, 171, "19세 모습을 미리 봅니다", F10, 4)
    # preview: map sprite (4 directions) + face, rendered monochrome on the amber tube
    sets, _ = R.build_all("T01", None, {"hair": "HR05", "color": "H2"})
    pv = Image.new("RGBA", (232, 132), A(1) + (255,))
    pd = ImageDraw.Draw(pv); pd.fontmode = "1"
    pd.rectangle([0, 0, 231, 131], outline=A(4))
    pd.text((6, 3), "세진 성장 예측기", font=F10, fill=A(6))
    for k, v in enumerate(("S", "E", "N", "W")):
        spr = amber(sets["idle"][v].crop((14, 18, 50, 62)))
        pv.alpha_composite(spr, (4 + k * 30, 40))
    face = PT.portrait(dict(skin="S3", hair="HR05", hair_color="H2", female=True, torso="T01", faction="PF-11", jaw=0.15), "기본")
    pv.alpha_composite(amber(face.crop((14, 8, 82, 92))), (152 - 26, 30))
    pd.text((6, 116), "◀ 회전 ▶   머리 HR05   피부 S3", font=F10, fill=A(5))
    scr_rgba = scr.convert("RGBA"); scr_rgba.alpha_composite(pv, (350, 36)); scr = scr_rgba.convert("RGB")
    s = ImageDraw.Draw(scr); s.fontmode = "1"
    t = lambda x, y, txt, f=F12, c=6: s.text((x, y), txt, font=f, fill=A(c))
    t(14, 214, "※ 신고 내용은 수도 관제망 등록 원부에 영구 기록됩니다.", F10, 4)
    t(14, 228, "※ 등록번호는 이후 어떤 서류에서도 바뀌지 않습니다.", F10, 4)
    for i, (lab, on) in enumerate((("무작위", False), ("기본값", False), ("신고", True))):
        x = 330 + i * 86
        if on:
            s.rectangle([x, 252, x + 76, 272], fill=A(7)); t(x + 22, 256, f"[{lab}]", F12, 0)
        else:
            s.rectangle([x, 252, x + 76, 272], outline=A(4)); t(x + 14, 256, f"[{lab}]", F12, 5)
    t(14, 258, "관리자 인증: 오버시어실  ●", F10, 5)
    for y in range(0, scr.height, 2):                          # scanlines
        for x in range(scr.width):
            r, g, b = scr.getpixel((x, y))
            scr.putpixel((x, y), (r * 85 // 100, g * 85 // 100, b * 85 // 100))
    im.paste(scr, (24, 28))
    return im


# ---------------------------------------------------------------- paper documents
PAPER, INK, INK2, RED = Cr("P08"), Cr("P44"), Cr("P43"), Cr("P53")
COMMENTS = {"체력장": "체력장 3등급. 무난합니다.", "관찰·탐구 태도": "환기구 소리가 바뀐 것을 먼저 알아챘습니다.",
            "건강 기록": "건강합니다.", "교우 관계": "친구가 적지만 갈등은 없습니다.",
            "학업 성취": "상위권. 적성 평가가 기대됩니다.", "운동 기능": "보통입니다.", "특기 사항": "특이 사항 없음."}


def paper(d, x0, y0, x1, y1):
    d.rectangle([x0 + 3, y0 + 3, x1 + 3, y1 + 3], fill=Cr("P03"))                  # drop shadow on the desk
    d.rectangle([x0, y0, x1, y1], fill=PAPER, outline=Cr("P06"))
    d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=Cr("P09"))
    for y in range(y0 + 6, y1, 37):                                               # faint fold / age marks
        d.point((x1 - 6, y), fill=Cr("P07"))


def stamp(d, cx, cy, text, r=13):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=RED, width=2)
    d.ellipse([cx - r + 3, cy - r + 3, cx + r - 3, cy + r - 3], outline=RED)
    d.text((cx, cy - 6), text, font=F10, fill=RED, anchor="ma")


STATS = [("체력장", "힘", 5), ("관찰·탐구 태도", "인지력", 7), ("건강 기록", "지구력", 5), ("교우 관계", "카리스마", 4),
         ("학업 성취", "지능", 8), ("운동 기능", "민첩성", 6), ("특기 사항", "행운", 5)]
SKILLS = [("물물교환", "카리스마"), ("중화기", "지구력"), ("에너지 무기", "인지력"), ("폭발물", "인지력"), ("자물쇠 따기", "인지력"),
          ("의학", "지능"), ("근접 무기", "힘"), ("수리", "지능"), ("과학", "지능"), ("소형 화기", "민첩성"), ("은신", "민첩성"),
          ("화술", "카리스마"), ("비무장", "지구력")]


def skill_values():
    """SD-10: initial skill = 2 + governing stat x 2 + ceil(luck / 2)."""
    st = {k: v for (_, k, v) in STATS}
    lk = math.ceil(st["행운"] / 2)
    return [(k, 2 + st[b] * 2 + lk) for k, b in SKILLS]


def record_book():
    W, H = 640, 360
    im = Image.new("RGB", (W, H), Cr("P17"))
    d = ImageDraw.Draw(im); d.fontmode = "1"
    for y in range(0, H, 3):                                                      # desk wood grain (rows)
        d.line([0, y, W, y], fill=Cr("P18") if (y // 3) % 4 == 0 else Cr("P17"))
    paper(d, 16, 10, 452, 350)
    d.text((234, 16), "볼트 S-07 초등과정 학교생활기록부", font=F15, fill=INK, anchor="ma")
    d.text((24, 38), "성명  한서진", font=F12, fill=Cr("P02")); d.text((140, 38), "등록번호  S07-2258-0031", font=F12, fill=Cr("P02"))
    d.text((360, 38), "학년도 2268", font=F12, fill=Cr("P02"))
    d.line([20, 54, 448, 54], fill=INK, width=2)
    stats = STATS
    for i, (item, sp, v) in enumerate(stats):
        y = 60 + i * 38
        d.rectangle([20, y, 448, y + 34], outline=Cr("P06"))
        if i == 1:
            d.rectangle([21, y + 1, 447, y + 33], fill=Cr("P09"))                # row in focus
        d.text((26, y + 3), item, font=F12B, fill=INK2); d.text((26, y + 18), sp, font=F10, fill=Cr("P05"))
        for k in range(10):
            bx = 136 + k * 15
            d.rectangle([bx, y + 4, bx + 11, y + 14], outline=INK)
            if k < v:
                d.rectangle([bx + 2, y + 6, bx + 9, y + 12], fill=INK)
        d.text((292, y + 3), f"{v:>2}", font=F12B, fill=Cr("P02"))
        d.text((310, y + 3), "◀ ▶", font=F10, fill=Cr("P05"))
        d.text((136, y + 19), "담임 의견: " + COMMENTS[item], font=F10, fill=Cr("P03"))
    d.text((24, 330), "남은 점수  0", font=F12B, fill=RED)
    for i, (lab, on) in enumerate((("되돌리기", 0), ("기본값", 0), ("확정", 1))):
        x = 196 + i * 84
        d.rectangle([x, 326, x + 76, 344], fill=INK if on else PAPER, outline=INK)
        d.text((x + 38, 329), f"[{lab}]", font=F12, fill=PAPER if on else INK, anchor="ma")
    stamp(d, 420, 304, "담임", 14)
    # right panel: live preview of derived values + 13 skills (before tags)
    paper(d, 464, 10, 626, 350)
    d.text((545, 16), "미리보기", font=F12B, fill=INK, anchor="ma")
    st = {k: v for (_, k, v) in stats}
    der = [("최대 HP", 90 + st["지구력"] * 20 + 10), ("최대 AP", 65 + st["민첩성"] * 2), ("소지 한도", 150 + st["힘"] * 10),
           ("탐지 반경", f"{6 + st['인지력'] // 2}t"), ("레벨업 스킬", 10 + st["지능"])]
    for i, (k, v) in enumerate(der):
        d.text((472, 36 + i * 15), k, font=F10, fill=Cr("P03")); d.text((618, 36 + i * 15), str(v), font=F10, fill=Cr("P02"), anchor="ra")
    d.line([470, 114, 620, 114], fill=Cr("P06"))
    for i, (k, v) in enumerate(skill_values()):
        d.text((472, 120 + i * 16), k, font=F10, fill=Cr("P03")); d.text((618, 120 + i * 16), str(v), font=F10, fill=Cr("P02"), anchor="ra")
    return im


def aptitude():
    W, H = 640, 360
    im = Image.new("RGB", (W, H), Cr("P17"))
    d = ImageDraw.Draw(im); d.fontmode = "1"
    for y in range(0, H, 3):
        d.line([0, y, W, y], fill=Cr("P18") if (y // 3) % 4 == 0 else Cr("P17"))
    # result notice (left)
    paper(d, 16, 10, 312, 350)
    d.text((164, 16), "재건 행정 요원 적성 평가", font=F12B, fill=INK, anchor="ma")
    d.text((164, 32), "결과 통지서", font=F15, fill=INK, anchor="ma")
    d.line([24, 52, 304, 52], fill=INK, width=2)
    rows = [("성명", "한서진"), ("등록번호", "S07-2258-0031"), ("응시일", "2274. 09. 02."), ("감독관", "차명수")]
    for i, (k, v) in enumerate(rows):
        d.text((28, 60 + i * 16), k, font=F10, fill=Cr("P05")); d.text((100, 60 + i * 16), v, font=F12, fill=Cr("P02"))
    d.rectangle([24, 130, 304, 168], outline=INK)
    d.text((32, 134), "적성 직업", font=F10, fill=Cr("P05"))
    d.text((164, 148), "승강기 점검 기사", font=F15, fill=Cr("P02"), anchor="ma")
    d.text((28, 176), "추천 태그", font=F10, fill=Cr("P05"))
    for i, (k, n) in enumerate((("수리", 4), ("과학", 3), ("의학", 3))):
        d.text((40, 192 + i * 16), f"{i + 1}. {k}", font=F12, fill=Cr("P02")); d.text((200, 192 + i * 16), f"{n}점", font=F10, fill=Cr("P05"))
    d.line([24, 248, 304, 248], fill=Cr("P06"))
    d.text((28, 256), "종합 판정", font=F10, fill=Cr("P05"))
    d.text((164, 272), "관리 후보 1순위", font=F15, fill=RED, anchor="ma")
    stamp(d, 274, 300, "평가", 16)
    d.text((28, 316), "※ 적성 직업은 배정 참고용입니다.", font=F10, fill=Cr("P05"))
    d.text((28, 330), "   종합 판정은 평가 위원회가 정합니다.", font=F10, fill=Cr("P05"))
    # tag selection (right)
    paper(d, 324, 10, 626, 350)
    d.text((475, 16), "태그 스킬 선택  (3개)", font=F12B, fill=INK, anchor="ma")
    d.text((475, 32), "추천은 참고일 뿐입니다. 자유롭게 바꾸세요.", font=F10, fill=Cr("P05"), anchor="ma")
    skills = skill_values()
    tags = {"수리", "과학", "화술"}
    for i, (k, v) in enumerate(skills):
        y = 50 + i * 19
        on = k in tags
        if k == "화술":
            d.rectangle([330, y - 2, 620, y + 15], fill=Cr("P09"))
        d.rectangle([334, y + 1, 344, y + 11], outline=INK)
        if on:
            d.line([336, y + 6, 339, y + 9], fill=RED, width=2); d.line([339, y + 9, 344, y + 1], fill=RED, width=2)
        d.text((352, y), k, font=F12, fill=Cr("P02"))
        d.text((540, y), str(v), font=F12, fill=Cr("P05"), anchor="ra")
        if on:
            d.text((612, y), f"{v + 15}", font=F12B, fill=RED, anchor="ra"); d.text((548, y), "→", font=F12, fill=Cr("P05"))
        if k in ("수리", "과학", "의학"):
            d.text((462, y + 2), "추천", font=F8, fill=INK)
    d.text((334, 304), "선택 3 / 3", font=F12B, fill=RED)
    for i, (lab, on) in enumerate((("추천으로", 0), ("확정", 1))):
        x = 440 + i * 90
        d.rectangle([x, 322, x + 80, 340], fill=INK if on else PAPER, outline=INK)
        d.text((x + 40, 325), f"[{lab}]", font=F12, fill=PAPER if on else INK, anchor="ma")
    return im


if __name__ == "__main__":
    save(world_map(False), "18_ui_map")
    save(world_map(True), "18_ui_map_balance")
    save(dialogue(), "18_ui_dialogue")
    save(birth_terminal(), "18_ui_birth")
    save(record_book(), "18_ui_record")
    save(aptitude(), "18_ui_aptitude")
    print("ok")
