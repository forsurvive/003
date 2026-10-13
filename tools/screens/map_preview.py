"""실내 맵 미리보기 (단계 0-5): game/data/maps/<ID>.json → art/out/maps/<ID>.png (1배) — 게임과 같은 그림 재료로 그린다.
바닥 = 바닥 합성(ground.py, 셰이더와 같은 정수 식), 벽 = ts_s07_wall 타일, 소품 = s07_props 아틀라스(같은 오프셋), 문패 = 남색 판,
인물 = 외형 코드 chibi(대기, 방향). --grid: 칸 격자·출구(빨강)·표지(초록)·일과 지점(노랑)을 덧그린다.
실행: python3 tools/screens/map_preview.py [ID ...] [--grid] [--sheet]  (--sheet: 12장 축소 모음 art/samples/t_maps_s07.png)"""
import os, sys, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import ground as G
import tiles_isaac as TI
import props_s07 as R
import chibi as K

MAPS = os.path.join(ROOT, "game", "data", "maps")
OUT = os.path.join(ROOT, "art", "out", "maps")
T = 32
F7 = ImageFont.truetype(os.path.join(ROOT, "art", "fonts", "Galmuri7.ttf"), 8)


def load_json(p):
    return json.load(open(p, encoding="utf-8"))


_WALL = None
_ATLAS = None
_PM = None
_NPC = None


def assets():
    global _WALL, _ATLAS, _PM, _NPC
    if _WALL is None:
        names = {v["atlas"][0]: k for k, v in load_json(os.path.join(ROOT, "game", "assets", "tiles", "ts_s07_wall.json")).items()}
        tiles = TI.s07_wall_tiles()
        _WALL = {i: tiles[n] for i, n in names.items()}
        _ATLAS = Image.open(os.path.join(ROOT, "game", "assets", "props", "s07_props.png")).convert("RGBA")
        _PM = load_json(os.path.join(ROOT, "game", "assets", "props", "s07_props.json"))["props"]
        _NPC = load_json(os.path.join(ROOT, "game", "data", "npcs.json"))["npcs"]
    return _WALL, _ATLAS, _PM, _NPC


def crop(rect):
    x, y, w, h = rect
    return _ATLAS.crop((x, y, x + w, y + h))


def sign(text_):
    im = R.sign_plate(text_)
    return TI.outline(_pad(im))


def _pad(im):
    p = Image.new("RGBA", (im.width + 2, im.height + 2), (0, 0, 0, 0))
    p.alpha_composite(im, (1, 1))
    return p


def render(mid, grid=False):
    wall, atlas, pm, npcs = assets()
    m = load_json(os.path.join(MAPS, mid + ".json"))
    W, H = m["size"]
    gs = G.load("s07")
    ids = np.array(m["floor"])
    flags = np.array([[1 if m["wall"][y][x] >= 0 else 0 for x in range(W)] for y in range(H)])
    img = Image.new("RGBA", (W * T, H * T), (11, 10, 13, 255))
    img.alpha_composite(gs.render(np.pad(ids, 1, mode="edge"), None, -1, -1, 0, 0, W * T, H * T, flags=np.pad(flags, 1, mode="edge")))
    for y in range(H):
        for x in range(W):
            i = m["wall"][y][x]
            if i >= 0:
                img.alpha_composite(wall[i], (x * T, y * T))
    items = []                                                      # (정렬 y, 그림, 위치)
    for p in m["props"]:
        e = pm[p["name"]]
        rect = e["frames"][0] if "frames" in e else e["rect"]
        items.append((p["sort_y"], crop(rect), tuple(p["px"])))
    for d in m["doors"]:
        e = pm[d["kind"]]
        items.append(((d["y"] + 2) * T, crop(e["rect"]), (d["x"] * T + e["off"][0], d["y"] * T + e["off"][1])))
    for s in m["signs"]:
        im = sign(s["text"])
        items.append(((s["y"] + 2) * T, im, (s["x"] * T + 16 - im.width // 2, s["y"] * T + 2)))
    for n in m["npcs"]:
        look = npcs.get(n["id"], {}).get("look", "")
        if not look or look.split("-")[0] in ("AN", "RB", "BY", "OBJ"):
            continue
        v = {"S": "S", "N": "N", "E": "E", "W": "E", "SE": "SE", "SW": "SE", "NE": "NE", "NW": "NE"}[n["dir"]]
        im = K.actor(K.Look.parse(look), v, "idle")
        if n["dir"] in ("W", "SW", "NW"):
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        fx, fy = n["x"] * T + 16, n["y"] * T + 26
        items.append((fy, im, (fx - im.width // 2, fy - im.height + 2)))
    items.sort(key=lambda t: t[0])
    for _, im, (x, y) in items:
        img.alpha_composite(im, (x, y))
    if grid:
        d = ImageDraw.Draw(img)
        for x in range(W + 1):
            d.line([x * T, 0, x * T, H * T], fill=(255, 255, 255, 40))
        for y in range(H + 1):
            d.line([0, y * T, W * T, y * T], fill=(255, 255, 255, 40))
        for e in m["exits"]:
            d.rectangle([e["x"] * T + 2, e["y"] * T + 2, e["x"] * T + 29, e["y"] * T + 29], outline=(255, 60, 60, 255), width=2)
            d.text((e["x"] * T + 3, e["y"] * T + 3), e["to"], font=F7, fill=(255, 200, 200, 255))
        for k, (x, y, _) in m["marks"].items():
            d.rectangle([x * T + 10, y * T + 10, x * T + 21, y * T + 21], outline=(80, 255, 120, 255))
        for n in m["npcs"]:
            for r in n["route"]:
                d.ellipse([r[1] * T + 12, r[2] * T + 12, r[1] * T + 19, r[2] * T + 19], outline=(255, 220, 60, 255))
    return img


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    grid = "--grid" in sys.argv
    index = load_json(os.path.join(MAPS, "_index.json"))["maps"]
    ids = args or sorted(index)
    os.makedirs(OUT, exist_ok=True)
    shots = {}
    for mid in ids:
        im = render(mid, grid)
        im.convert("RGB").save(os.path.join(OUT, f"{mid}{'_grid' if grid else ''}.png"))
        shots[mid] = im
        print("그림:", mid, im.size)
    if "--sheet" in sys.argv:
        cell_w, cell_h = 560, 400
        cols = 3
        rows = (len(shots) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell_w, rows * (cell_h + 14)), (11, 10, 13))
        d = ImageDraw.Draw(sheet)
        for i, (mid, im) in enumerate(sorted(shots.items())):
            k = min(cell_w / im.width, cell_h / im.height)
            sm = im.resize((int(im.width * k), int(im.height * k)), Image.BOX).convert("RGB")
            x0, y0 = (i % cols) * cell_w, (i // cols) * (cell_h + 14)
            sheet.paste(sm, (x0 + (cell_w - sm.width) // 2, y0 + 14))
            d.text((x0 + 4, y0 + 2), f"{mid} {index[mid]['name']}", font=F7, fill=(233, 228, 216))
        sheet.save(os.path.join(ROOT, "art", "samples", "t_maps_s07.png"))
        print("모음: art/samples/t_maps_s07.png")


if __name__ == "__main__":
    main()
