"""청계산 벙커 C05(권한대행 집무실 · 비서실 · 귀빈실) 소품과 북사면 환기탑 바깥 소품(단계 1-7, SD-09d L-R11-01 C05 · SD-03a §8.6 MQ-106
'걸어 들어간다' · §6.7 계엄군 생포 판 압수품 보관함, SD-16 §7·§8 아이작풍).
집무실은 2077년 정부서울청사 장관실 가구를 옮겨 놓은 방이다: 짙은 호두나무 책상 위 다섯 가지(지침 원본 · 계보 대장 사본 · 관리자 등록 서류 ·
생체 인증 견본 판 · 권한대행 직인), 태극기와 13개 별 성조기가 나란한 깃대, 진열장(경호 권총 · 국무위원 배지 7자리 중 4자리 빔).
귀빈실: 각 잡힌 침대 · 찻상 · 2077년 한강 사진을 끼운 가짜 창 · 공보방송 스피커. 바깥: 위장망 두른 환기탑 · 압수품 보관함.
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01).
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
WALNUT = ["P16", "P17", "P18", "P19"]
STEEL = ["P10", "P11", "P12", "P13"]
OLIVE = ["P28", "P29", "P30", "P31"]
BRASS = ["P47", "P48", "P49", "P50"]


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def box3(d, x0, y0, x1, y1, top_h, ramp, edge=True):
    """3/4 시점 상자: 윗면(밝게) + 앞면(어둡게). ramp 어두움→밝음 4단."""
    d.rectangle([x0, y0 + top_h, x1, y1], fill=C(ramp[1]))
    d.rectangle([x0, y0, x1, y0 + top_h], fill=C(ramp[2]))
    if edge:
        d.line([x0, y0, x1, y0], fill=C(ramp[3]))
        d.line([x0, y0 + top_h, x1, y0 + top_h], fill=C(ramp[0]))
        d.line([x0, y0 + top_h + 1, x0, y1], fill=C(ramp[2]))
        d.line([x1, y0 + top_h + 1, x1, y1], fill=C(ramp[0]))


# ================================================================================================ 집무실
def minister_desk():
    """권한대행 책상(3×1): 2077년 장관실의 짙은 호두나무 책상 — 녹색 가죽 깔판 위 다섯 가지(왼쪽부터 지침 원본 · 계보 대장 사본 ·
    관리자 등록 서류 · 생체 인증 견본 판 · 직인 함). 앞판에 봉황 무늬 대신 닳은 놋쇠 열쇠 구멍 셋."""
    im = img(94, 52)
    d = ImageDraw.Draw(im)
    box3(d, 1, 16, 92, 48, 14, WALNUT)
    for x in (3, 88):                                                     # 다리
        d.rectangle([x, 49, x + 3, 51], fill=C("P16"))
    d.rectangle([6, 17, 87, 28], fill=C("P29"))                           # 가죽 깔판
    d.line([6, 17, 87, 17], fill=C("P30"))
    d.rectangle([6, 17, 87, 28], outline=C("P28"))
    # ① 지침 원본: 누런 종이 묶음 + 붉은 관인
    d.rectangle([9, 18, 22, 27], fill=C("P21")); d.rectangle([10, 18, 23, 26], fill=C("P22"))
    for y in (20, 22, 24):
        d.line([12, y, 20, y], fill=C("P19"))
    d.rectangle([18, 23, 21, 25], fill=C("P53"))
    # ② 계보 대장 사본: 감색 천 장정 + 금박 띠
    d.rectangle([26, 18, 38, 27], fill=C("P44")); d.line([26, 18, 38, 18], fill=C("P45"))
    d.line([28, 18, 28, 27], fill=C("P43")); d.rectangle([31, 21, 36, 22], fill=C("P48"))
    # ③ 관리자 등록 서류: 흰 서식 + 서명란 + 만년필
    d.rectangle([42, 18, 55, 27], fill=C("P08")); d.rectangle([42, 18, 55, 26], fill=C("P09"))
    d.rectangle([44, 20, 53, 21], fill=C("P44"))
    d.line([44, 24, 51, 24], fill=C("P06"))
    d.line([52, 27, 58, 21], fill=C("P02")); d.point((58, 21), fill=C("P49"))
    # ④ 생체 인증 견본 판: 회색 판 + 손바닥 자국 + 호박색 대기등
    d.rectangle([61, 18, 74, 27], fill=C("P05")); d.rectangle([62, 19, 73, 26], fill=C("P04"))
    d.ellipse([64, 21, 69, 26], fill=C("P06"))
    for fx in (64, 66, 68, 70):
        d.line([fx, 21, fx + (1 if fx == 70 else 0), 19 if fx != 70 else 22], fill=C("P06"))
    d.point((72, 20), fill=C("P60"))
    # ⑤ 직인 함: 놋쇠 상자 + 붉은 인주
    d.rectangle([77, 19, 85, 26], fill=C("P47")); d.rectangle([77, 19, 85, 21], fill=C("P48"))
    d.line([77, 19, 85, 19], fill=C("P49")); d.rectangle([80, 23, 82, 25], fill=C("P52"))
    # 앞판: 서랍 셋 + 놋쇠 열쇠 구멍
    for x0 in (6, 34, 62):
        d.rectangle([x0, 34, x0 + 24, 44], outline=C("P16"))
        d.line([x0 + 1, 35, x0 + 23, 35], fill=C("P18"))
        d.rectangle([x0 + 11, 38, x0 + 13, 40], fill=C("P48")); d.point((x0 + 12, 39), fill=C("P16"))
    return im


def flag_stand():
    """깃대 둘(1×1): 왼쪽 태극기 · 오른쪽 13개 별 성조기(한미 연합 체제의 흔적, SD-09d C05). 놋쇠 깃봉, 무거운 받침."""
    im = img(32, 66)
    d = ImageDraw.Draw(im)
    d.ellipse([3, 58, 29, 65], fill=C("P02"))                             # 받침 그림자
    for px_ in (9, 22):
        d.rectangle([px_ - 4, 56, px_ + 4, 61], fill=C("P17")); d.line([px_ - 4, 56, px_ + 4, 56], fill=C("P19"))
        d.line([px_, 4, px_, 56], fill=C("P18")); d.line([px_ + 1, 4, px_ + 1, 56], fill=C("P16"))
        d.ellipse([px_ - 2, 1, px_ + 2, 5], fill=C("P49")); d.point((px_ - 1, 2), fill=C("P50"))
    # 태극기(깃대에 처진 천): 흰 바탕 + 붉은·푸른 태극 + 네 귀 괘
    d.polygon([(10, 7), (2, 9), (1, 26), (10, 24)], fill=C("P08"))
    d.polygon([(10, 7), (3, 8), (3, 24), (10, 23)], fill=C("P09"))
    d.pieslice([3, 12, 9, 18], 180, 360, fill=C("P53")); d.pieslice([3, 12, 9, 18], 0, 180, fill=C("P45"))
    for (x, y) in ((4, 10), (8, 10), (4, 21), (8, 21)):
        d.line([x - 1, y, x, y], fill=C("P01"))
    d.line([2, 24, 10, 24], fill=C("P07"))                                # 처진 주름 그늘
    # 성조기: 붉은·흰 줄 + 푸른 칸에 둥근 별 13
    d.polygon([(23, 7), (31, 9), (31, 26), (23, 24)], fill=C("P09"))
    for i, y in enumerate(range(8, 25, 2)):
        if i % 2 == 0:
            d.line([23, y, 31, y + 1], fill=C("P53"))
    d.rectangle([23, 8, 27, 14], fill=C("P44"))
    for (x, y) in ((25, 9), (24, 10), (26, 10), (24, 12), (26, 12), (25, 13)):
        d.point((x, y), fill=C("P09"))
    d.line([23, 24, 31, 26], fill=C("P07"))
    return im


def display_case():
    """진열장(1×1): 나무 받침 위 유리 상자 — 경호 권총 W-111(검은 자동 권총, 상아 손잡이) + 국무위원 배지 7자리(셋만 남고 넷은 빈 홈).
    유리 위 사선 반사. 놋쇠 자물쇠(잠금 매우 어려움)."""
    im = img(32, 50)
    d = ImageDraw.Draw(im)
    box3(d, 1, 30, 30, 48, 4, WALNUT)
    d.rectangle([2, 10, 29, 31], fill=C("P15"))                           # 유리 상자
    d.rectangle([3, 11, 28, 30], fill=C("P17"))                           # 안쪽 벨벳(짙은 갈색)
    d.rectangle([3, 11, 28, 30], outline=C("P14"))
    d.polygon([(6, 15), (17, 15), (18, 17), (11, 17), (10, 20), (7, 20), (8, 17), (6, 17)], fill=C("P01"))   # 권총
    d.line([7, 15, 16, 15], fill=C("P04"))
    d.rectangle([8, 17, 10, 20], fill=C("P08"))                           # 상아 손잡이
    slots = [(6, 24), (10, 24), (14, 24), (18, 24), (22, 24), (8, 27), (12, 27)]
    for i, (x, y) in enumerate(slots):                                    # 배지 7자리: 0·2·5 남음
        if i in (0, 2, 5):
            d.ellipse([x, y, x + 2, y + 2], fill=C("P49")); d.point((x + 1, y + 1), fill=C("P53"))
        else:
            d.ellipse([x, y, x + 2, y + 2], outline=C("P16"))
    d.line([21, 18, 27, 12], fill=C("P15")); d.line([24, 18, 28, 14], fill=C("P15"))   # 유리 반사(오른쪽 위 귀퉁이만)
    d.rectangle([14, 33, 17, 36], fill=C("P48")); d.point((15, 34), fill=C("P16"))   # 자물쇠
    return im


# ================================================================================================ 비서실 · 귀빈실
def typewriter_desk():
    """비서 책상(2×1): 회녹색 철제 책상 + 2077년 타자기(종이가 물린 채) + 결재 서류 상자 둘 + 검은 다이얼 전화기."""
    im = img(62, 50)
    d = ImageDraw.Draw(im)
    box3(d, 1, 18, 60, 46, 11, ["P33", "P34", "P35", "P36"])
    for x in (3, 56):
        d.rectangle([x, 47, x + 3, 49], fill=C("P02"))
    d.rectangle([14, 8, 34, 22], fill=C("P03")); d.rectangle([15, 9, 33, 18], fill=C("P04"))   # 타자기 몸
    d.rectangle([17, 2, 31, 11], fill=C("P09")); d.line([19, 5, 29, 5], fill=C("P06")); d.line([19, 7, 27, 7], fill=C("P06"))
    d.rectangle([13, 10, 35, 11], fill=C("P02"))                          # 롤러
    for x in range(17, 32, 3):
        for y in (14, 16):
            d.point((x, y), fill=C("P08"))
    for x0, n in ((38, 3), (48, 5)):                                      # 결재 상자(들어온 것 · 나간 것)
        d.rectangle([x0, 15, x0 + 8, 24], fill=C("P05"))
        for k in range(n):
            d.line([x0 + 1, 21 - k, x0 + 7, 21 - k], fill=C("P09" if k % 2 == 0 else "P08"))
    d.rectangle([3, 16, 11, 23], fill=C("P01")); d.ellipse([4, 17, 10, 22], fill=C("P02"))   # 전화기
    d.ellipse([6, 18, 8, 20], fill=C("P07"))
    d.rectangle([4, 13, 10, 15], fill=C("P01"))
    d.rectangle([22, 32, 40, 40], outline=C("P34")); d.rectangle([29, 35, 33, 36], fill=C("P07"))   # 서랍
    return im


def vip_bed():
    """귀빈실 침대(1×2, 세로 두 칸): 철제 머리판 + 각 잡힌 흰 시트 + 발치에 접힌 회색 모포(비상정부 휘장 — 동심원과 열쇠 구멍)."""
    im = img(34, 66)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 32, 10], fill=C("P11")); d.line([1, 2, 32, 2], fill=C("P13"))   # 머리판
    for x in (6, 12, 18, 24):
        d.line([x, 4, x, 9], fill=C("P10"))
    d.rectangle([2, 10, 31, 62], fill=C("P07"))                            # 매트리스 옆면
    d.rectangle([2, 10, 31, 58], fill=C("P09"))                            # 시트
    d.rounded_rectangle([5, 12, 28, 20], 3, fill=C("P08")); d.line([7, 13, 26, 13], fill=C("P09"))   # 베개
    d.line([3, 24, 30, 24], fill=C("P08"))                                 # 시트 접힌 선(각)
    d.rectangle([2, 44, 31, 58], fill=C("P05")); d.rectangle([2, 44, 31, 46], fill=C("P06"))   # 접힌 모포
    d.line([2, 51, 31, 51], fill=C("P04"))
    d.ellipse([12, 46, 21, 55], outline=C("P53")); d.ellipse([14, 48, 19, 53], outline=C("P53"))   # 휘장
    d.point((16, 50), fill=C("P53")); d.line([16, 51, 16, 52], fill=C("P53"))
    d.rectangle([3, 62, 6, 65], fill=C("P10")); d.rectangle([27, 62, 30, 65], fill=C("P10"))
    return im


def tea_table():
    """찻상(1×1): 둥근 나무 탁자 + 흰 사기 찻주전자 + 찻잔 둘(하나는 김이 오른다) + 마른 비스킷 접시. '차는 드릴 수 있습니다.'"""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 30, 30, 39], fill=C("P02"))
    d.rectangle([14, 26, 17, 36], fill=C("P17"))
    d.ellipse([1, 18, 30, 30], fill=C("P18")); d.ellipse([1, 16, 30, 28], fill=C("P20"))
    d.arc([1, 16, 30, 28], 180, 360, fill=C("P21"))
    d.ellipse([7, 13, 16, 22], fill=C("P08")); d.ellipse([8, 13, 15, 20], fill=C("P09"))   # 주전자
    d.rectangle([10, 11, 13, 13], fill=C("P08")); d.line([16, 17, 19, 14], fill=C("P08"))
    d.line([6, 16, 6, 19], fill=C("P08"))
    for (x, y) in ((20, 19), (23, 23)):                                   # 찻잔
        d.ellipse([x, y, x + 5, y + 3], fill=C("P09")); d.ellipse([x + 1, y, x + 4, y + 2], fill=C("P19"))
    for k, y in enumerate((14, 12, 10)):                                  # 김
        d.point((22 + (k % 2), y), fill=C("P08"))
    d.ellipse([3, 21, 8, 24], fill=C("P08"))
    d.point((5, 22), fill=C("P21")); d.point((6, 22), fill=C("P21"))
    return im


def w_fake_window():
    """가짜 창(벽, 2칸): 지하 z-2 벽에 창틀을 달고 2077년 봄 한강 사진을 끼웠다 — 바랜 하늘, 다리, 강 건너 빌딩 줄. 커튼 반쯤."""
    im = img(60, 34)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 59, 33], fill=C("P19")); d.rectangle([0, 0, 59, 1], fill=C("P21"))
    d.rectangle([4, 4, 55, 29], fill=C("P15"))                            # 하늘(바랜 청)
    d.rectangle([4, 4, 55, 12], fill=C("P14"))
    for x, hgt in ((8, 6), (13, 9), (18, 5), (24, 11), (31, 7), (37, 10), (44, 6), (50, 8)):   # 빌딩 줄
        d.rectangle([x, 20 - hgt, x + 4, 20], fill=C("P13"))
        d.point((x + 2, 20 - hgt + 2), fill=C("P15"))
    d.rectangle([4, 20, 55, 29], fill=C("P46")); d.rectangle([4, 23, 55, 29], fill=C("P45"))   # 강
    d.line([4, 19, 55, 18], fill=C("P05")); d.line([4, 20, 55, 19], fill=C("P06"))            # 다리
    for x in range(8, 54, 9):
        d.line([x, 20, x, 24], fill=C("P05"))
    d.line([29, 4, 29, 29], fill=C("P19")); d.line([4, 16, 55, 16], fill=C("P19"))            # 창살
    d.polygon([(4, 4), (16, 4), (13, 29), (4, 29)], fill=C("P52"))                         # 커튼
    d.line([8, 4, 7, 29], fill=C("P51")); d.line([12, 4, 11, 29], fill=C("P53"))
    return im


def w_speaker():
    """공보방송 스피커(벽, 1칸): 국방색 철함 + 둥근 그릴 + '공보' 스텐실. 귀빈실에서는 끌 수 없다."""
    im = img(26, 24)
    d = ImageDraw.Draw(im)
    box3(d, 1, 1, 24, 22, 3, OLIVE)
    d.ellipse([5, 6, 20, 19], fill=C("P02"))
    for r in (2, 4, 6):
        d.ellipse([12 - r, 12 - r, 13 + r, 13 + r], outline=C("P04"))
    return im


# ================================================================================================ 북사면(바깥)
def vent_tower():
    """청계산 위장 환기탑(2×2): 콘크리트 원통 위 루버 지붕, 둘레를 덮은 위장망(초록·갈색 천 조각), 탑 밑동에 쇠 점검문."""
    im = img(64, 92)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 78, 60, 91], fill=C("P02"))
    d.rectangle([12, 18, 52, 84], fill=C("P05"))                          # 원통
    d.rectangle([12, 18, 22, 84], fill=C("P06")); d.rectangle([44, 18, 52, 84], fill=C("P04"))
    d.ellipse([12, 78, 52, 88], fill=C("P05"))
    for y in range(24, 80, 12):                                           # 거푸집 이음
        d.line([12, y, 52, y], fill=C("P04"))
    d.ellipse([8, 8, 56, 26], fill=C("P04")); d.ellipse([10, 8, 54, 22], fill=C("P06"))   # 루버 지붕
    for x in range(14, 52, 5):
        d.line([x, 12, x + 2, 20], fill=C("P03"))
    rnd = random.Random(17)
    for _ in range(46):                                                   # 위장망 천 조각
        x, y = rnd.randint(9, 54), rnd.randint(16, 78)
        d.rectangle([x, y, x + rnd.randint(2, 5), y + rnd.randint(1, 3)], fill=C(rnd.choice(["P29", "P30", "P18", "P28", "P31"])))
    for x in range(10, 56, 4):                                            # 망 줄
        d.line([x, 16, x + 2, 82], fill=C("P29"))
    d.rectangle([26, 62, 38, 84], fill=C("P11")); d.rectangle([26, 62, 38, 64], fill=C("P12"))   # 점검문
    d.rectangle([35, 72, 36, 74], fill=C("P48"))
    return im


def seized_locker(opened=False):
    """압수품 보관함(1×1, 바깥 · 환기탑 밑): 국방색 철 사물함 + '압수품' 스텐실 + 큰 맹꽁이 자물쇠. opened = 문이 열린 채."""
    im = img(32, 50)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 44, 30, 49], fill=C("P02"))
    box3(d, 2, 6, 29, 46, 4, OLIVE)
    if opened:
        d.rectangle([5, 12, 26, 44], fill=C("P01")); d.rectangle([6, 13, 25, 44], fill=C("P02"))
        d.line([6, 28, 25, 28], fill=C("P04"))                            # 선반
        d.polygon([(26, 12), (31, 10), (31, 45), (26, 44)], fill=C("P30"))   # 열린 문짝
        return im
    d.line([15, 11, 15, 45], fill=C("P28"))
    put_text(im, "압수품", 4, 15, "P49", 8, "Galmuri7")
    d.rectangle([17, 30, 23, 37], fill=C("P05")); d.arc([17, 26, 23, 33], 180, 360, fill=C("P07"))   # 자물쇠
    d.point((20, 33), fill=C("P01"))
    for y in (40, 42):
        d.line([6, y, 13, y], fill=C("P29")); d.line([18, y, 25, y], fill=C("P29"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_CG = {
    "minister_desk": _r(minister_desk, 3, 1),
    "flag_stand": _r(flag_stand, 1, 1),
    "display_case": _r(display_case, 1, 1),
    "typewriter_desk": _r(typewriter_desk, 2, 1),
    "vip_bed": _r(vip_bed, 1, 2),
    "tea_table": _r(tea_table, 1, 1),
    "w_fake_window": _r(w_fake_window, 2, 0, "wall", dx=2, dy=0),
    "w_speaker": _r(w_speaker, 1, 0, "wall", dx=3, dy=6),
    "vent_tower": _r(vent_tower, 2, 2),
    "seized_locker": _r(seized_locker, 1, 1),
}
STATES_CG = {"seized_locker": {"open": lambda: seized_locker(True)}}


if __name__ == "__main__":
    from grid import upscale
    import tiles_isaac as TI
    ims = [(n, TI.outline(r["fn"]())) for n, r in PROPS_CG.items()] + [("seized_locker#open", TI.outline(seized_locker(True)))]
    W = sum(i.width + 8 for _, i in ims) + 8
    sheet = Image.new("RGBA", (W, 110), C("P20"))
    x = 8
    for _, i in ims:
        sheet.alpha_composite(i, (x, 100 - i.height))
        x += i.width + 8
    os.makedirs(os.path.join(os.path.dirname(__file__), "..", "out"), exist_ok=True)
    upscale(sheet, 3).save(os.path.join(os.path.dirname(__file__), "..", "out", "props_cg_x3.png"))
    print("소품 %d" % len(ims))
