"""주인공 실행 중 페이퍼돌 내보내기 v2 — 아이작풍(SD-16 §5 v2.0, art/tools/chibi.py).
층: 몸(이동 방향) + 머리(조준 방향, 표정) + 머리 장비 + 눈 장비 + 손 무기. 전부 **팔레트 인덱스 시트**(R = 인덱스, A = 0/255).
  인덱스 슬롯: 0 투명, 1~64 마스터 P00~P63, 65~69 피부 5, 70~73 머리색 4, 74~77 세력 주색 4, 78~79 세력 강조 2.
  몸 시트(몸통 계열 × 몸 M1·F1): 5행(S·SE·E·NE·N) × [대기 1 · 걷기 6 · 달리기 6 · 구르기 5], 칸 32×32, 발 기준점 (16, 30).
  머리 시트(머리모양 × 몸): 5행(표정 idle·blink·fire·talk·hurt) × 5열(S·SE·E·NE·N), 칸 40×40, 구 중심 (20, 22).
    모자를 쓰면 숨는 머리(HR07 쪽머리)는 'HR07h' 시트를 따로 둔다. 방호복·스텔스 아머(T10·T15)는 후드 머리 시트.
  장비 층: 기본 머리(HR03) 대비 바뀐 칸만(머리 칸과 같은 40×40, 5열). 무기: 5열 20×16.
  메타: 컷마다 머리 구 중심(발 기준점 기준), 구르기 공 중심, 무기 손 위치, 보폭.
출력: game/assets/paperdoll/*.png + paperdoll.json. 팔레트 밖 색이 나오면 실패한다."""
import os, sys, json
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import palette as P
import chibi as K

OUT = os.path.join(ROOT, "game", "assets", "paperdoll")
ROWS = K.VIEWS
FAMS = ["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08", "T09", "T10", "T11", "T12", "T13", "T14", "T15", "T16", "GOWN"]
BODIES = ["M1", "F1", "K1"]
KID_FAMS = ["T01"]                                    # 아이 몸(K1, MQ-P2 열 살)은 볼트 작업복만
HAIRS = ["HR00", "HR01", "HR02", "HR03", "HR04", "HR05", "HR06", "HR07", "HR08", "HR09", "HR10", "HR11"]
GEARS = ["HD01", "HD02", "HD03", "HD04", "HD05", "HD06", "HD07", "HD08", "HD09", "HD10", "HD11", "HD12",
         "HD13", "HD14", "HD15", "HD16", "HD17", "HD18"]
EYES = ["EY01", "EY02", "EY03", "EY04", "EY05", "EY06", "EY07", "EY08"]
WEAPONS = ["pistol", "rifle", "smg", "baton", "bb", "pole"]
MOTIONS = [("idle", 1), ("walk", 6), ("run", 6), ("roll", 5)]
PF = "PF-01"                                         # 세력 슬롯 자리표시(색은 실행 중 팔레트가 정한다)
DIR8 = {"E": 0, "SE": 1, "S": 2, "SW": 3, "W": 4, "NW": 5, "N": 6, "NE": 7}
REF_CASES = [("M1", "T01", "HR03", "", "", "", "idle", "S", 0, None), ("M1", "T01", "HR03", "", "", "", "walk", "E", 2, None),
             ("M1", "T01", "HR05", "", "EY01", "", "run", "SE", 4, None), ("F1", "T03", "HR06", "", "", "", "walk", "NE", 1, None),
             ("M1", "T06", "HR03", "HD04", "", "rifle", "run", "W", 3, "E"), ("M1", "T02", "HR07", "HD03", "", "pistol", "idle", "N", 0, "N"),
             ("F1", "T13", "HR09", "", "EY02", "", "walk", "SW", 5, None), ("M1", "T08", "HR01", "HD15", "", "pistol", "walk", "S", 3, "SE"),
             ("K1", "T01", "HR09", "", "", "bb", "walk", "E", 2, "E"), ("K1", "T01", "HR03", "", "", "pole", "run", "SW", 4, "SE")]


def slot_map():
    m = {P.rgb(f"P{i:02d}"): i + 1 for i in range(64)}
    for k, c in enumerate(P.SKIN["S3"]):
        m[P.rgb(c)] = 65 + k
    for k, c in enumerate(P.HAIR["H1"]):
        m[P.rgb(c)] = 70 + k
    for k, c in enumerate(P.PF[PF][:4]):
        m[P.rgb(c)] = 74 + k
    for k, c in enumerate(P.PF[PF][4:6]):
        m[P.rgb(c)] = 78 + k
    return m


M = slot_map()


def to_index(img, where):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src, dst = img.load(), out.load()
    bad = set()
    for y in range(img.height):
        for x in range(img.width):
            p = src[x, y]
            if p[3]:
                i = M.get(p[:3])
                if i is None:
                    bad.add(p[:3])
                    continue
                dst[x, y] = (i, 0, 0, 255)
    if bad:
        raise SystemExit(f"{where}: 팔레트 밖 색 {sorted(bad)[:6]}")
    return out


def diff(a, b):
    """b에서 a와 달라진 칸만(장비 층)."""
    out = Image.new("RGBA", a.size, (0, 0, 0, 0))
    pa, pb, po = a.load(), b.load(), out.load()
    for y in range(a.height):
        for x in range(a.width):
            if pb[x, y] != pa[x, y] and pb[x, y][3]:
                po[x, y] = pb[x, y]
    return out


def body_sheet(fam, bt):
    look = K.Look(body=bt, torso=fam, faction=PF)
    cols = sum(n for _, n in MOTIONS)
    sheet = Image.new("RGBA", (cols * 32, 32 * len(ROWS)), (0, 0, 0, 0))
    anchors, starts = {}, {}
    c0 = 0
    for mo, n in MOTIONS:
        starts[mo] = {"start": c0, "count": n}
        for r, v in enumerate(ROWS):
            for f in range(n):
                if mo == "roll":
                    img, (hx, hy) = K.roll_body(look, f)
                else:
                    img, (hx, hy) = K.body(look, v, mo, f)
                sheet.alpha_composite(img, ((c0 + f) * 32, r * 32))
                anchors[f"{v}:{mo}:{f}"] = [hx - 16, hy - 30]          # 발 기준점에서 머리 구 중심(또는 공 중심)
        c0 += n
    return sheet, starts, anchors


def head_sheet(look):
    sheet = Image.new("RGBA", (40 * 5, 40 * len(K.FACES)), (0, 0, 0, 0))
    for r, face in enumerate(K.FACES):
        for c, v in enumerate(ROWS):
            sheet.alpha_composite(K.head(look, v, face), (c * 40, r * 40))
    return sheet


def overlay_strip(make):
    strip = Image.new("RGBA", (40 * 5, 40), (0, 0, 0, 0))
    for c, v in enumerate(ROWS):
        strip.alpha_composite(make(v), (c * 40, 0))
    return strip


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):                                       # v1 시트 정리
        if f.startswith("pd_") and f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    meta = {"version": 2, "style": "isaac",
            "slots": {"master": [1, 64], "skin": [65, 69], "hair": [70, 73], "main": [74, 77], "accent": [78, 79]},
            "rows": list(ROWS), "faces": list(K.FACES), "body_cell": [32, 32], "foot": [16, 30],
            "head_cell": [40, 40], "head_center": [K.HC, 22], "gun_cell": [20, 16], "gun_at": K.GUN_AT,
            "stride": K.STRIDE, "families": {}, "heads": {}, "overlays": {}, "weapons": {}, "palettes": {}}
    for bt in BODIES:
        for fam in (KID_FAMS if bt == "K1" else FAMS):
            sheet, starts, anchors = body_sheet(fam, bt)
            name = f"pd_body_{bt.lower()}_{fam.lower()}.png"
            to_index(sheet, name).save(os.path.join(OUT, name))
            o = K.outfit(K.Look(body=bt, torso=fam, faction=PF))
            meta["families"][f"{bt}:{fam}"] = {"sheet": name, "motions": starts, "head": anchors,
                                               "faction_slots": bool(o["faction"]), "gloved": o["hand"] is not None,
                                               "hood": fam in ("T10", "T15"), "gun_off": list(K.GUN_BODY.get(bt, (0, 0)))}
        for hr in HAIRS + ["HR07h"]:
            look = K.Look(body=bt, hair=hr[:4], gear="_HAT" if hr.endswith("h") else None)
            name = f"pd_head_{bt.lower()}_{hr.lower()}.png"
            to_index(head_sheet(look), name).save(os.path.join(OUT, name))
            meta["heads"][f"{bt}:{hr}"] = name
        for fam in (("T10", "T15") if bt != "K1" else ()):
            name = f"pd_head_{bt.lower()}_hood_{fam.lower()}.png"
            to_index(head_sheet(K.Look(body=bt, torso=fam)), name).save(os.path.join(OUT, name))
            meta["heads"][f"{bt}:HOOD_{fam}"] = name
    base = {v: K.head(K.Look(hair="HR03"), v) for v in ROWS}
    for g in GEARS:
        strip = overlay_strip(lambda v: diff(base[v], K.head(K.Look(hair="HR03", gear=g, faction=PF), v)))
        name = f"pd_gear_{g.lower()}.png"
        to_index(strip, name).save(os.path.join(OUT, name))
        meta["overlays"][g] = {"slot": "gear", "sheet": name}
    for e in EYES:
        strip = overlay_strip(lambda v: diff(base[v], K.head(K.Look(hair="HR03", eyes=e), v)))
        name = f"pd_eyes_{e.lower()}.png"
        to_index(strip, name).save(os.path.join(OUT, name))
        meta["overlays"][e] = {"slot": "eyes", "sheet": name}
    for w in WEAPONS:                                             # 맨손(피부 슬롯)·장갑(P02) 두 벌
        for suffix, hand in (("", K.skin_ramp("S3")[3]), ("_glove", K.C("P02"))):
            strip = Image.new("RGBA", (20 * 5, 16), (0, 0, 0, 0))
            for c, v in enumerate(ROWS):
                strip.alpha_composite(K.gun(v, w, hand), (c * 20, 0))
            name = f"pd_gun_{w}{suffix}.png"
            to_index(strip, name).save(os.path.join(OUT, name))
            meta["weapons"][w + suffix] = name
    # 대조용 합성본(art/tools/chibi.actor): 실행 중 페이퍼돌과 픽셀 단위로 같아야 한다(paperdoll_check 장면)
    refs = []
    for i, (bt, fam, hr, gear, eyes, weapon, mo, view, fr, aim) in enumerate(REF_CASES):
        lk = K.Look(body=bt, torso=fam, hair=hr, gear=gear or None, eyes=eyes or None, faction=PF if fam in ("T02", "T06", "T08", "T09") else None)
        img = K.actor(lk, view, mo, fr, aim=aim, weapon=weapon or None)
        name = f"ref_{i:02d}.png"
        img.save(os.path.join(OUT, name))
        refs.append({"png": name, "look": {"body": bt, "torso": fam, "hair": hr, "gear": gear, "eyes": eyes, "weapon": weapon},
                     "motion": mo, "dir": DIR8[view], "frame": fr, "aim": DIR8[aim] if aim else -1})
    meta["refs"] = refs
    meta["palettes"]["master"] = [P.NAMED[f"P{i:02d}"] for i in range(64)]
    meta["palettes"]["skin"] = {k: [P.resolve(c) if not c.startswith("#") else c for c in v] for k, v in P.SKIN.items()}
    meta["palettes"]["hair"] = {k: list(v) for k, v in P.HAIR.items()}
    meta["palettes"]["faction"] = {k: [P.resolve(c) if not c.startswith("#") else c for c in v] for k, v in P.PF.items()}
    json.dump(meta, open(os.path.join(OUT, "paperdoll.json"), "w"), ensure_ascii=False, sort_keys=True, indent=1)
    print("paperdoll v2:", len(meta["families"]), "bodies,", len(meta["heads"]), "heads,", len(meta["overlays"]), "overlays,",
          len(meta["weapons"]), "weapons")


if __name__ == "__main__":
    main()
