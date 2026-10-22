#!/usr/bin/env python3
"""퀘스트 교차 정합 표(SD-20 §10, 사용자 지시 2026-10-16).

퀘스트 하나 안이 아니라 **퀘스트끼리** 서로 부딪히는 곳을 정적으로 뽑는다.
  · 원고(컴파일된 game/data/dialogue/*.json) · 진행기(game/scenes/story/*.gd 등) · 맵 인물 배치(game/data/maps/*.json)를 읽어
    단위(퀘스트·장소 묶음)마다 발자국(인물 · 이름 언급 · 맵 · 변수 읽기/쓰기 · 주는 물건 · 막 조건 · 시한)을 만들고,
  · 아래 경고를 낸다(허용 목록 tools/pipeline/quest_cross_allow.yaml에 이유가 적힌 것은 '허용'으로 내림).

경고 종류
  X1 사람 — 죽을 수 있는 이름 있는 인물을 다른 단위가 말하거나(대사 속 이름) 세우는데, 그 단위에 죽음 조건이 없다(dead("ID") · D_ 변수 · st.dead.has).
  X2 한 사람 두 곳 — 같은 인물의 맵 배치 둘이 동시에 참이 될 수 있다(조건식을 값 조합으로 풀어 본다).
  X3 사실 — 다른 퀘스트 소유 변수를 쓰는 단위(P1 한 곳에서만 세우나), 읽기만 하고 아무도 안 세우는 변수(죽은 분기), 세우기만 하고 아무도 안 읽는 퀘스트 변수(P12 반응 없음).
  X4 물건 — 한 장뿐인 물건(M-1xx~3xx)을 둘 이상의 곳이 준다(P3 · A38).
  X5 무대 — 둘 이상의 진행기가 같은 손 맵을 무대로 쓴다(P5 ⑥ 닫힌 무대 · 안전한 순간).
  X6 받기만 하고 안 함 — 퀘스트 장면이 막 조건(V_ACT 상한)으로 닫히는데 퀘스트에 시한·마감 처리가 없다, 또는 시한이 없어 영원히 열린 채 남는다(정보).
  X7 자리 비운 화자 — 장면에 말하는 인물(장면 주인이 아닌)이 맵에 조건부로만 서는데(다른 퀘스트로 자리를 비우는 날 · 시간대 · 사망 뒤 등),
     장면이 그 조건 변수를 하나도 보지 않는다 → 없는 사람이 말할 수 있다(P3 · 1-12d 노복희 S13 투표 날).
  X8 그날 밤 시각 — 2077-10-23 맥락(2077 · 그날 · 10. 23 · 막차 · 경보 …)의 원고 · 맵 글에서 시각이 정본 시각표(SD-02 §3.3)보다 앞서
     결과가 원인보다 먼저 온다(예: 22:00 '운행 중지' — 경보는 23:19). 전체 시각 목록은 보고서에 따로 싣는다(1-12d).

실행: python3 tools/pipeline/quest_cross.py  → game/data/_cross_report.md · _cross_report.json
"""
import glob
import itertools
import json
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
G = os.path.join(ROOT, "game")
ALLOW = os.path.join(ROOT, "tools", "pipeline", "quest_cross_allow.yaml")

# 진행기 파일 → 단위
PROG = {
    "scenes/story/side_r01.gd": "SQ-S01", "scenes/story/side_s02.gd": "SQ-S02", "scenes/story/side_s04.gd": "SQ-S04",
    "scenes/story/mq101.gd": "MQ-101", "scenes/story/mq106.gd": "MQ-106", "scenes/story/act1_paths.gd": "MQ-102~105",
    "scenes/story/home_bc.gd": "HOME_BC", "scenes/story/rq_r01.gd": "RQ", "core/story/repeat.gd": "RQ", "scenes/story/caravans.gd": "상인 순회", "scenes/story/prologue.gd": "프롤로그",
    "systems/world/encounter_live.gd": "인카운터", "core/story/encounters.gd": "인카운터", "core/story/rumors.gd": "소문",
    "core/story/radio.gd": "라디오", "core/story/wanted.gd": "수배", "systems/world/interior_host.gd": "엔진",
    "systems/world/world_map.gd": "엔진", "core/story/quest_log.gd": "엔진", "core/story/deeds.gd": "전파",
    "scenes/story/uq71.gd": "UQ-71", "scenes/story/uq04.gd": "UQ-04", "scenes/story/uq_r01.gd": "UQ-01|UQ-02|UQ-03|UQ-05|UQ-62|UQ-63|UQ-64|UQ-65|UQ-66|UQ-67", "scenes/story/uq_r02.gd": "UQ-07|UQ-08|UQ-09|UQ-10|UQ-70", "scenes/story/gr.gd": "DG-GR", "scenes/story/kt.gd": "DG-KT", "systems/world/dungeon.gd": "던전", "scenes/story/u02.gd": "U02",
    # 1-11 이후 진행기(1-12d 교차 점검 보강 — 빠져 있어 진행기의 생사 판정 · 변수 쓰기가 교차 표에 안 잡혔다). '|'는 한 진행기가 맡은 단위 여럿
    "scenes/story/side_s03.gd": "SQ-S03", "scenes/story/side_s05.gd": "SQ-S05", "scenes/story/side_s06.gd": "SQ-S06", "scenes/story/side_s08.gd": "SQ-S08",
    "scenes/story/side_s09.gd": "SQ-S09", "scenes/story/side_s10.gd": "SQ-S10", "scenes/story/side_s11.gd": "SQ-S11", "scenes/story/side_s12.gd": "SQ-S12",
    "scenes/story/side_s13.gd": "SQ-S13", "scenes/story/fq_jc01.gd": "FQ-JC-01", "scenes/story/fq_gs.gd": "FQ-GS-01|FQ-GS-02", "scenes/story/fq_jh.gd": "FQ-JH-01|FQ-JH-02", "scenes/story/fq_jh3.gd": "FQ-JH-03", "scenes/story/fq_sb.gd": "FQ-SB-01|FQ-SB-02",
    "scenes/story/ga.gd": "GA", "scenes/story/hp.gd": "HP", "scenes/story/ks.gd": "KS", "scenes/story/yt.gd": "YT", "scenes/story/u04.gd": "U04", "scenes/story/stash.gd": "UQ-125",
}
# 막 3개짜리 경로 묶음(MQ-102~105)은 한 진행기 — 변수 소유는 아래 접두로 나눈다
NPC_RE = re.compile(r'"((?:C-\d{3}|N-[A-Z0-9]{2,4}-\d{3}|CR-\d{3}))"')
VAR_RE = re.compile(r"\b([A-Z][A-Z0-9]*_[A-Z0-9_]+|V_[A-Z]+|GAME_DAY|GAME_HOUR)\b")
ASSIGN_RE = re.compile(r"\b([A-Z][A-Z0-9_]+)\s*(?:\+=|-=|=)(?!=)")
GDGET_RE = re.compile(r'(?:get_v|has)\("([A-Z][A-Z0-9_]*[A-Z0-9])"(?!\s*\+)')   # "FQ_JH01_" + k 처럼 이어 붙이는 앞부분은 변수가 아니다(1-12d)
GDSET_RE = re.compile(r'(?:set_v|add)\("([A-Z][A-Z0-9_]*[A-Z0-9])"(?!\s*\+)')
GDV_RE = re.compile(r'\bv\("([A-Z][A-Z0-9_]+)"\)')
ITEM_GIVE_RE = re.compile(r'give\(\\?"(M-\d{3})\\?"')
GD_GIVE_RE = re.compile(r'call_fn\("give",\s*\["(M-\d{3})"')
ENTER_RE = re.compile(r'\benter\("([A-Z]-[A-Z0-9]+|[A-Z]{1,2}-\d{2})"')
SCENE_RE = re.compile(r'play_scene\("([^"]+)"')
NOT_VARS = {"SYS", "END", "START"}
PROLOGUE = {"MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "프롤로그"}            # 볼트 평시(V_ACT 0): 주민을 죽일 수 없다(SD-10 §6.3 정합) · 프롤로그 불사 4인
DEAD_VARS = {"D_JMS": "C-010", "D_BIH": "C-011", "D_MKJ": "C-012", "D_HDC": "C-013", "D_MYS": "C-006", "D_SMR": "C-008",
             "D_DS": "C-005", "D_MXM": "C-007", "D_RJ": "C-014", "D_JL": "C-017", "D_BG": "C-015"}   # StoryState.DEAD_VARS와 같게


def owner_of(var):
    m = re.match(r"^MQ(\d{3}|P\d)_", var)
    if m:
        n = m.group(1)
        if n in ("102", "103", "104", "105"):
            return "MQ-102~105"
        return "MQ-" + n
    m = re.match(r"^SQ[A-Z]?_(S\d\d)", var)
    if m:
        return "SQ-" + m.group(1)
    m = re.match(r"^UQ(\d\d)_", var)                                      # 비표시 퀘스트(1-D1 UQ-71)
    if m:
        return "UQ-" + m.group(1)
    m = re.match(r"^FQ_([A-Z]{2})(\d\d)_", var)                           # 세력 퀘스트(1-12 — FQ_JH02_TAK → FQ-JH-02)
    if m:
        return "FQ-%s-%s" % (m.group(1), m.group(2))
    if var.startswith("DG_"):                                            # 던전 정리 변수(1-D0)
        return "던전"
    if var.startswith("U02_"):                                           # U02 남태령 지하(1-D2 — 훅 UG-H01 · UG-H02)
        return "U02"
    return None


def unit_of_src(src):
    base = os.path.splitext(os.path.basename(src))[0]
    d = os.path.basename(os.path.dirname(src))
    if d in ("act1", "prologue"):
        if base in ("MQ-102", "MQ-103", "MQ-104", "MQ-105"):
            return "MQ-102~105"
        return base
    return "장소:" + base


def load_allow():
    out = {}
    if not os.path.exists(ALLOW):
        return out
    for line in open(ALLOW, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r'^\s*"([^"]+)"\s*:\s*(.*)$', line)             # 키는 따옴표 안('장소:…'처럼 쌍점이 들어갈 수 있다), 값은 이유
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"')
    return out


def new_unit():
    return {"npcs": {}, "mentions": {}, "reads": set(), "writes": set(), "maps": set(), "give": {}, "guards": set(),
            "act_max": None, "expire": False, "files": set(), "scenes": set(), "pguards": set()}


def main():
    npcs = json.load(open(os.path.join(G, "data", "npcs.json"), encoding="utf-8"))["npcs"]
    names = {}
    COMMON = {"철사", "갈고리", "소개비", "빨간펜"}                       # 별명이 보통 낱말과 같은 인물(철사 = 쇠줄) — 이름 언급으로 세지 않는다
    def canon(nid):                                                       # 별칭(백구 N-R01-027 = C-015) — StoryState.canon과 같게
        ids = npcs.get(nid, {}).get("ids") or []
        return ids[0] if ids else nid
    for nid, n in npcs.items():
        nm = str(n.get("name", ""))
        if len(nm) >= 2 and nm not in names.values() and nm not in COMMON:
            names[canon(nid)] = nm
    units = {}

    def U(name):
        if name not in units:
            units[name] = new_unit()
        return units[name]

    sguard = {}                                                           # 장면 → 그 장면 안(조건 · 갈래)에서 생사를 보는 인물 — X1은 장면마다 본다(1-X 보강)
    scn = {}                                                              # 장면 → {npc, vars(장면이 보는 변수 전부), who(말하는 인물)} — X7
    times = []                                                            # (출처, 글) — X8

    def guards_in(c):
        out = {canon(x) for x in re.findall(r'(?:known_)?dead\(\\?"([^"\\]+)\\?"\)', c or "")}
        for v in re.findall(r"\b(D_[A-Z]+)\b", c or ""):
            if v in DEAD_VARS:
                out.add(DEAD_VARS[v])
        return out

    def scan_cond(u, c):
        for v in VAR_RE.findall(c or ""):
            if v not in NOT_VARS:
                u["reads"].add(v)
        for m in re.findall(r'dead\(\\?"([^"\\]+)\\?"\)', c or ""):
            u["guards"].add(canon(m))
        for v in re.findall(r"\b(D_[A-Z]+)\b", c or ""):
            if v in DEAD_VARS:
                u["guards"].add(DEAD_VARS[v])
        m = re.search(r"V_ACT\s*(<=|==|<)\s*(\d)", c or "")
        if m:
            mx = int(m.group(2)) - (1 if m.group(1) == "<" else 0)
            u["act_max"] = mx if u["act_max"] is None else max(u["act_max"], mx)

    def scan_fx(u, fx, where):
        if not fx:
            return
        for v in ASSIGN_RE.findall(fx):
            u["writes"].add(v)
        rhs = re.sub(r"\b[A-Z][A-Z0-9_]+\s*(?:=)(?!=)", "", fx)
        for v in VAR_RE.findall(rhs):
            u["reads"].add(v)
        for it in ITEM_GIVE_RE.findall(fx):
            u["give"].setdefault(it, []).append(where)

    # ---- 원고 장면
    idx = json.load(open(os.path.join(G, "data", "dialogue", "_index.json"), encoding="utf-8"))["scenes"]
    for sid in idx:
        p = os.path.join(G, "data", "dialogue", sid + ".json")
        if not os.path.exists(p):
            continue
        d = json.load(open(p, encoding="utf-8"))
        u = U(unit_of_src(d.get("src", "")))
        u["scenes"].add(sid)
        u["files"].add(d.get("src", ""))
        scan_cond(u, d.get("cond", ""))
        g = guards_in(d.get("cond", ""))
        for o in d["ops"]:
            if o["op"] == "if":
                g |= guards_in(o["cond"])
            elif o["op"] == "choice":
                for opt in o["opts"]:
                    g |= guards_in(opt.get("cond", ""))
        sguard[sid] = g
        sv = set(VAR_RE.findall(d.get("cond", "") or ""))
        who = set()
        shown = set()
        for o in d["ops"]:
            if o["op"] == "if":
                sv |= set(VAR_RE.findall(o["cond"]))
            elif o["op"] == "choice":
                for opt in o["opts"]:
                    sv |= set(VAR_RE.findall(opt.get("cond", "") or ""))
                    times.append(("장면 " + sid, opt.get("text", "")))
            elif o["op"] == "line":
                w = o.get("who", "")
                if w and w not in ("SYS", "PC") and not w.startswith("N-PS"):
                    who.add(canon(w))
                times.append(("장면 " + sid, o.get("text", "")))
            elif o["op"] == "cmd" and o["name"] in ("show", "move", "face", "pose", "buddy"):
                shown |= {canon(x) for x in re.findall(r"\b(C-\d{3}|N-[A-Z0-9]{2,4}-\d{3})\b", " ".join(str(a) for a in o.get("args", [])))}
        scn[sid] = {"npc": canon(d.get("npc", "") or "-"), "vars": sv, "who": who - shown, "unit": unit_of_src(d.get("src", ""))}
        if d.get("npc") and d["npc"] != "-":
            u["npcs"].setdefault(canon(d["npc"]), set()).add("장면 " + sid)
        for o in d["ops"]:
            if o["op"] == "if":
                scan_cond(u, o["cond"])
            elif o["op"] == "do":
                scan_fx(u, o["fx"], sid)
            elif o["op"] == "line":
                w = o.get("who", "")
                if w and w not in ("SYS", "PC") and not w.startswith("N-PS"):
                    u["npcs"].setdefault(canon(w), set()).add("말함 " + sid)
                txt = o.get("text", "")
                for nid, nm in names.items():
                    if nm in txt and nid != canon(w) and nid != canon(d.get("npc", "")):
                        u["mentions"].setdefault(nid, set()).add(sid)
            elif o["op"] == "choice":
                for opt in o["opts"]:
                    scan_cond(u, opt.get("cond", ""))
                    scan_fx(u, opt.get("fx", ""), sid)
            elif o["op"] == "cmd":
                args = " ".join(str(a) for a in o.get("args", []))
                for nid in re.findall(r"\b(C-\d{3}|N-[A-Z0-9]{2,4}-\d{3})\b", args):
                    if o["name"] in ("show", "move", "face", "pose"):
                        u["npcs"].setdefault(canon(nid), set()).add("연출 " + sid)

    # ---- 진행기
    reads_any = set()
    for rel, uns in PROG.items():
        p = os.path.join(G, rel)
        if not os.path.exists(p):
            continue
        src = open(p, encoding="utf-8").read()
        for ui, un in enumerate(uns.split("|")):                          # 한 진행기가 단위 여럿을 맡으면(fq_jh.gd = JH-01 · JH-02) 발자국을 둘 다에 — 물건 · 무대는 한 번만(X4 · X5 겹셈 없게)
            u = U(un)
            first = ui == 0
            u["files"].add(rel)
            for v in GDGET_RE.findall(src) + GDV_RE.findall(src):
                u["reads"].add(v)
            for v in GDSET_RE.findall(src):
                u["writes"].add(v)
            # 문자열 속 조건식(cond = "…")의 변수
            for s in re.findall(r'"([^"\n]*(?:==|>=|<=|!=)[^"\n]*)"', src):
                scan_cond(u, s)
            for it in (GD_GIVE_RE.findall(src) if first else []):
                u["give"].setdefault(it, []).append(rel)
            consts = dict(re.findall(r'^const\s+(\w+)\s*:?=\s*"([A-Z]+-[^"]+)"', src, re.M))   # 진행기 상수(const HAL := "N-UG-007") — is_dead(HAL)도 생사 판정(1-D2)
            boxes = {}                                                    # 상수 목록 · 사전(const VOTERS := {"B": "C-050", …}) — 그 이름으로 생사를 보면 안의 인물 모두(1-12d)
            for m in re.finditer(r'^const\s+(\w+)\s*(?::\s*\w+\s*)?:?=\s*([\[{].*?[\]}])\s*(?:#.*)?$', src, re.M | re.S):
                ids = NPC_RE.findall(m.group(2))
                if ids:
                    boxes[m.group(1)] = ids
            body = "\n".join(l for l in src.split("\n") if not l.startswith("const "))
            used_names = {n for n in list(consts) + list(boxes) if re.search(r"\b%s\b" % n, body)}
            for nid in NPC_RE.findall(body):                              # 정의만 있고 쓰이지 않는 상수의 인물은 세지 않는다
                if nid.startswith("CR-"):
                    continue
                u["npcs"].setdefault(canon(nid), set()).add("진행기 " + os.path.basename(rel))
            for n in used_names:
                for nid in ([consts[n]] if n in consts else boxes[n]):
                    if not nid.startswith("CR-"):
                        u["npcs"].setdefault(canon(nid), set()).add("진행기 " + os.path.basename(rel))
            DEADF = r'(?:dead\.has|is_dead|known_dead|_dead)'
            for nid in re.findall(DEADF + r'\("([^"]+)"\)', src) + \
                    [consts[c] for c in re.findall(DEADF + r'\((\w+)\)', src) if c in consts]:
                u["guards"].add(canon(nid))
                u["pguards"].add(canon(nid))
            for line in src.split("\n"):                                 # 목록 · 사전으로 보는 판정(st.is_dead(VOTERS[k]) · SB_HEADS.all(func(c): … is_dead(c)))
                if re.search(DEADF + r"\(", line):
                    for n, ids in boxes.items():
                        if re.search(r"\b%s\b" % n, line):
                            for nid in ids:
                                u["guards"].add(canon(nid))
                                u["pguards"].add(canon(nid))
            for v in re.findall(r'"(D_[A-Z]+)"', src) + re.findall(r'\bv\("(D_[A-Z]+)"\)', src):
                if v in DEAD_VARS:
                    u["guards"].add(DEAD_VARS[v])
                    u["pguards"].add(DEAD_VARS[v])
            if rel.startswith("scenes/story/") and first:
                for m in ENTER_RE.findall(src):
                    u["maps"].add(m)
            if re.search(r"EXPIRE|DEADLINE|만료|_expire", src):
                u["expire"] = True
    # 다른 모든 .gd도 '읽음'으로 센다(엔진 · UI가 읽는 변수는 반응이 있다)
    for p in glob.glob(os.path.join(G, "**", "*.gd"), recursive=True):
        if "/tests/" in p or "/bench/" in p:
            continue
        src = open(p, encoding="utf-8").read()
        reads_any |= set(GDGET_RE.findall(src) + GDV_RE.findall(src))
        for s in re.findall(r'"([^"\n]*(?:==|>=|<=|!=)[^"\n]*)"', src):
            reads_any |= set(VAR_RE.findall(s))

    # ---- 맵 인물 배치(조건)
    placements = {}
    for p in glob.glob(os.path.join(G, "data", "maps", "*.json")):
        m = json.load(open(p, encoding="utf-8"))
        for n in m.get("npcs", []):
            placements.setdefault(canon(n["id"]), []).append((m["id"], n.get("cond", "") or ""))
            for v in VAR_RE.findall(n.get("cond", "") or ""):
                reads_any.add(v)
    for p in [os.path.join(G, "data", "rumors.json"), os.path.join(G, "data", "radio.json"), os.path.join(G, "data", "quests.json"),
              os.path.join(G, "data", "notes.json"), os.path.join(G, "data", "terminals.json"), os.path.join(G, "data", "world", "encounters.json")]:
        if os.path.exists(p):
            reads_any |= set(VAR_RE.findall(open(p, encoding="utf-8").read()))
    for u in units.values():
        reads_any |= u["reads"]
    writes_any = set()
    for u in units.values():
        writes_any |= u["writes"]
    vdecl = json.load(open(os.path.join(G, "data", "vars.json"), encoding="utf-8"))["vars"]

    allow = load_allow()
    warns = []

    def warn(kind, key, msg):
        k = "%s %s" % (kind, key)
        warns.append({"kind": kind, "key": key, "msg": msg, "allowed": allow.get(k, "")})

    # X1 사람: 죽을 수 있는 인물(맵에 서는 이름 있는 인물)을 다른 단위가 말하거나 세움
    #   죽일 수 없는 인물: 아이(SD-11 §580 — 공격 대상 아님) · 엔진 불사(interior_combat.IMMORTAL) · 프롤로그 단위(볼트 평시)
    imm_src = open(os.path.join(G, "systems", "combat", "interior_combat.gd"), encoding="utf-8").read()
    m = re.search(r"const IMMORTAL := \[([^\]]*)\]", imm_src)
    immortal = set(re.findall(r'"([^"]+)"', m.group(1))) if m else set()

    def child(nid):
        n = npcs.get(nid, {})
        look = str(n.get("look", ""))
        if look.startswith("AN"):                                         # 동물은 아이가 아니다(StoryState.is_child와 같게)
            return False
        return 0 < int(n.get("age", 0) or 0) < 16 or look.startswith("K")
    killable = {nid for nid in placements if nid.startswith(("C-", "N-")) and not nid.startswith("N-PS")
                and nid not in immortal and not child(nid)}
    # 진행기 · 맵 발판이 직접 여는 장면(그 장면 주인에게 말을 걸어 연 것이 아니다 — 주인이 죽었어도 열릴 수 있다)
    forced = set()
    for p in glob.glob(os.path.join(G, "**", "*.gd"), recursive=True):
        if "/tests/" in p or "/bench/" in p:
            continue
        forced |= set(re.findall(r'"([A-Z][A-Za-z0-9_-]+)"', open(p, encoding="utf-8").read())) & set(idx)
    for p in glob.glob(os.path.join(G, "data", "maps", "*.json")):
        for tr in json.load(open(p, encoding="utf-8")).get("triggers", []):
            if tr.get("scene"):
                forced.add(tr["scene"])
    scene_npc = {}
    for sid in idx:
        p = os.path.join(G, "data", "dialogue", sid + ".json")
        if os.path.exists(p):
            scene_npc[sid] = json.load(open(p, encoding="utf-8")).get("npc", "")
    for un, u in sorted(units.items()):
        if un in PROLOGUE:
            continue
        for nid, roles in sorted(u["npcs"].items()):
            if nid not in killable:
                continue
            spoken = []
            for r in roles:
                kind, _, sid = r.partition(" ")
                if kind == "장면":
                    continue                                              # 그 인물에게 말을 걸어 여는 장면 = 엔진이 죽은 인물을 거른다
                if kind in ("말함", "연출") and canon(scene_npc.get(sid, "")) == nid and sid not in forced:
                    continue                                              # 자기 장면에서 자기가 말함
                if kind in ("말함", "연출") and nid in sguard.get(sid, set()):
                    continue                                              # 그 장면이 생사를 본다
                if kind == "진행기" and nid in u["pguards"]:
                    continue                                              # 진행기는 파일 단위(변수 인자는 허용 이유로)
                spoken.append(r)
            if not spoken:
                continue
            warn("X1", "%s %s" % (un, nid), "%s(%s)를 %s — 죽음 조건 없음" % (nid, names.get(nid, "?"), ", ".join(sorted(spoken))[:160]))
        for nid, sids in sorted(u["mentions"].items()):
            sids = {x for x in sids if nid not in sguard.get(x, set())}   # 장면마다: 그 장면이 생사를 보면 통과
            if un in PROLOGUE or nid not in killable or not sids:
                continue
            warn("X1", "%s %s 언급" % (un, nid), "%s(%s)의 이름이 대사에 — 장면 %s, 죽었을 때 판 없음" % (nid, names.get(nid, "?"), ", ".join(sorted(sids))[:160]))

    # X2 한 사람 두 곳
    def both_possible(c1, c2):
        return sat_expr("(%s) and (%s)" % (c1 or "True", c2 or "True"))

    def sat_expr(expr):
        calls = {}

        def sub_call(m):                                                  # 같은 글자의 호출(year() 등)은 같은 값
            t = re.sub(r"\s+", "", m.group(0))
            if t not in calls:
                calls[t] = "F%d" % len(calls)
            return calls[t]
        e = re.sub(r"\b[a-z_]+\([^()]*\)", sub_call, expr)
        e = e.replace("true", "True").replace("false", "False")
        vs = sorted(set(VAR_RE.findall(e)) | set(re.findall(r"\bF\d+\b", e)))
        dom = {}
        for v in vs:
            lits = {0, 1}
            for m in re.finditer(r"\b%s\s*(==|!=|>=|<=|>|<)\s*(-?\d+)" % re.escape(v), e):
                n = int(m.group(2))
                lits |= {n - 1, n, n + 1}
            if v == "GAME_HOUR":
                lits = set(range(24))
            if not v.startswith("AFF_") and not v.startswith("V_KARMA"):
                lits = {x for x in lits if x >= 0}                        # 단계 · 상태 · 날짜 변수는 0 아래로 가지 않는다(1-12d)
            dom[v] = sorted(lits)
        total = 1
        for v in vs:
            total *= len(dom[v])
        rng = random.Random(7)
        combos = itertools.product(*[dom[v] for v in vs]) if total <= 20000 else (tuple(rng.choice(dom[v]) for v in vs) for _ in range(20000))
        try:
            code = compile(e, "<cond>", "eval")
        except SyntaxError:
            return None
        for c in combos:
            env = dict(zip(vs, c))
            try:
                if eval(code, {"__builtins__": {}}, env):
                    return env
            except Exception:
                return None
        return False

    for nid, pls in sorted(placements.items()):
        if nid not in killable or len(pls) < 2:
            continue
        for (m1, c1), (m2, c2) in itertools.combinations(pls, 2):
            if m1 == m2 and c1 == c2:
                continue
            r = both_possible(c1, c2)
            if r:
                ex = ", ".join("%s=%s" % kv for kv in list(r.items())[:6])
                warn("X2", "%s %s %s" % (nid, m1, m2), "%s(%s): %s「%s」와 %s「%s」가 함께 참일 수 있다(예: %s)" % (
                    nid, names.get(nid, "?"), m1, c1 or "늘", m2, c2 or "늘", ex))

    # X3 사실
    for un, u in sorted(units.items()):
        for v in sorted(u["writes"]):
            o = owner_of(v)
            if o and o != un and not un.startswith("엔진") and not (un == "프롤로그" and o == "MQ-P4"):
                warn("X3", "%s %s" % (un, v), "%s가 %s 소유 변수 %s를 세운다 — 같은 사실인가(P1)" % (un, o, v))
    for v in sorted(reads_any - writes_any):
        o = owner_of(v)
        if v.endswith(("_STAGE", "_RESULT")):
            continue                                                      # 퀘스트 단계 · 결과는 엔진(quests.set_stage · result())
        if o and v in vdecl and not v.endswith(("_DAY", "_AT")):
            gd_set = False
            warn("X3", "읽기만 %s" % v, "%s(%s 소유)는 읽히지만 원고·진행기 어디서도 세우지 않는다 — 죽은 분기?" % (v, o))
    for v in sorted(writes_any - reads_any):
        o = owner_of(v)
        if o:
            warn("X3", "쓰기만 %s" % v, "%s(%s 소유)는 세우기만 하고 아무도 읽지 않는다 — 반응 없음(P12)?" % (v, o))

    # X4 물건
    gives = {}
    for un, u in units.items():
        for it, where in u["give"].items():
            gives.setdefault(it, set()).add(un)
    for it, us in sorted(gives.items()):
        n = int(it[2:])
        if 100 <= n < 400 and len(us) >= 2:
            warn("X4", it, "한 장뿐인 물건 %s를 %s가 준다 — 한 곳만 갖게 했나(P3 · A38)" % (it, ", ".join(sorted(us))))

    # X5 무대
    stage = {}
    for un, u in units.items():
        for m in u["maps"]:
            stage.setdefault(m, set()).add(un)
    for m, us in sorted(stage.items()):
        if len(us) >= 2:
            warn("X5", m, "손 맵 %s를 %s가 무대로 쓴다 — 서로의 진행 중 발동(P5 ⑥)" % (m, ", ".join(sorted(us))))

    # X6 받기만 하고 안 함
    quests = json.load(open(os.path.join(G, "data", "quests.json"), encoding="utf-8"))["quests"]
    for un, u in sorted(units.items()):
        if not (un.startswith("SQ-") or un.startswith("MQ-")):
            continue
        if u["act_max"] is not None and not u["expire"]:
            warn("X6", "%s 막" % un, "%s 장면이 V_ACT ≤ %d에서만 열리는데 진행기에 시한 · 마감 처리가 없다 — 막을 넘기면 반쯤 연 채 닫히나?" % (un, u["act_max"]))

    # X7 자리 비운 화자: 장면 주인이 아닌 말하는 인물이 다른 퀘스트 소유 변수 때문에 어느 맵에도 없을 수 있는데, 장면이 그 변수를 보지 않는다
    #   (동행 명부의 인물은 곁에 따라오므로 뺀다 · 프롤로그 볼트 평시는 뺀다 · 생사는 X1 몫이라 살아 있다고 본다)
    comp_src = open(os.path.join(G, "systems", "combat", "companions.gd"), encoding="utf-8").read()
    roster = set(re.findall(r'^\s*"((?:C|N|CR)-[A-Z0-9-]+)":\s*\{', comp_src, re.M))
    for sid, sc in sorted(scn.items()):
        if sc["unit"] in PROLOGUE:
            continue
        for w in sorted(sc["who"]):
            if w == sc["npc"] or w not in placements or w in roster:
                continue
            if any(str(t).startswith("진행기") for t in units.get(sc["unit"], new_unit())["npcs"].get(w, set())):
                continue                                                  # 그 단위의 진행기가 직접 세우는 인물(헬기 착륙 · 동행 · 대기실 칸) — 진행기가 자리를 맡는다
            pl = placements[w]
            if any(not c.strip() for _m, c in pl):
                continue                                                  # 늘 서 있는 자리가 하나라도 있다
            conds = [re.sub(r'(?:known_)?dead\("[^"]*"\)', "0", c) for _m, c in pl]
            other = set()
            for c in conds:
                for v in VAR_RE.findall(c):
                    o = owner_of(v)
                    if o and o != sc["unit"] and v not in sc["vars"]:
                        other.add(v)
            if not other:
                continue
            gone = sat_expr(" and ".join("not (%s)" % c for c in conds))
            if not gone:
                continue                                                  # 어느 값이든 어딘가에는 서 있다
            warn("X7", "%s %s" % (sid, w), "장면 %s에서 %s(%s)가 말하는데, %s 때문에 어느 맵에도 없을 수 있다(예: %s) — 장면은 %s를 보지 않는다" % (
                sid, w, names.get(w, "?"), ", ".join(sorted({owner_of(v) for v in other})), ", ".join("%s=%s" % kv for kv in list(gone.items())[:5]),
                ", ".join(sorted(other))[:80]))

    # X8 그날 밤 시각(SD-02 §3.3 정본): 2077-10-23 맥락 글에서 사건 낱말이 정본 시각보다 앞선 시각에 붙음
    for p in glob.glob(os.path.join(G, "data", "maps", "*.json")):
        m = json.load(open(p, encoding="utf-8"))
        for t in m.get("texts", []):
            times.append(("맵 " + m["id"], t.get("text", "")))
    CANON = [(r"섬광", 23 * 60 + 13), (r"공습|경보|운행 (?:중지|정지)|전 차량|대피(?:하|소로|령)|셔터를 내", 23 * 60 + 19),
             (r"분류 지침|집행 모드|차단벽", 23 * 60 + 21), (r"폭발|폭격|낙진", 23 * 60 + 27), (r"정전|시계가 멈|전기가 끊|EMP|전자기", 23 * 60 + 29)]
    CTX = re.compile(r"2077|그날|10\. ?23|10월 23일|막차|경보")
    TOK = re.compile(r"(\d{1,2}):(\d{2})|(\d{1,2})시\s*(?:(\d{1,2})분)?")
    tl = []
    for where, txt in times:
        if not txt or not CTX.search(txt):
            continue
        ms = list(TOK.finditer(txt))
        for i, mt in enumerate(ms):
            h = int(mt.group(1) or mt.group(3))
            mi = int(mt.group(2) or mt.group(4) or 0)
            if h > 24 or mi > 59 or h < 18:
                continue                                                  # 그날 밤 시각만(저녁 6시 뒤)
            seg = txt[mt.end(): ms[i + 1].start() if i + 1 < len(ms) else len(txt)]
            tl.append((h * 60 + mi, where, txt))
            for pat, at in CANON:
                if re.search(pat, seg) and h * 60 + mi < at:
                    warn("X8", "%s %02d:%02d" % (where, h, mi), "%s: '%02d:%02d' 뒤에 '%s' — 정본은 %02d:%02d(SD-02 §3.3). 원인보다 결과가 먼저?" % (
                        where, h, mi, re.search(pat, seg).group(0), at // 60, at % 60))
                    break

    newn = [w for w in warns if not w["allowed"]]
    # ---- 보고서
    out = ["# 퀘스트 교차 정합 표 (자동 — tools/pipeline/quest_cross.py)", "",
           "> SD-20 §10. 경고 %d · 허용 %d · **새 경고 %d**. 허용은 `tools/pipeline/quest_cross_allow.yaml`에 이유와 함께." % (
               len(warns), len(warns) - len(newn), len(newn)), ""]
    out.append("## 단위별 발자국")
    out.append("| 단위 | 인물(세움·말함) | 이름 언급 | 쓰는 변수 | 손 맵 무대 | 막 상한 | 시한 |")
    out.append("|---|---|---|---|---|---|---|")
    for un, u in sorted(units.items()):
        if not u["npcs"] and not u["writes"]:
            continue
        out.append("| %s | %s | %s | %d | %s | %s | %s |" % (un, " ".join(sorted(u["npcs"]))[:120], " ".join(sorted(u["mentions"]))[:80],
                                                       len(u["writes"]), " ".join(sorted(u["maps"]))[:60],
                                                       "" if u["act_max"] is None else u["act_max"], "○" if u["expire"] else ""))
    out.append("")
    out.append("## 인물이 걸친 단위(같은 사람을 둘 이상이 쓴다)")
    by_npc = {}
    for un, u in units.items():
        for nid in list(u["npcs"]) + list(u["mentions"]):
            by_npc.setdefault(nid, set()).add(un)
    for nid, us in sorted(by_npc.items()):
        if len(us) >= 2:
            out.append("- %s %s: %s" % (nid, names.get(nid, ""), ", ".join(sorted(us))))
    out.append("")
    out.append("## 그날 밤 시각 목록(2077-10-23 맥락 — X8 대조용, 정본 SD-02 §3.3)")
    seen_tl = set()
    for at, where, txt in sorted(tl):
        k = (at, where, txt)
        if k in seen_tl:
            continue
        seen_tl.add(k)
        out.append("- %02d:%02d · %s · %s" % (at // 60, at % 60, where, txt[:110]))
    out.append("")
    for kind in ["X1", "X2", "X3", "X4", "X5", "X6", "X7", "X8"]:
        ws = [w for w in warns if w["kind"] == kind]
        out.append("## %s (%d, 새 %d)" % (kind, len(ws), len([w for w in ws if not w["allowed"]])))
        for w in ws:
            out.append("- %s `%s` %s%s" % ("허용" if w["allowed"] else "**새**", w["key"], w["msg"], (" — " + w["allowed"]) if w["allowed"] else ""))
        out.append("")
    open(os.path.join(G, "data", "_cross_report.md"), "w", encoding="utf-8").write("\n".join(out))
    json.dump({"warn": len(warns), "new": [w["kind"] + " " + w["key"] for w in newn]},
              open(os.path.join(G, "data", "_cross_report.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    used = {"%s %s" % (w["kind"], w["key"]) for w in warns}
    stale = sorted(k for k in allow if k not in used)                 # 고쳐서 더는 경고가 아닌 허용 — 목록에서 지운다(이유가 낡는다)
    print("교차 정합: 경고 %d · 허용 %d · 새 %d (game/data/_cross_report.md)" % (len(warns), len(warns) - len(newn), len(newn)))
    if stale:
        print("  쓰이지 않는 허용 %d: %s" % (len(stale), ", ".join(stale)))
    for k in ["X1", "X2", "X3", "X4", "X5", "X6", "X7", "X8"]:
        print("  %s %d" % (k, len([w for w in newn if w["kind"] == k])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
