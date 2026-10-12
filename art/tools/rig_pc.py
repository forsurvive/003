"""PC parts rig (SD-16 §5 파츠 리그, first pass).
Front/back walk: derived from idle by leg lift + arm swing + 1px bob.
Side walk: torso from a hand-drawn grid, legs/arms rasterised from joint angles, then outlined and shaded.
Writes samples/04_pc_walk_*.png (sheets + x6) and samples/04_pc_walk.gif."""
import os, sys, math
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import parse, upscale, sheet

ROOT = os.path.dirname(os.path.dirname(__file__))
C = lambda t: P.rgb(t) + (255,)
OUT = C("P01")
CLEAR = (0, 0, 0, 0)


def shift_region(img, box, dy=0, dx=0):
    """Move pixels inside box by (dx, dy); vacated pixels become transparent."""
    x0, y0, x1, y1 = box
    reg = img.crop(box)
    img.paste(Image.new("RGBA", reg.size, CLEAR), (x0, y0))
    img.alpha_composite(reg, (x0 + dx, y0 + dy))


def lift_leg(img, x0, x1, knee_y, k):
    """Raise the leg below the knee by k px (bent knee / lifted foot)."""
    if k <= 0:
        return
    reg = img.crop((x0, knee_y, x1, 61))
    img.paste(Image.new("RGBA", reg.size, CLEAR), (x0, knee_y))
    img.alpha_composite(reg, (x0, knee_y - k))


def walk_frontback(idle, arm_l=(23, 36, 27, 51), arm_r=(37, 36, 42, 51), leg_l=(26, 32), leg_r=(32, 38), knee=54):
    """6-frame walk for S/N/SE/NE from the idle frame (feet on y=60)."""
    frames = []
    # (left lift, right lift, bob, left arm dy, right arm dy)
    plan = [(0, 2, 0, 1, -1), (0, 1, 1, 1, -1), (0, 0, 0, 0, 0), (2, 0, 0, -1, 1), (1, 0, 1, -1, 1), (0, 0, 0, 0, 0)]
    for ll, rl, bob, la, ra in plan:
        f = idle.copy()
        lift_leg(f, leg_l[0], leg_l[1], knee, ll)
        lift_leg(f, leg_r[0], leg_r[1], knee, rl)
        if la:
            shift_region(f, arm_l, dy=la)
        if ra:
            shift_region(f, arm_r, dy=ra)
        if bob:
            upper = f.crop((0, 0, 64, 51))
            f.paste(Image.new("RGBA", (64, 51), CLEAR), (0, 0))
            f.alpha_composite(upper, (0, bob))
        frames.append(f)
    return frames


# ---------- side view (E) rasterised limbs ----------
def capsule(mask, a, b, r):
    (x0, y0), (x1, y1) = a, b
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(n + 1):
        t = i / n
        cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        R = int(r) + 2
        for dy in range(-R, R + 1):
            for dx in range(-R, R + 1):
                if (dx + 0.5) ** 2 + (dy + 0.5) ** 2 <= (r + 0.35) ** 2:
                    mask.add((int(math.floor(cx + dx)), int(math.floor(cy + dy))))


def limb(hip, thigh_deg, knee_deg, l1, l2, r):
    """Angles in degrees from straight down; positive = forward (east)."""
    a1 = math.radians(thigh_deg)
    knee = (hip[0] + l1 * math.sin(a1), hip[1] + l1 * math.cos(a1))
    a2 = math.radians(thigh_deg - knee_deg)
    foot = (knee[0] + l2 * math.sin(a2), knee[1] + l2 * math.cos(a2))
    return knee, foot


def paint_mask(img, mask, fill, shade_edge="back", ramp=("P44", "P45", "P46")):
    """Fill mask with a 3-tone ramp: front-lit edge, base, back shade; outline outer pixels."""
    pts = set(mask)
    xs = {}
    for x, y in pts:
        xs.setdefault(y, []).append(x)
    for x, y in pts:
        if not (0 <= x < 64 and 0 <= y < 64):
            continue
        nb = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        if any(n not in pts for n in nb):
            img.putpixel((x, y), OUT)
            continue
        row = xs[y]
        lo, hi = min(row), max(row)
        if x == lo + 1:
            col = ramp[0] if shade_edge == "front" else ramp[2]
        elif x == hi - 1:
            col = ramp[2] if shade_edge == "front" else ramp[0]
        else:
            col = ramp[1]
        img.putpixel((x, y), C(col))


def leg_layer(hip, thigh, knee_bend, near=True):
    img = Image.new("RGBA", (64, 64), CLEAR)
    knee, ankle = limb(hip, thigh, knee_bend, 7.0, 6.0, 2)
    m = set()
    capsule(m, hip, knee, 2.7)
    capsule(m, knee, ankle, 2.4)
    ramp = ("P46", "P45", "P44") if near else ("P45", "P44", "P43")
    paint_mask(img, m, None, "front", ramp)
    # boot: lower shin + foot pointing forward along the ground direction of the shin
    a = math.radians(thigh - knee_bend)
    boot = set()
    bx, by = ankle
    up = (bx - 3 * math.sin(a), by - 3 * math.cos(a))
    capsule(boot, up, (bx, by), 2.1)
    fwd = (bx + 3.5 * math.cos(a), by - 3.5 * math.sin(a) * 0.3)
    capsule(boot, (bx, by), fwd, 1.3)
    paint_mask(img, boot, None, "front", ("P05", "P04", "P03") if near else ("P04", "P03", "P02"))
    return img, max(y for _, y in boot)


def arm_layer(sh, swing):
    img = Image.new("RGBA", (64, 64), CLEAR)
    elbow, wrist = limb(sh, swing, -abs(swing) * 0.4 - 6, 5.5, 5.0, 1)
    m = set()
    capsule(m, sh, elbow, 1.9)
    capsule(m, elbow, wrist, 1.7)
    paint_mask(img, m, None, "front", ("P46", "P45", "P44"))
    # cuff + hand
    hx, hy = int(round(wrist[0])), int(round(wrist[1]))
    for dx, dy, col in [(0, -1, "P49"), (-1, -1, "P49"), (0, 0, "P41"), (-1, 0, "P40"), (0, 1, "P40"), (-1, 1, "P39")]:
        img.putpixel((hx + dx, hy + dy), C(col))
    for dx, dy in [(1, 0), (1, 1), (0, 2), (-1, 2), (-2, 0), (-2, 1), (1, -1), (-2, -1)]:
        if img.getpixel((hx + dx, hy + dy))[3] == 0:
            img.putpixel((hx + dx, hy + dy), OUT)
    return img


def walk_side(upper):
    """upper = torso+head without legs/near arm (64x64). Returns 6 frames, feet on y=60."""
    hip = (31, 46)
    # (near thigh, near knee, far thigh, far knee, arm swing, bob)
    plan = [(24, 6, -22, 4, -20, 0), (14, 18, -12, 2, -12, 1), (2, 4, 6, 42, 0, 0),
            (-22, 4, 24, 6, 20, 0), (-12, 2, 14, 18, 12, 1), (6, 42, 2, 4, 0, 0)]
    frames = []
    for nt, nk, ft, fk, sw, bob in plan:
        f = Image.new("RGBA", (64, 64), CLEAR)
        far, fy = leg_layer((hip[0] - 1, hip[1] + bob), ft, fk, near=False)
        near, ny = leg_layer((hip[0] + 1, hip[1] + bob), nt, nk, near=True)
        lowest = max(fy, ny)
        drop = 60 - lowest  # legs only: keep the lowest foot on the ground line
        f.alpha_composite(far, (0, drop))
        f.alpha_composite(upper, (0, bob))
        f.alpha_composite(near, (0, drop))
        f.alpha_composite(arm_layer((32, 38 + bob), sw), (0, 0))
        frames.append(f)
    return frames


def gif(frames, path, scale=6, ms=100, bg="P19"):
    out = []
    for fr in frames:
        b = Image.new("RGBA", fr.size, C(bg))
        b.alpha_composite(fr)
        out.append(upscale(b, scale).convert("P", palette=Image.ADAPTIVE))
    out[0].save(path, save_all=True, append_images=out[1:], duration=ms, loop=0, disposal=2)


if __name__ == "__main__":
    src = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_S.txt"))
    up = parse(os.path.join(ROOT, "src/sprites/pc_s07_upper_E.txt"))["upperE"]
    dg = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_diag.txt"))
    S = walk_frontback(src["idle0"])
    N = walk_frontback(src["idleN"])
    E = walk_side(up)
    SE = walk_frontback(dg["idleSE"], arm_l=(24, 36, 29, 51), arm_r=(37, 36, 41, 51), leg_l=(28, 33), leg_r=(33, 40))
    NE = walk_frontback(dg["idleNE"], arm_l=(24, 36, 29, 51), arm_r=(37, 36, 41, 51), leg_l=(28, 33), leg_r=(33, 40))
    fl = lambda seq: [f.transpose(Image.FLIP_LEFT_RIGHT) for f in seq]
    W, SW, NW = fl(E), fl(SE), fl(NE)
    rows = S + SE + E + NE + N + NW + W + SW
    sh = sheet(rows, 6, pad=2, bg=C("P19"))
    out = os.path.join(ROOT, "samples")
    sh.save(os.path.join(out, "04_pc_walk_sheet.png"))
    upscale(sh, 5).save(os.path.join(out, "04_pc_walk_sheet_x5.png"))
    # 4-direction loop gif (S, E, N, W side by side)
    combo = []
    for i in range(6):
        c = Image.new("RGBA", (64 * 8, 64), CLEAR)
        for k, seq in enumerate((S, SE, E, NE, N, NW, W, SW)):
            c.alpha_composite(seq[i], (k * 64, 0))
        combo.append(c)
    gif(combo, os.path.join(out, "04_pc_walk.gif"), scale=4, ms=100)
    print("ok")
