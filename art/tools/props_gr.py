"""구로 차량기지 소품(단계 1-D4, 1-D 계획 §10 · SD-09a L-R02-25 · SD-14 CR-205 · SD-16 아이작풍).
  coach_gr        2077 객차 1량(8×2 발): 국방색 · 노란 띠 · 창 줄 · 출입문 둘(양 끝) · 지붕 환기 · 연결 통로 고무 주름
                  상태 open(끝 문 열림 — 들어가는 객차) · mob(창에 '동원 수송 — 제3 예비군 수송 열차' 표지 · 창마다 군모 그림자)
                  · ladder(끝에 지붕 사다리 — 넘어가는 자리) · rust(창이 깨지고 녹이 흘러내린 오래된 객차)
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
OLIVE = ("P28", "P29", "P30", "P31", "P32")     # 국방색(어둠 → 빛)
BAND = ("P47", "P48", "P49")                     # 노란 띠(군 수송 표식)


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def coach_gr(state=""):
    """2077 객차 1량(8×2 발, 260×88): 위에서 내려다본 옆모습 — 둥근 국방색 지붕(환기 돌기 넷) · 몸통 · 노란 띠 · 창 열 · 양 끝 출입문 ·
    끝마다 연결 통로 고무 주름 · 바퀴 그늘(대차 둘). 상태 open = 오른끝 문이 열려 안이 어둡다(들어가는 칸) · mob = 창에 '동원 수송' 표지와
    군모 그림자 · ladder = 왼끝에 지붕 사다리 · rust = 깨진 창 · 녹물 · 띠가 벗겨진 오래된 칸."""
    rnd = random.Random(5101 + len(state))
    W_, H_ = 260, 88
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    body = OLIVE
    d.rounded_rectangle([6, 8, 253, 76], 8, fill=C(INK))
    d.rounded_rectangle([7, 9, 252, 75], 7, fill=C(body[2]))                                 # 몸통
    d.rounded_rectangle([7, 9, 252, 26], 7, fill=C(body[3]))                                 # 지붕(위 빛)
    d.line([14, 10, 246, 10], fill=C(body[4]))
    for x in (36, 92, 148, 204):                                                              # 지붕 환기 돌기
        d.rounded_rectangle([x, 12, x + 16, 20], 3, fill=C(body[1])); d.line([x + 1, 12, x + 15, 12], fill=C(body[3]))
        for xx in range(x + 3, x + 14, 3):
            d.line([xx, 14, xx, 18], fill=C(body[0]))
    d.line([7, 27, 252, 27], fill=C(body[0]))                                                 # 지붕 · 옆판 이음
    band = BAND if state != "rust" else ("P24", "P25", "P26")
    d.rectangle([7, 52, 252, 57], fill=C(band[1])); d.line([7, 52, 252, 52], fill=C(band[2])); d.line([7, 57, 252, 57], fill=C(band[0]))
    for x in (0, 254):                                                                        # 연결 통로 고무 주름(양 끝)
        d.rectangle([x, 30, x + 5, 66], fill=C(INK))
        for y in range(31, 66, 3):
            d.line([x + 1, y, x + 4, y], fill=C("P03"))
    doors = [(14, False), (226, state == "open")]
    for x, open_ in doors:                                                                    # 양 끝 출입문(여닫이)
        d.rectangle([x, 30, x + 18, 73], fill=C(INK))
        if open_:
            d.rectangle([x + 1, 31, x + 17, 72], fill=C("P02"))
            d.rectangle([x + 13, 31, x + 17, 72], fill=C(body[1]))                            # 젖혀진 문짝
            d.line([x + 3, 66, x + 11, 66], fill=C("P04"))                                    # 발판 끝
        else:
            d.rectangle([x + 1, 31, x + 17, 72], fill=C(body[1]))
            d.rectangle([x + 4, 34, x + 14, 46], fill=C("P10")); d.line([x + 5, 35, x + 8, 41], fill=C("P12"))
            d.point((x + 15, 56), fill=C("P08"))                                              # 손잡이
        d.rectangle([x + 2, 73, x + 16, 76], fill=C("P04"))                                   # 발판
    for i, x in enumerate(range(40, 220, 18)):                                                # 창 열
        broken = state == "rust" and i % 3 == 1
        d.rounded_rectangle([x, 32, x + 13, 47], 2, fill=C(INK))
        d.rounded_rectangle([x + 1, 33, x + 12, 46], 2, fill=C("P02" if broken or i % 4 == 2 else "P10"))
        if broken:
            d.line([x + 2, 34, x + 6, 40], fill=C("P12")); d.line([x + 6, 40, x + 4, 45], fill=C("P12"))
        elif i % 4 != 2:
            d.line([x + 2, 34, x + 6, 40], fill=C("P12"))
        if state == "mob" and i % 2 == 0 and not broken:                                      # 군모 그림자(누군가 앉아 있던 자리 — 지금은 모자만)
            d.rectangle([x + 3, 41, x + 10, 43], fill=C(OLIVE[0])); d.line([x + 2, 43, x + 11, 43], fill=C(OLIVE[0]))
    if state == "mob":                                                                        # 창에 붙인 표지
        d.rectangle([96, 58, 168, 72], fill=C(INK)); d.rectangle([97, 59, 167, 71], fill=C("P09"))
        put_text(im, "동원 수송", 104, 60, "P52", 8, "Galmuri7")
        d.line([100, 69, 164, 69], fill=C("P05"))
    else:
        put_text(im, "군용 객차", 104, 59, body[4], 8, "Galmuri7")
    if state == "ladder":                                                                     # 왼끝 지붕 사다리
        for x in (38, 46):
            d.line([x, 12, x, 74], fill=C(INK), width=2); d.line([x, 12, x, 74], fill=C("P06"))
        for y in range(16, 74, 6):
            d.line([38, y, 46, y], fill=C("P07"))
    for x in (34, 62, 188, 216):                                                              # 바퀴 그늘(대차 둘)
        d.rectangle([x, 76, x + 18, 82], fill=C(INK)); d.ellipse([x + 1, 77, x + 7, 83], fill=C("P03")); d.ellipse([x + 11, 77, x + 17, 83], fill=C("P03"))
    if state == "rust":                                                                       # 녹 얼룩(오래 선 칸 — 가장자리가 고르지 않은 얼룩 + 아래로 흐른 녹물)
        ok = (P.rgb(body[1]), P.rgb(body[2]), P.rgb(body[3]))
        for _ in range(8):
            cx, cy = rnd.randint(20, 240), rnd.randint(14, 64)
            for _k in range(70):
                xx, yy = cx + int(rnd.gauss(0, 5)), cy + int(rnd.gauss(0, 2.5))
                if 0 <= xx < W_ and 0 <= yy < H_ and im.getpixel((xx, yy))[3] and im.getpixel((xx, yy))[:3] in ok:
                    im.putpixel((xx, yy), C(rnd.choice(["P25", "P25", "P24", "P26"])))
            for _k in range(3):                                                               # 흘러내린 녹물
                xx, y0 = cx + rnd.randint(-6, 6), cy + 2
                for yy in range(y0, min(74, y0 + rnd.randint(4, 14))):
                    if im.getpixel((xx, yy))[:3] in ok:
                        im.putpixel((xx, yy), C("P24" if yy % 2 else "P25"))
    for x in range(8, 252, 9):                                                                # 리벳 줄(옆판 위 · 아래)
        d.point((x, 29), fill=C(body[0])); d.point((x, 70), fill=C(body[0]))
    for _ in range(140 if state == "rust" else 90):                                           # 때 · 녹 · 먼지(아래로 갈수록)
        x, y = rnd.randint(10, 248), rnd.randint(28, 74)
        if im.getpixel((x, y))[3] and im.getpixel((x, y))[:3] in (P.rgb(body[2]), P.rgb(body[1])):
            im.putpixel((x, y), C(rnd.choice(["P25", "P24", body[1]] if y > 58 else [body[1], body[3]])))
    for x in range(12, 248, 6):                                                               # 아래 끝 녹물 줄
        if rnd.random() < (0.6 if state == "rust" else 0.35):
            d.line([x, 72, x, 72 + rnd.randint(1, 5)], fill=C("P25"))
    _shadow(d, 8, 252, 84)
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_GR = {
    "coach_gr": _r(coach_gr, 8, 2, down=-2),
}
STATES_GR = {
    "coach_gr": {s: (lambda s=s: coach_gr(s)) for s in ("open", "mob", "ladder", "rust")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_GR.values()] + [fn() for st in STATES_GR.values() for fn in st.values()]
    W = max(i.width for i in ims) + 4
    H = sum(i.height + 4 for i in ims)
    sheet = Image.new("RGBA", (W, H), C("P11"))
    y = 2
    for i in ims:
        sheet.alpha_composite(i, (2, y))
        y += i.height + 4
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
