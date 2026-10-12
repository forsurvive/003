"""단계 S ★ 1× 판독 시험지 (SD-19 §5.1): 640×360 실제 크기 화면에서
  A) 몸통 4계열 구분 (정답률 100%)   B) 크리처 3종을 원형 종으로 식별 (100%)
시험지에는 이름을 쓰지 않고 번호만 적는다. 순서는 고정 시드로 섞고, 정답은 samples/23_legibility_key.txt에 따로 둔다.
배경은 봉천 장면(에셋 층)이고, 인물은 대기·걷기 프레임을 섞어 실제 화면처럼 흩어 놓는다.
Writes samples/23_legibility_A.png, 23_legibility_B.png (1×, 확대하지 말고 볼 것), 23_legibility_key.txt."""
import os, sys, random
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P
from grid import parse

ROOT = os.path.dirname(os.path.dirname(__file__))
W, H = 640, 360


def label(img, x, y, n, F):
    d = ImageDraw.Draw(img); d.fontmode = "1"
    d.rectangle([x - 6, y, x + 6, y + 12], fill=P.rgb("P01"))
    d.text((x - 3, y + 1), str(n), font=F, fill=P.rgb("P49"))


def main():
    import rig_pc as R
    import scene_bongcheon as SB
    import creatures as CR
    F = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
    rnd = random.Random(2277)
    SB.RUNTIME = True
    bg = SB.build(hud=False).convert("RGBA")
    # A: 8 figures = 4 families x 2 (idle / walk), shuffled, standing on the street band
    fams = [("T01", None, "T01 점프슈트"), ("T02", None, "T02 경비 진압복"), ("T03", None, "T03 황무지 평상복"),
            ("T06", "PF-01", "T06 전투 아머(계엄군)")]
    figs = []
    for code, pf, name in fams:
        sets, _ = R.build_all(code, pf)
        figs.append((name, sets["idle"][rnd.choice(("S", "SE", "E"))]))
        figs.append((name, sets["walk"][rnd.choice(("S", "SW", "W", "NE"))][rnd.randrange(6)]))
    rnd.shuffle(figs)
    a = bg.copy()
    key = ["A) 몸통 계열 (번호: 정답)"]
    for i, (name, f) in enumerate(figs):
        fx, fy = 52 + i * 74, 300 + (i % 2) * 16
        a.alpha_composite(f, (fx - 32, fy - 60))
        label(a, fx, fy + 4, i + 1, F)
        key.append(f"  {i + 1}: {name}")
    # B: roach (16-32px), rat (32), dog (64), each twice, shuffled
    roach = parse(os.path.join(ROOT, "src/sprites/cr_roach.txt"))["E_idle0"]
    dog = CR.stand(CR.DOG)
    rat = CR.stand(CR.RAT)
    crs = [("변이 바퀴벌레", roach), ("변이 바퀴벌레", roach.transpose(Image.FLIP_LEFT_RIGHT)),
           ("변이 시궁쥐", rat), ("변이 시궁쥐", rat.transpose(Image.FLIP_LEFT_RIGHT)),
           ("변이 들개", dog), ("변이 들개", dog.transpose(Image.FLIP_LEFT_RIGHT))]
    rnd.shuffle(crs)
    b = bg.copy()
    key.append("B) 크리처 (번호: 정답)")
    for i, (name, im) in enumerate(crs):
        fx, fy = 60 + i * 100, 300
        b.alpha_composite(im, (fx - im.width // 2, fy - im.height + 2))
        label(b, fx, fy + 6, i + 1, F)
        key.append(f"  {i + 1}: {name}")
    out = os.path.join(ROOT, "samples")
    a.convert("RGB").save(os.path.join(out, "23_legibility_A.png"))
    b.convert("RGB").save(os.path.join(out, "23_legibility_B.png"))
    open(os.path.join(out, "23_legibility_key.txt"), "w", encoding="utf-8").write("\n".join(key) + "\n")
    print("\n".join(key))


if __name__ == "__main__":
    main()
