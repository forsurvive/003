"""Mobile touch HUD mockup (SD-12 §17.2 layout, SD-11 §15 controls) over the 봉천 scene.
Outputs samples/06_hud_mobile_640.png (base) and 06_hud_mobile_800.png (20:9 phone, world widened)."""
import os, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import scene_bongcheon as SB
from grid import upscale

ROOT = os.path.dirname(os.path.dirname(__file__))
C = P.rgb
U = lambda i, a=255: C(f"U{i}") + (a,)
F12 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri11.ttf"), 12)
F16 = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri14.ttf"), 15)


def widen(scene, W):
    """Extend a 640-wide world render to W by mirroring the edge strips (mock of the wider camera)."""
    if W == 640:
        return scene.copy()
    m = (W - 640) // 2
    out = Image.new("RGBA", (W, 360))
    out.alpha_composite(scene, (m, 0))
    out.alpha_composite(scene.crop((0, 0, m, 360)).transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
    out.alpha_composite(scene.crop((640 - m, 0, 640, 360)).transpose(Image.FLIP_LEFT_RIGHT), (W - m, 0))
    return out


def icon(name):
    """16x16 single-colour UI glyphs (drawn, no font)."""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = U(6)
    if name == "pip":       # wrist computer
        d.rectangle([2, 4, 13, 11], outline=c); d.rectangle([4, 6, 9, 9], fill=c); d.point([(11, 6), (11, 8)], fill=c)
    elif name == "pause":
        d.rectangle([4, 3, 6, 12], fill=c); d.rectangle([9, 3, 11, 12], fill=c)
    elif name == "hand":     # context / use
        d.rectangle([5, 7, 11, 13], fill=c)
        for x in (5, 7, 9, 11):
            d.line([x, 3 + (x == 5) * 2, x, 7], fill=c)
        d.line([3, 8, 5, 10], fill=c)
    elif name == "focus":    # crosshair
        d.ellipse([2, 2, 13, 13], outline=c); d.line([7, 0, 7, 5], fill=c); d.line([7, 10, 7, 15], fill=c)
        d.line([0, 7, 5, 7], fill=c); d.line([10, 7, 15, 7], fill=c); d.point((7, 7), fill=c)
    elif name == "roll":     # curved arrow
        d.arc([2, 3, 13, 14], 180, 360, fill=c); d.polygon([(11, 6), (15, 8), (12, 11)], fill=c)
        d.line([2, 9, 2, 12], fill=c)
    elif name == "throw":    # grenade
        d.ellipse([3, 5, 12, 14], fill=c); d.rectangle([6, 2, 9, 5], fill=c); d.line([10, 2, 13, 4], fill=c)
        d.point([(5, 8), (7, 10), (9, 8)], fill=U(1))
    elif name == "reload":   # magazine + arrow
        d.rectangle([5, 4, 10, 14], outline=c); d.line([5, 7, 10, 7], fill=c); d.line([5, 10, 10, 10], fill=c)
        d.line([12, 2, 14, 4], fill=c); d.line([12, 6, 14, 4], fill=c)
    elif name == "crouch":   # crouched figure
        d.ellipse([6, 2, 9, 5], fill=c); d.line([7, 6, 5, 10], fill=c); d.line([5, 10, 9, 11], fill=c)
        d.line([9, 11, 9, 14], fill=c); d.line([5, 10, 4, 14], fill=c); d.line([7, 7, 11, 9], fill=c)
    elif name == "heal":     # stimpak cross
        d.rectangle([6, 2, 9, 13], fill=c); d.rectangle([2, 6, 13, 9], fill=c)
    elif name == "pistol":
        d.rectangle([1, 5, 13, 8], fill=c); d.rectangle([2, 8, 5, 13], fill=c); d.point((12, 4), fill=c)
        d.line([6, 9, 8, 10], fill=c)
    return im


def layer(W):
    """Draw the HUD on a transparent layer; left groups anchor left, right groups right, centre centred."""
    L = Image.new("RGBA", (W, 360), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    d.fontmode = "1"
    R = W - 640   # right-group offset
    M = R // 2    # centre-group offset

    def text(xy, s, font=F12, col=5, shadow=True):
        x, y = xy
        if shadow:
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                d.text((x + dx, y + dy), s, font=font, fill=U(0))
        d.text((x, y), s, font=font, fill=U(col))

    def bar(x, y, w, h, frac, label):
        d.rectangle([x - 1, y - 1, x + w, y + h], fill=U(0))
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=U(2))
        d.rectangle([x, y, x + int(w * frac) - 1, y + h - 1], fill=U(5))
        text((x + w + 4, y - 3), label)

    def button(x, y, s, ic, big=False, alpha=150, label=None):
        d.ellipse([x - 1, y - 1, x + s, y + s], fill=U(0, 200))
        d.ellipse([x, y, x + s - 1, y + s - 1], fill=U(1, alpha), outline=U(4))
        L.alpha_composite(icon(ic), (x + s // 2 - 8, y + s // 2 - 8))
        if label:
            text((x + s // 2 - len(label) * 3, y + s - 2), label, F12, 5)

    def stick(cx, cy, label):
        d.ellipse([cx - 44, cy - 44, cx + 44, cy + 44], outline=U(4, 160))
        d.ellipse([cx - 56, cy - 56, cx + 56, cy + 56], outline=U(2, 110))       # sprint ring
        d.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=U(1, 150), outline=U(5))
        text((cx - len(label) * 6, cy + 46), label, F12, 4)

    # top-left: vitals, status, notifications, objective, support
    bar(8, 8, 140, 8, 0.82, "HP")
    bar(8, 20, 140, 6, 0.64, "AP")
    for k, g in enumerate(["leg", "rad"]):
        x0 = 8 + k * 16
        d.rectangle([x0 - 1, 29, x0 + 12, 42], fill=U(0, 200), outline=U(3))
        if g == "leg":   # crippled leg: boot + crack
            d.rectangle([x0 + 4, 31, x0 + 6, 38], fill=U(6)); d.rectangle([x0 + 4, 38, x0 + 9, 40], fill=U(6))
            d.line([x0 + 3, 34, x0 + 8, 33], fill=C("P54") + (255,))
        else:            # radiation trefoil (simplified)
            d.pieslice([x0 + 1, 31, x0 + 11, 41], 270, 330, fill=U(6)); d.pieslice([x0 + 1, 31, x0 + 11, 41], 30, 90, fill=U(6))
            d.pieslice([x0 + 1, 31, x0 + 11, 41], 150, 210, fill=U(6)); d.ellipse([x0 + 5, 35, x0 + 7, 37], fill=U(1))
    text((8, 50), "장소 발견: 봉천 계단마을")
    text((8, 66), "+10 XP", F12, 4)
    text((8, 116), "▶ 핍-보이 코드를 읽을", F12, 6)
    text((8, 132), "   사람을 찾는다", F12, 6)
    # subtitle band (radio / barks), 75% backing
    bx = 160 + M
    d.rectangle([bx, 6, bx + 320, 42], fill=U(0, 190))
    text((bx + 6, 8), "[라디오] 송미래: 관악 쪽 소식", F16, 5, shadow=False)
    text((bx + 6, 25), "하나 더 들어왔어요...", F16, 5, shadow=False)
    # top-right: pip-boy, pause, compass ring, radio chip
    button(556 + R, 8, 36, "pip")
    button(596 + R, 8, 36, "pause")
    cx, cy = 604 + R, 80
    d.ellipse([cx - 28, cy - 28, cx + 28, cy + 28], fill=U(0, 170), outline=U(4))
    d.ellipse([cx - 20, cy - 20, cx + 20, cy + 20], outline=U(2))
    text((cx - 5, cy - 27), "북", F12, 6, shadow=False)
    d.polygon([(cx, cy - 12), (cx + 4, cy + 4), (cx, cy), (cx - 4, cy + 4)], fill=U(6))
    d.rectangle([cx + 16, cy + 4, cx + 18, cy + 8], fill=C("P54") + (255,))   # hostile pip
    d.polygon([(cx - 15, cy - 10), (cx - 12, cy - 13), (cx - 9, cy - 10), (cx - 12, cy - 7)], fill=U(6))  # quest
    text((476 + R - 30, 112), "[라디오] 남산 방송", F12, 4)
    text((280 + M, 50), "[숨음]", F12, 6)
    # right cluster: weapon, heal, throw, reload, crouch, roll, focus, context, aim stick
    d.rectangle([560 + R, 152, 631 + R, 187], fill=U(0, 190), outline=U(4))
    L.alpha_composite(icon("pistol"), (566 + R, 162))
    text((586 + R, 162), "12/48", F12, 6, shadow=False)
    button(516 + R, 152, 36, "heal")
    button(512 + R, 196, 36, "throw")
    button(556 + R, 196, 36, "reload")
    button(596 + R, 196, 36, "crouch")
    button(466 + R, 244, 40, "roll")
    button(460 + R, 296, 44, "focus", alpha=180)
    button(408 + R, 292, 48, "hand", alpha=200)
    stick(564 + R, 284 + 10, "조준·사격")
    # left stick + interaction prompt (centre)
    stick(72, 288, "이동")
    text((214 + M, 250), "계단: 올라간다", F12, 6)
    return L


def render(W):
    scene = SB.build(hud=False)
    base = widen(scene, W)
    base.alpha_composite(layer(W))
    return base


if __name__ == "__main__":
    out = os.path.join(ROOT, "samples")
    for W in (640, 800):
        im = render(W)
        im.convert("RGB").save(os.path.join(out, f"06_hud_mobile_{W}.png"))
        upscale(im, 2).convert("RGB").save(os.path.join(out, f"06_hud_mobile_{W}_x2.png"))
    print("ok")
