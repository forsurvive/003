"""Head-anchor slots (SD-16 §5.5): hair style + hair colour + head gear + eye gear on the PC head.
Rules: hair is drawn first, gear over it; a hat switches hair to its 'under hat' state (the bun is hidden,
bob ends stay visible below the rim); glasses are hidden facing N/NE (§5.3).
For this sample the composite is applied to the idle bases before the rig, which is equivalent to the
per-frame head anchor because the rig moves the head rigidly with the torso."""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import parse

ROOT = os.path.dirname(os.path.dirname(__file__))
_G = None
H1 = [P.rgb(c) for c in P.HAIR["H1"]]
SKIN = P.SKIN["S3"]


def grids():
    global _G
    if _G is None:
        _G = parse(os.path.join(ROOT, "src/sprites/head_slots.txt"))
    return _G


def _recolor_hair(img, hx):
    """H1 -> Hx for every hair pixel (base hair and overlays)."""
    if hx == "H1":
        return img
    out = img.copy()
    px = out.load()
    tgt = [P.rgb(c) + (255,) for c in P.HAIR[hx]]
    m = {c: tgt[i] for i, c in enumerate(H1)}
    for y in range(16, 42):
        for x in range(16, 48):
            p = px[x, y]
            if p[3] and p[:3] in m:
                px[x, y] = m[p[:3]]
    return out


def _buzz(img):
    """HR04 짧게 민 머리: the short-hair cap becomes scalp with dark stubble tone (outline kept)."""
    out = img.copy()
    px = out.load()
    to = {H1[0]: "S3.1", H1[1]: "S3.2", H1[2]: "S3.2", H1[3]: "S3.3"}
    for y in range(20, 36):
        for x in range(20, 44):
            p = px[x, y]
            if p[3] and p[:3] in to:
                px[x, y] = P.rgb(to[p[:3]]) + (255,)
    return out


def head(img, view, hair="HR01", color="H1", gear=None, eyes=None):
    g = grids()
    out = img.copy()
    if hair == "HR04":
        out = _buzz(out)
    elif hair == "HR02":
        out.alpha_composite(g[f"HR02_{view}"])
    elif hair == "HR03" and gear is None:              # the bun cannot sit under a hat
        out.alpha_composite(g[f"HR03_{view}"])
    if eyes == "EY01" and f"EY01_{view}" in g:
        out.alpha_composite(g[f"EY01_{view}"])
    if gear:
        out.alpha_composite(g[f"{gear}_{view}"])
    return _recolor_hair(out, color) if hair != "HR04" else out
