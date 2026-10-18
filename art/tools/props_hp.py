"""여의도 대학병원 소품(단계 1-D8, 1-D 계획 §14 · SD-09a L-R02-09 L967 · SD-16 아이작풍).
  원문: 2077 지정 병원 · 응급실 · 7층 구울 병동(비적대 구울 12) · 약제부 · 지하 영안실 야생 구울 · 병동 게시판 '면회 시간 14:00~16:00'
  · 반수빈이 매일 그 시간에 복도 의자를 정리한다.
    w_pa_hp         원내 방송 단말(벽 1칸): 크림 함 · 천장 스피커 그릴 · 마이크 · 시각 단추 다섯(기상 · 회진 · 배식 · 면회 · 소등)
    w_visit_hp      병동 게시판(벽 2칸): '면회 시간 14:00~16:00' · 일과표 · 압정 쪽지 / 상태 off(빈 병동 — 쪽지가 떨어짐)
    morgue_hp       영안실 냉동 칸 벽(2×2): 스테인리스 칸 2×3 · 손잡이 · 이름표 / 상태 open(칸 하나가 열림 — 빈 들것) · cold(성에 · 표시등 초록)
    station_hp      간호사실 카운터(2×1): 민트 카운터 · 차트꽂이 · 호출벨 · 서류
    triage_hp       분류 구역 바닥 띠(바닥 덮개 1×1): 빨강 · 노랑 · 초록 · 검정 색 띠(상태 y · g · k로 색)
    w_chart_hp      침대 머리 차트(벽 덮개 1칸): 클립보드 · 이름표 · 체온표 / 상태 faded(줄이 끊김 — 퇴원)
    gurney_hp       영안실 들것(2×1): 바퀴 들것 · 흰 시트 · 발목 이름표
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
CREAM = ("P06", "P07", "P08", "P09")
MINT = ("P34", "P35", "P36", "P37")
PAPER = ("P20", "P21", "P22")
SHEET = ("P07", "P08", "P09")


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


def w_pa_hp():
    """원내 방송 단말(벽 1칸, 32×44): 스피커 그릴 · 마이크 목 · 시각 단추 다섯 · 붉은 '코드' 덮개 단추."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    _box(d, 3, 2, 28, 41, CREAM)
    d.ellipse([8, 4, 23, 17], fill=C(INK)); d.ellipse([9, 5, 22, 16], fill=C(STEEL[2]))
    for y in range(7, 15, 2):                                                        # 그릴
        d.line([11, y, 20, y], fill=C(STEEL[0]))
    d.line([15, 18, 15, 22], fill=C(INK)); d.line([16, 18, 18, 22], fill=C(INK))      # 마이크 목
    d.rectangle([17, 21, 20, 24], fill=C(STEEL[0]))
    for i, c in enumerate(("P49", "P46", "P56", "P62", "P04")):                       # 기상 · 회진 · 배식 · 면회 · 소등
        x = 6 + i * 4
        d.rectangle([x, 28, x + 2, 30], fill=C(INK)); d.point((x + 1, 29), fill=C(c))
    _box(d, 7, 32, 24, 41, ("P51", "P52", "P53", "P54"))                             # 코드 블루 덮개
    put_text(im, "코드", 8, 33, "P09", 8, "Galmuri7")
    return im


def w_visit_hp(state=""):
    """병동 게시판(벽 2칸, 64×48): 코르크 판 · '면회 14:00~16:00' 띠 · 일과표 다섯 줄 · 쪽지. off = 쪽지가 떨어지고 일과표만."""
    im = img(64, 48)
    d = ImageDraw.Draw(im)
    _box(d, 1, 2, 62, 45, ("P18", "P19", "P20", "P21"))
    d.rectangle([3, 4, 60, 14], fill=C("P61"))
    put_text(im, "면회 14~16시", 6, 5, "P09", 8, "Galmuri7")
    _box(d, 4, 16, 32, 42, SHEET)                                                    # 일과표
    for i, c in enumerate(("P49", "P46", "P56", "P62", "P04")):
        y = 19 + i * 5
        d.rectangle([6, y, 8, y + 2], fill=C(c))
        d.line([10, y + 1, 29, y + 1], fill=C(STEEL[1]))
    if state != "off":
        for (x, y, c) in ((36, 17, PAPER[2]), (47, 19, "P50"), (39, 30, SHEET[2]), (51, 31, PAPER[1])):
            d.rectangle([x, y, x + 8, y + 9], fill=C(INK)); d.rectangle([x + 1, y + 1, x + 7, y + 8], fill=C(c))
            d.point((x + 4, y + 1), fill=C("P53"))                                   # 압정
            d.line([x + 2, y + 4, x + 6, y + 4], fill=C(STEEL[1])); d.line([x + 2, y + 6, x + 5, y + 6], fill=C(STEEL[1]))
    else:
        for (x, y) in ((40, 18), (51, 21), (43, 32)):
            d.point((x, y), fill=C("P53"))                                           # 압정만 남음
    return im


def morgue_hp(state=""):
    """영안실 냉동 칸 벽(2×2, 64×88): 스테인리스 칸 2열 × 3단 · 손잡이 · 이름표. open = 가운데 아래 칸이 열려 빈 판이 나옴 · cold = 성에 · 표시등 초록."""
    im = img(64, 88)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 86)
    _box(d, 2, 4, 61, 84, CHROME)
    lamp = "P56" if state == "cold" else "P53"
    d.rectangle([28, 6, 35, 10], fill=C(INK)); d.rectangle([29, 7, 34, 9], fill=C(lamp))
    for r in range(3):
        for c in range(2):
            x0, y0 = 5 + c * 29, 13 + r * 23
            if state == "open" and (r, c) == (2, 0):
                d.rectangle([x0, y0, x0 + 25, y0 + 19], fill=C(INK))
                _box(d, x0 - 2, y0 + 12, x0 + 27, y0 + 19, CHROME)                   # 빼낸 판(비었다)
                continue
            _box(d, x0, y0, x0 + 25, y0 + 19, CHROME)
            d.rectangle([x0 + 9, y0 + 11, x0 + 16, y0 + 13], fill=C(INK)); d.line([x0 + 10, y0 + 12, x0 + 15, y0 + 12], fill=C(CHROME[3]))
            d.rectangle([x0 + 3, y0 + 3, x0 + 10, y0 + 7], fill=C(SHEET[2]))           # 이름표
            d.line([x0 + 4, y0 + 5, x0 + 9, y0 + 5], fill=C(STEEL[1]))
            if state == "cold":
                for k in range(0, 24, 5):
                    d.point((x0 + 1 + k, y0 + 1), fill=C("P63"))
    return im


def station_hp():
    """간호사실 카운터(2×1, 64×56): 민트 카운터 · 위 차트꽂이(클립보드 여섯) · 호출벨 · 서류 더미."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 54)
    _box(d, 2, 26, 61, 52, MINT)
    d.line([3, 33, 60, 33], fill=C(MINT[0]))
    _box(d, 2, 20, 61, 27, SHEET)                                                    # 상판
    _box(d, 6, 4, 38, 21, STEEL)                                                     # 차트꽂이
    for i in range(6):
        x = 8 + i * 5
        d.rectangle([x, 7, x + 3, 19], fill=C(PAPER[2] if i % 2 else SHEET[2]))
        d.line([x, 7, x + 3, 7], fill=C("P04"))
    d.ellipse([46, 15, 53, 21], fill=C(INK)); d.ellipse([47, 16, 52, 20], fill=C("P49"))   # 호출벨
    d.point((49, 15), fill=C(INK))
    for k, y in enumerate((17, 15, 13)):                                             # 서류
        d.rectangle([40 + k, y, 45 + k, y + 4], fill=C(INK)); d.rectangle([41 + k, y + 1, 44 + k, y + 3], fill=C(SHEET[2]))
    put_text(im, "7병동", 22, 37, "P37", 8, "Galmuri7")
    return im


def triage_hp(state=""):
    """분류 구역 바닥 띠(바닥 덮개 32×32): 칸 아래쪽 1/3에 색 띠 · 화살표. 상태 없음 = 빨강, y · g · k = 노랑 · 초록 · 검정."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    col = {"": ("P52", "P53"), "y": ("P48", "P49"), "g": ("P55", "P56"), "k": ("P01", "P03")}[state]
    d.rectangle([0, 20, 31, 27], fill=C(col[0]))
    d.line([0, 20, 31, 20], fill=C(col[1]))
    for x in (6, 18):
        d.polygon([(x, 22), (x + 6, 24), (x, 26)], fill=C(col[1] if state != "k" else "P05"))
    return im


def w_chart_hp(state=""):
    """침대 머리 차트(벽 1칸, 32×32): 클립보드 · 이름표 · 체온 선. faded = 선이 중간에서 끊기고 '퇴원' 붉은 도장."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    _box(d, 9, 6, 22, 27, ("P18", "P19", "P20", "P21"))
    d.rectangle([13, 4, 18, 8], fill=C(STEEL[2])); d.line([13, 4, 18, 4], fill=C(INK))
    d.rectangle([11, 9, 20, 25], fill=C(SHEET[2]))
    d.line([12, 11, 19, 11], fill=C(STEEL[1]))
    pts = [(12, 20), (14, 17), (15, 19), (17, 16), (19, 18)]
    if state == "faded":
        pts = pts[:3]
        d.rectangle([14, 21, 19, 24], fill=C("P53")); d.point((16, 22), fill=C(SHEET[2]))
    d.line(pts, fill=C("P53" if state != "faded" else "P04"))
    return im


def gurney_hp():
    """영안실 들것(2×1, 64×40): 철 다리 · 바퀴 · 흰 시트 아래 사람 윤곽 · 발목 이름표."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 60, 38)
    for x in (8, 52):
        d.line([x, 24, x, 34], fill=C(INK)); d.ellipse([x - 2, 33, x + 2, 37], fill=C(INK))
    _box(d, 3, 20, 60, 25, CHROME)
    d.rectangle([5, 10, 58, 21], fill=C(INK))
    d.rectangle([6, 11, 57, 20], fill=C(SHEET[1]))
    d.ellipse([7, 9, 17, 19], fill=C(INK)); d.ellipse([8, 10, 16, 18], fill=C(SHEET[2]))   # 머리 윤곽
    d.line([18, 12, 56, 12], fill=C(SHEET[2]))
    d.line([58, 18, 61, 22], fill=C(INK)); d.rectangle([60, 21, 63, 25], fill=C(PAPER[2]))  # 발목 이름표
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_HP = {
    "w_pa_hp": _r(w_pa_hp, 1, 0, "wall", dx=0, dy=2),
    "w_visit_hp": _r(lambda: w_visit_hp(), 2, 0, "wall", dx=0, dy=0),
    "morgue_hp": _r(lambda: morgue_hp(), 2, 2, down=-2),
    "station_hp": _r(station_hp, 2, 1, down=-2),
    "triage_hp": _r(lambda: triage_hp(), 1, 1, "deco", down=0),
    "w_chart_hp": _r(lambda: w_chart_hp(), 1, 0, "wall", dx=0, dy=8),
    "gurney_hp": _r(gurney_hp, 2, 1, down=-2),
}
STATES_HP = {
    "w_visit_hp": {"off": lambda: w_visit_hp("off")},
    "morgue_hp": {"open": lambda: morgue_hp("open"), "cold": lambda: morgue_hp("cold")},
    "triage_hp": {"y": lambda: triage_hp("y"), "g": lambda: triage_hp("g"), "k": lambda: triage_hp("k")},
    "w_chart_hp": {"faded": lambda: w_chart_hp("faded")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_HP.values()] + [fn() for st in STATES_HP.values() for fn in st.values()]
    cols = 6
    cw, ch = 76, 96
    sheet = Image.new("RGBA", (cols * cw, ((len(ims) + cols - 1) // cols) * ch), (70, 66, 74, 255))
    for i, m in enumerate(ims):
        sheet.alpha_composite(m, ((i % cols) * cw + 4, (i // cols) * ch + 4))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
