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
COMBOS = [   # canonical codes (SD-07b §3.4~3.6)
    ("T01", {"hair": "HR03", "color": "H1"}, "HR03 짧은 커트 · H1"),
    ("T01", {"hair": "HR05", "color": "H3"}, "HR05 단발 · H3"),
    ("T03", {"hair": "HR07", "color": "H6"}, "HR07 쪽머리 · H6"),
    ("T01", {"hair": "HR06", "color": "H2"}, "HR06 긴 생머리 · H2"),
    ("T01", {"hair": "HR08", "color": "H7"}, "HR08 덥수룩 · H7"),
    ("T01", {"hair": "HR09", "color": "H8"}, "HR09 꽁지 · H8"),
    ("T01", {"hair": "HR11", "color": "H2"}, "HR11 파마 · H2"),
    ("T01", {"hair": "HR01", "color": "H5"}, "HR01 스포츠 · H5"),
    ("T01", {"hair": "HR00", "color": "H1"}, "HR00 민머리"),
    ("T02", {"hair": "HR05", "color": "H7", "gear": "HD03"}, "HD03 경비 헬멧 + 단발"),
    ("T03", {"hair": "HR07", "color": "H2", "gear": "HD05"}, "HD05 챙모자 + 쪽머리(숨김)"),
    ("T06", {"hair": "HR02", "color": "H1", "gear": "HD04"}, "HD04 계엄군 철모"),
    ("T01", {"hair": "HR01", "color": "H2", "gear": "HD02", "eyes": "EY06"}, "HD02 안전모 + EY06 고글"),
    ("T03", {"hair": "HR05", "color": "H2", "gear": "HD07"}, "HD07 머릿수건"),
    ("T06", {"hair": "HR01", "color": "H1", "gear": "HD15"}, "HD15 장교 정모"),
    ("T01", {"hair": "HR03", "color": "H4", "eyes": "EY01"}, "EY01 둥근 안경"),
    ("T01", {"hair": "HR02", "color": "H4", "eyes": "EY02"}, "EY02 각진 안경"),
    ("T01", {"hair": "HR08", "color": "H5", "eyes": "EY03"}, "EY03 돋보기"),
    ("T03", {"hair": "HR01", "color": "H1", "eyes": "EY05"}, "EY05 색안경"),
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
    allowed = P.allowed_set("S3", *P.HAIR.keys(), "PF-01")
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
