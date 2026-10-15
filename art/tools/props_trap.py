"""함정 · 환경 폭발 소품(단계 1-9c, SD-11 §9.2 함정 표 · §9.3 환경 폭발 · SD-16 §7 아이작풍).
눈에 보이는 함정만 소품으로 세운다(숨긴 덫 · 압력판 · 인계철선 · 지향성 지뢰는 전투 이펙트 시트에서 발견했을 때 그린다).
- 부비트랩 자판기(trap_vending): 2077년 음료 자판기 + 옆구리에 테이프로 감은 전선 · 깜박이는 붉은 등. 상태 boom = 터져 속이 빈 틀.
- 폭탄 택배함(trap_parcel): 무인 택배 보관함 한 칸 + '취급주의' 상자 · 삐져나온 전선. 상태 boom = 그을린 칸.
- 가스 누출 배관(gas_pipe): 땅에서 솟은 도시가스 배관 · 노란 밸브 · 갈라진 이음. 상태 boom = 찢어진 배관.
- 방사능(1-9d): 웅덩이(rad_puddle · 2 — 밟고 지나가는 장식) · 폐기물 드럼(waste_drum, 그을린 상태) · 차폐 용기(rad_cask 함정, 상태 open · off) · 방사능 표지판(rad_sign).
- 불탄 차량 · 드럼 · 가스통: 기존 그림을 그을린 색으로(상태 burnt) — 원자력 차량이 터진 자리.
props_bc.PROPS / STATES에 합쳐져 r01_props 아틀라스로 나간다."""
import os, random, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

C = lambda t: P.rgb(t) + (255,)


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def vending(state=""):
    """음료 자판기(1×1, 32×56): 붉은 몸통 · 유리 진열창(병 줄) · 동전 투입구 · 배출구. 옆구리에 감은 회색 테이프와 전선, 꼭대기 붉은 등."""
    im = img(32, 56)
    d = ImageDraw.Draw(im)
    if state == "boom":
        d.rectangle([3, 8, 28, 54], fill=C("P02")); d.rectangle([5, 10, 26, 52], fill=C("P01"))
        d.polygon([(3, 8), (9, 2), (14, 9), (20, 3), (28, 8)], fill=C("P03"))                       # 찢긴 윗판
        for x, y in ((7, 20), (21, 30), (12, 44), (24, 47)):
            d.point((x, y), fill=C("P25"))
        d.rectangle([3, 50, 28, 54], fill=C("P24"))
        return im
    d.rectangle([3, 6, 28, 54], fill=C("P53")); d.line([3, 6, 28, 6], fill=C("P54")); d.line([3, 6, 3, 54], fill=C("P54"))
    d.rectangle([6, 9, 22, 34], fill=C("P11")); d.rectangle([7, 10, 21, 33], fill=C("P13"))         # 진열창
    for row, y in enumerate((12, 19, 26)):
        for k in range(4):
            col = ("P56", "P49", "P46", "P27")[(k + row) % 4]
            d.rectangle([8 + k * 3, y, 9 + k * 3, y + 4], fill=C(col))
    d.line([7, 10, 12, 10], fill=C("P15"))
    d.rectangle([24, 14, 26, 22], fill=C("P02")); d.point((25, 16), fill=C("P49"))                 # 동전 투입구
    d.rectangle([7, 40, 22, 46], fill=C("P01")); d.line([7, 40, 22, 40], fill=C("P52"))            # 배출구
    d.rectangle([2, 28, 29, 31], fill=C("P05")); d.line([2, 28, 29, 28], fill=C("P06"))            # 감은 테이프
    d.line([28, 30, 31, 38], fill=C("P54")); d.line([29, 31, 31, 44], fill=C("P46"))               # 전선
    d.rectangle([13, 2, 17, 6], fill=C("P02")); d.rectangle([14, 3, 16, 5], fill=C("P54" if state != "off" else "P52"))   # 경보등
    d.rectangle([3, 52, 28, 54], fill=C("P52"))
    return im


def parcel(state=""):
    """무인 택배 보관함 한 칸(1×1, 32×44): 회색 철제 함 · 열린 칸 안의 '취급주의' 상자 · 테이프 · 삐져나온 전선."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 29, 42], fill=C("P12")); d.line([2, 4, 29, 4], fill=C("P14"))
    for y in (14, 24, 34):
        d.line([2, y, 29, y], fill=C("P11"))
    d.line([15, 4, 15, 42], fill=C("P11"))
    for x, y in ((5, 7), (18, 7), (5, 17), (18, 27), (5, 37)):                                     # 칸 손잡이 · 번호
        d.rectangle([x, y, x + 2, y + 1], fill=C("P15"))
    if state == "boom":
        d.rectangle([3, 25, 28, 41], fill=C("P01"))
        d.polygon([(3, 25), (10, 21), (16, 26), (24, 20), (28, 25)], fill=C("P02"))
        d.point((8, 33), fill=C("P25")); d.point((20, 36), fill=C("P25"))
        return im
    d.rectangle([3, 25, 28, 41], fill=C("P01"))                                                     # 열린 아래 칸
    d.rectangle([6, 28, 25, 40], fill=C("P20")); d.line([6, 28, 25, 28], fill=C("P21"))           # 상자
    d.rectangle([13, 28, 18, 40], fill=C("P06"))                                                    # 테이프
    d.rectangle([7, 33, 12, 36], fill=C("P53")); d.point((9, 34), fill=C("P09"))                   # 취급주의 딱지
    d.line([22, 31, 28, 24], fill=C("P54")); d.line([23, 33, 29, 27], fill=C("P46"))              # 전선
    return im


def gas_pipe(state=""):
    """땅에서 솟은 도시가스 배관(1×1, 32×40): 노란 관 · 밸브 핸들 · 갈라진 이음 둘레 녹. 가스 흐름은 전투 이펙트(지대)로 그린다."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    d.ellipse([6, 33, 26, 39], fill=C("P18"))                                                       # 파낸 흙
    if state == "boom":
        d.rectangle([12, 22, 19, 36], fill=C("P47")); d.polygon([(12, 22), (14, 15), (16, 21), (19, 14), (19, 22)], fill=C("P47"))
        d.line([12, 22, 19, 22], fill=C("P02"))
        return im
    d.rectangle([12, 10, 19, 36], fill=C("P48")); d.line([12, 10, 12, 36], fill=C("P49"))
    d.rectangle([10, 21, 21, 24], fill=C("P47"))                                                     # 이음(갈라짐)
    d.point((15, 22), fill=C("P01")); d.point((17, 23), fill=C("P01"))
    d.rectangle([14, 4, 17, 10], fill=C("P05"))                                                      # 밸브 축
    d.rectangle([8, 3, 23, 5], fill=C("P53")); d.line([8, 3, 23, 3], fill=C("P54"))                 # 핸들
    d.point((20, 28), fill=C("P25")); d.point((13, 31), fill=C("P25"))
    return im


def trefoil(d, cx, cy, r, ink, bg):
    """방사능 삼엽 표지(날개 셋: 아래 · 왼쪽 위 · 오른쪽 위, 각 60°) — 가운데 고리 틈 · 점"""
    for a in (90, 210, 330):
        d.pieslice([cx - r, cy - r, cx + r, cy + r], a - 30, a + 30, fill=C(ink))
    k = max(1, round(r * 0.38))
    d.ellipse([cx - k, cy - k, cx + k, cy + k], fill=C(bg))
    k = max(1, round(r * 0.2))
    d.ellipse([cx - k, cy - k, cx + k, cy + k], fill=C(ink))


def rad_puddle(seed=0):
    """방사능 웅덩이(바닥 장식, 밟고 지나감, 40×22): 검푸른 테 · 형광 녹색 물 · 밝은 거품 알갱이. 둘레 흙은 젖어 어둡다."""
    rnd = random.Random(seed * 13 + 5)
    im = img(40, 22)
    d = ImageDraw.Draw(im)
    lobes = [(20 + rnd.uniform(-8, 8), 11 + rnd.uniform(-2.5, 2.5), rnd.uniform(6, 10), rnd.uniform(3.5, 5.5)) for _ in range(4)]
    px = im.load()
    for y in range(22):
        for x in range(40):
            v = min(((x + 0.5 - lx) / rx) ** 2 + ((y + 0.5 - ly) / ry) ** 2 for lx, ly, rx, ry in lobes)
            if v > 1.45:
                continue
            if v > 1.0:
                tok = "P02" if (x + y) % 2 == 0 else "P29"                          # 젖은 흙 테(바둑판)
            elif v > 0.72:
                tok = "P34"
            elif v > 0.4:
                tok = "P55"
            else:
                tok = "P56"
            px[x, y] = C(tok)
    for _ in range(5):                                                            # 거품 · 빛 알갱이
        lx, ly, rx, ry = lobes[rnd.randrange(4)]
        x, y = int(lx + rnd.uniform(-rx * 0.5, rx * 0.5)), int(ly + rnd.uniform(-ry * 0.4, ry * 0.4))
        if 0 <= x < 40 and 0 <= y < 22 and px[x, y][3]:
            px[x, y] = C("P57")
    lx, ly, rx, ry = lobes[0]
    d.line([int(lx - rx * 0.4), int(ly - ry * 0.45), int(lx), int(ly - ry * 0.45)], fill=C("P57"))   # 물 위 빛줄
    return im


def waste_drum(state=""):
    """방사성 폐기물 드럼(1×1, 26×36): 노란 칠 드럼 · 검은 삼엽 표지 · 찌그러진 옆구리 · 흘러내린 녹색 슬러지와 발치 웅덩이.
    상태 burnt = 그을린 드럼(폭발 뒤에도 웅덩이는 남는다)."""
    im = img(26, 36)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 29, 25, 35], fill=C("P34")); d.ellipse([4, 30, 21, 34], fill=C("P55"))       # 발치 슬러지
    sh = ["P47", "P48", "P49", "P50"]
    for x in range(4, 22):
        nx = (x + 0.5 - 13) / 9
        d.line([x, 11, x, 31], fill=C(sh[0] if nx > 0.6 else sh[1] if nx > 0.05 else sh[2] if nx > -0.65 else sh[3]))
    for y in (16, 26):
        d.line([4, y, 21, y], fill=C("P47"))
    d.ellipse([4, 6, 21, 15], fill=C("P48")); d.ellipse([6, 8, 19, 13], fill=C("P47"))
    d.point((15, 10), fill=C("P02"))                                                          # 마개
    trefoil(d, 12, 21, 4, "P02", "P49")
    d.line([19, 18, 21, 22], fill=C("P58")); d.point((20, 20), fill=C("P47"))                # 찌그러짐
    d.line([7, 13, 7, 24], fill=C("P55")); d.line([8, 13, 8, 18], fill=C("P56"))             # 넘친 슬러지 줄
    d.line([16, 14, 16, 20], fill=C("P55"))
    d.point((8, 29), fill=C("P57")); d.point((17, 31), fill=C("P57"))
    if state == "burnt":
        return burnt(im)
    return im


def rad_cask(state=""):
    """차폐 용기(방사능 함정, 1×1, 30×38): 땅딸막한 납 회색 원통 · 노란 띠 삼엽 표지 · 옆 손잡이(레버).
    open = 뚜껑이 들려 녹색 빛이 새어 나온다 · off = 뚜껑을 다시 조이고 분필로 '봉인' 가위표."""
    im = img(30, 38)
    d = ImageDraw.Draw(im)
    d.ellipse([3, 32, 27, 37], fill=C("P02"))
    sh = ["P11", "P12", "P13", "P14"]
    for x in range(5, 25):
        nx = (x + 0.5 - 15) / 10
        d.line([x, 14, x, 34], fill=C(sh[0] if nx > 0.6 else sh[1] if nx > 0.05 else sh[2] if nx > -0.65 else sh[3]))
    d.rectangle([5, 21, 24, 27], fill=C("P49")); d.line([5, 21, 24, 21], fill=C("P50")); d.line([5, 27, 24, 27], fill=C("P48"))
    trefoil(d, 15, 24, 3, "P02", "P49")
    d.rectangle([25, 17, 27, 19], fill=C("P11")); d.line([27, 18, 29, 12 if state != "open" else 22], fill=C("P53"))   # 레버(열리면 내려감)
    if state == "open":
        d.ellipse([5, 10, 24, 18], fill=C("P55")); d.ellipse([8, 11, 21, 16], fill=C("P56")); d.ellipse([11, 12, 18, 15], fill=C("P57"))
        d.polygon([(3, 9), (16, 3), (27, 7), (14, 12)], fill=C("P13")); d.line([3, 9, 16, 3], fill=C("P15"))   # 들린 뚜껑
        for x, y in ((9, 6), (13, 2), (20, 4)):
            d.point((x, y), fill=C("P57"))
    else:
        d.ellipse([5, 10, 24, 18], fill=C("P13")); d.ellipse([7, 11, 22, 16], fill=C("P14"))
        for x in (8, 15, 21):
            d.point((x, 13), fill=C("P10"))                                                  # 볼트
        if state == "off":
            d.line([9, 29, 13, 33], fill=C("P09")); d.line([13, 29, 9, 33], fill=C("P09"))  # 분필 가위표
    return im


def rad_sign(seed=0):
    """방사능 표지판(1×1, 28×46): 기운 쇠막대에 노란 삼각판 · 검은 삼엽 · 아래 붉은 띠 '방사능'. 녹 흘림."""
    from props_road import put_text
    im = img(28, 46)
    d = ImageDraw.Draw(im)
    d.ellipse([7, 41, 21, 45], fill=C("P02"))
    d.line([14, 18, 13, 43], fill=C("P05")); d.line([15, 18, 14, 43], fill=C("P04"))
    d.polygon([(14, 1), (27, 23), (1, 23)], fill=C("P02"))
    d.polygon([(14, 3), (25, 22), (3, 22)], fill=C("P49"))
    d.line([14, 3, 3, 22], fill=C("P50"))
    trefoil(d, 14, 15, 4, "P02", "P49")
    d.rectangle([2, 25, 26, 33], fill=C("P53")); d.line([2, 25, 26, 25], fill=C("P54"))
    put_text(im, "방사능", 3, 25, "P09", size=8)
    for x, h in ((6, 3), (20, 5)):
        d.line([x, 22, x, 22 + h], fill=C("P25"))
    return im


# 그을린 색: 밝기 순서로 어두운 회갈색 사다리에 옮긴다(팔레트 안)
_BURN = ["P01", "P01", "P02", "P02", "P03", "P38", "P04", "P39", "P05", "P24", "P06"]


def burnt(src):
    out = src.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            lum = (r * 3 + g * 6 + b) / 2550.0
            tok = _BURN[min(len(_BURN) - 1, int(lum * len(_BURN) * 0.95))]
            h = ((x * 73856093) ^ (y * 19349663)) % 41
            if h == 0 and lum > 0.25:
                tok = "P25"                                                                          # 녹 · 불씨 자국(흩뿌림)
            elif h in (1, 2) and lum > 0.4:
                tok = "P02"                                                                          # 그을음 얼룩
            px[x, y] = C(tok)
    return out


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_TRAP = {
    "trap_vending": _r(vending, 1, 1, down=-2),
    "trap_parcel": _r(parcel, 1, 1, down=-2),
    "gas_pipe": _r(gas_pipe, 1, 1, down=-4),
    "rad_puddle": _r(rad_puddle, 0, 0, "deco"),                   # 방사능 지대(1-9d): 웅덩이 Z1 · 폐기물 드럼 Z2 · 차폐 용기(함정) · 표지판
    "rad_puddle2": _r(lambda: rad_puddle(1), 0, 0, "deco"),
    "waste_drum": _r(waste_drum, 1, 1, down=-2),
    "rad_cask": _r(rad_cask, 1, 1, down=-2),
    "rad_sign": _r(rad_sign, 1, 1, down=0),
}
STATES_TRAP = {
    "trap_vending": {"boom": lambda: vending("boom")},
    "trap_parcel": {"boom": lambda: parcel("boom")},
    "gas_pipe": {"boom": lambda: gas_pipe("boom")},
    "waste_drum": {"burnt": lambda: waste_drum("burnt")},
    "rad_cask": {"open": lambda: rad_cask("open"), "off": lambda: rad_cask("off")},
}


def burnt_states(props):
    """원자력 차량 · 드럼 · 가스통: 터진 뒤 '그을린' 상태 그림(기존 그림의 색 바꿈)"""
    out = {}
    for n in ("car_wreck", "car_wreck2", "bus_wreck", "drum", "lp_gas", "convoy_truck"):
        if n in props:
            out[n] = {"burnt": (lambda n=n: burnt(props[n]["fn"]()))}
    return out
