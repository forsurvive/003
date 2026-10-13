"""바닥 합성 대조(SD-16 §6.10): Godot GroundLayer(셰이더)와 art/tools/ground.py(파이썬 정수 판)가 같은 구역을 픽셀 단위로 같게 그리는지.
r01·r01b: 시험 구역 두 곳(20×11타일) 바닥만. s07: 실내 방 전체(벽 타일 포함, 같은 아틀라스로 파이썬에서 덮는다).
출력: 다른 픽셀 수(0이어야 통과), game/reports/ground_check_<구역>.png(위 Godot · 아래 파이썬).
실행: python3 tools/screens/ground_check.py  (Xvfb + godot 필요)"""
import os, sys, json, subprocess, tempfile
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import ground as G

GAME = os.path.join(ROOT, "game")
SW, SH = 20, 11
R01 = {"r01": (160, 165), "r01b": (196, 205)}                  # 정문 마당·옹벽·비탈길 / 흙·풀 두 가지·아스팔트·소품 그림자


def shoot(region, tmp):
    out = os.path.join(tmp, f"g_{region}.png")
    extra = [f"--origin={R01[region][0]},{R01[region][1]}"] if region in R01 else []
    subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", "godot", "--path", GAME, "res://scenes/bench/ground_check.tscn",
                    "--write-movie", out, "--fixed-fps", "1", "--quit-after", "2", "--", f"--region={region[:3]}"] + extra,
                   check=True, capture_output=True, timeout=300)
    return Image.open(os.path.join(tmp, f"g_{region}00000001.png")).convert("RGB")


def ref_r01(region="r01"):
    OX, OY = R01[region]
    D = os.path.join(GAME, "data", "chunks")
    cs = json.load(open(os.path.join(D, "_index.json")))["chunk_size"]
    ids = np.zeros((SH + 2, SW + 2), int)
    deco = np.zeros((SH + 2, SW + 2), int)
    cache = {}
    for ty in range(OY - 1, OY + SH + 1):
        for tx in range(OX - 1, OX + SW + 1):
            cid = f"C-{tx // cs:02d}-{ty // cs:02d}"
            if cid not in cache:
                cache[cid] = json.load(open(os.path.join(D, cid + ".json")))
            c = cache[cid]
            i = (ty % cs) * cs + tx % cs
            ids[ty - OY + 1, tx - OX + 1] = c["ground"][i]
            deco[ty - OY + 1, tx - OX + 1] = c["deco"][i]
    return G.load("r01").render(ids, deco, OX - 1, OY - 1, OX * 32, OY * 32, SW * 32, SH * 32).convert("RGB")


def ref_s07():
    """interior_room.gd와 같은 배치."""
    W, H = 20, 12
    names = G.tile_ids("s07_int")
    meta = json.load(open(os.path.join(GAME, "assets", "tiles", "ts_s07_int.json")))
    ids = np.zeros((H, W), int)
    deco = np.full((H, W), -1)
    grid = []
    for y in range(H):
        row = []
        for x in range(W):
            n = "panel"
            if y == 0:
                n = "wall_top_s"
            elif y == 1:
                n = "face_top_pipe" if x % 5 == 2 else "face_top"
            elif y == 2:
                n = "face_bot"
            elif x == 0 or x == W - 1 or (y == H - 1 and x != 10):
                n = "wall_top"
            elif y == 3:
                n = "grate_a" if x % 2 else "grate_b"
            elif y == 7:
                n = "guide_x" if x == 10 else "guide_h"
            elif x == 10:
                n = "guide_v"
            elif (x * 7 + y) % 6 == 0:
                n = "panel_scuff"
            row.append(n)
            if meta[n]["solid"]:
                ids[y, x], deco[y, x] = names["panel"], names[n]
            else:
                ids[y, x] = names[n]
        grid.append(row)
    pad_ids = np.pad(ids, 1, mode="edge")
    pad_deco = np.pad(deco, 1, mode="edge")
    img = G.load("s07").render(pad_ids, pad_deco, -1, -1, 0, 0, W * 32, H * 32)
    ts = Image.open(os.path.join(GAME, "assets", "tiles", "ts_s07_int.png")).convert("RGBA")
    for y in range(H):
        for x in range(W):
            n = grid[y][x]
            if meta[n]["solid"]:
                a = names[n]
                img.alpha_composite(ts.crop((a * 32, 0, a * 32 + 32, 32)), (x * 32, y * 32))
    return img.convert("RGB")


def main():
    ok = True
    os.makedirs(os.path.join(GAME, "reports"), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for region, ref in (("r01", ref_r01), ("r01b", lambda: ref_r01("r01b")), ("s07", ref_s07)):
            g = shoot(region, tmp)
            r = ref()
            w, h = min(g.width, r.width), min(g.height, r.height)          # 화면(640×360) 안의 공통 부분
            r = r.crop((0, 0, w, h))
            gw = g.crop((0, 0, w, h))
            a, b = np.asarray(gw, np.int16), np.asarray(r, np.int16)
            bad = int((np.abs(a - b).sum(axis=2) > 0).sum())
            print(f"{region}: 다른 픽셀 {bad} / {r.width * r.height}")
            ok &= bad == 0
            sheet = Image.new("RGB", (r.width, r.height * 2 + 4), (255, 0, 255))
            sheet.paste(gw, (0, 0)); sheet.paste(r, (0, r.height + 4))
            sheet.save(os.path.join(GAME, "reports", f"ground_check_{region}.png"))
    print("바닥 합성 대조:", "통과" if ok else "실패")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
