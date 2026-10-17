"""독산 육가공 단지 소품(단계 1-D3, 1-D 계획 §9 · SD-09a L-R01-29 · SD-05 UQ-04 · SD-14 CR-004 · CR-096 · SD-16 아이작풍).
  w_quarantine_ds 창고 출입문 검역 공문(벽 2칸): '두 머리 송아지 출하 금지 — 2077-09 축산 검역' · 파란 '검역 보류' 테이프
  hook_line       갈고리 레일(2×1): 천장 레일에 매달린 썩은 고기 반쪽 둘 · 빈 갈고리 · 바닥 핏자국 / 상태 picked(고기 하나 떼어 감)
  conveyor_ds     가공 컨베이어(3×1): 고무 벨트 · 롤러 · 썩은 고기 조각 · 멈춘 비상 정지 버튼(붉은)
  cut_table       스테인리스 절단대(2×1): 도마 · 칼 꽂이 · 녹슨 식칼 · 저울
  carcass_pile    썩은 고기 더미(1×1): 검붉은 살덩이 · 뼈 · 파리 — 미끼(W-068)를 줍는 자리
  calf_bones      두 머리 송아지 뼈(2×1, 1호 검역 격리 칸): 한 몸에 머리뼈 둘 · 검역 꼬리표
  ds_valve        도랑 배수 밸브(1×1): 큰 바퀴 손잡이 · 녹 / 상태 open(바퀴가 돌아가 있고 물이 쏟아진 자국)
  egg_drain       배수 도랑 알집 둥지(덧그림): 도랑 철망 사이 갈색 알집 껍질 무더기 / 상태 washed(쓸려 나가 젖은 자국만)
  w_breach_ds     무너진 벽 틈(벽 2칸): 블록이 무너져 흙이 쏟아진 구멍 · 안쪽 굴의 어둠 · 쥐 긁힌 자국
  frost_patch     서리(덧그림): 바닥 서리 결정 · 흰 점 — 냉기를 돌리면(UQ04_COLD)
  flies_ds        파리 떼(덧그림): 검은 점 무리 · 날개 반짝임 — 썩은 칸(5호 · 녹은 7호)
  shelf_7ho       7호 비축 선반(2×1): 군납 런천미트 · 꽁치 통조림 상자 · 서리선
                  상태 half(반) · empty(빈 선반) · sweat(서리가 녹아 상자에 물방울) · thaw(녹음 · 젖은 상자 · 파리) · gnawed(왕쥐가 갉음)
  ds_cold_panel   7호 냉동기 제어반(1×1): 원자력 소형 냉동기 · 계기 둘 · 송풍 밸브 손잡이 / 상태 redirect(손잡이가 '굴' 쪽) · dead(멈춤)
  w_keypad7       7호 번호 자물쇠(벽 1칸): 열 칸 숫자판 · 붉은 등 / 상태 open(초록 등)
  frozen_ratking  언 왕쥐(2×1): 서리 덮인 조각상 / 상태 broken(깨진 조각)
  reefer_wagon    냉동 화물칸(4×2, 뒤 철길 하역장): 녹슨 화물칸 · 문 반쯤 열림 · 운송장 · 안의 어둠
  w_price_luncheon 지하시장 값표(벽 1칸): '청솔 런천미트 — 15캡' 판자(③ 판에만)
  cart_tipped_ds  엎어진 상인회 수레(2×1): 7호 왕쥐에게 쫓긴 짐꾼이 버린 수레 · 쏟아진 깡통 · 끌린 핏자국(UQ04_JH 4)
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
MEAT = ("P51", "P52", "P53", "P21")        # 썩은 살(어둠 · 살 · 밝음 · 누런 비계)
STEEL = ("P04", "P06", "P07", "P08")


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def _flies(d, rnd, x0, y0, x1, y1, n):
    for _ in range(n):
        x, y = rnd.randint(x0, x1), rnd.randint(y0, y1)
        d.point((x, y), fill=C(INK))
        if rnd.random() < 0.4:
            d.point((x + 1, y - 1), fill=C("P07"))


def _meat(d, x0, y0, x1, y1, rnd):
    """썩은 살덩이: 먹선 테 · 살 · 밝은 결 · 비계 줄 · 곰팡이 점."""
    d.ellipse([x0, y0, x1, y1], fill=C(INK))
    d.ellipse([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=C(MEAT[1]))
    d.ellipse([x0 + 2, y0 + 1, x1 - 3, (y0 + y1) // 2], fill=C(MEAT[2]))
    d.line([x0 + 3, (y0 + y1) // 2 + 1, x1 - 3, (y0 + y1) // 2], fill=C(MEAT[3]))
    for _ in range(3):
        d.point((rnd.randint(x0 + 2, x1 - 2), rnd.randint(y0 + 2, y1 - 2)), fill=C("P35"))
    d.arc([x0 + 1, y0 + 1, x1 - 1, y1 - 1], 20, 160, fill=C(MEAT[0]))


# ================================================================================================ 가공장(DS-01)
def w_quarantine_ds():
    """검역 공문(벽 2칸, 64×40): 누런 관청 공문 · 위 붉은 띠 '축산 검역' · 굵은 두 줄 '두 머리 송아지 / 출하 금지' · 붉은 직인 · 아래 '2077-09' ·
    오른쪽 아래 귀퉁이에 파란 '보류' 테이프(공문의 끝 — 1호 격리 칸의 꼬리표와 같은 테이프)."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 1, 61, 38], fill=C(INK)); d.rectangle([3, 2, 60, 37], fill=C("P20"))
    d.rectangle([3, 2, 60, 10], fill=C("P52"))
    put_text(im, "축산 검역", 6, 2, "P09", 8, "Galmuri7")
    put_text(im, "두 머리 송아지", 6, 12, "P01", 8, "Galmuri7")
    put_text(im, "출하 금지", 6, 21, "P53", 8, "Galmuri7")
    put_text(im, "2077-09", 6, 29, "P03", 8, "Galmuri7")
    d.ellipse([52, 3, 58, 9], outline=C("P09")); d.point((55, 6), fill=C("P09"))                # 직인(붉은 띠 위 흰 테)
    d.polygon([(38, 37), (60, 25), (60, 31), (46, 38)], fill=C("P45"))                         # 파란 '보류' 테이프(귀퉁이)
    d.line([38, 37, 60, 25], fill=C("P46"))
    put_text(im, "보류", 46, 28, "P09", 8, "Galmuri7")
    d.line([4, 37, 36, 37], fill=C("P18"))                                                     # 아래 젖은 얼룩
    return im


def hook_line(state=""):
    """갈고리 레일(2×1, 64×72): 천장에서 내려온 레일 · 갈고리 셋 · 썩은 고기 반쪽 둘(뼈 · 비계) · 아래 핏자국 · 파리."""
    im = img(64, 72)
    d = ImageDraw.Draw(im)
    rnd = random.Random(21)
    d.ellipse([4, 62, 60, 71], fill=C("P02"))
    d.ellipse([10, 60, 54, 69], fill=C("P51"))                                                 # 마른 핏자국
    d.rectangle([0, 2, 63, 6], fill=C(INK)); d.rectangle([0, 3, 63, 5], fill=C(STEEL[2]))   # 레일
    for x in (10, 32, 54):
        d.line([x, 6, x, 16], fill=C(STEEL[1])); d.arc([x - 4, 14, x + 2, 22], 270, 120, fill=C(STEEL[3]))   # 갈고리
    for i, x in enumerate((10, 54)):
        if state == "picked" and i == 1:
            continue
        sh = [(x - 2, 20), (x + 2, 20), (x + 4, 28), (x + 10, 40), (x + 9, 54), (x + 2, 59), (x - 7, 56), (x - 10, 44), (x - 5, 29)]
        d.polygon(sh, fill=C(INK))                                                             # 고기 반쪽(위 가는 정강이 · 아래 넓은 갈비짝)
        d.polygon([(px + (1 if px < x else -1), py + (1 if py < 40 else -1)) for px, py in sh], fill=C(MEAT[1]))
        d.polygon([(x - 1, 22), (x + 1, 22), (x + 2, 30), (x - 3, 30)], fill=C(MEAT[2]))
        d.line([x - 1, 20, x - 1, 27], fill=C("P08")); d.ellipse([x - 3, 18, x + 1, 22], fill=C("P08"))   # 정강이 뼈 끝(갈고리에 꿰임)
        for k, y in enumerate(range(34, 54, 4)):                                               # 갈비(흰 뼈 + 비계 사이)
            d.line([x - 7 + k // 2, y, x + 6 - k // 3, y + 2], fill=C("P08"))
            d.line([x - 6 + k // 2, y + 1, x + 5 - k // 3, y + 3], fill=C(MEAT[0]))
        d.line([x + 8, 42, x + 7, 53], fill=C(MEAT[3]))                                        # 바깥 비계 테
        for _ in range(4):
            d.point((rnd.randint(x - 6, x + 6), rnd.randint(30, 55)), fill=C("P35"))
    _flies(d, rnd, 2, 14, 62, 58, 12)
    return im


def conveyor_ds():
    """가공 컨베이어(3×1, 96×46): 검은 고무 벨트(가로 줄) · 양끝 롤러 · 철 다리 · 썩은 고기 조각 셋 · 비상 정지 버튼(붉은)."""
    im = img(96, 46)
    d = ImageDraw.Draw(im)
    rnd = random.Random(33)
    _shadow(d, 4, 92, 42)
    for x in (8, 46, 84):
        d.rectangle([x, 22, x + 3, 41], fill=C(STEEL[0]))
    d.rectangle([2, 10, 93, 24], fill=C(INK)); d.rectangle([3, 11, 92, 23], fill=C("P03"))
    for x in range(6, 90, 5):
        d.line([x, 12, x, 22], fill=C("P02"))
    d.rectangle([3, 11, 92, 12], fill=C("P05"))
    for x in (4, 88):
        d.ellipse([x - 3, 9, x + 4, 25], fill=C(STEEL[1])); d.ellipse([x - 1, 13, x + 2, 20], fill=C(STEEL[3]))
    for x in (18, 44, 70):
        _meat(d, x, 8, x + 10 + rnd.randint(0, 4), 18, rnd)
    d.rectangle([80, 26, 90, 34], fill=C("P48")); d.ellipse([82, 27, 88, 33], fill=C("P53")); d.point((84, 29), fill=C("P54"))
    _flies(d, rnd, 10, 2, 80, 20, 7)
    return im


def cut_table():
    """스테인리스 절단대(2×1, 64×44): 반짝이는 상판 · 둥근 도마(칼자국) · 녹슨 식칼 · 칼 꽂이 · 접시저울."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 60, 40)
    for x in (5, 56):
        d.rectangle([x, 22, x + 3, 39], fill=C(STEEL[0]))
    d.rectangle([2, 10, 61, 24], fill=C(INK)); d.rectangle([3, 11, 60, 23], fill=C(STEEL[2]))
    d.line([3, 11, 60, 11], fill=C(STEEL[3])); d.line([3, 23, 60, 23], fill=C(STEEL[0]))
    d.ellipse([8, 8, 30, 20], fill=C(INK)); d.ellipse([9, 9, 29, 19], fill=C("P19")); d.ellipse([11, 10, 27, 15], fill=C("P20"))
    for k in range(4):
        d.line([12 + k * 4, 12, 15 + k * 4, 17], fill=C("P18"))
    d.polygon([(32, 13), (46, 11), (47, 15), (33, 16)], fill=C(STEEL[1])); d.line([32, 13, 46, 11], fill=C(STEEL[3]))   # 식칼
    d.rectangle([46, 11, 51, 15], fill=C("P17")); d.point((40, 14), fill=C("P25"))
    d.rectangle([52, 4, 58, 12], fill=C("P05")); d.ellipse([51, 2, 59, 6], fill=C(STEEL[2]))  # 저울
    return im


def carcass_pile():
    """썩은 고기 더미(1×1, 32×32): 검붉은 살덩이 셋이 포개졌다 · 비죽 나온 뼈 · 고인 물 · 파리 — 여기서 미끼를 줍는다."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    rnd = random.Random(44)
    d.ellipse([1, 22, 31, 31], fill=C("P51"))
    _meat(d, 2, 14, 18, 27, rnd)
    _meat(d, 13, 15, 30, 28, rnd)
    _meat(d, 7, 7, 24, 20, rnd)
    d.line([20, 9, 27, 4], fill=C("P08")); d.ellipse([26, 2, 29, 5], fill=C("P08"))           # 뼈
    _flies(d, rnd, 2, 0, 30, 18, 9)
    return im


def calf_bones():
    """두 머리 송아지 뼈(2×1, 64×36): 바닥에 누운 작은 등뼈 · 갈비 · 목이 두 갈래로 갈라져 머리뼈 둘 · 발목에 검역 꼬리표(노랑)."""
    im = img(64, 36)
    d = ImageDraw.Draw(im)
    bone, dark = C("P08"), C("P06")
    d.ellipse([4, 24, 60, 35], fill=C("P03"))
    d.line([12, 24, 40, 24], fill=C(INK), width=3); d.line([12, 24, 40, 24], fill=bone)        # 등뼈
    for x in range(14, 40, 4):
        d.arc([x - 3, 18, x + 3, 30], 200, 340, fill=bone); d.point((x, 24), fill=dark)       # 갈비
    for k, (hx, hy) in enumerate(((50, 15), (52, 28))):                                         # 두 갈래 목 + 머리뼈 둘
        d.line([40, 24, hx - 4, hy], fill=C(INK), width=3); d.line([40, 24, hx - 4, hy], fill=bone)
        d.ellipse([hx - 6, hy - 5, hx + 6, hy + 4], fill=C(INK)); d.ellipse([hx - 5, hy - 4, hx + 5, hy + 3], fill=bone)
        d.point((hx - 1, hy - 1), fill=C(INK)); d.point((hx + 2, hy - 1), fill=C(INK))
        d.line([hx + 3, hy + 2, hx + 6, hy + 2], fill=dark)
    for x in (14, 34):                                                                         # 다리뼈
        d.line([x, 25, x - 3, 33], fill=bone)
    d.rectangle([7, 29, 12, 33], fill=C("P49")); d.line([10, 26, 12, 29], fill=C("P05"))      # 검역 꼬리표
    return im


def ds_valve(state=""):
    """도랑 배수 밸브(1×1, 32×40): 바닥에서 솟은 굵은 관 · 큰 붉은 바퀴 손잡이 · 녹 · 'DRAIN' 대신 '배수'. open = 바퀴가 돌아갔고 아래로 물 쏟아진 자국."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 28, 36)
    d.rectangle([12, 18, 20, 37], fill=C(INK)); d.rectangle([13, 18, 19, 36], fill=C(STEEL[1])); d.line([13, 18, 13, 36], fill=C(STEEL[3]))
    d.ellipse([4, 4, 28, 20], fill=C(INK)); d.ellipse([5, 5, 27, 19], fill=C("P52")); d.ellipse([9, 8, 23, 16], fill=(0, 0, 0, 0))
    d.ellipse([9, 8, 23, 16], outline=C("P52"))
    for a in ((0, 0), (1, 1)) if state != "open" else ((0, 1), (1, 0)):
        if a == (0, 0):
            d.line([16, 6, 16, 18], fill=C("P53"))
        elif a == (1, 1):
            d.line([6, 12, 26, 12], fill=C("P53"))
        else:
            d.line([8, 7, 24, 17], fill=C("P53")); d.line([8, 17, 24, 7], fill=C("P53"))
    d.ellipse([14, 10, 18, 14], fill=C(STEEL[2]))
    d.line([14, 22, 18, 30], fill=C("P25"))
    put_text(im, "배수", 9, 24, "P09", 8, "Galmuri7")
    if state == "open":
        for y in (34, 36, 38):
            d.line([6, y, 26, y], fill=C("P12")); d.point((8 + y % 5, y), fill=C("P14"))
    return im


def egg_drain(state=""):
    """배수 도랑 알집 둥지(덧그림, 32×32): 도랑 철망 칸 사이에 끼인 적갈색 알집 껍질 무더기 · 흰 애벌레 점. washed = 젖은 자국 · 껍질 조각 둘만."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    rnd = random.Random(55)
    if state == "washed":
        d.ellipse([4, 12, 28, 26], fill=C("P11"))
        for x, y in ((10, 18), (20, 15)):
            d.ellipse([x, y, x + 4, y + 2], fill=C("P23"))
        return im
    for _ in range(9):
        x, y = rnd.randint(4, 22), rnd.randint(8, 22)
        d.ellipse([x, y, x + 7, y + 4], fill=C(INK)); d.ellipse([x + 1, y, x + 6, y + 3], fill=C(rnd.choice(("P23", "P24", "P25"))))
        d.line([x + 1, y + 1, x + 6, y + 1], fill=C("P26"))
        if rnd.random() < 0.4:
            d.point((x + 3, y + 2), fill=C("P08"))
    return im


def w_breach_ds():
    """무너진 벽 틈(벽 2칸, 64×60): 블록 벽이 안쪽으로 무너진 구멍 · 쏟아진 흙더미 · 구멍 안 굴의 어둠 · 테두리 쥐 발톱 자국."""
    im = img(64, 60)
    d = ImageDraw.Draw(im)
    rnd = random.Random(66)
    d.polygon([(10, 58), (8, 30), (18, 12), (34, 6), (50, 14), (58, 34), (56, 58)], fill=C(INK))
    d.polygon([(13, 58), (12, 32), (20, 16), (34, 10), (47, 17), (54, 35), (52, 58)], fill=C("P02"))
    d.polygon([(18, 58), (18, 38), (26, 26), (40, 24), (46, 38), (46, 58)], fill=C(INK))       # 안쪽 굴(어둠)
    for k in range(7):                                                                         # 부서진 블록 테
        x, y = rnd.randint(8, 52), rnd.randint(8, 28)
        d.rectangle([x, y, x + 6, y + 3], fill=C("P05")); d.line([x, y, x + 6, y], fill=C("P07"))
    d.polygon([(6, 59), (16, 48), (32, 50), (48, 47), (60, 59)], fill=C("P17"))                # 쏟아진 흙
    d.line([16, 48, 48, 47], fill=C("P19"))
    for x in (22, 36, 44):                                                                     # 발톱 자국
        for k in range(3):
            d.line([x + k * 2, 28 + k, x + k * 2 + 1, 34 + k], fill=C("P06"))
    return im


def frost_patch():
    """바닥 서리(덧그림, 32×32): 희푸른 결정 별 · 흩뿌린 흰 점 · 가장자리 성글게(바닥이 비친다)."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    rnd = random.Random(77)
    for _ in range(30):
        x, y = rnd.randint(1, 30), rnd.randint(1, 30)
        if ((x - 16) ** 2 + (y - 16) ** 2) < 200 or rnd.random() < 0.3:
            d.point((x, y), fill=C("P15" if rnd.random() < 0.6 else "P09"))
    for cx, cy in ((10, 12), (22, 20), (16, 26)):
        d.line([cx - 2, cy, cx + 2, cy], fill=C("P15")); d.line([cx, cy - 2, cx, cy + 2], fill=C("P15")); d.point((cx, cy), fill=C("P09"))
    return im


def flies_ds():
    """파리 떼(덧그림, 32×24): 검은 점 무리가 뭉쳤다 흩어진다 · 날개 반짝임."""
    im = img(32, 24)
    d = ImageDraw.Draw(im)
    _flies(d, random.Random(88), 2, 2, 30, 20, 16)
    return im


# ================================================================================================ 냉동 창고 동(DS-02) · 7호
def shelf_7ho(state=""):
    """7호 비축 선반(2×1, 64×60): 회색 철제 선반 셋 단 · 국방색 군납 상자('청솔 런천미트' · '꽁치') · 흰 서리선이 상자 위를 덮는다.
    half = 반이 비었다 · empty = 빈 칸(서리 자국만) · sweat = 서리가 녹아 상자에 물방울 · thaw = 녹아 젖은 상자 · 핏물 · 파리 · gnawed = 왕쥐가 갉아 찢긴 상자 · 흩어진 깡통."""
    im = img(64, 60)
    d = ImageDraw.Draw(im)
    rnd = random.Random(99)
    _shadow(d, 2, 62, 57)
    for x in (2, 60):
        d.rectangle([x, 4, x + 2, 56], fill=C(STEEL[0]))
    fill = {"": 1.0, "half": 0.5, "empty": 0.0, "sweat": 1.0, "thaw": 0.8, "gnawed": 0.6}[state]
    n = 0
    for row, y in enumerate((8, 24, 40)):
        d.rectangle([2, y + 13, 62, y + 15], fill=C(INK)); d.line([3, y + 13, 61, y + 13], fill=C(STEEL[2]))
        for k in range(4):
            n += 1
            if (n / 12.0) > fill:
                continue
            x = 5 + k * 14
            col = ("P29", "P30", "P31") if (k + row) % 2 == 0 else ("P18", "P19", "P20")
            d.rectangle([x, y + 2, x + 12, y + 12], fill=C(INK)); d.rectangle([x + 1, y + 3, x + 11, y + 11], fill=C(col[1]))
            d.line([x + 1, y + 3, x + 11, y + 3], fill=C(col[2])); d.line([x + 1, y + 11, x + 11, y + 11], fill=C(col[0]))
            d.point((x + 3, y + 6), fill=C("P53" if col[0] == "P29" else "P45")); d.line([x + 5, y + 7, x + 9, y + 7], fill=C(col[0]))
            if state in ("", "half") and row < 2:
                d.line([x + 1, y + 2, x + 11, y + 2], fill=C("P09"))                          # 서리선
            if state == "sweat":
                d.point((x + 2 + rnd.randint(0, 8), y + 5 + rnd.randint(0, 5)), fill=C("P15"))
                d.point((x + 2 + rnd.randint(0, 8), y + 11), fill=C("P14"))
            if state == "thaw":
                d.line([x + 1, y + 11, x + 11, y + 11], fill=C("P51")); d.point((x + 6, y + 12), fill=C("P52"))
            if state == "gnawed" and rnd.random() < 0.5:
                d.polygon([(x + 6, y + 3), (x + 11, y + 4), (x + 9, y + 9)], fill=C(INK))    # 찢긴 구멍
    if state in ("", "half", "empty"):
        for x in range(3, 61, 3):                                                             # 선반 기둥 서리
            d.point((x, 6), fill=C("P15"))
    if state == "thaw":
        d.ellipse([6, 54, 58, 59], fill=C("P51"))
        _flies(d, rnd, 4, 4, 60, 50, 14)
    if state == "gnawed":
        for x, y in ((8, 55), (30, 56), (50, 54)):
            d.ellipse([x, y, x + 4, y + 3], fill=C(STEEL[2])); d.point((x + 1, y + 1), fill=C(STEEL[3]))
    return im


def ds_cold_panel(state=""):
    """7호 냉동기 제어반(1×1, 32×52): 크림색 함 · 위 원자력 표지 · 계기 둘(온도 · 출력) · 송풍 밸브 손잡이 '창고 ↔ 굴' · 초록 대기등.
    redirect = 손잡이가 '굴' 쪽 · 계기 바늘 끝까지 · 서리 · dead = 등이 꺼지고 바늘이 바닥."""
    im = img(32, 52)
    d = ImageDraw.Draw(im)
    _shadow(d, 3, 29, 49)
    d.rectangle([3, 6, 28, 48], fill=C(INK)); d.rectangle([4, 7, 27, 47], fill=C("P20")); d.line([4, 7, 27, 7], fill=C("P21"))
    d.polygon([(12, 9), (20, 9), (16, 3)], fill=C("P49")); d.point((16, 7), fill=C(INK))      # 방사능 표지
    for gx, val in ((10, {"": 0.3, "redirect": 0.95, "dead": 0.0}[state]), (22, {"": 0.6, "redirect": 0.8, "dead": 0.0}[state])):
        d.ellipse([gx - 5, 13, gx + 5, 23], fill=C(INK)); d.ellipse([gx - 4, 14, gx + 4, 22], fill=C("P09"))
        import math
        a = math.radians(200 - 220 * val)
        d.line([gx, 19, gx + round(4 * math.cos(a)), 19 - round(4 * math.sin(a))], fill=C("P53"))
    d.rectangle([7, 27, 25, 33], fill=C("P05"))
    put_text(im, "창", 5, 34, "P03", 8, "Galmuri7")
    put_text(im, "굴", 19, 34, "P03", 8, "Galmuri7")
    hx = 9 if state != "redirect" else 22
    d.rectangle([hx - 2, 24, hx + 2, 32], fill=C(INK)); d.rectangle([hx - 1, 25, hx + 1, 31], fill=C("P52"))
    lamp = {"": "P55", "redirect": "P46", "dead": "P04"}[state]
    d.ellipse([12, 41, 19, 46], fill=C(INK)); d.ellipse([13, 42, 18, 45], fill=C(lamp))
    if state == "redirect":
        for x, y in ((5, 9), (26, 12), (6, 40), (25, 44)):
            d.point((x, y), fill=C("P15"))
    return im


def w_keypad7(state=""):
    """7호 번호 자물쇠(벽 1칸, 26×34): 서리 낀 철판 · 열 칸 숫자판 · 위 등(붉은 · open이면 초록) · 판에 매직 '7'."""
    im = img(26, 34)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 23, 31], fill=C(INK)); d.rectangle([3, 3, 22, 30], fill=C(STEEL[1])); d.line([3, 3, 22, 3], fill=C(STEEL[3]))
    d.ellipse([9, 5, 16, 10], fill=C("P55" if state == "open" else "P53")); d.point((11, 7), fill=C("P57" if state == "open" else "P54"))
    for r in range(4):
        for c in range(3):
            if r == 3 and c != 1:
                continue
            x, y = 6 + c * 5, 13 + r * 4
            d.rectangle([x, y, x + 3, y + 2], fill=C(STEEL[0])); d.point((x + 1, y), fill=C(STEEL[3]))
    put_text(im, "7", 18, 22, "P53", 8, "Galmuri7")
    for x in (4, 21):
        d.point((x, 28), fill=C("P15"))
    return im


def frozen_ratking(state=""):
    """언 왕쥐(2×1): creatures_ds.frozen_ratking(서리 덮인 조각상 · 고드름) — broken = 깨진 조각."""
    import creatures_ds as DS
    fr = DS.frozen_ratking(state == "broken")
    im = img(64, 36)
    d = ImageDraw.Draw(im)
    d.ellipse([6, 28, 58, 35], fill=C("P15"))                                                  # 발밑 서리
    im.alpha_composite(fr, (1, 3))
    return im


def reefer_wagon():
    """냉동 화물칸(4×2, 132×80): 위에서 본 녹슨 국방색 냉동 화물칸 · 지붕 냉각기 · 옆문 반쯤 열림(안 어둠) · 문에 운송장 · 바퀴 넷 · 아래 레일."""
    im = img(132, 80)
    d = ImageDraw.Draw(im)
    _shadow(d, 6, 128, 74)
    for y in (70, 76):
        d.line([0, y, 131, y], fill=C(STEEL[0])); d.line([0, y + 1, 131, y + 1], fill=C(STEEL[2]))
    for x in (14, 34, 96, 116):
        d.ellipse([x - 7, 62, x + 7, 76], fill=C(INK)); d.ellipse([x - 5, 64, x + 5, 74], fill=C(STEEL[1])); d.point((x, 69), fill=C(STEEL[3]))
    d.rectangle([4, 10, 127, 66], fill=C(INK)); d.rectangle([5, 11, 126, 65], fill=C("P30"))
    d.rectangle([5, 11, 126, 20], fill=C("P31")); d.line([5, 11, 126, 11], fill=C("P32"))
    for x in range(12, 124, 10):
        d.line([x, 21, x, 64], fill=C("P29"))
    d.rectangle([40, 2, 70, 12], fill=C(INK)); d.rectangle([41, 3, 69, 11], fill=C(STEEL[1]))   # 지붕 냉각기
    for x in range(43, 68, 4):
        d.line([x, 4, x, 10], fill=C(STEEL[0]))
    d.rectangle([76, 24, 108, 64], fill=C(INK)); d.rectangle([77, 25, 92, 63], fill=C("P02"))   # 옆문 반쯤 열림
    d.rectangle([92, 25, 108, 63], fill=C("P29")); d.line([92, 25, 92, 63], fill=C(INK))
    d.rectangle([96, 32, 105, 42], fill=C("P08")); d.line([97, 35, 104, 35], fill=C("P04")); d.line([97, 38, 103, 38], fill=C("P04"))   # 운송장
    for k in range(6):
        d.line([10 + k * 11, 56, 14 + k * 11, 64], fill=C("P26"))                              # 녹물
    put_text(im, "냉동", 14, 28, "P09", 8, "Galmuri7")
    put_text(im, "군납", 14, 40, "P09", 8, "Galmuri7")
    return im


def w_price_luncheon():
    """지하시장 값표(벽 1칸, 30×30): 판자에 분필 '청솔 런천미트 15' · 깡통 그림."""
    im = img(30, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 3, 28, 27], fill=C(INK)); d.rectangle([2, 4, 27, 26], fill=C("P18")); d.line([2, 4, 27, 4], fill=C("P19"))
    put_text(im, "런천", 3, 5, "P09", 8, "Galmuri7")
    put_text(im, "15캡", 3, 15, "P49", 8, "Galmuri7")
    d.rectangle([20, 16, 25, 23], fill=C("P29")); d.line([20, 16, 25, 16], fill=C("P08"))
    return im


def cart_tipped_ds():
    """엎어진 상인회 수레(2×1, 64×44): 옆으로 누운 나무 짐칸 · 하늘을 향해 들린 바퀴 하나 · 땅에 닿은 바퀴 · 부러진 손잡이 ·
    쏟아진 군납 깡통(국방색 · 붉은 띠) · 손잡이에 걸린 짐표 · 오른쪽(7호 문턱 쪽)으로 끌린 핏자국 · 긁힌 이빨 자국."""
    rnd = random.Random(4404)
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 44, 40)
    for k in range(5):                                                                         # 끌린 핏자국(오른쪽으로 옅어진다)
        x = 34 + k * 6
        d.line([x, 36 + (k % 2), x + 5, 37], fill=C("P51" if k < 3 else "P23"), width=2 if k < 2 else 1)
    d.ellipse([28, 33, 36, 39], fill=C("P51")); d.point((31, 35), fill=C("P52"))
    d.polygon([(6, 14), (36, 8), (40, 30), (10, 36)], fill=C(INK))                             # 옆으로 누운 짐칸(바닥판이 보인다)
    d.polygon([(8, 15), (35, 10), (38, 29), (11, 34)], fill=C("P18"))
    for t in (0.3, 0.55, 0.8):                                                                 # 바닥 널빤지 이음
        x0, y0 = 8 + (35 - 8) * t, 15 + (10 - 15) * t
        x1, y1 = 11 + (38 - 11) * t, 34 + (29 - 34) * t
        d.line([x0, y0, x1, y1], fill=C("P17"))
    d.line([8, 15, 35, 10], fill=C("P20"))
    d.line([18, 22, 21, 24], fill=C("P16")); d.line([24, 20, 27, 23], fill=C("P16"))           # 이빨 자국
    d.line([20, 27, 22, 30], fill=C("P16"))
    d.polygon([(10, 36), (38, 29), (40, 33), (12, 40)], fill=C(INK))                           # 짐칸 옆판(누워서 아래로 보이는 테)
    d.polygon([(11, 37), (38, 31), (39, 32), (12, 38)], fill=C("P17"))
    d.line([20, 12, 21, 18], fill=C(INK), width=3); d.line([20, 12, 21, 17], fill=C("P05"))    # 굴대(들린 바퀴 → 짐칸)
    d.ellipse([14, 0, 26, 12], fill=C(INK)); d.ellipse([16, 2, 24, 10], fill=C("P04"))         # 들린 바퀴
    d.line([20, 2, 20, 10], fill=C("P06")); d.line([16, 6, 24, 6], fill=C("P06")); d.point((20, 6), fill=C("P08"))
    d.line([20, 12, 20, 13], fill=C(INK))
    d.ellipse([30, 28, 42, 40], fill=C(INK)); d.ellipse([32, 30, 40, 38], fill=C("P04")); d.point((36, 34), fill=C("P07"))   # 땅에 닿은 바퀴
    d.line([4, 30, 0, 40], fill=C(INK), width=3); d.line([4, 30, 1, 38], fill=C("P05"))        # 부러진 손잡이
    d.line([2, 36, 6, 40], fill=C("P05"))
    d.line([3, 32, 5, 27], fill=C("P21"))                                                      # 짐표 끈
    d.rectangle([2, 22, 8, 27], fill=C(INK)); d.rectangle([3, 23, 7, 26], fill=C("P09")); d.line([4, 25, 6, 25], fill=C("P05"))   # 짐표
    for _ in range(7):                                                                         # 쏟아진 깡통
        x, y = rnd.randint(38, 58), rnd.randint(22, 34)
        d.rectangle([x, y, x + 5, y + 4], fill=C(INK)); d.rectangle([x + 1, y + 1, x + 4, y + 3], fill=C("P30"))
        d.line([x + 1, y + 2, x + 4, y + 2], fill=C("P53")); d.point((x + 1, y + 1), fill=C("P08"))
    d.rectangle([46, 14, 60, 24], fill=C(INK)); d.rectangle([47, 15, 59, 23], fill=C("P30"))   # 찢긴 상자
    d.line([47, 15, 59, 15], fill=C("P31")); d.line([52, 15, 55, 23], fill=C("P02"))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_DS = {
    "w_quarantine_ds": _r(w_quarantine_ds, 2, 0, "wall", dx=2, dy=6),
    "hook_line": _r(hook_line, 2, 1, down=-2),
    "conveyor_ds": _r(conveyor_ds, 3, 1, down=-2),
    "cut_table": _r(cut_table, 2, 1, down=-2),
    "carcass_pile": _r(carcass_pile, 1, 1, down=-2),
    "calf_bones": _r(calf_bones, 2, 1, down=-2),
    "ds_valve": _r(ds_valve, 1, 1, down=-2),
    "egg_drain": _r(egg_drain, 0, 0, "deco"),
    "w_breach_ds": _r(w_breach_ds, 2, 0, "wall", dx=0, dy=0),
    "frost_patch": _r(frost_patch, 0, 0, "deco"),
    "flies_ds": _r(flies_ds, 0, 0, "deco"),
    "shelf_7ho": _r(shelf_7ho, 2, 1, down=-2),
    "ds_cold_panel": _r(ds_cold_panel, 1, 1, down=-2),
    "w_keypad7": _r(w_keypad7, 1, 0, "wall", dx=3, dy=4),
    "frozen_ratking": _r(frozen_ratking, 2, 1, down=-2),
    "reefer_wagon": _r(reefer_wagon, 4, 2, down=-2),
    "w_price_luncheon": _r(w_price_luncheon, 1, 0, "wall", dx=1, dy=6),
    "cart_tipped_ds": _r(cart_tipped_ds, 2, 1, down=-2),
}
STATES_DS = {
    "hook_line": {"picked": lambda: hook_line("picked")},
    "ds_valve": {"open": lambda: ds_valve("open")},
    "egg_drain": {"washed": lambda: egg_drain("washed")},
    "shelf_7ho": {s: (lambda s=s: shelf_7ho(s)) for s in ("half", "empty", "sweat", "thaw", "gnawed")},
    "ds_cold_panel": {s: (lambda s=s: ds_cold_panel(s)) for s in ("redirect", "dead")},
    "w_keypad7": {"open": lambda: w_keypad7("open")},
    "frozen_ratking": {"broken": lambda: frozen_ratking("broken")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_DS.values()] + [fn() for st in STATES_DS.values() for fn in st.values()]
    W = sum(i.width + 4 for i in ims)
    H = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, H + 4), C("P11"))
    x = 2
    for i in ims:
        sheet.alpha_composite(i, (x, 2))
        x += i.width + 4
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)
