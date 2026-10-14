"""상인 표 → game/data/merchants.json (SD-15 §4.1·§4.2, 단계 0-10c).
상인마다 이름·정착지 약호(F 기준)·보유 캡 등급(E~A)·취급(사는 분류)·진열 재고([아이템 ID, 수])·개인 요율.
재고 단계 Ⅰ(주인공 Lv1~6)만 쓴다. 아이템 ID는 game/data의 아이템·무기·탄약과 대조한다(모르는 ID = 빌드 오류).
SD-15 V01·V02 표의 품목 중 아직 데이터 표에 없는 것(W-001·W-014·.32 탄·12게이지·대못·M-100·I-007·I-092)은
SD-13 추출 범위가 넓어지면 넣는다(구현 정합: STAGE_0 0-10 기록).
python3 tools/pipeline/merchant_export.py   (build_data.sh에 들어 있다)"""
import os, sys, json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loot_export import known_ids, DATA

# 보유 캡 등급(SD-15 §4.1): 기준 = a + b × 레벨
GRADES = {"E": (150, 8), "D": (300, 15), "C": (500, 25), "B": (800, 35), "A": (1200, 50)}

MERCHANTS = {
    "V01": {
        "name": "오봉수 고물상", "npc": "N-R01-026", "settle": "BC", "grade": "D", "renew": 3, "rate": 1.0,
        "buys": ["*"],                                                  # 고물상은 다 산다
        "stock": [["10mm 탄", 36], ["I-001", 2], ["A-016", 1], ["W-002", 1], ["M-010", 5], ["M-012", 2],
                  ["M-025", 2], ["M-015", 1], ["I-030", 2], ["I-026", 1], ["I-055", 2]],
        "greet": "고물 사요, 팔아요. 볼트 물건이면 값 잘 쳐 줄게.",
    },
    "V02": {
        "name": "하숙자 약국", "npc": "C-057", "settle": "BC", "grade": "D", "renew": 3, "rate": 1.0,
        "buys": ["aid"],                                                 # 약방은 의약·약물·생물 재료만(§4.1) — 데이터 분류 aid(의약·음식·물)
        "stock": [["I-001", 4], ["I-002", 2], ["I-004", 1], ["I-005", 2], ["I-057", 2]],
        "greet": "약은 아껴 써. 여기서 더 나는 데가 없어.",
    },
}


def main():
    ids = known_ids()
    bad = []
    for vid, m in MERCHANTS.items():
        if m["grade"] not in GRADES:
            bad.append(f"{vid}: 모르는 캡 등급 {m['grade']}")
        for id_, n in m["stock"]:
            if id_ not in ids:
                bad.append(f"{vid}: 모르는 아이템 {id_}")
            if n < 1:
                bad.append(f"{vid}: 재고 수가 이상하다 {id_} {n}")
        m["caps_base"] = list(GRADES[m["grade"]])
    if bad:
        print("상인 표 오류:", *bad, sep="\n  ")
        sys.exit(1)
    json.dump(MERCHANTS, open(os.path.join(DATA, "merchants.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"상인 표: {len(MERCHANTS)}명")


if __name__ == "__main__":
    main()
