"""랜덤 인카운터 표(SD-05 §5 RE 목록 · SD-22 변주 규칙) → game/data/world/encounters.json의 "re"·"cat_w"·"fab_tag".

RE는 데이터 행이다(SD-05 §8 '157종은 개별 이벤트가 아니라 데이터 행'). 1차(SD-22 §4)는 R01·R02·전역 중 그림이 있는 것.
행 칸:
  name · cat(범주: creature 크리처 · raider 약탈자 · trader 상인 · event 사건 · patrol 순찰 · clash 교전 · tracker 추적대)
  regions(권역, "*" 전역) · no_regions · prefer(어울리는 지형 태그 — 가중 ×2) · ban(금지 태그 — 가중 ×0)
  time("any" · "day" 06~19 · "night" 20~05 · [시작, 끝] 시각) · weight(기본 가중 1~10) · cond(이야기 식, 비면 늘)
  groups: [{"side": "a"|"b", "units": [[CR, 최소, 최대]], "leader": [CR, 확률], "hostile": 참/거짓}] — 둘이면 서로 싸운다(S5)
  states: {상황: 가중} — S1 배회 · S2 매복 · S3 먹이·약탈 중 · S4 야영·잠 · S5 싸움 중 · S6 쫓기는 중 · S7 끝난 뒤
  talk(비적대 장면 원고) · rescue(구조형 — 매우 선한 카르마 ×1.2) · luck(행운 RE) · mix([CR, 최소, 최대, 확률] 섞임) · wounded(다친 개체 확률) · sign(흔적 예고 종류) · cool(같은 RE 쿨다운 게임시간)
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "data", "world", "encounters.json")

RE = {
    # ---- 적대 크리처
    "RE-001": {"name": "캠퍼스 들개 무리", "cat": "creature", "regions": ["R01"], "prefer": ["산지", "언덕"], "ban": ["업무"],
               "time": "any", "night_w": 1.5, "weight": 8,
               "groups": [{"side": "a", "units": [["CR-104", 3, 5]], "leader": ["CR-106", 0.25], "hostile": True}],
               "states": {"S1": 4, "S3": 3, "S4": 1, "S7": 1}, "sign": "howl", "wounded": 0.15},
    "RE-004": {"name": "시체 뜯는 바퀴", "cat": "creature", "regions": "*", "no_regions": ["R05"], "prefer": ["구도심", "시장", "공단"],
               "time": "night", "weight": 5,
               "groups": [{"side": "a", "units": [["CR-002", 3, 6]], "hostile": True}],
               "states": {"S3": 5, "S1": 1}, "sign": "skitter"},
    "RE-125": {"name": "밤의 구울", "cat": "creature", "regions": "*", "no_regions": ["R05"], "prefer": ["지하철", "구도심", "업무"],
               "time": "night", "weight": 6,
               "groups": [{"side": "a", "units": [["CR-200", 3, 5]], "leader": ["CR-201", 0.35], "hostile": True}],
               "states": {"S1": 3, "S3": 2, "S2": 1}, "sign": "groan", "mix": [["CR-002", 1, 3, 0.2]]},
    "RE-X01": {"name": "떠도는 들개", "cat": "creature", "regions": "*", "no_regions": ["R05"], "prefer": ["황무지", "강변", "공단"],
               "ban": ["업무"], "time": "any", "weight": 5,
               "groups": [{"side": "a", "units": [["CR-104", 2, 4]], "hostile": True}],
               "states": {"S1": 3, "S3": 3, "S6": 1}, "sign": "howl", "wounded": 0.2,
               "note": "SD-05 RE-001의 전역 판본(들개 CR-104는 SD-14 전역 크리처) — 구현 정합 1-E"},
    # ---- 적대 약탈자(남부순환 패거리, SD-14 F-04-C)
    "RE-002": {"name": "고가 아래 패거리", "cat": "raider", "regions": ["R01", "R02"], "prefer": ["고가", "큰길"], "ban": ["산지"],
               "time": "any", "night_w": 1.5, "weight": 8,
               "groups": [{"side": "a", "units": [["CR-420", 1, 2], ["CR-423", 1, 2], ["CR-421", 0, 1]], "hostile": True}],
               "states": {"S2": 4, "S4": 2, "S1": 2, "S3": 1}, "sign": "whistle", "mix": [["CR-104", 2, 3, 0.3]]},
    "RE-012": {"name": "대방 분대", "cat": "raider", "regions": ["R02"], "prefer": ["시장", "공단", "큰길"], "time": "any", "weight": 6,
               "groups": [{"side": "a", "units": [["CR-420", 1, 2], ["CR-421", 1, 1], ["CR-423", 1, 2]], "hostile": True}],
               "states": {"S1": 3, "S5": 2, "S4": 1}, "sign": "voices"},
    "RE-057": {"name": "혼자 온 신참", "cat": "raider", "regions": ["R01", "R02", "R07", "R08"], "time": "day", "weight": 2,
               "groups": [{"side": "a", "units": [["CR-420", 1, 1]], "hostile": False}], "talk": "RE-057_TALK",
               "states": {"S1": 1}, "threat_max": 3},
    # ---- 상인·사건
    "RE-036": {"name": "떠돌이 고물상", "cat": "trader", "regions": "*", "no_regions": ["R05"], "prefer": ["황무지", "큰길", "구도심"],
               "time": "day", "weight": 6, "threat_max": 4,
               "groups": [{"side": "a", "units": [["N-TRADER", 1, 1]], "hostile": False}, {"side": "a", "units": [["CR-108", 0, 1]], "hostile": False}],
               "talk": "RE-036_TALK", "states": {"S1": 3, "S4": 1}},
    "RE-042": {"name": "시체와 노트", "cat": "event", "regions": "*", "no_regions": ["R05"], "time": "any", "weight": 6, "threat_min": 2,
               "groups": [], "states": {"S7": 1}, "talk": "RE-042_NOTE"},
    "RE-044": {"name": "피난민 가족", "cat": "event", "regions": ["R01", "R02", "R06", "R08"], "prefer": ["큰길", "구도심"], "time": "day",
               "weight": 4, "groups": [{"side": "a", "units": [["N-REFUGEE", 2, 3]], "hostile": False},
                                       {"side": "b", "units": [["CR-437", 0, 2]], "hostile": True}],
               "talk": "RE-044_TALK", "states": {"S6": 2, "S1": 1}, "rescue": True},
    "RE-046": {"name": "쓰러진 세력원", "cat": "event", "regions": "*", "no_regions": ["R05"], "time": "any", "weight": 4,
               "groups": [{"side": "a", "units": [["N-DOWNED", 1, 1]], "hostile": False}, {"side": "b", "units": [["CR-104", 2, 3]], "hostile": True}],
               "talk": "RE-046_TALK", "states": {"S6": 1}, "rescue": True},
    # ---- 순찰(호감 단계를 보여 주는 무대, SD-05 §5.5)
    "RE-061": {"name": "계엄군 분대", "cat": "patrol", "regions": ["R01", "R02", "R07", "R11"], "prefer": ["큰길", "업무"], "ban": ["산지"],
               "time": [6, 20], "weight": 6, "faction": "BJ",
               "groups": [{"side": "a", "units": [["CR-401", 3, 3]], "leader": ["CR-403", 1.0], "hostile": False}],
               "talk": "RE-061_TALK", "states": {"S1": 1}},
    "RE-064": {"name": "인력 검문", "cat": "patrol", "regions": ["R02"], "prefer": ["공단", "시장", "큰길"], "time": [4, 10], "weight": 4,
               "faction": "SB", "groups": [{"side": "a", "units": [["CR-437", 3, 3], ["CR-107", 1, 1]], "leader": ["CR-438", 1.0], "hostile": False}],
               "talk": "RE-064_TALK", "states": {"S1": 1}},
    # ---- 교전(경합 판도의 장면, SD-05 §5.6 · SD-22 S5)
    "RE-X02": {"name": "계엄 분대 대 패거리", "cat": "clash", "regions": ["R01", "R02"], "prefer": ["큰길", "고가"], "time": "any", "weight": 5,
               "groups": [{"side": "a", "units": [["CR-401", 2, 3]], "hostile": False},
                          {"side": "b", "units": [["CR-420", 1, 2], ["CR-423", 1, 2]], "hostile": True}],
               "states": {"S5": 1}, "sign": "gunfire", "note": "SD-05 교전 RE-071~080의 1막 판본(BJ 대 YT) — 구현 정합 1-E"},
    "RE-X03": {"name": "들개 대 인솔조", "cat": "clash", "regions": ["R01", "R02"], "prefer": ["공단", "황무지", "구도심"], "time": "any",
               "weight": 4, "groups": [{"side": "a", "units": [["CR-437", 2, 3]], "hostile": True},
                                       {"side": "b", "units": [["CR-104", 3, 4]], "hostile": True}],
               "states": {"S5": 1}, "sign": "gunfire"},
    "RE-X04": {"name": "구울 대 패거리", "cat": "clash", "regions": ["R01", "R02"], "prefer": ["지하철", "구도심"], "time": "night", "weight": 3,
               "groups": [{"side": "a", "units": [["CR-420", 1, 2], ["CR-423", 1, 1]], "hostile": True},
                          {"side": "b", "units": [["CR-200", 2, 4]], "hostile": True}],
               "states": {"S5": 1}, "sign": "gunfire"},
}
# 추적대(기존 엔진 RE-087)도 표에 둔다(범주 tracker — 기본 표에서 고르지 않고 끼워 넣기로만)
RE["RE-087"] = {"name": "생포 추적대(새벽인력)", "cat": "tracker", "regions": "*", "no_regions": ["R05"], "time": "any", "weight": 0,
                "groups": [{"side": "a", "units": [["CR-436", 1, 1], ["CR-437", 2, 3]], "hostile": False}], "talk": "RE-087_TALK",
                "capture": "SB", "states": {"S1": 1}}

# 범주 가중(SD-05 §6.3 판도 표 · SD-06 §5.9 시작 판도): R01 경합 · R02 지상 경합 → 경합 표. 판도 구현 전 고정
CAT_W = {"경합": {"patrol": 30, "clash": 30, "creature": 10, "raider": 8, "trader": 7, "event": 10},
         "공백": {"creature": 45, "raider": 25, "trader": 5, "event": 15}}
REGION_STATE = {"R01": "경합", "R02": "경합"}
STATES = ["S1", "S2", "S3", "S4", "S5", "S6", "S7"]
# 비적대 사람(무명 NPC) 외형: 그림 시트 이름(종이 인형)
FRIENDLY_SHEET = {"N-TRADER": "en_trader_loco", "N-REFUGEE": "en_refugee_loco", "N-DOWNED": "en_downed_loco"}


def main():
    d = json.load(open(OUT, encoding="utf-8")) if os.path.exists(OUT) else {}
    bad = []
    enemies = json.load(open(os.path.join(ROOT, "game", "data", "enemies.json"), encoding="utf-8"))
    for rid, r in RE.items():
        for g in r["groups"]:
            for u in g["units"]:
                if u[0].startswith("CR-") and u[0] not in enemies:
                    bad.append(f"{rid}: 적 자료 없음 {u[0]}")
            if "leader" in g and g["leader"][0] not in enemies:
                bad.append(f"{rid}: 대장 자료 없음 {g['leader'][0]}")
        for m in r.get("mix", []):
            if m[0] not in enemies:
                bad.append(f"{rid}: 섞임 자료 없음 {m[0]}")
        for s in r.get("states", {}):
            if s not in STATES:
                bad.append(f"{rid}: 모르는 상황 {s}")
    if bad:
        print("인카운터 표 오류:", *bad, sep="\n  ")
        sys.exit(1)
    d["re"] = RE
    d["cat_w"] = CAT_W
    d["region_state"] = REGION_STATE
    d["friendly_sheet"] = FRIENDLY_SHEET
    json.dump(d, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print("인카운터 표: RE %d (%s)" % (len(RE), ", ".join("%s %d" % (c, sum(1 for r in RE.values() if r["cat"] == c))
                                                     for c in ["creature", "raider", "trader", "event", "patrol", "clash", "tracker"])))


if __name__ == "__main__":
    main()
