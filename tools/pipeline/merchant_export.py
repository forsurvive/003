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
    # 1-4 지하시장(SD-15 §4.2 V08~V14). 우호 해금 품목(A-019·A-106·I-012)·펄스 수류탄 W-061·설계도 M-102는 세력 호감도 단계·투척
    # 무기·설계도 표가 들어오면 넣는다(구현 정합). 진재석·변상민·도민지는 SD-07b [상]인데 SD-15 번호가 없어 VJ05·VJ07·VJ10으로 둔다.
    "V08": {
        "name": "복희 양품점", "npc": "C-050", "settle": "JH", "grade": "C", "renew": 3, "rate": 1.0,
        "buys": ["apparel", "misc"],
        "stock": [["A-005", 2], ["A-006", 1], ["A-007", 1], ["A-008", 1], ["A-009", 1], ["A-068", 2], ["A-069", 2], ["A-079", 1]],
        "greet": "2077년 물건이야. 옷감은 그대로고, 입던 사람만 바뀌었지.",
    },
    "V09": {
        "name": "영신통신 작업장", "npc": "C-006", "settle": "JH", "grade": "D", "renew": 7, "rate": 0.9,
        "buys": ["misc", "ammo"],
        "stock": [["에너지 전지", 40], ["M-018", 1], ["M-019", 2], ["M-014", 3], ["M-015", 2], ["W-010", 1]],
        "greet": "진공관 있으면 하나에 15캡. 성한 걸로.",
    },
    "V10": {
        "name": "지하시장 진료소", "npc": "C-051", "settle": "JH", "grade": "C", "renew": 3, "rate": 1.0,
        "buys": ["aid"],
        "stock": [["I-001", 5], ["I-002", 6], ["I-007", 2], ["I-006", 1], ["I-092", 2], ["I-004", 2]],
        "greet": "다친 데 보여 줘. 돈 얘기는 그다음에.",
    },
    "V11": {
        "name": "수연 약방", "npc": "N-R02-006", "settle": "JH", "grade": "D", "renew": 3, "rate": 1.0,
        "buys": ["aid", "misc"],
        "stock": [["I-010", 2], ["I-011", 3], ["I-013", 2], ["I-014", 2], ["I-016", 2], ["I-021", 1], ["M-048", 2], ["I-001", 2]],
        "greet": "버프아웃, 제트, 멘타츠. 몸이 버티는 만큼만 써.",
    },
    "V13": {
        "name": "희정 인쇄", "npc": "N-R02-008", "settle": "JH", "grade": "D", "renew": 7, "rate": 1.0,
        "buys": ["misc"],
        "stock": [["M-070", 10], ["M-025", 2], ["M-024", 1], ["M-004", 1]],
        "greet": "인쇄소야. 무엇을 인쇄하는지는 묻지 마.",
    },
    "V14": {
        "name": "세월상회", "npc": "N-R02-012", "settle": "JH", "grade": "C", "renew": 7, "rate": 1.0,
        "buys": ["misc"],
        "stock": [["M-083", 1], ["M-085", 1], ["M-084", 1], ["M-097", 1], ["M-086", 1]],
        "greet": "2077년 생활 잡화는 값 그대로 쳐 줘. 만 원권도 받아.",
    },
    "VJ05": {
        "name": "재석 전업사", "npc": "N-R02-005", "settle": "JH", "grade": "D", "renew": 3, "rate": 1.0,
        "buys": ["misc", "weapon"],
        "stock": [["M-012", 4], ["M-015", 2], ["M-016", 2], ["M-014", 2], ["M-025", 3], ["M-038", 1], ["I-067", 1], ["W-007", 1],
                  ["건설용 대못", 40]],
        "greet": "부품은 다 있어. 없으면 만들어 주고.",
    },
    "VJ07": {
        "name": "지하 분식", "npc": "N-R02-007", "settle": "JH", "grade": "E", "renew": 2, "rate": 1.0,
        "buys": ["aid"],
        "stock": [["I-033", 3], ["I-034", 3], ["I-044", 4], ["I-024", 2], ["I-060", 2], ["I-062", 2]],
        "greet": "떡볶이 한 그릇. 버섯은 공짜로 얹어 줄게.",
    },
    "VJ10": {
        "name": "민지 정수", "npc": "N-R02-010", "settle": "JH", "grade": "E", "renew": 2, "rate": 1.0,
        "buys": ["aid"],
        "stock": [["I-059", 8], ["I-055", 3]],
        "greet": "세 번 거른 물이야. 한강 물이랑은 비교도 마.",
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
