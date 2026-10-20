"""고유 무기 추출(단계 1-12a, 장부 D-027): SD-13 §3.9 표 W-101~W-131 → game/data/weapons.json에 덧붙인다.

규칙(SD-13 §3.9): 고유 무기는 기반 무기의 레이어를 그대로 쓰고 '기반 대비 변경' 칸에 적힌 값만 다르다.
  - 기반 무기 사본에 바뀐 값만 덮어쓴다: 피해 · 연사 · 내구 · 가격 · 탄창/장탄 · 사거리 · 치명 배수 · 재장전 시간 −n% ·
    넘어뜨림 · 마비 확률 · 관제망 로봇 상대 피해 +n%.
  - 그 밖의 특수 효과 문장(점사 · 화염 저항 · 포탑 지연 등)은 `unique_fx` 글로 남긴다 — 효과 자체는 장부 D-273(이월).
  - 단독 고유(기반 없음 — W-115 각성의 팔)는 건너뛴다(장부 D-273).
extract.py 뒤에 돈다(build_data.sh).
"""
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOC = os.path.join(ROOT, "docs", "seoul-fallout", "13_items.md")
OUT = os.path.join(ROOT, "game", "data", "weapons.json")

NUM = r"([0-9]+(?:\.[0-9]+)?)"


def rows():
    lines = open(DOC, encoding="utf-8").read().split("\n")
    on = False
    for i, ln in enumerate(lines):
        if ln.startswith("### 3.9 "):
            on = True
            continue
        if on and ln.startswith("### "):
            break
        if on and ln.startswith("| W-1"):
            cells = [c.strip() for c in ln.strip().strip("|").split("|")]
            yield i + 1, cells


def apply(w, change, errors, wid):
    def pair(label):
        m = re.search(label + r"\s*" + NUM + r"\s*→\s*" + NUM, change)
        return (float(m.group(1)), float(m.group(2))) if m else None
    fx = []
    p = pair("피해")
    if p:
        w["dmg"] = int(p[1]) if p[1].is_integer() else p[1]
        w["dmg_text"] = str(w["dmg"])
        w["crit_dmg"] = w["dmg"]
    p = pair("연사")
    if p:
        w["rate"] = p[1]
    p = pair("사거리")
    if p:
        w["range_eff"] = p[1]
        w["range_max"] = round(p[1] * 1.75, 2)
    for lab in ("탄창", "장탄"):
        p = pair(lab)
        if p:
            w["mag"] = int(p[1])
    p = pair("가격")
    if p:
        w["price"] = int(p[1])
    m = re.search(r"내구\s*([SABCDE∞])\s*→\s*([SABCDE∞])", change)
    if m:
        w["durability"] = m.group(2)
    elif "내구 " in change:
        m = re.search(r"내구\s*([SABCDE∞])\b", change)
        if m:
            w["durability"] = m.group(1)
    m = re.search(r"치명 배수\s*x" + NUM + r"\s*→\s*x" + NUM, change)
    if m:
        w["crit_mult"] = float(m.group(2))
    m = re.search(r"재장전 시간\s*[−-]\s*" + NUM + "%", change)
    if m:
        w["reload_s"] = round(float(w.get("reload_s", 2.0)) * (1.0 - float(m.group(1)) / 100.0), 2)
    m = re.search(r"넘어뜨림\s*" + NUM + r"\s*→\s*" + NUM + "%", change)
    if m:
        w["knock_pct"] = int(float(m.group(2)))
    m = re.search(r"마비 확률\s*" + NUM + r"\s*→\s*" + NUM + "%", change)
    if m:
        w["stun_pct"] = int(float(m.group(2)))
    m = re.search(r"로봇 상대 피해\s*\+" + NUM + "%", change)
    if m:
        w["robot_mult"] = 1.0 + float(m.group(1)) / 100.0
    # 위 규칙으로 읽지 못한 조각은 특수 효과 글로 남긴다
    for part in [s.strip() for s in re.split(r",\s*|\.(?!\d)", change) if s.strip()]:
        if not re.match(r"^(피해|연사|사거리|탄창|장탄|가격|내구|치명 배수|재장전 시간|넘어뜨림|마비 확률|관제망 로봇 상대 피해)\b", part):
            fx.append(part)
    if fx:
        w["unique_fx"] = " · ".join(fx)


def main():
    errors = []
    data = json.load(open(OUT, encoding="utf-8"))
    n = 0
    skipped = []
    for ln, c in rows():
        if len(c) < 8:
            errors.append(f"13_items.md:{ln} 칸이 모자란다")
            continue
        wid, name, layer_txt, base_txt, change, where, faction, origin = c[:8]
        m = re.match(r"(W-\d{3})", base_txt)
        if not m:
            skipped.append(wid)                                          # 단독 고유(W-115)
            continue
        base = m.group(1)
        if base not in data:
            errors.append(f"13_items.md:{ln} {wid} 기반 무기 {base}가 weapons.json에 없다")
            continue
        w = dict(data[base])
        w.update({"_src": f"13_items.md:{ln}", "id": wid, "name": name, "base": base, "unique": True,
                  "where": where, "faction": faction, "origin": origin, "note": change})
        apply(w, change, errors, wid)
        data[wid] = w
        n += 1
    json.dump(dict(sorted(data.items())), open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
    print(f"고유 무기 {n}종 · 건너뜀 {skipped} | 오류 {len(errors)}")
    for e in errors:
        print("  오류", e)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
