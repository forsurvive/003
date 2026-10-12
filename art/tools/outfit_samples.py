"""Reference sample #5: torso families T01/T02/T03/T06 (+ T06 faction swap) on the PC rig.
Writes samples/12_outfits_idle_x4.png, 12_outfits_silhouette_x4.png, 12_outfits_run.gif, 12_outfits_footlock.txt."""
import os, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import rig_pc as R
from grid import upscale, check

ROOT = os.path.dirname(os.path.dirname(__file__))
FONT = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
FITS = [("T01", None, "T01 점프슈트"), ("T02", None, "T02 경비 진압복"), ("T03", None, "T03 황무지 평상복"),
        ("T06", "PF-01", "T06 전투 아머 · 계엄군"), ("T06", "PF-12", "T06 전투 아머 · PF-12 교체")]
ORDER = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")
C = lambda t: P.rgb(t) + (255,)


def label(img, xy, s):
    d = ImageDraw.Draw(img); d.fontmode = "1"
    d.text(xy, s, font=FONT, fill=C("P09"))


def main():
    out = os.path.join(ROOT, "samples")
    built, report = [], []
    for code, fac, name in FITS:
        sets, rep = R.build_all(code, fac)
        built.append((name, sets)); report += rep
    R.build_all("T01")
    LW = 150
    # idle sheet
    sh = Image.new("RGBA", (LW + 8 * 52, len(built) * 56 + 4), C("P19"))
    allowed = P.allowed_set("S3", "H1", "PF-01", "PF-12")
    bad = []
    for i, (name, sets) in enumerate(built):
        label(sh, (4, i * 56 + 24), name)
        for k, dname in enumerate(ORDER):
            fr = sets["idle"][dname]
            bad += check(fr, allowed)
            sh.alpha_composite(fr.crop((6, 4, 58, 62)), (LW + k * 52, i * 56))
    upscale(sh, 4).save(os.path.join(out, "12_outfits_idle_x4.png"))
    # silhouette test: S, E, N in solid ink side by side per outfit
    sil = Image.new("RGBA", (len(built) * (3 * 40 + 16) + 8, 84), C("P09"))
    for i, (name, sets) in enumerate(built):
        for k, dname in enumerate(("S", "E", "N")):
            fr = sets["idle"][dname]
            m = Image.new("RGBA", fr.size, (0, 0, 0, 0))
            m.paste(Image.new("RGBA", fr.size, C("P01")), (0, 0), fr)
            sil.alpha_composite(m.crop((12, 10, 52, 64)), (4 + i * (3 * 40 + 16) + k * 40, 8))
        d = ImageDraw.Draw(sil); d.fontmode = "1"
        d.text((8 + i * (3 * 40 + 16), 68), name.split(" ")[0] + ("" if "PF-12" not in name else " PF-12"), font=FONT, fill=C("P02"))
    upscale(sil, 4).save(os.path.join(out, "12_outfits_silhouette_x4.png"))
    # run gif: rows = outfits, cols = 8 directions
    frames = []
    for f in range(6):
        c = Image.new("RGBA", (8 * 52, len(built) * 56), C("P19"))
        for i, (name, sets) in enumerate(built):
            for k, dname in enumerate(ORDER):
                c.alpha_composite(sets["run"][dname][f].crop((6, 4, 58, 62)), (k * 52, i * 56))
        frames.append(upscale(c, 2).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out, "12_outfits_run.gif"), save_all=True, append_images=frames[1:], duration=55, loop=0)
    open(os.path.join(out, "12_outfits_footlock.txt"), "w").write("\n".join(report) + "\n")
    worst = max(int(l.split("slip ")[1].split("px")[0]) for l in report)
    print("off-palette:", sorted(set(bad)) or 0, "| footlock stances:", len(report), "worst slip:", worst)


if __name__ == "__main__":
    main()
