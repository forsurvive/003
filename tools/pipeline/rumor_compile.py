"""소문 원고(script/world/rumors.txt, 1-4f) → game/data/rumors.json.
머리 줄 '@ 권역 | 조건', 다음 줄 = 한 줄 소문. 조건 식은 이야기 식 문법·변수 이름을 검사한다(map_compile.check_cond)."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_compile as MC
from script_compile import ENGINE_VARS

ROOT = MC.ROOT
SRC = os.path.join(ROOT, "script", "world", "rumors.txt")
OUT = os.path.join(ROOT, "game", "data", "rumors.json")
REGIONS = {"R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11", "UG", "HR", "*"}


def main():
    known_vars = set(json.load(open(os.path.join(ROOT, "game", "data", "vars.json")))["vars"]) | ENGINE_VARS
    for q in json.load(open(os.path.join(ROOT, "game", "data", "quests.json")))["quests"]:
        known_vars |= {q.replace("-", "") + s for s in ("_STAGE", "_RESULT", "_SKIP")}
    known_fns = set(__import__("script_compile").FNS)                                          # 원고 함수 목록은 script_compile.FNS 한 곳(1-X — 컴파일러마다 따로 두면 새 함수를 모른다)
    out, errs, head = [], [], None
    for i, ln in enumerate(open(SRC, encoding="utf-8").read().split("\n"), 1):
        s = ln.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("@"):
            parts = [p.strip() for p in s[1:].split("|", 1)]
            where, cond = parts[0], (parts[1] if len(parts) > 1 else "")
            if where not in REGIONS:
                errs.append(f"{i}: 모르는 권역 '{where}'")
            if cond:
                try:
                    MC.check_cond(cond, known_vars, known_fns)
                except Exception as e:
                    errs.append(f"{i}: 조건 오류 {e}")
            head = (where, cond)
        elif head is None:
            errs.append(f"{i}: 머리 줄(@ 권역 | 조건) 없이 나온 소문")
        else:
            out.append({"where": head[0], "cond": head[1], "text": s})
            head = None
    for e in errs:
        print("오류 rumors.txt:" + e)
    if errs:
        sys.exit(1)
    json.dump({"rumors": out}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(f"소문: {len(out)}줄 (조건 붙음 {sum(1 for r in out if r['cond'])})")


if __name__ == "__main__":
    main()
