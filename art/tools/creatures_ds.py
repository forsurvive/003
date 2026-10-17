"""1-D3 독산 육가공 단지 크리처(SD-14 §3.1 · §4.1, 아이작풍 옆 3/4 · E만, W는 반전).
- 굴쥐 CR-096: 사족 리그(chibi_creatures QUAD 'mole') + 땅속 전용 컷 — 흙 둔덕(이동) · 들썩임(예비 동작 1.0초) · 머리 내밀기 · 파고들기 · 미끼 먹기.
- 알집바퀴 CR-004: 큰바퀴보다 한 치수 반 큰 번식 개체. 배 끝에 부푼 알집(맥동) · 부화 직전 갈라짐 · 알집이 떠내려간 맨몸 판(따로 시트).
- 언 왕쥐(소품용): 냉기에 굳은 왕쥐 — 서리 덮인 조각상 · 깨진 판.
"""
import os, sys, math, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from chibi import C, CLEAR, INK, L, outline, ramp, shade
import chibi_creatures as CC

EARTH = ramp(["P16", "P17", "P18", "P19", "P20"])


# ---------------------------------------------------------------- 굴쥐 땅속 컷(칸 44×24, 발 기준점 (20, 21) — 서 있는 그림과 같은 자리)
def _hump(d, cx, cy, rx, ry, rnd, cracks=0):
    """흙 둔덕: 아래 그늘 · 면 셋 · 흙덩이 · 갈라진 금."""
    d.ellipse([cx - rx - 1, cy - ry + 2, cx + rx + 1, cy + ry + 1], fill=C("P16"))          # 바닥 그늘
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=EARTH[1])
    d.ellipse([cx - rx + 2, cy - ry, cx + rx - 3, cy + ry - 2], fill=EARTH[2])
    d.ellipse([cx - rx // 2 - 1, cy - ry, cx + rx // 3, cy - ry + 2], fill=EARTH[3])        # 윗면 빛
    for _ in range(5):                                                                         # 흙 알갱이
        x, y = cx + rnd.randint(-rx + 1, rx - 1), cy + rnd.randint(-ry + 1, ry - 1)
        d.point((x, y), fill=EARTH[rnd.choice((0, 3, 4))])
    for k in range(cracks):                                                                    # 갈라진 금(먹선)
        x0 = cx - rx // 2 + k * (rx // max(1, cracks))
        d.line([x0, cy - ry + 1, x0 + 1, cy, x0 - 1, cy + ry - 1], fill=INK)


def mole_mound(frame):
    """땅속 이동: 흙 둔덕이 들썩이며 간다(2컷 — 덩이 자리가 엇갈린다). 몸은 보이지 않는다."""
    img = Image.new("RGBA", (44, 24), CLEAR)
    d = ImageDraw.Draw(img)
    rnd = random.Random(31 + frame)
    _hump(d, 20 + frame, 19, 8, 3, rnd)
    for x, y in ((11 - frame, 20), (29 + frame, 20), (14, 18 + frame)):                       # 뒤로 흩어진 흙덩이
        d.rectangle([x, y, x + 1, y + 1], fill=EARTH[1]); d.point((x, y), fill=EARTH[3])
    return outline(img)


def mole_heave(frame):
    """흙 들썩임(예비 동작 1.0초 — SD-14 CR-096): 둔덕이 부풀고 금이 가고 흙덩이가 튄다(3컷 반복). 마지막 컷에 발톱 끝이 비친다."""
    img = Image.new("RGBA", (44, 24), CLEAR)
    d = ImageDraw.Draw(img)
    rnd = random.Random(57 + frame)
    rise = (1, 2, 3)[frame]
    _hump(d, 20, 20 - rise, 9 + frame // 2, 3 + rise // 2, rnd, cracks=1 + frame)
    out = outline(img)
    d = ImageDraw.Draw(out)
    for k, (x, y) in enumerate(((13, 13), (26, 12), (19, 9), (31, 15), (9, 16))[:2 + frame]):  # 튀는 흙덩이(먹선 밖 — 공중)
        yy = y - frame * 2 + (k % 2)
        d.rectangle([x, yy, x + 1, yy + 1], fill=EARTH[2]); d.point((x + 1, yy + 1), fill=EARTH[0])
    if frame == 2:
        for x in (21, 23):                                                                     # 흙 사이로 비치는 흰 발톱
            d.point((x, 15), fill=C("P08")); d.point((x, 16), fill=C("P07"))
    return out


def _hole(d, cx, cy):
    d.ellipse([cx - 8, cy - 2, cx + 8, cy + 3], fill=EARTH[2])                                 # 흙 테
    d.ellipse([cx - 6, cy - 1, cx + 6, cy + 2], fill=C("P01"))                                  # 구멍(검게)


def _mole_front(img, cx, base, lift, open_mouth=False):
    """구멍 위로 솟은 굴쥐 앞몸(정면에 가까운 옆 3/4): 어깨 · 머리 · 테를 움켜쥔 앞발 발톱 둘. base = 흙 테 줄(그 아래는 그리지 않는다)."""
    q = CC.QUAD["mole"]
    fur = ramp(q["fur"])
    sk = ramp(q["skin"])
    lay = Image.new("RGBA", img.size, CLEAR)
    CC._ellipse(lay, cx - 1, base - lift + 4, 7.0, 5.0, fur)                                   # 어깨(테 아래로 잘린다)
    hy = base - lift - 2
    CC._ellipse(lay, cx + 3, hy, 5.5, 4.6, fur)                                                 # 머리
    d = ImageDraw.Draw(lay)
    d.arc([cx - 3, hy - 5, cx + 3, hy + 6], 100, 260, fill=fur[0])                              # 목 주름
    d.ellipse([cx + 5, hy - 1, cx + 11, hy + 4], fill=fur[3])                                   # 주둥이
    d.rectangle([cx + 9, hy, cx + 11, hy + 1], fill=sk[1]); d.point((cx + 11, hy), fill=sk[2])
    d.line([cx + 3, hy - 2, cx + 5, hy - 2], fill=C("P01"))
    d.ellipse([cx - 1, hy - 4, cx + 1, hy - 2], fill=fur[0])
    px = lay.load()
    for y in range(base, img.height):
        for x in range(img.width):
            px[x, y] = CLEAR
    lay = outline(lay)
    d = ImageDraw.Draw(lay)
    tx = cx + 8                                                                                 # 앞니(벌리면 위아래로 갈라진다)
    d.line([tx, hy + 4, tx, hy + 5 + (1 if open_mouth else 0)], fill=C("P49"))
    if open_mouth:
        d.line([tx, hy + 7, tx, hy + 8], fill=C("P48"))
    for k, x in enumerate((cx - 6, cx + 4)):                                                    # 테를 움켜쥔 앞발 + 흰 발톱 셋
        d.rectangle([x, base - 2, x + 3, base - 1], fill=fur[1 + k])
        for j in range(3):
            d.point((x + j + 1, base), fill=C("P08")); d.point((x + j + 1, base - 1) if j == 1 else (x + j, base + 1), fill=C("P07"))
    img.alpha_composite(lay)


def mole_emerge(frame):
    """머리만 내밀기(SD-14 '땅속에서 머리만 내민 전용 프레임'): 구멍 테 위로 머리 · 어깨 · 앞발 발톱(2컷 — 한 단 더 솟고 입을 벌린다)."""
    img = Image.new("RGBA", (44, 24), CLEAR)
    d = ImageDraw.Draw(img)
    _hole(d, 20, 19)
    _mole_front(img, 19, 19, 3 + frame * 2, open_mouth=frame == 1)
    d = ImageDraw.Draw(img)
    d.line([12, 21, 28, 21], fill=EARTH[3])                                                     # 앞 테(흙이 몸 앞을 덮는다)
    d.line([11, 22, 29, 22], fill=EARTH[1])
    for x, y in ((9, 17), (31, 18), (14, 13 - frame), (27, 12 - frame)):                        # 튄 흙
        d.point((x, y), fill=EARTH[2])
    return img


def mole_dig(frame):
    """다시 파고들기(2컷): 머리부터 구멍으로 — 엉덩이 · 짧은 꼬리 · 흙 차는 뒷발 → 흙이 덮인 둔덕."""
    if frame == 1:
        img = Image.new("RGBA", (44, 24), CLEAR)
        d = ImageDraw.Draw(img)
        _hump(d, 20, 19, 7, 3, random.Random(77), cracks=1)
        img = outline(img)
        d = ImageDraw.Draw(img)
        for x, y in ((12, 13), (27, 12), (31, 16)):
            d.rectangle([x, y, x + 1, y + 1], fill=EARTH[2])
        return img
    q = CC.QUAD["mole"]
    fur = ramp(q["fur"])
    sk = ramp(q["skin"])
    img = Image.new("RGBA", (44, 24), CLEAR)
    d = ImageDraw.Draw(img)
    _hole(d, 21, 19)
    lay = Image.new("RGBA", img.size, CLEAR)
    CC._ellipse(lay, 18, 15, 6.5, 5.0, fur)                                                      # 위로 들린 엉덩이(머리는 땅속)
    px = lay.load()
    for y in range(19, 24):
        for x in range(44):
            px[x, y] = CLEAR
    lay = outline(lay)
    d2 = ImageDraw.Draw(lay)
    d2.line([12, 11, 9, 8], fill=sk[1], width=2); d2.point((8, 7), fill=sk[0])                  # 짧은 꼬리(위로)
    for x, y in ((11, 16), (24, 14)):                                                            # 흙을 차는 뒷발
        d2.line([x, y, x + (-3 if x < 18 else 3), y + 2], fill=fur[1], width=2)
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    d.line([12, 21, 28, 21], fill=EARTH[3])
    for x, y in ((7, 15), (30, 11), (33, 14), (5, 18)):                                         # 뒤로 튀는 흙
        d.rectangle([x, y, x + 1, y + 1], fill=EARTH[2]); d.point((x, y), fill=EARTH[4])
    return img


def mole_eat(frame):
    """미끼 먹기(1-D3 '썩은 고기'): 고개를 숙여 갉는다 — 머리 쪽만 1px 내려가고 앞니가 움직인다(2컷)."""
    img = CC.quad("mole", 0, "idle")
    if frame == 1:
        head = img.crop((24, 0, 44, 24))
        px = img.load()
        for y in range(24):
            for x in range(24, 44):
                px[x, y] = CLEAR
        img.alpha_composite(head, (24, 1))
    return img


def mole_sheet():
    """굴쥐 시트: 사족 시트(idle 1 · walk 4 · death 3) 뒤에 mound 2 · heave 3 · emerge 2 · dig 2 · eat 2."""
    frames, meta = CC.quad_sheet("mole")
    mo = meta["motions"]
    for name, fn, n in (("mound", mole_mound, 2), ("heave", mole_heave, 3), ("emerge", mole_emerge, 2), ("dig", mole_dig, 2), ("eat", mole_eat, 2)):
        mo[name] = {"start": len(frames), "count": n}
        frames += [fn(i) for i in range(n)]
    return frames, meta


# ---------------------------------------------------------------- 알집바퀴 CR-004 (칸 60×32, 발 기준점 (26, 29))
EGG_FOOT = (26, 29)
EGG_PX = 2
OOTH = ramp(["P22", "P23", "P24", "P25", "P26"])          # 알집: 적갈색 가죽 주머니


def eggroach(frame=0, pose="walk", pulse=0, crack=0, bare=False, hurt=False):
    img = Image.new("RGBA", (60, 32), CLEAR)
    d = ImageDraw.Draw(img)
    legc = [C("P02"), C("P16")]
    for far in (1, 0):                                                    # 다리 세 쌍(삼각 보행 — 디딘 다리는 컷마다 -2px)
        y0 = 19 - far * 2
        for i, bx in enumerate((18, 26, 34)):
            grp = (i + far) % 2
            ph = (frame + grp * 2) % 4 if pose == "walk" else 0
            u = [2, 0, -1, 1][ph] if pose == "walk" else 0
            lift = 0 if ph in (0, 1) else 1
            reach = (-8, 0, 8)[i]
            fx, fy = bx + reach + u, 28 - far * 3 - lift
            kx, ky = bx + reach // 2 + u // 2, y0 + 3 - lift
            d.line([bx, y0, kx, ky], fill=legc[far], width=2 if not far else 1)
            d.line([kx, ky, fx, fy], fill=legc[far])
            d.point((fx + (1 if reach >= 0 else -1), fy), fill=legc[far])
    bob = 1 if pose == "walk" and frame % 2 else 0
    body = Image.new("RGBA", img.size, CLEAR)

    def wings(nx, ny, col):
        if -0.04 < ny < 0.1 and nx < 0.5:
            return CC.SHELL[0]
        if ny < -0.5 and -0.5 < nx < 0.2 and int((nx + 2) * 9 + (ny + 2) * 7) % 5:
            return CC.SHELL[4]
        return None
    CC._ellipse(body, 27.5, 16.5 - bob, 16.0, 7.5, CC.SHELL[:4], extra=wings)              # 날개 덮인 몸
    belly = ramp(["P18", "P19", "P20", "P21"])
    CC._ellipse(body, 22.5, 20.5 - bob, 11.0, 4.0, belly)                                    # 부푼 배(마디 줄)
    bd = ImageDraw.Draw(body)
    for k in range(4):
        bd.arc([14 + k * 4, 17 - bob, 20 + k * 4, 25 - bob], 20, 160, fill=belly[0])
    bd.ellipse([39, 10 - bob, 48, 20 - bob], fill=CC.SHELL[1])                                # 앞가슴 방패
    bd.arc([39, 10 - bob, 48, 20 - bob], 200, 330, fill=CC.SHELL[3])
    bd.ellipse([45, 13 - bob, 51, 19 - bob], fill=C("P02"))                                   # 머리
    bd.point((48, 14 - bob), fill=C("P54") if hurt else C("P08"))
    if not bare:                                                                              # 알집(배 끝에 물린 가죽 주머니 — 맥동하면 1px 부풀고 밝아진다)
        oc = OOTH[1:] if pulse else OOTH[:4]
        CC._ellipse(body, 9.5, 19.5 - bob, 6.0 + pulse * 0.6, 4.2 + pulse * 0.5, oc)
        for k in range(5):                                                                    # 등의 이음 톱니(알 칸)
            bd.point((6 + k * 2, 15 - bob - pulse), fill=OOTH[4] if k % 2 else OOTH[0])
        bd.line([5, 19 - bob, 14, 19 - bob], fill=OOTH[0])
        if crack:                                                                             # 갈라짐: 솔기가 벌어지고 흰 애벌레가 비친다
            bd.line([5, 18 - bob, 14, 17 - bob], fill=C("P01"))
            for x in (7, 10, 12):
                bd.point((x, 17 - bob), fill=C("P08"))
            if crack > 1:
                bd.point((9, 16 - bob), fill=C("P07")); bd.point((13, 16 - bob), fill=C("P08"))
    img.alpha_composite(body)
    img = outline(img)
    d = ImageDraw.Draw(img)
    t = frame % 3
    for k, pts in enumerate((((51, 14 - bob), (54, 9), (57, 6 + t), (59, 9 + t)), ((51, 16 - bob), (55, 14), (58, 15 - t // 2), (59, 18 - t)))):
        d.line(pts, fill=CC.SHELL[0] if k else C("P01"))
    if crack and not bare:                                                                    # 깨지는 알 껍질 조각(먹선 밖)
        d.point((4, 13 - bob), fill=OOTH[3]); d.point((15, 12 - bob), fill=OOTH[2])
    if hurt:
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                if px[x, y][3] and px[x, y] != INK:
                    px[x, y] = C("P09")
    return img


def eggroach_death(bare=False):
    out = []
    base = eggroach(0, "idle", bare=bare)
    flip = base.transpose(Image.FLIP_TOP_BOTTOM)
    for k in range(2):
        f = Image.new("RGBA", (60, 32), CLEAR)
        f.alpha_composite(flip.crop((0, 3, 60, 32)), (0, 3 + k))
        out.append(f)
    for k in range(2):
        sq = base.resize((60, max(6, 32 - 9 * (k + 1))), Image.NEAREST)
        f = Image.new("RGBA", (60, 32), CLEAR)
        f.alpha_composite(CC.ichor(41 + k, 40, 16), (8, 14))
        f.alpha_composite(sq, (0, 32 - sq.height - 2))
        out.append(f)
    return out


def eggroach_sheet(bare=False):
    """알집바퀴 시트: idle 2(맥동) · walk 4(컷당 2px) · crack 2(부화 직전 '딸깍') · death 4. bare = 알집이 떠내려간 맨몸(맥동 · 갈라짐 없음)."""
    idle = [eggroach(0, "idle", pulse=p, bare=bare) for p in (0, 1)]
    walk = [eggroach(f, bare=bare) for f in range(4)]
    crack = [eggroach(0, "idle", pulse=1, crack=c, bare=bare) for c in (1, 2)]
    frames = idle + walk + crack + eggroach_death(bare)
    meta = {"frame": [60, 32], "foot": list(EGG_FOOT), "rows": ["E"], "mirror": {"W": "E"}, "style": "isaac",
            "motions": {"idle": {"start": 0, "count": 1}, "pulse": {"start": 0, "count": 2},
                        "walk": {"start": 2, "count": 4, "px_per_frame": EGG_PX, "drive": "distance"},
                        "crack": {"start": 6, "count": 2}, "death": {"start": 8, "count": 4}}}
    return frames, meta


# ---------------------------------------------------------------- 언 왕쥐(소품 — 냉기에 굳은 조각상 · 깨진 판)
def frozen_ratking(broken=False):
    base = CC.quad("ratking", 1, "walk")
    w, h = base.size
    img = Image.new("RGBA", (w, h), CLEAR)
    src, dst = base.load(), img.load()
    ice = ramp(["P33", "P34", "P35", "P36", "P08"])
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if not a:
                continue
            if (r, g, b, a) == INK:
                dst[x, y] = C("P33")
                continue
            lum = (r * 3 + g * 6 + b) / 2550.0
            dst[x, y] = ice[min(4, int(lum * 4.2) + (1 if (x * 7 + y * 3) % 11 == 0 else 0))]
    d = ImageDraw.Draw(img)
    rnd = random.Random(5)
    for _ in range(14):                                                                       # 서리 반짝임 · 고드름
        x, y = rnd.randint(8, w - 8), rnd.randint(6, h - 8)
        if dst[x, y][3]:
            d.point((x, y), fill=C("P08"))
    for x in (20, 26, 33):
        d.line([x, 22, x, 25], fill=ice[3]); d.point((x, 26), fill=ice[4])
    if broken:                                                                                 # 깨진 판: 머리 · 몸이 갈라져 조각이 흩어진다
        px = img.load()
        for y in range(h):
            for x in range(w):
                if abs(x - 34 - (y - 16) * 0.4) < 1.0 and px[x, y][3]:
                    px[x, y] = CLEAR
        front = img.crop((35, 0, w, h))
        for y in range(h):
            for x in range(35, w):
                px[x, y] = CLEAR
        img.alpha_composite(front, (37, 3))
        for x, y in ((14, 28), (42, 29), (50, 27), (28, 30)):
            d.polygon([(x, y), (x + 2, y - 1), (x + 3, y + 1)], fill=ice[2])
    return img


if __name__ == "__main__":
    out = sys.argv[1]
    rows = [mole_sheet()[0], eggroach_sheet()[0], eggroach_sheet(True)[0]]
    W = max(len(r) for r in rows) * 62
    sheet = Image.new("RGBA", (W, 34 * 3 + 34), C("P19"))
    for ri, r in enumerate(rows):
        for i, f in enumerate(r):
            sheet.alpha_composite(f, (i * 62 + 1, ri * 34 + 1))
    sheet.alpha_composite(frozen_ratking(), (1, 103)); sheet.alpha_composite(frozen_ratking(True), (70, 103))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)
