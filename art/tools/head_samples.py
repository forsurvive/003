"""Reference sample #6: head slots (hair x4, helmet, cap, glasses) on the PC across 8 directions.
Writes samples/13_heads_x6.png (head close-ups, 5 drawn views), 13_heads_idle_x4.png, 13_heads_run.gif."""
import os, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import rig_pc as R
from grid import upscale, check

ROOT = os.path.dirname(os.path.dirname(__file__))
FONT = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
C = lambda t: P.rgb(t) + (255,)
COMBOS = [
    ("T01", {"hair": "HR01", "color": "H1"}, "HR01 짧은 머리 · H1"),
    ("T01", {"hair": "HR02", "color": "H3"}, "HR02 단발 · H3"),
    ("T03", {"hair": "HR03", "color": "H6"}, "HR03 똥머리 · H6"),
    ("T01", {"hair": "HR04", "color": "H1"}, "HR04 짧게 민 머리"),
    ("T02", {"hair": "HR02", "color": "H7", "gear": "HG01"}, "경비 헬멧 + 단발(모자 아래)"),
    ("T03", {"hair": "HR03", "color": "H2", "gear": "HG02"}, "야구모자 + 똥머리(숨김)"),
    ("T01", {"hair": "HR01", "color": "H4", "eyes": "EY01"}, "안경 + 짧은 머리 · H4"),
    ("T03", {"hair": "HR02", "color": "H8", "gear": "HG02", "eyes": "EY01"}, "야구모자 + 안경 + 단발 · H8"),
]
VIEWS = ("S", "SE", "E", "NE", "N")
ORDER = ("S", "SE", "E", "NE", "N", "NW", "W", "SW")


def main():
    out = os.path.join(ROOT, "samples")
    built, report = [], []
    for code, look, name in COMBOS:
        sets, rep = R.build_all(code, None, look)
        built.append((name, sets)); report += rep
    R.build_all("T01")
    allowed = P.allowed_set("S3", "H1", "H2", "H3", "H4", "H6", "H7", "H8")
    bad = []
    # close-ups: head + shoulders, 5 drawn views
    LW = 180
    cu = Image.new("RGBA", (LW + 5 * 30, len(built) * 30 + 4), C("P19"))
    for i, (name, sets) in enumerate(built):
        d = ImageDraw.Draw(cu); d.fontmode = "1"
        d.text((4, i * 30 + 10), name, font=FONT, fill=C("P09"))
        for k, v in enumerate(VIEWS):
            fr = sets["idle"][v]
            bad += check(fr, allowed)
            cu.alpha_composite(fr.crop((17, 16, 47, 46)), (LW + k * 30, i * 30 + 2))
    upscale(cu, 6).save(os.path.join(out, "13_heads_x6.png"))
    # full idle, 8 directions
    sh = Image.new("RGBA", (8 * 52, len(built) * 56), C("P19"))
    for i, (name, sets) in enumerate(built):
        for k, v in enumerate(ORDER):
            sh.alpha_composite(sets["idle"][v].crop((6, 4, 58, 62)), (k * 52, i * 56))
    upscale(sh, 4).save(os.path.join(out, "13_heads_idle_x4.png"))
    frames = []
    for f in range(6):
        c = Image.new("RGBA", (8 * 52, len(built) * 56), C("P19"))
        for i, (name, sets) in enumerate(built):
            for k, v in enumerate(ORDER):
                c.alpha_composite(sets["run"][v][f].crop((6, 4, 58, 62)), (k * 52, i * 56))
        frames.append(upscale(c, 2).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out, "13_heads_run.gif"), save_all=True, append_images=frames[1:], duration=55, loop=0)
    worst = max(int(l.split("slip ")[1].split("px")[0]) for l in report)
    print("off-palette:", sorted(set(bad)) or 0, "| stances:", len(report), "worst slip:", worst)


if __name__ == "__main__":
    main()
