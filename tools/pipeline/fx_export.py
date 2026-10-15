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
import effects_arms as A
import palette as P
from grid import check

OUT = os.path.join(ROOT, "game", "assets", "fx")
CELL = 16
SETS = [  # 이름, 컷 수, 그리는 함수(각, 컷), 기준점, 혼합, 칸, 방향 수
    ("bullet", 1, lambda a, f: E.bullet_rt(a), E.FX_ANCHOR["bullet"], "mix", 16, 16),
    ("flash_pistol", 3, lambda a, f: E.muzzle(a, f), E.FX_ANCHOR["flash"], "add", 16, 16),
    ("flash_air", 2, lambda a, f: E.air_puff(a, f), E.FX_ANCHOR["flash"], "add", 16, 16),
    ("spark", 3, lambda a, f: E.sparks_dir(a, f), E.FX_ANCHOR["spark"], "add", 16, 16),
    # 1-9a 무기 계열(SD-16 §10.1 총구 4종 · 투사체 · §10.4 폭발)
    ("flash_laser", 2, lambda a, f: A.flash_laser(a, f), A.ANCHOR["flash16"], "add", 16, 16),
    ("flash_plasma", 2, lambda a, f: A.flash_plasma(a, f), A.ANCHOR["flash16"], "add", 16, 16),
    ("flash_flame", 2, lambda a, f: A.flash_flame(a, f), A.ANCHOR["flash16"], "add", 16, 16),
    ("spark_red", 3, lambda a, f: A.sparks_red(a, f), E.FX_ANCHOR["spark"], "add", 16, 16),
    ("pellet", 1, lambda a, f: A.pellet(a), A.ANCHOR["proj"], "mix", 16, 16),
    ("nail", 1, lambda a, f: A.nail(a), A.ANCHOR["proj"], "mix", 16, 16),
    ("dart", 1, lambda a, f: A.dart(a), A.ANCHOR["proj"], "mix", 16, 16),
    ("plasma", 1, lambda a, f: A.plasma_bolt(a), A.ANCHOR["mid16"], "add", 16, 16),
    ("tesla", 1, lambda a, f: A.tesla_bolt(a), A.ANCHOR["mid16"], "add", 16, 16),
    ("missile", 1, lambda a, f: A.missile(a), A.ANCHOR["proj"], "mix", 16, 16),
    ("shell", 1, lambda a, f: A.shell40(a), A.ANCHOR["mid16"], "mix", 16, 16),
    ("junk", 1, lambda a, f: A.junk(a), A.ANCHOR["mid16"], "mix", 16, 16),
    ("flame", 5, lambda a, f: A.flame_puff(f), A.ANCHOR["mid16"], "mix", 16, 1),     # 화염·불덩이는 일반 혼합 — 밝은 바닥에서 가산은 허옇게 바랜다
    ("flash_shotgun", 3, lambda a, f: A.flash_shotgun(a, f), A.ANCHOR["flash32"], "add", 32, 16),
    ("flash_heavy", 3, lambda a, f: A.flash_heavy(a, f), A.ANCHOR["flash32"], "add", 32, 16),
    ("boom_smoke", 8, lambda a, f: A.boom_smoke(f, 96), A.ANCHOR["mid96"], "mix", 96, 1),
    ("boom", 8, lambda a, f: A.boom_fire(f, 96), A.ANCHOR["mid96"], "mix", 96, 1),
]
SETS += [  # 1-9b 투척·설치(SD-11 §3.4 · §9.2): 던진 물체 4컷(구름) · 지뢰 2컷(경보등) · 지대 3컷 · 플라스마·펄스 폭발(색 교체)
    *[("thrown_" + k, 4, (lambda k: lambda a, f: A.thrown(k, f))(k), A.ANCHOR["mid16"], "mix", 16, 1) for k in A.THROWN],
    *[("mine_" + k, 2, (lambda k: lambda a, f: A.mine(k, f))(k), A.ANCHOR["mid16"], "mix", 16, 1) for k in A.MINES],
    *[("zone_" + k, 3, (lambda k: lambda a, f: A.zone(k, f))(k), (16.0, 16.0), "mix", 32, 1) for k in ("fire", "gas", "smoke", "rad")],
    ("boom_plasma", 8, lambda a, f: A.boom_tint(f, "plasma"), A.ANCHOR["mid96"], "mix", 96, 1),
    ("boom_pulse", 8, lambda a, f: A.boom_tint(f, "pulse"), A.ANCHOR["mid96"], "mix", 96, 1),
]
SETS += [  # 1-9c 숨긴 함정(발견하면 바닥층에 그린다)
    ("trap_bear", 2, lambda a, f: A.trap("bear", f), A.ANCHOR["mid16"], "mix", 16, 1),
    ("trap_plate", 1, lambda a, f: A.trap("plate"), A.ANCHOR["mid16"], "mix", 16, 1),
    ("trap_wire", 1, lambda a, f: A.trap("wire"), A.ANCHOR["mid16"], "mix", 16, 1),
    ("trap_claymore", 1, lambda a, f: A.trap("claymore"), A.ANCHOR["mid16"], "mix", 16, 1),
    ("trap_shotgun", 1, lambda a, f: A.trap("shotgun"), (16.0, 16.0), "mix", 32, 1),
]
TICKS = {"flame": 4, "boom": 3, "boom_smoke": 4, "boom_plasma": 3, "boom_pulse": 3}   # 컷당 틱(기본 2)


def main():
    os.makedirs(OUT, exist_ok=True)
    width = max(cell * dirs for *_, cell, dirs in SETS)
    height = sum((n if dirs > 1 else 1) * cell for _, n, _, _, _, cell, dirs in SETS)   # 무방향 세트는 컷을 가로로 놓는다
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    meta = {"cell": CELL, "dirs": len(E.DIRS16), "sets": {}}
    y = 0
    for name, n, fn, anchor, blend, cell, dirs in SETS:
        # row: 16칸 기준 행(예전 세트와 같다) · y: 화소 위치 · cell · dirs(1 = 무방향)
        meta["sets"][name] = {"row": y // CELL, "y": y, "frames": n, "anchor": list(anchor), "blend": blend, "ticks": TICKS.get(name, 2),
                              "cell": cell, "dirs": dirs}
        if dirs == 1:
            for f in range(n):
                sheet.alpha_composite(fn(0.0, f), (f * cell, y))
            y += cell
            continue
        for f in range(n):
            for i, a in enumerate(E.DIRS16):
                sheet.alpha_composite(fn(a, f), (i * cell, y + f * cell))
        y += n * cell
    bad = check(sheet, P.allowed_set())
    if bad:
        print("fx_export: 팔레트 밖 색", bad)
        sys.exit(1)
    sheet.save(os.path.join(OUT, "combat_fx.png"))
    json.dump(meta, open(os.path.join(OUT, "combat_fx.json"), "w"), ensure_ascii=False, sort_keys=True, indent=1)
    print("fx:", ", ".join(f"{k} {v['frames']}컷" for k, v in meta["sets"].items()), "→", sheet.size)


if __name__ == "__main__":
    main()
