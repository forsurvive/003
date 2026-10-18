"""여의도 유리탑 3동 · 증권가 객장 소품(단계 1-D9, 1-D 계획 §15 · SD-09a L-R02-08 L961 · L-R02-07 L955 · SD-05 UQ-06 L298 · SD-16 아이작풍).
  원문: 유리 커튼월이 깨져 바람이 분다 · 로비 안내판 '3동 연결 통로 폐쇄 — 계엄 시 1·2·3동 출입 등급 분리' · 동마다 판독기 등급 표시가 다르다
  · 18층 시세 송출실(시세 테이프) · 증권가 진공관 시세판 '종합지수 ▼ 99.9%'.
    gate_yt       판독기 게이트(2×1): 스테인리스 허리 기둥 둘 · 유리 날개 · 카드 판 / 상태 g · b · r(등급 불 — 1동 초록 · 2동 파랑 · 3동 빨강) · open(날개 접힘 · 초록)
    w_reader_yt   벽 판독기(벽 1칸): 카드 홈 · 등급 띠 / 상태 g · b · r · ok(초록 체크) · no(빨간 엑스)
    w_board_yt    로비 안내판(벽 2칸): '연결통로 폐쇄' · 1·2·3동 색 칸 · 계엄 붉은 띠
    shutter_yt    연결 통로 방화 셔터(2×1): 내려온 철 셔터 · 노랑 검정 띠 · 바닥 걸쇠 / 상태 up(올라감 — 셔터 통만)
    idterm_yt     사원증 발급 단말(1×1): 베이지 단말 · 초록 화면 · 카드 프린터 · 반쯤 나온 카드
    rack_yt       시세 송출 랙(2×2): 회색 랙 · 릴 테이프 데크 둘 · 숫자 창 · '시세 송출' 판 / 상태 empty(릴 하나가 빠짐)
    mound_yt      창가 화분 개미 둔덕(1×1): 사무실 화분 · 흙 둔덕 · 굴 구멍 / 상태 dry(마른 둔덕 — 전초가 끊김)
    w_ticker_sg   객장 전광판(벽 3칸): 검은 판 · 주황 진공관 숫자 '종합 ▼99.9%' / 상태 close(마감 — 숫자가 바뀌고 '장 마감')
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다. 위에서 빛(위 밝게 · 아래 어둡게), 반투명 없음."""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
STEEL = ("P03", "P04", "P05", "P06", "P07")
CHROME = ("P12", "P13", "P14", "P15")
BEIGE = ("P19", "P20", "P21", "P22")
GLASS = ("P61", "P62", "P63")
GRADE = {"g": ("P55", "P56", "P57"), "b": ("P44", "P46", "P15"), "r": ("P52", "P54", "P50")}
AMBER = ("P58", "P59", "P60")


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


def _lamp(d, x, y, ramp, w=3):
    d.rectangle([x - 1, y - 1, x + w, y + 1], fill=C(INK))
    d.line([x, y, x + w - 1, y], fill=C(ramp[1]))
    d.point((x, y), fill=C(ramp[2]))


def gate_yt(state=""):
    """판독기 게이트(2×1, 64×44): 허리 높이 스테인리스 기둥 둘(가운데 통로) · 기둥 위 카드 판 · 유리 날개.
    g · b · r = 그 동의 등급 불 · open = 날개가 기둥 안으로 접히고 초록."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    lit = GRADE.get(state[:1] if state != "open" else "g")
    for (x0, x1) in ((4, 19), (44, 59)):                                                  # 기둥 둘
        _box(d, x0, 18, x1, 41, CHROME)
        d.line([x0 + 2, 20, x0 + 2, 39], fill=C(CHROME[3]))                              # 세로 광택
        d.line([x1 - 2, 22, x1 - 2, 39], fill=C(CHROME[0]))
        _box(d, x0 - 1, 14, x1 + 1, 19, STEEL[1:])                                       # 윗판
        d.rectangle([x0 + 4, 15, x1 - 4, 17], fill=C(INK))                                # 카드 판
        d.rectangle([x0 + 5, 16, x1 - 5, 16], fill=C(lit[1] if lit else STEEL[1]))
        if lit:
            d.point((x0 + 5, 16), fill=C(lit[2]))
    if state == "open":                                                                   # 접힌 날개(기둥 옆 얇은 유리)
        for x in (20, 41):
            d.rectangle([x, 22, x + 2, 34], fill=C(GLASS[0])); d.line([x + 1, 23, x + 1, 33], fill=C(GLASS[2]))
    else:
        for (x0, x1) in ((20, 31), (32, 43)):                                             # 유리 날개(통로를 막음)
            d.rectangle([x0, 22, x1, 34], fill=C(INK))
            d.rectangle([x0 + 1, 23, x1 - 1, 33], fill=C(GLASS[0]))
            d.line([x0 + 2, 24, x0 + 5, 24], fill=C(GLASS[2])); d.line([x0 + 2, 25, x0 + 3, 25], fill=C(GLASS[1]))
        d.line([31, 22, 31, 34], fill=C(INK)); d.line([32, 22, 32, 34], fill=C(INK))
    _shadow(d, 4, 60, 42)
    return im


def w_reader_yt(state=""):
    """벽 판독기(벽 1칸, 32×40): 회색 함 · 카드 홈 · 등급 띠. ok = 초록 체크 · no = 빨간 엑스."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    _box(d, 9, 8, 22, 33, STEEL[1:])
    d.rectangle([11, 11, 20, 18], fill=C(INK))                                             # 작은 창
    rp = GRADE.get(state) or (GRADE["g"] if state == "ok" else GRADE["r"] if state == "no" else None)
    d.rectangle([12, 12, 19, 17], fill=C(rp[0] if rp else "P02"))
    if state == "ok":
        d.line([13, 15, 15, 17], fill=C(rp[2])); d.line([15, 17, 18, 12], fill=C(rp[2]))
    elif state == "no":
        d.line([13, 12, 18, 17], fill=C(rp[2])); d.line([18, 12, 13, 17], fill=C(rp[2]))
    elif rp:
        d.line([13, 14, 18, 14], fill=C(rp[1])); d.point((13, 14), fill=C(rp[2]))
    d.rectangle([12, 22, 19, 23], fill=C(INK))                                             # 카드 홈
    d.line([12, 26, 19, 26], fill=C(rp[1] if rp else STEEL[0]))                           # 등급 띠
    d.line([12, 28, 19, 28], fill=C(STEEL[0]))
    return im


def w_board_yt():
    """로비 안내판(벽 2칸, 64×44): 남색 판 · '연결통로 폐쇄' · 1·2·3동 색 칸 · 계엄 붉은 띠(덧붙인 종이)."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    _box(d, 2, 2, 61, 41, ("P43", "P44", "P45", "P46"))
    put_text(im, "유리탑", 5, 4, "P15", 8, "Galmuri7")
    for i, (k, n) in enumerate((("g", "1"), ("b", "2"), ("r", "3"))):                      # 동 칸
        x = 6 + i * 18
        d.rectangle([x, 16, x + 14, 25], fill=C(INK)); d.rectangle([x + 1, 17, x + 13, 24], fill=C(GRADE[k][1]))
        put_text(im, n + "동", x + 2, 17, "P09", 8, "Galmuri7")
    d.polygon([(3, 29), (60, 27), (60, 38), (3, 40)], fill=C("P53"))                        # 덧붙인 계엄 띠
    d.line([3, 29, 60, 27], fill=C("P54"))
    put_text(im, "연결통로 폐쇄", 6, 29, "P09", 8, "Galmuri7")
    d.point((58, 28), fill=C("P07")); d.point((5, 39), fill=C("P07"))                          # 테이프 귀
    return im


def shutter_yt(state=""):
    """연결 통로 방화 셔터(2×1, 64×56): 셔터 통 · 내려온 골판 셔터 · 노랑 검정 띠 · 바닥 걸쇠. up = 통만 남고 통로가 비었다."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    _box(d, 1, 2, 62, 10, STEEL[1:])                                                        # 셔터 통
    d.line([3, 6, 60, 6], fill=C(STEEL[0]))
    d.rectangle([2, 10, 4, 53], fill=C(INK)); d.rectangle([59, 10, 61, 53], fill=C(INK))     # 레일
    if state == "up":
        d.rectangle([5, 11, 58, 13], fill=C(STEEL[2])); d.line([5, 13, 58, 13], fill=C(INK))
        _shadow(d, 5, 59, 54)
        return im
    d.rectangle([5, 11, 58, 52], fill=C(STEEL[2]))
    for y in range(12, 46, 3):                                                               # 골
        d.line([5, y, 58, y], fill=C(STEEL[0])); d.line([5, y + 1, 58, y + 1], fill=C(STEEL[3]))
    for x in range(5, 59, 6):                                                                # 노랑 검정 띠
        d.polygon([(x, 46), (x + 3, 46), (x + 6, 52), (x + 3, 52)], fill=C("P49"))
    d.rectangle([5, 46, 58, 52], outline=C(INK))
    d.rectangle([27, 44, 36, 48], fill=C(INK)); d.rectangle([28, 45, 35, 47], fill=C(STEEL[4]))  # 걸쇠
    d.line([10, 20, 18, 30], fill=C(STEEL[4])); d.line([11, 20, 19, 30], fill=C(STEEL[1]))     # 긁힌 자국
    _shadow(d, 5, 59, 53)
    return im


def idterm_yt():
    """사원증 발급 단말(1×1, 32×40): 베이지 몸 · 초록 화면 글줄 · 카드 프린터 · 반쯤 나온 흰 카드(파란 띠)."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    _box(d, 4, 4, 27, 22, BEIGE)                                                            # 화면 몸
    d.rectangle([7, 7, 24, 18], fill=C(INK)); d.rectangle([8, 8, 23, 17], fill=C("P28"))
    for y in (10, 12, 14):
        d.line([9, y, 9 + (22 - y), y], fill=C("P56"))
    d.point((10, 16), fill=C("P57"))
    _box(d, 2, 23, 29, 36, BEIGE)                                                           # 프린터 받침
    d.rectangle([8, 26, 23, 27], fill=C(INK))                                               # 카드 홈
    d.rectangle([11, 22, 20, 27], fill=C("P09")); d.rectangle([11, 22, 20, 23], fill=C("P46"))   # 나온 카드
    d.rectangle([11, 22, 20, 27], outline=C(INK))
    d.point((25, 31), fill=C("P56"))                                                        # 전원 불
    _shadow(d, 3, 29, 37)
    return im


def rack_yt(state=""):
    """시세 송출 랙(2×2, 64×80): 회색 랙 · 위 숫자 창(주황) · 릴 테이프 데크 둘 · '시세 송출' 판. empty = 오른쪽 릴이 빠지고 축만."""
    im = img(64, 80)
    d = ImageDraw.Draw(im)
    _box(d, 4, 2, 59, 75, STEEL[1:])
    d.rectangle([8, 6, 55, 15], fill=C(INK))                                                # 숫자 창
    for i in range(7):
        x = 10 + i * 6
        d.rectangle([x, 8, x + 3, 13], fill=C(AMBER[0])); d.line([x, 10, x + 3, 10], fill=C(AMBER[2]))
    put_text(im, "시세 송출", 10, 18, "P09", 8, "Galmuri7")
    _box(d, 7, 30, 56, 58, ("P02", "P03", "P04", "P05"))                                   # 데크 판
    for k, cx in enumerate((19, 44)):
        if state == "empty" and k == 1:
            d.ellipse([cx - 2, 42, cx + 2, 46], fill=C(STEEL[4])); d.point((cx, 44), fill=C(INK))
            continue
        d.ellipse([cx - 9, 35, cx + 9, 53], fill=C(INK))
        d.ellipse([cx - 8, 36, cx + 8, 52], fill=C("P17"))                                   # 감긴 테이프(갈색)
        d.ellipse([cx - 4, 40, cx + 4, 48], fill=C(STEEL[3]))
        for (a, b) in ((0, -3), (3, 2), (-3, 2)):                                           # 릴 구멍
            d.point((cx + a, 44 + b), fill=C(INK))
        d.arc([cx - 7, 37, cx + 7, 51], 200, 260, fill=C("P19"))
    if state != "empty":
        d.line([19, 53, 44, 53], fill=C("P17"))                                              # 두 릴 사이 테이프
    for i in range(5):                                                                       # 단추
        x = 12 + i * 9
        d.rectangle([x, 61, x + 5, 64], fill=C(INK)); d.line([x + 1, 62, x + 4, 62], fill=C(STEEL[4] if i else "P54"))
    d.rectangle([8, 68, 55, 71], fill=C(STEEL[0]))                                           # 환기 줄
    _shadow(d, 5, 60, 76)
    return im


def mound_yt(state=""):
    """창가 화분 개미 둔덕(1×1, 32×36): 네모 사무실 화분 · 넘친 흙 둔덕 · 굴 구멍 셋 · 말라 죽은 잎. dry = 회색으로 마르고 갈라짐."""
    im = img(32, 36)
    d = ImageDraw.Draw(im)
    soil = ("P04", "P05", "P06") if state == "dry" else ("P16", "P17", "P18")
    for (x0, y0, x1, y1) in ((3, 12, 21, 30), (12, 8, 29, 30)):                             # 둔덕(둥근 흙 두 덩이가 화분을 넘침)
        d.ellipse([x0, y0, x1, y1], fill=C(INK))
    for (x0, y0, x1, y1) in ((4, 13, 20, 29), (13, 9, 28, 29)):
        d.ellipse([x0, y0, x1, y1], fill=C(soil[1]))
    d.arc([5, 14, 19, 28], 200, 290, fill=C(soil[2])); d.arc([14, 10, 27, 28], 210, 300, fill=C(soil[2]))
    for (x, y) in ((8, 19), (17, 14), (22, 18), (12, 17)):                                    # 굴 구멍 · 흙 알갱이
        d.rectangle([x, y, x + 1, y + 1], fill=C(INK)); d.point((x + 1, y - 1), fill=C(soil[0]))
    for (x, y) in ((6, 22), (25, 21), (15, 12)):
        d.point((x, y), fill=C(soil[2]))
    if state == "dry":
        d.line([8, 23, 12, 18], fill=C(INK)); d.line([21, 22, 25, 17], fill=C(INK)); d.line([15, 11, 17, 15], fill=C(INK))
    d.line([22, 9, 25, 3], fill=C("P18")); d.line([25, 3, 28, 4], fill=C("P30" if state != "dry" else "P05"))   # 마른 줄기
    _box(d, 5, 21, 26, 33, ("P11", "P12", "P13", "P14"))                                    # 화분
    d.line([7, 26, 24, 26], fill=C("P11"))
    _shadow(d, 5, 27, 34)
    return im


def w_ticker_sg(state=""):
    """객장 전광판(벽 3칸, 96×44): 검은 판 · 주황 진공관 숫자. 기본 '종합 ▼99.9%' · close = '장 마감' + 마감가 줄."""
    im = img(96, 44)
    d = ImageDraw.Draw(im)
    _box(d, 1, 2, 94, 41, ("P01", "P02", "P03", "P04"))
    d.rectangle([4, 5, 91, 38], fill=C("P01"))
    if state == "close":
        put_text(im, "장 마감", 6, 6, AMBER[2], 8, "Galmuri7")
        put_text(im, "10.23 15:30", 42, 6, AMBER[1], 8, "Galmuri7")
    else:
        put_text(im, "종합", 6, 6, AMBER[2], 8, "Galmuri7")
        put_text(im, "▼99.9%", 34, 6, "P54", 8, "Galmuri7")
    for r in range(3):                                                                       # 종목 줄(진공관 점)
        y = 19 + r * 6
        for i in range(14):
            x = 6 + i * 6
            on = (i * 7 + r * 3 + (5 if state == "close" else 0)) % 5 != 0
            d.rectangle([x, y, x + 3, y + 3], fill=C(AMBER[1] if on else "P02"))
            if on:
                d.point((x + 1, y + 1), fill=C(AMBER[2]))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_YT = {
    "gate_yt": _r(lambda: gate_yt(), 2, 1, down=-2),
    "w_reader_yt": _r(lambda: w_reader_yt(), 1, 0, "wall", dx=0, dy=4),
    "w_board_yt": _r(w_board_yt, 2, 0, "wall", dx=0, dy=0),
    "shutter_yt": _r(lambda: shutter_yt(), 2, 1, down=-2),
    "idterm_yt": _r(idterm_yt, 1, 1, down=-2),
    "rack_yt": _r(lambda: rack_yt(), 2, 2, down=-2),
    "mound_yt": _r(lambda: mound_yt(), 1, 1, down=-2),
    "w_ticker_sg": _r(lambda: w_ticker_sg(), 3, 0, "wall", dx=0, dy=0),
}
STATES_YT = {
    "gate_yt": {k: (lambda k=k: gate_yt(k)) for k in ("g", "b", "r", "open")},
    "w_reader_yt": {k: (lambda k=k: w_reader_yt(k)) for k in ("g", "b", "r", "ok", "no")},
    "shutter_yt": {"up": lambda: shutter_yt("up")},
    "rack_yt": {"empty": lambda: rack_yt("empty")},
    "mound_yt": {"dry": lambda: mound_yt("dry")},
    "w_ticker_sg": {"close": lambda: w_ticker_sg("close")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_YT.values()] + [fn() for st in STATES_YT.values() for fn in st.values()]
    cols = 6
    cw, ch = 100, 88
    sheet = Image.new("RGBA", (cols * cw, ((len(ims) + cols - 1) // cols) * ch), (70, 66, 74, 255))
    for i, m in enumerate(ims):
        sheet.alpha_composite(m, ((i % cols) * cw + 4, (i // cols) * ch + 4))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
