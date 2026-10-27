"""1막 경제 곡선(단계 1-13c, SD-15 §9.1 구간 Ⅰ · SD-25 B6): 봇 체인을 실제로 돌려 '캡 · 누적 수입 · XP · 레벨'을 모은다.

봇은 진짜 맵 · 대화 · 전투 · 거래 위에서 걷는다. 누적 수입 CAPS_EARNED는 캡이 늘 때마다 엔진이 센다(퀘스트 · 루팅 · 거래 모든 길).
기록 줄: 봇이 찍는 'ECON|지점|해법 n|캡 n|누적 n|XP n|Lv n|날 n'.
지금 지점: MQ-101 끝(프롤로그 → 첫 풍경 → MQ-101 해법 1~4, --from=view --chain --sol=N).
결과: game/data/_econ_curve.json — balance_check.py B6이 읽어 SD-15 구간 Ⅰ(보유 150~500 · 누적 1,500~2,500 by Lv6)과 대 본다.

봇이 느려 빌드에는 넣지 않는다 — 경제 · 보상을 바꾼 뒤 손으로 돌린다:
    python3 tools/pipeline/econ_curve.py [--sols 1,2,3,4] [--timeout 900]

v2(1-13j · D-399 — 계획 `docs/seoul-fallout/_plans/1-13j_econ_v2_plan.md`): 보통 플레이어 합성 곡선.
지하시장 봇 갈래마다 '번 캡 · 쓴 캡 · XP · 날'(ECONSEG 줄)을 재서 game/data/_econ_segs.json에 모으고(--segs),
MQ-101 끝(v1 기록) → MQ-102 허브 → 경로 하나(103 · 104 · 105) → MQ-106 → 사이드 · 세력 · 비표시 · 반복 · 던전 절반 + 길가 실내 루팅 셈으로 잇는다.
    python3 tools/pipeline/econ_curve.py --segs [--jobs 2] [--timeout 600]   # 조각 재기(느림 — 갈래 40여)
    python3 tools/pipeline/econ_curve.py --compose                          # 이어 붙이기만(빠름)
"""
import argparse
import json
import os
import re
import subprocess
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "data", "_econ_curve.json")
LINE = re.compile(r"ECON\|(?P<at>[^|]+)\|해법 (?P<sol>\d+)\|캡 (?P<caps>-?\d+)\|누적 (?P<earned>\d+)\|XP (?P<xp>\d+)\|Lv (?P<lv>\d+)\|날 (?P<day>\d+)")


def run(sol, timeout):
    cmd = ["godot", "--headless", "--path", os.path.join(ROOT, "game"), "res://scenes/story/prologue.tscn", "--",
           "--auto", "--from=view", "--chain", "--sol=%d" % sol]
    t0 = time.time()
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
    rows = []
    for m in LINE.finditer(out):
        r = {k: (m.group(k) if k == "at" else int(m.group(k))) for k in LINE.groupindex}
        r["secs"] = round(time.time() - t0)
        rows.append(r)
    return rows


SEGS = os.path.join(ROOT, "game", "data", "_econ_segs.json")
SEG = re.compile(r"ECONSEG\|(?P<route>[a-z_0-9]+)\|(?P<ok>[○×])\|캡 (?P<caps>-?\d+)\|번 캡 (?P<earned>\d+)\|쓴 캡 (?P<spent>\d+)\|XP (?P<xp>-?\d+)\|날 (?P<day>-?\d+)(?:\|처치 (?P<kills>[A-Z0-9:,-]*))?")
# 메인 행로: 허브 → 경로(돈 드는 길 · 돈 안 드는 길 — 둘 다 그린다) → MQ-106 말로
MAIN = {"MQ-102": "hub", "MQ-106": "vb_talk"}
PATHS = {"MQ-103 일 맡기(출입세 · 박춘삼 100캡)": ("MQ-103", "job"), "MQ-103 환풍구(무료)": ("MQ-103", "vent"),
         "MQ-104 말로(무료)": ("MQ-104", "yd_talk"),
         "MQ-105 구매자 위장(보증금 500 · 88번 300 — 고르는 지출)": ("MQ-105", "sb_buy"), "MQ-105 옥상 길(무료)": ("MQ-105", "sb_roof")}
PRO_XP = 475            # '첫 풍경' 시작점(--from=view)은 MQ-P1~P4 XP를 건너뛴다 — 프롤로그부터 전체 봇 MQ-101 끝 920 − 첫 풍경 봇 445(1-13j 실측)
# 사이드류(퀘스트마다 갈래 하나): 보통 플레이어는 이 가운데 절반을 한다(SD-25 '메인 + 사이드 · 탐험 절반')
SIDE = {"SQ-S01": "bw", "SQ-S02": "bs", "SQ-S03": "s3", "SQ-S05": "s5", "SQ-S06": "s6", "SQ-S08": "s8", "SQ-S09": "s9", "SQ-S10": "s10",
        "SQ-S11": "s11", "SQ-S12": "s12", "SQ-S13": "s13", "FQ-JC-01": "jc01", "FQ-GS-01": "gs01", "FQ-GS-02": "gs02", "FQ-JH-01": "jh01",
        "FQ-JH-02": "jh02", "FQ-JH-03": "jh03", "FQ-SB-02": "sb02f", "UQ-05": "uq05", "UQ-07": "uq07", "UQ-08": "uq08", "UQ-09": "uq09",
        "UQ-10": "uq10", "UQ-62": "uq62", "UQ-63": "uq63", "UQ-64": "uq64", "UQ-65": "uq65", "UQ-66": "uq66", "UQ-67": "uq67", "UQ-70": "uq70",
        "UQ-71": "db", "UQ-04": "ds", "UQ-68": "kt", "UQ-69": "ks", "UQ-126": "hosp", "UQ-06": "yt", "U04": "u04", "RQ(한 주)": "rq"}
INTERIORS = 40          # 보통 플레이어가 1막 동안 퀘스트 밖에서 여는 길가 실내(하루 약 5곳 × 8일 — 계획 §1 '하루 6곳'을 이 값으로 맞춤)
# 1-13j 조율사 보고(_plans/1-13j_econ_v2_auditor_report.md) 도구 고침 — 아래는 봇이 재지 못하는 몫의 '셈'(측정 아님)
SEG_FLOWS = {"sb_buy": 500, "sb_deal": 500}   # 나: 보증금 환불(앞서 낸 돈이 돌아온 것 — 수입 아님, balance_check.FLOWS MQ-105와 같은 뜻)
OPEN_BOX = 0.6          # 라: 길 15칸 안 월드 용기를 지나가며 여는 몫
OPEN_CORPSE = 0.9       # 마: 쓰러뜨린 적 유해를 여는 몫
FIGHT = 0.7             # 마: 마주친 적대 무리와 실제로 싸우는 몫(피하기 · 말 · 달아남 뺌) — 길 위 RE · 생성 실내 적
EXPLORE_TILES = 30      # 마: 길가 실내 한 곳을 들르려 주요 길에서 벗어나 걷는 칸(RE 판정이 그만큼 더 선다)
# 라 · 마: 1막 길 구간(loot_audit road)이 행로의 어느 지점 몫인가 — 노량진 · 수산시장 길은 사이드(절반)
ROAD_AT = {"MQ-101": ["볼트 → 봉천"], "MQ-102": ["봉천 → 영등포 지하시장"], "MQ-104": ["지하시장 → 여의도 벙커"],
           "MQ-105": ["지하시장 → 새벽인력 본소"], "MQ-103": [], "MQ-106": [],
           "end": ["봉천 → 노량진(24)", "봉천 → 노량진(25)", "지하시장 → 수산시장(FQ-JH-03 지상 배달)"]}
SELL_SHARE = 0.5        # 주운 물건 가운데 파는 몫(나머지는 쓴다)
SELL_RATE = 0.585       # 물물교환 30 판매가 배율(0.45 + 0.45 × 0.3 — SD-15 §4)


def run_seg(route, timeout):
    cmd = ["godot", "--headless", "--path", os.path.join(ROOT, "game"), "res://scenes/bench/jm_bot.tscn", "--", route]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
    m = None
    for m in SEG.finditer(out):
        pass
    if m is None:
        return {"route": route, "ok": False}
    r = {k: (m.group(k) if k in ("route", "ok", "kills") else int(m.group(k))) for k in SEG.groupindex}
    r["ok"] = r["ok"] == "○"
    r["kills"] = {kv.split(":")[0]: int(kv.split(":")[1]) for kv in (r.get("kills") or "").split(",") if ":" in kv}
    return r


def measure(jobs, timeout, fresh=False):
    from concurrent.futures import ThreadPoolExecutor
    old = json.load(open(SEGS, encoding="utf-8")).get("rows", {}) if os.path.exists(SEGS) and not fresh else {}
    # act1_done.py가 이미 잰 메인 갈래 조각은 다시 돌리지 않는다
    done = os.path.join(ROOT, "game", "data", "_act1_done.json")
    if os.path.exists(done) and not fresh:
        for r in json.load(open(done, encoding="utf-8")).get("rows", []):
            if r.get("econ") and r.get("ok"):
                old[r["route"]] = dict(r["econ"], route=r["route"], ok=True)
    todo = [rt for rt in list(MAIN.values()) + [v[1] for v in PATHS.values()] + list(SIDE.values()) if not old.get(rt, {}).get("ok")]
    with ThreadPoolExecutor(max_workers=jobs) as ex:
        for r in ex.map(lambda rt: run_seg(rt, timeout), todo):
            old[r["route"]] = r
            print("  조각 %s: %s" % (r["route"], "번 캡 %d · XP %d" % (r["earned"], r["xp"]) if r.get("ok") else "× (조각 없음 · 실패)"))
    json.dump({"rows": old, "when": time.strftime("%Y-%m-%d %H:%M")}, open(SEGS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def _seg_kill_loot(sg):
    """마: 그 조각에서 봇이 쓰러뜨린 적의 유해 기대(봇은 유해를 열지 않는다) — (캡, 판 값)"""
    import loot_audit as la
    c = v = 0.0
    for eid, n in (sg.get("kills") or {}).items():
        a, b = la.drop_value(eid)
        c += n * a
        v += n * b
    return c * OPEN_CORPSE, v * OPEN_CORPSE * SELL_SHARE * SELL_RATE


def compose():
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import balance_check as bc
    segs = json.load(open(SEGS, encoding="utf-8"))["rows"]
    base = json.load(open(OUT, encoding="utf-8"))
    v1 = [r for r in base.get("rows", []) if r.get("at") == "MQ-101"]
    loot = json.load(open(os.path.join(ROOT, "game", "data", "_loot_audit.json"), encoding="utf-8"))
    sell = SELL_SHARE * SELL_RATE
    gen_e = FIGHT * OPEN_CORPSE * (loot.get("gen_enemy_caps", 0.0) + loot.get("gen_enemy_value", 0.0) * sell)
    per_int = loot["per_interior_caps"] + loot["per_interior_value"] * sell + gen_e
    rd = loot.get("road", {})
    re_rate = sum(r["re_n"] for r in rd.values()) / max(1, sum(r["tiles"] for r in rd.values()))
    re_one = (sum(r["re_caps"] for r in rd.values()) + sum(r["re_value"] for r in rd.values()) * sell) / max(0.01, sum(r["re_n"] for r in rd.values()))
    def road_at(key):
        """라 · 마: 그 지점 몫 길의 용기(여는 몫) + RE 적 전리품(싸우는 몫 · 유해 여는 몫)"""
        t = 0.0
        for leg in ROAD_AT.get(key, []):
            r = rd.get(leg, {})
            t += OPEN_BOX * (r.get("caps", 0) + r.get("value", 0) * sell)
            t += FIGHT * OPEN_CORPSE * (r.get("re_caps", 0) + r.get("re_value", 0) * sell)
        return t
    # 다: 사이드 조각이 보상 지급 전에 끝난다(다음 방문 · 다음 날 보상) — 퀘스트마다 max(조각 번 캡 − 흐름, 보상표 캡(흐름 뺌))
    rw = bc.code_rewards(bc.script_rewards())
    def reward_caps(q):
        return 0 if q in bc.FLOWS else int(rw.get(q, {}).get("caps", 0))
    side = {}
    for q, rt in SIDE.items():
        sg = segs.get(rt, {})
        kc, kv = _seg_kill_loot(sg) if sg.get("ok") else (0.0, 0.0)
        if sg.get("ok"):
            got = int(sg["earned"]) - SEG_FLOWS.get(rt, 0)
            fill = max(got, reward_caps(q)) if q != "RQ(한 주)" else got
            side[q] = {"caps": int(sg["caps"]) + (fill - got) - SEG_FLOWS.get(rt, 0) + kc + kv, "earned": fill + kc + kv, "xp": int(sg["xp"]),
                       "kill": kc + kv, "fill": fill - got, "src": "조각" + (" + 보상표" if fill > got else "")}
        elif reward_caps(q) > 0:
            side[q] = {"caps": reward_caps(q), "earned": reward_caps(q), "xp": 0, "kill": 0.0, "fill": reward_caps(q), "src": "보상표(조각 실패)"}
    side_ok = [q for q, rt in SIDE.items() if segs.get(rt, {}).get("ok")]
    side_miss = [q for q, rt in SIDE.items() if not segs.get(rt, {}).get("ok")]
    half = lambda k: sum(float(d[k]) for d in side.values()) / 2.0
    db = bc.items_db()                                                   # 소모 지출: SD-15 §9.1 '이 구간에 살 수 있어야 하는 것'(스팀팩 5 · 위조 등록증 · 정화수 10, 물물교환 30)을 1막 동안 산다고 본다
    basket = 5 * bc.price_of(db["I-001"]["value"], True, 30) + bc.price_of(db["M-062"]["value"], True, 30) + 10 * bc.price_of(db["I-057"]["value"], True, 30)
    explore = INTERIORS * EXPLORE_TILES * re_rate * re_one * FIGHT * OPEN_CORPSE   # 마: 실내를 들르러 벗어난 걸음에서 서는 RE
    out = []
    # 길가 실내(퀘스트 밖) 루팅은 행로를 따라 나눠 든다: 허브까지 8곳 · 경로 12곳 · MQ-106까지 4곳 · 1막 남은 사이드 동안 16곳(계획 §1 — 하루 약 5곳)
    share = {"MQ-102": 8, "path": 12, "MQ-106": 4, "end": INTERIORS - 24}
    first = []
    for r in sorted(v1, key=lambda r: r["sol"]):                          # MQ-101 끝(해법마다): 봇 실측 + 볼트 → 봉천 길가 용기 셈
        first.append({"sol": r["sol"], "caps": round(r["caps"] + road_at("MQ-101")), "earned": round(r["earned"] + road_at("MQ-101")), "bot_caps": r["caps"]})
    r0 = [r for r in v1 if r["sol"] == 1][0]                             # 계단 방어(가장 흔한 해법)
    for name, (q, rt) in PATHS.items():
        sg_path = segs.get(rt, {})
        if not sg_path.get("ok"):
            continue
        ra = road_at("MQ-101")
        caps, earned, xp = float(r0["caps"]) + ra, float(r0["earned"]) + ra, float(r0["xp"]) + PRO_XP
        est = ra                                                            # 셈 몫(조율사 보고 라 · 마 — 측정이 아닌 길가 용기 · 전리품 · 탐험 걸음 RE)
        pts = [{"at": "MQ-101 끝", "caps": caps, "earned": earned, "xp": xp}]
        low = caps
        for key, sg in (("MQ-102", segs.get(MAIN["MQ-102"], {})), ("path", sg_path), ("MQ-106", segs.get(MAIN["MQ-106"], {}))):
            if not sg.get("ok"):
                break
            at = q if key == "path" else key
            add = share[key] * per_int + road_at(at)
            kc, kv = _seg_kill_loot(sg)
            fl = SEG_FLOWS.get(sg.get("route", ""), 0)
            caps += add
            earned += add
            est += road_at(at) + share[key] * gen_e + kc + kv
            low = min(low, caps - sg["spent"])                              # 그 길에서 돈을 내는 순간의 잔고(길가 루팅을 먼저 했다고 봄)
            caps += sg["caps"] + kc + kv
            earned += sg["earned"] - fl + kc + kv
            xp += sg["xp"]
            pts.append({"at": at, "caps": caps, "earned": earned, "xp": xp})
        add = share["end"] * per_int + road_at("end") / 2.0 + explore
        caps_end = caps + half("caps") + add - basket
        earned_end = earned + half("earned") + add
        est += road_at("end") / 2.0 + share["end"] * gen_e + explore + half("kill")
        xp_end = xp + half("xp")
        pts.append({"at": "1막 끝(사이드류 절반 + 길가 실내 %d곳)" % INTERIORS, "caps": caps_end, "earned": earned_end, "xp": xp_end})
        avg = sum(p["caps"] for p in pts) / len(pts)
        out.append({"path": name, "sol": r0["sol"], "low": round(low), "avg": round(avg), "est_pct": round(100.0 * est / max(1.0, earned_end)),
                    "points": [dict(p, caps=round(p["caps"]), earned=round(p["earned"]), xp=round(p["xp"])) for p in pts]})
    quest_end = sum(float(sg.get("earned", 0)) for sg in (segs.get(MAIN["MQ-102"], {}), segs.get(MAIN["MQ-106"], {}))) + half("earned")
    v2 = {"when": time.strftime("%Y-%m-%d %H:%M"), "per_interior": round(per_int, 1), "interiors": INTERIORS,
          "side_used": side_ok, "side_missing": side_miss, "side": {q: {k: round(v) if isinstance(v, float) else v for k, v in d.items()} for q, d in side.items()},
          "first": first, "basket": round(basket), "road": {k: round(road_at(k)) for k in ROAD_AT}, "explore_re": round(explore), "curves": out,
          "assume": {"OPEN_BOX": OPEN_BOX, "OPEN_CORPSE": OPEN_CORPSE, "FIGHT": FIGHT, "EXPLORE_TILES": EXPLORE_TILES, "SELL": round(sell, 3)}}
    base["v2"] = v2
    json.dump(base, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for f in first:
        print("MQ-101 끝 해법 %d: 봇 보유 %d → 볼트 → 봉천 길가 용기 셈 더해 %d" % (f["sol"], f["bot_caps"], f["caps"]))
    for c in out:
        print("경제 곡선 v2 %s: 가장 낮은 잔고 %d · 평균 보유 %d · 셈 몫 %d%% · " % (c["path"], c["low"], c["avg"], c["est_pct"])
              + " → ".join("%s 캡 %d · 누적 %d · XP %d" % (p["at"], p["caps"], p["earned"], p["xp"]) for p in c["points"]))
    print("사이드류 조각 %d · 없음 %d(%s) · 실내 한 곳 %.1f캡(적 전리품 %.1f 포함) · 탐험 걸음 RE %.0f · 장바구니 지출 %d" % (len(side_ok), len(side_miss), " ".join(side_miss), per_int, gen_e, explore, basket))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sols", default="1,2,3,4")
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--segs", action="store_true")
    ap.add_argument("--compose", action="store_true")
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--fresh", action="store_true", help="--segs: 이미 잰 조각도 다시(처치 수를 새로 받을 때)")
    a = ap.parse_args()
    if a.segs:
        measure(a.jobs, min(a.timeout, 600), a.fresh)
        compose()
        return
    if a.compose:
        compose()
        return
    rows = []
    for s in [int(x) for x in a.sols.split(",") if x]:
        got = run(s, a.timeout)
        if not got:
            print("경제 곡선: 해법 %d — 기록 줄 없음(봇이 끝나지 않음)" % s)
        rows += got
    json.dump({"rows": rows, "when": time.strftime("%Y-%m-%d %H:%M")}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for r in rows:
        print("경제 곡선 %s 해법 %d: 캡 %d · 누적 %d · XP %d · Lv %d · %d일째" % (r["at"], r["sol"], r["caps"], r["earned"], r["xp"], r["lv"], r["day"]))
    print("경제 곡선: 기록 %d줄 → %s" % (len(rows), os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
