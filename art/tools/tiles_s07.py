"""TS-I01 Vault S-07 interior, first pass (SD-16 §6.3 볼트 내부, §6.5 실내 벽 2타일, §12.3 #2).
Look: vault blue/yellow + metal grey, even white ceiling light, short contact shadows (SD-16 §2.6 table).
Every function returns an RGBA image whose size is a multiple of 32 (props include their top face + south face).
Writes samples/10_tiles_s07(.png, _x3)."""
import os, sys, math, random
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import upscale

ROOT = os.path.dirname(os.path.dirname(__file__))
T = 32
F7 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri7.ttf"), 8)
F9 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
F11B = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri11-Bold.ttf"), 12)


def C(t):
    return P.rgb(t) + (255,)


def new(w=1, h=1, fill=None):
    return Image.new("RGBA", (w * T, h * T), C(fill) if fill else (0, 0, 0, 0))


def text(d, xy, s, font, tok, anchor="la"):
    d.fontmode = "1"
    d.text(xy, s, font=font, fill=C(tok), anchor=anchor)


# ---------------------------------------------------------------- floors
def grate(seed=0):
    """철제 격자 바닥: 32px plate = 2x2 panels of slotted grating, bolted frame."""
    img = new(fill="P04")
    d = ImageDraw.Draw(img)
    for py in (0, 16):
        for px in (0, 16):
            d.rectangle([px, py, px + 15, py + 15], fill=C("P05"))
            d.line([px, py, px + 15, py], fill=C("P06"))          # lit north/west frame edge
            d.line([px, py, px, py + 15], fill=C("P06"))
            d.line([px, py + 15, px + 15, py + 15], fill=C("P04"))
            d.line([px + 15, py, px + 15, py + 15], fill=C("P04"))
            horiz = ((px + py) // 16 + seed) % 2 == 0
            for k in range(4, 13, 4):                            # slots alternate direction per panel
                if horiz:
                    d.line([px + 3, py + k, px + 12, py + k], fill=C("P03"))
                    d.line([px + 3, py + k + 1, px + 12, py + k + 1], fill=C("P06"))
                else:
                    d.line([px + k, py + 3, px + k, py + 12], fill=C("P03"))
                    d.line([px + k + 1, py + 3, px + k + 1, py + 12], fill=C("P06"))
    for x, y in ((1, 1), (30, 1), (1, 30), (30, 30)):
        img.putpixel((x, y), C("P07"))
    if seed % 3 == 2:                                             # worn: one rust-stained slot run
        for k in range(4, 12):
            img.putpixel((16 + k, 22), C("P24"))
    return img


def panel_floor(seed=0, sheen=False):
    """광택 패널 바닥 (아트리움 중앙·행정동): pale blue-grey panels, crisp seams."""
    img = new(fill="P14")
    d = ImageDraw.Draw(img)
    d.line([0, 0, 31, 0], fill=C("P13")); d.line([0, 0, 0, 31], fill=C("P13"))
    d.line([0, 16, 31, 16], fill=C("P13"))
    d.line([1, 1, 31, 1], fill=C("P15")); d.line([1, 17, 31, 17], fill=C("P15"))
    if sheen:                                                     # ceiling-light reflection streak
        for i in range(0, 10):
            d.point((8 + i, 26 - i), fill=C("P15"))
            d.point((9 + i, 26 - i), fill=C("P15"))
    if seed % 4 == 3:
        d.point([(23, 9), (24, 9)], fill=C("P13"))               # scuff
    return img


def guide_line(axis="h"):
    """바닥 안내선: vault-yellow 4px line over panel floor."""
    img = panel_floor()
    d = ImageDraw.Draw(img)
    if axis == "h":
        d.rectangle([0, 14, 31, 17], fill=C("P48")); d.line([0, 14, 31, 14], fill=C("P49")); d.line([0, 17, 31, 17], fill=C("P47"))
    else:
        d.rectangle([14, 0, 17, 31], fill=C("P48")); d.line([14, 0, 14, 31], fill=C("P49")); d.line([17, 0, 17, 31], fill=C("P47"))
    return img


def lino(seed=0):
    """교실 리놀륨: warm grey-green sheet with 16px tile seams (classrooms, dormitory)."""
    img = new(fill="P07")
    d = ImageDraw.Draw(img)
    for k in (0, 16):
        d.line([0, k, 31, k], fill=C("P06")); d.line([k, 0, k, 31], fill=C("P06"))
    for k in (1, 17):
        d.line([1, k, 15, k], fill=C("P08")); d.line([17, k, 31, k], fill=C("P08"))
    if seed % 3 == 1:
        d.point([(6, 9), (7, 9), (24, 25)], fill=C("P06"))
    return img


def clinic_tile(seed=0):
    """진료소 흰 타일: 8px ceramic grid."""
    img = new(fill="P09")
    d = ImageDraw.Draw(img)
    for k in range(0, 32, 8):
        d.line([0, k, 31, k], fill=C("P08")); d.line([k, 0, k, 31], fill=C("P08"))
    if seed % 4 == 2:
        d.rectangle([9, 17, 14, 22], fill=C("P15"))               # replaced tile, slightly bluer
    return img


# ---------------------------------------------------------------- walls
def wall_face(part, variant="plain", seed=0):
    """North wall face, 2 tiles high: part 'top' (upper panel) / 'bot' (yellow band + kick plate)."""
    img = new(fill="P13")
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    # vertical panel seams every 16px; west edge of each panel catches the light
    for x in (0, 16):
        d.line([x, 0, x, 31], fill=C("P12"))
        d.line([x + 1, 0, x + 1, 31], fill=C("P14"))
    if part == "top":
        d.line([0, 0, 31, 0], fill=C("P11"))                      # ceiling shadow under the wall top
        d.line([0, 1, 31, 1], fill=C("P12"))
        for x in (3, 13, 19, 29):
            d.point((x, 4), fill=C("P15"))                        # rivets
        if variant == "pipe":                                     # service pipe run along the top
            d.rectangle([0, 6, 31, 9], fill=C("P05")); d.line([0, 6, 31, 6], fill=C("P07"))
            d.line([0, 9, 31, 9], fill=C("P03"))
            for x in (8, 24):
                d.rectangle([x, 5, x + 1, 10], fill=C("P04"))
        if variant == "vent":
            d.rectangle([8, 10, 23, 21], fill=C("P11"))
            d.rectangle([8, 10, 23, 10], fill=C("P14"))
            for y in range(12, 21, 2):
                d.line([9, y, 22, y], fill=C("P02"))
    else:
        # yellow band (황 띠) at y 4..9, kick plate below, baseboard
        d.rectangle([0, 4, 31, 9], fill=C("P48"))
        d.line([0, 4, 31, 4], fill=C("P49")); d.line([0, 9, 31, 9], fill=C("P47"))
        d.rectangle([0, 10, 31, 29], fill=C("P12"))
        d.line([0, 10, 31, 10], fill=C("P11"))
        for x in (0, 16):
            d.line([x, 10, x, 29], fill=C("P11")); d.line([x + 1, 11, x + 1, 29], fill=C("P13"))
        for x in (5, 21):
            d.point((x, 13), fill=C("P14"))
        d.rectangle([0, 30, 31, 31], fill=C("P11"))
        d.line([0, 30, 31, 30], fill=C("P10"))
        if variant == "outlet":
            d.rectangle([20, 18, 25, 23], fill=C("P08")); d.point([(22, 20), (23, 20)], fill=C("P03"))
            d.rectangle([20, 18, 25, 18], fill=C("P09"))
    return img


def wall_top(edges):
    """벽 윗면 (dark ceiling void). edges = set of 'n','s','e','w' sides that border open floor/face."""
    img = new(fill="P10")
    d = ImageDraw.Draw(img)
    if "s" in edges:
        d.line([0, 31, 31, 31], fill=C("P13")); d.line([0, 30, 31, 30], fill=C("P11"))
    if "n" in edges:
        d.line([0, 0, 31, 0], fill=C("P13")); d.line([0, 1, 31, 1], fill=C("P11"))
    if "w" in edges:
        d.line([0, 0, 0, 31], fill=C("P13")); d.line([1, 0, 1, 31], fill=C("P11"))
    if "e" in edges:
        d.line([31, 0, 31, 31], fill=C("P13")); d.line([30, 0, 30, 31], fill=C("P11"))
    return img


def balcony_band(seed=0, door=False, num=None):
    """Atrium 3rd wall tile: upper-floor corridor seen above, railing in front (3층 높이 표현)."""
    img = new(fill="P12")
    d = ImageDraw.Draw(img)
    d.line([0, 0, 31, 0], fill=C("P11"))
    d.rectangle([0, 1, 31, 15], fill=C("P12"))                    # upper corridor wall (in shade)
    d.line([0, 9, 31, 9], fill=C("P47"))                          # its yellow band, dim
    if door:
        d.rectangle([8, 2, 23, 15], fill=C("P10"))
        d.line([8, 2, 23, 2], fill=C("P11"))
        if num:
            text(d, (16, 3), num, F7, "P08", anchor="ma")
    d.rectangle([0, 16, 31, 17], fill=C("P05"))                   # walkway slab edge
    d.line([0, 16, 31, 16], fill=C("P07"))
    d.rectangle([0, 18, 31, 31], fill=C("P13"))                   # slab face below the walkway
    d.line([0, 18, 31, 18], fill=C("P11"))
    d.line([0, 28, 31, 28], fill=C("P12"))
    # railing: posts + two rails in front of the corridor
    for x in (2, 18):
        d.rectangle([x, 4, x + 1, 15], fill=C("P15")); d.point((x + 1, 15), fill=C("P07"))
    d.line([0, 5, 31, 5], fill=C("P15")); d.line([0, 6, 31, 6], fill=C("P07"))
    d.line([0, 11, 31, 11], fill=C("P14"))
    return img


def door_slide(state="closed", label=None):
    """Sliding pressure door in a north wall face: 1 tile wide x 2 high (64px)."""
    img = Image.new("RGBA", (T, 2 * T), C("P13"))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 4, 29, 63], fill=C("P11"))                    # frame
    d.line([2, 4, 29, 4], fill=C("P14")); d.line([2, 4, 2, 63], fill=C("P14"))
    d.rectangle([2, 0, 29, 3], fill=C("P48")); d.line([2, 0, 29, 0], fill=C("P49")); d.line([2, 3, 29, 3], fill=C("P47"))
    if state == "closed":
        d.rectangle([4, 6, 27, 63], fill=C("P45"))
        d.line([4, 6, 4, 63], fill=C("P46")); d.line([27, 6, 27, 63], fill=C("P44"))
        d.line([15, 6, 15, 63], fill=C("P43")); d.line([16, 6, 16, 63], fill=C("P46"))
        d.rectangle([6, 24, 13, 27], fill=C("P44")); d.rectangle([18, 24, 25, 27], fill=C("P44"))
        d.rectangle([4, 50, 27, 53], fill=C("P48"))               # hazard kick band
        for x in range(4, 28, 4):
            d.polygon([(x, 53), (x + 2, 50), (x + 3, 50), (x + 1, 53)], fill=C("P02"))
    else:
        d.rectangle([4, 6, 27, 63], fill=C("P10"))
        d.rectangle([4, 6, 6, 63], fill=C("P45")); d.rectangle([25, 6, 27, 63], fill=C("P45"))
        d.rectangle([7, 56, 24, 63], fill=C("P11"))
    d.rectangle([28, 30, 30, 36], fill=C("P05")); d.point((29, 32), fill=C("P55"))   # panel with green lamp
    if label:
        d.rectangle([5, 8, 26, 16], fill=C("P09")); d.rectangle([5, 8, 26, 8], fill=C("P08"))
        text(d, (16, 9), label, F7, "P43", anchor="ma")
    return img


# ---------------------------------------------------------------- wall-mounted props
def slogan_crt(msg, tiles=2):
    """표어 화면: CRT in a cream housing, green phosphor text (U palette), on the wall's upper tile."""
    w = tiles * T
    img = Image.new("RGBA", (w, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, 23], radius=3, fill=C("P08"), outline=C("P03"))
    d.line([2, 1, w - 3, 1], fill=C("P09"))
    d.rectangle([3, 3, w - 4, 18], fill=C("U1"))
    d.rectangle([3, 3, w - 4, 3], fill=C("U2"))
    for y in range(5, 18, 2):
        d.line([4, y, w - 5, y], fill=C("U0"))                    # scanlines
    text(d, (w // 2, 6), msg, F7, "U6", anchor="ma")
    d.rectangle([4, 20, 9, 21], fill=C("P06")); d.point((w - 7, 20), fill=C("P55"))
    d.line([w // 2 - 3, 23, w // 2 + 3, 23], fill=C("P04"))      # mount
    return img


def rank_board(seed=7):
    """성적 순위 게시판 (S-07 anchor): 6x2 tiles. Metal frame, printed ranking sheets, two hundred years of
    names pinned around the edge on yellowed slips."""
    w, h = 6 * T, 2 * T - 8
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    d.rectangle([0, 0, w - 1, h - 1], fill=C("P05"), outline=C("P02"))
    d.line([1, 1, w - 2, 1], fill=C("P07")); d.line([1, 1, 1, h - 2], fill=C("P07"))
    d.rectangle([6, 4, w - 7, 15], fill=C("P44"))                 # header plate
    d.line([6, 4, w - 7, 4], fill=C("P46"))
    text(d, (w // 2, 5), "제2277학년도 성적 순위", F7, "P09", anchor="ma")
    # three printed sheets with rank rows
    for k in range(3):
        sx = 10 + k * 58
        d.rectangle([sx, 19, sx + 51, h - 6], fill=C("P09"))
        d.line([sx + 52, 20, sx + 52, h - 5], fill=C("P03"))      # sheet shadow
        d.line([sx, h - 5, sx + 51, h - 5], fill=C("P03"))
        for r, y in enumerate(range(22, h - 8, 3)):
            n = k * 9 + r + 1
            d.line([sx + 2, y, sx + 4, y], fill=C("P46" if n > 3 else "P48"))
            ln = rnd.randint(16, 34)
            d.line([sx + 7, y, sx + 7 + ln, y], fill=C("P03"))
            d.line([sx + 44, y, sx + 48, y], fill=C("P06"))
            if n <= 3:
                d.point((sx + 50, y), fill=C("P49"))
        d.point((sx + 25, 20), fill=C("P53"))                    # pin
    # old slips added over the generations: overlapping the frame edges
    for _ in range(26):
        side = rnd.choice(("t", "b", "l", "r"))
        if side in "tb":
            x = rnd.randint(-3, w - 10); y = -6 if side == "t" else h - 6
        else:
            x = -4 if side == "l" else w - 8; y = rnd.randint(0, h - 9)
        sw, sh = rnd.randint(8, 13), rnd.randint(6, 9)
        col = rnd.choice(("P08", "P22", "P21", "P09"))
        d.rectangle([x, y, x + sw, y + sh], fill=C(col), outline=C("P19" if col != "P09" else "P07"))
        for yy in range(y + 2, y + sh - 1, 2):
            d.line([x + 2, yy, x + sw - 3, yy], fill=C("P18" if col != "P09" else "P06"))
        d.point((x + sw // 2, y + 1), fill=C(rnd.choice(("P53", "P45", "P49"))))
    return img


def wall_clock(hour=10, minute=12):
    """적성 평가실의 멈추지 않은 벽시계 (16x16)."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 15, 15], fill=C("P09"), outline=C("P02"))
    d.arc([1, 1, 14, 14], 180, 270, fill=C("P04"))
    for a in range(0, 360, 90):
        x = 7.5 + 5.5 * math.sin(math.radians(a)); y = 7.5 - 5.5 * math.cos(math.radians(a))
        d.point((round(x), round(y)), fill=C("P03"))
    ha = math.radians((hour % 12 + minute / 60) * 30); ma = math.radians(minute * 6)
    d.line([7.5, 7.5, 7.5 + 3.5 * math.sin(ha), 7.5 - 3.5 * math.cos(ha)], fill=C("P02"))
    d.line([7.5, 7.5, 7.5 + 5.5 * math.sin(ma), 7.5 - 5.5 * math.cos(ma)], fill=C("P02"))
    d.point((8, 8), fill=C("P53"))
    return img


def blackboard():
    """교실 칠판 4x1.5 tiles (green board, chalk ledge, a half-erased timetable)."""
    w, h = 4 * T, 40
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 5], fill=C("P29"), outline=C("P17"))
    d.line([1, 1, w - 2, 1], fill=C("P18"))
    d.rectangle([2, 2, w - 3, h - 7], fill=C("P29"))
    for y in range(4, h - 8, 3):
        d.line([4, y, 4 + (y * 7) % 40 + 20, y], fill=C("P30"))   # erased smudges (rows, not noise)
    text(d, (8, 5), "적성 평가", F7, "P08")
    text(d, (8, 15), "1교시 09:00", F7, "P32")
    d.line([70, 8, 118, 8], fill=C("P08")); d.line([70, 12, 104, 12], fill=C("P32"))
    d.rectangle([0, h - 5, w - 1, h - 3], fill=C("P18")); d.line([0, h - 5, w - 1, h - 5], fill=C("P20"))
    d.rectangle([20, h - 7, 23, h - 6], fill=C("P09")); d.rectangle([90, h - 7, 92, h - 6], fill=C("P54"))
    d.line([0, h - 2, w - 1, h - 2], fill=C("P11"))
    return img


def ration_window():
    """배급소 창구: wall opening with half-raised shutter and counter, 2x2 tiles (sits on wall face)."""
    img = Image.new("RGBA", (2 * T, 2 * T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 10, 59, 50], fill=C("P11"), outline=C("P02"))
    d.rectangle([6, 12, 57, 30], fill=C("P06"))                   # shutter slats
    for y in range(13, 30, 3):
        d.line([6, y, 57, y], fill=C("P05")); d.line([6, y + 1, 57, y + 1], fill=C("P07"))
    d.rectangle([6, 31, 57, 44], fill=C("P02"))                   # dark interior
    d.rectangle([12, 36, 17, 44], fill=C("P05")); d.rectangle([40, 38, 47, 44], fill=C("P21"))   # shelf goods
    d.rectangle([2, 45, 61, 49], fill=C("P07")); d.line([2, 45, 61, 45], fill=C("P09"))
    d.line([2, 49, 61, 49], fill=C("P04"))
    d.rectangle([14, 1, 49, 8], fill=C("P44")); d.line([14, 1, 49, 1], fill=C("P46"))
    text(d, (32, 1), "배급과", F7, "P09", anchor="ma")
    return img


def emblem():
    """한결건설 방패 + S-07 plate (wall, 24x28)."""
    img = Image.new("RGBA", (32, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(1, 1), (30, 1), (30, 19), (15, 34), (1, 19)], fill=C("P44"), outline=C("P02"))
    d.line([2, 2, 29, 2], fill=C("P46")); d.line([2, 2, 2, 18], fill=C("P46"))
    d.rectangle([3, 9, 28, 18], fill=C("P48")); d.line([3, 9, 28, 9], fill=C("P49"))
    text(d, (16, 10), "S-07", F7, "P43", anchor="ma")
    d.line([10, 23, 21, 23], fill=C("P48")); d.line([12, 26, 19, 26], fill=C("P48"))   # 한결 three-line mark
    return img


# ---------------------------------------------------------------- floor props (top face + south face)
def water_cooler():
    """음수대: cream SJ-style cabinet with a blue bottle (1 tile, stands against a wall)."""
    img = Image.new("RGBA", (T, 50), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([9, 0, 22, 8], fill=C("P46"), outline=C("P02"))
    d.rectangle([9, 4, 22, 17], fill=C("P45"), outline=C("P02"))
    d.line([11, 6, 11, 15], fill=C("P46"))
    d.rectangle([6, 18, 25, 49], fill=C("P08"), outline=C("P02"))
    d.line([7, 19, 24, 19], fill=C("P09"))
    d.rectangle([10, 24, 21, 30], fill=C("P05")); d.rectangle([14, 25, 17, 26], fill=C("P15"))
    d.point((19, 22), fill=C("P53")); d.point((12, 22), fill=C("P45"))
    d.rectangle([9, 38, 22, 46], fill=C("P07"))
    return img


def shadow_px(base_tok):
    return {"P15": "P14", "P14": "P13", "P13": "P12", "P09": "P08", "P08": "P07", "P07": "P06", "P06": "P05",
            "P05": "P04", "P04": "P03", "P03": "P02", "P48": "P47", "P49": "P48", "P02": "P01"}.get(base_tok, base_tok)


def canteen_table(tiles=4):
    """공동 식당 장탁: laminate top (half-depth), steel apron, legs."""
    w = tiles * T
    img = Image.new("RGBA", (w, T + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 6, w - 2, 21], fill=C("P08"), outline=C("P03"))     # top face
    d.line([2, 7, w - 3, 7], fill=C("P09"))
    for x in range(18, w - 4, 32):
        d.rectangle([x, 11, x + 9, 16], fill=C("P07"))                   # trays
        d.rectangle([x + 1, 12, x + 4, 15], fill=C("P21"))
        d.point((x + 7, 13), fill=C("P54"))
    d.rectangle([1, 22, w - 2, 26], fill=C("P06"), outline=C("P03"))    # apron
    d.line([2, 23, w - 3, 23], fill=C("P07"))
    for x in (4, w - 7):
        d.rectangle([x, 27, x + 2, 36], fill=C("P04")); d.line([x, 27, x, 36], fill=C("P05"))
    return img


def stool():
    img = Image.new("RGBA", (16, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 1, 13, 7], fill=C("P45"), outline=C("P02"))
    d.line([4, 2, 10, 2], fill=C("P46"))
    d.rectangle([7, 8, 8, 15], fill=C("P05")); d.line([3, 16, 12, 16], fill=C("P04"))
    return img


def exam_desk(occupied=False):
    """적성 평가 책상 (1 tile): desk with a 세진 card reader (amber valve window), chair to the south."""
    img = Image.new("RGBA", (T, T + 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 8, 29, 17], fill=C("P20"), outline=C("P03"))        # wood-laminate top
    d.line([3, 9, 28, 9], fill=C("P21"))
    d.rectangle([4, 3, 15, 10], fill=C("P08"), outline=C("P03"))        # card reader (cream SJ housing)
    d.line([5, 4, 14, 4], fill=C("P09"))
    d.rectangle([6, 6, 9, 8], fill=C("P59")); d.point((7, 6), fill=C("P60"))
    d.line([11, 7, 14, 7], fill=C("P02"))                                # card slot
    d.rectangle([19, 11, 25, 15], fill=C("P09"), outline=C("P07"))      # answer card
    d.rectangle([2, 18, 29, 22], fill=C("P18"), outline=C("P03"))
    d.rectangle([4, 23, 5, 30], fill=C("P04")); d.rectangle([26, 23, 27, 30], fill=C("P04"))
    # chair (seen from behind: student faces north)
    d.rectangle([9, 26, 22, 34], fill=C("P45"), outline=C("P02"))
    d.line([10, 27, 21, 27], fill=C("P46"))
    d.rectangle([10, 35, 11, 41], fill=C("P04")); d.rectangle([20, 35, 21, 41], fill=C("P04"))
    return img


def teacher_desk():
    """평가관 교탁 2x1."""
    w = 2 * T
    img = Image.new("RGBA", (w, T + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 6, w - 2, 17], fill=C("P05"), outline=C("P02"))
    d.line([2, 7, w - 3, 7], fill=C("P07"))
    d.rectangle([6, 2, 21, 10], fill=C("P09"), outline=C("P06"))        # stacked answer cards
    d.line([7, 4, 20, 4], fill=C("P07")); d.line([7, 6, 20, 6], fill=C("P07"))
    d.rectangle([38, 4, 55, 12], fill=C("P08"), outline=C("P03"))      # 등사기 (mimeograph)
    d.ellipse([41, 5, 48, 11], fill=C("P04")); d.point((44, 8), fill=C("P07"))
    d.rectangle([1, 18, w - 2, 36], fill=C("P12"), outline=C("P02"))   # modesty panel
    d.line([2, 19, w - 3, 19], fill=C("P13"))
    d.rectangle([24, 24, 39, 30], fill=C("P44")); text(ImageDraw.Draw(img), (32, 23), "평가", F7, "P09", anchor="ma")
    return img


def bunk(two=True):
    """거주동 2인실 침대 (1x2 tiles, head to the north)."""
    img = Image.new("RGBA", (T, 2 * T + 6), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 4, 29, 61], fill=C("P05"), outline=C("P02"))       # frame top
    d.rectangle([4, 6, 27, 57], fill=C("P09"))                          # sheet
    d.rectangle([6, 8, 25, 15], fill=C("P08"), outline=C("P07"))       # pillow
    d.rectangle([4, 26, 27, 57], fill=C("P45"))                         # vault-blue blanket
    d.line([4, 26, 27, 26], fill=C("P46")); d.line([4, 27, 27, 27], fill=C("P09"))
    for y in (36, 46):
        d.line([5, y, 26, y], fill=C("P44"))
    d.rectangle([2, 62, 29, 67], fill=C("P04"), outline=C("P02"))       # south face of the frame
    d.line([3, 63, 28, 63], fill=C("P06"))
    return img


def locker_row(n=3):
    """복도 사물함 (n tiles wide, stands against a north wall: front face 48px tall + 6px top)."""
    w = n * T
    img = Image.new("RGBA", (w, 54), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, 5], fill=C("P14"), outline=C("P02"))
    for i in range(n * 2):
        x = i * 16
        d.rectangle([x, 6, x + 15, 53], fill=C("P45"), outline=C("P02"))
        d.line([x + 1, 7, x + 1, 52], fill=C("P46"))
        for y in (10, 13, 16):
            d.line([x + 5, y, x + 11, y], fill=C("P43"))
        d.rectangle([x + 12, 26, x + 13, 31], fill=C("P07"))
        d.rectangle([x + 4, 36, x + 11, 40], fill=C("P09"))            # name card
        d.line([x + 5, 38, x + 9, 38], fill=C("P05"))
    return img


def exam_bed():
    """진료소 진찰대 (2x1) with the white curtain rail."""
    w = 2 * T
    img = Image.new("RGBA", (w, T + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 6, w - 3, 19], fill=C("P15"), outline=C("P02"))
    d.rectangle([4, 7, 15, 18], fill=C("P09"))                          # headrest
    d.rectangle([16, 8, w - 5, 17], fill=C("P09")); d.line([16, 8, w - 5, 8], fill=C("P08"))
    d.rectangle([2, 20, w - 3, 26], fill=C("P13"), outline=C("P02"))
    for x in (5, w - 8):
        d.rectangle([x, 27, x + 2, 37], fill=C("P06"))
    d.point((w - 12, 23), fill=C("P53"))
    return img


def med_cabinet():
    """약장 (1x2 against the wall, glass doors)."""
    img = Image.new("RGBA", (T, 56), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 0, 30, 55], fill=C("P09"), outline=C("P02"))
    d.rectangle([3, 3, 28, 30], fill=C("P15"), outline=C("P07"))
    for y in (10, 19, 27):
        d.line([4, y, 27, y], fill=C("P07"))
        for x in range(5, 26, 4):
            d.rectangle([x, y - 4, x + 2, y - 1], fill=C(("P53", "P45", "P21", "P55")[(x + y) % 4]))
    d.line([15, 3, 15, 30], fill=C("P07"))
    d.rectangle([3, 33, 28, 53], fill=C("P08"), outline=C("P07"))
    d.rectangle([12, 38, 19, 41], fill=C("P54")); d.rectangle([14, 36, 17, 43], fill=C("P54"))   # red cross
    return img


def overseer_desk():
    """오버시어 결재 책상 3x1: dark wood, SJ terminal, stamp, file stack."""
    w = 3 * T
    img = Image.new("RGBA", (w, T + 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 10, w - 2, 23], fill=C("P17"), outline=C("P01"))
    d.line([2, 11, w - 3, 11], fill=C("P19"))
    d.rectangle([6, 0, 27, 15], fill=C("P08"), outline=C("P02"))       # SJ terminal
    d.rectangle([9, 3, 24, 11], fill=C("U1")); d.line([10, 5, 21, 5], fill=C("U5")); d.line([10, 8, 17, 8], fill=C("U4"))
    d.rectangle([40, 13, 59, 19], fill=C("P09"), outline=C("P06"))     # 생활기록부 file
    d.line([41, 15, 58, 15], fill=C("P46"))
    d.rectangle([66, 12, 69, 17], fill=C("P53")); d.rectangle([65, 18, 70, 19], fill=C("P02"))  # stamp
    d.rectangle([76, 12, 89, 18], fill=C("P49"), outline=C("P47"))     # nameplate
    d.rectangle([1, 24, w - 2, 42], fill=C("P16"), outline=C("P01"))
    d.line([2, 25, w - 3, 25], fill=C("P18"))
    d.rectangle([w // 2 - 10, 29, w // 2 + 9, 37], fill=C("P44"))
    d.rectangle([w // 2 - 6, 31, w // 2 + 5, 35], fill=C("P48"))
    return img


def safe():
    img = Image.new("RGBA", (T, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 0, 29, 7], fill=C("P06"), outline=C("P02"))
    d.rectangle([2, 8, 29, 39], fill=C("P04"), outline=C("P02"))
    d.line([3, 9, 28, 9], fill=C("P05"))
    d.ellipse([10, 16, 21, 27], fill=C("P06"), outline=C("P02")); d.point((15, 21), fill=C("P49"))
    d.rectangle([23, 19, 25, 25], fill=C("P07"))
    return img


def planter():
    """수경 재배 상자 (2x1): steel trough, lettuce rows (SD-09a V-06 / atrium greenery)."""
    w = 2 * T
    img = Image.new("RGBA", (w, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 6, w - 2, 15], fill=C("P34"), outline=C("P02"))    # nutrient water
    for x in range(4, w - 6, 7):                                       # lettuce heads
        d.ellipse([x, 2, x + 7, 10], fill=C("P30"), outline=C("P28"))
        d.point([(x + 2, 4), (x + 3, 4)], fill=C("P32"))
        d.point((x + 4, 8), fill=C("P29"))
    d.rectangle([1, 16, w - 2, 27], fill=C("P06"), outline=C("P02"))
    d.line([2, 17, w - 3, 17], fill=C("P07"))
    d.rectangle([6, 20, 15, 24], fill=C("P09")); d.line([7, 22, 13, 22], fill=C("P05"))
    return img


# ---------------------------------------------------------------- gear door (192x192, 8 frames)
def gear_door(frame=0, frames=8, teeth=12):
    """톱니 방폭문: rolling cog door. One tooth period over 8 frames -> seamless roll loop.
    Drawn analytically per angle (no runtime rotation, SD-16 §3.8)."""
    S = 192
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    cx = cy = 95.5
    rot = frame * (2 * math.pi / teeth) / frames
    R_out, R_root, R_rim, R_hub = 92, 82, 70, 30
    light = (-0.6, -0.8)
    for y in range(S):
        for x in range(S):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if r > R_out + 0.5:
                continue
            a = (math.atan2(dy, dx) - rot) % (2 * math.pi)
            ph = (a * teeth / (2 * math.pi)) % 1.0
            tooth = 0.18 < ph < 0.82                               # trapezoid teeth
            edge_r = R_out if tooth else R_root
            if 0.18 < ph < 0.26 or 0.74 < ph < 0.82:
                edge_r = R_out - 3                                 # chamfered tooth flanks
            if r > edge_r + 0.5:
                continue
            nx, ny = dx / (r or 1), dy / (r or 1)
            lit = nx * light[0] + ny * light[1]
            if r > R_rim:                                        # tooth ring: heavy steel
                tok = "P07" if lit > 0.45 else "P06" if lit > -0.1 else "P05"
                if r > edge_r - 2.5 and lit > 0.3:
                    tok = "P08"
            elif r > R_rim - 2:
                tok = "P02"
            elif r > R_hub + 6:                                    # face plate with hazard ring
                if R_rim - 12 < r < R_rim - 3:
                    seg = int(((a + 0.0) * 24 / (2 * math.pi)))
                    tok = "P48" if seg % 2 == 0 else "P02"
                    if r < R_rim - 10 or r > R_rim - 4:
                        tok = "P47" if tok == "P48" else "P01"
                else:
                    tok = "P45" if lit > 0.2 else "P44"
                    if abs(r - (R_hub + 18)) < 0.7:
                        tok = "P43"
            elif r > R_hub:
                tok = "P02" if r > R_hub + 5 else ("P06" if lit > 0 else "P05")
            else:
                tok = "P07" if lit > 0.3 else "P06" if lit > -0.3 else "P05"
            px[x, y] = C(tok)
    # 1px ink outline wherever the door meets transparency (tooth flanks included)
    alpha = [[px[x, y][3] for x in range(S)] for y in range(S)]
    for y in range(1, S - 1):
        for x in range(1, S - 1):
            if alpha[y][x] and (not alpha[y][x - 1] or not alpha[y][x + 1] or not alpha[y - 1][x] or not alpha[y + 1][x]):
                px[x, y] = C("P01")
    d = ImageDraw.Draw(img)
    # bolts on the face plate (rotate with the door)
    for k in range(12):
        a = rot + k * math.pi / 6 + math.pi / 12
        bx, by = cx + (R_hub + 12) * math.cos(a), cy + (R_hub + 12) * math.sin(a)
        d.rectangle([round(bx) - 1, round(by) - 1, round(bx) + 1, round(by) + 1], fill=C("P06"))
        d.point((round(bx) - 1, round(by) - 1), fill=C("P08"))
        d.point((round(bx) + 1, round(by) + 1), fill=C("P03"))
    # number plate: 'S-07' rendered as polygons around the hub, rotating with the door
    glyph = {  # 5x7 block glyphs
        "S": ["11111", "10000", "10000", "11111", "00001", "00001", "11111"],
        "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
        "0": ["11111", "10001", "10011", "10101", "11001", "10001", "11111"],
        "7": ["11111", "00001", "00010", "00100", "00100", "00100", "00100"],
    }
    cell = 3.2
    word = "S-07"
    total_w = len(word) * 6 * cell - cell
    ca, sa = math.cos(rot), math.sin(rot)
    for i, ch in enumerate(word):
        for r_, row in enumerate(glyph[ch]):
            for c_, v in enumerate(row):
                if v != "1":
                    continue
                lx = -total_w / 2 + (i * 6 + c_) * cell
                ly = -3.5 * cell + r_ * cell + 2
                quad = [(lx, ly), (lx + cell, ly), (lx + cell, ly + cell), (lx, ly + cell)]
                pts = [(cx + qx * ca - qy * sa, cy + qx * sa + qy * ca) for qx, qy in quad]
                d.polygon(pts, fill=C("P49"))
    return img


def gear_door_frame():
    """Wall opening for the cog door: 8x7 tiles of thick concrete + hazard surround (V-00 정문 구역)."""
    w, h = 8 * T, 7 * T
    img = Image.new("RGBA", (w, h), C("P13"))
    d = ImageDraw.Draw(img)
    for x in range(0, w, 32):
        d.line([x, 0, x, h], fill=C("P12")); d.line([x + 1, 0, x + 1, h], fill=C("P14"))
    d.line([0, 0, w, 0], fill=C("P11"))
    cx, cy = w // 2, 108
    d.ellipse([cx - 108, cy - 108, cx + 108, cy + 108], fill=C("P06"), outline=C("P02"))
    for k in range(36):                                          # hazard chevrons on the ring
        a0, a1 = k * 10, k * 10 + 5
        d.pieslice([cx - 106, cy - 106, cx + 106, cy + 106], a0, a1, fill=C("P48"))
    d.ellipse([cx - 99, cy - 99, cx + 99, cy + 99], fill=C("P02"))
    d.ellipse([cx - 97, cy - 97, cx + 97, cy + 97], fill=C("P10"))   # recess (seen when the door rolls away)
    d.rectangle([0, h - 12, w, h - 1], fill=C("P12"))
    d.rectangle([0, h - 4, w, h - 1], fill=C("P11"))
    d.rectangle([10, 30, 34, 70], fill=C("P05"), outline=C("P02"))  # control lever box
    d.rectangle([20, 36, 24, 56], fill=C("P53"))
    d.rectangle([18, 34, 26, 37], fill=C("P02"))
    return img


def all_tiles():
    return {
        "grate_a": grate(0), "grate_b": grate(1), "grate_c": grate(2),
        "panel": panel_floor(0), "panel_sheen": panel_floor(1, sheen=True), "panel_scuff": panel_floor(3),
        "guide_h": guide_line("h"), "guide_v": guide_line("v"), "lino_a": lino(0), "lino_b": lino(1),
        "clinic_a": clinic_tile(0), "clinic_b": clinic_tile(2),
        "wall_top_s": wall_top({"s"}), "wall_top_w": wall_top({"w"}), "wall_top_ws": wall_top({"w", "s"}),
        "wall_top": wall_top(set()),
        "face_top": wall_face("top"), "face_top_pipe": wall_face("top", "pipe"), "face_top_vent": wall_face("top", "vent"),
        "face_bot": wall_face("bot"), "face_bot_outlet": wall_face("bot", "outlet"),
        "balcony": balcony_band(0), "balcony_door": balcony_band(1, door=True, num="B-12"),
    }


if __name__ == "__main__":
    out = os.path.join(ROOT, "samples")
    tiles = all_tiles()
    props = [
        ("door_closed", door_slide("closed", "교무")), ("door_open", door_slide("open")),
        ("slogan1", slogan_crt("성적이 곧 미래다", 3)), ("slogan2", slogan_crt("오버시어님께 감사합니다", 4)),
        ("rank_board", rank_board()), ("clock", wall_clock()), ("blackboard", blackboard()),
        ("ration", ration_window()), ("emblem", emblem()),
        ("canteen", canteen_table(3)), ("stool", stool()), ("exam_desk", exam_desk()), ("teacher", teacher_desk()),
        ("bunk", bunk()), ("lockers", locker_row(2)), ("exam_bed", exam_bed()), ("med", med_cabinet()),
        ("overseer", overseer_desk()), ("safe", safe()), ("planter", planter()),
    ]
    # sheet: tiles row(s) then props packed in rows
    W = 640
    sheet = Image.new("RGBA", (W, 520), C("P19"))
    x, y = 8, 8
    for k, im in tiles.items():
        if x + 34 > W:
            x, y = 8, y + 36
        sheet.alpha_composite(im, (x, y)); x += 34
    x, y = 8, y + 44
    rowh = 0
    for k, im in props:
        if x + im.width + 6 > W:
            x, y = 8, y + rowh + 8; rowh = 0
        sheet.alpha_composite(im, (x, y)); x += im.width + 8; rowh = max(rowh, im.height)
    y += rowh + 10
    for f in (0, 4):
        g = gear_door(f)
        sheet.alpha_composite(g, (8 + f // 4 * 200, y)) if y + 192 <= 520 else None
    sheet = sheet.crop((0, 0, W, min(520, y + 200)))
    sheet.save(os.path.join(out, "10_tiles_s07.png"))
    upscale(sheet, 3).save(os.path.join(out, "10_tiles_s07_x3.png"))
    # gear door roll strip (8 frames)
    strip = Image.new("RGBA", (8 * 196, 196), C("P10"))
    for f in range(8):
        strip.alpha_composite(gear_door(f), (f * 196 + 2, 2))
    strip.save(os.path.join(out, "10_gear_door_8f.png"))
    frames = []
    for f in range(8):
        b = Image.new("RGBA", (196, 196), C("P10")); b.alpha_composite(gear_door(f), (2, 2))
        frames.append(upscale(b, 2).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out, "10_gear_door.gif"), save_all=True, append_images=frames[1:], duration=80, loop=0)
    print("ok")
