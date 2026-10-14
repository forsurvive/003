"""해킹 단어 풀 내보내기(단계 1-4, SD-12 §8.3 '단어 풀 규격'): tools/data/hack_words.txt → game/data/hack_words.json
{주제군: {음절 수: [단어, …]}}. 검사: 한글 음절만 · 3~7음절 · 겹침 없음 · 금칙(SD-18 §2.3 금칙 명칭은 원고 변환기와 같은 목록).
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
    for n, line in enumerate(open(SRC, encoding="utf-8"), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("@"):
            cur = line[1:].strip()
            if cur not in THEMES:
                errors.append(f"{n}: 모르는 주제군 {cur}")
            continue
        for w in line.split():
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
    print(f"해킹 단어 {len(seen)}개 {counts} | 길이 밖 건너뜀 {len(skipped)} | 오류 {len(errors)}")
    for e in errors[:20]:
        print("  오류:", e)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
