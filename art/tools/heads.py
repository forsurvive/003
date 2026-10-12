"""Head-anchor slots (SD-16 §5.5) with the canonical codes of SD-07b §3.4~3.6.
hair HR00~HR11 (HR10 later), head gear HD02 HD03 HD04 HD05 HD07 HD15, eye gear EY01 EY02 EY03 EY05 EY06.
Rules: hair first, gear over it; a hat switches hair to its 'under hat' state (HR07 top knot hidden, long hair and
tails stay visible below the rim); glasses are hidden facing N/NE (§5.3), goggles keep their strap.
The base sprite already carries HR03 (짧은 커트). For the samples the composite is applied to the idle bases
before the rig, which equals the per-frame head anchor because the rig moves the head rigidly with the torso."""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import parse

ROOT = os.path.dirname(os.path.dirname(__file__))
_G = None
H1 = [P.rgb(c) for c in P.HAIR["H1"]]
SKIN = [P.rgb(c) for c in P.SKIN["S3"]]
C = lambda t: P.rgb(t) + (255,)


def grids():
    global _G
    if _G is None:
        _G = parse(os.path.join(ROOT, "src/sprites/head_slots.txt"))
    return _G


def _map(img, table, box=(14, 14, 50, 44)):
    out = img.copy()
    px = out.load()
    m = {P.rgb(k) if not isinstance(k, tuple) else k: C(v) for k, v in table.items()}
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            p = px[x, y]
            if p[3] and p[:3] in m:
                px[x, y] = m[p[:3]]
    return out


def _hair_to_skin(img, rows=None, view=None):
    """HR00 민머리 / HR01 sides: hair pixels become scalp (skin) inside the given row filter."""
    out = img.copy()
    px = out.load()
    to = {H1[0]: SKIN[0], H1[1]: SKIN[1], H1[2]: SKIN[2], H1[3]: SKIN[3]}
    for y in range(18, 40):
        for x in range(18, 46):
            p = px[x, y]
            if p[3] and p[:3] in to and (rows is None or rows(x, y)):
                px[x, y] = to[p[:3]] + (255,)
    return out


def _perm(img):
    """HR11 파마: scalloped crown (bumps every other pixel on the outline) + regular curl highlights."""
    out = img.copy()
    px = out.load()
    hair = {(x, y) for y in range(18, 40) for x in range(18, 46) if px[x, y][3] and px[x, y][:3] in H1}
    for x, y in sorted(hair):
        if (x * 2 + y) % 3 == 0 and px[x, y][:3] in (H1[1], H1[2]):
            px[x, y] = C("H1.4")
    for x, y in sorted(hair):
        up, side = (x, y - 1), (x - 1 if x < 31 else x + 1, y)
        for nx, ny in (up, side):
            if px[nx, ny][3] and px[nx, ny][:3] == P.rgb("P01") and (nx + ny) % 2 == 0 and ny < 30:
                px[nx, ny] = C("H1.2")
                ox, oy = nx + (nx - x), ny + (ny - y)
                if not px[ox, oy][3]:
                    px[ox, oy] = C("P01")
    return out


def _kerchief(img, view):
    """HD07 머릿수건: cloth over the crown (hair rows above the brow) + a knot at the nape."""
    out = img.copy()
    px = out.load()
    cloth = {H1[0]: "P19", H1[1]: "P20", H1[2]: "P21", H1[3]: "P22"}
    limit = 27 if view in ("S", "SE") else 30
    for y in range(18, limit + 1):
        for x in range(18, 46):
            p = px[x, y]
            if p[3] and p[:3] in cloth:
                px[x, y] = C(cloth[p[:3]])
    for x in range(24, 40):                              # hem line
        p = px[x, limit]
        if p[3] and p[:3] in (P.rgb("P20"), P.rgb("P21"), P.rgb("P19"), P.rgb("P22")):
            px[x, limit] = C("P18")
    knot = {"N": (30, 31), "NE": (30, 31), "E": (25, 29), "SE": (25, 29)}.get(view)
    if knot:
        kx, ky = knot
        for dx, dy, t in ((0, 0, "P20"), (1, 0, "P21"), (2, 0, "P20"), (1, 1, "P19"), (0, 1, "P18"), (2, 1, "P18")):
            px[kx + dx, ky + dy] = C(t)
        for dx in range(-1, 4):
            for dy in (-1, 2):
                if not px[kx + dx, ky + dy][3]:
                    px[kx + dx, ky + dy] = C("P01")
    return out


GEAR_RECOLOR = {
    "HD02": ("HD03", {"P08": "P09", "P06": "P08", "P05": "P07", "P04": "P06", "P14": "P07", "P48": "P53"}),   # 안전모
    "HD04": ("HD03", {"P08": "PF-01.3", "P06": "PF-01.2", "P05": "PF-01.1", "P04": "PF-01.0",
                      "P14": "PF-01.1", "P48": "PF-01.1"}),                                                 # 계엄군 철모
}


def head(img, view, hair="HR03", color="H1", gear=None, eyes=None):
    g = grids()
    out = img.copy()
    if hair == "HR00":
        out = _hair_to_skin(out)
    elif hair == "HR01":                                   # 짧은 스포츠: sides and nape clipped to the scalp
        if view in ("S", "SE"):
            out = _hair_to_skin(out, lambda x, y: y >= 27)
        elif view == "E":
            out = _hair_to_skin(out, lambda x, y: y >= 28 and x >= 28 or y >= 31)
        else:
            out = _hair_to_skin(out, lambda x, y: y >= 31)
    elif hair == "HR02" and view in ("S", "SE"):           # 가르마: side part line
        for y in (24, 25, 26):
            out.putpixel((30 if view == "S" else 29, y), C("H1.1"))
    elif hair == "HR11":
        out = _perm(out)
    if hair in ("HR05", "HR06", "HR08") and f"{hair}_{view}" in g:
        out.alpha_composite(g[f"{hair}_{view}"])
    if hair in ("HR09", "HR04") and f"HR09_{view}" in g:   # tails; HR04 = the short low tie
        tail = g[f"HR09_{view}"]
        if hair == "HR04":
            tail = tail.crop((0, 0, 64, 37 if view in ("N", "NE") else 31))
        out.alpha_composite(tail)
    if hair == "HR07" and gear is None:                    # the top knot cannot sit under a hat
        out.alpha_composite(g[f"HR07_{view}"])
    if eyes and f"{eyes}_{view}" in g:
        out.alpha_composite(g[f"{eyes}_{view}"])
    if gear == "HD07":
        out = _kerchief(out, view)
    elif gear in GEAR_RECOLOR:
        src, table = GEAR_RECOLOR[gear]
        layer = _map(g[f"{src}_{view}"], table, box=(0, 0, 64, 64))
        out.alpha_composite(layer)
    elif gear:
        out.alpha_composite(g[f"{gear}_{view}"])
    if color != "H1":
        tgt = [P.rgb(c) for c in P.HAIR[color]]
        out = _map(out, {H1[i]: "#%02X%02X%02X" % tgt[i] for i in range(4)})
    return out
