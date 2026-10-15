"""기획서 요약(_digest)의 원문 줄 번호(Lnnn)를 다시 맞춘다 — 원문에 '구현 정합' 블록 등을 넣어 줄이 밀린 뒤에 돌린다.

쓰는 법: python3 tools/digest_lines.py <기준 커밋> [--dry] [--only 03a,09a]
  기준 커밋 = 요약의 줄 번호가 원문과 정확히 맞던 때(요약을 처음 쓴 커밋 등).
  1) 기준 커밋의 원문 → 지금 원문을 줄 단위로 맞대어(difflib) 옛 줄 → 새 줄 대응표를 만든다.
  2) 지금 요약의 줄마다 기준 커밋 요약에서 같은 줄(숫자만 다른)을 찾아, 그 줄의 옛 번호를 대응표로 옮겨 쓴다.
     기준 커밋 뒤에 새로 쓴 요약 줄은 그대로 두고 목록으로 알린다(손으로 확인).
  00_INDEX.md는 '## …(원문 `파일.md` …)' 구역마다 그 문서로 옮긴다.
"""
import os, re, sys, subprocess, difflib, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs", "seoul-fallout")
DIG = os.path.join(DOCS, "_digest")
REF = re.compile(r"L(\d{1,5})")


def show(commit, rel):
    try:
        return subprocess.run(["git", "show", f"{commit}:{rel}"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split("\n")
    except subprocess.CalledProcessError:
        return None


def line_map(old, new):
    """옛 줄 번호(1부터) → 새 줄 번호. 같은 줄은 그대로, 바뀐 덩어리는 덩어리 시작 기준으로 옮긴다."""
    sm = difflib.SequenceMatcher(None, old, new, autojunk=False)
    m = {}
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        for k in range(i1, i2):
            m[k + 1] = (j1 + (k - i1) if tag == "equal" else min(j1 + (k - i1), max(j1, j2 - 1))) + 1
    m[len(old) + 1] = len(new) + 1
    return m


def norm(s):
    return REF.sub("L#", s)


def remap_lines(cur_lines, old_lines, lmap, tag):
    """cur_lines 가운데 old_lines에 같은 모양(숫자 빼고)이 있는 줄의 L번호를 옛 번호 → 새 번호로"""
    pool = {}
    for l in old_lines:
        if REF.search(l):
            pool.setdefault(norm(l), []).append(l)
    out, fresh, changed = [], [], 0
    for l in cur_lines:
        if not REF.search(l):
            out.append(l)
            continue
        cand = pool.get(norm(l))
        if not cand:
            fresh.append(l)
            out.append(l)
            continue
        src = cand[0]
        nums = [int(x) for x in REF.findall(src)]
        it = iter(nums)
        nl = REF.sub(lambda m: "L%d" % lmap.get(next(it), int(m.group(1))), l)
        changed += nl != l
        out.append(nl)
    return out, fresh, changed


def main():
    base = sys.argv[1]
    dry = "--dry" in sys.argv
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []
    maps = {}

    def get_map(docname):
        if docname not in maps:
            rel = f"docs/seoul-fallout/{docname}"
            old = show(base, rel)
            cur = open(os.path.join(DOCS, docname), encoding="utf-8").read().split("\n")
            maps[docname] = line_map(old, cur) if old else None
        return maps[docname]
    for path in sorted(glob.glob(os.path.join(DIG, "*.md"))):
        name = os.path.basename(path)
        if only and name != "00_INDEX.md" and not any(name.startswith(o) for o in only):
            continue
        cur = open(path, encoding="utf-8").read().split("\n")
        old = show(base, f"docs/seoul-fallout/_digest/{name}")
        if old is None:
            continue
        if name == "00_INDEX.md":
            out, i, total = [], 0, 0
            heads = [k for k, l in enumerate(cur) if l.startswith("## ")] + [len(cur)]
            out = cur[:heads[0]]
            for a, b in zip(heads, heads[1:]):
                block = cur[a:b]
                m = re.search(r"원문 `([^`]+\.md)`", block[0])
                ok = m and os.path.exists(os.path.join(DOCS, m.group(1))) and (not only or any(m.group(1).startswith(o) for o in only))
                lm = get_map(m.group(1)) if ok else None
                if lm:
                    block, fresh, ch = remap_lines(block, old, lm, name)
                    total += ch
                out += block
            print(f"{name}: 고친 줄 {total}")
        else:
            m = re.search(r"원문: `docs/seoul-fallout/([^`]+\.md)`", "\n".join(cur[:6]))
            if not m:
                continue
            lm = get_map(m.group(1))
            if lm is None:
                continue
            out, fresh, ch = remap_lines(cur, old, lm, name)
            print(f"{name}: 고친 줄 {ch} · 기준 뒤 새 줄 {len(fresh)}")
            for f in fresh[:8]:
                print("   새 줄:", f[:110])
        if not dry and out != cur:
            open(path, "w", encoding="utf-8").write("\n".join(out))


if __name__ == "__main__":
    main()
