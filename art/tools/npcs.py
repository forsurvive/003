"""Reference sample #9: NPCs baked from SD-07b appearance codes (SD-16 §7.2, §12.3 #9).
Code: body-skin-hair-haircolour-torso-wear-palette-headgear-eyegear-prop, e.g. M2-S4-HR02-H4-T02-1-PF11-HD03-EY00-PR034.
Bodies are derived from the one M1 body sheet by row/column surgery on the baked frames (feet stay on y=60,
foot-lock untouched): M2 wider, F1 narrower shoulders and 1px shorter, F2 = F1 + wider hips, E1/E2 stooped
and shorter, K1 child (6 rows shorter, narrower; adult-size head reads as a child at 1x).
Writes samples/16_npcs_lineup_x4.png, 16_npcs_idle_x3.png, 16_npcs_life.gif, 16_npcs_walk.gif."""
import os, sys, math
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import rig_pc as R
import outfits as O
import heads as HD
import weapons as WP
import creatures as CR
from grid import thin_outline, upscale, check

ROOT = os.path.dirname(os.path.dirname(__file__))
FONT = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
F7 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri7.ttf"), 8)
CLEAR = (0, 0, 0, 0)
C = lambda t: P.rgb(t) + (255,)
VIEWS = ("S", "SE", "E", "NE", "N")
ORDER = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")

# (group, name, role, code) — rows copied from SD-07b §4
NPCS = [
    ("S-07 주민", "차명수", "담임·적성 평가관", "M1-S3-HR05-H4-T11-1-PF11-HD00-EY03-PR020"),
    ("S-07 주민", "방금례", "행정실 서기", "E2-S2-HR08-H5-T11-2-PF11-HD00-EY02-PR019"),
    ("S-07 주민", "신혜령", "의무관", "F1-S2-HR06-H4-T13-1-PF11-HD00-EY00-PR011"),
    ("S-07 주민", "나채윤", "우등 동급생", "F1-S1-HR06-H1-T01-0-PF11-HD00-EY00-PR021"),
    ("S-07 주민", "송지우", "배급소 아이", "K1-S3-HR07-H2-T01-1-PF11-HD00-EY00-PR022"),
    ("S-07 주민", "하로운", "배관 기사", "M2-S3-HR01-H2-T12-2-PF11-HD02-EY00-PR095"),
    ("S-07 주민", "홍태린", "구내방송 진행", "F1-S1-HR09-H2-T11-0-PF11-HD00-EY00-PR003"),
    ("S-07 주민", "이수겸", "전 오버시어", "E1-S2-HR00-H5-T11-2-PF11-HD00-EY03-PR006"),
    ("S-07 경비", "도경철", "보안부장", "M2-S4-HR02-H4-T02-1-PF11-HD03-EY00-PR034"),
    ("S-07 경비", "최보미", "정문 경비", "F1-S4-HR02-H2-T02-1-PF11-HD03-EY00-PR113"),
    ("계엄군", "엄도현", "하사 분대장", "M1-S4-HR02-H1-T06-1-PF01-HD04-EY00-PR034"),
    ("계엄군", "신승원", "상사 검문소장", "M2-S3-HR01-H4-T06-2-PF01-HD04-EY05-PR014"),
    ("계엄군", "선우진", "중위 수색조장", "M1-S2-HR02-H1-T06-1-PF01-HD04-EY00-PR019"),
    ("계엄군", "육지환", "계엄사령관 대령", "M2-S4-HR01-H1-T08-0-PF01-HD15-EY00-PR053"),
    ("새벽인력", "독사", "추심원·추적자", "M1-S4-HR01-H1-T12-1-PF05-HD00-EY05-PR027"),
    ("새벽인력", "갈고리", "인솔조장·추적자", "M2-S5-HR00-H1-T12-2-PF05-HD05-EY00-PR025"),
    ("봉천", "하숙자", "부이장·약국", "E2-S3-HR08-H4-T03-1-PF12-HD00-EY02-PR007"),
    ("봉천", "오봉수", "고물상", "M2-S4-HR01-H2-T03-2-PF12-HD05-EY00-PR015"),
    ("봉천", "조담희", "텃밭 담당", "F2-S3-HR05-H2-T03-1-PF12-HD07-EY00-PR048"),
    ("봉천", "남무진", "대장장이", "M2-S5-HR01-H1-T12-2-PF12-HD00-EY06-PR046"),
    ("봉천", "남솔", "백구 밥 당번", "K1-S3-HR07-H2-T03-1-PF12-HD00-EY00-PR045"),
    ("봉천", "오영자", "계단 미용실", "F2-S3-HR11-H2-T03-1-PF12-HD00-EY00-PR157"),
    ("봉천", "조만석", "이장", "E1-S4-HR01-H5-T03-2-PF12-HD00-EY00-PR006"),
]


def parse_code(code):
    b, sk, hr, hc, t, worn, pf, hd, ey, pr = code.split("-")
    return dict(body=b, skin=sk, hair=hr, color=hc, torso=t, worn=int(worn),
                faction=None if pf == "PF00" else "PF-" + pf[2:], gear=None if hd == "HD00" else hd,
                eyes=None if ey == "EY00" else ey, prop=pr)


# ---------------------------------------------------------------- body surgery
def drop_rows(img, rows):
    rows = set(rows)
    out = Image.new("RGBA", img.size, CLEAR)
    for y in range(64):
        if y in rows:
            continue
        below = sum(1 for r in rows if r > y)
        out.paste(img.crop((0, y, 64, y + 1)), (0, y + below))
    return out


def hmod(img, y0, y1, mode):
    out = img.copy()
    src = img.load(); px = out.load()
    for y in range(y0, y1 + 1):
        for x in range(64):
            if mode == "widen":
                sx = x + 1 if x <= 30 else (x - 1 if x >= 33 else x)
            else:                                   # narrow: drop columns 28 and 35
                sx = x - 1 if x <= 28 else (x + 1 if x >= 35 else x)
            px[x, y] = src[sx, y] if 0 <= sx < 64 else CLEAR
    return out


def body(img, b):
    if b == "M2":
        return hmod(img, 35, 57, "widen")
    if b in ("F1", "F2", "E2"):
        img = hmod(img, 36, 46, "narrow")
    if b == "F2":
        img = hmod(img, 46, 57, "widen")
    if b in ("F1", "F2"):
        return drop_rows(img, [50])
    if b in ("E1", "E2"):
        return drop_rows(img, [35, 52])
    if b == "K1":
        img = hmod(img, 36, 58, "narrow")
        return drop_rows(img, [38, 41, 44, 49, 51, 53])
    return img


def skin(img, s):
    if s == "S3":
        return img
    src = [P.rgb(c) for c in P.SKIN["S3"]]
    dst = [P.rgb(c) + (255,) for c in P.SKIN[s]]
    m = dict(zip(src, dst))
    out = img.copy(); px = out.load()
    for y in range(64):
        for x in range(64):
            p = px[x, y]
            if p[3] and p[:3] in m:
                px[x, y] = m[p[:3]]
    return out


def wear(img, view, level, fit):
    """낡음 1: two scuffs; 2: plus a patched square and a frayed hem notch."""
    if level == 0 or view not in ("S", "SE", "N", "NE"):
        return img
    out = img.copy(); d = ImageDraw.Draw(out)
    dark = fit["sleeve"][2]
    for x, y in ((29, 41), (34, 44)):
        if out.getpixel((x, y))[3]:
            d.point((x, y), fill=C(dark))
    if level == 2:
        if out.getpixel((34, 39))[3]:
            d.rectangle([33, 38, 35, 40], fill=C("P19")); d.point((33, 38), fill=C("P20"))
            d.point((35, 40), fill=C("P17"))
        for x in (28, 33):
            if out.getpixel((x, 47))[3]:
                d.point((x, 47), fill=C("P01"))
    return out


# ---------------------------------------------------------------- signature props (16x16 max, '*' = grip)
PKEY = {"o": "P01", "k": "P02", "l": "P03", "m": "P04", "n": "P05", "g": "P06", "G": "P07", "w": "P08", "W": "P09",
        "R": "P53", "r": "P52", "Y": "P48", "y": "P49", "b": "P45", "B": "P46", "d": "P17", "D": "P18",
        "t": "P20", "T": "P21", "O": "P59", "Z": "P60", "s": "P13", "S": "P14", "e": "P26", "E": "P27"}
PROPS = {
    "PR020": [".o.", "oRo", "o*o", "oRo", "oGo", ".o."],                                        # 빨간 펜
    "PR019": ["oooooo", "oBbbbo", "oBwwbo", "o*wwbo", "oBwwbo", "oooooo"],                       # 출석부
    "PR021": ["oooooo", "oWWWWo", "oWllWo", "o*WWWo", "oWllWo", "oooooo"],                       # 시험지 묶음
    "PR022": ["oooo", "oYyo", "o*Wo", "oooo"],                                                   # 배급 카드
    "PR095": ["..ooo...", "..o*o...", "oooooooo", "oRRRRRRo", "oRrrrrRo", "oRRRRRRo", "oooooooo"],  # 공구함
    "PR003": [".o*o..", ".oWo..", "oWWWo.", "oWWWWo", "oGGGGo", "oooooo"],                       # 확성기
    "PR034": [".oo.", "oggo", "o*go", "oOOo", "oOOo", "oOZo", "oZZo", ".oo."],                   # 경광봉
    "PR113": [".oo.", "oRRo", "oRro", "o*Ro", "oRro", "oYYo", ".oo."],                           # 신호탄 통
    "PR014": ["oooooo", "olkolk", "o*oolo", "oooooo"],                                           # 망원경
    "PR053": ["*kkkkkky", "oooooooo"],                                                           # 지휘봉
    "PR027": ["ooooooo.", "ollllloo", "o*ooGGGo", "..o.oooo"],                                   # 그물총
    "PR025": ["o*o", ".g.", "oGo", ".g.", "oGo", ".g.", "oGo", ".o."],                           # 쇠사슬
    "PR007": [".o*o.", "owwwo", "oWwwo", "oWRwo", "oWwwo", ".ooo."],                             # 약봉지
    "PR015": ["..o*o..", ".oDDDo.", "oDdDGDo", "oDDdDDo", "oDGDDdo", ".ooooo."],                 # 고철 자루
    "PR046": ["o*o", "odo", "odo", "oooo", "oGGGo", "ooooo"],                                    # 망치
    "PR045": [".ooo.", "o*.Ro", "oR.Ro", ".oRo.", "..R..", "..R.."],                             # 강아지 줄
    "PR157": [".o.o.", "oGoGo", ".o*o.", "oo.oo", "o...o"],                                      # 가위
}
LONG = {"PR006": ("P17", "P18"), "PR048": ("P45", "P46")}       # 지팡이 / 우산: from the hand to the ground
MAIN_HAND = {"S": (25, 45), "SE": (26, 45), "E": (32, 45), "NE": (37, 45), "N": (38, 45)}


def find_hand(img, view, guess):
    """Nearest hand pixel (skin or glove) to the expected anchor after body surgery."""
    gx, gy = guess
    best, bd = guess, 1e9
    skins = {P.rgb(c) for fam in ("S1", "S2", "S3", "S4", "S5", "S6") for c in P.SKIN[fam]}
    for y in range(36, 56):
        for x in range(gx - 4, gx + 5):
            p = img.getpixel((x, y))
            if p[3] and p[:3] in skins:
                dd = (x - gx) ** 2 + (y - gy) ** 2 * 0.5
                if dd < bd:
                    best, bd = (x, y), dd
    return best


def prop(img, view, pr):
    out = img.copy()
    hx, hy = find_hand(img, view, MAIN_HAND[view])
    if pr == "PR011":                                     # 청진기 around the neck
        if view in ("S", "SE"):
            d = ImageDraw.Draw(out)
            nx = 31 if view == "S" else 32
            ny = next((y for y in range(30, 45) if out.getpixel((nx, y))[:3] == P.rgb(P.SKIN["S2"][1])
                       or y > 35), 36)
            d.line([nx - 2, ny, nx - 2, ny + 3], fill=C("P02")); d.line([nx + 3, ny, nx + 3, ny + 3], fill=C("P02"))
            d.line([nx - 2, ny + 3, nx, ny + 5], fill=C("P02")); d.rectangle([nx, ny + 5, nx + 1, ny + 6], fill=C("P07"))
        return out
    if pr in LONG:                                        # cane / folded umbrella down to the ground
        if view in ("N", "NE"):
            return out
        d = ImageDraw.Draw(out)
        c0, c1 = LONG[pr]
        x = hx + (1 if view == "E" else 0)
        bottom = 60
        d.line([x - 1, hy - 1, x + 2, hy - 1], fill=C("P01"))
        d.rectangle([x - 1, hy, x + 1, bottom], fill=C("P01"))
        d.line([x, hy - 2, x, bottom - 1], fill=C(c1)) if pr == "PR048" else d.line([x, hy, x, bottom - 1], fill=C(c0))
        if pr == "PR006":
            d.line([x - 1, hy - 2, x + 2, hy - 2], fill=C("P01")); d.line([x - 1, hy - 1, x + 1, hy - 1], fill=C(c1))
        else:
            d.polygon([(x - 2, hy + 3), (x + 2, hy + 3), (x, bottom - 3)], fill=C(c0))
            d.line([x, hy + 3, x, bottom - 4], fill=C(c1))
        return out
    rows = PROPS.get(pr)
    if not rows:
        return out
    gx = gy = 0
    for y, r in enumerate(rows):
        if "*" in r:
            gx, gy = r.index("*"), y
    stamp = Image.new("RGBA", (16, 16), CLEAR)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in PKEY:
                stamp.putpixel((x, y), C(PKEY[ch]))
            elif ch == "*":
                stamp.putpixel((x, y), C("P01"))
    if view in ("N", "NE"):                               # carried at the side; body hides part of it
        layer = Image.new("RGBA", (64, 64), CLEAR)
        layer.alpha_composite(stamp, (hx - gx, hy - gy))
        layer.alpha_composite(out)
        return layer
    out.alpha_composite(stamp, (hx - gx, hy - gy))
    return out


# ---------------------------------------------------------------- build one NPC
def build(code):
    c = parse_code(code)
    look = dict(hair=c["hair"], color=c["color"], gear=c["gear"], eyes=c["eyes"])
    sets, rep = R.build_all(c["torso"], c["faction"], look)
    fit = R.FIT
    out = {"idle": {}, "walk": {}}
    for v in VIEWS:
        im = sets["idle"][v]
        im = wear(im, v, c["worn"], fit)
        im = body(im, c["body"])
        im = skin(im, c["skin"])
        im = prop(im, v, c["prop"])
        out["idle"][v] = im
        out["walk"][v] = [skin(body(wear(f, v, c["worn"], fit), c["body"]), c["skin"]) for f in sets["walk"][v]]
        out["idle"][v] = thin_outline(out["idle"][v])                 # body surgery can re-double an edge
        out["walk"][v] = [thin_outline(f) for f in out["walk"][v]]
    for m, src in (("NW", "NE"), ("W", "E"), ("SW", "SE")):
        out["idle"][m] = out["idle"][src].transpose(Image.FLIP_LEFT_RIGHT)
        out["walk"][m] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in out["walk"][src]]
    out["code"], out["parsed"], out["foot"] = code, c, rep
    return out


# ---------------------------------------------------------------- life motions (SD-16 §3.6.3)
def life_frames(code, kind):
    c = parse_code(code)
    look = dict(hair=c["hair"], color=c["color"], gear=c["gear"], eyes=c["eyes"])
    ups, fulls = WP.bases(c["torso"], look, c["faction"])
    fin = lambda im: skin(body(im, c["body"]), c["skin"])
    frames = []
    if kind == "arms_crossed":                            # 팔짱 (S): forearms folded over the chest
        im = Image.new("RGBA", (64, 64), CLEAR)
        im.alpha_composite(WP.legs_part(fulls["S"])); im.alpha_composite(WP.upper_only(ups["S"]))
        lay = Image.new("RGBA", (64, 64), CLEAR)
        WP.jointed_arm(lay, ((37, 38), (39, 43), (29, 42)), R.FIT["sleeve_far"])
        WP.jointed_arm(lay, ((26, 38), (24, 43), (34, 41)), R.FIT["sleeve"])
        im.alpha_composite(lay)
        d = ImageDraw.Draw(im)
        WP.hand_block(d, 35, 40, 36, 41)
        if R.FIT["pads"]:
            WP.front_compose  # pads drawn like the posed front arms
            g = O.GEOM["S"]; e = R.FIT["pads"]
            lx, ly, lx1 = g["lsh"]; rx, ry, rx1 = g["rsh"]
            O._box(d, lx - e, ly - (e - 1), lx1 + 1, ly + 3 + e, R.FIT["pad_ramp"])
            O._box(d, rx - 1, ry - (e - 1), rx1 + e, ry + 3 + e, R.FIT["pad_ramp"])
        frames = [fin(im)] * 2
    elif kind == "gesture":                               # 손짓 (S): open hand raised, 2 frames
        for hand in ((41, 35), (42, 32)):
            im = Image.new("RGBA", (64, 64), CLEAR)
            im.alpha_composite(WP.legs_part(fulls["S"])); im.alpha_composite(WP.upper_only(ups["S"]))
            lay = Image.new("RGBA", (64, 64), CLEAR)
            WP.jointed_arm(lay, ((26, 38), (25, 42), (25, 45)), R.FIT["sleeve"])
            WP.jointed_arm(lay, ((37, 38), (40, 40), hand), R.FIT["sleeve"])
            im.alpha_composite(lay)
            d = ImageDraw.Draw(im)
            WP.hand_block(d, 24, 44, 25, 46)
            WP.hand_block(d, hand[0] - 1, hand[1] - 2, hand[0] + 1, hand[1])
            frames.append(fin(im))
    elif kind == "hammer":                                # 작업·망치질 (E): 4 frames
        for hand, ang in (((37, 40), -60), ((34, 31), -150), ((40, 41), 55), ((39, 39), 10)):
            im = Image.new("RGBA", (64, 64), CLEAR)
            im.alpha_composite(WP.legs_part(fulls["E"]))
            d = ImageDraw.Draw(im)
            d.rectangle([42, 49, 51, 52], fill=C("P01")); d.rectangle([43, 49, 50, 51], fill=C("P04"))   # anvil
            d.line([43, 49, 50, 49], fill=C("P06")); d.rectangle([45, 53, 48, 59], fill=C("P02"))
            d.rectangle([44, 59, 49, 60], fill=C("P01"))
            fr = dict(h=(hand, (39, 44)), w=None, fist=True)
            body_ = WP.compose(WP.upper_only(ups["E"]), "E", fr, "fist")
            im.alpha_composite(body_)
            d = ImageDraw.Draw(im)
            a = math.radians(ang)
            tip = (hand[0] + 7 * math.cos(a), hand[1] + 7 * math.sin(a))
            d.line([hand, tip], fill=C("P01"), width=3); d.line([hand, tip], fill=C("P18"), width=1)
            hx, hy = tip
            pa = (math.cos(a + math.pi / 2), math.sin(a + math.pi / 2))
            p0 = (hx - 2.5 * pa[0], hy - 2.5 * pa[1]); p1 = (hx + 2.5 * pa[0], hy + 2.5 * pa[1])
            d.line([p0, p1], fill=C("P01"), width=4); d.line([p0, p1], fill=C("P06"), width=2)
            if ang == 55:                                  # impact spark on the anvil face
                for sx_, sy_ in ((44, 47), (47, 46), (49, 47)):
                    d.point((sx_, sy_), fill=C("P60"))
            frames.append(fin(im))
    return frames


# ---------------------------------------------------------------- 백구 (AN-CR536, white Jindo)
def baekgu():
    """진돗개 at real scale: shoulder ~13px vs a 40px adult (≈50cm : 170cm); pricked ears, curled tail."""
    sp = dict(CR.DOG)
    sp.update(fur=["P05", "P06", "P07", "P08", "P09", "P09"], skin=["P07", "P07", "P08", "P08", "P09", "P09"],
              leg_near=("P09", "P08", "P06"), leg_far=("P08", "P07", "P06"), paw="P06", leg_r=(1.3, 1.0), far_r=(1.1, 0.9),
              shoulder=(38, 50), hip=(27, 50), l1=4.6, l2=5.6,
              body=((28, 48, 4, 3.6), (33, 48, 6.5, 3.8), (38, 48, 4, 4.2)),
              neck=(41, 45, 2.6, 3), head=(43, 42, 3, 2.6), muzzle=(46.5, 43.5, 2.2, 1.4), ear=((42, 38), (44, 38)),
              tail=((25, 46), (23, 42), (26, 41)), patches=(), eye=(44, 41), step=6)
    idle = [CR.stand(sp), CR.stand(sp, tail_dy=-1, head_dy=1)]
    mv, _ = CR.move_frames(sp)
    return idle, mv


# ---------------------------------------------------------------- sheets
def main():
    out = os.path.join(ROOT, "samples")
    built = [(g, n, r, build(code)) for g, n, r, code in NPCS]
    allowed = P.allowed_set(*P.SKIN.keys(), *P.HAIR.keys(), *P.PF.keys())
    bad = []
    worst = 0
    for *_, b in built:
        for v in ORDER:
            bad += check(b["idle"][v], allowed)
        worst = max([worst] + [int(l.split("slip ")[1].split("px")[0]) for l in b["foot"]])
    bidle, bmove = baekgu()
    # line-up: everyone facing S, with names (scale check: children, elders, big men)
    W = 34 * (len(built) + 1) + 8
    lu = Image.new("RGBA", (W, 92), C("P19"))
    d = ImageDraw.Draw(lu); d.fontmode = "1"
    for i, (g, n, r, b) in enumerate(built):
        x = 4 + i * 34
        lu.alpha_composite(b["idle"]["S"].crop((15, 14, 49, 62)), (x, 6))
        d.text((x + 17, 58), n, font=F7, fill=C("P09"), anchor="ma")
        d.text((x + 17, 68), b["code"].split("-")[0], font=F7, fill=C("P07"), anchor="ma")
    xb = 4 + len(built) * 34
    lu.alpha_composite(bidle[0].crop((14, 22, 62, 62)), (xb - 10, 16))
    d.text((xb + 14, 58), "백구", font=F7, fill=C("P09"), anchor="ma")
    for x0, x1, label in ((4, 4 + 8 * 34, "볼트 S-07 주민"), (4 + 8 * 34, 4 + 10 * 34, "S-07 경비"),
                          (4 + 10 * 34, 4 + 14 * 34, "계엄군"), (4 + 14 * 34, 4 + 16 * 34, "새벽인력 추적자"),
                          (4 + 16 * 34, 4 + 23 * 34 + 48, "봉천 계단마을")):
        d.line([x0 + 2, 80, x1 - 4, 80], fill=C("P07"))
        d.text(((x0 + x1) // 2, 82), label, font=F7, fill=C("P08"), anchor="ma")
    upscale(lu, 4).save(os.path.join(out, "16_npcs_lineup_x4.png"))
    # idle 8 directions, grouped 2 columns of NPCs
    cols = 2
    rows = math.ceil(len(built) / cols)
    sh = Image.new("RGBA", (cols * (120 + 8 * 34) + 8, rows * 50 + 8), C("P19"))
    d = ImageDraw.Draw(sh); d.fontmode = "1"
    for i, (g, n, r, b) in enumerate(built):
        cx = 4 + (i % cols) * (120 + 8 * 34); cy = 4 + (i // cols) * 50
        d.text((cx, cy + 14), n, font=FONT, fill=C("P09"))
        d.text((cx, cy + 27), r, font=F7, fill=C("P08"))
        d.text((cx, cy + 37), b["code"], font=F7, fill=C("P07")) if False else None
        for k, v in enumerate(ORDER):
            sh.alpha_composite(b["idle"][v].crop((15, 14, 49, 62)), (cx + 116 + k * 34, cy))
    upscale(sh, 3).save(os.path.join(out, "16_npcs_idle_x3.png"))
    # walk gif: everyone walking S then E (2 strips)
    frames = []
    for t in range(12):
        c = Image.new("RGBA", (len(built) * 34 + 60, 100), C("P19"))
        for i, (g, n, r, b) in enumerate(built):
            c.alpha_composite(b["walk"]["S"][t % 6].crop((15, 14, 49, 62)), (4 + i * 34, 0))
            c.alpha_composite(b["walk"]["E"][t % 6].crop((15, 14, 49, 62)), (4 + i * 34, 50))
        c.alpha_composite(bmove[t % 6].crop((14, 22, 62, 62)), (4 + len(built) * 34, 58))
        frames.append(upscale(c, 2).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out, "16_npcs_walk.gif"), save_all=True, append_images=frames[1:], duration=62, loop=0)
    # life motions gif
    lives = [("도경철 팔짱", life_frames(NPCS[8][3], "arms_crossed")), ("홍태린 손짓", life_frames(NPCS[6][3], "gesture")),
             ("조만석 손짓", life_frames(NPCS[22][3], "gesture")), ("남무진 망치질", life_frames(NPCS[19][3], "hammer"))]
    frames = []
    for t in range(8):
        c = Image.new("RGBA", (len(lives) * 64, 72), C("P19"))
        d = ImageDraw.Draw(c); d.fontmode = "1"
        for i, (lab, fr) in enumerate(lives):
            c.alpha_composite(fr[t % len(fr)], (i * 64, 0))
            d.text((i * 64 + 32, 62), lab, font=F7, fill=C("P09"), anchor="ma")
        frames.append(upscale(c, 3).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out, "16_npcs_life.gif"), save_all=True, append_images=frames[1:], duration=260, loop=0)
    print("npcs:", len(built), "| off-palette:", sorted(set(bad)) or 0, "| worst slip:", worst)


if __name__ == "__main__":
    main()
