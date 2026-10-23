"""밀집 장면 CPU 시간 기록(단계 1-13f, SD-19 §10.4 성능 예산): 지하시장(J-01 · J-02 · J-03)을 헤드리스로 열고 주인공을 걸리며
프레임마다 CPU 시간(스크립트 · AI · 경로 · 물리 — 헤드리스는 렌더 없이 무제한으로 돌아 프레임 사이 실제 시간이 곧 CPU 몫)을 잰다.

예산(PC 60fps · 프레임 16.6ms 가운데 렌더 제출 4ms · 여유 2ms를 뺀 몫): 평균 10.6ms 이하 · 1% 최악 16ms 이하(최저 50fps = 20ms − 렌더 4).
헤드리스라 렌더 · 드로 콜은 재지 않는다(실기기 몫 — SD-19 §10.4 측정 보고서). 이 컨테이너 CPU는 기준 기기(D-P2)와 달라 '추세 기록'이다.
결과: game/data/_perf_report.md · .json. 빌드에는 넣지 않는다(봇이 느림):
    python3 tools/pipeline/perf_check.py [--frames 1200]
"""
import argparse
import json
import os
import re
import subprocess
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "data", "_perf_report")
SCENES = [("J-01", "from_W", "-", 0), ("J-02", "from_J-01", "-", 0), ("J-02", "from_J-01", "-", 3), ("J-03", "from_J-02", "-", 0)]
AVG_MAX, P99_MAX = 10.6, 16.0
LINE = re.compile(r"PERF\|(?P<map>[^|]+)\|(?P<n>\d+)\|(?P<avg>[\d.]+)\|(?P<p99>[\d.]+)\|(?P<max>[\d.]+)")


def run(mid, mark, at, prog, frames):
    cmd = ["godot", "--headless", "--path", os.path.join(ROOT, "game"), "res://scenes/bench/jm_check.tscn", "--",
           mid, mark, at, str(prog), "perf=%d" % frames]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=600).stdout
    except subprocess.TimeoutExpired:
        return None
    m = LINE.search(out)
    return {"map": m["map"], "prog": prog, "people": int(m["n"]), "avg": float(m["avg"]), "p99": float(m["p99"]), "max": float(m["max"])} if m else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", type=int, default=1200)
    a = ap.parse_args()
    rows = []
    for mid, mark, at, prog in SCENES:
        r = run(mid, mark, at, prog, a.frames)
        if r is None:
            rows.append({"map": mid, "prog": prog, "fail": "측정 줄 없음"})
            continue
        r["judge"] = "통과" if r["avg"] <= AVG_MAX and r["p99"] <= P99_MAX else ("주의" if r["avg"] <= AVG_MAX * 1.25 else "실패")
        rows.append(r)
    when = time.strftime("%Y-%m-%d %H:%M")
    json.dump({"when": when, "frames": a.frames, "rows": rows, "budget": {"avg": AVG_MAX, "p99": P99_MAX}},
              open(OUT + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    md = ["# 밀집 장면 CPU 시간(1-13f · SD-19 §10.4)", "", "측정 %s · 프레임 %d · 헤드리스(렌더 제외) — 예산 평균 %.1fms · 1%% 최악 %.0fms" % (when, a.frames, AVG_MAX, P99_MAX), "",
          "| 판정 | 맵(진행) | 인물 | 평균 ms | 1% 최악 ms | 최대 ms |", "|---|---|---|---|---|---|"]
    for r in rows:
        if "fail" in r:
            md.append("| 실패 | %s(%d) | - | - | - | %s |" % (r["map"], r["prog"], r["fail"]))
        else:
            md.append("| %s | %s(%d) | %d | %.2f | %.2f | %.2f |" % (r["judge"], r["map"], r["prog"], r["people"], r["avg"], r["p99"], r["max"]))
    open(OUT + ".md", "w", encoding="utf-8").write("\n".join(md) + "\n")
    bad = sum(1 for r in rows if "fail" in r or r.get("judge") == "실패")
    print("성능 기록: 장면 %d · 실패 %d (%s)" % (len(rows), bad, os.path.relpath(OUT + ".md", ROOT)))
    for r in rows:
        print("  ", r)


if __name__ == "__main__":
    main()
