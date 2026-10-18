"""U04 여의도 지하(5호선 영등포시장역 · 여의도역 · 여의나루역) 소품(단계 1-D10, 1-D 계획 §16 · SD-09f L657 · L800 · L802 · SD-16 아이작풍).
  원문 앵커: 영등포시장역 = 지하시장 '뒷문' 셔터('지하시장 후문 — 손님 환영, 피부 불문' · JH 적대면 용접) ·
  여의도역 = 진공관 플랩 시세판('태성중공업 ▲ 전쟁 수혜') · 계엄 공병반 배전실 · 벙커 배선 점검구(자물쇠 50) ·
  여의나루역 = 판독기 문이 반쯤 닫힌 채 굳은 대심도 대피소(문틈에 낀 해골 팔 — 2077 주민등록증).
    w_flap_ug      진공관 플랩 시세판(벽 3칸): 검은 틀 · 반쯤 넘어가다 멈춘 플랩 칸 · 주황 글 / 상태 close(장 마감 — 플랩이 다 넘어감)
    shutter_jm     지하시장 후문 셔터(2×1): 골판 셔터에 페인트 글 · 손잡이 / 상태 up(올라감) · weld(붉은 용접선 · 봉쇄)
    switchboard_ug 배전반(2×1): 회색 함 둘 · 칼날 개폐기 · 계기 · 굵은 전선 다발 / 상태 open(문짝 열리고 선이 뽑혀 나옴 — 조사 중)
    w_hatch_ug     벽 점검구(벽 1칸): 철 덮개 · 자물쇠 · 스텐실 'B-7 벙커 배선' · 전선 다발이 벽으로 / 상태 open(덮개가 열리고 사다리 구멍)
    door_shelter   대피소 판독기 문(2×1): 두꺼운 미닫이 철문 한 짝 · 붉은 판독기 · 문틈에 낀 해골 팔과 카드
    rail_cart_ug   운반조 레일 수레(2×1): 나무 바닥 · 쇠바퀴 넷 · 밀대 · 밧줄 / 상태 load(상자 · 자루를 실음)
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
AMBER = ("P58", "P59", "P60")
RED = ("P52", "P54", "P50")
WOOD = ("P16", "P17", "P18")
BONE = ("P19", "P20", "P21", "P22")


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


def w_flap_ug(state=""):
    """진공관 플랩 시세판(벽 3칸, 96×44): 검은 틀 · 머리 '여의도 시세' · 넉 줄 플랩(칸마다 가운데 이음선).
    셋째 줄 '태성중공업 ▲'만 또렷하고, 나머지 줄은 반쯤 넘어가다 멈춰 위아래가 다른 글. close = 머리 '장 마감' · 모든 줄이 다 넘어가 반듯."""
    im = img(96, 44)
    d = ImageDraw.Draw(im)
    _box(d, 1, 1, 94, 42, ("P02", "P03", "P04", "P05"))
    put_text(im, "장 마감" if state == "close" else "여의도 시세", 5, 2, AMBER[2], 8, "Galmuri7")
    d.ellipse([86, 4, 90, 8], fill=C(RED[1] if state != "close" else "P56"))                   # 진공관 표시등
    for row in range(4):
        y = 13 + row * 7
        for col in range(11):                                                                   # 플랩 칸
            x = 4 + col * 8
            d.rectangle([x, y, x + 6, y + 5], fill=C(INK))
            stuck = state != "close" and row != 2 and (col * 3 + row) % 4 == 1
            d.rectangle([x + 1, y + 1, x + 5, y + 2], fill=C("P04" if stuck else "P03"))
            d.rectangle([x + 1, y + 3, x + 5, y + 4], fill=C("P03"))
            d.line([x + 1, y + 3, x + 5, y + 3], fill=C(INK))                                     # 이음선
            if stuck:                                                                           # 반쯤 넘어간 플랩 — 위 판이 비스듬히 튀어나옴
                d.line([x, y + 1, x + 6, y], fill=C("P05"))
        if row == 2:
            put_text(im, "태성중공업", 5, y - 1, AMBER[2], 8, "Galmuri7")
            d.polygon([(76, y + 4), (79, y), (82, y + 4)], fill=C(RED[1]))                        # ▲
        elif state == "close":
            for col in range(0, 10, 2):
                d.point((6 + col * 8, y + 2), fill=C(AMBER[1]))
        else:
            for col in (1, 4, 7):
                d.point((6 + col * 8, y + 2), fill=C(AMBER[0]))
    return im


def shutter_jm(state=""):
    """지하시장 후문 셔터(2×1, 64×56): 셔터 통 · 골판 · 페인트 '후문' · '피부 불문'(서툰 손글씨) · 아래 손잡이 둘.
    up = 통만 남음 · weld = 이음선마다 붉은 용접 자국 · 'JH 봉쇄' 가위표."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    _box(d, 1, 2, 62, 10, STEEL[1:])
    d.line([3, 6, 60, 6], fill=C(STEEL[0]))
    d.rectangle([2, 10, 4, 53], fill=C(INK)); d.rectangle([59, 10, 61, 53], fill=C(INK))
    if state == "up":
        d.rectangle([5, 11, 58, 13], fill=C(STEEL[2])); d.line([5, 13, 58, 13], fill=C(INK))
        _shadow(d, 5, 59, 54)
        return im
    d.rectangle([5, 11, 58, 52], fill=C(STEEL[2]))
    for y in range(12, 52, 3):
        d.line([5, y, 58, y], fill=C(STEEL[0])); d.line([5, y + 1, 58, y + 1], fill=C(STEEL[3]))
    d.rectangle([9, 15, 54, 34], fill=C("P29"))                                                 # 칠한 판(초록 페인트)
    d.rectangle([9, 15, 54, 34], outline=C(INK))
    put_text(im, "후문", 12, 15, "P09", 8, "Galmuri7")
    put_text(im, "피부불문", 12, 25, "P20", 8, "Galmuri7")
    d.point((50, 17), fill=C("P09")); d.point((51, 31), fill=C("P20"))                          # 페인트 방울
    for x in (18, 42):
        d.rectangle([x, 46, x + 5, 49], fill=C(INK)); d.line([x + 1, 47, x + 4, 47], fill=C(STEEL[4]))
    if state == "weld":
        for y in (20, 32, 44):
            d.line([5, y, 58, y], fill=C(RED[0])); d.line([5, y + 1, 58, y + 1], fill=C(RED[2]))
        d.line([12, 14, 50, 46], fill=C(RED[1])); d.line([50, 14, 12, 46], fill=C(RED[1]))
    _shadow(d, 5, 59, 53)
    return im


def switchboard_ug(state=""):
    """배전반(2×1, 64×60): 회색 함 둘 · 위에 계기 셋 · 칼날 개폐기 줄 · 아래로 굵은 전선 다발이 바닥으로.
    open = 오른쪽 문짝이 열려 선이 뽑혀 늘어지고 꼬리표(공병반 조사 중)."""
    im = img(64, 60)
    d = ImageDraw.Draw(im)
    _box(d, 2, 4, 31, 52, STEEL[1:])
    _box(d, 32, 4, 61, 52, STEEL[1:])
    for i, x in enumerate((7, 17, 41)):                                                          # 계기
        d.ellipse([x, 8, x + 7, 15], fill=C(INK)); d.ellipse([x + 1, 9, x + 6, 14], fill=C("P09"))
        d.line([x + 3, 12, x + 5 - i, 10], fill=C(RED[1]))
    for x in range(6, 28, 5):                                                                    # 칼날 개폐기
        d.rectangle([x, 22, x + 2, 32], fill=C(INK)); d.line([x + 1, 23, x + 1, 27 if x % 2 else 30], fill=C(STEEL[4]))
    put_text(im, "배전", 6, 36, "P09", 8, "Galmuri7")
    if state == "open":
        d.rectangle([33, 5, 60, 51], fill=C("P02"))
        for i, col in enumerate(("P52", "P44", "P49", "P55")):                                   # 뽑힌 선
            d.line([36 + i * 6, 10, 38 + i * 5, 30 + i * 3], fill=C(col))
            d.line([38 + i * 5, 30 + i * 3, 34 + i * 7, 50], fill=C(col))
        d.rectangle([44, 22, 52, 27], fill=C("P09")); d.line([45, 24, 51, 24], fill=C(INK))        # 꼬리표
        d.polygon([(61, 5), (63, 8), (63, 50), (61, 51)], fill=C(STEEL[3]))                      # 열린 문짝 모서리
    else:
        put_text(im, "B-7", 38, 20, "P09", 8, "Galmuri7")
        d.rectangle([54, 26, 57, 31], fill=C(INK))                                                # 손잡이
    for i, x in enumerate((10, 20, 44)):                                                         # 바닥으로 내려가는 굵은 전선
        d.line([x, 52, x + 2, 57], fill=C(INK), width=2)
    _shadow(d, 3, 61, 58)
    return im


def w_hatch_ug(state=""):
    """벽 점검구(벽 1칸, 32×40): 철 덮개 · 스텐실 'B-7' · 자물쇠 · 옆으로 벽에 박힌 전선 다발.
    open = 덮개가 아래로 젖혀지고 안쪽 어둠에 사다리 가로대."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    for i, col in enumerate(("P52", "P44", "P03")):                                              # 벽 속으로 들어가는 전선
        d.line([0, 8 + i * 2, 5, 8 + i * 2], fill=C(col))
    _box(d, 5, 4, 27, 34, STEEL[1:])
    if state == "open":
        d.rectangle([7, 6, 25, 32], fill=C(INK))
        for y in range(9, 32, 5):
            d.line([10, y, 22, y], fill=C(STEEL[2]))
        d.polygon([(5, 34), (27, 34), (29, 39), (3, 39)], fill=C(STEEL[2]))                       # 젖힌 덮개
        d.line([3, 39, 29, 39], fill=C(INK))
        return im
    put_text(im, "B-7", 9, 8, "P09", 8, "Galmuri7")
    d.line([8, 19, 24, 19], fill=C(STEEL[0]))
    d.rectangle([13, 23, 19, 30], fill=C(INK)); d.rectangle([14, 24, 18, 29], fill=C("P59"))      # 자물쇠
    d.arc([13, 19, 19, 26], 180, 360, fill=C(STEEL[4]))
    return im


def door_shelter():
    """대피소 판독기 문(2×1, 64×64): 두꺼운 미닫이 철문 한 짝(노랑 검정 테두리) · 붉은 판독기 · 문틈(오른쪽 끝)에 낀 해골 팔과 카드 한 장."""
    im = img(64, 64)
    d = ImageDraw.Draw(im)
    _box(d, 1, 2, 62, 8, STEEL[1:])                                                               # 문틀 위
    _box(d, 2, 8, 50, 60, ("P04", "P05", "P06", "P07"))                                          # 문짝
    for y in range(12, 58, 6):
        d.line([4, y, 48, y], fill=C(STEEL[1]))
    for x in range(4, 48, 6):                                                                    # 노랑 검정 테두리
        d.polygon([(x, 54), (x + 3, 54), (x + 6, 58), (x + 3, 58)], fill=C("P49"))
    d.rectangle([40, 20, 47, 30], fill=C(INK)); d.rectangle([41, 21, 46, 25], fill=C(RED[1]))      # 판독기
    d.line([42, 28, 45, 28], fill=C(STEEL[4]))
    d.rectangle([51, 8, 53, 60], fill=C(INK))                                                     # 문 끝 고무
    for (x0, y0, x1, y1) in ((54, 30, 61, 33), (58, 33, 61, 40)):                                 # 문틈에 낀 해골 팔
        d.rectangle([x0, y0, x1, y1], fill=C(BONE[1])); d.rectangle([x0, y0, x1, y1], outline=C(INK))
    d.rectangle([56, 40, 62, 44], fill=C("P09")); d.rectangle([56, 40, 62, 44], outline=C(INK))     # 쥔 카드
    d.point((58, 42), fill=C(RED[1]))                                                             # 재산정 도장
    _shadow(d, 3, 62, 62)
    return im


def rail_cart_ug(state=""):
    """운반조 레일 수레(2×1, 64×40): 나무 바닥판 · 쇠바퀴 넷 · 뒤쪽 밀대 · 감긴 밧줄. load = 상자 둘 · 자루 하나를 실음."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    for x in (8, 20, 42, 54):                                                                    # 바퀴
        d.ellipse([x - 4, 28, x + 4, 36], fill=C(INK)); d.ellipse([x - 3, 29, x + 3, 35], fill=C(STEEL[2]))
        d.point((x, 32), fill=C(STEEL[4]))
    _box(d, 2, 20, 61, 29, WOOD + ("P18",))                                                       # 바닥판
    for x in range(10, 60, 10):
        d.line([x, 21, x, 28], fill=C(WOOD[0]))
    d.line([2, 12, 6, 20], fill=C(INK), width=2); d.line([2, 12, 8, 12], fill=C(STEEL[3]), width=2)  # 밀대
    d.arc([46, 14, 58, 22], 180, 360, fill=C("P20"))                                              # 밧줄
    if state == "load":
        _box(d, 12, 6, 28, 20, WOOD + ("P18",)); d.line([12, 13, 28, 13], fill=C(WOOD[0]))
        _box(d, 30, 9, 44, 20, ("P11", "P12", "P13", "P14"))
        d.ellipse([46, 8, 58, 20], fill=C(INK)); d.ellipse([47, 9, 57, 19], fill=C("P20"))         # 자루
        d.line([52, 9, 52, 12], fill=C(INK))
    _shadow(d, 3, 61, 38)
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_U04 = {
    "w_flap_ug": _r(lambda: w_flap_ug(), 3, 0, "wall", dx=0, dy=0),
    "shutter_jm": _r(lambda: shutter_jm(), 2, 1, down=-2),
    "switchboard_ug": _r(lambda: switchboard_ug(), 2, 1, down=-2),
    "w_hatch_ug": _r(lambda: w_hatch_ug(), 1, 0, "wall", dx=0, dy=2),
    "door_shelter": _r(door_shelter, 2, 1, down=-2),
    "rail_cart_ug": _r(lambda: rail_cart_ug(), 2, 1, down=-2),
}
STATES_U04 = {
    "w_flap_ug": {"close": lambda: w_flap_ug("close")},
    "shutter_jm": {"up": lambda: shutter_jm("up"), "weld": lambda: shutter_jm("weld")},
    "switchboard_ug": {"open": lambda: switchboard_ug("open")},
    "w_hatch_ug": {"open": lambda: w_hatch_ug("open")},
    "rail_cart_ug": {"load": lambda: rail_cart_ug("load")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_U04.values()] + [fn() for st in STATES_U04.values() for fn in st.values()]
    cols = 6
    cw, ch = 104, 72
    sheet = Image.new("RGBA", (cols * cw, ((len(ims) + cols - 1) // cols) * ch), (70, 66, 74, 255))
    for i, m in enumerate(ims):
        sheet.alpha_composite(m, ((i % cols) * cw + 4, (i // cols) * ch + 4))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(out)
