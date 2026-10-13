"""데이터 파이프라인 v1 — 서류 UI 자료 (단계 0-4). 손 입력 0.
기획서 표 → game/data/documents.json
  record   : SD-10 §2.6 생활기록부 항목명 대응 + 담임 의견 문구(값 1~2 / 3~4 / 5~6 / 7~8 / 9~10)
  aptitude : SD-03a §7.3 적성 평가 10문항(①~④ 답과 점수 스킬, 10-④는 점수 없음)
  jobs     : SD-03a §7.3 1위 스킬 → 참고 적성 직무 · 차명수의 한마디
  names    : SD-18 §3.12.5 P1 풀(남 '서준'~'지안' / 여 '서아'~) · S-07 성씨 30개, §9.1.4 기본 성 '윤'
  banned   : SD-18 §2.3·§11.7 금칙 명칭(원고 변환기와 같은 목록) — 이름 칸 거부용
  ksx1001  : 한글 완성형 KS X 1001 2,350자(이름 칸 허용 글자, SD-18 §9.1.4)
오류는 '문서 · 줄 · 기대값'으로 보고하고 종료 코드 1."""
import os, re, sys, json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract import tables, DOCS, OUT
from script_compile import banned_terms

REPORT = []
STAT_OF = {"힘": "ST", "인지력": "PE", "지구력": "EN", "카리스마": "CH", "지능": "IN", "민첩성": "AG", "행운": "LK"}
SKILL_OF = {"물물교환": "BARTER", "중화기": "BIG_GUNS", "에너지 무기": "ENERGY", "폭발물": "EXPLOSIVES", "자물쇠 따기": "LOCKPICK",
            "의학": "MEDICINE", "근접 무기": "MELEE", "수리": "REPAIR", "과학": "SCIENCE", "소형 화기": "SMALL_GUNS", "은신": "SNEAK",
            "화술": "SPEECH", "비무장": "UNARMED"}


def err(doc, line, msg):
    REPORT.append(f"오류 {doc}:{line} {msg}")


def doc(name):
    return os.path.join(DOCS, name)


def plain(s):
    return s.replace("**", "").strip()


def record():
    src = "10_character-system.md"
    items, comments = {}, {}
    for section, line, header, rows in tables(doc(src)):
        if not section.startswith("### 2.6"):
            continue
        if header[:2] == ["S.P.E.C.I.A.L.", "생활기록부 항목"]:
            for ln, c in rows:
                items[STAT_OF[c[0]]] = c[1]
        if header[0] == "항목" and header[1:] == ["1~2", "3~4", "5~6", "7~8", "9~10"]:
            for ln, c in rows:
                comments[c[0]] = [plain(x) for x in c[1:6]]
    out = []
    for code in ("ST", "PE", "EN", "CH", "IN", "AG", "LK"):
        it = items.get(code)
        if it is None or it not in comments:
            err(src, 0, f"§2.6 {code} 항목·담임 의견이 없다")
            continue
        out.append({"stat": code, "item": it, "comments": comments[it]})
    return out


ANS_RE = re.compile(r"^(.*?)\s*→\s*\*\*(.+?)\*\*$")


def aptitude():
    src = "03a_main-story-part1.md"
    qs, jobs = [], {}
    for section, line, header, rows in tables(doc(src)):
        if not section.startswith("### 7.3"):
            continue
        if header[:2] == ["#", "문항(요지)"]:
            for ln, c in rows:
                opts = []
                for cell in c[2:6]:
                    m = ANS_RE.match(cell.strip())
                    if not m:
                        err(src, ln, f"답 칸 형식 '내용 → **스킬**' 아님: {cell}")
                        continue
                    sk = m.group(2).strip()
                    if sk != "점수 없음" and sk not in SKILL_OF:
                        err(src, ln, f"모르는 스킬 '{sk}'")
                    opts.append({"text": m.group(1).strip(), "skill": SKILL_OF.get(sk, "")})
                qs.append({"n": int(c[0]), "q": plain(c[1]), "opts": opts})
        if header[:2] == ["1위 스킬", "참고 적성 직무"]:
            for ln, c in rows:
                if c[0] not in SKILL_OF:
                    err(src, ln, f"모르는 스킬 '{c[0]}'")
                    continue
                jobs[SKILL_OF[c[0]]] = {"job": c[1], "line": c[2].strip("\"")}
    # 배점 검증(§7.3): 13개 스킬이 정확히 3번, 점수 없는 답 1개
    count = {}
    for q in qs:
        for o in q["opts"]:
            count[o["skill"]] = count.get(o["skill"], 0) + 1
    if len(qs) != 10 or any(count.get(k, 0) != 3 for k in SKILL_OF.values()) or count.get("", 0) != 1:
        err(src, 0, f"적성 배점 검증 실패(10문항·스킬마다 3번·점수 없음 1): {len(qs)}문항 {count}")
    if set(jobs) != set(SKILL_OF.values()):
        err(src, 0, f"직무표가 13스킬을 덮지 않는다: {sorted(set(SKILL_OF.values()) - set(jobs))}")
    return qs, jobs


def names():
    src = "18_naming-terms.md"
    text = open(doc(src), encoding="utf-8").read().split("\n")
    pool, surnames = None, None
    for i, l in enumerate(text):
        if l.startswith("**P1.") and i + 1 < len(text):
            pool = [w.strip() for w in text[i + 1].split(",")]
        if l.startswith("- S-07 성씨 30개:"):
            surnames = [w.strip() for w in l.split(":", 1)[1].split("(")[0].split(",")]
    if not pool or "서아" not in pool or not surnames or len(surnames) != 30:
        err(src, 0, "P1 풀(40) 또는 S-07 성씨 30개를 찾지 못했다")
        return {}
    k = pool.index("서아")
    return {"male": pool[:k], "female": pool[k:], "surnames": surnames, "default_surname": "윤"}


def ksx1001():
    out = []
    for cp in range(0xAC00, 0xD7A4):
        ch = chr(cp)
        try:
            if len(ch.encode("euc-kr")) == 2:
                out.append(ch)
        except UnicodeEncodeError:
            pass
    assert len(out) == 2350, len(out)
    return "".join(out)


def main():
    qs, jobs = aptitude()
    data = {"record": record(), "aptitude": qs, "jobs": jobs, "names": names(), "banned": banned_terms(), "ksx1001": ksx1001()}
    for r in REPORT:
        print(r)
    if REPORT:
        sys.exit(1)
    path = os.path.join(OUT, "documents.json")
    json.dump(data, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
    print(f"서류 자료: 생활기록부 {len(data['record'])}항목, 적성 {len(qs)}문항, 직무 {len(jobs)}, "
          f"이름 풀 {len(data['names']['male'])}+{len(data['names']['female'])}, 금칙 {len(data['banned'])}, 허용 글자 {len(data['ksx1001'])}")


if __name__ == "__main__":
    main()
