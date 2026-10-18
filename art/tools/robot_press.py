"""산업 로봇 성형-4(SJ-P71 금형 프레스 보조 · 민수 · 관제망 비연결, CR-326) — 단계 1-D7 구로 공단 지식산업센터.

원문 SD-09a L1040 '산업 로봇(SJ 산업형, SD-14에서 ID 부여)' → SD-14 CR-326 신설. 외형 SD-16 §7.4 로봇 계열 64×64:
- 다리 대신 궤도 받침(공장 바닥 레일 따라 다님) · 세진 크림 몸통 + 안전 노랑 · 검정 빗금 팔 · 머리 대신 렌즈 하나(상태 색)
  · 팔 끝은 금형 집게(프레스에 금형을 물리는 손). 가슴에 세진 '생산 라인 3' 판.
- 걷기 6컷: 궤도 돌기는 세계에 고정 — 그림이 컷마다 보폭(chibi.STRIDE)만큼 나아가면 바닥에 닿은 돌기는 그만큼 뒤로 밀려 그려진다
  (SD-16 §3.6 ① 미끄러짐 금지를 궤도에 맞춘 판). 팔은 걸음마다 조금 흔들린다.
- 작업 2컷(work): 팔을 내려 금형을 누른다 · 들어 올린다 — 라인 박자(쿵)에 맞춰 진행기가 고른다.
- 쓰러짐 4컷: 불꽃 → 팔 늘어짐 → 옆으로 기욺 → 렌즈 꺼짐.
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import chibi as K

FW, FH = 64, 64
FOOT = (32, 60)
INK = "P01"
VIEWS = ("S", "SE", "E", "NE", "N")
LENS = {"idle": "P59", "line": "P56", "alert": "P54", "off": "P04"}
CREAM = ("P06", "P07", "P08", "P09")
SAFE = ("P58", "P59", "P49", "P50")                  # 안전 노랑


def C(t):
    return P.rgb(t) + (255,)


def img(w=FW, h=FH):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, cx, cy, rx, ry=3):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            e = ((x - cx) / rx) ** 2 + ((y - cy) / (ry + 0.5)) ** 2
            if e <= 0.5 or (e <= 1.0 and (x + y) % 2 == 0):
                d.point((x, y), fill=C("P02"))


def _tread(d, x0, y0, x1, y1, along_x, shift):
    """궤도 하나: 검은 고무 띠 + 돌기(간격 6). shift = 바닥 고정을 위해 거꾸로 민 거리(px)."""
    d.rounded_rectangle([x0, y0, x1, y1], radius=2, fill=C(INK))
    d.rounded_rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], radius=2, fill=C("P03"))
    if along_x:
        for x in range(x0 + 1 + (-shift) % 6, x1, 6):
            d.line([x, y0 + 1, x, y1 - 1], fill=C("P02"))
            d.point((x + 1, y0 + 1), fill=C("P05"))
    else:
        for y in range(y0 + 1 + (-shift) % 6, y1, 6):
            d.line([x0 + 1, y, x1 - 1, y], fill=C("P02"))
            d.point((x0 + 1, y + 1), fill=C("P05"))
    for x in (x0 + 2, x1 - 2):                                                   # 바퀴 축
        if along_x:
            d.point((x, (y0 + y1) // 2), fill=C("P06"))


def _hazard(d, x0, y0, x1, y1):
    """안전 빗금(노랑 · 검정) — 칸 안에서만(빗금이 테 밖으로 번지지 않게 점으로 찍는다)."""
    d.rectangle([x0, y0, x1, y1], fill=C(SAFE[2]))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x + (y1 - y)) % 4 == 0:
                d.point((x, y), fill=C(INK))


def _arm(d, base, elbow, hand, near):
    """관절 팔: 어깨 → 팔꿈치 → 손목(안전 노랑 원통 + 검정 관절) · 끝에 금형 집게."""
    for a, b in ((base, elbow), (elbow, hand)):
        d.line([a, b], fill=C(INK), width=6 if near else 5)
        d.line([a, b], fill=C(SAFE[2] if near else SAFE[1]), width=4 if near else 3)
    for j in (base, elbow):
        d.ellipse([j[0] - 3, j[1] - 3, j[0] + 3, j[1] + 3], fill=C(INK))
        d.ellipse([j[0] - 2, j[1] - 2, j[0] + 2, j[1] + 2], fill=C("P04"))
    hx, hy = hand
    d.rectangle([hx - 4, hy - 1, hx + 4, hy + 4], fill=C(INK))                     # 집게
    d.rectangle([hx - 3, hy, hx + 3, hy + 1], fill=C("P06"))
    d.line([hx - 3, hy + 2, hx - 3, hy + 3], fill=C("P05")); d.line([hx + 3, hy + 2, hx + 3, hy + 3], fill=C("P05"))


def press_bot(view="S", mode="idle", frame=0, lens="idle"):
    """성형-4 한 컷. view S·SE·E·NE·N, mode idle · walk · work(frame 0 내림 · 1 올림), lens idle · line · alert · off."""
    im = img()
    d = ImageDraw.Draw(im)
    fx, fy = FOOT
    ax, ay = K.AXIS[view]
    moving = mode == "walk"
    p = K.stride("walk", view)
    shift = (frame % 6) * p if moving else 0                                         # 바닥에 닿은 돌기는 그림이 나아간 만큼 뒤로
    bob = [0, 1, 0, 0, 1, 0][frame % 6] if moving else 0                             # 궤도 이음새를 넘을 때 1px 덜컹
    _shadow(d, fx, fy - 1, 15)
    by = fy - 3
    # ---- 궤도 받침(옆 · 앞 모습)
    if view == "E":
        _tread(d, fx - 15, by - 9, fx + 15, by, True, shift)
        d.rectangle([fx - 11, by - 13, fx + 11, by - 9], fill=C(INK)); d.rectangle([fx - 10, by - 12, fx + 10, by - 10], fill=C("P05"))
    elif view in ("S", "N"):
        for sx in (-1, 1):
            _tread(d, fx + sx * 13 - 4, by - 12, fx + sx * 13 + 4, by, False, shift * (ay if ay else 1))
        d.rectangle([fx - 9, by - 13, fx + 9, by - 4], fill=C(INK)); d.rectangle([fx - 8, by - 12, fx + 8, by - 5], fill=C("P05"))
    else:
        far = -1 if view == "SE" else 1
        _tread(d, fx - 15, by - 11 + 2 * (far < 0), fx + 11, by - 3 + 2 * (far < 0), True, shift)
        _tread(d, fx - 11, by - 9 - 2 * (far < 0), fx + 15, by - 1 - 2 * (far < 0), True, shift)
        d.rectangle([fx - 9, by - 14, fx + 9, by - 8], fill=C(INK)); d.rectangle([fx - 8, by - 13, fx + 8, by - 9], fill=C("P05"))
    # ---- 몸통(크림 상자 · 안전 빗금 띠 · 라인 판)
    ty = by - 14 + bob
    d.rounded_rectangle([fx - 11, ty - 16, fx + 11, ty], radius=3, fill=C(INK))
    d.rounded_rectangle([fx - 10, ty - 15, fx + 10, ty - 1], radius=3, fill=C(CREAM[2]))
    d.line([fx - 9, ty - 14, fx + 9, ty - 14], fill=C(CREAM[3]))
    _hazard(d, fx - 10, ty - 4, fx + 10, ty - 2)
    if view != "N":
        d.rectangle([fx - 6, ty - 11, fx + 2, ty - 7], fill=C("P61")); d.line([fx - 5, ty - 9, fx + 1, ty - 9], fill=C("P09"))   # '라인 3' 판
        d.point((fx - 4, ty - 10), fill=C("P09")); d.point((fx - 1, ty - 8), fill=C("P09"))
    else:
        d.rectangle([fx - 6, ty - 12, fx + 6, ty - 6], fill=C(CREAM[1]))            # 뒤: 전지 덮개
        for x in (fx - 4, fx, fx + 4):
            d.line([x, ty - 11, x, ty - 7], fill=C(CREAM[0]))
    # ---- 렌즈 머리(목 기둥 위 원통)
    hx = fx + {"S": 0, "SE": 2, "E": 3, "NE": 2, "N": 0}[view]
    hy = ty - 22
    d.rectangle([hx - 1, hy + 4, hx + 1, ty - 15], fill=C("P04"))
    d.ellipse([hx - 6, hy - 5, hx + 6, hy + 5], fill=C(INK))
    d.ellipse([hx - 5, hy - 4, hx + 5, hy + 4], fill=C(CREAM[2]))
    if view != "N":
        lx = hx + {"S": 0, "SE": 2, "E": 3, "NE": 1}[view]
        d.ellipse([lx - 3, hy - 3, lx + 3, hy + 3], fill=C(INK))
        d.ellipse([lx - 2, hy - 2, lx + 2, hy + 2], fill=C(LENS.get(lens, "P59")))
        d.point((lx - 1, hy - 1), fill=C("P09"))
    else:
        d.line([hx - 3, hy, hx + 3, hy], fill=C(CREAM[0]))
    # ---- 팔(작업: 내림 · 올림 / 걷기: 접고 흔들림)
    side = 1 if view in ("S", "SE", "E") else -1
    sx0, sy0 = fx + side * 9, ty - 12
    sway = [0, 1, 1, 0, -1, -1][frame % 6] if moving else 0
    if mode == "work":
        down = frame % 2 == 0
        elbow = (sx0 + side * 8, sy0 - 8)
        hand = (sx0 + side * 13, sy0 + (10 if down else -4))
    else:
        elbow = (sx0 + side * 6, sy0 - 9 + sway)
        hand = (sx0 + side * 10, sy0 + 2 + sway)
    near = view not in ("N", "NE")
    if not near:                                                                   # 뒤를 볼 땐 팔이 몸 뒤
        im2 = img()
        _arm(ImageDraw.Draw(im2), (sx0, sy0), elbow, hand, False)
        im2.alpha_composite(im)
        im = im2
        d = ImageDraw.Draw(im)
    else:
        _arm(d, (sx0, sy0), elbow, hand, True)
    if mode == "work" and frame % 2 == 0:                                           # 누를 때 불꽃 두 점
        d.point((hand[0] - 2, hand[1] + 5), fill=C("P50")); d.point((hand[0] + 3, hand[1] + 4), fill=C("P60"))
    return im


def press_death(frame):
    """0 불꽃 · 1 팔 늘어짐(렌즈 빨강 깜빡) · 2 옆으로 기욺 · 3 렌즈 꺼짐 · 연기."""
    if frame <= 1:
        base = press_bot("S", "idle", 0, "alert" if frame == 0 else "off")
        d = ImageDraw.Draw(base)
        for (x, y, c) in ((40, 20, "P50"), (24, 26, "P60"), (36, 12, "P63")):
            d.point((x, y + frame * 2), fill=C(c)); d.point((x + 1, y + frame * 2 - 1), fill=C(c))
        return base
    base = press_bot("S", "idle", 0, "off")
    out = img()
    rot = base.rotate(-14 if frame == 2 else -22, resample=Image.NEAREST, center=FOOT)
    out.alpha_composite(rot, (0, 0))
    d = ImageDraw.Draw(out)
    d.point((34, 16 - frame), fill=C("P05")); d.point((35, 13 - frame), fill=C("P04"))
    return out


def press_sheet(lens="line"):
    """5줄(S · SE · E · NE · N) × [idle 1 · walk 6 · death 4 · work 2] = 13칸."""
    rows = []
    for v in VIEWS:
        row = [press_bot(v, "idle", 0, lens)] + [press_bot(v, "walk", f, lens) for f in range(6)]
        row += [press_death(f) for f in range(4)]
        row += [press_bot(v, "work", 0, lens), press_bot(v, "work", 1, lens)]
        rows.append(row)
    meta = {"frame": [FW, FH], "foot": list(FOOT), "rows": list(VIEWS),
            "motions": {"idle": {"start": 0, "count": 1}, "walk": {"start": 1, "count": 6}, "death": {"start": 7, "count": 4},
                        "work": {"start": 11, "count": 2}}}
    return rows, meta


if __name__ == "__main__":
    rows, _ = press_sheet("line")
    sheet = Image.new("RGBA", (FW * len(rows[0]), FH * len(rows)), (70, 66, 74, 255))
    for r, row in enumerate(rows):
        for c, f in enumerate(row):
            sheet.alpha_composite(f, (c * FW, r * FH))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(sys.argv[1])
