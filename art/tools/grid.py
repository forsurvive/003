"""Text-grid pixel art format (SD-16 §13.2) -> PIL images.

File format
  @key <char> <token>      colour key; token per palette.resolve, '-' = transparent
  @size <w> <h>            canvas size for following frames (default 64 64)
  @origin <x> <y>          anchor (metadata only; feet point for characters)
  @frame <name> [x y] [mirror]  start a frame; rows placed at (x, y). With 'mirror', each row is the
                           left half and is mirrored to the right (a row containing '|' is taken literally, '|' removed)
  #...                     comment
Rows use one char per pixel. Spaces and '.' are transparent unless keyed otherwise.
Keys declared before the first @frame are shared; keys inside a frame block extend/override for that frame.
"""
import sys, os
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import palette


def parse(path):
    shared = {".": None, " ": None}
    size = (64, 64)
    origin = (32, 60)
    frames = {}
    order = []
    cur = None
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if line.startswith("#") and not cur:
            continue
        if line.startswith("@"):
            parts = line.split()
            cmd = parts[0]
            if cmd == "@key":
                ch = parts[1] if parts[1] != "SPACE" else " "
                col = None if parts[2] == "-" else palette.rgb(parts[2])
                (cur["keys"] if cur else shared)[ch] = col
            elif cmd == "@size":
                size = (int(parts[1]), int(parts[2]))
            elif cmd == "@origin":
                origin = (int(parts[1]), int(parts[2]))
            elif cmd == "@frame":
                name = parts[1]
                xy = (int(parts[2]), int(parts[3])) if len(parts) >= 4 else (0, 0)
                mirror = "mirror" in parts[4:]
                cur = {"name": name, "xy": xy, "rows": [], "keys": {}, "size": size, "origin": origin, "mirror": mirror}
                frames[name] = cur
                order.append(name)
            continue
        if cur is not None:
            if line.startswith("#"):
                continue
            cur["rows"].append(line)
    out = {}
    for name in order:
        f = frames[name]
        keys = dict(shared)
        keys.update(f["keys"])
        img = Image.new("RGBA", f["size"], (0, 0, 0, 0))
        px = img.load()
        x0, y0 = f["xy"]
        # trim leading/trailing empty rows
        rows = f["rows"]
        while rows and not rows[-1].strip():
            rows = rows[:-1]
        if f.get("mirror"):
            half = max([len(r) for r in rows if "|" not in r] or [0])
            rows = [r.ljust(half, ".") + r.ljust(half, ".")[::-1] if "|" not in r else r.replace("|", "") for r in rows]
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch not in keys:
                    raise ValueError(f"{path}:{name}: unknown key {ch!r} at row {j} col {i}")
                c = keys[ch]
                if c is None:
                    continue
                x, y = x0 + i, y0 + j
                if 0 <= x < f["size"][0] and 0 <= y < f["size"][1]:
                    px[x, y] = c + (255,)
        img.info["origin"] = f["origin"]
        out[name] = img
    return out


def upscale(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def sheet(imgs, cols, pad=2, bg=(40, 38, 44, 255)):
    w = max(i.width for i in imgs)
    h = max(i.height for i in imgs)
    rows = (len(imgs) + cols - 1) // cols
    s = Image.new("RGBA", (cols * (w + pad) + pad, rows * (h + pad) + pad), bg)
    for n, im in enumerate(imgs):
        s.alpha_composite(im, (pad + (n % cols) * (w + pad), pad + (n // cols) * (h + pad)))
    return s


def check(img, allowed):
    """Return list of problems: off-palette colours, partial alpha (SD-16 §3.8, §13.5)."""
    bad = set()
    alpha = 0
    for r, g, b, a in img.getdata():
        if a == 0:
            continue
        if a != 255:
            alpha += 1
        if (r, g, b) not in allowed:
            bad.add((r, g, b))
    probs = []
    if bad:
        probs.append(f"off-palette colours: {sorted(bad)[:6]}{'...' if len(bad) > 6 else ''}")
    if alpha:
        probs.append(f"partial alpha pixels: {alpha}")
    return probs


def thin_outline(img, ink=None, passes=4):
    """repeat _thin_once until nothing changes (a thinned band can expose the next one)."""
    for _ in range(passes):
        nxt = _thin_once(img, ink)
        if nxt.tobytes() == img.tobytes():
            break
        img = nxt
    return img


def _thin_once(img, ink=None):
    """SD-16 §13.5-3: silhouette outline is exactly 1px of P01. Where the edge ink pixel has a second ink pixel
    inside it followed by coloured fill, the second one becomes the fill's colour one step darker (a shade, not a
    line). 3px+ ink masses (gaps between legs, dark hair mass) are left alone. Returns a new image."""
    ink = ink or palette.rgb("P01")
    out = img.copy()
    px, po = img.load(), out.load()
    w, h = img.size
    op = lambda x, y: 0 <= x < w and 0 <= y < h and px[x, y][3]
    for y in range(h):
        for x in range(w):
            if not op(x, y) or px[x, y][:3] != ink:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if op(x + dx, y + dy):
                    continue
                ix, iy, jx, jy = x - dx, y - dy, x - 2 * dx, y - 2 * dy
                if op(ix, iy) and px[ix, iy][:3] == ink and op(jx, jy) and px[jx, jy][:3] != ink:
                    dk = palette.step(px[jx, jy][:3], -1)
                    po[ix, iy] = (dk if dk != ink else px[jx, jy][:3]) + (255,)
    return out
