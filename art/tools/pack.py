"""시트 패킹 v0 (SD-16 §13.3·§13.4·§5.4): 인물 레이어 → 시트 PNG + 같은 이름 JSON.
행 = 방향 S·SE·E·NE·N(반전 W·SW·NW는 파일로 만들지 않고 JSON mirror로 적는다), 열 = 모션을 순서대로 이어 붙임.
프레임 64×64, 발 기준점 (32, 60). 모션은 거리 구동(§3.6.5)이라 틱 대신 px_per_frame을 적는다.
프레임 메타: head (x, y, 상태) = 머리 윗줄 중심·위+16, hitbox = 불투명 상자. 손 앵커·무기 각도는 단계 T에서 포즈 표로 채운다.
이번 판은 합성본(몸 + 몸통 + 머리)을 낸다. 레이어별 분리 시트는 페이퍼돌 실행 중 합성 결정(G-T) 뒤에 낸다.
python3 tools/pack.py  ->  out/sheets/*.png + *.json"""
import os, sys, json
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))

ROOT = os.path.dirname(os.path.dirname(__file__))
OUT = os.path.join(ROOT, "out", "sheets")
ROWS = ("S", "SE", "E", "NE", "N")
MIRROR = {"W": "E", "SW": "SE", "NW": "NE"}


def meta(f):
    px = f.load()
    m = [(x, y) for y in range(64) for x in range(64) if px[x, y][3]]
    if not m:
        return {}
    top = min(y for _, y in m)
    xs = [x for x, y in m if y <= top + 6]
    x0, x1 = min(x for x, _ in m), max(x for x, _ in m)
    return {"head": [round(sum(xs) / len(xs)), top + 16, 0], "hitbox": [x0, top, x1 - x0 + 1, 60 - top + 1]}


def pack(name, sets, motions, steps):
    cols = []
    for mo in motions:
        n = len(sets[mo]["S"]) if isinstance(sets[mo]["S"], list) else 1
        cols.append((mo, n))
    W = sum(n for _, n in cols) * 64
    sheet = Image.new("RGBA", (W, 64 * len(ROWS)), (0, 0, 0, 0))
    j = {"name": name, "frame": [64, 64], "foot": [32, 60], "rows": list(ROWS), "mirror": MIRROR, "motions": {},
         "frames": {}}
    c = 0
    for mo, n in cols:
        j["motions"][mo] = {"start": c, "count": n}
        if mo in steps:
            j["motions"][mo].update({"px_per_frame": steps[mo][0], "diag_step": list(steps[mo][1]), "drive": "distance"})
        for r, v in enumerate(ROWS):
            seq = sets[mo][v] if isinstance(sets[mo][v], list) else [sets[mo][v]]
            for i, f in enumerate(seq):
                sheet.alpha_composite(f, ((c + i) * 64, r * 64))
                j["frames"][f"{v}:{mo}:{i}"] = meta(f)
        c += n
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, name + ".png"))
    with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as fh:
        json.dump(j, fh, ensure_ascii=False, sort_keys=True, indent=1)
    return name


def main():
    import rig_pc as R
    import npcs as NP
    made = []
    for code, pf in (("T01", None), ("T02", None), ("T03", None), ("T06", "PF-01")):
        sets, _ = R.build_all(code, pf)
        nm = f"pc_comp_{code.lower()}_{(pf or 'PF-00').replace('-', '').lower()}_loco"
        made.append(pack(nm, sets, ("idle", "walk", "run"), R.STEP))
    for grp, name, role, code in NP.NPCS:
        b = NP.build(code)
        nm = "np_" + code.lower().replace("-", "_") + "_loco"
        made.append(pack(nm, {"idle": b["idle"], "walk": b["walk"]}, ("idle", "walk"), {"walk": R.STEP["walk"]}))
    print("packed:", len(made), "sheets ->", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
