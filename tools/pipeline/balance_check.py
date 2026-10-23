"""밸런스 검사(SD-25 · 사용자 지시 2026-10-23 '모든 영역의 밸런스 — 재미는 높이고 스트레스는 줄인다').
정본 목표(SD-10 · 11 · 13 · 14 · 15 · 05)를 자료 · 원고 · 코드에서 계산으로 대 본다. 판정은 후보 — 조율은 `balance-auditor` 에이전트와 사람이 한다.
결과: game/data/_balance_report.md(사람용) · _balance_report.json. 허용 목록: tools/pipeline/balance_allow.yaml('ID|대상': 이유).
판정: 목표 안 = 통과 · 목표에서 25% 안 벗어남 = 주의 · 그 밖 = 실패. 새 실패(허용 목록 밖) 수를 마지막 줄에 찍는다."""
import glob
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "game", "data")
OUT_MD = os.path.join(DATA, "_balance_report.md")
OUT_JSON = os.path.join(DATA, "_balance_report.json")
ALLOW = os.path.join(os.path.dirname(__file__), "balance_allow.yaml")

COND_R = {"new": 1.0, "good": 0.87, "worn": 0.79, "poor": 0.70}       # combat_rules.gd COND_DMG_RANGED
COND_M = {"new": 1.0, "good": 0.82, "worn": 0.69, "poor": 0.57}
TTK = {"약": (1, 2), "중": (3, 6), "강": (7, 15), "전설": (20, 35), "유일": (45, 120)}   # SD-11 §10.3 · SD-14 §2.4
## 그 레벨대 표준 무기(SD-11 §10.3 '해당 레벨대 표준 무기' — 사용자 결정 2026-10-23: 그 레벨대에 흔히 쥐는 반자동 대표).
## 연사 무기는 빨리 죽이는 대신 탄을 쓰는 맞바꿈(SD-11 §10.1-3)이라 '중 2초 이상'으로 따로 본다(명중 0.6 — 반동 +0.5°/발).
## Lv7~12의 돌격소총(W-018)은 전리품 풀 3(Lv13~)이라 1막 표준이 아니다
STD_WEAPON = [(6, ["W-002"]), (12, ["W-004"]), (20, ["W-008", "W-022"]), (99, ["W-023", "W-024"])]
AUTO_WEAPON = [(12, "W-017"), (20, "W-018"), (99, "W-019")]
HIT_AUTO = 0.6
TIER_FIX = {"CR-082": ("전설", "원작 압축 HP 750 · 군락 여왕(SD-14 §2.4 압축 규칙) — 조율사"),
            "CR-405": ("강", "파워 아머 병종(SD-11 §10.3 예 '파워 아머 분대장' = 강)")}
BOSS_REF = {"CR-513": 12}                                               # 레벨 비례 스토리 보스: XP 기준 레벨(SD-14 §10.2 '65(Lv12 기준)')
## 위협 1~2 권역 필드 보스: 몸만이 아니라 교전 전체(호위 무리 · 부화 · 도주 문턱)로 잰다 — 목표 35~60초(SD-11 §10.3 — 사용자 결정 2026-10-23)
BOSS_FIGHT = {"CR-500": {"adds": [("CR-104", 4), ("CR-105", 3)], "flee": 0.3, "why": "무리 6~8 · HP 30% 도주(SD-14 §10.2 외눈)"},
              "CR-501": {"adds": [("CR-002", 6), ("CR-001", 3)], "flee": 0.0, "why": "15초마다 큰바퀴 셋 부화 · 페이즈 3 잔바퀴 떼 셋(SD-14 배수구 어미)"}}
ENGAGE_K = 1.5                                                          # 교전 전체: 움직임 · 재장전 · 다시 겨눔(조율사 추정 '지속 30초 → 움직임까지 40~50초')
PART_AVG = (12 * 2.0 + 88 * 1.0) / 100.0                               # 사람 부위 가중(머리 12 × 2 · 나머지 × 1 — combat_rules PART_MULT · HUMANOID_WEIGHTS)
CRIT_AVG = 1.05                                                         # 행운 5 × 무기 배수 1 → 치명 5%(치명 피해 ≈ 기본 피해)
## 그 레벨대 표준 방어구 DR(SD-13 몸통 표에서 그 구간에 흔히 구하는 것 — 1막 작업복 4 · 2~3막 약탈자 아머 18 · 3~5막 강화 가죽 28 · 그 뒤 전투 아머 32)
STD_DR = [(6, 4), (12, 18), (20, 28), (99, 32)]
HIT_PC = 0.8                                                            # 주인공 명중(스킬 50 · 표준 거리)
HIT_EN = 0.55                                                           # 적 명중(SD-11 §10.3 검증 예)
EN_SKILL = 45.0                                                         # Enemy.skill 기본(systems/ai/enemy.gd)
BITE_CD = 1.1                                                           # Enemy._bite 주기
CLAW_RATE = 0.8                                                         # 구울 맨손(_enemy_weapon)
def _enemy_arms():
    """게임의 ENEMY_ARMS(systems/combat/interior_combat.gd)를 그대로 읽는다 — 사본을 두지 않는다"""
    src = open(os.path.join(ROOT, "game", "systems", "combat", "interior_combat.gd"), encoding="utf-8").read()
    body = src[src.index("const ENEMY_ARMS := {"):]
    body = body[:body.index("\n}")]
    out = {}
    for m in re.finditer(r'"(CR-\d+)": \[(.*?)\],\s*(?:#|\n)', body):
        out[m.group(1)] = re.findall(r'"(W-\d+)"', m.group(2))
    return out


ENEMY_ARMS = _enemy_arms()
SWARMY = {"CR-095", "CR-200", "CR-201", "CR-204", "CR-205", "CR-206", "CR-001", "CR-002"}   # enemy.gd SWARMY


def _hand_arms():
    src = open(os.path.join(ROOT, "game", "systems", "combat", "interior_combat.gd"), encoding="utf-8").read()
    m = re.search(r"const HAND_ARMS := \{(.*?)\}\n", src)
    return {k: re.findall(r'"(W-\d+)"', v) for k, v in re.findall(r'"(CR-\d+)": \[([^\]]*)\]', m.group(1))} if m else {}


HAND_ARMS = _hand_arms()


def _boss_hp():
    src = open(os.path.join(ROOT, "game", "systems", "ai", "enemy.gd"), encoding="utf-8").read()
    m = re.search(r"const BOSS_HP := \{(.*?)\}", src)
    return {k: (int(a), int(b)) for k, a, b in re.findall(r'"(CR-\d+)": \[(\d+), (\d+)\]', m.group(1))} if m else {}


BOSS_HP = _boss_hp()
CLAW = {"CR-200", "CR-201", "CR-202", "CR-204", "CR-205", "CR-206"}
BITERS = {"CR-104", "CR-095", "CR-107", "CR-106", "CR-108", "CR-105", "CR-500", "CR-136", "CR-097", "CR-121", "CR-096", "CR-004", "CR-080",
          "CR-081", "CR-082", "CR-130", "CR-501", "CR-001", "CR-002"}


def load(name):
    p = os.path.join(DATA, name)
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}


def items_db():
    db = {}
    for f in glob.glob(os.path.join(DATA, "items_*.json")):
        db.update(json.load(open(f, encoding="utf-8")))
    return db


def judge(v, lo, hi):
    if lo <= v <= hi:
        return "통과"
    span = max(hi - lo, abs(hi) * 0.0 + 1e-9)
    edge = lo - v if v < lo else v - hi
    ref = (lo if v < lo else hi) or 1
    return "주의" if edge <= abs(ref) * 0.25 else "실패"


def allow_list():
    out = {}
    if os.path.exists(ALLOW):
        for l in open(ALLOW, encoding="utf-8"):
            m = re.match(r'^"([^"]+)":\s*(.*)$', l.strip())
            if m:
                out[m.group(1)] = m.group(2)
    return out


R = []                                                                    # 결과 줄


def add(bid, area, target_name, value, target, status, src, note=""):
    R.append({"id": bid, "area": area, "item": target_name, "value": value, "target": target, "status": status, "src": src, "note": note})


# ---------------------------------------------------------------- 무기 · 적 계산
def w_dps(w, skill=50.0, cond="new", dr=0.0, str_=5):
    if not w:
        return 0.0
    kind = w.get("kind", "ranged")
    ck = (COND_R if kind == "ranged" else COND_M)[cond]
    bonus = 0.0
    if kind == "melee":
        bonus = -(-str_ // 2)
    dmg = float(w["dmg"]) * (100.0 + skill) / 200.0 * ck + bonus
    dmg *= max(0.0, 1.0 - min(dr, 85.0) / 100.0)
    return dmg * float(w.get("rate", 1.0))


def w_hit(w, skill=50.0, cond="new", dr=0.0, str_=5):
    kind = w.get("kind", "ranged")
    ck = (COND_R if kind == "ranged" else COND_M)[cond]
    bonus = -(-str_ // 2) if kind == "melee" else 0.0
    return (float(w["dmg"]) * (100.0 + skill) / 200.0 * ck + bonus) * max(0.0, 1.0 - min(dr, 85.0) / 100.0)


def band(table, lv):
    for cap, v in table:
        if lv <= cap:
            return v
    return table[-1][1]


def tier_of(e):
    t = str(e.get("tier") or "")
    if e["id"] in TIER_FIX:
        return TIER_FIX[e["id"]][0]
    if e["id"] in BOSS_FIGHT:
        return "필드 보스"
    if e["id"].startswith("CR-5"):
        return "강" if e.get("weapon_main") or not e.get("attack") else "유일"   # 이름 있는 사람 우두머리는 '강', 유일 크리처만 '유일'(SD-11 예: 거인 변종 · 방어 체계)
    for k in ("전설", "강", "중", "약"):
        if t.startswith(k):
            return k
    r = str(e.get("rank") or "")
    lv = int(e.get("level") or 1)
    if r.isdigit():                                                     # 사람: SD-11 §10.3 예(약탈자 랭크 1 = 약 · 계엄군 병사 = 중)
        rk = int(r)
        if rk <= 1:
            return "약" if lv <= 4 else "중"
        return "중" if rk <= 3 else "강"                                 # 정본 예(SD-11 §10.3): 탈론 랭크 3 = 중
    return ""


def check_combat(weapons, enemies):
    for eid, e in sorted(enemies.items()):
        tier = tier_of(e)
        if not tier or not isinstance(e.get("hp"), (int, float)) or tier == "":
            continue
        lv = int(e.get("level") or 1)
        hp = float(e["hp"])
        dr = float(e.get("dr") or 0)
        if eid in BOSS_REF and eid in BOSS_HP:                          # enemy.gd BOSS_HP — HP = 기본 + Lv × 계수
            lv = BOSS_REF[eid]
            hp = BOSS_HP[eid][0] + lv * BOSS_HP[eid][1]
        best = max(band(STD_WEAPON, lv), key=lambda wid: w_dps(weapons.get(wid, {}), 50.0, "new", dr))
        dps = w_dps(weapons[best], 50.0, "new", dr) * HIT_PC * PART_AVG * CRIT_AVG
        ttk = hp / dps if dps > 0 else 999
        if tier == "필드 보스":
            bf = BOSS_FIGHT[eid]
            pool = hp * (1 - bf["flee"]) + sum(float(enemies[a]["hp"]) * n for a, n in bf["adds"] if a in enemies)
            eng = pool / dps * ENGAGE_K
            add("B3", "적 처치 시간", "%s %s(필드 보스 · Lv%d — 교전 전체: 몸 %d × %.1f + 호위 · 부화)" % (eid, e["name"], lv, hp, 1 - bf["flee"]), round(eng, 1), "35~60초",
                judge(eng, 35, 60), "SD-11 §10.3 필드 보스(사용자 결정 2026-10-23)", "표준 무기 %s · %s" % (best, bf["why"]))
        else:
            lo, hi = TTK[tier]
            add("B3", "적 처치 시간", "%s %s(%s · Lv%d · HP %d · DR %d)" % (eid, e["name"], tier, lv, hp, dr), round(ttk, 1), "%d~%d초" % (lo, hi),
                judge(ttk, lo, hi), "SD-11 §10.3 · SD-14 §2.4", "표준 무기 %s %s" % (best, weapons[best]["name"]) + (" · " + TIER_FIX[eid][1] if eid in TIER_FIX else ""))
        if tier == "중" and lv >= 7:
            aw = weapons.get(band(AUTO_WEAPON, lv), {})
            if aw:
                at = hp / (w_dps(aw, 50.0, "new", dr) * HIT_AUTO * PART_AVG * CRIT_AVG)
                add("B3", "적 처치 시간(연사)", "%s %s(중 · Lv%d)" % (eid, e["name"], lv), round(at, 1), "2초 이상",
                    "통과" if at >= 2 else ("주의" if at >= 1.5 else "실패"), "SD-11 §10.1-3 (탄과 맞바꿈)", "%s %s · 명중 0.6" % (aw["id"] if "id" in aw else band(AUTO_WEAPON, lv), aw["name"]))
        # 생존(B4) · 한 방(B5): 적이 주인공(같은 레벨 · 그 구간 방어구)에게
        php = 200.0 + (lv - 1) * 10.0
        pdr = float(band(STD_DR, lv))
        melee_tok = 3                                                   # 사수 토큰 3(SD-11 §7.4)
        if eid in BITERS or str(e.get("attack", "")).startswith("물기"):
            ma = re.match(r"^\S+ (\d+)", str(e.get("attack", "")))           # 게임과 같은 읽기(enemy.gd: '물기 18' · '집게 14'의 둘째 낱말)
            bite = float(ma.group(1)) if ma else 8.0
            melee_tok = 4 if eid in SWARMY else 2                         # 근접 토큰(무리 2 · 떼 4 — interior_combat 1.5초마다)
            raw = bite * max(0.0, 1 - pdr / 100.0)                      # 물기도 DR을 거친다(enemy.gd _bite — 2026-10-23 고침)
            edps = raw / (BITE_CD + max(0.0, bite - 15.0) * 0.05)        # enemy.gd _bite: 센 물기일수록 예비 동작이 길다
            hit1 = raw
            how = "물기 %g/%.1f초" % (bite, BITE_CD)
        elif eid in CLAW:
            claw = float(str(e.get("attack", "근접 5")).split(" ")[1]) if " " in str(e.get("attack", "")) else 5.0
            hit1 = claw * (100 + EN_SKILL) / 200.0 * max(0.0, 1 - pdr / 100.0)
            edps = hit1 * CLAW_RATE
            how = "맨손 %g" % claw
            melee_tok = 4 if eid in SWARMY else 2
        else:
            arms = ENEMY_ARMS.get(eid) or HAND_ARMS.get(eid) or (["W-008"] if eid == "CR-305" else ["W-002"])
            wid = max(arms, key=lambda a: w_dps(weapons.get(a, {}), EN_SKILL, "worn", pdr))
            w = weapons.get(wid, {})
            if not w:
                continue
            r = float(w.get("rate", 1.0))
            if r >= 5.0 and wid != "W-002":                             # 연사: 0.6~1.2초 점사 · 0.5~1.0초 쉼(enemy.gd _shoot)
                eff = r * 0.9 / 1.65
            elif w.get("kind", "ranged") == "ranged":                      # 반자동: 최대의 60%로 세 발, 그 뒤 1~1.6초 다시 겨눔
                eff = 3.0 / (3.0 / (0.6 * r) + 1.3)
            else:
                eff = r
            edps = w_hit(w, EN_SKILL, "worn", pdr) * eff * HIT_EN * PART_AVG
            how = "%s %s(실효 %.1f발/초)" % (wid, w["name"], eff)
            hit1 = w_hit(w, EN_SKILL, "worn", pdr)
            if eid in HAND_ARMS and len(HAND_ARMS[eid]) == 2 and eid not in ENEMY_ARMS:   # 손 맵: 셋에 연사 하나 · 둘은 반자동(interior_combat _hand_arm)
                w2 = weapons.get(HAND_ARMS[eid][1], {})
                r2 = float(w2.get("rate", 1.0))
                eff2 = 3.0 / (3.0 / (0.6 * r2) + 1.3) if w2.get("kind", "ranged") == "ranged" else r2
                edps = (edps + 2 * w_hit(w2, EN_SKILL, "worn", pdr) * eff2 * HIT_EN * PART_AVG) / 3.0
                how += " 하나 + %s 둘" % w2.get("name", "")
        surv = php / edps if edps > 0 else 999
        if tier == "약":
            add("B4", "주인공 생존", "%s %s 1명 ↔ Lv%d HP %d DR %d" % (eid, e["name"], lv, php, pdr), round(surv, 1), "25초 이상",
                "통과" if surv >= 25 else ("주의" if surv >= 25 * 0.75 else "실패"), "SD-11 §10.3", how)
        if tier == "중":
            s3 = surv / min(3, melee_tok)
            add("B4", "주인공 생존", "%s %s 3명 ↔ Lv%d HP %d DR %d" % (eid, e["name"], lv, php, pdr), round(s3, 1), "8~15초",
                judge(s3, 8, 15), "SD-11 §10.3", how)
        if lv <= 9:
            frac = hit1 / 200.0
            add("B5", "한 방 위험", "%s %s 한 번 공격 ↔ Lv1 HP 200" % (eid, e["name"]), round(frac * 100), "35% 이하",
                "통과" if frac <= 0.35 else ("주의" if frac <= 0.44 else "실패"), "SD-25 B5(스트레스)", how)


# ---------------------------------------------------------------- 퀘스트 보상(원고 · 진행기)
QID = re.compile(r'"((?:MQ|SQ|FQ|UQ)-[A-Z0-9]+(?:-[0-9]+)?)"')
VARQ = re.compile(r"\b(MQ|UQ)(\d{2,3})_|\b(SQ)_(S\d\d)_|\b(FQ)_([A-Z]{2})(\d\d)_")


def quest_of_line(s):
    m = re.search(r'quest\("([A-Z]+-[A-Z0-9-]+)"', s) or QID.search(s)
    if m:
        return m.group(1)
    v = VARQ.search(s)
    if v:
        if v.group(1):
            return "%s-%s" % (v.group(1), v.group(2))
        if v.group(3):
            return "SQ-%s" % v.group(4)
        return "FQ-%s-%s" % (v.group(6), v.group(7))
    return ""


def script_rewards():
    """원고: 장면마다 가장 큰 보상 하나(장면은 한 갈래로 끝난다고 보고) — 퀘스트(장면 머리 · 줄의 퀘스트 · 변수 접두)로 묶는다"""
    out = {}
    for f in glob.glob(os.path.join(ROOT, "script", "**", "*.txt"), recursive=True):
        rel = os.path.relpath(f, ROOT)
        act = 0 if "/prologue/" in f else (1 if "/act1/" in f or "/encounters/" in f else 9)
        scene = ""
        sq = ""
        best = {}
        def flush():
            for k, v in best.items():
                q, kind = k
                d = out.setdefault(q, {"xp": 0, "caps": 0, "act": act, "src": set(), "xp_all": [], "caps_all": []})
                d[kind] = max(d[kind], v)                                 # 결말 갈래마다 다른 보상 — 가장 큰 완료 보상 하나
                d[kind + "_all"].append(v)
                d["src"].add(rel)
        for l in open(f, encoding="utf-8"):
            if l.startswith("@scene"):
                flush()
                best = {}
                scene = l.split()[1]
                m = re.match(r"((?:MQ|SQ|FQ|UQ)-[A-Z0-9]+(?:-\d+)?)", scene.replace("MQ-P", "MQ-P"))
                sq = m.group(1) if m else ""
                continue
            for kind in ("xp", "caps"):
                for m in re.finditer(r"\b%s\((\d+)\)" % kind, l):
                    q = quest_of_line(l) or sq or os.path.basename(f)[:-4]
                    k = (q, kind)
                    best[k] = max(best.get(k, 0), int(m.group(1)))
        flush()
    return out


def code_rewards(out):
    """진행기: 함수마다 가장 큰 보상 하나 — 가까운 위 40줄의 퀘스트 ID · 파일 상수 Q/QID로 묶는다"""
    for f in glob.glob(os.path.join(ROOT, "game", "scenes", "story", "*.gd")):
        lines = open(f, encoding="utf-8").read().split("\n")
        fileq = ""
        consts = {}
        for l in lines:
            m = re.match(r'^const (?:Q|QID) := "([A-Z0-9-]+)"', l)
            if m:
                fileq = m.group(1)
            m2 = re.match(r"^const ([A-Z_0-9]+) := (\d+)\b", l)
            if m2:
                consts[m2.group(1)] = int(m2.group(2))
            m3 = re.match(r"^const ([A-Z_0-9]+) := \{([^}]*)\}", l)       # 단계 · 등급별 표({1: 60, 2: 90}) — 가장 큰 값
            if m3:
                vals = [int(x) for x in re.findall(r":\s*(\d+)", m3.group(2))]
                if vals:
                    consts[m3.group(1)] = max(vals)
        best = {}
        def flush():
            for k, v in best.items():
                q, kind = k
                d = out.setdefault(q, {"xp": 0, "caps": 0, "act": 1, "src": set(), "xp_all": [], "caps_all": []})
                d[kind] = max(d[kind], v)
                d[kind + "_all"].append(v)
                d["src"].add(os.path.relpath(f, ROOT))
        for i, l in enumerate(lines):
            if l.startswith("func "):
                flush()
                best = {}
            for kind in ("xp", "caps"):
                for m in re.finditer(r'call_fn\("%s", \[([^\]]+)\]' % kind, l):   # 식이면(갈래 'A if 조건 else B') 그 안의 가장 큰 수 · 파일 상수(XP)는 풀어서
                    q = ""
                    for j in range(i, max(-1, i - 40), -1):
                        q = quest_of_line(lines[j])
                        if q or lines[j].startswith("func "):
                            break
                    q = q or fileq or os.path.basename(f)[:-3]
                    k = (q, kind)
                    toks = re.findall(r"\b([A-Z][A-Z_0-9]+|\d+)\b", m.group(1))
                    val = max([consts.get(g, 0) if not g.isdigit() else int(g) for g in toks] or [0])
                    best[k] = max(best.get(k, 0), val)
        flush()
    return out


## 보상이 아니라 '흐름'인 캡(판매 · 환불 · 맡긴 돈) — 보상 합에서 빼고, 보상 상한 검사에서도 뺀다(원고를 읽고 확인한 것만)
FLOWS = {"MQ-105": "보증금 환불(앞서 낸 500)", "SQ-S09": "아내가 맡긴 몸값(장부 빚 400을 갚을 돈)", "KS": "UQ-69 금형 판 값(물건 값)",
         "ga": "여분 볼트 작업복 판 값(한 번)", "UQ-67": "노심을 새벽인력 매점에 판 값(보상 대신 고르는 갈래)",
         "FQ-JH-03": "약 상자를 판 값 300(배달 보상 150과 갈래 — 보상은 150)", "UQ-71": "노심 판 값(보상 대신 고르는 갈래)", "UQ-69": "금형을 새벽인력에 판 400 — SD-15 §9.1 구간 Ⅰ 300 상한의 정본 예외(사용자 결정 2026-10-23)"}


def canon_xp():
    """정본 표의 퀘스트 XP · 위협도: SD-04a~c 사이드 표(ID · 위협 · XP 열) · SD-05 비표시 표(끝 열 'n XP') · SD-04d 세력"""
    out = {}
    for f in glob.glob(os.path.join(ROOT, "docs", "seoul-fallout", "04*.md")) + [os.path.join(ROOT, "docs", "seoul-fallout", "05_misc-quests-encounters.md")]:
        hdr = None
        for l in open(f, encoding="utf-8"):
            if not l.startswith("|"):
                hdr = None
                continue
            cells = [c.strip() for c in l.strip().strip("|").split("|")]
            if cells and cells[0] == "ID":
                hdr = cells
                continue
            m = re.match(r"^((?:SQ|UQ|FQ)-[A-Z0-9]+(?:-\d+)?)$", cells[0]) if cells else None
            if not m or m.group(1) in out:
                continue
            xp = None
            thr = None
            if hdr and "XP" in hdr and len(cells) == len(hdr):
                mm = re.match(r"^(\d+)", cells[hdr.index("XP")])
                xp = int(mm.group(1)) if mm else None
                if "위협" in hdr:
                    tt = re.findall(r"\d", cells[hdr.index("위협")])
                    thr = (int(tt[0]), int(tt[-1])) if tt else None
            else:
                mm = re.search(r"(\d+) XP\s*$", cells[-1])
                xp = int(mm.group(1)) if mm else None
            if xp:
                out[m.group(1)] = {"xp": xp, "thr": thr}
    return out


THR_XP = {1: (150, 250), 2: (250, 350), 3: (350, 500), 4: (500, 650), 5: (650, 800)}   # SD-10 §4.4 위협도별 사이드 XP


def cat_of(q):
    if q.startswith("MQ-P"):
        return "프롤로그"
    for p, c in (("MQ", "메인"), ("SQ", "사이드"), ("FQ", "세력"), ("UQ", "비표시")):
        if q.startswith(p + "-"):
            return c
    return "기타"


def xp_level(xp):
    lv = 1
    while lv < 35 and xp >= lv * (50 + 75 * (lv + 1)):
        lv += 1
    return lv


def check_rewards(places):
    rw = code_rewards(script_rewards())
    canon = canon_xp()
    # B2 퀘스트 크기 — 정본 표(SD-04 · 05)에 그 퀘스트 XP가 있으면 그 값과(한 번에 주든 단계마다 나눠 주든), 없으면 SD-10 §4.4 범위와
    for q, d in sorted(rw.items()):
        c = cat_of(q)
        srcs = " · ".join(sorted(d["src"]))[:90]
        cq = canon.get(q)
        if cq and c in ("사이드", "세력", "비표시"):
            tot = sum(d["xp_all"])
            ok = d["xp"] >= cq["xp"] * 0.75 or tot >= cq["xp"] * 0.75          # 마지막 한 번 또는 단계 합이 정본에 닿는다
            over = d["xp"] > cq["xp"] * 1.25 and tot > cq["xp"] * 1.25 and min(d["xp"], tot) > cq["xp"] * 1.25
            v = "통과" if ok and not over else ("주의" if (d["xp"] >= cq["xp"] * 0.5 or tot >= cq["xp"] * 0.5) else "실패")
            rng = THR_XP.get(cq["thr"][0], (0, 0))[0] if cq.get("thr") else 0
            note = "정본 %d XP(위협 %s) · 한 번 최대 %d · 갈래 합 %d" % (cq["xp"], "~".join(str(x) for x in cq["thr"]) if cq.get("thr") else "–", d["xp"], tot)
            add("B2", "퀘스트 XP", q, d["xp"], "정본 %d" % cq["xp"], v, "SD-04 · 05 퀘스트 표", note + " · " + srcs)
            if cq.get("thr") and c == "사이드":
                lo = THR_XP[cq["thr"][0]][0]
                hi = THR_XP[cq["thr"][1]][1]
                add("B2", "정본 XP ↔ 위협도", q, cq["xp"], "%d~%d" % (lo, hi), judge(cq["xp"], lo, hi), "SD-10 §4.4 · SD-04", "정본 표끼리")
        elif c == "사이드":
            lo, hi = 150, 350                                           # 1막 권역 위협도 1~2(SD-10 §4.4)
            add("B2", "퀘스트 XP", q, d["xp"], "%d~%d" % (lo, hi), judge(d["xp"], lo, hi), "SD-10 §4.4", srcs)
        elif c == "세력":
            add("B2", "퀘스트 XP", q, d["xp"], "200~600", judge(d["xp"], 200, 600), "SD-10 §4.4", srcs)
        elif c == "비표시":
            add("B2", "퀘스트 XP", q, d["xp"], "50~200", judge(d["xp"], 50, 200), "SD-10 §4.4", srcs)
        if d["caps"] > 0 and c in ("사이드", "세력", "비표시", "메인", "프롤로그"):
            if q in FLOWS:
                add("B2", "퀘스트 캡(구간 Ⅰ)", q, d["caps"], "300 이하", "통과", "SD-15 §9.1", "흐름 — " + FLOWS[q])
            else:
                add("B2", "퀘스트 캡(구간 Ⅰ)", q, d["caps"], "300 이하", "통과" if d["caps"] <= 300 else ("주의" if d["caps"] <= 375 else "실패"),
                    "SD-15 §9.1", srcs)
    # B1 성장 — 프롤로그 끝 Lv3, 1막 끝 Lv7('필수 + 사이드 · 탐험 절반'). 메인 · 프롤로그는 단계마다 쌓이는 보상이라 합, 1막 갈래(103 · 104 · 105)는 하나만
    seq = lambda d: sum(d["xp_all"])
    pro = sum(seq(d) for q, d in rw.items() if cat_of(q) == "프롤로그")
    add("B1", "성장 곡선", "프롤로그 끝 레벨(메인 XP %d)" % pro, xp_level(pro), "2", judge(xp_level(pro), 2, 2), "SD-10 §4.4 예산표(사용자 결정 2026-10-23 — 원래 3)")
    paths = [seq(rw[q]) for q in ("MQ-103", "MQ-104", "MQ-105") if q in rw]
    main1 = sum(seq(d) for q, d in rw.items() if cat_of(q) == "메인" and q not in ("MQ-103", "MQ-104", "MQ-105")) + (max(paths) if paths else 0)
    other = sum(d["xp"] for q, d in rw.items() if cat_of(q) in ("사이드", "세력", "비표시", "기타") and d["act"] <= 1)
    disc = sum(int(p.get("xp", 25 if p.get("grade") in ("S", "A") else 10)) for p in places.values()
               if p.get("region") in ("R01", "R02") and p.get("marker", True) and not p.get("hidden", False))
    tot = pro + main1 + 0.5 * other + 0.5 * disc
    add("B1", "성장 곡선", "1막 끝 레벨(프롤로그 %d + 1막 메인 %d + 사이드류 절반 %d + 발견 절반 %d)" % (pro, main1, other // 2, disc // 2),
        xp_level(int(tot)), "8", judge(xp_level(int(tot)), 7.5, 8.5), "SD-10 §4.4 예산표(사용자 결정 2026-10-23 — 원래 7)")
    full = pro + main1 + other + disc
    add("B1", "성장 곡선", "1막을 다 한 사람(XP %d — 처치 XP 뺌)" % full, xp_level(full), "12 이하(넘치지 않게 — 사용자 결정 2026-10-23)",
        judge(xp_level(full), 8, 12), "SD-10 §4.4 · SD-11 §10.4")
    main_caps = sum(d["caps"] for q, d in rw.items() if d["act"] <= 1 and q not in FLOWS and cat_of(q) in ("메인", "프롤로그"))
    side_caps = sum(d["caps"] for q, d in rw.items() if d["act"] <= 1 and q not in FLOWS and cat_of(q) not in ("메인", "프롤로그"))
    caps1 = main_caps + side_caps // 2
    add("B6", "경제 흐름", "프롤로그 ~ 1막 퀘스트 캡 보상(메인 %d + 사이드류 절반 %d — 막 끝 목표 레벨과 같은 '절반' 기준 · 판매 · 환불 흐름 뺌)" % (main_caps, side_caps // 2),
        caps1, "1,125 이하(구간 Ⅰ 누적 상한 2,500의 45% — 퀘스트 몫 30%(§9.1 구간 Ⅲ 구성)에 초반 루팅이 적은 만큼 여유)",
        "통과" if caps1 <= 1125 else ("주의" if caps1 <= 1400 else "실패"), "SD-15 §9.1 수입 구성")
    add("B6", "경제 흐름", "1막 퀘스트를 다 했을 때 퀘스트 캡(%d)" % (main_caps + side_caps), main_caps + side_caps, "2,500 이하(구간 Ⅰ 누적 상한 — 다 해도 넘치지 않게)",
        "통과" if main_caps + side_caps <= 2500 else "주의", "SD-15 §9.1")
    return rw


# ---------------------------------------------------------------- 경제 · 소모 · 상점
def price_of(value, buying, barter, f=(1.0, 1.0), k=(1.0, 1.0), g=1.0):
    if value <= 0:
        return 0 if buying else -1
    sk = max(0.0, min(100.0, barter)) / 100.0
    if buying:
        b = 1.55 - 0.45 * sk
        return max(round(value * b * f[0] * k[0] * g), round(value * g))
    s = 0.45 + 0.45 * sk
    return min(max(round(value * s * f[1] * k[1] * g), 1), max(1, int(value * g * 0.95)))


def check_economy(db, weapons, loot, enemies):
    # 장바구니(구간 Ⅰ에 살 수 있어야 하는 것 — 물물교환 30 · 중립)
    basket = 5 * price_of(db["I-001"]["value"], True, 30) + price_of(db["M-062"]["value"], True, 30) + 10 * price_of(db["I-057"]["value"], True, 30)
    add("B6", "경제 흐름", "구간 Ⅰ 필수 장바구니(스팀팩 5 · 위조 등록증 · 정화수 10, 물물교환 30)", basket, "1,500 이하(구간 Ⅰ 수입 하한)",
        "통과" if basket <= 1500 else "실패", "SD-15 §9.1")
    # 차익(B9): 가장 비싸게 파는 값 ≤ 가장 싸게 사는 값
    worst = 0
    for iid, it in db.items():
        v = int(it.get("value", 0) or 0)
        if v <= 0:
            continue
        sell = price_of(v, False, 100, (1.0, 1.15), (1.0, 1.2 * 1.5))
        buy = price_of(v, True, 100, (0.75, 1.0), (0.85, 1.0))       # 동맹 · 단골 3단계
        worst = max(worst, sell - buy)
    add("B9", "상점 · 차익", "같은 물건 되팔기 최대 차익(물물교환 100 · 동맹 · 결 · 요즘 찾는 것 · 단골 3)", worst, "0 이하", "통과" if worst <= 0 else "실패", "SD-15 §3.7")
    # 회복(B8)
    heal = 30.0 * (1 + 15 / 50.0)
    add("B8", "회복 수급", "스팀팩 하나(의학 15) ↔ Lv1 HP 200", round(heal / 200 * 100), "15~25%", judge(heal / 200 * 100, 15, 25), "SD-13 §7 · SD-25 B8")
    heal_hi = 30.0 * (1 + 60 / 50.0)
    add("B8", "회복 수급", "스팀팩 하나(의학 60) ↔ Lv10 HP 290", round(heal_hi / 290 * 100), "15~30%", judge(heal_hi / 290 * 100, 15, 30), "SD-25 B8")
    # 싸움 손익(B7): '약' 사람 적을 표준 권총으로 — 쓴 탄값 ↔ 드롭 기대값
    drops = loot.get("drops", {})
    for eid in ("CR-420", "CR-200", "CR-104"):
        e = enemies.get(eid)
        if not e:
            continue
        w = weapons["W-002"]
        per = w_hit(w, 50.0, "new", float(e.get("dr") or 0))
        shots = (float(e["hp"]) / per) / HIT_PC
        ammo_cost = shots * price_of(db.get("10mm 탄", {"value": 1})["value"], True, 30)
        gain = 0.0
        back = 0.0
        for r in drops.get(eid, []):
            iid, p, a, b = r[0], float(r[1]), int(r[2]), int(r[3])
            avg = p * (a + b) / 2.0
            if iid == "M-001":
                gain += avg
            elif iid == "10mm 탄":
                back += avg
            elif iid in db:
                gain += avg * max(1, price_of(int(db[iid].get("value", 0) or 0), False, 30))
            elif iid.startswith("@"):
                gain += avg * 2
        net = gain + back * 1 - ammo_cost
        add("B7", "싸움 손익", "%s %s를 10mm 권총으로(탄 %.1f발)" % (eid, e["name"], shots), round(net, 1), "0 이상(싸움이 손해가 아님 — 짐승은 0 근처 허용)",
            "통과" if net >= 0 else ("주의" if net >= -ammo_cost * 0.6 or eid in ("CR-104", "CR-200") else "실패"), "SD-25 B7", "드롭 기대 %.1f + 탄 회수 %.1f − 탄값 %.1f" % (gain, back, ammo_cost))
    # 루팅 캡(B10): 일반 컨테이너 줄(금고 · 은닉처 · 기금 제외)이 T1~T2 범위(2~20) 안
    for t, v in loot.get("tables", {}).items():
        for r in v.get("rows", []):
            if r[0] != "M-001":
                continue
            lo, hi = int(r[2]), int(r[3])
            big = any(s in t for s in ("safe", "stash", "fund")) and t != "safe_g"
            tgt = (20, 190) if big else (1, 60)                          # 금고 · 은닉처 · 기금은 큰 칸(T1~T5 ×3), 나머지는 일반 칸(T1~T4 2~60)
            st = "통과" if tgt[0] <= lo and hi <= tgt[1] else ("주의" if hi <= tgt[1] * 1.25 else "실패")
            add("B10", "루팅 캡", "표 %s 캡 %d~%d(확률 %.0f%%)" % (t, lo, hi, float(r[1]) * 100), hi, "%d~%d" % tgt, st, "SD-15 §9.2")


def check_misc(db, weapons):
    # 소지(B11): 1막 표준 짐 — 10mm 권총 · 파이프 소총 · 작업복 · 탄 100 · 스팀팩 5 · 음식 · 물 6 · 잡동사니 10
    load_ = weapons["W-002"].get("weight", 2) + weapons["W-013"].get("weight", 5) + db["A-012"].get("weight", 4) + 5 * float(db["I-001"].get("weight", 0) or 0)
    load_ += 6 * float(db.get("I-057", {}).get("weight", 1) or 1) + 10 * 1.0
    add("B11", "소지 · 무게", "1막 표준 짐 %.0f ↔ 한도 200(힘 5)" % load_, round(load_ / 200 * 100), "60% 이하", "통과" if load_ / 200 <= 0.6 else "주의", "SD-10 §2.3 · SD-25 B11")
    # 퍽(B12): 영구 DR 합 ≤ 20
    src = open(os.path.join(ROOT, "game", "core", "rules", "perks.gd"), encoding="utf-8").read()
    m = re.search(r"func dr_bonus.*?return (.*?)\n", src, re.S)
    drs = [float(x) for x in re.findall(r"(\d+(?:\.\d+)?) if rank", m.group(1))] if m else []
    add("B12", "퍽 힘", "영구 DR 퍽 합(지금 고를 수 있는 것)", sum(drs), "20 이하", "통과" if sum(drs) <= 20 else "실패", "SD-10 §5.1")
    # 반복(B13): 상수 · 회당 보상
    rsrc = open(os.path.join(ROOT, "game", "core", "story", "repeat.gd"), encoding="utf-8").read()
    wk = int(re.search(r"const WEEK_CAP := (\d+)", rsrc).group(1))
    xc = int(re.search(r"const XP_CAP := (\d+)", rsrc).group(1))
    add("B13", "반복 퀘스트", "주간 캡 연성 상한", wk, "1,200", "통과" if wk == 1200 else "실패", "SD-15 §9.3-11")
    add("B13", "반복 퀘스트", "RQ별 XP 누적 상한", xc, "500", "통과" if xc == 500 else "실패", "SD-10 §4.4")
    for f in glob.glob(os.path.join(ROOT, "game", "scenes", "story", "*.gd")):
        for l in open(f, encoding="utf-8"):
            m = re.search(r'call_fn\("rq", \["(RQ-\d+)", "[A-Z_]+", (\d+), (\d+)', l)
            if m:
                rid, cp, xp = m.group(1), int(m.group(2)), int(m.group(3))
                if cp > 0:
                    add("B13", "반복 퀘스트", "%s 회당 캡" % rid, cp, "10~200", judge(cp, 10, 200), "SD-15 §9.1 · SD-05 §4")
                add("B13", "반복 퀘스트", "%s 회당 XP" % rid, xp, "0~50", "통과" if xp <= 50 else "실패", "SD-10 §4.4")
    # 코드 규칙(B4): 물기 피해가 주인공 DR을 거치나
    esrc = open(os.path.join(ROOT, "game", "systems", "ai", "enemy.gd"), encoding="utf-8").read()
    m = re.search(r"func _bite\(.*?\n\n", esrc, re.S)
    ok = bool(m) and ("dr" in m.group(0).lower())
    add("B4", "주인공 생존", "코드: 짐승 물기 피해가 주인공 DR을 거친다", "예" if ok else "아니오", "예(SD-11 §4.6 'DR은 몸 전체 기본 저항')",
        "통과" if ok else "실패", "SD-11 §4.6 · SD-14 §2.5")


def main():
    db = items_db()
    weapons = load("weapons.json")
    enemies = load("enemies.json")
    loot = load("loot.json")
    places = load(os.path.join("world", "places.json"))
    check_combat(weapons, enemies)
    check_rewards(places)
    check_economy(db, weapons, loot, enemies)
    check_misc(db, weapons)
    al = allow_list()
    for r in R:
        key = "%s|%s" % (r["id"], r["item"])
        r["allowed"] = r["status"] != "통과" and key in al
        r["reason"] = al.get(key, "")
    fails = [r for r in R if r["status"] == "실패" and not r["allowed"]]
    warns = [r for r in R if r["status"] == "주의" and not r["allowed"]]
    md = ["# 밸런스 검사 보고(SD-25) — `tools/pipeline/balance_check.py`", "",
          "판정: 통과 · 주의(목표에서 25% 안) · 실패. 허용 목록에 이유를 적은 것은 '허용'. 조율은 `.claude/agents/balance-auditor.md`.", "",
          "| 판정 | 수 |", "|---|---|"]
    for s in ("통과", "주의", "실패"):
        md.append("| %s | %d |" % (s, sum(1 for r in R if r["status"] == s)))
    md.append("| 허용(이유 있음) | %d |" % sum(1 for r in R if r["allowed"]))
    for area in sorted({r["id"] for r in R}):
        rows = [r for r in R if r["id"] == area]
        md += ["", "## %s %s" % (area, rows[0]["area"]), "", "| 판정 | 대상 | 값 | 목표 | 정본 | 메모 |", "|---|---|---|---|---|---|"]
        order = {"실패": 0, "주의": 1, "통과": 2}
        for r in sorted(rows, key=lambda x: (order[x["status"]], str(x["item"]))):
            st = ("허용(%s)" % r["reason"][:30]) if r["allowed"] else r["status"]
            md.append("| %s | %s | %s | %s | %s | %s |" % (st, r["item"], r["value"], r["target"], r["src"], r["note"]))
    open(OUT_MD, "w", encoding="utf-8").write("\n".join(md) + "\n")
    json.dump(R, open(OUT_JSON, "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=list)
    print("밸런스: 검사 %d · 통과 %d · 주의 %d · 실패 %d(새 %d) (game/data/_balance_report.md)" % (
        len(R), sum(1 for r in R if r["status"] == "통과"), len(warns), sum(1 for r in R if r["status"] == "실패"), len(fails)))


if __name__ == "__main__":
    main()
