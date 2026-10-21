"""R02 비표시 퀘스트 소품(단계 1-12h — UQ-07 견습생의 첫 납땜 · UQ-10 저울추, SD-05 §3.4 · SD-16 아이작풍).
  toy_robot   태엽 배송 로봇(1×1, 덧그림) — 태엽 장난감 자동차를 고친 짐칸 로봇. 기본 = 고장(옆으로 누움 · 바퀴 하나 빠짐 · 등판 진공관 자리 셋이 빔)
              상태 fixed(바로 섬 · 진공관 셋 주황 빛 · 짐칸에 끈 묶은 꾸러미 · 태엽 열쇠)
  scale_beam  시장 반장 추 저울(2×1) — 나무 받침 · 쇠 저울대 · 왼쪽 고철 접시(자릿세 고철) · 오른쪽 추 접시와 추 셋.
              기본 = 추 쪽 받침에 쇠판을 덧댐(접시 밑 검은 판 · 저울대가 고철 쪽으로 덜 기움) · 상태 fixed(쇠판 떼어 냄 · 새 눈금 딱지)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from props_bc_in import box3, WOOD

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def _wheel(d, x, y):
    d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=C(INK))
    d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=C("P04"))
    d.point((x, y), fill=C("P07"))


def toy_robot(state=""):
    """태엽 배송 로봇(28×22): 양철 몸통(청록 칠이 벗겨짐) · 앞 전조등 하나 · 등판 진공관 자리 셋 · 뒤 짐칸.
    기본 = 고장 — 옆으로 누워 바퀴 하나가 빠져 굴러가 있고 등판 관 자리 셋이 비었다 · fixed = 바로 서서 관 셋이 주황으로 빛나고 짐칸에 꾸러미 · 태엽 열쇠."""
    im = img(28, 22)
    d = ImageDraw.Draw(im)
    if state == "fixed":
        _shadow(d, 3, 25, 20)
        d.rounded_rectangle([3, 6, 24, 16], 2, fill=C(INK))                    # 몸통
        d.rounded_rectangle([4, 7, 23, 15], 2, fill=C("P36"))
        d.line([5, 7, 22, 7], fill=C("P38"))
        for x in (8, 15):                                                    # 칠 벗겨진 자리
            d.point((x, 12), fill=C("P06")); d.point((x + 1, 12), fill=C("P06"))
        d.rectangle([4, 9, 6, 11], fill=C("P09"))                             # 전조등
        d.point((5, 10), fill=C("P10"))
        for i, x in enumerate((9, 12, 15)):                                 # 등판 진공관 셋(주황)
            d.rectangle([x, 3, x + 2, 7], fill=C(INK))
            d.rectangle([x + 1, 4, x + 1, 6], fill=C("P27" if i != 1 else "P28"))
        d.rectangle([17, 3, 24, 7], fill=C(INK))                             # 짐칸 꾸러미
        d.rectangle([18, 4, 23, 6], fill=C("P22"))
        d.line([20, 3, 20, 7], fill=C("P24")); d.line([17, 5, 24, 5], fill=C("P24"))
        d.line([25, 10, 27, 10], fill=C("P06")); d.rectangle([26, 8, 27, 12], fill=C("P07"))   # 태엽 열쇠
        _wheel(d, 7, 17); _wheel(d, 20, 17)
    else:
        _shadow(d, 2, 22, 20)
        d.polygon([(4, 18), (6, 9), (17, 6), (19, 15)], fill=C(INK))         # 옆으로 누운 몸통
        d.polygon([(5, 17), (7, 10), (16, 7), (18, 14)], fill=C("P34"))
        d.line([7, 10, 16, 7], fill=C("P36"))
        for (x, y) in ((8, 13), (11, 12), (14, 11)):                          # 빈 관 자리 셋(검은 구멍)
            d.rectangle([x, y, x + 1, y + 1], fill=C(INK))
        _wheel(d, 7, 18)
        d.line([18, 14, 20, 17], fill=C("P05"))                              # 빠진 바퀴 축
        _wheel(d, 24, 17)                                                    # 굴러간 바퀴
        d.point((13, 4), fill=C("P06")); d.point((14, 3), fill=C("P06"))     # 떨어진 나사
    return im


def scale_beam(state=""):
    """시장 반장 추 저울(60×44): 나무 받침대 · 가운데 기둥 · 쇠 저울대 · 왼쪽 고철 접시(볼트 · 철근 토막) · 오른쪽 추 접시(추 셋).
    기본 = 추 접시 받침 밑에 검은 쇠판 한 장(덧댐 — 고철을 더 올려야 균형) · 저울대가 덜 기움 · fixed = 쇠판 없음 · 기둥에 새 눈금 딱지."""
    im = img(60, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 58, 41)
    box3(d, 2, 30, 57, 40, 4, WOOD)                                         # 받침대
    d.rectangle([27, 8, 32, 31], fill=C(INK)); d.rectangle([28, 9, 31, 30], fill=C("P05"))   # 기둥
    d.line([29, 9, 29, 30], fill=C("P07"))
    tilt = 0 if state == "fixed" else 2                                     # 덧댄 판 때문에 덜 기움
    d.line([8, 9 + tilt, 51, 9 - tilt], fill=C(INK), width=3)               # 저울대
    d.line([8, 8 + tilt, 51, 8 - tilt], fill=C("P07"))
    d.ellipse([27, 6, 32, 11], fill=C("P27"))                               # 받침점
    # 왼쪽 고철 접시
    lx, ly = 10, 22 + tilt
    d.line([lx, 10 + tilt, lx - 4, ly], fill=C("P05")); d.line([lx, 10 + tilt, lx + 4, ly], fill=C("P05"))
    d.ellipse([lx - 8, ly - 1, lx + 8, ly + 4], fill=C(INK)); d.ellipse([lx - 7, ly, lx + 7, ly + 3], fill=C("P06"))
    for (x, y, c) in ((lx - 4, ly - 2, "P05"), (lx, ly - 3, "P26"), (lx + 3, ly - 2, "P04")):   # 볼트 · 녹 철근
        d.rectangle([x, y, x + 2, y + 1], fill=C(c))
    # 오른쪽 추 접시
    rx, ry = 49, 22 - tilt
    d.line([rx, 10 - tilt, rx - 4, ry], fill=C("P05")); d.line([rx, 10 - tilt, rx + 4, ry], fill=C("P05"))
    d.ellipse([rx - 8, ry - 1, rx + 8, ry + 4], fill=C(INK)); d.ellipse([rx - 7, ry, rx + 7, ry + 3], fill=C("P06"))
    for k, x in enumerate((rx - 5, rx - 1, rx + 3)):                         # 추 셋
        h = 4 - k
        d.rectangle([x, ry - h, x + 2, ry], fill=C(INK)); d.rectangle([x + 1, ry - h + 1, x + 1, ry - 1], fill=C("P04"))
    if state == "fixed":
        d.rectangle([30, 18, 36, 22], fill=C("P09")); d.line([31, 20, 35, 20], fill=C("P05"))   # 새 눈금 딱지
    else:
        d.rectangle([rx - 9, ry + 4, rx + 9, ry + 6], fill=C(INK))         # 덧댄 쇠판(접시 받침 밑)
        d.line([rx - 8, ry + 5, rx + 8, ry + 5], fill=C("P03"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_UQ2 = {
    "toy_robot": _r(toy_robot, 0, 0, "deco"),
    "scale_beam": _r(scale_beam, 2, 1),
}
STATES_UQ2 = {
    "toy_robot": {"fixed": lambda: toy_robot("fixed")},
    "scale_beam": {"fixed": lambda: scale_beam("fixed")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_uq2.png"
    tiles = [(n, s) for n in PROPS_UQ2 for s in [""] + list(STATES_UQ2.get(n, {}))]
    W = 70 * len(tiles)
    sheet = Image.new("RGBA", (W, 60), (60, 56, 52, 255))
    for i, (n, s) in enumerate(tiles):
        p = PROPS_UQ2[n]["fn"](s) if s else PROPS_UQ2[n]["fn"]()
        sheet.alpha_composite(p, (i * 70 + 4, 6))
    sheet.resize((W * 4, 240), Image.NEAREST).save(out)
    print(out)
