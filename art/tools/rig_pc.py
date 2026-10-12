"""PC parts rig (SD-16 §3.6, §5) with the no-slide locomotion rule (SD-16 §3.6.3).

Locomotion frames advance by distance travelled, not by time, and the sprite is drawn at a position that
steps forward by exactly one frame-distance whenever the frame changes. So during a stance the planted foot
must move backwards relative to the hip by exactly that frame-distance each frame: then it stays fixed on
the ground. Side (E/W) and diagonal legs are solved with 2-bone IK from foot targets that obey this;
front/back (S/N) legs are derived from the idle frame (foot lift + bob) and only the cadence is locked.

  walk  6 frames, 6 px/frame (cycle 36 px)    run  6 frames, 8 px/frame (cycle 48 px, 2 flight frames)
  diagonal steps are (4,4) px walk / (6,6) px run per frame.

Writes samples/04_pc_walk_sheet*.png, 04_pc_run_sheet*.png, 04_pc_walk.gif, 04_pc_run.gif and
(foot-lock report) samples/04_pc_footlock.txt."""
import os, sys, math
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import parse, upscale, sheet
import outfits as O
import heads as HD

FIT = O.make("T01")   # current torso-equipment family (set by build_all)

ROOT = os.path.dirname(os.path.dirname(__file__))
C = lambda t: P.rgb(t) + (255,)
OUT = C("P01")
CLEAR = (0, 0, 0, 0)
GROUND = 60          # sole line (frame origin y)

# frame-distance per locomotion mode: (side px, diagonal (dx, dy) px)
STEP = {"walk": (6, (4, 4)), "run": (8, (6, 6))}


# ---------------------------------------------------------------- shared helpers
def shift_region(img, box, dy=0, dx=0):
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


def paint_mask(img, mask, ramp, lit_left=True):
    """3-tone fill (lit edge, base, shade edge) with a 1px outline on the outer border."""
    pts = set(mask)
    rows = {}
    for x, y in pts:
        rows.setdefault(y, []).append(x)
    for x, y in pts:
        if not (0 <= x < 64 and 0 <= y < 64):
            continue
        if any(n not in pts for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
            img.putpixel((x, y), OUT)
            continue
        lo, hi = min(rows[y]), max(rows[y])
        if x == lo + 1:
            col = ramp[0] if lit_left else ramp[2]
        elif x == hi - 1:
            col = ramp[2] if lit_left else ramp[0]
        else:
            col = ramp[1]
        img.putpixel((x, y), C(col))


def ik(hip, ankle, l1, l2, bend=1):
    """2-bone IK in screen space; the knee bends toward +x (bend=1) or -x. Ankle is clamped to reach."""
    hx, hy = hip
    ax, ay = ankle
    dx, dy = ax - hx, ay - hy
    d = math.hypot(dx, dy)
    reach = l1 + l2 - 0.05
    if d > reach:
        ax, ay = hx + dx * reach / d, hy + dy * reach / d
        dx, dy, d = ax - hx, ay - hy, reach
    base = math.atan2(dx, dy)                       # angle from straight down, +x positive
    a = math.acos(max(-1, min(1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    th = base + bend * a
    knee = (hx + l1 * math.sin(th), hy + l1 * math.cos(th))
    return knee, (ax, ay)


def boot(mask, ankle, planted, fwd=(1.0, 0.0), toe=3.5):
    """Boot = shaft capsule + foot capsule. A planted boot is flat (same pixels every stance frame)."""
    ax, ay = ankle
    capsule(mask, (ax, ay - 2.5), (ax, ay), 2.1)
    if planted:
        capsule(mask, (ax, ay), (ax + toe * fwd[0], ay + toe * fwd[1] * 0.5), 1.3)
    else:                                           # toe drops a little while the foot swings
        capsule(mask, (ax, ay), (ax + toe * 0.85 * fwd[0], ay + 1.2 + toe * fwd[1] * 0.4), 1.3)


SOLE = 1  # ankle sits this many px above the sole line (measured from the boot capsule)


def leg(hip, foot, lift, planted, near, fwd=(1.0, 0.0), l1=7.6, l2=6.8):
    """foot = (x of the ankle, ground) target; lift = px above ground. Returns layer + ankle pos."""
    img = Image.new("RGBA", (64, 64), CLEAR)
    ankle_t = (foot[0], GROUND - SOLE - lift)
    knee, ankle = ik(hip, ankle_t, l1, l2, 1 if fwd[0] >= 0 else -1)
    m = set()
    capsule(m, hip, knee, 2.7)
    capsule(m, knee, ankle, 2.4)
    paint_mask(img, m, FIT["leg"] if near else FIT["leg_far"])
    knee_plate(img, knee)
    b = set()
    a = (round(ankle[0]), round(ankle[1])) if planted else ankle
    boot(b, a, planted, fwd)
    paint_mask(img, b, FIT["boot"] if near else FIT["boot_far"])
    return img, b


def knee_plate(img, knee):
    if not FIT.get("knee"):
        return
    kx, ky = int(round(knee[0])), int(round(knee[1]))
    for dx in (-1, 0, 1):
        for dy in (-1, 0):
            img.putpixel((kx + dx, ky + dy), C(FIT["knee"][1] if dy == 0 else FIT["knee"][0]))
    for dx, dy in ((-2, -1), (-2, 0), (2, -1), (2, 0), (-1, -2), (0, -2), (1, -2), (-1, 1), (0, 1), (1, 1)):
        img.putpixel((kx + dx, ky + dy), OUT)


def leg_diag(hip, ankle_t, planted, near, fwd, lift):
    """Diagonal-view leg: in 3/4 the thigh and shin are foreshortened toward the camera, so the knee sits
    just off the hip-ankle line, pushed along the facing direction as the knee comes up."""
    img = Image.new("RGBA", (64, 64), CLEAR)
    (hx, hy), (ax, ay) = hip, ankle_t
    bend = 0.8 + lift * 0.45
    knee = ((hx + ax) / 2 + bend * fwd[0], (hy + ay) / 2 + bend * fwd[1] * 0.4)
    m = set()
    capsule(m, hip, knee, 2.7)
    capsule(m, knee, (ax, ay), 2.4)
    paint_mask(img, m, FIT["leg"] if near else FIT["leg_far"])
    knee_plate(img, knee)
    b = set()
    boot(b, (round(ax), round(ay)) if planted else (ax, ay), planted, fwd, toe=2.5)
    paint_mask(img, b, FIT["boot"] if near else FIT["boot_far"])
    return img, b


def arm(sh, swing, bend=6, near=True):
    img = Image.new("RGBA", (64, 64), CLEAR)
    a1 = math.radians(swing)
    elbow = (sh[0] + 5.5 * math.sin(a1), sh[1] + 5.5 * math.cos(a1))
    a2 = math.radians(swing + bend + abs(swing) * 0.4)
    wrist = (elbow[0] + 5.0 * math.sin(a2), elbow[1] + 5.0 * math.cos(a2))
    m = set()
    capsule(m, sh, elbow, 1.9)
    capsule(m, elbow, wrist, 1.7)
    paint_mask(img, m, FIT["sleeve"] if near else FIT["sleeve_far"])
    hx, hy = int(round(wrist[0])), int(round(wrist[1]))
    cuff = FIT["cuff"]
    hand = ("P03", "P02", "P02", "P01") if FIT["gloves"] else ("P41", "P40", "P40", "P39")
    for dx, dy, col in [(0, -1, cuff), (-1, -1, cuff), (0, 0, hand[0]), (-1, 0, hand[1]), (0, 1, hand[2]), (-1, 1, hand[3])]:
        img.putpixel((hx + dx, hy + dy), C(col))
    for dx, dy in [(1, 0), (1, 1), (0, 2), (-1, 2), (-2, 0), (-2, 1), (1, -1), (-2, -1)]:
        if img.getpixel((hx + dx, hy + dy))[3] == 0:
            img.putpixel((hx + dx, hy + dy), OUT)
    return img


def shear(img, lean):
    """Forward lean for running: head +lean px, chest +lean//2, hips 0."""
    if not lean:
        return img
    out = Image.new("RGBA", img.size, CLEAR)
    for y in range(64):
        k = lean if y < 34 else (lean // 2 if y < 42 else 0)
        out.alpha_composite(img.crop((0, y, 64, y + 1)), (k, y))
    return out


# ---------------------------------------------------------------- gait tables
# Per frame, per foot: (x offset of the ankle from the hip in frame-distance units of the cycle, lift px, planted)
# Stance x offsets fall by exactly 1 step per frame -> the planted foot is fixed on the ground.
def gait(mode):
    if mode == "walk":     # contact, passing, push | toe-off, swing, reach   (6 px per frame)
        A = [(+1.0, 0, True), (0.0, 0, True), (-1.0, 0, True), (-1.4, 3, False), (-0.1, 4, False), (+0.9, 1, False)]
        hip = [1, -1, 0, 1, -1, 0]            # hip y offset: low at contact, high at passing
        arm = [-22, 0, 20, 22, 0, -20]
        return A, hip, arm, 0
    # run: contact, push, flight | swing-high, swing-fwd, flight-reach          (8 px per frame)
    A = [(+0.5, 0, True), (-0.5, 0, True), (-1.25, 3, False), (-0.6, 7, False), (+0.3, 6, False), (+1.0, 2, False)]
    hip = [1, 0, -1, 1, 0, -1]
    arm = [-34, 10, 34, 34, -10, -34]
    return A, hip, arm, 2


def walk_side(upper, mode="walk"):
    """E-facing locomotion. upper = head+torso without legs/near arm."""
    step = STEP[mode][0]
    A, hipdy, armsw, lean = gait(mode)
    hip0 = (31, 46)
    frames, feet = [], []
    for f in range(6):
        hip = (hip0[0], hip0[1] + hipdy[f])
        fa = A[f]
        fb = A[(f + 3) % 6]
        far_img, far_b = leg((hip[0] - 1, hip[1]), (hip[0] - 1 + round(fb[0] * step), 0), fb[1], fb[2], False)
        near_img, near_b = leg((hip[0] + 1, hip[1]), (hip[0] + 1 + round(fa[0] * step), 0), fa[1], fa[2], True)
        fr = Image.new("RGBA", (64, 64), CLEAR)
        fr.alpha_composite(far_img)
        fr.alpha_composite(shear(upper, lean), (0, hipdy[f]))
        fr.alpha_composite(near_img)
        bend = 6 if mode == "walk" else 50
        fr.alpha_composite(arm((32 + lean // 2, 38 + hipdy[f]), armsw[f], bend))
        if FIT["pads"]:
            from PIL import ImageDraw
            e = FIT["pads"]
            sx_, sy_ = 32 + lean // 2, 38 + hipdy[f]
            O._box(ImageDraw.Draw(fr), sx_ - 2 - e, sy_ - 2 - e // 2, sx_ + 2 + e, sy_ + 2, FIT["pad_ramp"])
        frames.append(fr)
        feet.append({"near": (fa[2], near_b), "far": (fb[2], far_b)})
    return frames, feet


def strip_legs(img, y0):
    """Clear everything from row y0 down (the IK legs replace it)."""
    out = img.copy()
    out.paste(Image.new("RGBA", (64, 64 - y0), CLEAR), (0, y0))
    return out


def walk_diag(full, mode="walk", back=False):
    """SE (back=False) / NE (back=True) locomotion. Legs re-solved by IK under the idle torso.
    Both stance components are exact: the forward foot sits lower on screen (oblique 3/4 projection), so
    the planted boot moves (-4,-4)/(-6,-6) px per frame against a body that steps (+4,+4)/(+6,+6)."""
    sx, sy = STEP[mode][1]
    A, hipdy, armsw, lean = gait(mode)
    upper = strip_legs(full, 48)
    # the character's right leg is the near one: screen-left facing SE, screen-right facing NE
    hips = {"near": (30, 47), "far": (35, 47)} if not back else {"near": (35, 47), "far": (30, 47)}
    vdir = 1 if not back else -1
    fwd = (0.8, 0.6 * vdir)
    frames, feet = [], []
    for f in range(6):
        layers = {}
        for name, ph in (("near", A[f]), ("far", A[(f + 3) % 6])):
            hx, hy = hips[name]
            hy += hipdy[f]
            if ph[2]:     # stance: exact ground track, forward foot lower on screen
                ox, oy, lift = round(ph[0] * sx), round(ph[0] * sy) * vdir - 1, 0
            else:         # swing: free path, kept compact so the knee reads
                ox, oy, lift = round(ph[0] * sx * 0.6), round(ph[0] * sy * 0.35) * vdir - 1, ph[1] * 0.7
            ankle = (hx + ox, GROUND - SOLE + oy - lift)
            img, b = leg_diag((hx, hy), ankle, ph[2], name == "near", fwd, lift)
            layers[name] = (img, b, ph[2])
        fr = Image.new("RGBA", (64, 64), CLEAR)
        order = ("far", "near")
        fr.alpha_composite(layers[order[0]][0])
        up = upper.copy()
        sw = (1 if mode == "walk" else 2) * (1 if A[f][0] > 0 else -1 if A[f][0] < 0 or A[f][1] > 4 else 0)
        if sw:
            shift_region(up, (24, 36, 30, 48), dy=sw)       # screen-left arm
            shift_region(up, (36, 36, 41, 48), dy=-sw)      # screen-right arm
        fr.alpha_composite(up, (0, hipdy[f]))
        fr.alpha_composite(layers[order[1]][0])
        frames.append(fr)
        feet.append({k: (v[2], v[1]) for k, v in layers.items()})
    return frames, feet


def walk_frontback(idle, mode="walk", arm_l=(23, 36, 27, 51), arm_r=(37, 36, 42, 51), leg_l=(26, 32), leg_r=(32, 38), knee=54):
    """S/N locomotion from the idle frame. Cadence is distance-locked; foot lift and bob follow the same
    contact/passing timing as the side gait."""
    if mode == "walk":
        plan = [(0, 2, 0, 1, -1), (0, 3, 1, 1, -1), (0, 1, 0, 0, 0), (2, 0, 0, -1, 1), (3, 0, 1, -1, 1), (1, 0, 0, 0, 0)]
    else:   # run: higher knees, 2px bob, flight frames lift both feet
        plan = [(0, 3, 0, 2, -2), (0, 4, 1, 2, -2), (1, 2, -1, 0, 0), (3, 0, 0, -2, 2), (4, 0, 1, -2, 2), (2, 1, -1, 0, 0)]
    frames = []
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


# ---------------------------------------------------------------- foot-lock check
def footlock_report(feet, step, label):
    """World x of each planted boot (frame f is drawn step*f px further along): must not change."""
    lines = []
    worst = 0
    for name in ("near", "far"):
        run = []
        for f in range(6):
            planted, b = feet[f][name]
            if planted:
                run.append((f, min(x for x, y in b), max(y for x, y in b)))
        # group consecutive stance frames
        groups, cur = [], []
        for item in run:
            if cur and item[0] != cur[-1][0] + 1:
                groups.append(cur); cur = []
            cur.append(item)
        if cur:
            groups.append(cur)
        for g in groups:
            sx, sy = step if isinstance(step, tuple) else (step, 0)
            wx = [x + sx * f for f, x, _ in g]
            wy = [y + sy * f for f, _, y in g]
            slip = max(max(wx) - min(wx), max(wy) - min(wy))
            worst = max(worst, slip)
            lines.append(f"{label} {name} frames {[f for f, _, _ in g]}: world heel x {wx}, world sole y {wy}, slip {slip}px")
    return lines, worst


def gif(frames, path, scale=4, ms=100, bg="P19"):
    out = []
    for fr in frames:
        b = Image.new("RGBA", fr.size, C(bg))
        b.alpha_composite(fr)
        out.append(upscale(b, scale).convert("P", palette=Image.ADAPTIVE))
    out[0].save(path, save_all=True, append_images=out[1:], duration=ms, loop=0, disposal=2)


def build_all(code="T01", faction=None, look=None):
    global FIT
    FIT = O.make(code, faction)
    look = look or {}
    src = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_S.txt"))
    up = parse(os.path.join(ROOT, "src/sprites/pc_s07_upper_E.txt"))["upperE"]
    dg = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_diag.txt"))
    base = {"S": O.dress(src["idle0"], FIT, "S"), "N": O.dress(src["idleN"], FIT, "N"),
            "SE": O.dress(dg["idleSE"], FIT, "SE"), "NE": O.dress(dg["idleNE"], FIT, "NE"),
            "E": O.dress(up, FIT, "E")}
    base = {v: HD.head(im, v, **look) for v, im in base.items()}
    fl = lambda seq: [f.transpose(Image.FLIP_LEFT_RIGHT) for f in seq]
    sets, report = {}, []
    for mode in ("walk", "run"):
        S = walk_frontback(base["S"], mode)
        N = walk_frontback(base["N"], mode)
        E, fe = walk_side(base["E"], mode)
        SE, fse = walk_diag(base["SE"], mode)
        NE, fne = walk_diag(base["NE"], mode, back=True)
        dx, dy = STEP[mode][1]
        for seq_feet, lab, st in ((fe, "E", STEP[mode][0]), (fse, "SE", (dx, dy)), (fne, "NE", (dx, -dy))):
            lines, worst = footlock_report(seq_feet, st, f"{code} {mode} {lab}")
            report += lines
        sets[mode] = {"S": S, "SE": SE, "E": E, "NE": NE, "N": N, "NW": fl(NE), "W": fl(E), "SW": fl(SE)}
    sets["idle"] = {"S": base["S"], "N": base["N"], "SE": base["SE"], "NE": base["NE"],
                    "E": E_idle(HD.head(O.dress(src["idleE"], FIT, "E"), "E", **look)), }
    sets["idle"].update({"W": sets["idle"]["E"].transpose(Image.FLIP_LEFT_RIGHT),
                         "SW": base["SE"].transpose(Image.FLIP_LEFT_RIGHT),
                         "NW": base["NE"].transpose(Image.FLIP_LEFT_RIGHT)})
    return sets, report


def E_idle(full):
    """Side idle = the hand-drawn idleE dressed, plus the shoulder pad over the near arm."""
    fr = full.copy()
    if FIT["pads"]:
        from PIL import ImageDraw
        e = FIT["pads"]
        O._box(ImageDraw.Draw(fr), 30 - e, 36 - e // 2, 34 + e, 40, FIT["pad_ramp"])
    return fr


ORDER = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")

if __name__ == "__main__":
    sets, report = build_all()
    out = os.path.join(ROOT, "samples")
    for mode, ms in (("walk", 62), ("run", 55)):      # 3.0 t/s / 6 px = 16 fps, 4.5 t/s / 8 px = 18 fps
        rows = [f for d in ORDER for f in sets[mode][d]]
        sh = sheet(rows, 6, pad=2, bg=C("P19"))
        sh.save(os.path.join(out, f"04_pc_{mode}_sheet.png"))
        upscale(sh, 5).save(os.path.join(out, f"04_pc_{mode}_sheet_x5.png"))
        combo = []
        for i in range(6):
            c = Image.new("RGBA", (64 * 8, 64), CLEAR)
            for k, d in enumerate(ORDER):
                c.alpha_composite(sets[mode][d][i], (k * 64, 0))
            combo.append(c)
        gif(combo, os.path.join(out, f"04_pc_{mode}.gif"), scale=3, ms=ms)
    open(os.path.join(out, "04_pc_footlock.txt"), "w").write("\n".join(report) + "\n")
    print("\n".join(report))
