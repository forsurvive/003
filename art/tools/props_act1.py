"""1막 마감 배치 소품(단계 1-13a2 — SD-09a L-R01-16 도림천 고가 수로, SD-16 아이작풍).
  bike_pile  마른 수로 바닥에 쓰러진 2077년 자전거 더미(3×1) — 다섯 대가 옆으로 누워 겹쳤다. 모두 같은 쪽(오른쪽 위 — 한강 쪽)으로 앞바퀴가 향한다.
             바퀴 테는 검게 삭았고 바퀴살은 녹이 슬어 몇 가닥만 남음 · 틀은 바랜 칠(하늘 · 국방 · 빨강 · 은 · 노랑 장바구니)에 녹 얼룩 ·
             안장 가죽이 벗겨짐 · 한 대 바구니에 젖었다 마른 종이 한 장(R01-16 쪽지). 그림자는 몸을 민 선 그림자(타원 금지).
  fence_banner 신길 빌라 담장 철망에 묶인 2077년 재건축 현수막(2×1, SD-09a L-R02-16) — 크림 비닐 · 파란 테 '동의 87%' ·
             그 위 붉은 스프레이 '동의함' 덧칠 · 오른쪽 아래 귀퉁이만 덧칠이 덜 돼 볼펜 글씨 한 줄(읽는 건 조사 글) · 왼쪽 끈이 풀려 처짐 · 찢긴 구멍.
  atom_charger 원자 충전소 충전기(1×1, SD-09a L-R01-15 · LR-49) — 2050년대 캡슐형: 크림색 둥근 몸통 · 청록 띠 · 위 둥근 노심 창(꺼져 검은 유리에 금) ·
             바늘이 0에 붙은 계기 · 감긴 충전 호스 · 몸통 아래 녹물 · 앞판 원자 표장. 상태 glow(노심 창이 희미한 초록 — 아직 남은 열).
  wander_cairn 관악 비탈 떠돌이의 돌탑(1×1, 1-13j2 — 재미 검수 '아무 바위와 똑같아 운으로만 찾는다'): 납작한 돌 셋을 쌓은 작은 탑, 맨 아래 두 돌 틈에
             녹슨 탄약 깡통(올리브 칠이 벗겨진 쇠 · 손잡이 고리) — 뚜껑 테두리 한 점이 빛을 받아 반짝인다(광원 북서). 둘레 산에 무작위로 깔린 둥근 바위와
             한눈에 다르게: 결이 납작하고 층층이 · 사람 손이 쌓은 기울기. 상태 scattered(돌 셋이 쓰러져 흩어지고 뚜껑 열린 깡통이 옆으로 누움 — 비운 뒤) ·
             restacked(다시 쌓임 — 깡통은 틈 안 · 반짝임 없음, 주인이 다녀간 뒤).
  boot_prints 흙에 찍힌 군화 발자국 두 쌍(덧그림 30×20, 1-13j2) — 숲 틈 흙길에서 돌탑으로 꺾여 든다(손 자리에 두세 장). 굽 자리가 깊고 앞창 줄무늬 ·
             길 위 회색에서도 읽히게 진한 흙색. boot_prints_out — 주인이 다녀간 뒤 돌탑에서 북쪽으로 곧게 나간 새 발자국(더 진하다).
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from props_s04 import chain_fence
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _wheel(d, rnd, cx, cy, rx, ry):
    """누운 바퀴(납작한 고리): 삭은 타이어 · 녹슨 테 · 남은 바퀴살 몇 가닥 · 허브."""
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=C("P02"), width=2)
    d.ellipse([cx - rx + 1, cy - ry + 1, cx + rx - 1, cy + ry - 1], outline=C("P04"))
    for k in range(10):                                                 # 테의 녹 점
        a = rnd.random() * math.tau
        d.point((round(cx + math.cos(a) * (rx - 1)), round(cy + math.sin(a) * (ry - 1))), fill=C(rnd.choice(["P24", "P25", "P26"])))
    for k in range(rnd.randint(3, 5)):                                  # 남은 바퀴살
        a = rnd.random() * math.tau
        d.line([cx, cy, round(cx + math.cos(a) * (rx - 2)), round(cy + math.sin(a) * (ry - 2))], fill=C(rnd.choice(["P05", "P25"])))
    d.rectangle([cx - 1, cy - 1, cx + 1, cy], fill=C("P06"))
    d.point((cx, cy), fill=C(INK))


def _bike(im, rnd, rx_, ry_, ang, paint, basket=False, note=False):
    """옆으로 누운 자전거 한 대: 뒷바퀴 허브(rx_, ry_)에서 ang 방향(앞바퀴 쪽)으로 틀 · 안장 · 핸들."""
    d = ImageDraw.Draw(im)
    ux, uy = math.cos(ang), math.sin(ang) * 0.62                        # 바닥에 누운 몸 — 세로를 눌러 3/4 시점
    vx, vy = -uy, ux                                                    # 틀의 '위'쪽(누운 자전거라 바닥 위로 들린 방향)
    L = 24
    rear = (rx_, ry_)
    front = (rx_ + ux * L, ry_ + uy * L)
    bb = (rx_ + ux * L * 0.42 + vx * 2, ry_ + uy * L * 0.42 + vy * 2)    # 크랭크 축
    seat = (rx_ + ux * L * 0.3 - vx * 7, ry_ + uy * L * 0.3 - vy * 7)    # 안장 기둥 위
    head = (rx_ + ux * L * 0.82 - vx * 7, ry_ + uy * L * 0.82 - vy * 7)  # 머리관
    r = lambda p: (round(p[0]), round(p[1]))
    _wheel(d, rnd, *r(rear), 10, 6)
    _wheel(d, rnd, *r(front), 10, 6)
    c0, c1 = C(paint[0]), C(paint[1])
    for a, b in ((rear, bb), (bb, seat), (seat, rear), (seat, head), (bb, head), (head, front)):
        d.line([r(a), r(b)], fill=c0, width=2)
    d.line([r(seat), r(head)], fill=c1)                                 # 윗관 빛 받는 면(광원 북서)
    for k in range(4):                                                  # 칠 위 녹 얼룩
        t = rnd.random()
        a, b = rnd.choice(((rear, bb), (bb, seat), (seat, head), (bb, head)))
        d.point(r((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)), fill=C(rnd.choice(["P25", "P26"])))
    sx, sy = r(seat)                                                    # 안장(가죽 벗겨짐)
    d.rectangle([sx - 3, sy - 2, sx + 2, sy], fill=C("P02"))
    d.point((sx - 1, sy - 2), fill=C("P18")); d.point((sx + 1, sy - 1), fill=C("P18"))
    hx, hy = r(head)                                                    # 핸들(앞바퀴 쪽으로 꺾임)
    d.line([hx - round(vx * 4), hy - round(vy * 4), hx + round(vx * 3), hy + round(vy * 3)], fill=C("P05"), width=1)
    d.point((hx - round(vx * 4), hy - round(vy * 4)), fill=C(INK))
    d.point((hx + round(vx * 3), hy + round(vy * 3)), fill=C(INK))
    d.point(r(bb), fill=C(INK))
    if basket:                                                          # 앞 장바구니(삭은 철망) · 그 안 종이 한 장
        fx, fy = r((head[0] + ux * 5, head[1] + uy * 5))
        d.rectangle([fx - 4, fy - 4, fx + 3, fy + 1], outline=C("P04"))
        for x in range(fx - 3, fx + 3, 2):
            d.line([x, fy - 3, x, fy], fill=C("P25"))
        if note:
            d.rectangle([fx - 2, fy - 6, fx + 1, fy - 3], fill=C("P08"))
            d.point((fx - 1, fy - 5), fill=C("P05")); d.point((fx, fy - 4), fill=C("P05"))


def bike_pile():
    """도림천 수로 자전거 더미(96×44 — 3×1): 다섯 대가 오른쪽 위(한강 쪽)로 앞바퀴를 둔 채 겹쳐 누움.
    그림자: 틀 · 바퀴가 선이라 윤곽 그림자를 깔면 바퀴 안이 검게 메워진다 — 몸 알파를 오른쪽 아래(광원 북서)로 민 선 그림자."""
    W, H = 96, 44
    body = img(W, H)
    rnd = random.Random(1016)
    ang = -0.40                                                         # 오른쪽 위(조금 위로) — 모두 같은 쪽
    bikes = [(12, 33, ["P12", "P14"], False, False), (36, 35, ["P29", "P31"], False, False), (58, 29, ["P53", "P54"], True, True),
             (22, 21, ["P07", "P09"], False, False), (62, 15, ["P48", "P49"], True, False)]
    for x, y, paint, bsk, note in sorted(bikes, key=lambda b: b[1]):    # 위(멀리)부터 그려 겹침 순서를 맞춘다
        _bike(body, rnd, x, y, ang + rnd.uniform(-0.08, 0.08), paint, bsk, note)
    im = img(W, H)
    a = body.getchannel("A")
    sh = Image.new("RGBA", (W, H), C("P03"))
    sh.putalpha(a)
    im.alpha_composite(sh, (2, 1))
    im.alpha_composite(body)
    d = ImageDraw.Draw(im)
    for k in range(22):                                                 # 마른 수로 바닥의 진흙 금 · 낙엽
        x, y = rnd.randint(4, W - 6), rnd.randint(8, H - 3)
        if im.getpixel((x, y))[3] == 0:
            d.point((x, y), fill=C(rnd.choice(["P17", "P18", "P19"])))
    return im


def fence_banner():
    """철망에 묶인 재건축 현수막(64×44 — 2×1): 철망 두 칸 위에 크림 비닐 현수막(왼쪽 끈이 풀려 처짐) · 파란 테 '동의 87%' ·
    붉은 스프레이 '동의함'이 비스듬히 덮음 · 오른쪽 아래 귀퉁이만 덜 칠해져 볼펜 줄 한 줄 · 찢긴 구멍 하나."""
    im = img(64, 44)
    im.alpha_composite(chain_fence(), (0, 0))
    im.alpha_composite(chain_fence(), (32, 0))
    d = ImageDraw.Draw(im)
    poly = [(4, 13), (60, 12), (60, 33), (5, 35)]                       # 왼쪽 위 끈이 풀려 한 픽셀 처짐
    d.polygon(poly, fill=C("P09"))
    d.polygon(poly, outline=C("P07"))
    d.line([6, 14, 58, 13], fill=C("P45")); d.line([6, 33, 58, 32], fill=C("P45"))   # 파란 테
    put_text(im, "동의 87%", 10, 14, "P44", 8, "Galmuri7")
    # 붉은 스프레이 덧칠: 아랫줄에 굵게 '동의함' + 흘러내림 — 오른쪽 아래 귀퉁이(46~58, 27~32)는 비워 둔다
    put_text(im, "동의함", 10, 23, "P53", 8, "Galmuri7")
    put_text(im, "동의함", 11, 23, "P53", 8, "Galmuri7")
    for x, n in ((13, 3), (24, 4), (33, 2)):
        d.line([x, 32, x, 32 + n], fill=C("P52"))
    d.line([47, 30, 57, 29], fill=C("P44"))                             # 볼펜 한 줄('나는 반대' — 조사 글)
    d.point((49, 29), fill=C("P44")); d.point((53, 28), fill=C("P44"))
    d.ellipse([44, 23, 48, 27], fill=C("P02")); d.point((45, 24), fill=C("P13"))   # 찢긴 구멍 — 뒤 철망이 비침
    for x, y in ((4, 13), (60, 12), (60, 33)):                          # 묶은 끈(왼쪽 아래 하나는 풀림)
        d.line([x, y, x - 1 if x < 30 else x + 1, y - 2], fill=C("P05"))
    d.line([5, 35, 3, 39], fill=C("P05"))
    return im


def atom_charger(state=""):
    """원자 충전기(36×60 — 1×1): 크림 캡슐 몸통 · 청록 띠 · 위 노심 창 · 계기 · 호스 · 앞판 글. glow = 노심 창에 남은 초록."""
    im = img(36, 60)
    d = ImageDraw.Draw(im)
    sh = Image.new("RGBA", (36, 60), (0, 0, 0, 0))                     # 접지 그림자 — 받침 오른쪽 아래 짧은 띠
    ImageDraw.Draw(sh).rectangle([8, 55, 33, 57], fill=C("P02"))
    im.alpha_composite(sh)
    d.rectangle([5, 50, 29, 56], fill=C("P04")); d.line([5, 50, 29, 50], fill=C("P06"))   # 콘크리트 받침
    d.rounded_rectangle([7, 14, 27, 52], radius=6, fill=C("P08"), outline=C(INK))         # 몸통
    d.line([9, 18, 9, 48], fill=C("P09"))                               # 빛 받는 왼쪽 면(광원 북서)
    d.line([25, 18, 25, 48], fill=C("P07"))
    d.rectangle([8, 30, 26, 34], fill=C("P62")); d.line([8, 30, 26, 30], fill=C("P63"))   # 청록 띠
    d.ellipse([10, 39, 24, 45], outline=C("P44"))                       # 원자 표장: 궤도 둘 + 핵(글 대신 — 8px 글꼴로는 안 읽힌다)
    d.arc([13, 36, 21, 48], 0, 360, fill=C("P44"))
    d.rectangle([16, 41, 17, 42], fill=C("P53"))
    d.ellipse([9, 3, 25, 19], fill=C("P11"), outline=C(INK))            # 노심 창
    if state == "glow":
        d.ellipse([12, 6, 22, 16], fill=C("P55")); d.ellipse([14, 8, 19, 13], fill=C("P56"))
    else:
        d.ellipse([12, 6, 22, 16], fill=C("P02"))
        d.line([13, 9, 17, 12], fill=C("P13")); d.line([17, 12, 16, 15], fill=C("P13"))   # 유리 금
    d.point((13, 7), fill=C("P15"))                                     # 창 반짝임
    d.ellipse([12, 21, 20, 29], fill=C("P09"), outline=C(INK))          # 계기 — 바늘이 0
    d.line([16, 25, 13, 27], fill=C("P53"))
    d.arc([22, 22, 34, 44], 270, 90, fill=C(INK), width=2)              # 감긴 호스
    d.arc([23, 26, 33, 40], 270, 90, fill=C("P04"))
    d.rectangle([30, 43, 33, 46], fill=C("P05"))                        # 노즐
    for x, y in ((11, 47), (12, 49), (21, 46), (22, 49), (16, 50)):     # 녹물
        d.point((x, y), fill=C("P25"))
    d.line([18, 44, 18, 49], fill=C("P26"))
    return im


def _flat_stone(d, x0, y0, w, h, ramp, rnd):
    """납작한 돌 한 장(옆에서 본 층): 먹선 · 윗면 밝음(광원 북서) · 옆면 어둠 · 결 한 줄 · 지의류 한두 점."""
    d.rounded_rectangle([x0 - 1, y0 - 1, x0 + w, y0 + h], radius=2, fill=C(INK))
    d.rounded_rectangle([x0, y0, x0 + w - 1, y0 + h - 1], radius=2, fill=C(ramp[1]))
    d.line([x0 + 1, y0, x0 + w - 3, y0], fill=C(ramp[3]))              # 윗면 가장자리 빛
    d.line([x0 + 1, y0 + 1, x0 + w - 4, y0 + 1], fill=C(ramp[2]))
    d.line([x0 + 1, y0 + h - 1, x0 + w - 2, y0 + h - 1], fill=C(ramp[0]))   # 아랫면 그늘
    d.point((x0 + w - 1, y0 + h // 2), fill=C(ramp[0]))
    gx = x0 + rnd.randint(2, max(2, w - 4))                              # 결
    d.line([gx, y0 + 1, gx + 2, y0 + h - 2], fill=C(ramp[0]))
    for _ in range(rnd.randint(1, 2)):                                   # 지의류
        d.point((x0 + rnd.randint(1, w - 2), y0 + rnd.randint(1, max(1, h - 2))), fill=C(rnd.choice(["P31", "P32"])))


def _tin(d, x0, y0, lying=False, glint=True):
    """녹슨 탄약 깡통(8×6): 올리브 칠(벗겨진 쇠 · 녹) · 뚜껑 띠 · 손잡이 고리 · 빛 받는 뚜껑 모서리(흰 점 + 노란 점 — 멀리서도 보이는 반짝임)."""
    if lying:                                                            # 옆으로 누운 빈 깡통 — 입(어두운 안)이 보는 쪽을 향한다
        d.rectangle([x0 - 1, y0 - 1, x0 + 8, y0 + 5], fill=C(INK))
        d.rectangle([x0, y0, x0 + 7, y0 + 4], fill=C("P30"))
        d.line([x0 + 1, y0, x0 + 7, y0], fill=C("P31"))
        d.rectangle([x0 + 5, y0, x0 + 7, y0 + 4], fill=C("P05"))         # 열린 입 테(쇠)
        d.rectangle([x0 + 6, y0 + 1, x0 + 7, y0 + 3], fill=C("P01"))     # 빈 속
        d.point((x0 + 2, y0 + 3), fill=C("P25"))
        d.point((x0 + 3, y0 + 2), fill=C("P26"))
        return
    d.rectangle([x0 - 1, y0 - 1, x0 + 8, y0 + 6], fill=C(INK))
    d.rectangle([x0, y0, x0 + 7, y0 + 5], fill=C("P30"))                 # 몸통(올리브)
    d.line([x0, y0, x0 + 7, y0], fill=C("P06"))                           # 뚜껑 띠(쇠)
    d.line([x0, y0 + 1, x0 + 7, y0 + 1], fill=C("P04"))
    d.line([x0 + 7, y0 + 2, x0 + 7, y0 + 5], fill=C("P29"))               # 오른쪽 그늘
    for (x, y) in ((x0 + 2, y0 + 3), (x0 + 5, y0 + 4), (x0 + 6, y0 + 2), (x0 + 3, y0 + 5)):
        d.point((x, y), fill=C(("P25", "P26", "P24")[(x + y) % 3]))      # 녹 · 벗겨진 칠
    d.line([x0 + 2, y0 - 2, x0 + 5, y0 - 2], fill=C("P05"))               # 손잡이 고리
    d.point((x0 + 2, y0 - 1), fill=C("P04")); d.point((x0 + 5, y0 - 1), fill=C("P04"))
    if glint:
        d.point((x0, y0), fill=C("P09"))                                  # 뚜껑 모서리 반짝임(북서 빛)
        d.point((x0 + 1, y0), fill=C("P50"))
        d.point((x0, y0 - 1), fill=C("P08"))


def wander_cairn(state=""):
    """떠돌이의 돌탑(30×30, 발 1×1). 기본 = 쌓임 + 깡통 반짝임 · scattered = 흩어짐 + 빈 깡통 누움 · restacked = 다시 쌓임(깡통은 틈 안, 반짝임 없음)."""
    im = img(30, 30)
    d = ImageDraw.Draw(im)
    rnd = random.Random(1359)
    STONE = ["P04", "P05", "P06", "P07"]
    WARM = ["P17", "P18", "P19", "P20"]
    for x in range(3, 28):                                               # 그림자(선 그림자 — 타원 금지)
        if x % 2 == 0:
            d.point((x, 28), fill=C("P02"))
    if state == "scattered":
        _flat_stone(d, 1, 22, 10, 4, STONE, rnd)                          # 쓰러진 돌 셋 — 서로 떨어져 바닥에
        _flat_stone(d, 19, 23, 9, 4, WARM, rnd)
        _flat_stone(d, 6, 15, 8, 4, STONE, rnd)
        _tin(d, 15, 16, lying=True)
        return im
    _flat_stone(d, 3, 20, 22, 7, STONE, rnd)                              # 아래 넓은 돌
    if state != "restacked":
        _tin(d, 21, 14)                                                   # 아래 · 가운데 돌 사이 틈에서 오른쪽으로 비죽 나온 깡통(뚜껑 모서리 반짝임이 보인다)
    _flat_stone(d, 6, 14, 14, 6, WARM, rnd)                               # 가운데(조금 왼쪽으로 기움 — 손으로 쌓은 결)
    _flat_stone(d, 9, 9, 9, 5, STONE, rnd)                                # 꼭대기
    d.rectangle([12, 6, 14, 8], fill=C(INK))                              # 꼭대기 작은 돌 하나
    d.rectangle([12, 7, 13, 8], fill=C("P06"))
    d.point((12, 7), fill=C("P08"))
    if state == "restacked":
        d.rectangle([20, 17, 23, 19], fill=C("P01"))                      # 틈(깡통은 안쪽으로 밀어 넣었다)
    return im


def _boot(d, x, y, fresh=False):
    """군화 발자국 하나(4×7, 위가 앞): 앞창(넓고 줄무늬) · 틈 · 굽(깊다). 길 위 회색에서도 읽히게 진한 흙색"""
    sole, deep = ("P17", "P01") if fresh else ("P18", "P17")
    d.rectangle([x, y, x + 3, y + 3], fill=C(sole))                         # 앞창
    d.point((x + 1, y + 1), fill=C(deep))                                  # 줄무늬
    d.point((x + 2, y + 2), fill=C(deep))
    d.rectangle([x, y + 5, x + 3, y + 6], fill=C(deep))                    # 굽(깊다)


def boot_prints():
    """흙 위 군화 발자국 두 쌍(30×20, 덧그림): 아래 오른쪽(숲 틈 흙길) → 위 왼쪽(돌탑). 손 자리에 두세 장을 이어 깐다."""
    im = img(30, 20)
    d = ImageDraw.Draw(im)
    for k, (x, y) in enumerate(((22, 11), (16, 9), (9, 4), (3, 1))):
        _boot(d, x + (2 if k % 2 else 0), y)
    return im


def boot_prints_out():
    """주인이 다녀간 뒤의 새 발자국(30×20, 덧그림): 돌탑에서 위(북쪽 능선)로 곧게 나간다 — 먼저 난 발자국보다 진하다(새것)."""
    im = img(30, 20)
    d = ImageDraw.Draw(im)
    for k, (x, y) in enumerate(((10, 12), (16, 8), (10, 4), (16, 0))):
        _boot(d, x, y, fresh=True)
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_ACT1 = {
    "bike_pile": _r(bike_pile, 3, 1, down=0),
    "fence_banner": _r(fence_banner, 2, 1),
    "atom_charger": _r(atom_charger, 1, 1, down=-2),
    "wander_cairn": _r(wander_cairn, 1, 1, down=1),                     # 1-13j2 관악 비탈 떠돌이 돌탑(깡통 wander_tin)
    "boot_prints": _r(boot_prints, 0, 0, "deco"),
    "boot_prints_out": _r(boot_prints_out, 0, 0, "deco"),               # 주인이 다녀간 뒤(WT_STATE ≥ 3) 돌탑에서 나간 새 발자국
}
STATES_ACT1 = {"atom_charger": {"glow": lambda: atom_charger("glow")},
               "wander_cairn": {"scattered": lambda: wander_cairn("scattered"), "restacked": lambda: wander_cairn("restacked")}}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_act1.png"
    ps = [bike_pile(), fence_banner(), atom_charger(), atom_charger("glow"), wander_cairn(), wander_cairn("scattered"), wander_cairn("restacked"),
          boot_prints(), boot_prints_out()]
    sheet = Image.new("RGBA", (sum(p.width + 16 for p in ps), 60), (130, 112, 84, 255))
    x = 8
    for p in ps:
        sheet.alpha_composite(p, (x, 8))
        x += p.width + 16
    sheet.resize((sheet.width * 5, sheet.height * 5), Image.NEAREST).save(out)
    print(out)
