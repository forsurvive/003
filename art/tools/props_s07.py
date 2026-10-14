"""볼트 S-07 실내 소품 묶음 (단계 0-5, SD-09a §L-R01-01 ③ 실내 구성, SD-16 §6.3 볼트 내부·§3 아이작풍 굵은 먹선).
기존 견본 소품(tiles_s07)을 감싸고, 실내 12장(V-00~V-11)에 필요한 소품을 더 그린다.
규칙: 위에서 고르게 내려오는 천장 빛(그림자 없음, 바닥 접지 그늘 2px는 게임이 바닥 합성 층에서 그린다),
      윗면은 밝게 · 남쪽 앞면은 한 단 어둡게, 왼쪽 위 1px 반짝임, 먹선은 내보낼 때(tiles_isaac.outline) 두른다.
등록부 PROPS: 이름 → 그리기 함수 · 발 칸(가로, 세로; 막히는 칸) · 종류(floor 바닥에 서는 것 / wall 벽면에 거는 것 /
      deco 밟고 지나가는 바닥 장식 / door 벽면 문) · down(발 칸 아래로 내려오는 그림 px) · 벽 소품의 칸 안 위치(dx, dy).
내보내기: tools/pipeline/prop_export.py → game/assets/props/s07_props.png + .json"""
import os, sys, math, random
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import tiles_s07 as S
from tiles_s07 import C, text, F7, F9, T


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def block(d, x0, y0, x1, y1, top_h, top, face, hi=None, dark=None):
    """윗면(top_h px) + 앞면 상자. top/face: 색 토큰, hi: 윗면 왼쪽 위 반짝임, dark: 앞면 아래 띠."""
    d.rectangle([x0, y0, x1, y0 + top_h - 1], fill=C(top))
    d.rectangle([x0, y0 + top_h, x1, y1], fill=C(face))
    if hi:
        d.line([x0, y0, x1, y0], fill=C(hi)); d.line([x0, y0, x0, y0 + top_h - 1], fill=C(hi))
    d.line([x0, y0 + top_h, x1, y0 + top_h], fill=C("P02"))
    if dark:
        d.line([x0, y1, x1, y1], fill=C(dark))


def crt(d, x0, y0, x1, y1, lines=2, scr="U"):
    """세진 크림색 화면 테 + 녹색(U) 또는 호박색(A) 화면."""
    d.rectangle([x0, y0, x1, y1], fill=C("P08"))
    d.line([x0, y0, x1, y0], fill=C("P09"))
    d.rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 3], fill=C(scr + "1"))
    d.line([x0 + 2, y0 + 2, x1 - 2, y0 + 2], fill=C(scr + "2"))
    for k in range(lines):
        y = y0 + 4 + k * 3
        if y < y1 - 4:
            d.line([x0 + 4, y, x0 + 4 + (x1 - x0 - 8) * (3 - k) // 4, y], fill=C(scr + ("6" if k == 0 else "4")))


# ================================================================ 문·출입
def door(label=None, state="closed", kind="slide"):
    """벽면 문(1칸 × 2칸): slide 기밀 미닫이 / hatch 오버시어 비상문(붉은 띠) / iron 배수 갱도 원형 철문."""
    if kind == "slide":
        return S.door_slide(state, label)
    im = img(T, 2 * T)
    d = ImageDraw.Draw(im)
    if kind == "hatch":
        d.rectangle([0, 0, 31, 63], fill=C("P13"))
        d.rectangle([3, 6, 28, 63], fill=C("P11"))
        if state == "closed":
            d.rectangle([5, 8, 26, 63], fill=C("P05")); d.line([5, 8, 26, 8], fill=C("P07")); d.line([5, 8, 5, 63], fill=C("P07"))
            for y in range(12, 60, 8):
                d.line([7, y, 24, y], fill=C("P04"))
            d.rectangle([5, 30, 26, 35], fill=C("P53"))
            for x in range(5, 27, 4):
                d.polygon([(x, 35), (x + 2, 30), (x + 3, 30), (x + 1, 35)], fill=C("P02"))
            d.ellipse([20, 40, 25, 45], fill=C("P48"), outline=C("P02"))
        else:
            d.rectangle([5, 8, 26, 63], fill=C("P10"))
        d.rectangle([2, 0, 29, 4], fill=C("P53")); d.line([2, 0, 29, 0], fill=C("P54"))
        text(d, (16, 0), "비상", F7, "P09", anchor="ma")
    else:                                                            # iron: 원형 철문(배수 갱도)
        d.rectangle([0, 0, 31, 63], fill=C("P11"))
        d.ellipse([1, 14, 30, 63], fill=C("P24"), outline=C("P02"))
        if state == "closed":
            d.ellipse([4, 17, 27, 60], fill=C("P25"))
            d.arc([4, 17, 27, 60], 180, 270, fill=C("P27"))
            d.ellipse([11, 33, 20, 44], outline=C("P23"), width=2)
            d.line([15, 30, 15, 47], fill=C("P23")); d.line([8, 38, 23, 38], fill=C("P23"))
            for a in range(0, 360, 45):
                x = 15.5 + 12.5 * math.cos(math.radians(a)); y = 38.5 + 20 * math.sin(math.radians(a))
                d.point((round(x), round(y)), fill=C("P06"))
        else:
            d.ellipse([4, 17, 27, 60], fill=C("P00"))
        d.rectangle([4, 2, 27, 10], fill=C("P48")); d.line([4, 2, 27, 2], fill=C("P49"))
        text(d, (16, 2), "배수", F7, "P02", anchor="ma")
    return im


def lever_panel():
    """정문 제어반(벽): 레버 2단 + 진공관 표시등."""
    im = img(2 * T, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 39], fill=C("P05")); d.line([0, 0, 63, 0], fill=C("P07")); d.line([0, 0, 0, 39], fill=C("P07"))
    d.rectangle([3, 3, 60, 10], fill=C("P02"))
    for i, x in enumerate(range(6, 58, 7)):
        d.ellipse([x, 4, x + 4, 8], fill=C(("P59", "P56", "P59", "P53", "P59", "P56", "P59", "P59")[i]))
    for x, up in ((14, True), (42, False)):
        d.rectangle([x - 6, 14, x + 6, 36], fill=C("P03"))
        d.rectangle([x - 1, 17 if up else 24, x + 1, 30 if up else 33], fill=C("P07"))
        d.rectangle([x - 4, 15 if up else 31, x + 4, 19 if up else 35], fill=C("P53"))
        d.line([x - 4, 15 if up else 31, x + 4, 15 if up else 31], fill=C("P54"))
    text(d, (14, 0), "", F7, "P09")
    return im


def gear_door(frame=0):
    return S.gear_door(frame, GEAR_FRAMES)


# ================================================================ 벽 소품
def service_window(label="배급과"):
    im = S.ration_window()
    if label != "배급과":
        d = ImageDraw.Draw(im)
        d.rectangle([14, 1, 49, 8], fill=C("P44")); d.line([14, 1, 49, 1], fill=C("P46"))
        text(d, (32, 1), label, F7, "P09", anchor="ma")
    return im


def booth_window():
    """구내방송실 유리창(벽 2칸): 마이크와 진공관 송출기, '방송 중' 등."""
    im = img(2 * T, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 6, 63, 43], fill=C("P11")); d.line([0, 6, 63, 6], fill=C("P14"))
    d.rectangle([3, 9, 60, 36], fill=C("P33"))
    d.line([4, 10, 20, 10], fill=C("P37")); d.line([4, 10, 4, 22], fill=C("P37"))
    d.rectangle([8, 22, 30, 36], fill=C("P08")); d.line([8, 22, 30, 22], fill=C("P09"))
    for x in (11, 16, 21, 26):
        d.ellipse([x, 25, x + 3, 28], fill=C("P59"))
    d.line([44, 16, 44, 30], fill=C("P04")); d.ellipse([41, 12, 47, 18], fill=C("P03")); d.point((43, 14), fill=C("P07"))
    d.rectangle([0, 37, 63, 43], fill=C("P07")); d.line([0, 37, 63, 37], fill=C("P09"))
    d.rectangle([18, 0, 45, 6], fill=C("P53")); d.line([18, 0, 45, 0], fill=C("P54"))
    text(d, (32, 0), "방송 중", F7, "P09", anchor="ma")
    return im


def wall_terminal():
    """벽걸이 세진 단말(1칸): 녹색 화면 + 자판 선반."""
    im = img(T, 34)
    d = ImageDraw.Draw(im)
    crt(d, 3, 0, 28, 22, 3)
    d.rectangle([5, 22, 26, 25], fill=C("P06"))
    d.rectangle([2, 26, 29, 33], fill=C("P07")); d.line([2, 26, 29, 26], fill=C("P09"))
    for x in range(5, 27, 3):
        d.point((x, 29), fill=C("P04")); d.point((x + 1, 31), fill=C("P04"))
    return im


def notice_board(n=2, seed=3):
    """게시판(벽): 코르크판 + 쪽지·배급 공지."""
    rnd = random.Random(seed)
    w = n * T
    im = img(w, 28)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, 27], fill=C("P18")); d.rectangle([2, 2, w - 3, 25], fill=C("P20"))
    for _ in range(n * 4):
        x, y = rnd.randint(3, w - 14), rnd.randint(3, 14)
        col = rnd.choice(("P09", "P08", "P22", "P15"))
        d.rectangle([x, y, x + rnd.randint(8, 12), y + rnd.randint(7, 10)], fill=C(col), outline=C("P06"))
        d.point((x + 4, y + 1), fill=C(rnd.choice(("P53", "P45", "P49"))))
        for yy in range(y + 3, y + 7, 2):
            d.line([x + 2, yy, x + 7, yy], fill=C("P05"))
    return im


def memorial_plaque(lines=("2261. 04. 17.", "원자로실 사고 순직자")):
    """추모 명판(벽): 청동판 + 새긴 글."""
    im = img(3 * T, 24)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 23], fill=C("P19")); d.rectangle([2, 2, 93, 21], fill=C("P20"))
    d.line([2, 2, 93, 2], fill=C("P22")); d.line([2, 21, 93, 21], fill=C("P18"))
    for i, s in enumerate(lines[:2]):
        text(d, (48, 4 + i * 8), s, F7, "P17", anchor="ma")
    return im


def sign_plate(label, color="P44"):
    """문패·구역 표지(벽): 남색 판 + 흰 글자. 글자 길이에 맞춰 폭을 정한다."""
    w = max(24, 8 + 8 * len(label))
    im = img(w, 11)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, 10], fill=C(color)); d.line([0, 0, w - 1, 0], fill=C("P46" if color == "P44" else "P09"))
    text(d, (w // 2, 1), label, F7, "P09", anchor="ma")
    return im


def quarantine_sign():
    """2196년 회색 열병 격리 표지(벽): 노란 판 + 붉은 띠."""
    im = img(T, 24)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 31, 23], fill=C("P48")); d.line([0, 0, 31, 0], fill=C("P49"))
    d.rectangle([0, 15, 31, 19], fill=C("P53"))
    text(d, (16, 2), "격리", F7, "P02", anchor="ma")
    text(d, (16, 8), "2196", F7, "P17", anchor="ma")
    return im


def wall_pipes(n=3):
    """벽을 따라가는 배관 두 줄(벽 n칸) + 밸브."""
    w = n * T
    im = img(w, 22)
    d = ImageDraw.Draw(im)
    for y0, c in ((2, ("P05", "P07", "P04")), (11, ("P24", "P26", "P23"))):
        d.rectangle([0, y0, w - 1, y0 + 6], fill=C(c[0]))
        d.line([0, y0 + 1, w - 1, y0 + 1], fill=C(c[1])); d.line([0, y0 + 6, w - 1, y0 + 6], fill=C(c[2]))
        for x in range(10, w, 32):
            d.rectangle([x, y0 - 1, x + 2, y0 + 7], fill=C("P04"))
    d.ellipse([w - 22, 0, w - 8, 14], outline=C("P53"), width=2); d.line([w - 15, 1, w - 15, 13], fill=C("P53"))
    d.line([w - 21, 7, w - 9, 7], fill=C("P53"))
    return im


def duct_grille():
    """환기 덕트 진입구(벽 1칸): 나사 풀린 격자 덮개."""
    im = img(T, 26)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 0, 29, 25], fill=C("P04"))
    d.rectangle([4, 2, 27, 23], fill=C("P01"))
    for y in range(4, 22, 3):
        d.line([5, y, 26, y], fill=C("P05"))
    for x, y in ((3, 1), (28, 1), (3, 24)):
        d.point((x, y), fill=C("P07"))
    return im


HATCH_WHEEL = 4                                      # 원형 철문: 바퀴 4컷(22.5도씩, 손잡이 4개라 90도마다 같은 그림) + 문 젖힘 6컷(15도씩)
HATCH_SWING = 6
HATCH_FRAMES = HATCH_WHEEL + HATCH_SWING


def drain_hatch(frame=0):
    """비상 배수 갱도 원형 철문(V-11, 벽면 3칸 × 2줄 = 96×64, 바닥선에 붙는다).
    컷 0~3: 닫힌 문의 바퀴가 22.5도씩 돈다. 컷 4~9: 왼쪽 경첩으로 15~90도 젖혀진다(문 면이 cos만큼 좁아지고, 두께가 sin만큼 보인다).
    문 뒤는 갱도: 검은 원통 안쪽 고리 셋 + 젖은 바닥 반사 + 끝의 흰 바깥 빛(디더). 녹은 아래쪽에 고인다."""
    W, H = 96, 64
    im = img(W, H)
    px = im.load()
    cx, cy = 48, 33
    R_COL, R_IN, R_DOOR = 30, 26, 25
    wheel = frame if frame < HATCH_WHEEL else 0
    th = math.radians(15 * (frame - HATCH_WHEEL + 1)) if frame >= HATCH_WHEEL else 0.0
    def put(x, y, t):
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = C(t)
    # 콘크리트 테(집수 고리)
    for y in range(H):
        for x in range(W):
            dx, dy = x - cx + 0.5, y - cy + 0.5
            r = math.hypot(dx, dy)
            if R_IN <= r <= R_COL:
                lit = (-dx - dy) / max(r, 1)
                put(x, y, "P13" if lit > 0.45 else ("P10" if lit < -0.55 else "P11"))
            elif r < R_IN:                                     # 갱도 안쪽(문이 가리지 않는 곳만 보인다)
                put(x, y, "P00")
    for k in range(8):                                         # 테의 볼트
        a = k * math.pi / 4 + math.pi / 8
        bx, by = round(cx + 28 * math.cos(a)), round(cy + 28 * math.sin(a))
        put(bx, by, "P07"); put(bx + 1, by + 1, "P10")
    # 갱도 깊이: 안쪽 고리 셋 + 끝의 바깥 빛 + 젖은 바닥
    for rr, t in ((21, "P01"), (15, "P02"), (10, "P01")):
        for i in range(160):
            a = i * 2 * math.pi / 160
            put(round(cx + rr * math.cos(a)), round(cy - 2 + rr * 0.92 * math.sin(a)), t)
    for y in range(cy - 7, cy + 4):
        for x in range(cx - 5, cx + 6):
            r = math.hypot(x - cx, (y - cy + 2) * 1.1)
            if r <= 3.2:
                put(x, y, "P09")
            elif r <= 5.4 and (x + y) % 2 == 0:
                put(x, y, "P08")
    for x in range(cx - 14, cx + 15):                          # 바닥에 고인 물: 바깥 빛이 한 줄 비친다
        y = cy + 17 - round(abs(x - cx) * 0.12)
        put(x, y, "P35" if abs(x - cx) > 3 else "P37")
        if abs(x - cx) <= 8 and x % 3 == 0:
            put(x, y + 2, "P36")
    # 문(경첩 = 왼쪽 끝). 젖힐수록 면이 cos로 좁아지고 어두워진다
    s = math.cos(th)
    hx = cx - R_DOOR
    face = ["P05", "P04", "P04", "P03", "P03", "P02", "P02"][min(6, int(round(math.degrees(th) / 15)))]
    for y in range(H):
        for x in range(W):
            if s < 0.05:
                break
            lx = (x + 0.5 - hx) / s - R_DOOR                  # 문 면 좌표(가운데 0)
            ly = y + 0.5 - cy
            r = math.hypot(lx, ly)
            if r > R_DOOR:
                continue
            t = face
            lit = (-lx - ly) / max(r, 1)
            if r > R_DOOR - 2.2:
                t = "P07" if lit > 0.3 and th == 0 else "P03"                       # 테두리 띠
            elif r > R_DOOR - 4.5:
                t = "P04"
            elif th == 0 and lit > 0.55 and r > 14:
                t = "P06"                                                           # 위왼쪽 반사
            n = ((int(lx + 40) * 73856093) ^ (int(ly + 40) * 19349663)) % 97 / 97.0   # 문 면에 붙은 녹(젖혀도 같은 자리)
            if ly > 4 and r < R_DOOR - 3 and n < (ly - 4) / 26.0:
                t = "P25" if n < (ly - 4) / 70.0 else "P24"                          # 아래로 갈수록 짙게 고인 녹
            put(x, y, t)
    if th > 0:                                                 # 문 두께(젖혀진 만큼 오른쪽 끝에 보인다)
        thick = max(1, round(5 * math.sin(th)))
        for y in range(H):
            ly = y + 0.5 - cy
            if abs(ly) > R_DOOR - 1:
                continue
            ex = hx + 2 * R_DOOR * s * (math.sqrt(max(0.0, 1 - (ly / R_DOOR) ** 2)) * 0.5 + 0.5)
            for k in range(thick):
                put(round(ex) + k, y, "P02" if k else "P06")
    # 바퀴(손잡이 4개): 문 면 좌표에서 그려 cos로 눌러 찍는다
    if s > 0.2:
        rot = math.radians(22.5 * wheel)
        def wp(lx, ly):
            return round(hx + (lx + R_DOOR) * s), round(cy + ly)
        for i in range(120):
            a = i * 2 * math.pi / 120
            for rr, t in ((12, "P02"), (11, "P07" if th == 0 else "P05")):
                x, y = wp(rr * math.cos(a), rr * math.sin(a))
                put(x, y, t)
        for k in range(4):
            a = rot + k * math.pi / 2
            for step in range(3, 11):
                x, y = wp(step * math.cos(a), step * math.sin(a))
                put(x, y, "P06" if th == 0 else "P04"); put(x, y + 1, "P02")
            x, y = wp(12.5 * math.cos(a), 12.5 * math.sin(a))      # 손잡이 혹
            put(x, y, "P08" if th == 0 else "P05"); put(x + 1, y, "P03")
        hx0, hy0 = wp(0, 0)
        for dx in (-2, -1, 0, 1, 2):
            for dy in (-2, -1, 0, 1, 2):
                if dx * dx + dy * dy <= 5:
                    put(hx0 + dx, hy0 + dy, "P03" if dx * dx + dy * dy > 2 else ("P07" if th == 0 else "P04"))
    # 경첩(왼쪽): 두 개
    for yy in (cy - 14, cy + 10):
        for x in range(hx - 4, hx + 2):
            for y in range(yy, yy + 5):
                put(x, y, "P03" if y in (yy, yy + 4) else "P05")
        put(hx - 2, yy + 2, "P08")
    return im


def wall_clock():
    return S.wall_clock(10, 12)


def gun_rack():
    """보안과 총기 거치대(벽에 붙은 2칸, 바닥 1줄): 공기총 4정 + 진압봉."""
    im = img(2 * T, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 55], fill=C("P17")); d.rectangle([2, 2, 61, 53], fill=C("P18"))
    d.line([2, 2, 61, 2], fill=C("P20"))
    for i, x in enumerate((8, 20, 32, 44)):
        d.rectangle([x, 6, x + 3, 44], fill=C("P03")); d.rectangle([x, 30, x + 3, 44], fill=C("P19"))
        d.line([x, 6, x, 44], fill=C("P05"))
    d.rectangle([54, 10, 57, 46], fill=C("P02")); d.rectangle([53, 10, 58, 14], fill=C("P05"))
    d.rectangle([2, 46, 61, 53], fill=C("P16")); d.line([2, 46, 61, 46], fill=C("P19"))
    d.rectangle([26, 48, 37, 51], fill=C("P49"))
    return im


# ================================================================ 바닥 소품(발 칸이 막힌다)
def terminal_desk():
    """책상 + 세진 단말(1칸)."""
    im = img(T, T + 14)
    d = ImageDraw.Draw(im)
    crt(d, 6, 0, 25, 15, 2)
    block(d, 1, 14, 30, 34, 10, "P08", "P06", hi="P09", dark="P04")
    d.rectangle([8, 16, 23, 20], fill=C("P07")); d.line([8, 16, 23, 16], fill=C("P09"))     # 자판
    for x in (3, 27):
        d.rectangle([x, 35, x + 1, 44], fill=C("P04"))
    d.rectangle([10, 25, 21, 30], fill=C("P05"))
    return im


def file_cabinet():
    """서류장(1칸, 벽에 붙는다): 서랍 4단."""
    im = img(T, 54)
    d = ImageDraw.Draw(im)
    block(d, 2, 0, 29, 53, 6, "P07", "P05", hi="P08", dark="P03")
    for y in (9, 20, 31, 42):
        d.rectangle([5, y, 26, y + 9], fill=C("P06")); d.line([5, y, 26, y], fill=C("P07"))
        d.rectangle([12, y + 3, 19, y + 5], fill=C("P03")); d.rectangle([20, y + 2, 24, y + 4], fill=C("P09"))
    return im


def bookshelf(n=2, seed=5):
    """책장(n칸, 벽에 붙는다)."""
    rnd = random.Random(seed)
    w = n * T
    im = img(w, 60)
    d = ImageDraw.Draw(im)
    block(d, 0, 0, w - 1, 59, 5, "P20", "P18", hi="P21", dark="P16")
    for y in (8, 25, 42):
        d.rectangle([3, y, w - 4, y + 14], fill=C("P16"))
        x = 4
        while x < w - 6:
            bw = rnd.randint(2, 4)
            h = rnd.randint(9, 14)
            col = rnd.choice(("P44", "P53", "P29", "P48", "P08", "P24", "P45", "P31"))
            d.rectangle([x, y + 14 - h, x + bw - 1, y + 13], fill=C(col))
            d.point((x, y + 15 - h), fill=C("P09"))
            x += bw + (1 if rnd.random() < 0.3 else 0)
        d.line([3, y + 15, w - 4, y + 15], fill=C("P20"))
    return im


def counter(n=3, label=None):
    """창구 카운터(n칸 × 1): 크림 상판 + 유리 칸막이 + 볼트 청 앞판."""
    w = n * T
    im = img(w, T + 16)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 0, w - 3, 13], fill=C("P15")); d.line([2, 0, w - 3, 0], fill=C("P09"))
    d.line([2, 0, 2, 13], fill=C("P09"))
    for x in range(T, w - 2, T):
        d.line([x, 0, x, 13], fill=C("P07"))
    d.rectangle([8, 6, 20, 13], fill=C("P02"))                                   # 말하는 구멍
    block(d, 0, 12, w - 1, 46, 8, "P08", "P45", hi="P09", dark="P43")
    d.line([1, 21, w - 2, 21], fill=C("P46"))
    d.rectangle([0, 28, w - 1, 31], fill=C("P48")); d.line([0, 28, w - 1, 28], fill=C("P49"))
    if label:
        d.rectangle([w // 2 - 18, 34, w // 2 + 17, 43], fill=C("P09"))
        text(d, (w // 2, 35), label, F7, "P43", anchor="ma")
    d.rectangle([w - 26, 14, w - 18, 18], fill=C("P53"))                       # 도장
    return im


def meeting_table():
    """평가 위원회 회의 탁자(3칸 × 2): 짙은 나무 + 서류."""
    w, h = 3 * T, 2 * T
    im = img(w, h + 8)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([1, 4, w - 2, h - 8], radius=10, fill=C("P17"))
    d.rounded_rectangle([3, 6, w - 4, h - 12], radius=8, fill=C("P19"))
    d.line([10, 7, w - 11, 7], fill=C("P20"))
    for x, y in ((14, 14), (44, 22), (70, 12)):
        d.rectangle([x, y, x + 12, y + 8], fill=C("P09"), outline=C("P06"))
        d.line([x + 2, y + 3, x + 9, y + 3], fill=C("P05"))
    d.rounded_rectangle([1, h - 12, w - 2, h - 3], radius=4, fill=C("P16"))
    d.rectangle([12, h - 3, 14, h + 6], fill=C("P02")); d.rectangle([w - 15, h - 3, w - 13, h + 6], fill=C("P02"))
    return im


def chair(face="N"):
    """사무 의자(장식, 밟고 지나가지 않는다 — 발 칸 없음으로 둔다)."""
    im = img(16, 20)
    d = ImageDraw.Draw(im)
    if face == "N":
        d.rectangle([2, 0, 13, 10], fill=C("P44")); d.line([3, 1, 12, 1], fill=C("P45"))
        d.rectangle([2, 11, 13, 14], fill=C("P43"))
    else:
        d.rectangle([2, 4, 13, 12], fill=C("P45")); d.line([3, 5, 12, 5], fill=C("P46"))
        d.rectangle([2, 0, 13, 3], fill=C("P44"))
    d.rectangle([7, 15, 8, 17], fill=C("P04")); d.line([3, 18, 12, 18], fill=C("P03"))
    return im


def bench(n=2):
    """긴 의자(n칸 × 1)."""
    w = n * T
    im = img(w, 22)
    d = ImageDraw.Draw(im)
    block(d, 1, 2, w - 2, 12, 6, "P20", "P18", hi="P21", dark="P16")
    for x in (4, w - 7):
        d.rectangle([x, 13, x + 2, 21], fill=C("P04"))
    return im


def pillar():
    """아트리움 기둥(1칸): 볼트 청 띠 + 노란 번호."""
    im = img(T, 80)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 0, 29, 79], fill=C("P12"))
    d.line([3, 0, 3, 79], fill=C("P14")); d.line([28, 0, 28, 79], fill=C("P10"))
    d.rectangle([2, 0, 29, 6], fill=C("P13")); d.line([2, 0, 29, 0], fill=C("P15"))
    d.rectangle([2, 40, 29, 47], fill=C("P44")); d.line([2, 40, 29, 40], fill=C("P46"))
    d.rectangle([2, 64, 29, 69], fill=C("P48")); d.line([2, 64, 29, 64], fill=C("P49"))
    for y in (12, 26, 54):
        d.point((6, y), fill=C("P15")); d.point((25, y), fill=C("P15"))
    return im


def tube_rack(seed=2):
    """출생 등록 단말기 진공관 랙(2칸 × 1, 벽에 붙는다): 호박색으로 빛나는 진공관 3단."""
    rnd = random.Random(seed)
    im = img(2 * T, 66)
    d = ImageDraw.Draw(im)
    block(d, 0, 0, 63, 65, 5, "P07", "P03", hi="P08", dark="P01")
    for r, y in enumerate((9, 27, 45)):
        d.rectangle([3, y, 60, y + 14], fill=C("P02"))
        for x in range(6, 58, 8):
            lit = rnd.random() < 0.8
            d.ellipse([x, y + 2, x + 5, y + 11], fill=C("P59" if lit else "P04"), outline=C("P58" if lit else "P03"))
            if lit:
                d.point((x + 2, y + 4), fill=C("P60"))
        d.line([3, y + 15, 60, y + 15], fill=C("P05"))
    d.rectangle([50, 60, 56, 63], fill=C("P56"))
    return im


def tape_cabinet():
    """계보 대장 테이프 보관함(1칸, 벽에 붙는다): 릴 테이프 + 열쇠 구멍."""
    im = img(T, 56)
    d = ImageDraw.Draw(im)
    block(d, 1, 0, 30, 55, 5, "P20", "P17", hi="P21", dark="P16")
    d.rectangle([4, 8, 27, 40], fill=C("P15")); d.rectangle([4, 8, 27, 40], outline=C("P07"))
    for y in (11, 22, 33):
        for x in (6, 17):
            d.ellipse([x, y, x + 8, y + 6], fill=C("P03")); d.point((x + 4, y + 3), fill=C("P07"))
    d.rectangle([13, 45, 18, 50], fill=C("P48")); d.point((15, 47), fill=C("P02"))
    return im


def judge_machine():
    """세진 적성 판정기(3칸 × 2): 판독 카드 투입구, 진공관 창, 출력 프린터, '수정 금지' 봉인."""
    w = 3 * T
    im = img(w, 2 * T + 30)
    d = ImageDraw.Draw(im)
    block(d, 0, 0, w - 1, 2 * T + 29, 14, "P08", "P07", hi="P09", dark="P05")
    d.rectangle([6, 18, 50, 46], fill=C("P02"))
    for x in range(9, 48, 7):
        d.ellipse([x, 22, x + 4, 30], fill=C("P59"), outline=C("P58")); d.point((x + 1, 24), fill=C("P60"))
    crt(d, 9, 32, 48, 45, 2, "A")
    d.rectangle([58, 20, 88, 26], fill=C("P02")); d.line([60, 23, 86, 23], fill=C("P05"))         # 카드 투입구
    text(d, (73, 28), "카드", F7, "P04", anchor="ma")
    d.rectangle([56, 46, 90, 62], fill=C("P05")); d.rectangle([60, 40, 86, 48], fill=C("P09"))      # 프린터 + 종이
    for y in (42, 44, 46):
        d.line([63, y, 82, y], fill=C("P06"))
    d.rectangle([6, 52, 46, 60], fill=C("P53")); text(d, (26, 53), "수정 금지", F7, "P09", anchor="ma")
    d.rectangle([4, 70, w - 5, 76], fill=C("P44")); d.line([4, 70, w - 5, 70], fill=C("P46"))
    text(d, (w // 2, 2), "세진 판정기 SJ-AP7", F7, "P04", anchor="ma")
    return im


def record_locker():
    """평가 기록 보관장(2칸, 벽에 붙는다): 철제 서랍 2열."""
    im = img(2 * T, 52)
    d = ImageDraw.Draw(im)
    block(d, 0, 0, 63, 51, 5, "P07", "P05", hi="P08", dark="P03")
    for c in range(2):
        for r in range(4):
            x, y = 3 + c * 30, 8 + r * 10
            d.rectangle([x, y, x + 27, y + 8], fill=C("P06")); d.line([x, y, x + 27, y], fill=C("P07"))
            d.rectangle([x + 10, y + 3, x + 17, y + 4], fill=C("P03"))
            d.rectangle([x + 2, y + 2, x + 6, y + 5], fill=C("P09"))
    return im


def grow_shelf(crop="lettuce", mold=False, seed=1):
    """수경 재배 선반(3칸 × 1): 2단 양액 트레이 + 작물(lettuce 상추 · bean 콩 · mushroom 버섯 · rice 쌀). mold: 곰팡이병."""
    rnd = random.Random(seed)
    w = 3 * T
    im = img(w, 50)
    d = ImageDraw.Draw(im)
    for x in (2, w - 5):
        d.rectangle([x, 0, x + 2, 49], fill=C("P05")); d.line([x, 0, x, 49], fill=C("P07"))
    for y0 in (2, 24):
        d.rectangle([0, y0 + 10, w - 1, y0 + 15], fill=C("P06")); d.line([0, y0 + 10, w - 1, y0 + 10], fill=C("P08"))
        d.rectangle([2, y0 + 8, w - 3, y0 + 10], fill=C("P34"))
        x = 4
        while x < w - 8:
            if crop == "lettuce":
                d.ellipse([x, y0 + 1, x + 7, y0 + 9], fill=C("P30"), outline=C("P28")); d.point((x + 2, y0 + 3), fill=C("P32"))
                x += 8
            elif crop == "bean":
                d.line([x + 2, y0, x + 2, y0 + 9], fill=C("P29"))
                d.ellipse([x, y0 + 1, x + 4, y0 + 5], fill=C("P31")); d.point((x + 3, y0 + 6), fill=C("P56"))
                x += 6
            elif crop == "mushroom":
                d.rectangle([x + 2, y0 + 5, x + 3, y0 + 9], fill=C("P08"))
                d.ellipse([x, y0 + 2, x + 6, y0 + 6], fill=C("P20"), outline=C("P18")); d.point((x + 2, y0 + 3), fill=C("P22"))
                x += 7
            else:
                for k in range(3):
                    d.line([x + k * 2, y0 + 9, x + k * 2 + 1, y0], fill=C("P31" if k % 2 else "P30"))
                d.point((x + 2, y0), fill=C("P22"))
                x += 6
        if mold:
            for _ in range(7):
                mx, my = rnd.randint(4, w - 8), y0 + rnd.randint(1, 9)
                d.ellipse([mx, my, mx + rnd.randint(2, 4), my + rnd.randint(2, 3)], fill=C("P01"))
                d.point((mx + 1, my), fill=C("P03"))
    d.rectangle([0, 46, w - 1, 49], fill=C("P04"))
    d.rectangle([w // 2 - 10, 40, w // 2 + 9, 45], fill=C("P09"))
    text(d, (w // 2, 39), {"lettuce": "상추", "bean": "콩", "mushroom": "버섯", "rice": "쌀"}[crop], F7, "P43", anchor="ma")
    return im


def tank(kind="nutrient"):
    """원통 탱크(2칸 × 2): nutrient 양액(초록) / water 정수(파랑). 눈금 창 + 배관."""
    liquid = {"nutrient": ("P35", "P36", "P34"), "water": ("P45", "P46", "P44")}[kind]
    w, h = 2 * T, 2 * T + 22
    im = img(w, h)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 0, w - 5, 18], fill=C("P07"), outline=C("P04"))
    d.ellipse([10, 3, w - 11, 14], fill=C("P06"))
    d.rectangle([4, 9, w - 5, h - 10], fill=C("P06"))
    d.ellipse([4, h - 20, w - 5, h - 1], fill=C("P05"))
    d.line([5, 9, 5, h - 10], fill=C("P08")); d.line([w - 6, 9, w - 6, h - 10], fill=C("P04"))
    d.rectangle([22, 22, 41, h - 18], fill=C(liquid[2]))
    d.rectangle([22, 36, 41, h - 18], fill=C(liquid[0])); d.line([22, 36, 41, 36], fill=C(liquid[1]))
    d.rectangle([22, 22, 41, h - 18], outline=C("P03"))
    for y in range(26, h - 20, 6):
        d.line([42, y, 45, y], fill=C("P03"))
    d.rectangle([w - 8, 30, w - 1, 36], fill=C("P04"))
    d.rectangle([8, 12, 20, 18], fill=C("P48")); text(d, (14, 11), "양액" if kind == "nutrient" else "정수", F7, "P02", anchor="ma")
    return im


def reactor():
    """볼트-텍 면허 표준 소형 원자로(4칸 × 4): 압력 용기 + 노란·검은 위험 띠 + 제어봉 구동부 + 진공관 계기."""
    w, h = 4 * T, 4 * T + 24
    im = img(w, h)
    d = ImageDraw.Draw(im)
    d.rectangle([4, h - 30, w - 5, h - 1], fill=C("P04"))                                    # 받침
    d.line([4, h - 30, w - 5, h - 30], fill=C("P06"))
    for x in range(4, w - 4, 8):
        d.polygon([(x, h - 1), (x + 4, h - 9), (x + 7, h - 9), (x + 3, h - 1)], fill=C("P48"))
    d.rectangle([20, 26, w - 21, h - 30], fill=C("P06"))                                     # 용기 몸통
    d.ellipse([20, h - 46, w - 21, h - 22], fill=C("P05"))
    d.line([21, 26, 21, h - 34], fill=C("P08")); d.line([w - 22, 26, w - 22, h - 34], fill=C("P04"))
    d.rectangle([20, 60, w - 21, 72], fill=C("P48")); d.line([20, 60, w - 21, 60], fill=C("P49"))
    for x in range(20, w - 21, 8):
        d.polygon([(x, 72), (x + 4, 60), (x + 7, 60), (x + 3, 72)], fill=C("P02"))
    d.ellipse([20, 10, w - 21, 42], fill=C("P07"), outline=C("P04"))                          # 뚜껑
    d.ellipse([34, 16, w - 35, 36], fill=C("P05"))
    for i, x in enumerate(range(40, w - 40, 8)):                                              # 제어봉 구동부
        top = 0 if i % 2 else 4
        d.rectangle([x, top, x + 4, 26], fill=C("P04")); d.line([x, top, x, 26], fill=C("P06"))
        d.rectangle([x - 1, top, x + 5, top + 3], fill=C("P53"))
    d.ellipse([w // 2 - 14, 84, w // 2 + 13, 111], fill=C("P48"), outline=C("P02"))           # 방사능 표지
    d.ellipse([w // 2 - 3, 94, w // 2 + 2, 99], fill=C("P02"))
    for a in (90, 210, 330):
        r = math.radians(a)
        d.pieslice([w // 2 - 12, 85, w // 2 + 11, 110], a - 30, a + 30, fill=C("P02"))
    d.ellipse([w // 2 - 4, 93, w // 2 + 3, 100], fill=C("P48")); d.ellipse([w // 2 - 2, 95, w // 2 + 1, 98], fill=C("P02"))
    for x in (26, w - 40):                                                                    # 계기창
        d.rectangle([x, 118, x + 13, 128], fill=C("P02"))
        d.ellipse([x + 2, 119, x + 6, 125], fill=C("P59")); d.ellipse([x + 8, 119, x + 12, 125], fill=C("P56"))
    text(d, (w // 2, 132), "S-07 원자로 1호기", F7, "P02", anchor="ma")
    return im


def air_purifier():
    """공기 정화기(3칸 × 2): 큰 팬 두 개 + 필터 창."""
    w, h = 3 * T, 2 * T + 22
    im = img(w, h)
    d = ImageDraw.Draw(im)
    block(d, 0, 0, w - 1, h - 1, 12, "P07", "P05", hi="P08", dark="P03")
    for cx in (24, 70):
        d.ellipse([cx - 18, 18, cx + 17, 53], fill=C("P02"), outline=C("P04"))
        for a in range(0, 360, 60):
            r = math.radians(a)
            d.pieslice([cx - 15, 21, cx + 14, 50], a, a + 30, fill=C("P06"))
        d.ellipse([cx - 4, 31, cx + 3, 39], fill=C("P07"))
    d.rectangle([6, 60, w - 7, 74], fill=C("P30")); d.line([6, 60, w - 7, 60], fill=C("P31"))
    for x in range(8, w - 8, 4):
        d.line([x, 61, x, 73], fill=C("P29"))
    d.rectangle([w - 18, 2, w - 6, 8], fill=C("P56"))
    return im


def battery_rack():
    """예비 축전지 랙(2칸 × 1, 벽에 붙는다)."""
    im = img(2 * T, 44)
    d = ImageDraw.Draw(im)
    block(d, 0, 0, 63, 43, 4, "P06", "P04", hi="P07", dark="P02")
    for r, y in enumerate((7, 24)):
        for x in range(4, 58, 13):
            d.rectangle([x, y, x + 10, y + 13], fill=C("P44")); d.line([x, y, x + 10, y], fill=C("P46"))
            d.rectangle([x + 2, y - 2, x + 3, y], fill=C("P53")); d.rectangle([x + 7, y - 2, x + 8, y], fill=C("P02"))
            d.rectangle([x + 2, y + 5, x + 8, y + 7], fill=C("P56" if (x + r) % 3 else "P59"))
    return im


def target(hidden=False, state=""):
    """사격장 표적(1칸): 받침대 + 둥근 과녁. hidden: 낮게 엎드린 은신 표적.
    state: down = 맞아 뒤로 넘어간 과녁(납작한 타원), duck = 들켜서 받침 뒤로 숨은 은신 표적(테두리만 보인다)."""
    im = img(T, 40 if not hidden else 22)
    d = ImageDraw.Draw(im)
    if state in ("down", "duck"):
        if not hidden:
            d.rectangle([14, 30, 17, 39], fill=C("P18"))
            d.rectangle([6, 36, 25, 39], fill=C("P17"))
            d.ellipse([5, 27, 26, 33], fill=C("P07"), outline=C("P02"))          # 뒤로 넘어간 과녁(뒷면 회색)
            d.line([8, 29, 23, 29], fill=C("P08"))
        else:
            d.rectangle([4, 16, 27, 21], fill=C("P17"))
            if state == "down":
                d.ellipse([5, 12, 26, 17], fill=C("P07"), outline=C("P02"))
            else:
                d.chord([6, 10, 25, 26], 180, 360, fill=C("P53"), outline=C("P02"))   # 받침 위로 테두리만
                d.line([9, 15, 22, 15], fill=C("P09"))
            d.rectangle([4, 16, 27, 21], fill=C("P17"))
            d.line([4, 16, 27, 16], fill=C("P18"))
        return im
    if not hidden:
        d.rectangle([14, 20, 17, 39], fill=C("P18"))
        d.rectangle([6, 36, 25, 39], fill=C("P17"))
        cy = 11
    else:
        d.rectangle([4, 16, 27, 21], fill=C("P17"))
        cy = 9
    for r, c in ((10, "P09"), (7, "P53"), (4, "P09"), (2, "P53")):
        d.ellipse([16 - r, cy - r + (0 if not hidden else 2), 15 + r, cy + r - 1], fill=C(c))
    d.ellipse([6, cy - 10, 25, cy + 9 if not hidden else cy + 7], outline=C("P02"))
    return im


def cell_bars(n=1):
    """구금실 쇠창살(n칸 × 1)."""
    w = n * T
    im = img(w, 60)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, 5], fill=C("P05")); d.line([0, 0, w - 1, 0], fill=C("P07"))
    d.rectangle([0, 52, w - 1, 59], fill=C("P05")); d.line([0, 52, w - 1, 52], fill=C("P07"))
    for x in range(3, w, 6):
        d.rectangle([x, 6, x + 2, 51], fill=C("P04")); d.line([x, 6, x, 51], fill=C("P07"))
    d.rectangle([0, 28, w - 1, 31], fill=C("P05"))
    return im


def mimeograph():
    """등사기(1칸): 크림색 받침 위 둥근 드럼."""
    im = img(T, T + 14)
    d = ImageDraw.Draw(im)
    block(d, 2, 12, 29, 44, 7, "P08", "P06", hi="P09", dark="P04")
    d.ellipse([5, 0, 26, 17], fill=C("P04"), outline=C("P02")); d.ellipse([8, 3, 23, 14], fill=C("P05"))
    d.line([9, 5, 21, 5], fill=C("P07"))
    d.rectangle([24, 6, 30, 8], fill=C("P03"))
    d.rectangle([7, 22, 24, 26], fill=C("P09"))
    return im


def bat_rack():
    """체육 창고 방망이 꽂이(1칸): 나무 방망이 여럿 — 하나는 '9회말'."""
    im = img(T, 48)
    d = ImageDraw.Draw(im)
    for i, x in enumerate((6, 11, 16, 21, 26)):
        col = ("P20", "P21", "P18", "P20", "P19")[i]
        d.line([x, 2, x + (i - 2), 36], fill=C(col), width=3)
        d.point((x, 2), fill=C("P22"))
    d.line([16, 4, 16, 34], fill=C("P53"))                                        # 9회말: 붉은 테이프
    block(d, 2, 30, 29, 47, 5, "P07", "P05", hi="P08", dark="P03")
    return im


def gym_mat(n=2):
    """체육 매트(장식, n칸 × 1)."""
    w = n * T
    im = img(w, T)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 4, w - 2, 27], fill=C("P45")); d.line([1, 4, w - 2, 4], fill=C("P46"))
    d.rectangle([1, 24, w - 2, 27], fill=C("P44"))
    for x in range(T, w - 1, T):
        d.line([x, 5, x, 23], fill=C("P44"))
    return im


def delivery_bed():
    """분만대(2칸 × 1): 진찰대 + 무영등 받침."""
    im = S.exam_bed()
    out = img(im.width, im.height + 10)
    out.alpha_composite(im, (0, 10))
    d = ImageDraw.Draw(out)
    d.rectangle([44, 0, 46, 14], fill=C("P05"))
    d.ellipse([34, 0, 56, 8], fill=C("P08"), outline=C("P04")); d.ellipse([40, 2, 50, 6], fill=C("P50"))
    return out


def curtain(n=2):
    """진료 칸막이 커튼(n칸 × 1, 막힘)."""
    w = n * T
    im = img(w, 50)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, 2], fill=C("P05"))
    for x in range(0, w, 8):
        d.rectangle([x, 3, x + 7, 47], fill=C("P15"))
        d.line([x, 3, x, 47], fill=C("P09")); d.line([x + 6, 3, x + 6, 47], fill=C("P14"))
    d.rectangle([0, 44, w - 1, 47], fill=C("P46"))
    return im


def morgue_drawers():
    """냉동 안치실 서랍장(2칸, 벽에 붙는다)."""
    im = img(2 * T, 56)
    d = ImageDraw.Draw(im)
    block(d, 0, 0, 63, 55, 5, "P14", "P13", hi="P15", dark="P11")
    for r in range(3):
        for c in range(2):
            x, y = 3 + c * 30, 8 + r * 15
            d.rectangle([x, y, x + 27, y + 12], fill=C("P14")); d.line([x, y, x + 27, y], fill=C("P15"))
            d.rectangle([x + 10, y + 5, x + 17, y + 7], fill=C("P05"))
            d.rectangle([x + 2, y + 2, x + 7, y + 5], fill=C("P09"))
    return im


def crate(kind="wood"):
    """상자(1칸): wood 나무 / metal 볼트 보급함."""
    im = img(T, T + 8)
    d = ImageDraw.Draw(im)
    if kind == "wood":
        block(d, 2, 4, 29, 37, 8, "P21", "P19", hi="P22", dark="P17")
        for y in (17, 25):
            d.line([3, y, 28, y], fill=C("P18"))
        d.line([3, 13, 28, 36], fill=C("P18"))
    else:
        block(d, 2, 4, 29, 37, 8, "P46", "P45", hi="P15", dark="P43")
        d.rectangle([2, 20, 29, 24], fill=C("P48")); d.line([2, 20, 29, 20], fill=C("P49"))
        text(d, (16, 26), "S-07", F7, "P09", anchor="ma")
    return im


def sink():
    """세면대(1칸, 벽에 붙는다)."""
    im = img(T, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([12, 0, 19, 4], fill=C("P07"))
    d.rectangle([14, 4, 16, 10], fill=C("P06"))
    block(d, 2, 10, 29, 26, 8, "P15", "P13", hi="P09", dark="P11")
    d.ellipse([7, 11, 24, 17], fill=C("P12"))
    d.rectangle([14, 27, 17, 39], fill=C("P06"))
    return im


def desk(kind="wood", n=2):
    """사무 책상(n칸 × 1): 서류 더미·전화."""
    w = n * T
    top, face, hi, dk = (("P20", "P18", "P21", "P16") if kind == "wood" else ("P07", "P05", "P08", "P03"))
    im = img(w, T + 12)
    d = ImageDraw.Draw(im)
    block(d, 1, 4, w - 2, 34, 12, top, face, hi=hi, dark=dk)
    d.rectangle([6, 0, 19, 10], fill=C("P09"), outline=C("P06")); d.line([7, 3, 18, 3], fill=C("P07"))
    d.rectangle([w - 18, 4, w - 7, 11], fill=C("P02")); d.rectangle([w - 16, 2, w - 9, 5], fill=C("P03"))   # 다이얼 전화
    d.rectangle([w // 2 - 8, 20, w // 2 + 7, 24], fill=C(dk))
    for x in (4, w - 7):
        d.rectangle([x, 35, x + 2, 43], fill=C("P04"))
    return im


# ================================================================ 의무실 탄생 장면 소품(견본 21_scene_birth에서 옮김)
def _sb():
    import scene_birth as SB
    return SB


def _jeongin_head(face="idle"):
    import chibi as K
    import json as _j
    npcs = _j.load(open(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                                     "game", "data", "npcs.json")))["npcs"]
    return K.head(K.Look.parse(npcs["C-001"]["look"]), "S", face)


def birth_bed(occupied=False):
    """분만 침대(세로, 머리가 북쪽). occupied: 윤정인이 강보에 싼 갓난아기(주인공)를 가슴에 안고 누운 그림."""
    return _sb().birth_bed(_jeongin_head() if occupied else None, inked=False)


# ================================================================ 돌잔치(MQ-P1 S2·S3, 2259 공동 식당) — SD-03a §7.1 '볼트식 돌상'
def dol_table():
    """볼트식 돌상(2칸 × 1, 낮은 상): 철제 상 + 볼트 청 상보 + 수경 농장 작물로 만든 떡·과일 접시(상추·콩·버섯) +
    앞줄에 돌잡이 물건 여섯(진공관·청진기·배급 카드·방송실 마이크·공기총 탄알·볼트 출입 카드)."""
    w = 2 * T
    im = img(w, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 6, w - 2, 27], fill=C("P45")); d.line([1, 6, w - 2, 6], fill=C("P46"))      # 상보(윗면)
    d.rectangle([1, 24, w - 2, 27], fill=C("P48")); d.line([1, 24, w - 2, 24], fill=C("P49"))     # 노란 띠
    d.rectangle([1, 28, w - 2, 32], fill=C("P44"))                                                 # 상보 앞 자락
    for x in (3, w - 6):
        d.rectangle([x, 33, x + 2, 38], fill=C("P04"))
    # 뒷줄 접시: 콩떡 · 상추 · 버섯
    for k, (cx, food) in enumerate(((11, "bean"), (32, "lettuce"), (53, "mush"))):
        d.ellipse([cx - 8, 6, cx + 7, 13], fill=C("P09"), outline=C("P06"))
        if food == "bean":
            for i in range(3):
                d.rectangle([cx - 6 + i * 4, 4 - (i % 2), cx - 3 + i * 4, 9 - (i % 2)], fill=C("P21"), outline=C("P19"))
                d.point((cx - 5 + i * 4, 6 - (i % 2)), fill=C("P31"))
        elif food == "lettuce":
            for i in range(3):
                d.ellipse([cx - 7 + i * 4, 2 + (i % 2), cx - 1 + i * 4, 9], fill=C("P30"), outline=C("P28"))
                d.point((cx - 5 + i * 4, 4), fill=C("P32"))
        else:
            for i in range(3):
                d.rectangle([cx - 5 + i * 4, 6, cx - 4 + i * 4, 9], fill=C("P08"))
                d.ellipse([cx - 7 + i * 4, 3, cx - 2 + i * 4, 7], fill=C("P20"), outline=C("P18"))
    # 앞줄: 돌잡이 물건 여섯
    y = 15
    d.ellipse([3, y, 8, y + 7], fill=C("P59"), outline=C("P58")); d.point((5, y + 2), fill=C("P60"))      # 진공관
    d.rectangle([4, y + 7, 7, y + 8], fill=C("P05"))
    d.arc([12, y, 21, y + 8], 0, 300, fill=C("P04")); d.ellipse([18, y + 5, 21, y + 8], fill=C("P07"), outline=C("P03"))  # 청진기
    d.rectangle([24, y + 1, 32, y + 6], fill=C("P08"), outline=C("P06")); d.line([25, y + 3, 30, y + 3], fill=C("P53"))  # 배급 카드
    d.rectangle([36, y, 39, y + 4], fill=C("P02")); d.rectangle([37, y + 4, 38, y + 8], fill=C("P04"))    # 방송실 마이크
    d.point((37, y + 1), fill=C("P05"))
    for px, py in ((44, y + 5), (46, y + 3), (47, y + 6)):                                              # 공기총 탄알
        d.rectangle([px, py, px + 1, py + 1], fill=C("P06")); d.point((px, py), fill=C("P08"))
    d.rectangle([52, y + 1, 60, y + 6], fill=C("P46"), outline=C("P43")); d.rectangle([53, y + 2, 55, y + 4], fill=C("P48"))  # 출입 카드
    return im


def dol_banner(label="축 첫돌"):
    """'축 첫돌' 현수막(벽 3칸): 흰 천 + 붉은 글씨 + 양 끝 끈. label을 바꿔 생일 현수막(MQ-P2)에도 쓴다."""
    w = 3 * T
    im = img(w, 22)
    d = ImageDraw.Draw(im)
    d.line([0, 2, 6, 6], fill=C("P05")); d.line([w - 1, 2, w - 7, 6], fill=C("P05"))
    d.rectangle([6, 4, w - 7, 19], fill=C("P09")); d.line([6, 4, w - 7, 4], fill=C("P08"))
    d.line([6, 19, w - 7, 19], fill=C("P07"))
    for x in range(8, w - 8, 9):
        d.point((x, 5), fill=C("P53"))
    text(d, (w // 2, 6), label, F9, "P53", anchor="ma")
    return im


def sandbag():
    """보안부 사격장 모래주머니(1칸, 낮은 엄폐): 마대 세 단을 엇갈려 쌓았다. 묶은 끈·접힌 자락."""
    im = img(T, 30)
    d = ImageDraw.Draw(im)
    rows = ((2, 20, (1, 16), (16, 31)), (2, 12, (4, 18), (17, 29)), (1, 4, (7, 25),))
    for row in rows:
        h, y = 9, row[1]
        for x0, x1 in row[2:]:
            d.rounded_rectangle([x0, y, x1 - 1, y + h], radius=3, fill=C("P19"), outline=C("P17"))
            d.line([x0 + 2, y + 1, x1 - 3, y + 1], fill=C("P20"))
            d.line([x0 + 2, y + h - 1, x1 - 3, y + h - 1], fill=C("P18"))
            d.point(((x0 + x1) // 2, y + 4), fill=C("P17")); d.point(((x0 + x1) // 2, y + 5), fill=C("P17"))
    d.line([3, 29, 29, 29], fill=C("P02"))
    return im


# ================================================================ 등록부
# (함수, 발 가로, 발 세로, 종류, down, 벽 소품 dx, dy)
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS = {
    # 문
    "door_slide": _r(lambda: door(None), 1, 2, "door"),
    "door_hatch": _r(lambda: door(None, kind="hatch"), 1, 2, "door"),
    "door_iron": _r(lambda: door(None, kind="iron"), 1, 2, "door"),
    "gear_door": _r(lambda: gear_door(0), 6, 0, "wall", dx=-16, dy=-128),          # 문틀(8칸) 구멍 가운데에 맞춘다(0-9)
    "gear_frame": _r(lambda: S.gear_door_frame(), 7, 0, "wall", dx=-16, dy=-136),
    # 벽 소품(벽면 윗칸 기준 위치)
    "rank_board": _r(S.rank_board, 6, 0, "wall", dy=4),
    "slogan_crt": _r(lambda: S.slogan_crt("성적이 곧 미래다", 3), 3, 0, "wall", dy=6),
    "slogan_crt2": _r(lambda: S.slogan_crt("기록이 곧 나다", 2), 2, 0, "wall", dy=6),
    "slogan_crt3": _r(lambda: S.slogan_crt("배급은 공정하다", 3), 3, 0, "wall", dy=6),
    "wall_clock": _r(wall_clock, 1, 0, "wall", dx=8, dy=8),
    "blackboard": _r(S.blackboard, 4, 0, "wall", dy=6),
    "ration_window": _r(lambda: service_window("배급과"), 2, 0, "wall", dy=0),
    "reg_window": _r(lambda: service_window("행정과"), 2, 0, "wall", dy=0),
    "booth_window": _r(booth_window, 2, 0, "wall", dy=8),
    "emblem": _r(S.emblem, 1, 0, "wall", dy=6),
    "wall_terminal": _r(wall_terminal, 1, 0, "wall", dy=10),
    "notice_board": _r(notice_board, 2, 0, "wall", dy=8),
    "memorial_plaque": _r(memorial_plaque, 3, 0, "wall", dy=12),
    "quarantine_sign": _r(quarantine_sign, 1, 0, "wall", dy=10),
    "wall_pipes": _r(wall_pipes, 3, 0, "wall", dy=8),
    "duct_grille": _r(duct_grille, 1, 0, "wall", dy=12),
    "drain_hatch": _r(lambda: drain_hatch(0), 3, 0, "wall", dy=0),                 # 비상 배수 갱도 원형 철문(0-9, 컷 HATCH_FRAMES)
    "lever_panel": _r(lever_panel, 2, 0, "wall", dy=10),
    # 바닥 소품
    "canteen_table": _r(lambda: S.canteen_table(4), 4, 1, down=4),
    "canteen_table2": _r(lambda: S.canteen_table(2), 2, 1, down=4),
    "stool": _r(S.stool, 0, 0, "deco"),
    "exam_desk": _r(S.exam_desk, 1, 1, down=10),
    "teacher_desk": _r(S.teacher_desk, 2, 1, down=4),
    "bunk": _r(S.bunk, 1, 2, down=4),
    "locker_row2": _r(lambda: S.locker_row(2), 2, 1, down=0),
    "locker_row3": _r(lambda: S.locker_row(3), 3, 1, down=0),
    "exam_bed": _r(S.exam_bed, 2, 1, down=4),
    "delivery_bed": _r(delivery_bed, 2, 1, down=4),
    "med_cabinet": _r(S.med_cabinet, 1, 1, down=0),
    "overseer_desk": _r(S.overseer_desk, 3, 1, down=8),
    "safe": _r(S.safe, 1, 1, down=4),
    "planter": _r(S.planter, 2, 1, down=0),
    "water_cooler": _r(S.water_cooler, 1, 1, down=0),
    "terminal_desk": _r(terminal_desk, 1, 1, down=10),
    "file_cabinet": _r(file_cabinet, 1, 1, down=0),
    "bookshelf": _r(bookshelf, 2, 1, down=0),
    "counter": _r(lambda: counter(3, "등록 창구"), 3, 1, down=12),
    "counter_ration": _r(lambda: counter(3, "배급 창구"), 3, 1, down=12),
    "counter_clinic": _r(lambda: counter(3, "접수"), 3, 1, down=12),
    "meeting_table": _r(meeting_table, 3, 2, down=6),
    "chair_n": _r(lambda: chair("N"), 0, 0, "deco"),
    "chair_s": _r(lambda: chair("S"), 0, 0, "deco"),
    "bench": _r(bench, 2, 1, down=0),
    "pillar": _r(pillar, 1, 1, down=0),
    "tube_rack": _r(tube_rack, 2, 1, down=0),
    "tape_cabinet": _r(tape_cabinet, 1, 1, down=0),
    "judge_machine": _r(judge_machine, 3, 2, down=0),
    "record_locker": _r(record_locker, 2, 1, down=0),
    "shelf_lettuce": _r(lambda: grow_shelf("lettuce"), 3, 1, down=0),
    "shelf_bean": _r(lambda: grow_shelf("bean", seed=2), 3, 1, down=0),
    "shelf_mushroom": _r(lambda: grow_shelf("mushroom", seed=3), 3, 1, down=0),
    "shelf_rice": _r(lambda: grow_shelf("rice", seed=4), 3, 1, down=0),
    "shelf_mold": _r(lambda: grow_shelf("bean", mold=True, seed=5), 3, 1, down=0),
    "shelf_mold2": _r(lambda: grow_shelf("lettuce", mold=True, seed=6), 3, 1, down=0),
    "tank_nutrient": _r(lambda: tank("nutrient"), 2, 2, down=0),
    "tank_water": _r(lambda: tank("water"), 2, 2, down=0),
    "reactor": _r(reactor, 4, 4, down=0),
    "air_purifier": _r(air_purifier, 3, 2, down=0),
    "battery_rack": _r(battery_rack, 2, 1, down=0),
    "gun_rack": _r(gun_rack, 2, 1, down=0),
    "target": _r(target, 1, 1, down=0),
    "target_low": _r(lambda: target(True), 1, 1, down=0),
    "cell_bars": _r(cell_bars, 1, 1, down=0),
    "mimeograph": _r(mimeograph, 1, 1, down=10),
    "bat_rack": _r(bat_rack, 1, 1, down=0),
    "gym_mat": _r(gym_mat, 0, 0, "deco"),
    "curtain": _r(curtain, 2, 1, down=0),
    "morgue_drawers": _r(morgue_drawers, 2, 1, down=0),
    "crate": _r(crate, 1, 1, down=4),
    "crate_metal": _r(lambda: crate("metal"), 1, 1, down=4),
    "sink": _r(sink, 1, 1, down=0),
    "desk": _r(desk, 2, 1, down=8),
    "desk_metal": _r(lambda: desk("metal"), 2, 1, down=8),
    # 의무실(MQ-P1 S1): 견본 소품
    "birth_bed": _r(lambda: birth_bed(False), 1, 2, down=6),
    "iv_stand": _r(lambda: _sb().iv_stand(), 0, 0, "deco"),
    "bassinet": _r(lambda: _sb().bassinet(), 1, 1, down=-2),
    "terminal_cart": _r(lambda: _sb().terminal_cart(False, 0), 1, 1, down=2),
    "screen_partition": _r(lambda: _sb().screen_partition(), 1, 1, down=0),
    "clinic_desk": _r(lambda: _sb().clinic_desk(), 2, 1, down=4),
    "bobblehead": _r(lambda: _sb().bobblehead(), 1, 0, "wall", dx=11, dy=27),
    # 돌잔치
    "dol_table": _r(dol_table, 2, 1, down=6),
    "dol_banner": _r(dol_banner, 3, 0, "wall", dy=4),
    "bday_banner": _r(lambda: dol_banner("생일 축하"), 3, 0, "wall", dy=4),
    "sandbag": _r(sandbag, 1, 1, down=2),
}
# 상태 그림(연출이 바꾼다: InteriorMap.set_prop_state). 이름 → {상태: 그리기 함수}
PROP_STATES = {
    "birth_bed": {"occupied": lambda: birth_bed(True)},
    "terminal_cart": {"lit": lambda: _sb().terminal_cart(True, 0)},
    "target": {"down": lambda: target(False, "down")},
    "target_low": {"down": lambda: target(True, "down"), "duck": lambda: target(True, "duck")},
}
# 문 열린 그림(문 소품의 둘째 칸)
DOOR_OPEN = {"door_slide": lambda: door(None, "open"), "door_hatch": lambda: door(None, "open", "hatch"),
             "door_iron": lambda: door(None, "open", "iron")}
PROP_FRAMES = {"drain_hatch": (drain_hatch, HATCH_FRAMES)}   # 컷이 여럿인 소품(연출 명령 anim) — 방폭문은 GEAR_FRAMES로 따로
GEAR_FRAMES = 22                                     # 굴러 열리는 컷: 컷마다 10px(210/21) — 회전각 = 거리/반지름이라 미끄러지지 않는다


def sheet_sample(path):
    """견본: 모든 소품을 먹선 두르고 한 장에(art/samples/10_props_s07.png)."""
    import tiles_isaac as TI
    from grid import upscale
    ims = []
    for n, r in PROPS.items():
        if n in ("gear_door", "gear_frame"):
            continue
        im = r["fn"]()
        pad = img(im.width + 2, im.height + 2)
        pad.alpha_composite(im, (1, 1))
        ims.append(TI.outline(pad))
    W = 640
    x, y, rowh = 6, 6, 0
    placed = []
    for im in ims:
        if x + im.width > W - 6:
            x, y, rowh = 6, y + rowh + 6, 0
        placed.append((im, x, y))
        x += im.width + 6
        rowh = max(rowh, im.height)
    out = Image.new("RGBA", (W, y + rowh + 6), C("P19"))
    for im, x, y in placed:
        out.alpha_composite(im, (x, y))
    out.save(path)
    upscale(out, 2).save(path.replace(".png", "_x2.png"))
    return out


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sheet_sample(os.path.join(root, "samples", "10_props_s07.png"))
    print("props:", len(PROPS))
