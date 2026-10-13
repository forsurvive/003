"""전투 이펙트 시트 내보내기 (단계 0-7, SD-16 §10.1·§3.5·§3.7): art/tools/effects.py의 16방향 그림 → game/assets/fx/.
  combat_fx.png  칸 16×16, 열 = 방향(0 = 동, 22.5°씩 시계 방향 — 화면 y 아래), 행 = 세트 × 컷.
  combat_fx.json 세트마다 {row, frames, anchor, blend, ticks}. anchor = 칸 안 기준점(탄 머리·총구·맞은 점, px 연속 좌표).
    bullet        탄환 1컷(2×1 심 + 잔상 4px + 1px 어두운 심), 일반 혼합
    flash_pistol  총구 화염 3컷(견본 #12), 가산, 컷당 2틱
    flash_air     공기총 분출 2컷(BB총 — 불꽃 없음), 가산, 컷당 2틱
    spark         벽·엄폐물에 맞은 불꽃 3컷(쏜 쪽으로 튄다), 가산, 컷당 2틱
실행 중 회전은 쓰지 않는다(SD-16 §3.5) — 게임은 날아가는 각에 가까운 열을 고른다. 팔레트 밖 색이 나오면 실패."""
import os, sys, json
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import effects as E
import palette as P
from grid import check

OUT = os.path.join(ROOT, "game", "assets", "fx")
CELL = 16
SETS = [  # 이름, 컷 수, 그리는 함수(각, 컷), 기준점 종류, 혼합
    ("bullet", 1, lambda a, f: E.bullet_rt(a), "bullet", "mix"),
    ("flash_pistol", 3, lambda a, f: E.muzzle(a, f), "flash", "add"),
    ("flash_air", 2, lambda a, f: E.air_puff(a, f), "flash", "add"),
    ("spark", 3, lambda a, f: E.sparks_dir(a, f), "spark", "add"),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = sum(n for _, n, _, _, _ in SETS)
    sheet = Image.new("RGBA", (CELL * len(E.DIRS16), CELL * rows), (0, 0, 0, 0))
    meta = {"cell": CELL, "dirs": len(E.DIRS16), "sets": {}}
    row = 0
    for name, n, fn, anchor, blend in SETS:
        meta["sets"][name] = {"row": row, "frames": n, "anchor": list(E.FX_ANCHOR[anchor]), "blend": blend, "ticks": 2}
        for f in range(n):
            for i, a in enumerate(E.DIRS16):
                sheet.alpha_composite(fn(a, f), (i * CELL, (row + f) * CELL))
        row += n
    bad = check(sheet, P.allowed_set())
    if bad:
        print("fx_export: 팔레트 밖 색", bad)
        sys.exit(1)
    sheet.save(os.path.join(OUT, "combat_fx.png"))
    json.dump(meta, open(os.path.join(OUT, "combat_fx.json"), "w"), ensure_ascii=False, sort_keys=True, indent=1)
    print("fx:", ", ".join(f"{k} {v['frames']}컷" for k, v in meta["sets"].items()), f"× {len(E.DIRS16)}방향 →", sheet.size)


if __name__ == "__main__":
    main()
