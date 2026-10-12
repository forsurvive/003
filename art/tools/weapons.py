"""Reference sample #7: weapons on the hand anchors + attack poses + upper/lower split while aiming.
Families (SD-16 §3.6.2): A pistol, B rifle (사격장 공기총 / 계엄군 소총 skins), E one-hand melee (경봉),
G unarmed. Upper bodies are the dressed torsos with the arms removed; arms are re-solved by IK to the
hand anchors of each pose, and the weapon stamp is drawn per view (pre-baked, no runtime rotation).
Writes samples/14_weapons_x4.png, 14_weapons_attack.gif, 14_aim_split.gif (+ _strip.png)."""
import os, sys, math
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import rig_pc as R
import outfits as O
import heads as HD
from grid import parse, upscale, check

ROOT = os.path.dirname(os.path.dirname(__file__))
FONT = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
CLEAR = (0, 0, 0, 0)
C = lambda t: P.rgb(t) + (255,)

# ---------------------------------------------------------------- torsos without arms
ARMCUT = {  # view: (left arm max x, right arm min x, outline x left, outline x right)
    "S": (26, 37, 26, 37), "N": (26, 37, 26, 37), "SE": (27, 37, 27, 37), "NE": (27, 37, 27, 37)}
SHOULDER = {"S": ((26, 38), (37, 38)), "N": ((26, 38), (37, 38)), "SE": ((27, 38), (37, 38)),
            "NE": ((27, 38), (37, 38)), "E": ((32, 38), (30, 38))}   # (screen-left/near, screen-right/far)


def torso(img, view):
    """Remove the baked arms (rows 36..47) and close the torso sides with ink."""
    if view == "E":
        return img
    lx, rx, ol, orr = ARMCUT[view]
    out = img.copy()
    px = out.load()
    for y in range(36, 48):
        for x in range(16, 48):
            if (x <= lx or x >= rx) and px[x, y][3]:
                px[x, y] = CLEAR
    for y in range(37, 47):
        for x in (ol, orr):
            px[x, y] = C("P01")
    return out


def legs_part(img, y0=47):
    out = Image.new("RGBA", img.size, CLEAR)
    out.alpha_composite(img.crop((0, y0, 64, 64)), (0, y0))
    return out


# ---------------------------------------------------------------- arms
def draw_arm(layer, sh, hand, near=True, bend=1, fist=False):
    fit = R.FIT
    knee, wrist = R.ik(sh, hand, 5.6, 5.2, bend)
    m = set()
    R.capsule(m, sh, knee, 1.9)
    R.capsule(m, knee, wrist, 1.7)
    R.paint_mask(layer, m, fit["sleeve"] if near else fit["sleeve_far"])
    hx, hy = int(round(wrist[0])), int(round(wrist[1]))
    skin = ("P03", "P02") if fit["gloves"] else ("P41", "P40")
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            layer.putpixel((hx + dx, hy + dy), C("P01"))
    layer.putpixel((hx, hy), C(skin[0])); layer.putpixel((hx - 1, hy), C(skin[1]))
    layer.putpixel((hx, hy - 1), C(skin[0]) if fist else C(fit["cuff"]))
    return (hx, hy)


# ---------------------------------------------------------------- weapon stamps
SKINS = {
    "pistol": {"body": ("P06", "P04", "P03"), "grip": ("P18", "P17")},
    "airgun": {"body": ("P06", "P05", "P03"), "stock": ("P21", "P19", "P17")},
    "rifle": {"body": ("P04", "P03", "P02"), "stock": ("PF-01.3", "PF-01.2", "PF-01.1"), "mag": "P02"},
    "baton": {"body": ("P05", "P02", "P01"), "grip": ("P17", "P16")},
}


def thick_line(d, a, b, w, tok):
    d.line([a, b], fill=C(tok), width=w)


def pistol(d, view, hand, recoil=0):
    s = SKINS["pistol"]
    hx, hy = hand
    if view == "E":
        y = hy - 2 - recoil
        d.rectangle([hx - 1, y, hx + 6, y + 2], fill=C("P01"))
        d.line([hx, y + 1, hx + 5, y + 1], fill=C(s["body"][1])); d.line([hx, y + 1, hx + 4, y + 1], fill=C(s["body"][0]))
        d.rectangle([hx - 1, y + 3, hx + 1, y + 5], fill=C("P01")); d.point((hx, y + 3), fill=C(s["grip"][0]))
    elif view in ("S", "SE"):                     # muzzle toward the camera: short foreshortened block
        y = hy + 1 - recoil
        d.rectangle([hx - 1, y, hx + 2, y + 3], fill=C("P01"))
        d.rectangle([hx, y + 1, hx + 1, y + 2], fill=C(s["body"][1])); d.point((hx, y + 1), fill=C(s["body"][0]))
        d.point((hx + 1, y + 2), fill=C("P01"))   # bore
    # N / NE: hidden behind the body (SD-16 §5.3)


def long_gun(d, view, rear, front, kind, recoil=0):
    s = SKINS[kind]
    (rx, ry), (fx, fy) = rear, front
    if view == "E":
        y = ry - 1
        sx0 = rx - 7 - recoil
        d.rectangle([sx0 - 1, y - 1, fx + 9, y + 2], fill=C("P01"))                 # silhouette
        d.rectangle([sx0, y, rx, y + 1], fill=C(s["stock"][1])); d.line([sx0, y, rx, y], fill=C(s["stock"][0]))
        d.rectangle([rx + 1, y, fx + 8, y + 1], fill=C(s["body"][1])); d.line([rx + 1, y, fx + 8, y], fill=C(s["body"][0]))
        if kind == "rifle":
            d.rectangle([rx + 3, y + 2, rx + 5, y + 5], fill=C("P01")); d.line([rx + 4, y + 2, rx + 4, y + 4], fill=C(s["mag"]))
            d.point((fx + 8, y - 2), fill=C("P01")); d.point((rx + 2, y - 2), fill=C("P01"))   # sights
        else:
            d.rectangle([sx0 + 1, y + 2, rx - 2, y + 3], fill=C("P01")); d.line([sx0 + 2, y + 2, rx - 3, y + 2], fill=C(s["stock"][2]))
    elif view in ("S", "SE"):                    # toward the camera: foreshortened, stock at the shoulder
        a, b = (rx, ry - recoil), (fx, fy - recoil)
        d.line([a, b], fill=C("P01"), width=5)
        d.line([a, b], fill=C(s["body"][1]), width=3)
        d.line([(a[0] - 1, a[1]), (b[0] - 1, b[1])], fill=C(s["body"][0]), width=1)
        d.rectangle([a[0] - 2, a[1] - 2, a[0] + 1, a[1] + 2], fill=C("P01"))
        d.rectangle([a[0] - 1, a[1] - 1, a[0], a[1] + 1], fill=C(s["stock"][1]))
        d.rectangle([b[0] - 1, b[1], b[0] + 1, b[1] + 1], fill=C("P01"))   # muzzle
        if kind == "rifle":
            mx, my = (a[0] + b[0]) // 2 + 2, (a[1] + b[1]) // 2
            d.rectangle([mx, my, mx + 2, my + 3], fill=C("P01"))
    else:                                         # N / NE: muzzle shows above the right shoulder
        d.line([(fx, fy), (fx + 2, fy - 9)], fill=C("P01"), width=3)
        d.line([(fx, fy), (fx + 2, fy - 9)], fill=C(s["body"][1]), width=1)


def smear(img, sh, hand, path, length=12):
    """Swept area of the baton between the previous and the current pose: the in-between batons are
    filled pale (P08) with a bright tip edge (P09), drawn under the real baton (FX preview, SD-16 §10)."""
    d = ImageDraw.Draw(img)
    (h0, a0), (h1, a1) = path
    steps = max(10, int(abs(a1 - a0) / 3))
    tips = []
    for i in range(steps):                          # stop short of the current pose (the baton covers it)
        t = i / steps
        hx = h0[0] + (h1[0] - h0[0]) * t
        hy = h0[1] + (h1[1] - h0[1]) * t
        a = math.radians(a0 + (a1 - a0) * t)
        base = (hx + (length - 4) * math.cos(a), hy + (length - 4) * math.sin(a))
        tip = (hx + length * math.cos(a), hy + length * math.sin(a))
        d.line([base, tip], fill=C("P08" if t > 0.35 else "P07"), width=2)
        tips.append(tip)
    for p, q in zip(tips, tips[1:]):
        d.line([p, q], fill=C("P09"), width=1)


def baton(d, hand, angle_deg, length=11):
    """Baton from the fist along angle (0 = east, -90 = up)."""
    s = SKINS["baton"]
    a = math.radians(angle_deg)
    hx, hy = hand
    tip = (hx + length * math.cos(a), hy + length * math.sin(a))
    d.line([(hx, hy), tip], fill=C("P01"), width=3)
    d.line([(hx, hy), tip], fill=C(s["body"][1]), width=1)
    d.point((round(hx + 3 * math.cos(a)), round(hy + 3 * math.sin(a))), fill=C(s["body"][0]))
    d.point((round(tip[0]), round(tip[1])), fill=C(s["body"][0]))


# ---------------------------------------------------------------- pose tables
# Each frame: hands (screen-left arm target, screen-right arm target), weapon call, flags.
# E view: arm 0 = near (main), arm 1 = far (support, drawn behind the torso).
def poses(weapon, view):
    if view == "E":
        if weapon == "pistol":
            return [dict(h=((41, 39), (40, 40)), w=("pistol", 0)), dict(h=((40, 38), (39, 39)), w=("pistol", 1)),
                    dict(h=((41, 39), (40, 40)), w=("pistol", 0)), dict(h=((41, 39), (40, 40)), w=("pistol", 0))]
        if weapon in ("airgun", "rifle"):
            return [dict(h=((35, 40), (42, 40)), w=(weapon, 0)), dict(h=((34, 40), (41, 40)), w=(weapon, 1)),
                    dict(h=((35, 40), (42, 40)), w=(weapon, 0)), dict(h=((35, 40), (42, 40)), w=(weapon, 0))]
        if weapon == "baton":   # ready, wind-up (overhead, lean back), arc, impact, follow-through, recover
            return [dict(h=((37, 41), (37, 43)), w=("baton", -65), lean=0),
                    dict(h=((31, 28), (38, 41)), w=("baton", 150), lean=-1, over=True),
                    dict(h=((37, 30), (36, 43)), w=("baton", -50), lean=1, over=True,
                         smear=(((31, 28), 150), ((37, 30), -50 + 360))),
                    dict(h=((42, 38), (34, 44)), w=("baton", 25), lean=2,
                         smear=(((37, 30), -50), ((42, 38), 25))),
                    dict(h=((40, 44), (33, 44)), w=("baton", 80), lean=2),
                    dict(h=((37, 41), (36, 43)), w=("baton", -65), lean=1)]
        if weapon == "fist":    # guard, jab, guard, straight
            return [dict(h=((38, 38), (37, 36)), w=None, fist=True), dict(h=((44, 37), (37, 36)), w=None, fist=True),
                    dict(h=((38, 38), (37, 36)), w=None, fist=True), dict(h=((38, 38), (43, 36)), w=None, fist=True)]
    if view in ("S", "SE"):
        dx = 1 if view == "SE" else 0
        if weapon == "pistol":
            return [dict(h=((30 + dx, 44), (33 + dx, 44)), w=("pistol", 0), at=(31 + dx, 44)),
                    dict(h=((30 + dx, 43), (33 + dx, 43)), w=("pistol", 1), at=(31 + dx, 44))]
        if weapon in ("airgun", "rifle"):
            return [dict(h=((29 + dx, 42), (32 + dx, 46)), w=(weapon, 0), gun=((28 + dx, 39), (31 + dx, 49))),
                    dict(h=((29 + dx, 41), (32 + dx, 45)), w=(weapon, 1), gun=((28 + dx, 39), (31 + dx, 49)))]
        if weapon == "baton":
            return [dict(h=((24 + dx, 39), (34 + dx, 43)), w=("baton", -100)), dict(h=((26 + dx, 34), (34 + dx, 43)), w=("baton", -150)),
                    dict(h=((31 + dx, 43), (35 + dx, 42)), w=("baton", 60))]
        if weapon == "fist":
            return [dict(h=((29 + dx, 40), (34 + dx, 40)), w=None, fist=True), dict(h=((30 + dx, 44), (34 + dx, 40)), w=None, fist=True)]
    # N / NE (back): hands in front of the body, hidden; elbows out
    dx = 1 if view == "NE" else 0
    if weapon == "pistol":
        return [dict(h=((28 + dx, 43), (35 + dx, 43)), w=None)]
    if weapon in ("airgun", "rifle"):
        return [dict(h=((28 + dx, 43), (36 + dx, 42)), w=(weapon, 0), gun=((35 + dx, 44), (36 + dx, 40)))]
    if weapon == "baton":
        return [dict(h=((29 + dx, 41), (38 + dx, 38)), w=("baton", -80), behind=False)]
    return [dict(h=((27 + dx, 41), (36 + dx, 41)), w=None, fist=True)]


def compose(upper, view, frame, weapon):
    """upper = armless torso+head (with legs cut away). Returns upper-body layer with arms + weapon."""
    sh_l, sh_r = SHOULDER[view]
    out = Image.new("RGBA", (64, 64), CLEAR)
    layer_back = Image.new("RGBA", (64, 64), CLEAR)
    layer_front = Image.new("RGBA", (64, 64), CLEAR)
    fist = frame.get("fist", False)
    h0, h1 = frame["h"]
    wd = ImageDraw.Draw(layer_front)
    if view == "E":
        lean = frame.get("lean", 0)
        if lean:
            upper = R.shear(upper, lean)
            sh_l = (sh_l[0] + lean // 2 + (1 if lean > 0 else 0), sh_l[1])
            sh_r = (sh_r[0] + lean // 2, sh_r[1])
        draw_arm(layer_back, sh_r, h1, near=False, bend=-1, fist=fist)        # far support arm
        if frame["w"] and frame["w"][0] in ("airgun", "rifle"):
            long_gun(wd, "E", h0, h1, frame["w"][0], frame["w"][1])
        if frame.get("smear"):                      # swing trail behind the body (FX preview, SD-16 §10)
            smear(out, sh_l, h0, frame["smear"])
        out.alpha_composite(layer_back); out.alpha_composite(upper)
        if frame.get("over"):                       # arm raised above the shoulder: pad first, arm over it
            pads(out, [sh_l])
        hand = draw_arm(layer_front, sh_l, h0, near=True, bend=-1 if not frame.get("over") else 1, fist=fist)
        if frame["w"] and frame["w"][0] == "pistol":
            pistol(wd, "E", hand, frame["w"][1])
        if frame["w"] and frame["w"][0] == "baton":
            baton(wd, hand, frame["w"][1], length=12)
            fx, fy = hand
            for dx in (-1, 0, 1):                   # fist wrapped round the grip, over the baton
                for dy in (-1, 0, 1):
                    layer_front.putpixel((fx + dx, fy + dy), C("P01"))
            skin = ("P02", "P03") if R.FIT["gloves"] else ("P40", "P41")
            layer_front.putpixel((fx, fy), C(skin[1])); layer_front.putpixel((fx - 1, fy), C(skin[0]))
            layer_front.putpixel((fx, fy - 1), C(skin[0]))
        out.alpha_composite(layer_front)
        if not frame.get("over"):
            pads(out, [sh_l])
        return out
    behind = frame.get("behind", False)
    tgt = layer_back if behind else layer_front
    d = ImageDraw.Draw(tgt)
    if frame["w"] and frame["w"][0] in ("airgun", "rifle"):
        a, b = frame["gun"]
        long_gun(ImageDraw.Draw(layer_back if view in ("N", "NE") else layer_front), view, a, b, frame["w"][0], frame["w"][1])
    hl = draw_arm(tgt, sh_l, h0, near=True, bend=1, fist=fist)
    hr = draw_arm(tgt, sh_r, h1, near=True, bend=-1, fist=fist)
    if frame["w"] and frame["w"][0] == "pistol":
        pistol(ImageDraw.Draw(tgt), view, frame.get("at", hl), frame["w"][1])
    if frame["w"] and frame["w"][0] == "baton":
        baton(ImageDraw.Draw(layer_front), hl if view != "N" and view != "NE" else hr, frame["w"][1])
    out.alpha_composite(layer_back); out.alpha_composite(upper); out.alpha_composite(layer_front)
    pads(out, [sh_l, sh_r])
    return out


def pads(img, shoulders):
    e = R.FIT["pads"]
    if not e:
        return
    d = ImageDraw.Draw(img)
    for k, (sx, sy) in enumerate(shoulders):
        y0, y1 = sy - 2 - (e - 1), sy + 1 + e
        if len(shoulders) == 1:                       # side view: cap over the near shoulder
            O._box(d, sx - 2 - e // 2, y0, sx + 2 + e // 2, y1, R.FIT["pad_ramp"])
        elif k == 0:
            O._box(d, sx - 2 - e, y0, sx + 1, y1, R.FIT["pad_ramp"])
        else:
            O._box(d, sx - 1, y0, sx + 2 + e, y1, R.FIT["pad_ramp"])


# ---------------------------------------------------------------- front (S / SE) poses, explicit joints
# Each arm = (shoulder, elbow, hand). Arms reaching toward the camera are foreshortened: short forearms,
# hands meeting in front of the chest, the weapon seen muzzle-on. Drawn over the torso.
FRONT = {
    "pistol": [   # V-shaped arms, elbows outside the torso, hands together at the belly, gun muzzle-on
        dict(L=((26, 38), (24, 42), (29, 45)), R=((37, 38), (39, 42), (34, 45)), gun=(31, 41), grip=(30, 45, 33, 46)),
        dict(L=((26, 38), (24, 41), (29, 44)), R=((37, 38), (39, 41), (34, 44)), gun=(31, 39), grip=(30, 44, 33, 45)),
    ],
    "airgun": [   # stock in the right shoulder (screen-left), barrel slanting to the camera
        dict(L=((26, 38), (23, 42), (27, 43)), R=((37, 38), (39, 43), (33, 46)), rifle=((27, 37), (32, 48))),
        dict(L=((26, 38), (23, 41), (27, 42)), R=((37, 38), (39, 42), (33, 45)), rifle=((27, 36), (32, 47))),
    ],
    "baton": [
        dict(L=((26, 38), (23, 41), (24, 37)), R=((37, 38), (39, 42), (36, 45)), baton=((24, 37), (21, 28))),
        dict(L=((26, 38), (23, 37), (25, 33)), R=((37, 38), (39, 42), (36, 45)), baton=((25, 33), (32, 27))),
        dict(L=((26, 38), (25, 42), (30, 46)), R=((37, 38), (39, 42), (36, 45)), baton=((30, 46), (33, 52)),
             smear=(((25, 33), -40), ((30, 46), 63))),
    ],
    "fist": [     # guard: forearms up, fists at the chin
        dict(L=((26, 38), (24, 44), (28, 40)), R=((37, 38), (39, 44), (35, 40)), fists=True),
        dict(L=((26, 38), (25, 42), (30, 45)), R=((37, 38), (39, 44), (35, 40)), fists=True, jab=0),
    ],
}
FRONT["rifle"] = FRONT["airgun"]


def jointed_arm(layer, pts, ramp):
    sh, el, hd = pts
    m = set()
    R.capsule(m, sh, el, 1.9)
    R.capsule(m, el, hd, 1.6)
    R.paint_mask(layer, m, ramp)


def hand_block(d, x0, y0, x1, y1):
    """Hand/fist: skin block with ink only below and at the outer sides (no heavy ring)."""
    skin = ("P02", "P03") if R.FIT["gloves"] else ("P40", "P41")
    d.rectangle([x0, y0, x1, y1], fill=C(skin[0]))
    d.line([x0, y0, x1, y0], fill=C(skin[1]))
    d.line([x0, y1 + 1, x1, y1 + 1], fill=C("P01"))
    d.line([x0 - 1, y0, x0 - 1, y1], fill=C("P01")); d.line([x1 + 1, y0, x1 + 1, y1], fill=C("P01"))


def front_compose(upper, view, f, weapon):
    dx = 1 if view == "SE" else 0
    pose = FRONT[weapon][f % len(FRONT[weapon])]
    mv = lambda pts: tuple((x + dx, y) for x, y in pts)
    out = Image.new("RGBA", (64, 64), CLEAR)
    out.alpha_composite(upper)
    layer = Image.new("RGBA", (64, 64), CLEAR)
    d = ImageDraw.Draw(layer)
    L, Rr = mv(pose["L"]), mv(pose["R"])
    jointed_arm(layer, L, R.FIT["sleeve"])
    if "rifle" in pose:                                 # stock in the right shoulder, muzzle toward camera
        a, b = mv(pose["rifle"])
        sk = SKINS[weapon]
        d.line([a, b], fill=C("P01"), width=5)
        d.line([a, b], fill=C(sk["body"][1]), width=3)
        d.line([(a[0] - 1, a[1] + 1), (b[0] - 1, b[1])], fill=C(sk["body"][0]), width=1)
        d.rectangle([a[0] - 1, a[1], a[0] + 1, a[1] + 2], fill=C(sk["stock"][1]))   # butt against the shoulder
        d.point((a[0] - 1, a[1]), fill=C(sk["stock"][0]))
        d.ellipse([b[0] - 2, b[1] - 1, b[0] + 2, b[1] + 2], fill=C("P01"))
        d.point((b[0], b[1]), fill=C(sk["body"][0]))
        if weapon == "rifle":
            mx, my = (a[0] + b[0]) // 2 + 2, (a[1] + b[1]) // 2 - 1
            d.rectangle([mx, my, mx + 2, my + 4], fill=C("P01"))
    jointed_arm(layer, Rr, R.FIT["sleeve"])
    hx, hy = L[2]; hand_block(d, hx - 1, hy - 1, hx, hy)
    hx, hy = Rr[2]; hand_block(d, hx - 1, hy - 1, hx, hy)
    if "gun" in pose:                                   # pistol seen muzzle-on, held in both hands
        gx, gy = pose["gun"][0] + dx, pose["gun"][1]
        x0, y0, x1, y1 = pose["grip"]
        hand_block(d, x0 + dx, y0, x1 + dx, y1)
        d.rectangle([gx - 1, gy - 1, gx + 2, gy + 3], fill=C("P01"))
        d.rectangle([gx, gy, gx + 1, gy + 2], fill=C("P05")); d.line([gx, gy, gx + 1, gy], fill=C("P07"))
        d.point((gx + 1, gy + 1), fill=C("P01"))
    if "baton" in pose:
        if "smear" in pose:
            (h0, a0), (h1, a1) = pose["smear"]
            smear(layer, None, None, (((h0[0] + dx, h0[1]), a0), ((h1[0] + dx, h1[1]), a1)), length=9)
            jointed_arm(layer, L, R.FIT["sleeve"])
        a, b = mv(pose["baton"])
        d.line([a, b], fill=C("P01"), width=3)
        d.line([a, b], fill=C("P02"), width=1)
        d.point((round(b[0]), round(b[1])), fill=C("P05"))
        hx, hy = L[2]; hand_block(d, hx - 1, hy - 1, hx, hy)
    if pose.get("fists"):
        for k, (hx, hy) in enumerate((L[2], Rr[2])):
            big = 1 if pose.get("jab") == k else 0      # the punching fist comes toward the camera: 1px bigger
            hand_block(d, hx - 1 - big, hy - 1 - big, hx + big, hy)
    out.alpha_composite(layer)
    if R.FIT["pads"]:
        e = R.FIT["pads"]
        g = O.GEOM[view]
        lx, ly, lx1 = g["lsh"]; rx, ry, rx1 = g["rsh"]
        dd = ImageDraw.Draw(out)
        O._box(dd, lx - e, ly - (e - 1), lx1 + 1, ly + 3 + e, R.FIT["pad_ramp"])
        O._box(dd, rx - 1, ry - (e - 1), rx1 + e, ry + 3 + e, R.FIT["pad_ramp"])
    return out


# ---------------------------------------------------------------- bases
def bases(code="T01", look=None, faction=None):
    R.build_all(code, faction, look)
    src = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_S.txt"))
    up = parse(os.path.join(ROOT, "src/sprites/pc_s07_upper_E.txt"))["upperE"]
    dg = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_diag.txt"))
    look = look or {}
    raw = {"S": src["idle0"], "N": src["idleN"], "SE": dg["idleSE"], "NE": dg["idleNE"]}
    nopad = dict(R.FIT, pads=0)                     # pads are re-drawn over the posed arms
    up_ = {v: HD.head(O.dress(R.strip_arms(im, v), nopad, v), v, **look) for v, im in raw.items()}
    up_["E"] = HD.head(O.dress(up, nopad, "E"), "E", **look)
    full = {"S": O.dress(src["idle0"], R.FIT, "S"), "N": O.dress(src["idleN"], R.FIT, "N"),
            "SE": O.dress(dg["idleSE"], R.FIT, "SE"), "NE": O.dress(dg["idleNE"], R.FIT, "NE"),
            "E": O.dress(src["idleE"], R.FIT, "E")}
    return up_, full


def upper_only(img, y1=47):
    out = Image.new("RGBA", img.size, CLEAR)
    out.alpha_composite(img.crop((0, 0, 64, y1)), (0, 0))
    return out


VIEWS = ("S", "SE", "E", "NE", "N")
WEAPONS = [("pistol", "A 권총", "T01", None), ("airgun", "B 사격장 공기총", "T01", None),
           ("rifle", "B 계엄군 소총", "T06", None), ("baton", "E 경봉", "T02", {"gear": "HD03", "hair": "HR03"}),
           ("fist", "G 비무장", "T03", {"hair": "HR07", "color": "H2"})]


def aim_frame(weapon, view, f, ups, fulls):
    legs = legs_part(fulls[view])
    img = Image.new("RGBA", (64, 64), CLEAR)
    img.alpha_composite(legs)
    if view in ("S", "SE"):
        img.alpha_composite(front_compose(upper_only(ups[view]), view, f, weapon))
        return img
    fr = poses(weapon, view)[f % len(poses(weapon, view))]
    img.alpha_composite(compose(upper_only(ups[view]), view, fr, weapon))
    return img


def main():
    out = os.path.join(ROOT, "samples")
    allowed = P.allowed_set("S3", "H1", "H2", "PF-01")
    bad = []
    LW = 120
    sheet = Image.new("RGBA", (LW + 12 * 44, len(WEAPONS) * 56 + 4), C("P19"))
    anim = {}
    for i, (w, name, code, look) in enumerate(WEAPONS):
        ups, fulls = bases(code, look)
        d = ImageDraw.Draw(sheet); d.fontmode = "1"
        d.text((4, i * 56 + 22), name, font=FONT, fill=C("P09"))
        col = 0
        for v in VIEWS:                                      # aim idle in the 5 drawn views
            im = aim_frame(w, v, 0, ups, fulls)
            bad += check(im, allowed)
            sheet.alpha_composite(im.crop((10, 4, 54, 62)), (LW + col * 44, i * 56)); col += 1
        col += 0
        for f in range(len(poses(w, "E"))):                  # attack sequence, side view
            im = aim_frame(w, "E", f, ups, fulls)
            bad += check(im, allowed)
            sheet.alpha_composite(im.crop((10, 4, 54, 62)), (LW + col * 44, i * 56)); col += 1
        anim[w] = ([aim_frame(w, "E", f, ups, fulls) for f in range(len(poses(w, "E")))],
                   [aim_frame(w, "S", f, ups, fulls) for f in range(len(FRONT[w]))])
    upscale(sheet, 4).save(os.path.join(out, "14_weapons_x4.png"))
    # attack loop gif: each weapon E + S side by side
    frames = []
    for t in range(10):
        c = Image.new("RGBA", (len(WEAPONS) * 2 * 48, 60), C("P19"))
        for i, (w, *_r) in enumerate(WEAPONS):
            e, s = anim[w]
            c.alpha_composite(e[(t // 2) % len(e)].crop((8, 4, 56, 64)), (i * 96, 0))
            c.alpha_composite(s[(t // 2) % len(s)].crop((8, 4, 56, 64)), (i * 96 + 48, 0))
        frames.append(upscale(c, 3).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out, "14_weapons_attack.gif"), save_all=True, append_images=frames[1:], duration=90, loop=0)
    print("off-palette:", sorted(set(bad)) or 0)


if __name__ == "__main__" and len(sys.argv) == 1:
    main()


# ---------------------------------------------------------------- aim while moving (SD-16 §5.10)
DIRS = {"E": (1, 0), "NE": (1, -1), "N": (0, -1), "NW": (-1, -1), "W": (-1, 0), "SW": (-1, 1), "S": (0, 1), "SE": (1, 1)}
ANG = {k: math.degrees(math.atan2(-v[1], v[0])) % 360 for k, v in DIRS.items()}
OPP = {"E": "W", "W": "E", "N": "S", "S": "N", "NE": "SW", "SW": "NE", "NW": "SE", "SE": "NW"}
MIRROR = {"W": "E", "SW": "SE", "NW": "NE"}


def snap8(dx, dy):
    a = math.degrees(math.atan2(-dy, dx)) % 360
    return min(ANG, key=lambda k: min(abs(ANG[k] - a), 360 - abs(ANG[k] - a)))


def lower_sets(code, mode="walk"):
    """Leg frames without arms (the posed upper body supplies them)."""
    R.build_all(code)
    src = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_S.txt"))
    up = parse(os.path.join(ROOT, "src/sprites/pc_s07_upper_E.txt"))["upperE"]
    dg = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_diag.txt"))
    nopad = dict(R.FIT, pads=0)
    S = R.walk_frontback(torso(O.dress(src["idle0"], nopad, "S"), "S"), mode)
    N = R.walk_frontback(torso(O.dress(src["idleN"], nopad, "N"), "N"), mode)
    SE, _ = R.walk_diag(torso(O.dress(dg["idleSE"], nopad, "SE"), "SE"), mode)
    NE, _ = R.walk_diag(torso(O.dress(dg["idleNE"], nopad, "NE"), "NE"), mode, back=True)
    real_arm = R.arm
    R.arm = lambda *a, **k: Image.new("RGBA", (64, 64), CLEAR)
    E, _ = R.walk_side(O.dress(up, nopad, "E"), mode)
    R.arm = real_arm
    fl = lambda seq: [f.transpose(Image.FLIP_LEFT_RIGHT) for f in seq]
    sets = {"S": S, "N": N, "SE": SE, "NE": NE, "E": E, "W": fl(E), "SW": fl(SE), "NW": fl(NE)}
    A, hip, _, _ = R.gait(mode)
    fb = [0, 1, 0, 0, 1, 0] if mode == "walk" else [0, 1, -1, 0, 1, -1]
    bob = {d: (fb if d in ("S", "N") else hip) for d in sets}
    return sets, bob


def upper_sets(weapon, code, look=None):
    ups, _ = bases(code, look)
    out = {}
    for v in ("S", "SE", "E", "NE", "N"):
        out[v] = (front_compose(upper_only(ups[v], 45), v, 0, weapon) if v in ("S", "SE")
                  else compose(upper_only(ups[v], 45), v, poses(weapon, v)[0], weapon))
    for m, src in MIRROR.items():
        out[m] = out[src].transpose(Image.FLIP_LEFT_RIGHT)
    return out


def target_dummy():
    img = Image.new("RGBA", (24, 40), CLEAR)
    d = ImageDraw.Draw(img)
    d.rectangle([11, 18, 12, 39], fill=C("P17")); d.line([11, 18, 11, 39], fill=C("P19"))
    d.ellipse([2, 0, 21, 19], fill=C("P09"), outline=C("P01"))
    d.ellipse([6, 4, 17, 15], fill=C("P53")); d.ellipse([9, 7, 14, 12], fill=C("P09")); d.point((11, 9), fill=C("P53"))
    d.line([4, 39, 19, 39], fill=C("P03"))
    return img


def aim_split_demo():
    import tiles_s07 as TS
    VW, VH, FPS = 320, 180, 50
    lower, bob = lower_sets("T01", "walk")
    upper = upper_sets("pistol", "T01")
    world = Image.new("RGBA", (640, 480))
    for ty in range(15):
        for tx in range(20):
            world.alpha_composite(TS.panel_floor((tx * 3 + ty) % 5, sheen=(tx + ty) % 7 == 0), (tx * 32, ty * 32))
    tgt = (320, 220)
    world.alpha_composite(target_dummy(), (tgt[0] - 12, tgt[1] - 39))
    # 8-direction moves while aiming at the target: approach, strafe round, backpedal
    script = [("N", 0.7), ("E", 0.9), ("NE", 0.6), ("N", 0.8), ("NW", 0.8), ("W", 1.4), ("SW", 0.8), ("S", 0.8),
              ("SE", 0.6), ("E", 0.5), ("S", 1.0), (None, 0.6)]
    x, y = 320.0, 300.0
    step = {"diag": math.hypot(*R.STEP["walk"][1]), "ortho": R.STEP["walk"][0]}
    v = 96.0 / FPS
    dist = 0.0
    frames, strip = [], []
    last_leg = None
    for mv, secs in script:
        for t in range(int(secs * FPS)):
            aim = snap8(tgt[0] - x, (tgt[1] - 12) - y)
            if mv is None:
                legs_dir, k, rx, ry, rev = aim, 0, x, y, False
                low = lower[legs_dir][0]
                b = 0
            else:
                dx, dy = DIRS[mv]
                n = math.hypot(dx, dy)
                diff = abs(ANG[mv] - ANG[aim]) % 360
                diff = min(diff, 360 - diff)
                rev = diff > 90
                legs_dir = OPP[mv] if rev else mv
                x += dx / n * v; y += dy / n * v
                dist += v
                sp = step["diag"] if dx and dy else step["ortho"]
                k = int(dist // sp)
                back = dist - k * sp
                rx, ry = x - dx / n * back, y - dy / n * back
                idx = (-k) % 6 if rev else k % 6
                low = lower[legs_dir][idx]
                b = bob[legs_dir][idx]
            up = upper[aim]
            spr = Image.new("RGBA", (64, 64), CLEAR)
            lp = Image.new("RGBA", (64, 64), CLEAR); lp.alpha_composite(low.crop((0, 45, 64, 64)), (0, 45))
            spr.alpha_composite(lp)
            spr.alpha_composite(up, (0, b))
            cam_x, cam_y = round(x - VW / 2), round(y - VH / 2 - 14)
            fr = Image.new("RGBA", (VW, VH), C("P10"))
            fr.alpha_composite(world.crop((int(cam_x), int(cam_y), int(cam_x) + VW, int(cam_y) + VH)))
            sx, sy = int(round(rx - cam_x)), int(round(ry - cam_y))
            fr.alpha_composite(spr, (sx - 32, sy - 60))
            if sy < tgt[1] - cam_y:                        # depth sort: the target stands in front
                tx0, ty0 = int(tgt[0] - 12 - cam_x), int(tgt[1] - 39 - cam_y)
                fr.alpha_composite(target_dummy(), (tx0, ty0))
            d = ImageDraw.Draw(fr); d.fontmode = "1"
            lab = f"이동 {mv or '-'}  하체 {legs_dir}{' 역재생' if mv and rev else ''}  조준 {aim}"
            d.rectangle([0, 0, VW, 13], fill=C("P02"))
            d.text((4, 1), lab, font=FONT, fill=C("P09"))
            frames.append(upscale(fr, 2).convert("P", palette=Image.ADAPTIVE))
            if mv and t == int(secs * FPS) // 2:
                strip.append(fr.crop((sx - 40, sy - 70, sx + 40, sy + 6)))
    path = os.path.join(ROOT, "samples", "14_aim_split.gif")
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=20, loop=0)
    s = Image.new("RGBA", (80 * len(strip), 76), C("P19"))
    for i, im in enumerate(strip):
        s.alpha_composite(im, (i * 80, 0))
    upscale(s, 3).save(os.path.join(ROOT, "samples", "14_aim_split_strip.png"))
    print("aim split frames:", len(frames))


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "split":
    aim_split_demo()
