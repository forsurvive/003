"""사당 고개 검문소 소품(단계 1-8g, SD-09a L-R01-19 · SD-16 §7·§8 아이작풍).
비상정부 계엄군의 시작 검문소: 차단봉 둘 · 모래주머니 진지 · 컨테이너 막사 · 확성기 기둥(공보방송) · 분류반 천막('등록 상담 창구') · 감시탑.
게시판에는 공보방송 수배 전단과 2077년 계엄 포고문 '제7호'가 나란히 — 200년 차이가 나는 두 종이가 같은 서체다.
색: 계엄군 감색(P43~P45)·국방색(P28~P31)·경고 적백(P53/P09). props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다.
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _tw(s):
    w, _ = put_text(img(1, 1), s, 0, 0, "P09", 8, "Galmuri7")
    return w


def boom(up=False):
    """차단봉(3×1): 콘크리트 받침 + 쇠기둥 + 평형추 + 적백 줄무늬 팔. up = 팔을 세웠다(지나갈 수 있는 모습)."""
    im = img(98, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 40, 22, 54], fill=C("P05")); d.line([2, 40, 22, 40], fill=C("P07"))      # 받침
    d.rectangle([9, 18, 15, 41], fill=C("P12")); d.line([9, 18, 9, 41], fill=C("P14"))       # 기둥
    d.rectangle([6, 14, 18, 22], fill=C("P11")); d.point((12, 18), fill=C("P53"))            # 축 상자 · 빨간 불
    if up:
        d.rectangle([3, 22, 9, 30], fill=C("P04"))                                            # 평형추(아래로)
        for i in range(0, 6):
            y0 = 14 - i * 2
            d.rectangle([11, y0 - 2 - i * 0, 15, y0], fill=C("P53" if i % 2 else "P09"))
        d.line([13, 2, 13, 14], fill=C("P09"), width=4)
        for y in range(2, 14, 6):
            d.line([11, y, 15, y + 3], fill=C("P53"), width=2)
    else:
        d.rectangle([0, 15, 8, 21], fill=C("P04"))                                            # 평형추
        for i, x in enumerate(range(18, 96, 8)):                                              # 적백 팔
            d.rectangle([x, 16, x + 7, 20], fill=C("P53" if i % 2 else "P09"))
        d.line([18, 16, 96, 16], fill=C("P07")); d.line([18, 20, 96, 20], fill=C(INK))
        d.rectangle([92, 20, 95, 44], fill=C("P12")); d.rectangle([90, 44, 97, 47], fill=C("P05"))   # 팔 받침대
    return im


def speaker_pole():
    """확성기 기둥(1×1): 쇠기둥 + 나팔 확성기 둘 + '공보방송' 판 + 전선."""
    im = img(32, 72)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 6, 17, 68], fill=C("P12")); d.line([14, 6, 14, 68], fill=C("P14"))
    d.rectangle([10, 66, 21, 70], fill=C("P05"))
    for (x0, flip) in ((2, False), (18, True)):                                              # 나팔 둘
        if flip:
            d.polygon([(16, 8), (29, 3), (29, 17), (16, 12)], fill=C("P13")); d.ellipse([26, 3, 31, 17], fill=C("P11"))
        else:
            d.polygon([(15, 8), (2, 3), (2, 17), (15, 12)], fill=C("P13")); d.ellipse([0, 3, 5, 17], fill=C("P11"))
    d.rectangle([8, 22, 23, 32], fill=C("P44")); d.rectangle([9, 23, 22, 31], fill=C("P45"))  # 공보방송 판
    d.line([11, 26, 20, 26], fill=C("P09")); d.line([11, 28, 18, 28], fill=C("P09"))
    d.line([17, 34, 25, 44], fill=C("P02")); d.line([25, 44, 25, 66], fill=C("P02"))          # 전선
    return im


def barracks(seed=1):
    """컨테이너 막사(3×2): 국방색 컨테이너 + 철문 · 창(철망) · 흰 글씨 '제7 검문대' · 지붕 모래주머니 · 연통."""
    rnd = random.Random(seed)
    im = img(98, 76)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 22, 95, 74], fill=C("P29")); d.rectangle([2, 22, 95, 26], fill=C("P31"))   # 몸
    for x in range(6, 94, 5):
        d.line([x, 27, x, 72], fill=C("P28"))                                                  # 골
    d.rectangle([2, 10, 95, 22], fill=C("P30")); d.line([2, 10, 95, 10], fill=C("P32"))       # 지붕
    for x in range(8, 70, 10):
        d.rounded_rectangle([x, 4, x + 10, 12], radius=3, fill=C("P21")); d.line([x + 1, 5, x + 9, 5], fill=C("P22"))   # 지붕 모래주머니
    d.rectangle([78, 0, 82, 12], fill=C("P05"))                                                # 연통
    d.rectangle([12, 40, 30, 72], fill=C("P11")); d.rectangle([13, 41, 29, 71], fill=C("P12"))  # 철문
    d.point((27, 56), fill=C("P15"))
    d.rectangle([44, 36, 64, 50], fill=C("P02")); d.rectangle([45, 37, 63, 49], fill=C("P10"))  # 창(철망)
    for x in range(46, 63, 3):
        d.line([x, 37, x + 2, 49], fill=C("P13"))
    put_text(im, "제7 검문대", 50, 56, "P09", 8, "Galmuri7")
    for _ in range(4):                                                                        # 녹 자국
        x = rnd.randrange(4, 90)
        d.line([x, 27, x, 27 + rnd.randint(4, 14)], fill=C("P25"))
    return im


def class_tent():
    """분류반 천막(3×2): 국방색 대형 천막 + 앞 차양 + '등록 상담 창구' 판 + 접수대(도장 · 서류철) · 판독기 상자."""
    im = img(98, 74)
    d = ImageDraw.Draw(im)
    d.polygon([(4, 70), (4, 26), (49, 6), (94, 26), (94, 70)], fill=C("P30"))               # 몸
    d.polygon([(49, 6), (94, 26), (94, 70), (70, 70)], fill=C("P29"))
    d.line([4, 26, 49, 6], fill=C("P32")); d.line([49, 6, 94, 26], fill=C("P31"))
    d.polygon([(14, 34), (84, 34), (92, 46), (6, 46)], fill=C("P31")); d.line([6, 46, 92, 46], fill=C("P28"))   # 차양
    for x in (8, 90):
        d.line([x, 46, x, 70], fill=C("P18"), width=2)
    d.rectangle([20, 46, 78, 70], fill=C("P02"))                                               # 안(어둠)
    w = _tw("등록 상담 창구")
    d.rectangle([49 - w // 2 - 3, 20, 49 + w // 2 + 3, 34], fill=C("P09")); d.rectangle([49 - w // 2 - 3, 20, 49 + w // 2 + 3, 21], fill=C("P44"))
    d.line([49 - w // 2 - 3, 34, 49 + w // 2 + 3, 34], fill=C(INK))
    put_text(im, "등록 상담 창구", 49 - w // 2, 23, "P44", 8, "Galmuri7")
    d.rectangle([22, 58, 76, 64], fill=C("P19")); d.line([22, 58, 76, 58], fill=C("P20"))     # 접수대
    d.rectangle([28, 54, 38, 58], fill=C("P09")); d.rectangle([42, 55, 46, 58], fill=C("P53"))  # 서류철 · 도장
    d.rectangle([58, 50, 70, 58], fill=C("P11")); d.rectangle([60, 52, 68, 55], fill=C("P47"))  # 판독기 상자(호박 불)
    d.rectangle([22, 64, 26, 70], fill=C("P18")); d.rectangle([72, 64, 76, 70], fill=C("P18"))
    return im


def wanted_board():
    """검문소 게시판(2×1): 나무 판 + 공보방송 수배 전단 둘(얼굴 칸 · 붉은 띠) + 2077년 계엄 포고문 '제7호'(누렇게 바랜 종이) — 서체가 같다."""
    im = img(66, 54)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 32, 9, 52], fill=C("P18")); d.rectangle([56, 32, 59, 52], fill=C("P18"))
    d.rectangle([1, 4, 64, 36], fill=C("P18")); d.rectangle([3, 6, 62, 34], fill=C("P19"))
    for i, x in enumerate((5, 20)):                                                           # 수배 전단 둘
        d.rectangle([x, 8, x + 13, 32], fill=C("P09")); d.rectangle([x, 8, x + 13, 11], fill=C("P53"))
        d.rectangle([x + 3, 13, x + 10, 21], fill=C("P06")); d.ellipse([x + 5, 14, x + 8, 17], fill=C("P04"))
        for y in (24, 27, 30):
            d.line([x + 2, y, x + 11, y], fill=C("P04"))
    d.rectangle([37, 8, 60, 32], fill=C("P21")); d.rectangle([37, 8, 60, 11], fill=C("P02"))  # 포고문 제7호(바램)
    put_text(im, "제7호", 40, 12, "P02", 8, "Galmuri7")
    for y in (23, 26, 29):
        d.line([39, y, 58, y], fill=C("P18"))
    d.point((38, 9), fill=C("P05")); d.point((59, 9), fill=C("P05"))
    return im


def bj_flag():
    """비상정부 깃발(1×1): 쇠 깃대 + 감색 깃발(흰 테 · 가운데 국가 문장 모양 원)."""
    im = img(32, 70)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 4, 8, 68], fill=C("P13")); d.ellipse([5, 1, 10, 6], fill=C("P48"))
    d.rectangle([4, 64, 12, 68], fill=C("P05"))
    d.polygon([(9, 8), (30, 10), (29, 30), (9, 28)], fill=C("P44"))
    d.line([9, 8, 30, 10], fill=C("P09")); d.line([9, 28, 29, 30], fill=C("P09"))
    d.ellipse([14, 13, 24, 24], outline=C("P09")); d.point((19, 18), fill=C("P09"))
    return im


def issuer():
    """임시 등록증 발급기(1×1, 분류반 천막 안): 철제 함 + 천공 카드 투입구 · 등급 버튼 다섯 · 호박 불."""
    im = img(32, 46)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 10, 27, 44], fill=C("P12")); d.rectangle([5, 11, 26, 43], fill=C("P13"))
    d.line([5, 11, 26, 11], fill=C("P15"))
    d.rectangle([8, 14, 23, 22], fill=C("P02")); d.line([10, 17, 21, 17], fill=C("P47")); d.line([10, 19, 17, 19], fill=C("P48"))
    for i in range(5):
        d.rectangle([7 + i * 4, 25, 9 + i * 4, 27], fill=C(["P53", "P48", "P48", "P07", "P07"][i]))
    d.rectangle([9, 31, 22, 33], fill=C("P01"))                                               # 카드 투입구
    d.rectangle([11, 34, 20, 40], fill=C("P21")); d.line([12, 36, 19, 36], fill=C("P18"))     # 나와 있는 카드
    d.rectangle([3, 43, 28, 45], fill=C("P11"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_BJ = {
    "bj_boom": _r(lambda: boom(False), 3, 1, down=-2),
    "bj_boom_up": _r(lambda: boom(True), 1, 1, down=-2),
    "bj_speaker": _r(speaker_pole, 1, 1, down=-4),
    "bj_barracks": _r(lambda: barracks(1), 3, 2, down=-2),
    "bj_class_tent": _r(class_tent, 3, 2, down=-2),
    "bj_board": _r(wanted_board, 2, 1, down=-2),
    "bj_flag": _r(bj_flag, 1, 1, down=-4),
    "bj_issuer": _r(issuer, 1, 1, down=-2),
}
