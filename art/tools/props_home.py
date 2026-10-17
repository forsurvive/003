"""들어가 보는 건물 실내 소품(단계 1-5e 자유 탐험 확장, SD-16 §7·§8 아이작풍): 2077년 서울의 보통 살림과 가게.
빌라·단독주택(부엌·욕실·거실·아이 방) · 동네 가게(구멍가게·약국·철물점·세탁소) · 주민센터 민원실 · 아파트 현관 · 창고.
200년 묵어 먼지·녹·얼룩이 앉았다. 볼트(철제·형광)와 봉천(나무·양은)과 달리 2077년 가전은 둥근 모서리 + 크림·민트·적갈 법랑.
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01). 벽 소품(kind wall)은 벽면 윗칸(y=1)에 건다.
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from props_bc_in import box3, grain, WOOD, WOOD_D, BRASS

C = lambda t: P.rgb(t) + (255,)
CREAM = ["P06", "P07", "P08", "P09"]
MINT = ["P34", "P35", "P36", "P37"]
STEEL = ["P04", "P05", "P06", "P07"]
SLATE = ["P11", "P12", "P13", "P14"]
RUST = ["P24", "P25", "P26", "P27"]


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def shadow(d, x0, x1, y):
    d.ellipse([x0, y - 2, x1, y + 2], fill=C("P02"))


def dust(d, rnd, x0, y0, x1, y1, n=6, col="P06"):
    for _ in range(n):
        d.point((rnd.randint(x0, x1), rnd.randint(y0, y1)), fill=C(col))


# ================================================================================================ 부엌·욕실
def fridge():
    """냉장고(1×1, 2077 둥근 법랑): 민트 몸통 · 크롬 손잡이 · 위아래 문 · 붙은 자석 메모 · 문틈 녹. 찬장 용기."""
    im = img(30, 56)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 28, 53)
    d.rounded_rectangle([2, 2, 27, 52], 6, fill=C("P35"))
    d.rounded_rectangle([3, 2, 27, 50], 6, fill=C("P36"))
    d.line([7, 2, 22, 2], fill=C("P37"))
    d.line([3, 6, 3, 46], fill=C("P37"))
    d.line([4, 18, 26, 18], fill=C("P34"))                                # 위 칸·아래 칸 이음
    for y0, y1 in ((8, 15), (24, 38)):                                    # 크롬 손잡이
        d.rectangle([22, y0, 24, y1], fill=C("P07")); d.line([22, y0, 22, y1], fill=C("P09"))
    d.rectangle([7, 25, 13, 31], fill=C("P09")); d.line([8, 27, 12, 27], fill=C("P05")); d.line([8, 29, 11, 29], fill=C("P05"))  # 메모
    d.ellipse([9, 23, 11, 25], fill=C("P54"))                             # 자석
    d.rectangle([8, 41, 18, 43], fill=C("P48")); d.line([9, 42, 17, 42], fill=C("P47"))   # 상표판
    for x, y in ((4, 19), (5, 47), (26, 30)):                             # 녹
        d.point((x, y), fill=C("P25")); d.point((x, y + 1), fill=C("P24"))
    d.rectangle([4, 51, 7, 53], fill=C("P03")); d.rectangle([22, 51, 25, 53], fill=C("P03"))
    return im


def gas_range():
    """가스레인지(1×1): 크림 법랑 2구 · 냄비(뚜껑 들썩) · 아래 오븐 창 · 손잡이 셋. 옆에 LP 호스."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 30, 41)
    box3(d, 1, 12, 30, 40, 8, CREAM)
    for cx in (9, 22):                                                    # 화구
        d.ellipse([cx - 5, 13, cx + 5, 18], fill=C("P03")); d.ellipse([cx - 3, 14, cx + 3, 17], fill=C("P02"))
    d.rounded_rectangle([3, 4, 15, 15], 3, fill=C("P53"))                 # 냄비
    d.rounded_rectangle([3, 4, 15, 13], 3, fill=C("P54"))
    d.rectangle([2, 3, 16, 5], fill=C("P05")); d.point((9, 2), fill=C("P07"))
    d.rectangle([5, 24, 26, 35], fill=C("P05")); d.rectangle([7, 26, 24, 33], fill=C("P02"))   # 오븐 창
    d.line([8, 27, 12, 27], fill=C("P12"))
    for x in (8, 15, 22):                                                 # 손잡이
        d.ellipse([x - 2, 20, x + 1, 23], fill=C("P04"))
    d.arc([26, 22, 34, 40], 260, 90, fill=C("P31"))                      # LP 호스
    return im


def kitchen_sink():
    """싱크대(2×1): 상판 + 스테인리스 개수대(물때) · 수도꼭지 · 엎어 둔 그릇 · 아래 찬장 문 넷. 찬장 용기."""
    im = img(62, 46)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 43)
    box3(d, 1, 12, 60, 42, 9, CREAM)
    d.rounded_rectangle([5, 13, 27, 20], 2, fill=C("P06")); d.rounded_rectangle([7, 14, 25, 19], 2, fill=C("P04"))
    d.point((15, 17), fill=C("P02")); d.line([8, 18, 12, 18], fill=C("P31"))                  # 배수구·물때
    d.line([16, 4, 16, 13], fill=C("P07")); d.line([16, 4, 21, 4], fill=C("P07")); d.line([21, 4, 21, 7], fill=C("P07"))
    d.point((15, 4), fill=C("P09"))
    for k, x in enumerate((33, 41, 49)):                                  # 엎어 둔 밥그릇·국그릇
        d.pieslice([x, 8 + (k % 2), x + 8, 18 + (k % 2)], 180, 360, fill=C(["P09", "P46", "P08"][k]))
        d.line([x + 1, 13 + (k % 2), x + 7, 13 + (k % 2)], fill=C("P06"))
    for k in range(4):                                                    # 찬장 문
        x0 = 4 + k * 14
        d.rectangle([x0, 23, x0 + 12, 39], outline=C("P06"))
        d.line([x0 + (10 if k % 2 == 0 else 2), 29, x0 + (10 if k % 2 == 0 else 2), 33], fill=C("P04"))
    d.line([2, 41, 59, 41], fill=C("P05"))
    return im


def dining_table():
    """식탁(2×1): 무늬목 상판 · 의자 둘(앞) · 반찬 그릇 셋과 숟가락 · 가운데 굳은 김치 통."""
    im = img(62, 50)
    d = ImageDraw.Draw(im)
    shadow(d, 4, 58, 47)
    d.rectangle([4, 10, 57, 24], fill=C("P20")); d.rectangle([4, 10, 57, 22], fill=C("P21"))
    d.line([5, 10, 56, 10], fill=C("P22"))
    grain(d, 7, 12, 54, 21, "P20", 3, 3)
    d.rectangle([4, 22, 57, 26], fill=C("P18"))
    for x in (6, 53):
        d.rectangle([x, 27, x + 2, 38], fill=C("P17"))
    for k, x in enumerate((12, 22, 40)):                                  # 반찬 그릇
        d.ellipse([x, 12, x + 7, 17], fill=C("P09")); d.ellipse([x + 1, 13, x + 6, 16], fill=C(["P26", "P31", "P40"][k]))
    d.rounded_rectangle([28, 11, 36, 18], 2, fill=C("P15")); d.rectangle([29, 13, 35, 17], fill=C("P53"))   # 김치 통
    d.line([47, 14, 54, 12], fill=C("P07"))                               # 숟가락
    for x0 in (10, 38):                                                   # 의자(등받이가 앞)
        d.rectangle([x0, 28, x0 + 13, 30], fill=C("P19"))
        d.rectangle([x0, 31, x0 + 13, 40], fill=C("P18")); d.line([x0, 31, x0 + 13, 31], fill=C("P20"))
        d.line([x0 + 1, 41, x0 + 1, 47], fill=C("P17")); d.line([x0 + 12, 41, x0 + 12, 47], fill=C("P17"))
    return im


def bathtub():
    """욕조(2×1): 법랑 욕조 · 바닥에 마른 물때 줄 · 걸린 샤워기 · 수건. 200년 동안 물이 한 번도 안 찼다."""
    im = img(62, 40)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 37)
    d.rounded_rectangle([2, 6, 59, 34], 8, fill=C("P07"))
    d.rounded_rectangle([2, 6, 59, 30], 8, fill=C("P09"))
    d.rounded_rectangle([7, 9, 54, 26], 6, fill=C("P08"))
    d.rounded_rectangle([9, 11, 52, 24], 5, fill=C("P15"))
    d.line([12, 21, 48, 21], fill=C("P06"))                               # 물때 줄
    d.ellipse([47, 19, 50, 22], fill=C("P05"))                            # 배수구
    d.line([54, 2, 54, 9], fill=C("P06")); d.ellipse([51, 0, 57, 4], fill=C("P07"))   # 샤워기
    d.rectangle([3, 12, 6, 28], fill=C("P46")); d.line([3, 12, 3, 28], fill=C("P45"))  # 걸친 수건
    return im


def wash_basin():
    """세면대(1×1): 도자기 세면대 + 기둥 · 칫솔 컵(칫솔 셋) · 마른 비누."""
    im = img(30, 40)
    d = ImageDraw.Draw(im)
    shadow(d, 6, 24, 37)
    d.rectangle([12, 20, 18, 36], fill=C("P08")); d.line([12, 20, 12, 36], fill=C("P09"))
    d.rounded_rectangle([3, 9, 27, 21], 5, fill=C("P08"))
    d.rounded_rectangle([3, 9, 27, 18], 5, fill=C("P09"))
    d.ellipse([7, 11, 23, 17], fill=C("P15"))
    d.line([15, 6, 15, 11], fill=C("P07"))
    d.rectangle([21, 3, 25, 9], fill=C("P46"))                            # 칫솔 컵
    for x, c in ((22, "P54"), (23, "P49"), (24, "P56")):
        d.line([x, 0, x, 3], fill=C(c))
    d.rectangle([5, 8, 9, 10], fill=C("P42"))                             # 비누
    return im


# ================================================================================================ 거실·방
def sofa_home():
    """거실 소파(2×1): 꽃무늬 천 소파 · 터진 쿠션 솜 · 팔걸이 덮개(코바늘)."""
    im = img(62, 42)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 39)
    d.rounded_rectangle([3, 4, 58, 20], 5, fill=C("P39")); d.rounded_rectangle([3, 4, 58, 18], 5, fill=C("P40"))   # 등받이
    d.rounded_rectangle([1, 12, 10, 36], 4, fill=C("P39")); d.rounded_rectangle([51, 12, 60, 36], 4, fill=C("P39"))   # 팔걸이
    d.rectangle([9, 18, 52, 30], fill=C("P41")); d.line([9, 18, 52, 18], fill=C("P42"))   # 방석
    d.line([30, 18, 30, 30], fill=C("P39"))
    d.rectangle([9, 30, 52, 35], fill=C("P38"))
    rnd = random.Random(5)
    for _ in range(14):                                                   # 꽃무늬
        x, y = rnd.randint(6, 55), rnd.randint(6, 28)
        d.point((x, y), fill=C(rnd.choice(["P42", "P49", "P37"])))
    d.ellipse([36, 22, 42, 26], fill=C("P09")); d.point((38, 23), fill=C("P08"))   # 터진 솜
    for x0 in (1, 51):                                                    # 코바늘 덮개
        d.rectangle([x0 + 1, 12, x0 + 8, 15], fill=C("P09"))
        for x in range(x0 + 2, x0 + 8, 2):
            d.point((x, 16), fill=C("P09"))
    for x in (5, 55):
        d.rectangle([x, 36, x + 2, 39], fill=C("P17"))
    return im


def bookshelf_home():
    """책장(1×1): 무늬목 책장 · 위에서부터 전집·참고서·앨범 · 한 칸은 무너져 책이 쏟아졌다."""
    im = img(32, 58)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 30, 55)
    box3(d, 1, 2, 30, 54, 3, WOOD)
    rnd = random.Random(11)
    for k, y in enumerate((8, 22, 36)):
        d.rectangle([3, y, 28, y + 12], fill=C("P17"))
        x = 4
        while x < 27:
            w = rnd.randint(2, 4)
            if k == 2 and x > 15:                                         # 쏟아진 칸
                d.polygon([(x, y + 12), (x + 6, y + 6), (x + 8, y + 8), (x + 2, y + 12)], fill=C(rnd.choice(["P45", "P53", "P31"])))
                break
            col = rnd.choice(["P44", "P53", "P30", "P26", "P09", "P45", "P18"])
            d.rectangle([x, y + 12 - rnd.randint(8, 11), x + w - 1, y + 12], fill=C(col))
            d.point((x, y + 4), fill=C("P49"))
            x += w + (1 if rnd.random() < 0.2 else 0)
    d.rectangle([3, 50, 28, 52], fill=C("P18"))
    return im


def piano():
    """업라이트 피아노(2×1): 검은 옻칠 몸통 · 덮개 열린 건반(이 빠짐) · 위 레이스 덮개와 사진 액자 · 의자."""
    im = img(62, 56)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 53)
    box3(d, 2, 4, 59, 46, 5, ["P00", "P01", "P02", "P03"])
    d.rectangle([4, 24, 57, 30], fill=C("P09"))                           # 건반
    for x in range(6, 57, 4):
        d.line([x, 24, x, 30], fill=C("P06"))
    for x in range(8, 55, 8):
        d.rectangle([x, 24, x + 2, 27], fill=C("P01"))
    d.rectangle([33, 24, 36, 30], fill=C("P03"))                          # 빠진 건반
    d.rectangle([6, 2, 40, 6], fill=C("P09"))                             # 레이스 덮개
    for x in range(7, 40, 3):
        d.point((x, 7), fill=C("P09"))
    d.rectangle([44, 0, 52, 8], fill=C("P48")); d.rectangle([45, 1, 51, 7], fill=C("P08"))   # 액자
    d.ellipse([46, 2, 50, 5], fill=C("P41"))
    d.rectangle([18, 47, 43, 51], fill=C("P02")); d.line([18, 47, 43, 47], fill=C("P04"))   # 의자
    d.line([20, 52, 20, 55], fill=C("P01")); d.line([41, 52, 41, 55], fill=C("P01"))
    return im


def kid_desk():
    """아이 책상(1×1): 책상 + 갓 스탠드 · 펼친 공책(받아쓰기 100점) · 붙인 스티커 · 작은 의자."""
    im = img(32, 50)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 30, 47)
    box3(d, 1, 14, 30, 38, 7, ["P34", "P35", "P36", "P37"])
    d.rectangle([5, 15, 18, 20], fill=C("P09")); d.line([11, 15, 11, 20], fill=C("P06"))   # 공책
    d.line([6, 17, 9, 17], fill=C("P53"))
    d.ellipse([13, 16, 17, 19], outline=C("P53"))                          # 100점 동그라미
    d.line([24, 6, 24, 16], fill=C("P05")); d.polygon([(19, 6), (29, 6), (26, 1), (22, 1)], fill=C("P54"))   # 스탠드
    for x, c in ((6, "P49"), (20, "P46"), (25, "P56")):                    # 스티커
        d.ellipse([x, 27, x + 3, 30], fill=C(c))
    d.rectangle([9, 39, 22, 42], fill=C("P26")); d.line([10, 43, 10, 47], fill=C("P24")); d.line([21, 43, 21, 47], fill=C("P24"))
    return im


def w_photo():
    """벽 가족사진(벽, 1칸): 금테 액자 · 가족 넷(돌잔치 한복) · 모서리 사진 한 장 더 꽂힘."""
    im = img(26, 22)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 25, 21], fill=C("P47")); d.rectangle([1, 1, 24, 20], fill=C("P48"))
    d.rectangle([3, 3, 22, 18], fill=C("P21"))
    for x, c, hh in ((6, "P40", 9), (11, "P41", 10), (16, "P53", 7), (19, "P46", 6)):
        d.ellipse([x - 2, 18 - hh - 3, x + 1, 18 - hh], fill=C("P41"))
        d.rectangle([x - 2, 18 - hh, x + 1, 17], fill=C(c))
    d.rectangle([18, 0, 25, 6], fill=C("P09")); d.rectangle([19, 1, 24, 5], fill=C("P13"))
    return im


def w_kid_drawing():
    """벽에 붙인 아이 그림(벽, 1칸): 크레파스 '우리 가족' · 해 · 테이프 자국."""
    im = img(24, 20)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 1, 23, 19], fill=C("P09"))
    d.rectangle([2, 0, 6, 2], fill=C("P08")); d.rectangle([17, 0, 21, 2], fill=C("P08"))
    d.ellipse([16, 3, 21, 8], fill=C("P49"))
    for k, x in enumerate((4, 9, 13)):
        d.ellipse([x, 8, x + 3, 11], outline=C("P26"))
        d.line([x + 1, 12, x + 1, 16], fill=C(["P53", "P45", "P56"][k]))
    d.line([2, 17, 21, 17], fill=C("P55"))
    return im


# ================================================================================================ 가게
def _bag(d, x, y1, w, h, col, lit):
    """과자 봉지: 위 톱니 접합 · 볼록한 몸통 · 가운데 상표 띠."""
    d.rounded_rectangle([x, y1 - h, x + w, y1], 2, fill=C(col))
    d.line([x + 1, y1 - h + 1, x + 1, y1 - 2], fill=C(lit))
    for k in range(x, x + w + 1, 2):
        d.point((k, y1 - h - 1), fill=C(col))
    d.rectangle([x + 1, y1 - h // 2 - 1, x + w - 1, y1 - h // 2], fill=C("P09"))


def _can(d, x, y1, col):
    """통조림: 4×5 몸통 · 위 뚜껑 반사 · 상표 띠."""
    d.rectangle([x, y1 - 5, x + 3, y1], fill=C(col))
    d.line([x, y1 - 5, x + 3, y1 - 5], fill=C("P07"))
    d.line([x, y1 - 3, x + 3, y1 - 3], fill=C("P09"))


def _bottle(d, x, y1, col, hgt=8):
    d.rectangle([x, y1 - hgt + 3, x + 3, y1], fill=C(col))
    d.rectangle([x + 1, y1 - hgt, x + 2, y1 - hgt + 2], fill=C(col))
    d.point((x, y1 - hgt + 4), fill=C("P09"))


def _goods(d, rnd, kind, x0, y0, x1, y1):
    """진열대 한 칸: kind 0 과자 봉지·라면 묶음 / 1 통조림 2단·유리병 / 2 세제 통·두루마리 휴지·상자. 털린 자리는 빈다."""
    x = x0
    while x < x1 - 3:
        if rnd.random() < 0.2:                                           # 빈 자리(털림)
            x += rnd.randint(4, 8)
            continue
        if kind == 0:
            if rnd.random() < 0.65:
                w = rnd.randint(5, 7)
                col = rnd.choice(["P54", "P49", "P27", "P45", "P56", "P53"])
                lit = {"P54": "P27", "P49": "P50", "P27": "P42", "P45": "P46", "P56": "P57", "P53": "P54"}[col]
                _bag(d, x, y1, w, rnd.randint(6, 8), col, lit)
                x += w + 2
            else:                                                        # 라면 다섯 개 묶음(납작, 두 겹)
                col = rnd.choice(["P53", "P26", "P49"])
                for k in range(2):
                    d.rectangle([x, y1 - 3 - k * 4, x + 7, y1 - k * 4], fill=C(col)); d.line([x, y1 - 3 - k * 4, x + 7, y1 - 3 - k * 4], fill=C("P09"))
                x += 9
        elif kind == 1:
            if rnd.random() < 0.7:
                col = rnd.choice(["P05", "P26", "P31", "P48", "P53"])
                _can(d, x, y1, col)
                if rnd.random() < 0.6:
                    _can(d, x, y1 - 6, col)
                x += 5
            else:
                _bottle(d, x, y1, rnd.choice(["P35", "P59", "P15"]), 9)
                x += 5
        else:
            r = rnd.random()
            if r < 0.4:                                                  # 세제 통(손잡이)
                col = rnd.choice(["P46", "P56", "P27"])
                d.rounded_rectangle([x, y1 - 8, x + 5, y1], 1, fill=C(col))
                d.rectangle([x + 3, y1 - 10, x + 5, y1 - 8], outline=C(col))
                d.rectangle([x + 1, y1 - 5, x + 4, y1 - 3], fill=C("P09"))
                x += 7
            elif r < 0.75:                                               # 두루마리 휴지 묶음
                for k in range(2):
                    d.ellipse([x + k * 4, y1 - 7, x + k * 4 + 4, y1 - 3], fill=C("P09"))
                    d.rectangle([x + k * 4, y1 - 5, x + k * 4 + 4, y1], fill=C("P09"))
                    d.point((x + k * 4 + 2, y1 - 5), fill=C("P06"))
                d.line([x, y1 - 2, x + 8, y1 - 2], fill=C("P45"))
                x += 10
            else:                                                        # 상자
                w = rnd.randint(5, 8)
                d.rectangle([x, y1 - 6, x + w, y1], fill=C("P21")); d.line([x, y1 - 6, x + w, y1 - 6], fill=C("P22"))
                d.line([x + 1, y1 - 3, x + w - 1, y1 - 3], fill=C("P53"))
                x += w + 2


def shop_shelf(kind=0):
    """진열대(2×1): 철제 3단 · kind 0 과자·라면 / 1 통조림·병 / 2 생활용품. 털린 칸이 군데군데 비었다. 가게 용기."""
    im = img(62, 52)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 49)
    box3(d, 1, 2, 60, 48, 3, ["P11", "P12", "P13", "P14"])
    rnd = random.Random(40 + kind)
    for y in (8, 21, 34):
        d.rectangle([3, y, 58, y + 11], fill=C("P10"))
        _goods(d, rnd, kind, 4, y + 1, 57, y + 10)
        d.rectangle([3, y + 11, 58, y + 12], fill=C("P14"))
        for x in range(8, 56, 12):                                        # 가격표 줄
            d.rectangle([x, y + 11, x + 3, y + 12], fill=C("P49"))
    return im


def drink_fridge():
    """음료 냉장 진열장(1×1): 유리문 · 병 줄(번개사이다 노랑·뉴카-콜라 빨강) · 꺼진 형광등 · 위 상표."""
    im = img(32, 60)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 30, 57)
    box3(d, 1, 6, 30, 56, 3, ["P52", "P53", "P54", "P27"])
    d.rectangle([3, 0, 28, 7], fill=C("P49")); d.line([5, 3, 26, 3], fill=C("P53"))      # 상표
    d.rectangle([4, 11, 27, 53], fill=C("P33"))
    rnd = random.Random(9)
    for y in (14, 24, 34, 44):
        d.line([4, y + 8, 27, y + 8], fill=C("P05"))
        for x in range(5, 26, 4):
            if rnd.random() < 0.3:
                continue
            c = rnd.choice(["P49", "P53", "P56", "P46"])
            d.rectangle([x, y + 2, x + 2, y + 7], fill=C(c)); d.point((x + 1, y + 1), fill=C("P07"))
    d.line([5, 12, 9, 12], fill=C("P15")); d.line([6, 13, 6, 40], fill=C("P34"))         # 유리 반사
    d.rectangle([24, 28, 26, 36], fill=C("P07"))
    return im


def cash_counter():
    """계산대(2×1): 나무 계산대 · 기계식 금전 등록기(서랍 빠짐) · 껌 진열 · '외상 사절' 쪽지."""
    im = img(62, 48)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 45)
    box3(d, 1, 16, 60, 44, 7, WOOD)
    d.rounded_rectangle([30, 2, 52, 20], 3, fill=C("P04"))                 # 금전 등록기
    d.rounded_rectangle([30, 2, 52, 17], 3, fill=C("P05"))
    d.rectangle([33, 4, 49, 8], fill=C("P02"))
    d.line([35, 6, 40, 6], fill=C("P56"))
    for x in range(33, 50, 4):
        for y in (10, 13):
            d.rectangle([x, y, x + 2, y + 1], fill=C("P08"))
    d.rectangle([32, 18, 50, 22], fill=C("P06")); d.rectangle([33, 19, 49, 21], fill=C("P02"))   # 빠진 서랍
    d.rectangle([5, 10, 22, 17], fill=C("P46"))                           # 껌 진열
    for x in range(6, 22, 3):
        d.rectangle([x, 11, x + 1, 16], fill=C(["P54", "P49", "P56"][x % 3]))
    d.rectangle([8, 28, 22, 35], fill=C("P09")); d.line([10, 31, 20, 31], fill=C("P53")); d.line([10, 33, 18, 33], fill=C("P05"))
    return im


def hw_rack():
    """철물 걸이 진열대(2×1): 타공판 · 걸린 망치·스패너·톱·줄자 · 아래 못 상자. 철물점 용기."""
    im = img(62, 56)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 53)
    d.rectangle([2, 2, 59, 38], fill=C("P20")); d.rectangle([2, 2, 59, 4], fill=C("P21"))
    for y in range(7, 37, 5):
        for x in range(5, 58, 5):
            d.point((x, y), fill=C("P18"))
    d.line([8, 10, 8, 24], fill=C("P17")); d.rectangle([5, 8, 11, 11], fill=C("P05"))   # 망치
    d.line([16, 9, 20, 26], fill=C("P07")); d.ellipse([14, 6, 19, 11], outline=C("P07"))   # 스패너
    d.polygon([(26, 8), (40, 8), (40, 12), (26, 16)], fill=C("P07")); d.rectangle([22, 8, 26, 14], fill=C("P26"))   # 톱
    d.ellipse([45, 9, 54, 18], fill=C("P49")); d.ellipse([48, 12, 51, 15], fill=C("P01"))   # 줄자
    d.line([30, 22, 30, 34], fill=C("P05")); d.line([36, 22, 36, 30], fill=C("P05"))         # 빈 고리(털림)
    box3(d, 2, 38, 59, 52, 4, ["P17", "P18", "P19", "P20"])
    for x in range(6, 56, 9):
        d.rectangle([x, 39, x + 6, 41], fill=C("P06"))
    return im


def washer():
    """세탁소 드럼 세탁기(1×1): 크림 법랑 · 둥근 유리문 안 마른 셔츠 · 번호표."""
    im = img(30, 40)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 28, 37)
    box3(d, 1, 4, 28, 36, 4, CREAM)
    d.ellipse([6, 12, 23, 29], fill=C("P05")); d.ellipse([8, 14, 21, 27], fill=C("P11"))
    d.pieslice([9, 15, 20, 26], 30, 200, fill=C("P46"))                   # 마른 셔츠
    d.line([10, 17, 13, 15], fill=C("P15"))
    for x in (5, 9):
        d.ellipse([x, 6, x + 2, 8], fill=C("P04"))
    d.rectangle([20, 5, 26, 9], fill=C("P49")); d.point((22, 7), fill=C("P01"))
    return im


def laundry_rack():
    """세탁물 걸이(2×1): 쇠파이프 걸이 · 비닐 씌운 양복·교복·한복 · 번호표가 달랑."""
    im = img(62, 58)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 55)
    d.line([3, 6, 58, 6], fill=C("P06"), width=2)
    for x in (3, 58):
        d.line([x, 6, x, 53], fill=C("P05"), width=2)
    d.line([1, 53, 7, 53], fill=C("P04")); d.line([54, 53, 60, 53], fill=C("P04"))
    rnd = random.Random(3)
    for k, x in enumerate(range(7, 54, 8)):
        c = ["P43", "P02", "P44", "P54", "P12", "P30"][k % 6]
        d.line([x + 3, 6, x + 3, 9], fill=C("P07"))
        d.polygon([(x, 10), (x + 7, 10), (x + 8, 40 - rnd.randint(0, 8)), (x - 1, 40 - rnd.randint(0, 8))], fill=C(c))
        d.line([x, 10, x - 1, 38], fill=C("P15"))                         # 비닐 반사
        d.rectangle([x + 2, 12, x + 5, 15], fill=C("P49"))
    return im


# ================================================================================================ 주민센터·사무실
SEG7 = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcfgd"}


def _seg7(d, x, y, ch, on="P54", off="P52"):
    """7획 숫자 하나(4×7): 켜진 획은 붉게, 꺼진 획은 어둡게 비친다."""
    segs = {"a": [(x, y), (x + 3, y)], "b": [(x + 3, y), (x + 3, y + 3)], "c": [(x + 3, y + 3), (x + 3, y + 6)],
            "d": [(x, y + 6), (x + 3, y + 6)], "e": [(x, y + 3), (x, y + 6)], "f": [(x, y), (x, y + 3)], "g": [(x, y + 3), (x + 3, y + 3)]}
    lit = SEG7.get(ch, "")
    for k, ln in segs.items():
        if k not in lit:
            d.line(ln, fill=C("P51"))
    for k in lit:
        d.line(segs[k], fill=C(on))


def num_machine(num="412"):
    """번호표 발급기(1×1): 기둥 위 붉은 7획 숫자판(대기 인원 — 2077년 그대로 '412', SQ-S04에서 남솔이 들어가 '413') ·
    혀처럼 나온 번호표 · 아래 버린 번호표 더미."""
    im = img(26, 52)
    d = ImageDraw.Draw(im)
    shadow(d, 4, 22, 49)
    d.rectangle([10, 22, 15, 47], fill=C("P05")); d.line([10, 22, 10, 47], fill=C("P07"))
    d.rounded_rectangle([3, 2, 22, 24], 3, fill=C("P12")); d.rounded_rectangle([3, 2, 22, 22], 3, fill=C("P13"))
    d.rectangle([4, 3, 21, 12], fill=C("P01"))
    for k, ch in enumerate(num[:3]):
        _seg7(d, 6 + k * 5, 4, ch)
    if num != "412":
        d.point((21, 3), fill=C("P60"))                                  # 바뀐 순간 켜진 차임 표시등
    d.rectangle([9, 15, 16, 17], fill=C("P02")); d.rectangle([10, 17, 15, 21], fill=C("P09"))   # 번호표
    d.line([11, 19, 14, 19], fill=C("P05"))
    for x, y in ((3, 46), (8, 48), (17, 47), (20, 45)):
        d.rectangle([x, y, x + 3, y + 2], fill=C("P08"))
    return im


def wait_chairs():
    """대기 의자 줄(2×1): 철제 다리 플라스틱 의자 넷(주황·파랑) · 하나는 깨짐 · 버린 번호표."""
    im = img(62, 40)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 37)
    d.line([3, 30, 58, 30], fill=C("P05"), width=2)
    for k in range(4):
        x0 = 3 + k * 14
        c = ["P26", "P45", "P26", "P45"][k]
        lt = {"P26": "P27", "P45": "P46"}[c]
        d.rounded_rectangle([x0, 6, x0 + 12, 18], 3, fill=C(c)); d.line([x0 + 2, 6, x0 + 10, 6], fill=C(lt))   # 등받이
        d.rounded_rectangle([x0, 18, x0 + 12, 26], 2, fill=C(lt))
        if k == 2:
            d.polygon([(x0 + 4, 6), (x0 + 12, 6), (x0 + 12, 12)], fill=(0, 0, 0, 0))   # 깨진 등받이
            d.line([x0 + 4, 6, x0 + 12, 12], fill=C("P24"))
    for x in (5, 57):
        d.line([x, 31, x, 37], fill=C("P04"))
    d.rectangle([30, 33, 33, 35], fill=C("P09"))
    return im


def gov_counter():
    """민원 창구(2×1): 회색 철제 창구 · 유리 칸막이와 말하는 구멍 · 도장·인주 · '충성 등급 재산정' 명패."""
    im = img(62, 58)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 55)
    box3(d, 1, 26, 60, 54, 7, SLATE)
    d.rectangle([3, 2, 58, 27], fill=C("P33"))                            # 유리
    d.rectangle([3, 2, 58, 3], fill=C("P12")); d.line([30, 2, 30, 27], fill=C("P12"))
    d.line([6, 5, 12, 5], fill=C("P15")); d.line([7, 6, 7, 20], fill=C("P34"))
    d.line([36, 8, 44, 18], fill=C("P15"))                                # 금 간 유리
    d.line([44, 18, 46, 24], fill=C("P15"))
    for cx in (16, 44):                                                   # 말하는 구멍
        d.ellipse([cx - 3, 20, cx + 3, 24], outline=C("P12"))
    d.rectangle([10, 28, 15, 31], fill=C("P53")); d.rectangle([18, 28, 22, 31], fill=C("P18"))   # 인주·도장
    d.rectangle([34, 39, 56, 45], fill=C("P09")); d.line([36, 42, 54, 42], fill=C("P44"))   # 명패
    return im


def office_desk():
    """사무 책상(2×1): 회색 철제 책상 · 진공관 단말(꺼짐) · 결재판 · 엎어진 명패. 책상 서랍 용기."""
    im = img(62, 50)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 47)
    box3(d, 1, 16, 60, 44, 7, STEEL)
    d.rectangle([4, 25, 22, 42], outline=C("P04"))
    for y in (30, 36):
        d.line([4, y, 22, y], fill=C("P04")); d.rectangle([11, y - 3, 15, y - 2], fill=C("P07"))
    d.rounded_rectangle([30, 0, 52, 19], 3, fill=C("P20")); d.rounded_rectangle([30, 0, 52, 17], 3, fill=C("P21"))   # 단말
    d.rounded_rectangle([33, 3, 49, 14], 3, fill=C("P02")); d.line([35, 5, 38, 5], fill=C("P12"))
    d.rectangle([8, 13, 22, 21], fill=C("P18")); d.rectangle([9, 14, 21, 20], fill=C("P09"))   # 결재판
    d.line([11, 16, 19, 16], fill=C("P05"))
    d.polygon([(53, 18), (59, 16), (59, 20), (53, 22)], fill=C("P48"))   # 엎어진 명패
    return im


def w_gov_notice():
    """주민센터 벽 공고(벽, 2칸): '충성 등급 재산정 안내' · 등급표 1~5 칸 · 붉은 관인."""
    im = img(56, 24)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 55, 23], fill=C("P08")); d.rectangle([1, 1, 54, 22], fill=C("P09"))
    d.line([4, 4, 40, 4], fill=C("P44")); d.line([4, 6, 30, 6], fill=C("P44"))
    for k in range(5):
        d.rectangle([4 + k * 9, 10, 11 + k * 9, 17], outline=C("P05"))
        d.rectangle([5 + k * 9, 16 - (5 - k) * 1, 10 + k * 9, 16], fill=C(["P45", "P46", "P49", "P27", "P53"][k]))
    d.ellipse([47, 12, 53, 18], outline=C("P53")); d.point((50, 15), fill=C("P53"))
    return im


# ================================================================================================ 아파트 현관·창고
def w_mailboxes():
    """아파트 우편함(벽, 2칸): 칸 열둘 · 호수 번호 · 몇 칸은 문이 떨어졌고 고지서가 삐져나왔다."""
    im = img(58, 28)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 57, 27], fill=C("P05")); d.rectangle([1, 1, 56, 26], fill=C("P06"))
    for r in range(3):
        for k in range(4):
            x0, y0 = 3 + k * 13, 2 + r * 8
            d.rectangle([x0, y0, x0 + 11, y0 + 6], fill=C("P07"))
            d.line([x0 + 1, y0 + 1, x0 + 4, y0 + 1], fill=C("P02"))
            if (r * 4 + k) % 5 == 2:
                d.rectangle([x0, y0, x0 + 11, y0 + 6], fill=C("P02"))     # 떨어진 문
                d.rectangle([x0 + 2, y0 + 2, x0 + 9, y0 + 6], fill=C("P09"))
                d.line([x0 + 3, y0 + 4, x0 + 8, y0 + 4], fill=C("P53"))
    return im


def w_elevator():
    """엘리베이터 문(벽, 2칸): 스테인리스 두 짝(손톱만큼 벌어짐) · 위 층 표시 바늘 '1' · '고장' 종이."""
    im = img(52, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 6, 51, 39], fill=C("P04"))
    d.rectangle([3, 9, 48, 39], fill=C("P06"))
    d.rectangle([4, 10, 24, 39], fill=C("P07")); d.rectangle([27, 10, 47, 39], fill=C("P07"))
    d.line([25, 10, 26, 39], fill=C("P01"))
    d.line([5, 11, 5, 38], fill=C("P08")); d.line([28, 11, 28, 38], fill=C("P08"))
    d.pieslice([16, 0, 36, 14], 180, 360, fill=C("P48")); d.line([26, 7, 21, 3], fill=C("P01"))   # 층 바늘
    d.rectangle([30, 18, 42, 26], fill=C("P09")); d.line([32, 21, 40, 21], fill=C("P53"))   # 고장 종이
    d.ellipse([49, 20, 51, 22], fill=C("P54"))
    return im


def steel_rack():
    """창고 철제 랙(2×1): 앵글 선반 3단 · 골판지 상자 · 포대 · 비닐 감은 짐. 창고 용기."""
    im = img(62, 60)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 57)
    rnd = random.Random(21)
    for x in (2, 58):
        d.rectangle([x, 2, x + 2, 56], fill=C("P26")); d.line([x, 2, x, 56], fill=C("P27"))
        for y in range(6, 56, 6):
            d.point((x + 1, y), fill=C("P24"))
    for y in (16, 34, 52):
        d.rectangle([2, y, 60, y + 2], fill=C("P26")); d.line([2, y, 60, y], fill=C("P27"))
        x = 6
        while x < 54:
            w = rnd.randint(8, 14)
            hh = rnd.randint(7, 12)
            if rnd.random() < 0.2:
                x += w
                continue
            kind = rnd.random()
            if kind < 0.6:
                d.rectangle([x, y - hh, x + w, y - 1], fill=C("P20")); d.line([x, y - hh, x + w, y - hh], fill=C("P21"))
                d.line([x + w // 2, y - hh, x + w // 2, y - hh + 3], fill=C("P18"))
            elif kind < 0.85:
                d.rounded_rectangle([x, y - hh, x + w, y - 1], 3, fill=C("P08")); d.line([x + 2, y - hh + 3, x + w - 2, y - hh + 3], fill=C("P45"))
            else:
                d.rounded_rectangle([x, y - hh, x + w, y - 1], 2, fill=C("P15")); d.line([x + 1, y - hh + 1, x + w - 1, y - 2], fill=C("P09"))
            x += w + 2
    return im


def pallet_sacks():
    """팔레트와 포대(1×1): 나무 팔레트 위 쌀·시멘트 포대 셋(하나 터짐)."""
    im = img(32, 34)
    d = ImageDraw.Draw(im)
    shadow(d, 1, 31, 31)
    d.rectangle([1, 24, 30, 30], fill=C("P19"))
    for x in (2, 14, 26):
        d.rectangle([x, 26, x + 3, 30], fill=C("P17"))
    for k, (x, y) in enumerate(((2, 14), (15, 14), (8, 4))):
        d.rounded_rectangle([x, y, x + 14, y + 11], 4, fill=C("P07" if k != 1 else "P08"))
        d.line([x + 3, y + 4, x + 11, y + 4], fill=C("P53" if k == 0 else "P44"))
    d.ellipse([20, 22, 27, 25], fill=C("P09"))                            # 터진 쌀
    return im


def door_mat():
    """현관 발판(바닥 장식, 1칸): 닳은 고무 발판 · 가운데가 해져 밝다 · 모서리 말림. 들어갈 수 있는 문 앞에 깐다(1-5e)."""
    im = img(28, 12)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 1, 27, 11], 2, fill=C("P02"))
    d.rounded_rectangle([1, 1, 26, 9], 2, fill=C("P26"))
    for x in range(3, 25, 3):
        d.line([x, 3, x, 7], fill=C("P25"))
    d.ellipse([9, 3, 18, 7], fill=C("P27"))                             # 해진 가운데
    d.line([24, 1, 27, 4], fill=C("P24"))                                # 말린 모서리
    return im


# ================================================================================================ 손 장소(1-5e): 여의도 공영방송
def anchor_desk():
    """앵커석(2×1): 반달 앵커 책상 · 의자에 기대 앉은 앵커 해골(정장·넥타이) · 원고 묶음 · 마이크 · 앞면 방송사 띠(이름 없음)."""
    im = img(62, 54)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 60, 51)
    d.rectangle([20, 2, 41, 20], fill=C("P02")); d.line([20, 2, 41, 2], fill=C("P04"))          # 의자 등받이
    d.polygon([(23, 14), (38, 14), (40, 26), (21, 26)], fill=C("P43"))                           # 몸통(감색 정장)
    d.polygon([(29, 14), (32, 14), (31, 22)], fill=C("P08")); d.line([30, 16, 30, 22], fill=C("P53"))
    d.ellipse([25, 3, 36, 14], fill=C("P08")); d.ellipse([27, 7, 29, 9], fill=C("P01")); d.ellipse([32, 7, 34, 9], fill=C("P01"))   # 해골
    d.line([29, 12, 33, 12], fill=C("P05"))
    d.rounded_rectangle([2, 22, 59, 40], 6, fill=C("P11")); d.rounded_rectangle([2, 22, 59, 37], 6, fill=C("P12"))   # 책상
    d.line([8, 22, 53, 22], fill=C("P14"))
    d.rectangle([4, 38, 57, 49], fill=C("P10")); d.rectangle([4, 41, 57, 44], fill=C("P45"))    # 앞면 띠
    d.line([10, 42, 26, 42], fill=C("P15")); d.line([36, 42, 51, 42], fill=C("P15"))
    d.rectangle([12, 24, 22, 29], fill=C("P09")); d.line([13, 26, 21, 26], fill=C("P05"))       # 원고
    d.rectangle([15, 25, 25, 31], fill=C("P08"))
    d.line([40, 18, 42, 26], fill=C("P05")); d.ellipse([38, 15, 42, 19], fill=C("P03"))          # 마이크
    d.line([22, 27, 26, 29], fill=C("P08"), width=2)                                            # 원고 위 손뼈
    return im


def tv_camera():
    """스튜디오 카메라(1×1): 세 발 받침 · 상자 몸통 · 앞 렌즈 · 뒤 손잡이 · 꺼진 붉은 촬영등."""
    im = img(32, 50)
    d = ImageDraw.Draw(im)
    shadow(d, 2, 30, 47)
    for x0, x1 in ((16, 4), (16, 28), (16, 16)):
        d.line([x0, 26, x1, 46], fill=C("P04"), width=2)
    d.rounded_rectangle([5, 8, 27, 26], 3, fill=C("P03")); d.rounded_rectangle([5, 8, 27, 23], 3, fill=C("P04"))
    d.line([7, 8, 25, 8], fill=C("P06"))
    d.ellipse([10, 12, 22, 22], fill=C("P02")); d.ellipse([12, 14, 20, 20], fill=C("P11")); d.point((14, 15), fill=C("P15"))   # 렌즈
    d.rectangle([22, 4, 26, 8], fill=C("P52")); d.point((24, 5), fill=C("P53"))                 # 촬영등
    d.line([27, 18, 31, 22], fill=C("P05"), width=2)
    return im


def studio_light():
    """조명 스탠드(1×1): 긴 기둥 위 각진 등갓(깨진 유리) · 늘어진 전선."""
    im = img(28, 58)
    d = ImageDraw.Draw(im)
    shadow(d, 4, 24, 55)
    d.line([14, 14, 14, 52], fill=C("P05"), width=2)
    d.line([14, 52, 5, 55], fill=C("P04")); d.line([14, 52, 23, 55], fill=C("P04"))
    d.polygon([(4, 2), (24, 2), (21, 14), (7, 14)], fill=C("P03"))
    d.rectangle([7, 4, 21, 11], fill=C("P50")); d.line([9, 5, 14, 10], fill=C("P02")); d.line([15, 6, 19, 9], fill=C("P02"))
    d.arc([10, 30, 26, 56], 270, 90, fill=C("P02"))
    return im


def w_onair():
    """'방송 중' 표시등(벽, 1칸): 빨간 유리 상자(꺼짐) · 글자 띠."""
    im = img(26, 12)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, 25, 11], 2, fill=C("P02"))
    d.rounded_rectangle([2, 2, 23, 9], 2, fill=C("P52"))
    for x in (5, 9, 13, 17, 20):
        d.line([x, 4, x, 7], fill=C("P51"))
    d.line([3, 3, 8, 3], fill=C("P53"))
    return im


def crate_army():
    """국방색 나무 상자(1×1): 판자 이음 · 모서리 쇠 · 흰 스텐실 '탄약 · 비상' · 위에 접힌 방수포. 볼트 밖 비상 물자."""
    im = img(32, 34)
    d = ImageDraw.Draw(im)
    shadow(d, 1, 31, 31)
    box3(d, 1, 6, 30, 30, 6, ["P28", "P29", "P30", "P31"])
    for y in (16, 23):
        d.line([2, y, 29, y], fill=C("P28"))
    for x in (1, 26):
        d.rectangle([x, 12, x + 3, 30], fill=C("P04")); d.line([x, 12, x, 30], fill=C("P06"))
    d.rectangle([9, 18, 22, 21], fill=C("P08")); d.line([11, 19, 20, 19], fill=C("P29"))
    d.polygon([(4, 4), (20, 2), (24, 8), (6, 9)], fill=C("P12")); d.line([6, 5, 19, 3], fill=C("P13"))
    return im


# ================================================================================================ 1-B3 문 앞 분필 표식(떠돌이 표식 — 실내 생성 결과에서 뽑는다)
def chalk_sign(kind="x"):
    """문 앞 바닥의 떠돌이 분필 표식(바닥 장식, 1칸): x 막힘(동그라미 속 ✕) · skull 사람형 · 구울 · claw 짐승 굴 · trap 덫 · water 물 · live 사람 삶(지붕과 연기).
    분필은 두 겹(굵은 회백 + 가는 흰)으로 긋고 낱알을 빼거나 어둡게 해 거친 결을 낸다. 표식은 거짓말하지 않는다(P1)."""
    im = img(30, 26)
    d = ImageDraw.Draw(im)
    W_ = C("P07")                                                       # 번진 분필(어두운 쪽) · 그은 분필(밝은 쪽) — 팔레트 불투명만
    S_ = C("P09")

    def ln(pts, w=2):
        d.line(pts, fill=W_, width=w + 1)
        d.line(pts, fill=S_, width=1)
    if kind == "x":
        d.ellipse([3, 1, 26, 24], outline=W_, width=2); d.ellipse([4, 2, 25, 23], outline=S_, width=1)
        ln([9, 7, 20, 18]); ln([20, 7, 9, 18])
    elif kind == "skull":
        d.ellipse([8, 0, 21, 12], outline=W_, width=2); d.ellipse([9, 1, 20, 11], outline=S_, width=1)
        d.rectangle([11, 11, 18, 15], outline=S_)
        d.rectangle([10, 5, 12, 7], fill=S_); d.rectangle([17, 5, 19, 7], fill=S_)
        d.point((14, 13), fill=S_)
        ln([4, 17, 25, 24]); ln([25, 17, 4, 24])
    elif kind == "trap":
        d.ellipse([3, 2, 26, 24], outline=W_, width=2); d.ellipse([4, 3, 25, 23], outline=S_, width=1)
        ln([5, 13, 8, 8, 11, 17, 14, 8, 17, 17, 20, 8, 23, 17, 25, 12], 1)
    elif kind == "claw":                                                # 짐승 굴: 비스듬한 발톱 자국 셋
        for k in range(3):
            ln([6 + k * 7, 3, 12 + k * 7, 22], 1)
        d.ellipse([22, 18, 26, 22], outline=S_)
    elif kind == "water":
        for y in (5, 12, 19):
            ln([3, y + 2, 7, y, 11, y + 2, 15, y, 19, y + 2, 23, y, 27, y + 2], 1)
    else:                                                               # live
        ln([5, 13, 15, 4, 25, 13]); ln([8, 13, 8, 23]); ln([22, 13, 22, 23]); ln([8, 23, 22, 23])
        d.rectangle([13, 17, 16, 22], outline=S_)
        ln([20, 6, 21, 3, 23, 1], 1)
    rnd = random.Random({"x": 1, "skull": 2, "trap": 3, "water": 4, "live": 5, "claw": 6}[kind])
    px = im.load()
    for _ in range(70):                                                 # 분필 결: 낱알 빼기 · 옅게
        x, y = rnd.randrange(30), rnd.randrange(26)
        r_, g_, b_, a_ = px[x, y]
        if a_:
            px[x, y] = (0, 0, 0, 0) if rnd.random() < 0.5 else C("P06")
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_HOME = {
    "fridge": _r(fridge, 1, 1, down=1),
    "gas_range": _r(gas_range, 1, 1),
    "kitchen_sink": _r(kitchen_sink, 2, 1),
    "dining_table": _r(dining_table, 2, 1),
    "bathtub": _r(bathtub, 2, 1),
    "wash_basin": _r(wash_basin, 1, 1),
    "sofa_home": _r(sofa_home, 2, 1),
    "bookshelf_home": _r(bookshelf_home, 1, 1, down=1),
    "piano": _r(piano, 2, 1),
    "kid_desk": _r(kid_desk, 1, 1),
    "w_photo": _r(w_photo, 1, 0, "wall", dx=3, dy=6),
    "w_kid_drawing": _r(w_kid_drawing, 1, 0, "wall", dx=4, dy=8),
    "shop_shelf": _r(lambda: shop_shelf(0), 2, 1),
    "shop_shelf_can": _r(lambda: shop_shelf(1), 2, 1),
    "shop_shelf_goods": _r(lambda: shop_shelf(2), 2, 1),
    "drink_fridge": _r(drink_fridge, 1, 1, down=1),
    "cash_counter": _r(cash_counter, 2, 1),
    "hw_rack": _r(hw_rack, 2, 1),
    "washer": _r(washer, 1, 1),
    "laundry_rack": _r(laundry_rack, 2, 1),
    "num_machine": _r(num_machine, 1, 1),
    "wait_chairs": _r(wait_chairs, 2, 1),
    "gov_counter": _r(gov_counter, 2, 1),
    "office_desk": _r(office_desk, 2, 1),
    "w_gov_notice": _r(w_gov_notice, 2, 0, "wall", dx=4, dy=8),
    "w_mailboxes": _r(w_mailboxes, 2, 0, "wall", dx=3, dy=4),
    "w_elevator": _r(w_elevator, 2, 0, "wall", dx=6, dy=-8),
    "steel_rack": _r(steel_rack, 2, 1, down=1),
    "pallet_sacks": _r(pallet_sacks, 1, 1),
    "door_mat": _r(door_mat, 0, 0, "deco", dx=2, dy=12),
    **{"chalk_" + k: _r(lambda k=k: chalk_sign(k), 0, 0, "deco", dx=1, dy=3) for k in ("x", "skull", "claw", "trap", "water", "live")},   # 1-B3 문 앞 표식
    "anchor_desk": _r(anchor_desk, 2, 1),
    "crate_army": _r(crate_army, 1, 1),
    "tv_camera": _r(tv_camera, 1, 1),
    "studio_light": _r(studio_light, 1, 1),
    "w_onair": _r(w_onair, 1, 0, "wall", dx=3, dy=10),
}
STATES_HOME = {"num_machine": {"413": lambda: num_machine("413")}}   # 1-11c SQ-S04: 남솔 1명 추가
