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
    for fn in os.listdir(SPR):                                      # 지난 그림체의 시트를 지운다(이름이 바뀐 것까지)
        if fn.split(".")[0].endswith("_loco") and not fn.endswith(".import"):
            os.remove(os.path.join(SPR, fn))
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
    """CR-002 큰바퀴(아이작풍, art/tools/chibi_creatures.py): 옆(E)만 — idle 1, walk 4(삼각 보행, 컷당 3px), death 5."""
    import chibi_creatures as CC
    frames, meta = CC.roach_sheet()
    fw, fh = meta["frame"]
    sheet = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * fw, 0))
    name = "cr_cr002_base_loco"
    sheet.save(os.path.join(SPR, name + ".png"))
    mo = meta["motions"]
    anims = [("idle_E", [(0, 0)], True), ("walk_E", [(mo["walk"]["start"] + i, 0) for i in range(mo["walk"]["count"])], True),
             ("death_E", [(mo["death"]["start"] + i, 0) for i in range(mo["death"]["count"])], False)]
    open(os.path.join(SPR, name + ".tres"), "w", encoding="utf-8").write(
        spriteframes_tres(f"res://assets/sprites/{name}.png", fw, fh, anims))
    meta["name"] = name
    json.dump(meta, open(os.path.join(SPR, name + ".json"), "w"), ensure_ascii=False, sort_keys=True, indent=1)


def quad_sheets():
    """네발짐승(0-10): CR-104 변이 들개 · 백구(C-015 진돗개). 옆 그림만, 걷기 4컷(컷당 4px)."""
    import chibi_creatures as CC
    for kind, name in (("dog", "cr_cr104_loco"), ("jindo", "cr_baekgu_loco")):
        frames, meta = CC.quad_sheet(kind)
        fw, fh = meta["frame"]
        sheet = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            sheet.alpha_composite(f, (i * fw, 0))
        sheet.save(os.path.join(SPR, name + ".png"))
        mo = meta["motions"]
        anims = [("idle_E", [(0, 0)], True), ("walk_E", [(mo["walk"]["start"] + i, 0) for i in range(mo["walk"]["count"])], True),
                 ("death_E", [(mo["death"]["start"] + i, 0) for i in range(mo["death"]["count"])], False)]
        open(os.path.join(SPR, name + ".tres"), "w", encoding="utf-8").write(
            spriteframes_tres(f"res://assets/sprites/{name}.png", fw, fh, anims))
        meta["name"] = name
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


for _m in range(16):                                               # 실내 벽 자동 타일(ts_s07_wall)
    TILE_PROPS[f"wt_{_m}"] = (True, 2)


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


def tileset_grid(name, tiles, extra=None, cols=32):
    """격자 아틀라스 타일셋(월드 구조물처럼 칸이 많을 때 — 한 줄 아틀라스는 모바일 텍스처 한도 4096px를 넘는다).
    막힘·엄폐는 청크 자료가 칸마다 들고 있어 타일셋에는 그림만 둔다."""
    import tiles_world
    img, pos = tiles_world.atlas(tiles, cols)
    os.makedirs(TIL, exist_ok=True)
    img.save(os.path.join(TIL, name + ".png"))
    lines = [f'[gd_resource type="TileSet" load_steps=3 format=3]\n',
             f'[ext_resource type="Texture2D" path="res://assets/tiles/{name}.png" id="1"]\n',
             '[sub_resource type="TileSetAtlasSource" id="src0"]', 'texture = ExtResource("1")',
             "texture_region_size = Vector2i(32, 32)"]
    for n in tiles:
        x, y = pos[n]
        lines.append(f"{x}:{y}/0 = 0")
    lines += ["", "[resource]", "tile_size = Vector2i(32, 32)", 'sources/0 = SubResource("src0")', ""]
    open(os.path.join(TIL, name + ".tres"), "w", encoding="utf-8").write("\n".join(lines))
    meta = {"cols": cols, "tiles": pos}
    meta.update(extra or {})
    json.dump(meta, open(os.path.join(TIL, name + ".json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    return len(tiles)


def main():
    n = import_sheets()
    roach_sheet()
    quad_sheets()
    import tiles_isaac                                             # 아이작풍 타일(이름·순서는 이전 판과 같다)
    r01 = tiles_isaac.r01_tiles()
    nt = tileset("ts_r01_ext", r01)                                # 소품 타일은 투명 바탕(바닥은 합성 층이 그린다)
    ns = tileset("ts_s07_int", tiles_isaac.s07_tiles())
    nw = tileset("ts_s07_wall", tiles_isaac.s07_wall_tiles())
    tileset("ts_bc_wall", tiles_isaac.bc_wall_tiles())                # 봉천 빌라 실내 벽(0-10)
    tileset("ts_sb_wall", tiles_isaac.sb_wall_tiles())                # 새벽인력 창고동 벽(1-3 H-03)
    import tiles_world                                             # 월드 건물·지형 구조(1-1)
    wt, wtab = tiles_world.build()
    nwd = tileset_grid("ts_world", wt, {"skins": wtab})
    import ground                                                  # 바닥 합성 재질·잔 소품·잡음(SD-16 §6.10)
    ground._CACHE.clear()                                          # 타일 그림을 자르며 옛 번호로 읽은 세트를 버린다
    gdir = os.path.join(ROOT, "game", "assets", "ground")
    for gs in ("r01", "s07"):
        ground.load(gs).export(gdir)
    print(f"sprites: {n} sheets + cr_cr002 | tiles: r01 {nt}, s07 {ns}, s07 벽 {nw}, 월드 {nwd} | ground: r01, s07")


if __name__ == "__main__":
    main()
