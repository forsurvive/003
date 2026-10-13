"""이야기 인물 맵 시트 굽기 (SD-19 §6.7 'NPC는 빌드 때 굽기', SD-16 §3.11 아이작풍).
원고(game/data/dialogue/*.json)에 나오는 인물 — 화자 + 연출 명령(show·move·face·balloon)의 대상 — 마다 SD-07b 외형 코드로
대기·걷기 시트를 굽는다 → game/assets/sprites/st_<ID>.png + .json + .tres. 이미 있으면 다시 굽지 않는다.
사람이 아닌 인물(진돗개 AN- 등)은 건너뛴다(크리처 시트는 따로)."""
import os, sys, json, glob

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chibi as K
import pack
from art_import import spriteframes_tres, ROWS

DATA = os.path.join(ROOT, "game", "data")
SPR = os.path.join(ROOT, "game", "assets", "sprites")
TMP = os.path.join(ROOT, "art", "out", "story_sheets")
ACTOR_CMDS = {"show", "move", "face", "balloon", "hide", "pose"}


def sheet_name(npc_id):
    return "st_" + npc_id.lower().replace("-", "_")


def cast():
    ids = set()
    for f in glob.glob(os.path.join(DATA, "dialogue", "*.json")):
        if os.path.basename(f).startswith("_"):
            continue
        for op in json.load(open(f))["ops"]:
            if op["op"] == "line" and op["who"] != "SYS":
                ids.add(op["who"])
            if op["op"] == "cmd" and op["name"] in ACTOR_CMDS and op["args"] and op["args"][0][:2] in ("C-", "N-"):
                ids.add(op["args"][0])
    return ids


def main():
    npcs = json.load(open(os.path.join(DATA, "npcs.json")))["npcs"]
    pack.OUT = TMP
    os.makedirs(TMP, exist_ok=True)
    made, skipped, index = 0, [], {}
    for nid in sorted(cast()):
        look = npcs.get(nid, {}).get("look", "")
        if not look or look.split("-")[0] in ("AN", "RB", "BY", "OBJ") or "·" in look:
            skipped.append(nid)
            continue
        name = sheet_name(nid)
        index[nid] = name
        if os.path.exists(os.path.join(SPR, name + ".tres")):
            continue
        pack.pack(name, pack.chibi_sets(K.Look.parse(look), None, ("idle", "walk")), ("idle", "walk"), K.STRIDE)
        meta = json.load(open(os.path.join(TMP, name + ".json")))
        os.replace(os.path.join(TMP, name + ".png"), os.path.join(SPR, name + ".png"))
        anims = []
        for mo, m in sorted(meta["motions"].items(), key=lambda kv: kv[1]["start"]):
            for r, v in enumerate(ROWS):
                anims.append((f"{mo}_{v}", [(m["start"] + i, r) for i in range(m["count"])], True))
        fw, fh = meta["frame"]
        open(os.path.join(SPR, name + ".tres"), "w", encoding="utf-8").write(
            spriteframes_tres(f"res://assets/sprites/{name}.png", fw, fh, anims))
        json.dump(meta, open(os.path.join(SPR, name + ".json"), "w", encoding="utf-8"), ensure_ascii=False, sort_keys=True, indent=1)
        os.remove(os.path.join(TMP, name + ".json"))
        made += 1
    json.dump({"sheets": index}, open(os.path.join(SPR, "story_cast.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1,
              sort_keys=True)
    print(f"이야기 인물 시트: {len(index)}명 (새로 구움 {made}), 건너뜀 {skipped}")


if __name__ == "__main__":
    main()
