"""R01 비표시 퀘스트 소품(단계 1-12g — UQ-01 24시 · UQ-02 백구의 밥그릇 · UQ-03 다리목 하사의 배급표 · UQ-05 누렁이, SD-05 §3.3 · SD-16 아이작풍).
  tube_register   번개24 진공관 금전등록기 계산대(2×1) — 청솔 하늘청 계산대 · 진공관 넷 유리창 · 붉은 '점포 코드' 등 · 열쇠 구멍 · 영수증 말이
                  상태 fixed(진공관 주황 빛 · 초록 등 · 서랍 반쯤) · gutted(앞판 뜯김 · 진공관 깨짐 · 빈 서랍 · 흩어진 영수증)
  cold_case       번개24 냉장 진열대(2×1) — 이중 유리문 · 꺼진 형광등 · 빈 칸과 쓰러진 병 · 문 손잡이에 감긴 쇠줄 · 붉은 '회선 잠김' 딱지
                  상태 lit(형광등 · 냉기 서림 · 번개사이다 줄 · 쇠줄 풀림)
  w_rice_chart    냉장고 문 삼각김밥 진열 표(벽, 1칸) — 2077-10-23 날짜 칸 · 시간마다 체크 · 마지막 체크 22:00
  culvert         남부순환로 밑 빗물 배수구(2×1) — 콘크리트 관 입구 · 어두운 안 · 가는 물줄기 · 이끼 · 철망 조각
  pup_nest        배수구 뒤 새끼 둥지(1×1) — 마른 풀 · 넝마 · 밥 찌꺼기(백구가 물어 온 것) · 상태 empty(눌린 자리만)
  rope_snap       끊긴 고삐와 흩어진 짐(1×1, 덧그림) — 해진 밧줄 끝 · 엎어진 짐 꾸러미 · 수송대 꼬리표
  w_soldier_photo 2077년 군복 소년 사진 액자(벽, 1칸) — 나무 액자 · 바랜 사진 속 원정군 제복 · 액자 귀퉁이 검은 리본
  v24_counter     노량진 번개24 로봇 창구(2×1) — 하늘청 계산대 · 배급표 투입구 · 청솔 상표 · '적립 종료' 딱지 · 영수증 걸이
  dog_bowl        백구 밥그릇(덧그림) — 양은 그릇 · 상태 half(보리밥이 반쯤 남음)
  paw_prints      진흙 발자국 줄(덧그림) — 개천 회색 진흙, 아랫문 쪽으로
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from props_bc_in import box3, WOOD

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
CHEONG = ["P43", "P44", "P45", "P46"]                         # 청솔 하늘청 4단(어두움 → 밝음)


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def tube_register(state=""):
    """진공관 금전등록기 계산대(62×50): 하늘청 계산대(앞면 주황 띠 · 번개 꺾쇠) 위 회색 등록기 — 유리창 속 진공관 넷 · 숫자 창 · 열쇠 구멍.
    기본 = 잠김(진공관 꺼짐 · 붉은 등) · fixed = 진공관 주황 빛 · 초록 등 · 서랍 반쯤 열림 · gutted = 앞판 뜯겨 매달림 · 깨진 관 · 빈 서랍."""
    im = img(62, 50)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 60, 47)
    box3(d, 1, 18, 60, 46, 6, CHEONG)                                            # 계산대
    d.rectangle([1, 33, 60, 35], fill=C("P27")); d.line([1, 36, 60, 36], fill=C("P26"))   # 주황 띠
    d.line([27, 32, 30, 36], fill=C("P09")); d.line([30, 36, 33, 32], fill=C("P09"))       # 번개 꺾쇠
    d.rectangle([5, 39, 14, 43], fill=C("P09")); d.line([6, 41, 12, 41], fill=C("P05"))    # 계산대 앞 '어서 오세요' 딱지
    # 영수증 말이(왼쪽)
    d.rectangle([6, 12, 12, 19], fill=C(INK)); d.rectangle([7, 13, 11, 18], fill=C("P08"))
    d.line([9, 18, 9, 22], fill=C("P09"))
    # 등록기 몸
    x0, y0 = 22, 2
    d.rounded_rectangle([x0, y0, x0 + 30, y0 + 20], 3, fill=C(INK))
    d.rounded_rectangle([x0 + 1, y0 + 1, x0 + 29, y0 + 19], 3, fill=C("P05"))
    d.line([x0 + 2, y0 + 1, x0 + 27, y0 + 1], fill=C("P07"))
    if state == "gutted":
        d.rectangle([x0 + 3, y0 + 3, x0 + 27, y0 + 10], fill=C("P02"))           # 뜯긴 유리창 자리
        for i, x in enumerate(range(x0 + 5, x0 + 26, 6)):
            d.line([x, y0 + 9, x + (1 if i % 2 else -1), y0 + 5 + i % 2], fill=C("P06"))   # 깨진 관 밑동
        d.polygon([(x0 + 2, y0 + 19), (x0 + 12, y0 + 19), (x0 + 6, y0 + 27)], fill=C("P04"))   # 앞판 매달림
        d.line([x0 + 6, y0 + 27, x0 + 12, y0 + 19], fill=C(INK))
        d.rectangle([x0 + 14, y0 + 20, x0 + 29, y0 + 25], fill=C(INK)); d.rectangle([x0 + 15, y0 + 21, x0 + 28, y0 + 24], fill=C("P02"))   # 빈 서랍
        for (sx, sy) in ((4, 26), (16, 24), (46, 25), (55, 28)):
            d.rectangle([sx, sy, sx + 3, sy + 2], fill=C("P09")); d.point((sx + 1, sy + 1), fill=C("P05"))   # 흩어진 영수증
        d.point((x0 + 24, y0 + 14), fill=C("P53"))                             # 꺼진 등
        return im
    # 유리창 속 진공관 넷
    d.rectangle([x0 + 3, y0 + 3, x0 + 27, y0 + 10], fill=C("P02"))
    for i, x in enumerate(range(x0 + 5, x0 + 26, 6)):
        on = state == "fixed"
        d.rounded_rectangle([x - 1, y0 + 4, x + 2, y0 + 9], 1, fill=C("P34" if not on else "P59"))
        d.line([x, y0 + 6, x + 1, y0 + 6], fill=C("P05" if not on else "P60"))
        if on:
            d.point((x, y0 + 5), fill=C("P50"))
    d.line([x0 + 4, y0 + 4, x0 + 4, y0 + 8], fill=C("P15"))                     # 유리 반사
    # 숫자 창 · 키 줄
    d.rectangle([x0 + 3, y0 + 12, x0 + 15, y0 + 15], fill=C(INK))
    if state == "fixed":
        for k in range(4):
            d.point((x0 + 5 + k * 3, y0 + 13), fill=C("P56"))
    for x in range(x0 + 4, x0 + 16, 3):
        d.rectangle([x, y0 + 17, x + 1, y0 + 18], fill=C("P08"))
    # 등 · 열쇠 구멍
    lamp = "P56" if state == "fixed" else "P53"
    d.ellipse([x0 + 21, y0 + 12, x0 + 25, y0 + 16], fill=C(INK)); d.ellipse([x0 + 22, y0 + 13, x0 + 24, y0 + 15], fill=C(lamp))
    d.ellipse([x0 + 19, y0 + 16, x0 + 21, y0 + 18], fill=C(INK))
    if state == "fixed":                                                         # 서랍 반쯤
        d.rectangle([x0 + 3, y0 + 20, x0 + 27, y0 + 24], fill=C(INK)); d.rectangle([x0 + 4, y0 + 21, x0 + 26, y0 + 23], fill=C("P06"))
        for x in range(x0 + 6, x0 + 25, 5):
            d.line([x, y0 + 21, x + 2, y0 + 21], fill=C("P56"))
    return im


def cold_case(state=""):
    """냉장 진열대(62×60): 이중 유리문 · 위 상표 띠(번개24) · 안은 어둡고 칸이 비었다 · 쓰러진 병 하나 · 손잡이에 감긴 쇠줄과 자물쇠 ·
    붉은 '회선 잠김' 딱지. lit = 형광등이 켜져 유리에 냉기 서림 · 번개사이다(노랑 병) 줄 · 쇠줄 풀림."""
    im = img(62, 60)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 60, 57)
    box3(d, 1, 6, 60, 56, 3, CHEONG)
    d.rectangle([3, 0, 58, 7], fill=C("P27")); d.line([5, 3, 56, 3], fill=C("P09"))       # 상표 띠
    d.line([28, 1, 30, 5], fill=C("P09")); d.line([30, 5, 32, 1], fill=C("P09"))
    lit = state == "lit"
    for gx in (4, 31):                                                           # 유리문 둘
        d.rectangle([gx, 11, gx + 26, 53], fill=C(INK))
        d.rectangle([gx + 1, 12, gx + 25, 52], fill=C("P33" if not lit else "P15"))
        rnd = random.Random(gx)
        for y in (14, 24, 34, 44):
            d.line([gx + 1, y + 8, gx + 25, y + 8], fill=C("P05" if not lit else "P08"))
            for x in range(gx + 2, gx + 24, 4):
                if lit:
                    d.rectangle([x, y + 2, x + 2, y + 7], fill=C("P49")); d.point((x + 1, y + 1), fill=C("P07"))
                    d.point((x, y + 3), fill=C("P50"))
                elif rnd.random() < 0.12:
                    d.rectangle([x, y + 5, x + 4, y + 7], fill=C("P04"))         # 쓰러진 빈 병
        if lit:
            d.line([gx + 2, 13, gx + 24, 13], fill=C("P09"))                     # 형광등
            for k in range(4):                                                    # 서린 냉기
                d.point((gx + 4 + k * 6, 50 - k), fill=C("P09"))
        d.line([gx + 2, 14, gx + 2, 44], fill=C("P34" if not lit else "P09"))    # 유리 반사
    d.rectangle([28, 26, 29, 38], fill=C("P07")); d.rectangle([32, 26, 33, 38], fill=C("P07"))   # 손잡이
    if not lit:
        for y in range(27, 37, 2):                                               # 감긴 쇠줄 · 자물쇠
            d.line([26, y, 35, y + 1], fill=C("P06")); d.point((30, y), fill=C(INK))
        d.rectangle([28, 37, 33, 42], fill=C(INK)); d.rectangle([29, 38, 32, 41], fill=C("P48"))
        d.rectangle([40, 15, 52, 20], fill=C("P53")); d.line([42, 17, 50, 17], fill=C("P09"))    # '회선 잠김' 딱지
    return im


def w_rice_chart():
    """삼각김밥 진열 표(벽, 26×22): 칸 줄 표 · 위 날짜 '2077.10.23' 자리 · 시간 칸 체크(마지막이 22시) · 자석 둘."""
    im = img(26, 22)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 1, 25, 21], fill=C("P09")); d.line([0, 21, 25, 21], fill=C("P07"))
    d.rectangle([2, 3, 23, 5], fill=C("P27"))
    for k in range(4):
        d.point((4 + k * 2, 4), fill=C("P09"))
    for y in range(8, 20, 3):
        d.line([2, y, 23, y], fill=C("P07"))
    for x in (9, 16):
        d.line([x, 6, x, 20], fill=C("P07"))
    for i, y in enumerate(range(9, 20, 3)):                                     # 체크 — 마지막 줄은 비었다
        if i < 3:
            d.line([11, y + 1, 12, y + 2], fill=C("P45")); d.line([12, y + 2, 14, y], fill=C("P45"))
    d.ellipse([1, 0, 4, 3], fill=C("P53")); d.ellipse([21, 0, 24, 3], fill=C("P46"))   # 자석
    return im


def culvert():
    """빗물 배수구(62×40): 둑 비탈에 박힌 콘크리트 관 입구(둥근 테 · 어두운 안) · 아래로 흐르는 가는 물줄기 · 이끼 · 녹슨 철망 조각."""
    im = img(62, 40)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 6, 60, 46], fill=C("P17"))                                    # 흙 둑(둥근 무더기 — 바닥 타일에 섞인다)
    d.arc([2, 6, 60, 46], 190, 350, fill=C("P18"))
    for (x, y) in ((8, 30), (52, 28), (12, 36), (49, 35)):
        d.point((x, y), fill=C("P16")); d.point((x + 1, y), fill=C("P18"))
    d.ellipse([16, 4, 46, 32], fill=C(INK))
    d.ellipse([17, 5, 45, 31], fill=C("P06"))
    d.ellipse([21, 9, 41, 27], fill=C("P02"))
    d.ellipse([24, 12, 38, 24], fill=C(INK))
    d.arc([17, 5, 45, 31], 200, 300, fill=C("P08"))
    for (x, y) in ((19, 20), (22, 26), (41, 25), (44, 18)):                    # 이끼
        d.point((x, y), fill=C("P29")); d.point((x + 1, y), fill=C("P30"))
    d.line([31, 24, 31, 39], fill=C("P61")); d.line([32, 26, 32, 39], fill=C("P62"))   # 물줄기
    d.point((31, 32), fill=C("P63")); d.point((32, 37), fill=C("P63"))
    d.line([44, 8, 52, 14], fill=C("P26")); d.line([46, 7, 54, 13], fill=C("P26"))   # 녹슨 철망
    for x in range(45, 53, 2):
        d.line([x, 8 + (x - 45) * 6 // 8, x + 1, 11 + (x - 45) * 6 // 8], fill=C("P25"))
    return im


def pup_nest(state=""):
    """새끼 둥지(32×22): 마른 풀 둥지 · 넝마 조각 · 밥 찌꺼기(흰 밥알 · 뼈 조각 — 백구가 물어 온 것). empty = 눌린 자리와 털 몇 올만."""
    im = img(32, 22)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 6, 30, 20], fill=C("P01"))
    d.ellipse([3, 7, 29, 19], fill=C("P19"))
    d.ellipse([8, 9, 24, 17], fill=C("P18"))
    rnd = random.Random(7)
    for _ in range(14):                                                          # 풀 줄기
        x = rnd.randint(4, 27); y = rnd.randint(8, 17)
        d.line([x, y, x + rnd.choice((-2, 2)), y - 2], fill=C(rnd.choice(("P20", "P21", "P17"))))
    d.polygon([(20, 8), (27, 10), (24, 14)], fill=C("P53"))                      # 넝마 조각
    if state == "empty":
        d.ellipse([11, 11, 21, 16], fill=C("P17"))
        d.point((14, 12), fill=C("P20")); d.point((17, 14), fill=C("P21"))
        return im
    for (x, y) in ((6, 15), (8, 16), (25, 16)):                                  # 밥알 · 뼈 조각
        d.point((x, y), fill=C("P09"))
    d.line([26, 15, 28, 13], fill=C("P08"))
    return im


def rope_snap():
    """끊긴 고삐와 흩어진 짐(34×22, 덧그림): 해진 밧줄 끝(올이 풀림) · 엎어진 천 꾸러미 · 끈에 매단 수송대 꼬리표(붉은 닻)."""
    im = img(34, 22)
    d = ImageDraw.Draw(im)
    d.line([2, 18, 8, 15, 13, 17, 17, 14], fill=C("P19"), width=2)
    d.line([17, 14, 19, 12], fill=C("P20")); d.line([17, 14, 20, 15], fill=C("P20")); d.point((19, 13), fill=C("P21"))
    d.rounded_rectangle([20, 8, 33, 19], 3, fill=C(INK))
    d.rounded_rectangle([21, 9, 32, 18], 3, fill=C("P23"))
    d.line([22, 13, 31, 13], fill=C("P22")); d.line([26, 9, 26, 18], fill=C("P24"))
    d.rectangle([28, 4, 32, 8], fill=C("P09")); d.line([27, 8, 29, 10], fill=C("P05"))
    d.point((30, 6), fill=C("P53")); d.point((29, 5), fill=C("P53"))
    return im


def w_soldier_photo():
    """2077 군복 소년 사진(벽, 22×24): 나무 액자 · 바랜 사진(갈색 톤) 속 원정군 정복 · 각모 · 액자 귀퉁이 검은 리본."""
    im = img(22, 24)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 2, 21, 23], fill=C(WOOD[0])); d.rectangle([1, 3, 20, 22], fill=C(WOOD[2]))
    d.rectangle([3, 5, 18, 20], fill=C("P20"))
    d.ellipse([7, 7, 13, 13], fill=C("P21"))                                    # 얼굴
    d.rectangle([7, 6, 13, 8], fill=C("P29")); d.line([6, 8, 14, 8], fill=C("P28"))   # 각모
    d.point((9, 10), fill=C("P18")); d.point((11, 10), fill=C("P18"))
    d.polygon([(5, 20), (15, 20), (14, 14), (6, 14)], fill=C("P29"))            # 정복
    d.line([10, 14, 10, 20], fill=C("P28")); d.point((8, 16), fill=C("P48"))
    d.polygon([(17, 2), (21, 2), (21, 7)], fill=C(INK))                          # 검은 리본
    d.line([18, 5, 16, 8], fill=C(INK))
    return im


def v24_counter():
    """노량진 번개24 로봇 창구(62×48): 하늘청 계산대 · 윗면 배급표 투입구(놋쇠 테) · 청솔 상표 · 붉은 '포인트 적립 종료' 딱지 ·
    영수증 걸이에 2077 영수증 하나."""
    im = img(62, 48)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 60, 45)
    box3(d, 1, 14, 60, 44, 7, CHEONG)
    d.rectangle([1, 30, 60, 32], fill=C("P27")); d.line([1, 33, 60, 33], fill=C("P26"))
    d.rectangle([10, 15, 28, 19], fill=C(INK)); d.rectangle([11, 16, 27, 18], fill=C("P48"))   # 투입구
    d.line([13, 17, 25, 17], fill=C(INK))
    d.rectangle([34, 4, 52, 15], fill=C(INK)); d.rectangle([35, 5, 51, 14], fill=C("P09"))      # 상표판
    d.line([37, 8, 49, 8], fill=C("P45")); d.line([42, 9, 44, 12], fill=C("P27")); d.line([44, 12, 46, 9], fill=C("P27"))
    d.rectangle([6, 36, 22, 41], fill=C("P53")); d.line([8, 38, 20, 38], fill=C("P09"))   # 적립 종료 딱지
    d.line([56, 4, 56, 15], fill=C("P05")); d.rectangle([54, 6, 59, 12], fill=C("P09")); d.line([55, 8, 58, 8], fill=C("P05"))   # 영수증 걸이
    return im


def dog_bowl(state=""):
    """백구 밥그릇(18×12): 찌그러진 양은 그릇 · 보리밥. 기본 = 비었다(다 먹음) · half = 반쯤 남은 보리밥(UQ-02 '사흘째 밥을 남겨')."""
    im = img(18, 12)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 3, 16, 11], fill=C(INK))
    d.ellipse([2, 4, 15, 10], fill=C("P06"))
    d.ellipse([4, 5, 13, 8], fill=C("P04"))
    d.arc([2, 4, 15, 10], 200, 330, fill=C("P08"))
    d.point((14, 7), fill=C("P05"))                                             # 찌그러진 자국
    if state == "half":
        d.ellipse([5, 5, 12, 8], fill=C("P21"))
        for (x, y) in ((6, 6), (8, 5), (10, 6), (9, 7)):
            d.point((x, y), fill=C("P09"))
    return im


def paw_prints():
    """진흙 발자국 줄(28×14, 덧그림): 회색 개천 진흙 — 네 발 두 쌍이 아랫문 쪽으로(오른쪽 위 → 왼쪽 아래)."""
    im = img(28, 14)
    d = ImageDraw.Draw(im)
    for k, (x, y) in enumerate(((22, 2), (17, 5), (11, 7), (5, 10))):
        dy = 1 if k % 2 else 0
        d.ellipse([x, y + dy, x + 2, y + 2 + dy], fill=C("P05"))
        for t in (-1, 1, 3):
            d.point((x + t, y - 1 + dy), fill=C("P04"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_UQ = {
    "tube_register": _r(tube_register, 2, 1),
    "cold_case": _r(cold_case, 2, 1, down=1),
    "w_rice_chart": _r(w_rice_chart, 1, 0, "wall", dx=3, dy=6),
    "culvert": _r(culvert, 2, 1, down=-2),
    "pup_nest": _r(pup_nest, 1, 1, down=-4),
    "rope_snap": _r(rope_snap, 0, 0, "deco"),
    "w_soldier_photo": _r(w_soldier_photo, 1, 0, "wall", dx=5, dy=4),
    "v24_counter": _r(v24_counter, 2, 1),
    "dog_bowl": _r(dog_bowl, 0, 0, "deco"),
    "paw_prints": _r(paw_prints, 0, 0, "deco"),
}

STATES_UQ = {
    "tube_register": {"fixed": lambda: tube_register("fixed"), "gutted": lambda: tube_register("gutted")},
    "cold_case": {"lit": lambda: cold_case("lit")},
    "pup_nest": {"empty": lambda: pup_nest("empty")},
    "dog_bowl": {"half": lambda: dog_bowl("half")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_uq.png"
    ims = [v["fn"]() for v in PROPS_UQ.values()] + [f() for st in STATES_UQ.values() for f in st.values()]
    W = sum(i.width for i in ims) + 6 * len(ims)
    Hh = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, Hh + 4), C("P04"))
    x = 2
    for i in ims:
        sheet.alpha_composite(i, (x, 2))
        x += i.width + 6
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    sheet.save(out)
    ok = P.allowed_set("R01") if "R01" in getattr(P, "GROUPS", {}) else None
    print(out)
