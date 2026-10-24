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
    # 시간대(1-T2, SD-14 §2 표기 주 06~18 · 황 17~20 · 야 18~06 · §11.2 R01 '야간 교체: 들개 무리 +2'): 낮엔 들개가 사냥하고 신참이 길을 묻는다,
    # 밤엔 바퀴 · 구울 · 시궁쥐 · 옴 너구리가 나오고 들개는 우두머리가 이끄는 큰 사냥 무리(RE-X05)로 바뀐다 — 같은 길도 시각마다 다른 몹(리드 지시 2026-10-16)
    "RE-001": {"name": "캠퍼스 들개 무리", "cat": "creature", "regions": ["R01"], "prefer": ["산지", "언덕"], "ban": ["업무"],
               "time": [6, 20], "weight": 8,
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
               "ban": ["업무"], "time": [6, 20], "weight": 5,
               "groups": [{"side": "a", "units": [["CR-104", 2, 4]], "hostile": True}],
               "states": {"S1": 3, "S3": 3, "S6": 1}, "sign": "howl", "wounded": 0.2,
               "note": "SD-05 RE-001의 전역 판본(들개 CR-104는 SD-14 전역 크리처) — 구현 정합 1-E"},
    "RE-X05": {"name": "밤 사냥 들개", "cat": "creature", "regions": ["R01"], "prefer": ["산지", "언덕", "황무지"], "ban": ["업무"],
               "time": "night", "weight": 7,
               "groups": [{"side": "a", "units": [["CR-104", 4, 6], ["CR-105", 0, 1]], "leader": ["CR-106", 0.6, 5], "hostile": True}],   # 우두머리는 Lv5부터(1-13h 조율)
               "states": {"S1": 3, "S3": 2, "S2": 2}, "sign": "howl", "wounded": 0.1,
               "note": "SD-14 §11.2 R01 야간 교체 '들개 무리 +2' · §4.2 우두머리 — 낮 들개(RE-001 · X01)의 밤 판본"},
    "RE-X06": {"name": "시궁쥐 무리", "cat": "creature", "regions": ["R01", "R02"], "prefer": ["구도심", "시장", "공단", "지하철"],
               "time": [19, 5], "weight": 6,
               "groups": [{"side": "a", "units": [["CR-095", 3, 5]], "hostile": True}],
               "states": {"S3": 4, "S1": 2}, "sign": "squeak",
               "note": "SD-14 §4.1 시궁쥐(봉천 재개발 · 영등포 지하상가 외곽) — 밤에 굴에서 나온다"},
    "RE-X07": {"name": "쓰레기 뒤지는 너구리", "cat": "creature", "regions": ["R01", "R02"], "prefer": ["구도심", "아파트", "강변", "시장"],
               "time": [18, 6], "weight": 5,
               "groups": [{"side": "a", "units": [["CR-136", 2, 4]], "hostile": True}],
               "states": {"S3": 5, "S1": 1}, "sign": "rustle",
               "note": "SD-14 §4.9 옴 너구리(시간 야) — 겁이 많아 보면 달아나고 궁지에 몰리면 문다(옴 25%는 상태 이상 체계와 함께)"},
    # ---- 적대 약탈자(남부순환 패거리, SD-14 F-04-C)
    "RE-002": {"name": "고가 아래 패거리", "cat": "raider", "regions": ["R01", "R02"], "prefer": ["고가", "큰길"], "ban": ["산지"],
               "time": "any", "night_w": 1.5, "weight": 8,
               "cond": "KC_TOLL == 0 or KC_TOLL != GAME_DAY",                           # 1-13a3: 깡철이에게 통행세를 낸 날은 고가 아래 패거리가 건드리지 않는다
               "groups": [{"side": "a", "units": [["CR-420", 1, 2], ["CR-423", 1, 2], ["CR-421", 0, 1]], "hostile": True}],
               "states": {"S2": 4, "S4": 2, "S1": 2, "S3": 1}, "sign": "whistle", "mix": [["CR-104", 2, 3, 0.3]]},
    "RE-012": {"name": "대방 분대", "cat": "raider", "regions": ["R02"], "prefer": ["시장", "공단", "큰길"], "time": "any", "weight": 6,
               "cond": "UQ71_SQ != 9",                                  # 1-D1 UQ-71: 배수관이 쓰러지거나 신길에서 터지면 분대 소멸(SD-05 §3.17 · UQ-10 비고)
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
    # RE-104 탈영병 무리(SD-05 §5 L1452 · 1-12g UQ-03): MQ-106 이후(S1) A반 최대 3회 · 비적대 대화. 엄도현 판(RE-104E)은 UQ-03 ② 21일 뒤 한 번 —
    # 그 판이 열려 있는 동안엔 일반 판을 고르지 않는다(다음 RE-104 판정에 엄도현이 섞인다, P5). 그림은 계급장 뗀 계엄병(CR-401 그림)
    "RE-104": {"name": "탈영병 무리", "cat": "event", "regions": ["R01", "R02", "R11"], "prefer": ["강변", "산지", "구도심"], "ban": ["업무"],
               "time": "any", "weight": 3,
               "cond": "stage(\"MQ-106\") >= 100 and RE104_N < 3 and not (UQ03_EOM == 2 and GAME_DAY >= UQ03_REPORT_DAY + 21)",
               "groups": [{"side": "a", "units": [["N-DS-E1", 1, 1], ["N-DS-E2", 1, 2]], "hostile": False}],
               "talk": "RE-104_TALK", "states": {"S1": 3, "S4": 1}},
    "RE-104E": {"name": "탈영병 무리(엄도현)", "cat": "event", "regions": ["R01", "R02", "R11"], "ban": ["업무"], "time": "any", "weight": 8,
                "cond": "stage(\"MQ-106\") >= 100 and UQ03_EOM == 2 and GAME_DAY >= UQ03_REPORT_DAY + 21 and dead(\"N-R01-050\") == 0",
                "groups": [{"side": "a", "units": [["N-R01-050", 1, 1], ["N-DS-E2", 1, 2]], "hostile": False}],
                "talk": "RE-104E_TALK", "states": {"S1": 3, "S4": 1}},
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
# ---- 1-13e 기본 표 30종(D-130, 계획 _plans/1-13_closing_plan.md §5): SD-05 §5 R01 · R02 행 가운데 그림 · 자료가 있는 7종.
# 재미 검수(계획 때): 모두 판(variants) 2~3개 — 같은 RE도 상황 · 인원 · 소품이 매번 다르게. 결과는 세상에 남는다(장소 표시 · 정착지 개 · 오두막 쪽지 · 소문)
RE.update({
    # 국회 왕개미(SD-05 L1447 · 정본 CR-603은 계통 자료 CR-080 · 081로): 무너진 국회(L-R02-01) 3청크 안. 붉은 카펫 실밥 흔적이 먼저.
    # 판: ① 짐 나르는 줄(병정 없음 — 먼저 물지 않는다, 지나갈 수 있다) ② 사냥한 들개를 끄는 무리 ③ 병정이 지키는 길(매복). 끝나면 국회가 지도에
    "RE-006": {"name": "국회 왕개미", "cat": "creature", "regions": ["R02"], "near": ["L-R02-01", 758, 1057, 3], "prefer": ["업무", "강변"],
               "time": "any", "weight": 6, "sign": "fiber", "reveal": "L-R02-01",
               "reveal_msg": "붉은 실밥은 무너진 국회 쪽으로 이어진다. 지도에 표시되었다",
               "groups": [{"side": "a", "units": [["CR-080", 2, 4], ["CR-081", 0, 1]], "hostile": True}], "states": {"S3": 2, "S1": 1},
               "variants": [{"w": 3, "groups": [{"side": "a", "units": [["CR-080", 2, 4]], "hostile": False}], "states": {"S1": 1}},
                            {"w": 4, "groups": [{"side": "a", "units": [["CR-080", 2, 4], ["CR-081", 0, 1]], "hostile": True}], "states": {"S3": 1},
                             "s3_box": ["끌려가던 들개 사체", "carcass", "carcass_pile"]},
                            {"w": 3, "groups": [{"side": "a", "units": [["CR-081", 1, 1], ["CR-080", 2, 3]], "hostile": True}], "states": {"S2": 1}}],
               "note": "SD-05 RE-006 · CR-603 판본 자료 없음 → 왕개미 일개미 · 병정(CR-080 · 081, 1-D5 금탑 그림). 1막 병정 최대 1(밸런스 조율 — 정본 '일개미 4 + 병정 2'는 2막 표)"},
    # 지하상가 쥐(SD-05 L1449 · CR-605 판본은 시궁쥐 CR-095로): 영등포시장역(L-UG-06) 4청크 안 · 왕쥐는 주인공 Lv5부터. RQ-22 배수구 청소 중이면 절반.
    # 판: ① 뜯긴 쌀자루에 몰림(S3) ② 무언가에 쫓겨 몰려나옴(왕쥐가 이끈다, S6) ③ 배수 통로 그늘에 잠복(S2)
    "RE-008": {"name": "지하상가 쥐", "cat": "creature", "regions": ["R02"], "near": ["L-UG-06", 715, 1112, 4], "prefer": ["시장", "지하철", "구도심"],
               "time": "any", "night_w": 1.5, "weight": 5, "sign": "squeak", "mult_if": [["RQ22_ON == 1", 0.5]],
               "groups": [{"side": "a", "units": [["CR-095", 3, 5]], "hostile": True}], "states": {"S3": 2, "S1": 1},
               "variants": [{"w": 4, "states": {"S3": 1}, "s3_box": ["쥐가 뜯은 쌀자루", "sacks", "pallet_sacks"]},
                            {"w": 2, "states": {"S6": 1}, "groups": [{"side": "a", "units": [["CR-095", 2, 2]], "leader": ["CR-097", 1.0, 5], "hostile": True}],
                             "reveal": "L-UG-06", "reveal_msg": "쥐가 몰려나온 쪽은 영등포시장역 입구다. 안쪽에서 무언가 무너지는 소리가 났다. 지도에 표시되었다"},
                            {"w": 2, "states": {"S2": 1}}],
               "note": "SD-05 RE-008 · 1막 편성 시궁쥐 3~5 또는 2~3 + 왕쥐(Lv5+ — 밸런스 조율: 떼 4 + 무리 토큰이 겹쳐 4~6 + 왕쥐는 HP를 넘는다) · '어두운 곳 탐지 −30%'는 빛 체계와 함께(D-391)"},
    # 남부 고개길 수송대(SD-05 L1479 · SD-15 §4.3 V54): 연보경이 정류장 사이 길 위(CARAVAN_V54 = 0)일 때만 — 정류장과 같은 사람 · 같은 재고(P3).
    # 짐소는 UQ-05 상태를 읽는다(0 누렁이 · 1 없음 — 호위가 짐을 짐 · 2 위강윤에게 빌린 소). 판: ① 걸으며 ② 쉬며 짐소 물 먹임 ③ 척후가 따라붙음
    "RE-033": {"name": "남부 고개길 수송대", "cat": "trader", "regions": ["R01"], "prefer": ["큰길", "고가", "언덕"], "ban": ["업무"],
               "time": [7, 18], "weight": 4, "sign": "hoof",
               "cond": "CARAVAN_V54 == 0 and V_ACT >= 1 and dead(\"N-R01-040\") == 0 and RE033_ROB <= GAME_DAY and UQ05_REFUSE_DAY <= GAME_DAY",
               "groups": [{"side": "a", "units": [["N-R01-040", 1, 1], ["N-OX", 1, 1]], "hostile": False},
                          {"side": "a", "units": [["CR-472", 2, 2]], "hostile": False}],
               "talk": "RE-033_TALK", "states": {"S1": 2, "S4": 1},
               "variants": [{"w": 4, "cond": "UQ05_ABSENT != 1", "states": {"S1": 1}, "on_start": "RE_V = 1"},
                            {"w": 3, "cond": "UQ05_ABSENT != 1", "states": {"S4": 1}, "on_start": "RE_V = 2"},
                            {"w": 4, "cond": "UQ05_ABSENT == 1", "on_start": "RE_V = 3", "groups": [{"side": "a", "units": [["N-R01-040", 1, 1]], "hostile": False},
                                                                         {"side": "a", "units": [["CR-472", 2, 2]], "hostile": False}], "states": {"S1": 1, "S4": 1}},
                            {"w": 2, "states": {"S1": 1}, "on_start": "RE_V = 4",
                             "groups": [{"side": "a", "units": [["N-R01-040", 1, 1], ["N-OX", 1, 1]], "hostile": False},
                                        {"side": "a", "units": [["CR-472", 2, 2]], "hostile": False},
                                        {"side": "b", "units": [["CR-420", 1, 1], ["CR-423", 1, 1]], "hostile": True}]}]},
    # 산 사냥꾼(SD-05 L1485 · V04): 관악산 사냥꾼 엄태경(정본의 '곰배'는 SD-07b 엄태경). RE가 서면 그날 16시까지 봉천 오두막이 빈다(HUNT_OUT, P3).
    # 판: ① 덫을 놓는 중 ② 피 흔적을 쫓다 놓침 ③ 고기 굽는 중(S4 — 구운 고기를 판다). 근처 크리처 굴 하나를 아는 만큼 알려 준다
    "RE-039": {"name": "산 사냥꾼", "cat": "trader", "regions": ["R01"], "prefer": ["산지", "언덕"], "ban": ["업무", "시장"], "time": [7, 16], "weight": 3,
               "cond": "V_ACT >= 1 and dead(\"N-R01-033\") == 0 and HUNT_OUT != GAME_DAY and (MQ101_NIGHT == 0 or MQ101_RESULT != 0)",
               "on_start": "HUNT_OUT = GAME_DAY",
               "groups": [{"side": "a", "units": [["N-R01-033", 1, 1]], "hostile": False}], "talk": "RE-039_TALK", "states": {"S1": 1},
               "variants": [{"w": 1, "states": {"S1": 1}, "on_start": "HUNT_OUT = GAME_DAY; RE_V = 1"},
                            {"w": 1, "states": {"S1": 1}, "on_start": "HUNT_OUT = GAME_DAY; RE_V = 2"},
                            {"w": 1, "states": {"S4": 1}, "on_start": "HUNT_OUT = GAME_DAY; RE_V = 3"}]},
    # 조난 신호(SD-05 L1492 · ST-14): 핍-보이에 목소리가 먼저 잡힌다 — 가 보기 전엔 셋 중 무엇인지 모른다(라디오 켜짐 ×2 · PK-041 ×1.5 · 밤 ×1.3).
    # 판(4:4:2): ① 다친 생존자 + 둘러싼 무리(낮 들개 · 밤 시궁쥐) ② 무전기가 녹음을 되풀이하는 유해(위치 힌트) ③ 미끼 — 매복한 패거리(인지 6이면 미리 안다)
    "RE-041": {"name": "조난 신호", "cat": "event", "regions": "*", "no_regions": ["R05"], "time": "any", "night_w": 1.3, "weight": 5, "threat_min": 2,
               "sign": "radio", "radio": 2.0,
               "groups": [], "states": {"S7": 1}, "talk": "RE-041_TAPE",
               "variants": [{"w": 4, "luck": True, "cond": "GAME_HOUR >= 5 and GAME_HOUR < 20", "rescue": True, "talk": "RE-041_SURV", "states": {"S6": 1},
                             "groups": [{"side": "a", "units": [["N-SURV", 1, 1]], "hostile": False},
                                        {"side": "b", "units": [["CR-104", 2, 3]], "hostile": True}]},
                            {"w": 4, "luck": True, "cond": "GAME_HOUR >= 20 or GAME_HOUR < 5", "rescue": True, "talk": "RE-041_SURV", "states": {"S6": 1},
                             "groups": [{"side": "a", "units": [["N-SURV", 1, 1]], "hostile": False},
                                        {"side": "b", "units": [["CR-095", 3, 4]], "hostile": True}]},
                            {"w": 4, "luck": True, "w_if": ["RE041_N >= 1", 0.5], "groups": [], "talk": "RE-041_TAPE", "states": {"S7": 1}},
                            {"w": 2, "talk": "", "states": {"S2": 1}, "pe_hint": [6, "목소리가 같은 말만 또박또박 되풀이한다. 숨소리가 없다 — 미끼다."],
                             "groups": [{"side": "a", "units": [["CR-420", 1, 2], ["CR-423", 1, 1]], "leader": ["CR-421", 0.5, 5], "hostile": True}]}]},
    # 진돗개 한 마리(SD-05 L1504 · CR-108 판본): 목줄 쇠 이름표 — 봉천 감시조 '먹순이' · 사당 승강장 '돌쇠'(정착지마다 한 번, RE053_BC · RE053_SA).
    # 판: ① 길 잃고 다가옴 ② 다리를 절뚝임(스팀팩 · 붕대) ③ 떠돌이가 목줄을 쥐고 "이 개 살래?". 돌려보내면 그 정착지에 개가 서고 주인이 고마워한다
    "RE-053": {"name": "진돗개 한 마리", "cat": "event", "regions": ["R01"], "prefer": ["구도심", "아파트", "언덕"], "ban": ["업무"],
               "time": [6, 19], "weight": 2, "threat_max": 3, "cond": "V_ACT >= 1 and (RE053_BC == 0 or RE053_SA == 0)",
               "groups": [{"side": "a", "units": [["N-JINDO", 1, 1]], "hostile": False}], "talk": "RE-053_TALK", "states": {"S1": 1},
               "variants": [{"w": 4, "cond": "RE053_BC == 0", "on_start": "RE_V = 1; RE_VM = 0"}, {"w": 4, "cond": "RE053_SA == 0", "on_start": "RE_V = 2; RE_VM = 0"},
                            {"w": 2, "cond": "RE053_BC == 0", "on_start": "RE_V = 1; RE_VM = 1"}, {"w": 2, "cond": "RE053_SA == 0", "on_start": "RE_V = 2; RE_VM = 1"},
                            {"w": 2, "cond": "RE053_BC == 0", "talk": "RE-053_LEASH", "on_start": "RE_V = 1; RE_VM = 2",
                             "groups": [{"side": "a", "units": [["N-STRAY", 1, 1], ["N-JINDO", 1, 1]], "hostile": False}]},
                            {"w": 2, "cond": "RE053_SA == 0", "talk": "RE-053_LEASH", "on_start": "RE_V = 2; RE_VM = 2",
                             "groups": [{"side": "a", "units": [["N-STRAY", 1, 1], ["N-JINDO", 1, 1]], "hostile": False}]}],
               "rescue": True},
    # 각성회 탁발(SD-05 L1506 · SD-10 헌금 10캡당 카르마 +1 · 하루 +30): 무장한 고참 신도 CR-460 + 맨손 신참(N-GS-N1). 각성회 경계 이상.
    # 판: ① 낮 탁발 ② 해 질 녘 귀가 탁발(17~20시) — 신참이 엉뚱한 걸 묻는다
    "RE-055": {"name": "각성회 탁발", "cat": "event", "regions": ["R01", "R02"], "prefer": ["큰길", "시장", "구도심"], "time": [8, 20], "weight": 3,
               "cond": "V_ACT >= 1 and AFF_GS > -60", "sign": "bell",
               "groups": [{"side": "a", "units": [["CR-460", 1, 1], ["N-GS-N1", 1, 1]], "hostile": False}], "talk": "RE-055_TALK", "states": {"S1": 1},
               "variants": [{"w": 3, "cond": "GAME_HOUR < 17"}, {"w": 3, "cond": "GAME_HOUR >= 17", "talk": "RE-055_DUSK"}]},
    # 각성회 순례조(SD-05 L1526 · 순찰 — 호감도 체감): 신도 CR-460 2 + 맨손 신참. 우호면 '운영자님'이라 부르며 길을 비키고, 그 밑이면 기도를 멈추고 지켜본다.
    # 판: ① 중계소로 가는 순례(경문을 외며) ② 잠든 경비 로봇 먼지를 털고 돌아오는 길(걸레 · 기름통)
    "RE-069": {"name": "각성회 순례조", "cat": "patrol", "faction": "GS", "regions": ["R01"], "prefer": ["큰길", "구도심", "언덕"], "time": [8, 18],
               "weight": 4, "cond": "V_ACT >= 1 and AFF_GS > -60", "sign": "bell",
               "groups": [{"side": "a", "units": [["CR-460", 2, 2], ["N-GS-N1", 1, 1]], "hostile": False}], "talk": "RE-069_TALK", "states": {"S1": 1},
               "variants": [{"w": 1, "on_start": "RE_V = 1"}, {"w": 1, "on_start": "RE_V = 2"}]},
    # ---- 1-13i 정본 정기 순찰(SD-06 §14.1 · 계획 _plans/1-13i_patrol_plan.md · 장부 D-404): 판도 '지배 순찰' 칸의 내용.
    # 서서 기다리며(S4) 자기들끼리 떠든다(chatter — 엿보는 장면). 다가가면 장면: 첫 줄은 판도 몫(RE_TS 0 경합 · 1 우세 · 2 지배), 그다음 호감 단계.
    # 봉천 옥탑 감시조(CR-466 계단마을 자경단원 둘 — 조장 남태하는 망루에 있다, P3)
    "RE-X08": {"name": "봉천 감시조", "cat": "patrol", "faction": "JC", "regions": ["R01"], "near": ["L-R01-09", 892, 1362, 4],
               "prefer": ["언덕", "구도심", "큰길"], "ban": ["산지"], "time": [6, 22], "weight": 4, "cond": "V_ACT >= 1",
               "groups": [{"side": "a", "units": [["CR-466", 2, 2]], "hostile": False}], "talk": "RE-X08_TALK", "states": {"S4": 1},
               "variants": [{"w": 3, "on_start": "RE_V = 1", "chatter": [[0, "교대 아직이야?"], [1, "해 넘어가야 와. 물이나 마셔."],
                                                                       [0, "어제 밸브실 깡통 줄, 바람에 울린 거래."], [1, "바람이 깡통 당기는 거 봤어?"],
                                                                       [0, "…쉿. 저기 누가 서 있는데."]]},
                            {"w": 2, "on_start": "RE_V = 2", "chatter": [[1, "이거 봐, 발자국 새로 났어."], [0, "들개야? 몇 마리?"],
                                                                       [1, "셋…넷. 개천 쪽으로 갔어."], [0, "조장님께 올려야겠다."],
                                                                       [1, "…저 사람, 우리 얘기 듣는 거 아냐?"]]},
                            {"w": 2, "cond": "SQS01_STAGE >= 20", "on_start": "RE_V = 3", "chatter": [[0, "망루에서 바위굴 쪽 연기 봤대."],
                                                                       [1, "연기 말고 울음. 밤마다 커져."], [0, "볼트 학생이 거기 갔다던데."],
                                                                       [1, "…어, 저기 그 볼트 학생 아냐?"]]}]},
    # 지하시장 계약 경호단(CR-457 계약 경호 구울 둘 — SD-06 §4.3.6 JH '순찰대' 칸: 적대 추심 · 경계 몸수색 · 중립 무관심 · 우호 인사 · 신뢰 배웅)
    "RE-X09": {"name": "계약 경호단", "cat": "patrol", "faction": "JH", "regions": ["R02"], "near": ["L-UG-06", 715, 1112, 3],
               "prefer": ["시장", "구도심", "지하철"], "time": "any", "weight": 4, "cond": "V_ACT >= 1", "leash": 16, "leash_say": "여기서부턴 상인회 구역 밖이에요.",
               "groups": [{"side": "a", "units": [["CR-457", 2, 2]], "hostile": False}], "talk": "RE-X09_TALK", "states": {"S4": 1},
               "variants": [{"w": 3, "on_start": "RE_V = 1", "chatter": [[0, "오늘 계약서 몇 장 나갔어?"], [1, "셋. 그중 하나는 떼였지."],
                                                                       [0, "떼이면 우리가 받으러 가잖아."], [1, "그러니까 계약금은 먼저 받는 거야."],
                                                                       [0, "…손님 오셨다. 표정 풀어."]]},
                            {"w": 2, "on_start": "RE_V = 2", "chatter": [[1, "요즘 피부 좋은 손님이 많아."], [0, "볼트에서 나왔다는 그 사람?"],
                                                                       [1, "주머니부터 봐. 장물 들고 내려오면 회장님 골치 아파."],
                                                                       [0, "…저기 저 손님, 가방이 불룩한데."]]},
                            {"w": 2, "on_start": "RE_V = 3", "chatter": [[0, "출입 금지 하나가 이 근처에 숨었대."], [1, "폐차 뒤 봤어?"],
                                                                       [0, "냄새로 찾아. 사람 냄새는 우리랑 달라."],
                                                                       [1, "…저 손님도 사람 냄새가 나네."]]}]},
})

# 추적대(기존 엔진 RE-087)도 표에 둔다(범주 tracker — 기본 표에서 고르지 않고 끼워 넣기로만)
RE["RE-087"] = {"name": "생포 추적대(새벽인력)", "cat": "tracker", "regions": "*", "no_regions": ["R05"], "time": "any", "weight": 0,
                "groups": [{"side": "a", "units": [["CR-436", 1, 1], ["CR-437", 2, 3]], "hostile": False}], "talk": "RE-087_TALK",
                "capture": "SB", "states": {"S1": 1}}

# 범주 가중(SD-05 §6.3 판도 표 · SD-06 §5.9 시작 판도): R01 경합 · R02 지상 경합 → 경합 표. 판도 구현 전 고정
# SD-05 §6.3 판도 상태별 범주 가중(1-12m: 구역 상태는 core/story/turf.gd가 판정 칸마다 준다). patrol = 지배 세력 순찰(dom) + 경쟁 세력 순찰(comp).
# '판도 연동'(5.8) 범주는 RE가 들어올 때(정합 — 지금은 표에서 뺀다)
CAT_W = {"지배": {"patrol": 45, "dom": 40, "comp": 5, "clash": 5, "creature": 15, "raider": 5, "trader": 15, "event": 12},
         "우세": {"patrol": 40, "dom": 30, "comp": 10, "clash": 10, "creature": 15, "raider": 7, "trader": 13, "event": 12},
         "경합": {"patrol": 30, "dom": 15, "comp": 15, "clash": 30, "creature": 10, "raider": 8, "trader": 7, "event": 10},
         "공백": {"creature": 45, "raider": 25, "trader": 5, "event": 15}}
REGION_STATE = {"R01": "경합", "R02": "경합"}
STATES = ["S1", "S2", "S3", "S4", "S5", "S6", "S7"]
# 비적대 사람(무명 NPC) 외형: 그림 시트 이름(종이 인형)
FRIENDLY_SHEET = {"N-TRADER": "en_trader_loco", "N-REFUGEE": "en_refugee_loco", "N-DOWNED": "en_downed_loco",
                  "N-DS-E1": "en_cr401_loco", "N-DS-E2": "en_cr401_loco", "N-R01-050": "en_cr401_loco",
                  # 1-13e: 길 위 수송대 연보경 · 짐소 · 호위 민병, 산 사냥꾼 엄태경, 조난 생존자, 길 잃은 황구 · 개 파는 떠돌이, 각성회 고참 · 신참
                  "N-R01-040": "st_n_r01_040", "N-OX": "cr_cr091_loco", "CR-472": "en_cr472_loco", "N-R01-033": "st_n_r01_033",
                  "N-SURV": "en_downed_loco", "N-JINDO": "cr_hwanggu_loco", "N-STRAY": "en_refugee_b_loco",
                  "CR-460": "en_cr460_loco", "N-GS-N1": "en_cr460b_loco"}


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
