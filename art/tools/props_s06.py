"""시흥 고개 초소 · 지하 탄약고 · 노들섬 남문 · 강가 소품(단계 1-11f SQ-S06 근무자: 공란, SD-04a §4.6 · SD-09a L-R01-30 · SD-09f §11.1 · SD-16 아이작풍).
  oil_lamp        등유 램프(1×1): 탄약 상자 위 유리 갓 램프 · 주황 불꽃 · 그을음 — 호스트가 빛을 그린다(LIGHT_PROPS)
  w_duty_2077     2077 예비군 근무표(벽 소품 2칸): 칸 나뉜 표 · 날짜 줄 · 마지막 칸 '10-24 근무자: (공란)' · 상태 signed(그 아래 연필 '2277 진해원 — 근무 끝')
  rowboat         나룻배(2×1, 덧그림): 나무 배 · 노 둘 · 바닥에 고인 물 · 밧줄
  reeds           갈대 한 무더기(덧그림): 키 큰 줄기 · 이삭 · 바람에 기운 결
  nd_toll         노들섬 남문 통행세 창구(2×1): 철판 부스 · 창구 구멍 · '통행 30캡' · 조합 표식(닻)
  nd_flag         선주 조합 깃발(1×1): 청록 천 · 노란 닻 · 기증 표식 셋
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def oil_lamp():
    """등유 램프(32×40): 탄약 상자 위 · 쇠 받침 · 둥근 유리 갓 · 주황 불꽃(가운데 노랑) · 갓 위 그을음 · 손잡이 고리."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 26, 27, 36], fill=C(INK)); d.rectangle([5, 27, 26, 35], fill=C("P38"))     # 탄약 상자
    d.rectangle([5, 27, 26, 28], fill=C("P39"))
    d.line([5, 31, 26, 31], fill=C("P02"))
    d.rectangle([12, 22, 19, 26], fill=C(INK)); d.rectangle([13, 23, 18, 25], fill=C("P04"))   # 기름통 받침
    d.ellipse([10, 8, 21, 23], fill=C(INK))                                                  # 유리 갓
    d.ellipse([11, 9, 20, 22], fill=C("P59"))
    d.ellipse([13, 12, 18, 20], fill=C("P60"))                                               # 불빛
    d.rectangle([15, 13, 16, 19], fill=C("P50"))                                             # 불꽃 심지
    d.point((14, 11), fill=C("P09"))                                                         # 유리 반사
    d.rectangle([13, 5, 18, 8], fill=C(INK)); d.rectangle([14, 6, 17, 7], fill=C("P02"))     # 갓 뚜껑
    d.arc([12, 0, 19, 7], 180, 360, fill=C(INK))                                              # 고리
    for x in (14, 16):
        d.point((x, 4), fill=C("P02"))                                              # 그을음
    _shadow(d, 4, 28, 37)
    return im


def w_duty_2077(state=""):
    """2077 예비군 근무표(벽 소품 2칸, 64×60): 누런 종이 · 머리줄 · 날짜 칸 셋(손글씨 이름) · 마지막 칸 '10-24 (공란)' 빨간 테 · 압정.
    signed: 빨간 칸 아래 연필 '2277 근무 끝'(진해원이 노들섬에 닿은 뒤)."""
    im = img(64, 60)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 1, 61, 58], fill=C(INK)); d.rectangle([3, 2, 60, 57], fill=C("P22"))
    d.rectangle([3, 2, 60, 11], fill=C("P21"))
    put_text(im, "예비군 근무", 5, 2, "P01")
    rnd = random.Random(24)
    for i in range(3):
        y = 13 + i * 9
        d.line([3, y + 8, 60, y + 8], fill=C("P21"))
        d.line([24, y, 24, y + 8], fill=C("P21"))
        put_text(im, "%d" % (21 + i), 6, y, "P02")
        for x in range(27, 27 + rnd.randint(16, 28), 2):
            d.point((x, y + 4 + (x % 3 == 0)), fill=C("P02"))                               # 이름 손글씨(알아볼 수 없다)
    d.rectangle([3, 39, 60, 48], outline=C("P53"))
    put_text(im, "24", 6, 39, "P53")
    d.line([24, 39, 24, 48], fill=C("P53"))
    put_text(im, "(공란)", 28, 39, "P53")
    if state == "signed":
        put_text(im, "근무 끝", 26, 48, "P02")                                               # 꾹꾹 눌러 쓴 연필
    for x, y in ((4, 3), (59, 3)):
        d.point((x, y), fill=C("P53"))
    return im


def rowboat():
    """나룻배(64×32): 나무 판 배 · 테두리 · 가로 좌판 둘 · 노 둘 · 바닥 고인 물 · 이물 밧줄."""
    im = img(64, 32)
    d = ImageDraw.Draw(im)
    hull = [(4, 12), (58, 10), (62, 16), (56, 25), (8, 26), (2, 18)]
    d.polygon(hull, fill=C(INK))
    d.polygon([(6, 13), (57, 11), (60, 16), (55, 23), (9, 24), (4, 18)], fill=C("P40"))
    d.polygon([(10, 15), (54, 13), (56, 17), (52, 21), (12, 22), (8, 18)], fill=C("P39"))
    for x in (22, 40):
        d.rectangle([x, 13, x + 3, 22], fill=C("P38"))                                       # 좌판
    d.ellipse([28, 17, 36, 21], fill=C("P36"))                                     # 고인 물
    d.line([18, 8, 30, 28], fill=C(INK), width=2); d.line([18, 8, 29, 26], fill=C("P21"))    # 노
    d.line([44, 6, 52, 29], fill=C(INK), width=2); d.line([44, 6, 51, 27], fill=C("P21"))
    d.arc([56, 6, 64, 18], 200, 340, fill=C("P21"))                                           # 밧줄
    return im


def reeds(seed=5):
    """갈대 무더기(32×44): 줄기 열둘 · 바람에 기운 결 · 이삭(누런 털)."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    r = random.Random(seed)
    for i in range(12):
        x = 4 + i * 2 + r.randint(-1, 1)
        lean = r.randint(2, 6)
        top = r.randint(2, 12)
        d.line([x, 42, x + lean, top], fill=C("P30" if i % 3 else "P31"))
        d.ellipse([x + lean - 1, top - 4, x + lean + 2, top + 2], fill=C("P21"))
    return im


def nd_toll():
    """노들섬 남문 통행세 창구(64×52): 철판 부스 · 리벳 · 창구 구멍 · '통행 30캡' 판 · 닻 표식 · 깃발 꽂이."""
    im = img(64, 52)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 8, 59, 46], fill=C(INK)); d.rectangle([5, 9, 58, 45], fill=C("P06"))
    d.rectangle([5, 9, 58, 12], fill=C("P07"))
    for x in range(8, 58, 8):
        for y in (14, 42):
            d.point((x, y), fill=C("P08"))
    d.rectangle([20, 18, 43, 30], fill=C(INK)); d.rectangle([21, 19, 42, 29], fill=C("P02"))   # 창구
    d.rectangle([21, 29, 42, 31], fill=C("P21"))
    d.rectangle([8, 34, 30, 41], fill=C("P22")); put_text(im, "통행 30", 9, 34, "P01")
    ax, ay = 46, 36                                                                          # 닻
    d.line([ax, ay - 4, ax, ay + 4], fill=C("P57"), width=2)
    d.arc([ax - 4, ay, ax + 4, ay + 6], 0, 180, fill=C("P57"))
    d.line([ax - 2, ay - 3, ax + 2, ay - 3], fill=C("P57"))
    d.line([56, 0, 56, 9], fill=C(INK), width=2)                                              # 깃대
    d.polygon([(57, 0), (63, 2), (57, 5)], fill=C("P56"))
    _shadow(d, 4, 60, 47)
    return im


def nd_flag():
    """노들섬 선주 조합 깃발(32×66, 1×1): 무거운 받침 · 쇠 깃대 · 바람에 펄럭이는 짙은 청록 천 · 노란 닻 문양 ·
    천 아래쪽 기증 표식 줄(봉천 계단 · 탱크마을 기름띠 · 선유도 물방울) · 해진 끝단."""
    im = img(32, 66)
    d = ImageDraw.Draw(im)
    d.ellipse([5, 58, 27, 65], fill=C("P02"))                                                 # 받침 그림자
    d.rectangle([10, 55, 20, 61], fill=C(INK)); d.rectangle([11, 56, 19, 60], fill=C("P04"))  # 콘크리트 받침
    d.line([11, 56, 19, 56], fill=C("P06"))
    d.line([14, 3, 14, 56], fill=C(INK), width=2); d.line([15, 3, 15, 56], fill=C("P05"))     # 깃대
    d.ellipse([12, 0, 17, 4], fill=C("P48")); d.point((13, 1), fill=C("P50"))
    flag = [(16, 6), (24, 5), (31, 8), (30, 15), (31, 23), (24, 22), (16, 24)]               # 펄럭이는 천(오른쪽으로)
    d.polygon(flag, fill=C(INK))
    d.polygon([(17, 7), (24, 6), (30, 9), (29, 15), (30, 22), (24, 21), (17, 23)], fill=C("P35"))
    d.line([24, 7, 24, 20], fill=C("P34"))                                                    # 천 접힌 그늘
    ax, ay = 22, 12                                                                           # 닻
    d.line([ax, ay - 3, ax, ay + 5], fill=C("P49"))
    d.line([ax - 2, ay - 2, ax + 2, ay - 2], fill=C("P49"))
    d.arc([ax - 4, ay + 1, ax + 4, ay + 7], 0, 180, fill=C("P49"))
    d.point((ax, ay - 4), fill=C("P49"))
    for i, col in enumerate(("P07", "P01", "P46")):                                           # 기증 표식: 계단(회색) · 기름띠(검정) · 물방울(파랑)
        x = 18 + i * 4
        d.rectangle([x, 18, x + 2, 20], fill=C(col))
    for x in (27, 29):                                                                        # 해진 끝단
        d.point((x, 22), fill=C(INK))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_S06 = {
    "oil_lamp": _r(oil_lamp, 1, 1, down=-2),
    "w_duty_2077": _r(w_duty_2077, 2, 0, "wall", dx=0, dy=0),
    "rowboat": _r(rowboat, 0, 0, "deco"),
    "reeds": _r(lambda: reeds(5), 0, 0, "deco"),
    "reeds2": _r(lambda: reeds(11), 0, 0, "deco"),
    "nd_toll": _r(nd_toll, 2, 1, down=-2),
    "nd_flag": _r(nd_flag, 1, 1),
}

STATES_S06 = {
    "w_duty_2077": {"signed": lambda: w_duty_2077("signed")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_s06.png"
    ims = [v["fn"]() for v in PROPS_S06.values()] + [f() for st in STATES_S06.values() for f in st.values()]
    W = sum(i.width for i in ims) + 6 * len(ims)
    Hh = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, Hh + 4), C("P04"))
    x = 2
    for i in ims:
        sheet.alpha_composite(i, (x, 2))
        x += i.width + 6
    sheet = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
    sheet.save(out)
    print(out)
