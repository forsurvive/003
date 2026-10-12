"""H-11 화면비 비교 화면 (SD-19 §5.2 화면 행, SD-12 §17.3).
기기마다 시험 구역을 두 방식(① expand: 세로 360 기준 확장·상한 854×480, ② letterbox: 640×360 고정)으로 찍어
실제 화면 크기에 정수 배율로 놓고(남는 곳은 검은 띠) 나란히 붙인다. 휴대폰·태블릿은 터치 버튼을 켠다.
출력: game/reports/h11_aspect.png(축소 개관), game/reports/h11_aspect_1x.png(논리 해상도 1배, 같은 장면), h11_aspect.txt(수치)
실행: python3 tools/screens/h11_compare.py  (Xvfb + godot 필요)"""
import os, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, "game")
OUT = os.path.join(GAME, "reports")
FONT = ImageFont.truetype(os.path.join(ROOT, "art", "fonts", "Galmuri11.ttf"), 12)
DEVICES = [("PC 16:9", 1920, 1080, False), ("노트북", 1366, 768, False), ("울트라와이드 21:9", 2560, 1080, False),
           ("휴대폰 20:9", 2400, 1080, True), ("휴대폰 19.5:9", 2532, 1170, True), ("태블릿 4:3", 2048, 1536, True),
           ("접는 폰 안쪽", 2176, 1812, True)]
MODES = [("expand", "① 세로 360 기준 확장"), ("letterbox", "② 레터박스(640×360 고정)")]


def fit(w, h, mode):
    n = max(1, min(h // 360, w // 640))
    return n, ((640, 360) if mode == "letterbox" else (min(w // n, 854), min(h // n, 480)))


def shoot(tmp, w, h, mode, touch):
    path = os.path.join(tmp, f"{w}x{h}_{mode}.png")
    args = ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", "godot", "--path", GAME, "--",
            f"--device={w}x{h}", f"--fit={mode}", f"--shot={path}"] + (["--touch"] if touch else [])
    subprocess.run(args, check=True, capture_output=True, timeout=180)
    return Image.open(path).convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    TH = 200                                                  # 개관 칸 높이
    rows, ones, lines = [], [], ["기기\t화면\t방식\tn\t논리 해상도\t보이는 타일\t검은 띠 비율"]
    with tempfile.TemporaryDirectory() as tmp:
        for name, w, h, touch in DEVICES:
            cells = []
            for mode, label in MODES:
                n, (lw, lh) = fit(w, h, mode)
                shot = shoot(tmp, w, h, mode, touch)
                assert shot.size == (lw, lh), (name, mode, shot.size)
                dev = Image.new("RGB", (w, h), (0, 0, 0))
                big = shot.resize((lw * n, lh * n), Image.NEAREST)
                dev.paste(big, ((w - lw * n) // 2, (h - lh * n) // 2))
                bars = 1.0 - (lw * n * lh * n) / (w * h)
                lines.append(f"{name}\t{w}×{h}\t{label}\t{n}\t{lw}×{lh}\t{lw / 32:.1f}×{lh / 32:.1f}\t{bars * 100:.1f}%")
                thumb = dev.resize((round(w * TH / h), TH), Image.LANCZOS)
                cells.append((thumb, [label, f"×{n} → {lw}×{lh} · 타일 {lw / 32:.1f}×{lh / 32:.1f} · 띠 {bars * 100:.0f}%"]))
                if mode == "expand":
                    ones.append((name, shot))
            rows.append((f"{name}  {w}×{h}", cells))
        cw = lambda c: max(c[0].width, max(round(FONT.getlength(t)) for t in c[1]))
        W = 12 + max(sum(cw(c) + 16 for c in cells) for _, cells in rows)
        sheet = Image.new("RGB", (W, sum(TH + 54 for _ in rows) + 8), (43, 40, 48))
        d = ImageDraw.Draw(sheet); d.fontmode = "1"
        y = 8
        for title, cells in rows:
            d.text((12, y), title, font=FONT, fill=(232, 194, 58))
            x = 12
            for c in cells:
                im, cap = c
                sheet.paste(im, (x, y + 16))
                d.rectangle([x - 1, y + 15, x + im.width, y + 16 + im.height], outline=(110, 105, 102))
                d.text((x, y + 18 + TH), cap[0], font=FONT, fill=(233, 228, 216))
                d.text((x, y + 32 + TH), cap[1], font=FONT, fill=(203, 197, 185))
                x += cw(c) + 16
            y += TH + 54
        sheet.save(os.path.join(OUT, "h11_aspect.png"))
        # 1배 논리 화면: ① 방식에서 보이는 범위 그대로(픽셀 그대로, 축소 없음)
        W1 = 8 + max(im.width for _, im in ones) + 8
        one = Image.new("RGB", (W1, sum(im.height + 22 for _, im in ones) + 8), (43, 40, 48))
        d = ImageDraw.Draw(one); d.fontmode = "1"
        y = 8
        for name, im in ones:
            d.text((8, y), f"{name} ① {im.width}×{im.height} (1배)", font=FONT, fill=(232, 194, 58))
            one.paste(im, (8, y + 16))
            y += im.height + 22
        one.save(os.path.join(OUT, "h11_aspect_1x.png"))
    open(os.path.join(OUT, "h11_aspect.txt"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
