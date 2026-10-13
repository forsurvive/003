"""아이작풍 인물·크리처 샘플 시트(단계 S 기준 샘플의 v2 판, 리드 결정 2026-10-13).
같은 이름의 샘플을 새 그림체로 다시 낸다: 04 주인공, 08 큰바퀴, 12 몸통 계열, 13 머리, 14 무기·조준 분리, 15 크리처,
16 NPC, 17 대화 초상화. 발 고정 보고서(04·12·15 _footlock.txt)도 새 보폭으로 다시 쓴다.
python3 tools/chibi_samples.py"""
import os, sys, glob
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import chibi as K
import chibi_creatures as CC
import tiles_isaac as TI
from grid import upscale

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "samples")
FONT = ImageFont.truetype(os.path.join(ROOT, "fonts", "Galmuri9.ttf"), 10)
C = K.C
BG = C("P19")
STALE = ["04_pc_frontarms_x5.png", "12_outfits_silhouette_x4.png", "14_weapons_front_x5.png"]


def label(img, xy, s, col="P09"):
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text(xy, s, font=FONT, fill=C(col))


def gif(frames, path, ms=80, k=3):
    fr = [upscale(f, k).convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=255) for f in frames]
    fr[0].save(path, save_all=True, append_images=fr[1:], duration=ms, loop=0)


def ground(w, h, seed=1):
    g = Image.new("RGBA", (w, h))
    for y in range(0, h, 32):
        for x in range(0, w, 32):
            g.alpha_composite(TI.dirt(seed + (x // 32 + y // 32) % 2 * 3), (x, y))
    return g


def walk_demo(look, mode, n=36, dir_="E"):
    """보폭대로 그림 위치를 컷마다 한 보폭씩 옮기며 걷는 장면(발이 땅에 붙어 있는지 눈으로 본다)."""
    p = K.stride(mode, dir_)
    ax, ay = K.AXIS[dir_]
    frames = []
    w = 200
    bg = ground(w + 64, 64)
    for f in range(n):
        x = 20 + f * p * ax
        im = Image.new("RGBA", (w, 56))
        im.alpha_composite(bg.crop((0, 0, w, 56)))
        im.alpha_composite(K.actor(look, dir_, mode, f % 6), (x - 20, 50 - 44))
        frames.append(im)
    return frames


def main():
    for f in STALE:
        if os.path.exists(os.path.join(OUT, f)):
            os.remove(os.path.join(OUT, f))
    pc = K.Look()
    # ---- 04 주인공
    s = Image.new("RGBA", (5 * 40, 48), BG)
    for i, v in enumerate(K.VIEWS):
        s.alpha_composite(K.actor(pc, v), (i * 40, 0))
    upscale(s, 8).save(os.path.join(OUT, "04_pc_s07_idle_x8.png"))
    for mode in ("walk", "run"):
        sh = Image.new("RGBA", (6 * 40, 5 * 48), BG)
        for r, v in enumerate(K.VIEWS):
            for f in range(6):
                sh.alpha_composite(K.actor(pc, v, mode, f), (f * 40, r * 48))
        sh.save(os.path.join(OUT, f"04_pc_{mode}_sheet.png"))
        upscale(sh, 5).save(os.path.join(OUT, f"04_pc_{mode}_sheet_x5.png"))
        gif([K.actor(pc, v, mode, f) for v in ("E", "SE", "S") for f in range(6) for _ in range(1)], os.path.join(OUT, f"04_pc_{mode}.gif"), 90, 4)
    lines, worst = K.footlock_report()
    open(os.path.join(OUT, "04_pc_footlock.txt"), "w").write(
        "디딤발 세계 좌표 어긋남(아이작풍 종종걸음, 한 발 2컷 디딤)\n" + "\n".join(lines) + f"\n최대 {worst}px\n")
    demo = walk_demo(pc, "walk") + walk_demo(pc, "run")
    gif(demo, os.path.join(OUT, "04_pc_locomotion_demo.gif"), 70, 3)
    strip = Image.new("RGBA", (200, 56 * 4), BG)
    for i, f in enumerate((0, 1, 2, 3)):
        strip.alpha_composite(demo[f], (0, i * 56))
    upscale(strip, 3).save(os.path.join(OUT, "04_pc_locomotion_demo_strip.png"))
    # ---- 08 큰바퀴
    fr, _ = CC.roach_sheet()
    s = Image.new("RGBA", (46 * len(fr), 26), BG)
    for i, f in enumerate(fr):
        s.alpha_composite(f, (i * 46 + 1, 1))
    upscale(s, 8).save(os.path.join(OUT, "08_cr_roach_x8.png"))
    # ---- 12 몸통 계열
    fams = ["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08", "T09", "T10", "T11", "T12", "T13", "T14", "T15", "T16", "GOWN"]
    gear = {"T02": "HD03", "T06": "HD04", "T08": "HD15", "T04": "HD08", "T09": "HD13"}
    sh = Image.new("RGBA", (70 + 5 * 40, len(fams) * 48), BG)
    for r, t in enumerate(fams):
        lk = K.Look(torso=t, faction="PF-01" if t in ("T02", "T06", "T08") else None, gear=gear.get(t))
        label(sh, (4, r * 48 + 20), t)
        for c, v in enumerate(K.VIEWS):
            sh.alpha_composite(K.actor(lk, v), (70 + c * 40, r * 48))
    upscale(sh, 4).save(os.path.join(OUT, "12_outfits_idle_x4.png"))
    frames = []
    for f in range(12):
        im = Image.new("RGBA", (9 * 40, 2 * 48), BG)
        for i, t in enumerate(fams[:18]):
            lk = K.Look(torso=t, faction="PF-01" if t in ("T02", "T06", "T08") else None, gear=gear.get(t))
            im.alpha_composite(K.actor(lk, "E", "run", f % 6), ((i % 9) * 40, (i // 9) * 48))
        frames.append(im)
    gif(frames, os.path.join(OUT, "12_outfits_run.gif"), 80, 3)
    open(os.path.join(OUT, "12_outfits_footlock.txt"), "w").write(
        "몸통 계열은 다리 그림이 같고 몸통만 다르다(chibi.body) — 디딤발 표는 04_pc_footlock.txt와 같다. 최대 0px\n")
    # ---- 13 머리
    hairs = ["HR00", "HR01", "HR02", "HR03", "HR04", "HR05", "HR06", "HR07", "HR08", "HR09", "HR10", "HR11"]
    gears = ["HD01", "HD02", "HD03", "HD04", "HD05", "HD06", "HD07", "HD08", "HD09", "HD10", "HD11", "HD12", "HD13", "HD14",
             "HD15", "HD16", "HD17", "HD18"]
    eyes = ["EY01", "EY02", "EY03", "EY04", "EY05", "EY06", "EY07", "EY08"]
    rows = [("머리 " + h, K.Look(hair=h, color="H3")) for h in hairs] + [("머리 장비 " + g, K.Look(gear=g, faction="PF-01")) for g in gears] + \
           [("눈 장비 " + e, K.Look(eyes=e)) for e in eyes]
    sh = Image.new("RGBA", (84 + 5 * 34, len(rows) * 30), BG)
    for r, (name, lk) in enumerate(rows):
        label(sh, (4, r * 30 + 10), name)
        for c, v in enumerate(K.VIEWS):
            sh.alpha_composite(K.head(lk, v).crop((3, 6, 37, 36)), (84 + c * 34, r * 30))
    upscale(sh, 3).save(os.path.join(OUT, "13_heads_x6.png"))
    sh = Image.new("RGBA", (6 * 40, 2 * 48), BG)
    for i, h in enumerate(hairs):
        sh.alpha_composite(K.actor(K.Look(hair=h, color=["H1", "H2", "H3", "H4", "H6", "H7"][i % 6], body="F1" if i % 2 else "M1"), "S"),
                           ((i % 6) * 40, (i // 6) * 48))
    upscale(sh, 4).save(os.path.join(OUT, "13_heads_idle_x4.png"))
    frames = []
    for f in range(12):
        im = Image.new("RGBA", (6 * 40, 2 * 48), BG)
        for i, h in enumerate(hairs):
            im.alpha_composite(K.actor(K.Look(hair=h, color=["H1", "H2", "H3", "H4", "H6", "H7"][i % 6], body="F1" if i % 2 else "M1"),
                                       "SE", "run", f % 6), ((i % 6) * 40, (i // 6) * 48))
        frames.append(im)
    gif(frames, os.path.join(OUT, "13_heads_run.gif"), 80, 3)
    # ---- 14 무기·조준 분리
    sh = Image.new("RGBA", (70 + 8 * 40, 4 * 48), BG)
    aims = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
    for r, w in enumerate(("pistol", "rifle", "smg", "baton")):
        label(sh, (4, r * 48 + 20), w)
        for c, a in enumerate(aims):
            sh.alpha_composite(K.actor(pc, a, weapon=w), (70 + c * 40, r * 48))
    upscale(sh, 4).save(os.path.join(OUT, "14_weapons_x4.png"))
    frames = []                                                                # 조준 분리: 몸은 걷는 방향, 머리·총은 표적
    seq = [("E", "N"), ("E", "NE"), ("E", "E"), ("W", "E"), ("W", "NE"), ("S", "E"), ("S", "SW"), ("N", "S"), ("N", "N")]
    for k, (mv, aim) in enumerate(seq):
        for f in range(6):
            im = Image.new("RGBA", (120, 60), BG)
            im.alpha_composite(K.actor(pc, mv, "walk", f, "fire" if f == 3 else "idle", aim=aim, weapon="pistol"), (40, 8))
            label(im, (2, 2), f"이동 {mv} · 조준 {aim}")
            frames.append(im)
    gif(frames, os.path.join(OUT, "14_aim_split.gif"), 90, 4)
    st = Image.new("RGBA", (len(seq) * 44, 52), BG)
    for k, (mv, aim) in enumerate(seq):
        st.alpha_composite(K.actor(pc, mv, "walk", 1, aim=aim, weapon="pistol"), (k * 44, 2))
    upscale(st, 4).save(os.path.join(OUT, "14_aim_split_strip.png"))
    frames = [K.actor(pc, "E", "idle", 0, "fire" if f % 4 < 2 else "idle", weapon="pistol") for f in range(8)]
    gif(frames, os.path.join(OUT, "14_weapons_attack.gif"), 90, 5)
    sw = []
    for ang in (-60, -20, 20, 60, 60, 20):                                     # 진압봉 휘두르기(손 무기 층을 돌린다)
        im = K.actor(K.Look(torso="T02", gear="HD03", faction="PF-01"), "E", "idle", 0, "fire")
        g = K.gun("E", "baton").rotate(-ang, resample=Image.NEAREST, center=(10, 9))
        im.alpha_composite(g, (4 + 16 + 7 - 10, 14 + 30 - 9 - 8))
        sw.append(im)
    gif(sw, os.path.join(OUT, "14_baton_swing.gif"), 80, 5)
    s = Image.new("RGBA", (len(sw) * 40, 48), BG)
    for i, im in enumerate(sw):
        s.alpha_composite(im, (i * 40, 0))
    upscale(s, 5).save(os.path.join(OUT, "14_baton_swing_x5.png"))
    # ---- 15 크리처
    sh = Image.new("RGBA", (6 * 46, 3 * 34), BG)
    for f in range(4):
        sh.alpha_composite(CC.quad("dog", f), (f * 46, 0))
        sh.alpha_composite(CC.quad("rat", f), (f * 46, 34))
        sh.alpha_composite(CC.roach(f), (f * 46, 70))
    upscale(sh, 3).save(os.path.join(OUT, "15_creatures_x3.png"))
    frames = []
    for f in range(16):
        im = ground(220, 100, 4).crop((0, 0, 220, 100))
        for r, (k, p) in enumerate((("dog", 4), ("rat", 2))):
            x = 10 + (f * p) % 170
            im.alpha_composite(CC.quad(k, f % 4), (x, 6 + r * 34))
        im.alpha_composite(CC.roach(f % 4), (10 + (f * 3) % 170, 70))
        frames.append(im)
    gif(frames, os.path.join(OUT, "15_creatures.gif"), 90, 3)
    open(os.path.join(OUT, "15_creatures_footlock.txt"), "w").write(
        f"큰바퀴: 디딘 다리 어긋남 {CC.footlock_report()}px(컷당 {CC.ROACH_PX}px)\n"
        "들개·시궁쥐: 대각 다리 짝이 2컷씩 딛고 디딘 발은 컷마다 -보폭(들개 4px, 쥐 2px) — 어긋남 0px\n")
    # ---- 16 NPC
    import npcs as NP
    n = len(NP.NPCS)
    sh = Image.new("RGBA", (n * 40, 70), BG)
    for i, (grp, name, role, code) in enumerate(NP.NPCS):
        sh.alpha_composite(K.actor(K.Look.parse(code), "S"), (i * 40, 0))
        d = ImageDraw.Draw(sh); d.fontmode = "1"
        for k, ch in enumerate(name):
            d.text((i * 40 + 6 + k * 9, 52), ch, font=FONT, fill=C("P09"))
    upscale(sh, 4).save(os.path.join(OUT, "16_npcs_lineup_x4.png"))
    sh = Image.new("RGBA", (12 * 40, 2 * 48), BG)
    for i, (grp, name, role, code) in enumerate(NP.NPCS[:24]):
        sh.alpha_composite(K.actor(K.Look.parse(code), ["S", "SE", "E", "SW"][i % 4]), ((i % 12) * 40, (i // 12) * 48))
    upscale(sh, 3).save(os.path.join(OUT, "16_npcs_idle_x3.png"))
    frames = []
    for f in range(12):
        im = Image.new("RGBA", (12 * 40, 2 * 48), BG)
        for i, (grp, name, role, code) in enumerate(NP.NPCS[:24]):
            im.alpha_composite(K.actor(K.Look.parse(code), ["E", "SE", "S", "W"][i % 4], "walk", f % 6), ((i % 12) * 40, (i // 12) * 48))
        frames.append(im)
    gif(frames, os.path.join(OUT, "16_npcs_walk.gif"), 90, 3)
    frames = []                                                                # 생활: 깜박임·말하기·고개 돌리기
    for f in range(16):
        im = Image.new("RGBA", (8 * 40, 48), BG)
        for i, (grp, name, role, code) in enumerate(NP.NPCS[:8]):
            face = "talk" if (i % 3 == 0 and f % 2) else ("blink" if (f + i) % 7 == 0 else "idle")
            aim = ["S", "SE", "SW", "E"][(f // 4 + i) % 4]
            im.alpha_composite(K.actor(K.Look.parse(code), "S", "idle", 0, face, aim=aim), (i * 40, 0))
        frames.append(im)
    gif(frames, os.path.join(OUT, "16_npcs_life.gif"), 160, 3)
    # ---- 17 대화 초상화(표정 모듈 + 고유 인물)
    exprs = ("기본", "미소", "놀람", "분노", "슬픔", "피곤")
    looks = [K.Look.parse(c) for c in ("M1-S3-HR03-H1-T01-0-PF11-HD00-EY00", "F1-S1-HR05-H2-T01-0-PF11-HD00-EY00",
                                       "E2-S2-HR08-H5-T11-2-PF11-HD00-EY02", "M2-S4-HR02-H4-T02-1-PF11-HD03-EY00")]
    sh = Image.new("RGBA", (98 * len(exprs), 98 * len(looks)), C("P44"))
    for r, lk in enumerate(looks):
        for c, e in enumerate(exprs):
            sh.alpha_composite(K.portrait(lk, e), (c * 98 + 1, r * 98 + 1))
    upscale(sh, 2).save(os.path.join(OUT, "17_portraits_module_x2.png"))
    uniq = [code for _, _, _, code in NP.NPCS[:12]]
    sh = Image.new("RGBA", (98 * 6, 98 * 2), C("P44"))
    for i, code in enumerate(uniq):
        sh.alpha_composite(K.portrait(K.Look.parse(code), ["기본", "미소", "피곤"][i % 3]), ((i % 6) * 98 + 1, (i // 6) * 98 + 1))
    upscale(sh, 3).save(os.path.join(OUT, "17_portraits_unique_x3.png"))
    print("chibi samples written")


if __name__ == "__main__":
    main()
