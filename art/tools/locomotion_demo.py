"""No-slide locomotion demo (SD-16 §3.6.3): the PC crosses a paved floor following the runtime rules.
- frames advance by distance travelled (walk 6 px, run 8 px per frame; diagonal (4,4)/(6,6) px)
- the sprite is drawn at the last frame boundary (stepped render), the camera follows the logical position
- starting: the first input tick shows frame 0 (contact) at once; stopping: no skid, one settle frame, idle
Writes samples/04_pc_locomotion_demo.gif (50 fps, x2) and samples/04_pc_locomotion_demo_strip.png."""
import os, sys, math
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import parse, upscale
import rig_pc as R
import tiles_r01 as T

ROOT = os.path.dirname(os.path.dirname(__file__))
FPS = 50
VW, VH = 320, 180
SPEED = {"walk": 96.0, "run": 144.0}          # 3.0 / 4.5 t/s
DIRV = {"E": (1, 0), "W": (-1, 0), "S": (0, 1), "N": (0, -1),
        "SE": (1, 1), "NE": (1, -1), "SW": (-1, 1), "NW": (-1, -1)}

# (direction or None, mode, seconds)
SCRIPT = [(None, "walk", 0.4), ("E", "run", 1.6), ("SE", "walk", 1.2), ("E", "walk", 1.0), ("NE", "run", 1.0),
          ("N", "walk", 0.8), (None, "walk", 0.6), ("W", "run", 1.2), (None, "walk", 0.6)]


def floor(w, h):
    img = Image.new("RGBA", (w, h))
    for ty in range(h // 32):
        for tx in range(w // 32):
            img.alpha_composite(T.pavers(seed=tx * 31 + ty * 7, broken=(tx * ty) % 3), (tx * 32, ty * 32))
    return img


def idle_frames():
    src = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_S.txt"))
    dg = parse(os.path.join(ROOT, "src/sprites/pc_s07_jumpsuit_diag.txt"))
    fl = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)
    return {"S": src["idle0"], "E": src["idleE"], "N": src["idleN"], "SE": dg["idleSE"], "NE": dg["idleNE"],
            "W": fl(src["idleE"]), "SW": fl(dg["idleSE"]), "NW": fl(dg["idleNE"])}


def main():
    sets, _ = R.build_all()
    idles = idle_frames()
    world = floor(1280, 640)
    x, y = 200.0, 320.0                # logical position (feet)
    dist = 0.0                         # distance along the current gait
    face, mode = "E", "walk"
    out, strip = [], []
    tick = 0
    for d, m, secs in SCRIPT:
        for _ in range(int(secs * FPS)):
            if d is None:
                if dist > 0:           # stop: snap to the frame boundary pose's settle (contact) then idle
                    dist = 0.0
                    settle = True
                else:
                    settle = False
                spr = sets[mode][face][0] if settle else idles[face]
                rx, ry = x, y
            else:
                if d != face or m != mode:
                    face, mode = d, m
                vx, vy = DIRV[d]
                diag = vx != 0 and vy != 0
                step_px = math.hypot(*R.STEP[m][1]) if diag else R.STEP[m][0]
                nrm = math.hypot(vx, vy)
                v = SPEED[m] / FPS
                x += vx / nrm * v
                y += vy / nrm * v
                dist += v
                k = int(dist // step_px)
                spr = sets[m][d][k % 6]
                back = dist - k * step_px        # distance since the last frame boundary
                rx, ry = x - vx / nrm * back, y - vy / nrm * back
            cam_x, cam_y = x - VW / 2, y - VH / 2 - 10
            fr = world.crop((int(round(cam_x)), int(round(cam_y)), int(round(cam_x)) + VW, int(round(cam_y)) + VH)).copy()
            sx, sy = int(round(rx)) - int(round(cam_x)), int(round(ry)) - int(round(cam_y))
            # contact shadow
            for ddx in range(-7, 8):
                for ddy in (-1, 0, 1):
                    if (ddx / 7.5) ** 2 + (ddy / 1.6) ** 2 <= 1:
                        px, py = sx + ddx, sy + ddy
                        if 0 <= px < VW and 0 <= py < VH:
                            r_, g_, b_, a_ = fr.getpixel((px, py))
                            fr.putpixel((px, py), (r_ * 2 // 3, g_ * 2 // 3, b_ * 2 // 3, 255))
            fr.alpha_composite(spr, (sx - 32, sy - 60))
            out.append(upscale(fr, 2).convert("P", palette=Image.ADAPTIVE))
            if d == "E" and m == "run" and len(strip) < 8 and tick % 3 == 0:
                strip.append(fr.crop((VW // 2 - 60, VH // 2 - 40, VW // 2 + 60, VH // 2 + 40)))
            tick += 1
    path = os.path.join(ROOT, "samples", "04_pc_locomotion_demo.gif")
    out[0].save(path, save_all=True, append_images=out[1:], duration=1000 // FPS, loop=0, disposal=2)
    s = Image.new("RGBA", (120 * len(strip), 80))
    for i, im in enumerate(strip):
        s.alpha_composite(im, (i * 120, 0))
    upscale(s, 3).convert("RGB").save(os.path.join(ROOT, "samples", "04_pc_locomotion_demo_strip.png"))
    print(len(out), "frames")


if __name__ == "__main__":
    main()
