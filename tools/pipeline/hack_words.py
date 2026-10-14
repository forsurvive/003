"""해킹 단어 풀 내보내기(단계 1-4, SD-12 §8.3 '단어 풀 규격'): tools/data/hack_words.txt → game/data/hack_words.json
{주제군: {음절 수: [단어, …]}}. 검사: 한글 음절만 · 3~7음절 · 겹침 없음 · 금칙(SD-18 §2.3 금칙 명칭은 원고 변환기와 같은 목록).
합성 묶음 줄 `% 머리 … / 꼬리 … ! 뺄 단어 …` = 머리 × 꼬리를 모두 붙인 단어(뺄 단어 제외). 묶음끼리·낱말과 겹치면 조용히 한 번만 넣는다
— 같은 자리 같은 음절을 가진 후보가 많아야 '후보의 절반 이상은 정답과 1자리 이상 일치' 생성 규칙이 선다.
python3 tools/pipeline/hack_words.py
"""
import os, re, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "data", "hack_words.txt")
OUT = os.path.join(ROOT, "game", "data", "hack_words.json")
THEMES = {"T1": "기업·생활", "T2": "관제망·민방위", "T3": "볼트·적성 평가", "T4": "군사"}


def main():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from script_compile import banned_terms
    banned = banned_terms()
    out, seen, errors, skipped = {t: {} for t in THEMES}, set(), [], []
    cur = None
    families = [0]
    for n, line in enumerate(open(SRC, encoding="utf-8"), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("@"):
            cur = line[1:].strip()
            if cur not in THEMES:
                errors.append(f"{n}: 모르는 주제군 {cur}")
            continue
        fam = line.startswith("%")
        words = line.split()
        if fam:
            body, _, drop = line[1:].partition("!")
            heads, _, tails = body.partition("/")
            if not tails.strip():
                errors.append(f"{n}: 묶음에 꼬리가 없다")
                continue
            drop = set(drop.split())
            words = [h + t for h in heads.split() for t in tails.split()]
            unused = drop - set(words)
            if unused:
                errors.append(f"{n}: 묶음에 없는 뺄 단어 — {' '.join(sorted(unused))}")
            words = [w for w in words if w not in drop and w not in seen]
            families[0] += 1
        for w in words:
            if not re.fullmatch(r"[가-힣]+", w):
                errors.append(f"{n}: 한글 음절만 — {w}")
            elif w in seen:
                errors.append(f"{n}: 겹침 — {w}")
            elif any(b in w for b in banned):
                errors.append(f"{n}: 금칙 — {w}")
            elif not 3 <= len(w) <= 7:
                skipped.append(w)
            else:
                seen.add(w)
                out[cur].setdefault(str(len(w)), []).append(w)
    json.dump({"themes": THEMES, "words": out}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
    counts = {t: {k: len(v) for k, v in sorted(out[t].items())} for t in out}
    print(f"해킹 단어 {len(seen)}개(묶음 {families[0]}) {counts} | 길이 밖 건너뜀 {len(skipped)} | 오류 {len(errors)}")
    # 생성 규칙이 설 수 있는지: 주제군·길이마다 '1자리 이상 겹치는 다른 단어가 7개 이상'인 단어의 비율
    for t in out:
        row = []
        for k, ws in sorted(out[t].items()):
            ok = sum(1 for a in ws if sum(1 for b in ws if b != a and any(x == y for x, y in zip(a, b))) >= 7)
            row.append(f"{k}음절 {ok}/{len(ws)}")
        print(f"  {t} 겹침 넉넉: " + " · ".join(row))
    for e in errors[:20]:
        print("  오류:", e)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
