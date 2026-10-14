"""장소 표 추출(단계 1-2, SD-12 §5.4·§5.5 · SD-09a~f 개요 표 = 정본): 425곳의 아이콘 번호(SD-12 §5.4 22유형) · 지도 마커 Y/N ·
발견 전 숨김 · 통계 제외 · 경비 거점([경]) · 등급 · 위협 · 좌표를 game/data/world/places.json으로.
maps/locations.csv는 기계 판독용 사본(마커 열 표기가 권역마다 다르다)이라 개요 표를 먼저 읽고, 표에 없는 값만 CSV로 메운다.
발견 XP(SD-10 §4.4 · SD-09b 정합): 지하철역 5 · 주요 25(정착지·볼트·랜드마크·전망 지점·S·A등급 던전) · 그 밖 10 · 마커 N·통계 제외 0.
python3 tools/pipeline/places_extract.py
"""
import os, re, csv, json, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOCS = os.path.join(ROOT, "docs", "seoul-fallout")
OUT = os.path.join(ROOT, "game", "data", "world", "places.json")
# 유형 → 아이콘(표에 번호가 없을 때만, SD-12 §5.4)
TYPE_ICON = {"볼트": 1, "정착지": 3, "세력 거점": 4, "지하철역": 6, "지하 시설": 7, "교역소": 9, "관제망 시설": 12, "기반 시설": 12,
             "검문소": 13, "횡단로": 15, "자연": 16, "전망 지점": 16, "나루": 17, "폐허": 19, "랜드마크": 20, "던전": 22, "야영지": 22,
             "크리처 둥지": 22, "경계": 22}
MAJOR = {"정착지", "볼트", "랜드마크", "전망 지점"}
errors = []


def tables(path):
    """머리에 '마커'가 있는 표의 행들(사전)"""
    out, head = [], None
    for line in open(path, encoding="utf-8"):
        if not line.startswith("|"):
            head = None
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if head is None:
            head = cells
            continue
        if set("".join(cells)) <= set("-: "):
            continue
        if any("마커" in h for h in head) and cells and re.match(r"L-[A-Z0-9]+-\d+$", cells[0]) and len(cells) == len(head):
            out.append(dict(zip(head, cells)))
    return out


def main():
    rows = {}
    for f in sorted(os.listdir(DOCS)):
        if re.match(r"09[a-f]_", f):
            for r in tables(os.path.join(DOCS, f)):
                rows[r[[k for k in r if k.endswith("ID")][0]]] = (f, r)
    csvrows = {r["lid"]: r for r in csv.DictReader(open(os.path.join(DOCS, "maps", "locations.csv"), encoding="utf-8"))}
    places = {}
    for lid, c in csvrows.items():
        e = {"name": c["name"], "type": c["type"], "region": c["region"], "tx": int(c["tx"]), "ty": int(c["ty"]),
             "threat": int(c["threat"] or 0), "grade": c["grade"]}
        src, r = rows.get(lid, (None, None))
        icon, marker, hidden, nostat, guard = None, True, False, False, False
        if r is not None:
            ty_col = r[[k for k in r if k.startswith("유형")][0]]
            m = re.search(r"#\s*(\d+)|/\s*(\d+)", ty_col)
            if m:
                icon = int(m.group(1) or m.group(2))
            guard = "[경]" in ty_col or ("경비" in r and r["경비"].strip().upper().startswith("Y"))
            mk = r[[k for k in r if k.startswith("마커")][0]]
            marker = mk.startswith("Y")
            hidden = "숨김" in mk
            nostat = "통계 제외" in mk
            xy = re.match(r"(\d+)\s*·\s*(\d+)", r.get("tx·ty", ""))
            if xy and (int(xy.group(1)), int(xy.group(2))) != (e["tx"], e["ty"]):
                errors.append("%s 좌표 표 %s ≠ CSV %d·%d" % (lid, xy.group(0), e["tx"], e["ty"]))
        else:                                                             # 개요 표에 없는 행: CSV 마커 열로(— · × · 숨김 · ○(R01·R02) = 없음)
            mk = c["marker"].strip()
            marker = not (mk in ("—", "×", "숨김") or (c["region"] in ("R01", "R02") and mk == "○"))
            hidden = "◐" in mk or mk == "숨김"
            m = re.match(r"●?(\d+)", mk)
            if m:
                icon = int(m.group(1))
            guard = "[경]" in mk
        if icon is None:
            icon = TYPE_ICON.get(e["type"], 22)
        xp = 0
        if marker and not nostat:
            xp = 5 if e["type"] == "지하철역" else (25 if e["type"] in MAJOR or (e["type"] == "던전" and e["grade"] in ("S", "A")) else 10)
        e.update({"icon": icon, "marker": marker, "hidden": hidden, "no_stats": nostat, "guard": guard, "xp": xp,
                  "src": src or "locations.csv"})
        places[lid] = e
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(places, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    n_tab = sum(1 for p in places.values() if p["src"] != "locations.csv")
    icons = {}
    for p in places.values():
        icons[p["icon"]] = icons.get(p["icon"], 0) + 1
    print("장소 %d곳(개요 표 %d · CSV만 %d) · 마커 Y %d · 숨김 %d · 경비 거점 %d · 발견 XP 합 %d · 아이콘 %s | 오류 %d" % (
        len(places), n_tab, len(places) - n_tab, sum(p["marker"] for p in places.values()), sum(p["hidden"] for p in places.values()),
        sum(p["guard"] for p in places.values()), sum(p["xp"] for p in places.values()), dict(sorted(icons.items())), len(errors)))
    for e in errors:
        print("  오류:", e)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
