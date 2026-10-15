"""새벽인력 본소 창고동 소품(단계 1-3, SD-09a L-R02-19 H-03 '인력' 우리 · SD-16 §7·§8 아이작풍): 옛 공구상가 철골동을 고친 억류 창고.
철근을 용접한 우리 벽(앞쪽 줄 · 옆 칸막이 기둥) · 자물쇠 걸린 우리 문(닫힘 / 열림) · 바닥의 골판지와 담요 깔개 · 물 양동이 · 번호표 판 ·
쇠사슬 말뚝 · 작업등 · 앉아 있는 '인력'(번호표를 목에 건 억류자, 무릎을 끌어안음) · 감시 의자와 공구 상자 · 벽의 출근부 · 근태 목걸이 걸이.
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01). 벽 소품(kind wall)은 벽면 윗칸(y=1)에 건다.
"""
import os, sys, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import chibi as K

T = 32
C = lambda t: P.rgb(t) + (255,)
INK = "P01"
STEEL = ["P10", "P11", "P12", "P13", "P14"]
RUST = ["P23", "P24", "P25", "P26"]


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _bar(d, x, y0, y1, rust_at=None):
    """철근 한 줄(3px: 그늘·몸·빛) + 녹 자국"""
    d.line([x, y0, x, y1], fill=C("P11"))
    d.line([x + 1, y0, x + 1, y1], fill=C("P13"))
    d.point((x + 1, y0), fill=C("P15"))
    if rust_at is not None:
        d.line([x, rust_at, x + 1, rust_at + 3], fill=C("P25"))
        d.point((x + 1, rust_at + 4), fill=C("P24"))


def cage_front(seed=0, door=False, open_=False):
    """우리 앞벽(1×1, 높이 44px): 위·아래 가로대 + 철근 5줄. door면 문틀 + 걸쇠 + 맹꽁이자물쇠, open이면 문이 옆으로 젖혀 있다."""
    im = img(32, 46)
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    top, bot = 4, 43
    # 아래 가로대 그림자
    d.rectangle([0, bot + 1, 31, bot + 2], fill=C("P02") + (0,) if False else C("P02"))
    if open_:
        for x in (0, 29):                                             # 문틀 기둥만 남고 문짝은 옆으로
            _bar(d, x, top, bot)
        d.rectangle([0, top - 2, 31, top], fill=C("P11")); d.line([0, top - 2, 31, top - 2], fill=C("P14"))
        # 젖힌 문짝(비스듬히 보이는 얇은 판): 오른쪽 기둥에 붙어 앞으로 열림
        for k in range(4):
            x = 24 + k
            _bar(d, x, top + 3 + k, bot - 2 + k // 2)
        d.line([24, top + 6, 28, top + 9], fill=C("P14"))
        d.line([24, bot - 6, 28, bot - 3], fill=C("P12"))
        return im
    d.rectangle([0, top - 2, 31, top], fill=C("P11")); d.line([0, top - 2, 31, top - 2], fill=C("P14"))
    d.rectangle([0, bot - 2, 31, bot], fill=C("P11")); d.line([0, bot - 2, 31, bot - 2], fill=C("P13"))
    d.line([0, (top + bot) // 2, 31, (top + bot) // 2], fill=C("P12"))
    for i, x in enumerate((1, 7, 13, 19, 25, 30) if not door else (1, 30)):
        _bar(d, min(x, 30), top, bot, rnd.choice([None, None, rnd.randint(top + 6, bot - 10)]))
    if door:                                                          # 문짝: 테 + 안쪽 철근 넷 + 걸쇠 + 자물쇠
        d.rectangle([4, top + 1, 27, bot - 1], outline=C("P10"))
        d.rectangle([5, top + 2, 26, bot - 2], outline=C("P13"))
        for x in (9, 14, 19, 24):
            _bar(d, x, top + 3, bot - 3)
        d.rectangle([25, 21, 30, 24], fill=C("P11")); d.line([25, 21, 30, 21], fill=C("P14"))   # 걸쇠
        d.rectangle([26, 25, 30, 30], fill=C("P48")); d.rectangle([27, 23, 29, 25], outline=C("P47"))   # 놋쇠 맹꽁이자물쇠
        d.point((28, 27), fill=C("P01")); d.point((27, 26), fill=C("P50"))
    return im


def cage_post():
    """우리 칸막이(1×1, 옆에서 본 철근 벽): 굵은 기둥 앞뒤 + 가로대 셋 — 위에서 보면 칸 사이의 좁은 줄"""
    im = img(32, 46)
    d = ImageDraw.Draw(im)
    for x in (13, 17):
        _bar(d, x, 2, 43)
    for y in (6, 22, 38):
        d.line([12, y, 19, y], fill=C("P12")); d.point((19, y), fill=C("P14"))
    d.rectangle([12, 43, 19, 44], fill=C("P02"))
    return im


def straw_mat(seed=0):
    """깔개(장식, 막지 않음): 펼친 골판지 + 구겨진 군용 담요"""
    im = img(30, 18)
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    d.rectangle([1, 2, 28, 15], fill=C("P19")); d.rectangle([1, 2, 28, 15], outline=C("P17"))
    for x in range(4, 28, 6):
        d.line([x, 3, x, 14], fill=C("P18"))
    d.polygon([(6, 4), (24, 3), (27, 12), (9, 15)], fill=C("P30"))
    d.line([6, 4, 24, 3], fill=C("P31")); d.line([9, 15, 27, 12], fill=C("P29"))
    for k in range(3):
        x = rnd.randint(10, 22)
        d.line([x, 6, x + 2, 12], fill=C("P29"))
    return im


def bucket():
    """물 양동이(1×1): 찌그러진 함석 + 손잡이 + 물그림자"""
    im = img(20, 22)
    d = ImageDraw.Draw(im)
    d.polygon([(3, 6), (16, 6), (14, 20), (5, 20)], fill=C("P13"))
    d.line([3, 6, 5, 20], fill=C("P11")); d.line([16, 6, 14, 20], fill=C("P12"))
    d.ellipse([3, 3, 16, 9], fill=C("P12")); d.ellipse([5, 4, 14, 8], fill=C("P35"))
    d.point((7, 5), fill=C("P37"))
    d.arc([3, -3, 16, 9], 180, 360, fill=C("P11"))
    d.line([8, 12, 9, 16], fill=C("P14"))
    return im


def chain_post():
    """쇠사슬 말뚝(1×1): 바닥에 박은 고리 + 늘어진 사슬"""
    im = img(26, 20)
    d = ImageDraw.Draw(im)
    d.ellipse([9, 12, 16, 18], fill=C("P11")); d.ellipse([11, 13, 14, 16], fill=C("P02"))
    for i, (x, y) in enumerate(((16, 14), (19, 13), (21, 15), (23, 17))):
        d.ellipse([x - 1, y - 1, x + 1, y + 1], outline=C("P13" if i % 2 else "P12"))
    return im


def work_lamp():
    """천장에서 늘어진 작업등(1×1, 장식 위층): 갓 + 전구의 노란 빛 — 바닥에 둥근 빛"""
    im = img(30, 40)
    d = ImageDraw.Draw(im)
    d.line([15, 0, 15, 12], fill=C("P02"))
    d.polygon([(9, 14), (21, 14), (24, 20), (6, 20)], fill=C("P12"))
    d.line([9, 14, 21, 14], fill=C("P14")); d.line([6, 20, 24, 20], fill=C("P10"))
    d.ellipse([12, 18, 18, 23], fill=C("P50")); d.point((14, 19), fill=C("P09"))
    return im


def guard_chair():
    """감시 의자(1×1): 쇠 접이의자 + 걸쳐 둔 진압봉"""
    im = img(24, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([5, 4, 18, 14], fill=C("P12")); d.rectangle([5, 4, 18, 14], outline=C("P10"))
    d.line([6, 6, 17, 6], fill=C("P14"))
    d.rectangle([4, 15, 19, 19], fill=C("P13")); d.line([4, 15, 19, 15], fill=C("P14"))
    for x in (5, 18):
        d.line([x, 19, x, 28], fill=C("P11"))
    d.line([6, 20, 17, 27], fill=C("P11")); d.line([17, 20, 6, 27], fill=C("P11"))
    d.line([2, 10, 12, 24], fill=C("P02")); d.line([3, 10, 13, 24], fill=C("P04"))   # 진압봉
    return im


def tool_chest():
    """빨간 공구 상자(1×1): 옛 공구상가의 남은 물건 — 서랍 셋"""
    im = img(30, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 8, 27, 28], fill=C("P53")); d.rectangle([2, 4, 27, 8], fill=C("P54"))
    d.rectangle([2, 4, 27, 28], outline=C("P52"))
    for y in (12, 18, 24):
        d.line([4, y, 25, y], fill=C("P52")); d.line([12, y + 2, 17, y + 2], fill=C("P14"))
    d.point((24, 6), fill=C("P09"))
    return im


def detainee(look_code, seed=0, tag="127"):
    """앉아 있는 '인력'(1×1): 아이작풍 2등신 머리 + 웅크린 몸(무릎을 끌어안음) + 가슴에 건 번호표.
    chibi.body·head를 잘라 쓴다 — 서 있는 시트와 같은 머리·옷 색. 다리를 접은 만큼(5px) 낮게 앉는다."""
    lk = K.Look.parse(look_code)
    b, (hx, hy) = K.body(lk, "S", "idle", 0)
    h = K.head(lk, "S", "idle")
    o = K.outfit(lk)
    legl = K.BODY.get(lk.body, K.BODY["M1"])[2]
    hip = 30 - legl                                                   # 몸 칸 안 엉덩이 줄
    ox, oy = 4, 14 + 5
    im = img(40, oy + hip + 10)
    im.alpha_composite(b.crop((0, 0, 32, hip + 1)), (ox, oy))
    d = ImageDraw.Draw(im)
    pants = o["pants"]
    ky = oy + hip - 1                                                 # 무릎(엉덩이 앞으로 접힘)
    d.ellipse([ox + 7, ky, ox + 14, ky + 6], fill=pants[1]); d.ellipse([ox + 17, ky, ox + 24, ky + 6], fill=pants[1])
    d.arc([ox + 7, ky, ox + 14, ky + 6], 200, 320, fill=pants[2]); d.arc([ox + 17, ky, ox + 24, ky + 6], 200, 320, fill=pants[2])
    bc = o["boots"][1]
    d.rectangle([ox + 8, ky + 6, ox + 12, ky + 7], fill=bc); d.rectangle([ox + 19, ky + 6, ox + 23, ky + 7], fill=bc)
    sk = K.skin_ramp(lk.skin)
    d.rectangle([ox + 9, ky + 1, ox + 22, ky + 2], fill=sk[2])         # 무릎 위에 모은 팔
    d.line([ox + 9, ky + 3, ox + 22, ky + 3], fill=sk[1])
    cy = oy + hip - 6                                                 # 가슴: 번호표(흰 천 + 끈)
    d.rectangle([ox + 13, cy, ox + 18, cy + 3], fill=C("P09")); d.rectangle([ox + 13, cy, ox + 18, cy + 3], outline=C("P05"))
    d.line([ox + 14, cy + 2, ox + 17, cy + 2], fill=C("P04"))
    im.alpha_composite(h, (ox + hx - K.HC, oy + hy - 22))
    return K.outline(im)


def w_roster():
    """벽 출근부(2칸, 벽 소품): 판자에 붙인 '인력' 번호 명단 + 빨간 줄(빠진 번호)"""
    im = img(54, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 53, 29], fill=C("P18")); d.rectangle([0, 0, 53, 29], outline=C("P16"))
    d.rectangle([3, 3, 50, 26], fill=C("P08"))
    for i, y in enumerate(range(6, 25, 3)):
        d.line([6, y, 18, y], fill=C("P04")); d.line([22, y, 34 + (i % 3) * 4, y], fill=C("P05"))
        if i in (2, 5):
            d.line([5, y, 46, y], fill=C("P53"))
    d.rectangle([42, 4, 49, 9], fill=C("P53")); d.point((45, 6), fill=C("P09"))
    return im


def w_collars():
    """근태 목걸이 걸이(1칸, 벽 소품): 쇠 고리에 걸린 목걸이 셋 — 붉은 표시등과 철사 묶음"""
    im = img(30, 26)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 28, 4], fill=C("P11")); d.line([1, 2, 28, 2], fill=C("P14"))
    for x in (6, 15, 24):
        d.line([x, 4, x, 7], fill=C("P12"))
        d.ellipse([x - 4, 7, x + 4, 19], outline=C("P12"))
        d.rectangle([x - 2, 16, x + 2, 21], fill=C("P11")); d.point((x, 18), fill=C("P54"))
        d.line([x - 2, 21, x - 3, 24], fill=C("P26"))
    return im


def w_stencil(text="인력"):
    """벽 페인트 글자(1~2칸): 흰 스텐실 '인력' + 흘러내린 자국"""
    from struct_r01 import put_text
    im = img(42, 20)
    put_text(im, text, 3, 3, "P08")
    d = ImageDraw.Draw(im)
    for x in (8, 21, 33):
        d.line([x, 15, x, 18], fill=C("P07"))
    return im


# ================================================================================================ 1-6 본소 마당·본동(SD-09a L-R02-19 ②③⑨)
def _font_text(im, s, x, y, col, size=8, name="Galmuri7"):
    from struct_r01 import put_text
    return put_text(im, s, x, y, col, size, name)


def price_board():
    """'오늘의 인력 단가' 칠판(2×1, 세움): 각목 다리 + 녹색 칠판 + 분필 줄(맨 아랫줄만 붉은 분필) + 위 판자 머리글."""
    im = img(64, 60)
    d = ImageDraw.Draw(im)
    for x in (6, 55):                                                 # 다리(각목) + 가로대
        d.rectangle([x, 34, x + 3, 58], fill=C("P18")); d.line([x, 34, x, 58], fill=C("P19")); d.line([x + 3, 34, x + 3, 58], fill=C(INK))
    d.line([8, 52, 57, 52], fill=C("P17"))
    d.rectangle([1, 2, 62, 42], fill=C(INK))                          # 틀
    d.rectangle([2, 3, 61, 41], fill=C("P19")); d.line([2, 3, 61, 3], fill=C("P20"))
    d.rectangle([4, 10, 59, 39], fill=C("P34"))                       # 칠판
    d.line([4, 10, 59, 10], fill=C("P33"))
    rnd = random.Random(7)
    for i, y in enumerate(range(14, 36, 4)):                          # 분필 줄: 이름(짧은 획) … 값(숫자 덩어리)
        col = "P54" if y >= 34 else "P15"
        x = 7
        while x < 34:
            w_ = rnd.randint(2, 4)
            d.line([x, y, x + w_, y], fill=C(col)); x += w_ + rnd.randint(1, 2)
            if rnd.random() < 0.3:
                d.point((x, y - 1), fill=C(col))
        d.line([38, y, 40, y], fill=C("P14"))                          # 점선
        d.line([44, y, 55, y], fill=C(col)); d.point((45, y - 1), fill=C(col)); d.point((52, y - 1), fill=C(col))
    for _ in range(18):                                               # 지운 자국(흐린 분필)
        d.point((rnd.randint(5, 58), rnd.randint(11, 38)), fill=C("P35"))
    d.rectangle([4, 39, 59, 40], fill=C("P18"))                       # 분필 받침
    d.point((12, 39), fill=C("P09")); d.point((14, 39), fill=C("P54"))
    _font_text(im, "인력 단가", 14, 2, "P08", 8)
    return im


def auction_stage():
    """경매대(3×2): 팔레트를 겹쳐 쌓은 단 + 철판 연단(번호 원판) + 손종 + 번호판 장대."""
    im = img(96, 76)
    d = ImageDraw.Draw(im)
    for k in range(2):                                                # 팔레트 두 겹(옆면 널 줄)
        y0 = 40 + k * 10
        d.rectangle([2, y0, 93, y0 + 9], fill=C("P19" if k == 0 else "P18"))
        for x in range(4, 92, 12):
            d.rectangle([x, y0 + 3, x + 7, y0 + 6], fill=C("P02"))    # 팔레트 구멍
        d.line([2, y0, 93, y0], fill=C("P20")); d.line([2, y0 + 9, 93, y0 + 9], fill=C(INK))
    d.rectangle([2, 26, 93, 40], fill=C("P20"))                       # 윗면(널)
    for x in range(2, 94, 7):
        d.line([x, 26, x, 40], fill=C("P19"))
    d.line([2, 26, 93, 26], fill=C("P21"))
    d.rectangle([1, 25, 94, 60], outline=C(INK))
    d.rectangle([60, 8, 82, 36], fill=C(INK))                         # 철판 연단
    d.rectangle([61, 9, 81, 35], fill=C("P12")); d.line([61, 9, 81, 9], fill=C("P14"))
    d.ellipse([65, 16, 77, 28], fill=C("P09")); d.ellipse([65, 16, 77, 28], outline=C("P53"))
    _font_text(im, "7", 69, 17, "P53")
    d.rectangle([58, 6, 84, 9], fill=C("P11")); d.line([58, 6, 84, 6], fill=C("P13"))
    d.ellipse([86, 10, 92, 18], fill=C("P48")); d.line([89, 6, 89, 10], fill=C("P47"))   # 손종
    d.point((88, 12), fill=C("P50"))
    d.rectangle([12, 0, 14, 40], fill=C("P05")); d.line([12, 0, 12, 40], fill=C("P07"))   # 번호판 장대
    for i, y in enumerate(range(3, 25, 7)):                            # 걸린 번호판(흰 판 + 숫자 획)
        d.rectangle([15, y, 27, y + 5], fill=C("P08")); d.rectangle([15, y, 27, y + 5], outline=C("P04"))
        d.line([18, y + 2, 24, y + 2], fill=C("P53" if i == 1 else "P02"))
    return im


def queue_rail(seed=0):
    """번호표 줄 난간(2×1): 쇠파이프 기둥 셋 + 가로 파이프 둘(녹) — 줄 선 자리 바닥이 반들반들."""
    im = img(64, 30)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 20, 60, 29], fill=C("P06"))                         # 닳은 바닥(반들)
    for x in (4, 30, 57):
        d.rectangle([x, 4, x + 2, 25], fill=C("P05")); d.line([x, 4, x, 25], fill=C("P07")); d.line([x + 2, 4, x + 2, 25], fill=C(INK))
        d.rectangle([x - 1, 24, x + 3, 26], fill=C("P04"))
    for y in (6, 14):
        d.line([4, y, 59, y], fill=C("P06")); d.line([4, y + 1, 59, y + 1], fill=C(INK))
    rnd = random.Random(seed)
    for _ in range(6):
        d.point((rnd.randint(6, 57), rnd.choice((6, 14))), fill=C(rnd.choice(RUST)))
    return im


def dog_run():
    """경비견 우리(2×1): 철망 울(격자) + 지붕 함석 + 밥통(찌그러진 대야) + 사슬 — 개는 따로(적)."""
    im = img(64, 50)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 61, 10], fill=C("P06")); d.line([2, 4, 61, 4], fill=C("P08")); d.line([2, 11, 61, 11], fill=C(INK))   # 함석 지붕
    for x in range(4, 61, 4):
        d.line([x, 5, x, 10], fill=C("P05"))
    d.rectangle([3, 12, 60, 46], fill=C("P02"))                       # 안(그늘)
    d.rectangle([3, 34, 60, 46], fill=C("P17"))                       # 짚 바닥
    for x in range(5, 59, 3):
        d.point((x, 36 + (x * 7) % 8), fill=C("P20"))
    for x in range(3, 61, 4):                                         # 철망
        d.line([x, 12, x, 46], fill=C("P12"))
    for y in range(14, 46, 4):
        d.line([3, y, 60, y], fill=C("P11"))
    for x in (2, 31, 60):
        d.rectangle([x - 1, 10, x + 1, 48], fill=C("P05")); d.line([x - 1, 10, x - 1, 48], fill=C("P07"))
    d.ellipse([40, 40, 52, 47], fill=C("P13")); d.ellipse([42, 41, 50, 45], fill=C("P18"))   # 밥통
    d.line([10, 44, 20, 40], fill=C("P13")); d.line([20, 40, 26, 42], fill=C("P12"))           # 사슬
    d.line([2, 48, 61, 48], fill=C(INK))
    return im


def safe_big(open_=False):
    """소장실 금고(1×1, 세움): 검은 철 + 다이얼 + 손잡이 바퀴 + 놋쇠 명판 '근면'. 열리면 문이 옆으로, 안에 장부 칸."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 29, 42], fill=C(INK))
    d.rectangle([3, 5, 28, 41], fill=C("P03"))
    d.line([3, 5, 28, 5], fill=C("P05")); d.line([3, 5, 3, 41], fill=C("P04"))
    if open_:
        d.rectangle([6, 9, 25, 37], fill=C("P01"))
        d.line([6, 22, 25, 22], fill=C("P04"))                         # 칸막이
        d.rectangle([9, 15, 21, 21], fill=C("P02"))                    # 빈 장부 자리(먼지 테)
        d.rectangle([9, 15, 21, 21], outline=C("P04"))
        d.rectangle([8, 28, 14, 36], fill=C("P48")); d.line([8, 28, 14, 28], fill=C("P49"))   # 남은 캡 자루
        d.rectangle([26, 7, 31, 40], fill=C("P04")); d.line([31, 7, 31, 40], fill=C(INK))     # 젖힌 문 두께
        return im
    d.rectangle([6, 9, 25, 37], outline=C("P02"))
    d.ellipse([9, 14, 19, 24], fill=C("P05")); d.ellipse([9, 14, 19, 24], outline=C(INK))
    d.ellipse([12, 17, 16, 21], fill=C("P07")); d.point((14, 15), fill=C("P09"))
    for k in range(8):                                                # 다이얼 눈금
        import math as _m
        a = k * _m.pi / 4
        d.point((14 + int(round(_m.cos(a) * 4)), 19 + int(round(_m.sin(a) * 4))), fill=C("P08"))
    d.line([21, 17, 21, 27], fill=C("P06")); d.line([19, 22, 23, 22], fill=C("P06"))   # 손잡이 바퀴
    d.rectangle([9, 30, 22, 34], fill=C("P48")); d.line([9, 30, 22, 30], fill=C("P49"))  # 명판
    d.line([11, 32, 20, 32], fill=C("P47"))
    d.rectangle([2, 42, 29, 43], fill=C("P02"))
    return im


def collar_bench():
    """근태 목걸이 조립대(2×1): 철 작업대 + 반쯤 조립한 목걸이 셋(붉은 표시등·뇌관 통) + 철사 뭉치 + 납땜인두 + 바이스."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 14, 61, 20], fill=C("P12")); d.line([2, 14, 61, 14], fill=C("P14")); d.line([2, 21, 61, 21], fill=C(INK))
    for x in (4, 57):
        d.rectangle([x, 21, x + 3, 38], fill=C("P11")); d.line([x + 3, 21, x + 3, 38], fill=C(INK))
    d.rectangle([7, 30, 56, 32], fill=C("P11"))                       # 아래 선반
    d.rectangle([12, 25, 24, 30], fill=C("P53")); d.line([12, 25, 24, 25], fill=C("P54"))   # 뇌관 통(붉은 상자)
    for i, x in enumerate((9, 25, 41)):                               # 목걸이(고리 + 상자 + 표시등)
        d.ellipse([x, 4, x + 13, 15], outline=C("P11"))
        d.rectangle([x + 3, 10, x + 10, 15], fill=C("P10")); d.point((x + 6, 12), fill=C("P54" if i != 1 else "P02"))
        if i == 1:
            d.line([x + 4, 12, x + 12, 9], fill=C("P26")); d.line([x + 5, 13, x + 13, 11], fill=C("P46"))   # 풀린 전선
    d.ellipse([52, 8, 60, 14], outline=C("P26")); d.ellipse([53, 9, 59, 13], outline=C("P25"))   # 철사 뭉치
    d.line([5, 11, 9, 13], fill=C("P05")); d.point((4, 10), fill=C("P54"))                       # 납땜인두
    return im


def ledger_shelf():
    """출근부 선반(2×1, 세움): 200년 치 장부 — 아래 칸일수록 오래돼 누렇다. 맨 아래 2108년 장부 등에 '근면' 스티커."""
    im = img(64, 54)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 62, 52], fill=C(INK))
    d.rectangle([2, 3, 61, 51], fill=C("P18"))
    rnd = random.Random(21)
    for r, y in enumerate((5, 17, 29, 41)):
        x = 4
        while x < 59:
            bw = rnd.randint(3, 5)
            age = ["P13", "P45", "P26", "P20"][r] if rnd.random() < 0.7 else ["P05", "P44", "P25", "P21"][r]
            hgt = rnd.randint(8, 10)
            d.rectangle([x, y + 10 - hgt, x + bw - 1, y + 10], fill=C(age))
            d.line([x, y + 10 - hgt, x, y + 10], fill=C("P%02d" % min(63, int(age[1:]) + 1)))
            d.point((x + 1, y + 10 - hgt + 2), fill=C("P08"))
            x += bw
        d.rectangle([2, y + 11, 61, y + 12], fill=C("P17"))
    d.rectangle([6, 43, 11, 46], fill=C("P49")); d.point((8, 44), fill=C("P53"))   # '근면' 스티커(노랑 + 붉은 점)
    return im


def w_wanted():
    """수배 전단(벽 소품 1칸): 누런 종이 + 볼트 작업복 차림 대충 그린 얼굴 + '생포' 붉은 도장 + 3,000."""
    im = img(26, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 24, 28], fill=C("P21")); d.rectangle([1, 1, 24, 28], outline=C("P19"))
    d.polygon([(24, 1), (24, 5), (20, 1)], fill=C("P02"))             # 찢긴 귀퉁이
    d.ellipse([8, 5, 17, 14], outline=C("P02")); d.point((11, 9), fill=C("P02")); d.point((14, 9), fill=C("P02"))
    d.rectangle([7, 14, 18, 19], fill=C("P45")); d.line([12, 14, 12, 19], fill=C("P49"))   # 파란 작업복 + 노란 줄
    d.rectangle([4, 21, 21, 26], outline=C("P53")); d.line([6, 23, 19, 23], fill=C("P53"))
    return im


def w_punch():
    """출근 기록계(벽 소품 1칸): 둥근 시계 + 카드 꽂이(번호 카드 줄줄이)."""
    im = img(28, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 1, 23, 14], fill=C("P12")); d.rectangle([4, 1, 23, 14], outline=C(INK))
    d.ellipse([9, 3, 18, 12], fill=C("P09")); d.line([13, 7, 13, 4], fill=C(INK)); d.line([13, 7, 16, 8], fill=C(INK))
    d.rectangle([2, 16, 25, 29], fill=C("P05")); d.rectangle([2, 16, 25, 29], outline=C(INK))
    for x in range(4, 24, 3):
        d.rectangle([x, 17, x + 1, 24], fill=C("P08")); d.point((x, 19), fill=C("P53"))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


DETAINEES = [("M2-S4-HR02-H1-T16-2-PF05-HD00-EY00", "a"), ("F1-S2-HR03-H2-T16-1-PF05-HD00-EY00", "b"),
             ("M1-S3-HR05-H4-T16-2-PF05-HD00-EY00", "c"), ("E1-S4-HR01-H5-T16-2-PF05-HD00-EY00", "d")]

PROPS_SB = {
    "cage_front": _r(lambda: cage_front(1), 1, 1, down=-2),
    "cage_front2": _r(lambda: cage_front(2), 1, 1, down=-2),
    "cage_door": _r(lambda: cage_front(3, door=True), 1, 1, down=-2),
    "cage_post": _r(cage_post, 1, 1, down=-2),
    "straw_mat": _r(lambda: straw_mat(1), 0, 0, "deco"),
    "straw_mat2": _r(lambda: straw_mat(2), 0, 0, "deco"),
    "bucket": _r(bucket, 1, 1, down=-2),
    "chain_post": _r(chain_post, 0, 0, "deco"),
    "work_lamp": _r(work_lamp, 0, 0, "deco"),
    "guard_chair": _r(guard_chair, 1, 1, down=-2),
    "tool_chest": _r(tool_chest, 1, 1, down=-2),
    "w_roster": _r(w_roster, 2, 0, "wall", dx=5, dy=4),
    "w_collars": _r(w_collars, 1, 0, "wall", dx=1, dy=6),
    "w_stencil": _r(w_stencil, 2, 0, "wall", dx=11, dy=10),
    # 1-6 본소 마당·본동
    "price_board": _r(price_board, 2, 1, down=-2),
    "auction_stage": _r(auction_stage, 3, 2, down=-2),
    "queue_rail": _r(lambda: queue_rail(1), 2, 1, down=-2),
    "dog_run": _r(dog_run, 2, 1, down=-2),
    "safe_big": _r(safe_big, 1, 1, down=-2),
    "collar_bench": _r(collar_bench, 2, 1, down=-2),
    "ledger_shelf": _r(ledger_shelf, 2, 1, down=-2),
    "w_wanted": _r(w_wanted, 1, 0, "wall", dx=3, dy=2),
    "w_punch": _r(w_punch, 1, 0, "wall", dx=2, dy=1),
}
for _c, _s in DETAINEES:
    PROPS_SB["detainee_" + _s] = _r(lambda c=_c: detainee(c), 1, 1, down=-4)

STATES_SB = {"cage_door": {"open": lambda: cage_front(3, door=True, open_=True)}, "safe_big": {"open": lambda: safe_big(True)}}
