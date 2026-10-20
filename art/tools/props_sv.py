"""볼트 S-02 '끝없는 선거' · 영등포 역전 시장 소품(단계 1-11l SQ-S13, SD-09a L-R02-04 L924 · L-R02-12 L983 · SD-02 §S-02 · SD-16 아이작풍).
  원문 앵커: 아트리움 = 선거 벽보 여섯(정당명 없이 기호 1~6과 사진 틀만 — SD-18 민감 표현) · 투표함 수천 개 · 계단의 두 무리 해골(서로 다른 색 띠) ·
  개표실 = 세진 진공관 개표기(LR-42 '제751차 개표 결과') · 오버시어실 = 명패 벽 · 거주 구역 = 2131 내전 흔적 ·
  지상 = 공원 남쪽 숲의 환기탑과 반쯤 묻힌 톱니 문 · 역전 시장 = 아치 간판 '영등포시장 — 전시 공동 구매 협력 시장'.
    w_poster_vote  선거 벽보(벽 1칸): 기호 숫자 · 빈 사진 틀 · 이름 줄은 비어 있음 / 상태 2~6(기호) · pledge(손글씨 공약 쪽지를 덧붙임)
    ballot_pile    투표함 더미(2×1): 흰 상자 수십 개가 무너지듯 쌓임 · 봉인 · 먼지
    ballot_box_sv  투표함(1×1): 받침대 위 흰 상자 · 투입구 · 붉은 봉인 / 상태 full(투입구에 용지가 꽂힘)
    vote_booth     기표소 칸막이(1×1): 회색 틀 · 짧은 커튼 / 상태 in(커튼이 닫히고 발이 보임)
    reg_stand_sv   후보 등록부(1×1): 받침대 위 펼친 큰 장부 · 끈에 매단 펜
    counter_sv     진공관 개표기(2×1): 진공관 줄 · 숫자 창 · 아래 출력구에서 종이 / 상태 off(불 꺼짐)
    printout_pile  재검표 출력지 더미(1×1): 접힌 종이 띠 / 상태 more · heap(날마다 쌓임)
    w_board_vote   공고 칠판(벽 2칸): '제752차 선거 — 유권자를 기다립니다' / 상태 fail(무산 · 재공고) · term(임기 4년 · 다음 선거) · next(제753차)
    w_plaque_wall  명패 벽(벽 3칸): 작은 놋쇠 명패 줄 · 맨 끝 빈 틀 하나
    skel_sash      띠 두른 해골(1×1, 바닥): 쓰러진 해골 · 파란 띠 / 상태 orange(주황 띠)
    barricade_sv   내전 바리케이드(2×1): 엎은 책상 · 의자 다리 · 철판
    vault_gear_half 반쯤 묻힌 톱니 문(2×1, 월드 입구): 흙에 반쯤 잠긴 톱니 문짝 · 열린 틈 · 동판
    market_arch    시장 아치 간판(3×1): 기둥 둘 · 가로판 '영등포시장' · 아래 작은 판 '전시 공동 구매 협력 시장'
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다. 위에서 빛(위 밝게 · 아래 어둡게), 반투명 없음."""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
STEEL = ("P03", "P04", "P05", "P06", "P07")
PAPER = ("P07", "P08", "P09")
RED = ("P52", "P53", "P54")
BLUE = ("P44", "P45", "P46")
ORANGE = ("P59", "P60")
BRASS = ("P47", "P48", "P50")
WOOD = ("P16", "P17", "P18")
BONE = ("P19", "P20", "P21", "P22")
SOIL = ("P23", "P24", "P25")


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _box(d, x0, y0, x1, y1, ramp, top=True):
    d.rectangle([x0, y0, x1, y1], fill=C(INK))
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=C(ramp[1]))
    if top:
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=C(ramp[-1]))
    d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=C(ramp[0]))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        if x % 2 == 0:
            d.point((x, y), fill=C("P02"))


def _ballot(d, x, y, w=9, h=7, seal=True):
    """흰 투표함 하나(앞면 · 윗면 · 투입구 · 봉인)."""
    d.rectangle([x, y, x + w, y + h], fill=C(INK))
    d.rectangle([x + 1, y + 1, x + w - 1, y + h - 1], fill=C(PAPER[2]))
    d.line([x + 1, y + 2, x + w - 1, y + 2], fill=C(PAPER[1]))
    d.line([x + 1, y + h - 1, x + w - 1, y + h - 1], fill=C(PAPER[0]))
    d.line([x + 3, y + 1, x + w - 3, y + 1], fill=C(INK))              # 투입구
    if seal:
        d.point((x + w - 2, y + h - 3), fill=C(RED[1]))


def w_poster_vote(state=""):
    """선거 벽보(벽 1칸, 32×40): 누렇게 바랜 종이 · 크게 쓴 기호 숫자 · 빈 사진 틀(얼굴 자리에 먼지 얼룩) · 이름 줄은 빈칸.
    정당명은 쓰지 않는다(SD-18). 2~6 = 기호. pledge = 아래 귀퉁이에 손글씨 쪽지 '창고는 같이'를 덧붙임."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    num = state if state in ("2", "3", "4", "5", "6") else "1"
    d.rectangle([2, 2, 29, 37], fill=C(INK))
    d.rectangle([3, 3, 28, 36], fill=C("P21"))
    d.line([3, 3, 28, 3], fill=C(PAPER[2]))
    d.polygon([(28, 3), (28, 9), (23, 3)], fill=C("P20"))               # 접힌 귀퉁이
    put_text(im, "기호", 5, 4, "P02", 8, "Galmuri7")
    put_text(im, num, 22, 3, RED[1], 9, "Galmuri9")
    d.rectangle([7, 14, 22, 28], fill=C(INK))                          # 사진 틀
    d.rectangle([8, 15, 21, 27], fill=C("P20"))
    d.ellipse([11, 17, 18, 24], fill=C("P19"))                         # 얼굴 자리 얼룩
    d.rectangle([10, 24, 19, 27], fill=C("P19"))
    d.line([6, 31, 25, 31], fill=C("P19"))                             # 이름 줄(빈칸)
    d.line([6, 34, 18, 34], fill=C("P19"))
    for (x, y) in ((4, 12), (26, 20), (5, 33)):                        # 압정
        d.point((x, y), fill=C(BRASS[1]))
    if state == "pledge":
        d.rectangle([16, 26, 30, 38], fill=C(INK))
        d.rectangle([17, 27, 29, 37], fill=C(PAPER[2]))
        put_text(im, "같이", 18, 29, BLUE[1], 8, "Galmuri7")
        d.line([18, 36, 27, 35], fill=C(BLUE[0]))
    return im


def ballot_pile():
    """투표함 더미(2×1, 64×52): 무너지듯 쌓인 흰 투표함들 — 맨 위 몇은 기울고, 바닥엔 쏟아진 용지."""
    im = img(64, 52)
    d = ImageDraw.Draw(im)
    rows = [(4, 40, 6), (8, 32, 5), (14, 24, 4), (20, 16, 3)]
    for (x0, y, n) in rows:
        for i in range(n):
            _ballot(d, x0 + i * 10 + (y % 3), y, seal=(i + y) % 3 == 0)
    d.polygon([(46, 14), (55, 11), (57, 18), (48, 21)], fill=C(INK))   # 기운 상자
    d.polygon([(47, 15), (54, 12), (56, 17), (49, 20)], fill=C(PAPER[2]))
    d.line([49, 16, 53, 14], fill=C(INK))
    for (x, y) in ((6, 49), (14, 50), (58, 48), (40, 50)):            # 쏟아진 용지
        d.rectangle([x, y, x + 3, y + 1], fill=C(PAPER[1]))
    for x in range(6, 60, 7):                                          # 먼지
        d.point((x, 15 + (x % 5)), fill=C("P07"))
    _shadow(d, 3, 62, 51)
    return im


def ballot_box_sv(state=""):
    """투표함(1×1, 32×44): 다리 넷 받침대 위 큰 흰 상자 · 투입구 · 앞면 붉은 '투표함' · 봉인 줄. full = 투입구에 용지 한 장이 꽂힘."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    for x in (6, 24):                                                  # 받침대 다리
        d.rectangle([x, 30, x + 2, 41], fill=C(INK)); d.line([x + 1, 31, x + 1, 40], fill=C(STEEL[2]))
    _box(d, 4, 28, 28, 31, STEEL[1:])
    _box(d, 4, 8, 27, 28, PAPER)
    d.rectangle([5, 8, 26, 12], fill=C(PAPER[2]))                      # 윗면
    d.rectangle([10, 9, 21, 10], fill=C(INK))                          # 투입구
    put_text(im, "투표함", 6, 15, RED[1], 8, "Galmuri7")
    d.line([5, 24, 26, 24], fill=C(RED[0]))                            # 봉인 줄
    d.rectangle([14, 22, 17, 26], fill=C(RED[1]))
    if state == "full":
        d.rectangle([13, 3, 18, 10], fill=C(INK)); d.rectangle([14, 4, 17, 9], fill=C(PAPER[2]))
        d.point((15, 6), fill=C(RED[1]))
    _shadow(d, 4, 29, 43)
    return im


def vote_booth(state=""):
    """기표소 칸막이(1×1, 32×60): 회색 쇠 틀 · 위 가름대 · 무릎 높이까지 내려온 짧은 커튼(걷힌 채).
    in = 커튼이 닫히고 아래로 발 두 짝(구두)이 보인다 — 누가 안에서 찍는 중."""
    im = img(32, 60)
    d = ImageDraw.Draw(im)
    for x in (2, 27):
        d.rectangle([x, 4, x + 2, 57], fill=C(INK)); d.line([x + 1, 5, x + 1, 56], fill=C(STEEL[3]))
    _box(d, 2, 2, 29, 7, STEEL[1:])
    put_text(im, "기표", 9, 0, PAPER[2], 8, "Galmuri7")
    if state == "in":
        d.rectangle([5, 8, 26, 46], fill=C(INK))
        d.rectangle([6, 8, 25, 45], fill=C(BLUE[0]))
        for x in range(8, 25, 4):
            d.line([x, 9, x, 45], fill=C(BLUE[1]))                      # 커튼 주름
        for x in (11, 17):                                             # 발
            d.rectangle([x, 50, x + 4, 54], fill=C(INK)); d.line([x + 1, 51, x + 3, 51], fill=C("P03"))
    else:
        d.rectangle([5, 8, 9, 40], fill=C(INK)); d.rectangle([6, 8, 8, 39], fill=C(BLUE[0]))   # 걷힌 커튼(왼쪽에 모임)
        d.line([7, 9, 7, 38], fill=C(BLUE[1]))
        _box(d, 12, 26, 26, 30, WOOD)                                  # 기표대 선반
        d.rectangle([16, 23, 19, 26], fill=C(INK)); d.point((17, 24), fill=C(RED[1]))   # 기표 도장
        d.line([24, 30, 24, 40], fill=C(INK))                           # 도장 끈
    _shadow(d, 2, 30, 58)
    return im


def reg_stand_sv():
    """후보 등록부(1×1, 32×48): 비스듬한 받침대 위 펼친 큰 장부 · 칸 줄 셋 · 끈에 매단 펜 · 위 작은 판 '후보 등록'."""
    im = img(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 26, 17, 44], fill=C(INK)); d.line([15, 27, 15, 43], fill=C(STEEL[3]))
    _box(d, 9, 42, 22, 45, STEEL[1:])
    d.polygon([(2, 14), (29, 14), (27, 28), (4, 28)], fill=C(INK))
    d.polygon([(3, 15), (15, 15), (15, 27), (5, 27)], fill=C(PAPER[2]))
    d.polygon([(16, 15), (28, 15), (26, 27), (16, 27)], fill=C(PAPER[1]))
    for y in (18, 21, 24):
        d.line([5, y, 14, y], fill=C("P06")); d.line([17, y, 25, y], fill=C("P06"))
    d.point((7, 18), fill=C(BLUE[1])); d.point((8, 18), fill=C(BLUE[1]))   # 첫 칸에 흐린 글씨 자국
    d.line([27, 27, 29, 34], fill=C(INK))                              # 펜 끈 · 펜
    d.rectangle([28, 33, 30, 39], fill=C(INK)); d.line([29, 34, 29, 38], fill=C(BLUE[1]))
    _box(d, 7, 2, 24, 13, PAPER)
    put_text(im, "등록", 9, 3, "P02", 8, "Galmuri7")
    _shadow(d, 6, 26, 47)
    return im


def counter_sv(state=""):
    """세진 진공관 개표기(2×1, 64×60): 진한 녹회색 함 · 위 진공관 두 줄(주황 불) · 가운데 숫자 창 셋 · 아래 출력구에서 늘어진 종이 띠.
    off = 진공관이 꺼지고(회색 유리) 숫자 창이 검다."""
    im = img(64, 60)
    d = ImageDraw.Draw(im)
    _box(d, 2, 6, 61, 54, ("P11", "P12", "P13"))
    d.rectangle([5, 9, 58, 24], fill=C(INK))                           # 진공관 창
    for row, y in enumerate((11, 17)):
        for i in range(8):
            x = 7 + i * 6 + row * 3
            d.rectangle([x, y, x + 3, y + 5], fill=C("P02"))
            if state != "off" and (i + row) % 3 != 2:
                d.rectangle([x + 1, y + 1, x + 2, y + 4], fill=C(ORANGE[0]))
                d.point((x + 1, y + 1), fill=C(ORANGE[1]))
            else:
                d.point((x + 1, y + 1), fill=C("P06"))
    for i in range(3):                                                 # 숫자 창
        x = 10 + i * 15
        d.rectangle([x, 28, x + 11, 36], fill=C(INK))
        d.rectangle([x + 1, 29, x + 10, 35], fill=C("P02"))
        if state != "off":
            put_text(im, "0", x + 3, 28, "P62", 8, "Galmuri7")
    put_text(im, "세진 개표기", 8, 38, PAPER[2], 8, "Galmuri7")
    d.rectangle([38, 48, 54, 51], fill=C(INK)); d.line([39, 49, 53, 49], fill=C("P02"))   # 출력구
    if state != "off":
        for k in range(6):
            d.line([41, 51 + k, 50, 51 + k], fill=C(PAPER[2] if k % 2 else PAPER[1]))
        d.line([42, 53, 48, 53], fill=C("P05"))
    _shadow(d, 3, 62, 58)
    return im


def printout_pile(state=""):
    """재검표 출력지 더미(1×1, 32×32): 아코디언처럼 접힌 연속 용지 띠. more = 한 층 더 · heap = 무릎 높이로 쌓여 넘침(부정 뒤 날마다)."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    layers = {"more": 5, "heap": 8}.get(state, 3)
    for i in range(layers):
        y = 26 - i * 3
        x = 5 + (i % 2) * 2
        d.rectangle([x, y, x + 20, y + 3], fill=C(INK))
        d.rectangle([x + 1, y + 1, x + 19, y + 2], fill=C(PAPER[2] if i % 2 else PAPER[1]))
        for k in range(x + 3, x + 18, 4):
            d.point((k, y + 1), fill=C("P05"))                          # 찍힌 줄
    if state == "heap":
        d.line([25, 6, 30, 2], fill=C(PAPER[2])); d.line([26, 7, 31, 3], fill=C(INK))   # 넘친 띠 끝
    _shadow(d, 4, 28, 31)
    return im


def w_board_vote(state=""):
    """공고 칠판(벽 2칸, 64×40): 나무 테 · 초록 칠판 · 분필 글.
    기본 '제752차 선거 / 유권자를 기다립니다' · fail '제752차 무산 / 재공고' · term '임기 4년 / 다음 선거 1460일' · next '제753차 / 다음 달'."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    _box(d, 1, 2, 62, 37, WOOD)
    d.rectangle([4, 5, 59, 33], fill=C("P29"))
    d.rectangle([4, 5, 59, 33], outline=C(INK))
    l1, l2 = {"fail": ("752차 무산", "재공고합니다"), "term": ("임기 4년", "다음 1460일"),
              "next": ("제753차", "다음 달")}.get(state, ("제752차 선거", "유권자 기다림"))
    put_text(im, l1, 7, 7, PAPER[2], 8, "Galmuri7")
    put_text(im, l2, 7, 19, PAPER[1], 8, "Galmuri7")
    if state == "fail":
        d.line([7, 13, 56, 13], fill=C(PAPER[0]))                      # 줄 그음
    d.rectangle([40, 34, 50, 36], fill=C(PAPER[2]))                    # 분필 받침의 분필
    return im


def w_plaque_wall():
    """명패 벽(벽 3칸, 96×44): 짙은 판에 손톱만 한 놋쇠 명패가 빽빽이(750) — 맨 끝 한 칸만 빈 틀."""
    im = img(96, 44)
    d = ImageDraw.Draw(im)
    _box(d, 1, 2, 94, 41, WOOD)
    d.rectangle([3, 4, 92, 39], fill=C("P16"))
    rows = 7
    for r in range(rows):
        for c in range(22):
            x = 5 + c * 4
            y = 6 + r * 5
            if r == rows - 1 and c == 21:                              # 빈 틀(제751차 — 당선자 없음)
                d.rectangle([x - 1, y - 1, x + 3, y + 3], outline=C(BRASS[2]))
                continue
            d.rectangle([x, y, x + 2, y + 2], fill=C(BRASS[1] if (r + c) % 5 else BRASS[0]))
            d.point((x, y), fill=C(BRASS[2]))
    return im


def skel_sash(state=""):
    """띠 두른 해골(1×1, 32×24, 바닥): 쓰러진 해골 · 어깨에서 비스듬한 띠(파랑) — orange = 주황 띠(다른 무리)."""
    im = img(32, 24)
    d = ImageDraw.Draw(im)
    col = ORANGE if state == "orange" else (BLUE[1], BLUE[2])
    d.ellipse([3, 6, 11, 13], fill=C(INK)); d.ellipse([4, 7, 10, 12], fill=C(BONE[2]))   # 두개골
    d.point((6, 9), fill=C(INK)); d.point((8, 9), fill=C(INK))
    d.line([11, 11, 26, 14], fill=C(INK), width=3)                     # 등뼈 · 갈비
    d.line([11, 11, 26, 14], fill=C(BONE[2]))
    for x in range(13, 24, 3):
        d.line([x, 9, x + 1, 16], fill=C(BONE[1]))
    d.line([26, 14, 30, 19], fill=C(BONE[1])); d.line([25, 15, 27, 21], fill=C(BONE[1]))   # 다리
    d.line([13, 8, 22, 17], fill=C(INK), width=3)                      # 띠
    d.line([13, 8, 22, 17], fill=C(col[0]), width=1)
    d.point((17, 12), fill=C(col[1]))
    d.rectangle([20, 18, 23, 20], fill=C(PAPER[1]))                    # 손 곁 투표용지
    return im


def barricade_sv():
    """내전 바리케이드(2×1, 64×48): 엎은 철제 책상 · 의자 다리가 하늘로 · 철판 · 띠 조각 둘(파랑 · 주황)."""
    im = img(64, 48)
    d = ImageDraw.Draw(im)
    _box(d, 4, 22, 40, 42, STEEL[1:])                                  # 엎은 책상(상판이 앞)
    d.line([6, 32, 38, 32], fill=C(STEEL[0]))
    for x in (8, 34):                                                  # 하늘로 향한 책상 다리
        d.rectangle([x, 10, x + 2, 22], fill=C(INK)); d.line([x + 1, 11, x + 1, 21], fill=C(STEEL[3]))
    _box(d, 38, 26, 60, 44, ("P23", "P24", "P25"))                     # 녹슨 철판
    for (x, y) in ((42, 30), (55, 39)):
        d.point((x, y), fill=C(INK))
    d.line([44, 8, 50, 26], fill=C(INK), width=2); d.line([52, 8, 48, 26], fill=C(INK), width=2)   # 의자 다리
    d.rectangle([44, 18, 54, 21], fill=C(INK)); d.line([45, 19, 53, 19], fill=C(WOOD[1]))
    d.line([12, 24, 18, 30], fill=C(BLUE[1]), width=2)                 # 띠 조각
    d.line([28, 36, 34, 30], fill=C(ORANGE[0]), width=2)
    _shadow(d, 4, 61, 46)
    return im


def vault_gear_half():
    """반쯤 묻힌 톱니 문(2×1, 64×44, 월드 입구): 흙 둔덕에 아래 반이 잠긴 둥근 톱니 문짝 · 비스듬히 열린 틈(어둠) · 왼쪽 동판."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.pieslice([4, 4, 60, 60], 180, 360, fill=C(INK))                   # 문짝(위 반원만 보임)
    d.pieslice([6, 6, 58, 58], 180, 360, fill=C(STEEL[2]))
    d.pieslice([14, 14, 50, 50], 180, 360, fill=C(STEEL[3]))
    for a in range(0, 180, 20):                                        # 톱니
        import math
        t = math.radians(180 + a + 10)
        x, y = 32 + 28 * math.cos(t), 32 + 28 * math.sin(t)
        d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=C(INK))
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=C(STEEL[1]))
    put_text(im, "S-02", 22, 14, "P48", 8, "Galmuri7")
    d.polygon([(44, 32), (54, 18), (58, 32)], fill=C("P02"))            # 열린 틈
    d.line([44, 32, 54, 18], fill=C(INK))
    d.rectangle([0, 30, 63, 43], fill=C(SOIL[1]))                      # 흙 둔덕
    for x in range(0, 64, 3):
        d.point((x, 30 + (x % 2)), fill=C(SOIL[2]))
        d.point((x + 1, 36 + (x % 3)), fill=C(SOIL[0]))
    d.polygon([(44, 32), (58, 32), (60, 36), (42, 36)], fill=C("P02"))  # 틈 아래 어둠(들어가는 길)
    d.rectangle([2, 22, 12, 30], fill=C(INK)); d.rectangle([3, 23, 11, 29], fill=C(BRASS[0]))   # 동판
    d.line([4, 25, 10, 25], fill=C(BRASS[2])); d.line([4, 27, 9, 27], fill=C(BRASS[1]))
    return im


def market_arch():
    """시장 아치 간판(3×1, 96×72): 쇠기둥 둘 · 위 가로판 '영등포시장' · 아래 작은 판 '전시 공동 구매 협력 시장' · 기둥에 감은 전선과 전구."""
    im = img(96, 72)
    d = ImageDraw.Draw(im)
    for x in (4, 86):
        d.rectangle([x, 14, x + 5, 70], fill=C(INK)); d.rectangle([x + 1, 15, x + 4, 69], fill=C(STEEL[2]))
        d.line([x + 1, 15, x + 1, 69], fill=C(STEEL[3]))
    _box(d, 1, 2, 94, 20, ("P52", "P53", "P54"))
    put_text(im, "영등포 시장", 27, 6, PAPER[2], 8, "Galmuri7")
    _box(d, 14, 22, 81, 35, PAPER)
    put_text(im, "전시 공동 구매", 20, 24, "P02", 8, "Galmuri7")
    for x in range(10, 88, 8):                                         # 전구 줄
        d.point((x, 37 + (x // 8) % 2), fill=C(INK))
        d.point((x, 38 + (x // 8) % 2), fill=C(ORANGE[1] if (x // 8) % 3 else "P06"))
    _shadow(d, 4, 92, 71)
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_SV = {
    "w_poster_vote": _r(lambda: w_poster_vote(), 1, 0, "wall", dx=0, dy=0),
    "ballot_pile": _r(ballot_pile, 2, 1, down=-2),
    "ballot_box_sv": _r(lambda: ballot_box_sv(), 1, 1, down=-2),
    "vote_booth": _r(lambda: vote_booth(), 1, 1, down=-2),
    "reg_stand_sv": _r(reg_stand_sv, 1, 1, down=-2),
    "counter_sv": _r(lambda: counter_sv(), 2, 1, down=-2),
    "printout_pile": _r(lambda: printout_pile(), 1, 1, "deco", down=-2),
    "w_board_vote": _r(lambda: w_board_vote(), 2, 0, "wall", dx=0, dy=0),
    "w_plaque_wall": _r(w_plaque_wall, 3, 0, "wall", dx=0, dy=0),
    "skel_sash": _r(lambda: skel_sash(), 1, 1, "deco", down=-2),
    "barricade_sv": _r(barricade_sv, 2, 1, down=-2),
    "vault_gear_half": _r(vault_gear_half, 2, 1, down=-2),
    "market_arch": _r(market_arch, 3, 1, down=-2),
}
STATES_SV = {
    "w_poster_vote": {s: (lambda s=s: w_poster_vote(s)) for s in ("2", "3", "4", "5", "6", "pledge")},
    "ballot_box_sv": {"full": lambda: ballot_box_sv("full")},
    "vote_booth": {"in": lambda: vote_booth("in")},
    "counter_sv": {"off": lambda: counter_sv("off")},
    "printout_pile": {"more": lambda: printout_pile("more"), "heap": lambda: printout_pile("heap")},
    "w_board_vote": {s: (lambda s=s: w_board_vote(s)) for s in ("fail", "term", "next")},
    "skel_sash": {"orange": lambda: skel_sash("orange")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_sv.png"
    ims = [f["fn"]() for f in PROPS_SV.values()] + [fn() for st in STATES_SV.values() for fn in st.values()]
    cols = 7
    cw, ch = 104, 80
    sheet = Image.new("RGBA", (cols * cw, ((len(ims) + cols - 1) // cols) * ch), (70, 66, 74, 255))
    for i, m in enumerate(ims):
        sheet.alpha_composite(m, ((i % cols) * cw + 4, (i // cols) * ch + 4))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(out)
