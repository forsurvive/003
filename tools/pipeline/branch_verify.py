"""분기 자동 검증 v1(단계 1-13b, SD-19 §10.2 · 계획 docs/seoul-fallout/_plans/1-13_closing_plan.md §2) — 대화 자료(game/data/dialogue/*.json)를
프로필(막 · 세력 호감 구간 · 카르마 · 핵심 인물 생사 · 캡 · 시각)마다 장면 START부터 따라간다. 효과(`!`)는 그 프로필의 변수에 적용하고, 조건(`?`)이
정해지지 않으면(진행기 · 함수가 정하는 값) 두 길을 다 간다.

검사(도구가 후보를 내고 사람이 판정 — SD-25와 같은 틀):
  ① 닿지 않는 라벨 — 정적: 어떤 이동 · 조건 · 선택도 가리키지 않고 앞에서 흘러 들어오지도 않는 라벨(실패) / 동적: 어느 프로필에서도 닿지 않는 라벨(주의)
  ② 막힘 — 그 자리에 닿았는데 선택지가 모두 닫힘(보이는 조건 거짓 · [캡] · [물건] · [증거] · [능력치] · [스킬]이 모자람, 화술처럼 실패 길이 있는 것은 열림)(실패)
     끝없는 고리 — 대사 · 선택 없이 이동 · 조건 · 효과 · 명령만 도는 고리(실패)
  ⑥ 호감 한 번 변화가 ±25를 넘는 효과(주의 — SD-06 §3 한 사건 폭)
  ④ 미선언 변수 · ⑩ 진영 결정 문형은 원고 변환기(script_compile.py)가, ⑦ 같은 변수 다른 뜻은 교차 표(quest_cross.py)가 맡는다.
진행기(GDScript) 안의 분기는 대상 밖 — 시험 · 봇 몫(보고서 머리에 적는다).

결과: game/data/_branch_report.md · .json. 허용: tools/pipeline/branch_verify_allow.yaml("검사|장면|자리": 이유). 새 실패 0이 통과.
python3 tools/pipeline/branch_verify.py   (build_data.sh에 들어 있다)"""
import os, sys, json, glob, re

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import story_expr as SE

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "game", "data")
DLG = os.path.join(DATA, "dialogue")
ALLOW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "branch_verify_allow.yaml")
STEP_CAP = 4000                                                          # 장면 하나 · 프로필 하나에서 따라가는 걸음 상한
AFF_STEP = 25

# 프로필 축(하나씩 바꾼다 — v1은 '기준 + 한 축 변주'; 쌍별 조합은 v2)
AFFS = ["AFF_BJ", "AFF_SB", "AFF_JH", "AFF_GS", "AFF_JC_BC", "AFF_JC_SA", "AFF_YH"]
KEY_NPCS = ["C-010", "C-013", "C-014", "C-049", "C-050", "C-053", "C-057", "N-R01-028", "N-R01-030", "N-R01-026", "N-R02-001", "C-015"]
BASE = {"V_ACT": 1, "GAME_DAY": 3, "GAME_HOUR": 12, "GAME_WDAY": 3, "V_KARMA": 0, "PC_CAPS": 0, "MQ101_STAGE": 100}


def load(p):
    return json.load(open(p, encoding="utf-8"))


def allow_list():
    out = {}
    if os.path.exists(ALLOW):
        for line in open(ALLOW, encoding="utf-8"):
            m = re.match(r'^"(.+?)":\s*(.+)$', line.strip())
            if m:
                out[m.group(1)] = m.group(2).strip().strip('"')
    return out


def profiles(defaults):
    base = dict(defaults)
    base.update(BASE)
    out = [("기준", base, set(), 0)]
    for a in AFFS:
        for val, tag in ((-80, "적대"), (60, "우호")):
            p = dict(base)
            p[a] = val
            out.append(("%s %s" % (a, tag), p, set(), 0))
    for k, tag in ((-600, "악"), (600, "선")):
        p = dict(base)
        p["V_KARMA"] = k
        out.append(("카르마 " + tag, p, set(), 0))
    p = dict(base)
    p["PC_CAPS"] = 5000
    out.append(("캡 넉넉", p, set(), 5000))
    for h in (3, 21):
        p = dict(base)
        p["GAME_HOUR"] = h
        out.append(("%d시" % h, p, set(), 0))
    for n in KEY_NPCS:
        out.append(("%s 사망" % n, dict(base), {n}, 0))
    p = dict(base)
    p["V_ACT"] = 2
    out.append(("2막", p, set(), 0))
    return out


class Unknown(Exception):
    pass


def fns_for(dead):
    def unk(*_a):
        raise Unknown()
    f = {k: unk for k in ("stage", "result", "met", "worn", "blade", "killer_known", "confess", "victim", "rq", "rq_wait", "rq_left", "rq_stage", "talk_n",
                          "wanted", "stat", "skill", "year", "has")}
    f["dead"] = lambda i: 1 if i in dead else 0
    f["known_dead"] = lambda i: 1 if i in dead else 0
    for k in ("karma", "aff", "quest", "give", "take", "caps", "xp"):
        f[k] = (lambda *a: 0)
    return f


class Env(dict):
    def __init__(self, base, defaults):
        super().__init__(base)
        self.defaults = defaults

    def __missing__(self, k):
        return self.defaults.get(k, 0)


def test(cond, env, fns):
    """참 · 거짓 · None(정해지지 않음)"""
    if not cond:
        return True
    try:
        return SE._truthy(SE.evaluate(SE.parse(cond), Env(env, env.defaults) if isinstance(env, Env) else env, fns))
    except (Unknown, KeyError, ZeroDivisionError, TypeError, ValueError):
        return None


def apply(fx, env, fns):
    if not fx:
        return
    try:
        SE.evaluate(SE.parse(fx), env, fns)
    except (Unknown, KeyError, ZeroDivisionError, TypeError, ValueError):
        pass


def opt_open(o, env, fns, caps):
    """선택지가 열려 있나: 보이는 조건 · 태그(실패 길이 있는 판정은 늘 열림)"""
    vis = test(o.get("cond", ""), env, fns)
    if vis is False:
        return False
    for tg in o.get("tags", []):
        k = tg.get("k")
        if k == "caps" and int(tg.get("n", 0)) > caps:
            return False
        if k in ("item", "evidence", "stat", "skill") and not o.get("fail"):
            return False                                                   # 물건 · 증거 · 능력치 · 스킬 문턱: 가장 모자란 사람에게는 닫힌다
    return True


def walk(scene, env0, dead, caps, reached, stuck, starts=(0,)):
    ops = scene["ops"]
    labels = scene["labels"]
    fns = fns_for(dead)
    stack = [(i, env0) for i in starts]
    seen = set()
    steps = 0
    while stack and steps < STEP_CAP:
        i, env = stack.pop()
        while 0 <= i < len(ops) and steps < STEP_CAP:
            steps += 1
            key = (i, tuple(sorted((k, v) for k, v in env.items() if k not in env0 or env0[k] != v)))
            if key in seen:
                break
            seen.add(key)
            for lb, at in labels.items():
                if at == i:
                    reached.add(lb)
            op = ops[i]
            k = op["op"]
            if k == "end":
                break
            if k == "goto":
                if op["to"] == "END":
                    break
                i = labels.get(op["to"], len(ops))
                continue
            if k == "if":
                r = test(op["cond"], env, fns)
                if r is None:
                    stack.append((labels.get(op["to"], len(ops)), Env(dict(env), env.defaults)))
                    i += 1
                elif r:
                    if op["to"] == "END":
                        break
                    i = labels.get(op["to"], len(ops))
                else:
                    i += 1
                continue
            if k == "do":
                env = Env(dict(env), env.defaults)
                apply(op["fx"], env, fns)
                i += 1
                continue
            if k == "choice":
                opts = [o for o in op["opts"] if opt_open(o, env, fns, caps)]
                if not opts:
                    stuck.add(i)
                    break
                for o in opts:
                    e2 = Env(dict(env), env.defaults)
                    apply(o.get("fx", ""), e2, fns)
                    for to in [o["to"]] + ([o["fail"]] if o.get("fail") else []):
                        if to != "END":
                            stack.append((labels.get(to, len(ops)), e2))
                break
            i += 1
    return steps >= STEP_CAP


def code_entries():
    """진행기가 장면을 라벨부터 여는 입구(play_scene(id, "LABEL") · _cut(…, "LABEL")): 코드에 따옴표로 적힌 대문자 낱말"""
    out = set()
    for f in glob.glob(os.path.join(ROOT, "game", "**", "*.gd"), recursive=True):
        if "/tests/" in f:
            continue
        out |= set(re.findall(r'"([A-Z][A-Z0-9_]{2,})"', open(f, encoding="utf-8").read()))
    return out


def static_checks(scene, entries=frozenset()):
    """정적: 아무도 가리키지 않고 흘러 들어오지도 않는 라벨 · 대사 · 선택 없이 도는 고리"""
    ops = scene["ops"]
    labels = scene["labels"]
    targets = set()
    for op in ops:
        if op["op"] in ("goto", "if"):
            targets.add(op["to"])
        elif op["op"] == "choice":
            for o in op["opts"]:
                targets.add(o["to"])
                if o.get("fail"):
                    targets.add(o["fail"])
    orphans = []
    for lb, at in labels.items():
        if lb == "START" or lb in targets or lb in entries:
            continue
        prev = ops[at - 1]["op"] if at > 0 else "end"
        if prev in ("goto", "end", "choice"):
            orphans.append(lb)
    loops = []
    nxt = {}
    for i, op in enumerate(ops):                                           # 말 없는 칸만 잇는 그래프
        k = op["op"]
        if k in ("line", "choice", "end"):
            continue
        if k == "goto":
            nxt[i] = [labels.get(op["to"], -1)] if op["to"] != "END" else []
        elif k == "if":
            nxt[i] = [labels.get(op["to"], -1), i + 1] if op["to"] != "END" else [i + 1]
        else:
            nxt[i] = [i + 1]
    color = {}
    def dfs(u, path):
        color[u] = 1
        for v in nxt.get(u, []):
            if v not in nxt:
                continue
            if color.get(v) == 1:
                loops.append(v)
            elif v not in color:
                dfs(v, path)
        color[u] = 2
    for u in nxt:
        if u not in color:
            dfs(u, [])
    return orphans, loops


def aff_jumps(scene):
    out = []
    for i, op in enumerate(scene["ops"]):
        fxs = [op.get("fx", "")] if op["op"] == "do" else ([o.get("fx", "") for o in op["opts"]] if op["op"] == "choice" else [])
        for fx in fxs:
            for m in re.finditer(r'aff\("([A-Z_]+)",\s*(-?\d+)', fx or ""):
                if abs(int(m.group(2))) > AFF_STEP:
                    out.append((i, m.group(1), int(m.group(2))))
    return out


def main():
    defaults = {k: v.get("default", 0) for k, v in load(os.path.join(DATA, "vars.json"))["vars"].items()}
    profs = profiles(defaults)
    ids = load(os.path.join(DLG, "_index.json"))["scenes"]
    entries = code_entries()
    R = []
    def add(chk, sid, where, status, note):
        R.append({"check": chk, "scene": sid, "where": where, "status": status, "note": note})
    n_paths = 0
    for sid in ids:
        sc = load(os.path.join(DLG, sid + ".json"))
        orphans, loops = static_checks(sc, entries)
        starts = [0] + [at for lb, at in sc["labels"].items() if lb in entries and lb != "START"]
        for lb in orphans:
            add("①", sid, lb, "실패", "아무 이동 · 조건 · 선택도 가리키지 않고 앞에서 흘러 들어오지도 않는다")
        for at in sorted(set(loops)):
            add("②", sid, "op%d" % at, "실패", "대사 · 선택 없이 도는 고리")
        reached_any = set()
        stuck_by = {}
        capped = []
        for name, base, dead, caps in profs:
            if test(sc.get("cond", ""), Env(base, defaults), fns_for(dead)) is False:
                continue                                                    # 이 프로필에선 장면이 열리지 않는다
            reached, stuck = set(), set()
            if walk(sc, Env(dict(base), defaults), dead, caps, reached, stuck, starts):
                capped.append(name)
            n_paths += 1
            reached_any |= reached
            for i in stuck:
                stuck_by.setdefault(i, []).append(name)
        for i, names in sorted(stuck_by.items()):
            texts = " / ".join(o["text"][:18] for o in sc["ops"][i]["opts"])
            add("②", sid, "op%d" % i, "실패", "선택지가 모두 닫힘(%s) — 프로필 %s" % (texts, ", ".join(names[:4]) + (" 외 %d" % (len(names) - 4) if len(names) > 4 else "")))
        if capped:
            add("②", sid, "-", "주의", "걸음 상한(%d)에 닿음 — 프로필 %s" % (STEP_CAP, ", ".join(capped[:3])))
        for lb in sc["labels"]:
            if lb not in reached_any and lb not in orphans and reached_any:
                add("①", sid, lb, "참고", "어느 프로필에서도 닿지 않음(진행기 · 함수 · 앞 퀘스트가 정하는 값일 수 있다 — 사람이 볼 때 참고)")
        for i, a, n in aff_jumps(sc):
            add("⑥", sid, "op%d" % i, "주의", "%s %+d — 한 번에 ±%d 넘음" % (a, n, AFF_STEP))
    al = allow_list()
    for r in R:
        r["allowed"] = r["status"] != "통과" and ("%s|%s|%s" % (r["check"], r["scene"], r["where"])) in al
        r["reason"] = al.get("%s|%s|%s" % (r["check"], r["scene"], r["where"]), "")
    fails = [r for r in R if r["status"] == "실패" and not r["allowed"]]
    warns = [r for r in R if r["status"] == "주의" and not r["allowed"]]
    notes = [r for r in R if r["status"] == "참고"]
    md = ["# 분기 자동 검증 v1(SD-19 §10.2) — `tools/pipeline/branch_verify.py`", "",
          "장면 %d · 프로필 %d(기준 + 한 축 변주: 호감 적대/우호 · 카르마 · 캡 · 시각 · 핵심 인물 사망 · 2막) · 따라간 장면×프로필 %d." % (len(ids), len(profs), n_paths),
          "진행기(GDScript) 안의 분기는 대상 밖 — 시험 · 봇 몫. ④ 미선언 변수 · ⑩ 진영 결정 문형은 원고 변환기, ⑦ 같은 변수 다른 뜻은 교차 표가 맡는다.", "",
          "| 판정 | 수 |", "|---|---|", "| 실패 | %d |" % len(fails), "| 주의 | %d |" % len(warns), "| 참고(동적 닿지 않음) | %d |" % len(notes), "| 허용(이유 있음) | %d |" % sum(1 for r in R if r["allowed"]), "",
          "| 판정 | 검사 | 장면 | 자리 | 메모 |", "|---|---|---|---|---|"]
    for r in sorted(R, key=lambda r: (r["allowed"], {"실패": 0, "주의": 1, "참고": 2}.get(r["status"], 3), r["scene"])):
        md.append("| %s | %s | %s | %s | %s |" % ("허용" if r["allowed"] else r["status"], r["check"], r["scene"], r["where"], r["note"] + (" — " + r["reason"] if r["allowed"] else "")))
    open(os.path.join(DATA, "_branch_report.md"), "w", encoding="utf-8").write("\n".join(md) + "\n")
    json.dump(R, open(os.path.join(DATA, "_branch_report.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    new = len(fails)
    print("분기 검증: 장면 %d · 프로필 %d · 실패 %d(새 %d) · 주의 %d · 참고 %d (game/data/_branch_report.md)" % (len(ids), len(profs), len(fails), new, len(warns), len(notes)))
    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(0 if main() == 0 or "--soft" in sys.argv else 1)
