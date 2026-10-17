"""파밍 v3 수치 점검(1-L 계획 §2 · §7): 생성 실내 전체를 게임과 같은 규칙으로 굴려(기대값) 결마다 평균 물건 · 캡 · 빈 실내 비율 · 보이는 빔 ·
닫힌 용기 적중률 · 적이 있는 실내 비율을 찍는다. 목표: 실내 한 곳 물건 3~5 · 캡 1~3 · 쓸 것 없는 실내 약 30% · 닫힌 용기 적중 약 50%.
쓰기: python3 tools/pipeline/loot_audit.py [--n 표본 수]"""
import collections
import json
import os
import random
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAPS = os.path.join(ROOT, "game", "data", "maps")
L = json.load(open(os.path.join(ROOT, "game", "data", "loot.json"), encoding="utf-8"))
V3 = L["v3"]


def empty_p(b):
    pl = b.get("pl", "home")
    p = V3["empty"].get(pl, 0.5) * V3["threat"].get(str(b.get("th", 2)), 1.0)
    if b.get("lock", 0) > 0:
        p *= V3["lock"]
    if b.get("hd") == 1:
        p *= V3["hard"]
    if "l3" in b.get("ly", []):
        p *= V3["l3"]
    ev = b.get("ev")
    if ev and ev in L["events"]:
        p *= L["events"][ev][2]
    p *= V3["kind_mul"].get(b["kind"], 1.0)
    return max(0.0, min(0.97, p))


def table_of(b):
    kind, ev = b["kind"], b.get("ev")
    if ev and ev in L["events"] and L["events"][ev][1] and kind in L["events"][ev][0]:
        return L["events"][ev][1]
    till = b.get("name", "").startswith("계산대")
    for pk in (b.get("pl", "home"), "*"):
        m = L["place"].get(pk, {})
        if till and "계산대" in m:
            return m["계산대"]
        if kind in m:
            return m[kind]
    return kind


def roll(b, rnd):
    """한 번 굴린다: (물건 수, 캡, 비었나, 보이는 빔인가)"""
    u = rnd.random()
    pe = empty_p(b)
    vs = V3["vis"]
    pv = pe * vs.get(b.get("pl", "home"), vs["*"])
    if u < pe:
        return 0, 0, True, u < pv
    rows = []
    for r in L["tables"].get(table_of(b), {}).get("rows", []):
        if "l2" in b.get("ly", []) and r[0] in V3["l2_drop"]:
            continue
        r = list(r)
        if r[0] == "M-001":
            r[1] *= V3["caps"]
        rows.append(r)
    got = []
    for r in rows:
        if rnd.random() < min(1.0, r[1] * (1.0 if not r[0].startswith("@") else 1.0)):
            n = rnd.randint(r[2], r[3])
            if r[0].startswith(("@weapon", "@apparel", "@melee", "@clothes")):
                n = 1
            got.append((r[0], n))
    nmax = V3["lines_big"].get(b["kind"], V3["lines"])
    rnd.shuffle(got)
    got = got[:nmax]
    caps = sum(n for (i, n) in got if i == "M-001")
    items = sum(1 for (i, n) in got if i != "M-001" and not i.startswith("@ammo")) + sum(1 for (i, n) in got if i.startswith("@ammo"))
    return items, caps, not got, False


def main():
    idx = json.load(open(os.path.join(MAPS, "_index.json"), encoding="utf-8"))["maps"]
    blob = open(os.path.join(MAPS, "gen.bin"), "rb").read()
    rnd = random.Random(1)
    reps = 4
    S = collections.defaultdict(lambda: collections.Counter())
    for mid, m in idx.items():
        if not mid.startswith("G-"):
            continue
        o, ln, _ = m["pack"]
        d = json.loads(zlib.decompress(blob[o:o + ln]))
        boxes = [b for b in d["boxes"] if b.get("owner", "") == "" and b["kind"] in V3["kinds"]]
        pl = boxes[0].get("pl", "?") if boxes else (d.get("gen") or "?")
        s = S[pl]
        s["maps"] += 1
        s["enemy"] += 1 if d["enemies"] else 0
        s["boxes"] += len(boxes)
        for _ in range(reps):
            it = cp = 0
            any_ = False
            for b in boxes:
                i, c, e, v = roll(b, rnd)
                it += i
                cp += c
                s["vis"] += 1 if v else 0
                s["closed"] += 0 if v else 1
                s["hit"] += 0 if e else 1
                any_ = any_ or not e
            s["items"] += it
            s["caps"] += cp
            s["dry"] += 0 if any_ else 1
    tot = collections.Counter()
    print(f"{'결':10s} {'곳':>5s} {'용기':>5s} {'물건':>5s} {'캡':>5s} {'빈 실내':>7s} {'보이는빔':>8s} {'닫힌적중':>8s} {'적':>5s}")
    for pl, s in sorted(S.items(), key=lambda kv: -kv[1]["maps"]):
        n = s["maps"] * reps
        print(f"{pl:10s} {s['maps']:5d} {s['boxes'] / s['maps']:5.1f} {s['items'] / n:5.1f} {s['caps'] / n:5.1f} {s['dry'] / n:7.0%} "
              f"{s['vis'] / max(1, s['boxes'] * reps):8.0%} {s['hit'] / max(1, s['closed']):8.0%} {s['enemy'] / s['maps']:5.0%}")
        tot.update(s)
    n = tot["maps"] * reps
    print(f"{'전체':10s} {tot['maps']:5d} {tot['boxes'] / tot['maps']:5.1f} {tot['items'] / n:5.1f} {tot['caps'] / n:5.1f} {tot['dry'] / n:7.0%} "
          f"{tot['vis'] / max(1, tot['boxes'] * reps):8.0%} {tot['hit'] / max(1, tot['closed']):8.0%} {tot['enemy'] / tot['maps']:5.0%}")


if __name__ == "__main__":
    main()
