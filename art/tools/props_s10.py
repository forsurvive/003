"""고척 돔 인력 경매장(단계 1-11i SQ-S10 오늘의 4번 인력, SD-04a §5.3 · SD-09a L-R02-23 · SD-16 아이작풍).
  gd_podium        경매 단상(4×2): 철골 비계 위 널판 · 앞치마 천 '새벽인력' · 견적 연단(망치) · '인력'이 서는 동그라미 + 쇠사슬 기둥 · 번호 장대 '4'
  gd_board         분필 칠판(3×1, 세움): '오늘의 경기 / 인력 4번 경매 / 시작 10:00 / 현재가 300'
                   상태 p350 … p1000(50캡 단위 — 현재가를 지우고 고쳐 쓴 자국) · sold_sv('4번 낙찰 — 세이프빌') · sold_tank('4번 — 탱크마을')
                   · stop('세이프빌 구매 중단') · free('4번 — 풀려남') · raid(넘어져 금 간 칠판)
  gd_seats/2       관중석 좌석 줄(2×1): 계단 콘크리트 턱 위 플라스틱 의자 둘(파랑 · 주황 깨짐)
  w_vip_glass      VIP 박스 유리창(벽 3칸): 짙은 색유리 · 비스듬한 반사 · 상태 sil(장부를 든 기서윤 실루엣) · broken(깨짐)
  cheer_sticks     응원 막대(덧그림): 바람 빠진 2077 응원 막대 한 쌍
  light_shaft      무너진 지붕 빛기둥(덧그림 3칸 폭): 바닥의 빛 웅덩이(성긴 디더) + 떠도는 먼지
  ledger_box       장부함(1×1): 각목 받침 위 철제 함 · 다이얼 자물쇠 · 상태 open(뚜껑 열림 · 빈 함)
  paddle_table     구매자 패 탁자(2×1): 접이 탁자 · 번호 패 셋 · 물주전자
  broadcast_desk   중계석 송출 장비(2×1): 먼지 쌓인 믹서 · 마이크 둘 · 헤드셋 · 테이프로 붙인 쪽지
  w_lotto_poster   매점 복권 포스터(벽 1칸): '복권 — 2077. 10. 23. 추첨' · 번호 공
  snack_counter    매점 계산대(2×1): 바랜 '매점' 차양 · 빈 진열 · 계산기
  dugout_bench     덕아웃 벤치(3×1): 철 벤치 · 술병 · 아이스박스 · 카드 패
  home_plate       홈 플레이트(덧그림): 잔디 위 바랜 오각형 · 주변 흙
  base_bag         베이스(덧그림): 바랜 흰 방석
  chalk_h / chalk_v  파울 선(덧그림): 끊긴 흰 선 조각
  roof_debris      무너진 지붕 잔해(2×2): 휜 트러스 · 찢긴 흰 막 · 떨어진 조명
  w_gd_banner      2077 개막전 현수막(벽 2칸): '프로야구 개막 — 2077' 바랜 천
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


def _shadow(d, x0, x1, y, h=2):
    for x in range(x0, x1):
        for yy in range(y, y + h):
            if (x + yy) % 2 == 0:
                d.point((x, yy), fill=C("P02"))


def gd_podium():
    """경매 단상(128×88): 철골 비계 다리 · 널판 윗면 · 붉은 앞치마 천('새벽인력' 흰 글씨) · 왼쪽 연단(망치 · 종이)
    · 오른쪽 '인력' 동그라미(흰 칠) + 쇠사슬 기둥 · 뒤쪽 번호 장대(흰 판 '4')."""
    im = img(128, 88)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 124, 84, 3)
    for x in (6, 40, 84, 118):                                        # 비계 다리(쇠파이프) + 엑스 가새
        d.rectangle([x, 52, x + 3, 83], fill=C("P12")); d.line([x, 52, x, 83], fill=C("P14")); d.line([x + 3, 52, x + 3, 83], fill=C(INK))
    for x0, x1 in ((9, 40), (43, 84), (87, 118)):
        d.line([x0, 56, x1, 80], fill=C("P11")); d.line([x0, 80, x1, 56], fill=C("P11"))
    d.rectangle([2, 46, 125, 56], fill=C("P20"))                      # 널판 앞면
    for x in range(2, 126, 9):
        d.line([x, 46, x, 56], fill=C("P19"))
    d.line([2, 46, 125, 46], fill=C("P21")); d.line([2, 56, 125, 56], fill=C(INK))
    d.rectangle([2, 26, 125, 46], fill=C("P21"))                      # 널판 윗면(밟혀 닳은 가운데)
    for y in range(29, 46, 5):
        d.line([2, y, 125, y], fill=C("P20"))
    for x in range(30, 98):
        for y in range(30, 44):
            if (x * 7 + y * 3) % 11 == 0:
                d.point((x, y), fill=C("P22"))
    d.rectangle([1, 25, 126, 57], outline=C(INK))
    d.rectangle([16, 57, 112, 70], fill=C("P52"))                     # 앞치마 천(붉은 · 늘어진 아래 단)
    for x in range(16, 113, 8):
        d.line([x, 70, x + 4, 72], fill=C("P52")); d.point((x + 2, 71), fill=C("P51"))
    d.line([16, 57, 112, 57], fill=C("P53")); d.rectangle([16, 57, 112, 70], outline=C("P51"))
    put_text(im, "새벽인력", 46, 59, "P08")
    d.rectangle([14, 6, 36, 34], fill=C(INK))                          # 연단(철판 · 위 기울어진 판)
    d.rectangle([15, 7, 35, 33], fill=C("P11")); d.line([15, 7, 35, 7], fill=C("P13"))
    d.polygon([(12, 6), (38, 6), (36, 2), (14, 2)], fill=C("P12")); d.line([14, 2, 36, 2], fill=C("P14"))
    d.rectangle([18, 1, 26, 3], fill=C("P08")); d.line([19, 2, 25, 2], fill=C("P05"))   # 종이 쪽
    d.rectangle([28, 0, 34, 2], fill=C("P18")); d.line([31, 2, 31, 5], fill=C("P17"))   # 망치
    d.rectangle([15, 12, 35, 16], fill=C("P52")); d.line([15, 12, 35, 12], fill=C("P53"))   # 연단 붉은 띠
    d.ellipse([76, 30, 104, 42], outline=C("P08"))                    # '인력' 동그라미 + 발자국 닳음
    d.ellipse([77, 31, 103, 41], outline=C("P07"))
    d.point((86, 36), fill=C("P19")); d.point((94, 36), fill=C("P19"))
    d.rectangle([108, 18, 111, 40], fill=C("P05")); d.line([108, 18, 108, 40], fill=C("P07"))   # 쇠사슬 기둥
    for y in range(22, 36, 3):
        d.point((106 - (y - 22) // 3, y), fill=C("P06")); d.point((105 - (y - 22) // 3, y + 1), fill=C("P04"))
    d.rectangle([60, 0, 62, 28], fill=C("P05")); d.line([60, 0, 60, 28], fill=C("P07"))          # 번호 장대
    d.rectangle([63, 2, 75, 16], fill=C(INK)); d.rectangle([64, 3, 74, 15], fill=C("P08"))
    put_text(im, "4", 66, 4, "P53")
    return im


PRICES = list(range(350, 1001, 50))                                  # 경매 현재가(50캡 단위) — 칠판 상태 p350 … p1000
_BOARD = {"": ("현재가", "300", "P15"),
          "sold_sv": ("낙찰", "세이프빌", "P54"),
          "sold_tank": ("낙찰", "탱크마을", "P54"),
          "stop": ("세이프빌", "구매 중단", "P49"),
          "free": ("4번", "풀려남", "P56")}
_BOARD.update({"p%d" % v: ("현재가", str(v), "P15") for v in PRICES})


def gd_board(state=""):
    """분필 칠판(96×68): 각목 이젤 · 녹색 칠판 · 위 세 줄은 그대로, 맨 아랫줄(현재가)만 지우고 고쳐 쓴다 — 지운 자국이 겹겹이."""
    im = img(96, 68)
    d = ImageDraw.Draw(im)
    _shadow(d, 8, 90, 65)
    for x in (8, 86):                                                 # 이젤 다리
        d.rectangle([x, 44, x + 3, 66], fill=C("P18")); d.line([x, 44, x, 66], fill=C("P19")); d.line([x + 3, 44, x + 3, 66], fill=C(INK))
    d.line([10, 60, 88, 60], fill=C("P17"))
    tilt = state == "raid"
    d.rectangle([1, 0, 94, 50], fill=C(INK))
    d.rectangle([2, 1, 93, 49], fill=C("P19")); d.line([2, 1, 93, 1], fill=C("P20"))
    d.rectangle([5, 4, 90, 45], fill=C("P34")); d.line([5, 4, 90, 4], fill=C("P33"))
    rnd = random.Random(41)
    for _ in range(40):                                               # 오래 지운 자국(흐린 분필)
        d.point((rnd.randint(6, 89), rnd.randint(5, 44)), fill=C("P35"))
    put_text(im, "오늘의 경기", 8, 5, "P09")
    put_text(im, "인력 4번 경매", 8, 15, "P15")
    put_text(im, "시작 10:00", 8, 25, "P15")
    if state.startswith("p") and state[1:].isdigit():                 # 지운 자국: 바로 앞 값(50 아래)에 줄을 긋고 오른쪽 끝에 남긴다
        prev = str(int(state[1:]) - 50)
        x = 92 - 6 * len(prev) - 2
        put_text(im, prev, x, 35, "P36")
        d.line([x - 1, 40, 90, 38], fill=C("P15"))
    k, v, col = _BOARD.get(state, _BOARD[""])
    if state == "raid":
        k, v, col = ("현재가", "300", "P15")
    w, _ = put_text(im, k, 8, 35, "P14")
    put_text(im, v, 12 + w, 35, col)
    if state.startswith("p") or state == "":
        d.line([12 + w, 44, 12 + w + 6 * len(v), 44], fill=C(col))    # 밑줄
    d.rectangle([5, 45, 90, 47], fill=C("P18"))                       # 분필 받침
    d.point((20, 45), fill=C("P09")); d.point((23, 45), fill=C("P54")); d.rectangle([60, 44, 66, 46], fill=C("P06"))   # 지우개
    if tilt:                                                          # 습격: 금 간 칠판 · 받침 부러짐
        for (x0, y0, x1, y1) in ((30, 4, 44, 26), (44, 26, 40, 45), (44, 26, 62, 38)):
            d.line([x0, y0, x1, y1], fill=C(INK))
        d.rectangle([86, 44, 89, 66], fill=(0, 0, 0, 0)); d.line([86, 58, 94, 66], fill=C("P18"), width=3)
    return im


def gd_seats(seed=0):
    """관중석 좌석 줄(64×44): 콘크리트 계단 턱 + 플라스틱 의자 둘(등받이 · 접힌 좌판). seed 1은 주황 · 하나는 등받이가 깨졌다."""
    im = img(64, 44)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 30, 63, 43], fill=C("P06")); d.line([0, 30, 63, 30], fill=C("P08")); d.line([0, 37, 63, 37], fill=C("P05"))
    d.line([0, 43, 63, 43], fill=C("P04"))
    body, hi, lo = (("P45", "P46", "P44") if seed == 0 else ("P26", "P27", "P25"))
    for i, x in enumerate((6, 36)):
        broken = seed == 1 and i == 1
        d.rectangle([x + 4, 26, x + 6, 34], fill=C("P04")); d.rectangle([x + 16, 26, x + 18, 34], fill=C("P04"))   # 다리
        d.rectangle([x, 20, x + 22, 27], fill=C(INK)); d.rectangle([x + 1, 21, x + 21, 26], fill=C(body))         # 좌판
        d.line([x + 1, 21, x + 21, 21], fill=C(hi))
        if broken:
            d.polygon([(x + 1, 6), (x + 12, 4), (x + 9, 12), (x + 14, 20), (x + 1, 20)], fill=C(INK))
            d.polygon([(x + 2, 7), (x + 11, 5), (x + 8, 12), (x + 12, 19), (x + 2, 19)], fill=C(body))
            d.line([x + 2, 7, x + 11, 5], fill=C(hi))
            d.polygon([(x + 16, 30), (x + 22, 29), (x + 20, 33)], fill=C(lo))   # 깨진 조각이 발치에
        else:
            d.rounded_rectangle([x, 2, x + 22, 20], 4, fill=C(INK)); d.rounded_rectangle([x + 1, 3, x + 21, 19], 3, fill=C(body))
            d.line([x + 3, 4, x + 19, 4], fill=C(hi)); d.line([x + 1, 18, x + 21, 18], fill=C(lo))
            for k in range(3):                                         # 볕에 바랜 줄 디더
                for xx in range(x + 3, x + 20, 2):
                    d.point((xx + k % 2, 7 + k * 3), fill=C(hi))
        d.rectangle([x + 8, 22, x + 14, 24], fill=C("P08")); d.point((x + 10, 23), fill=C("P04"))   # 좌석 번호판
    return im


def w_vip_glass(state=""):
    """VIP 박스 유리창(96×46): 철 창틀 셋 · 짙은 색유리(위 어둡고 아래 옅게) · 비스듬한 반사 두 줄 · 아래 '귀빈석' 판.
    sil: 가운데 칸에 여자 실루엣(올림머리 · 어깨 · 손에 펼친 장부 — 장부 끝이 옅은 빛을 받는다). broken: 오른쪽 칸 깨짐."""
    im = img(96, 46)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 2, 95, 40], fill=C(INK))
    for i in range(3):
        x0 = 2 + i * 31
        d.rectangle([x0, 4, x0 + 29, 34], fill=C("P10"))
        d.rectangle([x0, 22, x0 + 29, 34], fill=C("P11"))
        for y in range(18, 23):
            for x in range(x0, x0 + 30):
                if (x + y) % 2 == 0:
                    d.point((x, y), fill=C("P11"))
        d.line([x0 + 4, 30, x0 + 16, 6], fill=C("P12")); d.line([x0 + 8, 30, x0 + 19, 8], fill=C("P12"))   # 반사
        d.point((x0 + 17, 5), fill=C("P14"))
    if state == "sil":
        cx = 47
        d.ellipse([cx - 5, 9, cx + 4, 18], fill=C(INK)); d.ellipse([cx - 3, 6, cx + 2, 11], fill=C(INK))   # 머리 · 올림머리
        d.polygon([(cx - 11, 34), (cx - 9, 22), (cx - 4, 19), (cx + 4, 19), (cx + 9, 22), (cx + 11, 34)], fill=C(INK))
        d.polygon([(cx - 7, 26), (cx + 6, 24), (cx + 8, 29), (cx - 6, 31)], fill=C("P13"))    # 펼친 장부
        d.line([cx - 7, 26, cx + 6, 24], fill=C("P15")); d.line([cx, 25, cx + 1, 30], fill=C("P11"))
    if state == "broken":
        x0 = 64
        d.rectangle([x0, 4, x0 + 29, 34], fill=C("P02"))
        for (a, b) in (((x0, 4), (x0 + 10, 14)), ((x0 + 29, 6), (x0 + 18, 16)), ((x0 + 3, 34), (x0 + 12, 22))):
            d.polygon([a, b, (a[0], b[1])], fill=C("P11")); d.line([a, b], fill=C("P13"))
    for i in range(4):                                                 # 창틀 기둥
        x = 1 + i * 31
        d.rectangle([x, 3, x + 1, 35], fill=C("P05")); d.point((x, 3), fill=C("P07"))
    d.rectangle([0, 34, 95, 37], fill=C("P05")); d.line([0, 34, 95, 34], fill=C("P07"))
    d.rectangle([34, 37, 61, 45], fill=C("P47")); d.rectangle([34, 37, 61, 45], outline=C(INK))
    put_text(im, "귀빈석", 36, 37, "P49")
    return im


def cheer_sticks():
    """응원 막대(32×18): 바람 빠진 풍선 막대 둘(바랜 파랑 · 바랜 빨강) — 한쪽 끝이 쭈글쭈글."""
    im = img(32, 18)
    d = ImageDraw.Draw(im)
    for (y, body, hi, lo) in ((4, "P45", "P46", "P44"), (10, "P40", "P41", "P39")):
        d.polygon([(2, y + 2), (24, y), (29, y + 2), (25, y + 5), (3, y + 6)], fill=C(INK))
        d.polygon([(3, y + 3), (24, y + 1), (27, y + 2), (24, y + 4), (3, y + 5)], fill=C(body))
        d.line([4, y + 3, 22, y + 1], fill=C(hi))
        for x in range(6, 22, 5):
            d.point((x, y + 4), fill=C(lo)); d.point((x + 1, y + 3), fill=C(lo))
        d.point((28, y + 2), fill=C(lo))
    return im


def light_shaft():
    """무너진 지붕 빛기둥(96×72, 덧그림): 바닥에 떨어진 타원 빛 웅덩이 — 가운데는 촘촘, 가장자리로 갈수록 성긴 디더(반투명 없이).
    위로 떠도는 먼지 점(밝은 점 몇)."""
    im = img(96, 72)
    px = im.load()
    cx, cy, rx, ry = 48, 52, 44, 18
    for y in range(72):
        for x in range(96):
            q = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if q < 1.0:
                if q < 0.35:
                    on = (x + y) % 2 == 0
                elif q < 0.7:
                    on = (x % 2 == 0) and (y % 2 == 0)
                else:
                    on = (x % 4 == 0) and (y % 2 == 0) and ((x // 4 + y // 2) % 2 == 0)
                if on:
                    px[x, y] = C("P22" if q > 0.2 else "P50")
    for y in range(0, 40):                                            # 빛줄기: 위에서 웅덩이로 좁게 내려오는 성긴 줄
        w = 10 + y * 30 // 40
        for x in range(cx - w, cx + w):
            if (x * 3 + y * 5) % 13 == 0 and y % 2 == 0:
                px[x, y] = C("P22")
    rnd = random.Random(5)
    for _ in range(14):                                               # 먼지(빛 속에 뜬 점)
        y = rnd.randint(2, 44)
        w = 8 + y * 30 // 40
        px[rnd.randint(cx - w, cx + w - 1), y] = C("P09")
    return im


def ledger_box(state=""):
    """장부함(32×44): 각목 받침 위 철제 함 · 앞면 다이얼 자물쇠 · 손잡이. open: 뚜껑이 젖혀지고 안이 비었다."""
    im = img(32, 44)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 28, 41)
    for x in (6, 23):
        d.rectangle([x, 26, x + 3, 41], fill=C("P18")); d.line([x, 26, x, 41], fill=C("P19"))
    d.line([8, 36, 24, 36], fill=C("P17"))
    d.rectangle([3, 12, 28, 28], fill=C(INK)); d.rectangle([4, 13, 27, 27], fill=C("P12"))
    d.line([4, 13, 27, 13], fill=C("P14")); d.line([4, 27, 27, 27], fill=C("P10"))
    if state == "open":
        d.polygon([(4, 12), (27, 12), (25, 2), (6, 2)], fill=C(INK)); d.polygon([(5, 11), (26, 11), (24, 3), (7, 3)], fill=C("P11"))
        d.rectangle([6, 13, 25, 16], fill=C("P02"))                    # 빈 속
    else:
        d.rectangle([3, 9, 28, 13], fill=C(INK)); d.rectangle([4, 10, 27, 12], fill=C("P13"))
        d.rectangle([13, 7, 18, 9], fill=C("P05"))                    # 손잡이
    d.ellipse([12, 17, 19, 24], fill=C(INK)); d.ellipse([13, 18, 18, 23], fill=C("P06"))   # 다이얼
    d.point((15, 18), fill=C("P53")); d.point((15, 20), fill=C("P08"))
    return im


def paddle_table():
    """구매자 패 탁자(64×40): 접이 탁자 · 둥근 번호 패 셋(흰 판 '7' '12' '21', 손잡이) · 양은 물주전자."""
    im = img(64, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 4, 60, 37)
    for x in (6, 55):
        d.line([x, 22, x + 3, 36], fill=C("P05"), width=2); d.line([x + 3, 22, x, 36], fill=C("P04"), width=2)
    d.rectangle([2, 16, 61, 23], fill=C(INK)); d.rectangle([3, 17, 60, 22], fill=C("P07")); d.line([3, 17, 60, 17], fill=C("P08"))
    for i, (x, n) in enumerate(((8, "7"), (22, "12"), (36, "21"))):
        d.line([x + 6, 14, x + 9, 18], fill=C("P18"), width=2)
        d.ellipse([x, 4, x + 12, 15], fill=C(INK)); d.ellipse([x + 1, 5, x + 11, 14], fill=C("P09"))
        put_text(im, n, x + (4 if len(n) == 1 else 1), 5, "P53" if i == 1 else "P02", 7)
    d.rectangle([50, 6, 58, 17], fill=C(INK)); d.rectangle([51, 7, 57, 16], fill=C("P14"))   # 주전자
    d.line([51, 7, 57, 7], fill=C("P15")); d.line([58, 9, 60, 13], fill=C("P13")); d.line([49, 8, 50, 10], fill=C("P13"))
    return im


def broadcast_desk():
    """중계석 송출 장비(64×48): 긴 책상 · 믹서(꼭지 줄 · 미닫이 줄) · 마이크 둘 · 헤드셋 · 먼지(회색 점) · 테이프로 붙인 노란 쪽지."""
    im = img(64, 48)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 45)
    d.rectangle([1, 26, 62, 44], fill=C(INK)); d.rectangle([2, 27, 61, 43], fill=C("P11")); d.line([2, 27, 61, 27], fill=C("P13"))
    for x in range(5, 60, 8):
        d.line([x, 30, x, 41], fill=C("P10"))
    d.rectangle([1, 20, 62, 27], fill=C(INK)); d.rectangle([2, 21, 61, 26], fill=C("P18")); d.line([2, 21, 61, 21], fill=C("P20"))
    d.polygon([(10, 20), (46, 20), (44, 10), (12, 10)], fill=C(INK))   # 믹서
    d.polygon([(11, 19), (45, 19), (43, 11), (13, 11)], fill=C("P05"))
    for i, x in enumerate(range(15, 43, 4)):
        d.point((x, 13), fill=C("P54" if i % 3 == 0 else "P08")); d.line([x, 15, x, 18], fill=C("P02")); d.point((x, 16 + i % 3), fill=C("P07"))
    for x in (6, 54):                                                  # 마이크(목 · 머리)
        d.line([x, 20, x + 2, 8], fill=C("P04")); d.ellipse([x, 3, x + 5, 9], fill=C(INK)); d.ellipse([x + 1, 4, x + 4, 8], fill=C("P06"))
    d.arc([46, 12, 58, 24], 180, 360, fill=C(INK)); d.rectangle([45, 17, 47, 21], fill=C("P02")); d.rectangle([57, 17, 59, 21], fill=C("P02"))   # 헤드셋
    d.rectangle([20, 22, 30, 26], fill=C("P49")); d.line([20, 22, 30, 22], fill=C("P50")); d.line([22, 24, 28, 24], fill=C("P47"))  # 쪽지
    d.line([19, 22, 21, 22], fill=C("P15"))
    rnd = random.Random(3)
    for _ in range(26):
        d.point((rnd.randint(12, 44), rnd.randint(11, 19)), fill=C("P07"))
    return im


def w_lotto_poster():
    """복권 포스터(32×40, 벽): 바랜 노란 종이 · '복권' 붉은 글씨 · 번호 공 넷 · '10.23 추첨' · 아래 모서리 찢김."""
    im = img(32, 40)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 1), (29, 1), (29, 33), (24, 38), (2, 38)], fill=C(INK))
    d.polygon([(3, 2), (28, 2), (28, 33), (24, 37), (3, 37)], fill=C("P22"))
    d.rectangle([3, 2, 28, 12], fill=C("P53"))
    put_text(im, "복권", 7, 3, "P50")
    for i, (x, col) in enumerate(((5, "P49"), (11, "P46"), (17, "P54"), (23, "P56"))):
        d.ellipse([x - 1, 15, x + 4, 20], fill=C(INK)); d.ellipse([x, 16, x + 3, 19], fill=C(col)); d.point((x + 1, 16), fill=C("P09"))
    put_text(im, "10.23", 5, 22, "P02", 7)
    put_text(im, "추첨", 8, 29, "P53", 7)
    d.line([24, 37, 28, 33], fill=C("P20"))
    return im


def snack_counter():
    """매점 계산대(64×56): 줄무늬 차양(바랜 빨강·흰) · '매점' 판 · 빈 진열 선반 · 계산대 위 손 계산기 · 앞판 음료 그림 자국."""
    im = img(64, 56)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 53)
    d.rectangle([1, 30, 62, 52], fill=C(INK)); d.rectangle([2, 31, 61, 51], fill=C("P07")); d.line([2, 31, 61, 31], fill=C("P08"))
    d.rectangle([8, 36, 20, 48], fill=C("P06")); d.ellipse([10, 38, 18, 46], fill=C("P40"))       # 바랜 음료 그림
    d.rectangle([1, 26, 62, 31], fill=C(INK)); d.rectangle([2, 27, 61, 30], fill=C("P05")); d.line([2, 27, 61, 27], fill=C("P06"))
    d.rectangle([44, 22, 54, 27], fill=C(INK)); d.rectangle([45, 23, 53, 26], fill=C("P12")); d.point((47, 24), fill=C("P56"))   # 계산기
    d.rectangle([4, 10, 59, 26], fill=C("P02"))                       # 빈 진열(어두운 안)
    d.line([4, 18, 59, 18], fill=C("P05")); d.point((12, 17), fill=C("P40")); d.point((40, 17), fill=C("P31"))
    for i, x in enumerate(range(0, 64, 8)):                           # 차양
        d.polygon([(x, 2), (x + 8, 2), (x + 8, 9), (x + 4, 11), (x, 9)], fill=C("P53" if i % 2 == 0 else "P08"))
    d.line([0, 2, 63, 2], fill=C(INK))
    d.rectangle([20, 0, 43, 8], fill=C("P09")); d.rectangle([20, 0, 43, 8], outline=C(INK))
    put_text(im, "매점", 24, 0, "P53")
    return im


def dugout_bench():
    """덕아웃 벤치(96×40): 긴 철 벤치(등판) · 빈 소주병 셋 · 뒤집힌 아이스박스 · 화투 패 몇 장."""
    im = img(96, 40)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 94, 37)
    d.rectangle([2, 4, 93, 14], fill=C(INK)); d.rectangle([3, 5, 92, 13], fill=C("P44")); d.line([3, 5, 92, 5], fill=C("P45"))   # 등판
    d.rectangle([2, 18, 93, 24], fill=C(INK)); d.rectangle([3, 19, 92, 23], fill=C("P45")); d.line([3, 19, 92, 19], fill=C("P46"))
    for x in (6, 46, 87):
        d.rectangle([x, 13, x + 2, 34], fill=C("P05")); d.line([x, 13, x, 34], fill=C("P07"))
    for x in (14, 19, 60):                                             # 소주병
        d.rectangle([x, 12, x + 3, 19], fill=C("P36")); d.rectangle([x + 1, 9, x + 2, 12], fill=C("P36")); d.point((x + 1, 13), fill=C("P37"))
    d.polygon([(28, 22), (32, 21), (34, 23), (30, 24)], fill=C("P09")); d.point((30, 22), fill=C("P53"))   # 화투
    d.polygon([(34, 23), (38, 22), (39, 24), (35, 25)], fill=C("P09")); d.point((36, 23), fill=C("P55"))
    d.rectangle([66, 24, 84, 36], fill=C(INK)); d.rectangle([67, 25, 83, 35], fill=C("P08"))    # 아이스박스(뒤집힘)
    d.rectangle([67, 25, 83, 28], fill=C("P45")); d.line([70, 31, 80, 31], fill=C("P06"))
    return im


def home_plate():
    """홈 플레이트(36×22, 덧그림): 흙 원 위 바랜 흰 오각형 — 고무가 갈라졌다."""
    im = img(36, 22)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 2, 35, 21], fill=C("P19"))
    for x in range(2, 34, 3):
        d.point((x, 6 + (x * 5) % 12), fill=C("P18"))
    d.polygon([(11, 7), (24, 7), (24, 12), (18, 16), (11, 12)], fill=C(INK))
    d.polygon([(12, 8), (23, 8), (23, 12), (18, 15), (12, 12)], fill=C("P08"))
    d.line([12, 8, 23, 8], fill=C("P09")); d.line([15, 9, 19, 13], fill=C("P06"))
    return im


def base_bag():
    """베이스(26×16, 덧그림): 바랜 흰 방석 — 끈이 풀렸다."""
    im = img(26, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(3, 6), (13, 2), (23, 6), (13, 11)], fill=C(INK))
    d.polygon([(4, 6), (13, 3), (22, 6), (13, 10)], fill=C("P08"))
    d.line([5, 6, 13, 3], fill=C("P09")); d.line([13, 10, 22, 6], fill=C("P06"))
    d.line([20, 8, 24, 12], fill=C("P06"))
    return im


def chalk(vertical=False):
    """파울 선 조각(32×32, 덧그림): 끊기고 닳은 흰 선."""
    im = img(32, 32)
    px = im.load()
    rnd = random.Random(9 if vertical else 8)
    for i in range(32):
        for k in range(3):
            if rnd.random() < 0.72:
                x, y = (14 + k, i) if vertical else (i, 14 + k)
                px[x, y] = C("P08" if k != 2 else "P07")
    return im


def roof_debris():
    """무너진 지붕 잔해(64×64): 비스듬히 꽂힌 트러스(삼각 격자) · 찢긴 흰 지붕 막 · 떨어진 조명 틀(전구 칸) · 바닥 파편."""
    im = img(64, 64)
    d = ImageDraw.Draw(im)
    _shadow(d, 2, 62, 60, 3)
    d.polygon([(4, 56), (58, 58), (54, 62), (8, 62)], fill=C("P05"))
    d.polygon([(6, 40), (40, 30), (60, 46), (34, 58)], fill=C(INK))   # 지붕 막
    d.polygon([(8, 41), (39, 32), (57, 46), (34, 56)], fill=C("P08"))
    d.line([8, 41, 39, 32], fill=C("P09"))
    d.polygon([(30, 44), (40, 40), (36, 50)], fill=C("P05"))          # 찢긴 구멍
    for (a, b) in (((4, 54), (44, 4)), ((14, 58), (52, 10))):         # 트러스 두 줄
        d.line([a, b], fill=C(INK), width=3); d.line([a, b], fill=C("P13"))
    for t in range(1, 8):
        x0, y0 = 4 + 40 * t / 8, 54 - 50 * t / 8
        x1, y1 = 14 + 38 * t / 8, 58 - 48 * t / 8
        d.line([x0, y0, x1, y1], fill=C("P12"))
        if t % 2:
            d.line([x0, y0, 14 + 38 * (t + 1) / 8, 58 - 48 * (t + 1) / 8], fill=C("P11"))
    d.rectangle([40, 48, 58, 56], fill=C(INK)); d.rectangle([41, 49, 57, 55], fill=C("P04"))    # 조명 틀
    for x in range(42, 57, 4):
        d.ellipse([x, 50, x + 2, 53], fill=C("P07")); d.point((x + 1, 51), fill=C("P09"))
    return im


def w_gd_banner():
    """2077 개막전 현수막(64×36, 벽): 바랜 남색 천 · 흰 글씨 '프로야구 개막' · '2077' 붉은 글씨 · 한쪽 끈이 끊겨 처졌다."""
    im = img(64, 36)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 2), (62, 2), (62, 22), (40, 30), (2, 26)], fill=C(INK))
    d.polygon([(3, 3), (61, 3), (61, 21), (40, 29), (3, 25)], fill=C("P44"))
    d.line([3, 3, 61, 3], fill=C("P45"))
    for x in range(4, 60, 3):
        if x % 9 == 0:
            d.line([x, 4, x + 1, 22], fill=C("P43"))
    put_text(im, "프로야구 개막", 6, 5, "P08")
    put_text(im, "2077", 22, 15, "P54")
    d.line([2, 2, 0, 0], fill=C("P05")); d.line([62, 22, 63, 34], fill=C("P05"))
    return im


def _r(fn, fw, fh, kind="floor", down=2, dx=0, dy=0):
    return {"fn": fn, "foot": (fw, fh), "kind": kind, "down": down, "dx": dx, "dy": dy}


PROPS_S10 = {
    "gd_podium": _r(gd_podium, 4, 2, down=-2),
    "gd_board": _r(gd_board, 3, 1, down=-2),
    "gd_seats": _r(lambda: gd_seats(0), 2, 1, down=-2),
    "gd_seats2": _r(lambda: gd_seats(1), 2, 1, down=-2),
    "w_vip_glass": _r(w_vip_glass, 3, 0, "wall", dx=0, dy=8),
    "cheer_sticks": _r(cheer_sticks, 0, 0, "deco"),
    "light_shaft": _r(light_shaft, 0, 0, "deco"),
    "ledger_box": _r(ledger_box, 1, 1, down=-2),
    "paddle_table": _r(paddle_table, 2, 1, down=-2),
    "broadcast_desk": _r(broadcast_desk, 2, 1, down=-2),
    "w_lotto_poster": _r(w_lotto_poster, 1, 0, "wall", dx=0, dy=8),
    "snack_counter": _r(snack_counter, 2, 1, down=-2),
    "dugout_bench": _r(dugout_bench, 3, 1, down=-2),
    "home_plate": _r(home_plate, 0, 0, "deco"),
    "base_bag": _r(base_bag, 0, 0, "deco"),
    "chalk_h": _r(lambda: chalk(False), 0, 0, "deco"),
    "chalk_v": _r(lambda: chalk(True), 0, 0, "deco"),
    "roof_debris": _r(roof_debris, 2, 2, down=-2),
    "w_gd_banner": _r(w_gd_banner, 2, 0, "wall", dx=0, dy=6),
}

STATES_S10 = {
    "gd_board": {s: (lambda s=s: gd_board(s)) for s in ["p%d" % v for v in PRICES] + ["sold_sv", "sold_tank", "stop", "free", "raid"]},
    "w_vip_glass": {"sil": lambda: w_vip_glass("sil"), "broken": lambda: w_vip_glass("broken")},
    "ledger_box": {"open": lambda: ledger_box("open")},
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/props_s10.png"
    ims = [v["fn"]() for v in PROPS_S10.values()] + [f() for st in STATES_S10.values() for f in st.values()]
    rows, row, w = [], [], 0
    for i in ims:
        if w + i.width + 6 > 420 and row:
            rows.append(row); row, w = [], 0
        row.append(i); w += i.width + 6
    rows.append(row)
    W = max(sum(i.width + 6 for i in r) for r in rows) + 4
    Hs = [max(i.height for i in r) + 6 for r in rows]
    sheet = Image.new("RGBA", (W, sum(Hs) + 4), C("P30"))
    y = 2
    for r, hh in zip(rows, Hs):
        x = 2
        for i in r:
            sheet.alpha_composite(i, (x, y)); x += i.width + 6
        y += hh
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    sheet.save(out)
    print(out)
