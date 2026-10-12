"""Reference sample #8: 변이 시궁쥐 (small, 32x32) and 변이 들개 (medium, 64x64) on a quadruped rig.
SD-16 §7.3: 70% of the silhouette reads as the real species, max 2 mutation axes.
  rat: ① size  ④ incisors enlarged (+ bare tail = real rat).   dog: ① size  ③ mange (bald patches).
SD-16 §3.6.5 applies: legs are IK-solved to foot targets, stance feet move back exactly one frame-distance
per frame (rat 4px/frame, dog 8px/frame), so planted paws stay fixed on the ground.
Writes samples/15_creatures_x4.png, 15_creatures.gif, 15_creatures_footlock.txt."""
import os, sys, math
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import upscale, check
import rig_pc as R

ROOT = os.path.dirname(os.path.dirname(__file__))
FONT = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
CLEAR = (0, 0, 0, 0)
C = lambda t: P.rgb(t) + (255,)
LIGHT = (-0.55, -0.7, 0.45)
_n = math.sqrt(sum(v * v for v in LIGHT)); LIGHT = tuple(v / _n for v in LIGHT)
THR = (-0.1, 0.2, 0.45, 0.7, 0.88)


def blob(img, cx, cy, rx, ry, ramp, mask=None, flat=0.3):
    """Quantised lit ellipsoid (5-step ramp), returns its pixel set."""
    pts = set()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                pts.add((x, y))
                nz = max(math.sqrt(max(0, 1 - dx * dx - dy * dy)), flat if dy < 0 else 0)
                ln = math.sqrt(dx * dx + dy * dy + nz * nz) or 1
                i = (dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2]) / ln
                k = sum(i >= t for t in THR)
                if 0 <= x < img.width and 0 <= y < img.height:
                    img.putpixel((x, y), C(ramp[k]))
    if mask is not None:
        mask |= pts
    return pts


def put(img, xy, col):
    x, y = int(xy[0]), int(xy[1])
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), col)


def outline(img, mask, ink="P01"):
    for x, y in mask:
        for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + a, y + b)
            if p not in mask and 0 <= p[0] < img.width and 0 <= p[1] < img.height:
                if img.getpixel(p)[3] == 0:
                    img.putpixel(p, C(ink))


def limb(img, mask, a, b, c, r1, r2, ramp):
    m = set()
    R.capsule(m, a, b, r1); R.capsule(m, b, c, r2)
    for x, y in m:
        if 0 <= x < img.width and 0 <= y < img.height:
            img.putpixel((x, y), C(ramp[1]))
    xs = {}
    for x, y in m:
        xs.setdefault(y, []).append(x)
    for y, row in xs.items():                         # lit front edge, shaded back edge
        if 0 <= y < img.height:
            if 0 <= min(row) < img.width:
                img.putpixel((min(row), y), C(ramp[2]))
            if 0 <= max(row) < img.width:
                img.putpixel((max(row), y), C(ramp[0]))
    mask |= m


# ---------------------------------------------------------------- species specs
DOG = dict(
    size=64, ground=60, fur=["P16", "P17", "P18", "P19", "P20", "P21"], skin=["P38", "P39", "P40", "P40", "P41", "P41"],
    leg_near=("P20", "P18", "P16"), leg_far=("P18", "P17", "P16"), paw="P16", leg_r=(2.1, 1.5), far_r=(1.8, 1.3),
    shoulder=(40, 42), hip=(22, 42), l1=8.0, l2=9.6,
    body=((23, 40, 6.5, 6), (31, 40, 11, 6.2), (39, 40, 7, 7)),
    neck=(44, 36, 4.5, 5), head=(48, 32, 5, 4.2), muzzle=(54, 34.5, 4, 2.3), ear=((46, 26), (49, 26)),
    tail=((17, 37), (13, 33), (12, 28)), patches=((29, 38, 3, 1.6), (35, 44, 2, 1.2)),
    step=8, eye=(50, 31), teeth=None,
)
RAT = dict(
    size=32, ground=29, fur=["P02", "P03", "P04", "P05", "P06", "P07"], skin=["P39", "P39", "P40", "P40", "P41", "P41"],
    leg_near=("P41", "P40", "P39"), leg_far=("P40", "P39", "P38"), paw="P40", leg_r=(0.45, 0.35), far_r=(0.4, 0.3),
    shoulder=(19, 25), hip=(12, 25), l1=2.2, l2=2.2,
    body=((11, 24, 5, 4), (15, 23.5, 5, 3.6), (19, 24, 3, 2.7)),
    neck=(21, 24, 2, 2.2), head=(23, 23.5, 2.6, 2.1), muzzle=(26, 24.5, 1.7, 1.2), ear=((21, 20),),
    tail=((6, 25), (2, 27), (0, 28)), patches=((13, 21.5, 1.6, 0.9),),
    step=4, eye=(24, 22), teeth=(27, 25),
)


# gait: per foot (x offset in steps, lift, planted). Diagonal pairs: near-front + far-hind, far-front + near-hind.
def gait(species):
    if species["size"] == 64:      # flying trot, 6 frames, 8 px/frame
        A = [(+0.5, 0, True), (-0.5, 0, True), (-1.2, 2, False), (-0.4, 5, False), (+0.5, 4, False), (+1.1, 1, False)]
        bob = [1, 0, -1, 1, 0, -1]
    else:                   # scurry, 4 frames, 4 px/frame
        A = [(+0.5, 0, True), (-0.5, 0, True), (-0.2, 1, False), (+0.6, 1, False)]
        bob = [0, 0, -1, -1]
    return A, bob


def draw(sp, pose):
    """pose: dict(bob, feet={nf,ff,nh,fh:(x_target, lift, planted)}, head_dy, jaw, tail_dy, lunge, flash)."""
    S = sp["size"]
    img = Image.new("RGBA", (S, S), CLEAR)
    body_mask, far_mask, near_mask = set(), set(), set()
    b = pose.get("bob", 0)
    L = pose.get("lunge", 0)
    sh = (sp["shoulder"][0] + L, sp["shoulder"][1] + b)
    hp = (sp["hip"][0] + L, sp["hip"][1] + b)
    feet = pose["feet"]
    ground = sp["ground"]

    def leg_pts(root, key, front):
        fx, lift, planted = feet[key]
        tgt = (fx, ground - 1 - lift)
        knee, ankle = R.ik(root, tgt, sp["l1"], sp["l2"], -1 if front else 1)
        return root, knee, ankle, planted

    far_layer = Image.new("RGBA", (S, S), CLEAR)
    paws = {}
    for key, root, front in (("ff", (sh[0] - 1, sh[1]), True), ("fh", (hp[0] - 1, hp[1]), False)):
        a, k, c, planted = leg_pts(root, key, front)
        limb(far_layer, far_mask, a, k, c, sp["far_r"][0], sp["far_r"][1], sp["leg_far"])
        paws[key] = (round(c[0]), round(c[1]), planted)
    outline(far_layer, far_mask)
    img.alpha_composite(far_layer)
    # tail (behind body), body, patches
    body = Image.new("RGBA", (S, S), CLEAR)
    t0, t1, t2 = sp["tail"]
    td = pose.get("tail_dy", 0)
    tail_ramp = sp["skin"] if sp["size"] == 32 else sp["fur"]
    m = set()
    R.capsule(m, (t0[0] + L, t0[1] + b), (t1[0] + L, t1[1] + b + td // 2), 1.3 if S == 64 else 0.6)
    R.capsule(m, (t1[0] + L, t1[1] + b + td // 2), (t2[0] + L, t2[1] + b + td), 1.0 if S == 64 else 0.4)
    for x, y in m:
        if 0 <= x < S and 0 <= y < S:
            put(body, (x, y), C(tail_ramp[3]))
    body_mask |= m
    for cx, cy, rx, ry in sp["body"]:
        blob(body, cx + L, cy + b, rx, ry, sp["fur"], body_mask)
    for cx, cy, rx, ry in sp["patches"]:                   # mange: bare skin patches (mutation axis ③)
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 and (x + L, y + b) in body_mask:
                    put(body, (x + L, y + b), C(sp["skin"][3 if y > cy - ry * 0.3 else 4]))
    hd = pose.get("head_dy", 0)
    nx, ny, nrx, nry = sp["neck"]
    blob(body, nx + L, ny + b + hd // 2, nrx, nry, sp["fur"], body_mask)
    hx, hy, hrx, hry = sp["head"]
    blob(body, hx + L, hy + b + hd, hrx, hry, sp["fur"], body_mask)
    mx, my, mrx, mry = sp["muzzle"]
    jaw = pose.get("jaw", 0)
    blob(body, mx + L, my + b + hd, mrx, mry, sp["fur"], body_mask)
    if jaw:                                                # open mouth: lower jaw drops
        blob(body, mx + L - 0.5, my + b + hd + mry + jaw * 0.7, mrx * 0.8, mry * 0.6, sp["fur"], body_mask)
        for x in range(int(mx + L - mrx * 0.3), int(mx + L + mrx)):
            put(body, (x, int(my + b + hd + mry * 0.5 + jaw * 0.4)), C("P51"))
    for ex, ey in sp["ear"]:                               # ears: upright triangles (dog) / round (rat)
        ex, ey = ex + L, ey + b + hd
        if S == 64:
            eh = 6 if sp["l1"] > 6 else 4
            ep = {(ex + dx, ey + dy) for dy in range(0, eh) for dx in range(0, max(1, dy // 2 + 1))}
        else:
            ep = {(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)}
        for p in ep:
            if 0 <= p[0] < S and 0 <= p[1] < S:
                put(body, p, C(sp["fur"][2] if S == 64 else sp["skin"][3]))
        body_mask |= ep
    outline(body, body_mask)
    ex, ey = sp["eye"]
    put(body, (ex + L, ey + b + hd), C("P01" if not pose.get("dead") else "P04"))
    if S == 64:
        put(body, (ex + L - 1, ey + b + hd), C("P01"))
        put(body, (int(mx + L + mrx), int(my + b + hd - 1)), C("P01"))      # nose
    if sp["teeth"]:                                        # rat: long yellow incisors (mutation axis ④)
        tx, ty = sp["teeth"]
        for k in range(3 + (1 if jaw else 0)):
            put(body, (tx + L, ty + b + hd + k), C("P21" if k < 2 else "P20"))
        put(body, (tx + L + 1, ty + b + hd), C("P22"))
    img.alpha_composite(body)
    # near legs over the body
    near_layer = Image.new("RGBA", (S, S), CLEAR)
    for key, root, front in (("nf", (sh[0] + 1, sh[1] + 1), True), ("nh", (hp[0] + 1, hp[1] + 1), False)):
        a, k, c, planted = leg_pts(root, key, front)
        limb(near_layer, near_mask, a, k, c, sp["leg_r"][0], sp["leg_r"][1], sp["leg_near"])
        paws[key] = (round(c[0]), round(c[1]), planted)
    outline(near_layer, near_mask)
    for key, (px_, py_, _) in paws.items():                # paw pads
        if key in ("nf", "nh") and 0 <= px_ < S and 0 <= py_ < S:
            put(near_layer, (px_, py_), C(sp["paw"]))
    img.alpha_composite(near_layer)
    if pose.get("flash"):                                  # hit: 1-frame white silhouette is an FX layer (§10); here 1px recoil only
        pass
    return img, paws


def move_frames(sp):
    A, bob = gait(sp)
    n = len(A)
    st = sp["step"]
    frames, feet = [], []
    for f in range(n):
        ph = lambda off: A[(f + off) % n]
        pairs = {"nf": ph(0), "fh": ph(0), "ff": ph(n // 2), "nh": ph(n // 2)}
        fe = {}
        for key, (u, lift, planted) in pairs.items():
            root_x = (sp["shoulder"][0] if key in ("nf", "ff") else sp["hip"][0]) + (1 if key[0] == "n" else -1)
            fe[key] = (root_x + round(u * st), lift, planted)
        img, paws = draw(sp, dict(bob=bob[f], feet=fe, tail_dy=(f % 2) * (2 if sp["size"] == 64 else 1)))
        frames.append(img); feet.append(paws)
    return frames, feet


def stand(sp, **kw):
    fe = {}
    for key in ("nf", "ff", "nh", "fh"):
        root_x = (sp["shoulder"][0] if key in ("nf", "ff") else sp["hip"][0]) + (1 if key[0] == "n" else -1)
        fe[key] = (root_x + kw.pop(key + "_dx", 0), kw.pop(key + "_lift", 0), True)
    return draw(sp, dict(feet=fe, **kw))[0]


def idle_frames(sp):
    if sp["size"] == 64:   # breathing + tail swish, head turn
        return [stand(sp), stand(sp, bob=0, tail_dy=-2), stand(sp, bob=1, head_dy=1), stand(sp, tail_dy=2)]
    return [stand(sp), stand(sp, head_dy=1)]


def attack_frames(sp):
    if sp["size"] == 64:   # crouch, lunge (front paws up), bite (jaw open), recover
        return [stand(sp, bob=2, head_dy=2, nh_dx=2, fh_dx=2),
                stand(sp, lunge=4, bob=-2, head_dy=-1, jaw=2, nf_dx=6, ff_dx=5, nf_lift=4, ff_lift=3),
                stand(sp, lunge=6, bob=0, head_dy=2, jaw=3, nf_dx=6, ff_dx=6),
                stand(sp, lunge=2, bob=1, head_dy=1, jaw=0)]
    return [stand(sp, bob=1, head_dy=1),
            stand(sp, lunge=2, bob=-1, jaw=2, nf_dx=2, ff_dx=2, nf_lift=2, ff_lift=2),
            stand(sp, lunge=2, jaw=2, nf_dx=2, ff_dx=2)]


def hit_frames(sp):
    if sp["size"] == 64:
        return [stand(sp, lunge=-2, bob=1, head_dy=2, jaw=1), stand(sp, lunge=-1, bob=0)]
    return [stand(sp, lunge=-1, bob=1, head_dy=1)]


def death_frames(sp):
    """Stagger, buckle, fall on the side, lie still (last = corpse)."""
    S = sp["size"]
    out = [stand(sp, lunge=-1, bob=2, head_dy=3, nf_dx=-1)]
    base = stand(sp, bob=0)
    for k, (ang, drop) in enumerate(((-25, 2), (-60, 4), (-90, 6), (-90, 6))):
        if sp["size"] == 32 and k == 3:
            break
        rot = Image.new("RGBA", (S, S), CLEAR)
        # pre-baked fall: rotate the standing silhouette about the far paws in 90-degree steps only at the end
        if ang == -90:
            lying = base.transpose(Image.ROTATE_90 if False else Image.FLIP_TOP_BOTTOM)
            lying = squash(base, S)
            rot.alpha_composite(lying, (0, drop))
        else:
            lean = shear_x(base, ang)
            rot.alpha_composite(lean, (0, drop))
        out.append(rot)
    return out


def shear_x(img, ang):
    """Topple: shear rows sideways (pixel rows shift, no resampling), lower body fixed."""
    S = img.width
    out = Image.new("RGBA", img.size, CLEAR)
    k = math.tan(math.radians(-ang)) * 0.35
    g = S - 4
    for y in range(S):
        out.alpha_composite(img.crop((0, y, S, y + 1)), (int(round((g - y) * k * 0.3)), y))
    return out


def squash(img, S):
    """Lying on the side: keep every other row of the upper half so the silhouette flattens (corpse frame)."""
    out = Image.new("RGBA", img.size, CLEAR)
    rows = [y for y in range(S) if any(img.getpixel((x, y))[3] for x in range(S))]
    if not rows:
        return out
    top, bot = rows[0], rows[-1]
    keep = [y for y in range(top, bot + 1) if (y - top) % 2 == 0 or y > bot - 3]
    for i, y in enumerate(reversed(keep)):
        out.alpha_composite(img.crop((0, y, S, y + 1)), (0, bot - i))
    return out


def footlock(feet, step):
    lines, worst = [], 0
    n = len(feet)
    for key in ("nf", "ff", "nh", "fh"):
        run = [(f, feet[f][key]) for f in range(n) if feet[f][key][2]]
        groups, cur = [], []
        for f, p in run:
            if cur and f != cur[-1][0] + 1:
                groups.append(cur); cur = []
            cur.append((f, p))
        if cur:
            groups.append(cur)
        for g in groups:
            wx = [p[0] + step * f for f, p in g]
            wy = [p[1] for f, p in g]
            slip = max(max(wx) - min(wx), max(wy) - min(wy))
            worst = max(worst, slip)
            lines.append(f"{key} frames {[f for f, _ in g]}: world paw x {wx}, y {wy}, slip {slip}px")
    return lines, worst


def main():
    out = os.path.join(ROOT, "samples")
    rows, report, anims = [], [], {}
    for name, sp in (("변이 들개", DOG), ("변이 시궁쥐", RAT)):
        mv, feet = move_frames(sp)
        lines, worst = footlock(feet, sp["step"])
        report += [f"{name} {l}" for l in lines]
        seq = {"대기": idle_frames(sp), "이동": mv, "공격": attack_frames(sp), "피격": hit_frames(sp), "사망": death_frames(sp)}
        rows.append((name, sp, seq)); anims[name] = seq
    bad = []
    for name, sp, seq in rows:
        for k, fr in seq.items():
            for im in fr:
                bad += check(im, P.allowed_set())
    # sheet: each species row = motions left to right (scaled so the rat reads at 2x relative)
    W = 140 + 21 * 66
    sh = Image.new("RGBA", (W, 2 * 74 + 20), C("P19"))
    d = ImageDraw.Draw(sh); d.fontmode = "1"
    for i, (name, sp, seq) in enumerate(rows):
        y = 10 + i * 74
        d.text((4, y + 26), name, font=FONT, fill=C("P09"))
        x = 140
        for k, fr in seq.items():
            d.text((x, y - 9 if i == 0 else y - 9), k, font=FONT, fill=C("P08"))
            for im in fr:
                big = im if sp["size"] == 64 else upscale(im, 2)
                sh.alpha_composite(big, (x, y))
                x += 66 if sp["size"] == 64 else 66
            x += 6
    upscale(sh.crop((0, 0, min(W, x + 60), sh.height)), 3).save(os.path.join(out, "15_creatures_x3.png"))
    # gif: dog trot across ground + rat scurry, stepped render over a tile strip
    import tiles_r01 as TR
    frames = []
    floor = Image.new("RGBA", (640, 96))
    for tx in range(20):
        for ty in range(3):
            floor.alpha_composite(TR.dirt(tx * 5 + ty, grass=(tx * 3 + ty) % 4), (tx * 32, ty * 32))
    dmv, _ = move_frames(DOG); rmv, _ = move_frames(RAT)
    dist_d = dist_r = 0.0
    for t in range(150):
        dist_d += 144 / 50; dist_r += 112 / 50
        kd = int(dist_d // 8); kr = int(dist_r // 4)
        cam = dist_d - 120
        fr = Image.new("RGBA", (320, 96)); fr.alpha_composite(floor.crop((int(cam) % 64, 0, int(cam) % 64 + 320, 96)))
        dx = 40 + kd * 8 - int(cam) + (int(cam) - int(cam) % 64) * 0
        fr.alpha_composite(dmv[kd % 6], (int(40 + kd * 8 - cam) - 32, 60 - 60))
        fr.alpha_composite(rmv[kr % 4], (int(30 + kr * 4 - (dist_r - 120)) - 16, 80 - 29))
        frames.append(upscale(fr, 2).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out, "15_creatures.gif"), save_all=True, append_images=frames[1:], duration=20, loop=0)
    open(os.path.join(out, "15_creatures_footlock.txt"), "w").write("\n".join(report) + "\n")
    worst = max(int(l.split("slip ")[1].split("px")[0]) for l in report)
    print("off-palette:", sorted(set(bad)) or 0, "| stances:", len(report), "worst slip:", worst)


if __name__ == "__main__":
    main()
