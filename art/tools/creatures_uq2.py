"""1-12h h3 영등포 지하상가 외곽 배수구 크리처(SD-14 §3.1 · §10.2, 아이작풍 옆 3/4 · E만, W는 반전).
- 배수구 어미 CR-501: 알집바퀴(CR-004)의 두 치수 큰 군락 어미. 등에 알집 무더기(맥동) · 부화 직전 갈라짐 · 긴 더듬이.
  천장에 붙어 있는 동안은 보이지 않는다(물속 구울과 같은 잠복) — 떨어지면 이 시트로 선다.
- 잔바퀴 떼 CR-001: 64×64 칸 안에 작은 바퀴 30~40이 꿈틀대는 무리(한 몸). 걸음마다 무리 모양이 바뀐다.
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from chibi import C, CLEAR, INK, outline, ramp
import chibi_creatures as CC

OOTH = ramp(["P22", "P23", "P24", "P25", "P26"])          # 알집: 적갈색 가죽 주머니(알집바퀴와 같은 결)
MOM_FOOT = (44, 41)
MOM_PX = 2
SWARM_FOOT = (32, 50)


# ---------------------------------------------------------------- 배수구 어미 CR-501 (칸 92×44)
def drain_mother(frame=0, pose="walk", pulse=0, crack=0, hurt=False):
    img = Image.new("RGBA", (92, 44), CLEAR)
    d = ImageDraw.Draw(img)
    legc = [C("P02"), C("P16")]
    for far in (1, 0):                                                    # 다리 세 쌍(가시 돋친 마디 — 삼각 보행)
        y0 = 28 - far * 3
        for i, bx in enumerate((28, 42, 56)):
            grp = (i + far) % 2
            ph = (frame + grp * 2) % 4 if pose == "walk" else 0
            u = [3, 0, -2, 1][ph] if pose == "walk" else 0
            lift = 0 if ph in (0, 1) else 2
            reach = (-13, 0, 13)[i]
            fx, fy = bx + reach + u, 41 - far * 4 - lift
            kx, ky = bx + reach // 2 + u // 2, y0 + 5 - lift
            d.line([bx, y0, kx, ky], fill=legc[far], width=3 if not far else 2)
            d.line([kx, ky, fx, fy], fill=legc[far], width=2 if not far else 1)
            d.point((kx + (2 if reach >= 0 else -2), ky + 1), fill=legc[far])                     # 마디 가시
            d.point((fx + (1 if reach >= 0 else -1), fy), fill=legc[far])
    bob = 1 if pose == "walk" and frame % 2 else 0
    body = Image.new("RGBA", img.size, CLEAR)

    def wings(nx, ny, col):
        if -0.04 < ny < 0.08 and nx < 0.55:
            return CC.SHELL[0]                                                                    # 날개 가운데 솔기
        if ny < -0.45 and -0.6 < nx < 0.3 and int((nx + 2) * 11 + (ny + 2) * 9) % 6 == 0:
            return CC.SHELL[4]                                                                    # 날개 결 빛
        return None
    CC._ellipse(body, 44.5, 25.5 - bob, 25.0, 11.0, CC.SHELL[:4], extra=wings)               # 날개 덮인 큰 몸
    belly = ramp(["P16", "P17", "P18", "P19"])
    CC._ellipse(body, 38.5, 31.0 - bob, 18.0, 5.0, belly)                                   # 처진 배(마디 줄)
    bd = ImageDraw.Draw(body)
    for k in range(6):
        bd.arc([23 + k * 5, 27 - bob, 30 + k * 5, 36 - bob], 20, 160, fill=belly[0])
    bd.ellipse([63, 16 - bob, 77, 31 - bob], fill=CC.SHELL[1])                                 # 앞가슴 방패
    bd.arc([63, 16 - bob, 77, 31 - bob], 200, 330, fill=CC.SHELL[3])
    bd.arc([65, 19 - bob, 75, 29 - bob], 210, 300, fill=CC.SHELL[2])
    bd.ellipse([73, 21 - bob, 82, 29 - bob], fill=C("P02"))                                   # 머리
    bd.point((78, 23 - bob), fill=C("P54") if hurt else C("P08"))
    bd.point((80, 27 - bob), fill=C("P53"))                                                   # 턱
    # 등의 알집 무더기(여섯 — 맥동하면 1px 부풀고 밝아진다)
    oc = OOTH[1:] if pulse else OOTH[:4]
    pods = [(24, 15), (32, 12), (40, 11), (48, 12), (29, 19), (44, 17)]
    for k, (px_, py_) in enumerate(pods):
        rx, ry = 5.0 + pulse * 0.6 + (k % 2) * 0.5, 3.4 + pulse * 0.4
        CC._ellipse(body, px_ + 0.5, py_ + 0.5 - bob - pulse, rx, ry, oc)
        for j in range(3):
            bd.point((px_ - 3 + j * 3, py_ - 2 - bob - pulse), fill=OOTH[4] if j % 2 else OOTH[1])   # 알 칸 톱니
    bd.line([19, 21 - bob, 52, 18 - bob], fill=C("P16"))                                       # 알집이 등에 붙은 끈적한 막(그늘)
    if crack:                                                                                  # 갈라짐: 솔기가 벌어지고 흰 애벌레가 비친다
        for (px_, py_) in pods[:4 if crack == 1 else 6]:
            bd.line([px_ - 3, py_ - bob - pulse, px_ + 3, py_ - 1 - bob - pulse], fill=C("P01"))
            bd.point((px_, py_ - 1 - bob - pulse), fill=C("P08"))
            if crack > 1:
                bd.point((px_ + 2, py_ - 2 - bob - pulse), fill=C("P07"))
    img.alpha_composite(body)
    img = outline(img)
    d = ImageDraw.Draw(img)
    t = frame % 3
    for k, pts in enumerate((((81, 22 - bob), (85, 14), (88, 8 + t), (91, 12 + t)), ((82, 25 - bob), (87, 22), (90, 23 - t // 2), (91, 28 - t)))):
        d.line(pts, fill=CC.SHELL[0] if k else C("P01"))                                       # 긴 더듬이
    if hurt:
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                if px[x, y][3] and px[x, y] != INK:
                    px[x, y] = C("P09")
    return img


def drain_mother_death():
    out = []
    base = drain_mother(0, "idle")
    flip = base.transpose(Image.FLIP_TOP_BOTTOM)
    for k in range(2):
        f = Image.new("RGBA", (92, 44), CLEAR)
        f.alpha_composite(flip.crop((0, 4, 92, 44)), (0, 4 + k))
        out.append(f)
    for k in range(2):
        sq = base.resize((92, max(8, 44 - 12 * (k + 1))), Image.NEAREST)
        f = Image.new("RGBA", (92, 44), CLEAR)
        f.alpha_composite(CC.ichor(57 + k, 64, 22), (12, 20))
        f.alpha_composite(sq, (0, 44 - sq.height - 2))
        out.append(f)
    return out


def drain_mother_sheet():
    """배수구 어미 시트: idle 2(맥동) · walk 4(컷당 2px) · crack 2(부화 직전) · death 4."""
    idle = [drain_mother(0, "idle", pulse=p) for p in (0, 1)]
    walk = [drain_mother(f) for f in range(4)]
    crack = [drain_mother(0, "idle", pulse=1, crack=c) for c in (1, 2)]
    frames = idle + walk + crack + drain_mother_death()
    meta = {"frame": [92, 44], "foot": list(MOM_FOOT), "rows": ["E"], "mirror": {"W": "E"}, "style": "isaac",
            "motions": {"idle": {"start": 0, "count": 1}, "pulse": {"start": 0, "count": 2},
                        "walk": {"start": 2, "count": 4, "px_per_frame": MOM_PX, "drive": "distance"},
                        "crack": {"start": 6, "count": 2}, "death": {"start": 8, "count": 4}}}
    return frames, meta


# ---------------------------------------------------------------- 잔바퀴 떼 CR-001 (칸 64×64 — 땅에 깔린 무리)
def _tiny(d, x, y, east, col):
    """작은 바퀴 하나(4×2): 몸 · 머리 · 더듬이 한 점."""
    hx = x + 3 if east else x
    d.rectangle([x, y, x + 3, y + 1], fill=col)
    d.point((x + (1 if east else 2), y), fill=CC.SHELL[4])                                   # 날개 빛
    d.point((x + 1, y + 2), fill=INK); d.point((x + 3, y + 2), fill=INK)                       # 다리 그늘
    d.point((hx, y), fill=INK)                                                                 # 머리
    d.point((hx + (1 if east else -1), y - 1), fill=CC.SHELL[0])                               # 더듬이


def roach_swarm(frame=0, n=42, spread=1.0):
    img = Image.new("RGBA", (64, 64), CLEAR)
    d = ImageDraw.Draw(img)
    rnd = random.Random(101)
    cols = [CC.SHELL[0], CC.SHELL[1], CC.SHELL[2]]
    d.ellipse([10, 44, 54, 56], fill=(0, 0, 0, 46))                                            # 무리 그늘
    for i in range(n):
        ang = rnd.random() * 6.283
        r = (rnd.random() ** 0.6) * 20.0 * spread
        bx = 30 + r * 1.05 * (1 if ang < 3.14 else -1) * abs(__import__("math").cos(ang))
        by = 48 + r * 0.42 * __import__("math").sin(ang)
        jit = random.Random(i * 7 + frame * 13)
        x = int(bx + (frame * 2 if spread <= 1.0 else 0) % 3 + jit.randint(-1, 1))
        y = int(by + jit.randint(-1, 1))
        east = jit.random() < 0.72
        _tiny(d, max(0, min(59, x)), max(30, min(61, y)), east, cols[i % 3])
    return img


def roach_swarm_sheet():
    """잔바퀴 떼 시트: idle 2 · walk 4(무리가 꿈틀 — 거리 구동) · death 3(흩어지며 준다)."""
    idle = [roach_swarm(f) for f in (0, 1)]
    walk = [roach_swarm(f) for f in range(4)]
    death = [roach_swarm(5, 24, 1.3), roach_swarm(6, 12, 1.7), roach_swarm(7, 4, 2.1)]
    frames = idle + walk + death
    meta = {"frame": [64, 64], "foot": list(SWARM_FOOT), "rows": ["E"], "mirror": {"W": "E"}, "style": "isaac",
            "motions": {"idle": {"start": 0, "count": 2}, "walk": {"start": 2, "count": 4, "px_per_frame": 2, "drive": "distance"},
                        "death": {"start": 6, "count": 3}}}
    return frames, meta


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/creatures_uq2.png"
    rows = [drain_mother_sheet()[0], roach_swarm_sheet()[0]]
    W = max(sum(f.width + 4 for f in r) for r in rows) + 8
    H = sum(max(f.height for f in r) + 8 for r in rows) + 8
    sheet = Image.new("RGBA", (W, H), (60, 56, 52, 255))
    y = 8
    for r in rows:
        x = 8
        for f in r:
            sheet.alpha_composite(f, (x, y))
            x += f.width + 4
        y += max(f.height for f in r) + 8
    sheet.resize((W * 3, H * 3), Image.NEAREST).save(out)
    print(out)
