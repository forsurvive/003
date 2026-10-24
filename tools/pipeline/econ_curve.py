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
SEG = re.compile(r"ECONSEG\|(?P<route>[a-z_0-9]+)\|(?P<ok>[○×])\|캡 (?P<caps>-?\d+)\|번 캡 (?P<earned>\d+)\|쓴 캡 (?P<spent>\d+)\|XP (?P<xp>-?\d+)\|날 (?P<day>-?\d+)")
# 메인 행로(경로마다 하나 — 가장 흔한 길): 허브 → 경로 → MQ-106 말로
MAIN = {"MQ-102": "hub", "MQ-103": "job", "MQ-104": "yd_talk", "MQ-105": "sb_buy", "MQ-106": "vb_talk"}
# 사이드류(퀘스트마다 갈래 하나): 보통 플레이어는 이 가운데 절반을 한다(SD-25 '메인 + 사이드 · 탐험 절반')
SIDE = {"SQ-S01": "bw", "SQ-S02": "bs", "SQ-S03": "s3", "SQ-S05": "s5", "SQ-S06": "s6", "SQ-S08": "s8", "SQ-S09": "s9", "SQ-S10": "s10",
        "SQ-S11": "s11", "SQ-S12": "s12", "SQ-S13": "s13", "FQ-JC-01": "jc01", "FQ-GS-01": "gs01", "FQ-GS-02": "gs02", "FQ-JH-01": "jh01",
        "FQ-JH-02": "jh02", "FQ-JH-03": "jh03", "FQ-SB-02": "sb02f", "UQ-05": "uq05", "UQ-07": "uq07", "UQ-08": "uq08", "UQ-09": "uq09",
        "UQ-10": "uq10", "UQ-62": "uq62", "UQ-63": "uq63", "UQ-64": "uq64", "UQ-65": "uq65", "UQ-66": "uq66", "UQ-67": "uq67", "UQ-70": "uq70",
        "UQ-71": "db", "UQ-04": "ds", "UQ-68": "kt", "UQ-69": "ks", "UQ-126": "hosp", "UQ-06": "yt", "U04": "u04", "RQ(한 주)": "rq"}
INTERIORS = 40          # 보통 플레이어가 1막 동안 퀘스트 밖에서 여는 길가 실내(하루 약 5곳 × 8일 — 계획 §1 가정)
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
    r = {k: (m.group(k) if k in ("route", "ok") else int(m.group(k))) for k in SEG.groupindex}
    r["ok"] = r["ok"] == "○"
    return r


def measure(jobs, timeout):
    from concurrent.futures import ThreadPoolExecutor
    old = json.load(open(SEGS, encoding="utf-8")).get("rows", {}) if os.path.exists(SEGS) else {}
    # act1_done.py가 이미 잰 메인 갈래 조각은 다시 돌리지 않는다
    done = os.path.join(ROOT, "game", "data", "_act1_done.json")
    if os.path.exists(done):
        for r in json.load(open(done, encoding="utf-8")).get("rows", []):
            if r.get("econ") and r.get("ok"):
                old[r["route"]] = dict(r["econ"], route=r["route"], ok=True)
    todo = [rt for rt in list(MAIN.values()) + list(SIDE.values()) if not old.get(rt, {}).get("ok")]
    with ThreadPoolExecutor(max_workers=jobs) as ex:
        for r in ex.map(lambda rt: run_seg(rt, timeout), todo):
            old[r["route"]] = r
            print("  조각 %s: %s" % (r["route"], "번 캡 %d · XP %d" % (r["earned"], r["xp"]) if r.get("ok") else "× (조각 없음 · 실패)"))
    json.dump({"rows": old, "when": time.strftime("%Y-%m-%d %H:%M")}, open(SEGS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def compose():
    segs = json.load(open(SEGS, encoding="utf-8"))["rows"]
    base = json.load(open(OUT, encoding="utf-8"))
    v1 = [r for r in base.get("rows", []) if r.get("at") == "MQ-101"]
    loot = json.load(open(os.path.join(ROOT, "game", "data", "_loot_audit.json"), encoding="utf-8"))
    per_int = loot["per_interior_caps"] + loot["per_interior_value"] * SELL_SHARE * SELL_RATE
    side_ok = [q for q, rt in SIDE.items() if segs.get(rt, {}).get("ok")]
    side_miss = [q for q, rt in SIDE.items() if not segs.get(rt, {}).get("ok")]
    half = lambda k: sum(int(segs[SIDE[q]][k]) for q in side_ok) / 2.0
    out = []
    for path in ("MQ-103", "MQ-104", "MQ-105"):
        for r0 in v1:
            caps, earned, xp = float(r0["caps"]), float(r0["earned"]), float(r0["xp"])
            pts = [{"at": "MQ-101", "caps": caps, "earned": earned, "xp": xp}]
            ok = True
            for q in ("MQ-102", path, "MQ-106"):
                sg = segs.get(MAIN[q], {})
                if not sg.get("ok"):
                    ok = False
                    break
                caps += sg["caps"]
                earned += sg["earned"]
                xp += sg["xp"]
                pts.append({"at": q, "caps": caps, "earned": earned, "xp": xp})
            if not ok:
                continue
            # 1막 끝: 사이드류 절반 + 길가 실내(퀘스트 밖)
            caps_end = caps + half("caps") + INTERIORS * per_int
            earned_end = earned + half("earned") + INTERIORS * per_int
            xp_end = xp + half("xp")
            pts.append({"at": "1막 끝(사이드류 절반 + 길가 실내 %d곳)" % INTERIORS, "caps": caps_end, "earned": earned_end, "xp": xp_end})
            out.append({"path": path, "sol": r0["sol"], "points": [dict(p, caps=round(p["caps"]), earned=round(p["earned"]), xp=round(p["xp"])) for p in pts]})
    v2 = {"when": time.strftime("%Y-%m-%d %H:%M"), "per_interior": round(per_int, 1), "interiors": INTERIORS,
          "side_used": side_ok, "side_missing": side_miss, "curves": out,
          "quest_share": round((half("earned")) / max(1.0, half("earned") + INTERIORS * per_int), 2)}
    base["v2"] = v2
    json.dump(base, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for c in out:
        print("경제 곡선 v2 %s(MQ-101 해법 %d): " % (c["path"], c["sol"]) + " → ".join("%s 캡 %d · 누적 %d · XP %d" % (p["at"], p["caps"], p["earned"], p["xp"]) for p in c["points"]))
    print("사이드류 조각 %d · 없음 %d(%s) · 실내 한 곳 %.1f캡" % (len(side_ok), len(side_miss), " ".join(side_miss), per_int))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sols", default="1,2,3,4")
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--segs", action="store_true")
    ap.add_argument("--compose", action="store_true")
    ap.add_argument("--jobs", type=int, default=2)
    a = ap.parse_args()
    if a.segs:
        measure(a.jobs, min(a.timeout, 600))
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
