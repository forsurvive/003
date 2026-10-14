"""실내 소품 묶음 내보내기 (단계 0-5): art/tools/props_s07.PROPS → game/assets/props/s07_props.png + s07_props.json.
그림마다 1px 여백을 두고 아이작풍 먹선(tiles_isaac.outline)을 두른 뒤 한 장에 줄지어 놓는다(최대 폭 1024).
메타(이름마다): rect [x, y, w, h](아틀라스 안), foot [가로, 세로](막히는 칸), kind(floor·wall·deco·door), off [x, y]
  — 놓는 칸의 왼쪽 위에서 그림 왼쪽 위까지 px. floor·deco: 발 칸 아래 변 + down에 그림 아래 변을 맞춘다.
  wall: 벽면 윗칸 왼쪽 위 + (dx, dy). door: 1칸 × 2칸 벽면(윗칸 기준), open = 열린 그림 rect.
  gear_door: 프레임 22장(frames), PROP_FRAMES(원형 철문 등)도 frames. states: 연출이 바꾸는 상태 그림(예: birth_bed occupied, terminal_cart lit)."""
import os, sys, json
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import props_s07 as R
import tiles_isaac as TI
import palette as P
from grid import check

OUT = os.path.join(ROOT, "game", "assets", "props")
T = 32


def outlined(im):
    pad = Image.new("RGBA", (im.width + 2, im.height + 2), (0, 0, 0, 0))
    pad.alpha_composite(im, (1, 1))
    return TI.outline(pad)


def main():
    os.makedirs(OUT, exist_ok=True)
    items = []                                                     # (key, image)
    for n, r in R.PROPS.items():
        if n == "gear_door":
            for f in range(R.GEAR_FRAMES):
                items.append((f"gear_door#{f}", outlined(R.S.gear_door(f, R.GEAR_FRAMES))))
            continue
        if n in R.PROP_FRAMES:                                      # 컷이 여럿인 소품(원형 철문 등, 연출 명령 anim)
            fn, cnt = R.PROP_FRAMES[n]
            for f in range(cnt):
                items.append((f"{n}#{f}", outlined(fn(f))))
            continue
        items.append((n, outlined(r["fn"]())))
        if n in R.DOOR_OPEN:
            items.append((n + "#open", outlined(R.DOOR_OPEN[n]())))
        for st, fn in R.PROP_STATES.get(n, {}).items():
            items.append((f"{n}#{st}", outlined(fn())))
    W = 1024
    x = y = rowh = 0
    pos = {}
    for k, im in items:
        if x + im.width > W:
            x, y, rowh = 0, y + rowh, 0
        pos[k] = (x, y, im.width, im.height)
        x += im.width
        rowh = max(rowh, im.height)
    atlas = Image.new("RGBA", (W, y + rowh), (0, 0, 0, 0))
    for k, im in items:
        atlas.alpha_composite(im, pos[k][:2])
    bad = check(atlas, P.allowed_set("UI", *P.SKIN, *P.HAIR))          # 탄생 침대의 윤정인·아기 피부·머리색
    if bad:
        print("팔레트 밖 색:", bad[:5]); sys.exit(1)
    atlas.save(os.path.join(OUT, "s07_props.png"))
    meta = {}
    for n, r in R.PROPS.items():
        key = "gear_door#0" if n == "gear_door" else (n + "#0" if n in R.PROP_FRAMES else n)
        x0, y0, w, h = pos[key]
        fw, fh = r["foot"]
        if r["kind"] in ("wall", "door"):
            off = [r["dx"] - 1, r["dy"] - 1]
        else:
            off = [(fw * T - (w - 2)) // 2 - 1 if fw else -(w // 2) + 16, fh * T + r["down"] - h + 1]
            if fw == 0:                                            # 장식: 칸 가운데 아래에 놓는다
                off = [16 - w // 2, T - h + 1]
        e = {"rect": [x0, y0, w, h], "foot": [fw, fh], "kind": r["kind"], "off": off}
        if n + "#open" in pos:
            e["open"] = list(pos[n + "#open"])
        for st in R.PROP_STATES.get(n, {}):
            e.setdefault("states", {})[st] = list(pos[f"{n}#{st}"])
        if n == "gear_door":
            e["frames"] = [list(pos[f"gear_door#{f}"]) for f in range(R.GEAR_FRAMES)]
        if n in R.PROP_FRAMES:
            e["frames"] = [list(pos[f"{n}#{f}"]) for f in range(R.PROP_FRAMES[n][1])]
        meta[n] = e
    json.dump({"props": meta, "tile": T}, open(os.path.join(OUT, "s07_props.json"), "w", encoding="utf-8"), ensure_ascii=False,
              indent=1, sort_keys=True)
    print(f"소품: {len(meta)}종, 아틀라스 {atlas.size[0]}×{atlas.size[1]}")


def export_r01():
    """바깥 소품(0-10, art/tools/props_bc.py) → r01_props.png/json. 같은 오프셋 규칙, 상태 그림(states)."""
    import props_bc as B
    items = []
    for n, r in B.PROPS.items():
        items.append((n, outlined(r["fn"]())))
        for st, fn in B.STATES.get(n, {}).items():
            items.append((f"{n}#{st}", outlined(fn())))
    W = 1024
    x = y = rowh = 0
    pos = {}
    for k, im in items:
        if x + im.width > W:
            x, y, rowh = 0, y + rowh, 0
        pos[k] = (x, y, im.width, im.height)
        x += im.width
        rowh = max(rowh, im.height)
    atlas = Image.new("RGBA", (W, y + rowh), (0, 0, 0, 0))
    for k, im in items:
        atlas.alpha_composite(im, pos[k][:2])
    bad = check(atlas, P.allowed_set("UI"))
    if bad:
        print("팔레트 밖 색(r01):", bad[:5]); sys.exit(1)
    atlas.save(os.path.join(OUT, "r01_props.png"))
    meta = {}
    for n, r in B.PROPS.items():
        x0, y0, w, h = pos[n]
        fw, fh = r["foot"]
        off = [(fw * T - (w - 2)) // 2 - 1 if fw else -(w // 2) + 16, fh * T + r["down"] - h + 1]
        if r["kind"] == "wall":                                    # 벽 소품(봉천 실내): 벽면 윗칸 왼쪽 위 + dx·dy
            off = [r["dx"] - 1, r["dy"] - 1]
        elif fw == 0:
            off = [16 - w // 2, T - h + 1]
        e = {"rect": [x0, y0, w, h], "foot": [fw, fh], "kind": r["kind"], "off": off, "atlas": "r01"}
        for st in B.STATES.get(n, {}):
            e.setdefault("states", {})[st] = list(pos[f"{n}#{st}"])
        meta[n] = e
    json.dump({"props": meta, "tile": T}, open(os.path.join(OUT, "r01_props.json"), "w", encoding="utf-8"), ensure_ascii=False,
              indent=1, sort_keys=True)
    print(f"바깥 소품: {len(meta)}종, 아틀라스 {atlas.size[0]}×{atlas.size[1]}")


if __name__ == "__main__":
    main()
    export_r01()
