"""R01 비표시 퀘스트 소품(단계 1-12i — UQ-66 전지 하나, 냉장고 둘, SD-05 §3.30 · SD-16 아이작풍).
  blood_fridge  흑석 병원 지하 혈액은행 냉장고(2×1) — 흰 법랑 몸통 · 유리문 둘 · 안쪽 선반에 혈액 팩 · 위 붉은 핏방울 표지 · 문 위 온도 창.
                기본 = 꺼짐(온도 창 검음 · 유리에 먼지 · 팩은 검붉게 말라 붙음 · 문틈 고무가 처짐) ·
                상태 on(온도 창 호박색 '4' · 안이 푸르스름하게 밝음 · 서리 줄 · 새 팩 붉은 줄)
  cell_box      전지함(1×1) — 회색 철 상자 · 노란 방사능 딱지 · 들창 유리 너머 회색 원통에 노란 띠.
                상태 empty(들창이 열려 있고 받침대가 빔 · 끊긴 단자 두 개)
  nurse_dock    간호 로봇 충전대(1×1) — 바닥 원판 · 케이블 기둥 · 받침 고리 · 기둥 위 초록 점등.
                상태 stopped(크림색 구체가 받침에 얹혀 꺼져 있음 · 손으로 칠한 '7' · 렌즈 검음 · 점등 붉음)
  gs_spare      대기등 예비 전원 받침(1×1) — 진공관 랙 옆 낮은 철 받침 · 굵은 전선 두 가닥 · 손글씨 카드 '예비 전원 자리'.
                상태 on(받침에 핵분열 전지가 앉음 · 초록 띠가 켜짐 · 전선 끝 단자 물림)
  jet_wreck     보라매 활주로 전투기 잔해(4×3, UQ-67) — 2076년 '전시 항공 기념 광장' 전시기. 올리브 회색 동체가 비스듬히 주저앉음 · 꺾인 주익 · 수직 꼬리날개 '공군' ·
                캐노피(금 간 유리) · 동체 뒤 시험 엔진 덮개(노란 방사능 띠). 상태 core(덮개 들창이 열려 안쪽 노심이 초록으로 빛남 · 바닥에 초록 물때) ·
                sealed(들창 위에 콘크리트 판 · 철사 묶음 · 분필 '봉인') · empty(들창 열린 채 빈 받침 · 물때만) · plain(전시기 2호 — 엔진 덮개 없음 · 캐노피 열림)
  streetlamp 상태 on을 더한다(그림 본체는 props_bc.streetlamp): 전구가 살아나 호박색으로 빛남 · 기둥 아래 빛 웅덩이(UQ-67 ① 봉천 아랫마당)
  freezer_unit 상태 두 개를 더한다(그림 본체는 props_r01n.freezer_unit):
                tagged(손잡이에 각성회 붉은 천 꼬리표 '수거' — 운반조가 다녀감) · off(멎음 — 서리 · 김 없음, 대기등 램프 떼어 감, 옆 전지 들창 열림)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from props_bc_in import box3
from props_r01n import freezer_unit, CREAM
from props_site import _hull_shadow                                     # 윤곽 그림자(사용자 지적 2026-10-22 — 타원 금지)

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
ENAMEL = ["P06", "P07", "P08", "P09"]
STEEL = ["P11", "P12", "P13", "P14"]


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def _rad(d, x, y):
    """작은 노란 방사능 딱지(7×6)."""
    d.rectangle([x, y, x + 6, y + 5], fill=C("P49"))
    d.rectangle([x, y, x + 6, y + 5], outline=C("P47"))
    d.point((x + 3, y + 2), fill=C(INK))
    d.point((x + 2, y + 3), fill=C(INK)); d.point((x + 4, y + 3), fill=C(INK))
    d.point((x + 3, y + 1), fill=C(INK))


# ================================================================================================ 혈액은행 냉장고
def blood_fridge(state=""):
    """혈액은행 냉장고(64×74 — 2×1): 흰 법랑 몸통 · 유리문 둘 · 선반 넷 · 위 핏방울 표지 · 온도 창.
    기본 = 꺼짐 — 온도 창이 검고 유리에 먼지 결 · 팩은 검붉게 말라 붙음 · 왼쪽 문 고무가 처져 틈 · on = 안이 밝고 서리 · 새 팩 붉은 줄 · 온도 '4'."""
    on = state == "on"
    im = img(64, 74)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 72)
    box3(d, 3, 4, 60, 71, 7, ENAMEL)                                         # 몸통
    d.rectangle([6, 1, 57, 5], fill=C(INK)); d.rectangle([7, 2, 56, 4], fill=C("P09"))   # 머리판
    d.ellipse([9, 1, 15, 7], fill=C(INK)); d.polygon([(12, 1), (9, 5), (15, 5)], fill=C("P53"))   # 핏방울 표지
    d.ellipse([10, 3, 14, 7], fill=C("P53")); d.point((11, 4), fill=C("P54"))
    d.rectangle([40, 1, 53, 5], fill=C(INK))                                # 온도 창
    if on:
        d.rectangle([41, 2, 52, 4], fill=C("P58"))
        for (x, y) in ((47, 2), (48, 2), (48, 3), (47, 4), (48, 4), (46, 3)):  # '4'
            d.point((x, y), fill=C("P60"))
        d.point((44, 3), fill=C("P56"))                                     # 초록 전원 점
    else:
        d.rectangle([41, 2, 52, 4], fill=C("P02"))
    for i, x0 in enumerate((7, 33)):                                         # 유리문 둘
        x1 = x0 + 23
        d.rectangle([x0, 13, x1, 66], fill=C(INK))
        d.rectangle([x0 + 1, 14, x1 - 1, 65], fill=C("P14" if on else "P11"))
        for sy in (24, 36, 48, 60):                                          # 선반
            d.line([x0 + 2, sy, x1 - 2, sy], fill=C("P12" if on else "P10"))
            for k, bx in enumerate(range(x0 + 3, x1 - 3, 5)):               # 팩
                if on and not (i == 1 and sy == 60 and k > 1):
                    d.rectangle([bx, sy - 7, bx + 3, sy - 1], fill=C("P52"))
                    d.point((bx + 1, sy - 6), fill=C("P54")); d.line([bx + 1, sy - 9, bx + 1, sy - 8], fill=C("P09"))
                elif not on and (bx + sy) % 3 != 0:
                    d.rectangle([bx, sy - 6, bx + 3, sy - 1], fill=C("P51"))   # 마른 팩(검붉게 쪼그라듦)
                    d.point((bx + 2, sy - 5), fill=C("P23"))
        if on:
            for fy in (16, 30, 42, 54):                                      # 서리 줄
                d.line([x0 + 2, fy, x0 + 6, fy], fill=C("P15")); d.point((x1 - 3, fy + 1), fill=C("P15"))
            d.line([x0 + 2, 14, x0 + 2, 64], fill=C("P15"))                  # 안쪽 빛
        else:
            for k in range(6):                                               # 먼지 결
                d.line([x0 + 3 + k * 3, 15 + k * 7, x0 + 7 + k * 3, 13 + k * 7], fill=C("P12"))
        d.rectangle([x1 - 4 if i == 0 else x0 + 2, 34, x1 - 3 if i == 0 else x0 + 3, 46], fill=C("P05"))   # 손잡이
    if not on:
        d.line([30, 14, 30, 64], fill=C("P03"))                              # 처진 고무 틈
        d.line([31, 20, 31, 30], fill=C(INK))
    d.rectangle([20, 67, 43, 69], fill=C("P05"))                             # 밑 환기창
    for x in range(22, 42, 3):
        d.point((x, 68), fill=C(INK))
    return im


# ================================================================================================ 전지함
def cell_box(state=""):
    """전지함(32×44 — 1×1): 회색 철 상자 · 노란 방사능 딱지 · 들창 유리 너머 원통.
    기본 = 회색 원통에 노란 띠(예비 전지 하나) · empty = 들창이 옆으로 열려 받침이 비고 끊긴 단자 둘."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 30, 42)
    box3(d, 3, 6, 28, 41, 5, STEEL)
    d.rectangle([7, 14, 24, 36], fill=C(INK))
    if state == "empty":
        d.rectangle([8, 15, 23, 35], fill=C("P02"))
        d.rectangle([10, 31, 21, 34], fill=C("P04"))                          # 빈 받침
        d.line([12, 18, 12, 22], fill=C("P27")); d.line([19, 18, 19, 21], fill=C("P27"))   # 끊긴 단자
        d.point((12, 23), fill=C("P26")); d.point((19, 22), fill=C("P26"))
        d.polygon([(24, 14), (30, 16), (30, 38), (24, 36)], fill=C("P12"))   # 열린 들창
        d.line([24, 14, 30, 16], fill=C("P14")); d.line([26, 24, 29, 25], fill=C("P15"))
    else:
        d.rectangle([8, 15, 23, 35], fill=C("P11"))
        d.rectangle([11, 17, 20, 34], fill=C(INK))                           # 원통
        d.rectangle([12, 18, 19, 33], fill=C("P05")); d.line([13, 18, 13, 33], fill=C("P07"))
        d.rectangle([12, 24, 19, 26], fill=C("P49"))                          # 노란 띠
        d.line([10, 15, 22, 35], fill=C("P13"))                               # 유리 빛
        d.rectangle([22, 24, 23, 27], fill=C("P05"))                          # 들창 걸쇠
    _rad(d, 18, 8)
    d.line([6, 8, 13, 8], fill=C("P15")); d.line([6, 10, 11, 10], fill=C("P13"))   # 스텐실 줄('B계통')
    return im


# ================================================================================================ 간호 로봇 충전대
def nurse_dock(state=""):
    """충전대(32×46 — 1×1): 바닥 원판 · 케이블 기둥 · 받침 고리 · 기둥 머리 점등.
    기본 = 빈 받침(초록 점등) · stopped = 크림색 구체가 받침에 얹혀 꺼짐 — 손으로 칠한 '7' · 렌즈 검음 · 점등 붉음."""
    im = img(32, 46)
    d = ImageDraw.Draw(im)
    _shadow(d, 3, 29, 44)
    d.ellipse([3, 36, 29, 44], fill=C(INK)); d.ellipse([4, 36, 28, 42], fill=C("P11"))   # 원판
    d.ellipse([8, 37, 24, 41], fill=C("P12"))
    d.rectangle([24, 6, 28, 38], fill=C(INK)); d.rectangle([25, 7, 27, 37], fill=C("P12"))   # 기둥
    d.line([25, 7, 25, 37], fill=C("P14"))
    d.ellipse([23, 2, 29, 8], fill=C(INK))
    d.ellipse([24, 3, 28, 7], fill=C("P53" if state == "stopped" else "P56"))   # 점등
    d.line([27, 30, 21, 33], fill=C("P02"))                                  # 케이블
    if state == "stopped":
        d.ellipse([3, 12, 23, 34], fill=C(INK))                              # 구체
        d.ellipse([4, 13, 22, 33], fill=C("P08"))
        d.ellipse([5, 14, 15, 24], fill=C("P09"))
        d.arc([4, 13, 22, 33], 20, 160, fill=C("P06"))
        d.line([9, 18, 13, 18], fill=C("P53")); d.line([13, 18, 10, 26], fill=C("P53"))   # 손으로 칠한 '7'
        d.line([12, 18, 9, 26], fill=C("P52"))
        d.ellipse([14, 26, 20, 32], fill=C(INK)); d.point((16, 28), fill=C("P03"))   # 꺼진 렌즈
        d.line([18, 13, 20, 9], fill=C("P05")); d.ellipse([19, 7, 22, 10], fill=C("P05"))   # 확성기 안테나
        d.line([6, 32, 3, 36], fill=C("P05")); d.line([20, 32, 23, 36], fill=C("P05"))   # 늘어진 집게팔
    else:
        d.arc([7, 26, 21, 38], 180, 360, fill=C("P13"))                       # 빈 받침 고리
        d.arc([7, 27, 21, 39], 180, 360, fill=C(INK))
    return im


# ================================================================================================ 대기등 예비 전원 받침
def gs_spare(state=""):
    """예비 전원 받침(32×40 — 1×1): 낮은 철 받침 · 랙으로 가는 굵은 전선 둘 · 손글씨 카드.
    기본 = 빈 받침(카드 '예비 전원 자리') · on = 핵분열 전지가 앉고 초록 띠가 켜짐 · 전선 끝 단자 물림."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 3, 29, 38)
    box3(d, 5, 22, 26, 37, 4, STEEL)
    d.line([26, 26, 31, 10], fill=C(INK)); d.line([27, 27, 31, 14], fill=C("P02"))   # 랙으로 가는 전선
    if state == "on":
        d.rectangle([9, 4, 22, 25], fill=C(INK))                             # 전지
        d.rectangle([10, 5, 21, 24], fill=C("P05")); d.line([11, 5, 11, 24], fill=C("P07"))
        d.rectangle([10, 13, 21, 15], fill=C("P56"))                          # 초록 띠
        d.point((15, 14), fill=C("P57"))
        d.rectangle([13, 2, 18, 4], fill=C("P04"))                            # 단자 머리
        d.line([18, 3, 26, 26], fill=C("P27"))                                # 물린 집게
        _rad(d, 12, 17)
    else:
        d.rectangle([9, 19, 22, 23], fill=C(INK)); d.rectangle([10, 20, 21, 22], fill=C("P04"))   # 빈 홈
        d.line([20, 18, 23, 12], fill=C("P27")); d.point((23, 11), fill=C("P26"))   # 풀린 집게
        d.rectangle([4, 10, 15, 18], fill=C("P08"))                           # 손글씨 카드
        d.line([5, 12, 13, 12], fill=C("P03")); d.line([5, 14, 11, 14], fill=C("P03")); d.line([5, 16, 12, 16], fill=C("P03"))
        d.point((14, 10), fill=C("P53"))                                      # 압정
    return im


# ================================================================================================ 수산시장 냉동고 — 상태 둘
def freezer_tagged():
    """가동 중 냉동고 + 손잡이에 각성회 붉은 천 꼬리표('수거' — 기한 날짜 숫자 흉내)."""
    im = freezer_unit()
    d = ImageDraw.Draw(im)
    d.line([27, 50, 25, 56], fill=C("P52")); d.line([28, 50, 30, 57], fill=C("P52"))   # 매듭 끈
    d.polygon([(21, 56), (31, 56), (30, 68), (22, 67)], fill=C(INK))
    d.polygon([(22, 57), (30, 57), (29, 66), (23, 66)], fill=C("P53"))      # 붉은 천
    d.line([24, 60, 28, 60], fill=C("P09")); d.line([24, 63, 27, 63], fill=C("P09"))   # 흰 글씨 두 줄
    return im


def freezer_off():
    """멎은 냉동고: 서리 · 김 없음 · 대기등 램프를 떼어 가고 줄만 · 옆 전지 들창이 열려 빔 · 문 아래 물 고임."""
    im = img(64, 84)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 74, 62, 83], fill=C("P02"))
    box3(d, 3, 10, 60, 78, 10, ["P05", "P06", "P07", "P08"])               # 칠이 바랜 몸통
    for x in range(8, 58, 6):                                              # 냉각 핀(녹)
        d.rectangle([x, 2, x + 3, 12], fill=C("P11")); d.line([x, 2, x + 3, 2], fill=C("P25"))
    d.rectangle([12, 26, 50, 74], fill=C("P06")); d.rectangle([12, 26, 50, 28], fill=C("P07"))
    d.line([31, 26, 31, 74], fill=C("P04"))
    d.rectangle([24, 44, 27, 58], fill=C("P11")); d.rectangle([35, 44, 38, 58], fill=C("P11"))
    d.rectangle([4, 30, 10, 46], fill=C(INK)); d.rectangle([5, 31, 9, 45], fill=C("P02"))   # 열린 전지 들창(빔)
    d.polygon([(0, 30), (4, 30), (4, 46), (0, 44)], fill=C("P06"))
    d.line([57, 36, 57, 41], fill=C("P05")); d.point((57, 42), fill=C("P04"))   # 잘린 대기등 줄
    d.polygon([(52, 30), (58, 30), (55, 25)], fill=C("P48")); d.point((55, 28), fill=C(INK))
    for (x, y) in ((16, 70), (44, 66), (30, 72)):                           # 녹물 자국
        d.line([x, y - 6, x, y], fill=C("P25"))
    d.ellipse([18, 77, 46, 83], fill=C("P34")); d.ellipse([22, 78, 40, 81], fill=C("P35"))   # 물 고임
    return im


# ================================================================================================ 보라매 전투기 잔해
OLIVE = ["P28", "P29", "P30", "P31"]


def jet_wreck(state=""):
    """전투기 잔해(136×96 — 4×3): 비스듬히 주저앉은 동체(올리브 회색) · 꺾인 주익 · 수직 꼬리 '공군' · 금 간 캐노피 · 시험 엔진 덮개.
    core = 들창 열림 · 노심 초록 빛 · 물때 / sealed = 콘크리트 판 · 철사 · 분필 / empty = 빈 받침 / plain = 전시기 2호(엔진 덮개 없음 · 캐노피 열림)."""
    im = img(136, 96)
    d = ImageDraw.Draw(im)
    body = [(10, 60), (24, 44), (96, 38), (124, 46), (128, 58), (112, 70), (30, 74)]
    _hull_shadow(im, body, 4, 6)
    d.polygon([(44, 58), (10, 86), (18, 90), (60, 66)], fill=C(INK))            # 꺾인 왼 주익(아래)
    d.polygon([(45, 59), (13, 85), (18, 88), (58, 66)], fill=C("P29"))
    d.line([(20, 84), (50, 64)], fill=C("P31"))
    d.polygon([(60, 44), (40, 14), (48, 12), (72, 42)], fill=C(INK))            # 오른 주익(위로 뻗음)
    d.polygon([(61, 44), (42, 16), (47, 14), (71, 42)], fill=C("P30"))
    d.polygon(body, fill=C(INK))                                                # 동체
    d.polygon([(12, 60), (25, 46), (95, 40), (122, 48), (126, 58), (111, 68), (31, 72)], fill=C("P30"))
    d.polygon([(25, 46), (95, 40), (122, 48), (96, 50), (30, 56)], fill=C("P31"))   # 윗면 빛
    d.line([(31, 72), (111, 68)], fill=C("P28"))
    for x in range(34, 110, 9):                                                  # 패널 이음
        d.line([x, 50, x - 2, 70], fill=C("P29"))
    d.polygon([(104, 44), (110, 14), (118, 14), (120, 46)], fill=C(INK))         # 수직 꼬리
    d.polygon([(105, 44), (111, 16), (117, 16), (119, 45)], fill=C("P29"))
    d.rectangle([111, 22, 116, 30], fill=C("P09")); d.point((113, 25), fill=C("P53")); d.point((114, 27), fill=C("P45"))   # 꼬리 휘장
    d.ellipse([18, 46, 46, 64], fill=C(INK))                                     # 캐노피
    if state == "plain":
        d.chord([20, 47, 44, 63], 180, 360, fill=C("P35")); d.rectangle([20, 55, 44, 58], fill=C("P02"))   # 열린 캐노피(틀만)
    else:
        d.ellipse([20, 47, 44, 63], fill=C("P35")); d.ellipse([22, 48, 36, 58], fill=C("P36"))
        d.line([(24, 50), (34, 60)], fill=C("P37")); d.line([(30, 49), (40, 58)], fill=C("P02"))   # 금
    d.polygon([(12, 60), (6, 64), (8, 70), (18, 68)], fill=C("P04"))             # 기수 콘(찌그러짐)
    for (x, y) in ((40, 66), (70, 46), (92, 64), (56, 70)):                      # 녹 · 그을음
        d.ellipse([x, y, x + 5, y + 3], fill=C("P25" if x % 2 else "P02"))
    if state != "plain":
        d.rectangle([80, 52, 108, 68], fill=C(INK))                               # 시험 엔진 덮개
        d.rectangle([81, 53, 107, 67], fill=C("P12"))
        d.line([81, 53, 107, 53], fill=C("P14"))
        d.rectangle([82, 60, 106, 62], fill=C("P49"))                             # 노란 방사능 띠
        for x in range(84, 106, 6):
            d.point((x, 61), fill=C(INK))
        _rad(d, 98, 54)
        if state == "core":
            d.rectangle([86, 56, 100, 66], fill=C(INK))                           # 열린 들창
            d.rectangle([87, 57, 99, 65], fill=C("P02"))
            d.rectangle([89, 58, 97, 64], fill=C("P55")); d.rectangle([91, 59, 95, 63], fill=C("P56")); d.point((93, 61), fill=C("P57"))   # 노심
            d.polygon([(100, 56), (106, 54), (106, 66), (100, 66)], fill=C("P13"))   # 젖혀진 들창
            for (x, y) in ((84, 72), (92, 76), (100, 74), (88, 80)):             # 바닥 초록 물때
                d.ellipse([x, y, x + 6, y + 2], fill=C("P55"))
            d.point((94, 70), fill=C("P57"))
        elif state == "sealed":
            d.rectangle([84, 55, 104, 67], fill=C(INK))                           # 콘크리트 판
            d.rectangle([85, 56, 103, 66], fill=C("P07")); d.line([85, 56, 103, 56], fill=C("P08"))
            d.line([86, 58, 102, 64], fill=C("P05")); d.line([86, 64, 102, 58], fill=C("P05"))   # 철사 묶음
            d.line([89, 61, 93, 61], fill=C("P09")); d.line([95, 61, 99, 61], fill=C("P09"))     # 분필 '봉인'
        elif state == "empty":
            d.rectangle([86, 56, 100, 66], fill=C(INK))
            d.rectangle([87, 57, 99, 65], fill=C("P02"))
            d.rectangle([90, 62, 96, 64], fill=C("P04"))                          # 빈 받침
            d.polygon([(100, 56), (106, 54), (106, 66), (100, 66)], fill=C("P13"))
            for (x, y) in ((86, 74), (96, 76)):
                d.ellipse([x, y, x + 5, y + 2], fill=C("P30"))                    # 마른 물때
    return im


def streetlamp_on():
    """살아난 가로등: 전구 호박색 · 유리 밝음 · 기둥 아래 빛 웅덩이(점무늬)."""
    from props_bc import streetlamp as _streetlamp_base                     # 늦은 가져오기(props_bc가 이 묶음을 가져온다 — 순환 방지)
    im = _streetlamp_base()
    d = ImageDraw.Draw(im)
    d.rectangle([20, 2, 29, 8], fill=C("P59")); d.rectangle([22, 3, 27, 7], fill=C("P60")); d.point((24, 4), fill=C("P50"))
    d.rectangle([22, 8, 27, 10], fill=C("P49"))
    for y in range(92, 100):
        for x in range(2, 28):
            if (x - 15) ** 2 / 2.2 + (y - 96) ** 2 < 36 and (x + y) % 2 == 0 and im.getpixel((x, y))[3] == 0:
                im.putpixel((x, y), C("P58"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_UQ3 = {
    "blood_fridge": _r(blood_fridge, 2, 1, down=0),
    "cell_box": _r(cell_box, 1, 1),
    "nurse_dock": _r(nurse_dock, 1, 1, down=-2),
    "gs_spare": _r(gs_spare, 1, 1, down=-2),
    "jet_wreck": _r(jet_wreck, 4, 3, down=-4),
}
STATES_UQ3 = {
    "blood_fridge": {"on": lambda: blood_fridge("on")},
    "cell_box": {"empty": lambda: cell_box("empty")},
    "nurse_dock": {"stopped": lambda: nurse_dock("stopped")},
    "gs_spare": {"on": lambda: gs_spare("on")},
    "freezer_unit": {"tagged": freezer_tagged, "off": freezer_off},
    "jet_wreck": {"core": lambda: jet_wreck("core"), "sealed": lambda: jet_wreck("sealed"), "empty": lambda: jet_wreck("empty"), "plain": lambda: jet_wreck("plain")},
    "streetlamp": {"on": streetlamp_on},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_uq3.png"
    tiles = [("blood_fridge", ""), ("blood_fridge", "on"), ("cell_box", ""), ("cell_box", "empty"),
             ("nurse_dock", ""), ("nurse_dock", "stopped"), ("gs_spare", ""), ("gs_spare", "on"),
             ("freezer_unit", ""), ("freezer_unit", "tagged"), ("freezer_unit", "off")]
    W = 72 * len(tiles)
    sheet = Image.new("RGBA", (W, 96), (60, 56, 52, 255))
    for i, (n, s) in enumerate(tiles):
        if n == "freezer_unit":
            p = freezer_unit() if not s else STATES_UQ3[n][s]()
        else:
            p = STATES_UQ3[n][s]() if s else PROPS_UQ3[n]["fn"]()
        sheet.alpha_composite(p, (i * 72 + 4, 6))
    sheet.resize((W * 3, 96 * 3), Image.NEAREST).save(out)
    print(out)
