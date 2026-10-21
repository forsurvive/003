"""고속터미널 지하상가 소품(단계 1-12d FQ-JH-02 「2077년 외상 장부」, SD-09f L-UG-39 · 아이작풍 SD-16).
꽃상가 자리의 수경 화단(원자 전지 조명 — 앵커) · 2077-10-23 '결혼식 화환 예약 접수' 꼬리표 진열대 · 매표소 창구와 전광판 '부산 23:50 매진' ·
2077 고속버스 시간표('영등포행 막차' — JH-02 호위 장면) · 구두 수선 좌판(탁만수).
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다.
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


# ================================================================================================ 수경 화단(2×1)
def hydro_bed(state="lit", seed=5):
    """수경 화단(64×52): 흰 플라스틱 수조 두 줄 · 잎 · 2077 결혼식 품종 꽃(빨강 · 흰 · 노랑) · 위에 원자 전지 조명 막대.
    dark = 조명이 꺼져 잎이 처졌다(세이프빌이 전기를 끊은 날 — UG-H10)."""
    rnd = random.Random(seed)
    im = img(64, 52)
    d = ImageDraw.Draw(im)
    lit = state == "lit"
    d.line([6, 2, 6, 14], fill=C("P06")); d.line([58, 2, 58, 14], fill=C("P06"))          # 조명 걸이
    d.rectangle([4, 0, 60, 4], fill=C("P05")); d.rectangle([6, 1, 58, 3], fill=C("P63" if lit else "P04"))
    if lit:
        for x in range(8, 58, 6):
            d.point((x, 5), fill=C("P62"))
    for row, y0 in enumerate((20, 34)):                                   # 수조 두 줄
        d.rectangle([2, y0 + 8, 61, y0 + 15], fill=C("P08")); d.line([2, y0 + 8, 61, y0 + 8], fill=C("P09"))
        d.line([2, y0 + 15, 61, y0 + 15], fill=C(INK))
        d.rectangle([4, y0 + 10, 59, y0 + 12], fill=C("P36"))            # 물
        for k in range(9):
            x = 6 + k * 6 + rnd.randint(-1, 1)
            h = rnd.randint(5, 9) if lit else rnd.randint(2, 4)
            d.line([x, y0 + 8, x - 1, y0 + 8 - h], fill=C("P30" if lit else "P29"))
            d.line([x, y0 + 8, x + 2, y0 + 9 - h], fill=C("P31" if lit else "P29"))
            if lit and rnd.random() < 0.7:
                col = rnd.choice(["P53", "P09", "P49", "P54"])
                d.rectangle([x - 1, y0 + 7 - h, x + 1, y0 + 9 - h], fill=C(col))
                d.point((x, y0 + 8 - h), fill=C("P50"))
    return im


# ================================================================================================ 화환 진열대(2×1)
def wreath_rack():
    """꽃상가 진열대(64×50): 쇠 진열대에 마른 화환 둘 · 리본 · 꼬리표 '2077. 10. 23 결혼식 화환 예약 접수'."""
    im = img(64, 50)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 38, 61, 42], fill=C("P06")); d.line([2, 38, 61, 38], fill=C("P08"))
    for x in (4, 58):
        d.line([x, 42, x, 49], fill=C("P05"))
    for cx in (18, 44):                                                   # 마른 화환(둥근 테)
        d.ellipse([cx - 13, 8, cx + 13, 34], outline=C("P19"), width=4)
        for a in range(0, 360, 30):
            import math
            t = math.radians(a)
            d.point((cx + math.cos(t) * 11, 21 + math.sin(t) * 11), fill=C(["P20", "P41", "P18"][a // 30 % 3]))
        d.line([cx - 2, 32, cx - 5, 40], fill=C("P09")); d.line([cx + 2, 32, cx + 5, 40], fill=C("P09"))   # 바랜 리본
    d.rectangle([24, 30, 40, 36], fill=C("P21")); d.line([24, 30, 40, 30], fill=C("P22"))   # 꼬리표
    d.line([32, 26, 32, 30], fill=C("P05"))
    put_text(im, "예약", 25, 29, "P02", size=8)
    return im


# ================================================================================================ 매표소 창구(벽 3칸)
def w_ticket_booth():
    """매표소(벽 96×62): 유리 창구 셋 · 말하는 구멍 · 위 전광판 주황 글씨 '부산 23:50 매진'(SD-09f 환경 ②)."""
    im = img(96, 62)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 61], fill=C("P12"))
    d.rectangle([2, 2, 93, 13], fill=C(INK))                              # 전광판
    put_text(im, "부산23:50 매진", 2, 2, "P59", size=8)
    for i in range(3):
        x0 = 4 + i * 31
        d.rectangle([x0, 18, x0 + 27, 46], fill=C("P13")); d.rectangle([x0, 18, x0 + 27, 46], outline=C("P11"))
        d.rectangle([x0 + 2, 20, x0 + 25, 40], fill=C("P15" if i != 1 else "P14"))   # 유리(가운데만 불 켜짐)
        d.line([x0 + 4, 22, x0 + 10, 28], fill=C("P09"))
        d.ellipse([x0 + 11, 32, x0 + 16, 36], outline=C("P11"))             # 말하는 구멍
        d.rectangle([x0 + 6, 41, x0 + 21, 45], fill=C(INK))                 # 표 나오는 틈
        put_text(im, str(i + 1), x0 + 11, 47, "P09", size=8)
    d.rectangle([0, 56, 95, 61], fill=C("P11")); d.line([0, 56, 95, 56], fill=C("P13"))
    return im


# ================================================================================================ 2077 시간표(벽 2칸)
def w_timetable():
    """2077 고속버스 시간표(벽 64×62): 행선지 · 시각 줄 · 맨 아래 '영등포 23:40 막차'만 손때가 묻었다."""
    im = img(64, 62)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 61], fill=C("P03"))
    d.rectangle([2, 2, 61, 59], fill=C("P44")); d.rectangle([2, 2, 61, 9], fill=C("P45"))
    put_text(im, "출발 시각", 12, 1, "P09", size=8)
    rows = [("부산", "23:50"), ("광주", "23:10"), ("대전", "22:40"), ("영등포", "23:40")]
    for i, (a, b) in enumerate(rows):
        y = 13 + i * 11
        d.line([4, y + 9, 59, y + 9], fill=C("P43"))
        put_text(im, a, 5, y, "P09" if i < 3 else "P50", size=8)
        put_text(im, b, 36, y, "P09" if i < 3 else "P50", size=8)
    d.rectangle([3, 46, 60, 55], outline=C("P41"))                         # 손때(누가 자꾸 짚은 줄)
    return im


# ================================================================================================ 구두 수선 좌판(2×1)
def shoe_stall():
    """구두 수선 좌판(64×46): 낮은 나무 좌판 · 쇠 구두골 · 고친 구두 셋 · 망치 · 구두약 깡통 · 작은 접이의자 · '구두 수선 · 굽 갈이'."""
    im = img(64, 46)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 22, 61, 30], fill=C("P18")); d.line([2, 22, 61, 22], fill=C("P20")); d.line([2, 30, 61, 30], fill=C(INK))
    for x in (5, 57):
        d.line([x, 30, x, 40], fill=C("P17"))
    d.line([14, 22, 14, 12], fill=C("P06")); d.polygon([(8, 12), (20, 12), (18, 8), (10, 8)], fill=C("P07"))   # 구두골
    for i, x in enumerate((26, 36, 46)):                                  # 고친 구두
        d.polygon([(x, 21), (x + 8, 21), (x + 8, 17), (x + 3, 15), (x, 16)], fill=C(["P02", "P17", "P39"][i]))
        d.line([x, 21, x + 8, 21], fill=C(INK)); d.point((x + 6, 17), fill=C("P08"))
    d.line([52, 18, 58, 14], fill=C("P17")); d.rectangle([56, 12, 60, 15], fill=C("P06"))   # 망치
    d.ellipse([4, 17, 10, 21], fill=C("P48")); d.ellipse([5, 17, 9, 19], fill=C("P02"))    # 구두약 깡통
    d.rectangle([22, 36, 34, 39], fill=C("P05")); d.line([24, 39, 22, 45], fill=C("P05")); d.line([32, 39, 34, 45], fill=C("P05"))   # 의자
    d.rectangle([34, 1, 63, 11], fill=C("P21")); d.rectangle([34, 1, 63, 11], outline=C("P17"))
    put_text(im, "구두수선", 35, 1, "P02", size=8)
    return im


# ================================================================================================ 침상 칸(1×2)
def rent_cot():
    """침상 칸(32×60, 세로): 쇠파이프 간이침대 · 회색 담요 · 꽃 이름 꼬리표(번호 대신 — 안개꽃 · 백합 · 수국)."""
    im = img(32, 60)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 8, 28, 56], fill=C("P06")); d.rectangle([3, 8, 28, 56], outline=C("P04"))
    d.rectangle([5, 10, 26, 18], fill=C("P09")); d.line([5, 18, 26, 18], fill=C("P07"))        # 베개
    d.rectangle([5, 20, 26, 54], fill=C("P12")); d.line([5, 30, 26, 30], fill=C("P13"))        # 담요
    for x in (3, 28):
        d.line([x, 56, x, 59], fill=C("P05"))
    d.rectangle([20, 2, 30, 8], fill=C("P09")); d.point((25, 5), fill=C("P53"))               # 꽃 꼬리표
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_GT = {
    "gt_hydro_bed": _r(hydro_bed, 2, 1, down=-2),
    "gt_wreath_rack": _r(wreath_rack, 2, 1, down=-2),
    "w_ticket_booth": _r(w_ticket_booth, 3, 0, "wall", dx=0, dy=2),
    "w_timetable": _r(w_timetable, 2, 0, "wall", dx=0, dy=2),
    "gt_shoe_stall": _r(shoe_stall, 2, 1, down=-2),
    "gt_rent_cot": _r(rent_cot, 1, 2, down=-2),
}

STATES_GT = {
    "gt_hydro_bed": {"dark": lambda: hydro_bed("dark")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_gt.png"
    ims = [v["fn"]() for v in PROPS_GT.values()] + [f() for st in STATES_GT.values() for f in st.values()]
    W = sum(i.width for i in ims) + 6 * len(ims)
    H = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, H), (70, 72, 78, 255))
    x = 0
    for i in ims:
        sheet.alpha_composite(i, (x, H - i.height))
        x += i.width + 6
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
