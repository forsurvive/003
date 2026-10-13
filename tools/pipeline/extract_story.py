"""데이터 파이프라인 v1 — 이야기 자료 (SD-19 §6.12 단계 0 대상). 손 입력 0.
기획서 표 → game/data/vars.json(변수 선언) · npcs.json(인물) · quests.json(퀘스트 단계).
  변수: SD-03a §4.2 지식 플래그·§4.3 세계 상태·§4.6 인도처·§4.7 전체 변수표의 `이름`, SD-06 §3.2 호감도(시작값),
        SD-18 §9.1.4 주인공 이름 변수(문자열), 퀘스트마다 <키>_STAGE·_RESULT·_SKIP(정수 0).
  인물: SD-07b §4 권역 표(ID · 이름 · 성·나이 · 종 · 세력 · 장소 · 역할 · 외형 코드).
  퀘스트: SD-03a §7·§8 퀘스트 절의 '단계 | 퀘스트 로그 | 완료 조건' 표.
오류는 '문서 · 줄 · 기대값'으로 보고하고 종료 코드 1."""
import os, re, sys, json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract import tables, DOCS, OUT

REPORT = []


def err(doc, line, msg):
    REPORT.append(f"오류 {doc}:{line} {msg}")


def doc(name):
    return os.path.join(DOCS, name)


VAR_RE = re.compile(r"`([A-Z][A-Z0-9_]*)`")


def extract_vars():
    out = {}
    src = "03a_main-story-part1.md"
    want = ("### 4.2", "### 4.3", "### 4.6", "### 4.7")
    for section, line, header, rows in tables(doc(src)):
        if not section.startswith(want):
            continue
        col = 1 if section.startswith("### 4.7") else 0           # 4.7은 '분류 | 변수 | 개수 | 비고'
        for ln, cells in rows:
            if len(cells) <= col:
                continue
            for name in VAR_RE.findall(cells[col]):
                if name.startswith(("AFF_", "NODE_", "INF_")) or name in ("MQxxx_STAGE", "MQxxx_RESULT"):
                    continue
                out[name] = {"type": "int", "default": 0, "src": f"{src}:{ln}"}
    # 호감도(SD-06 §3.2.1 대상 10개, §3.2.2 정착지 12곳): 시작값
    src = "06_factions.md"
    for section, line, header, rows in tables(doc(src)):
        if section.startswith("#### 3.2.1") and "변수" in header:
            vi, si = header.index("변수"), header.index("시작값")
            for ln, cells in rows:
                name = cells[vi].strip("` ")
                m = re.match(r"^[+-]?\d+", cells[si].replace("+", ""))
                if re.match(r"^AFF_[A-Z]+$", name):
                    out[name] = {"type": "int", "default": int(m.group()) if m else 0, "src": f"{src}:{ln}"}
        if section.startswith("#### 3.2.2") and "약호" in header and "시작값" in header:
            ai, si = header.index("약호"), header.index("시작값")
            for ln, cells in rows:
                code = cells[ai].strip()
                m = re.match(r"^[+-]?\d+", cells[si].replace("+", ""))
                if re.match(r"^[A-Z]{2}$", code):
                    out["AFF_JC_" + code] = {"type": "int", "default": int(m.group()) if m else 0, "src": f"{src}:{ln}"}
    # 주인공 이름 변수(SD-18 §9.1.4)
    src = "18_naming-terms.md"
    for i, l in enumerate(open(doc(src), encoding="utf-8").read().split("\n")):
        if l.startswith("| 변수 |") and "P_SURNAME" in l:
            for name in VAR_RE.findall(l):
                out[name] = {"type": "str", "default": "", "src": f"{src}:{i + 1}"}
    if "V_KARMA" not in out:
        err("03a_main-story-part1.md", 0, "V_KARMA가 변수표에 없다")
    return out


ID_RE = re.compile(r"\b([CN]-[A-Z0-9]+(?:-[0-9]+)?)\b")


def extract_npcs():
    out = {}
    src = "07b_npc-directory.md"
    for section, line, header, rows in tables(doc(src)):
        if header[:2] != ["ID", "이름"] or "외형 코드(통일안)" not in header:
            continue
        hi = {h: i for i, h in enumerate(header)}
        for ln, cells in rows:
            if len(cells) < len(header):
                err(src, ln, f"열 수 {len(cells)} < {len(header)}")
                continue
            idcell = re.sub(r"\(.*?\)", "", cells[hi["ID"]])        # 괄호 안 결번 메모 제외
            ids = ID_RE.findall(idcell)
            if not ids:
                err(src, ln, f"ID 형식: {cells[0]}")
                continue
            sexage = cells[hi["성·나이"]]
            m = re.match(r"(남|여|수컷|암컷)?\s*(\d+)?", sexage)
            raw = cells[hi["이름"]].replace("**", "").strip()
            disp = raw.split("←")[0].strip()                         # '←옛 이름' 주석은 표시 이름에서 뺀다
            nick = re.match(r"^(.+?)\('(.+?)'\)$", disp)                 # 등록 성명('통칭') → 화면에는 통칭(SD-07a C-027 '지우')
            rec = {"name": nick.group(2) if nick else disp, "name_full": nick.group(1) if nick else disp, "ids": ids,
                   "sex": (m.group(1) or "") if m else "", "age": int(m.group(2)) if m and m.group(2) else 0,
                   "species": cells[hi["종"]], "faction": cells[hi["세력"]].split("·")[0].strip(),
                   "place": cells[hi["장소"]], "role": cells[hi["역할"]], "look": cells[hi["외형 코드(통일안)"]],
                   "src": f"{src}:{ln}"}
            for i in ids:
                if i in out and out[i]["name"] != rec["name"]:
                    err(src, ln, f"ID 중복 {i}: {out[i]['name']} / {rec['name']}")
                out[i] = rec
    return out


QHEAD = re.compile(r"^### \d+\.\d+ (MQ-[A-Z0-9]+) (.+)$")


def extract_quests():
    out = {}
    src = "03a_main-story-part1.md"
    for section, line, header, rows in tables(doc(src)):
        m = QHEAD.match(section)
        if not m or header[:3] != ["단계", "퀘스트 로그", "완료 조건"]:
            continue
        qid, title = m.group(1), m.group(2).strip()
        stages = {}
        for ln, cells in rows:
            s = cells[0].replace("**", "").strip()
            if not s.isdigit():
                err(src, ln, f"단계 번호가 숫자가 아니다: {s}")
                continue
            stages[s] = {"log": cells[1].replace("**", "").strip(), "done": cells[2].strip(), "src": f"{src}:{ln}"}
        out[qid] = {"key": qid.replace("-", ""), "title": title, "stages": stages}
    for need in ("MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"):
        if need not in out:
            err(src, 0, f"단계 표가 없다: {need}")
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    quests = extract_quests()
    vars_ = extract_vars()
    for q in quests.values():
        for suf in ("_STAGE", "_RESULT", "_SKIP"):
            vars_.setdefault(q["key"] + suf, {"type": "int", "default": 0, "src": "quests"})
    npcs = extract_npcs()
    dump = lambda name, obj: json.dump(obj, open(os.path.join(OUT, name), "w", encoding="utf-8"), ensure_ascii=False, indent=1,
                                       sort_keys=True)
    dump("vars.json", {"vars": vars_})
    dump("quests.json", {"quests": quests})
    dump("npcs.json", {"npcs": npcs})
    rep = [f"이야기 자료 v1: 변수 {len(vars_)}, 퀘스트 {len(quests)}, 인물 ID {len(npcs)}"] + REPORT
    open(os.path.join(OUT, "_story_report.txt"), "w", encoding="utf-8").write("\n".join(rep) + "\n")
    print(rep[0], "| 오류", len(REPORT))
    for r in REPORT[:20]:
        print(" ", r)
    return 1 if REPORT else 0


if __name__ == "__main__":
    sys.exit(main())
