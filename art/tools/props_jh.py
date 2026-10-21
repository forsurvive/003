"""지하시장 B구역 소품(단계 1-12c FQ-JH-01 「B구역 셔터」, SD-04d §8.3 · SD-09a L-R02-11 J-08 · 아이작풍 SD-16).
계획 `docs/seoul-fallout/_plans/1-12c_FQ-JH-01-03_plan.md`: 무너진 셔터 너머 점포 12칸 · 쥐굴 입구 셋(열림 · 철판 · 독 미끼 · 조용) ·
셔터 구동부(기어 빠짐 · 고침 · 내림) · 안쪽 방화 셔터(틀 · 내림) · 다시 연 점포(사공 수선 · 빈 칸) · 상인회 비상 배수 통로.
쥐굴마다 생김새가 다르다(굴 A 무너진 점포 벽 밑 · 굴 B 바닥 균열 · 굴 C 깨진 배수구 — 왕쥐 둥지).
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다.
"""
import os, sys, random, math
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text
from props_jm import shutter, SHOP_PAINT

C = lambda t: P.rgb(t) + (255,)
INK = "P01"

SHOP_PAINT["sagong"] = ("P44", "P09", "사공 수선")
SHOP_PAINT["bshop"] = ("P29", "P08", "")


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


# ================================================================================================ 쥐굴 입구(바닥 2×1)
def _droppings(d, rnd, n, box):
    x0, y0, x1, y1 = box
    for _ in range(n):
        x = rnd.randint(x0, x1)
        y = rnd.randint(y0, y1)
        d.line([x, y, x + 1, y], fill=C("P17"))


def _plate(d, cx, cy, w, h, seed):
    """덧댄 철판: 녹 · 모서리 볼트 · 가장자리 용접 대신 철사 감기(수리 25 수준의 손질)."""
    rnd = random.Random(seed)
    d.polygon([(cx - w, cy - h + 2), (cx + w - 2, cy - h), (cx + w, cy + h - 1), (cx - w + 1, cy + h)], fill=C("P12"))
    d.line([(cx - w, cy - h + 2), (cx + w - 2, cy - h)], fill=C("P14"))
    d.line([(cx - w + 1, cy + h), (cx + w, cy + h - 1)], fill=C(INK))
    for _ in range(9):                                                     # 녹 반점
        x = rnd.randint(cx - w + 2, cx + w - 3)
        y = rnd.randint(cy - h + 3, cy + h - 2)
        d.point((x, y), fill=C(rnd.choice(["P25", "P26", "P11"])))
    for bx, by in ((cx - w + 3, cy - h + 4), (cx + w - 4, cy - h + 3), (cx - w + 3, cy + h - 2), (cx + w - 3, cy + h - 3)):
        d.ellipse([bx - 1, by - 1, bx + 1, by + 1], fill=C("P08"))
    d.line([(cx - 3, cy - h + 1), (cx + 4, cy + h - 1)], fill=C("P11"))   # 접힌 골


def _bait(d, cx, cy):
    """독 미끼: 깡통 뚜껑 접시 + 노란 말벌 독낭 덩이 + 분필 해골 표(상인회가 알아보게)."""
    d.ellipse([cx - 6, cy - 2, cx + 6, cy + 3], fill=C("P07")); d.ellipse([cx - 6, cy - 2, cx + 6, cy + 2], outline=C("P05"))
    d.ellipse([cx - 3, cy - 3, cx + 3, cy + 1], fill=C("P49")); d.point((cx - 1, cy - 2), fill=C("P50"))
    d.ellipse([cx + 9, cy - 9, cx + 15, cy - 4], outline=C("P09"))       # 분필 해골
    d.point((cx + 11, cy - 7), fill=C("P09")); d.point((cx + 13, cy - 7), fill=C("P09"))
    d.line([cx + 10, cy - 3, cx + 14, cy - 3], fill=C("P09"))


def _dead_rats(d, cx, cy, n):
    for i in range(n):
        x = cx - 10 + i * 9
        y = cy + (i % 2) * 3
        d.ellipse([x, y, x + 7, y + 3], fill=C("P05")); d.point((x + 7, y + 1), fill=C("P41"))
        d.line([x - 3, y + 2, x, y + 2], fill=C("P41"))                  # 꼬리
        d.point((x + 5, y + 1), fill=C(INK))


def burrow_a(state="open"):
    """굴 A — 무너진 점포 벽 밑(64×40): 깨진 벽돌 · 반달 굴 · 갉은 상호 띠 조각 · 똥 · 털."""
    rnd = random.Random(11)
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    for i in range(7):                                                     # 깨진 벽돌 무더기
        x = 4 + i * 8 + rnd.randint(-1, 1)
        y = 6 + rnd.randint(0, 6)
        d.rectangle([x, y, x + 9, y + 5], fill=C(rnd.choice(["P24", "P25", "P05"])))
        d.line([x, y, x + 9, y], fill=C("P26"))
    d.rectangle([2, 14, 61, 20], fill=C("P04"))
    d.rectangle([40, 9, 58, 13], fill=C("P45")); put_text(im, "B-0", 42, 8, "P09", size=8)   # 떨어진 상호 띠
    cx, cy = 26, 26
    if state == "plated":
        d.pieslice([cx - 14, cy - 12, cx + 14, cy + 14], 180, 360, fill=C(INK))
        _plate(d, cx, cy - 2, 15, 9, 3)
    else:
        d.pieslice([cx - 14, cy - 12, cx + 14, cy + 14], 180, 360, fill=C(INK))
        d.pieslice([cx - 11, cy - 9, cx + 11, cy + 11], 180, 360, fill=C("P01"))
        for a in range(195, 345, 18):
            t = math.radians(a)
            d.point((cx + math.cos(t) * 13, cy + 1 + math.sin(t) * 13), fill=C("P06"))
        if state == "open":
            d.point((cx - 3, cy - 3), fill=C("P53")); d.point((cx + 1, cy - 3), fill=C("P53"))   # 안에서 빛나는 눈
        if state == "bait":
            _bait(d, cx + 18, cy + 6)
        if state == "dead":
            _dead_rats(d, cx + 4, cy + 3, 3)
    _droppings(d, rnd, 8 if state == "open" else 3, (6, 28, 58, 36))
    return im


def burrow_b(state="open"):
    """굴 B — 바닥 균열(64×40): 갈라진 타일 · 꺼진 구덩이 · 흙 밀어낸 자국(굴쥐가 판다)."""
    rnd = random.Random(23)
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    for i in range(5):                                                     # 들뜬 바닥 타일 조각
        x = 6 + i * 11
        d.polygon([(x, 8 + i % 2 * 3), (x + 9, 7), (x + 10, 13), (x + 1, 14)], fill=C(rnd.choice(["P07", "P06"])))
        d.line([(x, 8 + i % 2 * 3), (x + 9, 7)], fill=C("P08"))
    cx, cy = 32, 24
    d.ellipse([cx - 22, cy - 9, cx + 22, cy + 11], fill=C("P18"))            # 밀어낸 흙
    for _ in range(14):
        x = rnd.randint(cx - 20, cx + 20)
        d.point((x, rnd.randint(cy - 8, cy + 10)), fill=C(rnd.choice(["P17", "P19"])))
    d.ellipse([cx - 13, cy - 6, cx + 13, cy + 7], fill=C(INK))
    if state == "plated":
        _plate(d, cx, cy, 16, 8, 5)
    else:
        d.ellipse([cx - 10, cy - 4, cx + 10, cy + 5], fill=C("P01"))
        for k in range(4):                                                 # 균열이 사방으로
            a = math.radians(20 + k * 95)
            d.line([cx + math.cos(a) * 12, cy + math.sin(a) * 6, cx + math.cos(a) * 24, cy + math.sin(a) * 12], fill=C(INK))
        if state == "open":
            d.point((cx + 2, cy - 1), fill=C("P53")); d.point((cx + 5, cy - 1), fill=C("P53"))
        if state == "bait":
            _bait(d, cx - 18, cy + 8)
        if state == "dead":
            _dead_rats(d, cx - 4, cy + 6, 2)
    return im


def burrow_c(state="open"):
    """굴 C — 깨진 배수구(64×44, 왕쥐 둥지): 뜯긴 배수 덮개 · 넓은 구멍 · 둥지 지푸라기 · 뼈 · 2077 상가 영수증 뭉치."""
    rnd = random.Random(37)
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([44, 6, 62, 12], fill=C("P11"))                            # 뜯겨 나간 배수 덮개
    for x in range(46, 61, 3):
        d.line([x, 6, x, 12], fill=C("P02"))
    cx, cy = 28, 26
    d.ellipse([cx - 24, cy - 12, cx + 24, cy + 14], fill=C("P20"))         # 둥지 지푸라기 · 종이
    for _ in range(30):
        x = rnd.randint(cx - 22, cx + 22)
        y = rnd.randint(cy - 10, cy + 12)
        d.line([x, y, x + rnd.randint(-3, 3), y + rnd.randint(-2, 2)], fill=C(rnd.choice(["P19", "P21", "P09", "P17"])))
    d.rectangle([cx + 12, cy + 6, cx + 20, cy + 11], fill=C("P09")); d.line([cx + 13, cy + 8, cx + 19, cy + 8], fill=C("P05"))  # 영수증
    d.line([cx - 22, cy + 8, cx - 14, cy + 11], fill=C("P08"))             # 뼈
    d.ellipse([cx - 15, cy - 8, cx + 15, cy + 9], fill=C(INK))
    if state == "plated":
        _plate(d, cx, cy, 18, 10, 7)
        d.line([cx - 18, cy - 10, cx + 18, cy + 10], fill=C("P06"))         # 덮개 반쪽을 걸쳐 묶었다
    else:
        d.ellipse([cx - 12, cy - 5, cx + 12, cy + 7], fill=C("P01"))
        if state == "open":
            for ex, ey in ((cx - 4, cy - 1), (cx + 3, cy), (cx - 1, cy + 3)):
                d.point((ex, ey), fill=C("P53")); d.point((ex + 2, ey), fill=C("P53"))
        if state == "bait":
            _bait(d, cx + 4, cy + 14)
        if state == "dead":
            _dead_rats(d, cx - 2, cy + 8, 3)
            d.ellipse([cx - 20, cy + 12, cx - 6, cy + 18], fill=C("P06")); d.line([cx - 24, cy + 16, cx - 20, cy + 15], fill=C("P41"))  # 큰 놈
    return im


# ================================================================================================ 셔터 구동부(벽 1칸)
def motor(state="broken"):
    """B구역 셔터 구동부(벽 걸이 32×60): 쇠 상자 · 감은 체인 드럼 · 손 크랭크 · 위로 올라가는 케이블.
    broken = 기어 빠져 바닥에(체인이 늘어짐) · fixed = 기어 물림 · 노란 레버 위 · down = 레버 아래(케이블 팽팽, 붉은 등)."""
    im = img(32, 60)
    d = ImageDraw.Draw(im)
    d.line([16, 0, 16, 14], fill=C("P06")); d.line([17, 0, 17, 14], fill=C(INK))    # 위로 가는 케이블
    d.rectangle([3, 14, 28, 46], fill=C("P11")); d.rectangle([3, 14, 28, 46], outline=C(INK))
    d.line([4, 15, 27, 15], fill=C("P13"))
    d.ellipse([7, 18, 23, 34], fill=C("P05")); d.ellipse([9, 20, 21, 32], fill=C("P07"))  # 체인 드럼
    for a in range(0, 360, 45):
        t = math.radians(a)
        d.point((15 + math.cos(t) * 5, 26 + math.sin(t) * 5), fill=C("P04"))
    put_text(im, "B", 23, 35, "P49", size=8)
    if state == "broken":
        d.line([12, 34, 9, 58], fill=C("P06")); d.line([14, 34, 13, 58], fill=C("P05"))    # 늘어진 체인
        d.ellipse([18, 51, 26, 59], fill=C("P08")); d.ellipse([20, 53, 24, 57], fill=C("P04"))  # 빠진 기어
        d.line([25, 38, 30, 44], fill=C("P05"))                                             # 부러진 크랭크
    else:
        d.ellipse([18, 36, 26, 44], fill=C("P08")); d.ellipse([20, 38, 24, 42], fill=C("P05"))  # 물린 기어
        lever_y = 38 if state == "fixed" else 50
        d.line([27, 42, 31, lever_y], fill=C("P49")); d.ellipse([29, lever_y - 2, 31, lever_y + 2], fill=C("P50"))
        d.ellipse([5, 36, 9, 40], fill=C("P53" if state == "down" else "P56"))          # 상태 등
        d.line([14, 46, 14, 52], fill=C("P05")); d.line([17, 46, 17, 52], fill=C("P05"))
    return im


# ================================================================================================ 안쪽 방화 셔터(통로 3칸)
def fire_frame():
    """방화 셔터 자리(덧그림 32×96, 남북 3칸): 통로를 가로지르는 바닥 노란 금 + 위아래 끝 레일 받침(올라간 상태 — 지나갈 수 있다)."""
    im = img(32, 96)
    d = ImageDraw.Draw(im)
    for y in range(2, 94, 8):
        d.line([15, y, 15, y + 4], fill=C("P48")); d.line([16, y, 16, y + 4], fill=C("P49"))
    for y0 in (0, 88):
        d.rectangle([11, y0, 20, y0 + 7], fill=C("P05")); d.rectangle([11, y0, 20, y0 + 7], outline=C(INK))
        d.line([12, y0 + 1, 19, y0 + 1], fill=C("P07"))
    return im


def fire_down():
    """내린 방화 셔터(남북 3칸 막힘, 32×110): 옆에서 본 셔터 판 — 골 · 붉은 띠 '방화'(2077) · 분필 '쥐 가둠' · 밑에서 긁는 자국."""
    im = img(32, 110)
    d = ImageDraw.Draw(im)
    d.rectangle([9, 0, 22, 109], fill=C("P04"))                              # 위 셔터 상자(천장에서 내려온 판의 윗면)
    d.line([9, 0, 22, 0], fill=C("P07"))
    for y in range(4, 106):
        d.line([10, y, 21, y], fill=C(["P13", "P12", "P11"][(y - 4) % 3]))
    d.line([9, 4, 9, 106], fill=C("P14")); d.line([22, 4, 22, 106], fill=C(INK))
    for y0 in (20, 64):
        d.rectangle([10, y0, 21, y0 + 9], fill=C("P52"))
    put_text(im, "방", 11, 20, "P09", size=8)
    put_text(im, "화", 11, 64, "P09", size=8)
    d.line([12, 40, 19, 44], fill=C("P09")); d.line([12, 44, 19, 40], fill=C("P09"))   # 분필 X '쥐 가둠'
    d.rectangle([7, 0, 24, 3], fill=C("P06")); d.rectangle([7, 106, 24, 109], fill=C("P06"))
    for k in range(4):
        d.line([23, 30 + k * 18, 27, 32 + k * 18], fill=C("P08"))           # 안쪽(동쪽)에서 긁는 자국
    return im


# ================================================================================================ 상인회 비상 배수 통로(벽 2칸)
def w_drain_exit():
    """B구역 동쪽 끝 배수 통로 쇠창살(벽 64×60): 둥근 배수관 입구 + 창살 + 상인회 분필 '비상 — 상인회'(MQ-506 봉쇄 때 탈출로)."""
    im = img(64, 60)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 59], fill=C("P03"))
    d.ellipse([10, 10, 54, 54], fill=C("P05")); d.ellipse([14, 14, 50, 50], fill=C(INK))
    for x in range(18, 48, 6):
        d.line([x, 14, x, 50], fill=C("P08")); d.line([x + 1, 14, x + 1, 50], fill=C("P05"))
    d.line([14, 32, 50, 32], fill=C("P08"))
    d.rectangle([26, 28, 34, 36], fill=C("P26")); d.line([28, 30, 32, 30], fill=C("P24"))   # 자물쇠
    put_text(im, "비상", 4, 1, "P09", size=8)
    put_text(im, "상인회", 34, 1, "P09", size=8)
    for x in (16, 30, 44):                                                  # 바닥 물 자국
        d.line([x, 54, x + 3, 59], fill=C("P35"))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_JH = {
    "jh_burrow_a": _r(burrow_a, 2, 1, down=-2),
    "jh_burrow_b": _r(burrow_b, 2, 1, down=-2),
    "jh_burrow_c": _r(burrow_c, 2, 1, down=-2),
    "jh_motor": _r(motor, 1, 1, down=-2),
    "jh_fire_frame": _r(fire_frame, 0, 0, "deco"),
    "jh_fire_down": _r(fire_down, 1, 3, down=-2),
    "w_drain_exit": _r(w_drain_exit, 2, 0, "wall", dx=0, dy=2),
    "w_shop_sagong": _r(lambda: shutter("sagong", "shut", 21), 2, 0, "wall", dx=0, dy=2),
    "w_shop_bshop": _r(lambda: shutter("bshop", "shut", 22), 2, 0, "wall", dx=0, dy=2),
}

STATES_JH = {
    "jh_burrow_a": {s: (lambda s=s: burrow_a(s)) for s in ("plated", "bait", "dead")},
    "jh_burrow_b": {s: (lambda s=s: burrow_b(s)) for s in ("plated", "bait", "dead")},
    "jh_burrow_c": {s: (lambda s=s: burrow_c(s)) for s in ("plated", "bait", "dead")},
    "jh_motor": {s: (lambda s=s: motor(s)) for s in ("fixed", "down")},
    "w_shop_sagong": {"open": lambda: shutter("sagong", "open", 21), "half": lambda: shutter("sagong", "half", 21)},
    "w_shop_bshop": {"open": lambda: shutter("bshop", "open", 22), "half": lambda: shutter("bshop", "half", 22)},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_jh.png"
    ims = [v["fn"]() for v in PROPS_JH.values()] + [f() for st in STATES_JH.values() for f in st.values()]
    W = sum(i.width for i in ims) + 6 * len(ims)
    H = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, H), (70, 72, 78, 255))
    x = 0
    for i in ims:
        sheet.alpha_composite(i, (x, H - i.height))
        x += i.width + 6
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)
