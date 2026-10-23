"""대화 초상화 내보내기 (SD-16 §8, 아이작풍 v2.0): 원고에 나오는 화자마다 표정 8종 96×96(투명 바탕) → game/assets/portraits/.
외형은 SD-07b 외형 코드(npcs.json look)를 chibi.Look.parse로 읽는다. 사람이 아닌 화자(진돗개 AN-·로봇 RB-·변종 BY-)는 건너뛴다.
이미 같은 그림이 있으면 다시 쓰지 않는다(빌드 시간). 팔레트 밖 색이 나오면 실패."""
import os, sys, json, glob
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import chibi as K
import palette as P

OUT = os.path.join(ROOT, "game", "assets", "portraits")
DATA = os.path.join(ROOT, "game", "data")
EMOS = list(K.PORTRAIT_EXPR)
ALLOWED = None


def main():
    global ALLOWED
    os.makedirs(OUT, exist_ok=True)
    npcs = json.load(open(os.path.join(DATA, "npcs.json")))["npcs"]
    speakers = set()
    for f in glob.glob(os.path.join(DATA, "dialogue", "*.json")):
        if os.path.basename(f).startswith("_"):
            continue
        for op in json.load(open(f))["ops"]:
            if op["op"] == "line" and op["who"] != "SYS":
                speakers.add(op["who"])
    for f in glob.glob(os.path.join(DATA, "maps", "*.json")):           # 실내 맵 인물도 말을 건다(단계 0-5 바크)
        if not os.path.basename(f).startswith("_"):
            speakers |= {n["id"] for n in json.load(open(f, encoding="utf-8")).get("npcs", [])}
    looks = {}                                                        # 맵에서 look=으로 다른 모습(시대)으로 선 인물: 시트 이름 → 외형
    for f in glob.glob(os.path.join(DATA, "maps", "*.json")):
        if not os.path.basename(f).startswith("_"):
            looks |= {n["sheet"]: n["look"] for n in json.load(open(f, encoding="utf-8")).get("npcs", []) if n.get("look")}
    made, skipped, index = 0, [], {}
    import pack as PK                                                 # 무명 적 템플릿 화자(CR-, 1-3 추적대 첫 분대): 적 시트와 같은 외형
    en_look = {nm.split("_")[1].upper().replace("CR", "CR-"): code for nm, code, _w in PK.ENEMIES if nm.startswith("en_cr")}
    sheet_look = {nm: code for nm, code, _w in PK.ENEMIES}
    en_look |= {"N-YT-1": sheet_look["en_cr421_loco"], "N-YT-2": sheet_look["en_cr420b_loco"]}   # 1-11b 무명 패거리 화자: 진행기가 세우는 그 그림(수금원 · 척후)과 같은 얼굴
    en_look |= {"N-BJ-S1": sheet_look["en_cr403_loco"], "N-BJ-S2": sheet_look["en_cr401_loco"],      # 계엄군 수색조(1-11c · 1-11f) · 여의도 순찰(1-11j): 진행기가 세우는 분대장 · 계엄병 얼굴
               "N-BJ-P1": sheet_look["en_cr403_loco"], "N-BJ-P2": sheet_look["en_cr401_loco"],
               "N-BJ-C1": sheet_look["en_cr403_loco"], "N-SB-R1": sheet_look["en_cr435_loco"],
               "N-SB-L1": sheet_look["en_cr438_loco"], "N-SB-H1": sheet_look["en_cr435_loco"], "N-JY-P1": sheet_look["en_cr452_loco"],
               "N-ND-G1": sheet_look["en_downed_loco"],
               "N-GA-T1": sheet_look["en_cr423_loco"], "N-BJ-C2": sheet_look["en_cr403_loco"], "N-DS-E1": sheet_look["en_cr401_loco"], "N-DS-E2": sheet_look["en_cr401_loco"]}   # 1-12n 가산 셈꾼(2층 거래 자리 CR-423) · 1-12g UQ-03 대리 분대장 · RE-104 탈영병   # 1-12f FQ-SB-02 인솔 반장 · 출장소 인수원 · 방범대 조장 · 노들 남문 경비   # 1-12e FQ-JH-03 다리목 분대장 · 새벽인력 모집원
    for sid in sorted(speakers) + sorted(looks):
        look = looks.get(sid) or npcs.get(sid, {}).get("look", "") or en_look.get(sid, "")
        if not look or look.split("-")[0] in ("AN", "RB", "BY", "OBJ") or "·" in look:
            skipped.append(sid)
            continue
        lk = K.Look.parse(look)
        index[sid] = {}
        for emo in EMOS:
            name = f"{sid.replace('st_look_', 'L_')}_{K.PORTRAIT_EXPR[emo]}.png"                # 파일 이름은 영문(모바일 내보내기에서 한글 경로 문제를 피한다)
            path = os.path.join(OUT, name)
            if not os.path.exists(path):
                img = K.portrait(lk, emo)
                bad = {px[:3] for px in img.getdata() if px[3] and px[:3] not in ALLOWED_SET()}
                if bad:
                    raise SystemExit(f"{name}: 팔레트 밖 색 {sorted(bad)[:4]}")
                img.save(path)
                made += 1
            index[sid][emo] = name
    import robots as RB                                               # 로봇 화자(1-7c): 시트 이름으로 선 간호 7호 — 렌즈 표정 8종
    for sid, nurse, stem in (("rb_nurse7_loco", True, "RB_nurse7"), ("N-R01-058", True, "RB_nurse7")):
        index[sid] = {}
        for emo in EMOS:
            name = f"{stem}_{K.PORTRAIT_EXPR[emo]}.png"
            path = os.path.join(OUT, name)
            if not os.path.exists(path):
                img = RB.salpim_portrait(emo, nurse)
                bad = {px[:3] for px in img.getdata() if px[3] and px[:3] not in ALLOWED_SET()}
                if bad:
                    raise SystemExit(f"{name}: 팔레트 밖 색 {sorted(bad)[:4]}")
                img.save(path)
                made += 1
            index[sid][emo] = name
    import robot_salim as RL                                          # 선거 관리 살림-2(1-11l SQ-S13): 투표함지기 2호 · 개표 4호 — 앞 렌즈 표정 8종
    for sid, kind, stem in (("N-R02-028", "ballot", "RB_ballot2"), ("rb_ballot2_loco", "ballot", "RB_ballot2"),
                            ("N-R02-029", "count", "RB_count4"), ("rb_count4_loco", "count", "RB_count4"),
                            ("N-K24-P1", "proxy", "RB_proxy"), ("rb_proxy_loco", "proxy", "RB_proxy"),   # 학원 원장 대행(1-12b FQ-GS-02)
                            ("N-R01-508", "clerk", "RB_clerk24"), ("rb_clerk24_loco", "clerk", "RB_clerk24"),   # 노량진 번개24 점원(1-12g UQ-01 · V24)
                            ("N-R01-065", "clean", "RB_clean"), ("rb_clean_loco", "clean", "RB_clean")):   # 연수원 깔끔이(1-12i UQ-63)
        index[sid] = {}
        for emo in EMOS:
            name = f"{stem}_{K.PORTRAIT_EXPR[emo]}.png"
            path = os.path.join(OUT, name)
            if not os.path.exists(path):
                img = RL.salim_portrait(emo, kind)
                bad = {px[:3] for px in img.getdata() if px[3] and px[:3] not in ALLOWED_SET()}
                if bad:
                    raise SystemExit(f"{name}: 팔레트 밖 색 {sorted(bad)[:4]}")
                img.save(path)
                made += 1
            index[sid][emo] = name
    import robot_sentry as RS                                         # 파수-3(1-11c SQ-S04): CRT 얼굴판 표정 8종 — 무명 화자 N-PS-1 · 시트 이름
    for sid in ("N-PS-1", "N-PS-2", "N-GS-R3", "CR-305", "rb_cr305_loco", "rb_cr305_carry_loco"):   # N-GS-R3 중계소 3번 파수(1-12b)   # N-PS-2 경찰서 경비 파수(1-11j)
        index[sid] = {}
        for emo in EMOS:
            name = f"RB_sentry3_{K.PORTRAIT_EXPR[emo]}.png"
            path = os.path.join(OUT, name)
            if not os.path.exists(path):
                img = RS.sentry_portrait(emo)
                bad = {px[:3] for px in img.getdata() if px[3] and px[:3] not in ALLOWED_SET()}
                if bad:
                    raise SystemExit(f"{name}: 팔레트 밖 색 {sorted(bad)[:4]}")
                img.save(path)
                made += 1
            index[sid][emo] = name
    json.dump({"portraits": index}, open(os.path.join(OUT, "portraits.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1,
              sort_keys=True)
    print(f"초상화: 화자 {len(index)}명 × 표정 {len(EMOS)} (새로 그림 {made}), 건너뜀 {skipped}")


_AL = None


def ALLOWED_SET():
    global _AL
    if _AL is None:
        _AL = set(P.allowed_set("UI", *P.SKIN.keys(), *P.HAIR.keys(), *P.PF.keys()))
    return _AL


if __name__ == "__main__":
    main()
