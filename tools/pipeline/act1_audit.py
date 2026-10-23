#!/usr/bin/env python3
"""1막 마감 배치 대조(단계 1-13a — SD-19 §5 단계 1 완료 기준 6 · 7 · 5 · 8 · 10).
장소: docs/seoul-fallout/maps/locations.csv의 R01 · R02 행 ↔ game/data/world/places.json · place_geo.json(도착점) — 있음 · 좌표 · 지도 표식.
인물: 1막 인물(npcs.json의 장소가 R01 · R02 · ID N-R01 · N-R02 · 1막 C-)마다 놓인 자리(맵 npcs · 진행기 코드)와 말 걸 거리(대화 장면 · 바크) · 한 맵(정착지) 안 같은 외형 코드.
인카운터: encounters.json RE 수(R01 · R02) — 기본 표 30종(SD-19 §5).  도달성: world.json 못 닿는 청크.
결과: game/data/_act1_audit.md · .json. 허용: tools/pipeline/act1_audit_allow.yaml('ID|대상': 이유). 새 실패 0이 통과.
"""
import csv
import glob
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "game", "data")
ALLOW = os.path.join(os.path.dirname(__file__), "act1_audit_allow.yaml")
R = []
NPC_OK = {}


def add(area, item, status, note=""):
    R.append({"area": area, "item": item, "status": status, "note": note})


def load(p):
    return json.load(open(p, encoding="utf-8"))


def allow_list():
    out = {}
    if os.path.exists(ALLOW):
        for l in open(ALLOW, encoding="utf-8"):
            m = re.match(r'^"([^"]+)":\s*(.*)$', l.strip())
            if m:
                out[m.group(1)] = m.group(2)
    return out


def places():
    pl = load(os.path.join(DATA, "world", "places.json"))
    geo = load(os.path.join(DATA, "world", "place_geo.json"))
    world = load(os.path.join(DATA, "world", "world.json"))
    cs = int(world.get("chunk_size", 32)) if isinstance(world.get("chunk_size"), int) else 32
    unreached = set(str(c) for c in world.get("unreached", []))
    n = 0
    for row in csv.DictReader(open(os.path.join(ROOT, "docs", "seoul-fallout", "maps", "locations.csv"), encoding="utf-8")):
        if row["region"] not in ("R01", "R02"):
            continue
        n += 1
        lid = row["lid"]
        p = pl.get(lid)
        if p is None:
            add("장소", "%s %s" % (lid, row["name"]), "실패", "places.json에 없음")
            continue
        bad = []
        if (int(p["tx"]), int(p["ty"])) != (int(row["tx"]), int(row["ty"])):
            bad.append("좌표 CSV %s,%s ↔ 자료 %s,%s" % (row["tx"], row["ty"], p["tx"], p["ty"]))
        mk = row["marker"].strip()
        want = not (mk in ("—", "×", "숨김") or mk == "○")
        if bool(p.get("marker", True)) != want:
            bad.append("지도 표식 CSV '%s' ↔ 자료 %s" % (mk, p.get("marker")))
        g = geo.get(lid)
        if not g or "arrive" not in g:
            bad.append("도착점 없음(place_geo)")
        else:
            ax, ay = g["arrive"]
            ck = "C-%02d-%02d" % (int(ax) // cs, int(ay) // cs)
            if ck in unreached:
                bad.append("도착 청크 %s 못 닿음" % ck)
        add("장소", "%s %s" % (lid, row["name"]), "실패" if bad else "통과", " · ".join(bad))
    add("장소", "R01 · R02 장소 수(CSV)", "통과" if n >= 62 else "주의", "%d곳 — SD-19 §5 '63곳'(볼트 S-07 L-R01-01은 통계 제외 표식)" % n)


def place_content(npc_ok):
    """장소 안 내용: SD-09a 장소 절의 NPC · 적 줄 ↔ 구현(원고 장면 머리의 장소 ID · 끼운 손 맵 · 손 자리 · 인물 배치)"""
    doc = open(os.path.join(ROOT, "docs", "seoul-fallout", "09a_locations-r01-r02.md"), encoding="utf-8").read().split("\n")
    pl = load(os.path.join(DATA, "world", "places.json"))
    world = load(os.path.join(DATA, "world", "world.json"))
    spots = load(os.path.join(DATA, "world", "spots_src.json"))
    spots = spots.get("spots", list(spots.values())[0]) if isinstance(spots, dict) else spots
    geo = load(os.path.join(DATA, "world", "place_geo.json"))
    dmaps = {}
    for d in geo.get("_doors", []):                                         # 장소 문 → 손 실내(생성 G- 빼고)
        if str(d.get("lid", "")) and not str(d.get("to", "")).startswith("G-"):
            dmaps.setdefault(str(d["lid"]), set()).add(str(d["to"]))
    scen = {}
    for f in glob.glob(os.path.join(ROOT, "script", "**", "*.txt"), recursive=True):
        for l in open(f, encoding="utf-8"):
            if l.startswith("@scene"):
                for lid in re.findall(r"L-R0[12]-\d+", l):
                    scen[lid] = scen.get(lid, 0) + 1
    cur = None
    sec = {}
    for l in doc:
        m = re.match(r"^#### (L-R0[12]-\d+) ", l)
        if m:
            cur = m.group(1)
            sec[cur] = []
            continue
        if cur and l.startswith("- **") and any(k in l[:16] for k in ("NPC", "적", "병력")):
            sec[cur].append(l)
    for lid, lines in sorted(sec.items()):
        p = pl.get(lid, {})
        tx, ty = int(p.get("tx", -999)), int(p.get("ty", -999))
        near_inset = [i["id"] for i in world.get("insets", []) if i["origin"][0] - 30 <= tx <= i["origin"][0] + i["size"][0] + 30 and i["origin"][1] - 30 <= ty <= i["origin"][1] + i["size"][1] + 30]
        near_spot = [s2.get("lid") or s2.get("key") for s2 in spots if s2.get("lid") == lid or (abs(s2["tile"][0] - tx) <= 30 and abs(s2["tile"][1] - ty) <= 30)]
        ids = sorted(set(re.findall(r"\b(?:N-R0[12]-\d+|C-\d{3})\b", " ".join(lines))))
        miss = [i for i in ids if i in npc_ok and not npc_ok[i]]
        rooms = sorted(dmaps.get(lid, set()))
        has = scen.get(lid, 0) > 0 or near_inset or near_spot or rooms
        note = "장면 %d · 손 맵 %s · 손 자리 %d · 손 실내 %s" % (scen.get(lid, 0), ",".join(near_inset) or "-", len(near_spot), ",".join(rooms) or "-")
        if miss:
            add("장소 내용", "%s %s" % (lid, p.get("name", "")), "주의", note + " · 자리 없는 인물 " + ",".join(miss))
        elif not has:
            add("장소 내용", "%s %s" % (lid, p.get("name", "")), "주의", note + " · 손으로 만든 내용이 없다(생성 지형 · 실내만)")
        else:
            add("장소 내용", "%s %s" % (lid, p.get("name", "")), "통과", note)


def act1_npc(nid, v):
    pl = str(v.get("place", ""))
    if pl.startswith(("L-R01", "L-R02", "R01", "R02")) or nid.startswith(("N-R01", "N-R02")):
        return True
    return nid.startswith("C-") and any(str(q).startswith(("MQ-10", "SQ-S", "FQ-", "UQ-0", "UQ-6", "UQ-7")) for q in v.get("quests", []))


def npcs():
    nd = load(os.path.join(DATA, "npcs.json"))["npcs"]
    scenes = {}
    for f in glob.glob(os.path.join(DATA, "dialogue", "*.json")):
        d = load(f)
        for who in ([d.get("npc")] if isinstance(d.get("npc"), str) else (d.get("npc") or [])):
            scenes.setdefault(str(who), []).append(d["id"])
        for op in d.get("ops", []):                                         # 장면 안에서 말하는 사람(합석 · 무대)
            w = op.get("who")
            if isinstance(w, str) and w not in ("SYS", "PC"):
                scenes.setdefault(w, [])
    placed = {}
    barks = {}
    looks = {}
    for f in glob.glob(os.path.join(DATA, "maps", "*.json")):
        m = load(f)
        mid = m.get("id", os.path.basename(f)[:-5])
        for e in m.get("npcs", []):
            i = str(e.get("id", ""))
            placed.setdefault(i, set()).add(mid)
            if str(e.get("bark", "")).strip():
                barks[i] = True
            lk = str(nd.get(i, {}).get("look", "") or e.get("sheet", ""))
            if lk:
                looks.setdefault(mid, {}).setdefault(lk, set()).add(i)
    code = ""
    for f in glob.glob(os.path.join(ROOT, "game", "scenes", "story", "*.gd")) + glob.glob(os.path.join(ROOT, "game", "systems", "world", "*.gd")) \
            + [os.path.join(DATA, "world", "spots_src.json"), os.path.join(DATA, "world", "place_geo.json")]:   # 월드 손 자리(spots)도 '놓임'
        code += open(f, encoding="utf-8").read()
    n = talk = 0
    seen_p = set()
    NPC_OK.clear()
    for nid, v in sorted(nd.items()):
        if v.get("unnamed") or not act1_npc(nid, v):
            continue
        ids = sorted(set([nid] + [str(x) for x in v.get("ids", [])]))
        if tuple(ids) in seen_p:
            continue                                                        # 같은 사람의 다른 ID(C- ↔ N-)
        seen_p.add(tuple(ids))
        n += 1
        where = set().union(*[placed.get(i, set()) for i in ids])
        by_code = any(('"%s"' % i) in code for i in ids)
        can = any(i in scenes or barks.get(i, False) for i in ids)
        for i in ids:
            NPC_OK[i] = bool((where or by_code) and can)
        if can:
            talk += 1
        if not where and not by_code:
            add("인물", "%s %s" % (nid, v.get("name", "")), "주의", "맵에도 진행기에도 자리가 없다(장소 %s)" % v.get("place", "?"))
        elif not can:
            add("인물", "%s %s" % (nid, v.get("name", "")), "주의", "놓였지만 대화 장면도 바크도 없다(%s)" % ",".join(sorted(where or [])))
    add("인물", "1막 이름 있는 인물 수", "통과", "%d명 · 말 걸 거리 있음 %d — SD-19 §5 'NPC 138명(단계 0 포함)'" % (n, talk))
    dup = 0
    for mid, lk in sorted(looks.items()):
        for code_, ids in lk.items():
            named = sorted(i for i in ids if i in nd and not nd[i].get("unnamed"))
            if len(named) >= 2:
                dup += 1
                add("외형", "%s %s" % (mid, code_[:40]), "실패", "같은 외형: " + ", ".join(named))
    add("외형", "한 맵 안 같은 외형(이름 있는 인물)", "통과" if dup == 0 else "실패", "%d건" % dup)


def encounters():
    e = load(os.path.join(DATA, "world", "encounters.json"))
    re_ = e.get("re", {})
    r12 = [k for k, v in re_.items() if set(v.get("regions", [])) & {"R01", "R02", "*"} or not v.get("regions")]
    add("인카운터", "R01 · R02 RE 종류", "통과" if len(r12) >= 30 else "실패", "%d종 / 기본 표 30종(SD-19 §5 · D-130)" % len(r12))


def reach():
    w = load(os.path.join(DATA, "world", "world.json"))
    un = w.get("unreached", [])
    add("도달성", "걸어서 못 닿는 청크", "통과" if not un else "실패", "%d · 봉한 도심 %d · 물 청크 %d" % (len(un), len(w.get("sealed_core", [])), len(w.get("water_chunks", []))))


def main():
    places()
    npcs()
    place_content(NPC_OK)
    encounters()
    reach()
    al = allow_list()
    for r in R:
        r["allowed"] = r["status"] != "통과" and ("%s|%s" % (r["area"], r["item"])) in al
        r["reason"] = al.get("%s|%s" % (r["area"], r["item"]), "")
    fails = [r for r in R if r["status"] == "실패" and not r["allowed"]]
    warns = [r for r in R if r["status"] == "주의" and not r["allowed"]]
    md = ["# 1막 마감 배치 대조(1-13a — SD-19 §5 단계 1 완료 기준)", "", "| 판정 | 수 |", "|---|---|",
          "| 검사 | %d |" % len(R), "| 통과 | %d |" % sum(1 for r in R if r["status"] == "통과"),
          "| 주의 | %d |" % len(warns), "| 실패 | %d |" % len(fails), "| 허용(이유 있음) | %d |" % sum(1 for r in R if r["allowed"]), "",
          "| 판정 | 영역 | 대상 | 메모 |", "|---|---|---|---|"]
    order = {"실패": 0, "주의": 1, "통과": 2}
    for r in sorted(R, key=lambda x: (order[x["status"]], x["area"], x["item"])):
        st = ("허용(%s)" % r["reason"][:30]) if r["allowed"] else r["status"]
        md.append("| %s | %s | %s | %s |" % (st, r["area"], r["item"], r["note"].replace("|", "/")))
    open(os.path.join(DATA, "_act1_audit.md"), "w", encoding="utf-8").write("\n".join(md) + "\n")
    json.dump(R, open(os.path.join(DATA, "_act1_audit.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("1막 배치 대조: 검사 %d · 주의 %d · 실패 %d(새 %d) (game/data/_act1_audit.md)" % (len(R), len(warns), sum(1 for r in R if r["status"] == "실패"), len(fails)))


if __name__ == "__main__":
    main()
