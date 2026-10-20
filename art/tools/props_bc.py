"""관악산 비탈·봉천 계단마을 바깥 소품(단계 0-10, SD-16 §7·§8 아이작풍): 굵은 먹선 + 둥근 덩어리 + 왼쪽 위 빛.
props_s07과 같은 등록 형식(_r) — tools/pipeline/prop_export.py가 r01_props.png/json으로 낸다(먹선은 내보낼 때 두른다).
foot = 막히는 칸(가로, 세로), kind floor(발 칸 아래 변에 그림 아래 + down) · deco(막지 않음).
상태 그림(STATES)은 연출이 바꾼다: 게시판(MQ-101 해법 5가지마다 다른 쪽지), 철문(열림·닫힘), 드럼통 모닥불(밤).
"""
import os, sys, math, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import tiles_isaac as TI
from struct_r01 import put_text, text_px, streak, step_px, window, hsh

T = 32
C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def lump(im, cx, cy, rx, ry, ramp, hi=0.62):
    TI.lump(im, cx, cy, rx, ry, ramp, hi)


# ================================================================================================ 자연
GREEN = ["P28", "P29", "P30", "P31"]
PINE = ["P28", "P28", "P29", "P30"]
MAPLE = ["P23", "P24", "P25", "P26"]
OAK = ["P18", "P19", "P20", "P21"]
GINKGO = ["P47", "P19", "P48", "P49"]


def _trunk(im, x, y0, y1, w=6):
    d = ImageDraw.Draw(im)
    d.rectangle([x - w // 2, y0, x + w // 2 - 1, y1], fill=C("P17"))
    d.line([x - w // 2, y0, x - w // 2, y1], fill=C("P18"))
    d.line([x - w // 2 + 1, y0, x - w // 2 + 1, y1], fill=C("P19"))
    d.line([x + w // 2 - 1, y0, x + w // 2 - 1, y1], fill=C("P16"))
    for yy in range(y0 + 3, y1, 5):                                       # 껍질 결
        d.point((x, yy), fill=C("P16"))
    d.line([x - w // 2 - 2, y1, x - w // 2, y1 - 2], fill=C("P17"))      # 뿌리
    d.line([x + w // 2 + 1, y1, x + w // 2 - 1, y1 - 2], fill=C("P17"))


def tree(kind="oak", size=1.0, seed=0):
    """나무(3/4 시점): 줄기 + 둥근 수관 덩이(빛 왼쪽 위). kind pine·oak·maple·ginkgo·dead. 발 = 줄기 밑동."""
    rnd = random.Random(hsh(seed, 3, int(size * 10)))
    r = int(26 * size)
    W, H = 2 * r + 10, int(2 * r + 26 * size + 8)
    im = img(W, H)
    cx, base = W // 2, H - 3
    top = H - int(26 * size) - 2
    _trunk(im, cx, top - 10, base, 6 if size >= 0.9 else 4)
    if kind == "dead":
        d = ImageDraw.Draw(im)
        for a, l in ((-0.9, 0.8), (-0.3, 1.0), (0.4, 0.9), (1.0, 0.7)):
            x1, y1 = cx + int(math.sin(a) * r * l), top - 10 - int(math.cos(a) * r * l)
            d.line([cx, top - 6, x1, y1], fill=C("P17"), width=2)
            d.line([x1, y1, x1 + rnd.randint(-5, 5), y1 - 6], fill=C("P17"))
        return im
    ramp = {"pine": PINE, "oak": OAK if rnd.random() < 0.0 else GREEN, "maple": MAPLE, "ginkgo": GINKGO}[kind]
    if kind == "oak":
        ramp = rnd.choice([GREEN, ["P29", "P30", "P31", "P32"]])               # 10월 말 참나무: 초록·누런 올리브
    cy = top - r + 6
    if kind == "pine":                                                    # 소나무: 층층 덩이(아래 넓고 위 좁게)
        for k, (dy, rx) in enumerate(((0.55, 1.0), (0.1, 0.85), (-0.35, 0.65), (-0.75, 0.4))):
            yy = cy + dy * r
            for j in (-1, 0, 1):
                lump(im, cx + j * rx * r * 0.45 + rnd.uniform(-2, 2), yy + abs(j) * 3, rx * r * 0.55, r * 0.38, ramp)
    else:
        lump(im, cx, cy, r * 0.92, r * 0.82, ramp)
        for k in range(7):
            a = k * math.pi * 2 / 7 + rnd.uniform(-0.3, 0.3)
            lump(im, cx + math.cos(a) * r * 0.5, cy + math.sin(a) * r * 0.42, r * 0.5, r * 0.44, ramp)
        lump(im, cx - r * 0.22, cy - r * 0.28, r * 0.42, r * 0.36, ramp[1:] + [ramp[-1]])
    px = im.load()                                                        # 잎 덩이 사이 어두운 틈 몇 점
    for _ in range(int(r * r * 0.05)):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if px[x, y][3] and px[x, y][:3] == P.rgb(ramp[2]):
            px[x, y] = C(ramp[1])
    return im


def bush(col="g", seed=0, w=30, h=22):
    ramp = {"g": GREEN, "a": MAPLE, "y": ["P29", "P30", "P31", "P32"]}[col]
    im = img(w + 2, h + 2)
    rnd = random.Random(seed)
    for cx, cy, rx, ry in ((w * 0.33, h * 0.62, w * 0.3, h * 0.36), (w * 0.68, h * 0.6, w * 0.3, h * 0.36), (w * 0.5, h * 0.38, w * 0.3, h * 0.32)):
        lump(im, cx + 1 + rnd.uniform(-1, 1), cy + 1, rx, ry, ramp)
    return im


def boulder(rx, ry, seed=0):
    w, h = int(rx * 2 + 6), int(ry * 2 + 8)
    im = img(w, h)
    rnd = random.Random(seed)
    ramp = ["P04", "P05", "P06", "P07"]
    lump(im, w / 2, h / 2 + 1, rx, ry, ramp)
    for _ in range(2 if rx > 12 else 1):
        lump(im, w / 2 + rnd.uniform(-rx * 0.4, rx * 0.4), h / 2 - rnd.uniform(0, ry * 0.4), rx * rnd.uniform(0.4, 0.6),
             ry * rnd.uniform(0.4, 0.6), ramp)
    d = ImageDraw.Draw(im)
    cx = int(w / 2 + rnd.uniform(-rx * 0.3, rx * 0.3))
    d.line([cx, h / 2 - ry * 0.5, cx + 2, h / 2, cx + 1, h / 2 + ry * 0.4], fill=C("P03"))
    d.point((int(w / 2 - rx * 0.5), int(h / 2 - ry * 0.45)), fill=C("P08"))
    px = im.load()
    for _ in range(int(rx * ry * 0.15)):                                  # 지의류
        x, y = rnd.randrange(w), rnd.randrange(h)
        if px[x, y][3] and px[x, y][:3] in (P.rgb("P06"), P.rgb("P05")):
            px[x, y] = C(rnd.choice(["P31", "P32"]))
    return im


def tuft(seed=0):
    im = img(14, 10)
    rnd = random.Random(seed)
    px = im.load()
    for k in range(5):
        x = 2 + k * 2 + rnd.randint(0, 1)
        hgt = rnd.randint(4, 8)
        col = rnd.choice(["P29", "P30", "P31", "P21", "P20"])
        for t in range(hgt):
            xx = x + (t // 3) * (1 if k > 2 else -1 if k < 2 else 0)
            if 0 <= xx < 14:
                px[xx, 9 - t] = C(col)
    return im


def stump():
    im = img(22, 18)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 6, 17, 16], fill=C("P18"))
    d.line([4, 6, 4, 16], fill=C("P19"))
    d.line([17, 6, 17, 16], fill=C("P16"))
    d.ellipse([3, 2, 18, 9], fill=C("P20"))
    d.ellipse([6, 3, 15, 8], fill=C("P21"))
    d.ellipse([9, 4, 12, 6], outline=C("P19"))
    return im


# ================================================================================================ 볼트 앞·전망바위
def exit_terminal():
    """출구 점검표 단말(SD-03a §7.4 S6): 기둥 위 진공관 단말, 호박색 화면, 볼트 청·황 띠."""
    im = img(22, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([9, 18, 12, 42], fill=C("P05")); d.line([9, 18, 9, 42], fill=C("P07")); d.line([12, 18, 12, 42], fill=C("P03"))
    d.rectangle([6, 38, 15, 43], fill=C("P04")); d.line([6, 38, 15, 38], fill=C("P06"))
    d.rectangle([1, 2, 20, 19], fill=C("P44"))
    d.rectangle([1, 2, 20, 4], fill=C("P45"))
    d.rectangle([1, 15, 20, 19], fill=C("P48")); d.line([1, 15, 20, 15], fill=C("P49"))
    d.rectangle([4, 5, 17, 13], fill=C("P01"))
    d.rectangle([5, 6, 16, 12], fill=C("A2"))
    for yy in (7, 9, 11):
        d.line([6, yy, 6 + (yy * 3) % 9 + 3, yy], fill=C("A6"))
    d.point((15, 7), fill=C("A7"))
    return im


def telescope():
    """동전 망원경(2077년 등산로 쉼터): 기둥 + 쌍안 몸통 + 동전 투입구."""
    im = img(24, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([10, 18, 13, 38], fill=C("P05")); d.line([10, 18, 10, 38], fill=C("P07"))
    d.rectangle([6, 35, 17, 39], fill=C("P04")); d.line([6, 35, 17, 35], fill=C("P06"))
    lump(im, 12, 11, 9, 7, ["P43", "P44", "P45", "P46"])                    # 바랜 청색 몸통
    d.rectangle([2, 5, 8, 9], fill=C("P02")); d.rectangle([16, 5, 22, 9], fill=C("P02"))   # 접안경 둘
    d.ellipse([3, 4, 8, 9], fill=C("P11")); d.ellipse([16, 4, 21, 9], fill=C("P11"))
    d.point((5, 5), fill=C("P14")); d.point((18, 5), fill=C("P14"))
    d.rectangle([10, 13, 14, 15], fill=C("P48")); d.line([11, 14, 13, 14], fill=C("P01"))
    for _ in range(4):
        d.point((random.Random(3).randint(6, 18), 12), fill=C("P24"))
    return im


def info_board():
    """2077년 전망 안내판(기울어진 철판): '맑은 날에는 여의도 국회 돔과 남산 타워가 보입니다'(절반만 맞다)."""
    im = img(34, 34)
    d = ImageDraw.Draw(im)
    for x in (6, 26):
        d.rectangle([x, 16, x + 2, 33], fill=C("P05")); d.line([x, 16, x, 33], fill=C("P07"))
    d.polygon([(1, 4), (33, 1), (33, 19), (1, 21)], fill=C("P44"))
    d.polygon([(3, 6), (31, 3), (31, 17), (3, 19)], fill=C("P15"))
    d.line([5, 8, 28, 6], fill=C("P11")); d.line([5, 11, 22, 10], fill=C("P11")); d.line([5, 14, 26, 12], fill=C("P11"))
    d.polygon([(19, 15), (24, 11), (29, 15)], fill=C("P12"))                   # 지도 위 산 모양
    for x, y in ((9, 16), (20, 4), (28, 8)):
        d.point((x, y), fill=C("P24"))
    return im


# ================================================================================================ 봉천: 게시판·개집·물탱크·망루
NOTE_COLS = ["P09", "P08", "P22", "P15"]


def notice_board(state="base"):
    """반상회 게시판(앵커): 지붕 달린 나무 판 + 쪽지. 상태(MQ-101): base 소식만 · wanted 수배 쪽지(손글씨, 인상착의) ·
    torn 쪽지가 찢겨 바닥에(방어) · crumpled 구겨 던진 쪽지 + '하수구 조심'(유인) · crossed 쪽지에 '강 건넜음' 낙서(거짓말) ·
    rate 쪽지 그대로 + '오늘의 인력 단가'(돈) · water 쪽지 그대로 + '물값 2배'(마을을 판다) · official 공보방송 정식 공고(BJ 우세)."""
    W_, H_ = 66, 58
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    for x in (5, 58):                                                     # 기둥
        d.rectangle([x, 12, x + 3, 57], fill=C("P18")); d.line([x, 12, x, 57], fill=C("P19")); d.line([x + 3, 12, x + 3, 57], fill=C("P16"))
    d.polygon([(0, 10), (33, 1), (65, 10), (65, 13), (0, 13)], fill=C("P24"))   # 함석 지붕
    for x in range(2, 64, 4):
        d.line([x, 13, x + (1 if x < 33 else -1) * 0, 5 + abs(x - 33) // 4], fill=C("P25"))
    d.line([0, 13, 65, 13], fill=C(INK))
    d.rectangle([3, 15, 62, 46], fill=C("P18"))
    d.rectangle([5, 17, 60, 44], fill=C("P20"))
    d.line([5, 17, 60, 17], fill=C("P21"))
    rnd = random.Random(11)
    notes = [(7, 19, 12, 10), (21, 21, 10, 9), (47, 19, 11, 12), (8, 32, 9, 9), (49, 33, 9, 9)]
    for (x, y, w, h) in notes:                                            # 마을 소식 쪽지(물 배급·텃밭 당번·분실물)
        col = rnd.choice(NOTE_COLS)
        d.rectangle([x, y, x + w, y + h], fill=C(col), outline=C("P06"))
        d.point((x + w // 2, y + 1), fill=C(rnd.choice(("P53", "P45", "P49"))))
        for yy in range(y + 3, y + h - 1, 2):
            d.line([x + 2, yy, x + w - 2 - rnd.randint(0, 3), yy], fill=C("P05"))
    old = (7, 41, 15, 3)                                                  # 맨 아래 누렇게 바랜 2077년 대피소 공지
    d.rectangle([33, 37, 46, 44], fill=C("P21"), outline=C("P19"))
    d.line([35, 40, 44, 40], fill=C("P19")); d.line([35, 42, 42, 42], fill=C("P19"))
    def wanted(x, y, tilt=0):
        d.rectangle([x, y, x + 16, y + 17], fill=C("P09"), outline=C("P05"))
        put_text(im, "수배", x + 1, y - 1, "P52", 8, "Galmuri7")
        d.rectangle([x + 3, y + 8, x + 8, y + 14], fill=C("P45"))          # 인상착의: 볼트 점프슈트(청·황)
        d.line([x + 3, y + 10, x + 8, y + 10], fill=C("P49"))
        d.ellipse([x + 4, y + 5, x + 7, y + 8], fill=C("P06"))
        d.line([x + 10, y + 9, x + 14, y + 9], fill=C("P04")); d.line([x + 10, y + 12, x + 15, y + 12], fill=C("P04"))
        d.point((x + 8, y), fill=C("P53"))
    if state in ("wanted", "rate", "water", "crossed"):
        wanted(28, 22)
    if state == "crossed":                                                # 쪽지 위에 휘갈긴 '강 건넜음'
        d.line([27, 25, 46, 37], fill=C("P53")); d.line([28, 25, 47, 37], fill=C("P53"))
        put_text(im, "강건넘", 27, 34, "P52", 8, "Galmuri7")
    if state == "rate":
        d.rectangle([9, 30, 24, 43], fill=C("P15"), outline=C("P12"))
        put_text(im, "단가", 10, 30, "P44", 8, "Galmuri7")
        for yy in (38, 40, 42):
            d.line([11, yy, 22, yy], fill=C("P12"))
    if state == "water":
        d.rectangle([7, 29, 25, 44], fill=C("P53"), outline=C("P52"))
        put_text(im, "물값", 9, 29, "P09", 8, "Galmuri7")
        put_text(im, "×2", 11, 36, "P50", 8, "Galmuri7")
    if state == "torn":                                                   # 압정에 찢긴 귀퉁이만
        d.polygon([(28, 22), (35, 22), (31, 27)], fill=C("P09"))
        d.point((29, 22), fill=C("P53"))
        d.rectangle([28, 26, 44, 35], fill=C("P22"), outline=C("P19"))     # 감시조 감사 쪽지
        put_text(im, "고맙다", 28, 26, "P17", 8, "Galmuri7")
    if state == "crumpled":
        d.polygon([(28, 22), (33, 22), (30, 26)], fill=C("P09"))
        d.rectangle([27, 27, 45, 36], fill=C("P08"), outline=C("P06"))
        put_text(im, "하수구", 28, 27, "P44", 8, "Galmuri7")
    if state == "official":
        d.rectangle([24, 19, 46, 40], fill=C("P09"), outline=C("P44"))
        d.rectangle([24, 19, 46, 23], fill=C("P44"))
        d.rectangle([28, 26, 34, 33], fill=C("P06"))
        for yy in (27, 30, 33, 36):
            d.line([36, yy, 44, yy], fill=C("P04"))
    if state in ("torn",):
        pass
    return im


def kennel(name="백구"):
    """개집(지붕 달린 나무 상자 + 이름판) + 물그릇 + '백구 밥 당번표' 판(옆 기둥)."""
    im = img(62, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 16, 33, 38], fill=C("P19"))                           # 상자
    for y in range(18, 38, 4):
        d.line([4, y, 33, y], fill=C("P18"))
    d.line([4, 16, 4, 38], fill=C("P20"))
    d.polygon([(1, 17), (18, 4), (36, 17)], fill=C("P25"))                # 지붕
    d.line([1, 17, 36, 17], fill=C(INK))
    d.line([18, 4, 18, 17], fill=C("P24"))
    d.rectangle([12, 24, 25, 38], fill=C("P02"))                          # 입구(둥근 위)
    d.ellipse([12, 20, 25, 30], fill=C("P02"))
    d.rectangle([10, 14, 27, 19], fill=C("P09"), outline=C("P05"))
    put_text(im, name, 11, 12, "P17", 8, "Galmuri7")
    d.ellipse([36, 32, 44, 38], fill=C("P06")); d.ellipse([37, 33, 43, 36], fill=C("P37"))   # 물그릇
    d.rectangle([48, 10, 50, 39], fill=C("P18"))                          # 당번표 기둥 + 판
    d.rectangle([42, 6, 61, 24], fill=C("P09"), outline=C("P19"))
    put_text(im, "밥당번", 43, 5, "P02", 8, "Galmuri7")
    for yy in (14, 17, 20, 23):
        d.line([44, yy, 59, yy], fill=C("P07"))
    for k in range(4):
        d.point((46 + k * 4, 15 + (k % 2) * 3), fill=C("P53"))
    return im


def water_tank(big=True):
    """옥상 물탱크(바랜 청색 FRP 원통) + 받침 + 관. 6개를 관으로 이은 '마을 물탱크'의 한 칸."""
    w, h = (56, 60) if big else (30, 38)
    im = img(w, h)
    d = ImageDraw.Draw(im)
    bx0, bx1 = 4, w - 5
    d.rectangle([bx0, h - 10, bx1, h - 2], fill=C("P05"))                 # 철 받침
    for x in range(bx0, bx1, 8):
        d.line([x, h - 10, x + 4, h - 2], fill=C("P04"))
    d.line([bx0, h - 10, bx1, h - 10], fill=C("P07"))
    ramp = ["P43", "P44", "P45", "P46"]
    top = 6
    for x in range(bx0 + 2, bx1 - 1):                                     # 원통 몸(세로 음영)
        nx = (x - (bx0 + bx1) / 2) / ((bx1 - bx0) / 2)
        col = ramp[3] if nx < -0.55 else ramp[2] if nx < 0.1 else ramp[1] if nx < 0.7 else ramp[0]
        d.line([x, top + 6, x, h - 11], fill=C(col))
    for y in range(top + 14, h - 12, 9):                                  # 띠
        d.line([bx0 + 2, y, bx1 - 2, y], fill=C(ramp[0]))
    d.ellipse([bx0 + 2, top, bx1 - 2, top + 12], fill=C(ramp[2]))
    d.ellipse([bx0 + 5, top + 2, bx1 - 5, top + 10], fill=C(ramp[3]))
    d.ellipse([(bx0 + bx1) // 2 - 4, top + 3, (bx0 + bx1) // 2 + 4, top + 8], fill=C(ramp[1]))   # 뚜껑
    rnd = random.Random(w)
    for _ in range(5):                                                    # 바램·이끼 줄
        x = rnd.randint(bx0 + 4, bx1 - 4)
        streak(im, x, top + 12, rnd.randint(6, h - 30), -1, rnd)
    d.rectangle([bx1 - 2, h - 20, w - 1, h - 17], fill=C("P06"))          # 옆으로 나간 관
    d.line([bx1 - 2, h - 20, w - 1, h - 20], fill=C("P08"))
    if big:
        d.rectangle([bx0 + 10, h - 30, bx0 + 22, h - 22], fill=C("P09"), outline=C("P05"))
        put_text(im, "식수", bx0 + 10, h - 31, "P44", 8, "Galmuri7")
    return im


def watchtower():
    """망루(봉천 앵커): 철제 비계 + 판자 바닥 + 함석 지붕 + 모래주머니 + 사다리. 2×2 발, 높이 약 3타일."""
    W_, H_ = 66, 112
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    for x in (6, 56):                                                     # 다리(비계 파이프)
        d.rectangle([x, 44, x + 3, H_ - 2], fill=C("P05")); d.line([x, 44, x, H_ - 2], fill=C("P07"))
    for y in range(52, H_ - 4, 18):                                       # 가새
        d.line([9, y, 56, y + 14], fill=C("P04")); d.line([56, y, 9, y + 14], fill=C("P04"))
        d.line([6, y, 59, y], fill=C("P05"))
    for y in range(48, H_ - 2, 6):                                        # 사다리(가운데)
        d.line([28, y, 37, y], fill=C("P06"))
    d.line([27, 44, 27, H_ - 2], fill=C("P05")); d.line([38, 44, 38, H_ - 2], fill=C("P05"))
    d.rectangle([1, 34, 64, 46], fill=C("P19"))                           # 판자 바닥 + 모래주머니 난간
    d.line([1, 46, 64, 46], fill=C(INK))
    for k, x in enumerate(range(2, 62, 10)):
        lump(im, x + 5, 34, 6, 4, ["P19", "P20", "P21", "P22"])
        d.line([x + 2, 33, x + 8, 33], fill=C("P20"))
    for x in (4, 58):                                                     # 지붕 기둥
        d.rectangle([x, 10, x + 2, 34], fill=C("P18"))
    d.polygon([(0, 12), (33, 2), (65, 12), (65, 16), (0, 16)], fill=C("P25"))
    for x in range(1, 65, 4):
        d.line([x, 16, x, 8 + abs(x - 33) // 5], fill=C("P26"))
    d.line([0, 16, 65, 16], fill=C(INK))
    d.rectangle([20, 18, 46, 32], fill=C("P02"))                          # 안쪽 어둠 + 탐조등
    lump(im, 33, 26, 6, 5, ["P04", "P05", "P07", "P09"])
    d.point((31, 24), fill=C("P50"))
    return im


def utility_pole():
    """콘크리트 전신주 + 완목·애자 + 죽은 변압기(전원 없음 200년)."""
    im = img(36, 120)
    d = ImageDraw.Draw(im)
    d.rectangle([15, 8, 20, 118], fill=C("P06")); d.line([15, 8, 15, 118], fill=C("P08")); d.line([20, 8, 20, 118], fill=C("P04"))
    for y in range(30, 118, 9):
        d.point((17, y), fill=C("P04"))
    d.rectangle([2, 14, 33, 17], fill=C("P05")); d.line([2, 14, 33, 14], fill=C("P07"))
    for x in (4, 12, 23, 31):
        d.rectangle([x - 1, 10, x + 1, 13], fill=C("P09"))
    lump(im, 26, 34, 6, 8, ["P04", "P05", "P06", "P07"])                  # 변압기 통
    d.line([20, 30, 22, 30], fill=C("P04"))
    d.rectangle([10, 70, 25, 80], fill=C("P09"), outline=C("P05"))        # 붙인 전단 한 장
    d.line([12, 73, 22, 73], fill=C("P05")); d.line([12, 76, 20, 76], fill=C("P05"))
    return im


def planter(kind="lettuce", seed=0):
    """계단 텃밭 화분: 스티로폼 상자(흰) 또는 고무 대야(검붉은) + 채소(상추·고추·파)."""
    rnd = random.Random(seed)
    im = img(30, 26)
    d = ImageDraw.Draw(im)
    if seed % 2 == 0:
        d.rectangle([2, 12, 27, 24], fill=C("P08")); d.line([2, 12, 27, 12], fill=C("P09")); d.line([2, 24, 27, 24], fill=C("P06"))
        d.line([27, 12, 27, 24], fill=C("P06"))
    else:
        d.ellipse([1, 10, 28, 25], fill=C("P24")); d.ellipse([3, 11, 26, 17], fill=C("P17"))
        d.line([4, 14, 25, 14], fill=C("P25"))
    if kind == "lettuce":
        for x in (7, 15, 22):
            lump(im, x, 11, 5, 4, ["P29", "P30", "P31", "P32"])
    elif kind == "pepper":
        for x in (8, 15, 22):
            d.line([x, 12, x, 4], fill=C("P29"))
            lump(im, x, 6, 4, 3, ["P29", "P30", "P31", "P31"])
            d.rectangle([x + 1, 8, x + 2, 11], fill=C("P53"))
    else:
        for x in range(6, 25, 3):
            h_ = rnd.randint(5, 10)
            d.line([x, 12, x, 12 - h_], fill=C("P31")); d.point((x, 12 - h_), fill=C("P32"))
    return im


def scrap_pile(seed=0):
    rnd = random.Random(seed)
    im = img(64, 36)
    d = ImageDraw.Draw(im)
    for _ in range(14):
        x, y = rnd.randint(4, 54), rnd.randint(10, 28)
        w, h = rnd.randint(6, 16), rnd.randint(4, 9)
        tone = rnd.choice([("P04", "P05", "P06"), ("P24", "P25", "P26"), ("P12", "P13", "P14"), ("P17", "P18", "P19")])
        d.rectangle([x, y, x + w, y + h], fill=C(tone[1]))
        d.line([x, y, x + w, y], fill=C(tone[2]))
        d.line([x, y + h, x + w, y + h], fill=C(tone[0]))
    lump(im, 20, 22, 9, 7, ["P04", "P05", "P06", "P07"])                  # 바퀴
    d.ellipse([16, 18, 24, 26], fill=C("P02")); d.ellipse([18, 20, 22, 24], fill=C("P06"))
    d.line([40, 6, 52, 20], fill=C("P05"), width=2)                       # 삐죽 나온 쇠파이프
    return im


def scale():
    """고철 저울(오봉수 가게): 바닥 저울판 + 기둥 + 둥근 눈금판."""
    im = img(30, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 30, 28, 38], fill=C("P05")); d.rectangle([2, 30, 27, 32], fill=C("P07"))
    for x in range(4, 27, 4):
        d.line([x, 33, x, 37], fill=C("P04"))
    d.rectangle([20, 8, 23, 30], fill=C("P05")); d.line([20, 8, 20, 30], fill=C("P07"))
    d.ellipse([12, 1, 29, 17], fill=C(INK)); d.ellipse([13, 2, 28, 16], fill=C("P09"))
    for a in range(0, 360, 30):
        x, y = 20.5 + math.cos(math.radians(a)) * 6, 9 + math.sin(math.radians(a)) * 6
        d.point((int(x), int(y)), fill=C("P04"))
    d.line([20, 9, 24, 5], fill=C("P53"))
    return im


def stall_counter(seed=0):
    """노점 매대(나무 판 + 함석 차양) 위 물건: 통조림·캡 깡통·전지·병."""
    rnd = random.Random(seed)
    im = img(66, 46)
    d = ImageDraw.Draw(im)
    for x in (2, 61):
        d.rectangle([x, 4, x + 2, 44], fill=C("P18"))
    d.polygon([(0, 6), (65, 2), (65, 9), (0, 12)], fill=C("P45"))        # 차양(바랜 청 방수포)
    for x in range(0, 66, 8):
        d.line([x, 6 - x // 16, x, 11 - x // 16], fill=C("P44"))
    d.line([0, 12, 65, 9], fill=C(INK))
    d.rectangle([1, 28, 64, 44], fill=C("P19"))
    d.rectangle([1, 26, 64, 29], fill=C("P20")); d.line([1, 26, 64, 26], fill=C("P21"))
    for y in range(32, 44, 5):
        d.line([2, y, 63, y], fill=C("P18"))
    x = 4
    while x < 60:
        kind = rnd.random()
        if kind < 0.35:
            d.rectangle([x, 19, x + 4, 25], fill=C("P07")); d.line([x, 19, x + 4, 19], fill=C("P09"))
            d.line([x, 22, x + 4, 22], fill=C(rnd.choice(["P53", "P45", "P49"])))
            x += 6
        elif kind < 0.6:
            d.rectangle([x + 1, 16, x + 3, 25], fill=C(rnd.choice(["P36", "P26", "P46"]))); d.rectangle([x + 1, 14, x + 3, 15], fill=C("P05"))
            x += 5
        elif kind < 0.8:
            d.rectangle([x, 20, x + 6, 25], fill=C("P05")); d.rectangle([x + 1, 21, x + 5, 22], fill=C("P49"))
            x += 8
        else:
            d.ellipse([x, 21, x + 7, 25], fill=C("P06")); d.ellipse([x + 1, 21, x + 6, 23], fill=C("P26"))   # 병뚜껑 깡통(캡)
            x += 9
    return im


def forge():
    """대장간 화로: 원자력 온수기 돔(2077 옥상 설비)을 뜯어 만든 화로 + 풀무 + 붉은 불."""
    im = img(66, 50)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 30, 46, 48], fill=C("P05")); d.line([6, 30, 46, 30], fill=C("P07"))   # 벽돌 받침
    for y in range(33, 48, 4):
        for x in range(6 + (4 if (y // 4) % 2 else 0), 46, 8):
            d.line([x, y, x, y + 3], fill=C("P04"))
    lump(im, 26, 22, 20, 14, ["P12", "P13", "P14", "P15"])                # 돔(바랜 금속)
    d.arc([8, 8, 44, 36], 200, 340, fill=C("P11"))
    d.rectangle([16, 22, 36, 32], fill=C(INK))                            # 아궁이
    d.rectangle([17, 23, 35, 31], fill=C("P53"))
    d.rectangle([19, 25, 33, 31], fill=C("P54")); d.rectangle([22, 27, 30, 31], fill=C("P50"))
    d.ellipse([20, 3, 32, 11], fill=C("P46")); d.point((26, 7), fill=C("P50"))   # 원자 마크(바램)
    d.ellipse([22, 5, 30, 9], outline=C("P44"))
    d.rectangle([48, 26, 64, 44], fill=C("P18"))                          # 풀무
    d.polygon([(48, 26), (64, 30), (64, 40), (48, 44)], fill=C("P24"))
    d.line([48, 35, 64, 35], fill=C("P23"))
    return im


def hangyeol_bench():
    """한결 공구 작업대(SD-13 §7.9.1, 1-8c): 2077년 공구 매장 진열형 — 철제 상판 · 바이스 · 공구 걸이판 · 한결 로고 판.
    걸이판에 스패너·망치·톱·드라이버, 상판에 부품 상자와 기름통, 아래 선반에 철제 공구함. 2×1칸, 걸이판이 칸 위로 솟는다."""
    im = img(66, 58)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 4, 58, 30], fill=C("P18"))                           # 공구 걸이판(타공 합판)
    d.rectangle([7, 5, 57, 29], fill=C("P19"))
    for y in range(8, 29, 4):
        for x in range(9, 57, 4):
            d.point((x, y), fill=C("P18"))
    d.rectangle([18, 0, 47, 11], fill=C("P46"))                          # 한결 로고 판(바랜 청 + 주황 사각 마크)
    d.line([18, 11, 47, 11], fill=C("P44"))
    d.rectangle([20, 3, 24, 8], fill=C("P53")); d.rectangle([21, 4, 22, 5], fill=C("P54"))
    put_text(im, "한결", 27, 1, "P09", 8, "Galmuri7")
    d.line([11, 14, 13, 24], fill=C("P06")); d.ellipse([9, 12, 14, 16], outline=C("P07"))  # 스패너
    d.rectangle([18, 15, 19, 25], fill=C("P20")); d.rectangle([15, 13, 22, 15], fill=C("P05"))  # 망치
    d.polygon([(27, 15), (39, 15), (39, 20), (27, 18)], fill=C("P12")); d.rectangle([39, 14, 43, 20], fill=C("P24"))   # 톱
    for x in range(28, 39, 2):
        d.point((x, 19), fill=C("P11"))
    d.rectangle([47, 10, 48, 18], fill=C("P53")); d.rectangle([47, 19, 48, 25], fill=C("P07"))    # 드라이버
    d.rectangle([51, 10, 52, 17], fill=C("P45")); d.rectangle([51, 18, 52, 24], fill=C("P07"))
    d.rectangle([2, 30, 63, 36], fill=C("P13"))                          # 철제 상판
    d.line([2, 30, 63, 30], fill=C("P15")); d.line([2, 36, 63, 36], fill=C("P11"))
    d.rectangle([5, 26, 14, 30], fill=C("P05")); d.rectangle([6, 27, 13, 29], fill=C("P53"))      # 부품 상자(붉은 서랍)
    d.rectangle([17, 25, 21, 30], fill=C("P26")); d.line([18, 24, 20, 24], fill=C("P07"))         # 기름통
    d.rectangle([30, 28, 36, 30], fill=C("P06")); d.point((32, 27), fill=C("P53"))                # 부품(회로 기판 조각)
    d.rectangle([50, 24, 60, 30], fill=C("P12")); d.rectangle([53, 22, 57, 24], fill=C("P11"))     # 바이스
    d.line([60, 27, 64, 27], fill=C("P06")); d.rectangle([63, 25, 64, 29], fill=C("P05"))
    d.line([50, 27, 60, 27], fill=C("P11"))
    for x in (4, 60):                                                    # 다리
        d.rectangle([x, 36, x + 2, 56], fill=C("P11"))
    d.rectangle([4, 46, 62, 48], fill=C("P12"))                          # 아래 선반
    d.rectangle([10, 39, 30, 46], fill=C("P53")); d.rectangle([10, 39, 30, 41], fill=C("P54"))    # 철제 공구함(빨강)
    d.rectangle([18, 37, 22, 39], fill=C("P06"))
    d.rectangle([36, 41, 44, 46], fill=C("P05")); d.rectangle([47, 42, 55, 46], fill=C("P18"))    # 깡통 · 나무 상자
    return im


def hunter_shack():
    """관악산 사냥꾼 엄태경의 오두막(1-8d, SD-09a N-R01-033 '산/아랫문 오두막'): 판자 벽 + 녹슨 함석 지붕(돌로 눌러 둠) +
    양철 연통 + 널문(가죽 발) + 처마에 말리는 육포 줄 + 문 옆 멧돼지 엄니 두 개. 3×2칸."""
    im = img(100, 74)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 30, 92, 72], fill=C("P18"))                          # 판자 벽
    for x in range(10, 92, 7):
        d.line([x, 31, x, 71], fill=C("P17"))
        d.point((x + 3, 40 + (x * 7) % 20), fill=C("P16"))                # 옹이
    d.line([8, 52, 92, 52], fill=C("P17"))
    d.polygon([(2, 34), (50, 10), (98, 34), (98, 38), (50, 15), (2, 38)], fill=C("P05"))   # 함석 지붕(처마)
    d.polygon([(6, 34), (50, 13), (94, 34)], fill=C("P26"))               # 녹 슨 지붕면
    for i, x in enumerate(range(12, 90, 9)):
        y = 13 + abs(50 - x) * 21 // 44
        d.line([x, y + 2, x + 1, 33], fill=C("P25" if i % 2 else "P27"))  # 골함석 줄(지붕면 안에서만)
    for (x, y) in ((28, 24), (66, 22), (48, 15)):                         # 지붕 누름돌
        lump(im, x, y, 4, 3, ["P04", "P05", "P06", "P07"])
    d.rectangle([70, 2, 75, 20], fill=C("P12")); d.rectangle([69, 1, 76, 4], fill=C("P11"))   # 양철 연통
    d.rectangle([40, 44, 58, 72], fill=C("P38"))                          # 문: 늘어뜨린 멧돼지 가죽 발
    d.rectangle([41, 45, 57, 71], fill=C("P39"))
    for y in range(48, 70, 5):
        d.line([42, y, 56, y + 1], fill=C("P40"))
    d.line([40, 44, 58, 44], fill=C("P17"))
    d.rectangle([14, 40, 30, 52], fill=C("P02")); d.rectangle([15, 41, 29, 51], fill=C("P11"))   # 작은 창(비닐)
    d.line([22, 41, 22, 51], fill=C("P18")); d.line([15, 46, 29, 46], fill=C("P18"))
    d.line([62, 36, 92, 37], fill=C("P17"))                               # 처마 밑 육포 줄
    for x in range(64, 92, 5):
        d.rectangle([x, 37, x + 2, 43], fill=C("P24")); d.point((x + 1, 43), fill=C("P23"))
    for (x, sgn) in ((37, -1), (61, 1)):                                  # 문 위 멧돼지 엄니 한 쌍(못에 건)
        d.arc([x - 3, 34, x + 3, 42], 90 if sgn > 0 else 270, 270 if sgn > 0 else 90, fill=C("P08"), width=1)
        d.point((x, 34), fill=C("P04"))
    d.rectangle([4, 66, 18, 72], fill=C("P17")); d.rectangle([5, 64, 17, 66], fill=C("P18"))  # 장작더미
    for x in (6, 10, 14):
        d.ellipse([x - 1, 66, x + 2, 69], fill=C("P20"))
    return im


def hide_rack():
    """가죽 건조대: 나무 틀에 펼쳐 말리는 멧돼지 가죽 + 끈. 1×1칸(위로 솟는다)."""
    im = img(34, 46)
    d = ImageDraw.Draw(im)
    d.line([4, 44, 8, 4], fill=C("P18"), width=2); d.line([29, 44, 25, 4], fill=C("P18"), width=2)
    d.line([6, 6, 27, 6], fill=C("P17"), width=2); d.line([5, 36, 28, 36], fill=C("P17"), width=2)
    d.polygon([(9, 9), (24, 9), (26, 20), (23, 33), (10, 33), (7, 20)], fill=C("P39"))
    d.polygon([(11, 11), (22, 11), (24, 20), (21, 31), (12, 31), (9, 20)], fill=C("P40"))
    for (a, b) in (((9, 9), (8, 6)), ((24, 9), (25, 6)), ((10, 33), (7, 36)), ((23, 33), (26, 36)), ((7, 20), (6, 20)), ((26, 20), (27, 20))):
        d.line([a, b], fill=C("P21"))
    d.line([16, 13, 17, 29], fill=C("P38"))
    return im


def anvil():
    im = img(30, 26)
    d = ImageDraw.Draw(im)
    d.rectangle([11, 14, 18, 24], fill=C("P18"))                          # 그루터기 받침
    d.polygon([(2, 6), (26, 6), (29, 9), (22, 10), (20, 14), (9, 14), (7, 10)], fill=C("P04"))
    d.line([3, 6, 26, 6], fill=C("P06"))
    d.line([4, 7, 25, 7], fill=C("P05"))
    return im


def gate_leaf(open_=True, side="l"):
    """아랫문 철문 한 짝(분양 현수막 덧댄 철판): open = 열려 벽 쪽으로 젖힌 모습(좁게), closed = 길을 막은 모습."""
    if open_:
        im = img(18, 66)
        d = ImageDraw.Draw(im)
        d.rectangle([3, 4, 14, 64], fill=C("P05"))
        for y in range(8, 62, 6):
            d.line([3, y, 14, y], fill=C("P04"))
        d.line([3, 4, 3, 64], fill=C("P07"))
        d.rectangle([5, 14, 12, 40], fill=C("P09")); d.rectangle([5, 14, 12, 18], fill=C("P53"))
        return im
    im = img(34, 66)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 4, 32, 64], fill=C("P05"))
    for x in range(4, 32, 4):
        d.line([x, 4, x, 64], fill=C("P06"))
    d.line([1, 4, 32, 4], fill=C("P07"))
    d.rectangle([4, 14, 29, 34], fill=C("P09")); d.rectangle([4, 14, 29, 18], fill=C("P53"))
    put_text(im, "분양", 8, 20, "P52", 8, "Galmuri7")
    return im


def guard_booth():
    """초소(감시조): 판자 상자 + 함석 지붕 + 모래주머니."""
    im = img(36, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 14, 31, 50], fill=C("P19"))
    for y in range(16, 50, 4):
        d.line([4, y, 31, y], fill=C("P18"))
    d.line([4, 14, 4, 50], fill=C("P20"))
    d.rectangle([9, 20, 26, 30], fill=C("P02"))
    d.line([9, 20, 26, 20], fill=C(INK))
    d.polygon([(0, 14), (18, 4), (35, 14)], fill=C("P25"))
    d.line([0, 14, 35, 14], fill=C(INK))
    for x in range(2, 34, 9):
        lump(im, x + 4, 47, 6, 4, ["P19", "P20", "P21", "P22"])
    return im


def drum(fire=False, frame=0):
    im = img(26, 34)
    d = ImageDraw.Draw(im)
    rust = ["P24", "P25", "P26", "P27"]
    for x in range(4, 22):
        nx = (x + 0.5 - 13) / 9
        d.line([x, 12, x, 32], fill=C(rust[0] if nx > 0.55 else rust[1] if nx > 0 else rust[2] if nx > -0.6 else rust[3]))
    for y in (18, 25):
        d.line([4, y, 21, y], fill=C(rust[0]))
    d.ellipse([4, 7, 21, 16], fill=C(rust[2]))
    d.ellipse([6, 9, 19, 14], fill=C("P02") if fire else C(rust[1]))
    if fire:                                                              # 드럼통 모닥불(밤)
        fl = [["P53", "P54", "P59", "P60", "P50"], ["P53", "P59", "P54", "P60", "P50"], ["P54", "P53", "P60", "P59", "P50"]][frame % 3]
        rnd = random.Random(frame * 7 + 1)
        for k in range(9):
            x = 7 + k * 1.4
            h_ = rnd.randint(4, 9)
            for t in range(h_):
                col = fl[min(4, t * 5 // h_)]
                im.putpixel((int(x), 11 - t), C(col))
        for k in range(3):
            im.putpixel((8 + k * 4, 1 + (frame + k) % 3), C("P59"))
    return im


def car_wreck(seed=0):
    """2077년 원자력 승용차(둥근 몸통·꼬리 날개) 잔해: 바퀴 없음, 녹, 깨진 유리. 3×2 발."""
    rnd = random.Random(seed)
    W_, H_ = 98, 62
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    body = ["P11", "P12", "P13", "P14"] if seed % 2 == 0 else ["P23", "P24", "P25", "P26"]
    d.rounded_rectangle([3, 22, 94, 56], 12, fill=C(body[1]))
    d.rounded_rectangle([3, 22, 94, 40], 12, fill=C(body[2]))
    d.line([10, 22, 86, 22], fill=C(body[3]))
    d.rounded_rectangle([22, 6, 74, 30], 10, fill=C(body[1]))             # 지붕·유리
    d.rounded_rectangle([26, 9, 70, 26], 8, fill=C("P10"))
    d.line([48, 9, 48, 26], fill=C(body[1]))
    d.polygon([(30, 12), (36, 12), (32, 20)], fill=C("P12"))
    d.polygon([(52, 10), (60, 10), (55, 16)], fill=C("P02"))              # 깨진 자리
    d.polygon([(84, 24), (96, 12), (95, 30)], fill=C(body[2]))            # 꼬리 날개
    d.ellipse([6, 40, 14, 48], fill=C("P49")); d.ellipse([84, 40, 92, 48], fill=C("P53"))   # 등
    d.rectangle([40, 44, 58, 50], fill=C("P07"))                          # 범퍼 + 원자 엠블럼
    d.ellipse([46, 42, 52, 48], fill=C("P46"))
    for x in (16, 80):                                                    # 바퀴 자리(빈 휠하우스 + 받친 벽돌)
        d.rectangle([x - 8, 50, x + 8, 60], fill=C("P02"))
        d.rectangle([x - 5, 55, x + 5, 60], fill=C("P25"))
    for _ in range(40):                                                   # 녹
        x, y = rnd.randint(6, 92), rnd.randint(24, 54)
        if im.getpixel((x, y))[3]:
            im.putpixel((x, y), C(rnd.choice(["P24", "P25", "P23"])))
    return im


def bus_stop():
    """2077 버스 정류장 뼈대(지붕 반쯤 무너짐) + 녹슨 노선판."""
    im = img(66, 60)
    d = ImageDraw.Draw(im)
    for x in (4, 58):
        d.rectangle([x, 12, x + 3, 58], fill=C("P05")); d.line([x, 12, x, 58], fill=C("P07"))
    d.polygon([(0, 12), (40, 6), (40, 14), (0, 18)], fill=C("P13"))
    d.line([0, 18, 40, 14], fill=C(INK))
    d.polygon([(40, 8), (64, 24), (62, 28), (40, 14)], fill=C("P12"))     # 꺾인 지붕
    d.rectangle([10, 40, 50, 46], fill=C("P18")); d.line([10, 40, 50, 40], fill=C("P20"))   # 의자
    d.rectangle([44, 20, 56, 34], fill=C("P45"), outline=C(INK))
    put_text(im, "6511", 45, 22, "P09", 8, "Galmuri7")
    return im


def manhole(open_=False):
    im = img(28, 22)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 1, 26, 20], fill=C("P04"))
    if open_:
        d.ellipse([3, 3, 24, 18], fill=C("P01"))
        d.line([8, 6, 8, 16], fill=C("P05")); d.line([18, 6, 18, 16], fill=C("P05"))
        for y in (8, 11, 14):
            d.line([8, y, 18, y], fill=C("P05"))
    else:
        d.ellipse([3, 3, 24, 18], fill=C("P05"))
        for y in range(6, 17, 3):
            d.line([6, y, 21, y], fill=C("P04"))
        d.point((9, 5), fill=C("P07"))
    return im


def stair_post():
    """'312계단' 표지 기둥(아랫문 안 계단참①): 손잡이 끝 각인 판."""
    im = img(26, 46)
    d = ImageDraw.Draw(im)
    d.rectangle([11, 18, 14, 45], fill=C("P05")); d.line([11, 18, 11, 45], fill=C("P07"))
    d.rectangle([1, 2, 24, 18], fill=C("P18")); d.rectangle([2, 3, 23, 17], fill=C("P20"))
    put_text(im, "312", 4, 3, "P16", 8, "Galmuri9")
    put_text(im, "계단", 4, 10, "P16", 8, "Galmuri7")
    return im


def floor_hatch():
    """비밀 저수조 뚜껑(B-08, 물탱크 아래): 녹슨 철판 + 손잡이 + 자물쇠."""
    im = img(30, 22)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 28, 20], fill=C("P05")); d.rectangle([1, 2, 28, 4], fill=C("P06"))
    for x in range(4, 27, 5):
        d.line([x, 6, x, 18], fill=C("P04"))
    d.rectangle([11, 9, 18, 12], fill=C("P07"))
    d.rectangle([13, 13, 16, 17], fill=C("P48"))
    return im


def roof_hatch():
    """옥상 출입구(계단실 상자 + 철문)."""
    im = img(34, 52)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 16, 31, 50], fill=C("P07"))
    d.line([2, 16, 2, 50], fill=C("P08")); d.line([31, 16, 31, 50], fill=C("P05"))
    d.rectangle([0, 10, 33, 16], fill=C("P08")); d.line([0, 10, 33, 10], fill=C("P09")); d.line([0, 16, 33, 16], fill=C(INK))
    d.rectangle([10, 26, 23, 50], fill=C(INK)); d.rectangle([11, 27, 22, 50], fill=C("P05"))
    d.rectangle([19, 38, 21, 39], fill=C("P48"))
    return im


def antenna():
    """옥상 방송 안테나(2077 진공관 수신기용 어골형)."""
    im = img(32, 60)
    d = ImageDraw.Draw(im)
    d.line([16, 8, 16, 58], fill=C("P05"))
    d.line([17, 8, 17, 58], fill=C("P03"))
    for k, y in enumerate(range(8, 30, 5)):
        w = 13 - k * 2
        d.line([16 - w, y, 16 + w, y], fill=C("P06"))
    d.line([16, 58, 4, 58], fill=C("P05")); d.line([16, 58, 28, 58], fill=C("P05"))
    return im


def laundry_line(seed=0):
    rnd = random.Random(seed)
    im = img(66, 46)
    d = ImageDraw.Draw(im)
    for x in (3, 61):
        d.rectangle([x, 6, x + 2, 44], fill=C("P05"))
    d.line([4, 8, 62, 10], fill=C("P06"))
    x = 8
    while x < 56:
        w = rnd.randint(7, 12)
        col = rnd.choice(["P09", "P26", "P45", "P36", "P49", "P15", "P21"])
        h = rnd.randint(10, 20)
        d.rectangle([x, 9, x + w, 9 + h], fill=C(col))
        d.line([x, 9 + h, x + w, 9 + h], fill=C(P.resolve(col) and "P%02d" % max(0, int(col[1:]) - 1)))
        d.line([x, 9, x, 9 + h], fill=C("P%02d" % min(63, int(col[1:]) + 1)))
        x += w + rnd.randint(2, 5)
    return im


def lp_gas():
    im = img(16, 34)
    d = ImageDraw.Draw(im)
    for x in range(2, 14):
        nx = (x - 8) / 6
        d.line([x, 8, x, 32], fill=C("P53" if nx < -0.3 else "P52" if nx < 0.5 else "P51"))
    d.ellipse([2, 4, 13, 12], fill=C("P53"))
    d.rectangle([6, 1, 9, 5], fill=C("P06"))
    d.line([2, 20, 13, 20], fill=C("P09"))
    return im


def crate(seed=0):
    im = img(30, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 8, 27, 28], fill=C("P19"))
    d.rectangle([2, 4, 27, 9], fill=C("P20")); d.line([2, 4, 27, 4], fill=C("P21"))
    for x in (2, 14, 27):
        d.line([x, 8, x, 28], fill=C("P18"))
    d.line([2, 8, 27, 28], fill=C("P18"))
    return im


def bench():
    im = img(66, 30)
    d = ImageDraw.Draw(im)
    for x in (6, 56):
        d.rectangle([x, 14, x + 3, 28], fill=C("P05"))
    d.rectangle([1, 10, 64, 16], fill=C("P19")); d.line([1, 10, 64, 10], fill=C("P21")); d.line([1, 13, 64, 13], fill=C("P18"))
    d.rectangle([1, 2, 64, 7], fill=C("P19")); d.line([1, 2, 64, 2], fill=C("P21"))
    return im


def rubble(seed=0):
    rnd = random.Random(seed)
    im = img(34, 26)
    for _ in range(7):
        lump(im, rnd.randint(6, 28), rnd.randint(10, 20), rnd.randint(3, 7), rnd.randint(3, 5), ["P04", "P05", "P06", "P07"])
    d = ImageDraw.Draw(im)
    d.line([8, 8, 14, 18], fill=C("P25"))                                 # 삐져나온 철근
    d.line([22, 6, 20, 16], fill=C("P25"))
    return im


def sandbags():
    im = img(34, 24)
    for row, y in enumerate((16, 9)):
        for k in range(3 - row):
            TI.lump(im, 7 + k * 10 + row * 5, y, 6, 4, ["P19", "P20", "P21", "P22"])
    return im


def jersey_barrier():
    im = img(66, 30)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 28), (6, 8), (60, 8), (64, 28)], fill=C("P07"))
    d.rectangle([6, 4, 60, 9], fill=C("P08")); d.line([6, 4, 60, 4], fill=C("P09"))
    for x in range(8, 60, 12):
        d.polygon([(x, 14), (x + 6, 14), (x + 2, 22), (x - 4, 22)], fill=C("P53"))
    return im


def streetlamp():
    """죽은 가로등(2077 원자력 가로등, 전구 깨짐)."""
    im = img(30, 100)
    d = ImageDraw.Draw(im)
    d.rectangle([13, 10, 16, 98], fill=C("P05")); d.line([13, 10, 13, 98], fill=C("P07"))
    d.arc([13, 4, 29, 20], 180, 270, fill=C("P05"), width=2)
    d.rectangle([20, 2, 29, 8], fill=C("P04")); d.rectangle([22, 8, 27, 10], fill=C("P11"))
    d.rectangle([9, 90, 20, 98], fill=C("P04"))
    return im


def tarp_pile():
    im = img(40, 28)
    lump(im, 20, 16, 17, 10, ["P44", "P45", "P46", "P46"])
    d = ImageDraw.Draw(im)
    d.line([6, 14, 34, 18], fill=C("P44")); d.line([10, 8, 28, 22], fill=C("P44"))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS = {
    # 나무·덤불·바위(관악산 비탈, 봉천 둘레)
    "tree_pine": _r(lambda: tree("pine", 1.0, 1), 1, 1, down=0),
    "tree_pine2": _r(lambda: tree("pine", 1.15, 2), 1, 1, down=0),
    "tree_oak": _r(lambda: tree("oak", 1.0, 3), 1, 1, down=0),
    "tree_oak2": _r(lambda: tree("oak", 1.2, 4), 1, 1, down=0),
    "tree_maple": _r(lambda: tree("maple", 0.95, 5), 1, 1, down=0),
    "tree_ginkgo": _r(lambda: tree("ginkgo", 0.9, 6), 1, 1, down=0),
    "tree_small": _r(lambda: tree("oak", 0.6, 7), 1, 1, down=0),
    "tree_dead": _r(lambda: tree("dead", 0.8, 8), 1, 1, down=0),
    "bush_g": _r(lambda: bush("g", 1), 1, 1, down=2),
    "bush_a": _r(lambda: bush("a", 2), 1, 1, down=2),
    "bush_y": _r(lambda: bush("y", 3), 1, 1, down=2),
    "boulder_s": _r(lambda: boulder(9, 6, 1), 1, 1, down=1),
    "boulder_m": _r(lambda: boulder(20, 12, 2), 2, 1, down=4),
    "boulder_l": _r(lambda: boulder(28, 18, 3), 2, 2, down=2),
    "stump": _r(stump, 1, 1, down=-2),
    "tuft": _r(lambda: tuft(1), 0, 0, "deco"),
    "tuft2": _r(lambda: tuft(2), 0, 0, "deco"),
    # 볼트 앞·전망바위
    "exit_terminal": _r(exit_terminal, 1, 1, down=-4),
    "telescope": _r(telescope, 1, 1, down=-4),
    "info_board": _r(info_board, 1, 1, down=-2),
    # 봉천
    "board_bc": _r(lambda: notice_board("base"), 2, 1, down=-2),
    "kennel": _r(lambda: kennel(), 2, 1, down=-2),
    "water_tank": _r(lambda: water_tank(True), 2, 1, down=-2),
    "water_tank_s": _r(lambda: water_tank(False), 1, 1, down=-2),
    "watchtower": _r(watchtower, 2, 2, down=-2),
    "utility_pole": _r(utility_pole, 1, 1, down=-6),
    "planter_l": _r(lambda: planter("lettuce", 0), 1, 1, down=-2),
    "planter_p": _r(lambda: planter("pepper", 1), 1, 1, down=-2),
    "planter_s": _r(lambda: planter("scallion", 2), 1, 1, down=-2),
    "scrap_pile": _r(lambda: scrap_pile(1), 2, 1, down=-2),
    "scrap_pile2": _r(lambda: scrap_pile(2), 2, 1, down=-2),
    "scale": _r(scale, 1, 1, down=-2),
    "stall": _r(lambda: stall_counter(1), 2, 1, down=-2),
    "forge": _r(forge, 2, 1, down=-2),
    "anvil": _r(anvil, 1, 1, down=-2),
    "hangyeol_bench": _r(hangyeol_bench, 2, 1, down=-2),
    "hunter_shack": _r(hunter_shack, 3, 2, down=-2),                      # 사냥꾼 오두막(1-8d, V04 엄태경)
    "hide_rack": _r(hide_rack, 1, 1, down=-2),                  # 한결 공구 작업대(1-8c, SD-13 §7.9.1)
    "gate_l": _r(lambda: gate_leaf(True, "l"), 1, 1, down=-2),
    "gate_r": _r(lambda: gate_leaf(True, "r"), 1, 1, down=-2),
    "gate_shut": _r(lambda: gate_leaf(False), 1, 1, down=-2),
    "guard_booth": _r(guard_booth, 1, 1, down=-2),
    "drum": _r(lambda: drum(False), 1, 1, down=-2),
    "drum_fire": _r(lambda: drum(True, 0), 1, 1, down=-2),
    "car_wreck": _r(lambda: car_wreck(0), 3, 2, down=-2),
    "car_wreck2": _r(lambda: car_wreck(1), 3, 2, down=-2),
    "bus_stop": _r(bus_stop, 2, 1, down=-2),
    "manhole": _r(lambda: manhole(False), 0, 0, "deco"),
    "manhole_open": _r(lambda: manhole(True), 0, 0, "deco"),
    "stair_post": _r(stair_post, 1, 1, down=-4),
    "floor_hatch": _r(floor_hatch, 1, 1, down=-6),
    "roof_hatch": _r(roof_hatch, 1, 1, down=-2),
    "antenna": _r(antenna, 1, 1, down=-4),
    "laundry_line": _r(lambda: laundry_line(1), 2, 1, down=-2),
    "lp_gas": _r(lp_gas, 1, 1, down=-6),
    "crate_o": _r(lambda: crate(0), 1, 1, down=-2),
    "bench_o": _r(bench, 2, 1, down=-2),
    "rubble": _r(lambda: rubble(1), 1, 1, down=-2),
    "rubble2": _r(lambda: rubble(2), 1, 1, down=-2),
    "sandbags": _r(sandbags, 1, 1, down=-2),
    "jersey": _r(jersey_barrier, 2, 1, down=-2),
    "streetlamp": _r(streetlamp, 1, 1, down=-4),
    "tarp_pile": _r(tarp_pile, 1, 1, down=-2),
}

from props_bc_in import PROPS_IN                                         # 봉천 실내(0-10c): 같은 아틀라스로 나간다
for _k in PROPS_IN:
    assert _k not in PROPS, _k
PROPS.update(PROPS_IN)
from props_sb import PROPS_SB, STATES_SB                                # 새벽인력 창고동 H-03(1-3)
for _k in PROPS_SB:
    assert _k not in PROPS, _k
PROPS.update(PROPS_SB)
from props_jm import PROPS_JM, STATES_JM                                # 영등포 지하상가(1-4 지하시장)
for _k in PROPS_JM:
    assert _k not in PROPS, _k
PROPS.update(PROPS_JM)
from props_road import PROPS_ROAD                                       # 길 위 발견물(1-4f, SD-08 §13.2)
for _k in PROPS_ROAD:
    assert _k not in PROPS, _k
PROPS.update(PROPS_ROAD)
from props_bw import PROPS_BW                                           # 관악산 들개 바위굴 · 연수원 별관(1-11a SQ-S01)
for _k in PROPS_BW:
    assert _k not in PROPS, _k
PROPS.update(PROPS_BW)
from props_bs import PROPS_BS, STATES_BS                                # 봉천 배수지 · 상류 밸브 · 낙성대 고개(1-11b SQ-S02)
for _k in PROPS_BS:
    assert _k not in PROPS, _k
PROPS.update(PROPS_BS)
from props_site import PROPS_SITE                                       # 소장소(1-W, SD-22 §5.2)
for _k in PROPS_SITE:
    assert _k not in PROPS, _k
PROPS.update(PROPS_SITE)
from props_bk import PROPS_BK, STATES_BK                                # 여의도 지하 벙커(1-5 MQ-104)
for _k in PROPS_BK:
    assert _k not in PROPS, _k
PROPS.update(PROPS_BK)
from props_cg import PROPS_CG, STATES_CG                                # 청계산 벙커 C05 · 북사면 환기탑(1-7 MQ-106)
for _k in PROPS_CG:
    assert _k not in PROPS, _k
PROPS.update(PROPS_CG)
from props_home import PROPS_HOME, STATES_HOME                        # 들어가 보는 건물 실내(1-5e 자유 탐험 확장)
for _k in PROPS_HOME:
    assert _k not in PROPS, _k
PROPS.update(PROPS_HOME)
from props_r01n import PROPS_R01N                                     # R01 북쪽 탐험 묶음(1-7c): 학원가 · 병원 · 수산시장 · 국립묘지
for _k in PROPS_R01N:
    assert _k not in PROPS, _k
PROPS.update(PROPS_R01N)
from props_sd import PROPS_SD                                         # 사당 환승촌(1-8f, SD-09a L-R01-18)
for _k in PROPS_SD:
    assert _k not in PROPS, _k
PROPS.update(PROPS_SD)
from props_bj import PROPS_BJ                                         # 사당 고개 검문소(1-8g, SD-09a L-R01-19)
for _k in PROPS_BJ:
    assert _k not in PROPS, _k
PROPS.update(PROPS_BJ)
from props_gs import PROPS_GS                                         # 노량진 관제 중계소(1-8g, SD-09a L-R01-23)
for _k in PROPS_GS:
    assert _k not in PROPS, _k
PROPS.update(PROPS_GS)
from props_s04 import PROPS_S04, STATES_S04                           # 봉천 동 주민센터 · 관악 레이더 중계소(1-11c SQ-S04)
from props_s03 import PROPS_S03, STATES_S03                           # 계곡 암거 곰팡이 · S-07 배수 갱도 · 봉천 배수지(1-11d SQ-S03)
for _k in PROPS_S03:
    assert _k not in PROPS, _k
PROPS.update(PROPS_S03)
for _k in PROPS_S04:
    assert _k not in PROPS, _k
PROPS.update(PROPS_S04)
from props_s05 import PROPS_S05, STATES_S05                           # 2호선 서쪽 터널 · 낙성대 · 서울대입구(1-11e SQ-S05)
for _k in PROPS_S05:
    assert _k not in PROPS, _k
PROPS.update(PROPS_S05)
from props_s06 import PROPS_S06, STATES_S06                           # 시흥 고개 초소 · 노들섬 남문 · 강가(1-11f SQ-S06)
for _k in PROPS_S06:
    assert _k not in PROPS, _k
PROPS.update(PROPS_S06)
from props_s08 import PROPS_S08, STATES_S08                           # 영등포 구청 배급소 · 남쪽 통로 경비 초소 · 김민수 셔터(1-11g SQ-S08)
for _k in PROPS_S08:
    assert _k not in PROPS, _k
PROPS.update(PROPS_S08)
from props_s10 import PROPS_S10, STATES_S10                           # 고척 돔 인력 경매장(1-11i SQ-S10)
for _k in PROPS_S10:
    assert _k not in PROPS, _k
PROPS.update(PROPS_S10)
from props_s11 import PROPS_S11, STATES_S11                           # 무너진 국회 · 기록관 · 경찰서 프린터(1-11j SQ-S11)
for _k in PROPS_S11:
    assert _k not in PROPS, _k
PROPS.update(PROPS_S11)
from props_dg import PROPS_DG, STATES_DG                               # 던전(1-D): 대방 지하차도 침수 입구 · 원자력 버스 · 잠긴 차
for _k in PROPS_DG:
    assert _k not in PROPS, _k
PROPS.update(PROPS_DG)
from props_u02 import PROPS_U02, STATES_U02                            # U02 남태령 지하(1-D2): 4호선 승강장 · 멈춘 전동차 · 조명 회로 · 할매 측실 · 지하 초소
for _k in PROPS_U02:
    assert _k not in PROPS, _k
PROPS.update(PROPS_U02)
from props_ds import PROPS_DS, STATES_DS                               # 독산 육가공 단지(1-D3): 가공 라인 · 냉동 창고 7호 · 굴 · 냉동 화물칸
for _k in PROPS_DS:
    assert _k not in PROPS, _k
PROPS.update(PROPS_DS)
from props_gr import PROPS_GR, STATES_GR                               # 구로 차량기지(1-D4): 객차 · 원자력 기관차 · 화차 · 검측차 · 전철기 레버 · 건널목 · 군화 줄
for _k in PROPS_GR:
    assert _k not in PROPS, _k
PROPS.update(PROPS_GR)
from props_kt import PROPS_KT, STATES_KT                               # 여의도 금탑 로비 · 수족관(1-D5a): 회전문 · 안내 데스크 · 승강기 · 개미 흙벽 · 수조 · 펌프 · 인터폰
for _k in PROPS_KT:
    assert _k not in PROPS, _k
PROPS.update(PROPS_KT)
from props_loot import PROPS_LOOT, STATES_LOOT                        # 파밍 v3 · 보관 · 거래처(1-L): 털린 자리 무늬 · 바꿈 상자 · 방울 줄 · 장사 간판 · 보관함
for _k in PROPS_LOOT:
    assert _k not in PROPS, _k
PROPS.update(PROPS_LOOT)
from props_ga import PROPS_GA, STATES_GA                              # 가산 아울렛(1-D6): 방독면 마네킹 · 진열창 · 행거 · 탈의실 커튼 · 에스컬레이터 · 단가 칠판 · 작업복 상자
for _k in PROPS_GA:
    assert _k not in PROPS, _k
PROPS.update(PROPS_GA)
from props_mr import PROPS_MR, STATES_MR                              # 문래 철공소 골목 · 지식산업센터 금형(1-D7): 선반 · 용접대 · 쇳가루 길 · 간판 · 태성 금형
for _k in PROPS_MR:
    assert _k not in PROPS, _k
PROPS.update(PROPS_MR)
from props_ks import PROPS_KS, STATES_KS                              # 구로 공단 지식산업센터(1-D7): 출근 기록기 · 카드꽂이 · 프레스 · 생산 게시판 · 해골 작업대 · 타자기 · 비상정지 · 데크 크레인 · 굴뚝
for _k in PROPS_KS:
    assert _k not in PROPS, _k
PROPS.update(PROPS_KS)
from props_hp import PROPS_HP, STATES_HP                              # 여의도 대학병원(1-D8): 방송 단말 · 면회 게시판 · 냉동 칸 · 간호사실 · 분류 띠 · 차트 · 들것 · 구울 환자 병상
for _k in PROPS_HP:
    assert _k not in PROPS, _k
PROPS.update(PROPS_HP)
from props_yt import PROPS_YT, STATES_YT                              # 여의도 유리탑 3동 · 증권가 객장(1-D9): 판독기 게이트 · 벽 판독기 · 안내판 · 방화 셔터 · 발급 단말 · 송출 랙 · 화분 둔덕 · 객장 전광판
for _k in PROPS_YT:
    assert _k not in PROPS, _k
PROPS.update(PROPS_YT)
from props_u04 import PROPS_U04, STATES_U04                          # U04 여의도 지하(1-D10): 진공관 플랩 시세판 · 지하시장 후문 셔터 · 배전반 · 벽 점검구 · 대피소 판독기 문 · 운반조 레일 수레
for _k in PROPS_U04:
    assert _k not in PROPS, _k
PROPS.update(PROPS_U04)
from props_sv import PROPS_SV, STATES_SV                              # 볼트 S-02 '끝없는 선거' · 영등포 역전 시장(1-11l SQ-S13): 벽보 · 투표함 · 기표소 · 등록부 · 개표기 · 출력지 · 공고 칠판 · 명패 벽 · 띠 해골 · 바리케이드 · 톱니 문 · 시장 아치
for _k in PROPS_SV:
    assert _k not in PROPS, _k
PROPS.update(PROPS_SV)
from props_trap import PROPS_TRAP, STATES_TRAP, burnt_states       # 함정 · 환경 폭발(1-9c, SD-11 §9.2 · §9.3)
for _k in PROPS_TRAP:
    assert _k not in PROPS, _k
PROPS.update(PROPS_TRAP)

STATES = {
    "board_bc": {s: (lambda s=s: notice_board(s)) for s in ("wanted", "torn", "crumpled", "crossed", "rate", "water", "official")},
    "drum_fire": {"f1": lambda: drum(True, 1), "f2": lambda: drum(True, 2)},
    "gate_l": {"shut": lambda: gate_leaf(False)},
    "gate_r": {"shut": lambda: gate_leaf(False)},
    "manhole": {"open": lambda: manhole(True)},
}
STATES.update(STATES_SB)
STATES.update(STATES_JM)
STATES.update(STATES_BK)
STATES.update(STATES_CG)
STATES.update(STATES_TRAP)
STATES.update(STATES_DS)
STATES.update(STATES_GR)
STATES.update(STATES_KT)
STATES.update(STATES_GA)
STATES.update(STATES_MR)
STATES.update(STATES_KS)
STATES.update(STATES_HP)
STATES.update(STATES_YT)
STATES.update(STATES_U04)
STATES.update(STATES_SV)
STATES.update(STATES_BS)
STATES.update(STATES_S04)
STATES.update(STATES_S03)
STATES.update(STATES_S05)
STATES.update(STATES_S06)
STATES.update(STATES_S08)
STATES.update(STATES_S10)
STATES.update(STATES_S11)
STATES.update(STATES_HOME)
STATES.update(STATES_DG)
STATES.update(STATES_U02)
STATES.update(STATES_LOOT)
for _k, _v in burnt_states(PROPS).items():
    STATES.setdefault(_k, {}).update(_v)


if __name__ == "__main__":
    from grid import upscale, check
    ims = [(n, TI.outline(r["fn"]())) for n, r in PROPS.items()]
    ims += [(f"{n}#{s}", TI.outline(fn())) for n, st in STATES.items() for s, fn in st.items()]
    W = 1024
    x = y = rowh = 0
    pos = []
    for n, im in ims:
        if x + im.width + 4 > W:
            x, y, rowh = 0, y + rowh + 4, 0
        pos.append((n, im, x, y))
        x += im.width + 4
        rowh = max(rowh, im.height)
    out = Image.new("RGBA", (W, y + rowh + 4), C("P30"))
    for n, im, x, y in pos:
        out.alpha_composite(im, (x, y))
    bad = check(out, P.allowed_set("UI"))
    out_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "out")
    upscale(out, 2).save(os.path.join(out_dir, "props_bc_x2.png"))
    print("off-palette:", bad[:5] if bad else 0, len(ims))
