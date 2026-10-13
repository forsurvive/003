"""조건·효과 식 대조 사례: 파이썬 판(story_expr.py)으로 계산한 기대값을 game/tests/data/expr_cases.json에 쓴다.
게임 쪽 단위 시험(test_story.gd)이 같은 식을 expr.gd로 계산해 값이 같은지 본다 — 두 구현이 어긋나면 빌드가 실패한다."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import story_expr as SE

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENV = {"V_ACT": 2, "AFF_YH": 55, "K_CODE": 0, "V_REACTOR": 3, "P_GIVEN": "서윤", "V_KARMA": -40, "V_DOL": 6, "MQP1_STAGE": 20}
CASES = [
    "V_ACT >= 2 and AFF_YH >= 50", "V_ACT >= 3 or AFF_YH >= 60", "not K_CODE", "not not K_CODE",
    "V_REACTOR in [2, 3, 4]", "V_REACTOR in [1]", "V_REACTOR in []", "1 + 2 * 3", "(1 + 2) * 3", "10 / 3", "-7 / 2", "- -3",
    "V_KARMA < 0 and V_KARMA > -100", "P_GIVEN == \"서윤\"", "P_GIVEN != \"하나\"", "V_DOL == 6 or K_CODE", "true and false",
    "true or false and false", "not V_ACT == 2", "V_ACT * 10 + AFF_YH", "MQP1_STAGE >= 20 and MQP1_STAGE < 100",
    "V_DOL = 3; V_DOL", "V_KARMA += 50; V_KARMA", "V_KARMA -= 5; V_KARMA", "AFF_YH = AFF_YH + V_ACT * 2; AFF_YH",
]


def main():
    out = []
    for src in CASES:
        env = dict(ENV)
        v = SE.evaluate(SE.parse(src), env)
        out.append({"src": src, "env": ENV, "value": v, "after": env})
    p = os.path.join(ROOT, "game", "tests", "data", "expr_cases.json")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump({"cases": out}, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("식 대조 사례", len(out))


if __name__ == "__main__":
    main()
