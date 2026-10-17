"""U02 남태령 지하 소품(단계 1-D2, 1-D 계획 §8 · SD-09f §3.2 U02 · §3.4 ST-1 · ST-5 · L-UG-05 · 훅 UG-H01 · UG-H02 · SD-16 아이작풍).
  w_name_ntr      역 이름판 '남태령'(벽 소품 3칸): 4호선 하늘색 동그라미 '4' · 앞뒤 역(사당 ← → 선바위)
  w_screen_door4  스크린도어(벽 소품 2칸): 4호선 하늘색 띠 · 유리 두 짝 · 먼지 · 아이 손바닥 / w_screen_door4b 깨진 판(금 · 테이프)
  train_car4      멈춘 4호선 전동차 1량(8×2 발): 스테인리스 몸통 · 하늘색 띠 · 창(안은 어둠) · 문 하나 반쯤 열림 · 행선판 '막차 · 과천'
  w_circuit_box   터널 조명 회로 함(벽 소품 1칸, UG-H01): 문 반쯤 열림 · 늘어진 전선 · 꺼진 표시등 둘
                  상태 sadang(사당 쪽 초록 하나) · full(둘 다 초록) · cut(초소 쪽 선이 끊기고 붉은 꼬리표)
  w_phone_box     비상 전화함(벽 소품 1칸, ST-5 LR 자리): 붉은 함 · 수화기 · '비상 전화 — 관제실 직통'
  hm_stove        할매 화로(1×1): 깡통 화로 · 숯불 · 찌그러진 주전자(김) · 곁에 컵 둘
  hm_shelf        할매 선반(1×1): 사과 상자 둘 포개 · 사탕 병 · 사진 액자 · 촛대 · 뜨개 바구니
  hm_cart         할매 짐수레(2×1): 손수레 · 보따리 · 과천 쪽 짐꾼과 바꾼 상자 · 끈에 끼운 쪽지
  w_hm_shaft      대피 측실 뒤 무너진 환기 갱(벽 소품 2칸, 밀통로 입구): 비스듬히 무너진 구멍 · 쇠 사다리 발판 · 위에서 새는 바람
                  상태 sealed(판자 · 노란 '계엄 봉인' 테이프) · collapsed(돌무더기로 메워짐 · 부러진 버팀목)
  w_chalk_roa     반로아 분필 화살표(벽 소품 1칸): '→ 로아' · 쥐 둥지 우회 표시
  w_chalk_height  키 재기 낙서(벽 소품 1칸): 분필 눈금 다섯 · '로아 9 · 10 · 11 · 12' · 맨 위 빈칸
  w_notice_ntr    개찰구 공문(벽 소품 2칸): 2077 안내문 '과천 방면 통행 등록증 확인'이 새 계엄 공문 밑에 비친다(SD-09f L-UG-05 환경)
  w_vent_nt       대합실 천장 환기구(벽 소품 1칸): 큰 격자 덮개 · 나사 넷 / 상태 open(덮개가 한쪽 나사에 매달려 젖혀짐 · 안쪽 덕트 어둠)
  bk_floor_hatch  막사 바닥 점검구(덧그림): 컨테이너 바닥 철판 뚜껑 · 손잡이 / 상태 open(뚜껑 젖힘 · 아래 어둠)
props_bc.PROPS에 합쳐져 r01_props 아틀라스로 나간다(prop_export.export_r01). 위에서 빛(위 밝게 · 아래 어둡게), 반투명 없음."""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import put_text, text_px

C = lambda t: P.rgb(t) + (255,)
INK = "P01"
LINE4 = ("P44", "P46", "P15")          # 4호선 하늘색(어둠 · 띠 · 빛) — 2호선 녹색(props_s05 LINE2)과 나란히 읽힌다


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, x0, x1, y):
    for x in range(x0, x1):
        for yy in (y, y + 1):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


# ================================================================================================ 승강장(ST-1)
def w_name_ntr():
    """역 이름판 '남태령'(벽 소품 3칸, 96×40): 흰 판 · 4호선 하늘색 동그라미 '4' · 아래 하늘색 띠에 앞뒤 역 · 녹물 한 줄."""
    im = img(96, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 6, 94, 36], fill=C(INK)); d.rectangle([2, 7, 93, 35], fill=C("P09"))
    d.rectangle([2, 26, 93, 35], fill=C(LINE4[1])); d.line([2, 26, 93, 26], fill=C(LINE4[0]))
    d.ellipse([5, 9, 19, 23], fill=C(LINE4[0])); d.ellipse([6, 10, 18, 22], fill=C(LINE4[1]))
    put_text(im, "4", 10, 11, "P09", 8, "Galmuri7")
    put_text(im, "남태령", 25, 9, "P01", 12, "Galmuri11")
    put_text(im, "‹사당", 4, 27, "P09", 8, "Galmuri7")
    _, w, _ = text_px("선바위›", 8, "Galmuri7")
    put_text(im, "선바위›", 92 - w, 27, "P09", 8, "Galmuri7")
    for x in range(8, 90, 13):
        d.point((x, 8), fill=C("P07"))
    d.line([88, 7, 89, 24], fill=C("P26")); d.line([89, 9, 89, 20], fill=C("P25"))              # 녹물
    d.line([71, 20, 78, 20], fill=C("P07"))                                                     # 판 금
    return im


def w_screen_door4(broken=False):
    """스크린도어(벽 소품 2칸, 64×56): 스테인리스 틀 · 유리 두 짝(너머 선로 어둠) · 4호선 하늘색 띠 · 먼지 줄 · 아이 손바닥.
    broken: 오른 짝 유리가 거미줄로 금 · 누가 테이프로 X를 붙였다(지나가는 구멍)."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 62, 54], fill=C(INK)); d.rectangle([2, 3, 61, 53], fill=C("P07"))
    d.rectangle([2, 3, 61, 6], fill=C("P08"))
    for x0 in (5, 33):
        d.rectangle([x0, 9, x0 + 25, 50], fill=C(INK)); d.rectangle([x0 + 1, 10, x0 + 24, 49], fill=C("P10"))
        d.line([x0 + 3, 12, x0 + 10, 30], fill=C("P13"))
        d.line([x0 + 4, 12, x0 + 11, 30], fill=C("P12"))
        for y in range(40, 49, 2):
            d.line([x0 + 1, y, x0 + 24, y], fill=C("P04") if y % 4 == 0 else C("P11"))
    d.rectangle([2, 30, 61, 33], fill=C(LINE4[1])); d.line([2, 30, 61, 30], fill=C(LINE4[2])); d.line([2, 33, 61, 33], fill=C(LINE4[0]))
    put_text(im, "4", 29, 26, "P09", 8, "Galmuri7")
    if broken:
        cx, cy = 46, 24
        for a, b in (((cx, cy), (36, 12)), ((cx, cy), (56, 13)), ((cx, cy), (57, 38)), ((cx, cy), (38, 44)), ((cx, cy), (47, 48))):
            d.line([*a, *b], fill=C("P09"))
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], outline=C("P15"))
        for (a, b) in (((35, 11), (57, 47)), ((57, 11), (35, 47))):                              # 누런 테이프 X
            d.line([*a, *b], fill=C("P21"), width=3); d.line([*a, *b], fill=C("P22"))
    else:
        d.rectangle([9, 18, 12, 22], fill=C("P15")); d.point((10, 17), fill=C("P15"))
        d.rectangle([14, 20, 16, 23], fill=C("P15"))
    return im


# ================================================================================================ 터널(ST-5)
def train_car4():
    """멈춘 4호선 전동차 1량(8×2 발, 260×88): 위에서 내려다본 옆모습 — 둥근 지붕(환기 돌기) · 스테인리스 몸통 · 하늘색 띠 ·
    창 줄(안은 어둠, 하나는 손전등에 비친 손잡이) · 문 넷 중 하나 반쯤 열림 · 오른끝 운전실 행선판 '막차 · 과천' · 바퀴 그늘."""
    rnd = random.Random(4404)
    W_, H_ = 260, 88
    im = img(W_, H_)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([4, 8, 255, 76], 10, fill=C(INK))
    d.rounded_rectangle([5, 9, 254, 75], 9, fill=C("P07"))                                   # 몸통(스테인리스)
    d.rounded_rectangle([5, 9, 254, 26], 9, fill=C("P08"))                                   # 지붕(위 빛)
    d.line([12, 10, 248, 10], fill=C("P09"))
    for x in range(30, 240, 46):                                                              # 지붕 환기 돌기
        d.rounded_rectangle([x, 12, x + 18, 20], 3, fill=C("P06")); d.line([x + 1, 12, x + 17, 12], fill=C("P08"))
        for xx in range(x + 3, x + 16, 3):
            d.line([xx, 14, xx, 18], fill=C("P05"))
    d.line([5, 27, 254, 27], fill=C("P05"))                                                   # 지붕 · 옆판 이음
    d.rectangle([5, 50, 254, 56], fill=C(LINE4[1])); d.line([5, 50, 254, 50], fill=C(LINE4[2])); d.line([5, 56, 254, 56], fill=C(LINE4[0]))
    doors = [(30, False), (88, True), (146, False), (204, False)]
    for x, open_ in doors:                                                                    # 출입문(양쪽 미닫이)
        d.rectangle([x, 29, x + 22, 72], fill=C(INK))
        if open_:
            d.rectangle([x + 1, 30, x + 21, 71], fill=C("P02"))
            d.rectangle([x + 1, 30, x + 5, 71], fill=C("P06")); d.rectangle([x + 17, 30, x + 21, 71], fill=C("P06"))
            d.line([x + 7, 60, x + 15, 60], fill=C("P04"))                                    # 안 바닥에 굴러다니는 가방끈
        else:
            d.rectangle([x + 1, 30, x + 10, 71], fill=C("P06")); d.rectangle([x + 12, 30, x + 21, 71], fill=C("P06"))
            d.line([x + 11, 30, x + 11, 71], fill=C(INK))
            for xx in (x + 3, x + 14):
                d.rectangle([xx, 33, xx + 5, 46], fill=C("P10")); d.line([xx, 33, xx + 3, 39], fill=C("P12"))
        if not open_:
            d.rectangle([x, 51, x + 22, 55], fill=C(LINE4[1]))                               # 닫힌 문에도 띠가 이어진다
    for i, x in enumerate(range(56, 236, 58)):                                                 # 창 줄(문 사이)
        for k in range(2):
            wx = x + k * 13
            if wx + 10 > 250:
                continue
            d.rounded_rectangle([wx, 31, wx + 10, 46], 2, fill=C(INK))
            d.rounded_rectangle([wx + 1, 32, wx + 9, 45], 2, fill=C("P10" if (i + k) % 3 else "P02"))
            if (i + k) % 3:
                d.line([wx + 2, 33, wx + 5, 38], fill=C("P12"))
            if i == 1 and k == 0:                                                              # 안쪽 손잡이 고리가 희게 비친다
                d.ellipse([wx + 3, 34, wx + 6, 37], outline=C("P08"))
    d.rounded_rectangle([238, 26, 254, 72], 6, fill=C("P06"))                                 # 운전실(오른끝, 과천 쪽)
    d.rectangle([241, 30, 252, 40], fill=C("P02"))
    d.rectangle([216, 12, 236, 23], fill=C(INK)); d.rectangle([217, 13, 235, 22], fill=C("P02"))   # 지붕 앞 행선 표시기(붉은 점등 글씨가 멈춘 채)
    put_text(im, "막차", 218, 13, "P53", 8, "Galmuri7")
    d.rectangle([7, 30, 18, 40], fill=C("P02"))                                               # 꽁무니 창(사당 쪽)
    put_text(im, "과천", 200, 59, "P09", 8, "Galmuri7")
    for x in (40, 70, 190, 220):                                                              # 바퀴 그늘(대차)
        d.rectangle([x, 74, x + 18, 80], fill=C(INK)); d.ellipse([x + 1, 75, x + 7, 81], fill=C("P03")); d.ellipse([x + 11, 75, x + 17, 81], fill=C("P03"))
    for _ in range(120):                                                                      # 때 · 녹 · 먼지(아래로 갈수록)
        x, y = rnd.randint(8, 250), rnd.randint(28, 74)
        if im.getpixel((x, y))[3] and im.getpixel((x, y))[:3] in (P.rgb("P07"), P.rgb("P06")):
            im.putpixel((x, y), C(rnd.choice(["P05", "P06", "P25"] if y > 58 else ["P06", "P08"])))
    for x in range(10, 250, 7):                                                               # 아래 끝 녹물 줄
        if rnd.random() < 0.4:
            d.line([x, 70, x, 70 + rnd.randint(1, 4)], fill=C("P25"))
    _shadow(d, 6, 254, 82)
    return im


def w_circuit_box(state=""):
    """터널 조명 회로 함(벽 소품 1칸, 30×40): 회색 함 · 문 반쯤 열림 · 안 차단기 둘(사당 쪽 · 초소 쪽) · 표시등 둘 · 늘어진 전선.
    상태 sadang = 사당 쪽 차단기 올림(초록 하나) · full = 둘 다 올림(초록 둘) · cut = 초소 쪽 선을 끊어 늘어뜨림(붉은 꼬리표)."""
    im = img(30, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 2, 24, 34], fill=C(INK)); d.rectangle([4, 3, 23, 33], fill=C("P05"))
    d.rectangle([6, 6, 21, 30], fill=C("P02"))                                                # 안쪽
    up = {"sadang": (True, False), "full": (True, True), "cut": (True, False)}.get(state, (False, False))
    for i, x in enumerate((8, 15)):
        d.rectangle([x, 12, x + 4, 22], fill=C("P04"))
        y = 13 if up[i] else 18
        d.rectangle([x + 1, y, x + 3, y + 3], fill=C("P08"))
        lamp = "P56" if up[i] else "P03"
        if state == "cut" and i == 1:
            lamp = "P52"
        d.rectangle([x + 1, 8, x + 3, 10], fill=C(lamp))
        if up[i]:
            d.point((x + 2, 7), fill=C("P57"))
    d.line([8, 25, 12, 25], fill=C("P07")); d.line([15, 25, 19, 25], fill=C("P07"))            # 이름표 자리
    d.polygon([(24, 3), (29, 6), (29, 36), (24, 33)], fill=C("P06")); d.line([24, 3, 29, 6], fill=C("P08"))   # 반쯤 열린 문짝
    d.rectangle([26, 18, 27, 21], fill=C("P53"))                                              # 문 경고 딱지
    if state == "cut":
        d.line([17, 31, 19, 37], fill=C("P01"), width=2); d.line([17, 31, 19, 36], fill=C("P26"))   # 잘린 구리선
        d.line([20, 37, 22, 39], fill=C("P26"))
        d.rectangle([9, 31, 14, 37], fill=C("P53")); d.line([11, 31, 11, 28], fill=C("P09"))  # 붉은 꼬리표
    else:
        d.line([10, 34, 9, 38], fill=C("P01")); d.line([18, 34, 20, 39], fill=C("P01"))       # 늘어진 전선 두 가닥
    d.line([3, 2, 24, 2], fill=C("P07"))
    return im


def w_phone_box():
    """비상 전화함(벽 소품 1칸, 26×36): 붉은 함 · 위 흰 글 '비상' · 유리문 너머 수화기 · 꼬인 줄이 바닥까지 늘어졌다."""
    im = img(26, 36)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 2, 22, 28], fill=C(INK)); d.rectangle([4, 3, 21, 27], fill=C("P53"))
    d.line([4, 3, 21, 3], fill=C("P54"))
    put_text(im, "비상", 6, 4, "P09", 8, "Galmuri7")
    d.rectangle([6, 14, 19, 25], fill=C("P51")); d.rectangle([8, 16, 17, 23], fill=C("P02"))
    d.rounded_rectangle([9, 17, 12, 22], 1, fill=C("P04")); d.line([12, 18, 12, 21], fill=C("P06"))   # 걸린 수화기
    for i, y in enumerate(range(25, 34, 2)):                                                   # 꼬인 줄
        d.point((14 + (i % 2), y), fill=C("P01")); d.point((15 - (i % 2), y + 1), fill=C("P02"))
    return im


# ================================================================================================ 할매의 대피 측실
def hm_stove():
    """할매 화로(1×1, 32×40): 기름통을 자른 깡통 화로 · 숯불(주황 · 노랑) · 찌그러진 양은 주전자 · 김 두 줄 · 곁에 사기 컵 둘."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([5, 20, 24, 35], fill=C(INK)); d.rectangle([6, 21, 23, 34], fill=C("P25"))
    d.line([6, 21, 23, 21], fill=C("P27")); d.line([6, 27, 23, 27], fill=C("P24"))
    for x in (9, 15, 20):                                                                     # 공기 구멍 사이 불빛
        d.rectangle([x, 29, x + 2, 31], fill=C("P59"))
    d.ellipse([6, 17, 23, 23], fill=C("P02"))
    for x, y, c in ((9, 19, "P59"), (13, 18, "P60"), (17, 19, "P58"), (11, 20, "P27")):
        d.point((x, y), fill=C(c)); d.point((x + 1, y), fill=C(c))
    d.rounded_rectangle([9, 8, 21, 18], 4, fill=C(INK)); d.rounded_rectangle([10, 9, 20, 17], 4, fill=C("P08"))   # 주전자
    d.line([11, 10, 19, 10], fill=C("P09")); d.point((15, 13), fill=C("P06"))                  # 찌그러진 자국
    d.line([20, 12, 25, 9], fill=C(INK)); d.line([20, 13, 25, 10], fill=C("P07"))             # 주둥이
    d.arc([10, 4, 20, 12], 180, 360, fill=C(INK))                                             # 손잡이
    for x0 in (24, 27):                                                                       # 김
        d.point((x0, 6), fill=C("P15")); d.point((x0 + 1, 4), fill=C("P15")); d.point((x0, 2), fill=C("P14"))
    for x in (25, 28):                                                                        # 사기 컵 둘
        d.rectangle([x, 31, x + 2, 35], fill=C("P09")); d.line([x, 31, x + 2, 31], fill=C("P45"))
    _shadow(d, 5, 30, 36)
    return im


def hm_shelf():
    """할매 선반(1×1, 32×44): 사과 상자 둘을 포갰다 · 위 칸 사진 액자(빛바랜 두 사람) · 사탕 병(알록달록) · 촛대(녹은 초) · 아래 칸 뜨개 바구니."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    for y0 in (14, 27):                                                                       # 사과 상자 둘
        d.rectangle([3, y0, 28, y0 + 13], fill=C(INK)); d.rectangle([4, y0 + 1, 27, y0 + 12], fill=C("P19"))
        d.line([4, y0 + 1, 27, y0 + 1], fill=C("P21")); d.line([4, y0 + 7, 27, y0 + 7], fill=C("P18"))
    put_text(im, "사과", 9, 29, "P53", 8, "Galmuri7")
    d.rectangle([5, 3, 13, 13], fill=C(INK)); d.rectangle([6, 4, 12, 12], fill=C("P21"))       # 액자
    d.rectangle([7, 5, 11, 11], fill=C("P06")); d.point((8, 7), fill=C("P41")); d.point((10, 7), fill=C("P41"))
    d.line([8, 9, 8, 11], fill=C("P03")); d.line([10, 9, 10, 11], fill=C("P45"))
    d.rounded_rectangle([16, 5, 22, 13], 2, fill=C(INK)); d.rounded_rectangle([17, 6, 21, 12], 2, fill=C("P15"))   # 사탕 병
    for x, y, c in ((18, 9, "P53"), (20, 8, "P49"), (19, 11, "P56"), (18, 7, "P46")):
        d.point((x, y), fill=C(c))
    d.rectangle([17, 4, 21, 5], fill=C("P26"))
    d.rectangle([24, 9, 26, 13], fill=C("P09")); d.point((25, 8), fill=C("P59")); d.point((25, 7), fill=C("P60"))   # 초
    d.line([23, 13, 27, 13], fill=C("P05"))
    d.ellipse([7, 33, 22, 41], fill=C(INK)); d.ellipse([8, 34, 21, 40], fill=C("P20"))         # 뜨개 바구니 · 실타래
    d.ellipse([10, 33, 15, 37], fill=C("P53")); d.line([15, 35, 22, 31], fill=C("P53"))
    return im


def hm_cart():
    """할매 짐수레(2×1, 64×44): 녹슨 손수레 · 끈으로 묶은 보따리 둘 · 과천 쪽 짐꾼과 바꾼 군용 상자 · 끈에 끼운 쪽지 한 장."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 22, 52, 32], fill=C(INK)); d.rectangle([7, 23, 51, 31], fill=C("P25"))      # 짐칸
    d.line([7, 23, 51, 23], fill=C("P27"))
    d.line([52, 24, 62, 18], fill=C(INK), width=2); d.line([52, 25, 62, 19], fill=C("P05"))      # 손잡이
    for x in (12, 44):                                                                         # 바퀴
        d.ellipse([x - 5, 30, x + 5, 40], fill=C(INK)); d.ellipse([x - 3, 32, x + 3, 38], fill=C("P04")); d.point((x, 35), fill=C("P07"))
    d.rounded_rectangle([8, 10, 24, 24], 5, fill=C(INK)); d.rounded_rectangle([9, 11, 23, 23], 5, fill=C("P45"))   # 보따리(남색 보자기)
    d.line([16, 11, 16, 23], fill=C("P44")); d.polygon([(14, 9), (18, 9), (16, 12)], fill=C("P45"))
    d.rounded_rectangle([20, 6, 33, 22], 4, fill=C(INK)); d.rounded_rectangle([21, 7, 32, 21], 4, fill=C("P53"))   # 보따리(붉은 꽃무늬)
    for x, y in ((24, 10), (29, 13), (25, 17)):
        d.point((x, y), fill=C("P49"))
    d.rectangle([34, 10, 50, 23], fill=C(INK)); d.rectangle([35, 11, 49, 22], fill=C("P30"))   # 군용 상자
    d.line([35, 11, 49, 11], fill=C("P31")); put_text(im, "과", 39, 12, "P32", 8, "Galmuri7")
    d.line([8, 17, 50, 15], fill=C("P21"))                                                     # 묶은 끈
    d.rectangle([40, 13, 45, 18], fill=C("P09")); d.line([41, 15, 44, 15], fill=C("P05"))      # 끈에 끼운 쪽지
    _shadow(d, 4, 58, 41)
    return im


def w_hm_shaft(state=""):
    """대피 측실 뒤 무너진 환기 갱(벽 소품 2칸, 64×64): 비스듬히 기운 콘크리트 구멍 · 녹슨 쇠 발판(사다리) · 위에서 새는 희미한 빛 ·
    바닥에 흘러내린 흙. 상태 sealed = 판자 세 장 · 노란 '계엄 봉인' 테이프 X · collapsed = 돌무더기로 메워짐 · 부러진 버팀목."""
    rnd = random.Random(7007)
    im = img(64, 64)
    d = ImageDraw.Draw(im)
    d.polygon([(10, 6), (52, 2), (56, 58), (8, 60)], fill=C("P04"))                           # 깨진 벽 테두리
    d.polygon([(16, 10), (48, 7), (50, 54), (14, 56)], fill=C(INK))                           # 갱 입구(어둠)
    if state == "collapsed":
        for _ in range(26):
            x, y = rnd.randint(16, 46), rnd.randint(12, 54)
            r = rnd.randint(3, 7)
            d.ellipse([x - r, y - r // 2 - 1, x + r, y + r // 2 + 1], fill=C(rnd.choice(["P05", "P06", "P04", "P18"])))
            d.line([x - r + 1, y - r // 2, x + r - 2, y - r // 2], fill=C("P07"))
        d.line([12, 20, 44, 50], fill=C("P18"), width=3); d.line([12, 20, 44, 50], fill=C("P20"))   # 부러진 버팀목
        d.line([44, 50, 50, 46], fill=C("P18"), width=2)
        return im
    d.polygon([(20, 10), (44, 8), (42, 22), (22, 24)], fill=C("P02"))                         # 위쪽 깊이
    d.line([28, 9, 36, 8], fill=C("P11")); d.line([30, 10, 34, 10], fill=C("P12"))            # 위에서 새는 빛
    for y in range(14, 54, 7):                                                                # 쇠 발판
        d.line([24, y, 40, y - 1], fill=C("P26")); d.line([24, y + 1, 40, y], fill=C("P24"))
    d.line([23, 12, 21, 54], fill=C("P24")); d.line([41, 11, 43, 54], fill=C("P24"))
    for _ in range(10):                                                                       # 흘러내린 흙
        x = rnd.randint(16, 48)
        d.line([x, 56, x + rnd.randint(1, 4), 60], fill=C("P18"))
    if state == "sealed":
        for i, y in enumerate((16, 30, 44)):                                                  # 판자 셋
            d.polygon([(13, y), (51, y - 2), (51, y + 7), (13, y + 9)], fill=C(INK))
            d.polygon([(14, y + 1), (50, y - 1), (50, y + 6), (14, y + 8)], fill=C("P19" if i % 2 else "P20"))
            d.line([14, y + 1, 50, y - 1], fill=C("P21"))
            for x in (17, 47):
                d.point((x, y + 4), fill=C("P06"))
        for (a, b) in (((12, 10), (52, 56)), ((52, 8), (12, 58))):                            # 노란 봉인 테이프 X
            d.line([*a, *b], fill=C(INK), width=5); d.line([*a, *b], fill=C("P49"), width=3)
        put_text(im, "봉인", 23, 28, "P01", 8, "Galmuri7")
    return im


def w_chalk_roa():
    """반로아 분필 화살표(벽 소품 1칸, 32×24): 흰 분필 '→' · 밑에 '로아' · 옆에 작은 쥐 그림에 가위표(둥지 피함)."""
    im = img(32, 24)
    d = ImageDraw.Draw(im)
    d.line([3, 7, 18, 7], fill=C("P09")); d.line([14, 3, 19, 7], fill=C("P09")); d.line([14, 11, 19, 7], fill=C("P09"))
    put_text(im, "로아", 3, 12, "P08", 8, "Galmuri7")
    d.ellipse([22, 4, 28, 8], outline=C("P08")); d.line([28, 6, 31, 5], fill=C("P08"))          # 쥐
    d.line([21, 2, 29, 10], fill=C("P53")); d.line([29, 2, 21, 10], fill=C("P53"))
    return im


def w_chalk_height():
    """키 재기 낙서(벽 소품 1칸, 32×48): 분필 눈금 다섯 · '로아 9 · 10 · 11 · 12' · 맨 위 빈 눈금에 물음표."""
    im = img(32, 48)
    d = ImageDraw.Draw(im)
    d.line([16, 4, 16, 46], fill=C("P07"))
    for i, (y, s) in enumerate(((40, "9"), (33, "10"), (27, "11"), (20, "12"), (12, "?"))):
        d.line([10, y, 22, y], fill=C("P09" if i < 4 else "P07"))
        put_text(im, s, 23, y - 4, "P08", 8, "Galmuri7")
    put_text(im, "로아", 0, 40, "P08", 8, "Galmuri7")
    return im


# ================================================================================================ 대합실 초소(L-UG-05)
def w_notice_ntr():
    """개찰구 공문(벽 소품 2칸, 64×44): 아래 2077 안내문(누런 판 · 파란 테 · '과천 방면 통행 / 등록증 확인')이 새 공문 위아래로 비친다.
    새 공문은 흰 종이 · 붉은 인장 · '계엄 / 통행 금지' · 왼 아래 귀퉁이가 들떠 2077 글자 '등록'이 보인다(SD-09f L-UG-05 환경)."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 61, 42], fill=C(INK)); d.rectangle([3, 3, 60, 41], fill=C("P21"))        # 2077 안내판
    d.rectangle([3, 3, 60, 5], fill=C("P45")); d.rectangle([3, 39, 60, 41], fill=C("P45"))
    put_text(im, "과천 방면 통행", 5, 6, "P44", 8, "Galmuri7")
    put_text(im, "등록증 확인", 5, 28, "P44", 8, "Galmuri7")
    d.polygon([(13, 17), (59, 15), (60, 39), (24, 40), (13, 33)], fill=C(INK))                 # 새 공문(비스듬히 · 왼 아래 귀퉁이 들뜸)
    d.polygon([(14, 18), (58, 16), (59, 38), (25, 39), (14, 32)], fill=C("P09"))
    d.polygon([(14, 32), (25, 39), (20, 33)], fill=C("P07"))                                   # 들뜬 귀퉁이 그늘
    put_text(im, "계엄", 17, 18, "P01", 8, "Galmuri7")
    put_text(im, "통행 금지", 17, 28, "P53", 8, "Galmuri7")
    d.ellipse([44, 18, 54, 28], outline=C("P53")); d.ellipse([46, 20, 52, 26], outline=C("P52"))   # 붉은 인장(글자 비켜)
    d.point((49, 23), fill=C("P53"))
    for x in (15, 57):
        d.point((x, 17), fill=C("P04"))                                                       # 압정
    return im


def w_vent_nt(state=""):
    """대합실 천장 환기구(벽 소품 1칸, 32×28): 큰 철 격자 덮개 · 모서리 나사 넷. open = 덮개가 한 나사에 매달려 아래로 젖혀졌고 안은 덕트의 어둠 · 먼지 줄."""
    im = img(32, 28)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 30, 22], fill=C("P04")); d.rectangle([3, 3, 28, 20], fill=C(INK))
    if state == "open":
        d.rectangle([4, 4, 27, 19], fill=C("P02"))
        d.line([6, 8, 25, 8], fill=C("P03")); d.line([8, 14, 23, 14], fill=C("P03"))            # 덕트 안 이음
        d.polygon([(3, 20), (7, 20), (12, 27), (0, 27)], fill=C("P05"))                        # 매달린 덮개(왼쪽 아래로)
        for y in range(21, 27, 2):
            d.line([2, y, 9, y], fill=C("P03"))
        d.point((4, 20), fill=C("P08"))
    else:
        for x in range(5, 27, 3):
            d.line([x, 4, x, 19], fill=C("P05"))
        for x, y in ((2, 2), (29, 2), (2, 21), (29, 21)):
            d.point((x, y), fill=C("P08"))
    d.line([1, 1, 30, 1], fill=C("P06"))
    return im


def bk_floor_hatch(state=""):
    """막사 바닥 점검구(덧그림, 32×32): 컨테이너 바닥 줄무늬 철판 위 네모 뚜껑 · 접이 손잡이 · 테두리 볼트.
    open = 뚜껑을 위로 젖혀 세움(뒤 그늘) · 아래 어둠 속 덕트 이음과 사다리 발판 하나."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([5, 7, 26, 26], fill=C(INK))
    if state == "open":
        d.rectangle([6, 8, 25, 25], fill=C("P01"))
        d.line([8, 16, 23, 16], fill=C("P03")); d.line([9, 22, 22, 22], fill=C("P26"))
        d.rectangle([5, 0, 26, 7], fill=C("P05")); d.line([5, 0, 26, 0], fill=C("P07"))        # 세워 둔 뚜껑
        for x in range(7, 26, 3):
            d.line([x, 1, x, 6], fill=C("P04"))
    else:
        d.rectangle([6, 8, 25, 25], fill=C("P05"))
        for y in range(10, 25, 3):
            d.line([7, y, 24, y], fill=C("P04"))
        d.line([6, 8, 25, 8], fill=C("P07"))
        d.rectangle([13, 14, 18, 16], fill=C(INK)); d.line([14, 15, 17, 15], fill=C("P07"))    # 손잡이
        for x, y in ((7, 9), (24, 9), (7, 24), (24, 24)):
            d.point((x, y), fill=C("P08"))
    return im


# ================================================================================================ 등록
def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_U02 = {
    "w_name_ntr": _r(w_name_ntr, 3, 0, "wall", dx=0, dy=6),
    "w_screen_door4": _r(w_screen_door4, 2, 0, "wall", dx=0, dy=2),
    "w_screen_door4b": _r(lambda: w_screen_door4(True), 2, 0, "wall", dx=0, dy=2),
    "train_car4": _r(train_car4, 8, 2, down=-2),
    "w_circuit_box": _r(w_circuit_box, 1, 0, "wall", dx=1, dy=0),
    "w_phone_box": _r(w_phone_box, 1, 0, "wall", dx=3, dy=2),
    "hm_stove": _r(hm_stove, 1, 1, down=-2),
    "hm_shelf": _r(hm_shelf, 1, 1, down=-2),
    "hm_cart": _r(hm_cart, 2, 1, down=-2),
    "w_hm_shaft": _r(w_hm_shaft, 2, 0, "wall", dx=0, dy=0),
    "w_chalk_roa": _r(w_chalk_roa, 1, 0, "wall", dx=0, dy=8),
    "w_chalk_height": _r(w_chalk_height, 1, 0, "wall", dx=0, dy=0),
    "w_notice_ntr": _r(w_notice_ntr, 2, 0, "wall", dx=0, dy=4),
    "w_vent_nt": _r(w_vent_nt, 1, 0, "wall", dx=0, dy=2),
    "bk_floor_hatch": _r(bk_floor_hatch, 0, 0, "deco"),
}
STATES_U02 = {
    "w_circuit_box": {s: (lambda s=s: w_circuit_box(s)) for s in ("sadang", "full", "cut")},
    "w_hm_shaft": {s: (lambda s=s: w_hm_shaft(s)) for s in ("sealed", "collapsed")},
    "w_vent_nt": {"open": lambda: w_vent_nt("open")},
    "bk_floor_hatch": {"open": lambda: bk_floor_hatch("open")},
}


if __name__ == "__main__":
    from grid import upscale
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_u02.png"
    ims = [(n, r["fn"]()) for n, r in PROPS_U02.items()] + [(f"{n}#{s}", fn()) for n, st in STATES_U02.items() for s, fn in st.items()]
    W = 560
    x = y = rowh = 0
    pos = []
    for n, im in ims:
        if x + im.width + 6 > W:
            x, y, rowh = 0, y + rowh + 6, 0
        pos.append((im, x, y))
        x += im.width + 6
        rowh = max(rowh, im.height)
    sheet = Image.new("RGBA", (W, y + rowh + 6), P.rgb("P03") + (255,))
    for im, x, y in pos:
        sheet.alpha_composite(im, (x + 3, y + 3))
    upscale(sheet, 3).save(out)
    print(out)
