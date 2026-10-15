"""세력 계급 증표(SD-13 §7.4.2, M-120~M-140) → game/data/items_tokens.json.
표가 한 줄에 증표 둘(ID·증표·세력·단계 × 2)이라 스키마 추출기(extract.py) 대신 여기서 뽑는다. 모두 무게 0 · 판매 불가.
M-136(정착지 명예 주민 증표)은 정착지마다 차분이 있어(표 괄호), 게임에 들어온 정착지 차분을 'M-136-<정착지>'로 더한다
(1-8b 봉천 계단 열쇠 = 312번째 계단 옥탑방 열쇠, SD-15 §7.2).
"""
import os, re, json

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOC = os.path.join(ROOT, "docs", "seoul-fallout", "13_items.md")
OUT = os.path.join(ROOT, "game", "data", "items_tokens.json")
SECTION = "#### 7.4.2 세력 계급 증표"
# M-136 정착지 차분: 열쇠 → (이름, 설명). 정착지 코드는 SD-06(BC 봉천 계단마을)
VARIANTS = {"BC": ("봉천 계단 열쇠", "정착지 명예 주민 증표(봉천). 312번째 계단 옥탑방 문 열쇠 — 조만석의 '빌린 침대'가 이제 내 방이다(SD-15 §7.2).")}


def main():
    lines = open(DOC, encoding="utf-8").read().split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith(SECTION))
    out = {}
    for l in lines[i + 1:]:
        if l.startswith("#### ") or l.startswith("### "):
            break
        if not l.startswith("| M-"):
            continue
        cells = [c.strip() for c in l.strip().strip("|").split("|")]
        for k in range(0, len(cells) - 2, 3):
            mid, name, fac = cells[k], cells[k + 1], cells[k + 2]
            if not re.match(r"^M-\d{3}$", mid):
                continue
            short = re.sub(r"\(.*\)$", "", name).strip()
            out[mid] = {"id": mid, "name": short, "cat": "misc", "value": 0, "weight": 0.0, "no_sell": True, "token": True,
                        "desc": "%s — %s" % (name, fac)}
    for code, (nm, desc) in VARIANTS.items():
        out["M-136-" + code] = {"id": "M-136-" + code, "name": nm, "cat": "misc", "value": 0, "weight": 0.0, "no_sell": True, "token": True,
                                "base": "M-136", "settle": code, "desc": desc}
    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
    print("세력 증표 %d개(정착지 차분 %d) → %s" % (len(out), len(VARIANTS), os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
