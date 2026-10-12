"""주인공 실행 중 페이퍼돌 내보내기 v0 (SD-16 §5.1·§5.5·§13.3, SD-19 §6.7).
  몸 + 몸통: 파츠 리그 굽기 결과를 계열마다 **팔레트 인덱스 시트**로 (R = 인덱스, A = 0/255).
    인덱스 슬롯: 0 투명, 1~64 마스터 P00~P63, 65~69 피부 5, 70~73 머리색 4, 74~77 세력 주색 4, 78~79 세력 강조 2.
  머리 앵커 층: 머리카락(HR05·07·08·09), 머리 장비(HD02·03·04·05), 눈 장비(EY01·05)를 방향 5개의 대기 컷에서
    '기본 머리(HR03) 대비 바뀐 칸'으로 뽑는다. 실행 중에는 프레임 메타의 머리 앵커만큼 옮겨 겹친다(리그가 머리를 몸과
    함께 강체로 옮기므로 대기 컷 + 앵커 차이 = 그 프레임의 머리).
  팔레트: 마스터 64 + 교체(피부 S1~S6·SG1·SG2, 머리색 H1~H8, 세력 PF-01~12)를 JSON으로.
출력: game/assets/paperdoll/*.png + paperdoll.json. 팔레트 밖 색이 나오면 실패한다."""
import os, sys, json
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import palette as P
import rig_pc as R
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


def sheet(sets, order=("idle", "walk", "run")):
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
                heads[f"{v}:{mo}:{i}"] = head_anchor(f)
    return im, motions, heads


def head_anchor(f):
    px = f.load()
    m = [(x, y) for y in range(64) for x in range(64) if px[x, y][3]]
    top = min(y for _, y in m)
    xs = [x for x, y in m if y <= top + 6]
    return [round(sum(xs) / len(xs)), top + 16]


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {"slots": {"master": [1, 64], "skin": [65, 69], "hair": [70, 73], "main": [74, 77], "accent": [78, 79]},
            "rows": list(ROWS), "frame": [64, 64], "foot": [32, 60], "families": {}, "overlays": {}, "palettes": {}}
    base_idle = None
    for fam, (pf, main, acc) in FAMILIES.items():
        sets, _ = R.build_all(fam, pf)
        im, motions, heads = sheet(sets)
        to_index(im, slot_map(main, acc), fam).save(os.path.join(OUT, f"pd_body_{fam.lower()}.png"))
        meta["families"][fam] = {"sheet": f"pd_body_{fam.lower()}.png", "motions": motions, "head": heads,
                                 "faction_slots": main is not None,
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
