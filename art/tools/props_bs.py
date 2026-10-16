"""봉천 배수지 · 상류 밸브실 · 낙성대 고개 소품(단계 1-11b SQ-S02 물 반 컵의 값, SD-09a L-R01-10 · L-R01-31 · L-R01-12 · SD-04a §4.2 · SD-16 아이작풍).
  reservoir     원형 콘크리트 저수조(5×3) — 둥근 뚜껑 · 점검구 · 환기관 · 사다리 · 큰 번호 · 2077년 '수질 1등급'과 2277년 붉은 손글씨 '끓여 마셔'
  pump          밸브실 양수 펌프(2×1) — 녹색 모터 덮개 · 굵은 관 두 줄 · 압력계
  w_valves      벽 밸브 다발(2칸, 벽 소품) — 관 매니폴드에 붉은 핸들 바퀴 넷(본문 '밸브 4')
  w_pipe_map    관로 계통도(2칸, 벽 소품) — 청사진 위 관악산에서 내려오는 관 · 상류 밸브 × 표 · 계곡 옛 관로 점선
  w_gauge       수위계(1칸, 벽 소품) — 유리관 눈금 5칸 · 푸른 물기둥(상태 lv0~lv5)
  valve_up      상류 관로 밸브(1×1) — 땅에서 솟은 굵은 관 + 큰 바퀴 핸들 · 사슬과 자물쇠(상태 open: 사슬이 끊겨 늘어짐)
  valve_open    열린 상류 밸브(진행기가 세운다 — 월드 소품은 상태 그림을 못 바꾼다) · bj_plate '배급 수도 — 관리 계엄사령부' 철판 표지(해법 D)
  pipe_run      땅 위 관로 한 칸(바닥 덧그림) — 회색 강관 · 녹 얼룩 · 이음 고리
  water_tap     급수 꼭지(1×1) — 저수조에서 끌어낸 쇠 수직관 · 붉은 핸들 · 마른 양동이
  trail_sign    2077년 등산로 표지(1×1) — 갈색 기둥 · '삼성산 정상 0.4km' 화살표 판
  arrow_paint   패거리 낙서(바닥 덧그림) — 바위에 붉은 페인트 화살표와 '봉천 물 ↓'
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01)."""
import os, sys, random, math
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def reservoir(num=1, seed=1):
    """원형 저수조: 3/4 시점 원통. 왼쪽이 밝고 오른쪽이 그늘(둥근 면), 테두리 띠 둘, 뚜껑은 살짝 솟은 둥근 판에 이끼 · 점검구 · 환기관."""
    rnd = random.Random(seed)
    W, H = 164, 128
    im = img(W, H)
    d = ImageDraw.Draw(im)
    cx, rx = 82, 76
    top_y, ry = 34, 26                                                     # 뚜껑 타원 중심 · 반지름
    bot_y = 104
    d.ellipse([cx - rx - 2, bot_y - 14, cx + rx + 2, bot_y + 22], fill=C("P02"))        # 땅 그림자
    for x in range(cx - rx, cx + rx + 1):                                  # 원통 벽: 세로 줄마다 명암(둥근 면)
        t = (x - (cx - rx)) / (2 * rx)
        k = "P08" if t < 0.18 else ("P07" if t < 0.52 else ("P06" if t < 0.82 else "P05"))
        yy = top_y + ry * math.sqrt(max(0.0, 1 - ((x - cx) / rx) ** 2))
        yb = bot_y + ry * 0.55 * math.sqrt(max(0.0, 1 - ((x - cx) / rx) ** 2))
        d.line([x, round(yy), x, round(yb)], fill=C(k))
        if rnd.random() < 0.05:                                            # 물때 줄
            d.line([x, round(yy) + 4, x, round(yy) + rnd.randint(10, 30)], fill=C("P05"))
    for band in (14, 44):                                                  # 테두리 띠(거푸집 이음)
        for x in range(cx - rx, cx + rx + 1):
            yy = top_y + band + ry * math.sqrt(max(0.0, 1 - ((x - cx) / rx) ** 2))
            d.point((x, round(yy)), fill=C("P05"))
            d.point((x, round(yy) + 1), fill=C("P08") if x < cx else C("P06"))
    # 뚜껑(살짝 솟은 둥근 판)
    d.ellipse([cx - rx, top_y - ry, cx + rx, top_y + ry], fill=C("P07"))
    d.ellipse([cx - rx + 6, top_y - ry + 3, cx + rx - 10, top_y + ry - 6], fill=C("P08"))
    d.ellipse([cx - rx + 26, top_y - ry + 8, cx + rx - 40, top_y + ry - 14], fill=C("P09"))
    d.arc([cx - rx, top_y - ry, cx + rx, top_y + ry], 0, 180, fill=C("P05"))
    for _ in range(9):                                                     # 이끼 · 낙엽
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.35, 0.9)
        x, y = cx + math.cos(a) * rx * r, top_y + math.sin(a) * ry * r
        s = rnd.randint(2, 5)
        d.ellipse([x - s, y - s * 0.6, x + s, y + s * 0.6], fill=C(rnd.choice(["P30", "P29", "P31", "P20"])))
    d.rectangle([cx - 10, top_y - 6, cx + 10, top_y + 6], fill=C("P11"))  # 점검구(쇠 뚜껑)
    d.rectangle([cx - 10, top_y - 6, cx + 10, top_y - 5], fill=C("P13"))
    d.line([cx - 7, top_y, cx + 7, top_y], fill=C("P10"))
    d.rectangle([cx + 6, top_y - 2, cx + 8, top_y + 2], fill=C("P49"))    # 자물쇠 고리
    vx = cx + 38                                                           # 환기관(버섯 머리)
    d.rectangle([vx - 2, top_y - 16, vx + 2, top_y + 2], fill=C("P12"))
    d.ellipse([vx - 7, top_y - 22, vx + 7, top_y - 13], fill=C("P11"))
    d.line([vx - 6, top_y - 15, vx + 6, top_y - 15], fill=C("P13"))
    # 앞쪽 사다리
    lx = cx - 30
    for x in (lx, lx + 10):
        d.line([x, top_y + ry - 3, x, bot_y + 8], fill=C("P04"), width=2)
    for y in range(top_y + ry + 2, bot_y + 8, 7):
        d.line([lx, y, lx + 10, y], fill=C("P04"))
    # 번호 · 표지 · 손글씨
    put_text(im, str(num), cx + 2, top_y + ry + 6, "P03", 16, "Galmuri11")
    d.rectangle([cx + 22, top_y + ry + 11, cx + 70, top_y + ry + 23], fill=C("P08"))
    d.rectangle([cx + 22, top_y + ry + 11, cx + 70, top_y + ry + 23], outline=C("P13"))
    put_text(im, "수질 1등급", cx + 26, top_y + ry + 13, "P12", 8, "Galmuri7")
    put_text(im, "끓여 마셔", cx - 66, top_y + ry + 30, "P53", 8, "Galmuri7")
    d.line([cx - 66, top_y + ry + 40, cx - 26, top_y + ry + 41], fill=C("P52"))
    for _ in range(4):                                                     # 금
        x0 = rnd.randint(cx - rx + 8, cx + rx - 8)
        y0 = rnd.randint(top_y + ry + 4, bot_y - 6)
        pts = [(x0, y0)]
        for _k in range(4):
            x0 += rnd.randint(-3, 3)
            y0 += rnd.randint(2, 5)
            pts.append((x0, y0))
        d.line(pts, fill=C("P04"))
    return im


def pump(seed=2):
    """양수 펌프(2×1): 콘크리트 받침 위 녹색 모터 덮개(냉각 갈비) + 굵은 흡입 · 토출관 + 압력계(바늘 0)."""
    im = img(66, 46)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 34, 63, 44], fill=C("P05")); d.line([2, 34, 63, 34], fill=C("P07"))
    d.rounded_rectangle([6, 12, 38, 36], 5, fill=C("P30"))
    d.rounded_rectangle([6, 12, 38, 20], 5, fill=C("P31"))
    for x in range(10, 36, 4):
        d.line([x, 22, x, 34], fill=C("P29"))
    d.rectangle([38, 18, 46, 32], fill=C("P12"))                          # 축 이음
    d.ellipse([44, 14, 60, 34], fill=C("P11")); d.ellipse([47, 17, 57, 31], fill=C("P12"))
    d.rectangle([52, 2, 58, 18], fill=C("P12")); d.line([52, 2, 52, 18], fill=C("P14"))    # 토출관(위로)
    d.rectangle([0, 26, 8, 32], fill=C("P12"))                            # 흡입관
    d.ellipse([22, 2, 32, 12], fill=C("P08")); d.ellipse([23, 3, 31, 11], fill=C("P09"))
    d.line([27, 7, 24, 9], fill=C("P53"))                                  # 바늘(0)
    d.point((27, 7), fill=C(INK))
    d.rectangle([12, 24, 22, 28], fill=C("P08"))
    put_text(im, "2", 14, 22, "P05", 8, "Galmuri7")
    return im


def w_valves(seed=3):
    """벽 밸브 다발(2칸): 가로 관 매니폴드에서 내려온 짧은 관 넷, 붉은 핸들 바퀴(하나는 사슬로 묶였다 — 상류 계통)."""
    im = img(62, 38)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 4, 61, 9], fill=C("P12")); d.line([0, 4, 61, 4], fill=C("P14")); d.line([0, 9, 61, 9], fill=C("P10"))
    for k, x in enumerate((8, 22, 38, 52)):
        d.rectangle([x - 2, 9, x + 2, 22], fill=C("P12"))
        d.ellipse([x - 7, 18, x + 7, 32], outline=C("P53"), width=2)
        d.line([x - 6, 25, x + 6, 25], fill=C("P53")); d.line([x, 19, x, 31], fill=C("P53"))
        d.ellipse([x - 2, 23, x + 2, 27], fill=C("P52"))
        if k == 3:                                                         # 상류 계통: 잠긴 표 꼬리표
            d.rectangle([x + 4, 30, x + 9, 36], fill=C("P21")); d.point((x + 6, 32), fill=C("P53"))
    put_text(im, "상류", 44, 0, "P09", 8, "Galmuri7")
    return im


def w_pipe_map(seed=4):
    """관로 계통도(2칸): 바랜 청사진 — 위쪽 산(관악산 등고선)에서 내려오는 굵은 관, 상류 밸브 붉은 ×, 계곡 쪽 옛 관로 점선, 아래 배수지 두 원."""
    im = img(62, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 61, 39], fill=C("P10")); d.rectangle([2, 2, 59, 37], fill=C("P44"))
    for r in (6, 10, 14):                                                  # 등고선
        d.arc([4, -4 - r, 30 + r, 10 + r], 0, 180, fill=C("P45"))
    d.line([(12, 6), (16, 14), (24, 20), (30, 30)], fill=C("P09"), width=2)  # 본관
    for x in range(34, 52, 3):                                             # 계곡 옛 관로(점선)
        d.point((x, 12 + (x - 34) // 2), fill=C("P15"))
    d.line([(14, 9), (18, 13)], fill=C("P54")); d.line([(18, 9), (14, 13)], fill=C("P54"))   # 상류 밸브 ×
    d.ellipse([24, 28, 32, 34], outline=C("P09")); d.ellipse([34, 28, 42, 34], outline=C("P09"))
    put_text(im, "봉천", 44, 28, "P09", 8, "Galmuri7")
    d.rectangle([2, 2, 59, 37], outline=C("P13"))
    return im


def w_gauge(level=5):
    """수위계(1칸): 쇠틀 안 유리관 · 눈금 5 · 푸른 물기둥(level 칸) · 위 '수위' 표. level 0은 바닥에 물때만."""
    im = img(26, 46)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 2, 21, 44], fill=C("P11")); d.rectangle([4, 2, 21, 3], fill=C("P13"))
    d.rectangle([9, 8, 16, 40], fill=C("P02"))
    for k in range(5):
        y = 38 - k * 6
        if k < level:
            d.rectangle([10, y - 5, 15, y], fill=C("P45") if k < level - 1 else C("P46"))
        d.line([17, y - 5, 20, y - 5], fill=C("P09"))
    if level == 0:
        d.line([10, 39, 15, 39], fill=C("P35"))
    d.line([9, 8, 9, 40], fill=C("P14"))
    if level <= 1:
        d.rectangle([4, 42, 21, 44], fill=C("P53"))                       # 붉은 띠(바닥)
    put_text(im, "수위", 5, 0, "P09", 8, "Galmuri7")
    return im


def valve_up(state=""):
    """상류 관로 밸브(1×1): 산비탈에서 솟은 굵은 강관 + 큰 바퀴 핸들. 기본 = 사슬 감기고 자물쇠, open = 끊긴 사슬이 늘어지고 바퀴가 돌아 있다."""
    im = img(36, 48)
    d = ImageDraw.Draw(im)
    d.ellipse([3, 38, 33, 47], fill=C("P02"))
    d.rectangle([12, 20, 23, 44], fill=C("P25")); d.line([12, 20, 12, 44], fill=C("P26")); d.line([23, 20, 23, 44], fill=C(INK))
    d.rectangle([9, 38, 26, 43], fill=C("P24"))
    d.rectangle([10, 26, 25, 30], fill=C("P24"))                           # 플랜지
    for x in (11, 15, 20, 24):
        d.point((x, 28), fill=C("P27"))
    rot = 0.4 if state == "open" else 0.0
    cx, cy, r = 18, 13, 11
    d.ellipse([cx - r, cy - r * 0.7, cx + r, cy + r * 0.7], outline=C("P53"), width=3)
    for k in range(3):
        a = rot + k * math.pi / 3
        d.line([cx - math.cos(a) * r, cy - math.sin(a) * r * 0.7, cx + math.cos(a) * r, cy + math.sin(a) * r * 0.7], fill=C("P52"), width=2)
    d.ellipse([cx - 3, cy - 2, cx + 3, cy + 2], fill=C("P05"))
    if state == "open":
        d.line([(23, 22), (30, 34), (28, 44)], fill=C("P06"), width=1)      # 끊겨 늘어진 사슬
        for y in range(24, 44, 3):
            d.point((29, y), fill=C("P07"))
    else:
        for k in range(7):                                                 # 바퀴를 관에 묶은 사슬
            x, y = 8 + k * 3, 10 + (k % 2) * 4
            d.ellipse([x - 1, y - 1, x + 1, y + 1], outline=C("P07"))
        d.rectangle([26, 16, 32, 22], fill=C("P49")); d.rectangle([27, 13, 31, 17], outline=C("P07"))   # 자물쇠
    return im


def bj_plate(seed=8):
    """'배급 수도 — 관리 계엄사령부' 철판 표지(1×1): 앵글 쇠기둥 둘에 볼트로 박은 새 철판(감색 띠 · 흰 스텐실 글씨 · 붉은 경고 줄) — 녹슨 밸브 곁이라 혼자 번쩍인다."""
    im = img(36, 52)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 46, 32, 51], fill=C("P02"))
    for x in (6, 28):
        d.rectangle([x, 20, x + 2, 49], fill=C("P13")); d.line([x, 20, x, 49], fill=C("P48"))
    d.rectangle([1, 4, 35, 30], fill=C("P48")); d.rectangle([2, 5, 34, 29], fill=C("P09"))
    d.rectangle([2, 5, 34, 12], fill=C("P44"))                               # 감색 머리 띠
    put_text(im, "배급수도", 4, 4, "P09", 8, "Galmuri7")
    put_text(im, "계엄사", 7, 14, "P44", 8, "Galmuri7")
    d.rectangle([2, 25, 34, 27], fill=C("P53"))                              # 붉은 경고 줄('무단 조작 시 적성 행위')
    for x, y in ((3, 6), (33, 6), (3, 28), (33, 28)):
        d.point((x, y), fill=C("P05"))                                      # 볼트
    return im


def pipe_run(seed=5):
    """땅 위 관로(덧그림 1칸): 회색 강관이 가로로 지나가고 녹 얼룩 · 가운데 이음 고리 · 받침 돌(울타리로 읽히지 않게 낮고 두껍게)."""
    im = img(32, 14)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 10, 31, 13], fill=C("P02"))                           # 그림자
    d.rectangle([0, 4, 31, 10], fill=C("P13")); d.line([0, 4, 31, 4], fill=C("P48")); d.line([0, 5, 31, 5], fill=C("P14"))
    d.line([0, 10, 31, 10], fill=C("P05"))
    rnd = random.Random(seed)
    for _ in range(3):                                                     # 녹 얼룩
        x = rnd.randint(2, 27)
        d.rectangle([x, 6, x + rnd.randint(1, 3), 8], fill=C("P25"))
    d.rectangle([14, 3, 18, 11], fill=C("P05")); d.line([14, 3, 18, 3], fill=C("P14")); d.point((16, 7), fill=C("P48"))
    d.rectangle([5, 11, 9, 13], fill=C("P06")); d.rectangle([22, 11, 26, 13], fill=C("P06"))
    return im


def water_tap(seed=9):
    """급수 꼭지(1×1): 저수조에서 끌어낸 쇠 수직관 + 꼭지 + 아래 양동이(바닥에 물기 없음 — 말랐다) + 관에 감은 헝겊."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 38, 28, 43], fill=C("P02"))
    d.rectangle([14, 6, 18, 40], fill=C("P13")); d.line([14, 6, 14, 40], fill=C("P48")); d.line([18, 6, 18, 40], fill=C("P05"))
    d.rectangle([12, 4, 20, 7], fill=C("P05"))
    d.rectangle([18, 12, 25, 15], fill=C("P13")); d.rectangle([24, 15, 26, 19], fill=C("P05"))   # 꼭지
    d.ellipse([20, 8, 26, 12], outline=C("P53"))                           # 붉은 핸들
    d.rectangle([13, 22, 19, 26], fill=C("P21")); d.line([13, 24, 19, 24], fill=C("P18"))         # 헝겊
    d.polygon([(19, 30), (30, 30), (28, 40), (21, 40)], fill=C("P44")); d.line([19, 30, 30, 30], fill=C("P09"))   # 양동이
    d.arc([19, 24, 30, 34], 200, 340, fill=C("P06"))
    return im


def trail_sign(seed=6):
    """2077년 등산로 표지(1×1): 갈색 나무 기둥 + 화살표 판 둘(위 '정상 0.4km' · 아래 '삼성산') — 한쪽 판이 기울었다."""
    im = img(36, 50)
    d = ImageDraw.Draw(im)
    d.ellipse([10, 44, 26, 49], fill=C("P02"))
    d.rectangle([16, 8, 20, 47], fill=C("P18")); d.line([16, 8, 16, 47], fill=C("P19"))
    d.polygon([(4, 8), (30, 8), (35, 13), (30, 18), (4, 18)], fill=C("P20"))
    d.polygon([(4, 8), (30, 8), (35, 13), (30, 18), (4, 18)], outline=C("P17"))
    put_text(im, "정상0.4", 5, 8, "P09", 8, "Galmuri7")
    d.polygon([(30, 21), (5, 24), (1, 30), (6, 34), (31, 31)], fill=C("P19"))
    put_text(im, "삼성산", 9, 24, "P08", 8, "Galmuri7")
    return im


def arrow_paint(seed=7):
    """패거리 낙서(덧그림): 바위 면에 흘러내린 붉은 페인트 화살표 ↓ 와 '봉천 물'."""
    im = img(44, 26)
    d = ImageDraw.Draw(im)
    put_text(im, "봉천 물", 1, 1, "P53", 8, "Galmuri7")
    d.line([(36, 2), (36, 18)], fill=C("P53"), width=3)
    d.polygon([(30, 15), (42, 15), (36, 24)], fill=C("P53"))
    for x, y in ((8, 11), (20, 12), (37, 24)):
        d.line([x, y, x, y + 3], fill=C("P52"))                            # 흘러내린 자국
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_BS = {
    "reservoir": _r(lambda: reservoir(1, 1), 5, 3, down=-4),
    "reservoir2": _r(lambda: reservoir(2, 9), 5, 3, down=-4),
    "pump": _r(pump, 2, 1, down=-2),
    "w_valves": _r(w_valves, 2, 0, "wall", dx=1, dy=6),
    "w_pipe_map": _r(w_pipe_map, 2, 0, "wall", dx=1, dy=6),
    "w_gauge": _r(lambda: w_gauge(5), 1, 0, "wall", dx=3, dy=0),
    "valve_up": _r(valve_up, 1, 1, down=-2),
    "valve_open": _r(lambda: valve_up("open"), 1, 1, down=-2),         # 진행기가 세우는 열린 밸브(월드 청크 소품은 상태를 못 바꾼다)
    "bj_plate": _r(bj_plate, 1, 1, down=-2),
    "pipe_run": _r(pipe_run, 0, 0, "deco"),
    "water_tap": _r(water_tap, 1, 1, down=-2),
    "trail_sign": _r(trail_sign, 1, 1, down=-2),
    "arrow_paint": _r(arrow_paint, 0, 0, "deco"),
}

STATES_BS = {
    "w_gauge": {f"lv{k}": (lambda k=k: w_gauge(k)) for k in range(5)},
    "valve_up": {"open": lambda: valve_up("open")},
}


if __name__ == "__main__":                                                 # 미리 보기: python3 props_bs.py out.png
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_bs.png"
    ims = [fn["fn"]() for fn in PROPS_BS.values()] + [f() for st in STATES_BS.values() for f in st.values()]
    W = sum(i.width for i in ims) + 8 * len(ims)
    H = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, H), C("P30"))
    x = 0
    for i in ims:
        sheet.alpha_composite(i, (x, H - i.height))
        x += i.width + 8
    sheet.resize((W * 3, H * 3), Image.NEAREST).save(out)
    print(out)
