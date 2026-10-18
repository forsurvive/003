"""들어가 보는 건물(단계 1-5e 자유 탐험 확장, STAGE_1 §1.1 '자유도 = 탐험이 서사를 만든다').
월드 굽기가 찍은 건물 1층 문 타일(빌라·주택·아파트 현관·주민센터 문, 공장 셔터, 가게·사무동 정면 가운데) 가운데 일부를 '들어가는 문'으로 정하고,
건물 종류마다 실내 한 장을 씨앗으로 만들어 map_compile로 굽는다(맵 ID 'G-x-y', x·y = 문 칸 월드 좌표).
실내: 빌라·주택(부엌·거실·방, 주택은 욕실) · 아파트 현관(우편함·엘리베이터·경비실) · 주민센터 민원실 · 가게 다섯(구멍가게·약국·철물점·세탁소·분식집) ·
사무실 · 창고. 살림 소품 + 용기(SD-13 §9 용기 표, 권역 등급) + 2077-10-23 밤에 멈춘 사연 글(script/world/rooms.txt) + 위협도에 맞춘 벌레·쥐·구울.
문 일부는 잠겼다(자물쇠 25·50 — 1-5 자물쇠 따기). 실내에서 나오면 그 문 앞 칸으로 돌아간다(출구 표지 '@x,y').
권역: 1막(R01·R02)만. 다른 권역은 그 막 단계에서 연다.
"""
import os, sys, json, glob, random, tempfile, zlib, re
from collections import deque

sys.path.insert(0, os.path.dirname(__file__))
import map_compile as MC

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "data", "maps")
ROOMS = os.path.join(ROOT, "script", "world", "rooms.txt")
HOUSE = os.path.join(ROOT, "script", "world", "households.txt")   # 1-B2 가구 생성기 재료(사건 묶음 · 시간 층 · 건물 이름)
REGIONS = ("R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11", "HR", 0)   # 1-B(사용자 지시 2026-10-17): 전 권역 — 0 = 권역 표 밖(외곽 · 경계)
RATE = {"villa": 1.0, "house": 1.0, "apt": 1.0, "gov": 1.0, "shop": 1.0, "office": 1.0, "factory": 1.0}   # 1-B: 모든 건물을 들어가 볼 수 있게(옛 값 빌라 .25 · 가게 .16 · 주택 · 사무 · 창고 .6)
GEN_VER = 3                                                           # 생성기 판 — 틀 · 글 · 규칙을 바꾸면 올린다(캐시가 버려진다)
# 권역 실내 적(SD-14 · SD-08 권역 결 — 그림 · 자료가 있는 것만, 없는 것은 같은 계열로 대체 · 정합 기록): 위협 → [(적, 확률, 최소, 최대)] — 앞에서부터 굴려 하나만
ENEMY_ROLL = {
    "R01": {1: [("CR-002", 0.3, 1, 2)], 2: [("CR-095", 0.35, 1, 3), ("CR-002", 0.25, 1, 2)], 3: [("CR-200", 0.15, 1, 2), ("CR-095", 0.35, 2, 3)]},
    "R02": {1: [("CR-002", 0.3, 1, 2)], 2: [("CR-095", 0.35, 1, 3), ("CR-002", 0.25, 1, 2)], 3: [("CR-200", 0.3, 1, 2), ("CR-095", 0.35, 2, 3)]},
    "R03": {1: [("CR-136", 0.25, 1, 2), ("CR-002", 0.25, 1, 2)], 2: [("CR-136", 0.3, 1, 2), ("CR-095", 0.3, 1, 3)], 3: [("CR-200", 0.3, 1, 3), ("CR-095", 0.3, 2, 3)]},
    "R04": {1: [("CR-136", 0.3, 1, 2)], 2: [("CR-136", 0.3, 1, 3), ("CR-095", 0.3, 1, 2)], 3: [("CR-200", 0.3, 1, 2), ("CR-136", 0.3, 2, 3)]},
    "R05": {1: [("CR-002", 0.3, 1, 2)], 2: [("CR-200", 0.25, 1, 2), ("CR-305", 0.12, 1, 1)], 3: [("CR-201", 0.25, 1, 2), ("CR-200", 0.3, 2, 3), ("CR-305", 0.15, 1, 1)]},
    "R06": {1: [("CR-002", 0.3, 1, 2)], 2: [("CR-305", 0.15, 1, 1), ("CR-095", 0.3, 1, 3)], 3: [("CR-423", 0.2, 1, 2), ("CR-305", 0.2, 1, 2), ("CR-200", 0.3, 1, 3)]},
    "R07": {1: [("CR-002", 0.25, 1, 2)], 2: [("CR-305", 0.15, 1, 1), ("CR-095", 0.3, 1, 2)], 3: [("CR-305", 0.2, 1, 2), ("CR-200", 0.3, 1, 3)]},
    "R08": {1: [("CR-002", 0.3, 1, 3)], 2: [("CR-095", 0.4, 1, 3), ("CR-002", 0.3, 1, 2)], 3: [("CR-097", 0.08, 1, 1), ("CR-423", 0.18, 1, 2), ("CR-095", 0.4, 2, 4)]},
    "R09": {1: [("CR-136", 0.25, 1, 1), ("CR-002", 0.25, 1, 2)], 2: [("CR-104", 0.3, 1, 2), ("CR-136", 0.3, 1, 2)], 3: [("CR-105", 0.25, 1, 2), ("CR-104", 0.3, 2, 3)]},
    "R10": {1: [("CR-002", 0.3, 1, 2)], 2: [("CR-104", 0.25, 1, 2), ("CR-136", 0.3, 1, 2)], 3: [("CR-105", 0.2, 1, 2), ("CR-104", 0.3, 2, 3)]},
    "R11": {1: [("CR-002", 0.3, 1, 2)], 2: [("CR-305", 0.2, 1, 1), ("CR-104", 0.3, 1, 2)], 3: [("CR-305", 0.25, 1, 2), ("CR-105", 0.25, 1, 2)]},
    "HR": {1: [("CR-095", 0.3, 1, 2)], 2: [("CR-095", 0.35, 1, 3)], 3: [("CR-200", 0.3, 1, 2), ("CR-095", 0.3, 2, 3)]},
}
SHOP_PRE = ["행복", "대박", "새마을", "온누리", "희망", "튼튼", "제일", "깔끔", "백조", "엄마손", "골목", "동네", "우리", "만물", "별빛", "꼬마",
            "한빛", "보람", "새벽", "무지개", "은하", "소망", "다정", "늘봄", "해뜨는", "형제", "삼거리", "언덕", "둥지", "단골"]
SHOP_SUF = {"conv": ["슈퍼", "상회", "마트"], "pharm": ["약국"], "hw": ["철물", "공구"], "laundry": ["세탁", "크리닝"], "snack": ["분식", "김밥"],
            "tea": ["다방", "커피숍"], "salon": ["미용실", "이용원"], "video": ["비디오", "비디오 대여점"], "karaoke": ["노래방", "노래연습장"]}
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_cache", "gen_entries.json")


def read_pools():
    pools, cur = {}, None
    for raw in open(ROOMS, encoding="utf-8").read().split("\n"):
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("@pool "):
            cur = s.split()[1]
            pools[cur] = []
        elif cur:
            pools[cur].append(s)
    return pools


def read_households():
    """households.txt → {이름: {성|남|여|아이: [..]}, 생업: {권역: [..]}, 사건: [{name, cond, lines: [(자리, 글)]}], 층2/층3: [(소품, 글)], 이름표: {..}}"""
    hh = {"이름": {}, "생업": {}, "사건": [], "층2": [], "층3": [], "이름표": {}}
    cur = None
    for raw in open(HOUSE, encoding="utf-8").read().split("\n"):
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("@"):
            head = s[1:].split()
            k = head[0]
            if k == "사건":
                m = re.match(r"@사건 (.+?)(?: \[(.+)\])?$", s)
                cur = {"name": m.group(1), "cond": m.group(2) or "", "lines": []}
                hh["사건"].append(cur)
            elif k in ("층2", "층3"):
                cur = hh[k]
            else:
                cur = (k, head[1])
            continue
        if isinstance(cur, dict):
            slot, txt = [t.strip() for t in s.split("|", 1)]
            cur["lines"].append((slot, txt))
        elif isinstance(cur, list):
            pr, txt = [t.strip() for t in s.split("|", 1)]
            cur.append((pr, txt))
        elif cur and cur[0] == "이름":
            hh["이름"][cur[1]] = s.split()
        elif cur and cur[0] == "생업":
            hh["생업"][cur[1]] = [t.strip() for t in s.split("·")]
        elif cur and cur[0] == "이름표":
            hh["이름표"][cur[1]] = s.split()
    return hh


NUM_KO = {1: "하나", 2: "둘", 3: "셋", 4: "넷", 5: "다섯", 6: "여섯", 7: "일곱"}
LAYER2 = {"R02": 0.55, "R01": 0.40, "R09": 0.35, "R08": 0.35, "R07": 0.08, "R05": 0.20}   # 시간 층 ②(덧댄 살림) — R02 쪽방은 두껍게 · R07 강남은 봉인된 듯
LAYER3 = {"R09": 0.30, "R01": 0.15, "R02": 0.15, "R07": 0.03}                              # 시간 층 ③(최근 며칠) — R09 산동네가 짙게
RHYTHM = (0.70, 0.95)                                                  # 훑기 70% · 사연 25% · 장면 5%(설계안 §7.1c)


JOSA = [("이랑", "랑"), ("을", "를"), ("은", "는"), ("과", "와"), ("아", "야"), ("이", "가")]   # (받침 있음, 없음) — 긴 것부터 · {성}은 '김가'처럼 성 뒤 '가'가 토씨가 아니라 건드리지 않는다


def josa(t, key, val):
    """자리 표시 뒤 토씨를 값의 끝 받침에 맞춘다: '{아이}야' → '지우야' · '예준아' / '{할머니}가' → '설정숙이'."""
    if key == "{성}":
        return t.replace(key, val)
    last = val[-1] if val else ""
    bat = "가" <= last <= "힣" and (ord(last) - 0xAC00) % 28 != 0
    i = t.find(key)
    while i >= 0:
        rest = t[i + len(key):]
        for b_, n_ in JOSA:
            for form in (b_, n_):
                if rest.startswith(form) and not (form in ("이", "가") and rest[len(form):len(form) + 1] in ("네", "씨")):
                    rest = (b_ if bat else n_) + rest[len(form):]
                    break
            else:
                continue
            break
        t = t[:i] + val + rest
        i = t.find(key, i + len(val))
    return t


def roll_household(x, y, region, hh, taken_names):
    """집 하나의 가구(1-B2): 성씨 · 식구 · 생업 · 그날 밤 사건 · 방 리듬. 배치 난수와 따로 굴린다(같은 문 = 같은 집)."""
    r = random.Random(_h(x, y, 1077))
    nm = hh["이름"]

    def full(sex, sur=None):
        for _ in range(12):
            sn = sur or r.choice(nm["성"])
            n = sn + r.choice(nm[sex])
            if n not in taken_names:                                  # 이름 있는 NPC(SD-07)와 겹치지 않게
                return n
        return n
    sur = r.choice(nm["성"])
    f = {"성": sur, "집": sur + "씨네"}
    roll = r.random()
    kind = "혼자" if roll < 0.15 else ("노인" if roll < 0.30 else "가족")
    kids, gran, exp = 0, False, False
    if kind == "혼자":
        n = 1
    elif kind == "노인":
        gran = True
        f["할머니"] = full("여")
        n = 1 + (r.random() < 0.5)
    else:
        f["아빠"] = full("남", sur)
        f["엄마"] = full("여")
        kids = r.choice([0, 1, 1, 2, 2]) if r.random() < 0.85 else 0
        if kids:
            f["아이"] = full("아이", sur)[len(sur):]
        if kids > 1:
            f["아이2"] = full("아이", sur)[len(sur):]
        gran = r.random() < 0.25
        if gran:
            f["할머니"] = full("여")
        exp = r.random() < 0.25
        if exp:
            f["원정"] = "큰아들 " + full("남", sur)[len(sur):]
        n = 2 + kids + gran + exp
    f["식구"], f["식구수"] = NUM_KO.get(n, str(n)), str(n)
    nb = r.choice([s_ for s_ in nm["성"] if s_ != sur])
    f["이웃"] = nb + "씨네"
    f["고향"] = r.choice(nm["고향"])
    f["번호"] = str(r.randint(101, 989))
    jobs = hh["생업"].get(region) or [j for v in hh["생업"].values() for j in v]
    f["생업"] = r.choice(jobs)
    flags = {"아이": kids > 0, "원정": exp, "노인": gran, "혼자": kind == "혼자"}

    def ok(ev):
        for c in ev["cond"].split():
            neg = c.startswith("!")
            if flags.get(c.lstrip("!"), False) == neg:
                return False
        return True

    def fill(t):
        for k_ in re.findall(r"\{(.+?)\}", t):
            if k_ not in f:
                return None
            t = josa(t, "{%s}" % k_, f[k_])
        return t
    cand = []
    for ev in hh["사건"]:
        if not ok(ev):
            continue
        ls = []
        for sl, t in ev["lines"]:
            t = r.choice(t.split(" || "))                              # 갈래 문장 — 집마다 하나
            ls.append((sl, fill(t), "{" in t))
        ls = [(sl, t, ph) for sl, t, ph in ls if t]
        if len(ls) >= 2:
            cand.append((ev["name"], ls))
    rr = r.random()
    mode = "skim" if rr < RHYTHM[0] else ("story" if rr < RHYTHM[1] else "scene")
    ev = r.choice(cand) if cand else ("", [])
    return {"f": f, "kind": kind, "kids": kids, "event": ev[0], "lines": [(sl, t) for sl, t, _ in ev[1]],
            "own": {t for _, t, ph in ev[1] if ph}, "mode": mode,
            "l2": r.random() < LAYER2.get(region, 0.30), "l3": r.random() < LAYER3.get(region, 0.10), "r": r}


def building_name(x, y, style, hh, f=None):
    """문 안내 · 실내 이름(설계안 §7.1d): '청솔빌라 102호' · '김씨네 대문' · '신일빌딩 사무실'. 이름표는 문 자리로 고른다(같은 문 = 같은 이름)."""
    r = random.Random(_h(x, y, 2077))
    tg = hh["이름표"]
    if style == "villa":
        if r.random() < 0.3:
            b = r.choice(tg["연립"]) + "연립"
            return "%s %s동 1층" % (b, r.choice("ABC")), b + " 현관"
        b = r.choice(tg["빌라"]) + "빌라"
        return "%s 10%d호" % (b, r.randint(1, 4)), b + " 현관"
    if style == "house":
        return "%s 단독주택" % f["집"], "%s 대문" % f["집"]
    if style == "apt":
        b = r.choice(tg["빌라"]) + "아파트"
        return "%s %d동 현관" % (b, r.randint(1, 12) * 100 + r.randint(1, 9)), b + " 현관"
    if style == "office":
        b = r.choice(tg["상가"]) + "빌딩"
        return "%s 사무실" % b, b + " 출입문"
    if style == "factory":
        b = r.choice(tg["상가"]) + r.choice(["물류", "공업사", "철공소", "상사", "운수"])
        return "%s 창고" % b, b + " 창고 셔터"
    return None, None


class Plan:
    """실내 한 장: 격자 + 맵 명령. 소품을 놓을 때 칸이 비었는지 본다."""

    def __init__(self, mid, name, wset, W, H, fill, rnd, pools, region):
        self.mid, self.name, self.set, self.W, self.H = mid, name, wset, W, H
        self.g = [["#"] * W for _ in range(H)]
        self.busy = set()
        self.cmds = []
        self.rnd = rnd
        self.pools = pools
        self.used = set()
        self.region = region
        self.fill = fill
        self.walls = set()
        self.ev = {}                                                   # 1-B2: 자리 → 그 집 사건 줄(가구 생성기)
        self.tags = []                                                 # 글 명령마다 (명령 번호, 자리, 사건 줄?, 쪽지 소품 명령 번호)
        self._pool, self._ev = None, False

    def floor(self, x0, y0, x1, y1, ch=None):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch or self.fill

    def isfloor(self, x, y):
        return 0 <= x < self.W and 0 <= y < self.H and self.g[y][x] != "#"

    def free(self, x, y, w=1, h=1):
        return all(self.isfloor(x + i, y + j) and (x + i, y + j) not in self.busy for i in range(w) for j in range(h))

    def prop(self, name, x, y, w=1, h=1, solid=True):
        if not self.free(x, y, w, h):
            return False
        if solid:
            for i in range(w):
                for j in range(h):
                    self.busy.add((x + i, y + j))
        self.cmds.append(f"prop {name} {x} {y}")
        return True

    def wall(self, name, x, y=1, w=1):
        """벽 소품: 벽면 윗칸(y=1)이고 그 아래 두 칸 뒤가 바닥이어야 한다."""
        if all(self.isfloor(x + i, y + 2) and self.g[y][x + i] == "#" and self.g[y + 1][x + i] == "#" and (x + i) not in self.walls
               for i in range(w)):
            self.walls.update(x + i for i in range(w))
            self.cmds.append(f"prop {name} {x} {y}")
            return True
        return False

    def wall_text(self, name, x, pool, w=1):
        """벽 소품 + 그 아래 벽면 칸의 조사 글."""
        if self.wall(name, x, 1, w):
            self.text(x, 2, self.line(pool), w=w)

    def line(self, pool):
        self._pool, self._ev = pool, False
        if self.ev.get(pool):
            self._ev = True
            return self.ev[pool].pop(0)
        cand = [s for s in self.pools.get(pool, []) if s not in self.used]
        hh = getattr(self, "hh", None)
        if hh:                                                         # 1-B2: 살림 글도 그 집과 어긋나지 않게(아이 없는 집에 아이 · 원정 없는 집에 군복 사진)
            cand = [s for s in cand if (hh["kids"] or "아이" not in s) and (hh["f"].get("원정") or "원정" not in s)]
        if not cand:
            return None
        s = self.rnd.choice(cand)
        self.used.add(s)
        return s.replace("{가게}", self.name)

    def text(self, x, y, s, w=1, h=1):
        if s:
            s = s.replace('"', "'")
            self.cmds.append(f'text {x} {y} "{s}"' + (f" w={w}" if w > 1 else "") + (f" h={h}" if h > 1 else ""))
            self.tags.append([len(self.cmds) - 1, self._pool, self._ev, None])
        self._pool, self._ev = None, False

    def note(self, x, y, pool):
        """바닥에 떨어진 쪽지: 종이 소품(밟고 지나갈 수 있다) + 조사 글. 맨바닥 글은 보이지 않아 찾을 수 없다."""
        s = self.line(pool)
        if s and self.free(x, y):
            self.cmds.append(f"prop note_ground {x} {y}")
            self.busy.add((x, y))
            self.text(x, y, s)
            self.tags[-1][3] = len(self.cmds) - 2

    def box(self, x, y, kind, name, w=1, lock=0):
        self.cmds.append(f'box {x} {y} {kind} w={w} name="{name}"' + (f" lock={lock}" if lock else ""))

    def enemy(self, eid, x, y):
        self.cmds.append(f"enemy {eid} {x} {y}")
        self.busy.add((x, y))

    def entrance(self, ex, wx, wy):
        """아래 벽 가운데 두 칸 = 출구(월드 문 앞 칸으로), 그 위 = 들어온 자리."""
        H = self.H
        self.g[H - 1][ex] = self.g[H - 2][ex]
        self.g[H - 1][ex + 1] = self.g[H - 2][ex + 1]
        for i in (0, 1):
            self.cmds.append(f"exit {ex + i} {H - 1} W @{wx},{wy}")
            self.busy.add((ex + i, H - 2))
        self.cmds.append(f"mark from_W {ex} {H - 2} N")
        self.ex = ex

    def spots(self, x0, y0, x1, y1):
        out = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if self.free(x, y)]
        self.rnd.shuffle(out)
        return out

    def source(self):
        rows = ["".join(r) for r in self.g]
        return "\n".join([f"map {self.mid} {self.name}", f"set {self.set}", "grid"] + rows + ["end"] + self.cmds) + "\n"


# ================================================================================================ 틀
def _vwall(p, x, y0, y1):
    for y in range(y0, y1 + 1):
        p.g[y][x] = "#"


def tpl_home(p, bath=False):
    """빌라·주택: 부엌 | 거실(현관) | 방 [| 욕실]. 세로 칸막이는 위쪽만 막고 아래로 트인다(벽 두께 규칙)."""
    rnd, W, H = p.rnd, p.W, p.H
    p.floor(1, 3, W - 2, H - 2, "w")
    xa = rnd.randint(6, 7)
    xb = xa + rnd.randint(7, 8)
    xc = W - 6 if bath else None
    for x in (xa, xb) + ((xc,) if bath else ()):
        _vwall(p, x, 3, rnd.randint(7, 8))
    p.floor(1, 3, xa - 1, H - 2, ",")
    p.floor(xb + 1, 3, (xc - 1) if bath else W - 2, H - 2, "j")
    if bath:
        p.floor(xc + 1, 3, W - 2, H - 2, "o")
    mirror = rnd.random() < 0.5
    ex = rnd.randint(xa + 2, xb - 3)
    p.entrance(ex, *p.door)
    kids = rnd.random() < 0.55
    if getattr(p, "hh", None):
        kids = p.hh["kids"] > 0                                        # 1-B2: 아이 책상은 그 집에 아이가 있을 때만
    # 부엌: 위 벽에 싱크대·가스레인지·냉장고, 가운데 식탁
    xs = 1
    order = ["sink", "range", "fridge"]
    rnd.shuffle(order)
    for it in order:
        if it == "sink" and p.prop("kitchen_sink", xs, 3, 2):
            p.box(xs, 3, "pantry", "찬장", w=2); xs += 2
        elif it == "range" and p.prop("gas_range", xs, 3):
            xs += 1
        elif it == "fridge" and p.prop("fridge", xs, 3):
            p.box(xs, 3, "pantry", "냉장고")
            p.text(xs, 3, p.line("home_fridge")) if rnd.random() < 0.5 or p.ev.get("home_fridge") else None
            xs += 1
    ty = rnd.randint(6, 7)
    tx = max(1, (xa - 2) // 2)
    if p.prop("dining_table", tx, ty, 2):
        p.text(tx, ty, p.line("home_table"), w=2)
    if rnd.random() < 0.6 or p.ev.get("home_note"):
        p.wall_text("w_calendar", rnd.randint(1, xa - 2), "home_note")
    # 거실
    lx0, lx1 = xa + 1, xb - 1
    cand = [("bookshelf_home", 1), ("crt_tv", 1), ("plant_pot", 1)] + ([("piano", 2)] if rnd.random() < 0.25 else [])
    rnd.shuffle(cand)
    x = lx0
    for nm, w in cand:
        if x + w - 1 <= lx1 and p.prop(nm, x, 3, w):
            if nm == "crt_tv":
                p.text(x, 3, p.line("home_tv"))
            x += w + (1 if rnd.random() < 0.4 else 0)
    sy = rnd.randint(6, 7)
    sx = lx0 + rnd.randint(0, max(0, lx1 - lx0 - 1))
    if p.prop("sofa_home", min(sx, lx1 - 1), sy, 2):
        if p.free(min(sx, lx1 - 1), sy + 2, 2):
            p.prop("low_table", min(sx, lx1 - 1), sy + 2, 2)
    p.wall_text("w_photo", rnd.randint(lx0, lx1), "home_photo")
    p.wall("wall_clock", rnd.randint(lx0, lx1)) if rnd.random() < 0.6 else None
    for sx in (ex + 2, ex - 1):
        if p.prop("shoe_rack", sx, H - 2):
            p.text(sx, H - 2, p.line("home_shoe"))
            break
    # 방
    bx0, bx1 = xb + 1, (xc - 1) if bath else W - 2
    if p.prop("wardrobe", bx0, 3, 2):
        p.box(bx0, 3, "apartment", "자개장롱", w=2, lock=25 if rnd.random() < 0.2 else 0)
    for yx in (bx1, bx0 + 2):
        if p.prop("yo_bed", yx, 3, 1, 2):
            p.text(yx, 3, p.line("home_bed"), h=2)
            break
    for (x, y) in p.spots(bx0, 6, bx1, H - 3)[:1]:
        if p.prop("dresser", x, y):
            p.box(x, y, "apartment", "서랍장")
    if kids:
        for (x, y) in p.spots(bx0, 6, bx1, H - 3)[:1]:
            if p.prop("kid_desk", x, y):
                p.box(x, y, "desk", "아이 책상 서랍")
                p.text(x, y, p.line("home_kid"))
        p.wall("w_kid_drawing", rnd.randint(bx0, bx1)) if rnd.random() < 0.7 else None
    # 욕실
    if bath:
        p.prop("bathtub", xc + 1, 3, 2) or p.prop("toilet_bk", xc + 1, 3)
        p.prop("wash_basin", xc + 3, 3) if p.free(xc + 3, 3) else None
        p.prop("toilet_bk", xc + 4, 3) if p.free(xc + 4, 3) else None
        p.wall("w_mirror", xc + 3) if rnd.random() < 0.7 else None
    clutter(p, rnd.randint(0, 2), 8)
    return "home"


HOME_SLOTS = {"home_table", "home_tv", "home_bed", "home_kid", "home_photo", "home_fridge", "home_shoe", "home_note"}


def apply_rhythm(p):
    """방 리듬(1-B2 · 설계안 §7.1c): 훑기 = 그 집 사건 줄 하나(없으면 살림 글 하나 — 재미 검수: 공용 글만 남으면 6천 채가 같은 말) ·
    사연 = 그 집 사건 줄 전부 + 살림 글 하나 · 장면 = 다 둔다.
    가구는 그대로 두고 조사 글만 줄인다(땅에 떨어진 쪽지는 소품째). 유해 · 소굴 글은 늘 남는다."""
    mode = p.hh["mode"]
    if mode == "scene":
        return
    home = [t for t in p.tags if t[1] in HOME_SLOTS]
    evs = [t for t in home if t[2]]
    plain = [t for t in home if not t[2]]
    if mode == "skim":                                                 # 그 집만의 줄(이름 · 생업 · 식구가 든 줄)을 먼저
        own = [t for t in evs if any(o.replace('"', "'") in p.cmds[t[0]] for o in p.hh["own"])]
        pick = own or evs or plain
        keep = {id(p.hh["r"].choice(pick))} if pick else set()
    else:
        keep = {id(t) for t in evs}
        if plain:
            keep.add(id(p.hh["r"].choice(plain)))
    drop = set()
    for t in home:
        if id(t) not in keep:
            drop.add(t[0])
            if t[3] is not None:
                drop.add(t[3])
    p.cmds = [c for i, c in enumerate(p.cmds) if i not in drop]
    p.tags = []


def add_layers(p, hh_src):
    """시간 층 ② 덧댄 살림 · ③ 최근 며칠의 흔적(설계안 §7.1b). 소품 하나 + 조사 글 하나씩. 들어온 자리 앞은 비운다."""
    r = p.hh["r"]
    keep = {(p.ex + i, p.H - 2 - j) for i in (-1, 0, 1, 2) for j in (0, 1, 2)}
    got = []
    for lay in ("l2", "l3"):
        if not p.hh[lay]:
            continue
        pr, txt = r.choice(hh_src["층2" if lay == "l2" else "층3"])
        pm = p.pm.get(pr)
        if pm is None:
            continue
        fw, fh = max(1, pm["foot"][0]), max(1, pm["foot"][1])
        if pm["kind"] == "wall":
            xs = list(range(1, p.W - fw))
            r.shuffle(xs)
            for x in xs:
                if p.wall(pr, x, 1, fw):
                    p.text(x, 2, txt, w=fw)
                    got.append(lay)
                    break
        else:
            for (x, y) in p.spots(1, 4, p.W - 1 - fw, p.H - 2 - fh):
                if any((x + i, y + j) in keep for i in range(fw) for j in range(fh)):
                    continue
                if p.prop(pr, x, y, fw, fh, solid=pm["kind"] != "deco"):
                    p.busy.update((x + i, y + j) for i in range(fw) for j in range(fh))
                    p.text(x, y, txt)
                    got.append(lay)
                    break
    return got


SIGN_RATE = {"skull": 50, "claw": 35, "trap": 50, "live": 60, "x": 40, "water": 15}
BEASTS = {"CR-002", "CR-095", "CR-097", "CR-104", "CR-105", "CR-106", "CR-108", "CR-136"}   # 짐승 — 해골이 아니라 발톱 자국


def door_sign(out, seed):
    """문 앞 떠돌이 분필 표식(1-B3 · 설계안 §7.2): 실내 생성 결과에서 뽑는다 — 표식은 거짓말하지 않는다(P1).
    해골 = 안에 적(바퀴 한두 마리는 빼고) · 덫 = 숨긴 함정 · 지뢰 · 부비트랩 · 집 = 최근 며칠 사람 기척 · ✕ = 무너져 막힘 · 물결 = 물 받을 데.
    모든 문에 있지는 않다(떠돌이가 다녀간 문만 — 갈래마다 비율)."""
    en = out.get("enemies", [])
    props = {q["name"] for q in out.get("props", [])}
    kind = None
    if any(e_["id"] not in BEASTS for e_ in en):                     # 사람형 · 구울 · 로봇(재미 검수: 쥐 한 마리가 해골이면 표식이 벽지가 된다)
        kind = "skull"
    elif len(en) >= 2 or any(e_["id"] not in ("CR-002",) for e_ in en):
        kind = "claw"
    elif out.get("traps") or out.get("mines") or props & {"trap_parcel", "trap_vending"}:
        kind = "trap"
    elif "l3" in out.get("house", {}).get("layers", []):               # 기척은 층 ③에서만(장면 방이라고 거짓말하지 않는다)
        kind = "live"
    elif out.get("gen") == "collapsed":
        kind = "x"
    elif props & {"water_jug", "water_tank", "water_tank_s", "bathtub"}:
        kind = "water"
    if kind and _h(seed, 131) % 100 < SIGN_RATE[kind]:
        return kind
    return None


def tpl_collapsed(p):
    """무너져 막힌 1층(1-B 대체 틀 — 씨앗 12번이 다 실패한 건물도 들어가 볼 수 있게): 현관 · 계단참 한 칸. 안쪽은 무너진 천장에 막혔다.
    그래도 용기 하나 · 조사 글 하나(빈 실내 금지)."""
    rnd, W, H = p.rnd, p.W, p.H
    p.floor(1, 3, W - 2, H - 2)
    ex = W // 2
    p.entrance(ex, *p.door)
    for x in range(1, W - 1):                                         # 안쪽 줄은 무너진 천장
        if rnd.random() < 0.75:
            p.prop("rubble", x, 3)
    p.text(ex, 3, "무너진 천장이 계단과 안쪽 복도를 막았다. 틈으로 찬바람만 나온다.") if not p.free(ex, 3) else None
    for (x, y) in p.spots(1, 4, W - 2, H - 3)[:1]:
        if p.prop("crate_o", x, y):
            p.box(x, y, "stall", "현관 구석 상자")
    clutter(p, rnd.randint(1, 2), 4)
    return "collapsed"


def tpl_den(p):
    """빈집에 든 떠돌이 자리(위협 2 이상 빌라·주택 일부): 거실 하나에 침낭·깡통 난로·고물. 생활 살림은 털렸다."""
    rnd, W, H = p.rnd, p.W, p.H
    p.floor(1, 3, W - 2, H - 2, "w")
    ex = rnd.randint(3, W - 5)
    p.entrance(ex, *p.door)
    cx, cy = W // 2, 6
    p.prop("drum_fire", cx, cy)
    p.text(cx, cy, p.line("den_note"))
    for (x, y) in ((cx - 2, cy), (cx + 2, cy), (cx, cy + 2)):
        p.cmds.append(f"prop straw_mat {x} {y}")
    if p.prop("scrap_pile", 1, 3, 2):
        p.box(1, 3, "trash", "고물 더미", w=2)
    if p.prop("crate_o", W - 3, 3):
        p.box(W - 3, 3, "stall", "떠돌이의 상자")
    for (x, y) in p.spots(1, 3, W - 2, H - 3)[:1]:
        if p.prop("remains2", x, y):
            p.box(x, y, "corpse_scav", "떠돌이의 유해")
            p.text(x, y, p.line("remains_note"))
    return "den"


def tpl_apt(p):
    """아파트 현관(계단실 1층): 우편함 · 엘리베이터(멈춤) · 무너진 계단 · 경비실(칸막이)."""
    rnd, W, H = p.rnd, p.W, p.H
    p.floor(1, 3, W - 2, H - 2, "t")
    xs = 5
    _vwall(p, xs, 3, 7)
    p.floor(1, 3, xs - 1, H - 2, ",")
    ex = rnd.randint(xs + 2, W - 5)
    p.entrance(ex, *p.door)
    p.prop("duty_table", 1, 3)
    p.text(1, 3, p.line("apt_note"))
    p.prop("radio_desk", 2, 3)
    if p.prop("file_cabinet", 3, 3):
        p.box(3, 3, "cabinet", "관리 서류함")
    p.wall_text("w_mailboxes", xs + 2, "apt_note", 2)
    if p.wall("w_elevator", xs + 5, 1, 2):
        p.text(xs + 5, 2, "엘리베이터. 층 표시 바늘이 1에 멈췄다. 문틈 너머는 깜깜하다.", w=2)
    p.cmds.append(f"prop stairs_up {W - 3} 3")
    p.busy.update({(W - 3, 3), (W - 2, 3)})
    p.text(W - 3, 3, "위층 계단. 두 층 위에서 무너져 막혔다. 위로는 갈 수 없다.", w=2)
    for (x, y) in p.spots(xs + 1, 5, W - 2, H - 3)[:1]:
        p.prop("crate_o", x, y) and p.box(x, y, "apartment", "주인 없는 짐")
    for (x, y) in p.spots(1, 6, xs - 1, H - 3)[:1]:
        p.prop("stool_w", x, y)
    return "apt"


def tpl_gov(p):
    """주민센터 민원실: 앞 = 대기 의자·번호표 발급기, 가운데 민원 창구 줄, 뒤 = 사무 책상·서류함·금고."""
    rnd, W, H = p.rnd, p.W, p.H
    p.floor(1, 3, W - 2, H - 2, "t")
    ex = W // 2 - 1
    p.entrance(ex, *p.door)
    cy = 7
    x = 2
    while x + 1 <= W - 6:
        p.prop("gov_counter", x, cy, 2)
        x += 2
    p.text(2, cy, p.line("gov_note"), w=2)
    for k, x in enumerate(range(3, W - 5, 4)):
        if p.prop("office_desk", x, 4, 2):
            p.box(x, 4, "desk", "책상 서랍")
            if k == 0:
                p.text(x, 4, p.line("gov_note"), w=2)
    if p.prop("file_cabinet", W - 3, 3):
        p.box(W - 3, 3, "cabinet", "민원 서류함")
    if p.prop("safe", W - 2, 3):
        p.box(W - 2, 3, "safe", "주민센터 금고", lock=50)
    for x in range(2, W - 4, 3):
        if x + 1 < ex - 1 or x > ex + 2:
            p.prop("wait_chairs", x, 10, 2)
    p.prop("num_machine", ex + 2, H - 3) and p.text(ex + 2, H - 3, p.line("gov_note"))
    p.wall("w_gov_notice", 3, 1, 2)
    p.wall("wall_clock", W // 2)
    if p.prop("civil_box", 1, 9):
        p.box(1, 9, "civil", "민방위 비상함")
    for (x, y) in p.spots(1, 9, W - 2, H - 3)[:1]:
        p.prop("bone_pile", x, y) and p.text(x, y, "번호표를 쥔 채 바닥에 쓰러진 뼈. 412번.")
    return "gov"


SHOPS = ["conv", "pharm", "hw", "laundry", "snack", "tea", "salon", "video", "karaoke"]   # 1-B5: 다방 · 미용실 · 비디오 가게 · 노래방
CLUTTER = [("rubble", 1, 3), ("rubble2", 1, 3), ("crate_o", 1, 2), ("scrap_pile", 2, 1), ("bone_pile", 1, 1), ("drum", 1, 1), ("plant_pot", 1, 1)]
WALL_DECO = {"jm": ["w_poster_rad", "w_calendar", "wall_clock", "w_shelf"], "bk": ["w_window", "wall_clock", "w_calendar", "w_poster_rad"],
             "sb": ["w_stencil", "w_poster_rad", "w_sign_exit"], "bc": ["w_calendar", "wall_clock", "w_window"]}


def row_props(p, names, y, x0, x1, skip=0.15, boxes=None, seq=False):
    """한 줄에 소품을 늘어놓는다: 틈 0~2칸 무작위, 일부는 빠진다(털려 치운 자리). boxes = {이름: (용기 종류, 이름, 비율)}.
    seq = 이름 목록을 차례로 한 번씩만(부엌 한 줄처럼)."""
    rnd = p.rnd
    x = x0 + rnd.randint(0, 1)
    out = []
    todo = list(names)
    while x <= x1 and (todo or not seq):
        nm = todo.pop(0) if seq else rnd.choice(names)
        w = 2 if nm in TWO_WIDE else 1
        if x + w - 1 > x1:
            break
        if rnd.random() >= skip and p.prop(nm, x, y, w):
            out.append((nm, x))
            if boxes and nm in boxes and rnd.random() < boxes[nm][2]:
                p.box(x, y, boxes[nm][0], boxes[nm][1], w=w)
        x += w + rnd.choice((0, 0, 1, 1, 2))
    return out


def clutter(p, n, y0=4):
    """바닥 잡동사니: 무너진 천장 조각·고물·상자·뼈. 상자 일부는 용기."""
    rnd = p.rnd
    for (x, y) in p.spots(1, y0, p.W - 2, p.H - 3):
        if n <= 0:
            break
        if abs(x - p.ex) <= 1 and y >= p.H - 4:
            continue
        nm, w, wt = rnd.choice([c for c in CLUTTER for _ in range(c[2])])
        if p.prop(nm, x, y, w):
            n -= 1
            if nm == "crate_o" and rnd.random() < 0.5:
                p.box(x, y, rnd.choice(["trash", "stall", "crate"]), "나무 상자")
            elif nm == "scrap_pile" and rnd.random() < 0.5:
                p.box(x, y, "trash", "고물 더미", w=2)


def wall_deco(p, k=None):
    rnd = p.rnd
    pool = list(WALL_DECO.get(p.set, ["w_calendar"]))
    rnd.shuffle(pool)
    for nm in pool[:k if k is not None else rnd.randint(1, 3)]:
        w = 2 if nm in ("w_window", "w_shelf", "w_stencil", "w_sign_exit") else 1
        p.wall(nm, rnd.randint(1, p.W - 1 - w), 1, w)


def maybe_remains(p, ch=0.12):
    if p.rnd.random() < ch:
        for (x, y) in p.spots(1, 4, p.W - 2, p.H - 3)[:1]:
            if p.prop(p.rnd.choice(["remains", "remains2"]), x, y):
                p.box(x, y, "corpse_scav", "떠돌이의 유해")
                p.text(x, y, p.line("remains_note"))


def counter(p, nm="cash_counter", kind="desk", lock_ch=0.0, pool="shop_counter"):
    """계산대: 출입구 반대쪽 아래 구석(들어서면 바로 보인다)."""
    rnd, W, H = p.rnd, p.W, p.H
    cx = W - 3 - rnd.randint(0, 2) if p.ex < W // 2 else 1 + rnd.randint(0, 2)
    for yy in (H - 3, H - 4):
        if p.prop(nm, cx, yy, 2):
            p.box(cx, yy, kind, "계산대 서랍", w=2, lock=25 if rnd.random() < lock_ch else 0)
            p.text(cx, yy, p.line(pool), w=2)
            return True
    return False


def tpl_shop(p, kind):
    rnd, W, H = p.rnd, p.W, p.H
    p.floor(1, 3, W - 2, H - 2, "," if kind != "pharm" else "o")
    ex = rnd.randint(2, W - 5)
    p.entrance(ex, *p.door)
    if kind == "conv":
        row_props(p, ["shop_shelf", "shop_shelf_can", "shop_shelf_goods"], 3, 1, W - 3, 0.1,
                  {n: ("conv", "진열대", 0.6) for n in ("shop_shelf", "shop_shelf_can", "shop_shelf_goods")})
        if p.prop("drink_fridge", W - 2, 3) or p.prop("drink_fridge", 1, 3):
            p.box(int(p.cmds[-1].split()[2]), 3, "conv", "음료 냉장고")
        row_props(p, ["shop_shelf", "shop_shelf_can"], rnd.randint(6, 7), 2, W - 4, 0.35,
                  {n: ("conv", "진열대", 0.5) for n in ("shop_shelf", "shop_shelf_can")})
        counter(p, lock_ch=0.4)
    elif kind == "pharm":
        row_props(p, ["med_shelf"], 3, 1, W - 3, 0.15, {"med_shelf": ("pharmacy", "약장", 0.7)})
        cx = rnd.randint(2, W - 5)
        if p.prop("pharm_counter", cx, rnd.randint(6, 7), 2):
            cy = int(p.cmds[-1].split()[3])
            p.box(cx, cy, "pharmacy", "조제대", w=2, lock=25 if rnd.random() < 0.5 else 0)
            p.text(cx, cy, p.line("pharm_note"), w=2)
        if rnd.random() < 0.4:                                          # 마지막까지 사람을 눕혔던 약국
            for (x, y) in p.spots(1, 8, W - 2, H - 3)[:2]:
                p.prop("cot", x, y, 1, 2) if p.free(x, y, 1, 2) else None
            for (x, y) in p.spots(1, 8, W - 2, H - 3)[:1]:
                p.prop("iv_pole", x, y)
        p.wall("w_cross", rnd.randint(1, W - 3))
    elif kind == "hw":
        row_props(p, ["hw_rack", "steel_rack", "hw_rack"], 3, 1, W - 2, 0.1,
                  {"hw_rack": ("toolbox", "철물 진열대", 0.6), "steel_rack": ("crate", "철물 선반", 0.6)})
        for (x, y) in p.spots(1, 6, W - 3, H - 4)[:1]:
            p.prop("workbench", x, y, 2) and p.box(x, y, "toolbox", "작업대", w=2)
        for (x, y) in p.spots(1, 6, W - 2, H - 4)[:1]:
            p.prop("tool_chest", x, y) and p.box(x, y, "toolbox", "공구함", lock=25 if rnd.random() < 0.3 else 0)
        counter(p)
    elif kind == "laundry":
        n = rnd.randint(3, 6)
        x0 = rnd.randint(1, max(1, W - 2 - n))
        for i in range(n):
            p.prop("washer", x0 + i, 3)
        p.text(x0, 3, p.line("laundry_note"))
        for (x, y) in p.spots(1, 6, W - 3, 8)[:rnd.randint(1, 3)]:
            if p.prop("laundry_rack", x, y, 2):
                p.box(x, y, "apartment", "맡긴 옷", w=2)
                p.text(x, y, p.line("laundry_note"), w=2)
        counter(p)
    elif kind == "tea":                                                 # 다방: 소파 칸 · 찻상 · 카운터 · 텔레비전
        for x0 in range(1, W - 4, 5):
            y0 = rnd.choice((4, 7))
            if p.prop("sofa_home", x0, y0, 2):
                if p.prop("low_table", x0, y0 + 1, 2) and rnd.random() < 0.5:
                    p.text(x0, y0 + 1, p.line("tea_note"), w=2)
        p.prop("crt_tv", W - 2, 3) and p.text(W - 2, 3, p.line("tea_note"))
        for (x, y) in p.spots(1, 3, W - 3, 3)[:1]:
            p.prop("tea_table", x, y) and p.box(x, y, "pantry", "찻장")
        counter(p, pool="tea_note")
    elif kind == "salon":                                               # 미용실: 벽 거울 줄 · 머리 감는 대 · 대기 소파
        x = 1
        while x < W - 2:
            if p.wall("w_mirror", x):
                p.text(x, 2, p.line("salon_note")) if rnd.random() < 0.3 else None
            x += 2
        for xx in range(1, W - 2, 2):
            if p.prop("wash_basin", xx, 3) and rnd.random() < 0.3:
                p.box(xx, 3, "apartment", "미용 도구 서랍")
        for (x, y) in p.spots(1, 6, W - 3, 8)[:1]:
            p.prop("sofa_home", x, y, 2) and p.text(x, y, p.line("salon_note"), w=2)
        counter(p, pool="salon_note")
    elif kind == "video":                                               # 비디오 가게: 테이프 진열대 줄 · 반납함 · 텔레비전
        row_props(p, ["shop_shelf_goods", "shop_shelf_goods"], 3, 1, W - 3, 0.1, {"shop_shelf_goods": ("stall", "테이프 진열대", 0.6)})
        row_props(p, ["shop_shelf_goods"], rnd.randint(6, 7), 2, W - 4, 0.35, {"shop_shelf_goods": ("stall", "테이프 진열대", 0.5)})
        for (x, y) in p.spots(1, 5, W - 2, H - 4)[:1]:
            p.prop("crt_tv", x, y) and p.text(x, y, p.line("video_note"))
        counter(p, pool="video_note")
    elif kind == "karaoke":                                             # 노래방: 칸막이 방 둘~셋(세로 칸막이는 위만 막고 아래로 트인다) · 소파 · 화면
        xs = list(range(1 + 6, W - 3, 6))
        for x in xs:
            _vwall(p, x, 3, 6)
        for x0 in [1] + [x + 1 for x in xs]:
            if p.prop("sofa_home", x0, 5, 2):
                if rnd.random() < 0.5:
                    p.text(x0, 5, p.line("karaoke_note"), w=2)
            if p.prop("crt_tv", x0 + 2, 3) and rnd.random() < 0.5:
                p.text(x0 + 2, 3, p.line("karaoke_note"))
        counter(p, pool="karaoke_note")
    else:                                                               # 분식집
        order = ["kitchen_sink", "gas_range", "fridge"] + (["gas_range"] if rnd.random() < 0.5 else [])
        rnd.shuffle(order)
        row_props(p, order, 3, 1, W - 2, 0.0, {"kitchen_sink": ("pantry", "찬장", 1.0), "fridge": ("pantry", "냉장고", 1.0)}, seq=True)
        for (x, y) in p.spots(1, 6, W - 3, 8)[:rnd.randint(2, 4)]:
            if p.prop("dining_table", x, y, 2) and rnd.random() < 0.5:
                p.text(x, y, rnd.choice(["식탁마다 떡볶이 접시가 굳었다. 포크가 꽂힌 채.", "김밥 은박지가 반쯤 펼쳐진 채 말라붙었다.",
                                         "국물 그릇 둘. 하나는 깨끗이 비웠다.", "'카드 안 됨 — 현금·배급표만' 메뉴판이 엎어져 있다."]), w=2)
        counter(p)
    wall_deco(p)
    clutter(p, rnd.randint(1, 3), 8)
    maybe_remains(p)
    for (x, y) in p.spots(1, 5, W - 2, H - 3)[:1]:
        p.note(x, y, "pharm_note" if kind == "pharm" else "shop_note")
    return kind


def tpl_office(p):
    rnd, W, H = p.rnd, p.W, p.H
    p.floor(1, 3, W - 2, H - 2, "c")
    ex = rnd.randint(3, W - 5)
    p.entrance(ex, *p.door)
    slots = [(x, y) for y in (4, 7) for x in range(2, W - 3, 4)]
    rnd.shuffle(slots)
    for i, (x, y) in enumerate(slots[:rnd.randint(3, len(slots))]):
        if p.prop("office_desk", x, y + rnd.randint(0, 1), 2):
            yy = int(p.cmds[-1].split()[3])
            p.box(x, yy, "desk", "책상 서랍")
            if i == 0:
                p.text(x, yy, p.line("office_note"), w=2)
    for x in (1, W - 2):
        if rnd.random() < 0.8:
            p.prop("file_cabinet", x, 3) and p.box(x, 3, "cabinet", "서류함")
    p.prop("water_cooler", rnd.randint(2, W - 3), 3)
    p.prop("plant_pot", rnd.randint(2, W - 3), 3)
    if rnd.random() < 0.35:
        for (x, y) in p.spots(1, 3, W - 2, 5)[:1]:
            p.prop("safe", x, y) and p.box(x, y, "safe", "사무실 금고", lock=50)
    wall_deco(p)
    clutter(p, rnd.randint(1, 3), 8)
    maybe_remains(p, 0.18)
    return "office"


def tpl_store(p):
    rnd, W, H = p.rnd, p.W, p.H
    p.floor(1, 3, W - 2, H - 2, "~")
    ex = rnd.randint(3, W - 5)
    p.entrance(ex, *p.door)
    row_props(p, ["steel_rack"], 3, 1, W - 3, 0.15, {"steel_rack": ("crate", "창고 선반", 0.6)})
    row_props(p, ["steel_rack", "pallet_sacks", "drum"], rnd.randint(6, 7), 1, W - 3, 0.3,
              {"steel_rack": ("crate", "창고 선반", 0.5), "pallet_sacks": ("pantry", "포대", 0.6)})
    p.text(1, 3, p.line("store_note"), w=2)
    for (x, y) in p.spots(1, 9, W - 3, H - 3)[:1]:
        p.prop("workbench", x, y, 2) and p.box(x, y, "toolbox", "작업대", w=2)
    wall_deco(p)
    clutter(p, rnd.randint(2, 4), 9)
    maybe_remains(p, 0.15)
    return "store"


TWO_WIDE = {"shop_shelf", "shop_shelf_can", "shop_shelf_goods", "med_shelf", "hw_rack", "steel_rack", "kitchen_sink", "laundry_rack",
            "dining_table", "cash_counter", "workbench", "scrap_pile", "office_desk", "gov_counter", "wait_chairs", "sofa_home", "piano"}


PROP_NAMES = set()


# ================================================================================================ 고르기·굽기
def _reach(out, start):
    W, H = out["size"]
    sol = out["solid"]
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen and sol[ny][nx] == "0":
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen


def _ok(out):
    """들어온 자리에서 용기·조사 글·적에 모두 닿는가(옆 칸 포함)."""
    m = out["marks"]["from_W"]
    seen = _reach(out, (m[0], m[1]))

    def near(x, y, w=1, h=1):
        for i in range(-1, w + 1):
            for j in range(-1, h + 1):
                if (x + i, y + j) in seen:
                    return True
        return False
    for b in out["boxes"]:
        if not near(b["x"], b["y"], b.get("w", 1), b.get("h", 1)):
            return False
    for t in out["texts"]:
        if not near(t["x"], t["y"], t.get("w", 1), t.get("h", 1)):
            return False
    for e in out["enemies"]:
        if (e["x"], e["y"]) not in seen:
            return False
    return len(seen) >= 20


# 장소 결 몹(1-L 계획 §2.3): 권역 표(그 권역에 사는 것)는 그대로 두고, 장소가 부르는 것으로 가중 · 적이 있을 확률(위협 1/2/3)을 바꾼다.
# 결 → ({적: 가중}, (확률 1, 2, 3), 장소 고유(권역 표에 없어도 부르는 사람형 — 그 위협부터)). 가중에 없는 권역 적은 0.5
PLACE_MOB = {
    "food": ({"CR-002": 2.5, "CR-095": 2.0, "CR-004": 1.0}, (0.35, 0.5, 0.6), {}),
    "pharm": ({"CR-200": 2.5, "CR-201": 1.5, "CR-002": 0.6}, (0.25, 0.4, 0.55), {"CR-423": 3}),
    "dark": ({"CR-200": 3.0, "CR-201": 1.0}, (0.25, 0.4, 0.55), {}),
    "office": ({"CR-200": 2.0, "CR-201": 2.0, "CR-305": 1.0}, (0.25, 0.35, 0.5), {}),
    "store": ({"CR-095": 2.0, "CR-096": 1.5, "CR-097": 0.3, "CR-136": 1.0}, (0.3, 0.45, 0.55), {}),
    "home": ({"CR-104": 1.5, "CR-136": 1.5, "CR-002": 1.0, "CR-095": 0.8}, (0.15, 0.3, 0.45), {}),
    "den": ({"CR-423": 3.0, "CR-420": 1.0}, (0.4, 0.6, 0.7), {"CR-423": 1, "CR-420": 2}),
    "quiet": ({}, (0.0, 0.0, 0.0), {}),
}
PLACE_FAM = {"conv": "food", "snack": "food", "tea": "food", "pharm": "pharm", "karaoke": "dark", "video": "dark", "salon": "home",
             "laundry": "home", "hw": "store"}


def _mob_family(p, style):
    if getattr(p, "den", False):
        return "den"
    if "l3" in getattr(p, "layers", []):
        return "quiet"                                                 # 최근 사람이 드나드는 집: 짐승은 없다(사람이 있다 — 1-L §3.4)
    if style == "shop":
        return PLACE_FAM.get(getattr(p, "shop_kind", ""), "food")
    return {"office": "office", "gov": "office", "factory": "store"}.get(style, "home")


def _place_enemies(p, threat, region, style="villa"):
    """장소 결 몹(1-L §2.3 · 1-B4 상황): 결 확률로 적이 있나 굴리고, 그 권역 · 그 위협 이하 적(+ 장소 고유 사람형)을 결 가중으로 하나 고른다.
    떠돌이 소굴의 사람형은 절반이 자는 중 · 유해가 있는 집의 짐승은 뜯어먹는 중(감지 0.5). 상황 판정은 따로 굴린다."""
    rnd = p.rnd
    tab = ENEMY_ROLL.get(region, ENEMY_ROLL["HR"])
    th = max(1, min(3, threat))
    fam = _mob_family(p, style)
    wts, probs, own = PLACE_MOB[fam]
    sit = random.Random(_h(len(p.cmds), p.W, p.H, p.ex))
    feed = any(c.startswith("prop remains ") for c in p.cmds)
    if rnd.random() >= probs[th - 1]:
        return
    cands = {}
    for t in range(1, th + 1):
        for eid, _ch, lo, hi in tab[t]:
            cands[eid] = (lo, hi)
    for eid, t0 in own.items():
        if th >= t0:
            cands.setdefault(eid, (1, 2))
    if not cands:
        return
    ids = sorted(cands)
    ws = [wts.get(e, 0.5) for e in ids]
    eid = rnd.choices(ids, ws)[0]
    lo, hi = cands[eid]
    far = [(x, y) for (x, y) in p.spots(1, 3, p.W - 2, p.H - 3) if abs(x - p.ex) + abs(y - (p.H - 2)) >= 6]
    for (x, y) in far[:rnd.randint(lo, hi)]:
        p.enemy(eid, x, y)
        if fam == "den" and eid not in BEASTS and sit.random() < 0.55:
            p.cmds[-1] += " sleep=1"
        elif feed and eid in BEASTS:
            p.cmds[-1] += " det=0.5"


def build_one(spec, pools, prop_meta, known_vars, known_fns, scenes, tries=12, hh_src=None, npc_names=frozenset()):
    """문 하나 → (맵 JSON, 이름) 또는 None. 씨앗이 맞지 않으면 다음 씨앗(1-11j: 6 → 12 — 먼저 맞는 씨앗은 그대로라 기존 건물은 바뀌지 않는다)."""
    x, y, style, threat, region = spec["x"], spec["y"], spec["style"], spec["threat"], spec["region"]
    mid = f"G-{x}-{y}"
    hh = roll_household(x, y, region, hh_src, npc_names) if hh_src and style in ("villa", "house") else None
    bname, blabel = building_name(x, y, style, hh_src, hh["f"] if hh else None) if hh_src else (None, None)
    for k in range(tries):
        rnd = random.Random((x * 73856093) ^ (y * 19349663) ^ (k * 83492791))
        got = style
        if spec.get("collapsed"):
            nm = {"shop": "무너진 가게", "office": "무너진 사무동", "factory": "무너진 창고", "gov": "무너진 청사", "apt": "무너진 현관"}.get(style, "무너진 1층")
            p = Plan(mid, nm, "bk", 14 + rnd.randint(0, 2), 9, "~", rnd, pools, region)
        elif style in ("villa", "house"):
            den = threat >= 2 and rnd.random() < 0.12
            if den:
                p = Plan(mid, (hh["f"]["집"] + "였던 집") if hh else "버려진 집", "bc", 16, 12, "w", rnd, pools, region)
                p.den = True
            else:
                bath = style == "house" and rnd.random() < 0.7
                W = (26 if bath else 22) + rnd.randint(0, 1)
                p = Plan(mid, bname or ("단독주택" if style == "house" else "빌라 1층 집"), "bc", W, 13, "w", rnd, pools, region)
        elif style == "apt":
            p = Plan(mid, bname or "아파트 현관", "bk", 18, 12, "t", rnd, pools, region)
        elif style == "gov":
            p = Plan(mid, "주민센터 민원실", "bk", 22, 14, "t", rnd, pools, region)
        elif style == "shop":
            kind = SHOPS[(x * 7 + y * 13) % len(SHOPS)]
            nm = rnd.choice(SHOP_PRE) + rnd.choice(SHOP_SUF[kind])
            p = Plan(mid, nm, "jm", 16 + rnd.randint(0, 2), 12, ",", rnd, pools, region)
            p.shop_kind = kind
        elif style == "office":
            p = Plan(mid, bname or "사무실", "bk", 20, 12, "c", rnd, pools, region)
        else:
            p = Plan(mid, bname or "창고", "sb", 22, 13, "~", rnd, pools, region)
        p.door = (x, y + 1)
        p.pm = prop_meta
        if hh and not spec.get("collapsed"):
            p.hh = dict(hh, r=random.Random(_h(x, y, 1077, k)))         # 씨앗마다 새로(재시도해도 같은 집 · 같은 고름)
            p.ev = {}
            for sl, t in hh["lines"]:                                  # 훑기 방도 사건 줄을 놓고 리듬이 하나만 남긴다
                p.ev.setdefault(sl, []).append(t)
        if spec.get("collapsed"):
            got = tpl_collapsed(p)
        elif style in ("villa", "house"):
            got = tpl_den(p) if getattr(p, "den", False) else tpl_home(p, bath=p.W >= 26)
            if got == "den" and getattr(p, "hh", None) and hh["lines"]:      # 떠돌이 층 아래 살던 집 한 줄(층 ①)
                sl, t_ = hh["lines"][0]
                for (sx, sy) in p.spots(1, 4, p.W - 2, p.H - 4):
                    if p.free(sx, sy):
                        p.cmds.append(f"prop note_ground {sx} {sy}")
                        p.busy.add((sx, sy))
                        p.text(sx, sy, "벽지 틈에 끼어 남은 종이 한 장 — " + t_)
                        break
            if got == "home" and rnd.random() < 0.22:
                for (sx, sy) in p.spots(1, 4, p.W - 2, p.H - 3)[:1]:
                    if p.prop("remains", sx, sy):
                        p.text(sx, sy, p.line("home_remains"))
                        p.box(sx, sy, "corpse_scav", "유해")
            if got == "home" and (rnd.random() < 0.6 or p.ev.get("home_note")):
                for (sx, sy) in p.spots(1, 5, p.W - 2, p.H - 3)[:1]:
                    p.note(sx, sy, "home_note")
            layers = []
            if got == "home" and getattr(p, "hh", None):
                apply_rhythm(p)
                layers = add_layers(p, hh_src)
            elif got == "den" and getattr(p, "hh", None):
                p.hh = dict(p.hh, mode="den")
        elif style == "apt":
            tpl_apt(p)
        elif style == "gov":
            tpl_gov(p)
        elif style == "shop":
            tpl_shop(p, kind)
        elif style == "office":
            tpl_office(p)
        else:
            tpl_store(p)
        _traps(p, style, got if style in ("villa", "house") else style, threat)
        p.layers = layers if style in ("villa", "house") and got == "home" else []
        _place_enemies(p, threat, region, style if not spec.get("collapsed") else "collapsed")
        _rads(p, style, got if style in ("villa", "house") else style, threat)   # 맨 뒤: 앞선 배치(적 · 상자 · 글)를 바꾸지 않는다
        with tempfile.NamedTemporaryFile("w", suffix=".map", delete=False, encoding="utf-8") as f:
            f.write(p.source())
            path = f.name
        m = MC.MapSrc(path)
        os.unlink(path)
        out = MC.compile_map(m, prop_meta, known_vars, known_fns, scenes)
        if out is None or m.errors:
            if k == tries - 1 and spec.get("collapsed"):                  # 보통 틀이 다 실패하면 대체 틀로 다시 하니 그때만 알린다
                print("생성 실패", mid, m.errors[:2])
            continue
        if not _ok(out):
            continue
        out["region"] = region
        out["gen"] = style if not spec.get("collapsed") else "collapsed"
        if blabel:
            out["label"] = blabel                                      # 월드 문 안내(건물 이름)
        if getattr(p, "hh", None):                                     # 가구 요약(1-B3 문 앞 표식은 이 결과에서 뽑는다 — P1)
            f_ = hh["f"]
            people = [f_[k_] for k_ in ("아빠", "엄마", "할머니") if k_ in f_] + [f_["성"] + f_[k_] for k_ in ("아이", "아이2") if k_ in f_]
            if "원정" in f_:
                people.append(f_["성"] + f_["원정"].split()[-1])
            out["house"] = {"집": f_["집"], "kind": hh["kind"], "event": hh["event"],
                            "mode": p.hh["mode"], "layers": layers, "people": people}
        for e in out["exits"]:
            e.pop("line", None)
        for n in out["npcs"]:
            n.pop("line", None)
        return out
    if not spec.get("collapsed"):                                     # 1-B: 씨앗 12번이 다 실패하면 대체 틀로라도(무너져 막힌 1층)
        return build_one(dict(spec, collapsed=True), pools, prop_meta, known_vars, known_fns, scenes, tries=6, hh_src=hh_src, npc_names=npc_names)
    return None


def _setup():
    PROPS = os.path.join(ROOT, "game", "assets", "props")
    prop_meta = dict(json.load(open(os.path.join(PROPS, "s07_props.json")))["props"])
    prop_meta.update(json.load(open(os.path.join(PROPS, "r01_props.json")))["props"])
    PROP_NAMES.update(prop_meta.keys())
    from script_compile import ENGINE_VARS
    known_vars = set(json.load(open(os.path.join(ROOT, "game", "data", "vars.json")))["vars"]) | ENGINE_VARS
    known_fns = set(__import__("script_compile").FNS)                                          # 원고 함수 목록은 script_compile.FNS 한 곳(1-X — 컴파일러마다 따로 두면 새 함수를 모른다)
    scenes = set(json.load(open(os.path.join(ROOT, "game", "data", "dialogue", "_index.json")))["scenes"])
    return prop_meta, known_vars, known_fns, scenes


def _traps(p, style, got, threat):
    """함정 섞기(1-9c, SD-11 §9.2): 숨긴 함정은 길을 막지 않는다(발견하면 보이고, 웅크려 해체).
    떠돌이 소굴 = 철선 수류탄 다발 또는 덫(위협 3 이상이면 입구 지뢰도) · 아파트 현관 = 폭탄 택배함 · 가게·사무실·주민센터 = 부비트랩 자판기 ·
    창고 = 압력판 → 함정 산탄총 · 가스 누출 배관. 들어온 자리(문 위 두 칸)와 그 앞줄에는 놓지 않는다."""
    rnd, W, H = p.rnd, p.W, p.H
    ex = getattr(p, "ex", W // 2)
    keep = {(ex + i, H - 2) for i in (-1, 0, 1, 2)} | {(ex + i, H - 3) for i in (0, 1)}
    ok = lambda x, y: p.free(x, y) and (x, y) not in keep
    if got == "den":
        if rnd.random() < 0.65:
            y = H - 4
            for x0 in (ex - 1, ex, ex - 2):
                if all(ok(x0 + k, y) for k in range(3)):
                    p.cmds.append(f"trap wire {x0} {y} dir=E len=3")
                    break
        else:
            for (x, y) in p.spots(2, H - 6, W - 3, H - 4)[:1]:
                if ok(x, y):
                    p.cmds.append(f"trap bear {x} {y}")
        if rnd.random() < 0.3:
            for (x, y) in p.spots(1, 4, W - 2, 8)[:1]:
                if ok(x, y):
                    p.cmds.append(f"trap bear {x} {y}")
        if threat >= 3 and rnd.random() < 0.3:
            for (x, y) in p.spots(ex - 2, H - 6, ex + 3, H - 5)[:1]:
                if ok(x, y):
                    p.cmds.append(f"mine W-063 {x} {y}")
    elif style == "apt" and threat >= 1 and rnd.random() < 0.25:
        for (x, y) in p.spots(1, 3, W - 2, 3)[:1]:
            p.prop("trap_parcel", x, y)
    elif style in ("shop", "office", "gov") and threat >= 1 and rnd.random() < 0.12:
        for (x, y) in p.spots(1, 3, W - 2, 3)[:1]:
            p.prop("trap_vending", x, y)
    elif style not in ("villa", "house", "apt", "shop", "office", "gov"):       # 창고
        if threat >= 2 and rnd.random() < 0.25:
            for (x, y) in p.spots(5, 4, W - 6, H - 5):
                if not ok(x, y):
                    continue
                for dx, d in ((4, "W"), (-4, "E")):
                    if ok(x + dx, y) and all(p.isfloor(x + k * (1 if dx > 0 else -1), y) for k in range(1, 4)):
                        p.cmds.append(f"trap plate {x} {y} link=sg{x}")
                        p.cmds.append(f"trap shotgun {x + dx} {y} dir={d} id=sg{x}")
                        p.busy.add((x + dx, y))
                        break
                else:
                    continue
                break
        if rnd.random() < 0.2:
            for (x, y) in p.spots(1, 4, W - 2, H - 4)[:1]:
                if ok(x, y):
                    p.prop("gas_pipe", x, y)


def _rads(p, style, got, threat):
    """방사능 섞기(1-9d, SD-11 §11.2 · §9.2): 지대는 소품이 내는 선량으로 생긴다(웅덩이 Z1 · 폐기물 드럼 Z2 · 열린 차폐 용기 20라드/초).
    창고·소굴(위협 2 이상) 18% = 구석의 폐기물 드럼 + 흘러나온 웅덩이 · 위협 3 이상 창고·사무실·주민센터 12% = 차폐 용기 함정(앞 칸 압력판이 뚜껑을 연다).
    입구 줄에는 놓지 않는다 — 들어서자마자 피폭되는 방은 없다."""
    rnd = random.Random(hash(tuple(p.rnd.getstate()[1][:6])))             # 따로 굴린다 — 다른 배치(적 · 상자)의 난수를 건드리지 않게
    W, H = p.W, p.H
    ex = getattr(p, "ex", W // 2)
    keep = {(ex + i, y) for i in (-2, -1, 0, 1, 2, 3) for y in (H - 2, H - 3, H - 4)}
    store = got == "den" or style not in ("villa", "house", "apt", "shop", "office", "gov")
    roll = rnd.random()
    if store and threat >= 2 and roll < 0.18:
        corners = [(1, 3), (W - 2, 3), (1, H - 5), (W - 2, H - 5)]
        rnd.shuffle(corners)
        for (cx, cy) in corners:
            if (cx, cy) in keep or not p.free(cx, cy):
                continue
            p.prop("waste_drum", cx, cy)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if p.free(cx + dx, cy + dy) and (cx + dx, cy + dy) not in keep:
                    p.prop("rad_puddle" if rnd.random() < 0.5 else "rad_puddle2", cx + dx, cy + dy, solid=False)
                    break
            break
    elif (style in ("office", "gov") or store) and threat >= 3 and roll < 0.30:
        cand = [(x, y) for y in range(3, H - 5) for x in range(2, W - 2) if p.free(x, y)]
        rnd.shuffle(cand)
        for (x, y) in cand:
            if (x, y) in keep or not p.free(x, y + 1) or (x, y + 1) in keep:
                continue
            p.prop("rad_cask", x, y)
            p.cmds.append(f"trap radcask {x} {y} id=rc{x}")
            p.cmds.append(f"trap plate {x} {y + 1} link=rc{x}")
            p.busy.add((x, y + 1))
            break


def _h(*a):
    v = 2166136261
    for k in a:
        v = ((v ^ (int(k) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return v


DIR8 = ["동쪽", "남동쪽", "남쪽", "남서쪽", "서쪽", "북서쪽", "북쪽", "북동쪽"]
STASH_SPOT = ["계산대 밑", "창고 쪽 구석", "진열대 뒤", "뒷벽 선반 아래"]


def _free_cell(out, rnd, need_solid_free=True, avoid=()):
    """들어온 자리에서 닿는 빈 바닥 칸(소품·조사 글·용기·출구 없는 곳)을 하나 고른다."""
    m = out["marks"]["from_W"]
    seen = _reach(out, (m[0], m[1]))
    W, H = out["size"]
    busy = {(b["x"] + i, b["y"]) for b in out["boxes"] for i in range(b.get("w", 1))}
    busy |= {(t["x"] + i, t["y"] + j) for t in out["texts"] for i in range(t.get("w", 1)) for j in range(t.get("h", 1))}
    busy |= {(p_["x"], p_["y"]) for p_ in out["props"]}
    busy |= {(e["x"], e["y"]) for e in out["exits"]} | {(e["x"], e["y"] - 1) for e in out["exits"]}
    cells = [c for c in seen if c not in busy and c not in avoid and 3 <= c[1] <= H - 3]
    rnd.shuffle(cells)
    return cells


def _add_prop(out, prop_meta, name, x, y):
    pm = prop_meta[name]
    sort_y = y * 32 + 16 if pm["kind"] == "deco" else (y + max(pm["foot"][1], 1)) * 32
    out["props"].append({"name": name, "x": x, "y": y, "px": [x * 32 + pm["off"][0], y * 32 + pm["off"][1]], "sort_y": sort_y})
    if pm["kind"] == "floor":
        row = out["solid"][y]
        out["solid"][y] = row[:x] + "1" + row[x + 1:]


def stash_chains(outs, pools, prop_meta):
    """쪽지 따라가기(STAGE_1 §1.1 '탐험이 서사를 만든다'): 어떤 집·사무실의 쪽지가 이름 있는 가게 하나를 방위·거리로 가리키고,
    그 가게 안에 숨겨 둔 상자(용기 'stash', 일반 용기보다 한 단 두껍다)가 있다. 지도 표시는 없다 — 쪽지를 읽고 걸어서 찾는다."""
    import math
    rnd = random.Random(2077)
    src = [k for k, (o, _, st) in sorted(outs.items()) if st in ("villa", "house", "office") and o.get("gen") != "den"]
    cap = max(40, len(src) // 25)                                       # 1-B3: 건물 수에 비례(옛 40쌍 상한) · 3고리까지
    tgt = [k for k, (o, _, st) in sorted(outs.items()) if st == "shop"]
    rnd.shuffle(src)
    names = {}
    for k in tgt:                                                       # 이름이 겹치는 가게는 가리키지 않는다(헷갈린다) — 1-B: 전 권역이라 '쪽지 둘레 150칸 안에서' 하나뿐
        names.setdefault(outs[k][0]["name"], []).append(outs[k][1])
    used, n = set(), 0
    queue = [(k, 1) for k in src[:cap * 3 // 2]]
    while queue:
        s_id, depth = queue.pop(0)
        (so, (sx, sy), _) = outs[s_id]
        cand = []
        for t_id in tgt:
            to, (tx, ty), _ = outs[t_id]
            d = math.hypot(tx - sx, ty - sy)
            if t_id in used or t_id == s_id or not (25 <= d <= 90):
                continue
            if sum(1 for (ox, oy) in names[to["name"]] if math.hypot(ox - sx, oy - sy) <= 150) > 1:
                continue
            cand.append((d, t_id))
        if not cand:
            continue
        d, t_id = rnd.choice(cand)
        to, (tx, ty), _ = outs[t_id]
        ang = math.degrees(math.atan2(ty - sy, tx - sx))
        dname = DIR8[int(((ang + 22.5) % 360) // 45)]
        far = "골목 몇 개 건너" if d < 40 else ("큰길 하나 건너" if d < 65 else "한참 가서")
        spot = rnd.choice(STASH_SPOT)
        cells_t = _free_cell(to, rnd)
        cells_s = _free_cell(so, rnd)
        if not cells_t or not cells_s:
            continue
        placed = False
        for (cx, cy) in cells_t[:8]:                                       # 상자를 놓아도 다른 곳이 막히지 않아야 한다
            trial = json.loads(json.dumps(to))
            _add_prop(trial, prop_meta, "crate_army", cx, cy)
            trial["boxes"].append({"x": cx, "y": cy, "w": 1, "h": 1, "kind": "stash", "owner": "", "lock": 25 if rnd.random() < 0.4 else 0,
                                   "name": "숨겨 둔 상자", "cond": ""})
            jip = so.get("house", {}).get("집")
            box_t = (rnd.choice(pools.get("stash_box", ["국방색 상자."])).replace("{집}", jip) if jip and depth == 1
                     else "국방색 상자. 위에 덮은 방수포를 누가 일부러 반듯하게 접어 두었다.")
            trial["texts"].append({"x": cx, "y": cy, "w": 1, "h": 1, "text": box_t})
            if _ok(trial):
                outs[t_id] = (trial, (tx, ty), "shop")
                placed = True
                break
        if not placed:
            continue
        pool = pools.get("stash_note" if depth == 1 else "stash_next", ["'{가게} {곳}. 여기서 {dir}으로 {far}.'"])
        kids = so.get("house", {}).get("kind") == "가족" and any("아이" in t["text"] for t in so["texts"])
        pool = [q for q in pool if kids or "아이" not in q and "아빠" not in q] or pool   # 아이 없는 집에 아이 글씨 쪽지는 없다
        line = rnd.choice(pool)
        line = line.replace("{가게}", to["name"]).replace("{곳}", spot).replace("{dir}", dname).replace("{far}", far)
        (cx, cy) = cells_s[0]
        _add_prop(so, prop_meta, "note_ground", cx, cy)
        so["texts"].append({"x": cx, "y": cy, "w": 1, "h": 1, "text": line})
        used.add(t_id)
        n += 1
        if depth < 3 and rnd.random() < 0.35:                          # 그 상자에서 다음 고리로(줄 맨 앞에 — 같은 사슬을 이어 만든다)
            queue.insert(0, (t_id, depth + 1))
        if n >= cap:
            break
    return n


SHOP_PLACE = {"conv": "conv", "pharm": "pharm", "hw": "hw", "laundry": "laundry", "snack": "snack", "tea": "tea", "salon": "salon",
              "video": "video", "karaoke": "karaoke"}
HARD_PROPS = ("rad_", "trap_", "gas_pipe")


def tag_loot(outs, thr):
    """파밍 v3 꼬리표(1-L 계획 §2 · §9.1): 용기마다 결(pl) · 위협(th) · 함정/방사능(hd) · 시간 층(ly) · 사건(ev) · 가리키는 곳(ld)을 붙인다.
    굴림은 게임이 판마다 한다(같은 판 같은 결과) — 생성기는 '어떤 곳인가'만 적는다. 가리키는 곳 = 25~90칸 안 가장 가까운 털이 소굴 · 최근 사람 집."""
    import math
    import loot_export as LE
    hubs = []
    for mid, (o, (x, y), st) in outs.items():
        hh = o.get("house") or {}
        if hh.get("mode") == "den" or "l3" in (hh.get("layers") or []):
            hubs.append((x, y, mid))
    n_ev = 0
    for mid, (o, (x, y), st) in outs.items():
        hh = o.get("house") or {}
        if o.get("gen") == "collapsed":
            pl = "collapsed"
        elif st in ("villa", "house"):
            pl = "den" if hh.get("mode") == "den" else "home"
        elif st == "shop":
            pl = SHOP_PLACE.get(SHOPS[(x * 7 + y * 13) % len(SHOPS)], "conv")
        else:
            pl = {"office": "office", "factory": "store", "gov": "gov", "apt": "apt"}.get(st, "home")
        hard = 1 if (o.get("traps") or any(str(p_["name"]).startswith(HARD_PROPS) for p_ in o["props"])) else 0
        ly = list(hh.get("layers") or [])
        best = None
        for (hx, hy, hid) in hubs:
            d = math.hypot(hx - x, hy - y)
            if hid != mid and 25 <= d <= 90 and (best is None or d < best[0]):
                best = (d, hx, hy)
        ld = []
        if best:
            ang = math.degrees(math.atan2(best[2] - y, best[1] - x))
            ld = [DIR8[int(((ang + 22.5) % 360) // 45)], "골목 몇 개 건너" if best[0] < 40 else ("큰길 하나 건너" if best[0] < 65 else "한참 가서")]
        ev = hh.get("event") if pl == "home" else None
        evd = LE.EVENTS.get(ev) if ev else None
        ev_kind = None
        if evd:
            have = [b["kind"] for b in o["boxes"]]
            ev_kind = next((k for k in evd[0] if k in have), None)
        ev_done = False
        for b in o["boxes"]:
            b["pl"], b["th"] = pl, int(thr.get(mid, 2))
            if hard:
                b["hd"] = 1
            if ly:
                b["ly"] = ly
            if ld:
                b["ld"] = ld
            if ev_kind and b["kind"] == ev_kind and (evd[3] or not ev_done):
                b["ev"] = ev
                ev_done = True
        n_ev += 1 if ev_done else 0
    return n_ev


# 일반 장사꾼(1-L 계획 §4.1 · §9.2): 결 있는 장사꾼은 권역마다 결 하나당 둘까지(같은 결끼리 150칸 넘게 떨어져) · 떠돌이는 최근 사람 집(층 ③)에
# 권역마다 여섯까지(장사꾼끼리 100칸 넘게). 적 · 함정 · 방사능 · 숨겨 둔 상자가 있는 실내는 고르지 않는다. 가게의 용기는 그 장사꾼 것이 된다(꺼내면 절도).
TRADE_KIND = {"hw": "scrap", "pharm": "herb", "video": "parts", "karaoke": "parts", "laundry": "cloth", "salon": "cloth",
              "snack": "food", "conv": "food", "tea": "food"}
TRADE_LOOK = {"scrap": ["M1-S3-HR04-H1-T11-0-PF11-HD00-EY00", "M2-S4-HR01-H1-T05-1-PF12-HD05-EY00", "M1-S3-HR02-H1-T05-1-PF12-HD02-EY00"],
              "herb": ["F1-S4-HR06-H2-T05-1-PF12-HD00-EY00", "E1-S3-HR04-H3-T03-2-PF12-HD00-EY00-PR011", "F1-S2-HR06-H2-T04-2-PF12-HD00-EY00-PR011"],
              "parts": ["M1-S2-HR01-H1-T03-2-PF00-HD05-EY00-PR040", "M2-S5-HR03-H2-T10-2-PF00-HD00-EY00-PR040", "M2-S3-HR01-H1-T03-1-PF00-HD05-EY00"],
              "cloth": ["F2-S4-HR05-H1-T06-2-PF12-HD03-EY00-PR041", "F1-S3-HR02-H1-T06-2-PF12-HD03-EY00-PR041", "M1-S3-HR02-H1-T04-2-PF12-HD00-EY00-PR011"],
              "food": ["E1-S3-HR04-H3-T03-2-PF12-HD00-EY00-PR011", "M2-S3-HR03-H3-T11-2-PF12-HD00-EY00-PR013", "F1-S4-HR06-H2-T05-1-PF12-HD00-EY00"],
              "drift": ["M2-S4-HR01-H1-T03-2-PF00-HD05-EY00", "M1-S4-HR01-H1-T06-2-PF12-HD03-EY00-PR041", "F2-S2-HR06-H2-T14-0-PF10-HD14-EY00-PR017"]}
TRADE_TEXT = {"scrap": "담요 위에 고철이 무게별로 쌓였다. 저울 접시에 녹슨 볼트 셋.", "herb": "말린 풀 다발과 약병. 병마다 손글씨 — '열' · '배' · '라드'.",
              "parts": "진공관이 솜에 싸여 줄지어 있다. 전지 상자 하나는 뚜껑이 열렸다.", "cloth": "개켜 둔 옷가지. 옷마다 실로 꿰맨 값표.",
              "food": "솥에서 김이 오른다. 국 냄새 — 무엇을 끓였는지는 묻지 않는 게 낫다.", "drift": "잡동사니를 늘어놓은 담요. 하나도 같은 물건이 없다."}
TRADE_BARK = {"scrap": "고철은 무게, 연장은 쓸모.", "herb": "아프면 와. 안 아파도 와.", "parts": "진공관 깨지지 않게 들고 와.",
              "cloth": "입던 옷도 받아.", "food": "한 그릇 하고 가.", "drift": "구경은 공짜."}
TRADE_SIGN = {"scrap": "판자 간판 '고철'. 문틈으로 등불 빛이 샌다 — 안에 사람이 있다.", "herb": "판자 간판 '약초'. 마른 풀 냄새가 문 밖까지 난다.",
              "parts": "판자 간판 '부품'. 안에서 무언가를 두드리는 소리.", "cloth": "판자 간판 '헌옷'. 문고리에 옷걸이가 줄줄이 걸렸다.",
              "food": "판자 간판 '국밥'. 연기가 문틈으로 나온다.", "drift": "판자 간판 '잡화'. 누가 여기 자리를 폈다."}

# 가게마다 다른 목소리(1-L 재미 검수 ②): 그 집이 원래 무엇이었나(거래 창 인사) · 권역 한 줄(머리 위 말). 사람 · 장소 이름은 대지 않는다(P1)
TRADE_FORMER = {"conv": ["편의점 자리야. 냉장고는 비어도 문은 잠겨.", "번개24 간판은 그대로 뒀어. 사람들이 그걸 보고 와."],
                "pharm": ["약국 선반은 내가 다 닦았어. 약은 없고.", "약국 자리라 아픈 사람이 먼저 와."],
                "hw": ["철물점 자리라 못은 넉넉해.", "공구 벽은 원래 주인이 걸어 둔 그대로야."],
                "laundry": ["빨래방 자리야. 세탁기는 이제 옷장이지.", "물만 있으면 빨래도 해 줄 텐데."],
                "snack": ["분식집 솥은 원래 있던 거야.", "떡볶이 냄새? 벽에 밴 거야. 떡은 없어."],
                "tea": ["다방 자리라 커피 냄새가 배어 있어. 커피는 없어.", "다방 의자는 푹신해. 앉아도 돼, 사면."],
                "salon": ["미용실 거울은 안 깼어. 손님이 제 얼굴 보고 사.", "가위는 안 팔아. 그건 내 거."],
                "video": ["비디오 가게였어. 테이프는 다 뜯어 부품 했지.", "포스터 속 배우는 이제 아무도 몰라."],
                "karaoke": ["노래방 기계 속 진공관이 쓸 만했어.", "방음벽이라 밤에 조용해. 그래서 여기 앉았어."],
                "house": ["이 집 주인? 나야. 사흘째. 내일은 모르고.", "주인이 돌아오면 비켜 줄 거야. 아직은 안 왔어.", "자리 깔 데가 여기밖에 없더라."]}
TRADE_REGION = {"R01": ["산바람 불면 장사 접어.", "계단 동네 사람들은 값을 깎아.", "산 쪽은 밤에 가지 마."],
                "R02": ["굴뚝 쪽 물은 마시지 마.", "강바람에 쇠가 빨리 녹아.", "철길 따라오면 금방이야."]}


def _place_trader(o, kind, prop_meta, rnd):
    """실내 하나에 장사꾼 · 담요 자리 · 글을 놓는다(들어온 자리에서 모든 것에 닿아야 — 안 되면 None)."""
    m = o["marks"]["from_W"]
    W, H = o["size"]
    cells = [c for c in _free_cell(o, rnd) if 4 <= c[1] <= H - 4 and abs(c[0] - m[0]) + abs(c[1] - m[1]) >= 4]
    pm = prop_meta["trade_mat_lt"]
    for (nx, ny) in cells[:14]:
        for mx in (nx + 1, nx - 2):
            if mx < 1 or mx + 1 > W - 2:
                continue
            if any(o["solid"][ny][xx] != "0" for xx in (mx, mx + 1)):
                continue
            trial = json.loads(json.dumps(o))
            for xx in (mx, mx + 1):
                trial["solid"][ny] = trial["solid"][ny][:xx] + "1" + trial["solid"][ny][xx + 1:]
            row = trial["solid"][ny]
            trial["solid"][ny] = row[:nx] + "1" + row[nx + 1:]                # 장사꾼이 선 칸도 막힌 셈 치고 닿는지 본다
            if not _ok(trial):
                continue
            trial["solid"][ny] = row                                         # 사람 칸은 길에서 막지 않는다(실행 중 인물이 막는다)
            trial["props"].append({"name": "trade_mat_lt", "x": mx, "y": ny, "px": [mx * 32 + pm["off"][0], ny * 32 + pm["off"][1]],
                                   "sort_y": (ny + 1) * 32})
            trial["texts"].append({"x": mx, "y": ny, "w": 2, "h": 1, "text": TRADE_TEXT[kind]})
            look = TRADE_LOOK[kind][rnd.randrange(len(TRADE_LOOK[kind]))]
            nid = "N-VG-" + {"scrap": "S1", "herb": "H1", "parts": "P1", "cloth": "C1", "food": "F1", "drift": "D1"}[kind]
            trial["npcs"].append({"id": nid, "x": nx, "y": ny, "dir": "S", "route": [], "cond": "", "bark": TRADE_BARK[kind],
                                  "look": look, "sheet": "st_look_" + look.lower().replace("-", "_")})
            for b in trial["boxes"]:
                b["owner"] = nid                                            # 이제 그 사람 가게다
            trial["trader"] = kind
            return trial
    return None


def place_traders(outs, doors, reach):
    import math
    prop_meta = _setup()[0]
    rnd = random.Random(1102)
    by_door = {d["to"]: d for d in doors}
    placed = {}                                                          # 맵 → (결, x, y, 권역)
    voice = {}                                                           # 맵 → 그 가게 인사(원래 무엇이었나)

    def clean(o):
        return not o["enemies"] and not o.get("traps") and not any(b["kind"] == "stash" or b.get("hd") for b in o["boxes"])

    def far_from(x, y, reg, kinds, dmin):
        return all(math.hypot(x - px, y - py) >= dmin for (k, px, py, r) in placed.values() if r == reg and (kinds is None or k in kinds))

    def put(mid, kind):
        o, (x, y), st = outs[mid]
        t = _place_trader(o, kind, prop_meta, random.Random(_h(x, y, 1102)))
        if t is None:
            return False
        outs[mid] = (t, (x, y), st)
        placed[mid] = (kind, x, y, o.get("region"))
        lr = random.Random(_h(x, y, 1103))
        former = SHOPS[(x * 7 + y * 13) % len(SHOPS)] if st == "shop" else "house"
        voice[mid] = lr.choice(TRADE_FORMER[former])
        reg_l = TRADE_REGION.get(o.get("region"), [])
        if reg_l and lr.random() < 0.6:
            for n in t["npcs"]:
                if n["id"].startswith("N-VG-"):
                    n["bark"] = lr.choice(reg_l)                            # 같은 결이라도 동네 말이 다르다
        d = by_door.get(mid)
        if d:
            d["name"] = o["name"] + " — 장사 함"
            for dx in (1, -1):
                if 0 <= x + dx < reach.shape[1] and reach[y + 1, x + dx]:
                    d["sign"], d["sign_prop"], d["sign_at"], d["sign_text"] = "trade", "tboard_" + kind, [x + dx, y + 1], TRADE_SIGN[kind]
                    break
        return True
    order = sorted(outs, key=lambda k: zlib.crc32(k.encode()))
    for kind in ("scrap", "herb", "parts", "cloth", "food"):
        per = {}
        for mid in order:
            o, (x, y), st = outs[mid]
            if st != "shop" or TRADE_KIND.get(SHOPS[(x * 7 + y * 13) % len(SHOPS)]) != kind or not clean(o) or mid in placed:
                continue
            reg = o.get("region")
            if per.get(reg, 0) >= 2 or not far_from(x, y, reg, {kind}, 150):
                continue
            if put(mid, kind):
                per[reg] = per.get(reg, 0) + 1
    per = {}
    for mid in order:
        o, (x, y), st = outs[mid]
        if "l3" not in ((o.get("house") or {}).get("layers") or []) or not clean(o) or mid in placed:
            continue
        reg = o.get("region")
        if per.get(reg, 0) >= 6 or not far_from(x, y, reg, None, 100):
            continue
        if put(mid, "drift"):
            per[reg] = per.get(reg, 0) + 1
    out = {mid: {"kind": k, "at": [x, y], "region": r, "greet": voice.get(mid, "")} for mid, (k, x, y, r) in sorted(placed.items())}
    json.dump(out, open(os.path.join(ROOT, "game", "data", "world", "traders.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    hide = {"den": [], "quiet": []}                                      # UQ-125 털이꾼이 자루를 두는 소굴 · 아이가 숨는 조용한 빈집(적 없음 · 장사꾼 없음)
    for mid, (o, (x, y), st) in sorted(outs.items()):
        if mid in placed:
            continue
        hh = o.get("house") or {}
        if hh.get("mode") == "den":
            hide["den"].append([mid, x, y, o.get("region")])
        elif st in ("villa", "house") and not o["enemies"] and not o.get("traps") and o.get("gen") != "collapsed":
            hide["quiet"].append([mid, x, y, o.get("region")])
    json.dump(hide, open(os.path.join(ROOT, "game", "data", "world", "hideouts.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    return out


def neighbor_links(outs, prop_meta):
    """이웃 고리(1-B3 · 설계안 §7.2): 같은 굽기에서 양쪽을 쓴다 — 한쪽만 있는 고리는 없다(P1).
    ① '가게 외상' 집의 '구멍가게'를 40칸 안 가장 가까운 동네 가게 이름으로 바꾸고, 그 가게 바닥에 그 집 외상 장부 한 장.
    ② '이웃 맡긴 열쇠' 집의 윗집 {이웃}이 30칸 안에 실제로 있으면, 그 집에 '열쇠는 아랫집 ○씨네에' 쪽지."""
    import math
    rnd = random.Random(1123)
    shops = [(k, xy) for k, (o, xy, st) in sorted(outs.items()) if st == "shop" and any(o["name"].endswith(t) for t in ("슈퍼", "상회", "마트"))]
    homes = {k: (o, xy) for k, (o, xy, st) in sorted(outs.items()) if o.get("house")}
    by_jip = {}
    for k, (o, xy) in homes.items():
        by_jip.setdefault(o["house"]["집"], []).append((k, xy))
    n1 = n2 = 0
    for k, (o, (x, y)) in homes.items():
        ev = o["house"].get("event")
        if ev == "가게 외상" and any("구멍가게" in t["text"] for t in o["texts"]):
            best = min(((math.hypot(sx - x, sy - y), sk) for sk, (sx, sy) in shops), default=None)
            if best and best[0] <= 40:
                so = outs[best[1]][0]
                cells = _free_cell(so, rnd)
                if cells:
                    cx, cy = cells[0]
                    for t in o["texts"]:
                        t["text"] = t["text"].replace("구멍가게", so["name"])
                    _add_prop(so, prop_meta, "note_ground", cx, cy)
                    so["texts"].append({"x": cx, "y": cy, "w": 1, "h": 1,
                                        "text": "계산대에서 떨어진 외상 장부 한 장. '%s — 쌀 반 말 · 라면 한 상자. 25일까지.' 그 아래 줄은 비었다." % o["house"]["집"]})
                    n1 += 1
        if ev == "이웃 맡긴 열쇠":
            nb = [line for line in o["texts"] if "윗집" in line["text"]]
            for jip, lst in by_jip.items():
                if not nb or not any(jip in t["text"] for t in nb):
                    continue
                cand = [(math.hypot(hx - x, hy - y), hk) for hk, (hx, hy) in lst if hk != k and math.hypot(hx - x, hy - y) <= 30]
                if not cand:
                    continue
                ho = outs[min(cand)[1]][0]
                cells = _free_cell(ho, rnd)
                if cells:
                    cx, cy = cells[0]
                    _add_prop(ho, prop_meta, "note_ground", cx, cy)
                    ho["texts"].append({"x": cx, "y": cy, "w": 1, "h": 1,
                                        "text": "문틈에 끼운 쪽지. '여행 다녀올게요. 열쇠는 아랫집 %s에. 화분 부탁해요.'" % o["house"]["집"]})
                    n2 += 1
                break
    return n1, n2


_CTX = {}                                                              # 병렬 일꾼이 물려받는 재료(fork)


def _work(spec):
    c = _CTX
    return build_one(spec, c["pools"], c["prop_meta"], c["known_vars"], c["known_fns"], c["scenes"], hh_src=c["hh"], npc_names=c["npc_names"])


def _gen_key(prop_meta):
    """캐시 열쇠: 생성기 판 · 생성기 · 맵 변환기 · 사연 글 · 소품 자료가 같으면 같은 문 = 같은 실내."""
    import hashlib
    hs = hashlib.sha1(str(GEN_VER).encode())
    for f in [os.path.abspath(__file__), os.path.join(os.path.dirname(os.path.abspath(__file__)), "map_compile.py"), ROOMS, HOUSE]:
        hs.update(open(f, "rb").read())
    hs.update(json.dumps(prop_meta, sort_keys=True, default=str).encode())
    return hs.hexdigest()


def _build_all(specs, pools, prop_meta, known_vars, known_fns, scenes, log=print):
    """건물마다 독립 — 지난 결과 캐시(_cache/gen_cache.bin) · 나머지는 여러 프로세스로(1-B, 7천여 곳)."""
    import pickle, multiprocessing as mp, time
    t0 = time.time()
    key = _gen_key(prop_meta)
    cpath = os.path.join(os.path.dirname(CACHE), "gen_cache.bin")
    old = {}
    if os.path.exists(cpath):
        try:
            d = pickle.loads(zlib.decompress(open(cpath, "rb").read()))
            if d.get("key") == key:
                old = d["outs"]
        except Exception:
            old = {}
    sk = lambda sp: "%d,%d,%s,%d,%s" % (sp["x"], sp["y"], sp["style"], sp["threat"], sp["region"])
    need = [sp for sp in specs if sk(sp) not in old]
    npcs = json.load(open(os.path.join(ROOT, "game", "data", "npcs.json"), encoding="utf-8"))["npcs"]
    _CTX.update(pools=pools, prop_meta=prop_meta, known_vars=known_vars, known_fns=known_fns, scenes=scenes, hh=read_households(),
                npc_names=frozenset(v.get("name", "") for v in npcs.values()))
    if len(need) > 40:
        with mp.get_context("fork").Pool(max(1, (os.cpu_count() or 2))) as pool:
            res = pool.map(_work, need, chunksize=16)
    else:
        res = [_work(sp) for sp in need]
    for sp, out in zip(need, res):
        old[sk(sp)] = out
    open(cpath, "wb").write(zlib.compress(pickle.dumps({"key": key, "outs": old}), 6))
    log("실내 생성: %d곳(새로 %d · 캐시 %d) %.0f초" % (len(specs), len(need), len(specs) - len(need), time.time() - t0))
    import copy
    return [copy.deepcopy(old[sk(sp)]) for sp in specs]                # 쪽지 사슬이 고쳐 쓰므로 캐시와 떼어 둔다


def run(entries, reach, threat, region_at, taken, log=print, cache=True, fixed=()):
    """entries: 굽기가 찍은 건물 문 후보 [{x, y, style, seed}] · reach[y, x] · threat(청크) · region_at(x, y) → 권역 코드 ·
    taken: 비워 둘 칸 사각형(손 맵·지하 문). 돌려줌: 월드 문 목록(kind 'facade')."""
    if cache:                                                          # 따로 다시 돌릴 수 있게 후보·문 앞 칸·위협·권역을 남긴다
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        H_, W_ = reach.shape
        front = [[e["x"] + dx, e["y"] + 1] for e in entries for dx in (-1, 0, 1)            # 문 앞 칸 + 양옆(1-B3 표식 자리)
                 if e["y"] + 1 < H_ and 0 <= e["x"] + dx < W_ and reach[e["y"] + 1, e["x"] + dx]]
        reg = [[region_at(cx * 40, cy * 40) for cx in range(W_ // 40)] for cy in range(H_ // 40)]
        json.dump({"W": W_, "H": H_, "entries": entries, "front": front, "threat": threat, "region": reg, "taken": [list(t) for t in taken],
                   "fixed": list(fixed)},
                  open(CACHE, "w", encoding="utf-8"), default=int)
    pools = read_pools()
    prop_meta, known_vars, known_fns, scenes = _setup()
    for f in glob.glob(os.path.join(OUT, "G-*.json")):
        os.remove(f)
    doors, made, cnt = [], {}, {}
    outs = {}
    used = set()
    for spec in fixed:                                                 # 손으로 만든 실내: 요청 자리에서 가장 가까운, 문 앞이 걸어서 닿는 1층 문
        nx, ny = spec["near"]
        best = None
        for e in entries:
            if e["y"] + 1 < reach.shape[0] and reach[e["y"] + 1, e["x"]] and (e["x"], e["y"]) not in used:   # 한 장소에 문이 둘이면 서로 다른 1층 문(1-D3 독산)
                dd = (e["x"] - nx) ** 2 + (e["y"] - ny) ** 2
                if dd <= 30 * 30 and (best is None or dd < best[0]):
                    best = (dd, e)
        if best is None:
            raise SystemExit("손 실내 문 자리를 못 찾았다: %s" % spec)
        e = best[1]
        used.add((e["x"], e["y"]))
        doors.append({"lid": spec["lid"], "at": [e["x"], e["y"]], "to": spec["to"], "mark": spec.get("mark", "from_W"), "name": spec["name"],
                      "prop": "", "kind": "facade", "lock": int(spec.get("lock", 0))})
        for k in ("hint", "hints", "open"):                              # 밖에서 읽는 안의 상태(1-D3 — 파리 소리 · 정리 · 녹음)
            if spec.get(k):
                doors[-1][k] = spec[k]
    todo = []                                                          # 1-B: 먼저 고르고(순서 그대로) → 병렬 · 캐시로 만든다
    for e in entries:
        x, y, st = e["x"], e["y"], e["style"]
        if (x, y) in used:
            continue
        rg = region_at(x, y)
        if rg not in REGIONS or st not in RATE:
            continue
        if not reach[y + 1, x]:
            continue
        if any(ox - 2 <= x < ox + ow + 2 and oy - 2 <= y < oy + oh + 2 for (ox, oy, ow, oh) in taken):
            continue
        if (_h(e["seed"], 77) % 1000) / 1000.0 >= RATE[st]:
            continue
        cx, cy = x // 40, y // 40
        t = threat[cy][cx] if cy < len(threat) and cx < len(threat[cy]) else "1"
        t = int(t) if str(t).isdigit() else 1
        todo.append((e, {"x": x, "y": y, "style": st, "threat": t, "region": rg}))
    built = _build_all([sp for _, sp in todo], pools, prop_meta, known_vars, known_fns, scenes, log)
    thr = {}
    for (e, sp), out in zip(todo, built):
        x, y, st = sp["x"], sp["y"], sp["style"]
        if out is None:
            continue
        outs[out["id"]] = (out, (x, y), st)
        thr[out["id"]] = sp["threat"]
        made[out["id"]] = {"name": out["name"], "size": out["size"], "exits": ["W"]}
        lock = 0
        hv = _h(e["seed"], 91) % 100
        if st in ("villa", "house", "office", "factory") and hv < 18:
            lock = 25 if hv < 12 else 50
        label = out.get("label") or {"villa": "빌라 현관", "house": "대문", "apt": "아파트 현관", "gov": "주민센터", "shop": out["name"],
                                     "office": "사무동 출입문", "factory": "창고 셔터"}[st]
        door = {"lid": "", "at": [x, y], "to": out["id"], "mark": "from_W", "name": label, "prop": "", "kind": "facade", "lock": lock}
        sg = door_sign(out, e["seed"])
        if sg:
            for dx in (1, -1):                                         # 문 앞 발판 옆 칸(걸어서 닿는 바닥)
                if 0 <= x + dx < reach.shape[1] and reach[y + 1, x + dx]:
                    lines = pools.get("sign_" + sg, [""])
                    door["sign"], door["sign_at"] = sg, [x + dx, y + 1]
                    door["sign_text"] = lines[_h(e["seed"], 137) % len(lines)]
                    cnt["sign:" + sg] = cnt.get("sign:" + sg, 0) + 1
                    break
        doors.append(door)
        cnt[st] = cnt.get(st, 0) + 1
    n_stash = stash_chains(outs, pools, prop_meta)
    n_nb = neighbor_links(outs, prop_meta)
    n_ev = tag_loot(outs, thr)                                         # 1-L: 쪽지 사슬 · 이웃 고리가 더한 용기까지 결 꼬리표
    log("파밍 v3 꼬리표: 실내 %d곳 · 사건 물건 %d집" % (len(outs), n_ev))
    tr = place_traders(outs, doors, reach)                             # 1-L §4.1 · §9.2 다시 문 연 가게
    tk = {}
    for v in tr.values():
        tk[(v["region"], v["kind"])] = tk.get((v["region"], v["kind"]), 0) + 1
    log("다시 문 연 가게: %d곳 (R01 %s · R02 %s)" % (len(tr), {k: n for (r, k), n in tk.items() if r == "R01"},
                                                     {k: n for (r, k), n in tk.items() if r == "R02"}))
    blob = bytearray()                                                 # 1-B: 낱장 JSON 대신 압축 묶음 하나(gen.bin — 실내마다 zlib, 월드 청크와 같은 방식)
    for mid in sorted(outs):
        raw = json.dumps(outs[mid][0], ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        z = zlib.compress(raw, 9)
        made[mid]["pack"] = [len(blob), len(z), len(raw)]
        blob += z
    open(os.path.join(OUT, "gen.bin"), "wb").write(bytes(blob))
    log("쪽지 따라가기(숨겨 둔 상자): %d쌍 · 이웃 고리 외상 %d · 열쇠 %d · 묶음 %.1fMB" % (n_stash, n_nb[0], n_nb[1], len(blob) / 1e6))
    idx_path = os.path.join(OUT, "_index.json")
    idx = json.load(open(idx_path, encoding="utf-8")) if os.path.exists(idx_path) else {"maps": {}}
    idx["maps"] = {k: v for k, v in idx["maps"].items() if not k.startswith("G-")}
    idx["maps"].update(made)
    json.dump(idx, open(idx_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    log("들어가는 건물: %d곳 (%s)" % (len(doors), ", ".join(f"{k} {v}" for k, v in sorted(cnt.items()))))
    return doors


def run_cached(log=print):
    """굽기 없이 다시 만든다(그림·원고·틀만 바꿨을 때): 마지막 굽기가 남긴 _cache/gen_entries.json을 쓰고, 월드 문 목록을 place_geo.json에 다시 넣는다."""
    import numpy as np
    c = json.load(open(CACHE, encoding="utf-8"))
    reach = np.zeros((c["H"], c["W"]), bool)
    for (x, y) in c["front"]:
        reach[y, x] = True
    reg = c["region"]

    def region_at(x, y):
        cy_, cx_ = y // 40, x // 40
        return reg[cy_][cx_] if 0 <= cy_ < len(reg) and 0 <= cx_ < len(reg[cy_]) else 0
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from world_chunks import DOORS                                     # 손 실내 문 목록은 굽기 파일이 정본(캐시보다 새것)
    fixed = [d for d in DOORS if d.get("kind") == "facade"]
    doors = run(c["entries"], reach, c["threat"], region_at, [tuple(t) for t in c["taken"]], log=log, cache=False, fixed=fixed)
    gp = os.path.join(ROOT, "game", "data", "world", "place_geo.json")
    geo = json.load(open(gp, encoding="utf-8"))
    for d in doors:
        if d.get("lid"):
            geo.setdefault(d["lid"], {"bank": "S", "arrive": None})["arrive"] = [d["at"][0], d["at"][1] + 1]
    geo["_doors"] = [d for d in geo["_doors"] if d.get("kind") != "facade"] + doors
    json.dump(geo, open(gp, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"), sort_keys=True, default=int)


if __name__ == "__main__":
    run_cached()
