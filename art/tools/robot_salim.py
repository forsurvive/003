"""세진 살림-2(SJ-H66 가사 부양, SD-14 §8.2 '은색 구체 팔 3') 변형 — 볼트 S-02 선거 관리 로봇 둘(아이작풍, 단계 1-11l SQ-S13).

- 투표함지기 2호(N-R02-028): 어깨에서 비스듬히 두른 크림 선거 띠(붉은 가장자리) · 아래 팔이 든 작은 투표함 · 앞 팔이 흔드는 투표용지 · 옆면에 덧칠한 '2'.
- 개표 4호(N-R02-029): 앞 팔 끝이 계수기(놋쇠 상자 · 숫자 창) · 몸통 아래 출력구에서 '재검표' 출력지 띠가 늘어진다 · 옆면 '4'.
- 원장 대행(K-24 '대한 대피 적성 학원', 1-12b FQ-GS-02): 앞 팔에 출석부(갈색 판 · 흰 종이 · 놋쇠 집게) · 아래 팔에 자습 종(놋쇠 손종) ·
  몸통 앞 남색 명찰 띠('원장 대행' 흰 획). 숫자 덧칠 없음 — 학원 기물이라 번호 대신 명찰.
- 번개 점원(노량진 번개24 · V24, 1-12g UQ-01): 번개24 제복 도장 — 구체 위쪽 반을 청솔 하늘청으로 칠하고 적도에 주황 띠(번개 꺾쇠) ·
  흰 명찰 '24' · 앞 팔에 바코드 판독기(회색 상자 · 붉은 빛) · 아래 팔에 배급표 펀치(놋쇠 집게). 이름 없는 기체(SD-07b — 번호는 명찰의 '24'뿐).
- 깔끔이(관악 행정 연수원 N-R01-065, 1-12i UQ-63): 어깨에서 비스듬히 두른 남색 졸업 리본 띠(금색 가장자리 · '33' 자리 금 점 둘) · 앞 팔 먼지떨이(나무 자루 · 노란 술 — 걷는 컷에 흔들림) ·
  아래 팔에 접은 강당 의자(갈색 좌판 · 쇠 다리). 숫자 덧칠 없음. 쓰러지면 의자가 넘어지고 먼지떨이 술이 흩어진다.
- 공통: 은색 구체 몸 · 정수리에서 뻗은 눈줄기 셋(앞 눈이 크다) · 아래 분사구 불꽃. 발이 없다 — 몸은 그림자 위 18px에 떠서 1px씩 흔들리고,
  그림자는 제자리(미끄러짐 규칙과 무관). 옆(E)만 그리고 W는 뒤집는다(robots.py 살핌-1과 같은 형식): idle 4 · walk 4 · death 4.
- 빛은 왼쪽 위: 몸 오른쪽 아래에 초승달 그늘, 왼쪽 위에 반짝임. 반투명 없음 · 팔레트 UI 묶음 안의 색만.
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

FW, FH = 56, 62
FOOT = (26, 58)                      # 그림자 가운데 = 노드 발 기준점
INK = "P01"
SILVER = ("P04", "P05", "P06", "P08", "P09")    # 깊은 그늘 · 그늘 · 바탕 · 빛 · 반짝


def C(t):
    return P.rgb(t)


def img(w=FW, h=FH):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, cx, cy, rx):
    for y in range(cy - 2, cy + 3):
        for x in range(cx - rx, cx + rx + 1):
            e = ((x - cx) / rx) ** 2 + ((y - cy) / 2.6) ** 2
            if e <= 0.45 or (e <= 1.0 and (x + y) % 2 == 0):
                d.point((x, y), fill=C("P02"))


def _digit(d, x, y, n, col="P53"):
    """손으로 덧칠한 숫자(3×5 획). 2와 4만 쓴다."""
    c = C(col)
    if n == 2:
        d.line([x, y, x + 2, y], fill=c); d.line([x + 2, y, x + 2, y + 2], fill=c)
        d.line([x + 2, y + 2, x, y + 2], fill=c); d.line([x, y + 2, x, y + 4], fill=c); d.line([x, y + 4, x + 3, y + 4], fill=c)
    else:
        d.line([x, y, x, y + 2], fill=c); d.line([x, y + 2, x + 3, y + 2], fill=c); d.line([x + 2, y, x + 2, y + 4], fill=c)
    d.point((x - 1, y + 1), fill=C("P52"))                            # 붓 삐침


def _arm(d, pts, col="P05"):
    """가는 관절 팔: 먹선 2px 위에 금속 1px."""
    d.line(pts, fill=C(INK), width=3)
    d.line(pts, fill=C(col), width=1)
    for p in pts[1:-1]:
        d.point(p, fill=C("P08"))                                     # 관절 반짝


def _eye(d, x0, y0, x1, y1, r, blink=False, big=False):
    """눈줄기: 몸에서 렌즈까지 줄기 + 렌즈(검은 고리 · 유리 · 청록 눈동자)."""
    d.line([x0, y0, x1, y1], fill=C(INK), width=2)
    d.point((x0, y0), fill=C("P06"))
    d.ellipse([x1 - r - 1, y1 - r - 1, x1 + r + 1, y1 + r + 1], fill=C(INK))
    d.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=C("P02"))
    if not blink:
        if big:
            d.rectangle([x1 - 1, y1 - 1, x1 + 1, y1 + 1], fill=C("P62")); d.point((x1, y1 - 1), fill=C("P63"))
        else:
            d.point((x1, y1), fill=C("P62"))
    d.point((x1 - r + 1, y1 - r + 1), fill=C("P08"))


def _clerk_paint(d, cx, cy, r):
    """번개24 제복 도장: 위 반구 하늘청(빛 쪽은 밝게) · 적도 주황 띠와 흰 번개 꺾쇠 · 흰 명찰 '24'(먹 두 획)."""
    for y in range(cy - r + 1, cy + 2):
        for x in range(cx - r + 1, cx + r):
            if (x - cx) ** 2 + (y - cy) ** 2 < (r - 0.5) ** 2:
                lit = (x - cx) + (y - cy) < -r * 0.6
                shade = (x - cx) > r * 0.45 or (x - cx) + (y - cy) > r * 0.3
                d.point((x, y), fill=C("P46" if lit else ("P44" if shade else "P45")))
    d.point((cx - r + 5, cy - r + 5), fill=C("P09"))                   # 칠 위 반짝
    d.line([cx - r + 1, cy + 2, cx + r - 1, cy + 2], fill=C("P27"))      # 주황 띠
    d.line([cx - r + 2, cy + 3, cx + r - 2, cy + 3], fill=C("P26"))
    d.line([cx - 2, cy + 1, cx, cy + 3], fill=C("P09")); d.line([cx, cy + 3, cx + 1, cy + 1], fill=C("P09"))   # 번개 꺾쇠
    d.rectangle([cx - 8, cy - 5, cx - 3, cy - 2], fill=C(INK))         # 흰 명찰 '24'
    d.rectangle([cx - 7, cy - 4, cx - 4, cy - 3], fill=C("P09"))
    d.point((cx - 6, cy - 4), fill=C(INK)); d.point((cx - 5, cy - 3), fill=C(INK))


def salim(frame=0, pose="idle", kind="ballot"):
    """살림-2 한 컷. pose: idle | walk | death(frame 0~3). kind: ballot(투표함지기 2호) | count(개표 4호)."""
    if pose == "death":
        return _death(frame, kind)
    im = img()
    d = ImageDraw.Draw(im)
    fx, fy = FOOT
    bob = [0, -1, -1, 0][frame % 4]
    lean = 1 if pose == "walk" else 0
    swing = [0, 1, 0, -1][frame % 4] if pose == "walk" else [0, 0, 1, 0][frame % 4]
    cx, cy = fx + lean, fy - 30 + bob                                # 구체 가운데(바닥에서 30px 위)
    r = 11
    _shadow(d, fx, fy, 10 if bob == 0 else 9)
    # 분사구(아래) + 불꽃
    fl = ([2, 3, 2, 4] if pose == "idle" else [4, 6, 5, 6])[frame % 4]
    d.polygon([(cx - 4, cy + r - 1), (cx + 4, cy + r - 1), (cx + 2, cy + r + 3), (cx - 2, cy + r + 3)], fill=C(INK))
    d.polygon([(cx - 3, cy + r - 1), (cx + 3, cy + r - 1), (cx + 1, cy + r + 2), (cx - 1, cy + r + 2)], fill=C("P04"))
    d.line([cx - 1, cy + r + 4, cx - 1, cy + r + 3 + fl], fill=C("P59"))
    d.line([cx, cy + r + 4, cx, cy + r + 4 + fl], fill=C("P60"))
    d.line([cx + 1, cy + r + 4, cx + 1, cy + r + 3 + fl - 1], fill=C("P59"))
    d.point((cx, cy + r + 4), fill=C("P50"))
    # 뒤 팔(몸 뒤에 먼저): 뒤로 접힌 집게
    _arm(d, [(cx - r + 2, cy + 2), (cx - r - 3, cy + 5 + swing), (cx - r - 5, cy + 9 + swing)])
    d.line([cx - r - 6, cy + 9 + swing, cx - r - 4, cy + 11 + swing], fill=C(INK))
    # 뒤 눈줄기(몸 뒤)
    _eye(d, cx - 4, cy - r + 1, cx - 9, cy - r - 7, 2, blink=frame % 4 == 2)
    # 몸: 외곽 → 은 바탕 → 그늘 초승달 → 빛
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=C(INK))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C(SILVER[1]))
    d.ellipse([cx - r, cy - r, cx + r - 2, cy + r - 2], fill=C(SILVER[2]))
    d.ellipse([cx - r + 2, cy - r + 2, cx - 1, cy - 1], fill=C(SILVER[3]))
    d.ellipse([cx - r + 4, cy - r + 4, cx - r + 6, cy - r + 6], fill=C(SILVER[4]))
    d.arc([cx - r, cy - r, cx + r, cy + r], 30, 120, fill=C(SILVER[0]))
    # 이음 띠(적도) + 리벳
    d.line([cx - r + 1, cy + 3, cx + r - 1, cy + 3], fill=C(SILVER[0]))
    for x in range(cx - r + 3, cx + r - 2, 4):
        d.point((x, cy + 4), fill=C("P09"))
    if kind == "clerk":
        _clerk_paint(d, cx, cy, r)
    if kind == "ballot":
        _digit(d, cx - 8, cy + 5, 2)                                    # 띠 아래(이음 띠 밑)에 덧칠
    elif kind == "count":
        _digit(d, cx - 7, cy - 6, 4)
    if kind == "clean":
        # 졸업 리본 띠: 왼쪽 위 → 오른쪽 아래(남색 · 금 가장자리 · '33' 자리 금 점 둘)
        for t in range(-r + 2, r - 1):
            x = cx + t
            y = cy - 3 + t // 2
            if (x - cx) ** 2 + (y - cy) ** 2 < (r - 1) ** 2:
                d.point((x, y - 1), fill=C("P49"))
                d.point((x, y), fill=C("P44")); d.point((x, y + 1), fill=C("P44"))
                d.point((x, y + 2), fill=C("P49"))
        d.point((cx - 2, cy - 3), fill=C("P50")); d.point((cx + 1, cy - 2), fill=C("P50"))
    if kind == "proxy":
        # 남색 명찰 띠(몸 앞 · 이음 띠 위) — 흰 획 두 줄('원장 대행'을 1배율에서 줄 글씨로)
        d.rectangle([cx - 6, cy - 3, cx + 5, cy + 1], fill=C(INK))
        d.rectangle([cx - 5, cy - 2, cx + 4, cy], fill=C("P44"))
        d.line([cx - 4, cy - 1, cx - 1, cy - 1], fill=C("P09")); d.line([cx + 1, cy - 1, cx + 3, cy - 1], fill=C("P09"))
    elif kind == "ballot":
        # 선거 띠: 왼쪽 위 → 오른쪽 아래로 비스듬히(크림 · 붉은 가장자리)
        for t in range(-r + 2, r - 1):
            x = cx + t
            y = cy - 3 + t // 2
            if (x - cx) ** 2 + (y - cy) ** 2 < (r - 1) ** 2:
                d.point((x, y - 1), fill=C("P53"))
                d.point((x, y), fill=C("P09"))
                d.point((x, y + 1), fill=C("P09" if t % 5 else "P08"))
                d.point((x, y + 2), fill=C("P52"))
    elif kind == "count":
        # 출력구(몸 아래 앞쪽) + 늘어진 '재검표' 출력지 띠(컷마다 길이가 조금 변한다)
        d.rectangle([cx + 1, cy + 6, cx + 7, cy + 8], fill=C(INK))
        d.line([cx + 2, cy + 7, cx + 6, cy + 7], fill=C("P02"))
        ln = 6 + [0, 1, 2, 1][frame % 4]
        for k in range(ln):
            y = cy + 8 + k
            x = cx + 3 + (1 if (k // 3) % 2 else 0)
            d.line([x, y, x + 2, y], fill=C("P09"))
            d.point((x + 3, y), fill=C(INK))
            if k % 2 == 0:
                d.point((x + 1, y), fill=C("P04"))                    # 찍힌 글줄
        d.point((cx + 3, cy + 8 + ln), fill=C(INK)); d.point((cx + 5, cy + 8 + ln), fill=C(INK))
    # 앞 눈줄기 둘(가운데 · 앞 — 앞 눈이 크다)
    _eye(d, cx, cy - r, cx + 1, cy - r - 9, 2, blink=frame % 4 == 3)
    _eye(d, cx + 5, cy - r + 2, cx + 11, cy - r - 4, 3, blink=frame % 4 == 3, big=True)
    # 앞 팔과 아래 팔
    if kind == "clerk":
        # 아래 팔: 배급표 펀치(놋쇠 집게 — 걷는 컷엔 접힘, 서 있을 땐 딸깍)
        _arm(d, [(cx + 6, cy + r - 3), (cx + 9, cy + r + 1), (cx + 12, cy + r)])
        bx, by = cx + 12, cy + r - 1
        bite = 1 if (pose == "idle" and frame % 4 == 1) else 0
        d.line([bx, by, bx + 4, by - 1 + bite], fill=C(INK), width=2); d.line([bx, by + 2, bx + 4, by + 3 - bite], fill=C(INK), width=2)
        d.point((bx + 1, by), fill=C("P48")); d.point((bx + 1, by + 2), fill=C("P48")); d.point((bx + 3, by + 1), fill=C("P49"))
        # 앞 팔: 바코드 판독기(회색 손잡이 상자 · 붉은 판독 빛 — 컷마다 깜박)
        tip = (cx + r + 5, cy - 1 - (swing if pose == "walk" else 0))
        _arm(d, [(cx + r - 1, cy), (cx + r + 2, cy + 1), tip])
        px, py = tip
        d.rectangle([px - 1, py - 4, px + 6, py + 2], fill=C(INK))
        d.rectangle([px, py - 3, px + 5, py + 1], fill=C("P06"))
        d.line([px, py + 1, px + 5, py + 1], fill=C("P04"))
        d.point((px + 1, py - 2), fill=C("P08"))
        if frame % 2 == 0:
            d.line([px + 7, py - 2, px + 8, py - 2], fill=C("P53")); d.point((px + 9, py - 2), fill=C("P52"))
        else:
            d.point((px + 6, py - 2), fill=C("P52"))
    elif kind == "clean":
        # 아래 팔: 접은 강당 의자(갈색 좌판 · 쇠 다리 둘 — 몸 옆에 끼고 든다)
        _arm(d, [(cx + 6, cy + r - 3), (cx + 9, cy + r + 1), (cx + 12, cy + r)])
        bx, by = cx + 12, cy + r - 4
        d.rectangle([bx - 1, by - 1, bx + 5, by + 2], fill=C(INK)); d.rectangle([bx, by, bx + 4, by + 1], fill=C("P19"))   # 좌판
        d.line([bx, by + 2, bx - 1, by + 9], fill=C(INK)); d.line([bx + 4, by + 2, bx + 5, by + 9], fill=C(INK))         # 다리
        d.line([bx, by + 3, bx - 1, by + 8], fill=C("P12")); d.line([bx + 4, by + 3, bx + 5, by + 8], fill=C("P12"))
        d.line([bx + 1, by - 3, bx + 3, by - 3], fill=C("P19")); d.point((bx + 2, by - 2), fill=C("P18"))                  # 등받이
        # 앞 팔: 먼지떨이(나무 자루 · 노란 술 — 걷는 컷에 흔들린다)
        tip = (cx + r + 5, cy - 1 - (swing if pose == "walk" else 0))
        _arm(d, [(cx + r - 1, cy), (cx + r + 2, cy + 1), tip])
        px, py = tip
        d.line([px, py, px + 3, py - 7], fill=C(INK), width=2); d.line([px, py, px + 3, py - 7], fill=C("P20"))          # 자루
        sw = swing if pose == "walk" else [0, 0, 1, 0][frame % 4]
        for k, (dx, dy) in enumerate(((-3, -2), (-1, -4), (1, -5), (3, -4), (4, -1))):                                  # 술
            d.line([px + 3, py - 7, px + 3 + dx + sw, py - 7 + dy], fill=C("P49" if k % 2 else "P48"))
        d.point((px + 3, py - 7), fill=C("P47"))
    elif kind == "proxy":
        # 아래 팔: 자습 종(놋쇠 손종 — 걷는 컷에 흔들린다)
        _arm(d, [(cx + 6, cy + r - 3), (cx + 9, cy + r + 1), (cx + 12, cy + r + 1)])
        bx, by = cx + 12, cy + r - 2 + (swing if pose == "walk" else 0)
        d.line([bx, by - 2, bx, by], fill=C("P19"))                    # 나무 손잡이
        d.polygon([(bx - 3, by + 5), (bx + 3, by + 5), (bx + 2, by), (bx - 2, by)], fill=C(INK))
        d.polygon([(bx - 2, by + 4), (bx + 2, by + 4), (bx + 1, by + 1), (bx - 1, by + 1)], fill=C("P48"))
        d.point((bx - 1, by + 2), fill=C("P49")); d.point((bx, by + 6), fill=C("P47"))
        # 앞 팔: 출석부(갈색 판 · 흰 종이 · 놋쇠 집게) — 들여다보듯 비스듬히
        tip = (cx + r + 5, cy - 1 - (swing if pose == "walk" else 0))
        _arm(d, [(cx + r - 1, cy), (cx + r + 2, cy + 1), tip])
        px, py = tip
        d.rectangle([px - 1, py - 8, px + 6, py + 1], fill=C(INK))
        d.rectangle([px, py - 7, px + 5, py], fill=C("P19"))
        d.rectangle([px + 1, py - 6, px + 4, py - 1], fill=C("P09"))
        d.line([px + 2, py - 4, px + 3, py - 4], fill=C("P04")); d.line([px + 2, py - 2, px + 3, py - 2], fill=C("P04"))
        d.line([px + 1, py - 8, px + 4, py - 8], fill=C("P48"))
    elif kind == "ballot":
        # 아래 팔: 작은 투표함(흰 상자 · 투입구 · 붉은 봉인)
        _arm(d, [(cx + 6, cy + r - 3), (cx + 9, cy + r + 2), (cx + 13, cy + r + 3)])
        bx, by = cx + 12, cy + r - 1
        d.rectangle([bx, by, bx + 9, by + 7], fill=C(INK))
        d.rectangle([bx + 1, by + 1, bx + 8, by + 6], fill=C("P09"))
        d.line([bx + 1, by + 6, bx + 8, by + 6], fill=C("P07"))
        d.line([bx + 3, by + 2, bx + 6, by + 2], fill=C(INK))          # 투입구
        d.point((bx + 7, by + 4), fill=C("P53"))                       # 봉인
        # 앞 팔: 투표용지 한 장을 흔든다
        tip = (cx + r + 6, cy - 2 - swing)
        _arm(d, [(cx + r - 1, cy), (cx + r + 3, cy + 1), tip])
        px, py = tip
        d.rectangle([px - 1, py - 6, px + 3, py], fill=C(INK))
        d.rectangle([px, py - 5, px + 2, py - 1], fill=C("P09"))
        d.point((px + 1, py - 3), fill=C("P53"))                       # 기표 도장
    else:
        # 앞 팔: 계수기(놋쇠 상자 · 숫자 창) — 누르는 컷에 엄지 레버가 내려간다
        tip = (cx + r + 5, cy + 2)
        _arm(d, [(cx + r - 1, cy + 1), (cx + r + 2, cy + 3), tip])
        kx, ky = tip
        d.rectangle([kx, ky - 4, kx + 7, ky + 3], fill=C(INK))
        d.rectangle([kx + 1, ky - 3, kx + 6, ky + 2], fill=C("P48"))
        d.line([kx + 1, ky + 2, kx + 6, ky + 2], fill=C("P47"))
        d.rectangle([kx + 2, ky - 2, kx + 5, ky], fill=C("P02"))
        d.point((kx + 3, ky - 1), fill=C("P62")); d.point((kx + 4, ky - 1), fill=C("P62"))
        lev = 1 if frame % 2 else 0
        d.line([kx + 6, ky - 5 + lev, kx + 8, ky - 6 + lev], fill=C(INK))
        # 아래 팔: 접혀 몸에 붙음
        _arm(d, [(cx + 4, cy + r - 2), (cx + 7, cy + r + 2), (cx + 10, cy + r + 1)])
    return im


def _death(frame, kind):
    """0 불꽃 튐(떠 있음) · 1 기울며 떨어짐 · 2 바닥에 닿아 튐 · 3 금 간 채 누움(눈 꺼짐, 띠 · 출력지가 바닥에 흩어짐)."""
    fx, fy = FOOT
    if frame <= 1:
        base = salim(1, "idle", kind)
        out = img()
        drop = [0, 11][frame]
        out.alpha_composite(base.crop((0, 0, FW, fy - 4)), (0, drop))
        d = ImageDraw.Draw(out)
        _shadow(d, fx, fy, 9 + frame)
        for (sx, sy, c) in [(fx + 7, fy - 42, "P50"), (fx - 9, fy - 34, "P60"), (fx + 12, fy - 30, "P63"), (fx - 2, fy - 46, "P50")]:
            d.point((sx, sy + drop), fill=C(c))
            d.point((sx + (1 if frame else -1), sy + drop - 1), fill=C(c))
        return out
    out = img()
    d = ImageDraw.Draw(out)
    cx, cy = fx, fy - 8 - (2 if frame == 2 else 0)
    r = 10
    _shadow(d, fx, fy, 12)
    d.ellipse([cx - r - 1, cy - r, cx + r + 1, cy + r - 1], fill=C(INK))
    d.ellipse([cx - r, cy - r + 1, cx + r, cy + r - 2], fill=C(SILVER[2]))
    d.chord([cx - r, cy - r + 1, cx + r, cy + r - 2], 200, 320, fill=C(SILVER[1]))
    d.line([cx - r + 1, cy + 2, cx + r - 1, cy + 2], fill=C(SILVER[0]))
    if kind == "proxy":
        d.rectangle([cx - 6, cy - 4, cx + 3, cy - 2], fill=C("P44")); d.line([cx - 5, cy - 3, cx + 2, cy - 3], fill=C("P09"))
    elif kind == "clerk":
        d.chord([cx - r, cy - r + 1, cx + r, cy + r - 2], 180, 360, fill=C("P45"))
        d.line([cx - r + 1, cy + 1, cx + r - 1, cy + 1], fill=C("P27"))
    elif kind == "clean":
        d.line([cx - 6, cy - 6, cx + 5, cy - 1], fill=C("P44"), width=2); d.line([cx - 6, cy - 7, cx + 5, cy - 2], fill=C("P49"))   # 풀린 리본
    else:
        _digit(d, cx - 6, cy - 5, 2 if kind == "ballot" else 4)
    d.line([cx - 3, cy - 8, cx, cy - 3], fill=C(INK)); d.line([cx, cy - 3, cx - 2, cy + 1], fill=C(INK))   # 금
    for (ex, ey) in ((cx + 9, cy - 10), (cx + 13, cy - 6)):            # 꺾인 눈줄기 · 꺼진 렌즈
        d.line([cx + 4, cy - 7, ex, ey], fill=C(INK), width=2)
        d.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=C("P02"))
    if kind == "ballot":
        d.rectangle([cx - 18, cy + 3, cx - 10, cy + 8], fill=C(INK)); d.rectangle([cx - 17, cy + 4, cx - 11, cy + 7], fill=C("P09"))   # 굴러간 투표함
        d.point((cx - 12, cy + 5), fill=C("P53"))
        d.line([cx + 12, cy + 7, cx + 18, cy + 8], fill=C("P09")); d.point((cx + 15, cy + 7), fill=C("P53"))   # 흩어진 용지
    elif kind == "clerk":
        d.rectangle([cx - 17, cy + 3, cx - 11, cy + 8], fill=C(INK)); d.rectangle([cx - 16, cy + 4, cx - 12, cy + 7], fill=C("P06"))   # 떨어진 판독기
        for k in range(3):                                             # 흩어진 영수증
            d.line([cx + 10 + k * 3, cy + 6 + (k % 2), cx + 11 + k * 3, cy + 6 + (k % 2)], fill=C("P09"))
    elif kind == "clean":
        d.line([cx - 19, cy + 7, cx - 11, cy + 4], fill=C(INK), width=2); d.line([cx - 19, cy + 7, cx - 11, cy + 4], fill=C("P20"))   # 떨어진 먼지떨이
        for k, (dx, dy) in enumerate(((-2, -1), (0, -3), (2, -2), (3, 1))):
            d.line([cx - 11, cy + 4, cx - 11 + dx, cy + 4 + dy], fill=C("P49" if k % 2 else "P48"))
        d.rectangle([cx + 10, cy + 5, cx + 17, cy + 7], fill=C(INK)); d.rectangle([cx + 11, cy + 6, cx + 16, cy + 6], fill=C("P19"))   # 넘어진 의자
        d.line([cx + 12, cy + 8, cx + 12, cy + 10], fill=C("P12")); d.line([cx + 16, cy + 8, cx + 17, cy + 10], fill=C("P12"))
    elif kind == "proxy":
        d.rectangle([cx - 18, cy + 2, cx - 11, cy + 8], fill=C(INK)); d.rectangle([cx - 17, cy + 3, cx - 12, cy + 7], fill=C("P19"))   # 떨어진 출석부
        d.rectangle([cx - 16, cy + 4, cx - 13, cy + 6], fill=C("P09"))
        d.polygon([(cx + 12, cy + 8), (cx + 17, cy + 8), (cx + 16, cy + 4), (cx + 13, cy + 4)], fill=C("P48"))   # 굴러간 종
    else:
        for k in range(12):                                            # 바닥에 풀린 출력지
            d.point((cx + 8 + k, cy + 7 + (k % 3 == 0)), fill=C("P09"))
        d.rectangle([cx - 17, cy + 2, cx - 11, cy + 7], fill=C(INK)); d.rectangle([cx - 16, cy + 3, cx - 12, cy + 6], fill=C("P48"))   # 계수기
    if frame == 2:
        d.point((cx - 10, cy - 10), fill=C("P50")); d.point((cx + 11, cy - 11), fill=C("P60"))
    else:
        d.point((cx - 5, cy - r - 2), fill=C("P05")); d.point((cx - 4, cy - r - 4), fill=C("P04"))   # 연기 한 올
    return out


def salim_sheet(kind="ballot"):
    """시트 프레임 목록과 메타(robots.salpim_sheet와 같은 형식): idle 4 · walk 4 · death 4."""
    frames = [salim(i, "idle", kind) for i in range(4)] + [salim(i, "walk", kind) for i in range(4)] + \
             [salim(i, "death", kind) for i in range(4)]
    meta = {"frame": [FW, FH], "foot": list(FOOT), "dirs": ["E"],
            "motions": {"idle": {"start": 0, "count": 4}, "walk": {"start": 4, "count": 4}, "death": {"start": 8, "count": 4}},
            "hover": True}
    return frames, meta


def salim_portrait(emo="기본", kind="ballot"):
    """대화 초상화(96×96, 투명 바탕): 은색 구체를 가까이서 — 눈줄기 셋 · 옆면 숫자 · 2호는 선거 띠, 4호는 계수기와 출력지.
    표정은 앞 렌즈 하나로(살핌-1과 같은 말법): 기본 점 · 말함 깜박 줄 · 놀람 고리 · 미소 반달 · 슬픔 처짐 · 분노 붉은 점 · 아픔 금 · 피곤 반쯤 닫힘."""
    im = img(96, 96)
    d = ImageDraw.Draw(im)
    cx, cy, r = 44, 56, 28
    # 뒤 · 가운데 눈줄기(몸 뒤)
    for (x0, y0, x1, y1, rr) in ((cx - 10, cy - r + 4, cx - 22, cy - r - 14, 5), (cx, cy - r, cx + 2, cy - r - 18, 5)):
        d.line([x0, y0, x1, y1], fill=C(INK), width=4); d.line([x0, y0, x1, y1], fill=C("P05"), width=2)
        d.ellipse([x1 - rr - 2, y1 - rr - 2, x1 + rr + 2, y1 + rr + 2], fill=C(INK)); d.ellipse([x1 - rr, y1 - rr, x1 + rr, y1 + rr], fill=C("P02"))
        d.ellipse([x1 - 2, y1 - 2, x1 + 2, y1 + 2], fill=C("P62"))
    d.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], fill=C(INK))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C(SILVER[1]))
    d.ellipse([cx - r, cy - r, cx + r - 6, cy + r - 6], fill=C(SILVER[2]))
    d.ellipse([cx - r + 6, cy - r + 6, cx - 4, cy - 4], fill=C(SILVER[3]))
    d.ellipse([cx - r + 10, cy - r + 10, cx - r + 15, cy - r + 15], fill=C(SILVER[4]))
    d.arc([cx - r, cy - r, cx + r, cy + r], 30, 120, fill=C(SILVER[0]), width=2)
    d.line([cx - r + 3, cy + 8, cx + r - 3, cy + 8], fill=C(SILVER[0]), width=2)
    for x in range(cx - r + 6, cx + r - 4, 8):
        d.rectangle([x, cy + 10, x + 1, cy + 11], fill=C("P09"))
    if kind == "clerk":                                                 # 번개24 제복 도장(위 반구 하늘청 · 주황 띠 · 흰 명찰)
        for y in range(cy - r + 2, cy + 7):
            for x in range(cx - r + 2, cx + r - 1):
                if (x - cx) ** 2 + (y - cy) ** 2 < (r - 1) ** 2:
                    lit = (x - cx) + (y - cy) < -r * 0.6
                    shade = (x - cx) > r * 0.45 or (x - cx) + (y - cy) > r * 0.3
                    d.point((x, y), fill=C("P46" if lit else ("P44" if shade else "P45")))
        d.ellipse([cx - r + 10, cy - r + 10, cx - r + 14, cy - r + 14], fill=C("P09"))
        d.line([cx - r + 2, cy + 7, cx + r - 2, cy + 7], fill=C("P27"), width=3); d.line([cx - r + 3, cy + 9, cx + r - 3, cy + 9], fill=C("P26"))
        d.line([cx - 4, cy + 5, cx, cy + 9], fill=C("P09"), width=2); d.line([cx, cy + 9, cx + 3, cy + 5], fill=C("P09"), width=2)
        d.rectangle([cx - 22, cy - 12, cx - 6, cy - 2], fill=C(INK)); d.rectangle([cx - 20, cy - 10, cx - 8, cy - 4], fill=C("P09"))
        d.line([cx - 18, cy - 9, cx - 15, cy - 9], fill=C(INK)); d.line([cx - 15, cy - 9, cx - 15, cy - 7], fill=C(INK)); d.line([cx - 15, cy - 7, cx - 18, cy - 5], fill=C(INK)); d.line([cx - 18, cy - 5, cx - 15, cy - 5], fill=C(INK))
        d.line([cx - 13, cy - 9, cx - 13, cy - 7], fill=C(INK)); d.line([cx - 13, cy - 7, cx - 10, cy - 7], fill=C(INK)); d.line([cx - 11, cy - 9, cx - 11, cy - 5], fill=C(INK))
    n = 2 if kind == "ballot" else 4                                    # 옆면 숫자(굵은 붓)
    col = C("P53")
    ox, oy = (cx - 18, cy + 13) if n == 2 else (cx - 20, cy - 16)       # 2호는 띠 아래
    if kind == "clerk":
        pass
    elif kind == "clean":                                                 # 졸업 리본 띠(남색 · 금 가장자리) — 숫자 없음
        for t in range(-r + 4, r - 3):
            x = cx + t; y = cy - 4 + t // 2
            if (x - cx) ** 2 + (y - cy) ** 2 < (r - 2) ** 2:
                d.line([x, y - 3, x, y - 2], fill=C("P49")); d.line([x, y - 1, x, y + 3], fill=C("P44")); d.line([x, y + 4, x, y + 5], fill=C("P49"))
        d.rectangle([cx - 3, cy - 2, cx - 1, cy], fill=C("P50")); d.rectangle([cx + 3, cy - 1, cx + 5, cy + 1], fill=C("P50"))
    elif kind == "proxy":                                                 # 남색 명찰 띠 '원장 대행'
        d.rectangle([cx - 20, cy - 8, cx + 10, cy + 4], fill=C(INK)); d.rectangle([cx - 18, cy - 6, cx + 8, cy + 2], fill=C("P44"))
        d.line([cx - 18, cy + 2, cx + 8, cy + 2], fill=C("P43"))
        for k, x in enumerate(range(cx - 15, cx + 6, 5)):              # 흰 획 넷(글자 넷의 자리)
            d.rectangle([x, cy - 4, x + 2 + (k % 2), cy - 1], fill=C("P09"))
    elif n == 2:
        d.line([ox, oy, ox + 8, oy], fill=col, width=3); d.line([ox + 8, oy, ox + 8, oy + 6], fill=col, width=3)
        d.line([ox + 8, oy + 6, ox, oy + 6], fill=col, width=3); d.line([ox, oy + 6, ox, oy + 12], fill=col, width=3); d.line([ox, oy + 12, ox + 9, oy + 12], fill=col, width=3)
    else:
        d.line([ox, oy, ox, oy + 7], fill=col, width=3); d.line([ox, oy + 7, ox + 10, oy + 7], fill=col, width=3); d.line([ox + 7, oy, ox + 7, oy + 13], fill=col, width=3)
    if kind == "clean":                                                 # 먼지떨이(앞 팔 자리 — 초상 아래 오른쪽)
        d.line([cx + 14, cy + 30, cx + 30, cy + 6], fill=C(INK), width=4); d.line([cx + 14, cy + 30, cx + 30, cy + 6], fill=C("P20"), width=2)
        for k, (dx, dy) in enumerate(((-8, -4), (-4, -10), (2, -12), (8, -9), (11, -3))):
            d.line([cx + 30, cy + 6, cx + 30 + dx, cy + 6 + dy], fill=C("P49" if k % 2 else "P48"), width=2)
    if kind == "ballot":                                                # 선거 띠
        for t in range(-r + 4, r - 3):
            x = cx + t; y = cy - 4 + t // 2
            if (x - cx) ** 2 + (y - cy) ** 2 < (r - 2) ** 2:
                d.line([x, y - 3, x, y - 2], fill=C("P53")); d.line([x, y - 1, x, y + 3], fill=C("P09")); d.line([x, y + 4, x, y + 5], fill=C("P52"))
    elif kind == "count":                                               # 출력구 + 늘어진 출력지
        d.rectangle([cx + 2, cy + 16, cx + 18, cy + 21], fill=C(INK)); d.line([cx + 4, cy + 18, cx + 16, cy + 18], fill=C("P02"))
        d.rectangle([cx + 6, cy + 21, cx + 14, cy + 40], fill=C(INK)); d.rectangle([cx + 7, cy + 21, cx + 13, cy + 40], fill=C("P09"))
        for k in range(23, 40, 3):
            d.line([cx + 8, cy + k, cx + 12 - (k % 2), cy + k], fill=C("P04"))
    ex, ey = cx + 24, cy - r - 4                                        # 앞 눈줄기와 렌즈
    d.line([cx + 12, cy - r + 6, ex, ey], fill=C(INK), width=4); d.line([cx + 12, cy - r + 6, ex, ey], fill=C("P05"), width=2)
    d.ellipse([ex - 13, ey - 13, ex + 13, ey + 13], fill=C(INK))
    d.ellipse([ex - 11, ey - 11, ex + 11, ey + 11], fill=C("P02"))
    eye = C("P62"); hi = C("P63")
    if emo == "놀람":
        d.ellipse([ex - 8, ey - 8, ex + 8, ey + 8], outline=eye, width=2); d.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=hi)
    elif emo == "미소":
        d.arc([ex - 7, ey - 6, ex + 7, ey + 6], 200, 340, fill=eye, width=3)
    elif emo == "슬픔":
        d.line([ex - 8, ey - 1, ex + 2, ey - 5], fill=C("P45"), width=3); d.ellipse([ex - 3, ey + 2, ex + 3, ey + 6], fill=C("P45"))
    elif emo == "분노":
        d.ellipse([ex - 5, ey - 5, ex + 5, ey + 5], fill=C("P53")); d.line([ex - 9, ey - 9, ex + 3, ey - 5], fill=C("P53"), width=2)
    elif emo == "아픔":
        d.ellipse([ex - 4, ey - 4, ex + 4, ey + 4], fill=C("P59"))
        d.line([ex - 10, ey - 6, ex - 2, ey + 2], fill=C("P07")); d.line([ex - 2, ey + 2, ex + 4, ey + 10], fill=C("P07"))
    elif emo == "피곤":
        d.rectangle([ex - 7, ey, ex + 7, ey + 4], fill=eye); d.rectangle([ex - 11, ey - 11, ex + 11, ey - 1], fill=C(SILVER[2]))
    elif emo == "말함":
        for k in (-4, 0, 4):
            d.line([ex - 7, ey + k, ex + 7, ey + k], fill=eye)
    else:
        d.ellipse([ex - 5, ey - 5, ex + 5, ey + 5], fill=eye); d.rectangle([ex - 1, ey - 4, ex + 1, ey - 2], fill=hi)
    d.point((ex - 7, ey - 7), fill=C("P08")); d.point((ex - 6, ey - 8), fill=C("P08"))
    if kind == "clerk":                                                 # 앞 팔 바코드 판독기(붉은 빛)
        d.line([cx + r - 2, cy + 2, cx + r + 6, cy + 4], fill=C(INK), width=5); d.line([cx + r - 2, cy + 2, cx + r + 6, cy + 4], fill=C("P05"), width=3)
        kx, ky = cx + r + 2, cy - 6
        d.rectangle([kx, ky, kx + 18, ky + 14], fill=C(INK)); d.rectangle([kx + 2, ky + 2, kx + 16, ky + 12], fill=C("P06"))
        d.line([kx + 2, ky + 12, kx + 16, ky + 12], fill=C("P04"), width=2); d.rectangle([kx + 3, ky + 3, kx + 6, ky + 5], fill=C("P08"))
        d.line([kx + 19, ky + 4, kx + 22, ky + 4], fill=C("P53"), width=2)
    elif kind == "proxy":                                                 # 아래 팔 자습 종 · 앞 팔 출석부
        d.line([cx + 18, cy + r - 8, cx + 28, cy + r + 2], fill=C(INK), width=5); d.line([cx + 18, cy + r - 8, cx + 28, cy + r + 2], fill=C("P05"), width=3)
        bx, by = cx + 30, cy + r
        d.rectangle([bx - 2, by - 6, bx + 2, by], fill=C(INK)); d.rectangle([bx - 1, by - 5, bx + 1, by], fill=C("P19"))
        d.polygon([(bx - 10, by + 14), (bx + 10, by + 14), (bx + 6, by), (bx - 6, by)], fill=C(INK))
        d.polygon([(bx - 8, by + 12), (bx + 8, by + 12), (bx + 5, by + 2), (bx - 5, by + 2)], fill=C("P48"))
        d.line([bx - 4, by + 4, bx - 6, by + 10], fill=C("P49"), width=2); d.line([bx - 8, by + 12, bx + 8, by + 12], fill=C("P47"), width=2)
        d.ellipse([bx - 2, by + 13, bx + 2, by + 17], fill=C(INK))
        d.line([cx + r - 2, cy + 2, cx + r + 6, cy + 4], fill=C(INK), width=5); d.line([cx + r - 2, cy + 2, cx + r + 6, cy + 4], fill=C("P05"), width=3)
        kx, ky = cx + r + 2, cy - 14
        d.rectangle([kx, ky, kx + 20, ky + 26], fill=C(INK)); d.rectangle([kx + 2, ky + 2, kx + 18, ky + 24], fill=C("P19"))
        d.rectangle([kx + 4, ky + 5, kx + 16, ky + 22], fill=C("P09"))
        for k in range(8, 22, 3):
            d.line([kx + 6, ky + k, kx + 14 - (k % 2) * 2, ky + k], fill=C("P04"))
        d.rectangle([kx + 6, ky, kx + 14, ky + 4], fill=C(INK)); d.rectangle([kx + 7, ky + 1, kx + 13, ky + 3], fill=C("P48"))
    elif kind == "ballot":                                                # 아래 팔이 든 투표함
        d.line([cx + 18, cy + r - 8, cx + 30, cy + r + 2], fill=C(INK), width=5); d.line([cx + 18, cy + r - 8, cx + 30, cy + r + 2], fill=C("P05"), width=3)
        d.rectangle([cx + 26, cy + r - 4, cx + 50, cy + r + 14], fill=C(INK)); d.rectangle([cx + 28, cy + r - 2, cx + 48, cy + r + 12], fill=C("P09"))
        d.line([cx + 28, cy + r + 12, cx + 48, cy + r + 12], fill=C("P07"), width=2)
        d.line([cx + 33, cy + r + 1, cx + 43, cy + r + 1], fill=C(INK), width=2)
        d.ellipse([cx + 42, cy + r + 5, cx + 46, cy + r + 9], fill=C("P53"))
    else:                                                               # 앞 팔 끝 계수기
        d.line([cx + r - 2, cy + 2, cx + r + 8, cy + 8], fill=C(INK), width=5); d.line([cx + r - 2, cy + 2, cx + r + 8, cy + 8], fill=C("P05"), width=3)
        kx, ky = cx + r + 6, cy - 2
        d.rectangle([kx, ky, kx + 18, ky + 18], fill=C(INK)); d.rectangle([kx + 2, ky + 2, kx + 16, ky + 16], fill=C("P48"))
        d.line([kx + 2, ky + 16, kx + 16, ky + 16], fill=C("P47"), width=2)
        d.rectangle([kx + 4, ky + 5, kx + 14, ky + 11], fill=C("P02"))
        for i in range(3):
            d.rectangle([kx + 5 + i * 3, ky + 7, kx + 6 + i * 3, ky + 9], fill=C("P62"))
    return im


def check_palette():
    ok = P.allowed_set("UI")
    bad = set()
    for kind in ("ballot", "count", "proxy", "clerk"):
        for f in salim_sheet(kind)[0] + [salim_portrait(e, kind) for e in ("기본", "놀람", "미소", "슬픔", "분노", "아픔", "피곤", "말함")]:
            for px in f.get_flattened_data():
                if px[3] and tuple(px[:3]) not in ok:
                    bad.add("#%02X%02X%02X" % px[:3])
    return bad


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/salim.png"
    rows = []
    for kind in ("ballot", "count", "proxy", "clerk"):
        fr, _ = salim_sheet(kind)
        rows.append(fr)
    sheet = Image.new("RGBA", (FW * 12, FH * 4 + 100), (70, 66, 74, 255))
    for j, fr in enumerate(rows):
        for i, f in enumerate(fr):
            sheet.alpha_composite(f, (i * FW, j * FH))
    for i, (kind, emo) in enumerate([(k, e) for k in ("clerk",) for e in ("기본", "말함", "놀람", "분노", "미소", "피곤")]):
        sheet.alpha_composite(salim_portrait(emo, kind), (i * 98, FH * 4 + 2))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(out)
    print("팔레트 밖:", sorted(check_palette()) or "없음")
