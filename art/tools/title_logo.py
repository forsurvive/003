"""제목 화면 로고(SD-12 §13.5·SD-16 §9.4 '메인 메뉴는 잉크·중성 램프 + 볼트 황 강조', 단계 0-11).
'서울 폴아웃' 큰 글씨(갈무리14 픽셀 글꼴을 3배로 키워 덩어리감) + 잉크 테두리 2단 + 위 빛·아래 그늘 띠, 그 아래 '2277 · 관악'
작은 줄, 그리고 볼트 문 명판 '볼트-텍 면허 / 한결건설 시공 / 서울 볼트 S-07'(SD-18 §7 표기). 팔레트 안 색만.
python3 art/tools/title_logo.py → game/assets/ui/title_logo.png, title_plate.png
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from struct_r01 import text_px, put_text
from grid import check

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "assets", "ui")
C = lambda t: P.rgb(t) + (255,)


def logo():
    pts, w, h = text_px("서울 폴아웃", 14, "Galmuri14")
    S = 3
    pad = 6
    W, H = w * S + pad * 2, h * S + pad * 2
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    fill = set()
    for (a, b) in pts:
        for dy in range(S):
            for dx in range(S):
                fill.add((pad + a * S + dx, pad + b * S + dy))
    # 테두리: 잉크 2단(바깥 P01, 안 P02) — 둥근 모서리 없이 각진 픽셀
    for ring, col in ((2, "P01"), (1, "P02")):
        for (x, y) in fill:
            for dy in range(-ring, ring + 1):
                for dx in range(-ring, ring + 1):
                    q = (x + dx, y + dy)
                    if q not in fill and 0 <= q[0] < W and 0 <= q[1] < H and px[q][3] == 0:
                        px[q] = C(col)
    # 글자 몸: 볼트 황 램프 — 위 3분의 1 밝게, 아래 3분의 1 그늘, 가운데 한 줄 반짝임
    top = min(y for _, y in fill)
    bot = max(y for _, y in fill)
    for (x, y) in fill:
        k = (y - top) / max(1, bot - top)
        col = "P50" if k < 0.22 else ("P49" if k < 0.62 else ("P48" if k < 0.86 else "P47"))
        px[x, y] = C(col)
    for (x, y) in fill:                                                   # 글자 위 가장자리 1px 하이라이트
        if (x, y - 1) not in fill:
            px[x, y] = C("P50")
    # 글자 아래 그림자 한 단(잉크, 오른쪽 아래 2px)
    sh = Image.new("RGBA", (W + 2, H + 2), (0, 0, 0, 0))
    spx = sh.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and px[x, y][:3] == P.rgb("P01"):
                spx[x + 2, y + 2] = C("P01")
    sh.alpha_composite(im, (0, 0))
    return sh


def plate():
    """볼트 문 명판: 철판(중성 램프) + 리벳 4 + 새김 글 3줄."""
    lines = ["볼트-텍 면허", "한결건설 시공", "서울 볼트 S-07"]
    ws = [text_px(s, 8, "Galmuri7")[1] for s in lines]
    W, H = max(ws) + 22, 44
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            edge = x in (0, W - 1) or y in (0, H - 1)
            px[x, y] = C("P01") if edge else C("P06" if y < 2 else ("P04" if y > H - 3 else "P05"))
    for x in range(2, W - 2):
        px[x, 1] = C("P07")
    for (x, y) in ((4, 4), (W - 5, 4), (4, H - 5), (W - 5, H - 5)):          # 리벳
        px[x, y] = C("P08")
        px[x + 1, y + 1] = C("P03")
    for i, s in enumerate(lines):
        put_text(im, s, (W - ws[i]) // 2, 5 + i * 12, "P02", 8, "Galmuri7", shadow="P07")
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    lg = logo()
    pl = plate()
    for name, im in (("title_logo", lg), ("title_plate", pl)):
        bad = check(im, P.allowed_set("UI"))
        if bad:
            print("팔레트 밖 색:", name, bad[:5])
            sys.exit(1)
        im.save(os.path.join(OUT, name + ".png"))
        print(name, im.size)


if __name__ == "__main__":
    main()
