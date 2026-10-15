"""계엄군 버티버드(CR-337 기체, SD-14 §9.2 · SD-03a §8.6 MQ-106 · SD-16 §13.6 '픽처 없이 맵 위 인게임 연출'), 단계 1-7.
3/4 탑다운: 동서로 누운 동체(오른쪽 = 기수 조종석 유리, 왼쪽 = 꼬리 붐과 쌍 수직꼬리) + 남북으로 뻗은 날개(북쪽 날개는 짧게 = 원근),
날개 끝에 세운 틸트 로터 엔진 둘. 계엄군 흑청 PF-01 + 노란 '계엄' 띠 + 꼬리 번호. 남쪽 옆구리에 화물칸 문(닫힘·열림 — 안에 하도윤이 앉은 그림은
실행 중에 사람 시트로 얹는다). 회전익은 따로(흐린 원판 3컷 — 돌며 깜박이지 않게 날개 자국이 120°씩 돈다), 그림자는 디더 타원(반투명 금지).
python3 vertibird.py → game/assets/sprites/vertibird.png(시트) + vertibird.json(칸 좌표), 견본 out/vertibird_x2.png"""
import os, sys, json, math, random
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import chibi as K
from struct_r01 import put_text

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
C = lambda t: P.rgb(t) + (255,)
INK = C("P01")
NAVY = K.ramp(P.PF["PF-01"][:4])                        # 흑청 4단(어두움 → 밝음)
BW, BH = 256, 184                                       # 기체 칸
RW, RH = 92, 50                                         # 회전익 칸
CY = 100                                                # 동체 가운데 줄
NAC = ((142, CY - 52), (142, CY + 58))                  # 엔진 나셀 바닥 가운데(북 · 남)
ROTOR_AT = [[x, y - 30] for (x, y) in NAC]              # 회전익 가운데 = 나셀 꼭대기
DOOR = (160, CY - 6, 194, CY + 17)                      # 화물칸 문(남쪽 옆구리, 날개와 조종석 사이)


def _half(x):
    """동체 옆모습 윤곽: x마다 (위, 아래). 꼬리 붐 → 몸통 → 둥근 기수."""
    if x < 30:
        return CY - 5, CY + 5
    if x < 84:
        return CY - 7, CY + 7
    if x < 104:
        k = (x - 84) / 20
        return CY - 7 - int(17 * k), CY + 7 + int(14 * k)
    if x < 204:
        return CY - 24, CY + 21
    k = (x - 204) / 34
    r = math.sqrt(max(0.0, 1 - k * k))
    return CY - 2 - int(22 * r), CY + 2 + int(19 * r)


def _fuselage(im):
    """원통 음영: 등(밝음) → 옆구리 → 배(그늘). 띠 경계는 한 줄 체크 디더."""
    px = im.load()
    for x in range(16, 239):
        top, bot = _half(x)
        for y in range(top, bot + 1):
            t = (y - top) / max(1, bot - top)
            if t < 0.10:
                c = NAVY[3]
            elif t < 0.42:
                c = NAVY[3] if t < 0.16 and (x + y) % 2 else NAVY[2] if t >= 0.16 else NAVY[3]
            elif t < 0.80:
                c = NAVY[1] if t < 0.46 and (x + y) % 2 else NAVY[2] if t < 0.46 else NAVY[1]
            else:
                c = NAVY[0] if t < 0.86 and (x + y) % 2 == 0 else NAVY[1] if t < 0.86 else NAVY[0]
            px[x, y] = c
    d = ImageDraw.Draw(im)
    for x in range(108, 200, 2):                                        # 등 반사선(끊긴 점선 = 금속 결)
        if x % 12:
            d.point((x, CY - 21), fill=C("P46"))
    for x in (104, 130, 158, 198):                                      # 판 이음(세로)
        top, bot = _half(x)
        d.line([(x, top + 3), (x, bot - 2)], fill=NAVY[0])
    for x in range(110, 200, 9):                                        # 리벳 줄
        d.point((x, CY - 9), fill=NAVY[0])


def body(open_door=False):
    im = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    nx, ny = NAC[0]
    sx, sy = NAC[1]
    # 북쪽 날개(뒤 — 원근으로 짧고 한 단 어둡게) + 북쪽 나셀
    d.polygon([(118, CY - 20), (154, CY - 20), (nx + 10, ny - 2), (nx - 10, ny - 2)], fill=NAVY[1])
    d.line([(nx - 10, ny - 2), (118, CY - 20)], fill=NAVY[2])
    d.line([(nx - 5, ny - 1), (124, CY - 21)], fill=NAVY[0])                # 플랩 선
    d.line([(nx + 10, ny - 2), (154, CY - 20)], fill=NAVY[0])
    _nacelle(d, nx, ny, far=True)
    # 쌍 수직꼬리 + 수평꼬리(H꼬리)
    d.rectangle([14, CY - 16, 40, CY + 14], fill=NAVY[1])               # 수평꼬리(위에서 본 판)
    d.line([(14, CY - 16), (40, CY - 16)], fill=NAVY[3])
    d.line([(14, CY + 14), (40, CY + 14)], fill=NAVY[0])
    _fuselage(im)
    for fy in (CY - 16, CY + 10):                                       # 수직꼬리 둘(판 양 끝에 선 지느러미)
        d.polygon([(16, fy + 4), (34, fy + 4), (26, fy - 22), (18, fy - 22)], fill=NAVY[2])
        d.line([(18, fy - 22), (16, fy + 4)], fill=NAVY[3])
        d.line([(26, fy - 22), (34, fy + 4)], fill=NAVY[0])
        d.line([(18, fy - 22), (26, fy - 22)], fill=NAVY[3])
    put_text(im, "BJ-04", 46, CY - 5, "P49", 8, "Galmuri7")              # 꼬리 번호(노란 칠)
    # 노란 '계엄' 띠(동체 둘레)
    for x in range(96, 102):
        top, bot = _half(x)
        d.line([(x, top + 1), (x, bot - 1)], fill=C("P50") if x == 96 else C("P48") if x == 101 else C("P49"))
    # 기수 조종석 유리(짙은 녹청 + 하늘 반사 두 줄) + 틀
    for x in range(206, 238):
        top, bot = _half(x)
        y1 = top + int((bot - top) * 0.55)
        for y in range(top + 1, y1):
            px = im.load()
            px[x, y] = C("P35") if (y - top) < (y1 - top) * 0.45 else C("P34")
    d.line([(214, CY - 18), (230, CY - 10)], fill=C("P37"))
    d.line([(218, CY - 14), (226, CY - 10)], fill=C("P63"))
    d.line([(206, CY - 22), (206, CY + 8)], fill=NAVY[0])
    d.line([(222, CY - 21), (224, CY + 6)], fill=NAVY[0])
    # 화물칸 문
    x0, y0, x1, y1 = DOOR
    if open_door:
        d.rectangle([126, y0 - 1, 158, y1 + 1], fill=NAVY[2])           # 뒤로 민 문짝
        d.line([(126, y0 - 1), (158, y0 - 1)], fill=NAVY[3])
        d.line([(126, y0 - 1), (126, y1 + 1)], fill=NAVY[0])
        put_text(im, "계엄", 133, y0 + 7, "P48", 8, "Galmuri7")
        d.rectangle([x0, y0, x1, y1], fill=C("P01"))
        d.rectangle([x0 + 2, y0 + 1, x1 - 2, y1], fill=C("P02"))
        for x in range(x0 + 4, x1 - 4, 7):                              # 안쪽 접이 의자 + 붉은 실내등
            d.rectangle([x, y0 + 4, x + 4, y0 + 10], fill=C("P11"))
            d.point((x + 2, y0 + 5), fill=C("P10"))
        d.line([(x0 + 2, y0 + 1), (x1 - 2, y0 + 1)], fill=C("P14"))
        d.line([(x0 + 2, y0 + 14), (x1 - 2, y0 + 14)], fill=C("P04"))   # 바닥 턱
    else:
        d.rectangle([x0, y0, x1, y1], fill=NAVY[2])
        d.rectangle([x0, y0, x1, y1], outline=NAVY[0])
        d.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=NAVY[3])
        d.rectangle([x0 + 3, y0 + 13, x0 + 6, y0 + 15], fill=C("P48"))  # 손잡이
        put_text(im, "계엄", x0 + 7, y0 + 4, "P49", 8, "Galmuri7")
    # 착륙 스키드(배 밑 — 그늘 쪽으로 살짝 보임)
    for kx in (112, 188):
        d.line([(kx, CY + 19), (kx - 3, CY + 27)], fill=C("P04"))
    d.line([(100, CY + 28), (198, CY + 28)], fill=C("P05"))
    d.line([(100, CY + 29), (198, CY + 29)], fill=C("P03"))
    d.line([(198, CY + 28), (202, CY + 25)], fill=C("P05"))
    # 남쪽 날개(앞 — 길고 밝게) + 남쪽 나셀
    d.polygon([(116, CY + 12), (156, CY + 12), (sx + 10, sy - 6), (sx - 10, sy - 6)], fill=NAVY[2])
    d.polygon([(156, CY + 12), (159, CY + 12), (sx + 12, sy - 6), (sx + 10, sy - 6)], fill=NAVY[0])   # 앞전 두께(그늘)
    d.line([(116, CY + 12), (sx - 10, sy - 6)], fill=NAVY[3])
    d.line([(123, CY + 13), (sx - 5, sy - 7)], fill=NAVY[1])                # 플랩 선
    for k in (0.35, 0.7):                                                   # 날개 판 이음
        ya = int(CY + 12 + (sy - 6 - CY - 12) * k)
        xa = int(116 + (sx - 10 - 116) * k); xb = int(156 + (sx + 10 - 156) * k)
        d.line([(xa + 1, ya), (xb - 1, ya)], fill=NAVY[1])
    _nacelle(d, sx, sy, far=False)
    return K.outline(im)


def _nacelle(d, ex, ey, far):
    """날개 끝 엔진(세운 원통 — 이륙 자세). ey = 바닥. 왼쪽이 빛."""
    r = [NAVY[0], NAVY[0], NAVY[1], NAVY[2]] if far else NAVY
    d.rounded_rectangle([ex - 11, ey - 28, ex + 11, ey], radius=5, fill=r[2])
    d.rectangle([ex - 11, ey - 24, ex - 7, ey - 3], fill=r[3])
    d.rectangle([ex + 7, ey - 24, ex + 11, ey - 3], fill=r[1])
    d.ellipse([ex - 11, ey - 33, ex + 11, ey - 24], fill=r[3])          # 윗면 테
    d.ellipse([ex - 9, ey - 32, ex + 9, ey - 25], fill=C("P02"))        # 흡입구
    d.ellipse([ex - 3, ey - 30, ex + 3, ey - 27], fill=C("P05"))        # 허브
    d.rectangle([ex - 11, ey - 10, ex + 11, ey - 8], fill=C("P49"))     # 노란 경고 띠
    d.line([(ex - 11, ey - 10), (ex + 11, ey - 10)], fill=C("P50"))


def rotor(f):
    """회전익(위에서 본 3/4 납작 타원): 가운데는 비우고 날 끝 자리만 성긴 디더 테(흐린 원판) + 날 셋(f마다 40°씩)."""
    im = Image.new("RGBA", (RW, RH), (0, 0, 0, 0))
    px = im.load()
    cx, cy, rx, ry = RW // 2, RH // 2, RW // 2 - 2, RH // 2 - 2
    for y in range(RH):
        for x in range(RW):
            u = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if 0.62 < u <= 1.0 and (x + 2 * y + f) % 5 == 0:
                px[x, y] = C("P07") if u > 0.85 else C("P06")
            elif 0.95 < u <= 1.0 and (x + f) % 3 == 0:
                px[x, y] = C("P06")
    d = ImageDraw.Draw(im)
    for k in range(3):
        a = math.radians(f * 40 + k * 120)
        ca, sa = math.cos(a), math.sin(a)
        x1, y1 = cx + ca * rx * 0.97, cy + sa * ry * 0.97
        d.line([(cx, cy), (x1, y1)], fill=C("P03"), width=2)
        d.line([(cx + ca * 6, cy + sa * 3), (cx + ca * rx * 0.6, cy + sa * ry * 0.6)], fill=C("P06"))
        d.point((round(x1), round(y1)), fill=C("P49"))                  # 날 끝 노란 칠
    d.ellipse([cx - 4, cy - 3, cx + 4, cy + 3], fill=C("P02"))
    d.point((cx - 1, cy - 1), fill=C("P06"))
    return im


def shadow(scale=1.0):
    """디더 그림자(동체 타원 + 날개 띠 모양). scale = 높이(떠 있을수록 작게 · 성기게)."""
    im = Image.new("RGBA", (220, 90), (0, 0, 0, 0))
    px = im.load()
    cx, cy = 110, 45
    step = 2 if scale >= 0.8 else 3
    for y in range(90):
        for x in range(220):
            dx, dy = (x - cx) / scale, (y - cy) / scale
            hull = (dx / 104) ** 2 + (dy / 20) ** 2 <= 1.0
            wing = abs(dx - 14) <= 12 and -34 <= dy <= 26
            if (hull or wing) and (x + y) % step == 0 and (step == 2 or y % 2 == 0):
                px[x, y] = C("P01")
    return im


def main():
    frames = {"body": body(False), "body_open": body(True)}
    for f in range(3):
        frames["rotor%d" % f] = rotor(f)
    for i, s in enumerate((0.45, 0.65, 0.85, 1.0)):
        frames["shadow%d" % i] = shadow(s)
    sheet = Image.new("RGBA", (BW * 2, BH + RH), (0, 0, 0, 0))
    meta, x, y = {}, 0, 0
    sheet.alpha_composite(frames["body"], (0, 0)); meta["body"] = [0, 0, BW, BH]
    sheet.alpha_composite(frames["body_open"], (BW, 0)); meta["body_open"] = [BW, 0, BW, BH]
    for f in range(3):
        sheet.alpha_composite(frames["rotor%d" % f], (f * RW, BH)); meta["rotor%d" % f] = [f * RW, BH, RW, RH]
    big = Image.new("RGBA", (BW * 2, BH + RH + 90 * 2), (0, 0, 0, 0))
    big.alpha_composite(sheet, (0, 0))
    for i in range(4):
        bx, by = (i % 2) * 220, BH + RH + (i // 2) * 90
        big.alpha_composite(frames["shadow%d" % i], (bx, by)); meta["shadow%d" % i] = [bx, by, 220, 90]
    from grid import check, upscale
    bad = check(big, P.allowed_set("UI", "PF-01"))
    if bad:
        raise SystemExit("팔레트 밖 색: %s" % bad[:5])
    out = os.path.join(ROOT, "game", "assets", "sprites")
    big.save(os.path.join(out, "vertibird.png"))
    json.dump({"frames": meta, "rotor_at": ROTOR_AT, "door": [DOOR[0], DOOR[1], DOOR[2] - DOOR[0], DOOR[3] - DOOR[1]],
               "shadow_at": [128, CY + 34], "size": [BW, BH]},
              open(os.path.join(out, "vertibird.json"), "w"), indent=1)
    demo = Image.new("RGBA", (BW * 2 + 60, BH + 70), C("P19"))
    for k, (nm, lift) in enumerate((("body", 30), ("body_open", 0))):
        ox = 20 + k * (BW + 20)
        sh = frames["shadow1" if lift else "shadow3"]
        demo.alpha_composite(sh, (ox + 128 - 110, 30 + CY + 34 - 45))
        demo.alpha_composite(frames[nm], (ox, 30 - lift))
        for (rx_, ry_) in ROTOR_AT:
            demo.alpha_composite(frames["rotor%d" % k], (ox + rx_ - RW // 2, 30 - lift + ry_ - RH // 2))
    os.makedirs(os.path.join(ROOT, "art", "out"), exist_ok=True)
    upscale(demo, 2).save(os.path.join(ROOT, "art", "out", "vertibird_x2.png"))
    print("버티버드 시트:", big.size)


if __name__ == "__main__":
    main()
