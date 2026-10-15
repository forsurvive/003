"""R01 북쪽 탐험 묶음 소품(단계 1-7c, SD-09a L-R01-22·24·25·26 · SD-16 §7·§8 아이작풍).
- 노량진 학원가(K-24): 진공관 단말 자습석 · 전산 모의고사 채점기 · 과외-3 조교 로봇(SJ-H71, 비전투 — 멈춘 채 책상에 붙어 있다).
- 흑석 대학병원(K-26): 병상(이름표 + '대기 구역' 판독 스티커) · 병동 화이트보드('병상 가동률 312%').
- 노량진 수산시장(L-R01-25): 원자력 냉동고(가동 — 대기등 램프 하나) · 생선 함지(가물치·메기·참게).
- 동작 국립묘지(L-R01-22): 이름 없는 비석 · 빈 기념탑 받침 · 안치소 선반(귀환 유해 상자 + '인수자 미정' 꼬리표 + 마른 꽃 — 유해는 그리지 않는다).
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다.
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
STEEL = ["P10", "P11", "P12", "P13"]
CREAM = ["P06", "P07", "P08", "P09"]
WOOD = ["P16", "P17", "P18", "P19"]
STONE = ["P04", "P05", "P06", "P07"]
INK = "P01"


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


# ================================================================================================ 학원가
def study_carrel():
    """진공관 단말 자습석(2×1): 칸막이 두 자리, 자리마다 둥근 녹색 화면(꺼짐 — '시험 연기 공지'의 잔상만 희미하게) + 의자 등받이."""
    im = img(64, 46)
    d = ImageDraw.Draw(im)
    box3(d, 1, 16, 62, 34, 6, WOOD)                                      # 책상
    for x in (1, 31, 61):                                                  # 칸막이
        d.rectangle([x, 4, x + 2, 22], fill=C("P12")); d.line([x, 4, x, 22], fill=C("P13"))
    for x in (6, 36):                                                      # 단말(진공관 크림 상자 + 녹색 화면)
        box3(d, x, 6, x + 20, 20, 3, CREAM)
        d.rounded_rectangle([x + 3, 9, x + 17, 18], 3, fill=C("P02"))
        d.line([x + 5, 12, x + 13, 12], fill=C("P55")); d.line([x + 5, 14, x + 10, 14], fill=C("P55"))   # 잔상
        d.point((x + 18, 19), fill=C("P05"))
    for x in (10, 40):                                                     # 의자 등받이(앞)
        d.rectangle([x, 34, x + 12, 44], fill=C("P11")); d.line([x, 34, x + 12, 34], fill=C("P13"))
        d.rectangle([x + 2, 36, x + 10, 39], fill=C("P46"))
    return im


def grader():
    """전산 모의고사 채점기(1×1): 놋쇠 투입구 + 진공관 창 + 천공 카드 받이 — 마지막 장이 반쯤 걸려 있다."""
    im = img(32, 46)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 38, 30, 45], fill=C("P02"))
    box3(d, 3, 8, 28, 40, 5, CREAM)
    d.rectangle([7, 4, 24, 9], fill=C("P48")); d.line([7, 4, 24, 4], fill=C("P50")); d.line([9, 7, 22, 7], fill=C(INK))   # 투입구
    d.rectangle([9, 17, 22, 25], fill=C("P02"))                            # 진공관 창
    for x in (11, 15, 19):
        d.rectangle([x, 19, x + 2, 24], fill=C("P59")); d.point((x + 1, 19), fill=C("P60"))
    d.rectangle([6, 29, 25, 32], fill=C("P05"))                            # 카드 받이
    d.polygon([(10, 29), (21, 29), (19, 35), (12, 35)], fill=C("P21"))     # 걸린 카드
    for x in (13, 15, 17):
        d.point((x, 31), fill=C("P18"))
    return im


def tutor_bot():
    """과외-3 조교 로봇(SJ-H71, 1×1 · 비전투): 세진 크림 원통 몸 + 칠판 지시봉 팔 + 머리 대신 작은 녹색 화면('3번'). 바퀴는 책상 다리에 묶였다."""
    im = img(32, 52)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 44, 28, 51], fill=C("P02"))
    d.rounded_rectangle([7, 18, 25, 46], 5, fill=C(INK))                   # 몸(외곽)
    d.rounded_rectangle([8, 19, 24, 45], 4, fill=C("P08"))
    d.rectangle([8, 32, 24, 35], fill=C("P61")); d.line([8, 32, 24, 32], fill=C("P62"))   # 청록 띠
    d.rectangle([9, 38, 23, 45], fill=C("P07"))
    d.ellipse([12, 42, 20, 50], fill=C(INK)); d.ellipse([13, 43, 19, 49], fill=C("P05"))  # 외바퀴
    d.line([12, 48, 7, 51], fill=C("P20")); d.line([20, 48, 25, 51], fill=C("P20"))     # 묶은 끈
    d.rounded_rectangle([6, 3, 26, 19], 3, fill=C(INK))                    # 화면 머리
    d.rounded_rectangle([7, 4, 25, 18], 3, fill=C("P07"))
    d.rectangle([9, 6, 23, 16], fill=C("P02"))
    put_text(im, "3번", 11, 6, "P56", size=8)
    d.line([24, 24, 30, 12], fill=C(INK), width=2); d.line([24, 24, 30, 12], fill=C("P12"))   # 지시봉 팔
    d.point((30, 11), fill=C("P53"))
    return im


# ================================================================================================ 병원
def hosp_bed(tag=True):
    """병상(1×2): 철제 난간 침대 + 얇은 매트 + 구겨진 모포. 머리맡 이름표(빈칸)와 '대기 구역' 판독 스티커(붉은 띠)."""
    im = img(34, 66)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 32, 8], fill=C("P12")); d.line([1, 2, 32, 2], fill=C("P14"))   # 머리 난간
    for x in (6, 11, 16, 21, 26):
        d.line([x, 3, x, 8], fill=C("P11"))
    d.rectangle([2, 8, 31, 61], fill=C("P11"))                             # 틀
    d.rectangle([3, 9, 30, 58], fill=C("P08"))                             # 시트(빛바랜 흰색)
    d.line([4, 10, 4, 57], fill=C("P09"))
    d.rounded_rectangle([6, 11, 27, 18], 3, fill=C("P09")); d.line([8, 17, 25, 17], fill=C("P07"))   # 베개
    d.polygon([(3, 31), (30, 27), (30, 58), (3, 58)], fill=C("P12"))       # 구겨진 청회 모포
    d.polygon([(3, 31), (30, 27), (30, 30), (3, 34)], fill=C("P13"))       # 접힌 단
    d.line([9, 45, 20, 43], fill=C("P11"))
    for x in (2, 30):                                                      # 옆 난간
        d.line([x, 20, x, 56], fill=C("P13"))
    if tag:
        d.rectangle([22, 3, 30, 7], fill=C("P09")); d.line([23, 5, 28, 5], fill=C("P06"))   # 이름표(빈칸)
        d.rectangle([3, 3, 10, 7], fill=C("P53")); d.line([4, 5, 9, 5], fill=C("P09"))      # 판독 스티커
    d.rectangle([3, 61, 6, 65], fill=C("P10")); d.rectangle([27, 61, 30, 65], fill=C("P10"))   # 바퀴 다리
    d.ellipse([2, 62, 7, 66], fill=C(INK)); d.ellipse([26, 62, 31, 66], fill=C(INK))
    return im


def w_whiteboard():
    """병동 화이트보드(벽, 2칸): 은색 테 + '병상 가동률 312%' + 손글씨 근무표 · 붉은 자석 셋."""
    im = img(60, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 59, 31], fill=C("P12")); d.rectangle([2, 2, 57, 29], fill=C("P09"))
    d.line([2, 2, 57, 2], fill=C("P15"))
    put_text(im, "병상 312%", 5, 4, "P52", size=8)
    for y in (17, 21, 25):
        d.line([5, y, 5 + (40 if y != 25 else 26), y], fill=C("P45"))
    for x in (44, 49, 54):
        d.ellipse([x - 2, 14, x + 2, 18], fill=C("P53"))
    d.rectangle([4, 29, 55, 31], fill=C("P11"))                            # 펜 받침
    d.line([10, 29, 18, 29], fill=C("P46")); d.line([22, 29, 28, 29], fill=C("P52"))
    return im


# ================================================================================================ 수산시장
def freezer_unit():
    """원자력 냉동고(2×2, 가동): 두꺼운 크림 철문 + 김 서린 손잡이 + 지붕 위 냉각 핀 · 문 옆 각성회 대기등 램프(녹색) 하나 · 노란 방사능 표지."""
    im = img(64, 84)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 74, 62, 83], fill=C("P02"))
    box3(d, 3, 10, 60, 78, 10, CREAM)
    for x in range(8, 58, 6):                                              # 냉각 핀
        d.rectangle([x, 2, x + 3, 12], fill=C("P12")); d.line([x, 2, x + 3, 2], fill=C("P14"))
    d.rectangle([12, 26, 50, 74], fill=C("P07")); d.rectangle([12, 26, 50, 28], fill=C("P09"))   # 문
    d.line([31, 26, 31, 74], fill=C("P06"))
    d.rectangle([24, 44, 27, 58], fill=C("P12")); d.rectangle([35, 44, 38, 58], fill=C("P12"))   # 손잡이
    for (x, y) in ((22, 40), (40, 41), (26, 38), (37, 37)):               # 김
        d.point((x, y), fill=C("P09"))
    d.polygon([(52, 30), (58, 30), (55, 25)], fill=C("P49")); d.point((55, 28), fill=C(INK))   # 방사능 표지
    d.line([57, 36, 57, 44], fill=C("P05"))                                # 대기등 줄
    d.ellipse([54, 44, 60, 50], fill=C("P55")); d.point((56, 46), fill=C("P57"))
    for y in (62, 66, 70):                                                 # 서리
        d.point((14, y), fill=C("P15")); d.point((48, y - 2), fill=C("P15"))
    return im


def fish_tub():
    """생선 함지(1×1): 고무 함지에 흙탕물 + 가물치 등지느러미 · 메기 수염 · 참게 한 마리가 테두리를 기어오른다."""
    im = img(32, 30)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 20, 31, 29], fill=C("P02"))
    d.ellipse([2, 8, 30, 26], fill=C("P51"))                               # 붉은 고무 함지
    d.ellipse([2, 6, 30, 22], fill=C("P52"))
    d.ellipse([5, 8, 27, 20], fill=C("P34"))                               # 흙탕물
    d.ellipse([7, 10, 25, 18], fill=C("P35"))
    d.polygon([(9, 13), (19, 11), (21, 14), (11, 15)], fill=C("P29"))      # 가물치 등
    for x in (12, 15, 18):
        d.point((x, 12), fill=C("P28"))
    d.line([20, 16, 24, 18], fill=C("P05")); d.line([20, 16, 23, 15], fill=C("P05"))   # 메기 수염
    d.ellipse([24, 6, 30, 11], fill=C("P25")); d.point((26, 7), fill=C(INK)); d.point((28, 7), fill=C(INK))   # 참게
    d.line([24, 9, 22, 8], fill=C("P24")); d.line([30, 9, 31, 7], fill=C("P24"))
    return im


# ================================================================================================ 국립묘지
def gravestone(seed=0):
    """이름 없는 비석(1×1): 회색 화강암 판 + 둥근 머리 · 글자 자리는 비바람에 다 지워졌다 · 밑동에 이끼와 마른 풀."""
    rnd = random.Random(seed)
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 32, 28, 39], fill=C("P02"))
    d.rectangle([7, 30, 25, 36], fill=C("P05")); d.line([7, 30, 25, 30], fill=C("P06"))   # 받침
    d.rounded_rectangle([9, 6, 23, 32], 6, fill=C(INK))
    d.rounded_rectangle([10, 7, 22, 31], 5, fill=C("P07"))
    d.rectangle([10, 18, 22, 31], fill=C("P06"))
    d.line([11, 9, 11, 29], fill=C("P08"))
    for y in (14, 18, 22):                                                 # 지워진 글자 자국
        d.line([13 + rnd.randint(0, 1), y, 19 - rnd.randint(0, 2), y], fill=C("P05"))
    for x in (8, 11, 21, 24):
        d.point((x, 33 + rnd.randint(0, 1)), fill=C("P31"))
    d.point((rnd.randint(11, 20), rnd.randint(24, 29)), fill=C("P30"))
    return im


def memorial_base():
    """빈 기념탑 받침(2×2): 3단 화강암 기단, 위는 비었다(탑이 있던 자리에 녹슨 볼트 넷) · 앞면 동판은 뜯겨 나간 네모 자국만."""
    im = img(64, 70)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 60, 63, 69], fill=C("P02"))
    box3(d, 2, 40, 61, 64, 6, STONE)
    box3(d, 8, 26, 55, 46, 6, STONE)
    box3(d, 15, 12, 48, 32, 6, ["P05", "P06", "P07", "P08"])
    for (x, y) in ((20, 14), (43, 14), (20, 17), (43, 17)):               # 볼트 자리
        d.point((x, y), fill=C("P25")); d.point((x + 1, y), fill=C("P24"))
    d.rectangle([22, 36, 41, 44], fill=C("P05")); d.rectangle([23, 37, 40, 43], outline=C("P04"))   # 뜯긴 동판 자국
    d.line([24, 43, 30, 37], fill=C("P26"))                                # 녹물
    return im


def morgue_shelf():
    """안치소 선반(2×1): 쇠 선반 두 단에 귀환 유해 상자(국방색 나무 상자) · 상자마다 흰 꼬리표 '인수자 미정' · 위에 마른 꽃 한 송이씩."""
    im = img(64, 54)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 46, 62, 53], fill=C("P02"))
    for x in (2, 60):
        d.rectangle([x, 4, x + 2, 50], fill=C("P11"))
    for y in (20, 44):
        d.rectangle([2, y, 62, y + 2], fill=C("P12")); d.line([2, y, 62, y], fill=C("P13"))
    for row, y in enumerate((8, 32)):
        for i, x in enumerate((6, 24, 42)):
            box3(d, x, y, x + 15, y + 12, 3, ["P28", "P29", "P30", "P31"])
            d.rectangle([x + 4, y + 6, x + 10, y + 10], fill=C("P09"))     # 꼬리표
            d.line([x + 5, y + 8, x + 9, y + 8], fill=C("P06"))
            d.line([x + 7, y + 6, x + 8, y + 3], fill=C("P06"))            # 꼬리표 끈
            fx = x + 3 + (i * 5 + row * 3) % 9                             # 마른 꽃
            d.line([fx, y - 1, fx + 4, y + 1], fill=C("P19"))
            d.point((fx, y - 2), fill=C("P26")); d.point((fx + 1, y - 2), fill=C("P22"))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


def blackboard_hw():
    """학원 칠판(벽, 4칸): 볼트 칠판과 같은 그림, 분필 글씨만 '수능 D-26 / 대피 적성 D-3'(붉은 분필)."""
    import tiles_s07 as S
    return S.blackboard("수능 D-26", "대피 적성 D-3", "P54")


def blackboard_k01():
    """연수원 대강의실 칠판(벽, 4칸): '관제망 운영 개론 / 3주차'(K-01 조사 글과 같은 글씨)."""
    import tiles_s07 as S
    return S.blackboard("관제망 운영 개론", "3주차 — 생체 판독")


PROPS_R01N = {
    "blackboard_hw": _r(blackboard_hw, 4, 0, "wall", dy=6),
    "blackboard_k01": _r(blackboard_k01, 4, 0, "wall", dy=6),
    "study_carrel": _r(study_carrel, 2, 1),
    "grader": _r(grader, 1, 1),
    "tutor_bot": _r(tutor_bot, 1, 1),
    "hosp_bed": _r(hosp_bed, 1, 2),
    "hosp_bed_x": _r(lambda: hosp_bed(False), 1, 2),
    "w_whiteboard": _r(w_whiteboard, 2, 0, "wall", dx=2, dy=1),
    "freezer_unit": _r(freezer_unit, 2, 2),
    "fish_tub": _r(fish_tub, 1, 1),
    "gravestone": _r(lambda: gravestone(1), 1, 1),
    "gravestone2": _r(lambda: gravestone(7), 1, 1),
    "memorial_base": _r(memorial_base, 2, 2),
    "morgue_shelf": _r(morgue_shelf, 2, 1),
}
STATES_R01N = {}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/r01n.png"
    ims = [(k, v["fn"]()) for k, v in PROPS_R01N.items()]
    W = sum(i.width for _, i in ims) + 8 * len(ims)
    H = max(i.height for _, i in ims) + 8
    sheet = Image.new("RGBA", (W, H), (70, 74, 66, 255))
    x = 4
    for _, i in ims:
        sheet.alpha_composite(i, (x, H - 4 - i.height))
        x += i.width + 8
    ok = P.allowed_set("UI")
    bad = {px[:3] for _, i in ims for px in i.get_flattened_data() if px[3] and tuple(px[:3]) not in ok}
    print("팔레트 밖 색:", bad or "없음")
    sheet.resize((W * 3, H * 3), Image.NEAREST).save(out)
