"""1막 경제 곡선(단계 1-13c, SD-15 §9.1 구간 Ⅰ · SD-25 B6): 봇 체인을 실제로 돌려 '캡 · 누적 수입 · XP · 레벨'을 모은다.

봇은 진짜 맵 · 대화 · 전투 · 거래 위에서 걷는다. 누적 수입 CAPS_EARNED는 캡이 늘 때마다 엔진이 센다(퀘스트 · 루팅 · 거래 모든 길).
기록 줄: 봇이 찍는 'ECON|지점|해법 n|캡 n|누적 n|XP n|Lv n|날 n'.
지금 지점: MQ-101 끝(프롤로그 → 첫 풍경 → MQ-101 해법 1~4, --from=view --chain --sol=N).
결과: game/data/_econ_curve.json — balance_check.py B6이 읽어 SD-15 구간 Ⅰ(보유 150~500 · 누적 1,500~2,500 by Lv6)과 대 본다.

봇이 느려 빌드에는 넣지 않는다 — 경제 · 보상을 바꾼 뒤 손으로 돌린다:
    python3 tools/pipeline/econ_curve.py [--sols 1,2,3,4] [--timeout 900]
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sols", default="1,2,3,4")
    ap.add_argument("--timeout", type=int, default=900)
    a = ap.parse_args()
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
