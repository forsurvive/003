"""소장소 소품(단계 1-W, SD-22 §5.2 결·지형별 템플릿, SD-16 §7·§8 아이작풍 + RPG 메이커풍 타일 비율).
월드 굽기(world_chunks.place_minisites)가 결·지형 태그에 맞춰 묶음으로 놓는다:
전복된 시내버스 · 화물 컨테이너 · 떠밀려 온 낚싯배 · 녹슨 지게차 · 무너진 비닐하우스 · 새는 화학 드럼 · 침낭 · 공동 우물 · 방수포 천막 ·
한강공원 매점 폐허 · 추락한 헬기 · 놀이터 미끄럼틀 · 낚시 도구 · 텃밭 상자.
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01). 위에서 빛(위 밝게 · 아래 어둡게), 반투명 없음.
"""
import os, sys, random, math
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, y0, x1, y1):
    d.ellipse([x0, y0, x1, y1], fill=C("P02"))


def _hull_shadow(im, poly, dx, dy):
    """땅에 얹힌 큰 물건의 접지 그림자(SD-16 §6 광원 북서 45°): 윤곽 다각형을 오른쪽 아래로 (dx, dy) 민 것과 (dx//2, dy//2) 민 것을 겹쳐 깔고
    몸체를 그 위에 덮는다 — 밑바닥 오른쪽 · 아래 가장자리를 따라가는 짧은 띠만 남는다. 점무늬 없음(사용자 지적 2026-10-22 — 타원 · 흩어진 그림자 금지)."""
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(sh)
    dd.polygon([(x + dx, y + dy) for x, y in poly], fill=C("P02"))
    dd.polygon([(x + dx // 2, y + dy // 2) for x, y in poly], fill=C("P02"))
    im.alpha_composite(sh)


def _rust(im, rnd, box, n, cols=("P24", "P25", "P26")):
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y = rnd.randint(x0, x1), rnd.randint(y0, y1)
        if 0 <= x < im.width and 0 <= y < im.height and im.getpixel((x, y))[3]:
            im.putpixel((x, y), C(rnd.choice(cols)))


def bus_wreck(seed=0):
    """버려진 2077 시내버스(한결 버스 65번): 깨진 창 줄 · 뜯겨 나간 문 · 바퀴는 벽돌에 얹혔다. 4×2 발."""
    rnd = random.Random(seed + 40)
    W_, H_ = 132, 74
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 52, 130, 72)
    # 몸통(옆면이 하늘을 본다): 크림 위 + 청록 띠
    d.rounded_rectangle([4, 14, 127, 58], 14, fill=C("P21"))
    d.rounded_rectangle([4, 14, 127, 30], 14, fill=C("P22"))
    d.rectangle([6, 34, 125, 42], fill=C("P36"))
    d.line([8, 34, 123, 34], fill=C("P37"))
    d.line([8, 42, 123, 42], fill=C("P35"))
    # 창 줄(깨진 유리 · 일부 빈 칸)
    for i, x in enumerate(range(16, 116, 14)):
        col = "P10" if (i * 3 + seed) % 5 else "P02"
        d.rounded_rectangle([x, 18, x + 10, 29], 2, fill=C(col))
        if col == "P10":
            d.line([x + 2, 20, x + 5, 20], fill=C("P13"))
            if i % 3 == 1:
                d.polygon([(x + 6, 19), (x + 9, 19), (x + 8, 24)], fill=C("P02"))
    # 앞(왼쪽) 끝: 노선판·전조등
    d.rounded_rectangle([4, 16, 14, 56], 6, fill=C("P20"))
    d.rectangle([5, 20, 12, 27], fill=C("P01")); put_text(im, "65", 5, 19, "P60", 8, "Galmuri7")
    d.ellipse([6, 44, 11, 49], fill=C("P49"))
    # 아래로 드러난 바닥과 바퀴 둘
    d.rectangle([16, 56, 116, 62], fill=C("P03"))
    d.line([16, 56, 116, 56], fill=C("P04"))
    for x in (34, 98):
        d.ellipse([x - 11, 52, x + 11, 70], fill=C("P01"))
        d.ellipse([x - 7, 55, x + 7, 67], fill=C("P03"))
        d.ellipse([x - 3, 59, x + 3, 63], fill=C("P06"))
    d.line([34, 61, 98, 61], fill=C("P02"))                               # 축
    d.rectangle([66, 36, 76, 56], fill=C("P02"))                          # 뜯겨 나간 문 자리
    d.line([66, 36, 66, 56], fill=C("P20"))
    _rust(im, rnd, (6, 14, 126, 56), 90)
    put_text(im, "한결", 92, 34, "P09", 8, "Galmuri7")
    return im


def container(seed=0):
    """2077 화물 컨테이너(세진 물류): 골진 철판 · 오른쪽 문 한 짝이 반쯤 열려 안이 어둡다. 3×2 발."""
    rnd = random.Random(seed + 50)
    W_, H_ = 98, 76
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 58, 96, 74)
    body = [["P24", "P25", "P26", "P27"], ["P11", "P12", "P13", "P14"], ["P29", "P30", "P31", "P32"]][seed % 3]
    d.rectangle([3, 4, 94, 16], fill=C(body[3]))                          # 윗면
    d.line([3, 4, 94, 4], fill=C(body[3]))
    d.rectangle([3, 16, 94, 66], fill=C(body[1]))                         # 앞면
    for x in range(6, 76, 6):                                             # 골
        d.line([x, 18, x, 64], fill=C(body[2]))
        d.line([x + 1, 18, x + 1, 64], fill=C(body[0]))
    d.rectangle([3, 16, 94, 18], fill=C(body[2]))
    d.rectangle([3, 64, 94, 66], fill=C(body[0]))
    # 문(오른쪽 끝): 한 짝 열림
    d.rectangle([76, 18, 94, 64], fill=C("P01"))
    d.polygon([(76, 18), (66, 22), (66, 62), (76, 64)], fill=C(body[2]))
    d.line([71, 24, 71, 60], fill=C("P06"))
    d.rectangle([84, 20, 93, 63], fill=C(body[1]))
    d.line([88, 22, 88, 61], fill=C("P06")); d.line([91, 22, 91, 61], fill=C("P06"))
    d.rectangle([78, 52, 82, 60], fill=C("P18"))                          # 안에 보이는 나무 상자 모서리
    _rust(im, rnd, (4, 16, 75, 64), 120)
    put_text(im, "SEJIN", 14, 26, "P09", 8, "Galmuri9")
    put_text(im, "물류", 14, 38, "P08", 8, "Galmuri7")
    return im


def boat_wreck(seed=0):
    """떠밀려 온 한강 순찰 보트(108×72 — 3×2 발): 흰 선체에 파란 띠 · 판자 결 · 가로 좌판 둘 · 조타 칸 잔해 · 부서진 선외기 · 밧줄 사리 · 옆구리에 걸친 그물 ·
    기대 놓은 노 · 선수 번호 '3' · 둔치에 비스듬히 얹혀 선미가 들림. 접지 그림자는 선체 밑바닥을 따라간다."""
    rnd = random.Random(seed + 60)
    W_, H_ = 108, 72
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    hull = [(3, 34), (10, 54), (26, 60), (86, 62), (102, 46), (100, 28), (84, 22), (14, 26)]
    _hull_shadow(im, hull, 3, 4)
    d.polygon(hull, fill=C(INK))                                              # 선체 먹선
    d.polygon([(5, 35), (11, 52), (27, 58), (85, 60), (100, 46), (98, 30), (84, 24), (15, 28)], fill=C("P08"))
    d.polygon([(7, 38), (12, 50), (28, 56), (84, 58), (97, 46), (96, 36), (12, 38)], fill=C("P07"))   # 옆면(그늘)
    for y in (42, 47, 52):                                                    # 판자 이음(옆면)
        d.line([(9, y), (94, y + 1)], fill=C("P06"))
    d.line([(8, 40), (96, 41)], fill=C("P45")); d.line([(8, 41), (96, 42)], fill=C("P46")); d.line([(8, 42), (96, 43)], fill=C("P44"))   # 파란 띠
    deck = [(16, 29), (84, 26), (94, 32), (92, 40), (20, 42), (10, 36)]
    d.polygon(deck, fill=C(INK)); d.polygon([(17, 30), (83, 27), (92, 33), (90, 39), (21, 41), (12, 36)], fill=C("P19"))   # 갑판(나무)
    for x in range(22, 88, 6):                                                # 갑판 판자 결
        d.line([x, 29, x - 1, 40], fill=C("P18"))
    d.rectangle([30, 28, 33, 41], fill=C("P20")); d.rectangle([62, 27, 65, 40], fill=C("P20"))   # 가로 좌판
    d.line([30, 28, 33, 28], fill=C("P21")); d.line([62, 27, 65, 27], fill=C("P21"))
    d.polygon([(42, 27), (56, 26), (54, 12), (44, 14)], fill=C(INK))         # 조타 칸 잔해(기울어진 틀)
    d.polygon([(43, 26), (55, 25), (53, 13), (45, 15)], fill=C("P09"))
    d.rectangle([46, 16, 52, 21], fill=C("P10")); d.line([(47, 17), (50, 20)], fill=C("P12"))   # 깨진 창
    d.line([(49, 12), (60, 2)], fill=C("P06")); d.point((60, 2), fill=C("P53"))                # 꺾인 안테나
    d.ellipse([22, 32, 30, 38], fill=C("P21")); d.ellipse([24, 33, 28, 36], fill=C("P19")); d.arc([22, 32, 30, 38], 0, 360, fill=C("P18"))   # 밧줄 사리
    for k in range(0, 24, 4):                                                 # 옆구리에 걸친 그물(마름모 그물코)
        for yy in range(44, 58, 4):
            x = 66 + k + (2 if (yy // 4) % 2 else 0)
            d.point((x, yy), fill=C("P30")); d.point((x + 1, yy + 1), fill=C("P31")); d.point((x - 1, yy + 1), fill=C("P31")); d.point((x, yy + 2), fill=C("P30"))
    d.polygon([(98, 30), (106, 22), (108, 30), (102, 40)], fill=C(INK))       # 선외기(부서져 꺾임)
    d.polygon([(99, 31), (105, 24), (106, 30), (101, 38)], fill=C("P05")); d.line([(102, 26), (104, 28)], fill=C("P07"))
    d.rectangle([101, 40, 103, 50], fill=C("P04")); d.polygon([(99, 50), (106, 50), (104, 56), (101, 56)], fill=C("P03"))   # 프로펠러 축 · 날개(휨)
    d.line([(6, 60), (36, 28)], fill=C(INK), width=3); d.line([(7, 59), (36, 29)], fill=C("P20"))   # 기대 놓은 노
    d.polygon([(4, 60), (10, 64), (14, 60), (8, 56)], fill=C("P19"))
    d.rectangle([12, 29, 15, 32], fill=C("P05"))                              # 선수 밧줄 고리
    d.line([(13, 30), (4, 34)], fill=C("P21"))
    _rust(im, rnd, (8, 36, 98, 58), 36, ("P06", "P05", "P25"))
    for _ in range(14):                                                       # 물때 · 이끼(아랫줄)
        x, y = rnd.randint(12, 90), rnd.randint(50, 58)
        if im.getpixel((x, y))[3]:
            im.putpixel((x, y), C("P30"))
    put_text(im, "한강", 36, 44, "P44", 11, "Galmuri11")                       # 11px — 9px에선 '강' 받침이 뭉개져 '깅'으로 보였다(사용자 지적 2026-10-22)
    put_text(im, "3", 18, 44, "P53", 11, "Galmuri11")
    return im


def forklift(seed=0):
    """녹슨 지게차: 노란 몸통 · 앞 포크가 내려진 채 팰릿 하나 · 운전석 지붕. 2×2 발."""
    rnd = random.Random(seed + 70)
    W_, H_ = 66, 72
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 56, 64, 70)
    d.rectangle([2, 58, 26, 63], fill=C("P18")); d.line([2, 58, 26, 58], fill=C("P20"))   # 팰릿
    d.rectangle([4, 54, 24, 57], fill=C("P05")); d.rectangle([4, 46, 24, 48], fill=C("P05"))   # 포크
    d.rectangle([22, 10, 26, 58], fill=C("P04")); d.line([22, 10, 22, 58], fill=C("P06"))   # 마스트
    d.rectangle([26, 34, 62, 60], fill=C("P48"))                          # 몸통
    d.rectangle([26, 34, 62, 38], fill=C("P49"))
    d.rectangle([52, 40, 62, 60], fill=C("P47"))                          # 평형추
    for x in (32, 56):                                                    # 바퀴
        d.ellipse([x - 7, 54, x + 7, 68], fill=C("P01")); d.ellipse([x - 3, 58, x + 3, 64], fill=C("P05"))
    d.line([30, 34, 30, 10], fill=C("P02")); d.line([58, 34, 58, 12], fill=C("P02"))   # 운전석 기둥
    d.rectangle([28, 8, 60, 12], fill=C("P03"))
    d.rectangle([38, 26, 48, 34], fill=C("P02"))                          # 좌석
    d.rectangle([40, 24, 46, 27], fill=C("P17"))
    _rust(im, rnd, (26, 34, 62, 60), 50)
    return im


def greenhouse(seed=0):
    """무너진 비닐하우스: 반원 철골이 줄지어 서고 가운데가 내려앉았다 · 남은 비닐은 찢겨 늘어짐 · 안에 말라 죽은 고추 이랑. 3×2 발."""
    rnd = random.Random(seed + 80)
    W_, H_ = 100, 72
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 34, 98, 68], fill=C("P17"))                          # 흙 바닥
    d.line([2, 68, 98, 68], fill=C("P16"))
    for y in (40, 50, 60):                                                # 이랑과 죽은 작물
        d.line([6, y, 94, y], fill=C("P18"))
        for x in range(8, 94, 5):
            if rnd.random() < 0.75:
                d.line([x, y - 1, x + rnd.randint(-1, 1), y - rnd.randint(3, 5)], fill=C(rnd.choice(["P29", "P30", "P19", "P18"])))
    ridge = lambda x: 10 + (9 if 34 < x < 66 else (4 if 24 < x < 76 else 0))
    hoops = list(range(6, 98, 12))
    for a_, b_ in zip(hoops, hoops[1:]):                                  # 남은 비닐(위쪽 칸만, 아래 자락은 찢김)
        if rnd.random() < 0.55:
            top = max(ridge(a_), ridge(b_))
            bot = top + rnd.randint(10, 20)
            pts = [(a_ + 1, ridge(a_) + 1), (b_ - 1, ridge(b_) + 1)]
            for k in range(4):
                xx = b_ - 1 - k * (b_ - a_ - 2) // 3
                pts.append((xx, bot + rnd.randint(-4, 4)))
            d.polygon(pts, fill=C("P15"))
            for k in range(6):
                d.point((rnd.randint(a_ + 2, b_ - 2), rnd.randint(top + 2, bot - 2)), fill=C("P14"))
    for x in hoops:                                                       # 반원 철골(앞에서 보면 세로 기둥 + 둥근 머리)
        r = ridge(x)
        d.line([x, r + 4, x, 66], fill=C("P05"))
        d.line([x - 1, r + 6, x - 1, 66], fill=C("P06"))
        d.arc([x - 6, r, x + 6, r + 10], 200, 340, fill=C("P06"))
    d.line([(6, ridge(6)), (30, ridge(30))], fill=C("P07"))               # 용마루 철선(가운데 처짐)
    d.line([(30, ridge(30)), (42, ridge(42))], fill=C("P07"))
    d.line([(54, ridge(54)), (90, ridge(90))], fill=C("P07"))
    return im


def chem_leak(seed=0):
    """쓰러져 새는 화학 드럼: 노란 몸통 · 방사능 표지 · 형광 녹색 웅덩이(빛 — 반투명 없이 점 둘레). 1×1 발."""
    W_, H_ = 46, 34
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    d.ellipse([12, 18, 44, 32], fill=C("P55"))                            # 웅덩이
    d.ellipse([16, 21, 40, 29], fill=C("P56"))
    d.ellipse([22, 23, 32, 27], fill=C("P57"))
    d.rounded_rectangle([2, 8, 26, 26], 6, fill=C("P48"))                 # 누운 드럼
    d.ellipse([20, 8, 30, 26], fill=C("P47")); d.ellipse([22, 11, 28, 23], fill=C("P02"))
    d.line([2, 12, 22, 12], fill=C("P49"))
    for x in (9, 15):
        d.line([x, 9, x, 25], fill=C("P47"))
    d.ellipse([6, 14, 12, 20], fill=C("P01")); d.point((9, 17), fill=C("P49"))   # 방사능 표지(작게)
    return im


def bedroll(seed=0):
    """펼쳐 둔 침낭(36×22, 바닥 덧그림): 국방색/회청색 누빔 — 누빔 줄 · 지퍼 · 머리 쪽 접힌 베개 · 발치 뭉친 자국 · 옆에 놓인 양철 컵."""
    im = img(36, 22)
    d = ImageDraw.Draw(im)
    a, b, c = (("P30", "P31", "P29") if seed % 2 == 0 else ("P12", "P13", "P11"))
    d.rounded_rectangle([1, 4, 31, 18], 5, fill=C(INK))
    d.rounded_rectangle([2, 5, 30, 17], 5, fill=C(a))
    d.rounded_rectangle([2, 5, 30, 9], 4, fill=C(b))                        # 위쪽 빛
    for x in range(8, 28, 5):                                              # 누빔 줄
        d.line([x, 6, x, 16], fill=C(c))
    d.line([6, 11, 29, 11], fill=C(c)); d.line([7, 12, 28, 12], fill=C(INK))   # 지퍼
    for x in range(8, 28, 3):
        d.point((x, 12), fill=C("P09"))
    d.rounded_rectangle([3, 6, 9, 16], 3, fill=C("P20")); d.line([4, 8, 8, 8], fill=C("P21"))   # 베개
    d.ellipse([24, 8, 30, 15], fill=C(c))                                   # 발치 뭉친 자국
    d.rectangle([32, 10, 35, 15], fill=C("P12")); d.line([32, 10, 35, 10], fill=C("P14")); d.point((33, 12), fill=C("P11"))   # 양철 컵
    return im


def well(seed=0):
    """공동 우물(언덕 동네): 돌 테두리 · 기와 지붕 · 도르래와 양동이. 1×1 발."""
    im = img(36, 56)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 44, 34, 54)
    d.ellipse([3, 34, 33, 52], fill=C("P05"))
    d.ellipse([7, 36, 29, 46], fill=C("P01"))
    for x in range(5, 32, 6):
        d.line([x, 46, x, 50], fill=C("P04"))
    d.line([6, 40, 6, 10], fill=C("P18")); d.line([30, 40, 30, 10], fill=C("P18"))
    d.polygon([(0, 14), (18, 2), (36, 14), (32, 16), (4, 16)], fill=C("P13"))   # 지붕
    d.line([(0, 14), (18, 2)], fill=C("P14")); d.line([(18, 2), (36, 14)], fill=C("P12"))
    d.line([6, 20, 30, 20], fill=C("P19"))                                # 도르래 막대
    d.line([18, 20, 18, 30], fill=C("P07"))
    d.rectangle([14, 30, 22, 36], fill=C("P05")); d.line([14, 30, 22, 30], fill=C("P07"))   # 양동이
    return im


def tent(seed=0):
    """방수포 천막: 파란 방수포를 줄에 걸어 비스듬히 내렸다 · 안에 침낭 끝. 2×1 발."""
    im = img(66, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 32, 64, 42)
    col = ["P45", "P46", "P44"] if seed % 2 == 0 else ["P30", "P31", "P29"]
    d.polygon([(4, 38), (32, 6), (62, 38)], fill=C(col[0]))
    d.polygon([(32, 6), (62, 38), (46, 38)], fill=C(col[2]))
    d.polygon([(20, 38), (32, 18), (40, 38)], fill=C("P01"))              # 입구
    d.polygon([(26, 38), (32, 30), (36, 38)], fill=C("P30"))
    d.line([(32, 6), (32, 2)], fill=C("P18"))
    d.line([(4, 38), (0, 42)], fill=C("P07")); d.line([(62, 38), (66, 42)], fill=C("P07"))
    for (x, y) in ((14, 26), (48, 22), (40, 30)):                       # 덧댄 자국
        d.rectangle([x, y, x + 4, y + 3], fill=C(col[1]))
    return im


def kiosk_ruin(seed=0):
    """한강공원 매점 폐허: 반쯤 내려앉은 차양 · '매점' 간판 · 빈 진열대 · 깨진 냉장고. 2×1 발."""
    rnd = random.Random(seed + 90)
    im = img(66, 66)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 54, 64, 64)
    d.rectangle([4, 22, 62, 58], fill=C("P08"))                          # 몸통
    d.rectangle([4, 22, 62, 26], fill=C("P09"))
    d.rectangle([10, 32, 40, 52], fill=C("P01"))                         # 창구(빈)
    d.line([10, 42, 40, 42], fill=C("P05"))
    d.rectangle([46, 30, 58, 56], fill=C("P15")); d.rectangle([48, 32, 56, 54], fill=C("P34"))   # 음료 냉장고
    d.line([48, 36, 56, 48], fill=C("P09"))
    d.polygon([(2, 22), (64, 22), (60, 10), (6, 4)], fill=C("P53"))       # 기운 차양(빨강·흰 줄)
    for x in range(8, 60, 10):
        d.polygon([(x, 21), (x + 5, 21), (x + 4, 9 - (x // 20)), (x, 8 - (x // 20))], fill=C("P09"))
    d.rectangle([18, 12, 46, 20], fill=C("P01"))
    _rust(im, rnd, (4, 22, 62, 58), 30, ("P06", "P07", "P25"))
    put_text(im, "매점", 23, 12, "P49", 8, "Galmuri7")
    return im


def heli_wreck(seed=0):
    """추락한 소형 헬기(2077 경찰 항공대): 올리브 몸통이 기울어 박힘 · 꺾인 꼬리 · 휜 회전날개 · 깨진 앞 유리. 4×3 발."""
    rnd = random.Random(seed + 100)
    W_, H_ = 136, 104
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    _hull_shadow(im, [(8, 66), (14, 86), (76, 90), (84, 74), (130, 54), (132, 58), (80, 82), (70, 90), (14, 92), (6, 72)], 3, 4)   # 썰매 · 동체 밑 접지 띠 — 들린 꼬리 밑은 길게(타원 · 점무늬 아님)
    d.polygon([(70, 66), (128, 48), (132, 54), (74, 74)], fill=C("P29"))   # 꼬리 붐(꺾임)
    d.polygon([(118, 50), (130, 30), (134, 34), (128, 52)], fill=C("P30"))   # 꼬리 날개
    d.line([(74, 70), (128, 52)], fill=C("P28"))
    d.rounded_rectangle([18, 42, 84, 88], 20, fill=C("P30"))              # 몸통(뒤쪽이 길다)
    d.rounded_rectangle([18, 42, 84, 60], 18, fill=C("P31"))
    d.ellipse([6, 46, 40, 86], fill=C("P30"))                             # 기수(앞 유리 덮개)
    d.chord([8, 48, 38, 84], 150, 330, fill=C("P34"))                     # 앞 유리(위쪽 반)
    d.chord([12, 52, 34, 80], 160, 300, fill=C("P35"))
    d.line([(14, 58), (22, 54)], fill=C("P37"))                           # 유리 반사
    d.polygon([(22, 62), (30, 58), (26, 68)], fill=C("P01"))               # 깨진 자리
    d.line([8, 78, 84, 78], fill=C("P29"))
    d.rectangle([50, 54, 60, 74], fill=C("P01"))                          # 열린 문
    d.rectangle([40, 30, 56, 38], fill=C("P04"))                          # 회전날개 축
    d.line([(48, 30), (6, 12)], fill=C("P03")); d.line([(48, 31), (6, 13)], fill=C("P05"))   # 휜 날개
    d.line([(48, 30), (96, 22)], fill=C("P03")); d.line([(48, 31), (100, 26)], fill=C("P05"))
    d.line([(48, 30), (60, 2)], fill=C("P03"))
    d.line([(14, 90), (70, 92)], fill=C("P04")); d.line([(20, 86), (18, 92)], fill=C("P04"))   # 착륙 썰매
    for _ in range(6):                                                    # 그을음
        x, y = rnd.randint(20, 80), rnd.randint(40, 86)
        d.ellipse([x, y, x + rnd.randint(4, 9), y + rnd.randint(3, 6)], fill=C("P02"))
    _rust(im, rnd, (10, 40, 84, 88), 40, ("P28", "P29", "P24"))
    put_text(im, "경찰", 60, 59, "P09", 9, "Galmuri9")   # 받침이 뭉개지지 않게 9px 글꼴 · 녹 · 그을음 뒤에(사용자 지적 2026-10-22)
    return im


def slide(seed=0):
    """놀이터 미끄럼틀: 녹슨 계단 · 빛바랜 노란 미끄럼판 · 모래 자리. 2×1 발."""
    rnd = random.Random(seed + 110)
    im = img(66, 54)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 42, 64, 54], fill=C("P21"))                             # 모래
    d.line([8, 46, 8, 14], fill=C("P05")); d.line([18, 46, 18, 14], fill=C("P05"))   # 계단 기둥
    for y in range(18, 46, 6):
        d.line([8, y, 18, y], fill=C("P06"))
    d.rectangle([6, 10, 22, 14], fill=C("P53"))                           # 꼭대기
    d.polygon([(20, 12), (26, 10), (62, 44), (54, 48)], fill=C("P48"))    # 미끄럼판
    d.line([(26, 10), (62, 44)], fill=C("P49"))
    d.line([(20, 12), (54, 48)], fill=C("P47"))
    _rust(im, rnd, (6, 10, 62, 48), 30)
    return im


def fishing_gear(seed=0):
    """낚시 도구(바닥 덧그림): 기대 놓은 낚싯대 둘 · 녹슨 태클 상자 · 빈 통조림."""
    im = img(36, 30)
    d = ImageDraw.Draw(im)
    d.line([(2, 28), (30, 2)], fill=C("P18")); d.line([(6, 28), (34, 6)], fill=C("P05"))
    d.point((31, 2), fill=C("P09")); d.point((34, 6), fill=C("P09"))
    d.rectangle([14, 18, 28, 27], fill=C("P53")); d.rectangle([14, 18, 28, 20], fill=C("P54"))
    d.line([20, 16, 22, 16], fill=C("P05"))
    d.rectangle([4, 20, 9, 26], fill=C("P06")); d.line([4, 20, 9, 20], fill=C("P08"))
    return im


def garden_box(seed=0):
    """옥상·계단참 텃밭 상자: 나무 상자 흙에 살아남은 상추·고추 몇 포기. 1×1 발."""
    rnd = random.Random(seed + 120)
    im = img(32, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 12, 30, 28], fill=C("P18")); d.rectangle([2, 12, 30, 14], fill=C("P20"))
    d.rectangle([4, 14, 28, 18], fill=C("P16"))
    for k in range(6):
        x = 5 + k * 4
        h = rnd.randint(4, 8)
        d.line([x, 14, x, 14 - h], fill=C("P55"))
        d.ellipse([x - 2, 12 - h, x + 2, 15 - h], fill=C("P56" if k % 2 else "P55"))
        if k % 3 == 2:
            d.point((x + 1, 13 - h + 2), fill=C("P53"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_SITE = {
    "bus_wreck": _r(lambda: bus_wreck(0), 4, 2, down=-4),
    "container": _r(lambda: container(0), 3, 2, down=-2),
    "container2": _r(lambda: container(1), 3, 2, down=-2),
    "boat_wreck": _r(lambda: boat_wreck(0), 3, 2, down=-2, dx=-6, dy=-4),
    "forklift": _r(lambda: forklift(0), 2, 2, down=-2),
    "greenhouse": _r(lambda: greenhouse(0), 3, 2, down=-2),
    "chem_leak": _r(lambda: chem_leak(0), 1, 1, down=-2),
    "bedroll": _r(lambda: bedroll(0), 0, 0, "deco"),
    "bedroll2": _r(lambda: bedroll(1), 0, 0, "deco"),
    "well": _r(lambda: well(0), 1, 1, down=-2),
    "tent": _r(lambda: tent(0), 2, 1, down=-2),
    "tent2": _r(lambda: tent(1), 2, 1, down=-2),
    "kiosk_ruin": _r(lambda: kiosk_ruin(0), 2, 1, down=-2),
    "heli_wreck": _r(lambda: heli_wreck(0), 4, 3, down=-2),
    "slide": _r(lambda: slide(0), 2, 1, down=-2),
    "fishing_gear": _r(lambda: fishing_gear(0), 0, 0, "deco"),
    "garden_box": _r(lambda: garden_box(0), 1, 1, down=-2),
}


if __name__ == "__main__":                                                  # 견본: 한 장에 늘어놓고 2배
    out = sys.argv[1] if len(sys.argv) > 1 else "props_site_sheet.png"
    ims = [(k, v["fn"]()) for k, v in PROPS_SITE.items()]
    W_ = 16 + sum(i.width + 12 for _, i in ims[:9])
    sheet = Image.new("RGBA", (max(W_, 900), 260), C("P30")[:3] + (255,))
    x, y, row_h = 8, 8, 0
    for k, i in ims:
        if x + i.width > sheet.width - 8:
            x, y = 8, y + row_h + 10
            row_h = 0
        sheet.alpha_composite(i, (x, y))
        x += i.width + 12
        row_h = max(row_h, i.height)
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
    print(out)
