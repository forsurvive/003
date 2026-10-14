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
}
for _c, _s in DETAINEES:
    PROPS_SB["detainee_" + _s] = _r(lambda c=_c: detainee(c), 1, 1, down=-4)

STATES_SB = {"cage_door": {"open": lambda: cage_front(3, door=True, open_=True)}}
