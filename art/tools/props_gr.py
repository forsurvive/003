"""구로 차량기지 소품(단계 1-D4, 1-D 계획 §10 · SD-09a L-R02-25 · SD-14 CR-205 · SD-16 아이작풍).
  loco_atomic     2077 원자력 기관차(10×3): 운전실 · 보닛 · 노심 칸 유리 돔 / 상태 idle(대기 출력 초록) · open(운전실 문) · sb(새벽인력 장부 번호)
  commute_car1    1호선 통근 전동차(8×2): 남색 띠 / 상태 open(떠돌이가 사는 칸 — 불빛 · 가림막 · 깡통 화분)
  boxcar_gr       유개 화차(6×2): 붉은 녹 판자 · 미닫이 / 상태 open
  flatcar_gr      무개차(4×2): 낮은 철판 · 묶인 상자 · 쐐기 / 상태 pushed(밀려난 자국)
  inspect_car     궤도 검측차(6×2): 노랑 · 사선 띠 · 경광등 / 상태 open(검측 일지 · 열쇠 고리)
  switch_lever    수동 전철기 레버(1×1) / 상태 thrown · crossing_gr 건널목 경보기(1×1) / 상태 ring
  rail_run · rail_run2  선로 넉 칸 덧그림 · boots_rows 벗어 둔 군화 줄(덧그림) / 상태 gap(빈자리)
  coach_seat      객차 좌석 한 쌍(2×1): 개켜 둔 군복 / 상태 empty · sat(철모)
  lost_box        분실물함(1×1): 정기권 지갑 / 상태 open · w_switch_chart 전철기 표(벽 2칸) · w_shutter_gr 선로 끝 셔터(벽 3칸) / 상태 open
  coach_gr        2077 객차 1량(8×2 발): 국방색 · 노란 띠 · 창 줄 · 출입문 둘(양 끝) · 지붕 환기 · 연결 통로 고무 주름
                  상태 open(끝 문 열림 — 들어가는 객차) · mob(창에 '동원 수송 — 제3 예비군 수송 열차' 표지 · 창마다 군모 그림자)
                  · ladder(끝에 지붕 사다리 — 넘어가는 자리) · rust(창이 깨지고 녹이 흘러내린 오래된 객차)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01). 위에서 빛(위 밝게 · 아래 어둡게), 반투명 없음."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
OLIVE = ("P28", "P29", "P30", "P31", "P32")     # 국방색(어둠 → 빛)
BAND = ("P47", "P48", "P49")                     # 노란 띠(군 수송 표식)


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def coach_gr(state=""):
    """2077 객차 1량(8×2 발, 260×88): 위에서 내려다본 옆모습 — 둥근 국방색 지붕(환기 돌기 넷) · 몸통 · 노란 띠 · 창 열 · 양 끝 출입문 ·
    끝마다 연결 통로 고무 주름 · 바퀴 그늘(대차 둘). 상태 open = 오른끝 문이 열려 안이 어둡다(들어가는 칸) · mob = 창에 '동원 수송' 표지와
    군모 그림자 · ladder = 왼끝에 지붕 사다리 · rust = 깨진 창 · 녹물 · 띠가 벗겨진 오래된 칸."""
    rnd = random.Random(5101 + len(state))
    W_, H_ = 260, 88
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    body = OLIVE
    d.rounded_rectangle([6, 8, 253, 76], 8, fill=C(INK))
    d.rounded_rectangle([7, 9, 252, 75], 7, fill=C(body[2]))                                 # 몸통
    d.rounded_rectangle([7, 9, 252, 26], 7, fill=C(body[3]))                                 # 지붕(위 빛)
    d.line([14, 10, 246, 10], fill=C(body[4]))
    for x in (36, 92, 148, 204):                                                              # 지붕 환기 돌기
        d.rounded_rectangle([x, 12, x + 16, 20], 3, fill=C(body[1])); d.line([x + 1, 12, x + 15, 12], fill=C(body[3]))
        for xx in range(x + 3, x + 14, 3):
            d.line([xx, 14, xx, 18], fill=C(body[0]))
    d.line([7, 27, 252, 27], fill=C(body[0]))                                                 # 지붕 · 옆판 이음
    band = BAND if state != "rust" else ("P24", "P25", "P26")
    d.rectangle([7, 52, 252, 57], fill=C(band[1])); d.line([7, 52, 252, 52], fill=C(band[2])); d.line([7, 57, 252, 57], fill=C(band[0]))
    for x in (0, 254):                                                                        # 연결 통로 고무 주름(양 끝)
        d.rectangle([x, 30, x + 5, 66], fill=C(INK))
        for y in range(31, 66, 3):
            d.line([x + 1, y, x + 4, y], fill=C("P03"))
    doors = [(14, False), (226, state == "open")]
    for x, open_ in doors:                                                                    # 양 끝 출입문(여닫이)
        d.rectangle([x, 30, x + 18, 73], fill=C(INK))
        if open_:
            d.rectangle([x + 1, 31, x + 17, 72], fill=C("P02"))
            d.rectangle([x + 13, 31, x + 17, 72], fill=C(body[1]))                            # 젖혀진 문짝
            d.line([x + 3, 66, x + 11, 66], fill=C("P04"))                                    # 발판 끝
        else:
            d.rectangle([x + 1, 31, x + 17, 72], fill=C(body[1]))
            d.rectangle([x + 4, 34, x + 14, 46], fill=C("P10")); d.line([x + 5, 35, x + 8, 41], fill=C("P12"))
            d.point((x + 15, 56), fill=C("P08"))                                              # 손잡이
        d.rectangle([x + 2, 73, x + 16, 76], fill=C("P04"))                                   # 발판
    for i, x in enumerate(range(40, 220, 18)):                                                # 창 열
        broken = state == "rust" and i % 3 == 1
        d.rounded_rectangle([x, 32, x + 13, 47], 2, fill=C(INK))
        d.rounded_rectangle([x + 1, 33, x + 12, 46], 2, fill=C("P02" if broken or i % 4 == 2 else "P10"))
        if broken:
            d.line([x + 2, 34, x + 6, 40], fill=C("P12")); d.line([x + 6, 40, x + 4, 45], fill=C("P12"))
        elif i % 4 != 2:
            d.line([x + 2, 34, x + 6, 40], fill=C("P12"))
        if state == "mob" and i % 2 == 0 and not broken:                                      # 군모 그림자(누군가 앉아 있던 자리 — 지금은 모자만)
            d.rectangle([x + 3, 41, x + 10, 43], fill=C(OLIVE[0])); d.line([x + 2, 43, x + 11, 43], fill=C(OLIVE[0]))
    if state == "mob":                                                                        # 창에 붙인 표지
        d.rectangle([96, 58, 168, 72], fill=C(INK)); d.rectangle([97, 59, 167, 71], fill=C("P09"))
        put_text(im, "동원 수송", 104, 60, "P52", 8, "Galmuri7")
        d.line([100, 69, 164, 69], fill=C("P05"))
    else:
        put_text(im, "군용 객차", 104, 59, body[4], 8, "Galmuri7")
    if state == "ladder":                                                                     # 왼끝 지붕 사다리
        for x in (38, 46):
            d.line([x, 12, x, 74], fill=C(INK), width=2); d.line([x, 12, x, 74], fill=C("P06"))
        for y in range(16, 74, 6):
            d.line([38, y, 46, y], fill=C("P07"))
    for x in (34, 62, 188, 216):                                                              # 바퀴 그늘(대차 둘)
        d.rectangle([x, 76, x + 18, 82], fill=C(INK)); d.ellipse([x + 1, 77, x + 7, 83], fill=C("P03")); d.ellipse([x + 11, 77, x + 17, 83], fill=C("P03"))
    if state == "rust":                                                                       # 녹 얼룩(오래 선 칸 — 가장자리가 고르지 않은 얼룩 + 아래로 흐른 녹물)
        ok = (P.rgb(body[1]), P.rgb(body[2]), P.rgb(body[3]))
        for _ in range(8):
            cx, cy = rnd.randint(20, 240), rnd.randint(14, 64)
            for _k in range(70):
                xx, yy = cx + int(rnd.gauss(0, 5)), cy + int(rnd.gauss(0, 2.5))
                if 0 <= xx < W_ and 0 <= yy < H_ and im.getpixel((xx, yy))[3] and im.getpixel((xx, yy))[:3] in ok:
                    im.putpixel((xx, yy), C(rnd.choice(["P25", "P25", "P24", "P26"])))
            for _k in range(3):                                                               # 흘러내린 녹물
                xx, y0 = cx + rnd.randint(-6, 6), cy + 2
                for yy in range(y0, min(74, y0 + rnd.randint(4, 14))):
                    if im.getpixel((xx, yy))[:3] in ok:
                        im.putpixel((xx, yy), C("P24" if yy % 2 else "P25"))
    for x in range(8, 252, 9):                                                                # 리벳 줄(옆판 위 · 아래)
        d.point((x, 29), fill=C(body[0])); d.point((x, 70), fill=C(body[0]))
    for _ in range(140 if state == "rust" else 90):                                           # 때 · 녹 · 먼지(아래로 갈수록)
        x, y = rnd.randint(10, 248), rnd.randint(28, 74)
        if im.getpixel((x, y))[3] and im.getpixel((x, y))[:3] in (P.rgb(body[2]), P.rgb(body[1])):
            im.putpixel((x, y), C(rnd.choice(["P25", "P24", body[1]] if y > 58 else [body[1], body[3]])))
    for x in range(12, 248, 6):                                                               # 아래 끝 녹물 줄
        if rnd.random() < (0.6 if state == "rust" else 0.35):
            d.line([x, 72, x, 72 + rnd.randint(1, 5)], fill=C("P25"))
    _shadow(d, 8, 252, 84)
    return im


def loco_atomic(state=""):
    """2077 원자력 기관차(10×3 발, 330×120): 위에서 내려다본 옆모습 — 왼끝 운전실(둥근 앞창 · 전조등) · 긴 보닛(국방색 · 노란 띠) ·
    가운데 노심 칸(둥근 유리 돔 · 냉각 지느러미 · 방사능 표지 · 손잡이 해치) · 오른끝 연결기 · 대차 셋. 상태 idle = 대기 출력(돔 안 초록빛 ·
    표시등 초록 · 전조등 희미) · open = 운전실 문이 열림(기관사 유해가 기대앉은 그림자)."""
    rnd = random.Random(6202 + len(state))
    W_, H_ = 330, 120
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    _shadow(d, 10, 322, 112)
    for x in (40, 150, 262):                                                                  # 대차 셋
        d.rectangle([x, 100, x + 30, 108], fill=C(INK))
        for k in (0, 1, 2):
            d.ellipse([x + 1 + k * 10, 101, x + 9 + k * 10, 109], fill=C("P03")); d.point((x + 5 + k * 10, 105), fill=C("P05"))
    d.rounded_rectangle([8, 22, 322, 102], 10, fill=C(INK))
    d.rounded_rectangle([9, 23, 321, 101], 9, fill=C(OLIVE[2]))                               # 몸통
    d.rounded_rectangle([9, 23, 321, 44], 9, fill=C(OLIVE[3]))                                # 지붕 빛
    d.line([18, 24, 312, 24], fill=C(OLIVE[4]))
    d.rectangle([9, 78, 321, 85], fill=C(BAND[1])); d.line([9, 78, 321, 78], fill=C(BAND[2])); d.line([9, 85, 321, 85], fill=C(BAND[0]))
    for x in range(14, 318, 8):                                                               # 리벳
        d.point((x, 46), fill=C(OLIVE[0])); d.point((x, 96), fill=C(OLIVE[0]))
    # 운전실(왼끝)
    d.rounded_rectangle([8, 14, 74, 102], 12, fill=C(INK))
    d.rounded_rectangle([9, 15, 73, 101], 11, fill=C(OLIVE[1]))
    d.rounded_rectangle([9, 15, 73, 34], 11, fill=C(OLIVE[2]))
    d.rounded_rectangle([14, 38, 46, 60], 6, fill=C(INK)); d.rounded_rectangle([15, 39, 45, 59], 5, fill=C("P10"))   # 앞창
    d.line([17, 41, 26, 54], fill=C("P12")); d.line([22, 41, 30, 52], fill=C("P12"))
    lamp = "P50" if state == "idle" else "P05"
    d.ellipse([10, 66, 20, 76], fill=C(INK)); d.ellipse([11, 67, 19, 75], fill=C(lamp))      # 전조등
    if state == "idle":
        d.point((13, 69), fill=C("P09"))
    door_open = state == "open"
    d.rectangle([52, 38, 68, 96], fill=C(INK))                                                # 운전실 문
    if door_open:
        d.rectangle([53, 39, 67, 95], fill=C("P02"))
        d.ellipse([56, 54, 63, 61], fill=C("P05")); d.rectangle([55, 61, 64, 80], fill=C(OLIVE[0]))   # 기대앉은 사람 그림자(모자 · 어깨)
        d.line([55, 61, 64, 61], fill=C(OLIVE[1]))
    else:
        d.rectangle([53, 39, 67, 95], fill=C(OLIVE[1])); d.rectangle([56, 42, 64, 54], fill=C("P10"))
        d.point((65, 70), fill=C("P08"))
    # 노심 칸(가운데)
    cx0, cx1 = 130, 214
    d.rectangle([cx0, 26, cx1, 98], fill=C(INK)); d.rectangle([cx0 + 1, 27, cx1 - 1, 97], fill=C("P05"))
    for x in range(cx0 + 4, cx1 - 2, 5):                                                      # 냉각 지느러미
        d.line([x, 30, x, 94], fill=C("P04")); d.line([x + 1, 30, x + 1, 94], fill=C("P07"))
    dome = "P56" if state == "idle" else "P11"
    d.ellipse([cx0 + 18, 20, cx1 - 18, 66], fill=C(INK)); d.ellipse([cx0 + 20, 22, cx1 - 20, 64], fill=C(dome))     # 유리 돔
    if state == "idle":
        d.ellipse([cx0 + 30, 30, cx1 - 30, 56], fill=C("P57")); d.ellipse([cx0 + 37, 37, cx1 - 37, 49], fill=C("P09"))
    else:
        d.ellipse([cx0 + 30, 30, cx1 - 30, 56], fill=C("P12")); d.line([cx0 + 26, 30, cx0 + 34, 26], fill=C("P15"))
    d.ellipse([cx0 + 32, 70, cx0 + 52, 90], fill=C(BAND[1])); d.ellipse([cx0 + 39, 77, cx0 + 45, 83], fill=C(INK))   # 방사능 표지
    for a in (0, 120, 240):
        import math
        r0, r1 = 4, 9
        aa = math.radians(a - 90)
        d.pieslice([cx0 + 42 - r1, 80 - r1, cx0 + 42 + r1, 80 + r1], a - 120, a - 60, fill=C(INK))
    d.ellipse([cx0 + 40, 78, cx0 + 44, 82], fill=C(BAND[1])); d.point((cx0 + 42, 80), fill=C(INK))
    d.rectangle([cx1 - 26, 72, cx1 - 8, 90], fill=C(INK)); d.rectangle([cx1 - 25, 73, cx1 - 9, 89], fill=C("P06"))   # 해치
    d.line([cx1 - 22, 81, cx1 - 12, 81], fill=C("P08"))
    # 표시등 줄(운전실 뒤)
    for i, x in enumerate(range(84, 122, 9)):
        on = state == "idle" and i < 3
        d.rectangle([x, 52, x + 5, 57], fill=C(INK)); d.rectangle([x + 1, 53, x + 4, 56], fill=C("P56" if on else "P03"))
    put_text(im, "원자력", 236, 54, OLIVE[4], 8, "Galmuri7")
    if state == "sb":                                                                         # 새벽인력 측량조가 칠한 장부 번호(흰 페인트 · 흘러내림)
        d.rectangle([228, 64, 300, 76], fill=C("P09"))
        put_text(im, "SB-0417", 232, 65, "P52", 8, "Galmuri7")
        for x in (236, 252, 284):
            d.line([x, 76, x, 80], fill=C("P09"))
    put_text(im, "7703", 280, 54, OLIVE[4], 8, "Galmuri7")
    d.rectangle([318, 56, 329, 70], fill=C(INK)); d.rectangle([319, 57, 328, 69], fill=C("P05"))   # 연결기
    for _ in range(110):
        x, y = rnd.randint(12, 318), rnd.randint(44, 96)
        if im.getpixel((x, y))[3] and im.getpixel((x, y))[:3] in (P.rgb(OLIVE[2]), P.rgb(OLIVE[1])):
            im.putpixel((x, y), C(rnd.choice(["P25", OLIVE[1], OLIVE[3]])))
    for x in range(14, 316, 6):
        if rnd.random() < 0.35:
            d.line([x, 96, x, 96 + rnd.randint(1, 5)], fill=C("P25"))
    return im


def commute_car1(state=""):
    """1호선 통근 전동차 1량(8×2 발, 260×88): 스테인리스 몸통 · 남색 띠(1호선) · 문 넷 · 창 · 지붕 냉방기. 상태 open = 셋째 문이 열려
    안에 불빛(떠돌이가 사는 칸 — 창 하나에 천 가림막 · 문턱에 깡통 화분)."""
    rnd = random.Random(7303 + len(state))
    W_, H_ = 260, 88
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    NAVY = ("P43", "P44", "P45")
    d.rounded_rectangle([4, 8, 255, 76], 10, fill=C(INK))
    d.rounded_rectangle([5, 9, 254, 75], 9, fill=C("P07"))
    d.rounded_rectangle([5, 9, 254, 26], 9, fill=C("P08"))
    d.line([12, 10, 248, 10], fill=C("P09"))
    for x in (52, 160):                                                                      # 지붕 냉방기
        d.rounded_rectangle([x, 11, x + 44, 22], 3, fill=C("P06")); d.line([x + 1, 11, x + 43, 11], fill=C("P08"))
        for xx in range(x + 4, x + 42, 4):
            d.line([xx, 13, xx, 20], fill=C("P05"))
    d.line([5, 27, 254, 27], fill=C("P05"))
    d.rectangle([5, 50, 254, 56], fill=C(NAVY[1])); d.line([5, 50, 254, 50], fill=C(NAVY[2])); d.line([5, 56, 254, 56], fill=C(NAVY[0]))
    doors = [(30, False), (88, False), (146, state == "open"), (204, False)]
    for x, open_ in doors:
        d.rectangle([x, 29, x + 22, 72], fill=C(INK))
        if open_:
            d.rectangle([x + 1, 30, x + 21, 71], fill=C("P47"))                              # 안의 불빛(호박색)
            d.rectangle([x + 1, 30, x + 5, 71], fill=C("P06")); d.rectangle([x + 17, 30, x + 21, 71], fill=C("P06"))
            d.rectangle([x + 7, 34, x + 15, 52], fill=C("P53"))                              # 천 가림막(붉은 꽃무늬)
            d.point((x + 9, 38), fill=C("P49")); d.point((x + 13, 45), fill=C("P49"))
            d.rectangle([x + 8, 64, x + 13, 70], fill=C("P29")); d.line([x + 9, 62, x + 12, 60], fill=C("P56"))   # 깡통 화분
        else:
            d.rectangle([x + 1, 30, x + 10, 71], fill=C("P06")); d.rectangle([x + 12, 30, x + 21, 71], fill=C("P06"))
            d.line([x + 11, 30, x + 11, 71], fill=C(INK))
            for xx in (x + 3, x + 14):
                d.rectangle([xx, 33, xx + 5, 46], fill=C("P10")); d.line([xx, 33, xx + 3, 39], fill=C("P12"))
            d.rectangle([x, 51, x + 22, 55], fill=C(NAVY[1]))
    for i, x in enumerate(range(56, 236, 58)):
        for k in range(2):
            wx = x + k * 13
            if wx + 10 > 250 or (146 <= wx <= 168):
                continue
            lit = state == "open" and i == 1 and k == 1
            d.rounded_rectangle([wx, 31, wx + 10, 46], 2, fill=C(INK))
            d.rounded_rectangle([wx + 1, 32, wx + 9, 45], 2, fill=C("P47" if lit else ("P10" if (i + k) % 3 else "P02")))
            if (i + k) % 3 and not lit:
                d.line([wx + 2, 33, wx + 5, 38], fill=C("P12"))
    put_text(im, "구로", 200, 59, "P09", 8, "Galmuri7")
    d.rectangle([7, 30, 18, 40], fill=C("P02"))
    for x in (40, 70, 190, 220):
        d.rectangle([x, 74, x + 18, 80], fill=C(INK)); d.ellipse([x + 1, 75, x + 7, 81], fill=C("P03")); d.ellipse([x + 11, 75, x + 17, 81], fill=C("P03"))
    for _ in range(110):
        x, y = rnd.randint(8, 250), rnd.randint(28, 74)
        if im.getpixel((x, y))[3] and im.getpixel((x, y))[:3] in (P.rgb("P07"), P.rgb("P06")):
            im.putpixel((x, y), C(rnd.choice(["P05", "P06", "P25"] if y > 58 else ["P06", "P08"])))
    _shadow(d, 6, 254, 82)
    return im


def boxcar_gr(state=""):
    """유개 화차(6×2 발, 196×84): 붉은 녹 판자 몸통 · 미닫이 문(빗장) · 스텐실 '군수 — 3' · 지붕 판. 상태 open = 문이 밀려 열려 안이 어둡고 빈 상자."""
    rnd = random.Random(8404 + len(state))
    W_, H_ = 196, 84
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    _shadow(d, 6, 190, 78)
    for x in (24, 150):
        d.rectangle([x, 70, x + 22, 76], fill=C(INK)); d.ellipse([x + 1, 71, x + 8, 78], fill=C("P03")); d.ellipse([x + 14, 71, x + 21, 78], fill=C("P03"))
    d.rectangle([4, 6, 191, 72], fill=C(INK)); d.rectangle([5, 7, 190, 71], fill=C("P24"))
    d.rectangle([5, 7, 190, 22], fill=C("P25")); d.line([5, 7, 190, 7], fill=C("P26"))
    for x in range(14, 188, 12):                                                             # 판자 이음
        d.line([x, 23, x, 70], fill=C("P23"))
    d.rectangle([76, 26, 120, 70], fill=C(INK))
    if state == "open":
        d.rectangle([77, 27, 103, 69], fill=C("P02"))
        d.rectangle([82, 50, 96, 66], fill=C("P18")); d.line([82, 50, 96, 50], fill=C("P20"))   # 빈 상자 하나
        d.rectangle([103, 27, 119, 69], fill=C("P25"))
    else:
        d.rectangle([77, 27, 119, 69], fill=C("P25"))
        d.line([98, 27, 98, 69], fill=C("P23")); d.rectangle([94, 44, 102, 50], fill=C("P05"))   # 빗장
    put_text(im, "군수 3", 128, 30, "P09", 8, "Galmuri7")
    for _ in range(90):
        x, y = rnd.randint(8, 188), rnd.randint(24, 70)
        if im.getpixel((x, y))[:3] == P.rgb("P24"):
            im.putpixel((x, y), C(rnd.choice(["P23", "P25", "P26"])))
    return im


def flatcar_gr(state=""):
    """무개차(4×2 발, 132×72): 낮은 철판 바닥 · 쇠사슬 고정쇠 · 위에 묶인 나무 상자 둘 · 바퀴. 가벼워서 사람이 민다([힘 7] · 쇠지레).
    상태 pushed = 바퀴 밑 자갈에 끌린 자국 · 쐐기가 빠져 옆에 뒹군다."""
    W_, H_ = 132, 72
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    _shadow(d, 6, 126, 66)
    for x in (16, 96):
        d.rectangle([x, 56, x + 20, 62], fill=C(INK)); d.ellipse([x + 1, 57, x + 7, 63], fill=C("P03")); d.ellipse([x + 13, 57, x + 19, 63], fill=C("P03"))
    d.rectangle([4, 40, 127, 58], fill=C(INK)); d.rectangle([5, 41, 126, 57], fill=C("P05"))
    d.line([5, 41, 126, 41], fill=C("P07"))
    for x in range(10, 126, 10):
        d.point((x, 49), fill=C("P04"))
    for bx, bw in ((14, 40), (64, 46)):                                                      # 묶인 상자
        d.rectangle([bx, 14, bx + bw, 44], fill=C(INK)); d.rectangle([bx + 1, 15, bx + bw - 1, 43], fill=C("P18"))
        d.rectangle([bx + 1, 15, bx + bw - 1, 22], fill=C("P19")); d.line([bx + 1, 15, bx + bw - 1, 15], fill=C("P20"))
        d.line([bx + bw // 2, 15, bx + bw // 2, 43], fill=C("P17"))
        d.line([bx - 2, 30, bx + bw + 2, 30], fill=C("P06"))                                 # 쇠사슬
        for xx in range(bx - 2, bx + bw + 2, 3):
            d.point((xx, 29), fill=C("P08"))
    if state == "pushed":
        for x in range(0, 14, 3):
            d.line([x, 64, x + 2, 64], fill=C("P04"))
        d.polygon([(118, 66), (128, 66), (128, 70)], fill=C("P18"))                         # 빠진 쐐기
    else:
        d.polygon([(8, 62), (16, 62), (16, 56)], fill=C("P18"))                             # 바퀴 쐐기
    return im


def inspect_car(state=""):
    """궤도 검측차(6×2 발, 196×84): 노란 몸통 · 검은 사선 띠 · 앞 레이저 검측 틀 · 운전실 창 · 지붕 경광등. 상태 open = 옆문 열림(검측 일지 · 열쇠 고리)."""
    rnd = random.Random(9505 + len(state))
    W_, H_ = 196, 84
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    _shadow(d, 6, 190, 78)
    for x in (24, 146):
        d.rectangle([x, 70, x + 22, 76], fill=C(INK)); d.ellipse([x + 1, 71, x + 8, 78], fill=C("P03")); d.ellipse([x + 14, 71, x + 21, 78], fill=C("P03"))
    d.rounded_rectangle([14, 10, 191, 72], 6, fill=C(INK)); d.rounded_rectangle([15, 11, 190, 71], 5, fill=C("P48"))
    d.rounded_rectangle([15, 11, 190, 26], 5, fill=C("P49")); d.line([20, 12, 186, 12], fill=C("P50"))
    for x in range(20, 186, 14):                                                             # 사선 띠
        d.polygon([(x, 56), (x + 7, 56), (x + 13, 64), (x + 6, 64)], fill=C(INK))
    d.line([15, 56, 190, 56], fill=C(INK)); d.line([15, 64, 190, 64], fill=C(INK))
    d.rectangle([2, 28, 14, 66], fill=C(INK)); d.rectangle([3, 29, 13, 65], fill=C("P05"))   # 앞 검측 틀
    d.line([3, 47, 13, 47], fill=C("P52"))
    d.rounded_rectangle([150, 28, 182, 48], 4, fill=C(INK)); d.rounded_rectangle([151, 29, 181, 47], 3, fill=C("P10"))
    d.line([153, 31, 160, 44], fill=C("P12"))
    d.ellipse([96, 2, 106, 12], fill=C(INK)); d.ellipse([97, 3, 105, 11], fill=C("P59"))      # 경광등
    d.rectangle([70, 28, 98, 54], fill=C(INK))
    if state == "open":
        d.rectangle([71, 29, 97, 53], fill=C("P02"))
        d.rectangle([76, 40, 86, 50], fill=C("P09")); d.line([77, 43, 85, 43], fill=C("P05"))   # 검측 일지
        d.ellipse([88, 34, 94, 40], outline=C("P08"))                                      # 열쇠 고리
    else:
        d.rectangle([71, 29, 97, 53], fill=C("P48")); d.point((94, 42), fill=C(INK))
    put_text(im, "검측", 112, 32, INK, 8, "Galmuri7")
    for _ in range(70):
        x, y = rnd.randint(16, 188), rnd.randint(26, 54)
        if im.getpixel((x, y))[:3] == P.rgb("P48"):
            im.putpixel((x, y), C(rnd.choice(["P47", "P25"])))
    return im


def switch_lever(state=""):
    """수동 전철기 레버(1×1, 32×44): 콘크리트 받침 · 주물 함 · 긴 쇠 손잡이(흰 · 붉은 줄무늬) · 표지판 글자 칸.
    상태 thrown = 손잡이가 반대로 넘어가 있고 표지가 돌아 노란 면."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 28, 40)
    d.rectangle([4, 30, 27, 39], fill=C(INK)); d.rectangle([5, 31, 26, 38], fill=C("P06"))   # 받침
    d.rectangle([9, 24, 22, 33], fill=C(INK)); d.rectangle([10, 25, 21, 32], fill=C("P04"))  # 주물 함
    thrown = state == "thrown"
    x0, x1 = (16, 26) if thrown else (16, 6)
    d.line([x0, 26, x1, 4], fill=C(INK), width=3)
    for k in range(5):                                                                       # 줄무늬 손잡이
        t = k / 5.0
        xx = int(x0 + (x1 - x0) * t); yy = int(26 + (4 - 26) * t)
        d.point((xx, yy), fill=C("P09" if k % 2 else "P52"))
        d.point((xx + (1 if thrown else -1), yy - 1), fill=C("P09" if k % 2 else "P52"))
    d.ellipse([x1 - 3, 1, x1 + 3, 7], fill=C("P52"))
    d.rectangle([20 if not thrown else 2, 12, 30 if not thrown else 12, 22], fill=C(INK))     # 방향 표지
    d.rectangle([21 if not thrown else 3, 13, 29 if not thrown else 11, 21], fill=C("P49" if thrown else "P09"))
    return im


def crossing_gr(state=""):
    """구내 건널목 경보기(1×1, 32×60): 기둥 · X자 표지 · 붉은 등 둘 · 아래 단추 함. 상태 ring = 등 하나가 켜지고 소리 표시(땡땡)."""
    im = img(32, 60)
    d = ImageDraw.Draw(im)
    _shadow(d, 8, 24, 56)
    d.rectangle([14, 10, 17, 54], fill=C(INK)); d.line([15, 10, 15, 54], fill=C("P07"))
    for k in range(4):
        d.rectangle([14, 14 + k * 10, 17, 18 + k * 10], fill=C("P09" if k % 2 else INK))
    d.line([4, 4, 27, 14], fill=C(INK), width=3); d.line([4, 14, 27, 4], fill=C(INK), width=3)   # X 표지
    d.line([5, 4, 26, 13], fill=C("P09")); d.line([5, 13, 26, 4], fill=C("P09"))
    ring = state == "ring"
    for i, x in enumerate((5, 22)):
        d.ellipse([x - 1, 20, x + 7, 28], fill=C(INK)); d.ellipse([x, 21, x + 6, 27], fill=C("P54" if ring and i == 0 else "P51"))
    d.rectangle([18, 40, 27, 50], fill=C(INK)); d.rectangle([19, 41, 26, 49], fill=C("P48"))   # 단추 함
    d.ellipse([20, 43, 24, 47], fill=C("P52"))
    if ring:
        put_text(im, "땡", 0, 30, "P50", 8, "Galmuri7")
    return im


def rail_run(seed=0):
    """선로 넉 칸(덧그림 128×32): rail_h 넷을 이은 줄 — 침목 간격 · 자갈 · 녹 반점이 칸마다 조금씩 다르다(한 줄에 쓰는 소품 수를 줄인다)."""
    from props_s05 import rail_h
    im = img(128, 32)
    for k in range(4):
        im.alpha_composite(rail_h((seed * 4 + k) % 5), (k * 32, 0))
    return im


def boots_rows(state=""):
    """벗어 둔 군화 줄(덧그림 96×32): 객차 통로에 발끝을 맞춰 벗어 둔 검은 군화 여섯 켤레(위에서 본 모양 — 둥근 발끝 · 목 입구 ·
    끈 구멍 · 광낸 발끝 하이라이트 · 바닥 그림자). 켤레마다 끈을 매듭지어 묶었다. 상태 gap = 둘째 · 다섯째 자리가 비어
    먼지 속 군화 자국만 — 군화를 신은 채 남은 사람들 몫('안 간 사람들')."""
    rnd = random.Random(1212 + len(state))
    im = img(96, 32)
    d = ImageDraw.Draw(im)
    gaps = {1, 4} if state == "gap" else set()
    for i in range(6):
        x = 4 + i * 15
        if i in gaps:
            for k in (0, 6):
                d.rounded_rectangle([x + k, 10, x + k + 4, 24], 2, outline=C("P05"))         # 먼지 속에 남은 군화 자국(테두리만)
            continue
        for k in (0, 6):
            y = 9 + rnd.randint(0, 1)
            for xx in range(x + k, x + k + 6):                                                # 바닥 그림자(바둑 점)
                if (xx + y) % 2 == 0:
                    d.point((xx, y + 17), fill=C("P02"))
            d.rounded_rectangle([x + k, y, x + k + 4, y + 16], 2, fill=C(INK))                # 몸(발끝이 아래 — 통로 쪽)
            d.ellipse([x + k, y + 11, x + k + 4, y + 17], fill=C(INK))
            d.rectangle([x + k + 1, y + 1, x + k + 3, y + 3], fill=C("P02"))                 # 목 입구
            for yy in range(y + 5, y + 11, 2):
                d.point((x + k + 1, yy), fill=C("P04")); d.point((x + k + 3, yy), fill=C("P04"))   # 끈 구멍 두 줄
            d.point((x + k + 2, y + 15), fill=C("P06")); d.point((x + k + 3, y + 14), fill=C("P04"))   # 광낸 발끝
        d.line([x + 2, 14, x + 8, 14], fill=C("P21")); d.point((x + 9, 15), fill=C("P21")); d.point((x + 9, 13), fill=C("P21"))   # 켤레를 묶은 끈 매듭
    return im


def coach_seat(state=""):
    """객차 좌석 한 쌍(2×1, 64×40): 국방색 비닐 2인 좌석 · 등받이 · 팔걸이 · 좌석 위 개켜 둔 군복(접힌 녹색 · 명찰).
    상태 empty = 군복 없이 비닐에 금 · 구멍 · 상태 sat = 등받이에 철모가 걸려 있다(앉아 있던 사람이 남긴)."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 60, 36)
    for x in (4, 34):
        d.rectangle([x, 4, x + 26, 14], fill=C(INK)); d.rectangle([x + 1, 5, x + 25, 13], fill=C(OLIVE[1]))   # 등받이
        d.line([x + 1, 5, x + 25, 5], fill=C(OLIVE[3]))
        d.rectangle([x, 14, x + 26, 32], fill=C(INK)); d.rectangle([x + 1, 15, x + 25, 31], fill=C(OLIVE[2]))   # 앉는 자리
        d.line([x + 1, 15, x + 25, 15], fill=C(OLIVE[3]))
    d.rectangle([2, 12, 4, 32], fill=C("P05")); d.rectangle([60, 12, 62, 32], fill=C("P05"))   # 팔걸이
    if state == "empty":
        d.line([10, 20, 18, 26], fill=C(OLIVE[0])); d.ellipse([44, 22, 48, 26], fill=C("P02"))
    else:
        for x in (8, 38):                                                                    # 개켜 둔 군복
            d.rectangle([x, 18, x + 16, 28], fill=C(INK)); d.rectangle([x + 1, 19, x + 15, 27], fill=C(OLIVE[3]))
            d.line([x + 1, 23, x + 15, 23], fill=C(OLIVE[1])); d.rectangle([x + 10, 20, x + 14, 22], fill=C("P09"))
    if state == "sat":
        d.ellipse([12, 0, 24, 9], fill=C(INK)); d.ellipse([13, 1, 23, 8], fill=C(OLIVE[2])); d.line([14, 2, 21, 2], fill=C(OLIVE[4]))
    return im


def lost_box(state=""):
    """분실물함(1×1, 32×44): 회색 철 사물함 · 앞 철망 칸 · '분실물 — 역무실 문의' 종이 · 칸 안 우산 · 정기권 지갑.
    상태 open = 철망 칸이 열리고 지갑이 없다."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 30, 40)
    d.rectangle([2, 2, 29, 38], fill=C(INK)); d.rectangle([3, 3, 28, 37], fill=C("P06"))
    d.line([3, 3, 28, 3], fill=C("P08"))
    d.rectangle([6, 6, 25, 22], fill=C(INK))
    d.rectangle([7, 7, 24, 21], fill=C("P02"))
    d.line([9, 19, 16, 9], fill=C("P53")); d.line([16, 9, 18, 11], fill=C("P53"))           # 우산
    if state != "open":
        d.rectangle([18, 15, 23, 20], fill=C("P44")); d.line([18, 15, 23, 15], fill=C("P46"))   # 정기권 지갑(남색)
        for xx in range(7, 25, 3):
            d.line([xx, 7, xx, 21], fill=C("P05"))                                          # 철망
    else:
        d.line([24, 7, 30, 4], fill=C("P05")); d.line([24, 21, 30, 24], fill=C("P05"))
    d.rectangle([7, 25, 24, 33], fill=C("P09")); d.line([9, 28, 22, 28], fill=C("P04")); d.line([9, 30, 18, 30], fill=C("P04"))
    return im


def w_switch_chart():
    """전철기 표(벽 소품 2칸, 64×44): 신호 초소 벽 칠판 — 선로 다섯 줄 그림 · 레버 A · B · C 화살표 · 손글씨 'C = 2번(수송) 연결 — 출발 대기'."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 61, 40], fill=C(INK)); d.rectangle([3, 3, 60, 39], fill=C("P29")); d.line([3, 3, 60, 3], fill=C("P30"))
    for k in range(5):
        y = 8 + k * 6
        d.line([8, y, 56, y], fill=C("P09"))
    d.line([20, 8, 30, 14], fill=C("P50")); d.line([30, 26, 40, 20], fill=C("P50")); d.line([44, 14, 52, 20], fill=C("P50"))
    put_text(im, "A", 18, 30, "P50", 8, "Galmuri7"); put_text(im, "B", 32, 30, "P50", 8, "Galmuri7"); put_text(im, "C", 46, 30, "P50", 8, "Galmuri7")
    return im


def w_shutter_gr(state=""):
    """선로 끝 셔터(벽 소품 3칸, 96×64): 골함석 셔터 · 레일이 셔터 밑으로 이어짐 · '선로 끝 — 출입 금지' / 상태 open = 반쯤 들려 바깥 빛."""
    im = img(96, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 93, 62], fill=C(INK)); d.rectangle([3, 3, 92, 61], fill=C("P05"))
    top = 34 if state == "open" else 61
    for y in range(4, top, 4):
        d.line([4, y, 91, y], fill=C("P07")); d.line([4, y + 1, 91, y + 1], fill=C("P04"))
    if state == "open":
        d.rectangle([4, top, 91, 61], fill=C("P15")); d.rectangle([4, top + 10, 91, 61], fill=C("P14"))
        d.line([4, top, 91, top], fill=C(INK))
    else:
        d.rectangle([30, 20, 66, 30], fill=C("P09")); put_text(im, "출입금지", 32, 21, "P52", 8, "Galmuri7")
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_GR = {
    "coach_gr": _r(coach_gr, 8, 2, down=-2),
    "loco_atomic": _r(loco_atomic, 10, 2, down=-2),
    "commute_car1": _r(commute_car1, 8, 2, down=-2),
    "boxcar_gr": _r(boxcar_gr, 6, 2, down=-2),
    "flatcar_gr": _r(flatcar_gr, 4, 2, down=-2),
    "inspect_car": _r(inspect_car, 6, 2, down=-2),
    "switch_lever": _r(switch_lever, 1, 1, down=-2),
    "crossing_gr": _r(crossing_gr, 1, 1, down=-2),
    "rail_run": _r(lambda: rail_run(0), 0, 0, "deco"),
    "rail_run2": _r(lambda: rail_run(1), 0, 0, "deco"),
    "boots_rows": _r(boots_rows, 0, 0, "deco"),
    "coach_seat": _r(coach_seat, 2, 1, down=-2),
    "lost_box": _r(lost_box, 1, 1, down=-2),
    "w_switch_chart": _r(w_switch_chart, 2, 0, "wall", dx=0, dy=6),
    "w_shutter_gr": _r(w_shutter_gr, 3, 0, "wall", dx=0, dy=0),
}
STATES_GR = {
    "coach_gr": {s: (lambda s=s: coach_gr(s)) for s in ("open", "mob", "ladder", "rust")},
    "loco_atomic": {s: (lambda s=s: loco_atomic(s)) for s in ("idle", "open", "sb")},
    "commute_car1": {"open": lambda: commute_car1("open")},
    "boxcar_gr": {"open": lambda: boxcar_gr("open")},
    "flatcar_gr": {"pushed": lambda: flatcar_gr("pushed")},
    "inspect_car": {"open": lambda: inspect_car("open")},
    "switch_lever": {"thrown": lambda: switch_lever("thrown")},
    "crossing_gr": {"ring": lambda: crossing_gr("ring")},
    "boots_rows": {"gap": lambda: boots_rows("gap")},
    "coach_seat": {s: (lambda s=s: coach_seat(s)) for s in ("empty", "sat")},
    "lost_box": {"open": lambda: lost_box("open")},
    "w_shutter_gr": {"open": lambda: w_shutter_gr("open")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_GR.values()] + [fn() for st in STATES_GR.values() for fn in st.values()]
    W = max(i.width for i in ims) + 4
    H = sum(i.height + 4 for i in ims)
    sheet = Image.new("RGBA", (W, H), C("P11"))
    y = 2
    for i in ims:
        sheet.alpha_composite(i, (2, y))
        y += i.height + 4
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
