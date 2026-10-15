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


# ---------------------------------------------------------------- 네발짐승(변이 들개·변이 시궁쥐): 큰 머리 + 작은 몸 + 짧은 다리
QUAD = {
    "dog": dict(w=44, h=32, foot=(20, 29), px=4, body=(19, 18, 10, 6.5), head=(32, 13, 7.5, 6.5), leg=5, fur=["P17", "P18", "P19", "P20"],
                skin=["P39", "P40", "P41"], eye="P54", tail="up", ears=True, mange=True),
    "jindo": dict(w=44, h=32, foot=(20, 29), px=4, body=(19, 18, 10, 6.5), head=(32, 12, 7.5, 6.5), leg=5, fur=["P06", "P07", "P08", "P09"],
                  skin=["P39", "P40", "P41"], eye="P01", tail="curl", ears=True, mange=False),
    # 경비견 CR-107(SD-14 §6, 새벽인력·약탈자 사육견): 검정·황갈 셰퍼드형, 선 귀, 검은 조끼 + 주황 띠(새벽인력 PF-05)
    "guard": dict(w=44, h=32, foot=(20, 29), px=4, body=(19, 18, 10, 6.5), head=(32, 13, 7.5, 6.5), leg=5, fur=["P01", "P02", "P03", "P18"],
                  skin=["P39", "P40", "P41"], eye="P49", tail="up", ears=True, mange=False, vest=True),
    "rat": dict(w=40, h=22, foot=(18, 19), px=2, body=(17, 13, 9, 5), head=(27, 12, 5, 4.5), leg=3, fur=["P03", "P04", "P05", "P06"],
                skin=["P40", "P41", "P42"], eye="P54", tail="long", ears=True, mange=False),
}


def quad(kind, frame=0, pose="walk"):
    """4컷 종종걸음(대각 다리 짝이 번갈아 2컷씩 딛는다, 디딘 발은 컷마다 -px = 세계에서 고정)."""
    q = QUAD[kind]
    img = Image.new("RGBA", (q["w"], q["h"]), CLEAR)
    d = ImageDraw.Draw(img)
    fur = ramp(q["fur"])
    p = q["px"]
    u0 = (p + 1) // 2
    table = [(u0, 0), (u0 - p, 0), (u0 - p, 2), (0, 2)]               # 디딤 0·1, 띄움 2·3
    bx, by, brx, bry = q["body"]
    bob = 1 if pose == "walk" and frame % 2 else 0
    hips = {"front": bx + brx * 0.55, "back": bx - brx * 0.6}
    for far in (1, 0):
        for end in ("back", "front"):
            pair = (0 if (end == "front") == (far == 0) else 2)            # 대각 짝
            ph = (frame + pair) % 4 if pose == "walk" else 0
            u, lift = table[ph] if pose == "walk" else (0, 0)
            hx = round(hips[end]) - far
            fx, fy = hx + u, q["foot"][1] - far * 2 - lift
            col = fur[0] if far else fur[1]
            d.line([hx, by + 2 - bob, fx, fy - 1], fill=col, width=2)
            d.point((fx + 1, fy - 1), fill=C("P02"))
    body = Image.new("RGBA", img.size, CLEAR)

    def mange(nx, ny, col):
        if q["mange"] and math.sin(nx * 7 + 2) * math.sin(ny * 6 - 1) > 0.6:
            return ramp(q["skin"])[1]
        if q["mange"] and ny > 0.1 and abs((nx * 6) % 1 - 0.5) < 0.12:
            return fur[0]                                                  # 드러난 갈비
        return None
    _ellipse(body, bx, by - bob, brx, bry, fur, extra=mange)
    if q.get("vest"):                                                      # 검은 조끼(가슴·등) + 주황 띠 + 버클
        vb = ImageDraw.Draw(body)
        x0, x1 = round(bx - brx * 0.45), round(bx + brx * 0.65)
        y0, y1 = round(by - bob - bry + 1), round(by - bob + bry - 2)
        vb.rectangle([x0, y0, x1, y1], fill=C("P02"))
        vb.line([x0, y0, x1, y0], fill=C("P04"))
        vb.rectangle([x0, (y0 + y1) // 2, x1, (y0 + y1) // 2 + 1], fill=C("P26"))
        vb.point((x1 - 2, y0 + 2), fill=C("P07"))
    hxc, hyc, hrx, hry = q["head"]
    _ellipse(body, hxc, hyc - bob, hrx, hry, fur)
    bd = ImageDraw.Draw(body)
    hyb = round(hyc - bob)
    if kind == "jindo":                                                    # 진돗개(백구): 쫑긋 선 세모 귀 + 짧은 주둥이 + 검은 코·눈
        ex = round(hxc - hrx * 0.25)
        bd.polygon([(ex - 3, hyb - 4), (ex, hyb - 11), (ex + 3, hyb - 4)], fill=fur[2])
        bd.polygon([(ex - 1, hyb - 5), (ex, hyb - 9), (ex + 1, hyb - 5)], fill=ramp(q["skin"])[1])
        sx = round(hxc + hrx - 2)
        bd.ellipse([sx - 1, hyb - 1, sx + 5, hyb + 4], fill=fur[3])
        bd.point((sx + 5, hyb), fill=C("P01")); bd.point((sx + 4, hyb), fill=C("P01"))
        bd.line([sx + 1, hyb + 3, sx + 4, hyb + 3], fill=fur[1])
        bd.point((round(hxc + 1), hyb - 2), fill=C(q["eye"]))
        bd.point((round(hxc + 1), hyb - 3), fill=C(q["eye"]))
    elif kind == "guard":                                                  # 셰퍼드형: 선 귀(검정) · 황갈 주둥이 · 목줄 고리
        ex = round(hxc - hrx * 0.3)
        bd.polygon([(ex - 3, hyb - 4), (ex - 1, hyb - 12), (ex + 2, hyb - 4)], fill=fur[0])
        bd.polygon([(ex - 2, hyb - 5), (ex - 1, hyb - 9), (ex + 1, hyb - 5)], fill=ramp(q["skin"])[0])
        sx = round(hxc + hrx - 2)
        bd.ellipse([sx - 1, hyb - 1, sx + 6, hyb + 4], fill=fur[3])
        bd.line([sx, hyb + 3, sx + 5, hyb + 3], fill=fur[1])
        bd.point((sx + 6, hyb), fill=C("P01")); bd.point((sx + 5, hyb), fill=C("P01"))
        bd.point((sx + 3, hyb + 4), fill=C("P09"))
        bd.point((round(hxc + 1), hyb - 2), fill=C(q["eye"]))
        bd.line([round(hxc - hrx + 1), hyb + 3, round(hxc - hrx + 3), hyb + 6], fill=C("P26"), width=2)   # 목줄
        bd.point((round(hxc - hrx + 2), hyb + 6), fill=C("P07"))
    elif kind == "dog":
        ex = round(hxc - hrx * 0.45)                                       # 늘어진 귀
        bd.polygon([(ex - 2, hyb - 5), (ex + 3, hyb - 6), (ex - 3, hyb + 1)], fill=fur[0])
        sx = round(hxc + hrx - 2)                                          # 긴 주둥이 + 검은 코 + 이빨
        bd.ellipse([sx - 1, hyb - 1, sx + 6, hyb + 4], fill=fur[2])
        bd.line([sx, hyb + 3, sx + 5, hyb + 3], fill=fur[0])
        bd.point((sx + 6, hyb), fill=C("P01")); bd.point((sx + 5, hyb), fill=C("P01"))
        bd.point((sx + 2, hyb + 4), fill=C("P09")); bd.point((sx + 4, hyb + 4), fill=C("P09"))
        bd.point((round(hxc + 1), hyb - 2), fill=C(q["eye"]))
    else:
        ex = round(hxc - 1)                                                # 동그란 귀(안쪽 분홍)
        bd.ellipse([ex - 2, hyb - 7, ex + 2, hyb - 3], fill=fur[2])
        bd.point((ex, hyb - 5), fill=ramp(q["skin"])[1])
        sx = round(hxc + hrx - 1)
        bd.ellipse([sx - 1, hyb - 1, sx + 3, hyb + 2], fill=fur[2])
        bd.point((sx + 3, hyb), fill=ramp(q["skin"])[2])
        bd.point((round(hxc + 1), hyb - 1), fill=C(q["eye"]))
    img.alpha_composite(body)
    img = outline(img)
    d = ImageDraw.Draw(img)
    tx = round(bx - brx)
    if kind == "rat":                                                     # 수염(먹선 밖)
        sx2, sy2 = round(q["head"][0] + q["head"][2] + 2), round(q["head"][1] - bob)
        d.line([sx2, sy2, sx2 + 3, sy2 - 1], fill=C("P07")); d.line([sx2, sy2 + 1, sx2 + 3, sy2 + 2], fill=C("P07"))
    if q["tail"] == "curl":                                               # 진돗개 말린 꼬리(등 위로 둥글게)
        cx0, cy0 = tx + 1, by - 7 - bob
        d.ellipse([cx0 - 5, cy0 - 5, cx0 + 3, cy0 + 3], fill=C("P01"))
        d.ellipse([cx0 - 4, cy0 - 4, cx0 + 2, cy0 + 2], fill=fur[2])
        d.arc([cx0 - 3, cy0 - 3, cx0 + 1, cy0 + 1], 200, 20, fill=fur[3])
        d.point((cx0 - 1, cy0), fill=fur[1])
    elif q["tail"] == "up":
        d.line([(tx, by - 2 - bob), (tx - 3, by - 6 - bob), (tx - 4, by - 9 - bob + (frame % 2))], fill=fur[0], width=2)
    else:
        pts = [(tx, by + 1 - bob), (tx - 5, by + 3), (tx - 10, by + 2 + (frame % 2)), (tx - 14, by + 4)]
        d.line(pts, fill=ramp(q["skin"])[1])
    return img


def quad_lying(kind):
    """쓰러진(누운) 네발짐승: 옆으로 누운 몸 + 뻗은 다리 + 감은 눈. 사망·기절 마지막 컷."""
    q = QUAD[kind]
    img = Image.new("RGBA", (q["w"], q["h"]), CLEAR)
    fur = ramp(q["fur"])
    bx, by, brx, bry = q["body"]
    body = Image.new("RGBA", img.size, CLEAR)
    _ellipse(body, bx + 1, by + 6, brx + 2, bry - 1.5, fur)
    hxc, hyc, hrx, hry = q["head"]
    _ellipse(body, hxc + 2, by + 6, hrx, hry - 1, fur)
    bd = ImageDraw.Draw(body)
    for x in (bx - 6, bx - 2, bx + 4, bx + 8):                            # 뻗은 다리
        bd.line([x, by + 9, x + 4, by + 11], fill=fur[1], width=2)
    bd.line([round(hxc), by + 4, round(hxc) + 2, by + 4], fill=C("P01"))  # 감은 눈
    img.alpha_composite(body)
    return outline(img)


def quad_sheet(kind):
    """네발짐승 시트(roach_sheet와 같은 형식): 옆(E)만, W는 뒤집기. idle 1 · walk 4 · run 4(같은 컷, 빠르게) · death 3."""
    walk = [quad(kind, f) for f in range(4)]
    idle = [quad(kind, 0, "idle")]
    lie = quad_lying(kind)
    mid = Image.new("RGBA", lie.size, CLEAR)                             # 무너지는 중간 컷: 서 있는 몸을 2px 내린 모습
    mid.alpha_composite(walk[1], (0, 2))
    frames = idle + walk + [mid, lie, lie]
    q = QUAD[kind]
    meta = {"frame": [q["w"], q["h"]], "foot": list(q["foot"]), "rows": ["E"], "mirror": {"W": "E"}, "style": "isaac",
            "motions": {"idle": {"start": 0, "count": 1}, "walk": {"start": 1, "count": 4, "px_per_frame": q["px"], "drive": "distance"},
                        "death": {"start": 5, "count": 3}}}
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


if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[2] == "quad":
    out = sys.argv[1]
    sheet = Image.new("RGBA", (46 * 8, 34 * 2), C("P19"))
    for r, k in enumerate(("dog", "rat")):
        for f in range(4):
            sheet.alpha_composite(quad(k, f), (f * 46, r * 34))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
    sys.exit()

if __name__ == "__main__":
    out = sys.argv[1]
    fr, _ = roach_sheet()
    sheet = Image.new("RGBA", (46 * len(fr), 26), C("P19"))
    for i, f in enumerate(fr):
        sheet.alpha_composite(f, (i * 46 + 1, 1))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
    print("roach footlock worst", footlock_report())
