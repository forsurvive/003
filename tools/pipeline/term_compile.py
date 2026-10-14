"""단말 원고 변환기(단계 1-4, SD-12 §7.4 터미널 · §8.3 해킹): script/terms/*.txt → game/data/terminals.json

원고 형식(# 뒤는 주석):
  @term TM-ID 이름            단말 하나(이름은 상호작용 문구 `(E) 단말 이름`)
  skin T1|T2|T3|T4|T5         운영체계 스킨(T1 세진 SJ-OS 녹색 · T2 관제-77 호박색 고정 · T3 볼트-텍 · T4 군용 · T5 중국군)
  lock 0|15|25|50|75|100      해킹 요구 과학(0 = 잠기지 않음). 등급 매우 쉬움~매우 어려움
  theme T1~T4                 해킹 단어 주제군(없으면 스킨이 정한다: T1·T5 → T1, T2 → T2, T3 → T3, T4 → T4)
  key 아이템ID               (선택) 비밀번호 — 가지고 있으면 해킹 없이 열린다
  owner 인물ID                (선택) 소유 단말 — 해킹으로 들어가면 카르마 −5(SD-12 §9.2)
  head 글                     머리 줄(스킨 머리글 뒤에 붙는다, 여러 줄)
  @entry 제목 [cond="식"] [set="식"]
  본문 줄 …                  한 줄 86반칸(한글 2반칸)까지. 비운 줄은 빈 줄
검사: 줄 폭 · 항목 9개 이하 · 식 문법·변수 · 단말 ID 겹침 · 인물 ID.
"""
import os, sys, json, glob, shlex, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import story_expr as SE

SRC = os.path.join(ROOT, "script", "terms")
OUT = os.path.join(ROOT, "game", "data", "terminals.json")
SKINS = {"T1", "T2", "T3", "T4", "T5"}
LOCKS = [0, 15, 25, 50, 75, 100]
THEME_OF = {"T1": "T1", "T2": "T2", "T3": "T3", "T4": "T4", "T5": "T1"}
WIDTH = 86                                   # 한 줄 86반칸(한글 43자) — 528px 화면, 반칸 6px(구현 정합: SD-12 §7.4 "44칸")


def cells(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


def main():
    from script_compile import ENGINE_VARS, FNS
    known_vars = set(json.load(open(os.path.join(ROOT, "game", "data", "vars.json")))["vars"]) | ENGINE_VARS
    for q in json.load(open(os.path.join(ROOT, "game", "data", "quests.json")))["quests"]:
        known_vars |= {q.replace("-", "") + s for s in ("_STAGE", "_RESULT", "_SKIP")}
    npcs = json.load(open(os.path.join(ROOT, "game", "data", "npcs.json")))["npcs"]
    items = set()
    for p in glob.glob(os.path.join(ROOT, "game", "data", "items_*.json")) + [os.path.join(ROOT, "game", "data", "weapons.json")]:
        d = json.load(open(p, encoding="utf-8"))
        if isinstance(d, dict):
            items |= {k for k in d if not k.startswith("_")}
            for v in d.values():                                         # {"weapons": {...}} 꼴
                if isinstance(v, dict) and all(isinstance(x, dict) for x in v.values()):
                    items |= set(v.keys())
    errors, terms = [], {}

    def check(src, where, effect):
        try:
            ast = SE.parse(src)
        except SyntaxError as e:
            errors.append(f"{where} 식 구문: {src} — {e}")
            return
        vs, calls = SE.names(ast)
        bad = [v for v in vs if v not in known_vars] + [f + "()" for f in calls if f not in FNS]
        if bad:
            errors.append(f"{where} 모르는 이름 {bad}")
        if not effect and any(isinstance(s, list) and s[0] == "set" for s in ast[1:]):
            errors.append(f"{where} 조건식에 대입이 있다: {src}")

    for path in sorted(glob.glob(os.path.join(SRC, "*.txt"))):
        rel = os.path.relpath(path, ROOT)
        cur, ent = None, None
        for n, raw in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
            where = f"{rel}:{n}"
            line = raw.rstrip()
            if line.lstrip().startswith("#"):
                continue
            if line.startswith("@term"):
                parts = line.split(None, 2)
                if len(parts) < 3:
                    errors.append(f"{where} @term ID 이름")
                    continue
                tid = parts[1]
                if tid in terms:
                    errors.append(f"{where} 단말 ID 겹침 {tid}")
                cur = {"name": parts[2].strip(), "skin": "T1", "lock": 0, "theme": "", "key": "", "owner": "", "head": [], "entries": []}
                terms[tid] = cur
                ent = None
                continue
            if cur is None:
                if line.strip():
                    errors.append(f"{where} @term 앞에 글이 있다")
                continue
            if line.startswith("@entry"):
                try:
                    words = shlex.split(line[6:])
                except ValueError as e:
                    errors.append(f"{where} 따옴표: {e}")
                    continue
                title = " ".join(w for w in words if "=" not in w)
                opt = dict(w.split("=", 1) for w in words if "=" in w)
                ent = {"title": title, "body": [], "cond": opt.get("cond", ""), "set": opt.get("set", "")}
                if ent["cond"]:
                    check(ent["cond"], where, False)
                if ent["set"]:
                    check(ent["set"], where, True)
                if cells(title) > WIDTH - 4:
                    errors.append(f"{where} 항목 제목이 길다({cells(title)}칸)")
                cur["entries"].append(ent)
                if len(cur["entries"]) > 9:
                    errors.append(f"{where} 항목이 9개를 넘는다")
                continue
            if ent is not None:
                if cells(line) > WIDTH:
                    errors.append(f"{where} 줄이 {WIDTH}칸을 넘는다({cells(line)}칸): {line}")
                ent["body"].append(line)
                continue
            if not line.strip():
                continue
            k, _, v = line.strip().partition(" ")
            v = v.strip()
            if k == "skin":
                if v not in SKINS:
                    errors.append(f"{where} 모르는 스킨 {v}")
                cur["skin"] = v
            elif k == "lock":
                if not v.isdigit() or int(v) not in LOCKS:
                    errors.append(f"{where} lock은 {LOCKS} 중 하나")
                else:
                    cur["lock"] = int(v)
            elif k == "theme":
                if v not in ("T1", "T2", "T3", "T4"):
                    errors.append(f"{where} 모르는 주제군 {v}")
                cur["theme"] = v
            elif k == "key":
                if v not in items:
                    errors.append(f"{where} 모르는 아이템 {v}")
                cur["key"] = v
            elif k == "owner":
                if v not in npcs:
                    errors.append(f"{where} 모르는 인물 {v}")
                cur["owner"] = v
            elif k == "head":
                if cells(v) > WIDTH:
                    errors.append(f"{where} 머리 줄이 {WIDTH}칸을 넘는다")
                cur["head"].append(v)
            else:
                errors.append(f"{where} 모르는 줄 '{k}'")
    for tid, t in terms.items():
        if not t["theme"]:
            t["theme"] = THEME_OF[t["skin"]]
        if not t["entries"]:
            errors.append(f"{tid}: 항목이 없다")
        for e in t["entries"]:
            while e["body"] and not e["body"][-1].strip():
                e["body"].pop()
    for e in errors:
        print("오류", e)
    if errors:
        sys.exit(1)
    json.dump({"terms": terms}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
    print(f"단말: {len(terms)}대 · 항목 {sum(len(t['entries']) for t in terms.values())}")


if __name__ == "__main__":
    main()
