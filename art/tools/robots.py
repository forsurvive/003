"""세진 로봇 시트(아이작풍, 단계 1-7c): 살핌-1(SJ-G68) 부양 구체 — SD-14 §8.2 '소형 확성기를 단 작은 구체'.

- 간호 7호(N-R01-058, 흑석 대학병원): 살핌-1 + 붉은 십자 자리에 손으로 덧칠한 '7' + 붕대 말이를 쥔 집게팔(SD-09a L-R01-26).
- 발이 없다: 몸은 바닥 그림자 위 16px에 떠서 위아래로 1px씩 흔들리고, 그림자는 제자리(미끄러짐 규칙과 무관 — 디딘 발이 없다).
- 옆(E)만 그리고 W는 뒤집는다(백구 시트와 같은 형식). idle 4 · walk 4(앞으로 1px 기울고 분사구 불꽃이 길다) · death 4(불꽃 → 추락 → 금 간 채 누움).
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P

FW, FH = 44, 54
FOOT = (22, 50)                      # 그림자 가운데 = 노드 발 기준점
INK = "P01"


def C(t):
    return P.rgb(t)


def img(w=FW, h=FH):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _shadow(d, cx, cy, rx):
    """디더 그림자(반투명 없음): 바깥 줄은 체크 무늬, 안은 채움."""
    for y in range(cy - 2, cy + 3):
        for x in range(cx - rx, cx + rx + 1):
            e = ((x - cx) / rx) ** 2 + ((y - cy) / 2.6) ** 2
            if e <= 0.45 or (e <= 1.0 and (x + y) % 2 == 0):
                d.point((x, y), fill=C("P02"))


def _seven(d, x, y):
    """손으로 덧칠한 붉은 '7'(3×5 획, 붓 자국 한 점 삐침)."""
    col = C("P53")
    d.line([x, y, x + 3, y], fill=col)
    d.line([x + 3, y, x + 1, y + 5], fill=col)
    d.point((x + 2, y + 2), fill=col)
    d.point((x - 1, y + 1), fill=C("P52"))                            # 십자를 덮은 흰 칠 위로 번진 자국


def salpim(frame=0, pose="idle", nurse=True):
    """살핌-1 한 컷. pose: idle | walk | death(frame 0~3)."""
    im = img()
    d = ImageDraw.Draw(im)
    fx, fy = FOOT
    if pose == "death":
        return _salpim_death(frame, nurse)
    bob = [0, -1, -1, 0][frame % 4]
    lean = 1 if pose == "walk" else 0
    cx, cy = fx + lean, fy - 26 + bob                                 # 구체 가운데(바닥에서 26px 위)
    r = 10
    _shadow(d, fx, fy, 8 if bob == 0 else 7)
    # 분사구 불꽃(아래로 · 컷마다 길이가 바뀐다)
    fl = ([2, 3, 2, 4] if pose == "idle" else [4, 5, 4, 6])[frame % 4]
    d.rectangle([cx - 2, cy + r - 1, cx + 2, cy + r + 1], fill=C("P03"))
    d.line([cx - 1, cy + r + 2, cx - 1, cy + r + 1 + fl], fill=C("P59"))
    d.line([cx, cy + r + 2, cx, cy + r + 2 + fl], fill=C("P60"))
    d.line([cx + 1, cy + r + 2, cx + 1, cy + r + 1 + fl - 1], fill=C("P59"))
    d.point((cx, cy + r + 2), fill=C("P50"))
    # 뒤 지느러미 안테나 둘(몸 뒤에 먼저)
    d.polygon([(cx - r + 1, cy - 7), (cx - r - 3, cy - 11), (cx - r - 3, cy - 8), (cx - r + 1, cy - 3)], fill=C(INK))   # 뒤 지느러미
    d.polygon([(cx - r + 1, cy - 6), (cx - r - 2, cy - 9), (cx - r - 2, cy - 8), (cx - r + 1, cy - 4)], fill=C("P12"))
    d.line([cx - 3, cy - r, cx - 4, cy - r - 4], fill=C(INK))                                                          # 짧은 안테나
    d.point((cx - 4, cy - r - 5), fill=C("P63") if frame % 2 == 0 else C("P62"))
    # 몸: 외곽 → 크림 → 아래 그늘 → 위 빛
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=C(INK))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C("P07"))                          # 빛은 왼쪽 위: 오른쪽 아래 초승달 그늘
    d.ellipse([cx - r, cy - r, cx + r - 2, cy + r - 2], fill=C("P08"))
    d.ellipse([cx - r + 2, cy - r + 2, cx - 1, cy - 2], fill=C("P09"))
    d.point((cx - r + 4, cy - r + 4), fill=C("P09"))
    d.arc([cx - r, cy - r, cx + r, cy + r], 40, 110, fill=C("P06"))
    # 적도 청록 띠 + 리벳
    d.rectangle([cx - r + 1, cy + 1, cx + r - 1, cy + 3], fill=C("P61"))
    d.line([cx - r + 2, cy + 1, cx + r - 2, cy + 1], fill=C("P62"))
    for x in range(cx - r + 3, cx + r - 2, 4):
        d.point((x, cy + 2), fill=C("P63"))
    # 옆면 흰 칠 판(붉은 십자를 덮음) + '7'
    d.rectangle([cx - 6, cy - 7, cx - 1, cy - 1], fill=C("P09"))
    d.line([cx - 6, cy - 1, cx - 1, cy - 1], fill=C("P07"))
    if nurse:
        _seven(d, cx - 5, cy - 7)
    else:
        for rr in (2, 1):                                              # 관제망 휘장(동심원 + 열쇠 구멍)
            d.ellipse([cx - 4 - rr, cy - 4 - rr, cx - 4 + rr, cy - 4 + rr], outline=C("P53"))
    # 눈(앞쪽 렌즈): 검은 유리 + 청록 눈동자(깜박 — 컷 3)
    d.ellipse([cx + 3, cy - 5, cx + 10, cy + 2], fill=C(INK))
    d.ellipse([cx + 4, cy - 4, cx + 9, cy + 1], fill=C("P02"))
    if frame % 4 != 3:
        d.rectangle([cx + 6, cy - 3, cx + 8, cy - 1], fill=C("P62"))
        d.point((cx + 7, cy - 3), fill=C("P63"))
    d.point((cx + 5, cy - 4), fill=C("P07"))                          # 유리 반짝
    # 확성기(정수리, 앞으로 벌어진 놋쇠 나팔)
    d.polygon([(cx - 1, cy - r - 1), (cx + 3, cy - r - 1), (cx + 9, cy - r - 6), (cx + 9, cy - r + 1)], fill=C(INK))
    d.polygon([(cx, cy - r - 1), (cx + 3, cy - r - 1), (cx + 8, cy - r - 4), (cx + 8, cy - r)], fill=C("P48"))
    d.line([cx + 8, cy - r - 4, cx + 8, cy - r], fill=C("P50"))
    d.line([cx, cy - r - 1, cx + 3, cy - r - 1], fill=C("P47"))
    if nurse:
        # 집게팔(아래 앞쪽) + 붕대 말이
        ax, ay = cx + 4, cy + r - 3                                    # 몸 아래 앞쪽에서 접힌 짧은 팔
        d.line([ax, ay, ax + 2, ay + 3], fill=C(INK), width=2)
        d.line([ax + 2, ay + 3, ax + 5, ay + 3], fill=C(INK), width=2)
        d.line([ax, ay, ax + 2, ay + 3], fill=C("P13"))
        d.line([ax + 2, ay + 3, ax + 4, ay + 3], fill=C("P13"))
        d.rectangle([ax + 4, ay + 1, ax + 8, ay + 5], fill=C(INK))           # 붕대 말이(집게에 물림)
        d.rectangle([ax + 5, ay + 2, ax + 7, ay + 4], fill=C("P09"))
        d.point((ax + 5, ay + 4), fill=C("P07"))
        d.line([ax + 7, ay + 5, ax + 7 + (frame % 2), ay + 7], fill=C("P08"))   # 풀린 붕대 끝이 흔들린다
    return im


def _salpim_death(frame, nurse):
    """0 불꽃 튐(떠 있음) · 1 기울며 떨어짐 · 2 바닥에 닿아 튐 · 3 금 간 채 누움(눈 꺼짐)."""
    fx, fy = FOOT
    if frame <= 1:
        base = salpim(1, "idle", nurse)
        out = img()
        drop = [0, 9][frame]
        out.alpha_composite(base.crop((0, 0, FW, fy - 4)), (0, drop))
        d = ImageDraw.Draw(out)
        _shadow(d, fx, fy, 7 + frame)
        for (sx, sy, c) in [(fx + 6, fy - 36, "P50"), (fx - 8, fy - 30, "P60"), (fx + 11, fy - 26, "P63"), (fx - 3, fy - 40, "P50")]:
            d.point((sx, sy + drop), fill=C(c))
            d.point((sx + (1 if frame else -1), sy + drop - 1), fill=C(c))
        return out
    out = img()
    d = ImageDraw.Draw(out)
    cx, cy = fx, fy - 7 - (2 if frame == 2 else 0)
    r = 9
    _shadow(d, fx, fy, 10)
    d.ellipse([cx - r - 1, cy - r, cx + r + 1, cy + r - 1], fill=C(INK))
    d.ellipse([cx - r, cy - r + 1, cx + r, cy + r - 2], fill=C("P07"))
    d.chord([cx - r, cy - r + 1, cx + r, cy + r - 2], 200, 320, fill=C("P08"))
    d.rectangle([cx - r + 1, cy - 1, cx + r - 1, cy + 1], fill=C("P61"))
    d.ellipse([cx + 2, cy - 5, cx + 8, cy + 1], fill=C("P02"))          # 꺼진 눈
    d.line([cx - 4, cy - 7, cx - 1, cy - 2], fill=C(INK)); d.line([cx - 1, cy - 2, cx - 3, cy + 2], fill=C(INK))   # 금
    d.polygon([(cx + 6, cy - r + 2), (cx + 12, cy - r - 1), (cx + 12, cy - r + 4)], fill=C("P47"))   # 찌그러진 확성기
    if nurse:
        d.rectangle([cx + 10, cy + 4, cx + 14, cy + 7], fill=C("P09")); d.line([cx + 14, cy + 6, cx + 18, cy + 7], fill=C("P08"))   # 굴러간 붕대
    if frame == 2:
        d.point((cx - 9, cy - 9), fill=C("P50")); d.point((cx + 10, cy - 10), fill=C("P60"))
    else:
        d.point((cx - 5, cy - r - 2), fill=C("P05")); d.point((cx - 4, cy - r - 4), fill=C("P04"))   # 연기 한 올
    return out


def salpim_sheet(nurse=True):
    """시트 프레임 목록과 메타(quad_sheet와 같은 형식): idle 4 · walk 4 · death 4."""
    frames = [salpim(i, "idle", nurse) for i in range(4)] + [salpim(i, "walk", nurse) for i in range(4)] + \
             [salpim(i, "death", nurse) for i in range(4)]
    meta = {"frame": [FW, FH], "foot": list(FOOT), "dirs": ["E"],
            "motions": {"idle": {"start": 0, "count": 4}, "walk": {"start": 4, "count": 4}, "death": {"start": 8, "count": 4}},
            "hover": True}
    return frames, meta


def salpim_portrait(emo="기본", nurse=True):
    """대화 초상화(96×96, 투명 바탕): 살핌-1 구체를 가까이서 — 크림 몸 · 청록 띠 · 정수리 확성기 · 옆면 '7'.
    표정은 렌즈 하나로: 기본 점 · 말함 깜박 줄 · 놀람 커진 고리 · 미소 반달 · 슬픔 처진 반달 · 분노 붉은 점 · 아픔 금 · 피곤 반쯤 닫힘."""
    im = img(96, 96)
    d = ImageDraw.Draw(im)
    cx, cy, r = 48, 50, 30
    d.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], fill=C(INK))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C("P07"))
    d.ellipse([cx - r, cy - r, cx + r - 6, cy + r - 6], fill=C("P08"))
    d.ellipse([cx - r + 6, cy - r + 6, cx - 6, cy - 6], fill=C("P09"))
    d.arc([cx - r, cy - r, cx + r, cy + r], 40, 110, fill=C("P06"), width=2)
    d.rectangle([cx - r + 2, cy + 4, cx + r - 2, cy + 10], fill=C("P61"))
    d.line([cx - r + 3, cy + 4, cx + r - 3, cy + 4], fill=C("P62"))
    for x in range(cx - r + 6, cx + r - 4, 8):
        d.rectangle([x, cy + 6, x + 1, cy + 7], fill=C("P63"))
    d.rectangle([cx - 24, cy - 20, cx - 8, cy - 4], fill=C("P09")); d.line([cx - 24, cy - 4, cx - 8, cy - 4], fill=C("P07"))
    if nurse:                                                            # 손으로 칠한 '7'(굵은 붓)
        col = C("P53")
        d.line([cx - 21, cy - 17, cx - 11, cy - 17], fill=col, width=3)
        d.line([cx - 11, cy - 17, cx - 17, cy - 6], fill=col, width=3)
        d.point((cx - 23, cy - 15), fill=C("P52"))
    else:
        d.ellipse([cx - 22, cy - 18, cx - 10, cy - 6], outline=C("P53"), width=2)
    d.polygon([(cx - 4, cy - r - 2), (cx + 8, cy - r - 2), (cx + 26, cy - r - 16), (cx + 26, cy - r + 4)], fill=C(INK))   # 확성기
    d.polygon([(cx - 2, cy - r - 2), (cx + 8, cy - r - 2), (cx + 24, cy - r - 12), (cx + 24, cy - r + 1)], fill=C("P48"))
    d.line([cx + 24, cy - r - 12, cx + 24, cy - r + 1], fill=C("P50"), width=2)
    ex, ey = cx + 14, cy - 10                                              # 렌즈
    d.ellipse([ex - 13, ey - 13, ex + 13, ey + 13], fill=C(INK))
    d.ellipse([ex - 11, ey - 11, ex + 11, ey + 11], fill=C("P02"))
    eye = C("P62"); hi = C("P63")
    if emo == "놀람":
        d.ellipse([ex - 8, ey - 8, ex + 8, ey + 8], outline=eye, width=2); d.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=hi)
    elif emo == "미소":
        d.arc([ex - 7, ey - 6, ex + 7, ey + 6], 200, 340, fill=eye, width=3)
    elif emo == "슬픔":                                                  # 바깥으로 처진 눈매 + 아래 작은 점(눈물 대신 응결)
        d.line([ex - 8, ey - 1, ex + 2, ey - 5], fill=C("P45"), width=3); d.ellipse([ex - 3, ey + 2, ex + 3, ey + 6], fill=C("P45"))
    elif emo == "분노":
        d.ellipse([ex - 5, ey - 5, ex + 5, ey + 5], fill=C("P53")); d.line([ex - 9, ey - 9, ex + 3, ey - 5], fill=C("P53"), width=2)
    elif emo == "아픔":
        d.ellipse([ex - 4, ey - 4, ex + 4, ey + 4], fill=C("P59"))
        d.line([ex - 10, ey - 6, ex - 2, ey + 2], fill=C("P07")); d.line([ex - 2, ey + 2, ex + 4, ey + 10], fill=C("P07"))
    elif emo == "피곤":
        d.rectangle([ex - 7, ey, ex + 7, ey + 4], fill=eye); d.rectangle([ex - 11, ey - 11, ex + 11, ey - 1], fill=C("P07"))
    elif emo == "말함":
        for k in (-4, 0, 4):
            d.line([ex - 7, ey + k, ex + 7, ey + k], fill=eye)
    else:
        d.ellipse([ex - 5, ey - 5, ex + 5, ey + 5], fill=eye); d.rectangle([ex - 1, ey - 4, ex + 1, ey - 2], fill=hi)
    d.point((ex - 7, ey - 7), fill=C("P07")); d.point((ex - 6, ey - 8), fill=C("P07"))   # 유리 반짝
    if nurse:                                                            # 아래 집게팔 끝의 붕대
        d.line([cx + 14, cy + r - 6, cx + 22, cy + r + 2], fill=C(INK), width=4); d.line([cx + 14, cy + r - 6, cx + 22, cy + r + 2], fill=C("P13"), width=2)
        d.rectangle([cx + 20, cy + r - 2, cx + 32, cy + r + 8], fill=C(INK)); d.rectangle([cx + 22, cy + r, cx + 30, cy + r + 6], fill=C("P09"))
        d.line([cx + 30, cy + r + 6, cx + 34, cy + r + 12], fill=C("P08"))
    return im


def check_palette():
    ok = P.allowed_set("UI")
    bad = set()
    for nurse in (True, False):
        for f in salpim_sheet(nurse)[0]:
            for px in f.get_flattened_data():
                if px[3] and tuple(px[:3]) not in ok:
                    bad.add("#%02X%02X%02X" % px[:3])
    return bad


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/salpim.png"
    fr, _ = salpim_sheet(True)
    fr2, _ = salpim_sheet(False)
    sheet = Image.new("RGBA", (FW * 12, FH * 2), (40, 44, 40, 255))
    for i, f in enumerate(fr):
        sheet.alpha_composite(f, (i * FW, 0))
    for i, f in enumerate(fr2):
        sheet.alpha_composite(f, (i * FW, FH))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
    print("팔레트 밖 색:", check_palette() or "없음")
