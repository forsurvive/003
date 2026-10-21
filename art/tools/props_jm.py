"""영등포 지하상가(지하시장) 소품(단계 1-4, SD-09a L-R02-11 · SD-16 §7·§8 아이작풍).
2077년 상가의 셔터 점포가 200년째 같은 상호를 덧칠하며 장사한다(환경 서사 ⑨-1: 칠이 수십 겹이라 셔터가 두껍다).
벽 소품(kind wall, 벽면 윗칸 y=1에 건다): 셔터 점포(닫힘 · 반쯤 · 열림) · 안내 간판 · 상인회 현수막 · 환영 판 · 게시판 · 냉장 창고 문 · 큰 셔터(B구역).
바닥 소품: 출입세 탁자 · 노점 매대(옷 · 부품 · 약 · 분식 · 정수 · 위조) · 물 없는 분수(캡) · 배전반 · 작업대 · 진공관 랙 · 무너진 천장 판 ·
배수 밸브 · 야생 구울 둥지 · 계단(위로) · 넘어진 파수 경비 로봇(봉천, MQ-102 잠든 로봇).
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01).
"""
import os, sys, random, math, zlib
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

T = 32
C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


# ================================================================================================ 셔터 점포(벽)
SHOP_PAINT = {                     # 상호 띠 색(바탕, 글자) — 200년 덧칠한 같은 상호
    "clothes": ("P45", "P09", "복희 의류"), "parts": ("P25", "P09", "재석 전업사"), "meds": ("P53", "P09", "수연 약방"),
    "food": ("P48", "P01", "상민 분식"), "forge": ("P04", "P08", "희정 인쇄"), "water": ("P62", "P01", "민지 정수"),
    "repair": ("P36", "P09", "민수 수선"), "blank1": ("P20", "P04", ""), "blank2": ("P12", "P07", ""), "blank3": ("P44", "P08", ""),
}


def _sign_band(d, im, x0, x1, y0, kind):
    bg, fg, name = SHOP_PAINT[kind]
    d.rectangle([x0, y0, x1, y0 + 10], fill=C(bg))
    d.line([x0, y0, x1, y0], fill=C("P09") if bg not in ("P48", "P62") else C("P50"))
    d.line([x0, y0 + 10, x1, y0 + 10], fill=C(INK))
    for k in range(3):                                                # 덧칠 자국(옛 칠이 비친다)
        xx = x0 + 3 + k * 19
        d.line([xx, y0 + 2, xx + 4, y0 + 2], fill=C(bg if k % 2 else "P07"))
    if name:
        put_text(im, name, x0 + 4, y0 + 1, fg, size=8)


def shutter(kind="blank1", state="shut", seed=0):
    """셔터 점포 앞(벽 2칸 = 64×62): 위 상호 띠 + 셔터 상자 + 골 셔터(수십 겹 칠, 두꺼운 테) · 반쯤(아래로 안쪽 물건이 보인다) · 열림(가게 안 선반)."""
    rnd = random.Random(seed)
    im = img(64, 62)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 61], fill=C("P03"))                        # 점포 틀(어두운 기둥)
    d.rectangle([2, 0, 61, 61], fill=C("P02"))
    _sign_band(d, im, 2, 61, 2, kind)
    d.rectangle([2, 13, 61, 18], fill=C("P05")); d.line([2, 13, 61, 13], fill=C("P07")); d.line([2, 18, 61, 18], fill=C(INK))  # 셔터 상자
    top = 19
    if state == "open":
        bottom = top                                                   # 다 올렸다
    elif state == "half":
        bottom = 38
    else:
        bottom = 60
    if state != "shut":                                                # 가게 안: 선반 두 줄 + 물건
        d.rectangle([3, top, 60, 60], fill=C("P02"))
        for sy in (34, 48):
            d.rectangle([5, sy, 58, sy + 2], fill=C("P18")); d.line([5, sy, 58, sy], fill=C("P20"))
            x = 7
            while x < 55:
                h = rnd.randint(4, 9)
                col = rnd.choice(["P45", "P53", "P49", "P36", "P07", "P26", "P21"])
                d.rectangle([x, sy - h, x + rnd.randint(2, 4), sy - 1], fill=C(col))
                x += rnd.randint(4, 7)
        d.rectangle([3, 56, 60, 60], fill=C("P19")); d.line([3, 56, 60, 56], fill=C("P21"))   # 매대 앞판
        d.line([10, 22, 10, 26], fill=C("P05")); d.rectangle([7, 26, 13, 29], fill=C("P50"))  # 백열등
        d.point((10, 30), fill=C("P49"))
    if bottom > top:                                                   # 골 셔터(굵은 칠 + 가로 골 2px)
        for y in range(top, bottom + 1):
            k = (y - top) % 3
            col = ["P07", "P06", "P05"][k]
            d.line([3, y, 60, y], fill=C(col))
        for k in range(rnd.randint(2, 4)):                             # 칠 벗겨진 자리 · 녹
            x, y = rnd.randint(6, 54), rnd.randint(top + 2, max(top + 3, bottom - 4))
            d.rectangle([x, y, x + rnd.randint(2, 5), y + 1], fill=C(rnd.choice(["P25", "P04", SHOP_PAINT[kind][0]])))
        d.rectangle([26, bottom - 3, 37, bottom], fill=C("P04")); d.line([26, bottom - 3, 37, bottom - 3], fill=C("P08"))  # 손잡이 막대
        if state == "shut":
            d.rectangle([29, bottom - 2, 34, bottom + 1], fill=C("P48")); d.point((31, bottom - 1), fill=C(INK))  # 자물쇠
        d.line([3, bottom, 60, bottom], fill=C(INK))
    d.line([2, 0, 2, 61], fill=C("P05")); d.line([61, 0, 61, 61], fill=C(INK))
    return im


def w_sign_market():
    """상인회 현수막(벽 3칸): '영등포 지하상가 상인회 — 영업 중'(SD-09a ② 앵커). 천 현수막 두 줄 + 끈."""
    im = img(94, 28)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 3), (91, 3), (91, 25), (2, 25)], fill=C("P09"))
    d.line([2, 3, 91, 3], fill=C("P08")); d.line([2, 25, 91, 25], fill=C("P07"))
    for x in (2, 91):
        d.line([x, 0, x, 3], fill=C("P05"))
    for x in range(14, 90, 19):                                        # 천 주름
        d.line([x, 4, x - 2, 24], fill=C("P08"))
    put_text(im, "영등포 지하상가", 13, 4, "P52", size=8)
    put_text(im, "상인회 — 영업 중", 10, 14, "P44", size=8)
    return im


def w_sign_welcome():
    """출입세 초소 옆 손글씨 판(벽 2칸): '피부 좋은 손님 환영'(SD-09a J-01) — 구울 경비의 농담."""
    im = img(56, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 53, 27], fill=C("P19")); d.rectangle([2, 2, 53, 27], outline=C("P17"))
    d.line([3, 3, 52, 3], fill=C("P21"))
    for y in (11, 19):
        d.line([4, y, 51, y], fill=C("P18"))
    put_text(im, "피부 좋은", 6, 4, "P52", size=8)
    put_text(im, "손님 환영", 16, 15, "P52", size=8)
    d.point((48, 24), fill=C("P53")); d.point((49, 24), fill=C("P53"))
    return im


def w_sign_dir(text_="중앙 광장 →"):
    """2077 상가 안내판(벽 2칸): 청록 바탕 흰 글자."""
    im = img(60, 16)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 58, 14], fill=C("P61")); d.line([1, 1, 58, 1], fill=C("P62")); d.line([1, 14, 58, 14], fill=C(INK))
    put_text(im, text_, 5, 3, "P09", size=8)
    return im


def w_board_jm():
    """상인회 게시판(벽 2칸): 현상금 쪽지 · 일감 · 셔터 순번표. 붉은 핀."""
    rnd = random.Random(7)
    im = img(60, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 58, 38], fill=C("P18")); d.rectangle([3, 3, 56, 36], fill=C("P20"))
    d.line([1, 1, 58, 1], fill=C("P21"))
    for (x, y, w, h, col) in [(5, 5, 14, 16, "P09"), (21, 6, 12, 12, "P08"), (35, 4, 18, 14, "P22"), (6, 23, 18, 11, "P08"),
                              (27, 20, 12, 15, "P09"), (41, 21, 13, 13, "P15")]:
        d.rectangle([x, y, x + w, y + h], fill=C(col))
        for yy in range(y + 3, y + h - 1, 3):
            d.line([x + 2, yy, x + w - 2 - rnd.randint(0, 3), yy], fill=C("P05"))
        d.point((x + w // 2, y + 1), fill=C("P53"))
    d.rectangle([36, 5, 52, 9], fill=C("P53"))                         # '현상금' 붉은 머리
    return im


def w_cold_door():
    """냉장 창고 문(벽 2칸): 두꺼운 단열 문 + 손잡이 레버 + 서리 대신 녹. 전원이 끊겨 문틈이 검다."""
    im = img(52, 60)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 51, 59], fill=C("P04"))
    d.rectangle([3, 3, 48, 59], fill=C("P13")); d.line([3, 3, 48, 3], fill=C("P15"))
    for y in (16, 46):
        d.rectangle([3, y, 48, y + 3], fill=C("P12"))
    d.rectangle([38, 26, 44, 34], fill=C("P05")); d.line([38, 30, 46, 30], fill=C("P08"))
    d.line([26, 4, 26, 59], fill=C(INK))
    for k in range(4):
        d.line([6 + k * 9, 40, 6 + k * 9, 46 + k], fill=C("P25"))
    put_text(im, "냉장", 8, 7, "P02", size=8)
    return im


def w_shutter_big_open():
    """B구역 큰 셔터 — 들어 올림(1-12c FQ-JH-01): 셔터가 위 상자로 반쯤 감겼고 풀린 사슬이 옆에 걸렸다. 아래로 B구역 바닥 · 어둠."""
    im = img(96, 62)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 61], fill=C("P03"))
    d.rectangle([2, 4, 93, 61], fill=C("P01"))                          # 안쪽 어둠
    for y in range(40, 61, 4):
        d.line([4, y, 91, y], fill=C("P02"))                             # 안쪽 바닥 줄눈
    for y in range(4, 26):
        d.line([2, y, 93, y], fill=C(["P06", "P05", "P04"][(y - 4) % 3]))
    d.rectangle([2, 0, 93, 3], fill=C("P05"))
    d.line([2, 26, 93, 26], fill=C(INK))
    put_text(im, "B구역", 34, 10, "P09", size=8)
    for k in range(7):                                                  # 풀린 사슬이 기둥에 늘어졌다
        d.ellipse([86, 28 + k * 4, 90, 32 + k * 4], outline=C("P13"))
    d.rectangle([84, 56, 91, 61], fill=C("P48"))
    return im


def w_shutter_big():
    """B구역 큰 셔터(벽 3칸): 내려앉은 구역을 막은 셔터 + 쇠사슬 + '출입 금지' 붉은 칠."""
    im = img(96, 62)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 61], fill=C("P03"))
    for y in range(4, 61):
        d.line([2, y, 93, y], fill=C(["P06", "P05", "P04"][(y - 4) % 3]))
    d.rectangle([2, 0, 93, 3], fill=C("P05"))
    for x in range(6, 92, 6):                                          # 사슬
        d.ellipse([x, 30, x + 5, 34], outline=C("P13"))
    d.rectangle([44, 29, 51, 37], fill=C("P48"))
    put_text(im, "출입 금지", 24, 12, "P53", size=8)
    put_text(im, "B구역", 34, 44, "P09", size=8)
    for k in range(6):                                                  # 셔터 밑 부스러기·긁힌 자국(안에서 무언가)
        d.line([10 + k * 14, 58, 14 + k * 14, 55], fill=C("P02"))
    return im


# ================================================================================================ 바닥 소품
def toll_table():
    """출입세 탁자(2×1): 접이식 탁자 + 캡 깡통(뚜껑 반짝) + 손글씨 '출입세 50캡' 판 + 장부."""
    im = img(66, 44)
    d = ImageDraw.Draw(im)
    for x in (5, 57):
        d.line([x, 22, x + 2, 42], fill=C("P05")); d.line([x + 2, 22, x, 42], fill=C("P04"))
    d.rectangle([1, 16, 64, 23], fill=C("P07")); d.line([1, 16, 64, 16], fill=C("P09")); d.line([1, 23, 64, 23], fill=C(INK))
    d.rectangle([8, 7, 20, 16], fill=C("P06")); d.ellipse([8, 5, 20, 9], fill=C("P08"))               # 캡 깡통
    for x in (10, 13, 16):
        d.ellipse([x, 4, x + 3, 6], fill=C("P26"))
    d.rectangle([24, 9, 38, 16], fill=C("P45")); d.line([31, 9, 31, 16], fill=C("P44")); d.line([24, 9, 38, 9], fill=C("P46"))  # 장부
    d.rectangle([42, 0, 63, 15], fill=C("P19")); d.rectangle([42, 0, 63, 15], outline=C("P17"))         # 세워 둔 판
    put_text(im, "출입세", 44, 1, "P52", size=8)
    put_text(im, "50캡", 46, 8, "P01", size=8)
    return im


def stall(kind="clothes", seed=0):
    """노점 매대(2×1): 각목 다리 + 판 + 물건. 위에 백열등 줄. kind: clothes · parts · meds · food · water · forge."""
    rnd = random.Random(seed + zlib.crc32(kind.encode()) % 97)          # 문자열 hash()는 실행마다 달라 굽기마다 그림이 바뀌었다
    im = img(66, 48)
    d = ImageDraw.Draw(im)
    for x in (3, 60):
        d.rectangle([x, 22, x + 2, 46], fill=C("P17"))
    d.rectangle([1, 28, 64, 46], fill=C("P18")); d.rectangle([1, 26, 64, 29], fill=C("P20")); d.line([1, 26, 64, 26], fill=C("P21"))
    for y in range(33, 46, 5):
        d.line([2, y, 63, y], fill=C("P17"))
    if kind == "clothes":                                              # 옷걸이 봉 + 외투 넷(장사꾼 코트 A-019 따위)
        d.line([4, 2, 61, 2], fill=C("P13")); d.line([4, 2, 4, 26], fill=C("P12")); d.line([61, 2, 61, 26], fill=C("P12"))
        for i, col in enumerate(["P24", "P44", "P29", "P18"]):
            x = 8 + i * 13
            d.line([x + 5, 2, x + 5, 4], fill=C("P05"))
            d.polygon([(x + 1, 5), (x + 10, 5), (x + 11, 24), (x, 24)], fill=C(col))
            d.line([x + 5, 6, x + 5, 23], fill=C(INK)); d.line([x + 1, 5, x + 10, 5], fill=C("P09"))
    elif kind == "parts":                                              # 부품 통 + 진공관 + 전선 뭉치
        for i in range(4):
            x = 4 + i * 15
            d.rectangle([x, 15, x + 12, 26], fill=C("P12")); d.line([x, 15, x + 12, 15], fill=C("P14"))
            for k in range(4):
                d.point((x + 2 + k * 3, 17 + (k % 2)), fill=C(rnd.choice(["P26", "P49", "P08", "P63"])))
        for x in (10, 16, 22):
            d.rectangle([x, 9, x + 3, 14], fill=C("P15")); d.ellipse([x, 6, x + 3, 10], fill=C("P15")); d.point((x + 1, 8), fill=C("P60"))
        d.arc([38, 4, 56, 16], 0, 360, fill=C("P53"))
    elif kind == "meds":                                               # 약병 · 스팀팩 · 붕대
        x = 6
        while x < 58:
            r = rnd.random()
            if r < 0.4:
                d.rectangle([x, 17, x + 3, 25], fill=C(rnd.choice(["P26", "P36", "P46"]))); d.rectangle([x, 15, x + 3, 16], fill=C("P09"))
                x += 6
            elif r < 0.7:
                d.rectangle([x, 20, x + 7, 24], fill=C("P09")); d.line([x + 3, 20, x + 3, 24], fill=C("P53"))   # 스팀팩
                d.line([x + 7, 22, x + 10, 22], fill=C("P13"))
                x += 12
            else:
                d.ellipse([x, 19, x + 6, 25], fill=C("P08")); d.ellipse([x + 2, 21, x + 4, 23], fill=C("P06"))
                x += 9
        d.rectangle([22, 6, 42, 13], fill=C("P09")); d.line([31, 7, 31, 12], fill=C("P53")); d.line([28, 9, 34, 9], fill=C("P53"))
    elif kind == "food":                                               # 분식: 김 나는 솥 + 꼬치 + 그릇
        d.ellipse([6, 12, 30, 26], fill=C("P04")); d.ellipse([8, 12, 28, 18], fill=C("P26")); d.ellipse([11, 13, 25, 16], fill=C("P27"))
        for k in range(3):
            d.arc([10 + k * 5, 2, 18 + k * 5, 12], 200, 340, fill=C("P08"))
        for i in range(5):
            x = 36 + i * 5
            d.line([x, 12, x, 25], fill=C("P20")); d.rectangle([x - 1, 14, x + 1, 20], fill=C(["P25", "P26", "P24"][i % 3]))
        d.ellipse([56, 19, 63, 25], fill=C("P09"))
    elif kind == "water":                                              # 정수 노점: 물통 둘 + 꼭지 + 깡통 컵
        for x in (5, 25):
            d.rectangle([x, 4, x + 16, 25], fill=C("P46")); d.line([x, 4, x + 16, 4], fill=C("P63"))
            d.rectangle([x + 2, 8, x + 14, 10], fill=C("P45"))
            d.line([x + 8, 25, x + 8, 27], fill=C("P13"))
        for x in (46, 52, 58):
            d.rectangle([x, 19, x + 4, 25], fill=C("P07")); d.line([x, 19, x + 4, 19], fill=C("P09"))
    elif kind == "forge":                                              # 위조상: 도장 · 서류 더미 · 스탠드
        d.rectangle([6, 18, 30, 25], fill=C("P09")); d.rectangle([8, 16, 28, 23], fill=C("P08")); d.line([10, 19, 24, 19], fill=C("P05"))
        for x in (36, 42):
            d.rectangle([x, 17, x + 4, 25], fill=C("P17")); d.rectangle([x - 1, 23, x + 5, 25], fill=C("P53"))
        d.line([52, 25, 52, 8], fill=C("P05")); d.line([52, 8, 58, 6], fill=C("P05")); d.polygon([(55, 4), (62, 4), (60, 10), (56, 10)], fill=C("P29"))
        d.point((58, 11), fill=C("P50"))
    return im


def fountain_dry():
    """물 없는 분수(3×3): 팔각 돌 테 + 바닥에 2077 동전과 2277 캡이 섞여 반짝인다(환경 서사 ⑨-2). 가운데 돌 기둥."""
    rnd = random.Random(11)
    im = img(98, 80)
    d = ImageDraw.Draw(im)
    cx, cy = 49, 50
    rim = [(cx + 46 * math.cos(a) * 1.0, cy + 26 * math.sin(a)) for a in [k * math.pi / 4 + math.pi / 8 for k in range(8)]]
    d.polygon([(x, y + 6) for x, y in rim], fill=C("P04"))             # 테 옆면
    d.polygon(rim, fill=C("P08"))
    inner = [(cx + 38 * math.cos(a), cy + 20 * math.sin(a)) for a in [k * math.pi / 4 + math.pi / 8 for k in range(8)]]
    d.polygon(inner, fill=C("P05"))
    d.polygon([(x, y + 2) for x, y in inner], fill=C("P04"))
    for _ in range(46):                                                 # 동전·캡
        a, r = rnd.random() * math.tau, rnd.random() ** 0.6
        x, y = int(cx + 33 * r * math.cos(a)), int(cy + 3 + 15 * r * math.sin(a))
        col = rnd.choice(["P26", "P26", "P48", "P49", "P08", "P13"])
        d.point((x, y), fill=C(col)); d.point((x + 1, y), fill=C(col))
        if rnd.random() < 0.25:
            d.point((x, y - 1), fill=C("P50"))
    d.rectangle([cx - 6, cy - 34, cx + 6, cy + 2], fill=C("P07"))       # 가운데 기둥 + 꽃 받침
    d.line([cx - 6, cy - 34, cx - 6, cy + 2], fill=C("P09")); d.line([cx + 6, cy - 34, cx + 6, cy + 2], fill=C("P05"))
    d.ellipse([cx - 14, cy - 44, cx + 14, cy - 32], fill=C("P08")); d.ellipse([cx - 11, cy - 43, cx + 11, cy - 36], fill=C("P06"))
    d.ellipse([cx - 9, cy + 0, cx + 9, cy + 5], fill=C("P05"))
    return im


def switchboard():
    """배전반(2×1, 높이 큰 철함): 문 둘 · 계기 셋(바늘) · 굵은 스위치 · 위로 굵은 전선관. 마영식이 200년 지킨 회선."""
    im = img(66, 78)
    d = ImageDraw.Draw(im)
    for x in (14, 30, 46):
        d.rectangle([x, 0, x + 4, 14], fill=C("P05")); d.line([x, 0, x, 14], fill=C("P07"))
    d.rectangle([2, 14, 63, 76], fill=C("P12")); d.line([2, 14, 63, 14], fill=C("P14")); d.line([2, 76, 63, 76], fill=C(INK))
    d.line([32, 16, 32, 75], fill=C("P10"))
    for i, x in enumerate((7, 22, 39)):                                 # 계기
        d.ellipse([x, 20, x + 12, 32], fill=C("P09")); d.ellipse([x, 20, x + 12, 32], outline=C("P05"))
        a = [-2.2, -1.4, -0.7][i]
        d.line([x + 6, 27, x + 6 + int(5 * math.cos(a)), 27 + int(5 * math.sin(a))], fill=C("P53"))
    for x in (8, 18, 40, 50):                                           # 차단기 손잡이
        d.rectangle([x, 40, x + 5, 52], fill=C("P02")); d.rectangle([x + 1, 42, x + 4, 46], fill=C("P08"))
    d.rectangle([10, 58, 22, 68], fill=C("P49")); put_text(im, "!", 14, 58, "P01", size=8)
    for x, col in ((44, "P56"), (50, "P54"), (56, "P60")):
        d.point((x, 62), fill=C(col)); d.point((x + 1, 62), fill=C(col))
    d.rectangle([28, 44, 36, 50], fill=C("P05"))
    return im


def workbench():
    """마영식 작업대(2×1): 회로판 · 오실로스코프(녹 화면) · 납땜 인두 · 진공관 상자 · 스탠드."""
    im = img(66, 50)
    d = ImageDraw.Draw(im)
    for x in (3, 59):
        d.rectangle([x, 26, x + 3, 48], fill=C("P05"))
    d.rectangle([1, 22, 64, 28], fill=C("P18")); d.line([1, 22, 64, 22], fill=C("P20")); d.line([1, 28, 64, 28], fill=C(INK))
    d.rectangle([4, 6, 22, 21], fill=C("P13")); d.rectangle([6, 8, 18, 18], fill=C("P02"))
    for x in range(7, 18):
        d.point((x, 13 + int(3 * math.sin(x * 0.9))), fill=C("P56"))
    d.rectangle([26, 15, 42, 21], fill=C("P29")); d.line([26, 15, 42, 15], fill=C("P31"))   # 회로판
    for x in (28, 32, 36, 40):
        d.point((x, 18), fill=C("P49"))
    d.line([45, 21, 54, 13], fill=C("P05")); d.point((54, 12), fill=C("P53"))             # 인두
    d.rectangle([48, 16, 62, 21], fill=C("P18"))
    for x in (50, 54, 58):
        d.ellipse([x, 13, x + 3, 17], fill=C("P15"))
    d.line([60, 21, 60, 2], fill=C("P05")); d.line([60, 2, 52, 0], fill=C("P05")); d.polygon([(47, 0), (55, 0), (53, 5), (49, 5)], fill=C("P45"))
    return im


def ceiling_slab(seed=0):
    """무너진 천장 판(2×1 발, 그림 2×2): 기울어진 콘크리트 판(윗면 밝게 · 깨진 테) + 끝에서 휘어 나온 짧은 철근 + 부스러기."""
    rnd = random.Random(seed)
    im = img(66, 50)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 32), (40, 18), (63, 30), (60, 48), (6, 48)], fill=C("P04"))
    d.polygon([(2, 32), (40, 18), (63, 30), (24, 42)], fill=C("P07"))
    d.line([2, 32, 40, 18], fill=C("P09")); d.line([24, 42, 63, 30], fill=C("P05"))
    for k in range(5):                                                 # 깨진 테의 이 빠진 자리
        x = 6 + k * 8
        d.polygon([(x, 31 - k * 3), (x + 3, 29 - k * 3), (x + 5, 31 - k * 3)], fill=C("P05"))
    for k in range(4):                                                 # 판 끝에서 휘어 나온 철근(짧게, 끝이 꺾임)
        x0, y0 = 42 + k * 5, 20 + k * 3
        x1, y1 = x0 + rnd.randint(2, 5), y0 - rnd.randint(5, 9)
        d.line([x0, y0, x1, y1], fill=C("P24"))
        d.line([x1, y1, x1 + rnd.choice([-3, 3]), y1 - 2], fill=C("P25"))
    for k in range(3):                                                 # 금
        x = 12 + k * 14
        d.line([x, 34 - k * 4, x + 4, 38 - k * 4], fill=C("P05"))
    for _ in range(14):
        x, y = rnd.randint(2, 62), rnd.randint(42, 48)
        d.rectangle([x, y, x + rnd.randint(1, 3), y + 1], fill=C(rnd.choice(["P05", "P06", "P07"])))
    return im


def drain_valve():
    """배수 밸브(1×1): 바닥에서 올라온 굵은 관 + 붉은 핸들 바퀴. 물을 채우면 배수구가 잠긴다(J-10)."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([11, 18, 20, 42], fill=C("P12")); d.line([11, 18, 11, 42], fill=C("P14")); d.line([20, 18, 20, 42], fill=C(INK))
    d.rectangle([8, 36, 23, 42], fill=C("P11"))
    d.ellipse([3, 4, 28, 20], outline=C("P53"), width=3)
    d.line([15, 6, 15, 18], fill=C("P53"), width=2); d.line([5, 12, 26, 12], fill=C("P53"), width=2)
    d.ellipse([12, 9, 19, 15], fill=C("P52"))
    d.line([6, 7, 12, 5], fill=C("P54"))
    return im


def ghoul_nest(seed=0):
    """야생 구울 둥지(deco): 누더기 · 신문지 · 뼈 · 깨진 깡통 더미."""
    rnd = random.Random(seed)
    im = img(46, 26)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 8, 44, 25], fill=C("P17"))
    for _ in range(18):
        x, y = rnd.randint(4, 40), rnd.randint(10, 22)
        d.rectangle([x, y, x + rnd.randint(2, 6), y + rnd.randint(1, 3)], fill=C(rnd.choice(["P18", "P05", "P30", "P08", "P24"])))
    for _ in range(3):
        x, y = rnd.randint(6, 36), rnd.randint(11, 20)
        d.line([x, y, x + 6, y + 2], fill=C("P09")); d.point((x, y - 1), fill=C("P09")); d.point((x + 6, y + 3), fill=C("P09"))
    return im


def stairs_up():
    """위로 오르는 계단(3×2, deco): 인조석 계단 단 · 양쪽 놋쇠 손잡이 · 위는 어둠(지상)."""
    im = img(96, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 63], fill=C("P02"))
    for i in range(8):
        y = 63 - i * 8
        shade = ["P08", "P07", "P07", "P06", "P06", "P05", "P04", "P03"][i]
        d.rectangle([4, y - 7, 91, y], fill=C(shade)); d.line([4, y - 7, 91, y - 7], fill=C("P09" if i < 3 else "P07"))
        d.line([4, y, 91, y], fill=C(INK))
    for x in (2, 92):
        d.line([x, 0, x, 63], fill=C("P58")); d.line([x + 1, 0, x + 1, 63], fill=C("P49"))
    return im


def sentry_down(lit=False):
    """넘어진 '파수-3' 경비 로봇(2×1, MQ-102 봉천 잠든 로봇 · SQ-S04에서 일어선다): robot_sentry의 누운 그림과 같은 몸
    (이족 · 크림 캡슐 · 관제망 휘장 · 떨어진 청록 방패 · CRT 얼굴판). lit이면 화면에 앰버 얼굴이 켜진다."""
    import robot_sentry as RS
    body = RS.sentry_death(3, lit)
    bb = body.getbbox()
    part = body.crop(bb)
    im = img(70, 40)
    im.alpha_composite(part, ((70 - part.width) // 2, 40 - part.height))
    return im


def remains(seed=0):
    """길 위 유해(1×1, 1-4 발견물): 벽에 기대 쓰러진 사람 — 바랜 외투 · 해골 머리 · 뻗은 다리 · 옆에 배낭. 피는 오래돼 검다."""
    rnd = random.Random(seed)
    im = img(40, 26)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 16, 38, 25], fill=C("P02"))                          # 바닥 얼룩(오래된 피·물때)
    coat = rnd.choice(["P18", "P29", "P44", "P05"])
    d.polygon([(8, 8), (22, 6), (26, 18), (6, 20)], fill=C(coat))       # 몸통(외투)
    d.line([8, 8, 22, 6], fill=C("P09") if coat == "P05" else C("P20"))
    d.line([24, 16, 36, 20], fill=C("P17"), width=3); d.line([22, 18, 34, 23], fill=C("P17"), width=3)   # 다리
    d.rectangle([34, 18, 37, 21], fill=C("P02")); d.rectangle([32, 21, 35, 24], fill=C("P02"))           # 신발
    d.ellipse([2, 2, 12, 11], fill=C("P08")); d.point((5, 6), fill=C("P02")); d.point((8, 6), fill=C("P02"))   # 해골
    d.line([5, 9, 9, 9], fill=C("P05"))
    d.rectangle([14, 15, 22, 22], fill=C("P30")); d.line([14, 15, 22, 15], fill=C("P31"))                 # 배낭
    return im


def subway_stairs(sign="지하상가"):
    """지상에서 지하로 내려가는 계단 입구(2×1 발, 월드 문 1-4): 뒤(북쪽) 낮은 벽 + 청록 안내판, 앞은 아래로 깊어지는 계단(북쪽일수록 어둡다),
    양옆 쇠 난간. 발 칸 두 개가 곧 출구 칸이다(밟으면 내려간다)."""
    im = img(64, 46)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 8, 63, 17], fill=C("P05")); d.line([0, 8, 63, 8], fill=C("P07")); d.line([0, 17, 63, 17], fill=C(INK))   # 뒤 벽
    d.rectangle([14, 0, 49, 10], fill=C("P61")); d.line([14, 0, 49, 0], fill=C("P62")); d.line([14, 10, 49, 10], fill=C(INK))
    put_text(im, sign, 17, 1, "P09", size=8)
    for i in range(7):                                                  # 계단(아래 = 남쪽이 지면, 위로 갈수록 깊다)
        y = 45 - i * 4
        col = ["P07", "P06", "P06", "P05", "P04", "P03", "P02"][i]
        d.rectangle([5, y - 3, 58, y], fill=C(col)); d.line([5, y - 3, 58, y - 3], fill=C("P08" if i < 3 else "P05"))
    d.rectangle([5, 18, 58, 20], fill=C("P01"))
    for x in (1, 59):                                                   # 난간
        d.rectangle([x, 16, x + 3, 45], fill=C("P12")); d.line([x, 16, x, 45], fill=C("P14")); d.line([x + 3, 16, x + 3, 45], fill=C(INK))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_JM = {
    "w_shop_clothes": _r(lambda: shutter("clothes", "open", 1), 2, 0, "wall", dx=0, dy=2),
    "w_shop_parts": _r(lambda: shutter("parts", "open", 2), 2, 0, "wall", dx=0, dy=2),
    "w_shop_meds": _r(lambda: shutter("meds", "open", 3), 2, 0, "wall", dx=0, dy=2),
    "w_shop_food": _r(lambda: shutter("food", "half", 4), 2, 0, "wall", dx=0, dy=2),
    "w_shop_water": _r(lambda: shutter("water", "half", 5), 2, 0, "wall", dx=0, dy=2),
    "w_shop_forge": _r(lambda: shutter("forge", "half", 6), 2, 0, "wall", dx=0, dy=2),
    "w_shop_repair": _r(lambda: shutter("repair", "shut", 7), 2, 0, "wall", dx=0, dy=2),
    "w_shutter": _r(lambda: shutter("blank1", "shut", 8), 2, 0, "wall", dx=0, dy=2),
    "w_shutter2": _r(lambda: shutter("blank2", "shut", 9), 2, 0, "wall", dx=0, dy=2),
    "w_shutter3": _r(lambda: shutter("blank3", "half", 10), 2, 0, "wall", dx=0, dy=2),
    "w_sign_market": _r(w_sign_market, 3, 0, "wall", dx=1, dy=4),
    "w_sign_welcome": _r(w_sign_welcome, 2, 0, "wall", dx=4, dy=10),
    "w_sign_plaza": _r(lambda: w_sign_dir("중앙 광장 →"), 2, 0, "wall", dx=2, dy=8),
    "w_sign_exit": _r(lambda: w_sign_dir("← 북쪽 출구"), 2, 0, "wall", dx=2, dy=8),
    "w_sign_south": _r(lambda: w_sign_dir("남쪽 통로 →"), 2, 0, "wall", dx=2, dy=8),
    "w_board_jm": _r(w_board_jm, 2, 0, "wall", dx=2, dy=8),
    "w_cold_door": _r(w_cold_door, 2, 0, "wall", dx=6, dy=4),
    "w_shutter_big": _r(w_shutter_big, 3, 0, "wall", dx=0, dy=2),
    "toll_table": _r(toll_table, 2, 1, down=-2),
    "stall_clothes": _r(lambda: stall("clothes", 1), 2, 1, down=-2),
    "stall_parts": _r(lambda: stall("parts", 2), 2, 1, down=-2),
    "stall_meds": _r(lambda: stall("meds", 3), 2, 1, down=-2),
    "stall_food": _r(lambda: stall("food", 4), 2, 1, down=-2),
    "stall_water": _r(lambda: stall("water", 5), 2, 1, down=-2),
    "stall_forge": _r(lambda: stall("forge", 6), 2, 1, down=-2),
    "fountain_dry": _r(fountain_dry, 3, 2, down=-2),
    "switchboard": _r(switchboard, 2, 1, down=-2),
    "workbench": _r(workbench, 2, 1, down=-2),
    "ceiling_slab": _r(lambda: ceiling_slab(1), 2, 1, down=-2),
    "ceiling_slab2": _r(lambda: ceiling_slab(2), 2, 1, down=-2),
    "drain_valve": _r(drain_valve, 1, 1, down=-2),
    "ghoul_nest": _r(lambda: ghoul_nest(1), 0, 0, "deco"),
    "ghoul_nest2": _r(lambda: ghoul_nest(2), 0, 0, "deco"),
    "stairs_up": _r(stairs_up, 0, 0, "deco"),
    "sentry_down": _r(sentry_down, 2, 1, down=-2),
    "subway_stairs": _r(subway_stairs, 2, 1, down=2),
    "remains": _r(lambda: remains(1), 1, 1, down=-2),
    "remains2": _r(lambda: remains(2), 1, 1, down=-2),
    "subway_stairs_st": _r(lambda: subway_stairs("구청역"), 2, 1, down=2),
    "subway_stairs_mall": _r(lambda: subway_stairs("역사 지하"), 2, 1, down=2),
}
STATES_JM = {"sentry_down": {"lit": lambda: sentry_down(True)}, "w_shutter_big": {"open": w_shutter_big_open}}
