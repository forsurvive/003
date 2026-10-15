"""제작(단계 1-8c, SD-13 §3.10 · §7.9.2~§7.9.5) → game/data/weapons_craft.json · items_craft.json · recipes.json.
· 제작 무기 W-153~W-157: §3.10 표(열이 일반 무기 표와 달라 스키마 추출기 대신 여기서 뽑는다 — 필드는 weapons.json과 같다).
· 폭발물 W-151·W-152: 던지기·설치가 아직 없어 '폭발물' 잡화로 싣는다(만들고 들고 팔 수 있다. 쓰기는 투척 단계에서).
· 설계도 M-100~M-106(§7.9.2): 잡화, 무게 0(원작 설계도 무게 0). 사본은 같은 ID를 여러 장 갖는다.
· 레시피(§7.9.3)와 조리(§7.9.5): 재료 칸의 '(ID)' · '×N' · '또는' · 'I-054~I-059 중 1'을 읽는다. 조리 결과물 ID는 I-077~I-084(§7.9.5 끝).
실행: python3 tools/pipeline/craft_export.py
"""
import os, re, json

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOC = os.path.join(ROOT, "docs", "seoul-fallout", "13_items.md")
DATA = os.path.join(ROOT, "game", "data")
ID = re.compile(r"\b([IMW]-\d{3})\b")
NUM = re.compile(r"-?\d+(?:\.\d+)?")
NAMES = {}                                                                 # 아이템 ID → 이름(이름만 적힌 재료 칸)
for _f in os.listdir(DATA):
    if _f.startswith("items_") and _f.endswith(".json") and _f != "items_craft.json":
        for _k, _v in json.load(open(os.path.join(DATA, _f), encoding="utf-8")).items():
            NAMES[_k] = str(_v.get("name", ""))


def table(lines, head):
    i = next(k for k, l in enumerate(lines) if l.startswith(head))
    rows = []
    for k in range(i + 1, len(lines)):
        l = lines[k]
        if l.startswith("#"):
            break
        if l.startswith("|") and not re.match(r"^\|[\s\-:|]+\|$", l.strip()):
            rows.append((k + 1, [c.strip() for c in l.strip().strip("|").split("|")]))
    return rows[1:]                                                        # 머리줄 빼기


def num(s, d=0.0):
    m = NUM.search(s.replace("−", "-").replace(",", ""))
    return (float(m.group()) if "." in m.group() else int(m.group())) if m else d


def slot(cell):
    """재료 칸 하나 → {"any": [ID…], "n": 수} · 캡 → {"caps": n} · 빈 칸 → None"""
    c = cell.replace("**", "").strip()
    if c in ("—", "-", ""):
        return None
    n = 1
    m = re.search(r"[×x]\s*(\d+)", c)
    if m:
        n = int(m.group(1))
    if c.startswith("캡"):
        return {"caps": n}
    if c == "물":                                                          # 조리 표 둘째 줄부터 '물' = 첫 줄의 물(I-054~I-059 중 1)
        c = "물(I-054~I-059 중 1)"
    rng = re.search(r"([IM])-(\d{3})~[IM]-(\d{3})", c)
    if rng:
        ids = ["%s-%03d" % (rng.group(1), k) for k in range(int(rng.group(2)), int(rng.group(3)) + 1)]
    else:
        ids = ID.findall(c)
    if not ids:
        nm = re.sub(r"\s*[×x]\s*\d+", "", c).strip()
        ids = [k for k, v in NAMES.items() if v == nm]                      # 표가 이름만 적은 칸(양념 꾸러미 = M-049)
    if not ids:
        raise ValueError("재료 ID 없음: " + c)
    return {"any": ids, "n": n}


def main():
    lines = open(DOC, encoding="utf-8").read().split("\n")
    weapons, items, recipes = {}, {}, {}
    # ---- §3.10 제작 무기
    for ln, c in table(lines, "### 3.10 "):
        wid, name, _orig, pose, skill, ammo, dmg, rate, rng, mag, wt, price, dur, role = c
        layer = pose.split("·")[-1].strip()
        rec = {"_src": "13_items.md:%d" % ln, "id": wid, "name": name, "skill": skill, "dmg": num(dmg), "weight": float(num(wt)),
               "price": int(num(price)), "note": role, "origin": "제작(작업대)", "layer": layer}
        if layer.startswith("X"):                                          # 폭발물: 잡화로
            items[wid] = {"_src": rec["_src"], "id": wid, "name": name, "cat": "misc", "explosive": True, "value": rec["price"], "weight": rec["weight"],
                          "desc": "%s 피해 %s · %s" % (skill, dmg, role), "dmg": rec["dmg"], "craft": True}
            continue
        kind = "melee" if skill == "근접 무기" else ("unarmed" if skill == "비무장" else "ranged")
        ammo_id = "" if kind != "ranged" else ("잡동사니" if ammo.startswith("잡동사니") else ammo)
        rec.update({"kind": kind, "rate": float(num(rate)), "range_eff": float(num(rng)), "durability": dur, "ammo": ammo, "ammo_id": ammo_id,
                    "mag": int(num(mag)) if mag not in ("—", "-") else None, "range_max": round(float(num(rng)) * 1.75, 2), "crit_mult": 1.0,
                    "falloff_min": 0.7, "two_handed": layer[:1] in ("R", "S", "H", "T"), "crit_dmg": num(dmg), "min_spread": 1.0, "ap_cost": None,
                    "reload_s": (1.5 if layer[:1] == "P" else 2.0) if kind == "ranged" else 0.0,
                    "sound": "melee" if kind != "ranged" else "pistol", "craft": True})
        if "DR 무시" in dmg:
            rec["ignore_dr"] = True
        fire = re.search(r"화염 (\d+)/초\((\d+)초\)", dmg)
        if fire:
            rec["burn"] = [int(fire.group(1)), int(fire.group(2))]
        poison = re.search(r"독 (\d+)/초\((\d+)초\)", dmg)
        if poison:
            rec["poison"] = [int(poison.group(1)), int(poison.group(2))]
        weapons[wid] = rec
    # ---- §7.9.2 설계도
    bp_of = {}
    for ln, c in table(lines, "#### 7.9.2 "):
        mid, name, out, copies, value, where = c
        items[mid] = {"_src": "13_items.md:%d" % ln, "id": mid, "name": name, "cat": "misc", "value": int(num(value)), "weight": 0.0,
                      "blueprint": out, "copies": int(num(copies)), "desc": "%s 설계도. 사본이 많을수록 잘 만든다(최대 3장). 얻는 곳: %s" % (out, where)}
        bp_of[out] = mid
    # ---- §7.9.3 레시피
    for ln, c in table(lines, "#### 7.9.3 "):
        head = c[0]
        perk = (re.search(r"(PK-\d{3})", head) or [None, ""])[1] if "PK-" in head else ""
        m = ID.search(head)
        if m:
            out, cnt = m.group(1), 1
        else:
            nm = re.match(r"(.+?)\s*[×x]\s*(\d+)", head)
            out, cnt = nm.group(1).strip(), int(nm.group(2))                 # 탄약(이름이 ID): 건설용 대못 ×20 · 마취 다트 ×10
        slots = [s for s in (slot(x) for x in c[1:5]) if s is not None]
        caps = sum(s.get("caps", 0) for s in slots)
        recipes[out] = {"_src": "13_items.md:%d" % ln, "out": out, "count": cnt, "caps": caps, "needs": [s for s in slots if "any" in s],
                        "blueprint": bp_of.get(out, ""), "perk": perk, "value_in": int(num(c[5])), "value_out": int(num(c[7])),
                        "kind": "weapon" if out in weapons else ("explosive" if out in items and items[out].get("explosive") else
                                                                  ("ammo" if not out[:2] in ("I-", "M-", "W-") else "item")), "cook": False}
    # ---- §7.9.5 조리(결과 ID I-077~I-084, 표 순서)
    k = 77
    for ln, c in table(lines, "#### 7.9.5 "):
        name, mats, hp, rad, note = c
        iid = "I-%03d" % k
        k += 1
        slots = []
        for part in re.split(r"\s\+\s(?![^()]*\))", mats):                 # 괄호 안 '+'는 나누지 않는다
            s = slot(part)
            if s:
                slots.append(s)
        heal = num(hp)
        over = re.search(r"(\d+)초", hp)
        rad_rule = "sum" if "재료 합" in rad else "flat"
        rad_v = num(rad.replace("재료 합", ""), 0) if rad_rule == "sum" else num(rad, 0)
        keep = re.search(r"무게 ([\d.]+)", note)
        items[iid] = {"_src": "13_items.md:%d" % ln, "id": iid, "name": name, "cat": "aid", "heal": heal, "rads": rad_v if rad_rule == "flat" else 0,
                      "value": 0, "weight": float(keep.group(1)) if keep else 0.5, "cooked": True,
                      "desc": "HP +%d%s · 라드 %s" % (heal, " (%s초에 걸쳐)" % over.group(1) if over else "", rad)}
        if over:
            items[iid]["heal_secs"] = int(over.group(1))
        recipes[iid] = {"_src": "13_items.md:%d" % ln, "out": iid, "count": 1, "caps": 0, "needs": slots, "blueprint": "",
                        "perk": "PK-009" if "PK-009" in note else "", "cook": True, "rad_rule": rad_rule, "rad_add": rad_v, "kind": "food"}
    # 조리 결과 가치(표에 없음): 재료 가치 합 + 2(구현 정합 — 끓이는 수고를 얹는다)
    vals = {}
    for f in os.listdir(DATA):
        if f.startswith("items_") and f.endswith(".json") and f != "items_craft.json":
            for kk, vv in json.load(open(os.path.join(DATA, f), encoding="utf-8")).items():
                vals[kk] = vv
    for rid, r in recipes.items():
        for s in r["needs"]:
            for i in s["any"]:
                if i not in vals and i not in items and i not in weapons:
                    raise SystemExit("레시피 %s 재료 %s가 아이템 표에 없다" % (rid, i))
        if r["cook"]:
            items[rid]["value"] = sum(int(vals[s["any"][0]].get("value", 0)) * s["n"] for s in r["needs"]) + 2
    # 조리 '재료 합' 라드(§7.9.5): 물에 따라 라드가 다르다 — 라드 0인 물(정화수·생수)로 끓인 것이 기본 ID,
    # 라드가 있는 물로 끓인 것은 '기본ID+물ID' 변형(이름 뒤 물 이름). 다른 '또는' 칸은 첫 재료의 라드로 센다(구현 정합).
    WATER = ["I-%03d" % k for k in range(54, 60)]
    for rid, r in list(recipes.items()):
        if not r["cook"] or r["rad_rule"] != "sum":
            continue
        base = sum(int(vals[s["any"][0]].get("rads", 0)) * s["n"] for s in r["needs"] if s["any"] != WATER)
        wat = [s for s in r["needs"] if s["any"] == WATER]
        items[rid]["rads"] = max(0, base + int(r["rad_add"]))
        r["variants"] = {}
        for w in (WATER if wat else []):
            wr = int(vals[w].get("rads", 0))
            if wr == 0:
                continue
            vid = "%s+%s" % (rid, w)
            v = dict(items[rid])
            v.update({"id": vid, "name": "%s(%s)" % (items[rid]["name"], vals[w]["name"]), "rads": max(0, base + wr + int(r["rad_add"])),
                      "desc": "HP +%d · 라드 +%d — %s로 끓였다" % (items[rid]["heal"], max(0, base + wr + int(r["rad_add"])), vals[w]["name"])})
            items[vid] = v
            r["variants"][w] = vid
        items[rid]["desc"] = "HP +%d · 라드 +%d%s" % (items[rid]["heal"], items[rid]["rads"], " — 맑은 물로 끓였다" if wat else "")
    for name, obj in (("weapons_craft", weapons), ("items_craft", items), ("recipes", recipes)):
        json.dump(obj, open(os.path.join(DATA, name + ".json"), "w", encoding="utf-8"), ensure_ascii=False, sort_keys=True, indent=1)
    print("제작: 무기 %d · 잡화 %d(설계도 %d · 폭발물 %d · 조리 %d) · 레시피 %d(조리 %d)" % (
        len(weapons), len(items), sum(1 for v in items.values() if "blueprint" in v), sum(1 for v in items.values() if v.get("explosive")),
        sum(1 for v in items.values() if v.get("cooked")), len(recipes), sum(1 for r in recipes.values() if r["cook"])))


if __name__ == "__main__":
    main()
