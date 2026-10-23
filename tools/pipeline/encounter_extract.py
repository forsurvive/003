"""인카운터 자료 추출(단계 1-3, SD-05 §6 스폰 규칙 · SD-08 §14.3 위협도 격자): game/data/world/encounters.json
- threat: 청크별 기본 위협도(53×43 글자 격자 — `.` 놀이 밖 · `~` 위협 3 이하 한강 수면 · 숫자 1~5)
- ep: 고정 지점 EP(SD-05 §6.5 표) — 위치는 장소 L-ID(장소 표 좌표) · 청크 C-x-y(가운데) 순으로 풀고, 못 푼 것(P·X 코드, 서술만)은 건너뛴다.
  종류(1회 ★ · 반복 72시간 · 상시), 판정 확률(기본 · 밤 · 수배 n+ 조건 · 시간대), 연결 RE.
- settlements: 정착지(장소 유형 '정착지') 좌표 — 반경 2청크 안은 이동 판정 없음(SD-05 §6.2).
- chance: 위협도 → [판정 주기(청크 수), 1회 확률](SD-05 §6.2 표)
python3 tools/pipeline/encounter_extract.py
"""
import os, re, sys, json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract import tables

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOCS = os.path.join(ROOT, "docs", "seoul-fallout")
OUT = os.path.join(ROOT, "game", "data", "world", "encounters.json")
errors, skipped = [], []


def threat_grid():
    lines = open(os.path.join(DOCS, "08_world-regions.md"), encoding="utf-8").read().split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("### 14.3"))
    while not lines[i].startswith("```"):
        i += 1
    rows = []
    for l in lines[i + 3:]:                                               # 머리 두 줄(열 번호) 다음부터
        if l.startswith("```"):
            break
        m = re.match(r"^(\d\d)\s+(\S+)$", l)
        if not m:
            errors.append("08:%d 격자 줄 형식: %s" % (i, l))
            continue
        rows.append(m.group(2))
    if len(rows) != 43 or any(len(r) != 53 for r in rows):
        errors.append("위협도 격자 크기 %d×%s ≠ 53×43" % (len(rows), {len(r) for r in rows}))
    return rows


def chance_table():
    out = {}
    for sec, ln, head, rows in tables(os.path.join(DOCS, "05_misc-quests-encounters.md")):
        if sec.startswith("### 6.2") and head[:3] == ["위협도", "판정 주기", "1회 발생 확률"]:
            for _ln, c in rows:
                out[c[0]] = [int(re.match(r"(\d)", c[1]).group(1)), int(c[2].rstrip("%")) / 100.0]
    if len(out) != 5:
        errors.append("위협도별 확률 표 %d행" % len(out))
    return out


def eps(places):
    out = []
    for sec, ln, head, rows in tables(os.path.join(DOCS, "05_misc-quests-encounters.md")):
        if not (sec.startswith("### 6.5") and head[:2] == ["EP", "위치(L-ID·청크)"]):
            continue
        for ln2, c in rows:
            eid, where, kind, rule = c[0], c[1], c[2], c[3]
            pos = None
            m = re.search(r"L-([A-Z0-9]+-\d+)", where)
            if m and ("L-" + m.group(1)) in places:
                p = places["L-" + m.group(1)]
                pos = [p["tx"], p["ty"]]
            else:
                m = re.search(r"C-(\d+)-(\d+)", where)
                if m:
                    pos = [int(m.group(1)) * 40 + 20, int(m.group(2)) * 40 + 20]
            if pos is None:
                skipped.append(eid)
                continue
            once = "★" in kind or rule.startswith("1회")
            e = {"id": eid, "where": where, "kind": kind.replace("★", "").strip(), "pos": pos, "once": once,
                 "repeat": "(반복)" in kind or (not once and "상시" not in rule), "re": re.findall(r"RE-\d+", rule), "rule": rule,
                 "src": "05_misc-quests-encounters.md:%d" % ln2}
            pm = re.findall(r"(\d+)%", rule)
            e["p"] = int(pm[0]) / 100.0 if pm else (1.0 if "상시" in rule else 0.0)
            nm = re.search(r"밤\s*(?:\+)?(\d+)%", rule)
            if nm:
                e["p_night"] = int(nm.group(1)) / 100.0
                if rule.strip().startswith("밤"):                      # '밤 50%'만 있으면 밤에만
                    e["night_only"] = True
            wm = re.search(r"수배\s*(\d)\+", rule)
            if wm:
                e["wanted_min"] = int(wm.group(1))
            hm = re.search(r"(\d\d)~(\d\d)시", rule)
            if hm:
                e["hours"] = [int(hm.group(1)), int(hm.group(2))]
            e.update(EP_FIX.get(eid, {}))
            out.append(e)
    return out


## 구현 정합 덧붙임(정본 표에 없는 조건 — 이유와 함께)
EP_FIX = {
    "EP-R01-03": {"cond": "KC_STATE != 0", "p": 0.2, "p_night": 0.3,          # 1-13a3: 깡철이가 마당을 쥔 동안엔 그 패거리가 곧 매복(진행기 kc_boss) — 겹쳐 뜨지 않는다.
                  "fix": "깡철이 결말 뒤에만 · 확률 절반(SD-05 RE-002 '두목 처리 뒤 ×0.5')"},  # 결말 뒤엔 흩어진 졸개가 가끔 돌아온다
}


def main():
    places = json.load(open(os.path.join(ROOT, "game", "data", "world", "places.json"), encoding="utf-8"))
    grid = threat_grid()
    ch = chance_table()
    ep = eps(places)
    sett = sorted([[lid, p["tx"], p["ty"]] for lid, p in places.items() if p["type"] == "정착지" and p["region"] not in ("UG",)])
    json.dump({"threat": grid, "chance": ch, "ep": ep, "settlements": sett}, open(OUT, "w", encoding="utf-8"),
              ensure_ascii=False, separators=(",", ":"))
    print("인카운터 자료: 위협도 격자 %d×%d · 확률 표 %d · EP %d(위치 못 푼 것 %d: %s) · 정착지 %d | 오류 %d" % (
        len(grid[0]) if grid else 0, len(grid), len(ch), len(ep), len(skipped), " ".join(skipped[:12]), len(sett), len(errors)))
    for e in errors:
        print("  오류:", e)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
