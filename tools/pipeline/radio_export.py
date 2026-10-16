"""라디오 원고(script/world/radio.txt, 1-10b) → game/data/radio.json.
머리 줄 '@블록 방송국 종류 ID | 조건', 다음 줄들 = '화자: 문장'(끝에 감정 스팅어 태그 [웃음] 등).
검사: 방송국 · 종류 이름, 블록 ID 겹침, 조건 식(이야기 식 문법 · 변수 이름), 자막 한 줄 28자(SD-17 §4.3 — 스팅어 태그 빼고)."""
import os, re, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_compile as MC
from script_compile import ENGINE_VARS

ROOT = MC.ROOT
SRC = os.path.join(ROOT, "script", "world", "radio.txt")
OUT = os.path.join(ROOT, "game", "data", "radio.json")
STATIONS = {                                                     # SD-12 §10.2 · SD-17 §4.1 — 1막에 쓰는 셋
    "ST-11": {"name": "볼트 S-07 구내방송", "short": "구내방송", "host": "구내방송"},
    "ST-01": {"name": "남산 방송", "short": "남산 방송", "host": "송미래"},
    "ST-02": {"name": "공보방송", "short": "공보방송", "host": "남궁혁 · 공보방송 아나운서"},
}
KINDS = {"intro", "talk", "info", "drama", "news", "outro", "speech", "slogan", "notice", "chime"}
STINGS = {"웃음", "놀람", "한숨", "슬픔", "긴급"}
LINE_MAX = 28


def _split(text):
    """28자가 넘는 줄은 가운데에 가까운 어절 경계(문장 부호 뒤를 먼저)에서 두 줄로 나눈다 — 자막은 한 줄씩 바뀐다."""
    if len(text) <= LINE_MAX:
        return [text]
    cuts = [k for k, ch in enumerate(text) if ch == " "]
    if not cuts:
        return [text]
    mid = len(text) / 2
    def score(k):
        punct = 0 if text[k - 1] in ".,?!…」" else 4
        return abs(k - mid) + punct
    k = min(cuts, key=score)
    return _split(text[:k].rstrip()) + _split(text[k + 1:].lstrip())


def main():
    known_vars = set(json.load(open(os.path.join(ROOT, "game", "data", "vars.json")))["vars"]) | ENGINE_VARS
    for q in json.load(open(os.path.join(ROOT, "game", "data", "quests.json")))["quests"]:
        known_vars |= {q.replace("-", "") + s for s in ("_STAGE", "_RESULT", "_SKIP")}
    known_fns = {"karma", "aff", "quest", "stage", "result", "give", "take", "has", "caps", "xp", "wanted", "stat", "skill", "year"}
    blocks, errs, warns, cur, seen = [], [], [], None, set()
    for i, ln in enumerate(open(SRC, encoding="utf-8").read().split("\n"), 1):
        s = ln.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("@블록"):
            parts = [p.strip() for p in s[3:].split("|", 1)]
            head, cond = parts[0].split(), (parts[1] if len(parts) > 1 else "")
            if len(head) != 3:
                errs.append(f"{i}: 머리 줄은 '@블록 방송국 종류 ID'")
                cur = None
                continue
            st, kind, bid = head
            if st not in STATIONS:
                errs.append(f"{i}: 모르는 방송국 '{st}'")
            if kind not in KINDS:
                errs.append(f"{i}: 모르는 종류 '{kind}'")
            if (st, bid) in seen:
                errs.append(f"{i}: 블록 ID 겹침 {st} {bid}")
            seen.add((st, bid))
            if cond:
                try:
                    MC.check_cond(cond, known_vars, known_fns)
                except Exception as e:
                    errs.append(f"{i}: 조건 오류 {e}")
            cur = {"st": st, "kind": kind, "id": bid, "cond": cond, "lines": [], "_src": i}
            m = re.search(r"(\d+)$", bid)
            if kind == "drama" and m:
                cur["ep"] = int(m.group(1))
            blocks.append(cur)
        elif cur is None:
            errs.append(f"{i}: 머리 줄(@블록) 없이 나온 줄")
        else:
            if ":" not in s:
                errs.append(f"{i}: '화자: 문장' 꼴이 아니다")
                continue
            who, text = [x.strip() for x in s.split(":", 1)]
            sting = ""
            m = re.search(r"\s*\[(\S+?)\]$", text)
            if m and m.group(1) in STINGS:
                sting = m.group(1)
                text = text[:m.start()].rstrip()
            parts = _split(text)
            if any(len(p) > LINE_MAX for p in parts):
                warns.append(f"{i}: 자막 {len(text)}자 — 어절로 못 나눔")
            for k, p in enumerate(parts):
                row = {"who": who, "text": p}
                if sting and k == len(parts) - 1:
                    row["sting"] = sting
                cur["lines"].append(row)
    for b in blocks:
        if not b["lines"]:
            errs.append(f"{b['_src']}: 빈 블록 {b['st']} {b['id']}")
    for w in warns:
        print("경고 radio.txt:" + w)
    for e in errs:
        print("오류 radio.txt:" + e)
    if errs:
        sys.exit(1)
    json.dump({"stations": STATIONS, "blocks": blocks}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    by = {}
    for b in blocks:
        by.setdefault(b["st"], 0)
        by[b["st"]] += 1
    print("라디오: 블록 %d (%s) · 줄 %d" % (len(blocks), " · ".join(f"{k} {v}" for k, v in by.items()), sum(len(b["lines"]) for b in blocks)))


if __name__ == "__main__":
    main()
