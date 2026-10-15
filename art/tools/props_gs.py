"""노량진 관제 중계소 소품(단계 1-8g, SD-09a L-R01-23 · SD-06 §10.11 각성회 · SD-16 §7·§8 아이작풍).
200년 동안 꺼지지 않은 녹색 대기등 하나 — 그 아래 바닥은 무릎 꿇은 자리만 하얗게 닳았다. 언덕 둘레에 흰 천과 대기등 램프 줄,
홀 벽 가득 신도들이 손으로 뚫은 천공 카드. 색: 대기등 녹(P55~P57) · 흰 천(P08/P09) · 진공관 호박(P47~P49) · 콘크리트 회색.
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다.
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


def standby_lamp():
    """대기등(1×1, G-02 홀 가운데): 진공관 함 위 둥근 녹색 등 — 200년 동안 한 번도 안 꺼졌다. 둘레에 빛 번짐."""
    im = img(32, 60)
    d = ImageDraw.Draw(im)
    d.rectangle([9, 30, 22, 56], fill=C("P11")); d.rectangle([10, 31, 21, 55], fill=C("P12"))   # 함
    d.line([10, 31, 21, 31], fill=C("P14"))
    for y in (36, 42, 48):
        d.rectangle([12, y, 19, y + 3], fill=C("P02")); d.point((14, y + 1), fill=C("P48")); d.point((17, y + 1), fill=C("P47"))   # 진공관 창
    d.rectangle([13, 24, 18, 30], fill=C("P05"))
    d.rectangle([11, 21, 20, 24], fill=C("P12"))                                                  # 등 받침 고리
    d.ellipse([8, 7, 23, 22], fill=C("P55")); d.ellipse([10, 9, 21, 20], fill=C("P56")); d.ellipse([12, 10, 17, 14], fill=C("P57"))   # 등
    for (x, y) in ((4, 9), (27, 11), (6, 20), (25, 3), (15, 2)):                                # 반짝임(외곽선 없이 떠 보이게 소품 밖 점 대신 등 둘레 점)
        d.point((x, y), fill=C("P57"))
    d.rectangle([7, 55, 24, 58], fill=C("P05"))
    return im


def kneel_marks():
    """무릎 자리(deco 1×1): 콘크리트 바닥에서 무릎 두 자리만 하얗게 닳았다."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    for (x, y) in ((8, 12), (19, 13)):                                        # 닳아 하얀 자리(디더 — 반투명 대신 점 섞기)
        for yy in range(y, y + 9):
            for xx in range(x, x + 7):
                if ((xx - x - 3) / 3.5) ** 2 + ((yy - y - 4) / 4.5) ** 2 <= 1.0 and (xx + yy) % 2 == 0:
                    d.point((xx, yy), fill=C("P08"))
        d.ellipse([x + 2, y + 3, x + 4, y + 5], fill=C("P09"))
    return im


def lamp_line(seed=1):
    """대기등 램프 줄(2×1): 나무 말뚝 둘 사이 늘어진 전선 + 녹색 전구 다섯 + 흰 천 조각."""
    rnd = random.Random(seed)
    im = img(66, 46)
    d = ImageDraw.Draw(im)
    for x in (3, 60):
        d.rectangle([x, 6, x + 3, 44], fill=C("P18")); d.line([x, 6, x, 44], fill=C("P20"))
    pts = [(4 + i * 6, 9 + int(6 * math.sin(math.pi * i / 10))) for i in range(11)]
    d.line(pts, fill=C("P02"))
    for i in range(1, 10, 2):
        x, y = pts[i]
        d.ellipse([x - 2, y + 1, x + 2, y + 5], fill=C("P56")); d.point((x - 1, y + 2), fill=C("P57"))
    for i in (2, 6, 8):
        x, y = pts[i]
        h = rnd.randint(9, 15)
        d.polygon([(x - 2, y), (x + 2, y), (x + 3, y + h), (x - 1, y + h - 2)], fill=C("P09")); d.line([x - 2, y, x - 1, y + h - 2], fill=C("P07"))
    return im


def cloth_post():
    """흰 천 말뚝(1×1): 언덕 둘레에 박은 쇠막대 + 바람에 날리는 흰 천 세 줄 + 녹색 매듭."""
    im = img(32, 52)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 6, 16, 50], fill=C("P12")); d.line([14, 6, 14, 50], fill=C("P14"))
    for i, (y, ln) in enumerate(((8, 15), (14, 12), (20, 9))):
        d.polygon([(16, y), (16 + ln, y + 2), (16 + ln - 2, y + 6), (16, y + 4)], fill=C("P09")); d.line([16, y + 4, 16 + ln - 2, y + 6], fill=C("P07"))
    d.ellipse([13, 4, 18, 9], fill=C("P55"))
    return im


def w_punch_wall(seed=3):
    """천공 카드 벽(3×0 벽): 신도들이 손으로 뚫은 누런 천공 카드 수십 장이 핀으로 겹겹이 — 그중 한 장만 새 종이."""
    rnd = random.Random(seed)
    im = img(96, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 29], fill=C("P17")); d.rectangle([2, 2, 93, 27], fill=C("P26"))      # 코르크 판(나무 테)
    for _ in range(140):
        d.point((rnd.randrange(3, 93), rnd.randrange(3, 27)), fill=C("P25"))
    for _ in range(40):
        x, y = rnd.randrange(3, 82), rnd.randrange(3, 20)
        col = rnd.choice(["P21", "P22", "P20", "P21"])
        d.rectangle([x, y, x + 9, y + 6], fill=C(col)); d.line([x, y, x + 9, y], fill=C("P22"))
        for k in range(3):
            d.point((x + 2 + rnd.randrange(0, 6), y + 2 + rnd.randrange(0, 3)), fill=C("P18"))   # 구멍
        d.point((x + 4, y), fill=C("P53"))                                                      # 핀
    d.rectangle([42, 10, 52, 17], fill=C("P09")); d.line([42, 10, 52, 10], fill=C(INK))         # 새 카드(주인공 번호 — 1막 이후)
    for k in range(5):
        d.point((44 + k * 2, 13 + (k % 2)), fill=C("P02"))
    return im


def card_punch():
    """천공기(1×1, G-01 대기실): 수동 카드 천공기 — 쇠 레버 · 열두 줄 자판 · 쌓인 빈 카드."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 18, 28, 38], fill=C("P19")); d.line([3, 18, 28, 18], fill=C("P20"))      # 받침 탁자
    d.rectangle([6, 10, 24, 20], fill=C("P12")); d.rectangle([7, 11, 23, 19], fill=C("P13"))
    for r in range(2):
        for c in range(6):
            d.point((9 + c * 2, 13 + r * 3), fill=C("P02"))
    d.line([24, 12, 29, 4], fill=C("P11"), width=2); d.ellipse([27, 2, 31, 6], fill=C("P53"))   # 레버
    d.rectangle([5, 20, 14, 24], fill=C("P21")); d.line([5, 21, 14, 21], fill=C("P22"))     # 빈 카드 더미
    return im


def relay_speaker():
    """방송기 '중계소 스피커'(2×1, G-03): 2077년 관제 방송 콘솔 — 다이얼 · 진공관 창 · 마이크 · 나팔 확성기 하나."""
    im = img(66, 50)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 22, 63, 48], fill=C("P11")); d.rectangle([3, 23, 62, 47], fill=C("P12"))
    d.line([3, 23, 62, 23], fill=C("P14"))
    for i, x in enumerate((8, 18, 28)):
        d.ellipse([x, 27, x + 7, 34], fill=C("P05")); d.line([x + 3, 30, x + 5, 28], fill=C("P09"))
    d.rectangle([38, 27, 58, 36], fill=C("P02"))
    for x in range(40, 57, 4):
        d.ellipse([x, 29, x + 2, 33], fill=C("P48"))
    d.rectangle([8, 40, 58, 44], fill=C("P02")); d.line([10, 42, 30, 42], fill=C("P56"))
    d.line([50, 22, 52, 12], fill=C("P05")); d.ellipse([48, 8, 55, 14], fill=C("P04"))       # 마이크
    d.polygon([(14, 6), (2, 0), (2, 16), (14, 12)], fill=C("P13")); d.ellipse([0, 0, 4, 16], fill=C("P11"))
    d.rectangle([14, 8, 17, 22], fill=C("P05"))
    return im


def manual_shelf():
    """운영 매뉴얼 서가(2×1, G-03): 철제 서가 + 청색 · 회색 바인더 '관제망 운영 지침 제n권' — 손때로 등이 닳았다."""
    im = img(66, 58)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 2, 62, 56], fill=C("P11")); d.rectangle([5, 4, 60, 54], fill=C("P02"))
    for y in (17, 32, 47):
        d.rectangle([5, y, 60, y + 2], fill=C("P12"))
    rnd = random.Random(5)
    for row, y in enumerate((5, 20, 35)):
        x = 6
        while x < 58:
            w = rnd.randint(4, 6)
            col = rnd.choice(["P44", "P45", "P12", "P13", "P44"])
            d.rectangle([x, y, x + w - 1, y + 11], fill=C(col)); d.line([x + 1, y + 3, x + w - 2, y + 3], fill=C("P09"))
            d.line([x + 1, y + 9, x + w - 2, y + 9], fill=C("P07"))
            x += w + 1
    return im


def relay_rack():
    """중계 진공관 랙(1×1): 철제 랙에 진공관 줄 — 셋에 하나는 아직 호박색으로 켜진다(원자 전지)."""
    im = img(32, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 4, 27, 54], fill=C("P11")); d.rectangle([6, 6, 25, 52], fill=C("P02"))
    for row, y in enumerate(range(9, 50, 8)):
        for c, x in enumerate((8, 14, 20)):
            on = (row + c) % 3 == 0
            d.ellipse([x, y, x + 4, y + 6], fill=C("P48" if on else "P05")); d.point((x + 2, y + 1), fill=C("P50" if on else "P07"))
    d.line([6, 6, 25, 6], fill=C("P13"))
    return im


def reservoir_stairs():
    """대기실 입구(2×1, 발 칸 = 출구 칸): 옛 배수지 저수조 덮개에 뚫은 계단 — 뒤 콘크리트 턱 + 흰 천 휘장 + 녹색 '대기실' 판."""
    from props_jm import subway_stairs
    im = subway_stairs("")
    d = ImageDraw.Draw(im)
    d.rectangle([12, 0, 51, 10], fill=C("P29")); d.line([12, 0, 51, 0], fill=C("P31")); d.line([12, 10, 51, 10], fill=C(INK))
    w, _ = put_text(img(1, 1), "대기실", 0, 0, "P09", 8, "Galmuri7")
    put_text(im, "대기실", 32 - w // 2, 1, "P56", 8, "Galmuri7")
    for x in (0, 58):                                                      # 흰 천 휘장
        d.polygon([(x + 1, 12), (x + 5, 12), (x + 6, 30), (x + 2, 28)], fill=C("P09")); d.line([x + 1, 12, x + 2, 28], fill=C("P07"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_GS = {
    "gs_standby_lamp": _r(standby_lamp, 1, 1, down=-4),
    "gs_kneel": _r(kneel_marks, 0, 0, "deco"),
    "gs_lamp_line": _r(lambda: lamp_line(1), 2, 1, down=-2),
    "gs_lamp_line2": _r(lambda: lamp_line(2), 2, 1, down=-2),
    "gs_cloth_post": _r(cloth_post, 1, 1, down=-4),
    "gs_card_punch": _r(card_punch, 1, 1, down=-2),
    "gs_relay_speaker": _r(relay_speaker, 2, 1, down=-2),
    "gs_manual_shelf": _r(manual_shelf, 2, 1, down=-2),
    "gs_relay_rack": _r(relay_rack, 1, 1, down=-2),
    "gs_reservoir_stairs": _r(reservoir_stairs, 2, 1, down=2),
    "w_gs_punch_wall": _r(w_punch_wall, 3, 0, "wall", dx=0, dy=2),
}
