"""1-D5 여의도 금탑 크리처 — 왕개미(SD-14 §3.5 CR-080~082, 아이작풍 옆 3/4 · E만, W는 반전).
- 일개미 CR-080: 몸길이 약 1m · 검은 광택 껍질(먹 · 짙은 회색 · 붉은 갈색 반사) · 머리 · 가슴 · 배 세 마디 · 다리 셋 쌍(삼각 보행) · 더듬이 둘 · 큰턱.
- 병정 CR-081: 머리가 한 치수 크고 큰턱이 길다 · 배 끝 개미산 분사(spray 2컷 — 꽁무니를 앞으로 말아 뿜는다).
- 여왕 CR-082: 96×64 · 배가 부풀어 마디 사이가 희게 늘어났다 · 날개 떨어진 자리 그루터기 · 알 낳기(lay 2컷) · 산성 침(spit 2컷).
걷기는 발을 땅에 고정한 삼각 보행(컷마다 디딘 다리는 몸과 같이 뒤로 — 미끄러짐 없음, px_per_frame).
"""
import os, sys, math, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from chibi import C, CLEAR, INK, L, outline, ramp, shade
import chibi_creatures as CC

ANT = ramp(["P01", "P02", "P03", "P04", "P24"])            # 검은 광택 껍질(먹 → 짙은 회색 → 붉은 갈색 반사)
GASTER_W = ramp(["P19", "P20", "P21", "P22", "P09"])        # 여왕 배 마디 사이로 늘어난 흰 막
LEG = [C("P02"), C("P03")]
KINDS = {                                                   # 칸 · 발 기준점 · 몸 크기 비율 · 걷기 컷당 px
    "worker": {"frame": (64, 40), "foot": (30, 36), "s": 1.0, "px": 3},
    "soldier": {"frame": (64, 44), "foot": (30, 40), "s": 1.15, "px": 3},
    "queen": {"frame": (96, 64), "foot": (44, 58), "s": 1.6, "px": 2},
}


def _legs(d, frame, pose, base_y, hips, hip_y, scale, far):
    """한쪽 다리 셋(far 1 = 먼 쪽 · 0 = 가까운 쪽): 엉덩이(가슴 밑) → 무릎(몸 높이 위로 꺾임) → 발끝(땅).
    삼각 보행 — 같은 조(앞 · 뒤 한쪽 + 가운데 반대쪽)가 함께 딛고, 디딘 발은 컷마다 몸과 같은 만큼 뒤로(px_per_frame) 간다."""
    for i, hx in enumerate(hips):
        grp = (i + far) % 2
        ph = (frame + grp * 2) % 4 if pose == "walk" else 0
        u = [3, 1, -1, 1][ph] * scale if pose == "walk" else 0
        lift = (0 if ph in (0, 1) else 2) if pose == "walk" else 0
        reach = (-13, 2, 13)[i] * scale
        fx, fy = hx + reach + u, base_y - far * 2 - lift
        kx, ky = hx + reach * 0.55 + u * 0.5, hip_y + 1 * scale - far * 1 - lift
        col = C("P03") if far else INK
        d.line([hx, hip_y, kx, ky], fill=col, width=2 if not far else 1)                    # 넓적다리(굵다)
        d.line([kx, ky, fx, fy], fill=col, width=1)                                          # 종아리(가늘다)
        d.point((fx + (1 if reach >= 0 else -1), fy), fill=col)                              # 발끝 갈고리
        if not far:
            d.point((kx, ky), fill=C("P04"))                                                 # 무릎 광택


def ant(kind="worker", frame=0, pose="walk", hurt=False, snap=0, spray=0, lay=0, spit=0, pulse=0):
    """왕개미 한 컷. pose: idle · walk · bite(큰턱 snap 0/1) · spray(병정 꽁무니 분사 1/2) · lay(여왕 알) · spit(여왕 산성 침)."""
    K = KINDS[kind]
    W_, H_ = K["frame"]
    s = K["s"]
    fx0, fy0 = K["foot"]
    img = Image.new("RGBA", (W_, H_), CLEAR)
    d = ImageDraw.Draw(img)
    bob = 1 if pose == "walk" and frame % 2 else 0
    base = fy0
    # 몸 중심(왼쪽 = 배 · 가운데 = 가슴 · 오른쪽 = 머리)
    cx = fx0
    gx, gy = cx - 15 * s, base - 12 * s - bob                  # 배(가스터)
    tx, ty = cx + 1 * s, base - 13 * s - bob                   # 가슴
    hx, hy = cx + 16 * s, base - 14 * s - bob                  # 머리
    if kind == "queen":
        gx, gy = cx - 18 * s * 0.85, base - 13 * s - bob
    hips = (tx - 4 * s, tx, tx + 4 * s)
    hip_y = ty + 3 * s
    _legs(d, frame, pose, base, hips, hip_y - 1, s, 1)                                     # 먼 쪽 다리(몸 뒤)
    body = Image.new("RGBA", img.size, CLEAR)
    bd = ImageDraw.Draw(body)
    # 배: 여왕은 크게 부풀고 마디 사이 흰 막이 늘어났다 · 병정 분사 땐 꽁무니가 앞으로 말린다
    if kind == "queen":                                                                     # 부푼 배: 검은 마디 판 사이로 흰 막이 띠처럼 늘어났다
        grx, gry = 17.0 * s * 0.85 + pulse * 0.6, 10.0 * s * 0.85 + pulse * 0.5
        CC._ellipse(body, gx, gy, grx, gry, ANT[:4])
        for k in (1, 2, 3, 4):                                                               # 막 띠 넷(굽은 세로띠 — 배의 둥근 면을 따라)
            x0 = gx - grx + k * (grx * 2) / 5.0
            for yy in range(int(gy - gry + 2), int(gy + gry - 1)):
                t = (yy - gy) / gry
                bend = int(round(2.0 * t * t))
                for w in range(3):
                    xx = int(x0 + bend + w - 1)
                    if 0 <= xx < W_ and 0 <= yy < H_ and body.getpixel((xx, yy))[3]:
                        body.putpixel((xx, yy), GASTER_W[1 if w == 1 else 0] if yy > gy - gry * 0.4 else GASTER_W[3])
        bd.arc([gx - grx, gy - gry, gx + grx, gy + gry], 200, 320, fill=ANT[4])
    else:
        curl = spray * 3 * s
        CC._ellipse(body, gx + curl * 0.4, gy + curl * 0.3, 9.0 * s, 7.0 * s, ANT[:4])
        bd.arc([gx - 9 * s + curl * 0.4, gy - 7 * s + curl * 0.3, gx + 9 * s + curl * 0.4, gy + 7 * s + curl * 0.3], 200, 300, fill=ANT[4])
        for k in range(3):                                                                  # 배 마디 줄
            ax = gx - 5 * s + k * 4 * s + curl * 0.4
            bd.arc([ax - 3, gy - 6 * s + curl * 0.3, ax + 3, gy + 6 * s + curl * 0.3], 70, 110, fill=ANT[0])
    # 허리 마디(가는 자루 + 비늘)
    bd.ellipse([gx + 7 * s, gy - 3 * s, gx + 12 * s, gy + 2 * s], fill=ANT[1])
    bd.ellipse([gx + 9 * s, gy - 6 * s, gx + 12 * s, gy - 1 * s], fill=ANT[2])               # 비늘(위로 솟음)
    # 가슴(길쭉 — 앞이 높다)
    CC._ellipse(body, tx, ty, 6.5 * s, 3.6 * s, ANT[:4])
    bd.ellipse([tx + 5 * s, ty - 2 * s, tx + 9 * s, ty + 1 * s], fill=ANT[1])               # 목(가슴 → 머리)
    bd.line([tx - 5 * s, ty - 3 * s, tx + 4 * s, ty - 4 * s], fill=ANT[4])
    if kind == "queen":                                                                      # 날개 떨어진 자리 그루터기
        bd.polygon([(tx - 2 * s, ty - 4 * s), (tx + 1 * s, ty - 7 * s), (tx + 2 * s, ty - 4 * s)], fill=ANT[3])
    # 머리(병정은 크다)
    hr = (5.5 if kind == "worker" else (7.0 if kind == "soldier" else 5.5)) * s * (0.9 if kind == "queen" else 1.0)
    CC._ellipse(body, hx, hy, hr, hr * 0.85, ANT[:4])
    bd.arc([hx - hr, hy - hr * 0.85, hx + hr, hy + hr * 0.85], 210, 300, fill=ANT[4])
    bd.ellipse([hx + hr * 0.15, hy - hr * 0.5, hx + hr * 0.15 + 3, hy - hr * 0.5 + 3], fill=C("P54") if hurt else C("P05"))   # 겹눈
    bd.point((hx + hr * 0.15 + 1, hy - hr * 0.5), fill=C("P08"))
    img.alpha_composite(body)
    img = outline(img)
    d = ImageDraw.Draw(img)
    _legs(d, frame, pose, base, hips, hip_y, s, 0)                                         # 가까운 쪽 다리(몸 앞)
    # 큰턱(앞으로 · 물 때 벌어졌다 닫힌다) — 병정은 길고 톱니
    jl = (5 if kind == "worker" else (8 if kind == "soldier" else 5)) * s
    open_ = 3 * s if snap else 1
    for k, dy in enumerate((-open_, open_)):
        x0, y0 = hx + hr * 0.8, hy + hr * 0.25
        x1, y1 = x0 + jl, y0 + dy + (2 if k else 0)
        d.line([x0, y0, x1, y1], fill=INK, width=2)
        d.line([x0 + 1, y0 + (0 if k else 0), x1 - 1, y1], fill=C("P24"))                     # 큰턱 붉은 갈색 광택
        d.line([x1, y1, x1 - 2, y1 + (2 if not k else -2)], fill=INK)                         # 끝이 안으로 굽은 갈고리
        if kind == "soldier":
            d.point((x0 + jl * 0.5, y0 + dy * 0.5 + (1 if k else -1)), fill=INK)          # 톱니
    # 더듬이(꺾인 팔꿈치 · 컷마다 끝이 흔들린다)
    t = frame % 3
    for k, (ax, ay) in enumerate(((2, -1), (1, 1))):
        x0, y0 = hx + hr * 0.3, hy - hr * 0.6
        ex, ey = x0 + 5 * s, y0 - 7 * s + k * 2
        tipx, tipy = ex + 6 * s, ey + (2 + t if k else 1 - t // 2)
        d.line([x0, y0, ex, ey], fill=INK if k == 0 else C("P02"))
        d.line([ex, ey, tipx, tipy], fill=INK if k == 0 else C("P02"))
    # 동작 효과
    if spray and kind != "queen":                                                            # 개미산 분사(배 끝 → 앞쪽 아래로 흩뿌림)
        px0, py0 = gx + 8 * s, gy + 6 * s
        for k in range(5 + spray * 3):
            ang = 0.15 + k * 0.08
            r = 6 + k * 2 * spray
            x, y = px0 + math.cos(ang) * r, py0 + math.sin(ang) * r * 0.4
            if 0 <= x < W_ and 0 <= y < H_:
                d.point((x, y), fill=C("P56" if k % 2 else "P57"))
    if spit:                                                                                 # 여왕 산성 침(입에서 앞으로 방울)
        for k in range(spit * 2 + 1):
            x, y = hx + hr + 4 + k * 4, hy + 1 + k
            if x < W_ - 1:
                d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=C("P56"))
    if lay:                                                                                  # 알(배 끝 아래 흰 타원)
        ex0, ey0 = gx - 17 * s * 0.85 + 2, gy + 6
        for k in range(lay):
            d.ellipse([ex0 + k * 5, ey0 + k, ex0 + k * 5 + 5, ey0 + k + 7], fill=INK)
            d.ellipse([ex0 + k * 5 + 1, ey0 + k + 1, ex0 + k * 5 + 4, ey0 + k + 6], fill=C("P09"))
    if hurt:
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                if px[x, y][3] and px[x, y] != INK:
                    px[x, y] = C("P09")
    return img


def ant_death(kind):
    """죽음 4컷: 뒤집혀 다리를 움츠림(2) → 체액 웅덩이 위로 납작(2)."""
    K = KINDS[kind]
    W_, H_ = K["frame"]
    base = ant(kind, 0, "idle")
    flip = base.transpose(Image.FLIP_TOP_BOTTOM)
    out = []
    for k in range(2):
        f = Image.new("RGBA", (W_, H_), CLEAR)
        f.alpha_composite(flip.crop((0, 4, W_, H_)), (0, 4 + k * 2))
        out.append(f)
    for k in range(2):
        sq = base.resize((W_, max(8, H_ - (H_ // 4) * (k + 1))), Image.NEAREST)
        f = Image.new("RGBA", (W_, H_), CLEAR)
        f.alpha_composite(CC.ichor(61 + k, int(W_ * 0.7), max(10, H_ // 3)), (int(W_ * 0.12), H_ - max(10, H_ // 3) - 2))
        f.alpha_composite(sq, (0, H_ - sq.height - 2))
        out.append(f)
    return out


def ant_sheet(kind):
    """왕개미 시트: idle 1 · walk 4(px_per_frame) · bite 2 · (병정) spray 2 · (여왕) pulse 2 · lay 2 · spit 2 · death 4."""
    K = KINDS[kind]
    frames = [ant(kind, 0, "idle")]
    motions = {"idle": {"start": 0, "count": 1}}
    walk = [ant(kind, f, "walk") for f in range(4)]
    motions["walk"] = {"start": len(frames), "count": 4, "px_per_frame": K["px"], "drive": "distance"}
    frames += walk
    motions["bite"] = {"start": len(frames), "count": 2}
    frames += [ant(kind, 0, "idle", snap=1), ant(kind, 1, "idle", snap=0)]
    if kind == "soldier":
        motions["spray"] = {"start": len(frames), "count": 2}
        frames += [ant(kind, 0, "idle", spray=1), ant(kind, 0, "idle", spray=2)]
    if kind == "queen":
        motions["pulse"] = {"start": len(frames), "count": 2}
        frames += [ant(kind, 0, "idle", pulse=0), ant(kind, 0, "idle", pulse=1)]
        motions["lay"] = {"start": len(frames), "count": 2}
        frames += [ant(kind, 0, "idle", pulse=1, lay=1), ant(kind, 0, "idle", pulse=0, lay=2)]
        motions["spit"] = {"start": len(frames), "count": 2}
        frames += [ant(kind, 0, "idle", snap=1, spit=1), ant(kind, 0, "idle", snap=1, spit=2)]
    motions["death"] = {"start": len(frames), "count": 4}
    frames += ant_death(kind)
    meta = {"frame": list(K["frame"]), "foot": list(K["foot"]), "rows": ["E"], "mirror": {"W": "E"}, "style": "isaac", "motions": motions}
    return frames, meta


if __name__ == "__main__":
    out = sys.argv[1]
    rows = []
    for k in ("worker", "soldier", "queen"):
        fr, _ = ant_sheet(k)
        rows.append(fr)
    W = max(sum(f.width + 2 for f in r) for r in rows)
    H = sum(r[0].height + 4 for r in rows)
    sheet = Image.new("RGBA", (W, H), (176, 150, 110, 255))
    y = 2
    for r in rows:
        x = 2
        for f in r:
            sheet.alpha_composite(f, (x, y))
            x += f.width + 2
        y += r[0].height + 4
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
