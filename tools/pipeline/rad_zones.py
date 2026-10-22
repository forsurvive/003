"""월드 방사능 구역(단계 1-9d, SD-08 §8.5 · SD-11 §11.2 · SD-09b 'Rad-n → Z' 대응) → game/data/world/rad.json.

원자료 source.json의 radiation(SD-08 6.5 표)에서 지상 구역을 동심 고리로 바꾼다. 칸 좌표(타일), 청크 40칸.
- 등급 대응(SD-09b): Rad-1 = Z1 · Rad-2 = Z2 · Rad-3 = Z3 · Rad-4 = Z4(중심 8칸만 Z5 — 김포 크레이터, SD-09b R10).
- 고리 끝 12칸은 한 등급 낮춘다(구역 반경 안쪽에서 옅어진다 — 선을 밟는 순간 확 바뀌지 않게).
- 지하 구역(당인리 · 서울역 대심도)은 실내 맵 `rad` 줄로, 도심 지상 Rad-1(R05)은 2막 배치 때 웅덩이·건물 단위로(구현 정합 SD-11 §11.2).
- 경계 띠(서쪽 지평선 안개 Z4)는 놀이 구역 밖이라 상자 하나로만 둔다.
막 1 장소(R01 · R02)가 고리에 드는지 찍어 메인 필수 동선에 Z3 이상이 없음을 검사한다(SD-11 §11.2 'Z5는 메인 필수 구간 금지').
"""
import json
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "game", "data", "world", "source.json")
OUT = os.path.join(ROOT, "game", "data", "world", "rad.json")
CS = 40
FADE = 12
# 이름 → (중심 반경 칸, 중심 등급) — 표에 중심 크기가 없는 곳은 여기서 정한다
CORE = {"김포 크레이터": [(8, 5), (20, 4)], "우면 크레이터": [(12, 4)], "이촌 폭심": [(20, 3)]}
# 막 1 메인 장소: 여기에 Z3 이상이 걸리면 실패
MAIN_LIDS = ("L-R01-01", "L-R01-09", "L-R01-18", "L-R01-19", "L-R01-23", "L-R02-19")


# 이야기 결과로 생기는 지대(조건부 — 굽기는 웅덩이를 깔지 않고, 게임이 조건을 보고 켠다)
COND_ZONES = [{"name": "신길 빌라 노심 잔해", "c": [763, 1194], "rings": [[10, 1]], "cond": "UQ71_CORE == 5"},   # UQ-71 ③(SD-05 §3.17): Rad-1 영구
              {"name": "보라매 시험기 노심(샘)", "c": [785, 1290], "rings": [[3, 1]], "cond": "UQ67_CORE == 0 and UQ67_LEAK == 0"},   # UQ-67(SD-05 §3.32): 엔진 안에서 새는 동안 Rad-1 작은 고리
              {"name": "보라매 시험기 노심(들창 반쯤)", "c": [785, 1290], "rings": [[6, 1]], "cond": "UQ67_CORE == 0 and UQ67_LEAK == 1"}]   # 꺼내다 실패 — 고리가 넓어진다


def zones(src):
    out = []
    for e in src["radiation"]:
        if e.get("underground") or e.get("center") is None:
            continue
        cx, cy = e["center"][0] * CS + CS // 2, e["center"][1] * CS + CS // 2
        if "box" in e:
            x0, x1, y0, y1 = e["box"]
            out.append({"name": e["name"], "box": [x0 * CS, y0 * CS, (x1 + 1) * CS, (y1 + 1) * CS], "z": 1})
            continue
        if "radius" not in e:
            continue
        R = e["radius"] * CS
        g = int(e["rad"])
        rings = list(CORE.get(e["name"], []))
        rings.append((R - FADE, g))
        rings.append((R, max(1, g - 1)))
        out.append({"name": e["name"], "c": [cx, cy], "rings": [[r, z] for r, z in rings]})
    out.append({"name": "서쪽 지평선 안개", "box": [0, 0, 2 * CS, 43 * CS], "z": 4})
    return out


def grade(zs, x, y):
    best = 0
    for z in zs:
        if "box" in z:
            b = z["box"]
            if b[0] <= x < b[2] and b[1] <= y < b[3]:
                best = max(best, z["z"])
            continue
        d = math.hypot(x - z["c"][0], y - z["c"][1])
        for r, g in z["rings"]:
            if d <= r:
                best = max(best, g)
                break
    return best


def main():
    src = json.load(open(SRC, encoding="utf-8"))
    zs = zones(src)
    hit, bad = [], []
    for p in src["places"]:
        if not p["lid"].startswith(("L-R01", "L-R02")):
            continue
        g = grade(zs, p["tx"], p["ty"])
        if g:
            hit.append("%s %s Z%d" % (p["lid"], p["name"], g))
        if g >= 3 and p["lid"] in MAIN_LIDS:
            bad.append(p["lid"])
    json.dump({"zones": zs + COND_ZONES, "dose": {"1": 1, "2": 3, "3": 8, "4": 25, "5": 80}}, open(OUT, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("방사능 구역 %d곳 → rad.json · 막 1 장소 중 구역 안 %d곳%s" % (len(zs), len(hit), (": " + " · ".join(hit)) if hit else ""))
    if bad:
        raise SystemExit("메인 필수 장소가 Z3 이상: " + ", ".join(bad))


if __name__ == "__main__":
    main()
