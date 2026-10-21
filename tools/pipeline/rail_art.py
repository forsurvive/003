"""철길 덧그림(사용자 지적 2026-10-21 — 회색 자갈 띠만 있고 레일 · 침목이 없어 '끊긴 길'처럼 보였다).

지상 1호선(world_bake: 지상 철도 폴리선, 자갈 띠 kind 10) 위에 복선 레일 · 침목을 픽셀마다 계산해 그린다 —
폴리선까지의 부호 있는 거리(n)와 따라간 길이(s)로 침목 줄무늬 · 레일 선을 정하므로 어느 각도 · 굽이에서도 계단 없이 곧다.
큰길 · 보도 · 동네 길을 건너는 곳(바닥이 포장인 픽셀 — 도로 경계 v3 셰이더와 같은 식으로 판정)은 침목 없이 레일과 홈만(건널목).
결과는 청크(40칸 = 1280px)마다 RGBA 한 장 — 게임은 바닥 층 바로 위 스프라이트로 얹고(world_map._attach), 견본도 같은 그림을 얹는다.
쯔꾸르풍 팔레트: 섞은 색을 만들지 않고 정해 둔 색만 쓴다."""
import numpy as np

T = 32
TRACK_C = 42.0          ## 복선: 선로 중심이 폴리선에서 ±42px(1.3칸)
GAUGE_H = 15.0          ## 궤간 반(레일 중심까지, px)
TIE_H = 26.0            ## 침목 반길이(px)
TIE_P = 16.0            ## 침목 간격(px)
TIE_W = 6.0             ## 침목 폭(px)
RD_CURB, RD_GUT = 4, 3  ## ground.gdshader rd_curb · rd_gut(px)
K = 2048
# 팔레트(쯔꾸르풍 — 정해 둔 색만)
C_CON = ((172, 168, 160), (146, 142, 134), (106, 102, 96))       ## PC 침목: 위 테 · 몸 · 아래 테
C_WOOD = ((116, 92, 68), (92, 70, 52), (62, 47, 36))           ## 나무 침목(낡은 구간)
C_PLATE = (78, 74, 70)                                           ## 체결 판
C_RAIL = ((192, 188, 180), (134, 94, 68), (74, 54, 42))        ## 레일: 닳은 윗면 · 녹 · 그늘 쪽
C_GROOVE = (44, 44, 48)                                          ## 건널목 홈
C_SHADOW = (0, 0, 0, 70)


def _hash(a, b, seed):
    h = (a.astype(np.int64) * 73856093) ^ (b.astype(np.int64) * 19349663) ^ seed
    h = (h ^ (h >> 13)) * 1274126177
    return (h ^ (h >> 16)) & 0xFFFF


def fields(polys, x0, y0, w, h, reach=2.6):
    """픽셀 창(월드 px x0, y0, 크기 w × h)에서 가장 가까운 철도 폴리선까지 부호 있는 거리 n(px) · 따라간 길이 s(px). 밖은 inf"""
    n = np.full((h, w), np.inf, np.float32)
    s = np.zeros((h, w), np.float32)
    for poly in polys:
        P = np.asarray(poly, np.float64) * T                              # 칸 좌표(중심 x + .5) → px
        seg = np.hypot(*(P[1:] - P[:-1]).T)
        cum = np.concatenate([[0.0], np.cumsum(seg)])
        R = reach * T
        for i in range(len(P) - 1):
            a, b = P[i], P[i + 1]
            bx0, bx1 = int(max(x0, min(a[0], b[0]) - R)), int(min(x0 + w, max(a[0], b[0]) + R + 1))
            by0, by1 = int(max(y0, min(a[1], b[1]) - R)), int(min(y0 + h, max(a[1], b[1]) + R + 1))
            if bx1 <= bx0 or by1 <= by0:
                continue
            ys, xs = np.mgrid[by0:by1, bx0:bx1].astype(np.float64)
            xs += 0.5
            ys += 0.5
            ab = b - a
            L2 = max(1e-9, float(ab @ ab))
            t = np.clip(((xs - a[0]) * ab[0] + (ys - a[1]) * ab[1]) / L2, 0.0, 1.0)
            dx, dy = xs - (a[0] + t * ab[0]), ys - (a[1] + t * ab[1])
            d = np.hypot(dx, dy)
            sg = np.sign(ab[0] * dy - ab[1] * dx)
            sg[sg == 0] = 1.0
            sub = (slice(by0 - y0, by1 - y0), slice(bx0 - x0, bx1 - x0))
            better = d < np.abs(n[sub])
            n[sub] = np.where(better, d * sg, n[sub])
            s[sub] = np.where(better, cum[i] + t * seg[i], s[sub])
    return n, s


def paved(x0, y0, w, h, rcls, eb, ea, floor_paved):
    """픽셀이 포장(차도 · 연석 · 보도 · 동네 길 · 골목)인가 — ground.gdshader 도로 경계 v3와 같은 식"""
    ys, xs = np.mgrid[y0:y0 + h, x0:x0 + w]
    tx, ty = xs >> 5, ys >> 5
    fx, fy = xs & 31, ys & 31
    ex1, ey1 = 2 * fx + 1, 2 * fy + 1
    ex0, ey0 = 64 - ex1, 64 - ey1
    Hc, Wc = rcls.shape

    def at(arr, yy, xx):
        return arr[np.clip(yy, 0, Hc - 1), np.clip(xx, 0, Wc - 1)].astype(np.int64)

    def bil(arr):
        return (ex0 * ey0 * (at(arr, ty, tx) - 96) + ex1 * ey0 * (at(arr, ty, tx + 1) - 96)
                + ex0 * ey1 * (at(arr, ty + 1, tx) - 96) + ex1 * ey1 * (at(arr, ty + 1, tx + 1) - 96))
    rc = at(rcls, ty, tx) & 7
    LB, LA = bil(eb), bil(ea)
    art = (rc >= 1) & (rc <= 5) & ((LB < RD_CURB * K) | (LA < 0))
    loc = (rc == 6) & ((LB < RD_GUT * K) | (LA < 0))
    base = (rc == 0) & floor_paved[np.clip(ty, 0, Hc - 1), np.clip(tx, 0, Wc - 1)]
    return art | loc | base


def draw(polys, x0, y0, w, h, rcls, eb, ea, floor_paved, ok_cell):
    """창 하나의 덧그림 RGBA(h × w × 4). ok_cell: 칸 마스크(그려도 되는 땅 · 길 — 물 · 구조물 · 손 맵은 거짓)"""
    n, s = fields(polys, x0, y0, w, h)
    out = np.zeros((h, w, 4), np.uint8)
    if not np.isfinite(n).any():
        return out
    ys, xs = np.mgrid[y0:y0 + h, x0:x0 + w]
    Hc, Wc = ok_cell.shape
    ok = ok_cell[np.clip(ys >> 5, 0, Hc - 1), np.clip(xs >> 5, 0, Wc - 1)] & np.isfinite(n)
    pv = paved(x0, y0, w, h, rcls, eb, ea, floor_paved)
    for side in (-1.0, 1.0):
        u = np.where(np.isfinite(n), n - side * TRACK_C, 1e9)              # 선로 중심에서 가로 거리
        k = np.floor(s / TIE_P).astype(np.int64)                           # 침목 번호
        ph = s - k * TIE_P
        hk = _hash(k, np.full_like(k, int(side) + 5), 911)
        run = _hash(np.floor(s / (TIE_P * 23)).astype(np.int64), np.full_like(k, int(side) + 9), 77)   # 나무 침목 구간(23개 단위)
        wood = (run % 100) < 22
        gone = (hk % 100) < 5                                              # 빠진 침목
        shift = np.where((hk >> 7) % 100 < 14, ((hk >> 3) % 3) - 1, 0)    # 살짝 비뚤어진 침목
        tw = ph - shift
        tie = ok & ~pv & (np.abs(u) <= TIE_H - ((hk >> 5) % 3)) & (tw >= 0) & (tw < TIE_W) & ~gone
        edge_t = tie & (tw < 1)
        edge_b = tie & (tw >= TIE_W - 1)
        for m, idx in ((tie, 1), (edge_t, 0), (edge_b, 2)):
            out[m & ~wood, :3] = C_CON[idx]
            out[m & wood, :3] = C_WOOD[idx]
            out[m, 3] = 255
        for rs in (-1.0, 1.0):
            v = (u - rs * GAUGE_H) * rs                                     # 레일 중심에서 바깥쪽(+)
            plate = tie & (np.abs(v) < 3.5)
            out[plate, :3] = C_PLATE
            grove = ok & pv & (v >= -3.0) & (v < -1.5)                      # 건널목: 레일 안쪽 홈
            out[grove, :3] = C_GROOVE
            out[grove, 3] = 255
            sh = ok & (v >= 1.5) & (v < 2.5) & (out[..., 3] == 0)          # 바깥쪽 그늘 한 줄
            out[sh] = C_SHADOW
            for lo, hi, c in ((-1.5, -0.5, C_RAIL[0]), (-0.5, 0.5, C_RAIL[1]), (0.5, 1.5, C_RAIL[2])):
                m = ok & (v >= lo) & (v < hi)
                out[m, :3] = c
                out[m, 3] = 255
    return out


def rail_polys(src, WB):
    """world_bake와 같은 지상 철도 폴리선(칸 좌표)"""
    return [WB.line_of(r["path"], 90) for r in src["rails"] if "지상" in r["name"]]


def ok_cells(R, inmask):
    kind = R["kind"]
    ok = np.isin(kind, (1, 5, 6, 7, 8, 9, 10, 12)) & (R["level"] == 0) & (R["body"] == 0) & ~inmask
    return ok
