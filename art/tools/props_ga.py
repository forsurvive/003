"""가산 아울렛 거리 소품(단계 1-D6, 1-D 계획 §12.5 · §12.6 · SD-09a L-R01-28 · SD-16 아이작풍).
  마네킹은 주인공과 같은 2등신 렌더러(chibi)로 뽑는다 — 같은 비율 · 같은 민방위 방독면(HD19). 피부만 플라스틱 색, 발밑에 받침대.
  그래서 방독면을 쓰고 줄 칸에 멈춰 선 주인공이 그림으로도 마네킹 사이에 섞인다(계획 §12.5 '눈을 속인다').
    mann_ga         마네킹(1×1): 방독면 · 헐렁한 평상복 · 받침대 / 상태 tag(번호표 목걸이 — 새벽인력 우세) · target(가슴 과녁 — 약탈자 우세)
                    · fallen(넘어짐 — 정리 뒤)
    mann_ga2        마네킹(1×1): 방독면 · 조끼 차림(여자 몸) — 줄을 섞는다 / 상태 같음
    window_ga       진열창(3×1): 유리 틀 · 단 · 마네킹 셋 · '전시 특가 — 방호 우비 2+1' 띠 / 상태 tag · target · fallen · decoy(가운데가 볼트 작업복)
                    · decoy_tag · decoy_target · decoy_fallen
    rack_ga         옷 행거(2×1): 철제 봉 · 옷걸이에 걸린 평상복(색 섞임) · 가격표
    raincoat_ga     전시 특가 진열대(2×1): 개켜 쌓은 노란 방호 우비 · 손글씨 '2+1' · 방독면 견본
    curtain_ga      탈의실 커튼(덧그림 — 칸을 막지 않음): 반쯤 걷힌 천 커튼 · 봉 고리
    escalator_ga    멈춘 에스컬레이터(2×3 덮개 — 밟고 오른다): 고무 손잡이 · 계단 판 · 먼지 · 끝에 '운행 중지' 줄
    w_board_ga      단가 칠판(벽 2칸): '고철 kg 2 · 옷 벌 5 / S-07 작업복 3,000 — 생포만'
    w_sign_ladder   옥외 간판 사다리 창(벽 2칸): 깨진 유리창 밖으로 간판 철골 · 사다리 손잡이(2층 출구)
    crate_police_ga 경찰 납품 상자(1×1): 녹색 철제 함 · '경찰' 스텐실 · 송장 · 자물쇠
    crate_suit_ga   작업복 상자(1×1): 못 박은 나무 상자 · 꼬리표 '새벽인력 인솔조 — 목요일 수거' · 개킨 작업복
                    / 상태 burnt(검게 탄 · 재) · swapped(뚜껑 틈으로 노란 우비) · empty(뚜껑 열린 빈 상자)
    returns_ga      반품 더미(2×1): 찌그러진 택배 상자 · 비닐 · 삐져나온 옷 · '반품' 딱지
    rat_nest_ga     왕쥐 둥지(2×1): 찢은 옷감 · 솜 · 뜯긴 마네킹 팔 하나 · 뼈
    mann_pile_ga    마네킹 무더기(2×1): 팔다리 · 머리가 엉킨 더미 · 방독면 하나가 굴러 나옴
    ledger_ga       재고 장부(덧그림 — 두목 책상 위 · 발 없음): 펼친 장부 · '마네킹 312' 동그라미
    w_window_ga_out 바깥 진열 유리(덧그림 96×64, 1-12n D-233): 철틀 유리 · 어둠 속 마네킹 셋(안 진열창과 같은 상태) · 반사 사선
    w_shutter_dock  하역장 셔터(덧그림 64×64, 1-12n 뒷문): 골함석 롤 셔터 · '인력 →' / 상태 open · holes(총알구멍 · '인부 사절')
    cart_ga         하역장 손수레(1×1) / 상태 blood(뒤집힘 · 핏자국)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01). 위에서 빛(위 밝게 · 아래 어둡게), 반투명 없음."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import chibi as K
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
WOOD = ("P16", "P17", "P18", "P19", "P20")
STEEL = ("P03", "P04", "P05", "P06", "P07")
PLASTIC = ("P05", "P06", "P07", "P08", "P09")          # 마네킹 살: 바랜 회백 플라스틱


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _box(d, x0, y0, x1, y1, ramp, top=True):
    d.rectangle([x0, y0, x1, y1], fill=C(INK))
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=C(ramp[1]))
    if top:
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=C(ramp[-1]))
    d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=C(ramp[0]))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        if x % 2 == 0:
            d.point((x, y), fill=C("P02"))


# ================================================================================================ 마네킹
_FIG = {}


def _figure(body="M1", torso="T03", suit=False):
    """2등신 몸(40×48, 발 (20, 46)): 주인공 렌더러 그대로 · 방독면 HD19 · 피부를 플라스틱으로 바꾼다."""
    key = (body, torso, suit)
    if key in _FIG:
        return _FIG[key].copy()
    look = K.Look(body=body, skin="S1", hair="HR00", color="H1", torso="T01" if suit else torso, gear="HD19")
    im = K.actor(look, "S", "idle", 0).convert("RGBA")
    skin = [tuple(c) for c in K.skin_ramp("S1")]
    plast = [C(t) for t in PLASTIC]
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            c = px[x, y]
            if c[3] and tuple(c) in skin:
                px[x, y] = plast[skin.index(tuple(c))]
    _FIG[key] = im
    return im.copy()


def _stand(d, cx, foot_y):
    """받침대: 발 사이 쇠막대 · 둥근 받침(앞이 밝다)."""
    d.ellipse([cx - 7, foot_y - 1, cx + 7, foot_y + 4], fill=C(INK))
    d.ellipse([cx - 6, foot_y, cx + 6, foot_y + 3], fill=C(STEEL[2]))
    d.line([cx - 5, foot_y + 1, cx + 4, foot_y + 1], fill=C(STEEL[4]))
    d.line([cx, foot_y - 6, cx, foot_y], fill=C(STEEL[1]))


def _tag(d, cx, y, no):
    """번호표 목걸이: 끈 V · 흰 판 · 숫자(새벽인력 인력 번호)."""
    d.line([cx - 4, y - 5, cx, y], fill=C("P02")); d.line([cx + 4, y - 5, cx, y], fill=C("P02"))
    d.rectangle([cx - 4, y, cx + 4, y + 6], fill=C(INK)); d.rectangle([cx - 3, y + 1, cx + 3, y + 5], fill=C("P09"))
    for i, ch in enumerate(str(no)[:2]):
        x = cx - 2 + i * 3
        d.line([x, y + 2, x, y + 4], fill=C("P53"))
        if ch in "2357":
            d.point((x + 1, y + 2), fill=C("P53"))


def _target(d, cx, y):
    """가슴 과녁: 붉은 · 흰 동그라미 셋(스프레이) · 총알구멍 둘."""
    for r, c in ((5, "P53"), (3, "P09"), (1, "P53")):
        d.ellipse([cx - r, y - r, cx + r, y + r], fill=C(c))
    d.point((cx - 3, y + 1), fill=C(INK)); d.point((cx + 2, y - 2), fill=C(INK))


def mann(body="M1", torso="T03", state="", suit=False, no=17):
    """마네킹(1×1, 40×56): 받침대 위 2등신 플라스틱 몸 · 방독면."""
    im = img(40, 56)
    d = ImageDraw.Draw(im)
    if state == "fallen":                                                  # 넘어짐: 몸을 옆으로 눕히고 받침대는 따로 구른다
        fig = _figure(body, torso, suit).rotate(90, expand=True)
        _shadow(d, 2, 38, 54)
        im.alpha_composite(fig.crop((0, 0, 48, 40)).resize((48, 40)), (-6, 18))
        d.ellipse([28, 49, 38, 53], fill=C(INK)); d.ellipse([29, 50, 37, 52], fill=C(STEEL[2]))
        return im
    _shadow(d, 10, 31, 54)
    _stand(d, 20, 50)
    im.alpha_composite(_figure(body, torso, suit), (0, 3))
    d = ImageDraw.Draw(im)
    if state == "tag":
        _tag(d, 20, 33, no)
    elif state == "target":
        _target(d, 20, 37)
    return im


# ================================================================================================ 진열창
def window_ga(state=""):
    """진열창(3×1, 96×72): 나무 단 · 유리 틀 · 마네킹 셋 · 위 띠 '전시 특가 — 방호 우비 2+1'."""
    im = img(96, 72)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 94, 70)
    _box(d, 1, 54, 94, 68, WOOD)                                           # 단
    d.line([3, 60, 92, 60], fill=C(WOOD[1]))
    decoy = state.startswith("decoy")
    taken = state.startswith("taken")                                      # 미끼 다음 날: 패거리가 가운데 마네킹을 끌고 올라갔다 — 받침대만
    base = state.split("_", 1)[1] if (decoy or taken) and "_" in state else ("" if (decoy or taken) else state)
    for i, (body, torso, no) in enumerate((("M1", "T03", 41), ("F1", "T12", 42), ("M1", "T11", 43))):
        if taken and i == 1:
            dd = ImageDraw.Draw(im)
            _stand(dd, i * 30 - 2 + 20, 54)
            dd.line([i * 30 + 12, 58, i * 30 + 30, 66], fill=C(WOOD[0]))      # 끌고 간 자국
            continue
        suit = decoy and i == 1                                            # 미끼: 가운데가 볼트 작업복을 입고 서 있다(넘어진 줄 사이에서도)
        m = mann(body, torso, "" if suit else base, suit=suit, no=no)
        im.alpha_composite(m, (i * 30 - 2, 4))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 5], fill=C(INK)); d.rectangle([1, 1, 94, 4], fill=C("P53"))   # 붉은 특가 띠
    put_text(im, "특가 · 방호 우비 2+1", 14, -1, "P09", 8, "Galmuri7")
    for x in (0, 95):                                                      # 유리 틀(세로 기둥) · 깨진 유리 결
        d.line([x, 5, x, 56], fill=C(STEEL[1]))
    rnd = random.Random(7)
    for _ in range(5):
        x, y = rnd.randint(6, 90), rnd.randint(10, 48)
        d.line([x, y, x + rnd.randint(-5, 5), y + rnd.randint(3, 8)], fill=C("P14"))
    if decoy:
        put_text(im, "S-07", 38, 57, "P49", 8, "Galmuri7")
    return im


# ================================================================================================ 바깥(월드 외벽 — 1-12n D-233 · D-231)
def w_window_ga_out(state=""):
    """A관 정문 옆 바깥 진열 유리(덧그림 96×64 — 외벽 아랫단, 지나가며 본다): 골함석 벽에 뚫은 철틀 유리 · 안쪽 어둠 · 마네킹 셋(안 진열창과 같은 상태) ·
    유리 반사 사선 · 위 붉은 특가 띠. 반투명 없이 — 유리는 반사 줄과 틀로만."""
    im = img(96, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 63], fill=C(INK))
    d.rectangle([2, 8, 93, 61], fill=C("P02"))                                # 안쪽 어둠(매장)
    for x in range(4, 92, 6):                                                # 안쪽 행거 그림자(어둠 속 줄)
        d.line([x, 12, x, 16], fill=C("P03"))
    d.line([2, 11, 93, 11], fill=C("P03"))
    decoy = state.startswith("decoy")
    taken = state.startswith("taken")
    base = state.split("_", 1)[1] if (decoy or taken) and "_" in state else ("" if (decoy or taken) else state)
    for i, (body, torso, no) in enumerate((("M1", "T03", 41), ("F1", "T12", 42), ("M1", "T11", 43))):
        cx = 16 + i * 32
        if taken and i == 1:
            _stand(d, cx, 58)
            continue
        suit = decoy and i == 1
        m = mann(body, torso, "" if suit else base, suit=suit, no=no)
        im.alpha_composite(m.crop((0, 0, 40, 55)), (cx - 20, 6))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 7], fill=C(INK)); d.rectangle([1, 1, 94, 6], fill=C("P53"))   # 특가 띠
    put_text(im, "특가 · 방호 우비 2+1", 16, 0, "P09", 8, "Galmuri7")
    for x in (0, 1, 31, 32, 63, 64, 94, 95):                                 # 철틀(세 칸)
        d.line([x, 8, x, 63], fill=C(STEEL[1] if x % 2 == 0 else STEEL[3]))
    d.line([0, 62, 95, 62], fill=C(STEEL[3])); d.line([0, 63, 95, 63], fill=C(STEEL[1]))
    for x0 in (6, 40, 72):                                                   # 유리 반사(사선 두 줄 — 칸마다)
        d.line([x0, 52, x0 + 14, 18], fill=C("P08")); d.line([x0 + 4, 52, x0 + 18, 18], fill=C("P06"))
    rnd = random.Random(11)
    for _ in range(4):                                                       # 금 간 유리
        x, y = rnd.randint(8, 88), rnd.randint(14, 50)
        d.line([x, y, x + rnd.randint(-6, 6), y + rnd.randint(4, 9)], fill=C("P14"))
    return im


def w_shutter_dock(state=""):
    """하역장 셔터(벽 소품 64×64 — A관 앞면 정문 오른쪽 두 칸, 1-12n 뒷문): 골함석 롤 셔터 · 아래 반 뼘 들림 · 분필 화살표 '인력 →' ·
    상태 open(말려 올라감 — 안쪽 어둠 · 컨베이어 끝) · holes(총알구멍 · 핏자국 줄 · 스프레이 '인부 사절' — 패거리가 친 다음 날)."""
    im = img(64, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 63], fill=C(INK))
    d.rectangle([2, 2, 61, 5], fill=C(STEEL[2])); d.line([2, 2, 61, 2], fill=C(STEEL[4]))   # 셔터 통(위)
    if state == "open":
        d.rectangle([4, 6, 59, 61], fill=C("P02"))
        d.rectangle([4, 6, 59, 12], fill=C(STEEL[1]))                          # 말려 올라간 셔터 끝
        for y in (8, 10):
            d.line([4, y, 59, y], fill=C(STEEL[3]))
        d.rectangle([14, 44, 49, 50], fill=C("P03")); d.line([14, 44, 49, 44], fill=C("P05"))   # 안쪽 컨베이어 끝
        for x in range(16, 48, 6):
            d.ellipse([x, 49, x + 3, 52], fill=C(INK))
    else:
        for y in range(6, 58, 3):                                             # 골함석 판
            d.line([4, y, 59, y], fill=C(STEEL[3] if (y // 3) % 2 else STEEL[2]))
            d.line([4, y + 1, 59, y + 1], fill=C(STEEL[1]))
        d.rectangle([4, 58, 59, 61], fill=C("P02"))                           # 아래 반 뼘 들림
        for x in (10, 30, 48):
            d.point((x, 59), fill=C("P04"))
        for (x, y, c) in ((8, 14, "P24"), (40, 30, "P24"), (22, 47, "P25"), (51, 19, "P24")):   # 녹
            d.line([x, y, x + 3, y + 4], fill=C(c))
        put_text(im, "인력 →", 18, 22, "P09", 8, "Galmuri7")
        if state == "holes":
            for (x, y) in ((14, 20), (19, 27), (33, 18), (41, 33), (47, 24), (25, 38)):
                d.point((x, y), fill=C(INK)); d.point((x + 1, y), fill=C("P09"))
            d.line([28, 40, 27, 57], fill=C("P52")); d.line([29, 42, 29, 56], fill=C("P51"))   # 셔터를 타고 흐른 자국
            put_text(im, "인부 사절", 14, 44, "P54", 8, "Galmuri7")
    for x in (0, 1, 62, 63):
        d.line([x, 0, x, 63], fill=C(STEEL[1]))
    return im


def cart_ga(state=""):
    """하역장 손수레(1×1): 철판 바닥 · 손잡이 · 바퀴 둘 / 상태 blood(뒤집혀 핏자국 — 패거리가 하역장을 친 다음 날)."""
    im = img(40, 48)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 36, 46)
    if state == "blood":
        d.polygon([(4, 30), (30, 22), (36, 34), (10, 42)], fill=C(INK))
        d.polygon([(6, 31), (29, 24), (34, 33), (11, 40)], fill=C(STEEL[2]))
        d.ellipse([28, 36, 36, 44], fill=C(INK)); d.ellipse([30, 38, 34, 42], fill=C(STEEL[1]))
        for (x, y) in ((14, 33), (18, 35), (22, 31), (9, 44), (16, 45)):
            d.point((x, y), fill=C("P52"))
        d.line([6, 44, 20, 46], fill=C("P51"))
        return im
    d.rectangle([6, 22, 34, 38], fill=C(INK)); d.rectangle([7, 23, 33, 37], fill=C(STEEL[2]))
    d.line([7, 23, 33, 23], fill=C(STEEL[4]))
    d.line([33, 22, 38, 8], fill=C(INK), width=2); d.line([33, 22, 38, 8], fill=C(STEEL[3]))
    for x in (9, 27):
        d.ellipse([x, 36, x + 7, 43], fill=C(INK)); d.ellipse([x + 2, 38, x + 5, 41], fill=C(STEEL[1]))
    return im


# ================================================================================================ 매장 · 창고 소품
def rack_ga():
    """옷 행거(2×1, 64×56): 철제 봉과 다리 · 옷걸이 여덟에 걸린 평상복(색 섞임) · 가격표 하나."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    _shadow(d, 3, 61, 54)
    for x in (4, 59):
        d.line([x, 12, x, 52], fill=C(INK)); d.line([x + 1, 12, x + 1, 52], fill=C(STEEL[3]))
        d.line([x - 3, 52, x + 4, 52], fill=C(INK))
    d.line([4, 12, 60, 12], fill=C(INK)); d.line([4, 13, 60, 13], fill=C(STEEL[4]))
    rnd = random.Random(11)
    cols = (("P43", "P45"), ("P16", "P18"), ("P28", "P30"), ("P53", "P54"), ("P06", "P08"), ("P58", "P60"), ("P33", "P35"), ("P24", "P26"))
    for i, (a, b) in enumerate(cols):
        x = 8 + i * 6
        d.line([x, 13, x + 2, 16], fill=C(STEEL[2]))                       # 옷걸이
        h = rnd.randint(22, 30)
        d.rectangle([x - 1, 16, x + 5, 16 + h], fill=C(INK))
        d.rectangle([x, 17, x + 4, 15 + h], fill=C(b))
        d.line([x, 17, x, 15 + h], fill=C(a))
    d.rectangle([52, 30, 57, 35], fill=C(INK)); d.rectangle([53, 31, 56, 34], fill=C("P09"))   # 가격표
    return im


def raincoat_ga():
    """전시 특가 진열대(2×1, 64×44): 낮은 매대 · 개켜 쌓은 노란 우비 셋 · '2+1' 손글씨 판 · 방독면 견본 하나."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 42)
    _box(d, 2, 22, 61, 40, WOOD)
    for i in range(3):
        x = 6 + i * 13
        for k in range(3):
            y = 18 - k * 3
            d.rectangle([x, y, x + 11, y + 3], fill=C(INK)); d.rectangle([x + 1, y + 1, x + 10, y + 2], fill=C(("P48", "P49", "P50")[k]))
    d.rectangle([46, 6, 59, 18], fill=C(INK)); d.rectangle([47, 7, 58, 17], fill=C("P09"))
    put_text(im, "2+1", 47, 7, "P53", 8, "Galmuri7")
    d.ellipse([46, 19, 55, 26], fill=C(INK)); d.ellipse([47, 20, 54, 25], fill=C("P02"))   # 방독면 견본
    d.point((49, 22), fill=C("P11")); d.point((52, 22), fill=C("P11"))
    return im


def curtain_ga():
    """탈의실 커튼(덧그림 32×48 — 칸을 막지 않음): 위 봉 · 고리 · 한쪽으로 걷힌 천 주름(바랜 자주)."""
    im = img(32, 48)
    d = ImageDraw.Draw(im)
    d.line([1, 2, 30, 2], fill=C(INK)); d.line([1, 3, 30, 3], fill=C(STEEL[4]))
    for i, x in enumerate((2, 6, 10)):
        d.ellipse([x, 2, x + 2, 4], outline=C(STEEL[2]))
        d.rectangle([x, 4, x + 4, 44 - i], fill=C(INK))
        d.rectangle([x + 1, 4, x + 3, 43 - i], fill=C(("P34", "P33", "P35")[i]))
        d.line([x + 1, 4, x + 1, 43 - i], fill=C("P36"))
    return im


def escalator_ga():
    """멈춘 에스컬레이터(2×3, 64×104): 검은 고무 손잡이 둘 · 금속 계단 판(위로 갈수록 좁게) · 먼지 · 끝 '운행 중지' 줄."""
    im = img(64, 104)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 60, 102)
    d.polygon([(10, 4), (54, 4), (60, 100), (4, 100)], fill=C(INK))
    d.polygon([(12, 6), (52, 6), (57, 98), (7, 98)], fill=C(STEEL[2]))
    for k in range(13):
        y = 10 + k * 7
        w = 18 + k * 1.6
        d.line([32 - w, y, 32 + w, y], fill=C(STEEL[4]))
        d.line([32 - w, y + 1, 32 + w, y + 1], fill=C(STEEL[0]))
        if k % 3 == 1:
            d.point((32 + (k * 7) % 20 - 10, y + 3), fill=C("P07"))           # 먼지
    for side in (-1, 1):                                                   # 손잡이
        d.line([32 + side * 22, 2, 32 + side * 30, 100], fill=C(INK), width=4)
        d.line([32 + side * 22, 2, 32 + side * 30, 100], fill=C("P02"), width=2)
    d.line([6, 92, 58, 92], fill=C("P49"), width=2)                         # 운행 중지 줄
    put_text(im, "운행 중지", 16, 85, "P53", 8, "Galmuri7")
    return im


def w_board_ga(state=""):
    """단가 칠판(벽 2칸, 64×40): 나무 테 · 검은 판 · 분필 '고철 kg2 옷 벌5' · 붉은 'S-07 3,000 생포만'.
    crossed: 미끼 다음 날 — '3,000'에 분필 줄 두 번 · 그 위에 흰 분필 '마네킹'."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    _box(d, 1, 2, 62, 37, WOOD)
    d.rectangle([4, 5, 59, 34], fill=C("P10"))
    put_text(im, "고철kg 2  옷벌 5", 6, 5, "P08", 8, "Galmuri7")
    put_text(im, "S-07 3,000", 6, 15, "P53", 8, "Galmuri7")
    put_text(im, "생포만!", 6, 24, "P53", 8, "Galmuri7")
    d.line([40, 30, 56, 30], fill=C("P08"))
    if state == "crossed":
        d = ImageDraw.Draw(im)
        d.line([24, 19, 52, 18], fill=C("P09")); d.line([24, 21, 52, 20], fill=C("P09"))
        put_text(im, "마네킹", 34, 23, "P09", 8, "Galmuri7")
    return im


def mann_tied(state=""):
    """묶인 마네킹(1×1, 40×56): 받침대 없이 기둥에 밧줄로 묶임 · 볼트 작업복(미끼) — bare는 작업복을 벗긴 뒤 플라스틱 몸."""
    im = img(40, 56)
    d = ImageDraw.Draw(im)
    _shadow(d, 8, 33, 54)
    d.rectangle([18, 2, 22, 53], fill=C(WOOD[0])); d.line([19, 3, 19, 52], fill=C(WOOD[2]))   # 기둥
    im.alpha_composite(_figure("F1", "T12", state != "bare"), (0, 5))
    d = ImageDraw.Draw(im)
    for y in (27, 36, 44):                                                 # 밧줄 세 바퀴
        d.line([9, y, 31, y + 1], fill=C("P02")); d.line([9, y + 1, 31, y + 2], fill=C("P01"))
    return im


def w_sign_ladder():
    """옥외 간판 사다리 창(벽 2칸, 64×48): 깨진 창틀 · 밖의 하늘 · 간판 철골과 사다리 손잡이."""
    im = img(64, 48)
    d = ImageDraw.Draw(im)
    _box(d, 2, 4, 61, 44, STEEL)
    d.rectangle([6, 8, 57, 40], fill=C("P41"))                              # 밖(흐린 하늘)
    d.rectangle([6, 30, 57, 40], fill=C("P40"))
    for x in (22, 38):                                                     # 사다리 기둥 · 가로대
        d.line([x, 8, x, 40], fill=C(INK), width=2)
    for y in range(12, 40, 6):
        d.line([22, y, 38, y], fill=C(STEEL[3]))
    d.rectangle([8, 10, 18, 18], fill=C("P53")); put_text(im, "아", 9, 9, "P09", 8, "Galmuri7")   # 간판 글자 조각
    rnd = random.Random(3)
    for _ in range(4):
        x, y = rnd.randint(8, 54), rnd.randint(9, 36)
        d.line([x, y, x + rnd.randint(-4, 4), y + rnd.randint(2, 6)], fill=C("P14"))
    return im


def crate_police_ga():
    """경찰 납품 상자(1×1, 32×40): 녹색 철제 함 · 흰 '경찰' 스텐실 · 옆 송장 · 맹꽁이 자물쇠."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 30, 38)
    _box(d, 2, 12, 29, 36, ("P28", "P29", "P30", "P31"))
    d.line([2, 18, 29, 18], fill=C(INK))
    put_text(im, "경찰", 8, 20, "P09", 8, "Galmuri7")
    d.rectangle([22, 24, 27, 30], fill=C(INK)); d.rectangle([23, 25, 26, 29], fill=C("P09"))   # 송장
    d.rectangle([13, 14, 18, 18], fill=C(INK)); d.point((15, 16), fill=C("P48"))
    return im


def crate_suit_ga(state=""):
    """작업복 상자(1×1, 32×40): 못 박은 나무 상자 · 꼬리표 · 위로 개킨 작업복(카키)."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 30, 38)
    if state == "burnt":
        _box(d, 3, 18, 28, 36, ("P01", "P02", "P03", "P04"))
        for x in range(5, 27, 3):
            d.line([x, 18, x + 1, 14 + (x % 4)], fill=C("P02"))
        d.point((10, 15), fill=C("P54")); d.point((20, 16), fill=C("P53"))   # 남은 불씨
        for x in range(4, 28, 2):
            d.point((x, 37), fill=C("P05"))                                  # 재
        return im
    _box(d, 3, 14, 28, 36, WOOD)
    d.line([3, 25, 28, 25], fill=C(WOOD[1]))
    for (x, y) in ((5, 16), (26, 16), (5, 34), (26, 34)):
        d.point((x, y), fill=C("P07"))
    if state == "empty":
        d.rectangle([4, 10, 27, 14], fill=C(INK)); d.rectangle([5, 11, 26, 13], fill=C(WOOD[3]))   # 열린 뚜껑
        d.rectangle([5, 15, 26, 17], fill=C("P01"))
    else:
        cloth = ("P48", "P49", "P50") if state == "swapped" else ("P28", "P29", "P30")
        for k in range(3):
            d.rectangle([5, 9 + k * 2, 26, 11 + k * 2], fill=C(INK)); d.rectangle([6, 10 + k * 2, 25, 10 + k * 2], fill=C(cloth[k]))
    d.line([22, 22, 26, 28], fill=C("P02")); d.rectangle([24, 27, 30, 33], fill=C(INK)); d.rectangle([25, 28, 29, 32], fill=C("P09"))   # 꼬리표
    return im


def returns_ga():
    """반품 더미(2×1, 64×44): 찌그러진 택배 상자 넷 · 찢긴 비닐 · 삐져나온 옷 소매 · '반품' 딱지."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 42)
    for (x0, y0, x1, y1) in ((4, 24, 26, 40), (22, 18, 44, 40), (40, 26, 60, 40), (12, 10, 32, 26)):
        d.polygon([(x0, y0 + 2), (x1 - 2, y0), (x1, y1), (x0 + 1, y1)], fill=C(INK))
        d.polygon([(x0 + 1, y0 + 3), (x1 - 3, y0 + 1), (x1 - 1, y1 - 1), (x0 + 2, y1 - 1)], fill=C(WOOD[3]))
        d.line([x0 + 2, y0 + 3, x1 - 3, y0 + 1], fill=C(WOOD[4]))
    d.rectangle([24, 22, 34, 28], fill=C("P53")); put_text(im, "반품", 24, 20, "P09", 8, "Galmuri7")
    d.line([44, 28, 52, 22], fill=C("P45"), width=2)                       # 소매
    d.polygon([(6, 20), (12, 16), (14, 24)], fill=C("P08"))                 # 비닐
    return im


def rat_nest_ga():
    """왕쥐 둥지(2×1, 64×36): 찢은 옷감 · 솜 더미 · 뜯긴 마네킹 팔 하나 · 뼈 조각."""
    im = img(64, 36)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 60, 34)
    rnd = random.Random(23)
    for _ in range(60):
        x, y = rnd.randint(6, 58), rnd.randint(14, 32)
        c = rnd.choice(("P45", "P16", "P28", "P53", "P08", "P33"))
        d.line([x, y, x + rnd.randint(1, 4), y + rnd.randint(-1, 1)], fill=C(c))
    d.ellipse([22, 16, 42, 30], fill=C("P02"))                               # 가운데 움푹한 자리
    d.line([46, 14, 58, 22], fill=C(INK), width=4); d.line([46, 14, 58, 22], fill=C(PLASTIC[3]), width=2)   # 마네킹 팔
    d.line([10, 28, 16, 26], fill=C("P09"))                                 # 뼈
    return im


def mann_pile_ga():
    """마네킹 무더기(2×1, 64×44): 엉킨 팔다리 · 머리 둘 · 방독면 하나가 굴러 나옴."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 3, 61, 42)
    rnd = random.Random(5)
    for _ in range(9):
        x, y = rnd.randint(6, 52), rnd.randint(18, 34)
        a = rnd.randint(-8, 8)
        d.line([x, y, x + 10, y + a // 2], fill=C(INK), width=4)
        d.line([x, y, x + 10, y + a // 2], fill=C(PLASTIC[rnd.randint(1, 3)]), width=2)
    for (x, y) in ((14, 14), (36, 18)):
        d.ellipse([x, y, x + 12, y + 11], fill=C(INK)); d.ellipse([x + 1, y + 1, x + 11, y + 10], fill=C(PLASTIC[3]))
        d.point((x + 3, y + 3), fill=C(PLASTIC[4]))
    d.ellipse([50, 30, 60, 39], fill=C(INK)); d.ellipse([51, 31, 59, 38], fill=C("P02"))   # 굴러 나온 방독면
    d.point((53, 34), fill=C("P11")); d.point((57, 34), fill=C("P11"))
    return im


def ledger_ga():
    """재고 장부(덧그림 32×24): 펼친 장부 · 줄 · 붉은 동그라미 '312'."""
    im = img(32, 24)
    d = ImageDraw.Draw(im)
    d.polygon([(3, 6), (16, 4), (29, 6), (29, 20), (16, 18), (3, 20)], fill=C(INK))
    d.polygon([(4, 7), (15, 5), (15, 17), (4, 19)], fill=C("P08"))
    d.polygon([(17, 5), (28, 7), (28, 19), (17, 17)], fill=C("P09"))
    for y in range(9, 18, 2):
        d.line([6, y, 13, y - 1], fill=C("P06"))
    put_text(im, "312", 18, 7, "P53", 8, "Galmuri7")
    d.ellipse([17, 8, 28, 16], outline=C("P53"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


_MSTATES = ("tag", "target", "fallen")
_WSTATES = ("tag", "target", "fallen", "decoy", "decoy_tag", "decoy_target", "decoy_fallen", "taken", "taken_tag", "taken_target", "taken_fallen")
PROPS_GA = {
    "mann_ga": _r(lambda: mann("M1", "T03"), 1, 1, down=-2),
    "mann_ga2": _r(lambda: mann("F1", "T12"), 1, 1, down=-2),
    "window_ga": _r(window_ga, 3, 1, down=-2),
    "rack_ga": _r(rack_ga, 2, 1, down=-2),
    "raincoat_ga": _r(raincoat_ga, 2, 1, down=-2),
    "curtain_ga": _r(curtain_ga, 1, 1, "deco", down=0),          # 칸을 막지 않는 덮개(탈의실 칸 안에 설 수 있다)
    "escalator_ga": _r(escalator_ga, 2, 3, "deco", down=0),      # 밟고 오르는 덮개 — 1층과 2층을 잇는 바닥 통로 위에 깐다
    "w_board_ga": _r(lambda: w_board_ga(), 2, 0, "wall", dx=0, dy=6),
    "w_sign_ladder": _r(w_sign_ladder, 2, 0, "wall", dx=0, dy=2),
    "crate_police_ga": _r(crate_police_ga, 1, 1, down=-2),
    "crate_suit_ga": _r(crate_suit_ga, 1, 1, down=-2),
    "returns_ga": _r(returns_ga, 2, 1, down=-2),
    "rat_nest_ga": _r(rat_nest_ga, 2, 1, down=-2),
    "mann_pile_ga": _r(mann_pile_ga, 2, 1, down=-2),
    "ledger_ga": _r(ledger_ga, 0, 0, "deco"),
    "mann_tied": _r(mann_tied, 1, 1, down=-2),
    "w_window_ga_out": _r(w_window_ga_out, 0, 0, "deco"),                     # 1-12n D-233 바깥 진열 유리(외벽 아랫단 덧그림 — 월드 스팟)
    "w_shutter_dock": dict(_r(w_shutter_dock, 0, 0, "deco"), nudge=16),                       # 1-12n 하역장 셔터(뒷문 — 월드 스팟)
    "cart_ga": _r(cart_ga, 1, 1, down=-2),
}
STATES_GA = {
    "mann_ga": {s: (lambda s=s: mann("M1", "T03", s, no=17)) for s in _MSTATES},
    "mann_ga2": {s: (lambda s=s: mann("F1", "T12", s, no=29)) for s in _MSTATES},
    "window_ga": {s: (lambda s=s: window_ga(s)) for s in _WSTATES},
    "w_window_ga_out": {s: (lambda s=s: w_window_ga_out(s)) for s in _WSTATES},
    "w_shutter_dock": {"open": lambda: w_shutter_dock("open"), "holes": lambda: w_shutter_dock("holes")},
    "cart_ga": {"blood": lambda: cart_ga("blood")},
    "crate_suit_ga": {s: (lambda s=s: crate_suit_ga(s)) for s in ("burnt", "swapped", "empty")},
    "w_board_ga": {"crossed": lambda: w_board_ga("crossed")},
    "mann_tied": {"bare": lambda: mann_tied("bare")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_GA.values()] + [fn() for st in STATES_GA.values() for fn in st.values()]
    cols = 6
    cw, ch = 100, 110
    sheet = Image.new("RGBA", (cols * cw, ((len(ims) + cols - 1) // cols) * ch), (70, 66, 72, 255))
    for i, im in enumerate(ims):
        sheet.alpha_composite(im, ((i % cols) * cw + 2, (i // cols) * ch + 2))
    sheet = sheet.resize((sheet.size[0] * 2, sheet.size[1] * 2), Image.NEAREST)
    sheet.save(out)
