"""아이작풍 크리처(SD-14, SD-16 §5 v2.0): 큰바퀴 CR-002, 변이 들개, 변이 시궁쥐.
옆 3/4 모습 한 방향(E, W는 반전). 굵은 먹선, 면 세 단계, 다리는 거리 구동(컷당 px는 메타에).
"""
import os, sys, math, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from chibi import C, CLEAR, INK, L, outline, ramp, shade

SHELL = ramp(["P16", "P17", "P18", "P19", "P20"])


def _ellipse(img, cx, cy, rx, ry, col_ramp, hi=0.6, extra=None):
    for y in range(img.height):
        for x in range(img.width):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            q = nx * nx + ny * ny
            if q <= 1:
                nz = math.sqrt(1 - q)
                col = shade(col_ramp, nx * L[0] + ny * L[1] + nz * L[2], hi)
                if extra:
                    col = extra(nx, ny, col) or col
                img.putpixel((x, y), col)


# ---------------------------------------------------------------- 큰바퀴 CR-002 (칸 44×24, 발 기준점 (18, 21))
ROACH_FOOT = (18, 21)
ROACH_PX = 3                                       # 컷당 3px(4컷 = 12px 한 주기)


def roach(frame=0, pose="walk", hurt=False):
    img = Image.new("RGBA", (44, 24), CLEAR)
    d = ImageDraw.Draw(img)
    legc = [C("P02"), C("P16")]
    # 다리: 삼각 보행 두 묶음이 번갈아 디딘다. 디딘 다리는 컷마다 정확히 -3px(세계에서 고정).
    for far in (1, 0):
        y0 = 14 - far * 2
        for i, bx in enumerate((11, 17, 23)):
            grp = (i + far) % 2
            ph = (frame + grp * 2) % 4 if pose == "walk" else 0
            u = [3, 0, -1, 2][ph] if pose == "walk" else 0               # 디딤 0→1: -3px, 띄움 2·3: 앞으로
            lift = 0 if ph in (0, 1) else 1
            reach = (-6, 0, 6)[i]
            fx, fy = bx + reach + u, 20 - far * 3 - lift
            kx, ky = bx + reach // 2 + u // 2, y0 + 2 - lift
            d.line([bx, y0, kx, ky], fill=legc[far])
            d.line([kx, ky, fx, fy], fill=legc[far])
            d.point((fx + (1 if reach >= 0 else -1), fy), fill=legc[far])
    bob = 1 if pose == "walk" and frame % 2 else 0

    def wings(nx, ny, col):
        if -0.05 < ny < 0.12 and nx < 0.55:
            return SHELL[0]                                              # 날개 갈라진 줄
        if ny < -0.45 and -0.6 < nx < 0.2 and int((nx + 2) * 9 + (ny + 2) * 7) % 5:
            return SHELL[4]                                              # 윤기
        return None
    body = Image.new("RGBA", (44, 24), CLEAR)
    _ellipse(body, 17.5, 11.5 - bob, 12.5, 6.0, SHELL[:4], extra=wings)
    bd = ImageDraw.Draw(body)
    bd.ellipse([26, 6 - bob, 33, 14 - bob], fill=SHELL[1])                 # 앞가슴 방패
    bd.arc([26, 6 - bob, 33, 14 - bob], 200, 330, fill=SHELL[3])
    bd.ellipse([31, 9 - bob, 35, 13 - bob], fill=C("P02"))                 # 머리
    bd.point((33, 10 - bob), fill=C("P54") if hurt else C("P08"))
    img.alpha_composite(body)
    img = outline(img)
    d = ImageDraw.Draw(img)
    t = frame % 3
    for k, pts in enumerate((((35, 9 - bob), (38, 5), (41, 3 + t), (43, 5 + t)), ((35, 11 - bob), (39, 9), (42, 10 - t // 2), (43, 13 - t)))):
        d.line(pts, fill=SHELL[0] if k else C("P01"))                     # 더듬이: 먹선 없이 가늘게
    if hurt:
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                if px[x, y][3] and px[x, y] != INK:
                    px[x, y] = C("P09")
    return img


def ichor(seed, w=28, h=14):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    cols = [C("P29"), C("P30"), C("P31")]
    blobs = [(w / 2, h / 2, w * 0.2, h * 0.25)] + [(rnd.uniform(4, w - 4), rnd.uniform(2, h - 2), rnd.uniform(1.2, 2.4), rnd.uniform(1, 1.8)) for _ in range(6)]
    for y in range(h):
        for x in range(w):
            v = max(1 - ((x + .5 - bx) / rx) ** 2 - ((y + .5 - by) / ry) ** 2 for bx, by, rx, ry in blobs)
            if v > 0:
                px[x, y] = cols[2] if v > 0.6 else cols[1] if v > 0.25 else cols[0]
    return img


def roach_death():
    """뒤집혀 버둥 → 납작 → 점액만 남음(5컷)."""
    out = []
    base = roach(0, "idle")
    flip = base.transpose(Image.FLIP_TOP_BOTTOM)
    for k in range(2):                                                     # 뒤집혀 다리 버둥
        f = Image.new("RGBA", (44, 24), CLEAR)
        f.alpha_composite(flip.crop((0, 2, 44, 24)), (0, 2 + k))
        out.append(f)
    for k in range(2):                                                     # 납작
        sq = base.resize((44, max(4, 24 - 8 * (k + 1))), Image.NEAREST)
        f = Image.new("RGBA", (44, 24), CLEAR)
        f.alpha_composite(ichor(3 + k), (6, 10))
        f.alpha_composite(sq, (0, 24 - sq.height - 2))
        out.append(f)
    f = Image.new("RGBA", (44, 24), CLEAR)
    f.alpha_composite(ichor(9, 32, 14), (4, 9))
    out.append(f)
    return out


def roach_sheet():
    """시트 프레임 목록과 메타(art_import가 쓴다)."""
    frames = [roach(0, "idle")] + [roach(f) for f in range(4)] + roach_death()
    meta = {"frame": [44, 24], "foot": list(ROACH_FOOT), "rows": ["E"], "mirror": {"W": "E"}, "style": "isaac",
            "motions": {"idle": {"start": 0, "count": 1}, "walk": {"start": 1, "count": 4, "px_per_frame": ROACH_PX, "drive": "distance"},
                        "death": {"start": 5, "count": 5}}}
    return frames, meta


def footlock_report():
    """디딘 다리 끝의 세계 x: 그림이 컷마다 3px 앞으로 갈 때 디딘 동안 그대로인가."""
    worst = 0
    for i in range(3):
        for far in (0, 1):
            grp = (i + far) % 2
            pts = []
            for f in range(4):
                ph = (f + grp * 2) % 4
                if ph in (0, 1):
                    pts.append(f * ROACH_PX + [3, 0, -1, 2][ph])
            for a, b in zip(pts, pts[1:]):
                worst = max(worst, abs(a - b)) if abs(a - b) < 6 else worst
    return worst


if __name__ == "__main__":
    out = sys.argv[1]
    fr, _ = roach_sheet()
    sheet = Image.new("RGBA", (46 * len(fr), 26), C("P19"))
    for i, f in enumerate(fr):
        sheet.alpha_composite(f, (i * 46 + 1, 1))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
    print("roach footlock worst", footlock_report())
