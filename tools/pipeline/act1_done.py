"""1막 완료 기준 묶음 실행기(단계 1-13 · SD-19 §5 완료 기준 ① ② ④ — 계획 `_plans/1-13_closing_plan.md` §1).
지하시장 봇(`game/scenes/bench/jm_bot.tscn`)의 갈래를 기준별로 묶어 돌리고, 갈래마다 마지막 요약 줄
'지하시장 봇 갈래: ○|× 맞음/전체 …'과 SCRIPT ERROR 수를 모아 기준마다 판정한다.

  ① 1막 3경로 각각 K_CODE: MQ-103(job · vent · hack · fee) · MQ-104(yd_talk · yd_fight · yd_vent) · MQ-105(sb_buy · sb_deal · sb_raid · sb_roof · sb_jo · sb_south)
     → MQ-106 해법 여섯(vb_talk · vb_walk · vb_fight · vb_hide · vb_cargo · vb_capture) — 막 전환까지
  ② 생포 → 연행 → 압수 → 탈출: sb_capture · vb_capture (같은 길을 3번 — 씨앗이 달라지는 갈래는 아니라 '3회 연속 막힘 없음')
  ④ 반복 의뢰: rq · rqb(각 3회 연속은 갈래 안에서)

결과: game/data/_act1_done.md · .json. 봇이 느려(갈래당 1~10분) 빌드에는 넣지 않는다:
    python3 tools/pipeline/act1_done.py [--only 1,2,4] [--jobs 2] [--timeout 600]
"""
import argparse
import json
import os
import re
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "data", "_act1_done")
CRIT = {
    "1": ("1막 3경로 → K_CODE → MQ-106 막 전환", ["job", "vent", "hack", "fee", "yd_talk", "yd_fight", "yd_vent",
                                               "sb_buy", "sb_deal", "sb_raid", "sb_roof", "sb_jo", "sb_south",
                                               "vb_talk", "vb_walk", "vb_fight", "vb_hide", "vb_cargo", "vb_capture"], 1),
    "2": ("생포 → 연행 → 압수 → 탈출(3회 연속)", ["sb_capture", "vb_capture"], 3),
    "4": ("반복 의뢰 10편 각 3회 연속", ["rq", "rqb"], 1),
}
LINE = re.compile(r"봇 (?P<r>[a-z_0-9]+): (?P<ok>[○×]) (?P<a>\d+)/(?P<b>\d+)")


def run(route, timeout):
    t0 = time.time()
    try:
        out = subprocess.run(["godot", "--headless", "--path", os.path.join(ROOT, "game"), "res://scenes/bench/jm_bot.tscn", "--", route],
                             capture_output=True, text=True, timeout=timeout).stdout
        why = ""
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        why = "시간 초과"
    m = None
    for m in LINE.finditer(out):
        pass
    errs = out.count("SCRIPT ERROR")
    ok = m is not None and m["ok"] == "○" and errs == 0 and why == ""
    return {"route": route, "ok": ok, "pass": "%s/%s" % (m["a"], m["b"]) if m else "-", "errors": errs,
            "why": why or ("요약 줄 없음" if m is None else ("" if ok else "확인 실패")), "secs": round(time.time() - t0)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="1,2,4")
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--timeout", type=int, default=600)
    a = ap.parse_args()
    keys = [k for k in a.only.split(",") if k in CRIT]
    todo = []
    for k in keys:
        for r in CRIT[k][1]:
            todo += [(k, r, i) for i in range(CRIT[k][2])]
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        res = list(ex.map(lambda x: dict(run(x[1], a.timeout), crit=x[0], n=x[2] + 1), todo))
    when = time.strftime("%Y-%m-%d %H:%M")
    verdict = {k: all(r["ok"] for r in res if r["crit"] == k) for k in keys}
    json.dump({"when": when, "verdict": verdict, "rows": res}, open(OUT + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    md = ["# 1막 완료 기준 묶음 실행(SD-19 §5 · `tools/pipeline/act1_done.py`)", "", "측정 %s" % when, ""]
    for k in keys:
        md += ["## 기준 %s %s — %s" % (k, CRIT[k][0], "통과" if verdict[k] else "실패"), "",
               "| 갈래 | 회 | 판정 | 확인 | 오류 | 초 | 메모 |", "|---|---|---|---|---|---|---|"]
        for r in [r for r in res if r["crit"] == k]:
            md.append("| %s | %d | %s | %s | %d | %d | %s |" % (r["route"], r["n"], "○" if r["ok"] else "×", r["pass"], r["errors"], r["secs"], r["why"]))
        md.append("")
    open(OUT + ".md", "w", encoding="utf-8").write("\n".join(md) + "\n")
    print("1막 완료 기준: " + " · ".join("%s %s" % (k, "통과" if verdict[k] else "실패") for k in keys) + " (game/data/_act1_done.md)")
    for r in res:
        if not r["ok"]:
            print("   ×", r["crit"], r["route"], r["n"], r["pass"], r["why"], "오류 %d" % r["errors"])


if __name__ == "__main__":
    main()
