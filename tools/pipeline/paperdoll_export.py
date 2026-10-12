"""주인공 실행 중 페이퍼돌 내보내기 v0 (SD-16 §5.1·§5.5·§13.3, SD-19 §6.7).
  몸 + 몸통: 파츠 리그 굽기 결과를 계열마다 **팔레트 인덱스 시트**로 (R = 인덱스, A = 0/255).
    인덱스 슬롯: 0 투명, 1~64 마스터 P00~P63, 65~69 피부 5, 70~73 머리색 4, 74~77 세력 주색 4, 78~79 세력 강조 2.
  머리 앵커 층: 머리카락(HR05·07·08·09), 머리 장비(HD02·03·04·05), 눈 장비(EY01·05)를 방향 5개의 대기 컷에서
    '기본 머리(HR03) 대비 바뀐 칸'으로 뽑는다. 실행 중에는 프레임 메타의 머리 앵커만큼 옮겨 겹친다(리그가 머리를 몸과
    함께 강체로 옮기므로 대기 컷 + 앵커 차이 = 그 프레임의 머리).
  조준 분리(SD-16 §5.10): 하체(45행 아래) 대기·걷기·달리기 + 권총 상체(45행 위) 방향 5개. 실행 중 하체는 이동 방향,
    상체는 조준 방향으로 따로 고르고 상체를 보폭 출렁임(bob)만큼 내린다. 상체 머리 앵커로 머리 층을 겹친다.
  구르기(SD-11 §5.3·§8.4 0.35초 5프레임): **임시 그림** — 대기 컷의 상체를 90도 단위로 돌린 공. 원화는 단계 0.
  팔레트: 마스터 64 + 교체(피부 S1~S6·SG1·SG2, 머리색 H1~H8, 세력 PF-01~12)를 JSON으로.
출력: game/assets/paperdoll/*.png + paperdoll.json. 팔레트 밖 색이 나오면 실패한다."""
import os, sys, json, colorsys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import palette as P
import rig_pc as R
import weapons as W
from grid import thin_outline

OUT = os.path.join(ROOT, "game", "assets", "paperdoll")
ROWS = ("S", "SE", "E", "NE", "N")
SKIN = [P.rgb(c) for c in P.SKIN["S3"]]
HAIR = [P.rgb(c) for c in P.HAIR["H1"]]
FAMILIES = {                       # torso family -> (build faction, main ramp, accent) as RGB tokens
    "T01": (None, ["P43", "P44", "P45", "P46"], ["P48", "P49"]),
    "T02": (None, ["P43", "P44", "P45", "P46"], ["P48", "P49"]),
    "T03": (None, None, None),
    "T06": ("PF-01", [f"PF-01.{i}" for i in range(4)], ["PF-01.4", "PF-01.5"]),
}
LOOKS = {"hair": ["HR05", "HR07", "HR08", "HR09"], "gear": ["HD02", "HD03", "HD04", "HD05"], "eyes": ["EY01", "EY05"]}


def slot_map(main, acc):
    m = {P.rgb(f"P{i:02d}"): i + 1 for i in range(64)}
    for k, c in enumerate(SKIN):
        m[c] = 65 + k
    for k, c in enumerate(HAIR):
        m[c] = 70 + k
    if main:
        for k, t in enumerate(main):
            m[P.rgb(t)] = 74 + k
        for k, t in enumerate(acc):
            m[P.rgb(t)] = 78 + k
    return m


def to_index(img, m, where):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src, dst = img.load(), out.load()
    bad = set()
    for y in range(img.height):
        for x in range(img.width):
            p = src[x, y]
            if p[3]:
                i = m.get(p[:3])
                if i is None:
                    bad.add(p[:3])
                    continue
                dst[x, y] = (i, 0, 0, 255)
    if bad:
        raise SystemExit(f"{where}: 팔레트 밖 색 {sorted(bad)[:6]}")
    return out


def sheet(sets, order=("idle", "walk", "run"), headless=()):
    cols, motions, c = [], {}, 0
    for mo in order:
        n = len(sets[mo]["S"]) if isinstance(sets[mo]["S"], list) else 1
        motions[mo] = {"start": c, "count": n}
        c += n
    im = Image.new("RGBA", (c * 64, 64 * len(ROWS)), (0, 0, 0, 0))
    heads = {}
    for mo in order:
        for r, v in enumerate(ROWS):
            seq = sets[mo][v] if isinstance(sets[mo][v], list) else [sets[mo][v]]
            for i, f in enumerate(seq):
                im.alpha_composite(f, ((motions[mo]["start"] + i) * 64, r * 64))
                if mo not in headless:
                    heads[f"{v}:{mo}:{i}"] = head_anchor(f)
    return im, motions, heads


def head_anchor(f):
    px = f.load()
    m = [(x, y) for y in range(64) for x in range(64) if px[x, y][3]]
    top = min(y for _, y in m)
    xs = [x for x, y in m if y <= top + 6]
    return [round(sum(xs) / len(xs)), top + 16]


def band(f, y0, y1):
    out = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    out.alpha_composite(f.crop((0, y0, 64, y1)), (0, y0))
    return out


def roll(idle, view, front):
    """임시 구르기 5컷: 웅크림 → 웅크린 공 3컷(머리·발이 공 둘레를 돈다) → 웅크림.
    공의 색은 그 계열 대기 컷의 몸통에서 뽑고(가장 어두운 색 = 외곽선), 머리·발은 대기 컷을 90도 단위로 돌려 붙이므로 팔레트가 그대로다."""
    hx, hy = head_anchor(idle)
    top = hy - 16
    lum = lambda c: c[0] * 3 + c[1] * 6 + c[2]
    sp = front.load()                                      # 공 색은 정면 대기 컷 몸통에서 뽑아 방향마다 같게
    ink = min((sp[x, y][:3] for y in range(64) for x in range(64) if sp[x, y][3]), key=lum)
    fx, fy = head_anchor(front)
    tones = {}
    for y in range(fy + 2, fy + 14):
        for x in range(fx - 6, fx + 7):
            c = sp[x, y]
            if c[3] and c[:3] != ink:
                tones[c[:3]] = tones.get(c[:3], 0) + 1
    main = max(tones, key=tones.get)
    hue = lambda c: colorsys.rgb_to_hsv(*[v / 255 for v in c])
    h0, s0, _ = hue(main)
    ramp = [c for c in tones if (abs(hue(c)[0] - h0) < 0.08 or (s0 < 0.15 and hue(c)[1] < 0.2))]
    dark = min(ramp, key=lum)
    hi = max(ramp, key=lum)
    head = Image.new("RGBA", (16, 15), (0, 0, 0, 0))
    head.alpha_composite(idle.crop((hx - 8, top, hx + 8, top + 15)))
    feet = idle.crop((0, 56, 64, 62))
    feet = feet.crop(feet.getbbox())
    cx, cy, r = 32, 51, 8

    def ball():
        f = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        q = f.load()
        for y in range(cy - r - 1, cy + r + 2):
            for x in range(cx - r - 1, cx + r + 2):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= r - 0.5:
                    t = (x - cx) * 0.55 + (y - cy) * 0.85          # 빛은 왼쪽 위
                    q[x, y] = (dark if t > 3.0 else hi if t < -4.5 else main) + (255,)
                elif d <= r + 0.6:
                    q[x, y] = ink + (255,)
        return f

    def put(f, im, x, y):
        f.alpha_composite(im, (x, y))
        return f

    crouch = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    crouch.alpha_composite(band(idle, 52, 64))
    crouch.alpha_composite(band(idle, 0, 45), (0, 7))
    if view in ("S", "N"):                    # 앞(S)·뒤(N)로 구르기: 머리가 공 안쪽으로 숙여졌다가 발이 넘어온다
        f1 = put(ball(), head, cx - 8, cy - r - 6)
        f2 = put(ball(), feet.transpose(Image.FLIP_TOP_BOTTOM), cx - feet.width // 2, cy - r - 3)
        f3 = put(ball(), head.transpose(Image.ROTATE_180), cx - 8, cy + r - 9) if view == "N" else \
            put(ball(), feet, cx - feet.width // 2, cy + r - 3)
    else:                                     # 옆·대각선(오른쪽으로 진행): 머리가 앞 → 아래 → 뒤로 시계 방향
        f1 = put(ball(), head.transpose(Image.ROTATE_270), cx + r - 6, cy - 9)
        f2 = put(ball(), feet.transpose(Image.FLIP_TOP_BOTTOM), cx - feet.width // 2, cy - r - 3)
        f3 = put(ball(), head.transpose(Image.ROTATE_90), cx - r - 9, cy - 6)
    return [crouch, f1, f2, f3, crouch]


def aim_sets(fam, pf, sets):
    """조준 분리 층: 하체(이동 방향)와 권총 상체(조준 방향) + 보폭 출렁임 표."""
    low, bob = {}, {}
    for mode in ("walk", "run"):
        lo, b = W.lower_sets(fam, mode, pf)
        low[mode] = {v: [band(f, 45, 64) for f in lo[v]] for v in ROWS}
        bob[mode] = {v: b[v] for v in ROWS}
    up = W.upper_sets("pistol", fam, None, pf)
    extra = {"aim_idle": {v: [band(sets["idle"][v], 45, 64)] for v in ROWS},
             "aim_walk": low["walk"], "aim_run": low["run"],
             "aim_up": {v: [up[v]] for v in ROWS},
             "roll": {v: roll(sets["idle"][v], v, sets["idle"]["S"]) for v in ROWS}}
    return extra, bob


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {"slots": {"master": [1, 64], "skin": [65, 69], "hair": [70, 73], "main": [74, 77], "accent": [78, 79]},
            "rows": list(ROWS), "frame": [64, 64], "foot": [32, 60], "families": {}, "overlays": {}, "palettes": {}}
    base_idle = None
    for fam, (pf, main, acc) in FAMILIES.items():
        sets, _ = R.build_all(fam, pf)
        sets = {k: sets[k] for k in ("idle", "walk", "run")}
        extra, bob = aim_sets(fam, pf, sets)
        sets.update(extra)
        im, motions, heads = sheet(sets, ("idle", "walk", "run", "aim_idle", "aim_walk", "aim_run", "aim_up", "roll"),
                                   headless=("aim_idle", "aim_walk", "aim_run"))
        to_index(im, slot_map(main, acc), fam).save(os.path.join(OUT, f"pd_body_{fam.lower()}.png"))
        meta["families"][fam] = {"sheet": f"pd_body_{fam.lower()}.png", "motions": motions, "head": heads,
                                 "faction_slots": main is not None, "bob": bob,
                                 "default_main": [P.resolve(t) for t in main] if main else None,
                                 "default_accent": [P.resolve(t) for t in acc] if acc else None}
        if fam == "T01":
            base_idle = {v: sets["idle"][v] for v in ROWS}
            base_head = {v: head_anchor(sets["idle"][v]) for v in ROWS}
    m = slot_map([f"PF-01.{i}" for i in range(4)], ["PF-01.4", "PF-01.5"])   # 세력 철모(HD04)는 착용자 세력 색을 따른다
    for slot, codes in LOOKS.items():
        for code in codes:
            look = {slot: code}
            sets, _ = R.build_all("T01", None, look)
            strip = Image.new("RGBA", (64 * len(ROWS), 64), (0, 0, 0, 0))
            for r, v in enumerate(ROWS):
                a, b = base_idle[v].load(), sets["idle"][v].load()
                ov = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
                o = ov.load()
                for y in range(64):
                    for x in range(64):
                        if b[x, y] != a[x, y] and b[x, y][3]:
                            o[x, y] = b[x, y]
                strip.alpha_composite(ov, (r * 64, 0))
            to_index(strip, m, code).save(os.path.join(OUT, f"pd_{slot}_{code.lower()}.png"))
            meta["overlays"][code] = {"slot": slot, "sheet": f"pd_{slot}_{code.lower()}.png",
                                      "head": {v: base_head[v] for v in ROWS}}
    meta["palettes"]["master"] = [P.NAMED[f"P{i:02d}"] for i in range(64)]
    meta["palettes"]["skin"] = {k: [P.resolve(c) if c.startswith("#") else c for c in v] for k, v in P.SKIN.items()}
    meta["palettes"]["hair"] = {k: list(v) for k, v in P.HAIR.items()}
    meta["palettes"]["faction"] = {k: [P.resolve(c) if not c.startswith("#") else c for c in v] for k, v in P.PF.items()}
    json.dump(meta, open(os.path.join(OUT, "paperdoll.json"), "w"), ensure_ascii=False, sort_keys=True, indent=1)
    print("paperdoll:", len(meta["families"]), "families,", len(meta["overlays"]), "overlays")


if __name__ == "__main__":
    main()
