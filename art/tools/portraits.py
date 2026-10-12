"""Reference sample #10: dialogue portraits (SD-16 §8). 96x96 bust, 3/4 view facing right, light from the upper left.
Two tiers: unique portraits (윤정인·하도윤·육지환·조만석) x 6 expressions, and module portraits assembled from the
same SD-07b appearance code as the map sprite x 3 expressions. Faces are cel-shaded planes (base / shadow /
deep shadow / highlight on a 5-step skin ramp), features are drawn per expression in a ~40x30 area only.
Writes samples/17_portraits_unique_x3.png, 17_portraits_module_x3.png."""
import os, sys, math
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import upscale, check

ROOT = os.path.dirname(os.path.dirname(__file__))
FONT = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
F7 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri7.ttf"), 8)
CLEAR = (0, 0, 0, 0)
S = 96


def C(t):
    return P.rgb(t) + (255,)


class Face:
    """Pixel canvas with a few region helpers."""
    def __init__(self):
        self.img = Image.new("RGBA", (S, S), CLEAR)
        self.px = self.img.load()

    def put(self, x, y, tok):
        x, y = int(x), int(y)
        if 0 <= x < S and 0 <= y < S:
            self.px[x, y] = C(tok) if isinstance(tok, str) else tok

    def get(self, x, y):
        return self.px[int(x), int(y)] if 0 <= x < S and 0 <= y < S else CLEAR

    def fill(self, mask, tok):
        for x, y in mask:
            self.put(x, y, tok)


def ellipse_mask(cx, cy, rx, ry):
    return {(x, y) for y in range(int(cy - ry) - 1, int(cy + ry) + 2) for x in range(int(cx - rx) - 1, int(cx + rx) + 2)
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1}


def poly_mask(pts):
    img = Image.new("L", (S, S), 0)
    ImageDraw.Draw(img).polygon(pts, fill=255)
    return {(x, y) for y in range(S) for x in range(S) if img.getpixel((x, y))}


def outline_of(mask):
    return {(x, y) for x, y in mask if any((x + a, y + b) not in mask for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))}


# ---------------------------------------------------------------- face geometry (3/4 right)
def head_masks(p):
    """Skull + jaw masks for face params: jaw (0 narrow .. 1 square), chin (length), cheek, scale."""
    jw = p.get("jaw", 0.4)
    chin = p.get("chin", 0)
    skull = ellipse_mask(44, 33, 18, 20)
    jaw = poly_mask([(27, 36), (28, 47), (31 - jw * 2, 54 + jw * 2), (38, 61 + chin), (46, 64 + chin), (53, 62 + chin),
                     (58 + jw, 56), (61 + jw, 48), (62, 38)])
    face = skull | jaw
    if p.get("child"):
        face = {(x, y) for x, y in face if y < 60} | ellipse_mask(46, 54, 13, 7)
    return face


def far_line(y, p):
    """x beyond which the face turns away from the light (far side plane)."""
    return 55 + (y - 40) * 0.12 if y < 48 else 54 - (y - 48) * 0.45


def draw_face(f, p, skin):
    sk = P.SKIN[skin]
    face = head_masks(p)
    rows = {}
    for x, y in face:
        rows.setdefault(y, []).append(x)
    # neck (behind the jaw), short; shadowed under the chin
    neck = poly_mask([(37, 54), (53, 54), (54, 70), (36, 70)])
    for x, y in neck:
        f.put(x, y, sk[2] if x < 45 else sk[1])
    for x, y in neck:
        if (x, y) not in face and y < 63 + p.get("chin", 0):
            f.put(x, y, sk[1])
    # ear on the near side, sticking out of the contour
    ear = ellipse_mask(27, 45, 2.8, 5)
    for x, y in ear:
        f.put(x, y, sk[3])
    for x, y in ellipse_mask(27.6, 45.5, 1.0, 2.6):
        f.put(x, y, sk[2])
    for x, y in outline_of(ear):
        if (x, y) not in face:
            f.put(x, y, sk[0])
    # face planes: lit front, a far-side band that follows the contour, a soft jaw shadow
    for x, y in face:
        xr = max(rows[y])
        band = 5 if y < 46 else 4
        tok = sk[3]
        if x > xr - band and x > 46:
            tok = sk[2]
        if y > 58 and x > 44:
            tok = sk[2]
        f.put(x, y, tok)
    for x in range(36, 41):                                      # near cheekbone catch: a short plane edge
        f.put(x, 48 + (x - 36) // 3, sk[4])
    for x, y in ellipse_mask(36, 24, 3, 2) & face:              # forehead catch
        f.put(x, y, sk[4])
    # nose (3/4 right): bridge starts between the eyes and runs down toward the far cheek, tip stays inside
    # the contour; lit left edge, shadow on its far side, shadow under the tip, one nostril
    top = 43 if p.get("child") else 40
    for y in range(top, 49):
        x = 50 + (y - 40) * 0.55
        f.put(x, y, sk[4] if y < 46 else sk[3])                   # lit ridge
        f.put(x + 1, y, sk[2])
        if y >= 43:
            f.put(x + 2, y, sk[1])                                 # far-side plane of the nose
        if y >= 46:
            f.put(x + 3, y, sk[2])
    for x, y in ellipse_mask(54, 48, 2.6, 1.7):
        f.put(x, y, sk[3])
    f.put(53, 47, sk[4]); f.put(54, 47, sk[4])                    # tip catch
    for x in range(51, 58):
        f.put(x, 50, sk[1])                                        # shadow under the tip
    f.put(51, 50, sk[2])
    f.put(55, 49, sk[0]); f.put(56, 49, sk[0]); f.put(57, 49, sk[1])   # nostril + wing
    # eye sockets
    for x, y in ellipse_mask(42, 41, 5.5, 2.2) | ellipse_mask(56, 40.5, 3.5, 2):
        if (x, y) in face:
            f.put(x, y, sk[2])
    # contour: light side in dark skin, shadow side and jaw in ink
    for x, y in outline_of(face):
        f.put(x, y, sk[1] if (x < 40 and y < 50) else "P01")
    return face


# ---------------------------------------------------------------- features per expression
EXPR = {  # brow (inner dy, outer dy, height), eye (open, squint), mouth kind
    "기본": dict(brow=(0, 0, 0), eye="open", mouth="neutral"),
    "미소": dict(brow=(-1, 0, -1), eye="smile", mouth="smile"),
    "분노": dict(brow=(3, -1, 1), eye="glare", mouth="snarl"),
    "슬픔": dict(brow=(-3, 1, 0), eye="sad", mouth="sad"),
    "놀람": dict(brow=(-3, -3, -3), eye="wide", mouth="open"),
    "결의": dict(brow=(1, 0, 1), eye="firm", mouth="tight"),
    "긍정": dict(brow=(-1, 0, -1), eye="smile", mouth="smile"),
    "부정": dict(brow=(2, 0, 1), eye="glare", mouth="sad"),
}


def brow(f, cx, y, w, inner, outer, lift, tok, thick=2, near=True):
    """Brow from the outer end to the inner end (inner = toward the nose = right for the near eye)."""
    x0, x1 = (cx - w // 2, cx + w // 2)
    for i in range(w + 1):
        t = i / w
        if near:      # near eye: outer at left, inner at right
            dy = outer * (1 - t) + inner * t
        else:         # far eye: inner at left, outer at right
            dy = inner * (1 - t) + outer * t
        arch = -1 if 0.3 < t < 0.7 else 0
        yy = y + lift + dy + arch
        for k in range(thick):
            f.put(x0 + i, yy + k, tok)


def eye(f, cx, cy, w, kind, sk, iris="P02", female=False, near=True):
    """Upper lid (ink), iris with a catchlight, sclera, lower lid line. kind changes lid shapes."""
    h = {"open": 3, "smile": 2, "glare": 2, "sad": 3, "wide": 4, "firm": 2}[kind]
    x0 = cx - w // 2
    # sclera + iris
    for x in range(x0, x0 + w):
        for y in range(cy - h + 1, cy + 1):
            f.put(x, y, "P08")
    ix = cx + (1 if near else 0)
    for x in range(ix - 1, ix + 1 + (1 if near else 0)):
        for y in range(cy - h + 1, cy + 1):
            f.put(x, y, iris)
    if kind != "smile":
        f.put(ix - 1, cy - h + 1, "P09")                            # catchlight
    # upper lid (thicker on the near eye, lashes for female)
    for i in range(w + 2):
        x = x0 - 1 + i
        t = i / (w + 1)
        dy = 0
        if kind == "sad":
            dy = int((1 - t) * 1.5) if near else int(t * 1.5)        # outer corners droop
        if kind == "glare":
            dy = int(t * 1.6) if near else int((1 - t) * 1.6)        # inner corner lowered
        if kind == "smile":
            dy = -1 if 0.25 < t < 0.75 else 0
        y = cy - h - (1 if 0.2 < t < 0.8 else 0) + dy
        f.put(x, y, "P01")
        if near or female:
            f.put(x, y + 1 if kind in ("glare", "firm") else y - 0, "P01")
        if female and (i == 0 if near else i == w + 1):
            f.put(x - (1 if near else -1), y - 1, "P01")             # lash flick at the outer corner
    if kind == "glare":
        for i in range(w):
            if (i >= w // 2) == near:
                f.put(x0 + i, cy - h + 1, "P01")
    # lower lid
    for x in range(x0, x0 + w):
        f.put(x, cy + 1, sk[1])
    if kind == "smile":
        for x in range(x0, x0 + w):
            f.put(x, cy + 1, sk[2]); f.put(x, cy, sk[1])
            f.put(x, cy - 1, "P01")


def mouth(f, cx, cy, kind, sk, lip="P38"):
    w = 9
    x0 = cx - w // 2
    if kind == "neutral":
        for x in range(x0, x0 + w):
            f.put(x, cy, sk[0] if x0 < x < x0 + w - 1 else sk[1])
        for x in range(x0 + 2, x0 + w - 2):
            f.put(x, cy + 1, sk[4])                                  # lower lip catch
    elif kind == "smile":
        for i in range(w + 2):
            x = x0 - 1 + i
            dy = -1 if i in (0, w + 1) else (0 if i in (1, w) else 1)
            f.put(x, cy + dy, sk[0])
        for x in range(x0 + 1, x0 + w - 1):
            f.put(x, cy + 2, sk[4])
        f.put(x0 - 1, cy - 2, sk[2]); f.put(x0 + w, cy - 2, sk[2])  # cheek dimples
    elif kind in ("sad", "snarl"):
        for i in range(w + 2):
            x = x0 - 1 + i
            dy = 1 if i in (0, w + 1) else (0 if i in (1, w) else -0)
            f.put(x, cy + dy, sk[0])
        if kind == "snarl":
            for x in range(x0 + 1, x0 + w - 1):
                f.put(x, cy + 1, "P08")                               # bared teeth
                f.put(x, cy + 2, sk[0])
            f.put(x0, cy - 1, sk[1]); f.put(x0 + w - 1, cy - 1, sk[1])
        else:
            for x in range(x0 + 2, x0 + w - 2):
                f.put(x, cy + 2, sk[4])
    elif kind == "open":
        for x, y in ellipse_mask(cx, cy + 1, 3, 2.5):
            f.put(x, y, "P51")
        for x, y in outline_of(ellipse_mask(cx, cy + 1, 3, 2.5)):
            f.put(x, y, sk[0])
        for x in range(cx - 1, cx + 2):
            f.put(x, cy - 1, "P08")
    elif kind == "tight":
        for x in range(x0, x0 + w):
            f.put(x, cy, sk[0])
        f.put(x0 - 1, cy + 1, sk[1]); f.put(x0 + w, cy + 1, sk[1])
        for x in range(x0 + 1, x0 + w - 1):
            f.put(x, cy + 1, sk[2])


def features(f, p, skin, expr):
    sk = P.SKIN[skin]
    e = EXPR[expr]
    hc = P.HAIR[p.get("hair_color", "H1")]
    btok = "#%02X%02X%02X" % P.rgb(hc[0]) if p.get("hair_color") not in ("H4", "H5") else hc[1]
    inner, outer, lift = e["brow"]
    ey = 44 + p.get("eye_dy", 0)
    brow(f, 42, ey - 7, 8, inner, outer, lift, btok, thick=2 if not p.get("female") else 1, near=True)
    brow(f, 56, ey - 7.5, 5, inner, outer, lift, btok, thick=2 if not p.get("female") else 1, near=False)
    eye(f, 42, ey, 7 if p.get("child") else 6, e["eye"], sk, iris=p.get("iris", "P02"), female=p.get("female", False), near=True)
    eye(f, 56, ey, 4, e["eye"], sk, iris=p.get("iris", "P02"), female=p.get("female", False), near=False)
    if p.get("tired"):                                          # 지친 눈가
        for x in range(39, 46):
            f.put(x, ey + 2, sk[1] if x % 2 else sk[2])
    mouth(f, 52 + p.get("mouth_dx", 0), 55 + p.get("mouth_dy", 0), e["mouth"], sk)
    if p.get("age", 30) >= 55:                                  # wrinkles: brow, crow's feet, nasolabial
        for x in range(36, 50, 1):
            if x % 3:
                f.put(x, 28, sk[2]);
        for x in range(38, 48):
            if x % 2:
                f.put(x, 31, sk[2])
        for k in range(3):
            f.put(36 - k, ey - 1 + k, sk[1])
        for k in range(5):
            f.put(53 - k * 0.6, 51 + k, sk[1])
        for x, y in ((40, 53), (44, 36), (35, 47)):
            f.put(x, y, sk[2])                                  # age spots
    if p.get("smudge"):
        for x, y in ((36, 50), (37, 50), (38, 51), (35, 51), (37, 52)):
            f.put(x, y, "P03")
    if p.get("stubble"):                                        # grey stubble: a soft band along the jaw and lip
        face = head_masks(p)
        edge = outline_of(face)
        for x, y in face:
            if y > 52 and (x, y) not in edge and any((x + a, y + b) in edge for a in (-2, -1, 0, 1, 2) for b in (0, 1, 2)):
                f.put(x, y, sk[2])
        for x in range(46, 57):
            f.put(x, 53, sk[2])
    if p.get("scar"):                                            # 손보정 고유 특징
        x0, y0, n = p["scar"]
        for k in range(n):
            f.put(x0 + k, y0 + k, sk[4]); f.put(x0 + k + 1, y0 + k, sk[1])
    if p.get("mole"):
        f.put(*p["mole"], sk[0])


# ---------------------------------------------------------------- hair
def hair_back(f, p):
    code = p.get("hair", "HR03")
    hc = P.HAIR[p.get("hair_color", "H1")]
    if code in ("HR05", "HR06"):
        bottom = 62 if code == "HR05" else 84
        m = poly_mask([(24, 24), (40, 12), (58, 14), (64, 30), (62, bottom - 10), (56, bottom), (30, bottom), (22, bottom - 8)])
        shade(f, m, hc, light_x=30)
    if code in ("HR07",):                                         # top knot behind the crown
        shade(f, ellipse_mask(32, 13, 8, 7), hc, light_x=28)
    if code in ("HR09", "HR04"):
        length = 84 if code == "HR09" else 64
        m = poly_mask([(22, 34), (28, 32), (30, length), (22, length - 4), (18, 50)])
        shade(f, m, hc, light_x=21)


def shade(f, mask, ramp, light_x=30, strands=True, outline=True):
    """Hair mass: base, shadow on the right/bottom, highlight band upper-left, strand lines."""
    ys = [y for _, y in mask] or [0]
    top, bot = min(ys), max(ys)
    for x, y in mask:
        t = (y - top) / max(1, bot - top)
        tok = ramp[2]
        if x > light_x + 18 or t > 0.85:
            tok = ramp[1]
        if x < light_x + 8 and t < 0.35:
            tok = ramp[3]
        f.put(x, y, tok)
    if strands:                                    # a few long strand lines sweeping from the crown
        xs = [x for x, _ in mask]
        cx = (min(xs) + max(xs)) / 2
        for k, off in enumerate((-12, -7, -2, 4, 9, 14)):
            for t in range(0, 30):
                x = cx + off + off * 0.04 * t
                y = top + 2 + t
                if (int(x), int(y)) in mask and (int(x), int(y) + 2) in mask:
                    f.put(x, y, ramp[3] if (off < 0 and t < 10) else ramp[1])
    if outline:
        for x, y in outline_of(mask):
            f.put(x, y, "P01")


def hair_front(f, p, face):
    code = p.get("hair", "HR03")
    hc = P.HAIR[p.get("hair_color", "H1")]
    if code == "HR00":
        return
    if p.get("gear") in ("HD03", "HD04", "HD15", "HD05", "HD02") and code in ("HR07",):
        code = "HR03"
    # hairline: the cap covers the skull above a curve across the forehead, dipping at the near temple
    def hairline(x):
        base = {"HR01": 22, "HR02": 25, "HR03": 25, "HR04": 25, "HR05": 27, "HR06": 26, "HR07": 24, "HR08": 31,
                "HR09": 24, "HR11": 26}.get(code, 25)
        temple = 12 if code not in ("HR01",) else 6
        return base + max(0, (36 - x)) * temple / 10 + max(0, x - 58) * 0.8
    cap = {(x, y) for x, y in ellipse_mask(44, 31, 19.5, 20) if y < hairline(x)}
    if code in ("HR05", "HR06"):
        cap |= poly_mask([(25, 30), (34, 30), (32, 58 if code == "HR05" else 64), (25, 60)])        # near side lock
        cap |= poly_mask([(58, 26), (64, 30), (65, 54), (60, 58)])                                # far side lock
    if code == "HR08":                                            # shaggy fringe with points
        for k, x in enumerate(range(34, 62, 4)):
            cap |= poly_mask([(x, 28), (x + 4, 28), (x + 2 + (k % 2), 36 + (k % 3))])
        cap |= {(x - 1, y) for x, y in cap if y < 40}            # extra volume
    if code == "HR11":                                            # perm: bumpy silhouette
        for a in range(0, 360, 30):
            r = math.radians(a)
            cx, cy = 44 + 19 * math.cos(r), 28 + 17 * math.sin(r)
            if cy < 36:
                cap |= ellipse_mask(cx, cy, 4, 4)
    if code == "HR01":
        cap = {(x, y) for x, y in cap if y > 13}
    shade(f, cap, hc, light_x=30)
    if code == "HR02":                                            # side part
        for y in range(14, 25):
            f.put(37 - (y - 14) * 0.2, y, hc[0])
    if code in ("HR07", "HR09", "HR04"):                          # combed back: strands toward the knot
        for k in range(4):
            for t in range(10):
                f.put(48 - k * 4 - t * 1.2, 18 + k * 1.5 + t * 0.4, hc[3] if k % 2 else hc[1])
    if code == "HR11":
        for x, y in cap:
            if (x + y) % 5 == 0:
                f.put(x, y, hc[3])
    if code == "HR01":                                            # cropped: darker hairline edge only
        for x, y in outline_of(cap):
            if y > 18 and f.get(x, y)[:3] != P.rgb("P01"):
                f.put(x, y, hc[1])


# ---------------------------------------------------------------- clothing (neckline per torso family)
def clothing(f, p):
    t = p.get("torso", "T01")
    pf = p.get("faction")
    main = [f"{pf}.{i}" for i in range(4)] if pf else ["P43", "P44", "P45", "P46"]
    acc = [f"{pf}.4", f"{pf}.5"] if pf else ["P48", "P49"]
    if t == "T03":
        main, acc = ["P16", "P17", "P18", "P19"], ["P27", "P26"]
    if t == "T13":
        main = ["P06", "P07", "P08", "P09"]
    if t == "T11" and not pf:
        main = ["P02", "P03", "P04", "P05"]
    if p.get("child"):
        body = poly_mask([(18, 96), (20, 80), (30, 71), (40, 68), (52, 68), (62, 71), (72, 80), (76, 96)])
    else:
        body = poly_mask([(8, 96), (12, 78), (24, 70), (38, 67), (52, 67), (68, 70), (82, 78), (88, 96)])
    for x, y in body:
        tok = main[2]
        if x > 62 or y > 90:
            tok = main[1]
        if x < 24 and y < 86:
            tok = main[3]
        f.put(x, y, tok)
    for x, y in outline_of(body):
        f.put(x, y, "P01")
    # shoulder seam / fold lines
    for y in range(78, 96):
        f.put(24 + (y - 78) * 0.2, y, main[1]); f.put(68 - (y - 78) * 0.25, y, main[0])
    d = ImageDraw.Draw(f.img)
    if t in ("T01", "T02"):                                       # jumpsuit: high collar + yellow zip stripe
        d.polygon([(36, 70), (46, 76), (56, 70), (56, 74), (46, 80), (36, 74)], fill=C(main[3]), outline=C("P01"))
        d.rectangle([44, 79, 47, 95], fill=C(acc[0])); d.line([44, 79, 44, 95], fill=C(acc[1]))
        if t == "T02":
            d.rectangle([30, 82, 62, 95], fill=C("P06"), outline=C("P01")); d.line([31, 83, 61, 83], fill=C("P07"))
            d.rectangle([44, 86, 47, 89], fill=C("P48"))
            for x0 in (12, 64):
                d.rounded_rectangle([x0, 74, x0 + 20, 86], radius=4, fill=C("P07"), outline=C("P01"))
                d.line([x0 + 2, 75, x0 + 18, 75], fill=C("P08"))
        if p.get("overseer"):
            d.line([20, 84, 40, 84], fill=C("P49")); d.line([20, 85, 40, 85], fill=C("P48"))   # gold band
            d.rectangle([54, 82, 59, 87], fill=C("P49"), outline=C("P01")); d.point((56, 84), fill=C("P47"))
    elif t == "T03":                                              # jacket + scarf
        d.polygon([(34, 70), (58, 70), (60, 78), (46, 82), (32, 78)], fill=C("P26"), outline=C("P01"))
        d.line([34, 74, 58, 74], fill=C("P27")); d.line([36, 78, 56, 78], fill=C("P25"))
        d.line([46, 82, 46, 96], fill=C("P01")); d.line([47, 82, 47, 96], fill=C(main[3]))
        d.polygon([(40, 80), (46, 82), (44, 96), (38, 96)], fill=C("P08"))       # shirt under the open jacket
    elif t in ("T06", "T08"):
        if t == "T08":                                            # officer coat: wide lapels, gold buttons
            d.polygon([(32, 70), (46, 84), (40, 96), (26, 80)], fill=C(main[3]), outline=C("P01"))
            d.polygon([(60, 70), (46, 84), (52, 96), (66, 80)], fill=C(main[1]), outline=C("P01"))
            d.polygon([(40, 72), (52, 72), (46, 82)], fill=C("P08"))
            d.line([44, 72, 46, 80], fill=C("P02")); d.line([48, 72, 46, 80], fill=C("P02"))
            for y in (86, 92):
                d.rectangle([41, y, 42, y + 1], fill=C(acc[1])); d.rectangle([50, y, 51, y + 1], fill=C(acc[1]))
            d.rectangle([12, 88, 22, 92], fill=C("P48"), outline=C("P01"))   # yellow armband
        else:
            d.rectangle([30, 76, 62, 95], fill=C(main[2]), outline=C("P01")); d.line([31, 77, 61, 77], fill=C(main[3]))
            d.line([46, 77, 46, 95], fill=C(main[0]))
            for x0 in (10, 64):
                d.rectangle([x0, 72, x0 + 22, 86], fill=C(main[3]), outline=C("P01"))
    elif t == "T11":                                              # suit: V lapels, shirt, tie
        d.polygon([(38, 70), (46, 84), (54, 70)], fill=C("P08"), outline=C("P01"))
        d.polygon([(45, 74), (47, 74), (48, 90), (46, 92), (44, 90)], fill=C(acc[0]), outline=C("P01"))
        d.line([38, 70, 46, 92], fill=C("P01")); d.line([54, 70, 46, 92], fill=C("P01"))
    elif t == "T12":                                              # vest over a shirt
        hivis = pf in ("PF-05", "PF-07")
        vest = (acc[1], acc[0]) if hivis else ("P06", "P05")
        d.polygon([(14, 80), (30, 72), (40, 74), (40, 96), (12, 96)], fill=C(vest[1]), outline=C("P01"))
        d.polygon([(78, 80), (62, 72), (52, 74), (52, 96), (82, 96)], fill=C(vest[1]), outline=C("P01"))
        if hivis:
            d.line([14, 88, 40, 88], fill=C("P08")); d.line([52, 88, 80, 88], fill=C("P08"))
    elif t == "T13":                                              # white coat + stethoscope
        d.polygon([(34, 70), (46, 86), (58, 70), (52, 70), (46, 80), (40, 70)], fill=C("P45"), outline=C("P01"))
        d.arc([34, 72, 58, 96], 200, 340, fill=C("P02"))
        d.ellipse([54, 86, 58, 90], fill=C("P07"), outline=C("P01"))


# ---------------------------------------------------------------- head gear / eye gear
def gear(f, p):
    g = p.get("gear")
    d = ImageDraw.Draw(f.img)
    if g == "HD15":                                               # officer peaked cap
        pf = p.get("faction") or "PF-01"
        crown = poly_mask([(22, 26), (26, 8), (50, 4), (68, 12), (66, 26)])
        shade(f, crown, [f"{pf}.0", f"{pf}.1", f"{pf}.2", f"{pf}.3"], light_x=28, strands=False)
        d.rectangle([24, 22, 66, 26], fill=C("P48")); d.line([24, 22, 66, 22], fill=C("P49")); d.line([24, 27, 66, 27], fill=C("P01"))
        d.polygon([(40, 27), (72, 27), (74, 31), (44, 31)], fill=C("P02"), outline=C("P01"))
        d.line([46, 28, 70, 28], fill=C("P04"))
        d.ellipse([44, 12, 52, 20], fill=C("P49"), outline=C("P47"))
    elif g in ("HD03", "HD04", "HD02"):
        ramp = {"HD03": ["P04", "P05", "P06", "P08"], "HD04": ["PF-01.0", "PF-01.1", "PF-01.2", "PF-01.3"],
                "HD02": ["P06", "P07", "P08", "P09"]}[g]
        dome = {(x, y) for x, y in ellipse_mask(44, 30, 21, 21) if y < 30}
        shade(f, dome, ramp, light_x=28, strands=False)
        d.rectangle([22, 28, 66, 31], fill=C(ramp[1]), outline=C("P01"))
        if g == "HD03":
            d.rectangle([42, 10, 46, 28], fill=C("P48"))
            d.polygon([(40, 30), (68, 30), (68, 34), (42, 34)], fill=C("P14"), outline=C("P01"))   # visor raised
        if g == "HD02":
            d.polygon([(20, 30), (70, 30), (72, 33), (18, 33)], fill=C("P08"), outline=C("P01"))
            d.rectangle([42, 14, 46, 20], fill=C("P53"))
    elif g == "HD05":
        crown = {(x, y) for x, y in ellipse_mask(44, 28, 20, 18) if y < 28}
        shade(f, crown, ["P51", "P52", "P53", "P54"], light_x=28, strands=False)
        d.polygon([(44, 26), (74, 26), (78, 30), (46, 31)], fill=C("P52"), outline=C("P01"))
        d.line([46, 27, 72, 27], fill=C("P54"))


def eyewear(f, p):
    e = p.get("eyes")
    if not e:
        return
    d = ImageDraw.Draw(f.img)
    ey = 44 + p.get("eye_dy", 0)
    if e in ("EY01", "EY02", "EY03"):
        tok = "P02" if e != "EY02" else "P03"
        if e == "EY03":                                           # half-moon readers sitting low
            d.arc([37, ey - 2, 47, ey + 5], 0, 180, fill=C(tok)); d.arc([52, ey - 2, 60, ey + 5], 0, 180, fill=C(tok))
            d.line([47, ey + 2, 52, ey + 2], fill=C(tok))
        elif e == "EY01":
            d.ellipse([37, ey - 5, 47, ey + 3], outline=C(tok)); d.ellipse([52, ey - 5, 60, ey + 3], outline=C(tok))
            d.line([47, ey - 1, 52, ey - 1], fill=C(tok))
            d.point((39, ey - 3), fill=C("P09"))
        else:
            d.rectangle([37, ey - 5, 47, ey + 3], outline=C(tok)); d.rectangle([52, ey - 5, 60, ey + 3], outline=C(tok))
            d.line([47, ey - 2, 52, ey - 2], fill=C(tok))
        d.line([30, ey - 2, 37, ey - 2], fill=C(tok))
    if e == "EY05":
        d.rectangle([36, ey - 5, 48, ey + 2], fill=C("P02"), outline=C("P01"))
        d.rectangle([51, ey - 5, 61, ey + 2], fill=C("P02"), outline=C("P01"))
        d.line([48, ey - 3, 51, ey - 3], fill=C("P01")); d.line([30, ey - 3, 36, ey - 3], fill=C("P01"))
        d.line([38, ey - 4, 42, ey - 4], fill=C("P05")); d.point((53, ey - 4), fill=C("P05"))


# ---------------------------------------------------------------- build
def portrait(p, expr):
    f = Face()
    hair_back(f, p)
    clothing(f, p)
    face = draw_face(f, p, p.get("skin", "S3"))
    features(f, p, p.get("skin", "S3"), expr)
    hair_front(f, p, face)
    gear(f, p)
    eyewear(f, p)
    return f.img


UNIQUE = [
    ("윤정인", "S-07 오버시어", dict(skin="S2", hair="HR07", hair_color="H1", female=True, tired=True, torso="T01",
                                  faction="PF-11", overseer=True, jaw=0.2, age=42, mole=(57, 52))),
    ("하도윤", "S-07 친구", dict(skin="S3", hair="HR08", hair_color="H2", torso="T01", faction="PF-11", jaw=0.3, age=19,
                              smudge=True)),
    ("육지환", "계엄사령관 대령", dict(skin="S4", hair="HR01", hair_color="H1", torso="T08", faction="PF-01", gear="HD15",
                                  jaw=1.0, chin=1, age=47)),
    ("조만석", "봉천 이장", dict(skin="S4", hair="HR01", hair_color="H5", torso="T03", jaw=0.6, age=68, stubble="P07")),
]
U_EXPR = ("기본", "미소", "분노", "슬픔", "놀람", "결의")

# module portraits: assembled from the map sprite's appearance code + one hand-retouch feature (SD-16 §8.3)
MODULE = [
    ("차명수", "M1-S3-HR05-H4-T11-1-PF11-HD00-EY03-PR020", dict(mole=(40, 53))),
    ("방금례", "E2-S2-HR08-H5-T11-2-PF11-HD00-EY02-PR019", dict()),
    ("신혜령", "F1-S2-HR06-H4-T13-1-PF11-HD00-EY00-PR011", dict(mole=(55, 47))),
    ("나채윤", "F1-S1-HR06-H1-T01-0-PF11-HD00-EY00-PR021", dict()),
    ("송지우", "K1-S3-HR07-H2-T01-1-PF11-HD00-EY00-PR022", dict()),
    ("도경철", "M2-S4-HR02-H4-T02-1-PF11-HD03-EY00-PR034", dict(scar=(52, 33, 5))),
    ("엄도현", "M1-S4-HR02-H1-T06-1-PF01-HD04-EY00-PR034", dict()),
    ("독사", "M1-S4-HR01-H1-T12-1-PF05-HD00-EY05-PR027", dict(scar=(36, 50, 4))),
    ("하숙자", "E2-S3-HR08-H4-T03-1-PF12-HD00-EY02-PR007", dict()),
    ("오봉수", "M2-S4-HR01-H2-T03-2-PF12-HD05-EY00-PR015", dict(stubble="P07")),
]
M_EXPR = ("기본", "긍정", "부정")


def from_code(code, extra):
    b, sk, hr, hc, t, worn, pf, hd, ey, pr = code.split("-")
    p = dict(skin=sk, hair=hr, hair_color=hc, torso=t, faction=None if pf == "PF00" else "PF-" + pf[2:],
             gear=None if hd == "HD00" else hd, eyes=None if ey == "EY00" else ey)
    p["female"] = b in ("F1", "F2", "E2")
    p["age"] = {"E1": 66, "E2": 64, "K1": 11}.get(b, 35)
    p["jaw"] = {"M2": 0.9, "M1": 0.5, "F1": 0.15, "F2": 0.3, "E1": 0.6, "E2": 0.3, "K1": 0.0}[b]
    if b == "K1":
        p["child"] = True; p["chin"] = -3; p["eye_dy"] = 2; p["mouth_dy"] = -1
    p.update(extra)
    return p


def main():
    out = os.path.join(ROOT, "samples")
    LW = 110
    sh = Image.new("RGBA", (LW + 6 * 100, len(UNIQUE) * 112 + 16), C("P12"))
    d = ImageDraw.Draw(sh); d.fontmode = "1"
    for k, ex in enumerate(U_EXPR):
        d.text((LW + k * 100 + 48, 2), ex, font=FONT, fill=C("P09"), anchor="ma")
    allowed = P.allowed_set(*P.SKIN.keys(), *P.HAIR.keys(), *P.PF.keys())
    bad = []
    for i, (name, role, p) in enumerate(UNIQUE):
        y = 16 + i * 112
        d.text((6, y + 40), name, font=FONT, fill=C("P09")); d.text((6, y + 54), role, font=F7, fill=C("P08"))
        for k, ex in enumerate(U_EXPR):
            im = portrait(p, ex)
            bad += check(im, allowed)
            d.rectangle([LW + k * 100, y, LW + k * 100 + 97, y + 97], fill=C("P11"))
            sh.alpha_composite(im, (LW + k * 100 + 1, y + 1))
    upscale(sh, 3).save(os.path.join(out, "17_portraits_unique_x3.png"))
    # module sheet: 10 NPCs x 3 expressions, 2 columns
    cols = 2
    rows = (len(MODULE) + 1) // cols
    ms = Image.new("RGBA", (cols * (90 + 3 * 100) + 8, rows * 104 + 18), C("P12"))
    d = ImageDraw.Draw(ms); d.fontmode = "1"
    for i, (name, code, extra) in enumerate(MODULE):
        p = from_code(code, extra)
        cx = 4 + (i % cols) * (90 + 3 * 100); cy = 16 + (i // cols) * 104
        d.text((cx, cy + 36), name, font=FONT, fill=C("P09"))
        d.text((cx, cy + 50), code.split("-")[0] + " " + code.split("-")[2] + " " + code.split("-")[4], font=F7, fill=C("P08"))
        for k, ex in enumerate(M_EXPR):
            im = portrait(p, ex)
            bad += check(im, allowed)
            d.rectangle([cx + 88 + k * 100, cy, cx + 88 + k * 100 + 97, cy + 97], fill=C("P11"))
            ms.alpha_composite(im, (cx + 89 + k * 100, cy + 1))
            if i < 2:
                d.text((cx + 88 + k * 100 + 48, 2), ex, font=FONT, fill=C("P09"), anchor="ma")
    upscale(ms, 2).save(os.path.join(out, "17_portraits_module_x2.png"))
    print("off-palette:", sorted(set(bad)) or 0)


if __name__ == "__main__":
    main()
