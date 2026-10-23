"""서울의 판도 자료(단계 1-12m, SD-06 §5 · SD-08 §15) → game/data/turf.json.
- 판도 구역(PD-Rxx-n): SD-08 §15.2 격자(구역 번호) × world.json 권역 격자 → 청크 '"x,y"' → 구역. 1단계는 R01 · R02(11구역).
- 거점: SD-06 §5.9(R01 7 · R02 6)를 SD-09a가 준 장소(L-ID) 좌표의 청크로 구역에 묶는다.
- 순찰 기반값(SD-06 §5.2 '정기 순찰 10 · 본거지 20'): 아래 PATROL. 'home'은 그 구역에 자기 거점이 남아 있을 때만 20(1-12m 재미 검수 ①).
- 원고: script/world/turf.txt(구역 한 줄 서술) · script/world/factions.txt(세력 기록) + SD-06 §4.3 표의 '핍-보이 한 줄'(관계 단계 6줄).
- 검사: 거점 장소가 그 구역 청크에 들고, 시작 상태(사건 보정 0)가 SD-08 §15.2 '단계'와 같은지(공식은 game/core/story/turf.gd와 같게)."""
import os, sys, re, json

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOC08 = os.path.join(ROOT, "docs", "seoul-fallout", "08_world-regions.md")
DOC06 = os.path.join(ROOT, "docs", "seoul-fallout", "06_factions.md")
WORLD = os.path.join(ROOT, "game", "data", "world", "world.json")
PLACES = os.path.join(ROOT, "game", "data", "world", "places.json")
TURF_TXT = os.path.join(ROOT, "script", "world", "turf.txt")
FAC_TXT = os.path.join(ROOT, "script", "world", "factions.txt")
OUT = os.path.join(ROOT, "game", "data", "turf.json")

REGIONS = ["R01", "R02"]
STATES = ["공백", "경합", "우세", "지배"]
STAGES = ["적대", "경계", "중립", "우호", "신뢰", "동맹"]

# 거점(SD-06 §5.9 · SD-09a L122 · L746): ID, 이름, 장소, 처음 주인, 가중치, 봉인(바깥에 영향력 없음)
NODES = [
    ("N-R01-1", "볼트 S-07", "L-R01-01", "S7", 3, True),
    ("N-R01-2", "봉천 계단마을", "L-R01-09", "BC", 2, False),
    ("N-R01-3", "노량진 관제 중계소", "L-R01-23", "GS", 2, False),
    ("N-R01-4", "남부순환로 관악 검문소", "L-R01-19", "BJ", 1, False),
    ("N-R01-5", "사당 환승촌", "L-R01-18", "SA", 1, False),
    ("N-R01-6", "남부순환 패거리 은신처", "L-R01-14", "YT", 1, False),
    ("N-R01-7", "관악산 송신소", "L-R01-04", "", 1, False),
    ("N-R02-1", "영등포 지하상가", "L-R02-11", "JH", 3, False),
    ("N-R02-2", "새벽인력 본소", "L-R02-19", "SB", 2, False),
    ("N-R02-3", "여의도 검문소", "L-R02-03", "BJ", 1, False),
    ("N-R02-4", "여의도 환승센터 터", "L-R02-28", "SB", 1, False),
    ("N-R02-5", "여의도 지하 벙커", "L-R02-02", "", 1, False),
    ("N-R02-6", "국회 폐허", "L-R02-01", "", 1, False),
]
# 구역마다 순찰 기반값: 세력 -> [값, home(거점이 남아 있을 때만 그 값 — 잃으면 10)]
PATROL = {
    "PD-R01-1": {"BJ": [10, False], "YT": [10, False]},
    "PD-R01-2": {"BC": [10, False], "YT": [10, False], "BJ": [10, False]},
    "PD-R01-3": {"YT": [20, True], "BC": [10, False], "SB": [10, False]},
    "PD-R01-4": {"BJ": [20, True], "SA": [10, False]},
    "PD-R01-5": {"GS": [10, False], "BJ": [10, False]},
    "PD-R01-6": {"YT": [20, False], "SB": [15, False]},
    "PD-R02-1": {"BJ": [10, False], "SB": [10, False], "YH": [5, False]},
    "PD-R02-2": {"SB": [15, False], "YT": [10, False]},
    "PD-R02-3": {"YT": [20, False], "JH": [15, False]},
    "PD-R02-4": {"SB": [20, True]},
    "PD-R02-5": {"SB": [20, False], "YT": [10, False]},
}
# 서로 '전쟁'(SD-06 관계 매트릭스 — 1막 남쪽 판도에 걸리는 쌍만): 3일 틱이 경합 구역에서 이 쌍만 계산한다
WARS = [["BJ", "YT"], ["SB", "YT"], ["JH", "YT"], ["BC", "YT"], ["SA", "YT"], ["GS", "YT"], ["SB", "BC"], ["SB", "SA"]]
# 지도 표시(SD-16 §9.3.1): 세력 -> [이름, 색, 무늬]
SHOW = {
    "BJ": ["비상정부", "#5A6A86", "hline"], "YH": ["연합단", "#5A6132", "slash"], "WP": ["원칙파", "#A82A26", "bslash"],
    "JH": ["지하시장", "#F2B866", "dot"], "GS": ["각성회", "#C47A12", "ring"], "JG": ["중국군 잔존병", "#4C5E3C", "vline"],
    "SB": ["새벽인력", "#FF7A1C", "checker"], "JC": ["정착지 연합", "#D27A3A", "cross"], "NJ": ["난지 고철단", "#E8682A", "zigzag"],
    "KD": ["큰돌 무리", "#8C9A78", "bigdot"], "YT": ["약탈자", "#85391C", "sparse"], "S7": ["볼트 S-07", "#E8C23A", "none"],
    "BC": ["봉천 계단마을", "#D27A3A", "cross"], "SA": ["사당 환승촌", "#D27A3A", "plus"],
}
# 틀문장(구역 서술이 원고에 없을 때)
TEMPLATE = {
    "지배": "{a} 표식이 골목마다 붙어 있다. 다른 깃발은 보이지 않는다.",
    "우세": "{a} 사람들이 길목을 쥐고 있다. {b} 쪽 흔적도 남아 있다.",
    "경합": "{a}와 {b}가 길목마다 서로 깃발을 찢는다.",
    "공백": "깃발 하나 없다. 짐승과 떠돌이만 지나간다.",
}
# 구역 정보 줄 끝의 '쓸모 있는 한 마디'(재미 검수 ③ — 실제 효과에서: SD-05 §6.3 인카운터 · SD-06 §5.6 상점)
# 범주 가중(SD-05 §6.3)에서 나온 '마주칠 것' — 서술 문장과 어긋나지 않게 사람 · 짐승 비율만 말한다(1-12m 구현 뒤 재미 검수 ③)
USE = {
    "지배": "{a} 사람을 자주 마주친다", "우세": "{a} 쪽 사람을 마주치기 쉽다", "경합": "교전 소리가 자주 들린다", "공백": "짐승과 떠돌이 패거리를 만나기 쉽다",
    "지배BJ": "검문이 잦다", "지배YT": "패거리가 길을 막는다", "우세YT": "패거리를 마주치기 쉽다",
}


def zone_grid():
    lines = open(DOC08, encoding="utf-8").read().split("\n")
    st = next(i for i, l in enumerate(lines) if l.startswith("**판도 구역 격자**"))
    grid = {}
    for l in lines[st:st + 60]:
        m = re.match(r"^(\d\d)   (.*)$", l)
        if m:
            for x, c in enumerate(m.group(2)):
                grid[(x, int(m.group(1)))] = c
    meta = {}
    sec = next(i for i, l in enumerate(lines) if l.startswith("### 15.2"))
    for l in lines[sec:sec + 70]:
        m = re.match(r"^\| (PD-R\d\d-\d) \| (R\d\d) \| ([^|]+) \| C-(\d\d)-(\d\d) \| (\d+) \|[^|]*\| ([^|]+) \| ([^|]+) \|", l)
        if m:
            meta[m.group(1)] = {"region": m.group(2), "name": m.group(3).strip(), "seed": [int(m.group(4)), int(m.group(5))],
                                "n": int(m.group(6)), "start": m.group(7).strip(), "stage": m.group(8).strip()}
    return grid, meta


def pipboy_lines():
    """SD-06 §4.3.x 표 '핍-보이 한 줄' 칸 → 세력 -> [단계 6줄]"""
    L = open(DOC06, encoding="utf-8").read().split("\n")
    out, cur = {}, None
    for l in L:
        m = re.match(r"^#### 4\.3\.\d+ (\w+)", l)
        if m:
            cur = m.group(1)
            out[cur] = {}
            continue
        if l.startswith("### ") and cur:
            cur = None
        if cur and l.startswith("| "):
            cells = [c.strip() for c in l.strip().strip("|").split("|")]
            if cells[0] in STAGES:
                out[cur][cells[0]] = cells[-1].strip('"“”')
    return {k: [v.get(s, "") for s in STAGES] for k, v in out.items() if v}


def parse_turf():
    zones, cur, errs = {}, None, []
    for i, ln in enumerate(open(TURF_TXT, encoding="utf-8").read().split("\n"), 1):
        s = ln.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("@구역"):
            cur = s.split()[1]
            zones[cur] = {}
            continue
        if cur is None or ":" not in s:
            errs.append(f"turf.txt:{i}: 머리 줄 없이 · 또는 ':' 없음")
            continue
        k, t = s.split(":", 1)
        k = k.strip()
        if k.split()[0] not in STATES or (len(k.split()) == 3 and k.split()[2] != "빈"):
            errs.append(f"turf.txt:{i}: 모르는 상태 '{k}'")
        zones[cur][k] = t.strip()
    return zones, errs


def parse_factions():
    facs, cur, errs = {}, None, []
    for i, ln in enumerate(open(FAC_TXT, encoding="utf-8").read().split("\n"), 1):
        s = ln.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("@세력"):
            p = s.split(None, 2)
            cur = p[1]
            facs[cur] = {"name": p[2], "desc": "", "near": [""] * 5, "treat": [""] * 6, "hear": [""] * 6}
            continue
        if cur is None or ":" not in s:
            errs.append(f"factions.txt:{i}: 머리 줄 없이 · 또는 ':' 없음")
            continue
        k, t = s.split(":", 1)
        k, t = k.strip(), t.strip()
        f = facs[cur]
        if k == "소개":
            f["desc"] = t
        elif k.startswith("가까움 "):
            a, b = k[4:].split("|")
            ia = STAGES.index(a)
            if STAGES.index(b) != ia + 1:
                errs.append(f"factions.txt:{i}: 경계는 이웃한 두 단계여야 한다")
            f["near"][ia] = t
        elif k.startswith("대우 "):
            f["treat"][STAGES.index(k[3:])] = t
        elif k.startswith("들림 "):
            f["hear"][STAGES.index(k[3:])] = t
        else:
            errs.append(f"factions.txt:{i}: 모르는 칸 '{k}'")
    return facs, errs


## game/core/story/turf.gd와 같은 공식(SD-06 §5.2): 사건 보정 0일 때의 시작 상태
def start_state(zid, nodes):
    inf = {}
    owned = {}
    for n in nodes.values():
        if n["zone"] == zid and n["owner"] and not n["sealed"]:
            owned[n["owner"]] = owned.get(n["owner"], 0) + n["w"]
    for f, w in owned.items():
        inf[f] = min(60, w * 15)
    for f, (b, home) in PATROL[zid].items():
        inf[f] = inf.get(f, 0) + (b if (not home or owned.get(f, 0) > 0) else 10)
    rank = sorted(inf.items(), key=lambda kv: -kv[1])
    a = rank[0] if rank else ("", 0)
    b = rank[1] if len(rank) > 1 else ("", 0)
    if a[1] < 20:
        return "공백"
    if a[1] >= 50 and a[1] - b[1] >= 25:
        return "지배"
    if a[1] - b[1] >= 10:
        return "우세"
    return "경합"


def main():
    grid, meta = zone_grid()
    w = json.load(open(WORLD, encoding="utf-8"))
    places = json.load(open(PLACES, encoding="utf-8"))
    errs = []
    chunk_zone = {}
    zones = {}
    for k, r in w["regions"].items():
        if r not in REGIONS:
            continue
        x, y = map(int, k.split(","))
        c = grid.get((x, y), ".")
        if not c.isdigit():
            errs.append(f"청크 {k}({r})가 판도 구역 격자에 없다")
            continue
        zid = f"PD-{r}-{c}"
        chunk_zone[k] = zid
        zones.setdefault(zid, {"chunks": []})["chunks"].append([x, y])
    for zid, z in zones.items():
        m = meta.get(zid)
        if m is None:
            errs.append(f"{zid}: SD-08 §15.2 표에 없다")
            continue
        if len(z["chunks"]) != m["n"]:
            errs.append(f"{zid}: 청크 수 {len(z['chunks'])} ≠ 원문 {m['n']}")
        z.update({"name": m["name"], "region": m["region"], "seed": m["seed"], "patrol": PATROL[zid]})
    nodes = {}
    for nid, nm, lid, own, wt, sealed in NODES:
        p = places.get(lid)
        if p is None:
            errs.append(f"{nid}: 장소 {lid} 없음")
            continue
        ck = f"{p['tx'] // 40},{p['ty'] // 40}"
        zid = chunk_zone.get(ck, "")
        if not zid:
            errs.append(f"{nid}: {lid} 청크 {ck}가 R01·R02 판도 구역 밖")
        nodes[nid] = {"name": nm, "lid": lid, "owner": own, "w": wt, "zone": zid, "tx": p["tx"], "ty": p["ty"], "sealed": sealed}
    want = {"공백": "공백", "경합": "경합", "우세": "우세", "장악": "지배"}
    for zid in sorted(zones):
        got = start_state(zid, nodes)
        exp = want.get(meta[zid]["stage"], meta[zid]["stage"])
        if got != exp:
            errs.append(f"{zid}: 시작 상태 {got} ≠ SD-08 §15.2 {exp}")
    lines, e1 = parse_turf()
    errs += e1
    for zid in lines:
        if zid not in zones:
            errs.append(f"turf.txt: 모르는 구역 {zid}")
        else:
            zones[zid]["lines"] = lines[zid]
    for zid in zones:
        if "lines" not in zones[zid]:
            errs.append(f"turf.txt: {zid} 서술 없음")
    facs, e2 = parse_factions()
    errs += e2
    pl = pipboy_lines()
    for code, f in facs.items():
        base = code.split("_")[0]
        f["stage"] = pl.get(base, [""] * 6)
        if base == "NJ" and f["stage"][5] == "":
            f["stage"][5] = f["stage"][4]                                  # 고철단은 동맹이 없다(최대 신뢰, SD-06 §3.2.3)
        if base == code:
            if any(s == "" for s in f["stage"]):
                errs.append(f"SD-06 §4.3 {code} 핍-보이 한 줄 빠짐")
            if code != "NJ" and (any(s == "" for s in f["near"]) or any(s == "" for s in f["treat"]) or any(s == "" for s in f["hear"])):
                errs.append(f"factions.txt: {code} 칸 빠짐")
    for e in errs:
        print("오류 판도:", e)
    if errs:
        sys.exit(1)
    out = {"zones": zones, "chunk_zone": chunk_zone, "nodes": nodes, "wars": WARS, "show": SHOW, "template": TEMPLATE, "use": USE,
           "factions": facs, "states": STATES, "stages": STAGES}
    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=0, sort_keys=True)
    print(f"판도: 구역 {len(zones)} · 청크 {len(chunk_zone)} · 거점 {len(nodes)} · 세력 기록 {len(facs)} — 시작 상태 SD-08 §15.2와 같음")


if __name__ == "__main__":
    main()
