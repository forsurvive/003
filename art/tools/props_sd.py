"""사당 환승촌 소품(단계 1-8f, SD-09a L-R01-18 · SD-16 §7·§8 아이작풍).
2077년 2·4호선 사당역 대합실이 200년째 '대기 구역'인 채로 환승촌이 됐다. 판독기 개찰구는 '대기 구역'에서 멈췄고(빨래가 널린다),
노란 대기 선 안의 해골은 '그 사람들 자리'라 아무도 건드리지 않는다.
바닥 소품: 판독기 개찰구(날개 닫힘·밀린) · 무기 내림대 · 대합실 천막(주황·청·녹) · 공동 화덕 · 물통 줄 · 버섯 재배 선반 · 차단 철망 ·
행상 천막 · 캐러밴 말뚝 · 경비 초소 · 역무실 책상 · 노선도 단말 · 방송 설비.
벽 소품(kind wall): 환승촌 간판(2·4호선 녹·하늘 천) · 분양 광고판(LR-09) · 멈춘 시계 '11시 29분' · 역무실 칠판 '오늘의 운행 안내: 운행 없음' ·
'빛 들이지 마시오' 표지 · '막차 기다리는 손님 있음' 표지.
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다.
"""
import os, sys, random, math
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

T = 32
C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


# ================================================================================================ 바닥 소품
def gate(state="shut", laundry=False):
    """판독기 개찰구 한 기(1×1): 스테인리스 함(윗면 · 앞면) + 윗면 판독기 + 기둥 위 표시창(호박색 '대기 구역') + 아크릴 날개.
    shut = 날개가 통로를 막음, push = 손으로 밀어 함 안으로 반쯤 접힌 날개(열린 모습). laundry = 표시창 기둥에 넌 빨래."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 18, 13, 24], fill=C("P15")); d.line([3, 18, 13, 18], fill=C("P16"))          # 윗면
    d.rectangle([3, 24, 13, 42], fill=C("P13")); d.line([4, 25, 4, 41], fill=C("P14"))            # 앞면
    d.rectangle([5, 19, 11, 22], fill=C("P02")); d.line([6, 20, 10, 20], fill=C("P47"))           # 판독기(호박 불)
    d.rectangle([5, 28, 11, 30], fill=C("P02")); d.point((8, 29), fill=C("P53"))                  # 승차권 투입구 · 빨간 불(꺼짐)
    d.line([3, 34, 13, 34], fill=C("P12"))
    d.rectangle([7, 9, 9, 18], fill=C("P12"))                                                      # 표시창 기둥
    d.rectangle([3, 3, 13, 10], fill=C("P11")); d.rectangle([4, 4, 12, 9], fill=C("P02"))          # 표시창
    d.line([5, 6, 11, 6], fill=C("P47")); d.line([5, 8, 9, 8], fill=C("P48"))                     # '대기 구역' 글줄
    if state == "shut":
        d.polygon([(13, 25), (30, 23), (30, 33), (13, 34)], fill=C("P44"))                         # 아크릴 날개(닫힘)
        d.line([13, 25, 30, 23], fill=C("P46")); d.line([30, 23, 30, 33], fill=C("P53"))
        d.line([16, 28, 26, 27], fill=C("P45"))
    else:
        d.polygon([(13, 25), (18, 24), (18, 33), (13, 34)], fill=C("P44"))                         # 반쯤 접힌 날개
        d.line([18, 24, 18, 33], fill=C("P53"))
    d.rectangle([2, 41, 14, 43], fill=C("P11"))
    if laundry:                                                           # 표시창 기둥에 건 빨래(셔츠 · 양말)
        d.line([9, 12, 24, 14], fill=C("P08"))
        d.polygon([(14, 12), (21, 13), (22, 20), (13, 19)], fill=C("P30")); d.line([14, 12, 21, 13], fill=C("P31"))
        d.rectangle([22, 14, 24, 19], fill=C("P53"))
    return im


def weapon_rack():
    """무기 내림대(2×1): 개찰구 앞 나무 선반 + '무기는 여기 내려놓고' 판 + 걸려 있는 파이프 소총 · 쇠파이프 · 녹슨 칼."""
    im = img(66, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 20, 62, 24], fill=C("P19")); d.line([4, 20, 62, 20], fill=C("P20"))
    d.rectangle([4, 38, 62, 42], fill=C("P19")); d.line([4, 38, 62, 38], fill=C("P20"))
    for x in (6, 33, 58):
        d.rectangle([x, 20, x + 3, 46], fill=C("P18"))
    d.rectangle([4, 2, 62, 16], fill=C("P09")); d.rectangle([4, 2, 62, 4], fill=C("P53"))     # 안내판
    w, _ = put_text(img(1, 1), "무기 내림대", 0, 0, "P02", 8, "Galmuri7")
    put_text(im, "무기 내림대", 33 - w // 2, 6, "P02", 8, "Galmuri7")
    d.line([20, 16, 22, 20], fill=C("P18")); d.line([46, 16, 44, 20], fill=C("P18"))
    d.line([10, 23, 28, 37], fill=C("P04"), width=3); d.rectangle([24, 33, 30, 37], fill=C("P18"))   # 파이프 소총(기대 둠)
    d.line([36, 22, 40, 37], fill=C("P06"), width=2)                                               # 쇠파이프
    d.line([48, 21, 52, 37], fill=C("P26"), width=2); d.rectangle([46, 20, 52, 22], fill=C("P17"))  # 녹슨 칼
    return im


TENT = {"o": ("P26", "P27", "P25"), "b": ("P45", "P46", "P44"), "g": ("P30", "P31", "P29"), "y": ("P48", "P49", "P47")}


def tent(col="o", seed=1):
    """대합실 천막(2×2): 방수포를 장대에 걸친 삼각 지붕 + 앞 휘장 반쯤 걷힘 + 안쪽 이불 · 냄비. 색마다 기운 자국이 다르다."""
    rnd = random.Random(seed)
    base, light, dark = TENT[col]
    im = img(66, 64)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 60), (33, 6), (64, 60)], fill=C(base))                # 몸
    d.polygon([(33, 6), (64, 60), (52, 60)], fill=C(dark))               # 그늘진 쪽
    d.line([2, 60, 33, 6], fill=C(light)); d.line([33, 6, 33, 3], fill=C("P18"), width=2)
    for _ in range(3):                                                    # 기운 천 조각
        x, y = rnd.randint(12, 44), rnd.randint(28, 50)
        pc = rnd.choice(["P20", "P07", "P36", "P53"])
        d.rectangle([x, y, x + 7, y + 5], fill=C(pc)); d.line([x, y, x + 7, y], fill=C("P02"))
    d.polygon([(24, 60), (33, 30), (42, 60)], fill=C("P02"))             # 입구(어둠)
    d.polygon([(33, 30), (42, 60), (36, 60)], fill=C(dark))              # 걷어 올린 휘장
    d.rectangle([27, 54, 34, 59], fill=C("P07")); d.rectangle([27, 54, 34, 55], fill=C("P46"))   # 안쪽 이불
    d.ellipse([35, 54, 40, 59], fill=C("P05"))                           # 냄비
    d.line([0, 61, 66, 61], fill=C("P18"))
    for x in (1, 64):
        d.line([x, 61, x, 63], fill=C("P17"))                            # 말뚝
    return im


def mushroom_shelf():
    """버섯 재배 선반(2×1): 철제 3단 선반 + 톱밥 봉지마다 회색 지하 느타리 + 아래 습도 물통."""
    im = img(66, 54)
    d = ImageDraw.Draw(im)
    for x in (3, 61):
        d.rectangle([x, 4, x + 2, 52], fill=C("P12"))
    for y in (12, 26, 40):
        d.rectangle([3, y, 63, y + 2], fill=C("P13"))
        for k, x in enumerate(range(7, 58, 9)):
            d.rectangle([x, y - 7, x + 6, y - 1], fill=C("P20"))         # 톱밥 봉지
            d.line([x, y - 7, x + 6, y - 7], fill=C("P21"))
            for (dx, dy) in ((1, -9), (4, -10), (2, -8)) if (k + y) % 3 else ((2, -9), (5, -8)):
                d.ellipse([x + dx - 1, y + dy - 1, x + dx + 2, y + dy + 1], fill=C("P07"))   # 느타리 갓
                d.point((x + dx, y + dy), fill=C("P09"))
    d.rectangle([20, 44, 46, 52], fill=C("P36")); d.rectangle([20, 44, 46, 46], fill=C("P37"))   # 습도 물통
    return im


def wire_fence():
    """차단 철망(1×1): 쇠기둥 + 마름모 철망 + 위 가시철사."""
    im = img(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 4, 3, 46], fill=C("P11")); d.rectangle([28, 4, 30, 46], fill=C("P11"))
    for y in range(8, 44, 5):
        for x in range(3, 29, 5):
            d.line([x, y, x + 2, y + 2], fill=C("P06")); d.line([x + 2, y + 2, x + 4, y], fill=C("P06"))
    d.line([0, 5, 31, 5], fill=C("P05"))
    for x in range(2, 30, 4):
        d.line([x, 3, x + 2, 7], fill=C("P05"))
    d.line([3, 44, 28, 44], fill=C("P11"))
    return im


def caravan_post():
    """캐러밴 말뚝(1×1): 굵은 나무 말뚝 + 쇠고리 + 감긴 밧줄 + 발치 물통."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([12, 6, 19, 40], fill=C("P18")); d.line([12, 6, 12, 40], fill=C("P20"))
    d.ellipse([11, 3, 20, 9], fill=C("P19"))
    d.ellipse([18, 14, 25, 21], outline=C("P05"), width=2)
    for y in range(24, 32, 2):
        d.line([11, y, 20, y + 1], fill=C("P21"))
    d.rectangle([22, 32, 30, 42], fill=C("P36")); d.rectangle([22, 32, 30, 34], fill=C("P37"))
    return im


def peddler_tent(seed=1):
    """행상 천막(2×2): 네 기둥 차양(줄무늬 방수포) + 앞 좌판 위 물통 · 자루 · 깡통."""
    rnd = random.Random(seed)
    im = img(66, 62)
    d = ImageDraw.Draw(im)
    for x in (4, 60):
        d.rectangle([x, 12, x + 2, 60], fill=C("P18"))
    for i, x in enumerate(range(0, 66, 8)):
        d.polygon([(x, 6), (x + 8, 6), (x + 8, 18), (x, 18)], fill=C("P53" if i % 2 else "P09"))
    d.line([0, 18, 65, 18], fill=C(INK))
    d.rectangle([2, 40, 63, 48], fill=C("P19")); d.line([2, 40, 63, 40], fill=C("P20"))
    x = 6
    while x < 58:
        k = rnd.random()
        if k < 0.35:
            d.rectangle([x, 30, x + 7, 39], fill=C("P36")); d.rectangle([x, 30, x + 7, 31], fill=C("P37")); x += 10
        elif k < 0.7:
            d.ellipse([x, 30, x + 9, 40], fill=C("P20")); d.line([x + 4, 30, x + 5, 27], fill=C("P18")); x += 11
        else:
            d.rectangle([x, 34, x + 4, 39], fill=C("P07")); d.line([x, 34, x + 4, 34], fill=C("P09")); x += 6
    d.rectangle([6, 49, 59, 60], fill=C("P18"))
    return im


def guard_post():
    """승강장 경비 초소(2×1): 모래주머니 반원 + 철판 방패 + 확성기 기둥."""
    im = img(66, 52)
    d = ImageDraw.Draw(im)
    for row, y in enumerate((38, 30)):
        for x in range(4 + row * 5, 62 - row * 5, 10):
            d.rounded_rectangle([x, y, x + 10, y + 8], radius=3, fill=C("P21")); d.line([x + 1, y + 1, x + 9, y + 1], fill=C("P22"))
    d.rectangle([22, 12, 44, 30], fill=C("P05")); d.rectangle([23, 13, 43, 29], fill=C("P06"))   # 철판 방패
    d.line([23, 13, 43, 13], fill=C("P07"))
    for (x, y) in ((25, 15), (41, 15), (25, 27), (41, 27)):
        d.point((x, y), fill=C("P08"))                                    # 리벳
    d.rectangle([26, 19, 40, 21], fill=C("P02"))                         # 사격 틈
    d.line([30, 24, 36, 28], fill=C("P26"))                              # 녹 자국
    d.rectangle([52, 2, 54, 32], fill=C("P05"))
    d.polygon([(54, 4), (63, 1), (63, 11), (54, 8)], fill=C("P13"))      # 확성기
    return im


def station_desk():
    """역무실 책상(2×1): 철제 책상 + 2077 노선도 단말(녹 화면, UG 지도) + 마이크 + 서류."""
    im = img(66, 46)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 24, 63, 30], fill=C("P12")); d.line([2, 24, 63, 24], fill=C("P14"))
    d.rectangle([4, 30, 12, 44], fill=C("P11")); d.rectangle([54, 30, 62, 44], fill=C("P11"))
    d.rectangle([8, 4, 34, 24], fill=C("P11")); d.rectangle([10, 6, 32, 20], fill=C("P02"))   # 단말
    d.line([12, 9, 30, 9], fill=C("P55")); d.line([12, 13, 21, 13], fill=C("P30")); d.line([21, 13, 29, 17], fill=C("P62"))
    d.point((21, 13), fill=C("P57")); d.point((29, 17), fill=C("P57"))
    d.rectangle([40, 18, 56, 23], fill=C("P09")); d.line([42, 20, 54, 20], fill=C("P07"))   # 서류
    d.line([38, 23, 40, 10], fill=C("P05")); d.ellipse([37, 6, 43, 11], fill=C("P04"))      # 방송 마이크
    return im


def banner():
    """환승촌 간판 현수막(3×1, 지상 4번 출구 광장 앵커): 쇠파이프 두 기둥 + 2호선 녹 · 4호선 하늘 천을 이어 붙인 띠 '사당 환승촌'
    + 그 아래 판자 '환승객 환영 / 무기는 개찰구 앞에서'."""
    im = img(98, 70)
    d = ImageDraw.Draw(im)
    for x in (4, 90):
        d.rectangle([x, 4, x + 3, 68], fill=C("P12")); d.line([x, 4, x, 68], fill=C("P14"))
        d.rectangle([x - 2, 64, x + 5, 68], fill=C("P05"))                # 콘크리트 받침
    d.rectangle([8, 6, 48, 24], fill=C("P55")); d.rectangle([49, 6, 89, 24], fill=C("P62"))
    d.line([8, 6, 89, 6], fill=C("P56")); d.line([8, 24, 89, 24], fill=C("P02"))
    for x in range(10, 88, 5):
        d.point((x, 8), fill=C("P09")); d.point((x, 22), fill=C("P09"))  # 바느질 땀
    d.line([48, 6, 48, 24], fill=C("P09"))
    w, _ = put_text(img(1, 1), "사당 환승촌", 0, 0, "P09", 8, "Galmuri7")
    d.rounded_rectangle([46 - w // 2, 9, 51 + w // 2, 21], radius=2, fill=C("P02"))
    put_text(im, "사당 환승촌", 49 - w // 2, 11, "P09", 8, "Galmuri7")
    for x in (8, 89):
        d.line([x, 24, x + (3 if x < 40 else -3), 28], fill=C("P05"))    # 처진 끈
    d.rectangle([20, 32, 77, 52], fill=C("P19")); d.line([20, 32, 77, 32], fill=C("P20"))   # 판자
    d.line([20, 42, 77, 42], fill=C("P18"))
    put_text(im, "환승객 환영", 26, 33, "P09", 8, "Galmuri7")
    put_text(im, "무기는 개찰구", 23, 43, "P22", 8, "Galmuri7")
    for x in (34, 62):
        d.line([x, 24, x, 32], fill=C("P05"))
    return im


def exit_stairs(num, barred=False):
    """지하철 출입구(2×1, 발 칸 = 출구 칸): 영등포 지하상가 출입구(props_jm.subway_stairs)와 같은 꼴에 노선 띠와 번호판.
    barred = 역무 위원회가 고철 칸막이로 막은 출구(지나갈 수 없다)."""
    from props_jm import subway_stairs
    im = subway_stairs("")
    d = ImageDraw.Draw(im)
    label = "%d번 출구" % num
    w, _ = put_text(img(1, 1), label, 0, 0, "P09", 8, "Galmuri7")
    d.rectangle([30 - w // 2, 0, 33 + w // 2, 10], fill=C("P61")); d.line([30 - w // 2, 0, 33 + w // 2, 0], fill=C("P62"))
    d.line([30 - w // 2, 10, 33 + w // 2, 10], fill=C(INK))
    put_text(im, label, 32 - w // 2, 1, "P09", 8, "Galmuri7")
    d.rectangle([0, 11, 13, 13], fill=C("P55")); d.rectangle([50, 11, 63, 13], fill=C("P62"))   # 뒤 벽 노선 띠
    if barred:
        for i, x in enumerate(range(4, 60, 9)):                          # 녹슨 함석 · 문짝 · 철판을 세워 묶었다
            col = ["P25", "P12", "P26", "P05", "P24", "P13", "P25"][i % 7]
            d.rectangle([x, 20 - (i % 3), x + 10, 45], fill=C(col)); d.line([x, 20 - (i % 3), x + 10, 20 - (i % 3)], fill=C("P07"))
            d.line([x + 10, 21, x + 10, 45], fill=C(INK))
        d.line([3, 30, 60, 28], fill=C("P05"), width=2); d.line([3, 38, 60, 40], fill=C("P05"), width=2)   # 철사
        w, _ = put_text(img(1, 1), "4번으로", 0, 0, "P53", 8, "Galmuri7")
        d.rectangle([29 - w // 2, 25, 34 + w // 2, 35], fill=C("P09")); d.rectangle([29 - w // 2, 25, 34 + w // 2, 35], outline=C("P53"))
        put_text(im, "4번으로", 32 - w // 2, 26, "P53", 8, "Galmuri7")
    return im


def wait_line(axis="h"):
    """노란 '대기 구역' 선(deco 1×1): 2077년 바닥에 칠한 굵은 노란 띠, 200년 발에 닳아 군데군데 벗겨졌다."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    rnd = random.Random(7 if axis == "h" else 9)
    if axis == "h":
        d.rectangle([0, 13, 31, 18], fill=C("P48")); d.line([0, 13, 31, 13], fill=C("P49"))
        for _ in range(3):
            x = rnd.randrange(0, 28)
            d.rectangle([x, 14, x + rnd.randint(1, 3), 17], fill=(0, 0, 0, 0))
    else:
        d.rectangle([13, 0, 18, 31], fill=C("P48")); d.line([13, 0, 13, 31], fill=C("P49"))
        for _ in range(3):
            y = rnd.randrange(0, 28)
            d.rectangle([14, y, 17, y + rnd.randint(1, 3)], fill=(0, 0, 0, 0))
    return im


def platform_stairs():
    """승강장으로 내려가는 계단(2×1): 지하철 출입구 꼴에 '승강장' 판 + 경비대 줄(지나갈 수 없다 — 승강장층 L-UG-01은 U01과 함께)."""
    from props_jm import subway_stairs
    im = subway_stairs("승강장")
    d = ImageDraw.Draw(im)
    d.line([2, 24, 61, 24], fill=C("P53"), width=2)                       # 가로지른 줄
    for x in range(6, 60, 8):
        d.line([x, 24, x + 4, 24], fill=C("P09"), width=2)
    d.rectangle([1, 20, 4, 30], fill=C("P05")); d.rectangle([59, 20, 62, 30], fill=C("P05"))
    return im


def rent_mat():
    """승강장 매트(1×1, 숙박 10캡 — SD-15 §5.5 V05): 승강장 고무 매트를 잘라 깐 잠자리 + 접은 담요 + 나무 번호표 '7'."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([2, 8, 29, 29], radius=2, fill=C("P03")); d.line([3, 8, 28, 8], fill=C("P05"))
    for y in range(11, 28, 3):
        d.line([4, y, 27, y], fill=C("P02"))                              # 고무 홈
    d.rectangle([5, 10, 17, 16], fill=C("P36")); d.line([5, 10, 17, 10], fill=C("P37"))   # 접은 담요
    d.line([5, 13, 17, 13], fill=C("P35"))
    d.rectangle([21, 22, 27, 28], fill=C("P20")); d.line([21, 22, 27, 22], fill=C("P21"))  # 번호표
    d.line([23, 24, 25, 24], fill=C("P02")); d.line([25, 24, 23, 27], fill=C("P02"))
    return im


def scrap_wall(seed=1):
    """고철 칸막이(2×1): 녹슨 함석 · 자동차 보닛 · 철문짝을 쇠기둥에 철사로 묶어 세웠다(사당 4번 출구 광장 둘레)."""
    rnd = random.Random(seed)
    im = img(66, 54)
    d = ImageDraw.Draw(im)
    x = 1
    while x < 62:
        w = rnd.randint(9, 15)
        top = rnd.randint(6, 14)
        col = rnd.choice(["P25", "P12", "P26", "P05", "P24", "P13", "P18"])
        d.rectangle([x, top, min(x + w, 64), 50], fill=C(col)); d.line([x, top, min(x + w, 64), top], fill=C("P07"))
        if col in ("P12", "P13", "P05"):
            for yy in range(top + 4, 48, 4):
                d.line([x + 1, yy, min(x + w, 64) - 1, yy], fill=C("P04"))      # 함석 골
        else:
            d.point((x + 2, top + 3), fill=C("P23")); d.line([x + w // 2, top + 6, x + w // 2 + 2, top + 14], fill=C("P23"))   # 녹 자국
        x += w
    for xx in (2, 32, 61):
        d.rectangle([xx, 2, xx + 2, 52], fill=C("P11")); d.line([xx, 2, xx, 52], fill=C("P13"))
    d.line([1, 22, 64, 20], fill=C("P05")); d.line([1, 38, 64, 40], fill=C("P05"))   # 철사
    return im


# ================================================================================================ 벽 소품
def w_sign_transfer():
    """환승촌 간판(4×0 벽): 2호선 녹색 · 4호선 하늘색 천을 이어 붙이고 흰 글씨 '사당 환승촌'."""
    im = img(128, 26)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 2, 63, 22], fill=C("P55")); d.rectangle([64, 2, 127, 22], fill=C("P62"))
    for x in range(4, 124, 6):
        d.point((x, 3), fill=C("P09")); d.point((x, 21), fill=C("P09"))  # 바느질 땀
    d.line([63, 2, 63, 22], fill=C("P09"))
    w, _ = put_text(img(1, 1), "사당 환승촌", 0, 0, "P09", 8, "Galmuri7")
    d.rounded_rectangle([60 - w // 2, 5, 67 + w // 2, 18], radius=2, fill=C("P02"))             # 글자 받침 천
    put_text(im, "사당 환승촌", 64 - w // 2, 7, "P09", 8, "Galmuri7")
    d.ellipse([6, 7, 18, 17], fill=C("P09")); put_text(im, "2", 10, 7, "P55", 8, "Galmuri7")
    d.ellipse([110, 7, 122, 17], fill=C("P09")); put_text(im, "4", 114, 7, "P61", 8, "Galmuri7")
    return im


def w_ad_vault():
    """2077 볼트 분양 광고판(2×0 벽, LR-09): '당첨되면 200년이 편안합니다' + 웃는 가족 + 볼트 문."""
    im = img(64, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 29], fill=C("P12")); d.rectangle([2, 2, 61, 27], fill=C("P50"))
    d.ellipse([6, 6, 22, 22], fill=C("P46")); d.ellipse([9, 9, 19, 19], fill=C("P45")); d.ellipse([12, 12, 16, 16], fill=C("P48"))   # 볼트 문
    for i, x in enumerate((28, 36, 44)):
        d.ellipse([x, 8, x + 6, 14], fill=C("P42")); d.rectangle([x, 14, x + 6, 22], fill=C(["P53", "P45", "P30"][i]))   # 가족
    put_text(im, "당첨되면 200년", 26, 0, "P02", 8, "Galmuri7") if False else None
    d.rectangle([4, 23, 59, 26], fill=C("P53"))
    return im


def w_clock_stopped():
    """멈춘 시계(1×0 벽): 둥근 역 시계 '11시 29분'."""
    im = img(28, 28)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 25, 25], fill=C("P11")); d.ellipse([4, 4, 23, 23], fill=C("P09"))
    for a in range(12):
        x = 13.5 + 8 * math.sin(a * math.pi / 6); y = 13.5 - 8 * math.cos(a * math.pi / 6)
        d.point((round(x), round(y)), fill=C("P04"))
    d.line([13, 13, 9, 11], fill=C("P02"), width=2)                      # 시침 11
    d.line([13, 13, 15, 22], fill=C("P02"))                              # 분침 29
    return im


def w_board_runs():
    """역무실 칠판(2×0 벽): '오늘의 운행 안내: 운행 없음' — 200년 날짜만 바뀐 줄."""
    im = img(64, 34)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 33], fill=C("P18")); d.rectangle([2, 2, 61, 31], fill=C("P29"))
    put_text(im, "운행 없음", 18, 3, "P08", 8, "Galmuri7")
    for y in range(15, 30, 4):
        d.line([5, y, 20, y], fill=C("P07")); d.line([24, y, 58, y], fill=C("P06"))
    return im


def w_sign_dark():
    """'빛 들이지 마시오' 표지(1×0 벽, 버섯 측실 입구)."""
    im = img(40, 18)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 39, 17], fill=C("P02")); d.rectangle([1, 1, 38, 16], fill=C("P48"))
    put_text(im, "빛 금지", 6, 4, "P02", 8, "Galmuri7")
    return im


def w_sign_lasttrain():
    """'막차 기다리는 손님 있음(들어가지 마시오)' 표지(2×0 벽, 2호선 서쪽 터널 철망)."""
    im = img(60, 22)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 59, 21], fill=C("P53")); d.rectangle([2, 2, 57, 19], fill=C("P09"))
    put_text(im, "막차 손님 있음", 4, 6, "P53", 8, "Galmuri7")
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_SD = {
    "sd_gate": _r(lambda: gate("shut"), 1, 1, down=-2),
    "sd_gate_wash": _r(lambda: gate("shut", True), 1, 1, down=-2),
    "sd_gate_open": _r(lambda: gate("push"), 1, 1, down=-2),
    "sd_weapon_rack": _r(weapon_rack, 2, 1, down=-2),
    "sd_tent_o": _r(lambda: tent("o", 1), 2, 2, down=-2),
    "sd_tent_b": _r(lambda: tent("b", 2), 2, 2, down=-2),
    "sd_tent_g": _r(lambda: tent("g", 3), 2, 2, down=-2),
    "sd_tent_y": _r(lambda: tent("y", 4), 2, 2, down=-2),
    "sd_mushroom": _r(mushroom_shelf, 2, 1, down=-2),
    "sd_fence": _r(wire_fence, 1, 1, down=-2),
    "sd_post": _r(caravan_post, 1, 1, down=-2),
    "sd_peddler": _r(lambda: peddler_tent(1), 2, 2, down=-2),
    "sd_peddler2": _r(lambda: peddler_tent(2), 2, 2, down=-2),
    "sd_guard_post": _r(guard_post, 2, 1, down=-2),
    "sd_station_desk": _r(station_desk, 2, 1, down=-2),
    "sd_banner": _r(banner, 3, 1, down=-2),
    "sd_rent_mat": _r(rent_mat, 1, 1, down=-4),
    "sd_scrap_wall": _r(lambda: scrap_wall(1), 2, 1, down=-2),
    "sd_scrap_wall2": _r(lambda: scrap_wall(2), 2, 1, down=-2),
    "sd_exit4": _r(lambda: exit_stairs(4), 2, 1, down=2),
    "sd_exit6": _r(lambda: exit_stairs(6, True), 2, 1, down=-2),
    "sd_exit10": _r(lambda: exit_stairs(10, True), 2, 1, down=-2),
    "sd_line_h": _r(lambda: wait_line("h"), 0, 0, "deco"),
    "sd_line_v": _r(lambda: wait_line("v"), 0, 0, "deco"),
    "sd_platform_stairs": _r(platform_stairs, 2, 1, down=-2),
    "w_sd_sign": _r(w_sign_transfer, 4, 0, "wall", dx=0, dy=4),
    "w_sd_ad": _r(w_ad_vault, 2, 0, "wall", dx=0, dy=2),
    "w_sd_clock": _r(w_clock_stopped, 1, 0, "wall", dx=2, dy=4),
    "w_sd_board": _r(w_board_runs, 2, 0, "wall", dx=0, dy=1),
    "w_sd_dark": _r(w_sign_dark, 1, 0, "wall", dx=0, dy=8),
    "w_sd_lasttrain": _r(w_sign_lasttrain, 2, 0, "wall", dx=2, dy=6),
}
