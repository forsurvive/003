"""2호선 서쪽 터널 · 낙성대역 승강장 · 서울대입구역 소품(단계 1-11e SQ-S05 환승촌 막차, SD-04a §4.5 · SD-09f U01 · L-UG-02 · SD-16 아이작풍).
  rail_h          레일 한 칸(덧그림, 32×32): 침목 둘 · 녹슨 레일 두 줄 · 자갈 — 가로로 이어 붙여 선로가 된다
  rail_stop       차막이(1×1): 측선 끝 빨간 띠 콘크리트 블록 · 완충 고무
  w_screen_door   스크린도어(벽 소품 2칸): 유리 두 짝 · 2호선 녹색 띠 · 먼지 · 한 짝은 반쯤 열림 · 아이 손자국
  w_screen_door2  스크린도어 깨진 판(유리 금 · 비닐로 막음)
  pf_bench        승강장 벤치(2×1): 스테인리스 좌석 셋 · 등받이 · 먼지 · 한 자리에 놓인 우산
  w_iron_door     서울대입구 방면 철문(벽 소품 2칸): 녹슨 철판 문 · 안쪽 빗장 · 페인트 '관계자 외 출입 금지' · 상태 open(빗장 뽑히고 열림)
  w_siding_door   폐쇄 측선 문(벽 소품 2칸): 철망 셔터 · '회송 · 측선' · 상태 open(올라간 셔터 · 안쪽 어둠)
  luggage         대피 짐 더미(덧그림): 여행 가방 · 신발 한 짝 · 접힌 우산 · 종이봉투
  ticket          2077 승차권(덧그림): 바닥의 작은 종이표
  w_ladder        지상으로 오르는 사다리(벽 소품 1칸): 쇠 사다리 · 위에서 새는 빛 · 봉천 감시조가 묶은 밧줄
  sd_fence_gate   차단 철망 문(1×1): 철망 문짝 · 자물쇠 고리 · 상태 open(옆으로 젖힘)
  w_name_nsd      역 이름판 '낙성대'(벽 소품 3칸): 2호선 녹색 동그라미 · 앞뒤 역(사당 ← → 서울대입구)
  w_name_snu      역 이름판 '서울대입구'(벽 소품 3칸)
  w_clock_2331    승강장 시계(벽 소품 1칸): 23:31에 멈춘 숫자 시계
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text, text_px

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
LINE2 = ("P30", "P56", "P57")          # 2호선 녹색(어둠 · 띠 · 빛)


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


# ================================================================================================ 선로
def rail_h(seed=0):
    """레일 한 칸(덧그림 32×32): 자갈 점 · 침목 둘(나뭇결 · 금) · 녹슨 레일 두 줄(위 빛 한 줄). 가로로 이으면 끊김 없이 맞물린다."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed + 7)
    for _ in range(26):                                                                      # 자갈
        x, y = rnd.randrange(0, 32), rnd.randrange(6, 27)
        d.point((x, y), fill=C(rnd.choice(["P04", "P05", "P06"])))
    for x in (5, 21):                                                                        # 침목(옆으로 긴 나무)
        d.rectangle([x, 6, x + 6, 26], fill=C(INK)); d.rectangle([x + 1, 7, x + 5, 25], fill=C("P17"))
        d.line([x + 2, 8, x + 2, 24], fill=C("P18")); d.point((x + 4, 15), fill=C("P16"))
    for y in (10, 21):                                                                       # 레일
        d.rectangle([0, y, 31, y + 2], fill=C(INK))
        d.line([0, y, 31, y], fill=C("P25")); d.line([0, y + 1, 31, y + 1], fill=C("P24"))
        for x in range(2, 32, 9):
            d.point((x + (seed % 3), y + 1), fill=C("P26"))                                  # 녹 반점
    return im


def rail_stop():
    """차막이(1×1, 32×40): 콘크리트 블록 · 빨강/흰 사선 띠 · 앞 완충 고무 둘."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 10, 28, 36], fill=C(INK)); d.rectangle([4, 11, 27, 35], fill=C("P06"))
    d.rectangle([4, 11, 27, 14], fill=C("P07"))
    for i, x in enumerate(range(4, 28, 6)):
        d.polygon([(x, 16), (x + 3, 16), (x + 6, 22), (x + 3, 22)], fill=C("P53" if i % 2 == 0 else "P09"))
    for x in (8, 20):
        d.rectangle([x, 26, x + 4, 32], fill=C(INK)); d.rectangle([x + 1, 27, x + 3, 31], fill=C("P03"))
    _shadow(d, 2, 30, 37)
    return im


# ================================================================================================ 승강장
def w_screen_door(broken=False):
    """스크린도어(벽 소품 2칸, 64×56): 스테인리스 틀 · 유리 두 짝(너머 선로의 어둠) · 2호선 녹색 띠 · 먼지 줄 · 아이 손바닥 자국.
    broken: 한 짝 유리에 금 · 비닐로 막은 판."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 62, 54], fill=C(INK)); d.rectangle([2, 3, 61, 53], fill=C("P07"))
    d.rectangle([2, 3, 61, 6], fill=C("P08"))
    for x0 in (5, 33):
        d.rectangle([x0, 9, x0 + 25, 50], fill=C(INK)); d.rectangle([x0 + 1, 10, x0 + 24, 49], fill=C("P33"))
        d.line([x0 + 3, 12, x0 + 10, 30], fill=C("P35"))                                     # 유리 반사
        d.line([x0 + 4, 12, x0 + 11, 30], fill=C("P34"))
        for y in range(40, 49, 2):                                                           # 아래 먼지
            d.line([x0 + 1, y, x0 + 24, y], fill=C("P04") if y % 4 == 0 else C("P34"))
    d.rectangle([2, 30, 61, 33], fill=C(LINE2[1])); d.line([2, 30, 61, 30], fill=C(LINE2[2])); d.line([2, 33, 61, 33], fill=C(LINE2[0]))
    put_text(im, "2", 29, 26, "P09", 8, "Galmuri7")
    if broken:
        for a, b in (((40, 14), (50, 26)), ((50, 26), (46, 40)), ((50, 26), (56, 34))):
            d.line([*a, *b], fill=C("P09"))
        d.rectangle([34, 34, 56, 48], fill=C("P05")); d.line([34, 34, 56, 48], fill=C("P06"))  # 비닐 덧댐
    else:
        d.rectangle([9, 18, 12, 22], fill=C("P35")); d.point((10, 17), fill=C("P35"))          # 아이 손바닥
    return im


def pf_bench():
    """승강장 벤치(2×1, 64×40): 스테인리스 좌석 셋 · 등받이 · 다리 · 먼지 · 끝자리에 기대 놓인 우산."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 10, 59, 22], fill=C(INK)); d.rectangle([5, 11, 58, 21], fill=C("P07"))   # 등받이
    for x in (5, 23, 41):
        d.rectangle([x, 11, x + 17, 13], fill=C("P08"))
    d.rectangle([2, 22, 61, 30], fill=C(INK)); d.rectangle([3, 23, 60, 29], fill=C("P08"))   # 좌석
    for x in (20, 39):
        d.line([x, 23, x, 29], fill=C("P06"))
    d.line([3, 23, 60, 23], fill=C("P09"))
    for x in (7, 55):
        d.rectangle([x, 30, x + 2, 36], fill=C(INK))
    for x in range(8, 58, 5):
        d.point((x, 27), fill=C("P05"))                                                      # 먼지
    d.line([58, 12, 54, 34], fill=C(INK), width=2); d.line([58, 12, 55, 30], fill=C("P53"))  # 우산
    d.polygon([(55, 30), (52, 35), (57, 35)], fill=C("P52"))
    _shadow(d, 2, 62, 37)
    return im


def w_iron_door(state="shut"):
    """서울대입구 방면 철문(벽 소품 2칸, 64×60): 녹슨 철판 두 짝 · 리벳 · 안쪽 가로 빗장 · '관계자 외 출입 금지' 페인트.
    open: 빗장이 뽑혀 바닥에 · 문짝이 안으로 젖혀져 너머 터널의 어둠."""
    im = img(64, 60)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 62, 58], fill=C(INK)); d.rectangle([2, 3, 61, 58], fill=C("P06"))
    if state == "open":
        d.rectangle([8, 8, 55, 58], fill=C(INK)); d.rectangle([9, 9, 54, 58], fill=C("P02"))
        for y in range(40, 58, 6):
            d.line([16, y, 47, y], fill=C("P03"))                                            # 너머 침목
        d.polygon([(9, 9), (17, 13), (17, 58), (9, 58)], fill=C("P24")); d.line([10, 10, 10, 57], fill=C("P26"))
        d.polygon([(54, 9), (46, 13), (46, 58), (54, 58)], fill=C("P24")); d.line([53, 10, 53, 57], fill=C("P23"))
        d.rectangle([12, 54, 50, 57], fill=C(INK)); d.rectangle([13, 55, 49, 56], fill=C("P12"))   # 바닥에 뽑힌 빗장
        return im
    for x0 in (8, 32):
        d.rectangle([x0, 8, x0 + 23, 58], fill=C(INK)); d.rectangle([x0 + 1, 9, x0 + 22, 58], fill=C("P24"))
        d.line([x0 + 2, 10, x0 + 2, 57], fill=C("P26"))
        for y in range(12, 56, 10):
            d.point((x0 + 4, y), fill=C("P23")); d.point((x0 + 19, y), fill=C("P23"))
    d.rectangle([4, 32, 59, 37], fill=C(INK)); d.rectangle([5, 33, 58, 36], fill=C("P12")); d.line([5, 33, 58, 33], fill=C("P13"))
    d.rectangle([28, 30, 35, 39], fill=C(INK)); d.rectangle([29, 31, 34, 38], fill=C("P11"))   # 빗장 걸쇠
    put_text(im, "관계자외", 11, 14, "P53", 8, "Galmuri7")
    put_text(im, "출입금지", 11, 22, "P53", 8, "Galmuri7")
    return im


def w_siding_door(state="shut"):
    """폐쇄 측선 문(벽 소품 2칸, 64×60): 철망 셔터 · 위 표지 '회송 · 측선' · open: 셔터가 말려 올라가 안쪽 어둠 · 선로가 이어진다."""
    im = img(64, 60)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 62, 58], fill=C(INK)); d.rectangle([2, 3, 61, 58], fill=C("P05"))
    d.rectangle([6, 4, 57, 12], fill=C(INK)); d.rectangle([7, 5, 56, 11], fill=C("P47"))
    put_text(im, "회송·측선", 10, 4, "P01", 8, "Galmuri7")
    d.rectangle([6, 14, 57, 58], fill=C(INK)); d.rectangle([7, 15, 56, 58], fill=C("P02"))
    if state == "open":
        d.rectangle([7, 15, 56, 19], fill=C("P11")); d.line([7, 19, 56, 19], fill=C("P12"))   # 말려 올라간 셔터
        for y in range(36, 58, 7):
            d.line([16, y, 47, y], fill=C("P03"))
        return im
    for y in range(16, 58, 4):
        d.line([7, y, 56, y], fill=C("P11"))
    for x in range(9, 56, 4):
        d.line([x, 15, x, 58], fill=C("P10"))
    d.rectangle([28, 50, 35, 56], fill=C("P12")); d.point((31, 53), fill=C(INK))              # 바닥 자물쇠
    return im


def luggage(seed=3):
    """대피 짐 더미(덧그림, 48×32): 여행 가방(바퀴) · 종이봉투 · 신발 한 짝 · 접힌 우산 — 2077-10-23 밤 사람들이 흘리고 간 것."""
    im = img(48, 32)
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    d.rectangle([4, 8, 21, 25], fill=C(INK)); d.rectangle([5, 9, 20, 24], fill=C(rnd.choice(["P52", "P43", "P17"])))
    d.line([5, 9, 20, 9], fill=C("P09")); d.rectangle([10, 5, 15, 8], outline=C(INK))
    d.point((7, 26), fill=C(INK)); d.point((18, 26), fill=C(INK))
    d.polygon([(24, 14), (36, 14), (37, 27), (23, 27)], fill=C(INK)); d.polygon([(25, 15), (35, 15), (36, 26), (24, 26)], fill=C("P20"))
    d.line([27, 15, 27, 12], fill=C("P19"))
    d.ellipse([38, 21, 46, 27], fill=C(INK)); d.ellipse([39, 22, 45, 26], fill=C("P03"))    # 신발
    d.line([2, 28, 30, 30], fill=C(INK), width=2); d.line([3, 28, 29, 29], fill=C("P44"))  # 우산
    _shadow(d, 2, 46, 29)
    return im


def ticket():
    """2077 승차권(덧그림, 16×12): 접힌 종이표 · 녹색 띠 · 자기 띠."""
    im = img(16, 12)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 4), (12, 2), (14, 8), (4, 10)], fill=C(INK))
    d.polygon([(3, 4), (12, 3), (13, 7), (4, 9)], fill=C("P09"))
    d.line([4, 5, 12, 4], fill=C(LINE2[1])); d.line([5, 8, 12, 7], fill=C("P03"))
    return im


def w_ladder():
    """지상으로 오르는 사다리(벽 소품 1칸, 32×64): 쇠 사다리 · 위에서 새는 햇빛 · 봉천 감시조가 묶은 밧줄 · 매듭에 꽂힌 헝겊."""
    im = img(32, 64)
    d = ImageDraw.Draw(im)
    d.polygon([(6, 0), (26, 0), (22, 20), (10, 20)], fill=C("P47"))                           # 새는 빛
    d.polygon([(9, 0), (23, 0), (20, 14), (12, 14)], fill=C("P50"))
    for x in (8, 22):
        d.rectangle([x, 2, x + 2, 62], fill=C(INK)); d.line([x + 1, 2, x + 1, 62], fill=C("P12"))
    for y in range(6, 62, 6):
        d.rectangle([9, y, 23, y + 1], fill=C(INK)); d.line([10, y, 22, y], fill=C("P13"))
    d.line([24, 10, 28, 40], fill=C("P21")); d.line([25, 10, 29, 40], fill=C("P20"))          # 밧줄
    d.rectangle([26, 22, 30, 26], fill=C("P52"))                                              # 헝겊(봉천 표식)
    return im


def sd_fence_gate(state="shut"):
    """차단 철망 문(1×1, 32×48): sd_fence와 같은 철망 · 가운데 경첩 문짝 · 자물쇠 고리. open: 문짝이 옆으로 젖혀져 통로가 열림."""
    im = img(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 4, 3, 46], fill=C("P11")); d.rectangle([28, 4, 30, 46], fill=C("P11"))
    d.line([0, 5, 31, 5], fill=C("P05"))
    for x in range(2, 30, 4):
        d.line([x, 3, x + 2, 7], fill=C("P05"))
    if state == "open":
        d.polygon([(27, 8), (31, 12), (31, 44), (27, 44)], fill=C("P11"))
        for y in range(12, 44, 5):
            d.line([28, y, 30, y + 2], fill=C("P06"))
        d.line([4, 44, 27, 44], fill=C("P04"))
        return im
    d.rectangle([4, 8, 27, 44], outline=C("P12"))
    for y in range(10, 44, 5):
        for x in range(5, 27, 5):
            d.line([x, y, x + 2, y + 2], fill=C("P06")); d.line([x + 2, y + 2, x + 4, y], fill=C("P06"))
    d.rectangle([24, 24, 28, 30], fill=C(INK)); d.rectangle([25, 25, 27, 29], fill=C("P24"))   # 자물쇠
    return im


def _station_name(name, prev, nxt):
    """역 이름판(벽 소품 3칸, 96×40): 흰 판 · 2호선 녹색 동그라미 '2' · 역 이름 · 아래 녹색 띠에 앞뒤 역."""
    im = img(96, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 6, 94, 36], fill=C(INK)); d.rectangle([2, 7, 93, 35], fill=C("P09"))
    d.rectangle([2, 26, 93, 35], fill=C(LINE2[1])); d.line([2, 26, 93, 26], fill=C(LINE2[0]))
    d.ellipse([5, 9, 19, 23], fill=C(LINE2[0])); d.ellipse([6, 10, 18, 22], fill=C(LINE2[1]))
    put_text(im, "2", 10, 11, "P09", 8, "Galmuri7")
    font = ("Galmuri11", 12)
    if text_px(name, 12, "Galmuri11")[1] > 68:                                                 # 긴 이름(서울대입구)은 한 치수 작게
        font = ("Galmuri9", 10)
    put_text(im, name, 23, 9 if font[1] == 12 else 11, "P01", font[1], font[0])
    put_text(im, "‹" + prev, 4, 27, "P09", 8, "Galmuri7")
    _, w, _ = text_px(nxt + "›", 8, "Galmuri7")
    put_text(im, nxt + "›", 92 - w, 27, "P09", 8, "Galmuri7")
    for x in range(8, 90, 13):                                                                # 먼지 · 녹물
        d.point((x, 8), fill=C("P07"))
    d.line([90, 7, 91, 24], fill=C("P26"))
    return im


def w_name_nsd():
    return _station_name("낙성대", "사당", "서울대입구")


def w_name_snu():
    return _station_name("서울대입구", "낙성대", "봉천")


def w_clock_2331():
    """승강장 시계(벽 소품 1칸, 32×24): 검은 판 · 붉은 7세그먼트 '23:31' — 그날 밤 그 시각에 멈췄다."""
    im = img(32, 24)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 4, 30, 20], fill=C(INK)); d.rectangle([2, 5, 29, 19], fill=C("P02"))
    put_text(im, "23:31", 4, 8, "P53", 8, "Galmuri7")
    d.line([15, 1, 15, 4], fill=C("P05"))
    return im


# ================================================================================================ 역무 파수-3(소품 판 — 퀘스트 동안 한 곳에만 선다, SD-20 P3)
def metro_robot_down():
    """측선에 쓰러진 역무 파수-3(덧그림 64×40): robot_sentry 지하철형 쓰러짐 마지막 컷 — 방전(눈 꺼짐)."""
    import robot_sentry as RS
    rows, _ = RS.metro_sheet("sleep")
    f = rows[2][-1]
    return f.crop((0, 24, 64, 64))


def metro_robot_stand(eye="idle"):
    """역무실 방송 설비 곁에 선 역무 파수-3(1×1, 64×64): 지하철형 서 있는 앞모습 · 안내 화면이 켜져 있다."""
    import robot_sentry as RS
    rows, _ = RS.metro_sheet(eye)
    return rows[0][0].copy()


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_S05 = {
    "rail_h": _r(lambda: rail_h(0), 0, 0, "deco"),
    "rail_h2": _r(lambda: rail_h(1), 0, 0, "deco"),
    "rail_stop": _r(rail_stop, 1, 1, down=-2),
    "w_screen_door": _r(w_screen_door, 2, 0, "wall", dx=0, dy=2),
    "w_screen_door2": _r(lambda: w_screen_door(True), 2, 0, "wall", dx=0, dy=2),
    "pf_bench": _r(pf_bench, 2, 1, down=-2),
    "w_iron_door": _r(w_iron_door, 2, 0, "wall", dx=0, dy=0),
    "w_siding_door": _r(w_siding_door, 2, 0, "wall", dx=0, dy=0),
    "luggage": _r(luggage, 0, 0, "deco"),
    "luggage2": _r(lambda: luggage(8), 0, 0, "deco"),
    "ticket": _r(ticket, 0, 0, "deco"),
    "w_ladder": _r(w_ladder, 1, 0, "wall", dx=0, dy=0),
    "sd_fence_gate": _r(sd_fence_gate, 1, 1, down=-2),
    "w_name_nsd": _r(w_name_nsd, 3, 0, "wall", dx=0, dy=6),
    "w_name_snu": _r(w_name_snu, 3, 0, "wall", dx=0, dy=6),
    "w_clock_2331": _r(w_clock_2331, 1, 0, "wall", dx=0, dy=8),
    "metro_robot_down": _r(metro_robot_down, 0, 0, "deco"),
    "metro_robot_stand": _r(metro_robot_stand, 1, 1, down=-2),
}

STATES_S05 = {
    "w_iron_door": {"open": lambda: w_iron_door("open")},
    "w_siding_door": {"open": lambda: w_siding_door("open")},
    "sd_fence_gate": {"open": lambda: sd_fence_gate("open")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_s05.png"
    ims = [v["fn"]() for v in PROPS_S05.values()] + [f() for st in STATES_S05.values() for f in st.values()]
    W = sum(i.width for i in ims) + 6 * len(ims)
    Hh = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, Hh + 4), C("P04"))
    x = 2
    for i in ims:
        sheet.alpha_composite(i, (x, 2))
        x += i.width + 6
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)
