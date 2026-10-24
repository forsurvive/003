"""아이작풍 크리처(SD-14, SD-16 §5 v2.0): 큰바퀴 CR-002, 변이 들개, 변이 시궁쥐.
옆 3/4 모습 한 방향(E, W는 반전). 굵은 먹선, 면 세 단계, 다리는 거리 구동(컷당 px는 메타에).
"""
import os, sys, math, random
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from chibi import C, CLEAR, INK, L, outline, ramp, shade

SHELL = ramp(["P16", "P17", "P18", "P19", "P20"])


def _ellipse(img, cx, cy, rx, ry, col_ramp, hi=0.6, extra=None):
    for y in range(img.height):
        for x in range(img.width):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            q = nx * nx + ny * ny
            if q <= 1:
                nz = math.sqrt(1 - q)
                col = shade(col_ramp, nx * L[0] + ny * L[1] + nz * L[2], hi)
                if extra:
                    col = extra(nx, ny, col) or col
                img.putpixel((x, y), col)


# ---------------------------------------------------------------- 큰바퀴 CR-002 (칸 44×24, 발 기준점 (18, 21))
ROACH_FOOT = (18, 21)
ROACH_PX = 3                                       # 컷당 3px(4컷 = 12px 한 주기)


def roach(frame=0, pose="walk", hurt=False):
    img = Image.new("RGBA", (44, 24), CLEAR)
    d = ImageDraw.Draw(img)
    legc = [C("P02"), C("P16")]
    # 다리: 삼각 보행 두 묶음이 번갈아 디딘다. 디딘 다리는 컷마다 정확히 -3px(세계에서 고정).
    for far in (1, 0):
        y0 = 14 - far * 2
        for i, bx in enumerate((11, 17, 23)):
            grp = (i + far) % 2
            ph = (frame + grp * 2) % 4 if pose == "walk" else 0
            u = [3, 0, -1, 2][ph] if pose == "walk" else 0               # 디딤 0→1: -3px, 띄움 2·3: 앞으로
            lift = 0 if ph in (0, 1) else 1
            reach = (-6, 0, 6)[i]
            fx, fy = bx + reach + u, 20 - far * 3 - lift
            kx, ky = bx + reach // 2 + u // 2, y0 + 2 - lift
            d.line([bx, y0, kx, ky], fill=legc[far])
            d.line([kx, ky, fx, fy], fill=legc[far])
            d.point((fx + (1 if reach >= 0 else -1), fy), fill=legc[far])
    bob = 1 if pose == "walk" and frame % 2 else 0

    def wings(nx, ny, col):
        if -0.05 < ny < 0.12 and nx < 0.55:
            return SHELL[0]                                              # 날개 갈라진 줄
        if ny < -0.45 and -0.6 < nx < 0.2 and int((nx + 2) * 9 + (ny + 2) * 7) % 5:
            return SHELL[4]                                              # 윤기
        return None
    body = Image.new("RGBA", (44, 24), CLEAR)
    _ellipse(body, 17.5, 11.5 - bob, 12.5, 6.0, SHELL[:4], extra=wings)
    bd = ImageDraw.Draw(body)
    bd.ellipse([26, 6 - bob, 33, 14 - bob], fill=SHELL[1])                 # 앞가슴 방패
    bd.arc([26, 6 - bob, 33, 14 - bob], 200, 330, fill=SHELL[3])
    bd.ellipse([31, 9 - bob, 35, 13 - bob], fill=C("P02"))                 # 머리
    bd.point((33, 10 - bob), fill=C("P54") if hurt else C("P08"))
    img.alpha_composite(body)
    img = outline(img)
    d = ImageDraw.Draw(img)
    t = frame % 3
    for k, pts in enumerate((((35, 9 - bob), (38, 5), (41, 3 + t), (43, 5 + t)), ((35, 11 - bob), (39, 9), (42, 10 - t // 2), (43, 13 - t)))):
        d.line(pts, fill=SHELL[0] if k else C("P01"))                     # 더듬이: 먹선 없이 가늘게
    if hurt:
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                if px[x, y][3] and px[x, y] != INK:
                    px[x, y] = C("P09")
    return img


def ichor(seed, w=28, h=14):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    cols = [C("P29"), C("P30"), C("P31")]
    blobs = [(w / 2, h / 2, w * 0.2, h * 0.25)] + [(rnd.uniform(4, w - 4), rnd.uniform(2, h - 2), rnd.uniform(1.2, 2.4), rnd.uniform(1, 1.8)) for _ in range(6)]
    for y in range(h):
        for x in range(w):
            v = max(1 - ((x + .5 - bx) / rx) ** 2 - ((y + .5 - by) / ry) ** 2 for bx, by, rx, ry in blobs)
            if v > 0:
                px[x, y] = cols[2] if v > 0.6 else cols[1] if v > 0.25 else cols[0]
    return img


def roach_death():
    """뒤집혀 버둥 → 납작 → 점액만 남음(5컷)."""
    out = []
    base = roach(0, "idle")
    flip = base.transpose(Image.FLIP_TOP_BOTTOM)
    for k in range(2):                                                     # 뒤집혀 다리 버둥
        f = Image.new("RGBA", (44, 24), CLEAR)
        f.alpha_composite(flip.crop((0, 2, 44, 24)), (0, 2 + k))
        out.append(f)
    for k in range(2):                                                     # 납작
        sq = base.resize((44, max(4, 24 - 8 * (k + 1))), Image.NEAREST)
        f = Image.new("RGBA", (44, 24), CLEAR)
        f.alpha_composite(ichor(3 + k), (6, 10))
        f.alpha_composite(sq, (0, 24 - sq.height - 2))
        out.append(f)
    f = Image.new("RGBA", (44, 24), CLEAR)
    f.alpha_composite(ichor(9, 32, 14), (4, 9))
    out.append(f)
    return out


def roach_sheet():
    """시트 프레임 목록과 메타(art_import가 쓴다)."""
    frames = [roach(0, "idle")] + [roach(f) for f in range(4)] + roach_death()
    meta = {"frame": [44, 24], "foot": list(ROACH_FOOT), "rows": ["E"], "mirror": {"W": "E"}, "style": "isaac",
            "motions": {"idle": {"start": 0, "count": 1}, "walk": {"start": 1, "count": 4, "px_per_frame": ROACH_PX, "drive": "distance"},
                        "death": {"start": 5, "count": 5}}}
    return frames, meta


# ---------------------------------------------------------------- 변이 미국가재 CR-121 (칸 48×26, 발 기준점 (20, 23)) — 1-D 대방 지하차도
# SD-14: 둔치 흙 굴에서 나온다 · 집게 14. 붉은 갈색 마디 몸통 · 앞으로 내민 큰 집게 둘(한쪽이 더 크다) · 부채꼴 꼬리 · 더듬이 두 가닥.
# 걷기 다리 네 쌍이 두 묶음으로 번갈아 디딘다(디딘 다리는 컷마다 정확히 -2px — 세계에서 고정).
CRAY_FOOT = (20, 23)
CRAY_PX = 2
CRAY = ramp(["P23", "P24", "P25", "P26", "P27"])


def crayfish(frame=0, pose="walk", hurt=False, snap=0):
    img = Image.new("RGBA", (48, 26), CLEAR)
    d = ImageDraw.Draw(img)
    legc = [C("P02"), C("P24")]
    for far in (1, 0):                                                     # 다리 네 쌍
        y0 = 15 - far * 2
        for i, bx in enumerate((12, 16, 20, 24)):
            grp = (i + far) % 2
            ph = (frame + grp * 2) % 4 if pose == "walk" else 0
            u = [2, 0, -1, 1][ph] if pose == "walk" else 0
            lift = 0 if ph in (0, 1) else 1
            fx, fy = bx + u + (i - 1), 22 - far * 3 - lift
            kx, ky = bx + u // 2, y0 + 3 - lift
            d.line([bx, y0, kx, ky], fill=legc[far])
            d.line([kx, ky, fx, fy], fill=legc[far])
    bob = 1 if pose == "walk" and frame % 2 else 0

    def segs(nx, ny, col):
        if int((nx + 1.2) * 6) % 2 == 0 and abs(ny) < 0.85:
            return CRAY[1]                                                 # 마디 이음
        if ny < -0.5 and -0.4 < nx < 0.5:
            return CRAY[4]                                                 # 윤기
        return None
    body = Image.new("RGBA", (48, 26), CLEAR)
    _ellipse(body, 18.5, 13.5 - bob, 10.5, 5.0, CRAY[:4], extra=segs)      # 배 마디
    _ellipse(body, 29.5, 12.5 - bob, 5.5, 4.5, CRAY[1:5])                  # 머리가슴
    bd = ImageDraw.Draw(body)
    bd.polygon([(8, 10 - bob), (3, 7 - bob), (2, 13 - bob), (3, 18 - bob), (8, 16 - bob)], fill=CRAY[2])   # 부채꼴 꼬리
    bd.line([(3, 9 - bob), (7, 12 - bob)], fill=CRAY[0]); bd.line([(3, 16 - bob), (7, 14 - bob)], fill=CRAY[0])
    bd.point((32, 10 - bob), fill=C("P54") if hurt else C("P01"))       # 눈자루
    bd.point((32, 9 - bob), fill=C("P02"))
    img.alpha_composite(body)
    img = outline(img)
    # 집게: 몸과 따로 먹선을 둘러 앞으로 뻗는다(머리와 뭉치지 않게) — 먼 쪽(작은 것, 위)을 먼저, 가까운 쪽(큰 것, 아래)을 위에
    for far, (ax, ay), (px_, py_), sz in ((1, (33, 10), (40, 6), 0.75), (0, (33, 14), (41, 17), 1.0)):
        cl = Image.new("RGBA", (48, 26), CLEAR)
        cd = ImageDraw.Draw(cl)
        rr = CRAY[0:4] if far else CRAY[1:5]
        py_ -= bob
        cd.line([ax, ay - bob, px_ - 3, py_], fill=rr[1], width=2)        # 팔 마디
        _ellipse(cl, px_ + 0.5, py_ + 0.5, 3.4 * sz + 0.4, 2.3 * sz + 0.4, rr[:4])
        gap = 2 if snap else 1
        tip = min(47, px_ + int(7 * sz))
        cd.polygon([(px_ + 1, py_ - 1), (tip, py_ - gap - 1), (tip - 2, py_ - gap - 2)], fill=rr[3])      # 위 손가락
        cd.polygon([(px_ + 1, py_ + 1), (tip - 1, py_ + gap), (tip - 3, py_ + gap + 1)], fill=rr[2])      # 아래 손가락
        cl = outline(cl)
        cd = ImageDraw.Draw(cl)
        cd.line([(px_ + 2, py_), (tip - 2, py_ - (gap - 1))], fill=INK)  # 손가락 사이 틈
        img.alpha_composite(cl)
    d = ImageDraw.Draw(img)
    t = frame % 3
    d.line([(34, 9 - bob), (39, 4), (44, 2 + t), (47, 3 + t)], fill=CRAY[0])   # 긴 더듬이
    d.line([(34, 10 - bob), (40, 7), (45, 7 - t // 2)], fill=C("P01"))
    if hurt:
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                if px[x, y][3] and px[x, y] != INK:
                    px[x, y] = C("P09")
    return img


def crayfish_death():
    """뒤집혀 다리 버둥 → 집게 늘어짐 → 껍데기만(4컷)."""
    out = []
    base = crayfish(0, "idle")
    flip = base.transpose(Image.FLIP_TOP_BOTTOM)
    for k in range(2):
        f = Image.new("RGBA", (48, 26), CLEAR)
        f.alpha_composite(flip.crop((0, 2, 48, 26)), (0, 2 + k))
        out.append(f)
    for k in range(2):
        sq = base.resize((48, max(6, 26 - 7 * (k + 1))), Image.NEAREST)
        f = Image.new("RGBA", (48, 26), CLEAR)
        f.alpha_composite(sq, (0, 26 - sq.height - 2))
        out.append(f)
    return out


def crayfish_sheet():
    frames = [crayfish(0, "idle")] + [crayfish(f) for f in range(4)] + [crayfish(0, "idle", snap=1)] + crayfish_death()
    meta = {"frame": [48, 26], "foot": list(CRAY_FOOT), "rows": ["E"], "mirror": {"W": "E"}, "style": "isaac",
            "motions": {"idle": {"start": 0, "count": 1}, "walk": {"start": 1, "count": 4, "px_per_frame": CRAY_PX, "drive": "distance"},
                        "attack": {"start": 5, "count": 1}, "death": {"start": 6, "count": 4}}}
    return frames, meta


# ---------------------------------------------------------------- 네발짐승(변이 들개·변이 시궁쥐): 큰 머리 + 작은 몸 + 짧은 다리
QUAD = {
    "dog": dict(w=44, h=32, foot=(20, 29), px=4, body=(19, 18, 10, 6.5), head=(32, 13, 7.5, 6.5), leg=5, fur=["P17", "P18", "P19", "P20"],
                skin=["P39", "P40", "P41"], eye="P54", tail="up", ears=True, mange=True),
    "jindo": dict(w=44, h=32, foot=(20, 29), px=4, body=(19, 18, 10, 6.5), head=(32, 12, 7.5, 6.5), leg=5, fur=["P06", "P07", "P08", "P09"],
                  skin=["P39", "P40", "P41"], eye="P01", tail="curl", ears=True, mange=False),
    # 황구(1-13e RE-053 길 잃은 정착지 진돗개 CR-108 판본): 백구와 같은 진돗개 몸에 누런 털 · 크림빛 주둥이 · 파란 천 목줄과 쇠 이름표
    # (백구 · 외눈과 한눈에 갈리게 — 흰 개가 아니고, 목줄이 새것이다)
    "hwanggu": dict(w=44, h=32, foot=(20, 29), px=4, body=(19, 18, 10, 6.5), head=(32, 12, 7.5, 6.5), leg=5, fur=["P25", "P26", "P27", "P21"],
                    skin=["P39", "P40", "P41"], eye="P01", tail="curl", ears=True, mange=False, nametag=True),
    # 경비견 CR-107(SD-14 §6, 새벽인력·약탈자 사육견): 검정·황갈 셰퍼드형, 선 귀, 검은 조끼 + 주황 띠(새벽인력 PF-05)
    "guard": dict(w=44, h=32, foot=(20, 29), px=4, body=(19, 18, 10, 6.5), head=(32, 13, 7.5, 6.5), leg=5, fur=["P01", "P02", "P03", "P18"],
                  skin=["P39", "P40", "P41"], eye="P49", tail="up", ears=True, mange=False, vest=True),
    # 외눈 CR-500(SD-14 §10.3 · SD-04a SQ-S01): 백구와 같은 진돗개 핏줄의 늙은 우두머리 — 한 치수 큰 몸, 때 탄 흰 털, 왼눈 흉터,
    # 뜯긴 귀 끝, 낡은 가죽 목줄과 2077년 인식표(금속 반짝임)
    "oenun": dict(w=44, h=32, foot=(20, 29), px=4, body=(19, 17, 11, 7), head=(32, 11, 8, 7), leg=5, fur=["P05", "P06", "P08", "P09"],
                  skin=["P39", "P40", "P41"], eye="P01", tail="curl", ears=True, mange=False, scar=True, tag=True),
    # 들개 우두머리 CR-106(SD-14 §4.2 '목에 2077년 반려견 인식표가 남은 큰 개체' · 1-13h 조율 — 무리 속에서 한눈에 갈려야 먼저 노린다):
    # 변이 들개 몸에 한 치수 큰 체구 · 희끗한 잿빛 털 · 늘어진 귀 · 긴 주둥이 · 낡은 가죽 목줄과 인식표(반짝)
    "packlead": dict(w=44, h=32, foot=(20, 29), px=4, body=(19, 16, 12, 7.5), head=(32, 11, 8.5, 7), leg=5, fur=["P02", "P23", "P04", "P19"],
                     skin=["P39", "P40", "P41"], eye="P54", tail="up", ears=True, mange=False, tag=True, tag_big=True, scars=True),
    # 사나운 들개 CR-105(SD-14 §4.7): 변이 들개보다 크고 어두운 털, 붉은 눈, 몸의 물린 흉터
    "fierce": dict(w=44, h=32, foot=(20, 29), px=4, body=(19, 17, 11, 7), head=(32, 12, 8, 6.5), leg=5, fur=["P10", "P11", "P12", "P13"],
                   skin=["P39", "P40", "P41"], eye="P54", tail="up", ears=True, mange=False, scars=True),
    # 들개 새끼(1-12g UQ-02 — 어미 잃은 변이 들개 새끼, 데려오면 마을 강아지 CR-108 판본): 들개 털빛을 한 단 밝게 · 머리가 몸만큼 큼 ·
    # 늘어진 귀 · 짧은 다리 · 옴 없음(아직 어리다) · 한쪽 귀 끝만 흰 털(백구가 핥아 준 자리 — 바크 · 이름표 그림과 같은 표지)
    "pup": dict(w=32, h=24, foot=(14, 21), px=2, body=(13, 14, 6.5, 4), head=(22, 10, 6.5, 5.5), leg=3, fur=["P18", "P19", "P20", "P21"],
                skin=["P39", "P40", "P41"], eye="P01", tail="tick", ears=True, mange=False, ribs=False),
    "rat": dict(w=40, h=22, foot=(18, 19), px=2, body=(17, 13, 9, 5), head=(27, 12, 5, 4.5), leg=3, fur=["P03", "P04", "P05", "P06"],
                skin=["P40", "P41", "P42"], eye="P54", tail="long", ears=True, mange=False),
    # 왕쥐 CR-097(SD-14 §4.1 '대형 확대 스프라이트', SQ-S03 계곡 암거): 시궁쥐 우두머리 — 한 치수 반 큰 몸(같은 걸음 리그를 원래 크기로 그린다 —
    # 늘린 그림이 아니다), 어두운 잿빛 털에 옴 자국 · 등의 긴 흉터 · 찢긴 귀 · 붉은 눈 · 누렇게 휜 앞니 · 꼬리 셋이 엉킨 매듭(쥐왕 전설)
    "ratking": dict(w=62, h=32, foot=(27, 29), px=3, body=(26, 17, 13, 7), head=(40, 15, 7, 5.5), leg=4, fur=["P02", "P03", "P04", "P05"],
                    skin=["P39", "P40", "P41"], eye="P54", tail="knot", ears=True, mange=True, ribs=False),
    # 옴 너구리 CR-136(SD-14 §4.9, 1-T2 밤 인카운터): 시궁쥐보다 둥글고 털이 부푼 잿빛 몸 · 눈가 검은 띠와 흰 눈썹 · 짧은 둥근 귀 ·
    # 털 빠진 꼬리(옴, 군데군데 분홍 살과 남은 검은 고리) · 몸통에도 옴 자국
    "raccoon": dict(w=46, h=24, foot=(22, 21), px=2, body=(21, 14, 10, 6), head=(32, 12, 6, 5.5), leg=3, fur=["P03", "P04", "P05", "P07"],
                    skin=["P40", "P41", "P42"], eye="P01", tail="mangy", ears=True, mange=True, ribs=False),
    # 굴쥐 CR-096(SD-14 §4.1 '흙빛 팔레트 + 땅속에서 머리만 내민 전용 프레임', 1-D3 독산): 시궁쥐보다 낮고 통통한 흙빛 몸 · 귀는 털 속에 묻힌 점 ·
    # 거의 감긴 작은 눈 · 넓적한 분홍 코 · 먹선 밖으로 튀어나온 누런 앞니 넷 · 앞발의 흰 굴 파기 발톱 · 뭉툭한 짧은 꼬리 · 털에 묻은 흙
    "mole": dict(w=44, h=24, foot=(20, 21), px=2, body=(18, 13, 10, 5), head=(29, 13, 5.5, 4.8), leg=3, fur=["P16", "P17", "P18", "P19"],
                 skin=["P40", "P41", "P42"], eye="P01", tail="stub", ears=False, mange=False, ribs=False),
}


def quad(kind, frame=0, pose="walk"):
    """4컷 종종걸음(대각 다리 짝이 번갈아 2컷씩 딛는다, 디딘 발은 컷마다 -px = 세계에서 고정)."""
    q = QUAD[kind]
    img = Image.new("RGBA", (q["w"], q["h"]), CLEAR)
    d = ImageDraw.Draw(img)
    fur = ramp(q["fur"])
    p = q["px"]
    u0 = (p + 1) // 2
    table = [(u0, 0), (u0 - p, 0), (u0 - p, 2), (0, 2)]               # 디딤 0·1, 띄움 2·3
    bx, by, brx, bry = q["body"]
    bob = 1 if pose == "walk" and frame % 2 else 0
    hips = {"front": bx + brx * 0.55, "back": bx - brx * 0.6}
    for far in (1, 0):
        for end in ("back", "front"):
            pair = (0 if (end == "front") == (far == 0) else 2)            # 대각 짝
            ph = (frame + pair) % 4 if pose == "walk" else 0
            u, lift = table[ph] if pose == "walk" else (0, 0)
            hx = round(hips[end]) - far
            fx, fy = hx + u, q["foot"][1] - far * 2 - lift
            col = fur[0] if far else fur[1]
            d.line([hx, by + 2 - bob, fx, fy - 1], fill=col, width=2)
            d.point((fx + 1, fy - 1), fill=C("P02"))
            if kind == "mole" and end == "front":                          # 굴 파기 발톱: 앞발 끝 흰 갈퀴 셋(먼 발은 한 단 어둡게)
                cl = C("P07") if far else C("P08")
                d.line([fx + 1, fy, fx + 4, fy], fill=cl); d.point((fx + 3, fy - 1), fill=cl); d.point((fx + 4, fy - 1), fill=C("P07"))
                d.point((fx + 2, fy + 1) if fy + 1 < q["h"] else (fx + 2, fy), fill=C("P06"))
    body = Image.new("RGBA", img.size, CLEAR)

    def mange(nx, ny, col):
        if q["mange"] and math.sin(nx * 7 + 2) * math.sin(ny * 6 - 1) > (0.9 if kind == "ratking" else 0.6):
            return ramp(q["skin"])[1]
        if q["mange"] and q.get("ribs", True) and ny > 0.1 and abs((nx * 6) % 1 - 0.5) < 0.12:
            return fur[0]                                                  # 드러난 갈비
        return None
    _ellipse(body, bx, by - bob, brx, bry, fur, extra=mange)
    if q.get("vest"):                                                      # 검은 조끼(가슴·등) + 주황 띠 + 버클
        vb = ImageDraw.Draw(body)
        x0, x1 = round(bx - brx * 0.45), round(bx + brx * 0.65)
        y0, y1 = round(by - bob - bry + 1), round(by - bob + bry - 2)
        vb.rectangle([x0, y0, x1, y1], fill=C("P02"))
        vb.line([x0, y0, x1, y0], fill=C("P04"))
        vb.rectangle([x0, (y0 + y1) // 2, x1, (y0 + y1) // 2 + 1], fill=C("P26"))
        vb.point((x1 - 2, y0 + 2), fill=C("P07"))
    hxc, hyc, hrx, hry = q["head"]
    _ellipse(body, hxc, hyc - bob, hrx, hry, fur)
    bd = ImageDraw.Draw(body)
    hyb = round(hyc - bob)
    if kind in ("jindo", "oenun", "hwanggu"):                              # 진돗개(백구 · 외눈 · 황구): 쫑긋 선 세모 귀 + 짧은 주둥이 + 검은 코·눈
        ex = round(hxc - hrx * 0.25)
        bd.polygon([(ex - 3, hyb - 4), (ex, hyb - 11), (ex + 3, hyb - 4)], fill=fur[2])
        bd.polygon([(ex - 1, hyb - 5), (ex, hyb - 9), (ex + 1, hyb - 5)], fill=ramp(q["skin"])[1])
        sx = round(hxc + hrx - 2)
        bd.ellipse([sx - 1, hyb - 1, sx + 5, hyb + 4], fill=fur[3])
        bd.point((sx + 5, hyb), fill=C("P01")); bd.point((sx + 4, hyb), fill=C("P01"))
        bd.line([sx + 1, hyb + 3, sx + 4, hyb + 3], fill=fur[1])
        bd.point((round(hxc + 1), hyb - 2), fill=C(q["eye"]))
        bd.point((round(hxc + 1), hyb - 3), fill=C(q["eye"]))
    elif kind == "guard":                                                  # 셰퍼드형: 선 귀(검정) · 황갈 주둥이 · 목줄 고리
        ex = round(hxc - hrx * 0.3)
        bd.polygon([(ex - 3, hyb - 4), (ex - 1, hyb - 12), (ex + 2, hyb - 4)], fill=fur[0])
        bd.polygon([(ex - 2, hyb - 5), (ex - 1, hyb - 9), (ex + 1, hyb - 5)], fill=ramp(q["skin"])[0])
        sx = round(hxc + hrx - 2)
        bd.ellipse([sx - 1, hyb - 1, sx + 6, hyb + 4], fill=fur[3])
        bd.line([sx, hyb + 3, sx + 5, hyb + 3], fill=fur[1])
        bd.point((sx + 6, hyb), fill=C("P01")); bd.point((sx + 5, hyb), fill=C("P01"))
        bd.point((sx + 3, hyb + 4), fill=C("P09"))
        bd.point((round(hxc + 1), hyb - 2), fill=C(q["eye"]))
        bd.line([round(hxc - hrx + 1), hyb + 3, round(hxc - hrx + 3), hyb + 6], fill=C("P26"), width=2)   # 목줄
        bd.point((round(hxc - hrx + 2), hyb + 6), fill=C("P07"))
    elif kind == "pup":                                                    # 새끼: 큰 늘어진 귀(끝 흰 털) · 짧고 둥근 주둥이 · 큰 검은 눈
        ex = round(hxc - hrx * 0.4)
        bd.polygon([(ex - 3, hyb - 4), (ex + 3, hyb - 5), (ex - 2, hyb + 3)], fill=fur[0])
        bd.point((ex + 1, hyb - 5), fill=C("P09")); bd.point((ex + 2, hyb - 5), fill=C("P08"))   # 귀 윗단 흰 털(백구가 핥아 준 자리)
        sx = round(hxc + hrx - 2)
        bd.ellipse([sx - 1, hyb, sx + 3, hyb + 3], fill=fur[3])
        bd.point((sx + 3, hyb + 1), fill=C("P01"))
        bd.rectangle([round(hxc), hyb - 3, round(hxc) + 1, hyb - 2], fill=C(q["eye"]))
        bd.point((round(hxc), hyb - 3), fill=C("P09"))
    elif kind in ("dog", "fierce", "packlead"):
        ex = round(hxc - hrx * 0.45)                                       # 늘어진 귀
        bd.polygon([(ex - 2, hyb - 5), (ex + 3, hyb - 6), (ex - 3, hyb + 1)], fill=fur[0])
        sx = round(hxc + hrx - 2)                                          # 긴 주둥이 + 검은 코 + 이빨
        bd.ellipse([sx - 1, hyb - 1, sx + 6, hyb + 4], fill=fur[2])
        bd.line([sx, hyb + 3, sx + 5, hyb + 3], fill=fur[0])
        bd.point((sx + 6, hyb), fill=C("P01")); bd.point((sx + 5, hyb), fill=C("P01"))
        bd.point((sx + 2, hyb + 4), fill=C("P09")); bd.point((sx + 4, hyb + 4), fill=C("P09"))
        bd.point((round(hxc + 1), hyb - 2), fill=C(q["eye"]))
    elif kind == "raccoon":                                                # 너구리: 둥근 귀 둘 · 눈가 검은 띠 · 흰 눈썹 · 뾰족한 검은 코
        ex = round(hxc - 4)
        bd.ellipse([ex - 1, hyb - 7, ex + 2, hyb - 4], fill=fur[0])                  # 먼 귀(그늘)
        bd.ellipse([ex + 1, hyb - 8, ex + 5, hyb - 3], fill=fur[2])                  # 가까운 귀 · 흰 테 · 안쪽
        bd.point((ex + 3, hyb - 6), fill=C("P02")); bd.point((ex + 3, hyb - 8), fill=C("P08"))
        bd.rectangle([round(hxc - 3), hyb - 2, round(hxc + 4), hyb], fill=C("P01"))   # 눈가 띠
        bd.point((round(hxc - 4), hyb - 1), fill=C("P02"))
        bd.line([round(hxc - 1), hyb - 3, round(hxc + 3), hyb - 3], fill=C("P08"))   # 흰 눈썹
        bd.point((round(hxc + 2), hyb - 1), fill=C("P54"))                         # 눈빛(밤에 빛난다)
        sx = round(hxc + hrx - 1)
        bd.ellipse([sx - 2, hyb, sx + 3, hyb + 3], fill=C("P08"))                  # 흰 주둥이
        bd.point((sx + 3, hyb + 1), fill=C("P01")); bd.point((sx + 2, hyb + 1), fill=C("P01"))
    elif kind == "mole":                                                   # 굴쥐: 털 속에 묻힌 귀(점) · 넓적한 분홍 코 · 거의 감긴 눈 · 흙 묻은 털
        sx = round(hxc + hrx - 2)
        bd.ellipse([sx - 2, hyb - 1, sx + 4, hyb + 4], fill=fur[3])                                 # 밝은 넓적 주둥이
        bd.line([sx - 1, hyb + 3, sx + 3, hyb + 3], fill=fur[1])
        bd.rectangle([sx + 3, hyb, sx + 5, hyb + 1], fill=ramp(q["skin"])[1]); bd.point((sx + 5, hyb), fill=ramp(q["skin"])[2])
        bd.line([round(hxc), hyb - 2, round(hxc + 2), hyb - 2], fill=C("P01"))                     # 실눈
        bd.point((round(hxc + 1), hyb - 3), fill=fur[3])
        bd.ellipse([round(hxc - 4), hyb - 4, round(hxc - 2), hyb - 2], fill=fur[0])                 # 털 속에 묻힌 귀
        bd.arc([round(hxc - hrx - 1), hyb - 6, round(hxc), hyb + 6], 100, 260, fill=fur[0])         # 목 주름(머리와 몸을 가른다)
        for gx, gy in ((bx - 6, by - 3), (bx - 1, by + 2), (bx + 4, by - 2), (bx - 3, by - 1)):
            bd.point((round(gx), round(gy - bob)), fill=C("P21"))                                   # 털에 묻은 흙(밝은 알갱이)
        bd.arc([round(bx - brx), round(by - bob - bry), round(bx + brx), round(by - bob + bry)], 200, 340, fill=fur[3])   # 등 윤곽 빛
    else:
        ex = round(hxc - 1)                                                # 동그란 귀(안쪽 분홍)
        bd.ellipse([ex - 2, hyb - 7, ex + 2, hyb - 3], fill=fur[2])
        bd.point((ex, hyb - 5), fill=ramp(q["skin"])[1])
        sx = round(hxc + hrx - 1)
        bd.ellipse([sx - 1, hyb - 1, sx + 3, hyb + 2], fill=fur[2])
        bd.point((sx + 3, hyb), fill=ramp(q["skin"])[2])
        bd.point((round(hxc + 1), hyb - 1), fill=C(q["eye"]))
    if kind == "ratking":                                                  # 왕쥐: 뾰족한 주둥이 · 큰 둥근 귀(찢긴 끝) · 등의 긴 흉터 · 굽은 등 털 다발
        sx = round(hxc + hrx - 2)
        bd.polygon([(sx - 2, hyb - 3), (sx + 7, hyb + 1), (sx - 2, hyb + 4)], fill=fur[2])         # 길게 뺀 주둥이
        bd.line([sx - 1, hyb + 3, sx + 5, hyb + 1], fill=fur[1])
        bd.point((sx + 7, hyb + 1), fill=ramp(q["skin"])[2]); bd.point((sx + 6, hyb + 1), fill=ramp(q["skin"])[1])   # 분홍 코끝
        ex = round(hxc - 3)
        bd.ellipse([ex - 3, hyb - 10, ex + 3, hyb - 4], fill=fur[3])                                # 큰 둥근 귀
        bd.ellipse([ex - 2, hyb - 9, ex + 2, hyb - 5], fill=ramp(q["skin"])[1])
        bd.point((ex + 2, hyb - 10), fill=(0, 0, 0, 0)); bd.point((ex + 3, hyb - 9), fill=(0, 0, 0, 0)); bd.point((ex + 2, hyb - 9), fill=fur[0])   # 찢긴 끝
        bd.arc([round(hxc - hrx), hyb - 6, round(hxc + 1), hyb + 6], 100, 260, fill=fur[0])         # 목 주름(머리와 몸을 가른다)
        y0 = round(by - bob - bry + 2)
        bd.line([round(bx - brx * 0.6), y0 + 1, round(bx + brx * 0.3), y0 - 1], fill=ramp(q["skin"])[1])
        for k in range(4):
            sx4 = round(bx - brx * 0.5 + k * 4)
            bd.point((sx4, y0 - 1 + (k % 2)), fill=ramp(q["skin"])[0])
        for k in range(4):
            gx = round(bx - brx * 0.2 + k * 3)
            bd.polygon([(gx - 1, y0 - 1), (gx, y0 - 4 + (k % 2)), (gx + 2, y0 - 1)], fill=fur[0])
    if q.get("scars"):                                                     # 사나운 들개: 곤두선 등 갈기(검푸른 털 위 뾰족 다발)
        for k in range(5):
            gx = round(bx - brx * 0.55 + k * 3)
            gy = round(by - bob - bry + 1)
            bd.polygon([(gx - 1, gy + 1), (gx + 1, gy - 3 + (k % 2)), (gx + 2, gy + 1)], fill=fur[0])
            bd.point((gx + 1, gy - 1), fill=fur[1])
    if q.get("scars"):                                                     # 사나운 들개: 옆구리 물린 흉터 셋(분홍 살 + 그늘)
        for k, (sx3, sy3) in enumerate(((bx - 4, by - 3), (bx + 1, by - 1), (bx + 5, by - 4))):
            bd.line([sx3, sy3 - bob, sx3 + 2, sy3 + 2 - bob], fill=ramp(q["skin"])[1])
            bd.point((sx3 + 1, sy3 + 2 - bob), fill=fur[0])
    if q.get("nametag"):                                                   # 황구: 새 파란 천 목줄 + 쇠 이름표(반짝)
        nx0 = round(hxc - hrx + 1)
        bd.line([nx0, hyb + 3, nx0 + 2, hyb + 7], fill=C("P12"), width=2)
        bd.point((nx0 + 1, hyb + 4), fill=C("P14"))
        bd.point((nx0 + 2, hyb + 8), fill=C("P08"))
        bd.point((nx0 + 3, hyb + 8), fill=C("P09"))
        bd.point((nx0 + 2, hyb + 9), fill=C("P07"))
    if q.get("tag"):                                                       # 외눈: 낡은 목줄 + 2077년 인식표 · 때 얼룩
        nx0 = round(hxc - hrx + 1)
        bd.line([nx0, hyb + 3, nx0 + 2, hyb + 7], fill=C("P18"), width=2)
        bd.point((nx0 + 2, hyb + 8), fill=C("P07"))                         # 인식표(쇠)
        bd.point((nx0 + 3, hyb + 8), fill=C("P49"))                         # 반짝임(놋쇠 테)
        if q.get("tag_big"):                                                # 우두머리: 목 아래로 늘어진 큰 쇠 인식표 — 무리 속에서 반짝여 먼저 눈에 든다
            bd.rectangle([nx0 + 1, hyb + 8, nx0 + 3, hyb + 10], fill=C("P07"))
            bd.point((nx0 + 2, hyb + 9), fill=C("P09")); bd.point((nx0 + 3, hyb + 8), fill=C("P50"))
        for gx, gy in ((bx - 5, by + 2), (bx + 3, by + 4), (bx - 1, by - 4)):
            bd.point((gx, gy - bob), fill=fur[1])
    img.alpha_composite(body)
    img = outline(img)
    d = ImageDraw.Draw(img)
    if q.get("scar"):                                                      # 외눈: 감긴 눈 위로 사선 흉터(먹선 위에 그어 또렷하게) · 귀 끝이 뜯겼다
        ex2, ey2 = round(hxc + 1), round(hyc - bob) - 2
        d.line([ex2 - 2, ey2 - 3, ex2 + 2, ey2 + 2], fill=C("P39"))
        d.point((ex2, ey2), fill=C("P01")); d.point((ex2 + 1, ey2), fill=C("P01"))
        d.point((ex2 - 1, ey2 - 2), fill=C("P40"))
        etip = round(hxc - hrx * 0.25)
        d.point((etip, round(hyc - bob) - 11), fill=(0, 0, 0, 0))
        d.point((etip, round(hyc - bob) - 10), fill=C("P01"))
    tx = round(bx - brx)
    if kind in ("rat", "ratking"):                                        # 수염(먹선 밖)
        sx2, sy2 = round(q["head"][0] + q["head"][2] + 2), round(q["head"][1] - bob)
        d.line([sx2, sy2, sx2 + 3, sy2 - 1], fill=C("P07")); d.line([sx2, sy2 + 1, sx2 + 3, sy2 + 2], fill=C("P07"))
    if kind == "mole":                                                    # 굴쥐 앞니 넷(위 둘 · 아래 둘 — 입을 다물어도 먹선 밖으로)
        tx2, ty2 = round(q["head"][0] + q["head"][2] + 1), round(q["head"][1] - bob) + 4
        d.line([tx2, ty2, tx2, ty2 + 2], fill=C("P49")); d.line([tx2 + 1, ty2, tx2 + 1, ty2 + 1], fill=C("P48"))
        d.point((tx2 + 1, ty2 + 2), fill=C("P01"))
    if kind == "ratking":                                                 # 누렇게 휜 앞니 둘(먹선 밖으로 삐져나온다) · 붉은 눈 두 점
        tx2, ty2 = round(q["head"][0] + q["head"][2] + 3), round(q["head"][1] - bob) + 3
        d.line([tx2, ty2, tx2, ty2 + 2], fill=C("P49")); d.line([tx2 + 1, ty2, tx2 + 1, ty2 + 2], fill=C("P48"))
        d.point((tx2, ty2 + 3), fill=C("P01"))
        d.point((round(q["head"][0] + 2), round(q["head"][1] - bob) - 2), fill=C("P53"))
    if q["tail"] == "curl":                                               # 진돗개 말린 꼬리(등 위로 둥글게)
        cx0, cy0 = tx + 1, by - 7 - bob
        d.ellipse([cx0 - 5, cy0 - 5, cx0 + 3, cy0 + 3], fill=C("P01"))
        d.ellipse([cx0 - 4, cy0 - 4, cx0 + 2, cy0 + 2], fill=fur[2])
        d.arc([cx0 - 3, cy0 - 3, cx0 + 1, cy0 + 1], 200, 20, fill=fur[3])
        d.point((cx0 - 1, cy0), fill=fur[1])
    elif q["tail"] == "tick":                                             # 새끼: 짧게 치켜든 꼬리(걷는 컷마다 흔들림)
        w = frame % 2
        d.line([(tx, by - 1 - bob), (tx - 2, by - 3 - bob), (tx - 2 - w, by - 5 - bob)], fill=fur[1])
        d.point((tx - 2 - w, by - 6 - bob), fill=fur[2])
    elif q["tail"] == "up":
        d.line([(tx, by - 2 - bob), (tx - 3, by - 6 - bob), (tx - 4, by - 9 - bob + (frame % 2))], fill=fur[0], width=2)
    elif q["tail"] == "mangy":                                            # 털 빠진 너구리 꼬리: 굵다 가늘어지고, 남은 털 고리 둘
        sw = frame % 2
        pts = [(tx + 1, by - bob), (tx - 4, by + 1 - sw), (tx - 8, by + 1), (tx - 11, by + 3 - sw)]
        d.line(pts[:2], fill=fur[1], width=3)
        d.line(pts[1:], fill=ramp(q["skin"])[1], width=2)
        d.line([pts[1][0] - 1, pts[1][1] - 1, pts[1][0] - 1, pts[1][1] + 1], fill=C("P01"))
        d.point((pts[2][0] - 1, pts[2][1]), fill=C("P02"))
        d.point((pts[3][0], pts[3][1]), fill=fur[1])
    elif q["tail"] == "knot":                                             # 왕쥐: 꼬리 셋이 엉덩이 뒤에서 한 매듭으로 엉켰다가 다시 갈라진다
        sw = frame % 2
        sk = ramp(q["skin"])
        kx, ky = tx - 6, by + 3 - bob
        for k, (dx, dy) in enumerate(((-9, 1 + sw), (-8, 5), (-6, -3 - sw))):
            d.line([(tx + 1, by - 1 + k - bob), (kx, ky)], fill=sk[1], width=2 if k == 0 else 1)
            d.line([(kx, ky), (kx + dx // 2, ky + dy // 2), (kx + dx, ky + dy)], fill=sk[k % 2 + 1])
        d.ellipse([kx - 2, ky - 2, kx + 2, ky + 2], fill=sk[0])               # 매듭(굳은 피딱지 · 흙)
        d.point((kx - 1, ky - 1), fill=sk[2]); d.point((kx + 1, ky), fill=C("P01"))
    elif q["tail"] == "stub":                                             # 굴쥐: 뭉툭한 짧은 꼬리(맨살)
        sk = ramp(q["skin"])
        d.line([(tx + 1, by + 1 - bob), (tx - 3, by + 2 - (frame % 2))], fill=sk[1], width=2)
        d.point((tx - 4, by + 2 - (frame % 2)), fill=sk[0])
    else:
        pts = [(tx, by + 1 - bob), (tx - 5, by + 3), (tx - 10, by + 2 + (frame % 2)), (tx - 14, by + 4)]
        d.line(pts, fill=ramp(q["skin"])[1])
    return img


def quad_lying(kind):
    """쓰러진(누운) 네발짐승: 옆으로 누운 몸 + 뻗은 다리 + 감은 눈. 사망·기절 마지막 컷."""
    q = QUAD[kind]
    img = Image.new("RGBA", (q["w"], q["h"]), CLEAR)
    fur = ramp(q["fur"])
    bx, by, brx, bry = q["body"]
    body = Image.new("RGBA", img.size, CLEAR)
    _ellipse(body, bx + 1, by + 6, brx + 2, bry - 1.5, fur)
    hxc, hyc, hrx, hry = q["head"]
    _ellipse(body, hxc + 2, by + 6, hrx, hry - 1, fur)
    bd = ImageDraw.Draw(body)
    for x in (bx - 6, bx - 2, bx + 4, bx + 8):                            # 뻗은 다리
        bd.line([x, by + 9, x + 4, by + 11], fill=fur[1], width=2)
    bd.line([round(hxc), by + 4, round(hxc) + 2, by + 4], fill=C("P01"))  # 감은 눈
    img.alpha_composite(body)
    return outline(img)


def quad_sleep(kind, breath=0):
    """엎드려 자는 진돗개(1-8b 백구 낮잠): 배를 깔고 앞발을 모아 뻗고, 턱을 앞발에 얹고, 말린 꼬리로 엉덩이를 감싼다.
    breath 1 = 들숨(등이 1px 오르고 귀 끝이 1px 들린다). 발 기준점은 서 있을 때와 같다(같은 칸에 놓인다)."""
    q = QUAD[kind]
    img = Image.new("RGBA", (q["w"], q["h"]), CLEAR)
    fur = ramp(q["fur"])
    fy = q["foot"][1]
    d0 = ImageDraw.Draw(img)
    d0.line([25, fy - 1, 33, fy - 1], fill=fur[0], width=2)                # 먼 앞발(뒤에 깔린)
    d0.line([10, fy, 16, fy], fill=fur[0], width=2)                        # 접힌 뒷다리 아랫단
    body = Image.new("RGBA", img.size, CLEAR)
    _ellipse(body, 18, fy - 5 - breath * 0.5, 11, 5 + breath * 0.5, fur)   # 엎드린 몸통
    _ellipse(body, 11, fy - 4, 5, 4, fur)                                  # 접힌 뒷다리 허벅지
    bd = ImageDraw.Draw(body)
    bd.line([24, fy, 35, fy], fill=fur[1], width=2)                        # 가까운 앞발(쭉 뻗음)
    bd.point((36, fy), fill=fur[0])
    bd.arc([24, fy - 11, 30, fy - 1], 110, 250, fill=fur[0])                # 목 주름(머리와 몸을 가르는 그늘)
    _ellipse(body, 31, fy - 5, 6.5, 4.6, fur)                              # 앞발 위에 얹은 머리
    bd.arc([25, fy - 10, 31, fy - 1], 120, 230, fill=fur[1])               # 뒤통수 가장자리
    sx = 36                                                                # 주둥이: 앞발에 턱을 얹었다
    bd.ellipse([sx - 1, fy - 6, sx + 4, fy - 2], fill=fur[3])
    bd.point((sx + 4, fy - 5), fill=C("P01")); bd.point((sx + 3, fy - 5), fill=C("P01"))
    bd.line([sx, fy - 2, sx + 3, fy - 2], fill=fur[1])
    ex = 29                                                                # 뒤로 눕힌 세모 귀(잘 때는 힘을 뺀다)
    bd.polygon([(ex - 3, fy - 8), (ex - 4 + breath, fy - 14 - breath), (ex + 1, fy - 9)], fill=fur[2])
    bd.polygon([(ex - 2, fy - 9), (ex - 3 + breath, fy - 12 - breath), (ex, fy - 9)], fill=ramp(q["skin"])[1])
    bd.line([31, fy - 6, 33, fy - 6], fill=C("P01"))                       # 감은 눈(한 줄)
    if q.get("nametag"):                                                   # 황구: 파란 목줄 · 이름표(턱 밑)
        bd.line([26, fy - 3, 28, fy - 1], fill=C("P12"), width=2)
        bd.point((29, fy), fill=C("P08")); bd.point((30, fy), fill=C("P09"))
    if q.get("tag"):                                                       # 외눈: 흉터 · 목줄과 인식표(턱 밑에 깔려 반짝)
        bd.line([30, fy - 9, 34, fy - 4], fill=C("P39"))
        bd.line([26, fy - 3, 28, fy - 1], fill=C("P18"), width=2)
        bd.point((29, fy), fill=C("P07")); bd.point((30, fy), fill=C("P49"))
    img.alpha_composite(body)
    img = outline(img)
    d = ImageDraw.Draw(img)
    cx0, cy0 = 8, fy - 6                                                   # 말린 꼬리: 엉덩이 옆으로 둥글게 감는다
    d.ellipse([cx0 - 4, cy0 - 4, cx0 + 4, cy0 + 4], fill=C("P01"))
    d.ellipse([cx0 - 3, cy0 - 3, cx0 + 3, cy0 + 3], fill=fur[2])
    d.arc([cx0 - 2, cy0 - 2, cx0 + 2, cy0 + 2], 200, 20, fill=fur[3])
    d.point((cx0, cy0), fill=fur[1])
    return img


# ---------------------------------------------------------------- 두머리소 CR-090 · 짐소 CR-091(SD-14 §4.10, 1-8d): 누렁소 두 머리, 짐소는 안장·짐
OX = dict(w=72, h=60, foot=(34, 56), px=3)
OX_FUR = ["P16", "P17", "P58", "P59", "P60"]


def _ox_head(im, cx, cy, far):
    """누렁소 머리 하나: 둥근 이마 + 밝은 주둥이 + 콧구멍 + 짧은 뿔 + 귀 + 눈. far면 한 단계 어둡게(뒤에 있는 머리)."""
    fur = ramp(OX_FUR[:-1] if far else OX_FUR[1:])
    _ellipse(im, cx, cy, 7.0, 6.0, fur)
    d = ImageDraw.Draw(im)
    mz = ramp(["P20", "P21", "P22"] if not far else ["P19", "P20", "P21"])
    _ellipse(im, cx + 6, cy + 2.5, 3.6, 3.0, mz)                         # 주둥이
    d.point((cx + 8, cy + 2), fill=C("P16")); d.point((cx + 8, cy + 4), fill=C("P16"))
    d.polygon([(cx - 3, cy - 4), (cx - 6, cy - 9), (cx - 4, cy - 9), (cx - 1, cy - 5)], fill=C("P08" if not far else "P07"))   # 뿔
    d.line([cx - 6, cy - 9, cx - 5, cy - 10], fill=C("P06"))
    d.polygon([(cx - 5, cy - 1), (cx - 10, cy - 3), (cx - 6, cy + 1)], fill=fur[1])                                          # 귀
    d.point((cx + 1, cy - 1), fill=C("P01")); d.point((cx + 2, cy - 1), fill=C("P01"))                                     # 눈
    if not far:
        d.point((cx + 1, cy - 2), fill=C("P09"))


def ox(frame=0, pose="walk", pack=False):
    """두머리소 옆모습(E). 4컷 걸음은 네발짐승과 같은 대각 짝(디딘 발은 컷마다 −px = 세계에서 고정, 발 미끄럼 없음)."""
    q = OX
    img = Image.new("RGBA", (q["w"], q["h"]), CLEAR)
    d = ImageDraw.Draw(img)
    fur = ramp(OX_FUR)
    p = q["px"]
    u0 = (p + 1) // 2
    table = [(u0, 0), (u0 - p, 0), (u0 - p, 2), (0, 2)]
    bx, by, brx, bry = 32, q["foot"][1] - 23, 19, 11
    bob = 1 if pose == "walk" and frame % 2 else 0
    hips = {"front": bx + 12, "back": bx - 12}
    for far in (1, 0):
        for end in ("back", "front"):
            pair = (0 if (end == "front") == (far == 0) else 2)
            ph = (frame + pair) % 4 if pose == "walk" else 0
            u, lift = table[ph] if pose == "walk" else (0, 0)
            hx = hips[end] - far * 3
            fx, fy = hx + u, q["foot"][1] - far * 2 - lift
            col = fur[1] if far else fur[2]
            d.line([hx, by + 4 - bob, fx, fy - 2], fill=col, width=4 if far else 5)   # 굵은 다리(먼 다리는 한 단계 어둡게)
            d.line([fx - 1, fy - 6, fx - 1, fy - 3], fill=fur[3] if not far else fur[2])  # 정강이 빛
            d.rectangle([fx - 2, fy - 2, fx + 2, fy], fill=C("P02"))          # 굽
    body = Image.new("RGBA", img.size, CLEAR)
    _ellipse(body, bx, by - bob, brx, bry, fur)
    _ellipse(body, bx - 13, by + 1 - bob, 8, 9, fur)                     # 엉덩이
    _ellipse(body, bx + 12, by - 3 - bob, 9, 10, fur)                    # 어깨 혹
    bd = ImageDraw.Draw(body)
    bd.arc([bx - 16, by + 2 - bob, bx + 14, by + 13 - bob], 20, 160, fill=fur[1])   # 배 그늘
    if pack:                                                             # 짐소: 안장 담요 · 짐 자루 둘 · 물통 · 밧줄
        bd.polygon([(bx - 10, by - 11 - bob), (bx + 10, by - 12 - bob), (bx + 12, by + 2 - bob), (bx - 12, by + 3 - bob)], fill=C("P53"))
        bd.line([bx - 10, by - 8 - bob, bx + 10, by - 9 - bob], fill=C("P50"))
        bd.line([bx - 11, by - 1 - bob, bx + 11, by - 2 - bob], fill=C("P52"))
        _ellipse(body, bx - 6, by - 2 - bob, 7, 6, ramp(["P19", "P20", "P21", "P22"]))   # 짐 자루(삼베)
        _ellipse(body, bx + 5, by - 3 - bob, 6, 5.5, ramp(["P18", "P19", "P20", "P21"]))
        bd.line([bx - 12, by - 6 - bob, bx - 1, by + 3 - bob], fill=C("P17"))  # 자루 묶은 끈
        bd.line([bx + 1, by - 7 - bob, bx + 10, by + 1 - bob], fill=C("P17"))
        bd.rectangle([bx - 2, by - 17 - bob, bx + 3, by - 10 - bob], fill=C("P36"))   # 물통
        bd.rectangle([bx - 1, by - 19 - bob, bx + 2, by - 17 - bob], fill=C("P35"))
        bd.line([bx - 15, by - 4 - bob, bx + 15, by - 6 - bob], fill=C("P18"))  # 밧줄(배띠)
    hb = 1 if pose == "walk" and frame % 2 == 0 else 0                  # 머리는 걸음과 반 박자 엇갈려 끄덕인다
    _ellipse(body, bx + 19, by - 13 - bob, 5, 7, ramp(OX_FUR[:-1]))     # 뒤 목(위로 갈라진다)
    _ox_head(body, bx + 23, by - 19 - bob - hb, True)                    # 뒤 머리(위·안쪽)
    _ellipse(body, bx + 22, by - 3 - bob, 6, 6, fur)                    # 앞 목
    _ox_head(body, bx + 30, by - 4 - bob + hb, False)                    # 앞 머리
    img.alpha_composite(body)
    img = outline(img)
    d = ImageDraw.Draw(img)
    tx = bx - 20
    d.line([(tx, by - 6 - bob), (tx - 4, by + 4), (tx - 4, by + 12 + (frame % 2))], fill=fur[1], width=2)   # 꼬리
    d.ellipse([tx - 6, by + 11 + (frame % 2), tx - 2, by + 16 + (frame % 2)], fill=C("P16"))                 # 꼬리 끝 술
    return img


def ox_lying(pack=False):
    """쓰러진 두머리소: 옆으로 누운 몸 + 뻗은 다리 + 감은 눈(사망·기절 마지막 컷). 짐은 옆으로 쏟아진다."""
    img = Image.new("RGBA", (OX["w"], OX["h"]), CLEAR)
    fur = ramp(OX_FUR)
    body = Image.new("RGBA", img.size, CLEAR)
    by = OX["foot"][1] - 9
    _ellipse(body, 32, by, 22, 8, fur)
    _ellipse(body, 56, by + 1, 7, 5, fur)
    _ellipse(body, 61, by - 4, 6, 4.5, ramp(OX_FUR[:-1]))
    bd = ImageDraw.Draw(body)
    for x in (18, 24, 40, 46):
        bd.line([x, by + 6, x + 6, by + 8], fill=fur[1], width=3)
    bd.line([55, by, 58, by], fill=C("P01")); bd.line([60, by - 5, 62, by - 5], fill=C("P01"))
    if pack:
        _ellipse(body, 26, by + 6, 6, 4, ramp(["P19", "P20", "P21", "P22"]))
        bd.rectangle([40, by - 7, 45, by - 2], fill=C("P36"))
        bd.polygon([(20, by - 7), (40, by - 8), (40, by - 3), (20, by - 2)], fill=C("P53"))
    img.alpha_composite(body)
    return outline(img)


def ox_sheet(pack=False):
    walk = [ox(f, "walk", pack) for f in range(4)]
    idle = [ox(0, "idle", pack)]
    lie = ox_lying(pack)
    mid = Image.new("RGBA", lie.size, CLEAR)
    mid.alpha_composite(walk[1], (0, 3))
    frames = idle + walk + [mid, lie, lie]
    meta = {"frame": [OX["w"], OX["h"]], "foot": list(OX["foot"]), "rows": ["E"], "mirror": {"W": "E"}, "style": "isaac",
            "motions": {"idle": {"start": 0, "count": 1}, "walk": {"start": 1, "count": 4, "px_per_frame": OX["px"], "drive": "distance"},
                        "death": {"start": 5, "count": 3}}}
    return frames, meta


def quad_sheet(kind):
    """네발짐승 시트(roach_sheet와 같은 형식): 옆(E)만, W는 뒤집기. idle 1 · walk 4 · run 4(같은 컷, 빠르게) · death 3."""
    if kind in ("ox", "ox_pack"):
        return ox_sheet(kind == "ox_pack")
    walk = [quad(kind, f) for f in range(4)]
    idle = [quad(kind, 0, "idle")]
    lie = quad_lying(kind)
    mid = Image.new("RGBA", lie.size, CLEAR)                             # 무너지는 중간 컷: 서 있는 몸을 2px 내린 모습
    mid.alpha_composite(walk[1], (0, 2))
    frames = idle + walk + [mid, lie, lie]
    q = QUAD[kind]
    meta = {"frame": [q["w"], q["h"]], "foot": list(q["foot"]), "rows": ["E"], "mirror": {"W": "E"}, "style": "isaac",
            "motions": {"idle": {"start": 0, "count": 1}, "walk": {"start": 1, "count": 4, "px_per_frame": q["px"], "drive": "distance"},
                        "death": {"start": 5, "count": 3}}}
    if kind in ("jindo", "oenun", "hwanggu"):                              # 백구 낮잠(1-8b) · 외눈 난간 낮잠(1-11a): 숨쉬기 2컷
        meta["motions"]["sleep"] = {"start": len(frames), "count": 2}
        frames += [quad_sleep(kind, 0), quad_sleep(kind, 1)]
    return frames, meta


def footlock_report():
    """디딘 다리 끝의 세계 x: 그림이 컷마다 3px 앞으로 갈 때 디딘 동안 그대로인가."""
    worst = 0
    for i in range(3):
        for far in (0, 1):
            grp = (i + far) % 2
            pts = []
            for f in range(4):
                ph = (f + grp * 2) % 4
                if ph in (0, 1):
                    pts.append(f * ROACH_PX + [3, 0, -1, 2][ph])
            for a, b in zip(pts, pts[1:]):
                worst = max(worst, abs(a - b)) if abs(a - b) < 6 else worst
    return worst


if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[2] == "quad":
    out = sys.argv[1]
    sheet = Image.new("RGBA", (46 * 8, 34 * 2), C("P19"))
    for r, k in enumerate(("dog", "rat")):
        for f in range(4):
            sheet.alpha_composite(quad(k, f), (f * 46, r * 34))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
    sys.exit()

if __name__ == "__main__":
    out = sys.argv[1]
    fr, _ = roach_sheet()
    sheet = Image.new("RGBA", (46 * len(fr), 26), C("P19"))
    for i, f in enumerate(fr):
        sheet.alpha_composite(f, (i * 46 + 1, 1))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
    print("roach footlock worst", footlock_report())
