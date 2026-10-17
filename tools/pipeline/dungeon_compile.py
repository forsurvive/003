"""던전 표(script/world/dungeons.txt, 1-D0) → game/data/dungeons.json.
맵 변환(map_compile) 뒤에 돈다: 맵 · 우두머리 · 재채움 자리를 변환된 맵에서 읽는다. 형식은 원고 머리 주석."""
import os, sys, json, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_compile as MC
from script_compile import ENGINE_VARS, FNS

ROOT = MC.ROOT
SRC = os.path.join(ROOT, "script", "world", "dungeons.txt")
OUT = os.path.join(ROOT, "game", "data", "dungeons.json")
MAPS = os.path.join(ROOT, "game", "data", "maps")


def main():
    places = json.load(open(os.path.join(ROOT, "game", "data", "world", "places.json"), encoding="utf-8"))
    enemies = json.load(open(os.path.join(ROOT, "game", "data", "enemies.json"), encoding="utf-8"))
    known_vars = set(json.load(open(os.path.join(ROOT, "game", "data", "vars.json")))["vars"]) | ENGINE_VARS
    errs, out, by_map, cur = [], {}, {}, None
    for i, ln in enumerate(open(SRC, encoding="utf-8").read().split("\n"), 1):
        s = ln.split(" #")[0].strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("@"):
            m = re.match(r"^@\s+([A-Z0-9]+)\s+(.+)$", s)
            if not m:
                errs.append(f"{i}: 머리 줄은 '@ 접미 이름'")
                continue
            cur = {"id": "DG-" + m.group(1), "var": "DG_" + m.group(1), "name": m.group(2), "lid": "", "maps": [], "music": "",
                   "refill": None, "clear": "", "bosses": [], "spots": [], "chalk": [None, None, None]}
            if cur["id"] in out:
                errs.append(f"{i}: 던전 ID 겹침 {cur['id']}")
            out[cur["id"]] = cur
            continue
        if cur is None:
            errs.append(f"{i}: 머리 줄 '@' 앞의 줄")
            continue
        w = s.split()
        try:
            if w[0] == "lid":
                if w[1] not in places:
                    raise ValueError(f"모르는 장소 {w[1]}")
                cur["lid"] = w[1]
            elif w[0] == "map":
                mid, floor, z = w[1], w[2], int(w[3])
                p = os.path.join(MAPS, mid + ".json")
                if not os.path.exists(p):
                    raise ValueError(f"맵 {mid}가 없다(map_compile 뒤에 돈다)")
                if mid in by_map:
                    raise ValueError(f"맵 {mid}가 던전 {by_map[mid]}에 이미 있다")
                d = json.load(open(p, encoding="utf-8"))
                cur["maps"].append({"id": mid, "floor": floor, "z": z})
                by_map[mid] = cur["id"]
                if len(cur["maps"]) == 1:                               # 재입주 자리: 표지 refill1… 가 있으면 그 자리(허리 물 · 매복 칸을 피해 원고가 고른다)
                    cur["spots"] = [[mid, int(v[0]), int(v[1])] for k, v in sorted(d.get("marks", {}).items()) if k.startswith("refill")]
                    cur["_marks"] = bool(cur["spots"])
                for e in d.get("enemies", []):
                    if e.get("who"):
                        continue
                    if e.get("boss"):
                        cur["bosses"].append("kill:%s:%d,%d" % (mid, e["x"], e["y"]))
                    elif len(cur["maps"]) == 1 and not cur["_marks"]:
                        cur["spots"].append([mid, e["x"], e["y"]])
            elif w[0] == "music":
                cur["music"] = w[1]
            elif w[0] == "refill":
                r = {"days": int(w[1]), "pct": int(w[2]), "people": [], "beasts": []}
                for part in w[3:]:
                    k, v = part.split("=", 1)
                    ids = [x for x in v.split(",") if x]
                    bad = [x for x in ids if x not in enemies]
                    if bad:
                        raise ValueError(f"모르는 적 {bad}")
                    r[{"사람": "people", "짐승": "beasts"}[k]] = ids
                cur["refill"] = r
            elif w[0] == "chalk":                                       # chalk 상태 소품 "글" — 월드 입구 분필 표식(1-D2: 사람이 지키는 입구엔 없음)
                m2 = re.match(r'^chalk\s+([012])\s+(\S+)\s+"(.+)"$', s)
                if not m2:
                    raise ValueError("chalk 줄은 'chalk 상태 소품 \"글\"'")
                cur["chalk"][int(m2.group(1))] = [m2.group(2), m2.group(3)]
            elif w[0] == "clear":
                expr = s[len("clear"):].strip()
                MC.check_cond(expr, known_vars, FNS)
                cur["clear"] = expr
            else:
                raise ValueError(f"모르는 줄 '{w[0]}'")
        except (ValueError, IndexError, KeyError, MC.Err) as e:
            errs.append(f"{i}: {e}")
    for d in out.values():
        d.pop("_marks", None)
        if any(d["chalk"]) and not all(d["chalk"]):
            errs.append(f"{d['id']}: chalk는 상태 0 · 1 · 2 셋을 모두 적거나 하나도 적지 않는다")
        if not any(d["chalk"]):
            d["chalk"] = []
        if not d["lid"] or not d["maps"]:
            errs.append(f"{d['id']}: lid · map이 있어야 한다")
        if not d["bosses"] and not d["clear"]:
            errs.append(f"{d['id']}: 우두머리(enemy … boss=1)나 clear 식이 있어야 정리할 수 있다")
        if d["refill"] and len(d["spots"]) < max(len(d["refill"]["people"]), len(d["refill"]["beasts"])):
            errs.append(f"{d['id']}: 재채움 자리(첫 맵의 우두머리 아닌 적 자리) {len(d['spots'])}곳이 무리 수보다 적다")
    for e in errs:
        print("오류 dungeons.txt:" + e)
    if errs:
        sys.exit(1)
    json.dump({"dungeons": out, "by_map": by_map}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"던전: {len(out)}곳 — " + ", ".join(f"{d['id']} {d['name']}(맵 {len(d['maps'])} · 우두머리 {len(d['bosses'])})" for d in out.values()))


if __name__ == "__main__":
    main()
