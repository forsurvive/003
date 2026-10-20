"""노량진 관제 중계소 정비고 · 학원 채점기 소품(단계 1-12b FQ-GS-01 「정비 당번」 · FQ-GS-02 「천공기」, SD-04d §9.3 · §9.4 · 아이작풍 SD-16).
계획 `docs/seoul-fallout/_plans/1-12b_FQ-GS-01-02_plan.md` §4 확정안: 정비고 = 점검 마당 북동쪽 트인 차양 · 잠든 로봇마다 다른 일 ·
3번 파수만 대기등이 또렷 · 퓨즈함 · 등록용 천공기 '바늘 부러짐' · 채점기 상태(돌아감 · 바늘 뽑힘).
묘사 원칙(SD-06 §4.3.7): 기도 · 성가 · 성직 표지를 그리지 않는다 — 2077 운영 매뉴얼 · 정비 표식(녹색 번호 · 흰 천)만.
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다.
"""
import os, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
SILVER = ["P05", "P07", "P08", "P09", "P63"]


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


# ================================================================================================ 정비고 차양
def canopy():
    """트인 차양(3×1 발 — 앞 기둥 둘만 막는다): 녹슨 함석 지붕 · 쇠 기둥 · 지붕 끝에 흰 천 · 기둥에 녹색 번호 '정비'.
    지붕은 그림 위쪽(북쪽)에 걸리고 아래는 비어 그 밑을 걷는다(발 칸은 기둥 자리)."""
    im = img(96, 70)
    d = ImageDraw.Draw(im)
    d.polygon([(0, 14), (96, 14), (92, 26), (4, 26)], fill=C(INK))
    d.polygon([(1, 15), (95, 15), (91, 25), (5, 25)], fill=C("P12"))
    for x in range(4, 92, 6):                                             # 골함석 골
        d.line([x, 16, x + 1, 24], fill=C("P11"))
        d.point((x + 3, 18), fill=C("P13"))
    for x in (12, 40, 70):                                                # 녹 얼룩
        d.ellipse([x, 17, x + 7, 22], fill=C("P27"))
        d.point((x + 2, 19), fill=C("P28"))
    d.line([5, 25, 91, 25], fill=C("P10"))
    for x in (8, 84):                                                     # 앞 기둥
        d.rectangle([x, 25, x + 4, 66], fill=C(INK))
        d.rectangle([x + 1, 25, x + 3, 65], fill=C("P11"))
        d.line([x + 1, 25, x + 1, 65], fill=C("P13"))
        d.ellipse([x - 2, 63, x + 6, 69], fill=C("P02"))
    d.rectangle([7, 40, 14, 47], fill=C("P56")); put_text(im, "정", 8, 40, "P09", size=8)   # 기둥 녹색 표식
    d.rectangle([83, 40, 90, 47], fill=C("P56")); put_text(im, "비", 84, 40, "P09", size=8)
    for x in range(10, 88, 13):                                           # 지붕 끝 흰 천 조각
        d.polygon([(x, 25), (x + 6, 25), (x + 4, 32), (x + 1, 30)], fill=C("P09"))
        d.point((x + 3, 27), fill=C("P08"))
    return im


# ================================================================================================ 잠든 살림-2(정비 대상)
def _salim_rest(d, cx, cy, r=10):
    """바닥에 내려앉은 살림-2 구체 — 분사구가 꺼져 몸이 반쯤 기울었다. 눈줄기는 늘어져 바닥에 닿는다."""
    d.ellipse([cx - r - 4, cy + r - 3, cx + r + 4, cy + r + 3], fill=C("P02"))
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=C(INK))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C(SILVER[1]))
    d.ellipse([cx - r, cy - r, cx + r - 2, cy + r - 2], fill=C(SILVER[2]))
    d.ellipse([cx - r + 2, cy - r + 2, cx - 1, cy - 1], fill=C(SILVER[3]))
    d.line([cx - r + 1, cy + 3, cx + r - 1, cy + 3], fill=C(SILVER[0]))
    for k, (ex, ey) in enumerate([(cx + 13, cy + r), (cx + 7, cy + r + 2)]):   # 늘어진 눈줄기
        d.line([cx + 2 + k * 3, cy - r + 2, ex, ey], fill=C(INK), width=2)
        d.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=C(INK)); d.point((ex, ey), fill=C("P04"))


def salim_wrap(state="wrap"):
    """살림-2 ①(1×1): wrap 흰 천이 관절마다 감겼다(신도가 감아 둔 천) · bare 천을 풀어 관절이 드러남 · done 닦아 반짝 + 정비 카드."""
    im = img(36, 34)
    d = ImageDraw.Draw(im)
    cx, cy = 15, 18
    _salim_rest(d, cx, cy)
    if state == "wrap":
        for a, b in [((cx - 10, cy - 2), (cx + 10, cy + 2)), ((cx - 8, cy + 6), (cx + 9, cy - 6))]:
            d.line([a, b], fill=C("P09"), width=3)
            d.line([a[0], a[1] + 2, b[0], b[1] + 2], fill=C("P08"))
        d.polygon([(cx + 9, cy + 1), (cx + 15, cy + 5), (cx + 12, cy + 7)], fill=C("P09"))   # 늘어진 천 끝
    else:
        for (jx, jy) in [(cx - 7, cy + 4), (cx + 6, cy + 5)]:              # 드러난 관절(기름 자리)
            d.ellipse([jx - 2, jy - 2, jx + 2, jy + 2], fill=C(INK)); d.point((jx, jy), fill=C("P48"))
        if state == "done":
            d.point((cx - 5, cy - 6), fill=C(SILVER[4])); d.point((cx - 4, cy - 7), fill=C(SILVER[4]))
            _card(d, cx + 3, cy - 8)
    return im


def salim_bin(state="shut"):
    """살림-2 ②(1×1): 집진통(등 뒤 원통). shut 닫힘 · nest 뚜껑이 열려 쥐 둥지(지푸라기 · 털) · done 비우고 닦아 정비 카드."""
    im = img(36, 34)
    d = ImageDraw.Draw(im)
    cx, cy = 17, 18
    d.rounded_rectangle([cx - 15, cy - 8, cx - 6, cy + 9], 3, fill=C(INK))  # 집진통
    d.rounded_rectangle([cx - 14, cy - 7, cx - 7, cy + 8], 2, fill=C("P12"))
    d.line([cx - 14, cy - 7, cx - 7, cy - 7], fill=C("P13"))
    if state == "nest":
        d.ellipse([cx - 16, cy - 12, cx - 5, cy - 5], fill=C(INK))
        d.ellipse([cx - 15, cy - 11, cx - 6, cy - 6], fill=C("P02"))
        for p in [(cx - 13, cy - 9), (cx - 10, cy - 10), (cx - 8, cy - 8), (cx - 12, cy - 7)]:
            d.point(p, fill=C("P47"))                                     # 지푸라기
        d.point((cx - 11, cy - 8), fill=C("P18")); d.point((cx - 9, cy - 9), fill=C("P18"))   # 털
        d.line([cx - 17, cy + 10, cx - 21, cy + 12], fill=C("P47"))       # 흘린 지푸라기
    else:
        d.ellipse([cx - 15, cy - 10, cx - 6, cy - 5], fill=C("P13")); d.arc([cx - 15, cy - 10, cx - 6, cy - 5], 0, 180, fill=C(INK))
    _salim_rest(d, cx + 2, cy)
    if state == "done":
        _card(d, cx + 5, cy - 8)
    return im


# ================================================================================================ 정비 대상 파수-3(정비고 · 3번)
def _card(d, x, y):
    """천공 정비 카드 한 장(크림 · 녹색 번호 띠 · 구멍 셋)."""
    d.rectangle([x, y, x + 7, y + 5], fill=C(INK))
    d.rectangle([x + 1, y + 1, x + 6, y + 4], fill=C("P21"))
    d.line([x + 1, y + 1, x + 6, y + 1], fill=C("P56"))
    for k in range(3):
        d.point((x + 2 + k * 2, y + 3), fill=C("P02"))


def sentry_maint(state=""):
    """정비고 파수-3(2×1): props_jm 넘어진 파수와 같은 몸. 상태 — "" 식별 태그 없음(목 고리가 빔) · tag 태그를 끼움 ·
    card 정비 카드를 끼움 · three 3번(머리 대기등이 또렷하게 밝음) · three_dim 3번 퓨즈를 뺌(등이 꺼져 간다) · three_card 3번 정비 끝."""
    import props_jm as JM
    im = JM.sentry_down(state in ("three", "three_card"))
    d = ImageDraw.Draw(im)
    if state.startswith("three"):
        lit = state != "three_dim"
        d.rectangle([52, 17, 54, 20], fill=C(INK))                        # 얼굴판 위 등 받침
        d.ellipse([49, 10, 57, 18], fill=C(INK))
        d.ellipse([50, 11, 56, 17], fill=C("P56" if lit else "P05"))
        if lit:
            d.ellipse([51, 12, 54, 14], fill=C("P57"))
            for (x, y) in ((46, 12), (60, 14), (53, 8), (47, 18), (59, 9)):
                d.point((x, y), fill=C("P57"))
        else:
            d.point((52, 13), fill=C("P06"))
        put_text(im, "3", 60, 10, "P56" if lit else "P07", size=8)
    if state in ("tag",):
        d.rectangle([30, 22, 34, 26], fill=C("P48")); d.point((32, 24), fill=C(INK))
    elif state == "":
        d.arc([28, 20, 36, 28], 200, 340, fill=C("P05"))                 # 빈 목 고리
    if state in ("card", "three_card"):
        _card(d, 34, 14)
    return im


def fuse_box(state="in"):
    """3번 파수 등판 퓨즈함(1×1 벽면 소품 · 바닥에 둔 덮개): in 퓨즈가 꽂힘(녹색 띠) · out 빈 홈."""
    im = img(20, 18)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 18, 16], fill=C(INK))
    d.rectangle([2, 3, 17, 15], fill=C("P12"))
    d.rectangle([5, 6, 14, 12], fill=C("P02"))
    if state == "in":
        d.rectangle([6, 7, 13, 11], fill=C("P09")); d.line([6, 9, 13, 9], fill=C("P56"))
    return im


# ================================================================================================ 천공기 · 채점기 상태
def card_punch_broken():
    """등록용 천공기(props_gs.card_punch와 같은 몸): 레버 끝 바늘이 부러져 걸렸고 앞판에 쪽지 '바늘 부러짐 — 류정'."""
    import props_gs as GS
    im = GS.card_punch()
    d = ImageDraw.Draw(im)
    d.line([24, 12, 27, 8], fill=C("P11"), width=2)
    d.line([27, 8, 29, 9], fill=C("P05"))                                 # 부러진 끝
    d.rectangle([8, 22, 23, 33], fill=C(INK)); d.rectangle([9, 23, 22, 32], fill=C("P09"))
    d.line([11, 26, 20, 26], fill=C("P05")); d.line([11, 29, 18, 29], fill=C("P05"))
    return im


def grader_state(state="run"):
    """채점기(props_r01n.grader와 같은 몸): run 진공관을 갈아 끼워 창이 켜짐(채점 중) · noneedle 머리판을 열고 바늘 뭉치를 뽑아 감."""
    import props_r01n as RN
    im = RN.grader()
    d = ImageDraw.Draw(im)
    if state == "run":
        for x in (11, 15, 19):
            d.rectangle([x, 19, x + 2, 24], fill=C("P50")); d.point((x + 1, 20), fill=C("P63"))
        d.polygon([(10, 29), (21, 29), (21, 38), (10, 38)], fill=C("P21"))   # 다 찍힌 카드가 받이로 내려옴
        for y in (31, 33, 35):
            d.point((13, y), fill=C(INK)); d.point((17, y), fill=C(INK))
    else:
        d.rectangle([7, 4, 24, 9], fill=C(INK)); d.rectangle([8, 5, 23, 8], fill=C("P02"))   # 열린 머리판
        d.line([24, 4, 29, 0], fill=C("P48"))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_GS2 = {
    "gs_canopy": _r(canopy, 0, 0, "deco"),
    "gs_salim_wrap": _r(salim_wrap, 1, 1, down=-2),
    "gs_salim_bin": _r(salim_bin, 1, 1, down=-2),
    "gs_sentry_maint": _r(sentry_maint, 2, 1, down=-2),
    "gs_fuse_box": _r(fuse_box, 0, 0, "deco"),
    "gs_punch_reg": _r(card_punch_broken, 1, 1, down=-2),
}

STATES_GS2 = {
    "gs_salim_wrap": {s: (lambda s=s: salim_wrap(s)) for s in ("bare", "done")},
    "gs_salim_bin": {s: (lambda s=s: salim_bin(s)) for s in ("nest", "done")},
    "gs_sentry_maint": {s: (lambda s=s: sentry_maint(s)) for s in ("tag", "card", "three", "three_dim", "three_card")},
    "gs_fuse_box": {"out": lambda: fuse_box("out")},
    "grader": {s: (lambda s=s: grader_state(s)) for s in ("run", "noneedle")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_gs2.png"
    ims = [v["fn"]() for v in PROPS_GS2.values()] + [f() for st in STATES_GS2.values() for f in st.values()]
    W = sum(i.width for i in ims) + 6 * len(ims)
    H = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, H), (70, 72, 78, 255))
    x = 0
    for i in ims:
        sheet.alpha_composite(i, (x, H - i.height))
        x += i.width + 6
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)
    print(out)
