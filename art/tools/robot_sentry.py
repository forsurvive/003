"""관제망 경비 로봇 파수-3(SJ-G70, CR-305) · 감시포 1형(CR-320) · 두뇌-4(CR-313, 잠든 소품) — 단계 1-11c SQ-S04 「도성이 뒤척인다」.

SD-16 §7.4 파수 계열: 64×64 · 이족 · 둥근 몸통 + 방패 팔 · 머리 CRT 얼굴판 · 관제망 휘장(동심원 위의 열쇠 구멍).
SD-16 §2.8 관제망 색: 대기 앰버 P59(느린 점멸) · 깨어남 앰버 P60 · 계엄 적 P54 · 소등 P04. 세진 크림 P08·P09 + 청록 P61·P62.
- 다섯 방향(S · SE · E · NE · N, W 쪽은 거울)을 사람 시트와 같은 줄 순서로 그린다.
- 걷기 6컷은 사람과 같은 보폭 표(chibi.STRIDE: 옆 4 · 대각 3 · 앞뒤 3px)와 같은 발 위치 함수(chibi.foot)를 쓴다 —
  디딤발이 세계에서 고정된다(SD-16 §3.6 ① 미끄러짐 금지). 무거운 기계라 몸은 디딤 컷에 1px 내려앉는다.
- 아이를 안고 걷는 판(carry): 방패 팔을 앞으로 접어 남솔(N-R01-034 외형)을 가슴에 안는다 — 경보 장면(파수가 아이를 데려가는 걸음).
- 쓰러짐 4컷: 불꽃 → 무릎 꺾임 → 옆으로 넘어짐 → 화면 꺼진 채 누움.
"""
import math
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
EYE = {"sleep": "P04", "idle": "P59", "awake": "P60", "alert": "P54"}


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


def _emblem(d, x, y, r=4):
    """관제망 휘장: 동심원 둘 + 가운데 열쇠 구멍."""
    d.ellipse([x - r, y - r, x + r, y + r], fill=C("P61"))
    d.ellipse([x - r + 1, y - r + 1, x + r - 1, y + r - 1], outline=C("P62"))
    d.ellipse([x - 1, y - 2, x + 1, y], fill=C(INK))
    d.line([x, y, x, y + 2], fill=C(INK))


# ---------------------------------------------------------------- 부품
def _leg(d, hip, ft, near):
    """허벅지 · 정강이를 한 덩어리 강철 원통으로(짧고 굵다) + 둥근 발."""
    col, hi = ("P13", "P14") if near else ("P12", "P13")
    d.line([hip, ft], fill=C(INK), width=7)
    d.line([hip, ft], fill=C(col), width=5)
    d.line([(hip[0] - 1, hip[1]), (ft[0] - 1, ft[1] - 1)], fill=C(hi), width=1)
    kx, ky = (hip[0] + ft[0]) // 2, (hip[1] + ft[1]) // 2                 # 무릎 관절
    d.ellipse([kx - 2, ky - 2, kx + 2, ky + 2], fill=C("P11"))
    d.point((kx - 1, ky - 1), fill=C(hi))
    fx, fy = ft
    d.ellipse([fx - 5, fy - 3, fx + 5, fy + 2], fill=C(INK))              # 발판
    d.ellipse([fx - 4, fy - 2, fx + 4, fy + 1], fill=C("P11"))
    d.line([fx - 3, fy - 2, fx + 2, fy - 2], fill=C("P12"))


def _torso(d, cx, cy, view, eye):
    """캡슐 몸통(크림) · 허리 청록 띠 · 앞이면 휘장, 뒤면 전지 덮개 · 옆이면 둥근 옆면."""
    w = {"S": 13, "SE": 12, "E": 10, "NE": 12, "N": 13}[view]
    h = 12
    d.rounded_rectangle([cx - w - 1, cy - h - 1, cx + w + 1, cy + h + 1], radius=9, fill=C(INK))
    d.rounded_rectangle([cx - w, cy - h, cx + w, cy + h], radius=8, fill=C("P08"))
    d.rounded_rectangle([cx - w, cy - h, cx + w - 3, cy + h - 3], radius=7, fill=C("P09"))   # 빛은 왼쪽 위
    d.arc([cx - w, cy - h, cx + w, cy + h], 20, 100, fill=C("P07"))
    d.rectangle([cx - w + 1, cy + 4, cx + w - 1, cy + 7], fill=C("P61"))      # 허리 띠
    d.line([cx - w + 1, cy + 4, cx + w - 1, cy + 4], fill=C("P62"))
    for x in range(cx - w + 3, cx + w - 1, 4):
        d.point((x, cy + 6), fill=C("P63"))
    if view in ("S", "SE"):
        ex = cx + (2 if view == "SE" else 0)
        _emblem(d, ex, cy - 4)
        d.point((ex + 7, cy - 8), fill=C(EYE[eye]))                       # 가슴 표시등(눈과 같은 색)
    elif view == "E":
        d.ellipse([cx - 2, cy - 7, cx + 5, cy], fill=C("P07"))             # 옆 어깨 관절 판
        d.ellipse([cx - 1, cy - 6, cx + 4, cy - 1], fill=C("P08"))
        d.point((cx + 7, cy - 6), fill=C(EYE[eye]))
    else:                                                                 # 등: 전지 덮개 · 통풍구 · 일련번호
        bx = cx - (2 if view == "NE" else 0)
        d.rectangle([bx - 6, cy - 9, bx + 6, cy + 1], fill=C("P07"))
        d.rectangle([bx - 5, cy - 8, bx + 5, cy], fill=C("P06"))
        for y in (cy - 6, cy - 4, cy - 2):
            d.line([bx - 4, y, bx + 4, y], fill=C("P05"))
        d.point((bx + 4, cy - 8), fill=C("P53"))                           # 억제기(SD-14: 등에 노출된 약점)
        d.point((bx + 3, cy - 8), fill=C("P54"))


def _head(d, cx, cy, view, eye, frame):
    """크림 케이스 안 CRT 얼굴판(단색). 앞 · 옆은 화면, 뒤는 진공관 뚜껑. 안테나 볼은 대기 앰버로 느리게 점멸."""
    w, h = 9, 7
    d.rounded_rectangle([cx - w - 1, cy - h - 1, cx + w + 1, cy + h + 1], radius=4, fill=C(INK))
    d.rounded_rectangle([cx - w, cy - h, cx + w, cy + h], radius=3, fill=C("P08"))
    d.line([cx - w + 2, cy - h, cx + w - 3, cy - h], fill=C("P09"))
    lit = C(EYE[eye])
    if view in ("S", "SE", "E"):
        off = {"S": 0, "SE": 2, "E": 4}[view]
        sw = {"S": 6, "SE": 5, "E": 3}[view]
        sx0, sx1 = cx - sw + off, cx + sw + off
        d.rectangle([sx0, cy - h + 2, sx1, cy + h - 2], fill=C("P10"))           # 화면(꺼진 녹흑)
        d.rectangle([sx0, cy - h + 2, sx1, cy - h + 2], fill=C("P33"))
        if eye != "sleep":
            if view == "E":
                d.rectangle([sx1 - 2, cy - 2, sx1 - 1, cy - 1], fill=lit)          # 옆에서 본 눈 하나
            else:
                ex = cx + off
                d.rectangle([ex - 4, cy - 2, ex - 3, cy - 1], fill=lit)
                d.rectangle([ex + 2, cy - 2, ex + 3, cy - 1], fill=lit)
                mouth = [(ex - 2, cy + 2), (ex + 2, cy + 2)] if eye != "alert" else [(ex - 2, cy + 3), (ex, cy + 2), (ex + 2, cy + 3)]
                d.line(mouth, fill=lit)
            for y in range(cy - h + 3, cy + h - 2, 2):                           # 주사선
                d.line([sx0, y, sx1, y], fill=C("P33") if eye != "sleep" else C("P10"))
        else:
            d.line([cx - 3 + off, cy, cx + 3 + off, cy], fill=C("P03"))
        if view != "E":
            d.point((sx1, cy + h - 3), fill=C("P06"))                            # 화면 귀퉁이 지문(원작 오마주)
    else:
        d.rectangle([cx - 5, cy - 4, cx + 5, cy + 3], fill=C("P07"))
        for x in (cx - 3, cx, cx + 3):
            d.line([x, cy - 3, x, cy + 2], fill=C("P05"))
    ax = cx - 4 if view in ("S", "SE", "E") else cx + 4
    d.line([ax, cy - h - 1, ax, cy - h - 5], fill=C(INK))                 # 안테나
    blink = eye in ("awake", "alert") or frame % 4 < 2
    d.ellipse([ax - 2, cy - h - 8, ax + 2, cy - h - 4], fill=C(INK))
    d.ellipse([ax - 1, cy - h - 7, ax + 1, cy - h - 5], fill=lit if blink and eye != "sleep" else C("P05"))


def _shield(d, x, y, view, front):
    """방패 팔: 청록 둥근 방패(크림 테) — 앞에서 보면 넓게, 옆에서 보면 두께만."""
    if view == "E" and not front:
        d.rectangle([x - 2, y - 9, x + 2, y + 9], fill=C(INK)); d.rectangle([x - 1, y - 8, x + 1, y + 8], fill=C("P61"))
        return
    w = {"S": 5, "SE": 6, "E": 3, "NE": 6, "N": 5}[view]
    d.rounded_rectangle([x - w - 1, y - 11, x + w + 1, y + 11], radius=4, fill=C(INK))
    d.rounded_rectangle([x - w, y - 10, x + w, y + 10], radius=3, fill=C("P08"))
    d.rounded_rectangle([x - w + 1, y - 9, x + w - 1, y + 9], radius=3, fill=C("P61"))
    d.line([x - w + 2, y - 8, x - w + 2, y + 7], fill=C("P62"))
    d.line([x - w + 1, y + 1, x + w - 1, y + 1], fill=C("P33"))
    for yy in (y - 6, y + 5):
        d.point((x, yy), fill=C("P08"))


def _gun_arm(d, sx, sy, ex, ey, view):
    """레이저 팔: 가는 강철 팔 + 손목 방열판 + 붉은 발사구."""
    d.line([sx, sy, ex, ey], fill=C(INK), width=5)
    d.line([sx, sy, ex, ey], fill=C("P13"), width=3)
    d.ellipse([ex - 3, ey - 3, ex + 3, ey + 3], fill=C(INK))
    d.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=C("P12"))
    for k in (-1, 1):
        d.point((ex + k, ey - 2), fill=C("P14"))
    tip = {"S": (0, 4), "SE": (2, 3), "E": (4, 0), "NE": (2, -2), "N": (0, -3)}[view]
    d.point((ex + tip[0], ey + tip[1]), fill=C("P54"))


# ---------------------------------------------------------------- 한 컷
_CHILD = {}


def _child(view):
    """남솔(N-R01-034) 외형을 아이 몸으로 — 파수 품에 안긴 모습(조금 작게)."""
    if view not in _CHILD:
        import json
        npcs = json.load(open(os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "npcs.json"), encoding="utf-8"))["npcs"]
        look = npcs.get("N-R01-034", {}).get("look", "K1-S3-HR07-H2-T03-1-PF12-HD00-EY00-PR045")
        im = K.actor(K.Look.parse(look), {"SE": "SE", "NE": "SE", "N": "S"}.get(view, view), "idle", 0)
        bb = im.getbbox()
        _CHILD[view] = im.crop(bb) if bb else im
    return _CHILD[view]


def sentry(view="S", mode="idle", frame=0, eye="idle", carry=False):
    """파수-3 한 컷. view S·SE·E·NE·N, mode idle·walk, eye sleep·idle·awake·alert."""
    im = img()
    d = ImageDraw.Draw(im)
    fx, fy = FOOT
    ax, ay = K.AXIS[view]
    sxv, syv = K.SIDE[view]
    moving = mode == "walk"
    bob = [1, 0, -1, 1, 0, -1][frame % 6] if moving else 0                 # 무거운 기계: 디딤 컷에 내려앉는다
    _shadow(d, fx, fy - 1, 13)
    hip_y = fy - 12 + bob
    sep = {"S": 5, "SE": 4, "E": 2, "NE": 4, "N": 5}[view]
    feet = []
    for k, side in ((0, -1), (1, 1)):
        u, lift = K.foot("walk", view, frame + 3 * k) if moving else (0, 0)
        px = fx + ax * u + sxv * side * sep
        py = fy - 2 + ay * u + syv * side * sep // 2 - lift
        hx = fx + sxv * side * (sep - 1)
        feet.append(((hx, hip_y), (px, py), side))
    # 먼 다리 먼저(화면 위쪽 = 먼 쪽)
    feet.sort(key=lambda t: t[1][1])
    for i, (hip, ft, side) in enumerate(feet):
        _leg(d, hip, ft, near=(i == 1))
    tcx, tcy = fx, hip_y - 12
    # 팔 자리: 로봇 왼팔 = 방패, 오른팔 = 레이저. 화면 기준으로 어느 쪽이 앞인가
    if view == "S":
        shield_x, gun_side, shield_front = tcx + 15, -1, True
    elif view == "SE":
        shield_x, gun_side, shield_front = tcx + 12, -1, True
    elif view == "E":
        shield_x, gun_side, shield_front = tcx - 3, 1, False                 # 방패는 몸 뒤(먼 쪽)
    elif view == "NE":
        shield_x, gun_side, shield_front = tcx - 12, 1, False
    else:
        shield_x, gun_side, shield_front = tcx - 15, 1, False
    sway = ([0, 1, 1, 0, -1, -1][frame % 6] if moving else 0)
    if not carry and not shield_front:
        _shield(d, shield_x, tcy + 2 - sway, view, False)
    gx = tcx + gun_side * {"S": 14, "SE": 12, "E": 2, "NE": 12, "N": 14}[view]
    if not carry and view == "N":
        _gun_arm(d, gx, tcy - 6, gx + 1, tcy + 6 + sway, view)
    _torso(d, tcx, tcy, view, eye)
    _head(d, tcx + (1 if view in ("SE", "E") else -1 if view == "NE" else 0), tcy - 19, view, eye, frame)
    if carry:
        ch = _child(view)
        if view != "N":
            cw, chh = ch.size
            cx0 = tcx - cw // 2 + {"S": 9, "SE": 10, "E": 5}.get(view, 0)     # 옆구리 쪽에 안는다(얼굴판이 보이게)
            cy0 = tcy - chh + {"S": 13, "SE": 13, "E": 15}.get(view, 13)
            im.alpha_composite(ch, (cx0, cy0))
            d = ImageDraw.Draw(im)
            # 아이를 받친 두 팔(방패 팔은 접어 등 쪽으로, 집게손이 아이 무릎 아래)
            o = {"S": 9, "SE": 10, "E": 5}.get(view, 0)
            d.line([tcx - 6, tcy - 4, tcx + o - 5, tcy + 8], fill=C(INK), width=5)        # 받친 팔(아이 무릎 아래)
            d.line([tcx - 6, tcy - 4, tcx + o - 5, tcy + 8], fill=C("P13"), width=3)
            d.line([tcx + o - 5, tcy + 8, tcx + o + 6, tcy + 8], fill=C(INK), width=4)
            d.line([tcx + o - 5, tcy + 8, tcx + o + 6, tcy + 8], fill=C("P14"), width=2)
            d.line([tcx + o + 9, tcy - 2, tcx + o + 7, tcy + 4], fill=C(INK), width=4)    # 등을 감싼 집게손
            d.line([tcx + o + 9, tcy - 2, tcx + o + 7, tcy + 4], fill=C("P12"), width=2)
        else:
            ch2 = ch.resize((ch.width, ch.height))
            top = ch2.crop((0, 0, ch2.width, min(ch2.height, 14)))           # 뒤에서는 어깨 너머로 아이 머리만
            im.alpha_composite(top, (tcx - top.width // 2 + 4, tcy - 30))
        return im
    if shield_front:
        _shield(d, shield_x, tcy + 2 + sway, view, True)
    if view != "N":
        if view == "E":
            _gun_arm(d, tcx + 2, tcy - 4, tcx + 9, tcy + 3 + sway, view)
        else:
            _gun_arm(d, gx, tcy - 5, gx - gun_side * 1 + (1 if view == "SE" else 0), tcy + 7 - sway, view)
    return im


def sentry_death(frame, lit=False):
    """0 불꽃 · 1 무릎 꺾임(기울기) · 2 옆으로 넘어짐 · 3 화면 꺼진 채 누움. lit = 누운 채 화면만 켜짐(MQ-102 잠든 파수가 반응할 때)."""
    if frame <= 1:
        base = sentry("S", "idle", 0, "alert" if frame == 0 else "sleep")
        out = img()
        rot = base.rotate(-8 * frame, resample=Image.NEAREST, center=FOOT)
        out.alpha_composite(rot, (0, 2 * frame))
        d = ImageDraw.Draw(out)
        for (sx, sy, c) in [(40, 14, "P50"), (24, 20, "P60"), (44, 26, "P63"), (30, 8, "P50")]:
            d.point((sx, sy + 3 * frame), fill=C(c)); d.point((sx + 1, sy + 3 * frame - 1), fill=C(c))
        return out
    out = img()
    d = ImageDraw.Draw(out)
    fx, fy = FOOT
    _shadow(d, fx, fy - 2, 22, 3)
    lift = 2 if frame == 2 else 0
    y = fy - 10 - lift
    d.rounded_rectangle([fx - 20, y - 8, fx + 6, y + 8], radius=7, fill=C(INK))            # 누운 몸통
    d.rounded_rectangle([fx - 19, y - 7, fx + 5, y + 7], radius=6, fill=C("P08"))
    d.rectangle([fx - 6, y - 7, fx - 3, y + 7], fill=C("P61"))
    _emblem(d, fx - 12, y, 3)
    d.rounded_rectangle([fx + 6, y - 7, fx + 20, y + 5], radius=3, fill=C(INK))            # 머리(화면 꺼짐)
    d.rounded_rectangle([fx + 7, y - 6, fx + 19, y + 4], radius=2, fill=C("P08"))
    d.rectangle([fx + 10, y - 4, fx + 17, y + 2], fill=C("P10"))
    if lit:
        d.rectangle([fx + 11, y - 3, fx + 12, y - 2], fill=C("P60")); d.rectangle([fx + 15, y - 3, fx + 16, y - 2], fill=C("P60"))
        d.line([fx + 12, y, fx + 15, y], fill=C("P60"))
    else:
        d.line([fx + 11, y - 1, fx + 16, y - 1], fill=C("P03"))
    d.line([fx - 20, y + 6, fx - 28, y + 9], fill=C(INK), width=5); d.line([fx - 20, y + 6, fx - 28, y + 9], fill=C("P12"), width=3)   # 다리
    d.ellipse([fx - 33, y + 6, fx - 25, y + 12], fill=C("P11"))
    d.rounded_rectangle([fx - 8, y + 6, fx + 4, y + 12], radius=3, fill=C("P61"))            # 떨어진 방패
    d.line([fx - 7, y + 7, fx + 3, y + 7], fill=C("P62"))
    if frame == 2:
        d.point((fx - 16, y - 12), fill=C("P50")); d.point((fx + 14, y - 11), fill=C("P60"))
    elif not lit:
        d.point((fx + 16, y - 10), fill=C("P05")); d.point((fx + 17, y - 12), fill=C("P04"))   # 연기 한 올
    return out


def sentry_sheet(eye="idle", carry=False):
    """5줄(S · SE · E · NE · N) × [idle 1 · walk 6 · death 4] = 11칸."""
    rows = []
    for v in VIEWS:
        row = [sentry(v, "idle", 0, eye, carry)] + [sentry(v, "walk", f, eye, carry) for f in range(6)]
        row += [sentry_death(f) for f in range(4)] if not carry else [sentry(v, "idle", 0, eye, carry) for _ in range(4)]
        rows.append(row)
    meta = {"frame": [FW, FH], "foot": list(FOOT), "rows": list(VIEWS),
            "motions": {"idle": {"start": 0, "count": 1}, "walk": {"start": 1, "count": 6}, "death": {"start": 7, "count": 4}}}
    return rows, meta


# ---------------------------------------------------------------- 감시포 1형(CR-320)
TW, TH = 48, 64
TFOOT = (24, 60)


def turret(view="S", frame=0, firing=False):
    """기둥 위 원통 포탑 + 회전 포신(관제망 휘장 · 표시등). 바로 아래는 사각(그림자 둥근 받침)."""
    im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fx, fy = TFOOT
    _shadow(d, fx, fy - 1, 9)
    d.rectangle([fx - 7, fy - 6, fx + 7, fy], fill=C(INK)); d.rectangle([fx - 6, fy - 5, fx + 6, fy - 1], fill=C("P05"))   # 콘크리트 받침
    d.rectangle([fx - 2, fy - 28, fx + 2, fy - 5], fill=C(INK)); d.rectangle([fx - 1, fy - 27, fx + 1, fy - 6], fill=C("P12"))   # 기둥
    cy = fy - 36
    vec = {"S": (0, 1), "SE": (1, 1), "E": (1, 0), "NE": (1, -1), "N": (0, -1)}[view]
    blen = 13
    bx, by = fx + vec[0] * blen, cy + 2 + vec[1] * int(blen * 0.6)
    back = vec[1] < 0
    if back:                                                              # 포신이 뒤로: 몸 뒤에 먼저
        d.line([fx, cy + 2, bx, by], fill=C(INK), width=5); d.line([fx, cy + 2, bx, by], fill=C("P11"), width=3)
    d.ellipse([fx - 10, cy - 8, fx + 10, cy + 10], fill=C(INK))
    d.ellipse([fx - 9, cy - 7, fx + 9, cy + 9], fill=C("P08"))
    d.ellipse([fx - 9, cy - 7, fx + 6, cy + 5], fill=C("P09"))
    d.rectangle([fx - 9, cy + 2, fx + 9, cy + 4], fill=C("P61"))
    _emblem(d, fx - 3 + vec[0] * 2, cy - 1, 3)
    lamp = "P54" if firing else ("P60" if frame % 2 == 0 else "P59")
    d.point((fx + 6, cy - 4), fill=C(lamp)); d.point((fx + 7, cy - 4), fill=C(lamp))
    if not back:
        d.line([fx, cy + 2, bx, by], fill=C(INK), width=5); d.line([fx, cy + 2, bx, by], fill=C("P12"), width=3)
        d.line([fx, cy + 1, bx, by - 1], fill=C("P14"))
        if firing:
            for (dx, dy, c) in [(0, 0, "P50"), (vec[0], vec[1], "P60"), (vec[0] * 2, vec[1] * 2, "P49"), (-vec[1], vec[0], "P60"), (vec[1], -vec[0], "P60")]:
                d.point((bx + dx, by + dy), fill=C(c))
    return im


def turret_death(frame):
    im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fx, fy = TFOOT
    _shadow(d, fx, fy - 1, 9)
    d.rectangle([fx - 7, fy - 6, fx + 7, fy], fill=C(INK)); d.rectangle([fx - 6, fy - 5, fx + 6, fy - 1], fill=C("P05"))
    d.rectangle([fx - 2, fy - 18 + 4 * frame // 2, fx + 2, fy - 5], fill=C("P11"))
    cy = fy - 26 + 6 * min(frame, 2)
    d.ellipse([fx - 9, cy - 6, fx + 9, cy + 8], fill=C(INK)); d.ellipse([fx - 8, cy - 5, fx + 8, cy + 7], fill=C("P07"))
    d.line([fx - 4, cy - 3, fx, cy + 3], fill=C(INK))
    d.point((fx + 4, cy - 8 - frame), fill=C("P05")); d.point((fx + 5, cy - 10 - frame), fill=C("P04"))
    return im


def turret_sheet():
    rows = []
    for v in VIEWS:
        rows.append([turret(v, 0), turret(v, 1), turret(v, 0, True), turret(v, 1, True)] + [turret_death(f) for f in range(4)])
    meta = {"frame": [TW, TH], "foot": list(TFOOT), "rows": list(VIEWS),
            "motions": {"idle": {"start": 0, "count": 2}, "walk": {"start": 2, "count": 2}, "death": {"start": 4, "count": 4}}}
    return rows, meta


# ---------------------------------------------------------------- 두뇌-4(CR-313) — 돔 안에서 대기(소품)
def brain4(state=""):
    """관제 중계 로봇 두뇌-4(1×1 발): 둥근 받침 위 크림 몸 + 유리 통 안 진공관 뇌(앰버 대기 점멸) + 양쪽 안테나 고리.
    state off = 전지를 뽑은 뒤(진공관 꺼짐 · 고개 떨굼)."""
    im = Image.new("RGBA", (40, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, fy = 20, 56
    _shadow(d, cx, fy, 12)
    d.ellipse([cx - 11, fy - 8, cx + 11, fy + 1], fill=C(INK)); d.ellipse([cx - 10, fy - 7, cx + 10, fy], fill=C("P12"))
    d.rounded_rectangle([cx - 9, fy - 26, cx + 9, fy - 5], radius=6, fill=C(INK))
    d.rounded_rectangle([cx - 8, fy - 25, cx + 8, fy - 6], radius=5, fill=C("P08"))
    d.rectangle([cx - 8, fy - 12, cx + 8, fy - 10], fill=C("P61"))
    _emblem(d, cx, fy - 18, 3)
    off = state == "off"
    gy = fy - 40 + (3 if off else 0)
    gx = cx + (2 if off else 0)
    d.ellipse([gx - 9, gy - 10, gx + 9, gy + 8], fill=C(INK))
    d.ellipse([gx - 8, gy - 9, gx + 8, gy + 7], fill=C("P15"))                # 유리 통
    for i, x in enumerate((gx - 4, gx, gx + 4)):                              # 진공관 셋
        col = "P04" if off else ("P60" if i == 1 else "P59")
        d.rectangle([x - 1, gy - 4, x + 1, gy + 4], fill=C(col)); d.ellipse([x - 1, gy - 6, x + 1, gy - 3], fill=C(col))
    d.arc([gx - 8, gy - 9, gx + 8, gy + 7], 200, 260, fill=C("P09"))
    for s in (-1, 1):
        d.ellipse([cx + s * 12 - 3, fy - 32, cx + s * 12 + 3, fy - 26], outline=C("P13"))
        d.line([cx + s * 9, fy - 24, cx + s * 12, fy - 27], fill=C("P13"))
    return im


def sentry_portrait(emo="기본"):
    """대화 초상화(96×96, 투명 바탕): 파수-3 머리를 가까이서 — 크림 케이스 · 녹흑 CRT 얼굴판(주사선) · 안테나 볼 · 아래로 어깨와 관제망 휘장.
    표정은 CRT 글자 얼굴로만: 기본 앰버 네모 눈 · 말함 입 줄 깜박 · 놀람 큰 네모 · 미소 위로 굽은 줄 · 슬픔 처진 줄 · 분노 계엄 적 사선 ·
    아픔 화면 찢김(잡음 띠) · 피곤 소등에 가까운 흐린 줄(대기)."""
    im = img(96, 96)
    d = ImageDraw.Draw(im)
    cx, cy = 48, 44
    d.rounded_rectangle([cx - 40, 78, cx + 40, 104], radius=14, fill=C(INK))        # 어깨 · 몸통 윗단
    d.rounded_rectangle([cx - 38, 80, cx + 38, 104], radius=12, fill=C("P08"))
    d.rounded_rectangle([cx - 38, 80, cx + 30, 104], radius=12, fill=C("P09"))
    _emblem(d, cx, 90, 6)
    d.rectangle([cx - 8, 70, cx + 8, 80], fill=C(INK)); d.rectangle([cx - 6, 70, cx + 6, 80], fill=C("P12"))   # 목 관절
    d.line([cx - 5, 73, cx + 5, 73], fill=C("P13")); d.line([cx - 5, 77, cx + 5, 77], fill=C("P11"))
    w, h = 34, 26
    d.rounded_rectangle([cx - w - 2, cy - h - 2, cx + w + 2, cy + h + 2], radius=12, fill=C(INK))
    d.rounded_rectangle([cx - w, cy - h, cx + w, cy + h], radius=10, fill=C("P08"))
    d.rounded_rectangle([cx - w, cy - h, cx + w - 5, cy + h - 5], radius=9, fill=C("P09"))
    d.arc([cx - w, cy - h, cx + w, cy + h], 15, 95, fill=C("P07"), width=2)
    for y in (cy - h + 6, cy + h - 7):                                              # 케이스 나사
        d.ellipse([cx + w - 7, y - 1, cx + w - 4, y + 2], fill=C("P06"))
    sx0, sy0, sx1, sy1 = cx - 25, cy - 18, cx + 25, cy + 18
    d.rounded_rectangle([sx0 - 2, sy0 - 2, sx1 + 2, sy1 + 2], radius=5, fill=C(INK))
    d.rounded_rectangle([sx0, sy0, sx1, sy1], radius=4, fill=C("P10"))
    eye = {"분노": "alert", "피곤": "sleep"}.get(emo, "idle" if emo in ("기본", "슬픔") else "awake")
    lit, glow = C(EYE[eye]), C("P33")
    if eye != "sleep":
        for y in range(sy0 + 2, sy1 - 1, 3):                                         # 주사선(켜진 화면은 녹빛이 돈다)
            d.line([sx0 + 2, y, sx1 - 2, y], fill=glow)
    ex1, ex2, ey = cx - 11, cx + 11, cy - 4
    if emo == "놀람":
        for ex in (ex1, ex2):
            d.rectangle([ex - 5, ey - 5, ex + 5, ey + 5], outline=lit, width=2)
        d.rectangle([cx - 3, cy + 8, cx + 3, cy + 12], outline=lit)
    elif emo == "미소":
        for ex in (ex1, ex2):
            d.rectangle([ex - 3, ey - 2, ex + 3, ey + 1], fill=lit)
        d.line([(cx - 9, cy + 7), (cx - 5, cy + 10), (cx + 5, cy + 10), (cx + 9, cy + 7)], fill=lit, width=2)
    elif emo == "슬픔":
        d.line([ex1 - 5, ey - 1, ex1 + 4, ey - 4], fill=lit, width=3); d.line([ex2 - 4, ey - 4, ex2 + 5, ey - 1], fill=lit, width=3)
        d.line([(cx - 8, cy + 11), (cx - 4, cy + 8), (cx + 4, cy + 8), (cx + 8, cy + 11)], fill=lit, width=2)
    elif emo == "분노":
        for ex, s in ((ex1, 1), (ex2, -1)):
            d.rectangle([ex - 4, ey - 2, ex + 4, ey + 2], fill=lit)
            d.line([ex - 6 * s, ey - 8, ex + 5 * s, ey - 4], fill=lit, width=2)
        d.line([cx - 8, cy + 10, cx + 8, cy + 10], fill=lit, width=2)
        d.line([cx - 8, cy + 10, cx - 10, cy + 8], fill=lit)
    elif emo == "피곤":
        for ex in (ex1, ex2):
            d.line([ex - 4, ey + 1, ex + 4, ey + 1], fill=C("P05"), width=2)
        d.line([cx - 4, cy + 9, cx + 4, cy + 9], fill=C("P05"))
    else:                                                                            # 기본 · 말함 · 아픔
        for ex in (ex1, ex2):
            d.rectangle([ex - 3, ey - 3, ex + 3, ey + 2], fill=lit)
            d.point((ex - 2, ey - 2), fill=C("P63"))
        if emo == "말함":
            d.rectangle([cx - 7, cy + 7, cx + 7, cy + 11], fill=lit); d.line([cx - 5, cy + 9, cx + 5, cy + 9], fill=C("P10"))
        else:
            d.line([cx - 7, cy + 9, cx + 7, cy + 9], fill=lit, width=2)
        if emo == "아픔":                                                            # 화면 찢김: 어긋난 잡음 띠 둘
            for yy, dx in ((cy - 10, 5), (cy + 4, -4)):
                strip = im.crop((sx0 + 1, yy, sx1 - 1, yy + 3))
                d.rectangle([sx0 + 1, yy, sx1 - 1, yy + 2], fill=C("P10"))
                im.alpha_composite(strip, (sx0 + 1 + dx, yy))
                d = ImageDraw.Draw(im)
                d.line([sx0 + 1, yy + 3, sx1 - 1, yy + 3], fill=C("P63"))
            d.rounded_rectangle([sx0 - 2, sy0 - 2, sx1 + 2, sy1 + 2], radius=5, outline=C(INK), width=2)
    d.point((sx1 - 3, sy1 - 3), fill=C("P06")); d.point((sx1 - 4, sy1 - 3), fill=C("P06"))   # 화면 귀퉁이 지문
    ax = cx - 18
    d.line([ax, cy - h - 2, ax, cy - h - 12], fill=C(INK), width=3)                   # 안테나
    d.line([ax, cy - h - 2, ax, cy - h - 12], fill=C("P12"))
    d.ellipse([ax - 5, cy - h - 20, ax + 5, cy - h - 10], fill=C(INK))
    d.ellipse([ax - 3, cy - h - 18, ax + 3, cy - h - 12], fill=lit if eye != "sleep" else C("P05"))
    d.point((ax - 1, cy - h - 17), fill=C("P63") if eye != "sleep" else C("P06"))
    return im


def portrait_faces():
    """파수-3 CRT 얼굴판 표정 6종(SD-16 §8 — 초상화 대신)."""
    out = {}
    for emo, eye in (("기본", "idle"), ("미소", "awake"), ("분노", "alert"), ("놀람", "awake"), ("슬픔", "idle"), ("피곤", "sleep")):
        out[emo] = sentry("S", "idle", 0, eye)
    return out


if __name__ == "__main__":                                                 # 미리 보기: python3 robot_sentry.py out.png
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/sentry.png"
    rows, _ = sentry_sheet("awake")
    crows, _ = sentry_sheet("awake", True)
    trows, _ = turret_sheet()
    W = FW * 11
    sheet = Image.new("RGBA", (W, FH * 10 + 70), (70, 80, 60, 255))
    for r, row in enumerate(rows):
        for c, f in enumerate(row):
            sheet.alpha_composite(f, (c * FW, r * FH))
    for r, row in enumerate(crows):
        for c, f in enumerate(row[:7]):
            sheet.alpha_composite(f, (c * FW, (r + 5) * FH))
    for c, f in enumerate([turret("S"), turret("SE"), turret("E", 0, True), turret("NE"), turret("N"), turret_death(3)]):
        sheet.alpha_composite(f, (c * TW, FH * 10 + 4))
    sheet.alpha_composite(brain4(), (7 * TW, FH * 10 + 6)); sheet.alpha_composite(brain4("off"), (8 * TW, FH * 10 + 6))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)
    print(out)
