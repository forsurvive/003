"""Vault S-07 interior reference scene (SD-16 §12.3 #2): V-01 아트리움 west half + V-03 적성 평가 교실,
joined by a doorway in the dividing wall. 640x360, 32px grid, interior walls 2 tiles (atrium 3 tiles).
Even ceiling light: no directional cast shadows, only 2px contact shadows under floor props (SD-16 §2.6).
v2(아이작풍): 바닥·벽은 tiles_isaac, 소품은 굵은 먹선, 주인공은 chibi(16세 연습 시험 날, 성적표 앞).
Writes samples/11_scene_s07(.png, _x2) and samples/11_scene_s07_grid_x2.png (tile grid overlay)."""
import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
import tiles_s07 as S
import tiles_isaac as TI
import ground as G
import numpy as np
import chibi as K
from grid import parse, upscale, check

ROOT = os.path.dirname(os.path.dirname(__file__))
T = 32
W, H = 640, 360
COLS, ROWS = 20, 12
gs_ids = G.tile_ids("s07_int")
RGB2TOK = {P.rgb(f"P{i:02d}"): f"P{i:02d}" for i in range(64)}

# Map legend: A atrium panel, G grate, L guide line, N lino, W wall top, w/e etc via code, F face, B balcony
# Columns 0-12 atrium, 13 dividing wall, 14-19 classroom. Rows 0-2 north wall, 3-9 floor, 10-11 south wall top.


def floor_name(c, r):
    if c == 13:
        return "guide_h" if r == 7 else "panel"                      # 칸막이 벽 문간
    if c <= 12:
        if r == 3 or c == 0:
            return "grate_a"
        if c == 6 and r == 7:
            return "guide_t"
        if r == 7:
            return "guide_h"
        if c == 6 and r in (4, 5, 6):
            return "guide_v"
        return "panel"
    return "lino_a"


def is_wall(c, r):
    return r >= 10 or r <= 2 or (c == 13 and r not in (6, 7))


def floor_layer():
    """바닥 합성 층(SD-16 §6.10, 게임과 같은 식): 벽 칸은 덮개 1(섞지 않음·아래 그늘)."""
    gs = G.load("s07")
    ids = np.zeros((ROWS, COLS), int)
    flags = np.zeros((ROWS, COLS), int)
    for r in range(ROWS):
        for c in range(COLS):
            ids[r, c] = gs_ids[floor_name(c, r)]
            flags[r, c] = 1 if is_wall(c, r) else 0
    return gs.render(np.pad(ids, 1, mode="edge"), None, -1, -1, 0, 0, W, H, flags=np.pad(flags, 1, mode="edge"))


def contact_shadow(img, x0, x1, y, h=2):
    """Darken the floor by one palette step under a prop's foot line (even overhead light)."""
    px = img.load()
    for yy in range(y, min(H, y + h)):
        for xx in range(max(0, x0), min(W, x1)):
            tok = RGB2TOK.get(px[xx, yy][:3])
            if tok:
                px[xx, yy] = S.C(S.shadow_px(tok))


def build():
    img = Image.new("RGBA", (W, H), S.C("P10"))
    img.alpha_composite(floor_layer())                               # 바닥은 합성 층, 벽은 타일
    for r in range(ROWS):
        for c in range(COLS):
            x, y = c * T, r * T
            if not is_wall(c, r):
                continue
            if r >= 10:                                              # south wall top
                img.alpha_composite(TI.wall_top({"n"} if r == 10 and c != 13 else set()), (x, y))
            elif c == 13:                                            # dividing wall with a doorway at rows 6-7
                if r <= 3:
                    img.alpha_composite(TI.wall_top({"w", "e"} if r >= 3 else {"w"} if r >= 1 else set()), (x, y))
                elif r in (4, 5):
                    img.alpha_composite(TI.wall_face_in("top" if r == 4 else "bot"), (x, y))
                else:
                    img.alpha_composite(TI.wall_top({"w", "e", "n"} if r == 8 else {"w", "e"}), (x, y))
            elif c <= 12 and r <= 2:                                 # atrium north wall: balcony + 2 face tiles
                if r == 0:
                    img.alpha_composite(TI.balcony_band(c, door=c in (4, 10), num={4: "2-04", 10: "2-07"}.get(c)), (x, y))
                elif r == 1:
                    img.alpha_composite(TI.wall_face_in("top", "pipe" if c in (12,) else "plain", c), (x, y))
                else:
                    img.alpha_composite(TI.wall_face_in("bot", "outlet" if c == 12 else "plain", c), (x, y))
            elif c >= 14 and r <= 2:                                 # classroom north wall
                if r == 0:
                    img.alpha_composite(TI.wall_top({"s", "w"} if c == 14 else {"s"}), (x, y))
                elif r == 1:
                    img.alpha_composite(TI.wall_face_in("top", "vent" if c == 19 else "plain", c), (x, y))
                else:
                    img.alpha_composite(TI.wall_face_in("bot", "plain", c), (x, y))
    # doorway: yellow jamb marks on the floor and the wall stub's face edges
    d = ImageDraw.Draw(img)
    for yy in (6 * T, 8 * T - 1):
        d.line([13 * T, yy, 14 * T - 1, yy], fill=S.C("P48"))
    # 벽 발치 그늘은 바닥 합성 층이 그린다(디더 감쇠)
    # --- wall-mounted props
    img.alpha_composite(TI.outline(S.ration_window()), (0, 1 * T))
    img.alpha_composite(TI.outline(S.emblem()), (2 * T, 1 * T + 6))
    img.alpha_composite(TI.outline(S.rank_board()), (3 * T, 1 * T + 4))
    img.alpha_composite(TI.outline(S.slogan_crt("성적이 곧 미래다", 3)), (9 * T, 1 * T + 6))
    img.alpha_composite(TI.outline(S.blackboard()), (15 * T, 1 * T + 6))
    img.alpha_composite(TI.outline(S.wall_clock(10, 12)), (14 * T + 8, 1 * T + 8))
    # --- floor props (drawn north to south)
    props = []
    # atrium: 돌잔치 long table with stools, planters, the rank board onlookers' spot
    props.append((S.canteen_table(4), 2 * T, 5 * T - 6))
    for k in range(5):
        props.append((S.stool(), 2 * T + 6 + k * 24, 5 * T - 14))
        props.append((S.stool(), 2 * T + 6 + k * 24, 6 * T + 4))
    props.append((S.planter(), 1 * T, 8 * T + 2))
    props.append((S.planter(), 9 * T, 8 * T + 2))
    props.append((S.canteen_table(2), 8 * T, 5 * T - 6))
    props.append((S.water_cooler(), 12 * T, 3 * T - 26))
    # classroom: teacher desk, 3x2 exam desks
    props.append((S.teacher_desk(), 15 * T + 16, 3 * T + 2))
    for rr in (5, 7):
        for cc in (14, 16, 18):
            props.append((S.exam_desk(), cc * T + (8 if cc == 14 else 0), rr * T - 4))
    props = [(TI.outline(im), x, y) for im, x, y in props]                 # 아이작풍 굵은 먹선
    props.sort(key=lambda p: p[2] + p[0].height)
    for im, x, y in props:
        contact_shadow(img, x + 2, x + im.width - 2, y + im.height, 2)
        img.alpha_composite(im, (x, y))
    # --- the protagonist (age 16, MQ-P3 rehearsal) reading the ranking board
    pc = K.actor(K.Look(), "N", "idle")
    fx, fy = 6 * T + 16, 4 * T + 22
    contact_shadow(img, fx - 7, fx + 8, fy - 1, 2)
    img.alpha_composite(pc, (fx - 20, fy - 44))
    return img


if __name__ == "__main__":
    im = build()
    bad = check(im, P.allowed_set("UI", "S3", "H1"))
    out = os.path.join(ROOT, "samples")
    im.convert("RGB").save(os.path.join(out, "11_scene_s07.png"))
    upscale(im, 2).convert("RGB").save(os.path.join(out, "11_scene_s07_x2.png"))
    g = upscale(im, 2)
    d = ImageDraw.Draw(g)
    for c in range(COLS + 1):
        d.line([c * 64, 0, c * 64, H * 2], fill=(255, 0, 255, 255))
    for r in range(ROWS + 1):
        d.line([0, r * 64, W * 2, r * 64], fill=(255, 0, 255, 255))
    g.convert("RGB").save(os.path.join(out, "11_scene_s07_grid_x2.png"))
    print("off-palette:", bad if bad else 0)
