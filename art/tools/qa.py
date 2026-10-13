"""자동 검수 v1 (SD-16 §13.5 자동 항목, SD-19 §5.1 '자동 검수 6항목'). v1: 아이작풍 인물(chibi, 칸 40×48·발 (20, 44)).
  1 허용 팔레트 밖 색 0            2 알파 0·255만
  3 이중 외곽선 0 (실루엣 가장자리 P01 안쪽에 또 P01 띠). 아이작풍의 '밑선 2px'(아래쪽 가장자리)는 규칙이라 빼고 센다
  4 발 기준점 (32, 60): 모든 프레임의 가장 낮은 불투명 행이 59~61, 레이어(몸통 계열·NPC) 사이 프레임 수 일치
  5 앵커 이탈 0: 머리 앵커(머리 윗줄 중심, 위+16)가 모션 안에서 2px 넘게 튀지 않음, 손(피부 덩어리)이 몸 상자 밖 3px 넘게 나가지 않음
  6 (경고) 1px 고립 점
대상: 주인공 몸 + 몸통 4계열(T01·T02·T03·T06), 기준 샘플 NPC 23명 대기 5방향, 타일·장면 출력의 팔레트·알파.
python3 tools/qa.py  ->  samples/qa_report.txt (위반 0이면 종료 코드 0)"""
import os, sys, glob
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import palette as P

ROOT = os.path.dirname(os.path.dirname(__file__))
ALLOWED = P.allowed_set("UI", *P.SKIN.keys(), *P.HAIR.keys(), *P.PF.keys(), *P.REGION.keys())
INK = P.rgb("P01")
SKIN = {P.rgb(c) for s in P.SKIN.values() for c in s}
VIEWS = ("S", "SE", "E", "NE", "N")


def opaque(img):
    px = img.load()
    return {(x, y) for y in range(img.height) for x in range(img.width) if px[x, y][3]}


def c1_palette(img):
    return sorted({p[:3] for p in img.get_flattened_data() if p[3] and p[:3] not in ALLOWED})


def c2_alpha(img):
    return sum(1 for p in img.get_flattened_data() if p[3] not in (0, 255))


def c3_double_outline(img):
    """이중 외곽선: 바깥에 닿은 먹선 칸의 안쪽 이웃도 먹선이고 그다음은 색 — 그런 칸이 가장자리를 따라 3칸 이상 이어질 때만 센다.
    둥근 실루엣의 계단 모서리(1~2칸)와 아이작풍 굵은 밑선(아래쪽 가장자리)은 규칙대로 그린 것이라 빼고 센다."""
    px = img.load()
    m = opaque(img)
    hits = {}
    for x, y in m:
        if px[x, y][:3] != INK:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, -1)):
            if (x + dx, y + dy) in m:
                continue
            ix, iy, jx, jy = x - dx, y - dy, x - 2 * dx, y - 2 * dy
            if (ix, iy) in m and px[ix, iy][:3] == INK and (jx, jy) in m and px[jx, jy][:3] != INK:
                hits.setdefault((dx, dy), set()).add((x, y))
    bad = 0
    for (dx, dy), pts in hits.items():
        tx, ty = (0, 1) if dx else (1, 0)                                  # 가장자리를 따라가는 방향
        for x, y in pts:
            run = 1 + sum(1 for k in (1, 2) if (x + tx * k, y + ty * k) in pts) + sum(1 for k in (1, 2) if (x - tx * k, y - ty * k) in pts)
            if run >= 3:
                bad += 1
    return bad


def lowest(img):
    m = opaque(img)
    return max(y for _, y in m) if m else None


def head_anchor(img):
    m = opaque(img)
    if not m:
        return None
    top = min(y for _, y in m)
    xs = [x for x, y in m if y <= top + 6]
    return (round(sum(xs) / len(xs)), top + 16)


def hands_out(img):
    """skin pixels below the head that sit more than 3px outside the torso box (shoulder width) -> count.
    아이작풍: 머리(약 20행) 아래 몸통 행에서 잰다. 손에 든 무기의 손은 무기 층이라 제외(무기 없는 컷만 검사)."""
    px = img.load()
    m = opaque(img)
    top = min(y for _, y in m)
    body = [(x, y) for x, y in m if top + 21 <= y <= top + 28]
    if not body:
        return 0
    x0, x1 = min(x for x, _ in body), max(x for x, _ in body)
    return sum(1 for x, y in m if y > top + 21 and px[x, y][:3] in SKIN and (x < x0 - 3 or x > x1 + 3))


def c6_isolated(img):
    m = opaque(img)
    return sum(1 for x, y in m if not any((x + a, y + b) in m for a in (-1, 0, 1) for b in (-1, 0, 1) if a or b))


def check_sets(name, sets, out, counts):
    errs = 0
    lens = {}
    for mode in ("idle", "walk", "run"):
        if mode not in sets:
            continue
        for v in VIEWS:
            seq = sets[mode][v]
            seq = seq if isinstance(seq, list) else [seq]
            lens[(mode, v)] = len(seq)
            prev = None
            for i, f in enumerate(seq):
                tag = f"{name} {mode} {v}#{i}"
                if f.size != (40, 48):
                    out.append(f"4 FAIL {tag}: frame size {f.size}"); errs += 1
                pal = c1_palette(f)
                if pal:
                    out.append(f"1 FAIL {tag}: off-palette {pal[:4]}"); errs += 1
                a = c2_alpha(f)
                if a:
                    out.append(f"2 FAIL {tag}: partial alpha {a}px"); errs += 1
                d = c3_double_outline(f)
                if d:
                    out.append(f"3 FAIL {tag}: double outline {d}px"); errs += 1
                lo = lowest(f)
                tol = {"idle": 0, "walk": 3, "run": 4}[mode]              # 디딘 발은 세계 고정: 앞뒤 보폭 반 + 들림
                if lo is None or not 44 - tol <= lo <= 45 + tol:                # 발 기준점 44 + 굵은 밑선 1
                    out.append(f"4 FAIL {tag}: lowest row {lo} (foot line 44~45)"); errs += 1
                ha = head_anchor(f)
                if prev and ha and (abs(ha[0] - prev[0]) > 2 or abs(ha[1] - prev[1]) > 2):
                    out.append(f"5 FAIL {tag}: head anchor jump {prev}->{ha}"); errs += 1
                prev = ha
                ho = hands_out(f)
                if ho:
                    out.append(f"5 FAIL {tag}: hand {ho}px outside the body box"); errs += 1
                iso = c6_isolated(f)
                if iso:
                    out.append(f"6 WARN {tag}: {iso} isolated px")
    for mode in ("walk", "run"):
        ns = {lens.get((mode, v)) for v in VIEWS if (mode, v) in lens}
        if len(ns) > 1:
            out.append(f"4 FAIL {name} {mode}: frame counts differ by direction {ns}"); errs += 1
    counts[name] = tuple(sorted(lens.items()))
    return errs


FAMS = ["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08", "T09", "T10", "T11", "T12", "T13", "T14", "T15", "T16", "GOWN"]


def main():
    import chibi as K
    import npcs as NP
    from pack import chibi_sets
    out, counts, errs = [], {}, 0
    for code in FAMS:
        for bt in ("M1", "F1"):
            sets = chibi_sets(K.Look(body=bt, torso=code, faction="PF-01" if code in ("T02", "T06", "T08") else None))
            errs += check_sets(f"PC {bt} {code}", sets, out, counts)
    for grp, name, role, code in NP.NPCS:
        errs += check_sets(f"NPC {name}", chibi_sets(K.Look.parse(code), None, ("idle", "walk")), out, counts)
    lines, worst = K.footlock_report()
    if worst:
        out.append(f"4 FAIL 디딤발 어긋남 {worst}px"); errs += 1
    pcs = {k: v for k, v in counts.items() if k.startswith("PC")}
    if len(set(pcs.values())) > 1:
        out.append(f"4 FAIL layer frame counts differ between torso families: {sorted(set(pcs.values()))[:2]}"); errs += 1
    # tiles, scenes, pictures: palette + alpha only (UI translucency and filter previews are exempt by spec)
    import scene_bongcheon as SB
    SB.RUNTIME = False                       # runtime shadow multiply + region tone are engine layers, not asset colours
    targets = [("05_scene_bongcheon (에셋 층: HUD·실행 중 그림자 곱하기·권역 색조 제외)", SB.build(hud=False).convert("RGBA"))]
    SB.RUNTIME = True
    for f in sorted(glob.glob(os.path.join(ROOT, "samples", "*.png"))):
        b = os.path.basename(f)
        # exempt: comparison/filter previews, translucent UI layers, preview sheets on a neutral backdrop
        # t_: 단계 T 기술 출력(지도 1px 미리보기, 엔진 화면 캡처)은 그림 원본이 아니다
        if any(b.startswith(p) for p in ("00_", "05_scene", "06_hud", "07_pip", "18_", "21_scene_birth", "22_", "23_", "t_")):
            continue
        if "_x" in b or "strip" in b:
            continue
        targets.append((b, Image.open(f).convert("RGBA")))
    for b, im in targets:
        pal = c1_palette(im)
        if pal:
            out.append(f"1 FAIL {b}: off-palette {pal[:4]}"); errs += 1
        a = c2_alpha(im)
        if a:
            out.append(f"2 FAIL {b}: partial alpha {a}px"); errs += 1
    warns = sum(1 for l in out if " WARN " in l)
    head = [f"자동 검수 v1 — 위반 {errs}건, 경고 {warns}건",
            f"대상: 주인공 몸통 {len(FAMS)}계열 × 남·여 × (대기 + 걷기·달리기 6프레임) × 5방향, NPC {len(NP.NPCS)}명 × (대기 + 걷기) × 5방향,"
            " 디딤발 표, samples/*.png 1× 원본",
            ""]
    rep = os.path.join(ROOT, "samples", "qa_report.txt")
    open(rep, "w", encoding="utf-8").write("\n".join(head + out) + "\n")
    print(head[0])
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
