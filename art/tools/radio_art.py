"""라디오 그림(단계 1-10b, SD-12 §10.1 · §10.6 · SD-16 '라디오 소형 3 · 로고'):
  · 화자 얼굴 24×24 × 4 — 송미래(헤드폰 · 청록 단발) · 남궁혁(구울 장관 · 양복 · 붉은 넥타이) · 공보방송(옛 마이크 + 무궁화 휘장) · 구내방송(볼트 천장 확성기)
    HUD 자막 띠 왼쪽에 그대로(색) 그린다 → game/assets/ui/radio_icons.png (96×24)
  · 방송국 로고 48×48 × 3(1비트 흰색 + 알파 — 핍-보이 CRT 셰이더가 칠한다): ST-11 볼트 문 톱니 · ST-01 남산 송신탑과 전파 · ST-02 무궁화 휘장과 월계
    → game/assets/ui/radio_logos.png (144×48)
  python3 art/tools/radio_art.py [--preview 경로.png]
"""
import os, sys, math
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import palette as P

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "assets", "ui")


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


S2 = P.SKIN["S2"]
SG = P.SKIN["SG1"]
H8 = P.HAIR["H8"]
H4 = P.HAIR["H4"]
N = P.NAMED

# 글자 → 색. 'k' 배경(어두운 방송실 벽 · 가장자리는 HUD가 테를 두른다)
PAL_SONG = {"k": N["P01"], "K": N["P02"], "o": N["P00"], "h": H8[0], "H": H8[1], "i": H8[2], "I": H8[3],
            "s": S2[2], "S": S2[1], "W": N["P09"], "l": S2[3], "L": S2[4], "e": N["P00"], "m": S2[1], "M": "#C46A5A",
            "p": N["P03"], "P": N["P04"], "q": N["P06"], "r": "#E04A35",
            "c": N["P30"], "C": N["P29"], "d": N["P28"], "w": N["P08"], "n": S2[1]}
SONG = [
    "kkkkkkkkkkkkkkkkkkkkkkkk",
    "kkkkkkkkkppppppkkkkkkkkk",
    "kkkkkkkpp......ppkkkkkkk",
    "kkkkkkp..oooooo..pkkkkkk",
    "kkkkkp.ooHHHHHHoo.pkkkkk",
    "kkkkkpoHHHiiIHHHHo.pkkkk",
    "kkkkp.oHHiiHHHHHhho.pkkk",
    "kkkkpohHHHHHHHHHHhhopkkk",
    "kkkPPohHHlllllHHHhhoPPkk",
    "kkPqPohHlLLlllllHhhoPqPk",
    "kkPqPohHlhhllhhllShoPqPk",
    "kkPqPohllWellWelllSoPqPk",
    "kkPrPohlleelleelllSoPrPk",
    "kkPPPohlllllllllllSoPPPk",
    "kkkkkoohlllllsllllSokkkk",
    "kkkkkkoollllsslllSSokkkk",
    "kkkkkkkosllMMMMlSSokkkkk",
    "kkkkkkkkoSlllllSSokkkkkk",
    "kkkkkkkkkoSSSSSSokkkkkkk",
    "kkkkkkkkkkonnnnokkkkkkkk",
    "kkkkkkkccoownwwoocckkkkk",
    "kkkkkccCCcoowwwocCCcckkk",
    "kkkkcCCcccoowwwoccccCckk",
    "kkkcCCcccccowwocccccCCck",
]
# 남궁혁: 2077년 그날을 기억하는 구울 장관 — 드러난 살갗(x) · 꺼진 눈 · 단정히 빗은 회색 머리 · 남색 양복 · 붉은 넥타이 · 금빛 배지
PAL_NAMGUNG = {"k": N["P01"], "o": N["P00"], "a": H4[1], "A": H4[2], "B": H4[0],
               "g": SG[2], "G": SG[1], "L": SG[3], "x": "#7A4A3A", "X": "#5C3328", "y": "#E8C23A", "e": "#0B0A0D", "E": "#D8CC80",
               "u": N["P11"], "U": N["P10"], "v": N["P12"], "w": N["P08"], "r": N["P53"], "R": N["P52"], "b": N["P49"], "m": SG[0]}
NAMGUNG = [
    "kkkkkkkkkkkkkkkkkkkkkkkk",
    "kkkkkkkkkoooooookkkkkkkk",
    "kkkkkkkooAAAaaaaookkkkkk",
    "kkkkkkoAAAaaaaaaaBokkkkk",
    "kkkkkoaAaaaaaaaaaaBokkkk",
    "kkkkkoaaggggLLgggaBokkkk",
    "kkkkkogggLLLLggggggokkkk",
    "kkkkkoggxggLggggxggokkkk",
    "kkkkkogGGegggggeGGgokkkk",
    "kkkkkogGEegggggEeGgokkkk",
    "kkkkoogggggggggggXgookkk",
    "kkkkoxggggGgggggxXgokkkk",
    "kkkkkoggggGGggggggGokkkk",
    "kkkkkoGgggmmmmmggGGokkkk",
    "kkkkkkoGgxggggggGGokkkkk",
    "kkkkkkkoGGgggggGGokkkkkk",
    "kkkkkkkkoGGGGGGGokkkkkkk",
    "kkkkkkkkkoGGXGGokkkkkkkk",
    "kkkkkkkuuowwwwwouukkkkkk",
    "kkkkkuuuUowrrwwoUuuukkkk",
    "kkkkuuvuUUowrRwoUUuvuukk",
    "kkkuuvuuUUowrrwoUUuubuuk",
    "kkuuvuuuUUUorRoUUUuuuuuk",
    "kuuvuuuuUUUorroUUUUuuuuu",
]
# 공보방송: 옛 리본 마이크(크롬) + 받침의 무궁화 휘장(금) — 깃발 대신 남색 휘장 바탕
PAL_GOV = {"k": "#142445", "K": "#1F3A6E", "o": N["P00"], "c": N["P07"], "C": N["P09"], "d": N["P05"], "D": N["P04"],
           "g": N["P49"], "G": N["P50"], "y": N["P48"], "r": N["P53"], "w": N["P08"]}
GOV = [
    "kkkkkkkkkkkkkkkkkkkkkkkk",
    "kKkkkkkkkkoooooookkkkkKk",
    "kkkkkkkkkocCCCCcdokkkkkk",
    "kkkkkkkkocCcdcdcddokkkkk",
    "kKkkkkkkoCcdcdcdcdokkkKk",
    "kkkkkkkkocdcdcdcddokkkkk",
    "kkkkkkkkoCcdcdcdcdokkkkk",
    "kkkkkkkkocdcdcdcddokkkkk",
    "kkkkkkkkoCcdcdcdcdokkkkk",
    "kkkkkkkkocdcdcdcddokkkkk",
    "kkkkkkkkkoccddddDokkkkkk",
    "kkkkkkkkkkooccDDookkkkkk",
    "kkkkkkkkkkkkocDokkkkkkkk",
    "kkkkkkkkkkkkocDokkkkkkkk",
    "kkkkkkkkkoooooooookkkkkk",
    "kkkkkkkkoyggggggggyokkkk",
    "kkkkkkkoygggGrGgggggokkk",
    "kkkkkkkoyggGrrrGggggokkk",
    "kkkkkkkoygGrrGrrGgggokkk",
    "kkkkkkkoyggGrrrGggggokkk",
    "kkkkkkkoygggGrGgggggokkk",
    "kkkkkkkkoyggggggggyokkkk",
    "kkkkkkoooooooooooooookkk",
    "kkkkkkoddddddddddddddokk",
]
# 구내방송: 볼트 천장 확성기(노랑) · 파란 벽 · 소리 물결
PAL_PA = {"k": N["P43"], "K": N["P44"], "o": N["P00"], "y": N["P48"], "Y": N["P49"], "z": N["P47"], "w": N["P09"],
          "b": N["P45"], "B": N["P46"], "d": N["P03"], "D": N["P05"]}
PA = [
    "kkkkkkkkkkkkkkkkkkkkkkkk",
    "kKKKKKKKKKKKKKKKKKKKKKKk",
    "kkkkkkkkkkoooookkkkkkkkk",
    "kkkkkkkkkkoDDDokkkkkkkkk",
    "kkkkkkkkkkodDdokkkkkkkkk",
    "kkkkkkkkkoooooookkkkkkkk",
    "kkkkkkkkoyyYYyyzokkkkkkk",
    "kkkkkkkkoyYYYYyzokkkkkkk",
    "kkkkkkkoyyYYYYyyzokkkkkk",
    "kkkkkkkoyYYYYYYyzokkkkkk",
    "kkkkkkoyyYYYYYYyyzokkkkk",
    "kkkkkkoyYYYYYYYYyzokkBkk",
    "kkkkkoyyYYYYYYYYyyzokkBk",
    "kkBkkoyYYYYYYYYYYyzokkBk",
    "kBkkoyyYYYYYYYYYYyyzokkB",
    "kBkkoooooooooooooooookkB",
    "kBkkkkoddddddddddddokkkB",
    "kkBkkkkoddddddddddokkkBk",
    "kkBkkkkkoooooooooookkkBk",
    "kkkBkkkkkkkkkkkkkkkkkBkk",
    "kkkkkkkkkkkkkkkkkkkkkkkk",
    "kKKKKKKKKKKKKKKKKKKKKKKk",
    "kkkkkkkkkkkkkkkkkkkkkkkk",
    "kkkkkkkkkkkkkkkkkkkkkkkk",
]


def grid_img(rows, pal):
    assert len(rows) == 24, len(rows)
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    px = img.load()
    for y, r in enumerate(rows):
        assert len(r) == 24, (y, len(r), r)
        for x, ch in enumerate(r):
            if ch == ".":
                ch = "k"
            px[x, y] = hexrgb(P.resolve(pal[ch]) if not pal[ch].startswith("#") else pal[ch])
    return img


# ---------------------------------------------------------------- 로고 48×48(1비트)
def _bits(draw_fn):
    im = Image.new("L", (48 * 4, 48 * 4), 0)                          # 4배로 그리고 줄여 임계(가장자리 계단 고르게)
    draw_fn(ImageDraw.Draw(im), 4)
    small = im.resize((48, 48), Image.BOX)
    out = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    sp, op = small.load(), out.load()
    for y in range(48):
        for x in range(48):
            if sp[x, y] >= 128:
                op[x, y] = (255, 255, 255, 255)
    return out


def logo_vault(d, k):
    c = 24 * k
    r_out, r_in = 21 * k, 16 * k
    for i in range(16):                                                # 볼트 문 톱니 16개
        a0 = i * math.tau / 16
        pts = []
        for da, rr in [(-0.09, r_in), (-0.07, r_out), (0.07, r_out), (0.09, r_in)]:
            pts.append((c + math.cos(a0 + da) * rr, c + math.sin(a0 + da) * rr))
        d.polygon(pts, fill=255)
    d.ellipse([c - 17 * k, c - 17 * k, c + 17 * k, c + 17 * k], fill=255)
    d.ellipse([c - 14 * k, c - 14 * k, c + 14 * k, c + 14 * k], fill=0)
    d.ellipse([c - 12 * k, c - 12 * k, c + 12 * k, c + 12 * k], fill=255)
pass


def logo_namsan(d, k):
    # 산등성이
    d.pieslice([0, 37 * k, 48 * k, 70 * k], 180, 360, fill=255)            # 남산 능선
    d.polygon([(0, 46 * k), (10 * k, 41 * k), (16 * k, 43 * k), (0, 48 * k)], fill=255)
    cx = 24 * k
    d.rectangle([cx - k, 6 * k, cx, 13 * k], fill=255)                 # 안테나
    d.rectangle([cx - 2 * k, 13 * k, cx + k, 16 * k], fill=255)
    d.polygon([(cx - 6 * k, 19 * k), (cx + 5 * k, 19 * k), (cx + 4 * k, 23 * k), (cx - 5 * k, 23 * k)], fill=255)   # 전망대
    d.rectangle([cx - 7 * k, 17 * k, cx + 6 * k, 19 * k], fill=255)
    d.rectangle([cx - 4 * k, 20 * k, cx + 3 * k, 21 * k - 1], fill=0)  # 전망 창 띠
    d.polygon([(cx - 2 * k, 23 * k), (cx + k, 23 * k), (cx + 2 * k, 39 * k), (cx - 3 * k, 39 * k)], fill=255)    # 기둥
    for i, rr in enumerate([7, 11, 15]):                               # 전파
        bb = [cx - rr * k - k // 2, 11 * k - rr * k, cx + rr * k - k // 2, 11 * k + rr * k]
        w = 2 * k
        d.arc(bb, 200, 250, fill=255, width=w)
        d.arc(bb, 290, 340, fill=255, width=w)


def logo_gov(d, k):
    c = 24 * k
    d.ellipse([c - 22 * k, c - 22 * k, c + 22 * k, c + 22 * k], fill=255)
    d.ellipse([c - 20 * k, c - 20 * k, c + 20 * k, c + 20 * k], fill=0)
    for side in (-1, 1):                                               # 월계 잎
        for i in range(6):
            a = math.radians(110 + i * 22) if side < 0 else math.radians(70 - i * 22)
            px_, py_ = c + math.cos(a) * 16 * k, c + math.sin(a) * 16 * k
            d.ellipse([px_ - 2.4 * k, py_ - 1.4 * k, px_ + 2.4 * k, py_ + 1.4 * k], fill=255)
    for i in range(5):                                                 # 무궁화 다섯 꽃잎
        a = -math.pi / 2 + i * math.tau / 5
        px_, py_ = c + math.cos(a) * 6.5 * k, c - 2 * k + math.sin(a) * 6.5 * k
        d.ellipse([px_ - 4.6 * k, py_ - 4.6 * k, px_ + 4.6 * k, py_ + 4.6 * k], fill=255)
    d.ellipse([c - 2.6 * k, c - 4.6 * k, c + 2.6 * k, c + 0.6 * k], fill=0)
    d.ellipse([c - 1.2 * k, c - 3.2 * k, c + 1.2 * k, c - 0.8 * k], fill=255)
    d.rectangle([c - 9 * k, c + 9 * k, c + 9 * k, c + 11 * k], fill=255)   # 아래 띠(공문의 줄)


def main():
    os.makedirs(OUT, exist_ok=True)
    icons = Image.new("RGBA", (96, 24), (0, 0, 0, 0))
    for i, (rows, pal) in enumerate([(SONG, PAL_SONG), (NAMGUNG, PAL_NAMGUNG), (GOV, PAL_GOV), (PA, PAL_PA)]):
        icons.paste(grid_img(rows, pal), (i * 24, 0))
    icons.save(os.path.join(OUT, "radio_icons.png"))
    logos = Image.new("RGBA", (144, 48), (0, 0, 0, 0))
    for i, fn in enumerate([logo_vault, logo_namsan, logo_gov]):
        logos.paste(_bits(fn), (i * 48, 0))
    lp = logos.load()
    glyphs = [["111", "100", "111", "001", "111"], ["111", "101", "101", "101", "111"], ["111", "001", "010", "010", "010"]]   # 'S07' 3×5
    for gi, g in enumerate(glyphs):
        for yy, row in enumerate(g):
            for xx, b in enumerate(row):
                if b == "1":
                    lp[19 + gi * 4 + xx, 22 + yy] = (0, 0, 0, 0)
    logos.save(os.path.join(OUT, "radio_logos.png"))
    if "--preview" in sys.argv:
        dst = sys.argv[sys.argv.index("--preview") + 1]
        pv = Image.new("RGBA", (96 * 8, 24 * 8 + 48 * 4 + 8), (40, 40, 44, 255))
        pv.paste(icons.resize((96 * 8, 24 * 8), Image.NEAREST), (0, 0))
        lg = Image.new("RGBA", (144, 48), (5, 10, 6, 255))
        lg.alpha_composite(Image.new("RGBA", (144, 48), (0, 0, 0, 0)))
        g = Image.new("RGBA", (144, 48), (124, 240, 142, 255))
        lg.paste(g, (0, 0), logos)
        pv.paste(lg.resize((144 * 4, 48 * 4), Image.NEAREST), (0, 24 * 8 + 8))
        pv.save(dst)
    print("라디오 그림: 화자 4 · 로고 3")


if __name__ == "__main__":
    main()
