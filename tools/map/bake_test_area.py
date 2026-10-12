"""단계 T 시험 구역 굽기 v0 (SD-19 §5.2 '관악산 비탈 3×3청크 + 실내 1곳', §6.5).
SD-08 벡터 굽기(bake_terrain)는 단계 0 도구다. 이번 판은 같은 청크 형식을 규칙 기반 생성으로 채운다(시드 고정 = 같은 출력).
9×9청크(360×360타일): 활성 3×3 · 사전 로드 5×5 · 7×7 밖 해제가 실제로 일어나게 넓게 굽는다.
배치: 흙·풀 바탕, 북서→남동 비탈길(아스팔트), 화강암 바위 무리(낮은 엄폐), 고철 장벽 줄, 드럼통, 가운데 청크에
S-07 정문 콘크리트 옹벽 + 문(실내 전환), 남쪽 청크에 벽돌 빌라 2동. 큰바퀴·계엄군 스폰 지점.
출력: game/data/chunks/C-xx-yy.json, game/data/chunks/_index.json, art 미리보기 PNG."""
import os, sys, json, random, math

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "data", "chunks")
TILES = json.load(open(os.path.join(ROOT, "game", "assets", "tiles", "ts_r01_ext.json")))
CS, N = 40, 9                                   # chunk size (tiles), chunks per side (7×7 밖 해제가 일어나게 9)
T = {k: v["atlas"][0] for k, v in TILES.items()}


def bake(seed=1023):
    rnd = random.Random(seed)
    W = CS * N
    ground = [[T["dirt_a"]] * W for _ in range(W)]
    deco = [[-1] * W for _ in range(W)]
    for y in range(W):
        for x in range(W):
            n = math.sin(x * 0.11 + seed) * math.cos(y * 0.09) + math.sin((x + y) * 0.05) * 0.6
            ground[y][x] = (T["dirt_grass_a"] if n > 0.55 else T["dirt_grass_b"] if n > 0.25 else
                            T["dirt_b"] if (x * 7 + y * 13) % 11 == 0 else T["dirt_a"])
    # slope road NW -> SE, 3 tiles wide, centre lane
    for x in range(W):
        cy = int(N * CS * 0.15 + x * 0.7)
        for k in (-1, 0, 1):
            if 0 <= cy + k < W:
                ground[cy + k][x] = T["asphalt_lane"] if k == 0 and x % 4 < 2 else T["asphalt"]
    # paver plaza in front of the vault gate (centre chunk)
    gx, gy = (N // 2) * CS + 14, (N // 2) * CS + 10
    for y in range(gy + 2, gy + 9):
        for x in range(gx - 4, gx + 14):
            ground[y][x] = T["pavers"] if (x + y) % 5 else T["pavers_b"]
    # retaining wall with the gate (wall_face_cap row + wall_face row), door at the middle
    for x in range(gx - 4, gx + 14):
        deco[gy][x] = T["wall_face_cap"]
        deco[gy + 1][x] = T["wall_face"]
    door = (gx + 5, gy + 1)
    for dx in (-1, 0, 1):                                  # 정문 통로 3타일 폭
        deco[door[1]][door[0] + dx] = -1
        deco[gy][door[0] + dx] = -1
    # brick villas in the south chunks
    for vx, vy in ((gx - 30, gy + 30), (gx + 26, gy + 36)):
        for y in range(vy, vy + 5):
            for x in range(vx, vx + 7):
                deco[y][x] = T["brick_window"] if (y == vy + 2 and x % 3 == 1) else T["brick"]
    # granite rock clusters (low cover), scrap barrier lines, drums
    for _ in range(70):
        cx, cy = rnd.randrange(W), rnd.randrange(W)
        for _ in range(rnd.randint(1, 4)):
            x, y = cx + rnd.randint(-2, 2), cy + rnd.randint(-1, 1)
            if 0 <= x < W and 0 <= y < W and deco[y][x] == -1 and ground[y][x] not in (T["asphalt"], T["asphalt_lane"]):
                deco[y][x] = T["granite_rock"]
    for _ in range(14):
        x0, y0 = rnd.randrange(W - 8), rnd.randrange(W)
        for x in range(x0, x0 + rnd.randint(3, 7)):
            if deco[y0][x] == -1:
                deco[y0][x] = T["scrap_barrier"]
    for _ in range(30):
        x, y = rnd.randrange(W), rnd.randrange(W)
        if deco[y][x] == -1:
            deco[y][x] = T["drum"]
    # keep the plaza and the spawn point clear
    for y in range(gy + 2, gy + 9):
        for x in range(gx - 4, gx + 14):
            deco[y][x] = -1
    spawns = {"player": [gx + 5, gy + 5],
              "CR-002": [[gx + 20 + k, gy + 16 + (k % 3)] for k in range(5)],
              "CR-401": [[gx - 18, gy + 24]]}
    objects = [{"type": "door", "x": door[0], "y": door[1], "w": 3, "to": "int_s07_gate", "label": "S-07 정문"}]
    return ground, deco, spawns, objects


def main():
    ground, deco, spawns, objects = bake()
    os.makedirs(OUT, exist_ok=True)
    solid_ids = {v["atlas"][0] for v in TILES.values() if v["solid"]}
    for cy in range(N):
        for cx in range(N):
            cid = f"C-{cx:02d}-{cy:02d}"
            g = [ground[cy * CS + y][cx * CS:(cx + 1) * CS] for y in range(CS)]
            d = [deco[cy * CS + y][cx * CS:(cx + 1) * CS] for y in range(CS)]
            obj = [o for o in objects if o["x"] // CS == cx and o["y"] // CS == cy]
            data = {"id": cid, "origin": [cx * CS, cy * CS], "size": CS, "tileset": "ts_r01_ext",
                    "ground": sum(g, []), "deco": sum(d, []), "objects": obj}
            json.dump(data, open(os.path.join(OUT, cid + ".json"), "w"), separators=(",", ":"))
    json.dump({"chunk_size": CS, "chunks": [N, N], "tile": 32, "spawns": spawns, "solid_atlas": sorted(solid_ids)},
              open(os.path.join(OUT, "_index.json"), "w"), indent=1, sort_keys=True)
    # preview: 1px per tile
    from PIL import Image
    W = CS * N
    im = Image.new("RGB", (W, W))
    col = {T["asphalt"]: (60, 58, 64), T["asphalt_lane"]: (200, 190, 120), T["pavers"]: (140, 136, 128),
           T["pavers_b"]: (140, 136, 128)}
    for y in range(W):
        for x in range(W):
            c = col.get(ground[y][x], (110, 92, 60) if ground[y][x] in (T["dirt_a"], T["dirt_b"]) else (90, 110, 60))
            if deco[y][x] in solid_ids:
                c = (30, 30, 34)
            im.putpixel((x, y), c)
    im.resize((W * 3, W * 3), Image.NEAREST).save(os.path.join(ROOT, "art", "samples", "t_test_area_map.png"))
    print("baked", N * N, "chunks", CS, "tiles each; door at", objects[0]["x"], objects[0]["y"])


if __name__ == "__main__":
    main()
