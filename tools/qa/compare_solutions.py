"""해법별 '기울기 체감' 비교(단계 0-12, SD-19 §5.3 ★: MQ-101 추적조 해법 5가지마다 봉천 주민의 호칭·가격·게시판이
다르게 보인다 — 자동 스크린샷 비교로 5종 모두 서로 다름).

branch_matrix.sh가 남긴 OUT/e<탈출>s<해법>/ 를 읽어 탈출 갈래마다 해법 1~5를 서로 비교한다.
  글 증거(봇 로그 '해법 증거:' 줄) — 게시판 그림 상태 · 아침 스팀팩 사는 값 · 고물상 첫마디
  화면 증거 — sol<n>_board.png(게시판 앞, 화면 가운데) · sol<n>_greet.png(대화창 글 영역) · sol<n>_trade.png(거래 창 머리말+값 열)
    두 사진의 영역 평균 화소 차(0~255)가 문턱(1.5)을 넘으면 '다르게 보인다'.
판정: 게시판 5종 서로 다름 AND 첫마디 5종 서로 다름 AND (게시판·첫마디·값) 묶음 5종 서로 다름.
값은 기획서대로 방어·유인이 같고(−10%), 마을을 팔면 고물상이 닫혀 거래가 없다(값 -1).
쓰는 법: python3 tools/qa/compare_solutions.py OUT [견본.png]  → 표 출력, 실패하면 종료 코드 1
"""
import os, re, sys, itertools
from PIL import Image, ImageChops, ImageStat, ImageDraw

THRESH = 1.5
REGIONS = {
    "board": [(228, 82, 304, 142)],                          # 게시판(주인공이 X-BC 24,37에 서면 화면 이 자리)
    "greet": [(128, 254, 612, 350), (128, 32, 612, 128)],     # 대화창 글(아래 배치·위 배치 중 큰 쪽)
    "trade": [(330, 24, 630, 44), (560, 50, 630, 262)],       # 상인 머리말 · 오른쪽 값 열
}


def diff(a, b, boxes):
    best = 0.0
    for box in boxes:
        d = ImageChops.difference(a.crop(box).convert("L"), b.crop(box).convert("L"))
        best = max(best, ImageStat.Stat(d).mean[0])
    return best


def evidence(log):
    for line in open(log, encoding="utf-8", errors="replace"):
        m = re.match(r"해법 증거: 게시판=(\S+) \| 사는 값=(-?\d+) \| 첫마디=(.*)$", line.strip())
        if m:
            return m.group(1), int(m.group(2)), m.group(3).strip()
    return None


def main():
    out = sys.argv[1]
    sample = sys.argv[2] if len(sys.argv) > 2 else ""
    ok_all = True
    sheet_rows = []
    escs = sorted({d[1] for d in os.listdir(out) if re.match(r"e\ds\d$", d)})
    for e in escs:
        ev = {}
        img = {}
        for s in range(1, 6):
            d = os.path.join(out, "e%ss%d" % (e, s))
            if not os.path.isdir(d):
                continue
            x = evidence(os.path.join(d, "log.txt"))
            if x:
                ev[s] = x
            img[s] = {k: Image.open(os.path.join(d, "sol%d_%s.png" % (s, k))).convert("RGB")
                      for k in REGIONS if os.path.exists(os.path.join(d, "sol%d_%s.png" % (s, k)))}
        print("탈출 %s:" % e)
        for s in sorted(ev):
            print("  해법 %d  게시판 %-8s 값 %3d  첫마디 %s" % (s, ev[s][0], ev[s][1], ev[s][2][:48]))
        sols = sorted(set(ev) & set(img))
        if len(sols) < 5:
            print("  × 해법 증거가 %d개뿐(로그 또는 사진 없음)" % len(sols))
            ok_all = False
            continue
        res = {}
        for k in REGIONS:
            same = []
            for a, b in itertools.combinations(sols, 2):
                if k not in img[a] or k not in img[b]:
                    continue
                if diff(img[a][k], img[b][k], REGIONS[k]) <= THRESH:
                    same.append("%d=%d" % (a, b))
            res[k] = same
            print("  화면 %-5s 같아 보이는 짝: %s" % (k, ", ".join(same) or "없음"))
        txt_board = len({ev[s][0] for s in sols}) == 5
        txt_greet = len({ev[s][2] for s in sols}) == 5
        txt_tuple = len({ev[s] for s in sols}) == 5
        ok = txt_board and txt_greet and txt_tuple and not res["board"] and not res["greet"]
        print("  판정: 게시판 %s · 첫마디 %s · 묶음 %s · 화면(게시판·첫마디) %s → %s" % (
            "5종" if txt_board else "겹침", "5종" if txt_greet else "겹침", "5종" if txt_tuple else "겹침",
            "모두 다름" if not res["board"] and not res["greet"] else "겹침", "○" if ok else "×"))
        ok_all = ok_all and ok
        if not sheet_rows:
            sheet_rows = [(s, img[s]) for s in sols]
    if sample and sheet_rows:
        crops = [("board", (200, 60, 330, 160)), ("greet", (0, 230, 640, 360)), ("trade", (320, 0, 640, 270))]
        W = sum(c[1][2] - c[1][0] for c in crops) + 8 * (len(crops) + 1)
        H = max(c[1][3] - c[1][1] for c in crops)
        sheet = Image.new("RGB", (W + 40, (H + 8) * len(sheet_rows) + 8), (26, 24, 29))
        dr = ImageDraw.Draw(sheet)
        for r, (s, ims) in enumerate(sheet_rows):
            x = 40
            dr.text((10, 8 + r * (H + 8) + H // 2), "%d" % s, fill=(232, 194, 58))
            for k, box in crops:
                if k in ims:
                    sheet.paste(ims[k].crop(box), (x, 8 + r * (H + 8)))
                x += box[2] - box[0] + 8
        sheet.save(sample)
        print("견본:", sample, sheet.size)
    print("전체:", "○ 해법 5가지가 모두 다르게 보인다" if ok_all else "× 겹치는 해법이 있다")
    sys.exit(0 if ok_all else 1)


if __name__ == "__main__":
    main()
