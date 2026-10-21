"""원고 변형판 만들기(단계 1-12f): 같은 장면을 다른 화자로 한 벌 더 — 손으로 두 벌 쓰면 한쪽만 고쳐지는 일을 막는다.
  FQ-SB-02 「현장 운송」: 인솔조장 갈고리(N-R02-041)가 죽었거나 SQ-S09에서 고척 노선으로 옮겼으면 대리 '인솔 반장'(N-SB-L1)이
  같은 자리를 맡는다(SD-20 P3 · A201 직함 규칙) → script/act1/FQ-SB-02L.txt(장면 ID 끝 _L). 진행기 FqSb가 FQ_SB02_LEAD로 고른다.
실행: python3 tools/pipeline/script_variants.py (build_data.sh — 원고 변환 앞)
"""
import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VARIANTS = [("script/act1/FQ-SB-02.txt", "script/act1/FQ-SB-02L.txt", "_L",
             [("N-R02-041", "N-SB-L1"), ("인솔조장 갈고리", "인솔 반장"), ("갈고리에게", "반장에게"), ("갈고리가", "반장이"),
              ("갈고리의", "반장의"), ("갈고리", "반장")])]


def main():
    for src, dst, suf, subs in VARIANTS:
        out = ["# 자동 생성 — tools/pipeline/script_variants.py가 %s에서 만든다. 고치려면 원본을 고칠 것." % src]
        for line in open(os.path.join(ROOT, src), encoding="utf-8").read().split("\n"):
            if line.startswith("#"):
                continue
            m = re.match(r"(@scene\s+)(\S+)(.*)", line)
            if m:
                line = m.group(1) + m.group(2) + suf + m.group(3)
            for a, b in subs:
                line = line.replace(a, b)
            out.append(line)
        open(os.path.join(ROOT, dst), "w", encoding="utf-8").write("\n".join(out))
        print("원고 변형판: %s → %s" % (src, dst))


if __name__ == "__main__":
    main()
