"""던전 소품(단계 1-D, 1-D 계획 §1·§2 · SD-09a L-R02-17 · SD-09f §3.5 침수 단계).
대방 지하차도: 월드 입구(침수 경사로) · 반쯤 잠긴 2077 원자력 통근 버스(노심 상태 셋) · 물에 잠긴 승용차 · '침수 시 진입 금지' 경고판 ·
변이 가재 진흙 굴 · 대방 분대 손 윈치 · 터널 등(비상등 상태).
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01). 위에서 빛(위 밝게 · 아래 어둡게), 반투명 없음.
물빛은 침수 바닥 타일(ground.flood_tex)과 같은 P10~P12 + 밝은 잔물결 P14·P15."""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text
from props_trap import trefoil

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _ripples(d, rnd, box, n, deep=True):
    """수면: 짙은 물 위 가로 잔물결(밝은 윗줄 + 짙은 아랫점) — 바닥 타일과 같은 결."""
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y = rnd.randint(x0, x1 - 4), rnd.randint(y0, y1 - 1)
        d.line([x, y, x + rnd.choice((2, 3, 4)), y], fill=C("P14" if deep else "P15"))
        d.point((x + 1, y + 1), fill=C("P10"))


def _waterline(im, y, x0, x1, rnd):
    """물에 잠긴 물체의 흘수선: y 아래는 물빛으로 덮고 경계에 밝은 띠."""
    d = ImageDraw.Draw(im)
    px = im.load()
    for yy in range(y, im.height):                                       # 물 아래 몸통 = 탁한 물에 비친 짙은 그림자(바닥 타일 위에 겹친다)
        for xx in range(x0, x1):
            if px[xx, yy][3]:
                px[xx, yy] = C("P10" if rnd.random() < 0.18 or yy > y + 10 else "P11")
    for xx in range(x0, x1):
        if px[xx, y][3]:
            px[xx, y] = C("P14" if rnd.random() < 0.6 else "P13")
            if rnd.random() < 0.25 and y + 2 < im.height and px[xx, y + 2][3]:
                px[xx, y + 2] = C("P13")


def underpass_mouth():
    """지하차도 입구(월드 문, 2×1 발 = 출구 칸 둘): 뒤(북쪽)에 콘크리트 문틀 + 높이 제한 띠(노랑·검정) + '대방 지하차도' 판,
    앞은 아래로 기우는 아스팔트 경사로가 끝에서 검은 물에 잠긴다(멀수록 어둡다). 양옆 옹벽 · 차선 흔적."""
    rnd = random.Random(1701)
    im = img(64, 48)
    d = ImageDraw.Draw(im)
    for i in range(9):                                                   # 경사로(아래 = 지면, 위로 갈수록 깊고 어둡다)
        y = 47 - i * 3
        col = ["P05", "P05", "P04", "P04", "P03", "P03", "P02", "P02", "P01"][i]
        d.rectangle([6, y - 2, 57, y], fill=C(col))
    for y in range(24, 48, 4):                                           # 가운데 노란 차선(벗겨짐)
        if rnd.random() < 0.7:
            d.line([31, y, 31, y + 1], fill=C("P48" if y > 34 else "P47"))
    d.rectangle([6, 18, 57, 24], fill=C("P11"))                          # 끝에서 물이 차오른다
    d.line([6, 24, 57, 24], fill=C("P13"))
    _ripples(d, rnd, (8, 19, 55, 23), 6, deep=False)
    d.rectangle([0, 6, 63, 17], fill=C("P05")); d.line([0, 6, 63, 6], fill=C("P07")); d.line([0, 17, 63, 17], fill=C(INK))   # 문틀 윗보
    for i, x in enumerate(range(2, 62, 6)):                              # 높이 제한 띠
        d.polygon([(x, 13), (x + 3, 13), (x + 6, 16), (x + 3, 16)], fill=C("P49" if i % 2 == 0 else "P01"))
    d.rectangle([12, 0, 51, 10], fill=C("P44")); d.line([12, 0, 51, 0], fill=C("P46")); d.line([12, 10, 51, 10], fill=C(INK))
    put_text(im, "대방지하차도", 14, 1, "P09", size=8)
    for x in (0, 58):                                                    # 옹벽
        d.rectangle([x, 16, x + 5, 47], fill=C("P06")); d.line([x, 16, x, 47], fill=C("P08")); d.line([x + 5, 16, x + 5, 47], fill=C(INK))
        for y in range(20, 46, 7):
            d.line([x + 1, y, x + 4, y], fill=C("P05"))
    return im


def bus_atomic_sunk(state=""):
    """반쯤 잠긴 2077 원자력 통근 버스(4×2 발, 132×70): 몸통 위 절반만 물 위 · 뒤쪽 지붕 위 둥근 노심 덮개(갈라진 틈으로 초록빛) ·
    '원자력 통근 — 대방↔여의도' 띠 · 비상문이 열려 있다.
    상태 cold = 노심을 꺼내 갔다(덮개가 열리고 빈 받침, 빛 없음) · torn = 분대가 쇠사슬로 덮개를 뜯어 갔다(찢긴 덮개 · 사슬 끝)."""
    rnd = random.Random(1717)
    W_, H_ = 132, 70
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([4, 16, 127, 64], 14, fill=C("P13"))             # 몸통(청회색 · 통근 노선)
    d.rounded_rectangle([4, 16, 127, 32], 14, fill=C("P14"))
    d.rectangle([6, 36, 125, 41], fill=C("P53")); d.line([8, 36, 123, 36], fill=C("P54"))    # 붉은 띠
    put_text(im, "원자력 통근", 22, 34, "P09", 8, "Galmuri7")
    for i, x in enumerate(range(16, 104, 13)):                           # 창 줄(물때 · 깨진 칸)
        col = "P10" if i % 3 else "P02"
        d.rounded_rectangle([x, 20, x + 9, 30], 2, fill=C(col))
        if col == "P10":
            d.line([x + 2, 22, x + 5, 22], fill=C("P12"))
    d.rounded_rectangle([4, 18, 14, 50], 6, fill=C("P12"))               # 앞(왼쪽) 끝 · 노선판
    d.rectangle([5, 21, 12, 28], fill=C("P01")); put_text(im, "6", 7, 20, "P60", 8, "Galmuri7")
    d.rectangle([70, 31, 80, 44], fill=C("P02")); d.line([70, 31, 70, 44], fill=C("P12"))   # 열린 비상문
    # 뒤쪽 지붕 노심 덮개
    if state == "torn":
        d.polygon([(100, 14), (112, 4), (124, 10), (118, 18)], fill=C("P12")); d.line([100, 14, 112, 4], fill=C("P14"))
        d.polygon([(110, 16), (114, 13), (122, 16), (116, 20)], fill=C("P02"))
        d.line([118, 10, 131, 2], fill=C("P06")); d.line([119, 11, 131, 4], fill=C("P04"))  # 사슬 끝(밖으로 끌려 나갔다)
    elif state == "cold":
        d.ellipse([100, 6, 126, 22], fill=C("P05")); d.ellipse([103, 9, 123, 19], fill=C("P02"))
        d.rectangle([108, 11, 118, 16], fill=C("P04"))                   # 빈 받침
        d.line([96, 4, 104, 8], fill=C("P06"))                           # 젖혀 둔 뚜껑 경첩
    else:
        d.ellipse([100, 6, 126, 22], fill=C("P06")); d.ellipse([102, 7, 124, 14], fill=C("P07"))
        for x0, y0, x1, y1 in ((106, 12, 112, 15), (114, 10, 118, 16), (120, 13, 123, 17)):   # 갈라진 틈 사이 초록빛
            d.line([x0, y0, x1, y1], fill=C("P56"))
            d.point((x0, y0), fill=C("P57"))
        trefoil(d, 113, 18, 2, "P02", "P49")
        if state == "haul":                                              # 당기는 통에 덮개가 비틀려 들렸다 — 아래 틈으로 빛이 세게 샌다
            d.polygon([(99, 10), (113, 1), (127, 6), (126, 12)], fill=C("P06")); d.line([99, 10, 113, 1], fill=C("P08"))
            d.line([101, 12, 125, 12], fill=C("P57")); d.line([102, 13, 124, 13], fill=C("P56"))
    for _ in range(70):                                                  # 녹 · 물때
        x, y = rnd.randint(6, 126), rnd.randint(18, 50)
        if im.getpixel((x, y))[3] and im.getpixel((x, y))[:3] in (P.rgb("P13"), P.rgb("P14")):
            im.putpixel((x, y), C(rnd.choice(["P24", "P25", "P12"])))
    _waterline(im, 50 if state == "haul" else 46, 0, W_, rnd)           # 끌려 나오는 중: 경사로 쪽으로 들려 물 밖으로 더 나왔다
    if state == "haul":                                                  # 앞 범퍼에서 서쪽(경사로 · 윈치)으로 팽팽한 사슬
        for i in range(4):
            x = 1 + i * 4
            d.ellipse([x, 40, x + 4, 44], outline=C("P07" if i % 2 else "P05"))
        for x, y in ((14, 53), (20, 55), (9, 56)):                       # 끌린 자리 물살
            d.line([x, y, x + 5, y], fill=C("P15"))
    if state in ("", "haul"):
        for x, y in ((98, 50), (110, 53), (121, 49), (104, 56)):         # 노심 쪽 물이 희미하게 빛난다
            d.line([x, y, x + 3, y], fill=C("P55"))
    return im


def car_sunk(seed=0):
    """물에 잠긴 2077 원자력 승용차(3×1 발, 96×40): 지붕과 유리만 물 위 · 꼬리 날개 끝 · 둘레 잔물결."""
    rnd = random.Random(1730 + seed)
    W_, H_ = 96, 40
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    body = ["P11", "P12", "P13", "P14"] if seed % 2 == 0 else ["P23", "P24", "P25", "P26"]
    d.rounded_rectangle([8, 16, 88, 34], 10, fill=C(body[2]))
    d.rounded_rectangle([22, 4, 72, 26], 10, fill=C(body[1]))
    d.rounded_rectangle([26, 7, 68, 22], 8, fill=C("P10"))
    d.line([47, 7, 47, 22], fill=C(body[1]))
    d.polygon([(52, 8), (60, 8), (55, 14)], fill=C("P02"))
    d.polygon([(80, 18), (92, 8), (91, 24)], fill=C(body[2]))           # 꼬리 날개
    if seed % 3 == 1:
        d.rectangle([30, 10, 40, 16], fill=C("P19"))                     # 유리 안 짐 보따리
    _waterline(im, 26, 0, W_, rnd)
    return im


def w_flood_warn():
    """벽 경고판(벽 소품 2칸): 흰 바탕 붉은 테 '침수 시 진입 금지' + 수위 눈금 막대(물때 줄이 눈금 위 1.2m에 남았다)."""
    im = img(58, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 2, 41, 27], fill=C("P53")); d.rectangle([2, 4, 39, 25], fill=C("P09"))
    put_text(im, "침수시", 6, 5, "P53", 8, "Galmuri7")
    put_text(im, "진입금지", 4, 15, "P02", 8, "Galmuri7")
    d.rectangle([46, 0, 53, 29], fill=C("P08"))                          # 수위 막대
    for i, y in enumerate(range(2, 29, 4)):
        d.line([46, y, 49 if i % 2 else 52, y], fill=C("P53" if y < 12 else "P02"))
    d.line([44, 11, 55, 11], fill=C("P19")); d.line([44, 12, 55, 12], fill=C("P18"))   # 물때 줄
    return im


def mud_burrow():
    """변이 가재 진흙 굴(바닥 장식, 밟고 지나감, 36×20): 젖은 진흙 둔덕 · 검은 구멍 · 집게 껍데기 조각."""
    rnd = random.Random(1741)
    im = img(36, 20)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 4, 35, 19], fill=C("P16"))
    d.ellipse([4, 3, 32, 15], fill=C("P17"))
    d.ellipse([6, 2, 28, 10], fill=C("P18"))
    d.ellipse([12, 5, 22, 11], fill=C("P01"))
    d.ellipse([14, 6, 20, 9], fill=C("P00"))
    for x, y in ((5, 15), (27, 14), (30, 9)):
        d.polygon([(x, y), (x + 3, y - 1), (x + 4, y + 1)], fill=C("P26"))
        d.point((x + 1, y), fill=C("P27"))
    for _ in range(14):
        x, y = rnd.randint(3, 33), rnd.randint(5, 18)
        if im.getpixel((x, y))[3]:
            im.putpixel((x, y), C(rnd.choice(["P16", "P19", "P29"])))
    return im


def squad_winch():
    """대방 분대 손 윈치(2×1 발, 64×44): 콘크리트 블록에 박은 드럼 · 손잡이 · 물속으로 늘어진 쇠사슬 · 스프레이 '대방'."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 34, 62, 43], fill=C("P02"))
    d.rectangle([4, 22, 40, 39], fill=C("P06")); d.line([4, 22, 40, 22], fill=C("P08")); d.line([4, 39, 40, 39], fill=C(INK))
    put_text(im, "대방", 8, 27, "P53", 8, "Galmuri7")
    d.rectangle([10, 8, 34, 22], fill=C("P11")); d.line([10, 8, 34, 8], fill=C("P13"))   # 드럼 받침
    d.ellipse([14, 6, 30, 20], fill=C("P12")); d.ellipse([18, 9, 26, 17], fill=C("P05"))
    for y in range(10, 18, 2):
        d.line([16, y, 28, y], fill=C("P04"))                            # 감긴 사슬
    d.line([30, 13, 36, 6], fill=C("P05")); d.rectangle([35, 3, 39, 7], fill=C("P53"))   # 손잡이
    for i in range(8):                                                   # 물로 늘어진 사슬
        x, y = 34 + i * 3, 16 + i * 3
        d.ellipse([x, y, x + 3, y + 2], outline=C("P06" if i % 2 else "P04"))
    return im


def w_tunnel_lamp(lit=False):
    """지하차도 벽 등(벽 소품 1칸): 철망 덮개 · 깨진 형광등. lit = 비상등(SD-09f §3.5 비상등 30%)이 붉게 남아 있다."""
    im = img(30, 16)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 27, 12], fill=C("P04")); d.line([2, 4, 27, 4], fill=C("P06"))
    d.rectangle([4, 6, 25, 10], fill=C("P53" if lit else "P02"))
    if lit:
        d.line([5, 7, 24, 7], fill=C("P54"))
    else:
        d.line([5, 8, 12, 8], fill=C("P07"))
    for x in range(5, 26, 4):
        d.line([x, 5, x, 11], fill=C("P05"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_DG = {
    "underpass_mouth": _r(underpass_mouth, 2, 1, down=2),
    "bus_atomic_sunk": _r(bus_atomic_sunk, 4, 2, down=-2),
    "car_sunk": _r(lambda: car_sunk(0), 3, 1, down=-2),
    "car_sunk2": _r(lambda: car_sunk(1), 3, 1, down=-2),
    "w_flood_warn": _r(w_flood_warn, 2, 0, "wall", dx=3, dy=6),
    "mud_burrow": _r(mud_burrow, 0, 0, "deco"),
    "squad_winch": _r(squad_winch, 2, 1, down=-2),
    "w_tunnel_lamp": _r(w_tunnel_lamp, 1, 0, "wall", dx=1, dy=10),
}
STATES_DG = {"bus_atomic_sunk": {"cold": lambda: bus_atomic_sunk("cold"), "torn": lambda: bus_atomic_sunk("torn"), "haul": lambda: bus_atomic_sunk("haul")},
             "w_tunnel_lamp": {"lit": lambda: w_tunnel_lamp(True)}}
