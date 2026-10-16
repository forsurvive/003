"""데이터 파이프라인 v0 (SD-19 §6.12): 기획서 마크다운 표 → 검증 → game/data/*.json.
표마다 스키마(schemas/*.yaml: 문서·절·ID 열·열 이름→필드·타입·패턴·필수)를 두고 행 단위로 읽는다.
오류는 '문서 · 절 · 행 · 열 · 기대값'으로 보고하고, 문서에 없는 필드(gaps)는 기본값을 쓰되 정합 목록에 따로 적는다.
python3 tools/pipeline/extract.py   (오류가 있으면 종료 코드 1, 손 입력 0)"""
import os, re, sys, json, glob
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOCS = os.path.join(ROOT, "docs", "seoul-fallout")
OUT = os.path.join(ROOT, "game", "data")
SCHEMAS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "schemas")


def tables(path):
    """yield (section heading, line number, header list, [(line, cells)]) for every pipe table in a markdown file."""
    lines = open(path, encoding="utf-8").read().split("\n")
    section, i = "", 0
    while i < len(lines):
        l = lines[i]
        if l.startswith("#"):
            section = l.strip()
        if l.startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s\-:|]+\|$", lines[i + 1].strip()):
            header = [c.strip() for c in l.strip().strip("|").split("|")]
            rows, j = [], i + 2
            while j < len(lines) and lines[j].startswith("|"):
                rows.append((j + 1, [c.strip() for c in lines[j].strip().strip("|").split("|")]))
                j += 1
            yield section, i + 1, header, rows
            i = j
            continue
        i += 1


NUM = re.compile(r"-?\d+(?:\.\d+)?")


def convert(raw, typ):
    s = raw.replace("**", "").strip()
    if typ in ("str", "id"):
        return s
    if typ == "int":
        return int(s.replace(",", ""))
    if typ == "float":
        return float(s.replace(",", ""))
    if typ == "int_or_none":
        return None if s in ("—", "-", "") else int(s.split()[0])
    if typ == "lead_number":                 # '18 + 전기 2/초(4초)' -> 18, '20(떼)' -> 20, '물기 3' -> 3
        m = NUM.search(s)
        if not m:
            raise ValueError("숫자가 없다")
        return float(m.group()) if "." in m.group() else int(m.group())
    if typ == "percent":
        return float(s.rstrip("%")) / 100.0
    if typ == "mult":
        return float(s.lstrip("×x"))
    raise ValueError(f"알 수 없는 타입 {typ}")


class Report:
    def __init__(self):
        self.errors, self.gaps, self.checks = [], [], []

    def err(self, doc, sec, line, col, msg):
        self.errors.append(f"{doc} · {sec} · {line}행 · {col} · {msg}")


def run_schema(path, rep):
    sch = yaml.safe_load(open(path, encoding="utf-8"))
    doc = sch["doc"]
    want = sch["rows"]
    found = {}
    for sec, tline, header, rows in tables(os.path.join(DOCS, doc)):
        if sch.get("section") and sec != sch["section"]:
            continue
        if sch.get("sections") and not any(sec.startswith(x) for x in sch["sections"]):   # 1-4: 여러 절(머리말 앞부분)
            continue
        if sch["id_column"] not in header:
            continue
        idx = {h: k for k, h in enumerate(header)}
        for line, cells in rows:
            if len(cells) != len(header):
                continue
            rid = cells[idx[sch["id_column"]]].replace("**", "")
            if want != "all" and rid not in want:
                continue
            if sch.get("id_filter") and not re.match(sch["id_filter"], rid):   # 표 전체를 뽑을 때 ID 모양이 다른 행(범위 줄 등)은 건너뛴다
                continue
            rec = {"_src": f"{doc}:{line}"}
            for col, spec in sch["columns"].items():
                if col not in idx:
                    continue
                raw = cells[idx[col]]
                if raw.strip() in ("—", "-", "–", "") and not spec.get("required"):   # 빈 칸(1-4: 표 전체 추출)
                    continue
                try:
                    v = convert(raw, spec["type"])
                except Exception as e:
                    rep.err(doc, sec, line, col, f"'{raw}' → {spec['type']} 변환 실패 ({e})")
                    continue
                if spec.get("pattern") and not re.match(spec["pattern"], str(v)):
                    rep.err(doc, sec, line, col, f"'{v}' 가 패턴 {spec['pattern']}에 맞지 않음")
                rec[spec["field"]] = v
                if spec.get("raw"):                                           # 1-9a: 같은 칸의 원문도 남긴다('40 (5×8)' → 펠릿 수 · '10 + 폭발 60' → 폭발 피해)
                    rec[spec["raw"]] = raw.replace("**", "").strip()
            for col, spec in sch["columns"].items():
                if spec.get("required") and spec["field"] not in rec:
                    rep.err(doc, sec, line, col, "필수 열 없음")
            key = str(rec.get(sch["columns"][sch["id_column"]]["field"]))
            if key in found:
                rep.err(doc, sec, line, sch["id_column"], f"ID 중복 {key} (앞: {found[key]['_src']})")
            found[key] = rec
    if want != "all":
        for rid in want:
            if rid not in found:
                rep.err(doc, "-", "-", sch["id_column"], f"{rid} 행을 찾지 못함")
    # 행에 빈 칸이 있어도 식이 돌게: 숫자 열은 0, 글 열은 ""(1-4: 표 전체를 뽑으면서 빈 칸이 생긴다)
    blank = {spec["field"]: (0 if spec["type"] in ("int", "float", "lead_number", "int_or_none") else "") for spec in sch["columns"].values()}
    blank.update({spec["raw"]: "" for spec in sch["columns"].values() if spec.get("raw")})

    class _Env(dict):
        def __missing__(self, k):
            if k in blank:
                return blank[k]
            raise KeyError(k)

    env_fn = lambda rec: _Env(rec, note_number=lambda pre, d: _note_number(rec.get("note", ""), pre, d),
                              num_in=lambda text, pre, d: _note_number(text, pre, d))
    for rec in found.values():
        for f, expr in (sch.get("derive") or {}).items():
            rec[f] = eval(expr, {"__builtins__": {}, "str": str, "round": round}, env_fn(rec))
        for f, g in (sch.get("gaps") or {}).items():
            if g.get("only_missing") and f in rec:
                continue
            v = eval(g["default"], {"__builtins__": {}, "round": round}, env_fn(rec))
            if v is None and g.get("skip_none"):                           # 이 행에는 채우지 않는다(보스 한 마리만 채우는 gaps)
                continue
            rec[f] = v
            rep.gaps.append(f"{doc} {rec.get('id', '')} · {f} = {rec[f]!r} — {g['why']}")
        for f, expr in (sch.get("check") or {}).items():
            exp = eval(expr, {"__builtins__": {}}, rec)
            if rec.get(f) != exp:
                rep.err(doc, sch.get("section", "-"), rec["_src"].split(":")[1], f, f"표 값 {rec.get(f)} ≠ 공식 값 {exp}")
            else:
                rep.checks.append(f)
    return os.path.splitext(os.path.basename(path))[0], found


def _note_number(note, prefix, default):
    m = re.search(re.escape(prefix) + r"(\d+(?:\.\d+)?)", note or "")
    return float(m.group(1)) if m else default


def main():
    rep = Report()
    os.makedirs(OUT, exist_ok=True)
    outputs = {}
    for p in sorted(glob.glob(os.path.join(SCHEMAS, "*.yaml"))):
        name, recs = run_schema(p, rep)
        outputs[name] = recs
    if rep.errors:
        print("데이터 빌드 실패:")
        for e in rep.errors:
            print("  " + e)
        return 1
    for name, recs in outputs.items():
        with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as fh:
            json.dump(recs, fh, ensure_ascii=False, sort_keys=True, indent=1)
    with open(os.path.join(OUT, "_report.txt"), "w", encoding="utf-8") as fh:
        fh.write("데이터 빌드 v0 — 오류 0\n")
        fh.write("".join(f"  {n}: {len(r)}행\n" for n, r in outputs.items()))
        fh.write(f"공식 대조 통과: {len(rep.checks)}칸\n정합 목록(문서에 없는 필드, 기본값 사용):\n")
        fh.write("".join(f"  - {g}\n" for g in rep.gaps))
    print(open(os.path.join(OUT, "_report.txt"), encoding="utf-8").read())
    return 0


if __name__ == "__main__":
    sys.exit(main())
