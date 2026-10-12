"""#13 출생 장면 — 인게임 컷신 (SD-03a §7.1 MQ-P1 S1, SD-16 §12.3 #13).
배경 일러스트 대신 실제 게임 화면으로 연출한다(쯔꾸르식): S-07 타일로 깐 V-08 의무실, 맵 스프라이트, 대화창(얼굴 그림),
감정 말풍선. 주인공은 윤정인 품의 갓난아기라 카메라는 침대에 고정된다.
흐름: 흰 화면에서 밝아짐 → 신혜령 "건강해요" → 단말 '삑' 두 번, 6번 칸 초록 → 방금례 ! 후 돌아섬 → 대사 → 윤정인 ♥.
Writes samples/21_scene_birth(.png, _x2), 21_scene_birth.gif."""
import os, sys, math
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import tiles_s07 as S
import npcs as NP
import portraits as PT
import hangul16 as HG
from grid import upscale, check

ROOT = os.path.dirname(os.path.dirname(__file__))
T = 32
W, H = 640, 360
Cr = P.rgb
C = lambda t: P.rgb(t) + (255,)
F = lambda n, s: ImageFont.truetype(os.path.join(ROOT, "fonts", n), s)
F9, F12, F12B = F("Galmuri9.ttf", 10), F("Galmuri11.ttf", 12), F("Galmuri11-Bold.ttf", 12)
RGB2TOK = {P.rgb(f"P{i:02d}"): f"P{i:02d}" for i in range(64)}
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))

# 2258년 외형 (SD-07b 코드의 19년 전): 윤정인 23세 머리 풀림, 신혜령 근무 중 올림머리, 방금례 45세 아직 검은 머리
JEONGIN = "F1-S2-HR06-H1-T01-0-PF11-HD00-EY00-PR000"
HYERYEONG = "F1-S2-HR07-H1-T13-1-PF11-HD00-EY00-PR011"
GEUMRYE = "F2-S2-HR08-H2-T11-1-PF11-HD00-EY02-PR019"

# room: floor cols 2..17, rows 3..9; north wall rows 0..2 (2-tile face), side walls, south wall rows 10..
FX0, FX1, FY0, FY1 = 2, 17, 3, 9


def contact_shadow(img, x0, x1, y, h=2):
    px = img.load()
    for yy in range(y, min(H, y + h)):
        for xx in range(max(0, x0), min(W, x1)):
            tok = RGB2TOK.get(px[xx, yy][:3])
            if tok:
                px[xx, yy] = S.C(S.shadow_px(tok))


def room():
    img = Image.new("RGBA", (W, H), C("P10"))
    for r in range(12):
        for c in range(20):
            x, y = c * T, r * T
            if FX0 <= c <= FX1 and r == 0:
                img.alpha_composite(S.wall_top({"s"}), (x, y))
            elif FX0 <= c <= FX1 and r in (1, 2):
                v = "vent" if (c == 16 and r == 1) else ("outlet" if c == 5 and r == 2 else "plain")
                img.alpha_composite(S.wall_face("top" if r == 1 else "bot", v, c), (x, y))
            elif FX0 <= c <= FX1 and FY0 <= r <= FY1:
                img.alpha_composite(S.clinic_tile(c * 3 + r), (x, y))
            else:
                e = set()
                if c == FX0 - 1 and r >= 1 and r <= FY1:
                    e.add("e")
                if c == FX1 + 1 and r >= 1 and r <= FY1:
                    e.add("w")
                if r == FY1 + 1 and FX0 <= c <= FX1:
                    e.add("n")
                img.alpha_composite(S.wall_top(e), (x, y))
    contact_shadow(img, FX0 * T, (FX1 + 1) * T, FY0 * T, 2)
    # door to the atrium corridor (V-01) and the delivery-room sign in the #14 sign font
    img.alpha_composite(S.door_slide("closed", "V-01"), (15 * T, 1 * T))
    plate(img, "의무과", 9 * T - 4, 1 * T + 2)
    img.alpha_composite(S.wall_clock(4, 20), (12 * T + 8, 1 * T + 9))     # 04:20, eight minutes after the birth
    return img


def plate(img, s, x, y):
    m, w = set(), 0
    for ch in s:
        m |= {(gx + w, gy) for gx, gy in HG.glyph(ch)}
        w += HG.advance(ch)
    w -= 1
    d = ImageDraw.Draw(img)
    d.rectangle([x, y, x + w + 9, y + 20], fill=C("P01"))
    d.rectangle([x + 1, y + 1, x + w + 8, y + 19], fill=C("P45")); d.line([x + 1, y + 1, x + w + 8, y + 1], fill=C("P46"))
    px = img.load()
    for gx, gy in m:
        px[x + 5 + gx + 1, y + 3 + gy + 1] = C("P43")
    for gx, gy in m:
        px[x + 5 + gx, y + 3 + gy] = C("P50")


# ------------------------------------------------------------------------------------------------ props
def iv_stand():
    img = Image.new("RGBA", (16, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line([8, 6, 8, 55], fill=C("P07")); d.line([9, 6, 9, 55], fill=C("P05"))
    d.line([3, 5, 14, 5], fill=C("P07"))
    d.rectangle([2, 7, 7, 17], fill=C("P15"), outline=C("P12")); d.rectangle([3, 13, 6, 16], fill=C("P14"))
    d.point((3, 8), fill=C("P09"))
    d.line([5, 18, 5, 24], fill=C("P13"))
    d.line([3, 57, 13, 57], fill=C("P04")); d.line([4, 56, 12, 56], fill=C("P05"))
    for x in (3, 13):
        d.point((x, 58), fill=C("P02"))
    return img


def bobblehead():
    """CL-13 흔들인형 '의학' on the cabinet top: 든든이 in a safety helmet holding a first-aid case (8x10)."""
    img = Image.new("RGBA", (10, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 10, 8, 11], fill=C("P05"))
    d.rectangle([3, 6, 6, 9], fill=C("P46"))
    d.ellipse([2, 1, 7, 6], fill=C("S1.4"), outline=C("P02"))
    d.rectangle([2, 0, 7, 2], fill=C("P49")); d.line([1, 2, 8, 2], fill=C("P48"))
    d.rectangle([6, 7, 9, 9], fill=C("P09")); d.point((7, 8), fill=C("P53"))
    return img


def terminal_cart(field6=False, frame=0):
    """세진 진공관 등록 단말 on a wheeled cart, screen to the south: amber form rows; field 6 lamp lit green
    (and its row) while field6=True."""
    img = Image.new("RGBA", (40, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # cart body + tube window + wheels
    d.rectangle([4, 30, 35, 56], fill=C("P07"), outline=C("P02")); d.line([5, 31, 34, 31], fill=C("P09"))
    d.rectangle([7, 38, 32, 50], fill=C("P02"))
    for k, x in enumerate(range(9, 31, 5)):
        d.rectangle([x, 41, x + 2, 48], fill=C("P59")); d.line([x + 1, 42, x + 1, 47], fill=C("P60" if (frame + k) % 4 else "P50"))
    for x in range(7, 33, 3):
        d.point((x, 44), fill=C("P03"))
    d.line([5, 56, 34, 56], fill=C("P05"))
    for x in (6, 30):
        d.ellipse([x, 56, x + 4, 60], fill=C("P02")); d.point((x + 1, 57), fill=C("P05"))
    # keyboard ledge
    d.rectangle([2, 26, 37, 31], fill=C("P06"), outline=C("P02")); d.line([3, 27, 36, 27], fill=C("P08"))
    for x in range(5, 35, 4):
        d.point((x, 29), fill=C("P09"))
    # CRT
    d.rounded_rectangle([5, 2, 34, 26], radius=3, fill=C("P08"), outline=C("P02"))
    d.line([7, 3, 32, 3], fill=C("P09"))
    d.rectangle([8, 5, 31, 21], fill=C("A1"))
    for i, y in enumerate(range(7, 19, 2)):
        d.line([10, y, 12, y], fill=C("A4"))
        d.line([14, y, 14 + (12, 8, 15, 10, 14, 0)[i], y], fill=C("A6" if i == 0 else "A5"))
    if field6:
        d.rectangle([8, 16, 31, 21], fill=C("U3")); d.rectangle([9, 17, 30, 20], fill=C("U5"))
        d.line([10, 18, 29, 18], fill=C("U7")); d.line([10, 19, 29, 19], fill=C("U6"))
    else:
        d.line([10, 19, 12, 19], fill=C("A4"))
    for y in range(6, 21, 2):
        for x in range(8, 32):
            p = img.getpixel((x, y))[:3]
            if p == Cr("A1"):
                img.putpixel((x, y), C("A0"))
    if field6:                                                   # green spill on the bezel and the keyboard ledge
        for x in range(6, 34, 2):
            img.putpixel((x, 22), C("U4"))
        for x in range(6, 34, 3):
            img.putpixel((x, 27), C("U5"))
    d.rectangle([27, 23, 31, 24], fill=C("P45"))
    d.point((9, 23), fill=C("P56" if field6 else "P55"))
    return img


def bassinet():
    """신생아 바구니 on a steel stand, still empty, a folded vault-blue blanket inside (24x26)."""
    img = Image.new("RGBA", (24, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 2, 22, 14], radius=4, fill=C("P15"), outline=C("P02"))
    d.rounded_rectangle([3, 4, 20, 12], radius=3, fill=C("P13"))
    d.rectangle([5, 6, 15, 10], fill=C("P46")); d.line([5, 6, 15, 6], fill=C("P09")); d.line([5, 10, 15, 10], fill=C("P45"))
    d.line([2, 3, 21, 3], fill=C("P09"))
    for x in (4, 18):
        d.line([x, 15, x, 23], fill=C("P05")); d.point((x, 24), fill=C("P02"))
    d.line([4, 20, 18, 20], fill=C("P06"))
    return img


def sink():
    """wall basin + small mirror on the north wall face (32x40, bottom sits on the floor line)."""
    img = Image.new("RGBA", (32, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([9, 0, 22, 12], fill=C("P07"), outline=C("P02")); d.rectangle([11, 2, 20, 10], fill=C("P14"))
    d.line([12, 3, 15, 3], fill=C("P15")); d.line([12, 4, 13, 4], fill=C("P09"))
    d.rounded_rectangle([4, 18, 27, 27], radius=3, fill=C("P09"), outline=C("P02"))
    d.ellipse([8, 19, 23, 24], fill=C("P15")); d.line([10, 20, 20, 20], fill=C("P14"))
    d.rectangle([15, 14, 16, 19], fill=C("P06")); d.point((14, 14), fill=C("P07"))
    d.rectangle([13, 28, 18, 37], fill=C("P06")); d.line([13, 28, 13, 37], fill=C("P07"))
    return img


def screen_partition():
    """3-panel folding screen (병상 가림막): steel frame, pale curtain cloth, standing on the floor (40x46)."""
    img = Image.new("RGBA", (40, 46), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k, x in enumerate((0, 13, 26)):
        dy = 2 if k == 1 else 0
        d.rectangle([x, dy, x + 13, 38 + dy], fill=C("P05"))
        d.rectangle([x + 1, dy + 2, x + 12, 36 + dy], fill=C("P15" if k != 1 else "P14"))
        for fx in range(x + 3, x + 12, 3):
            d.line([fx, dy + 3, fx, 35 + dy], fill=C("P14" if k != 1 else "P13"))
        d.line([x + 1, dy + 1, x + 12, dy + 1], fill=C("P07"))
        d.line([x + 2, 39 + dy, x + 2, 44], fill=C("P04")); d.line([x + 11, 39 + dy, x + 11, 44], fill=C("P04"))
    return img


def clinic_desk():
    """의무관 책상 2x1: steel desk, chart folders, a desk lamp and the delivery log open (64x40)."""
    img = Image.new("RGBA", (64, 42), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 10, 62, 23], fill=C("P07"), outline=C("P02")); d.line([2, 11, 61, 11], fill=C("P09"))
    d.rectangle([1, 24, 62, 30], fill=C("P06"), outline=C("P02")); d.line([2, 25, 61, 25], fill=C("P07"))
    d.rectangle([40, 25, 60, 29], fill=C("P05")); d.point((50, 27), fill=C("P08"))
    for x in (3, 58):
        d.rectangle([x, 31, x + 2, 40], fill=C("P04"))
    d.rectangle([8, 13, 22, 21], fill=C("P09"), outline=C("P06")); d.line([15, 13, 15, 21], fill=C("P06"))   # open log
    for y in (15, 17, 19):
        d.line([9, y, 13, y], fill=C("P12")); d.line([17, y, 21, y], fill=C("P12"))
    d.rectangle([26, 12, 36, 20], fill=C("P46"), outline=C("P02")); d.rectangle([28, 11, 38, 19], fill=C("P49"), outline=C("P02"))
    d.line([52, 4, 52, 16], fill=C("P05")); d.polygon([(47, 4), (57, 4), (55, 0), (49, 0)], fill=C("P45"), outline=C("P02"))
    d.rectangle([49, 16, 55, 18], fill=C("P05"))
    return img


def birth_bed(jeongin, look="calm"):
    """V-08 분만 침대 (top-down, head to the north): vault-blue tube frame, white sheet, 윤정인 lying with the
    swaddled baby on her chest under her arms; blanket with the S-07 yellow stripe. 44x84."""
    w, h = 44, 84
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # frame + mattress
    d.rectangle([2, 4, w - 3, 72], fill=C("P09"), outline=C("P02"))
    d.line([w - 4, 6, w - 4, 71], fill=C("P08")); d.line([3, 71, w - 4, 71], fill=C("P08"))
    d.rectangle([2, 72, w - 3, 77], fill=C("P08"), outline=C("P02")); d.line([3, 73, w - 4, 73], fill=C("P09"))
    d.rectangle([1, 77, w - 2, 79], fill=C("P45"), outline=C("P02"))
    for x in (3, w - 6):
        d.rectangle([x, 80, x + 2, 83], fill=C("P03"))
    d.rectangle([0, 0, w - 1, 6], fill=C("P45"), outline=C("P02")); d.line([1, 1, w - 2, 1], fill=C("P46"))   # headboard
    d.line([1, 5, w - 2, 5], fill=C("P44"))
    # pillow
    d.rounded_rectangle([7, 7, w - 8, 21], radius=3, fill=C("P09"), outline=C("P07"))
    d.line([9, 19, w - 10, 19], fill=C("P08"))
    # her head (front view crop of the map sprite), hair spread on the pillow
    head = jeongin.crop((20, 20, 44, 40))
    hx, hy = (w - 24) // 2, 4
    hair = [p for p in [(x, y) for y in range(20) for x in range(24)] if head.getpixel(p)[3]]
    img.alpha_composite(head, (hx, hy))
    for k, (x0, y0, x1, y1) in enumerate(((hx + 2, 14, hx - 1, 22), (hx + 21, 14, hx + 24, 22), (hx + 3, 16, hx + 1, 23),
                                          (hx + 20, 16, hx + 22, 23))):
        d.line([x0, y0, x1, y1], fill=C("H1.2" if k % 2 else "H1.1"))
    # blanket from the chest down
    d.rectangle([3, 26, w - 4, 70], fill=C("P45"))
    d.line([3, 26, w - 4, 26], fill=C("P09")); d.line([3, 27, w - 4, 27], fill=C("P08")); d.line([3, 28, w - 4, 28], fill=C("P46"))
    d.line([w - 5, 29, w - 5, 70], fill=C("P44"))
    d.rectangle([3, 60, w - 4, 62], fill=C("P48")); d.line([3, 60, w - 4, 60], fill=C("P49"))
    for x0, y0, x1, y1 in ((14, 44, 12, 58), (28, 46, 30, 58), (21, 52, 21, 68)):
        d.line([x0, y0, x1, y1], fill=C("P44")); d.line([x0 - 1, y0, x1 - 1, y1], fill=C("P46"))
    d.line([2, 26, 2, 70], fill=C("P02")); d.line([w - 3, 26, w - 3, 70], fill=C("P02"))
    # gown shoulders over the blanket edge + arms round the baby
    for x0 in (7, w - 15):
        d.rectangle([x0, 23, x0 + 7, 29], fill=C("P14"), outline=C("P12"))
    d.line([7, 24, 13, 24], fill=C("P15"))
    # baby: swaddle bundle on her chest, face toward her
    bx, by = w // 2, 33
    d.ellipse([bx - 8, by - 6, bx + 8, by + 7], fill=C("P09"), outline=C("P06"))
    d.arc([bx - 8, by - 6, bx + 8, by + 7], 20, 120, fill=C("P07"))
    d.line([bx - 6, by + 4, bx + 6, by + 2], fill=C("P46"))
    d.ellipse([bx - 4, by - 5, bx + 3, by + 1], fill=C("S1.4"), outline=C("S1.2"))
    d.point((bx - 2, by - 2), fill=C("S1.1")); d.point((bx + 1, by - 2), fill=C("S1.1"))
    d.point((bx - 1, by), fill=C("S1.2"))
    d.arc([bx - 5, by - 7, bx + 4, by - 1], 180, 360, fill=C("P08"))
    # her forearms over the bundle (sleeve + hand)
    d.line([8, 30, bx - 5, by + 5], fill=C("P14")); d.line([8, 31, bx - 5, by + 6], fill=C("P12"))
    d.line([w - 9, 30, bx + 6, by + 4], fill=C("P14")); d.line([w - 9, 31, bx + 6, by + 5], fill=C("P12"))
    d.rectangle([bx - 6, by + 4, bx - 4, by + 6], fill=C("S2.4")); d.point((bx - 6, by + 6), fill=C("S2.2"))
    d.rectangle([bx + 5, by + 3, bx + 7, by + 5], fill=C("S2.4")); d.point((bx + 7, by + 5), fill=C("S2.2"))
    return img


# ------------------------------------------------------------------------------------------------ actors
_cache = {}


def sprite(code, view):
    if code not in _cache:
        _cache[code] = NP.build(code)
    return _cache[code]["idle"][view]


def place(img, spr, fx, fy):
    """feet point (fx, fy) = sprite (32, 60); 2px contact shadow ellipse first."""
    px = img.load()
    for dx in range(-7, 8):
        for dy in (-1, 0, 1):
            if (dx / 7.5) ** 2 + (dy / 1.6) ** 2 <= 1:
                tok = RGB2TOK.get(px[fx + dx, fy + dy][:3])
                if tok:
                    px[fx + dx, fy + dy] = C(S.shadow_px(tok))
    img.alpha_composite(spr, (fx - 32, fy - 60))


def balloon(img, x, y, kind, frame=0):
    """쯔꾸르식 감정 말풍선 16x14 over a head: '!' surprise, '…' silence, '♥' love, '삑' beep."""
    b = Image.new("RGBA", (20 if kind == "삑" else 16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    bw = b.width
    d.rounded_rectangle([0, 0, bw - 1, 11], radius=4, fill=C("P09"), outline=C("P01"))
    d.polygon([(5, 11), (9, 11), (6, 15)], fill=C("P09")); d.line([(5, 12), (6, 15), (9, 11)], fill=C("P01"))
    if kind == "!":
        d.rectangle([7, 2, 8, 6], fill=C("P53")); d.rectangle([7, 8, 8, 9], fill=C("P53"))
    elif kind == "…":
        for dx in (4, 7, 10):
            d.point((dx, 6), fill=C("P02")); d.point((dx + 1, 6), fill=C("P02"))
    elif kind == "♥":
        d.polygon([(4, 4), (6, 2), (8, 4), (10, 2), (12, 4), (12, 5), (8, 9), (4, 5)], fill=C("P54"))
        d.point((5, 4), fill=C("P09"))
    elif kind == "삑":
        d.fontmode = "1"
        d.text((3, 0), "삑", font=F9, fill=C("P61"))
    img.alpha_composite(b, (x - bw // 2, y - 16 - (1 if frame % 2 else 0)))


def portrait_of(who):
    if who == "윤정인":
        p = dict(skin="S2", hair="HR06", hair_color="H1", female=True, tired=True, torso="GOWN", jaw=0.15, age=23,
                 mole=(57, 52))                                      # 환자복 얼굴 그림 (병상 장면 전용 의상)
    elif who == "신혜령":
        p = PT.from_code(HYERYEONG, dict(mole=(55, 47)))
        p["age"] = 34
    else:
        p = PT.from_code(GEUMRYE, {})
        p["age"] = 45
    return p


def dialogue(img, who, title, text, expr="기본", reveal=None):
    """the game's dialogue window (SD-12 §6.1, as 18_ui_dialogue): 85% black box, face 96x96, name tag."""
    box = Image.new("RGBA", (608, 104), Cr("P01") + (217,))
    ImageDraw.Draw(box).rectangle([0, 0, 607, 103], outline=Cr("P07") + (255,))
    img.alpha_composite(box, (16, 248))
    face = PT.portrait(portrait_of(who), expr)
    plate_ = Image.new("RGBA", (96, 96), Cr("P44") + (255,))
    plate_.alpha_composite(face)
    img.alpha_composite(plate_, (24, 252))
    tag = Image.new("RGBA", (int(len(who + title) * 12 + 30), 16), Cr("P01") + (217,))
    img.alpha_composite(tag, (124, 230))
    d = ImageDraw.Draw(img); d.fontmode = "1"
    d.rectangle([24, 252, 119, 347], outline=C("P05"))
    d.text((130, 231), f"{who} ({title})", font=F12B, fill=C("P09"))
    lines = text.split("\n")
    shown = sum(len(l) for l in lines) if reveal is None else reveal
    for i, s in enumerate(lines):
        part = s[:max(0, shown)]
        shown -= len(s)
        d.text((128, 258 + i * 18), part, font=F12, fill=C("P09"))
    if reveal is None:
        d.polygon([(604, 338), (612, 338), (608, 344)], fill=C("P48"))


def whiteout(img, dens):
    """fade from white: ordered dither toward P09 (dens 1 = all white)."""
    px = img.load()
    for y in range(H):
        for x in range(W):
            b = BAYER[y % 4][x % 4] / 16
            if b < dens:
                px[x, y] = C("P09")
            elif b < dens + 0.12:
                px[x, y] = C("P15") if dens > 0.05 else px[x, y]


# ------------------------------------------------------------------------------------------------ shot
BED = (8 * T + 10, 3 * T + 12)                  # top-left of the bed (head against the north wall)
CART = (11 * T + 2, 3 * T + 6)
HR_FEET = (7 * T + 14, 5 * T + 6)               # 신혜령 left of the bed
GR_FEET = (12 * T + 26, 5 * T + 10)             # 방금례 at the cart's south-east corner, typing (NW)


def frame(state):
    """state: dict(field6, geumrye_view, balloons{who:kind}, tick)"""
    img = base.copy()
    t = state.get("tick", 0)
    props = [
        (iv_stand(), 7 * T + 22, 3 * T - 30),
        (birth_bed(sprite(JEONGIN, "S")), *BED),
        (terminal_cart(state.get("field6", False), t), *CART),
    ]
    actors = [
        (sprite(HYERYEONG, state.get("hr_view", "E")), *HR_FEET),
        (sprite(GEUMRYE, state.get("gr_view", "NW")), *GR_FEET),
    ]
    items = [("p", im, x, y, y + im.height) for im, x, y in props] + [("a", im, x, y, y) for im, x, y in actors]
    items.sort(key=lambda it: it[4])
    for kind, im, x, y, _ in items:
        if kind == "p":
            contact_shadow(img, x + 2, x + im.width - 2, y + im.height, 2)
            img.alpha_composite(im, (x, y))
        else:
            place(img, im, x, y)
    bl = state.get("balloons", {})
    if "신혜령" in bl:
        balloon(img, HR_FEET[0] + 2, HR_FEET[1] - 46, bl["신혜령"], t)
    if "방금례" in bl:
        balloon(img, GR_FEET[0] + 2, GR_FEET[1] - 46, bl["방금례"], t)
    if "윤정인" in bl:
        balloon(img, BED[0] + 22, BED[1] + 2, bl["윤정인"], t)
    if "단말" in bl:
        balloon(img, CART[0] + 20, CART[1] - 1, bl["단말"], t)
    if state.get("say"):
        dialogue(img, *state["say"], reveal=state.get("reveal"))
    return img


def static_props(img):
    """wall cabinets, exam bed, sink-side shelf: things that never change during the shot."""
    items = [(S.med_cabinet(), 3 * T, 3 * T - 50), (S.med_cabinet(), 4 * T, 3 * T - 50),
             (sink(), 6 * T, 3 * T - 34),
             (S.exam_bed(), 15 * T + 4, 4 * T + 2), (screen_partition(), 14 * T + 4, 3 * T - 12),
             (clinic_desk(), 3 * T, 6 * T + 2), (S.stool(), 4 * T + 8, 7 * T + 10),
             (bassinet(), 10 * T - 6, 5 * T + 4)]
    items.sort(key=lambda it: it[2] + it[0].height)
    for im, x, y in items:
        contact_shadow(img, x + 2, x + im.width - 2, y + im.height, 2)
        img.alpha_composite(im, (x, y))
    img.alpha_composite(bobblehead(), (4 * T + 12, 3 * T - 61))


base = None


def shots():
    """(state, duration ms) list for the GIF."""
    seq = []
    calm = dict(gr_view="NW", hr_view="E")
    for k in range(8):
        seq.append((dict(calm, tick=k, white=1 - k / 7), 90))
    line = ("신혜령", "의무관", "건강해요. 울음소리 좋네.", "미소")
    seq.append((dict(calm, say=line, reveal=6), 120))
    seq.append((dict(calm, say=line), 1700))
    for k in range(4):                                         # 삑 두 번: field 6 lamp blinks green
        seq.append((dict(calm, tick=k, field6=k % 2 == 0, balloons={"단말": "삑"} if k % 2 == 0 else {}), 260))
    seq.append((dict(calm, field6=True, balloons={"방금례": "!", "신혜령": "…"}), 700))
    turned = dict(gr_view="W", hr_view="E", field6=True)
    line = ("방금례", "행정실 서기", "회선 확인 칸에 불 들어오는 거, 처음 봐요.\n이 칸은… 내가 서기 된 뒤로 한 번도 대답한 적이 없는데.", "놀람")
    seq.append((dict(turned, say=line, reveal=12), 120))
    seq.append((dict(turned, say=line, reveal=30), 120))
    seq.append((dict(turned, say=line), 2600))
    line = ("윤정인", "오버시어", "200년 된 기계예요. 서류 넣어 주세요.", "기본")
    seq.append((dict(turned, say=line), 2000))
    line = ("윤정인", "오버시어", "여기서 태어났으니까 여기서 잘 살면 돼.\n엄마가 지킬게.", "미소")
    seq.append((dict(turned, gr_view="NW", balloons={"윤정인": "♥"}, say=line), 2800))
    return seq


def render(state):
    im = frame(state)
    if state.get("white"):
        whiteout(im, state["white"])
    return im


def main():
    global base
    base = room()
    static_props(base)
    out = os.path.join(ROOT, "samples")
    allowed = P.allowed_set("UI", *P.SKIN.keys(), *P.HAIR.keys(), *P.PF.keys())
    key = render(dict(gr_view="W", hr_view="E", field6=True, balloons={"방금례": "!", "신혜령": "…"},
                      say=("방금례", "행정실 서기", "회선 확인 칸에 불 들어오는 거, 처음 봐요.\n이 칸은… 내가 서기 된 뒤로 한 번도 대답한 적이 없는데.", "놀람")))
    key.convert("RGB").save(os.path.join(out, "21_scene_birth.png"))
    upscale(key, 2).convert("RGB").save(os.path.join(out, "21_scene_birth_x2.png"))
    bad = check(render(dict(gr_view="W", hr_view="E", field6=True, balloons={"방금례": "!", "신혜령": "…"})), allowed)
    frames, durs = [], []
    for st, ms in shots():
        im = render(st)
        if not st.get("say"):
            bad += check(im, allowed)
        frames.append(upscale(im, 2).convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=255))
        durs.append(ms)
    frames[0].save(os.path.join(out, "21_scene_birth.gif"), save_all=True, append_images=frames[1:], duration=durs, loop=0)
    print("scene off-palette:", sorted(set(bad)) or 0, "| frames:", len(frames), "(dialogue window: 85% UI layer)")


if __name__ == "__main__":
    main()
