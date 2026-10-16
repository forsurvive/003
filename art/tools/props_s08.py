"""영등포 구청 배급소 · 지하시장 남쪽 통로 경비 초소 · 김민수 셔터(단계 1-11g SQ-S08 같은 명찰의 두 사람, SD-04a §5.1 · SD-09a L-R02-15 · SD-16 아이작풍).
  queue_board     번호표 전광판(벽 2칸): 검은 판 · 주황 진공관 숫자 '0411' · '번 고객님' · 상태 next('0413' — 주인공 번호표 차례)
  queue_skel      대기 줄 해골(1×1, 덧그림): 줄에 선 채 무너져 앉은 유해 · 손에 쥔 번호표 · 바랜 외투(색 셋)
  grade_line1~5   등급 줄(바닥 덧그림): 바닥에 칠한 색 띠 · 동그라미 안 등급 숫자 · 닳은 자국(1 금색 · 2 초록 · 3 파랑 · 4 주황 · 5 빨강)
  vip_sign        '공무원 우선 창구' 세움 팻말(1×1): 쇠 받침 · 남색 판 · 흰 글자
  w_grade_chart   배급 등급표 · 2077(벽 2칸): 누런 표 · 등급마다 하루 배급량 · 5등급 칸만 빨간 '대기'
  guard_desk      2077 상가 경비 초소 책상(2×1): 철제 책상 · 무전기(꺼진 빨간 불) · 경비 모자 · 손전등 · 근무 수첩 자리
  remains_guard   경비복 유해(1×1, 덧그림): 남색 경비복 · 가슴의 노란 명찰 '김민수' · 손전등 · 상태 taken(수첩을 가져간 뒤 — 빈 손)
  w_shutter_mem   김민수 셔터(벽 2칸): 닫힌 골 셔터 · 상태 named(흰 칠 '김민수 — 상가 야간 경비' · 명찰 둘 걸림 · 아래 국화)
  sign_repair     수리 노점 세움 간판(1×1): '수리 — 김민수' · 상태 bong('봉 수리' — 새 칠)
  w_paper_name    '본명 찾기 상담' 종이(벽 1칸): 테이프로 붙인 종이 · 함준호 글씨
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def queue_board(state=""):
    """번호표 전광판(64×30): 검은 철판 · 진공관 숫자 넷(주황 빛 · 꺼진 획은 어두운 갈색) · 아래 '번 고객님' · 위 '민원 대기'."""
    im = img(64, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 62, 28], fill=C(INK)); d.rectangle([2, 3, 61, 27], fill=C("P02"))
    d.line([2, 3, 61, 3], fill=C("P04"))
    put_text(im, "민원 대기", 4, 3, "P07")
    num = {"next": "0413", "skip": "0412"}.get(state, "0411")
    seg = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}
    for i, ch in enumerate(num):                                                              # 진공관 칠획(5×8)
        x0, y0 = 6 + i * 9, 12
        d.rectangle([x0 - 1, y0 - 1, x0 + 6, y0 + 9], fill=C("P38"))                          # 관 유리(어두운 붉은 갈색)
        on = seg.get(ch, "")
        lines = {"a": [x0, y0, x0 + 5, y0], "b": [x0 + 5, y0, x0 + 5, y0 + 4], "c": [x0 + 5, y0 + 4, x0 + 5, y0 + 8],
                 "d": [x0, y0 + 8, x0 + 5, y0 + 8], "e": [x0, y0 + 4, x0, y0 + 8], "f": [x0, y0, x0, y0 + 4], "g": [x0, y0 + 4, x0 + 5, y0 + 4]}
        for k, ln in lines.items():
            if k in on:
                d.line(ln, fill=C("P59"))                                                    # 꺼진 획은 관 유리 색 그대로(안 보인다)
        for k in on:
            if k in "ad":
                d.point((lines[k][0] + 2, lines[k][1]), fill=C("P60"))                         # 가장 밝은 점
    put_text(im, "번", 44, 13, "P59")
    put_text(im, "고객", 44, 20, "P05")
    d.point((58, 6), fill=C("P53" if state != "next" else "P56"))                             # 호출 불
    return im


def queue_skel(seed=0):
    """대기 줄 해골(32×36): 줄 선 채 무너져 앉은 유해 — 무릎을 세운 다리 · 외투 · 기운 해골 · 손에 번호표(흰 종이)."""
    r = random.Random(seed)
    im = img(32, 36)
    d = ImageDraw.Draw(im)
    d.ellipse([3, 28, 29, 35], fill=C("P02"))
    coat = ["P44", "P18", "P29", "P05"][seed % 4]
    d.polygon([(9, 14), (22, 13), (25, 29), (7, 30)], fill=C(INK))                           # 몸통(앉음)
    d.polygon([(10, 15), (21, 14), (23, 28), (9, 29)], fill=C(coat))
    d.line([10, 15, 21, 14], fill=C("P20" if coat != "P05" else "P07"))
    d.line([20, 26, 27, 22], fill=C("P17"), width=3); d.line([27, 22, 29, 30], fill=C("P17"), width=3)   # 세운 다리
    d.rectangle([27, 29, 31, 32], fill=C(INK))
    hx = 9 + r.randint(-1, 2)
    d.ellipse([hx, 3, hx + 10, 13], fill=C(INK)); d.ellipse([hx + 1, 4, hx + 9, 12], fill=C("P08"))   # 해골(기울었다)
    d.rectangle([hx + 2, 6, hx + 3, 8], fill=C("P02")); d.rectangle([hx + 6, 6, hx + 7, 8], fill=C("P02"))   # 눈구멍
    d.point((hx + 5, 9), fill=C("P04")); d.line([hx + 3, 11, hx + 7, 11], fill=C("P04"))
    d.rectangle([4, 21, 9, 25], fill=C("P09")); d.rectangle([4, 21, 9, 25], outline=C("P06"))  # 번호표
    d.point((6, 23), fill=C("P04"))
    return im


GRADE_COL = {1: "P49", 2: "P55", 3: "P45", 4: "P27", 5: "P53"}


def grade_line(g):
    """등급 줄(32×12, 바닥 덧그림): 바닥에 칠한 색 띠 · 왼쪽 동그라미 안 숫자 · 발에 닳아 칠이 벗겨진 자리."""
    r = random.Random(g * 7)
    im = img(32, 12)
    d = ImageDraw.Draw(im)
    col = GRADE_COL[g]
    d.rectangle([0, 4, 31, 8], fill=C(col))
    for _ in range(6):                                                                        # 닳은 자리
        x = r.randint(8, 29)
        d.rectangle([x, 5, x + r.randint(1, 3), 7], fill=(0, 0, 0, 0))
    d.ellipse([0, 0, 11, 11], fill=C(INK)); d.ellipse([1, 1, 10, 10], fill=C(col))
    put_text(im, str(g), 3, 1, "P01")
    return im


def vip_sign():
    """'공무원 우선 창구' 세움 팻말(32×48): 무거운 받침 · 쇠 기둥 · 남색 판 두 줄."""
    im = img(32, 48)
    d = ImageDraw.Draw(im)
    d.ellipse([6, 41, 26, 47], fill=C("P02"))
    d.rectangle([10, 40, 22, 44], fill=C(INK)); d.rectangle([11, 41, 21, 43], fill=C("P05"))
    d.line([16, 20, 16, 40], fill=C(INK), width=2); d.line([16, 20, 16, 40], fill=C("P06"))
    d.rectangle([1, 2, 30, 21], fill=C(INK)); d.rectangle([2, 3, 29, 20], fill=C("P44"))
    d.line([2, 3, 29, 3], fill=C("P46"))
    put_text(im, "공무원", 4, 3, "P09")
    put_text(im, "우선", 8, 11, "P09")
    return im


def w_grade_chart():
    """배급 등급표 · 2077(64×40, 벽 2칸): 누런 표 · 머리줄 · 등급 다섯 줄(색 점 + 막대 = 하루 배급량) · 5등급 줄은 막대 대신 빨간 '대기'."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 62, 38], fill=C(INK)); d.rectangle([2, 2, 61, 37], fill=C("P22"))
    d.rectangle([2, 2, 61, 10], fill=C("P21"))
    put_text(im, "배급 등급", 4, 2, "P01")
    for g in range(1, 6):
        y = 12 + (g - 1) * 5
        d.rectangle([5, y, 8, y + 3], fill=C(GRADE_COL[g]))
        if g < 5:
            d.rectangle([12, y + 1, 12 + (5 - g) * 10, y + 2], fill=C("P18"))
        else:
            put_text(im, "대기", 12, y - 4, "P53")
    d.point((4, 3), fill=C("P53")); d.point((59, 3), fill=C("P53"))
    return im


def guard_desk():
    """2077 상가 경비 초소 책상(64×44, 2×1): 철제 책상 · 무전기(꺼진 빨간 불 · 감긴 줄) · 경비 모자 · 손전등 · 빈 수첩 자리(먼지 없는 네모)."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 36, 62, 43], fill=C("P02"))
    d.rectangle([3, 16, 60, 38], fill=C(INK)); d.rectangle([4, 17, 59, 37], fill=C("P12"))   # 책상 앞판
    d.rectangle([3, 12, 60, 18], fill=C(INK)); d.rectangle([4, 13, 59, 17], fill=C("P14"))   # 상판
    d.line([4, 13, 59, 13], fill=C("P15"))
    d.rectangle([8, 22, 26, 33], fill=C("P11")); d.rectangle([12, 26, 22, 28], fill=C("P05"))  # 서랍
    d.rectangle([8, 2, 20, 13], fill=C(INK)); d.rectangle([9, 3, 19, 12], fill=C("P04"))      # 무전기
    d.line([17, 0, 17, 3], fill=C(INK)); d.point((11, 5), fill=C("P52"))
    for x in range(10, 18, 2):
        d.point((x, 9), fill=C("P02"))
    d.arc([18, 8, 30, 16], 0, 180, fill=C("P02"))                                             # 무전기 줄
    d.ellipse([33, 6, 47, 13], fill=C(INK)); d.ellipse([34, 7, 46, 12], fill=C("P44"))        # 경비 모자
    d.rectangle([37, 4, 43, 8], fill=C("P44")); d.point((40, 6), fill=C("P49"))
    d.rectangle([50, 9, 58, 12], fill=C(INK)); d.rectangle([51, 10, 57, 11], fill=C("P05")); d.point((58, 10), fill=C("P50"))  # 손전등
    d.rectangle([24, 13, 31, 16], fill=C("P15"))                                              # 수첩이 있던 자리(먼지 없는 네모)
    return im


def remains_guard(state=""):
    """경비복 유해(40×28): 벽에 기대 앉은 채 — 남색 경비복 · 가슴 노란 명찰 · 무릎 위 근무 수첩(taken이면 빈 손) · 옆 손전등."""
    im = img(40, 28)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 18, 38, 27], fill=C("P02"))
    d.polygon([(8, 8), (22, 6), (26, 19), (6, 21)], fill=C(INK))
    d.polygon([(9, 9), (21, 7), (24, 18), (7, 20)], fill=C("P44"))                           # 경비복
    d.line([9, 9, 21, 7], fill=C("P46"))
    d.rectangle([15, 11, 19, 13], fill=C("P49")); d.point((16, 12), fill=C("P01"))            # 명찰
    d.line([24, 17, 36, 21], fill=C("P11"), width=3); d.line([22, 19, 34, 24], fill=C("P11"), width=3)
    d.rectangle([34, 19, 37, 22], fill=C(INK)); d.rectangle([32, 22, 35, 25], fill=C(INK))
    d.ellipse([2, 2, 12, 11], fill=C(INK)); d.ellipse([3, 3, 11, 10], fill=C("P08"))
    d.point((5, 6), fill=C("P02")); d.point((8, 6), fill=C("P02")); d.line([5, 9, 9, 9], fill=C("P05"))
    if state != "taken":
        d.rectangle([20, 14, 26, 18], fill=C(INK)); d.rectangle([21, 15, 25, 17], fill=C("P20"))   # 근무 수첩
    d.rectangle([27, 23, 33, 25], fill=C(INK)); d.point((33, 24), fill=C("P07"))              # 손전등
    return im


def w_shutter_mem(state=""):
    """김민수 셔터(64×62, 벽 2칸): 닫힌 골 셔터(상호 띠 없음) — named: 흰 칠 글씨 두 줄 · 셔터 손잡이에 명찰 둘 · 아래 국화 다발과 초."""
    im = img(64, 62)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 61], fill=C("P03")); d.rectangle([2, 0, 61, 61], fill=C("P02"))
    d.rectangle([2, 2, 61, 12], fill=C("P04")); d.line([2, 12, 61, 12], fill=C(INK))
    d.rectangle([2, 13, 61, 18], fill=C("P05")); d.line([2, 13, 61, 13], fill=C("P07")); d.line([2, 18, 61, 18], fill=C(INK))
    for y in range(19, 61):
        d.line([3, y, 60, y], fill=C(["P07", "P06", "P05"][(y - 19) % 3]))
    d.line([3, 60, 60, 60], fill=C(INK))
    if state == "named":
        put_text(im, "김민수", 16, 22, "P09")
        put_text(im, "야간 경비", 10, 32, "P09")
        for x in (24, 34):                                                                    # 명찰 둘(손잡이에 줄로)
            d.line([x + 2, 44, x + 2, 48], fill=C("P05"))
            d.rectangle([x, 48, x + 5, 51], fill=C(INK)); d.rectangle([x + 1, 49, x + 4, 50], fill=C("P49"))
        for i, x in enumerate((8, 12, 47, 52)):                                               # 국화
            d.line([x, 61, x + 1, 54], fill=C("P30"))
            d.ellipse([x - 1, 51, x + 3, 55], fill=C("P09" if i % 2 else "P49"))
        d.rectangle([40, 55, 42, 60], fill=C("P09")); d.point((41, 54), fill=C("P60"))         # 초
    else:
        put_text(im, "", 0, 0, "P09")
    d.line([2, 0, 2, 61], fill=C("P05")); d.line([61, 0, 61, 61], fill=C(INK))
    return im


def sign_repair(state=""):
    """수리 노점 세움 간판(32×46): 합판 판 · 손글씨 '수리' + 이름 칸('김민수' → bong '봉 수리' 새 칠) · 렌치 그림 · 받침 다리."""
    im = img(32, 46)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 40, 28, 45], fill=C("P02"))
    d.line([7, 26, 4, 42], fill=C("P17"), width=2); d.line([25, 26, 28, 42], fill=C("P17"), width=2)
    d.rectangle([1, 2, 30, 28], fill=C(INK)); d.rectangle([2, 3, 29, 27], fill=C("P20"))
    d.line([2, 3, 29, 3], fill=C("P21"))
    if state == "bong":
        d.rectangle([3, 4, 28, 26], fill=C("P36"))                                            # 새 칠(청록)
        put_text(im, "봉", 11, 5, "P09")
        put_text(im, "수리", 6, 15, "P09")
    else:
        put_text(im, "수리", 6, 4, "P52")
        put_text(im, "김민수", 2, 15, "P02")
        d.line([4, 24, 27, 24], fill=C("P18"))
    d.line([22, 6, 27, 11], fill=C("P05"), width=2); d.ellipse([20, 4, 24, 8], fill=C("P05"))  # 렌치
    return im


def w_paper_name():
    """'본명 찾기 상담' 종이(32×30, 벽 1칸): 테이프 두 조각 · 함준호의 반듯한 글씨 · 아래 '관리사무소 · 06시~'."""
    im = img(32, 30)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 3, 28, 27], fill=C(INK)); d.rectangle([4, 4, 27, 26], fill=C("P09"))
    d.rectangle([12, 1, 19, 4], fill=C("P21"))
    put_text(im, "본명", 7, 4, "P02")
    put_text(im, "찾기", 7, 12, "P02")
    d.line([6, 22, 25, 22], fill=C("P06"))
    d.point((24, 24), fill=C("P53"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_S08 = {
    "queue_board": _r(queue_board, 2, 0, "wall", dx=0, dy=6),
    "queue_skel": _r(lambda: queue_skel(0), 0, 0, "deco"),
    "queue_skel2": _r(lambda: queue_skel(1), 0, 0, "deco"),
    "queue_skel3": _r(lambda: queue_skel(2), 0, 0, "deco"),
    "grade_line1": _r(lambda: grade_line(1), 0, 0, "deco"),
    "grade_line2": _r(lambda: grade_line(2), 0, 0, "deco"),
    "grade_line3": _r(lambda: grade_line(3), 0, 0, "deco"),
    "grade_line4": _r(lambda: grade_line(4), 0, 0, "deco"),
    "grade_line5": _r(lambda: grade_line(5), 0, 0, "deco"),
    "vip_sign": _r(vip_sign, 1, 1),
    "w_grade_chart": _r(w_grade_chart, 2, 0, "wall", dx=0, dy=2),
    "guard_desk": _r(guard_desk, 2, 1, down=-2),
    "remains_guard": _r(remains_guard, 0, 0, "deco"),
    "w_shutter_mem": _r(w_shutter_mem, 2, 0, "wall", dx=0, dy=2),
    "sign_repair": _r(sign_repair, 1, 1),
    "w_paper_name": _r(w_paper_name, 1, 0, "wall", dx=0, dy=2),
}

STATES_S08 = {
    "queue_board": {"next": lambda: queue_board("next"), "skip": lambda: queue_board("skip")},
    "remains_guard": {"taken": lambda: remains_guard("taken")},
    "w_shutter_mem": {"named": lambda: w_shutter_mem("named")},
    "sign_repair": {"bong": lambda: sign_repair("bong")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_s08.png"
    ims = [v["fn"]() for v in PROPS_S08.values()] + [f() for st in STATES_S08.values() for f in st.values()]
    W = sum(i.width for i in ims) + 6 * len(ims)
    Hh = max(i.height for i in ims)
    sheet = Image.new("RGBA", (W, Hh + 4), C("P04"))
    x = 2
    for i in ims:
        sheet.alpha_composite(i, (x, 2))
        x += i.width + 6
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    sheet.save(out)
    print(out)
