"""퍽 자료(단계 1-12p, SD-10 §5.2 일반 퍽 카탈로그 PK-001~PK-102): 기획서 표 → game/data/perks.json.
  레벨은 표 머리('**Lv2**' …) 또는 Lv22~30 표의 Lv 열. 요구 능력치 'IN 4, AG 4' → {"IN": 4, "AG": 4} · 요구 스킬 '과학 40' → {"SCIENCE": 40}
  · 카르마 '요구: 선함 이상(+250)' → {"karma_min": 250} 등. 효과 글은 그대로(퍽 창 설명). 정본은 기획서 — 이 파일은 손대지 않는다."""
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "docs", "seoul-fallout", "10_character-system.md")
OUT = os.path.join(ROOT, "game", "data", "perks.json")
CARD = os.path.join(ROOT, "script", "world", "perks.txt")             # 퍽 카드 글(맛 한 줄 · 효과 한 줄 — 다듬이 검수 원고)
SKILLS = {"물물교환": "BARTER", "중화기": "BIG_GUNS", "에너지 무기": "ENERGY", "폭발물": "EXPLOSIVES", "자물쇠 따기": "LOCKPICK", "의학": "MEDICINE",
          "근접 무기": "MELEE", "수리": "REPAIR", "과학": "SCIENCE", "소형 화기": "SMALL_GUNS", "은신": "SNEAK", "화술": "SPEECH", "비무장": "UNARMED"}
STATS = ("ST", "PE", "EN", "CH", "IN", "AG", "LK")


def _reqs(stat_s, skill_s):
    st, sk = {}, {}
    for m in re.finditer(r"\b(%s)\s*(\d+)" % "|".join(STATS), stat_s):
        st[m.group(1)] = int(m.group(2))
    for part in skill_s.split(","):
        m = re.match(r"\s*(.+?)\s+(\d+)\s*$", part)
        if m and m.group(1).strip() in SKILLS:
            sk[SKILLS[m.group(1).strip()]] = int(m.group(2))
    return st, sk


def _karma(s):
    s = s.strip()
    if s.startswith("요구:"):
        m = re.search(r"([+-]?\d[\d,]*)", s)
        n = int(m.group(1).replace(",", "")) if m else 0
        if "이상" in s:
            return {"karma_min": n}
        if "이하" in s:
            return {"karma_max": n}
        if "매우 악함이 아님" in s:
            return {"karma_min": -749}
        if "매우 선함이 아님" in s:
            return {"karma_max": 749}
        if "중립이 아님" in s:
            return {"karma_not_neutral": True}
    return {}


def main():
    lines = open(SRC, encoding="utf-8").read().split("\n")
    a = next(i for i, l in enumerate(lines) if l.startswith("### 5.2 "))
    b = next(i for i, l in enumerate(lines) if l.startswith("### 5.3 "))
    out = {}
    lv = 0
    for l in lines[a:b]:
        m = re.match(r"^\*\*Lv(\d+)", l)
        if m:
            lv = int(m.group(1))
            continue
        if not l.startswith("| PK-"):
            continue
        c = [x.strip() for x in l.strip().strip("|").split("|")]
        if len(c) == 10:                                                  # Lv22~30 표: ID 퍽 원작 구분 Lv 능력치 스킬 랭크 효과 카르마
            pid, name, orig, kind, plv, stat_s, skill_s, rank, eff, karma = c
            plv = int(plv)
        else:
            pid, name, orig, kind, stat_s, skill_s, rank, eff, karma = c[:9]
            plv = lv
        st, sk = _reqs(stat_s, skill_s)
        out[pid] = {"id": pid, "name": name, "orig": orig if orig != "–" else "", "kind": kind, "lv": plv, "stats": st, "skills": sk,
                    "ranks": int(rank) if rank.isdigit() else 1, "effect": eff, **_karma(karma)}
    for l in open(CARD, encoding="utf-8").read().split("\n"):
        if not l.startswith("PK-"):
            continue
        c = [x.strip() for x in l.split("|")]
        if len(c) != 3 or c[0] not in out:
            raise SystemExit("퍽 카드 줄 오류: " + l)
        out[c[0]]["line"], out[c[0]]["card"] = c[1], c[2]
    json.dump({"perks": out}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("퍽 자료: %d종 (레벨 %s)" % (len(out), sorted({p["lv"] for p in out.values()})))


if __name__ == "__main__":
    main()
