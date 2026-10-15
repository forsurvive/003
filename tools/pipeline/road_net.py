"""도로망(SD-21): 간선 노선(위계 H1~H4)과 시가지 결별 동네 길(H5·H6) 생성.

리드 지시(2026-10-15): 실제와 정확히 같을 필요는 없다 — 바둑판이 아니라 '실제 같은 도시·동네·강변·황무지'의 다채로움이 목표.
그래서 간선은 서울 실제 노선을 지식 기반 위경도 웨이포인트(±150m 근사)로 찍고(SD-21 §3 2순위, 리드 승인 2026-10-15),
강변·하천변 고속도로는 게임 속 한강·지천 선을 따라 만든다(강과 어긋나지 않게).
동네 길은 흔들린 점들의 보로노이 경계로 만든다 — 3갈래 교차·비스듬한 블록·막다른 길이 저절로 생기고, 점 간격으로 결이 달라진다.
"""
import numpy as np

# SD-08 W2 변환식
def to_tile(lat, lon):
    return ((lon - 126.7550) * 4769.46, (37.7080 - lat) * 5999.46)


# 위계별 단면(SD-21 §4): (차도 폭, 중앙분리대, 보도 한쪽) — 타일
SECTION = {"H1": (10, 1, 0), "H2": (6, 1, 2), "H3": (5, 0, 1), "H4": (4, 0, 1)}

# 간선 노선: (이름, 위계, [(위도, 경도) …]) — 서울 실제 노선의 근사 웨이포인트. 하천변 고속도로는 아래 RIVERSIDE가 만든다.
ROADS = [
    # H1 도시고속도로
    ("내부순환로", "H1", [(37.5525, 126.8930), (37.5660, 126.9020), (37.5745, 126.9180), (37.5880, 126.9310), (37.6010, 126.9555),
                         (37.6080, 126.9930), (37.6050, 127.0200), (37.6020, 127.0380), (37.5960, 127.0420), (37.5690, 127.0440),
                         (37.5560, 127.0430), (37.5450, 127.0480)]),
    ("북부간선도로", "H1", [(37.6000, 127.0420), (37.6100, 127.0650), (37.6130, 127.0800), (37.6110, 127.1000), (37.6050, 127.1250)]),
    ("경부고속도로", "H1", [(37.5230, 127.0180), (37.5130, 127.0150), (37.5040, 127.0190), (37.4870, 127.0300), (37.4700, 127.0390),
                          (37.4500, 127.0530), (37.4300, 127.0650)]),
    ("경인고속도로", "H1", [(37.5250, 126.8320), (37.5230, 126.8000), (37.5200, 126.7700)]),
    # H2 주간선
    ("남부순환로", "H2", [(37.5620, 126.8040), (37.5480, 126.8280), (37.5340, 126.8420), (37.5230, 126.8530), (37.5080, 126.8620),
                        (37.4950, 126.8700), (37.4800, 126.8850), (37.4850, 126.9030), (37.4870, 126.9130),
                        (37.4842, 126.9297), (37.4825, 126.9416), (37.4812, 126.9527), (37.4769, 126.9636), (37.4765, 126.9816),
                        (37.4790, 127.0000), (37.4790, 127.0130), (37.4840, 127.0340), (37.4880, 127.0550), (37.4950, 127.0640),
                        (37.4970, 127.0710), (37.4880, 127.1000), (37.4930, 127.1180)]),
    ("시흥대로", "H2", [(37.4930, 126.8960), (37.4850, 126.9000), (37.4700, 126.8990), (37.4520, 126.9000), (37.4340, 126.9030)]),
    ("경인로", "H2", [(37.5170, 126.9080), (37.5080, 126.8900), (37.5030, 126.8790), (37.4940, 126.8580), (37.4940, 126.8440),
                     (37.4920, 126.8230), (37.4880, 126.8000)]),
    ("국회대로", "H2", [(37.5290, 126.9150), (37.5270, 126.8870), (37.5250, 126.8700), (37.5240, 126.8350)]),
    ("공항대로", "H2", [(37.5620, 126.8040), (37.5600, 126.8250), (37.5580, 126.8380), (37.5510, 126.8650), (37.5470, 126.8750),
                      (37.5440, 126.8870)]),
    ("여의대방로", "H2", [(37.5180, 126.9280), (37.5130, 126.9270), (37.4990, 126.9230), (37.4870, 126.9130)]),
    ("마포대로", "H2", [(37.5370, 126.9440), (37.5440, 126.9510), (37.5570, 126.9560), (37.5660, 126.9670)]),
    ("양화로·신촌로", "H2", [(37.5440, 126.9030), (37.5490, 126.9140), (37.5570, 126.9240), (37.5550, 126.9370), (37.5570, 126.9460),
                          (37.5570, 126.9560)]),
    ("한강대로·세종대로", "H2", [(37.5240, 126.9620), (37.5310, 126.9680), (37.5350, 126.9730), (37.5550, 126.9720), (37.5660, 126.9780),
                             (37.5760, 126.9770)]),
    ("왕산로·망우로", "H2", [(37.5710, 127.0090), (37.5750, 127.0250), (37.5800, 127.0470), (37.5890, 127.0570), (37.5960, 127.0860),
                          (37.5990, 127.0930), (37.6020, 127.1100)]),
    ("천호대로", "H2", [(37.5750, 127.0250), (37.5670, 127.0520), (37.5610, 127.0640), (37.5570, 127.0790), (37.5520, 127.0890),
                      (37.5450, 127.1040), (37.5390, 127.1240), (37.5380, 127.1400), (37.5500, 127.1600), (37.5550, 127.1800)]),
    ("동일로", "H2", [(37.5450, 127.0700), (37.5570, 127.0790), (37.6020, 127.0790), (37.6180, 127.0750), (37.6550, 127.0610),
                     (37.6900, 127.0550)]),
    ("동소문로·도봉로", "H2", [(37.5820, 127.0020), (37.5930, 127.0160), (37.6030, 127.0250), (37.6130, 127.0300), (37.6380, 127.0260),
                            (37.6490, 127.0350), (37.6680, 127.0440), (37.6890, 127.0460)]),
    ("통일로", "H2", [(37.5660, 126.9660), (37.5740, 126.9580), (37.5830, 126.9500), (37.5890, 126.9440), (37.6010, 126.9350),
                     (37.6100, 126.9300), (37.6190, 126.9210), (37.6370, 126.9190), (37.6650, 126.9120)]),
    ("강남대로", "H2", [(37.5160, 127.0200), (37.5110, 127.0220), (37.5050, 127.0250), (37.4980, 127.0280), (37.4840, 127.0340),
                      (37.4700, 127.0380)]),
    ("테헤란로", "H2", [(37.4980, 127.0280), (37.5010, 127.0370), (37.5040, 127.0490), (37.5090, 127.0630), (37.5100, 127.0700)]),
    ("영동대로", "H2", [(37.5240, 127.0620), (37.5090, 127.0630), (37.4950, 127.0630), (37.4800, 127.0650)]),
    ("동작대로", "H2", [(37.5070, 126.9810), (37.4860, 126.9820), (37.4770, 126.9820), (37.4600, 126.9890), (37.4400, 126.9950)]),
    ("반포대로", "H2", [(37.5110, 126.9960), (37.5050, 127.0030), (37.4920, 127.0080), (37.4790, 127.0130)]),
    ("송파대로", "H2", [(37.5130, 127.1000), (37.5050, 127.1060), (37.4930, 127.1180), (37.4850, 127.1250), (37.4700, 127.1350)]),
    ("올림픽로", "H2", [(37.5110, 127.0860), (37.5130, 127.1000), (37.5170, 127.1130), (37.5300, 127.1230), (37.5390, 127.1240)]),
    # H3 보조간선(R01·R02 촘촘히, 1막 동선 SD-21 §7.2)
    ("관악로", "H3", [(37.4812, 126.9527), (37.4740, 126.9500), (37.4660, 126.9480)]),
    ("신림로", "H3", [(37.4842, 126.9297), (37.4760, 126.9320), (37.4680, 126.9340), (37.4600, 126.9330)]),
    ("상도로", "H3", [(37.5130, 126.9420), (37.5050, 126.9390), (37.5030, 126.9480), (37.4960, 126.9540), (37.4850, 126.9710)]),
    ("노량진로", "H3", [(37.5130, 126.9260), (37.5130, 126.9420), (37.5100, 126.9600), (37.5080, 126.9640), (37.5030, 126.9800)]),
    ("사당로", "H3", [(37.4770, 126.9820), (37.4850, 126.9710), (37.4900, 126.9620)]),
    ("영중로·당산로", "H3", [(37.5156, 126.9073), (37.5220, 126.9050), (37.5250, 126.8960), (37.5345, 126.9026)]),
    ("도림로", "H3", [(37.5160, 126.9060), (37.5080, 126.8960), (37.4930, 126.8950)]),
    ("디지털로", "H3", [(37.4850, 126.9010), (37.4800, 126.8900), (37.4810, 126.8820), (37.4780, 126.8700)]),
    ("구로중앙로", "H3", [(37.5030, 126.8820), (37.4900, 126.8870), (37.4810, 126.8830)]),
    ("여의대로", "H3", [(37.5300, 126.9270), (37.5180, 126.9280)]),
    ("의사당대로", "H3", [(37.5280, 126.9160), (37.5240, 126.9350)]),
    ("봉천로", "H4", [(37.4825, 126.9416), (37.4890, 126.9450), (37.4963, 126.9536)]),
    ("보라매로", "H4", [(37.4990, 126.9230), (37.4930, 126.9330), (37.4842, 126.9297)]),
    ("가마산로", "H4", [(37.4930, 126.8950), (37.4890, 126.9050), (37.4870, 126.9130)]),
]

# 하천변 고속도로: 강 선에서 바깥으로(옆 = +1 남·동, −1 북·서). 여유 = 둔치·제방 바깥 칸 수
RIVERSIDE = [("올림픽대로", "한강", +1, 12), ("강변북로", "한강", -1, 12), ("동부간선도로", "중랑천", +1, 5),
             ("서부간선도로", "안양천", +1, 5), ("동부간선도로(탄천)", "탄천", -1, 5)]

# 고가(층 1) 구간(SD-21 §6.3): 노선 이름 → 전 구간(None) 또는 [(위도, 경도, 반경 타일)]. 엔진(1-Rd) 전까지는 땅 위 도로로 굽고 표시만 한다
ELEVATED = {"내부순환로": None, "북부간선도로": None,
            "올림픽대로": [(37.5260, 126.9340, 30), (37.5100, 127.0000, 26), (37.5180, 127.0950, 26)],   # 여의도·노량진(E-01) · 반포 · 잠실
            "강변북로": [(37.5400, 126.9400, 26), (37.5420, 127.0500, 26)],                           # 마포 · 성수
            "서부간선도로": [(37.5000, 126.8800, 40)],                                                 # 안양천 구간(E-02)
            "남부순환로": [(37.4842, 126.9297, 30), (37.4765, 126.9816, 26)],                          # 신림 사거리(E-04) · 사당 — 램프 둘 + 상판이 들어갈 길이(1-Rd)
            "경부고속도로": [(37.5040, 127.0190, 14)]}                                                 # 반포 IC

# 계획 격자 시가지(F3): (위도, 경도) 상자 + 격자 방위각(도) · 간격(타일)
PLANNED = [((37.5320, 126.9150), (37.5170, 126.9420), -32, 34),   # 여의도(섬 축을 따라)
           ((37.5160, 127.0200), (37.4930, 127.0700), 16, 40),    # 강남(테헤란로 축)
           ((37.5350, 126.8600), (37.5180, 126.8850), 0, 38),     # 목동
           ((37.5200, 127.0750), (37.5000, 127.1100), 8, 42)]     # 잠실
# 아파트 단지(F5) 상자
APTS = [((37.5150, 126.9950), (37.5000, 127.0150)),   # 반포
        ((37.5320, 127.0200), (37.5220, 127.0400)),   # 압구정
        ((37.6650, 127.0550), (37.6350, 127.0850)),   # 상계·중계
        ((37.5650, 127.1450), (37.5450, 127.1700)),   # 고덕
        ((37.4850, 127.0500), (37.4720, 127.0750)),   # 개포
        ((37.5700, 126.8400), (37.5550, 126.8650)),   # 가양
        ((37.4950, 126.8650), (37.4850, 126.8800))]   # 구로 노동자 아파트 일대
# 공업 대블록(F4) 상자
INDUSTRIAL = [((37.4900, 126.8750), (37.4720, 126.9000)),   # 구로·가산 공단
              ((37.5200, 126.8880), (37.5120, 126.9020)),   # 문래 철공
              ((37.5500, 127.0480), (37.5390, 127.0650)),   # 성수
              ((37.4700, 126.8850), (37.4560, 126.9000))]   # 독산 육가공

FABRICS = ["F1", "F2", "F3", "F4", "F5", "F6", "F7"]
COLLECTOR = (52, 0.9, 4.0, 0.62)                                  # 집산로(H4 생성분): 큰길 사이 큰 블록을 나누는 성긴 보로노이 — 결은 이 경계에서 바뀐다
# 권역별 아파트 단지·공단 비율(world_bake.MIX의 apt·factory 몫, %) — 상자로 지정하지 않은 큰 블록에 섞는다
REGION_MIX = {"R01": (14, 0), "R02": (12, 30), "R03": (20, 20), "R04": (0, 0), "R05": (0, 0), "R06": (0, 0), "R07": (55, 0),
              "R08": (20, 25), "R09": (48, 0), "R10": (25, 0), "R11": (0, 0), "HR": (0, 0)}
# 결별 동네 길: (점 간격, 흔들림 0~1, 길 폭, 남길 비율) · 골목층(H6): (간격, 흔들림, 폭, 남길 비율) 또는 None
STREETS = {"F1": ((30, 0.85, 3.0, 0.70), (13, 0.9, 1.2, 0.36)),
           "F2": ((30, 0.9, 2.4, 0.35), (14, 0.9, 1.2, 0.34)),
           "F3": (None, (12, 0.6, 1.4, 0.35)),
           "F4": ((34, 0.35, 4.0, 0.85), None),
           "F5": ((70, 0.5, 3.6, 1.0), None),
           "F6": ((12, 0.9, 2.0, 0.72), (7, 0.9, 1.2, 0.50)),
           "F7": ((64, 1.0, 2.0, 0.55), None)}


def box_tiles(a, b):
    (x0, y0), (x1, y1) = to_tile(*a), to_tile(*b)
    return int(min(x0, x1)), int(min(y0, y1)), int(max(x0, x1)), int(max(y0, y1))


def _smooth_line(pts, step=3.0, chaikin_n=3):
    p = np.array(pts, float)
    for _ in range(chaikin_n):
        q = [p[0]]
        for a, b in zip(p[:-1], p[1:]):
            q += [0.75 * a + 0.25 * b, 0.25 * a + 0.75 * b]
        q.append(p[-1])
        p = np.array(q)
    out = [p[0]]
    for a, b in zip(p[:-1], p[1:]):
        n = max(1, int(np.hypot(*(b - a)) / step))
        for k in range(1, n + 1):
            out.append(a + (b - a) * k / n)
    return np.array(out)


def offset_line(P, half, side, gap, smooth_win=15):
    """강 중심선 P(서→동 또는 북→남)를 수면 반폭 half(배열·수) + gap만큼 옆으로 민 선. side +1 = 진행 방향 오른쪽(서→동이면 남)"""
    d = np.gradient(P, axis=0)
    d /= np.maximum(1e-6, np.hypot(d[:, 0], d[:, 1]))[:, None]
    n = np.stack([-d[:, 1], d[:, 0]], 1) * side
    Q = P + n * (np.asarray(half, float).reshape(-1, 1) + gap)
    k = np.ones(smooth_win) / smooth_win                                    # 굽이에서 꼬이지 않게 고르게
    Qs = np.stack([np.convolve(np.pad(Q[:, i], smooth_win // 2, mode="edge"), k, mode="valid") for i in (0, 1)], 1)
    return Qs[:len(Q)]


def arterials(river_lines):
    """간선 목록: [{"name", "cls", "pts"(타일 점열 N×2), "elev"(점마다 고가 여부)}]. river_lines = {이름: (중심선, 반폭)}"""
    out = []
    for name, cls, wps in ROADS:
        pts = _smooth_line([to_tile(*w) for w in wps])
        out.append({"name": name, "cls": cls, "pts": pts})
    for name, river, side, gap in RIVERSIDE:
        hit = next((v for k, v in river_lines.items() if k.startswith(river)), None)
        if hit is None:
            continue
        P, half = hit
        Q = offset_line(P, half, side, gap)
        out.append({"name": name, "cls": "H1", "pts": _smooth_line(Q[::3], step=3.0, chaikin_n=1)})
    for a in out:
        el = np.zeros(len(a["pts"]), bool)
        spec = ELEVATED.get(a["name"], [])
        if spec is None:
            el[:] = True
        else:
            for lat, lon, rad in spec:
                cx, cy = to_tile(lat, lon)
                el |= np.hypot(a["pts"][:, 0] - cx, a["pts"][:, 1] - cy) <= rad
        a["elev"] = el
    return out


def voronoi(shape, S, jit, seed, box=None):
    """흔들린 격자 점(칸마다 1개)의 보로노이: 반환 (가까운 두 점 사이 이등분선까지 거리, 가장 가까운 점 번호, 둘째 점 번호, 점 거리, 점 x, 점 y).
    box = (x0, y0, x1, y1)이면 그 안만 계산(밖은 큰 값)"""
    H, W = shape
    x0, y0, x1, y1 = box if box else (0, 0, W, H)
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(W, x1), min(H, y1)
    rng = np.random.default_rng(seed)
    gh, gw = H // S + 5, W // S + 5
    jx = (rng.random((gh, gw)) - 0.5) * jit
    jy = (rng.random((gh, gw)) - 0.5) * jit
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    xs += 0.5
    ys += 0.5
    by = (ys // S).astype(np.int32) + 2
    bx = (xs // S).astype(np.int32) + 2
    d1 = np.full(xs.shape, 1e9, np.float32)
    d2 = np.full(xs.shape, 1e9, np.float32)
    i1 = np.zeros(xs.shape, np.int32)
    i2 = np.zeros(xs.shape, np.int32)
    p1x = np.zeros(xs.shape, np.float32)
    p1y = np.zeros(xs.shape, np.float32)
    p2x = np.zeros(xs.shape, np.float32)
    p2y = np.zeros(xs.shape, np.float32)
    for oy in (-2, -1, 0, 1, 2):
        for ox in (-2, -1, 0, 1, 2):
            cy_, cx_ = np.clip(by + oy, 0, gh - 1), np.clip(bx + ox, 0, gw - 1)
            sx = (cx_ - 2 + 0.5 + jx[cy_, cx_]) * S
            sy = (cy_ - 2 + 0.5 + jy[cy_, cx_]) * S
            d = (xs - sx) ** 2 + (ys - sy) ** 2
            idx = cy_ * gw + cx_
            closer = d < d1
            mid = (~closer) & (d < d2) & (idx != i1)
            # 둘째 자리 갱신(새 점이 첫째가 되면 옛 첫째가 둘째로)
            d2 = np.where(closer, d1, np.where(mid, d, d2))
            i2 = np.where(closer, i1, np.where(mid, idx, i2))
            p2x = np.where(closer, p1x, np.where(mid, sx, p2x))
            p2y = np.where(closer, p1y, np.where(mid, sy, p2y))
            d1 = np.where(closer, d, d1)
            i1 = np.where(closer, idx, i1)
            p1x = np.where(closer, sx, p1x)
            p1y = np.where(closer, sy, p1y)
    sep = np.maximum(1e-3, np.hypot(p2x - p1x, p2y - p1y))
    bis = (d2 - d1) / (2 * sep)
    full_b = np.full(shape, 1e9, np.float32)
    full_i1 = np.zeros(shape, np.int32)
    full_i2 = np.zeros(shape, np.int32)
    full_d = np.full(shape, 1e9, np.float32)
    full_px = np.zeros(shape, np.float32)
    full_py = np.zeros(shape, np.float32)
    full_px[y0:y1, x0:x1] = p1x
    full_py[y0:y1, x0:x1] = p1y
    full_b[y0:y1, x0:x1] = bis
    full_i1[y0:y1, x0:x1] = i1
    full_i2[y0:y1, x0:x1] = i2
    full_d[y0:y1, x0:x1] = np.sqrt(d1)
    return full_b, full_i1, full_i2, full_d, full_px, full_py


def keep_edges(i1, i2, keep, seed):
    """보로노이 변(두 점 번호 쌍)마다 남길지(씨앗 해시): 지워진 변은 블록을 합치고, 남은 변 끝은 막다른 길이 된다"""
    a = np.minimum(i1, i2).astype(np.uint64)
    b = np.maximum(i1, i2).astype(np.uint64)
    h = (a * np.uint64(2654435761) + b * np.uint64(40503) + np.uint64(seed * 97)) % np.uint64(1000)
    return h < np.uint64(int(keep * 1000))


# ---------------------------------------------------------------- 시가지 결(SD-21 §5)
def _box_mask(shape, boxes):
    m = np.zeros(shape, bool)
    for a, b in boxes:
        x0, y0, x1, y1 = box_tiles(a, b)
        m[max(0, y0):max(0, y1), max(0, x0):max(0, x1)] = True
    return m


def _label(free):
    """작은 격자 연결 요소(4방향) 번호 — 순수 파이썬 BFS(거친 격자라 빠르다)"""
    from collections import deque
    h, w = free.shape
    lab = np.zeros((h, w), np.int32)
    n = 0
    fr = free.tolist()
    lb = lab.tolist()
    for y in range(h):
        for x in range(w):
            if not fr[y][x] or lb[y][x]:
                continue
            n += 1
            lb[y][x] = n
            q = deque([(y, x)])
            while q:
                cy, cx = q.popleft()
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < h and 0 <= nx < w and fr[ny][nx] and not lb[ny][nx]:
                        lb[ny][nx] = n
                        q.append((ny, nx))
    return np.array(lb, np.int32), n


def fabric_map(r, src, soft_h):
    """칸마다 결 번호(FABRICS 순서). 큰길(간선)로 나뉜 큰 블록마다 F3·F4·F5·F7을 투표로 정해 결이 큰길에서 바뀌게 하고,
    언덕(F2)·시장(F6)은 칸 단위로 덮는다"""
    kind, use, region = r["kind"], r["use"], r["region"]
    H, W = kind.shape
    hint = np.zeros((H, W), np.uint8)                                      # 0 = F1
    hint[_box_mask((H, W), INDUSTRIAL)] = 3
    hint[_box_mask((H, W), APTS)] = 4
    for a, b, ang, S in PLANNED:
        hint[_box_mask((H, W), [(a, b)])] = 2
    rc = {c: i for i, c in enumerate(["", "R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11", "HR"])}
    wild = (use == 4) | r["band"] | ((region == rc["R11"]) & (soft_h < 60)) | (kind == 12)
    hint[wild & (hint == 0)] = 6
    # 큰 블록: 4칸 거친 격자에서 간선·물·성곽·철로가 아닌 땅의 연결 요소
    C = 4
    hh, ww = H // C, W // C
    blocked = (kind >= 2) & (kind <= 4) | (kind == 7) | (kind == 8) | (kind == 9) | (kind == 10) | (kind == 11)
    S, jit, cw, ckeep = COLLECTOR
    cb, ci1, ci2, _, _, _ = voronoi((H, W), S, jit, 9091)
    coll = (cb < cw / 2) & keep_edges(ci1, ci2, ckeep, 9091)              # 일부 변을 지워 블록 크기가 들쭉날쭉(벌집 무늬 방지)
    r["collector"] = coll
    free_c = (~(blocked | coll)[:hh * C, :ww * C]).reshape(hh, C, ww, C).mean(axis=(1, 3)) > 0.6
    lab, n = _label(free_c)
    hc = hint[C // 2::C, C // 2::C][:hh, :ww]
    votes = np.bincount((lab * 8 + hc).ravel(), minlength=(n + 1) * 8).reshape(n + 1, 8)
    tot = votes.sum(1, keepdims=True).clip(1)
    best = votes.argmax(1)
    frac = votes.max(1) / tot[:, 0]
    pick = np.where((frac > 0.4) & (best > 0), best, 0).astype(np.uint8)
    # 지정 없는 큰 블록: 권역 비율로 아파트 단지(F5)·공단(F4)을 섞는다(블록 번호 해시 — 굽기마다 같다)
    rcodes = ["", "R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11", "HR"]
    regc = region[C // 2::C, C // 2::C][:hh, :ww]
    rv = np.bincount((lab * 16 + regc).ravel(), minlength=(n + 1) * 16).reshape(n + 1, 16).argmax(1)
    # 아파트 지구·공단 지구는 뭉친다: 블록 중심의 아주 낮은 주파수 잡음 값으로 고른다(이웃 블록이 같은 결이 되기 쉽다)
    rng = np.random.default_rng(7310)
    gn = rng.random((hh // 30 + 3, ww // 30 + 3))
    yy_c, xx_c = np.mgrid[0:hh, 0:ww].astype(np.float32) / 30.0
    iy, ix = yy_c.astype(int), xx_c.astype(int)
    ty, tx = yy_c - iy, xx_c - ix
    ty, tx = ty * ty * (3 - 2 * ty), tx * tx * (3 - 2 * tx)
    noise = (gn[iy, ix] * (1 - tx) + gn[iy, ix + 1] * tx) * (1 - ty) + (gn[iy + 1, ix] * (1 - tx) + gn[iy + 1, ix + 1] * tx) * ty
    nsum = np.bincount(lab.ravel(), weights=noise.ravel(), minlength=n + 1)
    ncnt = np.bincount(lab.ravel(), minlength=n + 1).clip(1)
    nv = nsum / ncnt
    order = np.argsort(np.argsort(nv[1:])) / max(1, n - 1)                 # 잡음 값을 0~1 순위로(분포 고르게)
    for i in range(1, n + 1):
        if pick[i] or votes[i].sum() < 20:
            continue
        apt, fac = REGION_MIX.get(rcodes[rv[i]] if rv[i] < len(rcodes) else "", (0, 0))
        q = order[i - 1] * 100.0
        if q < apt:
            pick[i] = 4
        elif q > 100.0 - fac:
            pick[i] = 3
    pick[0] = 0
    fc = pick[lab]
    fab = np.repeat(np.repeat(fc, C, 0), C, 1)
    fab = np.pad(fab, ((0, H - fab.shape[0]), (0, W - fab.shape[1])), mode="edge")
    # 언덕(F2): 구릉(50~150m) 칸은 F1 자리를 덮는다
    hill = (soft_h >= 48) & (use != 2)
    fab[hill & (fab == 0)] = 1
    # 시장(F6): 교역소·시장 장소 반경 22칸
    ys, xs = np.mgrid[0:H, 0:W]
    for p in src["places"]:
        if p.get("type") in ("교역소",) or "시장" in p.get("name", ""):
            x, y = int(p["tx"]), int(p["ty"])
            x0, x1, y0, y1 = max(0, x - 22), min(W, x + 23), max(0, y - 22), min(H, y + 23)
            m = (xs[y0:y1, x0:x1] - x) ** 2 + (ys[y0:y1, x0:x1] - y) ** 2 <= 22 * 22
            sub = fab[y0:y1, x0:x1]
            sub[m & (sub != 6)] = 5
    return fab


def local_streets(r, fab, land, soft_h, seed=4120):
    """결별 동네 길(H5) · 골목(H6) · 흙길(F7). 반환 (street, alley, track)"""
    H, W = fab.shape
    street = np.zeros((H, W), bool)
    alley = np.zeros((H, W), bool)
    track = np.zeros((H, W), bool)
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    for k, name in enumerate(FABRICS):
        m = (fab == k) & land
        if not m.any():
            continue
        yy, xx = np.nonzero(m)
        box = (int(xx.min()) - 8, int(yy.min()) - 8, int(xx.max()) + 9, int(yy.max()) + 9)
        main, sub = STREETS[name]
        if main:
            S, jit, w, keep = main
            b, i1, i2, dd, px, py = voronoi((H, W), S, jit, seed + 11 * k, box)
            line = (b < w / 2) & keep_edges(i1, i2, keep, seed + k) & m
            if name == "F7":
                track |= line
            else:
                street |= line
            if name == "F5":                                               # 단지 순환로 + 정문 둘(SD-21 §5 F5)
                ring = (b >= 10.0) & (b < 12.5) & (dd > 12.0) & m
                ang = np.arctan2(ys - py, xs - px)
                g0 = (i1.astype(np.int64) * 2654435761 % 6283) / 1000.0
                da = np.abs(((ang - g0) + np.pi) % (2 * np.pi) - np.pi)
                db = np.abs(((ang - g0 - np.pi) + np.pi) % (2 * np.pi) - np.pi)
                gate = (np.minimum(da, db) * np.maximum(dd, 1.0) < 1.8) & (b < 11.0) & m
                street |= ring | gate
            del b, i1, i2, dd, px, py
        if sub:
            S, jit, w, keep = sub
            b, i1, i2, dd, px, py = voronoi((H, W), S, jit, seed + 13 * k + 5, box)
            alley |= (b < w / 2) & keep_edges(i1, i2, keep, seed + 7 * k + 3) & m
            del b, i1, i2, dd, px, py
    # 계획 격자(F3): 그 시가지 축 방위각의 격자
    for a, b_, ang, S in PLANNED:
        x0, y0, x1, y1 = box_tiles(a, b_)
        sl = (slice(max(0, y0), y1), slice(max(0, x0), x1))
        th = np.deg2rad(ang)
        u = (xs[sl] * np.cos(th) + ys[sl] * np.sin(th)) / S
        v = (-xs[sl] * np.sin(th) + ys[sl] * np.cos(th)) / S
        g = (np.abs(u - np.round(u)) * S < 1.6) | (np.abs(v - np.round(v)) * S < 1.6)
        street[sl] |= g & (fab[sl] == 2) & land[sl]
    # 언덕(F2): 높이 결을 따라 감기는 길(등고선 간격 13칸쯤) — 경사를 곧장 오르는 차도는 없다
    gy, gx = np.gradient(soft_h.astype(np.float32))
    g = np.hypot(gx, gy)
    k = 9
    a = np.pad(g, k, mode="edge")
    c = a.cumsum(0).cumsum(1)
    c = np.pad(c, ((1, 0), (1, 0)))
    n = 2 * k + 1
    gs = (c[n:n + H, n:n + W] - c[0:H, n:n + W] - c[n:n + H, 0:W] + c[0:H, 0:W]) / (n * n) + 0.25
    hn = soft_h / gs
    q = hn / 15.0
    contour = (np.abs(q - np.round(q)) * 15.0 < 1.2) & (fab == 1) & land
    street |= contour
    if "collector" in r:                                                   # 집산로: 큰 블록 경계(언덕 F2·계획 F3·황무지 F7 제외)
        street |= r["collector"] & land & ~np.isin(fab, [1, 2, 4, 6])
        track |= r["collector"] & land & (fab == 6)
    alley &= ~street
    track &= ~street
    return street, alley, track
