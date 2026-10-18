"""구로 공단 지식산업센터 소품(단계 1-D7, 1-D 계획 §13.5 · SD-09a L-R02-21 L1037 · SD-16 아이작풍).
  원문: 2077 태성 협력 금형 공장 · 세진 부품 공장 · 생산 할당 게시판 '10월 목표 달성률 103% — 우수 라인 표창' · 표창장 아래 엎드린 작업자 해골.
  확정안: 라인 박자(프레스 쿵) · 출근 카드(10/23 출근만 · 퇴근 없음) · 11월 서류(타자기) · 비상정지 · 외벽 화물 데크 크레인 · 옥상 굴뚝 퇴근 낙서.
    w_clock_ks      출근 기록기(벽 1칸): 둥근 시계 · 카드 투입구 · '출근 · 퇴근' 레버
    w_cards_ks      카드꽂이(벽 2칸): 칸마다 누런 근태 카드 — 모두 '출근' 쪽 칸에만 꽂혔다 / 상태 punched(카드 하나가 빠진 자리)
    press_ks        금형 프레스(2×2): 주철 기둥 둘 · 위 램 · 아래 볼스터 · 안전 빗금 / 상태 down(램이 내려앉음 · 불꽃) · off(전원 꺼짐 — 표시등 소등)
    w_board_ks      생산 게시판(벽 2칸): '10월 목표 달성률 103%' · 막대그래프 · 표창장 / 상태 off(불 꺼짐 — 회색) · award(이달의 우수 작업자 이름 칸)
    bench_skel_ks   엎드린 해골 작업대(2×1): 작업대 · 엎드린 작업복 해골 둘 · 공구 / 상태 stamped(손등에 붉은 '퇴근' 도장)
    typewriter_ks   타자기(덮개 — 책상 위 · 발 없음): 세진 사무용 타자기 · 끼운 서식 종이
    estop_ks        비상정지 기둥(1×1): 노란 기둥 · 붉은 버섯 단추 · '비상정지' / 상태 pressed(눌림 · 회전등 꺼짐)
    deck_crane_ks   외벽 화물 데크 크레인(2×2): 철골 데크 · 지브 크레인 · 갈고리 · 화물칸 / 상태 lowered(화물칸이 내려감 — 빈 갈고리)
    chimney_ks      옥상 굴뚝(1×2): 벽돌 굴뚝 · 분필 낙서 '퇴근하고 싶다'
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다. 위에서 빛(위 밝게 · 아래 어둡게), 반투명 없음."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
STEEL = ("P03", "P04", "P05", "P06", "P07")
IRON = ("P10", "P11", "P12", "P13", "P14")
CREAM = ("P06", "P07", "P08", "P09")
WOOD = ("P16", "P17", "P18", "P19", "P20")
PAPER = ("P20", "P21", "P22")
SAFE = ("P58", "P59", "P49", "P50")
BRICK = ("P23", "P24", "P25", "P39")


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


def _hazard(d, x0, y0, x1, y1):
    """안전 빗금(노랑 · 검정) — 칸 안에서만(빗금이 테 밖으로 번지지 않게 점으로 찍는다)."""
    d.rectangle([x0, y0, x1, y1], fill=C(SAFE[2]))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x + (y1 - y)) % 4 == 0:
                d.point((x, y), fill=C(INK))


def w_clock_ks():
    """출근 기록기(벽 1칸, 32×44): 크림 함 · 둥근 시계(10시 23분에 멈춤) · 카드 투입구 · 레버."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    _box(d, 3, 2, 28, 41, CREAM)
    d.ellipse([7, 5, 24, 22], fill=C(INK)); d.ellipse([8, 6, 23, 21], fill=C("P09"))
    for a in range(12):
        import math
        x, y = 15.5 + 6 * math.sin(a * math.pi / 6), 13.5 - 6 * math.cos(a * math.pi / 6)
        d.point((round(x), round(y)), fill=C("P04"))
    d.line([15, 13, 12, 11], fill=C(INK)); d.line([15, 13, 19, 9], fill=C("P53"))     # 멈춘 바늘
    d.rectangle([9, 26, 22, 29], fill=C(INK)); d.line([10, 27, 21, 27], fill=C("P04"))   # 투입구
    d.rectangle([6, 33, 11, 37], fill=C("P55")); d.rectangle([20, 33, 25, 37], fill=C("P53"))   # 출근 · 퇴근 단추
    d.point((8, 35), fill=C("P56")); d.point((22, 35), fill=C("P04"))
    return im


def w_cards_ks(state=""):
    """카드꽂이(벽 2칸, 64×44): 철판 걸이 · 칸 4줄 × 7 · 누런 근태 카드 — 모두 왼쪽('출근') 열에만. punched = 카드 하나 빠짐."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    _box(d, 1, 2, 62, 42, STEEL)
    put_text(im, "출근", 6, 2, "P55", 8, "Galmuri7")
    put_text(im, "퇴근", 38, 2, "P53", 8, "Galmuri7")
    d.line([32, 11, 32, 40], fill=C(STEEL[0]))
    rnd = random.Random(23)
    for r in range(4):
        for c in range(7):
            x = 4 + c * 4
            y = 13 + r * 7
            if state == "punched" and (r, c) == (1, 3):
                d.rectangle([x, y, x + 2, y + 5], fill=C(STEEL[0]))
                continue
            d.rectangle([x, y - rnd.randint(0, 1), x + 2, y + 5], fill=C(PAPER[1]))
            d.point((x + 1, y + 2), fill=C("P53"))                                   # 찍힌 자국(10/23)
        for c in range(7):
            d.rectangle([35 + c * 4, 13 + r * 7, 37 + c * 4, 18 + r * 7], fill=C(STEEL[0]))   # 퇴근 칸은 비었다
    return im


def press_ks(state=""):
    """금형 프레스(2×2, 64×88): 주철 기둥 둘 · 위 크라운 · 램 · 볼스터 · 안전 빗금 · 표시등."""
    im = img(64, 88)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 86)
    _box(d, 4, 70, 59, 84, IRON)                                                     # 바닥 받침
    _hazard(d, 5, 80, 58, 82)
    for x in (6, 50):                                                                # 기둥
        _box(d, x, 12, x + 8, 72, IRON)
    _box(d, 2, 4, 61, 18, IRON)                                                      # 크라운
    d.rectangle([24, 7, 39, 13], fill=C(INK)); put_text(im, "TS-P", 25, 4, "P49", 8, "Galmuri7")
    lamp = {"": "P56", "down": "P54", "off": "P04"}[state]
    d.ellipse([52, 7, 57, 12], fill=C(INK)); d.ellipse([53, 8, 56, 11], fill=C(lamp))
    ram_y = 44 if state == "down" else 22
    _box(d, 15, ram_y, 48, ram_y + 14, STEEL)                                        # 램
    d.rectangle([28, 18, 35, ram_y], fill=C(INK)); d.line([31, 19, 31, ram_y - 1], fill=C(STEEL[4]))   # 피스톤
    _box(d, 15, 60, 48, 70, STEEL)                                                   # 볼스터(아래 금형 자리)
    d.ellipse([27, 62, 36, 68], fill=C(INK)); d.ellipse([28, 63, 35, 67], fill=C(IRON[1]))
    if state == "down":
        for (x, y, c) in ((14, 58, "P50"), (50, 59, "P60"), (20, 56, "P49"), (46, 55, "P50")):
            d.point((x, y), fill=C(c)); d.point((x + 1, y - 1), fill=C(c))
    return im


def w_board_ks(state=""):
    """생산 게시판(벽 2칸, 64×48): 녹색 판 · '10월 목표 103%' · 막대그래프 · 표창장(금테). off = 불 꺼짐(회색) · award = 우수 작업자 이름 칸."""
    im = img(64, 48)
    d = ImageDraw.Draw(im)
    off = state == "off"
    _box(d, 1, 2, 62, 45, ("P28", "P29", "P30", "P31") if not off else STEEL)
    d.rectangle([3, 4, 60, 13], fill=C("P01"))
    put_text(im, "10월 달성 103%", 4, 3, "P49" if not off else "P05", 8, "Galmuri7")
    for i, h in enumerate((10, 14, 12, 17, 19)):                                     # 막대
        x = 6 + i * 6
        d.rectangle([x, 40 - h, x + 3, 40], fill=C("P56" if not off else "P05"))
    d.line([5, 41, 34, 41], fill=C("P09" if not off else "P05"))
    _box(d, 38, 17, 59, 41, (PAPER[0], PAPER[1], PAPER[2]))                          # 표창장
    d.rectangle([39, 18, 58, 40], outline=C(SAFE[2]))
    put_text(im, "표창", 42, 18, "P53", 8, "Galmuri7")
    if state == "award":
        d.rectangle([40, 30, 57, 38], fill=C("P09"))
        d.line([42, 34, 55, 34], fill=C(INK)); d.line([42, 36, 51, 36], fill=C(INK))  # 붙인 이름 쪽지
    else:
        d.line([42, 31, 55, 31], fill=C("P04")); d.line([42, 34, 53, 34], fill=C("P04")); d.line([42, 37, 50, 37], fill=C("P04"))
    return im


def _skel(d, x, y, flip=False, stamp=False):
    """엎드린 해골(작업복): 둥근 두개골 · 등(카키 작업복) · 작업대 위로 뻗은 뼈 팔."""
    s = -1 if flip else 1
    d.ellipse([x - 5, y - 5, x + 5, y + 4], fill=C(INK)); d.ellipse([x - 4, y - 4, x + 4, y + 3], fill=C("P08"))
    d.point((x - 2 * s, y - 1), fill=C(INK)); d.point((x - 1 * s, y + 1), fill=C(INK))     # 눈구멍
    d.rounded_rectangle([x - 7, y + 3, x + 7, y + 14], radius=3, fill=C(INK))
    d.rounded_rectangle([x - 6, y + 4, x + 6, y + 13], radius=3, fill=C("P30"))           # 카키 작업복 등
    d.line([x + 6 * s, y + 5, x + 12 * s, y + 2], fill=C("P08"), width=2)                  # 뻗은 뼈 팔
    d.point((x + 13 * s, y + 2), fill=C("P07"))
    if stamp:
        d.rectangle([x + 9 * s - 1, y, x + 9 * s + 2, y + 3], fill=C("P53"))               # 손등의 '퇴근' 도장


def bench_skel_ks(state=""):
    """엎드린 해골 작업대(2×1, 64×52): 철제 작업대 · 해골 둘 · 렌치 · 반제품 총열 하나."""
    im = img(64, 52)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 50)
    _box(d, 2, 26, 61, 34, STEEL)
    for x in (5, 56):
        d.rectangle([x, 34, x + 3, 49], fill=C(INK)); d.line([x + 1, 35, x + 1, 48], fill=C(STEEL[2]))
    d.line([8, 44, 56, 44], fill=C(STEEL[1]))
    d.rectangle([28, 27, 40, 29], fill=C(INK)); d.line([29, 28, 39, 28], fill=C(STEEL[4]))   # 반제품 총열
    d.line([46, 28, 53, 30], fill=C("P04"), width=2)                                       # 렌치
    stamp = state == "stamped"
    _skel(d, 15, 13, False, stamp)
    _skel(d, 48, 14, True, stamp)
    return im


def typewriter_ks():
    """타자기(덮개 32×24 — 책상 위 · 발 없음): 크림 몸 · 자판 · 끼운 서식 종이 '11월 목표: ___'."""
    im = img(32, 24)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 0, 23, 9], fill=C(INK)); d.rectangle([9, 1, 22, 9], fill=C("P09"))       # 종이
    d.line([11, 3, 20, 3], fill=C("P04")); d.line([11, 5, 17, 5], fill=C("P04")); d.line([18, 5, 21, 5], fill=C("P53"))
    _box(d, 4, 8, 27, 21, CREAM)
    d.rectangle([5, 9, 26, 11], fill=C("P04"))                                              # 롤러
    for r in range(3):
        for c in range(7):
            d.point((7 + c * 3, 14 + r * 2), fill=C("P02"))
    return im


def estop_ks(state=""):
    """비상정지 기둥(1×1, 32×52): 노랑 빗금 기둥 · 붉은 버섯 단추 · 위 회전등. pressed = 눌려 들어감 · 회전등 꺼짐."""
    im = img(32, 52)
    d = ImageDraw.Draw(im)
    _shadow(d, 8, 24, 50)
    d.rectangle([11, 18, 20, 49], fill=C(INK))
    _hazard(d, 12, 19, 19, 48)
    _box(d, 8, 14, 23, 22, STEEL)
    pressed = state == "pressed"
    d.ellipse([10, 9 + (3 if pressed else 0), 21, 17], fill=C(INK))
    d.ellipse([11, 10 + (3 if pressed else 0), 20, 16], fill=C("P53" if not pressed else "P52"))
    d.point((13, 11 + (3 if pressed else 0)), fill=C("P54"))
    d.ellipse([12, 1, 19, 8], fill=C(INK)); d.ellipse([13, 2, 18, 7], fill=C("P60" if not pressed else "P04"))
    return im


def deck_crane_ks(state=""):
    """외벽 화물 데크 크레인(2×2, 64×80): 철골 데크(바깥은 허공) · 지브 크레인 기둥 · 팔 · 와이어 · 화물칸. lowered = 화물칸이 내려감."""
    im = img(64, 80)
    d = ImageDraw.Draw(im)
    _box(d, 1, 60, 62, 76, IRON)                                                       # 데크 판
    for x in range(4, 60, 6):
        d.line([x, 62, x, 74], fill=C(IRON[0]))
    _hazard(d, 2, 58, 61, 60)                                                          # 데크 끝 빗금
    d.rectangle([6, 8, 11, 62], fill=C(INK)); d.rectangle([7, 9, 10, 61], fill=C(SAFE[1]))   # 기둥
    d.rectangle([6, 6, 58, 11], fill=C(INK)); d.rectangle([7, 7, 57, 10], fill=C(SAFE[2]))    # 지브 팔
    for x in range(12, 56, 6):
        d.line([x, 7, x + 4, 10], fill=C(INK))
    d.rectangle([44, 11, 50, 15], fill=C(INK)); d.rectangle([45, 12, 49, 14], fill=C(STEEL[2]))   # 트롤리
    if state == "lowered":
        d.line([47, 15, 47, 40], fill=C(STEEL[0]))
        d.arc([44, 38, 50, 44], 0, 180, fill=C(STEEL[3]))                               # 빈 갈고리
    else:
        d.line([47, 15, 47, 32], fill=C(STEEL[0]))
        _box(d, 36, 32, 58, 52, STEEL)                                                  # 화물칸(철망 상자)
        for x in range(39, 57, 3):
            d.line([x, 34, x, 50], fill=C(STEEL[0]))
        d.line([37, 42, 57, 42], fill=C(STEEL[0]))
    return im


def chimney_ks():
    """옥상 굴뚝(1×2, 32×72): 벽돌 · 위 철제 테 · 분필 낙서 '퇴근하고 싶다' · 그을음."""
    im = img(32, 72)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 30, 70)
    _box(d, 3, 8, 28, 68, BRICK)
    for y in range(12, 66, 5):
        d.line([4, y, 27, y], fill=C(BRICK[0]))
        off = 0 if (y // 5) % 2 else 6
        for x in range(4 + off, 27, 12):
            d.line([x, y - 4, x, y], fill=C(BRICK[0]))
    _box(d, 1, 3, 30, 9, STEEL)
    d.rectangle([5, 0, 26, 4], fill=C(INK))
    put_text(im, "퇴근", 7, 30, "P09", 8, "Galmuri7")
    put_text(im, "하고", 7, 40, "P09", 8, "Galmuri7")
    put_text(im, "싶다", 7, 50, "P09", 8, "Galmuri7")
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_KS = {
    "w_clock_ks": _r(w_clock_ks, 1, 0, "wall", dx=0, dy=2),
    "w_cards_ks": _r(lambda: w_cards_ks(), 2, 0, "wall", dx=0, dy=2),
    "press_ks": _r(lambda: press_ks(), 2, 2, down=-2),
    "w_board_ks": _r(lambda: w_board_ks(), 2, 0, "wall", dx=0, dy=0),
    "bench_skel_ks": _r(lambda: bench_skel_ks(), 2, 1, down=-2),
    "typewriter_ks": _r(typewriter_ks, 0, 0, "deco"),
    "estop_ks": _r(lambda: estop_ks(), 1, 1, down=-2),
    "deck_crane_ks": _r(lambda: deck_crane_ks(), 2, 2, down=-2),
    "chimney_ks": _r(chimney_ks, 1, 2, down=-2),
}
STATES_KS = {
    "w_cards_ks": {"punched": lambda: w_cards_ks("punched")},
    "press_ks": {"down": lambda: press_ks("down"), "off": lambda: press_ks("off")},
    "w_board_ks": {"off": lambda: w_board_ks("off"), "award": lambda: w_board_ks("award")},
    "bench_skel_ks": {"stamped": lambda: bench_skel_ks("stamped")},
    "estop_ks": {"pressed": lambda: estop_ks("pressed")},
    "deck_crane_ks": {"lowered": lambda: deck_crane_ks("lowered")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_KS.values()] + [fn() for st in STATES_KS.values() for fn in st.values()]
    cols = 6
    cw, ch = 76, 96
    sheet = Image.new("RGBA", (cols * cw, ((len(ims) + cols - 1) // cols) * ch), (70, 66, 74, 255))
    for i, m in enumerate(ims):
        sheet.alpha_composite(m, ((i % cols) * cw + 4, (i // cols) * ch + 4))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
