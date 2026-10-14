"""월드 굽기 견본(SD-16 §6.7 '각 단계 결과를 청크 단위 PNG 미리보기로 남겨 검수'): 월드 래스터의 한 구역을
바닥 합성(art/tools/ground.py, 게임과 같은 정수 식)으로 그린다. 건물은 발자국 자리에 어두운 상자(타일 그림은 다음 단계).
python3 tools/screens/world_sample.py X Y [가로 세로] [출력.png]   (X Y = 월드 타일, 기본 40×23 = 화면 2장)"""
import os, sys, json
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
sys.path.insert(0, os.path.join(ROOT, "tools", "pipeline"))
import ground as G
import world_bake as WB


def main():
    x0, y0 = int(sys.argv[1]), int(sys.argv[2])
    w = int(sys.argv[3]) if len(sys.argv) > 3 else 40
    h = int(sys.argv[4]) if len(sys.argv) > 4 else 23
    out = sys.argv[5] if len(sys.argv) > 5 else os.path.join(ROOT, "game", "reports", "world_sample.png")
    src = json.load(open(WB.SRC, encoding="utf-8"))
    r = WB.bake(src)
    WB.city(r, src)
    f, names = WB.floor_names(r)
    tid = G.tile_ids("r01_ext")
    lut = np.array([tid[n] for n in names], np.int64)
    pad = 2
    sl = (slice(y0 - pad, y0 + h + pad), slice(x0 - pad, x0 + w + pad))
    ids = lut[f[sl]]
    flags = np.where(r["bid"][sl] > 0, 1, 0)
    gs = G.load("r01")
    img = gs.render(ids, None, x0 - pad, y0 - pad, x0 * 32, y0 * 32, w * 32, h * 32, flags=flags)
    a = np.array(img.convert("RGBA"))
    bid = r["bid"][y0:y0 + h, x0:x0 + w] > 0
    m = np.repeat(np.repeat(bid, 32, 0), 32, 1)
    a[m, :3] //= 3
    im = Image.fromarray(a, "RGBA")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out)
    print("견본:", out, im.size)


if __name__ == "__main__":
    main()
