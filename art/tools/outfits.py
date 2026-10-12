"""Torso equipment families for the reference sample #5 (SD-16 §5.1, §5.9, §12.3 #5).
T01 S-07 jumpsuit (base), T02 vault security riot suit, T03 wasteland casual, T06 combat armour (PF-01 계엄군).

An outfit = (a) colour remap of the jumpsuit keys per body region (torso / trousers / boots / hands),
(b) silhouette patches drawn per view (S, N, SE, NE, E-upper) and (c) ramps the rig uses for IK legs/arms.
Faction palette swap: every outfit names its main ramp by role, so PF-xx can replace it (§5.8)."""
import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import palette as P


def C(t):
    return P.rgb(t) + (255,)


JUMP = {"a": "P43", "b": "P44", "c": "P45", "d": "P46", "Y": "P48", "y": "P49", "z": "P50",
        "k": "P02", "l": "P03", "m": "P04"}
SKIN = P.SKIN["S3"]


def pf(code):
    """Faction main ramp (dark -> light) and accents from PF-xx."""
    return [f"{code}.{i}" for i in range(4)], [f"{code}.4", f"{code}.5"]


def make(code, faction=None):
    """Return the outfit spec. faction: PF-xx code that replaces the main ramp (T02/T06)."""
    if code == "T01":
        return {"code": code, "torso": {}, "pants": {}, "boots": {}, "gloves": False,
                "sleeve": ("P46", "P45", "P44"), "sleeve_far": ("P45", "P44", "P43"), "cuff": "P49",
                "leg": ("P46", "P45", "P44"), "leg_far": ("P45", "P44", "P43"),
                "boot": ("P05", "P04", "P03"), "boot_far": ("P04", "P03", "P02"), "pads": 0, "knee": None}
    if code == "T02":
        main = ["P43", "P44", "P45", "P46"]
        if faction:
            main, _ = pf(faction)
        m = dict(zip("abcd", main))
        return {"code": code, "torso": m, "pants": m, "boots": {}, "gloves": True,
                "sleeve": (main[3], main[2], main[1]), "sleeve_far": (main[2], main[1], main[0]), "cuff": "P02",
                "leg": (main[3], main[2], main[1]), "leg_far": (main[2], main[1], main[0]),
                "boot": ("P05", "P04", "P03"), "boot_far": ("P04", "P03", "P02"),
                "pads": 1, "pad_ramp": ("P08", "P07", "P06", "P05"), "chest": ("P07", "P06", "P05"),
                "badge": "P48", "knee": ("P07", "P05")}
    if code == "T03":
        torso = {"a": "P16", "b": "P17", "c": "P18", "d": "P19", "Y": "P07", "y": "P08", "z": "P09"}
        pants = {"a": "P28", "b": "P29", "c": "P30", "d": "P31"}
        return {"code": code, "torso": torso, "pants": pants,
                "boots": {"k": "P16", "l": "P17", "m": "P18"}, "gloves": False,
                "sleeve": ("P19", "P18", "P17"), "sleeve_far": ("P18", "P17", "P16"), "cuff": "P16",
                "leg": ("P31", "P30", "P29"), "leg_far": ("P30", "P29", "P28"),
                "boot": ("P19", "P18", "P16"), "boot_far": ("P18", "P17", "P16"),
                "pads": 0, "scarf": ("P27", "P26", "P25", "P24"), "hood": ("P19", "P17", "P16"), "knee": None}
    if code == "T06":
        main, acc = pf(faction or "PF-01")
        m = dict(zip("abcd", main))
        torso = dict(m, Y=main[0], y=main[1], z=main[2])
        return {"code": code, "torso": torso, "pants": m, "boots": {"k": "P01", "l": "P02", "m": "P03"},
                "gloves": True, "sleeve": (main[3], main[2], main[1]), "sleeve_far": (main[2], main[1], main[0]),
                "cuff": "P02", "leg": (main[3], main[2], main[1]), "leg_far": (main[2], main[1], main[0]),
                "boot": ("P03", "P02", "P01"), "boot_far": ("P02", "P01", "P01"),
                "pads": 2, "pad_ramp": (main[3], main[2], main[1], main[0]), "chest": (main[3], main[2], main[1]),
                "badge": acc[1], "knee": (main[3], main[1]), "pouch": (main[1], main[0])}
    raise KeyError(code)


def _recolor(img, fit):
    """Region-aware remap of the jumpsuit keys: torso (y<47), trousers (47..54), boots (>=55), hands."""
    out = img.copy()
    px = out.load()
    inv = {P.rgb(v): k for k, v in JUMP.items()}
    skin = {P.rgb(c): i for i, c in enumerate(SKIN)}
    for y in range(64):
        for x in range(64):
            r, g, b, a = px[x, y]
            if not a:
                continue
            k = inv.get((r, g, b))
            if y >= 55:
                table = fit["boots"]
            elif y >= 47:
                table = fit["pants"]
            else:
                table = fit["torso"]
            if k and k in table:
                px[x, y] = C(table[k])
            elif fit["gloves"] and (r, g, b) in skin and y >= 42:
                px[x, y] = C(("P01", "P02", "P02", "P03", "P04")[skin[(r, g, b)]])
    return out


def _box(d, x0, y0, x1, y1, ramp, out="P01"):
    """Small armour plate: outline, lit top/left row, base, shade bottom row."""
    lit, base, shade = ramp[0], ramp[1], ramp[2]
    d.rectangle([x0, y0, x1, y1], fill=C(out))
    if x1 - x0 >= 2 and y1 - y0 >= 2:
        d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=C(base))
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=C(lit))
        d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=C(shade))


# per-view anchor geometry (left/right shoulder boxes, chest box, neck)
GEOM = {
    "S": {"lsh": (24, 36, 27), "rsh": (36, 36, 39), "chest": (28, 37, 35, 44), "neck": (29, 34, 35)},
    "N": {"lsh": (24, 36, 27), "rsh": (36, 36, 39), "chest": (28, 37, 35, 44), "neck": (29, 34, 35)},
    "SE": {"lsh": (25, 36, 28), "rsh": (35, 36, 38), "chest": (29, 37, 34, 44), "neck": (30, 34, 35)},
    "NE": {"lsh": (25, 36, 28), "rsh": (35, 36, 38), "chest": (29, 37, 34, 44), "neck": (30, 34, 35)},
}


def dress(img, fit, view):
    """Apply an outfit to a base frame. view in S, N, SE, NE, E (E = upper torso for the side rig)."""
    out = _recolor(img, fit)
    d = ImageDraw.Draw(out)
    code = fit["code"]
    if view == "E":
        if fit.get("chest"):                                  # chest plate bulges past the profile
            bulge = 1 if fit["pads"] == 1 else 2
            _box(d, 33, 37, 37 + bulge, 44, fit["chest"])
            if fit.get("badge"):
                d.point((35, 39), fill=C(fit["badge"]))
        if fit.get("hood"):                                   # bunched hood standing off the nape
            _box(d, 24, 33, 29, 38, fit["hood"])
            _box(d, 27, 44, 30, 49, fit["hood"])             # coat tail past the hip
        if fit.get("scarf"):
            s = fit["scarf"]
            d.rectangle([30, 34, 36, 36], fill=C(s[1])); d.line([30, 34, 36, 34], fill=C(s[0]))
            d.line([30, 36, 36, 36], fill=C(s[2])); d.rectangle([35, 37, 36, 39], fill=C(s[2]))
        if fit.get("pouch"):
            _box(d, 29, 43, 32, 46, (fit["pouch"][0], fit["pouch"][0], fit["pouch"][1]))
        return out
    g = GEOM[view]
    back = view in ("N", "NE")
    if fit.get("chest"):
        x0, y0, x1, y1 = g["chest"]
        _box(d, x0, y0, x1, y1 - (0 if code == "T06" else 1), fit["chest"])
        if fit.get("badge") and not back:
            d.rectangle([x1 - 3, y0 + 2, x1 - 2, y0 + 3], fill=C(fit["badge"]))
        if code == "T06":
            d.line([x0 + 1, y0 + 4, x1 - 1, y0 + 4], fill=C(fit["chest"][2]))   # plate seam
    if fit["pads"]:
        e = fit["pads"]
        lx, ly, lx1 = g["lsh"]
        rx, ry, rx1 = g["rsh"]
        pr = fit["pad_ramp"]
        _box(d, lx - e, ly - (e - 1), lx1 + 1, ly + 3 + e, pr)
        _box(d, rx - 1, ry - (e - 1), rx1 + e, ry + 3 + e, pr)
    if fit.get("pouch") and not back:
        x0, y0, x1, y1 = g["chest"]
        for px_ in (x0, x1 - 3):
            _box(d, px_, 44, px_ + 3, 47, (fit["pouch"][0], fit["pouch"][0], fit["pouch"][1]))
    if fit.get("scarf"):
        s = fit["scarf"]
        nx, ny, _ = g["neck"]
        d.rectangle([nx - 1, ny + 1, nx + 6, ny + 2], fill=C(s[1])); d.line([nx - 1, ny + 1, nx + 6, ny + 1], fill=C(s[0]))
        d.line([nx - 1, ny + 3, nx + 6, ny + 3], fill=C(s[2]))
        if not back:                                          # knot tail
            d.rectangle([nx + 4, ny + 4, nx + 5, ny + 6], fill=C(s[2])); d.point((nx + 5, ny + 7), fill=C(s[3]))
        else:
            _box(d, nx - 1, ny - 1, nx + 6, ny + 2, fit["hood"])   # hood bunched behind the neck
    if fit.get("hood"):                                       # field-coat hem flaring past the hips
        x0, y0, x1, y1 = g["chest"]
        h = fit["hood"]
        for (a, b) in ((x0 - 2, x0 + 1), (x1 - 1, x1 + 2)):
            d.rectangle([a, 45, b, 49], fill=C("P01"))
            d.rectangle([a + 1, 45, b - 1, 48], fill=C(h[1]))
            d.line([a + 1, 45, b - 1, 45], fill=C(h[0]))
        if back:
            d.rectangle([x0 - 1, 45, x1 + 1, 49], fill=C("P01"))
            d.rectangle([x0, 45, x1, 48], fill=C(h[1])); d.line([x0, 45, x1, 45], fill=C(h[0]))
    if fit.get("knee") and view in ("S", "N"):
        for kx in (27, 33):
            d.rectangle([kx, 50, kx + 3, 52], fill=C(fit["knee"][1]))
            d.line([kx, 50, kx + 3, 50], fill=C(fit["knee"][0]))
    return out
