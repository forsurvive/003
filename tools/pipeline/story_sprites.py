"""이야기 인물 맵 시트 굽기 (SD-19 §6.7 'NPC는 빌드 때 굽기', SD-16 §3.11 아이작풍).
원고(game/data/dialogue/*.json)에 나오는 인물 — 화자 + 연출 명령(show·move·face·balloon)의 대상 — 과 실내 맵(data/maps)의 인물마다 SD-07b 외형 코드로
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


# 걸음마 주인공(MQ-P1 돌잔치, 2259): 아동 몸 K1 + 고른 피부 S1~S6, 아기라 머리카락 없음. 주인공 외형은 게임에서 고르므로 여섯 벌 다 굽는다
TODDLER = [f"K1-S{i}-HR00-H1-T01-0-PF11-HD00-EY00" for i in range(1, 7)]


def look_sheet(code):
    return "st_look_" + code.lower().replace("-", "_")


def map_looks():
    """맵 원고에서 look=으로 정한 모습들(+ 걸음마 주인공)."""
    out = set(TODDLER)
    for f in glob.glob(os.path.join(DATA, "maps", "*.json")):
        if not os.path.basename(f).startswith("_"):
            out |= {n["look"] for n in json.load(open(f, encoding="utf-8")).get("npcs", []) if n.get("look")}
    return out


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
    for f in glob.glob(os.path.join(DATA, "maps", "*.json")):         # 실내 맵에 서 있는 인물(단계 0-5)
        if os.path.basename(f).startswith("_"):
            continue
        for n in json.load(open(f, encoding="utf-8")).get("npcs", []):
            ids.add(n["id"])
    return ids


def main():
    npcs = json.load(open(os.path.join(DATA, "npcs.json")))["npcs"]
    pack.OUT = TMP
    os.makedirs(TMP, exist_ok=True)
    made, skipped, index = 0, [], {}
    jobs = [(nid, npcs.get(nid, {}).get("look", ""), sheet_name(nid)) for nid in sorted(cast())]
    jobs += [(look_sheet(c), c, look_sheet(c)) for c in sorted(map_looks())]
    for nid, look, name in jobs:
        if not look or look.split("-")[0] in ("AN", "RB", "BY", "OBJ") or "·" in look:
            skipped.append(nid)
            continue
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
