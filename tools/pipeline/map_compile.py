"""실내 맵 변환기 (단계 0-5): maps/<세트>/*.map → game/data/maps/<맵 ID>.json. 오류는 '파일:줄 내용'으로 보고하고 종료 코드 1.

원고 형식 (한 줄에 하나, # 뒤는 주석):
  map V-08 의무과                맵 ID와 이름
  set s07                        타일셋·소품 묶음(지금은 s07)
  grid … end                     글자 격자. 모든 줄 길이가 같아야 한다.
     # 또는 공백 = 벽(자동: 아래가 바닥이면 벽면 아랫칸, 두 칸 아래가 바닥이면 벽면 윗칸, 아니면 벽 윗면 + 테)
     . 철판  , 장판  o 진료실 타일  = 격자  ~ 콘크리트  c 카펫  w 마루  m·M 곰팡이 핀 철판·격자
     - | + ^  바닥 유도선(가로·세로·교차·T자)
  prop 이름 x y                  소품(발 칸 왼쪽 위). 벽 소품(wall)은 벽면 윗칸에 건다.
  door x y [kind=slide|hatch|iron] [locked] ["표지"]
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
                                 용기(SD-12 §7.3, 0-9): 그 칸(보통 소품)을 조사하면 2단 창. 종류 = loot_s07.json 표. owner가 있으면
                                 [소유](꺼내면 절도), lock이면 [자물쇠 따기 n] 판정 뒤 열린다.
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

LOOK_RE = re.compile(r"^(M1|M2|F1|F2|E1|E2|K1)-S[1-6G][12]?-HR\d\d-H\d-T\d\d-\d-PF\d\d-HD\d\d-EY\d\d(-PR\d+)?$")


def look_sheet(code):
    """외형 코드 → 이야기 인물 시트 이름(story_sprites와 같은 규칙)."""
    return "st_look_" + code.lower().replace("-", "_")

SRC = os.path.join(ROOT, "maps")
OUT = os.path.join(ROOT, "game", "data", "maps")
TIL = os.path.join(ROOT, "game", "assets", "tiles")
PROPS = os.path.join(ROOT, "game", "assets", "props")
FLOOR = {".": "panel", ",": "lino_a", "o": "clinic_a", "=": "grate_a", "~": "concrete_a", "c": "carpet_a", "w": "wood_a",
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
        self.cmds = []                                             # (줄, [낱말])
        lines = open(path, encoding="utf-8").read().split("\n")
        i = 0
        while i < len(lines):
            raw = lines[i]
            ln = i + 1
            i += 1
            s = raw.split(" #")[0].rstrip() if not raw.lstrip().startswith("#") else ""
            if raw.strip() == "grid":
                while i < len(lines) and lines[i].rstrip() != "end":
                    self.rows.append((i + 1, lines[i].rstrip("\n")))
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


def compile_map(m, prop_meta, known_vars, known_fns, scenes=()):
    if not m.rows:
        m.err(1, "grid가 없다")
        return None
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
    wt = tiles("s07_wall")
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
           "npcs": [], "texts": [], "signs": [], "triggers": [], "enemies": [], "boxes": []}
    loot_kinds = set(json.load(open(os.path.join(ROOT, "game", "data", "loot_s07.json"), encoding="utf-8"))["tables"].keys())
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
                            if not cond:
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
                out["doors"].append({"x": x, "y": y, "kind": "door_" + k, "label": label, "locked": locked})
            elif c == "exit":
                x, y, to, mk = int(pos[0]), int(pos[1]), pos[2], pos[3]
                if not floor(x, y):
                    raise Err(f"출구 칸 ({x},{y})이 바닥이 아니다")
                out["exits"].append({"x": x, "y": y, "to": to, "mark": mk, "line": ln})
            elif c == "mark":
                name, x, y, d = pos[0], int(pos[1]), int(pos[2]), pos[3]
                if d not in DIRS:
                    raise Err(f"모르는 방향 '{d}'")
                if not floor(x, y):
                    raise Err(f"표지 '{name}' ({x},{y})가 바닥이 아니다")
                out["marks"][name] = [x, y, d]
            elif c == "npc":
                nid, x, y, d = pos[0], int(pos[1]), int(pos[2]), pos[3]
                e = {"id": nid, "x": x, "y": y, "dir": d, "route": [], "cond": opt.get("cond", ""), "bark": opt.get("bark", "")}
                if not floor(x, y):
                    raise Err(f"인물 {nid} 자리 ({x},{y})가 바닥이 아니다")
                if e["cond"]:
                    check_cond(e["cond"], known_vars, known_fns)
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
                    if not floor(rx, ry):
                        raise Err(f"일과 지점 {mm.group(1)} ({rx},{ry})가 바닥이 아니다")
                    e["route"].append([mm.group(1), rx, ry, float(mm.group(4) or 4)])
                e["line"] = ln
                out["npcs"].append(e)
            elif c == "enemy":                                   # enemy ID x y [cond=] — 적(SD-14), 조건이 맞을 때만 선다
                eid, x, y = pos[0], int(pos[1]), int(pos[2])
                if eid not in enemy_ids:
                    raise Err(f"적 자료(enemies.json)에 없는 ID '{eid}'")
                if not floor(x, y) or solid[y][x]:
                    raise Err(f"적 {eid} 자리 ({x},{y})가 빈 바닥이 아니다")
                e = {"id": eid, "x": x, "y": y, "cond": opt.get("cond", "")}
                if e["cond"]:
                    check_cond(e["cond"], known_vars, known_fns)
                for k in ("arm", "who", "dir", "stance"):              # 0-9: 든 무기(baton|pistol) · 인물 ID(이름표) · 처음 방향 · hold(제자리)
                    if opt.get(k):
                        e[k] = opt[k]
                if opt.get("route"):                                   # 순찰 경로: x,y,초;… (닿으면 그 초만큼 서서 둘러본다)
                    e["route"] = []
                    for part in [p for p in opt["route"].split(";") if p]:
                        mm = re.match(r"^(\d+),(\d+)(?:,(\d+(?:\.\d+)?))?$", part)
                        if not mm:
                            raise Err(f"순찰 route 형식 'x,y,초' 아님: {part}")
                        rx, ry = int(mm.group(1)), int(mm.group(2))
                        if not floor(rx, ry) or solid[ry][rx]:
                            raise Err(f"순찰 지점 ({rx},{ry})가 빈 바닥이 아니다")
                        e["route"].append([rx, ry, float(mm.group(3) or 2)])
                out["enemies"].append(e)
            elif c == "box":                                     # box x y 종류 [w= h=] [owner=] [lock=] [name=] [cond=] — 용기(0-9)
                x, y, kind = int(pos[0]), int(pos[1]), pos[2]
                if kind not in loot_kinds:
                    raise Err(f"모르는 용기 종류 '{kind}'(loot_s07.json: {sorted(loot_kinds)})")
                e = {"x": x, "y": y, "w": int(opt.get("w", 1)), "h": int(opt.get("h", 1)), "kind": kind,
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
            else:
                raise Err(f"모르는 명령 '{c}'")
        except (Err, IndexError, ValueError) as e:
            m.err(ln, str(e) if isinstance(e, Err) else f"인자가 모자라거나 틀렸다: {' '.join(words)}")
    # 막힘(소품 포함) 위에서 이어짐 검사
    block = [[1 if solid[y][x] else 0 for x in range(W)] for y in range(H)]
    for e in out["exits"]:
        block[e["y"]][e["x"]] = 0
    for d in out["doors"]:                                        # 잠긴 문은 이야기에서 열린다: 이어짐은 열린 것으로 본다
        block[d["y"]][d["x"]] = block[d["y"] + 1][d["x"]] = 0
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
    for b in out["boxes"]:                                       # 용기가 장면 달린 조사 글을 가리면 장면을 못 연다
        cells = {(b["x"] + i, b["y"] + j) for j in range(b["h"]) for i in range(b["w"])}
        if cells & staged:
            m.err(1, f"용기 ({b['x']},{b['y']})가 장면이 달린 조사 글과 겹친다: {sorted(cells & staged)}")
        for (cx, cy) in cells:
            if not solid[cy][cx]:
                m.err(1, f"용기 ({b['x']},{b['y']}) 칸 ({cx},{cy})에 가구가 없다(빈 바닥)")
    out["floor"] = floor_ids
    out["wall"] = wall_ids
    out["solid"] = ["".join(str(min(1, v)) for v in row) for row in solid]
    return out


def alias_of(npcs):
    """같은 사람이 C-ID와 N-ID 둘로 있을 때(SD-07a 주요 인물이 SD-07b 권역 표에도 실림) N-ID → C-ID."""
    by_name = {}
    for k, v in npcs.items():
        if k.startswith("C-"):
            by_name.setdefault(v.get("name", ""), k)
    return {k: by_name[v.get("name", "")] for k, v in npcs.items() if k.startswith("N-") and v.get("name", "") in by_name}


def main():
    prop_meta = json.load(open(os.path.join(PROPS, "s07_props.json")))["props"]
    from script_compile import ENGINE_VARS                                 # 엔진이 선언하는 변수(PC_·MQP4_ 진행 표시 등)
    known_vars = set(json.load(open(os.path.join(ROOT, "game", "data", "vars.json")))["vars"]) | ENGINE_VARS
    for q in json.load(open(os.path.join(ROOT, "game", "data", "quests.json")))["quests"]:
        known_vars |= {q.replace("-", "") + s for s in ("_STAGE", "_RESULT", "_SKIP")}
    known_fns = {"karma", "aff", "quest", "stage", "result", "give", "take", "has", "caps", "xp", "wanted", "stat", "skill", "year"}
    npcs = json.load(open(os.path.join(ROOT, "game", "data", "npcs.json")))["npcs"]
    alias = alias_of(npcs)
    scenes = set(json.load(open(os.path.join(ROOT, "game", "data", "dialogue", "_index.json")))["scenes"])
    errors, maps = [], {}
    for path in sorted(glob.glob(os.path.join(SRC, "*", "*.map"))):
        m = MapSrc(path)
        out = compile_map(m, prop_meta, known_vars, known_fns, scenes)
        for n in (out or {}).get("npcs", []):
            if n["id"] not in npcs:
                m.err(n["line"], f"모르는 인물 ID {n['id']}(SD-07b)")
            elif n["id"] in alias:
                m.err(n["line"], f"{n['id']}는 주요 인물 {alias[n['id']]}와 같은 사람이다 — C-ID를 쓴다(초상화·대사가 C-ID에 붙는다)")
        errors += m.errors
        if out:
            if out["id"] in maps:
                errors.append(f"{path}: 맵 ID 겹침 {out['id']}")
            maps[out["id"]] = (out, m)
    for mid, (out, m) in maps.items():                           # 출구 → 갈 맵·표지가 있는지
        for e in out["exits"]:
            if e["to"] not in maps:
                m.err(e["line"], f"출구가 모르는 맵 '{e['to']}'로 간다")
                errors += m.errors[-1:]
            elif e["mark"] not in maps[e["to"]][0]["marks"]:
                m.err(e["line"], f"출구가 '{e['to']}'의 없는 표지 '{e['mark']}'로 간다")
                errors += m.errors[-1:]
    for e in errors:
        print("오류", e)
    if errors:
        sys.exit(1)
    os.makedirs(OUT, exist_ok=True)
    index = {}
    for mid, (out, m) in sorted(maps.items()):
        for e in out["exits"]:
            e.pop("line", None)
        for n in out["npcs"]:
            n.pop("line", None)
        json.dump(out, open(os.path.join(OUT, mid + ".json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
        index[mid] = {"name": out["name"], "size": out["size"], "exits": sorted({e["to"] for e in out["exits"]})}
    json.dump({"maps": index}, open(os.path.join(OUT, "_index.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"맵: {len(maps)}장 — " + ", ".join(f"{k} {v['size'][0]}×{v['size'][1]}" for k, v in sorted(index.items())))


if __name__ == "__main__":
    main()
