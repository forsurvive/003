"""파워 아머 리그 v1 — 계엄군 면허 생산형 '구형'(SD-16 §5.7, 단계 0-9). 아이작풍 치비와 같은 먹선·4단 명암.
SD-16 §5.7: 구형 = 각진 흉갑 · 원통 헬멧 · 등 원자로 돌출 4px. 계엄군 면허 생산형은 흑청 PF-01 + 놋쇠 띠 + 노란 '계엄' 완장(왼팔).
칸 48×56, 발 기준점 (24, 52)(사람 칸 40×48보다 한 단 크다). 방향 S·SE·E·NE·N(W·SW·NW는 반전), 모션 대기 1 · 걷기 6.
걸음은 치비와 같은 디딤발 고정 식(chibi.foot) — 무거운 몸이라 몸 들썩임 1px, 다리 굵기 5px.
손에 든 중화기(개틀링 계열 짧은 총열 묶음)는 무기 스탬프 대신 리그에 붙여 그린다(§5.7 '손 앵커만 리그 값').
python3 tools/power_armor.py  → samples/27_power_armor_x4.png(견본), pack.py가 시트 en_cr405_loco를 굽는다."""
import os, sys, math
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import chibi as K

ROOT = os.path.dirname(os.path.dirname(__file__))
CLEAR = (0, 0, 0, 0)
C = lambda t: P.rgb(t) + (255,)
W, H = 48, 56
FX, FY = 24, 52                                         # 발 기준점
NAVY = K.ramp(P.PF["PF-01"][:4])                        # 흑청 4단(어두움 → 밝음)
BRASS = [C("P47"), C("P48"), C("P49")]
JOINT = [C("P01"), C("P02"), C("P03")]
BAND = [C("P48"), C("P49"), C("P50")]                   # 노란 완장
GLOW = [C("P59"), C("P60")]                             # 바이저 등(호박색)
GUNM = [C("P02"), C("P04"), C("P05"), C("P07")]         # 총 금속(어두움 → 밝음)
VIEWS = K.VIEWS
STRIDE = {"walk": {"E": 6, "D": 4, "V": 4}, "run": {"E": 6, "D": 4, "V": 4}}   # 큰 몸 = 큰 보폭(사람 4·3·3). 뛰지 않는다


def foot(view, f):
    """chibi.foot과 같은 디딤발 고정 식, 보폭만 STRIDE(파워 아머)."""
    p = STRIDE["walk"]["E" if view == "E" else "V" if view in ("S", "N") else "D"]
    f %= 6
    u0 = (p + 1) // 2
    return {0: (u0, 0), 1: (u0 - p, 0), 2: (u0 - p - 1, 1), 3: (u0 - p, 2), 4: (0, 2), 5: (u0 - 1, 1)}[f]


def plate(d, x0, y0, x1, y1, r, bevel=2, light=True):
    """각진 판: 모서리를 bevel만큼 깎은 사각형. 바탕 r[2], 왼쪽·위 테두리 r[3], 오른쪽·아래 r[1]."""
    pts = [(x0 + bevel, y0), (x1 - bevel, y0), (x1, y0 + bevel), (x1, y1 - bevel), (x1 - bevel, y1), (x0 + bevel, y1),
           (x0, y1 - bevel), (x0, y0 + bevel)]
    d.polygon(pts, fill=r[2])
    if light:
        d.line([(x0 + bevel, y0), (x1 - bevel, y0)], fill=r[3])
        d.line([(x0, y0 + bevel), (x0, y1 - bevel)], fill=r[3])
        d.line([(x0, y0 + bevel), (x0 + bevel, y0)], fill=r[3])
        d.line([(x1, y0 + bevel), (x1, y1 - bevel)], fill=r[1])
        d.line([(x0 + bevel, y1), (x1 - bevel, y1)], fill=r[1])
        d.line([(x1, y1 - bevel), (x1 - bevel, y1)], fill=r[1])


def leg(d, hx, hy, fx, fy, near):
    """굵은 다리(허벅지 판 + 무릎 + 정강이) → 장화. near면 밝게."""
    r = NAVY if near else [NAVY[0], NAVY[0], NAVY[1], NAVY[2]]
    steps = max(abs(fx - hx), abs(fy - hy), 1)
    for i in range(steps + 1):
        t = i / steps
        x = round(hx + (fx - hx) * t)
        y = round(hy + (fy - hy) * t)
        d.rectangle([x - 2, y, x + 2, y], fill=r[2])
        d.point((x - 2, y), fill=r[3] if near else r[2])
        d.point((x + 2, y), fill=r[1])
    ky = round((hy + fy) / 2)
    kx = round((hx + fx) / 2)
    d.rectangle([kx - 2, ky - 1, kx + 2, ky], fill=JOINT[2] if near else JOINT[1])      # 무릎 관절
    d.rectangle([fx - 3, fy - 2, fx + 3, fy], fill=JOINT[1] if near else JOINT[0])      # 장화
    d.line([(fx - 3, fy - 2), (fx + 2, fy - 2)], fill=JOINT[2])


def helmet(d, view, cx, top):
    """원통 헬멧(구형): 둥근 윗모서리, 놋쇠 아랫테, 바이저 틈 + 호박색 눈 둘, 숨 거르개."""
    w = {"S": 18, "SE": 17, "E": 15, "NE": 17, "N": 18}[view]
    x0, x1 = cx - w // 2, cx - w // 2 + w - 1
    y0, y1 = top, top + 15
    plate(d, x0, y0, x1, y1, NAVY, bevel=4)
    d.line([(x0 + 3, y0 + 2), (x1 - 4, y0 + 2)], fill=NAVY[3])                          # 위쪽 반사
    d.rectangle([x0 + 1, y1 - 1, x1 - 1, y1], fill=BRASS[1])                             # 놋쇠 아랫테
    d.line([(x0 + 1, y1 - 1), (x1 - 1, y1 - 1)], fill=BRASS[2])
    if view in ("N", "NE"):                                                             # 뒤통수: 세로 냉각 핀
        for k in range(3):
            x = cx - 4 + k * 4 + (2 if view == "NE" else 0)
            d.line([(x, y0 + 4), (x, y1 - 4)], fill=NAVY[1])
        return
    face = {"S": 0, "SE": 3, "E": 5}[view]                                               # 얼굴판이 진행 쪽으로 돈다
    vx0, vx1 = (x0 + 2 + face, x1 - 2) if view != "E" else (cx, x1 - 1)
    vy = y0 + 6
    d.rectangle([vx0, vy, vx1, vy + 2], fill=JOINT[0])                                    # 바이저 틈
    if view == "S":
        eyes = (cx - 4, cx + 3)
    elif view == "SE":
        eyes = (cx - 1, cx + 5)
    else:
        eyes = (x1 - 3,)
    for ex in eyes:
        d.rectangle([ex - 1, vy + 1, ex, vy + 1], fill=GLOW[1])
        d.point((ex - 1, vy + 2), fill=GLOW[0])
    gx = cx + (face // 2 if view != "E" else 4)                                          # 숨 거르개(세로 틈)
    for k in (-2, 0, 2):
        if view == "E" and k < 0:
            continue
        d.line([(gx + k, vy + 4), (gx + k, vy + 7)], fill=NAVY[0])


def reactor(d, view, cx, y):
    """등 원자로: 놋쇠 뚜껑 둘 + 냉각 통. N에서 가장 크게, E·NE에서 등 뒤로 4px 돌출."""
    if view == "N":
        plate(d, cx - 7, y, cx + 6, y + 13, NAVY, bevel=3)
        for yy in (y + 1, y + 11):
            d.rectangle([cx - 5, yy, cx + 4, yy + 1], fill=BRASS[1])
            d.line([(cx - 5, yy), (cx + 4, yy)], fill=BRASS[2])
        for k in range(4):
            d.line([(cx - 4 + k * 3, y + 4), (cx - 4 + k * 3, y + 9)], fill=NAVY[0])
        d.rectangle([cx - 1, y + 5, cx, y + 8], fill=GLOW[0])                              # 노심 창
    elif view == "NE":
        plate(d, cx - 9, y + 1, cx + 1, y + 12, NAVY, bevel=3)
        d.rectangle([cx - 7, y + 2, cx - 1, y + 3], fill=BRASS[1])
        d.rectangle([cx - 5, y + 6, cx - 4, y + 8], fill=GLOW[0])
    elif view == "E":
        plate(d, cx - 13, y + 1, cx - 8, y + 13, NAVY, bevel=2)
        d.line([(cx - 12, y + 2), (cx - 12, y + 12)], fill=BRASS[1])
    elif view == "SE":
        plate(d, cx - 13, y + 2, cx - 10, y + 11, NAVY, bevel=1, light=False)


def gun(d, view, hx, hy):
    """중화기(총열 셋 묶음 + 놋쇠 탄통): 손 앵커(hx, hy)에서 조준 방향으로. 총 금속은 GUNM(갑옷보다 밝은 회색)."""
    if view == "S":                                                                      # 정면: 총구 셋이 이쪽을 본다
        d.rectangle([hx - 4, hy - 1, hx + 4, hy + 6], fill=GUNM[1])
        d.line([(hx - 4, hy - 1), (hx + 4, hy - 1)], fill=GUNM[3])
        d.line([(hx - 4, hy - 1), (hx - 4, hy + 6)], fill=GUNM[2])
        for k in (-2, 0, 2):
            d.rectangle([hx + k, hy + 3, hx + k, hy + 4], fill=GUNM[0])
            d.point((hx + k, hy + 2), fill=GUNM[3])
        d.rectangle([hx - 4, hy + 6, hx + 4, hy + 6], fill=GUNM[0])
    elif view == "SE":                                                                   # 비스듬히 앞으로
        d.rectangle([hx - 3, hy - 2, hx + 1, hy + 3], fill=BRASS[0])
        d.line([(hx - 3, hy - 2), (hx + 1, hy - 2)], fill=BRASS[1])
        for i in range(10):
            x, y = hx + 2 + i, hy + i // 2
            d.rectangle([x, y - 1, x, y + 2], fill=GUNM[1])
            d.point((x, y - 1), fill=GUNM[3])
            d.point((x, y + 2), fill=GUNM[0])
        d.rectangle([hx + 6, hy + 1, hx + 7, hy + 4], fill=GUNM[0])                       # 총열 고리
        d.rectangle([hx + 11, hy + 3, hx + 11, hy + 6], fill=GUNM[0])
    elif view == "E":
        d.rectangle([hx - 4, hy - 2, hx + 1, hy + 3], fill=BRASS[0])                     # 탄통
        d.line([(hx - 4, hy - 2), (hx + 1, hy - 2)], fill=BRASS[1])
        d.rectangle([hx + 2, hy - 2, hx + 14, hy + 2], fill=GUNM[1])
        d.line([(hx + 2, hy - 2), (hx + 14, hy - 2)], fill=GUNM[3])
        d.line([(hx + 2, hy + 2), (hx + 14, hy + 2)], fill=GUNM[0])
        d.line([(hx + 4, hy), (hx + 14, hy)], fill=GUNM[2])
        for x in (hx + 7, hx + 13):                                                     # 총열 고리
            d.rectangle([x, hy - 3, x + 1, hy + 3], fill=GUNM[0])
    elif view in ("NE", "N"):                                                          # 등 뒤로 겨눈 총열 끝만
        for i in range(8):
            x, y = hx + (i // 2 if view == "NE" else 0), hy - i
            d.rectangle([x - 1, y, x + 1, y], fill=GUNM[1])
            d.point((x - 1, y), fill=GUNM[3])


def figure(view, mode="idle", frame=0):
    """한 컷(48×56, 발 기준점 (24, 52)). 반환 RGBA."""
    img = Image.new("RGBA", (W, H), CLEAR)
    d = ImageDraw.Draw(img)
    moving = mode in ("walk", "run")
    bob = (0, 0, -1, 0, 0, -1)[frame % 6] if moving else 0
    hip_y = FY - 11 + bob
    ax, ay = K.AXIS[view]
    sx, sy = K.SIDE[view]
    side = view == "E"
    cx = FX
    # ---- 등 원자로(앞모습에서는 몸 뒤)
    reactor_y = hip_y - 17
    if view in ("SE", "E", "NE"):
        reactor(d, view, cx, reactor_y)
    # ---- 다리(먼 발 먼저)
    feet = []
    for k, ph in ((0, 0), (1, 3)):
        u, lift = foot(view, frame + ph) if moving else (0, 0)
        spread = (k * 2 - 1) * (2.0 if side else 4.0 if view in ("S", "N") else 3.0)
        fx = cx + ax * u + sx * spread
        fy = FY + ay * u + sy * spread * (0.5 if view in ("SE", "NE") else 1.0) - lift
        hx = cx + sx * spread * (0.6 if side else 0.9)
        hy = hip_y + (sy * spread * 0.3 if view in ("SE", "NE") else 0)
        near = (sy * spread) > 0 if view in ("E", "SE", "NE") else True
        feet.append((near, fx, fy, hx, hy))
    feet.sort(key=lambda f: (f[0], f[2]))
    for near, fx, fy, hx, hy in feet:
        leg(d, round(hx), round(hy), round(fx), round(fy), near)
    # ---- 몸통: 각진 흉갑
    tw = {"S": 22, "SE": 20, "E": 15, "NE": 20, "N": 22}[view]
    x0 = cx - tw // 2
    x1 = x0 + tw - 1
    y0 = hip_y - 15
    y1 = hip_y + 1
    plate(d, x0 + 1, y1 - 3, x1 - 1, y1, [JOINT[0], JOINT[1], JOINT[2], JOINT[2]], bevel=1)        # 허리 관절
    plate(d, x0, y0, x1, y1 - 3, NAVY, bevel=3)
    d.rectangle([x0 + 2, y1 - 5, x1 - 2, y1 - 4], fill=BRASS[1])                            # 놋쇠 허리띠
    d.line([(x0 + 2, y1 - 5), (x1 - 2, y1 - 5)], fill=BRASS[2])
    if view in ("S", "SE"):
        off = 0 if view == "S" else 2
        plate(d, x0 + 3 + off, y0 + 2, x1 - 3 + off // 2, y0 + 8, [NAVY[1], NAVY[2], NAVY[3], NAVY[3]], bevel=2)   # 가슴판
        d.rectangle([cx - 1 + off, y0 + 9, cx + 1 + off, y0 + 11], fill=JOINT[0])          # 가운데 흡기구
        for k in (0, 2):
            d.line([(cx - 1 + off, y0 + 9 + k), (cx + 1 + off, y0 + 9 + k)], fill=NAVY[1])
    elif side:
        plate(d, cx - 1, y0 + 2, x1 - 1, y0 + 9, [NAVY[1], NAVY[2], NAVY[3], NAVY[3]], bevel=2)
    else:                                                                                  # 등판
        for k in range(3):
            d.line([(x0 + 4, y0 + 4 + k * 3), (x1 - 4, y0 + 4 + k * 3)], fill=NAVY[1])
    if view == "N":
        reactor(d, view, cx, reactor_y + 2)
    # ---- 어깨판·팔·주먹(먼 팔 → 몸 → 가까운 팔 순서는 근사: 옆모습은 앞팔만)
    sw = (0, 1, 1, 0, -1, -1)[frame % 6] if moving else 0
    arms = []
    if side:
        arms = [(cx - 1, 1)]
    elif view in ("SE", "NE"):
        arms = [(x0 - 1, -1), (x1 + 1, 1)]
    else:
        arms = [(x0 - 2, -1), (x1 + 2, 1)]
    for axx, sgn in arms:
        swing = sw * sgn if not side else sw
        px0, px1 = axx - 3, axx + 3
        plate(d, px0, y0 - 2, px1, y0 + 4, NAVY, bevel=2)                                  # 어깨판(둥근 모서리)
        d.line([(px0 + 2, y0 - 2), (px1 - 2, y0 - 2)], fill=NAVY[3])
        ay0 = y0 + 5 + max(0, swing)
        d.rectangle([axx - 2, ay0, axx + 2, ay0 + 5], fill=NAVY[1] if sgn < 0 and not side else NAVY[2])
        d.line([(axx - 2, ay0), (axx - 2, ay0 + 5)], fill=NAVY[3] if sgn < 0 or side else NAVY[2])
        if (sgn > 0 and view in ("S", "SE")) or (sgn < 0 and view in ("N", "NE")) or side:  # 왼팔 노란 '계엄' 완장
            if not (side and view == "E" and False):
                d.rectangle([axx - 2, ay0 + 1, axx + 2, ay0 + 2], fill=BAND[1])
                d.line([(axx - 2, ay0 + 1), (axx + 2, ay0 + 1)], fill=BAND[2])
        d.rectangle([axx - 2, ay0 + 6, axx + 2, ay0 + 8], fill=JOINT[1])                    # 주먹
        d.line([(axx - 2, ay0 + 6), (axx + 2, ay0 + 6)], fill=JOINT[2])
    # ---- 중화기(손 앵커)
    if view in ("S", "SE"):
        gun(d, view, x1 + 1 if view == "S" else x1 - 2, y1 - 3)
    elif side:
        gun(d, view, cx + 1, y1 - 3)
    elif view == "NE":
        gun(d, view, x1 + 1, y0 + 4)
    # ---- 헬멧
    helmet(d, view, cx + (1 if view in ("SE", "E") else -1 if view == "NE" else 0), y0 - 14)
    img = K.outline(img, thick_bottom=False)
    return img


def sets(motions=("idle", "walk", "run")):
    """pack.pack 형식: 모션 → 방향 → 컷 목록. 달리기는 걷기 컷을 그대로 쓴다(파워 아머는 뛰지 않는다, 보폭만 다르다)."""
    out = {}
    for mo in motions:
        n = 1 if mo == "idle" else 6
        out[mo] = {v: [figure(v, "idle" if mo == "idle" else "walk", f) for f in range(n)] for v in VIEWS}
    return out


def sample():
    """견본: 5방향 대기 + E 걷기 6컷, 4배."""
    row1 = [figure(v) for v in VIEWS]
    row2 = [figure("E", "walk", f) for f in range(6)]
    sheet = Image.new("RGBA", (W * 6 + 10, H * 2 + 6), C("P03"))
    for i, f in enumerate(row1):
        sheet.alpha_composite(f, (i * W, 0))
    for i, f in enumerate(row2):
        sheet.alpha_composite(f, (i * W, H + 6))
    from grid import check
    bad = check(sheet, P.allowed_set("PF-01"))
    big = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
    big.save(os.path.join(ROOT, "samples", "27_power_armor_x4.png"))
    return bad


if __name__ == "__main__":
    print("power armor off-palette:", sample() or 0)
