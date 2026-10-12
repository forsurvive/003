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
    if code in ("T08", "T11", "T12", "T13"):
        if code == "T13":                                   # 의료 가운: white, knee length
            main, acc = ["P06", "P07", "P08", "P09"], ["P46", "P45"]
        elif faction:
            main, acc = pf(faction)
        else:
            main, acc = ["P02", "P03", "P04", "P05"], ["P48", "P49"]
        if code == "T12":                                   # shirt under the vest is the faction main ramp
            hivis = faction in ("PF-05", "PF-07")
            vest = (acc[1], acc[0], acc[0]) if hivis else ("P06", "P05", "P04")
        m = dict(zip("abcd", main))
        torso = dict(m, Y=main[1], y=main[2], z=main[3])
        pants = dict(zip("abcd", ["P02", "P03", "P04", "P05"])) if code in ("T08", "T11") else m
        if code == "T13":
            pants = dict(zip("abcd", ["P43", "P44", "P45", "P46"]))    # scrubs under the gown
        spec = {"code": code, "torso": torso, "pants": pants, "boots": {}, "gloves": code == "T08",
                "sleeve": (main[3], main[2], main[1]), "sleeve_far": (main[2], main[1], main[0]), "cuff": main[0],
                "leg": (pants["d"], pants["c"], pants["b"]) if isinstance(pants, dict) else (main[3], main[2], main[1]),
                "leg_far": (pants["c"], pants["b"], pants["a"]),
                "boot": ("P05", "P04", "P03"), "boot_far": ("P04", "P03", "P02"), "pads": 0, "knee": None,
                "accent": acc}
        if code == "T08":                                   # 장교 외투: knee-length skirts, wide lapels, gold buttons
            spec.update(coat=(main[3], main[2], main[1], main[0]), skirt=(46, 53), buttons=acc[1])
        if code == "T13":
            spec.update(coat=("P09", "P08", "P07", "P06"), skirt=(46, 54))
        if code == "T11":                                   # 정장: V lapels, shirt, tie
            spec.update(lapels=("P09", "P08"), tie=acc[0])
        if code == "T12":
            spec.update(vest=vest)
        return spec
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
        if fit.get("coat"):                                   # coat / gown tail hanging past the hip
            c = fit["coat"]
            y0, y1 = fit["skirt"]
            d.rectangle([27, y0, 35, y1], fill=C("P01"))
            d.rectangle([28, y0, 34, y1 - 1], fill=C(c[1]))
            d.line([28, y0, 28, y1 - 1], fill=C(c[0])); d.line([34, y0, 34, y1 - 1], fill=C(c[2]))
            d.line([28, y1 - 1, 34, y1 - 1], fill=C(c[3]))
            if fit.get("buttons"):
                for y in (38, 41, 44):
                    d.point((36, y), fill=C(fit["buttons"]))
        if fit.get("vest"):
            v = fit["vest"]
            d.rectangle([30, 37, 36, 46], fill=C(v[1])); d.line([30, 37, 36, 37], fill=C(v[0]))
            if v[1] in ("PF-05.4", "PF-07.4"):
                d.line([30, 40, 36, 40], fill=C("P08"))
            d.line([30, 46, 36, 46], fill=C("P01")); d.rectangle([33, 41, 35, 43], fill=C(v[2]))
            d.line([33, 41, 35, 41], fill=C("P01"))
        if fit.get("lapels"):
            d.line([35, 37, 36, 40], fill=C(fit["lapels"][0])); d.point((36, 41), fill=C(fit["tie"]))
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
    if fit.get("coat"):                                       # long coat / gown over the thighs
        x0, y0c, x1, y1c = g["chest"]
        c = fit["coat"]
        ya, yb = fit["skirt"]
        L, Rr = x0 - 1, x1 + 1
        d.rectangle([L - 1, ya, Rr + 1, yb], fill=C("P01"))
        d.rectangle([L, ya, Rr, yb - 1], fill=C(c[1]))
        d.line([L, ya, L, yb - 1], fill=C(c[0])); d.line([Rr, ya, Rr, yb - 1], fill=C(c[2]))
        d.line([L, yb - 1, Rr, yb - 1], fill=C(c[3]))
        if not back:
            mid = (L + Rr) // 2
            d.line([mid, ya + 1, mid, yb], fill=C("P01"))             # front opening
            d.line([x0 + 1, 36, mid, 41], fill=C(c[0])); d.line([x1 - 1, 36, mid + 1, 41], fill=C(c[0]))  # lapels
            if fit.get("buttons"):
                for y in (39, 42, 45, 48):
                    d.point((mid - 2, y), fill=C(fit["buttons"])); d.point((mid + 2, y), fill=C(fit["buttons"]))
        else:
            mid = (L + Rr) // 2
            d.line([mid, yb - 3, mid, yb], fill=C("P01"))             # back vent
    if fit.get("vest") and view in GEOM:
        x0, y0, x1, y1 = g["chest"]
        v = fit["vest"]
        for (a, b) in ((x0 - 1, x0 + 2), (x1 - 2, x1 + 1)) if not back else ((x0 - 1, x1 + 1),):
            d.rectangle([a, 37, b, 46], fill=C(v[1])); d.line([a, 37, b, 37], fill=C(v[0]))
            d.line([a, 47, b, 47], fill=C("P01"))                     # angular hem below the belt
            if fit.get("code") == "T12" and v[1].startswith("PF-0") and v[1] in ("PF-05.4", "PF-07.4", "PF-05.5", "PF-07.5"):
                d.line([a, 40, b, 40], fill=C("P08"))                 # reflective stripe (형광 조끼)
        if not back:
            for px_ in (x0, x1 - 1):
                d.rectangle([px_ - 1, 42, px_ + 1, 44], fill=C(v[2])); d.line([px_ - 1, 42, px_ + 1, 42], fill=C("P01"))
    if fit.get("lapels") and view in ("S", "SE"):
        x0, y0, x1, y1 = g["chest"]
        mid = (x0 + x1) // 2
        d.polygon([(mid - 2, 36), (mid + 3, 36), (mid + 1, 41), (mid, 41)], fill=C(fit["lapels"][0]))
        d.line([mid, 37, mid, 43], fill=C(fit["tie"])); d.line([mid + 1, 37, mid + 1, 42], fill=C(fit["tie"]))
    if fit.get("knee") and view in ("S", "N"):
        for kx in (27, 33):
            d.rectangle([kx, 50, kx + 3, 52], fill=C(fit["knee"][1]))
            d.line([kx, 50, kx + 3, 50], fill=C(fit["knee"][0]))
    return out
