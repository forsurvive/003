"""시트 패킹 v1 (SD-16 §13.3·§13.4·§5.4): 인물 합성본 → 시트 PNG + 같은 이름 JSON.
v1(아이작풍, chibi.py): 칸 40×48, 발 기준점 (20, 44), 모션 대기 1·걷기 6·달리기 6. 보폭은 chibi.STRIDE(= Locomotion 표).
행 = 방향 S·SE·E·NE·N(반전 W·SW·NW는 파일로 만들지 않고 JSON mirror로 적는다), 열 = 모션을 순서대로 이어 붙임.
프레임 64×64, 발 기준점 (32, 60). 모션은 거리 구동(§3.6.5)이라 틱 대신 px_per_frame을 적는다.
프레임 메타: head (x, y, 상태) = 머리 윗줄 중심·위+16, hitbox = 불투명 상자. 손 앵커·무기 각도는 단계 T에서 포즈 표로 채운다.
이번 판은 합성본(몸 + 몸통 + 머리)을 낸다. 레이어별 분리 시트는 페이퍼돌 실행 중 합성 결정(G-T) 뒤에 낸다.
python3 tools/pack.py  ->  out/sheets/*.png + *.json"""
import os, sys, json
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))

ROOT = os.path.dirname(os.path.dirname(__file__))
OUT = os.path.join(ROOT, "out", "sheets")
ROWS = ("S", "SE", "E", "NE", "N")
MIRROR = {"W": "E", "SW": "SE", "NW": "NE"}


FW, FH, FOOT = 40, 48, (20, 44)


def meta(f, foot=FOOT):
    px = f.load()
    m = [(x, y) for y in range(f.height) for x in range(f.width) if px[x, y][3]]
    if not m:
        return {}
    top = min(y for _, y in m)
    xs = [x for x, y in m if y <= top + 6]
    x0, x1 = min(x for x, _ in m), max(x for x, _ in m)
    return {"head": [round(sum(xs) / len(xs)), top + 10, 0], "hitbox": [x0, top, x1 - x0 + 1, foot[1] - top + 1]}


def pack(name, sets, motions, steps, frame=(FW, FH), foot=FOOT):
    """frame·foot: 칸 크기·발 기준점(기본 40×48·(20, 44). 파워 아머 리그는 48×56·(24, 52), SD-16 §5.7)."""
    fw, fh = frame
    cols = []
    for mo in motions:
        n = len(sets[mo]["S"]) if isinstance(sets[mo]["S"], list) else 1
        cols.append((mo, n))
    W = sum(n for _, n in cols) * fw
    sheet = Image.new("RGBA", (W, fh * len(ROWS)), (0, 0, 0, 0))
    j = {"name": name, "frame": [fw, fh], "foot": list(foot), "rows": list(ROWS), "mirror": MIRROR, "motions": {},
         "frames": {}, "style": "isaac"}
    c = 0
    for mo, n in cols:
        j["motions"][mo] = {"start": c, "count": n}
        if mo in steps:
            j["motions"][mo].update({"px_per_frame": steps[mo]["E"], "px_vertical": steps[mo]["V"], "diag_step": [steps[mo]["D"]] * 2,
                                     "drive": "distance"})
        for r, v in enumerate(ROWS):
            seq = sets[mo][v] if isinstance(sets[mo][v], list) else [sets[mo][v]]
            for i, f in enumerate(seq):
                sheet.alpha_composite(f, ((c + i) * fw, r * fh))
                j["frames"][f"{v}:{mo}:{i}"] = meta(f, foot)
        c += n
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, name + ".png"))
    with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as fh:
        json.dump(j, fh, ensure_ascii=False, sort_keys=True, indent=1)
    return name


def chibi_sets(look, weapon=None, motions=("idle", "walk", "run")):
    import chibi as K
    sets = {}
    for mo in motions:
        n = 1 if mo == "idle" else 6
        sets[mo] = {v: [K.actor(look, v, mo, f, weapon=weapon) for f in range(n)] for v in ROWS}
    return sets


# 적으로 쓰는 외형(SD-14 CR-401 보병 계엄병 = SD-07b 계엄군 분대 표준 외형 + 소총)
ENEMIES = [("en_cr401_loco", "M1-S4-HR02-H1-T06-1-PF01-HD04-EY00-PR034", "rifle"),
           # CR-473 S-07 보안요원(SD-14 §9.4, 단계 0-9): 보안 제복 T02 + 헬멧 HD03. 진압봉 / 권총 두 벌
           ("en_cr473_baton_loco", "M1-S3-HR03-H1-T02-1-PF11-HD03-EY00", "baton"),
           ("en_cr473_pistol_loco", "F1-S4-HR02-H2-T02-1-PF11-HD03-EY00", "pistol"),
           # 0-10 MQ-101 새벽인력 추적조(SD-14 §10.9, 새벽인력 팔레트 PF-05): 추심원 CR-436 기관단총 · 인솔조원 CR-437 소총 · 독사(C-021, SD-07b 외형)
           ("en_cr436_loco", "M2-S3-HR01-H2-T12-2-PF05-HD05-EY00", "smg"),
           ("en_cr437_loco", "M1-S4-HR02-H1-T05-1-PF05-HD02-EY00", "rifle"),
           ("en_c021_loco", "M1-S4-HR01-H1-T12-1-PF05-HD00-EY05-PR027", "smg"),
           # 1-4 지하시장(SD-14 §7·§10): 야생 구울 CR-200(누더기, 맨손) · 떠돌이 구울 CR-201(2077 방호복 잔해) ·
           # 지하시장 경비 CR-456(가죽 + 자동소총) · 계약 경호 구울 CR-457(고철 갑옷 + 전투 산탄총)
           ("en_cr200_loco", "M1-SG2-HR00-H1-T16-2-PF00-HD00-EY00", None),
           ("en_cr201_loco", "M2-SG2-HR00-H1-T10-2-PF00-HD00-EY00", None),
           ("en_cr456_loco", "M1-SG1-HR01-H1-T05-1-PF00-HD02-EY00", "rifle"),
           ("en_cr457_loco", "M2-SG1-HR00-H5-T04-1-PF00-HD05-EY00", "rifle")]


def main():
    import chibi as K
    import npcs as NP
    made = []
    for f in os.listdir(OUT) if os.path.isdir(OUT) else []:
        os.remove(os.path.join(OUT, f))
    for code, pf in (("T01", None), ("T02", None), ("T03", None), ("T06", "PF-01")):
        lk = K.Look(torso=code, faction=pf)
        nm = f"pc_comp_{code.lower()}_{(pf or 'PF-00').replace('-', '').lower()}_loco"
        made.append(pack(nm, chibi_sets(lk), ("idle", "walk", "run"), K.STRIDE))
    for nm, code, weapon in ENEMIES:
        made.append(pack(nm, chibi_sets(K.Look.parse(code), weapon), ("idle", "walk", "run"), K.STRIDE))
    import power_armor as PA                             # CR-405 파워 아머(구형, SD-16 §5.7): 48×56 칸
    made.append(pack("en_cr405_loco", PA.sets(), ("idle", "walk", "run"), PA.STRIDE, frame=(PA.W, PA.H), foot=(PA.FX, PA.FY)))
    for grp, name, role, code in NP.NPCS:
        nm = "np_" + code.lower().replace("-", "_") + "_loco"
        made.append(pack(nm, chibi_sets(K.Look.parse(code), None, ("idle", "walk")), ("idle", "walk"), K.STRIDE))
    print("packed:", len(made), "sheets ->", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
