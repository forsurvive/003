"""실내 맵 변환기 (단계 0-5): maps/<세트>/*.map → game/data/maps/<맵 ID>.json. 오류는 '파일:줄 내용'으로 보고하고 종료 코드 1.

원고 형식 (한 줄에 하나, # 뒤는 주석):
  map V-08 의무과                맵 ID와 이름
  set s07                        타일셋·소품 묶음(지금은 s07)
  grid … end                     글자 격자. 모든 줄 길이가 같아야 한다.
     # 또는 공백 = 벽(자동: 아래가 바닥이면 벽면 아랫칸, 두 칸 아래가 바닥이면 벽면 윗칸, 아니면 벽 윗면 + 테)
     . 철판  , 장판  o 진료실 타일  = 격자  ~ 콘크리트  c 카펫  w 마루  m·M 곰팡이 핀 철판·격자  t 인조석(지하상가)  u 지하 통로 콘크리트
     - | + ^  바닥 유도선(가로·세로·교차·T자)
  prop 이름 x y                  소품(발 칸 왼쪽 위). 벽 소품(wall)은 벽면 윗칸에 건다.
  door x y [kind=slide|hatch|iron|steel|blast] [locked] ["표지"]
                                 벽면 문: (x, y) 벽면 윗칸과 그 아래 칸이 바닥(뚫린 곳)이어야 한다. 가까이 가면 열린다.
  exit x y 맵 표지               이 칸에 들어서면 다른 맵의 표지로 간다(바닥 칸).
  mark 이름 x y 방향             연출·도착 표지(E S W N …)
  npc ID x y 방향 [route=이름:x,y,초;…] [cond="식"] [bark="한 줄"]
                                 인물. route가 있으면 표지 사이를 걸어 오가며 머문다(일과). cond가 거짓이면 없다.
  text x y "글"                  조사 키로 읽는 글(소품·벽 앞). [w=칸 h=칸]으로 넓힐 수 있다.
  sign x y "글자"                벽면 윗칸에 붙는 문패(그림은 게임이 그린다).
  trigger x y scene=장면 [w= h=] [cond="식"] [once]
                                 밟으면 대화 장면을 연다(cond가 참일 때, once면 한 번만).
  box x y 종류 [w= h=] [owner=인물ID|S7|PC] [lock=판정값] [name="이름"] [cond="식"]
                                 용기(SD-12 §7.3, 0-9): 그 칸(보통 소품)을 조사하면 2단 창. 종류 = loot.json 표. owner가 있으면
                                 [소유](꺼내면 절도), lock이면 [자물쇠 따기 n] 판정 뒤 열린다.
  term x y TM-ID [w= h=] [cond="식"]
                                 단말(SD-12 §7.4, 1-4): 그 칸(보통 책상 위 단말 소품)을 조사하면 단말 화면. 내용은 script/terms/*.txt.
  enemy ID x y [cond="식"] [arm=baton|pistol] [who=인물ID] [dir=방향] [stance=hold] [route=x,y,초;…]
                                 적(SD-14). route면 순찰(닿으면 그 초만큼 서서 둘러본다), stance=hold면 제자리 경계(0-9).
  prop·sign·npc에도 cond="식"을 붙일 수 있다(시대·퀘스트에 따라 있다 없다 — 예: year() == 2259).
  npc에 look=외형코드(SD-07b)를 주면 그 모습 시트로 선다(예: 2259년의 아기 하도윤).
검사: 격자 폭·글자, 벽 두께(위아래 방 사이 3칸), 소품 발 칸이 바닥·겹침 없음, 벽 소품은 벽면 윗칸, 문 자리, 출구 칸이
  바닥이고 갈 맵·표지가 있음, 인물·일과 지점이 바닥이고 서로 이어짐, 모든 바닥이 한 덩어리(갇힌 곳 없음), 식 문법·변수."""
import os, sys, json, glob, shlex, re
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import story_expr as SE

_TERMS = os.path.join(ROOT, "game", "data", "terminals.json")
terms_db = json.load(open(_TERMS, encoding="utf-8"))["terms"] if os.path.exists(_TERMS) else {}

LOOK_RE = re.compile(r"^(M1|M2|F1|F2|E1|E2|K1)-S[1-6G][12]?-HR\d\d-H\d-T\d\d-\d-PF\d\d-HD\d\d-EY\d\d(-PR\d+)?$")


def look_sheet(code):
    """외형 코드 → 이야기 인물 시트 이름(story_sprites와 같은 규칙)."""
    return "st_look_" + code.lower().replace("-", "_")

SRC = os.path.join(ROOT, "maps")
OUT = os.path.join(ROOT, "game", "data", "maps")
TIL = os.path.join(ROOT, "game", "assets", "tiles")
PROPS = os.path.join(ROOT, "game", "assets", "props")
FLOOR = {".": "panel", ",": "lino_a", "o": "clinic_a", "=": "grate_a", "~": "concrete_a", "c": "carpet_a", "w": "wood_a", "j": "jangpan_a", "t": "terrazzo_a", "u": "tunnel_a", "s": "steps_a", "e": "epoxy_a", "g": "turf_a", "f": "flood_a", "F": "flood_b",
         "m": "panel_mold", "M": "grate_mold", "-": "guide_h", "|": "guide_v", "+": "guide_x", "^": "guide_t"}
WALL = {"#", " "}
DIRS = {"E", "SE", "S", "SW", "W", "NW", "N", "NE"}


class Err(Exception):
    pass


def tiles(name):
    return {k: v["atlas"][0] for k, v in json.load(open(os.path.join(TIL, f"ts_{name}.json"))).items()}


def h(x, y, k=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (k * 83492791)
    return (v & 0xFFFF) % 97


class MapSrc:
    def __init__(self, path):
        self.path = path
        self.errors = []
        self.id = self.name = ""
        self.set = "s07"
        self.rows = []
        self.levels = []                                           # 바깥 맵 높이 격자(levels … end)
        self.cmds = []                                             # (줄, [낱말])
        lines = open(path, encoding="utf-8").read().split("\n")
        i = 0
        while i < len(lines):
            raw = lines[i]
            ln = i + 1
            i += 1
            s = raw.split(" #")[0].rstrip() if not raw.lstrip().startswith("#") else ""
            if raw.strip() in ("grid", "levels"):
                dst = self.rows if raw.strip() == "grid" else self.levels
                while i < len(lines) and lines[i].rstrip() != "end":
                    dst.append((i + 1, lines[i].rstrip("\n")))
                    i += 1
                i += 1
                continue
            if not s.strip():
                continue
            try:
                words = shlex.split(s)
            except ValueError as e:
                self.err(ln, f"따옴표 짝이 맞지 않는다: {e}")
                continue
            if words[0] == "map":
                self.id, self.name = words[1], " ".join(words[2:])
            elif words[0] == "set":
                self.set = words[1]
            else:
                self.cmds.append((ln, words))

    def err(self, ln, msg):
        self.errors.append(f"{os.path.relpath(self.path, ROOT)}:{ln} {msg}")


def kv(words):
    pos, opt = [], {}
    for w in words:
        if "=" in w and not w.startswith('"'):
            k, v = w.split("=", 1)
            opt[k] = v
        else:
            pos.append(w)
    return pos, opt


def check_cond(src, known_vars, known_fns):
    ast = SE.parse(src)
    vs, calls = SE.names(ast)
    bad = [v for v in vs if v not in known_vars] + [f for f in calls if f not in known_fns]
    if bad:
        raise Err(f"cond에 모르는 이름 {bad}")


# ------------------------------------------------------------------------------------------------ 바깥 맵(단계 0-10, set r01)
# 격자 글자: 걷는 바닥 · 구조물 위 걷는 칸 · 막힌 칸. 높이는 levels 격자(칸마다 0~9, 타일 단위 높이 — 옹벽 2타일 = 2단).
# 높이가 다른 이웃 칸은 계단·사다리 칸을 거쳐야만 오간다(실행 중 충돌·길찾기가 같은 규칙). 구조물 그림은 struct 명령으로
# 맵마다 한 장에 굽는다(tools/pipeline/struct_bake.py → game/assets/maps/<ID>_struct.png).
EXT_WALK = {".": "dirt_a", ",": "dirt_grass_b", ";": "dirt_grass_a", "_": "asphalt", "-": "asphalt_lane", ":": "pavers",
            "c": "concrete_o", "=": "stairs", "!": "stairs_rail", "g": "rock_floor"}       # g = 화강암 맨바닥(1-11c 관악산 정상)
EXT_ON = {"r": "concrete_o", "p": "dirt_a", "L": "concrete_o", "D": "concrete_o"}     # 구조물 그림이 덮는 걷는 칸(옥상·판자 다리·사다리·문)
EXT_SOLID = {"H": ("concrete_o", 1, 2), "#": ("concrete_o", 1, 2), "R": ("concrete_o", 1, 2), "S": ("concrete_o", 1, 2),
             "P": ("concrete_o", 1, 2), "X": ("concrete_o", 3, 2), "v": ("concrete_o", 3, 0), "T": ("dirt_grass_a", 0, 2),
             "o": ("dirt_a", 0, 1), "~": ("dirt_a", 3, 0)}                                  # 글자: (바닥, 덮개, 엄폐)
EXT_STAIR = {"=", "!", "L"}
EXT_PROPOK = set(EXT_WALK) | {"T", "o", "r", "p"}                                            # 소품 발 칸이 놓일 수 있는 글자


def compile_ext(m, prop_meta, known_vars, known_fns, scenes=()):
    W = max(len(r) for _, r in m.rows)
    H = len(m.rows)
    grid = []
    for ln, r in m.rows:
        if len(r) != W:
            m.err(ln, f"격자 줄 길이 {len(r)} ≠ {W}")
            r = r.ljust(W)
        for x, ch in enumerate(r):
            if ch not in EXT_WALK and ch not in EXT_ON and ch not in EXT_SOLID:
                m.err(ln, f"모르는 바깥 격자 글자 '{ch}' (x={x})")
        grid.append(r)
    if len(m.levels) != H or any(len(r) != W for _, r in m.levels):
        m.err(1, f"levels 격자 크기가 grid({W}×{H})와 다르다")
        return None
    lv = [r for _, r in m.levels]
    walk = lambda x, y: 0 <= x < W and 0 <= y < H and (grid[y][x] in EXT_WALK or grid[y][x] in EXT_ON)
    stair = lambda x, y: walk(x, y) and grid[y][x] in EXT_STAIR
    level = [[-1] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if walk(x, y):
                ch = lv[y][x]
                if not ch.isdigit():
                    m.err(m.levels[y][0], f"걷는 칸 ({x},{y}) '{grid[y][x]}'에 높이가 없다")
                    continue
                level[y][x] = int(ch)
    for y in range(H):                                                   # 높이 이음 규칙
        for x in range(W):
            if not walk(x, y):
                continue
            for dx, dy in ((1, 0), (0, 1)):
                nx, ny = x + dx, y + dy
                pass                                                    # 높이가 다른 칸끼리 붙은 곳 = 벼랑·옥상 끝(실행 중 막힘, 난간·턱을 그린다)
            if stair(x, y):
                for nx in (x - 1, x + 1):
                    if walk(nx, y) and not stair(nx, y) and level[y][nx] != level[y][x]:
                        m.err(m.rows[y][0], f"계단 ({x},{y}) 옆({nx},{y})이 다른 높이의 바닥이다 — 계단 옆은 벽이나 계단이어야 한다")
    ft = tiles("r01_ext")
    floor_ids, gflag, solid, cover = [], [], [], []
    for y in range(H):
        fr, gr, sr, cr = [], [], [], []
        for x in range(W):
            ch = grid[y][x]
            if ch in EXT_WALK:
                fr.append(ft[EXT_WALK[ch]]); gr.append(0); sr.append(0); cr.append(0)
            elif ch in EXT_ON:
                fr.append(ft[EXT_ON[ch]]); gr.append(1 if ch == "D" else 3); sr.append(0); cr.append(0)
            else:
                g, f, c = EXT_SOLID.get(ch, ("dirt_a", 0, 0))
                fr.append(ft[g]); gr.append(f); sr.append(1); cr.append(c)
        floor_ids.append(fr); gflag.append(gr); solid.append(sr); cover.append(cr)
    out = {"id": m.id, "name": m.name, "set": m.set, "ext": True, "size": [W, H], "props": [], "doors": [], "exits": [], "marks": {},
           "npcs": [], "texts": [], "signs": [], "triggers": [], "enemies": [], "boxes": [], "terms": [], "structs": []}
    return out, grid, floor_ids, gflag, solid, cover, level, walk


def compile_map(m, prop_meta, known_vars, known_fns, scenes=()):
    if not m.rows:
        m.err(1, "grid가 없다")
        return None
    ext = m.set == "r01"
    if ext:
        res = compile_ext(m, prop_meta, known_vars, known_fns, scenes)
        if res is None:
            return None
        out, grid, floor_ids, gflag, solid, cover, level, walk = res
        W, H = out["size"]
        kind = [[None] * W for _ in range(H)]

        def floor(x, y):
            return 0 <= x < W and 0 <= y < H and grid[y][x] in EXT_PROPOK

        return _commands(m, prop_meta, known_vars, known_fns, scenes, out, W, H, floor, kind, solid, walk, ext=True,
                         extra=(floor_ids, gflag, cover, level, grid))
    W = max(len(r) for _, r in m.rows)
    H = len(m.rows)
    grid = []
    for ln, r in m.rows:
        if len(r) != W:
            m.err(ln, f"격자 줄 길이 {len(r)} ≠ {W}")
            r = r.ljust(W)
        for x, ch in enumerate(r):
            if ch not in FLOOR and ch not in WALL:
                m.err(ln, f"모르는 격자 글자 '{ch}' (x={x})")
        grid.append(r)

    def floor(x, y):
        return 0 <= x < W and 0 <= y < H and grid[y][x] in FLOOR

    def wall(x, y):
        return not floor(x, y)

    # 벽 자동 타일
    wt = tiles(f"{m.set}_wall" if os.path.exists(os.path.join(TIL, f"ts_{m.set}_wall.json")) else "s07_wall")
    ft = tiles("s07_int")
    kind = [[None] * W for _ in range(H)]                         # 'top' / 'ftop' / 'fbot' / None(바닥)
    for y in range(H):
        for x in range(W):
            if floor(x, y):
                continue
            if floor(x, y + 1):
                kind[y][x] = "fbot"
            elif wall(x, y + 1) and floor(x, y + 2):
                kind[y][x] = "ftop"
            else:
                kind[y][x] = "top"
    for y in range(H):                                            # 벽 두께: 위에 바닥, 바로 아래 벽면 → 윗면이 없다
        thin = [x for x in range(W) if kind[y][x] in ("ftop", "fbot") and floor(x, y - 1)]
        if thin:
            m.err(m.rows[y][0], f"벽이 얇다(x={thin[0]}~{thin[-1]}, {len(thin)}칸): 위아래 방 사이 벽은 3줄(윗면 1 + 벽면 2)이어야 한다")
    wall_ids = [[-1] * W for _ in range(H)]
    floor_ids = [[ft["panel"]] * W for _ in range(H)]

    def top_at(x, y):
        return x < 0 or y < 0 or x >= W or y >= H or kind[y][x] == "top"
    for y in range(H):
        for x in range(W):
            k = kind[y][x]
            if k is None:
                floor_ids[y][x] = ft[FLOOR[grid[y][x]]]
                continue
            if k == "fbot":
                wall_ids[y][x] = wt["face_bot_outlet" if h(x, y) < 7 else "face_bot"]
            elif k == "ftop":
                v = h(x, y, 1)
                wall_ids[y][x] = wt["face_top_pipe" if v < 6 else "face_top_vent" if v < 10 else "face_top"]
            else:
                mask = 0
                for (dx, dy), bit in (((0, -1), 1), ((1, 0), 2), ((0, 1), 4), ((-1, 0), 8)):
                    if not top_at(x + dx, y + dy):
                        mask |= bit
                wall_ids[y][x] = wt[f"wt_{mask}"]
            nb = [grid[y + dy][x + dx] for dx, dy in ((0, 1), (0, 2), (1, 0), (-1, 0), (0, -1))
                  if 0 <= x + dx < W and 0 <= y + dy < H and grid[y + dy][x + dx] in FLOOR]
            floor_ids[y][x] = ft[FLOOR[nb[0]]] if nb else ft["panel"]
    solid = [[0 if floor(x, y) else 1 for x in range(W)] for y in range(H)]
    out = {"id": m.id, "name": m.name, "set": m.set, "size": [W, H], "props": [], "doors": [], "exits": [], "marks": {},
           "npcs": [], "texts": [], "signs": [], "triggers": [], "enemies": [], "boxes": [], "terms": []}
    return _commands(m, prop_meta, known_vars, known_fns, scenes, out, W, H, floor, kind, solid, None, ext=False,
                     extra=(floor_ids, wall_ids))


def _commands(m, prop_meta, known_vars, known_fns, scenes, out, W, H, floor, kind, solid, walk, ext=False, extra=()):
    """맵 명령(prop·door·exit·mark·npc·enemy·box·text·sign·trigger·struct) → out. 실내·바깥 공용."""
    loot_kinds = set(json.load(open(os.path.join(ROOT, "game", "data", "loot.json"), encoding="utf-8"))["tables"].keys()) | {"seized", "home"}   # seized: 계엄군 압수품 보관함(1-7, 진행기가 채운다) · home: 거처 보관함(1-8b, 빈 채로 시작 · 다시 차지 않음)
    enemy_ids = set(json.load(open(os.path.join(ROOT, "game", "data", "enemies.json"), encoding="utf-8")).keys())
    npc_ids = set(json.load(open(os.path.join(ROOT, "game", "data", "npcs.json"), encoding="utf-8"))["npcs"].keys())
    for ln, words in m.cmds:
        pos, opt = kv(words[1:])
        c = words[0]
        try:
            if c == "prop":
                name, x, y = pos[0], int(pos[1]), int(pos[2])
                if name not in prop_meta:
                    raise Err(f"모르는 소품 '{name}'")
                pm = prop_meta[name]
                fw, fh = pm["foot"]
                cond = opt.get("cond", "")
                if cond:
                    check_cond(cond, known_vars, known_fns)
                if pm["kind"] == "wall":
                    for i in range(max(1, fw)):
                        if 0 <= x + i < W and kind[y][x + i] != "ftop" and name not in ("gear_door", "gear_frame"):
                            raise Err(f"벽 소품 '{name}'은 벽면 윗칸에 건다(x={x + i}, y={y}는 {kind[y][x + i] or '바닥'})")
                    sort_y = (y + 2) * 32
                elif pm["kind"] == "door":
                    raise Err("문은 door 명령으로 둔다")
                else:
                    cells = []
                    for j in range(fh):
                        for i in range(fw):
                            if not floor(x + i, y + j):
                                raise Err(f"소품 '{name}' 발 칸 ({x + i},{y + j})이 바닥이 아니다")
                            if solid[y + j][x + i] == 2:
                                raise Err(f"소품 '{name}' 발 칸 ({x + i},{y + j})이 다른 소품과 겹친다")
                            cells.append([x + i, y + j])
                            if not cond and opt.get("pass") != "1":     # pass=1: 밟고 지나가는 소품(지하철 출입구 계단 = 출구 칸, 1-8f)
                                solid[y + j][x + i] = 2                 # 조건부 소품의 막힘은 게임이 cond를 보고 더한다
                    sort_y = (y + max(fh, 1)) * 32
                    if pm["kind"] == "deco":
                        sort_y = y * 32 + 16
                e = {"name": name, "x": x, "y": y, "px": [x * 32 + pm["off"][0], y * 32 + pm["off"][1]], "sort_y": sort_y}
                if cond:
                    e["cond"] = cond
                    e["cells"] = cells if pm["kind"] not in ("wall", "deco") else []
                out["props"].append(e)
            elif c == "door":
                x, y = int(pos[0]), int(pos[1])
                label = next((p for p in pos[2:] if p != "locked"), "")
                k = opt.get("kind", "slide")
                if not (floor(x, y) and floor(x, y + 1)):
                    raise Err(f"문 자리 ({x},{y})·({x},{y + 1})가 뚫려 있어야 한다")
                if not (0 < x < W - 1 and kind[y][x - 1] == "ftop" and kind[y][x + 1] == "ftop"):
                    raise Err(f"문 ({x},{y}) 양옆이 벽면 윗칸이어야 한다")
                locked = "locked" in pos
                if locked:
                    solid[y][x] = solid[y + 1][x] = 1
                e = {"x": x, "y": y, "kind": "door_" + k, "label": label, "locked": locked}
                if opt.get("lock"):                                  # 자물쇠 따기로 여는 잠긴 문(1-5): lock=0·25·50·75·100
                    if not locked or int(opt["lock"]) not in (0, 25, 50, 75, 100):
                        raise Err("lock=은 locked 문에 0·25·50·75·100으로 붙인다")
                    e["lock"] = int(opt["lock"])
                out["doors"].append(e)
            elif c == "exit":
                x, y, to, mk = int(pos[0]), int(pos[1]), pos[2], pos[3]
                if not (walk(x, y) if ext else floor(x, y)):
                    raise Err(f"출구 칸 ({x},{y})이 바닥이 아니다")
                out["exits"].append({"x": x, "y": y, "to": to, "mark": mk, "line": ln})
            elif c == "mark":
                name, x, y, d = pos[0], int(pos[1]), int(pos[2]), pos[3]
                if d not in DIRS:
                    raise Err(f"모르는 방향 '{d}'")
                if not (walk(x, y) if ext else floor(x, y)):
                    raise Err(f"표지 '{name}' ({x},{y})가 바닥이 아니다")
                out["marks"][name] = [x, y, d]
            elif c == "npc":
                nid, x, y, d = pos[0], int(pos[1]), int(pos[2]), pos[3]
                e = {"id": nid, "x": x, "y": y, "dir": d, "route": [], "cond": opt.get("cond", ""), "bark": opt.get("bark", "")}
                if not (walk(x, y) if ext else floor(x, y)):
                    raise Err(f"인물 {nid} 자리 ({x},{y})가 바닥이 아니다")
                if e["cond"]:
                    check_cond(e["cond"], known_vars, known_fns)
                if "sheet" in opt:                                  # 사람 아닌 인물(백구 등): 시트를 바로 쓴다(0-10)
                    e["sheet"] = opt["sheet"]
                if "pose" in opt:                                   # 처음 자세(1-8b): sleep(시트에 잠 컷이 있는 짐승) · sit · lie
                    if opt["pose"] not in ("sleep", "sit", "lie"):
                        raise Err(f"모르는 자세 '{opt['pose']}'")
                    e["pose"] = opt["pose"]
                if "look" in opt:
                    if not LOOK_RE.match(opt["look"]):
                        raise Err(f"외형 코드 형식이 아니다: {opt['look']}")
                    e["look"] = opt["look"]
                    e["sheet"] = look_sheet(opt["look"])
                for part in [p for p in opt.get("route", "").split(";") if p]:
                    mm = re.match(r"^([^:]+):(\d+),(\d+)(?:,(\d+(?:\.\d+)?))?$", part)
                    if not mm:
                        raise Err(f"route 형식 '이름:x,y,초' 아님: {part}")
                    rx, ry = int(mm.group(2)), int(mm.group(3))
                    if not (walk(rx, ry) if ext else floor(rx, ry)):
                        raise Err(f"일과 지점 {mm.group(1)} ({rx},{ry})가 바닥이 아니다")
                    e["route"].append([mm.group(1), rx, ry, float(mm.group(4) or 4)])
                e["line"] = ln
                out["npcs"].append(e)
            elif c == "enemy":                                   # enemy ID x y [cond=] — 적(SD-14), 조건이 맞을 때만 선다
                eid, x, y = pos[0], int(pos[1]), int(pos[2])
                if eid not in enemy_ids:
                    raise Err(f"적 자료(enemies.json)에 없는 ID '{eid}'")
                if not (walk(x, y) if ext else floor(x, y)) or solid[y][x]:
                    raise Err(f"적 {eid} 자리 ({x},{y})가 빈 바닥이 아니다")
                e = {"id": eid, "x": x, "y": y, "cond": opt.get("cond", "")}
                if e["cond"]:
                    check_cond(e["cond"], known_vars, known_fns)
                for k in ("arm", "who", "dir", "stance"):              # 0-9: 든 무기(baton|pistol) · 인물 ID(이름표) · 처음 방향 · hold(제자리)
                    if opt.get(k):
                        e[k] = opt[k]
                if opt.get("lurk"):                                    # 1-D 물속 매복(침수 구울): 물 칸('f' · 'F')에만
                    if [r for _, r in m.rows][y][x:x + 1] not in ("f", "F"):
                        raise Err(f"물속 매복 적 {eid} 자리 ({x},{y})가 물 칸이 아니다")
                    e["lurk"] = True
                if opt.get("boss"):                                    # 1-D0 우두머리: 쓰러뜨리면 다시 서지 않는다(SD-14 §11.3)
                    e["boss"] = True
                if opt.get("sleep"):                                   # 1-B4 실내 상황: 자는 중(맞거나 소리에 깬다 — Enemy.setup_enemy)
                    e["sleep"] = True
                if opt.get("det"):                                     # 감지 배수(먹는 중 0.5 등)
                    e["det"] = float(opt["det"])
                if opt.get("route"):                                   # 순찰 경로: x,y,초;… (닿으면 그 초만큼 서서 둘러본다)
                    e["route"] = []
                    for part in [p for p in opt["route"].split(";") if p]:
                        mm = re.match(r"^(\d+),(\d+)(?:,(\d+(?:\.\d+)?))?$", part)
                        if not mm:
                            raise Err(f"순찰 route 형식 'x,y,초' 아님: {part}")
                        rx, ry = int(mm.group(1)), int(mm.group(2))
                        if not (walk(rx, ry) if ext else floor(rx, ry)) or solid[ry][rx]:
                            raise Err(f"순찰 지점 ({rx},{ry})가 빈 바닥이 아니다")
                        e["route"].append([rx, ry, float(mm.group(3) or 2)])
                out["enemies"].append(e)
            elif c == "trap":                                    # trap 종류 x y [len=] [dir=E|W|N|S] [id=] [link=] [hide=] [cond=] — 숨긴 함정(1-9c, SD-11 §9.2)
                tk, x, y = pos[0], int(pos[1]), int(pos[2])
                if tk not in ("wire", "plate", "bear", "shotgun", "claymore", "terminal", "radcask"):
                    raise Err(f"모르는 함정 '{tk}'(wire·plate·bear·shotgun·claymore·terminal·radcask — 자판기·택배함·가스 배관은 소품)")
                if tk not in ("terminal", "radcask") and not (walk(x, y) if ext else floor(x, y)):
                    raise Err(f"함정 {tk} 자리 ({x},{y})가 바닥이 아니다")
                e = {"type": tk, "x": x, "y": y, "dir": opt.get("dir", "E"), "len": int(opt.get("len", 3 if tk == "wire" else 1)),
                     "id": opt.get("id", ""), "link": opt.get("link", ""), "cond": opt.get("cond", "")}
                if tk == "wire":                                        # 철선은 dir 쪽으로 len칸 — 모두 걸을 수 있는 칸이어야 한다
                    dx, dy = {"E": (1, 0), "W": (-1, 0), "S": (0, 1), "N": (0, -1)}[e["dir"]]
                    for k in range(e["len"]):
                        if not (walk(x + dx * k, y + dy * k) if ext else floor(x + dx * k, y + dy * k)):
                            raise Err(f"철선 칸 ({x + dx * k},{y + dy * k})가 바닥이 아니다")
                if e["cond"]:
                    check_cond(e["cond"], known_vars, known_fns)
                out.setdefault("traps", []).append(e)
            elif c == "rad":                                     # rad Z x y w h [cond=] — 방사능 지대(1-9d, SD-11 §11.2 Z1~Z5)
                z, x, y, w, h = int(pos[0]), int(pos[1]), int(pos[2]), int(pos[3]), int(pos[4])
                if not 1 <= z <= 5:
                    raise Err(f"방사능 등급 Z{z}(1~5)")
                e = {"z": z, "x": x, "y": y, "w": w, "h": h, "cond": opt.get("cond", "")}
                if e["cond"]:
                    check_cond(e["cond"], known_vars, known_fns)
                out.setdefault("rad", []).append(e)
            elif c == "mine":                                    # mine ID x y [cond=] — 적이 깔아 둔 지뢰(1-9c, W-063 · W-064 · W-151)
                mid, x, y = pos[0], int(pos[1]), int(pos[2])
                if mid not in ("W-063", "W-064", "W-151"):
                    raise Err(f"지뢰 ID '{mid}'(W-063 · W-064 · W-151)")
                if not (walk(x, y) if ext else floor(x, y)):
                    raise Err(f"지뢰 자리 ({x},{y})가 바닥이 아니다")
                e = {"id": mid, "x": x, "y": y, "cond": opt.get("cond", "")}
                if e["cond"]:
                    check_cond(e["cond"], known_vars, known_fns)
                out.setdefault("mines", []).append(e)
            elif c == "box":                                     # box x y 종류 [w= h=] [owner=] [lock=] [name=] [cond=] — 용기(0-9)
                x, y, bkind = int(pos[0]), int(pos[1]), pos[2]          # (kind는 벽 모양 격자 — 덮어쓰지 않는다)
                if bkind not in loot_kinds:
                    raise Err(f"모르는 용기 종류 '{bkind}'(loot.json: {sorted(loot_kinds)})")
                e = {"x": x, "y": y, "w": int(opt.get("w", 1)), "h": int(opt.get("h", 1)), "kind": bkind,
                     "owner": opt.get("owner", ""), "lock": int(opt.get("lock", 0)), "name": opt.get("name", ""), "cond": opt.get("cond", "")}
                if e["cond"]:
                    check_cond(e["cond"], known_vars, known_fns)
                if not (0 <= x < W and 0 <= y < H):
                    raise Err(f"용기 ({x},{y})가 맵 밖이다")
                if any(b["x"] == x and b["y"] == y for b in out["boxes"]):
                    raise Err(f"용기 ({x},{y})가 두 번 놓였다")
                if e["owner"] not in ("", "PC", "S7") and e["owner"] not in npc_ids:
                    raise Err(f"용기 주인 '{e['owner']}'를 모른다(\"\"·PC·S7·인물 ID)")
                out["boxes"].append(e)
            elif c == "term":                                    # term x y TM-ID [w= h=] [cond=] — 단말(1-4, SD-12 §7.4)
                x, y, tid = int(pos[0]), int(pos[1]), pos[2]
                if tid not in terms_db:
                    raise Err(f"모르는 단말 '{tid}'(script/terms)")
                e = {"x": x, "y": y, "w": int(opt.get("w", 1)), "h": int(opt.get("h", 1)), "id": tid, "cond": opt.get("cond", "")}
                if e["cond"]:
                    check_cond(e["cond"], known_vars, known_fns)
                if not (0 <= x < W and 0 <= y < H):
                    raise Err(f"단말 ({x},{y})가 맵 밖이다")
                out["terms"].append(e)
            elif c == "text":
                x, y, txt = int(pos[0]), int(pos[1]), pos[2]
                e = {"x": x, "y": y, "w": int(opt.get("w", 1)), "h": int(opt.get("h", 1)), "text": txt}
                if opt.get("cond"):                              # 시대·단계에 따라 다른 조사 글
                    check_cond(opt["cond"], known_vars, known_fns)
                    e["cond"] = opt["cond"]
                if opt.get("seq"):                               # 여러 번 조사: 글이 차례로 바뀌고, 다 읽으면 scene을 연다
                    e["seq"] = opt["seq"].split("|")
                if opt.get("scene"):
                    if opt["scene"] not in scenes:
                        raise Err(f"text의 장면 '{opt['scene']}'이 원고에 없다")
                    e["scene"] = opt["scene"]
                out["texts"].append(e)
            elif c == "sign":
                x, y, txt = int(pos[0]), int(pos[1]), pos[2]
                if kind[y][x] != "ftop":
                    raise Err(f"문패 ({x},{y})는 벽면 윗칸에 붙인다")
                e = {"x": x, "y": y, "text": txt}
                if opt.get("cond"):
                    check_cond(opt["cond"], known_vars, known_fns)
                    e["cond"] = opt["cond"]
                out["signs"].append(e)
            elif c == "trigger":
                x, y = int(pos[0]), int(pos[1])
                sc = opt.get("scene", "")
                if sc not in scenes:
                    raise Err(f"trigger의 장면 '{sc}'이 원고에 없다")
                e = {"x": x, "y": y, "w": int(opt.get("w", 1)), "h": int(opt.get("h", 1)), "scene": sc, "cond": opt.get("cond", ""),
                     "once": "once" in pos[2:]}
                if e["cond"]:
                    check_cond(e["cond"], known_vars, known_fns)
                if not any(floor(x + i, y + j) for i in range(e["w"]) for j in range(e["h"])):
                    raise Err(f"trigger ({x},{y}) 범위에 바닥이 없다")
                out["triggers"].append(e)
            elif c == "struct":                                  # struct 종류 x y w h [seed=] [args='{json}'] — 바깥 구조물(0-10)
                if not ext:
                    raise Err("struct는 바깥 맵(set r01)에서만 쓴다")
                sk, x, y, w, hh = pos[0], int(pos[1]), int(pos[2]), int(pos[3]), int(pos[4])
                if not (0 <= x and 0 <= y and x + w <= W and y + hh <= H):
                    raise Err(f"구조물 {sk} ({x},{y},{w}×{hh})가 맵 밖으로 나간다")
                e = {"kind": sk, "x": x, "y": y, "w": w, "h": hh, "seed": int(opt.get("seed", 0)),
                     "args": json.loads(opt["args"]) if opt.get("args") else {}}
                if opt.get("cond"):
                    check_cond(opt["cond"], known_vars, known_fns)
                    e["cond"] = opt["cond"]
                out["structs"].append(e)
            else:
                raise Err(f"모르는 명령 '{c}'")
        except (Err, IndexError, ValueError) as e:
            if os.environ.get("MAP_DEBUG") and not isinstance(e, Err):
                import traceback; traceback.print_exc()
            m.err(ln, str(e) if isinstance(e, Err) else f"인자가 모자라거나 틀렸다: {' '.join(words)}")
    if ext:
        _fi, _gf, _cv, level, grid = extra

        def link(x, y, nx, ny):
            return level[y][x] == level[ny][nx] or grid[y][x] in EXT_STAIR or grid[ny][nx] in EXT_STAIR
    # 막힘(소품 포함) 위에서 이어짐 검사
    block = [[1 if solid[y][x] else 0 for x in range(W)] for y in range(H)]
    for e in out["exits"]:
        block[e["y"]][e["x"]] = 0
    for d in out["doors"]:                                        # 잠긴 문은 이야기에서 열린다: 이어짐은 열린 것으로 본다
        block[d["y"]][d["x"]] = block[d["y"] + 1][d["x"]] = 0
    for p in out["props"]:                                        # 우리 문(1-3 H-03)도 이야기에서 열린다: 열린 것으로 본다
        if p["name"] == "cage_door":
            block[p["y"]][p["x"]] = 0
    start = None
    for y in range(H):
        for x in range(W):
            if not block[y][x]:
                start = (x, y)
                break
        if start:
            break
    seen = set()
    if start:
        q = deque([start])
        seen.add(start)
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if ext and 0 <= nx < W and 0 <= ny < H and not link(x, y, nx, ny):
                    continue
                if 0 <= nx < W and 0 <= ny < H and not block[ny][nx] and (nx, ny) not in seen:
                    seen.add((nx, ny))
                    q.append((nx, ny))
    free = sum(1 for y in range(H) for x in range(W) if not block[y][x])
    if free != len(seen):
        stray = [(x, y) for y in range(H) for x in range(W) if not block[y][x] and (x, y) not in seen][:6]
        m.err(1, f"갇힌 바닥이 있다(이어지지 않는 칸 {free - len(seen)}개, 예: {stray})")
    for n in out["npcs"]:
        for r in n["route"]:
            if (r[1], r[2]) not in seen:
                m.err(n["line"], f"인물 {n['id']} 일과 지점 {r[0]}에 갈 수 없다")
    staged = {(t["x"] + i, t["y"] + j) for t in out["texts"] if t.get("scene") or t.get("seq")
              for j in range(t["h"]) for i in range(t["w"])}
    cond_cells = {tuple(c) for p in out["props"] if p.get("cond") for c in p.get("cells", [])}
    for b in out["boxes"]:                                       # 용기가 장면 달린 조사 글을 가리면 장면을 못 연다
        cells = {(b["x"] + i, b["y"] + j) for j in range(b["h"]) for i in range(b["w"])}
        if cells & staged:
            m.err(1, f"용기 ({b['x']},{b['y']})가 장면이 달린 조사 글과 겹친다: {sorted(cells & staged)}")
        for (cx, cy) in cells:
            if not solid[cy][cx] and (cx, cy) not in cond_cells:          # 조건부 가구(거처 보관함 등) 위의 용기는 같은 조건으로 함께 선다
                m.err(1, f"용기 ({b['x']},{b['y']}) 칸 ({cx},{cy})에 가구가 없다(빈 바닥)")
    if ext:
        floor_ids, gflag, cover, level, grid = extra
        out["floor"] = floor_ids
        out["gflag"] = ["".join(str(v) for v in row) for row in gflag]
        out["cover"] = ["".join(str(v) for v in row) for row in cover]
        out["level"] = ["".join(str(v) if v >= 0 else "." for v in row) for row in level]
        out["stair"] = ["".join("1" if grid[y][x] in EXT_STAIR else "0" for x in range(W)) for y in range(H)]
    else:
        floor_ids, wall_ids = extra
        out["floor"] = floor_ids
        out["wall"] = wall_ids
        rows_ = [r for _, r in getattr(m, "rows", [])]
        if any(("f" in r or "F" in r) for r in rows_):                 # 1-D 침수 깊이(0 마름 · 1 발목 · 2 허리) — 이동 배수 · 웅크림(SD-09f §3.5)
            out["wet"] = ["".join("1" if c == "f" else ("2" if c == "F" else "0") for c in r) for r in rows_]
    out["solid"] = ["".join(str(min(1, v)) for v in row) for row in solid]
    return out


def compile_spots(prop_meta, known_vars, known_fns, scenes):
    """월드 발견 자리(1-4, maps/world/*.spots): 월드 위 작은 구역에 소품·조사 글·장면·용기·인물을 둔다(잠든 파수·길 위 유해·쪽지).
    spot L-ID w h [off=dx,dy] [cond=] — 장소 칸(+off) 둘레에서 w×h가 모두 걸어서 닿는 가장 가까운 자리(world_chunks가 고른다)
    spot @x,y w h — 월드 타일을 바로 찍는다(장소 없는 길가). 다음 spot까지의 명령은 그 구역 왼쪽 위 기준 좌표(맵 명령과 같은 문법).
    월드 땅은 굽기 전에는 모르니 구역 전체를 바닥으로 놓고 검사하고, 소품 발 칸은 실행 중 막힘(cells)으로 더한다."""
    out_all, errors = [], []
    places = json.load(open(os.path.join(ROOT, "game", "data", "world", "places.json"), encoding="utf-8"))
    for path in sorted(glob.glob(os.path.join(SRC, "world", "*.spots"))):
        m = MapSrc(path)
        blocks = []
        for ln, words in m.cmds:
            if words[0] == "spot":
                blocks.append((ln, words, []))
            elif not blocks:
                m.err(ln, "spot 줄보다 먼저 나온 명령")
            else:
                blocks[-1][2].append((ln, words))
        for ln, words, cmds in blocks:
            pos, opt = kv(words[1:])
            try:
                at, W, H = pos[0], int(pos[1]), int(pos[2])
            except (IndexError, ValueError):
                m.err(ln, "spot L-ID|@x,y w h 형식이 아니다")
                continue
            spec = {"w": W, "h": H, "line": ln, "file": os.path.basename(path)}
            if at.startswith("@"):
                xx, yy = at[1:].split(",")
                spec["tile"] = [int(xx), int(yy)]
                spec["key"] = "@%s,%s" % (xx, yy)
            else:
                if at not in places:
                    m.err(ln, f"모르는 장소 '{at}'")
                    continue
                spec["lid"] = at
                spec["key"] = at
                dx, dy = (int(v) for v in opt.get("off", "0,0").split(","))
                spec["tile"] = [places[at]["tx"] + dx, places[at]["ty"] + dy]
            if opt.get("cond"):
                check_cond(opt["cond"], known_vars, known_fns)
                spec["cond"] = opt["cond"]
            sub = MapSrc.__new__(MapSrc)
            sub.path, sub.errors, sub.cmds, sub.id, sub.name, sub.set = path, [], cmds, "W", "", "r01"
            out = {"id": "W", "name": "", "set": "r01", "size": [W, H], "props": [], "doors": [], "exits": [], "marks": {},
                   "npcs": [], "texts": [], "signs": [], "triggers": [], "enemies": [], "boxes": [], "terms": [], "structs": []}
            kind = [[None] * W for _ in range(H)]
            solid = [[0] * W for _ in range(H)]
            inb = lambda x, y: 0 <= x < W and 0 <= y < H
            out = _commands(sub, prop_meta, known_vars, known_fns, scenes, out, W, H, inb, kind, solid, inb,
                            extra=([[0] * W for _ in range(H)], [[0] * W for _ in range(H)]))
            for p in out["props"]:                                    # 월드 청크에는 이 소품이 없다: 발 칸을 실행 중 막힘으로
                pm = prop_meta[p["name"]]
                if "cells" not in p and pm["kind"] not in ("wall", "deco"):
                    fw, fh = pm["foot"]
                    p["cells"] = [[p["x"] + i, p["y"] + j] for j in range(max(1, fh)) for i in range(max(1, fw))]
            for k in ("floor", "wall", "solid"):
                out.pop(k, None)
            for k in ("doors", "signs", "structs", "exits"):
                if out.get(k):
                    sub.err(ln, f"발견 자리에는 {k}를 두지 않는다")
                out[k] = []
            for n in out["npcs"]:
                n.pop("line", None)
            errors += m.errors + sub.errors
            m.errors = []
            spec["data"] = out
            out_all.append(spec)
        errors += m.errors
    keys = [s["key"] for s in out_all]
    for k in set(keys):
        if keys.count(k) > 1:
            errors.append(f"발견 자리 겹침: {k}")
    return out_all, errors


def alias_of(npcs):
    """같은 사람이 C-ID와 N-ID 둘로 있을 때(SD-07a 주요 인물이 SD-07b 권역 표에도 실림) N-ID → C-ID."""
    by_name = {}
    for k, v in npcs.items():
        if k.startswith("C-"):
            by_name.setdefault(v.get("name", ""), k)
    return {k: by_name[v.get("name", "")] for k, v in npcs.items() if k.startswith("N-") and v.get("name", "") in by_name}


def main():
    prop_meta = dict(json.load(open(os.path.join(PROPS, "s07_props.json")))["props"])
    if os.path.exists(os.path.join(PROPS, "r01_props.json")):                  # 바깥 소품(0-10): 이름이 겹치지 않는다
        for k, v in json.load(open(os.path.join(PROPS, "r01_props.json")))["props"].items():
            if k in prop_meta:
                print("오류 소품 이름 겹침:", k); sys.exit(1)
            prop_meta[k] = v
    from script_compile import ENGINE_VARS                                 # 엔진이 선언하는 변수(PC_·MQP4_ 진행 표시 등)
    known_vars = set(json.load(open(os.path.join(ROOT, "game", "data", "vars.json")))["vars"]) | ENGINE_VARS
    for q in json.load(open(os.path.join(ROOT, "game", "data", "quests.json")))["quests"]:
        known_vars |= {q.replace("-", "") + s for s in ("_STAGE", "_RESULT", "_SKIP")}
    known_fns = set(__import__("script_compile").FNS)                                          # 원고 함수 목록은 script_compile.FNS 한 곳(1-X — 컴파일러마다 따로 두면 새 함수를 모른다)
    npcs = json.load(open(os.path.join(ROOT, "game", "data", "npcs.json")))["npcs"]
    from script_compile import UNNAMED                                  # 이름 없는 인물(떠돌이 고물상·수송대 호위·짐소 등)
    npcs = dict(npcs, **{k: {"name": v} for k, v in UNNAMED.items()})
    enemy_rows = json.load(open(os.path.join(ROOT, "game", "data", "enemies.json"), encoding="utf-8"))
    alias = alias_of(npcs)
    scenes = set(json.load(open(os.path.join(ROOT, "game", "data", "dialogue", "_index.json")))["scenes"])
    errors, maps = [], {}
    for path in sorted(glob.glob(os.path.join(SRC, "*", "*.map"))):
        m = MapSrc(path)
        out = compile_map(m, prop_meta, known_vars, known_fns, scenes)
        for n in (out or {}).get("npcs", []):
            if n["id"] in enemy_rows and "sheet" in n:                   # 이름 없는 주민(1-4: 지하시장 경비 CR-456 등) — 이름표는 직함
                continue
            if n["id"] not in npcs:
                m.err(n["line"], f"모르는 인물 ID {n['id']}(SD-07b)")
            elif n["id"] in alias:
                m.err(n["line"], f"{n['id']}는 주요 인물 {alias[n['id']]}와 같은 사람이다 — C-ID를 쓴다(초상화·대사가 C-ID에 붙는다)")
        errors += m.errors
        if out:
            fold = os.path.basename(os.path.dirname(path))
            out["region"] = fold.upper() if re.match(r"^r\d\d$", fold) else ""     # 루팅 등급 권역(1-4, SD-13 §9.2)
            if out["id"] in maps:
                errors.append(f"{path}: 맵 ID 겹침 {out['id']}")
            maps[out["id"]] = (out, m)
    places = json.load(open(os.path.join(ROOT, "game", "data", "world", "places.json"), encoding="utf-8"))
    for mid, (out, m) in maps.items():                           # 출구 → 갈 맵·표지가 있는지
        for e in out["exits"]:
            if e["to"] == "W":                                       # 월드로 나간다(1-3): 표지 = 장소 L-ID(그 장소의 도착 칸)
                if e["mark"] not in places:
                    m.err(e["line"], f"월드 출구 표지는 장소 L-ID여야 한다: '{e['mark']}'")
                    errors += m.errors[-1:]
            elif e["to"] not in maps:
                m.err(e["line"], f"출구가 모르는 맵 '{e['to']}'로 간다")
                errors += m.errors[-1:]
            elif e["mark"] not in maps[e["to"]][0]["marks"]:
                m.err(e["line"], f"출구가 '{e['to']}'의 없는 표지 '{e['mark']}'로 간다")
                errors += m.errors[-1:]
    spots, sp_err = compile_spots(prop_meta, known_vars, known_fns, scenes)
    errors += sp_err
    for e in errors:
        print("오류", e)
    if errors:
        sys.exit(1)
    os.makedirs(OUT, exist_ok=True)
    json.dump({"spots": spots}, open(os.path.join(ROOT, "game", "data", "world", "spots_src.json"), "w", encoding="utf-8"),
              ensure_ascii=False, separators=(",", ":"))
    index = {}
    for mid, (out, m) in sorted(maps.items()):
        for e in out["exits"]:
            e.pop("line", None)
        for n in out["npcs"]:
            n.pop("line", None)
        json.dump(out, open(os.path.join(OUT, mid + ".json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
        index[mid] = {"name": out["name"], "size": out["size"], "exits": sorted({e["to"] for e in out["exits"]})}
    ip = os.path.join(OUT, "_index.json")                              # 생성 실내(G-, gen.bin 묶음)는 굽기가 쓴 항목을 그대로 둔다(1-B — 맵 변환만 다시 돌려도 지워지지 않게)
    if os.path.exists(ip) and os.path.exists(os.path.join(OUT, "gen.bin")):
        old = json.load(open(ip, encoding="utf-8")).get("maps", {})
        index.update({k: v for k, v in old.items() if k.startswith("G-") and "pack" in v})
    json.dump({"maps": index}, open(ip, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"월드 발견 자리: {len(spots)}곳")
    print(f"맵: {len(maps)}장 — " + ", ".join(f"{k} {v['size'][0]}×{v['size'][1]}" for k, v in sorted(index.items())))


if __name__ == "__main__":
    main()
