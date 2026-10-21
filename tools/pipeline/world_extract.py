"""월드 원자료 추출(단계 1-1, SD-19 §6.12 '기획서 표 → 데이터, 손 입력 금지').
SD-08 월드·권역 원문의 표를 그대로 읽어 game/data/world/source.json 하나로 모은다.
  · 권역 행별 청크 구간(4.3, 권역 판정 정본)       · 고도 격자(6.1, 청크 중심 고도 등급)
  · 산 정상 24(5.1) · 랜드마크 24(5.2) · 성문·극점·합류·고개 24(5.3) · 다리 양끝 25(5.4)
  · 하천 11(6.2) · 간선도로 14(6.3) · 철도·성곽 8(6.4, 청크 경로) · 방사능 구역 11(6.5) · 횡단로 15(8.2)
  · 장소 425(maps/locations.csv — SD-08 §11 순서, SD-09 개요 표 등급·마커)
python3 tools/pipeline/world_extract.py
"""
import os, re, json, csv, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "docs", "seoul-fallout", "08_world-regions.md")
OUT = os.path.join(ROOT, "game", "data", "world")
CHUNKS = (53, 43)
errors = []


def section(lines, title):
    """제목 줄(### 4.3 …)부터 다음 같은·윗 단계 제목 앞까지"""
    for i, l in enumerate(lines):
        if l.startswith("#") and title in l:
            lv = len(l) - len(l.lstrip("#"))
            out = []
            for m in lines[i + 1:]:
                if m.startswith("#") and len(m) - len(m.lstrip("#")) <= lv:
                    break
                out.append(m)
            return out, i + 1
    errors.append("절을 찾지 못함: " + title)
    return [], 0


def tables(sec):
    """절 안의 마크다운 표들 → [[머리, 행…], …]"""
    out, cur = [], None
    for l in sec:
        if l.startswith("|"):
            cells = [c.strip() for c in l.strip().strip("|").split("|")]
            if cur is None:
                cur = [cells]
            elif set("".join(cells)) <= set("-: "):
                continue
            else:
                cur.append(cells)
        elif cur is not None:
            out.append(cur)
            cur = None
    if cur is not None:
        out.append(cur)
    return out


def rows_of(sec, need):
    """머리에 need(열 이름 일부)가 모두 있는 표의 행들(사전)"""
    res = []
    for t in tables(sec):
        head = t[0]
        if all(any(n in h for h in head) for n in need):
            for r in t[1:]:
                if len(r) == len(head):
                    res.append(dict(zip(head, r)))
    return res


def path_of(s):
    pts = re.findall(r"(\d+)\s*,\s*(\d+)", s.replace("`", ""))
    return [[int(a), int(b)] for a, b in pts]


def main():
    lines = open(SRC, encoding="utf-8").read().split("\n")
    w = {"src": "08_world-regions.md", "chunks": list(CHUNKS), "chunk_size": 40, "tile_m": 18.5}

    # 4.3 권역 행별 구간
    sec, at = section(lines, "4.3 행별 청크 구간")
    region = {}
    for r in rows_of(sec, ["권역", "구간"]):
        code = r["권역"].strip()
        for part in re.split(r"\s*/\s*", r[[k for k in r if "구간" in k][0]]):
            m = re.match(r"Y(\d+):(.+)", part.strip())
            if not m:
                continue
            y = int(m.group(1))
            for seg in m.group(2).split(","):
                a, _, b = seg.strip().partition("-")
                for x in range(int(a), int(b or a) + 1):
                    k = "%d,%d" % (x, y)
                    if k in region:
                        errors.append("청크 %s 권역 겹침 %s/%s" % (k, region[k], code))
                    region[k] = code
    w["region"] = region
    counts = {}
    for v in region.values():
        counts[v] = counts.get(v, 0) + 1
    w["region_counts"] = counts
    if len(region) != 1230:
        errors.append("권역 청크 합 %d ≠ 1230" % len(region))

    # 6.1 고도 격자(코드 블록 안, 행 번호 두 자리 + 53칸)
    sec, at = section(lines, "6.1 지형 고도")
    grid = {}
    inblock = False
    for l in sec:
        if l.startswith("```"):
            inblock = not inblock
            continue
        if inblock:
            m = re.match(r"^(\d\d) (.*)$", l)
            if m:
                y = int(m.group(1))
                row = m.group(2)
                for x, ch in enumerate(row[:CHUNKS[0]]):
                    if ch != " ":
                        grid["%d,%d" % (x, y)] = ch
    w["elev_grid"] = grid
    w["elev_class"] = {".": [0, 49], ":": [50, 149], "^": [150, 299], "M": [300, 499], "A": [500, 900], "#": [0, 49], "~": [0, 0]}

    def points(title, kind_col="구분"):
        sec, _ = section(lines, title)
        out = []
        for r in rows_of(sec, ["기준점", "tx", "ty"]):
            e = {"name": r["기준점"], "kind": r.get(kind_col, ""), "tx": int(r["tx"]), "ty": int(r["ty"]),
                 "chunk": r.get("청크", ""), "region": r.get("권역", "")}
            m = re.search(r"(\d+)m", e["kind"])
            if m:
                e["h"] = int(m.group(1))
            m = re.search(r"랜드마크 ([SABC])", e["kind"])
            if m:
                e["grade"] = m.group(1)
            out.append(e)
        return out

    w["peaks"] = points("5.1 산 정상")
    w["landmarks"] = points("5.2 랜드마크")
    w["boundary"] = points("5.3 ")
    sec, _ = section(lines, "5.4 한강 다리")
    w["bridges"] = [{"name": r["다리"], "state": r["게임 상태"], "n": [int(r["북단 tx"]), int(r["북단 ty"])],
                     "s": [int(r["남단 tx"]), int(r["남단 ty"])], "len": int(r["길이(t)"])}
                    for r in rows_of(sec, ["다리", "북단 tx", "남단 tx"])]

    def layer(title, name_col):
        sec, _ = section(lines, title)
        out = []
        for r in rows_of(sec, [name_col, "청크 경로"]):
            p = path_of(r[[k for k in r if "청크 경로" in k][0]])
            if len(p) < 2:
                continue
            e = {"layer": r.get("레이어", ""), "name": r[[k for k in r if name_col in k][0]], "path": p}
            for k in r:
                if "월드 길이" in k:
                    e["len"] = int(re.sub(r"\D", "", r[k]) or 0)
                if k == "역 수":
                    e["stations"] = r[k]
            out.append(e)
        return out

    w["rivers"] = layer("6.2 하천", "이름")
    w["roads"] = layer("6.3 간선도로", "이름")
    rails = layer("6.4 철도", "노선")
    w["rails"] = [r for r in rails if "성곽" not in r["layer"] and "도성" not in r["name"]]
    w["walls"] = [r for r in rails if "성곽" in r["layer"] or "도성" in r["name"]]

    sec, _ = section(lines, "6.5 방사능 구역")
    rad = []
    for r in rows_of(sec, ["구역", "중심", "등급"]):
        c = re.match(r"C-(\d+)-(\d+)", r["중심"])
        e = {"name": r["구역"], "center": [int(c.group(1)), int(c.group(2))] if c else None, "range": r["반경·범위"],
             "grade": r["등급"], "underground": "지하" in r["중심"]}
        m = re.search(r"반경 (\d+)청크 Rad-(\d)", r["반경·범위"])
        if m:
            e["radius"] = int(m.group(1))
            e["rad"] = int(m.group(2))
        m = re.search(r"중심 (?:1청크 )?Rad-(\d)", r["반경·범위"])
        if m:
            e["core_rad"] = int(m.group(1))
        m = re.search(r"X (\d+)~(\d+) · Y (\d+)~(\d+)", r["반경·범위"])
        if m:
            e["box"] = [int(g) for g in m.groups()]
        rad.append(e)
    w["radiation"] = rad

    sec, _ = section(lines, "8.2 횡단로 확정 목록")
    w["crossings"] = [{"id": r["#"], "name": r["횡단로"], "kind": r["종류"], "ends": r["북단 → 남단"],
                       "state": r["초기 상태(SD-12)"], "owner": r["주인"], "toll": r[[k for k in r if "통행세" in k][0]]}
                      for r in rows_of(sec, ["#", "횡단로", "종류"])]

    places = []
    with open(os.path.join(ROOT, "docs", "seoul-fallout", "maps", "locations.csv"), encoding="utf-8") as f:
        for r in csv.DictReader(f):
            places.append({"lid": r["lid"], "name": r["name"], "type": r["type"], "region": r["region"],
                           "tx": int(r["tx"]), "ty": int(r["ty"]), "threat": int(r["threat"] or 0), "grade": r["grade"],
                           "marker": r["marker"]})
    w["places"] = places

    # 검산(SD-08 §3.2: 광화문 1058,793 · 남산 송신탑 1112,941)
    def tx_of(lon):
        return round((lon - 126.7550) * 4769.46)

    def ty_of(lat):
        return round((37.7080 - lat) * 5999.46)
    if (tx_of(126.9769), ty_of(37.5759)) != (1058, 793):
        errors.append("변환식 검산 실패(광화문)")
    exp = {"peaks": 24, "landmarks": 24, "boundary": 24, "bridges": 25, "rivers": 11, "roads": 14, "crossings": 15, "places": 426}   # 426 = 개요 표 425 + 1-12g 노량진 번개24(L-R01-33)
    for k, n in exp.items():
        if len(w[k]) != n:
            errors.append("%s %d개(기대 %d)" % (k, len(w[k]), n))
    if len(w["rails"]) + len(w["walls"]) != 8:
        errors.append("철도·성곽 %d개(기대 8)" % (len(w["rails"]) + len(w["walls"])))
    os.makedirs(OUT, exist_ok=True)
    json.dump(w, open(os.path.join(OUT, "source.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print("월드 원자료: 권역 청크 %d %s · 고도 격자 %d칸 · 산 %d · 랜드마크 %d · 다리 %d · 하천 %d · 도로 %d · 철도 %d · 성곽 %d · 방사능 %d · 횡단로 %d · 장소 %d | 오류 %d" % (
        len(region), json.dumps(counts, ensure_ascii=False), len(grid), len(w["peaks"]), len(w["landmarks"]), len(w["bridges"]),
        len(w["rivers"]), len(w["roads"]), len(w["rails"]), len(w["walls"]), len(rad), len(w["crossings"]), len(places), len(errors)))
    for e in errors:
        print("  오류:", e)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
