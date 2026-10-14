"""봉천 실내 소품(단계 0-10c, SD-16 §7·§8 아이작풍): 옥탑 이장실 B-01 · 빌린 침대 방 · 하숙자 약국 B-03.
볼트 소품(철제·형광 녹색)과 달리 2277년 봉천 살림은 나무·장판·양은·천: 자개장롱, 밥상과 양은 주전자, 방석, 석유난로,
진공관 무전기(감시조 연락), 손으로 그린 마을 지도, 약국의 유리 진열대·약병 선반·야전 침대·링거대.
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01). 벽 소품(kind wall)은 벽면 윗칸(y=1)에 건다.
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import tiles_isaac as TI
from struct_r01 import put_text

T = 32
C = lambda t: P.rgb(t) + (255,)
INK = "P01"
WOOD_D = ["P16", "P17", "P18", "P19"]
WOOD = ["P18", "P19", "P20", "P21"]
BRASS = ["P47", "P48", "P49", "P50"]


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def box3(d, x0, y0, x1, y1, top_h, ramp, edge=True):
    """3/4 시점 상자: 윗면(밝게, 높이 top_h) + 앞면(어둡게). ramp 어두움→밝음 4단."""
    d.rectangle([x0, y0 + top_h, x1, y1], fill=C(ramp[1]))
    d.rectangle([x0, y0, x1, y0 + top_h], fill=C(ramp[2]))
    if edge:
        d.line([x0, y0, x1, y0], fill=C(ramp[3]))                         # 윗면 앞 모서리 빛
        d.line([x0, y0 + top_h, x1, y0 + top_h], fill=C(ramp[0]))
        d.line([x0, y0 + top_h + 1, x0, y1], fill=C(ramp[2]))             # 왼쪽 빛 받는 모서리
        d.line([x1, y0 + top_h + 1, x1, y1], fill=C(ramp[0]))


def grain(d, x0, y0, x1, y1, col, step=4, seed=0):
    rnd = random.Random(seed)
    for y in range(y0, y1, step):
        xa = x0 + rnd.randint(0, 6)
        d.line([xa, y, min(x1, xa + rnd.randint(8, 20)), y], fill=C(col))


# ================================================================================================ 이장실
def wardrobe():
    """자개장롱(2×1): 검은 옻칠 몸통 + 문 넷 + 자개 학·구름 무늬(청록 점) + 놋쇠 경첩·고리. 200년 된 혼수품."""
    im = img(62, 74)
    d = ImageDraw.Draw(im)
    box3(d, 1, 2, 60, 70, 5, ["P01", "P02", "P03", "P04"])
    d.rectangle([3, 70, 6, 73], fill=C("P02")); d.rectangle([55, 70, 58, 73], fill=C("P02"))   # 다리
    for k in range(4):                                                    # 문 넷
        x0 = 3 + k * 14
        d.rectangle([x0, 10, x0 + 12, 66], outline=C("P04"))
        d.line([x0 + 1, 11, x0 + 1, 65], fill=C("P03"))
    rnd = random.Random(7)
    for k in range(4):                                                    # 자개: 구름 + 학(문마다 다르게)
        x0 = 3 + k * 14
        for _ in range(9):
            x, y = x0 + rnd.randint(3, 9), rnd.randint(14, 60)
            d.point((x, y), fill=C(rnd.choice(["P37", "P63", "P36", "P15"])))
        cy = 24 + (k % 2) * 16
        d.arc([x0 + 2, cy, x0 + 10, cy + 6], 180, 360, fill=C("P37"))
        d.line([x0 + 6, cy + 3, x0 + 8, cy - 3], fill=C("P15"))           # 학 목
        d.point((x0 + 9, cy - 4), fill=C("P53"))                          # 학 머리 붉은 점
    for x in (16, 44):                                                    # 놋쇠 고리
        d.ellipse([x - 2, 36, x + 2, 40], outline=C("P48"))
        d.point((x - 1, 37), fill=C("P50"))
    for k in range(4):
        for y in (14, 60):
            d.rectangle([3 + k * 14 + (0 if k % 2 == 0 else 10), y, 3 + k * 14 + (2 if k % 2 == 0 else 12), y + 2], fill=C("P48"))
    d.rectangle([20, 0, 34, 2], fill=C("P21"))                            # 위에 얹은 이불 보따리
    d.rectangle([18, -1 + 1, 36, 2], fill=C("P26"))
    return im


def low_table():
    """밥상(2×1): 둥근 모서리 소반 + 양은 주전자 + 찻잔 둘 + 접힌 '봉천 소식' 쪽지."""
    im = img(62, 34)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([2, 8, 59, 22], 5, fill=C("P20"))                 # 상판 윗면
    d.rounded_rectangle([2, 8, 59, 20], 5, fill=C("P21"))
    d.line([6, 8, 55, 8], fill=C("P22"))
    d.rectangle([3, 20, 58, 25], fill=C("P18"))                           # 상판 두께(앞)
    d.line([3, 25, 58, 25], fill=C("P17"))
    for x in (6, 52):                                                     # 다리
        d.rectangle([x, 26, x + 3, 32], fill=C("P17"))
    grain(d, 6, 11, 54, 19, "P20", 3, 2)
    # 양은 주전자
    TI.lump(im, 20, 10, 8, 6, BRASS, 0.55)
    d.rectangle([17, 2, 23, 5], fill=C("P48")); d.point((20, 1), fill=C("P49"))   # 뚜껑 꼭지
    d.line([27, 9, 32, 5], fill=C("P48"), width=2)                        # 주둥이
    d.arc([12, 1, 28, 13], 200, 340, fill=C("P47"))                       # 손잡이
    for x in (38, 46):                                                    # 찻잔
        d.rectangle([x, 9, x + 4, 14], fill=C("P09")); d.line([x, 9, x + 4, 9], fill=C("P08"))
        d.point((x + 2, 10), fill=C("P31"))
    d.polygon([(48, 15), (57, 13), (58, 18), (49, 19)], fill=C("P08"))   # 쪽지
    d.line([50, 16, 56, 15], fill=C("P05"))
    return im


def cushion(col="r"):
    """방석(장식, 막지 않음): 누빈 천 + 가운데 매듭."""
    ramp = {"r": ["P52", "P53", "P54", "P27"], "b": ["P43", "P44", "P45", "P46"], "y": ["P47", "P48", "P49", "P50"]}[col]
    im = img(26, 18)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([1, 3, 24, 16], 4, fill=C(ramp[1]))
    d.rounded_rectangle([1, 3, 24, 13], 4, fill=C(ramp[2]))
    d.line([5, 3, 20, 3], fill=C(ramp[3]))
    for x in (8, 17):
        d.line([x, 5, x, 12], fill=C(ramp[1]))
    d.line([3, 8, 22, 8], fill=C(ramp[1]))
    d.ellipse([11, 6, 14, 9], fill=C(ramp[0]))
    return im


def chief_desk():
    """이장 책상(2×1): 나무 책상 + 유리 밑 구청 지도(2077) + 장부·도장·인주 + 꺼진 스탠드 + 깡통 필통."""
    im = img(62, 48)
    d = ImageDraw.Draw(im)
    box3(d, 1, 14, 60, 44, 12, WOOD)
    d.rectangle([3, 45, 6, 47], fill=C("P17")); d.rectangle([55, 45, 58, 47], fill=C("P17"))
    d.rectangle([5, 15, 40, 25], fill=C("P15"))                           # 유리 밑 지도
    d.rectangle([6, 16, 39, 24], fill=C("P09"))
    for x, y, x2, y2 in ((8, 18, 20, 22), (14, 17, 30, 23), (24, 19, 37, 18)):
        d.line([x, y, x2, y2], fill=C("P13"))
    d.line([18, 16, 22, 24], fill=C("P46"))                               # 도림천 물길
    d.point((26, 20), fill=C("P53")); d.point((27, 20), fill=C("P53"))   # 봉천 표시
    d.line([5, 15, 12, 15], fill=C("P09"))                                # 유리 반사
    d.rectangle([43, 15, 53, 23], fill=C("P26")); d.line([43, 15, 53, 15], fill=C("P27"))   # 장부
    d.line([48, 16, 48, 23], fill=C("P24"))
    d.rectangle([55, 17, 57, 22], fill=C("P18")); d.rectangle([55, 22, 57, 23], fill=C("P53"))   # 도장
    for x0 in (4, 32):                                                    # 서랍
        d.rectangle([x0, 30, x0 + 24, 40], outline=C("P18"))
        d.rectangle([x0 + 10, 34, x0 + 14, 35], fill=C("P48"))
    d.line([10, 14, 10, 4], fill=C("P05"))                                # 스탠드(꺼짐)
    d.line([10, 4, 16, 2], fill=C("P05"))
    d.polygon([(13, 1), (21, 0), (22, 6), (14, 7)], fill=C("P35"))
    d.rectangle([24, 6, 29, 14], fill=C("P07")); d.line([24, 6, 29, 6], fill=C("P09"))   # 깡통 필통
    for x, c in ((25, "P53"), (27, "P45"), (28, "P20")):
        d.line([x, 6, x, 2], fill=C(c))
    return im


def radio_desk():
    """감시조 무전기(1×1): 작은 상 위 진공관 송수신기(호박색 눈금 불) + 손 마이크 + 천장으로 가는 안테나 줄."""
    im = img(32, 52)
    d = ImageDraw.Draw(im)
    box3(d, 1, 30, 30, 48, 6, WOOD)
    d.rectangle([3, 49, 5, 51], fill=C("P17")); d.rectangle([26, 49, 28, 51], fill=C("P17"))
    box3(d, 3, 12, 27, 32, 4, ["P10", "P11", "P12", "P13"])               # 무전기 몸
    d.rectangle([5, 18, 18, 24], fill=C("P58"))                           # 눈금창
    d.rectangle([6, 19, 17, 23], fill=C("P60"))
    for x in range(7, 17, 2):
        d.point((x, 20), fill=C("P58"))
    d.line([12, 19, 13, 23], fill=C("P53"))                               # 바늘
    for x in (21, 25):                                                    # 손잡이 둘
        d.ellipse([x - 2, 19, x + 2, 23], fill=C("P04")); d.point((x - 1, 20), fill=C("P07"))
    d.rectangle([5, 26, 25, 29], fill=C("P11"))
    for x in range(6, 25, 3):
        d.point((x, 27), fill=C("P14"))
    d.line([25, 12, 29, 0], fill=C("P05"))                                # 안테나 줄
    d.ellipse([14, 32, 20, 37], fill=C("P02"))                            # 손 마이크
    d.line([17, 32, 22, 29], fill=C("P02"))
    return im


def crt_tv():
    """2077 원자력 텔레비전(1×1, 전원 없음): 둥근 나무 상자 + 볼록 브라운관(회색 반사) + 다이얼 + 낮은 장."""
    im = img(32, 46)
    d = ImageDraw.Draw(im)
    box3(d, 1, 28, 30, 44, 5, WOOD_D)
    d.rectangle([4, 34, 15, 41], outline=C("P16")); d.rectangle([17, 34, 27, 41], outline=C("P16"))
    d.rounded_rectangle([3, 4, 28, 29], 6, fill=C("P19"))
    d.rounded_rectangle([3, 4, 28, 27], 6, fill=C("P20"))
    d.line([8, 4, 23, 4], fill=C("P21"))
    d.rounded_rectangle([5, 7, 21, 24], 5, fill=C("P03"))                 # 브라운관
    d.rounded_rectangle([6, 8, 20, 23], 5, fill=C("P11"))
    d.line([8, 10, 11, 9], fill=C("P14")); d.point((8, 11), fill=C("P13"))   # 반사
    for y in (11, 17):
        d.ellipse([22, y, 26, y + 4], fill=C("P17")); d.point((23, y + 1), fill=C("P48"))
    d.line([10, 4, 6, 0], fill=C("P05")); d.line([20, 4, 24, 0], fill=C("P05"))   # 토끼 귀 안테나
    return im


def heater():
    """석유난로(1×1): 둥근 원통 + 둘레 철망 + 위 양은 주전자. 꺼져 있다(기름 아낌)."""
    im = img(30, 44)
    d = ImageDraw.Draw(im)
    ramp = ["P04", "P05", "P06", "P07"]
    for x in range(4, 26):
        nx = (x - 15) / 11
        d.line([x, 16, x, 40], fill=C(ramp[3] if nx < -0.5 else ramp[2] if nx < 0.1 else ramp[1] if nx < 0.7 else ramp[0]))
    d.ellipse([4, 12, 25, 20], fill=C("P06")); d.ellipse([7, 13, 22, 19], fill=C("P03"))
    for x in range(6, 25, 3):                                             # 철망
        d.line([x, 21, x, 34], fill=C("P03"))
    d.rectangle([5, 34, 24, 40], fill=C("P53")); d.line([5, 34, 24, 34], fill=C("P54"))   # 기름통 띠
    d.rectangle([12, 36, 17, 38], fill=C("P09"))
    TI.lump(im, 15, 9, 6, 5, BRASS, 0.55)                                 # 주전자
    d.rectangle([13, 2, 17, 4], fill=C("P48"))
    d.line([21, 8, 25, 5], fill=C("P48"))
    return im


def shoe_rack():
    """신발장(1×1): 낮은 나무 칸 + 고무신·운동화·장화."""
    im = img(32, 30)
    d = ImageDraw.Draw(im)
    box3(d, 1, 6, 30, 28, 3, WOOD)
    d.line([2, 17, 29, 17], fill=C("P17"))
    for x, y, c in ((4, 12, "P09"), (12, 12, "P46"), (20, 11, "P02"), (5, 23, "P31"), (15, 23, "P53")):
        d.rounded_rectangle([x, y, x + 7, y + 4], 2, fill=C(c))
        d.line([x + 1, y, x + 5, y], fill=C("P08" if c != "P09" else "P07"))
    return im


def dresser():
    """서랍장(1×1): 서랍 셋 + 위에 탁상시계·액자(사진: 볼트 이전 가족)·빗."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    box3(d, 1, 16, 30, 42, 4, WOOD)
    for k in range(3):
        y = 22 + k * 7
        d.rectangle([3, y, 28, y + 5], outline=C("P18"))
        d.rectangle([13, y + 2, 18, y + 3], fill=C("P48"))
    d.ellipse([4, 6, 12, 15], fill=C("P53")); d.ellipse([5, 7, 11, 14], fill=C("P09"))   # 탁상시계
    d.line([8, 10, 8, 8], fill=C("P01")); d.line([8, 10, 10, 11], fill=C("P01"))
    d.rectangle([16, 4, 26, 16], fill=C("P48"))                           # 액자
    d.rectangle([17, 5, 25, 15], fill=C("P08"))
    for x, c in ((19, "P41"), (23, "P40")):
        d.ellipse([x - 2, 7, x + 1, 10], fill=C(c))
        d.rectangle([x - 2, 11, x + 1, 15], fill=C("P13"))
    return im


def plant_pot():
    """고무나무 화분(1×1): 깨진 김치 항아리에 심은 고무나무."""
    im = img(30, 50)
    d = ImageDraw.Draw(im)
    TI.lump(im, 15, 40, 10, 8, ["P23", "P24", "P25", "P26"], 0.5)        # 항아리
    d.ellipse([7, 30, 23, 36], fill=C("P24")); d.ellipse([9, 31, 21, 35], fill=C("P17"))
    d.line([15, 33, 15, 14], fill=C("P18"), width=2)
    rnd = random.Random(3)
    for k, (x, y) in enumerate(((8, 24), (22, 22), (10, 14), (20, 12), (15, 5), (6, 16), (24, 17))):
        TI.lump(im, x, y, 5, 3 + (k % 2), ["P28", "P29", "P30", "P31"], 0.6)
        d.line([x - 2, y, x + 2, y], fill=C("P28"))
    return im


def yo_bed():
    """빌린 침대(1×2, 발 = 두 칸 세로): 장판 위 요 + 꽃무늬 이불 + 메밀 베개. 볼트 침대보다 낮고 넓다."""
    im = img(34, 64)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([1, 4, 32, 62], 3, fill=C("P08"))                 # 요
    d.rounded_rectangle([1, 4, 32, 59], 3, fill=C("P09"))
    d.rounded_rectangle([4, 6, 29, 15], 4, fill=C("P21"))                 # 메밀 베개
    d.line([7, 7, 26, 7], fill=C("P22"))
    for x in range(7, 27, 3):
        d.point((x, 11), fill=C("P19"))
    d.rounded_rectangle([1, 20, 32, 60], 3, fill=C("P52"))                # 이불(앞면 그림자)
    d.rounded_rectangle([1, 18, 32, 57], 3, fill=C("P53"))
    d.line([3, 18, 30, 18], fill=C("P54"))
    d.rectangle([1, 18, 32, 22], fill=C("P09"))                           # 홑청 깃
    rnd = random.Random(5)
    for _ in range(9):                                                    # 꽃무늬
        x, y = rnd.randint(5, 28), rnd.randint(26, 53)
        for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
            d.point((x + dx, y + dy), fill=C("P27"))
        d.point((x, y), fill=C("P49"))
    return im


# ================================================================================================ 약국
def med_shelf():
    """약 선반(2×1): 나무 선반 3단 + 갈색 약병·흰 상자·주황 라드어웨이 봉지·관악산 약수병(파란 뚜껑)."""
    im = img(62, 66)
    d = ImageDraw.Draw(im)
    box3(d, 1, 2, 60, 62, 4, WOOD)
    d.rectangle([4, 8, 57, 60], fill=C("P17"))
    rnd = random.Random(11)
    for k, y in enumerate((24, 41, 58)):
        d.rectangle([3, y, 58, y + 2], fill=C("P20")); d.line([3, y, 58, y], fill=C("P21"))
        x = 5
        while x < 55:
            kind = rnd.choice(["bottle", "box", "bag", "water", "bottle"])
            h = {"bottle": 8, "box": 7, "bag": 10, "water": 12}[kind]
            w = {"bottle": 4, "box": 7, "bag": 6, "water": 5}[kind]
            if x + w > 56:
                break
            col = {"bottle": "P25", "box": "P09", "bag": "P27", "water": "P15"}[kind]
            d.rectangle([x, y - h, x + w - 1, y - 1], fill=C(col))
            d.line([x, y - h, x, y - 1], fill=C("P26" if kind == "bottle" else "P22" if kind == "bag" else "P08"))
            if kind == "bottle":
                d.rectangle([x + 1, y - h - 2, x + 2, y - h - 1], fill=C("P09"))
            elif kind == "water":
                d.rectangle([x + 1, y - h - 2, x + 3, y - h - 1], fill=C("P45"))
            elif kind == "box":
                d.line([x + 1, y - 4, x + w - 2, y - 4], fill=C("P53"))   # 붉은 십자 띠
            elif kind == "bag":
                d.point((x + 2, y - 6), fill=C("P49"))
            x += w + rnd.randint(1, 2)
    return im


def pharm_counter():
    """약국 계산대(2×1): 유리 진열장(스팀팩·붕대) + 나무 상판 + 캡 깡통 저울·약절구·장부. 손님 쪽이 아래."""
    im = img(62, 42)
    d = ImageDraw.Draw(im)
    box3(d, 1, 6, 60, 40, 7, WOOD)
    d.rectangle([4, 16, 57, 37], fill=C("P11"))                           # 유리 앞판
    d.rectangle([5, 17, 56, 36], fill=C("P12"))
    for x, c in ((8, "P53"), (16, "P09"), (24, "P53"), (34, "P08"), (44, "P27")):
        d.rectangle([x, 28, x + 5, 34], fill=C(c))
        d.line([x, 28, x + 5, 28], fill=C("P09" if c != "P09" else "P07"))
    d.line([6, 18, 14, 18], fill=C("P15")); d.line([6, 19, 9, 19], fill=C("P14"))   # 유리 반사
    d.line([6, 26, 55, 26], fill=C("P13"))                                # 진열 선반
    d.ellipse([6, 4, 14, 9], fill=C("P06")); d.ellipse([7, 4, 13, 7], fill=C("P02"))   # 캡 깡통
    for x in (8, 11):
        d.point((x, 5), fill=C("P48"))
    d.ellipse([24, 3, 32, 10], fill=C("P07")); d.ellipse([25, 3, 31, 6], fill=C("P05"))   # 약절구
    d.line([30, 5, 34, 0], fill=C("P08"), width=2)
    d.rectangle([42, 3, 54, 10], fill=C("P44")); d.line([42, 3, 54, 3], fill=C("P45"))   # 장부
    d.line([48, 4, 48, 10], fill=C("P43"))
    return im


def cot():
    """야전 침대(1×2): 녹색 캔버스 + X 다리 + 접힌 담요. 앓는 사람이 누웠던 자국."""
    im = img(34, 66)
    d = ImageDraw.Draw(im)
    for y in (12, 56):                                                    # X 다리(앞에서 보임)
        d.line([3, y, 9, y + 8], fill=C("P05")); d.line([30, y, 24, y + 8], fill=C("P05"))
    d.rectangle([3, 4, 30, 58], fill=C("P29"))                            # 캔버스
    d.rectangle([3, 4, 30, 55], fill=C("P30"))
    d.line([3, 4, 3, 58], fill=C("P05")); d.line([30, 4, 30, 58], fill=C("P04"))   # 틀(쇠파이프)
    d.line([5, 5, 28, 5], fill=C("P31"))
    d.ellipse([9, 18, 24, 40], fill=C("P29"))                             # 누웠던 자국
    d.rounded_rectangle([5, 42, 28, 54], 2, fill=C("P45"))                # 접힌 담요
    d.line([6, 46, 27, 46], fill=C("P44")); d.line([6, 42, 27, 42], fill=C("P46"))
    d.rounded_rectangle([7, 6, 26, 13], 3, fill=C("P09"))                 # 베개
    return im


def iv_stand():
    """링거대(1×1): 바퀴 다리 + 기둥 + 고리 + 라드어웨이 봉지(주황) + 줄."""
    im = img(26, 70)
    d = ImageDraw.Draw(im)
    d.line([13, 8, 13, 64], fill=C("P07")); d.line([14, 8, 14, 64], fill=C("P05"))
    for dx in (-9, -4, 4, 9):
        d.line([13, 64, 13 + dx, 68], fill=C("P05"))
        d.point((13 + dx, 68), fill=C("P02"))
    d.line([5, 8, 21, 8], fill=C("P07"))
    d.rounded_rectangle([3, 10, 11, 24], 2, fill=C("P27"))
    d.line([4, 11, 4, 22], fill=C("P42"))
    put_text(im, "R", 5, 13, "P09", 8, "Galmuri7")
    d.line([7, 24, 7, 36], fill=C("P15")); d.line([7, 36, 10, 46], fill=C("P15"))
    return im


def water_jug():
    """약수통(1×1): 받침대 위 파란 20리터 통(관악산 약수) + 꼭지 + 바가지."""
    im = img(30, 52)
    d = ImageDraw.Draw(im)
    box3(d, 3, 30, 26, 50, 4, WOOD)
    TI.lump(im, 15, 17, 10, 13, ["P43", "P44", "P45", "P46"], 0.6)
    d.rectangle([12, 2, 18, 5], fill=C("P44"))
    for y in (12, 22):
        d.line([7, y, 23, y], fill=C("P44"))
    d.rectangle([20, 32, 23, 35], fill=C("P05"))                          # 꼭지
    d.ellipse([5, 36, 13, 41], fill=C("P21")); d.line([12, 38, 17, 36], fill=C("P19"))   # 바가지
    return im


def stool():
    """둥근 나무 의자(장식 아님, 1×1): 손님 대기."""
    im = img(22, 26)
    d = ImageDraw.Draw(im)
    for x in (4, 16):
        d.line([x, 10, x - 1, 24], fill=C("P17"), width=2)
    d.line([10, 12, 10, 24], fill=C("P17"), width=2)
    d.ellipse([1, 4, 20, 13], fill=C("P19")); d.ellipse([1, 3, 20, 11], fill=C("P20"))
    d.arc([3, 4, 18, 10], 190, 300, fill=C("P21"))
    return im


# ================================================================================================ 벽
def w_calendar():
    """손으로 만든 2277년 달력: 10월, 지난 날짜에 붉은 X, 23일에 동그라미('볼트 문 열린 날' 소문)."""
    im = img(24, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 22, 29], fill=C("P09")); d.rectangle([1, 2, 22, 9], fill=C("P53"))
    put_text(im, "10월", 4, 2, "P09", 8, "Galmuri7")
    d.point((11, 0), fill=C("P05")); d.point((11, 1), fill=C("P05"))
    for k in range(25):
        x, y = 3 + (k % 7) * 3, 11 + (k // 7) * 4
        if k < 21:
            d.line([x, y, x + 1, y + 1], fill=C("P53")); d.line([x + 1, y, x, y + 1], fill=C("P53"))
        else:
            d.point((x, y), fill=C("P05"))
    d.ellipse([3 + 1 * 3 - 2, 11 + 3 * 4 - 2, 3 + 1 * 3 + 3, 11 + 3 * 4 + 3], outline=C("P44"))
    return im


def w_map():
    """손으로 그린 봉천 지도(골판지, 2칸): 312계단 지그재그 + 계단참 넷(숫자) + 물탱크 + 붉은 압정(감시 자리)."""
    im = img(62, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 60, 38], fill=C("P20")); d.rectangle([3, 3, 58, 36], fill=C("P21"))
    pts = [(30, 34), (30, 28), (16, 26), (16, 20), (36, 18), (36, 12), (22, 10), (22, 5)]
    d.line(pts, fill=C("P02"), width=1)
    for k, (x, y) in enumerate(pts[1::2]):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=C("P09"), outline=C("P02"))
    for x in (46, 50, 54):
        d.rectangle([x, 6, x + 2, 9], fill=C("P45"))                      # 물탱크
    for x, y in ((28, 36), (50, 30), (8, 16), (44, 8)):
        d.point((x, y), fill=C("P53")); d.point((x, y - 1), fill=C("P54"))
    put_text(im, "봉천", 38, 26, "P17", 8, "Galmuri7")
    d.line([3, 37, 58, 37], fill=C("P18"))
    for x in (2, 59):
        d.point((x, 2), fill=C("P07"))
    return im


def w_window():
    """창문(2칸): 테이프 X자 + 바깥 하늘(늦가을 오후) + 먼 아파트 실루엣 + 창틀 위 양파망."""
    im = img(62, 36)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 60, 34], fill=C("P18"))
    for x0 in (4, 32):
        d.rectangle([x0, 4, x0 + 25, 30], fill=C("P14"))
        d.rectangle([x0, 4, x0 + 25, 15], fill=C("P15"))
        for bx, bh in ((x0 + 2, 9), (x0 + 8, 13), (x0 + 15, 7), (x0 + 20, 11)):
            d.rectangle([bx, 30 - bh, bx + 4, 30], fill=C("P13"))
        d.line([x0, 4, x0 + 25, 30], fill=C("P21")); d.line([x0 + 25, 4, x0, 30], fill=C("P21"))
    d.rectangle([0, 31, 61, 35], fill=C("P19")); d.line([0, 31, 61, 31], fill=C("P21"))
    d.ellipse([46, 26, 56, 33], fill=C("P26"))                            # 양파망
    for x in range(48, 56, 2):
        d.line([x, 27, x, 32], fill=C("P24"))
    return im


def w_shelf():
    """벽 선반(2칸): 라디오(꺼짐)·간장병·사진 액자·양초."""
    im = img(62, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 22, 59, 25], fill=C("P19")); d.line([2, 22, 59, 22], fill=C("P21"))
    for x in (8, 52):
        d.polygon([(x, 25), (x + 3, 25), (x + 3, 29)], fill=C("P18"))
    d.rounded_rectangle([5, 8, 25, 21], 3, fill=C("P26")); d.rectangle([8, 11, 17, 18], fill=C("P21"))
    for y in range(12, 18, 2):
        d.line([9, y, 16, y], fill=C("P19"))
    d.ellipse([19, 12, 23, 16], fill=C("P48"))
    d.rectangle([30, 10, 34, 21], fill=C("P02")); d.rectangle([31, 7, 33, 10], fill=C("P53"))
    d.rectangle([38, 9, 47, 21], fill=C("P48")); d.rectangle([39, 10, 46, 20], fill=C("P07"))
    d.ellipse([41, 12, 44, 15], fill=C("P41")); d.rectangle([40, 16, 45, 20], fill=C("P46"))
    d.rectangle([52, 14, 55, 21], fill=C("P09")); d.point((53, 13), fill=C("P49"))
    return im


def w_poster_rad():
    """약국 벽보: '물은 끓여 드세요 / 라드 숫자는 약사에게' + 방사능 표지."""
    im = img(30, 36)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 28, 34], fill=C("P09")); d.rectangle([1, 1, 28, 34], outline=C("P07"))
    d.ellipse([8, 4, 21, 17], fill=C("P49"))
    for a0 in (30, 150, 270):
        d.pieslice([9, 5, 20, 16], a0, a0 + 60, fill=C("P01"))
    d.ellipse([13, 9, 16, 12], fill=C("P01"))
    put_text(im, "물은", 7, 17, "P53", 8, "Galmuri7")
    put_text(im, "끓여", 7, 25, "P53", 8, "Galmuri7")
    d.point((14, 0), fill=C("P53"))
    return im


def w_herbs():
    """말린 약초 줄(2칸): 쑥·익모초 다발이 거꾸로 매달려 있다."""
    im = img(62, 30)
    d = ImageDraw.Draw(im)
    d.line([1, 3, 60, 5], fill=C("P18"))
    rnd = random.Random(9)
    for x in range(6, 58, 9):
        y0 = 4
        d.line([x, y0, x, y0 + 4], fill=C("P21"))
        ramp = rnd.choice([["P29", "P30", "P31", "P32"], ["P30", "P31", "P32", "P32"], ["P18", "P19", "P30", "P31"]])
        for k in range(5):
            dx = k - 2
            d.line([x, y0 + 4, x + dx * 2, y0 + 16 + rnd.randint(0, 6)], fill=C(ramp[k % 3]))
        d.rectangle([x - 1, y0 + 3, x + 1, y0 + 5], fill=C("P53"))
    return im


def w_cross():
    """약국 녹십자 간판(실내 쪽): 녹색 십자 + '약'."""
    im = img(26, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 24, 28], fill=C("P09")); d.rectangle([1, 1, 24, 28], outline=C("P55"))
    d.rectangle([10, 4, 15, 18], fill=C("P55")); d.rectangle([5, 9, 20, 13], fill=C("P55"))
    d.line([10, 4, 15, 4], fill=C("P56"))
    put_text(im, "약", 8, 18, "P02", 8, "Galmuri7")
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_IN = {
    "wardrobe": _r(wardrobe, 2, 1, down=-2),
    "low_table": _r(low_table, 2, 1, down=-2),
    "cushion_r": _r(lambda: cushion("r"), 0, 0, "deco"),
    "cushion_b": _r(lambda: cushion("b"), 0, 0, "deco"),
    "cushion_y": _r(lambda: cushion("y"), 0, 0, "deco"),
    "chief_desk": _r(chief_desk, 2, 1, down=-2),
    "radio_desk": _r(radio_desk, 1, 1, down=-2),
    "crt_tv": _r(crt_tv, 1, 1, down=-2),
    "heater": _r(heater, 1, 1, down=-2),
    "shoe_rack": _r(shoe_rack, 1, 1, down=-2),
    "dresser": _r(dresser, 1, 1, down=-2),
    "plant_pot": _r(plant_pot, 1, 1, down=-2),
    "yo_bed": _r(yo_bed, 1, 2, down=-2),
    "med_shelf": _r(med_shelf, 2, 1, down=-2),
    "pharm_counter": _r(pharm_counter, 2, 1, down=-2),
    "cot": _r(cot, 1, 2, down=-2),
    "iv_pole": _r(iv_stand, 1, 1, down=-2),
    "water_jug": _r(water_jug, 1, 1, down=-2),
    "stool_w": _r(stool, 1, 1, down=-2),
    "w_calendar": _r(w_calendar, 1, 0, "wall", dx=4, dy=14),
    "w_map": _r(w_map, 2, 0, "wall", dx=1, dy=8),
    "w_window": _r(w_window, 2, 0, "wall", dx=1, dy=6),
    "w_shelf": _r(w_shelf, 2, 0, "wall", dx=1, dy=14),
    "w_poster_rad": _r(w_poster_rad, 1, 0, "wall", dx=1, dy=10),
    "w_herbs": _r(w_herbs, 2, 0, "wall", dx=1, dy=8),
    "w_cross": _r(w_cross, 1, 0, "wall", dx=3, dy=10),
}
