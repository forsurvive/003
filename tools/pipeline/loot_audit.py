"""파밍 v3 수치 점검(1-L 계획 §2 · §7): 생성 실내 전체를 게임과 같은 규칙으로 굴려(기대값) 결마다 평균 물건 · 캡 · 빈 실내 비율 · 보이는 빔 ·
닫힌 용기 적중률 · 적이 있는 실내 비율을 찍는다. 목표: 실내 한 곳 물건 3~5 · 캡 1~3 · 쓸 것 없는 실내 약 30% · 닫힌 용기 적중 약 50%.
쓰기: python3 tools/pipeline/loot_audit.py [--n 표본 수]

경제 곡선 v2 셈 몫(1-13j 조율사 보고 '라' · '마' — `docs/seoul-fallout/_plans/1-13j_econ_v2_auditor_report.md`): 같은 파일에
  · road — 1막 길 구간(route_time.LEGS)마다 걸어서 가는 길 15칸 안 월드 용기(pois.json, 맵 W)의 캡 · 물건 값 기대(용기 하나 200번 굴림)
           + 그 길에서 길 위 인카운터(RE)가 몇 번 설지(청크 경계 판정 · 위협도 확률표)와 RE 한 번의 적 전리품 기대
  · gen_enemy — 생성 실내 한 곳에 서 있는 적의 전리품 기대
를 함께 적는다. 전리품 = 소지 캡 × (1 + 0.03 × 레벨)(SD-15 §9.2) + 물건 값. 판매 몫 · 값 배율은 econ_curve.py가 곱한다."""
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
VAL = {}                                    # 물건 값(경제 곡선 v2 — D-399): 아이템 표 전부의 value
for fn in os.listdir(os.path.join(ROOT, "game", "data")):
    if fn.startswith("items_") and fn.endswith(".json"):
        d = json.load(open(os.path.join(ROOT, "game", "data", fn), encoding="utf-8"))
        for iid, it in (d.items() if isinstance(d, dict) else [(x.get("id"), x) for x in d]):
            if isinstance(it, dict) and it.get("value") is not None:
                VAL[iid] = float(it.get("value") or 0)


def value_of(iid):
    """한 개 값 — 풀(@weapon 등)은 1막 등급(1 · 2)의 평균, 탄 · 이름 행은 0(작다)"""
    if iid in VAL:
        return VAL[iid]
    if iid.startswith("@"):
        pool = L["pools"].get(iid[1:].split(":")[0], {})
        ids = [x for k in ("1", "2") for x in pool.get(k, [])]
        vs = [VAL[x] for x in ids if x in VAL]
        return sum(vs) / len(vs) if vs else 0.0
    return 0.0


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
        roll.value = 0.0
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
    roll.value = sum(value_of(i) * n for (i, n) in got if i != "M-001")
    items = sum(1 for (i, n) in got if i != "M-001" and not i.startswith("@ammo")) + sum(1 for (i, n) in got if i.startswith("@ammo"))
    return items, caps, not got, False


LV_MID = 5              # 1막 한가운데 레벨(프롤로그 끝 Lv2 → 1막 끝 Lv8) — 적 소지 캡 레벨 계수에 쓴다
ROAD_R = 15             # 길에서 이만큼 안의 용기를 '지나가며 여는' 후보로 본다(조율사 보고 라)
TIER_MAX = 2            # 1막 루팅 등급(R01 T1~2 · R02 T1~3, Lv7부터 +1 — 가운데로 2)


def drop_value(eid, lv=LV_MID, t=TIER_MAX):
    """쓰러진 적 하나에서 기대하는 (캡, 물건 값). 캡은 SD-15 §9.2 레벨 계수, 등급 칸(다섯째)이 지금 등급보다 높은 줄은 안 나온다"""
    caps = val = 0.0
    for r in L.get("drops", {}).get(eid, []):
        if len(r) > 4 and int(r[4]) > t:
            continue
        n = float(r[1]) * (float(r[2]) + float(r[3])) / 2.0
        if r[0] == "M-001":
            caps += n * (1.0 + 0.03 * lv)
        else:
            val += n * value_of(r[0])
    return caps, val


def group_value(groups, mix=()):
    """적대 무리 한 판의 기대 (캡, 물건 값) — units [CR, 최소, 최대] 가운데값 · mix [CR, 최소, 최대, 확률]"""
    caps = val = 0.0
    for g in groups:
        for u in g.get("units", []):
            n = (float(u[1]) + float(u[2])) / 2.0
            c, v = drop_value(u[0])
            caps += n * c
            val += n * v
    for m in mix:
        n = (float(m[1]) + float(m[2])) / 2.0 * float(m[3])
        c, v = drop_value(m[0])
        caps += n * c
        val += n * v
    return caps, val


def re_expect(enc, region):
    """그 권역에서 RE 한 번이 설 때 적대 무리 전리품 기대 — 범주 몫(cat_w, 권역 판도 상태) × 범주 안 RE 가중, 판(variants)은 고르게"""
    state = enc.get("region_state", {}).get(region, "경합")
    cw = enc["cat_w"].get(state, {})
    by_cat = collections.defaultdict(list)
    for rid, d in enc["re"].items():
        regs = d.get("regions", [])
        if (regs != "*" and region not in regs) or float(d.get("weight", 0)) <= 0:
            continue
        by_cat[d.get("cat", "")].append((rid, d))
    tot_w = sum(cw.get(c, 0) for c in by_cat)
    caps = val = 0.0
    for c, lst in by_cat.items():
        share = cw.get(c, 0) / max(1.0, tot_w)
        wsum = sum(float(d["weight"]) for _, d in lst)
        for rid, d in lst:
            vs = d.get("variants") or [{}]
            gc = gv = 0.0
            for v in vs:
                gs = [g for g in v.get("groups", d.get("groups", [])) if g.get("hostile", True)]
                a, b = group_value(gs, d.get("mix", []) if gs else [])
                gc += a / len(vs)
                gv += b / len(vs)
            caps += share * float(d["weight"]) / wsum * gc
            val += share * float(d["weight"]) / wsum * gv
    return caps, val


def road(reps=200):
    """1막 길 구간마다: 15칸 안 용기 수 · 캡 · 물건 값 기대(앞 구간에서 센 용기는 다시 세지 않는다) · RE 판정 기대 횟수 · RE 전리품 기대"""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import route_time as rt
    W = os.path.join(ROOT, "game", "data", "world")
    geo = json.load(open(os.path.join(W, "place_geo.json"), encoding="utf-8"))
    enc = json.load(open(os.path.join(W, "encounters.json"), encoding="utf-8"))
    places = json.load(open(os.path.join(W, "places.json"), encoding="utf-8"))
    pts = {k: tuple(geo[k]["arrive"]) for leg in rt.LEGS for k in leg[:2] if geo.get(k, {}).get("arrive")}
    xs = [p[0] for p in pts.values()]
    ys = [p[1] for p in pts.values()]
    box = (max(0, min(xs) - 120), max(0, min(ys) - 120), max(xs) + 120, max(ys) + 120)
    grid = rt.load(box)
    boxes = [b for b in json.load(open(os.path.join(W, "pois.json"), encoding="utf-8"))["boxes"]
             if b.get("owner", "") == "" and b["kind"] in V3["kinds"]]
    for sp in json.load(open(os.path.join(W, "spots_src.json"), encoding="utf-8"))["spots"]:   # 손 자리 용기(조건 없는 것 — 관악 비탈 깡통 등)
        for b in sp["data"].get("boxes", []):
            if b.get("owner", "") == "" and not b.get("cond") and b["kind"] in L["tables"]:
                boxes.append(dict(b, x=sp["tile"][0] + b["x"], y=sp["tile"][1] + b["y"], hand=True))
    sett = [(s[1], s[2]) for s in enc.get("settlements", [])]
    rnd = random.Random(2)
    seen = set()
    out = {}
    for a, b, _goal, name in rt.LEGS:
        if a not in pts or b not in pts:
            continue
        _c, path = rt.route(grid, (pts[a][0] - box[0], pts[a][1] - box[1]), (pts[b][0] - box[0], pts[b][1] - box[1]), False, True)
        path = [(x + box[0], y + box[1]) for x, y in path]
        near = []
        for i, bx in enumerate(boxes):
            if i in seen:
                continue
            if any((bx["x"] - x) ** 2 + (bx["y"] - y) ** 2 <= ROAD_R * ROAD_R for x, y in path[::2]):
                near.append(bx)
                seen.add(i)
        caps = val = 0.0
        for bx in near:
            if bx["kind"] not in V3["kinds"]:                            # 옛 굴림(Loot.roll — 빈 상자율 · 캡 배수 없음): 줄마다 확률 × 가운데값
                for r in L["tables"][bx["kind"]].get("rows", []):
                    n = float(r[1]) * (float(r[2]) + float(r[3])) / 2.0
                    if r[0] == "M-001":
                        caps += n
                    else:
                        val += n * value_of(r[0])
                continue
            b2 = dict(bx, pl=bx.get("pl", "road"))
            for _ in range(reps):
                _i, c, _e, _v = roll(b2, rnd)
                caps += c / reps
                val += roll.value / reps
        # RE 판정(Encounters.on_move): 청크 경계마다 steps += 1, 위협도 표 [n, p] — n번째 경계마다 확률 p. 정착지 2청크 안 · 위협 0은 없음.
        # 고요 누적(실패마다 +0.03, 최대 +0.15)은 평균 +0.06으로, 안전 간격(RE 뒤 두 번 건너뜀)은 1 / (1 + 2p)로 셈한다
        n_re = 0.0
        last = None
        steps = 0
        for x, y in path:
            k = (x // 40, y // 40)
            if k == last:
                continue
            if last is None:
                last = k
                continue
            last = k
            steps += 1
            row = enc["threat"][k[1]] if k[1] < len(enc["threat"]) else ""
            ch = row[k[0]] if k[0] < len(row) else "."
            if not ch.isdigit() or int(ch) == 0 or any(abs(sx // 40 - k[0]) <= 2 and abs(sy // 40 - k[1]) <= 2 for sx, sy in sett):
                continue
            nn, pp = enc["chance"][ch]
            if steps % int(nn) == 0:
                pe = min(0.6, float(pp) + 0.06)
                n_re += pe / (1.0 + 2.0 * pe)
        region = places.get(b, {}).get("region", "R01")
        rc, rv = re_expect(enc, region)
        out[name] = {"boxes": len(near), "caps": round(caps, 1), "value": round(val, 1), "re_n": round(n_re, 2),
                     "re_caps": round(n_re * rc, 1), "re_value": round(n_re * rv, 1), "tiles": len(path)}
        print(f"  길 {name}: {len(path)}칸 · 15칸 안 용기 {len(near)} · 캡 {caps:.0f} · 물건 값 {val:.0f} · RE {n_re:.2f}번 · RE 전리품 캡 {n_re * rc:.0f} · 값 {n_re * rv:.0f}")
    return out


def gen_enemy():
    """생성 실내 한 곳에 서 있는 적 전리품 기대 (캡, 물건 값)"""
    idx = json.load(open(os.path.join(MAPS, "_index.json"), encoding="utf-8"))["maps"]
    blob = open(os.path.join(MAPS, "gen.bin"), "rb").read()
    caps = val = 0.0
    n = 0
    for mid, m in idx.items():
        if not mid.startswith("G-"):
            continue
        o, ln, _ = m["pack"]
        d = json.loads(zlib.decompress(blob[o:o + ln]))
        n += 1
        for e in d.get("enemies", []):
            c, v = drop_value(e["id"])
            caps += c
            val += v
    return caps / max(1, n), val / max(1, n)


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
                s["value"] += roll.value
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
    print(f"실내 한 곳 물건 값(판매 전 · 경제 곡선 v2 D-399): 전체 평균 {tot['value'] / n:.1f}캡 · 집 {S['home']['value'] / max(1, S['home']['maps'] * reps):.1f}")
    gc, gv = gen_enemy()
    print(f"생성 실내 한 곳 적 전리품 기대: 캡 {gc:.1f} · 물건 값 {gv:.1f}(Lv{LV_MID} 레벨 계수)")
    rd = road()
    json.dump({"per_interior_caps": tot["caps"] / n, "per_interior_value": tot["value"] / n, "dry": tot["dry"] / n,
               "gen_enemy_caps": round(gc, 2), "gen_enemy_value": round(gv, 2), "road": rd, "lv": LV_MID},
              open(os.path.join(ROOT, "game", "data", "_loot_audit.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{'전체':10s} {tot['maps']:5d} {tot['boxes'] / tot['maps']:5.1f} {tot['items'] / n:5.1f} {tot['caps'] / n:5.1f} {tot['dry'] / n:7.0%} "
          f"{tot['vis'] / max(1, tot['boxes'] * reps):8.0%} {tot['hit'] / max(1, tot['closed']):8.0%} {tot['enemy'] / tot['maps']:5.0%}")


if __name__ == "__main__":
    main()
