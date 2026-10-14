"""바깥 맵 구조물 층 굽기 (단계 0-10): game/data/maps/<ID>.json의 structs → game/assets/maps/<ID>_struct.png (맵 전체 크기, 투명 바탕).
그림은 art/tools/struct_r01.py(정면·옥상·옹벽·암벽·고철 장벽·틈·사다리·판자 다리). 실행 중에는 바닥 합성 층 위·인물 아래에 한 장으로 놓인다.
cond가 달린 구조물은 따로 굽는다(<ID>_struct_<n>.png, 실행 중 조건이 참일 때만)."""
import os, sys, json, glob
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import struct_r01 as S
import palette as P
from grid import check

MAPS = os.path.join(ROOT, "game", "data", "maps")
OUT = os.path.join(ROOT, "game", "assets", "maps")
T = 32


def bake(m):
    W, H = m["size"]
    base = Image.new("RGBA", (W * T, H * T), (0, 0, 0, 0))
    extra = []
    for i, s in enumerate(m.get("structs", [])):
        im = S.draw(s["kind"], s["w"], s["h"], s["seed"], **s.get("args", {}))
        if s.get("cond"):
            extra.append((i, s, im))
        else:
            base.alpha_composite(im, (s["x"] * T, s["y"] * T))
    return base, extra


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for f in sorted(glob.glob(os.path.join(MAPS, "*.json"))):
        if os.path.basename(f).startswith("_"):
            continue
        m = json.load(open(f, encoding="utf-8"))
        if not m.get("ext"):
            continue
        base, extra = bake(m)
        bad = check(base, P.allowed_set("UI"))
        if bad:
            print("팔레트 밖 색:", m["id"], bad[:5]); sys.exit(1)
        base.save(os.path.join(OUT, f"{m['id']}_struct.png"))
        for i, s, im in extra:
            im.save(os.path.join(OUT, f"{m['id']}_struct_{i}.png"))
        n += 1
    print(f"구조물 층: {n}장")


if __name__ == "__main__":
    main()
