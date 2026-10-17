"""여의도 금탑 로비 · 지하 수족관 소품(단계 1-D5a, 1-D 계획 §11 · SD-09a L-R02-05 · SD-16 아이작풍).
  revolving_kt    금빛 회전문(3×2): 금테 원통 · 유리 날개 넷 / 상태 turn(날개가 45도 돈 컷 — 삐걱)
  info_desk_kt    안내 데스크(4×1): 흰 대리석 곡면 · 금빛 탑 로고 · 안내 책자 꽂이 · '오늘의 관람' 판
  souvenir_kt     기념품 진열대(2×1): 금박 모형 탑 · 엽서 · 금 초콜릿 상자 / 상태 empty(빈 껍데기만)
  queue_kt        관람객 줄 난간(3×1): 금빛 기둥 넷 · 붉은 띠(가운데 끊김)
  stroller_kt     유모차(1×1): 줄이 끊긴 자리에 남은 것
  w_elev_kt       승강기 문(벽 2칸): 놋쇠 문 · 층 표시 바늘 / 상태 open(검은 승강로 — 칸이 아래로 꺼짐 · 정원 초과 붉은 등)
  w_cargo_kt      화물 승강기(벽 3칸): 잿빛 철문 · '화물 — 정원 15명' / 상태 live(초록 등 · 문 틈 빛)
  ant_soil_kt     개미 흙벽(2×1): 비상계단을 막은 흙 · 구멍 · 긁힌 자국 · 반짝이는 냄새 줄 / 상태 quiet(구멍이 흙으로 막힘 — 여왕 처리 뒤)
  scent_kt        냄새 길(덧그림 64×16): 바닥의 희미한 반짝임 점선
  w_intercom_kt   전망대 직통 인터폰(벽 1칸): 놋쇠 판 · 둥근 스피커 · 버튼 / 상태 lit(통화 중 — 등)
  safe_kt         기념품 가게 금고(1×1) / 상태 open
  tank_kt         큰 수조(4×2): 두꺼운 유리 · 물 · 수초 · 산호 돌 / 상태 broken(금 가고 물이 반 · 바닥에 샘) · dry(빈 수조 · 마른 수초)
  w_coral_kt      산호 벽(벽 2칸): 2077 수족관 장식 벽 — 색 바랜 산호 · 물고기 그림
  pump_kt         펌프실 비상 발전기 + 배수 펌프(2×1) / 상태 drain(배수로 돎 — 관에 물) · lift(승강기로 — 전선에 불) · gone(연료 통 자리가 빔)
  w_feedlog_kt    사육사 먹이 주기 일지(벽 1칸) · grate_kt 수조 위 직원 철망 발판(덧그림) · w_staff_phone_kt 관내 직원 인터폰(벽 1칸) / 상태 lit
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다. 위에서 빛(위 밝게 · 아래 어둡게), 반투명 없음."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
GOLD = ("P47", "P48", "P49", "P50")          # 금빛(어둠 → 빛)
MARBLE = ("P06", "P07", "P08", "P09")
WATER = ("P33", "P34", "P35", "P36", "P37")


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def _box(d, x0, y0, x1, y1, ramp, top=True):
    """먹선 상자 · 위 밝은 띠 · 아래 그늘."""
    d.rectangle([x0, y0, x1, y1], fill=C(INK))
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=C(ramp[1]))
    if top:
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=C(ramp[-1]))
    d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=C(ramp[0]))


# ================================================================================================ 로비
def revolving_kt(state=""):
    """금빛 회전문(3×2, 96×80): 위 금테 원통 지붕 · 둥근 바닥판 · 유리 날개 넷(위에서 본 +자 → 비스듬히) · 기둥 둘.
    상태 turn = 날개가 45도 돈 컷(X자) — 한 칸 돌 때 번갈아 보여 삐걱 돈다 · trapped = 날개 칸에 일개미가 갇혔다 · broken = 날개 하나의 유리가 깨져 비고 바닥에 유리 조각(개미가 큰턱으로 깨고 나간 뒤)."""
    im = img(96, 80)
    d = ImageDraw.Draw(im)
    _shadow(d, 6, 90, 76)
    d.ellipse([6, 44, 89, 75], fill=C(INK)); d.ellipse([7, 45, 88, 74], fill=C("P05"))           # 바닥판
    d.ellipse([12, 48, 83, 71], fill=C("P06"))
    cx, cy = 47, 59
    turn = state == "turn"
    wings = [(-34, 0), (34, 0), (0, -12), (0, 12)] if not turn else [(-24, -9), (24, 9), (-24, 9), (24, -9)]
    for wi, (wx, wy) in enumerate(wings):                                                       # 유리 날개(먹선 + 하늘빛 판 · 금테)
        d.line([cx, cy - 22, cx + wx, cy + wy - 22], fill=C(GOLD[1]), width=2)
        d.line([cx, cy, cx + wx, cy + wy], fill=C(GOLD[1]), width=2)
        if state == "trapped" and wi == 1:                                                        # 날개 칸 안에 일개미(검은 몸 · 더듬이)가 갇혔다
            mx, my = cx + wx // 2, cy + wy // 2 - 8
            d.ellipse([mx - 9, my - 3, mx - 1, my + 4], fill=C(INK)); d.ellipse([mx - 1, my - 3, mx + 5, my + 3], fill=C("P02"))
            d.ellipse([mx + 5, my - 4, mx + 11, my + 2], fill=C(INK))
            d.line([mx + 10, my - 3, mx + 14, my - 8], fill=C(INK)); d.line([mx + 9, my - 3, mx + 11, my - 9], fill=C(INK))
            for lx in (mx - 4, mx, mx + 3):
                d.line([lx, my + 3, lx - 2, my + 7], fill=C(INK))
        if state == "broken" and wi == 1:
            d.line([cx + wx, cy + wy - 22, cx + wx, cy + wy], fill=C(GOLD[0]), width=2)
            for k in range(6):
                d.point((cx + wx // 2 + k * 3 - 6, cy + 8 + (k % 3)), fill=C("P15"))
            continue
        for k in range(1, 6):
            t = k / 6
            d.line([cx + wx * t, cy + wy * t - 21, cx + wx * t, cy + wy * t - 1], fill=C("P14" if k % 2 else "P15"))
    d.rectangle([cx - 2, cy - 24, cx + 2, cy], fill=C(GOLD[2])); d.line([cx - 2, cy - 24, cx - 2, cy], fill=C(INK))
    for x in (6, 86):                                                                           # 기둥
        d.rectangle([x, 14, x + 4, 66], fill=C(INK)); d.rectangle([x + 1, 15, x + 3, 65], fill=C(GOLD[1])); d.line([x + 1, 15, x + 1, 65], fill=C(GOLD[3]))
    d.ellipse([2, 4, 93, 26], fill=C(INK)); d.ellipse([3, 5, 92, 25], fill=C(GOLD[1]))            # 원통 지붕
    d.ellipse([6, 7, 89, 21], fill=C(GOLD[2])); d.line([14, 9, 80, 9], fill=C(GOLD[3]))
    put_text(im, "금빛", 38, 8, "P47", 8, "Galmuri7")
    return im


def info_desk_kt():
    """안내 데스크(4×1, 128×52): 흰 대리석 곡면 앞판 · 금빛 탑 로고 · 위 책자 꽂이 · 뒤 '오늘의 관람' 세움판(60층 14:00~22:00 · 수족관 10:00~19:00)."""
    im = img(128, 52)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 124, 48)
    _box(d, 70, 0, 120, 22, ("P02", "P10", "P11"))                                             # 세움판
    put_text(im, "오늘의관람", 74, 2, "P50", 8, "Galmuri7")
    d.line([74, 13, 116, 13], fill=C("P13")); d.line([74, 17, 108, 17], fill=C("P13"))
    d.rectangle([4, 20, 123, 46], fill=C(INK))
    for x in range(5, 123):                                                                    # 곡면 앞판(가운데가 밝다 — 둥근 면)
        t = abs(x - 64) / 60
        col = MARBLE[3] if t < 0.3 else (MARBLE[2] if t < 0.7 else MARBLE[1])
        d.line([x, 24, x, 45], fill=C(col))
    d.rectangle([5, 21, 122, 24], fill=C("P09")); d.line([5, 25, 122, 25], fill=C(INK))         # 상판
    rnd = random.Random(5)
    for _ in range(9):                                                                          # 대리석 결
        x = rnd.randint(8, 118); y = rnd.randint(28, 42)
        d.line([x, y, x + rnd.randint(3, 8), y + rnd.randint(-1, 2)], fill=C("P06"))
    d.polygon([(60, 42), (64, 28), (68, 42)], fill=C(GOLD[2])); d.line([64, 28, 64, 42], fill=C(GOLD[3]))   # 금빛 탑 로고
    d.line([60, 42, 64, 28], fill=C(INK)); d.line([68, 42, 64, 28], fill=C(INK))
    for i, x in enumerate((14, 22, 30)):                                                       # 책자 꽂이
        d.rectangle([x, 14, x + 6, 22], fill=C(INK)); d.rectangle([x + 1, 15, x + 5, 21], fill=C(("P49", "P46", "P54")[i]))
    return im


def souvenir_kt(state=""):
    """기념품 진열대(2×1, 64×56): 유리 진열장 두 단 · 금박 모형 탑 셋 · 엽서 꽂이 · 금 초콜릿 상자.
    상태 empty = 모형 탑 하나만 넘어져 있고 상자는 뜯긴 빈 껍데기."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 52)
    _box(d, 2, 4, 61, 50, ("P02", "P04", "P06"))
    for y in (8, 26):                                                                           # 유리 단
        d.rectangle([5, y, 58, y + 15], fill=C("P11")); d.line([5, y, 58, y], fill=C("P14")); d.line([6, y + 2, 12, y + 2], fill=C("P15"))
    empty = state == "empty"
    for i, x in enumerate((10, 26, 42)):
        if empty and i != 1:
            continue
        if empty:
            d.polygon([(x - 2, 22), (x + 12, 19), (x + 12, 22)], fill=C(GOLD[2])); d.line([x - 2, 22, x + 12, 19], fill=C(INK))
            continue
        d.polygon([(x, 22), (x + 4, 10), (x + 8, 22)], fill=C(GOLD[2])); d.line([x + 4, 10, x + 4, 22], fill=C(GOLD[3]))
        d.line([x, 22, x + 4, 10], fill=C(INK)); d.line([x + 8, 22, x + 4, 10], fill=C(INK))
    for i, x in enumerate((8, 20, 32)):                                                          # 금 초콜릿 상자
        d.rectangle([x, 33, x + 9, 40], fill=C(INK)); d.rectangle([x + 1, 34, x + 8, 39], fill=C(GOLD[1] if not empty else "P05"))
        if empty:
            d.line([x + 1, 34, x + 8, 39], fill=C(INK))
    for k in range(3):                                                                           # 엽서
        d.rectangle([46 + k * 4, 30 + k, 50 + k * 4, 38 + k], fill=C(("P46", "P09", "P55")[k])); d.rectangle([46 + k * 4, 30 + k, 50 + k * 4, 38 + k], outline=C(INK))
    return im


def queue_kt():
    """관람객 줄 난간(3×1, 96×36): 금빛 기둥 넷 · 붉은 띠 셋(가운데가 끊겨 바닥에 늘어짐)."""
    im = img(96, 36)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 92, 32)
    xs = (6, 34, 62, 88)
    for i in range(3):
        a, b = xs[i] + 2, xs[i + 1] + 1
        if i == 1:
            d.line([a, 10, a + 6, 22], fill=C("P52"), width=2); d.line([b, 10, b - 5, 24], fill=C("P52"), width=2)
            d.line([a + 6, 23, a + 12, 30], fill=C("P51"), width=2)
        else:
            d.line([a, 10, (a + b) // 2, 13], fill=C("P53"), width=2); d.line([(a + b) // 2, 13, b, 10], fill=C("P53"), width=2)
    for x in xs:
        d.ellipse([x - 3, 28, x + 5, 33], fill=C(INK)); d.ellipse([x - 2, 29, x + 4, 32], fill=C(GOLD[1]))
        d.rectangle([x, 6, x + 2, 30], fill=C(INK)); d.line([x + 1, 7, x + 1, 29], fill=C(GOLD[2]))
        d.ellipse([x - 1, 3, x + 3, 8], fill=C(GOLD[3]))
    return im


def stroller_kt():
    """유모차(1×1, 32×36): 2077 접이식 · 빛바랜 남색 덮개 · 바퀴 넷 · 손잡이 · 안에 작은 담요."""
    im = img(32, 36)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 28, 32)
    for x in (6, 22):
        d.ellipse([x - 3, 25, x + 4, 32], fill=C(INK)); d.ellipse([x - 1, 27, x + 2, 30], fill=C("P05"))
    d.line([7, 26, 24, 26], fill=C(INK)); d.line([24, 26, 28, 6], fill=C(INK), width=2); d.line([25, 6, 30, 6], fill=C(INK), width=2)
    d.pieslice([3, 6, 23, 30], 180, 360, fill=C(INK)); d.pieslice([4, 7, 22, 29], 180, 360, fill=C("P44"))   # 덮개
    d.line([5, 17, 21, 17], fill=C("P45")); d.line([8, 11, 18, 11], fill=C("P45"))
    d.rectangle([4, 17, 23, 24], fill=C(INK)); d.rectangle([5, 18, 22, 23], fill=C("P12"))
    d.rectangle([8, 18, 17, 21], fill=C("P41")); d.line([8, 18, 17, 18], fill=C("P42"))           # 담요
    return im


def w_elev_kt(state=""):
    """승강기 문(벽 2칸, 64×64): 놋쇠 미닫이 두 짝 · 위 반달 층 표시(바늘) · 옆 호출 단추.
    상태 open = 문이 반쯤 열려 검은 승강로 — 칸이 없다(아래로 꺼짐) · 문틀 위 '정원 초과' 붉은 등이 아직 켜져 있다."""
    im = img(64, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 0, 59, 63], fill=C(INK)); d.rectangle([5, 1, 58, 62], fill=C("P06"))
    d.pieslice([20, 2, 44, 22], 180, 360, fill=C(INK)); d.pieslice([21, 3, 43, 21], 180, 360, fill=C(GOLD[1]))
    d.line([32, 12, 38 if state != "open" else 24, 5], fill=C(INK))
    op = state == "open"
    if op:
        d.rectangle([10, 16, 53, 62], fill=C(INK))
        d.rectangle([12, 18, 51, 62], fill=C("P01"))
        for y in range(22, 62, 6):
            d.line([14, y, 16, y], fill=C("P02")); d.line([47, y + 2, 49, y + 2], fill=C("P02"))       # 승강로 벽 볼트
        d.line([30, 18, 30, 62], fill=C("P03")); d.line([33, 18, 33, 62], fill=C("P03"))             # 늘어진 줄
        d.rectangle([10, 16, 17, 62], fill=C(GOLD[0])); d.rectangle([46, 16, 53, 62], fill=C(GOLD[0]))
        d.rectangle([24, 8, 40, 13], fill=C(INK)); d.rectangle([25, 9, 39, 12], fill=C("P54"))
        put_text(im, "초과", 26, 7, "P50", 8, "Galmuri7")
    else:
        for x0 in (10, 32):
            d.rectangle([x0, 16, x0 + 21, 62], fill=C(INK)); d.rectangle([x0 + 1, 17, x0 + 20, 62], fill=C(GOLD[1]))
            d.line([x0 + 2, 18, x0 + 2, 61], fill=C(GOLD[3]))
            d.rectangle([x0 + 5, 26, x0 + 16, 52], outline=C(GOLD[0]))
    d.rectangle([56, 30, 59, 38], fill=C(INK)); d.point((57, 32), fill=C("P49")); d.point((57, 35), fill=C("P49"))
    return im


def w_cargo_kt(state=""):
    """화물 승강기(벽 3칸, 96×64): 잿빛 철 위아래 문 · 노랑 사선 띠 · '화물 — 정원 15명' 판 · 옆 등.
    상태 live = 등이 초록 · 문 아랫단 틈으로 빛 · 판에 '운행'."""
    im = img(96, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 0, 93, 63], fill=C(INK)); d.rectangle([3, 1, 92, 62], fill=C("P04"))
    d.rectangle([10, 10, 85, 62], fill=C(INK)); d.rectangle([11, 11, 84, 35], fill=C("P05")); d.rectangle([11, 37, 84, 62], fill=C("P05"))
    d.line([11, 36, 84, 36], fill=C(INK))
    for y in (11, 37):
        for x in range(12, 84, 8):
            d.line([x, y + 1, x + 4, y + 1], fill=C("P06"))
    for x in range(11, 84, 6):                                                                       # 노랑 사선 띠
        d.line([x, 58, x + 3, 61], fill=C("P49")); d.line([x + 1, 58, x + 4, 61], fill=C("P01"))
    d.rectangle([30, 2, 66, 9], fill=C("P09")); put_text(im, "화물15명", 31, 1, "P52", 8, "Galmuri7")
    live = state == "live"
    d.ellipse([86, 14, 92, 20], fill=C(INK)); d.ellipse([87, 15, 91, 19], fill=C("P56" if live else "P51"))
    if live:
        d.line([12, 61, 83, 61], fill=C("P50"))
    return im


def ant_soil_kt(state=""):
    """개미 흙벽(2×1, 64×64): 비상계단 입구를 막은 흙더미(위로 솟음) · 둥근 굴 구멍 셋 · 큰턱 긁은 자국 · 흙에 박힌 계단 난간 끝 · 앞에 반짝이는 냄새 줄.
    상태 quiet = 구멍이 흙으로 막히고 냄새 줄이 없다(여왕을 처리한 뒤)."""
    im = img(64, 64)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 60)
    rnd = random.Random(80)
    d.polygon([(0, 60), (4, 18), (14, 6), (30, 2), (48, 6), (60, 16), (63, 60)], fill=C(INK))
    d.polygon([(1, 59), (5, 19), (15, 7), (30, 3), (47, 7), (59, 17), (62, 59)], fill=C("P18"))
    for _ in range(140):                                                                             # 흙 알갱이(작은 덩이 · 위쪽 밝게)
        x = rnd.randint(4, 59); y = rnd.randint(8, 58)
        d.point((x, y), fill=C("P19" if y < 30 and rnd.random() < 0.6 else ("P17" if rnd.random() < 0.6 else "P20")))
    for k in range(6):                                                                               # 긁힌 자국
        x = 8 + k * 9; y = 22 + (k % 3) * 9
        d.line([x, y, x + 5, y + 6], fill=C("P16")); d.line([x + 2, y, x + 7, y + 6], fill=C("P16"))
    d.line([52, 4, 60, -2], fill=C("P05"), width=2)                                                  # 흙에 묻힌 난간 끝
    quiet = state == "quiet"
    for hx, hy, r in ((18, 40, 6), (40, 30, 5), (30, 52, 5)):
        if quiet:
            d.ellipse([hx - r, hy - r + 1, hx + r, hy + r - 1], fill=C("P17"))
            continue
        d.ellipse([hx - r - 1, hy - r - 1, hx + r + 1, hy + r + 1], fill=C("P16"))
        d.ellipse([hx - r, hy - r, hx + r, hy + r], fill=C(INK))
        d.arc([hx - r, hy - r, hx + r, hy + r], 200, 340, fill=C("P20"))
    if not quiet:
        for k in range(7):
            d.point((16 + k * 6, 61 - (k % 2)), fill=C("P57" if k % 2 else "P32"))
        for x, y in ((46, 54), (49, 56), (44, 57)):                                                  # 흙벽 아래 개미산이 녹인 자리(관찰하면 보이는 녹 자국)
            d.point((x, y), fill=C("P31"))
    if state == "dug":                                                                               # 사람이 지나갈 만큼 판 굴(계단참이 보인다)
        d.ellipse([16, 22, 48, 60], fill=C("P16")); d.ellipse([18, 24, 46, 60], fill=C(INK))
        d.line([22, 52, 42, 52], fill=C("P04")); d.line([24, 46, 40, 46], fill=C("P03"))             # 안쪽 계단 디딤
        for hx, hy in ((12, 58), (52, 58), (8, 50), (56, 52)):
            d.ellipse([hx - 4, hy - 3, hx + 4, hy + 3], fill=C("P19"))
    return im


def scent_kt():
    """냄새 길(덧그림 64×16): 개미가 남긴 페로몬 줄 — 바닥에 희미한 연두 반짝임 점선(듬성듬성 · 한 칸 걸러 밝은 점)."""
    im = img(64, 16)
    d = ImageDraw.Draw(im)
    rnd = random.Random(81)
    for x in range(1, 63, 3):
        y = 8 + int(2 * __import__("math").sin(x / 7.0)) + rnd.randint(-1, 1)
        d.point((x, y), fill=C("P57" if x % 9 == 1 else "P31"))
        if x % 9 == 1:
            d.point((x, y - 1), fill=C("P32"))
    return im


def w_intercom_kt(state=""):
    """전망대 직통 인터폰(벽 1칸, 32×44): 놋쇠 판 · 둥근 스피커 구멍 · 버튼 하나 · '60층 전망대 직통' 판.
    상태 lit = 버튼 위 등이 켜짐(통화 중)."""
    im = img(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 4, 25, 38], fill=C(INK)); d.rectangle([7, 5, 24, 37], fill=C(GOLD[1])); d.line([7, 5, 24, 5], fill=C(GOLD[3]))
    d.ellipse([10, 9, 21, 20], fill=C(INK)); d.ellipse([11, 10, 20, 19], fill=C(GOLD[0]))
    for yy in (12, 14, 16):
        for xx in (13, 15, 17):
            d.point((xx, yy), fill=C(INK))
    d.ellipse([12, 24, 19, 31], fill=C(INK)); d.ellipse([13, 25, 18, 30], fill=C("P53"))
    d.ellipse([14, 33, 17, 36], fill=C("P56" if state == "lit" else "P02"))
    d.rectangle([4, 36, 27, 47], fill=C(INK)); d.rectangle([5, 37, 26, 46], fill=C("P09")); put_text(im, "60층", 8, 38, "P04", 8, "Galmuri7")
    return im


def safe_kt(state=""):
    """기념품 가게 금고(1×1, 32×36): 작은 검은 금고 · 금빛 다이얼 · 손잡이 / 상태 open = 문이 열려 안이 빈 칸."""
    im = img(32, 36)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 28, 32)
    _box(d, 4, 6, 27, 31, ("P01", "P02", "P04"))
    if state == "open":
        d.rectangle([7, 9, 24, 28], fill=C("P01")); d.line([7, 9, 24, 9], fill=C("P03"))
        d.polygon([(24, 9), (31, 6), (31, 31), (24, 28)], fill=C("P03")); d.line([24, 9, 31, 6], fill=C(INK))
    else:
        d.ellipse([11, 12, 20, 21], fill=C(INK)); d.ellipse([12, 13, 19, 20], fill=C(GOLD[2])); d.point((15, 14), fill=C(INK))
        d.line([22, 18, 22, 25], fill=C(GOLD[1]), width=2)
    return im


# ================================================================================================ 지하 수족관
def tank_kt(state=""):
    """큰 수조(4×2, 128×80): 두꺼운 유리(위 테 · 반사 줄) · 푸른 물 · 바닥 모래 · 수초 · 산호 돌 · 거품.
    상태 broken = 앞 유리에 별 모양 금 · 물이 반으로 줄어 수면선 · 앞 바닥으로 샌 자국. dry = 물이 다 빠지고 수초가 누렇게 말라 누움."""
    im = img(128, 80)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 126, 76)
    d.rectangle([2, 4, 125, 74], fill=C(INK)); d.rectangle([3, 5, 124, 73], fill=C("P11"))
    lvl = {"": 10, "broken": 40, "dry": 80}.get(state, 10)
    for y in range(6, 73):                                                                             # 물(위 밝게 → 아래 짙게)
        if y < lvl:
            d.line([4, y, 123, y], fill=C("P12"))
            continue
        k = min(4, max(0, 4 - (y - lvl) // 9))
        d.line([4, y, 123, y], fill=C(WATER[k]))
    if lvl < 73:
        d.line([4, lvl, 123, lvl], fill=C("P37"))
    d.rectangle([4, 64, 123, 72], fill=C("P21")); d.line([4, 64, 123, 64], fill=C("P22"))              # 모래
    rnd = random.Random(82 + len(state))
    for i in range(7):                                                                                 # 수초
        x = 10 + i * 17 + rnd.randint(-3, 3)
        h = rnd.randint(18, 34)
        col = ("P31", "P30") if state != "dry" else ("P20", "P19")
        if state == "dry":
            d.line([x, 63, x + h // 2, 60], fill=C(col[0]))
            continue
        for j in range(h):
            xx = x + int(2 * __import__("math").sin(j / 4.0 + i))
            d.point((xx, 63 - j), fill=C(col[j % 2]))
    for x0, c in ((30, "P27"), (88, "P41")):                                                           # 바위 위 가지 산호
        d.ellipse([x0, 58, x0 + 18, 68], fill=C(INK)); d.ellipse([x0 + 1, 59, x0 + 17, 67], fill=C("P05" if state != "dry" else "P06"))
        d.line([x0 + 3, 61, x0 + 14, 61], fill=C("P07"))
        cc = c if state != "dry" else "P08"                                                            # 마르면 하얗게 바램
        for bx, h in ((x0 + 5, 14), (x0 + 9, 18), (x0 + 13, 12)):
            d.line([bx, 59, bx, 59 - h], fill=C(cc))
            for k in range(1, h // 4):
                yy = 59 - k * 4
                d.line([bx, yy, bx + (2 if k % 2 else -2), yy - 3], fill=C(cc))
            d.point((bx, 59 - h), fill=C("P42" if state != "dry" else "P09"))
    if state == "":
        for k in range(5):
            d.ellipse([110, 54 - k * 9, 112, 56 - k * 9], outline=C("P37"))
    d.rectangle([2, 2, 125, 6], fill=C(INK)); d.rectangle([3, 3, 124, 5], fill=C("P06"))               # 위 테
    d.line([8, 10, 8, 40], fill=C("P15")); d.line([10, 10, 10, 24], fill=C("P15"))                      # 유리 반사
    if state == "broken":
        cx, cy = 70, 46
        for a, b in ((-18, -10), (16, -12), (-12, 14), (20, 10), (2, -22), (-4, 20)):
            d.line([cx, cy, cx + a, cy + b], fill=C("P09"))
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=C("P09"))
        d.rectangle([60, 74, 100, 78], fill=C("P35")); d.line([60, 74, 100, 74], fill=C("P37"))
    return im


def w_coral_kt():
    """산호 벽(벽 2칸, 64×64): 2077 수족관 장식 벽 — 색 바랜 산호 가지 · 물고기 그림 셋 · 아래 '서울의 바다' 판."""
    im = img(64, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 63], fill=C(INK)); d.rectangle([1, 1, 62, 62], fill=C("P35"))
    for y in range(1, 62):
        if y % 6 == 0:
            d.line([1, y, 62, y], fill=C("P34"))
    rnd = random.Random(83)
    for x0, c in ((10, "P40"), (30, "P27"), (48, "P41")):
        d.line([x0, 58, x0, 34], fill=C(c), width=2)
        for k in range(4):
            yy = 54 - k * 6
            d.line([x0, yy, x0 + rnd.choice([-6, 6]), yy - 5], fill=C(c))
    for fx, fy, c in ((14, 14, "P49"), (40, 10, "P54"), (28, 24, "P46")):
        d.ellipse([fx, fy, fx + 9, fy + 5], fill=C(c)); d.polygon([(fx, fy + 2), (fx - 4, fy - 1), (fx - 4, fy + 5)], fill=C(c))
        d.point((fx + 7, fy + 2), fill=C(INK))
    d.rectangle([10, 50, 54, 62], fill=C(INK)); d.rectangle([11, 51, 53, 61], fill=C("P09")); put_text(im, "서울의바다", 13, 52, "P44", 8, "Galmuri7")
    return im


def pump_kt(state=""):
    """펌프실 비상 발전기 + 배수 펌프(2×1, 64×56): 왼쪽 붉은 발전기(연료 통 자리 · 계기) · 오른쪽 회색 펌프(굵은 관이 벽으로) · 사이 전환 손잡이.
    상태 drain = 발전기 등 켜짐 · 손잡이 '배수' · 관에 물 흐름 · lift = 손잡이 '승강기' · 전선에 노란 불꽃 · gone = 연료 통 자리가 비고 계기가 죽음."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 52)
    _box(d, 2, 16, 32, 48, ("P51", "P52", "P53"))                                                     # 발전기
    for y in range(20, 44, 4):
        d.line([5, y, 18, y], fill=C("P51"))
    run = state in ("drain", "lift")
    d.ellipse([21, 20, 29, 28], fill=C(INK)); d.ellipse([22, 21, 28, 27], fill=C("P09"))
    d.line([25, 24, 27 if run else 23, 21 if run else 26], fill=C("P53"))
    d.ellipse([22, 32, 27, 37], fill=C("P56" if run else "P02"))
    if state != "gone":                                                                               # 연료 통(초록 철통)
        d.rectangle([4, 4, 14, 16], fill=C(INK)); d.rectangle([5, 5, 13, 15], fill=C("P55")); d.line([6, 6, 12, 6], fill=C("P56"))
        d.line([9, 2, 9, 4], fill=C(INK))
    _box(d, 38, 22, 61, 48, ("P03", "P05", "P07"))                                                    # 펌프
    d.ellipse([42, 26, 56, 40], fill=C(INK)); d.ellipse([43, 27, 55, 39], fill=C("P06"))
    d.rectangle([50, 2, 56, 24], fill=C(INK)); d.rectangle([51, 3, 55, 23], fill=C("P05"))             # 굵은 관(위로)
    if state == "drain":
        for y in range(4, 22, 3):
            d.point((53, y), fill=C("P37"))
    d.rectangle([33, 30, 37, 44], fill=C(INK)); d.rectangle([34, 31, 36, 43], fill=C("P04"))           # 전환 손잡이
    hx = 30 if state == "lift" else (40 if state == "drain" else 35)
    d.line([35, 36, hx, 26], fill=C(INK), width=2); d.ellipse([hx - 2, 24, hx + 2, 28], fill=C("P49"))
    if state == "lift":
        d.line([4, 50, 30, 52, 60, 50], fill=C("P02"))
        for x in (12, 26, 44):
            d.point((x, 50), fill=C("P50")); d.point((x + 1, 49), fill=C("P49"))
    return im


def grate_kt():
    """수조 위 직원 철망 발판(덧그림 64×32 = 2×1): 녹슨 격자 · 가장자리 각철 · 틈으로 아래 물빛 — 관람객 눈에 안 띄는 사육사 길."""
    im = img(64, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 2, 63, 29], fill=C(INK))
    for y in range(3, 29):
        d.line([1, y, 62, y], fill=C(WATER[1] if y % 2 else WATER[2]))
    for x in range(2, 63, 4):
        d.line([x, 3, x, 28], fill=C("P04"))
    for y in range(4, 29, 4):
        d.line([1, y, 62, y], fill=C("P05"))
    d.line([0, 2, 63, 2], fill=C("P06")); d.line([0, 29, 63, 29], fill=C("P02"))
    rnd = random.Random(84)
    for _ in range(14):
        d.point((rnd.randint(2, 61), rnd.randint(4, 28)), fill=C("P25"))                              # 녹
    return im


def w_staff_phone_kt(state=""):
    """관내 직원 인터폰(벽 1칸, 32×48): 잿빛 플라스틱 수화기 걸이 · 꼬인 줄 · '관내 — 전망대 9' 쪽지 / 상태 lit = 등."""
    im = img(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([7, 6, 24, 34], fill=C(INK)); d.rectangle([8, 7, 23, 33], fill=C("P07")); d.line([8, 7, 23, 7], fill=C("P09"))
    d.rectangle([10, 9, 14, 30], fill=C(INK)); d.rectangle([11, 10, 13, 29], fill=C("P04"))            # 수화기
    for y in range(30, 42, 2):
        d.point((12 + (y // 2) % 2, y), fill=C(INK))                                                     # 꼬인 줄
    for r in range(3):
        for c in range(3):
            d.point((17 + c * 2, 12 + r * 3), fill=C("P03"))
    d.ellipse([17, 24, 21, 28], fill=C("P56" if state == "lit" else "P02"))
    d.rectangle([4, 36, 27, 47], fill=C(INK)); d.rectangle([5, 37, 26, 46], fill=C("P50")); put_text(im, "관내9", 6, 38, "P04", 8, "Galmuri7")
    return im


def grate_gate_kt(state=""):
    """직원 통로 철망 문(1×1, 32×48): 각철 틀 · 철망 · 붉은 '사육사 외' 띠 · 자물쇠(닫힌 판만 소품 — 열면 맵에서 빠진다)."""
    im = img(32, 48)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 30, 44)
    d.rectangle([3, 2, 28, 42], fill=C(INK)); d.rectangle([4, 3, 27, 41], fill=C("P04"))
    for x in range(6, 27, 3):
        d.line([x, 5, x, 39], fill=C("P06"))
    for y in range(6, 40, 3):
        d.line([5, y, 26, y], fill=C("P05"))
    d.rectangle([4, 18, 27, 23], fill=C("P52")); d.line([4, 18, 27, 18], fill=C("P53"))
    d.rectangle([20, 26, 26, 33], fill=C(INK)); d.rectangle([21, 27, 25, 32], fill=C("P48")); d.arc([21, 22, 25, 29], 180, 360, fill=C("P06"))
    return im


def w_feedlog_kt():
    """사육사 먹이 주기 일지(벽 1칸, 32×44): 클립보드 · 표 · 맨 아래 붉은 글씨 한 줄."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([5, 4, 26, 40], fill=C(INK)); d.rectangle([6, 5, 25, 39], fill=C("P09"))
    d.rectangle([11, 2, 20, 7], fill=C("P05")); d.line([11, 2, 20, 2], fill=C(INK))
    for y in range(11, 32, 4):
        d.line([8, y, 23, y], fill=C("P06")); d.line([14, y - 3, 14, y], fill=C("P06"))
    d.line([8, 35, 22, 35], fill=C("P53")); d.line([8, 37, 18, 37], fill=C("P53"))
    return im


# ================================================================================================ 1-D5b 위층(사무층 개미굴 · 22층 여왕방 · 연회장 · 60층 · 옥상)
def egg_mound_kt(state=""):
    """여왕방 알 무더기(3×2, 96×64): 흙 둔덕 위 젖빛 알 덩이 · 반짝이는 점액 · 둘레 흙 알갱이 / 상태 hatch(알 하나가 갈라져 일개미 머리)."""
    im = img(96, 64)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 92, 60)
    d.ellipse([2, 30, 93, 62], fill=C(INK)); d.ellipse([3, 31, 92, 61], fill=C("P18"))
    d.ellipse([10, 34, 86, 58], fill=C("P19"))
    rnd = random.Random(90)
    eggs = [(rnd.randint(16, 76), rnd.randint(18, 44)) for _ in range(16)]
    for i, (x, y) in enumerate(sorted(eggs, key=lambda e: e[1])):
        d.ellipse([x - 6, y - 4, x + 6, y + 5], fill=C(INK))
        d.ellipse([x - 5, y - 3, x + 5, y + 4], fill=C("P08"))
        d.ellipse([x - 3, y - 2, x + 1, y + 1], fill=C("P09"))
        if state == "hatch" and i == 9:
            d.line([x - 4, y, x + 4, y - 1], fill=C(INK)); d.ellipse([x - 3, y - 6, x + 3, y - 1], fill=C("P02"))
            d.line([x - 1, y - 6, x - 4, y - 10], fill=C("P02")); d.line([x + 1, y - 6, x + 4, y - 10], fill=C("P02"))
    for _ in range(10):
        x = rnd.randint(14, 80); y = rnd.randint(22, 48)
        d.point((x, y), fill=C("P57"))                                                            # 점액 반짝임
    return im


def telescope_kt(state=""):
    """60층 진공관 망원경(1×2, 32×64): 금빛 받침 · 굵은 경통 · 옆 진공관 함(유리관 셋) · 동전 투입구 / 상태 lit(관에 주황 불 · 렌즈 반짝)."""
    im = img(32, 64)
    d = ImageDraw.Draw(im)
    _shadow(d, 6, 26, 60)
    d.polygon([(10, 58), (16, 30), (22, 58)], fill=C(INK)); d.polygon([(11, 57), (16, 32), (21, 57)], fill=C(GOLD[1]))
    d.line([16, 32, 16, 57], fill=C(GOLD[3]))
    d.polygon([(4, 26), (24, 16), (28, 24), (8, 34)], fill=C(INK)); d.polygon([(5, 26), (24, 17), (27, 23), (8, 33)], fill=C("P04"))
    d.line([6, 26, 24, 18], fill=C("P06"))
    d.ellipse([22, 15, 30, 25], fill=C(INK)); d.ellipse([23, 16, 29, 24], fill=C("P15" if state == "lit" else "P12"))
    d.ellipse([13, 27, 19, 33], fill=C(GOLD[2])); d.point((16, 30), fill=C(INK))                       # 받침 이음쇠
    _box(d, 1, 38, 12, 52, ("P02", "P04", "P06"))
    lit = state == "lit"
    for k, x in enumerate((3, 6, 9)):
        d.rectangle([x, 40, x + 1, 47], fill=C("P59" if lit else "P13")); d.point((x, 39), fill=C("P15"))
    d.rectangle([4, 49, 9, 50], fill=C(INK))
    return im


def roof_gen_kt(state=""):
    """옥상 소형 원자력 발전기(3×2, 96×64): 국방색 함 · 방사능 표지 · 냉각 지느러미 · 계기판 · 굵은 전선이 망원경 쪽으로 / 상태 live(초록 등 · 계기 바늘)."""
    im = img(96, 64)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 92, 60)
    _box(d, 4, 14, 70, 56, ("P28", "P29", "P31"))
    for x in range(10, 66, 5):
        d.line([x, 18, x, 52], fill=C("P28"))
    d.ellipse([28, 24, 46, 42], fill=C(INK)); d.ellipse([29, 25, 45, 41], fill=C("P49"))
    for a in (90, 210, 330):
        import math as _m
        cx, cy = 37, 33
        d.pieslice([cx - 7, cy - 7, cx + 7, cy + 7], a - 30, a + 30, fill=C(INK))
    d.ellipse([35, 31, 39, 35], fill=C("P49"))
    _box(d, 72, 22, 92, 50, ("P02", "P04", "P06"))
    live = state == "live"
    d.ellipse([76, 26, 86, 36], fill=C(INK)); d.ellipse([77, 27, 85, 35], fill=C("P09"))
    d.line([81, 31, 84 if live else 78, 28 if live else 34], fill=C("P53"))
    d.ellipse([78, 40, 84, 46], fill=C("P56" if live else "P51"))
    d.line([92, 44, 95, 60], fill=C(INK), width=2)
    return im


def gondola_kt(state=""):
    """바깥 유리창 청소 곤돌라(3×1, 96×40): 철 바구니 · 난간 · 위로 쇠줄 둘 · 녹 · 걸레 양동이 / 상태 tilt(줄 하나가 끊겨 기운 판)."""
    im = img(96, 40)
    d = ImageDraw.Draw(im)
    tilt = 6 if state == "tilt" else 0
    d.line([12, 0, 12, 14 + tilt], fill=C("P05")); d.line([84, 0, 84, 14], fill=C("P05") if tilt == 0 else C("P03"))
    d.polygon([(4, 16 + tilt), (92, 16), (92, 36), (4, 36 + tilt)], fill=C(INK))
    d.polygon([(5, 17 + tilt), (91, 17), (91, 35), (5, 35 + tilt)], fill=C("P05"))
    for x in range(8, 90, 8):
        d.line([x, 18 + tilt * (92 - x) // 88, x, 34 + tilt * (92 - x) // 88], fill=C("P04"))
    d.line([5, 17 + tilt, 91, 17], fill=C("P07"))
    rnd = random.Random(91)
    for _ in range(18):
        d.point((rnd.randint(6, 90), rnd.randint(18, 34)), fill=C("P25"))
    d.rectangle([40, 24, 48, 32], fill=C(INK)); d.rectangle([41, 25, 47, 31], fill=C("P45"))
    return im


def banquet_kt(state=""):
    """2077 연회장 원탁(2×2, 64×64): 흰 식탁보 · 접시 · 잔 · 금빛 촛대 · 의자 둘레(넘어진 것 하나) / 상태 bones(식탁에 엎드린 해골 · 넘어진 잔)."""
    im = img(64, 64)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 60, 58)
    d.ellipse([4, 14, 59, 50], fill=C(INK)); d.ellipse([5, 15, 58, 49], fill=C("P09"))
    d.ellipse([5, 30, 58, 49], fill=C("P08"))
    for k in range(8):
        import math as _m
        a = k / 8 * 6.283
        x = 31 + int(20 * _m.cos(a)); y = 31 + int(12 * _m.sin(a))
        d.ellipse([x - 4, y - 2, x + 4, y + 2], fill=C("P07")); d.ellipse([x - 2, y - 1, x + 2, y + 1], fill=C("P09"))
    d.rectangle([30, 18, 32, 30], fill=C(GOLD[1])); d.ellipse([28, 15, 34, 20], fill=C(GOLD[2]))
    if state == "bones":
        d.ellipse([12, 24, 24, 32], fill=C("P08")); d.ellipse([14, 22, 22, 28], fill=C("P09"))
        d.point((16, 25), fill=C(INK)); d.point((19, 25), fill=C(INK))
        d.line([40, 34, 46, 38], fill=C("P46"))
    for x, y in ((2, 50), (54, 50), (28, 54)):
        d.rectangle([x, y, x + 8, y + 8], fill=C(INK)); d.rectangle([x + 1, y + 1, x + 7, y + 7], fill=C("P52"))
    return im


def cubicle_kt(state=""):
    """사무층 칸막이 책상 묶음(2×2, 64×64): 회색 칸막이 · 책상 둘 · 진공관 단말 · 서류 더미 / 상태 ant(칸막이가 큰턱에 뜯기고 흙이 쌓임 · 서류가 굴 재료로 끌려감)."""
    im = img(64, 64)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 60)
    ant = state == "ant"
    for x0 in (2, 33):
        _box(d, x0, 22, x0 + 28, 56, ("P04", "P06", "P08"))
        d.rectangle([x0 + 4, 26, x0 + 14, 34], fill=C(INK)); d.rectangle([x0 + 5, 27, x0 + 13, 33], fill=C("P11" if not ant else "P02"))
        d.line([x0 + 6, 29, x0 + 12, 29], fill=C("P56") if not ant else C("P03"))
        for k in range(3):
            d.rectangle([x0 + 17 + k, 30 - k * 2, x0 + 25, 32 - k * 2], fill=C("P09"))
    d.rectangle([0, 4, 63, 22], fill=C(INK)); d.rectangle([1, 5, 62, 21], fill=C("P13"))       # 칸막이 판
    for x in range(4, 62, 6):
        d.line([x, 6, x, 20], fill=C("P12"))
    if ant:
        d.polygon([(18, 4), (30, 4), (26, 14), (22, 10)], fill=C(INK))                              # 뜯긴 자리
        rnd = random.Random(92)
        d.ellipse([20, 44, 46, 62], fill=C(INK)); d.ellipse([21, 45, 45, 61], fill=C("P18"))
        for _ in range(40):
            d.point((rnd.randint(22, 44), rnd.randint(46, 60)), fill=C("P19" if rnd.random() < 0.5 else "P17"))
    return im


def soil_pillar_kt():
    """여왕방 흙 기둥(1×1, 32×64): 개미가 침으로 쌓아 올린 기둥 · 둥근 마디 · 숨구멍 — 엄폐물."""
    im = img(32, 64)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 28, 60)
    rnd = random.Random(93)
    for k in range(6):
        y = 8 + k * 9
        w = 10 + (k % 2) * 2
        d.ellipse([16 - w - 1, y - 1, 16 + w + 1, y + 12], fill=C(INK))
        d.ellipse([16 - w, y, 16 + w, y + 11], fill=C("P18" if k % 2 else "P19"))
    for _ in range(70):
        x = rnd.randint(6, 26); y = rnd.randint(10, 60)
        d.point((x, y), fill=C("P20" if y < 30 else "P17"))
    for hx, hy in ((12, 24), (19, 40), (14, 52)):
        d.ellipse([hx - 2, hy - 2, hx + 2, hy + 2], fill=C(INK))
    return im


def ant_hole_kt():
    """사무층 바닥을 뚫은 개미 굴(덧그림 64×32 = 2×1): 깨진 타일 테두리 · 검은 굴 입구 · 둘레 흙 알갱이."""
    im = img(64, 32)
    d = ImageDraw.Draw(im)
    rnd = random.Random(94)
    d.ellipse([10, 6, 54, 28], fill=C("P18"))
    for _ in range(40):
        d.point((rnd.randint(8, 56), rnd.randint(4, 30)), fill=C("P19" if rnd.random() < 0.5 else "P17"))
    d.ellipse([18, 10, 46, 24], fill=C(INK)); d.ellipse([20, 12, 44, 23], fill=C("P01"))
    d.arc([18, 10, 46, 24], 200, 340, fill=C("P20"))
    for x in (12, 50):
        d.polygon([(x - 4, 8), (x + 4, 6), (x + 2, 12)], fill=C("P07"))
    return im


def w_north_sign_kt():
    """60층 망원경 옆 안내판(벽 2칸, 64×44): 2077 '맑은 날 북한 땅이 보입니다' — '북한' 위에 누가 매직으로 줄을 긋고 '북방'."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 61, 40], fill=C(INK)); d.rectangle([3, 5, 60, 39], fill=C("P09"))
    d.rectangle([3, 5, 60, 11], fill=C(GOLD[1]))
    put_text(im, "맑은날", 6, 13, "P44", 8, "Galmuri7")
    put_text(im, "북한", 6, 24, "P44", 8, "Galmuri7"); d.line([5, 29, 24, 28], fill=C(INK), width=2)
    put_text(im, "북방", 28, 23, "P53", 8, "Galmuri7")
    return im



# ================================================================================================ 1-D5b 위층(사무층 분양 홍보관 · 연회장 · 전망대 · 옥상 · 기단 옥상)
def model_kt(state=""):
    """분양 홍보관 금박 모형(2×2, 64×72): 검은 받침 위 유리 상자 · 금빛 60층 탑 모형 · 둘레 잿빛 작은 건물 · 파란 강 띠 · 명판 '금빛 빌딩 분양'.
    상태 ant = 유리가 깨지고 탑 모형이 꺾여 누움 · 받침에 흙(개미가 금박을 뜯어 갔다)."""
    im = img(64, 72)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 68)
    ant = state == "ant"
    _box(d, 2, 50, 61, 66, ("P01", "P02", "P04"))
    put_text(im, "분양", 24, 55, GOLD[2], 8, "Galmuri7")
    d.rectangle([4, 40, 59, 50], fill=C(INK)); d.rectangle([5, 41, 58, 49], fill=C("P05"))
    d.rectangle([5, 45, 58, 47], fill=C(WATER[3]))                                                  # 강 띠
    for x, h in ((8, 6), (14, 9), (44, 7), (50, 10), (55, 5)):
        d.rectangle([x, 44 - h, x + 4, 44], fill=C(INK)); d.rectangle([x + 1, 45 - h, x + 3, 43], fill=C("P07"))
    if not ant:
        d.polygon([(26, 44), (30, 6), (34, 6), (38, 44)], fill=C(INK))
        d.polygon([(27, 43), (30, 8), (34, 8), (37, 43)], fill=C(GOLD[1]))
        d.line([30, 9, 28, 42], fill=C(GOLD[3])); d.line([33, 9, 35, 30], fill=C(GOLD[2]))
        for y in range(12, 42, 4):
            d.line([28 + (42 - y) // 12, y, 36 - (42 - y) // 12, y], fill=C(GOLD[0]))
    else:
        d.polygon([(18, 42), (46, 34), (47, 38), (19, 46)], fill=C(INK))                             # 꺾여 누운 탑
        d.polygon([(19, 43), (46, 35), (46, 37), (20, 45)], fill=C(GOLD[1]))
        rnd = random.Random(95)
        for _ in range(26):
            d.point((rnd.randint(6, 58), rnd.randint(42, 49)), fill=C("P18" if rnd.random() < 0.6 else "P19"))
    d.rectangle([3, 2, 60, 41], outline=C("P15"))                                                    # 유리 상자 테
    d.line([4, 3, 4, 40], fill=C("P09")); d.line([5, 3, 20, 3], fill=C("P09"))
    if ant:
        d.line([40, 2, 48, 18], fill=C("P15")); d.line([48, 18, 44, 30], fill=C("P15")); d.line([48, 18, 58, 20], fill=C("P15"))
    return im


def sales_booth_kt():
    """분양 상담 부스(2×1, 64×48): 흰 곡면 탁자 · 금빛 탑 표지 · 팸플릿 꽂이 · 상담 의자 둘 · '분양 상담' 판."""
    im = img(64, 48)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 44)
    d.rectangle([2, 2, 61, 12], fill=C(INK)); d.rectangle([3, 3, 60, 11], fill=C(GOLD[1]))
    put_text(im, "분양상담", 13, 3, "P01", 8, "Galmuri7")
    _box(d, 2, 16, 61, 36, MARBLE)
    d.rectangle([6, 20, 14, 30], fill=C(INK)); d.rectangle([7, 21, 13, 29], fill=C("P46"))            # 팸플릿
    d.rectangle([16, 20, 24, 30], fill=C(INK)); d.rectangle([17, 21, 23, 29], fill=C(GOLD[2]))
    d.polygon([(44, 32), (48, 18), (52, 32)], fill=C(INK)); d.polygon([(45, 31), (48, 20), (51, 31)], fill=C(GOLD[2]))
    for x in (8, 40):
        d.ellipse([x, 36, x + 14, 46], fill=C(INK)); d.ellipse([x + 1, 37, x + 13, 45], fill=C("P53"))
    return im


def w_quote_kt():
    """분양 시세판(벽 3칸, 96×44): 2077 '금빛 빌딩 — 전 세대 완판' · 층별 분양가 줄 · 맨 아래 '10월 23일 계약분 입주 11월' — 누군가 숫자를 손톱으로 긁었다."""
    im = img(96, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 3, 94, 41], fill=C(INK)); d.rectangle([2, 4, 93, 40], fill=C("P02"))
    d.rectangle([2, 4, 93, 11], fill=C(GOLD[1]))
    put_text(im, "전세대완판", 26, 4, "P01", 8, "Galmuri7")
    rnd = random.Random(96)
    for r in range(5):
        y = 15 + r * 5
        put_text(im, str(60 - r * 10), 5, y - 2, GOLD[3], 8, "Galmuri7")
        for k in range(rnd.randint(4, 7)):
            d.rectangle([24 + k * 9, y, 30 + k * 9, y + 2], fill=C("P56" if r else "P49"))
    for k in range(5):
        d.line([60 + k * 3, 14, 56 + k * 3, 38], fill=C("P05"))                                      # 긁힌 자국
    return im


def exhibit_kt(state=""):
    """12층 어린이 과학관 전시대(2×1, 64×56): 유리 반구 아래 장난감 광선총 · 받침 명판 '광선총의 원리' · 옆 책 받침(책 한 권) / 상태 empty(책 받침이 빔)."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 52)
    _box(d, 2, 30, 61, 50, ("P43", "P44", "P46"))
    put_text(im, "광선총", 6, 36, "P09", 8, "Galmuri7")
    d.ellipse([6, 6, 40, 34], fill=C(INK)); d.ellipse([7, 7, 39, 33], fill=C("P11"))
    d.arc([8, 8, 38, 32], 190, 260, fill=C("P15"))
    d.rectangle([14, 20, 30, 24], fill=C(INK)); d.rectangle([15, 21, 29, 23], fill=C("P53"))           # 장난감 광선총
    d.rectangle([16, 24, 19, 29], fill=C(INK)); d.ellipse([28, 19, 33, 25], fill=C("P63"))
    d.rectangle([44, 16, 58, 30], fill=C(INK)); d.rectangle([45, 17, 57, 29], fill=C("P04"))
    if state != "empty":
        d.rectangle([47, 12, 56, 27], fill=C(INK)); d.rectangle([48, 13, 55, 26], fill=C("P54"))
        d.line([49, 15, 54, 15], fill=C("P09"))
    return im


def w_hose_kt(state=""):
    """소화전 함(벽 1칸, 32×44): 붉은 철함 · 유리 창 안에 감긴 호스 · '소화전' 글 / 상태 open(문이 열리고 호스가 풀려 바닥으로)."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 4, 28, 40], fill=C(INK)); d.rectangle([4, 5, 27, 39], fill=C("P53"))
    d.line([4, 5, 27, 5], fill=C("P54"))
    put_text(im, "소화전", 5, 6, "P09", 8, "Galmuri7")
    if state == "open":
        d.rectangle([6, 17, 25, 37], fill=C(INK))
        d.polygon([(26, 17), (31, 14), (31, 40), (26, 37)], fill=C("P52"))
        d.line([16, 30, 14, 43], fill=C("P08"), width=3)
    else:
        d.rectangle([6, 17, 25, 37], fill=C("P11"))
        for r in (8, 6, 4):
            d.ellipse([16 - r, 27 - r, 16 + r, 27 + r], outline=C("P08"))
        d.line([7, 18, 12, 18], fill=C("P15"))
    return im


def extinguisher_kt(state=""):
    """소화기(1×1, 32×40): 붉은 통 · 검은 손잡이 · 호스 · 압력계 / 상태 empty(쓰러져 있고 주둥이에 흰 가루)."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 6, 26, 36)
    if state == "empty":
        d.rounded_rectangle([4, 24, 26, 34], 4, fill=C(INK)); d.rounded_rectangle([5, 25, 25, 33], 3, fill=C("P52"))
        d.rectangle([26, 27, 29, 31], fill=C(INK))
        for k in range(6):
            d.point((28 + k % 3, 22 + k), fill=C("P09"))
        return im
    d.rounded_rectangle([10, 10, 22, 36], 4, fill=C(INK)); d.rounded_rectangle([11, 11, 21, 35], 3, fill=C("P53"))
    d.line([12, 12, 12, 33], fill=C("P54"))
    d.rectangle([12, 4, 20, 10], fill=C(INK)); d.line([20, 6, 26, 4], fill=C(INK), width=2)
    d.ellipse([13, 14, 19, 20], fill=C(INK)); d.ellipse([14, 15, 18, 19], fill=C("P09"))
    d.line([10, 12, 6, 26], fill=C(INK), width=2)
    return im


def w_banner_kt():
    """연회장 현수막(벽 4칸, 128×40): 진홍 바탕 금빛 글 '금빛 빌딩 개관 기념 만찬 2077.10.23' · 오른쪽 끝이 찢겨 늘어짐."""
    im = img(128, 40)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 6), (125, 6), (122, 28), (116, 36), (112, 26), (2, 30)], fill=C(INK))
    d.polygon([(3, 7), (124, 7), (121, 27), (116, 34), (112, 25), (3, 29)], fill=C("P52"))
    d.line([3, 8, 123, 8], fill=C("P53"))
    put_text(im, "개관기념만찬", 8, 10, GOLD[2], 8, "Galmuri7")
    put_text(im, "2077.10.23", 66, 10, GOLD[3], 8, "Galmuri7")
    d.line([3, 7, 3, 3], fill=C(INK)); d.line([124, 7, 124, 3], fill=C(INK))
    return im


def rope_line_kt():
    """60층 4번 승강기 앞 '정원 15명' 줄 난간(3×1, 96×40): 금빛 기둥 넷 · 붉은 벨벳 띠(끊기지 않음) · 가운데 판 '정원 15명'."""
    im = img(96, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 94, 36)
    for x in (4, 32, 60, 88):
        d.rectangle([x, 10, x + 4, 34], fill=C(INK)); d.rectangle([x + 1, 11, x + 3, 33], fill=C(GOLD[1]))
        d.ellipse([x - 1, 6, x + 5, 12], fill=C(GOLD[2])); d.rectangle([x - 2, 32, x + 6, 35], fill=C(INK))
    for a, b in ((6, 34), (34, 62), (62, 90)):
        d.arc([a, 10, b, 22], 0, 180, fill=C("P53"), width=2)
    d.rectangle([38, 22, 58, 31], fill=C(INK)); d.rectangle([39, 23, 57, 30], fill=C("P09"))
    put_text(im, "15", 43, 22, "P53", 8, "Galmuri7")
    return im


def w_glass_kt(state=""):
    """바깥 통유리(벽 2칸, 64×44): 금빛 창틀 · 밤하늘과 강 건너 불 꺼진 도시 실루엣 / 상태 broken(가운데가 깨져 바람 — 곤돌라로 들어온 자리)."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 62, 42], fill=C(INK)); d.rectangle([2, 3, 61, 41], fill=C("P43"))
    d.rectangle([2, 3, 61, 16], fill=C("P10"))
    rnd = random.Random(97)
    x = 2
    while x < 61:
        w = rnd.randint(3, 7); h = rnd.randint(4, 14)
        d.rectangle([x, 34 - h, x + w, 34], fill=C("P01"))
        x += w + 1
    d.rectangle([2, 34, 61, 41], fill=C(WATER[1]))
    d.line([32, 3, 32, 41], fill=C(GOLD[1])); d.rectangle([1, 2, 62, 3], fill=C(GOLD[2]))
    if state == "broken":
        d.polygon([(16, 12), (28, 8), (44, 14), (40, 30), (22, 32), (14, 24)], fill=C("P01"))
        for a, b in (((16, 12), (8, 6)), ((44, 14), (56, 8)), ((40, 30), (50, 38)), ((22, 32), (14, 40))):
            d.line([a, b], fill=C("P15"))
    else:
        d.line([5, 5, 14, 5], fill=C("P15")); d.line([35, 5, 40, 5], fill=C("P15"))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_KT = {
    "revolving_kt": _r(revolving_kt, 3, 2, down=-2),
    "info_desk_kt": _r(info_desk_kt, 4, 1, down=-2),
    "souvenir_kt": _r(souvenir_kt, 2, 1, down=-2),
    "queue_kt": _r(queue_kt, 3, 1, down=-2),
    "stroller_kt": _r(stroller_kt, 1, 1, down=-2),
    "w_elev_kt": _r(w_elev_kt, 2, 0, "wall", dx=0, dy=0),
    "w_cargo_kt": _r(w_cargo_kt, 3, 0, "wall", dx=0, dy=0),
    "ant_soil_kt": _r(ant_soil_kt, 2, 1, down=-2),
    "scent_kt": _r(scent_kt, 0, 0, "deco"),
    "w_intercom_kt": _r(w_intercom_kt, 1, 0, "wall", dx=0, dy=6),
    "safe_kt": _r(safe_kt, 1, 1, down=-2),
    "tank_kt": _r(tank_kt, 4, 2, down=-2),
    "w_coral_kt": _r(w_coral_kt, 2, 0, "wall", dx=0, dy=0),
    "pump_kt": _r(pump_kt, 2, 1, down=-2),
    "w_feedlog_kt": _r(w_feedlog_kt, 1, 0, "wall", dx=0, dy=6),
    "grate_kt": _r(grate_kt, 0, 0, "deco"),
    "grate_gate_kt": _r(grate_gate_kt, 1, 1, down=-2),
    "w_staff_phone_kt": _r(w_staff_phone_kt, 1, 0, "wall", dx=0, dy=6),
    "egg_mound_kt": _r(egg_mound_kt, 3, 2, down=-2),
    "telescope_kt": _r(telescope_kt, 1, 1, down=-2),
    "roof_gen_kt": _r(roof_gen_kt, 3, 2, down=-2),
    "gondola_kt": _r(gondola_kt, 3, 1, down=-2),
    "banquet_kt": _r(banquet_kt, 2, 2, down=-2),
    "w_north_sign_kt": _r(w_north_sign_kt, 2, 0, "wall", dx=0, dy=6),
    "cubicle_kt": _r(cubicle_kt, 2, 2, down=-2),
    "soil_pillar_kt": _r(soil_pillar_kt, 1, 1, down=-2),
    "ant_hole_kt": _r(ant_hole_kt, 0, 0, "deco"),
    "model_kt": _r(model_kt, 2, 2, down=-2),
    "sales_booth_kt": _r(sales_booth_kt, 2, 1, down=-2),
    "w_quote_kt": _r(w_quote_kt, 3, 0, "wall", dx=0, dy=6),
    "exhibit_kt": _r(exhibit_kt, 2, 1, down=-2),
    "w_hose_kt": _r(w_hose_kt, 1, 0, "wall", dx=0, dy=6),
    "extinguisher_kt": _r(extinguisher_kt, 1, 1, down=-2),
    "w_banner_kt": _r(w_banner_kt, 4, 0, "wall", dx=0, dy=6),
    "rope_line_kt": _r(rope_line_kt, 3, 1, down=-2),
    "w_glass_kt": _r(w_glass_kt, 2, 0, "wall", dx=0, dy=6),
}
STATES_KT = {
    "revolving_kt": {s: (lambda s=s: revolving_kt(s)) for s in ("turn", "broken", "trapped")},
    "souvenir_kt": {"empty": lambda: souvenir_kt("empty")},
    "w_elev_kt": {"open": lambda: w_elev_kt("open")},
    "w_cargo_kt": {"live": lambda: w_cargo_kt("live")},
    "ant_soil_kt": {s: (lambda s=s: ant_soil_kt(s)) for s in ("quiet", "dug")},
    "w_intercom_kt": {"lit": lambda: w_intercom_kt("lit")},
    "safe_kt": {"open": lambda: safe_kt("open")},
    "tank_kt": {s: (lambda s=s: tank_kt(s)) for s in ("broken", "dry")},
    "pump_kt": {s: (lambda s=s: pump_kt(s)) for s in ("drain", "lift", "gone")},
    "w_staff_phone_kt": {"lit": lambda: w_staff_phone_kt("lit")},
    "egg_mound_kt": {"hatch": lambda: egg_mound_kt("hatch")},
    "telescope_kt": {"lit": lambda: telescope_kt("lit")},
    "roof_gen_kt": {"live": lambda: roof_gen_kt("live")},
    "gondola_kt": {"tilt": lambda: gondola_kt("tilt")},
    "banquet_kt": {"bones": lambda: banquet_kt("bones")},
    "cubicle_kt": {"ant": lambda: cubicle_kt("ant")},
    "model_kt": {"ant": lambda: model_kt("ant")},
    "exhibit_kt": {"empty": lambda: exhibit_kt("empty")},
    "w_hose_kt": {"open": lambda: w_hose_kt("open")},
    "extinguisher_kt": {"empty": lambda: extinguisher_kt("empty")},
    "w_glass_kt": {"broken": lambda: w_glass_kt("broken")},
}


if __name__ == "__main__":
    out = sys.argv[1]
    ims = [f["fn"]() for f in PROPS_KT.values()] + [fn() for st in STATES_KT.values() for fn in st.values()]
    cols = 4
    rows = [ims[i:i + cols] for i in range(0, len(ims), cols)]
    W = max(sum(i.width + 4 for i in r) for r in rows) + 4
    H = sum(max(i.height for i in r) + 4 for r in rows) + 4
    sheet = Image.new("RGBA", (W, H), C("P05"))
    y = 2
    for r in rows:
        x = 2
        for i in r:
            sheet.alpha_composite(i, (x, y))
            x += i.width + 4
        y += max(i.height for i in r) + 4
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
