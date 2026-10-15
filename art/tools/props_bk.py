"""여의도 지하 벙커 소품(단계 1-5, SD-09a L-R02-02 · SD-03a §8.4 · SD-16 §7·§8 아이작풍).
비상 집결지 큰 방: 2077년 관리 요원 12명의 유해가 접이 의자에 앉아 입구를 본다(연출 메모 — 들어오는 순간 그 시선을 정면으로 받는다).
작은 방: 소파·책상·샤워장 거울('23:2'). 기계실: 공조기·발전기·환기구. 바깥: 환승센터 터 해치 · 계엄군 호송차.
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01).
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _chair_back(d, x0, y0):
    d.rectangle([x0, y0, x0 + 17, y0 + 3], fill=C("P05"))               # 등받이 판
    d.line([x0, y0, x0 + 17, y0], fill=C("P07"))
    d.line([x0 + 1, y0 + 4, x0 + 1, y0 + 20], fill=C("P04"))            # 등받이 기둥
    d.line([x0 + 16, y0 + 4, x0 + 16, y0 + 20], fill=C("P04"))


def seated_remains(variant=0, officer=False):
    """의자에 앉은 관리 요원 유해(1×1, 정면 = 남쪽을 본다): 2077 관리 요원 정장(감색·회색·갈색 셋) · 목에 건 신분증 ·
    고개가 조금 기운 해골 · 무릎 위 손뼈 · 어깨에 쌓인 먼지. officer = 경비 장교(국방색 군복·모자, 곁에 세운 소총)."""
    rnd = random.Random(variant * 31 + 7)
    w, h = (36, 44) if officer else (28, 44)
    im = img(w, h)
    d = ImageDraw.Draw(im)
    cx = 13
    d.ellipse([3, 38, 25, 43], fill=C("P02"))                            # 그림자
    _chair_back(d, cx - 8, 10)
    suit = ["P44", "P12", "P18", "P43"][variant % 4] if not officer else "P30"
    lit = {"P44": "P45", "P12": "P13", "P18": "P19", "P43": "P44", "P30": "P31"}[suit]
    d.rectangle([cx - 9, 25, cx + 9, 28], fill=C("P05"))                 # 좌석
    d.line([cx - 9, 25, cx + 9, 25], fill=C("P07"))
    for x in (cx - 8, cx + 7):                                           # 의자 다리
        d.line([x, 29, x, 41], fill=C("P04"))
    d.polygon([(cx - 8, 15), (cx + 8, 15), (cx + 9, 28), (cx - 9, 28)], fill=C(suit))   # 몸통(정장)
    d.line([cx - 7, 16, cx - 8, 27], fill=C(lit))
    d.polygon([(cx - 2, 15), (cx + 2, 15), (cx, 21)], fill=C("P08"))     # 셔츠 깃
    if not officer:
        d.line([cx, 17, cx, 22], fill=C("P53" if variant % 2 else "P45"))  # 넥타이
    else:
        d.rectangle([cx - 7, 18, cx - 3, 19], fill=C("P49"))              # 계급장
    d.line([cx - 4, 15, cx + 1, 23], fill=C("P02"))                      # 신분증 끈
    d.rectangle([cx + 1, 22, cx + 5, 26], fill=C("P09")); d.line([cx + 1, 22, cx + 5, 22], fill=C("P53"))
    for sx in (-1, 1):                                                   # 팔(소매) → 무릎 위 손뼈
        d.line([cx + sx * 8, 16, cx + sx * 9, 24], fill=C(suit), width=3)
        d.line([cx + sx * 9, 25, cx + sx * 5, 27], fill=C("P08"), width=2)
    d.rectangle([cx - 8, 28, cx - 1, 31], fill=C(suit)); d.rectangle([cx + 1, 28, cx + 8, 31], fill=C(suit))   # 허벅지
    for x0 in (cx - 7, cx + 2):                                          # 정강이 · 구두
        d.rectangle([x0, 31, x0 + 4, 38], fill=C(suit))
        d.rectangle([x0 - 1, 38, x0 + 5, 40], fill=C("P01"))
    tilt = [-2, 1, 0, 2, -1][variant % 5]
    hx, hy = cx + tilt, 9                                                 # 해골(조금 기운 고개)
    d.ellipse([hx - 6, hy - 7, hx + 6, hy + 4], fill=C("P08"))
    d.ellipse([hx - 5, hy - 6, hx + 3, hy + 1], fill=C("P09"))
    d.ellipse([hx - 4, hy - 2, hx - 1, hy + 1], fill=C("P02")); d.ellipse([hx + 1, hy - 2, hx + 4, hy + 1], fill=C("P02"))
    d.point((hx, hy + 2), fill=C("P03"))
    d.rectangle([hx - 3, hy + 4, hx + 3, hy + 6], fill=C("P07"))
    for x in (hx - 2, hx, hx + 2):
        d.point((x, hy + 5), fill=C("P04"))
    if not officer and variant % 3 == 1:                                  # 남은 머리카락 몇 가닥
        d.line([hx - 6, hy - 4, hx - 3, hy - 7], fill=C("P02")); d.line([hx - 2, hy - 7, hx + 3, hy - 7], fill=C("P02"))
    if officer:                                                           # 군모 + 세운 소총(W-103)
        d.rectangle([hx - 7, hy - 9, hx + 7, hy - 5], fill=C("P30")); d.line([hx - 8, hy - 5, hx + 8, hy - 5], fill=C("P28"))
        d.point((hx, hy - 7), fill=C("P49"))
        d.line([30, 4, 33, 41], fill=C("P17"), width=3); d.line([30, 4, 31, 14], fill=C("P02"), width=2)
        d.rectangle([31, 22, 34, 26], fill=C("P02"))
    for k in range(4):                                                    # 어깨 먼지
        x = rnd.randrange(cx - 8, cx + 8)
        d.point((x, 15), fill=C("P07"))
    return im


def folding_chair():
    """빈 접이 의자(1×1): 열셋째 자리 — 누군가 오지 않았다."""
    im = img(22, 34)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 29, 20, 33], fill=C("P02"))
    _chair_back(d, 2, 2)
    d.rectangle([2, 18, 19, 21], fill=C("P05")); d.line([2, 18, 19, 18], fill=C("P07"))
    for x in (3, 18):
        d.line([x, 22, x, 31], fill=C("P04"))
    return im


def bk_sofa():
    """작은 방 소파(2×1): 1970년대 갈색 인조 가죽 3인용 — 갈라진 쿠션, 팔걸이 단추. 200년 먼지."""
    im = img(62, 34)
    d = ImageDraw.Draw(im)
    d.ellipse([3, 27, 59, 33], fill=C("P02"))
    d.rectangle([2, 4, 59, 18], fill=C("P24"))                           # 등받이
    d.line([2, 4, 59, 4], fill=C("P26"))
    for x in (20, 41):
        d.line([x, 6, x, 17], fill=C("P23"))
    d.rectangle([5, 16, 56, 26], fill=C("P25"))                           # 앉는 쿠션
    d.line([5, 16, 56, 16], fill=C("P27"))
    for x in (22, 39):
        d.line([x, 17, x, 25], fill=C("P24"))
    d.line([10, 20, 15, 22], fill=C("P23")); d.line([44, 19, 48, 23], fill=C("P23"))   # 갈라진 곳
    d.point((12, 21), fill=C("P21"))
    for x0 in (0, 52):                                                    # 팔걸이
        d.rectangle([x0, 8, x0 + 9, 27], fill=C("P24")); d.line([x0, 8, x0 + 9, 8], fill=C("P26"))
        d.point((x0 + 4, 13), fill=C("P49"))
    d.line([4, 27, 4, 30], fill=C("P01")); d.line([57, 27, 57, 30], fill=C("P01"))
    return im


def bk_desk():
    """작은 방 책상(2×1): 회색 철제 사무 책상 — 서랍 셋(맨 아래 서랍에 LR-17), 검은 다이얼 전화기, 녹색 갓 전등."""
    im = img(62, 40)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 33, 60, 39], fill=C("P02"))
    d.rectangle([1, 12, 60, 16], fill=C("P06")); d.line([1, 12, 60, 12], fill=C("P08"))   # 상판
    d.rectangle([3, 16, 58, 35], fill=C("P05"))
    d.rectangle([38, 17, 56, 34], fill=C("P04"))                          # 서랍 칸
    for y in (18, 24, 30):
        d.rectangle([39, y, 55, y + 4], fill=C("P05")); d.line([45, y + 2, 49, y + 2], fill=C("P07"))
    d.rectangle([6, 18, 34, 34], fill=C("P03"))                           # 발 넣는 곳
    d.rectangle([8, 3, 19, 11], fill=C("P01")); d.ellipse([9, 4, 18, 10], fill=C("P02"))   # 다이얼 전화기
    d.ellipse([11, 5, 16, 9], fill=C("P04")); d.line([8, 3, 19, 3], fill=C("P03"))
    d.line([48, 11, 48, 3], fill=C("P04"))                                # 전등
    d.polygon([(43, 4), (53, 4), (51, 0), (45, 0)], fill=C("P30")); d.line([45, 0, 51, 0], fill=C("P31"))
    d.rectangle([24, 8, 34, 11], fill=C("P09")); d.line([25, 9, 33, 9], fill=C("P06"))      # 서류
    return im


def auth_terminal(lit=False):
    """관리자 인증 단말(1×1): 키 큰 철제 단말 함 — 둥근 CRT · 자판 · 핍-보이 대는 받침('관리자 인증' 명판).
    lit = 핍-보이를 댄 순간 녹색 화면이 켜진다(SD-03a §8.4 S3)."""
    im = img(30, 52)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 46, 28, 51], fill=C("P02"))
    d.rectangle([2, 6, 27, 48], fill=C("P12")); d.line([2, 6, 27, 6], fill=C("P14"))
    d.line([2, 7, 2, 48], fill=C("P13"))
    d.rectangle([5, 9, 24, 25], fill=C("P01"))                            # CRT
    d.rounded_rectangle([6, 10, 23, 24], 3, fill=C("P56") if lit else C("P02"))
    if lit:
        for y in (13, 16, 19):
            d.line([8, y, 8 + (y % 7) + 8, y], fill=C("P57"))
        d.rectangle([8, 21, 10, 22], fill=C("P57"))
    else:
        d.line([8, 12, 12, 12], fill=C("P03"))
    d.rectangle([4, 28, 25, 33], fill=C("P10"))                           # 자판
    for x in range(6, 24, 3):
        d.point((x, 30), fill=C("P07")); d.point((x + 1, 31), fill=C("P05"))
    d.rectangle([8, 36, 21, 41], fill=C("P49"))                           # '관리자 인증' 명판 + 받침
    d.line([9, 38, 20, 38], fill=C("P47"))
    d.rectangle([10, 42, 19, 45], fill=C("P02")); d.point((14, 43), fill=C("P54") if not lit else C("P56"))
    d.rectangle([4, 0, 25, 6], fill=C("P10")); d.line([4, 0, 25, 0], fill=C("P13"))   # 머리 함
    d.point((7, 3), fill=C("P54"))
    return im


def lectern():
    """출석부 거치대(1×1): 나무 독서대 위에 펼친 출석부(LR-28) — 열두 줄 서명."""
    im = img(26, 38)
    d = ImageDraw.Draw(im)
    d.ellipse([3, 33, 23, 37], fill=C("P02"))
    d.line([13, 16, 13, 34], fill=C("P18"), width=3)
    d.rectangle([7, 31, 19, 34], fill=C("P18"))
    d.polygon([(1, 6), (25, 6), (23, 17), (3, 17)], fill=C("P19"))         # 독서대 판
    d.polygon([(3, 2), (12, 4), (12, 15), (4, 13)], fill=C("P09"))         # 펼친 장부
    d.polygon([(23, 2), (14, 4), (14, 15), (22, 13)], fill=C("P08"))
    for k in range(5):
        d.line([5, 5 + k * 2, 10, 6 + k * 2], fill=C("P44"))
        d.line([16, 6 + k * 2, 21, 5 + k * 2], fill=C("P44"))
    return im


def duty_table():
    """당직 탁자(1×1): 작은 철 탁자 위 당직 일지 · 마른 잉크병 · 깨진 머그."""
    im = img(28, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 26, 26, 31], fill=C("P02"))
    d.rectangle([2, 10, 25, 13], fill=C("P06")); d.line([2, 10, 25, 10], fill=C("P08"))
    for x in (4, 23):
        d.line([x, 14, x, 28], fill=C("P04"))
    d.rectangle([5, 4, 16, 10], fill=C("P44")); d.rectangle([6, 5, 15, 9], fill=C("P09"))   # 일지
    d.line([7, 6, 13, 6], fill=C("P05")); d.line([7, 8, 11, 8], fill=C("P05"))
    d.rectangle([19, 5, 23, 10], fill=C("P08")); d.line([19, 5, 23, 5], fill=C("P09"))     # 머그
    d.line([20, 6, 21, 9], fill=C("P03"))
    return im


def shower_stall():
    """샤워장(1×1): 흰 타일 칸 · 녹슨 샤워 꼭지 · 반쯤 걷힌 비닐 커튼."""
    im = img(32, 52)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 30, 48], fill=C("P08"))
    for y in range(4, 48, 6):
        d.line([1, y, 30, y], fill=C("P07"))
    for x in range(1, 31, 6):
        d.line([x, 2, x, 48], fill=C("P07"))
    d.line([8, 8, 15, 8], fill=C("P05")); d.ellipse([14, 7, 19, 11], fill=C("P05"))   # 꼭지
    d.line([16, 11, 16, 20], fill=C("P25"))                               # 녹물 줄
    d.line([0, 1, 31, 1], fill=C("P04"))                                  # 커튼 막대
    d.polygon([(19, 2), (30, 2), (30, 47), (24, 47)], fill=C("P37"))      # 걷힌 커튼
    for x in (22, 26):
        d.line([x, 3, x + 1, 46], fill=C("P36"))
    d.rectangle([3, 44, 22, 48], fill=C("P06"))                           # 배수 턱
    d.ellipse([10, 45, 14, 47], fill=C("P02"))
    return im


def toilet_bk():
    """변기(1×1): 1970년대 흰 양변기 — 물탱크 금, 누런 물때."""
    im = img(24, 34)
    d = ImageDraw.Draw(im)
    d.ellipse([3, 28, 21, 33], fill=C("P02"))
    d.rectangle([4, 2, 19, 12], fill=C("P09")); d.line([4, 2, 19, 2], fill=C("P09")); d.line([4, 12, 19, 12], fill=C("P07"))
    d.line([8, 4, 11, 9], fill=C("P06"))                                  # 금
    d.ellipse([3, 12, 20, 28], fill=C("P09"))
    d.ellipse([6, 15, 17, 24], fill=C("P21")); d.ellipse([8, 17, 15, 22], fill=C("P22"))
    d.rectangle([8, 26, 15, 31], fill=C("P08"))
    return im


def w_mirror():
    """샤워장 거울(벽, 1칸): 얼룩진 거울에 립스틱 '23:2' — 누군가 시간을 지워 끝 자리가 없다(SD-09a ⑧-3)."""
    im = img(26, 28)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 25, 27], fill=C("P05"))
    d.rectangle([2, 2, 23, 25], fill=C("P14"))
    d.polygon([(3, 3), (10, 3), (3, 12)], fill=C("P15"))                  # 빛
    for x, y in ((18, 20), (6, 22), (20, 6)):
        d.point((x, y), fill=C("P12"))
    put_text(im, "23:2", 4, 9, "P53", size=8)
    d.line([21, 12, 23, 16], fill=C("P52"))                               # 문질러 지운 자국
    return im


def w_procedure():
    """'관리 요원 인수 절차' 게시(벽, 2칸): 액자 속 공문 — 3열 종대 그림(사람 점 12) + 호송차 그림 + 글줄."""
    im = img(60, 36)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 59, 35], fill=C("P17"))
    d.rectangle([2, 2, 57, 33], fill=C("P08"))
    d.rectangle([2, 2, 57, 8], fill=C("P44"))
    put_text(im, "인수 절차", 17, 1, "P09", size=8)
    for col in range(3):                                                  # 3열 종대
        for row in range(4):
            d.ellipse([7 + col * 6, 12 + row * 5, 9 + col * 6, 14 + row * 5], fill=C("P02"))
    d.rectangle([30, 15, 50, 24], fill=C("P30")); d.rectangle([44, 12, 50, 18], fill=C("P31"))   # 호송차 그림
    d.ellipse([32, 23, 36, 27], fill=C("P02")); d.ellipse([44, 23, 48, 27], fill=C("P02"))
    d.line([25, 19, 29, 19], fill=C("P53")); d.line([27, 17, 29, 19], fill=C("P53")); d.line([27, 21, 29, 19], fill=C("P53"))
    for y in (29, 31):
        d.line([6, y, 52, y], fill=C("P05"))
    return im


def w_bk_notice():
    """'비상 집결지 — 관계자 외 출입 금지' 스텐실 철판(벽, 2칸): 노란 바탕 검은 글, 사선 경고 띠."""
    im = img(60, 26)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 59, 25], fill=C("P01"))
    d.rectangle([1, 1, 58, 24], fill=C("P48"))
    for x in range(-24, 60, 8):                                           # 사선 띠(위·아래)
        d.polygon([(x, 1), (x + 4, 1), (x + 1, 4), (x - 3, 4)], fill=C("P01"))
        d.polygon([(x, 21), (x + 4, 21), (x + 1, 24), (x - 3, 24)], fill=C("P01"))
    put_text(im, "비상 집결지", 7, 6, "P01", size=8)
    d.line([6, 17, 53, 17], fill=C("P47"))
    return im


def air_handler():
    """공조기(2×2): 회색 철함 · 큰 팬 격자 · 덕트가 천장으로. 아직 돈다(환기 팬 소리 — SD-03a §8.4 연출)."""
    im = img(64, 66)
    d = ImageDraw.Draw(im)
    d.ellipse([3, 58, 61, 65], fill=C("P02"))
    d.rectangle([2, 10, 61, 60], fill=C("P05")); d.line([2, 10, 61, 10], fill=C("P07"))
    d.rectangle([20, 0, 42, 10], fill=C("P04")); d.line([20, 0, 42, 0], fill=C("P06"))   # 덕트
    d.ellipse([10, 16, 50, 54], fill=C("P02"))
    d.ellipse([12, 18, 48, 52], fill=C("P03"))
    for k in range(4):                                                    # 팬 날개
        import math
        a = k * math.pi / 2 + 0.4
        d.polygon([(30, 35), (30 + 16 * math.cos(a), 35 + 16 * math.sin(a)), (30 + 12 * math.cos(a + 0.6), 35 + 12 * math.sin(a + 0.6))], fill=C("P06"))
    d.ellipse([27, 32, 33, 38], fill=C("P07"))
    for y in range(20, 52, 4):
        d.line([14, y, 46, y], fill=C("P04"))
    d.rectangle([52, 18, 58, 30], fill=C("P03")); d.point((55, 21), fill=C("P56"))   # 운전 등(초록)
    return im


def generator_bk():
    """비상 발전기(2×1): 국방색 디젤 발전기 — 연료 계기 바늘이 0에 붙어 있다."""
    im = img(62, 42)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 35, 60, 41], fill=C("P02"))
    d.rectangle([2, 8, 59, 37], fill=C("P29")); d.line([2, 8, 59, 8], fill=C("P31"))
    d.rectangle([6, 12, 30, 32], fill=C("P28"))                           # 엔진 격자
    for y in range(14, 31, 3):
        d.line([7, y, 29, y], fill=C("P30"))
    d.ellipse([36, 13, 50, 27], fill=C("P01")); d.ellipse([37, 14, 49, 26], fill=C("P09"))   # 연료 계기
    d.line([43, 20, 38, 23], fill=C("P53")); put_text(im, "0", 38, 14, "P02", size=8)
    d.rectangle([52, 2, 56, 10], fill=C("P03"))                           # 배기관
    d.rectangle([34, 30, 56, 34], fill=C("P02"))
    return im


def w_vent():
    """환기구 격자(벽, 1칸): 큰 철 격자 — 나사 하나가 빠져 있다(조사 두 번이면 뜯긴다 · 윤중제 배수로로)."""
    im = img(30, 26)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 29, 25], fill=C("P03"))
    d.rectangle([2, 2, 27, 23], fill=C("P01"))
    for x in range(4, 27, 3):
        d.line([x, 3, x, 22], fill=C("P05"))
    for x, y in ((1, 1), (28, 1), (1, 24)):
        d.point((x, y), fill=C("P07"))
    d.point((28, 24), fill=C("P25"))                                       # 빠진 나사 자리(녹)
    return im


def gun_locker():
    """경비 무기함(1×1): 국방색 철 사물함 · 맹꽁이 자물쇠 · '무기' 스텐실."""
    im = img(28, 52)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 46, 26, 51], fill=C("P02"))
    d.rectangle([2, 2, 25, 48], fill=C("P30")); d.line([2, 2, 25, 2], fill=C("P32"))
    d.line([13, 3, 13, 47], fill=C("P28"))
    for y in (6, 9, 12):
        d.line([5, y, 11, y], fill=C("P28")); d.line([16, y, 22, y], fill=C("P28"))
    d.rectangle([11, 24, 16, 29], fill=C("P05")); d.arc([11, 20, 16, 27], 180, 360, fill=C("P06"))
    put_text(im, "무기", 6, 34, "P09", size=8)
    return im


def convoy_truck(prisoner=False):
    """계엄군 호송차(3×2, 바깥): 국방색 트럭 — 뒤 칸은 철창 호송 칸, 문에 자물쇠(하도윤, SD-03a §8.4 S5). 앞 유리엔 '계엄' 띠.
    prisoner = 철창 안에 웅크려 앉은 사람 그림자(볼트 작업복 파랑이 창살 사이로 보인다)."""
    im = img(100, 74)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 64, 96, 73], fill=C("P02"))
    d.rectangle([4, 10, 66, 58], fill=C("P29")); d.line([4, 10, 66, 10], fill=C("P31"))   # 호송 칸
    d.rectangle([8, 16, 62, 48], fill=C("P01"))
    for x in range(10, 62, 6):                                            # 철창
        d.line([x, 16, x, 48], fill=C("P05"))
    if prisoner:                                                          # 창살 뒤 웅크린 사람(먼저 그리고 창살을 덧그린다)
        d.ellipse([22, 26, 32, 36], fill=C("P02"))
        d.rectangle([20, 34, 36, 46], fill=C("P44")); d.line([20, 34, 36, 34], fill=C("P45"))
        d.rectangle([24, 41, 36, 46], fill=C("P49"))
        for x in range(10, 62, 6):
            d.line([x, 16, x, 48], fill=C("P05"))
    d.line([8, 30, 62, 30], fill=C("P05"))
    d.rectangle([28, 48, 42, 58], fill=C("P28")); d.rectangle([33, 50, 37, 54], fill=C("P06"))   # 문 + 자물쇠
    d.rectangle([66, 22, 96, 58], fill=C("P30")); d.line([66, 22, 96, 22], fill=C("P32"))        # 운전석
    d.rectangle([70, 26, 92, 38], fill=C("P13")); d.line([70, 26, 92, 26], fill=C("P15"))
    d.rectangle([70, 26, 92, 28], fill=C("P49"))                          # '계엄' 띠
    for x in (16, 52, 80):                                                # 바퀴
        d.ellipse([x - 8, 54, x + 8, 70], fill=C("P01")); d.ellipse([x - 4, 58, x + 4, 66], fill=C("P05"))
    d.rectangle([92, 44, 98, 50], fill=C("P49"))                          # 전조등
    return im


def bunker_hatch():
    """벙커 해치(2×1, 바깥 · 월드 문): 환승 정류장 승강장 바닥의 녹슨 철판 해치가 열려 있고, 가파른 계단이 어둠으로 내려간다."""
    im = img(64, 46)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 10, 61, 45], fill=C("P05"))                           # 해치 틀(콘크리트)
    d.line([2, 10, 61, 10], fill=C("P07"))
    d.rectangle([7, 14, 56, 44], fill=C("P01"))
    for i in range(6):                                                    # 계단(아래 = 남쪽이 입구, 위로 깊다)
        y = 44 - i * 5
        col = ["P05", "P04", "P04", "P03", "P02", "P02"][i]
        d.rectangle([8, y - 3, 55, y], fill=C(col)); d.line([8, y - 3, 55, y - 3], fill=C("P06" if i < 2 else "P03"))
    d.polygon([(7, 0), (56, 0), (56, 12), (7, 12)], fill=C("P25"))         # 젖혀 세운 해치 뚜껑(녹)
    d.line([7, 0, 56, 0], fill=C("P26"))
    for x in range(10, 56, 8):
        d.line([x, 2, x + 4, 10], fill=C("P24"))
    d.rectangle([28, 4, 35, 8], fill=C("P02"))
    return im


def drain_outlet():
    """윤중제 배수구(2×1, 바깥 · 월드 문): 둑 아래 콘크리트 암거 입 — 쇠창살 하나가 뜯겨 사람이 드나들 만하다. 바닥에 물이 고였다."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 6, 63, 43], fill=C("P06"))                            # 둑 옹벽
    d.line([0, 6, 63, 6], fill=C("P08"))
    for x in (10, 30, 52):
        d.line([x, 7, x - 2, 20], fill=C("P05"))
    d.ellipse([10, 14, 53, 54], fill=C("P01"))                            # 암거 입(아치)
    d.rectangle([10, 34, 53, 43], fill=C("P01"))
    d.arc([10, 14, 53, 54], 180, 360, fill=C("P04"), width=2)
    for x in range(16, 50, 6):                                            # 쇠창살(가운데 둘은 뜯김)
        if x in (28, 34):
            continue
        d.line([x, 20, x, 43], fill=C("P05"))
    d.line([28, 40, 22, 43], fill=C("P25")); d.line([34, 41, 40, 43], fill=C("P25"))   # 뜯겨 휜 창살
    d.rectangle([12, 40, 51, 43], fill=C("P35")); d.line([14, 40, 49, 40], fill=C("P37"))   # 고인 물
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_BK = {
    **{f"seated_{i}": _r((lambda i=i: seated_remains(i)), 1, 1, down=-2) for i in range(5)},
    "seated_officer": _r(lambda: seated_remains(2, officer=True), 1, 1, down=-2),
    "folding_chair": _r(folding_chair, 1, 1, down=-2),
    "bk_sofa": _r(bk_sofa, 2, 1),
    "bk_desk": _r(bk_desk, 2, 1),
    "auth_terminal": _r(auth_terminal, 1, 1),
    "lectern": _r(lectern, 1, 1),
    "duty_table": _r(duty_table, 1, 1),
    "shower_stall": _r(shower_stall, 1, 1),
    "toilet_bk": _r(toilet_bk, 1, 1),
    "w_mirror": _r(w_mirror, 1, 0, "wall", dx=3, dy=8),
    "w_procedure": _r(w_procedure, 2, 0, "wall", dx=2, dy=6),
    "w_bk_notice": _r(w_bk_notice, 2, 0, "wall", dx=2, dy=10),
    "w_vent": _r(w_vent, 1, 0, "wall", dx=1, dy=14),
    "air_handler": _r(air_handler, 2, 2),
    "generator_bk": _r(generator_bk, 2, 1),
    "gun_locker": _r(gun_locker, 1, 1),
    "convoy_truck": _r(convoy_truck, 3, 2),
    "convoy_truck_p": _r(lambda: convoy_truck(True), 3, 2),
    "bunker_hatch": _r(bunker_hatch, 2, 1, down=2),
    "drain_outlet": _r(drain_outlet, 2, 1, down=2),
}
STATES_BK = {"auth_terminal": {"lit": lambda: auth_terminal(True)}}
