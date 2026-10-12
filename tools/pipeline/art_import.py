"""그래픽 → Godot 리소스 변환 v0 (SD-16 §13.3 '엔진 내보내기', SD-19 §6.6·§6.7).
  - art/out/sheets/*.png + .json  →  game/assets/sprites/<name>.png + .tres(SpriteFrames) + .json(프레임 메타)
    애니메이션 이름 = '<모션>_<방향>' (S·SE·E·NE·N). W·SW·NW는 실행 중 좌우 반전(JSON mirror).
  - 큰바퀴(CR-002): 측면 원화 1장에서 다리만 움직이는 종종걸음 4프레임 + 점액 사망 프레임을 만들어 같은 형식으로.
  - 타일: R01 외부·S-07 실내 생성기 출력 → 아틀라스 PNG + TileSet(.tres, 사용자 데이터 'solid'·'cover') + 이름표 JSON.
    충돌은 물리 엔진이 아니라 자체 충돌 격자를 쓰므로(SD-19 §6.8) 타일은 데이터만 갖는다.
python3 tools/pipeline/art_import.py   (art/build.sh 뒤에 돌린다)"""
import os, sys, json, shutil
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, "art")
sys.path.insert(0, os.path.join(ART, "tools"))
GAME = os.path.join(ROOT, "game")
SPR = os.path.join(GAME, "assets", "sprites")
TIL = os.path.join(GAME, "assets", "tiles")
ROWS = ("S", "SE", "E", "NE", "N")


def spriteframes_tres(png_res, fw, fh, anims):
    """anims: list of (name, [(col, row)], loop). Writes Godot 4 text resource."""
    subs, anim_txt, n = [], [], 0
    for name, cells, loop in anims:
        frames = []
        for c, r in cells:
            sid = f"a{n}"
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\n'
                        f"region = Rect2({c * fw}, {r * fh}, {fw}, {fh})\n")
            frames.append(f'{{"duration": 1.0, "texture": SubResource("{sid}")}}')
            n += 1
        anim_txt.append(f'{{"frames": [{", ".join(frames)}], "loop": {"true" if loop else "false"}, '
                        f'"name": &"{name}", "speed": 8.0}}')
    head = f'[gd_resource type="SpriteFrames" load_steps={n + 2} format=3]\n\n' \
           f'[ext_resource type="Texture2D" path="{png_res}" id="1"]\n\n'
    return head + "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(anim_txt) + "]\n"


def import_sheets():
    src = os.path.join(ART, "out", "sheets")
    os.makedirs(SPR, exist_ok=True)
    n = 0
    for fn in sorted(os.listdir(src)):
        if not fn.endswith(".json"):
            continue
        name = fn[:-5]
        meta = json.load(open(os.path.join(src, fn), encoding="utf-8"))
        shutil.copyfile(os.path.join(src, name + ".png"), os.path.join(SPR, name + ".png"))
        anims = []
        for mo, m in sorted(meta["motions"].items(), key=lambda kv: kv[1]["start"]):
            for r, v in enumerate(ROWS):
                anims.append((f"{mo}_{v}", [(m["start"] + i, r) for i in range(m["count"])], mo != "death"))
        fw, fh = meta["frame"]
        open(os.path.join(SPR, name + ".tres"), "w", encoding="utf-8").write(
            spriteframes_tres(f"res://assets/sprites/{name}.png", fw, fh, anims))
        json.dump(meta, open(os.path.join(SPR, name + ".json"), "w", encoding="utf-8"), ensure_ascii=False,
                  sort_keys=True, indent=1)
        n += 1
    return n


def roach_sheet():
    """CR-002 큰바퀴 32×32, 측면(E)만: idle 1, walk 4(다리 번갈아), death 5(점액). 발 기준점 (16, 28)."""
    import effects as FX
    from grid import parse
    base = parse(os.path.join(ART, "src/sprites/cr_roach.txt"))["E_idle0"]
    px = base.load()
    ys = [y for y in range(32) for x in range(32) if px[x, y][3]]
    legs_y0 = max(ys) - 2                              # legs live in the lowest three rows
    leg = [(x, y) for y in range(legs_y0, max(ys) + 1) for x in range(32) if px[x, y][3]]
    walk = []
    for k in range(4):
        f = base.copy()
        fp = f.load()
        if k % 2 == 1:
            for x, y in leg:
                fp[x, y] = (0, 0, 0, 0)
            for x, y in leg:
                side = 1 if (x // 3 + (k // 2)) % 2 == 0 else -1   # alternate tripods
                nx = x + side
                if 0 <= nx < 32:
                    fp[nx, y] = px[x, y]
        walk.append(f)
    death = FX.slime_death()
    death = [d if d.size == (32, 32) else _pad32(d) for d in death]
    frames = [base] + walk + death
    sheet = Image.new("RGBA", (32 * len(frames), 32), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * 32, 0))
    name = "cr_cr002_base_loco"
    sheet.save(os.path.join(SPR, name + ".png"))
    anims = [("idle_E", [(0, 0)], True), ("walk_E", [(1 + i, 0) for i in range(4)], True),
             ("death_E", [(5 + i, 0) for i in range(len(death))], False)]
    open(os.path.join(SPR, name + ".tres"), "w", encoding="utf-8").write(
        spriteframes_tres(f"res://assets/sprites/{name}.png", 32, 32, anims))
    meta = {"name": name, "frame": [32, 32], "foot": [16, max(ys)], "rows": ["E"], "mirror": {"W": "E"},
            "motions": {"idle": {"start": 0, "count": 1}, "walk": {"start": 1, "count": 4, "px_per_frame": 3, "drive": "distance"},
                        "death": {"start": 5, "count": len(death)}}}
    json.dump(meta, open(os.path.join(SPR, name + ".json"), "w"), ensure_ascii=False, sort_keys=True, indent=1)


def _pad32(im):
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out.alpha_composite(im, ((32 - im.width) // 2, 32 - im.height))
    return out


# tile name -> (solid, cover)  cover: 0 없음 / 1 낮은 엄폐 / 2 높은 엄폐 (SD-11 §4.2)
TILE_PROPS = {
    "brick": (True, 2), "brick_window": (True, 2), "wall_face": (True, 2), "wall_face_cap": (True, 2),
    "granite_rock": (True, 1), "scrap_barrier": (True, 1), "drum": (True, 1),
    "wall_top": (True, 2), "wall_top_s": (True, 2), "wall_top_w": (True, 2), "wall_top_ws": (True, 2),
    "face_top": (True, 2), "face_top_pipe": (True, 2), "face_top_vent": (True, 2), "face_bot": (True, 2),
    "face_bot_outlet": (True, 2), "balcony": (True, 2), "balcony_door": (True, 2),
}


def tileset(name, tiles, floor_bg=None):
    os.makedirs(TIL, exist_ok=True)
    names = list(tiles)
    atlas = Image.new("RGBA", (32 * len(names), 32), (0, 0, 0, 0))
    for i, n in enumerate(names):
        im = tiles[n]
        if im.size != (32, 32):
            im = im.crop((0, 0, 32, 32))
        if floor_bg is not None and im.getpixel((0, 0))[3] == 0:     # props drawn over a floor tile
            b = floor_bg.copy(); b.alpha_composite(im); im = b
        atlas.alpha_composite(im, (32 * i, 0))
    atlas.save(os.path.join(TIL, name + ".png"))
    lines = [f'[gd_resource type="TileSet" load_steps=3 format=3]\n',
             f'[ext_resource type="Texture2D" path="res://assets/tiles/{name}.png" id="1"]\n',
             '[sub_resource type="TileSetAtlasSource" id="src0"]', 'texture = ExtResource("1")',
             "texture_region_size = Vector2i(32, 32)"]
    for i, n in enumerate(names):
        solid, cover = TILE_PROPS.get(n, (False, 0))
        lines += [f"{i}:0/0 = 0", f"{i}:0/0/custom_data_0 = {'true' if solid else 'false'}", f"{i}:0/0/custom_data_1 = {cover}"]
    lines += ["", "[resource]", "tile_size = Vector2i(32, 32)",
              'custom_data_layer_0/name = "solid"', "custom_data_layer_0/type = 1",
              'custom_data_layer_1/name = "cover"', "custom_data_layer_1/type = 2",
              'sources/0 = SubResource("src0")', ""]
    open(os.path.join(TIL, name + ".tres"), "w", encoding="utf-8").write("\n".join(lines))
    json.dump({n: {"atlas": [i, 0], "solid": TILE_PROPS.get(n, (False, 0))[0], "cover": TILE_PROPS.get(n, (False, 0))[1]}
               for i, n in enumerate(names)}, open(os.path.join(TIL, name + ".json"), "w"), indent=1, sort_keys=True)
    return len(names)


def main():
    n = import_sheets()
    roach_sheet()
    import tiles_r01, tiles_s07
    r01 = tiles_r01.all_tiles()
    nt = tileset("ts_r01_ext", r01, floor_bg=r01["dirt_a"])
    ns = tileset("ts_s07_int", tiles_s07.all_tiles())
    print(f"sprites: {n} sheets + cr_cr002 | tiles: r01 {nt}, s07 {ns}")


if __name__ == "__main__":
    main()
