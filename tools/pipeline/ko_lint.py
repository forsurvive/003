"""번역투 후보 찾기(SD-24 §3 · 리드 지시 2026-10-23) — 게임 안 글에서 영어식 표현 후보를 찾아 보고한다.
판정은 하지 않는다: 후보를 `korean-editor` 에이전트와 사람이 문맥으로 본다. 우리말 관용이라 둔 것은 허용 목록에 이유와 함께.

  python3 tools/pipeline/ko_lint.py              → game/data/_ko_lint.md (후보 · 허용 · 새 후보)
  python3 tools/pipeline/ko_lint.py --baseline "이유"  → 지금 새 후보를 모두 허용 목록에 더한다(전수 검수 뒤 둔 것만 — 이유 필수)

범위(SD-24 §1): script/**.txt(주석 · 제어 줄 빼고 글만) · maps/**.map · maps/world/*.spots(따옴표 글 · bark= · name=) ·
game/{scenes/story,systems,core}/**.gd 화면 글(_log · print 줄 빼고) · tools/pipeline/*.py 화면 글(print · log · 주석 빼고).
허용 목록 tools/pipeline/ko_lint_allow.yaml: '유형|글' : 이유 (글이 바뀌면 허용도 풀린다 — 다시 본다)."""
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "data", "_ko_lint.md")
ALLOW = os.path.join(ROOT, "tools", "pipeline", "ko_lint_allow.yaml")

# (유형, 정규식, 설명) — SD-24 §3 표와 같은 ID. 대사 줄에만 보는 것은 'dlg'.
PATS = [
    ("T1", r"(감|값|물건|짐짝|고철)(으)?로 (본다|봐|보는|봤|보지)", "값 · 쓸모로 '본다'(see A as B)"),
    ("T1", r"값을 매기는 눈", "값을 매기는 눈으로 본다"),
    ("T2", r"의 값이(다|야|지)", "'~의 값이다'(the price of)"),
    ("T2", r"값이 같", "'값이 같다'(costs the same)"),
    ("T2", r"그 값으로", "'그 값으로'(for that price)"),
    ("T2", r"값으로 (쳐|친|치)", "'값으로 친다'"),
    ("T3", r"(판|게임|패)(을|은|는)? ?접", "'판을 접는다'(fold)"),
    ("T3", r"기회를 잡", "'기회를 잡다'(take a chance)"),
    ("T3", r"시간을 (가지|갖)", "'시간을 가지다'(have time)"),
    ("T3", r"돈을 만들", "'돈을 만들다'(make money)"),
    ("T3", r"(얘기|말|이야기)(를|은|는)? 안 사", "'그 말 안 산다'(buy)"),
    ("T3", r"시간을 사", "'시간을 사다'(buy time)"),
    ("T4", r"거짓말을 (안|하지 않|못)", "'~는 거짓말을 안 한다'(… don't lie)"),
    ("T4", r"손이 묶", "'손이 묶였다'(hands are tied)"),
    ("T4", r"공(은|이) .{0,6}넘어", "'공은 네게 넘어갔다'"),
    ("T4", r"좋은 질문", "'좋은 질문이야'"),
    ("T4", r"그게 다(야|예요|다|요)", "'그게 다야'(that's all)"),
    ("T4", r"내 말은", "'내 말은'(I mean)"),
    ("T4", r"행운을 빌", "'행운을 빈다'(good luck)"),
    ("T5", r"그녀", "'그녀'"),
    ("T5", r"(^|[ (])그의 ", "'그의'"),
    ("T5", r"(^|[ (])(나의|너의) ", "'나의 · 너의'"),
    ("T6", r"에 대(한|해)", "'~에 대한/대해'"),
    ("T6", r"(을|를) 통해", "'~을 통해'"),
    ("T6", r"(으)?로부터", "'~로부터'"),
    ("T6", r"에 의해", "'~에 의해'"),
    ("T6", r"에 있어(서)? ", "'~에 있어서'"),
    ("T7", r"게 만들(었|어|다|더|지|고|면)", "무생물 주어 사역 '~하게 만들다'"),
    ("T8", r"하는 중이", "'~하는 중이다'"),
    ("T8", r"고 있는 중", "'~하고 있는 중'"),
    ("T8", r"하게 될 것", "'~하게 될 것이다'"),
    ("T9", r"(^|[ (])하나의 ", "'하나의'(a/an)"),
    ("T9", r"한 (명|사람)의 ", "'한 명의'"),
    ("T9", r"몇몇의", "'몇몇의'"),
    ("T10", r", 그리고 ", "'A, B, 그리고 C'"),
    ("T11", r"체크|타이밍|컨트롤|미션|오케이", "우리말이 있는 외래어"),
    ("T13", r"에 다름 아니", "'~에 다름 아니다'"),
    ("T13", r"지 않으면 안 ", "'~하지 않으면 안 된다'"),
    ("T13", r"(^|[ (])보다 더 ", "'보다 더'(more)"),
    ("T14", r"(이)?라고 부르(고|지|겠|는)", "'~라고 부르고, 남들은 …'(call it)"),
    ("T14", r"내가 할 일이 아니|내 일이 아니", "'not my job'"),
]
DLG_ONLY = [("T12", r"당신", "대사의 '당신'(낯선 이에게 · 아무에게나)")]
RX = [(i, re.compile(p), d) for i, p, d in PATS]
RX_DLG = [(i, re.compile(p), d) for i, p, d in DLG_ONLY]
HANGUL = re.compile(r"[가-힣]")
SPK = re.compile(r"^([A-Z][A-Z0-9]*-[A-Za-z0-9-@]+|[가-힣]+)\s*(\[[^\]]+\])?\s*[:]?\s*(.*)$")


def _script_lines(path):
    """원고: (줄 번호, 글, 대사인가)"""
    out = []
    for n, raw in enumerate(open(path, encoding="utf-8"), 1):
        s = raw.rstrip("\n").strip()
        if not s or s[0] in "#@?!*" or s.startswith("->"):
            continue
        if s.startswith(">"):
            s = s[1:].split(" -> ")[0].split(" ?? ")[0].strip()
            s = re.sub(r"^\[[^\]]+\]\s*", "", s)
            out.append((n, s, True))
            continue
        if s.startswith("SYS "):
            out.append((n, s[4:], False))
            continue
        if "|" in s and s.split("|")[0].strip().replace("_", "").isalnum() and not HANGUL.search(s.split("|")[0]):
            s = s.split("|", 1)[1].strip()                                  # households · factions 식 '키 | 글'
            out.append((n, s, False))
            continue
        m = SPK.match(s)
        if m and m.group(2):
            out.append((n, m.group(3), True))
        elif re.match(r"^[가-힣]{2,4}: ", s):                               # 방송 '송미래: 글'
            out.append((n, s.split(": ", 1)[1], True))
        else:
            out.append((n, s, False))
    return out


Q = re.compile(r'(\b(?:bark|name|hint|label)=)?"((?:[^"\\]|\\.)*)"')


def _map_lines(path):
    out = []
    for n, raw in enumerate(open(path, encoding="utf-8"), 1):
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        s = s.split(" #")[0] if " # " in s else s
        for m in Q.finditer(s):
            pre = s[:m.start()]
            if pre.endswith("cond=") or pre.endswith("args="):
                continue
            t = m.group(2)
            if HANGUL.search(t):
                out.append((n, t, (m.group(1) or "") == "bark="))
    return out


SKIP_CODE = re.compile(r"_log\(|print\(|push_error|push_warning|assert|log\(|raise |Err\(|\.err\(|SystemExit")


def _code_lines(path, py):
    out = []
    for n, raw in enumerate(open(path, encoding="utf-8"), 1):
        s = raw.strip()
        if not s or s.startswith("#") or SKIP_CODE.search(s):
            continue
        code = re.split(r"\s#(?![^\"]*\"[^\"]*$)", s)[0] if py else s.split("##")[0].split(" # ")[0]
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', code):
            t = m.group(1)
            if HANGUL.search(t):
                out.append((n, t, "_pop(" in code or "bark" in code))
    return out


def collect():
    items = []
    for p in sorted(glob.glob(os.path.join(ROOT, "script", "**", "*.txt"), recursive=True)):
        items += [(p, n, t, d) for n, t, d in _script_lines(p)]
    for p in sorted(glob.glob(os.path.join(ROOT, "maps", "**", "*.map"), recursive=True) + glob.glob(os.path.join(ROOT, "maps", "world", "*.spots"))):
        items += [(p, n, t, d) for n, t, d in _map_lines(p)]
    for sub in ("scenes/story", "systems", "core"):
        for p in sorted(glob.glob(os.path.join(ROOT, "game", sub, "**", "*.gd"), recursive=True)):
            items += [(p, n, t, d) for n, t, d in _code_lines(p, False)]
    for p in sorted(glob.glob(os.path.join(ROOT, "tools", "pipeline", "*.py"))):
        if os.path.basename(p) in ("ko_lint.py", "quest_cross.py", "expr_cases.py"):
            continue
        items += [(p, n, t, d) for n, t, d in _code_lines(p, True)]
    return items


def load_allow():
    d = {}
    if os.path.exists(ALLOW):
        for raw in open(ALLOW, encoding="utf-8"):
            s = raw.rstrip("\n")
            if not s.strip() or s.lstrip().startswith("#"):
                continue
            m = re.match(r'^"((?:[^"\\]|\\.)*)":\s*(.*)$', s)
            if m:
                d[m.group(1).replace('\\"', '"')] = m.group(2)
    return d


def scan():
    hits = []
    for p, n, t, dlg in collect():
        for i, rx, desc in RX + (RX_DLG if dlg else []):
            if rx.search(t):
                hits.append({"id": i, "file": os.path.relpath(p, ROOT), "line": n, "text": t, "desc": desc, "key": "%s|%s" % (i, t)})
    return hits


def main():
    hits = scan()
    allow = load_allow()
    if len(sys.argv) > 2 and sys.argv[1] == "--baseline":
        why = sys.argv[2]
        new = [h for h in hits if h["key"] not in allow]
        with open(ALLOW, "a", encoding="utf-8") as f:
            for h in new:
                if h["key"] in allow:
                    continue
                allow[h["key"]] = why
                f.write('"%s": %s\n' % (h["key"].replace('"', '\\"'), why))
        print("허용 목록에 더함: %d" % len(new))
    new = [h for h in hits if h["key"] not in allow]
    by = {}
    for h in hits:
        by.setdefault(h["id"], [0, 0])
        by[h["id"]][0 if h["key"] in allow else 1] += 1
    out = ["# 번역투 후보(ko_lint) — SD-24 §3", "",
           "> 도구는 후보만 찾는다 — 판정은 `korean-editor`와 사람. 후보 %d · 허용 %d · **새 %d**. 허용은 `tools/pipeline/ko_lint_allow.yaml`(이유 필수)." % (
               len(hits), len(hits) - len(new), len(new)), "",
           "| 유형 | 허용 | 새 |", "|---|---|---|"]
    for k in sorted(by):
        out.append("| %s | %d | %d |" % (k, by[k][0], by[k][1]))
    out += ["", "## 새 후보"]
    for h in new:
        out.append("- **%s** `%s:%d` %s — %s" % (h["id"], h["file"], h["line"], h["desc"], h["text"][:160]))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("번역투 후보: %d · 허용 %d · 새 %d (game/data/_ko_lint.md)" % (len(hits), len(hits) - len(new), len(new)))


if __name__ == "__main__":
    main()
