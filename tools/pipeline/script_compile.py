"""원고 변환기 v1 (SD-19 §9.3 단계 3·5): 대사 원고(script/**/*.txt) → 자동 검사 → 대화 그래프 JSON(game/data/dialogue/).

원고 형식(한 줄 = 한 명령. 빈 줄·`#`으로 시작하는 줄은 무시)
  @scene MQ-P1_S01  의무실  (L-R01-01)       장면 시작(ID · 제목 · 장소)
  @npc   C-025                                화술 판정 대상(없으면 그 장면 첫 화자). `@npc -` = 진행기·밟는 칸 장면(인물에 묶지 않는다)
  @cond  MQP1_STAGE == 10                     장면이 열리는 조건
  C-025 [미소] 건강해요. 울음소리 좋네.       대사: 화자 ID [표정] 문장   (화자 SYS = 해설, 표정 생략 = 기본)
  * 라벨                                      라벨(장면 첫 줄은 START)
  -> 라벨                                     이동(END = 장면 끝)
  ? 조건식 -> 라벨                            조건이 참이면 이동
  ! 효과식                                    효과(V_DOL = 3; karma(50); quest("MQ-P1", 30))
  @cmd 이름 인자...                            연출 명령(이벤트 실행기)
  > [태그]* 선택 문장 -> 성공 [| 실패] [?? 보이는 조건] [!! 효과]   선택지(연속한 > 줄이 한 묶음)
태그: [화술 아주 쉬움|쉬움|보통|어려움|아주 어려움] · [능력치 n] · [스킬 n] · [캡 n] · [물건: ID n] · [증거: ID] · [카르마] ·
      [관리자 인증] · [볼트 S-07] · [거짓말]·[위협](연출 표지). 한 선택지에 최대 2개(SD-12 §6.3).
문장 토큰(SD-18 N7): {변수|조사} · {변수} · {N:인물ID|조사} · {I:아이템ID|조사} · {L:장소ID|조사} → \\V[..]·\\N[..]·\\I[..]·\\L[..] + \\J[조사]

자동 검사(불합격이면 종료 코드 1): 토큰 문법·변수 선언·조사 짝, 화자 ID(SD-07b), 표정 키, 라벨, 식 구문·변수·함수, 장면 열림 조건(@cond) 필수,
창별 글자 수(SD-12 §14.5: 대사 1쪽 160자·2쪽 넘으면 오류, 선택지 80자), 금칙 명칭(SD-18 §2.3·§11.7, 옛 이름),
진영 결정 질문 문형(바이블 §5.8), 연출 명령 이름."""
import os, re, sys, json, glob, shlex

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import story_expr as SE
from extract import tables, DOCS

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "script")
OUT = os.path.join(ROOT, "game", "data", "dialogue")
DATA = os.path.join(ROOT, "game", "data")

EMOS = ["기본", "미소", "놀람", "분노", "슬픔", "피곤", "말함", "아픔"]
DIFFS = ["아주 쉬움", "쉬움", "보통", "어려움", "아주 어려움"]
STATS = ["힘", "인지력", "지구력", "카리스마", "지능", "민첩성", "행운"]
SKILLS = ["물물교환", "중화기", "에너지 무기", "폭발물", "자물쇠 따기", "의학", "근접 무기", "수리", "과학", "소형 화기", "은신", "화술",
          "비무장"]
FLAVORS = ["거짓말", "위협"]
PARTICLES = ["은", "는", "이", "가", "을", "를", "과", "와", "으로", "로", "이나", "나", "이랑", "랑", "아", "야", "이다", "다", "이에요",
             "예요", "이었", "였", "이라", "라", "이든", "든"]
FNS = {"karma", "aff", "quest", "stage", "result", "give", "take", "has", "caps", "xp", "wanted", "stat", "skill", "year"}
CMDS = {"wait", "fade_in", "fade_out", "balloon", "move", "face", "shake", "year_card", "title_card", "sfx", "bgm", "cam", "show",
        "hide", "pose", "doc", "flash", "lamp", "unlit", "note", "reveal",
        "pipboy", "equip", "hurt", "buddy", "range", "hint", "hud",          # 0-7: 핍-보이·무기·연출 피해·일시 동행·사격장 단계·안내 띠
        "refresh",                                                           # 0-8: 맵 인물을 지금 조건대로 다시 세운다
        "gate", "go", "pc", "escape", "unlock", "anim",                     # 0-9: 방폭문 · 기다리지 않는 이동 · 주인공 자리 · 탈출 진행기 · 문 열기
        "mq", "trade", "yd",                                                     # 0-10: 1막 진행기 사건 · 거래 창(상인 V번호)
        "meet", "memo", "obit",                                              # 1-2: 인물 수첩 등록 · 한 줄 메모 · 소식으로 안 죽음
        "re", "cage", "capture",                                             # 1-3: 인카운터 첫 분대 대화의 결말 · 우리 문 열기 · 생포(사흘 버팀)
        "jm", "yd", "sb", "vb"}                                                                # 1-4: 1막 경로 진행기(지하시장·단서) 사건                                             # 1-3: 인카운터 첫 분대 대화의 결말 · 우리 문 열기 · 생포(사흘 버팀)
ENGINE_VARS = {"PC_ST", "PC_PE", "PC_EN", "PC_CH", "PC_IN", "PC_AG", "PC_LK", "PC_TAG1", "PC_TAG2", "PC_TAG3", "PC_CAPS", "PC_XP",
               "PC_SEX", "PC_APT_PROXY",
               "MQP4_DUCT", "MQP4_FOLLOW", "MQP4_KEY", "MQP4_ARMORY", "MQP4_TALK", "MQP4_BJ_KO", "MQP4_SEC_KO", "MQP4_CAUGHT", "MQP4_DECOY",
               "S7_THEFT_SEEN", "S7_ASSAULT", "S7_KILLS",
               "MQ101_DOG", "MQ101_TRADE", "MQ101_WATER", "MQ101_RAD", "MQ101_NIGHT", "MQ101_DEAD", "MQ101_TANK", "MQ101_ROOF", "MQ101_LOAN",
               "MQ101_BOARD", "MQ101_FIGHT", "PC_RADS", "PD_BC", "PD_R01", "GAME_DAY", "PC_TORSO",
               "WANTED_DAY", "WANTED_KILL_SUM", "WANTED_AUTH_SUM", "WANTED_LOOK",                            # 1-3 수배도
               "CAPTURE_DAY", "CAPTURE_AT", "SB_COLLAR", "SB_CUFF", "CAPTURE_BY", "STAT_HACKED", "STAT_LOCKS",
               "MQ104_FIRE", "MQ104_DESK", "MQ104_IDS", "MQ104_SEEN", "MQ104_ROLL", "MQ104_LOG", "MQ104_FILES", "MQ104_RIFLE",
               "MQ104_AUTH", "MQ104_VENT", "MQ104_LAST", "MQ104_SEARCH", "MQ104_DOYUN", "MQ104_GUARDS", "MQ104_DAY",
               "PL_LETTER", "PL_VIEW", "PL_TECH",
               "MQ102_C1", "MQ102_C2", "MQ102_C3", "MQ102_ROBOT", "MQ103_GATE", "MQ103_JOB", "MQ103_HIRE", "MQ103_SNEAK",
               "MQ103_DOOR", "MQ103_CONF", "MQ103_LOG", "MQ103_AMBUSH", "MQ103_NEST", "MQ103_FOUNT", "JM_REG",
               "GAME_HOUR", "SB_RAID", "SB_PASS", "SB_DOGS", "SB_SAFE", "SB_KEY", "SB_FREED", "SB_READ", "SB_DEAL",
               "SB_BURNT", "SB_DEBT", "SB_BJ", "SB_TALK", "SB_BOUGHT", "SB_DEPO", "SB_127", "GB_PASS",
               "MQ106_CUSTODY", "MQ106_TALKED", "MQ106_SEIZED", "MQ106_AT", "MQ106_QLINE", "MQ106_QWHY", "MQ106_QGRID", "MQ106_QDEAD",
               "PD_R01_BJ", "WANTED_HOLD"}                                                        # 1-6 MQ-105             # 1-3 생포 · 1-4 해킹 통계
DECISION = ["어느 편에 서겠", "편에 서겠습니까", "제안을 수락", "받아들이겠습니까", "어느 쪽을 택하", "누구 편이"]
OLD_NAMES = ["강태오", "천웨이", "국민방송"]
PAGE = 160
CHOICE_MAX = 80


def banned_terms():
    """SD-18 §2.3 사용 금지 실명(예 칸)과 §11.7 금칙 범주의 예 → 금칙어. 설명 문구는 뺀다."""
    words = set(OLD_NAMES)
    skip = re.compile(r"실제|전부|같은|이름|인물명|명칭|계열|약칭|조합|호칭|고유명|낮잡|멸칭|뜻|말$|^등$|단체명|교단명|교회명|사찰명|국호|지도자|조직명|제호")
    for section, line, header, rows in tables(os.path.join(DOCS, "18_naming-terms.md")):
        col = None
        if section.startswith("### 2.3") and len(header) >= 3:
            col = 2
        if "예(일부)" in header:
            col = header.index("예(일부)")
        if col is None:
            continue
        for ln, cells in rows:
            if len(cells) <= col:
                continue
            if cells[0].strip() in ("X1", "X2", "X16", "X18", "X19", "X20", "X21") or re.search(r"전부|낮잡|모욕|빗댄|§", cells[col]):
                continue                                             # 범주 설명뿐인 칸(실명 목록이 아님)
            for w in re.split(r"[,·]", re.sub(r"\(.*?\)", "", cells[col])):
                w = w.strip().strip("'\"")
                if len(w) < 2 or skip.search(w) or w.endswith("등"):
                    continue
                words.add(w)
    return sorted(words)


class Report:
    def __init__(self):
        self.errors, self.warns = [], []

    def err(self, where, msg):
        self.errors.append(f"오류 {where} {msg}")

    def warn(self, where, msg):
        self.warns.append(f"경고 {where} {msg}")


TOKEN = re.compile(r"\{([^{}]*)\}")


class Ctx:
    def __init__(self):
        self.vars = set(json.load(open(os.path.join(DATA, "vars.json")))["vars"]) | ENGINE_VARS
        self.npcs = json.load(open(os.path.join(DATA, "npcs.json")))["npcs"]
        for cid, row in json.load(open(os.path.join(DATA, "enemies.json"))).items():   # 무명 적 템플릿도 화자(1-3: 추적대 첫 분대, 이름표는 직함)
            self.npcs.setdefault(cid, {"name": row.get("name", cid), "unnamed": True})
        self.banned = banned_terms()
        self.rep = Report()


def conv_text(text, where, cx):
    """원고 문장 → 엔진 문장(제어 코드). 반환: (문장, 화면 길이 추정)."""
    if "\\" in text.replace("\\.", ""):
        cx.rep.err(where, "원고에 역슬래시 제어 코드를 직접 쓰지 않는다(토큰 {..|..}을 쓴다. 줄바꿈 금지 공백 \\.만 허용)")
    out, est, pos = "", 0, 0
    for m in TOKEN.finditer(text):
        out += text[pos:m.start()]
        est += len(text[pos:m.start()])
        pos = m.end()
        body = m.group(1)
        name, _, part = body.partition("|")
        if part and part not in PARTICLES:
            cx.rep.err(where, f"조사 짝이 아니다: {{{body}}}")
        if ":" in name:
            kind, _, ident = name.partition(":")
            if kind == "N":
                if ident not in cx.npcs:
                    cx.rep.err(where, f"없는 인물 ID: {ident}")
                out += f"\\N[{ident}]"
                est += len(cx.npcs.get(ident, {}).get("name", "XXX"))
            elif kind in ("I", "L"):
                out += f"\\{kind}[{ident}]"
                est += 6
            else:
                cx.rep.err(where, f"알 수 없는 토큰 종류: {{{body}}}")
        else:
            if name not in cx.vars:
                cx.rep.err(where, f"미선언 변수 토큰: {{{body}}}")
            out += f"\\V[{name}]"
            est += 4
        if part:
            out += f"\\J[{part}]"
            est += len(part)
    out += text[pos:]
    est += len(text[pos:])
    if "{" in out or "}" in out:
        cx.rep.err(where, "닫히지 않은 토큰 괄호")
    for w in cx.banned:
        if w.isascii():
            hit = re.search(rf"(?<![A-Za-z0-9]){re.escape(w)}(?![A-Za-z0-9])", text)
        elif len(w) == 2:                                             # 두 글자 한글은 어절 경계에서만(조사 '이든' 같은 오탐 방지)
            hit = re.search(rf"(?<![가-힣]){re.escape(w)}(?![가-힣])", text)
        else:
            hit = w in text
        if hit:
            cx.rep.err(where, f"금칙 명칭: {w}")
    for p in DECISION:
        if p in text:
            cx.rep.err(where, f"진영 결정 질문 문형: '{p}'")
    return out, est


def check_expr(src, where, cx, effect=False):
    try:
        ast = SE.parse(src)
    except SyntaxError as e:
        cx.rep.err(where, f"식 구문: {src} — {e}")
        return
    vs, calls = SE.names(ast)
    for v in vs:
        if v not in cx.vars:
            cx.rep.err(where, f"미선언 변수: {v}")
    for c in calls:
        if c not in FNS:
            cx.rep.err(where, f"알 수 없는 함수: {c}()")
    if not effect and any(isinstance(s, list) and s[0] == "set" for s in ast[1:]):
        cx.rep.err(where, f"조건식에 대입이 있다: {src}")


TAG = re.compile(r"^\[([^\]]+)\]\s*")


def parse_tags(text, where, cx):
    tags = []
    while True:
        m = TAG.match(text)
        if not m:
            break
        t = m.group(1).strip()
        text = text[m.end():]
        if t.startswith("화술 "):
            d = t[3:].strip()
            if d.endswith("%"):
                cx.rep.err(where, f"[{t}]: 화술 확률은 난이도로 쓴다(실행 중 계산)")
            elif d not in DIFFS:
                cx.rep.err(where, f"[{t}]: 난이도는 {DIFFS}")
            tags.append({"k": "speech", "skill": "화술", "diff": d})
        elif t.startswith("캡 "):
            tags.append({"k": "caps", "n": int(t[2:])})
        elif t.startswith("물건:"):
            parts = t[3:].split()
            tags.append({"k": "item", "id": parts[0], "n": int(parts[1]) if len(parts) > 1 else 1})
        elif t.startswith("증거:"):
            tags.append({"k": "evidence", "id": t[3:].strip()})
        elif t == "카르마":
            tags.append({"k": "karma"})
        elif t == "관리자 인증":
            tags.append({"k": "admin"})
        elif t == "볼트 S-07":
            tags.append({"k": "vault"})
        elif t in FLAVORS:
            tags.append({"k": "flavor", "text": t})
        else:
            m2 = re.match(r"^(.+?)\s+(\d+)$", t)
            if m2 and m2.group(1) in STATS:
                tags.append({"k": "stat", "name": m2.group(1), "min": int(m2.group(2))})
            elif m2 and m2.group(1) in SKILLS:
                tags.append({"k": "skill", "name": m2.group(1), "min": int(m2.group(2))})
            else:
                cx.rep.err(where, f"알 수 없는 태그 [{t}]")
    if len(tags) > 2:
        cx.rep.err(where, f"선택지 태그는 최대 2개(지금 {len(tags)})")
    return tags, text


def compile_file(path, cx):
    rel = os.path.relpath(path, ROOT)
    scenes, sc = [], None
    pending = None                        # 모으는 중인 선택지 op
    n_choice = 0

    def flush():
        nonlocal pending
        if pending is not None:
            sc["ops"].append(pending)
            pending = None

    for ln, raw in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
        line = raw.rstrip()
        where = f"{rel}:{ln}"
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line.startswith(">"):
            flush()
        if line.startswith("@scene"):
            parts = line.split(None, 2)
            sid = parts[1] if len(parts) > 1 else ""
            rest = parts[2] if len(parts) > 2 else ""
            m = re.search(r"\((L-[^)]+)\)\s*$", rest)
            sc = {"id": sid, "title": rest[:m.start()].strip() if m else rest.strip(), "loc": m.group(1) if m else "",
                  "npc": "", "cond": "", "labels": {"START": 0}, "ops": [], "src": rel, "_refs": [], "_first": ""}
            scenes.append(sc)
            n_choice = 0
            continue
        if sc is None:
            cx.rep.err(where, "@scene 앞에 내용이 있다")
            continue
        if line.startswith("@npc"):
            sc["npc"] = line.split(None, 1)[1].strip()
            if sc["npc"] == "-":                                   # 0-9: 진행기·밟는 칸 장면 — 어느 인물에게도 묶지 않는다
                sc["npc"] = ""
                sc["_nonpc"] = True
            elif sc["npc"] not in cx.npcs:
                cx.rep.err(where, f"없는 인물 ID: {sc['npc']}")
        elif line.startswith("@cond"):
            sc["cond"] = line.split(None, 1)[1].strip()
            check_expr(sc["cond"], where, cx)
        elif line.startswith("@cmd"):
            try:
                parts = shlex.split(line)[1:]                       # "따옴표 안 공백"은 인자 하나
            except ValueError as e:
                cx.rep.err(where, f"연출 명령 인자: {e}")
                continue
            if not parts or parts[0] not in CMDS:
                cx.rep.err(where, f"알 수 없는 연출 명령: {parts[:1]}")
            sc["ops"].append({"op": "cmd", "name": parts[0] if parts else "", "args": parts[1:]})
        elif line.startswith("* "):
            lab = line[2:].strip()
            if lab in sc["labels"] and not (lab == "START" and sc["labels"]["START"] == len(sc["ops"])):
                cx.rep.err(where, f"라벨 중복: {lab}")
            sc["labels"][lab] = len(sc["ops"])
        elif line.startswith("-> "):
            to = line[3:].strip()
            sc["ops"].append({"op": "goto", "to": to})
            sc["_refs"].append((to, where))
        elif line.startswith("? "):
            m = re.match(r"^\?\s+(.+?)\s+->\s+(\S+)\s*$", line)
            if not m:
                cx.rep.err(where, "조건 이동 형식: ? 조건 -> 라벨")
                continue
            check_expr(m.group(1), where, cx)
            sc["ops"].append({"op": "if", "cond": m.group(1), "to": m.group(2)})
            sc["_refs"].append((m.group(2), where))
        elif line.startswith("! "):
            fx = line[2:].strip()
            check_expr(fx, where, cx, effect=True)
            sc["ops"].append({"op": "do", "fx": fx})
        elif line.startswith(">"):
            body = line[1:].strip()
            fx = cond = ""
            if " !! " in body:
                body, fx = body.split(" !! ", 1)
                check_expr(fx.strip(), where, cx, effect=True)
            if " ?? " in body:
                body, cond = body.split(" ?? ", 1)
                check_expr(cond.strip(), where, cx)
            if " -> " not in body:
                cx.rep.err(where, "선택지에 -> 이동이 없다")
                continue
            body, target = body.rsplit(" -> ", 1)
            to, _, fail = target.partition("|")
            tags, text = parse_tags(body.strip(), where, cx)
            etext, est = conv_text(text.strip(), where, cx)
            if est > CHOICE_MAX:
                cx.rep.err(where, f"선택지 {est}자 > {CHOICE_MAX}")
            elif est > 40:
                cx.rep.warn(where, f"선택지 {est}자(권장 40자 이내)")
            if pending is None:
                pending = {"op": "choice", "opts": []}
                n_choice += 1
            opt = {"text": etext, "tags": tags, "cond": cond.strip(), "fx": fx.strip(), "to": to.strip(),
                   "id": f"{sc['id']}:{n_choice}:{len(pending['opts'])}"}
            if fail.strip():
                opt["fail"] = fail.strip()
                sc["_refs"].append((fail.strip(), where))
            elif any(t["k"] == "speech" for t in tags):
                cx.rep.err(where, "화술 판정 선택지에는 실패 이동(| 라벨)이 있어야 한다")
            sc["_refs"].append((to.strip(), where))
            pending["opts"].append(opt)
        else:
            m = re.match(r"^(SYS|CR-\d+|[CN]-[A-Z0-9]+(?:-[0-9]+)?)\s+(?:\[([^\]]+)\]\s*)?(.+)$", line)
            if not m:
                cx.rep.err(where, f"알 수 없는 줄: {line[:30]}")
                continue
            who, emo, text = m.group(1), m.group(2) or "기본", m.group(3)
            if who != "SYS" and who not in cx.npcs:
                cx.rep.err(where, f"없는 화자 ID: {who}")
            if emo not in EMOS:
                cx.rep.err(where, f"표정 키 [{emo}]는 {EMOS} 중 하나")
            etext, est = conv_text(text, where, cx)
            if est > PAGE * 2:
                cx.rep.err(where, f"대사 {est}자 > 2쪽({PAGE * 2}자)")
            elif est > PAGE:
                cx.rep.warn(where, f"대사 {est}자: 2쪽으로 나뉜다")
            if who != "SYS" and not sc["_first"]:
                sc["_first"] = who
            sc["ops"].append({"op": "line", "who": who, "emo": emo, "text": etext})
    flush()
    for s in scenes:
        for to, where in s.pop("_refs"):
            if to != "END" and to not in s["labels"]:
                cx.rep.err(where, f"없는 라벨: {to}")
        first = s.pop("_first")
        if not s["npc"] and not s.pop("_nonpc", False):
            s["npc"] = first
        if not s["cond"]:                                          # 0-8: 2268 장면이 2274년 차명수에게 다시 열렸다
            cx.rep.err(f"{s['src']} {s['id']}", "@cond가 없다 — 그 인물에게 말을 걸면 어느 시대든 이 장면이 다시 열린다")
        s["ops"].append({"op": "end"})
    return scenes


def main():
    cx = Ctx()
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, "*.json")):
        os.remove(f)
    ids, total = {}, 0
    for path in sorted(glob.glob(os.path.join(SRC, "**", "*.txt"), recursive=True)):
        if os.sep + "terms" + os.sep in path or os.sep + "world" + os.sep in path or os.sep + "notes" + os.sep in path:   # 단말 원고(1-4)는 term_compile, 길 위 쪽지(1-4f)는 world_chunks가 읽는다
            continue
        for s in compile_file(path, cx):
            if s["id"] in ids:
                cx.rep.err(s["src"], f"장면 ID 중복: {s['id']} ({ids[s['id']]})")
            ids[s["id"]] = s["src"]
            total += sum(1 for o in s["ops"] if o["op"] == "line")
            json.dump(s, open(os.path.join(OUT, s["id"] + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump({"scenes": sorted(ids)}, open(os.path.join(OUT, "_index.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    head = f"원고 변환 v1: 장면 {len(ids)}, 대사 {total}줄 | 오류 {len(cx.rep.errors)}, 경고 {len(cx.rep.warns)}"
    open(os.path.join(DATA, "_script_report.txt"), "w", encoding="utf-8").write("\n".join([head] + cx.rep.errors + cx.rep.warns) + "\n")
    print(head)
    for e in cx.rep.errors[:30]:
        print(" ", e)
    return 1 if cx.rep.errors else 0


if __name__ == "__main__":
    sys.exit(main())
