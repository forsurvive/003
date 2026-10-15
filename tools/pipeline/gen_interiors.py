"""들어가 보는 건물(단계 1-5e 자유 탐험 확장, STAGE_1 §1.1 '자유도 = 탐험이 서사를 만든다').
월드 굽기가 찍은 건물 1층 문 타일(빌라·주택·아파트 현관·주민센터 문, 공장 셔터, 가게·사무동 정면 가운데) 가운데 일부를 '들어가는 문'으로 정하고,
건물 종류마다 실내 한 장을 씨앗으로 만들어 map_compile로 굽는다(맵 ID 'G-x-y', x·y = 문 칸 월드 좌표).
실내: 빌라·주택(부엌·거실·방, 주택은 욕실) · 아파트 현관(우편함·엘리베이터·경비실) · 주민센터 민원실 · 가게 다섯(구멍가게·약국·철물점·세탁소·분식집) ·
사무실 · 창고. 살림 소품 + 용기(SD-13 §9 용기 표, 권역 등급) + 2077-10-23 밤에 멈춘 사연 글(script/world/rooms.txt) + 위협도에 맞춘 벌레·쥐·구울.
문 일부는 잠겼다(자물쇠 25·50 — 1-5 자물쇠 따기). 실내에서 나오면 그 문 앞 칸으로 돌아간다(출구 표지 '@x,y').
권역: 1막(R01·R02)만. 다른 권역은 그 막 단계에서 연다.
"""
import os, sys, json, glob, random, tempfile, re
from collections import deque

sys.path.insert(0, os.path.dirname(__file__))
import map_compile as MC

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "data", "maps")
ROOMS = os.path.join(ROOT, "script", "world", "rooms.txt")
REGIONS = ("R01", "R02")
RATE = {"villa": 0.25, "house": 0.6, "apt": 0.5, "gov": 1.0, "shop": 0.16, "office": 0.6, "factory": 0.6}
SHOP_PRE = ["행복", "대박", "새마을", "온누리", "희망", "튼튼", "제일", "깔끔", "백조", "엄마손", "골목", "동네", "우리", "만물", "별빛", "꼬마",
            "한빛", "보람", "새벽", "무지개", "은하", "소망", "다정", "늘봄", "해뜨는", "형제", "삼거리", "언덕", "둥지", "단골"]
SHOP_SUF = {"conv": ["슈퍼", "상회", "마트"], "pharm": ["약국"], "hw": ["철물", "공구"], "laundry": ["세탁", "크리닝"], "snack": ["분식", "김밥"]}
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
        cand = [s for s in self.pools.get(pool, []) if s not in self.used]
        if not cand:
            return None
        s = self.rnd.choice(cand)
        self.used.add(s)
        return s.replace("{가게}", self.name)

    def text(self, x, y, s, w=1, h=1):
        if s:
            s = s.replace('"', "'")
            self.cmds.append(f'text {x} {y} "{s}"' + (f" w={w}" if w > 1 else "") + (f" h={h}" if h > 1 else ""))

    def note(self, x, y, pool):
        """바닥에 떨어진 쪽지: 종이 소품(밟고 지나갈 수 있다) + 조사 글. 맨바닥 글은 보이지 않아 찾을 수 없다."""
        s = self.line(pool)
        if s and self.free(x, y):
            self.cmds.append(f"prop note_ground {x} {y}")
            self.busy.add((x, y))
            self.text(x, y, s)

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
            p.text(xs, 3, p.line("home_fridge")) if rnd.random() < 0.5 else None
            xs += 1
    ty = rnd.randint(6, 7)
    tx = max(1, (xa - 2) // 2)
    if p.prop("dining_table", tx, ty, 2):
        p.text(tx, ty, p.line("home_table"), w=2)
    if rnd.random() < 0.6:
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


SHOPS = ["conv", "pharm", "hw", "laundry", "snack"]
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


def _place_enemies(p, threat, region):
    rnd = p.rnd
    if threat <= 1:
        roll = [("CR-002", 0.3, 1, 2)]
    elif threat == 2:
        roll = [("CR-095", 0.35, 1, 3), ("CR-002", 0.25, 1, 2)]
    else:
        roll = [("CR-200", 0.3 if region == "R02" else 0.15, 1, 2), ("CR-095", 0.35, 2, 3)]
    for eid, ch, lo, hi in roll:
        if rnd.random() < ch:
            far = [(x, y) for (x, y) in p.spots(1, 3, p.W - 2, p.H - 3) if abs(x - p.ex) + abs(y - (p.H - 2)) >= 6]
            for (x, y) in far[:rnd.randint(lo, hi)]:
                p.enemy(eid, x, y)
            break


def build_one(spec, pools, prop_meta, known_vars, known_fns, scenes, tries=6):
    """문 하나 → (맵 JSON, 이름) 또는 None. 씨앗이 맞지 않으면 다음 씨앗."""
    x, y, style, threat, region = spec["x"], spec["y"], spec["style"], spec["threat"], spec["region"]
    mid = f"G-{x}-{y}"
    for k in range(tries):
        rnd = random.Random((x * 73856093) ^ (y * 19349663) ^ (k * 83492791))
        if style in ("villa", "house"):
            den = threat >= 2 and rnd.random() < 0.18
            if den:
                p = Plan(mid, "버려진 집", "bc", 16, 12, "w", rnd, pools, region)
            else:
                bath = style == "house" and rnd.random() < 0.7
                W = (26 if bath else 22) + rnd.randint(0, 1)
                p = Plan(mid, "단독주택" if style == "house" else "빌라 1층 집", "bc", W, 13, "w", rnd, pools, region)
        elif style == "apt":
            p = Plan(mid, "아파트 현관", "bk", 18, 12, "t", rnd, pools, region)
        elif style == "gov":
            p = Plan(mid, "주민센터 민원실", "bk", 22, 14, "t", rnd, pools, region)
        elif style == "shop":
            kind = SHOPS[(x * 7 + y * 13) % len(SHOPS)]
            nm = rnd.choice(SHOP_PRE) + rnd.choice(SHOP_SUF[kind])
            p = Plan(mid, nm, "jm", 16 + rnd.randint(0, 2), 12, ",", rnd, pools, region)
        elif style == "office":
            p = Plan(mid, "사무실", "bk", 20, 12, "c", rnd, pools, region)
        else:
            p = Plan(mid, "창고", "sb", 22, 13, "~", rnd, pools, region)
        p.door = (x, y + 1)
        if style in ("villa", "house"):
            got = tpl_den(p) if p.name == "버려진 집" else tpl_home(p, bath=p.W >= 26)
            if got == "home" and rnd.random() < 0.22:
                for (sx, sy) in p.spots(1, 4, p.W - 2, p.H - 3)[:1]:
                    if p.prop("remains", sx, sy):
                        p.text(sx, sy, p.line("home_remains"))
                        p.box(sx, sy, "corpse_scav", "유해")
            if got == "home" and rnd.random() < 0.6:
                for (sx, sy) in p.spots(1, 5, p.W - 2, p.H - 3)[:1]:
                    p.note(sx, sy, "home_note")
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
        _place_enemies(p, threat, region)
        with tempfile.NamedTemporaryFile("w", suffix=".map", delete=False, encoding="utf-8") as f:
            f.write(p.source())
            path = f.name
        m = MC.MapSrc(path)
        os.unlink(path)
        out = MC.compile_map(m, prop_meta, known_vars, known_fns, scenes)
        if out is None or m.errors:
            if k == tries - 1:
                print("생성 실패", mid, m.errors[:2])
            continue
        if not _ok(out):
            continue
        out["region"] = region
        out["gen"] = style
        for e in out["exits"]:
            e.pop("line", None)
        for n in out["npcs"]:
            n.pop("line", None)
        return out
    return None


def _setup():
    PROPS = os.path.join(ROOT, "game", "assets", "props")
    prop_meta = dict(json.load(open(os.path.join(PROPS, "s07_props.json")))["props"])
    prop_meta.update(json.load(open(os.path.join(PROPS, "r01_props.json")))["props"])
    PROP_NAMES.update(prop_meta.keys())
    from script_compile import ENGINE_VARS
    known_vars = set(json.load(open(os.path.join(ROOT, "game", "data", "vars.json")))["vars"]) | ENGINE_VARS
    known_fns = {"karma", "aff", "quest", "stage", "result", "give", "take", "has", "caps", "xp", "wanted", "stat", "skill", "year"}
    scenes = set(json.load(open(os.path.join(ROOT, "game", "data", "dialogue", "_index.json")))["scenes"])
    return prop_meta, known_vars, known_fns, scenes


def _h(*a):
    v = 2166136261
    for k in a:
        v = ((v ^ (int(k) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return v


def run(entries, reach, threat, region_at, taken, log=print, cache=True):
    """entries: 굽기가 찍은 건물 문 후보 [{x, y, style, seed}] · reach[y, x] · threat(청크) · region_at(x, y) → 권역 코드 ·
    taken: 비워 둘 칸 사각형(손 맵·지하 문). 돌려줌: 월드 문 목록(kind 'facade')."""
    if cache:                                                          # 따로 다시 돌릴 수 있게 후보·문 앞 칸·위협·권역을 남긴다
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        H_, W_ = reach.shape
        front = [[e["x"], e["y"] + 1] for e in entries if e["y"] + 1 < H_ and reach[e["y"] + 1, e["x"]]]
        reg = [[region_at(cx * 40, cy * 40) for cx in range(W_ // 40)] for cy in range(H_ // 40)]
        json.dump({"W": W_, "H": H_, "entries": entries, "front": front, "threat": threat, "region": reg, "taken": [list(t) for t in taken]},
                  open(CACHE, "w", encoding="utf-8"), default=int)
    pools = read_pools()
    prop_meta, known_vars, known_fns, scenes = _setup()
    for f in glob.glob(os.path.join(OUT, "G-*.json")):
        os.remove(f)
    doors, made, cnt = [], {}, {}
    for e in entries:
        x, y, st = e["x"], e["y"], e["style"]
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
        out = build_one({"x": x, "y": y, "style": st, "threat": t, "region": rg}, pools, prop_meta, known_vars, known_fns, scenes)
        if out is None:
            continue
        json.dump(out, open(os.path.join(OUT, out["id"] + ".json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
        made[out["id"]] = {"name": out["name"], "size": out["size"], "exits": ["W"]}
        lock = 0
        hv = _h(e["seed"], 91) % 100
        if st in ("villa", "house", "office", "factory") and hv < 18:
            lock = 25 if hv < 12 else 50
        label = {"villa": "빌라 현관", "house": "대문", "apt": "아파트 현관", "gov": "주민센터", "shop": out["name"], "office": "사무동 출입문",
                 "factory": "창고 셔터"}[st]
        doors.append({"lid": "", "at": [x, y], "to": out["id"], "mark": "from_W", "name": label, "prop": "", "kind": "facade", "lock": lock})
        cnt[st] = cnt.get(st, 0) + 1
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
    doors = run(c["entries"], reach, c["threat"], region_at, [tuple(t) for t in c["taken"]], log=log, cache=False)
    gp = os.path.join(ROOT, "game", "data", "world", "place_geo.json")
    geo = json.load(open(gp, encoding="utf-8"))
    geo["_doors"] = [d for d in geo["_doors"] if d.get("kind") != "facade"] + doors
    json.dump(geo, open(gp, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"), sort_keys=True, default=int)


if __name__ == "__main__":
    run_cached()
