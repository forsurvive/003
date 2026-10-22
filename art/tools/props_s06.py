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
    """나룻배(72×40, 덧그림): 나무 판자 배 — 겹판 결 · 테두리 먹선 · 가로 좌판 둘 · 노 둘(노걸이) · 바닥에 고인 물과 물때 · 이물 밧줄 사리 · 고물 번호판 ·
    들린 이물 밑 접지 그림자(타원 아님)."""
    im = img(72, 40)
    d = ImageDraw.Draw(im)
    hull = [(4, 14), (64, 10), (70, 18), (64, 30), (10, 33), (2, 22)]
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0)); ImageDraw.Draw(sh).polygon([(x + 2, y + 3) for x, y in hull], fill=C("P02")); im.alpha_composite(sh)
    d.polygon(hull, fill=C(INK))
    d.polygon([(6, 15), (63, 11), (68, 18), (63, 29), (11, 32), (4, 22)], fill=C("P40"))
    for k, y in enumerate((18, 23, 28)):                                      # 겹판 이음(바깥 판자)
        d.line([(8, y + k), (62, y - 2 + k)], fill=C("P38"))
    d.polygon([(11, 17), (60, 13), (64, 18), (60, 26), (13, 29), (9, 22)], fill=C("P39"))   # 안쪽 바닥
    d.polygon([(13, 18), (58, 14), (62, 18), (58, 25), (15, 28), (11, 22)], fill=C("P38"))
    for x in range(16, 58, 5):                                                # 바닥 널
        d.line([x, 15, x - 1, 28], fill=C("P37"))
    d.ellipse([30, 19, 44, 26], fill=C("P36")); d.ellipse([33, 21, 41, 24], fill=C("P35")); d.point((36, 22), fill=C("P37"))   # 고인 물 · 반사
    for x in (24, 46):                                                        # 가로 좌판
        d.rectangle([x, 14, x + 4, 28], fill=C(INK)); d.rectangle([x + 1, 15, x + 3, 27], fill=C("P41")); d.line([x + 1, 15, x + 3, 15], fill=C("P42"))
    for x in (20, 52):                                                        # 노걸이
        d.rectangle([x, 12, x + 2, 15], fill=C("P05"))
    d.line([20, 6, 32, 36], fill=C(INK), width=3); d.line([21, 6, 32, 35], fill=C("P21")); d.polygon([(31, 34), (36, 38), (34, 40), (29, 36)], fill=C("P20"))   # 노 둘
    d.line([52, 4, 60, 37], fill=C(INK), width=3); d.line([53, 4, 60, 36], fill=C("P21")); d.polygon([(59, 35), (64, 38), (62, 40), (57, 37)], fill=C("P20"))
    d.ellipse([5, 17, 13, 23], fill=C("P21")); d.ellipse([7, 18, 11, 21], fill=C("P39")); d.arc([5, 17, 13, 23], 0, 360, fill=C("P18"))   # 이물 밧줄 사리
    d.line([(9, 17), (2, 10)], fill=C("P21"))
    d.rectangle([62, 20, 67, 25], fill=C("P09")); d.line([64, 21, 64, 24], fill=C(INK)); d.point((65, 22), fill=C(INK))   # 고물 번호판
    for (x, y) in ((16, 27), (50, 26), (40, 16)):                             # 물때
        d.point((x, y), fill=C("P30")); d.point((x + 1, y), fill=C("P31"))
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
