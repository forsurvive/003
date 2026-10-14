"""볼트 S-07 용기 내용물 표 → game/data/loot_s07.json (SD-12 §7.3 '서울판 컨테이너 유형'의 볼트판, 단계 0-9 정합).
용기 종류마다 [아이템 ID, 확률, 최소, 최대] 줄. 맵 원고의 `box x y 종류`가 이 표를 쓴다.
내용물은 처음 열 때 정해지고(용기 자리 + 연도로 씨앗), 시대(2259·2268·2274·2277)마다 따로 채워진다 —
200년 볼트에서 해마다 사물함 주인이 바뀌는 셈이다. 아이템 ID는 game/data의 아이템·무기·탄약 이름과 대조한다.
python3 tools/pipeline/loot_export.py   (build_data.sh에 들어 있다)"""
import os, sys, json, glob

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "game", "data")

# 종류 → (표시 이름, 내용물 줄). 확률은 줄마다 따로 굴린다. 빈 용기도 나온다(원작처럼 '[빈 상자]').
TABLES = {
    "locker": ("개인 사물함", [["M-070", 0.5, 1, 2], ["M-249", 0.35, 1, 3], ["M-046", 0.25, 1, 1], ["I-028", 0.2, 1, 1],
                              ["M-044", 0.15, 1, 1], ["M-075", 0.1, 1, 1]]),
    "school_locker": ("학생 사물함", [["M-070", 0.5, 1, 2], ["I-028", 0.3, 1, 1], ["M-249", 0.25, 1, 2], ["M-075", 0.15, 1, 1]]),
    "aid": ("민방위 비상용품함", [["I-004", 0.5, 1, 2], ["I-005", 0.4, 1, 1], ["I-001", 0.35, 1, 1], ["I-002", 0.15, 1, 1],
                                ["M-070", 0.3, 1, 1]]),
    "cabinet": ("서류함", [["M-002", 0.4, 2, 6], ["M-003", 0.35, 1, 3], ["M-070", 0.3, 1, 1], ["M-075", 0.2, 1, 1]]),
    "desk": ("책상 서랍", [["M-070", 0.4, 1, 1], ["M-002", 0.3, 1, 3], ["M-075", 0.2, 1, 1], ["I-028", 0.15, 1, 1]]),
    "crate": ("설비 상자", [["M-010", 0.7, 1, 3], ["M-012", 0.4, 1, 2], ["M-025", 0.35, 1, 1], ["M-015", 0.25, 1, 1],
                           ["M-014", 0.2, 1, 1]]),
    "pantry": ("식료품 상자", [["I-030", 0.6, 1, 3], ["I-026", 0.4, 1, 2], ["M-249", 0.3, 2, 4], ["M-046", 0.3, 1, 1]]),
    "ammo": ("탄약 상자", [["BB탄", 0.6, 10, 30], ["10mm 탄", 0.25, 6, 12]]),
    "safe": ("금고", [["M-002", 1.0, 12, 20], ["I-001", 1.0, 2, 2], ["M-014", 0.5, 1, 1]]),
}


def known_ids():
    ids = set()
    for f in glob.glob(os.path.join(DATA, "items_*.json")) + [os.path.join(DATA, "weapons.json")]:
        ids |= set(json.load(open(f, encoding="utf-8")).keys())
    for w in json.load(open(os.path.join(DATA, "weapons.json"), encoding="utf-8")).values():
        if w.get("ammo_id"):
            ids.add(w["ammo_id"])
    return ids


def main():
    ids = known_ids()
    bad = []
    out = {}
    for kind, (name, rows) in TABLES.items():
        for r in rows:
            if r[0] not in ids:
                bad.append(f"{kind}: 모르는 아이템 {r[0]}")
            if not (0.0 < r[1] <= 1.0 and 1 <= r[2] <= r[3]):
                bad.append(f"{kind}: 줄 값이 이상하다 {r}")
        out[kind] = {"name": name, "rows": rows}
    if bad:
        print("용기 표 오류:", *bad, sep="\n  ")
        sys.exit(1)
    json.dump({"tables": out}, open(os.path.join(DATA, "loot_s07.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"용기 표: {len(out)}종")


if __name__ == "__main__":
    main()
