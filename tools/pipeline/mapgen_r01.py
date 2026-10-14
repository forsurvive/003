"""관악산 비탈·봉천 계단마을 맵 원고 생성기 (단계 0-10, SD-09a §L-R01-01 ②·§L-R01-03·§L-R01-09, SD-16 §6.5).
바깥 맵은 '계단식 단'으로 짠다: 단(테라스)마다 높이(타일 단위)가 있고, 단과 단 사이는 2타일 옹벽 또는 2층 건물 정면.
2층 건물은 아랫단에 서서 정면이 옹벽 자리를 채우고, 옥상이 윗단과 같은 높이(산동네 — 옥상이 윗골목 바닥이 된다).
층 사이는 계단·사다리로만 오간다(map_compile 높이 검사). 구조물 그림은 struct 명령(art/tools/struct_r01.py)으로 굽는다.
이 스크립트가 원고의 정본을 만든다(손으로 고치지 않는다): python3 tools/pipeline/mapgen_r01.py
맵: X-S07 관악산 비탈(볼트 앞) · X-BC 봉천 계단마을 · B-01 옥탑 이장실(+빌린 침대) · B-03 하숙자 약국."""
import os, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "maps", "r01")
_IDX = os.path.join(ROOT, "game", "data", "dialogue", "_index.json")
SCENES = set(json.load(open(_IDX, encoding="utf-8"))["scenes"]) if os.path.exists(_IDX) else set()


class X:
    """바깥 맵 원고."""

    def __init__(self, mid, name, w, h):
        self.id, self.name, self.w, self.h = mid, name, w, h
        self.g = [["T"] * w for _ in range(h)]
        self.lv = [["."] * w for _ in range(h)]
        self.cmds = []
        self.seed = 0

    # ---- 칸
    def fill(self, x0, y0, x1, y1, ch, level=None, only=None):
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                if only is not None and self.g[y][x] not in only:
                    continue
                self.g[y][x] = ch
                if level is not None:
                    self.lv[y][x] = str(level)

    def set(self, x, y, ch, level=None):
        self.g[y][x] = ch
        if level is not None:
            self.lv[y][x] = str(level)

    def c(self, s):
        self.cmds.append(s)

    def p(self, name, x, y, cond=None):
        self.c(f"prop {name} {x} {y}" + (f' cond="{cond}"' if cond else ""))

    def text(self, x, y, s, w=1, h=1, **kw):
        if "scene" in kw and kw["scene"] not in SCENES:
            print(f"  (장면 {kw['scene']} 아직 없음 — 조사 글만)")
            kw.pop("scene")
        extra = "".join(f' {k}="{v}"' if " " in str(v) else f" {k}={v}" for k, v in kw.items())
        self.c(f'text {x} {y} "{s}"' + (f" w={w}" if w > 1 else "") + (f" h={h}" if h > 1 else "") + extra)

    def struct(self, kind, x, y, w, h, **args):
        self.seed += 1
        a = json.dumps(args, ensure_ascii=False) if args else ""
        self.c(f"struct {kind} {x} {y} {w} {h} seed={self.seed}" + (f" args='{a}'" if a else ""))

    # ---- 구조물
    def wall(self, x0, x1, y_top, h=2, kind="wall", **args):
        """옹벽·암벽 정면(남쪽을 본다): 막힌 칸 + 그림. kind wall(콘크리트) · rock(화강암)."""
        self.fill(x0, y_top, x1, y_top + h - 1, "#" if kind == "wall" else "R")
        self.struct(kind, x0, y_top, x1 - x0 + 1, h, **args)

    def stairs(self, x0, x1, y_top, h, lo, hi, rail=False):
        """남북 계단(위 끝 y_top이 높은 쪽 hi, 아래 끝이 낮은 쪽 lo)."""
        for k, y in enumerate(range(y_top, y_top + h)):
            for x in range(x0, x1 + 1):
                self.set(x, y, "!" if rail and x == x0 else "=", hi - (k * (hi - lo)) // max(1, h))

    def building(self, x0, x1, y_face, fh, style, roof_rows=0, roof_level=None, roof_walk=True, doors=(), shop=None, name=None,
                 num=None, edges="new", paint="green", exits=(), windows=None):
        """건물: 정면 y_face..y_face+fh-1(막힘), 그 위 roof_rows줄 옥상(roof_walk면 걷는 칸, 높이 roof_level).
        doors = [(열(맵 x), 종류)] — exits에 있으면 그 문 칸이 출구(D)."""
        w = x1 - x0 + 1
        self.fill(x0, y_face, x1, y_face + fh - 1, "H")
        for (dx, kind) in doors:
            if dx in [e[0] for e in exits]:
                self.set(dx, y_face + fh - 1, "D", self.lv[y_face + fh][dx] if self.lv[y_face + fh][dx] != "." else 0)
        if roof_rows:
            self.fill(x0, y_face - roof_rows, x1, y_face - 1, "r" if roof_walk else "X", roof_level if roof_walk else None)
            self.struct("roof", x0, y_face - roof_rows, w, roof_rows, edges=edges, paint=paint)
        self.struct("facade", x0, y_face, w, fh, style=style, doors=[[dx - x0, k] for dx, k in doors],
                    **({"shop": [shop[0] - x0, shop[1] - x0, shop[2]]} if shop else {}), **({"name": name} if name else {}),
                    **({"num": num} if num else {}), **({"windows": windows} if windows else {}))
        for (dx, to, mark) in exits:
            self.c(f"exit {dx} {y_face + fh - 1} {to} {mark}")

    def trees(self, cells, kinds=("tree_pine", "tree_oak", "tree_pine2", "tree_maple", "tree_oak2")):
        """숲 가장자리: T 칸 가운데 일부에 나무(엇갈려 겹치게)."""
        k = 0
        for (x, y) in cells:
            if self.g[y][x] == "T" and (x * 7 + y * 13) % 3 != 1:
                self.p(kinds[(x * 3 + y * 5 + k) % len(kinds)], x, y)
                k += 1

    def text_src(self):
        out = [f"map {self.id} {self.name}", "set r01", "grid"]
        out += ["".join(r) for r in self.g]
        out += ["end", "levels"]
        out += ["".join(r) for r in self.lv]
        out += ["end"]
        out += self.cmds
        return "\n".join(out) + "\n"


def blob(m, cx, cy, rx, ry, ch, level, only=None):
    """둥근 얼룩 칸 채우기(가장자리를 칸 해시로 흔든다)."""
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            if 0 <= x < m.w and 0 <= y < m.h:
                q = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + (((x * 37 + y * 61) % 7) - 3) * 0.06
                if q <= 1.0 and (only is None or m.g[y][x] in only):
                    m.g[y][x] = ch
                    m.lv[y][x] = str(level)


def border_trees(m, depth=2, skip=()):
    cells = []
    for y in range(m.h):
        for x in range(m.w):
            if m.g[y][x] == "T" and (x, y) not in skip:
                cells.append((x, y))
    m.trees(cells)


# ================================================================================================ X-S07 관악산 비탈(볼트 앞)
def slope():
    W, H = 40, 42
    m = X("X-S07", "관악산 비탈", W, H)
    # 가운데 비탈(높이 2): 풀밭, 남쪽 볼트 데크(높이 0) 위로 계단
    m.fill(2, 18, 37, 39, ";", 2)
    # 듬성 풀·흙 얼룩(둥글고 들쭉날쭉하게)
    for (cx, cy, rx, ry) in ((6, 26, 3.2, 2.2), (24, 27, 2.6, 1.8), (12, 32, 1.8, 2.4), (32, 32, 3.0, 2.0), (8, 36, 2.4, 1.6),
                             (34, 25, 1.6, 1.2), (21, 20, 1.5, 1.0)):
        blob(m, cx, cy, rx, ry, ",", 2, only=(";",))
    # 흙길: 계단 위(19~20, 32)에서 북서로 굽어 돌계단(12~13, 16~17)까지
    path = [(19, 32), (19, 31), (19, 30), (18, 29), (18, 28), (17, 27), (16, 26), (15, 25), (14, 24), (14, 23), (13, 22), (13, 21),
            (13, 20), (13, 19), (13, 18)]
    for (x, y) in path:
        m.fill(x - 1, y, x + 1, y, ".", 2)
    m.fill(17, 31, 22, 32, ".", 2)
    # 볼트 절개(데크 높이 0): x 15~24, y 35~39 + 양옆 콘크리트 윗면, 북쪽 옹벽 2줄(33~34)에 계단
    m.fill(15, 35, 24, 39, "c", 0)
    m.fill(14, 33, 14, 39, "#")
    m.fill(25, 33, 25, 39, "#")
    m.struct("slab", 14, 33, 1, 7)
    m.struct("slab", 25, 33, 1, 7)
    m.wall(15, 18, 33, 2, "wall", outlets=False, vines=True)
    m.wall(21, 24, 33, 2, "wall", outlets=False, vines=True, posters=[[40, 26, 0]])
    m.stairs(19, 20, 33, 2, 0, 2)
    m.struct("deck_edge", 15, 35, 10, 1)
    m.fill(12, 40, 27, 41, "P")
    m.struct("portal", 12, 40, 16, 2)
    m.text(19, 39, "방폭문은 다시 굳게 닫혔다. 인터컴에는 잡음뿐이다.", w=2)
    m.c("mark start 19 31 N")
    m.c("mark from_vault 19 37 N")
    m.p("exit_terminal", 22, 31)
    m.text(22, 31, "출구 점검표 단말. 화면에 '전출 처리 완료 — S07-2258-0031'이 떠 있다.")
    # 전망바위(높이 4): 동쪽 위, 남쪽 암벽 2줄(22~23) + 서쪽 암벽 열(26), 돌계단(30, 22~23)
    m.fill(27, 4, 38, 21, ";", 4)
    blob(m, 32, 10, 4.0, 2.4, ",", 4, only=(";",)); blob(m, 29, 18, 2.0, 1.5, ",", 4, only=(";",))
    m.wall(26, 38, 22, 2, "rock")
    m.fill(26, 4, 26, 21, "R")
    m.struct("rock", 26, 4, 1, 18)
    m.stairs(30, 30, 22, 2, 2, 4)
    m.fill(30, 21, 30, 21, ".", 4)
    m.fill(29, 13, 36, 15, "p", 4)                                       # 반쯤 무너진 나무 데크
    m.struct("bridge", 29, 13, 8, 3, axis="v")
    m.p("telescope", 33, 13)
    m.text(33, 13, "동전 망원경. 캡 하나를 넣으면 돌아간다.", scene="X-S07_VIEW")
    m.p("info_board", 35, 15)
    m.text(35, 15, "2077년 안내판: '맑은 날에는 여의도 국회 돔과 남산 타워가 보입니다.' 돔은 무너졌고 탑은 그대로다.")
    m.c("mark view 33 14 N")
    # 북쪽 비탈 끝(높이 2 → 0): 바위 턱 띠(17) + 돌계단(12~13, 17)
    m.fill(2, 3, 25, 16, ";", 0)
    m.fill(2, 17, 11, 17, "~"); m.fill(14, 17, 25, 17, "~")
    m.struct("brink", 2, 17, 10, 1)
    m.struct("brink", 14, 17, 12, 1)
    m.stairs(12, 13, 17, 1, 2, 0)
    for (cx, cy, rx, ry) in ((6, 11, 2.6, 2.0), (19, 12, 3.0, 1.6), (9, 5, 1.6, 1.2)):
        blob(m, cx, cy, rx, ry, ",", 0, only=(";",))
    for (x, y) in [(12, 15), (12, 14), (13, 13), (13, 12), (14, 11), (14, 10), (14, 9), (13, 8), (13, 7), (13, 6), (14, 5), (14, 4),
                   (14, 3), (14, 2), (14, 1), (14, 0)]:
        m.fill(x - 1, y, x + 1, y, ".", 0)
    m.fill(13, 0, 15, 2, ".", 0)
    for x in (13, 14, 15):
        m.c(f"exit {x} 0 X-BC from_X-S07")
    m.c("mark from_X-BC 14 2 S")
    # 연수원 기숙사 폐허(북동, 높이 0): 무너진 2층 콘크리트 정면 + 잔해
    m.building(17, 23, 4, 2, "concrete", roof_rows=2, roof_walk=False, edges="nwe", paint="grey",
               windows=["dark", "broken", "board", "dark"], name="관악 연수원 생활관")
    m.text(20, 6, "관악 행정 연수원 생활관. 2077년 그날 밤, 연수생들이 4분 만에 볼트로 뛰어 내려갔다고 한다.", w=2)
    for (x, y, n) in ((16, 7, "rubble"), (24, 6, "rubble2"), (18, 8, "rubble"), (22, 8, "crate_o"), (25, 9, "rubble2")):
        m.p(n, x, y)
    # 덤불·바위·나무
    for (n, x, y) in (("boulder_m", 4, 21), ("boulder_s", 6, 23), ("boulder_l", 8, 25), ("bush_a", 10, 23), ("bush_g", 5, 30),
                      ("boulder_s", 11, 33), ("bush_g", 23, 27), ("bush_a", 26, 30), ("boulder_m", 29, 28), ("bush_y", 33, 31),
                      ("boulder_s", 35, 36), ("bush_g", 28, 36), ("tree_small", 9, 37), ("bush_a", 4, 36), ("boulder_s", 16, 21),
                      ("bush_g", 21, 21), ("tree_maple", 23, 19), ("tree_oak", 3, 19), ("boulder_m", 31, 6), ("bush_g", 29, 18),
                      ("bush_a", 36, 19), ("tree_pine", 37, 8), ("tree_ginkgo", 28, 5), ("boulder_s", 34, 10), ("tree_oak2", 4, 6),
                      ("bush_g", 8, 4), ("boulder_m", 18, 12), ("bush_a", 22, 11), ("tree_maple", 9, 10), ("boulder_s", 6, 14),
                      ("tuft", 17, 24), ("tuft2", 25, 33), ("tuft", 7, 32), ("tuft2", 33, 25), ("tuft", 20, 15), ("tuft2", 5, 8)):
        m.p(n, x, y)
    # S1 백구 장면 자리(바위틈): 서쪽 바위 무리. 길(12~16, 21~23)에 들어서면 장면이 열린다
    m.c("mark dogs 7 24 E")
    m.c("mark baekgu 6 26 E")
    m.c("mark dog1 8 23 W"); m.c("mark dog2 9 25 W"); m.c("mark dog3 8 27 W")
    m.c('trigger 12 21 scene=MQ-101_DOGS w=6 h=3 cond="MQ101_STAGE == 10 and MQ101_DOG == 0" once')
    border_trees(m)
    return m


# ================================================================================================ X-BC 봉천 계단마을
def facade_line(m, y_face, base, segs, roof_rows=2):
    """집 줄 하나(정면 2줄 y_face..y_face+1, 바로 위 roof_rows줄 = 윗단 높이 base+2의 옥상 띠).
    segs: (x0, x1, 종류, 인자) — 'bld'(건물: style·doors·shop·name·num·exits·roof_edges·paint) · 'wall'(옹벽) ·
    'stairs'(계단, rail) · 'gap'(틈: 정면·옥상 띠 모두 빈 골, 판자 다리 row) · 'yard'(옹벽 + 위는 텃밭 흙)."""
    top = base + 2
    for (x0, x1, kind, a) in segs:
        ry0, ry1 = y_face - roof_rows, y_face - 1
        if kind == "bld":
            m.building(x0, x1, y_face, 2, a.get("style", "brick"), roof_rows=roof_rows, roof_level=top, roof_walk=True,
                       doors=a.get("doors", ()), shop=a.get("shop"), name=a.get("name"), num=a.get("num"),
                       edges=a.get("edges", ""), paint=a.get("paint", "green"), exits=a.get("exits", ()), windows=a.get("windows"))
        elif kind in ("wall", "yard"):
            m.wall(x0, x1, y_face, 2, "wall", **a.get("wall", {}))
            if kind == "yard":
                m.fill(x0, ry0, x1, ry1, ".", top)
        elif kind == "stairs":
            m.stairs(x0, x1, y_face, 2, base, top, rail=a.get("rail", True))
        elif kind == "gap":
            m.fill(x0, ry0, x1, y_face + 1, "v")
            m.struct("gap", x0, ry0, x1 - x0 + 1, roof_rows + 2)
            if a.get("bridge") is not None:
                by = a["bridge"]
                m.fill(x0, by, x1, by, "p", top)
                m.struct("bridge", x0, by, x1 - x0 + 1, 1)


def bongcheon():
    W, H = 60, 46
    m = X("X-BC", "봉천 계단마을", W, H)
    # ---- 남부순환로(높이 0, 41~45줄)
    m.fill(0, 42, 59, 45, "_", 0)
    for x in range(1, 59, 4):
        m.set(x, 43, "-", 0); m.set(x + 1, 43, "-", 0)
    m.fill(0, 41, 59, 41, ":", 0)
    for y in (42, 43, 44, 45):
        m.c(f"exit 59 {y} X-S07 from_X-BC")
    m.c("mark from_X-S07 57 43 W")
    m.p("car_wreck", 8, 42); m.p("car_wreck2", 44, 43); m.p("bus_stop", 50, 41); m.p("jersey", 2, 44)
    m.p("streetlamp", 22, 41); m.p("utility_pole", 36, 41); m.p("rubble", 54, 45); m.p("rubble2", 17, 45)
    m.text(0, 43, "남부순환로 서쪽은 무너진 고가가 막고 있다.", h=3)
    # ---- 고철 장벽(39~40) + 아랫문(27~31)
    m.fill(4, 39, 55, 40, "S")
    m.fill(27, 39, 31, 40, ":", 0)
    m.struct("scrap", 4, 39, 52, 2, gate=[23, 27], banner=[33, 36, "봉천 새봄빌라 분양"])
    m.p("gate_l", 27, 40); m.p("gate_r", 31, 40)
    m.text(29, 39, "봉천 계단마을 아랫문. 고철 장벽에 분양 현수막을 덧댄 철판 문이다.")
    # ---- 1단 아래 마당(높이 0, 33~38줄)
    m.fill(9, 33, 55, 38, "c", 0)
    m.fill(9, 33, 18, 38, ".", 0)
    m.fill(40, 33, 55, 38, ".", 0)
    m.fill(27, 35, 31, 38, ":", 0)                                        # 계단참①(아랫문 안쪽)
    m.fill(28, 33, 31, 34, ":", 0)
    m.p("guard_booth", 33, 38); m.p("sandbags", 25, 38); m.p("stair_post", 32, 34)
    m.p("board_bc", 22, 35)
    m.text(22, 35, "반상회 게시판.", w=2, scene="X-BC_BOARD")
    m.p("kennel", 35, 34)
    m.text(35, 34, "백구 집. 옆 기둥에 '백구 밥 당번표'가 붙어 있다.", w=2)
    m.p("stall", 10, 34); m.p("scale", 13, 34); m.p("scrap_pile", 10, 37); m.p("scrap_pile2", 14, 37); m.p("crate_o", 16, 35)
    m.p("lp_gas", 17, 33); m.p("forge", 44, 34); m.p("anvil", 47, 35); m.p("drum_fire", 42, 37); m.p("tarp_pile", 51, 36)
    m.p("crate_o", 53, 34); m.p("planter_l", 20, 33); m.p("planter_p", 24, 33); m.p("planter_s", 38, 33); m.p("bench_o", 19, 37)
    m.p("utility_pole", 39, 36); m.p("drum", 54, 38); m.p("tree_small", 49, 33)
    # 서쪽 구석(하수구) — 고철 더미 줄(8)로 마당과 갈라 놓았다. 들어오는 길은 고물상 정면 사다리뿐(옥상길 끝)
    m.fill(4, 33, 7, 38, ".", 0)
    m.fill(8, 33, 8, 38, "o")
    for y in (33, 35, 37):
        m.p("rubble" if y % 2 else "rubble2", 8, y)
    m.p("manhole", 5, 36)
    m.text(5, 36, "하수구 맨홀. 마을 밖 배수로로 이어진다.", scene="X-BC_MANHOLE")
    m.p("drum", 4, 38)
    # ---- 집 줄 1(정면 31~32, 높이 0 → 옥상 띠 29~30 = 2단)
    m.fill(4, 26, 55, 30, "c", 2)                                         # 2단(골목 26~28 + 옥상 띠 29~30)
    facade_line(m, 31, 0, [
        (4, 12, "bld", dict(style="concrete", doors=[(10, "shutter")], name="오씨네 고물", edges="w")),
        (13, 13, "gap", dict(bridge=30)),
        (14, 19, "bld", dict(style="brick", doors=[(16, "steel")], num="7", paint="red")),
        (20, 27, "yard", dict(wall=dict(posters=[[30, 20, 0], [190, 22, 1]], paint=[[100, 32, "312계단", "P53"]]))),
        (28, 28, "wall", dict(wall=dict(outlets=False, vines=False))),
        (29, 30, "stairs", {}),
        (31, 32, "wall", dict(wall=dict(outlets=False, vines=False))),
        (33, 38, "bld", dict(style="plaster", doors=[(35, "steel")], num="6")),
        (39, 39, "gap", dict(bridge=29)),
        (40, 46, "bld", dict(style="brick_dk", doors=[(44, "steel")], name="행복주택", paint="grey")),
        (47, 55, "yard", dict(wall=dict(posters=[[100, 24, 3]]))),
    ])
    m.set(5, 31, "L", 1); m.set(5, 32, "L", 1); m.struct("ladder", 5, 31, 1, 2)   # 고물상 정면 사다리(옥상 → 하수구 구석)
    m.fill(27, 26, 32, 30, ":", 2)                                        # 계단참②(약국 앞)
    # ---- 집 줄 2(정면 24~25, 높이 2 → 옥상 띠 22~23 = 3단)
    m.fill(4, 19, 55, 23, "c", 4)
    facade_line(m, 24, 2, [
        (4, 10, "bld", dict(style="brick_dk", name="삼성빌라", edges="w")),
        (11, 11, "gap", dict(bridge=23)),
        (12, 18, "bld", dict(style="mint", doors=[(15, "steel")], num="5", paint="grey")),
        (19, 20, "yard", dict(wall=dict(outlets=False))),
        (21, 30, "bld", dict(style="tile", doors=[(22, "steel")], shop=(24, 29, "봉천약국"), exits=[(22, "B-03", "from_X-BC")])),
        (31, 32, "wall", dict(wall=dict(outlets=False, vines=False))),
        (33, 34, "stairs", {}),
        (35, 36, "wall", dict(wall=dict(outlets=False, vines=False))),
        (37, 44, "bld", dict(style="concrete", doors=[(41, "steel")], num="4", paint="red")),
        (45, 45, "gap", dict(bridge=22)),
        (46, 55, "yard", dict(wall=dict(posters=[[60, 20, 2]], paint=[[150, 30, "학교 ↑", "P44"]]))),
    ])
    m.c("mark from_B-03 22 26 S")
    m.set(5, 24, "L", 3); m.set(5, 25, "L", 3); m.struct("ladder", 5, 24, 1, 2)
    m.fill(31, 19, 37, 23, ":", 4)                                        # 계단참③(학교 앞)
    # ---- 집 줄 3(정면 17~18, 높이 4 → 옥상 띠 15~16 = 4단 꼭대기)
    m.fill(4, 4, 55, 16, "c", 6)
    facade_line(m, 17, 4, [
        (4, 9, "bld", dict(style="plaster", name="새봄빌라", edges="w")),
        (10, 16, "bld", dict(style="brick", doors=[(13, "steel")], num="3", paint="grey")),
        (17, 28, "yard", dict(wall=dict(posters=[[200, 22, 1]], paint=[[60, 30, "물 아껴 쓰자", "P44"]]))),
        (29, 30, "stairs", {}),
        (31, 32, "wall", dict(wall=dict(outlets=False, vines=False))),
        (33, 43, "bld", dict(style="mint", doors=[(38, "steel")], name="계단 학교", num="학")),
        (44, 55, "yard", {}),
    ])
    m.set(5, 17, "L", 5); m.set(5, 18, "L", 5); m.struct("ladder", 5, 17, 1, 2)
    m.text(38, 18, "계단 학교. 오늘은 수업이 없다.")
    for (x, y) in ((16, 32), (35, 32), (44, 32), (15, 25), (41, 25), (13, 18)):
        m.text(x, y, "문이 잠겨 있다.")
    # ---- 꼭대기(높이 6): 물탱크 마당·이장실 빌라·망루
    m.fill(4, 4, 19, 14, ".", 6)
    m.fill(4, 3, 55, 5, ";", 6)
    m.fill(27, 12, 33, 16, ":", 6)                                        # 계단참④(이장실 아래)
    for (x, y) in ((6, 7), (9, 7), (12, 7), (6, 10), (9, 10), (12, 10)):
        m.p("water_tank", x, y)
    m.text(9, 7, "마을 물탱크. 빌라 옥상 여섯 개 탱크를 관으로 이었다.", w=6, h=4)
    m.p("floor_hatch", 16, 11)
    m.text(16, 11, "녹슨 철판 뚜껑. 자물쇠가 걸려 있다. 아래로 사다리가 보인다.")
    m.p("watchtower", 48, 9)
    m.text(48, 9, "망루. 옥탑 감시조가 교대로 오른다.", w=2, h=2)
    m.p("planter_l", 41, 13); m.p("planter_s", 43, 13); m.p("drum", 52, 7); m.p("utility_pole", 20, 13)
    m.p("tree_ginkgo", 38, 6); m.p("tree_small", 54, 12); m.p("bush_g", 17, 5); m.p("bush_a", 53, 4)
    # 이장실 빌라(정면 10~11, 옥상 6~9 = 높이 8) + 옥상 철계단(34) + 옥탑방(정면 8, 지붕 6~7)
    m.building(22, 33, 10, 2, "brick", doors=[(25, "steel")], num="1", name="봉천 새마음빌라")
    m.fill(22, 6, 34, 9, "r", 8)
    m.struct("roof", 22, 6, 13, 4, edges="nwe")
    m.stairs(34, 34, 10, 2, 6, 8, rail=True)
    m.fill(35, 10, 35, 11, "#"); m.struct("wall", 35, 10, 1, 2, outlets=False, vines=False)
    m.fill(25, 6, 30, 7, "X")
    m.struct("roof", 25, 6, 6, 2, edges="nwe", paint="red")
    m.fill(25, 8, 30, 8, "H")
    m.struct("facade", 25, 8, 6, 1, style="plaster", doors=[[2, "steel"]], name="이장실")
    m.set(27, 8, "D", 8)
    m.c("exit 27 8 B-01 from_X-BC")
    m.c("mark from_B-01 27 9 S")
    m.p("water_tank_s", 33, 8); m.p("antenna", 23, 7); m.p("laundry_line", 31, 6)
    m.text(25, 11, "봉천 새마음빌라 1동. 옥상에 옥탑 이장실이 있다.")
    # ---- 사람들(낮). 밤(MQ101_NIGHT ≥ 1)에는 감시조만 남는다
    day = "MQ101_NIGHT == 0 or MQ101_RESULT != 0"
    m.c(f'npc N-R01-028 28 37 S cond="{day}"')                                       # 남태하 감시조장(아랫문)
    m.c(f'npc N-R01-026 11 33 S cond="{day}"')                                       # 오봉수(고물상 매대 뒤)
    m.c('npc C-015 37 35 W sheet=cr_baekgu_loco cond="MQ101_DOG != 1"')              # 백구(개집 앞)
    m.c(f'npc N-R01-034 38 34 W cond="{day}" route=kennel:38,34,6;yard:33,36,4')     # 남솔(백구 밥 당번)
    m.c(f'npc N-R01-029 16 28 S cond="{day}" route=garden:16,28,6;alley:24,28,4')   # 조담희(텃밭·반상회 총무)
    m.c(f'npc N-R01-030 46 35 W cond="{day}"')                                       # 남무진(대장간)
    m.c(f'npc N-R01-031 39 21 S cond="{day}" route=school:39,21,6;stair:33,22,3')   # 오해인(계단 학교)
    m.c(f'npc N-R01-033 52 37 W cond="{day}"')                                       # 엄태경(사냥꾼)
    m.c(f'npc N-R01-035 30 29 S cond="{day}"')                                       # 오재윤(계단참②)
    m.c(f'npc N-R01-036 46 12 S cond="{day}" route=tower:46,12,8;top:40,14,4')      # 조하진(망루 감시조)
    m.c(f'npc N-R01-501 10 28 E cond="{day}" route=a:10,28,5;b:18,28,4')            # 오영자(미용실)
    m.c('trigger 27 39 scene=MQ-101_GATE w=5 h=2 cond="MQ101_STAGE == 10" once')
    m.c('npc C-021 29 42 N cond="MQ101_NIGHT == 2 and MQ101_RESULT == 0 and MQ101_FIGHT == 0"')   # 독사(밤, 아랫문 밖 — 말을 걸 수 있다)
    for k, (x, y) in enumerate(((29, 37), (29, 29), (33, 21), (30, 13))):           # 계단참 ①~④(방어전 감시조 자리)
        m.c(f"mark land{k + 1} {x} {y} S")
    m.c("mark doksa 29 42 N")
    m.c("mark pc_fight 30 36 S")                                         # 방어전: 주인공은 아랫문 안 계단참① 옆에서 막는다
    m.c("mark sbf1 25 44 N"); m.c("mark sbf2 33 44 N"); m.c("mark sbf3 37 43 N"); m.c("mark doksaf 29 45 N")   # 방어전 시작 자리(길 위)
    m.c("mark sb1 27 43 N"); m.c("mark sb2 31 43 N"); m.c("mark sb3 33 42 N")
    m.c("mark tanks 11 12 N")
    # ---- 윗문(북)
    m.fill(44, 1, 46, 2, "c", 6)
    m.p("gate_shut", 45, 1)
    m.text(45, 2, "윗문. 봉천 고개로 넘어가는 쪽문인데 지금은 잠가 두었다.")
    # ---- 골목 잔 소품(2단·3단)
    for (n, x, y) in (("planter_s", 14, 27), ("planter_l", 23, 27), ("drum", 45, 27), ("planter_p", 52, 26), ("bench_o", 48, 26),
                      ("utility_pole", 38, 27), ("lp_gas", 9, 27), ("crate_o", 19, 26),
                      ("laundry_line", 15, 29), ("antenna", 35, 29), ("water_tank_s", 44, 29), ("planter_l", 6, 29),
                      ("planter_p", 41, 20), ("drum", 50, 20), ("bench_o", 44, 19), ("utility_pole", 26, 20), ("planter_s", 9, 20),
                      ("tree_small", 19, 20), ("laundry_line", 24, 22), ("antenna", 14, 22), ("water_tank_s", 39, 22),
                      ("planter_l", 7, 22), ("laundry_line", 11, 15), ("antenna", 7, 15), ("planter_p", 22, 15), ("planter_l", 26, 15),
                      ("water_tank_s", 41, 15), ("planter_s", 48, 15), ("tree_small", 52, 23), ("bush_g", 54, 30),
                      ("bush_a", 22, 29), ("tree_small", 25, 29)):
        m.p(n, x, y)
    border_trees(m)
    return m


# ================================================================================================ 실내(빌라 방, set bc)
class I:
    def __init__(self, mid, name, w, h):
        self.id, self.name, self.w, self.h = mid, name, w, h
        self.g = [["#"] * w for _ in range(h)]
        self.cmds = []

    def room(self, x0, y0, x1, y1, ch="w"):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch

    def c(self, s):
        self.cmds.append(s)

    def text_src(self):
        return "\n".join([f"map {self.id} {self.name}", "set bc", "grid"] + ["".join(r) for r in self.g] + ["end"] + self.cmds) + "\n"


def b01():
    """B-01 옥탑 이장실(마루) + 빌린 침대 방(장판, 이장실 옆방, 안쪽 문). 2277년 봉천 살림: 자개장롱·밥상·석유난로·
    감시조 무전기·손으로 그린 마을 지도(SD-09a §4 봉천 '옥탑 이장실')."""
    m = I("B-01", "옥탑 이장실", 26, 14)
    m.room(1, 3, 15, 12, "w")                                            # 이장실(마루)
    m.room(19, 3, 24, 12, "j")                                           # 빌린 침대 방(콩댐 장판)
    for y in range(3, 13):
        m.g[y][16] = m.g[y][17] = m.g[y][18] = "#"
    for x in (16, 17, 18):
        m.g[10][x] = "w"
    m.g[13][8] = "w"
    m.c("exit 8 13 X-BC from_B-01")
    m.c("mark from_X-BC 8 12 N")
    m.c("mark bed 21 6 S")
    m.c("mark bed_side 20 8 N")
    m.c("mark chief_night 23 8 W")
    m.c("mark chief 6 4 S")
    m.c("npc C-010 6 4 S")
    # 벽(벽면 윗칸 y=1)
    m.c("prop w_map 3 1"); m.c("prop w_window 7 1"); m.c("prop w_calendar 11 1"); m.c("prop w_shelf 12 1")
    m.c('text 3 2 "손으로 그린 봉천 지도. 계단참 넷에 동그라미, 붉은 압정 넷은 감시조 자리다." w=2')
    # 이장실
    m.c("prop wardrobe 1 3")
    m.c('text 1 3 "자개장롱. 학과 구름이 박혀 있다. 이장 할머니의 혼수였다고 한다." w=2')
    m.c("prop chief_desk 5 5")
    m.c('text 5 5 "조만석의 책상. 2077년 구청 지도가 유리 밑에 깔려 있고, 장부에는 물탱크 눈금이 날마다 적혀 있다." w=2')
    m.c("prop radio_desk 9 3")
    m.c('text 9 3 "감시조 무전기. 호박색 눈금이 은은하게 켜져 있다. 계단참마다 한 대씩."')
    m.c("prop crt_tv 13 3"); m.c("prop plant_pot 15 3")
    m.c('text 13 3 "2077년 텔레비전. 전기가 들어온 적이 없다. 위에 뜨개 덮개가 얹혀 있다."')
    m.c("prop heater 11 7")
    m.c("prop low_table 4 9"); m.c("prop cushion_r 3 9"); m.c("prop cushion_b 6 9"); m.c("prop cushion_y 5 10")
    m.c('text 4 9 "밥상. 양은 주전자에 보리차가 식어 있다." w=2')
    m.c("prop dresser 14 6")
    m.c("prop shoe_rack 6 12"); m.c("prop crate_o 1 11"); m.c("prop crate_o 1 12"); m.c("prop water_jug 2 12")
    # 빌린 침대 방
    m.c("prop w_window 20 1"); m.c("prop w_calendar 23 1")
    m.c("prop yo_bed 22 4")
    m.c('text 22 4 "빌린 침대. 이불에서 햇볕 냄새가 난다." h=2' + (" scene=B-01_BED" if "B-01_BED" in SCENES else ""))
    m.c("prop dresser 19 3"); m.c("prop cushion_y 20 6"); m.c("prop plant_pot 24 11")
    return m


def b03():
    """B-03 하숙자 약국(18×12): 나무 약 선반·유리 진열 계산대·야전 침대·링거대·약수통·대기 의자."""
    m = I("B-03", "하숙자 약국", 18, 12)
    m.room(1, 3, 16, 10, "o")
    m.g[11][3] = "o"
    m.c("exit 3 11 X-BC from_B-03")
    m.c("mark from_X-BC 3 10 N")
    m.c("prop w_cross 5 1"); m.c("prop w_poster_rad 7 1"); m.c("prop w_herbs 9 1"); m.c("prop w_calendar 14 1")
    m.c("prop med_shelf 1 3"); m.c("prop med_shelf 3 3")
    m.c('text 1 3 "약 선반. 라드어웨이 봉지와 관악산 약수병이 줄지어 있다." w=4')
    m.c("prop water_jug 5 3")
    m.c("prop pharm_counter 6 6")
    m.c('text 6 6 "유리 진열장. 스팀팩 몇 개와 끓여 말린 붕대." w=2')
    m.c("mark counter 7 7 N")
    m.c("npc C-057 7 5 S")
    m.c("prop cot 11 3"); m.c("prop iv_pole 12 3"); m.c("prop cot 13 3"); m.c("prop cot 15 3")
    m.c("prop cot 13 7"); m.c("prop cot 15 7")
    m.c('text 11 3 "야전 침대. 열병 앓던 아이가 어제까지 누워 있었다." h=2')
    m.c("prop stool_w 4 8"); m.c("prop stool_w 9 8"); m.c("prop bench_o 1 9"); m.c("prop plant_pot 16 10")
    return m


def main():
    for sub in ("r01",):
        os.makedirs(os.path.join(OUT), exist_ok=True)
    for f in (slope, bongcheon, b01, b03):
        m = f()
        p = os.path.join(OUT, m.id + ".map")
        open(p, "w", encoding="utf-8").write(m.text_src())
        print("씀:", p)


if __name__ == "__main__":
    main()
